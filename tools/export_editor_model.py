#!/usr/bin/env python3
"""Convert the authored world scene to a script-free Roblox Studio editor preview.

The scene comes from export_scene.py executing the real World/CreatureVisual modules.
Only supported native instance classes and properties are serialized. Gameplay prompts
and creature billboards are omitted because their event hooks exist only during Play.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PART_CLASSES = {"Part", "WedgePart", "SpawnLocation"}
SUPPORTED_CLASSES = PART_CLASSES | {"Model", "Folder", "SurfaceGui", "TextLabel", "PointLight", "UITextSizeConstraint"}
OMITTED_CLASSES = {"ProximityPrompt", "BillboardGui"}
ENUM_VALUES = {
    "Enum.Material.SmoothPlastic": 272,
    "Enum.Material.Neon": 288,
    "Enum.Material.Wood": 512,
    "Enum.Material.WoodPlanks": 528,
    "Enum.Material.Slate": 800,
    "Enum.Material.Metal": 1088,
    "Enum.Material.Grass": 1280,
    "Enum.Material.Sand": 1296,
    "Enum.Material.Fabric": 1312,
    "Enum.Material.Ground": 1360,
    "Enum.Material.Glass": 1568,
    "Enum.PartType.Ball": 0,
    "Enum.PartType.Block": 1,
    "Enum.PartType.Cylinder": 2,
    "Enum.SurfaceType.Smooth": 0,
    "Enum.NormalId.Front": 5,
    "Enum.Font.GothamMedium": 18,
    "Enum.Font.GothamBold": 19,
    "Enum.Font.FredokaOne": 26,
}
PART_PROPERTIES = {
    "Anchored": ("bool", "Anchored"),
    "CanCollide": ("bool", "CanCollide"),
    "CanQuery": ("bool", "CanQuery"),
    "CanTouch": ("bool", "CanTouch"),
    "CastShadow": ("bool", "CastShadow"),
    "CFrame": ("CoordinateFrame", "CFrame"),
    "Size": ("Vector3", "size"),
    "Color": ("Color3uint8", "Color3uint8"),
    "Material": ("token", "Material"),
    "TopSurface": ("token", "TopSurface"),
    "BottomSurface": ("token", "BottomSurface"),
    "Transparency": ("float", "Transparency"),
}
CLASS_PROPERTIES = {
    "Model": {"PrimaryPart": ("Ref", "PrimaryPart")},
    "Folder": {},
    "Part": {**PART_PROPERTIES, "Shape": ("token", "shape")},
    "WedgePart": PART_PROPERTIES,
    "SpawnLocation": {**PART_PROPERTIES, "Duration": ("int", "Duration"), "Neutral": ("bool", "Neutral")},
    "SurfaceGui": {
        "CanvasSize": ("Vector2", "CanvasSize"),
        "Face": ("token", "Face"),
        "LightInfluence": ("float", "LightInfluence"),
    },
    "TextLabel": {
        "Position": ("UDim2", "Position"),
        "Size": ("UDim2", "Size"),
        "BackgroundTransparency": ("float", "BackgroundTransparency"),
        "Font": ("token", "Font"),
        "Text": ("string", "Text"),
        "TextColor3": ("Color3", "TextColor3"),
        "TextSize": ("float", "TextSize"),
        "TextWrapped": ("bool", "TextWrapped"),
        "TextScaled": ("bool", "TextScaled"),
        "TextStrokeColor3": ("Color3", "TextStrokeColor3"),
        "TextStrokeTransparency": ("float", "TextStrokeTransparency"),
    },
    "PointLight": {
        "Brightness": ("float", "Brightness"),
        "Color": ("Color3", "Color"),
        "Range": ("float", "Range"),
        "Shadows": ("bool", "Shadows"),
    },
    "UITextSizeConstraint": {"MinTextSize": ("int", "MinTextSize"), "MaxTextSize": ("int", "MaxTextSize")},
}


def number(value: float) -> str:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"Expected finite numeric property, got {value!r}")
    return format(value, ".17g")


def child(parent: ET.Element, tag: str, value: str) -> None:
    ET.SubElement(parent, tag).text = value


def property_element(properties: ET.Element, tag: str, name: str, value: object, included_ids: set[str]) -> None:
    element = ET.SubElement(properties, tag, {"name": name})
    if tag == "string":
        if not isinstance(value, str):
            raise ValueError(f"Expected string for {name}")
        element.text = value
    elif tag == "bool":
        if not isinstance(value, bool):
            raise ValueError(f"Expected bool for {name}")
        element.text = "true" if value else "false"
    elif tag in {"float", "int"}:
        if tag == "int" and value != int(value):
            raise ValueError(f"Expected whole number for {name}")
        element.text = number(value)
    elif tag == "token":
        if value not in ENUM_VALUES:
            raise ValueError(f"Unsupported enum {value!r}; add its explicit native value")
        element.text = str(ENUM_VALUES[value])
    elif tag == "Ref":
        reference = value.get("id")
        if value.get("kind") != "Ref" or reference not in included_ids:
            raise ValueError(f"Invalid model reference {value!r}")
        element.text = reference
    elif tag in {"Color3", "Color3uint8"}:
        if value.get("kind") != "Color3" or len(value["value"]) != 3:
            raise ValueError(f"Invalid Color3 property {value!r}")
        rgb = value["value"]
        if any(not isinstance(x, (int, float)) or not math.isfinite(x) or x < 0 or x > 1 for x in rgb):
            raise ValueError(f"Invalid color channels {rgb!r}")
        if tag == "Color3uint8":
            r, g, b = [int(math.floor(x * 255 + 0.5)) for x in rgb]
            element.text = str(0xFF000000 | (r << 16) | (g << 8) | b)
        else:
            for axis, component in zip(("R", "G", "B"), rgb):
                child(element, axis, number(component))
    elif tag in {"Vector2", "Vector3"}:
        expected = 2 if tag == "Vector2" else 3
        if value.get("kind") == "Vector3":
            components = value["value"]
        elif value.get("_kind") == "Vector2":
            components = [value["X"], value["Y"]]
        else:
            raise ValueError(f"Invalid {tag} property {value!r}")
        if len(components) != expected:
            raise ValueError(f"Wrong {tag} component count")
        for axis, component in zip(("X", "Y", "Z"), components):
            child(element, axis, number(component))
    elif tag == "UDim2":
        if value.get("_kind") != "UDim2":
            raise ValueError(f"Invalid UDim2 property {value!r}")
        for axis in ("X", "Y"):
            child(element, axis + "S", number(value[axis]["Scale"]))
            child(element, axis + "O", number(value[axis]["Offset"]))
    elif tag == "CoordinateFrame":
        if value.get("kind") != "CFrame" or len(value["position"]) != 3 or len(value["rotation"]) != 9:
            raise ValueError(f"Invalid CFrame property {value!r}")
        for axis, component in zip(("X", "Y", "Z"), value["position"]):
            child(element, axis, number(component))
        for index, component in enumerate(value["rotation"]):
            child(element, f"R{index // 3}{index % 3}", number(component))
    else:
        raise ValueError(f"Unsupported XML property type {tag!r}")


def export(scene_path: Path, output: Path) -> dict[str, int]:
    scene = json.loads(scene_path.read_text())
    if scene.get("mode") != "world" or not scene.get("nodes"):
        raise ValueError("Expected a nonempty world scene from export_scene.py")
    nodes = {node["id"]: node for node in scene["nodes"]}
    if len(nodes) != len(scene["nodes"]):
        raise ValueError("Duplicate scene IDs")
    roots = [node for node in nodes.values() if node.get("parent") not in nodes]
    if len(roots) != 1 or roots[0]["class"] != "Model" or roots[0]["name"] != "WildboundWorld":
        raise ValueError("Expected exactly one WildboundWorld root model")
    children = defaultdict(list)
    for node in nodes.values():
        children[node.get("parent")].append(node)
    included = []
    omitted = Counter()

    def collect(node: dict) -> None:
        class_name = node["class"]
        if class_name in OMITTED_CLASSES:
            omitted[class_name] += 1
            return
        if class_name not in SUPPORTED_CLASSES:
            raise ValueError(f"Unsupported scene class {class_name!r}; never include scripts implicitly")
        included.append(node)
        for descendant in children[node["id"]]:
            collect(descendant)

    collect(roots[0])
    included_ids = {node["id"] for node in included}
    roblox = ET.Element("roblox", {"version": "4"})
    digest = hashlib.sha256(scene_path.read_bytes()).hexdigest()
    roblox.append(ET.Comment(f" Generated by tools/export_editor_model.py; source scene SHA256 {digest}. Do not edit. "))
    child(roblox, "External", "null")
    child(roblox, "External", "nil")

    def append_instance(parent: ET.Element, node: dict) -> None:
        item = ET.SubElement(parent, "Item", {"class": node["class"], "referent": node["id"]})
        props = ET.SubElement(item, "Properties")
        property_element(props, "string", "Name", node["name"], included_ids)
        source_properties = dict(node["properties"])
        # Early scene adapters treated any Position as a BasePart Position. Recover
        # the two UDim components for sign text from those old exports too.
        if node["class"] == "TextLabel" and "CFrame" in source_properties:
            gui_position = source_properties.pop("CFrame")["position"]
            if len(gui_position) != 2 or any(not isinstance(x, dict) for x in gui_position):
                raise ValueError("TextLabel CFrame cannot be recovered as a GUI position")
            source_properties.setdefault("Position", {"_kind": "UDim2", "X": gui_position[0], "Y": gui_position[1]})
        for key, value in source_properties.items():
            if key in {"Name", "_pivot"}:
                continue
            descriptor = CLASS_PROPERTIES[node["class"]].get(key)
            if descriptor is None:
                raise ValueError(f"Unsupported property {node['class']}.{key}; preserve it explicitly")
            property_element(props, descriptor[0], descriptor[1], value, included_ids)
        for descendant in children[node["id"]]:
            if descendant["id"] in included_ids:
                append_instance(item, descendant)

    append_instance(roblox, roots[0])
    ET.indent(roblox, space="  ")
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(roblox).write(output, encoding="utf-8", xml_declaration=True)
    counts = Counter(node["class"] for node in included)
    parts = sum(counts[k] for k in PART_CLASSES)
    print(f"Editor preview: {parts} native parts, {counts['SurfaceGui']} signs, {counts['PointLight']} lights -> {output}")
    print(f"Omitted unbound runtime prompts/nameplates: {dict(omitted)}; no scripts or external assets")
    return dict(counts)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", type=Path, default=ROOT / ".build/world-scene.json")
    parser.add_argument("--output", type=Path, default=ROOT / "assets/WorldPreview.rbxmx")
    args = parser.parse_args()
    export(args.scene, args.output)

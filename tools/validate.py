#!/usr/bin/env python3
"""Compile Luau, execute headless logic regressions, and build the Rojo place.

This does not emulate Roblox Studio. Rendering, input and live multiplayer must
still pass tests/STUDIO-SMOKE.md before publishing.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
TOOLS = Path(os.environ.get("WILDBOUND_TOOL_DIR", "/workspace/.wildbound-tools"))
BUILD = ROOT / ".build"


def run(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(result.returncode)
    if result.stdout.strip():
        print(result.stdout.strip())


def check_ui_contrast():
    source = (ROOT / "src" / "client" / "Game.client.luau").read_text()
    palette = re.search(r"local palette\s*=\s*\{(.*?)\n\}", source, re.S)
    if palette is None:
        raise SystemExit("Cannot verify UI contrast: named palette is missing.")
    colors = {
        name: tuple(int(value) / 255 for value in rgb)
        for name, *rgb in re.findall(r"(\w+)\s*=\s*Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)", palette.group(1))
    }
    def luminance(rgb):
        linear = [channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in rgb]
        return sum(channel * weight for channel, weight in zip(linear, (0.2126, 0.7152, 0.0722)))
    pairs = [("ink", "paper"), ("muted", "paper"), ("amber", "paper"), ("danger", "paper"),
             ("white", "ink"), ("ink", "white"), ("muted", "white"), ("ink", "line"),
             ("success", "paper"), ("success", "white"), ("amber", "white"), ("danger", "white"),
             ("gold", "ink"), ("white", "teal"), ("teal", "white"), ("teal", "paper"),
             ("ink", "peach"), ("ink", "sky"), ("muted", "line")]
    # Read the authored hover/press blend values so changes to interaction colors
    # are checked as well as steady-state button colors.
    hover = re.search(r"background:Lerp\(palette\.(\w+),\s*([0-9.]+)\)", source)
    pressed = re.search(r"background:Lerp\(buttons\[object\].foreground == palette.white and palette\.(\w+) or palette\.(\w+),\s*([0-9.]+)\)", source)
    if hover is None or pressed is None:
        raise SystemExit("Cannot verify hover/press contrast: button blends are missing.")
    def blend(a, b, amount):
        return tuple(x + (y - x) * amount for x, y in zip(colors[a], colors[b]))
    colors["primary_hover"] = blend("teal", hover.group(1), float(hover.group(2)))
    colors["secondary_hover"] = blend("white", hover.group(1), float(hover.group(2)))
    colors["primary_pressed"] = blend("teal", pressed.group(1), float(pressed.group(3)))
    colors["secondary_pressed"] = blend("white", pressed.group(2), float(pressed.group(3)))
    pairs.extend([("white", "primary_hover"), ("white", "primary_pressed"),
                  ("ink", "secondary_hover"), ("ink", "secondary_pressed")])
    minimum = 100
    for text, background in pairs:
        light, dark = sorted((luminance(colors[text]), luminance(colors[background])), reverse=True)
        contrast = (light + 0.05) / (dark + 0.05)
        if contrast < 4.5:
            raise SystemExit("UI contrast %s on %s is %.2f:1; needs 4.5:1." % (text, background, contrast))
        minimum = min(minimum, contrast)
    print("PASS: %d UI text/background pairs meet 4.5:1 contrast (minimum %.2f:1)." % (len(pairs), minimum))



def check_editor_preview():
    project = json.loads((ROOT / "default.project.json").read_text())
    workspace = project["tree"].get("Workspace", {})
    mapping = workspace.get("WildboundWorld")
    if mapping is None:
        return
    if workspace.get("$ignoreUnknownInstances") is not True:
        raise SystemExit("Editor preview mapping must preserve other Studio Workspace objects.")
    path = ROOT / mapping["$path"]
    source = path.read_text()
    digest = re.search(r"source scene SHA256 ([0-9a-f]{64})", source)
    if digest is None:
        raise SystemExit("Editor preview is missing its source-scene checksum.")
    # Re-execute source into a temporary scene for freshness; never overwrite or
    # regenerate the checked-in model during validation.
    scene = BUILD / "validation-world-scene.json"
    run([sys.executable, str(ROOT / "tools" / "export_scene.py"), "world", "--output", str(scene)])
    if hashlib.sha256(scene.read_bytes()).hexdigest() != digest.group(1):
        raise SystemExit("Editor preview is stale. Regenerate it with tools/export_editor_model.py after exporting the current world scene.")
    preview = ET.fromstring(source)
    roots = preview.findall("Item")
    if len(roots) != 1 or roots[0].get("class") != "Model" or roots[0].findtext("Properties/string[@name='Name']") != "WildboundWorld":
        raise SystemExit("Editor preview must contain exactly one WildboundWorld model.")
    built = ET.parse(BUILD / "Wildbound.rbxlx").getroot()
    workspaces = [item for item in built.findall("Item") if item.get("class") == "Workspace"]
    if len(workspaces) != 1:
        raise SystemExit("Built place is missing a unique Workspace.")
    worlds = [item for item in workspaces[0].findall("Item") if item.findtext("Properties/string[@name='Name']") == "WildboundWorld"]
    if len(worlds) != 1:
        raise SystemExit("Rojo must package exactly one visible editor world.")
    counts = []
    for root in (roots[0], worlds[0]):
        count = 0
        for item in root.iter("Item"):
            kind = item.get("class")
            if kind in {"Script", "LocalScript", "ModuleScript", "MeshPart", "Decal", "Sound"}:
                raise SystemExit("Editor preview acquired an undeclared script or external asset: " + kind)
            if kind in {"Part", "WedgePart", "SpawnLocation"}:
                count += 1
                if item.findtext("Properties/bool[@name='Anchored']") != "true":
                    raise SystemExit("Editor preview contains an unanchored part.")
        counts.append(count)
    if counts[0] != counts[1] or counts[0] < 2000:
        raise SystemExit("Built editor preview has missing geometry.")
    print("PASS: fresh source-scene checksum, %d anchored editor parts packaged once, script-free world, preserved Workspace siblings." % counts[0])

def main():
    compiler = TOOLS / "luau" / "luau-compile"
    interpreter = TOOLS / "luau" / "luau"
    rojo = TOOLS / "rojo" / "rojo"
    for binary in (compiler, interpreter, rojo):
        if not binary.is_file():
            raise SystemExit("Missing tool: %s. Run tools/install-validation-tools.sh." % binary)
    BUILD.mkdir(exist_ok=True)
    sources = sorted(ROOT.glob("src/**/*.luau"))
    if not sources:
        raise SystemExit("No Luau source files found.")
    run([str(compiler), "--null", *(str(path) for path in sources)])
    print("Compiled %d Luau source files." % len(sources))
    check_ui_contrast()
    config = ROOT / "src" / "shared" / "Config.luau"
    spec = ROOT / "tests" / "config.spec.luau"
    config_prefix = (
        "local Color3 = {fromRGB = function(r,g,b) return {R=r/255,G=g/255,B=b/255} end,"
        " new = function(r,g,b) return {R=r,G=g,B=b} end}\n"
        "local Config = (function()\n" + config.read_text() + "\nend)()\n"
    )
    if config.is_file() and spec.is_file():
        # The CLI intentionally lacks Roblox globals. Inline the real Config
        # behind a Color3-only stub so its actual functions are executed.
        bundled = BUILD / "config.spec.luau"
        bundled.write_text(config_prefix + spec.read_text(), encoding="utf-8")
        run([str(interpreter), str(bundled)])
    persistence = ROOT / "src" / "server" / "PlayerData.luau"
    persistence_spec = ROOT / "tests" / "playerdata.spec.luau"
    if persistence.is_file() and persistence_spec.is_file():
        bundled = BUILD / "playerdata.spec.luau"
        bundled.write_text(
            config_prefix + persistence_spec.read_text().replace(
                "-- INLINE_PLAYERDATA", persistence.read_text()
            ), encoding="utf-8"
        )
        run([str(interpreter), str(bundled)])
    raids = ROOT / "src" / "server" / "RaidService.luau"
    raid_spec = ROOT / "tests" / "raids.spec.luau"
    if raids.is_file() and raid_spec.is_file():
        bundled = BUILD / "raids.spec.luau"
        bundled.write_text(
            config_prefix + raid_spec.read_text().replace(
                "-- INLINE_RAIDSERVICE", raids.read_text()
            ), encoding="utf-8"
        )
        run([str(interpreter), str(bundled)])
    gameplay = ROOT / "src" / "server" / "GameService.luau"
    gameplay_spec = ROOT / "tests" / "gameplay.spec.luau"
    if gameplay.is_file() and gameplay_spec.is_file():
        bundled = BUILD / "gameplay.spec.luau"
        bundled.write_text(
            config_prefix + gameplay_spec.read_text().replace(
                "-- INLINE_GAMESERVICE", gameplay.read_text()
            ), encoding="utf-8"
        )
        run([str(interpreter), str(bundled)])
    world = ROOT / "src" / "server" / "World.luau"
    creature_visual = ROOT / "src" / "shared" / "CreatureVisual.luau"
    world_spec = ROOT / "tests" / "world.spec.luau"
    if world.is_file() and creature_visual.is_file() and world_spec.is_file():
        # Real procedural modules execute behind Instance/vector/CFrame adapters.
        # CFrame composition is modeled; rendering, collision and replication are not.
        bundled = BUILD / "world.spec.luau"
        bundled.write_text(
            world_spec.read_text().replace(
                "-- INLINE_PLATFORM", (ROOT / "tests" / "platform-adapter.luau").read_text()
            ).replace(
                "-- INLINE_CONFIG", "local Config = (function()\n" + config.read_text() + "\nend)()"
            ).replace(
                "-- INLINE_CREATUREVISUAL", "local CreatureVisual = (function()\n" + creature_visual.read_text() + "\nend)()"
            ).replace(
                "-- INLINE_WORLD", "local World = (function()\n" + world.read_text() + "\nend)()"
            ), encoding="utf-8"
        )
        run([str(interpreter), str(bundled)])
    motion = ROOT / "src" / "shared" / "CreatureMotion.luau"
    animation_spec = ROOT / "tests" / "animation.spec.luau"
    if motion.is_file() and animation_spec.is_file():
        bundled = BUILD / "animation.spec.luau"
        bundled.write_text(
            animation_spec.read_text().replace(
                "-- INLINE_PLATFORM", (ROOT / "tests" / "platform-adapter.luau").read_text()
            ).replace(
                "-- INLINE_CONFIG", "local Config = (function()\n" + config.read_text() + "\nend)()"
            ).replace(
                "-- INLINE_CREATUREVISUAL", "local CreatureVisual = (function()\n" + creature_visual.read_text() + "\nend)()"
            ).replace(
                "-- INLINE_CREATUREMOTION", "local CreatureMotion = (function()\n" + motion.read_text() + "\nend)()"
            ), encoding="utf-8"
        )
        run([str(interpreter), str(bundled)])
    run([str(rojo), "build", "default.project.json", "--output", str(BUILD / "Wildbound.rbxlx")])
    print("Rojo build passed: .build/Wildbound.rbxlx")
    check_editor_preview()


if __name__ == "__main__":
    main()

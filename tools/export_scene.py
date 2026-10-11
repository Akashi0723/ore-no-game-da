#!/usr/bin/env python3
"""Extract authored Roblox geometry for offline art review; not Studio rendering."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def export(mode: str, output: Path):
    source = (ROOT / "tools/scene-adapter.luau").read_text()
    for marker, module, path in (
        ("-- INLINE_CONFIG", "Config", "src/shared/Config.luau"),
        ("-- INLINE_CREATUREVISUAL", "CreatureVisual", "src/shared/CreatureVisual.luau"),
        ("-- INLINE_CREATUREMOTION", "CreatureMotion", "src/shared/CreatureMotion.luau"),
        ("-- INLINE_WORLD", "World", "src/server/World.luau"),
    ):
        module_path = ROOT / path
        module_source = module_path.read_text() if module_path.exists() else "return nil"
        source = source.replace(marker, f"local {module} = (function()\n{module_source}\nend)()")
    source = source.replace("__SCENE_MODE__", mode)
    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    bundle = build / f"{mode}-extract.luau"
    bundle.write_text(source)
    tool_root = Path(os.environ.get("WILDBOUND_TOOL_DIR", "/workspace/.wildbound-tools"))
    result = subprocess.run([str(tool_root / "luau/luau"), str(bundle)],
                            cwd=ROOT, text=True, capture_output=True, check=True)
    data = json.loads(result.stdout)
    assert data["mode"] == mode and data["nodes"], "Scene extraction returned no nodes"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, separators=(",", ":")))
    parts = [node for node in data["nodes"] if node["class"] in ("Part", "WedgePart", "SpawnLocation")]
    print(f"Extracted {mode}: {len(parts)} native parts, including authored rotations -> {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("world", "creatures"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    export(args.mode, args.output or ROOT / ".build" / f"{args.mode}-scene.json")

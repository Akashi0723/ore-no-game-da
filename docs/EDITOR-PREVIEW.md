# World preview in Roblox Studio

Rojo now syncs a generated `Workspace.WildboundWorld` model. The islands, forest,
trails, shop, sanctuary village, signs, and a representative dusk creature population
are visible in Studio edit mode immediately after connecting Rojo. Press **Play**
to load live creature behavior, interactions, player progression, weather, and UI.

The preview uses native Roblox parts and built-in fonts. It contains no executable
scripts or external mesh, texture, audio, or animation assets. Creature prompts and
floating encounter labels appear during Play, when the game can connect their logic.

`src/server/World.luau` and `src/shared/CreatureVisual.luau` are the authoritative
world and creature sources. The checked-in `assets/WorldPreview.rbxmx` is generated
from those modules; editing that model alone does not change the live game. During
Play, `World.Build` replaces only the generated `WildboundWorld` model. Rojo leaves
other Workspace objects, including your existing place content, in place.

## Regenerate after changing world or creature geometry

Run these commands from the repository with the validation Luau toolchain installed:

```bash
python3 tools/export_scene.py world
python3 tools/export_editor_model.py
python3 tools/validate.py
```

The first command executes the actual geometry builders behind the offline scene
adapter, preserving positions and rotations in `.build/world-scene.json`. The second
converts that scene into the checked-in Roblox XML model. The validation build reads
that model through Rojo and produces a place with geometry already present in edit
mode. Commit the regenerated model with its source changes.

The exporter uses an explicit list of native classes, enum values, and serialized
properties. Unsupported properties fail the export instead of disappearing silently.
It preserves anchored geometry, collision/query flags, sizes, shapes, colors,
materials, full CFrame rotations, point lights, and SurfaceGui sign layouts. Runtime
attribute/event state is created afresh during Play.

Offline scene extraction and successful Rojo builds verify geometry serialization.
They do not verify Studio rendering, navigation, mobile frame rate, or multiplayer
behavior; use the Studio smoke checks for those.

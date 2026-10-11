# Wildbound — Hunt & Heist

A Roblox creature-collecting game built with Luau and Rojo. Explore a forest garden,
complete jobs, photograph clues, buy snacks, and befriend eight strange little creatures.
Build trust by approaching gently, discover Moonlit and Golden variants, and
feed an equipped companion to grow its bond. Keep your collection in a safe
vault or display it in your sanctuary. Studio
multiplayer tests include sanctuary raids with extraction, a 60-second chase,
and three-hit defensive nets.

## Open it in Roblox Studio

This repository uses the Git/Rojo connection already set up on your Windows PC.
From PowerShell in your local checkout:

```powershell
& "$HOME\Tools\Rojo\rojo.exe" serve
```

Connect the Studio Rojo plugin to `localhost:34872`, accept the additions under
`Workspace/WildboundWorld`,
`ReplicatedStorage/Wildbound`, `ServerScriptService/GameServer`, and
`StarterPlayer/StarterPlayerScripts/GameClient`. The generated forest preview
appears in **Edit mode**; press **Play** for the interface, creatures, progression,
and interactions. Existing Studio world objects are preserved; generated content
lives under `Workspace/WildboundWorld`.

If you pulled changes while Rojo was running, restart Rojo and reconnect when the
project configuration changes. Stop Play before editing or reconnecting.

You can also build a standalone place:

```powershell
New-Item -ItemType Directory -Force build
& "$HOME\Tools\Rojo\rojo.exe" build -o build\Wildbound.rbxlx
```

Open that file in Studio and press Play. A built place includes the forest preview
and scripts. The server replaces its preview with the interactive world on startup.
See [the edit preview workflow](docs/EDITOR-PREVIEW.md) when changing the map.

## How to play

- Follow the first garden clue. Offer the free berry, hold Sneak, and befriend
  your first Mossbun.
- Water flowers or gather fallen leaves for coins. Photograph distinct clues
  for research rewards and creature hints.
- Buy berries and seeds at the garden snack stand. Choose the creature's
  preferred snack, offer it, wait for it to approach, then sneak closer.
- Wild catches belong to the first successful player. Weather brings out
  different creatures. Hold Sneak within befriending range for three seconds to
  build trust and improve your chances. The encounter card shows the chance;
  higher Taming levels improve it too.
- The **Journey** screen guides six milestones with automatic, one-time coin
  and XP rewards. Follow its world marker when you need a next step.
- Three different garden discoveries unlock the pond. The journal tracks your
  collection, food preferences, weather, and remaining clues. Search by name or
  filter your discoveries and rare species.
- Five pond species include Reedling, Dewfin, Moonhare, Mistfox, and Bloomstag.
  Wild visitors can be Natural, Moonlit, or Golden. A variant is determined when
  the creature spawns and is preserved when caught or transferred.
- Manage your sanctuary to move creatures between safe storage and display;
  expand it as your collection grows. Each upgrade adds habitat decoration.
- Equip one owned creature to follow you. Feed its preferred snack every two
  minutes for +10 bond, up to 100. Bond adds display income at 50 and 100.
  Following you is cosmetic; vault protection depends on the display setting.
- Photograph two distinct clues each day for a research bonus. Rotating weekly
  collections reward fresh captures with coins and a naturalist title.

The map has eight sanctuary slots. Set a published experience's maximum server
size to **8 players** before private testing. New players enter during dusk so
all three garden species are initially available; weather changes every two
minutes.

| Action | Keyboard | Touch |
| --- | --- | --- |
| Sneak | Hold Left Shift | Hold Sneak |
| Offer snack / befriend | E | Encounter button |
| Shop, jobs, gate, sanctuary | F / world prompt | World prompt |
| Journey | G | Journey |
| Journal | J | Journal |
| Shop | B | Shop |
| Sanctuary | V | Sanctuary |
| Photograph clue | P | Photo |
| Defensive net | Q | Net during raid |
| Guide | H | Guide |

See the in-game guide for context-sensitive actions and snack selection.
The menu's Settings tab offers reduced motion and fewer decorative effects.
These preferences last for the current play session. Controller: hold left
trigger to sneak, X to offer/befriend, D-pad Up for field prompts, and Y to photograph;
menu controls are selectable. Field prompts pause while a menu is open.

## Studio raids and real payments

Use **Test → Start** with two players. One displays a creature; the other
approaches its display to begin a free development raid. The owner can stop the
theft and pursue the thief. The thief must reach extraction, then survive the
60-second marked chase. Three valid close-range net hits recover the creature.
Leaving, dying, or resetting cancels an unfinished raid.

**Real Robux raids are disabled.** This version has no active Developer Product,
receipt processor, or production ownership-transfer journal. Setting a product
ID alone does not enable paid raids. The requested payment-per-attempt design
needs current Roblox policy review, clear failure terms, idempotent receipt
handling, and tested recovery across two saved player profiles before release.
Published servers must not charge players for this prototype feature.

## Saving

Studio uses **session-only progress by default** and shows that status in the
interface. Restarting the Studio test starts fresh. Published experiences use
`WildboundProfiles_v1` with server-side session locks and periodic saves.
Unavailable or locked production profiles are rejected rather than overwritten
with blank progress. A lost lock makes the profile read-only.

Production DataStore access, save/rejoin, and cross-server locking still require
validation in a private Roblox experience. Avoid enabling API access in Studio
against live player data; use a separate testing experience/store if needed.

## Development and verification

No external art packs or web dependencies are required. The island forest,
waterfalls, market, sanctuary village, and eight articulated creatures use native
Roblox geometry. Creatures patrol and react to snacks on the server; the client
poses ears, wings, feet, fins, tails, and blinking eyes without moving capture roots.
Portraits share those models and animations. Bounded effects and a reduced-motion
option support smaller devices.

Game tuning lives in `src/shared/Config.luau`; the UI palette and layout live in
`src/client/Game.client.luau`. [Editable SVG design boards](docs/UI-HANDOFF.md) are
available for Figma import. This revision contains no Figma-created file or
Meshy-generated model; see [asset tool status](docs/ASSET-PIPELINE.md).

On Linux, install the pinned, checksum-verified validation tools and run checks:

```bash
bash tools/install-validation-tools.sh
python3 tools/validate.py
```

The validator compiles Luau, executes logic regression tests, and builds a Rojo
place. It does **not** run Roblox physics, rendering, replication, or payments.
Complete [the Studio smoke tests](tests/STUDIO-SMOKE.md) before publishing.

For an offline geometry review (requires Blender and Python):

```bash
python3 tools/export_scene.py world
python3 tools/export_editor_model.py
blender --background --python tools/render_scene.py -- --input .build/world-scene.json --output .build/forest.png --view world
```

These previews execute the authored world geometry, then render it outside Roblox.
They do not reproduce Studio lighting, UI, physics, or frame rate.

The [game concept](docs/GAME-CONCEPT.md) records the agreed design and the
[implementation contract](docs/IMPLEMENTATION-CONTRACT.md) records module APIs.

# Asset tool status and import workflow

This revision uses authored native Roblox geometry and joint poses for all eight
creatures and the forest environment. It has no external mesh dependency,
unverified Roblox asset ID, or Meshy-generated file.

## Figma

The Figma connection was confirmed, but no callable Figma tools were exposed in
this session. No external Figma file was created or edited. The editable SVG
boards under `design/handoff/` capture the implemented HUD, collection, and phone
layout and can be imported into Figma. `docs/UI-HANDOFF.md` explains the handoff.

## Meshy

Meshy CLI 0.4 was installed and its doctor and dry planner ran. A single textured
Mossbun preview plus refine was estimated at 30 credits (20 + 10). That estimate
was not a purchase or generation request. No model task, task ID, or credit charge
was created.

The current cloud proxy rejected `www.meshy.ai` during device sign-in; no login
code or credentials became available. Network settings need the official
`www.meshy.ai` and `api.meshy.ai` destinations before that workflow can resume.
Sign in through Meshy's supported device flow; never paste an API key into chat
or commit credential files. Recheck the live credit estimate and account balance
before starting a paid generation.

For a future generated asset, keep source GLB/FBX files and attribution/license
notes outside runtime scripts. Review geometry, triangle and texture budgets,
silhouette, rig hierarchy, and animations before importing with Studio's 3D
Importer. Upload meshes and animations under the experience owner's permissions,
then use the verified asset IDs. A cloud-generated file is not automatically a
usable Roblox asset ID.

Preserve the feet-origin creature root and the model's identity attributes.
Collision and capture distances remain server controlled. If imported animation
replaces native joint poses, disable the overlapping native pose layer for that
model and test idle, walking, startled, lure approach, companion, and viewport
states on a phone in Studio.

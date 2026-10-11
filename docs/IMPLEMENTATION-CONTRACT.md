# Wildbound implementation contract

Rojo maps shared modules to `ReplicatedStorage.Wildbound`, server modules to
`ServerScriptService.GameServer`, and client scripts to
`StarterPlayerScripts.GameClient`. Only `Workspace.WildboundWorld` belongs to
the world generator. Existing Studio world objects are preserved.

## Authoritative requests and presentation

`Wildbound.Remotes.Request` accepts tables with an `action` and relevant target
fields. `Update` sends `State`, `Toast`, `Panel`, `Capture`, `Photo`, `Lure`,
`Bond`, and `QuestComplete` packets. Positions in presentation packets and
waypoints use `{x, y, z}`. Currency, XP, trust, chance, variant, quest rewards,
inventory, and ownership are resolved by the server; client grants are ignored.

| Action | Relevant fields | Validation |
| --- | --- | --- |
| Sync | — | Sends a snapshot; never grants a reward |
| Sneak | enabled boolean | Server sets speed; release remains available under request saturation |
| Lure | target entity ID, snack Berry/Seed | Proximity, pond access, tutorial owner, food, inventory, cooldown |
| Befriend | target entity ID | Ready live lure, proximity, Sneak, exclusive claim, server trust/chance |
| Job / Photo | target job/clue ID | Proximity, repeatable job cooldown / one-time clue research |
| BuySnack | snack | Price, balance, level, inventory cap |
| SetDisplay | target owned UID, displayed boolean | Ownership, capacity, raid reservation |
| EquipCompanion | target owned UID, or omitted to unequip | Ownership, raid reservation |
| FeedCompanion | target owned UID | Preferred food, persisted cooldown, bond cap, raid reservation |
| UpgradeSanctuary | — | Cost, balance, maximum level |
| PondGate / Shop / Sanctuary | — | Relevant proximity / area access |
| BeginRaid | target creature UID, owner numeric UserId | Two online session-only Studio profiles, display, reservation, range, line of sight |
| Net | target thief UserId | Active defender, live character, range, line of sight, hit cooldown |
| CancelRaid | — | Active participant |

All valuable requests share bounded input validation and rate limits. Profiles
with an expired or lost save lease cannot mutate gameplay or earn income.

## State and progression

Snapshots contain coins, XP, level, tamingTool, titles, snacks, discoveries,
creatures, equippedUid, feedCooldownSeconds, tutorialComplete, pondUnlocked,
sanctuaryLevel/capacity/upgradeCost, weather/countdown, daily, event, research,
saving, sneaking, lures, questline, objective, and optional raid.

Owned creature snapshots include `uid`, `species`, `displayed`, `variant`,
`bond`, `lastFed`, `feedReadyIn`, and `reserved`. Lures are keyed by entity ID
and include `readyIn`, `expiresIn`, `trust` (0–1), and `chance` (0–1).
`questline` and `objective` describe the current journey milestone:
`id/title/text/progress/goal/reward/xpReward/complete/waypoint`.

The six journey IDs are firstcatch, firstjob, 2photos, 3garden, firstdisplay,
and pondcatch. Reward claims are persisted as research flags and advance only
after validated gameplay mutations or authoritative profile loading. Wild
discoveries, rather than stolen inventory, determine area and research progress.

Config owns eight species, two snacks, Normal/Moonlit/Golden variants, capture
balance, cooldowns, weather, map bounds, and disabled production raid settings.
`RollVariant(randomFloat, weather)` returns a variant string once per wild spawn;
the protected tutorial uses Normal. Trust takes three seconds of continuous
Sneak in range after lure readiness and adds up to 0.10 capture chance.
Feeding costs one preferred snack every 120 seconds, adds 10 bond up to 100,
and grants no coins or XP. Bond adds display income at 50 and 100.

## Modules

`World.Build(Config)` returns Root, Spawn, TutorialPosition, CreatureSpawns,
Sanctuaries, Jobs, Clues, Shop, Extraction, and PondGate. Spawn entries have
id/species/position. Sanctuary entries have Folder, BasePosition, Pedestals,
Spawn, and Sign. Jobs/clues expose stable Part references. Walking surfaces are
raised 0.05 studs above the existing baseplate.

`World.CreateCreature(Config, species, id, position, tutorialOwnerId?, variant?)`
returns a Model with PrimaryPart and EntityId/Species/Variant attributes on both
model and root. Optional TutorialOwnerId protects the first encounter.
`World.ShowDisplay(Config, pedestal, creature?)` creates or removes display
geometry and preserves UID/owner/species/variant attributes.
`World.DecorateSanctuary(sanctuary, level)` idempotently updates only habitat
decoration. `CreatureVisual.Build(Config, species)` provides a feet-origin
model; `CreatureVisual.ApplyVariant(Config, model, variant)` is idempotent and
does not change identity or create dynamic lights.

`GameService.Start(Config, World, PlayerData, Remotes)` returns Profiles, World,
RaidStates, SendState, Toast, RefreshDisplays, GetPlayerById, Distance,
AddCreature, RemoveCreature, AssignSanctuary, SetRaidHandler,
RegisterPlayerHooks, and Stop. Persistent companions are cosmetic models tied
to an owned UID; reservation, death, departure, reset, or ownership loss removes
the model, and a valid equipped selection returns on respawn. Equipping does
not alter display exposure.

`PlayerData.Load(player)` returns a profile or nil on unavailable/locked data.
`Save(player, profile, release?)` serializes bounded values under a session
lock. Profile schema v1 is backward compatible: legacy creatures become Normal
with zero bond/lastFed. equippedUid is retained only for owned inventory.
Runtime underscore fields are not persisted. Studio defaults to session-only
profiles; published profiles use locked UpdateAsync and periodic saves.

`RaidService.Start(Config, service, Remotes)` registers authoritative Studio
practice raids. The owner keeps the reserved entry until success. A completed
raid transfers the exact entry/UID/variant/bond/cooldown to the thief's vault and
clears the former owner's equippedUid; it grants no wild XP or discovery.
Disconnect, death, reset, map exit, timeout, and shutdown cancel pending theft.
Production raids remain disabled, including when a product ID is configured.

`Feedback.Start({Player, Gui, Config})` returns colon methods OnState,
OnMessage, SetOptions, and Destroy. It sends no requests and changes no valuable
state. Client idle animation stays close to the authoritative root and excludes
displays, companions, raid carries, and foreign tutorials. Work is bounded to
12 nearby wild creatures and 12 explicitly marked foliage parts at 30 Hz;
weather and celebrations have small shared budgets. ReducedMotion and LowEffects
are session preferences, with guidance preserved when effects are reduced.

## Verification boundary

`python3 tools/validate.py` compiles source, checks interface colors, executes
real modules behind platform stubs, and builds the Rojo place. These checks
cannot validate Roblox rendering, touch/controller input, physics, replication,
DataStore access, or purchases. Follow `tests/STUDIO-SMOKE.md` in Studio before
publishing. No external asset dependency or direct Studio MCP access is assumed.

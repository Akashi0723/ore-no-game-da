# Wildbound implementation contract

Shared modules are under ReplicatedStorage.Wildbound. Server modules are siblings under ServerScriptService.GameServer. Client entry is StarterPlayerScripts.GameClient.

## Networking

ReplicatedStorage.Wildbound.Remotes contains Request (RemoteEvent client to server) and Update (RemoteEvent server to client). Client requests `{action=string, target=string|number?, snack=string?, displayed=boolean?}`. Server returns Update messages `{kind="State", state=snapshot}`, `{kind="Toast", title=string, text=string, tone="success"|"error"|"info"}`, `{kind="Panel", panel="Shop"|"Journal"|"Sanctuary"|"Help"|"Raids"}`, `{kind="Capture", species=string}`. Never trust client value grants. Request state via action="Sync". Actions: Sneak (enabled boolean), Lure (target creature id, snack Berry|Seed), Befriend (target creature id), Job (target job id), Photo (target clue id), BuySnack (snack), SetDisplay (target creature uid, displayed), UpgradeSanctuary, BeginRaid (target creature uid, owner numeric userId), Net (target thief numeric userId). Raid module may add requests as documented.

Snapshot keys: coins number, xp number, level number, snacks={Berry=n,Seed=n}, discoveries={[species]=true}, creatures=array of {uid,species,displayed}, tutorialComplete boolean, pondUnlocked boolean, sanctuaryLevel number, weather string, nextWeatherIn number, event={name,goal,progress,reward,claimed}, objective={title,text}, saving="session"|"saved"|"loading"|"error", raid=table?; defaults for absent values. Raid snapshot fields should be communicated to UI agent.

## Config module

Config.Creatures keyed Mossbun, Lanternwing, Pebblehog, Dewfin, Mistfox. Each contains Name, Rarity, Color (Color3), Accent (Color3), Snack (Berry|Seed), XP, Hint, Weather ("Any"|"Rain"|"Dusk"|"Fog"), BaseChance, Zone ("Garden"|"Pond"), Description. Config.CreatureOrder array. Config.Snacks keyed Berry,Seed: Name,Price,UnlockLevel. Config.LevelXP=100, Config.StartCoins=30; Config.Raid={StudioFree=true,ProductId=0,ChaseSeconds=60,StealSeconds=6,NetHits=3,NetRange=12,NetCooldown=1.5}. Config.GetLevel(xp), Config.CaptureChance(species,level), Config.RarityColor(rarity). Optional numeric tunables can be added by root; tell peers.

## World module owned by world agent

World.Build(Config) returns world table: Root Model, Spawn CFrame, TutorialPosition Vector3, CreatureSpawns array of {id string,species string,position Vector3}, Sanctuaries array (8) of {Folder Model,BasePosition Vector3,Pedestals array BaseParts,Spawn CFrame,Sign TextLabel}, Jobs keyed id => {Part BasePart,Kind string,Label string,Cooldown number,Reward number}, Clues keyed id => {Part BasePart,Species string,Label string}, Shop BasePart, Extraction BasePart, PondGate BasePart. Garden centered near (0,0,0), sanctuaries arranged along x=90, pond z=-100. Walkable parts top at y=0; entities stand above it. Generated content goes ONLY under WildboundWorld; preserve existing world. Hide/remove generated SpawnLocation on destroy; do not change existing baseplate. Root may set lighting and relocate players in generated world.

World.CreateCreature(Config,species,id,position,tutorialOwnerId?) returns Model with PrimaryPart, Attribute EntityId=id, Species=species, TutorialOwnerId if set. Put under world.Root.Creatures (folder created in Build); no external assets. Includes a ProximityPrompt named Interaction on PrimaryPart; callbacks wired by game server. World.ShowDisplay(Config,pedestal,creature?) shows decorative creature at pedestal and Attributes OwnerUserId, CreatureUid, Species on its PrimaryPart when needed; game/raid owns prompts. World.CreateCreaturePortrait or helper isn't required; client creates its own ViewportFrame portrait geometry from shared CreatureVisual module if root provides it.

## GameService owned by gameplay agent

GameService.Start(Config,World,PlayerData,Remotes) returns service object. service.Profiles[player] holds loaded profile; service.World is built world. service.SendState(player), service.Toast(player,title,text,tone?), service.RefreshDisplays(player), service.GetPlayerById(id), service.Distance(player,partOrVector), service.AddCreature(player,species) returns owned entry, service.RemoveCreature(player,uid) returns entry?, service.AssignSanctuary(player). service.SetRaidHandler(fn) routes BeginRaid/Net/raid requests after common validation; service.RegisterPlayerHooks(join?,leave?) optional. Game service must cooperate with persistence; tell root of changes.

## PlayerData owned by root

PlayerData.Load(player) returns profile. PlayerData.Save(player,profile,release?) returns bool. PlayerData.Close() optional. Profile keys match snapshot, plus research table, coins, xp, snacks, discoveries, creatures, tutorialComplete, sanctuaryLevel. Runtime reserved fields can be stored under underscore-prefixed keys and are NOT persisted. Studio defaults to session storage; published games use session-locked UpdateAsync persistence. Mutation allowed only after successful profile load; unavailable stores must not overwrite a real profile. Raid transfers remain development-only until durable cross-profile ownership recovery is implemented.

## RaidService owned by raid agent

RaidService.Start(Config,GameService,Remotes) wires service.SetRaidHandler and updates service.RaidStates keyed Player. Start server-authoritative dev raids, notify both players; validate online owner, exposed creature, no concurrent reservations, distances, thief escape and net hits; cancel on departure/reset/death/shutdown. Real purchases are disabled when ProductId=0; no paid production ownership transfers without durable recovery. StudioFree available only RunService:IsStudio(). Raid module communicates snapshot fields to UI agent.

## UI owned by UI agent

Client reads Config and CreatureVisual when available. Client UI builds native Roblox ScreenGui. No web app. Warm paper/forest field-journal theme; compact HUD, responsive panels, viewport creature portraits, active objectives, coins/xp, weather countdown, shop, journal, vault/display, help, raid status. Phone landscape + desktop. Use safe insets, scrolling panels, focusable buttons, touch controls, error/pending states. All control actions call Request; state arrives via Update. Support keyboard J journal/B shop/V sanctuary/P photo/LeftShift hold Sneak/E context action/Q net. Context via nearby world attributes and prompts. Do not duplicate prompt callbacks if using ProximityPrompt Triggered; server wires world prompts. For context Lure/Befriend read creature attributes LuredUserId? server must define; UI agent can request target and server responds. Snapshots must be authoritative.

--!nonstrict
-- The server owns every coin, snack, capture roll, discovery, and displayed creature.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local GameService = {}

local function copyMap(source)
	local result = {}
	for key, value in pairs(source or {}) do
		if type(key) == "string" and (type(value) == "boolean" or type(value) == "number" or type(value) == "string") then
			result[key] = value
		end
	end
	return result
end

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 100
end

local function rootOf(player)
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then return nil end
	return root
end

function GameService.Start(Config, WorldModule, PlayerData, Remotes)
	local service = {
		Profiles = {},
		World = WorldModule.Build(Config),
		RaidStates = {},
		Weather = "Dusk",
		Running = true,
	}
	local world = service.World
	local random = Random.new()
	local entities = {}
	local spawns = {}
	local nextSpawn = {}
	local sanctuaries = {}
	local playerSanctuary = {}
	local sneak = {}
	local requestBuckets = {}
	local actionTimes = {}
	local jobTimes = {}
	local characterConnections = {}
	local companions = {}
	local connections = {}
	local joinHooks, leaveHooks = {}, {}
	local leaving = {}
	local loading = {}
	local saving = {}
	local raidHandler
	local shuttingDown = false
	local weatherCycle = Config.WeatherOrder or { "Clear", "Rain", "Dusk", "Fog" }
	local weatherIndex = table.find(weatherCycle, "Dusk") or 1
	local weatherSeconds = Config.WeatherSeconds or 100
	local weatherEnds = os.clock() + weatherSeconds
	local incomeAt = os.clock() + Config.DisplayIncomeSeconds
	local autosaveAt = os.clock() + Config.Persistence.SaveInterval
	local requestAction
	local spawnEntity
	local sendAll
	local refreshCompanion
	local feedCooldownSeconds = Config.FeedCooldownSeconds or 120
	local trustSeconds = Config.TrustSeconds or 3
	local trustBonus = Config.TrustChanceBonus or 0.10
	local questDefinitions = {
		{ id = "firstcatch", title = "A friend in the leaves", text = "Offer a berry, hold Sneak, and befriend your first Mossbun.", goal = 1, reward = 20, xpReward = 10 },
		{ id = "firstjob", title = "A little garden kindness", text = "Water a flowerbed or gather fallen leaves to earn snack money.", goal = 1, reward = 25, xpReward = 10 },
		{ id = "2photos", title = "Follow the little clues", text = "Photograph two different creature clues. Each reveals a field note.", goal = 2, reward = 30, xpReward = 15 },
		{ id = "3garden", title = "Meet the garden trio", text = "Discover Mossbun, Pebblehog, and Lanternwing. Lanternwing visits at dusk.", goal = 3, reward = 60, xpReward = 25 },
		{ id = "firstdisplay", title = "A place to call home", text = "Open Sanctuary and display one friend. Displays earn coins and can be raided while online.", goal = 1, reward = 30, xpReward = 10 },
		{ id = "pondcatch", title = "Beyond the garden gate", text = "Enter the unlocked pond and befriend any pond creature. Reedling is there in every weather.", goal = 1, reward = 80, xpReward = 40 },
	}

	local function dirty(profile)
		profile._dirty = true
		profile._revision = (profile._revision or 0) + 1
	end

	local function profileUsable(player, profile)
		if profile._readOnly then return false end
		if type(profile._lockAt) == "number" and os.time() - profile._lockAt >= Config.Persistence.LockSeconds then
			profile._readOnly = true
			if player.Parent == Players then
				player:Kick("The collection save connection expired. Please rejoin to load your progress safely.")
			end
			return false
		end
		return true
	end

	local function dayKey()
		return os.date("!%Y-%m-%d")
	end

	local function weeklyEvent()
		local week = math.floor(os.time() / (7 * 24 * 60 * 60))
		local themes = {
			{ name = "Garden companions", species = { "Mossbun", "Lanternwing", "Pebblehog" }, cosmetic = "Garden Naturalist" },
			{ name = "Rain & rustle", species = { "Mossbun", "Pebblehog", "Dewfin" }, cosmetic = "Rainwatcher" },
			{ name = "Twilight trails", species = { "Lanternwing", "Dewfin", "Mistfox" }, cosmetic = "Twilight Tracker" },
		}
		local theme = themes[week % #themes + 1]
		return { week = week, name = theme.name, species = theme.species, cosmetic = theme.cosmetic, endsAt = (week + 1) * 7 * 24 * 60 * 60 }
	end

	local function weeklyState(profile)
		local event = weeklyEvent()
		local prefix = "__event_" .. event.week .. "_"
		local progress = 0
		for _, species in ipairs(event.species) do if profile.research[prefix .. species] then progress += 1 end end
		return {
			name = event.name, goal = #event.species, progress = progress, reward = 100,
			claimed = profile.research[prefix .. "claimed"] == true,
			cosmetic = event.cosmetic, species = table.clone(event.species), endsAt = event.endsAt,
		}
	end

	local function dailyState(profile)
		local prefix = "__daily_" .. dayKey() .. "_"
		local progress = 0
		for clueId in pairs(world.Clues) do if profile.research[prefix .. clueId] then progress += 1 end end
		return { title = "Daily field notes", goal = 2, progress = math.min(2, progress), claimed = profile.research[prefix .. "claimed"] == true, reward = 30 }
	end

	local function recordDailyPhoto(player, clueId)
		local profile = service.Profiles[player]
		local prefix = "__daily_" .. dayKey() .. "_"
		if profile.research[prefix .. clueId] then return end
		profile.research[prefix .. clueId] = true
		dirty(profile)
		if dailyState(profile).progress >= 2 and not profile.research[prefix .. "claimed"] then
			profile.research[prefix .. "claimed"] = true
			profile.coins = math.min(1000000000, profile.coins + 30)
			profile.xp = math.min(1000000, profile.xp + 20)
			service.Toast(player, "Daily field notes complete", "+30 coins and +20 Taming XP. New research arrives tomorrow.", "success")
		end
	end

	local function recordEventCapture(player, species)
		local profile = service.Profiles[player]
		local event = weeklyEvent()
		if not table.find(event.species, species) then return end
		local prefix = "__event_" .. event.week .. "_"
		profile.research[prefix .. species] = true
		local status = weeklyState(profile)
		if status.progress >= status.goal and not profile.research[prefix .. "claimed"] then
			profile.research[prefix .. "claimed"] = true
			profile.coins = math.min(1000000000, profile.coins + 100)
			profile.research["__title_" .. event.cosmetic] = true
			player:SetAttribute("NaturalistTitle", event.cosmetic)
			service.Toast(player, event.name .. " complete", "+100 coins and the " .. event.cosmetic .. " title unlocked.", "success")
			service.RefreshDisplays(player)
		end
	end

	local function pruneResearch(profile)
		local today = dayKey()
		local week = weeklyEvent().week
		for key in pairs(profile.research) do
			local date = string.match(key, "^__daily_(%d%d%d%d%-%d%d%-%d%d)_")
			local eventWeek = tonumber(string.match(key, "^__event_(%d+)_"))
			if date and date ~= today or eventWeek and eventWeek < week - 1 then profile.research[key] = nil end
		end
	end
	local researchDay = dayKey()

	local function countGarden(profile)
		local count = 0
		for species, found in pairs(profile.discoveries) do
			if found and Config.Creatures[species] and Config.Creatures[species].Zone == "Garden" then
				count += 1
			end
		end
		return count
	end

	local function countDiscoveries(profile)
		local count = 0
		for species, found in pairs(profile.discoveries) do
			if found and Config.Creatures[species] then count += 1 end
		end
		return count
	end

	local function findOwned(profile, uid)
		for _, entry in ipairs(profile.creatures) do
			if entry.uid == uid then return entry end
		end
		return nil
	end

	local function questProgress(profile, id)
		if id == "firstcatch" then return countDiscoveries(profile) > 0 and 1 or 0 end
		if id == "firstjob" then return profile.research.__trail_job and 1 or 0 end
		if id == "2photos" then
			local count = 0
			for clueId in pairs(world.Clues) do if profile.research[clueId] then count += 1 end end
			return math.min(2, count)
		end
		if id == "3garden" then return math.min(3, countGarden(profile)) end
		if id == "firstdisplay" then return profile.research.__trail_display and 1 or 0 end
		if id == "pondcatch" then
			for species, found in pairs(profile.discoveries) do
				if found and Config.Creatures[species] and Config.Creatures[species].Zone == "Pond" then return 1 end
			end
		end
		return 0
	end

	local function waypoint(position)
		if typeof(position) ~= "Vector3" then return nil end
		return { x = position.X, y = position.Y, z = position.Z }
	end

	local function questWaypoint(player, profile, id)
		if id == "firstcatch" then return waypoint(world.TutorialPosition) end
		if id == "firstjob" then
			for _, job in pairs(world.Jobs) do return waypoint(job.Part.Position) end
		elseif id == "2photos" or id == "3garden" then
			for clueId, clue in pairs(world.Clues) do
				local definition = Config.Creatures[clue.Species]
				if definition and definition.Zone == "Garden" and (id == "2photos" and not profile.research[clueId] or id == "3garden" and not profile.discoveries[clue.Species]) then
					return waypoint(clue.Part.Position)
				end
			end
		elseif id == "firstdisplay" or id == "complete" then
			local sanctuary = playerSanctuary[player]
			return sanctuary and waypoint(sanctuary.BasePosition) or nil
		elseif id == "pondcatch" then
			return world.PondGate and waypoint(world.PondGate.Position) or nil
		end
		return nil
	end

	local function questState(player, profile)
		for _, definition in ipairs(questDefinitions) do
			if not profile.research["__trail_claimed_" .. definition.id] then
				return {
					id = definition.id, title = definition.title, text = definition.text,
					progress = questProgress(profile, definition.id), goal = definition.goal,
					reward = definition.reward, xpReward = definition.xpReward, complete = false,
					waypoint = questWaypoint(player, profile, definition.id),
				}
			end
		end
		return { id = "complete", title = "Naturalist trail complete", text = "Explore changing weather, bond with companions, and grow your sanctuary.", progress = #questDefinitions, goal = #questDefinitions, reward = 0, xpReward = 0, complete = true, waypoint = questWaypoint(player, profile, "complete") }
	end

	local function advanceQuests(player)
		local profile = service.Profiles[player]
		if not profile or not profileUsable(player, profile) then return end
		-- Called only after validated gameplay mutations, never by Sync/SendState.
		-- Completed earlier milestones can advance in sequence; each reward is permanent.
		for _, definition in ipairs(questDefinitions) do
			local key = "__trail_claimed_" .. definition.id
			if not profile.research[key] then
				if questProgress(profile, definition.id) < definition.goal then break end
				profile.research[key] = true
				profile.coins = math.min(1000000000, profile.coins + definition.reward)
				profile.xp = math.min(1000000, profile.xp + definition.xpReward)
				dirty(profile)
				service.Toast(player, definition.title .. " complete", "+" .. definition.reward .. " coins · +" .. definition.xpReward .. " Taming XP", "success")
				Remotes.Update:FireClient(player, { kind = "QuestComplete", id = definition.id, title = definition.title, coins = definition.reward, xp = definition.xpReward })
			end
		end
	end

	local function captureChance(entity, profile, lure)
		if entity.owner then return 1 end
		return math.clamp(Config.CaptureChance(entity.species, Config.GetLevel(profile.xp)) + (lure and lure.trust or 0) * trustBonus, 0, 0.99)
	end

	local function capacity(profile)
		return Config.BaseDisplayCapacity + math.max(0, profile.sanctuaryLevel - 1)
	end

	local function upgradeCost(profile)
		return profile.sanctuaryLevel < Config.MaxSanctuaryLevel and profile.sanctuaryLevel * Config.SanctuaryUpgradeBaseCost or 0
	end

	local function objective(player, profile)
		return questState(player, profile)
	end

	function service.GetPlayerById(id)
		if type(id) ~= "number" or id ~= id or math.abs(id) > 9007199254740991 or id ~= math.floor(id) then return nil end
		return Players:GetPlayerByUserId(id)
	end

	function service.Distance(player, target)
		local root = rootOf(player)
		if not root then return math.huge end
		local position
		if typeof(target) == "Vector3" then
			position = target
		elseif typeof(target) == "Instance" and target:IsA("BasePart") then
			position = target.Position
		elseif typeof(target) == "Instance" and target:IsA("Model") and target.PrimaryPart then
			position = target.PrimaryPart.Position
		else
			return math.huge
		end
		return (root.Position - position).Magnitude
	end

	function service.Toast(player, title, text, tone)
		if player.Parent == Players then
			Remotes.Update:FireClient(player, { kind = "Toast", title = title, text = text, tone = tone or "info" })
		end
	end

	local function openPanel(player, panel)
		Remotes.Update:FireClient(player, { kind = "Panel", panel = panel })
	end

	function service.SendState(player)
		local profile = service.Profiles[player]
		if not profile or player.Parent ~= Players then return end
		local creatures = {}
		for _, creature in ipairs(profile.creatures) do
			table.insert(creatures, {
				uid = creature.uid,
				species = creature.species,
				displayed = creature.displayed == true,
				reserved = profile._reservedCreatures and profile._reservedCreatures[creature.uid] == true or false,
				variant = creature.variant or "Normal",
				bond = creature.bond or 0,
				lastFed = creature.lastFed or 0,
				feedReadyIn = math.max(0, (creature.lastFed or 0) + feedCooldownSeconds - os.time()),
			})
		end
		local now = workspace:GetServerTimeNow()
		local lures = {}
		for id, entity in pairs(entities) do
			local lure = entity.lures[player.UserId]
			if lure and lure.expiresAt > now then
				lures[id] = { readyIn = math.max(0, lure.readyAt - now), expiresIn = lure.expiresAt - now, trust = lure.trust or 0, chance = captureChance(entity, profile, lure) }
			end
		end
		local research = {}
		local titles = {}
		for id, done in pairs(profile.research) do
			if done and string.sub(id, 1, 2) ~= "__" then research[id] = true end
			if done and string.sub(id, 1, 8) == "__title_" then table.insert(titles, string.sub(id, 9)) end
		end
		table.sort(titles)
		local raid
		if service.RaidStates[player] then
			raid = {}
			for key, value in pairs(service.RaidStates[player]) do
				if type(value) ~= "function" and typeof(value) ~= "Instance" then raid[key] = value end
			end
		end
		local snapshot = {
			coins = profile.coins,
			xp = profile.xp,
			level = Config.GetLevel(profile.xp),
			tamingTool = Config.GetLevel(profile.xp) >= 5 and "Naturalist kit" or Config.GetLevel(profile.xp) >= 3 and "Tracker kit" or "Starter kit",
			titles = titles,
			snacks = copyMap(profile.snacks),
			discoveries = copyMap(profile.discoveries),
			creatures = creatures,
			equippedUid = profile.equippedUid,
			feedCooldownSeconds = feedCooldownSeconds,
			tutorialComplete = profile.tutorialComplete,
			pondUnlocked = countGarden(profile) >= 3,
			sanctuaryLevel = profile.sanctuaryLevel,
			sanctuaryCapacity = capacity(profile),
			sanctuaryUpgradeCost = upgradeCost(profile),
			weather = service.Weather,
			nextWeatherIn = math.max(0, math.ceil(weatherEnds - os.clock())),
			event = weeklyState(profile),
			daily = dailyState(profile),
			objective = objective(player, profile),
			questline = questState(player, profile),
			saving = profile._saving or (RunService:IsStudio() and "session" or "saved"),
			raid = raid,
			lures = lures,
			research = research,
			sneaking = sneak[player] == true,
		}
		Remotes.Update:FireClient(player, { kind = "State", state = snapshot })
	end

	sendAll = function()
		for player in pairs(service.Profiles) do service.SendState(player) end
	end

	local function refreshMovement(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local speed = sneak[player] and (Config.SneakSpeed or 7) or (Config.WalkSpeed or 16)
		local slow = player:GetAttribute("RaidSlowedUntil")
		if type(slow) == "number" and slow > os.clock() then speed = math.min(speed, 8) end
		humanoid.WalkSpeed = speed
		player:SetAttribute("Sneaking", sneak[player] == true)
	end

	local function setEntityAttribute(entity, name, value)
		if entity.model and entity.model.Parent then
			entity.model:SetAttribute(name, value)
			if entity.model.PrimaryPart then entity.model.PrimaryPart:SetAttribute(name, value) end
		end
	end

	local function refreshLureAttribute(entity)
		local newest
		local now = workspace:GetServerTimeNow()
		for userId, lure in pairs(entity.lures) do
			if lure.expiresAt <= now then
				entity.lures[userId] = nil
				if entity.owner then
					local player = service.GetPlayerById(userId)
					local profile = player and service.Profiles[player]
					if profile and not profile._readOnly then
						profile.snacks[lure.snack] = math.min(999, profile.snacks[lure.snack] + 1)
						dirty(profile)
					end
				end
			elseif not newest or lure.readyAt > newest.readyAt then
				newest = { userId = userId, readyAt = lure.readyAt, expiresAt = lure.expiresAt }
			end
		end
		setEntityAttribute(entity, "LuredUserId", newest and newest.userId or nil)
		setEntityAttribute(entity, "LureReadyAt", newest and newest.readyAt or nil)
		setEntityAttribute(entity, "LureExpiresAt", newest and newest.expiresAt or nil)
	end

	local function resetTrust(player)
		for _, entity in pairs(entities) do
			local lure = entity.lures[player.UserId]
			if lure then lure.trust = 0; lure.trustStartedAt = nil end
		end
	end

	local function updateTrust(player, entity, lure, now)
		if now >= lure.readyAt and now < lure.expiresAt and sneak[player] and service.Distance(player, entity.model) <= Config.BefriendRange then
			lure.trustStartedAt = lure.trustStartedAt or now
			lure.trust = math.clamp((now - lure.trustStartedAt) / trustSeconds, 0, 1)
		else
			lure.trust, lure.trustStartedAt = 0, nil
		end
	end

	local function destroyEntity(id, respawnDelay)
		local entity = entities[id]
		if not entity then return end
		entities[id] = nil
		if entity.model then entity.model:Destroy() end
		if entity.promptConnection then entity.promptConnection:Disconnect() end
		if not entity.owner and spawns[id] then nextSpawn[id] = os.clock() + (respawnDelay or 45) end
	end

	local function firstCreature(player)
		local id = "tutorial_" .. tostring(player.UserId)
		if not service.Profiles[player] or service.Profiles[player].tutorialComplete then return end
		if entities[id] then return end
		spawnEntity(id, "Mossbun", world.TutorialPosition, player.UserId)
	end

	spawnEntity = function(id, species, position, owner)
		if entities[id] or not Config.Creatures[species] then return end
		-- Roll once per authoritative spawn. A lure or capture never rerolls a variant.
		local variant = "Normal"
		if not owner and Config.RollVariant then
			variant = Config.RollVariant(random:NextNumber(), service.Weather)
			if type(variant) ~= "string" or not Config.Variants or not Config.Variants[variant] then variant = "Normal" end
		end
		local model = WorldModule.CreateCreature(Config, species, id, position, owner, variant)
		if not model then return end
		if not model.Parent then model.Parent = world.Root:FindFirstChild("Creatures") or world.Root end
		local entity = { id = id, species = species, position = position, owner = owner, variant = variant, model = model, lures = {} }
		entities[id] = entity
		setEntityAttribute(entity, "EntityId", id)
		setEntityAttribute(entity, "Species", species)
		setEntityAttribute(entity, "Variant", variant)
		if owner then setEntityAttribute(entity, "TutorialOwnerId", owner) end
		local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Interaction")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Offer snack / Befriend"
			prompt.ObjectText = (variant ~= "Normal" and variant .. " " or "") .. Config.Creatures[species].Name
			entity.promptConnection = prompt.Triggered:Connect(function(player)
				local lure = entity.lures[player.UserId]
				requestAction(player, { action = lure and "Befriend" or "Lure", target = id, snack = Config.Creatures[species].Snack })
			end)
		end
		if variant ~= "Normal" then
			for player in pairs(service.Profiles) do
				if service.Distance(player, model) <= 65 then service.Toast(player, "An unusual visitor", "A " .. variant .. " " .. Config.Creatures[species].Name .. " has appeared nearby.", "success") end
			end
		end
	end

	local function newPrompt(part, name, text, object)
		local prompt = part:FindFirstChild(name)
		if not prompt or not prompt:IsA("ProximityPrompt") then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = name
			prompt.Parent = part
		end
		prompt.ActionText = text
		prompt.ObjectText = object
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		return prompt
	end

	local function clearCompanion(player)
		local companion = companions[player]
		if companion then
			if companion.model then companion.model:Destroy() end
			companions[player] = nil
		end
	end

	local function prepareCompanion(player, model, entry, permanent)
		-- A follower is cosmetic. It never changes ownership or exposes the vault.
		model.Name = "Companion_" .. player.UserId
		for _, target in ipairs({ model, model.PrimaryPart }) do
			if target then
				for _, attribute in ipairs({ "EntityId", "TutorialOwnerId", "LuredUserId", "LureReadyAt", "LureExpiresAt", "Action", "Target" }) do target:SetAttribute(attribute, nil) end
				target:SetAttribute("CompanionOwnerUserId", player.UserId)
				target:SetAttribute("CompanionUid", entry.uid)
				target:SetAttribute("Variant", entry.variant or "Normal")
			end
		end
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("ProximityPrompt") then child:Destroy() end
			if child:IsA("BasePart") then child.Anchored = true; child.CanCollide = false; child.CanTouch = false; child.CanQuery = false end
		end
		model.Parent = world.Root
		companions[player] = { model = model, expiresAt = permanent and math.huge or os.clock() + 20, character = player.Character, species = entry.species, uid = entry.uid, permanent = permanent == true }
	end

	local function followNewestFriend(player, entity, entry)
		if service.Profiles[player].equippedUid then return end
		clearCompanion(player)
		local ok, model = pcall(function() return entity.model:Clone() end)
		if not ok or not model then return end
		local prepared = pcall(prepareCompanion, player, model, entry, false)
		if not prepared then model:Destroy() end
	end

	refreshCompanion = function(player)
		local profile = service.Profiles[player]
		if not profile then clearCompanion(player); return end
		local uid = profile.equippedUid
		if not uid then
			if companions[player] and companions[player].permanent then clearCompanion(player) end
			return
		end
		local entry = findOwned(profile, uid)
		if not entry then
			clearCompanion(player)
			if profileUsable(player, profile) then profile.equippedUid = nil; dirty(profile) end
			return
		end
		if profile._reservedCreatures and profile._reservedCreatures[uid] then clearCompanion(player); return end
		local root = rootOf(player)
		if not root then clearCompanion(player); return end
		local companion = companions[player]
		if companion and companion.permanent and companion.uid == uid and companion.character == player.Character and companion.model.Parent then return end
		clearCompanion(player)
		local ok, model = pcall(WorldModule.CreateCreature, Config, entry.species, "companion_" .. tostring(player.UserId), root.Position, nil, entry.variant or "Normal")
		if not ok or not model then return end
		local prepared = pcall(prepareCompanion, player, model, entry, true)
		if not prepared then model:Destroy() end
	end

	function service.RefreshDisplays(player)
		local profile = service.Profiles[player]
		local sanctuary = playerSanctuary[player]
		if not profile or not sanctuary then return end
		refreshCompanion(player)
		if WorldModule.DecorateSanctuary then WorldModule.DecorateSanctuary(sanctuary, profile.sanctuaryLevel) end
		local displayed = {}
		for _, entry in ipairs(profile.creatures) do
			if entry.displayed then table.insert(displayed, entry) end
		end
		for index, pedestal in ipairs(sanctuary.Pedestals) do
			local entry = displayed[index]
			pedestal:SetAttribute("OwnerUserId", player.UserId)
			pedestal:SetAttribute("CreatureUid", entry and entry.uid or nil)
			pedestal:SetAttribute("Species", entry and entry.species or nil)
			pedestal:SetAttribute("Variant", entry and (entry.variant or "Normal") or nil)
			pedestal:SetAttribute("Bond", entry and (entry.bond or 0) or nil)
			pedestal:SetAttribute("DisplayActive", entry ~= nil)
			pedestal:SetAttribute("SlotUnlocked", index <= capacity(profile))
			local display = WorldModule.ShowDisplay(Config, pedestal, entry)
			-- World display geometry is cosmetic; the pedestal is the stable raid target.
			local prompt = pedestal:FindFirstChild("RaidInteraction")
			if entry then
				prompt = newPrompt(pedestal, "RaidInteraction", "Raid displayed creature", Config.Creatures[entry.species].Name)
				prompt:SetAttribute("WildboundWired", true)
				prompt.Enabled = true
				if not prompt:GetAttribute("Connected") then
					prompt:SetAttribute("Connected", true)
					table.insert(connections, prompt.Triggered:Connect(function(thief)
						local uid = pedestal:GetAttribute("CreatureUid")
						local ownerId = pedestal:GetAttribute("OwnerUserId")
						if thief.UserId == ownerId then
							openPanel(thief, "Sanctuary")
						else
							requestAction(thief, { action = "BeginRaid", target = uid, owner = ownerId })
						end
					end))
				end
			elseif prompt then
				prompt.Enabled = false
			end
			if typeof(display) == "Instance" and display:IsA("Model") and display.PrimaryPart and entry then
				display.PrimaryPart:SetAttribute("OwnerUserId", player.UserId)
				display.PrimaryPart:SetAttribute("CreatureUid", entry.uid)
				display.PrimaryPart:SetAttribute("Species", entry.species)
			end
		end
		if sanctuary.Sign then
			local title = player:GetAttribute("NaturalistTitle")
			sanctuary.Sign.Text = player.DisplayName .. "'s sanctuary\n" .. (title and title .. " · " or "") .. #displayed .. "/" .. capacity(profile) .. " displayed · vault is safe"
		end
	end

	function service.AssignSanctuary(player)
		if playerSanctuary[player] then return playerSanctuary[player] end
		for index, sanctuary in ipairs(world.Sanctuaries) do
			if not sanctuaries[index] then
				sanctuaries[index] = player
				playerSanctuary[player] = sanctuary
				sanctuary.Folder:SetAttribute("OwnerUserId", player.UserId)
				sanctuary.Folder:SetAttribute("SanctuaryIndex", index)
				service.RefreshDisplays(player)
				return sanctuary
			end
		end
		return nil
	end

	function service.AddCreature(player, species, variant)
		local profile = service.Profiles[player]
		if not profile or not profileUsable(player, profile) or not Config.Creatures[species] or #profile.creatures >= Config.MaxCreatures then return nil end
		if type(variant) ~= "string" or not Config.Variants or not Config.Variants[variant] then variant = "Normal" end
		local entry = { uid = HttpService:GenerateGUID(false), species = species, displayed = false, variant = variant, bond = 0, lastFed = 0 }
		table.insert(profile.creatures, entry)
		dirty(profile)
		return entry
	end

	function service.RemoveCreature(player, uid)
		local profile = service.Profiles[player]
		if not profile or not profileUsable(player, profile) or profile._reservedCreatures and profile._reservedCreatures[uid] then return nil end
		for index, entry in ipairs(profile.creatures) do
			if entry.uid == uid then
				table.remove(profile.creatures, index)
				if profile.equippedUid == uid then profile.equippedUid = nil; clearCompanion(player) end
				dirty(profile)
				return entry
			end
		end
		return nil
	end

	function service.SetRaidHandler(handler)
		raidHandler = handler
	end

	function service.RegisterPlayerHooks(join, leave)
		if join then
			table.insert(joinHooks, join)
			for player in pairs(service.Profiles) do task.spawn(join, player) end
		end
		if leave then table.insert(leaveHooks, leave) end
	end

	local function callHooks(hooks, player)
		for _, hook in ipairs(hooks) do
			local ok, err = pcall(hook, player)
			if not ok then warn("[Wildbound] Player hook failed: " .. tostring(err)) end
		end
	end

	local function actionLimit(player, action, seconds)
		local last = actionTimes[player]
		if not last then last = {}; actionTimes[player] = last end
		local now = os.clock()
		if now - (last[action] or -math.huge) < seconds then return false end
		last[action] = now
		return true
	end

	local function requestLimit(player)
		local now = os.clock()
		local bucket = requestBuckets[player]
		if not bucket then bucket = { tokens = 20, at = now }; requestBuckets[player] = bucket end
		bucket.tokens = math.min(20, bucket.tokens + (now - bucket.at) * 8)
		bucket.at = now
		if bucket.tokens < 1 then return false end
		bucket.tokens -= 1
		return true
	end

	local function eligibleEntity(player, id, range)
		local entity = validId(id) and entities[id]
		if not entity or not entity.model or not entity.model.Parent then
			service.Toast(player, "Creature moved on", "Explore for another clue or wait for a new appearance.", "info")
			return nil
		end
		if entity.owner and entity.owner ~= player.UserId then
			service.Toast(player, "First encounter", "That Mossbun is helping another player learn. Find a wild one nearby.", "info")
			return nil
		end
		local profile = service.Profiles[player]
		if Config.Creatures[entity.species].Zone == "Pond" and countGarden(profile) < 3 then
			service.Toast(player, "Pond locked", "Befriend three different garden creatures first.", "error")
			return nil
		end
		if service.Distance(player, entity.model) > range then
			service.Toast(player, "Get a little closer", "Move near the creature, then hold Sneak.", "info")
			return nil
		end
		return entity
	end

	local function offerSnack(player, request)
		if not actionLimit(player, "Lure", 0.65) then return end
		local entity = eligibleEntity(player, request.target, Config.LureRange)
		if not entity then return end
		local profile = service.Profiles[player]
		local definition = Config.Creatures[entity.species]
		local snack = request.snack
		if not validId(snack) or not Config.Snacks[snack] then return end
		if snack ~= definition.Snack then
			service.Toast(player, "Try its favorite snack", definition.Name .. " likes " .. Config.Snacks[definition.Snack].Name .. ". Your snack was not used.", "info")
			return
		end
		if Config.GetLevel(profile.xp) < Config.Snacks[snack].UnlockLevel then
			service.Toast(player, "Snack locked", "Reach Taming level " .. Config.Snacks[snack].UnlockLevel .. " first.", "error")
			return
		end
		local now = workspace:GetServerTimeNow()
		refreshLureAttribute(entity)
		local oldLure = entity.lures[player.UserId]
		if oldLure and oldLure.expiresAt > now then
			service.Toast(player, "Snack already offered", "Give it a moment, hold Sneak, then choose Befriend.", "info")
			return
		end
		if (profile.snacks[snack] or 0) < 1 then
			service.Toast(player, "Out of snacks", "Buy " .. Config.Snacks[snack].Name .. " at the stall. Garden jobs earn coins.", "error")
			return
		end
		profile.snacks[snack] -= 1
		local lureSeconds = math.max(1, Config.LureSeconds - math.max(0, Config.GetLevel(profile.xp) - 1) * 0.1)
		entity.lures[player.UserId] = { snack = snack, readyAt = now + lureSeconds, expiresAt = now + Config.LureLifetime, trust = 0 }
		dirty(profile)
		refreshLureAttribute(entity)
		service.Toast(player, "A curious visitor", "Hold Sneak nearby. A calm approach builds trust and improves your chance.", "info")
		Remotes.Update:FireClient(player, { kind = "Lure", target = entity.id, species = entity.species, position = waypoint(entity.model.PrimaryPart.Position), readyIn = lureSeconds })
		service.SendState(player)
	end

	local function befriend(player, request)
		if not actionLimit(player, "Befriend", 0.75) then return end
		local entity = eligibleEntity(player, request.target, Config.BefriendRange)
		if not entity then return end
		local profile = service.Profiles[player]
		local definition = Config.Creatures[entity.species]
		local now = workspace:GetServerTimeNow()
		local lure = entity.lures[player.UserId]
		if not lure or lure.expiresAt <= now then
			service.Toast(player, "Offer a snack first", "Choose " .. Config.Snacks[definition.Snack].Name .. " to lure this creature out.", "info")
			return
		end
		if now < lure.readyAt then
			service.Toast(player, "Let it settle", "The creature is still approaching its snack.", "info")
			return
		end
		if #profile.creatures >= Config.MaxCreatures then
			service.Toast(player, "Collection is full", "Your vault holds up to " .. Config.MaxCreatures .. " creatures.", "error")
			return
		end
		if not sneak[player] then
			-- First-session mistakes never strand the player without a snack.
			entity.lures[player.UserId] = nil
			if entity.owner then profile.snacks[lure.snack] += 1; dirty(profile) end
			refreshLureAttribute(entity)
			service.Toast(player, "Too quick!", entity.owner and "Your berry is returned. Hold Sneak before befriending." or "The creature backed away. Hold Sneak and offer another snack.", "error")
			service.SendState(player)
			return
		end
		local chance = captureChance(entity, profile, lure)
		entity.lures[player.UserId] = nil
		if random:NextNumber() > chance then
			refreshLureAttribute(entity)
			service.Toast(player, "Not quite friends yet", definition.Name .. " is shy. Another favorite snack may help; Taming levels improve your chance.", "info")
			service.SendState(player)
			return
		end
		-- Check and mutation are synchronous: two requests cannot both own this wild spawn.
		if entities[entity.id] ~= entity then return end
		local previousGarden = countGarden(profile)
		local newDiscovery = profile.discoveries[entity.species] ~= true
		local entry = service.AddCreature(player, entity.species, entity.variant)
		if not entry then return end
		profile.discoveries[entity.species] = true
		profile.xp = math.min(1000000, profile.xp + definition.XP)
		local tutorial = entity.owner ~= nil
		if tutorial then profile.tutorialComplete = true end
		local respawnSeconds = definition.RespawnSeconds
		followNewestFriend(player, entity, entry)
		destroyEntity(entity.id, respawnSeconds)
		dirty(profile)
		service.RefreshDisplays(player)
		Remotes.Update:FireClient(player, { kind = "Capture", species = entry.species, uid = entry.uid, variant = entry.variant, bond = entry.bond, newDiscovery = newDiscovery, position = waypoint(entity.position) })
		service.Toast(player, "Befriended " .. (entry.variant ~= "Normal" and entry.variant .. " " or "") .. definition.Name, "Safely stored in your vault. +" .. definition.XP .. " Taming XP", "success")
		recordEventCapture(player, entity.species)
		if previousGarden < 3 and countGarden(profile) >= 3 then
			service.Toast(player, "The pond is open!", "Visit the garden's pond gate to discover rain and fog creatures.", "success")
		end
		if countDiscoveries(profile) >= #Config.CreatureOrder and not profile.research.__fieldbookClaimed then
			profile.research.__fieldbookClaimed = true
			profile.coins = math.min(1000000000, profile.coins + 120)
			service.Toast(player, "First Fieldbook complete", "All " .. #Config.CreatureOrder .. " creatures discovered. Your 120-coin collection reward is claimed.", "success")
		end
		advanceQuests(player)
		sendAll()
	end

	local function doJob(player, target)
		if not validId(target) then return end
		local job = world.Jobs[target]
		if not job or service.Distance(player, job.Part) > Config.JobRange then return end
		local profile = service.Profiles[player]
		local times = jobTimes[player]
		if not times then times = {}; jobTimes[player] = times end
		local remaining = (times[target] or -math.huge) + job.Cooldown - os.clock()
		if remaining > 0 then
			service.Toast(player, "Garden recovering", "Try this job again in " .. math.ceil(remaining) .. " seconds, or visit another bed.", "info")
			return
		end
		times[target] = os.clock()
		profile.coins = math.min(1000000000, profile.coins + job.Reward)
		profile.research.__trail_job = true
		dirty(profile)
		service.Toast(player, job.Label, "+" .. job.Reward .. " coins. Buy snacks at the garden stall.", "success")
		advanceQuests(player)
		service.SendState(player)
	end

	local function photograph(player, target)
		if not validId(target) then return end
		local clue = world.Clues[target]
		local photoRange = Config.PhotoRange + math.min(8, math.max(0, Config.GetLevel(service.Profiles[player].xp) - 1) * 2)
		if not clue or service.Distance(player, clue.Part) > photoRange then
			service.Toast(player, "Move near a clue", "Look for footprints, glowing wings or unusual stones.", "info")
			return
		end
		local profile = service.Profiles[player]
		local definition = Config.Creatures[clue.Species]
		if definition.Zone == "Pond" and countGarden(profile) < 3 then return end
		recordDailyPhoto(player, target)
		Remotes.Update:FireClient(player, { kind = "Photo", target = target, species = clue.Species, position = waypoint(clue.Part.Position), newResearch = profile.research[target] ~= true })
		if profile.research[target] then
			service.Toast(player, definition.Name .. " clue", definition.Hint, "info")
			service.SendState(player)
			return
		end
		profile.research[target] = true
		profile.coins = math.min(1000000000, profile.coins + (Config.PhotoReward or 15))
		profile.xp = math.min(1000000, profile.xp + (Config.PhotoXP or 15))
		dirty(profile)
		service.Toast(player, "Clue photographed", "+" .. (Config.PhotoReward or 15) .. " coins · " .. definition.Hint, "success")
		advanceQuests(player)
		service.SendState(player)
	end

	local function buySnack(player, snack)
		if not validId(snack) or not Config.Snacks[snack] or not actionLimit(player, "BuySnack", 0.3) then return end
		local profile = service.Profiles[player]
		local definition = Config.Snacks[snack]
		if Config.GetLevel(profile.xp) < definition.UnlockLevel then
			service.Toast(player, "Snack locked", "Reach Taming level " .. definition.UnlockLevel .. " to buy " .. definition.Name .. ".", "error")
			return
		end
		if profile.coins < definition.Price then
			service.Toast(player, "Need more coins", "Water flowers, gather leaves or photograph a new clue.", "error")
			return
		end
		if profile.snacks[snack] >= 999 then return end
		profile.coins -= definition.Price
		profile.snacks[snack] += 1
		dirty(profile)
		service.Toast(player, "Snack packed", "+1 " .. definition.Name .. " for " .. definition.Price .. " coins.", "success")
		service.SendState(player)
	end

	local function setDisplay(player, request)
		if not validId(request.target) or type(request.displayed) ~= "boolean" then return end
		local profile = service.Profiles[player]
		if profile._reservedCreatures and profile._reservedCreatures[request.target] then
			service.Toast(player, "Raid in progress", "Recover this creature before changing its display.", "error")
			return
		end
		local total = 0
		local entry
		for _, item in ipairs(profile.creatures) do
			if item.displayed then total += 1 end
			if item.uid == request.target then entry = item end
		end
		if not entry or entry.displayed == request.displayed then return end
		if request.displayed and total >= capacity(profile) then
			service.Toast(player, "Display slots full", "Store a displayed creature safely or expand your sanctuary.", "error")
			return
		end
		entry.displayed = request.displayed
		if request.displayed then profile.research.__trail_display = true end
		dirty(profile)
		service.RefreshDisplays(player)
		service.Toast(player, request.displayed and "Now on display" or "Stored safely", request.displayed and "This creature earns coins and is exposed to online raids." or "Vault creatures cannot be raided.", request.displayed and "info" or "success")
		advanceQuests(player)
		service.SendState(player)
	end

	local function upgradeSanctuary(player)
		if not actionLimit(player, "UpgradeSanctuary", 0.8) then return end
		local profile = service.Profiles[player]
		local price = upgradeCost(profile)
		if price <= 0 then
			service.Toast(player, "Fully expanded", "All five display habitats are unlocked. Your vault remains safe.", "info")
			return
		end
		if profile.coins < price then
			service.Toast(player, "Save for an expansion", "You need " .. price .. " coins for another display slot.", "error")
			return
		end
		profile.coins -= price
		profile.sanctuaryLevel += 1
		dirty(profile)
		service.RefreshDisplays(player)
		service.Toast(player, "Sanctuary expanded", "Another display habitat is ready.", "success")
		service.SendState(player)
	end

	local function equipCompanion(player, target)
		if target ~= nil and not validId(target) then return end
		if not actionLimit(player, "EquipCompanion", 0.35) then return end
		local profile = service.Profiles[player]
		local entry = target and findOwned(profile, target) or nil
		if target and not entry then return end
		if target and profile._reservedCreatures and profile._reservedCreatures[target] then
			service.Toast(player, "Raid in progress", "Recover this friend before changing companions.", "error")
			return
		end
		if profile.equippedUid == target then return end
		profile.equippedUid = target
		dirty(profile)
		clearCompanion(player)
		refreshCompanion(player)
		service.Toast(player, entry and "Your exploring companion" or "Companion resting", entry and Config.Creatures[entry.species].Name .. " will follow you. Vault protection stays the same." or "Your friend is resting safely in the collection.", "success")
		service.SendState(player)
	end

	local function feedCompanion(player, target)
		if not validId(target) or not actionLimit(player, "FeedCompanion", 0.35) then return end
		local profile = service.Profiles[player]
		local entry = findOwned(profile, target)
		if not entry then return end
		if profile._reservedCreatures and profile._reservedCreatures[target] then
			service.Toast(player, "Raid in progress", "Recover this friend before feeding it.", "error")
			return
		end
		local maxBond = Config.MaxBond or 100
		if (entry.bond or 0) >= maxBond then
			service.Toast(player, "A trusted friend", "This companion's bond is already full. No snack was used.", "info")
			return
		end
		local now = os.time()
		local remaining = (entry.lastFed or 0) + feedCooldownSeconds - now
		if remaining > 0 then
			service.Toast(player, "Still enjoying its snack", "You can feed this friend again in " .. math.ceil(remaining) .. " seconds.", "info")
			return
		end
		local snack = Config.Creatures[entry.species].Snack
		if (profile.snacks[snack] or 0) <= 0 then
			service.Toast(player, "Pack its favorite snack", "Buy " .. Config.Snacks[snack].Name .. " at the snack stall first.", "error")
			return
		end
		profile.snacks[snack] -= 1
		entry.bond = math.min(maxBond, (entry.bond or 0) + (Config.FeedBond or 10))
		entry.lastFed = now
		dirty(profile)
		service.RefreshDisplays(player)
		service.Toast(player, "A little closer", Config.Creatures[entry.species].Name .. "'s bond is " .. entry.bond .. "/" .. maxBond .. ". Bond 50 and 100 improve display income.", "success")
		Remotes.Update:FireClient(player, { kind = "Bond", uid = entry.uid, species = entry.species, bond = entry.bond })
		service.SendState(player)
	end

	local function visitPond(player)
		if service.Distance(player, world.PondGate) > 18 then return end
		local profile = service.Profiles[player]
		if countGarden(profile) < 3 then
			service.Toast(player, "Pond discoveries await", "Befriend all three garden species first: " .. countGarden(profile) .. "/3 discovered.", "info")
			return
		end
		if player.Character and rootOf(player) then
			player.Character:PivotTo(CFrame.new(0, 4, -82))
			service.Toast(player, "Welcome to the pond", "Dewfin visits in rain; Mistfox appears through fog.", "info")
		end
	end

	requestAction = function(player, request)
		if not service.Running or leaving[player] or not service.Profiles[player] or type(request) ~= "table" then return end
		if not profileUsable(player, service.Profiles[player]) then return end
		if type(request.action) ~= "string" or #request.action > 30 then return end
		if request.action == "Sneak" and request.enabled == false then
			if sneak[player] then
				sneak[player] = false
				resetTrust(player)
				refreshMovement(player)
				service.SendState(player)
			end
			return
		end
		if not requestLimit(player) then return end
		local action = request.action
		if action == "Sync" then
			if actionLimit(player, "Sync", 0.4) then service.SendState(player) end
		elseif action == "Sneak" then
			if type(request.enabled) ~= "boolean" then return end
			-- Releasing a hold always works, even when rapid press events are throttled.
			if request.enabled and not actionLimit(player, "Sneak", 0.08) then return end
			sneak[player] = request.enabled
			if not request.enabled then resetTrust(player) end
			refreshMovement(player)
			service.SendState(player)
		elseif action == "Lure" then offerSnack(player, request)
		elseif action == "Befriend" then befriend(player, request)
		elseif action == "Job" then doJob(player, request.target)
		elseif action == "Photo" then
			if actionLimit(player, "Photo", 0.45) then photograph(player, request.target) end
		elseif action == "BuySnack" then buySnack(player, request.snack)
		elseif action == "SetDisplay" then
			if actionLimit(player, "SetDisplay", 0.3) then setDisplay(player, request) end
		elseif action == "UpgradeSanctuary" then upgradeSanctuary(player)
		elseif action == "EquipCompanion" then equipCompanion(player, request.target)
		elseif action == "FeedCompanion" then feedCompanion(player, request.target)
		elseif action == "PondGate" then
			if actionLimit(player, "PondGate", 1) then visitPond(player) end
		elseif action == "Shop" then
			if service.Distance(player, world.Shop) <= Config.ShopRange then openPanel(player, "Shop") end
		elseif action == "Sanctuary" then openPanel(player, "Sanctuary")
		elseif action == "BeginRaid" or action == "Net" or action == "CancelRaid" then
			if raidHandler and actionLimit(player, action, action == "Net" and 0.15 or 0.6) then
				raidHandler(player, request)
			elseif not raidHandler then
				service.Toast(player, "Raids initializing", "Please try again in a moment.", "info")
			end
		end
	end

	-- Prompts and remotes share the exact same validation and reward path.
	for id, job in pairs(world.Jobs) do
		job.Part:SetAttribute("JobId", id)
		job.Part:SetAttribute("Action", "Job")
		job.Part:SetAttribute("Target", id)
		local prompt = newPrompt(job.Part, "Interaction", job.Kind == "Water" and "Water flowers" or "Gather leaves", job.Label)
		table.insert(connections, prompt.Triggered:Connect(function(player) requestAction(player, { action = "Job", target = id }) end))
	end
	for id, clue in pairs(world.Clues) do
		clue.Part:SetAttribute("ClueId", id)
		clue.Part:SetAttribute("Action", "Photo")
		clue.Part:SetAttribute("Target", id)
		local prompt = newPrompt(clue.Part, "Interaction", "Photograph clue", clue.Label)
		table.insert(connections, prompt.Triggered:Connect(function(player) requestAction(player, { action = "Photo", target = id }) end))
	end
	local shopPrompt = newPrompt(world.Shop, "Interaction", "Browse snacks", "Garden snack stall")
	table.insert(connections, shopPrompt.Triggered:Connect(function(player) requestAction(player, { action = "Shop" }) end))
	local pondPrompt = newPrompt(world.PondGate, "Interaction", "Visit pond", "3 garden discoveries required")
	table.insert(connections, pondPrompt.Triggered:Connect(function(player) requestAction(player, { action = "PondGate" }) end))
	for _, sanctuary in ipairs(world.Sanctuaries) do
		local part = sanctuary.Pedestals[1]
		if part then
			local prompt = newPrompt(part, "SanctuaryMenu", "Manage sanctuary", "Safe vault / exposed displays")
			prompt.MaxActivationDistance = 10
			table.insert(connections, prompt.Triggered:Connect(function(player) openPanel(player, "Sanctuary") end))
		end
	end
	for _, spawn in ipairs(world.CreatureSpawns) do
		spawns[spawn.id] = spawn
		nextSpawn[spawn.id] = os.clock()
	end

	local function setWeather(weather)
		service.Weather = weather
		world.Root:SetAttribute("Weather", weather)
		Lighting.ClockTime = weather == "Dusk" and 18.3 or weather == "Fog" and 7.5 or weather == "Rain" and 11.5 or 14
		Lighting.Brightness = weather == "Dusk" and 1.5 or weather == "Rain" and 1.4 or 2
		Lighting.OutdoorAmbient = weather == "Dusk" and Color3.fromRGB(116, 98, 123) or Color3.fromRGB(132, 151, 143)
		Lighting.FogColor = weather == "Dusk" and Color3.fromRGB(207, 169, 153) or Color3.fromRGB(180, 204, 192)
		Lighting.FogStart = weather == "Fog" and 25 or 140
		Lighting.FogEnd = weather == "Fog" and 170 or 800
		for id, entity in pairs(entities) do
			local definition = Config.Creatures[entity.species]
			if not entity.owner and definition.Weather ~= "Any" and definition.Weather ~= weather and not next(entity.lures) then
				destroyEntity(id, 0)
			end
		end
		for player in pairs(service.Profiles) do
			service.Toast(player, weather .. " in the wilds", weather == "Dusk" and "Lanternwings stir in the garden." or weather == "Rain" and "Dewfin is visiting the pond." or weather == "Fog" and "Mistfox tracks appear near the pond." or "A good moment for garden jobs and Mossbun clues.", "info")
		end
		sendAll()
	end
	setWeather(service.Weather)

	local function savePlayer(player, release)
		local profile = service.Profiles[player]
		if not profile then return true end
		while saving[player] do task.wait(0.1) end
		saving[player] = true
		local revision = profile._revision
		local ok, result = pcall(PlayerData.Save, player, profile, release)
		saving[player] = nil
		if not ok or result == false then
			profile._saving = "error"
			warn("[Wildbound] Save unavailable for user " .. player.UserId)
			if not release then service.Toast(player, "Saving paused", "Your session is active. The server will retry saving shortly.", "error") end
			if profile._readOnly and player.Parent == Players then
				player:Kick("Your collection is active in another server. Please rejoin safely; this server has stopped changes to your collection.")
			end
		else
			profile._dirty = profile._revision ~= revision
		end
		if not release then service.SendState(player) end
		return ok and result ~= false
	end

	local function setupCharacter(player, character)
		clearCompanion(player)
		sneak[player] = false
		resetTrust(player)
		player:SetAttribute("Sneaking", false)
		player:SetAttribute("RaidSlowedUntil", nil)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or player.Character ~= character or not service.Profiles[player] or leaving[player] then return end
		character:PivotTo(world.Spawn)
		refreshMovement(player)
		refreshCompanion(player)
		firstCreature(player)
		service.SendState(player)
	end

	local function joined(player)
		if service.Profiles[player] or loading[player] or shuttingDown then return end
		loading[player] = true
		local ok, profile = pcall(PlayerData.Load, player)
		if not ok or not profile then
			loading[player] = nil
			warn("[Wildbound] Profile unavailable for user " .. player.UserId)
			if player.Parent == Players then player:Kick("Your collection could not load safely. Please rejoin in a moment; no progress was overwritten.") end
			return
		end
		if player.Parent ~= Players or shuttingDown then
			pcall(PlayerData.Save, player, profile, true)
			loading[player] = nil
			return
		end
		service.Profiles[player] = profile
		pruneResearch(profile)
		for key, unlocked in pairs(profile.research) do
			if unlocked and string.sub(key, 1, 8) == "__title_" then player:SetAttribute("NaturalistTitle", string.sub(key, 9)); break end
		end
		if not profile.tutorialComplete and not profile.research.__starterBerry then
			profile.research.__starterBerry = true
			profile.snacks.Berry = math.min(999, profile.snacks.Berry + 1)
			dirty(profile)
		end
		if not service.AssignSanctuary(player) then
			savePlayer(player, true)
			service.Profiles[player] = nil
			loading[player] = nil
			player:Kick("All eight sanctuaries are occupied. Please join another server.")
			return
		end
		-- Migrate already-earned discoveries on load; Sync itself never awards progress.
		advanceQuests(player)
		characterConnections[player] = player.CharacterAdded:Connect(function(character) task.spawn(setupCharacter, player, character) end)
		if player.Character then task.spawn(setupCharacter, player, player.Character) end
		firstCreature(player)
		service.SendState(player)
		callHooks(joinHooks, player)
		loading[player] = nil
	end

	local function cleanupSanctuary(player)
		local sanctuary = playerSanctuary[player]
		if not sanctuary then return end
		for _, pedestal in ipairs(sanctuary.Pedestals) do
			WorldModule.ShowDisplay(Config, pedestal, nil)
			pedestal:SetAttribute("OwnerUserId", nil)
			pedestal:SetAttribute("CreatureUid", nil)
			pedestal:SetAttribute("Species", nil)
			pedestal:SetAttribute("Variant", nil)
			pedestal:SetAttribute("Bond", nil)
			pedestal:SetAttribute("DisplayActive", false)
			local prompt = pedestal:FindFirstChild("RaidInteraction")
			if prompt then prompt.Enabled = false end
		end
		if sanctuary.Sign then sanctuary.Sign.Text = "Open sanctuary\nMake discoveries to call it home" end
		sanctuary.Folder:SetAttribute("OwnerUserId", nil)
		if WorldModule.DecorateSanctuary then WorldModule.DecorateSanctuary(sanctuary, 1) end
		for index, owner in pairs(sanctuaries) do if owner == player then sanctuaries[index] = nil end end
		playerSanctuary[player] = nil
	end

	local function departed(player)
		if leaving[player] then return end
		leaving[player] = true
		callHooks(leaveHooks, player)
		clearCompanion(player)
		local tutorialEntity = entities["tutorial_" .. player.UserId]
		local tutorialLure = tutorialEntity and tutorialEntity.lures[player.UserId]
		local profile = service.Profiles[player]
		if tutorialLure and profile and not profile._readOnly then
			profile.snacks[tutorialLure.snack] = math.min(999, profile.snacks[tutorialLure.snack] + 1)
			dirty(profile)
		end
		destroyEntity("tutorial_" .. player.UserId)
		for _, entity in pairs(entities) do
			entity.lures[player.UserId] = nil
			refreshLureAttribute(entity)
		end
		cleanupSanctuary(player)
		savePlayer(player, true)
		service.Profiles[player] = nil
		service.RaidStates[player] = nil
		if characterConnections[player] then characterConnections[player]:Disconnect(); characterConnections[player] = nil end
		sneak[player], requestBuckets[player], actionTimes[player], jobTimes[player] = nil, nil, nil, nil
		leaving[player] = nil
	end

	table.insert(connections, Remotes.Request.OnServerEvent:Connect(requestAction))
	table.insert(connections, Players.PlayerAdded:Connect(function(player) task.spawn(joined, player) end))
	table.insert(connections, Players.PlayerRemoving:Connect(departed))
	-- The bootstrap publishes remotes after both services have registered handlers.
	-- Existing-player loads begin on the next scheduler turn, after publication.
	for _, player in ipairs(Players:GetPlayers()) do task.defer(joined, player) end

	local movementElapsed = 0
	local stateElapsed = 0
	local companionElapsed = 0
	table.insert(connections, RunService.Heartbeat:Connect(function(delta)
		if not service.Running then return end
		companionElapsed += delta
		-- Bound server model replication; client ambient animation handles finer detail.
		if companionElapsed >= 0.05 then
			local followDelta = companionElapsed
			companionElapsed = 0
			for player, companion in pairs(companions) do
				local root = rootOf(player)
				local sanctuary = playerSanctuary[player]
				local profile = service.Profiles[player]
				local stillOwned = profile and findOwned(profile, companion.uid)
				local reserved = profile and profile._reservedCreatures and profile._reservedCreatures[companion.uid]
				if not root or not stillOwned or reserved or companion.permanent and profile.equippedUid ~= companion.uid or player.Character ~= companion.character or os.clock() >= companion.expiresAt or not companion.model.Parent then
					clearCompanion(player)
				elseif not companion.permanent and sanctuary and service.Distance(player, sanctuary.BasePosition) < 14 then
					clearCompanion(player)
					service.Toast(player, "Home in the sanctuary", Config.Creatures[companion.species].Name .. " is safely in your vault. Open Sanctuary to choose a display.", "success")
				else
					local destination = root.CFrame * CFrame.new(3, -2.8, 4)
					companion.model:PivotTo(companion.model:GetPivot():Lerp(destination, math.min(1, followDelta * 8)))
				end
			end
		end
		movementElapsed += delta
		stateElapsed += delta
		if movementElapsed < 0.25 then return end
		movementElapsed = 0
		local now = os.clock()
		if researchDay ~= dayKey() then
			researchDay = dayKey()
			for player, profile in pairs(service.Profiles) do
				if not leaving[player] and profileUsable(player, profile) then pruneResearch(profile); dirty(profile) end
			end
		end
		for player, profile in pairs(service.Profiles) do
			if not leaving[player] and profileUsable(player, profile) then
				refreshMovement(player)
				refreshCompanion(player)
				local root = rootOf(player)
				-- The pond is an earned area even if a client jumps around the gate.
				if root and root.Position.Z < -72 and root.Position.X > -68 and root.Position.X < 68 and countGarden(profile) < 3 then
					player.Character:PivotTo(world.Spawn)
					if actionLimit(player, "PondWarning", 5) then service.Toast(player, "Pond is locked", "Discover all three garden creatures to enter.", "info") end
				end
			end
		end
		if now >= weatherEnds then
			weatherIndex = weatherIndex % #weatherCycle + 1
			weatherEnds = now + weatherSeconds
			setWeather(weatherCycle[weatherIndex])
		end
		for id, spawn in pairs(spawns) do
			if not entities[id] and now >= (nextSpawn[id] or 0) then
				local definition = Config.Creatures[spawn.species]
				if definition.Weather == "Any" or definition.Weather == service.Weather then
					-- Rare creatures have a chance per window; a capture does not guarantee a respawn.
					local appearanceChance = definition.Rarity == "Rare" and 0.55 or definition.Rarity == "Legendary" and 0.25 or 1
					nextSpawn[id] = now + 35
					if random:NextNumber() <= appearanceChance then spawnEntity(id, spawn.species, spawn.position) end
				end
			end
		end
		for id, entity in pairs(entities) do
			refreshLureAttribute(entity)
			for userId, lure in pairs(entity.lures) do
				local player = service.GetPlayerById(userId)
				local profile = player and service.Profiles[player]
				if player and profile and not leaving[player] and profileUsable(player, profile) then
					updateTrust(player, entity, lure, workspace:GetServerTimeNow())
				else
					lure.trust, lure.trustStartedAt = 0, nil
				end
			end
			-- Wild creatures retreat from a running approach. An owned tutorial waits
			-- for the explicit attempt so the first lesson stays forgiving.
			if not entity.owner then
				for userId, lure in pairs(entity.lures) do
					local player = service.GetPlayerById(userId)
					if player and service.Profiles[player] and profileUsable(player, service.Profiles[player]) and not sneak[player] and service.Distance(player, entity.model) < Config.BefriendRange and workspace:GetServerTimeNow() >= lure.readyAt then
						entity.lures[userId] = nil
						refreshLureAttribute(entity)
						service.Toast(player, "A shy retreat", "Hold Sneak before approaching. Offer another snack when you're ready.", "info")
						service.SendState(player)
					end
				end
			end
			local definition = Config.Creatures[entity.species]
			if not entity.owner and definition.Weather ~= "Any" and definition.Weather ~= service.Weather and not next(entity.lures) then destroyEntity(id, 0) end
		end
		if now >= incomeAt then
			incomeAt = now + Config.DisplayIncomeSeconds
			for player, profile in pairs(service.Profiles) do
				if not leaving[player] and profileUsable(player, profile) then
					local income = 0
					for _, creature in ipairs(profile.creatures) do
						if creature.displayed then
							local bond = creature.bond or 0
							income += Config.DisplayIncomePerCreature + (bond >= (Config.MaxBond or 100) and 2 or bond >= 50 and 1 or 0)
						end
					end
					if income > 0 then
						profile.coins = math.min(1000000000, profile.coins + income)
						dirty(profile)
						service.SendState(player)
					end
				end
			end
		end
		if now >= autosaveAt then
			autosaveAt = now + Config.Persistence.SaveInterval
			for player in pairs(service.Profiles) do if not leaving[player] then task.spawn(savePlayer, player, false) end end
		end
		if stateElapsed >= 2 then stateElapsed = 0; sendAll() end
	end))

	function service.Stop()
		if shuttingDown then return end
		shuttingDown = true
		service.Running = false
		for _, connection in ipairs(connections) do connection:Disconnect() end
		local pending = 0
		for player in pairs(service.Profiles) do
			pending += 1
			task.spawn(function()
				departed(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while (pending > 0 or next(loading) ~= nil) and os.clock() < deadline do task.wait(0.1) end
	end
	game:BindToClose(service.Stop)
	return service
end

return GameService

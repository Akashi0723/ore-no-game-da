-- Session-locked profiles. A failed load never becomes an empty writable profile.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Wildbound"):WaitForChild("Config"))

local PlayerData = {}
local sessions = {}
local sessionOnly = RunService:IsStudio() and not Config.Persistence.EnableInStudio
local store = if sessionOnly then nil else DataStoreService:GetDataStore(Config.Persistence.StoreName)

local function whole(value, defaultValue, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return defaultValue end
	return math.clamp(math.floor(value), 0, maximum)
end

local function sanitize(raw)
	local data = if type(raw) == "table" then raw else {}
	local profile = {
		coins = whole(data.coins, Config.StartCoins, 1000000000),
		xp = whole(data.xp, 0, 10000000),
		snacks = { Berry = 0, Seed = 0 },
		discoveries = {}, creatures = {}, research = {},
		tutorialComplete = data.tutorialComplete == true,
		sanctuaryLevel = math.max(1, whole(data.sanctuaryLevel, 1, Config.MaxSanctuaryLevel)),
	}
	if type(data.snacks) == "table" then
		for name in Config.Snacks do profile.snacks[name] = whole(data.snacks[name], 0, 999) end
	end
	if type(data.discoveries) == "table" then
		for species in Config.Creatures do profile.discoveries[species] = data.discoveries[species] == true end
	end
	if type(data.research) == "table" then
		local count = 0
		for key, value in data.research do
			if type(key) == "string" and #key <= 100 and type(value) == "boolean" and count < 300 then
				profile.research[key] = value
				count += 1
			end
		end
	end
	local seen = {}
	if type(data.creatures) == "table" then
		for _, creature in data.creatures do
			if type(creature) == "table" and type(creature.uid) == "string" and #creature.uid <= 80
				and Config.Creatures[creature.species] and not seen[creature.uid] and #profile.creatures < Config.MaxCreatures then
				seen[creature.uid] = true
				table.insert(profile.creatures, { uid = creature.uid, species = creature.species, displayed = creature.displayed == true })
			end
		end
	end
	local displayed, capacity = 0, Config.BaseDisplayCapacity + profile.sanctuaryLevel - 1
	for _, creature in profile.creatures do
		if creature.displayed then
			displayed += 1
			if displayed > capacity then creature.displayed = false end
		end
	end
	return profile
end

function PlayerData.Load(player)
	if sessions[player] then return sessions[player].profile end
	if sessionOnly then
		local profile = sanitize(nil)
		profile._saving = "session"
		sessions[player] = { profile = profile, session = true }
		return profile
	end
	local token = HttpService:GenerateGUID(false)
	local key = "player_" .. player.UserId
	for attempt = 1, 3 do
		local locked = false
		local success, record = pcall(function()
			return store:UpdateAsync(key, function(old)
				locked = false
				if old ~= nil and type(old) ~= "table" then return nil end
				if old ~= nil and (old.version ~= 1 or type(old.data) ~= "table") then return nil end
				local previous = old or {}
				local lock = previous.lock
				if type(lock) == "table" and lock.id ~= token and type(lock.at) == "number"
					and os.time() - lock.at < Config.Persistence.LockSeconds then
					locked = true
					return nil
				end
				return { version = 1, data = sanitize(previous.data), lock = { id = token, at = os.time() } }
			end)
		end)
		if success and not locked and type(record) == "table" and type(record.lock) == "table" and record.lock.id == token then
			local profile = sanitize(record.data)
			profile._saving = "saved"
			profile._lockAt = os.time()
			sessions[player] = { profile = profile, token = token, key = key }
			return profile
		end
		if attempt < 3 then task.wait(attempt * 2) end
	end
	warn("[Wildbound] Profile unavailable for player " .. player.UserId .. "; gameplay blocked to protect saved progress.")
	return nil
end

function PlayerData.Save(player, profile, release)
	local session = sessions[player]
	if not session or session.profile ~= profile then return false end
	if session.session then
		profile._saving = "session"
		if release then sessions[player] = nil end
		return true
	end
	if profile._lockAt and os.time() - profile._lockAt >= Config.Persistence.LockSeconds then
		profile._readOnly = true
		profile._saving = "error"
		return false
	end
	-- Serialize each profile once. Saves for this player are ordered, including
	-- release, so an autosave cannot overwrite progress with an older snapshot.
	local deadline = os.clock() + 20
	while session.busy and os.clock() < deadline do task.wait(0.1) end
	if session.busy or sessions[player] ~= session then return false end
	session.busy = true
	local payload = sanitize(profile)
	local saved = false
	for attempt = 1, 3 do
		local accepted = false
		local lockLost = false
		local success = pcall(function()
			store:UpdateAsync(session.key, function(old)
				accepted = false
				if type(old) ~= "table" or type(old.lock) ~= "table" or old.lock.id ~= session.token then
					lockLost = true
					return nil
				end
				lockLost = false
				accepted = true
				return { version = 1, data = payload, lock = if release then nil else { id = session.token, at = os.time() } }
			end)
		end)
		if success and accepted then saved = true break end
		if success and lockLost then
			profile._readOnly = true
			break
		end
		if attempt < 3 then task.wait(attempt) end
	end
	session.busy = false
	profile._saving = if saved then "saved" else "error"
	if saved then profile._lockAt = os.time() end
	if release and saved then sessions[player] = nil end
	if not saved then warn("[Wildbound] Save failed for player " .. player.UserId .. "; existing profile was not overwritten without its lock.") end
	return saved
end

return PlayerData

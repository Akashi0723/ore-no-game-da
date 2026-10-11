-- tools/validate.py embeds the real PlayerData module at INLINE_PLAYERDATA.
-- Mock only platform boundaries; all sanitization and lock logic is production code.
local function createData(settings)
    settings.records = settings.records or {}
    settings.calls = settings.calls or 0
    settings.writes = settings.writes or 0
    local store = {}
    function store:UpdateAsync(key, callback)
        settings.calls += 1
        if settings.fail then error("DataStore temporarily unavailable") end
        local nextRecord = callback(settings.records[key])
        if settings.retryWithForeignLock then
            settings.retryWithForeignLock = false
            settings.records[key] = {version = 1, data = {coins = 456}, lock = {id = "racing-server", at = os.time()}}
            nextRecord = callback(settings.records[key])
        end
        if nextRecord == nil then return nil end
        settings.records[key] = nextRecord
        settings.writes += 1
        return nextRecord
    end
    local folder = {}
    function folder:WaitForChild() return self end
    local services = {
        DataStoreService = {GetDataStore = function() return store end},
        HttpService = {GenerateGUID = function() return settings.token or "this-session" end},
        RunService = {IsStudio = function() return settings.studio == true end},
        ReplicatedStorage = folder,
    }
    local game = {GetService = function(_, name) return assert(services[name], name) end}
    local require = function() return Config end
    local task = {wait = function() end}
    local warn = function() end
    local PlayerData = (function()
        -- INLINE_PLAYERDATA
    end)()
    return PlayerData
end

local player = {UserId = 12345}
local key = "player_12345"

-- Studio session storage must never pretend to save permanently or hit DataStore.
do
    local settings = {studio = true}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    assert(profile.coins == Config.StartCoins and profile._saving == "session")
    assert(data.Load(player) == profile, "Repeated load must return the same active profile")
    assert(not data.Save(player, {}), "Unregistered profiles must not be writable")
    profile.coins = 72
    assert(data.Save(player, profile, true))
    assert(settings.calls == 0, "Studio session mode must not touch real DataStores")
    local reloaded = assert(data.Load(player))
    assert(reloaded ~= profile and reloaded.coins == Config.StartCoins)
end

-- New players acquire a lock, save data with that lock, then release it.
do
    local settings = {token = "first-server"}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    assert(profile._saving == "saved")
    assert(settings.records[key].lock.id == "first-server")
    profile.coins, profile.xp = 88, 130
    assert(data.Save(player, profile))
    assert(settings.records[key].data.coins == 88 and settings.records[key].data.xp == 130)
    assert(settings.records[key].data._lockAt == nil, "Runtime lease metadata must not enter the saved payload")
    assert(settings.records[key].lock.id == "first-server")
    assert(data.Save(player, profile, true))
    assert(settings.records[key].lock == nil, "Release must relinquish the session lock")
end

-- A stalled server cannot refresh an expired lease or overwrite a successor.
do
    local settings = {token = "expired-server"}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    local callsBefore = settings.calls
    profile._lockAt = os.time() - Config.Persistence.LockSeconds - 1
    profile.coins = 9999
    assert(not data.Save(player, profile))
    assert(profile._readOnly == true and profile._saving == "error")
    assert(settings.calls == callsBefore and settings.records[key].data.coins == Config.StartCoins)
end

for level = 1, Config.MaxSanctuaryLevel do
    local creatures = {}
    for index = 1, 6 do table.insert(creatures, {uid = "slot-" .. index, species = "Mossbun", displayed = true}) end
    local settings = {records = {[key] = {version = 1, data = {creatures = creatures, sanctuaryLevel = level}}}}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    local displayed = 0
    for _, creature in profile.creatures do if creature.displayed then displayed += 1 end end
    assert(displayed == Config.BaseDisplayCapacity + level - 1, "Each saved sanctuary level must preserve its configured display capacity")
end

-- Invalid values cannot poison balances, tools, collections or display capacity.
do
    local settings = {records = {[key] = {version = 1, data = {
        coins = 0/0, xp = math.huge, snacks = {Berry = -5, Seed = 9.9, BadSnack = 100},
        sanctuaryLevel = 0, discoveries = {Mossbun = true, BadSpecies = true},
        creatures = {
            {uid = "a", species = "Mossbun", displayed = true},
            {uid = "a", species = "Mossbun", displayed = true},
            {uid = "b", species = "Pebblehog", displayed = true},
            {uid = "c", species = "Lanternwing", displayed = true},
            {uid = "d", species = "BadSpecies", displayed = true},
        },
    }}}}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    assert(profile.coins == Config.StartCoins and profile.xp == 0, "Nonfinite values must use safe defaults")
    assert(profile.snacks.Berry == 0 and profile.snacks.Seed == 9 and profile.snacks.BadSnack == nil)
    assert(profile.sanctuaryLevel == 1 and profile.discoveries.BadSpecies == nil)
    assert(#profile.creatures == 3, "Unknown species and duplicate UIDs must be removed")
    local displayed = 0
    for _, creature in profile.creatures do if creature.displayed then displayed += 1 end end
    assert(displayed == Config.BaseDisplayCapacity, "Stored display flags cannot exceed capacity")
end

-- Locked and malformed records must never be replaced by fresh blank progress.
for _, record in {
    "corrupt-record",
    {version = 999, data = {coins = 6543}},
    {version = 1, data = "corrupt-data"},
    {version = 1, data = {coins = 9876}, lock = {id = "another-active-server", at = os.time()}},
} do
    local settings = {records = {[key] = record}}
    local data = createData(settings)
    assert(data.Load(player) == nil, "Unusable saves must block play rather than return blank profiles")
    assert(settings.writes == 0 and settings.records[key] == record)
    assert(not data.Save(player, {coins = 0}), "Failed loads cannot gain permission to overwrite")
end

do
    local old = {version = 1, data = {coins = 500}}
    local settings = {records = {[key] = old}, fail = true}
    local data = createData(settings)
    assert(data.Load(player) == nil and settings.writes == 0 and settings.records[key] == old)
end

-- A lost session lock forbids saves even if the in-memory profile is valid.
do
    local settings = {token = "first-server"}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    local foreign = {version = 1, data = {coins = 200}, lock = {id = "replacement-server", at = os.time()}}
    settings.records[key] = foreign
    profile.coins = 9999
    assert(not data.Save(player, profile))
    assert(profile._saving == "error" and profile._readOnly == true and settings.records[key] == foreign)
end

-- UpdateAsync may retry a transform after another server wins the session lock.
do
    local settings = {token = "first-server"}
    local data = createData(settings)
    local profile = assert(data.Load(player))
    settings.retryWithForeignLock = true
    profile.coins = 9999
    assert(not data.Save(player, profile), "An earlier accepted transform cannot mark a cancelled retry as saved")
    assert(profile._readOnly == true and settings.records[key].data.coins == 456)
end

-- Two independent servers cannot mutate the same player's profile concurrently.
do
    local records = {}
    local firstSettings = {records = records, token = "first-server"}
    local secondSettings = {records = records, token = "second-server"}
    local first = createData(firstSettings)
    local second = createData(secondSettings)
    local firstProfile = assert(first.Load(player))
    firstProfile.coins = 321
    assert(second.Load(player) == nil and secondSettings.writes == 0)
    assert(first.Save(player, firstProfile, true))
    local secondProfile = assert(second.Load(player))
    assert(secondProfile.coins == 321 and records[key].lock.id == "second-server")
end

print("PASS: real PlayerData sanitization, session storage, lock acquisition/release, failed loads and lost-lock protection")

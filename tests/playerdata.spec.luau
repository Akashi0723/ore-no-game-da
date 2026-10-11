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

-- Legacy collections migrate; new fields are finite, owned and saveable.
do
    local timestamp=os.time()-10
    local settings={records={[key]={version=1,data={equippedUid="golden",creatures={
        {uid="legacy",species="Mossbun"},
        {uid="golden",species="Mossbun",variant="Golden",bond=44,lastFed=timestamp},
        {uid="forged",species="Mossbun",variant="Admin",bond=100000,lastFed=math.huge},
        {uid="nonfinite",species="Mossbun",variant="Moonlit",bond=0/0,lastFed=0/0},
        {uid="negative",species="Mossbun",bond=-3,lastFed=-100},
        {uid="decimal",species="Mossbun",bond=12.9,lastFed=timestamp+0.9},
    }}}}}
    local data=createData(settings)
    local profile=assert(data.Load(player))
    local entries={}
    for _,entry in profile.creatures do entries[entry.uid]=entry end
    assert(entries.legacy.variant=="Normal" and entries.legacy.bond==0 and entries.legacy.lastFed==0,
        "Existing collections must migrate without losing their original identities")
    assert(entries.golden.variant=="Golden" and entries.golden.bond==44 and entries.golden.lastFed==timestamp)
    assert(profile.equippedUid=="golden","A valid owned companion choice must survive load")
    assert(entries.forged.variant=="Normal" and entries.forged.bond==Config.MaxBond and entries.forged.lastFed==0)
    assert(entries.nonfinite.bond==0 and entries.nonfinite.lastFed==0,
        "Nonfinite companion fields cannot poison replicated progress or cooldowns")
    assert(entries.negative.bond==0 and entries.negative.lastFed==0)
    assert(entries.decimal.bond==12 and entries.decimal.lastFed==timestamp)
    assert(data.Save(player,profile,true))
    local reloaded=assert(data.Load(player))
    assert(reloaded.equippedUid=="golden" and reloaded.creatures[2].variant=="Golden" and reloaded.creatures[2].bond==44,
        "New companion fields must persist across a real save/reload")
end
for _,equipped in {"not-owned",123,""} do
    local settings={records={[key]={version=1,data={equippedUid=equipped,
        creatures={{uid="owned",species="Mossbun",lastFed=os.time()+999999}}}}}}
    local profile=assert(createData(settings).Load(player))
    assert(profile.equippedUid==nil,"A dangling or forged equipped UID cannot enter a profile")
    assert(profile.creatures[1].lastFed<=os.time(),"Future feed timestamps must not create permanent cooldowns")
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

print("PASS: real PlayerData sanitization, legacy/variant/bond migration, owned equipment, feed timestamps, session storage, locks and failed-load protection")

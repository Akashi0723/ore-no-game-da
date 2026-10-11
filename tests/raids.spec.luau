-- Real RaidService, with Roblox services/instances/vector math mocked at boundaries.
-- This verifies state and ownership rules, not Studio replication or input.
local function signal()
    local listeners = {}
    return {
        Connect = function(_, callback)
            local connection = {Connected = true}
            function connection:Disconnect() self.Connected = false end
            table.insert(listeners, {callback = callback, connection = connection})
            return connection
        end,
        Fire = function(_, ...)
            for _, listener in listeners do
                if listener.connection.Connected then listener.callback(...) end
            end
        end,
    }
end

local vectorMethods = {}
local vectorMeta = {
    __index = function(value, key)
        if key == "Magnitude" then return math.sqrt(value.X^2 + value.Y^2 + value.Z^2) end
        return vectorMethods[key]
    end,
    __sub = function(a, b)
        return setmetatable({X = a.X-b.X, Y = a.Y-b.Y, Z = a.Z-b.Z}, getmetatable(a))
    end,
}
local function position(x, y, z)
    return setmetatable({X = x or 0, Y = y or 18, Z = z or 0}, vectorMeta)
end

local function instance(className)
    local attributes = {}
    local object = {ClassName = className, ChildAdded = signal()}
    function object:IsA(name) return name == self.ClassName or (name == "BasePart" and self.ClassName == "Part") end
    function object:GetAttribute(name) return attributes[name] end
    function object:SetAttribute(name, value) attributes[name] = value end
    function object:Destroy() self.Parent = nil; self.Destroyed = true end
    function object:FindFirstAncestorOfClass(name)
        local ancestor = self.Parent
        while ancestor do
            if ancestor.ClassName == name then return ancestor end
            ancestor = ancestor.Parent
        end
        return nil
    end
    function object:IsDescendantOf(ancestor)
        local parent = self.Parent
        while parent do
            if parent == ancestor then return true end
            parent = parent.Parent
        end
        return false
    end
    return object
end

local function fixture(studio)
    local now = 0
    local Players = {people = {}}
    function Players:GetPlayers() return self.people end
    local RunService = {Heartbeat = signal(), IsStudio = function() return studio ~= false end}
    local services = {Players = Players, RunService = RunService}
    local game = {GetService = function(_, name) return assert(services[name], name) end}
    function game:BindToClose(callback) self.close = callback end
    local os = {clock = function() return now end}
    local Instance = {new = instance}
    local Vector3 = {new = position}
    local UDim2 = {fromOffset = function() return {} end, fromScale = function() return {} end}
    local UDim = {new = function() return {} end}
    local Enum = {RaycastFilterType = {Exclude = 1}, HighlightDepthMode = {AlwaysOnTop = 1}, Font = {GothamBold = 1}}
    local RaycastParams = {new = function() return {} end}
    local workspace = {blocked = false}
    local wall = instance("Part")
    function workspace:Raycast() return if self.blocked then {Instance = self.hit or wall} else nil end
    local RaidService = (function()
        -- INLINE_RAIDSERVICE
    end)()
    local function player(userId)
        local p = instance("Player")
        p.UserId, p.DisplayName, p.Parent = userId, "Player " .. tostring(userId), Players
        p.CharacterAdded, p.CharacterRemoving = signal(), signal()
        p.Character = instance("Model")
        p.Character.Parent = workspace
        p.root = instance("Part")
        p.root.Position, p.root.Parent = position(), p.Character
        p.humanoid = instance("Humanoid")
        p.humanoid.Health, p.humanoid.Died = 100, signal()
        function p.Character:FindFirstChild(name) return if name == "HumanoidRootPart" then p.root else nil end
        function p.Character:FindFirstChildOfClass(name) return if name == "Humanoid" then p.humanoid else nil end
        table.insert(Players.people, p)
        return p
    end
    local owner, thief, third = player(1), player(2), player(3)
    local creature = {uid = "original-uid", species = "Mossbun", displayed = true,variant="Golden",bond=40,lastFed=123}
    local Profiles = {
        [owner] = {creatures = {creature}, xp = 10, _saving = "session",equippedUid=creature.uid},
        [thief] = {creatures = {}, xp = 20, _saving = "session"},
        [third] = {creatures = {}, xp = 30, _saving = "session"},
    }
    local displayModel = instance("Model")
    local display = instance("Part")
    display.Position, display.Parent = position(), displayModel
    display:SetAttribute("OwnerUserId", owner.UserId)
    display:SetAttribute("CreatureUid", creature.uid)
    local worldRoot = instance("Model")
    worldRoot.Parent, displayModel.Parent = workspace, worldRoot
    function worldRoot:GetDescendants() return {display} end
    local extraction = instance("Part")
    extraction.Parent, extraction.Position = worldRoot, position(100, 18, 0)
    local service = {
        Profiles = Profiles,
        World = {Root = worldRoot, Extraction = extraction},
        Toast = function() end,
        SendState = function() end,
        RefreshDisplays = function() end,
        GetPlayerById = function(id)
            for _, p in Players.people do if p.UserId == id and p.Parent == Players then return p end end
            return nil
        end,
    }
    function service.SetRaidHandler(handler) service.handler = handler end
    function service.RegisterPlayerHooks(join, leave) service.join, service.leave = join, leave end
    local controller = RaidService.Start(Config, service, {})
    local h = {owner = owner, thief = thief, third = third, creature = creature, service = service,
        world = workspace, controller = controller, display = display, extraction = extraction,
        wall = wall, displayModel = displayModel}
    function h:begin(p)
        service.handler(p or thief, {action = "BeginRaid", owner = owner.UserId, target = creature.uid})
    end
    function h:tick(seconds) now += seconds; RunService.Heartbeat:Fire(seconds) end
    function h:net() service.handler(owner, {action = "Net", target = thief.UserId}) end
    function h:state() return service.RaidStates[thief] end
    function h:escape()
        self:tick(Config.Raid.StealSeconds + 0.1)
        assert(self:state().phase == "escape")
    end
    function h:extract()
        thief.root.Position = extraction.Position
        self:tick(0.3)
        assert(self:state().phase == "chase")
    end
    function h:unchanged()
        assert(#Profiles[owner].creatures == 1 and Profiles[owner].creatures[1] == creature)
        assert(#Profiles[thief].creatures == 0)
    end
    return h
end

do
    local h = fixture()
    for _, malformed in {math.huge, -math.huge, 0/0, 1e20} do
        h.service.handler(h.thief, {action = "BeginRaid", owner = malformed, target = h.creature.uid})
        assert(h:state() == nil)
    end
    h:unchanged()
end

-- A wall in the target sanctuary still blocks LOS; its own decoration does not.
do
    local h = fixture()
    h.thief.root.Position = position(2, 18, 0)
    h.wall.Parent = h.displayModel
    h.world.blocked = true
    h:begin(); assert(h:state() == nil, "A sanctuary wall must not count as hitting the creature")
    local decoration = instance("Part")
    decoration.Parent = h.display
    h.world.hit = decoration
    h:begin(); assert(h:state().phase == "stealing", "The creature's own decorative parts are a clear hit")
    h.controller.CancelAll()
    h:unchanged()
end

do
    local previous = Config.Persistence.EnableInStudio
    Config.Persistence.EnableInStudio = true
    local h = fixture()
    h:begin(); assert(h:state() == nil and not h.controller.Enabled, "Durable Studio profiles must not enable temporary ownership transfers")
    Config.Persistence.EnableInStudio = previous
end

-- Vault, distance, line-of-sight, self-target and production gates.
do
    local h = fixture(false)
    h:begin()
    assert(h:state() == nil and not h.controller.Enabled)
    h:unchanged()
end
do
    local h = fixture()
    h.creature.displayed = false; h:begin(); assert(h:state() == nil)
    h.creature.displayed = true; h.thief.root.Position = position(50, 18, 0)
    h:begin(); assert(h:state() == nil)
    h.thief.root.Position = position(2, 18, 0); h.world.blocked = true
    h:begin(); assert(h:state() == nil)
    h.world.blocked = false; h:begin(h.owner); assert(h:state() == nil)
    h:unchanged()
end

-- Ownership stays pending; reservations stop simultaneous attacks.
do
    local h = fixture()
    h:begin()
    assert(h:state().phase == "stealing")
    assert(h.service.Profiles[h.owner]._reservedCreatures[h.creature.uid] == true)
    h:unchanged()
    h:begin(h.third)
    assert(h.service.RaidStates[h.third] == nil)
    h:escape(); h:unchanged()
    h:extract(); h:tick(Config.Raid.ChaseSeconds - 1); h:unchanged()
    h:tick(1.1)
    assert(h:state() == nil and #h.service.Profiles[h.owner].creatures == 0)
    assert(#h.service.Profiles[h.thief].creatures == 1)
    assert(h.service.Profiles[h.thief].creatures[1] == h.creature and h.creature.uid == "original-uid")
    assert(h.creature.variant=="Golden" and h.creature.bond==40 and h.creature.lastFed==123,
        "A raid must preserve the original creature's identity, cosmetic variant and care progress")
    assert(h.service.Profiles[h.owner].equippedUid==nil,"A completed transfer must clear the former owner's equipped UID")
    assert(h.creature.displayed == false and h.service.Profiles[h.thief].xp == 20)
    h:tick(100); h:net()
    assert(#h.service.Profiles[h.thief].creatures == 1, "Late events cannot duplicate a completed transfer")
end

-- A net interrupts theft; three chase hits survive extraction and reject spam.
do
    local h = fixture()
    h:begin(); h:net()
    assert(h:state() == nil)
    h:unchanged()
end
do
    local h = fixture()
    h:begin(); h:escape(); h:net()
    assert(h:state().netHits == 1)
    h:net(); assert(h:state().netHits == 1, "Immediate repeated net requests must be throttled")
    h:extract(); assert(h:state().netHits == 1, "Extraction must not reset defensive hits")
    h.owner.root.Position = h.extraction.Position
    h:tick(Config.Raid.NetCooldown + 0.1); h:net()
    assert(h:state().netHits == 2)
    h:tick(Config.Raid.NetCooldown + 0.1); h:net()
    assert(h:state() == nil)
    h:unchanged()
    assert(h.service.Profiles[h.owner]._reservedCreatures[h.creature.uid] == nil)
end

-- Leaving, resetting, dying and closing cancel all phases without deleting inventory.
for _, phase in {"stealing", "escape", "chase"} do
    for _, cause in {"thief-leave", "owner-leave", "reset", "death", "shutdown"} do
        local h = fixture()
        h:begin()
        if phase ~= "stealing" then h:escape() end
        if phase == "chase" then h:extract() end
        if cause == "thief-leave" then h.service.leave(h.thief)
        elseif cause == "owner-leave" then h.service.leave(h.owner)
        elseif cause == "reset" then h.thief.CharacterRemoving:Fire()
        elseif cause == "death" then h.thief.humanoid.Health = 0; h.thief.humanoid.Died:Fire()
        else h.controller.CancelAll() end
        assert(h:state() == nil, phase .. ": " .. cause .. " must cancel the raid")
        h:unchanged()
    end
end

do
    local h = fixture()
    h:begin(); h:escape(); h:tick(91)
    assert(h:state() == nil, "Missing extraction must time out")
    h:unchanged()
end

-- Leaving the playable map cannot turn a chase into an unreachable guaranteed win.
for _, outside in {
    position(Config.PlayableBounds.MaxX + 1, 18, 0),
    position(0, Config.PlayableBounds.MaxY + 1, 0),
    position(0, 18, Config.PlayableBounds.MinZ - 1),
    position(0, Config.PlayableBounds.MinY - 1, 0),
} do
    local h = fixture()
    h:begin(); h:escape(); h:extract()
    h.thief.root.Position = outside
    h:tick(0.3)
    assert(h:state() == nil, "An out-of-bounds thief must forfeit the pending raid")
    h:unchanged()
end

-- Capacity and save-state transitions cannot make a pending transfer unsafe.
for _, state in {"saved", "error"} do
    local h = fixture()
    h.service.Profiles[h.thief]._saving = state
    h:begin(); assert(h:state() == nil)
    h:unchanged()
end
do
    local h = fixture()
    h.service.Profiles[h.owner]._readOnly = true
    h:begin(); assert(h:state() == nil)
    h:unchanged()
end
do
    local h = fixture()
    for index = 1, Config.MaxCreatures do
        table.insert(h.service.Profiles[h.thief].creatures, {uid = "full-" .. index, species = "Mossbun"})
    end
    h:begin(); assert(h:state() == nil)
    assert(#h.service.Profiles[h.owner].creatures == 1)
end
do
    local h = fixture()
    h:begin(); h:escape(); h:extract()
    for index = 1, Config.MaxCreatures do
        table.insert(h.service.Profiles[h.thief].creatures, {uid = "full-" .. index, species = "Mossbun"})
    end
    h:tick(Config.Raid.ChaseSeconds + 0.1)
    assert(h:state() == nil and #h.service.Profiles[h.owner].creatures == 1)
    assert(#h.service.Profiles[h.thief].creatures == Config.MaxCreatures)
end
do
    local h = fixture()
    h:begin(); h:escape()
    h.service.Profiles[h.owner]._saving = "error"
    h:tick(0.3)
    assert(h:state() == nil)
    h:unchanged()
end

print("PASS: real RaidService ownership timing, three-hit recovery, reservations, cooldowns, death/reset/leave/shutdown cancellation and production gate")

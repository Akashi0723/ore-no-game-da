-- Real GameService; mocks model services/instances only, never reward logic.
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, callback)
            local connection = {Connected = true}
            function connection:Disconnect() self.Connected = false end
            table.insert(callbacks, {callback = callback, connection = connection})
            return connection
        end,
        Fire = function(_, ...)
            for _, item in callbacks do if item.connection.Connected then item.callback(...) end end
        end,
    }
end
local vectorMeta = {}
vectorMeta.__index = function(value, key)
    if key == "Magnitude" then return math.sqrt(value.X^2 + value.Y^2 + value.Z^2) end
end
vectorMeta.__sub = function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z}, vectorMeta) end
local function pos(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, vectorMeta) end

local function fixture(tutorial)
    local now, guid = 0, 0
    local instances = {}
    local function instance(className, name, parent)
        local attributes = {}
        local object = {ClassName=className, Name=name, Parent=parent, Triggered=signal()}
        function object:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
        function object:SetAttribute(name,value) attributes[name]=value end
        function object:GetAttribute(name) return attributes[name] end
        function object:FindFirstChild(name)
            for _, child in instances do if child.Parent==self and child.Name==name then return child end end
            return nil
        end
        function object:WaitForChild(name) return self:FindFirstChild(name) end
        function object:FindFirstChildOfClass(class)
            for _, child in instances do if child.Parent==self and child.ClassName==class then return child end end
            return nil
        end
        function object:Destroy() self.Parent=nil end
        table.insert(instances,object)
        return object
    end
    local workspace={GetServerTimeNow=function() return now end}
    local Players={people={},PlayerAdded=signal(),PlayerRemoving=signal()}
    function Players:GetPlayers() return self.people end
    function Players:GetPlayerByUserId(id)
        for _, p in self.people do if p.UserId==id then return p end end
        return nil
    end
    local RunService={Heartbeat=signal(),IsStudio=function() return true end}
    local HttpService={GenerateGUID=function() guid+=1;return "uid-"..guid end}
    local services={Players=Players,RunService=RunService,HttpService=HttpService,Lighting={}}
    local game={GetService=function(_,name) return assert(services[name],name) end,BindToClose=function() end}
    local os=table.clone(os)
    os.clock=function() return now end
    os.time=function() return 1700000000+math.floor(now) end
    local task={spawn=function(callback,...) callback(...) end,wait=function(seconds) now+=seconds or 0.1 end}
    task.defer=task.spawn
    local warn=function() end
    local typeof=function(value)
        if type(value)=="table" and value.ClassName then return "Instance" end
        if getmetatable(value)==vectorMeta then return "Vector3" end
        return type(value)
    end
    local Instance={new=instance}
    local Random={new=function() return {NextNumber=function() return 0 end} end}
    local CFrame={new=pos}
    local GameService=(function()
        -- INLINE_GAMESERVICE
    end)()
    local function player(id)
        local p=instance("Player","Player"..id,Players)
        p.UserId,p.DisplayName=id,"Player "..id
        p.CharacterAdded=signal()
        p.Character=instance("Model","Character",workspace)
        p.root=instance("Part","HumanoidRootPart",p.Character);p.root.Position=pos()
        p.humanoid=instance("Humanoid","Humanoid",p.Character);p.humanoid.Health=100
        function p.Character:PivotTo(position) p.root.Position=position end
        function p:Kick(reason) self.Kicked=reason end
        table.insert(Players.people,p)
        return p
    end
    local a,b=player(1),player(2)
    local profiles={}
    local PlayerData={Load=function(p)
        local data={coins=Config.StartCoins,xp=0,snacks={Berry=0,Seed=0},discoveries={},creatures={},research={},
            tutorialComplete=not tutorial,sanctuaryLevel=1,_saving="session"}
        profiles[p]=data
        return data
    end,Save=function() return true end}
    local function part(name,position,parent)
        local p=instance("Part",name,parent or workspace);p.Position=position or pos();return p
    end
    local root=instance("Model","WildboundWorld",workspace)
    instance("Folder","Creatures",root)
    local world={Root=root,Spawn=pos(),TutorialPosition=pos(),Shop=part("Shop"),PondGate=part("PondGate"),
        Extraction=part("Extraction"),
        Jobs={water={Part=part("Job"),Kind="Water",Label="Water flowers",Cooldown=10,Reward=15}},
        Clues={tracks={Part=part("Clue"),Species="Mossbun",Label="Tiny tracks"}},
        CreatureSpawns={{id="wild",species="Mossbun",position=pos()}},Sanctuaries={}}
    for index=1,2 do
        local s={Folder=instance("Model","Sanctuary"..index,root),Pedestals={},Sign={}}
        for slot=1,6 do table.insert(s.Pedestals,part("Pedestal"..slot)) end
        table.insert(world.Sanctuaries,s)
    end
    local World={Build=function() return world end,ShowDisplay=function() return nil end,
        CreateCreature=function(_,species,id,position)
            local model=instance("Model",id,root)
            model.PrimaryPart=part("Body",position,model)
            return model
        end}
    local states,messages={},{}
    local Remotes={Request={OnServerEvent=signal()},Update={FireClient=function(_,p,message)
        table.insert(messages,{player=p,message=message})
        if message.kind=="State" then states[p]=message.state end
    end}}
    local service=GameService.Start(Config,World,PlayerData,Remotes)
    local h={a=a,b=b,profiles=profiles,service=service,states=states,messages=messages}
    function h:request(p,request) Remotes.Request.OnServerEvent:Fire(p,request) end
    function h:tick(seconds) now+=seconds;RunService.Heartbeat:Fire(seconds) end
    function h:lure(p,target,snack) self:request(p,{action="Lure",target=target,snack=snack or "Berry"}) end
    function h:catch(p,target)
        self:request(p,{action="Sneak",enabled=true});self:lure(p,target)
        self:tick(Config.LureSeconds+0.1);self:request(p,{action="Befriend",target=target})
    end
    return h
end

-- The tutorial remains usable with no purchased snacks and after a mistake.
do
    local h=fixture(true)
    local profile=h.profiles[h.a]
    h:lure(h.a,"tutorial_1")
    h:tick(Config.LureSeconds+0.1)
    h:request(h.a,{action="Befriend",target="tutorial_1"})
    assert(#profile.creatures==0 and not profile.tutorialComplete)
    h:tick(1)
    h:catch(h.a,"tutorial_1")
    assert(profile.tutorialComplete and #profile.creatures==1,"The free tutorial encounter must support retries")
end
do
    local h=fixture(true)
    local profile=h.profiles[h.a]
    h:lure(h.a,"tutorial_1")
    h.a.root.Position=pos(50,0,0)
    h:tick(Config.LureLifetime+1)
    h.a.root.Position=pos()
    h:catch(h.a,"tutorial_1")
    assert(profile.tutorialComplete,"An expired first lure must not strand a new player without a berry")
end
do
    local h=fixture(true)
    h.profiles[h.b].snacks.Berry=2
    h:catch(h.b,"tutorial_1")
    assert(#h.profiles[h.b].creatures==0,"The first encounter must remain protected from rivals")
end

-- Two concurrent ready lures cannot both acquire one exclusive wild spawn.
do
    local h=fixture(false)
    h:tick(0.3)
    for _,p in {h.a,h.b} do
        h.profiles[p].snacks.Berry=2
        h:request(p,{action="Sneak",enabled=true});h:lure(p,"wild")
    end
    h:tick(Config.LureSeconds+0.1)
    h:request(h.a,{action="Befriend",target="wild"})
    h:request(h.b,{action="Befriend",target="wild"})
    assert(#h.profiles[h.a].creatures==1 and #h.profiles[h.b].creatures==0,"One wild spawn must have one winner")
    assert(h.profiles[h.a].xp==Config.Creatures.Mossbun.XP)
    h:request(h.a,{action="Befriend",target="wild"})
    assert(#h.profiles[h.a].creatures==1,"Duplicate capture requests cannot duplicate ownership")
end

-- Job cooldown and one-time clue research cannot farm duplicate rewards.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    local initial=profile.coins
    h:request(h.a,{action="Job",target="water"})
    h:request(h.a,{action="Job",target="water"})
    assert(profile.coins==initial+15)
    h:request(h.a,{action="Photo",target="tracks"})
    h:tick(0.5);h:request(h.a,{action="Photo",target="tracks"})
    assert(profile.coins==initial+15+Config.PhotoReward and profile.xp==Config.PhotoXP)
    h:request(h.a,{action="BuySnack",snack="Berry",coins=100000,amount=-1})
    assert(profile.snacks.Berry==1 and profile.coins==initial+15+Config.PhotoReward-Config.Snacks.Berry.Price)
    h:tick(1);profile.coins=0
    h:request(h.a,{action="BuySnack",snack="Berry"})
    assert(profile.coins==0 and profile.snacks.Berry==1,"Insufficient funds cannot produce negative coins")
end

-- Shared capacity and collection caps must agree with persisted limits.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    for level=1,Config.MaxSanctuaryLevel do
        profile.sanctuaryLevel=level
        h.service.SendState(h.a)
        assert(h.states[h.a].sanctuaryCapacity==Config.BaseDisplayCapacity+level-1,"Display capacity must match sanitized persistence")
    end
    for index=1,Config.MaxCreatures do table.insert(profile.creatures,{uid="full-"..index,species="Mossbun",displayed=false}) end
    assert(h.service.AddCreature(h.a,"Mossbun")==nil,"The ownership cap must match the save sanitizer")
    h:tick(0.3);profile.snacks.Berry=1
    h:catch(h.a,"wild")
    assert(#profile.creatures==Config.MaxCreatures and profile.xp==0)
end

-- A lost profile lock freezes all rewards, including passive display income.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    profile._readOnly=true
    profile.creatures={{uid="owned",species="Mossbun",displayed=true}}
    profile.snacks.Berry=1
    local initial=profile.coins
    for _,request in {
        {action="Job",target="water"},{action="Photo",target="tracks"},
        {action="BuySnack",snack="Berry"},{action="SetDisplay",target="owned",displayed=false},
        {action="UpgradeSanctuary"},
    } do h:request(h.a,request);h:tick(1) end
    h:tick(Config.DisplayIncomeSeconds+1)
    assert(profile.coins==initial and profile.xp==0 and profile.snacks.Berry==1)
    assert(profile.creatures[1].displayed and profile.sanctuaryLevel==1,"Read-only profiles cannot keep mutating")
end

-- The application freezes and exits before mutating a profile with an expired lease.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    profile._lockAt=1700000000-Config.Persistence.LockSeconds-1
    local initial=profile.coins
    h:request(h.a,{action="Job",target="water"})
    assert(profile.coins==initial and profile._readOnly==true and h.a.Kicked)
end

-- Releasing a held movement control must survive a depleted request bucket.
do
    local h=fixture(false)
    h:request(h.a,{action="Sneak",enabled=true})
    assert(h.a.humanoid.WalkSpeed==Config.SneakSpeed)
    for _=1,25 do h:request(h.a,{action="Sync"}) end
    h:request(h.a,{action="Sneak",enabled=false})
    assert(h.a.humanoid.WalkSpeed==Config.WalkSpeed,"Rate limits must not trap a released Sneak button")
end

print("PASS: real GameService tutorial retries, exclusive-capture race, reward limits, purchases, save-compatible caps and lost-lock freeze")

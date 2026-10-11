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
    if key == "Unit" then return value/math.max(1e-12,value.Magnitude) end
    if key == "Lerp" then
        return function(a,b,alpha)
            return setmetatable({X=a.X+(b.X-a.X)*alpha,Y=a.Y+(b.Y-a.Y)*alpha,Z=a.Z+(b.Z-a.Z)*alpha},vectorMeta)
        end
    end
end
vectorMeta.__sub = function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z}, vectorMeta) end
vectorMeta.__add = function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z}, vectorMeta) end
vectorMeta.__mul = function(a,b)
    if type(a)=="number" then a,b=b,a end
    return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b},vectorMeta)
end
vectorMeta.__div = function(a,b) return setmetatable({X=a.X/b,Y=a.Y/b,Z=a.Z/b},vectorMeta) end
local function pos(x,y,z) return setmetatable({X=x or 0,Y=y or 18,Z=z or 0}, vectorMeta) end
local Vector3={new=function(x,y,z) return pos(x or 0,y or 0,z or 0) end,zero=pos(0,0,0)}
local frameMeta={}
local function frame(x,y,z) return setmetatable({Position=type(x)=="table" and x or Vector3.new(x,y,z)},frameMeta) end
frameMeta.__index={Lerp=function(a,b,t) return frame(a.Position:Lerp(b.Position,t)) end}
frameMeta.__mul=function(a,b) return frame(a.Position+b.Position) end
frameMeta.__add=function(a,b) return frame(a.Position+b) end
local CFrame={new=frame,lookAt=function(a) return frame(a) end,Angles=function() return frame() end}
local Enum={KeyCode={F="F",DPadUp="DPadUp",E="E",ButtonX="ButtonX"}}

local function fixture(tutorial, settings)
    settings=settings or {}
    local now, guid = 0, 0
    local rolls=table.clone(settings.rolls or {})
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
        function object:GetDescendants()
            local descendants={}
            for _,child in instances do
                local ancestor=child.Parent
                while ancestor do
                    if ancestor==self then table.insert(descendants,child);break end
                    ancestor=ancestor.Parent
                end
            end
            return descendants
        end
        function object:GetPivot() return self.PrimaryPart and frame(self.PrimaryPart.Position) or frame() end
        function object:PivotTo(destination)
            self.pivotCount=(self.pivotCount or 0)+1
            if self.PrimaryPart then self.PrimaryPart.Position=destination.Position;self.PrimaryPart.CFrame=destination end
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
    local Random={new=function() return {NextNumber=function() return table.remove(rolls,1) or settings.roll or 0 end} end}

    local GameService=(function()
        -- INLINE_GAMESERVICE
    end)()
    local function player(id)
        local p=instance("Player","Player"..id,Players)
        p.UserId,p.DisplayName=id,"Player "..id
        p.CharacterAdded=signal()
        p.Character=instance("Model","Character",workspace)
        p.root=instance("Part","HumanoidRootPart",p.Character);p.root.Position=pos();p.root.CFrame=frame(p.root.Position)
        p.humanoid=instance("Humanoid","Humanoid",p.Character);p.humanoid.Health=100
        function p.Character:PivotTo(destination) self.pivotCount=(self.pivotCount or 0)+1;p.root.Position=destination.Position;p.root.CFrame=destination end
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
    local world={Root=root,FloorY=18,Spawn=frame(0,21.2,0),PondSpawn=frame(0,21.2,-88),TutorialPosition=pos(),Shop=part("Shop"),PondGate=part("PondGate"),
        Extraction=part("Extraction"),
        Jobs={water={Part=part("Job"),Kind="Water",Label="Water flowers",Cooldown=10,Reward=15}},
        Clues={tracks={Part=part("Clue"),Species="Mossbun",Label="Tiny tracks"},
            stones={Part=part("StoneClue"),Species="Pebblehog",Label="Polished stones"}},
        CreatureSpawns=settings.creatureSpawns or {{id="wild",species="Mossbun",position=pos()}},Sanctuaries={}}
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
    local h={a=a,b=b,profiles=profiles,service=service,states=states,messages=messages,world=world,instances=instances,rolls=rolls}
    function h:request(p,request) Remotes.Request.OnServerEvent:Fire(p,request) end
    function h:tick(seconds) now+=seconds;RunService.Heartbeat:Fire(seconds) end
    function h:now() return now end
    function h:setRoll(value) settings.roll=value end
    function h:entity(id)
        for _,object in instances do if object.Name==id and object.Parent and object.ClassName=="Model" then return object end end
        return nil
    end
    function h:lure(p,target,snack) self:request(p,{action="Lure",target=target,snack=snack or "Berry"}) end
    function h:catch(p,target,snack)
        self:request(p,{action="Sneak",enabled=true});self:lure(p,target,snack)
        self:tick(Config.LureSeconds+0.1);self:request(p,{action="Befriend",target=target})
    end
    return h
end

-- Nearby clue/job prompts cannot consume the creature action's keyboard or
-- gamepad binding. Check production-created prompts, not implementation text.
do
    local h=fixture(true)
    local count=0
    for _,object in h.instances do
        if object.ClassName=="ProximityPrompt" then
            count+=1
            assert(object:GetAttribute("WildboundWired")==true,"Modal prompt suspension needs a tagged server-wired field interaction")
            assert(object.KeyboardKeyCode==Enum.KeyCode.F and object.GamepadKeyCode==Enum.KeyCode.DPadUp,
                "World jobs, clues and menus must leave E/ButtonX available for the creature")
        end
    end
    assert(count>=7,"Prompt wiring fixture needs actual jobs/clues/shop/gate/sanctuaries")
    local before=h.profiles[h.a].coins
    local job=assert(h.world.Jobs.water.Part:FindFirstChild("Interaction"))
    job.Triggered:Fire(h.a)
    assert(h.profiles[h.a].coins==before+h.world.Jobs.water.Reward,"The separate job key must keep its real reward path")
    assert(#h.profiles[h.a].creatures==0,"A nearby world prompt cannot execute a creature catch")
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
    h.a.root.Position=pos(50,18,0)
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
    assert(h.profiles[h.a].xp==Config.Creatures.Mossbun.XP+10,"Wild capture and first-catch trail reward must each grant once")
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

-- Variant rolls belong to the spawn and survive capture without being rerolled.
do
    local h=fixture(false,{roll=0.995})
    h:tick(0.3)
    local model=assert(h:entity("wild"))
    assert(model:GetAttribute("Variant")=="Golden")
    h:setRoll(0)
    h.profiles[h.a].snacks.Berry=1
    h:catch(h.a,"wild")
    local captured=assert(h.profiles[h.a].creatures[1])
    assert(captured.variant=="Golden" and captured.bond==0 and captured.lastFed==0,
        "A capture must keep its spawn's cosmetic variant and initialize care fields")
    h.service.SendState(h.a)
    assert(h.states[h.a].creatures[1].variant=="Golden")
end

-- Trust is server elapsed time, not a client-supplied progress or chance field.
do
    local h=fixture(false,{roll=0.89})
    h:tick(0.3)
    h.profiles[h.a].snacks.Berry=2
    h:request(h.a,{action="Sneak",enabled=true})
    h:lure(h.a,"wild")
    h:tick(Config.LureSeconds+0.1)
    h:request(h.a,{action="Befriend",target="wild",trust=1,chance=1,readyAt=-1})
    assert(#h.profiles[h.a].creatures==0,"Forged full trust cannot beat the production capture roll")
    h:tick(0.7)
    h:lure(h.a,"wild")
    h:tick(Config.LureSeconds/2)
    h.service.SendState(h.a)
    assert(h.states[h.a].lures.wild.trust==0,"Trust cannot accrue before the snack lure is ready")
    h:tick(Config.LureSeconds/2+0.1)
    h:tick(0.5)
    h.service.SendState(h.a)
    local partial=h.states[h.a].lures.wild.trust
    assert(partial>0 and partial<0.5,"A short patient approach must have partial server-timed trust")
    h.a.root.Position=pos(50,18,0)
    h:tick(0.5);h.service.SendState(h.a)
    assert(h.states[h.a].lures.wild.trust==0,"Leaving approach range must clear trust")
    h.a.root.Position=pos()
    h:tick(0.3)
    h:tick(Config.TrustSeconds+0.1);h.service.SendState(h.a)
    assert(h.states[h.a].lures.wild.trust==1)
    local chance=h.states[h.a].lures.wild.chance
    assert(chance>Config.CaptureChance("Mossbun",1) and chance<=0.99)
    h:request(h.a,{action="Befriend",target="wild"})
    assert(#h.profiles[h.a].creatures==1,"Earned full trust must improve the same production capture roll")
end

-- Companion equipment accepts owned identities only and clears on ownership loss.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    local own=assert(h.service.AddCreature(h.a,"Mossbun","Moonlit"))
    local other=assert(h.service.AddCreature(h.b,"Mossbun","Golden"))
    h:request(h.a,{action="EquipCompanion",target=other.uid})
    assert(profile.equippedUid==nil,"A rival's UID cannot equip their creature")
    h:tick(0.6);h:request(h.a,{action="EquipCompanion",target=own.uid})
    assert(profile.equippedUid==own.uid)
    h.service.SendState(h.a)
    assert(h.states[h.a].equippedUid==own.uid and h.states[h.a].creatures[1].variant=="Moonlit")
    profile._reservedCreatures={[own.uid]=true}
    h:tick(0.6);h:request(h.a,{action="EquipCompanion"})
    h:tick(0.6);h:request(h.a,{action="EquipCompanion",target=own.uid})
    assert(profile.equippedUid==nil,"A pending raid target cannot become an equipped companion")
    profile._reservedCreatures=nil
    h:tick(0.6);h:request(h.a,{action="EquipCompanion",target=own.uid})
    assert(profile.equippedUid==own.uid)
    assert(h.service.RemoveCreature(h.a,own.uid))
    h.service.RefreshDisplays(h.a)
    assert(profile.equippedUid==nil,"Removed ownership cannot leave a dangling equipped companion")
end

-- Care consumes the server-selected favorite snack once and persists cooldowns.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    local entry=assert(h.service.AddCreature(h.a,"Mossbun"))
    local initialCoins,initialXP=profile.coins,profile.xp
    profile.snacks.Berry,profile.snacks.Seed=2,3
    h:request(h.a,{action="FeedCompanion",target=entry.uid,snack="Seed",bond=100,coins=10000})
    assert(entry.bond==Config.FeedBond and entry.lastFed==1700000000+math.floor(h:now()))
    assert(profile.snacks.Berry==1 and profile.snacks.Seed==3,
        "The client cannot choose a cheaper food or forge the care reward")
    assert(profile.coins==initialCoins and profile.xp==initialXP,"Care must not award capture XP or coins")
    h:tick(1);h:request(h.a,{action="FeedCompanion",target=entry.uid})
    assert(entry.bond==Config.FeedBond and profile.snacks.Berry==1,"Repeated feeding must enforce its persisted cooldown")
    h.service.SendState(h.a)
    assert(h.states[h.a].creatures[1].feedReadyIn>0 and h.states[h.a].creatures[1].feedReadyIn<=Config.FeedCooldownSeconds)
    h:tick(Config.FeedCooldownSeconds+1)
    entry.bond=Config.MaxBond-1
    h:request(h.a,{action="FeedCompanion",target=entry.uid})
    assert(entry.bond==Config.MaxBond and profile.snacks.Berry==0,"Feeding must cap bond at its shared limit")
    h:tick(Config.FeedCooldownSeconds+1)
    profile.snacks.Berry=1
    h:request(h.a,{action="FeedCompanion",target=entry.uid})
    assert(profile.snacks.Berry==1,"Fully bonded creatures must not consume another snack")
end
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    local entry=assert(h.service.AddCreature(h.a,"Mossbun"))
    profile.snacks.Seed=5
    h:request(h.a,{action="FeedCompanion",target=entry.uid})
    assert(entry.bond==0 and profile.snacks.Seed==5,"Lacking the favorite snack cannot consume other supplies")
    profile.snacks.Berry=2
    profile._reservedCreatures={[entry.uid]=true}
    h:tick(1);h:request(h.a,{action="FeedCompanion",target=entry.uid})
    assert(entry.bond==0 and profile.snacks.Berry==2,"Pending raid targets cannot be fed")
    profile._reservedCreatures=nil;profile._readOnly=true
    h:tick(1);h:request(h.a,{action="FeedCompanion",target=entry.uid})
    h:request(h.a,{action="EquipCompanion",target=entry.uid})
    assert(entry.bond==0 and profile.snacks.Berry==2 and profile.equippedUid==nil,
        "Read-only profiles cannot mutate care or equipment")
end

-- Receiving snapshots must never claim quest rewards or mutate progression.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    profile.discoveries.Mossbun=true
    profile.research.__trail_job=true
    local coins,xp,revision=profile.coins,profile.xp,profile._revision
    for _=1,3 do h.service.SendState(h.a);h:request(h.a,{action="Sync"}) end
    assert(profile.coins==coins and profile.xp==xp and profile._revision==revision)
    assert(not profile.research.__trail_claimed_firstcatch and not profile.research.__trail_claimed_firstjob,
        "Opening the UI cannot claim available milestones")
end

-- Validated actions claim sequential trail milestones exactly once.
do
    local h=fixture(true)
    local profile=h.profiles[h.a]
    local initial=profile.coins
    h:catch(h.a,"tutorial_1")
    assert(profile.research.__trail_claimed_firstcatch==true)
    assert(profile.coins==initial+20 and profile.xp==Config.Creatures.Mossbun.XP+10)
    h:request(h.a,{action="Job",target="water"})
    assert(profile.research.__trail_claimed_firstjob==true)
    assert(profile.coins==initial+20+15+25)
    h:tick(0.6);h:request(h.a,{action="Photo",target="tracks"})
    h:tick(0.6);h:request(h.a,{action="Photo",target="stones"})
    assert(profile.research.__trail_claimed_2photos==true)
    local after=profile.coins
    for _=1,3 do h:tick(1);h:request(h.a,{action="Sync"});h:request(h.a,{action="Photo",target="stones"}) end
    assert(profile.coins==after,"A completed clue and claimed quest cannot repeatedly pay")
    local questRewards={}
    for _,message in h.messages do
        if message.player==h.a and message.message.kind=="QuestComplete" then
            local id=message.message.id
            questRewards[id]=(questRewards[id] or 0)+1
        end
    end
    assert(questRewards.firstcatch==1 and questRewards.firstjob==1 and questRewards["2photos"]==1,
        "Each trail claim must announce one authoritative reward")
end

-- The later trail completes on real display/capture actions, without replay rewards.
do
    local h=fixture(false,{creatureSpawns={{id="reed",species="Reedling",position=pos()}}})
    local profile=h.profiles[h.a]
    for _,species in {"Mossbun","Pebblehog","Lanternwing"} do profile.discoveries[species]=true end
    for _,id in {"firstcatch","firstjob","2photos","3garden"} do profile.research["__trail_claimed_"..id]=true end
    local entry=assert(h.service.AddCreature(h.a,"Mossbun"))
    local coins,xp=profile.coins,profile.xp
    h:request(h.a,{action="SetDisplay",target=entry.uid,displayed=true})
    assert(profile.research.__trail_claimed_firstdisplay and profile.coins==coins+30 and profile.xp==xp+10)
    h:tick(0.6);h:request(h.a,{action="SetDisplay",target=entry.uid,displayed=false})
    assert(profile.coins==coins+30 and profile.xp==xp+10,"Returning to the vault cannot replay the first display reward")
    profile.snacks.Seed=1
    h:catch(h.a,"reed","Seed")
    assert(profile.research.__trail_claimed_pondcatch and profile.coins==coins+30+80)
    assert(profile.xp==xp+10+Config.Creatures.Reedling.XP+40)
    h.service.SendState(h.a)
    assert(h.states[h.a].questline.complete and h.states[h.a].questline.id=="complete")
end

-- Bonds affect passive income only for displayed owned creatures at each boundary.
for _,sample in {{0,0},{49,0},{50,1},{99,1},{100,2}} do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    local entry=assert(h.service.AddCreature(h.a,"Mossbun"))
    entry.displayed=true;entry.bond=sample[1]
    local coins=profile.coins
    h:tick(Config.DisplayIncomeSeconds+0.1)
    assert(profile.coins==coins+Config.DisplayIncomePerCreature+sample[2],
        "Display income must honor the bond boundary at "..sample[1])
    entry.displayed=false
    local after=profile.coins
    h:tick(Config.DisplayIncomeSeconds+0.1)
    assert(profile.coins==after,"Bonded vault creatures cannot generate exposed-display income")
end



-- Actual server patrols move their authoritative interaction roots, without
-- adding random rolls or root bobbing that would change capture range honesty.
do
    local h=fixture(false)
    h:tick(0.3)
    local model=assert(h:entity("wild"))
    local home=model:GetAttribute("HomePosition")
    local previous=model.PrimaryPart.Position
    local moved=false
    for _=1,500 do
        h:tick(0.05)
        local current=model.PrimaryPart.Position
        moved=moved or (current-home).Magnitude>0.2
        assert(math.abs(current.Y-home.Y)<1e-8,"Ambient gait cannot move the authoritative floor height")
        assert((current-home).Magnitude<=4.000001,"Unlured patrol escaped its authored habitat")
        assert((current-previous).Magnitude<=0.32,"Patrol replication jumped farther than its speed budget")
        assert(model:GetAttribute("MoveSpeed")>=0 and model:GetAttribute("MoveSpeed")<=3.2)
        previous=current
    end
    assert(moved,"Wildlife must leave its static spawn position without a lure")
    assert(#h.profiles[h.a].creatures==0,"Animation cannot grant ownership")
end
do
    local h=fixture(true)
    local model=assert(h:entity("tutorial_1"))
    local initial=model.PrimaryPart.Position
    for _=1,100 do h:tick(0.1) end
    assert((model.PrimaryPart.Position-initial).Magnitude==0,"The protected first creature must wait visibly at its hint")
end

-- Requests cannot select a forged remote world position for a lure, and the
-- moving model remains the actual source of truth for range checks.
do
    local h=fixture(false)
    h:tick(0.3)
    local model=assert(h:entity("wild"))
    local profile=h.profiles[h.a]
    profile.snacks.Berry=2
    h.a.root.Position=pos(12,21.2,0)
    h:request(h.a,{action="Sneak",enabled=true})
    h:request(h.a,{action="Lure",target="wild",snack="Berry",position={x=99999,y=-99999,z=99999}})
    local point=assert(h.states[h.a].lures.wild.position)
    assert(point.y==18 and math.abs(point.x-6)<1e-8 and point.z==0,"Snack placement must be clamped to the server habitat")
    point.x=99999 -- A received snapshot must not alias internal lure state.
    local earlier=model.PrimaryPart.Position
    h:tick(20)
    assert((model.PrimaryPart.Position-earlier).Magnitude<=1.65*0.25+1e-8,
        "A long server stall cannot teleport a creature all the way to its snack")
    for _=1,70 do h:tick(0.1) end
    assert((model.PrimaryPart.Position-pos(6,18,0)).Magnitude<1e-6,"Creature must approach its actual placed snack")
    assert(profile.snacks.Berry==1 and #profile.creatures==0,"The approach alone cannot catch a creature")
    h:request(h.a,{action="Sneak",enabled=false})
    h:tick(0.3)
    assert(model:GetAttribute("WildState")=="Startled","A running close approach must visibly startle the creature")
    local initial=model.PrimaryPart.Position
    h:tick(3)
    assert((model.PrimaryPart.Position-initial).Magnitude<=3.2*0.25+1e-8,"Retreat must remain bounded after a stalled frame")
    assert((model.PrimaryPart.Position-model:GetAttribute("HomePosition")).Magnitude<=6.000001)
end
do
    local h=fixture(false)
    h:tick(0.3)
    local model=assert(h:entity("wild"))
    h.profiles[h.a].snacks.Berry=1
    h:request(h.a,{action="Sneak",enabled=true});h:lure(h.a,"wild")
    h:tick(Config.LureSeconds+0.1)
    model.PrimaryPart.Position=pos(Config.BefriendRange+2,18,0)
    h:request(h.a,{action="Befriend",target="wild",distance=0,chance=1})
    assert(#h.profiles[h.a].creatures==0,"A moved root outside range must reject a forged nearby capture")
    model.PrimaryPart.Position=pos()
    h:tick(0.8);h:request(h.a,{action="Befriend",target="wild"})
    assert(#h.profiles[h.a].creatures==1,"The same real capture must succeed once the root returns in range")
end

-- Replication frequency stays bounded independently of client visual frame rate.
do
    local h=fixture(false)
    h:tick(0.3)
    local model=assert(h:entity("wild"))
    h.profiles[h.a].snacks.Berry=1
    h.a.root.Position=pos(12,21.2,0)
    h:request(h.a,{action="Sneak",enabled=true});h:lure(h.a,"wild")
    h:tick(0.1)
    local count=model.pivotCount or 0
    for _=1,4 do h:tick(0.02) end
    assert((model.pivotCount or 0)==count,"Decorative client frames cannot increase server movement replication")
    h:tick(0.03)
    assert((model.pivotCount or 0)==count+1,"At most one authoritative root update may occur per 100ms budget")
    count=model.pivotCount
    for _=1,50 do h:tick(0.005) end
    assert(model.pivotCount-count<=3,"Wildlife must remain within its 10Hz replication budget")
end

-- Forecast values expose the actual weather cycle without granting progression.
do
    local h=fixture(false)
    local profile=h.profiles[h.a]
    for _=1,#Config.WeatherOrder+1 do
        h.service.SendState(h.a)
        local state=h.states[h.a]
        local index=assert(table.find(Config.WeatherOrder,state.weather))
        assert(state.nextWeather==Config.WeatherOrder[index%#Config.WeatherOrder+1])
        assert(state.nextWeatherIn>=0 and state.nextWeatherIn<=Config.WeatherSeconds)
        for species,definition in Config.Creatures do
            local waitSeconds=state.creatureWeatherWait[species]
            if definition.Weather=="Any" or definition.Weather==state.weather then
                assert(waitSeconds==0,"Available species cannot display a weather wait")
            else
                local offset=1
                while Config.WeatherOrder[(index+offset-1)%#Config.WeatherOrder+1]~=definition.Weather do offset+=1 end
                assert(waitSeconds==state.nextWeatherIn+(offset-1)*Config.WeatherSeconds,
                    "Forecast must count the same actual weather windows as spawning")
            end
        end
        local coins,xp=profile.coins,profile.xp
        h:request(h.a,{action="Sync"})
        assert(profile.coins==coins and profile.xp==xp,"Reading a weather forecast cannot grant rewards")
        local expected=state.nextWeather
        h:tick(Config.WeatherSeconds+0.1)
        h.service.SendState(h.a)
        assert(h.states[h.a].weather==expected,"Forecast must predict the next actual server weather")
    end
end

-- New players must recover from the island void without needing a companion.
for _,outside in {pos(0,9,0),pos(Config.PlayableBounds.MaxX+1,21.2,0),pos(0,21.2,Config.PlayableBounds.MaxZ+1)} do
    local h=fixture(true)
    local profile=h.profiles[h.a]
    h.a.root.Position=outside
    h:tick(0.3)
    assert((h.a.root.Position-h.world.Spawn.Position).Magnitude<1e-8,"Void recovery must work before the first creature capture")
    assert(#profile.creatures==0 and not profile.tutorialComplete,"Recovery cannot change collection progress")
    assert(h:entity("tutorial_1"),"Recovery cannot lose the protected first encounter")
end
do
    local h=fixture(false)
    h.a.root.Position=pos(0,Config.PlayableBounds.MaxY+10,0)
    h:tick(0.3)
    assert(h.a.root.Position.Y==Config.PlayableBounds.MaxY+10,"A normal high jump must not count as island void")
    h.service.RaidStates[h.a]={phase="escape"}
    h.a.root.Position=pos(0,9,0)
    h:tick(0.3)
    assert(h.a.root.Position.Y==9,"Raid cancellation must inspect the actual fall before normal recovery")
    h.service.RaidStates[h.a]=nil
    h:tick(0.3)
    assert((h.a.root.Position-h.world.Spawn.Position).Magnitude<1e-8,"Recovery must resume after the raid clears")
end

-- Earned pond travel lands on the new raised deck and remains there.
do
    local h=fixture(false)
    h:request(h.a,{action="PondGate"})
    assert(h.a.root.Position.Z==h.world.Spawn.Position.Z,"A locked visitor cannot use the pond shortcut")
    for _,species in {"Mossbun","Lanternwing","Pebblehog"} do h.profiles[h.a].discoveries[species]=true end
    h:tick(1.1);h:request(h.a,{action="PondGate"})
    assert((h.a.root.Position-h.world.PondSpawn.Position).Magnitude<1e-8,"The pond teleport cannot land below the island")
    h:tick(0.3)
    assert(h.a.root.Position.Y>h.world.FloorY,"Earned pond travel cannot immediately trigger void recovery")
end
print("PASS: real GameService economy/ownership/quests/care, bounded moving roots and patrols, authoritative lure ranges, actual forecasts, companion-free void recovery and raised pond travel")

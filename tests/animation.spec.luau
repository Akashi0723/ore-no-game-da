-- Real procedural rig metadata and production Pose/Bind/Apply behind math adapters.
-- These checks cover articulation, deterministic poses, scaling and pivot safety;
-- Roblox render timing and replicated visual smoothness require Studio playtests.
-- INLINE_PLATFORM
-- INLINE_CONFIG
-- INLINE_CREATUREVISUAL
-- INLINE_CREATUREMOTION
local function near(a,b,message)
    assert(math.abs(a-b)<1e-7,(message or "numeric mismatch")..": "..tostring(a).." vs "..tostring(b))
end
local function frameClose(a,b,message)
    near((a.Position-b.Position).Magnitude,0,message)
    for i=1,9 do near(a.m[i],b.m[i],message) end
end
local function bounded(pose)
    for group,values in pose do
        for channel,value in values do
            assert(type(value)=="number" and value==value and math.abs(value)<2,
                "Unbounded numeric pose: "..group.."."..channel)
        end
        for _,key in {"x","y","z","rx","ry","rz"} do assert(values[key]~=nil,"Missing joint channel") end
    end
end
local function samePose(a,b)
    for name,channels in a do for key,value in channels do near(value,b[name][key],"Deterministic pose") end end
end
local function signature(pose)
    local values={}
    for _,group in {"Body","Head","Tail","LegLF","EarL"} do
        for _,key in {"x","y","z","rx","ry","rz"} do table.insert(values,string.format("%.4f",pose[group][key])) end
    end
    return table.concat(values,",")
end
local styles={}
for _,species in Config.CreatureOrder do
    local state={mood="Curious",speed=4,age=0.1}
    local pose=CreatureMotion.Pose(species,0.53,state,0.31)
    bounded(pose)
    local style=signature(pose)
    assert(not styles[style],"Each species needs distinct movement: "..species.." and "..tostring(styles[style]))
    styles[style]=species
    samePose(pose,CreatureMotion.Pose(species,0.53,state,0.31))
    assert(state.mood=="Curious" and state.speed==4 and state.age==0.1,"Pose cannot mutate authoritative input state")
    pose.Body.y=999
    bounded(CreatureMotion.Pose(species,0.53,state,0.31))
    for _,time in {0,0.17,1.8,10,1000,0/0,math.huge,-math.huge,"bad"} do
        for _,mood in {"Idle","Walking","Curious","Eating","Startled","Happy","Bond","Capture","unknown"} do
            bounded(CreatureMotion.Pose(species,time,{mood=mood,speed=100,age=0},math.huge))
        end
    end
    for _,badState in {false,123,"bad",{mood=false,speed=0/0,age=math.huge},{speed=-math.huge}} do
        bounded(CreatureMotion.Pose(species,1,badState,0/0))
    end
    local quietA=CreatureMotion.Pose(species,0.23,{mood="Idle",speed=0,reducedMotion=true},0)
    local quietB=CreatureMotion.Pose(species,3.8,{mood="Idle",speed=0,reducedMotion=true},2)
    samePose(quietA,quietB)
    assert(quietA.EyeL.scaleY==1 and quietA.EyeR.scaleY==1,"Reduced motion cannot repeatedly hide eyes")
    local reactions=CreatureMotion.Pose(species,0.23,{mood="Curious",speed=0,reducedMotion=true},0)
    assert(reactions.Head.rx>quietA.Head.rx,"Reduced motion must retain the static snack-interest cue")
end
for _,time in {0.12,0.7,1.3,4} do
    local wings=CreatureMotion.Pose("Lanternwing",time,{speed=4},0)
    near(wings.WingL.ry,-wings.WingR.ry,"Paired wings must flap around opposing hinges")
    local legs=CreatureMotion.Pose("Bloomstag",time,{speed=4},0)
    near(legs.LegLF.rx,-legs.LegRF.rx,"Walking quadruped needs alternating feet")
    near(legs.LegLF.rx,legs.LegRR.rx,"Diagonal quadruped legs must move together")
end
local startled=CreatureMotion.Pose("Mistfox",1,{mood="Startled",age=0},0)
local recovered=CreatureMotion.Pose("Mistfox",1,{mood="Startled",age=1},0)
assert(startled.Body.rx<recovered.Body.rx,"A startle must recoil and settle rather than loop forever")
local blink=CreatureMotion.Pose("Mossbun",-1.29,{},0)
near(blink.EyeL.scaleY,0.06,"Blink reaches its authored closed-eye pose")
local open=CreatureMotion.Pose("Mossbun",0,{},0)
assert(open.EyeL.scaleY==1,"Blink must release automatically")

for _,species in Config.CreatureOrder do
    local model=CreatureVisual.Build(Config,species)
    model.Parent=workspace
    for _,variant in {"Normal","Moonlit","Golden"} do
        CreatureVisual.ApplyVariant(Config,model,variant)
        local record=assert(CreatureMotion.Bind(model))
        assert(#record.parts>5,"Animated rig cannot lose its visible body")
        for _,detail in record.parts do
            assert(typeof(detail.rest)=="CFrame" and typeof(detail.size)=="Vector3","Rig needs unit-scale rest transforms")
            local group=record.groups[detail.group]
            assert(group and group.parent~=detail.group,"Rig cannot parent a joint to itself")
            assert(detail.part~=model.PrimaryPart,"Authoritative root cannot be an animated decoration")
        end
        for _,scale in {1,0.62,1.7} do
            model:ScaleTo(scale)
            local destination=CFrame.new(17,18,-31)*CFrame.Angles(0.3,0.7,-0.1)
            model:PivotTo(destination)
            local rootFrame=model.PrimaryPart.CFrame
            CreatureMotion.Apply(record,2.13,{mood="Curious",speed=4},0.27)
            assert(model.PrimaryPart.CFrame==rootFrame,"Articulation must never move the range/capture root")
            local posed={}
            for _,detail in record.parts do
                posed[detail.part]=detail.part.CFrame
                assert(detail.part.Position.Magnitude<100,"Animated child escaped its root")
            end
            -- All color insets/eyes/markings sharing a joint must travel rigidly.
            -- Compare full rest-relative rotations, not just center distances.
            local firstByGroup={}
            for _,detail in record.parts do
                local first=firstByGroup[detail.group]
                if first then
                    local firstRest=CFrame.new(first.rest.Position*scale)*first.rest.Rotation
                    local nextRest=CFrame.new(detail.rest.Position*scale)*detail.rest.Rotation
                    frameClose(first.part.CFrame:ToObjectSpace(detail.part.CFrame),firstRest:ToObjectSpace(nextRest),
                        "Connected joint details detached: "..species.."/"..detail.group)
                else firstByGroup[detail.group]=detail end
            end
            CreatureMotion.Apply(record,2.13,{mood="Curious",speed=4},0.27)
            for part,expected in posed do frameClose(part.CFrame,expected,"Animation accumulated drift") end
            -- Reset is relative to the latest server root, including its rotation.
            local relocated=CFrame.new(-9,27,8)*CFrame.Angles(-0.2,-1.1,0.04)
            model:PivotTo(relocated)
            local currentRoot=model.PrimaryPart.CFrame
            CreatureMotion.Reset(record)
            assert(model.PrimaryPart.CFrame==currentRoot,"Reset cannot undo a server movement")
            for _,detail in record.parts do
                frameClose(detail.part.CFrame,currentRoot*CFrame.new(detail.rest.Position*scale)*detail.rest.Rotation,
                    "Reset lost the rig's rest shape or current scale")
                near((detail.part.Size-detail.size*scale).Magnitude,0,"Reset must restore eye size")
            end
        end
    end
    local record=CreatureMotion.Bind(model)
    CreatureMotion.Apply(record,-1.29,{mood="Idle"},0)
    local sawClosedGlint=false
    for _,detail in record.parts do
        if detail.eye and detail.glint then sawClosedGlint=sawClosedGlint or detail.part.Transparency==1 end
    end
    assert(sawClosedGlint,"Closed eyes must hide their glints: "..species)
    CreatureMotion.Reset(record)
    for _,detail in record.parts do
        if detail.glint then assert(detail.part.Transparency==detail.transparency,"Eye glints must return after reset") end
    end
    model:Destroy()
    CreatureMotion.Apply(record,1,{})
    CreatureMotion.Reset(record)
end
print("PASS: real eight-species poses, finite hostile inputs, reduced motion, blink/startle timing, articulated joint integrity, scale-aware resets and stable authoritative roots")

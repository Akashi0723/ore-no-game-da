-- INLINE_PLATFORM
-- INLINE_CONFIG
-- INLINE_CREATUREVISUAL
local modules=Instance.new("Folder");modules.Name="Wildbound";modules.Parent=ReplicatedStorage
local visualModule=Instance.new("ModuleScript");visualModule.Name="CreatureVisual";visualModule.Parent=modules
local require=function(module) assert(module==visualModule,"Unexpected module dependency");return CreatureVisual end
-- INLINE_WORLD
local userBaseplate=Instance.new("Part");userBaseplate.Name="Baseplate";userBaseplate.Parent=workspace
userBaseplate.CFrame=frame(5,-4,9);userBaseplate.Size=v(512,4,512);userBaseplate.Transparency=0.3;userBaseplate.CanCollide=true
local originalFrame,originalSize=userBaseplate.CFrame,userBaseplate.Size
local world=World.Build(Config)
local function count(root,filter) local n=0 for _,o in root:GetDescendants() do if filter(o) then n+=1 end end return n end
local function baseparts(root) return count(root,function(o) return o:IsA("BasePart") end) end
local function assertEq(a,b,message) assert(a==b,(message or "mismatch")..": "..tostring(a).." vs "..tostring(b)) end
local firstCount=baseparts(world.Root)
assert(firstCount<=2200,"Scene part budget exceeded")
for _,object in world.Root:GetDescendants() do
    if object:IsA("BasePart") then assert(object.Anchored==true,"Generated static geometry must be anchored") end
    assert(object.ClassName~="MeshPart" and object.ClassName~="Decal" and object.ClassName~="Sound",
        "The procedural scene must not acquire undeclared external asset dependencies")
end
local scenePrompts=0
for _,object in world.Root:GetDescendants() do
    if object:IsA("ProximityPrompt") then
        scenePrompts+=1
        assert(object.KeyboardKeyCode==Enum.KeyCode.F and object.GamepadKeyCode==Enum.KeyCode.DPadUp,
            "Scenic world prompts cannot share the creature's E/ButtonX binding")
    end
end
assert(scenePrompts>8,"The scene must expose its actual native interactions")
assertEq(count(world.Root,function(o) return o.ClassName=="PointLight" end),8,"static light budget")
assert(count(world.Root,function(o) return o:GetAttribute("WindFoliage")==true end)<=12,"wind budget")
assertEq(#world.CreatureSpawns,9,"creature spawns")
assertEq(#world.Sanctuaries,8,"habitats")
assertEq(world.TutorialPosition.Y,18,"floor offset")
assertEq(userBaseplate.Parent,workspace,"existing place retained")
assertEq(userBaseplate.CFrame,originalFrame,"existing place frame retained")
assertEq(userBaseplate.Size,originalSize,"existing place size retained")
assertEq(userBaseplate.Transparency,0.3,"existing place appearance retained")
assertEq(userBaseplate.CanCollide,true,"existing place collision retained")
assertEq(world.FloorY,18,"raised island floor")
assert(math.abs(world.Spawn.Position.Y-21.2)<1e-8,"Player spawn must start safely above the island deck")
assert(math.abs(world.PondSpawn.Position.Y-21.2)<1e-8,"Pond destination must not double-apply the island lift")
assert(world.PondSpawn.Position.Z < -72,"Pond travel must actually enter the unlocked area")
local ocean,caps=nil,{}
for _,object in world.Root:GetDescendants() do
    if object.Name=="SurroundingOcean" then ocean=object end
    if object.Name=="WalkingMeadow" then table.insert(caps,object) end
end
assert(ocean and ocean.CanCollide==false,"Scenic ocean cannot become a floor beneath the island")
assert(math.abs(ocean.Position.Y+ocean.Size.Y/2-4)<1e-8,"The opaque ocean surface must hide the old baseplate below the raised island")
assert((ocean.Transparency or 0)==0,"Ocean must remain opaque")
assert(#caps>=3,"Raised rounded landforms must support every playable region")
local function topHeight(part)
    local rotation=part.CFrame
    return part.Position.Y+math.abs(rotation.RightVector.Y)*part.Size.X/2+
        math.abs(rotation.UpVector.Y)*part.Size.Y/2+math.abs(rotation.LookVector.Y)*part.Size.Z/2
end
for index,cap in caps do
    local top=topHeight(cap)
    assert(top>=18-1e-7 and top<=18.020001,"Meadow layering must remain near the creature interaction floor")
    for previous=1,index-1 do
        assert(math.abs(top-topHeight(caps[previous]))>0.0001,
            "Overlapping rounded islands must avoid exactly coplanar faces")
    end
end
-- The rendered terrain pass separates grass, path borders, path fill and joins.
-- Verify those ordering relationships on actual authored part transforms.
local trails={}
for _,object in world.Root:GetDescendants() do
    if object.Name=="Trail" then
        local group=trails[object.Parent] or {fills={},edges={},joins={}}
        trails[object.Parent]=group;table.insert(group.fills,object)
    elseif object.Name=="TrailEdge" or object.Name=="TrailJoin" then
        local group=trails[object.Parent] or {fills={},edges={},joins={}}
        trails[object.Parent]=group;table.insert(object.Name=="TrailEdge" and group.edges or group.joins,object)
    end
end
for _,group in trails do
    assert(#group.fills==#group.edges and #group.joins==#group.fills,"Every trail segment needs layered borders and safe joins")
    local highestFill,lowestJoin=0,math.huge
    for index,fill in group.fills do
        assert(topHeight(fill)>topHeight(group.edges[index])+0.02,"Path fill must rise above its border to avoid coplanar surfaces")
        assert(topHeight(fill)>18.020001,"The path cannot fight with its underlying meadow face")
        highestFill=math.max(highestFill,topHeight(fill))
    end
    for _,join in group.joins do lowestJoin=math.min(lowestJoin,topHeight(join)) end
    assert(lowestJoin>highestFill+0.01,"Trail joins need a separate top layer above intersecting segments")
end
for _,sanctuary in world.Sanctuaries do
    local floor=assert(sanctuary.Folder:FindFirstChild("HabitatFloor"))
    local cross=assert(sanctuary.Folder:FindFirstChild("HabitatFloorCross"))
    assert(topHeight(cross)>topHeight(floor)+0.005,"Intersecting habitat floor faces must not be exactly coplanar")
end
local function meadowSupport(position)
    for _,cap in caps do
        local point=cap.CFrame:PointToObjectSpace(v(position.X,world.FloorY,position.Z))
        if math.abs(point.X)<=cap.Size.X/2+1e-7 and (point.Y/(cap.Size.Y/2))^2+(point.Z/(cap.Size.Z/2))^2<=1+1e-7 then
            assert(cap.CanCollide==true,"A playable meadow cannot be decorative only")
            return true
        end
    end
    return false
end
assert(meadowSupport(world.TutorialPosition),"Protected first encounter must sit on actual island ground")
assert(meadowSupport(world.Spawn.Position),"Player spawn needs a colliding island underneath")
for _,spawn in world.CreatureSpawns do
    assert(Config.Creatures[spawn.species],"Missing species definition")
    assert(spawn.position.X>=Config.PlayableBounds.MinX and spawn.position.X<=Config.PlayableBounds.MaxX,"spawn x bounds")
    assert(spawn.position.Z>=Config.PlayableBounds.MinZ and spawn.position.Z<=Config.PlayableBounds.MaxZ,"spawn z bounds")
    assertEq(spawn.position.Y,18,"spawn floor offset")
    assert(meadowSupport(spawn.position),"Encounter home must have an actual island floor: "..spawn.id)
    for angleIndex=1,16 do
        local angle=angleIndex*math.pi/8
        assert(meadowSupport(spawn.position+v(math.cos(angle)*6,0,math.sin(angle)*6)),
            "A retreat/lure envelope reaches unsupported coastline: "..spawn.id)
    end
end
for _,sanctuary in world.Sanctuaries do
    World.DecorateSanctuary(sanctuary,4)
    local before=baseparts(sanctuary.Folder)
    World.DecorateSanctuary(sanctuary,4)
    assertEq(baseparts(sanctuary.Folder),before,"decor idempotency")
    assertEq(sanctuary.Folder:FindFirstChild("HabitatDecorations"):GetAttribute("Level"),4)
end
local maxCount=baseparts(world.Root)
assert(maxCount<=2500,"max decorated world part budget")
for _,species in Config.CreatureOrder do
    local natural=CreatureVisual.Build(Config,species)
    assert(natural.PrimaryPart and natural.PrimaryPart:IsA("BasePart"),"Creature has no valid pivot: "..species)
    local naturalCount=baseparts(natural)
    assert(naturalCount<=80,"Creature geometry exceeds the carried/portrait budget: "..species)
    natural:Destroy()
    local model=World.CreateCreature(Config,species,"test_"..species,v(0,18,0),nil,"Golden")
    assertEq(model:GetAttribute("Variant"),"Golden")
    assertEq(model.PrimaryPart:GetAttribute("Variant"),"Golden")
    assertEq(model.PrimaryPart:GetAttribute("EntityId"),"test_"..species)
    local creaturePrompt=assert(model.PrimaryPart:FindFirstChild("Interaction"),"interaction missing")
    assertEq(creaturePrompt.KeyboardKeyCode,Enum.KeyCode.E,"creature keyboard binding")
    assertEq(creaturePrompt.GamepadKeyCode,Enum.KeyCode.ButtonX,"creature gamepad binding")
    local original=baseparts(model)
    assert(original<=80,"Rare variant exceeds the carried/portrait budget: "..species)
    CreatureVisual.ApplyVariant(Config,model,"Golden")
    assertEq(baseparts(model),original,"variant idempotency")
    CreatureVisual.ApplyVariant(Config,model,"Normal")
    assertEq(baseparts(model),naturalCount,"variant reset must remove decorations without deleting body parts")
    CreatureVisual.ApplyVariant(Config,model,"Moonlit")
    local display=World.ShowDisplay(Config,world.Sanctuaries[1].Pedestals[1],{uid="owned",species=species,variant="Moonlit"})
    assertEq(display:GetAttribute("Variant"),"Moonlit","display variant")
    World.ShowDisplay(Config,world.Sanctuaries[1].Pedestals[1],nil)
    assertEq(world.Sanctuaries[1].Pedestals[1]:FindFirstChild("DisplayCreature"),nil,"display clear")
    model:Destroy()
end
local rebuilt=World.Build(Config)
assertEq(world.Root.Parent,nil,"replaced only generated root")
assertEq(userBaseplate.Parent,workspace,"baseplate retained on rebuild")
assertEq(baseparts(rebuilt.Root),firstCount,"deterministic rebuild")
print("PASS: real world generation",firstCount,"initial parts;",maxCount,"all tier-4 decorated parts; 8 lights; <=12 wind parts; 9 spawns; 8 habitats; raised walkable islands and opaque ocean; variants and displays idempotent; existing place properties preserved")

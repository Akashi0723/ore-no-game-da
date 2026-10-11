-- Platform-only adapters; real Config, CreatureVisual and World are inlined below.
-- CFrame rotation is intentionally omitted: this verifies construction contracts,
-- ownership of generated objects and resource budgets, never rendering/collision.
local vec = {}
vec.__index = function(a,k)
    if k == "Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    if k == "Lerp" then return function(x,y,t) return x+(y-x)*t end end
end
local function v(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vec) end
vec.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul=function(a,b) if type(a)=="number" then a,b=b,a end return v(a.X*b,a.Y*b,a.Z*b) end
vec.__div=function(a,b) return v(a.X/b,a.Y/b,a.Z/b) end
local Vector3={new=v,zero=v()}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local cf={}
cf.__index=function(a,k) if k=="Position" then return a.p elseif k=="Rotation" then return setmetatable({p=v()},cf) end end
local function frame(x,y,z) return setmetatable({p=type(x)=="table" and x or v(x,y,z)},cf) end
cf.__mul=function(a,b) return frame(a.p+b.p) end
cf.__add=function(a,b) return frame(a.p+b) end
cf.__sub=function(a,b) return frame(a.p-b) end
local CFrame={new=frame,Angles=function() return frame() end,lookAt=function(a) return frame(a) end}
local col={}
col.__index={Lerp=function(a,b,t) return setmetatable({R=a.R+(b.R-a.R)*t,G=a.G+(b.G-a.G)*t,B=a.B+(b.B-a.B)*t},col) end}
local Color3={fromRGB=function(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255},col) end}
local typeof=function(a) if getmetatable(a)==col then return "Color3" end return type(a) end
local Enum=setmetatable({}, {__index=function(self,k)
    local group=setmetatable({}, {__index=function(_,item) return k.."."..item end}) rawset(self,k,group) return group
end})
local UDim2={new=function(...) return {...} end,fromScale=function(...) return {...} end,fromOffset=function(...) return {...} end}
local objects={}
local methods={}
local function belongs(child,parent)
    local ancestor=child.Parent
    while ancestor do if ancestor==parent then return true end ancestor=ancestor.Parent end
    return false
end
function methods:IsA(kind) return self.ClassName==kind or (kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart" or self.ClassName=="SpawnLocation")) end
function methods:SetAttribute(k,value) self._attrs[k]=value end
function methods:GetAttribute(k) return self._attrs[k] end
function methods:GetDescendants() local t={} for _,o in objects do if belongs(o,self) then table.insert(t,o) end end return t end
function methods:FindFirstChild(name) for _,o in objects do if o.Parent==self and o.Name==name then return o end end return nil end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:Destroy() for _,o in self:GetDescendants() do o.Parent=nil end self.Parent=nil end
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self._pivot or frame() end
function methods:PivotTo(destination)
    local delta=destination.Position-self:GetPivot().Position
    for _,p in self:GetDescendants() do if p:IsA("BasePart") then p.CFrame=p.CFrame+delta end end
    self._pivot=destination
end
function methods:GetScale() return self._scale or 1 end
function methods:ScaleTo(scale)
    local origin=self:GetPivot().Position
    local ratio=scale/self:GetScale()
    for _,p in self:GetDescendants() do if p:IsA("BasePart") then p.Size=p.Size*ratio;p.CFrame=frame(origin+(p.Position-origin)*ratio) end end
    self._scale=scale
end
local Instance={new=function(className)
    local o=setmetatable({_attrs={},ClassName=className,Name=className}, {__index=function(a,k) if k=="Position" then return a.CFrame and a.CFrame.Position or v() end return methods[k] end})
    table.insert(objects,o) return o
end}
local workspace=Instance.new("Workspace")
local ReplicatedStorage=Instance.new("ReplicatedStorage")
local game={GetService=function(_,name) assert(name=="ReplicatedStorage") return ReplicatedStorage end}
-- INLINE_CONFIG
-- INLINE_CREATUREVISUAL
local modules=Instance.new("Folder");modules.Name="Wildbound";modules.Parent=ReplicatedStorage
local visualModule=Instance.new("ModuleScript");visualModule.Name="CreatureVisual";visualModule.Parent=modules
local require=function(module) assert(module==visualModule,"Unexpected module dependency");return CreatureVisual end
-- INLINE_WORLD
local userBaseplate=Instance.new("Part");userBaseplate.Name="Baseplate";userBaseplate.Parent=workspace
local world=World.Build(Config)
local function count(root,filter) local n=0 for _,o in root:GetDescendants() do if filter(o) then n+=1 end end return n end
local function baseparts(root) return count(root,function(o) return o:IsA("BasePart") end) end
local function assertEq(a,b,message) assert(a==b,(message or "mismatch")..": "..tostring(a).." vs "..tostring(b)) end
local firstCount=baseparts(world.Root)
assert(firstCount<1800,"Scene part budget exceeded")
for _,object in world.Root:GetDescendants() do
    if object:IsA("BasePart") then assert(object.Anchored==true,"Generated static geometry must be anchored") end
    assert(object.ClassName~="MeshPart" and object.ClassName~="Decal" and object.ClassName~="Sound",
        "The procedural scene must not acquire undeclared external asset dependencies")
end
assertEq(count(world.Root,function(o) return o.ClassName=="PointLight" end),8,"static light budget")
assert(count(world.Root,function(o) return o:GetAttribute("WindFoliage")==true end)<=12,"wind budget")
assertEq(#world.CreatureSpawns,9,"creature spawns")
assertEq(#world.Sanctuaries,8,"habitats")
assertEq(world.TutorialPosition.Y,0.05,"floor offset")
assertEq(userBaseplate.Parent,workspace,"existing place retained")
for _,spawn in world.CreatureSpawns do
    assert(Config.Creatures[spawn.species],"Missing species definition")
    assert(spawn.position.X>=Config.PlayableBounds.MinX and spawn.position.X<=Config.PlayableBounds.MaxX,"spawn x bounds")
    assert(spawn.position.Z>=Config.PlayableBounds.MinZ and spawn.position.Z<=Config.PlayableBounds.MaxZ,"spawn z bounds")
    assertEq(spawn.position.Y,0.05,"spawn floor offset")
end
for _,sanctuary in world.Sanctuaries do
    World.DecorateSanctuary(sanctuary,4)
    local before=baseparts(sanctuary.Folder)
    World.DecorateSanctuary(sanctuary,4)
    assertEq(baseparts(sanctuary.Folder),before,"decor idempotency")
    assertEq(sanctuary.Folder:FindFirstChild("HabitatDecorations"):GetAttribute("Level"),4)
end
local maxCount=baseparts(world.Root)
assert(maxCount<1800,"max decorated world part budget")
for _,species in Config.CreatureOrder do
    local natural=CreatureVisual.Build(Config,species)
    assert(natural.PrimaryPart and natural.PrimaryPart:IsA("BasePart"),"Creature has no valid pivot: "..species)
    local naturalCount=baseparts(natural)
    natural:Destroy()
    local model=World.CreateCreature(Config,species,"test_"..species,v(0,0.05,0),nil,"Golden")
    assertEq(model:GetAttribute("Variant"),"Golden")
    assertEq(model.PrimaryPart:GetAttribute("Variant"),"Golden")
    assertEq(model.PrimaryPart:GetAttribute("EntityId"),"test_"..species)
    assert(model.PrimaryPart:FindFirstChild("Interaction"),"interaction missing")
    local original=baseparts(model)
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
print("PASS: real world generation",firstCount,"initial parts;",maxCount,"all tier-4 decorated parts; 8 lights; <=12 wind parts; 9 spawns; 8 habitats; variants and displays idempotent; existing place preserved")

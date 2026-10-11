-- Offline scene extraction, not a Roblox runtime emulator. Full rigid transforms
-- preserve the authored geometry for Blender previews and the editor model.
local vector = {}
local function v(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector) end
vector.__index = function(a,key)
	if key == "Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
	if key == "Unit" then local length=a.Magnitude; return length>0 and a/length or v() end
	if key == "Lerp" then return function(x,y,t) return x+(y-x)*t end end
	if key == "Dot" then return function(x,y) return x.X*y.X+x.Y*y.Y+x.Z*y.Z end end
	if key == "Cross" then return function(x,y) return v(x.Y*y.Z-x.Z*y.Y,x.Z*y.X-x.X*y.Z,x.X*y.Y-x.Y*y.X) end end
end
vector.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__unm=function(a) return v(-a.X,-a.Y,-a.Z) end
vector.__mul=function(a,b)
	if type(a)=="number" then a,b=b,a end
	if type(b)=="table" then return v(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
	return v(a.X*b,a.Y*b,a.Z*b)
end
vector.__div=function(a,b) return v(a.X/b,a.Y/b,a.Z/b) end
local Vector3={new=v,zero=v(),yAxis=v(0,1,0)}
local Vector2={new=function(x,y) return {X=x,Y=y,_kind="Vector2"} end}
local identity={1,0,0,0,1,0,0,0,1}
local cf={}
local function frame(position,rotation) return setmetatable({p=position or v(),r=rotation or table.clone(identity)},cf) end
local function rotate(r,p) return v(r[1]*p.X+r[2]*p.Y+r[3]*p.Z,r[4]*p.X+r[5]*p.Y+r[6]*p.Z,r[7]*p.X+r[8]*p.Y+r[9]*p.Z) end
local function matrixMultiply(a,b)
	local output={}
	for row=0,2 do for column=1,3 do
		output[row*3+column]=a[row*3+1]*b[column]+a[row*3+2]*b[3+column]+a[row*3+3]*b[6+column]
	end end
	return output
end
cf.__index=function(a,key)
	if key=="Position" then return a.p end
	if key=="Rotation" then return frame(v(),table.clone(a.r)) end
	if key=="LookVector" then return v(-a.r[3],-a.r[6],-a.r[9]) end
	if key=="Inverse" then return function(x)
		local r=x.r;local inverse={r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}
		return frame(rotate(inverse,-x.p),inverse)
	end end
	if key=="ToObjectSpace" then return function(x,y) return x:Inverse()*y end end
	if key=="PointToObjectSpace" then return function(x,y) local f=x:Inverse();return f.p+rotate(f.r,y) end end
	if key=="PointToWorldSpace" then return function(x,y) return x.p+rotate(x.r,y) end end
end
cf.__mul=function(a,b)
	if getmetatable(b)==vector then return a.p+rotate(a.r,b) end
	return frame(a.p+rotate(a.r,b.p),matrixMultiply(a.r,b.r))
end
cf.__add=function(a,b) return frame(a.p+b,table.clone(a.r)) end
cf.__sub=function(a,b) return frame(a.p-b,table.clone(a.r)) end
local CFrame={}
CFrame.new=function(x,y,z)
	if getmetatable(x)==vector then return frame(x) end
	return frame(v(x,y,z))
end
CFrame.Angles=function(x,y,z)
	local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
	return frame(v(),matrixMultiply(matrixMultiply({1,0,0,0,cx,-sx,0,sx,cx},{cy,0,sy,0,1,0,-sy,0,cy}),{cz,-sz,0,sz,cz,0,0,0,1}))
end
CFrame.lookAt=function(position,target,up)
	local forward=(target-position).Unit
	local right=forward:Cross(up or v(0,1,0)).Unit
	local back=-forward;local vertical=back:Cross(right)
	return frame(position,{right.X,vertical.X,back.X,right.Y,vertical.Y,back.Y,right.Z,vertical.Z,back.Z})
end
local color={}
color.__index={Lerp=function(a,b,t) return setmetatable({R=a.R+(b.R-a.R)*t,G=a.G+(b.G-a.G)*t,B=a.B+(b.B-a.B)*t},color) end}
local Color3={fromRGB=function(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255},color) end,new=function(r,g,b) return setmetatable({R=r,G=g,B=b},color) end}
local function typeof(value)
	local meta=getmetatable(value)
	if meta==vector then return "Vector3" elseif meta==cf then return "CFrame" elseif meta==color then return "Color3" end
	if type(value)=="table" and value._kind then return value._kind end
	return type(value)
end
local Enum=setmetatable({}, {__index=function(self,key)
	local group=setmetatable({}, {__index=function(_,item) return "Enum."..key.."."..item end})
	rawset(self,key,group);return group
end})
local UDim={new=function(scale,offset) return {_kind="UDim",Scale=scale,Offset=offset} end}
local UDim2={new=function(xs,xo,ys,yo) return {_kind="UDim2",X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end}
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
local objects,methods={},{}
local function belongs(child,parent)
	local ancestor=child.Parent
	while ancestor do if ancestor==parent then return true end;ancestor=ancestor.Parent end
	return false
end
function methods:IsA(kind) return self.ClassName==kind or kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart" or self.ClassName=="SpawnLocation") end
function methods:SetAttribute(key,value) self._attrs[key]=value end
function methods:GetAttribute(key) return self._attrs[key] end
function methods:GetChildren() local list={} for _,item in ipairs(objects) do if item.Parent==self then table.insert(list,item) end end return list end
function methods:GetDescendants() local list={} for _,item in ipairs(objects) do if belongs(item,self) then table.insert(list,item) end end return list end
function methods:FindFirstChild(name) for _,item in ipairs(objects) do if item.Parent==self and item.Name==name then return item end end return nil end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:Destroy() for _,item in ipairs(self:GetDescendants()) do item.Parent=nil end;self.Parent=nil end
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self._pivot or frame() end
function methods:PivotTo(destination)
	local delta=destination*self:GetPivot():Inverse()
	for _,item in ipairs(self:GetDescendants()) do if item:IsA("BasePart") then item.CFrame=delta*item.CFrame end end
	self._pivot=destination
end
function methods:GetScale() return self._scale or 1 end
function methods:ScaleTo(scale)
	local origin=self:GetPivot();local ratio=scale/self:GetScale()
	for _,item in ipairs(self:GetDescendants()) do if item:IsA("BasePart") then
		local localFrame=origin:ToObjectSpace(item.CFrame)
		item.Size=item.Size*ratio;item.CFrame=origin*frame(localFrame.Position*ratio,localFrame.r)
	end end
	self._scale=scale
end
local Instance={new=function(className)
	local object={_attrs={},_props={ClassName=className,Name=className},_kind="Instance",_id="scene"..tostring(#objects+1)}
	setmetatable(object,{__index=function(self,key)
		if key=="Position" and methods.IsA(self,"BasePart") then return self.CFrame and self.CFrame.Position or v() end
		if key=="Transparency" then return self._props[key] or 0 end
		if self._props[key]~=nil then return self._props[key] end
		return methods[key]
	end,__newindex=function(self,key,value)
		if key=="Position" and methods.IsA(self,"BasePart") then local current=self.CFrame or frame();self._props.CFrame=frame(value,current.r)
		else self._props[key]=value end
	end})
	table.insert(objects,object);return object
end}
local workspace=Instance.new("Workspace")
local ReplicatedStorage=Instance.new("ReplicatedStorage")
local game={GetService=function(_,name) assert(name=="ReplicatedStorage");return ReplicatedStorage end}
-- INLINE_CONFIG
-- INLINE_CREATUREVISUAL
-- INLINE_CREATUREMOTION
local modules=Instance.new("Folder");modules.Name="Wildbound";modules.Parent=ReplicatedStorage
local visualModule=Instance.new("ModuleScript");visualModule.Name="CreatureVisual";visualModule.Parent=modules
local require=function(module) assert(module==visualModule,"Unexpected model dependency");return CreatureVisual end
-- INLINE_WORLD

local function json(value)
	if value==nil then return "null" end
	if type(value)=="number" then assert(value==value and math.abs(value)~=math.huge,"Nonfinite scene value");return tostring(value) end
	if type(value)=="boolean" then return value and "true" or "false" end
	if type(value)=="string" then return '"'..value:gsub('[%z\1-\31\\"]',function(char)
		if char=='"' then return '\\"' elseif char=='\\' then return '\\\\' end
		return string.format('\\u%04x',string.byte(char))
	end)..'"' end
	local kind=typeof(value)
	if kind=="Vector3" then return json({kind=kind,value={value.X,value.Y,value.Z}}) end
	if kind=="CFrame" then return json({kind=kind,position={value.p.X,value.p.Y,value.p.Z},rotation=value.r}) end
	if kind=="Color3" then return json({kind=kind,value={value.R,value.G,value.B}}) end
	if kind=="Instance" then return json({kind="Ref",id=value._id}) end
	local parts={}
	if #value>0 then for _,entry in ipairs(value) do table.insert(parts,json(entry)) end;return '['..table.concat(parts,',')..']' end
	local keys={} for key in pairs(value) do table.insert(keys,key) end;table.sort(keys)
	for _,key in ipairs(keys) do table.insert(parts,json(tostring(key))..':'..json(value[key])) end
	return '{'..table.concat(parts,',')..'}'
end
-- Check exporter transform fidelity before extracting the real model.
do
	local pose=CFrame.new(3,5,-2)*CFrame.Angles(0.3,-1.1,0.7)
	assert((pose:PointToObjectSpace(pose:PointToWorldSpace(v(2,4,1)))-v(2,4,1)).Magnitude<0.000001)
	assert((CFrame.Angles(0,0,math.pi/2)*v(1,0,0)-v(0,1,0)).Magnitude<0.000001)
end
local mode="__SCENE_MODE__"
local root
if mode=="world" then
	local world=World.Build(Config);root=world.Root
	for _,spawn in ipairs(world.CreatureSpawns) do
		local weather=Config.Creatures[spawn.species].Weather
		if weather=="Any" or weather=="Dusk" then World.CreateCreature(Config,spawn.species,spawn.id,spawn.position,nil,"Normal") end
	end
else
	root=Instance.new("Model");root.Name="CreatureGallery";root.Parent=workspace
	for index,species in ipairs(Config.CreatureOrder) do
		local model=CreatureVisual.Build(Config,species);model.Parent=root
		model:PivotTo(CFrame.new((index-1)%4*7,0,math.floor((index-1)/4)*9))
		if CreatureMotion then CreatureMotion.Apply(CreatureMotion.Bind(model),0.8,{mood="Idle",speed=0,trust=0},index) end
	end
end
local nodes={}
for _,object in ipairs(objects) do
	if object==root or belongs(object,root) then
		local props={} for key,value in pairs(object._props) do if key~="Parent" and key~="ClassName" then props[key]=value end end
		local parentId=false
		if object~=root then parentId=object.Parent._id end
		table.insert(nodes,{id=object._id,class=object.ClassName,name=object.Name,parent=parentId,properties=props,attributes=object._attrs})
	end
end
print(json({mode=mode,nodes=nodes}))

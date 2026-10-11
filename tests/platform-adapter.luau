-- Platform-only construction/math adapters. Native collision, networking and
-- rendering are outside this harness; CFrame composition includes real rotation.
local vec={}
local function v(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vec) end
vec.__index=function(a,k)
    if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    if k=="Unit" then return a/math.max(1e-12,a.Magnitude) end
    if k=="Lerp" then return function(x,y,t) return x+(y-x)*t end end
    if k=="Dot" then return function(x,y) return x.X*y.X+x.Y*y.Y+x.Z*y.Z end end
    if k=="Cross" then return function(x,y) return v(x.Y*y.Z-x.Z*y.Y,x.Z*y.X-x.X*y.Z,x.X*y.Y-x.Y*y.X) end end
end
vec.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__unm=function(a) return v(-a.X,-a.Y,-a.Z) end
vec.__mul=function(a,b)
    if type(a)=="number" then a,b=b,a end
    if type(b)=="number" then return v(a.X*b,a.Y*b,a.Z*b) end
    return v(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
vec.__div=function(a,b) return v(a.X/b,a.Y/b,a.Z/b) end
local Vector3={new=v,zero=v(),one=v(1,1,1)}
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local identity={1,0,0,0,1,0,0,0,1}
local cf={}
local function transform(matrix,point)
    return v(matrix[1]*point.X+matrix[2]*point.Y+matrix[3]*point.Z,
        matrix[4]*point.X+matrix[5]*point.Y+matrix[6]*point.Z,
        matrix[7]*point.X+matrix[8]*point.Y+matrix[9]*point.Z)
end
local function matrixProduct(a,b)
    local result={}
    for row=0,2 do for col=0,2 do
        result[row*3+col+1]=a[row*3+1]*b[col+1]+a[row*3+2]*b[col+4]+a[row*3+3]*b[col+7]
    end end
    return result
end
local function makeFrame(position,matrix) return setmetatable({p=position or v(),m=matrix or identity},cf) end
local function frame(x,y,z) return makeFrame(type(x)=="table" and x or v(x,y,z)) end
local function inverse(a)
    local m=a.m
    local transpose={m[1],m[4],m[7],m[2],m[5],m[8],m[3],m[6],m[9]}
    return makeFrame(transform(transpose,-a.p),transpose)
end
cf.__index=function(a,k)
    if k=="Position" then return a.p end
    if k=="Rotation" then return makeFrame(v(),a.m) end
    if k=="LookVector" then return v(-a.m[3],-a.m[6],-a.m[9]) end
    if k=="RightVector" then return v(a.m[1],a.m[4],a.m[7]) end
    if k=="UpVector" then return v(a.m[2],a.m[5],a.m[8]) end
    if k=="Inverse" then return inverse end
    if k=="ToObjectSpace" then return function(x,y) return inverse(x)*y end end
    if k=="ToWorldSpace" then return function(x,y) return x*y end end
    if k=="PointToObjectSpace" then return function(x,y) return inverse(x)*y end end
    if k=="PointToWorldSpace" then return function(x,y) return x*y end end
end
cf.__mul=function(a,b)
    if getmetatable(b)==vec then return a.p+transform(a.m,b) end
    return makeFrame(a.p+transform(a.m,b.p),matrixProduct(a.m,b.m))
end
cf.__add=function(a,b) return makeFrame(a.p+b,a.m) end
cf.__sub=function(a,b) return makeFrame(a.p-b,a.m) end
local CFrame={new=frame}
function CFrame.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return makeFrame(v(),matrixProduct(matrixProduct({1,0,0,0,cx,-sx,0,sx,cx},{cy,0,sy,0,1,0,-sy,0,cy}),{cz,-sz,0,sz,cz,0,0,0,1}))
end
function CFrame.lookAt(a,b,up)
    local back=(a-b).Unit
    local right=(up or v(0,1,0)):Cross(back).Unit
    local vertical=back:Cross(right)
    return makeFrame(a,{right.X,vertical.X,back.X,right.Y,vertical.Y,back.Y,right.Z,vertical.Z,back.Z})
end
local col={}
col.__index={Lerp=function(a,b,t) return setmetatable({R=a.R+(b.R-a.R)*t,G=a.G+(b.G-a.G)*t,B=a.B+(b.B-a.B)*t},col) end}
local Color3={fromRGB=function(r,g,b) return setmetatable({R=r/255,G=g/255,B=b/255},col) end,new=function(r,g,b) return setmetatable({R=r,G=g,B=b},col) end}
local function typeof(a)
    local meta=getmetatable(a)
    return meta==col and "Color3" or meta==vec and "Vector3" or meta==cf and "CFrame" or type(a)
end
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
function methods:GetChildren() local t={} for _,o in objects do if o.Parent==self then table.insert(t,o) end end return t end
function methods:FindFirstChild(name) for _,o in objects do if o.Parent==self and o.Name==name then return o end end return nil end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:Destroy() for _,o in self:GetDescendants() do o.Parent=nil end self.Parent=nil end
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self._pivot or frame() end
function methods:PivotTo(destination)
    local delta=destination*self:GetPivot():Inverse()
    for _,p in self:GetDescendants() do if p:IsA("BasePart") then p.CFrame=delta*p.CFrame end end
    self._pivot=destination
end
function methods:GetScale() return self._scale or 1 end
function methods:ScaleTo(scale)
    local origin=self:GetPivot().Position
    local ratio=scale/self:GetScale()
    for _,p in self:GetDescendants() do if p:IsA("BasePart") then
        p.Size=p.Size*ratio;p.CFrame=frame(origin+(p.Position-origin)*ratio)*p.CFrame.Rotation
    end end
    self._scale=scale
end
local Instance={new=function(className)
    local o=setmetatable({_attrs={},ClassName=className,Name=className,Transparency=0}, {__index=function(a,k)
        if k=="Position" then return a.CFrame and a.CFrame.Position or v() end return methods[k]
    end})
    table.insert(objects,o) return o
end}
local workspace=Instance.new("Workspace")
local ReplicatedStorage=Instance.new("ReplicatedStorage")
local game={GetService=function(_,name) assert(name=="ReplicatedStorage") return ReplicatedStorage end}

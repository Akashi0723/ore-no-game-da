-- Wildbound's handcrafted procedural forest. Owns only WildboundWorld.
-- Playable island surfaces finish at y=18; an opaque ocean masks the user's
-- baseplate without editing it. Every returned gameplay position uses this floor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureVisual = require(ReplicatedStorage:WaitForChild("Wildbound"):WaitForChild("CreatureVisual"))

local World = {}
local activeWorld = nil
local windFoliageCount = 0
local pathSurfaceOrder = 0

local palette = {
	Grass = Color3.fromRGB(107, 169, 110),
	Meadow = Color3.fromRGB(143, 189, 123),
	Path = Color3.fromRGB(231, 210, 169),
	PathEdge = Color3.fromRGB(189, 164, 124),
	Forest = Color3.fromRGB(43, 101, 80),
	Leaf = Color3.fromRGB(90, 154, 93),
	LightLeaf = Color3.fromRGB(156, 199, 119),
	Wood = Color3.fromRGB(160, 112, 77),
	Bark = Color3.fromRGB(107, 76, 58),
	Cream = Color3.fromRGB(255, 247, 224),
	Ink = Color3.fromRGB(32, 60, 58),
	Gold = Color3.fromRGB(225, 179, 96),
	Berry = Color3.fromRGB(201, 105, 131),
	Stone = Color3.fromRGB(118, 139, 145),
	Water = Color3.fromRGB(95, 181, 184),
	Clay = Color3.fromRGB(219, 159, 116),
	Lavender = Color3.fromRGB(177, 157, 198),
	Pine = Color3.fromRGB(47, 119, 103),
	Ocean = Color3.fromRGB(81, 157, 173),
	Soil = Color3.fromRGB(111, 108, 91),
	Moss = Color3.fromRGB(88, 140, 100),
}

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(parent, name, size, position, color, material, collide, shape, rotation)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position) * (rotation or CFrame.new())
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.CastShadow = size.Y > 0.3
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function sphere(parent, name, size, position, color)
	return part(parent, name, size, position, color, Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
end

local function cylinder(parent, name, diameter, height, position, color, collide)
	return part(parent, name, Vector3.new(height, diameter, diameter), position, color, Enum.Material.SmoothPlastic, collide, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
end

local function windFoliage(leaf, strength)
	if windFoliageCount >= 12 then return leaf end
	windFoliageCount += 1
	leaf:SetAttribute("WindFoliage", true)
	leaf:SetAttribute("WindStrength", strength or 0.4)
	leaf:SetAttribute("WindPhase", windFoliageCount * 1.71)
	return leaf
end

local function lantern(parent, position)
	local body = part(parent, "LanternGlass", Vector3.new(0.78, 1.05, 0.78), position, palette.Gold, nil, false)
	body.Material = Enum.Material.Neon
	body.Color = Color3.fromRGB(255, 219, 155)
	part(parent, "LanternRoof", Vector3.new(1.04, 0.18, 1.04), position + Vector3.new(0, 0.61, 0), palette.Ink, Enum.Material.Metal, false)
	part(parent, "LanternFoot", Vector3.new(0.9, 0.16, 0.9), position - Vector3.new(0, 0.61, 0), palette.Ink, Enum.Material.Metal, false)
	local light = Instance.new("PointLight")
	light.Name = "WarmGardenLight"
	light.Color = Color3.fromRGB(255, 216, 165)
	light.Brightness = 0.6
	light.Range = 15
	light.Shadows = false
	light.Parent = body
	return body
end

local function lampPost(parent, x, z)
	local model = Instance.new("Model")
	model.Name = "TrailLamp"
	model.Parent = parent
	cylinder(model, "StoneFoot", 1.2, 0.28, Vector3.new(x, 0.14, z), palette.Stone, false)
	part(model, "Post", Vector3.new(0.35, 5.9, 0.35), Vector3.new(x, 3.0, z), palette.Ink, Enum.Material.Metal, false)
	part(model, "Hook", Vector3.new(1.5, 0.18, 0.18), Vector3.new(x + 0.56, 5.91, z), palette.Ink, Enum.Material.Metal, false)
	lantern(model, Vector3.new(x + 1.06, 5.24, z))
	return model
end

local function prompt(p, name, action, target, text, object, hold)
	p.CanQuery = true
	p:SetAttribute("Action", action)
	p:SetAttribute("Target", target)
	local interaction = Instance.new("ProximityPrompt")
	interaction.Name = name or "Interaction"
	interaction.ActionText = text
	interaction.ObjectText = object
	interaction.HoldDuration = hold or 0
	interaction.MaxActivationDistance = 12
	interaction.RequiresLineOfSight = false
	interaction.KeyboardKeyCode = action == "Creature" and Enum.KeyCode.E or Enum.KeyCode.F
	interaction.GamepadKeyCode = action == "Creature" and Enum.KeyCode.ButtonX or Enum.KeyCode.DPadUp
	interaction.Parent = p
	return interaction
end

local function sign(parent, position, title, subtitle, width, facing)
	width = width or 10
	local model = Instance.new("Model")
	model.Name = "Sign"
	model.Parent = parent
	local rotation = CFrame.Angles(0, facing or math.pi, 0)
	local board = part(model, "Board", Vector3.new(width, 3.2, 0.35), position + Vector3.new(0, 3.8, 0), palette.Cream, Enum.Material.Wood, false, nil, rotation)
	part(model, "Post", Vector3.new(0.42, 4.5, 0.42), position + Vector3.new(0, 1.9, 0), palette.Wood, Enum.Material.Wood, false)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(width * 55, 176)
	gui.LightInfluence = 0
	gui.Parent = board
	local heading = Instance.new("TextLabel")
	heading.Name = "Title"
	heading.Size = UDim2.new(1, -24, 0.5, 0)
	heading.Position = UDim2.new(0, 12, 0, 12)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.FredokaOne
	heading.Text = title
	heading.TextSize = 34
	heading.TextColor3 = palette.Ink
	heading.TextWrapped = true
	heading.Parent = gui
	local caption = Instance.new("TextLabel")
	caption.Name = "Subtitle"
	caption.Size = UDim2.new(1, -28, 0.36, 0)
	caption.Position = UDim2.new(0, 14, 0.6, 0)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamMedium
	caption.Text = subtitle or ""
	caption.TextSize = 19
	caption.TextColor3 = palette.Forest
	caption.TextWrapped = true
	caption.Parent = gui
	return heading, board
end

local function tree(parent, x, z, scale, shade, silhouette, distant)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = silhouette == "Willow" and "StillwaterWillow" or silhouette == "Pine" and "ShelterPine" or "GardenOak"
	model.Parent = parent
	local trunk = cylinder(model, "Trunk", 1.65 * scale, 10 * scale, Vector3.new(x, 5 * scale, z), palette.Bark, true)
	trunk.Material = Enum.Material.Wood
	if not distant then
		for i = 1, 3 do
			local angle = i * math.pi * 2 / 3
			part(model,"RootFlare",Vector3.new(0.6,0.6,3.0)*scale,Vector3.new(x+math.sin(angle)*0.8*scale,0.25*scale,z+math.cos(angle)*0.8*scale),palette.Bark,Enum.Material.Wood,false,nil,CFrame.Angles(0,angle,0.18))
		end
	end
	part(model, "Branch", Vector3.new(0.8, 5.2, 0.8) * scale, Vector3.new(x + 1.0 * scale, 8 * scale, z), palette.Bark, Enum.Material.Wood, false, nil, CFrame.Angles(0, 0, -0.53))
	if silhouette == "Pine" then
		for i = 1, 3 do
			local crown = part(model, "PineBough", Vector3.new(9.5 - i * 1.8, 4.8, 9.5 - i * 1.8) * scale, Vector3.new(x, (7.7 + i * 2.1) * scale, z), i == 3 and palette.Leaf or palette.Pine, nil, false, Enum.PartType.Ball)
			crown.CFrame *= CFrame.Angles(0, i * 0.8, 0)
		end
	elseif silhouette == "Willow" then
		sphere(model, "WillowCanopy", Vector3.new(13, 6, 11) * scale, Vector3.new(x, 11.5 * scale, z), shade or palette.Leaf)
		for i = 1, 6 do
			local angle = i * math.pi / 3
			local position = Vector3.new(x + math.cos(angle) * 4.6 * scale, 8.7 * scale, z + math.sin(angle) * 4.0 * scale)
			local frond = part(model, "WillowFrond", Vector3.new(2.4, 7.0 + (i % 2), 2.2) * scale, position, i % 2 == 0 and palette.LightLeaf or palette.Leaf, nil, false, Enum.PartType.Ball, CFrame.Angles(math.sin(angle) * 0.12, angle, math.cos(angle) * 0.12))
			if i == 1 then windFoliage(frond, 0.55) end
		end
	else
		sphere(model, "Crown", Vector3.new(10, 7.4, 10) * scale, Vector3.new(x, 12 * scale, z), shade or palette.Leaf)
		sphere(model, "CrownLight", Vector3.new(7, 6, 7) * scale, Vector3.new(x + 3.1 * scale, 12.6 * scale, z - 0.5 * scale), palette.LightLeaf)
		sphere(model, "CrownLow", Vector3.new(7.5, 6.5, 7.5) * scale, Vector3.new(x - 2.8 * scale, 10.9 * scale, z + scale), shade or palette.Leaf)
	end
	return model
end

local function bush(parent, position, size)
	size = size or 1
	sphere(parent, "LeafBush", Vector3.new(4.6, 2.4, 3.9) * size, position + Vector3.new(0, 1.1 * size, 0), palette.Leaf)
	windFoliage(sphere(parent, "BushLight", Vector3.new(2.8, 2.1, 2.6) * size, position + Vector3.new(1.35 * size, 1.2 * size, -0.2 * size), palette.LightLeaf), 0.16)
end

local function flower(parent, position, color, scale)
	scale = scale or 1
	part(parent, "FlowerStem", Vector3.new(0.1, 1.0, 0.1) * scale, position + Vector3.new(0, 0.5 * scale, 0), palette.Forest, nil, false)
	for i = 1, 4 do
		local angle = i * math.pi / 2
		sphere(parent, "Petal", Vector3.new(0.65, 0.25, 0.65) * scale, position + Vector3.new(math.cos(angle) * 0.3 * scale, 1.0 * scale, math.sin(angle) * 0.3 * scale), color)
	end
	sphere(parent, "FlowerCenter", Vector3.new(0.32, 0.24, 0.32) * scale, position + Vector3.new(0, 1.12 * scale, 0), palette.Gold)
end

local function fence(parent, a, b)
	local direction = b - a
	local length = direction.Magnitude
	local midpoint = (a + b) / 2
	local facing = CFrame.lookAt(midpoint, b)
	for _, height in ipairs({ 1.3, 2.55 }) do
		part(parent, "FenceRail", Vector3.new(0.22, 0.24, length), midpoint + Vector3.new(0, height, 0), palette.Wood, Enum.Material.Wood, false, nil, facing.Rotation)
	end
	local segments = math.max(1, math.ceil(length / 9))
	for i = 0, segments do
		part(parent, "FencePost", Vector3.new(0.5, 3.1, 0.5), a:Lerp(b, i / segments) + Vector3.new(0, 1.55, 0), palette.Wood, Enum.Material.Wood, false)
	end
end

-- Surface tops are deliberately layered above the meadow. Distinct small
-- offsets also separate overlapping trail segments, joins and crossing branches.
local function nextPathSurface(height)
	pathSurfaceOrder += 1
	return (height or 0) + pathSurfaceOrder * 0.0017
end

local function path(parent, name, x, z, width, depth, height)
	local layer = nextPathSurface(height)
	part(parent, name .. "Border", Vector3.new(width + 0.8, 0.22, depth + 0.8), Vector3.new(x, layer - 0.075, z), palette.PathEdge, Enum.Material.Sand, true)
	return part(parent, name, Vector3.new(width, 0.2, depth), Vector3.new(x, layer - 0.025, z), palette.Path, Enum.Material.Sand, true)
end

local function windingPath(parent, name, points, width)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local layer = nextPathSurface(0)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local midpoint = (a + b) / 2
		local orientation = CFrame.lookAt(midpoint, b).Rotation
		local segmentLayer = layer + i * 0.00137
		part(model, "TrailEdge", Vector3.new(width + 0.8, 0.22, (b - a).Magnitude + 0.7), midpoint + Vector3.new(0, segmentLayer - 0.075, 0), palette.PathEdge, Enum.Material.Sand, true, nil, orientation)
		part(model, "Trail", Vector3.new(width, 0.2, (b - a).Magnitude + 0.4), midpoint + Vector3.new(0, segmentLayer - 0.025, 0), palette.Path, Enum.Material.Sand, true, nil, orientation)
		cylinder(model, "TrailJoin", width, 0.2, a + Vector3.new(0, segmentLayer + 0.005, 0), palette.Path, true)
	end
	return model
end

local function steppingTrail(parent, points, diameter)
	for i, position in ipairs(points) do
		local stone = cylinder(parent, "HabitatSteppingStone", diameter or 2.7, 0.12, position + Vector3.new(0, -0.04, 0), i % 2 == 0 and palette.Cream or palette.Stone, true)
		stone.CFrame *= CFrame.Angles((i % 3 - 1) * 0.015, i * 0.82, 0)
	end
end

local function rock(parent, position, size)
	return sphere(parent, "RiverStone", size, position + Vector3.new(0, size.Y * 0.4, 0), palette.Stone)
end

local function oval(parent, name, width, depth, height, position, color, collide, material)
	return part(parent, name, Vector3.new(height, width, depth), position, color, material or Enum.Material.SmoothPlastic, collide, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
end

local function island(parent, name, x, z, width, depth, color, floorOffset)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	-- The grass cap is level for traversal; the layered skirt gives the island
	-- a sculpted silhouette from the boardwalk and every normal camera angle.
	oval(model, "IslandFoundation", width - 2, depth - 2, 11, Vector3.new(x, -6.5, z), palette.Stone, true, Enum.Material.Slate)
	oval(model, "ExposedSoil", width + 0.2, depth + 0.2, 3.1, Vector3.new(x, -2.5, z), palette.Soil, true, Enum.Material.Ground)
	oval(model, "MossBank", width + 1.8, depth + 1.8, 1.0, Vector3.new(x, -1.15, z), palette.Moss, false)
	oval(model, "WalkingMeadow", width, depth, 1.4, Vector3.new(x, -0.7 + (floorOffset or 0), z), color, true, Enum.Material.Grass)
	return model
end

local function ruggedBank(parent, center, width, depth, count, phase)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + (phase or 0)
		local position = center + Vector3.new(math.cos(angle) * width / 2, -3.2, math.sin(angle) * depth / 2)
		local size = Vector3.new(7 + (i % 3) * 1.6, 5.5 + (i % 4), 6.2 + (i % 2) * 2)
		local bank = part(parent, "CoastalStone", size, position, i % 2 == 0 and palette.Stone or palette.Soil, Enum.Material.Slate, false, Enum.PartType.Ball, CFrame.Angles(0.12, angle, -0.1))
		bank.CanQuery = false
	end
end

local function meadowPatch(parent, position, width, depth, color)
	return oval(parent, "MeadowPatch", width, depth, 0.06, position + Vector3.new(0, 0.02, 0), color or palette.Meadow, false)
end

local function mushroom(parent, position, scale, color)
	local model = Instance.new("Model")
	model.Name = "ForestMushroom"
	model.Parent = parent
	cylinder(model, "MushroomStem", 0.65 * scale, 1.6 * scale, position + Vector3.new(0, 0.8 * scale, 0), palette.Cream, false)
	local cap = sphere(model, "MushroomCap", Vector3.new(2.6, 0.92, 2.6) * scale, position + Vector3.new(0, 1.7 * scale, 0), color or palette.Clay)
	cap.CastShadow = true
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		sphere(model, "CapSpot", Vector3.new(0.42, 0.1, 0.42) * scale, position + Vector3.new(math.cos(angle) * 0.64 * scale, 2.13 * scale, math.sin(angle) * 0.64 * scale), palette.Cream)
	end
	return model
end

local function fern(parent, position, scale)
	scale = scale or 1
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		part(parent, "FernFrond", Vector3.new(0.72, 2.3, 0.18) * scale, position + Vector3.new(math.cos(angle) * 0.42 * scale, 0.85 * scale, math.sin(angle) * 0.42 * scale), i == 1 and palette.LightLeaf or palette.Forest, nil, false, Enum.PartType.Ball, CFrame.Angles(0.45, angle, 0.48))
	end
end

local function bridge(parent, name, a, b, width)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local length = (b - a).Magnitude
	local facing = CFrame.lookAt((a + b) / 2, b).Rotation
	-- Continuous collision underneath all boards makes touch traversal forgiving.
	part(model, "WalkDeck", Vector3.new(width, 0.3, length + 1), (a + b) / 2 + Vector3.new(0, -0.12, 0), palette.Wood, Enum.Material.WoodPlanks, true, nil, facing)
	local boards = math.ceil(length / 2.2)
	for i = 0, boards do
		part(model, "Board", Vector3.new(width + 0.2, 0.1, 1.92), a:Lerp(b, i / boards) + Vector3.new(0, 0.07, 0), i % 2 == 0 and palette.Wood or palette.PathEdge, Enum.Material.Wood, false, nil, facing)
	end
	for _, side in ipairs({ -1, 1 }) do
		local sideOffset = Vector3.new(-(b.Z - a.Z), 0, b.X - a.X) * (side * (width / 2 + 0.15) / length)
		for i = 0, 4 do
			local position = a:Lerp(b, i / 4) + sideOffset
			part(model, "BridgePost", Vector3.new(0.48, 2.7, 0.48), position + Vector3.new(0, 1.3, 0), palette.Bark, Enum.Material.Wood, false)
			cylinder(model, "PostCap", 0.64, 0.13, position + Vector3.new(0, 2.7, 0), palette.Cream, false)
		end
		part(model, "BridgeHandrail", Vector3.new(0.28, 0.24, length + 1), (a + b) / 2 + sideOffset + Vector3.new(0, 2.3, 0), palette.Wood, Enum.Material.Wood, false, nil, facing)
	end
	return model
end

local function bench(parent, position, facing)
	local model = Instance.new("Model")
	model.Name = "ForestBench"
	model.Parent = parent
	local rotation = CFrame.Angles(0, facing or 0, 0)
	local function localPart(name, size, offset, color, collide)
		return part(model, name, size, position + Vector3.new(offset.X * math.cos(facing or 0) + offset.Z * math.sin(facing or 0), offset.Y, -offset.X * math.sin(facing or 0) + offset.Z * math.cos(facing or 0)), color, Enum.Material.Wood, collide, nil, rotation)
	end
	localPart("BenchSeat", Vector3.new(6, 0.35, 1.9), Vector3.new(0, 1.7, 0), palette.Wood, true)
	localPart("BenchBack", Vector3.new(6, 1.5, 0.25), Vector3.new(0, 2.6, 0.85), palette.Wood, false)
	for _, x in ipairs({ -2.1, 2.1 }) do localPart("BenchLeg", Vector3.new(0.36, 1.6, 1.6), Vector3.new(x, 0.8, 0), palette.Bark, false) end
	return model
end

local function hillside(parent, position, width, height, depth, shade)
	local stone = sphere(parent, "ForestHillside", Vector3.new(width, height, depth), position + Vector3.new(0, height * 0.27 - 0.7, 0), palette.Stone)
	stone.Material = Enum.Material.Slate
	local cap = sphere(parent, "HillsideMoss", Vector3.new(width * 0.97, height * 0.68, depth * 0.98), position + Vector3.new(0, height * 0.48, 0), shade or palette.Moss)
	stone.CanQuery, cap.CanQuery = false, false
	return stone
end

local function makeClue(world, id, species, position, label)
	local holder = Instance.new("Model")
	holder.Name = id
	holder.Parent = world.Interactions
	local target = cylinder(holder, "Clue", 2.6, 0.12, position + Vector3.new(0, 0.07, 0), palette.Gold, false)
	target.Material = Enum.Material.Neon
	target:SetAttribute("ClueId", id)
	target:SetAttribute("Species", species)
	prompt(target, "Interaction", "Photo", id, "Photograph clue", label, 0.4)
	world.Clues[id] = { Part = target, Species = species, Label = label }
	if species == "Mossbun" or species == "Mistfox" or species == "Moonhare" then
		for i = 1, 4 do
			sphere(holder, "Pawprint", Vector3.new(0.45, 0.08, species == "Moonhare" and 0.94 or 0.65), position + Vector3.new((i % 2 == 0 and 0.36 or -0.36), 0.16, (i - 2.5) * 0.7), species == "Mistfox" and palette.Cream or species == "Moonhare" and palette.Lavender or palette.Ink)
		end
	elseif species == "Lanternwing" then
		for i = 1, 3 do
			local glow = sphere(holder, "GoldenDust", Vector3.new(0.22, 0.22, 0.22), position + Vector3.new((i - 2) * 0.6, 0.5 + i * 0.25, 0), palette.Gold)
			glow.Material = Enum.Material.Neon
		end
	elseif species == "Pebblehog" then
		for i = 1, 3 do
			rock(holder, position + Vector3.new((i - 2) * 0.5, 0.15, 0), Vector3.new(0.55, 0.4 + i * 0.15, 0.6))
		end
	elseif species == "Bloomstag" then
		for i = 1, 3 do
			flower(holder, position + Vector3.new((i - 2) * 0.65, 0, (i % 2) * 0.6), palette.Clay, 0.46)
		end
	elseif species == "Reedling" then
		for i = 1, 3 do
			part(holder, "BentReed", Vector3.new(0.12, 1.3, 0.12), position + Vector3.new((i - 2) * 0.45, 0.7, 0), palette.Forest, nil, false, nil, CFrame.Angles(0.32, 0, (i - 2) * 0.2))
		end
	else
		cylinder(holder, "Ripple", 1.6, 0.04, position + Vector3.new(0, 0.16, 0), palette.Cream, false)
		cylinder(holder, "RippleCenter", 1.15, 0.05, position + Vector3.new(0, 0.19, 0), palette.Water, false)
	end
	return target
end

local function waterJob(world, id, position, color)
	local bed = Instance.new("Model")
	bed.Name = "FlowerBed"
	bed.Parent = world.Interactions
	part(bed, "RaisedBed", Vector3.new(6, 0.8, 3.7), position + Vector3.new(0, 0.4, 0), palette.Wood, Enum.Material.Wood, false)
	part(bed, "Soil", Vector3.new(5.5, 0.1, 3.2), position + Vector3.new(0, 0.83, 0), palette.Bark, Enum.Material.Ground, false)
	for i = 1, 3 do
		flower(bed, position + Vector3.new((i - 2) * 1.6, 0.84, 0), color, 0.85)
	end
	local target = part(bed, "WateringHandle", Vector3.new(0.6, 0.6, 0.6), position + Vector3.new(0, 1.7, 1.7), palette.Gold, nil, false)
	target.Transparency = 1
	target.CanQuery = false
	target:SetAttribute("JobId", id)
	prompt(target, "Interaction", "Job", id, "Water flowers  +12 coins", "Garden job", 1.0)
	world.Jobs[id] = { Part = target, Kind = "Water", Label = "Water the flowers", Cooldown = 30, Reward = 12 }
end

local function leafJob(world, id, position)
	local pile = Instance.new("Model")
	pile.Name = "FallenLeaves"
	pile.Parent = world.Interactions
	local colors = { palette.Gold, palette.Berry, palette.LightLeaf, palette.Leaf }
	for i = 1, 5 do
		local a = i * 2.4
		part(pile, "FallenLeaf", Vector3.new(1.3, 0.16, 0.8), position + Vector3.new(math.cos(a), 0.12 + i * 0.02, math.sin(a)), colors[(i % #colors) + 1], nil, false, Enum.PartType.Ball, CFrame.Angles(0, a, 0))
	end
	local target = part(pile, "GatheringHandle", Vector3.new(0.4, 0.4, 0.4), position + Vector3.new(0, 0.65, 0), palette.Gold, nil, false)
	target.Transparency = 1
	target.CanQuery = false
	target:SetAttribute("JobId", id)
	prompt(target, "Interaction", "Job", id, "Gather leaves  +15 coins", "Garden job", 0.8)
	world.Jobs[id] = { Part = target, Kind = "Gather", Label = "Gather fallen leaves", Cooldown = 40, Reward = 15 }
end

function World.Build(config)
	local oldRoot = workspace:FindFirstChild("WildboundWorld")
	if oldRoot then oldRoot:Destroy() end
	local root = Instance.new("Model")
	root.Name = "WildboundWorld"
	root.Parent = workspace
	local geometry = folder(root, "Garden")
	windFoliageCount = 0
	pathSurfaceOrder = 0
	local world = {
		Root = root,
		Creatures = folder(root, "Creatures"),
		Interactions = folder(root, "Interactions"),
		Sanctuaries = {}, Jobs = {}, Clues = {},
		FloorY = 18,
		PondSpawn = CFrame.lookAt(Vector3.new(0, 21.2, -88), Vector3.new(0, 21.2, -110)),
		Spawn = CFrame.lookAt(Vector3.new(0, 3.2, 31), Vector3.new(0, 3.2, 8)),
		TutorialPosition = Vector3.new(0, 0, 8),
		CreatureSpawns = {
			{ id = "garden_mossbun_1", species = "Mossbun", position = Vector3.new(-17, 0, -4) },
			{ id = "garden_mossbun_2", species = "Mossbun", position = Vector3.new(29, 0, -32) },
			{ id = "garden_lanternwing", species = "Lanternwing", position = Vector3.new(-34, 0, -31) },
			{ id = "garden_pebblehog", species = "Pebblehog", position = Vector3.new(34, 0, -4) },
			{ id = "pond_dewfin", species = "Dewfin", position = Vector3.new(-16, 0, -112) },
			{ id = "pond_mistfox", species = "Mistfox", position = Vector3.new(28, 0, -130) },
			{ id = "pond_reedling", species = "Reedling", position = Vector3.new(-41, 0, -97) },
			{ id = "pond_moonhare", species = "Moonhare", position = Vector3.new(18, 0, -116) },
			{ id = "pond_bloomstag", species = "Bloomstag", position = Vector3.new(38, 0, -97) },
		},
	}
	activeWorld = world
	-- Rounded landforms replace the flat rectangular template. A broad opaque sea
	-- sits well below the grass, so existing Studio baseplates never enter the view.
	local coastline = folder(root, "IslandCoastline")
	local ocean = part(coastline, "SurroundingOcean", Vector3.new(1800, 1, 1800), Vector3.new(0, -14.5, 0), palette.Ocean, Enum.Material.SmoothPlastic, false)
	ocean.CastShadow = false
	ocean:SetAttribute("ScenicOcean", true)
	island(geometry, "BramblegardenIsland", 0, -8, 146, 142, palette.Grass)
	island(geometry, "StillwaterIsland", 0, -113, 146, 92, palette.Meadow, 0.012)
	island(geometry, "SanctuaryVillageIsland", 117, 9, 110, 176, palette.Meadow, 0.018)
	island(geometry, "EastMeadowNeck", 63, 27, 43, 35, palette.Grass, 0.006)
	ruggedBank(coastline, Vector3.new(0, 0, -8), 147, 143, 28, 0.12)
	ruggedBank(coastline, Vector3.new(0, 0, -113), 147, 93, 22, 0.18)
	ruggedBank(coastline, Vector3.new(117, 0, 9), 111, 177, 24, 0.2)
	-- Forest margins rise away from encounter clearings. Decorative slopes are
	-- intentionally not colliders; creatures retain honest flat homes and ranges.
	for _, data in ipairs({ {-52,33,20,9,19}, {-53,-46,22,12,21}, {48,-49,22,10,18}, {54,37,20,8,17}, {-55,-125,19,12,22}, {43,-143,30,15,19}, {164,-63,17,11,21}, {167,75,18,10,22} }) do
		hillside(geometry, Vector3.new(data[1],0,data[2]), data[3],data[4],data[5],palette.Moss)
	end
	meadowPatch(geometry, Vector3.new(-19,0,-6), 20, 17, palette.Meadow)
	meadowPatch(geometry, Vector3.new(-35,0,-32), 22, 20, palette.LightLeaf)
	meadowPatch(geometry, Vector3.new(34,0,-5), 22, 21, palette.Moss)
	meadowPatch(geometry, Vector3.new(29,0,-32), 19, 17, palette.Meadow)
	windingPath(geometry, "GardenWalk", { Vector3.new(0, 0, 40), Vector3.new(0, 0, 22), Vector3.new(1.6, 0, 13), Vector3.new(0, 0, -5), Vector3.new(-2, 0, -25), Vector3.new(0, 0, -45), Vector3.new(0, 0, -65) }, 8.5)
	windingPath(geometry, "MarketPromenade", {Vector3.new(-48,0,32), Vector3.new(-35,0,31), Vector3.new(-21,0,34), Vector3.new(-8,0,25), Vector3.new(6,0,22), Vector3.new(24,0,24), Vector3.new(47,0,30)}, 8.5)
	windingPath(geometry, "WestResearchTrail", { Vector3.new(0, 0, -27), Vector3.new(-16, 0, -24), Vector3.new(-32, 0, -27), Vector3.new(-42, 0, -38) }, 5)
	windingPath(geometry, "EastResearchTrail", { Vector3.new(0, 0, -27), Vector3.new(17, 0, -26), Vector3.new(31, 0, -31), Vector3.new(43, 0, -17) }, 5)
	bridge(geometry, "SanctuaryWelcomeBridge", Vector3.new(49,0,31), Vector3.new(82,0,31), 9)
	path(geometry, "SanctuaryLane", 117, 9, 9, 152)
	windingPath(geometry, "PondBoardwalkTrail", {Vector3.new(0,0,-66),Vector3.new(0,0,-86),Vector3.new(4,0,-103),Vector3.new(0,0,-119),Vector3.new(0,0,-144)}, 7)
	for _, z in ipairs({ -52, -14, 24, 62 }) do
		windingPath(geometry, "HabitatLane", {Vector3.new(72,0,z),Vector3.new(94,0,z+11),Vector3.new(117,0,z+13),Vector3.new(139,0,z+11),Vector3.new(161,0,z)}, 5)
	end

	-- The first landing is quiet, with a visible leaf nook directly ahead.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "WildboundSpawn"
	spawnPad.Size = Vector3.new(5, 0.2, 5)
	spawnPad.CFrame = CFrame.new(0, -0.1, 31)
	spawnPad.Transparency = 1
	spawnPad.Anchored = true
	spawnPad.CanCollide = false
	spawnPad.CanTouch = false
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Parent = root
	-- A warm round arrival plaza points straight into the first creature nook.
	oval(geometry,"ArrivalCourtBorder",24,21,0.12,Vector3.new(0,0,32),palette.PathEdge,true)
	oval(geometry,"ArrivalCourt",22.8,19.8,0.1,Vector3.new(0,0.105,32),palette.Path,true)
	local welcome = sign(geometry, Vector3.new(14, 0, 38), "WILDBOUND", "A little wild. A world of friends.", 12)
	welcome.TextColor3 = palette.Ink
	bush(geometry, Vector3.new(-3.8, 0, 7), 0.9)
	bush(geometry, Vector3.new(3.8, 0, 7), 0.8)
	cylinder(geometry, "BerryBowl", 1.5, 0.25, Vector3.new(0, 0.15, 11.1), palette.Cream, false)
	for i = 1, 3 do
		sphere(geometry, "StarterBerry", Vector3.new(0.32, 0.32, 0.32), Vector3.new((i - 2) * 0.32, 0.38, 11.1), palette.Berry)
	end
	steppingTrail(geometry, { Vector3.new(-7, 0, 0), Vector3.new(-10, 0, -1), Vector3.new(-13, 0, -2), Vector3.new(-16, 0, -3) }, 2.2)
	steppingTrail(geometry, { Vector3.new(7, 0, -5), Vector3.new(13, 0, -4), Vector3.new(19, 0, -4), Vector3.new(24, 0, -4), Vector3.new(29, 0, -4) }, 2.4)
	local nook = folder(geometry, "FirstFriendNook")
	part(nook, "LeafNookBackdrop", Vector3.new(8.8, 0.12, 6.0), Vector3.new(0, -0.01, 7.5), palette.Meadow, Enum.Material.Grass, false, Enum.PartType.Ball)
	for _, x in ipairs({ -5.2, 5.2 }) do
		part(nook, "NookPost", Vector3.new(0.4, 3.4, 0.4), Vector3.new(x, 1.7, 6.4), palette.Wood, Enum.Material.Wood, false)
	end
	part(nook, "NookRail", Vector3.new(10.6, 0.18, 0.18), Vector3.new(0, 3.25, 6.4), palette.Wood, Enum.Material.Wood, false)
	for i = 1, 5 do
		local leaf = part(nook, "NookHangingLeaf", Vector3.new(0.44, 0.82, 0.16), Vector3.new((i - 3) * 1.62, 2.75, 6.4), i % 2 == 0 and palette.Gold or palette.LightLeaf, nil, false, Enum.PartType.Ball, CFrame.Angles(0, 0, (i - 3) * 0.17))
		leaf:SetAttribute("TutorialLeaf", true)
	end

	-- A small market stall sits on the loop back from the first encounter.
	local shop = Instance.new("Model")
	shop.Name = "SnackShop"
	shop.Parent = root
	part(shop, "Platform", Vector3.new(17, 0.22, 11), Vector3.new(-26, 0.065, 24), palette.Path, Enum.Material.Wood, true)
	for _, x in ipairs({ -32, -20 }) do
		for _, z in ipairs({ 21, 28 }) do
			part(shop, "AwningPost", Vector3.new(0.5, 7.4, 0.5), Vector3.new(x, 3.7, z), palette.Wood, Enum.Material.Wood, true)
		end
	end
	part(shop, "Awning", Vector3.new(15, 0.5, 10), Vector3.new(-26, 7.5, 24.5), palette.Forest, Enum.Material.Fabric, false)
	for i = 0, 4 do
		part(shop, "AwningStripe", Vector3.new(1.5, 0.12, 10.1), Vector3.new(-32 + i * 3, 7.8, 24.5), palette.Cream, Enum.Material.Fabric, false)
	end
	local counter = part(shop, "Counter", Vector3.new(12, 2.5, 2.5), Vector3.new(-26, 1.25, 27.5), palette.Wood, Enum.Material.Wood, true)
	world.Shop = counter
	prompt(counter, "Interaction", "Shop", "SnackShop", "Browse snacks", "Little provisions", 0)
	for _, x in ipairs({ -29, -24 }) do
		part(shop, "SnackCrate", Vector3.new(2.5, 0.5, 1.9), Vector3.new(x, 2.75, 27.5), palette.Path, Enum.Material.Wood, false)
		for i = 1, 4 do
			sphere(shop, "ShopSnack", Vector3.new(0.5, 0.45, 0.5), Vector3.new(x - 0.7 + (i % 2) * 1.1, 3.2, 27.1 + math.floor((i - 1) / 2) * 0.7), x == -29 and palette.Berry or palette.Gold)
		end
	end
	-- The open front stays readable from spawn; a back shelf gives the stall depth.
	part(shop, "BackWall", Vector3.new(15, 4.2, 0.35), Vector3.new(-26, 2.1, 19.6), palette.Cream, Enum.Material.Wood, true)
	part(shop, "BackWallTrim", Vector3.new(15.1, 0.3, 0.4), Vector3.new(-26, 0.43, 19.6), palette.Clay, Enum.Material.Wood, false)
	part(shop, "Shelf", Vector3.new(12, 0.25, 1.2), Vector3.new(-26, 2.75, 20.4), palette.Wood, Enum.Material.Wood, false)
	for i = 1, 5 do
		local x = -31 + (i - 1) * 2.5
		local height = 1.0 + (i % 2) * 0.2
		cylinder(shop, "PantryJar", 0.8, height, Vector3.new(x, 2.9 + height / 2, 20.4), i % 2 == 0 and palette.Berry or palette.Gold, false)
		cylinder(shop, "JarLid", 0.9, 0.13, Vector3.new(x, 2.965 + height, 20.4), palette.Cream, false)
	end
	part(shop, "CounterTop", Vector3.new(12.6, 0.23, 3.0), Vector3.new(-26, 2.55, 27.5), palette.Cream, Enum.Material.Wood, false)
	part(shop, "CounterInset", Vector3.new(10.2, 1.6, 0.14), Vector3.new(-26, 1.28, 28.82), palette.Forest, Enum.Material.Wood, false)
	for _, x in ipairs({ -31.1, -26, -20.9 }) do
		part(shop, "CounterMullion", Vector3.new(0.16, 2.0, 0.17), Vector3.new(x, 1.3, 28.93), palette.Gold, Enum.Material.Wood, false)
	end
	lantern(shop, Vector3.new(-26, 6.38, 25.3))
	part(shop, "Doormat", Vector3.new(7.0, 0.08, 3.8), Vector3.new(-26, 0.14, 31.3), palette.LightLeaf, Enum.Material.Fabric, false)
	local crate = part(shop, "SideProvisionCrate", Vector3.new(2.4, 2.4, 2.4), Vector3.new(-35.8, 1.2, 24.9), palette.Clay, Enum.Material.Wood, true)
	part(shop, "CrateBand", Vector3.new(2.52, 0.16, 2.52), crate.Position + Vector3.new(0, 0.6, 0), palette.Path, Enum.Material.Wood, false)
	sign(shop, Vector3.new(-26, 3.1, 20.8), "LITTLE PROVISIONS", "Berries + seeds / bought with garden coins", 12)
	-- Hand-painted-looking roof silhouettes and planters soften the market.
	for _, x in ipairs({-34,-18}) do
		cylinder(shop,"MarketPlanter",1.8,1.6,Vector3.new(x,0.8,30),palette.Clay,false)
		bush(shop,Vector3.new(x,1.1,30),0.47)
		flower(shop,Vector3.new(x,1.65,30),palette.Cream,0.55)
	end
	part(shop,"RoofLeft",Vector3.new(9,0.5,11),Vector3.new(-29.8,8.2,24.5),palette.Forest,Enum.Material.Wood,false,nil,CFrame.Angles(0,0,0.2))
	part(shop,"RoofRight",Vector3.new(9,0.5,11),Vector3.new(-22.2,8.2,24.5),palette.Forest,Enum.Material.Wood,false,nil,CFrame.Angles(0,0,-0.2))
	part(shop,"RoofRidge",Vector3.new(0.4,0.5,11.6),Vector3.new(-26,9,24.5),palette.Gold,Enum.Material.Wood,false)
	waterJob(world, "water_1", Vector3.new(-12, 0, 21), palette.Berry)
	waterJob(world, "water_2", Vector3.new(14, 0, -23), palette.Gold)
	waterJob(world, "water_3", Vector3.new(-40, 0, -20), Color3.fromRGB(184, 157, 191))
	leafJob(world, "leaves_1", Vector3.new(20, 0, 20))
	leafJob(world, "leaves_2", Vector3.new(-18, 0, -37))
	sign(geometry, Vector3.new(26, 0, 27), "GARDEN JOBS", "Water flowers or gather leaves to earn snacks.", 10)

	-- Research clues are small, bright markers beside each creature habitat.
	makeClue(world, "mossbun_tracks", "Mossbun", Vector3.new(-12, 0, -6), "Tiny leaf-covered footprints")
	makeClue(world, "lanternwing_glow", "Lanternwing", Vector3.new(-29, 0, -28), "Golden dust on the petals")
	makeClue(world, "pebblehog_stones", "Pebblehog", Vector3.new(27, 0, -7), "A curious stack of stones")
	makeClue(world, "dewfin_ripples", "Dewfin", Vector3.new(-9, 0, -107), "Ripples without a breeze")
	makeClue(world, "mistfox_tracks", "Mistfox", Vector3.new(22, 0, -128), "Pale prints in the moss")
	makeClue(world, "reedling_reeds", "Reedling", Vector3.new(-36, 0, -94), "Reeds bent by webbed toes")
	makeClue(world, "moonhare_tracks", "Moonhare", Vector3.new(13, 0, -112), "Long lavender prints beneath the willows")
	makeClue(world, "bloomstag_petals", "Bloomstag", Vector3.new(33, 0, -94), "Warm petals without a flowering tree")
	for _, pos in ipairs({ Vector3.new(-20, 0, -7), Vector3.new(32, 0, -35), Vector3.new(-39, 0, -35) }) do
		bush(geometry, pos, 1.1)
	end
	for i, pos in ipairs({ Vector3.new(38, 0, -8), Vector3.new(37, 0, -2), Vector3.new(41, 0, -5), Vector3.new(31, 0, -12) }) do
		rock(geometry, pos, Vector3.new(3.2, 1.7 + i * 0.12, 2.8))
	end
	for i = 1, 8 do
		local angle = i * 2.4
		flower(geometry, Vector3.new(-35 + math.cos(angle) * 5, 0, -33 + math.sin(angle) * 5), i % 2 == 0 and palette.Gold or Color3.fromRGB(185, 151, 188), 1)
	end

	-- The north gate previews the next discoveries without a universal collision lock.
	local gate = Instance.new("Model")
	gate.Name = "StillwaterGate"
	gate.Parent = root
	for _, x in ipairs({ -8, 8 }) do
		part(gate, "GatePost", Vector3.new(1, 9, 1), Vector3.new(x, 4.5, -66), palette.Wood, Enum.Material.Wood, true)
	end
	part(gate, "GateBeam", Vector3.new(17.5, 1.1, 1.1), Vector3.new(0, 8.7, -66), palette.Forest, Enum.Material.Wood, false)
	local gateTarget = part(gate, "GateInteraction", Vector3.new(1, 1, 1), Vector3.new(0, 2.2, -66), palette.Forest, nil, false)
	gateTarget.Transparency = 1
	gateTarget.CanQuery = false
	world.PondGate = gateTarget
	prompt(gateTarget, "Interaction", "PondGate", "Pond", "Check discovery milestone", "The Stillwater Pond", 0)
	gateTarget:SetAttribute("Zone", "Pond")
	sign(gate, Vector3.new(0, 4.3, -66), "THE STILLWATER", "Befriend all 3 garden species to explore.", 12)
	-- The landmark arch is the readable entry, while low forest banks frame it.
	-- No world-wide gate collider is needed: the server checks each discovery.
	for _, x in ipairs({-48,-28,28,48}) do
		hillside(geometry,Vector3.new(x,0,-66),21,5,12,palette.Forest)
		tree(geometry,x,-64,0.7,palette.Pine,"Pine")
	end

	local pond = folder(root, "StillwaterPond")
	local water = cylinder(pond, "Stillwater", 63, 0.18, Vector3.new(-19, -0.04, -113), palette.Water, false)
	water.Transparency = 0
	water.CastShadow = false
	water.Material = Enum.Material.SmoothPlastic
	water:SetAttribute("LagoonWater", true)
	for i = 1, 10 do
		local angle = i * math.pi * 2 / 10
		rock(pond, Vector3.new(-19 + math.cos(angle) * 31.5, 0, -113 + math.sin(angle) * 31.5), Vector3.new(4, 1.7, 3.2))
	end
	bridge(pond,"WillowLagoonFootbridge",Vector3.new(-2,0,-96),Vector3.new(-24,0,-119),6.2)
	for i = 1, 5 do
		local x, z = -7 - i * 3.7, -100 - i * 3.2
		cylinder(pond, "MossySteppingStone", 4.4, 0.35, Vector3.new(x, -0.175, z), palette.Stone, true)
		cylinder(pond, "SteppingStoneMoss", 3.8, 0.04, Vector3.new(x, 0.02, z), palette.LightLeaf, false)
	end
	for _, pos in ipairs({ Vector3.new(-32, 0, -102), Vector3.new(-36, 0, -121), Vector3.new(-14, 0, -133) }) do
		cylinder(pond, "LilyPad", 3.3, 0.08, pos + Vector3.new(0, 0.12, 0), palette.Leaf, false)
		flower(pond, pos + Vector3.new(0, 0.1, 0), palette.Cream, 0.8)
	end
	for i = 1, 5 do
		part(pond, "Reed", Vector3.new(0.17, 2.3 + i * 0.3, 0.17), Vector3.new(-42 + i * 0.5, 1.4, -93 + (i % 2)), palette.Forest, nil, false)
		sphere(pond, "ReedTip", Vector3.new(0.32, 0.9, 0.32), Vector3.new(-42 + i * 0.5, 3.1 + i * 0.12, -93 + (i % 2)), palette.Bark)
	end
	-- Stillwater's cascade is a stable silhouette, made of opaque rock and thin water.
	local cascade = Instance.new("Model")
	cascade.Name = "StillwaterCascade"
	cascade.Parent = pond
	for i, data in ipairs({ { -47, -129, 7.2 }, { -42, -129, 8.0 }, { -39, -130, 5.8 }, { -51, -131, 4.7 }, { -45, -134, 6.5 } }) do
		local stone = rock(cascade, Vector3.new(data[1], 0, data[2]), Vector3.new(6.2, data[3], 5.5))
		stone.CanCollide = true
		stone.Material = Enum.Material.Slate
		stone.CFrame *= CFrame.Angles(0, i * 0.64, 0)
		part(cascade, "CascadeMoss", Vector3.new(3.9, 0.2, 3.1), Vector3.new(data[1], data[3] * 0.88, data[2]), palette.Leaf, Enum.Material.Grass, false, Enum.PartType.Ball)
	end
	local stream = part(cascade, "Waterfall", Vector3.new(2.9, 5.0, 0.3), Vector3.new(-43.6, 3.7, -126.5), palette.Water, Enum.Material.Glass, false, nil, CFrame.Angles(-0.09, 0, 0))
	stream.Transparency = 0.14
	stream.CastShadow = false
	stream:SetAttribute("Waterfall", true)
	for i = 1, 3 do
		local ribbon = part(cascade, "WaterRibbon", Vector3.new(0.18, 4.9, 0.06), Vector3.new(-45.0 + i * 0.67, 3.62, -126.23), palette.Cream, Enum.Material.SmoothPlastic, false, nil, CFrame.Angles(-0.09, 0, 0))
		ribbon.Transparency = 0.38
		ribbon.CastShadow = false
	end
	cylinder(cascade, "CascadePoolBed", 13.3, 0.2, Vector3.new(-43.6, 0.05, -123), palette.Stone, false)
	local pool = cylinder(cascade, "CascadePool", 11.5, 0.12, Vector3.new(-43.6, 0.2, -123), palette.Water, false)
	pool.Transparency = 0.12
	for i = 1, 6 do
		local angle = i * math.pi / 3
		rock(cascade, Vector3.new(-43.6 + math.cos(angle) * 6.4, 0.18, -123 + math.sin(angle) * 5.8), Vector3.new(2.7, 1.25, 2.0))
	end
	for i = 1, 3 do
		local foam = cylinder(cascade, "CascadeFoam", 1.7 + i * 0.3, 0.05, Vector3.new(-43.5 + (i - 2) * 1.6, 0.3, -125.4 + (i % 2)), palette.Cream, false)
		foam.Transparency = 0.2
	end
	windingPath(pond, "EastPondLoop", { Vector3.new(0, 0, -88), Vector3.new(19, 0, -90), Vector3.new(35, 0, -88), Vector3.new(44, 0, -106), Vector3.new(37, 0, -121), Vector3.new(23, 0, -130), Vector3.new(9, 0, -129), Vector3.new(0, 0, -118) }, 4.3)
	steppingTrail(pond, { Vector3.new(-9, 0, -89), Vector3.new(-17, 0, -89), Vector3.new(-24, 0, -91), Vector3.new(-30, 0, -93), Vector3.new(-35, 0, -95) }, 2.9)
	local grove = folder(pond, "BloomGrove")
	cylinder(grove, "GroveMeadow", 17.0, 0.08, Vector3.new(38, -0.01, -97), palette.LightLeaf, false)
	for i = 1, 6 do
		local angle = i * math.pi / 3
		flower(grove, Vector3.new(38 + math.cos(angle) * 6.6, 0, -97 + math.sin(angle) * 6.6), i % 2 == 0 and palette.Cream or palette.Clay, 0.77)
	end
	local moonNook = folder(pond, "MoonhareNook")
	for _, position in ipairs({ Vector3.new(16, 0, -120), Vector3.new(21, 0, -115), Vector3.new(17, 0, -111) }) do
		flower(moonNook, position, palette.Lavender, 0.95)
	end
	part(moonNook, "Moonstone", Vector3.new(2.7, 1.6, 3.2), Vector3.new(23, 0.72, -116), palette.Cream, Enum.Material.Slate, false, Enum.PartType.Ball, CFrame.Angles(0, -0.3, 0))
	bush(pond, Vector3.new(31, 0, -134), 1.6)
	tree(pond, 37, -140, 1.1, palette.Forest, "Willow")
	tree(pond, 18, -141, 0.9, palette.Forest, "Pine")
	tree(pond, 10, -121, 0.86, palette.Leaf, "Willow")
	sign(pond, Vector3.new(12, 0, -101), "WATCH THE WEATHER", "Rain wakes Dewfin. Fog reveals Mistfox.", 11)

	-- Sanctuaries have six visible pedestals; extra capacity is earned in-game.
	local sanctuaryFolder = folder(root, "Sanctuaries")
	for column = 1, 2 do
		for row = 1, 4 do
			local index = (column - 1) * 4 + row
			local x, z = column == 1 and 92 or 140, -52 + (row - 1) * 38
			local pad = Instance.new("Model")
			pad.Name = "Sanctuary" .. index
			pad:SetAttribute("SanctuaryIndex", index)
			pad.Parent = sanctuaryFolder
			-- A rounded garden terrace supports the full habitat without exposed gaps
			-- at fence corners. The narrow stone rim frames an inviting grass patch.
			oval(pad,"HabitatStoneTerrace",39,34,1.3,Vector3.new(x,-0.72,z),palette.Stone,true,Enum.Material.Slate)
			part(pad,"HabitatFloor",Vector3.new(30,0.26,29),Vector3.new(x,-0.065,z),palette.Meadow,Enum.Material.Grass,true)
			part(pad,"HabitatFloorCross",Vector3.new(34,0.26,25),Vector3.new(x,-0.055,z),palette.Meadow,Enum.Material.Grass,true)
			for _, ox in ipairs({-15,15}) do
				for _, oz in ipairs({-12.5,12.5}) do
					cylinder(pad,"RoundedHabitatCorner",4,0.26,Vector3.new(x+ox,-0.045,z+oz),palette.Meadow,true)
				end
			end
			path(pad, "WelcomePath", x, z + 7, 5, 14, 0.075)
			fence(pad, Vector3.new(x - 17, 0, z - 14.5), Vector3.new(x + 17, 0, z - 14.5))
			fence(pad, Vector3.new(x - 17, 0, z - 14.5), Vector3.new(x - 17, 0, z + 14))
			fence(pad, Vector3.new(x + 17, 0, z - 14.5), Vector3.new(x + 17, 0, z + 14))
			local label = sign(pad, Vector3.new(x + 8, 0, z + 11.5), "AVAILABLE HABITAT", "Vault = safe / displayed friends earn coins", 12)
			label.TextScaled = true
			local sizeLimit = Instance.new("UITextSizeConstraint")
			sizeLimit.MinTextSize = 14
			sizeLimit.MaxTextSize = 30
			sizeLimit.Parent = label
			local pedestals = {}
			for j = 1, 6 do
				local px = x - 10 + ((j - 1) % 3) * 10
				local pz = z - 7 + math.floor((j - 1) / 3) * 9
				local pedestal = cylinder(pad, "Pedestal" .. j, 5.7, 0.6, Vector3.new(px, 0.3, pz), palette.Cream, true)
				pedestal:SetAttribute("PedestalIndex", j)
				cylinder(pad, "PedestalTrim", 5.9, 0.1, Vector3.new(px, 0.06, pz), palette.Gold, false)
				table.insert(pedestals, pedestal)
			end
			bush(pad, Vector3.new(x - 12, 0, z + 10), 0.65)
			world.Sanctuaries[index] = {
				Folder = pad, BasePosition = Vector3.new(x, 0, z), Pedestals = pedestals,
				Spawn = CFrame.lookAt(Vector3.new(x, 3.2, z + 12), Vector3.new(x, 3.2, z)), Sign = label,
			}
			World.DecorateSanctuary(world.Sanctuaries[index], 1)
		end
	end
	sign(root, Vector3.new(66, 0, 23), "YOUR SANCTUARY", "Protect favorites in the vault. Display to earn.", 13, math.pi / 2)

	-- A far-west landmark makes the raid escape route readable from every habitat.
	local extraction = Instance.new("Model")
	extraction.Name = "ExtractionGarden"
	extraction.Parent = root
	local extractionPad = cylinder(extraction, "Extraction", 15, 0.2, Vector3.new(-45, 0.1, 43), palette.Gold, false)
	extractionPad:SetAttribute("Action", "Extraction")
	extractionPad:SetAttribute("Target", "Extraction")
	world.Extraction = extractionPad
	cylinder(extraction, "ExtractionInset", 12, 0.05, Vector3.new(-45, 0.24, 43), palette.Path, false)
	for _, x in ipairs({ -51, -39 }) do
		part(extraction, "ArchPost", Vector3.new(0.7, 8, 0.7), Vector3.new(x, 4, 43), palette.Forest, Enum.Material.Wood, false)
	end
	part(extraction, "ArchBeam", Vector3.new(13, 0.8, 0.8), Vector3.new(-45, 8, 43), palette.Forest, Enum.Material.Wood, false)
	lantern(extraction, Vector3.new(-45, 6.9, 43))
	for i = 1, 8 do
		local angle = i * math.pi / 4
		local marker = part(extraction, "ExtractionMarker", Vector3.new(0.8, 0.12, 1.8), Vector3.new(-45 + math.cos(angle) * 6.7, 0.26, 43 + math.sin(angle) * 6.7), palette.Cream, nil, false, nil, CFrame.Angles(0, -angle, 0))
		marker:SetAttribute("ExtractionMarker", true)
	end
	for i = 1, 3 do
		part(extraction, "TrailheadArrow", Vector3.new(1.4, 0.09, 0.22), Vector3.new(-45.4, 0.1, 30 + i * 2.3), palette.Gold, nil, false, nil, CFrame.Angles(0, -0.6, 0))
		part(extraction, "TrailheadArrow", Vector3.new(1.4, 0.09, 0.22), Vector3.new(-44.6, 0.1, 30 + i * 2.3), palette.Gold, nil, false, nil, CFrame.Angles(0, 0.6, 0))
	end
	sign(extraction, Vector3.new(-45, 4.1, 43), "TRAILHEAD", "Raid escape point / survive the marked chase", 11)
	path(geometry, "ExtractionApproach", -45, 34, 7, 16)

	-- Deterministic scenery stays out of the main route and all interaction distances.
	local treePositions = {
		{ -58, 44, 1.0 }, { -60, 8, 1.1 }, { -56, -44, 1.0 }, { -26, -56, 1.1 },
		{ 35, -54, 0.95 }, { 55, -42, 1.1 }, { 57, -12, 1.0 }, { 52, 45, 1.0 },
		{ 19, 51, 0.95 }, { -19, 50, 0.85 }, { -58, -86, 1.1 }, { -58, -143, 0.9 },
		{ 54, -112, 1.2 }, { 48, -85, 0.9 }, { 166, -64, 0.95 }, { 167, 78, 1.1 },
	}
	for _, data in ipairs(treePositions) do
		tree(geometry, data[1], data[2], data[3], nil, data[2] < -80 and "Pine" or nil)
	end
	-- Six trail lights plus the shop and extraction lanterns cap static lights at eight.
	for _, position in ipairs({ { -8, 30 }, { 8, -43 }, { 11, -69 }, { -9, -97 }, { 62, 31 }, { 117, 31 } }) do
		lampPost(geometry, position[1], position[2])
	end
	for i, pos in ipairs({ Vector3.new(-45, 0, 7), Vector3.new(40, 0, 36), Vector3.new(17, 0, -44), Vector3.new(-42, 0, -51), Vector3.new(46, 0, -27), Vector3.new(-10, 0, 48) }) do
		bush(geometry, pos, 0.85)
		flower(geometry, pos + Vector3.new(2.8, 0, 0.5), i % 2 == 0 and palette.Cream or palette.Berry, 0.95)
	end
	for _, x in ipairs({ -10, 11 }) do
		part(geometry, "BenchSeat", Vector3.new(5, 0.35, 1.5), Vector3.new(x, 1.6, 36), palette.Wood, Enum.Material.Wood, true)
		part(geometry, "BenchBack", Vector3.new(5, 1.4, 0.3), Vector3.new(x, 2.4, 36.6), palette.Wood, Enum.Material.Wood, false)
		for _, offset in ipairs({ -1.8, 1.8 }) do
			part(geometry, "BenchLeg", Vector3.new(0.35, 1.5, 1.1), Vector3.new(x + offset, 0.75, 36), palette.Forest, nil, false)
		end
	end
	-- Three distinctive discovery pockets sit off the loop, never on its collision
	-- lane: a fern hollow, a flowering dusk meadow, and a quiet rock garden.
	local pockets = folder(root,"DiscoveryGroves")
	for i = 1, 6 do
		local angle = i * math.pi / 3
		fern(pockets,Vector3.new(-17+math.cos(angle)*7.4,0,-4+math.sin(angle)*7.4),0.8)
	end
	for _, data in ipairs({{-25,-12,0.8},{-26,-8,0.55},{-23,-13,0.45},{-43,-36,0.7},{-44,-38,0.45},{-31,-39,0.6},{28,-42,0.85},{30,-43,0.5}}) do
		mushroom(pockets,Vector3.new(data[1],0,data[2]),data[3],palette.Clay)
	end
	-- The grand elder oak anchors the garden; its trunk stays outside all capture
	-- homes and the glow clearing remains visible from the central walking loop.
	tree(pockets,-45,-49,1.65,palette.Forest)
	for _, p in ipairs({Vector3.new(-47,0,-42),Vector3.new(-42,0,-44),Vector3.new(-48,0,-56)}) do
		fern(pockets,p,1.4)
	end
	part(pockets,"FallenLog",Vector3.new(1.7,1.7,8),Vector3.new(-48,0.86,-31),palette.Bark,Enum.Material.Wood,false,Enum.PartType.Cylinder,CFrame.Angles(0,0.75,0))
	cylinder(pockets,"LogEnd",1.54,0.14,Vector3.new(-44.3,0.86,-33.5),palette.PathEdge,false)
	-- Two flat dry patches within the shallows give Dewfin/Reedling space to roam
	-- without changing their server homes or pretending to implement swimming.
	meadowPatch(pond,Vector3.new(-16,0.12,-112),15,15,palette.Moss)
	meadowPatch(pond,Vector3.new(-41,0.12,-97),15,15,palette.Meadow)
	for _, p in ipairs({Vector3.new(-46,0,-102),Vector3.new(-36,0,-104),Vector3.new(-25,0,-116),Vector3.new(-25,0,-106)}) do
		fern(pond,p,0.86)
	end
	-- A broad stepped stone falls reads from the garden before the player unlocks
	-- the lagoon. All water remains opaque: no endless baseplate shows through.
	local landmark = folder(pond,"WillowFallsLandmark")
	for _, data in ipairs({{-48,-143,13,17,13},{-37,-145,17,21,12},{-24,-145,16,17,12},{-12,-146,12,13,12}}) do
		hillside(landmark,Vector3.new(data[1],0,data[2]),data[3],data[4],data[5],palette.Pine)
	end
	part(landmark,"UpperFalls",Vector3.new(6.8,13,0.55),Vector3.new(-33,10,-136),palette.Water,Enum.Material.SmoothPlastic,false)
	part(landmark,"FallsShelf",Vector3.new(12,1.6,7),Vector3.new(-33,3,-133),palette.Stone,Enum.Material.Slate,false)
	part(landmark,"LowerFalls",Vector3.new(8.7,3.8,0.45),Vector3.new(-33,1.8,-129.7),palette.Water,Enum.Material.SmoothPlastic,false)
	for i=1,4 do
		local ribbon=part(landmark,"FallsRibbon",Vector3.new(0.21,12.5,0.06),Vector3.new(-36.6+i*1.35,10,-135.67),palette.Cream,nil,false)
		ribbon.Transparency=0.18
		ribbon.CastShadow=false
	end
	oval(landmark,"FallsPool",23,15,0.11,Vector3.new(-33,0.07,-127),palette.Water,false)
	for i=1,4 do
		oval(landmark,"SoftFallsFoam",3+i*0.3,1.0,0.05,Vector3.new(-36+(i-1)*2.0,0.16,-129.2),palette.Cream,false)
	end
	tree(pond,-56,-116,1.16,palette.Pine,"Willow")
	tree(pond,-54,-91,1.0,palette.Leaf,"Willow")
	tree(pond,55,-130,1.18,palette.Pine,"Pine")
	bench(pond,Vector3.new(2,0,-133),0.45)
	bench(geometry,Vector3.new(35,0,40),math.pi/2)
	-- A few meadow clusters give texture at ground level, with open clearings left
	-- around every interaction. No textures, packages or hidden scripts are loaded.
	for i, data in ipairs({{-51,17},{-36,42},{-14,46},{27,46},{44,20},{43,-28},{-46,-21},{-32,-54},{21,-55},{49,-112},{32,-139},{7,-144}}) do
		local center=Vector3.new(data[1],0,data[2])
		meadowPatch(geometry,center,7.8,5.9,i%2==0 and palette.Meadow or palette.Moss)
		fern(geometry,center+Vector3.new(-2,0,1),0.65)
		flower(geometry,center+Vector3.new(1.5,0,-0.6),i%3==0 and palette.Lavender or i%2==0 and palette.Cream or palette.Clay,0.68)
		flower(geometry,center+Vector3.new(0.2,0,1.2),palette.Cream,0.46)
	end
	-- The far forest ridge closes the scene in every direction. Background peaks
	-- are visual-only beyond the transparent play boundary, so raids cannot escape.
	local background=folder(root,"DistantForestRidge")
	for i, data in ipairs({{-112,-154,44,46,48},{-101,-80,42,39,56},{-102,2,41,32,58},{-88,83,55,36,43},{-18,116,76,28,40},{70,119,61,33,42},{173,112,65,39,54},{216,37,57,44,86},{210,-61,60,41,59},{115,-166,67,39,53},{47,-194,65,47,58},{-20,-192,64,43,61}}) do
		hillside(background,Vector3.new(data[1],-5,data[2]),data[3],data[4],data[5],i%2==0 and palette.Pine or palette.Forest)
		for j=1,3 do
			local distantTree=tree(background,data[1]+(j-2)*9,data[2]+(j%2)*5,1.1+j*0.16,palette.Pine,"Pine",true)
			-- Lift the far trees onto the moss ridge instead of burying their trunks.
			distantTree:PivotTo(distantTree:GetPivot()+Vector3.new(0,data[4]*0.68-5,0))
		end
	end
	-- Transparent safety walls stop players before the visual cliff edges. They
	-- neither intercept interaction raycasts nor change unrelated Workspace parts.
	local barriers=folder(root,"PlayBoundary")
	local bounds=config.PlayableBounds or {MinX=-73,MaxX=173,MinZ=-155,MaxZ=87}
	for _, data in ipairs({
		{Vector3.new(1,44,bounds.MaxZ-bounds.MinZ+2),Vector3.new(bounds.MinX-0.5,18,(bounds.MinZ+bounds.MaxZ)/2)},
		{Vector3.new(1,44,bounds.MaxZ-bounds.MinZ+2),Vector3.new(bounds.MaxX+0.5,18,(bounds.MinZ+bounds.MaxZ)/2)},
		{Vector3.new(bounds.MaxX-bounds.MinX+2,44,1),Vector3.new((bounds.MinX+bounds.MaxX)/2,18,bounds.MinZ-0.5)},
		{Vector3.new(bounds.MaxX-bounds.MinX+2,44,1),Vector3.new((bounds.MinX+bounds.MaxX)/2,18,bounds.MaxZ+0.5)},
	}) do
		local barrier=part(barriers,"InvisibleCliffBoundary",data[1],data[2],palette.Cream,nil,true)
		barrier.Transparency=1
		barrier.CanQuery=false
		barrier.CastShadow=false
	end
	-- Raise only our model, including all prompts, to the island floor. Outside
	-- objects remain intact; the sea and scenic ridges mask the Studio template.
	local lift = Vector3.new(0, 18, 0)
	root:PivotTo(root:GetPivot() + lift)
	world.Spawn += lift
	world.TutorialPosition += lift
	for _, spawn in ipairs(world.CreatureSpawns) do spawn.position += lift end
	for _, sanctuary in ipairs(world.Sanctuaries) do
		sanctuary.BasePosition += lift
		sanctuary.Spawn += lift
	end
	return world
end

-- Rebuild only this habitat's decorative tier; creatures and prompts are untouched.
function World.DecorateSanctuary(sanctuary, level)
	if not sanctuary or not sanctuary.Folder or not sanctuary.Folder.Parent then return end
	level = math.clamp(math.floor(tonumber(level) or 1), 1, 4)
	local existing = sanctuary.Folder:FindFirstChild("HabitatDecorations")
	if existing and existing:GetAttribute("Level") == level then return end
	if existing then existing:Destroy() end
	local decor = Instance.new("Model")
	decor.Name = "HabitatDecorations"
	decor:SetAttribute("Level", level)
	decor.Parent = sanctuary.Folder
	local base = sanctuary.BasePosition
	-- The village keeps a shared silhouette; flower colors make each home easy
	-- to recognize during a chase without adding noisy floating numbers.
	local homeIndex=sanctuary.Folder:GetAttribute("SanctuaryIndex") or 1
	local homeFlower=({palette.Berry,palette.Clay,palette.Lavender,palette.Cream})[(homeIndex-1)%4+1]
	local function localPart(name, size, offset, color, material, shape, rotation)
		return part(decor, name, size, base + offset, color, material, false, shape, rotation)
	end
	-- All tiers share an entry arbor. Habitat level is visible without opening a menu.
	for _, x in ipairs({ -3.6, 3.6 }) do
		localPart("ArborPost", Vector3.new(0.42, 6.4, 0.42), Vector3.new(x, 3.2, 12.7), palette.Wood, Enum.Material.Wood)
		localPart("ArborLeaf", Vector3.new(2.8, 1.0, 1.3), Vector3.new(x, 6.2, 12.7), palette.Leaf, nil, Enum.PartType.Ball)
	end
	localPart("ArborBeam", Vector3.new(8.5, 0.4, 0.65), Vector3.new(0, 6.4, 12.7), palette.Forest, Enum.Material.Wood)
	localPart("HabitatBunting", Vector3.new(1.8, 0.85, 0.12), Vector3.new(0, 5.75, 12.7), level == 4 and palette.Gold or palette.Cream, Enum.Material.Fabric)
	localPart("EntryRunner", Vector3.new(4.1, 0.07, 4.0), Vector3.new(0, 0.235, 12.1), palette.LightLeaf, Enum.Material.Fabric)
	localPart("WelcomePlanter", Vector3.new(2.3, 1.0, 2.2), Vector3.new(-13.5, 0.5, 10.8), palette.Clay, Enum.Material.SmoothPlastic)
	localPart("PlanterLeaves", Vector3.new(2.6, 1.3, 2.5), Vector3.new(-13.5, 1.42, 10.8), palette.Leaf, nil, Enum.PartType.Ball)
	localPart("PlanterFlower", Vector3.new(1.1, 0.32, 1.1), Vector3.new(-13.5, 2.06, 10.8), homeFlower, nil, Enum.PartType.Ball)
	-- Furnish each first-level habitat so an empty collection still reads as home.
	cylinder(decor,"WelcomeSteppingStone",2.9,0.06,base+Vector3.new(0,0.235,10.1),palette.Cream,false)
	cylinder(decor,"HabitatSnackBowl",1.5,0.35,base+Vector3.new(12.7,0.18,10.8),palette.Clay,false)
	for i=1,3 do sphere(decor,"BowlBerries",Vector3.new(0.25,0.25,0.25),base+Vector3.new(12.7+(i-2)*0.23,0.4,10.8),palette.Berry) end
	if level >= 2 then
		-- A flowering trellis frames the rarest back-row residents.
		for _, x in ipairs({ -11, 11 }) do
			localPart("TrellisPost", Vector3.new(0.36, 4.3, 0.36), Vector3.new(x, 2.15, -12.7), palette.Cream, Enum.Material.Wood)
		end
		for _, height in ipairs({ 1.7, 3.5 }) do
			localPart("TrellisRail", Vector3.new(22.5, 0.17, 0.18), Vector3.new(0, height, -12.7), palette.Cream, Enum.Material.Wood)
		end
		for _, x in ipairs({ -10, 0, 10 }) do
			localPart("ClimbingVine", Vector3.new(1.1, 3.9, 0.33), Vector3.new(x, 2.45, -12.5), palette.Leaf, nil, Enum.PartType.Ball, CFrame.Angles(0, 0, 0.18))
			localPart("VineFlower", Vector3.new(0.64, 0.63, 0.14), Vector3.new(x + 0.21, 3.2, -12.26), palette.Lavender, nil, Enum.PartType.Ball)
		end
	end
	if level >= 3 then
		-- A bench and drinking pool make the habitat feel inhabited, with a clear raid lane.
		localPart("HabitatBench", Vector3.new(1.5, 0.3, 5.2), Vector3.new(14.3, 1.3, 5.8), palette.Wood, Enum.Material.Wood)
		localPart("HabitatBenchBack", Vector3.new(0.28, 1.25, 5.2), Vector3.new(15, 2.1, 5.8), palette.Wood, Enum.Material.Wood)
		for _, z in ipairs({ 4.1, 7.5 }) do
			localPart("BenchSupport", Vector3.new(1.2, 1.3, 0.3), Vector3.new(14.3, 0.65, z), palette.Forest)
		end
		cylinder(decor, "HabitatWaterBowl", 3.5, 0.4, base + Vector3.new(-13.6, 0.2, 5.0), palette.Stone, false)
		cylinder(decor, "HabitatDrinkingWater", 2.8, 0.09, base + Vector3.new(-13.6, 0.43, 5.0), palette.Water, false)
		for i = 1, 2 do
			localPart("BowlStone", Vector3.new(0.75, 0.57, 0.8), Vector3.new(-15.1, 0.27, 4.1 + i), palette.Cream, nil, Enum.PartType.Ball)
		end
	end
	if level >= 4 then
		-- The final tier is a small shelter rather than a noisy pile of effect parts.
		for _, x in ipairs({ -4, 4 }) do
			localPart("ShelterPost", Vector3.new(0.3, 5.2, 0.3), Vector3.new(x, 2.6, -11.0), palette.Wood, Enum.Material.Wood)
		end
		localPart("ShelterRoof", Vector3.new(9.5, 0.42, 3.2), Vector3.new(0, 5.3, -11.0), palette.Forest, Enum.Material.Wood, nil, CFrame.Angles(-0.12, 0, 0))
		localPart("ShelterTrim", Vector3.new(9.7, 0.18, 0.23), Vector3.new(0, 5.16, -9.4), palette.Gold, Enum.Material.Wood)
		localPart("AchievementMedallion", Vector3.new(0.9, 0.9, 0.18), Vector3.new(0, 4.42, -9.5), palette.Gold, Enum.Material.Metal, Enum.PartType.Ball)
	end
	sanctuary.Folder:SetAttribute("SanctuaryLevel", level)
end

function World.CreateCreature(config, species, id, position, tutorialOwnerId, variant)
	assert(activeWorld and activeWorld.Root.Parent, "World.Build must run before creating creatures")
	local model = CreatureVisual.Build(config, species)
	model.Name = id
	model:SetAttribute("EntityId", id)
	model:SetAttribute("Species", species)
	model.PrimaryPart:SetAttribute("EntityId", id)
	model.PrimaryPart:SetAttribute("Species", species)
	CreatureVisual.ApplyVariant(config, model, variant)
	if tutorialOwnerId then
		model:SetAttribute("TutorialOwnerId", tutorialOwnerId)
		model.PrimaryPart:SetAttribute("TutorialOwnerId", tutorialOwnerId)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = activeWorld.Creatures
	local interaction = prompt(model.PrimaryPart, "Interaction", "Creature", id, "Inspect creature", config.Creatures[species].Name, 0)
	interaction.MaxActivationDistance = config.LureRange or 15
	interaction.UIOffset = Vector2.new(0, -38)
	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "CreatureName"
	nameplate.Adornee = model.PrimaryPart
	nameplate.Size = UDim2.fromOffset(222, 55)
	local height = species == "Moonhare" and 5.8 or species == "Bloomstag" and 6.0 or species == "Mossbun" and 4.3 or 3.9
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	nameplate.MaxDistance = 38
	nameplate.AlwaysOnTop = false
	nameplate.Parent = model.PrimaryPart
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 31)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 20
	text.TextScaled = true
	text.TextColor3 = palette.Cream
	text.TextStrokeColor3 = palette.Ink
	text.TextStrokeTransparency = 0.3
	local variantName = model:GetAttribute("Variant")
	text.Text = (variantName ~= "Normal" and variantName .. " " or "") .. config.Creatures[species].Name
	text.Parent = nameplate
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MinTextSize = 14
	titleLimit.MaxTextSize = 20
	titleLimit.Parent = text
	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.Size = UDim2.new(1, 0, 0, 19)
	rarity.Position = UDim2.fromOffset(0, 31)
	rarity.BackgroundTransparency = 1
	rarity.Font = Enum.Font.GothamBold
	rarity.TextSize = 12
	rarity.TextColor3 = palette.Cream
	rarity.TextStrokeColor3 = palette.Ink
	rarity.TextStrokeTransparency = 0.2
	rarity.Text = string.upper(config.Creatures[species].Rarity)
	rarity.Parent = nameplate
	return model
end

function World.ShowDisplay(config, pedestal, creature)
	local existing = pedestal:FindFirstChild("DisplayCreature")
	if existing then existing:Destroy() end
	if not creature then return nil end
	local model = CreatureVisual.Build(config, creature.species)
	CreatureVisual.ApplyVariant(config, model, creature.variant)
	model.Name = "DisplayCreature"
	model:ScaleTo(0.86)
	-- Cylinders are rotated to put their X axis upright; their walking top is X/2.
	local top = pedestal.Position.Y + pedestal.Size.X / 2
	model:PivotTo(CFrame.new(pedestal.Position.X, top, pedestal.Position.Z))
	model.Parent = pedestal
	local ownerId = pedestal:GetAttribute("OwnerUserId") or creature.ownerUserId or creature.OwnerUserId
	for _, target in ipairs({ model, model.PrimaryPart }) do
		target:SetAttribute("Species", creature.species)
		target:SetAttribute("CreatureUid", creature.uid)
		if ownerId then target:SetAttribute("OwnerUserId", ownerId) end
	end
	model.PrimaryPart:SetAttribute("Action", "Display")
	model.PrimaryPart:SetAttribute("Target", creature.uid)
	return model
end

return World

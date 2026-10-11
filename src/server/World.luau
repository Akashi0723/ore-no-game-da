-- Wildbound's asset-free garden. Owns only the generated WildboundWorld model.
-- Walking surfaces finish at y=0.05 to clear an existing y=0 baseplate.
-- Creature models still use a local feet-origin pivot, shifted with the world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreatureVisual = require(ReplicatedStorage:WaitForChild("Wildbound"):WaitForChild("CreatureVisual"))

local World = {}
local activeWorld = nil

local palette = {
	Grass = Color3.fromRGB(137, 164, 104),
	Meadow = Color3.fromRGB(150, 173, 116),
	Path = Color3.fromRGB(223, 207, 165),
	PathEdge = Color3.fromRGB(196, 179, 139),
	Forest = Color3.fromRGB(53, 94, 66),
	Leaf = Color3.fromRGB(109, 145, 84),
	LightLeaf = Color3.fromRGB(154, 177, 108),
	Wood = Color3.fromRGB(139, 107, 77),
	Bark = Color3.fromRGB(105, 83, 65),
	Cream = Color3.fromRGB(246, 242, 232),
	Ink = Color3.fromRGB(24, 63, 50),
	Gold = Color3.fromRGB(211, 164, 76),
	Berry = Color3.fromRGB(185, 80, 104),
	Stone = Color3.fromRGB(153, 158, 142),
	Water = Color3.fromRGB(116, 171, 163),
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
	p.CanQuery = true
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

local function prompt(p, name, action, target, text, object, hold)
	p:SetAttribute("Action", action)
	p:SetAttribute("Target", target)
	local interaction = Instance.new("ProximityPrompt")
	interaction.Name = name or "Interaction"
	interaction.ActionText = text
	interaction.ObjectText = object
	interaction.HoldDuration = hold or 0
	interaction.MaxActivationDistance = 12
	interaction.RequiresLineOfSight = false
	interaction.KeyboardKeyCode = Enum.KeyCode.E
	interaction.GamepadKeyCode = Enum.KeyCode.ButtonX
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

local function tree(parent, x, z, scale, shade)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "GardenTree"
	model.Parent = parent
	cylinder(model, "Trunk", 1.65 * scale, 10 * scale, Vector3.new(x, 5 * scale, z), palette.Bark, true)
	part(model, "Branch", Vector3.new(0.8, 5.2, 0.8) * scale, Vector3.new(x + 1.0 * scale, 8 * scale, z), palette.Bark, Enum.Material.Wood, false, nil, CFrame.Angles(0, 0, -0.53))
	sphere(model, "Crown", Vector3.new(10, 9, 10) * scale, Vector3.new(x, 12 * scale, z), shade or palette.Leaf)
	sphere(model, "CrownLight", Vector3.new(7, 6, 7) * scale, Vector3.new(x + 3.1 * scale, 12.6 * scale, z - 0.5 * scale), palette.LightLeaf)
	sphere(model, "CrownLow", Vector3.new(7.5, 6.5, 7.5) * scale, Vector3.new(x - 2.8 * scale, 10.9 * scale, z + scale), shade or palette.Leaf)
	return model
end

local function bush(parent, position, size)
	size = size or 1
	sphere(parent, "LeafBush", Vector3.new(4.6, 2.4, 3.9) * size, position + Vector3.new(0, 1.1 * size, 0), palette.Leaf)
	sphere(parent, "BushLight", Vector3.new(2.8, 2.1, 2.6) * size, position + Vector3.new(1.35 * size, 1.2 * size, -0.2 * size), palette.LightLeaf)
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

local function path(parent, name, x, z, width, depth)
	part(parent, name .. "Border", Vector3.new(width + 0.8, 0.22, depth + 0.8), Vector3.new(x, -0.12, z), palette.PathEdge, Enum.Material.Sand, true)
	return part(parent, name, Vector3.new(width, 0.2, depth), Vector3.new(x, -0.1, z), palette.Path, Enum.Material.Sand, true)
end

local function rock(parent, position, size)
	return sphere(parent, "RiverStone", size, position + Vector3.new(0, size.Y * 0.4, 0), palette.Stone)
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
	if species == "Mossbun" or species == "Mistfox" then
		for i = 1, 4 do
			sphere(holder, "Pawprint", Vector3.new(0.45, 0.08, 0.65), position + Vector3.new((i % 2 == 0 and 0.36 or -0.36), 0.16, (i - 2.5) * 0.7), species == "Mistfox" and palette.Cream or palette.Ink)
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
	local world = {
		Root = root,
		Creatures = folder(root, "Creatures"),
		Interactions = folder(root, "Interactions"),
		Sanctuaries = {}, Jobs = {}, Clues = {},
		Spawn = CFrame.lookAt(Vector3.new(0, 3.2, 31), Vector3.new(0, 3.2, 8)),
		TutorialPosition = Vector3.new(0, 0, 8),
		CreatureSpawns = {
			{ id = "garden_mossbun_1", species = "Mossbun", position = Vector3.new(-17, 0, -4) },
			{ id = "garden_mossbun_2", species = "Mossbun", position = Vector3.new(29, 0, -32) },
			{ id = "garden_lanternwing", species = "Lanternwing", position = Vector3.new(-34, 0, -31) },
			{ id = "garden_pebblehog", species = "Pebblehog", position = Vector3.new(34, 0, -4) },
			{ id = "pond_dewfin", species = "Dewfin", position = Vector3.new(-16, 0, -112) },
			{ id = "pond_mistfox", species = "Mistfox", position = Vector3.new(28, 0, -130) },
		},
	}
	activeWorld = world
	part(geometry, "GardenGround", Vector3.new(140, 1, 128), Vector3.new(0, -0.5, -7), palette.Grass, Enum.Material.Grass, true)
	part(geometry, "SanctuaryGround", Vector3.new(106, 1, 164), Vector3.new(117, -0.5, 9), palette.Meadow, Enum.Material.Grass, true)
	part(geometry, "PondGround", Vector3.new(140, 1, 84), Vector3.new(0, -0.5, -111), palette.Leaf, Enum.Material.Grass, true)
	path(geometry, "GardenWalk", 0, -12, 9, 104)
	path(geometry, "Crossing", 1, 22, 108, 8)
	path(geometry, "ResearchTrail", 0, -27, 92, 6)
	path(geometry, "SanctuaryWalk", 68, 31, 46, 8)
	path(geometry, "SanctuaryLane", 117, 9, 9, 152)
	path(geometry, "PondWalk", 0, -110, 8, 87)
	for _, z in ipairs({ -52, -14, 24, 62 }) do
		path(geometry, "HabitatLane", 117, z, 96, 5)
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
	local welcome = sign(geometry, Vector3.new(12, 0, 36), "WILDBOUND", "Follow the leaves. Find your first friend.", 13)
	welcome.TextColor3 = palette.Ink
	bush(geometry, Vector3.new(-3.8, 0, 7), 0.9)
	bush(geometry, Vector3.new(3.8, 0, 7), 0.8)
	cylinder(geometry, "BerryBowl", 1.5, 0.25, Vector3.new(0, 0.15, 11.1), palette.Cream, false)
	for i = 1, 3 do
		sphere(geometry, "StarterBerry", Vector3.new(0.32, 0.32, 0.32), Vector3.new((i - 2) * 0.32, 0.38, 11.1), palette.Berry)
	end

	-- A small market stall sits on the loop back from the first encounter.
	local shop = Instance.new("Model")
	shop.Name = "SnackShop"
	shop.Parent = root
	part(shop, "Platform", Vector3.new(17, 0.22, 11), Vector3.new(-26, -0.11, 24), palette.Path, Enum.Material.Wood, true)
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
	sign(shop, Vector3.new(-26, 3.1, 20.8), "LITTLE PROVISIONS", "Berries + seeds / bought with garden coins", 12)
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
	fence(geometry, Vector3.new(-68, 0, -66), Vector3.new(-9, 0, -66))
	fence(geometry, Vector3.new(9, 0, -66), Vector3.new(68, 0, -66))

	local pond = folder(root, "StillwaterPond")
	local water = cylinder(pond, "Stillwater", 63, 0.18, Vector3.new(-19, -0.04, -113), palette.Water, false)
	water.Transparency = 0.16
	water.Material = Enum.Material.SmoothPlastic
	for i = 1, 10 do
		local angle = i * math.pi * 2 / 10
		rock(pond, Vector3.new(-19 + math.cos(angle) * 31.5, 0, -113 + math.sin(angle) * 31.5), Vector3.new(4, 1.7, 3.2))
	end
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
	bush(pond, Vector3.new(31, 0, -134), 1.6)
	tree(pond, 37, -140, 1.1, palette.Forest)
	tree(pond, 18, -141, 0.9, palette.Forest)
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
			part(pad, "HabitatFloor", Vector3.new(34, 0.26, 29), Vector3.new(x, -0.13, z), Color3.fromRGB(181, 191, 139), Enum.Material.Grass, true)
			path(pad, "WelcomePath", x, z + 7, 5, 14)
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
		tree(geometry, data[1], data[2], data[3])
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
	-- Never hide or delete the user's baseplate. This tiny offset avoids coincident
	-- surfaces in the standard Studio template and keeps every returned position aligned.
	local lift = Vector3.new(0, 0.05, 0)
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

function World.CreateCreature(config, species, id, position, tutorialOwnerId)
	assert(activeWorld and activeWorld.Root.Parent, "World.Build must run before creating creatures")
	local model = CreatureVisual.Build(config, species)
	model.Name = id
	model:SetAttribute("EntityId", id)
	model:SetAttribute("Species", species)
	model.PrimaryPart:SetAttribute("EntityId", id)
	model.PrimaryPart:SetAttribute("Species", species)
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
	nameplate.Size = UDim2.fromOffset(190, 48)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, species == "Mossbun" and 4.3 or 3.9, 0)
	nameplate.MaxDistance = 38
	nameplate.AlwaysOnTop = false
	nameplate.Parent = model.PrimaryPart
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 20
	text.TextColor3 = palette.Cream
	text.TextStrokeColor3 = palette.Ink
	text.TextStrokeTransparency = 0.3
	text.Text = config.Creatures[species].Name
	text.Parent = nameplate
	return model
end

function World.ShowDisplay(config, pedestal, creature)
	local existing = pedestal:FindFirstChild("DisplayCreature")
	if existing then existing:Destroy() end
	if not creature then return nil end
	local model = CreatureVisual.Build(config, creature.species)
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

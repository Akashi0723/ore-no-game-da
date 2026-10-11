-- Procedural, asset-free creature models shared by the world and UI portraits.
-- Models pivot at their feet (0, 0, 0). Decorative parts never participate in physics.
local CreatureVisual = {}

local function piece(parent, name, size, position, color, shape, rotation)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position) * (rotation or CFrame.new())
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function ball(parent, name, size, position, color)
	return piece(parent, name, size, position, color, Enum.PartType.Ball)
end

local function wedge(parent, name, size, position, color, rotation)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position) * (rotation or CFrame.new())
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = parent
	return p
end

local function face(model, eyeX, eyeY, eyeZ, eyeSize)
	local ink = Color3.fromRGB(32, 49, 42)
	local cream = Color3.fromRGB(253, 247, 223)
	for _, sign in ipairs({ -1, 1 }) do
		ball(model, "Eye", Vector3.new(eyeSize, eyeSize * 1.15, eyeSize * 0.7), Vector3.new(sign * eyeX, eyeY, eyeZ), ink)
		ball(model, "EyeGlint", Vector3.new(eyeSize * 0.3, eyeSize * 0.3, eyeSize * 0.2), Vector3.new(sign * eyeX - eyeSize * 0.15, eyeY + eyeSize * 0.2, eyeZ - eyeSize * 0.32), cream)
	end
end

local function foot(model, x, z, color)
	ball(model, "Paw", Vector3.new(0.7, 0.45, 0.8), Vector3.new(x, 0.23, z), color)
end

function CreatureVisual.Build(config, species)
	local definition = config.Creatures[species]
	assert(definition, "Unknown Wildbound creature: " .. tostring(species))
	local model = Instance.new("Model")
	model.Name = species
	local root = piece(model, "Root", Vector3.new(0.25, 0.25, 0.25), Vector3.zero, definition.Color)
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root
	model:SetAttribute("Species", species)
	local color, accent = definition.Color, definition.Accent
	local cream = Color3.fromRGB(247, 238, 207)
	local blush = Color3.fromRGB(205, 133, 130)
	local leaf = Color3.fromRGB(93, 131, 72)

	if species == "Mossbun" then
		ball(model, "Body", Vector3.new(2.55, 2.3, 2.2), Vector3.new(0, 1.3, 0.15), color)
		ball(model, "Belly", Vector3.new(1.5, 1.25, 0.35), Vector3.new(0, 1.05, -0.92), cream)
		for _, sign in ipairs({ -1, 1 }) do
			piece(model, "TallEar", Vector3.new(0.57, 1.65, 0.65), Vector3.new(sign * 0.62, 3.0, 0.02), color, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * -0.18))
			piece(model, "EarCenter", Vector3.new(0.25, 1.1, 0.18), Vector3.new(sign * 0.64, 3.01, -0.28), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * -0.18))
			foot(model, sign * 0.69, -0.4, color)
			ball(model, "Cheek", Vector3.new(0.45, 0.25, 0.12), Vector3.new(sign * 0.75, 1.38, -0.98), blush)
		end
		ball(model, "CottonTail", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 1.0, 1.2), cream)
		face(model, 0.45, 1.77, -0.94, 0.21)
		ball(model, "Nose", Vector3.new(0.21, 0.15, 0.14), Vector3.new(0, 1.49, -1.05), accent)
		piece(model, "SproutStem", Vector3.new(0.1, 0.6, 0.1), Vector3.new(0.1, 2.66, 0.13), leaf)
		piece(model, "SproutLeft", Vector3.new(0.65, 0.15, 0.4), Vector3.new(-0.16, 2.95, 0.13), leaf, Enum.PartType.Ball, CFrame.Angles(0, 0, -0.25))
		piece(model, "SproutRight", Vector3.new(0.65, 0.15, 0.4), Vector3.new(0.37, 2.95, 0.13), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, 0.25))
	elseif species == "Lanternwing" then
		ball(model, "Body", Vector3.new(1.5, 1.7, 1.15), Vector3.new(0, 1.7, 0), color)
		ball(model, "LanternAbdomen", Vector3.new(1.35, 1.25, 1.05), Vector3.new(0, 0.8, 0.1), accent).Material = Enum.Material.Neon
		for _, sign in ipairs({ -1, 1 }) do
			piece(model, "UpperWing", Vector3.new(1.85, 2.2, 0.28), Vector3.new(sign * 1.2, 2.05, 0.22), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * -0.42))
			piece(model, "WingInset", Vector3.new(1.1, 1.55, 0.1), Vector3.new(sign * 1.2, 2.12, 0.02), cream, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * -0.42))
			piece(model, "LowerWing", Vector3.new(1.3, 1.25, 0.25), Vector3.new(sign * 0.97, 0.94, 0.28), color, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * 0.4))
			piece(model, "Antenna", Vector3.new(0.12, 0.9, 0.12), Vector3.new(sign * 0.43, 2.81, 0), color, nil, CFrame.Angles(0, 0, sign * -0.34))
			ball(model, "AntennaLight", Vector3.new(0.27, 0.27, 0.27), Vector3.new(sign * 0.6, 3.2, 0), accent).Material = Enum.Material.Neon
		end
		face(model, 0.28, 2.06, -0.48, 0.19)
		ball(model, "Mouth", Vector3.new(0.16, 0.08, 0.09), Vector3.new(0, 1.82, -0.6), cream)
	elseif species == "Pebblehog" then
		ball(model, "Body", Vector3.new(2.8, 1.95, 2.85), Vector3.new(0, 1.16, 0.12), color)
		ball(model, "Face", Vector3.new(1.75, 1.25, 1.3), Vector3.new(0, 1.08, -1.02), cream)
		for _, x in ipairs({ -0.75, 0, 0.75 }) do
			for _, z in ipairs({ -0.15, 0.65 }) do
				wedge(model, "StoneSpine", Vector3.new(0.6, 0.82, 0.75), Vector3.new(x, 2.07, z), accent, CFrame.Angles(0, 0, x * -0.13))
			end
		end
		for _, sign in ipairs({ -1, 1 }) do
			ball(model, "Ear", Vector3.new(0.55, 0.5, 0.48), Vector3.new(sign * 0.8, 1.87, -0.9), color)
			foot(model, sign * 0.82, -0.77, accent)
			foot(model, sign * 0.82, 0.82, accent)
		end
		face(model, 0.44, 1.39, -1.56, 0.2)
		ball(model, "Nose", Vector3.new(0.34, 0.24, 0.25), Vector3.new(0, 1.02, -1.76), Color3.fromRGB(46, 55, 51))
	elseif species == "Dewfin" then
		ball(model, "FishBody", Vector3.new(2.0, 1.72, 2.4), Vector3.new(0, 1.22, -0.03), color)
		ball(model, "Belly", Vector3.new(1.35, 0.55, 1.6), Vector3.new(0, 0.69, -0.22), cream)
		wedge(model, "DorsalFin", Vector3.new(0.22, 1.0, 1.28), Vector3.new(0, 2.24, 0.1), accent)
		for _, sign in ipairs({ -1, 1 }) do
			piece(model, "SideFin", Vector3.new(1.05, 0.2, 0.8), Vector3.new(sign * 1.01, 1.08, 0.14), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * 0.28))
			piece(model, "TailFin", Vector3.new(0.82, 1.12, 0.25), Vector3.new(sign * 0.36, 1.34, 1.5), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * 0.42))
		end
		face(model, 0.45, 1.5, -1.05, 0.23)
		ball(model, "RoundMouth", Vector3.new(0.28, 0.24, 0.13), Vector3.new(0, 1.18, -1.26), accent)
		for _, x in ipairs({ -0.6, 0, 0.6 }) do
			ball(model, "DewPearl", Vector3.new(0.2, 0.2, 0.2), Vector3.new(x, 2.01, -0.2), cream)
		end
	elseif species == "Mistfox" then
		ball(model, "Body", Vector3.new(2.05, 1.75, 2.48), Vector3.new(0, 1.18, 0.3), color)
		ball(model, "Head", Vector3.new(2.12, 1.78, 1.72), Vector3.new(0, 2.0, -0.55), color)
		ball(model, "FaceMask", Vector3.new(1.5, 0.75, 0.6), Vector3.new(0, 1.77, -1.31), cream)
		for _, sign in ipairs({ -1, 1 }) do
			wedge(model, "PointedEar", Vector3.new(0.65, 1.2, 0.65), Vector3.new(sign * 0.68, 3.06, -0.5), color, CFrame.Angles(0, 0, sign * -0.12))
			wedge(model, "EarCenter", Vector3.new(0.3, 0.75, 0.25), Vector3.new(sign * 0.68, 3.03, -0.82), accent, CFrame.Angles(0, 0, sign * -0.12))
			foot(model, sign * 0.6, -0.35, color)
			foot(model, sign * 0.6, 0.93, color)
		end
		piece(model, "SweepingTail", Vector3.new(1.12, 1.1, 2.18), Vector3.new(0.76, 1.36, 1.95), color, Enum.PartType.Ball, CFrame.Angles(0.3, -0.4, 0.2))
		ball(model, "TailTip", Vector3.new(0.9, 0.86, 0.8), Vector3.new(1.08, 1.72, 2.68), cream)
		face(model, 0.48, 2.15, -1.25, 0.23)
		ball(model, "Nose", Vector3.new(0.27, 0.16, 0.16), Vector3.new(0, 1.9, -1.63), accent)
		for _, sign in ipairs({ -1, 1 }) do
			ball(model, "MistMark", Vector3.new(0.24, 0.5, 0.13), Vector3.new(sign * 0.79, 1.93, -1.1), accent)
		end
	else
		ball(model, "Body", Vector3.new(2, 2, 2), Vector3.new(0, 1, 0), color)
		face(model, 0.4, 1.3, -0.83, 0.2)
	end

	return model
end

return CreatureVisual

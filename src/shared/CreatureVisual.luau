-- Procedural, asset-free creature models shared by the world and UI portraits.
-- Models pivot at their feet (0, 0, 0). Decorative parts never participate in physics.
local CreatureVisual = {}

-- Shared rigid groups keep inset colors, spots and facial details attached to
-- the same animated joint. Rest transforms are stored at unit scale so portraits,
-- tiny followers and full-size wild encounters share the exact same rig.
local headPivots = {
	Mossbun = Vector3.new(0, 1.58, -0.36), Lanternwing = Vector3.new(0, 1.63, 0),
	Pebblehog = Vector3.new(0, 1.08, -0.85), Dewfin = Vector3.new(0, 1.25, -0.45),
	Mistfox = Vector3.new(0, 1.77, -0.48), Reedling = Vector3.new(0, 1.21, -0.35),
	Moonhare = Vector3.new(0, 2.0, -0.45), Bloomstag = Vector3.new(0, 2.47, -0.79),
}

local function annotate(model, species, existingOnly)
	local scale, rootFrame = model:GetScale(), model.PrimaryPart.CFrame
	local headPivot = headPivots[species] or Vector3.new(0, 1.5, 0)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and (not existingOnly or p:GetAttribute("RestCFrame") == nil) then
			local localFrame = rootFrame:ToObjectSpace(p.CFrame)
			local position = localFrame.Position / scale
			local name, sign = p.Name, position.X < 0 and -1 or 1
			local group, parent, pivot = "Body", "", Vector3.new(0, 1.2, 0)
			local headDetail = name == "Head" or name == "Face" or name == "FaceMask" or name == "Muzzle" or name == "Nose" or name == "Mouth" or name == "RoundMouth" or name == "Smile" or name == "Cheek" or name == "EyeBump" or name == "Brow" or name == "LeafFreckle" or name == "MistMark" or string.find(name, "Whisker") or string.find(name, "MoonMark") or string.find(name, "Antler") or name == "BloomCenter" or name == "MistTuft" or string.find(name, "Sprout") or string.find(name, "Antenna")
			if headDetail then group, parent, pivot = "Head", "Body", headPivot end
			if string.find(name, "Ear") then
				group, parent = sign < 0 and "EarL" or "EarR", "Head"
				local height = species == "Moonhare" and 2.9 or species == "Mistfox" and 2.55 or species == "Bloomstag" and 3.35 or species == "Pebblehog" and 1.7 or 2.26
				pivot = Vector3.new(sign * (species == "Bloomstag" and 0.65 or 0.56), height, species == "Moonhare" and -0.26 or species == "Mistfox" and -0.5 or species == "Bloomstag" and -1.02 or species == "Pebblehog" and -0.8 or 0.02)
			elseif string.find(name, "Wing") then
				group, parent, pivot = sign < 0 and "WingL" or "WingR", "Body", Vector3.new(sign * 0.51, 1.75, 0.18)
			elseif name == "SideFin" then
				group, parent, pivot = sign < 0 and "FinL" or "FinR", "Body", Vector3.new(sign * 0.78, 1.08, 0.14)
			elseif string.find(name, "Tail") then
				group, parent, pivot = "Tail", "Body", Vector3.new(0, species == "Bloomstag" and 1.9 or 1.18, species == "Dewfin" and 1.05 or species == "Moonhare" and 1.16 or 1.2)
			elseif name == "Eye" or name == "EyeGlint" then
				group, parent, pivot = sign < 0 and "EyeL" or "EyeR", "Head", headPivot
				p:SetAttribute("EyePart", true)
			elseif name == "ForePaw" then
				group, parent, pivot = sign < 0 and "ArmL" or "ArmR", "Body", Vector3.new(sign * 0.81, 1.26, -0.7)
			elseif string.find(name, "Paw") or string.find(name, "Foot") or string.find(name, "Toe") or name == "Leg" or name == "Hoof" or name == "LeafCuff" or name == "Haunch" then
				local back = position.Z > 0.3
				group = (sign < 0 and "LegL" or "LegR") .. (back and "R" or "F")
				parent, pivot = "Body", Vector3.new(sign * (species == "Reedling" and 1 or 0.64), species == "Bloomstag" and 1.3 or 0.58, back and (species == "Bloomstag" and 1.25 or 0.8) or -0.45)
			elseif string.find(name, "Reed") then
				group, parent, pivot = "Crest", "Body", Vector3.new(0, 1.7, 0.39)
			end
			p:SetAttribute("AnimationGroup", group)
			p:SetAttribute("AnimationParent", parent)
			p:SetAttribute("AnimationPivot", pivot)
			p:SetAttribute("RestCFrame", CFrame.new(position) * localFrame.Rotation)
			p:SetAttribute("RestSize", p.Size / scale)
		end
	end
	model:SetAttribute("AnimationRig", "JointGroups_v1")
end

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
	p:SetAttribute("NaturalColor", color)
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
	p:SetAttribute("NaturalColor", color)
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
	local petal = Color3.fromRGB(232, 183, 155)

	if species == "Mossbun" then
		ball(model, "Body", Vector3.new(2.55, 2.3, 2.2), Vector3.new(0, 1.3, 0.15), color)
		ball(model, "Belly", Vector3.new(1.5, 1.25, 0.35), Vector3.new(0, 1.05, -0.92), cream)
		ball(model, "Head", Vector3.new(2.08, 1.55, 1.84), Vector3.new(0, 1.85, -0.12), color)
		for _, sign in ipairs({ -1, 1 }) do
			ball(model, "ForePaw", Vector3.new(0.52, 0.78, 0.61), Vector3.new(sign * 0.85, 1.12, -0.73), color)
		end
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
		for _, sign in ipairs({ -1, 1 }) do
			piece(model, "LeafCuff", Vector3.new(0.8, 0.18, 0.48), Vector3.new(sign * 0.75, 0.42, -0.35), leaf, Enum.PartType.Ball, CFrame.Angles(0, sign * 0.28, 0))
			ball(model, "LeafFreckle", Vector3.new(0.12, 0.1, 0.05), Vector3.new(sign * 0.69, 1.55, -1.02), cream)
		end
	elseif species == "Lanternwing" then
		ball(model, "Head", Vector3.new(1.5, 1.7, 1.15), Vector3.new(0, 1.7, 0), color)
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
		for _, sign in ipairs({ -1, 1 }) do
			ball(model, "WingEyespot", Vector3.new(0.55, 0.72, 0.09), Vector3.new(sign * 1.4, 2.05, -0.05), color)
			ball(model, "WingEyespotCenter", Vector3.new(0.22, 0.3, 0.06), Vector3.new(sign * 1.4, 2.05, -0.12), accent)
			piece(model, "WingVein", Vector3.new(0.06, 1.3, 0.04), Vector3.new(sign * 1.17, 2.15, -0.13), accent, nil, CFrame.Angles(0, 0, sign * -0.42))
		end
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
		for _, x in ipairs({ -0.73, 0.6 }) do
			ball(model, "SpineMoss", Vector3.new(0.52, 0.17, 0.63), Vector3.new(x, 2.47, 0.6), leaf)
		end
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
		for _, sign in ipairs({ -1, 1 }) do
			for i = 1, 3 do
				ball(model, "WaterMark", Vector3.new(0.09, 0.19, 0.24), Vector3.new(sign * (0.92 - i * 0.025), 1.42, -0.12 + i * 0.32), accent)
			end
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
		for i = 1, 3 do
			piece(model, "MistTuft", Vector3.new(0.26, 0.36 + i * 0.08, 0.55), Vector3.new((i - 2) * 0.38, 2.53, 0.15), cream, Enum.PartType.Ball, CFrame.Angles(0.38, 0, 0))
		end
	elseif species == "Reedling" then
		-- A squat amphibian with broad webbed toes and an unmistakable reed crest.
		ball(model, "Body", Vector3.new(2.75, 1.45, 2.35), Vector3.new(0, 0.98, 0.15), color)
		ball(model, "Belly", Vector3.new(1.9, 0.74, 0.38), Vector3.new(0, 0.79, -0.91), cream)
		for _, sign in ipairs({ -1, 1 }) do
			ball(model, "EyeBump", Vector3.new(0.98, 0.91, 0.87), Vector3.new(sign * 0.79, 1.75, -0.52), color)
			ball(model, "Eye", Vector3.new(0.36, 0.42, 0.17), Vector3.new(sign * 0.8, 1.83, -0.96), Color3.fromRGB(31, 59, 43))
			ball(model, "EyeGlint", Vector3.new(0.1, 0.1, 0.07), Vector3.new(sign * 0.8 - 0.05, 1.92, -1.04), cream)
			ball(model, "Haunch", Vector3.new(1.1, 0.77, 1.35), Vector3.new(sign * 1.13, 0.62, 0.5), color)
			piece(model, "WebbedFoot", Vector3.new(1.1, 0.23, 0.97), Vector3.new(sign * 1.05, 0.13, -0.6), accent, Enum.PartType.Ball)
			for i = 1, 3 do
				ball(model, "WebbedToe", Vector3.new(0.2, 0.18, 0.42), Vector3.new(sign * 1.05 + (i - 2) * 0.27, 0.14, -1.0), accent)
			end
			ball(model, "Cheek", Vector3.new(0.4, 0.17, 0.08), Vector3.new(sign * 0.99, 1.28, -0.82), petal)
		end
		piece(model, "Smile", Vector3.new(0.71, 0.08, 0.07), Vector3.new(0, 1.1, -1.08), Color3.fromRGB(48, 80, 52))
		for i = 1, 3 do
			local x = (i - 2) * 0.29
			piece(model, "ReedCrest", Vector3.new(0.12, 0.92 + (i % 2) * 0.3, 0.12), Vector3.new(x, 2.09, 0.39), leaf, nil, CFrame.Angles(0, 0, x * -0.6))
			ball(model, "ReedSeedhead", Vector3.new(0.23, 0.46, 0.22), Vector3.new(x * 1.3, 2.66 + (i % 2) * 0.17, 0.39), accent)
		end
	elseif species == "Moonhare" then
		-- Taller than Mossbun: crescent ears, a narrow chest and long running paws.
		ball(model, "Body", Vector3.new(1.9, 2.25, 2.3), Vector3.new(0, 1.42, 0.3), color)
		ball(model, "Head", Vector3.new(1.8, 1.62, 1.48), Vector3.new(0, 2.41, -0.53), color)
		ball(model, "Chest", Vector3.new(1.07, 1.19, 0.31), Vector3.new(0, 1.32, -0.81), cream)
		for _, sign in ipairs({ -1, 1 }) do
			piece(model, "MoonEar", Vector3.new(0.51, 2.45, 0.57), Vector3.new(sign * 0.53, 4.0, -0.27), color, Enum.PartType.Ball, CFrame.Angles(-0.17, 0, sign * -0.17))
			piece(model, "EarCenter", Vector3.new(0.23, 1.95, 0.12), Vector3.new(sign * 0.55, 4.03, -0.55), accent, Enum.PartType.Ball, CFrame.Angles(-0.17, 0, sign * -0.17))
			ball(model, "LongPaw", Vector3.new(0.62, 0.44, 1.29), Vector3.new(sign * 0.63, 0.24, -0.45), cream)
			ball(model, "Haunch", Vector3.new(0.92, 1.04, 1.27), Vector3.new(sign * 0.65, 0.94, 0.83), color)
			piece(model, "StarlitWhisker", Vector3.new(0.69, 0.05, 0.05), Vector3.new(sign * 0.74, 2.14, -1.27), cream, nil, CFrame.Angles(0, 0, sign * 0.18))
		end
		face(model, 0.4, 2.59, -1.14, 0.23)
		ball(model, "Nose", Vector3.new(0.2, 0.14, 0.13), Vector3.new(0, 2.25, -1.33), accent)
		for _, sign in ipairs({ -1, 1 }) do
			ball(model, "ForePaw", Vector3.new(0.37, 0.83, 0.52), Vector3.new(sign * 0.72, 1.39, -0.72), color)
		end
		ball(model, "MoonTail", Vector3.new(0.72, 0.8, 0.73), Vector3.new(0, 1.16, 1.53), accent)
		ball(model, "MoonMark", Vector3.new(0.46, 0.42, 0.08), Vector3.new(0, 2.91, -1.05), cream)
		ball(model, "MoonMarkInset", Vector3.new(0.39, 0.34, 0.06), Vector3.new(0.12, 2.98, -1.11), color)
	elseif species == "Bloomstag" then
		-- A small deer with branching antlers and flowering crown, readable at distance.
		ball(model, "Body", Vector3.new(2.05, 1.65, 3.0), Vector3.new(0, 1.65, 0.37), color)
		piece(model, "Neck", Vector3.new(1.1, 1.6, 1.12), Vector3.new(0, 2.39, -0.72), color, Enum.PartType.Ball, CFrame.Angles(-0.22, 0, 0))
		ball(model, "Head", Vector3.new(1.5, 1.45, 1.66), Vector3.new(0, 3.08, -1.11), color)
		ball(model, "Muzzle", Vector3.new(0.94, 0.58, 0.79), Vector3.new(0, 2.8, -1.84), cream)
		for _, sign in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -0.5, 1.25 }) do
				piece(model, "Leg", Vector3.new(0.42, 1.25, 0.44), Vector3.new(sign * 0.65, 0.71, z), color)
				ball(model, "Hoof", Vector3.new(0.5, 0.33, 0.63), Vector3.new(sign * 0.65, 0.18, z - 0.08), accent)
			end
			piece(model, "LeafEar", Vector3.new(0.98, 0.39, 0.62), Vector3.new(sign * 0.98, 3.46, -1.02), leaf, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * 0.26))
			piece(model, "Antler", Vector3.new(0.2, 1.5, 0.2), Vector3.new(sign * 0.64, 4.18, -0.88), accent, nil, CFrame.Angles(0, 0, sign * -0.21))
			piece(model, "AntlerBranch", Vector3.new(0.18, 0.94, 0.18), Vector3.new(sign * 1.07, 4.5, -0.85), accent, nil, CFrame.Angles(0, 0, sign * -0.82))
			piece(model, "AntlerFork", Vector3.new(0.15, 0.71, 0.15), Vector3.new(sign * 0.72, 4.95, -0.85), accent, nil, CFrame.Angles(0, 0, sign * 0.29))
			ball(model, "AntlerBloom", Vector3.new(0.66, 0.44, 0.52), Vector3.new(sign * 1.33, 4.8, -0.85), petal)
			ball(model, "BloomCenter", Vector3.new(0.22, 0.17, 0.16), Vector3.new(sign * 1.33, 4.9, -1.08), cream)
			for i = 1, 3 do
				ball(model, "Dapple", Vector3.new(0.07, 0.19, 0.26), Vector3.new(sign * 0.94, 1.91, i * 0.44), cream)
			end
		end
		face(model, 0.38, 3.23, -1.8, 0.22)
		ball(model, "Nose", Vector3.new(0.29, 0.2, 0.15), Vector3.new(0, 2.87, -2.2), accent)
		piece(model, "PetalTail", Vector3.new(0.55, 0.84, 0.46), Vector3.new(0, 2.05, 1.9), cream, Enum.PartType.Ball, CFrame.Angles(-0.4, 0, 0))
	else
		ball(model, "Body", Vector3.new(2, 2, 2), Vector3.new(0, 1, 0), color)
		face(model, 0.4, 1.3, -0.83, 0.2)
	end

	-- Eyebrows and small smiles turn a pose into an expression at phone scale.
	local front = species == "Bloomstag" and Vector3.new(0, 3.23, -1.8) or species == "Moonhare" and Vector3.new(0, 2.59, -1.14) or species == "Mistfox" and Vector3.new(0, 2.15, -1.25) or species == "Pebblehog" and Vector3.new(0, 1.39, -1.56) or species == "Lanternwing" and Vector3.new(0, 2.06, -0.48) or species == "Dewfin" and Vector3.new(0, 1.5, -1.05) or species == "Reedling" and Vector3.new(0, 1.83, -0.96) or Vector3.new(0, 1.77, -0.94)
	local eyeX = species == "Reedling" and 0.8 or species == "Bloomstag" and 0.38 or species == "Lanternwing" and 0.28 or 0.43
	for _, sign in ipairs({ -1, 1 }) do
		piece(model, "Brow", Vector3.new(0.24, 0.055, 0.065), front + Vector3.new(sign * eyeX, 0.2, 0.05), accent, Enum.PartType.Ball, CFrame.Angles(0, 0, sign * -0.10))
	end
	if species == "Mossbun" or species == "Moonhare" or species == "Mistfox" or species == "Pebblehog" then
		for _, sign in ipairs({ -1, 1 }) do
			piece(model, "Smile", Vector3.new(0.13, 0.055, 0.06), front + Vector3.new(sign * 0.06, -0.46, -0.13), Color3.fromRGB(58, 67, 53), Enum.PartType.Ball, CFrame.Angles(0, 0, sign * 0.35))
		end
	end
	annotate(model, species, false)
	model:SetAttribute("Variant", "Normal")
	root:SetAttribute("Variant", "Normal")
	return model
end

function CreatureVisual.ApplyVariant(config, model, variant)
	if not model or not model.PrimaryPart then return end
	local definition = config.Creatures[model:GetAttribute("Species")]
	if not definition then return end
	if variant ~= "Moonlit" and variant ~= "Golden" then variant = "Normal" end
	local previous = model:FindFirstChild("VariantDetails")
	if previous then previous:Destroy() end
	model:SetAttribute("Variant", variant)
	model.PrimaryPart:SetAttribute("Variant", variant)
	local variantDefinition = config.Variants and config.Variants[variant]
	local tint = variantDefinition and variantDefinition.Color or (variant == "Golden" and Color3.fromRGB(237, 187, 75) or Color3.fromRGB(181, 181, 234))
	local glow = variantDefinition and variantDefinition.Accent or (variant == "Golden" and Color3.fromRGB(255, 229, 133) or Color3.fromRGB(215, 232, 255))
	for _, detail in ipairs(model:GetDescendants()) do
		if detail:IsA("BasePart") then
			local natural = detail:GetAttribute("NaturalColor")
			if typeof(natural) == "Color3" then
				local primary = (natural.R - definition.Color.R)^2 + (natural.G - definition.Color.G)^2 + (natural.B - definition.Color.B)^2 < 0.0001
				local accent = (natural.R - definition.Accent.R)^2 + (natural.G - definition.Accent.G)^2 + (natural.B - definition.Accent.B)^2 < 0.0001
				detail.Color = (variant ~= "Normal" and (primary or accent)) and natural:Lerp(accent and glow or tint, accent and 0.78 or 0.62) or natural
			end
		end
	end
	if variant == "Normal" then return end
	local decoration = Instance.new("Folder")
	decoration.Name = "VariantDetails"
	decoration.Parent = model
	local scale = model:GetScale()
	local origin = model:GetPivot()
	-- Neon pearls provide an identifiable variant accent without dynamic lights.
	for _, side in ipairs({ -1, 1 }) do
		local spark = ball(decoration, "VariantPearl", Vector3.new(0.18, 0.2, 0.18) * scale, Vector3.zero, glow)
		spark.CFrame = origin * CFrame.new(Vector3.new(side * 0.51, 0.53, -1.07) * scale)
		spark.Material = Enum.Material.Neon
		spark.CastShadow = false
	end
	local emblem = piece(decoration, variant == "Golden" and "GoldenLeaf" or "MoonlitPetal", Vector3.new(0.38, 0.12, 0.55) * scale, Vector3.zero, glow, Enum.PartType.Ball)
	emblem.CFrame = origin * CFrame.new(Vector3.new(0, 0.32, -1.13) * scale) * CFrame.Angles(0, 0, 0.22)
	emblem.Material = Enum.Material.Neon
	emblem.CastShadow = false
	annotate(model, model:GetAttribute("Species"), true)
end

return CreatureVisual

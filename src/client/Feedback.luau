-- Local, asset-free feedback. This module never sends remotes or changes game state.
-- Discovery runs once a second; animation has a 30 Hz ceiling and explicit budgets.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Feedback = {}

local CREAM = Color3.fromRGB(255, 247, 221)
local INK = Color3.fromRGB(26, 49, 41)
local GOLD = Color3.fromRGB(242, 191, 91)
local MINT = Color3.fromRGB(163, 215, 155)

local function create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end

local function decorativePart(name, size, color, parent, shape)
	return create("Part", {
		Name = name, Size = size, Color = color, Anchored = true,
		CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
		Material = Enum.Material.SmoothPlastic, Shape = shape or Enum.PartType.Block,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
	}, parent)
end

local function positionOf(value)
	if typeof(value) == "Vector3" then return value end
	if typeof(value) == "CFrame" then return value.Position end
	if type(value) ~= "table" then return nil end
	if value.position then return positionOf(value.position) end
	local x, y, z = value.x or value.X or value[1], value.y or value.Y or value[2], value.z or value.Z or value[3]
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return nil end
	if x ~= x or y ~= y or z ~= z or math.abs(x) > 100000 or math.abs(y) > 100000 or math.abs(z) > 100000 then return nil end
	return Vector3.new(x, y, z)
end

local function samePivot(a, b)
	local _, angle = a:ToObjectSpace(b):ToAxisAngle()
	return (a.Position - b.Position).Magnitude < 0.005 and math.abs(angle) < 0.005
end

local function makeBillboard(name, anchor, size, height, parent)
	local billboard = create("BillboardGui", {
		Name = name, Adornee = anchor, Size = UDim2.fromOffset(size.X, size.Y),
		StudsOffsetWorldSpace = Vector3.new(0, height, 0), AlwaysOnTop = false,
		MaxDistance = 90, LightInfluence = 0, Enabled = false,
	}, parent)
	local body = create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK,
		BackgroundTransparency = 0.07, BorderSizePixel = 0,
	}, billboard)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, body)
	create("UIStroke", { Color = CREAM, Transparency = 0.75, Thickness = 1 }, body)
	local title = create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 4), Size = UDim2.new(1, -18, 0, 19),
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = CREAM,
		Text = "", TextXAlignment = Enum.TextXAlignment.Center,
	}, body)
	return billboard, body, title
end

local function makeHeart(parent)
	-- Three geometric pieces form the heart, independent of fonts or image assets.
	local holder = create("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1 }, parent)
	local lower = create("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(4, 5), Rotation = 45, BackgroundColor3 = MINT, BorderSizePixel = 0 }, holder)
	create("UICorner", { CornerRadius = UDim.new(0, 1) }, lower)
	for _, x in ipairs({ 1, 7 }) do
		local lobe = create("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(x, 2), BackgroundColor3 = MINT, BorderSizePixel = 0 }, holder)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, lobe)
	end
	return holder
end

function Feedback.Start(options)
	options = options or {}
	local player = options.Player or Players.LocalPlayer
	assert(player, "Feedback requires the local player")
	local config = options.Config or {}
	local gui = options.Gui
	local controller = {}
	local destroyed = false
	local connections, worldConnections = {}, {}
	local state, stateAt = nil, os.clock()
	local preferences = {
		ReducedMotion = player:GetAttribute("WildboundReducedMotion") == true,
		LowEffects = player:GetAttribute("WildboundLowEffects") == true,
		Muted = player:GetAttribute("WildboundMuted") == true,
	}
	local effects = create("Folder", { Name = "WildboundLocalFeedback_" .. player.UserId }, workspace)
	local world = nil
	local candidates, foliage = {}, {}
	local animations, swaying = {}, {}
	local modelById, lastPositions = {}, {}
	local bowls, bursts, weatherParts = {}, {}, {}
	local weatherKind, underRoof = "", false
	local nextRefresh, nextTick = 0, 0
	local time = os.clock()

	local marker = decorativePart("ObjectiveAnchor", Vector3.new(0.1, 0.1, 0.1), GOLD, effects)
	marker.Transparency = 1
	local waypointGui, waypointBody, waypointTitle = makeBillboard("TrailWaypoint", marker, Vector2.new(146, 33), 3.2, effects)
	waypointGui.MaxDistance = 350
	waypointTitle.Size = UDim2.new(1, -18, 1, -8)
	local trustGui, trustBody, trustTitle = makeBillboard("CreatureTrust", marker, Vector2.new(178, 57), 4.7, effects)
	trustTitle.Position = UDim2.fromOffset(28, 4)
	trustTitle.Size = UDim2.new(1, -34, 0, 19)
	makeHeart(trustBody)
	local trustNote = create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 24), Size = UDim2.new(1, -14, 0, 14), Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = CREAM, Text = "" }, trustBody)
	local trustTrack = create("Frame", { Position = UDim2.fromOffset(9, 44), Size = UDim2.new(1, -18, 0, 5), BackgroundColor3 = Color3.fromRGB(72, 90, 70), BorderSizePixel = 0 }, trustBody)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, trustTrack)
	local trustFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = MINT, BorderSizePixel = 0 }, trustTrack)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, trustFill)
	local trustHighlight = create("Highlight", { Name = "TrustedCreature", FillTransparency = 1, OutlineColor = MINT, OutlineTransparency = 0.18, DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false }, effects)
	local shutter, shutterLines, shutterEnds = nil, {}, 0
	if gui and gui:IsA("LayerCollector") then
		shutter = create("Frame", { Name = "PhotoFeedback", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.fromOffset(168, 112), BackgroundTransparency = 1, Visible = false, ZIndex = 6 }, gui)
		for _, corner in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
			for _, vertical in ipairs({ false, true }) do
				local line = create("Frame", {
					AnchorPoint = corner, Position = UDim2.fromScale(corner.X, corner.Y),
					Size = vertical and UDim2.fromOffset(2, 14) or UDim2.fromOffset(14, 2),
					BackgroundColor3 = CREAM, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 6,
				}, shutter)
				table.insert(shutterLines, line)
			end
		end
	end

	local function characterRoot()
		local character = player.Character
		return character and character:FindFirstChild("HumanoidRootPart")
	end

	local function eligible(model)
		if not world or not model.Parent or not model:IsDescendantOf(world) or not model.PrimaryPart then return false end
		if not model:GetAttribute("EntityId") then return false end
		local owner = model:GetAttribute("TutorialOwnerId")
		if owner and owner ~= player.UserId then return false end
		if model:GetAttribute("CompanionOwnerUserId") or model:GetAttribute("CreatureUid") or model:GetAttribute("Reserved") or model:GetAttribute("RaidReserved") then return false end
		return not model:GetAttribute("WildboundHidden") and not model.PrimaryPart:GetAttribute("WildboundHidden")
	end

	local function restoreModel(record)
		local model = record.model
		if not model.Parent then return end
		-- A server relocation always wins over our previous cosmetic transform.
		if record.applied and samePivot(model:GetPivot(), record.applied) then
			model:PivotTo(record.base)
			for _, detail in ipairs(record.details) do
				if detail.part.Parent then detail.part.CFrame = record.base * detail.localCFrame end
			end
		end
	end

	local function stopAnimation()
		for model, record in pairs(animations) do restoreModel(record); animations[model] = nil end
		for part, record in pairs(swaying) do
			if part.Parent and record.applied and samePivot(part.CFrame, record.applied) then part.CFrame = record.base end
			swaying[part] = nil
		end
	end

	local function removeBowl(id)
		local bowl = bowls[id]
		if bowl then bowl.model:Destroy(); bowls[id] = nil end
	end

	local function clearWeather()
		for _, part in ipairs(weatherParts) do part:Destroy() end
		table.clear(weatherParts)
		weatherKind = ""
	end

	local function scanCandidate(object)
		if object:IsA("Model") and (object:GetAttribute("EntityId") or object.Parent and object.Parent.Name == "Creatures") then candidates[object] = true end
		if object:IsA("BasePart") and not object.CanCollide and object.Anchored and object:GetAttribute("WindFoliage") == true then
			-- Foliage has explicit world metadata. A petal-shaped creature detail
			-- must never join the independent foliage animation loop.
			local ancestor = object.Parent
			while ancestor and ancestor ~= world do
				if ancestor:GetAttribute("Species") or ancestor:GetAttribute("EntityId") or ancestor:GetAttribute("CreatureUid") or ancestor:GetAttribute("CompanionOwnerUserId") then return end
				ancestor = ancestor.Parent
			end
			foliage[object] = true
		end
	end

	local function attachWorld(root)
		for _, connection in ipairs(worldConnections) do connection:Disconnect() end
		table.clear(worldConnections)
		stopAnimation()
		for id in pairs(bowls) do removeBowl(id) end
		table.clear(candidates); table.clear(foliage); table.clear(modelById)
		world = root
		if not root then return end
		for _, object in ipairs(root:GetDescendants()) do scanCandidate(object) end
		table.insert(worldConnections, root.DescendantAdded:Connect(scanCandidate))
		table.insert(worldConnections, root.DescendantRemoving:Connect(function(object)
			candidates[object] = nil; foliage[object] = nil
		end))
		nextRefresh = 0
	end

	local function makeAnimation(model, index)
		local base = model:GetPivot()
		local record = { model = model, base = base, applied = nil, phase = index * 1.71, details = {} }
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") and part ~= model.PrimaryPart then
				local name = part.Name
				local kind = string.find(name, "Wing", 1, true) and "wing" or string.find(name, "Ear", 1, true) and "ear" or string.find(name, "Fin", 1, true) and "fin" or string.find(name, "Tail", 1, true) and "tail" or name == "Head" and "head" or nil
				if kind then table.insert(record.details, { part = part, kind = kind, localCFrame = base:ToObjectSpace(part.CFrame) }) end
			end
		end
		return record
	end

	local function refreshNearest(rootPart)
		local origin = rootPart.Position
		local nearest, leaves = {}, {}
		table.clear(modelById)
		for model in pairs(candidates) do
			if not model.Parent then candidates[model] = nil
			elseif eligible(model) then
				local distance = (model.PrimaryPart.Position - origin).Magnitude
				local id = model:GetAttribute("EntityId")
				modelById[id] = model
				lastPositions[model:GetAttribute("Species") or ""] = model.PrimaryPart.Position
				if distance <= 76 then table.insert(nearest, { model = model, distance = distance }) end
			end
		end
		table.sort(nearest, function(a, b) return a.distance < b.distance end)
		local kept = {}
		local creatureBudget = preferences.LowEffects and 6 or 12
		if not preferences.ReducedMotion then
			for index = 1, math.min(creatureBudget, #nearest) do
				local model = nearest[index].model
				kept[model] = true
				if not animations[model] then animations[model] = makeAnimation(model, index) end
			end
		end
		for model, record in pairs(animations) do
			if not kept[model] then restoreModel(record); animations[model] = nil end
		end
		if not preferences.ReducedMotion then
			for part in pairs(foliage) do
				if not part.Parent then foliage[part] = nil
			elseif (part.Position - origin).Magnitude < 52 then table.insert(leaves, { part = part, distance = (part.Position - origin).Magnitude, tagged = part:GetAttribute("WindFoliage") == true }) end
			end
		end
		table.sort(leaves, function(a, b)
			if a.tagged ~= b.tagged then return a.tagged end
			return a.distance < b.distance
		end)
		table.clear(kept)
		for index = 1, math.min(preferences.LowEffects and 4 or 12, #leaves) do
			local part = leaves[index].part
			kept[part] = true
			if not swaying[part] then swaying[part] = { base = part.CFrame, phase = part:GetAttribute("WindPhase") or index * 0.63 } end
		end
		for part, record in pairs(swaying) do
			if not kept[part] then
				if part.Parent and record.applied and samePivot(part.CFrame, record.applied) then part.CFrame = record.base end
				swaying[part] = nil
			end
		end
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Exclude
		filter.FilterDescendantsInstances = { player.Character, effects }
		local ceiling = workspace:Raycast(origin + Vector3.new(0, 2, 0), Vector3.new(0, 18, 0), filter)
		underRoof = ceiling ~= nil
	end

	local function spawnBowl(id, model)
		local holder = create("Model", { Name = "OfferedSnack" }, effects)
		local origin = model.PrimaryPart.Position + Vector3.new(1.15, 0.09, -0.9)
		local bowl = decorativePart("SnackBowl", Vector3.new(0.13, 0.88, 0.88), CREAM, holder, Enum.PartType.Cylinder)
		bowl.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.pi / 2)
		local species = model:GetAttribute("Species")
		local snack = config.Creatures and config.Creatures[species] and config.Creatures[species].Snack or "Berry"
		for index = 1, 3 do
			local morsel = decorativePart("Offered" .. snack, Vector3.new(0.24, snack == "Seed" and 0.13 or 0.24, 0.24), snack == "Seed" and GOLD or Color3.fromRGB(192, 80, 104), holder, Enum.PartType.Ball)
			morsel.Position = origin + Vector3.new((index - 2) * 0.19, 0.17, index == 2 and -0.11 or 0.07)
		end
		bowls[id] = { model = holder, creature = model }
	end

	local function burstAt(position, color)
		if not position then return end
		-- One shared budget prevents overlapping celebrations from producing VFX storms.
		local limit = preferences.ReducedMotion and 3 or preferences.LowEffects and 5 or 12
		for index = 1, math.max(0, limit - #bursts) do
			local angle = index * math.pi * 2 / limit
			local part = decorativePart("FriendshipSpark", Vector3.new(0.12, 0.12, 0.12), index % 3 == 0 and CREAM or color, effects, index % 2 == 0 and Enum.PartType.Ball or Enum.PartType.Block)
			part.Material = Enum.Material.Neon
			local direction = Vector3.new(math.cos(angle), 0.6 + index % 3 * 0.2, math.sin(angle))
			part.Position = position + Vector3.new(0, 1.7, 0) + direction * 0.65
			table.insert(bursts, { part = part, origin = part.Position, velocity = direction * 2.8, born = os.clock(), lifetime = preferences.ReducedMotion and 0.35 or 0.85 })
		end
	end

	local function photoFeedback()
		if shutter then shutterEnds = os.clock() + 0.28; shutter.Visible = true end
	end

	local function animateCreatures()
		for model, record in pairs(animations) do
			if not eligible(model) then restoreModel(record); animations[model] = nil
			else
				local current = model:GetPivot()
				if record.applied and not samePivot(current, record.applied) then
					-- A replicated transform changed: recapture the authoritative pose.
					record.base = current
				end
				local phase = time * 2 + record.phase
				local localLure = state and state.lures and state.lures[model:GetAttribute("EntityId")]
				local curious = localLure ~= nil
				local float = model:GetAttribute("Species") == "Lanternwing" or model:GetAttribute("Species") == "Dewfin"
				-- The interaction root stays within 0.12 studs of its replicated position.
				local height = math.sin(phase) * (float and 0.085 or 0.025)
				local yaw = math.sin(phase * 0.5) * 0.014
				local transform = record.base * CFrame.new(curious and math.sin(phase * 0.65) * 0.045 or 0, height, 0) * CFrame.Angles(0, yaw, 0)
				model:PivotTo(transform)
				for _, detail in ipairs(record.details) do
					if detail.part.Parent then
						local sign = detail.localCFrame.Position.X < 0 and -1 or 1
						local rotation = CFrame.new()
						if detail.kind == "wing" then rotation = CFrame.Angles(0, math.sin(phase * 3.5) * 0.065 * sign, 0)
						elseif detail.kind == "ear" then rotation = CFrame.Angles(0.018 * math.sin(phase * 0.7), 0, sign * 0.028 * math.sin(phase * 1.3))
						elseif detail.kind == "fin" then rotation = CFrame.Angles(math.sin(phase * 1.8) * 0.035, 0, 0)
						elseif detail.kind == "tail" then rotation = CFrame.Angles(0, math.sin(phase * 0.9) * 0.045, 0)
						elseif detail.kind == "head" then rotation = CFrame.Angles(0, 0, math.sin(phase * 0.5) * 0.014) end
						detail.part.CFrame = transform * detail.localCFrame * rotation
					end
				end
				record.applied = transform
			end
		end
		for part, record in pairs(swaying) do
			if not part.Parent then swaying[part] = nil
			else
				if record.applied and not samePivot(part.CFrame, record.applied) then record.base = part.CFrame end
				record.applied = record.base * CFrame.Angles(math.sin(time * 1.4 + record.phase) * 0.018, 0, math.sin(time * 1.1 + record.phase) * 0.014)
				part.CFrame = record.applied
			end
		end
	end

	local function updateTrust(rootPart)
		local closest, closestLure, distance = nil, nil, 30
		local lures = state and state.lures or {}
		local elapsed = time - stateAt
		local count, keptBowls = 0, {}
		for id, lure in pairs(lures) do
			local model = modelById[id]
			if type(lure) == "table" and model and eligible(model) and (lure.expiresIn or 0) > elapsed then
				local range = (model.PrimaryPart.Position - rootPart.Position).Magnitude
				if range < distance then closest, closestLure, distance = model, lure, range end
				if range < 45 and count < 4 then
					count += 1
					keptBowls[id] = true
					if not bowls[id] then spawnBowl(id, model) end
				end
			end
		end
		for id, bowl in pairs(bowls) do
			local lure = lures[id]
			if not keptBowls[id] or not lure or not eligible(bowl.creature) or (lure.expiresIn or 0) <= elapsed then removeBowl(id) end
		end
		trustGui.Enabled = closest ~= nil
		trustHighlight.Enabled = closest ~= nil
		if closest then
			if trustGui.Adornee ~= closest.PrimaryPart then trustGui.StudsOffsetWorldSpace = Vector3.new(0, math.max(4.7, closest:GetExtentsSize().Y + 0.8), 0) end
			trustGui.Adornee = closest.PrimaryPart
			trustHighlight.Adornee = closest
			local remaining = math.max(0, (closestLure.readyIn or 0) - elapsed)
			local progress = math.clamp(type(closestLure.trust) == "number" and closestLure.trust or 0, 0, 1)
			local percent = math.floor(progress * 100 + 0.5)
			trustTitle.Text = remaining > 0 and "CURIOUS · " .. math.ceil(remaining) .. "s" or "TRUST " .. percent .. "%"
			local chance = type(closestLure.chance) == "number" and math.floor(math.clamp(closestLure.chance, 0, 1) * 100 + 0.5) or nil
			local sneaking = player:GetAttribute("Sneaking") == true
			trustNote.Text = remaining > 0 and "Let the snack settle." or not sneaking and "Hold Sneak nearby to build trust." or chance and "Befriend · " .. chance .. "% catch chance" or "Stay close and befriend gently."
			-- Trust is authoritative; the snack timer never fabricates trust gains.
			trustFill.Size = UDim2.fromScale(progress, 1)
			trustFill.BackgroundColor3 = remaining > 0 and GOLD or MINT
		else trustHighlight.Adornee = nil end
	end

	local function updateWaypoint(rootPart)
		local objective = state and (state.objective or state.questline or state.quest) or nil
		local position = objective and positionOf(objective.waypoint) or nil
		if not position and state and state.questline then position = positionOf(state.questline.waypoint) end
		if not position and state and state.quest then position = positionOf(state.quest.waypoint) end
		waypointGui.Enabled = position ~= nil and state ~= nil and state.raid == nil and not (objective and objective.complete)
		if position then
			marker.Position = position + Vector3.new(0, 0.25, 0)
			local distance = math.floor((rootPart.Position - position).Magnitude + 0.5)
			waypointTitle.Text = distance < 6 and "YOUR NEXT DISCOVERY" or "TRAIL GOAL · " .. distance .. " studs"
			waypointBody.BackgroundColor3 = distance < 6 and Color3.fromRGB(47, 83, 56) or INK
		end
	end

	local function updateWeather(rootPart)
		local kind = state and state.weather or world and world:GetAttribute("Weather") or "Clear"
		if preferences.ReducedMotion then kind = "Clear" end
		local key = kind .. (preferences.LowEffects and "_low" or "_full")
		if weatherKind ~= key then
			clearWeather(); weatherKind = key
			local count = kind == "Rain" and (preferences.LowEffects and 4 or 12) or kind == "Dusk" and (preferences.LowEffects and 2 or 6) or kind == "Fog" and (preferences.LowEffects and 0 or 4) or 0
			for index = 1, count do
				local size = kind == "Rain" and Vector3.new(0.025, 1.0, 0.025) or kind == "Fog" and Vector3.new(5, 0.6, 4) or Vector3.new(0.1, 0.1, 0.1)
				local part = decorativePart("Weather" .. kind, size, kind == "Dusk" and GOLD or CREAM, effects, kind == "Rain" and Enum.PartType.Block or Enum.PartType.Ball)
				part.Material = kind == "Dusk" and Enum.Material.Neon or Enum.Material.SmoothPlastic
				table.insert(weatherParts, part)
			end
		end
		local origin = rootPart.Position
		for index, part in ipairs(weatherParts) do
			local phase = index * 2.399
			if kind == "Rain" then
				local descent = (time * 16 + index * 3.17) % 11
				part.CFrame = CFrame.new(origin + Vector3.new(math.sin(phase) * 14 + 0.3 * descent, 10 - descent, math.cos(phase) * 14)) * CFrame.Angles(0, 0, 0.12)
				part.Transparency = underRoof and 1 or 0.6
			elseif kind == "Dusk" then
				part.Position = origin + Vector3.new(math.sin(phase + time * 0.18) * 11, -1.3 + math.sin(time * 0.5 + phase) * 1.2, math.cos(phase + time * 0.21) * 11)
				part.Transparency = 0.2 + (math.sin(time * 1.5 + phase) + 1) * 0.25
			elseif kind == "Fog" then
				part.Position = origin + Vector3.new(math.sin(phase + time * 0.04) * 14, -2.1 + math.sin(time * 0.2 + phase) * 0.2, math.cos(phase + time * 0.06) * 14)
				part.Transparency = 0.94
			end
		end
	end

	function controller:OnState(snapshot)
		if destroyed or type(snapshot) ~= "table" then return end
		state, stateAt = snapshot, os.clock()
		nextRefresh = 0
	end

	function controller:OnMessage(message)
		if destroyed or type(message) ~= "table" then return end
		if message.kind == "Capture" then
			local definition = config.Creatures and config.Creatures[message.species]
			local rootPart = characterRoot()
			local position = positionOf(message.position) or lastPositions[message.species]
			if rootPart and (not position or (position - rootPart.Position).Magnitude > 32) then position = rootPart.Position + rootPart.CFrame.LookVector * 3 end
			burstAt(position, definition and definition.Accent or GOLD)
		elseif message.kind == "Photo" or message.kind == "Toast" and message.title == "Clue photographed" then photoFeedback()
		elseif message.kind == "Lure" then nextRefresh = 0 end
	end

	function controller:SetOptions(settings)
		if destroyed or type(settings) ~= "table" then return end
		for _, key in ipairs({ "ReducedMotion", "LowEffects", "Muted" }) do
			if type(settings[key]) == "boolean" then preferences[key] = settings[key] end
		end
		if preferences.ReducedMotion then stopAnimation() end
		clearWeather(); nextRefresh = 0
		-- No audio is created without a verified, game-owned audio asset.
	end

	function controller:Destroy()
		if destroyed then return end
		destroyed = true
		for _, connection in ipairs(connections) do connection:Disconnect() end
		for _, connection in ipairs(worldConnections) do connection:Disconnect() end
		stopAnimation()
		if shutter then shutter:Destroy() end
		effects:Destroy()
		table.clear(bowls); table.clear(bursts); table.clear(weatherParts)
	end

	table.insert(connections, workspace.ChildAdded:Connect(function(object)
		if object.Name == "WildboundWorld" then attachWorld(object) end
	end))
	table.insert(connections, workspace.ChildRemoved:Connect(function(object)
		if object == world then attachWorld(nil); trustGui.Enabled = false; waypointGui.Enabled = false end
	end))
	table.insert(connections, player.CharacterAdded:Connect(function()
		stopAnimation(); clearWeather()
		for id in pairs(bowls) do removeBowl(id) end
		trustGui.Enabled = false; waypointGui.Enabled = false; nextRefresh = 0
	end))
	for _, key in ipairs({ "ReducedMotion", "LowEffects", "Muted" }) do
		table.insert(connections, player:GetAttributeChangedSignal("Wildbound" .. key):Connect(function()
			controller:SetOptions({ [key] = player:GetAttribute("Wildbound" .. key) == true })
		end))
	end
	if gui then table.insert(connections, gui.Destroying:Connect(function() controller:Destroy() end)) end
	attachWorld(workspace:FindFirstChild("WildboundWorld"))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		if destroyed then return end
		local now = os.clock()
		if now < nextTick then return end
		nextTick, time = now + 1 / 30, now
		local rootPart = characterRoot()
		if rootPart then
			if now >= nextRefresh then nextRefresh = now + 1; refreshNearest(rootPart) end
			if not preferences.ReducedMotion then animateCreatures() end
			updateTrust(rootPart); updateWaypoint(rootPart); updateWeather(rootPart)
		else
			trustGui.Enabled = false; waypointGui.Enabled = false; trustHighlight.Enabled = false
			for _, part in ipairs(weatherParts) do part.Transparency = 1 end
		end
		for index = #bursts, 1, -1 do
			local burst = bursts[index]
			local age = now - burst.born
			if age >= burst.lifetime then burst.part:Destroy(); table.remove(bursts, index)
			else
				burst.part.Transparency = math.clamp(age / burst.lifetime, 0, 1)
				if not preferences.ReducedMotion then burst.part.Position = burst.origin + burst.velocity * age - Vector3.new(0, age * age * 1.2, 0) end
			end
		end
		if shutter and shutter.Visible then
			local remaining = shutterEnds - now
			if remaining <= 0 then shutter.Visible = false
			else
				for _, line in ipairs(shutterLines) do line.BackgroundTransparency = remaining > 0.2 and 0.1 or 1 - remaining / 0.2 * 0.9 end
			end
		end
	end))
	return controller
end

return Feedback

-- Joint-group procedural animation. Pose is pure numeric math and can run in
-- headless tests; Apply only poses decorative child parts, never the root.
local CreatureMotion = {}

local function finite(value, fallback)
	return type(value) == "number" and value == value and math.abs(value) < 10000000 and value or fallback
end

local function transform(x, y, z, rx, ry, rz)
	return { x = x or 0, y = y or 0, z = z or 0, rx = rx or 0, ry = ry or 0, rz = rz or 0 }
end

function CreatureMotion.Pose(species, timeSeconds, state, phaseOffset)
	state = type(state) == "table" and state or {}
	local clock = finite(timeSeconds, 0) + finite(phaseOffset, 0)
	local speed = math.clamp(finite(state.speed, 0), 0, 18)
	local gait = math.clamp(speed / 4, 0, 1)
	local mood = string.lower(type(state.mood) == "string" and state.mood or "idle")
	local reduced = state.reducedMotion == true
	local idle = reduced and 0 or 1
	local curious = mood == "curious" or mood == "eating"
	local happy = mood == "happy" or mood == "capture" or mood == "bond"
	local startled = mood == "startled"
	local stateAge = math.max(0, finite(state.age, 999))
	local recoil = startled and math.max(0, 1 - stateAge / 0.8) or 0
	local breathing = math.sin(clock * 2.15) * 0.024 * idle
	local trust = math.clamp(finite(state.trust, 0), 0, 1)
	local sniff = curious and math.sin(clock * 6) * (reduced and 0.025 or 0.08) * (1 - trust * 0.6) or 0
	local look = math.sin(clock * 0.77) * 0.10 * idle
	local bounce = happy and math.max(0, math.sin(clock * 8)) * (reduced and 0.04 or 0.18) or 0
	local stride = clock * (4.5 + gait * 4)
	local step = math.sin(stride) * gait
	local pose = {
		Body = transform(0, breathing + bounce + recoil * 0.12, recoil * 0.08, recoil * -0.13, 0, step * 0.035),
		Head = transform(0, 0, 0, sniff + (curious and 0.09 or 0), look, math.sin(clock * 0.53) * 0.024 * idle),
		EarL = transform(0, 0, 0, math.sin(clock * 1.8) * 0.08 * idle, 0, (happy and -0.08 or 0) + recoil * -0.26),
		EarR = transform(0, 0, 0, math.sin(clock * 1.8 + 1) * 0.08 * idle, 0, (happy and 0.08 or 0) + recoil * 0.26),
		Tail = transform(0, 0, 0, 0, math.sin(clock * (happy and 7 or 2.4)) * (happy and 0.42 or 0.16) * idle, 0),
		LegLF = transform(0, 0, 0, step * 0.38, 0, 0),
		LegRF = transform(0, 0, 0, -step * 0.38, 0, 0),
		LegLR = transform(0, 0, 0, -step * 0.38, 0, 0),
		LegRR = transform(0, 0, 0, step * 0.38, 0, 0),
		ArmL = transform(0, 0, 0, (curious and -0.18 or 0) + step * 0.13, 0, math.sin(clock * 2) * 0.025 * idle),
		ArmR = transform(0, 0, 0, (curious and -0.18 or 0) - step * 0.13, 0, -math.sin(clock * 2) * 0.025 * idle),
		Crest = transform(0, 0, 0, math.sin(clock * 1.7) * 0.055 * idle, 0, math.sin(clock * 1.3) * 0.04 * idle),
	}

	if species == "Mossbun" or species == "Moonhare" then
		local hopping = gait > 0 and gait or (happy and 0.6 or 0)
		local hopPhase = (clock * (species == "Moonhare" and 1.95 or 1.6)) % 1
		local hop = math.max(0, math.sin(hopPhase * math.pi))
		pose.Body.y += hop * hopping * (reduced and 0.07 or 0.48)
		pose.Body.rx += math.sin(hopPhase * math.pi * 2) * hopping * 0.10
		pose.LegLF.rx = -hop * hopping * 0.48
		pose.LegRF.rx = pose.LegLF.rx
		pose.LegLR.rx = hop * hopping * 0.35
		pose.LegRR.rx = pose.LegLR.rx
		pose.EarL.rx += -hop * hopping * 0.19
		pose.EarR.rx += -hop * hopping * 0.19
		if species == "Moonhare" then pose.EarL.rz -= 0.025 * idle; pose.EarR.rz += 0.025 * idle end
	elseif species == "Lanternwing" then
		pose.Body.y += math.sin(clock * 3.4) * 0.10 * idle + gait * 0.12
		pose.Body.rx += gait * -0.08
		local flap = math.sin(clock * (11 + gait * 5)) * (reduced and gait * 0.18 or 0.64)
		pose.WingL = transform(0, 0, 0, 0, flap, math.sin(clock * 2) * 0.035 * idle)
		pose.WingR = transform(0, 0, 0, 0, -flap, -math.sin(clock * 2) * 0.035 * idle)
		pose.Head.rx += curious and 0.12 or 0
	elseif species == "Pebblehog" then
		pose.Body.y += math.abs(step) * 0.045
		pose.Head.rx += (curious and 0.16 or 0.05 * idle) + math.sin(clock * 3.2) * 0.045 * idle
		pose.Head.z = curious and -0.045 or 0
		pose.Tail.ry *= 0.25
	elseif species == "Dewfin" then
		pose.Body.y += (0.07 + math.sin(clock * 2.9) * 0.12) * idle
		pose.Body.rz += math.sin(clock * 2.2) * 0.055 * idle
		local fin = math.sin(clock * (5 + gait * 5)) * (reduced and gait * 0.1 or 0.28)
		pose.FinL = transform(0, 0, 0, fin * 0.25, 0, fin)
		pose.FinR = transform(0, 0, 0, fin * 0.25, 0, -fin)
		pose.Tail.ry = math.sin(clock * (4 + gait * 4)) * (reduced and gait * 0.12 or 0.32)
	elseif species == "Mistfox" then
		pose.Body.rx += gait * -0.02
		pose.Head.ry *= 1.7
		pose.Head.rx += curious and 0.10 or 0
		pose.Tail.ry = math.sin(clock * (happy and 8 or 2.6)) * (happy and 0.58 or 0.28) * idle + step * 0.12
	elseif species == "Reedling" then
		local leap = math.max(0, math.sin(stride * 0.65)) * gait
		pose.Body.y += leap * (reduced and 0.06 or 0.29)
		pose.Body.rx += leap * -0.11
		pose.LegLF.rx = -leap * 0.32; pose.LegRF.rx = -leap * 0.32
		pose.LegLR.rx = leap * 0.35; pose.LegRR.rx = leap * 0.35
		pose.Crest.rx += -leap * 0.18
	elseif species == "Bloomstag" then
		pose.Body.y += math.abs(step) * 0.07
		pose.Body.rz *= 0.5
		pose.Head.rx += curious and 0.26 or math.sin(clock * 0.8) * 0.045 * idle
		pose.Head.ry *= 0.65
		pose.Tail.rx = math.sin(clock * 2.5) * 0.10 * idle
	end

	-- Blink includes the glints and is offset per individual. Eyes retain their
	-- native dimensions when motion is reduced; no continuous hidden eye jitter.
	local blinkPhase = (clock + 1.37) % 4.6
	local blink = not reduced and blinkPhase < 0.16 and math.sin(blinkPhase / 0.16 * math.pi) or 0
	pose.EyeL = transform(); pose.EyeR = transform()
	pose.EyeL.scaleY = 1 - blink * 0.94
	pose.EyeR.scaleY = pose.EyeL.scaleY
	return pose
end

local function scaledFrame(value, scale)
	return CFrame.new(value.Position * scale) * value.Rotation
end

function CreatureMotion.Bind(model)
	if not model or not model.PrimaryPart then return nil end
	local record = { model = model, parts = {}, groups = {}, species = model:GetAttribute("Species"), phase = model:GetAttribute("AnimationPhase") or 0 }
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= model.PrimaryPart then
			local name = part:GetAttribute("AnimationGroup") or "Body"
			local parent = part:GetAttribute("AnimationParent") or (name ~= "Body" and "Body" or "")
			local pivot = part:GetAttribute("AnimationPivot") or Vector3.zero
			local rest = part:GetAttribute("RestCFrame")
			local size = part:GetAttribute("RestSize")
			local scale = model:GetScale()
			if typeof(rest) ~= "CFrame" then
				local localFrame = model.PrimaryPart.CFrame:ToObjectSpace(part.CFrame)
				rest = scaledFrame(localFrame, 1 / scale)
			end
			if typeof(size) ~= "Vector3" then size = part.Size / scale end
			record.groups[name] = { parent = parent, pivot = pivot }
			table.insert(record.parts, { part = part, group = name, rest = rest, size = size, transparency = part.Transparency, glint = part.Name == "EyeGlint", eye = part:GetAttribute("EyePart") == true })
		end
	end
	return record
end

function CreatureMotion.Apply(record, timeSeconds, state, phaseOffset)
	local model = record and record.model
	if not model or not model.Parent or not model.PrimaryPart then return end
	local scale = model:GetScale()
	local rootFrame = model.PrimaryPart.CFrame
	local pose = CreatureMotion.Pose(record.species, timeSeconds, state, phaseOffset or record.phase)
	local transforms = { [""] = CFrame.new() }
	local resolving = {}
	local function groupFrame(name)
		if transforms[name] then return transforms[name] end
		if resolving[name] then return CFrame.new() end
		resolving[name] = true
		local group = record.groups[name] or { parent = name == "Body" and "" or "Body", pivot = Vector3.zero }
		local p = pose[name] or transform()
		local pivot = group.pivot * scale
		local frame = groupFrame(group.parent) * CFrame.new(pivot) * CFrame.new(p.x * scale, p.y * scale, p.z * scale) * CFrame.Angles(p.rx, p.ry, p.rz) * CFrame.new(-pivot)
		resolving[name] = nil
		transforms[name] = frame
		return frame
	end
	for _, detail in ipairs(record.parts) do
		if detail.part.Parent then
			detail.part.CFrame = rootFrame * groupFrame(detail.group) * scaledFrame(detail.rest, scale)
			if detail.eye then
				local factor = pose[detail.group] and pose[detail.group].scaleY or 1
				detail.part.Size = detail.size * Vector3.new(scale, scale * factor, scale)
				if detail.glint then detail.part.Transparency = factor < 0.45 and 1 or detail.transparency end
			end
		end
	end
end

function CreatureMotion.Reset(record)
	local model = record and record.model
	if not model or not model.Parent or not model.PrimaryPart then return end
	local scale, rootFrame = model:GetScale(), model.PrimaryPart.CFrame
	for _, detail in ipairs(record.parts) do
		if detail.part.Parent then
			detail.part.CFrame = rootFrame * scaledFrame(detail.rest, scale)
			if detail.eye then detail.part.Size = detail.size * scale; detail.part.Transparency = detail.transparency end
		end
	end
end

return CreatureMotion

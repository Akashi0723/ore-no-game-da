--!strict
-- Development-only raids. Production ownership transfers require a durable,
-- cross-profile transaction journal before any paid attempts can be enabled.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RaidService = {}

type Raid = {
	id: number,
	thief: Player,
	owner: Player,
	thiefProfile: any,
	ownerProfile: any,
	uid: string,
	species: string,
	phase: string,
	phaseStarted: number,
	deadline: number,
	hits: number,
	lastPublished: number,
	marker: Highlight?,
	label: BillboardGui?,
	carried: Model?,
	character: Model,
}

local function alive(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character or player.Parent ~= Players then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function findEntry(profile: any, uid: string): (any?, number?)
	if not profile or type(profile.creatures) ~= "table" then
		return nil, nil
	end
	for index, entry in ipairs(profile.creatures) do
		if entry.uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

local function positionData(position: Vector3): any
	return { x = position.X, y = position.Y, z = position.Z }
end

function RaidService.Start(Config: any, service: any, _remotes: any): any
	local settings = Config.Raid or {}
	local enabled = RunService:IsStudio() and settings.StudioFree == true
		and not (Config.Persistence and Config.Persistence.EnableInStudio == true)
	local stealSeconds = math.max(1, settings.StealSeconds or 6)
	local chaseSeconds = math.max(1, settings.ChaseSeconds or 60)
	local escapeSeconds = math.max(10, settings.EscapeSeconds or 90)
	local netHits = math.max(1, settings.NetHits or 3)
	local netRange = math.clamp(settings.NetRange or 12, 1, 20)
	local netCooldown = math.max(0.5, settings.NetCooldown or 1.5)
	local stealRange = math.clamp(settings.StealRange or 12, 1, 20)
	local extractionRange = math.clamp(settings.ExtractionRange or 14, 1, 20)
	local attemptCooldown = math.max(5, settings.AttemptCooldown or 12)
	local bounds = Config.PlayableBounds or {
		MinX = -73, MaxX = 173, MinZ = -155, MaxZ = 87, MinY = -15, MaxY = 70,
	}
	local raids: { [number]: Raid } = {}
	local byPlayer: { [Player]: Raid } = {}
	local reservations: { [string]: Raid } = {}
	local lastAttempt: { [Player]: number } = {}
	local lastNet: { [Player]: number } = {}
	local playerConnections: { [Player]: { RBXScriptConnection } } = {}
	local deathConnections: { [Player]: RBXScriptConnection } = {}
	local heartbeat: RBXScriptConnection? = nil
	local running = true
	local sequence = 0
	service.RaidStates = service.RaidStates or {}
	service.RaidConfiguration = {
		enabled = enabled,
		developmentOnly = true,
		paidEnabled = false,
		status = if enabled then "Studio raid test · no Robux" else "Paid raids are unavailable in this build.",
	}

	local function toast(player: Player, title: string, message: string, tone: string?)
		if player.Parent == Players then
			service.Toast(player, title, message, tone or "info")
		end
	end

	local function inPlayableArea(position: Vector3): boolean
		return position.X >= bounds.MinX and position.X <= bounds.MaxX
			and position.Z >= bounds.MinZ and position.Z <= bounds.MaxZ
			and position.Y >= bounds.MinY and position.Y <= bounds.MaxY
	end

	local function findDisplay(owner: Player, uid: string): BasePart?
		local root = service.World.Root
		if not root or not root.Parent then
			return nil
		end
		local fallback: BasePart? = nil
		for _, instance in ipairs(root:GetDescendants()) do
			if instance:IsA("BasePart")
				and instance:GetAttribute("OwnerUserId") == owner.UserId
				and instance:GetAttribute("CreatureUid") == uid
			then
				-- Prefer the stable pedestal over its cosmetic creature PrimaryPart.
				if instance:GetAttribute("DisplayActive") == true then
					return instance
				end
				fallback = fallback or instance
			end
		end
		return fallback
	end

	local function hasLineOfSight(from: BasePart, to: BasePart, ignoreCharacter: Model?, characterTarget: boolean?): boolean
		local direction = to.Position - from.Position
		if direction.Magnitude < 0.01 then
			return true
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if ignoreCharacter then { ignoreCharacter } else {}
		local hit = workspace:Raycast(from.Position, direction, params)
		if not hit then
			return true
		end
		if hit.Instance == to or hit.Instance:IsDescendantOf(to) then
			return true
		end
		-- Display decorations are descendants of the pedestal. Never accept a
		-- fence/sign elsewhere in that sanctuary as a clear path to the pedestal.
		local targetModel = to:FindFirstAncestorOfClass("Model")
		if not targetModel or targetModel == service.World.Root then
			return false
		end
		local sameCreature = to:GetAttribute("CreatureUid") ~= nil
			and targetModel:GetAttribute("CreatureUid") == to:GetAttribute("CreatureUid")
		return (characterTarget == true or sameCreature) and hit.Instance:IsDescendantOf(targetModel)
	end

	local function publish(raid: Raid)
		local now = os.clock()
		local extraction = service.World.Extraction
		local definition = Config.Creatures[raid.species]
		for _, player in ipairs({ raid.thief, raid.owner }) do
			local opponent = if player == raid.thief then raid.owner else raid.thief
			local opponentRoot = alive(opponent)
			service.RaidStates[player] = {
				role = if player == raid.thief then "thief" else "defender",
				phase = raid.phase,
				creature = raid.species,
				creatureUid = raid.uid,
				creatureName = if definition then definition.Name else raid.species,
				opponentUserId = opponent.UserId,
				opponentName = opponent.DisplayName,
				opponentPosition = if opponentRoot then positionData(opponentRoot.Position) else nil,
				remaining = math.max(0, math.ceil(raid.deadline - now)),
				netHits = raid.hits,
				netHitsRequired = netHits,
				developmentOnly = true,
				extraction = if extraction then positionData(extraction.Position) else nil,
			}
			if service.Profiles[player] and player.Parent == Players then
				service.SendState(player)
			end
		end
		raid.lastPublished = now
	end

	local function release(raid: Raid)
		raids[raid.id] = nil
		reservations[tostring(raid.owner.UserId) .. ":" .. raid.uid] = nil
		for _, player in ipairs({ raid.thief, raid.owner }) do
			if byPlayer[player] == raid then
				byPlayer[player] = nil
				service.RaidStates[player] = nil
			end
			local profile = if player == raid.owner then raid.ownerProfile else raid.thiefProfile
			if profile._activeRaid == raid.id then
				profile._activeRaid = nil
			end
		end
		if raid.ownerProfile._reservedCreatures then
			raid.ownerProfile._reservedCreatures[raid.uid] = nil
		end
		local target = findDisplay(raid.owner, raid.uid)
		if target then
			target:SetAttribute("RaidReserved", nil)
			target:SetAttribute("RaidThiefUserId", nil)
		end
		if raid.marker then
			raid.marker:Destroy()
		end
		if raid.label then
			raid.label:Destroy()
		end
		if raid.carried then
			raid.carried:Destroy()
			raid.carried = nil
		end
		raid.character:SetAttribute("RaidMarked", nil)
		raid.character:SetAttribute("RaidOwnerUserId", nil)
		raid.thief:SetAttribute("RaidSlowedUntil", nil)
	end

	local function sendBoth(raid: Raid)
		for _, player in ipairs({ raid.thief, raid.owner }) do
			if service.Profiles[player] and player.Parent == Players then
				service.SendState(player)
			end
		end
	end

	local function cancel(raid: Raid, reason: string)
		if raids[raid.id] ~= raid then
			return
		end
		-- The owner's inventory was never removed while the theft was pending.
		release(raid)
		toast(raid.thief, "Raid ended", reason .. " The creature stays with its owner.", "error")
		toast(raid.owner, "Creature safe", reason .. " Your creature remains in your sanctuary.", "success")
		sendBoth(raid)
	end

	local function eligible(raid: Raid): boolean
		local entry = findEntry(raid.ownerProfile, raid.uid)
		return enabled
			and RunService:IsStudio()
			and service.Profiles[raid.owner] == raid.ownerProfile
			and service.Profiles[raid.thief] == raid.thiefProfile
			and raid.ownerProfile._readOnly ~= true
			and raid.thiefProfile._readOnly ~= true
			and raid.ownerProfile._saving == "session"
			and raid.thiefProfile._saving == "session"
			and raid.owner.Parent == Players
			and raid.thief.Parent == Players
			and entry ~= nil
			and entry.displayed == true
			and entry.species == raid.species
			and type(raid.ownerProfile._reservedCreatures) == "table"
			and raid.ownerProfile._reservedCreatures[raid.uid] == true
	end

	local function complete(raid: Raid)
		if raids[raid.id] ~= raid or not eligible(raid) then
			cancel(raid, "The target became unavailable.")
			return
		end
		local ownerRoot = alive(raid.owner)
		local thiefRoot = alive(raid.thief)
		local entry, index = findEntry(raid.ownerProfile, raid.uid)
		if #raid.thiefProfile.creatures >= (Config.MaxCreatures or 60) then
			cancel(raid, "The thief's collection is full.")
			return
		end
		if not ownerRoot or not thiefRoot or not index or not entry or findEntry(raid.thiefProfile, raid.uid) then
			cancel(raid, "The transfer could not be completed.")
			return
		end
		-- No yields between revalidation and both mutations. Preserve the exact UID;
		-- AddCreature would create a duplicate identity or award wild-capture XP.
		-- This is deliberately session-only Studio behavior, not a durable transfer.
		table.remove(raid.ownerProfile.creatures, index)
		entry.displayed = false
		table.insert(raid.thiefProfile.creatures, entry)
		raid.ownerProfile._dirty = true
		raid.thiefProfile._dirty = true
		release(raid)
		service.RefreshDisplays(raid.owner)
		service.RefreshDisplays(raid.thief)
		toast(raid.thief, "Practice raid complete", "The creature is in your vault. No Taming XP was awarded.", "success")
		toast(raid.owner, "Creature taken", "Your rival completed the chase in this Studio test.", "info")
		sendBoth(raid)
	end

	local function mark(raid: Raid, root: BasePart)
		local marker = Instance.new("Highlight")
		marker.Name = "WildboundRaidMarker"
		marker.Adornee = raid.character
		marker.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		marker.FillColor = Color3.fromRGB(232, 159, 75)
		marker.FillTransparency = 0.7
		marker.OutlineColor = Color3.fromRGB(255, 231, 175)
		marker.OutlineTransparency = 0
		marker.Parent = raid.character
		raid.marker = marker
		local label = Instance.new("BillboardGui")
		label.Name = "WildboundRaidLabel"
		label.Adornee = root
		label.Size = UDim2.fromOffset(168, 30)
		label.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		label.AlwaysOnTop = true
		label.MaxDistance = 300
		label.Parent = root
		local text = Instance.new("TextLabel")
		text.BackgroundColor3 = Color3.fromRGB(43, 48, 39)
		text.BackgroundTransparency = 0.12
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 14
		text.TextColor3 = Color3.fromRGB(255, 231, 175)
		text.Text = "RAID IN PROGRESS"
		text.Parent = label
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 8)
		round.Parent = text
		raid.label = label
		raid.character:SetAttribute("RaidMarked", true)
		raid.character:SetAttribute("RaidOwnerUserId", raid.owner.UserId)
	end

	local function showCarriedCreature(raid: Raid, root: BasePart, target: BasePart?)
		if raid.carried or not target then
			return
		end
		-- This is presentation only: the reserved UID stays in the owner's profile.
		-- Missing cosmetic geometry must never fail or award a pending raid.
		local staged: Model? = nil
		local ok = pcall(function()
			local source = target:FindFirstChild("DisplayCreature")
			if not source then
				local ancestor = target:FindFirstAncestorOfClass("Model")
				if ancestor and ancestor.Name == "DisplayCreature" then
					source = ancestor
				end
			end
			if not source or not source:IsA("Model") then
				return
			end
			local clone = source:Clone()
			if not clone or not clone:IsA("Model") then
				if clone then clone:Destroy() end
				return
			end
			staged = clone
			clone.Name = "WildboundRaidCarry"
			local parts: { BasePart } = {}
			local instances = clone:GetDescendants()
			table.insert(instances, clone)
			for _, instance in ipairs(instances) do
				if instance:IsA("ProximityPrompt") or instance:IsA("ClickDetector")
					or instance:IsA("BaseScript") or instance:IsA("ModuleScript")
				then
					instance:Destroy()
				else
					for _, attribute in ipairs({
						"EntityId", "CreatureUid", "OwnerUserId", "Action", "Target", "TutorialOwnerId",
						"LuredUserId", "RaidReserved", "RaidThiefUserId", "DisplayActive",
					}) do
						instance:SetAttribute(attribute, nil)
					end
					if instance:IsA("BasePart") then
						table.insert(parts, instance)
					end
				end
			end
			-- Generated creatures are small; reject unexpectedly large clones.
			if #parts == 0 or #parts > 80 then
				clone:Destroy()
				staged = nil
				return
			end
			clone:ScaleTo(0.62)
			clone:PivotTo(root.CFrame * CFrame.new(0, -0.6, -1.8))
			for _, part in ipairs(parts) do
				part.Massless = true
				part.Anchored = false
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CosmeticCarryWeld"
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
			end
			clone:SetAttribute("CosmeticRaidCarry", true)
			clone.Parent = raid.character
			raid.carried = clone
		end)
		if not ok and staged then
			staged:Destroy()
		end
	end

	local function begin(player: Player, request: any)
		if not enabled then
			toast(player, "Raids unavailable", "Paid raids are not enabled. Free practice raids work only in Studio multiplayer tests.", "info")
			return
		end
		if type(request.target) ~= "string" or #request.target > 120
			or type(request.owner) ~= "number" or request.owner ~= request.owner
			or math.abs(request.owner) > 9007199254740991 or request.owner ~= math.floor(request.owner)
			or request.owner == player.UserId
		then
			return
		end
		local owner = service.GetPlayerById(request.owner)
		local thiefProfile = service.Profiles[player]
		local ownerProfile = if owner then service.Profiles[owner] else nil
		if not owner or not thiefProfile or not ownerProfile then
			toast(player, "Protected sanctuary", "Only displayed creatures belonging to an online player can be targeted.", "info")
			return
		end
		if ownerProfile._readOnly == true or thiefProfile._readOnly == true
			or ownerProfile._saving ~= "session" or thiefProfile._saving ~= "session"
		then
			toast(player, "Raid unavailable", "Practice raids require two writable, session-only Studio profiles.", "info")
			return
		end
		if #thiefProfile.creatures >= (Config.MaxCreatures or 60) then
			toast(player, "Collection full", "Make room in your collection before starting a practice raid.", "info")
			return
		end
		if byPlayer[player] or byPlayer[owner] then
			toast(player, "Raid already active", "Both players must finish their current raid before another attempt.", "info")
			return
		end
		local now = os.clock()
		if lastAttempt[player] and now - lastAttempt[player] < attemptCooldown then
			toast(player, "Catch your breath", "Wait a moment before starting another practice raid.", "info")
			return
		end
		local uid = request.target
		local reservationKey = tostring(owner.UserId) .. ":" .. uid
		local entry = findEntry(ownerProfile, uid)
		local target = findDisplay(owner, uid)
		local thiefRoot = alive(player)
		local ownerRoot = alive(owner)
		if reservations[reservationKey] or not entry or entry.displayed ~= true
			or not Config.Creatures[entry.species] or not target or not thiefRoot or not ownerRoot
			or (ownerProfile._reservedCreatures and ownerProfile._reservedCreatures[uid])
			or findEntry(thiefProfile, uid)
		then
			toast(player, "Creature unavailable", "The creature must be exposed and both players must be alive.", "info")
			return
		end
		if (thiefRoot.Position - target.Position).Magnitude > stealRange
			or not inPlayableArea(thiefRoot.Position)
			or not hasLineOfSight(thiefRoot, target, player.Character)
		then
			toast(player, "Move closer", "Stand beside the exposed creature with a clear path to start stealing.", "info")
			return
		end
		local extraction = service.World.Extraction
		if not extraction or not extraction.Parent then
			toast(player, "Raid unavailable", "The extraction point is unavailable.", "error")
			return
		end
		sequence += 1
		local raid: Raid = {
			id = sequence, thief = player, owner = owner, thiefProfile = thiefProfile, ownerProfile = ownerProfile,
			uid = uid, species = entry.species, phase = "stealing", phaseStarted = now,
			deadline = now + stealSeconds, hits = 0, lastPublished = 0,
			marker = nil, label = nil, carried = nil, character = player.Character :: Model,
		}
		ownerProfile._reservedCreatures = ownerProfile._reservedCreatures or {}
		ownerProfile._reservedCreatures[uid] = true
		ownerProfile._activeRaid = raid.id
		thiefProfile._activeRaid = raid.id
		raids[raid.id] = raid
		reservations[reservationKey] = raid
		byPlayer[player] = raid
		byPlayer[owner] = raid
		lastAttempt[player] = now
		target:SetAttribute("RaidReserved", true)
		target:SetAttribute("RaidThiefUserId", player.UserId)
		mark(raid, thiefRoot)
		toast(player, "Studio raid test · no Robux", "Stay beside the creature, then reach extraction. Three net hits end the raid.", "info")
		toast(owner, "Sanctuary raid!", player.DisplayName .. " is stealing your creature. One net hit interrupts the stealing phase.", "error")
		publish(raid)
	end

	local function net(player: Player, request: any)
		local raid = byPlayer[player]
		if not raid or player ~= raid.owner or request.target ~= raid.thief.UserId then
			return
		end
		local now = os.clock()
		if lastNet[player] and now - lastNet[player] < netCooldown then
			return
		end
		-- Attempt cooldown also covers misses; never trust a client hit result.
		lastNet[player] = now
		local ownerRoot = alive(player)
		local thiefRoot = alive(raid.thief)
		if not ownerRoot or not thiefRoot then
			cancel(raid, "A player reset or was defeated.")
			return
		end
		if (ownerRoot.Position - thiefRoot.Position).Magnitude > netRange
			or not hasLineOfSight(ownerRoot, thiefRoot, player.Character, true)
		then
			toast(player, "Net missed", "Move within " .. tostring(netRange) .. " studs with a clear line of sight.", "info")
			return
		end
		raid.hits += 1
		if raid.phase == "stealing" then
			cancel(raid, "The owner interrupted the theft with a net.")
		elseif raid.hits >= netHits then
			cancel(raid, "The owner landed all " .. tostring(netHits) .. " net hits.")
		else
			raid.thief:SetAttribute("RaidSlowedUntil", now + 0.8)
			toast(player, "Net hit", tostring(raid.hits) .. "/" .. tostring(netHits) .. " hits. Keep chasing!", "success")
			toast(raid.thief, "Caught by a net", tostring(raid.hits) .. "/" .. tostring(netHits) .. " hits. Dodge and use cover.", "error")
			publish(raid)
		end
	end

	service.SetRaidHandler(function(player: Player, request: any)
		if not running or type(request) ~= "table" then
			return
		end
		if request.action == "BeginRaid" then
			begin(player, request)
		elseif request.action == "Net" then
			net(player, request)
		elseif request.action == "CancelRaid" then
			local raid = byPlayer[player]
			if raid and raid.thief == player then
				cancel(raid, "The thief abandoned the attempt.")
			end
		end
	end)

	local function onCharacter(player: Player, character: Model)
		local active = byPlayer[player]
		if active then
			cancel(active, "A player reset their character.")
		end
		if deathConnections[player] then
			deathConnections[player]:Disconnect()
			deathConnections[player] = nil
		end
		local function watchHumanoid(humanoid: Humanoid)
			if deathConnections[player] then
				deathConnections[player]:Disconnect()
			end
			deathConnections[player] = humanoid.Died:Connect(function()
				local raid = byPlayer[player]
				if raid then
					cancel(raid, "A player reset or was defeated.")
				end
			end)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			watchHumanoid(humanoid)
		else
			local childConnection: RBXScriptConnection? = nil
			childConnection = character.ChildAdded:Connect(function(child)
				if child:IsA("Humanoid") then
					watchHumanoid(child)
					if childConnection then
						childConnection:Disconnect()
					end
				end
			end)
			if childConnection and playerConnections[player] then
				table.insert(playerConnections[player], childConnection)
			end
		end
	end

	local function onJoin(player: Player)
		if not running or playerConnections[player] then
			return
		end
		local connections = {}
		playerConnections[player] = connections
		table.insert(connections, player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end))
		table.insert(connections, player.CharacterRemoving:Connect(function()
			local raid = byPlayer[player]
			if raid then
				cancel(raid, "A player reset their character.")
			end
		end))
		if player.Character then
			onCharacter(player, player.Character)
		end
	end

	local function onLeave(player: Player)
		local raid = byPlayer[player]
		if raid then
			cancel(raid, "A player left the server.")
		end
		local connections = playerConnections[player]
		if connections then
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end
		playerConnections[player] = nil
		if deathConnections[player] then
			deathConnections[player]:Disconnect()
			deathConnections[player] = nil
		end
		lastAttempt[player] = nil
		lastNet[player] = nil
	end

	service.RegisterPlayerHooks(onJoin, onLeave)
	for _, player in ipairs(Players:GetPlayers()) do
		onJoin(player)
	end

	local elapsed = 0
	heartbeat = RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, raid in pairs(raids) do
			local thiefRoot = alive(raid.thief)
			local ownerRoot = alive(raid.owner)
			if not thiefRoot or not ownerRoot or not eligible(raid) then
				cancel(raid, "A player or the exposed creature became unavailable.")
				continue
			end
			if not inPlayableArea(thiefRoot.Position) then
				cancel(raid, "The thief left the playable area.")
				continue
			end
			local target = findDisplay(raid.owner, raid.uid)
			if target then
				target:SetAttribute("RaidReserved", true)
				target:SetAttribute("RaidThiefUserId", raid.thief.UserId)
			end
			if raid.phase == "stealing" then
				if not target or (thiefRoot.Position - target.Position).Magnitude > stealRange
					or not hasLineOfSight(thiefRoot, target, raid.thief.Character)
				then
					cancel(raid, "The thief moved away from the creature.")
					continue
				end
				if now >= raid.deadline then
					raid.phase = "escape"
					raid.phaseStarted = now
					raid.deadline = now + escapeSeconds
					showCarriedCreature(raid, thiefRoot, target)
					toast(raid.thief, "Reach extraction", "Take the creature to the amber extraction ring. Ownership is still pending.", "info")
					toast(raid.owner, "Stop the escape", "Land three net hits to recover your creature before the chase ends.", "error")
					publish(raid)
				end
			elseif raid.phase == "escape" then
				local extraction = service.World.Extraction
				if not extraction or not extraction.Parent then
					cancel(raid, "The extraction point became unavailable.")
					continue
				end
				if now >= raid.deadline then
					cancel(raid, "The thief ran out of time to reach extraction.")
					continue
				end
				if (thiefRoot.Position - extraction.Position).Magnitude <= extractionRange then
					raid.phase = "chase"
					raid.phaseStarted = now
					raid.deadline = now + chaseSeconds
					toast(raid.thief, "Marked chase started", "Survive for " .. tostring(chaseSeconds) .. " seconds. Net hits do not reset.", "info")
					toast(raid.owner, "Recover your creature", "Your rival is marked for " .. tostring(chaseSeconds) .. " seconds. Keep chasing!", "error")
					publish(raid)
				end
			elseif raid.phase == "chase" and now >= raid.deadline then
				complete(raid)
				continue
			end
			if raids[raid.id] == raid and now - raid.lastPublished >= 1 then
				publish(raid)
			end
		end
	end)

	local result = { Enabled = enabled, DevelopmentOnly = true }
	function result.CancelAll()
		local active = {}
		for _, raid in pairs(raids) do
			table.insert(active, raid)
		end
		for _, raid in ipairs(active) do
			cancel(raid, "The server is closing.")
		end
	end
	function result.Destroy()
		if not running then
			return
		end
		running = false
		result.CancelAll()
		if heartbeat then
			heartbeat:Disconnect()
		end
		local players = {}
		for player in pairs(playerConnections) do
			table.insert(players, player)
		end
		for _, player in ipairs(players) do
			onLeave(player)
		end
	end
	game:BindToClose(result.CancelAll)
	return result
end

return RaidService

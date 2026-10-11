-- Wildbound's native client. Valuable actions are requests; the server owns outcomes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local palette = {
	paper = Color3.fromRGB(246, 242, 232), ink = Color3.fromRGB(24, 63, 50),
	leaf = Color3.fromRGB(111, 141, 92), berry = Color3.fromRGB(185, 80, 104),
	gold = Color3.fromRGB(211, 164, 76), muted = Color3.fromRGB(81, 104, 93),
	line = Color3.fromRGB(210, 216, 198), white = Color3.fromRGB(255, 253, 248),
	danger = Color3.fromRGB(158, 53, 53), amber = Color3.fromRGB(135, 91, 27),
	success = Color3.fromRGB(63, 104, 66),
}
local fonts = { title = Enum.Font.FredokaOne, body = Enum.Font.Gotham, bold = Enum.Font.GothamBold }
local gui = Instance.new("ScreenGui")
gui.Name = "WildboundUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Name = "SafeCanvas"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local function create(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props) do object[key] = value end
	object.Parent = parent
	return object
end
local function corner(object, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, object)
end
local function border(object, color, thickness)
	return create("UIStroke", { Color = color or palette.line, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, object)
end
local function frame(parent, name, size, color)
	local object = create("Frame", { Name = name, Size = size, BackgroundColor3 = color or palette.paper, BorderSizePixel = 0 }, parent)
	corner(object)
	return object
end
local function label(parent, text, size, font, color)
	return create("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 16,
		Font = font or fonts.body, TextColor3 = color or palette.ink,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true, Size = UDim2.new(1, 0, 0, 24), BorderSizePixel = 0,
	}, parent)
end
local buttonOrder = 0
local buttons = setmetatable({}, { __mode = "k" })
local function button(parent, text, onClick, secondary)
	buttonOrder += 1
	local bg = secondary and palette.white or palette.ink
	local object = create("TextButton", {
		Name = text, Text = text, TextSize = 15, Font = fonts.bold,
		TextColor3 = secondary and palette.ink or palette.white,
		BackgroundColor3 = bg, BorderSizePixel = 0, AutoButtonColor = false,
		Size = UDim2.fromOffset(140, 48), TextWrapped = true,
		Selectable = true, SelectionOrder = buttonOrder,
	}, parent)
	corner(object, 10)
	local outline = border(object, secondary and palette.line or palette.ink, 1)
	buttons[object] = { background = bg, outline = outline, disabled = false }
	object.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled and not buttons[object].disabled then
			TweenService:Create(object, TweenInfo.new(0.12), { BackgroundColor3 = buttons[object].background:Lerp(palette.leaf, 0.15) }):Play()
		end
	end)
	object.MouseLeave:Connect(function()
		TweenService:Create(object, TweenInfo.new(0.12), { BackgroundColor3 = buttons[object].disabled and palette.line or buttons[object].background }):Play()
	end)
	object.InputBegan:Connect(function(input)
		if not buttons[object].disabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			object.BackgroundColor3 = buttons[object].background:Lerp(palette.gold, 0.24)
		end
	end)
	object.InputEnded:Connect(function()
		if buttons[object] then object.BackgroundColor3 = buttons[object].disabled and palette.line or buttons[object].background end
	end)
	if onClick then
		object.Activated:Connect(function()
			if not buttons[object].disabled then onClick() end
		end)
	end
	return object
end
local function enable(object, enabled, text)
	local style = buttons[object]
	if not style then return end
	style.disabled = not enabled
	object.Active = enabled
	object.Selectable = enabled
	object.BackgroundColor3 = enabled and style.background or palette.line
	object.TextTransparency = enabled and 0 or 0.3
	if text then object.Text = text end
end
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	for object, style in pairs(buttons) do
		if object.Parent then
			local focused = object == GuiService.SelectedObject
			style.outline.Color = focused and palette.gold or palette.line
			style.outline.Thickness = focused and 3 or 1
		end
	end
end)
local function insetLabel(parent, text, x, y, width, height, size, font, color)
	local object = label(parent, text, size, font, color)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.new(width < 0 and 1 or 0, width, 0, height)
	return object
end
local function countKeys(map)
	local count = 0
	for _, value in pairs(map or {}) do if value then count += 1 end end
	return count
end
local function formatTime(seconds)
	local value = math.max(0, math.ceil(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

local state = nil
local stateAt = os.clock()
local Config, CreatureVisual, Request, Update
local pending = {}
local selectedSnack = "Berry"
local currentPanel = nil
local lastPanelKey = ""
local nearestCreature, nearestClue, nearestDisplay
local sneaking = false
local compact = false
local visiblePrompts = {}
local suppressCreaturePrompts = {}
local send, renderPanel, openPanel, closePanel, responsive, updateHUD
local feedback = nil
local uiOptions = {
	ReducedMotion = player:GetAttribute("WildboundReducedMotion") == true,
	LowEffects = player:GetAttribute("WildboundLowEffects") == true,
	Muted = player:GetAttribute("WildboundMuted") == true,
}
local objectiveExpanded = player:GetAttribute("WildboundObjectiveCollapsed") ~= true
local journalFilter, journalSearch = "All", ""
local pendingChecks = {}
local feedControls = setmetatable({}, { __mode = "k" })
local displayedCoins = nil
local coinAnimation = nil

local header = frame(root, "FieldHeader", UDim2.fromOffset(240, 72))
header.Position = UDim2.fromOffset(16, 12)
border(header)
local title = insetLabel(header, "WILDBOUND", 14, 7, -28, 30, 24, fonts.title)
local weatherText = insetLabel(header, "Connecting to the garden…", 14, 40, -28, 23, 13, fonts.body, palette.muted)
local wallet = frame(root, "Wallet", UDim2.fromOffset(240, 72))
wallet.AnchorPoint = Vector2.new(1, 0)
wallet.Position = UDim2.new(1, -16, 0, 12)
border(wallet)
local coinText = insetLabel(wallet, "— coins", 14, 6, -28, 29, 20, fonts.bold)
coinText.TextColor3 = palette.amber
local coinDelta = insetLabel(wallet, "", 14, 34, -28, 18, 12, fonts.bold, palette.success)
coinDelta.TextXAlignment = Enum.TextXAlignment.Right
coinDelta.Visible = false
coinDelta.BackgroundColor3 = palette.paper
coinDelta.BackgroundTransparency = 0
corner(coinDelta, 6)
local coinDeltaVersion = 0
local coinCounter = create("NumberValue", { Value = 0 }, wallet)
coinCounter:GetPropertyChangedSignal("Value"):Connect(function() coinText.Text = tostring(math.floor(coinCounter.Value + 0.5)) .. " coins" end)
local levelText = insetLabel(wallet, "Taming · loading", 14, 35, -28, 21, 12, fonts.body, palette.muted)
local xpTrack = frame(wallet, "XPTrack", UDim2.new(1, -28, 0, 4), palette.line)
xpTrack.Position = UDim2.new(0, 14, 1, -10)
corner(xpTrack, 2)
local xpFill = frame(xpTrack, "XP", UDim2.fromScale(0, 1), palette.leaf)
corner(xpFill, 2)
local objective = frame(root, "Objective", UDim2.fromOffset(360, 86))
objective.Position = UDim2.fromOffset(16, 96)
border(objective)
local objectiveTitle = insetLabel(objective, "YOUR FIRST DISCOVERY", 14, 10, -28, 18, 12, fonts.bold, palette.muted)
local objectiveText = insetLabel(objective, "Waiting for your field journal…", 14, 31, -28, 44, 16, fonts.bold)
local objectiveCount = insetLabel(objective, "", 14, 70, -28, 15, 11, fonts.body, palette.muted)
local objectiveToggle = button(objective, "−", function()
	if not state or not state.tutorialComplete then return end
	objectiveExpanded = not objectiveExpanded
	player:SetAttribute("WildboundObjectiveCollapsed", not objectiveExpanded)
	if responsive then responsive() end
end, true)
objectiveToggle.Position = UDim2.new(1, -48, 0, 0)
objectiveToggle.Size = UDim2.fromOffset(44, 44)
objectiveToggle.TextSize = 22
objectiveToggle.Visible = false
local navigation = create("ScrollingFrame", { Name = "FieldNavigation", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.fromOffset(360, 0), Position = UDim2.fromOffset(16, 194), Size = UDim2.fromOffset(360, 46) }, root)
local journeyNav = button(navigation, "Journey · G", function() openPanel("Journey") end, true)
journeyNav.Size = UDim2.fromOffset(84, 44)
local journalNav = button(navigation, "Journal · J", function() openPanel("Journal") end, true)
journalNav.Position = UDim2.fromOffset(92, 0)
journalNav.Size = UDim2.fromOffset(84, 44)
local shopNav = button(navigation, "Snacks · B", function() openPanel("Shop") end, true)
shopNav.Position = UDim2.fromOffset(184, 0)
shopNav.Size = UDim2.fromOffset(84, 44)
local sanctuaryNav = button(navigation, "Sanctuary · V", function() openPanel("Sanctuary") end, true)
sanctuaryNav.Position = UDim2.fromOffset(276, 0)
sanctuaryNav.Size = UDim2.fromOffset(84, 44)

local context = frame(root, "Encounter", UDim2.fromOffset(360, 82))
context.AnchorPoint = Vector2.new(0.5, 1)
context.Position = UDim2.new(0.5, 0, 1, -84)
border(context)
local contextName = insetLabel(context, "Explore the garden", 12, 8, -24, 20, 15, fonts.bold)
local contextHint = insetLabel(context, "Watch for moving leaves and tiny tracks.", 12, 30, -150, 40, 12, fonts.body, palette.muted)
local actionButton = button(context, "Explore", function()
	if not state then return end
	if nearestCreature then
		local entity = nearestCreature:GetAttribute("EntityId")
		local lure = (state.lures or {})[entity]
		if lure then send({ action = "Befriend", target = entity }, "encounter")
		else send({ action = "Lure", target = entity, snack = selectedSnack }, "encounter") end
	elseif nearestDisplay then
		send({ action = "BeginRaid", target = nearestDisplay:GetAttribute("CreatureUid"), owner = nearestDisplay:GetAttribute("OwnerUserId") }, "encounter")
	else openPanel("Help") end
end)
actionButton.AnchorPoint = Vector2.new(1, 0.5)
actionButton.Position = UDim2.new(1, -10, 0.5, 10)
actionButton.Size = UDim2.fromOffset(126, 48)
local trustTrack = frame(context, "TrustTrack", UDim2.new(1, -24, 0, 4), palette.line)
trustTrack.Position = UDim2.new(0, 12, 1, -9)
trustTrack.Visible = false
local trustFill = frame(trustTrack, "Trust", UDim2.fromScale(0, 1), palette.leaf)
local trustText = insetLabel(context, "", 12, 55, -152, 16, 11, fonts.bold, palette.success)
trustText.Visible = false
local controls = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(356, 54), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20) }, root)
local sneakButton = button(controls, "Hold Sneak", nil, true)
sneakButton.Size = UDim2.fromOffset(110, 50)
local snackButton = button(controls, "Berry · 0", function()
	if selectedSnack == "Berry" and state and (state.level or 1) >= (Config.Snacks.Seed.UnlockLevel or 1) then selectedSnack = "Seed"
	else selectedSnack = "Berry" end
end, true)
snackButton.Position = UDim2.fromOffset(118, 0)
snackButton.Size = UDim2.fromOffset(116, 50)
local function photograph()
	if nearestClue then send({ action = "Photo", target = nearestClue:GetAttribute("ClueId") or nearestClue:GetAttribute("Target") }, "photo")
	else
		if openPanel then openPanel("Help") end
	end
end
local photoButton = button(controls, "Photo · P", photograph, true)
photoButton.Position = UDim2.fromOffset(242, 0)
photoButton.Size = UDim2.fromOffset(114, 50)
local netButton = button(root, "Net · Q", function()
	if state and state.raid and state.raid.role == "defender" then send({ action = "Net", target = state.raid.opponentUserId }, "net") end
end)
netButton.AnchorPoint = Vector2.new(0.5, 1)
netButton.Position = UDim2.new(0.5, 0, 1, -84)
netButton.Size = UDim2.fromOffset(180, 52)
netButton.Visible = false

local raidHud = frame(root, "Chase", UDim2.fromOffset(380, 114), palette.ink)
raidHud.AnchorPoint = Vector2.new(0.5, 0)
raidHud.Position = UDim2.new(0.5, 0, 0, 12)
raidHud.Visible = false
border(raidHud, palette.gold, 2)
local raidTitle = insetLabel(raidHud, "SANCTUARY ALERT", 14, 8, -28, 22, 15, fonts.bold, palette.gold)
local raidTimer = insetLabel(raidHud, "0:60", 14, 34, 92, 36, 30, fonts.title, palette.white)
local raidDetail = insetLabel(raidHud, "", 112, 32, -128, 44, 13, fonts.body, palette.white)
local raidHits = insetLabel(raidHud, "", 14, 82, -28, 20, 12, fonts.bold, palette.gold)
local raidMarker = create("Highlight", { Name = "WildboundChaseMarker", FillColor = palette.berry, FillTransparency = 0.65, OutlineColor = palette.gold, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, gui)
local extractionMarker = create("BillboardGui", { Name = "ExtractionMarker", Size = UDim2.fromOffset(170, 62), StudsOffsetWorldSpace = Vector3.new(0, 8, 0), AlwaysOnTop = true, Enabled = false }, gui)
local extractionLabel = label(extractionMarker, "↓ EXTRACTION", 18, fonts.bold, palette.gold)
extractionLabel.Size = UDim2.fromScale(1, 1)
extractionLabel.TextXAlignment = Enum.TextXAlignment.Center
extractionLabel.TextStrokeTransparency = 0.4
extractionLabel.TextStrokeColor3 = palette.ink

local scrim = create("TextButton", { Name = "MenuBackdrop", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, BackgroundColor3 = palette.ink, BackgroundTransparency = 0.55, BorderSizePixel = 0, Visible = false, ZIndex = 20 }, root)
scrim.Selectable = false
local modal = frame(root, "FieldJournal", UDim2.fromOffset(740, 600))
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Visible = false
modal.ZIndex = 21
border(modal, palette.line, 2)
local modalTitle = insetLabel(modal, "Field journal", 22, 12, -86, 34, 27, fonts.title)
modalTitle.ZIndex = 22
local modalSubtitle = insetLabel(modal, "", 22, 48, -86, 24, 13, fonts.body, palette.muted)
modalSubtitle.ZIndex = 22
local closeButton = button(modal, "×", function() closePanel() end, true)
closeButton.Position = UDim2.new(1, -60, 0, 14)
closeButton.Size = UDim2.fromOffset(44, 44)
closeButton.TextSize = 25
closeButton.ZIndex = 23
local tabs = create("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 0, 48), CanvasSize = UDim2.fromOffset(810, 0), ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 22 }, modal)
local tabButtons = {}
local panelNames = { "Journey", "Journal", "Shop", "Sanctuary", "Raids", "Help", "Settings" }
local tabNames = { Journey = "Journey", Journal = "Journal", Shop = "Snacks", Sanctuary = "Sanctuary", Raids = "Raids", Help = "Guide", Settings = "Settings" }
for index, name in ipairs(panelNames) do
	local tab = button(tabs, tabNames[name], function() openPanel(name) end, true)
	tab.Position = UDim2.fromOffset((index - 1) * 114, 0)
	tab.Size = UDim2.fromOffset(106, 44)
	tab.ZIndex = 23
	tabButtons[name] = tab
end
local filters = create("Frame", { Name = "JournalFilters", Position = UDim2.fromOffset(18, 136), Size = UDim2.new(1, -36, 0, 100), BackgroundTransparency = 1, Visible = false, ZIndex = 22 }, modal)
local filterButtons = {}
for index, name in ipairs({ "All", "Found", "Rare" }) do
	local filter = button(filters, name, function()
		journalFilter = name
		if renderPanel then renderPanel() end
	end, true)
	filter.Position = UDim2.fromOffset((index - 1) * 78, 0)
	filter.Size = UDim2.fromOffset(70, 44)
	filter.ZIndex = 23
	filterButtons[name] = filter
end
local search = create("TextBox", {
	Name = "SearchCreatures", Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 44),
	Text = "", PlaceholderText = "Search names, habitats or clues", PlaceholderColor3 = palette.muted,
	TextColor3 = palette.ink, BackgroundColor3 = palette.white, BorderSizePixel = 0, Font = fonts.body,
	TextSize = 14, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23,
}, filters)
corner(search, 10)
border(search)
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, search)
search:GetPropertyChangedSignal("Text"):Connect(function()
	journalSearch = string.lower(string.sub(search.Text, 1, 80))
	if currentPanel == "Journal" and renderPanel then renderPanel() end
end)
local body = create("ScrollingFrame", { Name = "Entries", Position = UDim2.fromOffset(18, 138), Size = UDim2.new(1, -36, 1, -154), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = palette.leaf, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 22 }, modal)
local bodyLayout = create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, body)
create("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, body)

local toastStack = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(380, 250), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), ZIndex = 40 }, root)
create("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, toastStack)
local toastCount = 0
local function toast(titleText, message, tone)
	toastCount += 1
	local item = frame(toastStack, "Notice", UDim2.new(1, 0, 0, 76), palette.white)
	item.ZIndex = 41
	item.LayoutOrder = toastCount
	local accent = tone == "error" and palette.danger or tone == "success" and palette.success or palette.amber
	border(item, accent, 2)
	local heading = insetLabel(item, titleText or "Field note", 14, 8, -28, 21, 15, fonts.bold, accent)
	heading.ZIndex = 42
	local copy = insetLabel(item, message or "", 14, 30, -28, 38, 13, fonts.body)
	copy.ZIndex = 42
	if #toastStack:GetChildren() > 4 then
		for _, old in ipairs(toastStack:GetChildren()) do if old:IsA("Frame") and old ~= item then old:Destroy(); break end end
	end
	item.BackgroundTransparency = 1
	TweenService:Create(item, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	task.delay(tone == "error" and 6 or 4.5, function()
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
			task.delay(0.2, function() item:Destroy() end)
		end
	end)
end

local function portrait(parent, species, size, discovered, variant)
	local holder = frame(parent, "Portrait", UDim2.fromOffset(size, size), palette.line)
	holder.ZIndex = 23
	local viewport = create("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 216, 193), LightColor = Color3.fromRGB(255, 245, 220), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 24 }, holder)
	local camera = create("Camera", { FieldOfView = 36, CFrame = CFrame.lookAt(Vector3.new(4, 3.6, -7), Vector3.new(0, 1.9, 0)) }, viewport)
	viewport.CurrentCamera = camera
	if CreatureVisual and Config.Creatures[species] then
		local ok, model = pcall(CreatureVisual.Build, Config, species)
		if ok and model then
			if variant and CreatureVisual.ApplyVariant then pcall(CreatureVisual.ApplyVariant, Config, model, variant) end
			local world = create("WorldModel", {}, viewport)
			model.Parent = world
			model:PivotTo(CFrame.Angles(0, math.rad(-18), 0))
			local bounds, extents = model:GetBoundingBox()
			local radius = math.max(extents.X, extents.Y, extents.Z) * 0.5
			local distance = radius / math.tan(math.rad(camera.FieldOfView * 0.5)) * 1.18
			local direction = Vector3.new(0.4, 0.15, -1).Unit
			camera.CFrame = CFrame.lookAt(bounds.Position + direction * distance, bounds.Position)
			if not discovered then
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "Root" then part.Color = palette.muted; part.Material = Enum.Material.SmoothPlastic end
				end
			end
		end
	end
	if not discovered then
		local unknown = label(holder, "?", 32, fonts.title, palette.ink)
		unknown.AnchorPoint = Vector2.new(0.5, 0.5)
		unknown.Position = UDim2.fromScale(0.5, 0.5)
		unknown.Size = UDim2.fromOffset(44, 44)
		unknown.BackgroundColor3 = palette.paper
		unknown.BackgroundTransparency = 0
		corner(unknown, 12)
		unknown.TextXAlignment = Enum.TextXAlignment.Center
		unknown.ZIndex = 25
	end
	return holder
end
local function card(height, color)
	local object = frame(body, "Entry", UDim2.new(1, 0, 0, height), color or palette.white)
	object.ZIndex = 23
	border(object)
	return object
end
local function cardLabel(parent, text, x, y, width, height, size, font, color)
	local object = insetLabel(parent, text, x, y, width, height, size, font, color)
	object.ZIndex = 24
	return object
end
local function paragraph(heading, text, tone)
	local item = card(110)
	cardLabel(item, heading, 16, 10, -32, 24, 18, fonts.bold, tone)
	cardLabel(item, text, 16, 39, -32, 61, 14, fonts.body)
	return item
end
local function progressCard(heading, copy, progress, goal, reward, complete)
	local item = card(126)
	cardLabel(item, heading, 16, 10, -32, 25, 18, fonts.bold)
	cardLabel(item, copy, 16, 38, -32, 34, 13, fonts.body, palette.muted)
	local track = frame(item, "ProgressTrack", UDim2.new(1, -32, 0, 6), palette.line)
	track.Position = UDim2.fromOffset(16, 82)
	track.ZIndex = 24
	local fill = frame(track, "Progress", UDim2.fromScale(math.clamp((progress or 0) / math.max(1, goal or 1), 0, 1), 1), palette.leaf)
	fill.ZIndex = 25
	cardLabel(item, complete and "COMPLETE" or string.format("%d / %d", progress or 0, goal or 1), 16, 96, 110, 20, 12, fonts.bold, complete and palette.success or palette.ink)
	local rewards = cardLabel(item, reward or "", 130, 96, -146, 20, 12, fonts.bold, palette.amber)
	rewards.TextXAlignment = Enum.TextXAlignment.Right
	return item
end
local function variantName(variant)
	local data = Config and Config.Variants and Config.Variants[variant or "Normal"]
	return data and (data.Name or data.Label) or variant or "Normal"
end
local function panelKey()
	if not state then return "loading" end
	local parts = { tostring(state.coins), tostring(state.xp), tostring(state.level), tostring(state.sanctuaryLevel), tostring(state.sanctuaryCapacity), tostring(state.saving), tostring(state.tutorialComplete), tostring(state.pondUnlocked) }
	for _, snack in ipairs({ "Berry", "Seed" }) do table.insert(parts, tostring((state.snacks or {})[snack])) end
	for _, species in ipairs(Config.CreatureOrder) do table.insert(parts, tostring((state.discoveries or {})[species])) end
	for _, creature in ipairs(state.creatures or {}) do table.insert(parts, creature.uid .. tostring(creature.displayed) .. tostring(creature.variant) .. tostring(creature.bond) .. tostring(creature.reserved) .. tostring(creature.lastFed)) end
	for key in pairs(pending) do table.insert(parts, key) end
	table.insert(parts, tostring(state.equippedUid))
	if state.questline then table.insert(parts, tostring(state.questline.id) .. tostring(state.questline.progress) .. tostring(state.questline.complete)) end
	table.insert(parts, state.raid and state.raid.phase or "peace")
	if state.event then table.insert(parts, tostring(state.event.progress) .. tostring(state.event.claimed)) end
	if state.daily then table.insert(parts, tostring(state.daily.progress) .. tostring(state.daily.claimed)) end
	return table.concat(parts, "|")
end

renderPanel = function()
	if not currentPanel then return end
	local scrollPosition = body.CanvasPosition
	local selected = GuiService.SelectedObject
	local restoreSelection = selected and selected:IsDescendantOf(body)
	local selectedName = restoreSelection and selected.Name or nil
	for _, child in ipairs(body:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	for name, tab in pairs(tabButtons) do
		tab.BackgroundColor3 = name == currentPanel and palette.ink or palette.white
		tab.TextColor3 = name == currentPanel and palette.white or palette.ink
		buttons[tab].background = tab.BackgroundColor3
	end
	modalTitle.Text = ({ Journey = "Naturalist journey", Journal = "Field journal", Shop = "Garden snack shop", Sanctuary = "Your sanctuary", Raids = "Hunt & heist", Help = "Your field guide", Settings = "Your preferences" })[currentPanel]
	modalSubtitle.Text = ({ Journey = "Your next goal, rewards, and seasonal fieldwork.", Journal = "Find a clue. Learn a habit. Meet a new friend.", Shop = "Snacks for your next discovery or companion.", Sanctuary = "Bond, explore together, or display for income.", Raids = "Exclusive hunts and Studio raid practice.", Help = "Everything you need to explore.", Settings = "Local preferences for this play session." })[currentPanel]
	filters.Visible = currentPanel == "Journal"
	local shortPanel = modal.AbsoluteSize.Y < 380
	local bodyTop = shortPanel and 104 or 138
	local singleFilterRow = modal.AbsoluteSize.X >= 460 or shortPanel
	local filterHeight = singleFilterRow and 56 or 106
	modalSubtitle.Visible = not shortPanel
	tabs.Position = UDim2.fromOffset(18, shortPanel and 48 or 80)
	filters.Position = UDim2.fromOffset(18, bodyTop - 2)
	local searchX = modal.AbsoluteSize.X >= 460 and 234 or shortPanel and 204 or 0
	for index, name in ipairs({ "All", "Found", "Rare" }) do
		filterButtons[name].Position = UDim2.fromOffset((index - 1) * (shortPanel and modal.AbsoluteSize.X < 460 and 68 or 78), 0)
		filterButtons[name].Size = UDim2.fromOffset(shortPanel and modal.AbsoluteSize.X < 460 and 60 or 70, 44)
	end
	search.Position = UDim2.fromOffset(searchX, singleFilterRow and 0 or 52)
	search.Size = UDim2.new(1, -searchX, 0, 44)
	search.PlaceholderText = shortPanel and "Search" or "Search names, habitats or clues"
	local top = currentPanel == "Journal" and bodyTop + filterHeight or bodyTop
	body.Position = UDim2.fromOffset(18, top)
	body.Size = UDim2.new(1, -36, 1, -top - 16)
	for name, filter in pairs(filterButtons) do
		filter.BackgroundColor3 = journalFilter == name and palette.ink or palette.white
		filter.TextColor3 = journalFilter == name and palette.white or palette.ink
		buttons[filter].background = filter.BackgroundColor3
	end
	if not state or not Config then
		paragraph("Opening your journal…", "Waiting for the server. Your progress and coins will appear when the connection is ready.")
		return
	end
	if currentPanel == "Journey" then
		local quest = state.questline or state.objective or {}
		progressCard(quest.title or "Your first discovery", quest.text or "Follow the moving leaves to meet your first Mossbun.", quest.progress or 0, quest.goal or 1, quest.complete and "Trail completed" or string.format("+%d coins · +%d XP", quest.reward or 0, quest.xpReward or 0), quest.complete)
		local garden = 0
		for _, species in ipairs(Config.CreatureOrder) do
			if Config.Creatures[species].Zone == "Garden" and (state.discoveries or {})[species] then garden += 1 end
		end
		progressCard(state.pondUnlocked and "The pond is open" or "Open the pond trail", "Discover three different garden species. Look for Lanternwing at dusk.", math.min(garden, 3), 3, state.pondUnlocked and "New habitat unlocked" or "Reward: pond access", state.pondUnlocked)
		if state.daily then
			progressCard(state.daily.title or "Daily field notes", "Photograph different clues today. Familiar clues count too.", state.daily.progress, state.daily.goal or 2, "+" .. tostring(state.daily.reward or 30) .. " coins", state.daily.claimed)
		end
		if state.event then
			local targets = {}
			for _, species in ipairs(state.event.species or {}) do table.insert(targets, Config.Creatures[species] and Config.Creatures[species].Name or species) end
			progressCard("Weekly · " .. tostring(state.event.name or "Garden survey"), "Find " .. table.concat(targets, ", ") .. ".", state.event.progress, state.event.goal or 3, "+" .. tostring(state.event.reward or 100) .. " coins + title", state.event.claimed)
		end
		if state.titles and #state.titles > 0 then paragraph("Your earned titles", table.concat(state.titles, " · ")) end
	elseif currentPanel == "Journal" then
		local total = countKeys(state.discoveries)
		local summary = card(66)
		cardLabel(summary, string.format("%d / %d species discovered", total, #Config.CreatureOrder), 14, 9, -28, 23, 17, fonts.bold)
		cardLabel(summary, "Taming " .. tostring(state.level or 1) .. " · " .. tostring(state.tamingTool or "Starter kit") .. " · Rare filter includes Legendary", 14, 35, -28, 21, 12, fonts.body, palette.muted)
		local shown = 0
		for _, species in ipairs(Config.CreatureOrder) do
			local data = Config.Creatures[species]
			local found = (state.discoveries or {})[species] == true
			local rare = data.Rarity == "Rare" or data.Rarity == "Legendary"
			local searchable = string.lower(data.Name .. " " .. data.Zone .. " " .. data.Hint .. " " .. data.Rarity)
			local matching = (journalFilter == "All" or journalFilter == "Found" and found or journalFilter == "Rare" and rare) and (journalSearch == "" or string.find(searchable, journalSearch, 1, true) ~= nil)
			if matching then
				shown += 1
				local firstVariant, ownedCount = "Normal", 0
				local seenVariants = {}
				for _, owned in ipairs(state.creatures or {}) do
					if owned.species == species then
						ownedCount += 1
						firstVariant = owned.variant or "Normal"
						seenVariants[variantName(owned.variant)] = true
					end
				end
				local item = card(compact and 164 or 142)
				local picture = portrait(item, species, compact and 76 or 104, found, firstVariant)
				picture.Position = UDim2.fromOffset(12, 12)
				local x = compact and 102 or 132
				cardLabel(item, data.Name, x, 8, -x - 12, 27, compact and 19 or 23, fonts.title)
				cardLabel(item, data.Rarity .. " · " .. (found and "Discovered" or "Unknown"), x, 37, -x - 12, 22, 12, fonts.bold, Config.RarityColor(data.Rarity))
				cardLabel(item, data.Snack .. " · " .. data.Zone .. " · " .. (data.Weather == "Any" and "Any weather" or data.Weather), x, 60, -x - 12, compact and 31 or 24, 12, fonts.body, palette.muted)
				cardLabel(item, found and data.Description or data.Hint, compact and 14 or x, compact and 97 or 87, compact and -28 or -x - 12, compact and 35 or 30, 13, fonts.body)
				local variants = {}
				for name in pairs(seenVariants) do table.insert(variants, name) end
				table.sort(variants)
				cardLabel(item, found and (tostring(ownedCount) .. " owned" .. (#variants > 0 and " · " .. table.concat(variants, ", ") or "")) or "Read its clue to start searching", compact and 14 or x, compact and 138 or 117, compact and -28 or -x - 12, 20, 11, fonts.bold, found and palette.success or palette.muted)
			end
		end
		if shown == 0 then paragraph("No matching creatures", "Try another filter or a shorter search. Your collection is still here.") end
	elseif currentPanel == "Shop" then
		paragraph(tostring(state.coins or 0) .. " coins to spend", "Water flowers and gather leaves for repeatable coins. Photograph a new clue for a one-time research reward. Your first guided berry is free.")
		for _, snack in ipairs({ "Berry", "Seed" }) do
			local data = Config.Snacks[snack]
			local locked = (state.level or 1) < data.UnlockLevel
			local afford = (state.coins or 0) >= data.Price
			local waiting = pending["buy-" .. snack] ~= nil
			local item = card(compact and 160 or 126)
			cardLabel(item, data.Name, 16, 12, -32, 26, 23, fonts.title)
			cardLabel(item, string.format("%d coins each · %d in your bag", data.Price, (state.snacks or {})[snack] or 0), 16, 42, -32, 22, 14, fonts.bold, palette.muted)
			local message = locked and "Unlocks at Taming level " .. data.UnlockLevel or not afford and "Need more coins? Try a garden job." or "Select this snack in your bag before offering it."
			cardLabel(item, message, 16, 72, compact and -32 or -190, compact and 23 or 34, 12, fonts.body, locked and palette.amber or palette.muted)
			local buy = button(item, waiting and "Buying…" or locked and "Level " .. data.UnlockLevel or "Buy · " .. data.Price, function() send({ action = "BuySnack", snack = snack }, "buy-" .. snack) end)
			buy.AnchorPoint = Vector2.new(1, 1)
			buy.Position = UDim2.new(1, -14, 1, -12)
			buy.Size = UDim2.fromOffset(compact and 140 or 158, 44)
			buy.ZIndex = 24
			buy.Name = "Buy_" .. snack
			enable(buy, not locked and afford and not waiting)
		end
	elseif currentPanel == "Sanctuary" then
		local capacity = state.sanctuaryCapacity or ((state.sanctuaryLevel or 1) * 3)
		local owned = state.creatures or {}
		local displayed = 0
		for _, creature in ipairs(owned) do if creature.displayed then displayed += 1 end end
		local summary = card(compact and 96 or 82)
		cardLabel(summary, string.format("%d companions · %d / %d displays", #owned, displayed, capacity), 14, 9, -28, 24, 17, fonts.bold)
		cardLabel(summary, "Vault: protected. Display: income, exposed while online. Following: travels with you.", 14, 39, -28, compact and 46 or 33, 12, fonts.body, palette.muted)
		if #owned == 0 then paragraph("Meet your first companion", "Follow the moving leaves, offer your free berry, then hold Sneak. Your Mossbun will appear here after you befriend it.") end
		for _, creature in ipairs(owned) do
			local data = Config.Creatures[creature.species]
			if data then
				local item = card(compact and 250 or 194)
				local picture = portrait(item, creature.species, compact and 72 or 80, true, creature.variant)
				picture.Position = UDim2.fromOffset(12, 12)
				local x = compact and 98 or 108
				cardLabel(item, data.Name, x, 9, -x - 12, 26, 21, fonts.title)
				local following = state.equippedUid == creature.uid
				cardLabel(item, variantName(creature.variant) .. " · " .. (following and "Following you" or creature.displayed and "Displayed · exposed" or "Vault · protected"), x, 38, -x - 12, compact and 32 or 24, 12, fonts.bold, creature.displayed and palette.amber or palette.success)
				local bond = math.clamp(creature.bond or 0, 0, 100)
				cardLabel(item, string.format("Bond %d / 100 · likes %s", bond, data.Snack), x, compact and 72 or 64, -x - 12, 20, 12, fonts.body, palette.muted)
				local track = frame(item, "BondTrack", UDim2.new(1, -x - 12, 0, 5), palette.line)
				track.Position = UDim2.fromOffset(x, compact and 96 or 90)
				track.ZIndex = 24
				local fill = frame(track, "Bond", UDim2.fromScale(bond / 100, 1), palette.leaf)
				fill.ZIndex = 25
				local displayKey, equipKey, feedKey = "display-" .. creature.uid, "equip-" .. creature.uid, "feed-" .. creature.uid
				local toggle = button(item, pending[displayKey] and "Updating…" or creature.displayed and "Store in vault" or "Display for income", function() send({ action = "SetDisplay", target = creature.uid, displayed = not creature.displayed }, displayKey) end, not creature.displayed)
				local equip = button(item, pending[equipKey] and "Updating…" or following and "Stop following" or "Follow me", function()
					local target = creature.uid
					if following then target = nil end
					send({ action = "EquipCompanion", target = target }, equipKey)
				end, true)
				local cooldown = math.max(0, (creature.feedReadyIn or 0) - (os.clock() - stateAt))
				local snackCount = (state.snacks or {})[data.Snack] or 0
				local feedText = pending[feedKey] and "Feeding…" or bond >= 100 and "Bond complete" or cooldown > 0 and "Feed in " .. formatTime(cooldown) or snackCount < 1 and "Need " .. data.Snack or "Feed · " .. data.Snack
				local feed = button(item, feedText, function() send({ action = "FeedCompanion", target = creature.uid }, feedKey) end, true)
				if compact then
					toggle.Position = UDim2.fromOffset(12, 112)
					toggle.Size = UDim2.new(1, -24, 0, 44)
					equip.Position = UDim2.fromOffset(12, 164)
					equip.Size = UDim2.new(0.5, -16, 0, 44)
					feed.Position = UDim2.new(0.5, 4, 0, 164)
					feed.Size = UDim2.new(0.5, -16, 0, 44)
				else
					for index, control in ipairs({ toggle, equip, feed }) do
						control.Position = UDim2.new((index - 1) / 3, 12, 0, 114)
						control.Size = UDim2.new(1 / 3, -16, 0, 44)
					end
				end
				for _, control in ipairs({ toggle, equip, feed }) do control.ZIndex = 24; control.TextSize = compact and 12 or 13 end
				toggle.Name, equip.Name, feed.Name = "Display_" .. creature.uid, "Equip_" .. creature.uid, "Feed_" .. creature.uid
				local available = not creature.reserved and state.raid == nil
				enable(toggle, available and not pending[displayKey] and (creature.displayed or displayed < capacity))
				enable(equip, available and not pending[equipKey])
				enable(feed, available and not pending[feedKey] and cooldown <= 0 and snackCount > 0 and bond < 100)
				feedControls[feed] = { readyAt = stateAt + (creature.feedReadyIn or 0), bond = bond, snack = data.Snack, key = feedKey, available = available }
				cardLabel(item, creature.reserved and "In an active raid · ownership pending" or bond >= 50 and "Strong bond increases display income" or "Feed a favorite snack to grow your bond (+10)", 12, compact and 219 or 166, -24, 23, 11, fonts.body, palette.muted)
			end
		end
		local upgradeCost = state.sanctuaryUpgradeCost
		local item = card(132)
		cardLabel(item, "Habitat level " .. tostring(state.sanctuaryLevel or 1), 16, 10, -32, 26, 21, fonts.title)
		cardLabel(item, "More space for income-earning displays.", 16, 41, -32, 26, 13, fonts.body, palette.muted)
		local canUpgrade = type(upgradeCost) == "number" and upgradeCost > 0
		local upgrade = button(item, pending.upgrade and "Expanding…" or canUpgrade and "Expand · " .. upgradeCost .. " coins" or "Fully expanded", function() send({ action = "UpgradeSanctuary" }, "upgrade") end)
		upgrade.AnchorPoint = Vector2.new(1, 1)
		upgrade.Position = UDim2.new(1, -14, 1, -12)
		upgrade.Size = UDim2.fromOffset(214, 44)
		upgrade.ZIndex = 24
		upgrade.Name = "UpgradeSanctuary"
		enable(upgrade, canUpgrade and (state.coins or 0) >= (upgradeCost or math.huge) and not pending.upgrade)
	elseif currentPanel == "Raids" then
		paragraph("Studio raid test · no Robux", "Free raid practice is available in Studio with two players. Real paid raids and permanent production transfers are disabled in this version.", palette.amber)
		paragraph("One wild creature. One winner.", "Wild catches are exclusive. Use its preferred snack; higher Taming levels improve your odds. Rare appearances depend on the weather. Approach gently and watch its clues.")
		paragraph("Take it. Reach extraction. Survive.", "Only online owners' exposed creatures are eligible. Stealing takes 6 seconds; the owner can stop you. Reach the extraction point, then survive a 60-second marked chase.")
		paragraph("Owners can recover their companion", "Land three short-range net hits during the escape or chase. Leaving, resetting, or being defeated before completion returns the creature. Taking it does not grant Taming XP.")
		if state.raid then
			local item = paragraph("Active raid", state.raid.role == "thief" and "Follow the escape marker. You can abandon this attempt and return the creature." or "Your creature is still recoverable. Follow the marked thief and use your net at close range.")
			if state.raid.role == "thief" then
				item.Size = UDim2.new(1, 0, 0, 160)
				local cancel = button(item, "Abandon & return creature", function() send({ action = "CancelRaid" }, "cancel-raid") end, true)
				cancel.Position = UDim2.new(0, 16, 1, -54)
				cancel.Size = UDim2.fromOffset(268, 44)
				cancel.ZIndex = 24
				cancel.Name = "CancelRaid"
				enable(cancel, not pending["cancel-raid"])
			end
		end
	elseif currentPanel == "Settings" then
		local choices = {
			{ key = "ReducedMotion", title = "Gentle motion", text = "Reduce world bobbing and reward movement." },
			{ key = "LowEffects", title = "Lightweight effects", text = "Fewer particles and ambient details on slower devices." },
		}
		for _, choice in ipairs(choices) do
			local item = card(136)
			cardLabel(item, choice.title, 14, 10, -28, 25, 19, fonts.bold)
			cardLabel(item, choice.text, 14, 39, -28, 34, 13, fonts.body, palette.muted)
			local toggle = button(item, uiOptions[choice.key] and "On" or "Off", function()
				uiOptions[choice.key] = not uiOptions[choice.key]
				player:SetAttribute("Wildbound" .. choice.key, uiOptions[choice.key])
				if feedback then feedback:SetOptions(uiOptions) end
				renderPanel()
			end, not uiOptions[choice.key])
			toggle.Position = UDim2.new(1, -110, 1, -54)
			toggle.Size = UDim2.fromOffset(96, 44)
			toggle.ZIndex = 24
			toggle.Name = "Setting_" .. choice.key
		end
	else
		paragraph("1 · Follow the moving leaves", "Approach the flowerpot, select Berry, and offer a snack. Wait for the creature to trust you. Hold Sneak and use Befriend when it is ready.")
		paragraph("2 · Earn, learn, and explore", "Garden jobs provide repeatable coins. Photograph clues once for coins and research XP. Befriend three unique garden species to open the pond.")
		paragraph("3 · Choose your risk", "Store companions in your protected vault or display them for income while online. Weather changes who appears. Rare creatures may not return in the same session.")
		paragraph("Desktop controls", "Shift: hold Sneak · E: offer / befriend · P: photo · Q: recovery net · G: journey · J: journal · B: snacks · V: sanctuary · H: guide · Esc: close menu.")
		paragraph("Touch & controller", "Hold Sneak to approach gently. Tap your snack to switch Berry / Seed. Use the encounter button to offer or befriend; tap Photo near tracks. Menus support controller focus. Left trigger sneaks; X interacts; Y photographs.")
		paragraph("Progress saving", state.saving == "session" and "Studio progress lasts for this test session. Published games save your collection, coins, and research when data access is available." or state.saving == "error" and "Your latest save could not be confirmed. Stay connected and check again shortly; the server will retry safely." or state.saving == "loading" and "Your saved collection is still loading. Actions will unlock when it is ready." or "Your collection, coins, and research are saved by the game server.")
	end
	lastPanelKey = panelKey()
	if currentPanel then body.CanvasPosition = scrollPosition end
	if restoreSelection then
		local replacement = selectedName and body:FindFirstChild(selectedName, true)
		GuiService.SelectedObject = replacement and replacement:IsA("GuiObject") and replacement.Selectable and replacement or tabButtons[currentPanel]
	end
end

closePanel = function()
	currentPanel = nil
	modal.Visible = false
	scrim.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then GuiService.SelectedObject = nil end
end
openPanel = function(name)
	if currentPanel == name then closePanel(); return end
	currentPanel = name
	body.CanvasPosition = Vector2.zero
	scrim.Visible = true
	modal.Visible = true
	renderPanel()
	modal.Position = UDim2.fromScale(0.5, 0.5)
	if not uiOptions.ReducedMotion then
		modal.Position = UDim2.new(0.5, 0, 0.5, 8)
		TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = tabButtons[name] end
	if sneaking and Request then sneaking = false; Request:FireServer({ action = "Sneak", enabled = false }) end
end
scrim.Activated:Connect(closePanel)

send = function(payload, key)
	if not state or not Request then toast("Still connecting", "Your field journal is loading. Try again in a moment.", "info"); return end
	if state.saving == "loading" then toast("Collection loading", "Wait for your saved progress before taking an action.", "info"); return end
	key = key or payload.action
	if pending[key] then return end
	local sentAt = os.clock()
	pending[key] = sentAt
	local before = state
	pendingChecks[key] = function(nextState)
		local action = payload.action
		if action == "BuySnack" then return ((nextState.snacks or {})[payload.snack] or 0) > ((before.snacks or {})[payload.snack] or 0)
		elseif action == "UpgradeSanctuary" then return (nextState.sanctuaryLevel or 1) > (before.sanctuaryLevel or 1)
		elseif action == "EquipCompanion" then return nextState.equippedUid == payload.target
		elseif action == "SetDisplay" or action == "FeedCompanion" then
			for _, creature in ipairs(nextState.creatures or {}) do
				if creature.uid == payload.target then
					if action == "SetDisplay" then return creature.displayed == payload.displayed end
					for _, old in ipairs(before.creatures or {}) do if old.uid == payload.target then return (creature.bond or 0) > (old.bond or 0) or (creature.lastFed or 0) > (old.lastFed or 0) end end
				end
			end
		elseif action == "Lure" then return (nextState.lures or {})[payload.target] ~= nil
		elseif action == "Befriend" then return #(nextState.creatures or {}) > #(before.creatures or {}) or (nextState.lures or {})[payload.target] == nil
		elseif action == "Photo" then return (nextState.research or {})[payload.target] == true or (nextState.daily and nextState.daily.progress or 0) > (before.daily and before.daily.progress or 0)
		elseif action == "BeginRaid" then return nextState.raid ~= nil
		elseif action == "CancelRaid" then return nextState.raid == nil
		elseif action == "Net" then return nextState.raid == nil or (nextState.raid.netHits or 0) > (before.raid and before.raid.netHits or 0) end
		return false
	end
	Request:FireServer(payload)
	if currentPanel then renderPanel() end
	task.delay(4, function()
		if pending[key] == sentAt then pending[key] = nil; pendingChecks[key] = nil; if currentPanel then renderPanel() end end
	end)
end

local function setSneak(enabled)
	if sneaking == enabled then return end
	if enabled and (not state or currentPanel) then return end
	sneaking = enabled
	sneakButton.Text = enabled and "Sneaking…" or "Hold Sneak"
	sneakButton.BackgroundColor3 = enabled and palette.ink or palette.white
	sneakButton.TextColor3 = enabled and palette.white or palette.ink
	buttons[sneakButton].background = sneakButton.BackgroundColor3
	if Request then Request:FireServer({ action = "Sneak", enabled = enabled }) end
end
local heldTouch = nil
sneakButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then heldTouch = input; setSneak(true) end
end)
sneakButton.InputEnded:Connect(function(input)
	if input == heldTouch or input.UserInputType == Enum.UserInputType.MouseButton1 then heldTouch = nil; setSneak(false) end
end)
sneakButton.Activated:Connect(function(input)
	if input and input.UserInputType == Enum.UserInputType.Gamepad1 then setSneak(not sneaking) end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == heldTouch or input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.ButtonL2 then heldTouch = nil; setSneak(false) end
end)
UserInputService.WindowFocusReleased:Connect(function() heldTouch = nil; setSneak(false) end)
player.CharacterAdded:Connect(function() heldTouch = nil; setSneak(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Escape and currentPanel then closePanel(); return end
	if processed then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.G then openPanel("Journey")
	elseif key == Enum.KeyCode.J then openPanel("Journal")
	elseif key == Enum.KeyCode.B then openPanel("Shop")
	elseif key == Enum.KeyCode.V then openPanel("Sanctuary")
	elseif key == Enum.KeyCode.H then openPanel("Help")
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift or key == Enum.KeyCode.ButtonL2 then setSneak(true)
	elseif not currentPanel then
		if key == Enum.KeyCode.P or key == Enum.KeyCode.ButtonY then photograph()
		elseif key == Enum.KeyCode.Q and state and state.raid and state.raid.role == "defender" then send({ action = "Net", target = state.raid.opponentUserId }, "net")
		elseif (key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonX) and next(visiblePrompts) == nil and actionButton.Active then
			if nearestCreature then
				local entity = nearestCreature:GetAttribute("EntityId")
				if (state.lures or {})[entity] then send({ action = "Befriend", target = entity }, "encounter")
				else send({ action = "Lure", target = entity, snack = selectedSnack }, "encounter") end
			end
		end
	end
end)
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt:GetAttribute("WildboundHidden") then return end
	visiblePrompts[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt) visiblePrompts[prompt] = nil end)

responsive = function()
	local size = root.AbsoluteSize
	compact = size.X < 820 or size.Y < 550
	local mobile = UserInputService.TouchEnabled
	local margin = compact and 10 or 16
	local headWidth = compact and math.min(195, size.X * 0.47) or 216
	header.Position = UDim2.fromOffset(margin, compact and 4 or 12)
	header.Size = UDim2.fromOffset(headWidth, 56)
	wallet.Position = UDim2.new(1, -margin, 0, compact and 4 or 12)
	wallet.Size = UDim2.fromOffset(headWidth, 56)
	title.TextSize = compact and 20 or 22
	title.Position = UDim2.fromOffset(12, 3)
	weatherText.Position = UDim2.fromOffset(12, 32)
	weatherText.TextSize = compact and 11 or 12
	coinText.TextSize = compact and 18 or 20
	coinText.Position = UDim2.fromOffset(12, 2)
	levelText.Position = UDim2.fromOffset(12, 27)
	levelText.Size = UDim2.new(1, -24, 0, 20)
	levelText.TextSize = compact and 10 or 11
	coinDelta.Position = UDim2.new(1, -100, 0, 59)
	coinDelta.Size = UDim2.fromOffset(100, 22)
	coinDelta.TextSize = 12
	local collapsible = state and state.tutorialComplete == true
	local expanded = not collapsible or objectiveExpanded
	local objectiveHeight = expanded and (compact and 52 or 76) or 44
	objective.Position = UDim2.fromOffset(margin, compact and 66 or 80)
	objective.Size = UDim2.fromOffset(compact and math.min(340, size.X - margin * 2) or 360, objectiveHeight)
	objectiveToggle.Visible = collapsible
	objectiveToggle.Text = expanded and "−" or "+"
	objectiveTitle.Position = UDim2.fromOffset(12, expanded and (compact and 3 or 8) or 9)
	objectiveTitle.Size = UDim2.new(1, collapsible and -66 or -24, 0, expanded and 17 or 27)
	objectiveTitle.TextSize = expanded and (compact and 9 or 11) or 12
	objectiveText.Position = UDim2.fromOffset(12, compact and 20 or 27)
	objectiveText.Size = UDim2.new(1, collapsible and -66 or -24, 0, compact and 29 or 31)
	objectiveText.TextSize = compact and 13 or 15
	objectiveText.Visible = expanded
	objectiveCount.Position = UDim2.fromOffset(12, 59)
	objectiveCount.Visible = expanded and not compact
	navigation.Position = UDim2.fromOffset(margin, compact and (size.Y < 305 and 66 or 74 + objectiveHeight) or 88 + objectiveHeight)
	navigation.Size = UDim2.fromOffset(math.min(360, size.X - margin * 2), 46)
	journeyNav.Text = compact and "Journey" or "Journey · G"
	journalNav.Text = compact and "Journal" or "Journal · J"
	shopNav.Text = compact and "Snacks" or "Snacks · B"
	sanctuaryNav.Text = compact and "Home" or "Home · V"
	-- In landscape, the center strip sits between Roblox's movement/jump zones.
	-- Portrait touch screens move it above those zones instead.
	local bottom = compact and 12 or 20
	if mobile and size.X < size.Y then bottom = 140 end
	local narrowControls = size.X < 650
	local controlWidth = narrowControls and 264 or 356
	controls.Size = UDim2.fromOffset(controlWidth, 54)
	sneakButton.Size = UDim2.fromOffset(narrowControls and 84 or 110, 50)
	snackButton.Position = UDim2.fromOffset(narrowControls and 90 or 118, 0)
	snackButton.Size = UDim2.fromOffset(narrowControls and 90 or 116, 50)
	photoButton.Position = UDim2.fromOffset(narrowControls and 186 or 242, 0)
	photoButton.Size = UDim2.fromOffset(narrowControls and 78 or 114, 50)
	for _, control in ipairs({ sneakButton, snackButton, photoButton }) do control.TextSize = narrowControls and 12 or 15 end
	controls.Position = UDim2.new(0.5, 0, 1, -bottom)
	context.Position = UDim2.new(0.5, 0, 1, -bottom - 58)
	context.Size = UDim2.fromOffset(math.min(360, size.X - margin * 2), compact and 70 or 82)
	contextName.Position = UDim2.fromOffset(12, compact and 4 or 8)
	contextName.TextSize = compact and 13 or 15
	contextHint.Position = UDim2.fromOffset(12, compact and 25 or 30)
	contextHint.Size = UDim2.new(1, -150, 0, compact and 23 or 25)
	trustText.Position = UDim2.fromOffset(12, compact and 47 or 55)
	contextHint.TextSize = compact and 11 or 12
	actionButton.Size = UDim2.fromOffset(126, 44)
	actionButton.Position = UDim2.new(1, -10, 0.5, compact and 4 or 10)
	netButton.Position = UDim2.new(0.5, 0, 1, -bottom - 58)
	local modalWidth = math.min(740, size.X - margin * 2)
	local modalHeight = math.min(640, size.Y - margin * 2)
	modal.Size = UDim2.fromOffset(modalWidth, modalHeight)
	modalTitle.TextSize = compact and 23 or 27
	modalSubtitle.TextSize = compact and 11 or 13
	toastStack.Size = UDim2.fromOffset(math.min(380, size.X - 24), 250)
	toastStack.Position = UDim2.new(0.5, 0, 0, compact and 76 or 140)
	raidHud.Size = UDim2.fromOffset(math.min(380, size.X - margin * 2), compact and 106 or 114)
	raidHud.Position = UDim2.new(0.5, 0, 0, compact and 4 or 12)
	if currentPanel then renderPanel() end
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(responsive)
responsive()

local function capture(species, variant, newDiscovery)
	local data = Config and Config.Creatures[species]
	if not data then return end
	local reveal = frame(root, "Befriended", UDim2.fromOffset(320, 122), palette.paper)
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.46)
	reveal.ZIndex = 45
	border(reveal, palette.gold, 2)
	local picture = portrait(reveal, species, 96, true, variant)
	picture.Position = UDim2.fromOffset(12, 13)
	picture.ZIndex = 46
	for _, child in ipairs(picture:GetDescendants()) do if child:IsA("GuiObject") then child.ZIndex = 47 end end
	local heading = cardLabel(reveal, newDiscovery and "NEW DISCOVERY" or "BEFRIENDED", 124, 18, -136, 20, 11, fonts.bold, palette.success)
	heading.ZIndex = 47
	local name = cardLabel(reveal, data.Name, 124, 43, -136, 32, 24, fonts.title)
	name.ZIndex = 47
	local note = cardLabel(reveal, variantName(variant) .. " · safely in your vault", 124, 79, -136, 31, 12, fonts.body, palette.muted)
	note.ZIndex = 47
	local scale = create("UIScale", { Scale = uiOptions.ReducedMotion and 1 or 0.94 }, reveal)
	if not uiOptions.ReducedMotion then TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play() end
	task.delay(3, function() if reveal.Parent then reveal:Destroy() end end)
end

updateHUD = function()
	if not state then return end
	local newCoins = state.coins or 0
	if displayedCoins ~= newCoins then
		local delta = displayedCoins and newCoins - displayedCoins or 0
		if coinAnimation then coinAnimation:Cancel() end
		if displayedCoins == nil or uiOptions.ReducedMotion then coinCounter.Value = newCoins
		else
			coinAnimation = TweenService:Create(coinCounter, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = newCoins })
			coinAnimation:Play()
		end
		displayedCoins = newCoins
		if delta ~= 0 then
			coinDeltaVersion += 1
			local version = coinDeltaVersion
			coinDelta.Text = (delta > 0 and "+" or "") .. tostring(delta)
			coinDelta.TextColor3 = delta > 0 and palette.success or palette.amber
			coinDelta.Visible = true
			task.delay(1.8, function()
				if version == coinDeltaVersion then coinDelta.Visible = false end
			end)
		end
	end
	local xp = state.xp or 0
	local threshold = Config.LevelXP or 100
	levelText.Text = string.format("Taming %d · %d / %d XP", state.level or 1, xp % threshold, threshold)
	TweenService:Create(xpFill, TweenInfo.new(0.2), { Size = UDim2.fromScale((xp % threshold) / threshold, 1) }):Play()
	local goal = state.objective or {}
	objectiveTitle.Text = goal.title or "YOUR NEXT DISCOVERY"
	objectiveText.Text = goal.text or "Follow moving leaves. Offer a berry and approach gently."
	objectiveCount.Text = goal.progress ~= nil and string.format("Progress · %d / %d", goal.progress, goal.goal or 1) or state.pondUnlocked and "Pond trail open · explore further" or "Garden discoveries · " .. math.min(countKeys(state.discoveries), 3) .. "/3"
	for _, object in ipairs({ journeyNav, journalNav, shopNav, sanctuaryNav, snackButton, sneakButton, photoButton }) do enable(object, state.saving ~= "loading") end
	objectiveToggle.Visible = state.tutorialComplete == true
	if currentPanel and lastPanelKey ~= panelKey() then renderPanel() end
end

gui.Destroying:Connect(function()
	if feedback then feedback:Destroy(); feedback = nil end
end)

-- Wait without blocking a useful loading/error surface.
task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Wildbound", 30)
	if not shared then
		weatherText.Text = "Game server not connected"
		objectiveText.Text = "Check Rojo and Studio Output, then restart Play."
		toast("Game scripts missing", "Connect Rojo, wait for scripts to sync, then restart Play.", "error")
		return
	end
	local configModule = shared:WaitForChild("Config", 15)
	local remotes = shared:WaitForChild("Remotes", 15)
	if not configModule or not remotes then toast("Still loading", "The shared game scripts are not ready. Restart Play after Rojo finishes syncing.", "error"); return end
	Config = require(configModule)
	local visualModule = shared:WaitForChild("CreatureVisual", 10)
	if visualModule then CreatureVisual = require(visualModule) end
	local feedbackModule = script.Parent:FindFirstChild("Feedback")
	if feedbackModule and feedbackModule:IsA("ModuleScript") then
		local loaded, module = pcall(require, feedbackModule)
		if loaded and type(module) == "table" and type(module.Start) == "function" then
			local started, controller = pcall(module.Start, { Player = player, Gui = gui, Config = Config })
			if started then feedback = controller; feedback:SetOptions(uiOptions) end
		end
	end
	Request = remotes:WaitForChild("Request", 15)
	Update = remotes:WaitForChild("Update", 15)
	if not Request or not Update then toast("Connection incomplete", "Restart Play after all game scripts finish syncing.", "error"); return end
	Update.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then return end
		if feedback and message.kind ~= "State" then feedback:OnMessage(message) end
		if message.kind == "State" and type(message.state) == "table" then
			local tutorialChanged = state == nil or state.tutorialComplete ~= message.state.tutorialComplete
			state = message.state
			stateAt = os.clock()
			for key, check in pairs(pendingChecks) do
				if check(state) then pending[key] = nil; pendingChecks[key] = nil end
			end
			if feedback then feedback:OnState(state) end
			updateHUD()
			if tutorialChanged then responsive() end
		elseif message.kind == "Toast" then
			if message.tone == "error" then table.clear(pending); table.clear(pendingChecks) end
			toast(message.title, message.text, message.tone)
			if currentPanel then renderPanel() end
		elseif message.kind == "Panel" and tabButtons[message.panel] then
			if currentPanel ~= message.panel then openPanel(message.panel) end
		elseif message.kind == "Capture" then
			pending.encounter, pendingChecks.encounter = nil, nil
			capture(message.species, message.variant, message.newDiscovery)
		end
	end)
	Request:FireServer({ action = "Sync" })
	task.delay(10, function()
		if not state then toast("Journal still loading", "The server has not sent your progress yet. Check Studio Output for details.", "error"); Request:FireServer({ action = "Sync" }) end
	end)
end)

local scanParts = {}
local extractionPart = nil
local scanAt = 0
local tickAt = 0
local function distanceTo(part, origin)
	return (part.Position - origin).Magnitude
end
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - tickAt < 0.12 then return end
	tickAt = now
	if not state or not Config then
		enable(actionButton, false, "Loading…")
		return
	end
	local elapsed = now - stateAt
	for control, data in pairs(feedControls) do
		if control.Parent then
			local remaining = math.max(0, data.readyAt - now)
			local hasSnack = ((state.snacks or {})[data.snack] or 0) > 0
			local text = pending[data.key] and "Feeding…" or data.bond >= 100 and "Bond complete" or remaining > 0 and "Feed in " .. formatTime(remaining) or not hasSnack and "Need " .. data.snack or "Feed · " .. data.snack
			enable(control, data.available and not pending[data.key] and remaining <= 0 and hasSnack and data.bond < 100, text)
		else feedControls[control] = nil end
	end
	weatherText.Text = tostring(state.weather or "Clear") .. " · " .. formatTime((state.nextWeatherIn or 0) - elapsed)
	snackButton.Text = (Config.Snacks[selectedSnack].Name or selectedSnack) .. " · " .. tostring((state.snacks or {})[selectedSnack] or 0)
	sneakButton.Text = sneaking and "Sneaking…" or "Hold Sneak"
	sneakButton.BackgroundColor3 = sneaking and palette.ink or palette.white
	sneakButton.TextColor3 = sneaking and palette.white or palette.ink
	buttons[sneakButton].background = sneakButton.BackgroundColor3
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local origin = rootPart.Position
	local world = Workspace:FindFirstChild("WildboundWorld")
	if world and now - scanAt > 1 then
		scanAt = now
		table.clear(scanParts)
		for _, object in ipairs(world:GetDescendants()) do
			if object:IsA("BasePart") and (object:GetAttribute("ClueId") or object:GetAttribute("CreatureUid")) then table.insert(scanParts, object) end
			if object:IsA("BasePart") and object:GetAttribute("Action") == "Extraction" then extractionPart = object end
			if object:IsA("Model") then
				local tutorialOwner = object:GetAttribute("TutorialOwnerId")
				if tutorialOwner and tutorialOwner ~= player.UserId then
					for _, descendant in ipairs(object:GetDescendants()) do
						if descendant:IsA("BasePart") then descendant.LocalTransparencyModifier = 1
						elseif descendant:IsA("BillboardGui") or descendant:IsA("ParticleEmitter") then descendant.Enabled = false
						elseif descendant:IsA("ProximityPrompt") then descendant.Enabled = false end
					end
				end
			end
			if object:IsA("ProximityPrompt") and object.Name == "Interaction" and object.Parent and object.Parent:GetAttribute("EntityId") then
				object:SetAttribute("WildboundHidden", true)
				object.Enabled = false
				suppressCreaturePrompts[object] = true
				visiblePrompts[object] = nil
			end
		end
	end
	nearestCreature = nil
	nearestClue = nil
	nearestDisplay = nil
	local photographRange = (Config.PhotoRange or 18) + math.min(8, math.max(0, (state.level or 1) - 1) * 2)
	local creatureDistance, clueDistance, displayDistance = 17, photographRange, 12
	local creatures = world and world:FindFirstChild("Creatures")
	if creatures then
		for _, creature in ipairs(creatures:GetChildren()) do
			if creature:IsA("Model") and creature.PrimaryPart and creature:GetAttribute("EntityId") then
				local tutorialOwner = creature:GetAttribute("TutorialOwnerId")
				if not tutorialOwner or tutorialOwner == player.UserId then
					local distance = distanceTo(creature.PrimaryPart, origin)
					if distance < creatureDistance then nearestCreature = creature; creatureDistance = distance end
				end
			end
		end
	end
	for _, part in ipairs(scanParts) do
		if part.Parent then
			local distance = distanceTo(part, origin)
			if part:GetAttribute("ClueId") and distance < clueDistance then nearestClue = part; clueDistance = distance end
			if part:GetAttribute("CreatureUid") and part:GetAttribute("OwnerUserId") ~= player.UserId and distance < displayDistance then nearestDisplay = part; displayDistance = distance end
		end
	end
	local ready = state.saving ~= "loading" and not pending.encounter and not currentPanel
	if nearestCreature then
		local species = nearestCreature:GetAttribute("Species")
		local creatureData = Config.Creatures[species]
		local entity = nearestCreature:GetAttribute("EntityId")
		local lure = (state.lures or {})[entity]
		contextName.Text = (creatureData and creatureData.Name or "Wild creature") .. (nearestCreature:GetAttribute("Variant") and nearestCreature:GetAttribute("Variant") ~= "Normal" and " · " .. variantName(nearestCreature:GetAttribute("Variant")) or "")
		trustTrack.Visible = lure ~= nil
		trustText.Visible = lure ~= nil
		if lure then
			local remaining = math.max(0, (lure.readyIn or 0) - elapsed)
			local expires = math.max(0, (lure.expiresIn or 0) - elapsed)
			local trust = math.clamp(lure.trust or 0, 0, 1)
			trustFill.Size = UDim2.fromScale(trust, 1)
			trustText.Text = string.format("Trust %d%% · Catch %d%%", math.floor(trust * 100 + 0.5), math.floor((lure.chance or 0) * 100 + 0.5))
			contextHint.Text = expires <= 0 and "Snack expired. Offer another." or remaining > 0 and "Settling · " .. math.ceil(remaining) .. "s" or sneaking and "Approach gently · snack " .. math.ceil(expires) .. "s" or "Hold Sneak to build trust"
			local closeEnough = creatureDistance <= (Config.BefriendRange or 8)
			enable(actionButton, ready and expires > 0 and remaining <= 0 and closeEnough and sneaking, pending.encounter and "Trying…" or expires <= 0 and "Expired" or remaining > 0 and "Wait…" or not closeEnough and "Move closer" or not sneaking and "Hold Sneak" or compact and "Befriend" or "Befriend · E")
		else
			local snackCount = (state.snacks or {})[selectedSnack] or 0
			contextHint.Text = creatureData and (creatureData.Hint or "Offer a snack to lure it closer.") or "Offer a snack to lure it closer."
			local closeEnough = creatureDistance <= (Config.LureRange or 15)
			enable(actionButton, ready and snackCount > 0 and closeEnough, pending.encounter and "Offering…" or not closeEnough and "Move closer" or snackCount > 0 and "Offer " .. selectedSnack or "No snacks")
		end
	elseif nearestDisplay then
		trustTrack.Visible, trustText.Visible = false, false
		local species = nearestDisplay:GetAttribute("Species")
		contextName.Text = (Config.Creatures[species] and Config.Creatures[species].Name or "Companion") .. " · exposed"
		contextHint.Text = RunService:IsStudio() and "Practice a raid. The owner can recover it." or "Paid raids are unavailable in this version."
			local practice = RunService:IsStudio() and not (Config.Persistence and Config.Persistence.EnableInStudio)
			enable(actionButton, ready and practice and not state.raid, pending.encounter and "Starting…" or practice and "Practice raid" or "Unavailable")
	else
		trustTrack.Visible, trustText.Visible = false, false
		contextName.Text = "Explore the garden"
		contextHint.Text = "Watch for moving leaves. Use prompts for jobs."
		enable(actionButton, ready, "Field guide")
	end
	photoButton.Text = pending.photo and "Taking…" or nearestClue and (compact and "Photo" or "Photo · P") or "Find tracks"
	enable(photoButton, nearestClue ~= nil and not pending.photo and not currentPanel)
	local raid = state.raid
	extractionMarker.Enabled = raid ~= nil and raid.role == "thief" and raid.phase == "escape" and not currentPanel
	if extractionMarker.Enabled then extractionMarker.Adornee = extractionPart end
	raidHud.Visible = raid ~= nil and not currentPanel
	netButton.Visible = raid ~= nil and raid.role == "defender" and not currentPanel
	context.Visible = not currentPanel and not (raid and raid.role == "defender") and (nearestCreature ~= nil or nearestDisplay ~= nil or not state.tutorialComplete)
	controls.Visible = not currentPanel
	objective.Visible = (not raid or currentPanel ~= nil) and root.AbsoluteSize.Y >= 305
	navigation.Visible = not raid or currentPanel ~= nil
	header.Visible = raid == nil or currentPanel ~= nil
	wallet.Visible = raid == nil or currentPanel ~= nil
	if raid then
		local remaining = math.max(0, (raid.remaining or 0) - elapsed)
		raidTitle.Text = raid.role == "thief" and "RAID · " .. string.upper(raid.phase or "escape") or "RECOVER YOUR COMPANION"
		raidTimer.Text = formatTime(remaining)
		local opponent = Players:GetPlayerByUserId(raid.opponentUserId or 0)
		local opponentRoot = opponent and opponent.Character and opponent.Character:FindFirstChild("HumanoidRootPart")
		local inRange = opponentRoot and distanceTo(opponentRoot, origin) <= (Config.Raid.NetRange or 12)
		if raid.role == "defender" then
			raidDetail.Text = tostring(raid.opponentName or "A rival") .. " has " .. tostring(raid.creatureName or "your creature") .. ". Follow the marker."
			enable(netButton, inRange ~= nil and inRange and not pending.net, pending.net and "Net readying…" or inRange and "Throw net · Q" or "Get closer to net")
			raidMarker.Adornee = opponent and opponent.Character or nil
			raidMarker.Enabled = opponent ~= nil
		else
			raidMarker.Enabled = false
			if raid.phase == "stealing" then raidDetail.Text = "Hold your ground. The owner can interrupt you."
			elseif raid.phase == "escape" and raid.extraction then
				local position = Vector3.new(raid.extraction.x, raid.extraction.y, raid.extraction.z)
				raidDetail.Text = "Reach the extraction arch · " .. math.ceil((position - origin).Magnitude) .. " studs"
			else raidDetail.Text = "Stay alive and connected. Ownership is still pending." end
		end
		raidHits.Text = string.format("NET HITS · %d / %d   ·   Studio test · no Robux", raid.netHits or 0, raid.netHitsRequired or 3)
	else raidMarker.Enabled = false end
	for prompt in pairs(visiblePrompts) do if not prompt.Parent or not prompt.Enabled then visiblePrompts[prompt] = nil end end
end)

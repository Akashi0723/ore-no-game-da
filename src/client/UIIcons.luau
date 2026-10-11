-- Small vector icons made from native GuiObjects. No downloaded images or asset IDs.
local Icons = {}

function Icons.Draw(parent, kind, color, zIndex)
	local root = Instance.new("Frame")
	root.Name = "Icon_" .. kind
	root.Size = UDim2.fromOffset(30, 30)
	root.BackgroundTransparency = 1
	root.ZIndex = zIndex or parent.ZIndex + 1
	root.Parent = parent
	local function shape(x, y, w, h, radius, rotation, tint)
		local part = Instance.new("Frame")
		part.BackgroundColor3 = tint or color
		part:SetAttribute("IconTintable", tint == nil)
		part.BorderSizePixel = 0
		part.Position = UDim2.fromScale(x, y)
		part.Size = UDim2.fromScale(w, h)
		part.Rotation = rotation or 0
		part.ZIndex = root.ZIndex
		part.Parent = root
		if radius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(radius, 0)
			corner.Parent = part
		end
		return part
	end
	local function ring(x, y, w, h, thickness, radius, rotation)
		local part = shape(x, y, w, h, radius or 0.5, rotation)
		part.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = thickness or 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = part
		return part
	end
	local function cutout(x, y, w, h, radius, rotation)
		local part = shape(x, y, w, h, radius, rotation, parent.BackgroundColor3)
		part:SetAttribute("IconCutout", true)
		return part
	end
	if kind == "coin" then
		shape(0.12, 0.12, 0.76, 0.76, 0.5)
		ring(0.22, 0.22, 0.56, 0.56, 2)
		shape(0.44, 0.31, 0.12, 0.38, 0.2, 0, Color3.fromRGB(105, 61, 19))
	elseif kind == "paw" then
		shape(0.23, 0.47, 0.55, 0.39, 0.45)
		shape(0.12, 0.22, 0.19, 0.25, 0.5, -25)
		shape(0.33, 0.09, 0.18, 0.26, 0.5, -8)
		shape(0.56, 0.1, 0.18, 0.26, 0.5, 8)
		shape(0.77, 0.24, 0.18, 0.24, 0.5, 25)
	elseif kind == "book" then
		ring(0.1, 0.2, 0.8, 0.65, 2.5, 0.08)
		shape(0.47, 0.18, 0.06, 0.7)
		shape(0.2, 0.34, 0.18, 0.06, 0.5)
		shape(0.2, 0.49, 0.18, 0.06, 0.5)
		shape(0.62, 0.34, 0.18, 0.06, 0.5)
		shape(0.62, 0.49, 0.18, 0.06, 0.5)
	elseif kind == "bag" then
		ring(0.16, 0.31, 0.68, 0.56, 2.5, 0.12)
		ring(0.33, 0.12, 0.34, 0.34, 2.5, 0.4)
		shape(0.29, 0.51, 0.42, 0.06, 0.5)
	elseif kind == "home" then
		shape(0.25, 0.15, 0.5, 0.5, 0.08, 45)
		shape(0.19, 0.43, 0.62, 0.45, 0.08)
		cutout(0.41, 0.6, 0.18, 0.28, 0.08)
	elseif kind == "berry" then
		shape(0.21, 0.38, 0.39, 0.42, 0.5)
		shape(0.43, 0.37, 0.4, 0.42, 0.5)
		shape(0.34, 0.54, 0.37, 0.37, 0.5)
		shape(0.42, 0.16, 0.34, 0.19, 0.5, -32, Color3.fromRGB(144, 226, 91))
	elseif kind == "seed" then
		shape(0.22, 0.25, 0.28, 0.58, 0.5, 30)
		shape(0.55, 0.3, 0.25, 0.51, 0.5, -28)
	elseif kind == "camera" then
		shape(0.12, 0.31, 0.76, 0.52, 0.12)
		shape(0.28, 0.19, 0.34, 0.2, 0.12)
		cutout(0.35, 0.41, 0.3, 0.3, 0.5)
		ring(0.34, 0.4, 0.32, 0.32, 2.5)
		cutout(0.73, 0.4, 0.07, 0.07, 0.5)
	elseif kind == "sneak" then
		shape(0.29, 0.15, 0.29, 0.54, 0.35, 18)
		shape(0.46, 0.65, 0.32, 0.22, 0.35, 18)
		shape(0.12, 0.25, 0.11, 0.11, 0.5)
		shape(0.2, 0.1, 0.11, 0.11, 0.5)
	elseif kind == "net" then
		ring(0.12, 0.08, 0.59, 0.59, 2.5)
		shape(0.55, 0.6, 0.13, 0.38, 0.3, -37)
		for index = 1, 2 do
			shape(0.15, 0.15 + index * 0.12, 0.49, 0.035, nil, 12)
			shape(0.22 + index * 0.12, 0.12, 0.035, 0.48, nil, 12)
		end
	elseif kind == "flag" then
		shape(0.2, 0.12, 0.09, 0.79, 0.2)
		shape(0.29, 0.16, 0.5, 0.34, 0.06)
		shape(0.09, 0.84, 0.32, 0.07, 0.4)
	elseif kind == "gear" then
		for index = 0, 3 do
			shape(0.42, 0.09, 0.16, 0.82, 0.2, index * 45)
		end
		shape(0.18, 0.18, 0.64, 0.64, 0.5)
		cutout(0.37, 0.37, 0.26, 0.26, 0.5)
	elseif kind == "star" then
		shape(0.37, 0.13, 0.26, 0.74, 0.08)
		shape(0.13, 0.37, 0.74, 0.26, 0.08)
		shape(0.3, 0.3, 0.4, 0.4, 0.06, 45)
	elseif kind == "sun" then
		for index = 0, 3 do shape(0.46, 0.03, 0.08, 0.94, 0.2, index * 45) end
		shape(0.23, 0.23, 0.54, 0.54, 0.5)
	elseif kind == "rain" then
		shape(0.13, 0.2, 0.72, 0.31, 0.5)
		shape(0.26, 0.12, 0.36, 0.34, 0.5)
		for index = 0, 2 do shape(0.23 + index * 0.22, 0.63, 0.07, 0.23, 0.5, 20) end
	elseif kind == "moon" then
		shape(0.15, 0.1, 0.72, 0.76, 0.5)
		cutout(0.44, 0.04, 0.54, 0.64, 0.5)
	elseif kind == "fog" then
		for index = 0, 2 do shape(0.12 + index * 0.04, 0.23 + index * 0.22, 0.77 - index * 0.08, 0.08, 0.5) end
	elseif kind == "close" then
		shape(0.43, 0.12, 0.14, 0.76, 0.25, 45)
		shape(0.43, 0.12, 0.14, 0.76, 0.25, -45)
	elseif kind == "search" then
		ring(0.12, 0.12, 0.55, 0.55, 2.5)
		shape(0.62, 0.6, 0.1, 0.34, 0.25, -45)
	elseif kind == "check" then
		shape(0.18, 0.45, 0.13, 0.36, 0.2, -40)
		shape(0.45, 0.22, 0.13, 0.62, 0.2, 40)
	else
		ring(0.13, 0.13, 0.74, 0.74, 2.5)
		shape(0.45, 0.27, 0.1, 0.29, 0.4)
		shape(0.45, 0.67, 0.1, 0.1, 0.5)
	end
	local backgroundConnection = parent:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		for _, part in ipairs(root:GetChildren()) do
			if part:IsA("Frame") and part:GetAttribute("IconCutout") then part.BackgroundColor3 = parent.BackgroundColor3 end
		end
	end)
	root.Destroying:Connect(function() backgroundConnection:Disconnect() end)
	return root
end

function Icons.Tint(icon, color)
	for _, object in ipairs(icon:GetDescendants()) do
		if object:IsA("Frame") and object:GetAttribute("IconTintable") then object.BackgroundColor3 = color end
		if object:IsA("UIStroke") then object.Color = color end
	end
end

return Icons

-- The interface kit (V11): one look for the wardrobe, the emote wheel and the raid results, from the art direction's
-- palette (docs/ART_DIRECTION.md): a dark-wood frame, parchment cards, goblin gold for anything good, chunky rounded
-- type. Buttons are large, work with mouse, touch and gamepad (they are Selectable and show a gold ring when the
-- gamepad is on them), and acknowledge every press.
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = {}

local rgb = Color3.fromRGB
Ui.C = {
	wood = rgb(74, 46, 30),
	woodMid = rgb(108, 70, 44),
	woodLight = rgb(150, 98, 58),
	parchment = rgb(244, 232, 204),
	parchmentDark = rgb(222, 204, 166),
	ink = rgb(56, 36, 24),
	inkSoft = rgb(110, 84, 62),
	gold = rgb(255, 196, 46),
	goldDeep = rgb(214, 150, 30),
	goldPale = rgb(255, 232, 150),
	danger = rgb(232, 64, 52),
	good = rgb(96, 190, 84),
	sea = rgb(32, 104, 146),
	white = rgb(255, 255, 255),
	night = rgb(20, 16, 22),
	premium = rgb(90, 226, 176),
}
Ui.TITLE = Enum.Font.FredokaOne
Ui.BOLD = Enum.Font.GothamBold
Ui.BLACK = Enum.Font.GothamBlack
Ui.BODY = Enum.Font.GothamMedium

function Ui.make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

function Ui.corner(parent, radius)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function Ui.stroke(parent, color, thickness, transparency)
	return Ui.make("UIStroke", {
		Color = color or Ui.C.wood,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Ui.pad(parent, all, top, right, bottom)
	return Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingTop = UDim.new(0, top or all),
		PaddingRight = UDim.new(0, right or all),
		PaddingBottom = UDim.new(0, bottom or top or all),
	}, parent)
end

function Ui.label(parent, props)
	local label = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.BOLD,
		TextColor3 = Ui.C.ink,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
	for key, value in pairs(props or {}) do
		label[key] = value
	end
	return label
end

-- A Shinies amount with its little gold gem, e.g. Ui.shinies(parent, 120, 18).
function Ui.gem(parent, size, position)
	local gem = Ui.make("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = 45,
		BackgroundColor3 = Ui.C.gold,
		BorderSizePixel = 0,
	}, parent)
	Ui.make("UIGradient", {
		Color = ColorSequence.new(Ui.C.goldPale, Ui.C.goldDeep),
		Rotation = 90,
	}, gem)
	Ui.make("UIStroke", { Color = Ui.C.ink, Thickness = 1.5 }, gem)
	return gem
end

-- The selection ring the gamepad shows on a focused button.
local function selectionRing()
	local ring = Instance.new("ImageLabel")
	ring.Name = "SelectionRing"
	ring.BackgroundTransparency = 1
	ring.Image = ""
	ring.Size = UDim2.fromScale(1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ui.C.gold
	stroke.Thickness = 4
	stroke.Parent = ring
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = ring
	return ring
end

-- A chunky button. style: "gold" (the main action), "wood", "parchment", "premium", "ghost" (quiet).
local STYLES = {
	gold = { back = Ui.C.gold, text = Ui.C.ink, edge = Ui.C.goldDeep },
	wood = { back = Ui.C.woodMid, text = Ui.C.parchment, edge = Ui.C.wood },
	parchment = { back = Ui.C.parchment, text = Ui.C.ink, edge = Ui.C.woodLight },
	premium = { back = Ui.C.premium, text = Ui.C.night, edge = rgb(40, 150, 110) },
	good = { back = Ui.C.good, text = Ui.C.white, edge = rgb(60, 130, 50) },
	ghost = { back = Ui.C.parchmentDark, text = Ui.C.inkSoft, edge = Ui.C.parchmentDark },
	danger = { back = Ui.C.danger, text = Ui.C.white, edge = rgb(160, 40, 30) },
}
Ui.STYLES = STYLES
local edges = setmetatable({}, { __mode = "k" }) -- button -> its edge stroke

-- Restyles a button made by Ui.button (enabled/disabled look, a different action).
function Ui.setStyle(button, name)
	local s = STYLES[name]
	button.BackgroundColor3 = s.back
	button.TextColor3 = s.text
	local edge = edges[button]
	if edge then
		edge.Color = s.edge
	end
end

function Ui.button(parent, props, onClick)
	local style = STYLES[props.style or "gold"]
	local button = Ui.make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = style.back,
		BorderSizePixel = 0,
		Font = props.font or Ui.TITLE,
		Text = props.text or "",
		TextColor3 = style.text,
		TextSize = props.textSize or 20,
		TextWrapped = true,
		Size = props.size or UDim2.fromOffset(160, 48),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(),
		LayoutOrder = props.order or 0,
		SelectionImageObject = selectionRing(),
		Name = props.name or "Button",
	}, parent)
	Ui.corner(button, props.radius or 12)
	local edge = Ui.stroke(button, style.edge, 2)
	local scale = Ui.make("UIScale", { Scale = 1 }, button)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if onClick then
			onClick(button)
		end
	end)
	edges[button] = edge
	return button
end

-- A 3D stage: a ViewportFrame with a world and a camera. Returns { frame, world, camera }.
function Ui.viewport(parent, props)
	local frame = Ui.make("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = props and props.size or UDim2.fromScale(1, 1),
		Position = props and props.position or UDim2.new(),
		Ambient = rgb(176, 168, 176),
		LightColor = rgb(255, 242, 222),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
	}, parent)
	local world = Ui.make("WorldModel", {}, frame)
	local camera = Ui.make("Camera", { FieldOfView = props and props.fov or 30 }, frame)
	frame.CurrentCamera = camera
	return { frame = frame, world = world, camera = camera }
end

-- Points a viewport camera at a box: centre, size (a Vector3), from a yaw and pitch (degrees).
function Ui.frameBox(camera, center, size, yaw, pitch, margin)
	local radius = math.max(size.X, size.Y, size.Z) * 0.5 * (margin or 1.15)
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2))
	local direction = (CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.Angles(math.rad(-(pitch or 10)), 0, 0)).LookVector
	camera.CFrame = CFrame.lookAt(center - direction * distance, center)
end

-- What input the goblin is using now: "gamepad", "touch" or "keyboard".
function Ui.inputKind()
	local last = UserInputService:GetLastInputType()
	if last.Name:sub(1, 7) == "Gamepad" then
		return "gamepad"
	elseif last == Enum.UserInputType.Touch then
		return "touch"
	end
	return "keyboard"
end

function Ui.focus(object)
	if Ui.inputKind() == "gamepad" and object then
		GuiService.SelectedObject = object
	end
end

return Ui

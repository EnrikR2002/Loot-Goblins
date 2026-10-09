-- The world map (hold or tap M). Islands from the shared Archipelago list, where every treasure is
-- and what state it is in (waiting, carried, loose, banked), live storms, the Hoard and you. It
-- shows the sea, never other players' positions: you still have to look for rivals. Also draws the
-- compass strip along the top of the screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Weather = require(script.Parent.Weather)

local Map = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(16, 16, 22)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 50)

local MAP_W, MAP_H = 700, 600
local panel, canvas, youMarker
local islandViews = {}
local lootViews = {}
local stormViews = {}
local hoardMarker
local hoardPosition
local visible = false

-- Compass
local COMPASS_FOV = 170
local compass
local compassLoot = {}
local compassHoard, compassStorm = nil, {}
local cardinals = {}

local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
local spanX, spanZ = max.X - min.X, max.Z - min.Z

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function toMap(x, z)
	return UDim2.fromScale((x - min.X) / spanX, (z - min.Z) / spanZ)
end

local function lootFolder()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("Loot")
end

-- Where a treasure is right now: its live position if it is loose or carried (and streamed in), else
-- its island.
local function lootPosition(def, state, folder)
	if state == "carried" or state == "loose" then
		local model = folder and folder:FindFirstChild(def.id)
		local core = model and model.PrimaryPart
		if core then
			return core.Position.X, core.Position.Z
		end
	end
	local island = Archipelago.byId[def.island]
	return island.x, island.z
end

function Map.build(gui, hoard)
	hoardPosition = hoard
	panel = make("Frame", {
		Name = "WorldMap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(MAP_W + 24, MAP_H + 56),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	make("UIStroke", { Color = GOLD, Thickness = 2 }, panel)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 22),
		Font = Enum.Font.GothamBlack,
		Text = "THE GOBLIN SEA        (M closes)",
		TextColor3 = GOLD,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	}, panel)
	canvas = make("Frame", {
		Name = "Canvas",
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.fromOffset(MAP_W, MAP_H),
		BackgroundColor3 = Color3.fromRGB(30, 110, 150),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 21,
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, canvas)

	for _, island in ipairs(Archipelago.islands) do
		local size = math.max(10, island.r * 2 / spanX * MAP_W * 0.8)
		local dot = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(island.x, island.z),
			Size = UDim2.fromOffset(size, size * (spanX / spanZ) * (MAP_H / MAP_W)),
			BackgroundColor3 = island.color:Lerp(Color3.fromRGB(70, 150, 90), 0.45),
			BorderSizePixel = 0,
			ZIndex = 22,
		}, canvas)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		make("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 1),
			Size = UDim2.fromOffset(120, 12),
			Font = Enum.Font.GothamBold,
			Text = island.name,
			TextColor3 = WHITE,
			TextStrokeTransparency = 0.3,
			TextSize = 9,
			ZIndex = 23,
		}, dot)
		islandViews[island.id] = dot
	end
	hoardMarker = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(hoard.X, hoard.Z),
		Size = UDim2.fromOffset(54, 16),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		Text = "HOARD",
		TextColor3 = DARK,
		TextSize = 11,
		ZIndex = 26,
	}, canvas)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, hoardMarker)

	for _, def in ipairs(Config.LOOT) do
		local dot = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = def.color,
			Font = Enum.Font.GothamBlack,
			Text = tostring(def.value),
			TextColor3 = DARK,
			TextSize = 12,
			ZIndex = 27,
		}, canvas)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		make("UIStroke", { Color = WHITE, Thickness = 1.5 }, dot)
		lootViews[def.id] = dot
	end
	for i = 1, 4 do
		local view = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 38, 52),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 24,
		}, canvas)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, view)
		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.GothamBlack,
			Text = "STORM",
			TextColor3 = Color3.fromRGB(210, 220, 255),
			TextSize = 11,
			ZIndex = 25,
		}, view)
		stormViews[i] = view
	end
	youMarker = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "^",
		TextColor3 = Color3.fromRGB(120, 255, 170),
		TextStrokeTransparency = 0,
		TextSize = 24,
		ZIndex = 30,
	}, canvas)
	make("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -6),
		Size = UDim2.new(1, -28, 0, 16),
		Font = Enum.Font.GothamMedium,
		Text = "Numbers are gold. Bright = waiting, pulsing = being carried, grey = banked. Higher gold is deeper in.",
		TextColor3 = Color3.fromRGB(190, 190, 200),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	}, panel)

	-- Compass strip.
	compass = make("Frame", {
		Name = "Compass",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(560, 28),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, compass)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, compass)
	for i, letter in ipairs({ "N", "E", "S", "W" }) do
		cardinals[i] = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = letter,
			TextColor3 = i == 1 and Color3.fromRGB(255, 120, 110) or Color3.fromRGB(210, 210, 220),
			TextSize = 15,
		}, compass)
	end
	compassHoard = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(70, 20),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextColor3 = DARK,
		TextSize = 12,
		ZIndex = 3,
	}, compass)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, compassHoard)
	for _, def in ipairs(Config.LOOT) do
		local dot = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(24, 18),
			BackgroundColor3 = def.color,
			Font = Enum.Font.GothamBlack,
			Text = tostring(def.value),
			TextColor3 = DARK,
			TextSize = 12,
			ZIndex = 2,
		}, compass)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, dot)
		compassLoot[def.id] = dot
	end
	for i = 1, 3 do
		compassStorm[i] = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(46, 18),
			BackgroundColor3 = Color3.fromRGB(60, 66, 90),
			Font = Enum.Font.GothamBlack,
			Text = "STORM",
			TextColor3 = Color3.fromRGB(215, 225, 255),
			TextSize = 10,
			Visible = false,
		}, compass)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, compassStorm[i])
	end
end

function Map.toggle()
	visible = not visible
	panel.Visible = visible
end

local function wrap(degrees)
	return (degrees + 180) % 360 - 180
end

-- Places a compass marker for a world point, or hides it if it is behind you.
local function place(label, heading, x, z, from)
	local bearing = math.deg(math.atan2(x - from.X, -(z - from.Z)))
	local delta = wrap(bearing - heading)
	if math.abs(delta) > COMPASS_FOV / 2 - 4 then
		label.Visible = false
		return false
	end
	label.Visible = true
	label.Position = UDim2.fromScale(0.5 + delta / COMPASS_FOV, 0.5)
	return true
end

function Map.update(now)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = lootFolder()
	local carrying = player:GetAttribute("CarryingLoot")
	if camera and root then
		local look = camera.CFrame.LookVector
		local heading = math.deg(math.atan2(look.X, -look.Z))
		local from = root.Position
		for i, bearing in ipairs({ 0, 90, 180, 270 }) do
			local delta = wrap(bearing - heading)
			local show = math.abs(delta) < COMPASS_FOV / 2 - 4
			cardinals[i].Visible = show
			cardinals[i].Position = UDim2.fromScale(0.5 + delta / COMPASS_FOV, 0.5)
		end
		if hoardPosition then
			if place(compassHoard, heading, hoardPosition.X, hoardPosition.Z, from) then
				compassHoard.Text = "HOARD "
					.. math.floor(
						(Vector3.new(hoardPosition.X, 0, hoardPosition.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
					)
				compassHoard.Size = carrying and UDim2.fromOffset(96, 22) or UDim2.fromOffset(86, 20)
			end
		end
		for _, def in ipairs(Config.LOOT) do
			local label = compassLoot[def.id]
			local state = folder and folder:GetAttribute(def.id .. "State") or "spot"
			if
				state == "away" or (state == "carried" and folder:GetAttribute(def.id .. "CarrierId") == player.UserId)
			then
				label.Visible = false
			else
				local x, z = lootPosition(def, state, folder)
				if place(label, heading, x, z, from) then
					label.BackgroundTransparency = state == "spot" and 0.15 or 0
					local pulse = state == "loose" and (math.sin(now * 8) > 0)
					label.TextColor3 = pulse and Color3.fromRGB(255, 80, 80) or DARK
				end
			end
		end
		local i = 0
		for _, cell in pairs(Weather.cells()) do
			i += 1
			if compassStorm[i] then
				local dt = math.clamp(now - (cell.t or now), 0, 2)
				if place(compassStorm[i], heading, cell.x + cell.vx * dt, cell.z + cell.vz * dt, from) then
					compassStorm[i].Text = cell.fog and "FOG" or "STORM"
				end
			end
		end
		for k = i + 1, #compassStorm do
			compassStorm[k].Visible = false
		end
	end

	if not visible then
		return
	end
	for _, def in ipairs(Config.LOOT) do
		local view = lootViews[def.id]
		local state = folder and folder:GetAttribute(def.id .. "State") or "spot"
		local x, z = lootPosition(def, state, folder)
		local island = Archipelago.byId[def.island]
		-- Several treasures never share an island, but nudge so the label clears the island name.
		view.Position = toMap(x, z + (state == "spot" and -island.r * 0.25 or 0))
		local mine = state == "carried" and folder:GetAttribute(def.id .. "CarrierId") == player.UserId
		view.BackgroundTransparency = state == "away" and 0.75 or 0
		view.Size = (state == "carried" or state == "loose")
				and UDim2.fromOffset(28 + math.floor(math.sin(now * 6) * 2), 28)
			or UDim2.fromOffset(22, 22)
		view.BackgroundColor3 = state == "away" and Color3.fromRGB(110, 110, 120) or (mine and GOLD or def.color)
		local bonus = folder and folder:GetAttribute(def.id .. "Bonus") or 0
		view.Text = tostring(def.value + (bonus or 0))
	end
	local i = 0
	for _, cell in pairs(Weather.cells()) do
		i += 1
		local view = stormViews[i]
		if view then
			local dt = math.clamp(now - (cell.t or now), 0, 2)
			view.Visible = true
			view.Position = toMap(cell.x + cell.vx * dt, cell.z + cell.vz * dt)
			local size = cell.r * 2 / spanX * MAP_W
			view.Size = UDim2.fromOffset(size, size * (spanX / spanZ) * (MAP_H / MAP_W))
			view.BackgroundColor3 = cell.fog and Color3.fromRGB(200, 215, 220) or Color3.fromRGB(35, 38, 52)
		end
	end
	for k = i + 1, #stormViews do
		stormViews[k].Visible = false
	end
	if root then
		youMarker.Position = toMap(root.Position.X, root.Position.Z)
		local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
		youMarker.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
end

return Map

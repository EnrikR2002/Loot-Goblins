-- The minimap (V9): local orientation at a glance, top right. The world map (M) is for planning; this is
-- for steering. It turns with the camera (up is where you are looking), shows about MINIMAP.RANGE studs
-- round you, and draws:
--   * the islands (from the shared Archipelago list, so it can never disagree with the world) and the name
--     of the one you are at, under the map: this is where island names went when they left the horizon
--   * the Hoard, and the sanctuary's ring of lights round Goblin Cove; when the Hoard is off the map it sits
--     on the rim as an arrow, gold and pulsing while you carry treasure
--   * treasure waiting nearby (not what others carry: you still have to look for rivals)
--   * tornadoes (they are something to steer for, or away from)
--   * whatever is chasing YOU, as a red pip: no other threats (it is not a radar)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Archipelago = require(Shared:WaitForChild("Archipelago"))
local Twisters = require(script.Parent.Twisters)

local Minimap = {}

local player = Players.LocalPlayer
local RANGE = 1100 -- studs from the middle to the rim
local SIZE = 184 -- pixels across
local R = SIZE / 2
local GOLD = Color3.fromRGB(255, 205, 50)
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(16, 16, 22)
local CHASER = Color3.fromRGB(255, 60, 50)

local gui, scaler, canvas, rim, hoardDot, hoardArrow, sanctuaryRing, northMark, placeLabel
local islandDots = {}
local lootDots = {}
local twisterDots = {}
local chaserDots = {}
local hoardPosition
local nextUpdate = 0

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function circle(parent, size, color, transparency, z)
	local dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Visible = false,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	return dot
end

local function lootFolder()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("Loot")
end

local function threatsFolder()
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	return generated and generated:FindFirstChild("Threats")
end

function Minimap.build(hoard)
	hoardPosition = hoard
	gui = make("ScreenGui", {
		Name = "LootGoblinsMinimap",
		ResetOnSpawn = false,
		DisplayOrder = 2,
	}, player:WaitForChild("PlayerGui"))
	local holder = make("Frame", {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(SIZE, SIZE + 22),
		BackgroundTransparency = 1,
	}, gui)
	scaler = make("UIScale", {}, holder)
	-- A rounded square that clips what it draws. (A round CanvasGroup was tried first: on some graphics settings a
	-- CanvasGroup is drawn ungrouped and clips nothing, and big islands spilled past the rim.)
	canvas = make("Frame", {
		Name = "Sea",
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Color3.fromRGB(28, 96, 132),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, canvas)
	rim = make("Frame", {
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, rim)
	make("UIStroke", { Color = Color3.fromRGB(230, 220, 190), Thickness = 2.5, Transparency = 0.1 }, rim)

	for _, island in ipairs(Archipelago.islands) do
		local dot = circle(canvas, 10, island.color:Lerp(Color3.fromRGB(70, 150, 90), 0.5), 0, 2)
		make("UIStroke", { Color = island.color, Thickness = 1, Transparency = 0.3 }, dot)
		islandDots[island.id] = { dot = dot, island = island }
	end
	sanctuaryRing = circle(canvas, 10, GOLD, 1, 3)
	make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.35 }, sanctuaryRing)
	hoardDot = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		Text = "H",
		TextColor3 = DARK,
		TextSize = 11,
		ZIndex = 6,
		Visible = false,
	}, canvas)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, hoardDot)
	for _, def in ipairs(Config.LOOT) do
		local dot = circle(canvas, 7, def.color, 0, 4)
		make("UIStroke", { Color = DARK, Thickness = 1 }, dot)
		lootDots[def.id] = dot
	end
	for i = 1, Config.TWISTER.MAX + 1 do
		local dot = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "@",
			TextColor3 = Color3.fromRGB(220, 230, 255),
			TextStrokeTransparency = 0.2,
			TextSize = 15,
			ZIndex = 5,
			Visible = false,
		}, canvas)
		twisterDots[i] = dot
	end
	for i = 1, 8 do
		local dot = circle(canvas, 8, CHASER, 0, 7)
		make("UIStroke", { Color = WHITE, Thickness = 1 }, dot)
		chaserDots[i] = dot
	end
	-- You: the middle, pointing up (the map turns, you do not).
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "^",
		TextColor3 = Color3.fromRGB(120, 255, 170),
		TextStrokeTransparency = 0,
		TextSize = 22,
		ZIndex = 8,
	}, holder)
	-- The Hoard when it is off the map: an arrow on the rim.
	hoardArrow = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "^",
		TextColor3 = GOLD,
		TextStrokeTransparency = 0,
		TextSize = 24,
		ZIndex = 9,
		Visible = false,
	}, holder)
	northMark = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		Font = Enum.Font.GothamBlack,
		Text = "N",
		TextColor3 = Color3.fromRGB(255, 120, 110),
		TextSize = 11,
		ZIndex = 9,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, northMark)
	placeLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, SIZE + 3),
		Size = UDim2.fromOffset(SIZE + 60, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.2,
		TextSize = 13,
	}, holder)
	RunService.RenderStepped:Connect(function()
		Minimap.update()
	end)
end

-- Where a world point goes on the map: pixels from the middle, given the camera's flat forward and right.
local function toMap(x, z, from, forward, right)
	local dx, dz = x - from.X, z - from.Z
	local sx = (dx * right.X + dz * right.Z) / RANGE * R
	local sy = -(dx * forward.X + dz * forward.Z) / RANGE * R
	return sx, sy
end

local function put(view, sx, sy, margin)
	local edge = R - (margin or 0)
	local inside = math.abs(sx) <= edge and math.abs(sy) <= edge
	view.Visible = inside
	if inside then
		view.Position = UDim2.fromOffset(R + sx, R + sy)
	end
	return inside
end

function Minimap.update()
	if not gui then
		return
	end
	local t = os.clock()
	if t < nextUpdate then
		return
	end
	nextUpdate = t + 1 / 30
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local viewport = camera.ViewportSize
	scaler.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.6, 1.1)
	local from = root.Position
	-- High up (the skyship, a flight) the minimap is no help; the aim view and the map are.
	local high = from.Y > 260
	gui.Enabled = not high
	if high then
		return
	end
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = forward.Magnitude > 0.05 and forward.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local carrying = player:GetAttribute("CarryingLoot") ~= nil
	-- Islands, and the one you are at.
	local here, hereDistance = nil, math.huge
	for _, entry in pairs(islandDots) do
		local island = entry.island
		local sx, sy = toMap(island.x, island.z, from, forward, right)
		local size = math.max(6, island.r * 2 / RANGE * R)
		entry.dot.Size = UDim2.fromOffset(size, size)
		put(entry.dot, sx, sy, -size / 2)
		local distance = math.sqrt((island.x - from.X) ^ 2 + (island.z - from.Z) ^ 2)
		if distance < island.r + 220 and distance - island.r < hereDistance then
			here, hereDistance = island, distance - island.r
		end
	end
	if here then
		local info = Config.ISLAND_INFO[here.id]
		local tier = info and info.major and Config.TIER_NAMES[info.tier or 1]
		placeLabel.Text = tier and (here.name .. "  -  " .. tier) or here.name
		placeLabel.TextColor3 = tier and Config.TIER_COLORS[info.tier or 1] or WHITE
	else
		placeLabel.Text = ""
	end
	-- The Hoard and the sanctuary.
	if hoardPosition then
		local sx, sy = toMap(hoardPosition.X, hoardPosition.Z, from, forward, right)
		local radius = Config.SANCTUARY.RADIUS / RANGE * R * 2
		sanctuaryRing.Size = UDim2.fromOffset(radius, radius)
		put(sanctuaryRing, sx, sy, -radius / 2)
		local onMap = put(hoardDot, sx, sy, 8)
		hoardArrow.Visible = not onMap
		if not onMap then
			local angle = math.atan2(sx, -sy)
			hoardArrow.Position = UDim2.fromOffset(R + math.sin(angle) * (R + 2), R - math.cos(angle) * (R + 2))
			hoardArrow.Rotation = math.deg(angle)
			local pulse = carrying and (0.5 + 0.5 * math.sin(t * 8)) or 0
			hoardArrow.TextSize = carrying and (24 + pulse * 6) or 20
			hoardArrow.TextColor3 = carrying and GOLD or Color3.fromRGB(220, 200, 140)
		end
		hoardDot.Size = carrying and UDim2.fromOffset(20, 20) or UDim2.fromOffset(16, 16)
	end
	-- North, on the rim.
	local nx, ny = toMap(from.X, from.Z - 1000, from, forward, right)
	local north = math.atan2(nx, -ny)
	northMark.Position = UDim2.fromOffset(R + math.sin(north) * (R - 2), R - math.cos(north) * (R - 2))
	-- Treasure waiting or loose nearby.
	local folder = lootFolder()
	for _, def in ipairs(Config.LOOT) do
		local dot = lootDots[def.id]
		local state = folder and folder:GetAttribute(def.id .. "State") or "spot"
		local x, z
		if state == "loose" then
			local model = folder and folder:FindFirstChild(def.id)
			local core = model and model.PrimaryPart
			if core then
				x, z = core.Position.X, core.Position.Z
			end
		elseif state == "spot" then
			local island = Archipelago.byId[def.island]
			x, z = island.x, island.z
		end
		if x and not carrying then
			local sx, sy = toMap(x, z, from, forward, right)
			put(dot, sx, sy, 4)
			dot.BackgroundTransparency = state == "loose" and (math.sin(t * 9) > 0 and 0 or 0.5) or 0
		else
			dot.Visible = false
		end
	end
	-- Tornadoes.
	local positions = Twisters.positions()
	for i, dot in ipairs(twisterDots) do
		local tw = positions[i]
		if tw then
			local sx, sy = toMap(tw.x, tw.z, from, forward, right)
			put(dot, sx, sy, 6)
			dot.Rotation = (t * 240) % 360
		else
			dot.Visible = false
		end
	end
	-- Whatever is chasing you.
	local count = 0
	local threats = threatsFolder()
	if threats then
		for _, child in ipairs(threats:GetChildren()) do
			if count >= #chaserDots then
				break
			end
			if child:GetAttribute("Chasing") == player.UserId then
				local part = child:IsA("Model") and child.PrimaryPart or (child:IsA("BasePart") and child or nil)
				if part then
					count += 1
					local sx, sy = toMap(part.Position.X, part.Position.Z, from, forward, right)
					local dot = chaserDots[count]
					if not put(dot, sx, sy, 4) then
						-- Off the map: on the rim, so you know which way it is.
						local angle = math.atan2(sx, -sy)
						dot.Visible = true
						dot.Position = UDim2.fromOffset(R + math.sin(angle) * (R - 5), R - math.cos(angle) * (R - 5))
					end
					dot.Size = math.sin(t * 10) > 0 and UDim2.fromOffset(10, 10) or UDim2.fromOffset(8, 8)
				end
			end
		end
	end
	for i = count + 1, #chaserDots do
		chaserDots[i].Visible = false
	end
end

return Minimap

-- What is chasing you, at the edge of the screen (V12).
--
-- Pursuers are the best part of a raid (the V8 playtest: a creature right behind a fleeing boat), but a goblin
-- driving away looks ahead, and the minimap's red dot is small. So whatever is chasing YOU (a model whose
-- `Chasing` attribute is your UserId: Pursuit.lua, Leviathan.lua, GhostFleet.lua; the minimap reads the same)
-- gets a red arrow on a ring round the middle of the screen, pointing at it, with its name and how far behind it
-- is. Close behind, the arrow says BEHIND YOU. On screen it shows nothing: you can see it. Only within RANGE, so
-- the horizon stays clear of text (V9). Drawn by this client for itself; it reads only replicated attributes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Map = require(script.Parent.Map)

local Danger = {}

local player = Players.LocalPlayer
local RED = Color3.fromRGB(255, 80, 60)
local DARK = Color3.fromRGB(16, 16, 22)
local RANGE = 520 -- studs: beyond this a chaser is the minimap's business
local CLOSE = 90 -- studs: "BEHIND YOU"
local MAX = 3
local APART = 70 -- pixels: two chasers closer than this on the ring share one arrow ("THE ECHO +1")

local gui
local marks = {}

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function build()
	gui = make("ScreenGui", {
		Name = "LootGoblinsDanger",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
	}, player:WaitForChild("PlayerGui"))
	for i = 1, MAX do
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(150, 70),
			BackgroundTransparency = 1,
			Visible = false,
		}, gui)
		local arrow = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "^",
			TextColor3 = RED,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = DARK,
			TextSize = 44,
		}, frame)
		local label = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(150, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "",
			TextColor3 = RED,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = DARK,
			TextSize = 13,
			TextWrapped = true,
		}, frame)
		marks[i] = { frame = frame, arrow = arrow, label = label }
	end
end

local function chasers(from)
	local found = {}
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local threats = generated and generated:FindFirstChild("Threats")
	if not threats then
		return found
	end
	for _, child in ipairs(threats:GetChildren()) do
		if child:GetAttribute("Chasing") == player.UserId then
			local part = child:IsA("Model") and child.PrimaryPart or (child:IsA("BasePart") and child or nil)
			if part then
				local distance = (part.Position - from).Magnitude
				if distance <= RANGE then
					table.insert(found, {
						position = part.Position,
						distance = distance,
						name = child:GetAttribute("Pursuer") or child.Name,
					})
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	return found
end

local function update()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- The map shows them itself (and the arrows would sit on top of it).
	local list = (camera and root and not Map.isOpen()) and chasers(root.Position) or {}
	local shown = 0
	local placed = {}
	for _, entry in ipairs(list) do
		if shown >= MAX then
			break
		end
		local screen, visible = camera:WorldToViewportPoint(entry.position)
		local size = camera.ViewportSize
		local onScreen = visible
			and screen.X > 40
			and screen.X < size.X - 40
			and screen.Y > 40
			and screen.Y < size.Y - 40
		if not onScreen then
			-- The bearing on screen: from the camera's view, flattened (behind = straight down).
			local rel = camera.CFrame:PointToObjectSpace(entry.position)
			local angle = math.atan2(rel.X, -rel.Z) -- 0 ahead, pi behind
			-- The ring sits a little high and flat: its bottom clears the boat panel, the toasts above it, the
			-- objective and the action slots (a first ring put "THE ECHO" on top of SHIFT: BOOST, a second on
			-- "THE ECHO SLAMS YOU"), its top the raid timer.
			local rx, ry = math.min(size.X * 0.36, 420), math.min(size.Y * 0.22, 180)
			local at = Vector2.new(size.X / 2 + math.sin(angle) * rx, size.Y * 0.45 - math.cos(angle) * ry)
			-- Two chasers on the same bearing (a thief's own guardian and a neighbour's) share the nearer's arrow.
			local shared
			for _, other in ipairs(placed) do
				if (other.at - at).Magnitude < APART then
					shared = other
					break
				end
			end
			if shared then
				shared.extra += 1
				shared.mark.label.Text = shared.text .. "  +" .. shared.extra
			else
				shown += 1
				local mark = marks[shown]
				mark.frame.Position = UDim2.fromOffset(at.X, at.Y)
				mark.arrow.Rotation = math.deg(angle)
				local close = entry.distance <= CLOSE and math.abs(angle) > math.rad(100)
				local line = close and ("BEHIND YOU! " .. string.upper(entry.name))
					or string.format("%s  %d", string.upper(entry.name), math.floor(entry.distance))
				mark.label.Text = line
				local pulse = not close or math.sin(os.clock() * 10) > 0
				mark.arrow.TextTransparency = pulse and 0 or 0.4
				mark.frame.Visible = true
				table.insert(placed, { at = at, mark = mark, text = line, extra = 0 })
			end
		end
	end
	for i = shown + 1, MAX do
		marks[i].frame.Visible = false
	end
end

function Danger.start()
	build()
	RunService.RenderStepped:Connect(update)
end

return Danger

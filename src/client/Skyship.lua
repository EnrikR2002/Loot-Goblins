-- Flight, from the goblin's side (V8): the skyship's banner, the AIM (for a ship's cannon or an
-- island catapult: they are the same thing), and the flight itself. The character's own client flies
-- it; the server only works out the throw and rules on how it ends (server/Flight.lua).
--
-- Aiming is looking. In a launcher the mouse turns the view; the gold ring on the ground is where you
-- will come down, and the launcher throws exactly hard enough to put you there (shared/Dive.solve).
-- Past its reach the ring turns red and shows the farthest it can throw that way. The ship is seen
-- through while you aim, so the whole sea beneath is in view, and every island wears its name.
--
-- V13.2: the ship FLIES ITS ROUTE (shared/SkyRoute.lua). This client moves its own copy of the ship along the route every
-- frame (smooth, whatever the network does; the server moves its own the same way), carries its goblin along while they
-- stand on the deck, and aims a cannon from where that cannon is now. The banner says when the cannons unlock and which
-- islands are in reach.
--
-- Keys, all shown on the banner for the moment they matter:
--   aboard     E at a cannon: climb in.   M: map (click an island to point a cannon at it).   or walk off a wing.
--   aiming     MOUSE (or WASD) look at where to land.   CLICK or SPACE fire.   X climb out.
--   in the air WASD nudge.   hold SPACE: glide (an air brake, a soft landing).   hold SHIFT: dive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Archipelago = require(Shared:WaitForChild("Archipelago"))
local Dive = require(Shared:WaitForChild("Dive"))
local SkyRoute = require(Shared:WaitForChild("SkyRoute"))
local Effects = require(script.Parent.Effects)
local Map = require(script.Parent.Map)

local Skyship = {}

local mapHeldUntil = 0 -- V11: the map does not open on its own before this time (the winner's dance)
function Skyship.holdMap(seconds)
	mapHeldUntil = math.max(mapHeldUntil, time() + seconds)
end
Skyship.handlers = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local deployRemote = remotes:WaitForChild("DeployRequest")

local D = Config.DIVE
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 50)
local RED = Color3.fromRGB(255, 90, 80)
local SKIP = Color3.fromRGB(150, 230, 255)
local DARK = Color3.fromRGB(16, 16, 22)

local gui, banner, subline, crosshair
local aimFolder -- every local helper part (dots, rings, labels, the beam): rays ignore it
local preview = {} -- pooled dots
local markers = {} -- pooled rings
local labels = {} -- island id -> { part, text }
local beam
local shipModel

-- Aim.
local aimYaw, aimPitch = 0, -0.5
local aimReady = false
local aimTouched = false -- has the player turned the aim since climbing in?
local aimTarget, aimVelocity, aimReach
local pickedTarget = nil -- V12: a spot picked on the map, held until the goblin turns the view
local lastAimSent = 0
local aimCamera = false

-- Flight.
local velocity = Vector3.zero
local diving = false
local diveClock = 0
local mode = "tumble"
local sentMode = "tumble"
local bouncesUsed = 0
local rotation = CFrame.new()
local skimUntil, restingSince = nil, nil
local landing -- where the flight is heading: { position, water, island }

local function now()
	return workspace:GetServerTimeNow()
end

-- V13.2: the ship's frame as this client last placed it (SkyRoute), and where a cannon throws from now.
local shipFrame = nil
local REACH = SkyRoute.reach()
local function launchFrom()
	local localFrom = player:GetAttribute("LaunchLocal")
	if typeof(localFrom) == "Vector3" and shipFrame then
		return shipFrame * localFrom
	end
	return player:GetAttribute("LaunchFrom")
end

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function character()
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	return c, humanoid, root
end

local function ship()
	if not shipModel then
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		local landmarks = generated and generated:FindFirstChild("Landmarks")
		shipModel = landmarks and landmarks:FindFirstChild("Skyship")
	end
	return shipModel
end

-- Rays: straight down (what is under a point) and along a line (what the view or the flight meets).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
local function ignoreList()
	local list = { ship(), aimFolder }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	return list
end

-- The height of whatever is below (x, z), and whether it is the sea.
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -800, 0), rayParams)
	if not hit then
		return 0, true
	end
	return hit.Position.Y, hit.Material == Enum.Material.Water
end

-- The island a point belongs to (within its shore and a little more), or nil for open sea.
local function islandAt(position)
	local best, bestGap = nil, math.huge
	for _, island in ipairs(Archipelago.islands) do
		local gap = Vector3.new(island.x - position.X, 0, island.z - position.Z).Magnitude - island.r
		if gap < 70 and gap < bestGap then
			best, bestGap = island, gap
		end
	end
	return best
end

-- The banner ------------------------------------------------------------------------------------
local function build()
	gui = make(
		"ScreenGui",
		{ Name = "LootGoblinsSky", ResetOnSpawn = false, DisplayOrder = 6, IgnoreGuiInset = true },
		player:WaitForChild("PlayerGui")
	)
	banner = make("TextLabel", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -196),
		Size = UDim2.fromOffset(700, 34),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		TextSize = 18,
		Text = "",
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, banner)
	subline = make("TextLabel", {
		Name = "Subline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.fromOffset(700, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.4,
		TextSize = 15,
		Text = "",
		Visible = false,
	}, gui)
	-- The aiming mark: the middle of the screen is where you are looking.
	crosshair = make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, crosshair)
	make("UIStroke", { Color = DARK, Thickness = 2 }, crosshair)
	aimFolder = make("Folder", { Name = "LootGoblinsAim" }, workspace)
	rayParams.FilterDescendantsInstances = ignoreList()
end

local function setBanner(text, sub, color)
	banner.Text = text or ""
	banner.Visible = text ~= nil and text ~= ""
	banner.TextColor3 = color or GOLD
	subline.Text = sub or ""
	subline.Visible = sub ~= nil and sub ~= ""
end

local function keyDown(...)
	for _, key in ipairs({ ... }) do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- The name over the island you are aiming at (or falling toward) ------------------------------------
-- V8 hung all sixteen names and tiers over the sea while aiming. V9 shows only the one island the ring is
-- on: the map (M) is where the whole sea is read. focusIsland is set by the aim and by the flight.
local focusIsland = nil
local labelsOn = false
local signRange = setmetatable({}, { __mode = "k" })
local function showLabels(on)
	if on and next(labels) == nil then
		for _, island in ipairs(Archipelago.islands) do
			local info = Config.ISLAND_INFO[island.id]
			if info and info.major then
				local anchor = make("Part", {
					Name = "IslandLabel",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Transparency = 1,
					Size = Vector3.new(1, 1, 1),
					Position = Vector3.new(island.x, 150, island.z),
				}, aimFolder)
				local board = make("BillboardGui", {
					Size = UDim2.fromOffset(210, 50),
					MaxDistance = 100000,
					LightInfluence = 0,
				}, anchor)
				local color = Config.TIER_COLORS[info.tier or 1] or WHITE
				make("TextLabel", {
					Size = UDim2.fromScale(1, 0.6),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBlack,
					TextColor3 = WHITE,
					TextStrokeTransparency = 0.15,
					TextScaled = true,
					Text = island.name,
				}, board)
				make("TextLabel", {
					Size = UDim2.fromScale(1, 0.4),
					Position = UDim2.fromScale(0, 0.6),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBlack,
					TextColor3 = color,
					TextStrokeTransparency = 0.15,
					TextScaled = true,
					Text = Config.TIER_NAMES[info.tier or 1] or "",
				}, board)
				labels[island.id] = { part = anchor, board = board }
			end
		end
	end
	for id, entry in pairs(labels) do
		entry.board.Enabled = on and id == focusIsland
	end
	-- The world's own island signs only reach 1,500 studs; these take over while they are up, so no
	-- island wears two names. (Main hides a sign that is beyond its MaxDistance.)
	if on ~= labelsOn then
		labelsOn = on
		for _, sign in ipairs(CollectionService:GetTagged("RangedSign")) do
			local holder = sign.Parent
			if holder and holder.Name == "IslandSign" then
				signRange[sign] = signRange[sign] or sign.MaxDistance
				sign.MaxDistance = on and 0 or signRange[sign]
			end
		end
	end
end

-- V12: where a pick of island `id` comes down (server/Skyship.lua publishes one dry spot near each island's
-- treasure); the island's middle if it has none.
local function landingFor(id)
	local island = id and Archipelago.byId[id]
	if not island then
		return nil
	end
	local generated = workspace:FindFirstChild("LootGoblinsGenerated")
	local spot = generated and generated:GetAttribute("Land_" .. id)
	return typeof(spot) == "Vector3" and spot or Vector3.new(island.x, 0, island.z)
end

-- The destination beam: a column of light over the spot you will come down on (V12: the landing spot near the
-- island's treasure; V11 stood it over the island's middle).
local function updateBeam()
	local id = player:GetAttribute("DeployDest")
	local island = id and Archipelago.byId[id]
	local phase = player:GetAttribute("DeployState")
	if
		not island or not (phase == "aboard" or phase == "loaded" or phase == "fuse" or player:GetAttribute("Diving"))
	then
		if beam then
			beam.Parent = nil
		end
		return
	end
	if not beam then
		beam = make("Part", {
			Name = "DestinationBeam",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			Size = Vector3.new(1500, 14, 14),
			Shape = Enum.PartType.Cylinder,
		}, nil)
	end
	local info = Config.ISLAND_INFO[id]
	beam.Color = Config.TIER_COLORS[info and info.tier or 1] or WHITE
	local spot = landingFor(id)
	beam.CFrame = CFrame.new(spot.X, 700, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = aimFolder
end

-- Seeing through the ship while aiming from it ---------------------------------------------------
local shipParts, shipGlows
local function seeThrough(on, from)
	if not shipParts then
		shipParts, shipGlows = {}, {}
		for _, p in ipairs(ship() and ship():GetDescendants() or {}) do
			if p:IsA("BasePart") then
				table.insert(shipParts, p)
			elseif p:IsA("ParticleEmitter") or p:IsA("PointLight") or p:IsA("SurfaceGui") then
				table.insert(shipGlows, p)
			end
		end
	end
	for _, p in ipairs(shipParts) do
		local value = 0
		if on then
			-- Your own cannon stays (faintly) so you can see what you are sitting in; everything else goes
			-- (even nearly clear, forty layers of deck, mast and sail made a fog of the sea below).
			local own = from and string.find(p.Name, "^Cannon") and (p.Position - from).Magnitude < 9
			value = own and 0.5 or 1
		end
		p.LocalTransparencyModifier = value
	end
	for _, glow in ipairs(shipGlows) do
		glow.Enabled = not on
	end
end

-- The aim preview --------------------------------------------------------------------------------
local function dot(i)
	local p = preview[i]
	if not p then
		p = make("Part", {
			Name = "AimDot",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Size = Vector3.new(5, 5, 5),
		}, nil)
		preview[i] = p
	end
	return p
end

local function marker(i)
	local m = markers[i]
	if not m then
		m = make("Part", {
			Name = "LandingMarker",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		}, nil)
		markers[i] = m
	end
	return m
end

local function hidePreview()
	for _, p in pairs(preview) do
		p.Parent = nil
	end
	for _, m in pairs(markers) do
		m.Parent = nil
	end
end

-- Draws an arc and its touches. The FIRST touch is the mark (it is where you aimed, or where you are
-- about to come down); the ones after it are where the sea skips you on to. Returns the touches.
local function drawFlight(origin, v0, flightMode, want, used, color, withDots)
	local points, touches = Dive.predict(origin, v0, flightMode, groundAt, want, used)
	local camera = workspace.CurrentCamera
	local eye = camera.CFrame.Position
	local dots = 0
	if withDots then
		for i = 2, #points, 2 do
			-- (not the ones in your face: the arc starts beside the camera)
			if (points[i] - eye).Magnitude > 90 then
				dots += 1
				local p = dot(dots)
				p.Color = color
				p.Transparency = 0.25
				p.Position = points[i]
				p.Parent = aimFolder
			end
		end
	end
	for i = dots + 1, #preview do
		preview[i].Parent = nil
	end
	for i, touch in ipairs(touches) do
		local m = marker(i)
		local first = i == 1
		-- Big enough to read from wherever the camera is: a ring far below still looks like a ring.
		local far = (eye - touch.position).Magnitude
		local size = math.clamp(far * (first and 0.05 or 0.026), first and 26 or 12, first and 200 or 110)
		m.Size = Vector3.new(first and 1.4 or 0.8, size, size)
		m.Color = first and color or SKIP
		m.Transparency = first and 0.15 or 0.4
		m.CFrame = CFrame.new(touch.position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		m.Parent = aimFolder
	end
	for i = #touches + 1, #markers do
		markers[i].Parent = nil
	end
	return touches
end

-- The aiming view -----------------------------------------------------------------------------------
local function lookVector()
	local cos = math.cos(aimPitch)
	return Vector3.new(math.sin(aimYaw) * cos, math.sin(aimPitch), math.cos(aimYaw) * cos)
end

local function lookAtPoint(from, point)
	local to = point - (from + Vector3.new(0, 26, 0))
	if to.Magnitude < 1 then
		return
	end
	aimYaw = math.atan2(to.X, to.Z)
	aimPitch = math.clamp(math.asin(to.Unit.Y), math.rad(-88), math.rad(-1.5))
end

local function releaseView()
	if aimCamera then
		aimCamera = false
		seeThrough(false)
		crosshair.Visible = false
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	aimReady = false
end

-- V12: aiming without a mouse. A controller's thumbsticks turn the view; a finger dragging across the screen
-- turns it like the mouse does (through V11 only a mouse or the keyboard could aim, so a controller or a phone
-- could only fire wherever a map pick had pointed the cannon).
local stickAim = Vector2.zero
local touchAim = Vector2.zero
UserInputService.InputChanged:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local v = Vector2.new(input.Position.X, input.Position.Y)
		stickAim = v.Magnitude > 0.18 and v or Vector2.zero
	elseif
		input.UserInputType == Enum.UserInputType.Touch
		and not processed
		and player:GetAttribute("DeployState") == "loaded"
	then
		touchAim += Vector2.new(input.Delta.X, input.Delta.Y)
	end
end)

local nextPreview = 0
local function aimStep(dt, firing)
	local from = launchFrom()
	local speed = player:GetAttribute("LaunchSpeed")
	local elevation = player:GetAttribute("LaunchElevation")
	if typeof(from) ~= "Vector3" or not speed or not elevation then
		return
	end
	local camera = workspace.CurrentCamera
	local start = player:GetAttribute("LaunchTarget")
	if not aimReady then
		aimReady = true
		aimTouched = false
		pickedTarget = nil
		if typeof(start) == "Vector3" then
			lookAtPoint(from, start)
		end
	end
	if not aimCamera then
		aimCamera = true
		seeThrough(player:GetAttribute("LaunchKind") == "cannon", from)
	end
	-- Turning: the mouse (locked to the middle of the screen), or the keys.
	if not firing and not Map.isOpen() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local delta = UserInputService:GetMouseDelta() + touchAim
		touchAim = Vector2.zero
		local turn = (keyDown(Enum.KeyCode.D, Enum.KeyCode.Right) and -1 or 0)
			+ (keyDown(Enum.KeyCode.A, Enum.KeyCode.Left) and 1 or 0)
		local tilt = (keyDown(Enum.KeyCode.W, Enum.KeyCode.Up) and 1 or 0)
			+ (keyDown(Enum.KeyCode.S, Enum.KeyCode.Down) and -1 or 0)
		turn -= stickAim.X
		tilt += stickAim.Y
		-- Slower when looking far away: near the horizon a small turn is a long way on the sea.
		local fine = math.clamp(math.abs(math.sin(aimPitch)) * 2.2, 0.3, 1)
		if delta.Magnitude > 0.5 or math.abs(turn) > 0.01 or math.abs(tilt) > 0.01 then
			aimTouched = true
		end
		aimYaw += -delta.X * 0.0032 * fine + turn * 0.9 * fine * dt
		aimPitch =
			math.clamp(aimPitch - delta.Y * 0.0032 * fine + tilt * 0.6 * fine * dt, math.rad(-88), math.rad(-1.5))
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	local look = lookVector()
	local flatLook = Vector3.new(math.sin(aimYaw), 0, math.cos(aimYaw))
	local eye = from
		+ Vector3.new(0, 22 + 10 * math.abs(math.sin(aimPitch)), 0)
		- flatLook * (22 * math.cos(aimPitch) + 4)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(eye, eye + look)
	camera.FieldOfView = 70
	crosshair.Visible = not Map.isOpen()
	-- What the middle of the screen is on.
	rayParams.FilterDescendantsInstances = ignoreList()
	local hit = workspace:Raycast(eye, look * D.AIM_RANGE, rayParams)
	local target
	if not aimTouched and pickedTarget then
		target = pickedTarget
	elseif not aimTouched and typeof(start) == "Vector3" then
		-- Nobody has turned it yet: it is aimed at exactly the place it started on (an island picked on the
		-- map, or what a catapult was built to reach), not at whatever slope happens to be in front of that.
		target = start
	elseif hit then
		target = hit.Position
	elseif look.Y < -0.005 then
		target = eye + look * (eye.Y / -look.Y) -- the sea, where nothing is loaded yet
	else
		target = from + flatLook * D.AIM_RANGE * 0.5
	end
	aimTarget = target
	aimVelocity, aimReach = Dive.solve(from, target, elevation, speed)
	local t = now()
	if t - lastAimSent > 0.1 and not firing then
		lastAimSent = t
		deployRemote:FireServer("aim", target)
	end
	if os.clock() >= nextPreview then
		nextPreview = os.clock() + 0.1
		local color = aimReach and GOLD or RED
		crosshair.BackgroundColor3 = color
		local touches = drawFlight(from, aimVelocity, "tumble", nil, 0, color, true)
		local first = touches[1]
		local text
		if not first then
			text = "Nothing down there."
		else
			local island = islandAt(first.position)
			focusIsland = island and island.id or nil
			local info = island and Config.ISLAND_INFO[island.id]
			local distance = Vector3.new(first.position.X - from.X, 0, first.position.Z - from.Z).Magnitude
			text = string.format(
				"%s%s   |   %d studs",
				island and island.name or "OPEN SEA",
				(info and info.major) and ("  (" .. (Config.TIER_NAMES[info.tier or 1] or "") .. ")") or "",
				distance
			)
			if #touches > 1 then
				local on = islandAt(touches[#touches].position)
				text ..= string.format(
					"   |   the sea skips you %d time%s%s",
					#touches - 1,
					#touches > 2 and "s" or "",
					on and (", on to " .. on.name) or ""
				)
			end
		end
		local bellAt = workspace:GetAttribute("DeployOpensAt")
		local waiting = bellAt and t < bellAt
		setBanner(
			firing and "FIRING..."
				or (
					waiting
						and string.format(
							"LOCKED: AIM NOW, THE SHIP SETS OFF AND THE CANNONS FIRE IN %d   -   X: CLIMB OUT",
							math.ceil(bellAt - t)
						)
					or (
						aimReach and "LOOK WHERE YOU WANT TO LAND   -   CLICK or SPACE: FIRE   -   X: CLIMB OUT"
						or "OUT OF REACH: THE RED RING IS AS FAR AS IT THROWS. WAIT FOR THE SHIP TO GET CLOSER!"
					)
				),
			text,
			(aimReach and not waiting) and GOLD or (waiting and Color3.fromRGB(255, 230, 140) or RED)
		)
	end
end

-- Steering input in world space, relative to the camera.
local function wantDirection()
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	look = Vector3.new(look.X, 0, look.Z)
	right = Vector3.new(right.X, 0, right.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)
	local move = Vector3.zero
	if keyDown(Enum.KeyCode.W, Enum.KeyCode.Up) then
		move += look
	end
	if keyDown(Enum.KeyCode.S, Enum.KeyCode.Down) then
		move -= look
	end
	if keyDown(Enum.KeyCode.D, Enum.KeyCode.Right) then
		move += right
	end
	if keyDown(Enum.KeyCode.A, Enum.KeyCode.Left) then
		move -= right
	end
	local _, humanoid = character()
	if move.Magnitude < 0.1 and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		move = humanoid.MoveDirection
	end
	return move
end

local function wantedMode()
	if
		keyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
	then
		return "glide"
	elseif
		keyDown(Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonX)
	then
		return "pencil"
	end
	return "tumble"
end

-- The flight -----------------------------------------------------------------------------------------
-- V12: the flight sets the goblin's velocity every frame, but Roblox's own gravity then acts on the body inside
-- each physics step as well, so through V11 every throw sank below the arc the aim ring promised (measured: 25
-- studs low after 7 s, 40 at touchdown, so a throw aimed at a beach came down in the water 58 studs short and
-- skipped three times out past the island). While flying, a force that exactly cancels the world's gravity on
-- the body is switched on; the flight's own gravity (Dive.step) is then the only one, as Dive.solve assumes.
local antiGravity
local function setAntiGravity(root)
	if not root then
		if antiGravity then
			antiGravity.force.Enabled = false
		end
		return
	end
	if not antiGravity or antiGravity.root ~= root or not antiGravity.force.Parent then
		if antiGravity and antiGravity.attachment then
			antiGravity.attachment:Destroy()
		end
		local attachment = make("Attachment", { Name = "FlightLift" }, root)
		local force = make("VectorForce", {
			Name = "FlightLift",
			Attachment0 = attachment,
			RelativeTo = Enum.ActuatorRelativeTo.World,
			ApplyAtCenterOfMass = true,
			Enabled = false,
		}, attachment)
		antiGravity = { root = root, attachment = attachment, force = force }
	end
	-- The whole body's weight: while a goblin tumbles its limbs hang from loose joints (AnimationConstraints with
	-- ball sockets: server/Flight.lua), so they are separate assemblies from the root and would still drag it down.
	local body = root.Parent
	if antiGravity.character ~= body then
		local mass = 0
		for _, p in ipairs(body:GetDescendants()) do
			if p:IsA("BasePart") and not p.Massless then
				mass += p:GetMass()
			end
		end
		antiGravity.character, antiGravity.mass = body, mass
	end
	antiGravity.force.Force = Vector3.new(0, antiGravity.mass * workspace.Gravity, 0)
	antiGravity.force.Enabled = true
end

local function startDive(v)
	local _, humanoid, root = character()
	if not root then
		return
	end
	velocity = v
	diving = true
	diveClock = 0
	mode, sentMode = "tumble", "tumble"
	bouncesUsed = 0
	skimUntil, restingSince = nil, nil
	rotation = root.CFrame.Rotation
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = v
	hidePreview()
end

RunService.PreSimulation:Connect(function(dt)
	if not diving then
		return
	end
	local _, humanoid, root = character()
	-- V12: the DiveStart message can arrive before the Diving attribute does (a remote and an attribute are not
	-- ordered). Through V11 that first frame read "not diving" and dropped the throw, and the goblin fell
	-- straight down off the deck under the world's gravity (seen once in about forty Studio launches). The end
	-- of a dive is the attribute clearing (the handler in Skyship.start); here it only has a second to arrive.
	if not root or (not player:GetAttribute("Diving") and diveClock > 1) then
		diving = false
		setAntiGravity(nil)
		return
	end
	setAntiGravity(root)
	dt = math.min(dt, 0.1)
	diveClock += dt
	humanoid.PlatformStand = true
	mode = wantedMode()
	if mode ~= sentMode then
		sentMode = mode
		deployRemote:FireServer("mode", mode)
	end
	local want = wantDirection()
	if restingSince then
		-- Down, and waiting for the server to say how it ended. If it never does, stand up anyway.
		velocity = Vector3.zero
		if os.clock() - restingSince > 2 then
			diving = false
			setAntiGravity(nil)
			humanoid.PlatformStand = false
			return
		end
	else
		velocity = Dive.step(velocity, want, mode, dt)
		if skimUntil then
			-- On the water, waiting for the bounce: skim, never sink.
			velocity = Vector3.new(velocity.X, math.max(velocity.Y, 0), velocity.Z)
			if os.clock() > skimUntil then
				skimUntil = nil
			end
		end
		-- What the next step meets. Stopping on it here (instead of leaving it to the collision) is
		-- what keeps a goblin doing 400 studs a second from going through a thin floor.
		local step = velocity * dt
		if step.Magnitude > 0.01 and diveClock > 0.35 then
			rayParams.FilterDescendantsInstances = ignoreList()
			local hit = workspace:Raycast(root.Position, step + step.Unit * 3.5, rayParams)
			if hit and hit.Material == Enum.Material.Water then
				if velocity.Y < 0 and not skimUntil then
					skimUntil = os.clock() + 0.45
					root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 2.6, 0)) * rotation
					velocity = Vector3.new(velocity.X, 0, velocity.Z)
				end
			elseif hit and hit.Normal.Y > 0.5 then
				if velocity.Y <= 0 then
					root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.2, 0)) * rotation
					velocity = Vector3.zero
					restingSince = os.clock()
				end
			elseif hit then
				-- A wall or a cliff: off it, most of the speed gone, and down.
				local n = hit.Normal
				velocity = (velocity - n * velocity:Dot(n) * 1.35) * 0.35
			end
		end
	end
	local target =
		Dive.orientation(velocity.Magnitude > 2 and velocity or Vector3.new(0, -1, 0), mode, diveClock).Rotation
	rotation = rotation:Lerp(target, 1 - math.exp(-(mode == "tumble" and 14 or 9) * dt))
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(root.Position) * rotation
end)

-- Pose, for everybody: a goblin who has taken hold strikes it (arms out for a glide, arms and legs
-- in a line for a dive); a tumbling one is all loose limbs (the server unhooks them: server/Flight.lua),
-- so there is nothing to pose. The pose is written over the animation each frame, after the animator
-- has had its say (a joint's Transform, which both kinds of avatar joint have), so it needs no undoing.
local POSES = {
	glide = {
		LeftShoulder = CFrame.Angles(0, 0, math.rad(-85)),
		RightShoulder = CFrame.Angles(0, 0, math.rad(85)),
		LeftHip = CFrame.Angles(0, 0, math.rad(-18)),
		RightHip = CFrame.Angles(0, 0, math.rad(18)),
		LeftElbow = CFrame.new(),
		RightElbow = CFrame.new(),
		LeftKnee = CFrame.new(),
		RightKnee = CFrame.new(),
	},
	pencil = {
		LeftShoulder = CFrame.Angles(math.rad(178), 0, 0),
		RightShoulder = CFrame.Angles(math.rad(178), 0, 0),
		LeftHip = CFrame.new(),
		RightHip = CFrame.new(),
		LeftElbow = CFrame.new(),
		RightElbow = CFrame.new(),
		LeftKnee = CFrame.new(),
		RightKnee = CFrame.new(),
	},
}
-- The same poses for the older six-part avatar.
POSES.glide["Left Shoulder"] = CFrame.Angles(0, 0, math.rad(-85))
POSES.glide["Right Shoulder"] = CFrame.Angles(0, 0, math.rad(85))
POSES.pencil["Left Shoulder"] = CFrame.Angles(0, 0, math.rad(-170))
POSES.pencil["Right Shoulder"] = CFrame.Angles(0, 0, math.rad(170))

local jointCache = setmetatable({}, { __mode = "k" })
local function jointsOf(character_)
	local list = jointCache[character_]
	if not list then
		list = {}
		for _, joint in ipairs(character_:GetDescendants()) do
			if POSES.glide[joint.Name] and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
				table.insert(list, joint)
			end
		end
		jointCache[character_] = list
	end
	return list
end

RunService.PreSimulation:Connect(function()
	for _, other in ipairs(Players:GetPlayers()) do
		local c = other.Character
		local poseMode = c and other:GetAttribute("Diving") and other:GetAttribute("DiveMode") or nil
		local set = poseMode and POSES[poseMode]
		if set then
			for _, joint in ipairs(jointsOf(c)) do
				local transform = set[joint.Name]
				if transform then
					joint.Transform = transform
				end
			end
		end
	end
end)

-- V13.2: the major islands whose landing is in the cannons' reach right now (for the banner).
local reachText, nextReachAt = "", 0
local function inReachNow()
	if os.clock() < nextReachAt then
		return reachText
	end
	nextReachAt = os.clock() + 0.4
	if not shipFrame then
		return reachText
	end
	local names = {}
	local p = shipFrame.Position
	for _, island in ipairs(Archipelago.islands) do
		local info = Config.ISLAND_INFO[island.id]
		if info and info.major then
			local spot = landingFor(island.id)
			if Vector3.new(spot.X - p.X, 0, spot.Z - p.Z).Magnitude <= REACH then
				table.insert(names, island.name)
			end
		end
	end
	reachText = #names > 0 and table.concat(names, ", ", 1, math.min(#names, 4)) .. (#names > 4 and "..." or "")
		or "nothing yet: wait for land"
	return reachText
end

-- Each frame: the banner, the aim, the landing ring -------------------------------------------------
local nextLanding = 0
local function update(dt)
	local phase = player:GetAttribute("DeployState")
	local t = now()
	local opensAt = workspace:GetAttribute("DeployOpensAt")
	local endsAt = workspace:GetAttribute("DeployEndsAt")
	local flying = player:GetAttribute("Diving")
	updateBeam()
	local _, _, root = character()
	local high = root and root.Position.Y > 150
	showLabels(((phase == "loaded" or phase == "fuse" or flying) and high) or false)
	if phase == "aboard" then
		releaseView()
		-- V12: once an island is picked, the banner names it. V13.2: the ship fires you there as it passes it.
		local dest = player:GetAttribute("DeployDest")
		local destIsland = dest and Archipelago.byId[dest]
		local routeName = workspace:GetAttribute("SkyRouteName") or "THE SKYSHIP"
		if Map.isOpen() then
			Map.setTitle(
				"CLICK A LIT ISLAND: the ship fires you there as it passes  -  ring: the cannons' reach  -  M closes"
			)
			setBanner(nil)
		elseif opensAt and t < opensAt then
			Map.setTitle()
			setBanner(
				string.format(
					"%s SETS OFF IN %d   -   CANNONS LOCKED: CLIMB IN (E) AND AIM",
					routeName,
					math.ceil(opensAt - t)
				),
				destIsland
						and ("Picked: " .. destIsland.name .. " (the ship fires you there as it passes)   |   M: the map")
					or "M: the map shows the route: pick an island in reach, and the ship fires you there as it passes"
			)
		else
			Map.setTitle()
			local by = player:GetAttribute("LaunchBy") or endsAt -- V12: a late arrival's own deadline
			local left = by and math.max(0, math.ceil(by - t)) or 0
			setBanner(
				string.format("IN REACH NOW: %s   -   %d s", inReachNow(), left),
				destIsland
						and ("Picked: " .. destIsland.name .. "   |   CLIMB IN (E) to aim yourself   |   or step off a wing")
					or "CLIMB INTO A CANNON (E) and fire when your island is in reach   |   M: the map"
			)
		end
		hidePreview()
	elseif phase == "loaded" or phase == "fuse" then
		Map.setTitle(phase == "loaded" and "CLICK AN ISLAND TO POINT AT IT  -  M closes" or nil)
		aimStep(dt, phase == "fuse")
	elseif flying then
		releaseView()
		Map.setTitle()
		if os.clock() >= nextLanding and root then
			nextLanding = os.clock() + 0.15
			rayParams.FilterDescendantsInstances = ignoreList()
			local touches = drawFlight(root.Position, velocity, mode, wantDirection(), bouncesUsed, GOLD, false)
			local first = touches[1]
			landing = first and { position = first.position, island = islandAt(first.position), skips = #touches - 1 }
				or nil
			focusIsland = landing and landing.island and landing.island.id or nil
		end
		local where = "?"
		if landing then
			where = landing.island and landing.island.name or "OPEN SEA"
			if landing.skips > 0 then
				where = where .. string.format("  (%d skip%s)", landing.skips, landing.skips > 1 and "s" or "")
			end
		end
		local altitude = root and math.max(0, root.Position.Y - (groundAt(root.Position.X, root.Position.Z))) or 0
		local title = mode == "glide" and "GLIDING: a soft landing"
			or mode == "pencil" and "DIVING!"
			or "TUMBLING!   hold SPACE: glide (brake)   hold SHIFT: dive   WASD: nudge"
		setBanner(title, string.format("Coming down at: %s   |   %d up", where, altitude))
	else
		releaseView()
		Map.setTitle()
		setBanner(nil)
		hidePreview()
	end
end

-- Keys that are not movement ---------------------------------------------------------------------
-- Fire the loaded launcher where it is aimed (CLICK, SPACE, A, or the FIRE touch button: Main's TouchControls).
function Skyship.fire()
	if player:GetAttribute("DeployState") ~= "loaded" then
		return
	end
	if aimTarget then
		deployRemote:FireServer("aim", aimTarget)
	end
	deployRemote:FireServer("fire")
end

function Skyship.leave()
	if player:GetAttribute("DeployState") == "loaded" then
		deployRemote:FireServer("leave")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local phase = player:GetAttribute("DeployState")
	if phase == "loaded" then
		if
			input.KeyCode == Enum.KeyCode.Space
			or (input.UserInputType == Enum.UserInputType.MouseButton1 and not Map.isOpen())
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			Skyship.fire()
		elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonB then
			Skyship.leave()
		end
	end
end)

-- Choosing an island on the map (Map.lua calls this): the ship remembers it, and a loaded launcher
-- turns to look at it.
function Skyship.choose(id)
	-- V13.2: only an island the ship comes in reach of on this route (the map dims the others).
	if Map.reachable and not Map.reachable(id) then
		Effects.chime(Effects.CHIME_BAD or { 1, 0.8 }, 0.4)
		setBanner("OUT OF REACH ON THIS ROUTE: pick a lit island", nil, RED)
		return
	end
	deployRemote:FireServer("choose", id)
	player:SetAttribute("DeployDest", id) -- shown at once; the server's copy follows
	local island = Archipelago.byId[id]
	local from = launchFrom()
	if island and typeof(from) == "Vector3" and player:GetAttribute("DeployState") == "loaded" then
		lookAtPoint(from, landingFor(id))
		-- V12: aimed at exactly that spot until the goblin turns the view themselves (a ray along the look
		-- could catch a slope or a cliff in front of it).
		pickedTarget = landingFor(id)
		aimTouched = false
		Map.show(false)
	elseif island and player:GetAttribute("DeployState") == "aboard" then
		-- V12: picked from the deck: the map steps aside so the cannons are in view (the banner names the island
		-- and the beam stands over where you will come down).
		Map.show(false)
		Effects.chime(Effects.CHIME_GOOD, 0.5)
	end
end

-- Server events -------------------------------------------------------------------------------------
function Skyship.handlers.DiveStart(p)
	startDive(p.velocity)
	Effects.punchFov(100)
end

function Skyship.handlers.DiveBounce(p)
	local _, _, root = character()
	if not root then
		return
	end
	velocity = p.velocity
	bouncesUsed = p.count or (bouncesUsed + 1)
	skimUntil, restingSince = nil, nil
	root.AssemblyLinearVelocity = p.velocity
	Effects.punchFov(104)
end

function Skyship.handlers.DiveFire(p)
	Effects.burst(p.position + p.direction * 8, Color3.fromRGB(255, 200, 90), 60, 50)
	Effects.ring(p.position + p.direction * 8, Color3.fromRGB(255, 240, 200), 18, 0.4)
	if p.kind == "catapult" then
		Effects.sound("whoosh", { position = p.position, speed = 0.6, volume = 1, range = 400 })
		Effects.sound("thud", { position = p.position, speed = 0.9, volume = 0.8, range = 400 })
	else
		Effects.sound("boom", { position = p.position, speed = 1.1, volume = 1, range = 500 })
		Effects.shakeAt(p.position, 0.9, 0.35, 90)
	end
end

function Skyship.handlers.DiveImpact(p)
	if p.kind == "water" then
		-- Each bounce is a smaller splash than the one before; the last touch is the big one going in.
		local power = p.bounce == 0 and 1.2 or (1.9 - (p.bounce or 1) * 0.4)
		Effects.spray(p.position, power)
		Effects.ring(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(190, 240, 255), 22 + power * 12, 0.8)
		Effects.burst(p.position + Vector3.new(0, 2, 0), Color3.fromRGB(235, 250, 255), 40 + power * 20, 60)
		Effects.sound("rise", { position = p.position, speed = 0.6 + (p.bounce or 0) * 0.15, volume = 1, range = 500 })
		Effects.sound("thud", { position = p.position, speed = 0.6, volume = 0.8, range = 500 })
	elseif p.kind == "ground" then
		Effects.burst(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(150, 120, 80), 55, 38)
		Effects.ring(p.position + Vector3.new(0, 0.5, 0), Color3.fromRGB(190, 160, 110), 22, 0.5)
		Effects.sound("thud", { position = p.position, speed = 0.5, volume = 1, range = 500 })
		Effects.shakeAt(p.position, 1.2, 0.4, 120)
	elseif p.kind == "pop" then
		Effects.burst(p.position + Vector3.new(0, 2, 0), Color3.fromRGB(190, 160, 110), 40, 30)
		Effects.sound("whoosh", { position = p.position, speed = 1.7, volume = 0.9, range = 400 })
	else
		Effects.burst(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(200, 190, 160), 24, 18)
		Effects.sound("thud", { position = p.position, speed = 1.3, volume = 0.5, range = 300 })
	end
end

function Skyship.handlers.DeployOpen(_p)
	Effects.sound("rise", { speed = 1.4, volume = 1 })
end

function Skyship.install(handlers)
	for kind, fn in pairs(Skyship.handlers) do
		handlers[kind] = fn
	end
end

-- For the playtest hook: where the aim is, and how the flight is going.
function Skyship.debugState()
	return {
		yaw = aimYaw,
		pitch = aimPitch,
		target = aimTarget,
		reach = aimReach,
		velocity = diving and velocity or aimVelocity,
		mode = mode,
		landing = landing and landing.position,
	}
end

-- For the playtest hook and the map: look at a place.
function Skyship.lookAt(point)
	local from = launchFrom()
	if typeof(from) == "Vector3" then
		lookAtPoint(from, point)
	end
end

-- The map's island buttons call Skyship.choose; Main starts this once the HUD exists.
-- V10: the skyship's propellers turn (on every client, for itself). V13.2: the ship is one welded assembly, so each
-- hub hangs on a Motor6D ("Spin") and turning it is setting that joint's Transform (only on this client).
local spinners, spinAngle = nil, 0
local function spinPropellers(dt)
	if not spinners then
		local model = ship()
		if not model then
			return
		end
		spinners = {}
		for _, p in ipairs(model:GetChildren()) do
			local motor = p.Name == "PropellerHub" and p:FindFirstChild("Spin")
			if motor and motor:IsA("Motor6D") then
				table.insert(spinners, { motor = motor, side = p:GetAttribute("Spin") or 1 })
			end
		end
	end
	spinAngle += dt * 7
	for _, entry in ipairs(spinners) do
		entry.motor.Transform = CFrame.Angles(spinAngle * entry.side, 0, 0)
	end
end

-- V13.2: fly this client's copy of the ship along the raid's route, and carry this client's goblin with it while
-- they stand on it (or jump about over its deck): the ship moves by setting its Deck, which does not drag what stands on
-- it. A goblin in a cannon is welded into the ship and rides along anyway.
local function flyShip()
	local model = ship()
	local deck = model and model.PrimaryPart
	if not deck then
		return
	end
	local points, opensAt = SkyRoute.current()
	if not points then
		return
	end
	local cf = SkyRoute.cframeAt(points, opensAt, now())
	local before = shipFrame
	shipFrame = cf
	deck.CFrame = cf
	if not before or before == cf then
		return
	end
	local _, humanoid, root = character()
	if not root or root.Anchored or humanoid.SeatPart or diving or player:GetAttribute("Diving") then
		return
	end
	local state = player:GetAttribute("DeployState")
	if state == "loaded" or state == "fuse" then
		return
	end
	local onShip = before:PointToObjectSpace(root.Position)
	if math.abs(onShip.X) < 92 and onShip.Y > -7 and onShip.Y < 48 and math.abs(onShip.Z) < 112 then
		root.CFrame = cf * before:ToObjectSpace(root.CFrame)
	end
end

-- For the playtest hook: where this client has the ship.
function Skyship.shipFrame()
	return shipFrame
end

function Skyship.start()
	RunService.RenderStepped:Connect(spinPropellers)
	RunService.PreSimulation:Connect(flyShip)
	RunService.RenderStepped:Connect(flyShip)
	-- V13.2: the bell when the ship sets off and the cannons unlock.
	local rungFor = nil
	RunService.Heartbeat:Connect(function()
		local opensAt = workspace:GetAttribute("DeployOpensAt")
		if type(opensAt) == "number" and rungFor ~= opensAt and now() >= opensAt and now() < opensAt + 2 then
			rungFor = opensAt
			local state = player:GetAttribute("DeployState")
			if state == "aboard" or state == "loaded" then
				Effects.chime({ 1, 1.26, 1.5, 2 }, 0.8)
				Effects.sound("rise", { speed = 1.2, volume = 1 })
			end
		end
	end)
	build()
	Map.setSelector(Skyship.choose)
	RunService.RenderStepped:Connect(update)
	player:GetAttributeChangedSignal("Diving"):Connect(function()
		if not player:GetAttribute("Diving") then
			diving = false
			setAntiGravity(nil)
			landing = nil
			hidePreview()
			local _, humanoid = character()
			if humanoid and player:GetAttribute("DeployState") ~= "embedded" then
				humanoid.PlatformStand = false
			end
		end
	end)
	-- Open the map the first time you are aboard in a raid's start, so the sea is the first thing you see.
	-- V11: not straight after a raid ends: the winner dances on the deck first (Skyship.holdMap), then the map opens.
	local lastState
	player:GetAttributeChangedSignal("DeployState"):Connect(function()
		local state = player:GetAttribute("DeployState")
		if
			state == "aboard"
			and lastState ~= "aboard"
			and lastState ~= "loaded"
			and not player:GetAttribute("DeployDest")
		then
			local function openMap()
				if time() < mapHeldUntil then
					task.delay(mapHeldUntil - time(), openMap)
				elseif player:GetAttribute("DeployState") == "aboard" then
					Map.show(true)
				end
			end
			task.delay(1, openMap)
		elseif state == "loaded" or state == "fuse" or state == "diving" or lastState == "aboard" then
			Map.show(false) -- the sky is the thing to look at (V12: or off the deck any other way)
		end
		lastState = state
	end)
end

return Skyship

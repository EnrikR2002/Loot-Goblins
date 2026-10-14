-- The skyship, from the goblin's side: the banner that says what to do, the island you chose, the
-- cannon's aim and where the shot will land, and the dive itself (the character's own client flies
-- it; the server only decides how it ends). Also the pose every diver is drawn in, for everyone.
--
-- Keys, all shown on the banner for the moment they matter:
--   aboard    M map: click an island.   E at a cannon: climb in.   or jump off the side.
--   in cannon A D turn the aim, W S tilt it, SPACE fire, X climb out. A ring shows where it lands.
--   diving    WASD steer, hold SPACE to glide (a long reach), let go to pencil-dive (a fast drop).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Archipelago = require(Shared:WaitForChild("Archipelago"))
local Dive = require(Shared:WaitForChild("Dive"))
local Effects = require(script.Parent.Effects)
local Map = require(script.Parent.Map)

local Skyship = {}
Skyship.handlers = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LootGoblinsRemotes")
local deployRemote = remotes:WaitForChild("DeployRequest")

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 50)
local DARK = Color3.fromRGB(16, 16, 22)

local gui, banner, subline
local nudgeYaw, nudgeTilt = 0, 0
local lastAimSent = 0
local velocity = Vector3.zero -- our own dive velocity
local bounceVy = nil -- while a splash's hop is in the air: its own vertical speed, under its own gravity
local diveToken = 0
local diving = false
local preview = {} -- pooled neon dots
local markers = {} -- landing rings
local beam
local groundAt

local function now()
	return workspace:GetServerTimeNow()
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

-- The height of whatever is below (x, z): ground or the sea. Used by the landing preview.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false
local shipModel
function groundAt(x, z)
	if not shipModel then
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		local landmarks = generated and generated:FindFirstChild("Landmarks")
		shipModel = landmarks and landmarks:FindFirstChild("Skyship")
	end
	groundParams.FilterDescendantsInstances = { shipModel, player.Character, beam }
	local hit = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -800, 0), groundParams)
	return hit and hit.Position.Y or 0
end

-- The banner ------------------------------------------------------------------------------------
local function build()
	gui = make(
		"ScreenGui",
		{ Name = "LootGoblinsSky", ResetOnSpawn = false, DisplayOrder = 6, IgnoreGuiInset = false },
		player:WaitForChild("PlayerGui")
	)
	banner = make("TextLabel", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -196),
		Size = UDim2.fromOffset(640, 34),
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
		Size = UDim2.fromOffset(640, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.4,
		TextSize = 15,
		Text = "",
		Visible = false,
	}, gui)
end

local function destinationLabel()
	local id = player:GetAttribute("DeployDest")
	local island = id and Archipelago.byId[id]
	if not island then
		return nil, nil
	end
	local info = Config.ISLAND_INFO[id]
	return island, info
end

local function keyDown(...)
	for _, key in ipairs({ ... }) do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- The destination beam: a column of light over your island, so you can see it from the sky.
local function updateBeam()
	local island = destinationLabel()
	if not island then
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
			Size = Vector3.new(14, 1500, 14),
			Shape = Enum.PartType.Cylinder,
		}, nil)
	end
	local info = Config.ISLAND_INFO[player:GetAttribute("DeployDest")]
	beam.Color = Config.TIER_COLORS[info and info.tier or 1] or WHITE
	beam.CFrame = CFrame.new(island.x, 700, island.z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
end

-- The aiming camera: behind and above the cannon, looking where it points.
local aimCamera = false
local sailParts
local function seeThrough(on)
	-- The sails, masts and wings hide the sky from a cannon that shoots across the deck: fade them while aiming.
	if not sailParts then
		sailParts = {}
		local generated = workspace:FindFirstChild("LootGoblinsGenerated")
		local landmarks = generated and generated:FindFirstChild("Landmarks")
		local ship = landmarks and landmarks:FindFirstChild("Skyship")
		for _, p in ipairs(ship and ship:GetChildren() or {}) do
			if
				p:IsA("BasePart")
				and string.match(p.Name, "^[SMYEW]")
				and (
					string.find(p.Name, "Sail")
					or string.find(p.Name, "Mast")
					or string.find(p.Name, "Yard")
					or string.find(p.Name, "Emblem")
					or string.find(p.Name, "Wing")
				)
			then
				table.insert(sailParts, p)
			end
		end
	end
	for _, p in ipairs(sailParts) do
		p.LocalTransparencyModifier = on and 0.88 or 0
	end
end

local function aimView(root, aim)
	local camera = workspace.CurrentCamera
	if not aimCamera then
		seeThrough(true)
	end
	aimCamera = true
	camera.CameraType = Enum.CameraType.Scriptable
	local back = aim.Unit
	camera.CFrame = CFrame.lookAt(root.Position - back * 24 + Vector3.new(0, 10, 0), root.Position + back * 80)
	camera.FieldOfView = 72
end

local function releaseView()
	if aimCamera then
		aimCamera = false
		seeThrough(false)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

local function setBanner(text, sub)
	banner.Text = text or ""
	banner.Visible = text ~= nil and text ~= ""
	subline.Text = sub or ""
	subline.Visible = sub ~= nil and sub ~= ""
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
			Size = Vector3.new(4.5, 4.5, 4.5),
		}, workspace)
		preview[i] = p
	end
	return p
end

local function marker(i, color)
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
			Transparency = 0.35,
			Size = Vector3.new(0.6, 30, 30),
		}, workspace)
		markers[i] = m
	end
	m.Color = color
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

local function drawPreview(origin, v0)
	local used = 0
	local function arc(glide, color, markerIndex)
		local points, landing = Dive.predict(origin, v0, glide, groundAt, nil)
		for i = 1, #points do
			used += 1
			local p = dot(used)
			p.Color = color
			p.Transparency = glide and 0.2 or 0.55
			p.Position = points[i]
			p.Parent = workspace
		end
		local m = marker(markerIndex, color)
		if landing then
			m.CFrame = CFrame.new(landing + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
			m.Parent = workspace
		else
			m.Parent = nil
		end
		return landing
	end
	arc(true, Color3.fromRGB(120, 255, 190), 1)
	arc(false, Color3.fromRGB(255, 170, 80), 2)
	for i = used + 1, #preview do
		preview[i].Parent = nil
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

local function wantsGlide()
	return keyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

-- The dive -----------------------------------------------------------------------------------------
local function startDive(v, token)
	local _, humanoid, root = character()
	if not root then
		return
	end
	velocity = v
	bounceVy = nil
	diveToken = token or diveToken
	diving = true
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = v
	hidePreview()
end

local function stopDive()
	diving = false
end

RunService.PreSimulation:Connect(function(dt)
	if not diving then
		return
	end
	local _, humanoid, root = character()
	if not root or not player:GetAttribute("Diving") then
		diving = false
		return
	end
	humanoid.PlatformStand = true
	local glide = wantsGlide()
	local want = wantDirection()
	-- No hands on the keys: a weak pull toward your island keeps a glider on its way.
	if want.Magnitude < 0.1 and glide then
		local island = destinationLabel()
		if island then
			local toward = Vector3.new(island.x - root.Position.X, 0, island.z - root.Position.Z)
			if toward.Magnitude > 30 then
				want = toward.Unit * 0.5
			end
		end
	end
	velocity = Dive.step(velocity, want, glide, math.min(dt, 0.1))
	if bounceVy then
		-- The hop after a splash: ballistic until it falls as fast as the dive would let it.
		local sink = glide and Config.DIVE.GLIDE_SINK or Config.DIVE.PENCIL_FALL
		bounceVy -= Config.DIVE.BOUNCE_GRAVITY * math.min(dt, 0.1)
		if bounceVy <= -sink then
			bounceVy = nil
		else
			velocity = Vector3.new(velocity.X, bounceVy, velocity.Z)
		end
	end
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(root.Position) * Dive.orientation(velocity, glide).Rotation
end)

-- Pose, for everybody -----------------------------------------------------------------------------
local defaults = setmetatable({}, { __mode = "k" })

local function shoulders(character_)
	local upper = character_:FindFirstChild("UpperTorso")
	local torso = upper or character_:FindFirstChild("Torso")
	if not torso then
		return nil, nil
	end
	local left = torso:FindFirstChild(upper and "LeftShoulder" or "Left Shoulder")
	local right = torso:FindFirstChild(upper and "RightShoulder" or "Right Shoulder")
	return left, right
end

local function pose(character_, mode)
	local left, right = shoulders(character_)
	for index, joint in ipairs({ left, right }) do
		if joint and joint:IsA("Motor6D") then
			defaults[joint] = defaults[joint] or joint.C0
			local sign = index == 1 and 1 or -1
			if mode == "pencil" then
				joint.C0 = defaults[joint] * CFrame.Angles(0, 0, sign * math.rad(165))
			elseif mode == "glide" then
				joint.C0 = defaults[joint] * CFrame.Angles(0, 0, sign * math.rad(80))
			else
				joint.C0 = defaults[joint]
			end
		end
	end
end

local posed = setmetatable({}, { __mode = "k" })
RunService.PreRender:Connect(function()
	for _, other in ipairs(Players:GetPlayers()) do
		local c = other.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root then
			local mode = nil
			if other:GetAttribute("Diving") then
				mode = root.CFrame.UpVector.Y < -0.3 and "pencil" or "glide"
			end
			if posed[c] ~= mode then
				posed[c] = mode
				pose(c, mode)
			end
		end
	end
end)

-- Each frame: the banner, the aim and its preview --------------------------------------------------
local nextPreview = 0
local function update()
	local phase = player:GetAttribute("DeployState")
	local t = now()
	local opensAt = workspace:GetAttribute("DeployOpensAt")
	local endsAt = workspace:GetAttribute("DeployEndsAt")
	local island, info = destinationLabel()
	local target = island and (island.name .. "  " .. (Config.TIER_NAMES[info and info.tier or 1] or ""))
		or "no island chosen: press M"
	updateBeam()
	if phase == "aboard" then
		releaseView()
		if Map.isOpen() then
			-- The map is the picker: its title says what a click does.
			Map.setTitle("CLICK AN ISLAND TO LAND THERE  -  then climb into a cannon (E)  -  M closes")
			setBanner(nil)
		elseif opensAt and t < opensAt then
			Map.setTitle()
			setBanner(
				string.format("THE CANNONS UNLOCK IN %d", math.ceil(opensAt - t)),
				"Pick your island on the map (M)"
			)
		else
			Map.setTitle()
			local left = endsAt and math.max(0, math.ceil(endsAt - t)) or 0
			setBanner(
				string.format("CHOOSE AN ISLAND (M)  -  CLIMB INTO A CANNON (E)  -  %d s", left),
				"Landing at: " .. target .. "   |   or jump off the side"
			)
		end
		hidePreview()
	elseif phase == "loaded" or phase == "fuse" then
		Map.setTitle()
		setBanner(
			phase == "fuse" and "FIRING..." or "SPACE: FIRE   A/D: TURN   W/S: TILT   X: CLIMB OUT",
			"Landing at: " .. target .. "   |   green: glide, orange: pencil dive"
		)
		local aim = player:GetAttribute("DeployAim")
		local _, _, root = character()
		if aim and root then
			aimView(root, aim)
		end
		if phase == "loaded" then
			local dt = 1 / 60
			local turn = (keyDown(Enum.KeyCode.D) and -1 or 0) + (keyDown(Enum.KeyCode.A) and 1 or 0)
			local tilt = (keyDown(Enum.KeyCode.W) and 1 or 0) + (keyDown(Enum.KeyCode.S) and -1 or 0)
			if turn ~= 0 or tilt ~= 0 then
				nudgeYaw = math.clamp(nudgeYaw + turn * 0.5 * dt, -Config.DIVE.NUDGE_YAW, Config.DIVE.NUDGE_YAW)
				nudgeTilt = math.clamp(nudgeTilt + tilt * 0.4 * dt, -Config.DIVE.NUDGE_PITCH, Config.DIVE.NUDGE_PITCH)
			end
			if t - lastAimSent > 0.12 and (turn ~= 0 or tilt ~= 0) then
				lastAimSent = t
				deployRemote:FireServer("aim", nudgeYaw, nudgeTilt)
			end
			if os.clock() > nextPreview then
				nextPreview = os.clock() + 0.15
				if aim and root then
					drawPreview(root.Position, aim)
				end
			end
		end
	elseif player:GetAttribute("Diving") then
		releaseView()
		Map.setTitle()
		local _, _, root = character()
		local distance = ""
		if island and root then
			local flatDistance = Vector3.new(island.x - root.Position.X, 0, island.z - root.Position.Z).Magnitude
			distance = string.format("%s: %d studs", island.name, flatDistance)
		end
		local altitude = root and math.max(0, root.Position.Y - groundAt(root.Position.X, root.Position.Z)) or 0
		setBanner(
			wantsGlide() and "GLIDING" or "PENCIL DIVE  (hold SPACE to glide)",
			string.format("%s   |   %d up   |   WASD steer", distance, altitude)
		)
		hidePreview()
	else
		releaseView()
		Map.setTitle()
		setBanner(nil)
		hidePreview()
		nudgeYaw, nudgeTilt = 0, 0
	end
end

-- Keys that are not movement ---------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local phase = player:GetAttribute("DeployState")
	if phase == "loaded" then
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			deployRemote:FireServer("aim", nudgeYaw, nudgeTilt)
			deployRemote:FireServer("fire")
		elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonB then
			deployRemote:FireServer("leave")
		end
	end
end)

-- Choosing an island on the map (Map.lua calls this).
function Skyship.choose(id)
	deployRemote:FireServer("choose", id)
	player:SetAttribute("DeployDest", id) -- shown at once; the server's copy follows
end

-- Server events -------------------------------------------------------------------------------------
function Skyship.handlers.DiveStart(p)
	startDive(p.velocity, p.token)
	Effects.punchFov(100)
end

function Skyship.handlers.DiveBounce(p)
	local _, _, root = character()
	if not root then
		return
	end
	velocity = p.velocity
	bounceVy = p.velocity.Y
	diveToken = p.token or diveToken
	root.AssemblyLinearVelocity = p.velocity
	Effects.punchFov(104)
end

function Skyship.handlers.DiveFire(p)
	Effects.burst(p.position + p.direction * 8, Color3.fromRGB(255, 200, 90), 60, 50)
	Effects.ring(p.position + p.direction * 8, Color3.fromRGB(255, 240, 200), 18, 0.4)
	Effects.sound("boom", { position = p.position, speed = 1.1, volume = 1, range = 500 })
	Effects.shakeAt(p.position, 0.9, 0.35, 90)
end

function Skyship.handlers.DiveImpact(p)
	if p.kind == "water" then
		Effects.spray(p.position, 1.6)
		Effects.ring(p.position + Vector3.new(0, 1, 0), Color3.fromRGB(190, 240, 255), 36, 0.8)
		Effects.burst(p.position + Vector3.new(0, 2, 0), Color3.fromRGB(235, 250, 255), 70, 60)
		Effects.sound("rise", { position = p.position, speed = 0.7, volume = 1, range = 500 })
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

-- The map's island buttons call Skyship.choose; Main starts this once the HUD exists.
function Skyship.start()
	build()
	Map.setSelector(Skyship.choose)
	RunService.RenderStepped:Connect(update)
	player:GetAttributeChangedSignal("Diving"):Connect(function()
		if not player:GetAttribute("Diving") then
			stopDive()
			local _, humanoid = character()
			if humanoid then
				humanoid.PlatformStand = false
			end
		end
	end)
	-- Open the map the first time you are aboard in a raid's start, so the choice is the first thing you see.
	local lastState
	player:GetAttributeChangedSignal("DeployState"):Connect(function()
		local state = player:GetAttribute("DeployState")
		if state == "aboard" and lastState ~= "aboard" and not player:GetAttribute("DeployDest") then
			task.delay(1, function()
				if player:GetAttribute("DeployState") == "aboard" then
					Map.show(true)
				end
			end)
		elseif state == "loaded" then
			Map.show(false)
			nudgeYaw, nudgeTilt = 0, 0
		elseif state == "fuse" or state == "diving" then
			Map.show(false) -- the choice is made: the sky is the thing to look at
		end
		lastState = state
	end)
end

return Skyship

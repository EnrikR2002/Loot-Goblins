-- Cannon Golf on this client (V13.3; V13.5: water-skipping golf in strokes). While you sit in a tee cannon (DeployState
-- "loaded", LaunchKind "golf") the camera stands behind it and you AIM THE WAY YOU LOOK: left and right (mouse, A/D or
-- the arrows, the left or right stick, a finger dragged across) and UP for a lob or DOWN for a skimmer (mouse, W/S or
-- the arrows, a stick). Then HOLD (Space, a click, A on a controller, or HOLD on a touch screen) to charge: the meter
-- swings up and down; let go to fire yourself. The server turns (direction, power) into the throw (shared/PortGames.lua:
-- PortGames.golfVelocity) and judges where you come down. Nothing predicts the shot while aiming: reading the
-- distance is the game. In the air the camera chases you (client/Skyship.lua draws the rings where you will touch the
-- sea next and counts the skips), and holds on where you land for a moment.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local PortGames = require(Shared:WaitForChild("PortGames"))
local Ui = require(script.Parent.Ui)
local Effects = require(script.Parent.Effects)

local PlayGolf = {}

local player = Players.LocalPlayer
local GF = Config.PLAYGROUND.GOLF
local SKIM = Config.DIVE.SKIM
local golf = PortGames.GOLF
local C = Ui.C

local ctx
local gui, meter, fill, readout, holeLabel, tipLabel, angleLabel
local aiming = false
local yaw = 0 -- radians from the tee's heading
local pitch = GF.ELEVATION -- the elevation (radians)
local charging, chargeFrom = false, 0
local nextAimSend = 0
local stick = Vector2.zero
local touchDrag = Vector2.zero
local dots = {}
local chase = nil -- the chase camera: { eye, look } while a golf shot flies
local holdUntil, holdAt = 0, nil -- after a landing: look at it this long
local inGolf = false

local function teeFrom()
	local from = player:GetAttribute("LaunchFrom")
	return typeof(from) == "Vector3" and from or golf.tees[2].from
end

local function flatDirection()
	return PortGames.turn(golf.facing, math.deg(yaw))
end

-- The aim as the server takes it: the flat way, raised by the elevation.
local function aimVector()
	local d = flatDirection()
	return d * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
end

local function power()
	local phase = ((os.clock() - chargeFrom) / GF.POWER_CYCLE) % 1
	return phase < 0.5 and phase * 2 or (1 - phase) * 2
end

local function myShow()
	local row = ctx and ctx.myRow
	local x = row and row.x
	return type(x) == "table" and x or nil
end

local function myHole()
	local x = myShow()
	return x and x.hole or 1
end

-- Aim at the current hole when it starts (it is up to you from there). The elevation is kept: a habit is a skill.
local function aimAtHole()
	local hole = golf.holes[myHole()]
	if not hole then
		yaw = 0
		return
	end
	local to = hole.center - teeFrom()
	local flat = Vector3.new(to.X, 0, to.Z).Unit
	local angle = math.deg(math.acos(math.clamp(flat:Dot(golf.facing), -1, 1)))
	local side = golf.facing:Cross(flat).Y >= 0 and -1 or 1
	yaw = math.rad(angle * side)
end

-- Will this shot skip? Its arrival on the sea (the tee stands above the water, so it comes down a little steeper than it
-- left) against the skimmer's limit, at the power charged so far (full power while not charging): a weak low shot plops.
local function skims(p)
	local speed = GF.MIN_SPEED + (GF.MAX_SPEED - GF.MIN_SPEED) * p
	local across, up = speed * math.cos(pitch), speed * math.sin(pitch)
	local fall = math.sqrt(up * up + 2 * Config.DIVE.GRAVITY * math.max(0, teeFrom().Y - 1))
	return math.deg(math.atan2(fall, across)) <= SKIM.MAX_ANGLE
end

local function fire()
	if not aiming then
		return
	end
	charging = false
	local p = power()
	ctx.remote:FireServer("golf", aimVector(), p)
	Effects.sound("boom", { speed = 1.2, volume = 0.6 })
	Effects.punchFov(96)
end

local function onCharge(_, state)
	if not aiming then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		charging = true
		chargeFrom = os.clock()
		Effects.sound("blip", { speed = 1.6, volume = 0.4 })
	elseif state == Enum.UserInputState.End and charging then
		fire()
	end
	return Enum.ContextActionResult.Sink
end

local function enter()
	aiming = true
	charging = false
	chase = nil
	aimAtHole()
	ContextActionService:BindActionAtPriority(
		"LootGoblinsGolfCharge",
		onCharge,
		true,
		3100,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.UserInputType.MouseButton1
	)
	ContextActionService:SetTitle("LootGoblinsGolfCharge", "HOLD")
	ContextActionService:SetPosition("LootGoblinsGolfCharge", UDim2.new(1, -150, 1, -150))
	gui.Enabled = true
end

local function exit()
	aiming = false
	charging = false
	ContextActionService:UnbindAction("LootGoblinsGolfCharge")
	gui.Enabled = false
	for _, d in ipairs(dots) do
		d.Transparency = 1
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function releaseCamera()
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
end

function PlayGolf.start(context)
	ctx = context
	gui = Ui.make(
		"ScreenGui",
		{ Name = "LootGoblinsGolf", ResetOnSpawn = false, DisplayOrder = 8, Enabled = false },
		player:WaitForChild("PlayerGui")
	)
	meter = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, 90, 0.5, 0),
		Size = UDim2.fromOffset(30, 220),
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.25,
	}, gui)
	Ui.corner(meter, 12)
	Ui.stroke(meter, C.gold, 2)
	fill = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -4),
		Size = UDim2.new(1, -8, 0, 0),
		BackgroundColor3 = C.gold,
	}, meter)
	Ui.corner(fill, 9)
	Ui.make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(120, 230, 110), Color3.fromRGB(255, 90, 60)),
		Rotation = -90,
	}, fill)
	angleLabel = Ui.label(gui, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, 128, 0.5, 0),
		Size = UDim2.fromOffset(150, 40),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 16,
		TextColor3 = C.white,
		TextWrapped = true,
	})
	Ui.stroke(angleLabel, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	readout = Ui.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 130),
		Size = UDim2.fromOffset(460, 26),
		Text = "",
		Font = Ui.TITLE,
		TextSize = 20,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.stroke(readout, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	holeLabel = Ui.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 158),
		Size = UDim2.fromOffset(460, 20),
		Text = "",
		Font = Ui.BOLD,
		TextSize = 15,
		TextColor3 = C.goldPale,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	tipLabel = Ui.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 180),
		Size = UDim2.fromOffset(460, 18),
		Text = "",
		Font = Ui.BODY,
		TextSize = 14,
		TextColor3 = C.parchment,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	for i = 1, 10 do
		local d = Ui.make("Part", {
			Name = "GolfAimDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = C.goldPale,
			Transparency = 1,
		}, workspace)
		dots[i] = d
	end
	UserInputService.InputChanged:Connect(function(input, processed)
		if not aiming then
			return
		end
		if input.KeyCode == Enum.KeyCode.Thumbstick2 or input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local v = Vector2.new(input.Position.X, input.Position.Y)
			stick = v.Magnitude > 0.18 and v or Vector2.zero
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			touchDrag += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
end

local function key(...)
	for _, code in ipairs({ ... }) do
		if UserInputService:IsKeyDown(code) then
			return 1
		end
	end
	return 0
end

-- The chase camera while a golf shot flies, and the hold on the landing afterwards.
local function chaseCamera(dt)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local flying = inGolf and player:GetAttribute("Diving") and player:GetAttribute("LaunchKind") == "golf"
	if flying and root then
		local v = root.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		local way = flat.Magnitude > 4 and flat.Unit or (chase and chase.way) or golf.facing
		local goalEye = root.Position - way * 34 + Vector3.new(0, 12, 0)
		local goalLook = root.Position + way * 26 + Vector3.new(0, -4, 0)
		if not chase then
			chase = { eye = camera.CFrame.Position, look = goalLook }
		end
		local k = 1 - math.exp(-dt * 4.5)
		chase.eye = chase.eye:Lerp(goalEye, k)
		chase.look = chase.look:Lerp(goalLook, 1 - math.exp(-dt * 7))
		chase.way = way
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(chase.eye, chase.look)
		return true
	end
	if chase then
		-- Down: hold on the landing for a moment (a big finish deserves a look).
		chase = nil
		holdUntil = os.clock() + 1.1
		holdAt = root and root.Position or nil
	end
	if holdAt and os.clock() < holdUntil and not aiming then
		local camera_ = workspace.CurrentCamera
		local eye = camera_.CFrame.Position
		camera_.CameraType = Enum.CameraType.Scriptable
		camera_.CFrame = CFrame.lookAt(eye, eye:Lerp(holdAt, 1 - math.exp(-dt * 6)) + Vector3.new(0, 1, 0))
		return true
	elseif holdAt then
		holdAt = nil
		if not aiming then
			releaseCamera()
		end
	end
	return false
end

function PlayGolf.update(dt, context)
	ctx = context
	local session = ctx and ctx.mine
	inGolf = session ~= nil and session.game == "golf"
	local loaded = player:GetAttribute("DeployState") == "loaded" and player:GetAttribute("LaunchKind") == "golf"
	if loaded and not aiming then
		enter()
	elseif not loaded and aiming then
		exit()
	end
	if not aiming then
		chaseCamera(dt)
		if not inGolf and not holdAt then
			chase = nil
		end
		return
	end
	-- Turning and raising.
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local delta = UserInputService:GetMouseDelta() + touchDrag
	touchDrag = Vector2.zero
	local turnKeys = key(Enum.KeyCode.D, Enum.KeyCode.Right) - key(Enum.KeyCode.A, Enum.KeyCode.Left)
	local tiltKeys = key(Enum.KeyCode.W, Enum.KeyCode.Up) - key(Enum.KeyCode.S, Enum.KeyCode.Down)
	yaw += delta.X * 0.0035 + (turnKeys + stick.X) * 0.9 * dt
	yaw = math.clamp(yaw, -math.rad(GF.YAW_MAX), math.rad(GF.YAW_MAX))
	pitch -= delta.Y * 0.0028
	pitch += (tiltKeys + stick.Y) * 0.7 * dt
	pitch = math.clamp(pitch, GF.ELEVATION_MIN, GF.ELEVATION_MAX)
	local dir = flatDirection()
	-- The camera behind the cannon, looking along the aim: up for a lob shows the sky, down for a skimmer the sea.
	local from = teeFrom()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local eye = from - dir * 16 + Vector3.new(0, 9, 0)
	local lookUp = (pitch - GF.ELEVATION) * 40
	camera.CFrame = CFrame.lookAt(eye, from + dir * 60 + Vector3.new(0, -4 + lookUp, 0))
	-- A short line of dots on the water: which way, never how far.
	for i, d in ipairs(dots) do
		local spot = from + dir * (8 + i * 7)
		d.CFrame = CFrame.new(spot.X, 2.4, spot.Z)
		d.Transparency = 0.35 + i * 0.05
	end
	local p = charging and power() or 0
	fill.Size = UDim2.new(1, -8, p, -8 * p)
	local skimmer = skims(charging and p or 1)
	angleLabel.Text = string.format("%d°\n%s", math.floor(math.deg(pitch) + 0.5), skimmer and "SKIPS" or "LOB")
	angleLabel.TextColor3 = skimmer and Color3.fromRGB(150, 230, 255) or C.goldPale
	local x = myShow()
	local hole = golf.holes[myHole()]
	if hole then
		local distance = (Vector3.new(hole.center.X, 0, hole.center.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
		holeLabel.Text = string.format(
			"HOLE %d: %s  ·  PAR %d  ·  SHOT %d/%d  ·  %d studs",
			myHole(),
			hole.name,
			hole.par,
			x and x.shot or 1,
			hole.par + 1,
			distance
		)
		tipLabel.Text = hole.tip
	end
	readout.Text = charging and string.format("POWER %d%%  ·  LET GO TO FIRE", math.floor(p * 100 + 0.5))
		or "AIM: look (or WASD): low skips, high lobs  ·  HOLD SPACE (or click) TO CHARGE"
	if os.clock() >= nextAimSend then
		nextAimSend = os.clock() + 0.25
		ctx.remote:FireServer("golfaim", aimVector())
	end
end

-- The server's word on a shot: where it came down and what it counts for.
function PlayGolf.fx(p)
	if p.kind == "golfland" then
		local mine = p.userId == player.UserId
		local headline
		if p.grade == "cup" then
			headline = "IN THE CUP!"
		elseif p.grade == "green" then
			headline = "ON THE " .. ((golf.holes[p.hole or 1] or {}).kind == "pad" and "PAD!" or "GREEN!")
		elseif p.grade == "pickup" then
			headline = "PICKED UP"
		else
			headline = "SPLASH!"
		end
		local name = p.strokes and p.par and PortGames.golfName(p.strokes, p.par) or nil
		local good = p.grade == "cup" or p.grade == "green"
		if p.position then
			Effects.ring(p.position + Vector3.new(0, 0.8, 0), good and C.gold or Color3.fromRGB(150, 220, 255), 10, 0.8)
			if p.grade == "cup" then
				Effects.firework(p.position + Vector3.new(0, 10, 0), C.gold)
				Effects.firework(p.position + Vector3.new(4, 12, 0), Color3.fromRGB(150, 240, 130))
				Effects.dustRing(p.position, 18, Color3.fromRGB(255, 240, 180))
			elseif good then
				Effects.burst(p.position + Vector3.new(0, 3, 0), Color3.fromRGB(150, 240, 130), 40, 26)
			end
			Effects.sound(good and "rise" or "splash", { position = p.position, volume = 0.9, range = 400 })
			Effects.popText(
				p.position + Vector3.new(0, 6, 0),
				name and (headline .. "  " .. name) or headline,
				good and C.goldPale or Color3.fromRGB(170, 230, 255),
				2
			)
		end
		if mine and ctx and ctx.hud then
			local skips = (p.skips or 0) > 0 and string.format("  ·  %d skip%s", p.skips, p.skips > 1 and "s" or "")
				or ""
			local line
			if p.strokes then
				line = string.format("%s  %s (%d)%s", headline, name or "", p.strokes, skips)
			else
				line = string.format("%s  Shot %d of %d%s", headline, (p.shot or 1) + 1, (p.par or 2) + 1, skips)
			end
			ctx.hud.banner(line, good and C.gold or Color3.fromRGB(170, 230, 255), 2.2, 3)
			if p.grade == "cup" and p.strokes == 1 then
				Effects.chime({ 1, 1.26, 1.5, 2, 2.5 }, 0.8)
			elseif good then
				Effects.chime(Effects.CHIME_GOOD, 0.6)
			end
		end
		return true
	elseif p.kind == "golfhole" then
		task.defer(aimAtHole)
		return true
	end
	return false
end

return PlayGolf

-- Cannon Golf on this client (V13.3): while you sit in a tee cannon (DeployState "loaded", LaunchKind "golf"), the
-- camera stands behind it and you AIM THE WAY YOU LOOK (mouse, A/D or the arrow keys, the right stick, or a finger
-- dragged across the screen), then HOLD (Space, a click, A on a controller, or CHARGE on a touch screen) to charge:
-- the meter swings up and down; let go to fire yourself. The server turns (direction, power) into the throw
-- (shared/PortGames.lua: PortGames.golfVelocity) and scores where you come to rest. Nothing about the shot is
-- predicted on screen: reading the distance is the game.
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
local golf = PortGames.GOLF
local C = Ui.C

local ctx
local gui, meter, fill, readout, holeLabel
local aiming = false
local yaw = 0 -- radians from the tee's heading
local charging, chargeFrom = false, 0
local nextAimSend = 0
local stick = 0
local touchDrag = 0
local dots = {}

local function teeFrom()
	local from = player:GetAttribute("LaunchFrom")
	return typeof(from) == "Vector3" and from or golf.tees[2].from
end

local function direction()
	return PortGames.turn(golf.facing, math.deg(yaw))
end

local function power()
	local phase = ((os.clock() - chargeFrom) / GF.POWER_CYCLE) % 1
	return phase < 0.5 and phase * 2 or (1 - phase) * 2
end

local function myHole()
	local row = ctx and ctx.myRow
	local x = row and row.x
	return type(x) == "table" and x.hole or 1
end

-- Aim at the current green when a hole starts (it is up to you from there).
local function aimAtHole()
	local green = golf.greens[myHole()]
	if not green then
		yaw = 0
		return
	end
	local to = green.center - teeFrom()
	local flat = Vector3.new(to.X, 0, to.Z).Unit
	local angle = math.deg(math.acos(math.clamp(flat:Dot(golf.facing), -1, 1)))
	local side = golf.facing:Cross(flat).Y >= 0 and -1 or 1
	yaw = math.rad(angle * side)
end

local function fire()
	if not aiming then
		return
	end
	charging = false
	local p = power()
	ctx.remote:FireServer("golf", direction(), p)
	Effects.sound("boom", { speed = 1.2, volume = 0.6 })
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
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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
	readout = Ui.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 130),
		Size = UDim2.fromOffset(420, 26),
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
		Size = UDim2.fromOffset(420, 20),
		Text = "",
		Font = Ui.BOLD,
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
			stick = math.abs(input.Position.X) > 0.18 and input.Position.X or 0
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			touchDrag += input.Delta.X
		end
	end)
end

function PlayGolf.update(dt, context)
	ctx = context
	local loaded = player:GetAttribute("DeployState") == "loaded" and player:GetAttribute("LaunchKind") == "golf"
	if loaded and not aiming then
		enter()
	elseif not loaded and aiming then
		exit()
	end
	if not aiming then
		return
	end
	-- Turning.
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local delta = UserInputService:GetMouseDelta().X + touchDrag
	touchDrag = 0
	local keys = (UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)) and 1
		or 0
	keys -= (UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)) and 1 or 0
	yaw += delta * 0.0035 + (keys + stick) * 0.9 * dt
	yaw = math.clamp(yaw, -math.rad(GF.YAW_MAX), math.rad(GF.YAW_MAX))
	local dir = direction()
	-- The camera behind the cannon, looking along the aim and a little down at the water.
	local from = teeFrom()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local eye = from - dir * 16 + Vector3.new(0, 9, 0)
	camera.CFrame = CFrame.lookAt(eye, from + dir * 60 + Vector3.new(0, -4, 0))
	camera.FieldOfView = 70
	-- A short line of dots on the water: which way, never how far.
	for i, d in ipairs(dots) do
		local at = from + dir * (8 + i * 7)
		d.CFrame = CFrame.new(at.X, 2.4, at.Z)
		d.Transparency = 0.35 + i * 0.05
	end
	local p = charging and power() or 0
	fill.Size = UDim2.new(1, -8, p, -8 * p)
	local green = golf.greens[myHole()]
	if green then
		local distance = (Vector3.new(green.center.X, 0, green.center.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
		holeLabel.Text = string.format("HOLE %d: %s  ·  %d studs", myHole(), green.name, distance)
	end
	readout.Text = charging and string.format("POWER %d%%  ·  LET GO TO FIRE", math.floor(p * 100 + 0.5))
		or "AIM: look or A/D  ·  HOLD SPACE (or click) TO CHARGE"
	if os.clock() >= nextAimSend then
		nextAimSend = os.clock() + 0.25
		ctx.remote:FireServer("golfaim", dir)
	end
end

-- The server's word on a shot: where it came down and what it scored.
local GRADE =
	{ cup = "IN THE CUP!", near = "SO CLOSE!", green = "ON THE GREEN!", fringe = "THE FRINGE", miss = "SPLASH!" }
function PlayGolf.fx(p)
	if p.kind == "golfland" and p.position then
		local mine = p.userId == player.UserId
		local text = string.format("%s  +%d", GRADE[p.grade] or "", p.points or 0)
		Effects.ring(
			p.position + Vector3.new(0, 0.8, 0),
			p.points and p.points > 0 and C.gold or Color3.fromRGB(150, 220, 255),
			10,
			0.8
		)
		if p.grade == "cup" then
			Effects.firework(p.position + Vector3.new(0, 10, 0), C.gold)
		end
		Effects.sound(p.points > 0 and "rise" or "splash", { position = p.position, volume = 0.9, range = 400 })
		local anchor = Ui.make("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(p.position + Vector3.new(0, 5, 0)),
		}, workspace)
		local bill = Ui.make("BillboardGui", {
			Adornee = anchor,
			Size = UDim2.fromOffset(260, 50),
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 600,
		}, anchor)
		local label = Ui.label(bill, {
			Size = UDim2.fromScale(1, 1),
			Text = text,
			Font = Ui.TITLE,
			TextScaled = true,
			TextColor3 = (p.points or 0) > 0 and C.goldPale or Color3.fromRGB(170, 230, 255),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.stroke(label, C.night, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		task.delay(2.4, function()
			anchor:Destroy()
		end)
		if mine and ctx and ctx.hud then
			ctx.hud.banner(
				string.format(
					"%s  +%d  (%.1f studs from the pin)",
					GRADE[p.grade] or "",
					p.points or 0,
					p.distance or 0
				),
				C.gold,
				2.2,
				3
			)
		end
		return true
	elseif p.kind == "golfhole" then
		task.defer(aimAtHole)
		return true
	elseif p.kind == "golfskip" then
		if ctx and ctx.hud then
			ctx.hud.toast("Hole skipped: you sat in the cannon too long.")
		end
		return true
	end
	return false
end

return PlayGolf

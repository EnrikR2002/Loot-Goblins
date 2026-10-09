-- Local-only feedback: sounds, flashes of neon, particles, camera shake and the
-- screen tint that follows Heat. Nothing here changes game state.
--
-- Sounds use files that ship inside every Roblox client (rbxasset://sounds/...),
-- so they need no uploaded assets or permissions. Pitch changes turn the same
-- few files into chimes, alarms and thuds.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local SOUNDS = {
	boom = "rbxasset://sounds/impact_explosion_03.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
	whoosh = "rbxasset://sounds/action_jump.mp3",
	thud = "rbxasset://sounds/action_jump_land.mp3",
	rise = "rbxasset://sounds/action_get_up.mp3",
	blip = "rbxasset://sounds/volume_slider.ogg",
	ouch = "rbxasset://sounds/ouch.ogg",
}

local camera = workspace.CurrentCamera

-- name: key of SOUNDS. options: volume, speed, position (3D sound), range.
function Effects.sound(name, options)
	options = options or {}
	local sound = Instance.new("Sound")
	sound.SoundId = SOUNDS[name]
	sound.Volume = options.volume or 0.6
	sound.PlaybackSpeed = options.speed or 1
	if options.position then
		local holder = Instance.new("Attachment")
		holder.Name = "SoundAt"
		holder.Position = options.position
		holder.Parent = workspace.Terrain
		sound.RollOffMaxDistance = options.range or 350
		sound.RollOffMinDistance = 15
		sound.Parent = holder
		Debris:AddItem(holder, 5)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 5)
	end
	sound:Play()
end

-- A quick arpeggio built from one blip at different pitches.
function Effects.chime(pitches, volume)
	for i, pitch in ipairs(pitches) do
		task.delay((i - 1) * 0.07, function()
			Effects.sound("blip", { speed = pitch, volume = volume or 0.7 })
		end)
	end
end

Effects.CHIME_GOOD = { 1, 1.26, 1.5, 2 }
Effects.CHIME_STEAL = { 1.5, 1.26, 1, 0.75 }
Effects.CHIME_ALARM = { 0.6, 0.45, 0.6, 0.45, 0.6 }

-- Neon pieces ------------------------------------------------------------------
local function fxPart(size, cframe, color, shape)
	local p = Instance.new("Part")
	p.Name = "FX"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

local function fadeOut(p, duration, goal)
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad), goal):Play()
	Debris:AddItem(p, duration)
end

-- A flat ring that spreads out from a point on the ground.
function Effects.ring(position, color, radius, duration)
	local ring = fxPart(
		Vector3.new(0.2, 2, 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.2
	fadeOut(ring, duration or 0.45, { Size = Vector3.new(0.2, radius * 2, radius * 2) })
end

function Effects.line(from, to, color, width, duration)
	local distance = (to - from).Magnitude
	if distance < 0.3 then
		return
	end
	local line = fxPart(Vector3.new(width, width, distance), CFrame.lookAt((from + to) / 2, to), color)
	line.Transparency = 0.1
	fadeOut(line, duration or 0.25, { Size = Vector3.new(width * 0.2, width * 0.2, distance) })
end

function Effects.ball(position, color, size, duration)
	local ball = fxPart(Vector3.new(1, 1, 1), CFrame.new(position), color, Enum.PartType.Ball)
	ball.Transparency = 0.15
	fadeOut(ball, duration or 0.4, { Size = Vector3.new(size, size, size) })
end

-- One-shot sparkle burst.
function Effects.burst(position, color, count, speed)
	local holder = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), color)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(speed or 18, (speed or 18) * 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.9, 0)
	emitter.Parent = holder
	emitter:Emit(count or 30)
	Debris:AddItem(holder, 2)
end

-- Visual-only explosion (no push, nothing breaks).
function Effects.explosion(position, radius)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = radius or 6
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	Effects.sound("boom", { position = position, volume = 0.8 })
end

-- Camera shake --------------------------------------------------------------------
local shakeUntil, shakePower = 0, 0
function Effects.shake(power, duration)
	shakePower = math.max(shakePower, power)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

-- Shake only nudges this player's own camera offset.
RunService.RenderStepped:Connect(function()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if os.clock() < shakeUntil then
		local p = shakePower
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * p, (math.random() - 0.5) * p, 0)
	elseif shakePower > 0 then
		shakePower = 0
		humanoid.CameraOffset = Vector3.zero
	end
end)

-- Distance-scaled shake for something that happened at a point.
function Effects.shakeAt(position, power, duration, range)
	local distance = (camera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - distance / (range or 120), 0, 1)
	if falloff > 0 then
		Effects.shake(power * falloff, duration)
	end
end

-- Heat tint ----------------------------------------------------------------------
local heatTint = Instance.new("ColorCorrectionEffect")
heatTint.Name = "HeatTint"
heatTint.Parent = Lighting

local HEAT_TINTS = {
	{ tint = Color3.new(1, 1, 1), saturation = 0.05, contrast = 0 },
	{ tint = Color3.fromRGB(255, 248, 230), saturation = 0.1, contrast = 0.03 },
	{ tint = Color3.fromRGB(255, 230, 205), saturation = 0.15, contrast = 0.06 },
	{ tint = Color3.fromRGB(255, 205, 190), saturation = 0.2, contrast = 0.1 },
}

function Effects.setHeatTier(tier)
	local look = HEAT_TINTS[tier] or HEAT_TINTS[1]
	TweenService:Create(heatTint, TweenInfo.new(1.2), {
		TintColor = look.tint,
		Saturation = look.saturation,
		Contrast = look.contrast,
	}):Play()
end

-- Spirit form turns the world cold and pale for the spirit only.
local spiritTint = Instance.new("ColorCorrectionEffect")
spiritTint.Name = "PoltergoblinTint"
spiritTint.Parent = Lighting

function Effects.setSpirit(active)
	TweenService:Create(spiritTint, TweenInfo.new(active and 0.15 or 0.35), {
		TintColor = active and Color3.fromRGB(200, 255, 225) or Color3.new(1, 1, 1),
		Saturation = active and -0.45 or 0,
	}):Play()
end

-- Sprinting widens the resting field of view; punches settle back to it.
local baseFov = 70

function Effects.setBaseFov(fov)
	baseFov = fov
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { FieldOfView = fov }):Play()
end

function Effects.punchFov(fov)
	camera.FieldOfView = fov
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { FieldOfView = baseFov }):Play()
end

-- A grapple rope from a moving part to a fixed point, for a few seconds.
-- Returns the holder so the caller can cut it early.
function Effects.rope(part, to, color, duration)
	local holder = Instance.new("Attachment")
	holder.Name = "GrappleRope"
	holder.Parent = part
	local anchor = Instance.new("Attachment")
	anchor.Name = "GrappleHook"
	anchor.Parent = workspace.Terrain
	anchor.WorldPosition = to
	local beam = Instance.new("Beam")
	beam.Attachment0 = holder
	beam.Attachment1 = anchor
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 0.6
	beam.FaceCamera = true
	beam.Width0 = 0.35
	beam.Width1 = 0.2
	beam.Segments = 1
	beam.Parent = holder
	-- The hook end lives in Terrain, so it goes with the holder.
	holder.Destroying:Connect(function()
		anchor:Destroy()
	end)
	Debris:AddItem(holder, duration or 2)
	return holder
end

-- Danger markers ------------------------------------------------------------------------------
-- A marked circle on the ground: a faint full disc, with a bright one that grows to fill it. When
-- it is full, the blast lands. Every telegraphed attack in the game (the Guardian's leap, Navy
-- shells, lava bombs, lightning, tentacles) uses this, so one visual language means "get out".
local MARKER_COLORS = {
	stomp = Color3.fromRGB(255, 150, 60),
	lava = Color3.fromRGB(255, 100, 30),
	kraken = Color3.fromRGB(190, 110, 255),
	lightning = Color3.fromRGB(215, 230, 255),
}

function Effects.marker(position, radius, duration, color, style)
	color = color or MARKER_COLORS[style] or Color3.fromRGB(255, 80, 60)
	local flat = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local base = fxPart(Vector3.new(0.3, radius * 2, radius * 2), flat, color, Enum.PartType.Cylinder)
	base.Transparency = 0.8
	local fill = fxPart(Vector3.new(0.4, 1, 1), flat, color, Enum.PartType.Cylinder)
	fill.Transparency = 0.35
	TweenService
		:Create(
			fill,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = Vector3.new(0.4, radius * 2, radius * 2) }
		)
		:Play()
	Debris:AddItem(fill, duration + 0.15)
	Debris:AddItem(base, duration + 0.15)
	-- A faint column so a marker far away still reads.
	local column =
		fxPart(Vector3.new(radius * 0.25, 60, radius * 0.25), CFrame.new(position + Vector3.new(0, 30, 0)), color)
	column.Transparency = 0.75
	Debris:AddItem(column, duration + 0.15)
	Effects.sound("blip", { position = position, speed = 1.4, volume = 0.5, range = 250 })
end

-- Lightning: a jagged bolt from the clouds, a flash of sky and thunder that arrives late.
function Effects.bolt(position)
	local top = position + Vector3.new(math.random(-30, 30), 320, math.random(-30, 30))
	local from = top
	for i = 1, 8 do
		local nextPoint = position:Lerp(top, 1 - i / 8)
			+ Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)) * (i < 8 and 1 or 0)
		Effects.line(from, nextPoint, Color3.fromRGB(235, 240, 255), 2.2, 0.28)
		from = nextPoint
	end
	Effects.ball(position, Color3.fromRGB(235, 240, 255), 18, 0.3)
	local distance = (camera.CFrame.Position - position).Magnitude
	local ambient = Lighting.Ambient
	Lighting.Ambient = Color3.fromRGB(230, 235, 255)
	task.delay(0.12, function()
		Lighting.Ambient = ambient
	end)
	task.delay(math.min(distance / 340, 3), function()
		Effects.sound("boom", { speed = 0.5, volume = math.clamp(1 - distance / 1500, 0.15, 0.9) })
	end)
	Effects.shakeAt(position, 0.8, 0.3, 90)
end

-- A signal flare from a carrier: a rocket, a burst, and a beam of light for a few seconds.
function Effects.flare(position, color, duration)
	local top = position + Vector3.new(0, 110, 0)
	Effects.line(position, top, color, 0.7, 0.8)
	task.delay(0.55, function()
		Effects.burst(top, color, 60, 34)
		Effects.ball(top, color, 12, 0.5)
		Effects.sound("rise", { position = top, speed = 1.7, volume = 0.6, range = 600 })
	end)
	local beam = fxPart(Vector3.new(2.6, 420, 2.6), CFrame.new(position + Vector3.new(0, 210, 0)), color)
	beam.Transparency = 0.45
	fadeOut(beam, duration or 3.5, { Size = Vector3.new(0.4, 420, 0.4) })
end

-- A Navy or Guardian shell arcing in over the marker.
function Effects.shell(from, to, duration)
	local ball = fxPart(Vector3.new(2.6, 2.6, 2.6), CFrame.new(from), Color3.fromRGB(40, 40, 46), Enum.PartType.Ball)
	ball.Material = Enum.Material.Metal
	ball.Transparency = 0
	local lift = math.max(40, (to - from).Magnitude * 0.25)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - started) / duration, 0, 1)
		ball.Position = from:Lerp(to, a) + Vector3.new(0, math.sin(math.pi * a) * lift, 0)
		if a >= 1 then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
	Effects.sound("whoosh", { position = from, speed = 0.7, volume = 0.9, range = 500 })
	Effects.burst(from, Color3.fromRGB(255, 220, 160), 18, 14)
end

-- A tentacle slamming up out of the sea at a marker.
function Effects.tentacle(position, delay)
	task.delay(delay, function()
		local color = Color3.fromRGB(110, 60, 150)
		for i = 0, 5 do
			local seg = fxPart(
				Vector3.new(7 - i * 0.8, 9, 7 - i * 0.8),
				CFrame.new(position + Vector3.new(math.sin(i) * 3, 3 + i * 8, math.cos(i) * 3)),
				color,
				Enum.PartType.Ball
			)
			seg.Material = Enum.Material.SmoothPlastic
			seg.Transparency = 0.05
			TweenService:Create(
				seg,
				TweenInfo.new(0.9, Enum.EasingStyle.Quad),
				{ Transparency = 1, Position = seg.Position - Vector3.new(0, 24, 0) }
			):Play()
			Debris:AddItem(seg, 1)
		end
		Effects.burst(position, Color3.fromRGB(190, 230, 255), 40, 30)
		Effects.sound("splash", { position = position, speed = 0.6, volume = 1, range = 500 })
	end)
end

-- Fireworks over the Hoard when someone banks.
function Effects.firework(position, color)
	local top = position + Vector3.new(math.random(-14, 14), 70 + math.random(0, 30), math.random(-14, 14))
	Effects.line(position + Vector3.new(0, 8, 0), top, color, 0.5, 0.45)
	task.delay(0.4, function()
		Effects.burst(top, color, 70, 36)
		Effects.burst(top, Color3.new(1, 1, 1), 30, 22)
		Effects.sound("boom", { position = top, speed = 1.8, volume = 0.5, range = 500 })
	end)
end

-- Spray and a thud when a boat hits something, a splash when one is wrecked.
function Effects.spray(position, power)
	Effects.burst(
		position + Vector3.new(0, 2, 0),
		Color3.fromRGB(235, 245, 255),
		math.floor(20 + power * 50),
		20 + power * 20
	)
	Effects.sound("splash", { position = position, speed = 1 - power * 0.3, volume = 0.5 + power * 0.5, range = 300 })
	Effects.shakeAt(position, power * 1.2, 0.3, 80)
end

-- A flock of gulls bursting off the island.
function Effects.gulls(position)
	for _ = 1, 14 do
		local gull = fxPart(
			Vector3.new(2.4, 0.2, 1),
			CFrame.new(position + Vector3.new(math.random(-6, 6), 2, math.random(-6, 6))),
			Color3.new(1, 1, 1)
		)
		gull.Material = Enum.Material.SmoothPlastic
		gull.Transparency = 0
		local goal = gull.Position + Vector3.new(math.random(-60, 60), math.random(50, 110), math.random(-60, 60))
		TweenService:Create(gull, TweenInfo.new(3, Enum.EasingStyle.Sine), { Position = goal, Transparency = 1 }):Play()
		Debris:AddItem(gull, 3.2)
	end
	for i = 0, 3 do
		task.delay(i * 0.25, function()
			Effects.sound("whoosh", { position = position, speed = 2.4, volume = 0.5, range = 400 })
		end)
	end
end

return Effects

-- Local-only feedback: sounds, flashes of neon, particles, camera shake and the
-- screen tint that follows Heat. Nothing here changes game state.
--
-- Sounds use files that ship inside every Roblox client (rbxasset://sounds/...),
-- so they need no uploaded assets or permissions. Pitch changes turn the same
-- few files into chimes, alarms and thuds.
--
-- There are two kinds of sound, and the difference matters:
--   INTERFACE  a chime when you bank, the alarm when Heat rises. Played in your ears.
--   WORLD      thunder, a keg, a cannon. It happened at a place: it is played there, it fades
--              with distance, and past its range it is not played at all.
-- From V2 to V5 thunder was played as an interface sound with a floor on its volume, so every
-- bolt of every storm on the map boomed in every goblin's ears: about one a second with three
-- storms out. That was the "explosions in the distance". World sounds also used Roblox's
-- default rolloff, which never reaches silence: it cuts off dead at the maximum distance.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local Effects = {}

local AUDIO = Config.AUDIO

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

-- Where this player hears from (Roblox's default listener is the camera).
local function listener()
	return camera.CFrame.Position
end

-- How far this player is from a point in the world.
function Effects.distanceTo(position)
	return (listener() - position).Magnitude
end

-- Sound groups: one for the world, one for the interface. The world's has a compressor, so a
-- pile of blasts at once (a barrage, a chain of powder barrels) is held down instead of adding up.
local function soundGroup(name)
	local old = SoundService:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local worldGroup = soundGroup("LootGoblinsWorld")
local interfaceGroup = soundGroup("LootGoblinsInterface")
do
	local squash = Instance.new("CompressorSoundEffect")
	squash.Threshold = AUDIO.COMPRESS_THRESHOLD
	squash.Ratio = AUDIO.COMPRESS_RATIO
	squash.Attack = 0.005
	squash.Release = 0.2
	squash.Parent = worldGroup
end

-- How loud a world sound is at a distance, from 1 (inside `near`) to 0 (at `range` and beyond).
-- It is the shape Roblox's InverseTapered rolloff has: an inverse falloff that is pulled down to
-- nothing as the range runs out. Used to decide what is worth playing; Roblox does the mixing.
local function heardAt(distance, near, range)
	if distance <= near then
		return 1
	elseif distance >= range then
		return 0
	end
	local taper = (range - distance) / (range - near)
	return near / distance * taper * taper
end
Effects.heardAt = heardAt

-- At most VOICE_LIMIT world sounds of one kind may start within VOICE_WINDOW seconds. One more
-- only gets in if it would be louder here than all of those (the keg at your feet still sounds
-- in the middle of a distant barrage).
local voices = {} -- sound name -> { { at, loudness }, ... }

local function admit(name, loudness)
	local now = os.clock()
	local list = voices[name]
	if not list then
		list = {}
		voices[name] = list
	end
	local loudest = 0
	for i = #list, 1, -1 do
		if now - list[i].at > AUDIO.VOICE_WINDOW then
			table.remove(list, i)
		else
			loudest = math.max(loudest, list[i].loudness)
		end
	end
	if #list >= AUDIO.VOICE_LIMIT and loudness <= loudest then
		return false
	end
	table.insert(list, { at = now, loudness = loudness })
	return true
end

-- name: key of SOUNDS. options:
--   volume, speed
--   position   makes it a WORLD sound, played at that point
--   range      silent from this distance on (default AUDIO.RANGE): beyond it nothing is played
--   near       full volume inside this distance (default AUDIO.NEAR)
--   muffle     true: the far half of the range loses its treble, like distant thunder
-- Without a position it is an INTERFACE sound.
function Effects.sound(name, options)
	options = options or {}
	local volume = options.volume or 0.6
	if not options.position then
		local sound = Instance.new("Sound")
		sound.SoundId = SOUNDS[name]
		sound.Volume = volume
		sound.PlaybackSpeed = options.speed or 1
		sound.SoundGroup = interfaceGroup
		sound.Parent = SoundService
		Debris:AddItem(sound, 5)
		sound:Play()
		return
	end
	local near, range = options.near or AUDIO.NEAR, options.range or AUDIO.RANGE
	local distance = (listener() - options.position).Magnitude
	local loudness = volume * heardAt(distance, near, range)
	if loudness < AUDIO.FLOOR or not admit(name, loudness) then
		return -- Too far to hear, or one too many at once: not played at all.
	end
	local holder = Instance.new("Attachment")
	holder.Name = "SoundAt"
	holder.Position = options.position
	holder.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = SOUNDS[name]
	sound.Volume = volume
	sound.PlaybackSpeed = options.speed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = near
	sound.RollOffMaxDistance = range
	sound.SoundGroup = worldGroup
	if options.muffle then
		local far = math.clamp((distance - near) / (range - near) * 2, 0, 1)
		if far > 0.05 then
			local muffle = Instance.new("EqualizerSoundEffect")
			muffle.LowGain = 0
			muffle.MidGain = -10 * far
			muffle.HighGain = -30 * far
			muffle.Parent = sound
		end
	end
	sound.Parent = holder
	Debris:AddItem(holder, 5)
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

-- Visual-only explosion (no push, nothing breaks). silent: something else is its sound (a bolt
-- of lightning has its thunder).
function Effects.explosion(position, radius, silent)
	if Effects.distanceTo(position) > AUDIO.DRAW_BLAST then
		return -- Across the sea: nothing to see or hear from here.
	end
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = radius or 6
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	if not silent then
		Effects.sound("boom", { position = position, volume = 0.8, near = AUDIO.BLAST_NEAR, range = AUDIO.BLAST_RANGE })
	end
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

-- Speed widens the field of view (running, sprinting, a boat at full tilt); punches (a dash, a
-- launch) kick it wider for a moment and settle back. One writer, every frame, so the two
-- never fight.
local BASE_FOV = 70
local speedFov, shownFov, punch = BASE_FOV, BASE_FOV, 0

-- speed: how fast the local character is travelling, in studs/s.
function Effects.setSpeed(speed)
	speedFov = BASE_FOV + 24 * (1 - math.exp(-math.max(0, speed - 22) / 70))
end

function Effects.punchFov(fov)
	punch = math.max(punch, fov - shownFov)
end

RunService.RenderStepped:Connect(function(dt)
	shownFov += (speedFov - shownFov) * (1 - math.exp(-dt * 5))
	punch *= math.exp(-dt * 4.5)
	camera.FieldOfView = shownFov + punch
end)

-- A grapple rope from a moving part to a point, for a few seconds. The point can ride another
-- part (a boat): pass that part and the hook's position in its space. Returns the holder so
-- the caller can cut it early.
function Effects.rope(part, to, color, duration, hookPart, hookOffset)
	local holder = Instance.new("Attachment")
	holder.Name = "GrappleRope"
	holder.Parent = part
	local anchor = Instance.new("Attachment")
	anchor.Name = "GrappleHook"
	if hookPart and hookPart.Parent then
		anchor.Parent = hookPart
		anchor.Position = hookOffset or Vector3.zero
	else
		anchor.Parent = workspace.Terrain
		anchor.WorldPosition = to
	end
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

-- A dash: streaks trailing back from where it started. direction is nil for another player's
-- dash (we only know where it began), which draws a puff instead.
function Effects.dash(position, direction)
	local color = Color3.fromRGB(190, 235, 255)
	if direction then
		local side = Vector3.new(-direction.Z, 0, direction.X)
		for _, offset in ipairs({ -1.4, 0, 1.4 }) do
			local from = position + side * offset + Vector3.new(0, offset == 0 and 1 or -0.5, 0)
			Effects.line(from - direction * 7, from + direction * 5, color, 0.35, 0.22)
		end
	else
		Effects.ring(position - Vector3.new(0, 2.5, 0), color, 7, 0.3)
	end
	Effects.sound("whoosh", { position = position, speed = 1.9, volume = 0.55, range = 120 })
end

-- An air jump: a ring kicked off under the feet.
function Effects.airJump(position)
	Effects.ring(position - Vector3.new(0, 2.8, 0), Color3.fromRGB(190, 235, 255), 6, 0.3)
	Effects.sound("whoosh", { position = position, speed = 1.3, volume = 0.45, range = 100 })
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
	if Effects.distanceTo(position) > AUDIO.DRAW_MARKER then
		return -- Too far to matter to this player, or to be seen.
	end
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

-- The Guardian's stomp. While its fists are up the whole reach of the ring shows faintly; then
-- the ring itself races out along the ground. Its leading edge is what you jump.
function Effects.shockwave(position, radius, windup, speed)
	local color = Color3.fromRGB(255, 150, 60)
	local flat = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local travel = radius / speed
	local reach = fxPart(Vector3.new(0.3, radius * 2, radius * 2), flat, color, Enum.PartType.Cylinder)
	reach.Transparency = 0.9
	Debris:AddItem(reach, windup + travel)
	Effects.sound("blip", { position = position, speed = 0.5, volume = 1, range = 300 })
	task.delay(windup, function()
		local ring = fxPart(Vector3.new(1.4, 2, 2), flat, color, Enum.PartType.Cylinder)
		ring.Transparency = 0.4
		TweenService:Create(
			ring,
			TweenInfo.new(travel, Enum.EasingStyle.Linear),
			{ Size = Vector3.new(1.4, radius * 2, radius * 2), Transparency = 0.82 }
		):Play()
		Debris:AddItem(ring, travel + 0.1)
		Effects.sound("boom", { position = position, speed = 0.5, volume = 1, range = 400 })
		Effects.shakeAt(position, 1.6, 0.5, 150)
	end)
end

-- The sky lighting up for a moment. strength 0 to 1. (The resting colour is remembered once per
-- flash and restored by the last one to end: V5 let each bolt restore whatever it had found, so
-- two bolts close together could leave the world lit.)
local flashing, flashToken, restAmbient = false, 0, nil

local function skyFlash(strength)
	if strength < 0.03 then
		return
	end
	if not flashing then
		restAmbient = Lighting.Ambient
		flashing = true
	end
	flashToken += 1
	local token = flashToken
	Lighting.Ambient = restAmbient:Lerp(Color3.fromRGB(230, 235, 255), strength)
	task.delay(0.12, function()
		if token == flashToken then
			Lighting.Ambient = restAmbient
			flashing = false
		end
	end)
end

-- Thunder: a WORLD sound at the strike, late by the time sound takes to arrive. Loud inside the
-- storm, a muffled rumble as one comes near, and nothing at all from a storm across the sea.
function Effects.thunder(position)
	local distance = Effects.distanceTo(position)
	if distance >= AUDIO.THUNDER_RANGE then
		return
	end
	task.delay(math.min(distance / 340, 3), function()
		Effects.sound("boom", {
			position = position,
			speed = 0.5,
			volume = 1,
			near = AUDIO.THUNDER_NEAR,
			range = AUDIO.THUNDER_RANGE,
			muffle = true,
		})
	end)
end

-- Lightning: a jagged bolt from the clouds, a flash of sky and thunder that arrives late.
function Effects.bolt(position)
	local distance = Effects.distanceTo(position)
	if distance <= AUDIO.DRAW_BOLT then
		local top = position + Vector3.new(math.random(-30, 30), 320, math.random(-30, 30))
		local from = top
		for i = 1, 8 do
			local nextPoint = position:Lerp(top, 1 - i / 8)
				+ Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)) * (i < 8 and 1 or 0)
			Effects.line(from, nextPoint, Color3.fromRGB(235, 240, 255), 2.2, 0.28)
			from = nextPoint
		end
		Effects.ball(position, Color3.fromRGB(235, 240, 255), 18, 0.3)
	end
	-- The sky flickers for a storm in the distance and goes white for one overhead.
	skyFlash(math.clamp(1 - (distance - AUDIO.FLASH_FULL) / (AUDIO.FLASH_NONE - AUDIO.FLASH_FULL), 0, 1))
	Effects.thunder(position)
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

-- V13.5: words that pop out of the world where something happened ("SKIP x2!", "BIG AIR!") and float away. Far ones
-- are not drawn.
function Effects.popText(position, text, color, seconds)
	if Effects.distanceTo(position) > 500 then
		return
	end
	seconds = seconds or 1.2
	local anchor = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(240, 54)
	bill.AlwaysOnTop = true
	bill.LightInfluence = 0
	bill.MaxDistance = 500
	bill.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(20, 16, 24)
	label.TextStrokeTransparency = 0
	label.Parent = bill
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService
		:Create(anchor, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Position = position + Vector3.new(0, 9, 0) })
		:Play()
	task.delay(seconds * 0.6, function()
		TweenService:Create(label, TweenInfo.new(seconds * 0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end)
	Debris:AddItem(anchor, seconds + 0.1)
end

-- V13.5: a column of white water thrown up where something heavy hit the sea (a meteor, a goblin's first skip, a
-- breaking wave). height and radius in studs.
function Effects.splashColumn(position, height, radius)
	if Effects.distanceTo(position) > AUDIO.DRAW_BLAST then
		return
	end
	local white = Color3.fromRGB(235, 248, 255)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is its X: stood on end
	local column = fxPart(
		Vector3.new(1, radius * 0.8, radius * 0.8),
		CFrame.new(position + Vector3.new(0, 0.5, 0)) * upright,
		white,
		Enum.PartType.Cylinder
	)
	column.Material = Enum.Material.SmoothPlastic
	column.Transparency = 0.25
	local rise = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(column, rise, {
		Size = Vector3.new(height, radius * 1.4, radius * 1.4),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * upright,
	}):Play()
	task.delay(0.35, function()
		fadeOut(column, 0.6, {
			Size = Vector3.new(height * 0.3, radius * 2.2, radius * 2.2),
			CFrame = CFrame.new(position + Vector3.new(0, height * 0.15, 0)) * upright,
		})
	end)
	Effects.burst(position + Vector3.new(0, height * 0.7, 0), white, math.floor(20 + radius * 2), 12 + height * 0.3)
	Effects.ring(position + Vector3.new(0, 0.8, 0), Color3.fromRGB(200, 240, 255), radius * 3, 0.9)
end

-- V13.5: solid bits flying off an impact (wood off a hull, rock off a meteor): a few real, falling, local pieces.
function Effects.debris(position, color, count, speed, material)
	if Effects.distanceTo(position) > 400 then
		return
	end
	for _ = 1, count or 6 do
		local size = 0.6 + math.random() * 1.2
		local piece = Instance.new("Part")
		piece.Name = "Debris"
		piece.Size = Vector3.new(size, size * 0.5, size * 1.4)
		piece.CFrame = CFrame.new(position)
			* CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
		piece.Color = color
		piece.Material = material or Enum.Material.WoodPlanks
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		local a = math.random() * math.pi * 2
		local out = (speed or 30) * (0.5 + math.random() * 0.6)
		piece.AssemblyLinearVelocity =
			Vector3.new(math.cos(a) * out, out * (0.6 + math.random() * 0.6), math.sin(a) * out)
		piece.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
		piece.Parent = workspace
		Debris:AddItem(piece, 1.6)
	end
end

-- V13.5: a ring of dust or spray hugging the ground, rolling outward from a landing or a blast.
function Effects.dustRing(position, radius, color)
	if Effects.distanceTo(position) > AUDIO.DRAW_BLAST then
		return
	end
	local holder = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1))
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(210, 190, 160))
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, radius * 0.35) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.7, 1.1)
	emitter.Speed = NumberRange.new(radius * 0.9, radius * 1.2)
	emitter.SpreadAngle = Vector2.new(12, 3)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	-- A flat spray: emitted round the circle by turning the holder.
	for i = 0, 11 do
		holder.CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, i / 12 * math.pi * 2, 0)
		emitter:Emit(3)
	end
	Debris:AddItem(holder, 1.4)
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

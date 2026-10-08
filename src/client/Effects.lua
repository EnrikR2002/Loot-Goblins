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

return Effects

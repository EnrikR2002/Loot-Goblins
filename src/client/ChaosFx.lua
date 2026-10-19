-- V13.2: WORLD CHAOS, drawn (server/WorldChaos.lua decides everything; this only shows it). Every piece is a local,
-- non-colliding part in one folder, cleared when the raid resets.
--
--   meteors    a burning ring on the ground, a fireball streaking down onto it, a blast and a column of spray
--   kraken     bubbles, then a giant tentacle that rises and sweeps, slams or tosses, then sinks
--   waves      the rogue waves themselves (read from the sea: Sea.chaos), a wall of blue with a foam crest
--   crossfire  the rogue armada (three black galleons), its muzzle flashes and shells, the shelled zone
--   barrels    the drifting barrels (red ones are powder), bobbing on the swell between the server's snapshots
--   whirls     the wandering whirlpools (also read from the sea): spinning foam arms round a dark eye
--   haunted    two green portal rings and the phantom ships they spit out
--   thunder    the sky darkens, a crackling ring, the bolt, the shockwave racing out, chains between boats
-- And for each episode a banner for goblins close enough to care.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Sea = require(Shared:WaitForChild("Sea"))
local Effects = require(script.Parent.Effects)

local ChaosFx = {}

local X = Config.CHAOS
local player = Players.LocalPlayer
local hud -- client/Hud.lua (Main hands it over)

local folder = Instance.new("Folder")
folder.Name = "LootGoblinsChaosFx"
folder.Parent = workspace

local function now()
	return workspace:GetServerTimeNow()
end

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

local function myPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	return workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero
end

local function near(position, range)
	local p = myPosition()
	return Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude <= range
end

local function compass(from, to)
	local d = to - from
	local degrees = math.deg(math.atan2(d.X, -d.Z)) % 360
	local names = { "NORTH", "NORTH-EAST", "EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST" }
	return names[math.floor((degrees + 22.5) / 45) % 8 + 1]
end

local ORANGE = Color3.fromRGB(255, 140, 50)
local PURPLE = Color3.fromRGB(150, 70, 190)
local FOAM = Color3.fromRGB(236, 248, 255)
local WAVE = Color3.fromRGB(46, 140, 196)
local GHOST = Color3.fromRGB(120, 255, 190)
local SPARK = Color3.fromRGB(200, 225, 255)

-- A warning on the water: a faint disc of the whole reach and a bright ring closing in on it over `duration` (the
-- one visual language for "this lands here", without the tall column of the shared marker: chaos warnings come in
-- crowds, and a column right beside the camera tinted the whole screen).
local function warnRing(position, radius, duration, color)
	local at = CFrame.new(position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local reach = part({
		Name = "ChaosWarn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = at,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.82,
	})
	local closing = part({
		Name = "ChaosWarnRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2 + 30, radius * 2 + 30),
		CFrame = at,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	TweenService:Create(closing, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 0.15,
	}):Play()
	Debris:AddItem(reach, duration + 0.1)
	Debris:AddItem(closing, duration + 0.1)
end

-- Meteors ---------------------------------------------------------------------------------------------------------------
local function meteorWarn(p)
	local at, warn = p.position, p.warn or 2.4
	warnRing(at, p.radius or 40, warn, ORANGE)
	local dir = typeof(p.from) == "Vector3" and p.from or Vector3.new(1, 0, 0)
	local start = at - dir * 420 + Vector3.new(0, 700, 0)
	local size = p.big and 22 or 11
	local rock = part({
		Name = "Meteor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Color = Color3.fromRGB(90, 50, 30),
		Material = Enum.Material.Basalt,
		CFrame = CFrame.new(start),
	})
	local glow = part({
		Name = "MeteorGlow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size) * 1.6,
		Color = ORANGE,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CFrame = CFrame.new(start),
	})
	local fire = Instance.new("Fire")
	fire.Size = size * 1.4
	fire.Heat = 25
	fire.Color = ORANGE
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = rock
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 60
	light.Brightness = 3
	light.Parent = glow
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, size / 2, 0), Vector3.new(0, -size / 2, 0)
	a0.Parent, a1.Parent = rock, rock
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.6
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), ORANGE)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = rock
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / warn, 0, 1)
		local e = k * k -- it speeds up as it falls
		local at2 = start:Lerp(at, e)
		rock.CFrame = CFrame.new(at2) * CFrame.Angles(k * 9, k * 7, 0)
		glow.CFrame = CFrame.new(at2)
		if k >= 1 then
			connection:Disconnect()
			rock:Destroy()
			glow:Destroy()
		end
	end)
	Effects.sound("whoosh", { position = at, speed = 0.35, volume = 1, range = 900 })
	if near(at, X.ALERT_RANGE * 0.5) and hud then
		hud.banner(p.big and "☄ THE BIG ONE! GET CLEAR!" or "☄ METEOR! Out of the burning ring!", ORANGE, 1.6, 2)
	end
end

local function meteorHit(p)
	local at, radius = p.position, p.radius or 40
	Effects.explosion(at, radius * 0.7, false)
	Effects.ring(at + Vector3.new(0, 1, 0), ORANGE, radius * 2.2, 0.8)
	Effects.ring(at + Vector3.new(0, 1, 0), FOAM, radius * 1.4, 0.6)
	Effects.spray(at, p.big and 3 or 2)
	Effects.burst(at + Vector3.new(0, 4, 0), Color3.fromRGB(255, 200, 90), p.big and 140 or 80, p.big and 90 or 60)
	-- A column of spray (or dust) thrown up where it hit.
	local column = part({
		Name = "MeteorColumn",
		Size = Vector3.new(radius * 0.7, 6, radius * 0.7),
		CFrame = CFrame.new(at + Vector3.new(0, 3, 0)),
		Color = at.Y < 3 and FOAM or Color3.fromRGB(150, 120, 90),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.25,
		Shape = Enum.PartType.Cylinder,
	})
	column.CFrame = CFrame.new(at + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(column, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * (p.big and 3.2 or 1.8), radius * 0.2, radius * 0.2),
		CFrame = CFrame.new(at + Vector3.new(0, radius * (p.big and 1.6 or 0.9), 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(column, 1)
	Effects.sound("boom", { position = at, speed = p.big and 0.35 or 0.55, volume = 1, range = 1200 })
	Effects.shakeAt(at, p.big and 3 or 1.8, p.big and 1 or 0.6, p.big and 500 or 260)
end

-- Kraken ----------------------------------------------------------------------------------------------------------------
local function krakenWarn(p)
	local at, warn = p.position, p.warn or 1.5
	warnRing(
		at,
		p.strike == "sweep" and X.kraken.sweepLength or (p.strike == "slam" and X.kraken.slamRadius or 26),
		warn,
		PURPLE
	)
	-- Bubbles boiling up.
	local holder = part({
		Name = "Bubbles",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)),
	})
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(FOAM)
	bubbles.Size = NumberSequence.new(2.2, 0.4)
	bubbles.Lifetime = NumberRange.new(0.6, 1.1)
	bubbles.Speed = NumberRange.new(8, 22)
	bubbles.SpreadAngle = Vector2.new(60, 60)
	bubbles.Rate = 90
	bubbles.Shape = Enum.ParticleEmitterShape.Cylinder
	bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = holder
	holder.Size = Vector3.new(18, 1, 18)
	Debris:AddItem(holder, warn + 0.3)
	Effects.sound("rise", { position = at, speed = 0.3, volume = 0.9, range = 500 })
	if near(at, 300) and hud then
		hud.banner("🐙 BUBBLES! THE KRAKEN!", PURPLE, 1.3, 2)
	end
end

-- A tentacle: a chain of tapering balls along a curve from its base, posed every frame by `pose(t) -> {root, dir,
-- height, bend}`. Lives for `life` seconds.
local function tentacle(base, life, pose)
	local segments = {}
	local count = 14
	for i = 1, count do
		local size = 13 - i * 0.7
		table.insert(
			segments,
			part({
				Name = "Tentacle",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				Color = PURPLE:Lerp(Color3.fromRGB(230, 120, 160), i / count),
				Material = Enum.Material.SmoothPlastic,
				CFrame = CFrame.new(base),
			})
		)
		if i % 3 == 0 then
			-- suckers
			local sucker = part({
				Name = "Sucker",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size * 0.4, size * 0.4, size * 0.4),
				Color = Color3.fromRGB(255, 200, 220),
				Material = Enum.Material.SmoothPlastic,
				CFrame = CFrame.new(base),
			})
			segments[#segments].sucker = sucker
		end
	end
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		if age > life then
			connection:Disconnect()
			for _, s in ipairs(segments) do
				if s.sucker then
					s.sucker:Destroy()
				end
				s:Destroy()
			end
			return
		end
		local dir, height, bend = pose(age)
		for i, s in ipairs(segments) do
			local k = (i - 1) / (count - 1)
			local along = dir * (k * height * bend)
			local up = Vector3.new(0, math.sin(k * math.pi * 0.5) * height * (1 - bend * 0.5) + k * height * 0.2, 0)
			local wobble = Vector3.new(math.sin(age * 6 + i) * 1.2, 0, math.cos(age * 5 + i) * 1.2)
			local at = base + along + up + wobble
			s.CFrame = CFrame.new(at)
			if s.sucker then
				s.sucker.CFrame = CFrame.new(at + Vector3.new(0, s.Size.Y * 0.35, 0))
			end
		end
	end)
	Effects.spray(base, 1.8)
	Effects.sound("splash", { position = base, speed = 0.4, volume = 1, range = 700 })
end

local function krakenStrike(p)
	local base = p.position
	local K = X.kraken
	if p.strike == "sweep" then
		local angle, direction = p.angle or 0, p.direction or 1
		tentacle(base, 0.35 + K.sweepTime + 0.8, function(age)
			local rise = math.clamp(age / 0.35, 0, 1)
			local k = math.clamp((age - 0.35) / K.sweepTime, 0, 1)
			local sink = math.clamp((age - 0.35 - K.sweepTime) / 0.8, 0, 1)
			local a = angle + K.sweepArc * k * direction
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			-- Up, then lying along the water as it sweeps, then down.
			return dir, K.sweepLength * rise * (1 - sink), 0.9
		end)
	elseif p.strike == "slam" then
		tentacle(base + Vector3.new(0, 0, 0), 1.6, function(age)
			local up = math.clamp(age / 0.5, 0, 1)
			local down = math.clamp((age - 0.5) / 0.15, 0, 1)
			local sink = math.clamp((age - 0.9) / 0.7, 0, 1)
			return Vector3.new(1, 0, 0), 70 * up * (1 - down * 0.85) * (1 - sink), 0.15 + down * 0.3
		end)
	else -- toss
		tentacle(base, 1.4, function(age)
			local up = math.clamp(age / 0.25, 0, 1)
			local sink = math.clamp((age - 0.6) / 0.8, 0, 1)
			return Vector3.new(0, 0, 1), 85 * up * (1 - sink), 0.05
		end)
	end
	Effects.shakeAt(base, 1.2, 0.5, 260)
end

local function krakenSlam(p)
	Effects.ring(p.position + Vector3.new(0, 1, 0), FOAM, (p.radius or 42) * 1.6, 0.7)
	Effects.spray(p.position, 2.4)
	Effects.sound("boom", { position = p.position, speed = 0.5, volume = 1, range = 700 })
	Effects.shakeAt(p.position, 2, 0.6, 260)
end

-- Rogue waves (drawn from the sea itself) ---------------------------------------------------------------------------------
local waveViews = {} -- wave table -> { segments }
local SEGMENTS = 22
local function waveView(w)
	local view = waveViews[w]
	if view then
		return view
	end
	view = { segments = {} }
	local segLength = (w.half * 2) / SEGMENTS
	for i = 1, SEGMENTS do
		local front = part({
			ClassName = "WedgePart",
			Name = "WaveFace",
			Size = Vector3.new(segLength + 1, 1, w.width),
			Color = WAVE,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
		})
		local back = part({
			ClassName = "WedgePart",
			Name = "WaveBack",
			Size = Vector3.new(segLength + 1, 1, w.width * 1.4),
			Color = WAVE:Lerp(Color3.new(0, 0, 0), 0.15),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
		local crest = part({
			Name = "WaveCrest",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segLength + 1.5, 4, 4),
			Color = FOAM,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.1,
		})
		table.insert(
			view.segments,
			{ front = front, back = back, crest = crest, along = -w.half + segLength * (i - 0.5) }
		)
	end
	local holder = part({ Name = "WaveSpray", Size = Vector3.new(w.half * 2, 1, 4), Transparency = 1 })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(FOAM)
	spray.Size = NumberSequence.new(4, 12)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Lifetime = NumberRange.new(0.8, 1.4)
	spray.Speed = NumberRange.new(10, 26)
	spray.Rate = 60
	spray.Shape = Enum.ParticleEmitterShape.Box
	spray.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = holder
	view.holder = holder
	waveViews[w] = view
	return view
end

local function drawWaves(t)
	local alive = {}
	for _, w in ipairs(Sea.chaos.waves) do
		alive[w] = true
		local age = t - w.born
		local view = waveView(w)
		local dir = Vector3.new(w.dx, 0, w.dz)
		local across = Vector3.new(-dir.Z, 0, dir.X)
		local crest = Vector3.new(w.x, 0, w.z) + dir * w.speed * math.max(age, 0)
		local yaw = CFrame.lookAt(Vector3.zero, dir)
		for _, s in ipairs(view.segments) do
			local at = crest + across * s.along
			-- The real height of the sea there (shelter breaks it; it swells in and dies away).
			local h = Sea.chaosAt(at.X, at.Z, t)
			h = math.max(h, 0)
			if h < 0.6 or age < 0 then
				s.front.Transparency, s.back.Transparency, s.crest.Transparency = 1, 1, 1
			else
				s.front.Transparency, s.back.Transparency, s.crest.Transparency = 0.25, 0.3, 0.1
				-- The face rises ahead of the crest; the back slopes away behind it. (A wedge's slope faces its -Z.)
				s.front.Size = Vector3.new(s.front.Size.X, h, w.width)
				s.front.CFrame = CFrame.new(at + dir * (w.width * 0.5) + Vector3.new(0, h / 2 - 0.5, 0)) * yaw
				s.back.Size = Vector3.new(s.back.Size.X, h, w.width * 1.4)
				s.back.CFrame = CFrame.new(at - dir * (w.width * 0.7) + Vector3.new(0, h / 2 - 0.5, 0))
					* yaw
					* CFrame.Angles(0, math.pi, 0)
				s.crest.CFrame = CFrame.new(at + Vector3.new(0, h, 0)) * yaw -- (a cylinder's axis is its X: along the front)
			end
		end
		view.holder.CFrame = CFrame.new(crest + Vector3.new(0, math.max(2, w.height * 0.7), 0))
			* yaw
			* CFrame.Angles(0, math.rad(90), 0)
		view.holder.Size = Vector3.new(4, 1, w.half * 1.8)
	end
	for w, view in pairs(waveViews) do
		if not alive[w] then
			for _, s in ipairs(view.segments) do
				s.front:Destroy()
				s.back:Destroy()
				s.crest:Destroy()
			end
			view.holder:Destroy()
			waveViews[w] = nil
		end
	end
end

-- Whirlpools (drawn from the sea) ----------------------------------------------------------------------------------------
local whirlViews = {}
local function whirlView(wh)
	local view = whirlViews[wh]
	if view then
		return view
	end
	view = { arms = {} }
	view.eye = part({
		Name = "WhirlEye",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, wh.r * 0.5, wh.r * 0.5),
		Color = Color3.fromRGB(14, 40, 62),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
	})
	for arm = 1, 5 do
		for k = 1, 9 do
			table.insert(view.arms, {
				arm = arm,
				k = k,
				part = part({
					Name = "WhirlFoam",
					Size = Vector3.new(2.4, 0.8, 9),
					Color = FOAM,
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.2,
				}),
			})
		end
	end
	whirlViews[wh] = view
	return view
end

local function drawWhirls(t)
	local alive = {}
	for _, wh in ipairs(Sea.chaos.whirls) do
		alive[wh] = true
		local age = t - wh.born
		local view = whirlView(wh)
		local show = age >= 0 and age <= wh.life
		local k = show and math.min(1, age / 1.5, (wh.life - age) / 2) or 0
		local center = Vector3.new(wh.x + wh.vx * age, 0, wh.z + wh.vz * age)
		view.eye.Transparency = show and 0.15 + (1 - k) * 0.85 or 1
		view.eye.CFrame = CFrame.new(center + Vector3.new(0, 0.8 - wh.dip * k * 0.3, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		for _, a in ipairs(view.arms) do
			local f = a.k / 9
			local radius = wh.r * (0.15 + f * 0.85)
			-- Inner foam goes round faster (a vortex).
			local angle = a.arm * (math.pi * 2 / 5) + f * 2.4 - t * (wh.spin / math.max(radius, 10)) * 1.2
			local at = center
				+ Vector3.new(math.cos(angle) * radius, 0.9 - (1 - f) * wh.dip * 0.35 * k, math.sin(angle) * radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			a.part.CFrame = CFrame.lookAt(at, at + tangent)
			a.part.Transparency = show and 0.15 + (1 - k) * 0.85 + f * 0.25 or 1
		end
	end
	for wh, view in pairs(whirlViews) do
		if not alive[wh] then
			view.eye:Destroy()
			for _, a in ipairs(view.arms) do
				a.part:Destroy()
			end
			whirlViews[wh] = nil
		end
	end
end

-- Crossfire: the armada ---------------------------------------------------------------------------------------------------
local armadaParts = {}
local function galleon(at, facing, color, transparency, parent)
	local model = Instance.new("Model")
	model.Name = "Galleon"
	local look = CFrame.lookAt(at, at + facing)
	local function add(size, offset, c, material, shape)
		return part({
			Size = size,
			CFrame = look * offset,
			Color = c,
			Material = material or Enum.Material.WoodPlanks,
			Transparency = transparency,
			Shape = shape or Enum.PartType.Block,
			Parent = model,
		})
	end
	add(Vector3.new(16, 7, 44), CFrame.new(0, 2, 0), color)
	add(Vector3.new(14, 5, 10), CFrame.new(0, 7, 17), color)
	for _, z in ipairs({ -10, 6 }) do
		add(Vector3.new(1.2, 30, 1.2), CFrame.new(0, 19, z), Color3.fromRGB(40, 30, 26))
		add(Vector3.new(0.4, 18, 16), CFrame.new(0, 21, z + 0.8), Color3.fromRGB(28, 26, 30), Enum.Material.Fabric)
	end
	for i = -2, 2 do
		for _, side in ipairs({ -1, 1 }) do
			add(
				Vector3.new(0.4, 1.4, 2),
				CFrame.new(side * 8.1, 3, i * 7),
				Color3.fromRGB(255, 120, 60),
				Enum.Material.Neon
			)
		end
	end
	model.Parent = parent or folder
	return model
end

local function armada(p)
	for _, m in ipairs(armadaParts) do
		m:Destroy()
	end
	table.clear(armadaParts)
	local facing = typeof(p.facing) == "Vector3" and p.facing or Vector3.new(0, 0, 1)
	for _, at in ipairs(p.ships or {}) do
		local model = galleon(at + Vector3.new(0, 1, 0), facing, Color3.fromRGB(36, 30, 34), 0)
		table.insert(armadaParts, model)
		Debris:AddItem(model, math.max(1, (p.untilAt or now()) - now() + 3))
	end
	-- The shelled zone: a faint red ring on the water for as long as it lasts (it rolls with a rolling barrage).
	local zoneRing = part({
		Name = "CrossfireZone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, (p.zone or 200) * 2, (p.zone or 200) * 2),
		Color = Color3.fromRGB(255, 60, 50),
		Material = Enum.Material.Neon,
		Transparency = 0.88,
	})
	table.insert(armadaParts, zoneRing)
	local started, untilAt = p.start or now(), p.untilAt or now()
	local roll = typeof(p.roll) == "Vector3" and p.roll or Vector3.zero
	local center = p.center
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = now()
		if t > untilAt or not zoneRing.Parent then
			connection:Disconnect()
			zoneRing:Destroy()
			return
		end
		local c = center + roll * (t - started)
		zoneRing.CFrame = CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end)
	if near(center, X.ALERT_RANGE) and hud then
		hud.banner("💣 A ROGUE ARMADA OPENS FIRE TO THE " .. compass(myPosition(), center) .. "!", ORANGE, 2.2, 2)
	end
end

local function shell(p)
	if typeof(p.from) ~= "Vector3" or typeof(p.to) ~= "Vector3" then
		return
	end
	warnRing(p.to, p.radius or 24, p.time or 1.4, Color3.fromRGB(255, 70, 50))
	Effects.shell(p.from, p.to, p.time or 1.4)
	Effects.burst(p.from, Color3.fromRGB(255, 200, 120), 26, 26)
	Effects.sound("boom", { position = p.from, speed = 0.9, volume = 0.8, range = 900 })
end

-- Barrels -----------------------------------------------------------------------------------------------------------------
local barrels = {} -- id -> { part, x, z, tx, tz, powder }
local function makeBarrel(id, x, z, powder)
	local body = part({
		Name = powder and "PowderBarrel" or "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.6, 3.6, 3.6),
		Color = powder and Color3.fromRGB(190, 50, 40) or Color3.fromRGB(140, 96, 56),
		Material = Enum.Material.WoodPlanks,
	})
	for _, offset in ipairs({ -1.5, 1.5 }) do
		local band = part({
			Name = "Hoop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 3.75, 3.75),
			Color = Color3.fromRGB(60, 60, 66),
			Material = Enum.Material.Metal,
			Parent = body,
		})
		band:SetAttribute("Offset", offset)
	end
	if powder then
		local fuse = part({
			Name = "Fuse",
			Size = Vector3.new(0.4, 1.2, 0.4),
			Color = Color3.fromRGB(255, 220, 120),
			Material = Enum.Material.Neon,
			Parent = body,
		})
		fuse:SetAttribute("Offset", 0)
	end
	barrels[id] = { part = body, x = x, z = z, tx = x, tz = z, powder = powder, phase = math.random() * 6 }
end

local function drawBarrels(dt, t)
	for _, b in pairs(barrels) do
		b.x += (b.tx - b.x) * math.min(1, dt * 6)
		b.z += (b.tz - b.z) * math.min(1, dt * 6)
		local y = Sea.waveAt(b.x, b.z, t) + 0.6
		local cf = CFrame.new(b.x, y, b.z)
			* CFrame.Angles(math.sin(t + b.phase) * 0.2, b.phase, math.cos(t * 0.8 + b.phase) * 0.15)
		b.part.CFrame = cf
		for _, child in ipairs(b.part:GetChildren()) do
			if child:IsA("BasePart") then
				local offset = child:GetAttribute("Offset") or 0
				if child.Name == "Fuse" then
					child.CFrame = cf * CFrame.new(0, 2.4, 0)
				else
					child.CFrame = cf * CFrame.new(offset, 0, 0)
				end
			end
		end
	end
end

-- Haunted seas -------------------------------------------------------------------------------------------------------------
local portalParts = {}
local function portalRing(at, facing, radius, untilAt)
	local model = Instance.new("Model")
	model.Name = "GhostPortal"
	local look = CFrame.lookAt(at, at + facing)
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		part({
			Name = "PortalRim",
			Size = Vector3.new(3, 3, 5),
			Color = GHOST,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			CFrame = look
				* CFrame.new(math.cos(a) * radius, radius * 0.9 + math.sin(a) * radius, 0)
				* CFrame.Angles(0, 0, a),
			Parent = model,
		})
	end
	local veil = part({
		Name = "PortalVeil",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, radius * 1.9, radius * 1.9),
		Color = Color3.fromRGB(40, 255, 160),
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CFrame = look * CFrame.new(0, radius * 0.9, 0) * CFrame.Angles(0, math.rad(90), 0),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = GHOST
	light.Range = 60
	light.Brightness = 2
	light.Parent = veil
	model.Parent = folder
	Debris:AddItem(model, math.max(1, untilAt - now() + 0.5))
	table.insert(portalParts, model)
	return model
end

local function portals(p)
	for _, m in ipairs(portalParts) do
		m:Destroy()
	end
	table.clear(portalParts)
	local a, b = p.a, p.b
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		return
	end
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	portalRing(a, dir, p.radius or 22, p.untilAt or now() + 20)
	portalRing(b, -dir, p.radius or 22, p.untilAt or now() + 20)
	if hud and (near(a, X.ALERT_RANGE) or near(b, X.ALERT_RANGE)) then
		hud.banner("👻 GHOST PORTALS! Sail through one, come out of the other.", GHOST, 2.6, 2)
	end
end

local function ghostShip(p)
	if typeof(p.from) ~= "Vector3" or typeof(p.dir) ~= "Vector3" then
		return
	end
	local model = galleon(p.from, p.dir, Color3.fromRGB(150, 255, 210), 0.5)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Material = Enum.Material.Neon
		end
	end
	local born, life, speed = p.born or now(), p.life or 9, p.speed or 110
	local pivot = model:GetPivot()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local age = now() - born
		if age > life or not model.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		local fadeIn = math.min(1, age / 0.6, (life - age) / 0.8)
		local at = p.from + p.dir * speed * age + Vector3.new(0, math.sin(age * 3) * 1.5, 0)
		model:PivotTo(CFrame.lookAt(at, at + p.dir))
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1 - fadeIn * 0.5
			end
		end
	end)
	model:PivotTo(pivot)
	Effects.sound("rise", { position = p.from, speed = 0.4, volume = 0.9, range = 600 })
end

-- Thunder -----------------------------------------------------------------------------------------------------------------
local tint
local function thunderSky(p)
	if not near(p.center, p.radius or 500) then
		return
	end
	if not tint then
		tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "ThunderSky"
		tint.Parent = Lighting
	end
	tint.Brightness, tint.Saturation, tint.TintColor = 0, 0, Color3.new(1, 1, 1)
	TweenService:Create(tint, TweenInfo.new(1.5), {
		Brightness = -0.12,
		Saturation = -0.3,
		TintColor = Color3.fromRGB(200, 210, 255),
	}):Play()
	task.delay(math.max(2, p.time or 12), function()
		if tint then
			TweenService
				:Create(tint, TweenInfo.new(2), { Brightness = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
				:Play()
		end
	end)
	if hud then
		hud.banner("⚡ THUNDERSTRUCK! Spread out: lightning hits where boats crowd.", SPARK, 2.4, 2)
	end
end

local function boltWarn(p)
	warnRing(p.position, 40, p.warn or 2, SPARK)
	local cloud = part({
		Name = "StormEye",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(30, 12, 30),
		Color = Color3.fromRGB(40, 44, 60),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.3,
		CFrame = CFrame.new(p.position + Vector3.new(0, 260, 0)),
	})
	TweenService:Create(cloud, TweenInfo.new(p.warn or 2), { Size = Vector3.new(160, 40, 160) }):Play()
	Debris:AddItem(cloud, (p.warn or 2) + 1.2)
	for _ = 1, 4 do
		task.delay(math.random() * (p.warn or 2), function()
			local a = p.position + Vector3.new(math.random(-30, 30), 2, math.random(-30, 30))
			Effects.line(
				a,
				a + Vector3.new(math.random(-10, 10), math.random(6, 18), math.random(-10, 10)),
				SPARK,
				0.5,
				0.15
			)
		end)
	end
	Effects.sound("blip", { position = p.position, speed = 0.4, volume = 0.9, range = 500 })
end

local function bolt(p)
	Effects.bolt(p.position)
	local ring = part({
		Name = "Shockwave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 4, 4),
		Color = SPARK,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CFrame = CFrame.new(p.position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local reach = (p.ring or 170) * 2
	TweenService:Create(ring, TweenInfo.new(p.ringTime or 1.1, Enum.EasingStyle.Linear), {
		Size = Vector3.new(2, reach, reach),
		Transparency = 0.85,
	}):Play()
	Debris:AddItem(ring, (p.ringTime or 1.1) + 0.1)
	Effects.shakeAt(p.position, 2.2, 0.7, 400)
end

local function chainBolt(p)
	if typeof(p.from) ~= "Vector3" or typeof(p.to) ~= "Vector3" then
		return
	end
	local from = p.from + Vector3.new(0, 4, 0)
	for i = 1, 5 do
		local nextPoint = from:Lerp(p.to + Vector3.new(0, 4, 0), i / 5)
			+ Vector3.new(math.random(-5, 5), math.random(-3, 3), math.random(-5, 5)) * (i < 5 and 1 or 0)
		Effects.line(from, nextPoint, SPARK, 1.4, 0.3)
		from = nextPoint
	end
end

local function supercharge(p)
	Effects.burst(p.position + Vector3.new(0, 3, 0), SPARK, 50, 40)
	local mine = false
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and typeof(p.hull) == "Instance" and seat.Parent == p.hull.Parent then
		mine = true
	end
	if mine and hud then
		hud.banner("⚡ SUPERCHARGED! FREE BOOST!", SPARK, 1.5, 3)
		Effects.punchFov(104)
	end
end

-- Messages -----------------------------------------------------------------------------------------------------------------
local function clear()
	folder:ClearAllChildren()
	table.clear(barrels)
	table.clear(armadaParts)
	table.clear(portalParts)
	for w in pairs(waveViews) do
		waveViews[w] = nil
	end
	for wh in pairs(whirlViews) do
		whirlViews[wh] = nil
	end
	if tint then
		tint:Destroy()
		tint = nil
	end
end

local HANDLERS = {
	meteorWarn = meteorWarn,
	meteorHit = meteorHit,
	krakenWarn = krakenWarn,
	krakenStrike = krakenStrike,
	krakenSlam = krakenSlam,
	krakenSwat = function(p)
		Effects.burst(p.position + Vector3.new(0, 3, 0), PURPLE, 40, 40)
		Effects.sound("thud", { position = p.position, speed = 0.5, volume = 1, range = 500 })
	end,
	wave = function(p)
		local w = p.wave
		if type(w) ~= "table" or not hud then
			return
		end
		local start = Vector3.new(w.x, 0, w.z)
		if near(start, X.waves.start + 500) then
			hud.banner(
				"🌊 ROGUE WAVE FROM THE "
					.. compass(myPosition(), start)
					.. "! Surf it, jump it (SPACE), or get clear.",
				WAVE,
				3,
				2
			)
		end
	end,
	armada = armada,
	shell = shell,
	barrels = function(p)
		for _, entry in ipairs(p.list or {}) do
			makeBarrel(entry[1], entry[2], entry[3], entry[4] == 1)
		end
		if hud and #(p.list or {}) > 0 then
			local first = p.list[1]
			if near(Vector3.new(first[2], 0, first[3]), X.ALERT_RANGE) then
				hud.banner("💥 BARRELS ADRIFT! The red ones explode.", Color3.fromRGB(255, 120, 60), 2.4, 2)
			end
		end
	end,
	barrelsAt = function(p)
		local ids, xs, zs = p.ids or {}, p.xs or {}, p.zs or {}
		for i, id in ipairs(ids) do
			local b = barrels[id]
			if b then
				b.tx, b.tz = xs[i], zs[i]
			end
		end
	end,
	barrelGone = function(p)
		local b = barrels[p.id]
		if b then
			barrels[p.id] = nil
			b.part:Destroy()
		end
	end,
	whirls = function(p)
		if hud and near(p.center, X.ALERT_RANGE) then
			hud.banner("🌀 WHIRLPOOLS! The eye flings you out.", Color3.fromRGB(120, 210, 255), 2.4, 2)
		end
	end,
	fling = function(p)
		Effects.spray(p.position, 1.6)
		Effects.sound("whoosh", { position = p.position, speed = 0.6, volume = 1, range = 500 })
	end,
	portals = portals,
	portalsGone = function()
		for _, m in ipairs(portalParts) do
			m:Destroy()
		end
		table.clear(portalParts)
	end,
	portalHop = function(p)
		for _, at in ipairs({ p.from, p.to }) do
			if typeof(at) == "Vector3" then
				Effects.burst(at + Vector3.new(0, 10, 0), GHOST, 60, 40)
				Effects.ring(at + Vector3.new(0, 1, 0), GHOST, 40, 0.6)
			end
		end
		Effects.sound("rise", { position = p.to, speed = 1.6, volume = 1, range = 500 })
	end,
	ghostShip = ghostShip,
	ghostRam = function(p)
		Effects.burst(p.position + Vector3.new(0, 4, 0), GHOST, 50, 40)
		Effects.sound("thud", { position = p.position, speed = 0.4, volume = 1, range = 500 })
	end,
	thunderSky = thunderSky,
	boltWarn = boltWarn,
	bolt = bolt,
	chainBolt = chainBolt,
	supercharge = supercharge,
	episode = function(p)
		-- Far away: the feed says so (the server's line). Near: the big banner (each event's own handler says
		-- what to do; this one names it).
		if hud and typeof(p.center) == "Vector3" and near(p.center, (p.radius or 200) + X.ALERT_RANGE) then
			hud.banner(string.format("%s %s!", p.icon or "", p.name or "CHAOS"), ORANGE, 2, 2)
			Effects.chime({ 1.5, 1.2, 0.9 }, 0.6)
		end
	end,
	reset = clear,
}

function ChaosFx.handle(p)
	local fn = HANDLERS[p.kind]
	if fn then
		fn(p)
	end
end

function ChaosFx.start(hudModule)
	hud = hudModule
	RunService.RenderStepped:Connect(function(dt)
		local t = now()
		if #Sea.chaos.waves > 0 or next(waveViews) then
			drawWaves(t)
		end
		if #Sea.chaos.whirls > 0 or next(whirlViews) then
			drawWhirls(t)
		end
		if next(barrels) then
			drawBarrels(dt, t)
		end
	end)
end

return ChaosFx

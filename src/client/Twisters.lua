-- Drawing the tornadoes (V9; restyled V10). The server only publishes where they are (workspace.TwisterData, read by
-- shared/Twister.lua); every client draws them itself, so the funnel spins smoothly at any distance and
-- costs the server nothing. What makes one readable from far off: a tall funnel of translucent bands that
-- snakes and widens toward a dark cloud cap, debris whirling up it, spray at its foot and a roar that grows
-- as you near it. Strength (forming, dying away) fades the whole thing in and out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Twister = require(Shared:WaitForChild("Twister"))

local Twisters = {}

local T = Config.TWISTER
local LAYERS = 7 -- the soft core: few, tall, overlapping
local ARMS, WISPS = 3, 14 -- the wind wrapped round it
local DEBRIS = 10
local FAR = 4200 -- Beyond this from the camera it is not drawn.
local HIDDEN = CFrame.new(0, -1000, 0)

local folder
local views = {} -- id -> view

local function now()
	return workspace:GetServerTimeNow()
end

local function part(name, size, color, material, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = HIDDEN
	p.Parent = folder
	return p
end

-- An ellipsoid (a block with a sphere mesh): soft shapes that blend into each other, unlike cylinder bands.
local function puff(name, size, color, material, transparency)
	local p = part(name, size, color, material, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- V10 (docs/ART_DIRECTION.md): the funnel is a soft core of tall overlapping ellipsoids wrapped in spiral arms
-- of long flat wisps that race round and up it, so it reads as wind, not stacked plates. Bright streaks spiral
-- up its skin to show the spin; the cap is a wide billowing storm cloud, not a flat disc.
local STREAKS = 18
local CAP_PUFFS = 8

local function makeView(tw)
	local view = { layers = {}, debris = {}, streaks = {}, cap = {} }
	-- The core: tall narrow ellipsoids stacked with lots of overlap, so no ring edges show.
	local layerHeight = T.HEIGHT / LAYERS
	for i = 1, LAYERS do
		local y = (i - 0.5) * layerHeight
		local r = Twister.radiusAt(y) * 0.62
		local shade = 206 - i * 5
		local layer = puff(
			"TwisterBand",
			Vector3.new(r * 2, layerHeight * 2.6, r * 2),
			Color3.fromRGB(shade, shade + 6, shade + 18),
			Enum.Material.SmoothPlastic,
			0.4
		)
		view.layers[i] = { part = layer, y = y, transparency = 0.4 }
	end
	-- The wind: long flat wisps lying on the funnel's skin in spiral arms, racing round and up it.
	view.wisps = {}
	for arm = 1, ARMS do
		for k = 1, WISPS do
			local h = (k - 0.5) / WISPS
			local r = Twister.radiusAt(h * T.HEIGHT)
			local wisp = puff(
				"TwisterWisp",
				Vector3.new(1.6, 7 + h * 6, r * 1.3),
				k % 2 == 0 and Color3.fromRGB(236, 242, 252) or Color3.fromRGB(196, 204, 218),
				Enum.Material.SmoothPlastic,
				0.3
			)
			table.insert(view.wisps, { part = wisp, h = h, arm = arm, transparency = 0.3 + (k % 3) * 0.1 })
		end
	end
	for i = 1, STREAKS do
		local streak = part(
			"TwisterStreak",
			Vector3.new(0.9, 0.9, 14 + (i % 3) * 5),
			Color3.fromRGB(236, 244, 255),
			Enum.Material.Neon,
			0.35
		)
		view.streaks[i] = { part = streak, phase = i / STREAKS }
	end
	for i = 1, DEBRIS do
		local size = 1.5 + (i % 4)
		local bit = part(
			"TwisterDebris",
			Vector3.new(size, size * 0.6, size * 1.4),
			i % 3 == 0 and Color3.fromRGB(90, 70, 50) or Color3.fromRGB(70, 80, 90),
			i % 3 == 0 and Enum.Material.Wood or Enum.Material.Slate,
			0
		)
		view.debris[i] = { part = bit, phase = i * 0.63, height = (i / DEBRIS) * T.HEIGHT * 0.95 }
	end
	local capR = T.RADIUS * T.FLARE
	for i = 1, CAP_PUFFS do
		local middle = i == 1
		local size = middle and capR * 3.4 or capR * (1.8 + (i % 2) * 0.4)
		local cloud = puff(
			"TwisterCloud",
			Vector3.new(size, size * (middle and 0.24 or 0.32), size),
			middle and Color3.fromRGB(64, 70, 88) or Color3.fromRGB(96 + i * 6, 104 + i * 6, 124 + i * 6),
			Enum.Material.SmoothPlastic,
			0
		)
		view.cap[i] = { part = cloud, angle = i * math.pi * 2 / (CAP_PUFFS - 1), reach = middle and 0 or capR * 1.5 }
	end
	view.foot = puff(
		"TwisterFoot",
		Vector3.new(T.RADIUS * 3.4, 6, T.RADIUS * 3.4),
		Color3.fromRGB(235, 245, 255),
		Enum.Material.ForceField,
		0.2
	)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(1.2, 2)
	spray.Speed = NumberRange.new(20, 40)
	spray.SpreadAngle = Vector2.new(80, 80)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.RotSpeed = NumberRange.new(-120, 120)
	spray.Rate = 40
	spray.Parent = view.foot
	view.spray = spray
	local roar = Instance.new("Sound")
	roar.SoundId = "rbxasset://sounds/action_falling.mp3"
	roar.Looped = true
	roar.Volume = 0
	roar.PlaybackSpeed = 0.42
	roar.RollOffMode = Enum.RollOffMode.InverseTapered
	roar.RollOffMinDistance = 60
	roar.RollOffMaxDistance = 650
	roar.Parent = view.foot
	roar:Play()
	view.roar = roar
	view.id = tw.id
	return view
end

local function eachPart(view, fn)
	for _, list in ipairs({ view.layers, view.wisps, view.streaks, view.debris, view.cap }) do
		for _, entry in ipairs(list) do
			fn(entry.part)
		end
	end
	fn(view.foot)
end

local function dropView(view)
	eachPart(view, function(p)
		p:Destroy()
	end)
end

local function hideView(view)
	local parts, frames = {}, {}
	eachPart(view, function(p)
		table.insert(parts, p)
		table.insert(frames, HIDDEN)
	end)
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	view.spray.Rate = 0
	view.roar.Volume = 0
end

-- Where the funnel's axis is at height y (it snakes: pushed off the axis more the higher it is).
local function swayAt(t, k)
	return Vector3.new(math.cos(t * 0.7 + k * 2.2), 0, math.sin(t * 0.9 + k * 1.7)) * k * 16
end

local function drawView(view, tw, t, eye)
	local x, z = Twister.positionOf(tw, t)
	local strength = Twister.strength(tw, t)
	if (Vector3.new(x, 0, z) - Vector3.new(eye.X, 0, eye.Z)).Magnitude > FAR or strength <= 0 then
		hideView(view)
		return
	end
	local parts, frames = {}, {}
	for i, layer in ipairs(view.layers) do
		local sway = swayAt(t, i / #view.layers)
		local cf = CFrame.new(x + sway.X, layer.y, z + sway.Z) * CFrame.Angles(0, t * 4 + i * 0.7, 0)
		table.insert(parts, layer.part)
		table.insert(frames, cf)
		layer.part.Transparency = 1 - (1 - layer.transparency) * strength
	end
	for _, wisp in ipairs(view.wisps) do
		local y = wisp.h * T.HEIGHT
		local sway = swayAt(t, wisp.h)
		local r = Twister.radiusAt(y) * 0.92
		local a = t * 4.2 + wisp.arm * (math.pi * 2 / ARMS) + wisp.h * 7
		local at = Vector3.new(x + sway.X + math.cos(a) * r, y, z + sway.Z + math.sin(a) * r)
		-- Lying along the skin: long axis (Z) along the direction of spin, tilted up a little.
		local tangent = Vector3.new(-math.sin(a), 0.22, math.cos(a))
		table.insert(parts, wisp.part)
		table.insert(frames, CFrame.lookAt(at, at + tangent))
		wisp.part.Transparency = 1 - (1 - wisp.transparency) * strength
	end
	-- Streaks race up and round the funnel's skin.
	for _, streak in ipairs(view.streaks) do
		local h = ((streak.phase + t * 0.18) % 1) * T.HEIGHT * 0.96
		local k = h / T.HEIGHT
		local sway = swayAt(t, k)
		local r = Twister.radiusAt(h) * 0.9
		local a = t * 5 + streak.phase * 37
		local at = Vector3.new(x + sway.X + math.cos(a) * r, h, z + sway.Z + math.sin(a) * r)
		local tangent = Vector3.new(-math.sin(a), 0.35, math.cos(a))
		table.insert(parts, streak.part)
		table.insert(frames, CFrame.lookAt(at, at + tangent))
		streak.part.Transparency = 1 - 0.65 * strength
	end
	for _, bit in ipairs(view.debris) do
		local h = (bit.height + t * 34) % (T.HEIGHT * 0.95)
		local r = Twister.radiusAt(h) * 0.95
		local a = t * 3.1 + bit.phase * 5
		local cf = CFrame.new(x + math.cos(a) * r, h, z + math.sin(a) * r) * CFrame.Angles(a, a * 1.3, 0)
		table.insert(parts, bit.part)
		table.insert(frames, cf)
		bit.part.Transparency = strength > 0.3 and 0 or 1
	end
	local top = swayAt(t, 1)
	for i, cloud in ipairs(view.cap) do
		local a = cloud.angle + t * 0.4
		local cf = CFrame.new(
			x + top.X + math.cos(a) * cloud.reach,
			T.HEIGHT + 6 + (i == 1 and 0 or 5),
			z + top.Z + math.sin(a) * cloud.reach
		) * CFrame.Angles(0, a, 0)
		table.insert(parts, cloud.part)
		table.insert(frames, cf)
		cloud.part.Transparency = 1 - strength
	end
	table.insert(parts, view.foot)
	table.insert(frames, CFrame.new(x, 1, z) * CFrame.Angles(0, -t * 3, 0))
	view.foot.Transparency = 1 - 0.8 * strength
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	view.spray.Rate = 45 * strength
	view.roar.Volume = 1.1 * strength
end

function Twisters.init()
	folder = Instance.new("Folder")
	folder.Name = "LootGoblinsTwisters"
	folder.Parent = workspace
	Twister.follow()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = now()
		local eye = camera.CFrame.Position
		local seen = {}
		for _, tw in ipairs(Twister.list()) do
			seen[tw.id] = true
			local view = views[tw.id]
			if not view then
				view = makeView(tw)
				views[tw.id] = view
			end
			drawView(view, tw, t, eye)
		end
		for id, view in pairs(views) do
			if not seen[id] then
				dropView(view)
				views[id] = nil
			end
		end
	end)
end

-- For the minimap and the map: where each tornado is now.
function Twisters.positions()
	local t = now()
	local out = {}
	for _, tw in ipairs(Twister.list()) do
		if Twister.strength(tw, t) > 0 then
			local x, z = Twister.positionOf(tw, t)
			table.insert(out, { x = x, z = z, name = tw.name })
		end
	end
	return out
end

return Twisters

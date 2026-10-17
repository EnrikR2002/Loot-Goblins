-- Drawing the tornadoes (V9). The server only publishes where they are (workspace.TwisterData, read by
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
local LAYERS = 14
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

local function makeView(tw)
	local view = { layers = {}, debris = {}, base = {} }
	local layerHeight = T.HEIGHT / LAYERS
	for i = 1, LAYERS do
		local y = (i - 0.5) * layerHeight
		local r = Twister.radiusAt(y) * 0.8
		local shade = 205 - i * 4
		local layer = part(
			"TwisterBand",
			Vector3.new(layerHeight * 1.15, r * 2, r * 2),
			Color3.fromRGB(shade, shade + 10, shade + 25),
			i % 3 == 0 and Enum.Material.ForceField or Enum.Material.Glass,
			0.55,
			Enum.PartType.Cylinder
		)
		view.layers[i] = { part = layer, y = y, transparency = i % 3 == 0 and 0.2 or 0.55 }
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
	view.cap = part(
		"TwisterCloud",
		Vector3.new(14, T.RADIUS * T.FLARE * 4.4, T.RADIUS * T.FLARE * 4.4),
		Color3.fromRGB(70, 76, 92),
		Enum.Material.SmoothPlastic,
		0.25,
		Enum.PartType.Cylinder
	)
	view.foot = part(
		"TwisterFoot",
		Vector3.new(1.4, T.RADIUS * 3.2, T.RADIUS * 3.2),
		Color3.fromRGB(235, 245, 255),
		Enum.Material.Glass,
		0.5,
		Enum.PartType.Cylinder
	)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(1.2, 2)
	spray.Speed = NumberRange.new(20, 40)
	spray.SpreadAngle = Vector2.new(80, 80)
	spray.EmissionDirection = Enum.NormalId.Right -- the foot is a cylinder on its side: Right is up
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

local function dropView(view)
	for _, layer in ipairs(view.layers) do
		layer.part:Destroy()
	end
	for _, bit in ipairs(view.debris) do
		bit.part:Destroy()
	end
	view.cap:Destroy()
	view.foot:Destroy()
end

local function hideView(view)
	local parts, frames = {}, {}
	for _, layer in ipairs(view.layers) do
		table.insert(parts, layer.part)
		table.insert(frames, HIDDEN)
	end
	for _, bit in ipairs(view.debris) do
		table.insert(parts, bit.part)
		table.insert(frames, HIDDEN)
	end
	table.insert(parts, view.cap)
	table.insert(frames, HIDDEN)
	table.insert(parts, view.foot)
	table.insert(frames, HIDDEN)
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	view.spray.Rate = 0
	view.roar.Volume = 0
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder part's axis is X: stand it up

local function drawView(view, tw, t, eye)
	local x, z = Twister.positionOf(tw, t)
	local strength = Twister.strength(tw, t)
	if (Vector3.new(x, 0, z) - Vector3.new(eye.X, 0, eye.Z)).Magnitude > FAR or strength <= 0 then
		hideView(view)
		return
	end
	local parts, frames = {}, {}
	for i, layer in ipairs(view.layers) do
		local k = i / #view.layers
		-- The funnel snakes: each band is pushed off the axis a little more the higher it is.
		local sway = Vector3.new(math.cos(t * 0.7 + k * 2.2), 0, math.sin(t * 0.9 + k * 1.7)) * k * 16
		local cf = CFrame.new(x + sway.X, layer.y, z + sway.Z) * CFrame.Angles(0, t * 4 + i * 0.7, 0) * UPRIGHT
		table.insert(parts, layer.part)
		table.insert(frames, cf)
		layer.part.Transparency = 1 - (1 - layer.transparency) * strength
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
	table.insert(parts, view.cap)
	table.insert(frames, CFrame.new(x, T.HEIGHT + 6, z) * CFrame.Angles(0, t * 0.5, 0) * UPRIGHT)
	view.cap.Transparency = 1 - 0.75 * strength
	table.insert(parts, view.foot)
	table.insert(frames, CFrame.new(x, 1, z) * CFrame.Angles(0, -t * 3, 0) * UPRIGHT)
	view.foot.Transparency = 1 - 0.5 * strength
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

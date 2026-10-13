-- The Leviathan (V7): the thing the Sleeper's eye belongs to, made visible.
--
-- It is a set of plain parts moved from the server by the Sleeper's own tick (BestiaryMinor), so it
-- is only ever simulated while a goblin is near enough for the Sleeper to be awake:
--   LURK   seven humps of its back swim a slow circle off the east dock and rise as the Sleeper grows
--          aware of a loud boat (awareness 0 to 1): at 0 almost nothing shows, at 1 it is a coiling ridge;
--   SLAM   when the Sleeper strikes, the head and a neck of twelve segments rise out of the sea in an arc
--          and come down on the marked circle exactly when the marker closes (Blast.strike, unchanged:
--          the damage, the marker and the telegraph are the same as the tentacles were);
--   RECOIL a blast that lands on the head while it is up (a keg, a cannonball, a bolt) makes it flinch:
--          the arc is cut short, it sinks and does not strike again for twice as long.
-- It does not fight and has no health bar: it is the Sleeper's answer to noise, with a face. All its
-- numbers are in Config.CREATURES.Sleeper (range, strikes, damage) and Config.LEVIATHAN.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)

local Leviathan = {}

local L = Config.LEVIATHAN
local DEEP = Color3.fromRGB(46, 86, 96)
local BELLY = Color3.fromRGB(150, 205, 190)

local folder
local center -- the middle of its circle
local humps = {}
local neck = {}
local head
local jawTop, jawBottom, eyes
local phase = 0
local striking = false -- a slam is in the air
local recoiled = false
local headAt = nil -- where the head is while it is up (for blasts)
local generation = 0

local function part(name, size, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Slate
	p.Shape = shape or Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(0, -200, 0)
	p.Parent = folder
	return p
end

function Leviathan.build(threatsFolder, home)
	folder = threatsFolder
	center = home
	for i = 1, L.HUMPS do
		humps[i] = part("LeviathanHump", Vector3.new(1, 1, 1) * (13 - i * 0.9), DEEP)
	end
	for i = 1, L.NECK do
		neck[i] = part("LeviathanNeck", Vector3.new(1, 1, 1) * (11 - i * 0.35), DEEP)
	end
	head = part("LeviathanHead", Vector3.new(22, 14, 26), DEEP)
	jawTop = part("LeviathanJawTop", Vector3.new(15, 4, 18), BELLY, Enum.PartType.Block)
	jawBottom = part("LeviathanJawBottom", Vector3.new(13, 3, 16), BELLY, Enum.PartType.Block)
	eyes = {}
	for _, side in ipairs({ -1, 1 }) do
		local eye = part("LeviathanEye", Vector3.new(4, 4, 4), Color3.fromRGB(255, 190, 70))
		eye.Material = Enum.Material.Neon
		eye.Name = "LeviathanEye"
		eyes[side] = eye
	end
end

local function hide()
	for _, p in ipairs(humps) do
		p.CFrame = CFrame.new(0, -200, 0)
	end
	for _, p in ipairs(neck) do
		p.CFrame = CFrame.new(0, -200, 0)
	end
	head.CFrame = CFrame.new(0, -200, 0)
	jawTop.CFrame = head.CFrame
	jawBottom.CFrame = head.CFrame
	for _, eye in pairs(eyes) do
		eye.CFrame = head.CFrame
	end
	headAt = nil
end

local function placeHead(cf, open)
	head.CFrame = cf
	jawTop.CFrame = cf * CFrame.new(0, 3 + open * 3, -15) * CFrame.Angles(math.rad(-6 - open * 14), 0, 0)
	jawBottom.CFrame = cf * CFrame.new(0, -5 - open * 3, -12) * CFrame.Angles(math.rad(8 + open * 16), 0, 0)
	for side, eye in pairs(eyes) do
		eye.CFrame = cf * CFrame.new(side * 7, 4, -9)
	end
	headAt = cf.Position
end

-- Each tick from the Sleeper: the lurking ridge. awareness is 0 to 1.
function Leviathan.update(dt, awareness)
	if not head or striking then
		return
	end
	phase += dt * L.SWIM_SPEED / L.RADIUS
	local rise = L.LURK_MIN + (1 - L.LURK_MIN) * awareness
	for i, p in ipairs(humps) do
		local angle = phase - (i - 1) * L.GAP
		local x, z = center.X + math.cos(angle) * L.RADIUS, center.Z + math.sin(angle) * L.RADIUS
		local wave = math.max(0, math.sin(phase * 3 - i * 1.1))
		local size = p.Size.X
		p.CFrame = CFrame.new(x, -size * 0.55 + size * 0.9 * wave * rise, z)
	end
	-- The head follows the first hump, just under the surface until it strikes.
	local angle = phase + 0.12
	local x, z = center.X + math.cos(angle) * L.RADIUS, center.Z + math.sin(angle) * L.RADIUS
	local tangent = CFrame.lookAt(
		Vector3.new(x, -8 + 6 * awareness, z),
		Vector3.new(center.X + math.cos(angle + 0.1) * L.RADIUS, -8, center.Z + math.sin(angle + 0.1) * L.RADIUS)
	)
	for _, p in ipairs(neck) do
		p.CFrame = CFrame.new(0, -200, 0)
	end
	placeHead(tangent, awareness * 0.4)
	headAt = nil
end

-- A slam that lands at `at` when `delay` seconds have passed. Returns immediately.
function Leviathan.slam(at, delay)
	if not head or striking then
		return
	end
	striking = true
	recoiled = false
	local g = generation
	local startHead = head.Position
	if startHead.Y < -30 then
		startHead = Vector3.new(center.X + L.RADIUS, -8, center.Z)
	end
	local landing = Vector3.new(at.X, 0, at.Z)
	local started = os.clock()
	task.spawn(function()
		local function path(s)
			-- a high arc from where the head was to the circle, with the peak mid-way
			local flatPos = startHead:Lerp(landing, s)
			local height = math.sin(math.min(1, s) * math.pi) * L.ARC_HEIGHT
			return Vector3.new(
				flatPos.X,
				math.max(startHead.Y, -6) + (landing.Y - startHead.Y) * s + height - (1 - s) * 0,
				flatPos.Z
			)
		end
		while true do
			local dt = RunService.Heartbeat:Wait()
			if g ~= generation then
				return
			end
			local s = math.min(1.25, (os.clock() - started) / delay)
			if recoiled then
				break
			end
			local position = path(math.min(s, 1))
			local ahead = path(math.min(s + 0.04, 1))
			local look = (ahead - position)
			look = look.Magnitude > 0.1 and look or Vector3.new(0, -1, 0)
			local open = s < 1 and 0.8 or 0.1
			placeHead(CFrame.lookAt(position, position + look), open)
			-- the neck is the same path, a little behind
			for i, p in ipairs(neck) do
				local back = math.max(0, math.min(s, 1) - i * L.NECK_GAP)
				p.CFrame = CFrame.new(path(back))
			end
			if s >= 1.25 or dt > 1 then
				break
			end
		end
		-- sink away
		local sinkFrom = head.Position
		local sinkStart = os.clock()
		while os.clock() - sinkStart < 1.1 do
			RunService.Heartbeat:Wait()
			if g ~= generation then
				return
			end
			local k = (os.clock() - sinkStart) / 1.1
			local down = Vector3.new(0, -k * 60, 0)
			placeHead(CFrame.new(sinkFrom + down) * head.CFrame.Rotation, 0.2)
			for i, p in ipairs(neck) do
				p.CFrame = CFrame.new(p.Position + Vector3.new(0, -2.2 - i * 0.2, 0))
			end
		end
		striking = false
		headAt = nil
		hide()
	end)
end

-- Where the head is, if it is up and can be hit.
function Leviathan.headPosition()
	return striking and headAt or nil
end

function Leviathan.recoil()
	if striking then
		recoiled = true
		Net.feed("The Leviathan recoils from the blast!", Color3.fromRGB(255, 200, 110))
	end
end

function Leviathan.reset()
	generation += 1
	striking = false
	recoiled = false
	if head then
		hide()
	end
end

return Leviathan

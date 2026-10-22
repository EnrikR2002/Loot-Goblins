-- The valuables: building them, who holds what, throwing, knocking loose,
-- banking at the Hoard and respawning. The server owns all of it.
--
-- An item is always in one state:
--   "spot"    resting where it spawns (hold E to pry it off: this causes Trouble)
--   "carried" welded above a player's head
--   "loose"   a physics object on the ground (or floating in the sea)
--   "away"    banked; it comes back to its spot after Config respawn time
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Movement = require(script.Parent.Movement)

local Loot = {}
Loot.items = {}
Loot.byId = {}

-- (item, player, fromSpot, fromPlayer). fromSpot is true when this take causes Trouble.
Loot.Taken = Util.signal()
-- (item, reason, byPlayer, fromPlayer). reason: "throw", "sword", "guardian", "death", "boulder", "spirit".
Loot.Loosened = Util.signal()
-- (item, player)
Loot.Banked = Util.signal()
-- (item, reason). reason: "respawn", "timeout", "lost".
Loot.Returned = Util.signal()

-- Main wires this to Poltergoblin so spirits can't bank.
Loot.canBank = function(_player)
	return true
end

local CARRY_LIFT = 2.8 -- Studs from the root's center to the bottom of carried loot.

local carrying = {} -- player -> item
local slipUntil = {} -- player -> time their grip stops being loose (the two-strike rule)
local dropSafeUntil = {} -- player -> time before which the world cannot make them drop again
local enabled = false
local refs
-- V13.1: who to name when a world hit knocks a carrier out ("knocked out by ..."), by the hit's reason.
local WORLD_NAMES = {
	guardian = "the Guardian",
	guardianleap = "the Guardian",
	boulder = "a boulder",
	cannon = "a cannonball",
	keg = "a powder keg",
	crab = "Old Clacker",
	echo = "the Echo",
	eel = "the Warden",
	ghost = "a ghost pirate",
	imp = "the jade frogs",
	frog = "the jade frogs",
	chill = "the Chill",
	lancer = "a lancer",
	lava = "lava",
	leviathan = "the Leviathan",
	lightning = "lightning",
	marine = "the garrison",
	ram = "Bramble",
	watcher = "a Watcher",
	pursuit = "a pursuer",
}

local function now()
	return workspace:GetServerTimeNow()
end

-- Item models --------------------------------------------------------------------
-- Each item is one physical core part plus welded, massless decoration.
local function decorate(core, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = core.CFrame * offset
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = p
	weld.Parent = p
	p.Parent = core.Parent
	return p
end

-- V10 decoration that is looks only: rays (grapples, aim) pass through it, so a treasure's grab area stays what
-- it was before V10 restyled it.
local function trim(core, name, size, offset, color, material, shape)
	local p = decorate(core, name, size, offset, color, material, shape)
	p.CanQuery = false
	return p
end

local GOLD = Color3.fromRGB(255, 200, 40)

-- One builder per look (Config.LOOT's `visual`). Each resizes the core and welds on decoration;
-- the treasure's own color (def.color) tints it, so one look can serve several treasures.
local function lighten(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local builders = {
	disc = function(core, def)
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(1.2, 4.4, 4.4)
		core.Material = Enum.Material.Glass
		core.Transparency = 0.2
		decorate(
			core,
			"DiscGlow",
			Vector3.new(1.3, 3, 3),
			CFrame.new(),
			lighten(def.color, 0.6),
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		decorate(
			core,
			"DiscRim",
			Vector3.new(0.8, 4.8, 4.8),
			CFrame.new(),
			Color3.fromRGB(190, 140, 60),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		).Transparency =
			0.5
	end,
	chest = function(core, def)
		core.Size = Vector3.new(4.4, 3.2, 3)
		core.Material = Enum.Material.WoodPlanks
		core.Color = def.color:Lerp(Color3.fromRGB(70, 40, 20), 0.55)
		-- V10: a domed lid propped open on a heap of coins, gold bands, a lock and a jewel on top.
		trim(
			core,
			"Lid",
			Vector3.new(4.6, 3.1, 3.1),
			CFrame.new(0, 1.9, 1.1) * CFrame.Angles(math.rad(-35), 0, 0),
			core.Color:Lerp(Color3.new(0, 0, 0), 0.2),
			Enum.Material.WoodPlanks,
			Enum.PartType.Cylinder
		)
		for _, x in ipairs({ -1.6, 1.6 }) do
			decorate(core, "Band", Vector3.new(0.4, 3.4, 3.2), CFrame.new(x, 0, 0), GOLD, Enum.Material.Metal)
		end
		decorate(core, "Lock", Vector3.new(0.8, 0.9, 0.4), CFrame.new(0, 0.6, -1.6), GOLD, Enum.Material.Metal)
		decorate(core, "Spill", Vector3.new(3.8, 0.6, 2.6), CFrame.new(0, 1.7, 0), GOLD, Enum.Material.Neon).Transparency =
			0.2
		for i, at in ipairs({ Vector3.new(-1, 2.1, -0.4), Vector3.new(0.6, 2.2, 0.3), Vector3.new(1.4, 2, -0.6) }) do
			trim(
				core,
				"Coin",
				Vector3.new(0.25, 1.1, 1.1),
				CFrame.new(at) * CFrame.Angles(0, i * 0.9, math.rad(60 + i * 20)),
				GOLD,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
		trim(
			core,
			"Jewel",
			Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(-0.2, 2.3, 0.5) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			lighten(def.color, 0.2),
			Enum.Material.Neon
		)
	end,
	orb = function(core, def)
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(3.8, 3.8, 3.8)
		core.Material = Enum.Material.Glass
		core.Transparency = 0.25
		decorate(
			core,
			"OrbGlow",
			Vector3.new(2.4, 2.4, 2.4),
			CFrame.new(),
			lighten(def.color, 0.35),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2
			decorate(
				core,
				"OrbShard",
				Vector3.new(0.6, 2.2, 0.6),
				CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.8) * CFrame.Angles(0.5, 0, 0),
				lighten(def.color, 0.5),
				Enum.Material.Neon
			)
		end
	end,
	-- V10: the Golden Idol is THE prize, so it looks it: a squat golden goblin king, ears out, ruby eyes and a
	-- ruby on its brow, arms folded over a fat belly, a gold crown and (the Idol only) a sun halo behind its head.
	idol = function(core, def)
		core.Size = Vector3.new(3, 4.6, 3)
		core.Material = Enum.Material.Metal
		core.Color = def.color
		-- The core keeps its size (it is what you carry and throw) but is invisible: the figure below is the look.
		core.Transparency = 1
		local deep = def.color:Lerp(Color3.fromRGB(150, 90, 20), 0.35)
		local ruby = Color3.fromRGB(255, 40, 60)
		local metal = Enum.Material.Metal
		local ball = Enum.PartType.Ball
		trim(core, "IdolBase", Vector3.new(3.2, 0.6, 3.2), CFrame.new(0, -2, 0), deep, metal)
		trim(core, "IdolBelly", Vector3.new(3, 3, 3), CFrame.new(0, -0.6, 0), def.color, metal, ball).Reflectance = 0.2
		trim(core, "IdolChest", Vector3.new(2.4, 1.4, 2), CFrame.new(0, 0.6, 0.1), def.color, metal)
		trim(core, "IdolArms", Vector3.new(3, 0.7, 0.9), CFrame.new(0, 0.1, -1.2), deep, metal)
		trim(core, "IdolHead", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 1.7, 0), def.color, metal, ball).Reflectance =
			0.2
		for _, side in ipairs({ -1, 1 }) do
			trim(
				core,
				"IdolEar",
				Vector3.new(0.35, 0.9, 1.7),
				CFrame.new(side * 1.4, 1.9, 0.1) * CFrame.Angles(0, side * math.rad(70), side * math.rad(-30)),
				def.color,
				metal,
				Enum.PartType.Wedge
			)
			trim(
				core,
				"IdolEye",
				Vector3.new(0.5, 0.35, 0.3),
				CFrame.new(side * 0.5, 1.8, -1.08),
				ruby,
				Enum.Material.Neon
			)
		end
		trim(
			core,
			"IdolBrowGem",
			Vector3.new(0.4, 0.4, 0.4),
			CFrame.new(0, 2.35, -0.95) * CFrame.Angles(0, 0, math.rad(45)),
			ruby,
			Enum.Material.Neon
		)
		trim(
			core,
			"IdolCrownBand",
			Vector3.new(0.5, 2, 2),
			CFrame.new(0, 2.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
			deep,
			metal,
			Enum.PartType.Cylinder
		)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			trim(
				core,
				"IdolCrown",
				Vector3.new(0.4, 0.9, 0.4),
				CFrame.new(math.cos(a) * 0.82, 3.2, math.sin(a) * 0.82),
				Color3.fromRGB(255, 226, 110),
				metal
			)
		end
		if def.id == "Idol" then
			local halo = trim(
				core,
				"IdolHalo",
				Vector3.new(0.3, 4.4, 4.4),
				CFrame.new(0, 1.8, 0.9) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(255, 226, 120),
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
			halo.Transparency = 0.35
		end
	end,
	-- V10: the Jade Frog: a fat jade frog squatting on a gold lily pad, bulging gold-ringed eyes.
	frog = function(core, def)
		core.Size = Vector3.new(3, 4.6, 3)
		core.Material = Enum.Material.Glass
		core.Transparency = 1 -- same size and physics as before; the frog below is the look
		core.Color = def.color
		trim(
			core,
			"FrogBody",
			Vector3.new(3.8, 3.8, 3.8),
			CFrame.new(0, -0.6, 0),
			def.color,
			Enum.Material.Glass,
			Enum.PartType.Ball
		)
		trim(
			core,
			"FrogHead",
			Vector3.new(3, 3, 3),
			CFrame.new(0, 1.2, -0.6),
			def.color,
			Enum.Material.Glass,
			Enum.PartType.Ball
		)
		for _, side in ipairs({ -1, 1 }) do
			trim(
				core,
				"FrogEye",
				Vector3.new(1.1, 1.1, 1.1),
				CFrame.new(side * 0.9, 2.4, -0.9),
				GOLD,
				Enum.Material.Metal,
				Enum.PartType.Ball
			)
			trim(
				core,
				"FrogPupil",
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(side * 0.95, 2.5, -1.35),
				Color3.fromRGB(20, 20, 20),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
			trim(
				core,
				"FrogLeg",
				Vector3.new(1.4, 1.4, 1.4),
				CFrame.new(side * 1.8, -1.7, -0.6),
				def.color,
				Enum.Material.Glass,
				Enum.PartType.Ball
			)
		end
		trim(
			core,
			"FrogGlow",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(0, -0.4, 0),
			lighten(def.color, 0.5),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		trim(
			core,
			"LilyPad",
			Vector3.new(0.4, 5, 5),
			CFrame.new(0, -2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end,
	gear = function(core, def)
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(1.2, 4, 4)
		core.Material = Enum.Material.Metal
		core.Color = def.color
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			decorate(
				core,
				"GearTooth",
				Vector3.new(1.2, 1.1, 1.1),
				CFrame.new(0, math.cos(a) * 2.2, math.sin(a) * 2.2),
				def.color,
				Enum.Material.Metal
			)
		end
		decorate(
			core,
			"GearHub",
			Vector3.new(1.6, 1.4, 1.4),
			CFrame.new(),
			Color3.fromRGB(255, 250, 200),
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
	end,
	crown = function(core, def)
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(1.6, 4, 4)
		core.Material = Enum.Material.Metal
		core.Color = def.color
		core.Orientation = Vector3.new(0, 0, 90)
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			decorate(
				core,
				"CrownSpike",
				Vector3.new(1, 1, 0.8),
				CFrame.new(0, math.cos(a) * 2, math.sin(a) * 2) * CFrame.Angles(a, 0, 0),
				Color3.fromRGB(255, 220, 90),
				Enum.Material.Neon
			)
		end
	end,
	gem = function(core, def)
		core.Size = Vector3.new(2.6, 2.6, 2.6)
		core.Material = Enum.Material.Glass
		core.Transparency = 0.15
		core.Color = def.color
		decorate(
			core,
			"GemFacet",
			Vector3.new(2.6, 2.6, 2.6),
			CFrame.Angles(math.rad(45), math.rad(45), 0),
			lighten(def.color, 0.3),
			Enum.Material.Glass
		).Transparency =
			0.2
		decorate(core, "GemGlow", Vector3.new(1.4, 1.4, 1.4), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.Neon)
		-- V10: a gold setting round its middle.
		trim(
			core,
			"GemSetting",
			Vector3.new(0.5, 3.3, 3.3),
			CFrame.Angles(0, 0, math.rad(90)),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		decorate(
			core,
			"GemTop",
			Vector3.new(0.7, 2, 0.7),
			CFrame.new(0, 2.2, 0),
			lighten(def.color, 0.5),
			Enum.Material.Neon
		)
	end,
	tooth = function(core, def)
		core.Size = Vector3.new(2.6, 5.4, 2.6)
		core.Material = Enum.Material.Marble
		core.Color = def.color
		decorate(core, "ToothTip", Vector3.new(1.5, 2.4, 1.5), CFrame.new(0, 3.6, 0), def.color, Enum.Material.Marble)
		decorate(
			core,
			"ToothRoot",
			Vector3.new(3.2, 1, 3.2),
			CFrame.new(0, -2.8, 0),
			Color3.fromRGB(190, 180, 150),
			Enum.Material.Marble
		)
	end,
	chalice = function(core, def)
		core.Size = Vector3.new(1.4, 3.4, 1.4)
		core.Material = Enum.Material.Metal
		core.Color = Color3.fromRGB(190, 190, 205)
		decorate(
			core,
			"ChaliceCup",
			Vector3.new(3.4, 3.4, 3.4),
			CFrame.new(0, 2.2, 0),
			Color3.fromRGB(200, 205, 220),
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		decorate(
			core,
			"ChaliceFlame",
			Vector3.new(2, 2, 2),
			CFrame.new(0, 3.4, 0),
			def.color,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		decorate(
			core,
			"ChaliceBase",
			Vector3.new(3, 0.6, 3),
			CFrame.new(0, -1.8, 0),
			Color3.fromRGB(150, 150, 165),
			Enum.Material.Metal
		)
	end,
}

local function makeTag(core, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LootTag"
	gui.Size = UDim2.fromOffset(190, 52)
	gui.StudsOffsetWorldSpace = Vector3.new(0, core.Size.Y / 2 + 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = Config.LOOT_TAG_RANGE -- V9: close range only (V8: 3,000, the whole map; the map has it all)
	gui.LightInfluence = 0

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = def.color
	title.TextStrokeTransparency = 0.15
	title.Text = string.format("%s  %dg", string.upper(def.name), def.value)
	title.Parent = gui

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.3
	status.Text = ""
	status.Parent = gui

	gui.Parent = core
	return gui, status
end

local function makePillar(core, color)
	local base = Instance.new("Attachment")
	base.Name = "PillarBase"
	base.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "LootPillarTop"
	top.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Name = "LootPillar"
	beam.Attachment0 = base
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 2.5
	beam.Width1 = 2.5
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = core
	return beam, top
end

local function buildItem(def, spot, parent)
	local model = Instance.new("Model")
	model.Name = def.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- Light pillars and tags must show from anywhere.

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Color = def.color
	core.CFrame = spot
	core.Anchored = true
	core.CanCollide = true
	core.TopSurface = Enum.SurfaceType.Smooth
	core.BottomSurface = Enum.SurfaceType.Smooth
	-- Lighter than water, so dropped loot floats instead of sinking out of reach.
	core.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.6, 0.2)
	core.Parent = model
	model.PrimaryPart = core
	local build = builders[def.visual] or builders.orb
	build(core, def)
	-- The builder may have resized the core; recenter it on the spot.
	core.CFrame = spot

	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = core

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Color = ColorSequence.new(def.color)
	sparkles.LightEmission = 1
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.Parent = core
	if def.id == "Idol" then
		-- V10: the prize glows brighter and sparkles harder than anything else.
		light.Range = 22
		light.Brightness = 2
		sparkles.Rate = 18
		sparkles.Size = NumberSequence.new(0.8, 0)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LootPrompt"
	prompt.ObjectText = def.name .. " (" .. def.value .. " gold)"
	prompt.ActionText = "STEAL"
	prompt.HoldDuration = Config.STEAL_HOLD
	prompt.MaxActivationDistance = Config.PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	local tag, status = makeTag(core, def)
	local beam, pillarTop = makePillar(core, def.color)
	core:SetAttribute("LootId", def.id)
	model.Parent = parent

	return {
		id = def.id,
		def = def,
		model = model,
		core = core,
		spot = spot,
		prompt = prompt,
		tag = tag,
		status = status,
		beam = beam,
		pillarTop = pillarTop,
		sparkles = sparkles,
		state = "spot",
		bonus = 0, -- Interest: gold added while nobody takes it.
		unclaimedSince = 0,
		title = tag:FindFirstChild("Title"),
		carrier = nil,
		weld = nil,
		lastHolder = nil,
		lastHeldAt = -math.huge,
		looseSince = 0,
		immuneUntil = 0,
		returnAt = 0,
		noRegrab = nil,
	}
end

-- State -------------------------------------------------------------------------
-- The client reads loot state from attributes on the Loot folder, which never leaves.
local function publish(item)
	local folder = refs.folders.loot
	folder:SetAttribute(item.id .. "State", item.state)
	folder:SetAttribute(item.id .. "Carrier", item.carrier and item.carrier.DisplayName or nil)
	folder:SetAttribute(item.id .. "CarrierId", item.carrier and item.carrier.UserId or nil)
	folder:SetAttribute(item.id .. "ReturnAt", item.state == "away" and item.returnAt or nil)
end

local function setState(item, state)
	item.state = state
	local free = state == "spot" or state == "loose"
	item.prompt.Enabled = enabled and free
	item.prompt.ActionText = state == "spot" and "STEAL" or "GRAB"
	item.prompt.HoldDuration = state == "spot" and Config.STEAL_HOLD or Config.GRAB_HOLD
	item.beam.Enabled = free
	item.sparkles.Enabled = free
	if state == "loose" then
		item.status.Text = "LOOSE! GRAB IT"
		item.status.TextColor3 = Color3.fromRGB(255, 120, 120)
		item.tag.AlwaysOnTop = true
	elseif state == "carried" then
		item.status.Text = item.carrier and string.upper(item.carrier.DisplayName) or ""
		item.status.TextColor3 = Color3.new(1, 1, 1)
	else
		item.status.Text = ""
		item.tag.AlwaysOnTop = true
	end
	item.core:SetAttribute("State", state)
	publish(item)
end

-- The tag and prompt show what the item is worth right now (base value + interest).
local function setBonus(item, bonus)
	item.bonus = bonus
	local value = item.def.value + bonus
	item.title.Text =
		string.format("%s  %dg%s", string.upper(item.def.name), value, bonus > 0 and (" +" .. bonus) or "")
	item.prompt.ObjectText = item.def.name .. " (" .. value .. " gold)"
	refs.folders.loot:SetAttribute(item.id .. "Bonus", bonus)
end

function Loot.valueOf(item)
	return item.def.value + item.bonus
end

local function clearCarrier(item)
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	local carrier = item.carrier
	if carrier then
		carrying[carrier] = nil
		Movement.setCarry(carrier, nil)
		carrier:SetAttribute("CarryingLoot", nil)
	end
	item.carrier = nil
	item.tag.PlayerToHideFrom = nil
	item.core.Massless = false
end

local function attach(item, player, root)
	clearCarrier(item)
	local t = now()
	local core = item.core
	core.Anchored = false
	core.CanCollide = false
	core.Massless = true
	core.AssemblyLinearVelocity = Vector3.zero
	core.AssemblyAngularVelocity = Vector3.zero
	core.CFrame = root.CFrame * CFrame.new(0, CARRY_LIFT + core.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = core
	weld.Parent = core

	item.weld = weld
	item.held = nil
	item.carrier = player
	item.lastHolder = player
	item.immuneUntil = t + Config.STEAL_IMMUNITY
	item.noRegrab = nil
	carrying[player] = item
	-- The carrier doesn't need their own tag floating over their head.
	item.tag.PlayerToHideFrom = player
	Movement.setCarry(player, item.def.carrySpeed, item.def.weight)
	player:SetAttribute("CarryingLoot", item.id)
	setState(item, "carried")
end

-- Turns the item into a free physics object where it is, with a push.
local function release(item, velocity)
	clearCarrier(item)
	local core = item.core
	core.Anchored = false
	core.CanCollide = true
	pcall(function()
		core:SetNetworkOwner(nil)
	end)
	core.AssemblyLinearVelocity = velocity or Vector3.zero
	core.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6
	item.lastHeldAt = now()
	item.looseSince = now()
	setState(item, "loose")
end

local function placeAtSpot(item)
	local core = item.core
	core.Anchored = true
	core.CanCollide = true
	core.AssemblyLinearVelocity = Vector3.zero
	core.AssemblyAngularVelocity = Vector3.zero
	core.CFrame = item.spot
	item.model.Parent = refs.folders.loot
	item.pillarTop.Position = item.spot.Position + Vector3.new(0, 300, 0)
	-- V12: every treasure's interest clock starts now, so untouched treasure grows together and the feed says so
	-- in one line (see Loot.tick). V11 staggered the clocks by up to 59 s to spread one line per treasure; with
	-- 45 s steps that made some treasures grow the moment a raid began.
	item.unclaimedSince = now()
	setBonus(item, 0)
end

local function returnToSpot(item, reason)
	clearCarrier(item)
	item.lastHolder = nil
	item.noRegrab = nil
	placeAtSpot(item)
	setState(item, "spot")
	if reason then
		Loot.Returned:Fire(item, reason)
	end
end

local function bank(item, player)
	clearCarrier(item)
	item.bankedValue = item.def.value + item.bonus
	item.model.Parent = nil
	item.returnAt = now() + item.def.respawn
	setState(item, "away")
	Loot.Banked:Fire(item, player)
	setBonus(item, 0)
end

local function flatUnit(v)
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.05 then
		local a = math.random() * math.pi * 2
		return Vector3.new(math.cos(a), 0, math.sin(a))
	end
	return flat.Unit
end

local function inBank(position)
	local hoard = refs.hoard.position
	return Util.flatDistance(position, hoard) <= Config.BANK_RADIUS and math.abs(position.Y - hoard.Y) < 14
end

local function outOfBounds(position)
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	return position.X < min.X
		or position.X > max.X
		or position.Y < min.Y
		or position.Y > max.Y
		or position.Z < min.Z
		or position.Z > max.Z
end

-- Public API -----------------------------------------------------------------------
function Loot.build(worldRefs)
	refs = worldRefs
	for _, def in ipairs(Config.LOOT) do
		local spot = refs.lootSpots[def.id]
		assert(spot, "World has no spot for loot " .. def.id)
		local item = buildItem(def, spot, refs.folders.loot)
		table.insert(Loot.items, item)
		Loot.byId[def.id] = item
		item.prompt.Triggered:Connect(function(player)
			Loot.tryGrab(item, player)
		end)
		placeAtSpot(item)
		setState(item, "spot")
	end
end

-- Pickups only work during a raid.
function Loot.setEnabled(on)
	enabled = on
	for _, item in ipairs(Loot.items) do
		item.prompt.Enabled = on and (item.state == "spot" or item.state == "loose")
	end
end

function Loot.itemOf(player)
	return carrying[player]
end

-- Every carrier as { player = ..., item = ..., root = ... }.
function Loot.carriers()
	local list = {}
	for player, item in pairs(carrying) do
		local root = Util.aliveRoot(player)
		if root then
			table.insert(list, { player = player, item = item, root = root })
		end
	end
	return list
end

-- E on the prompt: take it off its spot, or grab it loose.
function Loot.tryGrab(item, player)
	if not enabled or (item.state ~= "spot" and item.state ~= "loose") then
		return
	end
	local root = Util.aliveRoot(player)
	if not root or (root.Position - item.core.Position).Magnitude > Config.PICKUP_DISTANCE + 4 then
		return
	end
	if carrying[player] then
		Net.toast(player, "HANDS FULL - Q to throw what you're holding")
		return
	end
	if item.noRegrab and item.noRegrab.player == player and now() < item.noRegrab.untilTime then
		return
	end
	local fromSpot = item.state == "spot"
	attach(item, player, root)
	Loot.Taken:Fire(item, player, fromSpot, nil)
end

-- Grapple: steal from a carrier or yank loose loot. Returns true on success.
function Loot.steal(item, thief)
	if not enabled or carrying[thief] then
		return false
	end
	local from = item.carrier
	if item.state == "carried" then
		if from == thief or now() < item.immuneUntil then
			return false
		end
	elseif item.state ~= "loose" then
		return false
	end
	local root = Util.aliveRoot(thief)
	if not root then
		return false
	end
	attach(item, thief, root)
	Loot.Taken:Fire(item, thief, false, from)
	return true
end

function Loot.isImmune(item)
	return now() < item.immuneUntil
end

-- Q: throw the held loot forward. Lands loose; anyone can grab it.
function Loot.throw(player)
	local item = carrying[player]
	local root = Util.aliveRoot(player)
	if not item or not root then
		return
	end
	local look = flatUnit(root.CFrame.LookVector)
	local carried = root.AssemblyLinearVelocity
	local velocity = look * Config.THROW_SPEED
		+ Vector3.new(carried.X, 0, carried.Z) * 0.5
		+ Vector3.new(0, Config.THROW_UP_SPEED, 0)
	release(item, velocity)
	item.noRegrab = { player = player, untilTime = now() + Config.THROW_REGRAB_DELAY }
	Loot.Loosened:Fire(item, "throw", player, player)
end

-- A hit pops the loot off the carrier, away from the hit. Respects steal
-- immunity. Returns true if something came loose.
-- V13.1 (the V13 playtest: "no bosses should be able to steal the treasure from you"): only a RIVAL's hit (byPlayer)
-- knocks treasure loose. A hit from the world (creatures, bosses, boulders, lava; byPlayer nil) never takes it: it
-- HURTS the carrier instead (Config.KNOCKOUT.HIT on top of the hit's own damage), and a carrier whose health runs
-- out is knocked out and drops it (server/Knockout.lua). V8 to V13 it loosened their grip (two hits dropped it).
function Loot.knockLoose(player, fromPosition, reason, byPlayer)
	local item = carrying[player]
	if not item or now() < item.immuneUntil then
		return false
	end
	if byPlayer == nil then
		local _, humanoid = Util.getCharacterParts(player)
		if humanoid and humanoid.Health > 0 then
			if WORLD_NAMES[reason] then
				player:SetAttribute("LastHitBy", WORLD_NAMES[reason])
				player:SetAttribute("LastHitAt", now())
			end
			humanoid:TakeDamage(Config.KNOCKOUT.HIT)
		end
		return false
	end
	local root = Util.aliveRoot(player)
	local away = root and (root.Position - fromPosition) or Vector3.zero
	release(item, flatUnit(away) * Config.KNOCK_LOOSE_SPEED + Vector3.new(0, 30, 0))
	Loot.Loosened:Fire(item, reason, byPlayer, player)
	return true
end

-- Death, leaving, or a shattered spirit: drop whatever you hold, ignoring
-- steal immunity.
function Loot.dropFor(player, reason, byPlayer)
	local item = carrying[player]
	if not item then
		return
	end
	release(item, Vector3.new(0, 18, 0))
	Loot.Loosened:Fire(item, reason, byPlayer, player)
end

-- Loot comes back in one piece: used between raids.
function Loot.resetAll()
	for _, item in ipairs(Loot.items) do
		item.held = nil
		returnToSpot(item, nil)
	end
end

-- Creatures can carry treasure (Creatures.lua). The item stays "loose" the whole time: anyone can
-- still grab it out of the creature's grip, and the bounds check and the Hoard keep working. It
-- does not time out while held. Returns false if the item is not loose.
function Loot.hold(item, cframe)
	if item.state ~= "loose" then
		return false
	end
	local core = item.core
	core.Anchored = true
	core.CanCollide = false
	core.AssemblyLinearVelocity = Vector3.zero
	core.AssemblyAngularVelocity = Vector3.zero
	core.CFrame = cframe
	item.looseSince = now()
	item.held = true
	return true
end

-- The creature lets go: the item falls free again, with a push.
function Loot.letGo(item, velocity)
	if item.state == "loose" and item.held then
		item.held = nil
		release(item, velocity or Vector3.zero)
	end
end

-- A creature puts loose treasure back where it belongs. `reason` reaches Loot.Returned.
function Loot.sendHome(item, reason)
	if item.state == "loose" then
		item.held = nil
		returnToSpot(item, reason)
	end
end

-- Revealed carriers' tags show through walls.
function Loot.setRevealed(item, revealed)
	if item.state == "carried" then
		item.tag.AlwaysOnTop = revealed
	end
end

local grown = {} -- V12: treasures whose interest went up this tick (one feed line for them all)

function Loot.tick()
	local t = now()
	for _, item in ipairs(Loot.items) do
		if item.state == "carried" then
			local player = item.carrier
			local root = player and Util.aliveRoot(player)
			if not root then
				-- Safety net: the carrier vanished without the death hook firing.
				release(item, Vector3.zero)
			elseif enabled and inBank(root.Position) and Loot.canBank(player) then
				bank(item, player)
			end
		elseif item.state == "loose" then
			local position = item.core.Position
			local holder = item.lastHolder
			if outOfBounds(position) then
				returnToSpot(item, "lost")
			elseif t - item.looseSince > Config.LOOSE_RETURN_TIME then
				returnToSpot(item, "timeout")
			elseif
				enabled
				and inBank(position)
				and holder
				and holder.Parent
				and t - item.lastHeldAt <= Config.THROWN_BANK_WINDOW
			then
				-- A throw that lands in the Hoard counts for the thrower.
				bank(item, holder)
			else
				item.pillarTop.Position = position + Vector3.new(0, 300, 0)
			end
		elseif item.state == "away" and t >= item.returnAt then
			returnToSpot(item, "respawn")
		elseif item.state == "spot" and enabled then
			-- Interest: treasure nobody takes keeps growing, up to a cap.
			-- Each step is a share of what the treasure is worth, so waiting matters for a far prize too.
			local steps =
				math.min(Config.LOOT_INTEREST_MAX, math.floor((t - item.unclaimedSince) / Config.LOOT_INTEREST_EVERY))
			local earned = steps * math.max(1, math.floor(item.def.value * Config.LOOT_INTEREST_SHARE + 0.5))
			if earned ~= item.bonus then
				local grew = earned > item.bonus
				setBonus(item, earned)
				if grew then
					table.insert(grown, item)
				end
			end
		end
	end
	-- V12: one line for every treasure that grew this moment. Through V11 each one had its own ("The Lost
	-- Compass is worth 7 gold now!"), and untouched treasure all grows at once: bursts of up to nineteen lines,
	-- about fifty a raid, pushing everything else out of the feed. The board and the map show each value.
	if #grown == 1 then
		local item = grown[1]
		Net.feed("The " .. item.def.name .. " is worth " .. Loot.valueOf(item) .. " gold now!", item.def.color)
	elseif #grown > 1 then
		table.sort(grown, function(a, b)
			return Loot.valueOf(a) > Loot.valueOf(b)
		end)
		local best = grown[1]
		Net.feed(
			string.format(
				"%d untouched treasures grew. The %s is worth %d gold now (T: every value).",
				#grown,
				best.def.name,
				Loot.valueOf(best)
			),
			Color3.fromRGB(255, 215, 90)
		)
	end
	table.clear(grown)
end

function Loot.forget(player)
	Loot.dropFor(player, "left")
	carrying[player] = nil
	slipUntil[player] = nil
	dropSafeUntil[player] = nil
end

-- A creature that TAKES treasure (V5's imps). V13.1: nothing from the world takes treasure any more; a world hit
-- hurts instead (Loot.knockLoose). Kept so an old caller is harmless: it hurts and returns nil.
function Loot.worldTake(player, reason)
	Loot.knockLoose(player, Vector3.zero, reason, nil)
	return nil
end

-- V13.1 (the V13 playtest: "allow treasure to be picked up by boating over to it"): a driver whose hull passes over
-- loose treasure picks it up, the same as grabbing it (Loot.Taken, immunity, the thrower's regrab delay all apply).
-- `boats`: Boats.list. Called each frame from Main; cheap (it looks at loose treasure only).
function Loot.sweepBoats(boats)
	if not enabled then
		return
	end
	local t = now()
	for _, item in ipairs(Loot.items) do
		if item.state == "loose" and not item.held then
			local position = item.core.Position
			for _, boat in ipairs(boats) do
				local seat = boat.driver
				local occupant = seat and seat.Occupant
				local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
				if player and not carrying[player] and boat.state == "float" then
					local hull = boat.hull
					local offset = hull.CFrame:PointToObjectSpace(position)
					local size = boat.spec.size
					if
						math.abs(offset.X) < size.X / 2 + 5
						and math.abs(offset.Z) < size.Z / 2 + 5
						and offset.Y > -14
						and offset.Y < 16
						and not (item.noRegrab and item.noRegrab.player == player and t < item.noRegrab.untilTime)
						and Util.aliveRoot(player)
					then
						attach(item, player, Util.aliveRoot(player))
						Loot.Taken:Fire(item, player, false, nil)
						Net.toast(player, "SCOOPED IT UP! " .. string.upper(item.def.name) .. " is aboard.")
						break
					end
				end
			end
		end
	end
end

return Loot

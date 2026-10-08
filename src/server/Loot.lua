-- The valuables: building them, who holds what, throwing, knocking loose,
-- banking at the Hoard and respawning. The server owns all of it.
--
-- An item is always in one state:
--   "spot"    resting where it spawns (hold E to pry it off: this causes Trouble)
--   "carried" welded above a player's head
--   "loose"   a physics object on the ground (or floating in the sea)
--   "away"    banked; it comes back to its spot after Config respawn time
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
local enabled = false
local refs

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

local GOLD = Color3.fromRGB(255, 200, 40)

local builders = {
	Lens = function(core)
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(1.2, 4.4, 4.4)
		core.Material = Enum.Material.Glass
		core.Transparency = 0.2
		decorate(
			core,
			"LensGlow",
			Vector3.new(1.3, 3, 3),
			CFrame.new(),
			Color3.fromRGB(255, 250, 200),
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		decorate(
			core,
			"LensRim",
			Vector3.new(0.8, 4.8, 4.8),
			CFrame.new(),
			Color3.fromRGB(190, 140, 60),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		).Transparency =
			0.5
	end,
	Chest = function(core)
		core.Size = Vector3.new(4.4, 3.2, 3)
		core.Material = Enum.Material.WoodPlanks
		core.Color = Color3.fromRGB(130, 80, 40)
		decorate(
			core,
			"Lid",
			Vector3.new(4.6, 0.8, 3.2),
			CFrame.new(0, 1.3, 0),
			Color3.fromRGB(100, 60, 30),
			Enum.Material.WoodPlanks
		)
		for _, x in ipairs({ -1.6, 1.6 }) do
			decorate(core, "Band", Vector3.new(0.4, 3.4, 3.2), CFrame.new(x, 0, 0), GOLD, Enum.Material.Metal)
		end
		decorate(core, "Lock", Vector3.new(0.8, 0.9, 0.4), CFrame.new(0, 0.6, -1.6), GOLD, Enum.Material.Metal)
		decorate(core, "Spill", Vector3.new(3.6, 0.5, 2.4), CFrame.new(0, 1.8, 0), GOLD, Enum.Material.Neon).Transparency =
			0.3
	end,
	Heart = function(core)
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(3.8, 3.8, 3.8)
		core.Material = Enum.Material.Glass
		core.Transparency = 0.25
		decorate(
			core,
			"HeartGlow",
			Vector3.new(2.4, 2.4, 2.4),
			CFrame.new(),
			Color3.fromRGB(240, 150, 255),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2
			decorate(
				core,
				"HeartShard",
				Vector3.new(0.6, 2.2, 0.6),
				CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.8) * CFrame.Angles(0.5, 0, 0),
				Color3.fromRGB(110, 230, 255),
				Enum.Material.Neon
			)
		end
	end,
	Idol = function(core)
		core.Size = Vector3.new(3, 4.6, 3)
		core.Material = Enum.Material.Metal
		core.Color = GOLD
		core.Reflectance = 0.15
		decorate(
			core,
			"IdolHead",
			Vector3.new(2.6, 2.6, 2.6),
			CFrame.new(0, 1.2, 0),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		for _, x in ipairs({ -0.55, 0.55 }) do
			decorate(
				core,
				"IdolEye",
				Vector3.new(0.5, 0.35, 0.3),
				CFrame.new(x, 1.3, -1.25),
				Color3.fromRGB(255, 40, 40),
				Enum.Material.Neon
			)
		end
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			decorate(
				core,
				"IdolCrown",
				Vector3.new(0.4, 1, 0.4),
				CFrame.new(math.cos(a) * 0.9, 2.7, math.sin(a) * 0.9),
				Color3.fromRGB(255, 120, 60),
				Enum.Material.Neon
			)
		end
	end,
}

local function makeTag(core, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LootTag"
	gui.Size = UDim2.fromOffset(190, 52)
	gui.StudsOffsetWorldSpace = Vector3.new(0, core.Size.Y / 2 + 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 3000 -- Readable across the whole map.
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
	builders[def.id](core)
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

local function clearCarrier(item)
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	local carrier = item.carrier
	if carrier then
		carrying[carrier] = nil
		Movement.setCarrySpeed(carrier, nil)
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
	item.carrier = player
	item.lastHolder = player
	item.immuneUntil = t + Config.STEAL_IMMUNITY
	item.noRegrab = nil
	carrying[player] = item
	-- The carrier doesn't need their own tag floating over their head.
	item.tag.PlayerToHideFrom = player
	Movement.setCarrySpeed(player, item.def.carrySpeed)
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
	item.model.Parent = nil
	item.returnAt = now() + item.def.respawn
	setState(item, "away")
	Loot.Banked:Fire(item, player)
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
function Loot.knockLoose(player, fromPosition, reason, byPlayer)
	local item = carrying[player]
	if not item or now() < item.immuneUntil then
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
		returnToSpot(item, nil)
	end
end

-- Revealed carriers' tags show through walls.
function Loot.setRevealed(item, revealed)
	if item.state == "carried" then
		item.tag.AlwaysOnTop = revealed
	end
end

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
		end
	end
end

function Loot.forget(player)
	Loot.dropFor(player, "left")
	carrying[player] = nil
end

return Loot

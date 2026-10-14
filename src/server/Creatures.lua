-- What lives on the islands (V5). This module is the shared machinery; Bestiary.lua holds the
-- inhabitants themselves, one small behavior each.
--
-- The rule for a creature: it must be something a player can LEARN. Each has one idea (statues
-- that only move when nobody is facing them, a double that retraces your path, a crab that owns
-- the sand) and the idea should be visible, fair, and useful once understood. None of them is
-- the Sun Temple's Guardian with a different skin, and none follows a thief home: they belong
-- to their island, and Heat stays the danger of the open sea.
--
-- What every creature gets from here:
--   * a body: one anchored root with the other parts welded to it, so moving it is one write
--   * sleep: a creature is only ticked while a player is within its `wake` range of its home
--     (or it is in the middle of something), so twenty of them cost nothing on an empty island
--   * ground and water queries, walking that follows the ground, player and carrier lookups
--   * one way to hurt, shove and take treasure from a player, one way to mark a spot first
--   * reset, the treasure-taken hook and the blast hook (a keg is the universal answer)
--
-- Creatures are kinematic, like the Guardian: they never collide, so they can never shove loot
-- off the map or wedge a boat. Everything they do to a player goes through Creatures.strike.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Impact = require(script.Parent.Impact)
local Blast = require(script.Parent.Blast)
local Alerts = require(script.Parent.Alerts)

local Creatures = {}

Creatures.list = {}
Creatures.generation = 0 -- Bumped on reset, so a delayed action from an old raid never lands.

local refs
local solid = RaycastParams.new() -- Ground a creature can stand on: terrain and walkable parts.
solid.FilterType = Enum.RaycastFilterType.Include
solid.IgnoreWater = true
local sight = RaycastParams.new() -- What blocks a line of sight.
sight.FilterType = Enum.RaycastFilterType.Include
sight.IgnoreWater = true
local nextWakeCheck = 0

function Creatures.now()
	return workspace:GetServerTimeNow()
end

function Creatures.refs()
	return refs
end

-- An island's center plus an offset, at height y.
function Creatures.at(id, dx, y, dz)
	local island = Archipelago.byId[id]
	return Vector3.new(island.x + (dx or 0), y or 0, island.z + (dz or 0))
end

-- The solid ground under a point: its height, its material, and what was hit. Water does not
-- count as ground: a result below WATER_Y is the seabed.
Creatures.WATER_Y = -0.4

function Creatures.floor(x, z, fromY)
	local hit = workspace:Raycast(Vector3.new(x, fromY or 400, z), Vector3.new(0, -460, 0), solid)
	if not hit then
		return -30, Enum.Material.Sand, nil
	end
	return hit.Position.Y, hit.Material, hit.Instance
end

function Creatures.canSee(from, to)
	local hit = workspace:Raycast(from, to - from, sight)
	return hit == nil
end

-- Players ---------------------------------------------------------------------------------
-- Everyone alive within `radius` (flat) of a point: { player, root, humanoid, item, distance }.
function Creatures.players(center, radius)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			local distance = Util.flatDistance(root.Position, center)
			if distance <= radius then
				table.insert(list, {
					player = player,
					root = root,
					humanoid = humanoid,
					item = Loot.itemOf(player),
					distance = distance,
				})
			end
		end
	end
	return list
end

-- The same, but only those carrying treasure.
function Creatures.carriers(center, radius)
	local list = {}
	for _, entry in ipairs(Creatures.players(center, radius)) do
		if entry.item then
			table.insert(list, entry)
		end
	end
	return list
end

-- The entry in a list nearest to a position (3D), or nil.
function Creatures.nearest(list, position)
	local best, bestDistance
	for _, entry in ipairs(list) do
		local distance = (entry.root.Position - position).Magnitude
		if not bestDistance or distance < bestDistance then
			best, bestDistance = entry, distance
		end
	end
	return best, bestDistance
end

-- Treasure lying loose within `radius` of a point.
function Creatures.looseLoot(center, radius)
	local list = {}
	for _, item in ipairs(Loot.items) do
		if item.state == "loose" and Util.flatDistance(item.core.Position, center) <= radius then
			table.insert(list, item)
		end
	end
	return list
end

-- Doing things to players -----------------------------------------------------------------
-- The one way a creature touches a player. opts:
--   damage   health removed (0 for a creature that only shoves)
--   push     a velocity (Vector3) to throw them with
--   reason   knocks their treasure loose with this cause ("crab", "ram", ...), unless nil
--   text     a line for their screen
-- Returns true if it landed. It does not land on a goblin the world hit a moment ago (Impact.lua), and
-- `reason` loosens a carrier's grip before it ever drops their treasure (Loot.knockLoose).
function Creatures.strike(entry, from, opts)
	local player, root, humanoid = entry.player, entry.root, entry.humanoid
	if not root.Parent or humanoid.Health <= 0 or not Impact.open(player) then
		return false
	end
	if (opts.damage or 0) > 0 then
		Impact.damage(humanoid, opts.damage)
	end
	if opts.push and not humanoid.SeatPart then
		Util.knockback(root, opts.push, opts.pushTime or 0.22)
	end
	if opts.reason then
		Loot.knockLoose(player, from, opts.reason, nil)
	end
	if opts.text then
		Net.toast(player, opts.text)
	end
	return true
end

-- A closing ring on the ground: the game's one sign for "something lands here".
function Creatures.mark(position, radius, seconds, color)
	Net.broadcast("Marker", { position = position, radius = radius, duration = seconds, color = color })
end

-- A sound and a puff where a creature did something (the client picks them by kind).
function Creatures.fx(kind, position, extra)
	local payload = extra or {}
	payload.kind = kind
	payload.position = position
	Net.broadcast("Creature", payload)
end

-- Bodies ----------------------------------------------------------------------------------
-- parts: { { name, size, offset (CFrame from the root), color, material, shape, transparency } }.
-- The first is the root. Nothing collides or answers raycasts: a creature is not a wall, and
-- a grapple aimed at one goes through to the ground behind it.
function Creatures.body(name, parts, parent)
	local model = Instance.new("Model")
	model.Name = name
	local root
	for index, spec in ipairs(parts) do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.Color = spec[4] or Color3.new(1, 1, 1)
		part.Material = spec[5] or Enum.Material.SmoothPlastic
		if spec[6] then
			part.Shape = spec[6]
		end
		part.Transparency = spec[7] or 0
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = index == 1
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if index == 1 then
			part.Anchored = true
			part.CFrame = CFrame.new(0, -200, 0)
			root = part
		else
			part.Anchored = false
			part.Massless = true
			part.CFrame = root.CFrame * (spec[3] or CFrame.new())
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
		part.Parent = model
	end
	model.PrimaryPart = root
	model.Parent = parent or refs.folders.threats
	return model, root
end

-- Puts a creature's root at its position and heading. `extra` is a pose on top (a tilt, a hop).
function Creatures.pose(creature, extra)
	local frame = CFrame.new(creature.position)
		* CFrame.Angles(0, creature.yaw or 0, 0)
		* (creature.lift or CFrame.new())
	if extra then
		frame *= extra
	end
	creature.root.CFrame = frame
end

-- Walks a ground creature toward a goal. Returns true while it still has somewhere to go.
-- allowed(x, z, y, material, instance) may refuse a step (the crab only crosses sand); a refused
-- step leaves it where it is.
function Creatures.walk(creature, goal, speed, dt, stop, allowed)
	local flat = Vector3.new(goal.X - creature.position.X, 0, goal.Z - creature.position.Z)
	local distance = flat.Magnitude
	-- (The small margin matters: a walker closing on its stopping distance would otherwise creep
	-- toward it for ever without arriving.)
	if distance <= (stop or 0.5) + 0.05 then
		return false
	end
	local direction = flat.Unit
	local step = math.min(speed * dt, distance - (stop or 0))
	local nextX, nextZ = creature.position.X + direction.X * step, creature.position.Z + direction.Z * step
	local y, material, instance = Creatures.floor(nextX, nextZ, creature.position.Y + 60)
	if allowed and not allowed(nextX, nextZ, y, material, instance) then
		return false
	end
	creature.yaw = math.atan2(-direction.X, -direction.Z)
	-- Feet follow the ground, quickly but not instantly, so a cliff is a climb and not a jump cut.
	local dy = y - creature.position.Y
	creature.position = Vector3.new(nextX, creature.position.Y + math.clamp(dy, -90 * dt, 70 * dt), nextZ)
	return true
end

function Creatures.face(creature, toward)
	local flat = Vector3.new(toward.X - creature.position.X, 0, toward.Z - creature.position.Z)
	if flat.Magnitude > 0.1 then
		creature.yaw = math.atan2(-flat.X, -flat.Z)
	end
end

-- The way a creature is facing, as a flat unit vector.
function Creatures.heading(creature)
	local yaw = creature.yaw or 0
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- Registry --------------------------------------------------------------------------------
-- def: { name, island, home (Vector3), wake (studs), build(self), tick(self, dt, t),
--        reset(self), onTaken(self, item, player, fromSpot), onBlast(self, position, radius) }
function Creatures.add(def)
	def.position = def.home
	def.island = def.island or select(1, Archipelago.nearest(def.home.X, def.home.Z)).id
	def.yaw = def.yaw or 0
	def.awake = false
	def.busy = false -- Set by a creature that must keep ticking with nobody near (returning home...).
	table.insert(Creatures.list, def)
	return def
end

function Creatures.build(worldRefs)
	refs = worldRefs
	solid.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground }
	sight.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground, refs.folders.structures }
	for _, creature in ipairs(Creatures.list) do
		creature:build()
		if creature.reset then
			creature:reset()
		end
	end
	Blast.Hit:Connect(function(position, radius)
		for _, creature in ipairs(Creatures.list) do
			if
				creature.onBlast
				and creature.position
				and (creature.position - position).Magnitude <= radius + (creature.size or 4)
			then
				creature:onBlast(position, radius)
			end
		end
	end)
end

function Creatures.onTaken(item, player, fromSpot)
	for _, creature in ipairs(Creatures.list) do
		if creature.onTaken then
			creature:onTaken(item, player, fromSpot)
		end
	end
end

function Creatures.tick(dt)
	local t = Creatures.now()
	if t >= nextWakeCheck then
		nextWakeCheck = t + 0.4
		local roots = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local root = Util.aliveRoot(player)
			if root then
				table.insert(roots, root.Position)
			end
		end
		for _, creature in ipairs(Creatures.list) do
			local near = false
			for _, position in ipairs(roots) do
				if Util.flatDistance(position, creature.home) <= creature.wake * Alerts.wakeFactor(creature.island) then
					near = true
					break
				end
			end
			creature.awake = near
		end
	end
	-- A long frame must not fling anything: creatures step as if it were a short one.
	dt = math.min(dt, 0.1)
	for _, creature in ipairs(Creatures.list) do
		if creature.awake or creature.busy then
			creature:tick(dt, t)
		end
	end
end

function Creatures.reset()
	Creatures.generation += 1
	for _, creature in ipairs(Creatures.list) do
		creature.busy = false
		if creature.reset then
			creature:reset()
		end
	end
end

-- How many are being ticked right now (for the performance line).
function Creatures.active()
	local count = 0
	for _, creature in ipairs(Creatures.list) do
		if creature.awake or creature.busy then
			count += 1
		end
	end
	return count, #Creatures.list
end

Creatures.Config = Config.CREATURES

return Creatures

-- Weather you can see coming. A storm is a moving cell of rough water, strong wind and
-- lightning. It is visible from far away (dark clouds and rain, drawn by the client's
-- Weather.lua from the cell list published here), it drifts slowly enough to outrun in a boat,
-- and its lightning is marked on the ground a moment before it lands. Storms are not random
-- disasters: quiet stretches come first, and each storm gives a clear heading and time to react.
--
--   ambient   a cell crosses the sea every couple of minutes, mostly well away from home
--   squall    a treasure (Maelstrom Rock) calls one down on its own island
--   tempest   at FRENZY heat the sea turns on the thief: a big cell sails in from a flank at
--             boat-beatable speed (Escalation)
--   fog       a cell with no wind, only a white-out (the Ghost Fleet's cover)
--
-- Swell, currents and wind drift all read these cells through Sea.storms, so boats really are
-- harder to handle inside one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Sea = require(script.Parent.Sea)
local Boats = require(script.Parent.Boats)
local Blast = require(script.Parent.Blast)
local Loot = require(script.Parent.Loot)

local Storms = {}

Storms.Spent = Util.signal() -- (x, z): an ambient storm just blew itself out here.
Storms.cells = {}

local refs
-- Waterspouts wandering inside the storm cells: { cell, angle, orbit, turn, part, hitAt = {} }.
local spouts = {}
local nextId = 1
local nextAmbientAt = 0
local nextPublishAt = 0
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local COMPASS = { "NORTH", "NORTH-EAST", "EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST" }

-- "NORTH-EAST" and so on, for a direction (north is -Z).
function Storms.compassName(dx, dz)
	local degrees = math.deg(math.atan2(dx, -dz)) % 360
	return COMPASS[math.floor((degrees + 22.5) / 45) % 8 + 1]
end

-- o: x, z, r, strength (0..1), vx, vz, duration, kind ("storm" or "fog"), hunt (Player).
function Storms.spawn(o)
	local t = now()
	local cell = {
		id = nextId,
		x = o.x,
		z = o.z,
		r = o.r or 280,
		s = 0,
		maxS = o.strength or 1,
		vx = o.vx or 0,
		vz = o.vz or 0,
		kind = o.kind or "storm",
		bornAt = t,
		endsAt = t + (o.duration or 80),
		hunt = o.hunt,
		nextStrikeAt = t + Config.LIGHTNING_FIRST_DELAY,
	}
	nextId += 1
	table.insert(Storms.cells, cell)
	if cell.kind == "storm" then
		table.insert(Sea.storms, cell)
		-- Twisters circle the storm's heart, some one way and some the other.
		for i = 1, (o.hunt and Config.SPOUT_COUNT_TEMPEST or Config.SPOUT_COUNT) do
			table.insert(spouts, {
				cell = cell,
				angle = random:NextNumber(0, math.pi * 2),
				orbit = random:NextNumber(0.25, 0.6),
				turn = random:NextNumber(0.1, 0.18) * (i % 2 == 0 and -1 or 1),
				part = nil,
				hitAt = {},
			})
		end
	end
	return cell
end

-- Waterspouts ---------------------------------------------------------------------------
-- A tall column of spray you can see from across the storm. Whatever it catches goes up and
-- sideways: a boat is thrown off its line (and can land a clean one for a burst), a goblin is
-- flung. It is a hazard to steer round, or a launch for the brave.
local function spoutPart()
	local column = Instance.new("Part")
	column.Name = "Waterspout"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(170, Config.SPOUT_RADIUS * 1.2, Config.SPOUT_RADIUS * 1.2)
	column.Color = Color3.fromRGB(205, 225, 240)
	column.Material = Enum.Material.SmoothPlastic
	column.Transparency = 0.55
	column.Anchored = true
	column.CanCollide = false
	column.CanTouch = false
	column.CanQuery = false
	column.CastShadow = false
	local foot = Instance.new("Part")
	foot.Name = "SpoutFoot"
	foot.Shape = Enum.PartType.Cylinder
	foot.Size = Vector3.new(1, Config.SPOUT_RADIUS * 2, Config.SPOUT_RADIUS * 2)
	foot.Color = Color3.fromRGB(240, 248, 255)
	foot.Material = Enum.Material.Neon
	foot.Transparency = 0.6
	foot.Anchored = true
	foot.CanCollide = false
	foot.CanTouch = false
	foot.CanQuery = false
	foot.CastShadow = false
	foot.Parent = column
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(1, 1.6)
	mist.Speed = NumberRange.new(20, 40)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Rate = 30
	mist.Parent = foot
	column.Parent = refs.folders.fx
	return column, foot
end

local function removeSpout(spout)
	if spout.part then
		spout.part:Destroy()
		spout.part = nil
	end
end

local function tickSpouts(dt, t)
	for i = #spouts, 1, -1 do
		local spout = spouts[i]
		local cell = spout.cell
		if t >= cell.endsAt then
			removeSpout(spout)
			table.remove(spouts, i)
		elseif cell.s < 0.5 then
			-- The storm is still building, or blowing itself out.
			removeSpout(spout)
		else
			spout.angle += spout.turn * dt
			local radius = cell.r * spout.orbit
			local x, z = cell.x + math.cos(spout.angle) * radius, cell.z + math.sin(spout.angle) * radius
			if not spout.part then
				spout.part, spout.foot = spoutPart()
			end
			-- A cylinder's long axis is X: stand it up.
			spout.part.CFrame = CFrame.new(x, 85, z) * CFrame.Angles(0, 0, math.rad(90))
			spout.foot.CFrame = CFrame.new(x, 1, z) * CFrame.Angles(0, 0, math.rad(90))
			-- The way the water circles inside it.
			local function fling(position)
				local out = Vector3.new(position.X - x, 0, position.Z - z)
				out = out.Magnitude > 0.5 and out.Unit or Vector3.new(1, 0, 0)
				local along = Vector3.new(-out.Z, 0, out.X) * (spout.turn > 0 and 1 or -1)
				return (along * 0.8 + out * 0.6) * Config.SPOUT_PUSH + Vector3.new(0, Config.SPOUT_LIFT, 0)
			end
			for _, boat in ipairs(Boats.list) do
				if
					boat.state == "float"
					and not boat.asleep
					and t - (spout.hitAt[boat] or -10) > Config.SPOUT_REHIT
				then
					local p = boat.hull.Position
					local reach = Config.SPOUT_RADIUS + boat.spec.size.X * 0.5
					if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < reach * reach and p.Y < 30 then
						spout.hitAt[boat] = t
						Boats.shove(boat, fling(p), Vector3.new(0, spout.turn > 0 and 1.4 or -1.4, 0))
						Boats.damage(boat, Config.SPOUT_HULL_DAMAGE, "a waterspout")
						Net.broadcast("Spout", { position = Vector3.new(x, 0, z) })
					end
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local root, humanoid = Util.aliveRoot(player)
				if root and not humanoid.SeatPart and t - (spout.hitAt[player] or -10) > Config.SPOUT_REHIT then
					local p = root.Position
					if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < Config.SPOUT_RADIUS ^ 2 and p.Y < 30 then
						spout.hitAt[player] = t
						Util.knockback(root, fling(p) * 1.15, 0.25)
						Net.broadcast("Spout", { position = Vector3.new(x, 0, z) })
					end
				end
			end
		end
	end
end

local function remove(cell)
	for i, other in ipairs(Storms.cells) do
		if other == cell then
			table.remove(Storms.cells, i)
			break
		end
	end
	for i, other in ipairs(Sea.storms) do
		if other == cell then
			table.remove(Sea.storms, i)
			break
		end
	end
end

-- A cell crossing the open sea. The sea is too big now for weather to find anyone by chance,
-- so a storm is seeded a little way off someone who is out there and set to blow across their
-- water: something they see coming and steer around (or through). Never on top of home.
local function spawnAmbient()
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	local home = refs.hoard.position
	local sailors = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = Util.aliveRoot(player)
		if root and Util.flatDistance(root.Position, home) > Config.STORM_HOME_CLEAR then
			table.insert(sailors, root.Position)
		end
	end
	for _ = 1, 12 do
		local x, z, heading
		if #sailors > 0 then
			local near = sailors[random:NextInteger(1, #sailors)]
			local bearing = random:NextNumber(0, math.pi * 2)
			local distance = random:NextNumber(Config.STORM_NEAR_MIN, Config.STORM_NEAR_MAX)
			x, z = near.X + math.cos(bearing) * distance, near.Z + math.sin(bearing) * distance
			-- Blowing back across them, give or take.
			heading = bearing + math.pi + random:NextNumber(-0.7, 0.7)
		else
			x = random:NextNumber(min.X + 300, max.X - 300)
			z = random:NextNumber(min.Z + 300, max.Z - 300)
			heading = random:NextNumber(0, math.pi * 2)
		end
		local inside = x > min.X + 200 and x < max.X - 200 and z > min.Z + 200 and z < max.Z - 200
		if inside and Vector3.new(x - home.X, 0, z - home.Z).Magnitude > Config.STORM_HOME_CLEAR then
			local speed = random:NextNumber(Config.STORM_SPEED_MIN, Config.STORM_SPEED_MAX)
			Storms.spawn({
				x = x,
				z = z,
				r = random:NextNumber(300, 420),
				strength = random:NextNumber(0.7, 0.95),
				vx = math.cos(heading) * speed,
				vz = math.sin(heading) * speed,
				duration = random:NextNumber(90, 125),
			})
			return
		end
	end
end

-- The sea turns on a thief: a big storm sails in from the side, slowly steering at them.
function Storms.hunt(player)
	for _, cell in ipairs(Storms.cells) do
		if cell.hunt and cell.endsAt > now() then
			return cell
		end
	end
	local root = Util.aliveRoot(player)
	if not root then
		return nil
	end
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = Config.TEMPEST_DISTANCE
	local x, z = root.Position.X + math.cos(angle) * distance, root.Position.Z + math.sin(angle) * distance
	x = math.clamp(x, Config.BOUNDS_MIN.X + 100, Config.BOUNDS_MAX.X - 100)
	z = math.clamp(z, Config.BOUNDS_MIN.Z + 100, Config.BOUNDS_MAX.Z - 100)
	local cell = Storms.spawn({
		x = x,
		z = z,
		r = 330,
		strength = 1,
		duration = Config.TEMPEST_DURATION,
		hunt = player,
	})
	local direction = Storms.compassName(x - root.Position.X, z - root.Position.Z)
	Net.message("A TEMPEST BLOWS IN FROM THE " .. direction .. "!", 4, Color3.fromRGB(170, 190, 255))
	Net.feed(
		"The sea wants its treasure back: a tempest is heading for " .. player.DisplayName .. "!",
		Color3.fromRGB(170, 190, 255)
	)
	return cell
end

-- Lightning: pick a boat or a person inside the storm, mark the spot, strike a beat later.
local function strike(cell)
	local candidates = {}
	local function consider(position, weight, velocity)
		local dx, dz = position.X - cell.x, position.Z - cell.z
		if dx * dx + dz * dz < (cell.r * 0.92) ^ 2 then
			table.insert(candidates, { position = position, weight = weight, velocity = velocity })
		end
	end
	for _, boat in ipairs(Boats.list) do
		if boat.state == "float" and not boat.asleep then
			local occupied = boat.driver ~= nil and boat.driver.Occupant ~= nil
			consider(boat.hull.Position, occupied and 4 or 1, boat.hull.AssemblyLinearVelocity)
		end
	end
	for _, carrier in ipairs(Loot.carriers()) do
		consider(carrier.root.Position, 3, carrier.root.AssemblyLinearVelocity)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local root = Util.aliveRoot(player)
		if root then
			consider(root.Position, 1, root.AssemblyLinearVelocity)
		end
	end
	local position
	if #candidates > 0 then
		local total = 0
		for _, c in ipairs(candidates) do
			total += c.weight
		end
		local roll = random:NextNumber(0, total)
		for _, c in ipairs(candidates) do
			roll -= c.weight
			if roll <= 0 then
				position = c.position + Vector3.new(c.velocity.X, 0, c.velocity.Z) * Config.LIGHTNING_DELAY * 0.65
				break
			end
		end
	end
	if not position then
		local angle, r = random:NextNumber(0, math.pi * 2), random:NextNumber(0, cell.r * 0.8)
		position = Vector3.new(cell.x + math.cos(angle) * r, 0, cell.z + math.sin(angle) * r)
	end
	-- The strike hits the water line or the ground under that point.
	Blast.strike(Vector3.new(position.X, math.max(position.Y, 0), position.Z), Config.LIGHTNING_DELAY, {
		radius = 11,
		damage = Config.LIGHTNING_DAMAGE,
		knockback = 64,
		hullDamage = Config.LIGHTNING_HULL_DAMAGE,
		boatPush = 55,
		lootReason = "lightning",
		cause = "lightning",
		markerColor = Color3.fromRGB(235, 240, 255),
		style = "lightning",
		bolt = true,
		color = Color3.fromRGB(235, 240, 255),
	})
end

local function publish(t)
	local parts = { string.format("%.2f", t) }
	for _, cell in ipairs(Storms.cells) do
		table.insert(
			parts,
			string.format(
				"%d,%.0f,%.0f,%.0f,%.2f,%.1f,%.1f,%d",
				cell.id,
				cell.x,
				cell.z,
				cell.r,
				cell.s,
				cell.vx,
				cell.vz,
				cell.kind == "fog" and 1 or 0
			)
		)
	end
	workspace:SetAttribute("StormData", table.concat(parts, ";"))
	-- A driver's client floats its own boat, so it needs the global roughness too.
	if workspace:GetAttribute("SeaRough") ~= Sea.rough then
		workspace:SetAttribute("SeaRough", Sea.rough)
	end
end

function Storms.tick(dt, raidActive)
	local t = now()
	if raidActive and t >= nextAmbientAt then
		nextAmbientAt = t + random:NextNumber(Config.STORM_GAP_MIN, Config.STORM_GAP_MAX)
		local ambient = 0
		for _, cell in ipairs(Storms.cells) do
			if not cell.hunt and cell.kind == "storm" then
				ambient += 1
			end
		end
		if ambient < Config.STORM_MAX_AMBIENT then
			spawnAmbient()
		end
	end
	for i = #Storms.cells, 1, -1 do
		local cell = Storms.cells[i]
		if t >= cell.endsAt then
			remove(cell)
			if cell.kind == "storm" and raidActive then
				Storms.Spent:Fire(cell.x, cell.z)
			end
		else
			-- A hunting storm steers toward its thief, slowly enough to outrun.
			if cell.hunt then
				local root = Util.aliveRoot(cell.hunt)
				if root then
					local to = Vector3.new(root.Position.X - cell.x, 0, root.Position.Z - cell.z)
					if to.Magnitude > 60 then
						local want = to.Unit * Config.TEMPEST_SPEED
						local blend = math.min(1, dt * 0.35)
						cell.vx += (want.X - cell.vx) * blend
						cell.vz += (want.Z - cell.vz) * blend
					end
				end
			end
			cell.x += cell.vx * dt
			cell.z += cell.vz * dt
			-- Fade in over the first seconds and out over the last.
			local fadeIn = math.clamp((t - cell.bornAt) / Config.STORM_FADE, 0, 1)
			local fadeOut = math.clamp((cell.endsAt - t) / Config.STORM_FADE, 0, 1)
			cell.s = cell.maxS * math.min(fadeIn, fadeOut)
			if cell.kind == "storm" and cell.s > 0.45 and t >= cell.nextStrikeAt then
				cell.nextStrikeAt = t + random:NextNumber(Config.LIGHTNING_GAP_MIN, Config.LIGHTNING_GAP_MAX)
				strike(cell)
			end
		end
	end
	tickSpouts(dt, t)
	if t >= nextPublishAt then
		nextPublishAt = t + 0.25
		publish(t)
	end
end

function Storms.build(worldRefs)
	refs = worldRefs
end

function Storms.reset()
	for _, spout in ipairs(spouts) do
		removeSpout(spout)
	end
	table.clear(spouts)
	table.clear(Storms.cells)
	Sea.reset()
	nextAmbientAt = now() + Config.STORM_FIRST_DELAY
	workspace:SetAttribute("StormData", "")
	workspace:SetAttribute("SeaRough", 0)
end

return Storms

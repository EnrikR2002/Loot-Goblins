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
Storms.cells = {}

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
	end
	return cell
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

-- A cell crossing the open sea, away from home, on a heading that avoids the Hoard.
local function spawnAmbient()
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	for _ = 1, 12 do
		local x = random:NextNumber(min.X + 200, max.X - 200)
		local z = random:NextNumber(min.Z + 200, max.Z - 400)
		-- Not on top of home.
		if Vector3.new(x, 0, z - 650).Magnitude > 650 then
			local heading = random:NextNumber(0, math.pi * 2)
			local speed = random:NextNumber(Config.STORM_SPEED_MIN, Config.STORM_SPEED_MAX)
			Storms.spawn({
				x = x,
				z = z,
				r = random:NextNumber(230, 320),
				strength = random:NextNumber(0.7, 0.95),
				vx = math.cos(heading) * speed,
				vz = math.sin(heading) * speed,
				duration = random:NextNumber(85, 115),
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
				position = c.position + Vector3.new(c.velocity.X, 0, c.velocity.Z) * Config.LIGHTNING_DELAY * 0.5
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
		if ambient < 1 then
			spawnAmbient()
		end
	end
	for i = #Storms.cells, 1, -1 do
		local cell = Storms.cells[i]
		if t >= cell.endsAt then
			remove(cell)
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
	if t >= nextPublishAt then
		nextPublishAt = t + 0.25
		publish(t)
	end
end

function Storms.reset()
	table.clear(Storms.cells)
	Sea.reset()
	nextAmbientAt = now() + Config.STORM_FIRST_DELAY
	workspace:SetAttribute("StormData", "")
end

return Storms

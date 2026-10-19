-- V13.2: WORLD CHAOS. Every raid gets one of eight events (Config.CHAOS.EVENTS), chosen when the Port opens and shown
-- there before anyone picks a boat. During the raid's six minutes it plays EPISODES: one big, telegraphed, physical
-- event near goblins, then a calm, then another (Config.CHAOS.FIRST, CALM, LAST), each drawn afresh (size, count, shape,
-- place) so no two play the same.
--
--   meteors    showers of meteors (a burning ring, then a blast that throws boats sky high, tumbling)
--   kraken     tentacles rise out of the sea and SWEEP, SLAM or TOSS (bubbles first)
--   waves      rogue waves: long ridges of water rolling across the sea, part of the sea itself (shared/Sea.lua), so a
--              boat really rides, surfs or is thrown by them
--   crossfire  a rogue armada shells a patch of sea (sometimes a barrage that rolls across it)
--   barrels    fields of floating barrels, most of them powder: one spark and the field chain-reacts
--   whirls     wandering whirlpools (also part of the sea): sucked in, spun round, flung out of the eye
--   haunted    a pair of ghost portals (sail through one, come out of the other) spitting phantom ships that ram
--   thunder    giant lightning at the busiest water: a shockwave throws boats, and SUPERCHARGES them (a free boost)
--
-- Everything hits through the game's own rules: explosions are Blasts (every creature, sea mob, ship and mine already
-- reacts to those: Blast.Hit), boats are shoved through Boats.shove and dented above the world's hull floor (chaos
-- batters, it never sinks), goblins through Impact's grace (no juggling) with small damage, pursuers through
-- Pursuit.shoveAt, island creatures and the Guardian are dazed (Creatures.disturb, Threats.stagger), the Leviathan
-- recoils. Nothing happens in the Port or within CHAOS.HOME_CLEAR of the Hoard. The server sends only what clients need
-- to draw (client/ChaosFx.lua): episodes are functions of time, barrels a small snapshot a few times a second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Lobby = require(Shared:WaitForChild("Lobby"))
local Sea = require(Shared:WaitForChild("Sea"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local Blast = require(script.Parent.Blast)
local Impact = require(script.Parent.Impact)
local Loot = require(script.Parent.Loot)
local Pursuit = require(script.Parent.Pursuit)
local Leviathan = require(script.Parent.Leviathan)
local Creatures = require(script.Parent.Creatures)
local Threats = require(script.Parent.Threats)
local SeaNav = require(script.Parent.SeaNav)

local WorldChaos = {}

local X = Config.CHAOS
local BY_ID = {}
for _, entry in ipairs(X.EVENTS) do
	BY_ID[entry.id] = entry
end

local refs
local chosen = nil -- the event this (or the next) raid plays
local lastChosen = nil
local generation = 0 -- bumped on reset: delayed work from an old raid never lands
local running = false
local nextEpisodeAt = math.huge
local raidEndsAt = 0
local episode = nil -- { kind, center, radius, endsAt, ... }
local episodes = 0 -- how many this raid (for the report and tests)
local sweeps = {} -- kraken sweeps in progress
local rings = {} -- thunder shockwaves in progress
local barrels = {} -- { id, x, z, vx, vz, powder, alive, born }
local nextBarrelId = 0
local nextSnapshot = 0
local nextSlowTick = 0
local portals = nil -- { a, b, untilAt, hopAt = { [key] = t } }
local ghosts = {} -- { from, dir, speed, born, life, rammed = {} }
local armada = nil -- { center, zone, roll, untilAt, nextShot, ships }
local flungAt = setmetatable({}, { __mode = "k" }) -- boat -> when a whirlpool last flung it

local function now()
	return workspace:GetServerTimeNow()
end

local function rand(range)
	return range[1] + math.random() * (range[2] - range[1])
end

local function randInt(range)
	return math.random(range[1], range[2])
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function randomDirection()
	local a = math.random() * math.pi * 2
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- Where chaos never happens: the Port, and the water round home.
local function safe(position)
	return Lobby.inPort(position) or (refs and Util.flatDistance(position, refs.hoard.position) < X.HOME_CLEAR)
end

-- After `seconds`, unless the raid has moved on.
local function later(seconds, fn)
	local gen = generation
	task.delay(seconds, function()
		if gen == generation and running then
			fn()
		end
	end)
end

-- What every client within reach is told (client/ChaosFx.lua draws it).
local function tell(kind, payload, position)
	payload.kind = kind
	payload.event = episode and episode.kind or chosen
	if position then
		Net.broadcastNear(position, 2800, "Chaos", payload)
	else
		Net.broadcast("Chaos", payload)
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false
-- The surface at (x, z): the sea (0) or the ground's height.
local function surfaceAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -900, 0), groundParams)
	if hit then
		return math.max(hit.Position.Y, 0.5), hit.Material == Enum.Material.Water
	end
	return 0.5, true
end

local function deepAt(x, z, need)
	return SeaNav.depthAt(x, z) >= (need or 4)
end

-- Raiders out in the world (not in the Port, not still on the skyship), with whether they are at sea.
local function raiders()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		local state = player:GetAttribute("DeployState")
		if root and player:GetAttribute("InRaid") and state ~= "aboard" and state ~= "loaded" and state ~= "fuse" then
			local p = root.Position
			if p.Y < 160 and not safe(p) then
				local seated = humanoid.SeatPart ~= nil
				table.insert(list, { player = player, position = p, atSea = seated or p.Y < 6, root = root })
			end
		end
	end
	return list
end

-- Where the next episode happens: near the goblins (the busiest place, so it causes trouble between them), a little
-- off them, never in the safe places. preferSea: move it onto open water.
local function pickFocus(preferSea)
	local list = raiders()
	local center
	if #list > 0 then
		local best, bestScore = nil, -math.huge
		for _, a in ipairs(list) do
			local score = math.random() * 0.5 + ((preferSea and a.atSea) and 1.5 or 0)
			for _, b in ipairs(list) do
				if a ~= b and (a.position - b.position).Magnitude < 520 then
					score += 1
				end
			end
			if score > bestScore then
				best, bestScore = a, score
			end
		end
		center = flat(best.position) + randomDirection() * rand(X.FOCUS_JITTER)
	else
		-- Nobody out yet: somewhere in the middle of the sea.
		center = Vector3.new(math.random(-1800, 1800), 0, math.random(-1800, 900))
	end
	for _ = 1, 12 do
		if not safe(center) and (not preferSea or deepAt(center.X, center.Z, 6)) then
			break
		end
		center += randomDirection() * 140
	end
	if safe(center) then
		-- Still at home: push it out along the line from the Hoard.
		local away = flat(center - refs.hoard.position)
		away = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, -1)
		center = flat(refs.hoard.position) + away * (X.HOME_CLEAR + 200)
	end
	return center
end

-- Boats near a point (not in the safe places), with their predicted position `lead` seconds ahead.
local function boatsNear(center, radius, lead)
	local list = {}
	for _, boat in ipairs(Boats.list) do
		if boat.state == "float" and not safe(boat.hull.Position) then
			local p = boat.hull.Position
			if Util.flatDistance(p, center) <= radius then
				local v = flat(boat.hull.AssemblyLinearVelocity)
				table.insert(list, { boat = boat, at = flat(p) + v * (lead or 0) })
			end
		end
	end
	return list
end

-- Hits -------------------------------------------------------------------------------------------------------------------
-- Boats round a point: thrown out and up (falling off with distance), dented above the world's floor, maybe tumbling.
local function throwBoats(position, radius, out, up, opts)
	opts = opts or {}
	local count = 0
	for _, boat in ipairs(Boats.list) do
		local hull = boat.hull
		if boat.state == "float" and not safe(hull.Position) and boat ~= opts.except then
			local offset = flat(hull.Position - position)
			local reach = radius + boat.spec.size.Z * 0.4
			if offset.Magnitude < reach then
				local k = math.clamp(1 - offset.Magnitude / reach, 0.3, 1)
				local away = opts.direction or (offset.Magnitude > 0.5 and offset.Unit or randomDirection())
				local side = math.random() < 0.5 and -1 or 1
				local tumble = opts.tumble
					and {
						seconds = opts.tumble,
						altitude = (up * k) ^ 2 / (2 * workspace.Gravity) + 60,
						allow = opts.tumble + 3,
					}
				Boats.shove(boat, away * out * k + Vector3.new(0, up * k, 0), Vector3.new(0, side * 1.6, 0), tumble)
				if opts.hull and opts.hull > 0 then
					local floor = boat.spec.health * Config.IMPACT.HULL_FLOOR
					Boats.damage(boat, math.min(opts.hull * k, math.max(0, boat.health - floor)), opts.cause)
				end
				count += 1
			end
		end
	end
	return count
end

-- Goblins in the water or on foot round a point (not in a boat: the hull takes it), under the world's grace.
local function throwGoblins(position, radius, out, up, damage, direction)
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root and not humanoid.SeatPart and player:GetAttribute("InRaid") and not safe(root.Position) then
			local offset = flat(root.Position - position)
			if offset.Magnitude < radius and math.abs(root.Position.Y - position.Y) < 60 and Impact.open(player) then
				local k = math.clamp(1 - offset.Magnitude / radius, 0.35, 1)
				local away = direction or (offset.Magnitude > 0.5 and offset.Unit or randomDirection())
				Util.knockback(root, away * out * k + Vector3.new(0, up * k, 0), 0.25)
				if damage and damage > 0 then
					Impact.damage(humanoid, damage * k)
				end
			end
		end
	end
end

-- Everything that lives here: pursuers at sea thrown, island creatures and the Guardian dazed, the Leviathan recoils.
local function shake(position, radius, push)
	Pursuit.shoveAt(position, radius, push or 110)
	Creatures.disturb(position, radius, 2.5)
	Threats.stagger(position, radius, 1.6)
	local head = Leviathan.headPosition()
	if head and Util.flatDistance(head, position) < radius + 40 then
		Leviathan.recoil()
	end
end

-- Loose treasure thrown about (it is fun to watch the prize go flying).
local function throwLoot(position, radius, power)
	for _, item in ipairs(Loot.items) do
		if item.state == "loose" and not item.held and not item.core.Anchored then
			local offset = item.core.Position - position
			if offset.Magnitude < radius then
				local away = offset.Magnitude > 0.5 and offset.Unit or Vector3.yAxis
				item.core:ApplyImpulse((away + Vector3.new(0, 0.9, 0)) * item.core.AssemblyMass * power)
			end
		end
	end
end

-- The sea's share: rogue waves and whirlpools live in shared/Sea.lua, published here whenever one starts or ends.
local function publishSea()
	workspace:SetAttribute("ChaosSea", Sea.encodeChaos(Sea.chaos))
end

local function zone(kind, center, radius, untilAt)
	workspace:SetAttribute(
		"ChaosZone",
		string.format("%s,%.0f,%.0f,%.0f,%.1f", kind, center.X, center.Z, radius, untilAt)
	)
end

-- The feed says where (an island's name if it is near one).
local Archipelago = require(Shared:WaitForChild("Archipelago"))
local function placeName(center)
	local island = Archipelago.nearest and select(1, Archipelago.nearest(center.X, center.Z))
	if island and Util.flatDistance(Vector3.new(island.x, 0, island.z), center) < island.r + 700 then
		return "near " .. island.name
	end
	return "out at sea"
end

-- Episodes -------------------------------------------------------------------------------------------------------------
local EPISODE = {}

-- METEOR MAYHEM: one meteor.
local function meteor(at, big)
	local M = X.meteors
	local scale = big and M.bigScale or 1
	local warn = big and M.bigWarn or M.warn
	local y = surfaceAt(at.X, at.Z)
	local point = Vector3.new(at.X, y, at.Z)
	tell(
		"meteorWarn",
		{ position = point, radius = M.radius * scale, warn = warn, from = randomDirection(), big = big },
		point
	)
	later(warn, function()
		Blast.at(point, {
			radius = M.radius * scale,
			damage = M.damage * (big and 1.4 or 1),
			knockback = 95 * scale,
			breakPower = 2,
			cause = "a meteor",
			color = Color3.fromRGB(255, 140, 50),
		})
		throwBoats(point, M.launch * scale, M.out * scale, rand(M.up) * (big and 1.2 or 1), {
			tumble = big and 2.2 or 1.4,
			hull = M.hull * scale,
			cause = "a meteor",
		})
		throwGoblins(point, M.radius * scale * 1.3, 80 * scale, 70, M.damage)
		shake(point, M.launch * scale * 1.4, 130 * scale)
		throwLoot(point, M.radius * scale * 1.5, 60)
		tell("meteorHit", { position = point, radius = M.radius * scale, big = big }, point)
	end)
end

EPISODE.meteors = function(center)
	local M = X.meteors
	local spread = rand(M.spread)
	local count = randInt(M.count)
	local delay = 0
	local big = math.random() < M.bigChance
	if big then
		meteor(center, true)
		delay += M.bigWarn * 0.5
		count = math.max(3, count - 3)
	end
	local targets = boatsNear(center, spread + 120, M.warn)
	for _ = 1, count do
		local at
		if #targets > 0 and math.random() < 0.5 then
			at = targets[math.random(#targets)].at + randomDirection() * math.random(0, 30)
		else
			at = center + randomDirection() * math.sqrt(math.random()) * spread
		end
		if not safe(at) then
			later(delay, function()
				meteor(at, false)
			end)
		end
		delay += rand(M.gap)
	end
	return delay + M.warn + 1.5, spread
end

-- KRAKEN'S TANTRUM: one tentacle (sweep, slam or toss).
local function tentacle(at, kind, angle, direction)
	local K = X.kraken
	local point = Vector3.new(at.X, 0.5, at.Z)
	tell("krakenWarn", { position = point, warn = K.warn, strike = kind, angle = angle, direction = direction }, point)
	later(K.warn, function()
		local t = now()
		tell("krakenStrike", {
			position = point,
			strike = kind,
			angle = angle,
			direction = direction,
			startedAt = t,
			length = K.sweepLength,
			arc = K.sweepArc,
			time = K.sweepTime,
		}, point)
		if kind == "sweep" then
			table.insert(sweeps, {
				base = point,
				angle = angle,
				direction = direction,
				startedAt = t + 0.35, -- it rises first
				hit = {},
			})
		elseif kind == "slam" then
			later(0.55, function()
				Blast.Hit:Fire(point, K.slamRadius)
				throwBoats(point, K.slamRadius, 50, K.slamUp, { tumble = 1.5, hull = 14, cause = "the Kraken" })
				throwGoblins(point, K.slamRadius, 60, 70, 8)
				shake(point, K.slamRadius + 30, 120)
				throwLoot(point, K.slamRadius, 50)
				tell("krakenSlam", { position = point, radius = K.slamRadius }, point)
			end)
		elseif kind == "toss" then
			throwBoats(point, 26, 20, K.tossUp, { tumble = 2.2, hull = 10, cause = "the Kraken" })
			throwGoblins(point, 26, 20, 110, 6)
			shake(point, 40, 160)
		end
	end)
end

EPISODE.kraken = function(center)
	local K = X.kraken
	local area = rand(K.area)
	local strikes = randInt(K.strikes)
	local delay = 0
	for _ = 1, strikes do
		later(delay, function()
			local targets = boatsNear(center, area + 80, K.warn + 0.4)
			local target = #targets > 0 and math.random() < 0.7 and targets[math.random(#targets)] or nil
			local roll = math.random()
			local kind = roll < 0.45 and "sweep" or (roll < 0.75 and "slam" or "toss")
			if kind == "toss" and not target then
				kind = "slam"
			end
			local at = target and target.at or (center + randomDirection() * math.sqrt(math.random()) * area)
			local angle, direction = 0, 1
			if kind == "sweep" then
				-- It rises beside the target and sweeps through where it will be.
				local side = randomDirection()
				at = (target and target.at or at) + side * (K.sweepLength * 0.55)
				local toward = -side
				angle = math.atan2(toward.Z, toward.X) - K.sweepArc / 2
				direction = 1
			elseif kind == "slam" and target then
				at += randomDirection() * 12
			end
			if not safe(at) and deepAt(at.X, at.Z, 3) then
				tentacle(at, kind, angle, direction)
			end
		end)
		delay += rand(K.gap)
	end
	return delay + K.warn + 2.5, area
end

-- ROGUE WAVE RAMPAGE: walls of water rolling through.
local function wavePathSafe(start, dir, half, life, speed)
	for i = 0, 10 do
		local c = start + dir * speed * life * (i / 10)
		local across = Vector3.new(-dir.Z, 0, dir.X)
		for j = -2, 2 do
			if safe(c + across * half * (j / 2)) then
				return false
			end
		end
	end
	return true
end

EPISODE.waves = function(center)
	local W = X.waves
	local count = randInt(W.count)
	local longest = 0
	for i = 1, count do
		local speed, half = rand(W.speed), rand(W.half)
		local life = (W.start * 2) / speed
		local placed = nil
		for _ = 1, 10 do
			local dir = randomDirection()
			local start = center - dir * W.start + Vector3.new(-dir.Z, 0, dir.X) * math.random(-120, 120)
			if wavePathSafe(start, dir, half, life, speed) then
				placed = { start = start, dir = dir }
				break
			end
		end
		if placed then
			local wave = {
				x = placed.start.X,
				z = placed.start.Z,
				dx = placed.dir.X,
				dz = placed.dir.Z,
				speed = speed,
				born = now() + (i - 1) * 4,
				life = life,
				height = rand(W.height),
				width = rand(W.width),
				half = half,
			}
			table.insert(Sea.chaos.waves, wave)
			longest = math.max(longest, life + (i - 1) * 4)
			tell("wave", { wave = wave }, center)
		end
	end
	publishSea()
	return longest + 1, W.start
end

-- CANNONBALL CROSSFIRE: a rogue armada shells a patch of sea.
EPISODE.crossfire = function(center)
	local C = X.crossfire
	local time = rand(C.time)
	local zoneRadius = rand(C.zone)
	local dir = randomDirection()
	local off = center + dir * rand(C.standoff)
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local ships = {}
	for i = -1, 1 do
		table.insert(ships, off + across * i * 46)
	end
	local roll = math.random() < C.roll and across * C.rollSpeed * (math.random() < 0.5 and -1 or 1) or Vector3.zero
	local t = now()
	armada = {
		center = center,
		start = t,
		zone = zoneRadius,
		roll = roll,
		untilAt = t + time,
		nextShot = t + 2,
		ships = ships,
	}
	tell(
		"armada",
		{ ships = ships, facing = -dir, untilAt = t + time, center = center, zone = zoneRadius, roll = roll, start = t },
		center
	)
	return time + C.warn + 1, zoneRadius
end

local function tickArmada(t)
	local a = armada
	if not a then
		return
	end
	if t >= a.untilAt then
		armada = nil
		return
	end
	if t < a.nextShot then
		return
	end
	local C = X.crossfire
	a.nextShot = t + rand(C.every)
	local center = a.center + a.roll * (t - a.start)
	local target
	local targets = boatsNear(center, a.zone, C.warn + 0.2)
	if #targets > 0 and math.random() < C.aimAtBoats then
		target = targets[math.random(#targets)].at + randomDirection() * math.random(0, 16)
	else
		target = center + randomDirection() * math.sqrt(math.random()) * a.zone
	end
	if safe(target) then
		return
	end
	local y = surfaceAt(target.X, target.Z)
	local point = Vector3.new(target.X, y, target.Z)
	local ship = a.ships[math.random(#a.ships)]
	tell("shell", { from = ship + Vector3.new(0, 14, 0), to = point, time = C.warn, radius = C.radius }, point)
	later(C.warn, function()
		Blast.at(point, {
			radius = C.radius,
			damage = C.damage,
			knockback = C.knockback,
			hullDamage = C.hull,
			boatPush = C.push,
			breakPower = 1,
			cause = "the rogue armada",
			color = Color3.fromRGB(255, 170, 70),
		})
		shake(point, C.radius + 20, 100)
	end)
end

-- BARREL APOCALYPSE: a drifting field of barrels.
local function explodeBarrel(b)
	if not b.alive then
		return
	end
	b.alive = false
	local B = X.barrels
	local point = Vector3.new(b.x, 0.8, b.z)
	tell("barrelGone", { id = b.id, boom = true, position = point }, point)
	-- A Blast: it chains through the rest of the field by itself (Blast.Hit, below), and through mines, creatures, ships.
	Blast.at(point, {
		radius = B.radius,
		damage = B.damage,
		knockback = B.knockback,
		hullDamage = B.hull,
		boatPush = B.push,
		breakPower = 1,
		cause = "a powder keg",
		color = Color3.fromRGB(255, 120, 50),
	})
	throwBoats(point, B.radius, 20, 60, { tumble = 1.0 })
end

EPISODE.barrels = function(center)
	local B = X.barrels
	local spread = rand(B.spread)
	local count = randInt(B.count)
	local alive = 0
	for _, b in ipairs(barrels) do
		if b.alive then
			alive += 1
		end
	end
	count = math.min(count, B.max - alive)
	local spawned = {}
	local t = now()
	for _ = 1, count * 3 do
		if #spawned >= count then
			break
		end
		local at = center + randomDirection() * math.sqrt(math.random()) * spread
		if deepAt(at.X, at.Z, 3) and not safe(at) then
			nextBarrelId += 1
			local b = {
				id = nextBarrelId,
				x = at.X,
				z = at.Z,
				vx = 0,
				vz = 0,
				powder = math.random() < B.powder,
				alive = true,
				born = t,
			}
			table.insert(barrels, b)
			table.insert(spawned, { b.id, math.floor(b.x * 10) / 10, math.floor(b.z * 10) / 10, b.powder and 1 or 0 })
		end
	end
	tell("barrels", { list = spawned, life = B.life }, center)
	return 14, spread
end

local function tickBarrels(dt, t)
	local B = X.barrels
	local any = false
	for i = #barrels, 1, -1 do
		local b = barrels[i]
		if not b.alive or t - b.born > B.life then
			if b.alive then
				b.alive = false
				tell("barrelGone", { id = b.id }, Vector3.new(b.x, 0, b.z))
			end
			table.remove(barrels, i)
		else
			any = true
			-- Drift with the water (rogue waves and whirlpools carry them too), and slow down.
			local fx, fz = Sea.currentAt(b.x, b.z, t)
			b.vx += (fx - b.vx) * math.min(1, dt * 0.8)
			b.vz += (fz - b.vz) * math.min(1, dt * 0.8)
			b.x += b.vx * dt
			b.z += b.vz * dt
		end
	end
	if not any then
		return
	end
	-- Hulls touching barrels: a powder keg goes up; a plain barrel is knocked away.
	for _, boat in ipairs(Boats.list) do
		if boat.state == "float" then
			local p = boat.hull.Position
			local reach = boat.spec.size.Z * 0.5 + B.touch
			for _, b in ipairs(barrels) do
				if b.alive then
					local dx, dz = b.x - p.X, b.z - p.Z
					if dx * dx + dz * dz < reach * reach then
						if b.powder then
							explodeBarrel(b)
						else
							local v = flat(boat.hull.AssemblyLinearVelocity)
							local away = Vector3.new(dx, 0, dz)
							away = away.Magnitude > 0.1 and away.Unit or randomDirection()
							local kick = away * math.max(35, v.Magnitude * 0.9)
							b.vx, b.vz = kick.X, kick.Z
							b.x += away.X * 3
							b.z += away.Z * 3
						end
					end
				end
			end
		end
	end
	-- Barrels bump each other apart (a few dozen at most).
	for i = 1, #barrels do
		local a = barrels[i]
		for j = i + 1, #barrels do
			local b = barrels[j]
			local dx, dz = b.x - a.x, b.z - a.z
			local d2 = dx * dx + dz * dz
			if d2 < 16 and d2 > 0.01 then
				local d = math.sqrt(d2)
				local push = (4 - d) * 0.5 / d
				a.x -= dx * push
				a.z -= dz * push
				b.x += dx * push
				b.z += dz * push
			end
		end
	end
	if t >= nextSnapshot then
		nextSnapshot = t + B.snapshot
		local ids, xs, zs = {}, {}, {}
		local cx, cz, n = 0, 0, 0
		for _, b in ipairs(barrels) do
			if b.alive then
				table.insert(ids, b.id)
				table.insert(xs, math.floor(b.x * 10) / 10)
				table.insert(zs, math.floor(b.z * 10) / 10)
				cx += b.x
				cz += b.z
				n += 1
			end
		end
		if n > 0 then
			tell("barrelsAt", { ids = ids, xs = xs, zs = zs }, Vector3.new(cx / n, 0, cz / n))
		end
	end
end

-- WHIRLPOOL OUTBREAK: wandering whirlpools, part of the sea.
EPISODE.whirls = function(center)
	local H = X.whirls
	local count = randInt(H.count)
	local longest = 0
	local t = now()
	for i = 1, count do
		for _ = 1, 8 do
			local at = center + randomDirection() * (i == 1 and 0 or rand(H.spread))
			local life = rand(H.life)
			local wander = randomDirection() * rand(H.wander)
			local r = rand(H.radius)
			if deepAt(at.X, at.Z, 5) and not safe(at) and not safe(at + wander * life) then
				table.insert(Sea.chaos.whirls, {
					x = at.X,
					z = at.Z,
					vx = wander.X,
					vz = wander.Z,
					born = t + (i - 1) * 1.5,
					life = life,
					r = r,
					spin = rand(H.spin),
					pull = rand(H.pull),
					dip = rand(H.dip),
				})
				longest = math.max(longest, life + (i - 1) * 1.5)
				break
			end
		end
	end
	publishSea()
	tell("whirls", { center = center }, center)
	return longest + 1, 400
end

local function whirlCenter(wh, t)
	local age = t - wh.born
	return Vector3.new(wh.x + wh.vx * age, 0, wh.z + wh.vz * age), age
end

local function tickWhirls(t, slow)
	local H = X.whirls
	for _, wh in ipairs(Sea.chaos.whirls) do
		local center, age = whirlCenter(wh, t)
		if age >= 0 and age <= wh.life then
			-- Boats in the eye are FLUNG out (the swirl itself is the sea's: BoatSim feels it).
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and t - (flungAt[boat] or -math.huge) > H.flingRest then
					local offset = flat(boat.hull.Position - center)
					if offset.Magnitude < wh.r * H.eye then
						flungAt[boat] = t
						local out = offset.Magnitude > 0.5 and offset.Unit or randomDirection()
						local tangent = Vector3.new(-out.Z, 0, out.X)
						local dir = (tangent * 0.8 + out * 0.6).Unit
						Boats.shove(boat, dir * H.fling + Vector3.new(0, H.flingUp, 0), Vector3.new(0, 2.4, 0), {
							seconds = 1.3,
							altitude = 90,
							allow = 4,
						})
						tell("fling", { position = boat.hull.Position }, boat.hull.Position)
					end
				end
			end
			if slow then
				-- Swimmers are dragged round and in; pursuers churned about; loose treasure too.
				for _, player in ipairs(Players:GetPlayers()) do
					local root, humanoid = Util.aliveRoot(player)
					if root and not humanoid.SeatPart and root.Position.Y < Config.WATER_ROOT_Y + 2 then
						local offset = flat(root.Position - center)
						if offset.Magnitude < wh.r and offset.Magnitude > 0.5 then
							local out = offset.Unit
							local tangent = Vector3.new(-out.Z, 0, out.X)
							local eye = offset.Magnitude < wh.r * H.eye
							Util.knockback(
								root,
								eye and Vector3.new(0, 70, 0) + tangent * 50 or (tangent * 34 - out * 18),
								0.2
							)
						end
					end
				end
				Pursuit.shoveAt(center, wh.r, 28)
				throwLoot(center, wh.r, 6)
			end
		end
	end
end

-- HAUNTED SEAS: two ghost portals and their phantom ships.
local function waterNear(point, tries)
	for _ = 1, tries do
		if deepAt(point.X, point.Z, 6) and not safe(point) then
			return point
		end
		point += randomDirection() * 120
	end
	return nil
end

EPISODE.haunted = function(center)
	local G = X.haunted
	local a = waterNear(center, 10)
	if not a then
		return 2, 100
	end
	local b
	for _ = 1, 12 do
		b = waterNear(a + randomDirection() * rand(G.pairDistance), 6)
		if b then
			break
		end
	end
	if not b then
		return 2, 100
	end
	local time = rand(G.time)
	local t = now()
	portals = { a = a, b = b, untilAt = t + time, hopAt = {}, nextShipAt = { t + 1.5, t + 3 } }
	tell("portals", { a = a, b = b, untilAt = t + time, radius = G.portalRadius }, center)
	tell("portals", { a = a, b = b, untilAt = t + time, radius = G.portalRadius }, b)
	return time + 1, (b - a).Magnitude / 2 + 200
end

local function spawnGhost(from, t)
	local G = X.haunted
	local targets = boatsNear(from, 600, 1)
	local dir
	if #targets > 0 then
		dir = flat(targets[math.random(#targets)].at - from)
		dir = dir.Magnitude > 1 and dir.Unit or randomDirection()
	else
		dir = randomDirection()
	end
	local ghost =
		{ from = from, dir = dir, speed = G.shipSpeed, born = t, life = G.shipLife, rammed = {}, volleyAt = t + 1.5 }
	table.insert(ghosts, ghost)
	tell("ghostShip", { from = from, dir = dir, speed = ghost.speed, born = t, life = ghost.life }, from)
end

local function tickHaunted(t)
	local G = X.haunted
	local p = portals
	if p then
		if t >= p.untilAt then
			portals = nil
			tell("portalsGone", {}, p.a)
		else
			for i, at in ipairs({ p.a, p.b }) do
				if t >= p.nextShipAt[i] then
					p.nextShipAt[i] = t + rand(G.shipEvery)
					spawnGhost(at, t)
				end
			end
			-- Through a portal: out of its twin, at the same speed, the same way.
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and t - (p.hopAt[boat] or -math.huge) > 3 then
					local hull = boat.hull
					for i, at in ipairs({ p.a, p.b }) do
						if Util.flatDistance(hull.Position, at) < G.portalRadius * 0.85 then
							local other = i == 1 and p.b or p.a
							local v = hull.AssemblyLinearVelocity
							local heading = flat(v).Magnitude > 4 and flat(v).Unit or flat(hull.CFrame.LookVector).Unit
							local exit = other + heading * (G.portalRadius + boat.spec.size.Z * 0.6 + 6)
							p.hopAt[boat] = t
							Boats.place(boat, CFrame.new(exit.X, hull.Position.Y, exit.Z) * hull.CFrame.Rotation)
							hull.AssemblyLinearVelocity = v
							boat.impactGraceUntil = math.max(boat.impactGraceUntil, t + 1.5)
							tell("portalHop", { from = at, to = exit }, at)
							tell("portalHop", { from = at, to = exit }, exit)
							break
						end
					end
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local root, humanoid = Util.aliveRoot(player)
				if root and not humanoid.SeatPart and t - (p.hopAt[player] or -math.huge) > 3 then
					for i, at in ipairs({ p.a, p.b }) do
						if Util.flatDistance(root.Position, at) < G.portalRadius * 0.8 and root.Position.Y < 30 then
							local other = i == 1 and p.b or p.a
							p.hopAt[player] = t
							local v = root.AssemblyLinearVelocity
							local heading = flat(v).Magnitude > 2 and flat(v).Unit or randomDirection()
							player.Character:PivotTo(
								CFrame.new(other + heading * (G.portalRadius + 8) + Vector3.new(0, 4, 0))
							)
							tell("portalHop", { from = at, to = other }, other)
							break
						end
					end
				end
			end
		end
	end
	for i = #ghosts, 1, -1 do
		local g = ghosts[i]
		local age = t - g.born
		if age > g.life then
			table.remove(ghosts, i)
		else
			local at = g.from + g.dir * g.speed * age
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and not g.rammed[boat] and not safe(boat.hull.Position) then
					local offset = flat(boat.hull.Position - at)
					if offset.Magnitude < G.ram + boat.spec.size.X then
						g.rammed[boat] = true
						local side = Vector3.new(-g.dir.Z, 0, g.dir.X)
						side *= offset:Dot(side) >= 0 and 1 or -1
						Boats.shove(
							boat,
							side * G.ramPush + g.dir * 40 + Vector3.new(0, 40, 0),
							Vector3.new(0, 1.8, 0),
							{
								seconds = 0.9,
								altitude = 60,
								allow = 3,
							}
						)
						Boats.damage(
							boat,
							math.min(10, math.max(0, boat.health - boat.spec.health * Config.IMPACT.HULL_FLOOR)),
							"a phantom ship"
						)
						tell("ghostRam", { position = boat.hull.Position }, boat.hull.Position)
					end
				end
			end
			Pursuit.shoveAt(at, 30, 60, g.dir)
			if t >= g.volleyAt then
				g.volleyAt = t + G.volleyEvery
				local targets = boatsNear(at, G.volleyRange, 1.2)
				if #targets > 0 then
					local target = targets[math.random(#targets)].at
					Blast.strike(Vector3.new(target.X, 0.5, target.Z), 1.2, {
						radius = 18,
						damage = 4,
						knockback = 60,
						hullDamage = 8,
						boatPush = 60,
						cause = "a phantom cannon",
						color = Color3.fromRGB(120, 255, 190),
						markerColor = Color3.fromRGB(120, 255, 190),
					})
				end
			end
		end
	end
end

-- THUNDERSTRUCK: giant lightning at the busiest water, and its shockwave.
local function strike(center, area)
	local T = X.thunder
	-- The busiest water: the boat with the most boats round it (ties broken by chance).
	local list = boatsNear(center, area + 120, T.warn)
	local at
	if #list > 0 then
		local best, bestScore = nil, -1
		for _, a in ipairs(list) do
			local score = math.random() * 0.5
			for _, b in ipairs(list) do
				if a ~= b and (a.at - b.at).Magnitude < 160 then
					score += 1
				end
			end
			if score > bestScore then
				best, bestScore = a, score
			end
		end
		at = best.at
	else
		at = center + randomDirection() * math.sqrt(math.random()) * area
	end
	if safe(at) then
		return
	end
	local y = surfaceAt(at.X, at.Z)
	local point = Vector3.new(at.X, y, at.Z)
	tell("boltWarn", { position = point, warn = T.warn, ring = T.ring }, point)
	later(T.warn, function()
		local t = now()
		Blast.at(point, {
			radius = 20,
			damage = T.damage,
			knockback = 70,
			bolt = true,
			breakPower = 1,
			cause = "a lightning strike",
			color = Color3.fromRGB(200, 220, 255),
		})
		table.insert(rings, { center = point, startedAt = t, hit = {} })
		-- The bolt jumps between boats packed close together.
		local struck = boatsNear(point, 26, 0)
		local chain = {}
		local from = struck[1] and struck[1].boat
		local jumps = 0
		while from and jumps < T.chainMax do
			chain[from] = true
			local nextBoat, nextGap = nil, T.chain
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and not chain[boat] then
					local gap = (boat.hull.Position - from.hull.Position).Magnitude
					if gap < nextGap then
						nextBoat, nextGap = boat, gap
					end
				end
			end
			if nextBoat then
				tell("chainBolt", { from = from.hull.Position, to = nextBoat.hull.Position }, point)
				Boats.shove(nextBoat, Vector3.new(0, T.lift, 0), Vector3.new(0, 1.2, 0))
				jumps += 1
			end
			from = nextBoat
		end
		tell("bolt", { position = point, ring = T.ring, ringTime = T.ringTime, startedAt = t }, point)
		shake(point, 60, 80)
	end)
end

EPISODE.thunder = function(center)
	local T = X.thunder
	local area = rand(T.area)
	local strikes = randInt(T.strikes)
	local delay = 0
	for _ = 1, strikes do
		later(delay, function()
			strike(center, area)
		end)
		delay += rand(T.gap)
	end
	local duration = delay + T.warn + T.ringTime + 1
	tell("thunderSky", { center = center, radius = area + 200, time = duration }, center)
	return duration, area
end

local function tickRings(t)
	local T = X.thunder
	for i = #rings, 1, -1 do
		local ring = rings[i]
		local k = (t - ring.startedAt) / T.ringTime
		if k > 1 then
			table.remove(rings, i)
		else
			local radius = T.ring * k
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and not ring.hit[boat] and not safe(boat.hull.Position) then
					local d = Util.flatDistance(boat.hull.Position, ring.center)
					if d <= radius + 8 then
						ring.hit[boat] = true
						local away = flat(boat.hull.Position - ring.center)
						away = away.Magnitude > 0.5 and away.Unit or randomDirection()
						local fade = 1 - k * 0.5
						Boats.shove(boat, away * T.push * fade + Vector3.new(0, T.lift * fade, 0), Vector3.new(0, 1, 0))
						Boats.damage(
							boat,
							math.min(
								T.hull * fade,
								math.max(0, boat.health - boat.spec.health * Config.IMPACT.HULL_FLOOR)
							),
							"a lightning strike"
						)
						-- SUPERCHARGED: the jolt hands the boat a free boost.
						boat.boostUntil = math.max(boat.boostUntil, t + T.charge)
						boat.model:SetAttribute("BoostEndsAt", boat.boostUntil)
						tell("supercharge", { position = boat.hull.Position, hull = boat.hull }, boat.hull.Position)
					end
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local root, humanoid = Util.aliveRoot(player)
				if root and not humanoid.SeatPart and not ring.hit[player] and not safe(root.Position) then
					local d = Util.flatDistance(root.Position, ring.center)
					if d <= radius + 6 and math.abs(root.Position.Y - ring.center.Y) < 40 then
						ring.hit[player] = true
						if Impact.open(player) then
							local away = flat(root.Position - ring.center)
							away = away.Magnitude > 0.5 and away.Unit or randomDirection()
							Util.knockback(root, away * 70 + Vector3.new(0, 40, 0), 0.22)
							Impact.damage(humanoid, T.damage)
						end
					end
				end
			end
		end
	end
end

-- Kraken sweeps, step by step.
local function tickSweeps(t)
	local K = X.kraken
	for i = #sweeps, 1, -1 do
		local s = sweeps[i]
		local k = (t - s.startedAt) / K.sweepTime
		if k > 1 then
			table.remove(sweeps, i)
		elseif k >= 0 then
			local angle = s.angle + K.sweepArc * k * s.direction
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tangent = Vector3.new(-dir.Z, 0, dir.X) * s.direction
			local tip = s.base + dir * K.sweepLength
			local function nearSegment(p, extra)
				local rel = flat(p - s.base)
				local along = math.clamp(rel:Dot(dir), 0, K.sweepLength)
				return (rel - dir * along).Magnitude < K.width + extra
			end
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and not s.hit[boat] and not safe(boat.hull.Position) then
					if nearSegment(boat.hull.Position, boat.spec.size.X * 0.5) then
						s.hit[boat] = true
						Boats.shove(
							boat,
							tangent * K.swat + Vector3.new(0, K.lift, 0),
							Vector3.new(0, 2.2 * s.direction, 0),
							{
								seconds = 1.2,
								altitude = 70,
								allow = 3,
							}
						)
						Boats.damage(
							boat,
							math.min(12, math.max(0, boat.health - boat.spec.health * Config.IMPACT.HULL_FLOOR)),
							"the Kraken"
						)
						tell("krakenSwat", { position = boat.hull.Position }, boat.hull.Position)
					end
				end
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local root, humanoid = Util.aliveRoot(player)
				if root and not humanoid.SeatPart and not s.hit[player] and root.Position.Y < 20 then
					if nearSegment(root.Position, 2) and Impact.open(player) then
						s.hit[player] = true
						Util.knockback(root, tangent * 80 + Vector3.new(0, 55, 0), 0.25)
						Impact.damage(humanoid, 8)
					end
				end
			end
			if not s.pursuers and k > 0.5 then
				s.pursuers = true
				Pursuit.shoveAt((s.base + tip) / 2, K.sweepLength * 0.6, 120, tangent)
			end
		end
	end
end

-- Rogue waves carry swimmers and pursuers along on their faces (boats ride them through the sea itself).
local function tickWaves(t)
	local W = X.waves
	for _, w in ipairs(Sea.chaos.waves) do
		local age = t - w.born
		if age >= 0 and age <= w.life then
			local dir = Vector3.new(w.dx, 0, w.dz)
			local crest = Vector3.new(w.x, 0, w.z) + dir * w.speed * age
			for _, player in ipairs(Players:GetPlayers()) do
				local root, humanoid = Util.aliveRoot(player)
				if root and not humanoid.SeatPart and root.Position.Y < Config.WATER_ROOT_Y + 6 then
					local rel = flat(root.Position - crest)
					local along = rel:Dot(dir)
					local across = math.abs(rel:Dot(Vector3.new(-dir.Z, 0, dir.X)))
					if math.abs(along) < w.width and across < w.half then
						Util.knockback(root, dir * W.push + Vector3.new(0, W.lift, 0), 0.2)
					end
				end
			end
			local across = Vector3.new(-dir.Z, 0, dir.X)
			for j = -2, 2 do
				Pursuit.shoveAt(crest + across * w.half * (j / 2.5), w.width + 20, 40, dir)
			end
			throwLoot(crest, w.width * 1.5, 8)
		end
	end
end

-- The sea's events end: take them out of it.
local function pruneSea(t)
	local changed = false
	for i = #Sea.chaos.waves, 1, -1 do
		local w = Sea.chaos.waves[i]
		if t - w.born > w.life then
			table.remove(Sea.chaos.waves, i)
			changed = true
		end
	end
	for i = #Sea.chaos.whirls, 1, -1 do
		local wh = Sea.chaos.whirls[i]
		if t - wh.born > wh.life then
			table.remove(Sea.chaos.whirls, i)
			changed = true
		end
	end
	if changed then
		publishSea()
	end
end

-- The schedule ------------------------------------------------------------------------------------------------------------
local function startEpisode(kind, center)
	local fn = EPISODE[kind]
	if not fn then
		return
	end
	local t = now()
	episodes += 1
	episode = { kind = kind, center = center, startedAt = t }
	local duration, radius = fn(center)
	episode.endsAt = t + duration
	episode.radius = radius
	zone(kind, center, radius, episode.endsAt)
	local def = BY_ID[kind]
	tell("episode", { center = center, radius = radius, untilAt = episode.endsAt, name = def.name, icon = def.icon })
	Net.feed(string.format("%s %s %s!", def.icon, def.name, placeName(center)), Color3.fromRGB(255, 170, 90))
	nextEpisodeAt = episode.endsAt + rand(X.CALM)
end

-- In the Port: choose the next raid's event (never the same twice running) and show it.
function WorldChaos.choose(id)
	if id and BY_ID[id] then
		chosen = id
	else
		local pool = {}
		for _, entry in ipairs(X.EVENTS) do
			if entry.id ~= lastChosen then
				table.insert(pool, entry.id)
			end
		end
		chosen = pool[math.random(#pool)]
	end
	lastChosen = chosen
	local def = BY_ID[chosen]
	workspace:SetAttribute("ChaosNext", chosen)
	workspace:SetAttribute("ChaosName", def.name)
	workspace:SetAttribute("ChaosIcon", def.icon)
	workspace:SetAttribute("ChaosLine", def.line)
	return chosen
end

-- The raid's clock starts at clockAt and ends at endsAt: episodes from a little after the start until near the end.
function WorldChaos.start(clockAt, endsAt)
	if not chosen then
		WorldChaos.choose()
	end
	running = true
	raidEndsAt = endsAt
	episodes = 0
	nextEpisodeAt = clockAt + rand(X.FIRST)
	workspace:SetAttribute("ChaosEvent", chosen)
end

function WorldChaos.tick(dt)
	if not running then
		return
	end
	local t = now()
	if t >= nextEpisodeAt and t < raidEndsAt - X.LAST and (not episode or t >= episode.endsAt) then
		startEpisode(chosen, pickFocus(chosen ~= "meteors" and chosen ~= "thunder"))
	end
	if episode and t >= episode.endsAt and workspace:GetAttribute("ChaosZone") then
		workspace:SetAttribute("ChaosZone", nil)
	end
	tickSweeps(t)
	tickRings(t)
	tickArmada(t)
	tickHaunted(t)
	tickWhirls(t, false)
	if t >= nextSlowTick then
		local slowDt = math.max(dt, t - (nextSlowTick - 0.1))
		nextSlowTick = t + 0.1
		tickBarrels(math.min(slowDt, 0.25), t)
		tickWhirls(t, true)
		tickWaves(t)
		pruneSea(t)
	end
end

function WorldChaos.reset()
	generation += 1
	running = false
	episode = nil
	nextEpisodeAt = math.huge
	table.clear(sweeps)
	table.clear(rings)
	table.clear(ghosts)
	portals = nil
	armada = nil
	for _, b in ipairs(barrels) do
		b.alive = false
	end
	table.clear(barrels)
	Sea.setChaos(nil)
	workspace:SetAttribute("ChaosSea", nil)
	workspace:SetAttribute("ChaosZone", nil)
	workspace:SetAttribute("ChaosEvent", nil)
	Net.broadcast("Chaos", { kind = "reset" })
end

function WorldChaos.init(worldRefs)
	refs = worldRefs
	groundParams.FilterDescendantsInstances = { workspace.Terrain, refs.folders.ground, refs.folders.structures }
	-- Anything that goes bang near a powder keg sets it off: a cannonball, a meteor, a keg, another barrel (a chain).
	Blast.Hit:Connect(function(position, radius)
		local reach = radius + 6
		for _, b in ipairs(barrels) do
			if b.alive and b.powder then
				local dx, dz = b.x - position.X, b.z - position.Z
				if dx * dx + dz * dz < reach * reach and math.abs(position.Y) < 40 then
					later(X.barrels.chainDelay * (0.6 + math.random() * 0.8), function()
						explodeBarrel(b)
					end)
				end
			end
		end
	end)
	RunService.Heartbeat:Connect(WorldChaos.tick)
end

-- For tests and the Studio playtest hook ------------------------------------------------------------------------------
-- Play an episode of `kind` now, at `center` (or where it would choose).
function WorldChaos.force(kind, center)
	if not BY_ID[kind] then
		return false
	end
	chosen = kind
	running = true
	raidEndsAt = math.max(raidEndsAt, now() + 120)
	startEpisode(kind, center or pickFocus(kind ~= "meteors" and kind ~= "thunder"))
	return true
end

function WorldChaos.inspect()
	local alive = 0
	for _, b in ipairs(barrels) do
		if b.alive then
			alive += 1
		end
	end
	return {
		chosen = chosen,
		running = running,
		episodes = episodes,
		episode = episode and { kind = episode.kind, center = episode.center, endsAt = episode.endsAt },
		nextAt = nextEpisodeAt,
		waves = #Sea.chaos.waves,
		whirls = #Sea.chaos.whirls,
		barrels = alive,
		ghosts = #ghosts,
		portals = portals ~= nil,
		sweeps = #sweeps,
		rings = #rings,
	}
end

return WorldChaos

-- Tornadoes (V9): rideable waterspouts that wander the open sea in any weather.
--
-- They are not part of the storms (Storms.lua still has its own spouts inside its cells). Up to
-- Config.TWISTER.MAX at once, each in one of the sea's "alleys" (Config.TWISTER.ALLEYS: open water on the
-- routes goblins sail, far from any shore and from home), wandering slowly for a minute or two and then
-- dying away. Half of them form near a goblin who is out at sea, so they are met, not just seen.
--
-- What a tornado does is in shared/Twister.lua, so every machine agrees:
--   * a BOAT is lifted by whoever simulates it (BoatSim.step: the driver's client, or the server); its
--     driver can bail out with the jump key; the anti-cheat allows the height and the throw (Boats.police)
--   * a GOBLIN on foot or swimming is thrown into the skydive from here (Flight.launch), so the glide,
--     the dive and the three water skips all work; fall back into the funnel and it throws you again
--   * a PURSUER (Pursuit.lua) is lifted and spun like a boat, and cannot strike while it is up there
-- This module only decides where they are, publishes them (workspace.TwisterData) and throws goblins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Twister = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Twister"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local SeaNav = require(script.Parent.SeaNav)
local Flight = require(script.Parent.Flight)

local Tornadoes = {}

local T = Config.TWISTER
local random = Random.new()
local list = {} -- the live tornadoes (Twister's records, plus our own fields)
local refs
local nextSpawnAt = math.huge
local nextPublishAt = 0
local nextGoblinCheck = 0
local serial = 0
local thrownAt = {} -- player -> time
local dirty = false

local function now()
	return workspace:GetServerTimeNow()
end

local function publish(t)
	for _, tw in ipairs(list) do
		-- Re-anchor each record at the present, so a client extrapolates from a fresh sample.
		local x, z = Twister.positionOf(tw, t)
		tw.x, tw.z, tw.t = x, z, t
	end
	Twister.set(list)
	workspace:SetAttribute("TwisterData", Twister.encode())
	dirty = false
end

local function deepEnough(x, z)
	return SeaNav.depthAt(x, z) > 10
end

-- A free alley, preferring the one nearest a goblin who is out at sea.
local function pickAlley()
	local used = {}
	for _, tw in ipairs(list) do
		used[tw.alley] = true
	end
	local free = {}
	for index in ipairs(T.ALLEYS) do
		if not used[index] then
			table.insert(free, index)
		end
	end
	if #free == 0 then
		return nil
	end
	if random:NextNumber() < 0.5 then
		local sailors = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local root = Util.aliveRoot(player)
			if root and root.Position.Y < 30 and SeaNav.depthAt(root.Position.X, root.Position.Z) > 4 then
				table.insert(sailors, root.Position)
			end
		end
		if #sailors > 0 then
			local at = sailors[random:NextInteger(1, #sailors)]
			local best, bestDistance
			for _, index in ipairs(free) do
				local alley = T.ALLEYS[index]
				local distance = math.sqrt((alley[1] - at.X) ^ 2 + (alley[2] - at.Z) ^ 2)
				if not bestDistance or distance < bestDistance then
					best, bestDistance = index, distance
				end
			end
			return best
		end
	end
	return free[random:NextInteger(1, #free)]
end

local function spawnOne(t, alleyIndex, at)
	alleyIndex = alleyIndex or pickAlley()
	if not alleyIndex then
		return nil
	end
	local alley = T.ALLEYS[alleyIndex]
	local x, z
	if at then
		x, z = at.X, at.Z
	else
		for _ = 1, 12 do
			local a, r = random:NextNumber(0, math.pi * 2), random:NextNumber(0, T.WANDER * 0.5)
			local cx, cz = alley[1] + math.cos(a) * r, alley[2] + math.sin(a) * r
			if deepEnough(cx, cz) then
				x, z = cx, cz
				break
			end
		end
	end
	if not x then
		return nil
	end
	local hoard = refs.hoard.position
	if not at and math.sqrt((x - hoard.X) ^ 2 + (z - hoard.Z) ^ 2) < T.HOME_CLEAR then
		return nil
	end
	serial += 1
	local heading = random:NextNumber(0, math.pi * 2)
	local speed = random:NextNumber(T.SPEED[1], T.SPEED[2])
	local tw = {
		id = serial,
		alley = alleyIndex,
		name = alley[3],
		x = x,
		z = z,
		vx = math.cos(heading) * speed,
		vz = math.sin(heading) * speed,
		t = t,
		born = t,
		dies = t + T.FADE + random:NextNumber(T.LIFE[1], T.LIFE[2]),
		heading = heading,
		speed = speed,
		nextTurnAt = t + 1,
	}
	table.insert(list, tw)
	dirty = true
	Net.feed(
		"A TORNADO is spinning up over " .. alley[3] .. "! Ride it, or steer clear.",
		Color3.fromRGB(200, 230, 255)
	)
	Net.broadcastNear(Vector3.new(x, 0, z), 2600, "TwisterBorn", { position = Vector3.new(x, 0, z) })
	return tw
end

-- Wander: drift on, turn a little now and then, keep to the alley and off the shallows.
local function steer(tw, t)
	if t < tw.nextTurnAt then
		return
	end
	tw.nextTurnAt = t + 1
	local x, z = Twister.positionOf(tw, t)
	local alley = T.ALLEYS[tw.alley]
	tw.heading += random:NextNumber(-0.35, 0.35)
	local home = Vector3.new(alley[1] - x, 0, alley[2] - z)
	if home.Magnitude > T.WANDER then
		tw.heading = math.atan2(home.Z, home.X) + random:NextNumber(-0.4, 0.4)
	end
	local ahead = Vector3.new(x + math.cos(tw.heading) * 90, 0, z + math.sin(tw.heading) * 90)
	if not deepEnough(ahead.X, ahead.Z) then
		tw.heading += math.pi * random:NextNumber(0.6, 1.0)
	end
	tw.x, tw.z, tw.t = x, z, t
	tw.vx, tw.vz = math.cos(tw.heading) * tw.speed, math.sin(tw.heading) * tw.speed
	dirty = true
end

-- Goblins on foot or swimming: thrown into the skydive.
local function throwGoblins(t)
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root and not humanoid.SeatPart and t - (thrownAt[player] or -math.huge) > T.GOBLIN_REHIT then
			local phase = Flight.phaseOf(player)
			local position = root.Position
			if (phase == nil or phase == "diving") and position.Y < T.GOBLIN_LOW then
				local tw, offset = Twister.find(position, t)
				local strength = tw and Twister.strength(tw, t) or 0
				if tw and strength > 0.4 and offset.Magnitude < Twister.radiusAt(position.Y) then
					thrownAt[player] = t
					local out = offset.Magnitude > 0.5 and offset.Unit or Vector3.new(1, 0, 0)
					local around = Vector3.new(-out.Z, 0, out.X)
					local velocity = Vector3.new(tw.vx, T.GOBLIN_UP, tw.vz) + around * T.GOBLIN_SWIRL - out * 8
					Flight.launch(player, velocity, nil)
					Net.broadcastNear(position, 900, "TwisterThrow", { position = position, userId = player.UserId })
					Net.toast(player, "WHOOSH! Hold SPACE to glide, SHIFT to dive.")
				end
			end
		end
	end
end

function Tornadoes.tick(dt, active)
	local t = now()
	if not refs then
		return
	end
	for index = #list, 1, -1 do
		local tw = list[index]
		if t > tw.dies then
			table.remove(list, index)
			dirty = true
			nextSpawnAt = math.min(nextSpawnAt, t + random:NextNumber(T.GAP[1], T.GAP[2]))
		else
			steer(tw, t)
		end
	end
	if active and t >= nextSpawnAt and #list < T.MAX then
		spawnOne(t)
		nextSpawnAt = #list < T.MAX and t + random:NextNumber(T.GAP[1], T.GAP[2]) or math.huge
	end
	if t >= nextGoblinCheck then
		nextGoblinCheck = t + 0.1
		throwGoblins(t)
	end
	if dirty or t >= nextPublishAt then
		nextPublishAt = t + 2
		publish(t)
	end
	local _ = dt
end

function Tornadoes.build(worldRefs)
	refs = worldRefs
	Tornadoes.reset()
end

-- A raid starts or ends: clear the sea, and the first one forms FIRST seconds into the next raid.
function Tornadoes.reset()
	table.clear(list)
	table.clear(thrownAt)
	nextSpawnAt = now() + T.FIRST
	publish(now())
end

function Tornadoes.forget(player)
	thrownAt[player] = nil
end

-- For tests: a tornado at a point (in the nearest alley's name), lasting `seconds`.
function Tornadoes.force(position, seconds)
	local t = now()
	local best, bestDistance = 1, math.huge
	for index, alley in ipairs(T.ALLEYS) do
		local distance = math.sqrt((alley[1] - position.X) ^ 2 + (alley[2] - position.Z) ^ 2)
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	local tw = spawnOne(t, best, position)
	if tw and seconds then
		tw.dies = t + seconds
		tw.born = t - T.FADE -- at full strength at once
	end
	if tw then
		tw.vx, tw.vz, tw.speed = 0, 0, 0
	end
	publish(t)
	return tw
end

function Tornadoes.list()
	return list
end

return Tornadoes

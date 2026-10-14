-- Sea mobs (V8): the ordinary things that live in the open water. Three kinds, each with one trick,
-- each with an answer, none of them able to sink a boat or take a treasure:
--   NIBBLERS  a school of small fish that chases a passing boat and latches onto its hull, gnawing and
--             dragging. They cannot hold a boat that leaves the water: JUMP and they fall off. (They also
--             give up after a few seconds, and an explosion scatters them.)
--   PUFFERS   a fat spiny fish that floats and does nothing at all, until a boat runs into it: then it
--             blows up like a balloon and BOUNCES the boat into the air. No harm done; a free jump for a
--             driver who aims for one (over a reef, a patrol ship, a pursuer), a surprise for one who
--             does not. It needs a few seconds to puff up again.
--   LANCERS   a swordfish that marks a straight LINE across the water and, a second later, goes down it
--             like a thrown spear, knocking aside whatever is on it. Leave the line (or jump it).
-- Where: each region of the sea has its own mix (REGIONS below), there are none in Home Bay or in the
-- Navy's waters, and none within sight of an island's shore, so there are quiet stretches by design.
--
-- Cost: a mob that nobody is near does nothing at all (no per-frame work, a body that does not move).
-- A sweep four times a second wakes the ones with an occupied boat in range; only those are stepped.
-- The count is fixed at build time (Config.SEA_MOBS), whatever the number of players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Sea = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Sea"))
local Net = require(script.Parent.Net)
local Boats = require(script.Parent.Boats)
local SeaNav = require(script.Parent.SeaNav)
local Blast = require(script.Parent.Blast)
local Creatures = require(script.Parent.Creatures)
local Pursuit = require(script.Parent.Pursuit)

local SeaMobs = {}

local M = Config.SEA_MOBS

local mobs = {}
local nextSweep = 0
local hoard

-- What swims where. Regions are Archipelago.regions, by name.
local REGIONS = {
	["THE CROSSING"] = { puffer = 3, nibbler = 1 },
	["WESTERN SHALLOWS"] = { nibbler = 3, puffer = 1 },
	["EASTERN REACH"] = { lancer = 2, puffer = 2 },
	["THE OPEN SEA"] = { puffer = 3, lancer = 2 },
	["THE FAR NORTH"] = { nibbler = 2, lancer = 2 },
	["THE CINDERS"] = { puffer = 2, lancer = 1, nibbler = 1 },
	-- HOME BAY and NAVY WATERS: nothing. Home is safe; the Navy is trouble enough.
}

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function ball(name, size, offset, color, material, transparency)
	return { name, Vector3.new(size, size, size), offset, color, material, Enum.PartType.Ball, transparency }
end

local function block(name, size, offset, color, material, transparency)
	return { name, size, offset, color, material, nil, transparency }
end

local SILVER = Color3.fromRGB(170, 200, 215)
local PUFF = Color3.fromRGB(255, 205, 90)
local STEEL = Color3.fromRGB(70, 110, 160)

local BODIES = {
	nibbler = {
		block("Core", Vector3.new(1, 1, 1), nil, SILVER, Enum.Material.SmoothPlastic, 1),
		block(
			"FinA",
			Vector3.new(0.4, 2.2, 2.6),
			CFrame.new(0, 0.6, -3) * CFrame.Angles(math.rad(-25), 0, 0),
			SILVER,
			Enum.Material.SmoothPlastic
		),
		block(
			"FinB",
			Vector3.new(0.4, 1.8, 2.2),
			CFrame.new(-3, 0.4, -0.5) * CFrame.Angles(math.rad(-25), 0, 0),
			SILVER,
			Enum.Material.SmoothPlastic
		),
		block(
			"FinC",
			Vector3.new(0.4, 2, 2.4),
			CFrame.new(3, 0.5, 0) * CFrame.Angles(math.rad(-25), 0, 0),
			SILVER,
			Enum.Material.SmoothPlastic
		),
		block(
			"FinD",
			Vector3.new(0.4, 1.7, 2),
			CFrame.new(-1.5, 0.4, 3) * CFrame.Angles(math.rad(-25), 0, 0),
			SILVER,
			Enum.Material.SmoothPlastic
		),
		block(
			"FinE",
			Vector3.new(0.4, 1.9, 2.2),
			CFrame.new(2, 0.4, 3.4) * CFrame.Angles(math.rad(-25), 0, 0),
			SILVER,
			Enum.Material.SmoothPlastic
		),
		ball("Froth", 7, CFrame.new(0, -3.2, 0), Color3.fromRGB(235, 245, 255), Enum.Material.Foil, 0.55),
	},
	puffer = {
		ball("Body", 7, nil, PUFF, Enum.Material.SmoothPlastic),
		ball("Belly", 6.2, CFrame.new(0, -0.8, 0), Color3.fromRGB(255, 245, 220), Enum.Material.SmoothPlastic),
		ball("EyeL", 1.4, CFrame.new(-2, 1.4, -2.6), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic),
		ball("EyeR", 1.4, CFrame.new(2, 1.4, -2.6), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic),
		block(
			"SpikeA",
			Vector3.new(0.6, 3, 0.6),
			CFrame.new(0, 4, 0),
			Color3.fromRGB(190, 120, 50),
			Enum.Material.SmoothPlastic
		),
		block(
			"SpikeB",
			Vector3.new(3, 0.6, 0.6),
			CFrame.new(4, 0.5, 0),
			Color3.fromRGB(190, 120, 50),
			Enum.Material.SmoothPlastic
		),
		block(
			"SpikeC",
			Vector3.new(3, 0.6, 0.6),
			CFrame.new(-4, 0.5, 0),
			Color3.fromRGB(190, 120, 50),
			Enum.Material.SmoothPlastic
		),
		block(
			"SpikeD",
			Vector3.new(0.6, 0.6, 3),
			CFrame.new(0, 0.5, 4),
			Color3.fromRGB(190, 120, 50),
			Enum.Material.SmoothPlastic
		),
	},
	lancer = {
		block("Body", Vector3.new(2.6, 2.8, 12), nil, STEEL, Enum.Material.Slate),
		block(
			"Sword",
			Vector3.new(0.5, 0.5, 8),
			CFrame.new(0, 0.2, -10),
			Color3.fromRGB(225, 232, 240),
			Enum.Material.Metal
		),
		block(
			"Sail",
			Vector3.new(0.4, 4.4, 7),
			CFrame.new(0, 3.2, 0.5),
			Color3.fromRGB(110, 170, 230),
			Enum.Material.Neon,
			0.25
		),
		block("Tail", Vector3.new(0.4, 4.2, 2.4), CFrame.new(0, 0.4, 7), STEEL, Enum.Material.Slate),
	},
}

local RIDE = { nibbler = 0.2, puffer = 0.6, lancer = -0.4 }

local function occupied(boat)
	return boat.state == "float" and not boat.ai and Boats.occupied(boat)
end

-- The nearest occupied boat to a point within `range`, and how far.
local function nearestBoat(position, range)
	local best, bestDistance = nil, range
	for _, boat in ipairs(Boats.list) do
		if occupied(boat) then
			local distance = flat(boat.hull.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = boat, distance
			end
		end
	end
	return best, bestDistance
end

local function crew(boat)
	local seat = boat.driver
	local humanoid = seat and seat.Occupant
	local character = humanoid and humanoid.Parent
	return character and game:GetService("Players"):GetPlayerFromCharacter(character) or nil
end

local function goHome(mob)
	mob.state = "idle"
	mob.target = nil
	mob.position = mob.home
	mob.heading = Vector3.new(0, 0, -1)
	Pursuit.place(mob, RIDE[mob.kind])
end

-- Nibblers ----------------------------------------------------------------------------------------------
local function tickNibbler(mob, dt, t)
	local boat = mob.target
	if not boat or not occupied(boat) or t > mob.untilAt then
		goHome(mob)
		mob.sleepUntil = t + M.NIBBLER_REST
		return
	end
	local hull = boat.hull
	if mob.state == "chase" then
		Pursuit.swim(mob, hull.Position, M.NIBBLER_SPEED, dt, 4)
		if flat(hull.Position - mob.position).Magnitude < boat.spec.size.Z * 0.5 + 4 then
			mob.state = "latched"
			mob.untilAt = t + M.NIBBLER_HOLD
			mob.biteAt = t
			local player = crew(boat)
			if player then
				Net.toast(player, "NIBBLERS ON THE HULL! Jump (SPACE) to shake them off!")
			end
			Pursuit.fx("nibble", mob.position)
		elseif flat(mob.position - mob.home).Magnitude > M.LEASH then
			mob.untilAt = 0
		end
	else
		-- On the hull: they go where it goes, until it leaves the water.
		local wave = Sea.waveAt(hull.Position.X, hull.Position.Z, t)
		if hull.Position.Y - wave > 6.5 then
			local player = crew(boat)
			if player then
				Net.toast(player, "Shook the nibblers off!")
			end
			Pursuit.fx("splash", mob.position)
			mob.untilAt = 0
			return
		end
		mob.position = flat(hull.Position)
		mob.heading = flat(hull.CFrame.LookVector)
		if t >= mob.biteAt then
			mob.biteAt = t + 0.5
			Pursuit.batter(boat, M.NIBBLER_BITE, "nibblers")
			Boats.shove(boat, -flat(hull.AssemblyLinearVelocity) * 0.14)
		end
	end
	Pursuit.place(mob, RIDE.nibbler)
end

-- Puffers -----------------------------------------------------------------------------------------------
local function tickPuffer(mob, _dt, t)
	if t < (mob.readyAt or 0) then
		-- deflating: it sits low and small
		if t > mob.readyAt - 0.3 then
			Pursuit.place(mob, RIDE.puffer)
		end
		return
	end
	for _, boat in ipairs(Boats.list) do
		if boat.state == "float" and not boat.ai then
			local hull = boat.hull
			local reach = boat.spec.size.Z * 0.5 + 5
			if flat(hull.Position - mob.position).Magnitude < reach and hull.Position.Y < 9 then
				mob.readyAt = t + M.PUFFER_REST
				local v = flat(hull.AssemblyLinearVelocity)
				local along = v.Magnitude > 8 and v.Unit or flat(hull.CFrame.LookVector)
				Boats.shove(boat, along * M.PUFFER_PUSH + Vector3.new(0, M.PUFFER_LIFT, 0))
				Pursuit.fx("boing", mob.position)
				local player = crew(boat)
				if player then
					Net.toast(player, "BOING! A puffer fish. (Aim for them: it is a free jump.)")
				end
				-- puffed up for a moment, then small and low while it gets its breath back
				Pursuit.place(mob, 3, CFrame.new(0, 2, 0))
				task.delay(0.6, function()
					if mob.root.Parent then
						Pursuit.place(mob, -1.6)
					end
				end)
				return
			end
		end
	end
end

-- Lancers -----------------------------------------------------------------------------------------------
local function tickLancer(mob, dt, t)
	if mob.state == "aim" then
		if t >= mob.untilAt then
			mob.state = "charge"
			mob.untilAt = t + M.LANCER_RUN / M.LANCER_SPEED
			mob.struck = {}
			Pursuit.fx("lance", mob.position)
		end
	elseif mob.state == "charge" then
		mob.position += mob.heading * M.LANCER_SPEED * dt
		for _, boat in ipairs(Boats.list) do
			if occupied(boat) and not mob.struck[boat] then
				local offset = flat(boat.hull.Position - mob.position)
				if offset.Magnitude < boat.spec.size.Z * 0.45 + 6 and boat.hull.Position.Y < 8 then
					mob.struck[boat] = true
					local side = offset:Cross(mob.heading).Y >= 0 and 1 or -1
					local across = Vector3.new(-mob.heading.Z, 0, mob.heading.X) * side
					Boats.shove(boat, across * M.LANCER_PUSH + Vector3.new(0, 24, 0), Vector3.new(0, 2.6 * side, 0))
					Pursuit.batter(boat, M.LANCER_HULL, "a lancer")
					local player = crew(boat)
					if player then
						Pursuit.hit(
							player,
							mob.position,
							{ reason = "lancer", text = "SPEARED BY A LANCER! (It runs a straight line: get off it.)" }
						)
					end
					Pursuit.fx("crash", boat.hull.Position)
				end
			end
		end
		local probe = mob.position + mob.heading * 16
		if t >= mob.untilAt or not SeaNav.passable(probe.X, probe.Z, 1) then
			mob.state = "away"
			mob.untilAt = t + 2.5
		end
	elseif mob.state == "away" then
		-- It sounds, and comes back to its beat later.
		if t >= mob.untilAt then
			goHome(mob)
			mob.sleepUntil = t + M.LANCER_REST
			return
		end
	end
	Pursuit.place(mob, mob.state == "away" and -6 or RIDE.lancer)
end

local function wake(mob, boat, distance, t)
	if mob.kind == "nibbler" then
		mob.state = "chase"
		mob.target = boat
		mob.untilAt = t + M.NIBBLER_CHASE
	elseif mob.kind == "lancer" then
		if distance < 60 then
			return -- too close to line up: it lets this one go
		end
		local lead = flat(boat.hull.Position) + flat(boat.hull.AssemblyLinearVelocity) * (M.LANCER_TELL + 0.4)
		local direction = flat(lead - mob.position)
		if direction.Magnitude < 1 then
			return
		end
		mob.heading = direction.Unit
		mob.state = "aim"
		mob.untilAt = t + M.LANCER_TELL
		-- The line: a row of marks down the way it will go.
		for i = 1, 7 do
			local at = mob.position + mob.heading * (i * M.LANCER_RUN / 7)
			Creatures.mark(Vector3.new(at.X, 0.5, at.Z), 7, M.LANCER_TELL, Color3.fromRGB(110, 170, 230))
		end
		Pursuit.place(mob, 1.5, CFrame.Angles(math.rad(12), 0, 0))
	end
end

-- Running them ----------------------------------------------------------------------------------------------
function SeaMobs.tick(dt)
	local t = now()
	dt = math.min(dt, 0.1)
	if t >= nextSweep then
		nextSweep = t + 0.25
		for _, mob in ipairs(mobs) do
			if mob.kind == "puffer" then
				local _, distance = nearestBoat(mob.position, 60)
				mob.near = distance < 60
			elseif mob.state == "idle" and t >= (mob.sleepUntil or 0) then
				local range = mob.kind == "nibbler" and M.NIBBLER_SIGHT or M.LANCER_SIGHT
				local boat, distance = nearestBoat(mob.position, range)
				if boat then
					wake(mob, boat, distance, t)
				end
			end
		end
	end
	for _, mob in ipairs(mobs) do
		if mob.kind == "puffer" then
			if mob.near then
				tickPuffer(mob, dt, t)
			end
		elseif mob.state ~= "idle" then
			if mob.kind == "nibbler" then
				tickNibbler(mob, dt, t)
			else
				tickLancer(mob, dt, t)
			end
		end
	end
end

-- An explosion scatters the nibblers and sends a lancer under.
local function onBlast(position, radius)
	local t = now()
	for _, mob in ipairs(mobs) do
		if mob.state ~= "idle" and mob.kind ~= "puffer" and flat(mob.position - position).Magnitude <= radius + 14 then
			Pursuit.fx("splash", mob.position)
			goHome(mob)
			mob.sleepUntil = t + 20
		end
	end
end

-- A spot of open water for a mob: deep, away from every shore, away from home.
local function spotNear(center, random)
	for _ = 1, 40 do
		local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(80, M.SPREAD)
		local x, z = center.x + math.cos(angle) * distance, center.z + math.sin(angle) * distance
		local ok = SeaNav.passable(x, z, 4)
			and Vector3.new(x - hoard.X, 0, z - hoard.Z).Magnitude > M.HOME_CLEAR
			and x > Config.BOUNDS_MIN.X + 150
			and x < Config.BOUNDS_MAX.X - 150
			and z > Config.BOUNDS_MIN.Z + 150
			and z < Config.BOUNDS_MAX.Z - 150
		if ok then
			for _, island in ipairs(Archipelago.islands) do
				if Vector3.new(x - island.x, 0, z - island.z).Magnitude < island.r + M.SHORE_CLEAR then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, other in ipairs(mobs) do
				if Vector3.new(x - other.home.X, 0, z - other.home.Z).Magnitude < 150 then
					ok = false
					break
				end
			end
		end
		if ok then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

function SeaMobs.build(worldRefs)
	hoard = worldRefs.hoard.position
	local random = Random.new(8088) -- the same sea every raid: players can learn where the puffers are
	local names = {}
	for name in pairs(REGIONS) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local region
		for _, candidate in ipairs(Archipelago.regions) do
			if candidate.name == name then
				region = candidate
			end
		end
		for _, kind in ipairs({ "lancer", "nibbler", "puffer" }) do
			for _ = 1, region and REGIONS[name][kind] or 0 do
				local spot = spotNear(region, random)
				if spot then
					local model, root = Pursuit.body(
						kind == "nibbler" and "Nibblers" or (kind == "puffer" and "Puffer" or "Lancer"),
						BODIES[kind]
					)
					local mob = {
						kind = kind,
						region = name,
						home = spot,
						position = spot,
						heading = Vector3.new(0, 0, -1),
						model = model,
						root = root,
						state = "idle",
						draft = 1,
					}
					table.insert(mobs, mob)
					Pursuit.place(mob, RIDE[kind])
				end
			end
		end
	end
	Blast.Hit:Connect(onBlast)
end

function SeaMobs.reset()
	for _, mob in ipairs(mobs) do
		goHome(mob)
		mob.sleepUntil = nil
		mob.readyAt = nil
	end
end

-- For tests and the report.
function SeaMobs.list()
	return mobs
end

return SeaMobs

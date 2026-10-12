-- The Goblin Navy: patrol ships that hunt carriers across the sea. They are physics boats like
-- the players' (Boats.lua, BoatSim.lua) driven by an AI that follows routes from the sea
-- navigation grid.
--
-- They do not simply follow you. Each ship has a job:
--   hunter    sails for where you WILL be (an intercept), shells you on the way in, and when
--             it gets close and lined up it sounds a horn and rams
--   blocker   sails for the water between you and the Hoard and drops a chain of mines
--             across the way home, then turns hunter when you reach it
-- And they do not always come from behind: when the fort is far away, ships appear on the
-- horizon on the side you are sailing home through.
--
-- What makes them a puzzle instead of a stat check:
--   * They sit deep. The same grid that routes them marks shallow channels and reef gaps as
--     impassable to them, so a skiff that slips through leaves them behind.
--   * They need to SEE you. Line of sight and a sight range (shorter in a storm) decide whether they
--     chase or search; break contact behind an island and they go to your last position and give up.
--   * They are fast in a straight line (faster than a cutter or a laden skiff) but wide in a
--     turn. A ram is announced; a hard turn or a drift makes it miss.
--   * Their guns are marked: each shell is a closing ring on the water. Up close they fire a
--     spread along your course, so holding a straight line is what gets you hit.
--   * Mines are bright, sit still and go off for anyone, the Navy included.
--   * They can be sunk. Cannons (the Cutter's, Fort Barnacle's) wreck them in a few hits, and so
--     can a barrel, lightning, or their own mines.
--
-- Escalation sends them out as Heat rises; Troubles sends them when the Admiral's strongbox
-- or the Skull Chalice is taken. Fort Barnacle is the base; the Ghost Fleet comes from the sea.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Sea = require(script.Parent.Sea)
local SeaNav = require(script.Parent.SeaNav)
local Boats = require(script.Parent.Boats)
local Blast = require(script.Parent.Blast)
local Loot = require(script.Parent.Loot)
local Storms = require(script.Parent.Storms)

local Navy = {}
Navy.ships = {}
Navy.mines = {}

local refs
local random = Random.new()
local lastDispatchAt = -math.huge

local NAVY_RED = Color3.fromRGB(255, 120, 100)

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true
losParams.RespectCanCollide = true

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function clearLine(from, to)
	local ignore = { refs.folders.fx, refs.folders.loot, refs.folders.bodies, refs.folders.threats, refs.folders.decor }
	for _, boat in ipairs(Boats.list) do
		table.insert(ignore, boat.model)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	losParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(from, to - from, losParams) == nil
end

local function nearestBase(position)
	local best, bestDistance
	for _, base in ipairs(refs.navyBases) do
		local distance = (base.position - position).Magnitude
		if not bestDistance or distance < bestDistance then
			best, bestDistance = base, distance
		end
	end
	return best, bestDistance
end

local function inWard(position)
	return (flat(position) - flat(refs.hoard.position)).Magnitude <= Config.WARD_RADIUS
end

-- Open, deep water on the horizon, on the side the thief is sailing home through. Returns a
-- CFrame facing them, or nil if nothing suitable was found.
local function horizonSpawn(position)
	local draft = Config.BOAT_TYPES.navy.draft
	local toHome = flat(refs.hoard.position - position)
	local homeAngle = toHome.Magnitude > 1 and math.atan2(toHome.Z, toHome.X) or random:NextNumber(0, math.pi * 2)
	local min, max = Config.BOUNDS_MIN, Config.BOUNDS_MAX
	for attempt = 1, 24 do
		-- Ahead of them first, and in plain sight, so the ship is something the thief sees
		-- coming and it can start the chase at once. If the way home is all islands, anywhere.
		local ahead = attempt <= 10
		local inSight = attempt <= 18
		local spread = ahead and math.rad(70) or math.pi
		local angle = homeAngle + random:NextNumber(-spread, spread)
		local distance = random:NextNumber(Config.NAVY_SPAWN_MIN, Config.NAVY_SPAWN_MAX)
		local x, z = position.X + math.cos(angle) * distance, position.Z + math.sin(angle) * distance
		local open = x > min.X + 120 and x < max.X - 120 and z > min.Z + 120 and z < max.Z - 120
		if open then
			-- Room to sail, not a pond between reefs.
			for _, offset in ipairs({ { 0, 0 }, { 60, 0 }, { -60, 0 }, { 0, 60 }, { 0, -60 } }) do
				open = open and SeaNav.passable(x + offset[1], z + offset[2], draft)
			end
		end
		local spot = Vector3.new(x, 0, z)
		if
			open
			and (spot - flat(refs.hoard.position)).Magnitude > Config.WARD_RADIUS + 300
			and (not inSight or clearLine(spot + Vector3.new(0, 8, 0), position + Vector3.new(0, 2, 0)))
		then
			return CFrame.lookAt(spot, flat(position))
		end
	end
	return nil
end

local function makeGhost(boat)
	for _, part in ipairs(boat.model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Hull" and part.Name ~= "BowSkid" then
			part.Transparency = math.max(part.Transparency, 0.45)
		end
	end
	boat.hull.Transparency = 0.4
	boat.hull.Color = Color3.fromRGB(90, 190, 190)
	boat.model:SetAttribute("Ghost", true)
	boat.model.Name = "GhostShip"
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(110, 255, 210)
	glow.Range = 40
	glow.Brightness = 2
	glow.Parent = boat.hull
end

-- role: "hunter" or "blocker".
local function spawnShip(spawnCFrame, ghost, hunted, role)
	local boat = Boats.spawnAI("navy", spawnCFrame)
	if ghost then
		makeGhost(boat)
		boat.spec = table.clone(boat.spec)
		boat.spec.maxSpeed *= 1.1
		boat.spec.accel *= 1.1
		boat.spec.health = 300
		boat.health = 300
		boat.model:SetAttribute("Health", 300)
		boat.model:SetAttribute("MaxHealth", 300)
	end
	local t = now()
	local ship = {
		boat = boat,
		ghost = ghost,
		role = role or "hunter",
		target = nil,
		targetVelocity = Vector3.zero,
		lastSeenAt = -math.huge,
		lastSeenPos = nil,
		route = nil,
		routeIndex = 1,
		routeAt = -math.huge,
		routeGoal = nil,
		nextFireAt = t + Config.NAVY_FIRST_SHOT_DELAY,
		nextRamAt = t + Config.NAVY_FIRST_RAM_DELAY,
		ramUntil = 0,
		ramPoint = nil, -- A far point along the bearing a charge was aimed on.
		peelUntil = 0,
		side = #Navy.ships % 2 == 0 and 1 or -1,
		nextMineAt = t + 4,
		minesLaid = 0,
		stuckSince = nil,
		reverseUntil = 0,
		leaving = false,
		leavingSince = nil,
		bornAt = t,
		base = nil,
	}
	if not ghost then
		ship.base = nearestBase(spawnCFrame.Position)
	end
	-- Sent after someone: head for where they were when the alarm sounded, and look from there.
	if hunted then
		local root = Util.aliveRoot(hunted)
		if root then
			ship.lastSeenPos = root.Position
			ship.lastSeenAt = t
		end
	end
	table.insert(Navy.ships, ship)
	return ship
end

local function patrolCount()
	local count = 0
	for _, ship in ipairs(Navy.ships) do
		if not ship.ghost then
			count += 1
		end
	end
	return count
end

-- Send patrol ships after a carrier. Returns how many set out.
function Navy.dispatch(targetPlayer, count, force)
	local t = now()
	if not force and t - lastDispatchAt < Config.NAVY_DISPATCH_GAP then
		return 0
	end
	local root = Util.aliveRoot(targetPlayer)
	if not root then
		return 0
	end
	local base, baseDistance = nearestBase(root.Position)
	local fromBase = base ~= nil and baseDistance < Config.NAVY_BASE_RANGE
	local sent = 0
	local seenAt = nil
	for i = 1, count do
		if patrolCount() >= Config.NAVY_MAX then
			break
		end
		local spawn = nil
		if not fromBase then
			spawn = horizonSpawn(root.Position)
			seenAt = seenAt or (spawn and spawn.Position)
		end
		if not spawn and base then
			spawn = base.spawns[(i - 1) % #base.spawns + 1]
		end
		if spawn then
			-- Every second ship goes for the way home instead of for the thief.
			spawnShip(spawn, false, targetPlayer, patrolCount() % 2 == 1 and "blocker" or "hunter")
			sent += 1
		end
	end
	if sent > 0 then
		lastDispatchAt = t
		if seenAt then
			local direction = Storms.compassName(seenAt.X - root.Position.X, seenAt.Z - root.Position.Z)
			Net.message("PATROL SHIP ON THE HORIZON, " .. direction .. " OF THE THIEF!", 3.5, NAVY_RED)
			Net.feed(sent .. " patrol ship" .. (sent > 1 and "s" or "") .. " closing in from the open sea!", NAVY_RED)
			Net.broadcast("NavySpawn", { position = seenAt })
		elseif base then
			Net.message("THE NAVY HAS BEEN ALERTED! PATROL SHIPS ARE SAILING OUT", 3.5, NAVY_RED)
			Net.feed(sent .. " patrol ship" .. (sent > 1 and "s" or "") .. " launched from Fort Barnacle!", NAVY_RED)
			Net.broadcast("NavySpawn", { position = base.position })
		end
	end
	return sent
end

-- The Ghost Fleet: ships from the fog, not from the fort.
function Navy.dispatchGhosts(spawns, count, hunted)
	local sent = 0
	for i = 1, count do
		if #Navy.ships >= Config.NAVY_MAX + 2 then
			break
		end
		spawnShip(spawns[(i - 1) % #spawns + 1], true, hunted, "hunter")
		sent += 1
	end
	if sent > 0 then
		Net.message("GHOST SHIPS RISE FROM THE FOG!", 3.5, Color3.fromRGB(120, 255, 210))
	end
	return sent
end

function Navy.standDown()
	for _, ship in ipairs(Navy.ships) do
		if not ship.ghost then
			ship.leaving = true
		end
	end
end

-- Patrol ships out right now (ghost ships are not Heat's doing and do not count).
function Navy.count()
	return patrolCount()
end

local function dropShip(ship, remove)
	for i, other in ipairs(Navy.ships) do
		if other == ship then
			table.remove(Navy.ships, i)
			break
		end
	end
	if remove and ship.boat.state ~= "gone" then
		Boats.remove(ship.boat)
	end
end

-- Mines ------------------------------------------------------------------------------------
-- A blocker's answer to a boat it cannot outrun: a chain of floating mines across the way
-- home. They are easy to see, they never move, and they go off for any hull or swimmer.
local function removeMine(mine)
	for i, other in ipairs(Navy.mines) do
		if other == mine then
			table.remove(Navy.mines, i)
			break
		end
	end
	mine.part:Destroy()
end

local function explodeMine(mine)
	local position = mine.position
	removeMine(mine)
	Blast.at(position, {
		radius = Config.MINE_RADIUS,
		damage = Config.MINE_DAMAGE,
		knockback = 80,
		hullDamage = Config.MINE_HULL_DAMAGE,
		boatPush = 70,
		lootReason = "cannon",
		cause = "a mine",
		color = Color3.fromRGB(255, 90, 60),
	})
end

local function dropMine(ship, position)
	while #Navy.mines >= Config.MINE_MAX do
		removeMine(Navy.mines[1])
	end
	local at = Vector3.new(position.X, 0.9, position.Z)
	local ball = Instance.new("Part")
	ball.Name = "Mine"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(5, 5, 5)
	ball.Color = Color3.fromRGB(45, 42, 50)
	ball.Material = Enum.Material.Metal
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CFrame = CFrame.new(at)
	local lamp = Instance.new("Part")
	lamp.Name = "MineLamp"
	lamp.Shape = Enum.PartType.Ball
	lamp.Size = Vector3.new(2.2, 2.2, 2.2)
	lamp.Color = Color3.fromRGB(255, 60, 50)
	lamp.Material = Enum.Material.Neon
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanTouch = false
	lamp.CanQuery = false
	lamp.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
	lamp.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = lamp.Color
	light.Range = 22
	light.Brightness = 2
	light.Parent = lamp
	-- A tall thin beacon, so a mine is readable from a fast boat well before it matters.
	local beacon = Instance.new("Part")
	beacon.Name = "MineBeacon"
	beacon.Size = Vector3.new(0.5, 26, 0.5)
	beacon.Color = lamp.Color
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.45
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanTouch = false
	beacon.CanQuery = false
	beacon.CFrame = CFrame.new(at + Vector3.new(0, 15, 0))
	beacon.Parent = ball
	ball.Parent = refs.folders.fx
	local t = now()
	table.insert(Navy.mines, {
		part = ball,
		position = at,
		owner = ship.boat,
		armedAt = t + Config.MINE_ARM_TIME,
		expiresAt = t + Config.MINE_LIFETIME,
	})
	ship.minesLaid += 1
	if ship.minesLaid == 1 then
		Net.feed("A patrol ship is laying MINES across the way home! Steer around the red lights.", NAVY_RED)
	end
end

local function tickMines(t)
	for _, mine in ipairs(table.clone(Navy.mines)) do
		if t >= mine.expiresAt then
			removeMine(mine)
		elseif t >= mine.armedAt then
			local position = mine.position
			local tripped = false
			for _, boat in ipairs(Boats.list) do
				if boat.state == "float" and not boat.asleep then
					local offset = boat.hull.Position - position
					-- The ship that laid it gets a head start to clear its own wake.
					local own = boat == mine.owner and t < mine.armedAt + 3
					if
						not own
						and math.abs(offset.Y) < 9
						and flat(offset).Magnitude < Config.MINE_TRIGGER + boat.spec.size.X * 0.5
					then
						tripped = true
						break
					end
				end
			end
			if not tripped then
				for _, player in ipairs(Players:GetPlayers()) do
					local root = Util.aliveRoot(player)
					if root and (root.Position - position).Magnitude < Config.MINE_TRIGGER then
						tripped = true
						break
					end
				end
			end
			if tripped then
				explodeMine(mine)
			end
		end
	end
end

-- Targets -----------------------------------------------------------------------------------
-- The most valuable carrier this ship can see.
local function pickTarget(position)
	local sight = Config.NAVY_SIGHT
	if Sea.stormAt(position.X, position.Z) > 0.3 then
		sight *= 0.6
	end
	local best, bestValue, bestDistance
	for _, carrier in ipairs(Loot.carriers()) do
		local to = carrier.root.Position
		local distance = (flat(to) - flat(position)).Magnitude
		-- The Hoard's ward is a safe harbor: carriers inside it are out of reach.
		if
			not inWard(to)
			and distance < sight
			and clearLine(position + Vector3.new(0, 8, 0), to + Vector3.new(0, 2, 0))
		then
			local value = carrier.item.def.value
			if not best or value > bestValue or (value == bestValue and distance < bestDistance) then
				best, bestValue, bestDistance = carrier, value, distance
			end
		end
	end
	return best
end

local function steerToward(ship, goal)
	local boat = ship.boat
	local cf = boat.hull.CFrame
	local forward = flat(cf.LookVector)
	forward = forward.Magnitude > 0.05 and forward.Unit or Vector3.new(0, 0, -1)
	local desired = flat(goal - cf.Position)
	if desired.Magnitude < 1 then
		return 0, 0, 0
	end
	desired = desired.Unit
	-- Whiskers: if water ahead is too shallow or land, bias away from that side. They reach
	-- farther the faster the ship goes (it needs the room to turn), and a nearer one checks
	-- for anything it is about to hit.
	local avoid = 0
	local blocked = false
	local draft = boat.spec.draft
	local speed = flat(boat.hull.AssemblyLinearVelocity).Magnitude
	local reach = math.max(110, speed * 1.5)
	for _, offset in ipairs({ -0.5, 0, 0.5 }) do
		local probeDir = (CFrame.Angles(0, offset, 0) * forward)
		local probe = cf.Position + probeDir * reach
		local near = cf.Position + probeDir * (reach * 0.5)
		if not SeaNav.passable(probe.X, probe.Z, draft) or not SeaNav.passable(near.X, near.Z, draft) then
			avoid += (offset == 0) and 1.2 or -offset * 1.4
			blocked = true
		end
	end
	local cross = forward:Cross(desired).Y -- positive: the goal is to the left
	local dot = forward:Dot(desired)
	local steer = -math.clamp(cross * 2.4 + avoid * 0.6, -1, 1)
	if dot < 0 then
		steer = cross >= 0 and -1 or 1
	end
	-- Slow for a hard turn, and for land ahead: a ship at full speed turns too wide to come
	-- about or to clear a headland.
	local throttle = dot > 0.5 and 1 or 0.45
	if blocked then
		throttle = math.min(throttle, speed > 55 and 0.1 or 0.5)
	end
	return throttle, steer, dot
end

local function fireShell(ship, aim, delay)
	local hull = ship.boat.hull
	local landing = Vector3.new(aim.X, math.max(aim.Y - 2, 0), aim.Z)
	local muzzle = hull.Position + hull.CFrame.LookVector * 12 + Vector3.new(0, 8, 0)
	Net.broadcast("Shell", { from = muzzle, to = landing, duration = delay })
	Blast.strike(landing, delay, {
		radius = 12,
		damage = Config.NAVY_SHELL_DAMAGE,
		knockback = 72,
		hullDamage = Config.NAVY_SHELL_HULL_DAMAGE,
		boatPush = 58,
		lootReason = "cannon",
		cause = ship.ghost and "a ghost ship" or "the Navy",
		exceptBoat = ship.boat,
		markerColor = Color3.fromRGB(255, 80, 60),
		color = Color3.fromRGB(255, 150, 80),
	})
end

local function tickShip(ship, t)
	local boat = ship.boat
	local hull = boat.hull
	local position = hull.Position
	local input = boat.input

	-- See someone?
	local carrier = pickTarget(position)
	if carrier then
		ship.target = carrier.player
		ship.lastSeenAt = t
		ship.lastSeenPos = carrier.root.Position
		ship.targetVelocity = flat(carrier.root.AssemblyLinearVelocity)
	end

	local goal
	local engaged = false
	local ramming = t < ship.ramUntil
	local afloat = false -- The thief is in a boat (something a ship can reach and ram).
	local distance = math.huge
	if ship.leaving then
		ship.leavingSince = ship.leavingSince or t
		goal = ship.base and ship.base.position
	elseif carrier then
		engaged = true
		local targetPos = carrier.root.Position
		local velocity = ship.targetVelocity
		distance = (flat(targetPos) - flat(position)).Magnitude
		local humanoid = carrier.player.Character and carrier.player.Character:FindFirstChildOfClass("Humanoid")
		afloat = humanoid ~= nil and humanoid.SeatPart ~= nil
		if ship.role == "blocker" and distance > Config.NAVY_BLOCK_RELEASE and not ramming then
			-- Get between the thief and the Hoard, and stay there.
			local toHome = flat(refs.hoard.position - targetPos)
			local ahead = math.min(Config.NAVY_BLOCK_AHEAD, math.max(toHome.Magnitude - (Config.WARD_RADIUS + 110), 0))
			goal = targetPos + (toHome.Magnitude > 1 and toHome.Unit * ahead or Vector3.zero)
		else
			-- Intercept: sail for where they will be when we get there, not where they are.
			local closing = math.max(flat(hull.AssemblyLinearVelocity).Magnitude, 40)
			local lead = math.clamp(distance / closing, 0, Config.NAVY_LEAD_MAX)
			goal = targetPos + velocity * lead * 0.8
		end
		-- Which side this ship keeps the thief on when it is not charging.
		local across = velocity.Magnitude > 8 and velocity.Unit or flat(targetPos - position)
		across = across.Magnitude > 0.1 and Vector3.new(-across.Z, 0, across.X).Unit * ship.side or Vector3.xAxis
		-- Close, lined up, and they are in a boat: sound the horn and run them down. The charge
		-- is a commitment: it is aimed where the thief will be IF THEY HOLD THEIR COURSE, and the
		-- ship does not correct it. Turn after the horn and it thunders past.
		if afloat and not ramming and t >= ship.nextRamAt and distance < Config.NAVY_RAM_RANGE then
			local toTarget = flat(targetPos - position)
			local look = flat(hull.CFrame.LookVector)
			if toTarget.Magnitude > 1 and look.Magnitude > 0.05 and look.Unit:Dot(toTarget.Unit) > 0.55 then
				local closing = math.max(flat(hull.AssemblyLinearVelocity).Magnitude + 25, 60)
				local impact = flat(targetPos + velocity * (distance / closing) - position)
				ship.ramPoint = flat(position) + (impact.Magnitude > 1 and impact.Unit or look.Unit) * 700
				ship.ramUntil = t + Config.NAVY_RAM_TIME
				ship.nextRamAt = t + Config.NAVY_RAM_GAP
				ship.peelUntil = ship.ramUntil + Config.NAVY_PEEL_TIME
				ramming = true
				Net.broadcast("NavyRam", { position = position, userId = carrier.player.UserId })
			end
		end
		if ramming then
			goal = ship.ramPoint
		elseif t < ship.peelUntil then
			-- The charge is spent: swing out wide and come about, guns still firing.
			goal = targetPos + across * Config.NAVY_PEEL_DISTANCE
		elseif
			afloat
			and distance < Config.NAVY_STATION * 1.4
			and t < ship.nextRamAt - 2
			and (ship.role == "hunter" or distance <= Config.NAVY_BLOCK_RELEASE)
		then
			-- Run alongside at gun range, not on their stern, until the next charge is nearly
			-- ready; then the intercept above turns it in and lines it up.
			goal = targetPos + velocity * 1.2 + across * Config.NAVY_STATION
		end
	elseif ship.lastSeenPos and t - ship.lastSeenAt < Config.NAVY_SEARCH_TIME then
		goal = ship.lastSeenPos
	else
		-- Lost them: head for home and give up.
		ship.leaving = true
		ship.leavingSince = ship.leavingSince or t
		goal = ship.base and ship.base.position
	end
	if not goal then
		-- A ghost with nothing to chase fades away.
		if t - ship.lastSeenAt > Config.NAVY_SEARCH_TIME then
			dropShip(ship, true)
		end
		input.throttle, input.steer, input.boost = 0, 0, false
		return
	end

	-- Route: replan now and then, or when the goal has moved a long way.
	if t - ship.routeAt > Config.NAVY_REPLAN or not ship.routeGoal or (ship.routeGoal - goal).Magnitude > 120 then
		ship.routeAt = t
		ship.routeGoal = goal
		ship.route = SeaNav.path(position, goal, boat.spec.draft, Config.NAVY_COAST_WEIGHT)
		ship.routeIndex = 2
	end
	local waypoint = goal
	if ship.route and not ramming then
		while ship.route[ship.routeIndex] and (flat(ship.route[ship.routeIndex] - position)).Magnitude < 45 do
			ship.routeIndex += 1
		end
		waypoint = ship.route[ship.routeIndex] or goal
	end

	local throttle, steer = steerToward(ship, waypoint)
	if ramming then
		throttle = 1 -- A charge does not slow for the turn.
	end
	local distanceToGoal = (flat(goal) - flat(position)).Magnitude
	if engaged and not afloat and distance < Config.NAVY_STANDOFF then
		-- The thief is ashore: hold at gun range, and back water if they come too close.
		throttle = distance < Config.NAVY_STANDOFF * 0.55 and -0.8 or 0
	elseif engaged and ship.role == "blocker" and not ramming and distanceToGoal < 60 then
		throttle = 0.25 -- On station across the way home: keep steerage, do not sail off.
	end
	if ship.leaving and (distanceToGoal < 70 or t - ship.leavingSince > Config.NAVY_LEAVE_TIME) then
		dropShip(ship, true)
		return
	end

	-- Stuck? Back off.
	local speed = flat(hull.AssemblyLinearVelocity).Magnitude
	if t < ship.reverseUntil then
		throttle, steer = -1, (ship.reverseSteer or 1)
	elseif throttle > 0.3 and speed < 5 then
		ship.stuckSince = ship.stuckSince or t
		if t - ship.stuckSince > 2.5 then
			ship.reverseUntil = t + 2.2
			ship.reverseSteer = random:NextInteger(0, 1) == 0 and -1 or 1
			ship.stuckSince = nil
			ship.routeAt = -math.huge
		end
	else
		ship.stuckSince = nil
	end
	input.throttle, input.steer = throttle, steer
	input.boost = ramming or (engaged and distance > 300)

	-- Mines: a blocker that is ahead of the thief, on the way home, sows its wake.
	if
		engaged
		and ship.role == "blocker"
		and not ship.ghost
		and t >= ship.nextMineAt
		and speed > 20
		and distance < Config.MINE_LAY_RANGE
	then
		local targetPos = carrier.root.Position
		local toHome = flat(refs.hoard.position - targetPos)
		local ahead = toHome.Magnitude > 1 and flat(position - targetPos):Dot(toHome.Unit) or 0
		local stern = position - hull.CFrame.LookVector * (boat.spec.size.Z * 0.5 + 8)
		if ahead > 50 and SeaNav.depthAt(stern.X, stern.Z) > 3 then
			ship.nextMineAt = t + Config.MINE_LAY_GAP
			dropMine(ship, stern)
		end
	end

	-- Guns: mark the water where the target will be, then land the shell. Up close it is a
	-- spread along their course, so a straight line is the wrong answer.
	if carrier and not ramming and t >= ship.nextFireAt and distance < Config.NAVY_FIRE_RANGE then
		local lead = ship.targetVelocity
		local shots = distance < Config.NAVY_SPREAD_RANGE and Config.NAVY_SPREAD_SHOTS or 1
		for i = 1, shots do
			local along = shots == 1 and 1 or (0.5 + (i - 1) * 0.5)
			local aim = carrier.root.Position + lead * Config.NAVY_SHELL_DELAY * along
			aim += Vector3.new(random:NextNumber(-6, 6), 0, random:NextNumber(-6, 6))
			fireShell(ship, aim, Config.NAVY_SHELL_DELAY + (i - 1) * 0.2)
		end
		ship.nextFireAt = t + Config.NAVY_FIRE_GAP * (shots > 1 and 1.4 or 1) * random:NextNumber(0.85, 1.2)
	end
end

function Navy.tick()
	local t = now()
	for _, ship in ipairs(table.clone(Navy.ships)) do
		if ship.boat.state ~= "float" or not ship.boat.model.Parent then
			dropShip(ship, ship.boat.state == "float")
		else
			tickShip(ship, t)
		end
	end
	tickMines(t)
end

function Navy.build(worldRefs)
	refs = worldRefs
	Boats.Sunk:Connect(function(boat)
		for _, ship in ipairs(Navy.ships) do
			if ship.boat == boat then
				dropShip(ship, false)
				return
			end
		end
	end)
	-- Any blast sets off the mines it reaches: shoot a gap in the chain, or watch it cook off.
	Blast.Hit:Connect(function(position, radius)
		for _, mine in ipairs(table.clone(Navy.mines)) do
			if mine.part.Parent and (mine.position - position).Magnitude < radius + 3 then
				-- Next frame, so one blast never recurses through the whole chain at once.
				task.defer(function()
					if mine.part.Parent then
						explodeMine(mine)
					end
				end)
			end
		end
	end)
end

function Navy.reset()
	for _, ship in ipairs(table.clone(Navy.ships)) do
		dropShip(ship, true)
	end
	table.clear(Navy.ships)
	for _, mine in ipairs(table.clone(Navy.mines)) do
		removeMine(mine)
	end
	lastDispatchAt = -math.huge
end

return Navy

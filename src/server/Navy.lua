-- The Goblin Navy: patrol ships that hunt carriers across the sea. They are physics boats like
-- the players' (Boats.lua) driven by an AI that follows routes from the sea navigation grid.
--
-- What makes them a puzzle instead of a stat check:
--   * They sit deep. The same grid that routes them marks shallow channels and reef gaps as
--     impassable to them, so a skiff that slips through leaves them behind.
--   * They need to SEE you. Line of sight and a sight range (shorter in a storm) decide whether they
--     chase or search; break contact behind an island and they go to your last position and give up.
--   * Their guns are slow and marked: a shell is announced as a closing ring on the water about
--     where you will be, then lands. A moving boat that reads the ring is never hit.
--   * They can be sunk. Cannons (the Cutter's, Fort Barnacle's) wreck them in a few hits, and so
--     can a good ramming line, a barrel, or lightning.
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

local Navy = {}
Navy.ships = {}

local refs
local random = Random.new()
local lastDispatchAt = -math.huge

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
	return best
end

local function makeGhost(boat)
	for _, part in ipairs(boat.model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Hull" then
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

local function spawnShip(spawnCFrame, ghost, hunted)
	local boat = Boats.spawnAI("navy", spawnCFrame)
	if ghost then
		makeGhost(boat)
		boat.spec = table.clone(boat.spec)
		boat.spec.maxSpeed *= 1.12
		boat.spec.accel *= 1.1
		boat.spec.health = 300
		boat.health = 300
		boat.model:SetAttribute("Health", 300)
		boat.model:SetAttribute("MaxHealth", 300)
	end
	local ship = {
		boat = boat,
		ghost = ghost,
		target = nil,
		lastSeenAt = -math.huge,
		lastSeenPos = nil,
		route = nil,
		routeIndex = 1,
		routeAt = -math.huge,
		routeGoal = nil,
		nextFireAt = now() + Config.NAVY_FIRST_SHOT_DELAY,
		stuckSince = nil,
		reverseUntil = 0,
		leaving = false,
		bornAt = now(),
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
			ship.lastSeenAt = now()
		end
	end
	table.insert(Navy.ships, ship)
	return ship
end

-- Send patrol ships after a carrier. Returns how many left port.
function Navy.dispatch(targetPlayer, count, force)
	if #refs.navyBases == 0 then
		return 0
	end
	local t = now()
	if not force and t - lastDispatchAt < Config.NAVY_DISPATCH_GAP then
		return 0
	end
	local root = Util.aliveRoot(targetPlayer)
	local base = nearestBase(root and root.Position or Vector3.zero)
	if not base then
		return 0
	end
	local sent = 0
	for i = 1, count do
		if #Navy.ships >= Config.NAVY_MAX then
			break
		end
		local spawn = base.spawns[(i - 1) % #base.spawns + 1]
		spawnShip(spawn, false, targetPlayer)
		sent += 1
	end
	if sent > 0 then
		lastDispatchAt = t
		Net.message("THE NAVY HAS BEEN ALERTED! PATROL SHIPS ARE SAILING OUT", 3.5, Color3.fromRGB(255, 120, 100))
		Net.feed(
			sent .. " patrol ship" .. (sent > 1 and "s" or "") .. " launched from Fort Barnacle!",
			Color3.fromRGB(255, 120, 100)
		)
		Net.broadcast("NavySpawn", { position = base.position })
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
		spawnShip(spawns[(i - 1) % #spawns + 1], true, hunted)
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

function Navy.count()
	return #Navy.ships
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
		local safe = (flat(to) - flat(refs.hoard.position)).Magnitude <= Config.WARD_RADIUS
		if not safe and distance < sight and clearLine(position + Vector3.new(0, 8, 0), to + Vector3.new(0, 2, 0)) then
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
	-- Whiskers: if water ahead is too shallow or land, bias away from that side.
	local avoid = 0
	local draft = boat.spec.draft
	for _, offset in ipairs({ -0.5, 0, 0.5 }) do
		local probeDir = (CFrame.Angles(0, offset, 0) * forward)
		local probe = cf.Position + probeDir * 85
		if not SeaNav.passable(probe.X, probe.Z, draft) then
			avoid += (offset == 0) and 1.2 or -offset * 1.4
		end
	end
	local cross = forward:Cross(desired).Y -- positive: the goal is to the left
	local dot = forward:Dot(desired)
	local steer = -math.clamp(cross * 2.4 + avoid * 0.6, -1, 1)
	if dot < 0 then
		steer = cross >= 0 and -1 or 1
	end
	local throttle = dot > 0.5 and 1 or 0.45
	return throttle, steer, dot
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
		ship.targetRoot = carrier.root
	end

	local goal
	local engaged = false
	if ship.leaving then
		goal = ship.base and ship.base.position
	elseif carrier then
		goal = carrier.root.Position
		engaged = true
	elseif ship.lastSeenPos and t - ship.lastSeenAt < Config.NAVY_SEARCH_TIME then
		goal = ship.lastSeenPos
	else
		-- Lost them: head for home and give up.
		ship.leaving = true
		goal = ship.base and ship.base.position
	end
	if not goal then
		-- A ghost with nothing to chase fades away.
		if t - ship.lastSeenAt > Config.NAVY_SEARCH_TIME then
			dropShip(ship, true)
		end
		input.throttle, input.steer = 0, 0
		return
	end

	-- Route: replan now and then, or when the goal has moved a long way.
	if t - ship.routeAt > Config.NAVY_REPLAN or not ship.routeGoal or (ship.routeGoal - goal).Magnitude > 120 then
		ship.routeAt = t
		ship.routeGoal = goal
		ship.route = SeaNav.path(position, goal, boat.spec.draft)
		ship.routeIndex = 2
	end
	local waypoint = goal
	if ship.route then
		while ship.route[ship.routeIndex] and (flat(ship.route[ship.routeIndex] - position)).Magnitude < 38 do
			ship.routeIndex += 1
		end
		waypoint = ship.route[ship.routeIndex] or goal
	end

	local throttle, steer = steerToward(ship, waypoint)
	local distanceToGoal = (flat(goal) - flat(position)).Magnitude
	if engaged and distanceToGoal < Config.NAVY_STANDOFF then
		-- Hold at gun range: ease off, and back water if they came too close.
		throttle = distanceToGoal < Config.NAVY_STANDOFF * 0.55 and -0.8 or 0
	end
	if ship.leaving and distanceToGoal < 70 then
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
	input.boost = engaged and distanceToGoal > 360

	-- Fire: mark the water where the target will be, then land the shell.
	if carrier and t >= ship.nextFireAt and distanceToGoal < Config.NAVY_FIRE_RANGE then
		local lead = carrier.root.AssemblyLinearVelocity
		local aim = carrier.root.Position + Vector3.new(lead.X, 0, lead.Z) * Config.NAVY_SHELL_DELAY * 0.85
		aim += Vector3.new(random:NextNumber(-6, 6), 0, random:NextNumber(-6, 6))
		local muzzle = position + hull.CFrame.LookVector * 12 + Vector3.new(0, 8, 0)
		Net.broadcast("Shell", {
			from = muzzle,
			to = Vector3.new(aim.X, math.max(aim.Y - 2, 0), aim.Z),
			duration = Config.NAVY_SHELL_DELAY,
		})
		Blast.strike(Vector3.new(aim.X, math.max(aim.Y - 2, 0), aim.Z), Config.NAVY_SHELL_DELAY, {
			radius = 12,
			damage = Config.NAVY_SHELL_DAMAGE,
			knockback = 72,
			hullDamage = Config.NAVY_SHELL_HULL_DAMAGE,
			boatPush = 58,
			lootReason = "cannon",
			cause = ship.ghost and "a ghost ship" or "the Navy",
			exceptBoat = boat,
			markerColor = Color3.fromRGB(255, 80, 60),
			color = Color3.fromRGB(255, 150, 80),
		})
		ship.nextFireAt = t + Config.NAVY_FIRE_GAP * random:NextNumber(0.85, 1.2)
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
end

function Navy.reset()
	for _, ship in ipairs(table.clone(Navy.ships)) do
		dropShip(ship, true)
	end
	table.clear(Navy.ships)
	lastDispatchAt = -math.huge
end

return Navy

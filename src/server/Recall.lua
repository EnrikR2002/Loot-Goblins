-- Call a boat (B). Stranded on an island with no boat in sight is not a game, so a goblin on foot
-- can ask for one: the nearest boat that nobody is using sails (or, when nothing is free, is built)
-- to the closest shore. It does not teleport onto the beach: it is put into open water a few
-- hundred studs out, where the player may be able to see it come, and drives itself in under the
-- same BoatSim every boat uses, so it can be seen, raced and (if a patrol ship is about) shot at.
--
-- Rules, all in Config.RECALL_*:
--   * one call per RECALL_COOLDOWN seconds per goblin (a Tug Crab pet shortens it);
--   * not while sitting in a boat, and not when a boat you could board is already beside you;
--   * the boat comes from the nearest free one anywhere, and never one somebody is sitting in,
--     standing beside, or that another goblin has called;
--   * with no free boat at all, a skiff is built (at most RECALL_EXTRA_MAX of those exist; the
--     oldest empty one is retired first), so the call always works;
--   * the player must be within RECALL_SHORE_MAX studs of water a skiff can use; otherwise they
--     are told which way the coast is.
-- V13: B brings the CLASS the goblin chose in the Port's shipyard (player attribute BoatClass, set by the server
-- from what they own: server/Progress.lua). A Skiff or a Cutter comes from the nearest free boat of that class (or is
-- built); a specialty class is the goblin's own boat (one each, built the first time and brought again after that).
-- The class changes only in the Port or at the Hoard, so it is never swapped mid-chase, and the cooldown is the same.
-- Nothing here trusts the client: it only says "B".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Lobby = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Lobby"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local SeaNav = require(script.Parent.SeaNav)
local Boats = require(script.Parent.Boats)
local Gear = require(script.Parent.Gear)
local Cannons = require(script.Parent.Cannons)

local own = {} -- player -> their specialty-class boat (V13)

-- The class a goblin calls (a player class they own; the server sets the attribute).
local function classOf(player)
	local id = player:GetAttribute("BoatClass")
	local spec = type(id) == "string" and Config.BOAT_TYPES[id]
	return (spec and spec.class) and id or "skiff"
end
local FREE = { skiff = true, cutter = true }

local Recall = {}
Recall.classOf = classOf

-- Pets and other modifiers set this: function(player) -> cooldown seconds.
Recall.cooldownFor = function(player)
	return Config.RECALL_COOLDOWN * (Gear.petIs(player, "Crab") and Config.PET_CRAB_RECALL or 1)
end

local readyAt = {} -- player -> server time
local active = {} -- boat -> { player, goal, path, index, startedAt, beacon }
local extras = {} -- boats Recall built, oldest first

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function compass(from, to)
	local d = flat(to - from)
	local names = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
	-- North is -Z.
	local angle = math.deg(math.atan2(d.X, -d.Z)) % 360
	return names[math.floor((angle + 22.5) / 45) % 8 + 1]
end

-- A boat a goblin at `position` could climb into right now, if there is one within `range`.
local function boardableNear(position, range, class)
	for _, boat in ipairs(Boats.list) do
		if
			not boat.ai
			and (class == nil or boat.typeName == class)
			and boat.state == "float"
			and not Boats.occupied(boat)
			and (boat.hull.Position - position).Magnitude < range
		then
			return boat
		end
	end
	return nil
end

local function someoneNear(position, except, range)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= except then
			local root = Util.aliveRoot(other)
			if root and (root.Position - position).Magnitude < range then
				return true
			end
		end
	end
	return false
end

local function pickBoat(goal, player, class)
	local best, bestDistance = nil, math.huge
	for _, boat in ipairs(Boats.list) do
		if
			not boat.ai
			and boat.typeName == class
			and not boat.owner -- someone's own specialty boat is theirs to call
			and boat.state == "float"
			and not active[boat]
			and not Boats.occupied(boat)
			and not someoneNear(boat.hull.Position, player, 45)
		then
			local distance = flat(boat.hull.Position - goal).Magnitude
			if distance < bestDistance then
				best, bestDistance = boat, distance
			end
		end
	end
	return best
end

-- Open water for the boat to start from: `radius` studs out from the goal, as close to the bearing
-- of where the boat is now as the sea allows, with a route in.
local function startPoint(goal, towards, draft)
	local bearing = math.atan2(towards.X - goal.X, towards.Z - goal.Z)
	for _, radius in ipairs({ Config.RECALL_OFFSHORE, Config.RECALL_OFFSHORE * 0.7, Config.RECALL_OFFSHORE * 0.45 }) do
		for step = 0, 15 do
			local turn = math.ceil(step / 2) * (step % 2 == 0 and 1 or -1) * (math.pi / 8)
			local angle = bearing + turn
			local p = goal + Vector3.new(math.sin(angle), 0, math.cos(angle)) * radius
			if SeaNav.passable(p.X, p.Z, draft) then
				local path = SeaNav.path(p, goal, draft, 1)
				if path and #path > 0 then
					return p, path
				end
			end
		end
	end
	return nil, nil
end

local function beaconFor(boat)
	local part = Instance.new("Part")
	part.Name = "RecallBeacon"
	part.Size = Vector3.new(3, 110, 3)
	part.Color = Color3.fromRGB(110, 255, 190)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.45
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = boat.hull.CFrame * CFrame.new(0, 60, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = boat.hull
	weld.Part1 = part
	weld.Parent = part
	part.Parent = boat.model
	return part
end

local function finish(boat, quiet)
	local job = active[boat]
	if not job then
		return
	end
	active[boat] = nil
	if boat.input and not boat.ai then
		boat.input = nil
	end
	if job.beacon then
		job.beacon:Destroy()
	end
	boat.model:SetAttribute("Recalled", nil)
	if not quiet and job.player.Parent then
		Net.toast(job.player, "Your boat is here. Hold E at it to climb in.")
	end
end

local function retireExtra()
	for i, boat in ipairs(extras) do
		if boat.state == "float" and not Boats.occupied(boat) and not active[boat] then
			table.remove(extras, i)
			Boats.remove(boat)
			return
		end
	end
end

function Recall.request(player)
	local t = now()
	local root, humanoid = Util.aliveRoot(player)
	if not root then
		return
	end
	if humanoid.SeatPart then
		Net.toast(player, "You are already aboard.")
		return
	end
	-- V13: boats are called in the raid. In the Port, the shipyard shows them.
	if Lobby.inPort(root.Position) then
		Net.toast(player, "Boats come when you call in a raid. Visit the shipyard to choose yours.")
		return
	end
	local ready = readyAt[player] or 0
	if t < ready then
		Net.toast(player, string.format("No boat can come yet: %d s.", math.ceil(ready - t)))
		return
	end
	-- (V13: only a boat of the class they sail counts: a goblin who chose a Wraith can still call it beside a skiff.)
	local near = boardableNear(root.Position, Config.RECALL_BOAT_CLEAR, classOf(player))
	if near then
		Net.toast(player, "There is a boat right here. Hold E at it.")
		return
	end
	local draft = Config.BOAT_TYPES.skiff.draft
	local water = SeaNav.nearestWater(root.Position.X, root.Position.Z, draft)
	if not water then
		Net.toast(player, "There is no water to call a boat to.")
		return
	end
	local away = flat(water - root.Position).Magnitude
	if away > Config.RECALL_SHORE_MAX then
		Net.toast(
			player,
			string.format(
				"Too far inland for a boat: the sea is %d studs %s.",
				math.floor(away),
				compass(root.Position, water)
			)
		)
		return
	end
	local goal = water
	-- V13: the class this goblin sails.
	local class = classOf(player)
	local spec = Config.BOAT_TYPES[class]
	local boat
	if FREE[class] then
		boat = pickBoat(goal, player, class)
	else
		local mine = own[player]
		if mine and (mine.state ~= "float" or not mine.model.Parent) then
			own[player] = nil -- sunk or gone: a new one is built
		elseif mine and not Boats.occupied(mine) and not active[mine] then
			boat = mine
		end
	end
	local origin = boat and boat.hull.Position or (goal + Vector3.new(0, 0, Config.RECALL_OFFSHORE))
	local start, path = startPoint(goal, origin, spec.draft)
	if not start then
		start, path = startPoint(goal, origin, draft) -- a deep hull may still be brought nearly in
	end
	if not start then
		Net.toast(player, "No boat can reach this shore.")
		return
	end
	if not boat then
		if FREE[class] then
			if #extras >= Config.RECALL_EXTRA_MAX then
				retireExtra()
			end
			if #extras >= Config.RECALL_EXTRA_MAX then
				Net.toast(player, "Every spare boat is out. Try again in a moment.")
				return
			end
			boat = Boats.spawnPlayerBoat(class, CFrame.lookAt(start, goal))
			table.insert(extras, boat)
		else
			-- Their own was taken by someone else (it is theirs to sail now, and a spare after that): a new one.
			local old = own[player]
			if old then
				old.owner = nil
				table.insert(extras, old)
			end
			boat = Boats.spawnPlayerBoat(class, CFrame.lookAt(start, goal))
			boat.owner = player
			own[player] = boat
		end
		Cannons.mountIfArmed(boat)
	end
	Boats.place(
		boat,
		CFrame.lookAt(
			Vector3.new(start.X, boat.hull.Position.Y, start.Z),
			Vector3.new(goal.X, boat.hull.Position.Y, goal.Z)
		)
	)
	boat.asleep = false
	boat.hull.Anchored = false
	boat.moored = false
	boat.model:SetAttribute("Moored", false)
	boat.input = { throttle = 0, steer = 0, boost = false }
	boat.model:SetAttribute("Recalled", player.UserId)
	Boats.style(boat, player) -- V11: it arrives in the caller's colours
	active[boat] = {
		player = player,
		goal = goal,
		path = path,
		index = 1,
		startedAt = t,
		beacon = beaconFor(boat),
	}
	readyAt[player] = t + Recall.cooldownFor(player)
	player:SetAttribute("RecallReadyAt", readyAt[player])
	Net.toast(player, "A boat is on its way: follow the green beam.")
	Net.broadcast("RecallCalled", { position = goal, userId = player.UserId, boat = boat.model })
end

local function drive(boat, job, t)
	local hull = boat.hull
	local position = hull.Position
	local goal = job.goal
	if Boats.occupied(boat) or boat.state ~= "float" then
		finish(boat, true)
		if boat.state ~= "float" and job.player.Parent then
			Net.toast(job.player, "Your boat was lost on the way. Call again.")
			readyAt[job.player] = t + 6
			job.player:SetAttribute("RecallReadyAt", readyAt[job.player])
		end
		return
	end
	local toGoal = flat(goal - position)
	if toGoal.Magnitude < Config.RECALL_ARRIVE or t - job.startedAt > Config.RECALL_TIMEOUT then
		if toGoal.Magnitude >= Config.RECALL_ARRIVE * 2 then
			-- It is stuck somewhere: put it beside the shore rather than leave a goblin waiting.
			Boats.place(boat, CFrame.lookAt(goal + Vector3.new(0, boat.hull.Position.Y, 0) + toGoal.Unit * -40, goal))
		end
		finish(boat, false)
		return
	end
	-- Follow the route; the last point is the shore.
	local waypoint = job.path[job.index] or goal
	if job.index < #job.path and flat(waypoint - position).Magnitude < 70 then
		job.index += 1
		waypoint = job.path[job.index]
	end
	local cf = hull.CFrame
	local forward = flat(cf.LookVector)
	forward = forward.Magnitude > 0.05 and forward.Unit or Vector3.new(0, 0, -1)
	local desired = flat(waypoint - position)
	desired = desired.Magnitude > 1 and desired.Unit or forward
	local cross = forward:Cross(desired).Y
	local dot = forward:Dot(desired)
	local steer = -math.clamp(cross * 2.4, -1, 1)
	if dot < 0 then
		steer = cross >= 0 and -1 or 1
	end
	local throttle = dot > 0.5 and 1 or 0.45
	-- Ease off for the last stretch so it stops beside the player instead of on the beach.
	if toGoal.Magnitude < 150 then
		throttle = math.min(throttle, math.clamp(toGoal.Magnitude / 150, 0.12, 1))
	end
	boat.input.throttle, boat.input.steer = throttle, steer
	boat.input.boost = toGoal.Magnitude > 260 and dot > 0.9
end

function Recall.tick()
	local t = now()
	for boat, job in pairs(active) do
		if not boat.hull.Parent then
			active[boat] = nil
		elseif not job.player.Parent then
			finish(boat, true)
		else
			drive(boat, job, t)
		end
	end
end

function Recall.forget(player)
	readyAt[player] = nil
	for boat, job in pairs(active) do
		if job.player == player then
			finish(boat, true)
		end
	end
	-- Their own boat becomes a spare (anyone can still sail it; the raid's end removes it).
	local mine = own[player]
	if mine then
		mine.owner = nil
		table.insert(extras, mine)
		own[player] = nil
	end
end

-- The boat this goblin's B brought them, if it is their own specialty boat (for tests and the HUD).
function Recall.ownBoat(player)
	return own[player]
end

function Recall.reset()
	for boat in pairs(active) do
		finish(boat, true)
	end
	table.clear(extras)
	table.clear(readyAt)
	table.clear(own)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("RecallReadyAt", nil)
	end
end

return Recall

-- V13.2: THE SKYSHIP'S ROUTE, as pure functions of time, so the server (server/Skyship.lua), every client (the ship drawn
-- smoothly, the map's route and reach, the cannon's aim: client/Skyship.lua, client/Map.lua) and the tests agree on where
-- the ship is without sending it every frame.
--
-- A raid's deployment (Config.SKYSHIP): PREP seconds hovering at the start of the route (climb in, aim, the cannons are
-- locked), then the PASS: the ship flies the whole route in PASS seconds whatever its length, and a goblin fires when an
-- island they want is in REACH (a cannon throws about REACH studs across from the ship's height). Anyone still aboard
-- when the pass ends is fired at the best landing in reach. After the pass the ship swings round and flies the route
-- back, then forwards again, for goblins who join the raid late (it never jumps: whoever stands on it rides along).
--
-- A route is a list of points { x, z } across the archipelago (Config.SKYSHIP.ROUTES); a raid flies one, forwards or
-- backwards (`reversed`), chosen in the Port (server/Raid.lua), so the corridor differs raid to raid.
local Config = require(script.Parent:WaitForChild("Config"))

local SkyRoute = {}

local S = Config.SKYSHIP

-- The route's points as Vector3s at the ship's height (reversed: flown from the other end).
function SkyRoute.points(index, reversed)
	local route = S.ROUTES[index]
	if not route then
		return nil
	end
	local list = {}
	for _, p in ipairs(route.points) do
		table.insert(list, Vector3.new(p[1], S.POSITION.Y, p[2]))
	end
	if reversed then
		local flipped = {}
		for i = #list, 1, -1 do
			table.insert(flipped, list[i])
		end
		list = flipped
	end
	return list
end

function SkyRoute.length(points)
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

-- The point `distance` studs along the route (clamped to its ends).
function SkyRoute.along(points, distance)
	if distance <= 0 then
		return points[1]
	end
	for i = 2, #points do
		local leg = (points[i] - points[i - 1]).Magnitude
		if distance <= leg then
			return points[i - 1]:Lerp(points[i], leg > 0 and distance / leg or 0)
		end
		distance -= leg
	end
	return points[#points]
end

-- How far along the route the ship is at time t, given when the pass starts (opensAt), and its speed.
-- Also whether it flies the route forwards (the pass, and every other lap after it) or back.
function SkyRoute.distanceAt(points, opensAt, t)
	local length = SkyRoute.length(points)
	local since = t - opensAt
	if since <= 0 then
		return 0, length / S.PASS, true
	end
	-- The pass, then back along the route, then forwards again (late arrivals): there and back, never a jump.
	local laps = since / S.PASS
	local lap = math.floor(laps)
	local frac = laps - lap
	local forward = lap % 2 == 0
	return length * (forward and frac or 1 - frac), length / S.PASS, forward
end

-- The ship's CFrame at time t: at its height over the route, bow along the way it flies (smoothed round corners).
-- Also returns its velocity (zero while it waits at the start).
function SkyRoute.cframeAt(points, opensAt, t)
	local distance, speed, forward = SkyRoute.distanceAt(points, opensAt, t)
	local position = SkyRoute.along(points, distance)
	local length = SkyRoute.length(points)
	local ahead = SkyRoute.along(points, math.min(length, distance + 90))
		- SkyRoute.along(points, math.max(0, distance - 90))
	ahead = Vector3.new(ahead.X, 0, ahead.Z)
	if ahead.Magnitude < 1 then
		ahead = Vector3.new(points[#points].X - points[1].X, 0, points[#points].Z - points[1].Z)
	end
	local along = ahead.Magnitude > 0.1 and ahead.Unit or Vector3.new(0, 0, -1)
	local heading = forward and along or -along
	local yaw = math.atan2(-heading.X, -heading.Z)
	-- At either end it swings round over TURN seconds (a half turn, always the same way) instead of flipping.
	local since = t - opensAt
	local into = since - math.floor(since / S.PASS) * S.PASS
	if since > S.PASS and into < S.TURN then
		yaw += math.pi * (1 - into / S.TURN)
	end
	local moving = t > opensAt
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0), moving and heading * speed or Vector3.zero
end

-- How far a ship's cannon throws a goblin across, landing at sea level (Dive.solve's ballistics at the cannon's speed
-- and angle from the ship's height): the reach shown on the map. (Steering in the air adds a little more.)
function SkyRoute.reach()
	local D = Config.DIVE
	local g, speed, elevation = D.GRAVITY, D.CANNON_SPEED, D.CANNON_ELEVATION
	local h = S.POSITION.Y + 4.6
	local cos, tan = math.cos(elevation), math.tan(elevation)
	local a = 2 * speed * speed * cos * cos * tan
	local b = 8 * g * speed * speed * cos * cos * h
	return (a + math.sqrt(a * a + b)) / (2 * g)
end

-- When the ship passes closest to a point on this route during the pass, how close, and how long the point is in reach
-- (seconds from opensAt). Returns { at, distance, from, to } (from/to nil if it is never in reach).
function SkyRoute.passBy(points, x, z, reach)
	reach = reach or SkyRoute.reach()
	local length = SkyRoute.length(points)
	local target = Vector3.new(x, 0, z)
	local best, bestAt = math.huge, 0
	local from, to = nil, nil
	local steps = 120
	for i = 0, steps do
		local d = length * i / steps
		local p = SkyRoute.along(points, d)
		local gap = (Vector3.new(p.X, 0, p.Z) - target).Magnitude
		local at = S.PASS * i / steps
		if gap < best then
			best, bestAt = gap, at
		end
		if gap <= reach then
			from = from or at
			to = at
		end
	end
	return { at = bestAt, distance = best, from = from, to = to }
end

-- Is (x, z) in reach of the ship at time t?
function SkyRoute.inReach(points, opensAt, t, x, z, reach)
	local cf = SkyRoute.cframeAt(points, opensAt, t)
	local p = cf.Position
	return (Vector3.new(p.X - x, 0, p.Z - z)).Magnitude <= (reach or SkyRoute.reach())
end

-- What the workspace says about the raid's route: its points, opensAt (the pass starts; math.huge while it is only
-- planned and the ship waits at the start), index, reversed. nil if none.
function SkyRoute.current()
	local index = workspace:GetAttribute("SkyRoute")
	local opensAt = workspace:GetAttribute("SkyRouteOpensAt")
	if type(index) ~= "number" or not S.ROUTES[index] then
		return nil
	end
	if type(opensAt) ~= "number" then
		opensAt = math.huge
	end
	local reversed = workspace:GetAttribute("SkyRouteReversed") == true
	return SkyRoute.points(index, reversed), opensAt, index, reversed
end

return SkyRoute

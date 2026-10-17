-- Tornadoes as pure maths (V9). Shared, like Sea.lua, because a tornado has to lift a boat on whichever
-- machine is simulating it: the driver's client for a driven boat, the server for everything else. The
-- server (server/Tornadoes.lua) decides where they are and publishes them as one string attribute,
-- workspace.TwisterData; a client calls Twister.follow() to keep its copy current, and extrapolates
-- each one's position from its velocity between updates, so every machine agrees on where the funnel is.
--
-- A tornado is a funnel standing on the sea: Config.TWISTER.RADIUS wide at the water, wider at the top
-- (FLARE), HEIGHT tall. What it does to something at a point, moving at a velocity:
--   inside the funnel   lifts it toward a steady rising speed (RISE), swings it round (SWIRL) and holds it
--                       in toward the middle (PULL): a spiral ride to the top
--   just outside        draws it in (CATCH radii), weakly: a near miss tugs, it does not grab
--   at the top          throws it out (THROW, THROW_UP): from there it falls like anything else
-- Twister.accel returns that as an acceleration (gravity already cancelled inside the funnel), for the
-- caller to apply its own way (an impulse on a hull, a velocity on a kinematic body).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local Twister = {}

local T = Config.TWISTER
local list = {} -- { id, x, z, vx, vz, t, born, dies }

local function now()
	return workspace:GetServerTimeNow()
end

-- The server sets the list directly; it publishes it for the clients itself.
function Twister.set(newList)
	list = newList
end

function Twister.list()
	return list
end

-- Where a tornado's foot is at time t.
function Twister.positionOf(tw, t)
	local dt = math.clamp((t or now()) - tw.t, -1, 3)
	return tw.x + tw.vx * dt, tw.z + tw.vz * dt
end

-- 0 while it builds or dies away, 1 in its prime.
function Twister.strength(tw, t)
	t = t or now()
	local rise = math.clamp((t - tw.born) / T.FADE, 0, 1)
	local fall = math.clamp((tw.dies - t) / T.FADE, 0, 1)
	return math.min(rise, fall)
end

-- The funnel's radius at a height above the sea.
function Twister.radiusAt(y)
	return T.RADIUS * (1 + (T.FLARE - 1) * math.clamp(y / T.HEIGHT, 0, 1))
end

-- The tornado whose pull reaches a point (within `margin` times its catch radius), or nil. Also returns the
-- flat offset from its axis to the point and the axis' x, z.
function Twister.find(position, t, margin)
	t = t or now()
	local best, bestOffset, bestX, bestZ, bestD
	for _, tw in ipairs(list) do
		if t >= tw.born and t <= tw.dies then
			local x, z = Twister.positionOf(tw, t)
			local offset = Vector3.new(position.X - x, 0, position.Z - z)
			local d = offset.Magnitude
			local reach = Twister.radiusAt(position.Y) * T.CATCH * (margin or 1)
			if d < reach and position.Y < T.HEIGHT + 25 and position.Y > -12 and (not bestD or d < bestD) then
				best, bestOffset, bestX, bestZ, bestD = tw, offset, x, z, d
			end
		end
	end
	return best, bestOffset, bestX, bestZ
end

-- The acceleration a tornado gives something at `position` moving at `velocity`, or nil if none reaches
-- it. `gravity` is the world's (the lift cancels it inside the funnel). Returns accel, state where state is
-- "inside", "edge" or "top".
function Twister.accel(position, velocity, t, gravity)
	t = t or now()
	local tw, offset = Twister.find(position, t)
	if not tw then
		return nil, nil
	end
	local strength = Twister.strength(tw, t)
	if strength <= 0 then
		return nil, nil
	end
	local y = position.Y
	local r = Twister.radiusAt(y)
	local d = offset.Magnitude
	local out = d > 0.5 and offset / d or Vector3.new(1, 0, 0)
	local tangent = Vector3.new(-out.Z, 0, out.X)
	local carried = Vector3.new(tw.vx, 0, tw.vz)
	local rel = Vector3.new(velocity.X, 0, velocity.Z) - carried
	local vRad, vTan = rel:Dot(out), rel:Dot(tangent)
	local g = gravity or workspace.Gravity
	local accel
	local state
	if y > T.HEIGHT * 0.86 then
		-- The top: out it goes.
		state = "top"
		accel = out * math.max(0, T.THROW - vRad) * 3
			+ tangent * (T.SWIRL - vTan) * 0.8
			+ Vector3.new(0, g * 0.6 + math.max(0, T.THROW_UP - velocity.Y) * 2, 0)
	elseif d < r then
		-- Inside: whatever came in is caught. Its motion across is turned into the swirl (round, and in
		-- toward the middle) within a fraction of a second, so even a boat at full boost is taken up, and
		-- it rises steadily to the top.
		state = "inside"
		local want = tangent * T.SWIRL - out * (d - r * 0.4) * T.PULL
		accel = Vector3.new(0, g + (T.RISE - velocity.Y) * 3, 0) + (want - rel) * T.CAPTURE
	else
		-- The skirt: drawn in and a little lifted, more strongly the nearer the funnel.
		state = "edge"
		local k = 1 - math.clamp((d - r) / (r * (T.CATCH - 1)), 0, 1)
		local want = tangent * T.SWIRL * 0.7 - out * (d - r * 0.4) * T.PULL * 0.7
		accel = Vector3.new(0, g * 0.45 * k, 0) + (want - rel) * 1.2 * k * k
	end
	return accel * strength, state, tw
end

-- The velocity change a driver gets for bailing out of a funnel (the jump key): thrown the way the boat
-- points, a little up. nil if no tornado holds it.
function Twister.bail(position, look, t)
	local tw = Twister.find(position, t)
	if not tw then
		return nil
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
	return flat * T.BAIL + Vector3.new(0, T.BAIL_UP, 0)
end

-- Encodes the list for workspace.TwisterData.
function Twister.encode()
	local out = {}
	for _, tw in ipairs(list) do
		table.insert(out, {
			id = tw.id,
			x = math.floor(tw.x * 10) / 10,
			z = math.floor(tw.z * 10) / 10,
			vx = math.floor(tw.vx * 100) / 100,
			vz = math.floor(tw.vz * 100) / 100,
			t = tw.t,
			born = tw.born,
			dies = tw.dies,
			name = tw.name,
		})
	end
	return HttpService:JSONEncode(out)
end

-- A client keeps its copy in step with the server's.
local following = false
function Twister.follow()
	if following then
		return
	end
	following = true
	local function read()
		local raw = workspace:GetAttribute("TwisterData")
		if type(raw) ~= "string" or raw == "" then
			list = {}
			return
		end
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			list = decoded
		end
	end
	read()
	workspace:GetAttributeChangedSignal("TwisterData"):Connect(read)
end

return Twister

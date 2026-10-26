-- Flight (V8): how a goblin moves through the air after a cannon or a catapult throws it. One small
-- model, shared, so the goblin's own client (which flies it, the way a driven boat is simulated on
-- its driver's client), the server (which works out the launch and rules on the bounces) and the
-- landing preview all use exactly the same numbers.
--
-- V7's dive was a glider: Space held it at 175 studs/s for as long as there was height, so the glide
-- was the way to travel and the cannon was only a start. V8 turns that round. The THROW supplies the
-- reach: a plain ballistic arc under one gravity, aimed where you look. In the air you have three ways
-- to be, and none of them adds distance:
--   TUMBLE  no keys: you are a thrown goblin, limbs everywhere, on the arc you were given. The keys
--           nudge it (a little sideways push), enough to fix an aim, not to change islands.
--   GLIDE   hold Space: arms out, an air brake. The fall slows to a float and your speed across the
--           sea bleeds away, so you come down gently and steer onto a spot. Open it early and you
--           fall short: it is a correction and a soft landing, not a way to travel.
--   DIVE    hold Shift: head first, straight down hard, for dropping onto something you would
--           otherwise overshoot.
-- Water is a second chance: a fast goblin skips off the sea like a stone, up to three times, each
-- bounce smaller (Dive.bounce). The server decides each one; the preview draws them.
-- V13.5: a SKIMMER (Cannon Golf's throws: `skim`) skips by its angle instead, like a real stone: shallow arrivals
-- skip on, lower and flatter each time, steep ones plop (Config.DIVE.SKIM).
--
-- Pure functions of numbers and Vector3s: no instances, safe on either machine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local Dive = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Steering never adds speed: it turns what you have (or, from a standstill, gives you `floor`).
local function steer(h, want, accel, floor, dt)
	local w = flat(want)
	if w.Magnitude < 0.1 then
		return h
	end
	local cap = math.max(h.Magnitude, floor)
	local after = h + w.Unit * accel * dt
	if after.Magnitude > cap then
		after = after.Unit * cap
	end
	return after
end

-- One step: the new velocity. mode: "tumble", "glide" or "pencil". want: steering, world space. skim (V13.5): a
-- skimmer's flight, whose tumble steers at Config.DIVE.SKIM.STEER of the usual.
function Dive.step(velocity, want, mode, dt, skim)
	local d = Config.DIVE
	local h = flat(velocity)
	local vy = velocity.Y
	if mode == "glide" then
		if vy < -d.GLIDE_SINK then
			-- The brake: the fall eases to the float (no gravity while it is biting).
			vy = -d.GLIDE_SINK + (vy + d.GLIDE_SINK) * math.exp(-d.GLIDE_BRAKE * dt)
		else
			vy = math.max(vy - d.GRAVITY * dt, -d.GLIDE_SINK)
		end
		local speed = h.Magnitude
		if speed > d.GLIDE_SPEED then
			h = h.Unit * (d.GLIDE_SPEED + (speed - d.GLIDE_SPEED) * math.exp(-d.GLIDE_DRAG * dt))
		end
		h = steer(h, want, d.GLIDE_STEER, d.GLIDE_SPEED, dt)
	elseif mode == "pencil" then
		vy = math.max(vy - d.PENCIL_GRAVITY * dt, -d.PENCIL_FALL_MAX)
		h = h * math.exp(-d.PENCIL_DRAG * dt)
		h = steer(h, want, d.PENCIL_STEER, d.PENCIL_FLOOR, dt)
	else
		vy -= d.GRAVITY * dt
		h = steer(h, want, d.TUMBLE_STEER * (skim and d.SKIM.STEER or 1), d.TUMBLE_FLOOR, dt)
	end
	return Vector3.new(h.X, vy, h.Z)
end

-- The velocity that throws a goblin from `from` to land on `target`, leaving at `elevation` (radians
-- above level) and never faster than `maxSpeed`. Returns the velocity and whether the target is in
-- reach; if it is not, the velocity is the full throw in that direction (the preview shows where
-- that comes down). Exact for an untouched tumble: the arc is one gravity and nothing else.
function Dive.solve(from, target, elevation, maxSpeed)
	local d = Config.DIVE
	local across = flat(target - from)
	local range = across.Magnitude
	local dir = range > 1 and across.Unit or Vector3.new(0, 0, -1)
	local drop = from.Y - target.Y
	local cos, sin, tan = math.cos(elevation), math.sin(elevation), math.tan(elevation)
	local speed, reach = maxSpeed, false
	local denominator = 2 * cos * cos * (range * tan + drop)
	if denominator > 0.001 then
		local need = math.sqrt(d.GRAVITY * range * range / denominator)
		if need <= maxSpeed then
			speed, reach = need, true
		end
	end
	speed = math.max(speed, d.MIN_SPEED)
	return (dir * cos + Vector3.new(0, sin, 0)) * speed, reach
end

-- The n-th time a flight meets the sea: the velocity it leaves with, or nil if it does not bounce
-- (all three used, a gentle arrival, or the goblin is braking: a glide lands, it does not skip).
-- skim (V13.5): a skimmer's rule (Config.DIVE.SKIM): by the angle it comes down at, not how hard.
function Dive.bounce(velocity, n, mode, skim)
	local d = Config.DIVE
	if skim then
		local S = d.SKIM
		local h = flat(velocity)
		local fall = -velocity.Y
		if mode == "glide" or n > S.MAX or fall <= 0 or h.Magnitude < 1 then
			return nil
		end
		if math.deg(math.atan2(fall, h.Magnitude)) > S.MAX_ANGLE then
			return nil -- too steep: it plops
		end
		local across, up = h * S.KEEP, fall * S.BOUNCE
		if up < S.MIN_UP or across.Magnitude < S.MIN_SPEED then
			return nil -- run out: it sinks in
		end
		return Vector3.new(across.X, up, across.Z)
	end
	local up = d.BOUNCE_UP[n]
	if not up or mode == "glide" then
		return nil
	end
	if n == 1 and -velocity.Y < d.BOUNCE_MIN_FALL then
		return nil
	end
	local h = flat(velocity) * d.BOUNCE_KEEP
	if h.Magnitude > d.BOUNCE_MAX_SPEED then
		h = h.Unit * d.BOUNCE_MAX_SPEED
	end
	return Vector3.new(h.X, up, h.Z)
end

-- Where a flight from `origin` at `velocity` goes if `mode` and `want` are held all the way down:
-- the points of the arc and every place it touches (the last one is where it stops; the ones before
-- are skips off the sea). groundAt(x, z) gives the height of whatever is below and whether it is
-- water. Stops after 30 seconds of flight. skim (V13.5): a skimmer's flight (its own bounce and steering).
function Dive.predict(origin, velocity, mode, groundAt, want, bouncesUsed, skim)
	local points = { origin }
	local touches = {}
	local p, v = origin, velocity
	local bounces = bouncesUsed or 0
	local dt = skim and 0.1 or 0.2 -- (a skimmer's skips are short: a coarse step would step over them)
	for _ = 1, skim and 300 or 150 do
		v = Dive.step(v, want or Vector3.zero, mode, dt, skim)
		local to = p + v * dt
		local ground, water = groundAt(to.X, to.Z)
		if to.Y <= ground and v.Y < 0 then
			local share = math.clamp((p.Y - ground) / math.max(p.Y - to.Y, 0.001), 0, 1)
			local at = p + (to - p) * share
			at = Vector3.new(at.X, ground, at.Z)
			table.insert(points, at)
			table.insert(touches, { position = at, water = water == true })
			local away = water and Dive.bounce(v, bounces + 1, mode, skim) or nil
			if not away then
				return points, touches
			end
			bounces += 1
			v = away
			p = at + Vector3.new(0, 0.5, 0)
		else
			p = to
			table.insert(points, p)
		end
	end
	return points, touches
end

-- How a flying goblin is turned. `t` is seconds of flight (the tumble spins on it).
--   tumble  end over end, with a wobble: nobody is in charge
--   pencil  head along the way it is going
--   glide   belly down, facing the way it is heading
function Dive.orientation(velocity, mode, t)
	local h = flat(velocity)
	local yaw = h.Magnitude > 1 and math.atan2(-h.X, -h.Z) or 0
	if mode == "glide" then
		return CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-78), 0, 0)
	elseif mode == "pencil" then
		local up = velocity.Magnitude > 1 and velocity.Unit or Vector3.new(0, -1, 0)
		local right = up:Cross(Vector3.yAxis)
		right = right.Magnitude > 0.05 and right.Unit or Vector3.xAxis
		return CFrame.fromMatrix(Vector3.zero, right, up)
	end
	local spin = Config.DIVE.TUMBLE_SPIN
	return CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(-(t or 0) * spin, 0, 0)
		* CFrame.Angles(0, 0, math.sin((t or 0) * 2.3) * 0.6)
end

return Dive

-- The dive: how a goblin falls from the skyship. One small model, shared, so the driver's client
-- (which flies its own goblin, the way a driven boat is simulated on its driver's client) and the
-- landing preview that shows where a cannon shot will end up use exactly the same numbers.
--
-- Two ways to fall, switched by one key (hold Space):
--   PENCIL  head down, a fast plummet with little sideways reach (about 55 studs/s along, 150 down).
--   GLIDE   arms out, slow sink, a long reach (about 175 studs/s along, 30 down): 5.7 studs of
--           reach for every stud of height. The ship hangs 540 studs up, so a glide covers most of
--           the sea; the pencil dive is for getting down onto a small island quickly.
-- The cannon throws you much faster than either; the velocity relaxes toward the chosen mode, so a
-- shot is a fast flat start that settles into the dive. Everything is a first-order approach to a
-- target velocity: no gravity to integrate, easy to predict, and impossible to get stuck in.
--
-- Pure functions of numbers and Vector3s: no instances, safe on either machine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))

local Dive = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- The horizontal direction you want to go, from steering input (a world-space vector, any length)
-- and the way you are already going: no input keeps the heading.
function Dive.heading(want, velocity)
	local w = flat(want)
	if w.Magnitude > 0.1 then
		return w.Unit, true
	end
	local h = flat(velocity)
	if h.Magnitude > 1 then
		return h.Unit, false
	end
	return Vector3.zero, false
end

-- One step: returns the new velocity. glide: Space is held. want: steering (world space).
function Dive.step(velocity, want, glide, dt)
	local d = Config.DIVE
	local reach = glide and d.GLIDE_REACH or d.PENCIL_REACH
	local sink = glide and d.GLIDE_SINK or d.PENCIL_FALL
	local rate = glide and d.GLIDE_RATE or d.PENCIL_RATE
	local dir, steering = Dive.heading(want, velocity)
	-- No input: keep going, but not at full reach (steering is what earns the last stretch).
	local speed = steering and reach or reach * d.COAST_SHARE
	local target = Vector3.new(dir.X * speed, -sink, dir.Z * speed)
	local blend = 1 - math.exp(-rate * dt)
	return velocity:Lerp(target, blend)
end

-- Where a shot launched from `origin` at `velocity` ends up if the goblin glides (or dives) the whole
-- way: a list of points, and the first one at or below `groundAt(x, z)` (a function giving the height
-- of whatever is below). It stops at 24 seconds. want is the steering to hold (usually none).
function Dive.predict(origin, velocity, glide, groundAt, want)
	local points = { origin }
	local p, v = origin, velocity
	local dt = 0.2
	for _ = 1, 120 do
		v = Dive.step(v, want or Vector3.zero, glide, dt)
		p = p + v * dt
		table.insert(points, p)
		local ground = groundAt(p.X, p.Z)
		if p.Y <= ground then
			return points, Vector3.new(p.X, ground, p.Z)
		end
	end
	return points, nil
end

-- The velocity a cannon gives: toward `target` (flat), at the launch speed and elevation, with
-- the player's nudge (radians) added.
function Dive.launchVelocity(from, target, yawNudge, pitchNudge)
	local d = Config.DIVE
	local toward = flat(target - from)
	toward = toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, -1)
	local yaw = math.atan2(toward.X, toward.Z) + (yawNudge or 0)
	local pitch = math.clamp(d.LAUNCH_ELEVATION + (pitchNudge or 0), math.rad(4), math.rad(52))
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	return dir * d.LAUNCH_SPEED
end

-- The orientation of a diving goblin: head down for a pencil dive, belly down for a glide,
-- facing the way they are heading.
function Dive.orientation(velocity, glide)
	local h = flat(velocity)
	local yaw = h.Magnitude > 1 and math.atan2(-h.X, -h.Z) or 0
	if glide then
		return CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-78), 0, 0)
	end
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(172), 0, 0)
end

return Dive

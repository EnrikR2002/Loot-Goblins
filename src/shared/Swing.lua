-- V13.2: the GRAPPLE SWING, as pure functions (the goblin's own client flies its own body with it: client/Main;
-- tests/luau/Specs/MovementSpec.lua checks it). A rope from the goblin to a hook point:
--
--   rope = Swing.start(hookPoint, position, velocity)   mode "swing" (the hook is above) or "pull" (level or below)
--   velocity, done = Swing.step(rope, position, velocity, hookPoint, hookVelocity, { move, reel }, dt)
--
-- A swing is a pendulum under Config.SWING.GRAVITY: the rope only ever pulls (when taut it takes away the part of the
-- motion that would stretch it, so the goblin goes round the hook instead of away from it), the move keys pump along
-- the swing, holding the grapple key reels the rope in. A pull reels the goblin straight to the hook (V7's grapple).
-- The velocity this returns is the whole motion: the caller sets it on the body (and so owns gravity while it lasts).
local Config = require(script.Parent:WaitForChild("Config"))

local Swing = {}

function Swing.start(hook, position, _velocity)
	local S = Config.SWING
	local offset = position - hook
	local mode = hook.Y > position.Y + S.ABOVE and "swing" or "pull"
	return {
		mode = mode,
		length = math.max(S.MIN_LENGTH, offset.Magnitude * (mode == "swing" and S.START_SHORTEN or 1)),
		age = 0,
		best = offset.Magnitude,
		bestAge = 0,
	}
end

-- Returns the new velocity, and a reason when the rope is done ("arrived", "snagged", "time").
function Swing.step(rope, position, velocity, hook, hookVelocity, input, dt)
	local S = Config.SWING
	rope.age += dt
	hookVelocity = hookVelocity or Vector3.zero
	local offset = position - hook
	local distance = offset.Magnitude
	if rope.age > S.MAX_TIME then
		return velocity, "time"
	end
	if distance < 0.5 then
		return hookVelocity, "arrived"
	end
	local n = offset / distance -- from the hook out to the goblin
	if rope.mode == "pull" then
		-- Reeled straight in, easing over the last studs, riding along with a moving hook.
		if distance < 3 then
			return velocity, "arrived"
		end
		if distance < rope.best - 0.5 then
			rope.best, rope.bestAge = distance, rope.age
		elseif rope.age - rope.bestAge > 0.3 then
			return velocity, "snagged"
		end
		return -n * math.min(Config.GRAPPLE_PULL_SPEED, 30 + distance * 6) + hookVelocity, nil
	end
	-- The swing.
	local v = velocity - hookVelocity
	v += Vector3.new(0, -S.GRAVITY * dt, 0)
	local move = input and input.move
	if typeof(move) == "Vector3" and move.Magnitude > 0.1 then
		-- Pumping: the keys push along the swing (never along the rope).
		local along = move.Unit - n * move.Unit:Dot(n)
		if along.Magnitude > 0.05 then
			v += along.Unit * S.PUMP * dt
		end
	end
	if input and input.reel then
		rope.length = math.max(S.MIN_LENGTH, rope.length - S.REEL * dt)
	end
	local over = distance - rope.length
	if over > 0 then
		local outward = v:Dot(n)
		if outward > 0 then
			v -= n * outward -- taut: no stretching
		end
		v -= n * math.min(over, 20) * 6 -- and back in to the rope's length (an overshoot is taken up in about 1/6 s)
	end
	if v.Magnitude > S.MAX_SPEED then
		v = v.Unit * S.MAX_SPEED
	end
	if input and input.reel and distance < S.MIN_LENGTH + 2 then
		return v + hookVelocity, "arrived"
	end
	return v + hookVelocity, nil
end

-- The velocity to leave the rope with: all of it, and a little lift if moving upward (off the top of an arc).
function Swing.release(velocity)
	if velocity.Y > 4 then
		return velocity + Vector3.new(0, Config.SWING.RELEASE_POP, 0)
	end
	return velocity
end

return Swing

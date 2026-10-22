-- V13.2: running with MOMENTUM, as pure functions (the goblin's own client plays it on its own WalkSpeed: client/Main;
-- tests/luau/Specs/MovementSpec.lua checks the numbers). The server still owns the BASE speed (carrying, water, a
-- pet's or a spirit's bonus: server/Movement.lua); momentum is a multiplier on it, from Config.MOMENTUM.START at the
-- first step, to 1 a moment later, to Config.MOMENTUM.TOP after a couple of seconds of running on.
--
--   state = Momentum.new()
--   multiplier = Momentum.step(state, { moving, direction (a flat unit Vector3), grounded, swimming }, dt)
--   Momentum.carry(state, speed, direction): a swing, a dash or a fall hands over speed the goblin keeps for a moment
--   Momentum.speed(state, base): the WalkSpeed to use (the run with momentum, or a carried speed if that is faster)
local Config = require(script.Parent:WaitForChild("Config"))

local Momentum = {}

function Momentum.new()
	return { m = 0, direction = nil, carried = 0, carryDirection = nil, landedAt = nil, airborne = false }
end

-- The run's multiplier for a momentum of m (0..1).
function Momentum.multiplier(m)
	local M = Config.MOMENTUM
	if m < M.RUN_AT then
		return M.START + (1 - M.START) * (m / M.RUN_AT)
	end
	local k = (m - M.RUN_AT) / (1 - M.RUN_AT)
	k = k * k * (3 - 2 * k) -- eased: it comes on smoothly and settles at the top
	return 1 + (M.TOP - 1) * k
end

function Momentum.step(state, input, dt)
	local M = Config.MOMENTUM
	local moving = input.moving == true and typeof(input.direction) == "Vector3" and input.direction.Magnitude > 0.1
	if moving then
		local direction = input.direction.Unit
		if state.direction then
			local dot = direction:Dot(state.direction)
			if dot < M.TURN_DOT and input.grounded then
				-- A hard turn on the ground spends momentum (a gentle curve keeps it).
				local share = M.TURN_LOSS * math.clamp((M.TURN_DOT - dot) / (M.TURN_DOT + 1), 0, 1)
				state.m = math.max(0, state.m * (1 - share))
			end
		end
		-- The heading follows the keys, so a long curve is a run, not a string of turns.
		state.direction = state.direction and state.direction:Lerp(direction, math.min(1, dt * 6)) or direction
		if state.direction.Magnitude > 0.01 then
			state.direction = state.direction.Unit
		end
		if input.grounded or input.swimming then
			local rate = state.m < M.RUN_AT and (M.RUN_AT / M.RUN_TIME) or ((1 - M.RUN_AT) / M.TOP_TIME)
			state.m = math.min(1, state.m + rate * dt)
		end
	elseif input.grounded then
		state.m = math.max(0, state.m - M.STOP_DECAY * dt)
		state.direction = nil
	end
	if input.swimming then
		state.m = math.min(state.m, M.WATER_MAX)
	end
	-- A carried speed: kept in the air, slid off over CARRY_GROUND_TIME once down, lost to a hard turn.
	if state.carried > 0 then
		if input.grounded then
			if not state.landedAt then
				state.landedAt, state.landSpeed = 0, state.carried
			end
			state.landedAt += dt
			state.carried = state.landSpeed * math.max(0, 1 - state.landedAt / M.CARRY_GROUND_TIME)
		else
			state.landedAt = nil
			state.carried *= math.max(0, 1 - M.CARRY_AIR_DECAY * dt)
		end
		if moving and state.carryDirection and input.direction.Unit:Dot(state.carryDirection) < 0 then
			state.carried *= math.max(0, 1 - dt * 4) -- steering back against it brakes it
		end
		if state.carried < 1 then
			state.carried = 0
		end
	else
		state.landedAt = nil
	end
	return Momentum.multiplier(state.m)
end

-- Hand over a speed the goblin is moving at (a swing let go, a dash ending, a launch): it may keep it for a while, and
-- it counts as full momentum when it is at least the top of the run.
function Momentum.carry(state, speed, direction, base)
	local M = Config.MOMENTUM
	speed = math.min(speed, M.CARRY_MAX)
	if speed > state.carried then
		state.carried = speed
		state.carryDirection = typeof(direction) == "Vector3" and direction.Magnitude > 0.01 and direction.Unit or nil
		state.landedAt = nil
	end
	if base and speed >= base * M.TOP * 0.95 then
		state.m = 1
	end
end

-- The WalkSpeed: the run with momentum, or the carried speed if that is faster.
function Momentum.speed(state, base)
	return math.max(base * Momentum.multiplier(state.m), state.carried)
end

return Momentum

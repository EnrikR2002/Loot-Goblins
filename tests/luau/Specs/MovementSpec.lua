-- V13.2: running with momentum (shared/Momentum.lua) and the grapple swing (shared/Swing.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Momentum = require(Shared.Momentum)
local Swing = require(Shared.Swing)

local M = Config.MOMENTUM
local S = Config.SWING
local FORWARD = Vector3.new(0, 0, -1)

local function run(state, seconds, input)
	local dt = 1 / 60
	for _ = 1, math.floor(seconds / dt + 0.5) do
		Momentum.step(state, input, dt)
	end
end

return function(t)
	t.test("momentum: moving at once, the ordinary run a moment later, the top after a couple of seconds", function()
		local state = Momentum.new()
		local base = Config.WALK_SPEED
		t.ok(Momentum.speed(state, base) >= base * 0.7, "the first step is already a jog, not a crawl")
		run(state, M.RUN_TIME + 0.05, { moving = true, direction = FORWARD, grounded = true })
		t.ok(Momentum.speed(state, base) >= base * 0.99, "the ordinary run within a third of a second")
		run(state, M.TOP_TIME + 0.1, { moving = true, direction = FORWARD, grounded = true })
		t.ok(math.abs(Momentum.speed(state, base) - base * M.TOP) < 0.1, "the top of the run")
		t.ok(base * M.TOP >= 36 and base * M.TOP <= 40, "the top is what V13's sprint was")
	end)

	t.test("momentum: a hard turn or a stop spends it; a curve, a jump and a fall keep it", function()
		local state = Momentum.new()
		run(state, 3, { moving = true, direction = FORWARD, grounded = true })
		-- A gentle curve, a little at a time.
		local dir = FORWARD
		for i = 1, 60 do
			dir = CFrame.Angles(0, math.rad(1), 0):VectorToWorldSpace(dir)
			Momentum.step(state, { moving = true, direction = dir, grounded = true }, 1 / 60)
			if i == 60 then
				t.ok(state.m > 0.95, "a 60 degree curve over a second keeps it: " .. state.m)
			end
		end
		-- In the air it is held, whatever happens.
		run(state, 1, { moving = false, grounded = false })
		t.ok(state.m > 0.95, "held through a jump")
		-- A reverse on the ground spends most of it.
		Momentum.step(state, { moving = true, direction = -dir, grounded = true }, 1 / 60)
		t.ok(state.m < 0.5, "a reverse spends it: " .. state.m)
		-- Standing still drains the rest.
		run(state, 1, { moving = false, grounded = true })
		t.eq(state.m, 0, "a stop spends it")
	end)

	t.test("momentum: a swing's speed is kept in the air and slides back to the run after landing", function()
		local state = Momentum.new()
		local base = Config.WALK_SPEED
		Momentum.carry(state, 80, FORWARD, base)
		t.eq(state.m, 1, "a fast hand-over is full momentum")
		run(state, 1, { moving = true, direction = FORWARD, grounded = false })
		t.ok(Momentum.speed(state, base) > 65, "still fast in the air: " .. Momentum.speed(state, base))
		run(state, M.CARRY_GROUND_TIME * 0.25, { moving = true, direction = FORWARD, grounded = true })
		local mid = Momentum.speed(state, base)
		t.ok(mid > base * M.TOP and mid < 70, "sliding back: " .. mid)
		run(state, M.CARRY_GROUND_TIME, { moving = true, direction = FORWARD, grounded = true })
		t.ok(math.abs(Momentum.speed(state, base) - base * M.TOP) < 0.5, "back to the top of the run")
		Momentum.carry(state, 500, FORWARD, base)
		t.ok(state.carried <= M.CARRY_MAX, "never more than CARRY_MAX")
	end)

	t.test("swing: a hook above is a swing, level or below a pull", function()
		local here = Vector3.new(0, 10, 0)
		t.eq(Swing.start(Vector3.new(0, 60, -40), here).mode, "swing", "above")
		t.eq(Swing.start(Vector3.new(0, 12, -40), here).mode, "pull", "level")
		t.eq(Swing.start(Vector3.new(0, -2, -40), here).mode, "pull", "below")
	end)

	t.test("swing: a pendulum under the hook gathers speed at the bottom and never stretches the rope", function()
		local hook = Vector3.new(0, 80, 0)
		local p = Vector3.new(-50, 40, 0)
		local v = Vector3.zero
		local rope = Swing.start(hook, p, v)
		local length = rope.length
		local fastest, longest = 0, 0
		local dt = 1 / 60
		for frame = 1, 90 do
			local done
			v, done = Swing.step(rope, p, v, hook, Vector3.zero, {}, dt)
			t.eq(done, nil, "still swinging")
			p += v * dt
			fastest = math.max(fastest, v.Magnitude)
			if frame > 30 then -- (it starts a little slack-shortened: the first moments take the rope up)
				longest = math.max(longest, (p - hook).Magnitude)
			end
		end
		t.ok(fastest > 40, "a real swing: " .. math.floor(fastest) .. " studs/s at the bottom")
		t.ok(longest <= length + 2, "the rope holds: " .. math.floor(longest) .. " of " .. math.floor(length))
		t.ok(fastest <= S.MAX_SPEED + 0.01, "within the swing's top speed")
	end)

	t.test("swing: the keys pump it, holding the key reels in, and letting go keeps the speed with a lift", function()
		local hook = Vector3.new(0, 80, 0)
		local function swingFor(input)
			local p, v = Vector3.new(-50, 40, 0), Vector3.zero
			local rope = Swing.start(hook, p, v)
			local fastest = 0
			for _ = 1, 120 do
				v = Swing.step(rope, p, v, hook, Vector3.zero, input, 1 / 60)
				p += v * (1 / 60)
				fastest = math.max(fastest, v.Magnitude)
			end
			return fastest, rope
		end
		local plain = swingFor({})
		local pumped = swingFor({ move = Vector3.new(1, 0, 0) })
		t.ok(pumped > plain, string.format("pumping: %d over %d", pumped, plain))
		local _, reeled = swingFor({ reel = true })
		local _, free = swingFor({})
		t.ok(reeled.length < free.length - 20, "holding the key shortens the rope")
		local out = Swing.release(Vector3.new(60, 20, 0))
		t.eq(out.X, 60, "every bit of the speed")
		t.eq(out.Y, 20 + S.RELEASE_POP, "and a lift off the top of an arc")
		t.eq(Swing.release(Vector3.new(60, -10, 0)).Y, -10, "no lift on the way down")
	end)

	t.test("swing: a pull reels you to the hook and says when it arrived", function()
		local hook = Vector3.new(0, 10, -60)
		local p, v = Vector3.new(0, 10, 0), Vector3.zero
		local rope = Swing.start(hook, p, v)
		t.eq(rope.mode, "pull", "a pull")
		local done
		for _ = 1, 200 do
			v, done = Swing.step(rope, p, v, hook, Vector3.zero, {}, 1 / 60)
			if done then
				break
			end
			p += v * (1 / 60)
		end
		t.eq(done, "arrived", "it arrives")
		t.ok((p - hook).Magnitude < 4, "at the hook")
	end)
end

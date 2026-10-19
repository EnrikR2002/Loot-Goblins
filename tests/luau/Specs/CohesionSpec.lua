-- V12 (the cohesion pass): where a picked island throws you, which banner shows, what the objective line says,
-- and that a flight on Dive's own rules comes down where Dive.solve aimed it (the contract the client's
-- anti-gravity force restores in the real game: client/Skyship.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Dive = require(Shared.Dive)
local Landing = require(Shared.Landing)
local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("LootGoblinsClient")
local BannerQueue = require(Client.BannerQueue)
local Objective = require(Client.Objective)

local function near(a, b, within)
	return (a - b).Magnitude <= within
end

return function(t)
	-- Landing ---------------------------------------------------------------------------------------------
	t.test("landing candidates start on the skyship's side of the treasure and walk outward", function()
		local spot = Vector3.new(100, 10, 100)
		local ship = Vector3.new(100, 540, -500) -- due north (-Z)
		local list = Landing.candidates(spot, ship)
		t.eq(#list, #Landing.RINGS * Landing.STEPS, "every ring, every bearing")
		t.ok(near(list[1], Vector3.new(100, 0, 100 - Landing.RINGS[1]), 0.01), "first: toward the ship, nearest ring")
		local last = list[#list]
		t.ok(
			math.abs(
				(Vector3.new(last.X, 0, last.Z) - Vector3.new(100, 0, 100)).Magnitude - Landing.RINGS[#Landing.RINGS]
			) < 0.01,
			"last: the outer ring"
		)
		for i = 2, #list do
			local d1 = (Vector3.new(list[i - 1].X, 0, list[i - 1].Z) - Vector3.new(100, 0, 100)).Magnitude
			local d2 = (Vector3.new(list[i].X, 0, list[i].Z) - Vector3.new(100, 0, 100)).Magnitude
			t.ok(d2 >= d1 - 0.01, "never closer than the one before")
		end
	end)

	t.test("a landing must be dry, level, open ground near the treasure's height", function()
		local good = { y = 9, normalY = 1, water = false, structure = false, lava = false }
		t.ok(Landing.acceptable(good, 10), "a flat beach")
		t.ok(not Landing.acceptable({ y = 0, normalY = 1, water = true }, 10), "the sea")
		t.ok(not Landing.acceptable({ y = 9, normalY = 1, structure = true }, 10), "a roof or a dock")
		t.ok(not Landing.acceptable({ y = 9, normalY = 1, lava = true }, 10), "lava")
		t.ok(not Landing.acceptable({ y = 9, normalY = 0.5 }, 10), "a cliff face")
		t.ok(not Landing.acceptable({ y = 30, normalY = 1 }, 10), "far above the treasure")
		t.ok(not Landing.acceptable({ y = -25, normalY = 1 }, 10), "far below the treasure")
		t.ok(not Landing.acceptable({ y = 1, normalY = 1 }, 10), "awash at sea level")
		t.ok(not Landing.acceptable({ y = 3, normalY = 1 }, 10), "the strict pass wants ground above the waterline")
		t.ok(Landing.acceptable({ y = 3, normalY = 1 }, 10, Landing.PASSES[2].sea), "the loose pass takes a low beach")
		t.eq(#Landing.apron(Vector3.new(0, 0, 0), 10), 8, "eight apron points")
		local back = Landing.approach(Vector3.new(0, 0, 0), Vector3.new(0, 500, -1000), 36)
		t.eq(#back, 3, "approach points every 12 studs")
		t.ok(back[3].Z < -35 and math.abs(back[3].X) < 0.01, "toward the ship")
		t.ok(not Landing.acceptable(nil, 10), "nothing below")
	end)

	t.test("a throw flown on Dive's own gravity lands where Dive.solve aimed it", function()
		local D = Config.DIVE
		for _, target in ipairs({ Vector3.new(-538, 7, 1955), Vector3.new(1593, 40, 1344), Vector3.new(29, 100, 296) }) do
			-- V13.2: the ship's cannons reach about 1,200 studs, so it throws from a ship passing 920 studs off.
			local from = Vector3.new(target.X - 650, Config.SKYSHIP.POSITION.Y + 4.6, target.Z - 650)
			local velocity, reach = Dive.solve(from, target, D.CANNON_ELEVATION, D.CANNON_SPEED)
			t.ok(reach, "in reach")
			local position, dt = from, 1 / 60
			for _ = 1, 60 * 40 do
				velocity = Dive.step(velocity, Vector3.zero, "tumble", dt)
				position += velocity * dt
				if velocity.Y < 0 and position.Y <= target.Y then
					break
				end
			end
			t.ok(
				near(Vector3.new(position.X, 0, position.Z), Vector3.new(target.X, 0, target.Z), 12),
				"within 12 studs"
			)
		end
	end)

	-- Banners ---------------------------------------------------------------------------------------------
	t.test("a lesser banner waits for the one showing, then shows if still fresh", function()
		local q = BannerQueue.new()
		t.ok(BannerQueue.offer(q, 0, { message = "YOU STOLE IT", duration = 3, priority = 3 }), "the steal shows")
		t.eq(BannerQueue.offer(q, 1.1, { message = "TROUBLE", duration = 2.6, priority = 2 }), nil, "trouble waits")
		t.eq(BannerQueue.flush(q, 2), nil, "not while the steal shows")
		local shown = BannerQueue.flush(q, 3.1)
		t.eq(shown and shown.message, "TROUBLE", "then trouble")
		t.eq(BannerQueue.flush(q, 3.2), nil, "only once")
	end)

	t.test("an equal or bigger banner replaces at once; a stale waiting one is dropped", function()
		local q = BannerQueue.new()
		BannerQueue.offer(q, 0, { message = "NEWS", duration = 3, priority = 1 })
		t.ok(BannerQueue.offer(q, 0.5, { message = "STOMP", duration = 1.6, priority = 4 }), "act-now beats news")
		t.eq(BannerQueue.offer(q, 0.6, { message = "STORM", duration = 3.5, priority = 1 }), nil, "news waits")
		t.eq(BannerQueue.flush(q, 9), nil, "too old by then")
		t.ok(BannerQueue.offer(q, 10, { message = "A", duration = 3 }), "default priority shows on a clear screen")
		t.ok(BannerQueue.offer(q, 10.5, { message = "B", duration = 3 }), "same priority replaces")
	end)

	t.test("only the most important waiting banner is kept", function()
		local q = BannerQueue.new()
		BannerQueue.offer(q, 0, { message = "BIG", duration = 4, priority = 4 })
		BannerQueue.offer(q, 1, { message = "NEWS", priority = 1 })
		BannerQueue.offer(q, 1.5, { message = "TROPHY", priority = 2 })
		BannerQueue.offer(q, 2, { message = "MORE NEWS", priority = 1 })
		local shown = BannerQueue.flush(q, 4.1)
		t.eq(shown and shown.message, "TROPHY", "the trophy, not the news")
	end)

	-- Objective -------------------------------------------------------------------------------------------
	t.test("the objective line names the key for the next step", function()
		local function line(state)
			state.phase = state.phase or "raid"
			return (Objective.line(state))
		end
		t.eq(line({ phase = "port" }), "", "in the Port: no chip (the Port's own screen speaks)")
		local carry = { name = "Lost Compass", value = 4 }
		local far = line({ carrying = carry, bonus = 1, hoardDistance = 566 })
		t.ok(string.find(far, "LOST COMPASS (5g)", 1, true), "value with interest")
		t.ok(string.find(far, "B: call a boat", 1, true), "far from home on foot: B")
		t.ok(
			string.find(line({ carrying = carry, hoardDistance = 60, nearHoard = true }), "GOLD RING", 1, true),
			"close: run in"
		)
		t.ok(
			string.find(line({ carrying = carry, hoardDistance = 900, inBoat = true }), "SHIFT", 1, true),
			"at the wheel: boost"
		)
		local docks = line({ carrying = carry, hoardDistance = 204 })
		t.ok(string.find(docks, "GOLD RING", 1, true) and not string.find(docks, "B:", 1, true), "on the cove: walk")
		t.ok(
			string.find(line({ carrying = carry, hoardDistance = 900, recallLeft = 12 }), "in 12s", 1, true),
			"says when B is ready"
		)
		t.ok(string.find(line({ swimming = true }), "B calls a boat", 1, true), "swimming: B")
		t.ok(string.find(line({ inWard = true }), "E at a boat", 1, true), "at home: the docks")
		t.ok(
			string.find(line({ nearest = { name = "Giant Pearl", distance = 60 } }), "HOLD E", 1, true),
			"near treasure: hold E"
		)
		t.ok(
			string.find(line({ nearest = { name = "Giant Pearl", distance = 600 } }), "(M: map)", 1, true),
			"far: the map"
		)
		local heart = line({ nearest = { name = "Crystal Heart", distance = 140, way = "through the tunnel" } })
		t.ok(string.find(heart, "through the tunnel: HOLD E", 1, true), "a treasure under a roof says the way in")
		local lagoon = line({ swimming = true, nearest = { name = "Skull Chalice", distance = 90, way = "in" } })
		t.ok(string.find(lagoon, "Skull Chalice", 1, true), "even to a goblin swimming to it")
	end)

	t.test("V13: after the first raids the chip only speaks when it matters", function()
		local veteran = Objective.TEACH_RAIDS
		local function line(state)
			state.phase = "raid"
			state.raids = veteran
			return (Objective.line(state))
		end
		t.eq(line({ inBoat = true }), "", "sailing about: nothing to say")
		t.eq(line({ inWard = true }), "", "at home: nothing to say")
		t.eq(line({ nearest = { name = "Giant Pearl", distance = 600 } }), "", "a far treasure: the map says it")
		local carry = line({ carrying = { name = "Lost Compass", value = 4 }, hoardDistance = 566 })
		t.ok(string.find(carry, "LOST COMPASS", 1, true) and string.find(carry, "B: boat", 1, true), "carrying: short")
		t.ok(#carry < 48, "carrying is a short chip: " .. carry)
		t.ok(
			string.find(line({ nearest = { name = "Giant Pearl", distance = 60 } }), "HOLD E", 1, true),
			"near: hold E"
		)
		t.ok(string.find(line({ swimming = true }), "B: boat", 1, true), "in the water: B")
	end)
end

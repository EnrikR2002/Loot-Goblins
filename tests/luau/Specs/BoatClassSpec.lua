-- V13, the fleet: boat classes, each with a showroom row, an ability, a model and seats, and none of them simply
-- better than another (horizontal balance: every class gives something up for what it is best at).
-- V13.2: ten classes on one speed band (no class wins a crossing by speed), and every one with a bow gun.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local BoatSim = require(Shared.BoatSim)
local Server = ServerScriptService:WaitForChild("LootGoblinsServer")
local BoatModels = require(Server.BoatModels)

local PIPS = { "speed", "handling", "toughness", "air", "firepower" }

-- What a class is worth on the water, as numbers: higher is better in every one.
local function profile(spec)
	return {
		speed = spec.maxSpeed,
		accel = spec.accel,
		turn = spec.turn,
		toughness = spec.health / (spec.crashTaken or 1),
		air = spec.jumpMult or 1,
		crew = spec.passengers or 1,
	}
end

return function(t)
	t.test("ten classes, each in the showroom with a role, five stats and an ability", function()
		t.eq(#Config.BOAT_CLASSES, 10, "ten classes (V13.2: Anchorjack, Wavebreaker and Corsair join the seven)")
		local abilities = {}
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local spec = Config.BOAT_TYPES[row.id]
			t.ok(spec ~= nil and spec.class == true, row.id .. ": not a player class")
			t.ok(type(row.role) == "string" and type(row.best) == "string" and type(row.worst) == "string", row.id)
			for _, stat in ipairs(PIPS) do
				local pips = row.pips[stat]
				t.ok(type(pips) == "number" and pips >= 1 and pips <= 5, row.id .. ": " .. stat .. " pips")
			end
			local ability = Config.BOAT_ABILITIES[spec.ability]
			t.ok(ability ~= nil, row.id .. ": no ability")
			t.ok(ability.cooldown >= 5 and ability.cooldown <= 40, row.id .. ": cooldown")
			t.ok(#ability.name > 0 and #ability.glyph > 0 and #ability.verb > 0, row.id .. ": how the ability is shown")
			t.ok(not abilities[spec.ability], row.id .. ": shares its ability with another class")
			abilities[spec.ability] = true
		end
	end)

	t.test("no class is better than another at everything (horizontal balance)", function()
		local rows = Config.BOAT_CLASSES
		for _, a in ipairs(rows) do
			for _, b in ipairs(rows) do
				if a ~= b then
					local pa, pb = profile(Config.BOAT_TYPES[a.id]), profile(Config.BOAT_TYPES[b.id])
					local better = false
					for key, value in pairs(pb) do
						if value > pa[key] then
							better = true
						end
					end
					t.ok(better, b.id .. " has nothing over " .. a.id .. " (so " .. a.id .. " is simply better)")
				end
			end
		end
		-- And the pips say so too: no class has the most of everything.
		for _, row in ipairs(rows) do
			local sum = 0
			for _, stat in ipairs(PIPS) do
				sum += row.pips[stat]
			end
			t.ok(sum >= 11 and sum <= 15, row.id .. ": pips add up to " .. sum)
		end
	end)

	t.test("every class builds its model on a hull of its size, with a seat for each passenger", function()
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local spec = Config.BOAT_TYPES[row.id]
			local model = Instance.new("Model")
			local hull = Instance.new("Part")
			hull.Name = "Hull"
			hull.Size = spec.size
			hull.Anchored = true
			hull.Parent = model
			local ok, err = pcall(BoatModels.dress, row.id, model, hull, spec.size, Color3.new(1, 1, 1))
			t.ok(ok, row.id .. ": " .. tostring(err))
			t.eq(hull.Size, spec.size, row.id .. ": the look changed the hull")
			local parts = 0
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and p ~= hull then
					parts += 1
					t.ok(not p.CanCollide, row.id .. ": " .. p.Name .. " collides (decoration must not)")
					t.ok(p.Massless, row.id .. ": " .. p.Name .. " has mass")
				end
			end
			t.ok(parts >= 8 and parts <= 160, row.id .. ": " .. parts .. " parts")
			t.eq(#BoatModels.seats(row.id, spec.size), spec.passengers or 1, row.id .. ": a seat per passenger")
			model:Destroy()
		end
	end)

	t.test("abilities have their rule in the shared sim: ready, used, then cooling down", function()
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local spec = Config.BOAT_TYPES[row.id]
			local a = Config.BOAT_ABILITIES[spec.ability]
			local boat = { spec = spec, abilityReadyAt = 0, out = { wet = 1 } }
			t.ok(BoatSim.abilityReady(boat, 10), row.id .. ": ready at first, on the water")
			boat.abilityReadyAt = 10 + a.cooldown
			t.ok(not BoatSim.abilityReady(boat, 11), row.id .. ": cooling down")
			t.ok(BoatSim.abilityReady(boat, 10 + a.cooldown), row.id .. ": ready again")
			boat.out.wet = 0
			t.ok(not BoatSim.abilityReady(boat, 100), row.id .. ": not in the air (the key does a trick there)")
			boat.out.wet, boat.moored = 1, true
			t.ok(not BoatSim.abilityReady(boat, 100), row.id .. ": not at anchor")
		end
	end)

	-- V13.2 ----------------------------------------------------------------------------------------------------------
	-- The time a hull takes to cover `distance` from a standstill and its speed then, on BoatSim's own drive and drag
	-- (Roblox's own water drag is measured and cancelled by BoatSim, so it is left out; no boost, no currents).
	local function crossing(spec, distance)
		local v, x, elapsed, dt = 0, 0, 0, 1 / 60
		local top = spec.maxSpeed
		while x < distance and elapsed < 120 do
			local drive = spec.accel * (1 + Config.BOAT_LAUNCH_PUNCH * math.clamp(1 - v / (top * 0.5), 0, 1))
			local drag = spec.accel / top * v
			v += (drive - drag) * dt
			x += v * dt
			elapsed += dt
		end
		return elapsed, v
	end

	t.test("V13.2: one speed band: top speeds 105 to 120, and nobody reaches top speed much sooner", function()
		local fastest, slowest = 0, math.huge
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local spec = Config.BOAT_TYPES[row.id]
			t.ok(spec.maxSpeed >= 105 and spec.maxSpeed <= 120, row.id .. ": top speed " .. spec.maxSpeed)
			-- Time to 90% of its own top speed.
			local v, time, dt = 0, 0, 1 / 60
			while v < spec.maxSpeed * 0.9 and time < 20 do
				local drive = spec.accel
					* (1 + Config.BOAT_LAUNCH_PUNCH * math.clamp(1 - v / (spec.maxSpeed * 0.5), 0, 1))
				v += (drive - spec.accel / spec.maxSpeed * v) * dt
				time += dt
			end
			t.ok(time >= 3 and time <= 4.2, row.id .. string.format(": 90%% of top in %.2f s", time))
			fastest = math.max(fastest, spec.maxSpeed)
			slowest = math.min(slowest, spec.maxSpeed)
		end
		t.ok(fastest / slowest <= 1.13, "the band is narrow: " .. fastest .. " / " .. slowest)
	end)

	t.test("V13.2: a 3,000-stud crossing from a standstill takes every class about the same time", function()
		local best, worst = math.huge, 0
		local skiff = crossing(Config.BOAT_TYPES.skiff, 3000)
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local time = crossing(Config.BOAT_TYPES[row.id], 3000)
			best, worst = math.min(best, time), math.max(worst, time)
		end
		t.ok(worst / best <= 1.14, string.format("within 14%%: %.1f s to %.1f s", best, worst))
		t.ok(skiff <= best + 0.01 and skiff >= best, "the Skiff is still (just) the quickest on a straight")
		-- V13's spread was 135 to 96 studs/s: about 40% between the Skiff and the Ironbelly.
	end)

	t.test("V13.2: Nitro is an escape burst, not a straight-line win", function()
		local N = Config.BOAT_ABILITIES.nitro
		local skiff = Config.BOAT_TYPES.skiff
		t.ok(N.mult <= Config.BOAT_BOOST_MULT * 1.05, "barely faster than a boost")
		t.ok(N.time <= 1.2, "short")
		t.ok(N.cooldown >= 14, "not often")
		t.ok(N.shrug and N.shrug < 0.5, "it shrugs shoves off")
		-- The most a Nitro can gain over a boat cruising at the same top speed: (mult - 1) * top * time.
		local gain = (N.mult - 1) * skiff.maxSpeed * N.time + N.kick * 0.5
		t.ok(gain < 70, string.format("at most %d studs gained per Nitro (every %d s)", gain, N.cooldown))
	end)

	t.test("V13.2: every ability escapes or disrupts; the anchor and the hook have their numbers", function()
		local ESCAPE = {
			nitro = true,
			rally = true,
			spring = true,
			twister = true,
			slip = true,
			breaker = true,
			anchor = true,
			hook = true,
		}
		local DISRUPT = {
			rally = true,
			volley = true,
			twister = true,
			slip = true,
			plow = true,
			anchor = true,
			breaker = true,
			hook = true,
		}
		for id in pairs(Config.BOAT_ABILITIES) do
			t.ok(ESCAPE[id] or DISRUPT[id], id .. ": neither escapes nor disrupts")
		end
		local A = Config.BOAT_ABILITIES
		t.ok(A.anchor.range > 80 and A.anchor.snag >= 2 and A.anchor.swing >= 1.5, "the anchor reaches and holds")
		t.ok(A.hook.range > A.anchor.range * 0.9 and A.hook.board > 10, "the hook reaches and boards")
		t.ok(A.breaker.radius > 60 and A.breaker.push > A.breaker.edgePush, "the breaker throws near boats hardest")
		t.ok(A.rally.radius > 60 and A.rally.boost > 1, "the horn rallies a convoy")
	end)

	t.test("V13.2: the bow gun shoves more than it hurts, and reloads quickly", function()
		local G = Config.BOAT_GUN
		t.ok(G.knockback > G.damage * 8, "knockback over damage")
		t.ok(G.hullDamage <= 15, "it does not sink boats")
		t.ok(G.cooldown >= 1.5 and G.cooldown <= 4, "a fair reload")
		t.ok(G.arc > 0 and G.arc < 0.7, "fires forward")
		for _, row in ipairs(Config.BOAT_CLASSES) do
			t.ok(Config.BOAT_TYPES[row.id].class == true, row.id .. ": a class (gets a bow gun)")
		end
	end)

	t.test(
		"V13.2: an anchor snag, a swing and a hook become the right chains, and a swing lets go as a sling",
		function()
			local hull = Instance.new("Part")
			hull.Size = Config.BOAT_TYPES.anchorjack.size
			hull.CFrame = CFrame.new(0, 2, 0)
			local rival = Instance.new("Part")
			rival.Size = Config.BOAT_TYPES.skiff.size
			rival.CFrame = CFrame.new(0, 2, -60)
			local boat = BoatSim.new(hull, Config.BOAT_TYPES.anchorjack)
			local A = Config.BOAT_ABILITIES
			t.ok(BoatSim.attach(boat, "anchor", { part = rival }, 10), "snag")
			t.eq(boat.tether.kind, "snag", "a snag on a hull")
			t.ok(math.abs(boat.tether.length - 60) < 0.5, "chain as long as the gap")
			t.ok(math.abs(boat.tether.untilAt - (10 + A.anchor.snag)) < 1e-6, "held for the snag time")
			t.ok(BoatSim.attach(boat, "anchor", { point = Vector3.new(10, 0, -5) }, 10), "swing")
			t.eq(boat.tether.kind, "swing", "a swing on a point")
			t.ok(boat.tether.length >= A.anchor.swingMin, "never shorter than the shortest swing")
			t.eq(BoatSim.release(boat, 11, true), "sling", "let go of a swing: a sling")
			t.eq(boat.tether, nil, "let go")
			t.ok(BoatSim.attach(boat, "hook", { part = rival }, 10), "hook")
			t.eq(boat.tether.kind, "reel", "a hook on a hull reels")
			t.ok(BoatSim.attach(boat, "hook", { point = Vector3.new(0, 0, -50) }, 10), "zip")
			t.eq(boat.tether.kind, "zip", "a hook on a rock zips")
			t.ok(not BoatSim.attach(boat, "anchor", {}, 10), "nothing to attach to")
			hull:Destroy()
			rival:Destroy()
		end
	)
end

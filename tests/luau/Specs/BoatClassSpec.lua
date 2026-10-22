-- V13, the fleet: seven boat classes, each with a showroom row, an ability, a model and seats, and none of them simply
-- better than another (horizontal balance: every class gives something up for what it is best at).
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
	t.test("seven classes, each in the showroom with a role, five stats and an ability", function()
		t.eq(#Config.BOAT_CLASSES, 7, "seven classes")
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
end

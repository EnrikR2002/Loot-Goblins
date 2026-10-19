-- V13.2: the skyship's routes (shared/SkyRoute.lua): finite reach, routes that each reach a fair share of the islands,
-- every island reachable on some routes, a pass of fixed length, and a wait at the start while the cannons are locked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local SkyRoute = require(Shared.SkyRoute)
local Dive = require(Shared.Dive)
local Archipelago = require(Shared.Archipelago)

local S = Config.SKYSHIP

local function majors()
	local list = {}
	for _, island in ipairs(Archipelago.islands) do
		local info = Config.ISLAND_INFO[island.id]
		if info and info.major then
			table.insert(list, island)
		end
	end
	return list
end

return function(t)
	t.test("the cannons' reach is finite: about 1,200 studs, not the whole sea", function()
		local reach = SkyRoute.reach()
		t.ok(reach > 1000 and reach < 1400, "reach " .. math.floor(reach))
		local from = Vector3.new(0, S.POSITION.Y + 4.6, 0)
		local _, inReach =
			Dive.solve(from, Vector3.new(reach - 30, 0, 0), Config.DIVE.CANNON_ELEVATION, Config.DIVE.CANNON_SPEED)
		t.ok(inReach, "just inside the reach: Dive.solve reaches it")
		local _, beyond =
			Dive.solve(from, Vector3.new(reach + 60, 0, 0), Config.DIVE.CANNON_ELEVATION, Config.DIVE.CANNON_SPEED)
		t.ok(not beyond, "just beyond: it cannot (the ring turns red)")
		local _, farIsland =
			Dive.solve(from, Vector3.new(2436, 0, -2044), Config.DIVE.CANNON_ELEVATION, Config.DIVE.CANNON_SPEED)
		t.ok(not farIsland, "Skull Rock from the middle of the sea: out of reach (it was in reach through V13)")
	end)

	t.test(
		"every route reaches 6 to 10 major islands, and every major island is reachable on at least two routes",
		function()
			local reach = SkyRoute.reach()
			local counts = {}
			for index, route in ipairs(S.ROUTES) do
				local points = SkyRoute.points(index, false)
				local reached = 0
				for _, island in ipairs(majors()) do
					local pass = SkyRoute.passBy(points, island.x, island.z, reach)
					if pass.from then
						reached += 1
						counts[island.id] = (counts[island.id] or 0) + 1
					end
				end
				t.ok(reached >= 6 and reached <= 10, route.name .. ": reaches " .. reached)
			end
			for _, island in ipairs(majors()) do
				t.ok((counts[island.id] or 0) >= 2, island.name .. ": on " .. (counts[island.id] or 0) .. " routes")
			end
			t.ok(#S.ROUTES >= 5, "enough routes for variety")
		end
	)

	t.test("a route stays in the sea's bounds, far from the Port, and flies at a speed a goblin can watch", function()
		for index, route in ipairs(S.ROUTES) do
			local points = SkyRoute.points(index, false)
			for _, p in ipairs(points) do
				t.ok(p.X > Config.BOUNDS_MIN.X and p.X < Config.BOUNDS_MAX.X, route.name .. ": x in bounds")
				t.ok(p.Z > Config.BOUNDS_MIN.Z and p.Z < Config.BOUNDS_MAX.Z, route.name .. ": z in bounds")
				t.ok(
					(p - Vector3.new(Config.PORT.CENTER.X, p.Y, Config.PORT.CENTER.Z)).Magnitude
						> Config.PORT.RADIUS + 1500,
					route.name .. ": far from the Port"
				)
			end
			local speed = SkyRoute.length(points) / S.PASS
			t.ok(speed >= 120 and speed <= 240, route.name .. ": " .. math.floor(speed) .. " studs/s")
		end
	end)

	t.test("the ship waits at the start until the cannons unlock, then flies the route in PASS seconds", function()
		local points = SkyRoute.points(1, false)
		local opensAt = 1000
		local waiting = SkyRoute.cframeAt(points, opensAt, opensAt - S.PREP)
		t.ok((waiting.Position - points[1]).Magnitude < 0.5, "at the start during the prep")
		local _, still = SkyRoute.cframeAt(points, opensAt, opensAt - 1)
		t.eq(still, Vector3.zero, "not moving before the bell")
		local half = SkyRoute.cframeAt(points, opensAt, opensAt + S.PASS / 2)
		local middle = SkyRoute.along(points, SkyRoute.length(points) / 2)
		t.ok((half.Position - middle).Magnitude < 1, "halfway at half time")
		local finish = SkyRoute.cframeAt(points, opensAt, opensAt + S.PASS - 0.001)
		t.ok((finish.Position - points[#points]).Magnitude < 10, "at the far end when the pass ends")
		local _, flying = SkyRoute.cframeAt(points, opensAt, opensAt + 5)
		t.ok(math.abs(flying.Magnitude - SkyRoute.length(points) / S.PASS) < 0.01, "its velocity is its speed")
		local heading = (points[#points] - points[1]).Unit
		t.ok(half.LookVector:Dot(Vector3.new(heading.X, 0, heading.Z).Unit) > 0.9, "bow first along the route")
		-- After the pass it swings round and flies the route back (late arrivals): never a jump.
		local speed = SkyRoute.length(points) / S.PASS
		local before = SkyRoute.cframeAt(points, opensAt, opensAt + S.PASS - 0.05).Position
		local after = SkyRoute.cframeAt(points, opensAt, opensAt + S.PASS + 0.05).Position
		t.ok((after - before).Magnitude < speed * 0.2, "no jump at the end of the pass")
		local back, backVelocity = SkyRoute.cframeAt(points, opensAt, opensAt + S.PASS * 1.5)
		t.ok((back.Position - middle).Magnitude < 1, "halfway back after another half pass")
		t.ok(backVelocity:Dot(flying) < 0, "flying the other way")
		local turned = SkyRoute.cframeAt(points, opensAt, opensAt + S.PASS + S.TURN + 0.1)
		t.ok(turned.LookVector:Dot(backVelocity.Unit) > 0.99, "bow first once it has swung round")
		t.eq(S.WINDOW, S.PREP + S.PASS, "the window is the prep and the pass")
		t.ok(S.PREP >= 6 and S.PREP <= 15, "a short, clear prep")
	end)

	t.test(
		"reversed, a route is flown from its other end; an island in reach is in reach at its closest pass",
		function()
			local forward = SkyRoute.points(3, false)
			local back = SkyRoute.points(3, true)
			t.ok((forward[1] - back[#back]).Magnitude < 0.01, "ends swapped")
			local reach = SkyRoute.reach()
			for _, island in ipairs(majors()) do
				local pass = SkyRoute.passBy(forward, island.x, island.z, reach)
				if pass.from then
					local at = SkyRoute.cframeAt(forward, 0, pass.at).Position
					t.ok(
						(Vector3.new(at.X - island.x, 0, at.Z - island.z)).Magnitude <= reach + 1,
						island.name .. ": in reach at its closest pass"
					)
					t.ok(
						pass.from <= pass.at and pass.at <= pass.to,
						island.name .. ": the closest pass is inside its window"
					)
				end
			end
		end
	)
end

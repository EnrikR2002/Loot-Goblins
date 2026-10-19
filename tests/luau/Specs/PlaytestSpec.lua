-- V13.1, the V13 playtest fixes: the knockout's numbers, the Guardian's sky-high tumble, the Leviathan's bite, the
-- called boat's stop, and Poltergoblin switched off. (What needs a running world, the creatures and the pickup by
-- boat, was tested in Studio: docs/reports/2026-10-18-v13-1-playtest-fixes.md.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local BoatSim = require(Shared.BoatSim)

local function near(a, b, within)
	return math.abs(a - b) <= within
end

return function(t)
	t.test("a carrier is knocked out by a handful of creature hits, never by one", function()
		local K = Config.KNOCKOUT
		t.ok(K.TIME == 5, "five seconds down (the playtest's number)")
		local hits = math.ceil(100 / K.HIT)
		t.ok(hits >= 3 and hits <= 6, "a full-health carrier takes " .. hits .. " creature hits")
		t.ok(K.WAKE_GRACE > 0 and K.WAIT > K.TIME, "a moment of grace on waking; pursuers wait past the knockout")
		t.ok(Config.PET_GHOST_KNOCKOUT > 0 and Config.PET_GHOST_KNOCKOUT < 1, "a SPIRIT pet shortens it")
		t.ok(string.find(Config.PET_ABILITIES.Ghost.effect, "knockout", 1, true), "and says so")
	end)

	t.test("Poltergoblin is switched off, and E is free", function()
		t.eq(Config.POLTER_ENABLED, false, "switched off")
		t.ok(Config.POLTER_DURATION > 0, "but its numbers are kept for later")
	end)

	t.test("the Guardian's launch goes sky high, end over end, and lands level", function()
		local GB = Config.GUARDIAN_BOAT
		local height = GB.LIFT * GB.LIFT / (2 * workspace.Gravity)
		t.ok(height > 140, string.format("about %d studs up (V9: about 35)", math.floor(height)))
		t.ok(GB.ALTITUDE > height, "the boat police allow it")
		local tumble = BoatSim.TRICKS.tumble
		t.ok(tumble ~= nil, "a tumble")
		local finish = tumble(1, 1)
		t.ok(
			finish.UpVector:Dot(Vector3.yAxis) > 0.999 and finish.LookVector:Dot(-Vector3.zAxis) > 0.999,
			"level at the end"
		)
		local upsideDown = false
		for i = 1, 19 do
			if tumble(i / 20, 1).UpVector.Y < -0.5 then
				upsideDown = true
			end
		end
		t.ok(upsideDown, "upside down on the way")
	end)

	t.test("a tumble starts from the water and pays nothing", function()
		local hull = Instance.new("Part")
		hull.Size = Config.BOAT_TYPES.skiff.size
		hull.CFrame = CFrame.new(0, 2, 0)
		local boat = BoatSim.new(hull, Config.BOAT_TYPES.skiff)
		t.ok(BoatSim.tumble(boat, 2.5, 1, 100), "it starts on the water")
		t.ok(boat.trick and boat.trick.tumble and near(boat.trick.duration, 2.5, 0.01), "a 2.5 s tumble")
		t.eq(boat.tricksDone, 0, "not a trick of the driver's")
		boat.moored = true
		boat.trick = nil
		t.ok(not BoatSim.tumble(boat, 2.5, 1, 100), "an anchored boat is not thrown")
		hull:Destroy()
	end)

	t.test("the Leviathan's lunge can catch a boat holding its speed", function()
		local L = Config.LEVIATHAN
		-- From its following distance, the lunge's extra speed (reached at L.ACCEL) must close the gap to a bite.
		local reach = 0
		local speed, dt = 0, 1 / 60
		for _ = 1, math.floor(L.LUNGE_TIME / dt) do
			speed = math.min(L.LUNGE_SPEED, speed + L.ACCEL * dt)
			reach += speed * dt
		end
		t.ok(
			reach > L.FOLLOW - L.CONTACT,
			string.format("closes %d studs in a lunge, needs %d", math.floor(reach), L.FOLLOW - L.CONTACT)
		)
		t.ok(L.LUNGE_TELL >= 0.6, "with a tell long enough to boost or turn")
	end)

	t.test("a called boat brakes to a stop within reach", function()
		-- At boost speed, starting to brake at its stopping distance plus the margin, it stops PARK short.
		local v = Config.BOAT_TYPES.skiff.maxSpeed * Config.BOAT_BOOST_MULT
		local stopping = v * v / (2 * Config.RECALL_BRAKE)
		t.ok(stopping < 120, string.format("from %d studs/s it stops in %d studs", math.floor(v), math.floor(stopping)))
		t.ok(Config.RECALL_PARK <= 12, "and parks close")
		t.ok(Config.RECALL_HOLD >= 15, "then holds the spot")
	end)
end

-- V13, the Goblin Port: the round's rules between raids (shared/Lobby.lua) and the Port's isolation from the raid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Lobby = require(Shared.Lobby)
local Archipelago = require(Shared.Archipelago)

local P = Config.PORT

return function(t)
	t.test("the Port's zone: inside, outside, and junk", function()
		t.ok(Lobby.inPort(P.CENTER), "its centre")
		t.ok(Lobby.inPort(P.CENTER + Vector3.new(P.RADIUS - 1, 40, 0)), "near its edge, any height")
		t.ok(not Lobby.inPort(P.CENTER + Vector3.new(P.RADIUS + 1, 0, 0)), "just outside")
		t.ok(not Lobby.inPort(Vector3.zero), "the archipelago")
		t.ok(not Lobby.inPort(nil) and not Lobby.inPort("here"), "junk is not in the Port")
	end)

	t.test("the Port is far out of reach of every island and of Goblin Cove", function()
		for _, island in ipairs(Archipelago.islands) do
			local flat = Vector3.new(island.x - P.CENTER.X, 0, island.z - P.CENTER.Z).Magnitude
			t.ok(flat - P.RADIUS > 1500, island.id .. " is only " .. math.floor(flat) .. " studs from the Port")
		end
	end)

	t.test("late entry: only into a running raid, only while enough of it is left, never twice", function()
		local now = 1000
		local ok, why = Lobby.canJoinLate("raid", now, now + P.LATE_JOIN_MIN + 30, false)
		t.ok(ok and why == nil, "plenty left")
		ok, why = Lobby.canJoinLate("raid", now, now + P.LATE_JOIN_MIN - 1, false)
		t.ok(not ok and why == "late", "too little left")
		ok, why = Lobby.canJoinLate("port", now, now + 300, false)
		t.ok(not ok and why == "noraid", "no raid running")
		ok, why = Lobby.canJoinLate("raid", now, now + 300, true)
		t.ok(not ok and why == "in", "already in it")
		ok = Lobby.canJoinLate("raid", now, "soon", false)
		t.ok(not ok, "a junk end time")
	end)

	t.test(
		"V13.2: the countdown waits for somebody to sign up, is brought forward when all who did are aboard, never pushed back",
		function()
			local now = 500
			local endsAt = now + 40
			-- (now, endsAt, signed up, signed up and aboard, in the server)
			t.eq(Lobby.portEndsAt(now, endsAt, 0, 0, 0), now + P.DURATION, "nobody in the server: held")
			t.eq(Lobby.portEndsAt(now, endsAt, 0, 0, 5), now + P.DURATION, "five goblins, nobody signed up: held")
			t.eq(Lobby.portEndsAt(now, endsAt, 3, 1, 5), endsAt, "some of those signed up aboard: unchanged")
			t.eq(Lobby.portEndsAt(now, endsAt, 3, 3, 5), now + P.READY_SECONDS, "all signed up aboard: soon")
			local soon = now + 2
			t.eq(Lobby.portEndsAt(now, soon, 3, 3, 5), soon, "never later than it already was")
			t.ok(P.READY_SECONDS < P.DURATION and P.DURATION <= 90, "a short Port, a shorter ready countdown")
		end
	)

	t.test("V13.2: a raid only leaves with somebody signed up, and only when the countdown is over", function()
		t.ok(not Lobby.shouldDepart(100, 120, 2), "still counting down")
		t.ok(not Lobby.shouldDepart(130, 120, 0), "over, but nobody signed up: no empty raid")
		t.ok(Lobby.shouldDepart(130, 120, 1), "over, one goblin signed up: it leaves")
	end)

	t.test("a raid with nobody left in it ends", function()
		t.ok(Lobby.raidAbandoned(0), "empty")
		t.ok(Lobby.raidAbandoned(nil), "nil counts as empty")
		t.ok(not Lobby.raidAbandoned(1), "one raider keeps it going")
	end)

	t.test("spectating cycles a stable ring, both ways, and copes with a target who has gone", function()
		local targets = {
			{ userId = 30, name = "zed" },
			{ userId = 10, name = "Ann" },
			{ userId = 20, name = "bob" },
		}
		t.eq(Lobby.cycle(targets, nil, 1), 10, "first by name")
		t.eq(Lobby.cycle(targets, 10, 1), 20, "next")
		t.eq(Lobby.cycle(targets, 20, 1), 30, "next")
		t.eq(Lobby.cycle(targets, 30, 1), 10, "wraps forward")
		t.eq(Lobby.cycle(targets, 10, -1), 30, "wraps back")
		t.eq(Lobby.cycle(targets, 99, 1), 10, "gone: the first")
		t.eq(Lobby.cycle({}, 10, 1), nil, "nobody to watch")
		t.eq(#targets, 3, "the list given is not changed")
		t.eq(targets[1].userId, 30, "nor reordered")
	end)

	t.test("the Port screen's status", function()
		local now = 100
		local raid = Lobby.status("raid", now, now + 200, false)
		t.eq(raid.state, "raid", "raid")
		t.eq(raid.canJoin, true, "can join")
		t.eq(math.floor(raid.seconds), 200, "seconds left")
		local late = Lobby.status("raid", now, now + 30, false)
		t.eq(late.canJoin, false, "too late to join")
		local port = Lobby.status("port", now, now + 42, false)
		t.eq(port.state, "countdown", "counting down")
		t.eq(Lobby.status("port", now, now, false).state, "boarding", "time's up")
		t.eq(Lobby.status("port", now, now + 42, false, 0).state, "waiting", "V13.2: nobody signed up: waiting")
		t.eq(Lobby.status("port", now, now + 42, false, 2).state, "countdown", "two signed up: counting down")
	end)
end

-- V13.3: the Port's seven games (shared/PortGames.lua): what a run pays and the daily caps, medals, and the shapes
-- the server judges with (the Regatta's checkpoints, the Gauntlet's platforms, a golf shot, the Derby's track and its
-- judge, a throw or a cannonball meeting a target). Pure: no server, no players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Lobby = require(Shared.Lobby)
local PortGames = require(Shared.PortGames)
local ProfileSchema = require(ServerScriptService:WaitForChild("LootGoblinsServer").ProfileSchema)

local G = Config.PLAYGROUND
local DAY = 86400
local NOW = 20747 * DAY + 3600

local function fresh()
	return ProfileSchema.load(nil, nil, 0)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

return function(t)
	t.test("seven games, each with a venue inside the Port and a medal ladder", function()
		t.eq(#PortGames.GAMES, 7, "seven")
		for _, def in ipairs(PortGames.GAMES) do
			local venue = PortGames.VENUES[def.id]
			t.ok(venue ~= nil, def.id .. ": venue")
			t.ok(Lobby.inPort(venue.join) and Lobby.inPort(venue.zone), def.id .. ": inside the Port's zone")
			if def.id ~= "derby" then
				local medals = G[string.upper(def.id)].MEDALS
				t.ok(medals.gold and medals.silver and medals.bronze, def.id .. ": medals")
				if def.kind == "time" then
					t.ok(medals.gold < medals.silver and medals.silver < medals.bronze, def.id .. ": faster is better")
				else
					t.ok(medals.gold > medals.silver and medals.silver > medals.bronze, def.id .. ": more is better")
				end
			end
		end
		t.eq(PortGames.medal("regatta", G.REGATTA.MEDALS.gold - 1), "gold", "a fast lap")
		t.eq(PortGames.medal("regatta", 999), nil, "a slow one")
		t.eq(PortGames.medal("golf", G.GOLF.MEDALS.bronze), "bronze", "bronze golf")
		t.eq(PortGames.medal("derby", 30, 1), "gold", "the Derby's medal is the place")
		t.eq(PortGames.medal("derby", 30, 4), nil, "fourth")
	end)

	t.test("a run pays a little; the first score is not a beaten record; a better one is", function()
		local profile = fresh()
		local first = PortGames.finishRun(profile, "regatta", 50, 1, 1, NOW)
		t.ok(not first.best, "a first score is not a beaten record")
		t.eq(profile.games.best.regatta, 50, "but it is the best now")
		t.eq(first.parts.played, G.REWARD.played, "played")
		t.eq(first.won, false, "a solo race is not a win")
		local better = PortGames.finishRun(profile, "regatta", 41, 1, 3, NOW)
		t.ok(better.best, "beat it")
		t.ok(better.won, "won a heat of three")
		t.eq(better.parts.best, G.REWARD.best, "best bonus")
		t.eq(better.parts.winner, G.REWARD.winner, "winner bonus")
		local worse = PortGames.finishRun(profile, "regatta", 60, 2, 3, NOW)
		t.ok(not worse.best, "slower is not a best")
		t.eq(profile.games.best.regatta, 41, "best kept")
		t.eq(profile.games.plays.regatta, 3, "three finished runs")
		local dnf = PortGames.finishRun(profile, "regatta", nil, nil, 3, NOW)
		t.eq(dnf.medal, nil, "no medal without a finish")
		t.eq(profile.games.plays.regatta, 3, "a run that did not finish is not a play")
	end)

	t.test("the daily caps hold: runs per game, Shinies per day, best bonuses per day; tomorrow they reset", function()
		local profile = fresh()
		for _ = 1, G.DAILY_RUNS do
			PortGames.finishRun(profile, "toss", 1, 1, 1, NOW)
		end
		local over = PortGames.finishRun(profile, "toss", 1, 1, 1, NOW)
		t.eq(over.shinies, 0, "the seventh paid run of a game pays nothing")
		t.eq(over.capped, "runs", "because of the run cap")
		-- Shinies across games stop at the day's cap.
		local total = profile.games.earned
		for _, game in ipairs({ "regatta", "golf", "gallery", "crabs", "gauntlet", "derby" }) do
			for i = 1, G.DAILY_RUNS do
				local score = (game == "regatta" or game == "gauntlet" or game == "derby") and (100 - i) or (1000 + i)
				local r = PortGames.finishRun(profile, game, score, 1, 2, NOW)
				total += r.shinies
			end
		end
		t.eq(profile.games.earned, G.DAILY_SHINIES, "earned exactly the day's cap")
		t.ok(total <= G.DAILY_SHINIES, "never more")
		t.ok(profile.games.bests <= G.DAILY_BESTS, "best bonuses capped")
		-- Tomorrow.
		local tomorrow = PortGames.finishRun(profile, "toss", 50, 1, 1, NOW + DAY)
		t.ok(tomorrow.shinies > 0, "a new day pays again")
		t.eq(profile.games.runs.toss, 1, "counts from zero")
		t.ok(profile.games.best.regatta ~= nil, "bests are kept for ever")
		t.eq(PortGames.tried(profile), 7, "all seven tried")
	end)

	t.test("a checkpoint is crossed by a fast boat between two ticks, and missed beside it", function()
		local center = Vector3.new(0, 0, 0)
		t.ok(PortGames.crossed(Vector3.new(-50, 0, 3), Vector3.new(50, 0, 3), center, 10), "straight through")
		t.ok(not PortGames.crossed(Vector3.new(-50, 0, 30), Vector3.new(50, 0, 30), center, 10), "beside it")
		t.ok(PortGames.crossed(Vector3.new(2, 0, 2), Vector3.new(2, 0, 2), center, 10), "standing in it")
		t.ok(not PortGames.crossed(Vector3.new(20, 0, 0), Vector3.new(40, 0, 0), center, 10), "short of it")
	end)

	t.test("the Regatta: thirteen checkpoints round the island, the Teeth's two ways, a grid that fits", function()
		local R = PortGames.REGATTA
		t.eq(#R.checkpoints, G.REGATTA.CHECKPOINTS + 1, "twelve and the Teeth")
		t.eq(R.finish, #R.checkpoints, "the last is the line")
		local last = R.checkpoints[R.finish].discs[1].center
		t.ok((flat(last) - flat(PortGames.ring(0))).Magnitude < 1, "the finish is the start line")
		local teeth
		for _, cp in ipairs(R.checkpoints) do
			for _, disc in ipairs(cp.discs) do
				t.ok(Lobby.inPort(disc.center), "every checkpoint is inside the Port's zone")
			end
			if cp.teeth then
				teeth = cp
			end
		end
		t.ok(teeth and #teeth.discs == 2, "the Teeth: the channel or round the outside")
		-- The checkpoints go round in order.
		for i = 2, #R.checkpoints do
			t.ok(R.checkpoints[i].theta > R.checkpoints[i - 1].theta, "in order " .. i)
		end
		t.eq(#R.grid, G.REGATTA.MAX, "a slot for every racer")
		for i = 1, #R.grid do
			for j = i + 1, #R.grid do
				t.ok((R.grid[i].Position - R.grid[j].Position).Magnitude >= 20, "grid slots apart")
			end
			-- Each starts behind the line, facing the first checkpoint's way.
			t.ok(R.grid[i].LookVector:Dot(PortGames.ringHeading(0)) > 0.95, "facing along the lap")
		end
		-- Nothing of the course is on the island or near another venue.
		for _, id in ipairs({ "gauntlet", "golf", "gallery" }) do
			local zone = PortGames.VENUES[id].zone
			t.ok(
				(flat(zone) - flat(PortGames.ISLAND)).Magnitude < G.REGATTA.RADIUS - G.REGATTA.GATE_RADIUS,
				id .. " clear of the course"
			)
		end
		local back = PortGames.regattaRespawn(7) -- the Teeth's checkpoint
		t.ok((flat(back.Position) - flat(PortGames.ring(210))).Magnitude < 1, "never put back inside the Teeth")
	end)

	t.test(
		"the Gauntlet: eight platforms in order, each inside its checkpoint, each within reach of the last",
		function()
			local GA = PortGames.GAUNTLET
			t.eq(#GA.checkpoints, 8, "eight")
			t.eq(GA.checkpoints[#GA.checkpoints].name, "FINISH", "ends at the bell")
			local previous = GA.start.center
			for i, cp in ipairs(GA.checkpoints) do
				local platform = GA.platforms[i]
				t.ok(
					PortGames.inBox(platform.center + Vector3.new(0, 3, 0), cp.box),
					cp.name .. ": standing on it counts"
				)
				t.ok(
					not PortGames.inBox(platform.center + Vector3.new(0, -30, 0), cp.box),
					cp.name .. ": below it does not"
				)
				t.ok((flat(platform.center) - flat(previous)).Magnitude <= 95, cp.name .. ": not too far from the last")
				t.ok(Lobby.inPort(platform.center), cp.name .. ": in the Port")
				t.ok(platform.center.Y > G.GAUNTLET.FALL_Y + 20, cp.name .. ": well above the water")
				previous = platform.center
			end
		end
	)

	t.test("Cannon Golf: power and aim are held inside the tee's limits, and the far green is in reach", function()
		local GF = G.GOLF
		local golf = PortGames.GOLF
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 0).Magnitude - GF.MIN_SPEED) < 0.01, "no power: the softest")
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 1).Magnitude - GF.MAX_SPEED) < 0.01, "full power")
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 7).Magnitude - GF.MAX_SPEED) < 0.01, "clamped power")
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 0 / 0).Magnitude - GF.MIN_SPEED) < 0.01, "NaN power")
		local backwards = PortGames.golfVelocity(-golf.facing, 0.5)
		local angle = math.deg(math.acos(flat(backwards).Unit:Dot(golf.facing)))
		t.ok(angle <= GF.YAW_MAX + 0.5, "aiming backwards is pulled round to the limit")
		-- The farthest a full shot goes over level water (the dive's gravity).
		local g = Config.DIVE.GRAVITY
		local reach = GF.MAX_SPEED ^ 2 * math.sin(2 * GF.ELEVATION) / g
		for _, green in ipairs(golf.greens) do
			local d = (flat(green.center) - flat(golf.jettyEnd)).Magnitude
			t.ok(d < reach - 20, green.name .. " is in reach")
			t.ok(d > 60, green.name .. " is not on the jetty")
			t.ok(Lobby.inPort(green.center), green.name .. " in the Port")
		end
		t.eq(PortGames.golfPoints(0), GF.POINTS.cup, "in the cup")
		t.eq(PortGames.golfPoints(GF.GREEN), GF.POINTS.green, "edge of the green")
		t.eq(PortGames.golfPoints(GF.FRINGE + 0.1), GF.POINTS.miss, "a splash")
	end)

	t.test("the Derby: every lane runs the same fraction, the judge's window is fair", function()
		local D = PortGames.DERBY
		t.ok(D.length > 150, "a proper oval")
		local a = PortGames.derbyPoint(0, 1)
		local b = PortGames.derbyPoint(1, 1)
		t.ok((a - b).Magnitude < 0.05, "a lap comes back to the start")
		local inner = PortGames.derbyPoint(0.3, 1)
		local outer = PortGames.derbyPoint(0.3, 6)
		t.ok(
			(flat(outer) - flat(D.center)).Magnitude > (flat(inner) - flat(D.center)).Magnitude,
			"lane 6 is outside lane 1"
		)
		local _, heading = PortGames.derbyPoint(0, 1)
		t.ok(heading.X > 0.9, "the start runs east, in front of the stand")
		for i = 2, #D.hurdles do
			t.ok(D.hurdles[i] > D.hurdles[i - 1] and D.hurdles[i] < 1, "hurdles in order")
		end
		local DG = G.DERBY
		t.eq(PortGames.derbyJudge(0.3), "clean", "in the window")
		t.eq(
			PortGames.derbyJudge(-DG.LATE + 0.01),
			"clean",
			"a hair late is still clean (the server sees the pet late)"
		)
		t.eq(PortGames.derbyJudge(DG.EARLY + 0.1), "early", "too soon")
		t.eq(PortGames.derbyJudge(DG.TOO_EARLY + 1), "none", "no hurdle near")
		t.eq(PortGames.derbyJudge(-1), "none", "long past")
		t.eq(PortGames.derbyJudge(nil), "none", "no hurdle left")
		-- V13.4: the perfect heart sits inside the clean window, never outside it.
		t.eq(PortGames.derbyJudge(0.1), "perfect", "the heart of the window")
		t.eq(PortGames.derbyJudge(DG.PERFECT_EARLY + 0.01), "clean", "just early of perfect is clean")
		t.eq(PortGames.derbyJudge(-DG.PERFECT_LATE - 0.01), "clean", "just late of perfect is clean")
		t.ok(DG.PERFECT_EARLY < DG.EARLY and DG.PERFECT_LATE < DG.LATE, "perfect is inside clean")
		t.ok(DG.FIRE > DG.ZOOM and DG.PERFECT_TIME > DG.ZOOM_TIME, "a streak and a perfect jump are worth more")
	end)

	t.test("V13.4: a Gauntlet shortcut counts, and range streaks pay a little more", function()
		local GA = PortGames.GAUNTLET
		local p3 = GA.platforms[3].center + Vector3.new(0, 3, 0)
		t.eq(PortGames.gauntletReached(p3, 1), 3, "landing on the third platform from the start skips two")
		t.eq(PortGames.gauntletReached(p3, 4), nil, "a platform already passed does not count again")
		t.eq(PortGames.gauntletReached(GA.start.center + Vector3.new(0, 3, 0), 1), nil, "the start is not a checkpoint")
		local finish = GA.platforms[#GA.platforms].center + Vector3.new(0, 3, 0)
		t.eq(PortGames.gauntletReached(finish, 1), #GA.checkpoints, "the bell is the last")
		local streak, points = 0, 0
		local total = 0
		for _, hit in ipairs({ true, true, true, true, false, true }) do
			streak, points = PortGames.rangeShot(streak, hit, 2)
			total += points
		end
		local S = G.STREAK
		t.eq(streak, 1, "a miss ended the streak; the next hit starts again")
		t.eq(total, 5 * 2 + (4 - S.FROM + 1) * S.BONUS, "the bonus from the streak's third hit on")
	end)

	t.test("a throw lands in a basket coming down, not going up; a closed mouth eats nothing", function()
		local spot = Vector3.new(0, 10, 40)
		local range = { targets = { {
			at = function()
				return spot
			end,
			radius = 3,
			basket = true,
		} } }
		local g = G.TOSS.GRAVITY
		-- A lob from (0, 10, 0) that comes down through the spot 40 studs away: the up-and-down of a 1.2 s flight.
		local time = 1.2
		local velocity = Vector3.new(0, g * time / 2, 40 / time)
		local index = PortGames.shotHit(range, Vector3.new(0, 10, 0), velocity, g, 100, 1, 0, 3)
		t.eq(index, 1, "into the basket")
		-- A throw that passes the spot on the way up only.
		local rising = PortGames.shotHit(range, Vector3.new(0, 4, 38), Vector3.new(0, 30, 2), g, 100, 1, 0, 0.2)
		t.eq(rising, nil, "rising through it does not count")
		local mouth = {
			targets = {
				{
					at = function()
						return spot
					end,
					radius = 3,
					open = function()
						return false
					end,
				},
			},
		}
		t.eq(PortGames.shotHit(mouth, Vector3.new(0, 10, 0), velocity, g, 100, 1, 0, 3), nil, "a closed mouth")
		-- The booth's limits on the aim.
		t.eq(PortGames.tossDirection(Vector3.new(0 / 0, 1, 0)), nil, "nonsense")
		local up = PortGames.tossDirection(Vector3.new(0.01, 1, 0))
		t.ok(math.deg(math.asin(up.Y)) <= G.TOSS.PITCH_MAX + 0.01, "not straight up")
		local behind = PortGames.tossDirection(Vector3.new(-1, 0.2, 0))
		t.ok(behind:Dot(PortGames.TOSS.facing) > 0, "never behind you")
	end)

	t.test("the gallery's cannonball arcs onto where it is aimed", function()
		local from = PortGames.GALLERY.stations[1].muzzle
		local target = from + PortGames.GALLERY.facing * 200 + Vector3.new(0, -8, 0)
		local velocity = PortGames.cannonVelocity(from, target)
		local g = G.GALLERY.GRAVITY
		local flatSpeed = flat(velocity).Magnitude
		local time = (flat(target) - flat(from)).Magnitude / flatSpeed
		local y = from.Y + velocity.Y * time - 0.5 * g * time * time
		t.ok(math.abs(y - target.Y) < 1.5, "it comes down on the spot")
		t.ok(math.abs(velocity.Magnitude - G.GALLERY.SPEED) < 0.01, "at the cannon's own speed")
	end)

	t.test("every range target stays out in front of its booth", function()
		for _, pair in ipairs({
			{ PortGames.TOSS, PortGames.TOSS.spots[1].Position },
			{ PortGames.GALLERY, PortGames.GALLERY.deck },
		}) do
			local range, origin = pair[1], pair[2]
			for index in ipairs(range.targets) do
				for s = 0, 60, 0.7 do
					local at = PortGames.targetAt(range, index, 1000 + s)
					local ahead = (flat(at) - flat(origin)):Dot(range.facing)
					t.ok(ahead > 10, "target " .. index .. " in front")
					t.ok(Lobby.inPort(at), "target " .. index .. " in the Port")
				end
			end
		end
	end)
end

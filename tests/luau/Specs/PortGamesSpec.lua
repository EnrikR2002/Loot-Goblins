-- V13.3: the Port's games (shared/PortGames.lua): what a run pays and the daily caps, medals, and the shapes the server
-- judges with. V13.5: three games (the Derby, the Toss, the Gallery and Crab Chaos removed); the Regatta's new circuit,
-- its test drives and their per-boat records; Cannon Golf's six holes, its skimmer's sea and its strokes. Pure: no
-- server, no players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Dive = require(Shared.Dive)
local Lobby = require(Shared.Lobby)
local PortGames = require(Shared.PortGames)
local Seasons = require(Shared.Seasons)
local ProfileSchema = require(ServerScriptService:WaitForChild("LootGoblinsServer").ProfileSchema)

local G = Config.PLAYGROUND
local DAY = 86400
local NOW = 20747 * DAY + 3600
local C = Config.PORT.CENTER

local function fresh()
	return ProfileSchema.load(nil, nil, 0)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Port-relative (x, z) of a world point.
local function rel(p)
	return p.X - C.X, p.Z - C.Z
end

-- Copied from server/Port.lua's buildTerrain: the island's lobes, { x, z, sand radius } from the Port's centre.
local LOBES =
	{ { 0, 60, 205 }, { -95, 130, 90 }, { 110, 120, 96 }, { 130, -10, 80 }, { -130, -30, 74 }, { 30, 205, 70 } }

-- How far a world point is out in the water from the island's coast (negative: on the island).
local function offshore(p)
	local x, z = rel(p)
	local best = math.huge
	for _, lobe in ipairs(LOBES) do
		best = math.min(best, math.sqrt((x - lobe[1]) ^ 2 + (z - lobe[2]) ^ 2) - lobe[3])
	end
	return best
end

-- The flat distance from a point to the Regatta's lap (its nearest segment) and that segment's lane half-width.
local function toLap(p)
	local line = PortGames.REGATTA.line
	local best, w = math.huge, 0
	for i = 1, #line do
		local d = PortGames.toSegment(p, line[i].p, line[i % #line + 1].p)
		if d < best then
			best, w = d, line[i].w
		end
	end
	return best, w
end

return function(t)
	t.test("V13.5: three games, each with a venue inside the Port and a medal ladder", function()
		t.eq(#PortGames.GAMES, 3, "the Regatta, the Gauntlet and Cannon Golf")
		for _, def in ipairs(PortGames.GAMES) do
			local venue = PortGames.VENUES[def.id]
			t.ok(venue ~= nil, def.id .. ": venue")
			t.ok(Lobby.inPort(venue.join) and Lobby.inPort(venue.zone), def.id .. ": inside the Port's zone")
			local medals = G[string.upper(def.id)].MEDALS
			t.ok(medals.gold and medals.silver and medals.bronze, def.id .. ": medals")
			t.ok(PortGames.lowerWins(def.id), def.id .. ": less is better (a time, or strokes)")
			t.ok(medals.gold < medals.silver and medals.silver < medals.bronze, def.id .. ": gold is the fewest")
		end
		t.eq(PortGames.medal("regatta", G.REGATTA.MEDALS.gold - 1), "gold", "a fast lap")
		t.eq(PortGames.medal("regatta", 999), nil, "a slow one")
		t.eq(PortGames.medal("golf", G.GOLF.MEDALS.bronze), "bronze", "bronze golf")
		t.eq(PortGames.medal("golf", PortGames.GOLF.par), "silver", "a round at par is silver")
		t.ok(PortGames.better("golf", 15, 16), "fewer strokes are better")
	end)

	t.test("V13.5: the removed games are gone from every list, their tuning and their quests", function()
		for _, id in ipairs({ "derby", "toss", "gallery", "crabs" }) do
			t.eq(PortGames.BY_ID[id], nil, id .. " is not a game")
			t.eq(PortGames.VENUES[id], nil, id .. " has no venue")
			t.eq(G[string.upper(id)], nil, id .. " has no tuning")
		end
		t.eq(G.STREAK, nil, "the ranges' streaks went with them")
		for _, name in ipairs({ "DERBY", "TOSS", "GALLERY", "CRABS" }) do
			t.eq(PortGames[name], nil, name .. " shapes are gone")
		end
		local gone = { toss_points = true, crabs = true, gallery_hits = true, game_derby = true }
		for _, list in pairs(Seasons.QUESTS) do
			for _, def in ipairs(list) do
				t.ok(not gone[def.event], def.id .. " counts a removed game")
				t.ok(def.go == nil or PortGames.BY_ID[def.go] ~= nil, def.id .. " points at a game that is gone")
				if def.event == "game_distinct" then
					t.ok(def.goal <= #PortGames.GAMES, def.id .. " asks for more games than the Port has")
				end
			end
		end
		-- What goblins earned stays theirs: the Derby's trophy and laurel still exist, are offered to nobody new, and
		-- the Port Regular asks for exactly the games there are.
		local laurel = Catalog.get("pethat_laurel")
		t.ok(laurel ~= nil and not laurel.retired, "the Derby Laurel is still wearable by its owners")
		t.ok(laurel.unearnable, "and no longer offered")
		local derby = Catalog.achievementById.derby_winner
		t.ok(derby ~= nil and derby.unearnable, "Derby Day is kept for those who have it and unlocks for nobody else")
		t.eq(Catalog.achievementById.port_regular.goal, #PortGames.GAMES, "Port Regular: every game the Port has")
	end)

	t.test("a run pays a little; the first score is not a beaten record; a better one is", function()
		local profile = fresh()
		local first = PortGames.finishRun(profile, "gauntlet", 50, 1, 1, NOW)
		t.ok(not first.best, "a first score is not a beaten record")
		t.eq(profile.games.best.gauntlet, 50, "but it is the best now")
		t.eq(first.parts.played, G.REWARD.played, "played")
		t.eq(first.won, false, "a solo run is not a win")
		local better = PortGames.finishRun(profile, "gauntlet", 41, 1, 3, NOW)
		t.ok(better.best, "beat it")
		t.ok(better.won, "won a heat of three")
		t.eq(better.parts.best, G.REWARD.best, "best bonus")
		t.eq(better.parts.winner, G.REWARD.winner, "winner bonus")
		local worse = PortGames.finishRun(profile, "gauntlet", 60, 2, 3, NOW)
		t.ok(not worse.best, "slower is not a best")
		t.eq(profile.games.best.gauntlet, 41, "best kept")
		t.eq(profile.games.plays.gauntlet, 3, "three finished runs")
		local dnf = PortGames.finishRun(profile, "gauntlet", nil, nil, 3, NOW)
		t.eq(dnf.medal, nil, "no medal without a finish")
		t.eq(profile.games.plays.gauntlet, 3, "a run that did not finish is not a play")
	end)

	t.test("V13.5: a Regatta lap's best is its boat's own; the old course's best is kept but never compared", function()
		local profile = fresh()
		profile.games.best.regatta = 41.5 -- a V13.4 lap of the old ring course
		local tub = PortGames.recordKey("regatta", "racer")
		local skiff = PortGames.recordKey("regatta", "skiff")
		t.ok(tub ~= skiff and tub ~= "regatta", "a key per boat, and not the old course's")
		local first = PortGames.finishRun(profile, "regatta", 30, 1, 1, NOW, tub)
		t.ok(not first.best, "the new course's first tub lap is a first score, not a beaten 41.5")
		local skiffLap = PortGames.finishRun(profile, "regatta", 26, 1, 1, NOW, skiff)
		t.ok(not skiffLap.best and skiffLap.previous == nil, "the Skiff's first lap is its own first")
		t.eq(profile.games.best[tub], 30, "the tub's best")
		t.eq(profile.games.best[skiff], 26, "the Skiff's best")
		t.eq(profile.games.best.regatta, 41.5, "the old course's best is left as it was")
		t.eq(profile.games.plays.regatta, 2, "both laps count as Regatta plays (quests, Port Regular)")
		t.eq(profile.games.runs.regatta, 2, "and both count against the one daily cap: switching boats farms nothing")
		t.eq(PortGames.recordKey("golf"), "golf2", "a golf round in strokes is its own record too")
	end)

	t.test("the daily caps hold: runs per game, Shinies per day, best bonuses per day; tomorrow they reset", function()
		local profile = fresh()
		for _ = 1, G.DAILY_RUNS do
			PortGames.finishRun(profile, "golf", 20, 1, 1, NOW)
		end
		local over = PortGames.finishRun(profile, "golf", 20, 1, 1, NOW)
		t.eq(over.shinies, 0, "the seventh paid run of a game pays nothing")
		t.eq(over.capped, "runs", "because of the run cap")
		-- Test drives in every boat still pay from the Regatta's one cap (a fresh goblin, slow laps with no medal, so the
		-- day's Shiny cap is not what stops them).
		local driver = fresh()
		local classes = { "racer" }
		for _, row in ipairs(Config.BOAT_CLASSES) do
			table.insert(classes, row.id)
		end
		local paid = 0
		for i, class in ipairs(classes) do
			local r = PortGames.finishRun(driver, "regatta", 60 + i, 1, 2, NOW, PortGames.recordKey("regatta", class))
			paid += r.shinies > 0 and 1 or 0
		end
		t.eq(paid, G.DAILY_RUNS, "eleven boats, six paid laps")
		t.eq(driver.games.runs.regatta, G.DAILY_RUNS, "all on the Regatta's one cap")
		PortGames.finishRun(profile, "regatta", 30, 1, 2, NOW, PortGames.recordKey("regatta"))
		for i = 1, G.DAILY_RUNS do
			PortGames.finishRun(profile, "gauntlet", 100 - i, 1, 2, NOW)
		end
		t.ok(profile.games.earned <= G.DAILY_SHINIES, "never more than the day's cap")
		t.ok(profile.games.bests <= G.DAILY_BESTS, "best bonuses capped")
		local tomorrow = PortGames.finishRun(profile, "golf", 18, 1, 1, NOW + DAY)
		t.ok(tomorrow.shinies > 0, "a new day pays again")
		t.eq(profile.games.runs.golf, 1, "counts from zero")
		t.eq(PortGames.tried(profile), 3, "all three tried")
		profile.games.plays.derby = 4 -- a V13.4 goblin's Derby runs
		t.eq(PortGames.tried(profile), 3, "a removed game is not counted (the Port Regular never asks for it)")
	end)

	t.test("a checkpoint is crossed by a fast boat between two ticks, and missed beside it", function()
		local center = Vector3.new(0, 0, 0)
		t.ok(PortGames.crossed(Vector3.new(-50, 0, 3), Vector3.new(50, 0, 3), center, 10), "straight through")
		t.ok(not PortGames.crossed(Vector3.new(-50, 0, 30), Vector3.new(50, 0, 30), center, 10), "beside it")
		t.ok(PortGames.crossed(Vector3.new(2, 0, 2), Vector3.new(2, 0, 2), center, 10), "standing in it")
		t.ok(not PortGames.crossed(Vector3.new(20, 0, 0), Vector3.new(40, 0, 0), center, 10), "short of it")
	end)

	t.test(
		"V13.5: the Regatta's circuit is all open water inside the Port, clear of the island and the dock",
		function()
			local R = PortGames.REGATTA
			t.ok(#R.line >= 16, "a real circuit, not a ring")
			for i, point in ipairs(R.line) do
				local x, z = rel(point.p)
				t.ok(
					math.sqrt(x * x + z * z) + point.w <= Config.PORT.RADIUS - 10,
					"point " .. i .. ": its lane is in the Port"
				)
				-- Every stretch of lane keeps off the island, sampled along it.
				local nextPoint = R.line[i % #R.line + 1]
				for k = 0, 10 do
					local p = point.p:Lerp(nextPoint.p, k / 10)
					t.ok(
						offshore(p) >= point.w + 40,
						string.format("stretch %d: its lane keeps 40 studs off the coast", i)
					)
				end
			end
			-- The dock's end (243, 62) and the lane: no boat should be launched at the planks.
			local dockEnd = PortGames.world(243, 0, 62)
			local d, w = toLap(dockEnd)
			t.ok(d - w >= 12, string.format("the lane passes %.0f studs off the dock's end", d - w))
			-- The other venues are nowhere near it.
			for _, id in ipairs({ "gauntlet", "golf" }) do
				local gap, lane = toLap(PortGames.VENUES[id].zone)
				t.ok(gap - lane > 200, id .. " is far from the course")
			end
			t.ok(R.length > 1900 and R.length < 2600, string.format("a lap of %.0f studs (about 25 s)", R.length))
			t.ok(R.shortcutLength < 0.6 * 333, "the Teeth's channel is a real shortcut")
		end
	)

	t.test("V13.5: the Regatta's checkpoints run in order round the lap, and the Teeth has exactly two ways", function()
		local R = PortGames.REGATTA
		t.eq(R.finish, #R.checkpoints, "the last is the line")
		t.ok(
			(flat(R.checkpoints[R.finish].discs[1].center) - flat(R.line[1].p)).Magnitude < 1,
			"the finish is the start"
		)
		local lastAt = 1
		local teeth
		for i, cp in ipairs(R.checkpoints) do
			for _, disc in ipairs(cp.discs) do
				t.ok(Lobby.inPort(disc.center), cp.name .. ": inside the Port")
			end
			if i < R.finish then
				t.ok(cp.at > lastAt, cp.name .. ": after the one before it")
				lastAt = cp.at
			end
			if cp.teeth then
				teeth = cp
			end
		end
		t.ok(teeth and #teeth.discs == 2, "the Teeth: the channel or round")
		local channel, safe = teeth.discs[1], teeth.discs[2]
		-- The safe way never crosses the channel's disc, and the channel never the safe way's.
		for i = 13, 15 do
			local d = PortGames.toSegment(channel.center, R.line[i].p, R.line[i + 1].p)
			t.ok(
				d - R.line[i].w > channel.radius,
				"the safe way, stretch " .. i .. ", keeps off the channel's checkpoint"
			)
		end
		local s = PortGames.toSegment(safe.center, R.shortcut.from, R.shortcut.to)
		t.ok(s > safe.radius + R.shortcut.half, "the channel keeps off the safe way's checkpoint")
		-- The channel's rocks leave the safe way's lane clear (sampled along it, in the channel's own frame).
		local T = R.shortcut
		for i = 13, 15 do
			for k = 0, 16 do
				local p = flat(R.line[i].p:Lerp(R.line[i + 1].p, k / 16) - T.from)
				local along, side = p:Dot(T.along), p:Dot(T.toward)
				if along >= T.startAt - 4 and along <= T.endAt + 4 then
					t.ok(
						side - R.line[i].w >= T.half + T.near,
						string.format("the Teeth's rocks off the safe lane (%d/%d)", i, k)
					)
				end
			end
		end
		-- Put back after the Teeth: on the far side, facing on.
		local back = PortGames.regattaRespawn(7)
		t.ok((flat(back.Position) - flat(R.line[16].p)).Magnitude < 1, "never put back inside the Teeth")
		for i = 1, R.finish - 1 do
			local cf = PortGames.regattaRespawn(i)
			local cp = R.checkpoints[i]
			t.ok(cf.LookVector:Dot(PortGames.regattaHeading(cp.at)) > 0.99, cp.name .. ": put back facing on")
		end
	end)

	t.test("V13.5: the Regatta's grid fits the biggest boats; its obstacles sit where they should", function()
		local R = PortGames.REGATTA
		t.eq(#R.grid, G.REGATTA.MAX, "a slot for every racer")
		local widest, longest = 0, 0
		for _, row in ipairs(Config.BOAT_CLASSES) do
			local size = Config.BOAT_TYPES[row.id].size
			widest, longest = math.max(widest, size.X), math.max(longest, size.Z)
		end
		for i = 1, #R.grid do
			for j = i + 1, #R.grid do
				local a = R.grid[i]:PointToObjectSpace(R.grid[j].Position)
				t.ok(math.abs(a.X) >= widest + 4 or math.abs(a.Z) >= longest + 2, "slots " .. i .. "/" .. j .. " apart")
			end
			t.ok(R.grid[i].LookVector:Dot(PortGames.regattaHeading(1)) > 0.99, "facing up the Pier Straight")
			local d, w = toLap(R.grid[i].Position)
			t.ok(d <= w - widest / 2, "slot " .. i .. " is on the lane")
		end
		-- The rocks are beside the lane, the barrels and buoys on it.
		for _, rock in ipairs({ R.lighthouse, R.flumeRock }) do
			local d, w = toLap(rock.center)
			t.ok(d - w >= rock.radius, "a rock clear of the lane")
		end
		for _, c in ipairs(R.cannons) do
			local d, w = toLap(c.rock)
			t.ok(d - w >= 13, "a splash cannon's rock beside the lane")
			t.ok(offshore(c.rock) > 20, "and in the water")
		end
		for _, list in ipairs({ R.barrels, R.buoys }) do
			for _, p in ipairs(list) do
				local d, w = toLap(p)
				t.ok(d <= w - 5, "on the lane, with room round it")
			end
		end
		local reefGap, reefLane = toLap(R.reef.center)
		t.ok(reefGap < 10 and R.reef.half < reefLane - 12, "the reef crosses the lane's middle, gaps at its edges")
		t.ok(R.highHoop.at.Y > 20, "the high hoop only a jump reaches")
	end)

	t.test("V13.5: test-drive abilities work on the Regatta's water and nowhere else in the Port", function()
		local R = PortGames.REGATTA
		for i, point in ipairs(R.line) do
			t.ok(PortGames.onRegatta(point.p), "line point " .. i)
		end
		t.ok(PortGames.onRegatta(R.grid[1].Position), "the grid")
		for _, spot in ipairs({
			PortGames.world(0, 6, 0), -- the plaza
			PortGames.VENUES.regatta.zone, -- the dock: spectators are safe
			PortGames.VENUES.golf.zone,
			PortGames.VENUES.gauntlet.zone,
			PortGames.world(0, 6, -120), -- the boarding pier
		}) do
			t.ok(not PortGames.onRegatta(spot), "not on the course: " .. tostring(spot - C))
		end
		t.ok(not PortGames.onRegatta(nil), "nonsense is not the course")
		-- MIN_TIME refuses only the impossible: the shortcut's lap at the fastest boat's boosted top speed all the way.
		local fastest = 0
		for _, row in ipairs(Config.BOAT_CLASSES) do
			fastest = math.max(fastest, Config.BOAT_TYPES[row.id].maxSpeed)
		end
		local lap = R.length - 333 + R.shortcutLength
		t.ok(lap / (fastest * Config.BOAT_BOOST_MULT) > G.REGATTA.MIN_TIME, "a believable lap is never refused")
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
				-- V13.5: put back on it facing the next platform.
				local nextOne = GA.platforms[i + 1]
				if nextOne then
					local way = flat(nextOne.center - platform.center).Unit
					t.ok(flat(cp.respawn.LookVector).Unit:Dot(way) > 0.99, cp.name .. ": put back facing the next")
				end
				t.ok(PortGames.inBox(cp.respawn.Position, cp.box), cp.name .. ": put back on it")
				previous = platform.center
			end
			for _, h in ipairs(GA.hooks) do
				t.ok(h.leg >= 1 and h.leg < #GA.platforms, "every hook serves a leg")
			end
		end
	)

	t.test("V13.4: a Gauntlet shortcut counts", function()
		local GA = PortGames.GAUNTLET
		local p3 = GA.platforms[3].center + Vector3.new(0, 3, 0)
		t.eq(PortGames.gauntletReached(p3, 1), 3, "landing on the third platform from the start skips two")
		t.eq(PortGames.gauntletReached(p3, 4), nil, "a platform already passed does not count again")
		t.eq(PortGames.gauntletReached(GA.start.center + Vector3.new(0, 3, 0), 1), nil, "the start is not a checkpoint")
		local finish = GA.platforms[#GA.platforms].center + Vector3.new(0, 3, 0)
		t.eq(PortGames.gauntletReached(finish, 1), #GA.checkpoints, "the bell is the last")
	end)

	t.test("V13.5: Cannon Golf's aim and power are held inside the tee's limits, the elevation too", function()
		local GF = G.GOLF
		local golf = PortGames.GOLF
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 0).Magnitude - GF.MIN_SPEED) < 0.01, "no power: the softest")
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 1).Magnitude - GF.MAX_SPEED) < 0.01, "full power")
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 7).Magnitude - GF.MAX_SPEED) < 0.01, "clamped power")
		t.ok(math.abs(PortGames.golfVelocity(golf.facing, 0 / 0).Magnitude - GF.MIN_SPEED) < 0.01, "NaN power")
		local backwards = PortGames.golfVelocity(-golf.facing, 0.5)
		local angle = math.deg(math.acos(flat(backwards).Unit:Dot(golf.facing)))
		t.ok(angle <= GF.YAW_MAX + 0.5, "aiming backwards is pulled round to the limit")
		local function elevation(v)
			return math.deg(math.asin(v.Unit.Y))
		end
		t.ok(math.abs(elevation(PortGames.golfVelocity(golf.facing, 1)) - math.deg(GF.ELEVATION)) < 0.1, "a flat aim")
		local straightUp = PortGames.golfVelocity(Vector3.new(0, 1, 0) + golf.facing * 0.01, 1)
		t.ok(elevation(straightUp) <= math.deg(GF.ELEVATION_MAX) + 0.1, "never straight up")
		local down = PortGames.golfVelocity(golf.facing - Vector3.new(0, 0.9, 0), 1)
		t.ok(elevation(down) >= math.deg(GF.ELEVATION_MIN) - 0.1, "never into the jetty")
		t.ok(PortGames.golfVelocity(Vector3.new(0 / 0, 0, 0), 1).Magnitude > 0, "nonsense aims straight out")
	end)

	t.test(
		"V13.5: a skimmer skips like a stone: shallow arrivals skip on, flatter each time; steep ones plop",
		function()
			local S = Config.DIVE.SKIM
			local shallow = Vector3.new(100, -40, 0)
			local away = Dive.bounce(shallow, 1, "tumble", true)
			t.ok(away ~= nil, "a shallow arrival skips")
			t.ok(math.abs(flat(away).Magnitude - 100 * S.KEEP) < 0.01, "keeping its share of the speed across")
			t.ok(math.abs(away.Y - 40 * S.BOUNCE) < 0.01, "and leaving lower than it came")
			t.ok(away.Y / flat(away).Magnitude < 40 / 100, "each skip flatter than the last")
			t.eq(Dive.bounce(Vector3.new(40, -80, 0), 1, "tumble", true), nil, "a steep lob plops")
			t.eq(Dive.bounce(shallow, 1, "glide", true), nil, "a glide never skips: it is how you stop")
			t.eq(Dive.bounce(Vector3.new(30, -10, 0), 1, "tumble", true), nil, "too slow to skip: it sinks in")
			t.eq(Dive.bounce(shallow, S.MAX + 1, "tumble", true), nil, "a limit to the skips")
			t.ok(
				Dive.bounce(Vector3.new(60, -100, 0), 1, "tumble") ~= nil,
				"a skydiver's sea is unchanged (a fast fall)"
			)
			-- A whole full-power skimmer over open water: it skips several times and stays inside the Port.
			local golf = PortGames.GOLF
			local function sea()
				return 0.5, true
			end
			local best = 0
			for e = 18, 38, 4 do
				local direction = golf.facing * math.cos(math.rad(e)) + Vector3.new(0, math.sin(math.rad(e)), 0)
				local v = PortGames.golfVelocity(direction, 1)
				local _, touches = Dive.predict(golf.tees[2].from, v, "tumble", sea, nil, 0, true)
				local last = touches[#touches].position
				local x, z = rel(last)
				t.ok(math.sqrt(x * x + z * z) < Config.PORT.RADIUS - 20, e .. " degrees: it comes down inside the Port")
				best = math.max(best, #touches - 1)
			end
			t.ok(best >= 3, "a good skimmer skips three times or more")
		end
	)

	t.test("V13.5: six holes out on the water, each reachable the way it is meant to be played", function()
		local golf = PortGames.GOLF
		local GF = G.GOLF
		t.eq(#golf.holes, 6, "six holes")
		local par = 0
		local lobReach = GF.MAX_SPEED ^ 2 / Config.DIVE.GRAVITY -- a 45-degree throw over level water
		for i, hole in ipairs(golf.holes) do
			par += hole.par
			t.ok(Lobby.inPort(hole.center), hole.name .. ": in the Port")
			t.ok(offshore(hole.center) > hole.radius + 30, hole.name .. ": out on the water")
			t.ok(hole.cup < hole.radius, hole.name .. ": the cup is on the target")
			t.ok(hole.par >= 2 and hole.par <= 3, hole.name .. ": par 2 or 3")
			local far = (flat(hole.center) - flat(golf.jettyEnd)).Magnitude
			if hole.par == 2 then
				t.ok(far < lobReach - 30, hole.name .. ": a par 2 can be reached with one lob")
			end
			for j = i + 1, #golf.holes do
				t.ok((flat(hole.center) - flat(golf.holes[j].center)).Magnitude > 100, "holes apart")
			end
		end
		t.eq(par, golf.par, "par is the holes' par")
		t.eq(golf.holes[2].par, 3, "the Skipping Stone is too far to fly")
		t.ok((flat(golf.holes[2].center) - flat(golf.jettyEnd)).Magnitude > lobReach + 40, "...so it must be skipped")
		-- The Bend's stacks stand on the straight line; Over the Top's ridge between the tee and its green.
		local bend = golf.holes[3]
		for _, stack in ipairs(bend.rocks) do
			local d = PortGames.toSegment(stack.at, golf.jettyEnd, bend.center)
			t.ok(d < 25, "a stack in the way")
		end
		local over = golf.holes[5]
		local mid = (over.ridge.from + over.ridge.to) / 2
		t.ok(PortGames.toSegment(mid, golf.jettyEnd, over.center) < 2, "the ridge on the line")
		-- Nothing of one hole stands in another hole's straight line.
		for i, hole in ipairs(golf.holes) do
			for j, other in ipairs(golf.holes) do
				if i ~= j then
					for _, stack in ipairs(other.rocks or {}) do
						if PortGames.toSegment(stack.at, golf.jettyEnd, hole.center) < 15 then
							t.ok(
								(flat(stack.at) - flat(golf.jettyEnd)).Magnitude
									> (flat(hole.center) - flat(golf.jettyEnd)).Magnitude,
								"a stack behind, not in front of, " .. hole.name
							)
						end
					end
				end
			end
		end
	end)

	t.test("V13.5: golf in strokes: the cup is that stroke, the target one putt more, a pickup has a limit", function()
		local hole = PortGames.GOLF.holes[1]
		local on = hole.center + Vector3.new(hole.radius - 1, 0, 0)
		t.eq((PortGames.golfJudge(hole, hole.center + Vector3.new(1, 0, 0), false)), "cup", "in the cup")
		t.eq((PortGames.golfJudge(hole, on, false)), "green", "on the green")
		t.eq((PortGames.golfJudge(hole, on, true)), "miss", "in the water beside it is a miss")
		t.eq((PortGames.golfJudge(hole, hole.center + Vector3.new(hole.radius + 20, 0, 0), false)), "miss", "off it")
		t.eq((PortGames.golfJudge(hole, nil, true)), "miss", "no landing at all")
		t.eq(PortGames.golfStrokes(hole, 1, "cup"), 1, "a hole in one")
		t.eq(PortGames.golfStrokes(hole, 1, "green"), 2, "on in one, one putt")
		t.eq(PortGames.golfStrokes(hole, 1, "miss"), nil, "a splash: the hole goes on")
		t.eq(PortGames.golfStrokes(hole, hole.par + 1, "miss"), hole.par + G.GOLF.PICKUP, "picked up")
		t.ok(
			PortGames.golfStrokes(hole, hole.par + 1, "green") < hole.par + G.GOLF.PICKUP,
			"holing out always beats a pickup"
		)
		t.eq(PortGames.toPar(16, 16), "E", "even")
		t.eq(PortGames.toPar(18, 16), "+2", "over")
		t.eq(PortGames.toPar(14, 16), "-2", "under")
		t.eq(PortGames.golfName(1, 3), "HOLE IN ONE!", "an ace")
		t.eq(PortGames.golfName(2, 3), "BIRDIE!", "a birdie")
		t.eq(PortGames.golfName(3, 3), "PAR", "par")
		-- The worst round there can be is still finished in time.
		local shots = 0
		for _, h in ipairs(PortGames.GOLF.holes) do
			shots += h.par + 1
		end
		t.ok(shots * (G.GOLF.RETURN + 9) < G.GOLF.LIMIT, "every shot of the slowest round fits the clock")
	end)

	t.test("V13.4: a challenge shows each goblin their own score, even when it is missing", function()
		local a, b = PortGames.sides(true, nil, 40.1)
		t.eq(a, nil, "the first goblin did not finish: no score of their own")
		t.eq(b, 40.1, "they see the other's time as theirs")
		local c, d = PortGames.sides(true, 30, nil)
		t.eq(c, 30, "the first goblin finished")
		t.eq(d, nil, "and the other did not")
		local e, f = PortGames.sides(false, 30, nil)
		t.eq(e, nil, "the second goblin has no score")
		t.eq(f, 30, "their opponent's is 30")
		local g, h = PortGames.sides(false, 30, 41)
		t.eq(g, 41, "the second goblin's own")
		t.eq(h, 30, "the first's")
	end)

	t.test("V13.4: the Hall of Legends stands clear of the Shipyard's quay and the Wardrobe", function()
		local H = PortGames.HALL
		-- Copied from server/Port.lua: the quay is 56 by 228 round (-112, 24); the Wardrobe's floor 34 by 24 round (0, 112).
		local quay = { x0 = -140, x1 = -84, z0 = -90, z1 = 138 }
		local shop = { x0 = -17, x1 = 17, z0 = 100, z1 = 124 }
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local x, z = PortGames.podiumToPort(H.x + sx * H.width / 2, H.z + sz * H.depth / 2)
				local onQuay = x >= quay.x0 and x <= quay.x1 and z >= quay.z0 and z <= quay.z1
				local onShop = x >= shop.x0 - 2 and x <= shop.x1 + 2 and z >= shop.z0 and z <= shop.z1
				t.ok(not onQuay, string.format("corner (%.0f, %.0f) is on the quay", x, z))
				t.ok(not onShop, string.format("corner (%.0f, %.0f) is on the Wardrobe", x, z))
			end
		end
		-- And behind the podium's statue and banner (the podium frame's z runs back from the podium).
		t.ok(H.z - H.depth / 2 >= 13, "the stage starts behind the champion's plinth and banner poles")
	end)
end

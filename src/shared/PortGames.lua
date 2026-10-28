-- The Port's games (V13.3, The Living Port; V13.5, The Curated Port): where every venue stands and the rules that need
-- no server, as data and pure functions. Shared, so the server (server/Minigames.lua and one module per game) judges
-- with exactly the shapes, paths and numbers each client draws (client/PlayHud.lua), and the tests (tests/luau/Specs/
-- PortGamesSpec.lua) can check them.
--
--   TINY BOAT REGATTA   (V13.5) one lap of a circuit in the east water: the Pier Straight, the Lighthouse Bend, the
--                       Leap (a ramp and a reef, the high hoop over it), the Flume (a hairpin with a current that
--                       carries you round: the banked turn), Barrel Alley, the Teeth (a narrow channel through the
--                       rocks, or the long way round), the Bumper Chicane, Cannon Corner and the Home Straight. In the
--                       Racing Tub, or on a TEST DRIVE in any of the ten boats.
--   GRAPPLE GAUNTLET    a course in the air over the north-west water: bounce pads, swing hooks, a beam, a zipline
--   CANNON GOLF         (V13.5) six holes over the south-west water, in strokes: lob, or skim and skip off the sea
--
-- V13.5 removed the Pet Derby, Treasure Toss, the Target Ship Gallery and Crab Chaos (the team's call after playtests;
-- their code is in Git history). What goblins earned in them is kept: Shinies, cosmetics, achievements, stats.
--
-- Places are given relative to the Port's centre (Config.PORT.CENTER; north is -Z, like the sea) and turned into the
-- world by PortGames.world.
local Config = require(script.Parent:WaitForChild("Config"))
local Seasons = require(script.Parent:WaitForChild("Seasons"))

local PortGames = {}

local C = Config.PORT.CENTER
local G = Config.PLAYGROUND
local v3 = Vector3.new
local rad = math.rad

function PortGames.world(x, y, z)
	return v3(C.X + x, y, C.Z + z)
end
local W = PortGames.world

-- The island's middle (the town is a little south of the Port's centre): the sanctuary's isles ring it.
PortGames.ISLAND = W(0, 0, 40)

-- The games, in the order the Port lists them. kind: "time" (less is better), "strokes" (less is better: golf) or
-- "points"; unit: what a score is; concurrent: every goblin (or challenge pair) gets a run of their own at once; board:
-- the leaderboard it feeds; record: the key a goblin's personal best is kept under (V13.5: a new course is a new key,
-- so a best from the old course is never compared with the new one; the old keys stay in profiles untouched).
PortGames.GAMES = {
	{
		id = "regatta",
		name = "Tiny Boat Regatta",
		short = "REGATTA",
		icon = "⛵",
		color = Color3.fromRGB(80, 190, 255),
		kind = "time",
		unit = "s",
		max = G.REGATTA.MAX,
		board = "regatta2",
		record = "regatta2",
		hint = "Race the lap: the Leap, the Flume, the Teeth's gap. Pick any boat to test-drive it.",
	},
	{
		id = "gauntlet",
		name = "Grapple Gauntlet",
		short = "GAUNTLET",
		icon = "🎣",
		color = Color3.fromRGB(255, 196, 70),
		kind = "time",
		unit = "s",
		concurrent = true,
		max = 2,
		board = "gauntlet",
		hint = "Bounce, swing (F) and zip to the bell. Fall and you're back at the last platform.",
	},
	{
		id = "golf",
		name = "Cannon Golf",
		short = "GOLF",
		icon = "⛳",
		color = Color3.fromRGB(120, 230, 110),
		kind = "strokes",
		unit = "strokes",
		concurrent = true,
		max = 2,
		board = "golf2",
		record = "golf2",
		hint = "Look up to lob, down to skim: a low shot skips off the sea. Hold to charge, let go to fire.",
	},
}
PortGames.BY_ID = {}
local byRecord = {} -- a best's key in profile.games.best (PortGames.recordKey, without a ":class") -> its game
for index, def in ipairs(PortGames.GAMES) do
	def.order = index
	PortGames.BY_ID[def.id] = def
	byRecord[def.record or def.id] = def
end

-- Is less better in this game? (Times and strokes.) Takes a game id or a record key ("golf2", "regatta2:dory").
function PortGames.lowerWins(gameId)
	local def = PortGames.BY_ID[gameId] or (type(gameId) == "string" and byRecord[string.match(gameId, "^[^:]*")])
	return def ~= nil and def.kind ~= "points"
end

-- The key a personal best is kept under in profile.games.best (V13.5: a Regatta best is kept per boat class).
function PortGames.recordKey(gameId, class)
	local def = PortGames.BY_ID[gameId]
	local key = def and def.record or gameId
	if gameId == "regatta" then
		return key .. ":" .. (class or "racer")
	end
	return key
end

-- Where each game is joined (a prompt) and the zone its lobby waits in. (Relative to the Port's centre.)
PortGames.VENUES = {
	regatta = { join = W(176, 7.5, 62), zone = W(200, 6, 62), radius = 44, sign = W(176, 18, 52) },
	gauntlet = { join = W(-100, 8, -100), zone = W(-105, 6, -105), radius = 20, sign = W(-96, 20, -92) },
	golf = { join = W(-140, 8, 200), zone = W(-152, 6, 214), radius = 30, sign = W(-132, 18, 192) },
}

-- Ground the town's scenery (palms) keeps off: every venue, and the Port's other pieces. { x, z, radius }.
PortGames.KEEP_CLEAR = {
	{ 205, 62, 40 }, -- the Regatta dock
	{ -150, 212, 32 }, -- the golf jetty
	{ -105, -105, 24 }, -- the Gauntlet's start
	{ 52, 76, 16 }, -- the Sanctuary Lift
	{ -34, -70, 12 }, -- the Captain's Quest Board
	{ 30, 205, 46 }, -- (V13.5) the Lookout Green
	{ -85, 175, 34 }, -- (V13.5) the Clubhouse Beach
	{ 110, 110, 30 }, -- (V13.5) the Regatta Promenade
}
function PortGames.clearOf(x, z)
	for _, c in ipairs(PortGames.KEEP_CLEAR) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < c[3] * c[3] then
			return false
		end
	end
	return true
end

-- THE HALL OF LEGENDS (V13.4; built by server/Leaderboards.lua) -----------------------------------------------------------
-- Its stage in the podium's frame (the podium stands at (-56, 52) from the Port's centre, turned -45 degrees; x runs to
-- its right, z straight back from it): the stage's middle and size. It fits the gap between the Shipyard's quay (its east
-- edge is 84 studs west of the Port's centre) and the Wardrobe's west wall (17 studs west of it): PortGamesSpec checks it.
PortGames.HALL = { x = 27, z = 21, width = 77, depth = 10 }

-- A point in the podium's frame -> the Port-relative (x, z) it is at.
function PortGames.podiumToPort(lx, lz)
	local c, s = math.cos(rad(-45)), math.sin(rad(-45))
	return -56 + lx * c + lz * s, 52 - lx * s + lz * c
end

-- Medals ----------------------------------------------------------------------------------------------------------------
-- A score's medal ("gold" | "silver" | "bronze" | nil).
function PortGames.medal(gameId, score)
	local def = PortGames.BY_ID[gameId]
	local medals = G[string.upper(gameId)] and G[string.upper(gameId)].MEDALS
	if not def or not medals or type(score) ~= "number" then
		return nil
	end
	local lower = PortGames.lowerWins(gameId)
	for _, name in ipairs({ "gold", "silver", "bronze" }) do
		local need = medals[name]
		if need and ((lower and score <= need) or (not lower and score >= need)) then
			return name
		end
	end
	return nil
end

function PortGames.better(gameId, a, b)
	if a == nil then
		return false
	elseif b == nil then
		return true
	end
	if PortGames.lowerWins(gameId) then
		return a < b
	end
	return a > b
end

-- A challenge's two scores as one side sees them: (mine, theirs). A plain if, because `isA and sa or sb` returns the
-- other score whenever sa is nil (a goblin who did not finish), showing a goblin the opponent's time as their own.
function PortGames.sides(isA, sa, sb)
	if isA then
		return sa, sb
	end
	return sb, sa
end

-- A goblin's daily counters (profile.games), brought up to the UTC day of `unix`.
local function today(profile, unix)
	local g = profile.games
	local day = Seasons.period("day", unix)
	if g.day ~= day then
		g.day = day
		g.runs = {}
		g.earned = 0
		g.bests = 0
	end
	return g
end
PortGames.today = today

-- A finished run (the server measured `score`; `place` among the humans and `humans` how many raced). Records the
-- best and the play, pays within the daily caps, and returns what happened:
--   { medal, best (a new personal best), previous, won, shinies, parts = { played, medal, winner, best }, capped }
-- `score` nil means a run that did not finish (no best, no medal: only "played" if it counted at all). recordKey
-- (V13.5): where the best is kept (PortGames.recordKey); plays, wins and the daily caps are always the game's own.
function PortGames.finishRun(profile, gameId, score, place, humans, unix, recordKey)
	local g = today(profile, unix)
	local R = G.REWARD
	local key = recordKey or PortGames.recordKey(gameId)
	local out = { parts = {}, shinies = 0, capped = false }
	out.medal = score ~= nil and PortGames.medal(gameId, score) or nil
	out.won = score ~= nil and place == 1 and (humans or 1) >= 2
	out.previous = g.best[key]
	if score ~= nil and PortGames.better(gameId, score, out.previous) then
		out.best = out.previous ~= nil -- the very first run is a first score, not a beaten record
		g.best[key] = score
	end
	if score ~= nil then
		g.plays[gameId] = (g.plays[gameId] or 0) + 1
	end
	if out.won then
		g.wins[gameId] = (g.wins[gameId] or 0) + 1
	end
	-- What it would pay...
	local parts = out.parts
	parts.played = R.played
	if out.medal then
		parts.medal = R[out.medal] or 0
	end
	if out.won then
		parts.winner = R.winner
	end
	if out.best and g.bests < G.DAILY_BESTS then
		parts.best = R.best
	end
	local total = 0
	for _, value in pairs(parts) do
		total += value
	end
	-- ...and what the caps allow.
	local runs = g.runs[gameId] or 0
	if runs >= G.DAILY_RUNS then
		total, out.capped = 0, "runs"
	end
	local room = math.max(0, G.DAILY_SHINIES - g.earned)
	if total > room then
		total, out.capped = room, "day"
	end
	if total > 0 then
		g.runs[gameId] = runs + 1
		g.earned += total
		if parts.best then
			g.bests += 1
		end
		profile.shinies += total
	end
	out.shinies = total
	return out
end

-- How many different games a profile has finished (the Port Regular achievement's stat). Only the games the Port has
-- now count, so a goblin is never asked for one that is gone.
function PortGames.tried(profile)
	local n = 0
	for id in pairs(profile.games.plays or {}) do
		if PortGames.BY_ID[id] then
			n += 1
		end
	end
	return n
end

-- Geometry helpers --------------------------------------------------------------------------------------------------------
-- Does the segment a-b (flat) pass within `radius` of `center`? (A fast boat can cross a checkpoint between ticks.)
function PortGames.crossed(a, b, center, radius)
	local ax, az, bx, bz = a.X, a.Z, b.X, b.Z
	local dx, dz = bx - ax, bz - az
	local length2 = dx * dx + dz * dz
	local t = 0
	if length2 > 1e-6 then
		t = math.clamp(((center.X - ax) * dx + (center.Z - az) * dz) / length2, 0, 1)
	end
	local px, pz = ax + dx * t - center.X, az + dz * t - center.Z
	return px * px + pz * pz <= radius * radius
end

function PortGames.inBox(position, box)
	local d = position - box.center
	return math.abs(d.X) <= box.half.X and math.abs(d.Y) <= box.half.Y and math.abs(d.Z) <= box.half.Z
end

local function flatUnit(x, z)
	local m = math.sqrt(x * x + z * z)
	return m > 1e-6 and v3(x / m, 0, z / m) or v3(0, 0, -1)
end

local function flatOf(v)
	return v3(v.X, 0, v.Z)
end

-- Turns a flat direction by `degrees` (positive: to the right when looking along it from above, north up).
local function turn(direction, degrees)
	local a = rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return flatUnit(direction.X * c - direction.Z * s, direction.X * s + direction.Z * c)
end
PortGames.turn = turn

-- The flat distance from p to the segment a-b, and how far along it (0..1) the nearest point is.
local function toSegment(p, a, b)
	local dx, dz = b.X - a.X, b.Z - a.Z
	local length2 = dx * dx + dz * dz
	local t = length2 > 1e-6 and math.clamp(((p.X - a.X) * dx + (p.Z - a.Z) * dz) / length2, 0, 1) or 0
	return math.sqrt((a.X + dx * t - p.X) ^ 2 + (a.Z + dz * t - p.Z) ^ 2), t
end
PortGames.toSegment = toSegment

-- TINY BOAT REGATTA (V13.5) ------------------------------------------------------------------------------------------------
-- The racing line: Port-relative x and z and the lane's half-width there, a closed loop starting on the start line and
-- running clockwise seen from above (north up the Pier Straight, east along the north, round the Flume at the east end,
-- back west through the Teeth and the Chicane, north up the Home Straight). It takes the SAFE way round the Teeth; the
-- channel through them (regatta.shortcut) runs straight from point 13 to point 16. Every point is open water: the
-- spec checks the lane against the island's coast, the dock and the Port's edge.
local LINE = {
	{ 320, 40, 55 }, -- 1 the start and finish line
	{ 320, -200, 50 }, -- 2 the end of the Pier Straight
	{ 350, -330, 50 }, -- 3 the LIGHTHOUSE BEND
	{ 430, -400, 50 }, -- 4
	{ 530, -410, 50 }, -- 5
	{ 610, -370, 50 }, -- 6 THE LEAP: the ramp is just before here, the reef just after
	{ 690, -310, 52 }, -- 7
	{ 715, -215, 55 }, -- 8 THE FLUME: its current carries you round the hairpin
	{ 735, -110, 55 }, -- 9
	{ 700, -10, 55 }, -- 10
	{ 630, 40, 50 }, -- 11
	{ 560, 90, 46 }, -- 12 BARREL ALLEY
	{ 520, 150, 46 }, -- 13 THE TEETH: the channel goes straight on to 16; the safe way swings out east
	{ 590, 225, 48 }, -- 14
	{ 530, 325, 48 }, -- 15
	{ 420, 300, 44 }, -- 16
	{ 360, 370, 40 }, -- 17 the BUMPER CHICANE
	{ 290, 330, 40 }, -- 18
	{ 250, 250, 46 }, -- 19 CANNON CORNER
	{ 300, 150, 52 }, -- 20 the HOME STRAIGHT
}
local RG = G.REGATTA
local regatta = {}
PortGames.REGATTA = regatta
regatta.line = {}
for i, row in ipairs(LINE) do
	regatta.line[i] = { p = W(row[1], 0, row[2]), w = row[3] }
end
local line = regatta.line
local function linePoint(i)
	return line[(i - 1) % #line + 1].p
end

-- The way the lap runs from point i to the next.
function PortGames.regattaHeading(i)
	local a, b = linePoint(i), linePoint(i + 1)
	return flatUnit(b.X - a.X, b.Z - a.Z)
end
local heading = PortGames.regattaHeading

-- A point beside the line: `along` studs on from point i towards the next, `side` studs to the right of the way.
function PortGames.regattaAt(i, along, side)
	local d = heading(i)
	local right = v3(-d.Z, 0, d.X)
	return linePoint(i) + d * (along or 0) + right * (side or 0)
end
local at = PortGames.regattaAt

regatta.length = 0 -- the safe lap, along its middle
for i = 1, #line do
	regatta.length += flatOf(linePoint(i + 1) - linePoint(i)).Magnitude
end

-- THE TEETH: the channel through the rocks (half its width) and the rocks either side of it: `near` thick on the side
-- the safe way goes round (`toward`, a flat unit vector), `far` thick on the infield's. The rocks run from `startAt` to
-- `endAt` studs along the channel: its mouths are open water where the safe way leaves and rejoins the line.
do
	local from, to = line[13].p, line[16].p
	local along = flatUnit(to.X - from.X, to.Z - from.Z)
	local toward = v3(along.Z, 0, -along.X)
	local round = line[14].p - from
	if toward:Dot(round) < 0 then
		toward = -toward
	end
	local length = flatOf(to - from).Magnitude
	regatta.shortcut = {
		from = from,
		to = to,
		along = along,
		toward = toward,
		half = 11,
		near = 30,
		far = 40,
		startAt = 26,
		endAt = length - 44,
	}
	regatta.shortcutLength = length
end

-- The checkpoints, in order: each a list of discs, any of which counts (the Teeth's: the channel, or the safe way).
-- `at` is the line point a goblin who falls out after passing it is put back at, facing on along the lap.
local function gate(name, index)
	return { name = name, at = index, discs = { { center = line[index].p, radius = line[index].w + 8, line = index } } }
end
regatta.checkpoints = {
	gate("THE PIER STRAIGHT", 2),
	gate("THE LIGHTHOUSE BEND", 4),
	gate("THE LEAP", 7),
	gate("THE FLUME", 9),
	gate("THE FLUME'S EXIT", 11),
	gate("BARREL ALLEY", 13),
	{
		name = "THE TEETH",
		teeth = true,
		at = 16, -- never put back inside the Teeth
		discs = {
			{ center = (line[13].p + line[16].p) / 2, radius = regatta.shortcut.half + 1 },
			{ center = line[15].p, radius = line[15].w + 8, line = 15 },
		},
	},
	gate("THE BUMPER CHICANE", 18),
	gate("CANNON CORNER", 19),
	gate("THE FINISH", 1),
}
regatta.finish = #regatta.checkpoints -- the last checkpoint is the start line: crossing it ends the lap

-- The start grid: three rows of three behind the line, facing up the Pier Straight, roomy enough for the biggest
-- classes (an Ironbelly is 18 by 36).
regatta.grid = {}
do
	local start, way = line[1].p, heading(1)
	local right = v3(-way.Z, 0, way.X)
	for i = 1, RG.MAX do
		local row, col = (i - 1) // 3, (i - 1) % 3
		local p = start - way * (28 + row * 42) + right * ((col - 1) * 26)
		table.insert(regatta.grid, CFrame.lookAt(p, p + way))
	end
	regatta.startLine = { a = start - right * (line[1].w + 6), b = start + right * (line[1].w + 6) }
end

-- What stands on the water (server/Regatta.lua builds it; the hoops and the ramp are BoatSim gates).
regatta.hoops = {
	{ at = at(1, 90), dir = heading(1) }, -- two on the Pier Straight: a chain
	{ at = at(1, 175), dir = heading(1) },
	{ at = at(10, 50), dir = heading(10) }, -- out of the Flume
	{
		at = (line[13].p + line[16].p) / 2,
		dir = flatUnit(line[16].p.X - line[13].p.X, line[16].p.Z - line[13].p.Z),
		small = true,
	}, -- in the Teeth: the shortcut's reward
	{ at = at(19, 55), dir = heading(19) }, -- out of Cannon Corner
}
regatta.ramp = { at = at(5, flatOf(line[6].p - line[5].p).Magnitude - 22), dir = heading(5), width = 20 }
-- The reef the Leap jumps: rocks across the middle of the lane just past the ramp (gaps at its edges for the careful).
do
	local d = flatUnit(heading(5).X + heading(6).X, heading(5).Z + heading(6).Z)
	local centre = line[6].p + d * 30
	regatta.reef = { center = centre, dir = d, half = 30 }
	regatta.highHoop = { at = centre + v3(0, 27, 0), dir = d } -- only a jump off the ramp reaches it
end
regatta.flume = { from = 7, to = 11 } -- line points the current runs between
regatta.lighthouse = { center = W(425, 0, -295), radius = 18 }
regatta.flumeRock = { center = W(630, 0, -140), radius = 32 }
regatta.barrels = {} -- a staggered field to weave through
for i = 0, 11 do -- (twelve: the last stops short of the Teeth's fork)
	local along = 18 + i * 11
	local index = along < 86 and 11 or 12
	local into = index == 11 and along or along - 86
	table.insert(regatta.barrels, at(index, into, ((i * 37) % 7 - 3) * 10))
end
regatta.buoys = {} -- the chicane's big bumper buoys, side to side
for i = 0, 5 do
	local index = i < 3 and 16 or 17
	table.insert(regatta.buoys, at(index, 22 + (i % 3) * 26, (i % 2 == 0) and -18 or 18))
end
regatta.cannons = { -- splash cannons on rocks outside the lane, each watching its stretch
	{ rock = W(190, 0, 280) },
	{ rock = W(600, 0, 140) },
}

-- Where a goblin is put back after passing checkpoint `index`: on the line, facing on along the lap.
function PortGames.regattaRespawn(index)
	local cp = regatta.checkpoints[index]
	local i = cp and cp.at or 1
	local p = linePoint(i)
	return CFrame.lookAt(p, p + heading(i))
end

-- Is this on the Regatta's water? (Its boats may use their abilities there: the rest of the Port is a safe harbour.)
function PortGames.onRegatta(position)
	if typeof(position) ~= "Vector3" then
		return false
	end
	for i = 1, #line do
		local d = toSegment(position, linePoint(i), linePoint(i + 1))
		if d <= line[i].w + 60 then
			return true
		end
	end
	return false
end

-- GRAPPLE GAUNTLET -----------------------------------------------------------------------------------------------------------
-- Platforms (top surface y), swing hooks, bounce pads, the zipline, and the checkpoints in order. A pad launches a
-- goblin straight up (about 35 studs); the next platform is close enough to drift onto.
local gauntlet = {}
PortGames.GAUNTLET = gauntlet
local function plat(name, x, z, top, size)
	return { name = name, center = W(x, top, z), size = size or 14 }
end
gauntlet.start = plat("START", -105, -105, 6, 16)
gauntlet.platforms = {
	plat("P1", -118, -131, 36, 16),
	plat("P2", -165, -182, 38, 14),
	plat("P3", -197, -207, 38, 12),
	plat("P4", -214, -230, 70, 14),
	plat("P5", -258, -312, 62, 14),
	plat("P6", -195, -300, 40, 14),
	plat("P7", -140, -272, 44, 14),
	plat("FINISH", -122, -248, 78, 20),
}
gauntlet.beam = { from = W(-165, 38, -182), to = W(-197, 38, -207), width = 3 } -- P2 to P3
-- V13.5: each hook knows the leg it serves (it leaves from that platform), so the hooks ahead can light up.
gauntlet.hooks = {
	{ at = W(-142, 62, -157), leg = 1 }, -- P1 -> P2
	{ at = W(-234, 98, -256), leg = 4 }, -- P4 -> P5
	{ at = W(-250, 96, -286), leg = 4 },
	{ at = W(-168, 66, -288), leg = 6 }, -- P6 -> P7
}
gauntlet.pads = {
	{ at = W(-109, 6, -113), launch = v3(0, 118, 0) }, -- start -> P1
	{ at = W(-199, 38, -210), launch = v3(0, 128, 0) }, -- P3 -> P4
	{ at = W(-137, 44, -268), launch = v3(0, 132, 0) }, -- P7 -> FINISH
}
gauntlet.zip = { from = W(-253, 68, -318), to = W(-197, 45, -301) } -- P5 -> P6
gauntlet.home = { from = W(-118, 82, -244), to = W(-100, 11, -116) } -- FINISH -> the beach
gauntlet.checkpoints = {}
for i, p in ipairs(gauntlet.platforms) do
	local half = p.size / 2 + 2
	-- V13.5: put back facing the next platform (or the bell), so a fall is followed by a clear way on.
	local nextOne = gauntlet.platforms[i + 1] or p
	local from = p.center + v3(0, 4, 0)
	local toward = v3(nextOne.center.X, from.Y, nextOne.center.Z)
	table.insert(gauntlet.checkpoints, {
		name = p.name,
		box = { center = p.center + v3(0, 6, 0), half = v3(half, 8, half) },
		respawn = (toward - from).Magnitude > 1 and CFrame.lookAt(from, toward) or CFrame.new(from),
	})
end
gauntlet.startBox = { center = gauntlet.start.center + v3(0, 6, 0), half = v3(10, 8, 10) }

-- The furthest checkpoint at or after `from` that `position` is on (its index), or nil. V13.4: reaching a platform
-- further on counts, so a swing that skips one is a shortcut.
function PortGames.gauntletReached(position, from)
	for k = #gauntlet.checkpoints, from, -1 do
		if PortGames.inBox(position, gauntlet.checkpoints[k].box) then
			return k
		end
	end
	return nil
end
gauntlet.startSpot = CFrame.lookAt(W(-101, 10, -101), W(-109, 10, -113))

-- CANNON GOLF (V13.5) -----------------------------------------------------------------------------------------------------------
-- Six holes from the tee cannons at the end of the south-west jetty, each a different use of the sea. `dir` is degrees
-- from the tee's heading (positive to the right, towards the west), `far` studs from the tee. kind: "green" (a floating
-- green), "pad" (a little floating platform: precision), "isle" (a sand islet). Obstacles stand between: `rocks`
-- (sea stacks), `ridge` (a tall wall of rock to lob over or skip round) and `reef` (a ring of rocks with a gap).
local GF = G.GOLF
local golf = {}
PortGames.GOLF = golf
golf.facing = flatUnit(-0.62, 0.78) -- out to the south-west
golf.across = flatUnit(0.78, 0.62)
golf.jettyRoot = W(-138, 6, 196)
golf.jettyEnd = golf.jettyRoot + golf.facing * 38
golf.tees = {}
for i = 1, GF.TEES do
	local spot = golf.jettyEnd + golf.across * ((i - 2) * 10) + v3(0, 2.2, 0)
	table.insert(
		golf.tees,
		{ from = spot + golf.facing * 2 + v3(0, 2, 0), cframe = CFrame.lookAt(spot, spot + golf.facing) }
	)
end
local tee = golf.jettyEnd
-- A point `far` studs out from the tee, `dir` degrees off its heading, and `side` studs to the right of that line.
function PortGames.golfAt(dir, far, side)
	local way = turn(golf.facing, dir)
	local right = v3(-way.Z, 0, way.X)
	return tee + way * far + right * (side or 0)
end
local out = PortGames.golfAt
golf.holes = {
	{
		name = "THE PUDDLE JUMP",
		par = 2,
		kind = "green",
		center = out(10, 170),
		radius = 16,
		cup = 4,
		tip = "A gentle lob: look up, hold, let go.",
	},
	{
		name = "THE SKIPPING STONE",
		par = 3,
		kind = "green",
		center = out(0, 400),
		radius = 20,
		cup = 5,
		tip = "Too far to fly: aim low and skip it across.",
	},
	{
		name = "THE BEND",
		par = 3,
		kind = "green",
		center = out(-30, 330),
		radius = 17,
		cup = 4,
		rocks = {
			{ at = out(-30, 200, -18), radius = 9, height = 44 },
			{ at = out(-30, 200, 0), radius = 11, height = 52 },
			{ at = out(-30, 202, 18), radius = 9, height = 40 },
		},
		tip = "Stacks in the way: skim wide and curve it in (A/D).",
	},
	{
		name = "THE LILY PAD",
		par = 2,
		kind = "pad",
		center = out(-50, 150),
		radius = 7,
		cup = 3,
		tip = "Small and close: a soft lob, right on top.",
	},
	{
		name = "OVER THE TOP",
		par = 3,
		kind = "green",
		center = out(40, 260),
		radius = 16,
		cup = 4,
		ridge = { from = out(40, 157, -32), to = out(40, 157, 32), height = 50, thick = 16 },
		tip = "Lob it over the ridge, or skip round its end.",
	},
	{
		name = "THE KRAKEN'S CROWN",
		par = 3,
		kind = "isle",
		center = out(22, 430),
		radius = 12,
		cup = 3,
		reef = { center = out(22, 430), radius = 62, gap = 26, height = 14 },
		tip = "Skip through the reef's gap, then SPACE to stop on the crown.",
	},
}
golf.par = 0
for _, hole in ipairs(golf.holes) do
	hole.center += v3(0, hole.kind == "isle" and 3.2 or 1.6, 0) -- the top of the green, the pad or the islet
	golf.par += hole.par
end

-- The throw for a direction and a power (0..1). The direction's flat part is the aim, pulled inside YAW_MAX of the tee's
-- heading; its height is the elevation (V13.5: look up for a lob, down for a skimmer), held between ELEVATION_MIN and
-- ELEVATION_MAX (a flat direction is thrown at the starting ELEVATION). The speed is between MIN_SPEED and MAX_SPEED.
function PortGames.golfVelocity(direction, power)
	local valid = typeof(direction) == "Vector3" and direction == direction and direction.Magnitude > 1e-3
	local d = valid and flatUnit(direction.X, direction.Z) or golf.facing
	local angle = math.deg(math.acos(math.clamp(d:Dot(golf.facing), -1, 1)))
	if angle > GF.YAW_MAX then
		local side = (golf.facing:Cross(d).Y >= 0) and 1 or -1
		d = turn(golf.facing, -side * GF.YAW_MAX)
		-- (turn's positive is to the right; Cross.Y >= 0 is to the left)
	end
	local elevation = GF.ELEVATION
	if valid and math.abs(direction.Unit.Y) > 1e-3 then
		elevation = math.clamp(math.asin(math.clamp(direction.Unit.Y, -1, 1)), GF.ELEVATION_MIN, GF.ELEVATION_MAX)
	end
	power = math.clamp(tonumber(power) or 0, 0, 1)
	if power ~= power then
		power = 0
	end
	local speed = GF.MIN_SPEED + (GF.MAX_SPEED - GF.MIN_SPEED) * power
	return (d * math.cos(elevation) + v3(0, math.sin(elevation), 0)) * speed
end

-- Where a shot came down for good, judged for hole `hole`: "cup" (holed out with this stroke), "green" (on the target:
-- one putt more), or "miss". `water`: it ended in the sea (a target is something to land ON).
function PortGames.golfJudge(hole, position, water)
	if water or not hole or typeof(position) ~= "Vector3" then
		return "miss", nil
	end
	local distance = flatOf(position - hole.center).Magnitude
	if distance <= hole.cup then
		return "cup", distance
	elseif distance <= hole.radius + GF.NEAR then
		return "green", distance
	end
	return "miss", distance
end

-- What a hole is worth after `shots` shots ending in `grade`: the strokes, or nil while it goes on. A pickup (the last
-- allowed shot missed) is par + PICKUP.
function PortGames.golfStrokes(hole, shots, grade)
	if grade == "cup" then
		return shots
	elseif grade == "green" then
		return shots + 1
	elseif shots >= hole.par + 1 then
		return hole.par + GF.PICKUP
	end
	return nil
end

-- Strokes against par, the golf way: "E", "+2", "-1".
function PortGames.toPar(strokes, par)
	local d = strokes - par
	return d == 0 and "E" or (d > 0 and ("+" .. d) or tostring(d))
end

-- A hole's name for its strokes against its par ("HOLE IN ONE!", "BIRDIE!", "PAR", "BOGEY"...).
function PortGames.golfName(strokes, par)
	if strokes == 1 then
		return "HOLE IN ONE!"
	end
	local names =
		{ [-3] = "ALBATROSS!", [-2] = "EAGLE!", [-1] = "BIRDIE!", [0] = "PAR", [1] = "BOGEY", [2] = "DOUBLE BOGEY" }
	return names[strokes - par] or ("+" .. (strokes - par))
end

return PortGames

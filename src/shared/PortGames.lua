-- The Port's seven games (V13.3, The Living Port): where every venue stands and the rules that need no server, as
-- data and pure functions. Shared, so the server (server/Minigames.lua and one module per game) judges with exactly
-- the shapes, paths and numbers each client draws (client/PlayHud.lua), and the tests (tests/luau/Specs/
-- PortGamesSpec.lua) can check them.
--
--   TINY BOAT REGATTA   one lap of the water round the Port in a Racing Tub, through 13 checkpoints, past barrels,
--                       bumper buoys, splash cannons, a ramp over a reef and THE TEETH (a rock wall with a narrow
--                       channel through it: the shortcut; the safe way round is longer)
--   GRAPPLE GAUNTLET    a course in the air over the north-west water: bounce pads, swing rings, a beam, a zipline
--   CANNON GOLF         a tee cannon on a jetty and three floating greens; one shot at each, scored by the pin
--   PET DERBY           an oval with six hurdles; pets race, you CHEER as yours reaches a hurdle
--   TREASURE TOSS       throw chests into sliding barrels, a rowboat, a parrot's swinging perch, the King's mouth
--   TARGET GALLERY      shore cannons and a cut-out pirate fleet sailing to and fro (and a kraken, and a barge)
--   CRAB CHAOS          a crate of crabs bursts on the beach; catch them
--
-- Places are given relative to the Port's centre (Config.PORT.CENTER; north is -Z, like the sea) and turned into the
-- world by PortGames.world. Moving targets are functions of the server's clock, so every client draws them where the
-- server judges them, with nothing sent over the network but the clock.
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

-- The island's middle (the town is a little south of the Port's centre): the Regatta's ring is round it.
PortGames.ISLAND = W(0, 0, 40)

-- The games, in the order the Port lists them. kind: "time" (less is better) or "points"; unit: what a score is;
-- concurrent: every goblin (or challenge pair) gets a run of their own at once; board: the leaderboard it feeds.
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
		board = "regatta",
		hint = "Race a lap round the Port. Through every checkpoint; the Teeth have a gap.",
	},
	{
		id = "gauntlet",
		name = "Grapple Gauntlet",
		short = "GAUNTLET",
		icon = "🪝",
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
		kind = "points",
		unit = "pts",
		concurrent = true,
		max = 2,
		board = "golf",
		hint = "Aim the way you look. Hold to charge, let go to fire yourself at the pin.",
	},
	{
		id = "derby",
		name = "Pet Derby",
		short = "DERBY",
		icon = "🐾",
		color = Color3.fromRGB(255, 150, 190),
		kind = "time",
		unit = "s",
		max = G.DERBY.MAX,
		hint = "CHEER as your pet reaches a hurdle. Too soon, too late, or mashing: it trips.",
	},
	{
		id = "toss",
		name = "Treasure Toss",
		short = "TOSS",
		icon = "💰",
		color = Color3.fromRGB(255, 214, 90),
		kind = "points",
		unit = "pts",
		max = G.TOSS.MAX,
		hint = "Aim with the camera, click or Q to throw. Lob into baskets; the King only eats when his mouth is open.",
	},
	{
		id = "gallery",
		name = "Target Ship Gallery",
		short = "GALLERY",
		icon = "💥",
		color = Color3.fromRGB(255, 120, 80),
		kind = "points",
		unit = "pts",
		max = G.GALLERY.STATIONS,
		hint = "Aim with the camera, click to fire. Small, fast ships are worth more.",
	},
	{
		id = "crabs",
		name = "Crab Chaos",
		short = "CRABS",
		icon = "🦀",
		color = Color3.fromRGB(255, 110, 90),
		kind = "points",
		unit = "pts",
		max = G.CRABS.MAX,
		hint = "Run into crabs to catch them (dash helps). Golden ones are worth three.",
	},
}
PortGames.BY_ID = {}
for index, def in ipairs(PortGames.GAMES) do
	def.order = index
	PortGames.BY_ID[def.id] = def
end

-- Where each game is joined (a prompt) and the zone its lobby waits in. (Relative to the Port's centre.)
PortGames.VENUES = {
	regatta = { join = W(176, 7.5, 62), zone = W(200, 6, 62), radius = 44, sign = W(176, 18, 52) },
	gauntlet = { join = W(-100, 8, -100), zone = W(-105, 6, -105), radius = 20, sign = W(-96, 20, -92) },
	golf = { join = W(-140, 8, 200), zone = W(-152, 6, 214), radius = 30, sign = W(-132, 18, 192) },
	derby = { join = W(30, 8, 168), zone = W(30, 6, 205), radius = 60, sign = W(30, 22, 160) },
	toss = { join = W(70, 8, 108), zone = W(78, 6, 118), radius = 28, sign = W(66, 18, 100) },
	gallery = { join = W(130, 10, -94), zone = W(148, 8, -108), radius = 30, sign = W(126, 22, -88) },
	crabs = { join = W(-60, 8, 150), zone = W(-85, 6, 175), radius = 40, sign = W(-56, 18, 146) },
}

-- Ground the town's scenery (palms) keeps off: every venue, and the Port's other V13.3 pieces. { x, z, radius }.
PortGames.KEEP_CLEAR = {
	{ 110, 122, 52 }, -- Treasure Toss and its targets
	{ 30, 205, 56 }, -- the Derby's oval
	{ 205, 62, 40 }, -- the Regatta dock
	{ -85, 175, 42 }, -- Crab Chaos's beach
	{ -150, 212, 32 }, -- the golf jetty
	{ -105, -105, 24 }, -- the Gauntlet's start
	{ 140, -100, 34 }, -- the Target Gallery's pier
	{ 52, 76, 16 }, -- the Sanctuary Lift
	{ -34, -70, 12 }, -- the Captain's Quest Board
}
function PortGames.clearOf(x, z)
	for _, c in ipairs(PortGames.KEEP_CLEAR) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < c[3] * c[3] then
			return false
		end
	end
	return true
end

-- Medals ----------------------------------------------------------------------------------------------------------------
-- A score's medal ("gold" | "silver" | "bronze" | nil). The Derby's is its place (1st, 2nd, 3rd).
function PortGames.medal(gameId, score, place)
	if gameId == "derby" then
		return place == 1 and "gold" or (place == 2 and "silver" or (place == 3 and "bronze" or nil))
	end
	local def = PortGames.BY_ID[gameId]
	local medals = G[string.upper(gameId)] and G[string.upper(gameId)].MEDALS
	if not def or not medals or type(score) ~= "number" then
		return nil
	end
	for _, name in ipairs({ "gold", "silver", "bronze" }) do
		local need = medals[name]
		if need and ((def.kind == "time" and score <= need) or (def.kind ~= "time" and score >= need)) then
			return name
		end
	end
	return nil
end

function PortGames.better(gameId, a, b)
	local def = PortGames.BY_ID[gameId]
	if a == nil then
		return false
	elseif b == nil then
		return true
	end
	if def and def.kind == "time" then
		return a < b
	end
	return a > b
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
-- `score` nil means a run that did not finish (no best, no medal: only "played" if it counted at all).
function PortGames.finishRun(profile, gameId, score, place, humans, unix)
	local g = today(profile, unix)
	local R = G.REWARD
	local out = { parts = {}, shinies = 0, capped = false }
	out.medal = score ~= nil and PortGames.medal(gameId, score, place) or nil
	out.won = score ~= nil and place == 1 and (humans or 1) >= 2
	out.previous = g.best[gameId]
	if score ~= nil and PortGames.better(gameId, score, out.previous) then
		out.best = out.previous ~= nil -- the very first run is a first score, not a beaten record
		g.best[gameId] = score
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

-- How many different games a profile has finished (the Port Regular achievement's stat).
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

-- Turns a flat direction by `degrees` (positive: to the right when looking along it from above, north up).
local function turn(direction, degrees)
	local a = rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return flatUnit(direction.X * c - direction.Z * s, direction.X * s + direction.Z * c)
end
PortGames.turn = turn

-- TINY BOAT REGATTA ------------------------------------------------------------------------------------------------------
-- The lap goes round the island anticlockwise seen from above: east, north, west, south, east. theta in degrees from
-- east (0) towards north (90).
local RG = G.REGATTA
function PortGames.ring(theta, r)
	local a = rad(theta)
	local I = PortGames.ISLAND
	return v3(I.X + (r or RG.RADIUS) * math.cos(a), 0, I.Z - (r or RG.RADIUS) * math.sin(a))
end
-- The way the lap goes at theta.
function PortGames.ringHeading(theta)
	local a = rad(theta)
	return flatUnit(-math.sin(a), -math.cos(a))
end
local ring, heading = PortGames.ring, PortGames.ringHeading

local regatta = {}
PortGames.REGATTA = regatta
-- Checkpoints: each is a list of discs, any of which counts (THE TEETH's: the channel, or out round the wall).
regatta.checkpoints = {}
for k = 1, RG.CHECKPOINTS do
	local theta = k * 360 / RG.CHECKPOINTS
	table.insert(regatta.checkpoints, { theta = theta, discs = { { center = ring(theta), radius = RG.GATE_RADIUS } } })
	if theta == 180 then
		-- The Teeth (186 to 206 degrees): the channel through them at 196, or the long way outside.
		table.insert(regatta.checkpoints, {
			theta = 196,
			teeth = true,
			discs = {
				{ center = ring(196, 600), radius = 13 },
				{ center = ring(196, 712), radius = 44 },
			},
		})
	end
end
regatta.finish = #regatta.checkpoints -- the last checkpoint (360 degrees) is the start line: crossing it ends the lap
-- The start grid: four rows of two behind the line, facing along the lap.
regatta.grid = {}
for i = 1, RG.MAX do
	local row, col = (i - 1) // 2, (i - 1) % 2
	local theta = -(3 + row * 3.6)
	local p = ring(theta, RG.RADIUS + (col == 0 and -15 or 15))
	table.insert(regatta.grid, CFrame.lookAt(p, p + heading(theta)))
end
regatta.startLine = { a = ring(0, RG.RADIUS - 60), b = ring(0, RG.RADIUS + 60) }
-- What stands on the water (server/Regatta.lua builds it; the boost hoops and ramps are BoatSim gates).
regatta.hoops = {
	{ theta = 14, r = 600 },
	{ theta = 34, r = 600 },
	{ theta = 152, r = 600 },
	{ theta = 196, r = 600, small = true }, -- inside the Teeth's channel: the shortcut's reward
	{ theta = 232, r = 600 },
	{ theta = 338, r = 600 },
}
regatta.highHoop = { theta = 326, r = 600, y = 30 } -- over the second ramp: only a jump reaches it
regatta.ramps = {
	{ theta = 59, r = 600, width = 18 }, -- THE LEAP over the reef
	{ theta = 320, r = 600, width = 16 }, -- up into the high hoop
}
regatta.reef = { from = 63.5, to = 65.5, inner = 548, outer = 652 } -- a low ridge across the lane (crash or jump)
regatta.teeth = { from = 186, to = 206, channel = { 589, 611 }, inner = 430, outer = 650 }
regatta.barrels = {} -- a staggered field to weave through
for i = 0, 13 do
	local theta = 97 + i * 1.1
	local r = 566 + ((i * 37) % 7) * 11
	table.insert(regatta.barrels, ring(theta, r))
end
regatta.buoys = {} -- a slalom of big bumper buoys
for i = 0, 5 do
	table.insert(regatta.buoys, ring(246 + i * 3.4, i % 2 == 0 and 582 or 618))
end
regatta.cannons = { -- splash cannons on rocks outside the lane
	{ rock = ring(134, 690), theta = 134 },
	{ rock = ring(286, 690), theta = 286 },
}

-- The lap's length along its middle (for the HUD's progress and the server's sanity checks).
regatta.length = 2 * math.pi * RG.RADIUS

-- Where checkpoint `index` of the lap is reached, for a tub put back after falling out.
function PortGames.regattaRespawn(index)
	local cp = regatta.checkpoints[index]
	local theta = cp and cp.theta or 0
	if cp and cp.teeth then
		theta = 210 -- never put a tub back inside the Teeth
	end
	local p = ring(theta, RG.RADIUS)
	return CFrame.lookAt(p, p + heading(theta))
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
gauntlet.hooks = {
	W(-142, 62, -157), -- P1 -> P2
	W(-234, 98, -256), -- P4 -> R3
	W(-250, 96, -286), -- -> P5
	W(-168, 66, -288), -- P6 -> P7
}
gauntlet.pads = {
	{ at = W(-109, 6, -113), launch = v3(0, 118, 0) }, -- start -> P1
	{ at = W(-199, 38, -210), launch = v3(0, 128, 0) }, -- P3 -> P4
	{ at = W(-137, 44, -268), launch = v3(0, 132, 0) }, -- P7 -> FINISH
}
gauntlet.zip = { from = W(-253, 68, -318), to = W(-197, 45, -301) } -- P5 -> P6
gauntlet.home = { from = W(-118, 82, -244), to = W(-100, 11, -116) } -- FINISH -> the beach
gauntlet.checkpoints = {}
for _, p in ipairs(gauntlet.platforms) do
	local half = p.size / 2 + 2
	table.insert(gauntlet.checkpoints, {
		name = p.name,
		box = { center = p.center + v3(0, 6, 0), half = v3(half, 8, half) },
		respawn = CFrame.new(p.center + v3(0, 4, 0)),
	})
end
gauntlet.startBox = { center = gauntlet.start.center + v3(0, 6, 0), half = v3(10, 8, 10) }
gauntlet.startSpot = CFrame.lookAt(W(-101, 10, -101), W(-109, 10, -113))

-- CANNON GOLF ---------------------------------------------------------------------------------------------------------------
local GF = G.GOLF
local golf = {}
PortGames.GOLF = golf
golf.facing = flatUnit(-0.62, 0.78) -- out to the south-west
golf.across = flatUnit(0.78, 0.62)
golf.jettyRoot = W(-138, 6, 196)
golf.jettyEnd = golf.jettyRoot + golf.facing * 38
golf.tees = {}
for i = 1, GF.TEES do
	local at = golf.jettyEnd + golf.across * ((i - 2) * 10) + v3(0, 2.2, 0)
	table.insert(golf.tees, { from = at + golf.facing * 2 + v3(0, 2, 0), cframe = CFrame.lookAt(at, at + golf.facing) })
end
local teeMiddle = golf.jettyEnd
golf.greens = {
	{ name = "THE PUDDLE", center = teeMiddle + turn(golf.facing, -24) * 110 + v3(0, 1.6, 0), radius = GF.GREEN },
	{ name = "THE SANDBAR", center = teeMiddle + turn(golf.facing, 21) * 172 + v3(0, 1.6, 0), radius = GF.GREEN },
	{ name = "THE LONG ONE", center = teeMiddle + turn(golf.facing, -4) * 236 + v3(0, 1.6, 0), radius = GF.GREEN },
}

-- The throw for a yaw (a flat direction the goblin chose) and a power (0..1): a fixed elevation, the speed between
-- MIN_SPEED and MAX_SPEED. The direction is pulled inside YAW_MAX of the tee's heading.
function PortGames.golfVelocity(direction, power)
	local d = typeof(direction) == "Vector3" and flatUnit(direction.X, direction.Z) or golf.facing
	local angle = math.deg(math.acos(math.clamp(d:Dot(golf.facing), -1, 1)))
	if angle > GF.YAW_MAX then
		local side = (golf.facing:Cross(d).Y >= 0) and 1 or -1
		d = turn(golf.facing, -side * GF.YAW_MAX)
		-- (turn's positive is to the right; Cross.Y >= 0 is to the left)
	end
	power = math.clamp(tonumber(power) or 0, 0, 1)
	if power ~= power then
		power = 0
	end
	local speed = GF.MIN_SPEED + (GF.MAX_SPEED - GF.MIN_SPEED) * power
	return (d * math.cos(GF.ELEVATION) + v3(0, math.sin(GF.ELEVATION), 0)) * speed
end

-- Points for a landing `distance` (flat studs) from the pin.
function PortGames.golfPoints(distance)
	local P = GF.POINTS
	if distance <= GF.CUP then
		return P.cup, "cup"
	elseif distance <= GF.NEAR then
		return P.near, "near"
	elseif distance <= GF.GREEN then
		return P.green, "green"
	elseif distance <= GF.FRINGE then
		return P.fringe, "fringe"
	end
	return P.miss, "miss"
end

-- PET DERBY ---------------------------------------------------------------------------------------------------------------------
local DG = G.DERBY
local derby = {}
PortGames.DERBY = derby
derby.center = W(30, 6.2, 205)
derby.a, derby.b = 45, 22 -- half-axes of the oval (x, z)
derby.lanes = DG.MAX
derby.laneWidth = 1.9
derby.hurdles = { 0.12, 0.27, 0.42, 0.57, 0.72, 0.87 }
-- Arc length along the inner line, sampled once, so a pet at fraction f is f of the way round (all lanes run the
-- same fraction: the outer lanes are drawn wider, never longer).
local SAMPLES = 240
local arc = { 0 }
do
	local function at(phi)
		return derby.a * math.cos(phi), derby.b * math.sin(phi)
	end
	local total = 0
	local px, pz = at(-math.pi / 2)
	for i = 1, SAMPLES do
		local phi = -math.pi / 2 + i / SAMPLES * math.pi * 2
		local x, z = at(phi)
		total += math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		arc[i + 1] = total
		px, pz = x, z
	end
	derby.length = total
end
-- Where a pet at fraction f (0..1, wrapped) in `lane` (1..) is, and the way it faces.
function PortGames.derbyPoint(f, lane)
	f = f % 1
	local target = f * derby.length
	local lo, hi = 1, SAMPLES + 1
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if arc[mid] <= target then
			lo = mid
		else
			hi = mid
		end
	end
	local span = arc[hi] - arc[lo]
	local k = span > 0 and (target - arc[lo]) / span or 0
	local phi = -math.pi / 2 + ((lo - 1) + k) / SAMPLES * math.pi * 2
	local x, z = derby.a * math.cos(phi), derby.b * math.sin(phi)
	-- Outward normal of the ellipse, for the lane offset; the tangent is the way round.
	local nx, nz = x / (derby.a * derby.a), z / (derby.b * derby.b)
	local n = flatUnit(nx, nz)
	local t = flatUnit(-derby.a * math.sin(phi), derby.b * math.cos(phi))
	local offset = ((lane or 1) - 1) * derby.laneWidth + 1.2
	return derby.center + v3(x, 0, z) + n * offset, t
end
-- The judge: a CHEER `timeToHurdle` seconds before the pet reaches its next hurdle (negative: after) is
-- "clean" (in the window), "early" (too soon: it trips on the hurdle) or "none" (no hurdle near: a stumble).
function PortGames.derbyJudge(timeToHurdle)
	if timeToHurdle == nil then
		return "none"
	end
	if timeToHurdle <= DG.EARLY and timeToHurdle >= -DG.LATE then
		return "clean"
	elseif timeToHurdle > DG.EARLY and timeToHurdle <= DG.TOO_EARLY then
		return "early"
	end
	return "none"
end

-- THE RANGES: TREASURE TOSS and the TARGET SHIP GALLERY ------------------------------------------------------------------------
-- A target is a function of the server's clock: target(t) -> { pos, radius, points, up (it can be hit: the King's
-- mouth is open, a ship is not keeled over is the server's to add), basket (a throw must come down into it) }.
local function pingpong(t, speed, length, phase)
	local s = (t * speed + (phase or 0)) % (2 * length)
	return s <= length and s or 2 * length - s
end

local toss = {}
PortGames.TOSS = toss
toss.facing = v3(1, 0, 0)
toss.spots = {}
for i = 0, 5 do
	table.insert(toss.spots, CFrame.lookAt(W(78, 9.5, 103 + i * 6), W(130, 9.5, 103 + i * 6)))
end
toss.ground = 5.6 -- a throw that comes down to this height has landed
toss.targets = {}
for i = 0, 2 do
	table.insert(toss.targets, {
		kind = "barrel",
		points = 1,
		radius = 2.7,
		basket = true,
		at = function(t)
			return W(106, 9.2, 100 + pingpong(t, 6, 36, i * 12))
		end,
	})
end
table.insert(toss.targets, {
	kind = "rowboat",
	points = 2,
	radius = 3.8,
	basket = true,
	at = function(t)
		return W(122, 8.2 + 0.4 * math.sin(t * 2.2), 96 + pingpong(t, 9, 44, 7))
	end,
})
toss.perch = W(137, 6, 118)
table.insert(toss.targets, {
	kind = "perch",
	points = 4,
	radius = 2.5,
	basket = true,
	at = function(t)
		local a = t * 1.1
		return toss.perch + v3(math.sin(a) * 3, 15, math.cos(a) * 9)
	end,
})
toss.king = W(154, 6, 118)
toss.MOUTH_EVERY, toss.MOUTH_OPEN = 4, 1.4
function PortGames.kingOpen(t)
	return (t % toss.MOUTH_EVERY) < toss.MOUTH_OPEN
end
table.insert(toss.targets, {
	kind = "king",
	points = 8,
	radius = 3.4,
	at = function(_t)
		return toss.king + v3(-5, 8, 0) -- the mouth, low on the front of his face
	end,
	open = PortGames.kingOpen,
})

local gallery = {}
PortGames.GALLERY = gallery
gallery.deck = W(148, 8, -108)
gallery.facing = flatUnit(0.6, -0.8)
gallery.across = flatUnit(0.8, 0.6)
gallery.stations = {}
for i = 1, G.GALLERY.STATIONS do
	local at = gallery.deck + gallery.across * ((i - 2.5) * 10) + v3(0, 1.4, 0)
	table.insert(gallery.stations, {
		cframe = CFrame.lookAt(at, at + gallery.facing),
		muzzle = at + gallery.facing * 3.6 + v3(0, 2.4, 0),
		seat = at - gallery.facing * 3.2 + v3(0, 2.6, 0),
	})
end
gallery.water = 1
local function lane(dist, side)
	return gallery.deck + gallery.facing * dist + gallery.across * side
end
gallery.targets = {
	{
		kind = "galleon",
		points = 1,
		radius = 9,
		at = function(t)
			return lane(205, pingpong(t, 8, 120, 0) - 60) + v3(0, 5, 0)
		end,
	},
	{
		kind = "sloop",
		points = 2,
		radius = 6.5,
		at = function(t)
			return lane(150, 70 - pingpong(t, 14, 140, 40)) + v3(0, 3.6, 0)
		end,
	},
	{
		kind = "sloop",
		points = 2,
		radius = 6.5,
		at = function(t)
			return lane(255, pingpong(t, 12, 130, 90) - 65) + v3(0, 3.6, 0)
		end,
	},
	{
		kind = "skiff",
		points = 4,
		radius = 4.5,
		at = function(t)
			return lane(110, pingpong(t, 24, 160, 15) - 80) + v3(0, 2.4, 0)
		end,
	},
	{
		-- A tentacle up out of the sea for 2.5 s every 7 s, somewhere new each time.
		kind = "kraken",
		points = 6,
		radius = 4,
		at = function(t)
			local cycle = t // 7
			local h = Seasons.mix(cycle, 77)
			local dist = 130 + (h % 90)
			local side = ((h // 90) % 120) - 60
			return lane(dist, side) + v3(0, 6, 0)
		end,
		open = function(t)
			return (t % 7) < 2.5
		end,
	},
	{
		-- The Goblin King's barge: crosses quickly for 5 s every 15 s, far out. Worth the most.
		kind = "barge",
		points = 10,
		radius = 6,
		at = function(t)
			local s = (t % 15) / 5
			return lane(250, -90 + 180 * math.clamp(s, 0, 1)) + v3(0, 4, 0)
		end,
		open = function(t)
			return (t % 15) < 5
		end,
	},
}

-- Where a range's target is at time t, whether it can be hit now, and its radius and points.
function PortGames.targetAt(range, index, t)
	local target = range.targets[index]
	if not target then
		return nil
	end
	return target.at(t), (target.open == nil or target.open(t)), target
end

-- A projectile from `from` with `velocity` under `gravity` (studs/s^2, down), thrown at server time t0: the first
-- target it reaches, within maxTime, before it comes down to `floor`. `down(index, t)` (optional): true while a target
-- cannot be hit (a keeled-over ship). Returns index, time of the hit (server clock), where; or nil, the time and place
-- it came down.
function PortGames.shotHit(range, from, velocity, gravity, t0, ballRadius, floor, maxTime, down)
	local step = 1 / 60
	local p, v = from, velocity
	local g = v3(0, -gravity, 0)
	for i = 1, math.floor((maxTime or 3) / step) do
		local t = t0 + i * step
		v += g * step
		p += v * step
		for index, target in ipairs(range.targets) do
			if (target.open == nil or target.open(t)) and not (down and down(index, t)) then
				if not target.basket or v.Y < 0 then
					local at = target.at(t)
					if (p - at).Magnitude <= target.radius + (ballRadius or 1) then
						return index, t, p
					end
				end
			end
		end
		if p.Y <= floor then
			return nil, t, p
		end
	end
	return nil, t0 + (maxTime or 3), p
end

-- The direction a toss may leave in: the aim, pulled inside the booth's limits (pitch and yaw). nil if it is nonsense.
function PortGames.tossDirection(aim)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 or aim.X ~= aim.X then
		return nil
	end
	aim = aim.Unit
	local T = G.TOSS
	local flat = flatUnit(aim.X, aim.Z)
	local yaw = math.deg(math.acos(math.clamp(flat:Dot(toss.facing), -1, 1)))
	if yaw > T.YAW_MAX then
		local side = toss.facing:Cross(flat).Y >= 0 and 1 or -1
		flat = turn(toss.facing, -side * T.YAW_MAX)
	end
	local pitch = math.deg(math.asin(math.clamp(aim.Y, -1, 1)))
	pitch = math.clamp(pitch, T.PITCH_MIN, T.PITCH_MAX)
	local p = rad(pitch)
	return flat * math.cos(p) + v3(0, math.sin(p), 0)
end

-- The gallery cannon's arc through a point (the island cannons' rule: the low arc that reaches it, or 45 degrees if it
-- is out of reach). Returns a velocity.
function PortGames.cannonVelocity(from, target)
	local A = G.GALLERY
	local g, speed = A.GRAVITY, A.SPEED
	local delta = target - from
	local flat = v3(delta.X, 0, delta.Z)
	local x, y = flat.Magnitude, delta.Y
	local dir = x > 0.01 and flat.Unit or gallery.facing
	local s2 = speed * speed
	local root = s2 * s2 - g * (g * x * x + 2 * y * s2)
	local angle
	if root >= 0 and x > 0.01 then
		angle = math.atan((s2 - math.sqrt(root)) / (g * x))
	else
		angle = rad(45)
	end
	angle = math.clamp(angle, rad(-20), rad(60))
	return (dir * math.cos(angle) + v3(0, math.sin(angle), 0)) * speed
end

-- CRAB CHAOS ------------------------------------------------------------------------------------------------------------------------
PortGames.CRABS = { center = W(-85, 6, 175), radius = 32, fence = 35 }

return PortGames

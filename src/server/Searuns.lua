-- Things to do while sailing: boost lanes, timed courses, stunt ramps and coins.
--
-- V5 laid about a hundred hoops and three hundred coins, and its playtest said they were fun and
-- badly placed: a wall of them outside the harbor, lanes that hooked round islands, nothing to
-- tell one thing from another. V6 keeps the mechanics and lays them out again by these rules:
--
--   A TEAL hoop is a LANE. A lane points at a dock across open water, straight unless there is
--   a reason to bend (a coast to follow, a rock to round), with a hoop every 190 studs or so:
--   far enough apart to see past, close enough to chain. A sign at each end says where it goes.
--
--   An ORANGE hoop is a TIMED COURSE: a slalom between sea stacks, a sprint down a current, or
--   a lap round a landmark. These are places to go and play, set apart from the lanes.
--
--   A COIN marks a line worth taking: a weave through a slalom, a stack to hug, the air over a
--   ramp, the way into somewhere hidden. A few long lanes carry one between hoops. Coins never
--   just fill water.
--
--   HOME BAY is calm on purpose: one line of hoops from the harbor through the Gate. The rest
--   of the sea shows itself once a goblin has left.
--
-- A lane is an offer, never a fence: nothing here blocks the open water beside it, and some
-- water (the fort's, the skull's, the far east) is left empty so that it stays quiet.
--
-- Everything is placed from island positions (shared/Archipelago.lua) and from the features in
-- Seaways.lua, so the layout follows when the map moves. Like the other builders this only
-- describes: hoops become refs.boostGates (Boats), coins refs.coins and runs refs.runs (Coins).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Kit = require(script.Parent.WorldKit)
local Seaways = require(script.Parent.Seaways)

local Searuns = {}

local folders = Kit.folders
local refs = Kit.refs

local LANE = Color3.fromRGB(120, 255, 230)
local TIMED = Color3.fromRGB(255, 185, 80)
local COIN = Color3.fromRGB(255, 215, 60)
local BIG_COIN = Color3.fromRGB(255, 140, 40)
local COIN_Y = 3.4
local LANE_SIGN_RANGE = 300
-- A lap's radius. At chain speed a skiff cannot hold a circle 190 studs across the middle (driven,
-- it missed half the hoops of one). At 290 it can, with care; at 330 it has steering to spare.
-- (V7: the skiff is a quarter faster, so a lap's radius grew with it: V6 had 330 and 290.)
local LAP_RADIUS = { Lookout = 400, Maelstrom = 350 }

-- Pars for the timed courses, in seconds. Each was measured: the game's own boat physics drove
-- a skiff down the course (boosting, steering at a point a little ahead along the hoops), and
-- the par is that clean time plus 15 to 20 percent, rounded to half a second. Measured times:
-- the Teeth 3.7, the Cinder Slalom 3.6 to 3.8, the Serpent 2.9 with the current and 3.3 against,
-- the Maelstrom Ring 11.5 to 11.7 a flying lap, the Lookout Loop 13.3 to 13.8.
-- V7 (a skiff at 135, chain speed to 242, laps 400 and 350 studs in radius): measured again, plus 17 percent.
local PAR = {
	Teeth = 3.3,
	Cinder = 3.2,
	Serpent = 2.8,
	Lookout = 14,
	Maelstrom = 12.8,
}

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

local function from(id, dx, dz)
	local island = Archipelago.byId[id]
	return v3(island.x + (dx or 0), 0, island.z + (dz or 0))
end

local function warn_(text)
	table.insert(refs.buildWarnings, text)
end

-- How deep the water is at a point (a positive number), or 0 on land.
local function depthAt(position)
	return math.max(0, -Kit.groundY(position.X, position.Z, -30))
end

-- Coins ---------------------------------------------------------------------------------
-- `facing` is the way a boat is expected to come: the coin shows it its face.
local function coin(position, facing, value, inAir)
	if not inAir and depthAt(position) < 2.5 then
		return nil -- On a shoal or a beach: a boat could not reach it.
	end
	facing = (facing and facing.Magnitude > 0.1) and facing.Unit or Vector3.zAxis
	local big = (value or 1) > 1
	local size = big and 6.5 or 4.2
	local part = Kit.part(
		"Coin",
		v3(0.7, size, size),
		CFrame.lookAt(position, position + facing) * CFrame.Angles(0, math.rad(90), 0),
		big and BIG_COIN or COIN,
		Enum.Material.Neon,
		folders.coins
	)
	part.Shape = Enum.PartType.Cylinder
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("Value", value or 1)
	table.insert(refs.coins, { part = part, value = value or 1, position = position })
	return part
end

-- A straight line of coins from a to b.
local function trail(a, b, count, value)
	local facing = b - a
	for i = 0, count - 1 do
		local at = a:Lerp(b, count == 1 and 0.5 or i / (count - 1))
		coin(v3(at.X, COIN_Y, at.Z), facing, value)
	end
end

-- Paths ---------------------------------------------------------------------------------
-- A smooth curve through the waypoints (Catmull-Rom), as a list of { position, distance }.
local function curve(points)
	local samples = { { position = points[1], distance = 0 } }
	local total = 0
	for i = 1, #points - 1 do
		local p0, p1, p2, p3 = points[math.max(i - 1, 1)], points[i], points[i + 1], points[math.min(i + 2, #points)]
		for step = 1, 20 do
			local t = step / 20
			local position = 0.5
				* (
					2 * p1
					+ (p2 - p0) * t
					+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
					+ (3 * p1 - p0 - 3 * p2 + p3) * t * t * t
				)
			total += (position - samples[#samples].position).Magnitude
			table.insert(samples, { position = position, distance = total })
		end
	end
	return samples, total
end

-- The point `distance` along a curve, and the way the curve is heading there.
local function along(samples, distance)
	for i = 2, #samples do
		if samples[i].distance >= distance then
			local a, b = samples[i - 1], samples[i]
			local span = math.max(b.distance - a.distance, 0.001)
			local heading = b.position - a.position
			return a.position:Lerp(b.position, (distance - a.distance) / span), heading
		end
	end
	local last, before = samples[#samples], samples[#samples - 1]
	return last.position, last.position - before.position
end

-- A sign over one end of a timed course. Returns its label, which Coins.lua rewrites with the best time.
local function runSign(position, text)
	local holder = Kit.decor("RunSign", v3(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), nil)
	holder.Transparency = 1
	local gui = Kit.sign(holder, text, TIMED, Vector3.zero, 420)
	gui.Size = UDim2.fromOffset(300, 44)
	return gui:FindFirstChildOfClass("TextLabel")
end

-- A small sign over the end of a lane: where it leads. Only readable from close by, so it
-- answers "where does this go?" at the moment someone is about to take it and never adds to
-- the names on the horizon.
local function laneSign(position, text)
	local holder = Kit.decor("LaneSign", v3(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), nil)
	holder.Transparency = 1
	Kit.sign(holder, text, LANE, Vector3.zero, LANE_SIGN_RANGE)
end

-- Lays a run. def:
--   name     what it is called (shown on the signs of a timed course)
--   points   world waypoints
--   spacing  studs between hoops (default 190); `exact` puts one hoop on every waypoint instead
--   to, back for a lane: what the sign at its first hoop says it leads to, and the one at its last
--   timed    true: a timed course, with `par` seconds (measured by driving it: see the V6 report)
--   loop     true: a lap. The first hoop is the start and the finish; either way round counts.
--   coins    coins between each pair of hoops (default 0)
--   adrift   false: never set a salvage crate adrift beside this lane
--   sway     coins step this far left and right of the line in turn (a weave to follow)
local function run(def)
	local points = def.points
	if def.loop then
		points = table.clone(points)
		table.insert(points, points[1])
	end
	local samples, total = curve(points)
	local color = def.timed and TIMED or LANE
	local marks = {} -- distances along the curve where the hoops stand
	if def.exact then
		for i = 1, #points do
			table.insert(marks, samples[(i - 1) * 20 + 1].distance)
		end
	else
		local spacing = def.spacing or 190
		local count = math.max(2, math.floor(total / spacing + 0.5) + 1)
		for i = 0, count - 1 do
			table.insert(marks, total * i / (count - 1))
		end
	end
	local checkpoints = {}
	for i, distance in ipairs(marks) do
		local position, heading = along(samples, distance)
		-- A lap's last mark is its first hoop again.
		if not (def.loop and i == #marks) then
			if depthAt(position) < 3.2 then -- Less than a skiff needs.
				warn_(
					string.format(
						"%s hoop %d at (%.0f, %.0f) is over shallow water or land",
						def.name,
						i,
						position.X,
						position.Z
					)
				)
			end
			Kit.hoop(v3(position.X, 5, position.Z), heading, def.radius or 12, color)
			table.insert(checkpoints, v3(position.X, 0, position.Z))
		end
		-- Coins from this hoop to the next.
		local nextDistance = marks[i + 1]
		local coins = def.coins or 0
		if nextDistance and coins > 0 then
			for k = 1, coins do
				local at, way = along(samples, distance + (nextDistance - distance) * k / (coins + 1))
				local side = v3(-way.Z, 0, way.X)
				side = side.Magnitude > 0.1 and side.Unit or Vector3.xAxis
				local sway = (def.sway or 0) * ((i + k) % 2 == 0 and 1 or -1)
				coin(v3(at.X, COIN_Y, at.Z) + side * sway, way)
			end
		end
	end
	local first, last = checkpoints[1], checkpoints[#checkpoints]
	if def.timed then
		local text = string.format("%s - par %.1f s", def.name, def.par)
		local labels = { runSign(first + v3(0, 26, 0), text) }
		if not def.loop then
			table.insert(labels, runSign(last + v3(0, 26, 0), text))
		end
		table.insert(refs.runs, {
			name = def.name,
			par = def.par,
			length = total,
			loop = def.loop or false,
			checkpoints = checkpoints,
			labels = labels,
		})
	else
		if def.to then
			laneSign(first + v3(0, 23, 0), "TO " .. def.to)
		end
		if def.back then
			laneSign(last + v3(0, 23, 0), "TO " .. def.back)
		end
		-- adrift: salvage crates may be set adrift beside this lane (Coins.lua).
		table.insert(
			refs.lanes,
			{ name = def.name, length = total, checkpoints = checkpoints, adrift = def.adrift ~= false }
		)
	end
	return checkpoints
end

-- Coins along a curve through the waypoints, one every `spacing` studs, from just after the
-- first waypoint to the last: a trail to follow where the way is not straight.
local function breadcrumbs(points, spacing)
	local samples, total = curve(points)
	local count = math.max(1, math.floor(total / spacing + 0.5))
	for k = 1, count do
		local at, way = along(samples, total * k / count)
		coin(v3(at.X, COIN_Y, at.Z), way)
	end
end

-- A ramp with coins hanging over where a boat that takes it fast will fly.
local function ramp(at, direction, label)
	direction = v3(direction.X, 0, direction.Z).Unit
	Kit.kicker(at, direction, 16)
	local lip = at + direction * 15
	for k, air in ipairs({ { 24, 13 }, { 40, 17 }, { 56, 13 } }) do
		coin(v3(lip.X, air[2], lip.Z) + direction * air[1], direction, k == 2 and 5 or 1, true)
	end
	if label then
		local holder = Kit.decor("RampSign", v3(1, 1, 1), CFrame.new(at + v3(0, 18, 0)), Color3.new(1, 1, 1), nil)
		holder.Transparency = 1
		Kit.sign(holder, label, Color3.fromRGB(255, 220, 90), Vector3.zero, 300)
	end
end

-- A ring of waypoints round a center, for a lap. `from` is the angle of the first (degrees;
-- 0 is east, 90 south, -90 north).
local function ringOf(center, radius, count, from_)
	local ring = {}
	for k = 0, count - 1 do
		local a = math.rad(from_ + k * 360 / count)
		table.insert(ring, center + v3(math.cos(a) * radius, 0, math.sin(a) * radius))
	end
	return ring
end

-- HOME BAY -------------------------------------------------------------------------------
-- One line out. From the harbor a goblin should see the Gate, a short chain of hoops through it,
-- and open water: everything else in the sea is found by leaving.
local function buildHomeWaters()
	local home = from("Home")
	local gate = Seaways.GATE
	local gateX = (gate[1] + gate[2]) / 2
	-- GATE RUN: out of the harbor, through the Gate, to the Crossroads' south dock. Four hoops close
	-- together: the place to learn that hoops chain. The harbor jump (built with the island) lands
	-- a boat on its first hoop.
	-- (No signs on this one: THE GATE and the Crossroads' own name already stand on its line.)
	run({
		name = "Gate Run",
		exact = true,
		adrift = false, -- Home Bay stays calm (and salvage on the doorstep would be free coins).
		points = {
			home + v3(gateX - 46, 0, gate[3] + 241),
			home + v3(gateX - 23, 0, gate[3] + 121),
			home + v3(gateX, 0, gate[3]),
			home + v3(gateX + 23, 0, gate[3] - 120),
		},
	})
	-- The harbor jump: coins over it.
	for k, air in ipairs({ { -288, 13 }, { -304, 17 }, { -320, 13 } }) do
		coin(home + v3(0, air[2], air[1]), -Vector3.zAxis, k == 2 and 5 or 1, true)
	end
	-- The two shallow passes are shortcuts for a small boat: three coins through each say so.
	trail(home + v3(-318, 0, -604), home + v3(-252, 0, -572), 3) -- Gull Pass
	trail(home + v3(402, 0, -610), home + v3(458, 0, -592), 3) -- Smuggler's Gap
	-- Trails into places worth finding.
	trail(home + v3(10, 0, 440), home + v3(10, 0, 330), 4) -- up the Back Door cove
	local smuggler = from("Smuggler")
	trail(smuggler + v3(-120, 0, 76), smuggler + v3(-10, 0, 100), 4) -- into the hidden lagoon
end

-- LANES ----------------------------------------------------------------------------------
-- The sea's roads. Each one is the line a boat would want to sail between two places anyway.
local function buildLanes()
	local home = from("Home")
	-- WEST RUN: from outside Gull Pass to the Shipwreck Shoals' dock. A ramp beside it.
	local westA, westB = home + v3(-400, 0, -682), from("Shoals", 260, 35)
	run({
		name = "West Run",
		to = "SHIPWRECK SHOALS",
		back = "THE GATE",
		spacing = 190,
		coins = 1,
		points = { westA, westB },
	})
	ramp(from("Shoals", 600, 232), westB - westA, "WEST JUMP")
	-- MILL RUN: east out of the bay, south of Smuggler's Cove, to Windmill Hills' west dock.
	-- (The Mill Race current, a little to the south, is the way back.)
	run({
		name = "Mill Run",
		to = "WINDMILL HILLS",
		back = "GOBLIN COVE",
		spacing = 165,
		points = { home + v3(500, 0, -237), from("Windmill", -345, 132) },
	})
	-- CHIMNEY RUN: from Smuggler's Gap, past the Chimney, to Crystal Isle's west dock.
	run({
		name = "Chimney Run",
		to = "CRYSTAL ISLE",
		back = "SMUGGLER'S GAP",
		spacing = 193,
		coins = 1,
		points = { home + v3(470, 0, -662), from("Crystal", -240, 105) },
	})
	-- TEMPLE RUN: the Crossroads' north dock, past the west side of Pilgrim's Rock, to the temple's dock.
	run({
		name = "Temple Run",
		exact = true,
		to = "SUN TEMPLE",
		back = "CROSSROADS RUINS",
		points = {
			from("Cross", -52, -460),
			from("Pilgrim", -140, 60),
			from("Pilgrim", -118, -100),
			from("Temple", 16, 330),
		},
	})
	-- EMBER ROAD: the long one. From north of the Crossroads across the open reach to Ember Isle's
	-- west beach, with nothing in the way: the place to hold a chain.
	run({
		name = "Ember Road",
		to = "EMBER ISLE",
		back = "CROSSROADS RUINS",
		spacing = 202,
		coins = 1,
		points = { from("Cross", 230, -480), from("Ember", -470, 200) },
	})
	-- FROST ROAD: up the temple's east coast and past the Two Sisters to Frost Spire, in one
	-- straight line. (It is laid through a point 60 studs west of the Sisters: they are its landmark.)
	local sisters = Seaways.rock("Sisters")
	local frostA = from("Temple", 440, 360)
	local frostB = frostA + (sisters + v3(-60, 0, 0) - frostA) * 1.5
	run({
		name = "Frost Road",
		to = "FROST SPIRE",
		back = "SUN TEMPLE",
		spacing = 190,
		coins = 1,
		points = { frostA, frostB },
	})
	-- LANTERN LINE: from north of the Two Sisters east to Lantern Key. It starts clear of the
	-- rocks, so a boat turning onto it from the Frost Road has open water to do it in.
	run({
		name = "Lantern Line",
		to = "LANTERN KEY",
		back = "FROST ROAD",
		spacing = 230,
		points = { sisters + v3(120, 0, -60), from("Lantern", -110, 75) },
	})
	-- TANGLE LANE: from the west of the Crossroads to Tangle Isle's dock.
	run({
		name = "Tangle Lane",
		to = "TANGLE ISLE",
		back = "CROSSROADS RUINS",
		spacing = 188,
		coins = 1,
		points = { from("Cross", -560, -130), from("Tangle", 40, 250) },
	})
	-- LEVIATHAN ROAD: north between Tangle Isle and the temple, past the Old Man, toward
	-- Leviathan's east dock. Straight: the Old Man stands 60 studs to port. It stops 300 studs
	-- short on purpose. The Sleeper off that dock wakes to fast boats, and a lane must not carry
	-- one over it at full chain: the last stretch is the pilot's to judge.
	run({
		name = "Leviathan Road",
		to = "LEVIATHAN'S REST",
		back = "TANGLE ISLE",
		spacing = 157,
		coins = 1,
		points = { from("Tangle", 540, -220), from("Bone", 295, 365) },
	})
	-- NORTHERN DRIFT: along the top of the map with the current, and a ramp half way.
	local a, b = from("Frost", -500, -220), from("Bone", 380, -240)
	run({
		name = "Northern Drift",
		to = "LEVIATHAN'S REST",
		back = "FROST SPIRE",
		spacing = 185,
		points = { a, b },
	})
	ramp(a:Lerp(b, 0.46) + v3(0, 0, 48), b - a, "DRIFT JUMP") -- beside the lane, in the same current
end

-- THE WESTERN SHALLOWS ---------------------------------------------------------------------
local function buildShallows()
	local shelf = from("Kelp", Seaways.SHELF[1], Seaways.SHELF[2])
	-- The Sandbar Jump: two hoops in, the ramp over the bar, one hoop out.
	local bar = Seaways.JUMP_BAR
	local way = Seaways.JUMP_WAY
	local center = shelf + v3((bar[1] + bar[3]) / 2, 0, (bar[2] + bar[4]) / 2)
	run({ name = "Shelf Hop", exact = true, adrift = false, points = { center - way * 250, center - way * 135 } })
	ramp(center - way * 28, way, "SANDBAR JUMP: go fast!")
	Kit.hoop(v3(center.X + 130, 5, center.Z + 10), way, 12, LANE)
	-- TIDE RUN: from the water west of Gull Rock straight to the edge of the shelf. The hoops
	-- stop there on purpose. The way on to the Tide Vault's pier winds between sandbars, and a
	-- hoop would throw a boat at them: so that part is a trail of coins, which shows the channel
	-- (north about Kelp Cay) and leaves the speed to the pilot. No patrol ship can follow it.
	local gull = from("Gull")
	local edge = shelf + v3(330, 0, 8)
	run({
		name = "Tide Run",
		to = "THE TIDE VAULT",
		back = "GOBLIN COVE",
		spacing = 184,
		points = { gull + v3(-170, 0, -45), edge },
	})
	breadcrumbs({
		edge,
		shelf + v3(168, 0, -8),
		shelf + v3(80, 0, -80),
		shelf + v3(-50, 0, -105),
		shelf + v3(-230, 0, 25),
		shelf + v3(-306, 0, 95),
	}, 62)
end

-- TIMED COURSES ----------------------------------------------------------------------------
-- Pars are a competent run, measured by driving each course with the game's own boat physics
-- (the V6 report says how). Change a course and its par must be measured again.
local function buildCourses()
	-- THE TEETH: a run threaded between the stacks east of the Crossroads. The coins weave.
	-- A chain of hoops holds a boat at 150 to 175 studs a second, and at that speed a skiff needs
	-- about 180 studs of radius to turn and a moment before its course follows its bow. Driven
	-- with the game's own physics, a boat stayed on a course whose line bent 8 degrees at a gate
	-- and left one that bent 24. So the gates stand about 145 apart on a line that hardly bends,
	-- with a stack close on alternate sides: the rocks going past are the danger, not the
	-- steering. (V5 set seven gates 80 to 120 apart with 25 to 55 studs of sidestep between them.
	-- Driven at speed, a boat was off the course by the third gate and into a stack.)
	local teeth = from("Cross", Seaways.TEETH[1], Seaways.TEETH[2])
	run({
		name = "THE TEETH",
		timed = true,
		exact = true,
		par = PAR.Teeth,
		coins = 2,
		sway = 10,
		points = {
			teeth + v3(-265, 0, 50),
			teeth + v3(-115, 0, 22),
			teeth + v3(25, 0, -12),
			teeth + v3(160, 0, -52),
			teeth + v3(295, 0, -78),
		},
	})
	for _, at in ipairs({ { -195, 26 }, { -38, -19 }, { 45, 19 }, { 150, -26 } }) do
		coin(teeth + v3(at[1], COIN_Y, at[2]), Vector3.xAxis, 5) -- hugging a stack
	end
	-- CINDER SLALOM: from Lantern Key through the basalt stacks to the mouth of Skull Rock, laid
	-- out by the same rule. (V5's course ended at an empty shore, and had a stack on the straight
	-- line between two of its hoops.)
	local cinders = from("Ember", Seaways.CINDERS[1], Seaways.CINDERS[2])
	run({
		name = "CINDER SLALOM",
		timed = true,
		exact = true,
		par = PAR.Cinder,
		coins = 2,
		sway = 10,
		points = {
			cinders + v3(-270, 0, -50),
			cinders + v3(-115, 0, -82),
			cinders + v3(15, 0, -128),
			cinders + v3(110, 0, -152),
			cinders + v3(270, 0, -165),
		},
	})
	for _, at in ipairs({ { -168, -95 }, { 42, -150 }, { 168, -143 } }) do
		coin(cinders + v3(at[1], COIN_Y, at[2]), Vector3.xAxis, 5)
	end
	-- SERPENT RUN: a sprint straight down the channel, with the fastest current in the sea.
	local mid, axis = Seaways.serpent()
	run({
		name = "SERPENT RUN",
		timed = true,
		spacing = 120,
		par = PAR.Serpent,
		coins = 1,
		points = { mid + axis * 240, mid, mid - axis * 240 },
	})
	-- LOOKOUT LOOP: a lap round Lookout Stack, in open water west of home. The one to learn on:
	-- the widest turn in the sea (V5's Bay Circuit, moved out of the harbor's view).
	local lookout = Seaways.rock("Lookout")
	run({
		name = "LOOKOUT LOOP",
		timed = true,
		loop = true,
		exact = true,
		par = PAR.Lookout,
		points = ringOf(lookout + v3(40, 0, 40), LAP_RADIUS.Lookout, 8, -90), -- (off-center: clear of the shelf)
	})
	-- MAELSTROM RING: a lap round the outside of the whirlpool, tighter than the Lookout's. The
	-- fast line is the ring; the coins are inside it, where the water pulls.
	local whirl = from("Maelstrom")
	run({
		name = "MAELSTROM RING",
		timed = true,
		loop = true,
		exact = true,
		par = PAR.Maelstrom,
		points = ringOf(whirl, LAP_RADIUS.Maelstrom, 8, 150),
	})
	for k = 0, 3 do -- Deeper in, where the pull is stronger, the coins are bigger.
		local a = math.rad(170 + k * 80)
		coin(whirl + v3(math.cos(a) * 128, COIN_Y, math.sin(a) * 128), v3(-math.sin(a), 0, math.cos(a)), 5)
	end
end

-- Coins that lead somewhere, and one at each lone rock for whoever can hug stone.
local function buildDiscoveries()
	local temple = from("Temple")
	trail(temple + v3(520, 0, 6), temple + v3(310, 0, -6), 6) -- up the Serpent River
	local tangle = from("Tangle")
	trail(tangle + v3(30, 0, -440), tangle + v3(15, 0, -260), 6) -- up the Hidden River
	local skull = from("Skull")
	trail(skull + v3(0, 0, 330), skull + v3(0, 0, 70), 6) -- into the skull's mouth
	local bone = from("Bone")
	trail(bone + v3(20, 0, -330), bone + v3(250, 0, -400), 7) -- under the ribs
	local fort = from("Fort")
	trail(fort + v3(0, 0, 420), fort + v3(0, 0, 250), 5, 5) -- into the fort's harbor: big coins, bad idea
	-- The quiet water's landmarks: thread the Two Sisters, or scrape round a stack.
	local sisters = Seaways.rock("Sisters")
	coin(sisters + v3(25, COIN_Y, 12.5), Vector3.zAxis, 5)
	for _, entry in ipairs({
		{ "Chimney", 0, 22 },
		{ "OldMan", 28, 0 },
		{ "Widow", 0, 23 },
		{ "Pillar", 0, 26 },
		{ "Anvil", -44, 0 },
		{ "Lookout", 24, 0 },
	}) do
		coin(Seaways.rock(entry[1]) + v3(entry[2], COIN_Y, entry[3]), Vector3.zAxis, 5)
	end
end

function Searuns.build()
	folders.coins = Kit.folder("Coins", folders.root)
	refs.coins = {}
	refs.runs = {}
	refs.lanes = {}
	buildHomeWaters()
	buildLanes()
	task.wait()
	buildShallows()
	buildCourses()
	buildDiscoveries()
	refs.coinTotal = #refs.coins
end

return Searuns

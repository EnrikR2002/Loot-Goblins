-- Things to do while sailing (V5): hoop runs, coin trails, stunt ramps and timed runs.
--
-- The V4 playtest found the boost hoops the best thing about travelling, so there are now about a
-- hundred of them, laid out as RUNS: a chain of hoops along a line someone would want to sail
-- anyway, close enough together that each kick carries into the next.
--
--   lanes     easy chains on the open-water legs between islands
--   slaloms   hoops threaded between the sea stacks (the Teeth, the Cinders)
--   timed     a run with a sign at each end: beat the par, see the best time (Coins.lua times it)
--
-- Coins lie along the runs, round the rocks and in the air over the ramps, and a few trails
-- lead into places worth finding (a hidden inlet, the Back Door). A run is an offer, never a
-- fence: nothing here blocks the open water beside it.
--
-- Everything is placed from island positions (shared/Archipelago.lua) and from the features in
-- Seaways.lua, so the runs follow when the map moves. Like the other builders this only
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

-- A sign over one end of a timed run. Returns its label, which Coins.lua rewrites with the best time.
local function runSign(position, text)
	local holder = Kit.decor("RunSign", v3(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), nil)
	holder.Transparency = 1
	local gui = Kit.sign(holder, text, TIMED, Vector3.zero, 420)
	gui.Size = UDim2.fromOffset(300, 44)
	return gui:FindFirstChildOfClass("TextLabel")
end

-- Lays a run. def:
--   name     shown on the signs of a timed run
--   points   world waypoints
--   spacing  studs between hoops (default 125); `exact` puts one hoop on every waypoint instead
--   timed    true: a timed run. par defaults to its length at a brisk speed.
--   coins    coins between each pair of hoops (default 3; 0 for none)
--   sway     coins step this far left and right of the line in turn (a weave to follow)
--   skip     { [hoop number] = true }: leave that hoop out (where a ramp stands instead)
local function run(def)
	local samples, total = curve(def.points)
	local color = def.timed and TIMED or LANE
	local marks = {} -- distances along the curve where the hoops stand
	if def.exact then
		for i = 1, #def.points do
			table.insert(marks, samples[(i - 1) * 20 + 1].distance)
		end
	else
		local spacing = def.spacing or 125
		local count = math.max(2, math.floor(total / spacing + 0.5) + 1)
		for i = 0, count - 1 do
			table.insert(marks, total * i / (count - 1))
		end
	end
	local checkpoints = {}
	for i, distance in ipairs(marks) do
		local position, heading = along(samples, distance)
		if not (def.skip and def.skip[i]) then
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
		end
		table.insert(checkpoints, v3(position.X, 0, position.Z))
		-- Coins from this hoop to the next.
		local nextDistance = marks[i + 1]
		local coins = def.coins or 3
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
	if def.timed then
		-- A par nobody has driven: a brisk average speed over the length, plus a moment to get going.
		local par = def.par or (math.floor((total / 100 + 1.5) * 2 + 0.5) / 2)
		local first, last = checkpoints[1], checkpoints[#checkpoints]
		local text = string.format("%s - par %.1f s", def.name, par)
		table.insert(refs.runs, {
			name = def.name,
			par = par,
			length = total,
			checkpoints = checkpoints,
			labels = { runSign(first + v3(0, 26, 0), text), runSign(last + v3(0, 26, 0), text) },
		})
	end
	return checkpoints
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

-- The runs --------------------------------------------------------------------------------
local function buildHomeWaters()
	local home = from("Home")
	local gate = Seaways.GATE
	-- BAY CIRCUIT: a lap of the water inside the reef. The first thing a new goblin tries.
	run({
		name = "BAY CIRCUIT",
		timed = true,
		spacing = 118,
		points = {
			home + v3(-200, 0, -450),
			home + v3(-60, 0, -545),
			home + v3(150, 0, -555),
			home + v3(300, 0, -470),
			home + v3(210, 0, -375),
			home + v3(-150, 0, -365),
		},
	})
	-- GATE RUN: out of the harbor, through the Gate, to the Crossroads' dock.
	run({
		name = "Gate Run",
		spacing = 120,
		points = { home + v3(30, 0, -430), home + v3(60, 0, gate[3]), from("Cross", 40, 330) },
	})
	-- BACK DOOR ARC: round the south of the island, from Coral Atoll past the Back Door to Pebble Isle.
	run({
		name = "Back Door Arc",
		spacing = 135,
		points = {
			from("Coral", -200, -60),
			home + v3(260, 0, 450),
			home + v3(10, 0, 505),
			home + v3(-260, 0, 440),
			from("Pebble", 170, -60),
		},
	})
	-- Trails into places worth finding.
	trail(home + v3(10, 0, 440), home + v3(10, 0, 330), 4) -- up the Back Door cove
	local smuggler = from("Smuggler")
	trail(smuggler + v3(-120, 0, 76), smuggler + v3(-10, 0, 100), 4) -- into the hidden lagoon
	-- Big coins right on the reef's crest: worth it, if the hull can take the scrape.
	for _, at in ipairs({ { -372, -546 }, { -150, -648 }, { 280, -638 }, { 530, -560 } }) do
		coin(home + v3(at[1], COIN_Y, at[2]), Vector3.zAxis, 5, true)
	end
	-- The harbor jump (built with the island): coins over it.
	for k, air in ipairs({ { -288, 13 }, { -304, 17 }, { -320, 13 } }) do
		coin(home + v3(0, air[2], air[1]), -Vector3.zAxis, k == 2 and 5 or 1, true)
	end
end

local function buildLanes()
	local home = from("Home")
	-- WEST RUN: Gull Pass to the Shipwreck Shoals' dock, with a ramp on the way.
	local west = {
		home + v3(-285, 0, -612),
		home + v3(-500, 0, -742),
		from("Shoals", 440, 110),
		from("Shoals", 280, 30),
	}
	run({ name = "West Run", spacing = 120, points = west })
	ramp(from("Shoals", 600, 232), from("Shoals", 440, 110) - from("Shoals", 590, 185), "WEST JUMP") -- beside the lane
	-- MILL RUN: Smuggler's Gap, round the north of Smuggler's Cove, down the strait to Windmill Hills.
	run({
		name = "Mill Run",
		spacing = 140,
		points = {
			home + v3(430, 0, -605),
			home + v3(560, 0, -702),
			home + v3(800, 0, -662),
			from("Windmill", -330, -250),
			from("Windmill", -400, -40),
			from("Windmill", -350, 170),
		},
	})
	-- REACH RUN: the open water north of the Teeth, from Pilgrim's Rock to Twin Stacks.
	run({
		name = "Reach Run",
		spacing = 125,
		points = {
			from("Pilgrim", 140, 60),
			from("Pilgrim", 390, 140),
			from("Twin", -250, -90),
			from("Twin", -80, -20),
		},
	})
	-- TANGLE LANE: from the temple's south-west shore to Tangle Isle's dock.
	run({
		name = "Tangle Lane",
		spacing = 125,
		points = {
			from("Temple", -600, 300),
			from("Temple", -760, 410),
			from("Tangle", 250, 220),
			from("Tangle", -20, 290),
		},
	})
	-- EMBER REACH: Crystal Isle's beach, past the Anvil, to Ember Isle's south dock. A ramp on the way.
	local anvil = Seaways.rock("Anvil")
	run({
		name = "Ember Reach",
		spacing = 130,
		points = {
			from("Crystal", 340, 240),
			from("Crystal", 490, 40),
			from("Crystal", 590, -140),
			anvil + v3(-100, 0, -60),
			from("Ember", 40, 520),
		},
	})
	ramp(from("Crystal", 585, -40), from("Crystal", 590, -140) - from("Crystal", 490, 40), "ANVIL JUMP") -- beside the lane
	-- LANTERN LINE: from the mouth of the temple's river to Lantern Key, past Two Sisters.
	run({
		name = "Lantern Line",
		spacing = 130,
		points = {
			from("Temple", 560, -20),
			from("Temple", 640, -130),
			from("Temple", 860, -170),
			from("Lantern", -280, 60),
			from("Lantern", -110, 80),
		},
	})
	-- MAELSTROM SLING: round the outside of the whirlpool. Deeper in, the coins are bigger.
	local whirl = from("Maelstrom")
	local ring = {}
	for k = 0, 5 do
		local a = math.rad(150 + k * 50)
		table.insert(ring, whirl + v3(math.cos(a) * 195, 0, math.sin(a) * 195))
	end
	run({ name = "Maelstrom Sling", exact = true, points = ring, coins = 2 })
	for k = 0, 3 do
		local a = math.rad(170 + k * 80)
		coin(whirl + v3(math.cos(a) * 128, COIN_Y, math.sin(a) * 128), v3(-math.sin(a), 0, math.cos(a)), 5)
	end
end

local function buildTimedRuns()
	-- PILGRIM'S RUN: the Crossroads' north dock, past the west side of Pilgrim's Rock, to the temple's dock.
	run({
		name = "PILGRIM'S RUN",
		timed = true,
		spacing = 118,
		points = {
			from("Cross", -60, -450),
			from("Pilgrim", -130, 60),
			from("Pilgrim", -120, -120),
			from("Temple", 40, 330),
		},
	})
	-- THE TEETH: a slalom between the stacks. One hoop on every waypoint; the coins weave.
	local teeth = from("Cross", Seaways.TEETH[1], Seaways.TEETH[2])
	run({
		name = "THE TEETH",
		timed = true,
		exact = true,
		sway = 10,
		points = {
			teeth + v3(-260, 0, 20),
			teeth + v3(-145, 0, 50),
			teeth + v3(-70, 0, 15),
			teeth + v3(15, 0, -20),
			teeth + v3(95, 0, -5),
			teeth + v3(175, 0, -60),
			teeth + v3(260, 0, -90),
		},
	})
	for _, at in ipairs({ { -195, 26 }, { -38, -19 }, { 45, 19 }, { 150, -26 } }) do
		coin(teeth + v3(at[1], COIN_Y, at[2]), Vector3.xAxis, 5) -- hugging a stack
	end
	-- SERPENT RUN: straight down the channel, with the current.
	local mid, axis = Seaways.serpent()
	run({
		name = "SERPENT RUN",
		timed = true,
		spacing = 120,
		par = 4,
		points = { mid + axis * 240, mid, mid - axis * 240 },
	})
	-- CINDER SLALOM: through the basalt stacks toward Ember Isle.
	local cinders = from("Ember", Seaways.CINDERS[1], Seaways.CINDERS[2])
	run({
		name = "CINDER SLALOM",
		timed = true,
		exact = true,
		sway = 10,
		points = {
			cinders + v3(-260, 0, -40),
			cinders + v3(-115, 0, -80),
			cinders + v3(-10, 0, 20),
			cinders + v3(90, 0, 90),
			cinders + v3(200, 0, 230),
		},
	})
	for _, at in ipairs({ { -63, -16 }, { 84, 33 }, { -14, 65 } }) do
		coin(cinders + v3(at[1], COIN_Y, at[2]), Vector3.xAxis, 5)
	end
	-- NORTHERN DRIFT: along the top of the map with the current, and a ramp half way.
	local a, b = from("Frost", -500, -220), from("Bone", 380, -240)
	run({ name = "NORTHERN DRIFT", timed = true, spacing = 124, par = 7, points = { a, b } })
	ramp(a:Lerp(b, 0.46) + v3(0, 0, 48), b - a, "DRIFT JUMP") -- beside the run, in the same current
end

-- The Sandbar Jump on the Western Shelf: two hoops in, the ramp, one hoop out.
local function buildShelfHop()
	local shelf = from("Kelp", Seaways.SHELF[1], Seaways.SHELF[2])
	local bar = Seaways.JUMP_BAR
	local way = Seaways.JUMP_WAY
	local center = shelf + v3((bar[1] + bar[3]) / 2, 0, (bar[2] + bar[4]) / 2)
	run({ name = "Shelf Hop", exact = true, coins = 2, points = { center - way * 250, center - way * 135 } })
	ramp(center - way * 28, way, "SANDBAR JUMP: go fast!")
	Kit.hoop(v3(center.X + 130, 5, center.Z + 10), way, 12, LANE)
end

-- Coins that lead somewhere.
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
end

function Searuns.build()
	folders.coins = Kit.folder("Coins", folders.root)
	refs.coins = {}
	refs.runs = {}
	buildHomeWaters()
	buildLanes()
	task.wait()
	buildTimedRuns()
	buildShelfHop()
	buildDiscoveries()
	refs.coinTotal = #refs.coins
end

return Searuns

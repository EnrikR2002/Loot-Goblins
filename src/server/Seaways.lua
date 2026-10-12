-- The water between the islands (V4): reefs, shallows, stack fields, lone rocks, currents and
-- the hoops that mark the sea lanes. The point is that a voyage is never a straight line across
-- nothing: there is always a landmark to steer by and a choice of water to take.
--
--   WRECKER'S REEF    closes Home Bay. One deep gap (the Gate) that any ship can use, and two
--                     shallow passes (green lights) that only a skiff or a cutter can cross.
--   WESTERN SHALLOWS  a wide sandy shelf around Kelp Cay: too shallow for a patrol ship anywhere,
--                     with dry bars to steer around (or jump: there is a ramp).
--   THE TEETH         a field of sea stacks between the Crossroads and Crystal Isle.
--   SERPENT CHANNEL   the strait between Tangle Isle and Fort Barnacle, narrowed by rocks, with
--                     the fastest current in the sea running down it.
--   THE CINDERS       basalt stacks between Ember Isle, Lantern Key and Skull Rock.
--   lone rocks        one tall stack in every stretch that would otherwise be empty horizon.
--
-- Depths that matter (SeaNav): a skiff needs 3.1 studs of water, a cutter 3.9, a patrol ship 5.6.
-- A reef crest is 1.2 deep (everything grounds; a fast skiff scrapes over and pays for it), a
-- pass is 3.7 deep and the shelf is 4.8.
--
-- Everything is in world coordinates. Like the island builders, this only describes.
local Kit = require(script.Parent.WorldKit)
local Landform = require(script.Parent.Landform)

local Seaways = {}

local folders = Kit.folders
local refs = Kit.refs
local decor, neon, deck = Kit.decor, Kit.neon, Kit.deck

local M = Enum.Material
local HAZE = Color3.fromRGB(96, 110, 126)
local GREEN = Color3.fromRGB(110, 255, 150)
local GOLD = Color3.fromRGB(255, 215, 110)

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

-- A floating label over a place in the sea.
local function nameplate(position, text, color, distance)
	local holder = decor("SeaSign", v3(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), nil)
	holder.Transparency = 1
	Kit.sign(holder, text, color or Color3.fromRGB(190, 235, 255), Vector3.zero, distance or 520)
end

-- Sea stacks: { x, z, radius, height } each, standing on a shallow foot. Returns their tops.
local function stacks(name, seed, list, material)
	local spec = { seed = seed, body = material or M.Rock, cliff = material or M.Rock, lobes = {} }
	for _, s in ipairs(list) do
		table.insert(spec.lobes, { kind = "mesa", x = s[1], z = s[2], r = s[3], h = s[4], wob = 0.14 })
		table.insert(spec.lobes, { kind = "hill", x = s[1], z = s[2], r = s[3] * 2.4, h = -6, e = -11, rough = 0 })
	end
	Landform.mark(Landform.build(spec), name, HAZE, folders.landmarks)
end

-- A lantern on a short pole standing in the water: marks a pass (green) or a gate (gold).
local function marker(x, z, color, height)
	height = height or 12
	Kit.cylinder("MarkerPole", 0.7, height + 8, v3(x, (height - 8) / 2, z), Kit.DARK_WOOD, M.Wood, folders.structures)
	local lamp = neon(decor("MarkerLamp", v3(2.2, 2.2, 2.2), CFrame.new(x, height + 1, z), color))
	lamp.Shape = Enum.PartType.Ball
	Kit.pointLight(lamp, color, 30, 1.4)
end

-- Wrecker's Reef ------------------------------------------------------------------------
local function buildReef()
	-- From Gull Rock east to Smuggler's Cove: crest, pass, crest, the Gate, crest, pass, crest.
	local crest, pass = -1.2, -3.7
	local runs = {
		{ -440, 1880, -330, 1760, crest },
		{ -330, 1760, -240, 1715, pass },
		{ -240, 1715, -50, 1690, crest },
		{ 170, 1695, 390, 1730, crest },
		{ 390, 1730, 470, 1760, pass },
		{ 470, 1760, 590, 1820, crest },
	}
	local spec = { seed = 201, lobes = {} }
	local random = Kit.rng(202)
	for _, run in ipairs(runs) do
		table.insert(spec.lobes, {
			kind = "hill",
			x = run[1],
			z = run[2],
			x2 = run[3],
			z2 = run[4],
			r = 34,
			h = run[5],
			e = run[5] - 6,
			rough = 0,
			wob = 0.2,
			slope = 0.25,
		})
		if run[5] == crest then
			-- Rocks that break the surface along a crest, so the reef can be seen from a boat.
			local length = math.sqrt((run[3] - run[1]) ^ 2 + (run[4] - run[2]) ^ 2)
			for d = 20, length - 10, 62 do
				local t = d / length
				local x = run[1] + (run[3] - run[1]) * t + random:NextNumber(-6, 6)
				local z = run[2] + (run[4] - run[2]) * t + random:NextNumber(-6, 6)
				table.insert(spec.lobes, {
					kind = "mesa",
					x = x,
					z = z,
					r = random:NextNumber(6, 9),
					h = random:NextNumber(4, 11),
					body = M.Rock,
					wob = 0.2,
				})
				Kit.coral(v3(x + 12, -1, z + 6), 300 + d, 3)
			end
		else
			marker(run[1], run[2], GREEN)
			marker(run[3], run[4], GREEN)
		end
	end
	Landform.build(spec)
	-- The Gate: two tall posts with perches (grapple them) and a hoop between.
	Kit.hookPost(v3(-50, -8, 1690), 30, GOLD)
	Kit.hookPost(v3(170, -8, 1695), 30, GOLD)
	nameplate(v3(60, 40, 1692), "THE GATE", GOLD, 700)
	nameplate(v3(-285, 22, 1738), "GULL PASS (shallow)", GREEN, 420)
	nameplate(v3(430, 22, 1745), "SMUGGLER'S GAP (shallow)", GREEN, 420)
	Kit.hoop(v3(60, 5, 1692), v3(0, 0, -1), 12, GOLD)
end

-- The Western Shallows -------------------------------------------------------------------
local function buildShallows()
	local spec = { seed = 211, lobes = {} }
	local function bar(x, z, x2, z2, h, r)
		table.insert(spec.lobes, {
			kind = "hill",
			x = x,
			z = z,
			x2 = x2,
			z2 = z2,
			r = r or 30,
			h = h,
			e = h - 6,
			rough = 0,
			wob = 0.25,
			slope = 0.22,
		})
	end
	-- The shelf itself: 4.8 studs of water for 400 studs around the cay.
	table.insert(spec.lobes, { kind = "mesa", x = -2080, z = 1500, r = 520, h = -4.8, e = -9, flat = 0.85, wob = 0.2 })
	bar(-1790, 1310, -1850, 1430, 1.8, 20) -- Thin enough to jump: the Sandbar Jump crosses it.
	bar(-2000, 1300, -1880, 1280, -3.7)
	bar(-2260, 1230, -2100, 1160, 1.8)
	bar(-2380, 1480, -2250, 1590, -3.7)
	bar(-2320, 1720, -2210, 1830, 1.8)
	bar(-1500, 1370, -1380, 1500, 1.8)
	bar(-2600, 1560, -2500, 1660, 1.8)
	Landform.build(spec)
	-- Green lamps ring the shelf, the same sign as the reef passes: shallow water, no patrol ships.
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		marker(-2080 + math.cos(a) * 450, 1500 + math.sin(a) * 450, GREEN, 10)
	end
	nameplate(v3(-2080, 60, 1500), "WESTERN SHALLOWS (no patrol ships)", GREEN, 700)
	-- The Sandbar Jump: a ramp in the deep water in front of the thin bar, pointing at home. (Tried
	-- with the ramp on the bar itself: a boat stalls on it. It has to be hit from open water.)
	local homeward = v3(0.89, 0, 0.46)
	Kit.kicker(v3(-1820, 0, 1370) - homeward * 28, homeward, 16)
	nameplate(v3(-1845, 18, 1356), "SANDBAR JUMP: go fast!", Color3.fromRGB(255, 220, 90), 320)
	for _, palmAt in ipairs({ { -1795, 1322 }, { -2180, 1195 }, { -2265, 1775 }, { -1440, 1435 }, { -2550, 1610 } }) do
		Kit.palm(palmAt[1], palmAt[2], nil, 12)
	end
end

-- The Teeth ------------------------------------------------------------------------------
local function buildTeeth()
	stacks("TheTeeth", 221, {
		{ 720, 640, 12, 34 },
		{ 800, 480, 10, 22 },
		{ 860, 760, 14, 50 },
		{ 930, 580, 11, 40 },
		{ 990, 420, 13, 28 },
		{ 1040, 700, 16, 62 },
		{ 1090, 540, 10, 36 },
		{ 1150, 820, 12, 26 },
		{ 1180, 640, 14, 48 },
		{ 1240, 470, 11, 30 },
		{ 900, 880, 10, 20 },
	})
	deck("ToothDeck", v3(1040, 62, 700), 18)
	deck("ToothDeck", v3(860, 50, 760), 14)
	deck("ToothDeck", v3(1180, 48, 640), 14)
	table.insert(refs.kegCrates, Kit.kegCrate(v3(1043, 63, 702)))
	Kit.breakBridge("TeethBridge", v3(1052, 62.5, 695), v3(1170, 49, 645), 6, 5)
	Kit.hoop(v3(985, 5, 610), v3(1, 0, -0.1), 12)
	Kit.hoop(v3(1135, 5, 585), v3(1, 0, -0.2), 12)
	nameplate(v3(985, 80, 620), "THE TEETH", Color3.fromRGB(235, 235, 240), 600)
end

-- Serpent Channel --------------------------------------------------------------------------
local function buildSerpent()
	local mid = v3(-2275, 0, -750)
	local axis = v3(0.5, 0, -0.87) -- Along the channel, north-north-east.
	local across = v3(0.87, 0, 0.5) -- Toward Tangle Isle.
	local list = {}
	local random = Kit.rng(231)
	for _, along in ipairs({ -250, -90, 70, 230 }) do
		for _, side in ipairs({ -1, 1 }) do
			local at = mid + axis * (along + random:NextNumber(-25, 25)) + across * side * random:NextNumber(115, 150)
			table.insert(list, { at.X, at.Z, random:NextNumber(11, 17), random:NextNumber(26, 58) })
		end
	end
	stacks("SerpentRocks", 232, list)
	local head, tail = mid + axis * 330, mid - axis * 330
	Kit.stream("SERPENT CHANNEL", head, tail, 70, 28)
	Kit.hoop(mid + v3(0, 5, 0), axis, 13, Color3.fromRGB(255, 120, 110))
end

-- The Cinders ------------------------------------------------------------------------------
local function buildCinders()
	stacks("TheCinders", 241, {
		{ 2280, -1180, 14, 46 },
		{ 2420, -1260, 12, 60 },
		{ 2560, -1380, 15, 38 },
		{ 2350, -1450, 11, 52 },
		{ 2680, -1560, 13, 44 },
		{ 2500, -1640, 12, 30 },
		{ 2200, -1560, 10, 36 },
		{ 2620, -1150, 12, 54 },
	}, M.Basalt)
	deck("CinderDeck", v3(2420, 60, -1260), 14)
	table.insert(refs.kegCrates, Kit.kegCrate(v3(2422, 61, -1258)))
	Kit.hoop(v3(2470, 5, -1320), v3(0.55, 0, -0.83), 12, Color3.fromRGB(255, 150, 80))
	nameplate(v3(2450, 84, -1380), "THE CINDERS", Color3.fromRGB(255, 150, 90), 600)
end

-- Lone rocks -------------------------------------------------------------------------------
local function buildSentinels()
	stacks("OldMan", 251, { { -900, -1150, 18, 96 } })
	nameplate(v3(-900, 112, -1150), "THE OLD MAN", nil, 520)
	stacks("TwoSisters", 252, { { 980, -1250, 13, 70 }, { 1030, -1225, 11, 54 } })
	nameplate(v3(1000, 88, -1240), "TWO SISTERS", nil, 520)
	stacks("Anvil", 253, { { 2350, 150, 34, 40 } })
	deck("AnvilDeck", v3(2350, 40, 150), 30)
	table.insert(refs.kegCrates, Kit.kegCrate(v3(2356, 41, 146)))
	Kit.beacon(v3(2342, 41, 156), "the Anvil")
	nameplate(v3(2350, 64, 150), "THE ANVIL", nil, 520)
	stacks("LookoutStack", 254, { { -1150, 2250, 14, 60 } })
	nameplate(v3(-1150, 76, 2250), "LOOKOUT STACK", nil, 520)
	stacks("Chimney", 255, { { 900, 1400, 12, 70 } })
	nameplate(v3(900, 86, 1400), "THE CHIMNEY", nil, 520)
	stacks("NorthPillar", 256, { { -100, -1900, 16, 84 } })
	nameplate(v3(-100, 100, -1900), "NORTH PILLAR", nil, 520)
	stacks("Widow", 257, { { 1750, -350, 13, 64 } })
	nameplate(v3(1750, 80, -350), "THE WIDOW", nil, 520)
end

-- Currents and lanes -----------------------------------------------------------------------
local function buildCurrents()
	-- Out of the Crossroads and down to the Gate: treasure runs ride it home.
	Kit.stream("HOME STREAM v", v3(150, 0, 1290), v3(70, 0, 1660), 55, 18)
	-- From the Shoals toward the Crossroads, fast.
	Kit.stream("RUSHING STRAIT >", v3(-1230, 0, 1010), v3(-470, 0, 930), 60, 24)
	-- North up the Long Reach, toward the temple.
	Kit.stream("TEMPLE DRIFT ^", v3(-170, 0, 440), v3(-170, 0, -380), 55, 18)
	-- Out of the Cinders toward Twin Stacks: the way back from Ember Isle.
	Kit.stream("CINDER RUN", v3(2230, 0, -430), v3(1680, 0, 230), 55, 20)
	-- Along the top of the map, from Frost Spire to Leviathan's Rest.
	Kit.stream("NORTHERN DRIFT <", v3(640, 0, -2330), v3(-800, 0, -2330), 60, 20)
	-- From Windmill Hills into Home Bay.
	Kit.stream("MILL RACE", v3(1330, 0, 1990), v3(800, 0, 2230), 50, 18)
end

local function buildLanes()
	-- Hoops on the open-water legs: they push whichever way you are going.
	local lanes = {
		{ 0, 1985, 0, -1 }, -- outside the harbor mouth
		{ -640, 1560, -1, -0.5 }, -- Gull Pass to the Shoals
		{ 1000, 2090, 1, -0.3 }, -- Home Bay to Windmill Hills
		{ -30, 380, 0, -1 }, -- the Long Reach
		{ 620, -1700, 0.75, -0.66 }, -- the temple to Frost Spire
		{ -620, -1650, -0.7, -0.7 }, -- the temple to Leviathan's Rest
		{ 2300, 520, 1, 0.5 }, -- Crystal Isle to Maelstrom Rock
		{ -1150, 320, -0.5, -0.85 }, -- the Crossroads to Tangle Isle
		{ -1500, -1500, -0.85, -0.5 }, -- Tangle Isle to Driftwood Key
	}
	for _, lane in ipairs(lanes) do
		Kit.hoop(v3(lane[1], 5, lane[2]), v3(lane[3], 0, lane[4]), 12)
	end
end

function Seaways.build()
	buildReef()
	buildShallows()
	task.wait()
	buildTeeth()
	buildSerpent()
	buildCinders()
	task.wait()
	buildSentinels()
	buildCurrents()
	buildLanes()
end

return Seaways

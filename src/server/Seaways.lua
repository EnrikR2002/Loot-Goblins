-- The water between the islands: reefs, shallows, stack fields, lone rocks and currents. The point
-- is that a voyage is never a straight line across nothing: there is always a landmark to steer
-- by and a choice of water to take. (Searuns.lua lays the hoops, coins and ramps over all of it.)
--
--   WRECKER'S REEF    closes Home Bay. One deep gap (the Gate) that any ship can use, and two
--                     shallow passes (green lamps) that only a skiff or a cutter can cross.
--   WESTERN SHALLOWS  a sandy shelf around Kelp Cay: too shallow for a patrol ship anywhere,
--                     with dry bars to steer around (or jump: there is a ramp).
--   THE TEETH         a field of sea stacks between the Crossroads and Twin Stacks.
--   SERPENT CHANNEL   the strait between Tangle Isle and Fort Barnacle, narrowed by rocks, with
--                     the fastest current in the sea running down it.
--   THE CINDERS       basalt stacks between Ember Isle, Lantern Key and Skull Rock.
--   lone rocks        one tall stack in every stretch that would otherwise be empty horizon.
--
-- Depths that matter (SeaNav): a skiff needs 3.1 studs of water, a cutter 3.9, a patrol ship 5.6.
-- A reef crest is 1.2 deep (everything grounds; a fast skiff scrapes over and pays for it), a
-- pass is 3.7 deep and the shelf is 4.8.
--
-- Everything is placed from the islands' positions in shared/Archipelago.lua (an offset from an
-- island, or a point between two), so the sea follows when the islands move. V4 used fixed world
-- coordinates and all of it had to be re-laid by hand when V5 pulled the islands in.
-- Like the island builders, this only describes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
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

-- An island's center at sea level, plus an offset.
local function from(id, dx, dz)
	local island = Archipelago.byId[id]
	return v3(island.x + (dx or 0), 0, island.z + (dz or 0))
end

-- A floating label over a place in the sea.
local function nameplate(position, text, color, distance)
	local holder = decor("SeaSign", v3(1, 1, 1), CFrame.new(position), Color3.new(1, 1, 1), nil)
	holder.Transparency = 1
	Kit.sign(holder, text, color or Color3.fromRGB(190, 235, 255), Vector3.zero, distance or 520)
end

-- Sea stacks: { x, z, radius, height } each (world), standing on a shallow foot.
local function stacks(name, seed, list, material)
	local spec = { seed = seed, body = material or M.Rock, cliff = material or M.Rock, lobes = {} }
	for _, s in ipairs(list) do
		table.insert(spec.lobes, { kind = "mesa", x = s[1], z = s[2], r = s[3], h = s[4], wob = 0.14 })
		table.insert(spec.lobes, { kind = "hill", x = s[1], z = s[2], r = s[3] * 2.4, h = -6, e = -11, rough = 0 })
	end
	Landform.mark(Landform.build(spec), name, HAZE, folders.landmarks)
end

-- The same, from offsets around a center: { dx, dz, radius, height }.
local function stackField(name, seed, center, offsets, material)
	local list = {}
	for _, s in ipairs(offsets) do
		table.insert(list, { center.X + s[1], center.Z + s[2], s[3], s[4] })
	end
	stacks(name, seed, list, material)
	return list
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
-- Offsets from Goblin Cove: from Gull Rock east to Smuggler's Cove. Crest, pass, crest, the Gate,
-- crest, pass, crest.
Seaways.GATE = { -50, 170, -658 } -- The Gate's two posts (x offsets) and its line (z offset) from home.

local function buildReef()
	local home = from("Home")
	local crest, pass = -1.2, -3.7
	local runs = {
		{ -440, -470, -330, -590, crest },
		{ -330, -590, -240, -635, pass },
		{ -240, -635, -50, -660, crest },
		{ 170, -655, 390, -620, crest },
		{ 390, -620, 470, -590, pass },
		{ 470, -590, 590, -530, crest },
	}
	local spec = { seed = 201, lobes = {} }
	local random = Kit.rng(202)
	for _, run in ipairs(runs) do
		local x1, z1, x2, z2 = home.X + run[1], home.Z + run[2], home.X + run[3], home.Z + run[4]
		table.insert(spec.lobes, {
			kind = "hill",
			x = x1,
			z = z1,
			x2 = x2,
			z2 = z2,
			r = 34,
			h = run[5],
			e = run[5] - 6,
			rough = 0,
			wob = 0.2,
			slope = 0.25,
		})
		if run[5] == crest then
			-- Rocks that break the surface along a crest, so the reef can be seen from a boat.
			local length = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
			for d = 20, length - 10, 62 do
				local t = d / length
				local x = x1 + (x2 - x1) * t + random:NextNumber(-6, 6)
				local z = z1 + (z2 - z1) * t + random:NextNumber(-6, 6)
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
			marker(x1, z1, GREEN)
			marker(x2, z2, GREEN)
		end
	end
	Landform.build(spec)
	-- The Gate: two tall posts with perches (grapple them).
	local gate = Seaways.GATE
	Kit.hookPost(v3(home.X + gate[1], -8, home.Z + gate[3] - 2), 30, GOLD)
	Kit.hookPost(v3(home.X + gate[2], -8, home.Z + gate[3] + 3), 30, GOLD)
	nameplate(home + v3(60, 40, gate[3]), "THE GATE", GOLD, 700)
	nameplate(home + v3(-285, 22, -612), "GULL PASS (shallow)", GREEN, 420)
	nameplate(home + v3(430, 22, -605), "SMUGGLER'S GAP (shallow)", GREEN, 420)
end

-- The Western Shallows -------------------------------------------------------------------
Seaways.SHELF = { -20, 10, 400 } -- The shelf's center (offset from Kelp Cay) and radius.
-- The thin bar the Sandbar Jump crosses (offsets from the shelf's center), and the way boats jump it.
Seaways.JUMP_BAR = { -190, -70, -130, -170 }
Seaways.JUMP_WAY = Vector3.new(0.86, 0, 0.51)

local function buildShallows()
	local shelf = Seaways.SHELF
	local c = from("Kelp", shelf[1], shelf[2])
	local spec = { seed = 211, lobes = {} }
	local function bar(x, z, x2, z2, h, r)
		table.insert(spec.lobes, {
			kind = "hill",
			x = c.X + x,
			z = c.Z + z,
			x2 = c.X + x2,
			z2 = c.Z + z2,
			r = r or 30,
			h = h,
			e = h - 6,
			rough = 0,
			wob = 0.25,
			slope = 0.22,
		})
	end
	-- The shelf itself: 4.8 studs of water for 340 studs around its center.
	table.insert(
		spec.lobes,
		{ kind = "mesa", x = c.X, z = c.Z, r = shelf[3], h = -4.8, e = -9, flat = 0.85, wob = 0.2 }
	)
	local jump = Seaways.JUMP_BAR
	bar(jump[1], jump[2], jump[3], jump[4], 1.8, 20) -- Thin enough to jump: the Sandbar Jump crosses it.
	bar(-60, -250, 70, -250, -3.7)
	bar(-20, 270, 90, 320, 1.8)
	bar(170, 120, 120, 220, 1.8)
	Landform.build(spec)
	-- Green lamps ring the shelf, the same sign as the reef passes: shallow water, no patrol ships.
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		local x, z = c.X + math.cos(a) * 345, c.Z + math.sin(a) * 345
		if Kit.groundY(x, z, -30) < -2 then
			marker(x, z, GREEN, 10)
		end
	end
	nameplate(c + v3(0, 60, 0), "WESTERN SHALLOWS (no patrol ships)", GREEN, 700)
	for _, palmAt in ipairs({ { -130, -190 }, { 40, 300 }, { 140, 170 } }) do
		Kit.palm(c.X + palmAt[1], c.Z + palmAt[2], nil, 12)
	end
end

-- The Teeth ------------------------------------------------------------------------------
-- A stack field east of the Crossroads. Offsets are from its center.
Seaways.TEETH = { 690, -150 } -- Center, as an offset from Crossroads Ruins.
Seaways.TEETH_STACKS = {
	{ -195, 0, 12, 34 },
	{ -135, -120, 10, 22 },
	{ -90, 90, 14, 50 },
	{ -38, -45, 11, 40 },
	{ 8, -165, 13, 28 },
	{ 45, 45, 16, 62 },
	{ 82, -75, 10, 36 },
	{ 128, 135, 12, 26 },
	{ 150, 0, 14, 48 },
	{ 195, -128, 11, 30 },
	{ -60, 180, 10, 20 },
}

local function buildTeeth()
	local c = from("Cross", Seaways.TEETH[1], Seaways.TEETH[2])
	stackField("TheTeeth", 221, c, Seaways.TEETH_STACKS)
	deck("ToothDeck", c + v3(45, 62, 45), 18)
	deck("ToothDeck", c + v3(-90, 50, 90), 14)
	deck("ToothDeck", c + v3(150, 48, 0), 14)
	table.insert(refs.kegCrates, Kit.kegCrate(c + v3(48, 63, 47)))
	Kit.breakBridge("TeethBridge", c + v3(57, 62.5, 40), c + v3(140, 49, 5), 6, 5)
	nameplate(c + v3(0, 84, 0), "THE TEETH", Color3.fromRGB(235, 235, 240), 600)
end

-- Serpent Channel --------------------------------------------------------------------------
-- Returns the channel's middle and its axis (a unit vector along it, pointing north-east).
function Seaways.serpent()
	local tangle, fort = from("Tangle"), from("Fort")
	local across = (tangle - fort).Unit
	return (tangle + fort) / 2, v3(-across.Z, 0, across.X) * -1, across
end

local function buildSerpent()
	local mid, axis, across = Seaways.serpent()
	local list = {}
	local random = Kit.rng(231)
	for _, along in ipairs({ -200, -70, 60, 190 }) do
		for _, side in ipairs({ -1, 1 }) do
			local at = mid + axis * (along + random:NextNumber(-20, 20)) + across * side * random:NextNumber(98, 124)
			table.insert(list, { at.X, at.Z, random:NextNumber(11, 16), random:NextNumber(26, 58) })
		end
	end
	stacks("SerpentRocks", 232, list)
	Kit.stream("SERPENT CHANNEL", mid + axis * 270, mid - axis * 270, 60, 28)
end

-- The Cinders ------------------------------------------------------------------------------
Seaways.CINDERS = { -100, -520 } -- Center, as an offset from Ember Isle.
Seaways.CINDER_STACKS = {
	{ -112, 147, 14, 46 },
	{ -14, 91, 12, 60 },
	{ 84, 7, 15, 38 },
	{ -63, -42, 11, 52 },
	{ 168, -119, 13, 44 },
	{ 42, -175, 12, 30 },
	{ -168, -119, 10, 36 },
	{ 126, 168, 12, 54 },
}

local function buildCinders()
	local c = from("Ember", Seaways.CINDERS[1], Seaways.CINDERS[2])
	stackField("TheCinders", 241, c, Seaways.CINDER_STACKS, M.Basalt)
	deck("CinderDeck", c + v3(-14, 60, 91), 14)
	table.insert(refs.kegCrates, Kit.kegCrate(c + v3(-12, 61, 93)))
	nameplate(c + v3(0, 84, 0), "THE CINDERS", Color3.fromRGB(255, 150, 90), 600)
end

-- Lone rocks -------------------------------------------------------------------------------
-- One in each stretch of open water, placed between the islands around it.
Seaways.ROCKS = {
	OldMan = { "Temple", -640, -160, 18, 96, "THE OLD MAN" },
	Sisters = { "Temple", 700, -240, 13, 70, "TWO SISTERS" },
	Anvil = { "Ember", 200, 680, 34, 40, "THE ANVIL" },
	Lookout = { "Home", -1050, -82, 14, 60, "LOOKOUT STACK" },
	Chimney = { "Cross", 700, 340, 12, 70, "THE CHIMNEY" },
	Pillar = { "Temple", -70, -900, 16, 84, "NORTH PILLAR" },
	Widow = { "Ember", -680, 100, 13, 64, "THE WIDOW" },
}

function Seaways.rock(name)
	local rock = Seaways.ROCKS[name]
	return from(rock[1], rock[2], rock[3]), rock
end

local function buildSentinels()
	-- In a fixed order, so every rock gets the same seed (and so the same shape) every raid.
	for index, name in ipairs({ "OldMan", "Sisters", "Anvil", "Lookout", "Chimney", "Pillar", "Widow" }) do
		local rock = Seaways.ROCKS[name]
		local seed = 250 + index
		local at = from(rock[1], rock[2], rock[3])
		local list = { { at.X, at.Z, rock[4], rock[5] } }
		if name == "Sisters" then
			table.insert(list, { at.X + 50, at.Z + 25, 11, 54 })
		end
		stacks(name, seed, list)
		nameplate(at + v3(0, rock[5] + 16, 0), rock[6], nil, 520)
	end
	local anvil = Seaways.rock("Anvil")
	deck("AnvilDeck", anvil + v3(0, 40, 0), 30)
	table.insert(refs.kegCrates, Kit.kegCrate(anvil + v3(6, 41, -4)))
	Kit.beacon(anvil + v3(-8, 41, 6), "the Anvil")
end

-- Currents ---------------------------------------------------------------------------------
local function buildCurrents()
	-- From the Shoals toward the Crossroads, fast.
	Kit.stream("RUSHING STRAIT >", from("Shoals", 300, -40), from("Cross", -500, 40), 55, 24)
	-- North up the west side of the Long Reach, toward the temple.
	Kit.stream("TEMPLE DRIFT ^", from("Cross", -330, -270), from("Temple", -330, 530), 50, 18)
	-- Out of Ember Isle's water toward Twin Stacks: the way back from the Cinders.
	Kit.stream("CINDER RUN", from("Ember", -220, 310), from("Crystal", -110, -390), 50, 20)
	-- Along the top of the map, from Frost Spire to Leviathan's Rest.
	Kit.stream("NORTHERN DRIFT <", from("Frost", -440, -220), from("Bone", 320, -240), 55, 20)
	-- From Windmill Hills into Home Bay.
	Kit.stream("MILL RACE", from("Windmill", -430, 230), from("Home", 520, 38), 45, 18)
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
end

return Seaways

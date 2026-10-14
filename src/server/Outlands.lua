-- The new land around every island (V4), and what stands on it.
--
-- The islands' own builders (World.lua, Islands.lua, IslandsFar.lua) still make the place the
-- treasure is. This module grows each island outward first, with Landform: headlands, hills,
-- cliff-walled crags, sandbars and inlets, so an island is somewhere to explore and to choose a
-- way through, not a disc with a prize on it. Small islands stay small on purpose.
--
--   buildLand()    runs BEFORE the island builders: terrain only.
--   buildPlaces()  runs AFTER them: docks, boats, ziplines, catapults, beacons and the rest, which
--                  need the finished ground.
--   buildSilhouettes()  leaves a horizon silhouette of every island; run in the background.
--
-- Offsets in this file are from the island's center in shared/Archipelago.lua: +X east, +Z south.
-- Like the other builders, nothing here has logic of its own; mechanisms are described in `refs`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Archipelago = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Archipelago"))
local Kit = require(script.Parent.WorldKit)
local Landform = require(script.Parent.Landform)

local Outlands = {}

local folders = Kit.folders
local refs = Kit.refs
local ground, structure, decor, neon = Kit.ground, Kit.structure, Kit.decor, Kit.neon
local groundY, palm, dock, deck, ladder = Kit.groundY, Kit.palm, Kit.dock, Kit.deck, Kit.ladder
local plank, pointLight = Kit.plank, Kit.pointLight

local M = Enum.Material
local STONE, WOOD, DARK_WOOD = Kit.STONE, Kit.WOOD, Kit.DARK_WOOD
local BONE = Color3.fromRGB(240, 234, 214)

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

-- A function that turns an offset from the island's center into a world position.
local function from(i)
	return function(x, y, z)
		return Vector3.new(i.x + x, y, i.z + z)
	end
end

-- The ground under an offset from the island's center.
local function floorAt(i, x, z, default)
	return groundY(i.x + x, i.z + z, default or 0)
end

-- A spare boat floating free of any dock, bow toward `toward`.
local function moor(position, toward, typeName)
	local at = v3(position.X, 0.8, position.Z)
	table.insert(refs.boatSpawns, { cf = CFrame.lookAt(at, v3(toward.X, 0.8, toward.Z)), type = typeName or "skiff" })
end

-- A catapult at `a` that starts aimed at `b` (V8: it can be turned; see Kit.catapult).
local function catapult(a, b, label)
	return Kit.catapult(a, b, label)
end

-- Trees (or palms) scattered over the land between two radii, wherever the ground suits them.
local function grove(i, seed, count, minR, maxR, kind, leaf)
	local random = Kit.rng(seed)
	for _ = 1, count do
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(minR, maxR)
		local x, z = i.x + math.cos(a) * r, i.z + math.sin(a) * r
		local y = groundY(x, z, -50)
		if y > 3.2 and y < 40 then
			if kind == "palm" then
				palm(x, z, y, random:NextNumber(8, 15))
			else
				Kit.tree(x, z, y, random:NextNumber(11, 19), leaf)
			end
		end
	end
end

-- A wooden perch on top of a crag, so a grapple has somewhere to land.
local function perch(i, x, z, size, name)
	local y = floorAt(i, x, z, 20)
	deck(name or "CragDeck", v3(i.x + x, y, i.z + z), size or 12)
	return v3(i.x + x, y + 1, i.z + z)
end

-- A zipline off a crag. It starts from a post at the rim on the side it leaves by, so the rider
-- clears the edge instead of being dragged across the top.
local function zipFromCrag(name, top, to, rim)
	local start = top + Kit.flatDirection(top, to) * rim
	structure("ZipPost", v3(1, 11, 1), CFrame.new(start + v3(0, 5, 0)), DARK_WOOD, M.Wood)
	Kit.zipline(name, start + v3(0, 10, 0), to)
end

local function torch(position, color)
	color = color or Color3.fromRGB(255, 190, 110)
	local lamp = neon(decor("Lantern", v3(1, 1.4, 1), CFrame.new(position), color))
	pointLight(lamp, color, 26, 1.3)
	return lamp
end

local lands, places = {}, {}

-- Goblin Cove ---------------------------------------------------------------------------
-- Two arms now reach north around the docks and make a real harbor, with a watch crag on each
-- point; the hills behind the Hoard hide a second way in from the south, the Back Door.
function lands.Home(i)
	return Landform.shaper(i.x, i.z, { seed = 11 })
		.ridge(-185, 30, -330, -70, 66, 22)
		.ridge(-330, -70, -290, -300, 58, 24)
		.mesa(-245, -335, 40, 44)
		.ridge(175, -20, 290, -200, 60, 12)
		.mesa(255, -300, 36, 32)
		.hill(-150, 235, 125, 36)
		.hill(140, 250, 115, 24)
		.ridge(-40, 185, 40, 185, 60, 14)
		.cut(10, 440, 10, 262, 40, -9)
		.build()
end

function places.Home(i)
	local P = from(i)
	-- West Watch: a harbor gun, a way up, and a zipline back down to the docks.
	local west = perch(i, -245, -335, 16, "WestWatch")
	Kit.cannon(west + v3(0, 0.2, -4), P(-245, 0, -700), "Harbor gun")
	Kit.rockRamp(P(-292, floorAt(i, -292, -262, 22), -262), P(-262, west.Y - 1, -312), 9, M.Rock)
	zipFromCrag("WatchZipline", west, P(-70, 12, -150), 27)
	-- East Watch: the other gun. Its crag is lower; a ladder goes up the harbor side.
	local east = perch(i, 255, -300, 14, "EastWatch")
	Kit.cannon(east + v3(0, 0.2, -3), P(255, 0, -700), "Harbor gun")
	Kit.rockRamp(P(275, floorAt(i, 275, -212, 8), -212), P(260, east.Y - 1, -268), 9, M.Rock)
	-- A third dock on the west shore of the harbor: eight goblins need more than four boats.
	dock(P(-112, 0, -138), P(-152, 0, -190), { -1, 1 })
	-- The Back Door: a quiet cove behind the hideout hill, with its own dock and skiff.
	dock(P(10, 0, 240), P(10, 0, 306), { 1 })
	local doorSign = decor("BackDoorSign", v3(1, 1, 1), CFrame.new(P(10, 16, 300)), Color3.new(1, 1, 1), nil)
	doorSign.Transparency = 1
	Kit.sign(doorSign, "THE BACK DOOR", Kit.GOLD, Vector3.zero, 260)
	grove(i, 21, 26, 190, 380, "palm")
end

-- Home Bay's small islands: left simple. Pebble gains a sandbar tail, Smuggler's a hidden lagoon.
function lands.Pebble(i)
	return Landform.shaper(i.x, i.z, { seed = 13 }).bar(30, 20, 150, 80, 26, 1.8).hill(170, 95, 34, 5).build()
end

function places.Pebble(i)
	local P = from(i)
	moor(P(-110, 0, -70), P(0, 0, -400))
	palm(i.x + 168, i.z + 94, nil, 12)
end

function lands.Smuggler(i)
	return Landform.shaper(i.x, i.z, { seed = 17 })
		.ridge(50, 30, 96, 112, 38, 24)
		.ridge(96, 112, 0, 166, 34, 18)
		.ridge(0, 166, -76, 112, 30, 10)
		.build()
end

function places.Smuggler(i)
	local P = from(i)
	-- A spare skiff nobody can see from the sea, in the lagoon behind the ridge.
	moor(P(14, 0, 100), P(-200, 0, 60))
	table.insert(refs.kegCrates, Kit.kegCrate(P(60, floorAt(i, 60, 62, 8), 62)))
	grove(i, 23, 8, 60, 140, "palm")
end

function places.Coral(i)
	local P = from(i)
	moor(P(-150, 0, -110), P(-600, 0, -400))
end

function places.Gull(i)
	local P = from(i)
	Kit.beacon(P(-4, 66.5, 4), "Gull Rock")
end

function places.Twin(i)
	local P = from(i)
	Kit.beacon(P(4, 48.6, -4), "Twin Stacks")
	moor(P(46, 0, 30), P(-400, 0, 400))
end

-- Crossroads Ruins ----------------------------------------------------------------------
-- The hub. High ground to the north-west with a crag that overlooks everything (and a catapult
-- on it aimed at the acropolis), a meadow and a second dock facing the temple, a sand spit to the
-- east and a drowned colonnade you can wade to the west.
function lands.Cross(i)
	return Landform.shaper(i.x, i.z, { seed = 31 })
		.ridge(-150, -120, -320, -40, 86, 40)
		.mesa(-345, -70, 40, 66)
		.hill(-60, -250, 110, 18)
		.ridge(190, 20, 350, 100, 52, 6)
		.hill(370, 120, 46, 12)
		.bar(-200, 110, -390, 180, 30, -2.6)
		.hill(-410, 190, 40, 9)
		.build()
end

function places.Cross(i)
	local P = from(i)
	local crag = perch(i, -345, -70, 16, "WatchCrag")
	Kit.beacon(crag + v3(-4, 0, -4), "Crossroads")
	Kit.rockRamp(P(-262, floorAt(i, -262, -52, 30), -52), P(-318, crag.Y - 1, -66), 9, M.Rock)
	catapult(crag + v3(5, 0.2, 3), P(-20, 42, -20), "CATAPULT: aim it anywhere")
	dock(P(-60, 0, -338), P(-60, 0, -402), { 1 })
	-- The drowned colonnade: broken columns mark a way you can wade.
	for k = 0, 6 do
		local t = k / 6
		local at = P(-200 - 190 * t, -3, 110 + 70 * t)
		Kit.column(at + v3(0, 0, 12), 16, 2, STONE, k % 2 == 0)
		Kit.column(at + v3(0, 0, -12), 16, 2, STONE, k % 3 == 0)
	end
	table.insert(refs.kegCrates, Kit.kegCrate(P(-410, floorAt(i, -410, 190, 9), 190)))
	moor(P(410, 0, 200), P(900, 0, 400))
	grove(i, 33, 30, 200, 380, "tree")
	grove(i, 34, 8, 330, 400, "palm")
end

-- Pilgrim's Rock: a sea stack a third of the way from the temple to the Crossroads. The Sun
-- Spire's zipline lands on it; a skiff waits at its foot, and so might anyone who saw you coming.
function lands.Pilgrim(i)
	return Landform.shaper(i.x, i.z, { seed = 37, body = M.Rock })
		.mesa(0, 0, 20, i.top, { wob = 0.12 })
		.hill(22, 30, 46, 5, { body = M.Sand })
		.build()
end

function places.Pilgrim(i)
	local P = from(i)
	deck("PilgrimDeck", P(0, i.top, 0), 18)
	Kit.rockRamp(P(30, floorAt(i, 30, 36, 4), 36), P(8, i.top, 10), 8, M.Rock)
	Kit.beacon(P(-5, i.top + 1, -5), "Pilgrim's Rock")
	dock(P(40, 0, 56), P(40, 0, 116), { 1 })
	palm(i.x + 44, i.z + 30, nil, 12)
	Kit.islandSign(P(0, 70, 0), i.name, i.color)
end

-- The Sun Temple -------------------------------------------------------------------------
-- The old island is now the heart of a much bigger one: jungle to the west and east, highlands
-- behind the mesa, and the Serpent River, an inlet a boat can follow from the east coast right
-- up to the old shore. The Moon Altar, a crag on the highlands, has a catapult that lands you
-- on the mesa.
function lands.Temple(i)
	return Landform.shaper(i.x, i.z, { seed = 41, body = M.LeafyGrass })
		.hill(-270, 30, 170, 26)
		.hill(260, -70, 170, 30)
		.ridge(-140, -270, 170, -300, 120, 44)
		.mesa(-170, -290, 48, 70)
		.hill(-130, 290, 90, 12)
		.bar(-330, 230, -470, 330, 30, -2.4)
		.hill(-490, 350, 44, 10)
		.cut(480, 10, 215, -10, 30, -8)
		.build()
end

function places.Temple(i)
	local P = from(i)
	local altar = perch(i, -170, -290, 20, "MoonAltar")
	for _, off in ipairs({ { 7, 7 }, { -7, 7 }, { 7, -7 }, { -7, -7 } }) do
		Kit.column(altar + v3(off[1], 0, off[2]), 11, 1.1, Color3.fromRGB(200, 210, 235), false)
	end
	torch(altar + v3(0, 9, 0), Color3.fromRGB(170, 200, 255))
	catapult(altar + v3(6, 0.2, 2), P(-78, 56, 10), "CATAPULT: aim it anywhere")
	Kit.rockRamp(P(-95, floorAt(i, -95, -278, 44), -278), P(-140, altar.Y - 1, -288), 9, M.Rock)
	-- The Serpent River's landing: a skiff hidden at the head of the inlet.
	moor(P(285, 0, -5), P(700, 0, 20))
	torch(P(256, 14, -40), Color3.fromRGB(255, 205, 90))
	torch(P(256, 14, 30), Color3.fromRGB(255, 205, 90))
	moor(P(-560, 0, 330), P(-800, 0, 600))
	table.insert(refs.kegCrates, Kit.kegCrate(P(260, floorAt(i, 260, -110, 20), -110)))
	grove(i, 43, 46, 250, 440, "tree", Color3.fromRGB(40, 140, 70))
end

-- Crystal Isle ---------------------------------------------------------------------------
-- A north shore, a beach with a second dock, and the Shards: basalt needles standing on a shelf
-- off the north-east coast, close enough together to grapple from one to the next.
local SHARDS =
	{ { 250, -150, 16, 58 }, { 300, -80, 13, 44 }, { 330, -190, 18, 70 }, { 390, -120, 14, 52 }, { 210, -230, 12, 36 } }

function lands.Crystal(i)
	local shaper = Landform.shaper(i.x, i.z, { seed = 47 })
		.ridge(-190, -150, 60, -250, 70, 28)
		.hill(150, 210, 120, 16)
		.hill(300, -150, 150, -3, { e = -9, rough = 0 })
	for _, s in ipairs(SHARDS) do
		shaper.mesa(s[1], s[2], s[3], s[4], { body = M.Basalt, wob = 0.15 })
	end
	return shaper.build()
end

function places.Crystal(i)
	local P = from(i)
	dock(P(214, 0, 276), P(258, 0, 320), { 1 })
	local tall = perch(i, 330, -190, 14, "ShardDeck")
	perch(i, 250, -150, 12, "ShardDeck")
	perch(i, 390, -120, 11, "ShardDeck")
	table.insert(refs.kegCrates, Kit.kegCrate(tall + v3(3, 0, 0)))
	for _, s in ipairs(SHARDS) do
		local glow = Kit.glow(P(s[1], s[4] + 5, s[2]), Color3.fromRGB(215, 110, 255), 26)
		glow.Size = v3(2.4, 2.4, 2.4)
	end
	zipFromCrag("ShardZipline", tall, P(165, 25, 195), 9)
	grove(i, 49, 14, 180, 300, "palm")
end

-- Shipwreck Shoals -----------------------------------------------------------------------
-- Sandbars ring the old atoll now, with gaps between them: a maze a skiff can thread and a
-- deep-keeled patrol ship cannot.
function lands.Shoals(i)
	return Landform.shaper(i.x, i.z, { seed = 53 })
		.bar(-250, -230, -40, -330, 34, 1.8)
		.bar(110, -300, 310, -190, 30, 1.8)
		.bar(-330, 110, -200, 300, 34, 1.8)
		.bar(40, 310, 240, 250, 30, -2.4)
		.hill(-290, -260, 44, 8)
		.hill(330, -170, 40, 7)
		.build()
end

function places.Shoals(i)
	local P = from(i)
	-- A second wreck, broken on the north bar: its deck is a ramp, its gun still works.
	local hull = CFrame.new(P(-150, 3.4, -282)) * CFrame.Angles(0, math.rad(64), math.rad(9))
	local wood = Color3.fromRGB(110, 78, 52)
	ground("BrokenHull", v3(16, 2, 44), hull, wood, M.WoodPlanks)
	structure("BrokenRib", v3(1.4, 9, 44), hull * CFrame.new(-8, 4, 0), wood, M.WoodPlanks)
	structure(
		"BrokenMast",
		v3(1.6, 30, 1.6),
		hull * CFrame.new(0, 13, 8) * CFrame.Angles(0, 0, math.rad(24)),
		DARK_WOOD,
		M.Wood
	)
	Kit.cannon((hull * CFrame.new(2, 1.6, -14)).Position, P(400, 0, -100), "Wreck gun")
	table.insert(refs.kegCrates, Kit.kegCrate(P(-290, floorAt(i, -290, -260, 8), -260)))
	moor(P(390, 0, -110), P(800, 0, -200))
	grove(i, 55, 12, 240, 360, "palm")
end

-- Kelp Cay: a low sandy key in the middle of the Western Shallows. A boat, a beacon and a small
-- prize, somewhere to stop between the Shoals and the Tide Vault.
function lands.Kelp(i)
	return Landform.shaper(i.x, i.z, { seed = 59 })
		.hill(0, 0, 60, 7)
		.bar(40, 20, 130, 70, 22, 1.6)
		.hill(-50, -30, 30, 12)
		.build()
end

function places.Kelp(i)
	local P = from(i)
	local y = floorAt(i, 0, 0, 7)
	ground("SextantStand", v3(5, 2, 5), CFrame.new(P(0, y + 1, 0)), STONE, M.Cobblestone)
	Kit.lootSpot("Sextant", CFrame.new(P(0, y + 2 + 2.2, 0)))
	Kit.beacon(P(-50, floorAt(i, -50, -30, 12), -30), "Kelp Cay")
	dock(P(-30, 0, 52), P(-30, 0, 112), { 1 })
	table.insert(refs.kegCrates, Kit.kegCrate(P(24, floorAt(i, 24, -18, 6), -18)))
	grove(i, 61, 9, 12, 70, "palm")
	Kit.islandSign(P(0, 44, 0), i.name, i.color)
end

-- Windmill Hills -------------------------------------------------------------------------
-- Shepherd's Ridge runs east to a watch crag with a beacon and a long zipline back to the dock;
-- terraces to the north and a meadow to the west give the farm somewhere to sprawl.
function lands.Windmill(i)
	return Landform.shaper(i.x, i.z, { seed = 61 })
		.ridge(140, -70, 300, 30, 88, 44)
		.mesa(320, 60, 36, 60)
		.hill(-70, -200, 120, 20)
		.hill(-250, 20, 90, 12)
		.build()
end

function places.Windmill(i)
	local P = from(i)
	local crag = perch(i, 320, 60, 15, "ShepherdsWatch")
	Kit.beacon(crag + v3(4, 0, -4), "Windmill Hills")
	Kit.rockRamp(P(250, floorAt(i, 250, 20, 36), 20), P(296, crag.Y - 1, 50), 9, M.Rock)
	zipFromCrag("ShepherdZipline", crag, P(8, 14, 150), 24)
	dock(P(-250, 0, 96), P(-290, 0, 150), { 1 })
	local random = Kit.rng(63)
	for k = 1, 9 do
		local x, z = -70 + random:NextNumber(-80, 80), -200 + random:NextNumber(-70, 70)
		local y = floorAt(i, x, z, -50)
		if y > 4 then
			local field = decor(
				"Field",
				v3(random:NextNumber(16, 28), 0.3, random:NextNumber(16, 28)),
				CFrame.new(P(x, y + 0.2, z)) * CFrame.Angles(0, k, 0),
				k % 2 == 0 and Color3.fromRGB(235, 205, 90) or Color3.fromRGB(120, 190, 80),
				M.Grass
			)
			field.CanQuery = false
		end
	end
	grove(i, 65, 18, 170, 320, "tree")
end

-- The Tide Vault -------------------------------------------------------------------------
-- A broken ring of sandbars around the shallows, and two drowned towers: the west one rings.
function lands.Tide(i)
	return Landform.shaper(i.x, i.z, { seed = 67 })
		.bar(-250, -120, -140, -250, 30, 1.6)
		.bar(180, -210, 270, -60, 30, 1.6)
		.bar(250, 110, 110, 260, 32, 1.6)
		.bar(-120, 270, -270, 130, 32, -2.4)
		.mesa(-235, 140, 20, 38, { body = M.Slate, wob = 0.12 })
		.mesa(255, -220, 16, 30, { body = M.Slate, wob = 0.12 })
		.build()
end

function places.Tide(i)
	local P = from(i)
	local tower = perch(i, -235, 140, 14, "BellTower")
	Kit.beacon(tower + v3(0, 0, 0), "the Tide Vault")
	for _, off in ipairs({ { 5, 5 }, { -5, 5 }, { 5, -5 }, { -5, -5 } }) do
		Kit.column(tower + v3(off[1], 0, off[2]), 12, 1, Color3.fromRGB(200, 210, 220), false)
	end
	perch(i, 255, -220, 11, "DrownedTower")
	moor(P(150, 0, -290), P(600, 0, -500))
	-- A ramp in the deep water outside the south-west shoal: a cutter is too deep to cross it, but
	-- can jump it.
	Kit.kicker(P(-224, 0, 236), v3(0.68, 0, -0.73))
	grove(i, 69, 8, 190, 290, "palm")
end

-- Tangle Isle ----------------------------------------------------------------------------
-- More jungle and more pillars, so the canopy is a way across the whole island for anyone with a
-- grapple, and the Hidden River: a boat can come in from the north, unseen from the dock.
local PILLARS = { { -180, -130, 12, 58 }, { -250, -10, 11, 66 }, { 70, -220, 12, 62 }, { -90, -190, 10, 50 } }

function lands.Tangle(i)
	local shaper = Landform.shaper(i.x, i.z, { seed = 71, body = M.LeafyGrass })
		.hill(-230, -70, 150, 30)
		.ridge(-60, -240, 190, -250, 90, 36)
		.hill(240, 60, 110, 20)
		.cut(30, -400, 10, -175, 24, -7)
	for _, p in ipairs(PILLARS) do
		shaper.mesa(p[1], p[2], p[3], p[4], { body = M.Rock, wob = 0.12 })
	end
	return shaper.build()
end

function places.Tangle(i)
	local P = from(i)
	local tops = {}
	for k, p in ipairs(PILLARS) do
		tops[k] = perch(i, p[1], p[2], p[3] * 1.3, "PillarDeck")
	end
	Kit.breakBridge("WestBridge", tops[1] + v3(8, 0, 4), tops[4] + v3(-7, 0, 2), 5, 5)
	Kit.zipline("JungleZipline", tops[2] + v3(0, 9, 0), P(-60, 16, 150))
	table.insert(refs.kegCrates, Kit.kegCrate(tops[3] + v3(2, 0, 2)))
	-- The river's landing, with a skiff tucked under the trees.
	moor(P(14, 0, -230), P(40, 0, -700))
	torch(P(34, 12, -190), Color3.fromRGB(110, 235, 130))
	grove(i, 73, 50, 180, 360, "tree", Color3.fromRGB(40, 140, 70))
end

-- Fort Barnacle --------------------------------------------------------------------------
-- The harbor now has two stone moles and a chain between them: pull the lever on the west mole
-- and the chain rises, so no ship leaves port (and none enters) until it drops. Siege Hill, to
-- the east, has a cannon that bears on the cracked wall and a catapult that clears it.
function lands.Fort(i)
	return Landform.shaper(i.x, i.z, { seed = 79 })
		.wall(-78, 180, -78, 330, 15, 9, { body = M.Slate, wob = 0.08 })
		.wall(78, 180, 78, 330, 15, 9, { body = M.Slate, wob = 0.08 })
		.ridge(-190, 40, -330, 150, 70, 22)
		.mesa(260, -30, 52, 38)
		.hill(240, 60, 110, 14)
		.hill(-170, -270, 110, 9)
		.build()
end

function places.Fort(i)
	local P = from(i)
	-- The harbor chain. Its resting place is under every keel; raised, it stops any hull.
	local chain = Instance.new("Model")
	chain.Name = "HarborChain"
	local lowered = CFrame.new(P(0, -9, 318))
	local links = Kit.partOf(chain, "Chain", v3(138, 1.8, 1.8), lowered, Color3.fromRGB(50, 50, 58), M.Metal)
	for k = -4, 4 do
		Kit.partOf(
			chain,
			"ChainFloat",
			v3(3.4, 3.4, 3.4),
			lowered * CFrame.new(k * 14, 0.3, 0),
			Color3.fromRGB(205, 60, 50),
			M.SmoothPlastic
		).Shape =
			Enum.PartType.Ball
	end
	chain.PrimaryPart = links
	chain.Parent = folders.structures
	local gate = {
		model = chain,
		closed = lowered,
		open = lowered * CFrame.new(0, 10.4, 0),
		name = "harbor chain",
		hold = Config.CHAIN_HOLD_TIME,
		pulled = "raised the harbor chain: Fort Barnacle's ships are locked in port!",
	}
	table.insert(refs.gates, gate)
	local moleTop = floorAt(i, -78, 322, 9)
	table.insert(refs.levers, Kit.lever(P(-78, moleTop, 322), "Harbor chain", gate))
	torch(P(-78, moleTop + 7, 328))
	torch(P(78, floorAt(i, 78, 322, 9) + 7, 328))
	for _, base in ipairs(refs.navyBases) do
		if base.id == "Fort" then
			base.chain = gate
		end
	end
	-- Siege Hill.
	local hill = perch(i, 262, -30, 22, "SiegeDeck")
	Kit.cannon(hill + v3(-6, 0.2, 0), P(52, 20, -10), "Siege cannon")
	catapult(hill + v3(2, 0.2, 7), P(20, 20, 14), "CATAPULT: aim it anywhere")
	Kit.rockRamp(P(272, floorAt(i, 272, 52, 10), 52), P(268, hill.Y - 1, 10), 10, M.Rock)
	table.insert(refs.kegCrates, Kit.kegCrate(hill + v3(6, 0, -6)))
	-- Gallows Point: a spare skiff out of sight of the walls.
	moor(P(-400, 0, 230), P(-700, 0, 500))
	grove(i, 81, 16, 200, 360, "palm")
end

-- Driftwood Key: wreckage and sand on the long crossing between the fort and Leviathan's Rest.
function lands.Driftwood(i)
	return Landform.shaper(i.x, i.z, { seed = 83 })
		.hill(0, 0, 56, 6)
		.hill(40, -30, 30, 14)
		.bar(-30, 30, -120, 70, 20, 1.6)
		.build()
end

function places.Driftwood(i)
	local P = from(i)
	local y = floorAt(i, 0, 0, 6)
	local wreck = CFrame.new(P(-8, y + 2, 6)) * CFrame.Angles(math.rad(8), math.rad(-30), math.rad(14))
	structure("DriftHull", v3(12, 5, 30), wreck, Color3.fromRGB(110, 78, 52), M.WoodPlanks)
	structure(
		"DriftMast",
		v3(1.4, 26, 1.4),
		wreck * CFrame.new(0, 12, 4) * CFrame.Angles(0, 0, math.rad(20)),
		DARK_WOOD,
		M.Wood
	)
	Kit.lootSpot("Castaway", CFrame.new(P(14, floorAt(i, 14, -6, 6) + 2.4, -6)))
	Kit.beacon(P(40, floorAt(i, 40, -30, 14), -30), "Driftwood Key")
	dock(P(10, 0, 50), P(10, 0, 110), { -1 })
	table.insert(refs.kegCrates, Kit.kegCrate(P(-26, floorAt(i, -26, -14, 5), -14)))
	grove(i, 85, 7, 10, 60, "palm")
	Kit.islandSign(P(0, 46, 0), i.name, i.color)
end

-- Ember Isle -----------------------------------------------------------------------------
-- A lava delta to the east with a river of fire down its middle (jump it), a black beach to the
-- south with a second dock below the geysers, and the first of the Cinders off the north-east.
local CINDERS = { { 330, -230, 15, 50 }, { 400, -150, 12, 38 }, { 290, -320, 13, 64 }, { 430, -290, 16, 44 } }

function lands.Ember(i)
	local shaper = Landform.shaper(i.x, i.z, { seed = 89, body = M.Basalt, shore = M.Basalt, cliff = M.Basalt })
		.ridge(170, 20, 340, 80, 84, 18)
		.hill(0, 290, 120, 7)
		.hill(-250, 90, 90, 22)
		.cut(215, 36, 420, 108, 15, 5)
	for _, s in ipairs(CINDERS) do
		shaper.mesa(s[1], s[2], s[3], s[4], { wob = 0.15 })
	end
	return shaper.build()
end

function places.Ember(i)
	local P = from(i)
	-- The river of fire: lava in the gully the delta was cut with.
	local a, b = P(215, 3, 36), P(420, 3, 108)
	Kit.terrain:FillBlock(CFrame.lookAt((a + b) / 2, b), v3(13, 5, (b - a).Magnitude), M.CrackedLava)
	local zone = Kit.lavaZone((a + b) / 2 + v3(0, 3, 0), v3(12, 6, (b - a).Magnitude), 20)
	zone.CFrame = CFrame.lookAt((a + b) / 2 + v3(0, 3, 0), b + v3(0, 3, 0))
	for k = 0, 4 do
		pointLight(
			decor(
				"LavaGlow",
				v3(1, 1, 1),
				CFrame.new(a:Lerp(b, k / 4) + v3(0, 4, 0)),
				Color3.fromRGB(255, 120, 40),
				M.Neon
			),
			Color3.fromRGB(255, 120, 40),
			34,
			1.6
		)
	end
	dock(P(0, 0, 398), P(0, 0, 462), { 1 })
	perch(i, 290, -320, 12, "CinderDeck")
	local deckB = perch(i, 330, -230, 13, "CinderDeck")
	table.insert(refs.kegCrates, Kit.kegCrate(deckB + v3(2, 0, 2)))
	moor(P(-400, 0, 190), P(-800, 0, 400))
end

-- Lantern Key: a rock with a lantern tower between Ember Isle, Frost Spire and Skull Rock.
function lands.Lantern(i)
	return Landform.shaper(i.x, i.z, { seed = 97, body = M.Rock })
		.mesa(0, 0, 26, 22, { wob = 0.12 })
		.hill(-30, 30, 50, 6, { body = M.Sand })
		.hill(40, -20, 30, 4, { body = M.Sand })
		.build()
end

function places.Lantern(i)
	local P = from(i)
	local top = floorAt(i, 0, 0, 22)
	Kit.cylinder("LanternTower", 5, 26, P(0, top + 13, 0), Color3.fromRGB(230, 220, 200), M.Brick, folders.structures)
	ground("LanternGallery", v3(15, 1, 15), CFrame.new(P(0, top + 26.5, 0)), WOOD, M.WoodPlanks)
	ladder("LanternLadder", P(8.6, top, 0), 27)
	Kit.lootSpot("Lantern", CFrame.new(P(0, top + 27 + 2.6, 0)))
	Kit.beacon(P(-9, top, -9), "Lantern Key")
	Kit.rockRamp(P(-26, floorAt(i, -26, 26, 5), 26), P(-12, top, 10), 8, M.Rock)
	dock(P(-40, 0, 66), P(-40, 0, 126), { 1 })
	table.insert(refs.kegCrates, Kit.kegCrate(P(40, floorAt(i, 40, -20, 4), -20)))
	Kit.islandSign(P(0, 78, 0), i.name, i.color)
end

-- Frost Spire ----------------------------------------------------------------------------
-- An ice shelf to the west, a second peak to the north, and floes drifting off the north shore:
-- flat ice you can hop and grapple across, or slalom a skiff through.
local FLOES = {
	{ -120, -330, 24 },
	{ -40, -400, 18 },
	{ 60, -420, 22 },
	{ -220, -260, 20 },
	{ 300, -330, 26 },
	{ 380, -220, 18 },
	{ 240, -420, 16 },
}

function lands.Frost(i)
	local shaper = Landform.shaper(i.x, i.z, { seed = 101, body = M.Snow, shore = M.Snow, cliff = M.Glacier })
		.hill(-270, 70, 130, 12)
		.hill(130, -270, 90, 64, { rough = 5 })
		.hill(260, 120, 90, 9)
	for _, f in ipairs(FLOES) do
		shaper.mesa(f[1], f[2], f[3], 2.8, { body = M.Glacier, shore = M.Glacier, e = -7, wob = 0.15, rough = 0 })
	end
	return shaper.build()
end

function places.Frost(i)
	local P = from(i)
	moor(P(50.3, 0, 227), P(50.3, 0, 700))
	local peak = perch(i, 130, -270, 12, "LittleSpire")
	table.insert(refs.kegCrates, Kit.kegCrate(peak + v3(2, 0, 2)))
	Kit.zipline("FloeZipline", peak + v3(0, 9, 0), P(-120, 9, -330))
	moor(P(-400, 0, 230), P(-800, 0, 600))
	for k, f in ipairs(FLOES) do
		if k % 2 == 1 then
			local shard = decor(
				"IceShard",
				v3(4, 10 + k * 2, 4),
				CFrame.new(P(f[1] + 4, 7, f[2] - 3)) * CFrame.Angles(0.2, k, -0.15),
				Color3.fromRGB(190, 235, 255),
				M.Glass,
				true
			)
			shard.Transparency = 0.25
		end
	end
end

-- Leviathan's Rest -----------------------------------------------------------------------
-- Salt hills to the south, tusks of rock off the west shore, and a second, smaller skeleton lying
-- in the water to the north: its ribs arch over a channel boats can run.
function lands.Bone(i)
	return Landform.shaper(i.x, i.z, { seed = 103, body = M.Salt })
		.hill(-60, 250, 120, 16)
		.hill(200, 180, 80, 8)
		.bar(60, -220, 260, -300, 30, 1.6)
		.mesa(-270, 160, 12, 46, { wob = 0.12 })
		.mesa(-320, 70, 10, 60, { wob = 0.12 })
		.mesa(-250, -150, 11, 38, { wob = 0.12 })
		.build()
end

function places.Bone(i)
	local P = from(i)
	moor(P(207, 0, 30.3), P(700, 0, 30.3))
	-- The rib run: arches over open water north of the bar, with a hoop at each end.
	local a, b = P(20, 0, -330), P(250, 0, -400)
	local along = (b - a).Unit
	local across = v3(-along.Z, 0, along.X)
	for k = 0, 7 do
		local center = a:Lerp(b, k / 7)
		for _, side in ipairs({ -1, 1 }) do
			local prev
			for s = 0, 6 do
				local angle = s / 6 * 1.4
				local point = center
					+ across * side * (5 + 17 * math.cos(angle))
					+ v3(0, -4 + 28 * math.sin(angle) / math.sin(1.4), 0)
				if prev then
					plank("RunRib", prev, point, 2.6, 2.6, BONE, M.Marble, folders.structures, 0.5)
				end
				prev = point
			end
		end
	end
	Kit.hoop(a + v3(0, 5, 0) - along * 24, along, 10, Color3.fromRGB(120, 255, 190))
	Kit.hoop(b + v3(0, 5, 0) + along * 24, along, 10, Color3.fromRGB(120, 255, 190))
	perch(i, -320, 70, 9, "TuskDeck")
	local tusk = perch(i, -270, 160, 10, "TuskDeck")
	table.insert(refs.kegCrates, Kit.kegCrate(tusk + v3(1, 0, 1)))
end

-- Skull Rock -----------------------------------------------------------------------------
-- Teeth of rock ring the approach to the mouth, a spine of high ground runs north behind the
-- cranium, and a skiff now waits in the lagoon inside.
local TEETH = { 28, 44, 60, 120, 136, 152 }

function lands.Skull(i)
	local shaper = Landform.shaper(i.x, i.z, { seed = 107, body = M.Rock })
		.ridge(-30, -120, 80, -290, 60, 34)
		.hill(-220, -40, 80, 10)
	for k, degrees in ipairs(TEETH) do
		local out = Kit.compass(degrees) * 250
		shaper.mesa(out.X, out.Z, 11, 18 + (k % 3) * 8, { wob = 0.12 })
	end
	return shaper.build()
end

function places.Skull(i)
	local P = from(i)
	moor(P(-15, 0, -6), P(-15, 0, 400))
	for k, degrees in ipairs(TEETH) do
		if k % 2 == 0 then
			local out = Kit.compass(degrees) * 250
			perch(i, out.X, out.Z, 9, "ToothDeck")
		end
	end
	moor(P(-330, 0, 10), P(-800, 0, 100))
	local spine = P(60, floorAt(i, 60, -250, 34), -250)
	structure("ZipPost", v3(1, 17, 1), CFrame.new(spine + v3(0, 8, 0)), DARK_WOOD, M.Wood)
	Kit.zipline("SpineZipline", spine + v3(0, 16, 0), P(-200, 16, -50))
end

function places.Maelstrom(i)
	local P = from(i)
	moor(P(60, 0, 50), P(-400, 0, 400))
end

-- The color an island is on the horizon: its own, seen through a lot of sea air.
local function haze(island)
	return island.color:Lerp(Color3.fromRGB(92, 108, 124), 0.62)
end

-- Build ----------------------------------------------------------------------------------
function Outlands.buildLand()
	for index, island in ipairs(Archipelago.islands) do
		local build = lands[island.id]
		if build then
			Landform.mark(build(island), "Crags" .. island.id, haze(island), folders.landmarks)
		end
		if index % 4 == 0 then
			task.wait()
		end
	end
end

function Outlands.buildPlaces()
	for _, island in ipairs(Archipelago.islands) do
		local build = places[island.id]
		if build then
			build(island)
		end
	end
end

-- The horizon: every island as a few buried blocks that never stream out. Run once all terrain
-- is final. It is two seconds of raycasts and nothing depends on it, so it takes a `budget`
-- (seconds of work per frame) and is run after the raid has started. Returns how many blocks.
function Outlands.buildSilhouettes(budget)
	local total = 0
	for _, island in ipairs(Archipelago.islands) do
		local _, count = Landform.silhouette(
			"Silhouette" .. island.id,
			island.x,
			island.z,
			island.r + 60,
			haze(island),
			folders.landmarks,
			budget
		)
		total += count
	end
	return total
end

return Outlands

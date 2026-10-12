-- The islands of the Goblin Sea: where they are, what they are called, how far in
-- they sit. Positions are in studs (north is -Z). The server builds the terrain from
-- these centers (World.lua, Islands.lua, IslandsFar.lua, Outlands.lua); the client reads
-- the same list for the world map, the compass and the floating names, so nothing is duplicated.
--
-- ring: 0 home, 1 near (easy, cheap loot), 2 middle (real trips), 3 far (commitment).
-- Loot value, danger and distance rise with the ring; the geography does the rest.
--
-- The sea is laid out in regions, not rings (V4). Distances were chosen from travel time: a
-- skiff does 108 studs a second, so 1000 studs is about nine seconds of sailing.
--
--   HOME BAY         Goblin Cove behind a reef arc, with four small islands 6-8 s away.
--   THE CROSSING     Crossroads Ruins, 13 s out: the hub every northern route passes.
--   WESTERN SHALLOWS Shipwreck Shoals and the Tide Vault in a maze of sandbars (20-23 s).
--   EASTERN REACH    Windmill Hills, Crystal Isle and Twin Stacks as a cluster (16-23 s),
--                    and Maelstrom Rock alone in open water beyond them (29 s).
--   NAVY WATERS      Tangle Isle and Fort Barnacle, either side of the Serpent Channel (31-41 s).
--   THE FAR NORTH    The Sun Temple (31 s), then Ember Isle, Frost Spire, Leviathan's Rest and
--                    Skull Rock at the edge of the map (37-49 s), with small keys on the long
--                    crossings to rest at.
--
-- The eight original islands were moved, not rebuilt; World.lua asserts that each moved by a
-- multiple of 4 studs, so change their x and z in steps of 4.
local Archipelago = {}

Archipelago.islands = {
	{ id = "Home", name = "GOBLIN COVE", x = 0, z = 2350, r = 430, ring = 0, color = Color3.fromRGB(255, 205, 50) },
	-- Home Bay: a short boat ride from home.
	{
		id = "Pebble",
		name = "PEBBLE ISLE",
		x = -600,
		z = 2640,
		r = 110,
		ring = 1,
		color = Color3.fromRGB(245, 225, 170),
	},
	{ id = "Coral", name = "CORAL ATOLL", x = 720, z = 2660, r = 160, ring = 1, color = Color3.fromRGB(255, 150, 130) },
	{ id = "Gull", name = "GULL ROCK", x = -520, z = 1928, r = 80, ring = 1, color = Color3.fromRGB(235, 235, 240) },
	{
		id = "Smuggler",
		name = "SMUGGLER'S COVE",
		x = 680,
		z = 1880,
		r = 150,
		ring = 1,
		color = Color3.fromRGB(190, 170, 140),
	},
	-- The Crossing.
	{
		id = "Cross",
		name = "CROSSROADS RUINS",
		x = 0,
		z = 900,
		r = 400,
		ring = 2,
		color = Color3.fromRGB(255, 245, 220),
	},
	-- Eastern Reach.
	{
		id = "Windmill",
		name = "WINDMILL HILLS",
		x = 1700,
		z = 1850,
		r = 330,
		ring = 2,
		color = Color3.fromRGB(190, 235, 120),
	},
	{
		id = "Crystal",
		name = "CRYSTAL ISLE",
		x = 1900,
		z = 700,
		r = 330,
		ring = 2,
		color = Color3.fromRGB(215, 110, 255),
	},
	{ id = "Twin", name = "TWIN STACKS", x = 1550, z = 420, r = 70, ring = 2, color = Color3.fromRGB(235, 235, 240) },
	{
		id = "Maelstrom",
		name = "MAELSTROM ROCK",
		x = 2950,
		z = 1450,
		r = 120,
		ring = 2,
		color = Color3.fromRGB(150, 190, 255),
	},
	-- Western Shallows.
	{
		id = "Shoals",
		name = "SHIPWRECK SHOALS",
		x = -1660,
		z = 1000,
		r = 360,
		ring = 2,
		color = Color3.fromRGB(255, 160, 70),
	},
	{ id = "Tide", name = "TIDE VAULT", x = -2500, z = 2000, r = 300, ring = 2, color = Color3.fromRGB(110, 230, 255) },
	{ id = "Kelp", name = "KELP CAY", x = -2080, z = 1560, r = 90, ring = 2, color = Color3.fromRGB(150, 210, 140) },
	-- Navy Waters.
	{
		id = "Tangle",
		name = "TANGLE ISLE",
		x = -1750,
		z = -450,
		r = 380,
		ring = 2,
		color = Color3.fromRGB(110, 230, 110),
	},
	{
		id = "Fort",
		name = "FORT BARNACLE",
		x = -2800,
		z = -1050,
		r = 380,
		ring = 3,
		color = Color3.fromRGB(255, 110, 100),
	},
	-- The Far North.
	-- top: the height of the stack's deck, where the Sun Spire's zipline lands.
	{
		id = "Pilgrim",
		name = "PILGRIM'S ROCK",
		x = 120,
		z = -340,
		r = 80,
		top = 30,
		ring = 2,
		color = Color3.fromRGB(255, 230, 150),
	},
	{ id = "Temple", name = "SUN TEMPLE", x = 0, z = -960, r = 460, ring = 3, color = Color3.fromRGB(255, 205, 40) },
	{ id = "Ember", name = "EMBER ISLE", x = 2600, z = -650, r = 400, ring = 3, color = Color3.fromRGB(255, 120, 50) },
	{
		id = "Lantern",
		name = "LANTERN KEY",
		x = 1900,
		z = -1400,
		r = 100,
		ring = 3,
		color = Color3.fromRGB(255, 200, 110),
	},
	{
		id = "Frost",
		name = "FROST SPIRE",
		x = 1100,
		z = -2250,
		r = 380,
		ring = 3,
		color = Color3.fromRGB(170, 230, 255),
	},
	{
		id = "Bone",
		name = "LEVIATHAN'S REST",
		x = -1150,
		z = -2200,
		r = 360,
		ring = 3,
		color = Color3.fromRGB(240, 235, 215),
	},
	{
		id = "Driftwood",
		name = "DRIFTWOOD KEY",
		x = -2050,
		z = -1780,
		r = 100,
		ring = 3,
		color = Color3.fromRGB(200, 170, 130),
	},
	{
		id = "Skull",
		name = "SKULL ROCK",
		x = 2850,
		z = -2100,
		r = 300,
		ring = 3,
		color = Color3.fromRGB(150, 255, 190),
	},
}

-- Region names for the world map: where you are in the sea, in a word.
Archipelago.regions = {
	{ name = "HOME BAY", x = 0, z = 2950 },
	{ name = "THE CROSSING", x = -800, z = 1420 },
	{ name = "WESTERN SHALLOWS", x = -2560, z = 1260 },
	{ name = "EASTERN REACH", x = 2440, z = 1230 },
	{ name = "NAVY WATERS", x = -2500, z = -300 },
	{ name = "THE LONG REACH", x = 780, z = 60 },
	{ name = "THE FAR NORTH", x = 60, z = -1900 },
	{ name = "THE CINDERS", x = 2500, z = -1380 },
}

Archipelago.byId = {}
for _, island in ipairs(Archipelago.islands) do
	Archipelago.byId[island.id] = island
end

-- The nearest island to a position (flat distance), or nil.
function Archipelago.nearest(x, z)
	local best, bestDistance = nil, math.huge
	for _, island in ipairs(Archipelago.islands) do
		local distance = math.sqrt((island.x - x) ^ 2 + (island.z - z) ^ 2)
		if distance < bestDistance then
			best, bestDistance = island, distance
		end
	end
	return best, bestDistance
end

return Archipelago

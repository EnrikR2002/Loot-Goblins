-- The islands of the Goblin Sea: where they are, what they are called, how far in
-- they sit. Positions are in studs (north is -Z). The server builds the terrain from
-- these centers (World.lua, Islands.lua); the client reads the same list for the
-- world map, the compass and the floating names, so nothing is duplicated.
--
-- ring: 0 home, 1 near (easy, cheap loot), 2 middle (real trips), 3 far (commitment).
-- Loot value, danger and distance rise with the ring; the geography does the rest.
local Archipelago = {}

Archipelago.islands = {
	{ id = "Home", name = "GOBLIN COVE", x = 0, z = 650, r = 190, ring = 0, color = Color3.fromRGB(255, 205, 50) },
	-- Near ring: a short boat ride from home.
	{ id = "Pebble", name = "PEBBLE ISLE", x = -300, z = 880, r = 70, ring = 1, color = Color3.fromRGB(245, 225, 170) },
	{ id = "Coral", name = "CORAL ATOLL", x = 330, z = 930, r = 140, ring = 1, color = Color3.fromRGB(255, 150, 130) },
	{ id = "Gull", name = "GULL ROCK", x = -360, z = 400, r = 60, ring = 1, color = Color3.fromRGB(235, 235, 240) },
	{
		id = "Smuggler",
		name = "SMUGGLER'S COVE",
		x = 380,
		z = 380,
		r = 80,
		ring = 1,
		color = Color3.fromRGB(190, 170, 140),
	},
	-- Middle ring.
	{
		id = "Windmill",
		name = "WINDMILL HILLS",
		x = 760,
		z = 650,
		r = 160,
		ring = 2,
		color = Color3.fromRGB(190, 235, 120),
	},
	{ id = "Cross", name = "CROSSROADS RUINS", x = 0, z = 0, r = 200, ring = 2, color = Color3.fromRGB(255, 245, 220) },
	{
		id = "Shoals",
		name = "SHIPWRECK SHOALS",
		x = -700,
		z = 20,
		r = 190,
		ring = 2,
		color = Color3.fromRGB(255, 160, 70),
	},
	{
		id = "Crystal",
		name = "CRYSTAL ISLE",
		x = 720,
		z = -40,
		r = 170,
		ring = 2,
		color = Color3.fromRGB(215, 110, 255),
	},
	{ id = "Tide", name = "TIDE VAULT", x = -1060, z = 560, r = 170, ring = 2, color = Color3.fromRGB(110, 230, 255) },
	{ id = "Twin", name = "TWIN STACKS", x = 370, z = -320, r = 50, ring = 2, color = Color3.fromRGB(235, 235, 240) },
	{
		id = "Tangle",
		name = "TANGLE ISLE",
		x = -520,
		z = -720,
		r = 200,
		ring = 2,
		color = Color3.fromRGB(110, 230, 110),
	},
	{
		id = "Maelstrom",
		name = "MAELSTROM ROCK",
		x = 1380,
		z = 330,
		r = 90,
		ring = 2,
		color = Color3.fromRGB(150, 190, 255),
	},
	-- Far ring: long, dangerous, valuable.
	{
		id = "Fort",
		name = "FORT BARNACLE",
		x = -1080,
		z = -400,
		r = 200,
		ring = 3,
		color = Color3.fromRGB(255, 110, 100),
	},
	{ id = "Temple", name = "SUN TEMPLE", x = 0, z = -720, r = 240, ring = 3, color = Color3.fromRGB(255, 205, 40) },
	{ id = "Ember", name = "EMBER ISLE", x = 1130, z = -430, r = 210, ring = 3, color = Color3.fromRGB(255, 120, 50) },
	{
		id = "Frost",
		name = "FROST SPIRE",
		x = 420,
		z = -1180,
		r = 210,
		ring = 3,
		color = Color3.fromRGB(170, 230, 255),
	},
	{
		id = "Bone",
		name = "LEVIATHAN'S REST",
		x = -450,
		z = -1200,
		r = 190,
		ring = 3,
		color = Color3.fromRGB(240, 235, 215),
	},
	{ id = "Skull", name = "SKULL ROCK", x = 1430, z = -900, r = 180, ring = 3, color = Color3.fromRGB(150, 255, 190) },
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

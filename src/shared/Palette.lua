-- The game's colours (V10, docs/ART_DIRECTION.md). One place for the art direction's palette, so the
-- world, the creatures, the boats and the interface agree. Change a colour here and in the guide.
local Palette = {}

local rgb = Color3.fromRGB

-- The base world.
Palette.SAND = rgb(222, 194, 140) -- warm gold: paler bleaches the shallows white in full sun
Palette.WET_SAND = rgb(196, 168, 118)
Palette.MEADOW = rgb(112, 196, 86)
Palette.MEADOW_DARK = rgb(78, 162, 70)
Palette.JUNGLE = rgb(52, 150, 74)
Palette.ROCK = rgb(126, 118, 116)
Palette.ROCK_LIGHT = rgb(168, 154, 160)
Palette.ROCK_DARK = rgb(70, 62, 78)
Palette.SEA_FLOOR = rgb(14, 44, 66)
Palette.WATER = rgb(12, 92, 132)
Palette.FAR_SEA = rgb(18, 80, 124) -- the flat sea beyond the map's walls, matched to the deep water by eye

-- Wood, rope and canvas.
Palette.WOOD = rgb(150, 98, 58)
Palette.WOOD_LIGHT = rgb(186, 134, 82)
Palette.WOOD_DARK = rgb(92, 58, 36)
Palette.DRIFTWOOD = rgb(196, 182, 160)
Palette.CANVAS = rgb(236, 222, 190)
Palette.ROPE = rgb(200, 170, 120)

-- Accents: one meaning each.
Palette.GOLD = rgb(255, 196, 46)
Palette.GOLD_DEEP = rgb(214, 150, 30)
Palette.DANGER = rgb(232, 64, 52)
Palette.GHOST = rgb(110, 255, 210)
Palette.CRYSTAL = rgb(186, 120, 255)
Palette.CRYSTAL_CYAN = rgb(110, 230, 255)
Palette.EMBER = rgb(255, 120, 40)
Palette.FROST = rgb(170, 228, 255)
Palette.SNOW = rgb(222, 234, 248) -- a touch of blue: pure white blows out in the sun
Palette.BONE = rgb(236, 228, 206)
Palette.GOBLIN = rgb(126, 184, 72) -- goblin skin: yellower than the meadows, so a goblin never melts into grass
Palette.NAVY = rgb(36, 62, 120)
Palette.CORAL = rgb(255, 128, 120)
Palette.CORAL_PEACH = rgb(255, 176, 128)
Palette.SANDSTONE = rgb(226, 190, 132)
Palette.MARBLE = rgb(214, 236, 236)
Palette.STONE = rgb(170, 164, 156)
Palette.STONE_DARK = rgb(112, 106, 104)
Palette.IRON = rgb(52, 54, 62)

-- Foliage: two greens per tree, picked by region.
Palette.LEAVES = {
	default = { rgb(86, 178, 74), rgb(58, 146, 66) },
	jungle = { rgb(46, 140, 70), rgb(30, 104, 60) },
	autumn = { rgb(232, 146, 52), rgb(206, 96, 44) },
	blossom = { rgb(196, 120, 220), rgb(150, 86, 196) },
	frost = { rgb(206, 236, 244), rgb(160, 206, 222) },
	ash = { rgb(92, 84, 80), rgb(64, 58, 56) },
}

-- Coral heads.
Palette.CORALS = {
	rgb(255, 120, 140),
	rgb(255, 170, 70),
	rgb(196, 112, 255),
	rgb(80, 220, 200),
	rgb(255, 214, 110),
}

-- Boat classes: hull, trim, stripe, sail, sail stripe.
Palette.BOATS = {
	skiff = {
		hull = rgb(168, 112, 64),
		trim = rgb(96, 60, 36),
		stripe = rgb(255, 196, 46),
		sail = rgb(244, 232, 204),
		sailStripe = rgb(226, 74, 60),
	},
	cutter = {
		hull = rgb(124, 86, 56),
		trim = rgb(70, 46, 30),
		stripe = rgb(64, 200, 196),
		sail = rgb(236, 226, 200),
		sailStripe = rgb(40, 150, 170),
	},
	navy = {
		hull = rgb(240, 240, 236),
		trim = rgb(36, 62, 120),
		stripe = rgb(36, 62, 120),
		sail = rgb(250, 250, 246),
		sailStripe = rgb(36, 62, 120),
	},
	default = {
		hull = rgb(150, 98, 58),
		trim = rgb(92, 58, 36),
		stripe = rgb(255, 196, 46),
		sail = rgb(236, 222, 190),
		sailStripe = rgb(226, 74, 60),
	},
}

return Palette

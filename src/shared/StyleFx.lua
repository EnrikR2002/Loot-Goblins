-- Boost trails, wakes, trick effects and callout styles (V11, Goblin Life): what each one looks like, as data. client/
-- Looks.lua draws them on boats, client/Tricks.lua styles the callouts, and the shop previews them from the same rows.
--
-- Budgets (docs/ART_DIRECTION.md "Performance rules"): a trail is one Trail object (cheap, no particles) plus at most
-- one sparkle emitter; wakes and trick effects are one emitter each, with capped rates and capped bursts; nothing is
-- drawn on a boat farther than DRAW_RANGE from the camera; ordinary tricks get the small burst and only a landing of
-- three or more tricks gets the big one. None of it hides a boat or a hazard: trails are thin and short-lived.
-- Textures are the particle files every Roblox client ships with (rbxasset://textures/particles/...).
local StyleFx = {}

local rgb = Color3.fromRGB
local P = "rbxasset://textures/particles/"

StyleFx.DRAW_RANGE = 420
StyleFx.BURST_CAP = 40

local function seq(...)
	local colors = { ... }
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, color in ipairs(colors) do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end
StyleFx.seq = seq

-- Boost trails: a ribbon behind the stern while boosting, and maybe sparkles. Light emission stays low: over the
-- bright sea a glowing ribbon washes out to white (checked in a Studio screenshot at boost speed).
StyleFx.TRAILS = {
	trail_gold = {
		colors = seq(rgb(255, 236, 140), rgb(255, 196, 46), rgb(214, 150, 40)),
		light = 0.35,
		lifetime = 0.7,
		sparkle = { texture = P .. "sparkles_main.dds", color = rgb(255, 226, 120), rate = 24, size = 1.2 },
	},
	trail_bubbles = {
		colors = seq(rgb(220, 250, 255), rgb(140, 220, 255)),
		light = 0.1,
		lifetime = 0.5,
		sparkle = {
			texture = P .. "forcefield_glow_main.dds",
			color = rgb(200, 240, 255),
			rate = 18,
			size = 1.6,
			float = true,
		},
	},
	trail_ember = {
		colors = seq(rgb(255, 220, 120), rgb(255, 120, 40), rgb(200, 40, 30)),
		light = 0.45,
		lifetime = 0.6,
		sparkle = { texture = P .. "fire_sparks_main.dds", color = rgb(255, 150, 60), rate = 26, size = 1.0 },
	},
	trail_ghost = {
		colors = seq(rgb(200, 255, 240), rgb(110, 255, 210), rgb(60, 140, 130)),
		light = 0.35,
		lifetime = 0.9,
		sparkle = { texture = P .. "smoke_main.dds", color = rgb(150, 255, 220), rate = 10, size = 2.2, float = true },
	},
	trail_rainbow = {
		colors = seq(
			rgb(255, 70, 70),
			rgb(255, 170, 40),
			rgb(255, 240, 70),
			rgb(80, 220, 90),
			rgb(60, 160, 255),
			rgb(170, 90, 255)
		),
		light = 0.05,
		lifetime = 0.8,
	},
	trail_aurora = {
		colors = seq(rgb(110, 255, 170), rgb(70, 220, 220), rgb(170, 110, 255)),
		light = 0.4,
		lifetime = 1.0,
		sparkle = { texture = P .. "sparkles_main.dds", color = rgb(190, 255, 230), rate = 14, size = 1.3 },
	},
}

-- Wakes: an extra stream of foam in the boat's colour at speed (the ordinary white wake stays underneath).
StyleFx.WAKES = {
	wake_glitter = { texture = P .. "sparkles_main.dds", color = rgb(255, 214, 90), size = 1.4, light = 1, rate = 0.35 },
	wake_ink = { texture = P .. "smoke_main.dds", color = rgb(64, 30, 90), size = 2.4, light = 0, rate = 0.25 },
	wake_petals = {
		texture = P .. "SquareParticle.png",
		color = rgb(255, 150, 196),
		size = 0.5,
		light = 0.2,
		rate = 0.3,
		spin = true,
	},
}

-- Trick effects: `during` streams off the hull through a trick; `land` bursts on a clean landing (big: 3+ tricks).
StyleFx.TRICKFX = {
	trickfx_stars = {
		during = { texture = P .. "sparkles_main.dds", color = rgb(255, 240, 120), rate = 60, size = 1.6 },
		land = { texture = P .. "sparkles_main.dds", color = rgb(255, 240, 120), count = 24, speed = 30 },
	},
	trickfx_confetti = {
		during = {
			texture = P .. "SquareParticle.png",
			colors = seq(rgb(255, 90, 160), rgb(90, 200, 255)),
			rate = 30,
			size = 0.5,
			spin = true,
		},
		land = {
			texture = P .. "SquareParticle.png",
			colors = seq(rgb(255, 80, 80), rgb(255, 220, 60), rgb(80, 220, 120), rgb(80, 160, 255)),
			count = 40,
			speed = 34,
			spin = true,
		},
	},
	trickfx_fireworks = {
		during = { texture = P .. "fire_sparks_main.dds", color = rgb(255, 200, 120), rate = 70, size = 1.0 },
		land = {
			texture = P .. "sparkles_main.dds",
			colors = seq(rgb(255, 120, 60), rgb(255, 230, 120)),
			count = 36,
			speed = 44,
			firework = true,
		},
	},
	trickfx_comet = {
		during = {
			texture = P .. "fire_main.dds",
			colors = seq(rgb(140, 220, 255), rgb(60, 100, 255)),
			rate = 90,
			size = 2.6,
			light = 1,
		},
		land = { texture = P .. "sparkles_main.dds", color = rgb(160, 220, 255), count = 30, speed = 38 },
	},
}

-- Callout styles: the trick names shouted on screen (your own) and over boats (others').
StyleFx.CALLOUTS = {
	callout_classic = {
		palette = { rgb(170, 255, 60), rgb(255, 70, 190), rgb(60, 230, 255), rgb(255, 170, 40), rgb(255, 240, 70) },
		stroke = rgb(20, 10, 30),
		font = Enum.Font.FredokaOne,
	},
	callout_gold = {
		palette = { rgb(255, 214, 70), rgb(255, 236, 150), rgb(255, 190, 40) },
		stroke = rgb(110, 60, 10),
		font = Enum.Font.FredokaOne,
		gradient = seq(rgb(255, 250, 200), rgb(255, 196, 46)),
	},
	callout_comic = {
		palette = { rgb(255, 255, 255) },
		stroke = rgb(20, 20, 30),
		font = Enum.Font.Bangers,
		back = { rgb(255, 60, 90), rgb(40, 170, 255), rgb(255, 210, 40) },
	},
	callout_spooky = {
		palette = { rgb(110, 255, 210), rgb(170, 255, 230) },
		stroke = rgb(10, 40, 40),
		font = Enum.Font.Creepster,
		wobble = true,
	},
	callout_royal = {
		palette = { rgb(255, 214, 90) },
		stroke = rgb(70, 20, 100),
		font = Enum.Font.Fondamento,
		gradient = seq(rgb(255, 230, 140), rgb(200, 150, 255)),
	},
}

-- V13.3: TITLES, a few words over a goblin's head that every client draws (client/Titles.lua) from the Look attribute.
-- text: what it says; color, stroke: its letters; glyph: a small mark before it; gradient (optional): gold letters.
StyleFx.TITLES = {
	title_landlubber = { text = "Landlubber", glyph = "⚓", color = rgb(214, 196, 160), stroke = rgb(60, 40, 24) },
	title_scallywag = { text = "Scallywag", glyph = "☠", color = rgb(255, 120, 90), stroke = rgb(50, 16, 12) },
	title_seadog = { text = "Old Sea Dog", glyph = "⚓", color = rgb(130, 210, 255), stroke = rgb(16, 40, 70) },
	title_royalty = {
		text = "Goblin Royalty",
		glyph = "♛",
		color = rgb(255, 214, 70),
		stroke = rgb(110, 60, 10),
		gradient = seq(rgb(255, 250, 200), rgb(255, 190, 40)),
	},
	title_regular = { text = "Port Regular", glyph = "★", color = rgb(196, 150, 255), stroke = rgb(40, 16, 70) },
	title_questor = { text = "Quest Taker", glyph = "✦", color = rgb(196, 150, 255), stroke = rgb(40, 16, 70) },
	title_challenger = { text = "The Challenger", glyph = "⚔", color = rgb(196, 150, 255), stroke = rgb(40, 16, 70) },
	title_haul = { text = "Haul Champion", glyph = "♛", color = rgb(255, 150, 110), stroke = rgb(70, 20, 10) },
	title_regatta = { text = "Regatta Ace", glyph = "⚑", color = rgb(255, 150, 110), stroke = rgb(70, 20, 10) },
	title_golf = { text = "Cannon Golf Ace", glyph = "⛳", color = rgb(255, 150, 110), stroke = rgb(70, 20, 10) },
	title_champion = {
		text = "Pirate Champion",
		glyph = "♛",
		color = rgb(255, 214, 70),
		stroke = rgb(90, 20, 20),
		gradient = seq(rgb(255, 236, 150), rgb(255, 120, 70)),
	},
	title_contender = {
		text = "Championship Contender",
		glyph = "★",
		color = rgb(255, 150, 110),
		stroke = rgb(70, 20, 10),
	},
	title_gauntlet = { text = "Gauntlet Legend", glyph = "✦", color = rgb(255, 150, 110), stroke = rgb(70, 20, 10) },
	title_weekcaptain = {
		text = "Captain of the Week",
		glyph = "♛",
		color = rgb(220, 170, 255),
		stroke = rgb(50, 16, 80),
		gradient = seq(rgb(255, 236, 160), rgb(200, 140, 255)),
	},
}

function StyleFx.covers(item)
	if item.slot == "title" then
		return StyleFx.TITLES[item.id] ~= nil
	elseif item.slot == "trail" then
		return StyleFx.TRAILS[item.id] ~= nil
	elseif item.slot == "wake" then
		return StyleFx.WAKES[item.id] ~= nil
	elseif item.slot == "trickfx" then
		return StyleFx.TRICKFX[item.id] ~= nil
	elseif item.slot == "callout" then
		return StyleFx.CALLOUTS[item.id] ~= nil
	end
	return false
end

return StyleFx

-- V13.2: world chaos. Eight events, each with its name, icon and line for the Port, its tuning, and a schedule that
-- leaves calm between episodes; and the sea's own share (rogue waves, whirlpools: shared/Sea.lua) behaving as water.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Sea = require(Shared.Sea)

local X = Config.CHAOS
-- Emoji Roblox's interface font draws (the team's notebook: newer ones show as empty boxes).
local SAFE_ICONS = {
	["☄"] = true,
	["🐙"] = true,
	["🌊"] = true,
	["💣"] = true,
	["💥"] = true,
	["🌀"] = true,
	["👻"] = true,
	["⚡"] = true,
}

return function(t)
	t.test("eight events, each with a name, an icon that draws, a line, and its own tuning", function()
		t.eq(#X.EVENTS, 8, "eight")
		local seen = {}
		for _, entry in ipairs(X.EVENTS) do
			t.ok(not seen[entry.id], entry.id .. ": twice")
			seen[entry.id] = true
			t.ok(#entry.name > 3 and #entry.name <= 24, entry.id .. ": a short name")
			t.ok(SAFE_ICONS[entry.icon], entry.id .. ": an icon the font draws")
			t.ok(#entry.line > 20 and #entry.line < 110, entry.id .. ": a one-line description")
			t.ok(type(X[entry.id]) == "table", entry.id .. ": its tuning")
		end
	end)

	t.test("a raid holds several episodes with calm between them", function()
		-- The fewest episodes: the latest first one, the longest calms, episodes as long as they get.
		local longest = {
			meteors = 14,
			kraken = 18,
			waves = 30,
			crossfire = 20,
			barrels = 14,
			whirls = 31,
			haunted = 31,
			thunder = 22,
		}
		for id, length in pairs(longest) do
			local at, count = X.FIRST[2], 0
			while at < Config.RAID_DURATION - X.LAST do
				count += 1
				at += length + X.CALM[2]
			end
			t.ok(count >= 4, id .. ": at least four episodes (" .. count .. ")")
			t.ok(X.CALM[1] >= 10, "a real calm between")
		end
		t.ok(X.HOME_CLEAR > Config.SANCTUARY.RADIUS + 100, "never in the sanctuary round home")
	end)

	t.test("the world batters, it does not wreck: hits are recoverable", function()
		t.ok(X.meteors.damage <= 15 and X.crossfire.damage <= 12 and X.thunder.damage <= 10, "small damage to goblins")
		t.ok(X.barrels.damage <= 12, "barrels too")
		t.ok(
			X.meteors.warn >= 2 and X.crossfire.warn >= 1.2 and X.kraken.warn >= 1.2 and X.thunder.warn >= 1.5,
			"every big hit is telegraphed"
		)
		t.ok(X.whirls.flingRest >= 2, "a flung boat is left alone a moment")
	end)

	t.test("the chaos on the sea travels to the clients intact", function()
		local chaos = {
			waves = {
				{
					x = 100,
					z = -40,
					dx = 0.6,
					dz = 0.8,
					speed = 66,
					born = 1234.5,
					life = 22,
					height = 25,
					width = 35,
					half = 400,
				},
			},
			whirls = {
				{ x = -300, z = 900, vx = 8, vz = -4, born = 1240, life = 25, r = 90, spin = 50, pull = 20, dip = 10 },
			},
		}
		local back = Sea.decodeChaos(Sea.encodeChaos(chaos))
		t.eq(#back.waves, 1, "one wave")
		t.eq(#back.whirls, 1, "one whirlpool")
		t.ok(
			math.abs(back.waves[1].speed - 66) < 0.1 and math.abs(back.waves[1].born - 1234.5) < 0.01,
			"the wave's numbers"
		)
		t.ok(
			math.abs(back.whirls[1].r - 90) < 0.1 and math.abs(back.whirls[1].vx - 8) < 0.01,
			"the whirlpool's numbers"
		)
		t.eq(#Sea.decodeChaos("").waves, 0, "nothing")
		t.eq(#Sea.decodeChaos("junk;W,1,2").waves, 0, "junk is ignored")
	end)

	t.test("a rogue wave lifts the sea under its crest and carries what is on it, and dies away", function()
		local saved = Sea.chaos
		local savedShelter = Sea.shelterFn
		Sea.shelterFn = function()
			return 0 -- open sea
		end
		Sea.setChaos({
			waves = {
				{ x = 0, z = 0, dx = 1, dz = 0, speed = 60, born = 0, life = 20, height = 25, width = 35, half = 400 },
			},
			whirls = {},
		})
		local t0 = 5 -- the crest is at x = 300
		local crest = Sea.chaosAt(300, 0, t0)
		t.ok(math.abs(crest - 25) < 0.5, "the crest stands its height: " .. crest)
		t.ok(Sea.chaosAt(300 + 200, 0, t0) < 0.5, "flat well ahead of it")
		t.ok(Sea.chaosAt(300, 500, t0) < 0.5, "flat beyond its ends")
		local _, fx, fz = Sea.chaosAt(300, 0, t0)
		t.ok(fx > 30 and math.abs(fz) < 0.01, "it carries things the way it rolls")
		t.ok(Sea.chaosAt(300 + 60 * 25, 0, 25) < 0.5, "gone once its life is over")
		t.ok(Sea.waveAt(300, 0, t0) > 20, "and the sea a boat floats on includes it")
		Sea.shelterFn = function()
			return 1 -- right by a shore
		end
		t.ok(Sea.chaosAt(300, 0, t0) < 3, "right beside land it breaks to a ripple")
		Sea.shelterFn = function()
			return 0.5 -- a sheltered channel
		end
		local channel = Sea.chaosAt(300, 0, t0)
		t.ok(channel > 8 and channel < 16, "in a sheltered channel it is still a wave: " .. channel)
		Sea.shelterFn = savedShelter
		Sea.setChaos(saved)
	end)

	t.test("a whirlpool swirls round and in, and dips in the middle", function()
		local saved = Sea.chaos
		Sea.setChaos({
			waves = {},
			whirls = { { x = 0, z = 0, vx = 0, vz = 0, born = 0, life = 30, r = 100, spin = 50, pull = 20, dip = 10 } },
		})
		local _, fx, fz = Sea.chaosAt(50, 0, 10)
		t.ok(fz > 20, "round (anticlockwise)")
		t.ok(fx < -5, "and in")
		local eye = Sea.chaosAt(2, 0, 10)
		t.ok(eye < -5, "the eye is a funnel: " .. eye)
		t.ok(select(2, Sea.chaosAt(150, 0, 10)) == 0, "nothing outside it")
		Sea.setChaos(saved)
	end)
end

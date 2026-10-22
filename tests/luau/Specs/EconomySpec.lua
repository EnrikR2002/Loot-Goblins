-- The rules of owning things: buying, wearing, presets, payouts, stats and achievements (server/Economy.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Server = ServerScriptService:WaitForChild("LootGoblinsServer")
local Economy = require(Server.Economy)
local ProfileSchema = require(Server.ProfileSchema)

local P = Config.PROGRESS

local function fresh(shinies)
	local profile = ProfileSchema.new(0)
	profile.shinies = shinies or 0
	return profile
end

return function(t)
	t.test("buying with enough Shinies takes the price once and owns the item", function()
		local profile = fresh(100)
		local result = Economy.buy(profile, "hat_tricorn", 1)
		t.ok(result.ok, result.code)
		t.eq(profile.shinies, 55, "balance")
		t.ok(profile.owned.hat_tricorn, "owned")
		t.eq(#profile.history, 1, "logged")
		local again = Economy.buy(profile, "hat_tricorn", 2)
		t.eq(again.code, "owned", "second purchase refused")
		t.eq(profile.shinies, 55, "not charged twice")
	end)

	t.test("buying without enough Shinies changes nothing and says how many more", function()
		local profile = fresh(10)
		local result = Economy.buy(profile, "hat_captain", 1)
		t.eq(result.code, "funds", "code")
		t.eq(result.short, 270, "short by")
		t.eq(profile.shinies, 10, "balance untouched")
		t.ok(not profile.owned.hat_captain, "not owned")
	end)

	t.test("rapid repeated purchases charge once", function()
		local profile = fresh(1000)
		local ok = 0
		for _ = 1, 10 do
			if Economy.buy(profile, "outfit_captain", 1).ok then
				ok += 1
			end
		end
		t.eq(ok, 1, "one success")
		t.eq(profile.shinies, 1000 - Catalog.get("outfit_captain").price, "charged once")
	end)

	t.test("trophies, Robux items, free items and unknown ids cannot be bought", function()
		local profile = fresh(10000)
		t.eq(Economy.buy(profile, "hat_idol").code, "locked", "trophy")
		t.eq(Economy.buy(profile, "livery_starlit").code, "premium", "premium-only")
		t.eq(Economy.buy(profile, "hat_bandana").code, "owned", "free items are already owned")
		t.eq(Economy.buy(profile, "no_such_thing").code, "unknown", "unknown")
		t.eq(Economy.buy(profile, nil).code, "unknown", "nil")
		t.eq(profile.shinies, 10000, "nothing charged")
	end)

	t.test("a pet look needs its pet", function()
		local profile = fresh(1000)
		t.eq(Economy.buy(profile, "petskin_crab_hermit").code, "needpet", "without the crab")
		t.ok(Economy.buy(profile, "Crab").ok, "buy the crab")
		t.ok(Economy.buy(profile, "petskin_crab_hermit").ok, "now the look")
	end)

	t.test("wearing needs ownership and the right slot; taking off returns to the default", function()
		local profile = fresh(1000)
		t.eq(Economy.equip(profile, "hat", "hat_crown").code, "notowned", "not owned")
		t.eq(Economy.equip(profile, "eyes", "hat_bandana").code, "wrongslot", "wrong slot")
		t.eq(Economy.equip(profile, "nonsense", "hat_bandana").code, "wrongslot", "unknown slot")
		t.eq(Economy.equip(profile, "emote", "emote_wave").code, "wrongslot", "emotes are not worn")
		t.ok(Economy.equip(profile, "hat", "hat_bandana").ok, "free item")
		t.eq(Economy.look(profile).hat, "hat_bandana", "worn")
		t.ok(Economy.buy(profile, "skin_hob").ok, "buy skin")
		t.ok(Economy.equip(profile, "skin", "skin_hob").ok, "wear skin")
		t.eq(Economy.look(profile).skin, "skin_hob", "skin worn")
		t.ok(Economy.equip(profile, "skin", nil).ok, "take off")
		t.eq(Economy.look(profile).skin, "skin_classic", "back to the default")
		t.ok(Economy.equip(profile, "hat", nil).ok, "hat off")
		t.eq(Economy.look(profile).hat, nil, "optional slot empty")
	end)

	t.test("the look drops anything not owned, whatever the saved data says", function()
		local profile = fresh(0)
		profile.equipped = { hat = "hat_crown", outfit = "outfit_admiral", pet = "Ghost", ears = "ears_bat" }
		profile.petSkins = { Ghost = "petskin_ghost_pumpkin" }
		local look = Economy.look(profile)
		t.eq(look.hat, nil, "hat")
		t.eq(look.outfit, nil, "outfit")
		t.eq(look.pet, nil, "pet")
		t.eq(look.petskin, nil, "pet look")
		t.eq(look.ears, "ears_long", "default ears")
		t.ok(Economy.tidy(profile), "tidy reports a change")
		t.eq(next(profile.equipped), nil, "equipped emptied")
	end)

	t.test("a pet look is worn by its own pet only", function()
		local profile = fresh(1000)
		Economy.buy(profile, "Crab")
		Economy.buy(profile, "petskin_crab_hermit")
		Economy.equip(profile, "pet", "Crab")
		t.ok(Economy.equip(profile, "petskin", "petskin_crab_hermit").ok, "wear on crab")
		t.eq(Economy.look(profile).petskin, "petskin_crab_hermit", "shown")
		Economy.buy(profile, "Frog")
		Economy.equip(profile, "pet", "Frog")
		t.eq(Economy.look(profile).petskin, nil, "not on the frog")
		Economy.equip(profile, "pet", "Crab")
		t.eq(Economy.look(profile).petskin, "petskin_crab_hermit", "back on the crab")
	end)

	t.test("presets save what is worn and never put on what is not owned", function()
		local profile = fresh(1000)
		Economy.buy(profile, "hat_tricorn")
		Economy.equip(profile, "hat", "hat_tricorn")
		Economy.buy(profile, "eyes_patch")
		Economy.equip(profile, "eyes", "eyes_patch")
		t.ok(Economy.savePreset(profile, 1, "Pirate", P.PRESETS).ok, "save")
		Economy.equip(profile, "hat", nil)
		Economy.equip(profile, "eyes", nil)
		local loaded = Economy.loadPreset(profile, 1)
		t.ok(loaded.ok, "load")
		t.eq(Economy.look(profile).hat, "hat_tricorn", "hat back")
		t.eq(Economy.look(profile).eyes, "eyes_patch", "eyes back")
		-- A hand-edited preset with a crown nobody bought.
		profile.presets[2] = { name = "Cheat", look = { hat = "hat_crown", eyes = "eyes_patch" } }
		local cheat = Economy.loadPreset(profile, 2)
		t.ok(cheat.ok, "loads")
		t.eq(#cheat.skipped, 1, "the crown is skipped")
		t.eq(Economy.look(profile).hat, nil, "no crown")
		t.eq(Economy.loadPreset(profile, 3).code, "preset", "empty preset")
		t.eq(Economy.savePreset(profile, 9, "x", P.PRESETS).code, "preset", "out of range")
		t.eq(Economy.savePreset(profile, 1.5, "x", P.PRESETS).code, "preset", "not whole")
	end)

	t.test("raid payouts follow the formula and the cap", function()
		-- Took part, banked nothing.
		local nothing = Economy.payout(0, false, 0, P)
		t.eq(nothing.total, P.PARTICIPATION, "participation only")
		-- Banked one treasure (7 gold), below the middle.
		local one = Economy.payout(7, false, 10, P)
		t.eq(one.total, P.PARTICIPATION + 7 + P.UNDERDOG, "one treasure")
		-- Several treasures (30 gold): the gold part is capped.
		local several = Economy.payout(30, false, 10, P)
		t.eq(several.gold, P.GOLD_CAP, "gold capped")
		-- The winner.
		local win = Economy.payout(28, true, 10, P)
		t.eq(win.win, P.WIN, "win bonus")
		t.eq(win.underdog, 0, "a winner is not an underdog")
		t.ok(win.total <= P.RAID_CAP, "raid cap")
		t.eq(win.total, math.min(P.PARTICIPATION + P.GOLD_CAP + P.WIN, P.RAID_CAP), "winner total")
	end)

	t.test("V13: deeds pay once a raid each, tricks up to their limit, and the raid cap still holds", function()
		local D = P.DEEDS
		local all = { steal = true, escape = true, snatch = true, tricks = 99 }
		local deeds = Economy.payout(0, false, 0, P, all)
		t.eq(deeds.deeds, D.steal + D.escape + D.snatch + D.tricksMax * D.trick, "every deed, tricks capped")
		t.eq(deeds.total, P.PARTICIPATION + deeds.deeds, "participation plus deeds")
		t.eq(Economy.payout(0, false, 0, P, {}).deeds, 0, "no deeds, nothing extra")
		t.eq(Economy.payout(0, false, 0, P, nil).total, P.PARTICIPATION, "deeds are optional")
		local best = Economy.payout(100, true, 10, P, all)
		t.eq(best.total, P.RAID_CAP, "a perfect raid is capped")
		t.ok(best.capped > 0, "the cap is reported")
	end)

	t.test("V13: the economy model: a typical goblin earns a boat in a few hours, and nothing takes weeks", function()
		-- The model in docs/economy (and Config.PROGRESS): about 8 raids an hour (60 s Port + 20 s launch + 360 s raid).
		local raidsPerHour = 3600 / (Config.PORT.DURATION + Config.SKYSHIP.WINDOW + Config.RAID_DURATION)
		t.ok(raidsPerHour > 7 and raidsPerHour < 9, "about eight raids an hour: " .. raidsPerHour)
		-- A typical raid: banks one middling treasure (10 gold), one steal, one clean trick; below the median.
		local typical = Economy.payout(10, false, 12, P, { steal = true, tricks = 1 }).total
		local perHour = typical * raidsPerHour
		t.ok(perHour >= 120 and perHour <= 260, "a typical goblin's Shinies an hour: " .. perHour)
		local fleet, dearest = 0, 0
		for _, item in ipairs(Catalog.bySlot.boat) do
			if item.price then
				fleet += item.price
				dearest = math.max(dearest, item.price)
			end
		end
		t.ok(dearest / perHour <= 6, "the dearest boat in at most six hours of typical play")
		t.ok(fleet / perHour <= 20, "every boat in at most twenty hours of typical play")
		for _, item in ipairs(Catalog.bySlot.pet) do
			if item.price then
				t.ok(item.price / perHour <= 5, item.id .. ": a pet in at most five hours")
			end
		end
	end)

	t.test("V13: boats are bought and sailed like any item; the Skiff is everyone's", function()
		local profile = fresh(400)
		t.eq(Economy.look(profile).boat, "boat_skiff", "the default boat")
		t.ok(Economy.equip(profile, "boat", "boat_cutter").ok, "the Cutter is free")
		t.eq(Economy.equip(profile, "boat", "boat_wraith").code, "notowned", "not owned")
		t.ok(Economy.buy(profile, "boat_reefhopper", 1).ok, "buy the Reefhopper")
		t.eq(profile.shinies, 400 - Catalog.get("boat_reefhopper").price, "charged")
		t.ok(Economy.equip(profile, "boat", "boat_reefhopper").ok, "sail it")
		t.eq(Economy.look(profile).boat, "boat_reefhopper", "chosen")
		t.eq(Economy.equip(profile, "boat", "hat_tricorn").code, "wrongslot", "a hat is not a boat")
	end)

	t.test("V13: escapes unlock their island's pet, and four classes of boat make an admiral", function()
		local profile = fresh(0)
		Economy.record(profile, "escape", "Bone")
		Economy.checkAchievements(profile, 1)
		t.ok(profile.owned.Levi, "the Little Leviathan for outrunning the Leviathan")
		t.ok(profile.achievements.leviathan_friend, "achievement")
		for _, entry in ipairs({
			{ "Temple", "Sunny" },
			{ "Crystal", "Echo" },
			{ "Windmill", "Lamb" },
			{ "Skull", "Bones" },
			{ "Tide", "Zap" },
			{ "Cross", "Peek" },
		}) do
			Economy.record(profile, "escape", entry[1])
			Economy.checkAchievements(profile, 2)
			t.ok(profile.owned[entry[2]], entry[2] .. " for escaping from " .. entry[1])
		end
		t.eq(Economy.statValue(profile, "escapes"), 7, "escapes counted")
		for _, class in ipairs({ "skiff", "cutter", "wraith" }) do
			Economy.record(profile, "bank", "Idol", 5, class)
		end
		Economy.checkAchievements(profile, 3)
		t.eq(profile.achievements.fleet_admiral, nil, "three classes is not four")
		Economy.record(profile, "bank", "Idol", 5, "ironbelly")
		Economy.checkAchievements(profile, 4)
		t.ok(profile.achievements.fleet_admiral, "four classes")
	end)

	t.test("stats and achievements unlock once, pay once and grant their trophy", function()
		local profile = fresh(0)
		Economy.record(profile, "bank", "Idol", 17)
		local unlocked = Economy.checkAchievements(profile, 5)
		local names = {}
		for _, entry in ipairs(unlocked) do
			names[entry.achievement.id] = true
		end
		t.ok(names.first_haul and names.idol_thief, "first haul and idol thief")
		t.ok(profile.owned.hat_idol, "idol crown granted")
		local paid = profile.shinies
		t.eq(paid, 25 + 50, "paid")
		t.eq(#Economy.checkAchievements(profile, 6), 0, "not twice")
		t.eq(profile.shinies, paid, "paid once")
		for _, id in ipairs({ "Pearl", "Gear", "Lens", "Heart", "Frog", "Vault", "Crown" }) do
			Economy.record(profile, "bank", id, 10)
		end
		local more = Economy.checkAchievements(profile, 7)
		t.eq(#more, 1, "island hopper at eight treasures")
		t.ok(profile.owned.flag_map, "chart flag")
		Economy.record(profile, "combo", 3)
		t.eq(#Economy.checkAchievements(profile, 8), 0, "three tricks is not four")
		Economy.record(profile, "combo", 4)
		t.ok(profile.owned.trickfx_comet == nil, "not before checking")
		Economy.checkAchievements(profile, 9)
		t.ok(profile.owned.trickfx_comet, "comet tail")
	end)

	t.test("earnings made while the profile was busy move across exactly once", function()
		local standIn = fresh(0)
		Economy.addShinies(standIn, 30)
		Economy.record(standIn, "raid", true)
		Economy.record(standIn, "bank", "Chalice", 11)
		local real = fresh(200)
		real.stats.raids = 4
		Economy.mergeEarnings(real, standIn)
		t.eq(real.shinies, 230, "shinies")
		t.eq(real.stats.raids, 5, "raids")
		t.eq(real.stats.wins, 1, "wins")
		t.eq(real.stats.bankedFrom.Chalice, 1, "banked")
	end)

	t.test("the welcome is given once", function()
		local profile = fresh(0)
		t.eq(Economy.welcome(profile, 60), 60, "first")
		t.eq(Economy.welcome(profile, 60), 0, "second")
		t.eq(profile.shinies, 60, "balance")
	end)

	t.test("grants do not duplicate", function()
		local profile = fresh(0)
		t.eq(#Economy.grant(profile, { "livery_starlit" }, "robux"), 1, "first")
		t.eq(#Economy.grant(profile, { "livery_starlit" }, "robux"), 0, "second")
		t.eq(#Economy.grant(profile, { "nonsense" }, "robux"), 0, "unknown")
	end)
end

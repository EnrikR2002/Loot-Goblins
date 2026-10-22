-- V13.3: the Port's calendar, the Captain's quests and the leaderboards' season rewards (shared/Seasons.lua), on plain
-- profile tables with a made-up clock: every reset, rollover and payout, without waiting a week.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Seasons = require(Shared.Seasons)
local ProfileSchema = require(ServerScriptService:WaitForChild("LootGoblinsServer").ProfileSchema)

local DAY = 86400
-- 2026-10-21 12:00 UTC, a Wednesday (days since 1970-01-01: 20747).
local WED = 20747 * DAY + 12 * 3600

local function fresh()
	return ProfileSchema.load(nil, nil, 0)
end

local function never()
	return false
end

return function(t)
	t.test("the calendar: days, Monday weeks and months in UTC, with leap years", function()
		t.eq(Seasons.period("day", WED), 20747, "day number")
		local y, m, d = Seasons.civil(20747)
		t.eq(y * 10000 + m * 100 + d, 20261021, "2026-10-21")
		t.eq(Seasons.daysFrom(2028, 2, 29) + 1, Seasons.daysFrom(2028, 3, 1), "2028 has a 29 February")
		t.eq(Seasons.daysFrom(2027, 2, 28) + 1, Seasons.daysFrom(2027, 3, 1), "2027 does not")
		local y2, m2, d2 = Seasons.civil(Seasons.daysFrom(2000, 2, 29))
		t.eq(y2 * 10000 + m2 * 100 + d2, 20000229, "round trip through a leap day")
		-- The week starts on Monday 2026-10-19 00:00 and ends the next Monday.
		local w = Seasons.period("week", WED)
		local start, finish = Seasons.bounds("week", w)
		t.eq(start, Seasons.daysFrom(2026, 10, 19) * DAY, "week starts Monday 00:00")
		t.eq(finish - start, 7 * DAY, "a week long")
		t.eq(Seasons.period("week", finish - 1), w, "Sunday 23:59:59 is the same week")
		t.eq(Seasons.period("week", finish), w + 1, "Monday 00:00 is the next")
		-- October 2026 runs from the 1st to the 1st of November.
		local month = Seasons.period("month", WED)
		t.eq(Seasons.key("month", month), "m2026-10", "month key")
		local ms, mf = Seasons.bounds("month", month)
		t.eq(ms, Seasons.daysFrom(2026, 10, 1) * DAY, "month start")
		t.eq(mf, Seasons.daysFrom(2026, 11, 1) * DAY, "month end")
		t.eq(
			Seasons.key("month", Seasons.period("month", Seasons.daysFrom(2026, 12, 31) * DAY)),
			"m2026-12",
			"December"
		)
		t.eq(Seasons.key("month", Seasons.period("month", Seasons.daysFrom(2027, 1, 1) * DAY)), "m2027-01", "January")
		for _, kind in ipairs({ "day", "week", "month" }) do
			local index = Seasons.period(kind, WED)
			local k2, i2 = Seasons.parse(Seasons.key(kind, index))
			t.eq(k2, kind, "parse kind " .. kind)
			t.eq(i2, index, "parse index " .. kind)
		end
		t.eq(Seasons.parse("nonsense"), nil, "nonsense")
		t.eq(Seasons.secondsLeft("day", WED), 12 * 3600, "half a day left")
	end)

	t.test(
		"three daily and three weekly quests, one per slot, the same for everyone, never repeated next day",
		function()
			for day = 20000, 20060 do
				local today, yesterday = Seasons.questsFor("day", day), Seasons.questsFor("day", day - 1)
				t.eq(#today, Config.QUESTS.DAILY, "three a day")
				for slot = 1, 3 do
					t.eq(today[slot].slot, slot, "slot order")
					t.ok(today[slot].id ~= yesterday[slot].id, "not the same quest two days running")
				end
				t.eq(Seasons.questsFor("day", day)[2].id, today[2].id, "deterministic")
			end
			local weekly = Seasons.questsFor("week", 2911)
			t.eq(#weekly, Config.QUESTS.WEEKLY, "three a week")
			-- Every quest's event is one the server reports, and every Port quest names its game.
			local EVENTS = {
				bankraid = true,
				steal = true,
				raid = true,
				gold = true,
				escape = true,
				escapefrom = true,
				podium = true,
				tricks = true,
				chaos = true,
				game_any = true,
				game_distinct = true,
				bankclass = true,
				challenge = true,
				snatch = true,
				golf_green = true,
				toss_points = true,
				crabs = true,
				gallery_hits = true,
				best = true,
				medal_gold = true,
				expedition = true,
			}
			for _, list in pairs(Seasons.QUESTS) do
				for _, def in ipairs(list) do
					local known = EVENTS[def.event] or string.sub(def.event, 1, 5) == "game_"
					t.ok(known, def.id .. ": unknown event " .. def.event)
					t.ok(Seasons.questReward(def) > 0, def.id .. ": no reward")
					t.ok(def.goal >= 1, def.id .. ": goal")
				end
			end
		end
	)

	t.test("quest progress, claiming once, and a finished quest paid at the reset if never claimed", function()
		local profile = fresh()
		Seasons.ensureQuests(profile, WED, never)
		local first = profile.quests.daily[1]
		local def = Seasons.QUEST_BY_ID[first.id]
		t.eq(Seasons.claimQuest(profile, "day", 1, WED, never).code, "notdone", "not finished yet")
		local done = Seasons.recordQuest(profile, def.event, def.goal + 5, def.distinct and "a" or nil, WED, never)
		if def.distinct then
			for i = 1, def.goal do
				done = Seasons.recordQuest(profile, def.event, 1, "detail" .. i, WED, never)
			end
		end
		t.eq(profile.quests.daily[1].n, def.goal, "progress stops at the goal")
		local before = profile.shinies
		local claim = Seasons.claimQuest(profile, "day", 1, WED, never)
		t.ok(claim.ok, claim.code)
		t.eq(profile.shinies - before, Seasons.questReward(def), "paid")
		t.eq(Seasons.claimQuest(profile, "day", 1, WED, never).code, "already", "never twice")
		t.eq(profile.stats.questsDone, 1, "counted")
		-- Finish the second daily quest but never claim it: the next day pays it.
		local second = Seasons.QUEST_BY_ID[profile.quests.daily[2].id]
		for i = 1, second.goal do
			Seasons.recordQuest(profile, second.event, 1, "d" .. i, WED, never)
		end
		local mid = profile.shinies
		local rolled = Seasons.ensureQuests(profile, WED + DAY, never)
		t.eq(rolled.count, 1, "one quest paid at the reset")
		t.eq(profile.shinies - mid, Seasons.questReward(second), "paid what it was worth")
		t.eq(profile.quests.day, Seasons.period("day", WED + DAY), "a new day")
		t.eq(#profile.quests.daily, 3, "new quests")
		t.eq(profile.quests.daily[1].n, 0, "from scratch")
		local _ = done
	end)

	t.test("distinct quests count different things, not the same thing twice", function()
		local profile = fresh()
		profile.quests = {
			day = Seasons.period("day", WED),
			week = Seasons.period("week", WED),
			daily = {},
			weekly = { { id = "w_escape3", n = 0, claimed = false } },
		}
		Seasons.recordQuest(profile, "escapefrom", 1, "Bone", WED, never)
		Seasons.recordQuest(profile, "escapefrom", 1, "Bone", WED, never)
		t.eq(profile.quests.weekly[1].n, 1, "the same island twice is one")
		Seasons.recordQuest(profile, "escapefrom", 1, "Temple", WED, never)
		local done = Seasons.recordQuest(profile, "escapefrom", 1, "Skull", WED, never)
		t.eq(profile.quests.weekly[1].n, 3, "three islands")
		t.eq(#done, 1, "reported finished once")
		t.eq(#Seasons.recordQuest(profile, "escapefrom", 1, "Cross", WED, never), 0, "not again")
	end)

	t.test("claiming all three weekly quests gives the week's cosmetic, in turn, then Shinies", function()
		local profile = fresh()
		local owned = {}
		local function owns(id)
			return owned[id] == true
		end
		local week = Seasons.period("week", WED)
		Seasons.ensureQuests(profile, WED, owns)
		for i, entry in ipairs(profile.quests.weekly) do
			local def = Seasons.QUEST_BY_ID[entry.id]
			entry.n = def.goal
			local claim = Seasons.claimQuest(profile, "week", i, WED, owns)
			t.ok(claim.ok, "claim " .. i)
			if i < 3 then
				t.eq(claim.bundle, nil, "no bundle before the third")
			else
				t.ok(claim.bundle and claim.bundle.item, "the week's cosmetic")
				t.eq(claim.bundle.item, Seasons.BUNDLE[week % #Seasons.BUNDLE + 1], "this week's in the rotation")
				owned[claim.bundle.item] = true
			end
		end
		t.eq(profile.quests.bundle, week, "given for this week")
		-- Owning the whole rotation pays Shinies instead.
		for _, id in ipairs(Seasons.BUNDLE) do
			owned[id] = true
		end
		local nextWeek = WED + 7 * DAY
		Seasons.ensureQuests(profile, nextWeek, owns)
		for i, entry in ipairs(profile.quests.weekly) do
			entry.n = Seasons.QUEST_BY_ID[entry.id].goal
			local claim = Seasons.claimQuest(profile, "week", i, nextWeek, owns)
			if i == 3 then
				t.eq(claim.bundle.shinies, Config.QUESTS.BUNDLE_SHINIES, "Shinies when everything is owned")
			end
		end
		for _, id in ipairs(Seasons.BUNDLE) do
			local item = Catalog.get(id)
			t.ok(item and item.award == "weekly_bundle", id .. " is a weekly_bundle item")
		end
	end)

	t.test("leaderboards: only a better score counts, times keep hundredths, tiers anyone can reach", function()
		local profile = fresh()
		t.ok(Seasons.submit(profile, "haul", 12, WED), "first haul")
		t.ok(not Seasons.submit(profile, "haul", 9, WED), "a worse haul does not replace it")
		t.ok(Seasons.submit(profile, "haul", 19, WED), "a better one does")
		t.eq(Seasons.best(profile, "haul", WED), 19, "best haul")
		t.ok(Seasons.submit(profile, "regatta", 44.27, WED), "a lap")
		t.ok(not Seasons.submit(profile, "regatta", 50, WED), "slower does not count")
		t.ok(Seasons.submit(profile, "regatta", 39.5, WED), "faster does")
		t.eq(Seasons.best(profile, "regatta", WED), 39.5, "kept to the hundredth")
		t.ok(not Seasons.submit(profile, "nonsense", 5, WED), "unknown board")
		t.ok(not Seasons.submit(profile, "haul", 0 / 0, WED), "NaN")
		local haul = Seasons.BOARD_BY_ID.haul
		t.eq(Seasons.tier(haul, 9), nil, "no tier")
		t.eq(Seasons.tier(haul, 10), "bronze", "bronze")
		t.eq(Seasons.tier(haul, 32), "gold", "gold")
		local regatta = Seasons.BOARD_BY_ID.regatta
		t.eq(Seasons.tier(regatta, Config.PLAYGROUND.REGATTA.MEDALS.gold), "gold", "a gold-medal lap")
		t.eq(Seasons.tier(regatta, 999), nil, "too slow for a tier")
		t.eq(Seasons.encode(regatta, 39.5), 3950, "stored in hundredths")
		t.eq(Seasons.decode(regatta, 3950), 39.5, "and back")
	end)

	t.test("the Pirate Championship adds a goblin's best five raids of the month", function()
		local profile = fresh()
		local sums = {}
		for _, gold in ipairs({ 10, 4, 22, 8, 15, 3, 30 }) do
			table.insert(sums, Seasons.addRaid(profile, gold, WED) or false)
		end
		t.eq(sums[1], 10, "first raid")
		t.eq(sums[6], false, "a 3-gold raid does not raise the best five (10, 4, 22, 8, 15)")
		t.eq(sums[7], 30 + 22 + 15 + 10 + 8, "the best five")
		t.eq(Seasons.addRaid(profile, 0, WED), nil, "a raid with nothing banked")
		-- A new month starts again.
		local nextMonth = Seasons.daysFrom(2026, 11, 2) * DAY
		t.eq(Seasons.addRaid(profile, 5, nextMonth), 5, "new month")
	end)

	t.test("a finished period pays once: its tier by score, its placement by rank, cosmetics for the top", function()
		local profile = fresh()
		Seasons.submit(profile, "haul", 26, WED)
		Seasons.submit(profile, "regatta", 35, WED)
		t.eq(#Seasons.pending(profile, WED), 0, "nothing while the week runs")
		local after = WED + 8 * DAY
		local pending = Seasons.pending(profile, after)
		t.eq(#pending, 2, "both boards are due after the week")
		local before = profile.shinies
		local haulEntry
		for _, entry in ipairs(pending) do
			if entry.board == "haul" then
				haulEntry = entry
			end
		end
		local reward = Seasons.pay(profile, haulEntry, 7, after)
		t.eq(reward.tier, "silver", "26 gold is silver")
		local expect = Config.SEASONS.TIER.week.silver + Seasons.placement("week", 7).shinies
		t.eq(profile.shinies - before, expect, "tier and placement")
		t.ok(table.find(reward.items, "flag_leader") ~= nil, "a weekly top ten earns the Leaderboard Pennant")
		t.eq(Seasons.pay(profile, haulEntry, 7, after), nil, "never twice")
		t.eq(profile.shinies - before, expect, "still paid once")
		t.eq(#Seasons.pending(profile, after), 1, "only the regatta left")
		-- No standings (rank nil): the tier alone.
		local regattaEntry = Seasons.pending(profile, after)[1]
		local r2 = Seasons.pay(profile, regattaEntry, nil, after)
		t.eq(r2.tier, "gold", "a gold lap")
		t.ok(table.find(r2.items, "flag_burgee") ~= nil, "the gold tier's burgee")
		t.eq(#profile.season.trophies, 2, "two trophies for the sanctuary's case")
		-- First place takes the top prize too.
		local top = Seasons.rewardFor("champion", 140, 1)
		t.ok(
			table.find(top.items, "title_champion") and table.find(top.items, "livery_champion"),
			"champion's title and sails"
		)
		t.eq(Seasons.rewardFor("champion", 140, 150).shinies, Config.SEASONS.TIER.month.gold, "rank 150: only the tier")
	end)

	t.test("every season cosmetic has a way to be earned, and every way grants something real", function()
		local sources = Seasons.awardSources()
		for _, item in ipairs(Catalog.items) do
			if item.award then
				t.ok(sources[item.award], item.id .. ": no board or quest pays " .. item.award)
				t.eq(item.rarity, "season", item.id .. ": season items are rarity season")
			end
			if item.rarity == "season" then
				t.ok(item.award ~= nil, item.id .. ": a season item needs an award")
			end
		end
		for source in pairs(sources) do
			t.ok(#Seasons.itemsFor(source) > 0, source .. " grants nothing")
		end
	end)

	t.test("old season records are trimmed only after they are paid", function()
		local profile = fresh()
		Seasons.submit(profile, "haul", 20, WED)
		local later = WED + 20 * 7 * DAY
		Seasons.trim(profile, later)
		t.eq(#Seasons.pending(profile, later), 1, "an unpaid score is never forgotten")
		Seasons.pay(profile, Seasons.pending(profile, later)[1], nil, later)
		Seasons.trim(profile, later)
		local count = 0
		for _ in pairs(profile.season.best) do
			count += 1
		end
		t.eq(count, 0, "paid and old: trimmed")
		t.eq(#Seasons.pending(profile, later), 0, "and not paid again")
	end)
end

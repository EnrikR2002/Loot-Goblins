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
				golf_skips = true, -- V13.5
				regatta_class = true, -- V13.5
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
		t.ok(Seasons.submit(profile, "regatta2", 44.27, WED), "a lap")
		t.ok(not Seasons.submit(profile, "regatta2", 50, WED), "slower does not count")
		t.ok(Seasons.submit(profile, "regatta2", 39.5, WED), "faster does")
		t.eq(Seasons.best(profile, "regatta2", WED), 39.5, "kept to the hundredth")
		t.ok(not Seasons.submit(profile, "nonsense", 5, WED), "unknown board")
		t.ok(not Seasons.submit(profile, "regatta", 20, WED), "V13.5: a retired board takes no new score")
		t.ok(Seasons.submit(profile, "golf2", 15, WED), "a golf round in strokes")
		t.ok(Seasons.submit(profile, "golf2", 13, WED), "fewer strokes are better")
		t.ok(not Seasons.submit(profile, "golf2", 18, WED), "more are not")
		t.ok(not Seasons.submit(profile, "haul", 0 / 0, WED), "NaN")
		local haul = Seasons.BOARD_BY_ID.haul
		t.eq(Seasons.tier(haul, 9), nil, "no tier")
		t.eq(Seasons.tier(haul, 10), "bronze", "bronze")
		t.eq(Seasons.tier(haul, 32), "gold", "gold")
		local regatta = Seasons.BOARD_BY_ID.regatta2
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

	-- V13.4: the raid boards made central.
	t.test("the weekly Pirate Championship adds a goblin's best three raids of the week, beside the month's", function()
		local profile = fresh()
		profile.season.week = nil -- a V13.3 profile loaded before the repair knew the field
		local weeks = {}
		for _, gold in ipairs({ 10, 4, 22, 8, 15 }) do
			local month, week = Seasons.addRaid(profile, gold, WED)
			table.insert(weeks, week or false)
			t.ok(month ~= nil or gold <= 8, "the month's sum still moves: " .. gold)
		end
		t.eq(weeks[1], 10, "first raid")
		t.eq(weeks[3], 10 + 4 + 22, "three raids")
		t.eq(weeks[4], 10 + 22 + 8, "an 8 replaces the 4")
		t.eq(weeks[5], 22 + 15 + 10, "the best three only")
		local _, small = Seasons.addRaid(profile, 3, WED)
		t.eq(small, nil, "a raid outside the best three does not move it")
		local nextWeek = WED + 7 * DAY
		local _, fresh2 = Seasons.addRaid(profile, 6, nextWeek)
		t.eq(fresh2, 6, "a new week starts again")
		t.eq(#profile.season.raids.list, Config.SEASONS.CHAMPION_RAIDS, "the month keeps its own five")
	end)

	t.test("the raid boards come first, keep their ids, and pay their new prizes", function()
		local seenGame = false
		for _, board in ipairs(Seasons.BOARDS) do
			if not board.raid then
				seenGame = true
			end
			t.ok(not (board.raid and seenGame), board.id .. ": raid boards are listed before the Port's records")
			t.ok(board.icon ~= nil, board.id .. " has an icon")
		end
		for _, id in ipairs({ "haul", "crown", "champion", "regatta2", "golf2", "gauntlet" }) do
			t.ok(Seasons.BOARD_BY_ID[id] ~= nil and not Seasons.BOARD_BY_ID[id].retired, id .. " is a board")
		end
		-- V13.5: the old Regatta and golf boards are still known (so they pay) but stand nowhere.
		for _, id in ipairs({ "regatta", "golf" }) do
			t.ok(Seasons.BOARD_BY_ID[id] and Seasons.BOARD_BY_ID[id].retired, id .. " is retired, not forgotten")
			for _, board in ipairs(Seasons.BOARDS) do
				t.ok(board.id ~= id, id .. " is not shown")
			end
		end
		t.eq(Seasons.BOARD_BY_ID.golf2.order, "asc", "golf is fewest strokes")
		t.eq(Seasons.BOARD_BY_ID.champion.period, "month", "Pirate Legends keeps the monthly championship's id")
		t.eq(Seasons.BOARD_BY_ID.crown.period, "week", "the Pirate Championship is weekly")
		local top = Seasons.rewardFor("crown", 85, 1)
		for _, id in ipairs({ "title_weekcaptain", "flag_champion", "flag_leader", "pethat_doubloon" }) do
			t.ok(table.find(top.items, id) ~= nil, "the week's champion gets " .. id)
		end
		t.eq(top.tier, "gold", "85 over three raids is gold")
		local legend = Seasons.rewardFor("champion", 140, nil)
		t.ok(table.find(legend.items, "livery_legend") ~= nil, "a gold Pirate Legends tier earns the gilt sails")
		t.eq(#Seasons.rewardFor("crown", 30, nil).items, 0, "a bronze week: Shinies only")
	end)

	t.test("a new score's place among the board's last read counts each goblin once", function()
		local haul = Seasons.BOARD_BY_ID.haul
		local list = { { u = 1, s = 40 }, { u = 2, s = 30 }, { u = 3, s = 20 }, { u = 9, s = 10 } }
		t.eq(Seasons.rankAmong(haul, list, 9, 25), 3, "behind 40 and 30")
		t.eq(Seasons.rankAmong(haul, list, 9, 50), 1, "the top")
		t.eq(Seasons.rankAmong(haul, list, 2, 30), 2, "their own old row does not count against them")
		t.eq(Seasons.rankAmong(haul, list, 9, 30), 2, "a tie is shared, not lost")
		t.eq(Seasons.rankAmong(haul, {}, 9, 1), 1, "an empty board")
		local full = {}
		for i = 1, Config.SEASONS.HALL do
			table.insert(full, { u = 100 + i, s = 1000 - i })
		end
		t.eq(Seasons.rankAmong(haul, full, 9, 1), nil, "past the last place kept")
		local regatta = Seasons.BOARD_BY_ID.regatta2
		t.eq(Seasons.rankAmong(regatta, { { u = 1, s = 4000 } }, 9, 39.5), 1, "times: faster is better")
	end)

	t.test("a finished period pays once: its tier by score, its placement by rank, cosmetics for the top", function()
		local profile = fresh()
		Seasons.submit(profile, "haul", 26, WED)
		Seasons.submit(profile, "regatta2", Config.PLAYGROUND.REGATTA.MEDALS.gold - 1, WED)
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

	t.test("V13.5: a retired board still pays what was scored on it before it was retired", function()
		local profile = fresh()
		local week = Seasons.key("week", Seasons.period("week", WED))
		profile.season.best["regatta@" .. week] = 3500 -- a 35.00 s lap of the old course, this week
		profile.season.best["golf@" .. week] = 210 -- a 210-point round of the old golf
		local after = WED + 8 * DAY
		local pending = Seasons.pending(profile, after)
		t.eq(#pending, 2, "both old boards are paid after the week")
		local paid = 0
		for _, entry in ipairs(pending) do
			local reward = Seasons.pay(profile, entry, 1, after)
			t.eq(reward.tier, "gold", entry.board .. ": its old tiers")
			paid += reward.shinies
			if entry.board == "regatta" then
				t.ok(table.find(reward.items, "title_regatta") ~= nil, "the old board's #1 still takes the Regatta Ace")
			end
		end
		t.ok(paid > 0, "Shinies paid")
		t.eq(#Seasons.pending(profile, after), 0, "once")
	end)

	t.test(
		"V13.5: a saved quest for a removed game is replaced; a finished one is paid first; a claimed one stays",
		function()
			local profile = fresh()
			Seasons.ensureQuests(profile, WED, never)
			local q = profile.quests
			local keep1, keep3 = q.daily[1].id, q.daily[3].id
			q.daily[1].n = 1 -- progress on a quest that still exists is untouched
			q.daily[2] = { id = "d_toss", n = 30, claimed = false } -- finished (30 of 30), never claimed
			local before = profile.shinies
			local rolled = Seasons.ensureQuests(profile, WED, never)
			t.eq(profile.shinies - before, Config.QUESTS.REWARD.easy, "the finished Toss quest is paid")
			t.eq(rolled.count, 1, "and reported like a rollover")
			t.ok(Seasons.QUEST_BY_ID[q.daily[2].id] ~= nil, "the Port slot now has a real quest")
			t.eq(q.daily[2].n, 0, "a fresh one")
			t.eq(q.daily[1].id, keep1, "the others are left")
			t.eq(q.daily[1].n, 1, "with their progress")
			t.eq(q.daily[3].id, keep3, "all of them")
			t.eq(#Seasons.questView(profile, WED).day, 3, "the board shows three again")
			-- Unfinished: replaced, nothing paid. Claimed: left alone (it was paid).
			q.daily[2] = { id = "d_crabs", n = 2, claimed = false }
			local mid = profile.shinies
			Seasons.ensureQuests(profile, WED, never)
			t.eq(profile.shinies, mid, "an unfinished one pays nothing")
			t.ok(Seasons.QUEST_BY_ID[q.daily[2].id] ~= nil, "and is replaced")
			q.daily[2] = { id = "d_gallery", n = 10, claimed = true }
			Seasons.ensureQuests(profile, WED, never)
			t.eq(q.daily[2].id, "d_gallery", "a claimed one stays as it was")
			t.eq(profile.shinies, mid, "and is never paid twice")
			-- The weekly "every Port game" quest now asks for the three there are.
			t.eq(Seasons.QUEST_BY_ID.w_variety.goal, 3, "all three")
		end
	)

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

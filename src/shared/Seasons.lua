-- The Port's calendar and what it pays (V13.3, The Living Port), as pure functions over a saved profile table: the
-- daily and weekly QUESTS of the Captain's Quest Board, and the weekly and monthly LEADERBOARDS' tiers, placements and
-- season rewards. No DataStore, no players, no clock of its own (every function is given `unix`, the server's time),
-- so the tests can run a whole month in a moment. server/Quests.lua and server/Leaderboards.lua do the talking.
--
-- THE CALENDAR is UTC. A day starts at 00:00, a week on Monday 00:00 (1970-01-05 was a Monday), a month on the 1st.
-- Periods are numbered (Seasons.period) and named by key ("d20383", "w2911", "m2026-10"); a goblin's saved scores and
-- the leaderboards' DataStores use the keys.
--
-- QUESTS are the same for everyone on the day or the week (chosen from the pools below by the period's number), so
-- goblins can do them together. Three a day (one raid quest, one Port game, one of everything else) and three a week.
-- Progress comes only from the server's own events (Seasons.recordQuest). A finished quest is claimed at the board;
-- one nobody claimed is paid when the period rolls over (Seasons.ensureQuests), never lost. Claiming all three weekly
-- quests also gives the week's cosmetic (BUNDLE, in turn), or Shinies if it is already owned. No streaks, nothing to
-- log in for, nothing bought.
--
-- LEADERBOARDS: every score is the server's measurement (a raid's banked gold, a lap the server timed). A goblin's own
-- best for each board and period is kept in their profile (season.best). When a period is over, each goblin is paid
-- once for it, in their own profile, the next time they are in any server: a TIER by their own score (anyone can reach
-- one) and a PLACEMENT by their rank in the final standings (server/Leaderboards.lua writes those once per period).
-- The paid marker (season.paid) is saved in the same profile write as the Shinies, so a reward can never be paid twice.
local Config = require(script.Parent:WaitForChild("Config"))
local Catalog = require(script.Parent:WaitForChild("Catalog"))

local Seasons = {}

local DAY, WEEK = 86400, 604800
local MONDAY0 = 4 * DAY -- 1970-01-05 00:00 UTC, a Monday
Seasons.DAY, Seasons.WEEK = DAY, WEEK

-- The calendar ---------------------------------------------------------------------------------------------------------
-- Days since 1970-01-01 -> year, month (1-12), day (1-31), proleptic Gregorian (Howard Hinnant's algorithm), so no
-- os.date or os.time with a local time zone is ever involved.
local function civil(days)
	local z = days + 719468
	local era = (z >= 0 and z or z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = mp < 10 and mp + 3 or mp - 9
	if m <= 2 then
		y += 1
	end
	return y, m, d
end

local function daysFrom(y, m, d)
	if m <= 2 then
		y -= 1
	end
	local era = (y >= 0 and y or y - 399) // 400
	local yoe = y - era * 400
	local mm = m > 2 and m - 3 or m + 9
	local doy = (153 * mm + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end
Seasons.civil, Seasons.daysFrom = civil, daysFrom

-- The number of the day, week or month `unix` is in.
function Seasons.period(kind, unix)
	unix = math.floor(unix or 0)
	if kind == "day" then
		return unix // DAY
	elseif kind == "week" then
		return (unix - MONDAY0) // WEEK
	end
	local y, m = civil(unix // DAY)
	return y * 12 + (m - 1)
end

-- When period `index` of `kind` starts and ends (unix seconds; the end is the next one's start).
function Seasons.bounds(kind, index)
	if kind == "day" then
		return index * DAY, (index + 1) * DAY
	elseif kind == "week" then
		return MONDAY0 + index * WEEK, MONDAY0 + (index + 1) * WEEK
	end
	local y, m = index // 12, index % 12 + 1
	local ny, nm = (index + 1) // 12, (index + 1) % 12 + 1
	return daysFrom(y, m, 1) * DAY, daysFrom(ny, nm, 1) * DAY
end

function Seasons.key(kind, index)
	if kind == "day" then
		return "d" .. index
	elseif kind == "week" then
		return "w" .. index
	end
	return string.format("m%04d-%02d", index // 12, index % 12 + 1)
end

-- Back from a key to its kind and index (nil for anything else).
function Seasons.parse(key)
	if type(key) ~= "string" then
		return nil
	end
	local d = string.match(key, "^d(%-?%d+)$")
	if d then
		return "day", tonumber(d)
	end
	local w = string.match(key, "^w(%-?%d+)$")
	if w then
		return "week", tonumber(w)
	end
	local y, m = string.match(key, "^m(%d%d%d%d)%-(%d%d)$")
	if y then
		return "month", tonumber(y) * 12 + tonumber(m) - 1
	end
	return nil
end

-- Seconds until the period `unix` is in ends.
function Seasons.secondsLeft(kind, unix)
	local _, finish = Seasons.bounds(kind, Seasons.period(kind, unix))
	return math.max(0, finish - unix)
end

-- A small, stable integer hash (the quest pick must be the same on every server, forever). Multiplication is done in
-- 16-bit halves so every intermediate stays an exact whole number (a double holds 53 bits; a 32 x 32 product does not).
local TWO32 = 4294967296
local function mul32(a, b)
	local ah, al = a // 65536, a % 65536
	local bh, bl = b // 65536, b % 65536
	return ((ah * bl + al * bh) % 65536 * 65536 + al * bl) % TWO32
end
local function mix(a, b)
	local h = bit32.bxor(mul32(a % TWO32, 2654435761), mul32(b % TWO32, 40503))
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = mul32(h, 2246822519)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	return h
end
Seasons.mix = mix

-- Quests --------------------------------------------------------------------------------------------------------------
-- A quest: id (stable: saved in profiles), slot (1 raids, 2 Port games, 3 everything else), tier (its reward:
-- Config.QUESTS), event (what counts: server/Quests.lua is told), goal, text, and optionally `distinct` (count different
-- details, not repeats: different islands, games, boats) and `go` (the Port game it suggests).
Seasons.QUESTS = {
	day = {
		{ id = "d_bank2", slot = 1, tier = "easy", event = "bankraid", goal = 2, text = "Bank treasure in 2 raids" },
		{
			id = "d_steal2",
			slot = 1,
			tier = "easy",
			event = "steal",
			goal = 2,
			text = "Steal 2 treasures from their islands",
		},
		{ id = "d_raids3", slot = 1, tier = "easy", event = "raid", goal = 3, text = "Play 3 raids to the end" },
		{ id = "d_gold15", slot = 1, tier = "medium", event = "gold", goal = 15, text = "Bank 15 gold" },
		{
			id = "d_escape1",
			slot = 1,
			tier = "medium",
			event = "escape",
			goal = 1,
			text = "Escape a pursuer to Goblin Cove",
		},
		{
			id = "d_regatta",
			slot = 2,
			tier = "easy",
			event = "game_regatta",
			goal = 1,
			text = "Finish a Tiny Boat Regatta",
			go = "regatta",
		},
		{
			id = "d_gauntlet",
			slot = 2,
			tier = "medium",
			event = "game_gauntlet",
			goal = 1,
			text = "Finish a Grapple Gauntlet run",
			go = "gauntlet",
		},
		{
			id = "d_golf",
			slot = 2,
			tier = "medium",
			event = "golf_green",
			goal = 3,
			text = "Land on 3 greens in Cannon Golf",
			go = "golf",
		},
		-- V13.5: the Pet Derby, Treasure Toss, Gallery and Crab Chaos quests went with their games (a goblin holding
		-- one is dealt today's quest in its place: Seasons.ensureQuests). Two new ones show off what the games became.
		{
			id = "d_testdrive",
			slot = 2,
			tier = "easy",
			event = "regatta_class",
			goal = 2,
			distinct = true,
			text = "Race the Regatta in 2 different boats",
			go = "regatta",
		},
		{
			id = "d_skip3",
			slot = 2,
			tier = "medium",
			event = "golf_skips",
			goal = 1,
			text = "Skip 3 times off the sea in one Cannon Golf shot",
			go = "golf",
		},
		{ id = "d_tricks3", slot = 3, tier = "medium", event = "tricks", goal = 3, text = "Land 3 clean boat tricks" },
		{
			id = "d_chaos2",
			slot = 3,
			tier = "medium",
			event = "chaos",
			goal = 2,
			text = "Get thrown about by world chaos twice",
		},
		{ id = "d_games3", slot = 3, tier = "easy", event = "game_any", goal = 3, text = "Play 3 Port games" },
		{
			id = "d_classes2",
			slot = 3,
			tier = "hard",
			event = "bankclass",
			goal = 2,
			distinct = true,
			text = "Bank treasure from 2 different boats",
		},
		{
			id = "d_challenge",
			slot = 3,
			tier = "medium",
			event = "challenge",
			goal = 1,
			text = "Play a challenge against another goblin",
		},
		{
			id = "d_snatch",
			slot = 3,
			tier = "hard",
			event = "snatch",
			goal = 1,
			text = "Snatch treasure from a goblin you knocked down",
		},
	},
	week = {
		{ id = "w_bank8", slot = 1, tier = "medium", event = "bankraid", goal = 8, text = "Bank treasure in 8 raids" },
		{ id = "w_gold100", slot = 1, tier = "hard", event = "gold", goal = 100, text = "Bank 100 gold" },
		{
			id = "w_escape3",
			slot = 1,
			tier = "hard",
			event = "escapefrom",
			goal = 3,
			distinct = true,
			text = "Escape 3 different island guardians",
		},
		{
			id = "w_podium3",
			slot = 1,
			tier = "medium",
			event = "podium",
			goal = 3,
			text = "Finish 3 raids in the top 3",
		},
		{
			id = "w_variety",
			slot = 2,
			tier = "hard",
			event = "game_distinct",
			goal = 3, -- V13.5: all three (it was 5 of the seven)
			distinct = true,
			text = "Finish all 3 Port games",
		},
		{ id = "w_regatta5", slot = 2, tier = "medium", event = "game_regatta", goal = 5, text = "Finish 5 Regattas" },
		{
			id = "w_fleet4",
			slot = 2,
			tier = "medium",
			event = "regatta_class",
			goal = 4,
			distinct = true,
			text = "Race the Regatta in 4 different boats",
		},
		{
			id = "w_best2",
			slot = 2,
			tier = "medium",
			event = "best",
			goal = 2,
			text = "Beat a personal best in a Port game twice",
		},
		{
			id = "w_gold3",
			slot = 2,
			tier = "medium",
			event = "medal_gold",
			goal = 3,
			text = "Win 3 gold medals in Port games",
		},
		{
			id = "w_tricks15",
			slot = 3,
			tier = "medium",
			event = "tricks",
			goal = 15,
			text = "Land 15 clean boat tricks",
		},
		{
			id = "w_classes3",
			slot = 3,
			tier = "hard",
			event = "bankclass",
			goal = 3,
			distinct = true,
			text = "Bank treasure from 3 different boats",
		},
		{
			id = "w_voyages3",
			slot = 3,
			tier = "easy",
			event = "expedition",
			goal = 3,
			text = "Welcome pets home from 3 expeditions",
		},
		{
			id = "w_chaos8",
			slot = 3,
			tier = "medium",
			event = "chaos",
			goal = 8,
			text = "Get thrown about by world chaos 8 times",
		},
	},
}
Seasons.QUEST_BY_ID = {}
for kind, list in pairs(Seasons.QUESTS) do
	for _, def in ipairs(list) do
		def.kind = kind
		Seasons.QUEST_BY_ID[def.id] = def
	end
end
-- The week's cosmetic for claiming all three weekly quests, in turn by week (shared/Catalog.lua: award "weekly_bundle").
Seasons.BUNDLE = { "flag_questor", "livery_voyager", "pethat_medal" }

function Seasons.questReward(def)
	local table_ = def.kind == "week" and Config.QUESTS.WEEKLY_REWARD or Config.QUESTS.REWARD
	return table_[def.tier] or 0
end

local function bySlot(list, slot)
	local out = {}
	for _, def in ipairs(list) do
		if def.slot == slot then
			table.insert(out, def)
		end
	end
	return out
end

-- A slot's pool is dealt in CYCLES: every #pool periods, each quest once, in an order shuffled by the cycle's number.
-- Inside a cycle no quest repeats; across a boundary, if the new cycle would start with the quest the last one ended
-- on, its first two swap (a cycle's last place is never touched by its own swap when the pool has three or more), so
-- a quest is never there two periods running.
local function shuffled(n, cycle, salt)
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	for i = n, 2, -1 do
		local j = mix(cycle, salt + i) % i + 1
		order[i], order[j] = order[j], order[i]
	end
	return order
end

local function dealt(pool, index, salt)
	local n = #pool
	if n == 1 then
		return pool[1]
	end
	local cycle, place = index // n, index % n + 1
	local order = shuffled(n, cycle, salt)
	if n == 2 then
		return pool[(index % 2) + 1] -- two quests simply alternate
	end
	local before = shuffled(n, cycle - 1, salt)
	if order[1] == before[n] then
		order[1], order[2] = order[2], order[1]
	end
	return pool[order[place]]
end

-- The quests of period `index` ("day" or "week"): one per slot, the same on every server.
function Seasons.questsFor(kind, index)
	local list = Seasons.QUESTS[kind]
	local picked = {}
	local count = kind == "week" and Config.QUESTS.WEEKLY or Config.QUESTS.DAILY
	for slot = 1, count do
		local pool = bySlot(list, slot)
		if #pool > 0 then
			table.insert(picked, dealt(pool, index, slot * 31 + (kind == "week" and 1000 or 0)))
		end
	end
	return picked
end

local function freshQuests(kind, index)
	local out = {}
	for _, def in ipairs(Seasons.questsFor(kind, index)) do
		table.insert(out, { id = def.id, n = 0, claimed = false })
	end
	return out
end

-- V13.5: the quests whose games were removed, as they were (so one a goblin had already finished is still paid).
Seasons.RETIRED_QUESTS = {
	d_toss = { goal = 30, tier = "easy" },
	d_crabs = { goal = 8, tier = "easy" },
	d_gallery = { goal = 10, tier = "easy" },
	d_derby = { goal = 1, tier = "easy" },
}

-- V13.5: a quest that no longer exists (its game was removed) and was not claimed is replaced by the quest the board
-- deals for its place in this period; if it had been finished it is paid first, as if claimed (an earned reward is
-- never lost). A claimed one is left (it was paid). The others, and their progress and claims, are left exactly as
-- they are. Adds what it paid to `out` (Seasons.ensureQuests's result).
local function replaceRetired(profile, list, kind, index, out)
	local deal
	for i, entry in ipairs(list or {}) do
		if not Seasons.QUEST_BY_ID[entry.id] and not entry.claimed then
			deal = deal or freshQuests(kind, index)
			local fresh = deal[i]
			local taken = false
			for _, other in ipairs(list) do
				taken = taken or (fresh ~= nil and other.id == fresh.id)
			end
			if fresh and not taken then
				local old = Seasons.RETIRED_QUESTS[entry.id]
				if old and (entry.n or 0) >= old.goal then
					local rewards = kind == "week" and Config.QUESTS.WEEKLY_REWARD or Config.QUESTS.REWARD
					local shinies = rewards[old.tier] or 0
					profile.shinies += shinies
					profile.stats.questsDone = (profile.stats.questsDone or 0) + 1
					out.shinies += shinies
					out.count += 1
				end
				list[i] = fresh
			end
		end
	end
end

local function countKeys(map)
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
end

-- Pays every finished, unclaimed quest in `entries` (at a rollover). Returns the Shinies paid and how many.
local function autoClaim(profile, entries)
	local paid, count = 0, 0
	for _, entry in ipairs(entries or {}) do
		local def = Seasons.QUEST_BY_ID[entry.id]
		if def and not entry.claimed and (entry.n or 0) >= def.goal then
			entry.claimed = true
			local shinies = Seasons.questReward(def)
			profile.shinies += shinies
			paid += shinies
			count += 1
			profile.stats.questsDone = (profile.stats.questsDone or 0) + 1
		end
	end
	return paid, count
end

-- The week's cosmetic (once a week, for all three weekly quests claimed). owns(id) -> bool. Returns
-- { item = id } (the caller grants it: Economy.grant) or { shinies = n } (already added), or nil.
local function bundle(profile, week, owns)
	local q = profile.quests
	if q.bundle == week then
		return nil
	end
	for _, entry in ipairs(q.weekly or {}) do
		if not entry.claimed then
			return nil
		end
	end
	if #(q.weekly or {}) == 0 then
		return nil
	end
	q.bundle = week
	local start = week % #Seasons.BUNDLE
	for i = 0, #Seasons.BUNDLE - 1 do
		local id = Seasons.BUNDLE[(start + i) % #Seasons.BUNDLE + 1]
		if not owns(id) then
			return { item = id }
		end
	end
	profile.shinies += Config.QUESTS.BUNDLE_SHINIES
	return { shinies = Config.QUESTS.BUNDLE_SHINIES }
end

-- Brings a profile's quests up to the day and week of `unix`: a new period pays what was finished and not claimed,
-- then deals the new quests. Returns { shinies, count, bundle } paid at a rollover (zeros when nothing rolled).
-- owns(itemId) -> bool (for the week's cosmetic).
function Seasons.ensureQuests(profile, unix, owns)
	local q = profile.quests
	local day, week = Seasons.period("day", unix), Seasons.period("week", unix)
	local out = { shinies = 0, count = 0 }
	if q.day ~= day then
		if q.day ~= nil then
			local s, c = autoClaim(profile, q.daily)
			out.shinies += s
			out.count += c
		end
		q.day = day
		q.daily = freshQuests("day", day)
	end
	if q.week ~= week then
		if q.week ~= nil then
			local s, c = autoClaim(profile, q.weekly)
			out.shinies += s
			out.count += c
			local b = bundle(profile, q.week, owns or function()
				return false
			end)
			if b then
				out.bundle = b
				out.shinies += b.shinies or 0
			end
		end
		q.week = week
		q.weekly = freshQuests("week", week)
	end
	replaceRetired(profile, q.daily, "day", day, out)
	replaceRetired(profile, q.weekly, "week", week, out)
	return out
end

-- Something that counts toward quests happened. event: a quest event name; amount (default 1); detail: what it was
-- (an island, a game, a boat: for `distinct` quests). Returns the quests finished just now ({ { kind, index, def } }),
-- and what a rollover paid if the day or week turned first (Seasons.ensureQuests's result: the caller grants a bundle).
function Seasons.recordQuest(profile, event, amount, detail, unix, owns)
	local rolled = Seasons.ensureQuests(profile, unix, owns)
	local done = {}
	amount = math.max(0, math.floor(amount or 1))
	if amount == 0 then
		return done, rolled
	end
	for _, kind in ipairs({ "day", "week" }) do
		local list = kind == "day" and profile.quests.daily or profile.quests.weekly
		for index, entry in ipairs(list) do
			local def = Seasons.QUEST_BY_ID[entry.id]
			if def and def.event == event and not entry.claimed and (entry.n or 0) < def.goal then
				local before = entry.n or 0
				if def.distinct then
					if detail ~= nil then
						entry.seen = entry.seen or {}
						entry.seen[tostring(detail)] = true
						entry.n = math.min(def.goal, countKeys(entry.seen))
					end
				else
					entry.n = math.min(def.goal, before + amount)
				end
				if before < def.goal and entry.n >= def.goal then
					table.insert(done, { kind = kind, index = index, def = def })
				end
			end
		end
	end
	return done, rolled
end

-- Claim a finished quest. kind "day" | "week", index 1..3. Returns { ok, code, shinies, bundle, rolled }.
--   claimed   paid now        notdone   not finished      already   paid before      unknown   no such quest
-- (rolled: what a rollover paid first, if the day or week had turned; the caller grants its bundle item.)
function Seasons.claimQuest(profile, kind, index, unix, owns)
	local rolled = Seasons.ensureQuests(profile, unix, owns)
	local result = Seasons.claimRolled(profile, kind, index, owns)
	result.rolled = rolled
	return result
end

function Seasons.claimRolled(profile, kind, index, owns)
	local list = kind == "day" and profile.quests.daily or (kind == "week" and profile.quests.weekly or nil)
	local entry = list and type(index) == "number" and list[index]
	local def = entry and Seasons.QUEST_BY_ID[entry.id]
	if not def then
		return { ok = false, code = "unknown" }
	end
	if entry.claimed then
		return { ok = false, code = "already" }
	end
	if (entry.n or 0) < def.goal then
		return { ok = false, code = "notdone" }
	end
	entry.claimed = true
	local shinies = Seasons.questReward(def)
	profile.shinies += shinies
	profile.stats.questsDone = (profile.stats.questsDone or 0) + 1
	local out = { ok = true, code = "claimed", shinies = shinies, def = def }
	if kind == "week" then
		out.bundle = bundle(profile, profile.quests.week, owns or function()
			return false
		end)
	end
	return out
end

-- The board's view of a profile's quests (for the client: the Quest Board and the Port screen's chip).
function Seasons.questView(profile, unix)
	local out = {
		day = {},
		week = {},
		dayLeft = Seasons.secondsLeft("day", unix),
		weekLeft = Seasons.secondsLeft("week", unix),
	}
	for _, kind in ipairs({ "day", "week" }) do
		local list = kind == "day" and profile.quests.daily or profile.quests.weekly
		for index, entry in ipairs(list or {}) do
			local def = Seasons.QUEST_BY_ID[entry.id]
			if def then
				table.insert(out[kind], {
					i = index,
					id = def.id,
					text = def.text,
					n = entry.n or 0,
					goal = def.goal,
					claimed = entry.claimed == true,
					shinies = Seasons.questReward(def),
					go = def.go,
					tier = def.tier,
				})
			end
		end
	end
	out.bundle = profile.quests.bundle == profile.quests.week
	return out
end

-- Leaderboards ----------------------------------------------------------------------------------------------------------
-- id: stable (it names a DataStore); period: "week" | "month"; order: "desc" (more is better) or "asc" (less is
-- better: times, stored in hundredths of a second); tiers: the score for each tier; awards: catalogue `award` sources
-- for placements (top1, top10) and the gold tier (gold). raid: a RAID board (V13.4: the Hall of Legends' centrepiece,
-- listed first everywhere); the others are the Port games' records. icon: its mark on boards and cards.
--
-- V13.4 kept every id (they name the DataStores and the saved bests, so standings and unpaid rewards carry over) and
-- only renamed the monthly "champion" board PIRATE LEGENDS, adding the weekly PIRATE CHAMPIONSHIP ("crown").
local G = Config.PLAYGROUND
Seasons.BOARDS = {
	{
		id = "haul",
		period = "week",
		order = "desc",
		raid = true,
		icon = "💰",
		name = "BIGGEST HAUL",
		sub = "gold banked in one raid",
		unit = "gold",
		tiers = { bronze = 10, silver = 20, gold = 32 },
		awards = { top1 = { "haul_top1" }, top10 = { "weekly_top10" } },
	},
	{
		id = "crown",
		period = "week",
		order = "desc",
		raid = true,
		icon = "👑",
		name = "PIRATE CHAMPIONSHIP",
		sub = string.format("your best %d raids of the week added up", Config.SEASONS.WEEK_RAIDS),
		unit = "gold",
		tiers = { bronze = 25, silver = 50, gold = 80 },
		awards = { top1 = { "crown_top1" }, top10 = { "weekly_top10", "crown_top10" }, gold = { "crown_gold" } },
	},
	{
		id = "champion",
		period = "month",
		order = "desc",
		raid = true,
		icon = "🏆",
		name = "PIRATE LEGENDS",
		sub = string.format("your best %d raids of the month added up", Config.SEASONS.CHAMPION_RAIDS),
		unit = "gold",
		tiers = { bronze = 40, silver = 80, gold = 130 },
		awards = { top1 = { "champion_top1" }, top10 = { "champion_top10" }, gold = { "legend_gold" } },
	},
	{
		-- V13.5: the new course. Only Racing Tub laps count (everyone in the same boat); a test drive's lap is a
		-- class record instead (server/Leaderboards.lua: the week's CLASS RECORDS at the dock).
		id = "regatta2",
		period = "week",
		order = "asc",
		icon = "⛵",
		name = "FASTEST REGATTA",
		sub = "one lap in the Racing Tub",
		unit = "time",
		tiers = { bronze = G.REGATTA.MEDALS.bronze, silver = G.REGATTA.MEDALS.silver, gold = G.REGATTA.MEDALS.gold },
		awards = { top1 = { "regatta_top1" }, top10 = { "weekly_top10", "regatta_top10" }, gold = { "regatta_gold" } },
	},
	{
		-- V13.5: six holes in strokes (fewest wins).
		id = "golf2",
		period = "week",
		order = "asc",
		icon = "⛳",
		name = "CANNON GOLF",
		sub = "fewest strokes round six holes",
		unit = "strokes",
		tiers = { bronze = G.GOLF.MEDALS.bronze, silver = G.GOLF.MEDALS.silver, gold = G.GOLF.MEDALS.gold },
		awards = { top1 = { "golf_top1" }, top10 = { "weekly_top10" } },
	},
	{
		id = "gauntlet",
		period = "month",
		order = "asc",
		icon = "🎣",
		name = "FASTEST GAUNTLET",
		sub = "one Grapple Gauntlet run",
		unit = "time",
		tiers = { bronze = G.GAUNTLET.MEDALS.bronze, silver = G.GAUNTLET.MEDALS.silver, gold = G.GAUNTLET.MEDALS.gold },
		awards = { top1 = { "gauntlet_top1" } },
	},
}
-- V13.5: boards whose games changed (the Regatta's old course, Cannon Golf's old points). They take no new scores and
-- stand nowhere, but they are still known, so what goblins already scored on them (this period's places included) is
-- paid out when the period ends, and their Hall records and DataStores stay as they are.
Seasons.RETIRED_BOARDS = {
	{
		id = "regatta",
		period = "week",
		order = "asc",
		icon = "⛵",
		name = "FASTEST REGATTA (the old course)",
		sub = "one lap round the island",
		unit = "time",
		tiers = { bronze = 54, silver = 43, gold = 36 },
		awards = { top1 = { "regatta_top1" }, top10 = { "weekly_top10", "regatta_top10" }, gold = { "regatta_gold" } },
	},
	{
		id = "golf",
		period = "week",
		order = "desc",
		icon = "⛳",
		name = "CANNON GOLF (three holes)",
		sub = "best round of three holes",
		unit = "points",
		tiers = { bronze = 50, silver = 120, gold = 200 },
		awards = { top1 = { "golf_top1" }, top10 = { "weekly_top10" } },
	},
}
Seasons.BOARD_BY_ID = {}
for _, board in ipairs(Seasons.BOARDS) do
	Seasons.BOARD_BY_ID[board.id] = board
end
for _, board in ipairs(Seasons.RETIRED_BOARDS) do
	board.retired = true
	Seasons.BOARD_BY_ID[board.id] = board
end

-- Every catalogue `award` source the Port can pay, and the items it grants (the tests check both directions).
function Seasons.awardSources()
	local sources = { weekly_bundle = true }
	for _, list in ipairs({ Seasons.BOARDS, Seasons.RETIRED_BOARDS }) do
		for _, board in ipairs(list) do
			for _, awards in pairs(board.awards) do
				for _, source in ipairs(awards) do
					sources[source] = true
				end
			end
		end
	end
	return sources
end

function Seasons.itemsFor(source)
	local out = {}
	for _, item in ipairs(Catalog.items) do
		if item.award == source then
			table.insert(out, item.id)
		end
	end
	return out
end

-- A score as the board stores it (a whole number: times in hundredths) and back.
function Seasons.encode(board, score)
	if board.unit == "time" then
		return math.max(1, math.floor(score * 100 + 0.5))
	end
	return math.max(0, math.floor(score))
end
function Seasons.decode(board, value)
	if board.unit == "time" then
		return value / 100
	end
	return value
end

-- Is `a` better than `b` on this board? (nil is worse than anything.)
function Seasons.better(board, a, b)
	if a == nil then
		return false
	elseif b == nil then
		return true
	end
	if board.order == "asc" then
		return a < b
	end
	return a > b
end

function Seasons.tier(board, score)
	if score == nil then
		return nil
	end
	for _, name in ipairs({ "gold", "silver", "bronze" }) do
		local need = board.tiers[name]
		if need and ((board.order == "asc" and score <= need) or (board.order ~= "asc" and score >= need)) then
			return name
		end
	end
	return nil
end

-- Which period a board is in at `unix`, and its key.
function Seasons.boardKey(board, unix)
	local index = Seasons.period(board.period, unix)
	return Seasons.key(board.period, index), index
end

local function slot(board, key)
	return board.id .. "@" .. key
end
Seasons.slot = slot

-- A goblin's own best on a board this period (in board units: seconds or points), or nil.
function Seasons.best(profile, boardId, unix)
	local board = Seasons.BOARD_BY_ID[boardId]
	if not board then
		return nil
	end
	local key = Seasons.boardKey(board, unix)
	local value = profile.season.best[slot(board, key)]
	return value and Seasons.decode(board, value) or nil
end

-- A new score for a board (the server measured it). Returns improved (bool), the period key, and the stored value.
-- A retired board (V13.5) takes none.
function Seasons.submit(profile, boardId, score, unix)
	local board = Seasons.BOARD_BY_ID[boardId]
	if not board or board.retired or type(score) ~= "number" or score ~= score then
		return false
	end
	local key = Seasons.boardKey(board, unix)
	local value = Seasons.encode(board, score)
	local old = profile.season.best[slot(board, key)]
	if Seasons.better(board, value, old) then
		profile.season.best[slot(board, key)] = value
		return true, key, value
	end
	return false, key, old
end

-- A raid's haul into one bounded list of best raids (`r` = { key, list }) for the period `key`: only the best `keep`
-- count, so playing more never wins by itself. Returns the new sum when it went up, else nil.
local function addBest(r, key, gold, keep)
	if r.key ~= key then
		r.key = key
		r.list = {}
	end
	local list = r.list
	local before = 0
	for _, v in ipairs(list) do
		before += v
	end
	table.insert(list, gold)
	table.sort(list, function(a, b)
		return a > b
	end)
	while #list > keep do
		table.remove(list)
	end
	local after = 0
	for _, v in ipairs(list) do
		after += v
	end
	return after > before and after or nil
end

-- A raid's banked gold goes into the month's best CHAMPION_RAIDS (PIRATE LEGENDS, board "champion") and the week's
-- best WEEK_RAIDS (the PIRATE CHAMPIONSHIP, board "crown"). Returns each sum when it went up (to submit), else nil.
function Seasons.addRaid(profile, gold, unix)
	gold = math.floor(gold or 0)
	if gold <= 0 then
		return nil, nil
	end
	local S = Config.SEASONS
	profile.season.week = profile.season.week or { key = "", list = {} }
	local month =
		addBest(profile.season.raids, Seasons.key("month", Seasons.period("month", unix)), gold, S.CHAMPION_RAIDS)
	local week = addBest(profile.season.week, Seasons.key("week", Seasons.period("week", unix)), gold, S.WEEK_RAIDS)
	return month, week
end

-- Where `score` would stand among a board's known top (stored values, best first: { { u, s } }), counting a goblin's
-- own row only once: the place a fresh score is worth before the next read of the board. nil past the list's end.
function Seasons.rankAmong(board, list, userId, score)
	local value = Seasons.encode(board, score)
	local ahead = 0
	for _, row in ipairs(list or {}) do
		if row.u ~= userId and Seasons.better(board, row.s, value) then
			ahead += 1
		end
	end
	return ahead < Config.SEASONS.HALL and ahead + 1 or nil
end

-- The placement reward for a rank in a period kind: { shinies, top } or nil (unranked, or below the last step).
function Seasons.placement(kind, rank)
	if type(rank) ~= "number" or rank < 1 then
		return nil
	end
	for _, step in ipairs(Config.SEASONS.PLACE[kind]) do
		if rank <= step.rank then
			return { shinies = step.shinies, top = step.rank }
		end
	end
	return nil
end

-- What a finished period pays for one board: { shinies, items = { ids }, tier, rank }. rank may be nil (not in the
-- final standings, or they are missing): then only the tier is paid.
function Seasons.rewardFor(boardId, score, rank)
	local board = Seasons.BOARD_BY_ID[boardId]
	local out = { shinies = 0, items = {}, tier = nil, rank = rank }
	if not board or score == nil then
		return out
	end
	local tier = Seasons.tier(board, score)
	out.tier = tier
	if tier then
		out.shinies += Config.SEASONS.TIER[board.period][tier] or 0
		if tier == "gold" and board.awards.gold then
			for _, source in ipairs(board.awards.gold) do
				for _, id in ipairs(Seasons.itemsFor(source)) do
					table.insert(out.items, id)
				end
			end
		end
	end
	local place = Seasons.placement(board.period, rank)
	if place then
		out.shinies += place.shinies
		local groups = {}
		if rank == 1 and board.awards.top1 then
			table.insert(groups, board.awards.top1)
		end
		if rank <= 10 and board.awards.top10 then
			table.insert(groups, board.awards.top10)
		end
		for _, list in ipairs(groups) do
			for _, source in ipairs(list) do
				for _, id in ipairs(Seasons.itemsFor(source)) do
					if not table.find(out.items, id) then
						table.insert(out.items, id)
					end
				end
			end
		end
	end
	return out
end

-- The finished periods this profile has a score in and has not been paid for: { { board = id, key, score } }.
function Seasons.pending(profile, unix)
	local out = {}
	for name, value in pairs(profile.season.best) do
		local boardId, key = string.match(name, "^([%w_]+)@(.+)$")
		local board = boardId and Seasons.BOARD_BY_ID[boardId]
		local kind, index = Seasons.parse(key)
		if board and kind == board.period and not profile.season.paid[name] then
			local _, finish = Seasons.bounds(kind, index)
			if unix >= finish then
				table.insert(out, { board = boardId, key = key, score = Seasons.decode(board, value), ended = finish })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.ended < b.ended
	end)
	return out
end

-- Pays one finished period (Seasons.pending's entry) with its rank (or nil). Adds the Shinies, marks it paid, records a
-- trophy for the sanctuary's trophy case when a tier or a placement was earned. Returns the reward ({ items } are for
-- the caller to grant: Economy.grant). A second call for the same period pays nothing (returns nil).
function Seasons.pay(profile, entry, rank, unix)
	local board = Seasons.BOARD_BY_ID[entry.board]
	local name = board and slot(board, entry.key)
	if not name or profile.season.paid[name] then
		return nil
	end
	local reward = Seasons.rewardFor(entry.board, entry.score, rank)
	profile.season.paid[name] = math.floor(unix)
	profile.shinies += reward.shinies
	if reward.tier or reward.shinies > 0 then
		local trophies = profile.season.trophies
		table.insert(trophies, {
			board = entry.board,
			key = entry.key,
			tier = reward.tier,
			rank = (rank and rank <= Config.SEASONS.HALL) and rank or nil,
			score = entry.score,
		})
		while #trophies > 24 do
			table.remove(trophies, 1)
		end
	end
	return reward
end

-- Forget what is too old to matter: scores and paid markers more than KEEP periods back (paid markers twice as long,
-- so a score can never be seen without its marker).
function Seasons.trim(profile, unix)
	local keep = Config.SEASONS.KEEP
	local function old(key, factor)
		local kind, index = Seasons.parse(string.match(key, "@(.+)$") or "")
		if not kind then
			return true
		end
		return Seasons.period(kind, unix) - index > keep * factor
	end
	for name in pairs(profile.season.best) do
		if old(name, 1) and profile.season.paid[name] then
			profile.season.best[name] = nil
		end
	end
	for name in pairs(profile.season.paid) do
		if old(name, 2) then
			profile.season.paid[name] = nil
		end
	end
end

return Seasons

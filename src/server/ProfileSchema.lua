-- What a goblin's saved profile looks like (V11), how an older one is brought up to date, and how a damaged one
-- is repaired. Pure functions on plain tables: no DataStore, no players, so the tests can run every case.
--
-- Version 2 (V11):
--   v            2
--   shinies      whole number >= 0
--   owned        { [itemId] = true }      everything owned that is not free for everyone (cosmetics, pets, kits,
--                                         premium grants). Ids this server does not know are KEPT: a newer server
--                                         may have written them, and dropping them would lose someone's item.
--   equipped     { [slot] = itemId }      what is worn (Catalog.LOOK_SLOTS) and the start kit ("kit")
--   petSkins     { [petId] = itemId }     the look each pet wears
--   presets      { { name, look = { [slot] = itemId } } } up to Config.PROGRESS.PRESETS
--   stats        { raids, wins, banked, treasures, snatches, bestCombo, bankedFrom = { [lootId] = count } }
--   achievements { [achievementId] = unix time unlocked }
--   receipts     { purchaseId, ... }     Robux receipts already granted, oldest first, capped (see Receipts)
--   history      { { t, kind, item, amount, balance }, ... } the latest purchases, capped
--   welcomed     true once the starting Shinies were given
--   created, seen  unix times
--   lock         { job, session, at }     who has this profile open (server/ProfileStore.lua). Never trusted from
--                                         a client; only the store code reads or writes it.
--
-- Version 1 (V7 to V10): { v = 1, shinies, pets = { [petId] = true }, kits = { [gearId] = true }, pet, kit, raids,
-- wins, banked, receipts = { [purchaseId] = true } }. migrate() turns it into version 2 keeping every Shiny, pet,
-- kit, choice, total and receipt.
--
-- Version 3 (V13, the Goblin Port): everything in version 2, plus
--   stats.steals        treasures taken from their spot
--   stats.escapes       pursuits that ended with this goblin reaching the sanctuary
--   stats.escapedFrom   { [islandId] = count } which island's pursuer they got away from ("Bone" the Leviathan,
--                       "Skull" the Ghost Fleet, "Temple" the Guardian's speedboat ...)
--   stats.classBanks    { [boatClass] = count } treasure banked having come home in a boat of that class
-- Boat classes are owned like any other item (owned["boat_wraith"] = true) and the one sailed is equipped.boat, so no
-- older field changes meaning. A version-2 profile is upgraded in place (nothing is lost); a version-2 server meeting a
-- version-3 profile refuses to write it ("newer"), which is the safe direction.
--
-- Version 4 (V13.3, the Living Port): everything in version 3, plus
--   stats.questsDone, stats.expeditions, stats.challengeWins, stats.derbyWins
--   games        { day, runs = { [game] = paid runs today }, earned (Shinies from games today), bests (best bonuses
--                today), best = { [game] = personal best }, plays = { [game] = finished runs }, wins = { [game] = n } }
--                (shared/PortGames.lua: the daily caps live HERE, in the profile, so rejoining resets nothing)
--   quests       { day, daily = { { id, n, claimed, seen } }, week, weekly = {...}, bundle (the week whose cosmetic was
--                given) } (shared/Seasons.lua)
--   season       { best = { ["board@period"] = stored score }, paid = { ["board@period"] = unix paid },
--                raids = { key = month, list = best raid hauls }, trophies = { { board, key, tier, rank, score } } }
--   sanctuary    { theme, owned = { theme_<id> / decor_<id> = true }, levels = { [feature] = level },
--                decor = { four decoration ids or "" }, residents = { pet ids } } (shared/Habitat.lua)
--   expeditions  { list = { { id, pet, trip, at, back } }, nextId, day, collected (Shinies collected today) }
--   milestones   { [name] = unix }: firsts already reported to analytics (server/Analytics.lua)
--   challenges   { day, paid (paid wins today), pairs = { [userId] = paid wins against them today } }
-- A version-2 or version-3 profile is upgraded in place: the new tables start empty and nothing old changes meaning;
-- a version-3 server meeting a version-4 profile refuses to write it ("newer").
local ProfileSchema = {}

ProfileSchema.VERSION = 4

local STAT_KEYS = {
	"raids",
	"wins",
	"banked",
	"treasures",
	"snatches",
	"bestCombo",
	"steals",
	"escapes",
	"questsDone", -- V13.3
	"expeditions",
	"challengeWins",
	"derbyWins",
}
ProfileSchema.STAT_KEYS = STAT_KEYS
local STAT_MAPS = { "bankedFrom", "escapedFrom", "classBanks" }

local function whole(value)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function stringSet(value)
	local set = {}
	if type(value) == "table" then
		for key, flag in pairs(value) do
			if type(key) == "string" and #key > 0 and #key <= 64 and flag then
				set[key] = true
			end
		end
	end
	return set
end

local function stringMap(value)
	local map = {}
	if type(value) == "table" then
		for key, id in pairs(value) do
			if type(key) == "string" and type(id) == "string" and #id > 0 and #id <= 64 then
				map[key] = id
			end
		end
	end
	return map
end

local function shortString(value, limit)
	return type(value) == "string" and #value > 0 and #value <= (limit or 64)
end

-- { [string] = whole number > 0 } (a count per game, per goblin...).
local function countMap(value, limit)
	local out, n = {}, 0
	if type(value) == "table" then
		for key, count in pairs(value) do
			if shortString(key, 80) and whole(count) > 0 and n < (limit or 200) then
				out[key] = whole(count)
				n += 1
			end
		end
	end
	return out
end

-- { [string] = number } (finite, not negative: a personal best in seconds or points).
local function numberMap(value)
	local out = {}
	if type(value) == "table" then
		for key, number in pairs(value) do
			if
				shortString(key, 80)
				and type(number) == "number"
				and number == number
				and number >= 0
				and number < 1e9
			then
				out[key] = number
			end
		end
	end
	return out
end

local function optionalWhole(value)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return nil
	end
	return math.floor(value)
end

local function questList(value)
	local out = {}
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			if type(entry) == "table" and shortString(entry.id) and #out < 6 then
				table.insert(out, {
					id = entry.id,
					n = whole(entry.n),
					claimed = entry.claimed == true,
					seen = (type(entry.seen) == "table") and stringSet(entry.seen) or nil,
				})
			end
		end
	end
	return out
end

local function tableOr(value)
	return type(value) == "table" and value or {}
end

-- V13.3: the Living Port's tables, repaired in place (wrong types become empty; nothing is invented).
local function sanitizePort(profile)
	local g = tableOr(profile.games)
	profile.games = {
		day = whole(g.day),
		runs = countMap(g.runs),
		earned = whole(g.earned),
		bests = whole(g.bests),
		best = numberMap(g.best),
		plays = countMap(g.plays),
		wins = countMap(g.wins),
	}
	local q = tableOr(profile.quests)
	profile.quests = {
		day = optionalWhole(q.day),
		daily = questList(q.daily),
		week = optionalWhole(q.week),
		weekly = questList(q.weekly),
		bundle = optionalWhole(q.bundle),
	}
	local season = tableOr(profile.season)
	local raids = tableOr(season.raids)
	local raidList = {}
	if type(raids.list) == "table" then
		for _, gold in ipairs(raids.list) do
			if whole(gold) > 0 and #raidList < 10 then
				table.insert(raidList, whole(gold))
			end
		end
	end
	local trophies = {}
	if type(season.trophies) == "table" then
		for _, t in ipairs(season.trophies) do
			if type(t) == "table" and shortString(t.board) and shortString(t.key) and #trophies < 24 then
				table.insert(trophies, {
					board = t.board,
					key = t.key,
					tier = shortString(t.tier, 12) and t.tier or nil,
					rank = optionalWhole(t.rank),
					score = (type(t.score) == "number" and t.score == t.score) and t.score or 0,
				})
			end
		end
	end
	profile.season = {
		best = countMap(season.best, 400),
		paid = countMap(season.paid, 800),
		raids = { key = type(raids.key) == "string" and raids.key or "", list = raidList },
		trophies = trophies,
	}
	local sanctuary = tableOr(profile.sanctuary)
	local levels = {}
	if type(sanctuary.levels) == "table" then
		for key, level in pairs(sanctuary.levels) do
			if shortString(key, 24) and type(level) == "number" then
				levels[key] = math.clamp(whole(level), 0, 9)
			end
		end
	end
	local decor = {}
	for i = 1, 4 do
		local id = type(sanctuary.decor) == "table" and sanctuary.decor[i] or nil
		decor[i] = shortString(id, 32) and id or ""
	end
	local residents = {}
	if type(sanctuary.residents) == "table" then
		for _, id in ipairs(sanctuary.residents) do
			if shortString(id) and #residents < 12 then
				table.insert(residents, id)
			end
		end
	end
	profile.sanctuary = {
		theme = shortString(sanctuary.theme, 32) and sanctuary.theme or "meadow",
		owned = stringSet(sanctuary.owned),
		levels = levels,
		decor = decor,
		residents = residents,
	}
	local x = tableOr(profile.expeditions)
	local list, top = {}, 0
	if type(x.list) == "table" then
		for _, e in ipairs(x.list) do
			if type(e) == "table" and shortString(e.pet) and shortString(e.trip, 24) and #list < 5 then
				local id = whole(e.id)
				top = math.max(top, id)
				table.insert(list, { id = id, pet = e.pet, trip = e.trip, at = whole(e.at), back = whole(e.back) })
			end
		end
	end
	profile.expeditions = {
		list = list,
		nextId = math.max(whole(x.nextId), top + 1, 1),
		day = whole(x.day),
		collected = whole(x.collected),
	}
	profile.milestones = countMap(profile.milestones)
	local c = tableOr(profile.challenges)
	profile.challenges = { day = whole(c.day), paid = whole(c.paid), pairs = countMap(c.pairs) }
end

function ProfileSchema.new(now)
	return {
		v = ProfileSchema.VERSION,
		shinies = 0,
		owned = {},
		equipped = {},
		petSkins = {},
		presets = {},
		stats = {
			raids = 0,
			wins = 0,
			banked = 0,
			treasures = 0,
			snatches = 0,
			bestCombo = 0,
			steals = 0,
			escapes = 0,
			questsDone = 0,
			expeditions = 0,
			challengeWins = 0,
			derbyWins = 0,
			bankedFrom = {},
			escapedFrom = {},
			classBanks = {},
		},
		achievements = {},
		receipts = {},
		history = {},
		welcomed = false,
		created = now or 0,
		seen = now or 0,
		-- V13.3
		games = { day = 0, runs = {}, earned = 0, bests = 0, best = {}, plays = {}, wins = {} },
		quests = { daily = {}, weekly = {} },
		season = { best = {}, paid = {}, raids = { key = "", list = {} }, trophies = {} },
		sanctuary = { theme = "meadow", owned = {}, levels = {}, decor = { "", "", "", "" }, residents = {} },
		expeditions = { list = {}, nextId = 1, day = 0, collected = 0 },
		milestones = {},
		challenges = { day = 0, paid = 0, pairs = {} },
	}
end

-- Version 1 -> 2. Called only on a table whose v is 1 (or missing, which V7 never wrote but a hand-made test might).
local function fromV1(old, now)
	local profile = ProfileSchema.new(now)
	profile.shinies = whole(old.shinies)
	for petId in pairs(stringSet(old.pets)) do
		profile.owned[petId] = true
	end
	for gearId in pairs(stringSet(old.kits)) do
		profile.owned["kit_" .. gearId] = true
	end
	if type(old.pet) == "string" and profile.owned[old.pet] then
		profile.equipped.pet = old.pet
	end
	if type(old.kit) == "string" and profile.owned["kit_" .. old.kit] then
		profile.equipped.kit = "kit_" .. old.kit
	end
	profile.stats.raids = whole(old.raids)
	profile.stats.wins = whole(old.wins)
	profile.stats.banked = whole(old.banked)
	-- V7 kept receipts as a set; order is unknown, so keep them sorted (all of them: they are what stops a re-sent
	-- receipt from granting twice).
	local receipts = {}
	for id in pairs(stringSet(old.receipts)) do
		table.insert(receipts, id)
	end
	table.sort(receipts)
	profile.receipts = receipts
	profile.migratedFrom = 1
	return profile
end

-- Repairs a version-2 table in place: wrong types become empty, numbers become whole and non-negative, lists are
-- trimmed to their caps. Unknown item ids and unknown top-level keys are kept.
function ProfileSchema.sanitize(profile, limits, now)
	limits = limits or {}
	local fresh = ProfileSchema.new(now)
	for key, default in pairs(fresh) do
		if type(profile[key]) ~= type(default) then
			profile[key] = default
		end
	end
	profile.v = ProfileSchema.VERSION
	profile.shinies = whole(profile.shinies)
	profile.owned = stringSet(profile.owned)
	profile.equipped = stringMap(profile.equipped)
	profile.petSkins = stringMap(profile.petSkins)
	local stats = profile.stats
	for _, key in ipairs(STAT_KEYS) do
		stats[key] = whole(stats[key])
	end
	for _, key in ipairs(STAT_MAPS) do
		local from = {}
		if type(stats[key]) == "table" then
			for id, count in pairs(stats[key]) do
				if type(id) == "string" and #id <= 64 and whole(count) > 0 then
					from[id] = whole(count)
				end
			end
		end
		stats[key] = from
	end
	local achievements = {}
	for id, at in pairs(profile.achievements) do
		if type(id) == "string" then
			achievements[id] = type(at) == "number" and whole(at) or 0
		end
	end
	profile.achievements = achievements
	local presets = {}
	for _, preset in ipairs(profile.presets) do
		if type(preset) == "table" and #presets < (limits.presets or 3) then
			table.insert(presets, {
				name = type(preset.name) == "string" and string.sub(preset.name, 1, 24)
					or ("Outfit " .. (#presets + 1)),
				look = stringMap(preset.look),
			})
		end
	end
	profile.presets = presets
	local receipts = {}
	local seen = {}
	for _, id in ipairs(profile.receipts) do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			table.insert(receipts, id)
		end
	end
	local keep = limits.receipts or 500
	while #receipts > keep do
		table.remove(receipts, 1)
	end
	profile.receipts = receipts
	local history = {}
	for _, entry in ipairs(profile.history) do
		if type(entry) == "table" then
			table.insert(history, entry)
		end
	end
	while #history > (limits.history or 40) do
		table.remove(history, 1)
	end
	profile.history = history
	profile.welcomed = profile.welcomed == true
	profile.created = whole(profile.created)
	profile.seen = whole(profile.seen)
	sanitizePort(profile)
	return profile
end

-- Whatever came out of the store -> a current-version profile, or nil and a reason when this server must not touch it.
--   nil (no data)        a new profile
--   not a table           a new profile, flagged `repaired` (a corrupt value is not worth refusing a player over)
--   v == 1 / missing v    migrated
--   v == 2, 3             upgraded in place (V13, V13.3)
--   v == 4                repaired where needed
--   v >  4                nil, "newer": written by a newer version of the game. This server would lose what it does
--                         not understand, so it plays the goblin unsaved instead of writing over it.
function ProfileSchema.load(data, limits, now)
	if data == nil then
		return ProfileSchema.new(now), "new"
	end
	if type(data) ~= "table" then
		local profile = ProfileSchema.new(now)
		profile.repaired = true
		return profile, "repaired"
	end
	local version = data.v
	if type(version) == "number" and version > ProfileSchema.VERSION then
		return nil, "newer"
	end
	local profile
	local how
	if version == nil or version == 1 then
		profile = fromV1(data, now)
		how = "migrated"
	elseif version == 2 or version == 3 then
		-- V13: version 2 -> 3 adds stats; V13.3: 3 -> 4 adds the Port's tables (sanitize fills them in, empty). Every
		-- item, Shiny, stat and receipt stays.
		profile = data
		profile.migratedFrom = version
		how = "upgraded"
	else
		profile = data
		how = "loaded"
	end
	ProfileSchema.sanitize(profile, limits, now)
	return profile, how
end

-- A deep copy for saving (the store must never hold a reference the game keeps changing).
function ProfileSchema.copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in pairs(value) do
		out[key] = ProfileSchema.copy(inner)
	end
	return out
end

return ProfileSchema

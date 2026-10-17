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
local ProfileSchema = {}

ProfileSchema.VERSION = 2

local STAT_KEYS = { "raids", "wins", "banked", "treasures", "snatches", "bestCombo" }

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

function ProfileSchema.new(now)
	return {
		v = ProfileSchema.VERSION,
		shinies = 0,
		owned = {},
		equipped = {},
		petSkins = {},
		presets = {},
		stats = { raids = 0, wins = 0, banked = 0, treasures = 0, snatches = 0, bestCombo = 0, bankedFrom = {} },
		achievements = {},
		receipts = {},
		history = {},
		welcomed = false,
		created = now or 0,
		seen = now or 0,
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
	local from = {}
	if type(stats.bankedFrom) == "table" then
		for lootId, count in pairs(stats.bankedFrom) do
			if type(lootId) == "string" and whole(count) > 0 then
				from[lootId] = whole(count)
			end
		end
	end
	stats.bankedFrom = from
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
	return profile
end

-- Whatever came out of the store -> a version-2 profile, or nil and a reason when this server must not touch it.
--   nil (no data)        a new profile
--   not a table           a new profile, flagged `repaired` (a corrupt value is not worth refusing a player over)
--   v == 1 / missing v    migrated
--   v == 2                repaired where needed
--   v >  2                nil, "newer": written by a newer version of the game. This server would lose what it does
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

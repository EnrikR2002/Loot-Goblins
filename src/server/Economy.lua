-- The rules of owning things (V11): buying with Shinies, wearing, outfit presets, raid payouts, lasting stats,
-- achievements and grants. Pure functions on a profile table (server/ProfileSchema.lua): no DataStore, no
-- network, no players. server/Progress.lua calls them and tells the goblin; the tests call them directly.
--
-- Every function that can refuse returns a result table { ok = bool, code = string, ... }. Codes:
--   ok        done                       owned     already owned (never charged twice)
--   unknown   no such item               funds     not enough Shinies
--   locked    earned by an achievement   premium   Robux only
--   notforsale cannot be bought           notowned  cannot wear what you do not own
--   wrongslot  item does not go there     needpet   a pet look for a pet you do not own
--   preset    no such preset
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Catalog"))
local PortGames = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("PortGames"))
local Seasons = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Seasons"))

local Economy = {}

local function result(ok, code, extra)
	local out = extra or {}
	out.ok = ok
	out.code = code
	return out
end

local function log(profile, entry, limit)
	table.insert(profile.history, entry)
	while #profile.history > (limit or 40) do
		table.remove(profile.history, 1)
	end
end

-- Ownership --------------------------------------------------------------------------------------------------------
function Economy.owns(profile, id)
	local item = Catalog.get(id)
	if not item then
		return false
	end
	if Catalog.isFree(item) then
		return true
	end
	return profile.owned[id] == true
end

-- Everything owned that is not free, sorted (the client's locker reads this).
function Economy.ownedList(profile)
	local list = {}
	for id in pairs(profile.owned) do
		if Catalog.get(id) then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- Buying with Shinies ------------------------------------------------------------------------------------------------
function Economy.buy(profile, id, now, historyLimit)
	local item = Catalog.get(id)
	if not item or item.retired then
		return result(false, "unknown")
	end
	if Economy.owns(profile, id) then
		return result(false, "owned", { item = item })
	end
	if item.unlock then
		return result(false, "locked", { item = item })
	end
	if not Catalog.forSale(item) then
		return result(false, item.premium and "premium" or "notforsale", { item = item })
	end
	if item.slot == "petskin" and not Economy.owns(profile, item.pet) then
		return result(false, "needpet", { item = item })
	end
	if profile.shinies < item.price then
		return result(false, "funds", { item = item, short = item.price - profile.shinies })
	end
	profile.shinies -= item.price
	profile.owned[id] = true
	log(
		profile,
		{ t = now or 0, kind = "shinies", item = id, amount = item.price, balance = profile.shinies },
		historyLimit
	)
	return result(true, "ok", { item = item, price = item.price, balance = profile.shinies })
end

-- Grants: achievements, Robux, game passes. Returns the ids that were newly owned.
function Economy.grant(profile, ids, source, now, historyLimit)
	local fresh = {}
	for _, id in ipairs(ids) do
		local item = Catalog.get(id)
		if item and not Economy.owns(profile, id) then
			profile.owned[id] = true
			table.insert(fresh, id)
			log(
				profile,
				{ t = now or 0, kind = source, item = id, amount = 0, balance = profile.shinies },
				historyLimit
			)
		end
	end
	return fresh
end

function Economy.addShinies(profile, amount)
	amount = math.max(0, math.floor(amount))
	profile.shinies += amount
	return amount
end

-- The starting Shinies for a goblin's first visit (new profiles and V7 ones migrated). Once.
function Economy.welcome(profile, amount)
	if profile.welcomed then
		return 0
	end
	profile.welcomed = true
	return Economy.addShinies(profile, amount)
end

-- Wearing ------------------------------------------------------------------------------------------------------------
-- equip(profile, slot, id): id nil takes the slot off (back to its default, or empty). A pet look is worn by its own
-- pet (profile.petSkins[pet]); the start kit lives in equipped.kit.
function Economy.equip(profile, slot, id)
	local slotDef = Catalog.slot(slot)
	if not slotDef or slotDef.multi then
		return result(false, "wrongslot")
	end
	if id == nil then
		if slot == "petskin" then
			local pet = profile.equipped.pet
			if pet then
				profile.petSkins[pet] = nil
			end
		else
			profile.equipped[slot] = nil
		end
		return result(true, "ok")
	end
	local item = Catalog.get(id)
	if not item or item.slot ~= slot or item.retired then
		return result(false, item and "wrongslot" or "unknown")
	end
	if not Economy.owns(profile, id) then
		return result(false, "notowned", { item = item })
	end
	if slot == "petskin" then
		if not Economy.owns(profile, item.pet) then
			return result(false, "needpet", { item = item })
		end
		profile.petSkins[item.pet] = id
		return result(true, "ok", { item = item })
	end
	profile.equipped[slot] = id
	return result(true, "ok", { item = item })
end

-- What the goblin wears right now, as a full look (Catalog.LOOK_SLOTS), with anything not owned dropped and the
-- defaults filled in. The one place the server turns a profile into a look.
function Economy.look(profile)
	local look = {}
	for _, slot in ipairs(Catalog.LOOK_SLOTS) do
		local id = profile.equipped[slot]
		local item = id and Catalog.get(id)
		if slot ~= "petskin" and item and item.slot == slot and not item.retired and Economy.owns(profile, id) then
			look[slot] = id
		end
	end
	if look.pet then
		local skin = profile.petSkins[look.pet]
		local item = skin and Catalog.get(skin)
		if item and item.pet == look.pet and Economy.owns(profile, skin) then
			look.petskin = skin
		end
	end
	return Catalog.withDefaults(look)
end

-- The start kit chosen (a Config.GEAR id) or nil.
function Economy.kit(profile)
	local id = profile.equipped.kit
	local item = id and Catalog.get(id)
	if item and item.gear and Economy.owns(profile, id) then
		return item.gear
	end
	return nil
end

-- Drops anything worn that is no longer owned (a revoked or retired item). Returns true if something changed.
function Economy.tidy(profile)
	local changed = false
	for slot, id in pairs(profile.equipped) do
		local item = Catalog.get(id)
		if not item or item.slot ~= slot or not Economy.owns(profile, id) then
			profile.equipped[slot] = nil
			changed = true
		end
	end
	for pet, id in pairs(profile.petSkins) do
		local item = Catalog.get(id)
		if not item or item.pet ~= pet or not Economy.owns(profile, id) then
			profile.petSkins[pet] = nil
			changed = true
		end
	end
	return changed
end

-- Outfit presets: the goblin, boat and style slots (not the pet, which has its own rule about when it can change).
Economy.PRESET_SLOTS = {
	"hat",
	"eyes",
	"face",
	"outfit",
	"back",
	"skin",
	"ears",
	"nose",
	"livery",
	"flag",
	"figurehead",
	"trail",
	"wake",
	"trickfx",
	"callout",
	"victory",
	"title", -- V13.3
}

function Economy.savePreset(profile, index, name, maxPresets)
	if type(index) ~= "number" or index < 1 or index > (maxPresets or 3) or index ~= math.floor(index) then
		return result(false, "preset")
	end
	-- Fill gaps so presets stay a list.
	for i = #profile.presets + 1, index - 1 do
		profile.presets[i] = { name = "Outfit " .. i, look = {} }
	end
	local look = {}
	for _, slot in ipairs(Economy.PRESET_SLOTS) do
		local id = profile.equipped[slot]
		if id and Economy.owns(profile, id) then
			look[slot] = id
		end
	end
	if type(name) ~= "string" or name == "" then
		name = (profile.presets[index] and profile.presets[index].name) or ("Outfit " .. index)
	end
	name = string.sub(string.gsub(name, "[%c]", ""), 1, 24)
	profile.presets[index] = { name = name, look = look }
	return result(true, "ok", { index = index })
end

-- Puts a preset on. Every slot is checked again: a preset can never put on something not owned (it may have been
-- saved by hand-edited data, or the item retired since). Skipped items are reported.
function Economy.loadPreset(profile, index)
	local preset = type(index) == "number" and profile.presets[index]
	if not preset then
		return result(false, "preset")
	end
	local skipped = {}
	for _, slot in ipairs(Economy.PRESET_SLOTS) do
		local id = preset.look[slot]
		if id == nil then
			profile.equipped[slot] = nil
		else
			local item = Catalog.get(id)
			if item and item.slot == slot and not item.retired and Economy.owns(profile, id) then
				profile.equipped[slot] = id
			else
				-- Not owned (any more): the slot is left empty rather than keeping whatever was on before.
				profile.equipped[slot] = nil
				table.insert(skipped, id)
			end
		end
	end
	return result(true, "ok", { index = index, skipped = skipped })
end

-- Raid payout ----------------------------------------------------------------------------------------------------------
-- The breakdown a goblin sees at the end of a raid. P is Config.PROGRESS.
--   participation   for being there (P.MIN_PRESENT seconds of the raid)
--   gold            one Shiny per gold banked, up to P.GOLD_CAP
--   win             the winner (a tie shares it)
--   underdog        banked something and finished at or below the middle: a small lift for trying
--   deeds           V13: small, server-checked things done in the raid (P.DEEDS): taking a treasure from its spot,
--                   getting away from a pursuer to the sanctuary, clean trick landings, snatching from a rival
-- The total is capped at P.RAID_CAP.
function Economy.deedsValue(deeds, P)
	local D = P.DEEDS or {}
	deeds = deeds or {}
	local total = 0
	total += deeds.steal and (D.steal or 0) or 0
	total += deeds.escape and (D.escape or 0) or 0
	total += deeds.snatch and (D.snatch or 0) or 0
	total += math.min(math.max(0, math.floor(deeds.tricks or 0)), D.tricksMax or 0) * (D.trick or 0)
	return total
end

function Economy.payout(gold, won, median, P, deeds)
	gold = math.max(0, math.floor(gold or 0))
	local out = {
		participation = P.PARTICIPATION,
		gold = math.min(gold * P.PER_GOLD, P.GOLD_CAP),
		win = won and P.WIN or 0,
		underdog = (not won and gold >= 1 and gold <= (median or 0)) and P.UNDERDOG or 0,
		deeds = Economy.deedsValue(deeds, P),
	}
	local sum = out.participation + out.gold + out.win + out.underdog + out.deeds
	out.total = math.min(sum, P.RAID_CAP)
	out.capped = sum - out.total
	return out
end

-- Lasting stats --------------------------------------------------------------------------------------------------------
-- kind: "bank" (a = treasure id, b = gold, c = the boat class they came home in, or nil), "raid" (a = won),
-- "snatch", "combo" (a = tricks), V13 "steal" (from its spot), "escape" (a = the island whose pursuer gave up).
function Economy.record(profile, kind, a, b, c)
	local stats = profile.stats
	if kind == "bank" then
		stats.treasures += 1
		stats.banked += math.max(0, math.floor(b or 0))
		if type(a) == "string" then
			stats.bankedFrom[a] = (stats.bankedFrom[a] or 0) + 1
		end
		if type(c) == "string" then
			stats.classBanks[c] = (stats.classBanks[c] or 0) + 1
		end
	elseif kind == "raid" then
		stats.raids += 1
		if a then
			stats.wins += 1
		end
	elseif kind == "snatch" then
		stats.snatches += 1
	elseif kind == "combo" then
		stats.bestCombo = math.max(stats.bestCombo, math.floor(a or 0))
	elseif kind == "steal" then
		stats.steals += 1
	elseif kind == "escape" then
		stats.escapes += 1
		if type(a) == "string" then
			stats.escapedFrom[a] = (stats.escapedFrom[a] or 0) + 1
		end
	end
end

local function countKeys(map)
	local count = 0
	for _ in pairs(map or {}) do
		count += 1
	end
	return count
end

function Economy.statValue(profile, name)
	local stats = profile.stats
	if string.sub(name, 1, 5) == "bank_" then
		return stats.bankedFrom[string.sub(name, 6)] or 0
	elseif string.sub(name, 1, 7) == "escape_" then
		return (stats.escapedFrom or {})[string.sub(name, 8)] or 0
	elseif name == "islands" then
		return countKeys(stats.bankedFrom)
	elseif name == "classes" then
		return countKeys(stats.classBanks)
	elseif name == "gamesTried" then
		return PortGames.tried(profile) -- V13.3: Port games finished at least once
	end
	return stats[name] or 0
end

-- Unlocks every achievement whose goal has been reached and not yet paid. Returns
-- { { achievement, reward = itemId or nil, shinies } ... } for the ones unlocked just now.
function Economy.checkAchievements(profile, now, historyLimit)
	local unlocked = {}
	for _, achievement in ipairs(Catalog.ACHIEVEMENTS) do
		if
			not profile.achievements[achievement.id]
			and Economy.statValue(profile, achievement.stat) >= achievement.goal
		then
			profile.achievements[achievement.id] = now or 0
			Economy.addShinies(profile, achievement.shinies or 0)
			local reward = achievement.reward
			if reward then
				Economy.grant(profile, { reward }, "achievement", now, historyLimit)
			end
			table.insert(unlocked, { achievement = achievement, reward = reward, shinies = achievement.shinies or 0 })
		end
	end
	return unlocked
end

-- A goblin who played while their saved profile could not be opened earned things on a stand-in profile. When the
-- real one opens, what was EARNED moves across (Shinies and stats); nothing was bought on the stand-in (buying needs
-- a saved profile), so there is nothing else to move.
function Economy.mergeEarnings(profile, standIn)
	Economy.addShinies(profile, standIn.shinies)
	local from, to = standIn.stats, profile.stats
	for _, key in ipairs({
		"raids",
		"wins",
		"banked",
		"treasures",
		"snatches",
		"steals",
		"escapes",
		"questsDone",
		"expeditions",
		"challengeWins",
		"derbyWins",
	}) do
		to[key] = (to[key] or 0) + (from[key] or 0)
	end
	Economy.mergePort(profile, standIn)
	to.bestCombo = math.max(to.bestCombo, from.bestCombo or 0)
	for _, map in ipairs({ "bankedFrom", "escapedFrom", "classBanks" }) do
		to[map] = to[map] or {}
		for id, count in pairs(from[map] or {}) do
			to[map][id] = (to[map][id] or 0) + count
		end
	end
end

-- V13.3: what a stand-in earned in the Port moves across too: the day's game counters (so the caps still hold), the
-- personal bests, quest progress on the same day or week (added, up to the goal; distinct details joined), season
-- bests on the same period (the better one) and the month's raid hauls, and the first-time milestones.
function Economy.mergePort(profile, standIn)
	local a, b = profile.games, standIn.games
	if a and b then
		if a.day == b.day then
			for game, n in pairs(b.runs or {}) do
				a.runs[game] = (a.runs[game] or 0) + n
			end
			a.earned = (a.earned or 0) + (b.earned or 0)
			a.bests = (a.bests or 0) + (b.bests or 0)
		elseif (b.day or 0) > (a.day or 0) then
			a.day, a.runs, a.earned, a.bests = b.day, table.clone(b.runs or {}), b.earned or 0, b.bests or 0
		end
		for game, score in pairs(b.best or {}) do
			if PortGames.better(game, score, a.best[game]) then
				a.best[game] = score
			end
		end
		for _, map in ipairs({ "plays", "wins" }) do
			for game, n in pairs(b[map] or {}) do
				a[map][game] = (a[map][game] or 0) + n
			end
		end
	end
	local qa, qb = profile.quests, standIn.quests
	if qa and qb then
		for _, pair in ipairs({ { "day", "daily" }, { "week", "weekly" } }) do
			local period, list = pair[1], pair[2]
			if qb[period] ~= nil and qa[period] == qb[period] then
				for _, theirs in ipairs(qb[list] or {}) do
					for _, ours in ipairs(qa[list] or {}) do
						local def = Seasons.QUEST_BY_ID[ours.id]
						if def and ours.id == theirs.id and not ours.claimed then
							if def.distinct then
								ours.seen = ours.seen or {}
								local n = 0
								for key in pairs(theirs.seen or {}) do
									ours.seen[key] = true
								end
								for _ in pairs(ours.seen) do
									n += 1
								end
								ours.n = math.min(def.goal, n)
							else
								ours.n = math.min(def.goal, (ours.n or 0) + (theirs.n or 0))
							end
						end
					end
				end
			elseif qb[period] ~= nil and (qa[period] == nil or qb[period] > qa[period]) then
				qa[period], qa[list] = qb[period], qb[list]
			end
		end
	end
	local sa, sb = profile.season, standIn.season
	if sa and sb then
		for name, value in pairs(sb.best or {}) do
			local boardId = string.match(name, "^([%w_]+)@")
			local board = boardId and Seasons.BOARD_BY_ID[boardId]
			if board and not sa.paid[name] and Seasons.better(board, value, sa.best[name]) then
				sa.best[name] = value
			end
		end
		if sb.raids and sb.raids.key ~= "" then
			if sa.raids.key == sb.raids.key then
				for _, gold in ipairs(sb.raids.list or {}) do
					table.insert(sa.raids.list, gold)
				end
				table.sort(sa.raids.list, function(x, y)
					return x > y
				end)
				while #sa.raids.list > 10 do
					table.remove(sa.raids.list)
				end
			elseif sa.raids.key < sb.raids.key then
				sa.raids = { key = sb.raids.key, list = table.clone(sb.raids.list or {}) }
			end
		end
	end
	for name, at in pairs(standIn.milestones or {}) do
		if profile.milestones and not profile.milestones[name] then
			profile.milestones[name] = at
		end
	end
	if profile.challenges and standIn.challenges and profile.challenges.day == standIn.challenges.day then
		profile.challenges.paid += standIn.challenges.paid or 0
		for who, n in pairs(standIn.challenges.pairs or {}) do
			profile.challenges.pairs[who] = (profile.challenges.pairs[who] or 0) + n
		end
	end
end

-- Progress toward each achievement, for the locker: { id = { value, goal, done } }.
function Economy.achievementProgress(profile)
	local out = {}
	for _, achievement in ipairs(Catalog.ACHIEVEMENTS) do
		out[achievement.id] = {
			value = math.min(Economy.statValue(profile, achievement.stat), achievement.goal),
			goal = achievement.goal,
			done = profile.achievements[achievement.id] ~= nil,
		}
	end
	return out
end

return Economy

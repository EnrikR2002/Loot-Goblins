-- Lasting progress (V7, rebuilt for V11 Goblin Life): Shinies, everything a goblin owns and wears, outfit presets,
-- achievements and the raid payout. Nothing here changes how a raid is scored: raid Gold wins the raid, Shinies are
-- what a goblin keeps.
--
--   shared/Catalog.lua        what exists (items, slots, achievements)
--   server/Economy.lua        the rules (buy, wear, presets, payout, achievements), pure
--   server/ProfileSchema.lua  the saved shape, migration from V7, repair
--   server/ProfileStore.lua   session-locked reading and writing
--   this module               the goblins in this server: opening, saving, the shop's requests, telling clients
--
-- A goblin's session goes through these states (attribute SaveState tells their client):
--   loading   opening the saved profile (they play at once on a blank stand-in)
--   saved / saving   open; changes are saved within seconds, every AUTOSAVE seconds anyway, and when they leave
--   standin   could not open it yet (another server is still closing it, or the store is down). They keep playing;
--             what they EARN moves into the real profile when it opens (retried in the background). Buying waits.
--   newer     written by a newer version of the game: played unsaved, never written over
--   lost      another server took the profile over: this server stops saving it
--   studio    Studio without DataStore access: an in-memory store, reset when Play stops
-- Every number comes from the server. A client sends only intent ("buy hat_tricorn", "equip hat hat_tricorn").
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("LootGoblins")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(script.Parent.Net)
local Gear = require(script.Parent.Gear)
local Util = require(script.Parent.Util)
local ProfileSchema = require(script.Parent.ProfileSchema)
local ProfileStore = require(script.Parent.ProfileStore)
local Economy = require(script.Parent.Economy)
local Analytics = require(script.Parent.Analytics)
local PortGames = require(Shared:WaitForChild("PortGames"))
local Habitat = require(Shared:WaitForChild("Habitat"))

local Progress = {}
Progress.LookChanged = Util.signal() -- (player): what they wear changed (goblin, boat or pet)
Progress.Opened = Util.signal() -- (player): their saved profile is open (Monetization checks game passes)
-- V13.3, the Living Port. Other modules hang their rules on Progress without Progress requiring them (no cycles):
--   Deed (player, session, event, amount, detail)   something that counts toward quests happened (server/Quests.lua)
--   RaidRewarded (player, session, result)           a raid's payout was made (Quests, Leaderboards)
--   AfterRaid (player, session, result)               ...and after those: the next-up card (server/Prospects.lua)
--   actions[name] = fn(session, a, b)                 a ShopRequest action someone else owns (quests, the sanctuary)
--   publishers = { fn(session) }                      set the player's attributes whenever their profile changes
Progress.Deed = Util.signal()
Progress.RaidRewarded = Util.signal()
Progress.AfterRaid = Util.signal()
-- (player, session, gameId, score, run, extra): a Port game's run was paid (Leaderboards). extra (V13.5): { board (the
-- board this score goes on, or nil: a test drive's lap is not a Racing Tub lap), class (the Regatta boat) }.
Progress.GamePlayed = Util.signal()
Progress.actions = {}
Progress.publishers = {}

local P = Config.PROGRESS
local LIMITS = { presets = P.PRESETS, receipts = P.RECEIPTS_KEEP, history = P.HISTORY }
local sessions = {} -- player -> session
local profileStore = nil
local storeMode = "none" -- "datastore" | "studio" | "none"
local raidNumber = 0

-- Is it safe to change pets here? (Main sets it: the skyship, the Hoard, between raids.)
Progress.petSafe = function(_player)
	return true
end

local function unix()
	return os.time()
end

local function keyFor(player)
	return "u" .. player.UserId
end

-- Telling the client --------------------------------------------------------------------------------------------------
local function saveState(s)
	if s.status == "ready" then
		if storeMode == "studio" then
			return "studio"
		end
		return (s.version > s.savedVersion) and "saving" or "saved"
	end
	return s.status
end

local function publish(s)
	local player, profile = s.player, s.profile
	if not player.Parent then
		return
	end
	local look = Economy.look(profile)
	local encoded = Catalog.encodeLook(look)
	player:SetAttribute("Shinies", profile.shinies)
	player:SetAttribute("SaveState", saveState(s))
	player:SetAttribute("Look", encoded)
	player:SetAttribute("Pet", look.pet)
	player:SetAttribute("Kit", Economy.kit(profile))
	-- V13: the boat class this goblin sails (what B calls: server/Recall.lua). Only ever a class they own.
	local boatItem = look.boat and Catalog.get(look.boat)
	player:SetAttribute("BoatClass", boatItem and boatItem.class or "skiff")
	player:SetAttribute("Raids", profile.stats.raids) -- V13: the HUD says less once a goblin knows the game
	player:SetAttribute("Owned", table.concat(Economy.ownedList(profile), ","))
	local done = {}
	for id in pairs(profile.achievements) do
		table.insert(done, id)
	end
	table.sort(done)
	player:SetAttribute("Achievements", table.concat(done, ","))
	local progress = {}
	for id, entry in pairs(Economy.achievementProgress(profile)) do
		progress[id] = { entry.value, entry.goal }
	end
	player:SetAttribute("AchievementProgress", HttpService:JSONEncode(progress))
	local presets = {}
	for index, preset in ipairs(profile.presets) do
		presets[index] = { name = preset.name, look = preset.look }
	end
	player:SetAttribute("Presets", HttpService:JSONEncode(presets))
	if encoded ~= s.lookSent then
		s.lookSent = encoded
		Progress.LookChanged:Fire(player)
	end
	for _, fn in ipairs(Progress.publishers) do
		local ok, err = pcall(fn, s)
		if not ok then
			warn("[Progress] publisher: " .. tostring(err))
		end
	end
end

local function reply(s, action, outcome, extra)
	local payload = extra or {}
	payload.action = action
	payload.ok = outcome.ok
	payload.code = outcome.code
	payload.balance = s.profile.shinies
	Net.send(s.player, "ShopResult", payload)
end

-- Saving --------------------------------------------------------------------------------------------------------------
local function changed(s, urgent)
	s.version += 1
	if urgent then
		s.saveAt = 0
	else
		s.saveAt = math.min(s.saveAt or math.huge, time() + 6)
	end
	publish(s)
end

-- One save. Waits for a save already running. Returns true when the profile as it was at the call is on disk.
local function saveNow(s, release)
	if s.status ~= "ready" or not profileStore then
		return false
	end
	while s.saving do
		task.wait(0.1)
	end
	if s.status ~= "ready" then
		return false
	end
	s.saving = true
	local version = s.version
	local status = profileStore:save(s.key, s.id, s.profile, release)
	s.saving = false
	s.lastSaveAt = time()
	if status == "ok" then
		s.savedVersion = math.max(s.savedVersion, version)
		s.failures = 0
		if s.version <= s.savedVersion then
			s.saveAt = nil
		end
	elseif status == "lost" or status == "newer" then
		s.status = status
		Net.toast(
			s.player,
			"Your profile was opened in another server, so this one stopped saving it. Rejoin to carry on safely."
		)
		Analytics.event(s.player, "SaveFailed", 1, { reason = status })
	else
		s.failures = (s.failures or 0) + 1
		s.saveAt = time() + math.min(30, 5 * s.failures)
		if s.failures == 2 then
			Net.toast(s.player, "Saving is having trouble. Your progress is kept here and will be saved when it can.")
		end
		Analytics.event(s.player, "SaveFailed", 1, { reason = "store" })
	end
	if s.player.Parent then
		s.player:SetAttribute("SaveState", saveState(s))
	end
	return status == "ok"
end

-- V13.3: another module changed this goblin's profile (a quest claimed, a decoration bought): save it soon (or now)
-- and tell their client.
function Progress.markChanged(player, urgent)
	local s = sessions[player]
	if s then
		changed(s, urgent)
	end
end

-- V13.3: something that counts toward quests (server/Quests.lua listens). event: a quest event name.
function Progress.record(player, event, amount, detail)
	local s = sessions[player]
	if s then
		Progress.Deed:Fire(player, s, event, amount or 1, detail)
	end
end

-- V13.3: owns(itemId) for this goblin's profile (Seasons and Habitat ask with it).
function Progress.ownsFn(s)
	return function(id)
		return Economy.owns(s.profile, id)
	end
end

-- V13.3: a first that matters for retention (server/Analytics.lua), once per goblin ever.
function Progress.milestone(player, name)
	local s = sessions[player]
	if s and Analytics.milestone(player, s.profile, name, unix()) then
		changed(s, false)
	end
end

-- For receipts: save now and say whether it is on disk.
function Progress.saveNow(player)
	local s = sessions[player]
	return s ~= nil and saveNow(s, false)
end

-- Opening ------------------------------------------------------------------------------------------------------------
-- The real profile is open: move in what was earned on the stand-in, give the welcome, check achievements.
local function adopt(s, profile, how, lastSeen)
	local standIn = s.profile
	Economy.mergeEarnings(profile, standIn)
	s.profile = profile
	s.status = "ready"
	s.savedVersion = 0
	s.version = 1 -- something to save: the lock refresh at least, and any merge or migration
	local welcome = Economy.welcome(profile, P.WELCOME)
	Economy.tidy(profile)
	local unlocked = Economy.checkAchievements(profile, unix(), P.HISTORY)
	changed(s, how ~= "loaded" or welcome > 0 or standIn.shinies > 0)
	if welcome > 0 then
		Net.send(s.player, "Welcome", { shinies = welcome, migrated = how == "migrated" })
		Analytics.shinies(s.player, false, welcome, profile.shinies, "Onboarding", "welcome")
	end
	if standIn.shinies > 0 then
		Net.toast(
			s.player,
			string.format("Your saved profile is open: the %d Shinies you earned are in it.", standIn.shinies)
		)
	end
	for _, entry in ipairs(unlocked) do
		Progress.announce(s, entry)
	end
	-- V13.3: a goblin coming back after a day or more (the retention question): how long they were away, in days.
	if type(lastSeen) == "number" and how == "loaded" then
		local away = unix() - lastSeen
		if away >= 20 * 3600 then
			Analytics.event(s.player, "ReturnSession", math.floor(away / 86400 * 10 + 0.5) / 10)
		end
	end
	Progress.Opened:Fire(s.player)
end

local function open(s)
	local tries = 0
	while s.player.Parent and sessions[s.player] == s do
		tries += 1
		local status, profile, how, lastSeen = profileStore:open(s.key, s.id)
		if not s.player.Parent or sessions[s.player] ~= s then
			-- Left while it was opening: give the lock straight back.
			if status == "ok" then
				profileStore:save(s.key, s.id, profile, true)
			end
			return
		end
		if status == "ok" then
			adopt(s, profile, how, lastSeen)
			return
		elseif status == "newer" then
			s.status = "newer"
			publish(s)
			Net.toast(
				s.player,
				"This server is older than the one that last saved you. Progress here will not be saved."
			)
			return
		end
		if tries == P.OPEN_TRIES then
			s.status = "standin"
			publish(s)
			Net.toast(
				s.player,
				status == "locked"
						and "Your saved progress is still being closed by another server. Play on: what you earn will be added when it opens."
					or "Your saved progress could not be loaded yet. Play on: what you earn will be added when it opens."
			)
		end
		task.wait(tries < P.OPEN_TRIES and P.OPEN_RETRY or P.BACKGROUND_RETRY)
	end
end

local function begin(player)
	local s = {
		player = player,
		key = keyFor(player),
		id = HttpService:GenerateGUID(false),
		status = "loading",
		profile = ProfileSchema.new(unix()), -- the stand-in until the real one opens
		version = 0,
		savedVersion = 0,
		present = 0,
		awardedRaid = -1,
		actions = {},
	}
	sessions[player] = s
	publish(s)
	Analytics.onboarding(player, 1)
	if profileStore then
		task.spawn(open, s)
	else
		s.status = "off"
		publish(s)
	end
end

-- Achievements --------------------------------------------------------------------------------------------------------
function Progress.announce(s, entry)
	local achievement = entry.achievement
	local reward = entry.reward and Catalog.get(entry.reward)
	Net.send(s.player, "Achievement", {
		id = achievement.id,
		name = achievement.name,
		how = achievement.how,
		shinies = entry.shinies,
		reward = entry.reward,
		rewardName = reward and reward.name or nil,
	})
	if reward then
		Net.feed(
			s.player.DisplayName .. " earned " .. achievement.name .. ": the " .. reward.name .. "!",
			Catalog.RARITIES.trophy.color
		)
	end
	Analytics.event(s.player, "AchievementUnlocked", 1, { achievement = achievement.id })
	Analytics.shinies(s.player, false, entry.shinies, s.profile.shinies, "Gameplay", "achievement:" .. achievement.id)
end

-- Achievements unlock only on the real profile. A stand-in starts from zero, so it would unlock (and pay) again what a
-- veteran already has; its stats merge into the real profile, and adopt() checks them there.
local function unlock(s)
	if s.status ~= "ready" then
		return {}
	end
	return Economy.checkAchievements(s.profile, unix(), P.HISTORY)
end

local function recordAndCheck(player, kind, a, b, c)
	local s = sessions[player]
	if not s then
		return
	end
	Economy.record(s.profile, kind, a, b, c)
	local unlocked = unlock(s)
	changed(s, #unlocked > 0)
	for _, entry in ipairs(unlocked) do
		Progress.announce(s, entry)
	end
end

-- V13.3: unlock any achievement whose goal a change outside the raid reached (a quest claimed, an expedition home).
function Progress.checkAchievements(player)
	local s = sessions[player]
	if not s then
		return
	end
	local unlocked = unlock(s)
	if #unlocked > 0 then
		changed(s, true)
		for _, entry in ipairs(unlocked) do
			Progress.announce(s, entry)
		end
	end
end

-- V13.3: a finished Port game run (server/Minigames.lua calls this through Minigames.reward). score: the run's score,
-- or nil if it did not count (did not finish, or scored nothing). place: among the goblins in the heat. Pays within the
-- day's caps (shared/PortGames.lua: the counters live in the profile), records bests, feeds quests, the boards and
-- achievements. Returns the breakdown the results card shows. V13.5: a Regatta lap's best is kept per boat class, and
-- only a Racing Tub lap goes on the FASTEST REGATTA board (a test drive is a class record instead).
function Progress.onPortGame(player, gameId, score, place, humans, gameSession)
	local s = sessions[player]
	if not s then
		return nil
	end
	local profile = s.profile
	local entry = gameSession and gameSession.entries and gameSession.entries[player]
	local data = entry and entry.data or {}
	local class = gameId == "regatta" and (data.class or "racer") or nil
	local run = PortGames.finishRun(profile, gameId, score, place, humans, unix(), PortGames.recordKey(gameId, class))
	if score ~= nil then
		s.gamesPlayed = (s.gamesPlayed or 0) + 1
	end
	changed(s, run.shinies > 0)
	if run.shinies > 0 then
		Analytics.shinies(player, false, run.shinies, profile.shinies, "Gameplay", "game:" .. gameId)
	end
	Analytics.event(player, "PortGamePlayed", score ~= nil and 1 or 0, { game = gameId, medal = run.medal or "none" })
	if score ~= nil then
		Progress.milestone(player, "FirstMinigamePlayed")
		-- Quests: what this run counts toward.
		Progress.record(player, "game_any")
		Progress.record(player, "game_" .. gameId)
		Progress.record(player, "game_distinct", 1, gameId)
		if run.best then
			Progress.record(player, "best")
		end
		if run.medal == "gold" then
			Progress.record(player, "medal_gold")
		end
		if gameId == "golf" then
			if (data.greens or 0) > 0 then
				Progress.record(player, "golf_green", data.greens)
			end
			if (data.bestSkips or 0) >= 3 then
				Progress.record(player, "golf_skips")
			end
		elseif class then
			Progress.record(player, "regatta_class", 1, class)
		end
		local def = PortGames.BY_ID[gameId]
		local board = def and def.board
		if gameId == "regatta" and class ~= "racer" then
			board = nil -- a test drive: fair only against the same boat (its class record)
		end
		Progress.GamePlayed:Fire(player, s, gameId, score, run, { board = board, class = class })
	end
	Progress.checkAchievements(player)
	return {
		shinies = run.shinies,
		parts = run.parts,
		medal = run.medal,
		best = run.best,
		first = score ~= nil and run.previous == nil,
		previous = run.previous,
		won = run.won,
		capped = run.capped,
		class = class, -- V13.5: the boat this lap was in (its best is that boat's own)
		balance = profile.shinies,
		today = profile.games.earned,
		cap = Config.PLAYGROUND.DAILY_SHINIES,
	}
end

-- A raid deed (V13): remembered for this raid's payout (Economy.deedsValue).
local function deed(player, name, add)
	local s = sessions[player]
	if not s or not Progress.participating(player) then
		return
	end
	s.deeds = s.deeds or {}
	if add then
		s.deeds[name] = (s.deeds[name] or 0) + add
	else
		s.deeds[name] = true
	end
end

-- A treasure was banked (Main, from Loot.Banked). `class`: the boat class they came home in (V13), or nil.
function Progress.onBanked(player, lootId, value, class)
	recordAndCheck(player, "bank", lootId, value, class)
	Progress.record(player, "gold", value) -- V13.3: quests
	if class then
		Progress.record(player, "bankclass", 1, class)
	end
	local s = sessions[player]
	if s then
		s.bankedThisRaid = true
	end
end

-- A goblin snatched treasure from one they knocked down (Main, from Loot.Taken).
function Progress.onSnatch(player)
	deed(player, "snatch")
	recordAndCheck(player, "snatch")
	Progress.record(player, "snatch")
end

-- V13: a goblin took a treasure from its spot (Main, from Loot.Taken).
function Progress.onSteal(player)
	deed(player, "steal")
	recordAndCheck(player, "steal")
	Progress.record(player, "steal")
end

-- V13: a pursuit of this goblin ended at the sanctuary (Pursuit.Escaped): `islandId` is whose creature it was.
function Progress.onEscape(player, islandId)
	deed(player, "escape")
	recordAndCheck(player, "escape", islandId)
	Progress.record(player, "escape")
	Progress.record(player, "escapefrom", 1, islandId)
end

-- A clean landing after `count` tricks, checked by the server (Boats.TrickLanded).
function Progress.onTrickLanded(player, count)
	deed(player, "tricks", 1)
	Progress.record(player, "tricks", count or 1)
	local s = sessions[player]
	if s and count > s.profile.stats.bestCombo then
		recordAndCheck(player, "combo", count)
	end
end

-- Raid payout ----------------------------------------------------------------------------------------------------------
-- results: { { player, gold, won, place } ... } from Raid.finish. Pays once per goblin per raid.
function Progress.award(results)
	raidNumber += 1
	local golds = {}
	for _, r in ipairs(results) do
		table.insert(golds, r.gold)
	end
	table.sort(golds)
	local median = golds[math.ceil(#golds / 2)] or 0
	local payouts = {}
	for _, r in ipairs(results) do
		local player = r.player
		local s = sessions[player]
		if s and s.awardedRaid ~= raidNumber then
			s.awardedRaid = raidNumber
			if s.present >= P.MIN_PRESENT then
				local breakdown = Economy.payout(r.gold, r.won, median, P, s.deeds)
				Economy.addShinies(s.profile, breakdown.total)
				Economy.record(s.profile, "raid", r.won)
				local unlocked = unlock(s)
				changed(s, true)
				payouts[player] = breakdown.total
				local names = {}
				for _, entry in ipairs(unlocked) do
					table.insert(names, {
						name = entry.achievement.name,
						reward = entry.reward,
						rewardName = entry.reward and Catalog.get(entry.reward).name or nil,
						shinies = entry.shinies,
					})
				end
				Net.send(player, "RaidReward", {
					breakdown = breakdown,
					balance = s.profile.shinies,
					gold = r.gold,
					won = r.won,
					place = r.place,
					achievements = names,
					kept = s.status == "ready",
				})
				for _, entry in ipairs(unlocked) do
					Progress.announce(s, entry)
				end
				Analytics.shinies(player, false, breakdown.total, s.profile.shinies, "Gameplay", "raid")
				if s.profile.stats.raids == 1 then
					Analytics.onboarding(player, 2)
					Progress.milestone(player, "FirstRaidCompleted")
				elseif s.profile.stats.raids == 2 then
					Progress.milestone(player, "SecondRaidCompleted")
				end
				-- V13.3: the RaidContinuation funnel (does a goblin who finished a raid choose to play another?).
				s.raidsFinished = (s.raidsFinished or 0) + 1
				if s.raidsFinished == 1 then
					Analytics.continuation(player, s.id, 1)
				elseif s.raidsFinished == 2 then
					Analytics.continuation(player, s.id, 3)
				end
				-- Quests and the leaderboards, then the next-up card.
				local result = {
					gold = r.gold,
					won = r.won,
					place = r.place,
					raiders = #results,
					banked = s.bankedThisRaid == true,
					breakdown = breakdown,
				}
				Progress.RaidRewarded:Fire(player, s, result)
				Progress.AfterRaid:Fire(player, s, result)
			else
				Net.send(player, "RaidReward", { late = true, balance = s.profile.shinies, gold = r.gold })
			end
		end
		if s then
			s.present = 0
			s.bankedThisRaid = nil
		end
	end
	return payouts
end

-- The raid has started (V13: for these goblins; `late` when one joins a raid already running from the Port): hand out
-- the kit each goblin chose (a convenience, not a lock) and start counting the time they are really in it.
function Progress.onRaidStart(players, late)
	for _, player in ipairs(players or {}) do
		local s = sessions[player]
		if s then
			s.present = 0
			s.deeds = {}
			s.bankedThisRaid = nil
			-- V13.3: retention. Every raid since V13.2 is one a goblin chose to join (AUTO-JOIN is a standing choice).
			s.raidsJoined = (s.raidsJoined or 0) + 1
			Analytics.event(player, "RaidJoined", s.raidsJoined, {
				auto = player:GetAttribute("AutoJoin") == true,
				late = late == true,
			})
			if s.profile.stats.raids == 1 then
				Progress.milestone(player, "SecondRaidStarted")
			end
			if (s.raidsFinished or 0) >= 1 and not s.continued then
				s.continued = true
				Analytics.continuation(player, s.id, 2)
			end
			local gear = Economy.kit(s.profile)
			if gear then
				Gear.give(player, gear, true)
			end
		end
	end
	local _ = late
end

-- Who is in the raid (Main sets it to Raid.isParticipant). A goblin waiting in the Port earns no presence.
Progress.participating = function(_player)
	return true
end

function Progress.tick(dt, active)
	if not active then
		return
	end
	for player, s in pairs(sessions) do
		if Progress.participating(player) then
			s.present += dt
		end
	end
end

-- The shop and the locker ------------------------------------------------------------------------------------------
local MESSAGES = {
	unknown = "That item does not exist.",
	owned = "You already own that.",
	locked = "That one is earned, not bought: see its achievement.",
	premium = "That one is a Robux item.",
	notforsale = "That one is not for sale.",
	funds = "Not enough Shinies yet.",
	notowned = "You do not own that yet.",
	wrongslot = "That does not go there.",
	needpet = "Get that pet first.",
	preset = "No outfit saved there.",
	unsaved = "Buying waits until your saved progress is open (a few seconds after joining).",
	petbusy = "Pets change in the Port, or at the Hoard during a raid.",
	boatbusy = "Your boat changes in the Port, or at the Hoard during a raid.",
	away = "That pet is away on an expedition: it comes home at your sanctuary.",
	busy = "Slow down a little.",
}

-- Is it safe to change the boat you sail here? (Main sets it: the Port, the Hoard, between raids.)
Progress.boatSafe = function(_player)
	return true
end

local function allowed(s)
	local t = time()
	local recent = 0
	for i = #s.actions, 1, -1 do
		if t - s.actions[i] < 1 then
			recent += 1
		else
			table.remove(s.actions, i)
		end
	end
	if recent >= P.ACTIONS_PER_SECOND then
		return false
	end
	table.insert(s.actions, t)
	return true
end

local WEARABLE = {}
for _, slot in ipairs(Catalog.LOOK_SLOTS) do
	WEARABLE[slot] = true
end
WEARABLE.kit = true

local function wear(s, slot, id)
	if slot == "pet" and s.profile.equipped.pet ~= id and not Progress.petSafe(s.player) then
		return { ok = false, code = "petbusy" }
	end
	-- V13.3: a pet out on an expedition cannot follow anyone until it is home.
	if slot == "pet" and id and Habitat.away(s.profile)[id] then
		return { ok = false, code = "away" }
	end
	-- V13: the boat you sail changes only in the Port (or at the Hoard): never in the middle of a chase.
	if slot == "boat" and s.profile.equipped.boat ~= id and not Progress.boatSafe(s.player) then
		return { ok = false, code = "boatbusy" }
	end
	local outcome = Economy.equip(s.profile, slot, id)
	if outcome.ok then
		changed(s, false)
		local item = id and Catalog.get(id)
		if item then
			Analytics.event(s.player, slot == "pet" and "PetEquipped" or "CosmeticEquipped", 1, { slot = slot })
			if not s.equippedOnce then
				s.equippedOnce = true
				Analytics.onboarding(s.player, 4)
			end
		end
	end
	return outcome
end

-- ShopRequest(action, a, b):
--   "buy", itemId                    buy with Shinies (and wear it, where that makes sense)
--   "equip", slot, itemId            wear something owned
--   "unequip", slot                  take it off (back to the slot's default)
--   "presetsave", index, name        save what is worn as a preset
--   "presetload", index              wear a preset (only items still owned)
--   "opened"                         the shop was opened (analytics)
-- ("robux", key is routed to Monetization by Main.)
function Progress.handle(player, action, a, b)
	local s = sessions[player]
	if not s or type(action) ~= "string" then
		return
	end
	if not allowed(s) then
		reply(s, action, { ok = false, code = "busy" }, { message = MESSAGES.busy })
		return
	end
	if action == "buy" then
		if type(a) ~= "string" then
			return
		end
		if s.status ~= "ready" then
			reply(s, action, { ok = false, code = "unsaved" }, { id = a, message = MESSAGES.unsaved })
			return
		end
		local firstPurchase = #s.profile.history == 0
		local outcome = Economy.buy(s.profile, a, unix(), P.HISTORY)
		local extra = { id = a, message = MESSAGES[outcome.code] }
		if outcome.ok then
			local item = outcome.item
			changed(s, true)
			Analytics.shinies(player, true, outcome.price, s.profile.shinies, "Shop", item.id)
			if firstPurchase then
				Analytics.event(player, "FirstShiniesPurchase", outcome.price, { item = item.id })
				Analytics.onboarding(player, 3)
			end
			if item.slot == "boat" and not item.free then
				Progress.milestone(player, "FirstSpecialtyBoat") -- V13.3 (a Robux grant: Progress.granted)
			end
			-- Wear it straight away (a pet only where pets can change; a pet look only on its own pet).
			local slot = item.slot
			local equipped = false
			if WEARABLE[slot] and slot ~= "kit" then
				if slot == "petskin" then
					if s.profile.equipped.pet == item.pet then
						equipped = wear(s, slot, item.id).ok
					end
				else
					equipped = wear(s, slot, item.id).ok
				end
			end
			extra.equipped = equipped
			extra.message = "Bought: " .. item.name .. (equipped and ". You are wearing it." or ".")
		else
			if outcome.code ~= "owned" then
				Analytics.event(player, "PurchaseFailed", 1, { reason = outcome.code })
			end
			if outcome.code == "funds" then
				extra.message = string.format("Not enough Shinies yet: %d more to go.", outcome.short or 0)
			end
		end
		reply(s, action, outcome, extra)
	elseif action == "equip" or action == "unequip" then
		local slot = a
		local id = action == "equip" and b or nil
		if type(slot) ~= "string" or (id ~= nil and type(id) ~= "string") then
			return
		end
		local outcome = (slot == "kit" or WEARABLE[slot]) and wear(s, slot, id) or { ok = false, code = "wrongslot" }
		reply(s, action, outcome, { slot = slot, id = id, message = not outcome.ok and MESSAGES[outcome.code] or nil })
	elseif action == "presetsave" then
		local outcome = Economy.savePreset(s.profile, a, b, P.PRESETS)
		if outcome.ok then
			changed(s, false)
		end
		reply(s, action, outcome, { index = a, message = outcome.ok and "Outfit saved." or MESSAGES.preset })
	elseif action == "presetload" then
		local outcome = Economy.loadPreset(s.profile, a)
		if outcome.ok then
			changed(s, false)
		end
		local message = outcome.ok and "Outfit on." or MESSAGES.preset
		if outcome.ok and #outcome.skipped > 0 then
			message = string.format("Outfit on (%d item(s) you no longer own were left off).", #outcome.skipped)
		end
		reply(s, action, outcome, { index = a, message = message })
	elseif action == "opened" then
		Analytics.event(player, "ShopOpened")
	elseif Progress.actions[action] then
		-- V13.3: the Quest Board's and the sanctuary's actions (server/Quests.lua, server/Sanctuary.lua).
		Progress.actions[action](s, a, b)
	end
end

-- V13.3: is this session's real profile open (buying, claiming and sending expeditions wait until it is)?
function Progress.isReady(s)
	return s ~= nil and s.status == "ready"
end

-- Used by Monetization and Emotes ---------------------------------------------------------------------------------------
function Progress.session(player)
	return sessions[player]
end

function Progress.sessionByUserId(userId)
	for player, s in pairs(sessions) do
		if player.UserId == userId then
			return s
		end
	end
	return nil
end

function Progress.owns(player, id)
	local s = sessions[player]
	return s ~= nil and Economy.owns(s.profile, id)
end

function Progress.look(player)
	local s = sessions[player]
	return s and Economy.look(s.profile) or Catalog.withDefaults({})
end

function Progress.profileOf(player)
	local s = sessions[player]
	return s and s.profile
end

-- A grant from outside the shop (Robux, game passes): marks the change and tells the client.
function Progress.granted(player, urgent)
	local s = sessions[player]
	if s then
		changed(s, urgent)
		-- V13.3: a boat class from a game pass or product counts as the first specialty boat too.
		for _, item in ipairs(Catalog.bySlot.boat or {}) do
			if not item.free and Economy.owns(s.profile, item.id) then
				Progress.milestone(player, "FirstSpecialtyBoat")
				break
			end
		end
	end
end

-- Leaving and shutting down -------------------------------------------------------------------------------------------------
function Progress.forget(player)
	local s = sessions[player]
	if not s then
		return
	end
	s.leaving = true
	-- V13.3: how much of the game this visit used (raids joined and Port games played), for retention.
	Analytics.event(player, "SessionSummary", s.raidsJoined or 0, { games = s.gamesPlayed or 0 })
	if s.status == "ready" then
		saveNow(s, true)
	end
	if sessions[player] == s then
		sessions[player] = nil
	end
end

local function useStore(store, mode, budget)
	storeMode = mode
	profileStore = ProfileStore.new({
		store = store,
		job = (game.JobId ~= "" and game.JobId) or ("studio-" .. HttpService:GenerateGUID(false)),
		budget = budget,
		limits = LIMITS,
		lockStale = P.LOCK_STALE,
	})
end

function Progress.init()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(P.STORE)
	end)
	if ok and store and RunService:IsStudio() then
		-- Studio may have no DataStore access (an unpublished place, or API access off): find out once.
		ok = pcall(function()
			store:GetAsync("access-check")
		end)
	end
	if ok and store then
		useStore(store, "datastore", function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end)
	elseif RunService:IsStudio() and P.STUDIO_MOCK then
		useStore(ProfileStore.mock(), "studio", nil)
	end
	Players.PlayerAdded:Connect(begin)
	for _, player in ipairs(Players:GetPlayers()) do
		if not sessions[player] then
			task.spawn(begin, player)
		end
	end
	-- Saves: soon after a change, and every AUTOSAVE seconds anyway (which keeps the session lock fresh).
	task.spawn(function()
		while true do
			task.wait(1)
			local t = time()
			for _, s in pairs(sessions) do
				if s.status == "ready" and not s.saving and not s.leaving then
					local due = (s.saveAt and t >= s.saveAt) or (t - (s.lastSaveAt or 0) >= P.AUTOSAVE)
					if due then
						s.saveAt = nil
						task.spawn(saveNow, s, false)
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, s in pairs(sessions) do
			if s.status == "ready" then
				pending += 1
				task.spawn(function()
					saveNow(s, true)
					pending -= 1
				end)
			end
		end
		local started = time()
		while pending > 0 and time() - started < 25 do
			task.wait(0.2)
		end
	end)
end

-- For tests: run this server on a stand-in store (ProfileStore.mock()).
function Progress.useStore(store)
	useStore(store, "studio", nil)
end

-- For tests (the Studio harness): the goblin leaves (saved, lock released) and joins again in this server, as a new
-- session on the same store; and the raw store, to plant another server's lock or read what was written.
function Progress.rejoinForTest(player)
	Progress.forget(player)
	begin(player)
end

function Progress.storeForTest()
	return profileStore and profileStore.store
end

return Progress

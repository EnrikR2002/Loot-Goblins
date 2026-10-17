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

local Progress = {}
Progress.LookChanged = Util.signal() -- (player): what they wear changed (goblin, boat or pet)
Progress.Opened = Util.signal() -- (player): their saved profile is open (Monetization checks game passes)

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

-- For receipts: save now and say whether it is on disk.
function Progress.saveNow(player)
	local s = sessions[player]
	return s ~= nil and saveNow(s, false)
end

-- Opening ------------------------------------------------------------------------------------------------------------
-- The real profile is open: move in what was earned on the stand-in, give the welcome, check achievements.
local function adopt(s, profile, how)
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
	Progress.Opened:Fire(s.player)
end

local function open(s)
	local tries = 0
	while s.player.Parent and sessions[s.player] == s do
		tries += 1
		local status, profile, how = profileStore:open(s.key, s.id)
		if not s.player.Parent or sessions[s.player] ~= s then
			-- Left while it was opening: give the lock straight back.
			if status == "ok" then
				profileStore:save(s.key, s.id, profile, true)
			end
			return
		end
		if status == "ok" then
			adopt(s, profile, how)
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

local function recordAndCheck(player, kind, a, b)
	local s = sessions[player]
	if not s then
		return
	end
	Economy.record(s.profile, kind, a, b)
	local unlocked = Economy.checkAchievements(s.profile, unix(), P.HISTORY)
	changed(s, #unlocked > 0)
	for _, entry in ipairs(unlocked) do
		Progress.announce(s, entry)
	end
end

-- A treasure was banked (Main, from Loot.Banked).
function Progress.onBanked(player, lootId, value)
	recordAndCheck(player, "bank", lootId, value)
end

-- A goblin snatched treasure from one they knocked down (Main, from Loot.Taken).
function Progress.onSnatch(player)
	recordAndCheck(player, "snatch")
end

-- A clean landing after `count` tricks, checked by the server (Boats.TrickLanded).
function Progress.onTrickLanded(player, count)
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
				local breakdown = Economy.payout(r.gold, r.won, median, P)
				Economy.addShinies(s.profile, breakdown.total)
				Economy.record(s.profile, "raid", r.won)
				local unlocked = Economy.checkAchievements(s.profile, unix(), P.HISTORY)
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
				end
			else
				Net.send(player, "RaidReward", { late = true, balance = s.profile.shinies, gold = r.gold })
			end
		end
		if s then
			s.present = 0
		end
	end
	return payouts
end

-- The raid has started: hand out the kit each goblin chose (a convenience, not a lock).
function Progress.onRaidStart()
	for player, s in pairs(sessions) do
		local gear = Economy.kit(s.profile)
		if gear then
			Gear.give(player, gear, true)
		end
	end
end

function Progress.tick(dt, active)
	if not active then
		return
	end
	for _, s in pairs(sessions) do
		s.present += dt
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
	petbusy = "Pets can be changed on the skyship, at the Hoard or between raids.",
	busy = "Slow down a little.",
}

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
	end
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
	end
end

-- Leaving and shutting down -------------------------------------------------------------------------------------------------
function Progress.forget(player)
	local s = sessions[player]
	if not s then
		return
	end
	s.leaving = true
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

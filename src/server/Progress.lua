-- Lasting progress (V7): Shinies, pets and "start with gear". Nothing here changes how a raid is
-- scored: raid Gold wins the raid, Shinies are what a goblin keeps. They are different currencies
-- with different names on purpose (the HUD and the shop never say "gold" for one and "Shinies" for the
-- other).
--
-- What is saved (one DataStore key per player, Config.PROGRESS.STORE):
--   shinies, owned pets, owned start-kits, the pet and the kit chosen, a few totals, and the ids of
--   Robux receipts already granted (so a receipt processed twice grants once).
--
-- Rules the server keeps:
--   * every number comes from the server: a raid pays out once per goblin per raid (a token), the
--     amount is capped, and a buy or an equip is checked against the catalogue and what is owned;
--   * a profile that could NOT be loaded is never saved over the one that exists: the goblin plays with
--     a blank, unsaved profile and is told so (attribute SaveState = "unsaved"). Studio without API
--     access (and any server with DataStores down) behaves the same way: "unavailable";
--   * saves are retried, are queued when they fail, and run on leaving, at intervals, and on shutdown;
--   * winners earn more but not much more, a goblin who tried always earns something, and the biggest
--     purchases are sidegrades (a pet is a different verb, not a bigger number): see Config.PETS.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Gear = require(script.Parent.Gear)

local Progress = {}

local P = Config.PROGRESS
local profiles = {} -- player -> profile table
local state = {} -- player -> { loaded, dirty, present, awardedRaid, saving }
local store = nil
local raidNumber = 0

local function newProfile()
	return {
		v = 1,
		shinies = 0,
		pets = {},
		kits = {},
		pet = nil,
		kit = nil,
		raids = 0,
		wins = 0,
		banked = 0,
		receipts = {},
	}
end

local function keyFor(player)
	return "u" .. player.UserId
end

-- A store call that may fail: tries a few times, returns ok, result.
local function try(fn)
	local ok, result
	for attempt = 1, 3 do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(0.5 * attempt)
	end
	return false, result
end

local function publish(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute("Shinies", profile.shinies)
	player:SetAttribute("Pet", profile.pet)
	local pets, kits = {}, {}
	for id in pairs(profile.pets) do
		table.insert(pets, id)
	end
	for id in pairs(profile.kits) do
		table.insert(kits, id)
	end
	table.sort(pets)
	table.sort(kits)
	player:SetAttribute("OwnedPets", table.concat(pets, ","))
	player:SetAttribute("OwnedKits", table.concat(kits, ","))
	player:SetAttribute("Kit", profile.kit)
end

-- Saving ----------------------------------------------------------------------------------------------
function Progress.save(player)
	local s, profile = state[player], profiles[player]
	if not s or not profile or not s.loaded or s.saving then
		return s ~= nil and not s.dirty
	end
	if not store then
		return false
	end
	s.saving = true
	local snapshot = table.clone(profile)
	local ok = try(function()
		store:UpdateAsync(keyFor(player), function(_old)
			return snapshot
		end)
	end)
	s.saving = false
	if ok then
		s.dirty = false
		player:SetAttribute("SaveState", "saved")
	else
		s.dirty = true
		player:SetAttribute("SaveState", "unsaved")
	end
	return ok
end

local function markDirty(player)
	local s = state[player]
	if s then
		s.dirty = true
	end
	publish(player)
end

-- Loading ---------------------------------------------------------------------------------------------
local function load(player)
	local s = { loaded = false, dirty = false, present = 0, awardedRaid = -1, saving = false }
	state[player] = s
	player:SetAttribute("SaveState", "loading")
	local profile
	if store then
		local ok, result = try(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			profile = type(result) == "table" and result or newProfile()
			s.loaded = true
			player:SetAttribute("SaveState", "saved")
		else
			-- Could not read: never write over what is there. Play on a blank, unsaved profile.
			profile = newProfile()
			player:SetAttribute("SaveState", "unsaved")
			Net.toast(
				player,
				"Your saved progress could not be loaded. You can play, but nothing will be saved this time."
			)
		end
	else
		profile = newProfile()
		player:SetAttribute("SaveState", "unavailable")
	end
	for key, default in pairs(newProfile()) do
		if profile[key] == nil then
			profile[key] = default
		end
	end
	profiles[player] = profile
	publish(player)
	-- A profile that failed to load must not be saved; a blank one with no store has nowhere to go.
end

-- Raid payout -----------------------------------------------------------------------------------------
-- results: { { player, gold, won } ... } from Raid.finish. Returns the table of payouts.
function Progress.award(results)
	raidNumber += 1
	local payouts = {}
	local golds = {}
	for _, r in ipairs(results) do
		table.insert(golds, r.gold)
	end
	table.sort(golds)
	local median = golds[math.ceil(#golds / 2)] or 0
	for _, r in ipairs(results) do
		local player = r.player
		local s, profile = state[player], profiles[player]
		if s and profile and s.awardedRaid ~= raidNumber and s.present >= P.MIN_PRESENT then
			s.awardedRaid = raidNumber
			local amount = P.PARTICIPATION + math.min(r.gold * P.PER_GOLD, P.GOLD_CAP)
			if r.won then
				amount += P.WIN
			elseif r.gold >= 1 and r.gold <= median then
				amount += P.UNDERDOG -- a small lift for a goblin who got something home and is behind
			end
			amount = math.min(amount, P.RAID_CAP)
			profile.shinies += amount
			profile.raids += 1
			profile.wins += r.won and 1 or 0
			profile.banked += r.gold
			payouts[player] = amount
			markDirty(player)
			Net.toast(player, string.format("+%d Shinies (kept for good).", amount))
		end
		if s then
			s.present = 0
		end
	end
	for player in pairs(payouts) do
		task.spawn(Progress.save, player)
	end
	return payouts
end

-- The raid has started: hand out the kit each goblin chose (it is a convenience, not a lock).
function Progress.onRaidStart()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = profiles[player]
		if profile and profile.kit and profile.kits[profile.kit] then
			Gear.give(player, profile.kit, true)
		end
	end
end

function Progress.tick(dt, active)
	if not active then
		return
	end
	for _, s in pairs(state) do
		s.present += dt
	end
end

-- The shop ---------------------------------------------------------------------------------------------
local function priceOf(kind, id)
	if kind == "pet" and Config.PETS[id] then
		return Config.PETS[id].price
	elseif kind == "kit" and Config.GEAR[id] then
		return Config.KIT_PRICE
	end
	return nil
end

function Progress.grantPet(player, id)
	local profile = profiles[player]
	if not profile or not Config.PETS[id] then
		return false
	end
	profile.pets[id] = true
	markDirty(player)
	return true
end

-- ShopRequest(action, id): "buy" (pet), "equip" (pet), "unequip", "buykit" (kit), "kit" (choose the
-- kit, or "none"), "robux" (a pet, by Robux: only when a product is configured).
function Progress.handle(player, action, id)
	local profile = profiles[player]
	if not profile or type(action) ~= "string" then
		return
	end
	id = type(id) == "string" and id or nil
	if action == "buy" or action == "buykit" then
		local kind = action == "buy" and "pet" or "kit"
		local price = id and priceOf(kind, id)
		local owned = kind == "pet" and profile.pets or profile.kits
		if not price then
			return
		end
		if owned[id] then
			Net.toast(player, "You already own that.")
			return
		end
		if profile.shinies < price then
			Net.toast(player, string.format("Not enough Shinies: %d needed, you have %d.", price, profile.shinies))
			return
		end
		profile.shinies -= price
		owned[id] = true
		if kind == "pet" and not profile.pet then
			profile.pet = id
		end
		markDirty(player)
		Net.toast(player, "Bought: " .. (kind == "pet" and Config.PETS[id].name or Config.GEAR[id].name) .. ".")
		task.spawn(Progress.save, player)
	elseif action == "equip" then
		if id and profile.pets[id] then
			profile.pet = id
			markDirty(player)
		end
	elseif action == "unequip" then
		profile.pet = nil
		markDirty(player)
	elseif action == "kit" then
		if id == "none" then
			profile.kit = nil
		elseif id and profile.kits[id] then
			profile.kit = id
		else
			return
		end
		markDirty(player)
	end
end

function Progress.forget(player)
	local s = state[player]
	if s and s.dirty then
		Progress.save(player)
	end
	state[player] = nil
	profiles[player] = nil
end

function Progress.profileOf(player)
	return profiles[player]
end

-- Idempotent Robux receipts: remembers a receipt id, returns true if it was new.
function Progress.noteReceipt(player, receiptId)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local key = tostring(receiptId)
	if profile.receipts[key] then
		return false
	end
	profile.receipts[key] = true
	-- Keep the list short: the oldest ids are only needed for as long as Roblox can resend them.
	local count = 0
	for _ in pairs(profile.receipts) do
		count += 1
	end
	if count > 300 then
		profile.receipts = { [key] = true }
	end
	markDirty(player)
	return true
end

function Progress.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(P.STORE)
	end)
	store = ok and result or nil
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	task.spawn(function()
		while true do
			task.wait(P.AUTOSAVE)
			for player, s in pairs(state) do
				if s.dirty then
					task.spawn(Progress.save, player)
				end
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for player, s in pairs(state) do
			if s.dirty then
				Progress.save(player)
			end
		end
	end)
end

-- For tests: a store that is not the real one (a table with GetAsync, UpdateAsync).
function Progress.useStore(fake)
	store = fake
	for _, s in pairs(state) do
		s.loaded = true -- the stand-in 'loaded' for them
	end
end

return Progress

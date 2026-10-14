-- The match: a timed raid, then a short intermission, forever.
-- During a raid, banked loot adds gold to your score. When time runs out, the
-- richest goblin wins, loot still out in the world is lost, and everything resets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Heat = require(script.Parent.Heat)
local Threats = require(script.Parent.Threats)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Boats = require(script.Parent.Boats)
local Coins = require(script.Parent.Coins)
local Creatures = require(script.Parent.Creatures)
local Pursuit = require(script.Parent.Pursuit)
local SeaMobs = require(script.Parent.SeaMobs)
local Blast = require(script.Parent.Blast)
local Destructibles = require(script.Parent.Destructibles)
local Mechanisms = require(script.Parent.Mechanisms)
local Cannons = require(script.Parent.Cannons)
local Kegs = require(script.Parent.Kegs)
local Navy = require(script.Parent.Navy)
local Storms = require(script.Parent.Storms)
local Troubles = require(script.Parent.Troubles)
local Escalation = require(script.Parent.Escalation)
local Recall = require(script.Parent.Recall)
local Combat = require(script.Parent.Combat)
local Skyship = require(script.Parent.Skyship)
local Gear = require(script.Parent.Gear)
local Impact = require(script.Parent.Impact)
local Alerts = require(script.Parent.Alerts)
local Progress = require(script.Parent.Progress)

local Raid = {}
Raid.phase = "intermission"

local refs
local phaseEndsAt = 0
local lastCallSent = false
local rushSent = false

local function now()
	return workspace:GetServerTimeNow()
end

local function setPhase(phase, endsAt)
	Raid.phase = phase
	phaseEndsAt = endsAt
	workspace:SetAttribute("RaidPhase", phase)
	workspace:SetAttribute("PhaseEndsAt", endsAt)
end

local function stat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name)
end

function Raid.setupPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in ipairs({ "Gold", "Wins" }) do
		local value = leaderstats:FindFirstChild(name) or Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

-- Puts every system back to the start-of-raid state.
local function resetWorld()
	Poltergoblin.cancelAll()
	Loot.resetAll()
	Heat.reset()
	Threats.reset()
	Blast.reset()
	Troubles.reset()
	Navy.reset()
	Storms.reset()
	Escalation.reset()
	Destructibles.reset()
	Mechanisms.reset()
	Cannons.reset()
	Kegs.reset()
	Boats.reset()
	Recall.reset()
	Gear.reset()
	Impact.reset()
	Alerts.reset()
	Combat.reset()
	Coins.reset()
	Creatures.reset()
	Pursuit.reset()
	SeaMobs.reset()
end

function Raid.start()
	resetWorld()
	-- V7: the match starts aboard the skyship (nobody walks out of the cove). Anyone who is still at
	-- home (a late spawn, a death in the intermission) is put on the deck first.
	Skyship.boardAll()
	Progress.onRaidStart()
	for _, player in ipairs(Players:GetPlayers()) do
		local gold = stat(player, "Gold")
		if gold then
			gold.Value = 0
		end
	end
	lastCallSent = false
	rushSent = false
	setPhase("raid", now() + Config.RAID_DURATION)
	Loot.setEnabled(true)
	Skyship.open()
	Net.broadcast("RaidStart", { endsAt = phaseEndsAt })
end

function Raid.finish()
	Loot.setEnabled(false)
	local results = {}
	local best = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local gold = stat(player, "Gold")
		local value = gold and gold.Value or 0
		best = math.max(best, value)
		table.insert(results, { name = player.DisplayName, userId = player.UserId, gold = value })
	end
	table.sort(results, function(a, b)
		return a.gold > b.gold
	end)
	local winners = {}
	if best > 0 then
		for _, player in ipairs(Players:GetPlayers()) do
			local gold = stat(player, "Gold")
			if gold and gold.Value == best then
				local wins = stat(player, "Wins")
				if wins then
					wins.Value += 1
				end
				table.insert(winners, player.DisplayName)
			end
		end
	end
	-- What the goblins keep: Shinies, once each (Progress guards a second payout for the same raid).
	local awardList = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local gold = stat(player, "Gold")
		local value = gold and gold.Value or 0
		table.insert(awardList, { player = player, gold = value, won = best > 0 and value == best })
	end
	Progress.award(awardList)
	-- Loot still out there is lost; the world goes quiet until the next raid.
	resetWorld()
	setPhase("intermission", now() + Config.INTERMISSION)
	Skyship.reset()
	Skyship.boardAll() -- the intermission is spent on the deck, choosing where to land
	Net.broadcast("RaidEnd", { results = results, winners = winners, endsAt = phaseEndsAt })
end

function Raid.isActive()
	return Raid.phase == "raid"
end

function Raid.onBanked(item, player)
	local value = item.bankedValue or item.def.value
	if Raid.phase == "raid" and phaseEndsAt - now() <= Config.FINAL_RUSH then
		local rushed = math.floor(value * Config.FINAL_RUSH_MULT + 0.5)
		Net.feed(
			string.format("FINAL RUSH: +%d extra gold for %s.", rushed - value, player.DisplayName),
			Color3.fromRGB(255, 120, 70)
		)
		value = rushed
	end
	local gold = stat(player, "Gold")
	if gold then
		gold.Value += value
	end
	Net.broadcast("Banked", {
		name = player.DisplayName,
		userId = player.UserId,
		item = item.id,
		itemName = item.def.name,
		value = item.def.value,
		total = gold and gold.Value or item.def.value,
		position = refs.hoard.position,
	})
end

function Raid.tick()
	local t = now()
	if Raid.phase == "raid" then
		if not rushSent and phaseEndsAt - t <= Config.FINAL_RUSH then
			rushSent = true
			Net.message(
				string.format(
					"FINAL RUSH: BANKING PAYS %d%% MORE!",
					math.floor((Config.FINAL_RUSH_MULT - 1) * 100 + 0.5)
				),
				4,
				Color3.fromRGB(255, 120, 70)
			)
		end
		if not lastCallSent and phaseEndsAt - t <= Config.LAST_CALL then
			lastCallSent = true
			Net.broadcast("LastCall", { seconds = Config.LAST_CALL })
		end
		if t >= phaseEndsAt then
			Raid.finish()
		end
	elseif t >= phaseEndsAt then
		Raid.start()
	end
end

function Raid.init(worldRefs)
	refs = worldRefs
	setPhase("intermission", now() + Config.FIRST_INTERMISSION)
	Loot.setEnabled(false)
end

return Raid

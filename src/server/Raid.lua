-- The match: a timed raid, then a short intermission, forever.
-- During a raid, banked loot adds gold to your score. When time runs out, the
-- richest goblin wins, loot still out in the world is lost, and everything resets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Net = require(script.Parent.Net)
local Loot = require(script.Parent.Loot)
local Heat = require(script.Parent.Heat)
local Threats = require(script.Parent.Threats)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Boats = require(script.Parent.Boats)
local Blast = require(script.Parent.Blast)
local Destructibles = require(script.Parent.Destructibles)
local Mechanisms = require(script.Parent.Mechanisms)
local Cannons = require(script.Parent.Cannons)
local Kegs = require(script.Parent.Kegs)
local Navy = require(script.Parent.Navy)
local Storms = require(script.Parent.Storms)
local Troubles = require(script.Parent.Troubles)
local Escalation = require(script.Parent.Escalation)

local Raid = {}
Raid.phase = "intermission"

local refs
local phaseEndsAt = 0
local lastCallSent = false

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

-- Everyone back to the cove, off any boat seat.
local function teleportHome()
	for i, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = Util.aliveRoot(player)
		if root then
			local seat = humanoid.SeatPart
			if seat then
				local seatWeld = seat:FindFirstChild("SeatWeld")
				if seatWeld then
					seatWeld:Destroy()
				end
				humanoid.Sit = false
			end
			local points = refs.homePoints
			root.CFrame = points[(i - 1) % #points + 1]
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
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
end

function Raid.start()
	resetWorld()
	teleportHome()
	for _, player in ipairs(Players:GetPlayers()) do
		local gold = stat(player, "Gold")
		if gold then
			gold.Value = 0
		end
	end
	lastCallSent = false
	setPhase("raid", now() + Config.RAID_DURATION)
	Loot.setEnabled(true)
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
	-- Loot still out there is lost; the world goes quiet until the next raid.
	resetWorld()
	setPhase("intermission", now() + Config.INTERMISSION)
	Net.broadcast("RaidEnd", { results = results, winners = winners, endsAt = phaseEndsAt })
end

function Raid.isActive()
	return Raid.phase == "raid"
end

function Raid.onBanked(item, player)
	local value = item.bankedValue or item.def.value
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

-- The match (V13): the Goblin Port, then a raid, forever.
--
--   PORT     Config.PORT.DURATION (60 s) in the harbour town (server/Port.lua): results, shopping, pets, the
--            shipyard, spectating. Everyone aboard the Little Goblin's deck brings the raid forward; nobody in the
--            server holds it. Nobody has to ready up.
--   RAID     everyone in the Port goes aboard the skyship together: the launch window (Config.SKYSHIP.WINDOW), then
--            the six-minute clock (Config.RAID_DURATION). Banked loot adds gold to your score.
--   END      the richest goblin wins; loot still out in the world is lost; everything resets; everyone in the raid
--            comes home to the Port, the winners onto the podium.
--
-- Who is in the raid is explicit (`participants`): the goblins who were in the Port when it set off, plus anyone who
-- joined late from the Port while at least Config.PORT.LATE_JOIN_MIN was left (shared/Lobby.lua). Only they score,
-- earn the raid's Shinies, respawn at Goblin Cove when they die, and can be watched by spectators. A goblin who joins
-- the server mid-raid arrives in the Port.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Lobby = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Lobby"))
local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
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
local Tornadoes = require(script.Parent.Tornadoes)
local GhostFleet = require(script.Parent.GhostFleet)
local Emotes = require(script.Parent.Emotes)
local Port = require(script.Parent.Port)
local BoatAbilities = require(script.Parent.BoatAbilities)

local Raid = {}
Raid.phase = "port"

local refs
local phaseEndsAt = 0
local lastCallSent = false
local rushSent = false
local participants = {} -- player -> true: who is in the raid that is running
local nextHome = 0

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

function Raid.isParticipant(player)
	return participants[player] == true
end

local function participantList()
	local list = {}
	for player in pairs(participants) do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end
Raid.participants = participantList

local function count(set)
	local n = 0
	for player in pairs(set) do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function join(player)
	participants[player] = true
	player:SetAttribute("Zone", "raid")
	player:SetAttribute("InRaid", true)
	player:SetAttribute("Ready", nil)
	Port.stopSpectating(player, "joined")
	local gold = stat(player, "Gold")
	if gold then
		gold.Value = 0
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
	Recall.reset()
	Gear.reset()
	Impact.reset()
	Alerts.reset()
	Combat.reset()
	Coins.reset()
	Creatures.reset()
	Pursuit.reset()
	SeaMobs.reset()
	Tornadoes.reset()
	GhostFleet.reset()
	BoatAbilities.reset()
end

function Raid.start()
	resetWorld()
	table.clear(participants)
	-- Everyone in the server goes: the Port is a place to wait, not a menu to click through.
	local going = {}
	for _, player in ipairs(Players:GetPlayers()) do
		join(player)
		table.insert(going, player)
	end
	Port.stopAll("raid")
	lastCallSent = false
	rushSent = false
	-- V9: the six-minute clock starts when the launch window closes, so everyone gets all six minutes of play.
	local clockAt = now() + Config.SKYSHIP.WINDOW
	workspace:SetAttribute("RaidClockAt", clockAt)
	setPhase("raid", clockAt + Config.RAID_DURATION)
	Loot.setEnabled(true)
	Skyship.open()
	Skyship.boardList(going)
	Progress.onRaidStart(going)
	Net.broadcast("RaidStart", { endsAt = phaseEndsAt })
end

-- A goblin in the Port joins the raid that is running (shared/Lobby.canJoinLate says when). They go aboard the
-- skyship like everyone else did, with its deck grace (Config.SKYSHIP.MIN_DECK), and start with no gold.
function Raid.joinLate(player)
	local ok, reason = Lobby.canJoinLate(Raid.phase, now(), phaseEndsAt, participants[player] == true)
	if not ok then
		if reason == "late" then
			Net.toast(player, "Too little of this raid is left. Get ready for the next one!")
		elseif reason == "noraid" then
			Net.toast(player, "No raid is running: the next one leaves soon.")
		end
		return false
	end
	if not Util.aliveRoot(player) then
		return false
	end
	join(player)
	Progress.onRaidStart({ player }, true)
	Skyship.board(player)
	Net.feed(player.DisplayName .. " joined the raid!", Color3.fromRGB(255, 205, 50))
	Net.send(player, "RaidJoined", { endsAt = phaseEndsAt })
	return true
end

function Raid.finish()
	Loot.setEnabled(false)
	local raiders = participantList()
	local results = {}
	local best = 0
	for _, player in ipairs(raiders) do
		local gold = stat(player, "Gold")
		local value = gold and gold.Value or 0
		best = math.max(best, value)
		table.insert(results, { name = player.DisplayName, userId = player.UserId, gold = value })
	end
	table.sort(results, function(a, b)
		return a.gold > b.gold
	end)
	local winners = {}
	local champions = {}
	if best > 0 then
		for _, player in ipairs(raiders) do
			local gold = stat(player, "Gold")
			if gold and gold.Value == best then
				local wins = stat(player, "Wins")
				if wins then
					wins.Value += 1
				end
				table.insert(winners, player.DisplayName)
				table.insert(champions, player)
			end
		end
	end
	-- What the goblins keep: Shinies, once each (Progress guards a second payout for the same raid).
	local places = {}
	for index, entry in ipairs(results) do
		places[entry.userId] = index
	end
	local awardList = {}
	for _, player in ipairs(raiders) do
		local gold = stat(player, "Gold")
		local value = gold and gold.Value or 0
		local won = best > 0 and value == best
		table.insert(awardList, { player = player, gold = value, won = won, place = places[player.UserId] })
	end
	Progress.award(awardList)
	-- Loot still out there is lost; the world goes quiet until the next raid.
	resetWorld()
	setPhase("port", now() + Config.PORT.DURATION)
	workspace:SetAttribute("RaidClockAt", nil)
	Skyship.reset()
	Port.stopAll("ended")
	-- Everyone comes home: the winners onto the podium, the rest round the fountain.
	local isChampion = {}
	for _, player in ipairs(champions) do
		isChampion[player] = true
	end
	Port.arriveWinners(champions)
	for _, player in ipairs(raiders) do
		if not isChampion[player] then
			Port.arrive(player)
		end
	end
	if #champions > 0 then
		Port.setChampion(champions[1], best)
	end
	for _, player in ipairs(raiders) do
		player:SetAttribute("InRaid", nil)
	end
	table.clear(participants)
	Net.broadcast("RaidEnd", { results = results, winners = winners, endsAt = phaseEndsAt })
	-- V11: the winner dances (V13: on the podium, once they have arrived and are standing on it).
	for _, champion in ipairs(champions) do
		task.delay(Config.PORT.ARRIVE_GRACE + Config.PORT.PODIUM_DANCE, Emotes.celebrate, champion)
	end
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
		value = value, -- V12: what was paid (interest and the final rush included); V11 sent the base value
		total = gold and gold.Value or item.def.value,
		position = refs.hoard.position,
	})
end

-- Where a goblin's new body goes (Main calls this for every spawn: a join, a respawn, a reset).
--   in the raid, launch window still open   aboard the skyship
--   in the raid, after the window           home, at Goblin Cove (death sends you home, as it always has)
--   anyone else                             the Port
function Raid.placeCharacter(player)
	if Raid.phase == "raid" and participants[player] then
		player:SetAttribute("Zone", "raid")
		if Skyship.isDeploying() then
			Skyship.board(player)
			return
		end
		local points = refs.homePoints
		local root = Util.aliveRoot(player)
		if root and points and #points > 0 then
			nextHome = nextHome % #points + 1
			local spot = points[nextHome]
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(spot.Position, 3)
				end)
				if root.Parent then
					player.Character:PivotTo(spot)
				end
			end)
		end
		return
	end
	Port.arrive(player)
end

function Raid.forget(player)
	participants[player] = nil
end

-- For the Port's screen: how many goblins are aboard the Little Goblin, and how many are in the Port at all.
local function readiness()
	local inPort, ready = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if not participants[player] and Util.aliveRoot(player) then
			inPort += 1
			local isReady = Port.isReady(player)
			if isReady then
				ready += 1
			end
			if (player:GetAttribute("Ready") == true) ~= isReady then
				player:SetAttribute("Ready", isReady or nil)
			end
		end
	end
	return inPort, ready
end

local nextReadyCheck = 0
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
		if t >= phaseEndsAt or Lobby.raidAbandoned(count(participants)) then
			Raid.finish()
		end
	else
		if t >= nextReadyCheck then
			nextReadyCheck = t + 0.25
			local inPort, ready = readiness()
			local before = phaseEndsAt
			local after = Lobby.portEndsAt(t, phaseEndsAt, inPort, ready, #Players:GetPlayers())
			if math.abs(after - before) > 0.05 then
				phaseEndsAt = after
				workspace:SetAttribute("PhaseEndsAt", after)
			end
			workspace:SetAttribute("PortReady", ready)
			workspace:SetAttribute("PortCount", inPort)
		end
		if t >= phaseEndsAt and #Players:GetPlayers() > 0 then
			Raid.start()
		end
	end
	Port.tick()
end

function Raid.init(worldRefs)
	refs = worldRefs
	-- Studio test hook: workspace attribute DevPortSeconds shortens the Port's countdown (never set in a live game).
	setPhase("port", now() + Config.PORT.DURATION)
	Loot.setEnabled(false)
	Port.inRaid = Raid.isParticipant
	workspace:GetAttributeChangedSignal("DevPortSeconds"):Connect(function()
		local seconds = workspace:GetAttribute("DevPortSeconds")
		if game:GetService("RunService"):IsStudio() and Raid.phase == "port" and type(seconds) == "number" then
			setPhase("port", now() + math.max(1, seconds))
		end
	end)
end

return Raid

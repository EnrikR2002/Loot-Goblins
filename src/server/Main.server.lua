-- Loot Goblins server entry point. Builds the world, wires the modules
-- together and runs one Heartbeat. Each module's header explains its rules.
--
--   Net          remotes + the GameEvent broadcast channel
--   World        the map: home, the old islands (World.lua, WorldKit.lua) and the new ones
--                (Islands.lua, IslandsFar.lua); it only DESCRIBES mechanisms in `refs`
--   Sea          waves, currents and storm influence as pure functions
--   SeaNav       the sea grid: shelter from coasts, and routes for ships
--   Boats        physics boats floating on the Sea functions
--   Loot         the valuables: possession, throwing, banking, respawn, interest
--   Heat         the shared trouble meter
--   Escalation   what each Heat tier does to the world
--   Threats      Guardian, totems, item trouble, carrier reveal
--   Troubles     what each treasure does when it is taken
--   Navy         AI patrol ships that hunt carriers
--   Storms       weather cells and lightning
--   Blast        every explosion goes through here
--   Destructibles, Cannons, Kegs, Mechanisms   the interactive island pieces
--   Combat       sword and grapple
--   Poltergoblin the spirit ability (was Soul Unbound / Yone's E)
--   Movement     WalkSpeed from carrying, sprint + stamina, water and spirit form
--   Raid         timer, scoring, intermission, world reset
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Nobody spawns until the world exists; the map takes a moment to build.
Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local Movement = require(script.Parent.Movement)
local World = require(script.Parent.World)
local SeaNav = require(script.Parent.SeaNav)
local Boats = require(script.Parent.Boats)
local Loot = require(script.Parent.Loot)
local Heat = require(script.Parent.Heat)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Combat = require(script.Parent.Combat)
local Destructibles = require(script.Parent.Destructibles)
local Cannons = require(script.Parent.Cannons)
local Kegs = require(script.Parent.Kegs)
local Mechanisms = require(script.Parent.Mechanisms)
local Threats = require(script.Parent.Threats)
local Storms = require(script.Parent.Storms)
local Navy = require(script.Parent.Navy)
local Troubles = require(script.Parent.Troubles)
local Escalation = require(script.Parent.Escalation)
local Raid = require(script.Parent.Raid)

Players.RespawnTime = Config.RESPAWN_TIME
StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED
-- Shift sprints, so it can't also toggle Roblox's shift lock.
StarterPlayer.EnableMouseLockOption = false

local refs = World.build()
SeaNav.build(refs)
Boats.build(refs)
Loot.build(refs)
Poltergoblin.init(refs)
Destructibles.build(refs)
Cannons.build(refs)
Kegs.build(refs)
Mechanisms.build(refs)
Threats.build(refs)
Navy.build(refs)
Troubles.build(refs)
Escalation.build(refs)
Combat.init(refs)
Raid.init(refs)
Storms.reset()

-- Spirits can't bank; the Hoard's ward also pulls them back before they reach it.
Loot.canBank = function(player)
	return not Poltergoblin.isSpirit(player)
end

-- What happened to the loot, told to everyone ----------------------------------------
Loot.Taken:Connect(function(item, player, fromSpot, fromPlayer)
	local def = item.def
	if fromSpot then
		Heat.add(def.heat)
		Net.broadcast("Stolen", {
			name = player.DisplayName,
			userId = player.UserId,
			item = item.id,
			itemName = def.name,
			value = Loot.valueOf(item),
			position = item.spot.Position,
		})
		Net.feed(player.DisplayName .. " stole the " .. def.name .. " (+" .. def.heat .. " heat)", def.color)
		Threats.onTaken(item, player)
	elseif fromPlayer then
		Net.broadcast(
			"Snatched",
			{ name = player.DisplayName, userId = player.UserId, from = fromPlayer.DisplayName, itemName = def.name }
		)
		Net.feed(
			player.DisplayName .. " grappled the " .. def.name .. " from " .. fromPlayer.DisplayName .. "!",
			def.color
		)
	else
		Net.broadcast("Grabbed", { name = player.DisplayName, userId = player.UserId, itemName = def.name })
		Net.feed(player.DisplayName .. " grabbed the " .. def.name, def.color)
	end
end)

local LOOSE_TEXT = {
	throw = "%s threw the %s",
	sword = "%s smacked the %s out of %s's hands!",
	guardian = "The Guardian smashed the %s out of %s's hands!",
	boulder = "%s got flattened and dropped the %s!",
	cannon = "%s was blasted and dropped the %s!",
	keg = "%s got kegged and dropped the %s!",
	lava = "%s burned and dropped the %s!",
	lightning = "%s was struck by lightning and dropped the %s!",
	death = "%s died and dropped the %s",
	shatter = "%s's spirit was shattered and dropped the %s",
	left = "%s left and dropped the %s",
}

Loot.Loosened:Connect(function(item, reason, byPlayer, fromPlayer)
	local def = item.def
	local holder = fromPlayer and fromPlayer.DisplayName or "Someone"
	local text
	if reason == "throw" then
		text = string.format(LOOSE_TEXT.throw, holder, def.name)
	elseif reason == "sword" then
		text = string.format(LOOSE_TEXT.sword, byPlayer and byPlayer.DisplayName or "Someone", def.name, holder)
	elseif reason == "guardian" then
		text = string.format(LOOSE_TEXT.guardian, def.name, holder)
	else
		text = string.format(LOOSE_TEXT[reason] or "%s dropped the %s", holder, def.name)
	end
	Net.feed(text, def.color)
	Net.broadcast("LootLoose", { item = item.id, position = item.core.Position, reason = reason })
end)

Loot.Returned:Connect(function(item, reason)
	local def = item.def
	if reason == "respawn" then
		Net.feed("The " .. def.name .. " is back at " .. def.place .. ".", def.color)
	else
		Net.feed("The " .. def.name .. " vanished back to " .. def.place .. ".", def.color)
	end
end)

Loot.Banked:Connect(function(item, player)
	Raid.onBanked(item, player)
	Net.feed(
		player.DisplayName
			.. " banked the "
			.. item.def.name
			.. " (+"
			.. (item.bankedValue or item.def.value)
			.. " gold)",
		item.def.color
	)
end)

-- Players ----------------------------------------------------------------------------
local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Config.WALK_SPEED
	Movement.refill(player)
	Kegs.refill(player)
	Combat.giveSword(player, character)
	humanoid.Died:Connect(function()
		Loot.dropFor(player, "death")
		Poltergoblin.finish(player, "death")
	end)
end

local function setupPlayer(player)
	-- EnableMouseLockOption only reaches players who join after it is set.
	player.DevEnableMouseLock = false
	Raid.setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		Loot.dropFor(player, "death")
		Poltergoblin.finish(player, "cancel")
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	Loot.forget(player)
	Poltergoblin.forget(player)
	Movement.forget(player)
	Combat.forget(player)
	Kegs.forget(player)
	Mechanisms.forget(player)
end)

Net.Throw.OnServerEvent:Connect(function(player)
	Loot.throw(player)
end)
Net.Poltergoblin.OnServerEvent:Connect(function(player)
	Poltergoblin.request(player)
end)
Net.Sprint.OnServerEvent:Connect(function(player, held)
	Movement.setSprintHeld(player, held == true)
end)
Net.BoatBoost.OnServerEvent:Connect(function(player)
	Boats.boost(player)
end)

-- The world is ready: let everyone in (and put anyone who joined early at the spawn).
Players.CharacterAutoLoads = true
for _, player in ipairs(Players:GetPlayers()) do
	player:LoadCharacter()
end

-- Main loop --------------------------------------------------------------------------
local function carriersOutsideWard()
	local count = 0
	for _, carrier in ipairs(Loot.carriers()) do
		if Util.flatDistance(carrier.root.Position, refs.hoard.position) > Config.WARD_RADIUS then
			count += 1
		end
	end
	return count
end

RunService.Heartbeat:Connect(function(dt)
	local active = Raid.isActive()
	Boats.tick(dt)
	if active then
		Loot.tick()
		Heat.tick(dt, carriersOutsideWard())
		Threats.tick(dt)
		Navy.tick()
		Escalation.tick()
	end
	Storms.tick(dt, active)
	Cannons.tick(dt)
	Kegs.tick()
	Mechanisms.tick(dt)
	Poltergoblin.tick()
	Movement.tick(dt)
	Raid.tick()
end)

-- Loot Goblins server entry point. Builds the world, wires the modules
-- together and runs one Heartbeat. Each module's header explains its rules.
--
--   Net          remotes + the GameEvent broadcast channel
--   World        the map (terrain, landmarks, routes) and named references
--   Loot         the valuables: possession, throwing, banking, respawn
--   Heat         the shared trouble meter
--   Threats      Guardian, totems, item trouble, carrier reveal
--   Combat       sword and grapple
--   Poltergoblin the spirit ability (was Soul Unbound / Yone's E)
--   Movement     WalkSpeed from carrying, water and spirit form
--   Boats        the kinematic boats
--   Raid         timer, scoring, intermission, world reset
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LootGoblins"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local Movement = require(script.Parent.Movement)
local World = require(script.Parent.World)
local Boats = require(script.Parent.Boats)
local Loot = require(script.Parent.Loot)
local Heat = require(script.Parent.Heat)
local Poltergoblin = require(script.Parent.Poltergoblin)
local Combat = require(script.Parent.Combat)
local Threats = require(script.Parent.Threats)
local Raid = require(script.Parent.Raid)

Players.RespawnTime = Config.RESPAWN_TIME
StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED

local refs = World.build()
Boats.build(refs)
Loot.build(refs)
Poltergoblin.init(refs)
Threats.build(refs)
Combat.init(refs)
Raid.init(refs)

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
			value = def.value,
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
		player.DisplayName .. " banked the " .. item.def.name .. " (+" .. item.def.value .. " gold)",
		item.def.color
	)
end)

-- Players ----------------------------------------------------------------------------
local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Config.WALK_SPEED
	Combat.giveSword(player, character)
	humanoid.Died:Connect(function()
		Loot.dropFor(player, "death")
		Poltergoblin.finish(player, "death")
	end)
end

local function setupPlayer(player)
	Raid.setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	-- The world takes a moment to build; someone may have spawned already.
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
end)

Net.Throw.OnServerEvent:Connect(function(player)
	Loot.throw(player)
end)
Net.Poltergoblin.OnServerEvent:Connect(function(player)
	Poltergoblin.request(player)
end)

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
	Boats.tick(dt)
	if Raid.isActive() then
		Loot.tick()
		Heat.tick(dt, carriersOutsideWard())
		Threats.tick(dt)
	end
	Poltergoblin.tick()
	Movement.tick()
	Raid.tick()
end)

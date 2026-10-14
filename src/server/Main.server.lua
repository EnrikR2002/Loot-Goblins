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
local Coins = require(script.Parent.Coins)
local Recall = require(script.Parent.Recall)
local Skyship = require(script.Parent.Skyship)
local Flight = require(script.Parent.Flight)
local Gear = require(script.Parent.Gear)
local Impact = require(script.Parent.Impact)
local Alerts = require(script.Parent.Alerts)
local Progress = require(script.Parent.Progress)
local Monetization = require(script.Parent.Monetization)
local Creatures = require(script.Parent.Creatures)
local Pursuit = require(script.Parent.Pursuit)
local Leviathan = require(script.Parent.Leviathan)
local SeaMobs = require(script.Parent.SeaMobs)
require(script.Parent.Bestiary)
require(script.Parent.BestiaryMinor)
local Raid = require(script.Parent.Raid)

Players.RespawnTime = Config.RESPAWN_TIME
StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED
StarterPlayer.CharacterUseJumpPower = true
StarterPlayer.CharacterJumpPower = Config.JUMP_POWER
-- Shift sprints, so it can't also toggle Roblox's shift lock.
StarterPlayer.EnableMouseLockOption = false

-- The world is big: say how long it took, so a slow start-up is noticed when it creeps in.
local startedAt = os.clock()
local refs = World.build()
local worldSeconds = os.clock() - startedAt
local seaGrid = SeaNav.build(refs)
print(
	string.format(
		"[LootGoblins] world built in %.1f s (%s), sea grid in %.1f s (%d cells, %d land, %d probes)",
		worldSeconds,
		refs.buildTimings or "",
		os.clock() - startedAt - worldSeconds,
		seaGrid.cells,
		seaGrid.land,
		seaGrid.probes
	)
)
Boats.build(refs)
Skyship.build(refs)
Flight.build(refs, Skyship.model())
Gear.build(refs)
Loot.build(refs)
Poltergoblin.init(refs)
Destructibles.build(refs)
Cannons.build(refs)
Kegs.build(refs)
Mechanisms.build(refs)
Coins.build(refs)
Threats.build(refs)
Storms.build(refs)
Navy.build(refs)
Troubles.build(refs)
Escalation.build(refs)
Creatures.build(refs)
Pursuit.build(refs)
SeaMobs.build(refs)
Combat.init(refs)
Raid.init(refs)
Progress.init()
Monetization.init()
Storms.reset()

-- Salvage: a crate floats where a patrol ship went down, and where a storm blew itself out.
Boats.Sunk:Connect(function(boat)
	if boat.typeName == "navy" then
		Coins.dropSalvage(boat.hull.Position, "a patrol ship went down")
	end
end)
Storms.Spent:Connect(function(x, z)
	Coins.dropSalvage(Vector3.new(x, 0, z), "a storm blew itself out")
end)

-- A lit signal beacon turns the patrol ships that can see it.
Mechanisms.BeaconLit:Connect(function(beacon, player)
	local turned = Navy.distract(beacon.position)
	local name = beacon.name or "the sea"
	if turned > 0 then
		Net.message(
			"A SIGNAL FIRE AT " .. string.upper(name) .. ": THE PATROL TURNS TO LOOK!",
			3.5,
			Color3.fromRGB(255, 170, 70)
		)
	end
	Net.feed(
		player.DisplayName
			.. " lit the beacon at "
			.. name
			.. (
				turned > 0
					and (": " .. turned .. " patrol ship" .. (turned > 1 and "s go" or " goes") .. " to look")
				or ""
			),
		Color3.fromRGB(255, 170, 70)
	)
end)

for _, warning in ipairs(refs.buildWarnings or {}) do
	warn("[LootGoblins] world: " .. warning)
end

-- Spirits can't bank; the Hoard's ward also pulls them back before they reach it.
Loot.canBank = function(player)
	return not Poltergoblin.isSpirit(player)
end

-- What happened to the loot, told to everyone ----------------------------------------
Loot.Taken:Connect(function(item, player, fromSpot, fromPlayer)
	local def = item.def
	Creatures.onTaken(item, player, fromSpot)
	if fromSpot then
		Alerts.stolen(def.island, player)
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
			player.DisplayName .. " snatched the " .. def.name .. " from " .. fromPlayer.DisplayName .. "!",
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
	guardianleap = "The Guardian LANDED on the %s: %s dropped it!",
	boulder = "%s got flattened and dropped the %s!",
	cannon = "%s was blasted and dropped the %s!",
	keg = "%s got kegged and dropped the %s!",
	lava = "%s burned and dropped the %s!",
	lightning = "%s was struck by lightning and dropped the %s!",
	death = "%s died and dropped the %s",
	watcher = "A Watcher caught %s: the %s is on the ground!",
	echo = "%s ran into an Echo and dropped the %s!",
	crab = "Old Clacker came up under %s: the %s went flying!",
	ram = "Bramble tossed %s and the %s!",
	eel = "The Warden eel shocked %s: the %s is in the water!",
	imp = "An imp snatched the %s!",
	marine = "The Garrison threw %s out: the %s stayed behind!",
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
	elseif reason == "guardian" or reason == "guardianleap" then
		text = string.format(LOOSE_TEXT.guardian, def.name, holder)
	elseif reason == "imp" then
		text = string.format(LOOSE_TEXT.imp, def.name)
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
	elseif string.sub(reason, 1, 6) == "taken:" then
		-- A creature put it back (Creatures.lua).
		Net.feed(string.sub(reason, 7) .. " put the " .. def.name .. " back at " .. def.place .. ".", def.color)
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
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JUMP_POWER
	Movement.refill(player)
	Kegs.refill(player)
	Combat.standUp(player, 0) -- a new body starts on its feet
	Skyship.onCharacter(player)
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
	Coins.forget(player)
	Recall.forget(player)
	Skyship.forget(player)
	Impact.forget(player)
	Progress.forget(player)
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
Net.Move.OnServerEvent:Connect(function(player, kind)
	if kind == "dash" or kind == "airjump" then
		Movement.request(player, kind)
	elseif kind == "getup" then
		Combat.getUp(player)
	end
end)
Net.BoatBoost.OnServerEvent:Connect(function(player)
	Boats.boost(player)
end)
Net.BoatDrift.OnServerEvent:Connect(function(player, held)
	Boats.setDrift(player, held == true)
end)
-- A grapple reeled the player onto a boat: give them a seat. Only the boat the server itself
-- hooked for them a moment ago counts (Combat.hookedBoat); nothing the client says is used.
Net.BoatBoard.OnServerEvent:Connect(function(player)
	local boat = Combat.hookedBoat(player)
	if boat then
		Boats.board(boat, player, Config.GRAPPLE_PULL_RANGE)
	end
end)
Net.BoatFx.OnServerEvent:Connect(function(player, kind)
	if kind == "mini1" or kind == "mini2" or kind == "landing" or kind == "jump" or kind == "super" then
		Boats.relayFx(player, kind)
	end
end)
Net.Deploy.OnServerEvent:Connect(function(player, action, a)
	-- V8: a launcher is aimed at a PLACE (the server works out the throw); see Flight.lua.
	if action == "choose" then
		Skyship.choose(player, a)
	elseif action == "aim" then
		Flight.aim(player, a)
	elseif action == "fire" then
		Flight.fire(player)
	elseif action == "leave" then
		Flight.leave(player)
	elseif action == "mode" then
		Flight.setMode(player, a)
	end
end)
Net.Shop.OnServerEvent:Connect(function(player, action, id)
	if action == "robux" then
		Monetization.prompt(player, id)
	else
		Progress.handle(player, action, id)
	end
end)
Net.Steal.OnServerEvent:Connect(function(player, target)
	Combat.stealFrom(player, target)
end)
Net.BoatJump.OnServerEvent:Connect(function(player)
	Boats.jump(player)
end)
Net.BoatRecall.OnServerEvent:Connect(function(player)
	Recall.request(player)
end)

-- The world is ready: let everyone in (and put anyone who joined early at the spawn).
Players.CharacterAutoLoads = true
for _, player in ipairs(Players:GetPlayers()) do
	player:LoadCharacter()
end

-- The far islands' silhouettes are only scenery, so they are made now, a little each frame.
task.spawn(function()
	local horizonStarted = os.clock()
	local blocks = World.buildHorizon()
	print(string.format("[LootGoblins] horizon ready: %d blocks in %.0f s", blocks, os.clock() - horizonStarted))
end)

-- Main loop --------------------------------------------------------------------------
-- Heat per second from carriers outside the ward, weighted by how hot each treasure is.
local function carryHeatRate()
	local rate = 0
	for _, carrier in ipairs(Loot.carriers()) do
		if Util.flatDistance(carrier.root.Position, refs.hoard.position) > Config.WARD_RADIUS then
			rate += Config.HEAT_CARRY_RATE * math.clamp(carrier.item.def.heat / 25, 0.25, 2)
		end
	end
	return rate
end

RunService.Heartbeat:Connect(function(dt)
	local active = Raid.isActive()
	Boats.tick(dt)
	Recall.tick()
	Skyship.tick(dt)
	Flight.tick(dt)
	Pursuit.tick(dt)
	SeaMobs.tick(dt)
	Progress.tick(dt, active)
	if active then
		Loot.tick()
		Heat.tick(dt, carryHeatRate())
		Threats.tick(dt)
		Navy.tick()
		Escalation.tick()
		Alerts.tick(dt)
	end
	Storms.tick(dt, active)
	Cannons.tick(dt)
	Kegs.tick()
	Mechanisms.tick(dt)
	Coins.tick(dt, active)
	Creatures.tick(dt)
	Leviathan.tick(dt) -- after the creatures: the Sleeper drives it when awake, this only fills in when it is not
	Poltergoblin.tick()
	Movement.tick(dt)
	Raid.tick()
end)

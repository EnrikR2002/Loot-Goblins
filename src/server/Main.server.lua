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
--   Movement     WalkSpeed from carrying, water and spirit form (V13.2: the base momentum multiplies), stamina
--   Raid         timer, scoring, who is in the raid, world reset
--   Port         the Goblin Port between raids: arrivals, readiness, the champion, spectating (V13)
--   BoatAbilities  each boat class's own ability, validated (V13)
--   WorldChaos   one physical chaos event per raid, played in episodes (V13.2)
--   Raid sign-up the Port's JOIN / STAY IN PORT / AUTO-JOIN and the raid's LEAVE (V13.2: RaidRequest)
--   V13.3, THE LIVING PORT:
--   Minigames    the framework for the Port's games (Regatta, Gauntlet, CannonGolf: one module each; V13.5 removed
--                the Pet Derby, Treasure Toss, the Target Gallery and Crab Chaos)
--   Quests       the Captain's Quest Board (daily and weekly quests)
--   Leaderboards weekly and monthly boards, the Hall of Records, season rewards
--   Sanctuary    every goblin's floating pet isle and pet expeditions
--   Challenges   one-on-one challenges to a Port game
--   Prospects    the "what's next" card after a raid
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
local Emotes = require(script.Parent.Emotes)
local Creatures = require(script.Parent.Creatures)
local Pursuit = require(script.Parent.Pursuit)
local Leviathan = require(script.Parent.Leviathan)
local SeaMobs = require(script.Parent.SeaMobs)
local Tornadoes = require(script.Parent.Tornadoes)
local GhostFleet = require(script.Parent.GhostFleet)
local GoblinLook = require(script.Parent.GoblinLook)
local Port = require(script.Parent.Port)
local BoatAbilities = require(script.Parent.BoatAbilities)
local Knockout = require(script.Parent.Knockout)
local WorldChaos = require(script.Parent.WorldChaos)
local WorldKit = require(script.Parent.WorldKit)
-- V13.3: the Living Port.
local Minigames = require(script.Parent.Minigames)
local PortGames = require(ReplicatedStorage.LootGoblins:WaitForChild("PortGames"))
local Regatta = require(script.Parent.Regatta)
local Quests = require(script.Parent.Quests)
local Leaderboards = require(script.Parent.Leaderboards)
local Sanctuary = require(script.Parent.Sanctuary)
local Challenges = require(script.Parent.Challenges)
local Prospects = require(script.Parent.Prospects)
require(script.Parent.Bestiary)
require(script.Parent.BestiaryMinor)
local Raid = require(script.Parent.Raid)
local ProximityPromptService = game:GetService("ProximityPromptService")

Players.RespawnTime = Config.RESPAWN_TIME
StarterPlayer.CharacterWalkSpeed = Config.WALK_SPEED
StarterPlayer.CharacterUseJumpPower = true
StarterPlayer.CharacterJumpPower = Config.JUMP_POWER
-- Shift boosts a boat and dashes on foot (V13.2; it sprinted until then), so it can't also toggle Roblox's shift lock.
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
-- V13.3: the Regatta's hoops and ramps are boat gates, so they exist before Boats.build sends every client the list.
Regatta.addGates(WorldKit)
Boats.build(refs)
-- V13: the Goblin Port, where every goblin arrives and waits between raids (its slipways show every boat class).
Port.build(refs, Boats.displayModel)
-- V13.3: the Port's games, the Quest Board, the Hall of Records and the sanctuaries (each builds its own corner of town).
for _, name in ipairs({ "Regatta", "Gauntlet", "CannonGolf" }) do
	Minigames.register(require(script.Parent[name]))
end
Minigames.build(Port.kit)
refs.spawn.Enabled = false -- Goblin Cove's pad is no longer where goblins appear: the Port's is (Raid.placeCharacter)
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
GhostFleet.build()
SeaMobs.build(refs)
Tornadoes.build(refs)
Combat.init(refs)
WorldChaos.init(refs) -- V13.2 (before Raid: the Port shows the next raid's chaos the moment it opens)
Raid.init(refs)
BoatAbilities.init(refs)
Progress.participating = Raid.isParticipant
-- V13.3 (registered before Progress opens anyone's profile, so their first publish already includes the Port's parts).
Minigames.reward = Progress.onPortGame
Minigames.bestOf = function(player, gameId, class) -- V13.4: shown on the play panel as the score to beat
	local s = Progress.session(player)
	return s and s.profile.games.best[PortGames.recordKey(gameId, class)] or nil -- V13.5: a Regatta best is per boat
end
Quests.init(Port.kit)
Leaderboards.init(Port.kit)
Sanctuary.init(Port.kit)
task.spawn(Port.curate) -- V13.5: the curated Port's furniture, after every building it must keep off (it waits a frame)
Challenges.init()
Prospects.init()
Raid.onDeparting = function(players)
	Minigames.leaveAll(players, "raid")
end
-- The world's chaos throwing a goblin about counts toward the chaos quests (once every few seconds at most).
local tossedAt = setmetatable({}, { __mode = "k" })
WorldChaos.Tossed:Connect(function(player)
	local t = os.clock()
	if t - (tossedAt[player] or 0) >= 4 then
		tossedAt[player] = t
		Progress.record(player, "chaos")
	end
end)
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

-- V13: a goblin at home (the Hoard's ward) or in the Port is out of reach of other goblins' boat guns.
local Lobby = require(ReplicatedStorage.LootGoblins.Lobby)
local Blast = require(script.Parent.Blast)
Blast.safe = function(position)
	return Lobby.inPort(position) or Util.flatDistance(position, refs.hoard.position) <= Config.WARD_RADIUS
end
-- V13.2: no bow gun fires from there, and no boat ability acts there (a little wider: the docks are busy). V13.5: except
-- on the Regatta's water, where a test drive plays its boat's ability for real (the race is the only thing out there).
Cannons.inSafeZone = Blast.safe
BoatAbilities.safe = function(position)
	if Lobby.inPort(position) then
		return not PortGames.onRegatta(position)
	end
	return Util.flatDistance(position, refs.hoard.position) <= Config.WARD_RADIUS + 60
end

-- Spirits can't bank; the Hoard's ward also pulls them back before they reach it.
Loot.canBank = function(player)
	return not Poltergoblin.isSpirit(player)
end

-- What happened to the loot, told to everyone ----------------------------------------
Loot.Taken:Connect(function(item, player, fromSpot, fromPlayer)
	local def = item.def
	Creatures.onTaken(item, player, fromSpot)
	if fromPlayer then
		Progress.onSnatch(player) -- V11: the Sticky Fingers trophy
	end
	if fromSpot then
		Progress.onSteal(player) -- V13: a deed, and the Light Fingers trophy
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
	boarded = "%s was BOARDED and the %s went over the side!", -- V13.2: a Corsair's boarding hook
	sword = "%s smacked the %s out of %s's hands!",
	guardian = "The Guardian smashed the %s out of %s's hands!",
	guardianleap = "The Guardian LANDED on the %s: %s dropped it!",
	boulder = "%s got flattened and dropped the %s!",
	cannon = "%s was blasted and dropped the %s!",
	keg = "%s got kegged and dropped the %s!",
	lava = "%s burned and dropped the %s!",
	lightning = "%s was struck by lightning and dropped the %s!",
	death = "%s died and dropped the %s",
	knockout = "%s was KNOCKED OUT and dropped the %s!", -- V13.1: the only way the world takes treasure
	reset = "%s reset and dropped the %s",
	lost = "%s fell out of the world and dropped the %s",
	watcher = "A Watcher caught %s: the %s is on the ground!",
	echo = "%s ran into an Echo and dropped the %s!",
	crab = "Old Clacker came up under %s: the %s went flying!",
	ram = "Bramble tossed %s and the %s!",
	eel = "The Warden eel shocked %s: the %s is in the water!",
	marine = "The Garrison threw %s out: the %s stayed behind!",
	shatter = "%s's spirit was shattered and dropped the %s",
	leviathan = "The Leviathan caught %s: the %s went flying!",
	ghost = "A ghost pirate wrenched the %s out of %s's hands!",
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
	elseif reason == "ghost" then
		text = string.format(LOOSE_TEXT.ghost, def.name, holder)
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

-- V13: getting away from a pursuer to the sanctuary pays a deed and counts toward that island's pet.
Pursuit.Escaped:Connect(function(player, islandId)
	if player.Parent then
		Progress.onEscape(player, islandId)
	end
end)

Loot.Banked:Connect(function(item, player)
	Raid.onBanked(item, player)
	-- V11: lasting stats and trophies; V13: and which class of boat brought it home.
	Progress.onBanked(player, item.def.id, item.bankedValue or item.def.value, Boats.lastRide(player, 25))
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
	-- V13: the skyship (in the raid, during its launch window), Goblin Cove (in the raid, later) or the Port.
	task.defer(function()
		if player.Parent and player.Character == character then
			Raid.placeCharacter(player)
		end
	end)
	Combat.giveSword(player, character)
	-- V11: dressed at once, again when the avatar's appearance has loaded (GoblinLook.watch) and once more 2 s later
	-- (appearance loading can replace the head and colours just after spawning; dressing again is cheap and idempotent).
	task.defer(GoblinLook.apply, player, character)
	task.delay(2, GoblinLook.apply, player, character)
	-- V13.1: health 0 is a knockout, not a death (server/Knockout.lua). Died only fires if Roblox kills the body
	-- some other way; it is still covered.
	Knockout.watch(player, character, humanoid)
	humanoid.Died:Connect(function()
		Loot.dropFor(player, "death")
		Poltergoblin.finish(player, "death")
	end)
end

local function setupPlayer(player)
	-- EnableMouseLockOption only reaches players who join after it is set.
	player.DevEnableMouseLock = false
	Raid.setupPlayer(player)
	GoblinLook.watch(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterRemoving:Connect(function()
		Loot.dropFor(player, "death")
		Poltergoblin.finish(player, "cancel")
		Minigames.leave(player, "reset") -- V13.3: a new body is a new start (a reset ends a Port game)
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
	Pursuit.forget(player)
	GhostFleet.forget(player)
	Tornadoes.forget(player)
	Raid.forget(player)
	Port.forget(player)
	BoatAbilities.forget(player)
	Boats.forgetRider(player)
	Knockout.forget(player)
	task.spawn(Progress.forget, player) -- saves and releases the profile (it yields)
end)
Knockout.KnockedOut:Connect(function(player)
	Poltergoblin.finish(player, "death")
	Combat.cancelDown(player) -- a grapple catch is overtaken by the knockout
end)
Net.Reset.OnServerEvent:Connect(function(player)
	Knockout.respawn(player, "reset")
end)

-- V13: the Port. Its screen's buttons and its prompts (the Spyglass, the pier's "join the raid").
local portAsks = setmetatable({}, { __mode = "k" }) -- player -> when they last asked (a few a second at most)
Net.Port.OnServerEvent:Connect(function(player, action, a, b)
	local t = os.clock()
	if t - (portAsks[player] or 0) < 0.2 then
		return
	end
	portAsks[player] = t
	if action == "join" then
		Raid.joinLate(player)
	elseif action == "spectate" and (a == "start" or a == "next" or a == "back" or a == "stop") then
		Port.spectate(player, a, type(b) == "number" and b or nil)
	end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local action = prompt:GetAttribute("PortAction")
	if action == "join" then
		Raid.joinLate(player)
	elseif action == "spectate" then
		Port.spectate(player, "start")
	end
end)
-- V13.2: signing up for the next raid, and leaving a running one.
local raidAsks = setmetatable({}, { __mode = "k" })
Net.Raid.OnServerEvent:Connect(function(player, action, value)
	local t = os.clock()
	if t - (raidAsks[player] or 0) < 0.25 then
		return
	end
	raidAsks[player] = t
	if action == "in" then
		Raid.signUp(player, true)
	elseif action == "out" then
		Raid.signUp(player, false)
	elseif action == "auto" then
		Raid.setAutoJoin(player, value == true)
	elseif action == "leave" then
		Raid.leave(player)
	end
end)
-- V13.3: the Port's games, challenges and sanctuaries.
Net.Play.OnServerEvent:Connect(function(player, action, a, b)
	Minigames.request(player, action, a, b)
end)
Net.Challenge.OnServerEvent:Connect(function(player, action, a, b)
	if type(action) == "string" then
		Challenges.request(player, action, a, b)
	end
end)
Net.Sanctuary.OnServerEvent:Connect(function(player, action, a)
	if type(action) == "string" then
		Sanctuary.request(player, action, a)
	end
end)
Net.BoatAbility.OnServerEvent:Connect(function(player, aimPoint, info)
	BoatAbilities.request(player, aimPoint, info)
end)
-- V13.2: every boat's bow gun (a click at the wheel), and the driver's own chain letting go.
local gunAsks = setmetatable({}, { __mode = "k" })
Net.BoatGun.OnServerEvent:Connect(function(player, aimPoint)
	local t = os.clock()
	if t - (gunAsks[player] or 0) < 0.15 then
		return
	end
	gunAsks[player] = t
	local ok, why = Cannons.driverFire(player, Boats.drivenBy(player), aimPoint)
	if not ok and why then
		Net.toast(player, why)
	end
end)
Net.BoatChain.OnServerEvent:Connect(function(player, kind)
	if kind == "sling" or kind == "arrived" or kind == "unchain" or kind == "snag" or kind == "swing" then
		BoatAbilities.released(player, kind)
	end
end)

Net.Throw.OnServerEvent:Connect(function(player)
	Loot.throw(player)
end)
Net.Poltergoblin.OnServerEvent:Connect(function(player)
	-- V13.1: switched off (Config.POLTER_ENABLED); the module stays for a later return.
	if Config.POLTER_ENABLED then
		Poltergoblin.request(player)
	end
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
local RELAYED_FX = {
	mini1 = true,
	mini2 = true,
	landing = true,
	jump = true,
	super = true,
	-- V9
	trick = true,
	trickland = true,
	sketchy = true,
	bail = true,
}
Net.BoatFx.OnServerEvent:Connect(function(player, kind, extra)
	if RELAYED_FX[kind] then
		Boats.relayFx(player, kind, extra)
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
-- V13 fix: the shop's requests carry two arguments ("equip", slot, item; "presetsave", index, name). Since V11 only
-- the first was passed on, so WEAR IT on anything already owned arrived as "equip, slot" and took the slot off (only
-- a purchase, which wears the item itself, ever changed a look), and saved outfits lost their names.
Net.Shop.OnServerEvent:Connect(function(player, action, a, b)
	if action == "robux" then
		Monetization.prompt(player, a)
	else
		Progress.handle(player, action, a, b)
	end
end)
Net.Emote.OnServerEvent:Connect(function(player, id)
	if type(id) == "string" then
		Emotes.request(player, id)
	end
end)
-- V11: a clean four-trick landing the server itself saw counts toward the Trick Master trophy.
Boats.TrickLanded:Connect(function(player, count)
	Progress.onTrickLanded(player, count)
end)
-- V11: pets (whose abilities matter in a raid) change only where nothing is chasing you. V13: in the Port (and at the
-- Hoard, for anyone in the raid); the boat you sail is chosen there too.
Progress.petSafe = function(player)
	if not Raid.isActive() or not Raid.isParticipant(player) then
		return true
	end
	local root = Util.aliveRoot(player)
	return root ~= nil and Util.flatDistance(root.Position, refs.hoard.position) <= Config.WARD_RADIUS + 25
end
Progress.boatSafe = Progress.petSafe
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
	Recall.tick(dt)
	Skyship.tick(dt)
	Flight.tick(dt)
	Pursuit.tick(dt)
	GhostFleet.tick(dt)
	Tornadoes.tick(dt, active)
	SeaMobs.tick(dt)
	Progress.tick(dt, active)
	if active then
		Loot.tick()
		Loot.sweepBoats(Boats.list) -- V13.1: drive over loose treasure to pick it up
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
	Knockout.tick()
	Movement.tick(dt)
	Emotes.tick()
	Raid.tick()
	Minigames.tick(dt) -- V13.3
end)

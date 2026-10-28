-- Every tuning number lives here so a playtest can be rebalanced in one file.
-- Times are seconds, distances are studs, speeds are studs per second.
local Config = {}

-- Raid -----------------------------------------------------------------------
-- A raid is one timed match. Bank the most gold before the timer runs out.
-- V9: SIX MINUTES of real play. The clock does not run while the skyship is deploying: the raid opens with the
-- launch window (SKYSHIP.WINDOW, 20 s) and the six-minute clock starts when that window closes, so a goblin who
-- fires late still gets the whole six minutes and one who fires at once gets a head start. (V7/V8: 720, with the
-- clock running through a 40 s deployment; V5/V6: 540, V4: 600, V3: 420.)
Config.RAID_DURATION = 360
Config.LAST_CALL = 30 -- The HUD turns red for the final stretch.
-- V7, the final rush: in the last FINAL_RUSH seconds every treasure banked pays FINAL_RUSH_MULT times its gold. It
-- gives everybody a reason to run for the Hoard at the end, and lets a goblin who is behind catch up with one big
-- run; it is a multiplier on what is banked, never on what is held, so a rival still has to be robbed to profit.
Config.FINAL_RUSH = 50 -- V9: one run's worth of a six-minute raid (V7/V8: 90 of twelve minutes).
Config.FINAL_RUSH_MULT = 1.25
-- V13: the old 10 s intermission on the skyship's deck is gone. Between raids goblins are in THE GOBLIN PORT
-- (Config.PORT, server/Port.lua) for PORT.DURATION, then everyone in the Port goes aboard the skyship together.
Config.RESPAWN_TIME = 3

-- V13, THE GOBLIN PORT (server/Port.lua, shared/Lobby.lua, client/PortHud.lua, client/Spectate.lua). A harbour town
-- far south of the archipelago where goblins gather between raids: the plaza, Madame Ragwort's wardrobe, the pet
-- menagerie, the shipyard with every boat class on its slipway, a spyglass tower for watching the raid, the boarding
-- plank to the skyship and the winners' podium. Nothing of a raid reaches it: inside RADIUS there is no damage, no
-- keg, no Poltergoblin, no boat call, no treasure, and no storm or tornado is ever seeded on a goblin standing in it.
-- The round:  PORT (DURATION) -> skyship launch window (SKYSHIP.WINDOW) -> raid (RAID_DURATION) -> back to the PORT.
Config.PORT = {
	CENTER = Vector3.new(0, 0, 4600), -- 2,250 studs south of the sea's wall, 2,900 from Goblin Cove: out of streaming range.
	RADIUS = 820, -- The Port's zone.
	DURATION = 60, -- Seconds between raids (results, shopping, spectating and getting ready all happen here).
	READY_SECONDS = 8, -- When every goblin in the Port stands on the boarding plank, the raid starts this soon.
	EMPTY_HOLD = true, -- With nobody in the server the countdown waits instead of starting raids for no one.
	LATE_JOIN_MIN = 120, -- A goblin in the Port may join the raid that is running while at least this much is left.
	ARRIVE_GRACE = 1.2, -- Seconds a goblin is held still on arrival while the Port streams in around them.
	PODIUM_DANCE = 1.5, -- Seconds after arriving that the raid's winners dance on the podium.
}

-- Movement -------------------------------------------------------------------
-- Running is fast and free. Stamina never slows a normal run: it pays for the exceptional
-- moves (sprint, dash, air jump, a carrier's sword swing).
Config.WALK_SPEED = 28 -- Running. (V2 jogged at 20.)
Config.JUMP_POWER = 56 -- Roblox's default is 50: a little higher and longer.
Config.WATER_SPEED_MULT = 0.85 -- Wading or swimming. Carry and spirit speed stack with it.
Config.WATER_ROOT_Y = 3 -- A root lower than this is standing or swimming in the sea.

-- V13.2: MOMENTUM instead of sprint. A goblin starts moving at once at a jog and builds to a full run by keeping on
-- running (shared/Momentum.lua, played by the goblin's own client on its own WalkSpeed; the server's WalkSpeed is the
-- base the momentum multiplies). A turn sharper than about 70 degrees, or stopping on the ground, spends it; a jump, a
-- fall, a grapple swing and a landing keep it. There is no sprint key any more (Shift on foot is the dash), and so no
-- stamina drain from running: stamina pays for the dash, the air jump and a carrier's swing.
-- (V13: Shift held to sprint, x1.36, 11 stamina a second.)
Config.MOMENTUM = {
	START = 0.75, -- Share of the run speed the first step is at (28 -> 21): moving at once, not crawling.
	RUN_AT = 0.3, -- Momentum at which the ordinary run (x1) is reached...
	RUN_TIME = 0.3, -- ...this many seconds after setting off.
	TOP = 1.36, -- Full momentum (28 -> 38, carriers 21.5-27 -> 29-37: what V13's sprint was).
	TOP_TIME = 2.0, -- Seconds of running on from RUN_AT to the top.
	TURN_DOT = 0.35, -- A change of heading whose cosine is below this (about 70 degrees) spends momentum...
	TURN_LOSS = 0.65, -- ...this much of it at a full reverse (less for a gentler turn).
	STOP_DECAY = 2.6, -- Momentum lost per second standing still on the ground.
	WATER_MAX = 0.4, -- Swimming builds no further than this.
	-- Speed carried from a swing, a dash or a fall: the goblin may keep moving faster than its run for a moment.
	CARRY_MAX = 92, -- Studs/s at most.
	CARRY_AIR_DECAY = 0.12, -- Share lost per second while still in the air.
	CARRY_GROUND_TIME = 0.75, -- Seconds after touching down that it slides back to the run (a slide-out, not a stop).
}
Config.STAMINA_MAX = 100
Config.STAMINA_REGEN = 32 -- Per second, once you stop spending.
Config.STAMINA_REGEN_DELAY = 0.6 -- Pause after spending before stamina comes back.
-- Loot makes every stamina cost bigger instead of making you slow: each unit of the treasure's
-- weight adds this much to sprint drain and to the cost of a dash, an air jump or a swing.
Config.CARRY_STAMINA_PER_WEIGHT = 0.12 -- Leviathan Tooth (weight 6): everything costs 1.72x.

-- Dash (C, V13.2: also Shift on foot): a short burst the way you are moving, on the ground or in the air. It is the
-- dodge: out of a marked circle, across a gap, away from a sword or a grapple's hook. V13.2: it ends at full momentum,
-- so it is also the quick start.
Config.DASH_COST = 18
Config.DASH_COOLDOWN = 0.9
Config.DASH_SPEED = 85
Config.DASH_TIME = 0.17 -- 85 * 0.17 is about 14 studs.
Config.DASH_AIR_LIFT = 6 -- An air dash cancels your fall and floats a touch.

-- Air jump (Space in the air): one extra jump per flight.
Config.AIR_JUMP_COST = 12
Config.AIR_JUMP_POWER = 52

-- Loot -----------------------------------------------------------------------
-- Value is gold when banked (it grows a little while nobody takes it: see LOOT_INTEREST).
-- weight slows boats carrying it and makes every stamina cost bigger. carrySpeed replaces
-- WALK_SPEED while held (a carrier is a little slower, not crippled: 21.5-27 against 28).
-- heat is added when it is taken from its spot. respawn is seconds after banking.
-- trouble is what the world does the moment it leaves its spot (Threats / Troubles).
-- island is the Archipelago id. visual picks the model (Loot.lua).
-- V8: VALUES ARE FLAT. Through V7 gold rose steeply with distance (1 to 20), and the playtest found that sent
-- everyone to do sums instead of going where looked fun. Now the three islands beside home pay 4 to 5 (and come
-- back slowly, 150 s, so they cannot be farmed), the keys 7 to 8, and every other island 9 to 11. A goblin picks an
-- island because of what lives on it. Weight, carry speed, heat and trouble still differ.
-- V9: ONE exception: the Golden Idol (17) is the prize of the sea, guarded by a Guardian that follows you home in a
-- boat. The three nearest home respawn after 100 to 105 s (V8: 150 to 160) in a six-minute raid.
-- (Was: the rule of the map: more gold means farther, harder to carry and nastier trouble.)
-- Values follow travel time: a near treasure earns about 2.5 gold a minute for a goblin working
-- alone, a middle one 4 to 5, a far one 6 to 8 (and far ones go wrong). V5 pulled the islands in
-- by 30%, so the far values came down from V4's; they are still well above V3's, because every
-- big island now has something living on it that makes leaving with the treasure harder.
Config.LOOT = {
	{
		id = "Compass",
		name = "Lost Compass",
		place = "Pebble Isle",
		island = "Pebble",
		visual = "disc",
		value = 4,
		weight = 1,
		carrySpeed = 27,
		heat = 4,
		respawn = 100,
		trouble = "Gulls",
		color = Color3.fromRGB(255, 225, 150),
	},
	{
		id = "Pearl",
		name = "Giant Pearl",
		place = "Coral Atoll",
		island = "Coral",
		visual = "orb",
		value = 5,
		weight = 1,
		carrySpeed = 26.5,
		heat = 6,
		respawn = 105,
		trouble = "Gulls",
		color = Color3.fromRGB(255, 190, 220),
	},
	{
		id = "Stash",
		name = "Smuggler's Stash",
		place = "Smuggler's Cove",
		island = "Smuggler",
		visual = "chest",
		value = 5,
		weight = 2,
		carrySpeed = 26,
		heat = 8,
		respawn = 105,
		trouble = "Bell",
		color = Color3.fromRGB(190, 150, 100),
	},
	{
		id = "Gear",
		name = "Golden Gear",
		place = "the Windmill",
		island = "Windmill",
		visual = "gear",
		value = 9,
		weight = 2,
		carrySpeed = 26,
		heat = 10,
		respawn = 60,
		trouble = "Windmill",
		color = Color3.fromRGB(255, 205, 60),
	},
	{
		id = "Lens",
		name = "Lighthouse Lens",
		place = "the Lighthouse",
		island = "Cross",
		visual = "disc",
		value = 9,
		weight = 2,
		carrySpeed = 25.5,
		heat = 15,
		respawn = 60,
		trouble = "Bell",
		color = Color3.fromRGB(255, 240, 140),
	},
	{
		id = "Sextant",
		name = "Sunken Sextant",
		place = "Kelp Cay",
		island = "Kelp",
		visual = "gear",
		value = 7,
		weight = 1,
		carrySpeed = 26.5,
		heat = 10,
		respawn = 60,
		trouble = "Gulls",
		color = Color3.fromRGB(150, 220, 160),
	},
	{
		id = "Chest",
		name = "Captain's Chest",
		place = "the Shipwreck",
		island = "Shoals",
		visual = "chest",
		value = 9,
		weight = 4,
		carrySpeed = 23.5,
		heat = 20,
		respawn = 60,
		trouble = "Barrage",
		color = Color3.fromRGB(255, 160, 70),
	},
	{
		id = "Heart",
		name = "Crystal Heart",
		place = "Crystal Isle",
		island = "Crystal",
		visual = "orb",
		value = 10,
		weight = 3,
		carrySpeed = 24.5,
		heat = 25,
		respawn = 60,
		trouble = "CaveIn",
		way = "through the tunnel at the foot of the spire", -- V12: the objective line's hint (it is under a roof)
		color = Color3.fromRGB(215, 110, 255),
	},
	{
		id = "Frog",
		name = "Jade Frog",
		place = "Tangle Isle",
		island = "Tangle",
		visual = "frog", -- V10: its own look (it shared the idol's)
		value = 10,
		weight = 2,
		carrySpeed = 25,
		heat = 22,
		respawn = 60,
		trouble = "Quake",
		color = Color3.fromRGB(110, 235, 130),
	},
	{
		id = "Vault",
		name = "Pearl of the Deep",
		place = "the Tide Vault",
		island = "Tide",
		visual = "orb",
		value = 10,
		weight = 3,
		carrySpeed = 24.5,
		heat = 26,
		respawn = 60,
		trouble = "Flood",
		color = Color3.fromRGB(110, 230, 255),
	},
	{
		id = "Trident",
		name = "Tempest Trident",
		place = "Maelstrom Rock",
		island = "Maelstrom",
		visual = "gem",
		value = 10,
		weight = 3,
		carrySpeed = 24.5,
		heat = 24,
		respawn = 60,
		trouble = "Squall",
		color = Color3.fromRGB(150, 190, 255),
	},
	{
		id = "Lantern",
		name = "Storm Lantern",
		place = "Lantern Key",
		island = "Lantern",
		visual = "gem",
		value = 8,
		weight = 2,
		carrySpeed = 25.5,
		heat = 22,
		respawn = 60,
		trouble = "Bell",
		color = Color3.fromRGB(255, 200, 110),
	},
	{
		id = "Castaway",
		name = "Castaway's Hoard",
		place = "Driftwood Key",
		island = "Driftwood",
		visual = "chest",
		value = 8,
		weight = 4,
		carrySpeed = 23.5,
		heat = 24,
		respawn = 60,
		trouble = "Gulls",
		color = Color3.fromRGB(205, 175, 130),
	},
	{
		id = "Strongbox",
		name = "Admiral's Strongbox",
		place = "Fort Barnacle",
		island = "Fort",
		visual = "chest",
		value = 11,
		weight = 5,
		carrySpeed = 22.5,
		heat = 30,
		respawn = 70,
		trouble = "Navy",
		color = Color3.fromRGB(255, 110, 100),
	},
	{
		id = "Crown",
		name = "Ember Crown",
		place = "the Volcano",
		island = "Ember",
		visual = "crown",
		value = 10,
		weight = 3,
		carrySpeed = 24,
		heat = 32,
		respawn = 60,
		trouble = "Eruption",
		color = Color3.fromRGB(255, 130, 50),
	},
	{
		id = "Idol",
		name = "Golden Idol",
		place = "the Sun Temple",
		island = "Temple",
		visual = "idol",
		value = 17, -- V9: the single most valuable treasure (V8: 11). Everything else stays at 4 to 11.
		weight = 4,
		carrySpeed = 23.5,
		heat = 40,
		respawn = 70,
		trouble = "Guardian",
		color = Color3.fromRGB(255, 205, 40),
	},
	{
		id = "Aurora",
		name = "Aurora Gem",
		place = "Frost Spire",
		island = "Frost",
		visual = "gem",
		value = 11,
		weight = 4,
		carrySpeed = 23.5,
		heat = 38,
		respawn = 70,
		trouble = "Avalanche",
		color = Color3.fromRGB(150, 245, 255),
	},
	{
		id = "Tooth",
		name = "Leviathan Tooth",
		place = "Leviathan's Rest",
		island = "Bone",
		visual = "tooth",
		value = 11,
		weight = 6,
		carrySpeed = 21.5,
		heat = 42,
		respawn = 70,
		trouble = "Kraken",
		color = Color3.fromRGB(245, 240, 215),
	},
	{
		id = "Chalice",
		name = "Skull Chalice",
		place = "Skull Rock",
		island = "Skull",
		visual = "chalice",
		value = 11,
		weight = 5,
		carrySpeed = 22.5,
		heat = 45,
		respawn = 70,
		trouble = "GhostFleet",
		way = "in through the skull's mouth and up the ladder", -- V12: the objective line's hint (it is inside)
		color = Color3.fromRGB(130, 255, 180),
	},
}

-- Loot nobody takes grows more valuable: one step per LOOT_INTEREST_EVERY seconds untouched,
-- up to LOOT_INTEREST_MAX steps. A step is LOOT_INTEREST_SHARE of the treasure's value (at
-- least 1 gold), so a far prize left alone gains as much, in proportion, as a near one. A
-- treasure everyone ignores becomes the best deal on the map, so the crowd is always deciding
-- between "now, with company" and "later".
Config.LOOT_INTEREST_EVERY = 45 -- V9 (V8: 80, in a raid twice as long)
Config.LOOT_INTEREST_MAX = 3
Config.LOOT_INTEREST_SHARE = 0.12 -- The Skull Chalice (20) gains 2 a step, up to +6.

Config.PICKUP_DISTANCE = 10
Config.STEAL_HOLD = 0.6 -- Holding E to pry loot off its spot.
Config.GRAB_HOLD = 0.15 -- Holding E to grab loose loot.
Config.STEAL_IMMUNITY = 1.5 -- After loot changes hands, nobody can take it for this long.
Config.THROW_SPEED = 62
Config.THROW_UP_SPEED = 38
Config.THROW_REGRAB_DELAY = 0.6 -- The thrower can't instantly catch their own throw.
Config.THROWN_BANK_WINDOW = 8 -- Loose loot entering the Hoard banks for whoever last held it.
Config.LOOSE_RETURN_TIME = 45 -- Loose loot nobody touches goes back to its spot.
Config.KNOCK_LOOSE_SPEED = 26

Config.BANK_RADIUS = 14
Config.WARD_RADIUS = 55 -- Around the Hoard: no Poltergoblin, no Guardian.

-- Out of bounds. Loot past these returns to its spot. Invisible walls stand at
-- the X/Z edges, built from several parts because one part can't pass 2048 studs.
-- V5: 5080 x 4390 studs. V3's sea was 3200 x 2740 and V4's 6900 x 5840; the V4 playtest found
-- that too spread out, so this is 55% of V4's area (2.5 times V3's).
-- V7: 5880 x 5010 studs (the islands beyond the home ring are 20% farther apart; see Archipelago.lua).
Config.BOUNDS_MIN = Vector3.new(-2980, -45, -2660)
Config.BOUNDS_MAX = Vector3.new(2900, 600, 2350)

-- Heat -----------------------------------------------------------------------
-- One shared meter. Stealing and carrying raise it, quiet time lowers it.
-- World threats only ever target players carrying loot.
Config.HEAT_MAX = 100
Config.HEAT_TIERS = {
	{ name = "CALM", at = 0, color = Color3.fromRGB(120, 200, 255), hint = "Nobody's watching. Yet." },
	{
		name = "ALERT",
		at = 25,
		color = Color3.fromRGB(255, 210, 70),
		hint = "Carriers are lit up for everyone. Flares mark them. Totems fire.",
	},
	{
		name = "HUNTED",
		at = 50,
		color = Color3.fromRGB(255, 120, 40),
		hint = "A patrol ship cuts the thief off. The Guardian hunts.",
	},
	{
		name = "FRENZY",
		at = 80,
		color = Color3.fromRGB(255, 45, 60),
		hint = "A second ship mines the way home. A tempest chases the thief.",
	},
}
-- Heat per second of carrying follows trip length: V3's short trips used 0.8, V4's long ones
-- 0.48, V5's sit between. The aim is the same shape each time: a middle treasure ends its trip
-- at ALERT, a far one is HUNTED for most of the way and reaches FRENZY near home if the thief
-- dawdles or is caught up in a fight.
Config.HEAT_CARRY_RATE = 0.62 -- Per carrier outside the ward, per second, for a 25-heat treasure (scaled by its heat). (V4: 0.48, V3: 0.8)
Config.HEAT_CARRY_RATE_CAP = 1.7 -- (V4: 1.4, V3: 2.0)
Config.HEAT_DECAY_RATE = 0.5 -- Per second while nobody carries loot. (V3: 0.6)
Config.REVEAL_TIER = 2 -- ALERT and up: carriers are visible through walls.

-- Guardian -------------------------------------------------------------------
-- Wakes when the Golden Idol is taken, or when Heat reaches GUARDIAN_WAKE_TIER.
Config.GUARDIAN_WAKE_TIER = 3
-- It outpaces a carrier who only runs (21.5-27) and loses to one who sprints (27-34), so
-- stamina is the lifeline and a straight line is how you spend it.
Config.GUARDIAN_SPEED = 27 -- (V2: 16)
Config.GUARDIAN_FRENZY_SPEED = 32 -- (V2: 19)
Config.GUARDIAN_WADE_MULT = 0.8
Config.GUARDIAN_LEASH = 520 -- From the temple island's center, until FRENZY: the whole of the bigger island (V3: 300).
Config.GUARDIAN_HIT_RANGE = 9
Config.GUARDIAN_DAMAGE = 20
Config.GUARDIAN_KNOCKBACK = 60
Config.GUARDIAN_HIT_COOLDOWN = 1.2
Config.GUARDIAN_RECOVER = 0.8 -- It stands still this long after a smash.

-- Totems ---------------------------------------------------------------------
-- Stone watchers by the loot spots. They charge, then lob a blast at a carrier.
Config.TOTEM_TIER = 2
Config.TOTEM_RANGE = 130
Config.TOTEM_TELEGRAPH = 0.9
Config.TOTEM_INTERVAL = { [2] = 4.5, [3] = 3.2, [4] = 2.2 } -- By Heat tier.
Config.TOTEM_LEAD = 0.35 -- Aims this many seconds ahead of the target.

Config.BLAST_SPEED = 125
Config.BLAST_MAX_TIME = 2
Config.BLAST_RADIUS = 8
Config.BLAST_DAMAGE = 15
Config.BLAST_KNOCKBACK = 55

-- Trouble (what each loot does when taken) -------------------------------------
Config.BOULDER_SIZE = 11
Config.BOULDER_SPEED = 44
Config.BOULDER_DAMAGE = 35
Config.BOULDER_KNOCKBACK = 70
Config.BOULDER_LIFETIME = 10

Config.CAVE_IN_BLOCK_TIME = 25
Config.CAVE_IN_ROCKS = 7
Config.CAVE_IN_DAMAGE = 15

Config.BARRAGE_SHOTS = 4
Config.BARRAGE_GAP = 0.9

Config.BELL_REVEAL_TIME = 20

-- Combat ---------------------------------------------------------------------
-- Everyone spawns with a sword. Carriers can't swing (hands full).
Config.SWORD_DAMAGE = 20
Config.SWORD_RANGE = 9
Config.SWORD_MIN_DOT = 0.3
Config.SWORD_COOLDOWN = 0.55
Config.SWORD_KNOCKBACK = 34

-- F: a grappling hook. Aimed at loot (or near a carrier) it steals it, with a
-- clear line of sight. Aimed at ground, walls, cliffs or a boat it pulls you there (a boat
-- keeps moving: the rope follows it). Carriers can't steal with it, but they can still pull
-- themselves around, on a longer cooldown. A miss costs no cooldown.
-- V13.2: THE GRAPPLE IS HOW GOBLINS GET ABOUT ON FOOT (Config.SWING, shared/Swing.lua). Hooked to something above
-- you, you SWING on the rope under your own momentum (W A S D pump the swing; hold F to reel in; F again or Space lets
-- go and you keep every bit of the speed). Hooked to something level or below, it reels you to it (the old pull).
-- It starts on your own client the moment you press (the server is told and checks the rope's reach).
Config.GRAPPLE_RANGE = 70 -- Range for grabbing LOOSE loot (a carrier is caught at GRAPPLE_PVP_RANGE, below).
Config.GRAPPLE_AIM_ASSIST = 8 -- Loot or a carrier this far off your aim line still counts.
-- V7: the hook CATCHES a carrier, it does not rob them. A caught goblin is yanked toward you and falls
-- (CATCH_DOWN_TIME seconds, or sooner if they press Space after CATCH_MIN_DOWN); you have to run up and
-- press E within STEAL_RANGE to take what they carry. The ordinary pull (to walls, ground, boats) keeps
-- its long GRAPPLE_PULL_RANGE: only the person-catching range was cut.
Config.GRAPPLE_PVP_RANGE = 40 -- (V6: 70, and it stole at once.)
Config.CATCH_DOWN_TIME = 2.0
Config.CATCH_MIN_DOWN = 0.9 -- Before this, Space does not get you up.
Config.CATCH_PULL_SPEED = 46 -- The yank toward the thrower.
Config.CATCH_COOLDOWN = 4.5 -- The hook's cooldown after a catch.
Config.CATCH_IMMUNITY = 6 -- Nobody can be caught again for this long after getting up (no knockdown loops).
Config.STEAL_RANGE = 8 -- E at this range, on a goblin who is down.
Config.STEAL_COOLDOWN = 1.2
Config.GRAPPLE_COOLDOWN = 6 -- After a successful steal.
Config.GRAPPLE_FAIL_COOLDOWN = 1 -- After a steal that slipped off (steal immunity).
Config.GRAPPLE_PULL_RANGE = 170
Config.GRAPPLE_PULL_SPEED = 135
Config.GRAPPLE_PULL_COOLDOWN = 1.4
Config.GRAPPLE_CARRY_COOLDOWN = 2.4 -- A carrier's pull or swing: usable, but not spammable. (V13.2; V13: 5.)
Config.GRAPPLE_POP_SPEED = 42 -- Upward hop at the end of a pull, to climb onto ledges.
Config.GRAPPLE_KEEP_SPEED = 0.6 -- How much of the pull's sideways speed you keep when it ends.
Config.GRAPPLE_BOAT_ASSIST = 18 -- Aim passing this close to a boat hooks the boat (a fast boat is ahead of where you see it).
-- V13.2: the catch is a thrown hook, not a hitscan: it flies at CATCH_HOOK_SPEED, so a carrier who sees it coming can
-- dash out of its line (it must still be within CATCH_HOOK_WIDTH of where it was thrown when it gets there).
Config.CATCH_HOOK_SPEED = 170
Config.CATCH_HOOK_WIDTH = 7
Config.SWING = {
	RANGE = 170, -- Studs to a hook point (GRAPPLE_PULL_RANGE).
	ASSIST = math.rad(7), -- Aim this far off a hookable surface still finds it (a cone of rays: forgiving).
	ABOVE = 6, -- A hook this far above you is a swing; lower, it reels you in (the pull).
	GRAVITY = 150, -- Studs/s/s while swinging (the world's is 196: a slower, readable arc).
	PUMP = 46, -- Studs/s/s the move keys add along the swing.
	START_SHORTEN = 0.9, -- The rope starts this share of the distance, so the swing begins at once.
	REEL = 70, -- Studs/s the rope shortens while F is held.
	MIN_LENGTH = 8,
	MAX_SPEED = 125, -- Studs/s at most on a rope.
	MAX_TIME = 7, -- A swing lets go by itself after this long.
	RELEASE_POP = 18, -- Upward studs/s added when you let go moving up (a little lift off the top of an arc).
	COOLDOWN = 0.35, -- After a swing or a pull ends, before the next hook. (Carriers: GRAPPLE_CARRY_COOLDOWN.)
	GROUND_LET_GO = 0.3, -- Seconds on the ground with a slack rope before it lets go by itself.
}

-- Poltergoblin (was Soul Unbound, Yone's E) ----------------------------------------
-- E leaves your body behind and sends your spirit out. Whatever loot the spirit
-- holds rides the tether back to the body.
-- V13.1 (the V13 playtest): SUNSET. Poltergoblin is switched off and E is kept for prompts (boats, treasure,
-- cannons, levers) and for leaving a boat. Everything below and server/Poltergoblin.lua stay, so it can come back.
Config.POLTER_ENABLED = false
Config.POLTER_DASH_DISTANCE = 16
Config.POLTER_DASH_TIME = 0.16
Config.POLTER_DURATION = 5
Config.POLTER_RECAST_DELAY = 0.5
Config.POLTER_COOLDOWN = 10 -- Starts on cast.
Config.POLTER_SPEED_BONUS_START = 0.1
Config.POLTER_SPEED_BONUS_END = 0.3
Config.POLTER_ECHO_FRACTION = 0.35
Config.POLTER_TETHER = 90 -- Straying farther from the body snaps you back.

-- Sea ------------------------------------------------------------------------
-- Waves, currents and storms are functions of position and time (Sea.lua). The
-- Terrain water is only the visual surface; boats float on these numbers.
Config.SEA_WAVE_AMP = 0.75 -- Calm-day swell strength (studs, roughly crest height).
Config.SEA_STORM_WAVES = 3.4 -- Extra swell multiplier at the heart of a storm.
Config.SEA_SHELTER_DISTANCE = 230 -- Water this close to land is sheltered.
Config.SEA_SHELTER_CALM = 0.3 -- Swell multiplier right beside the shore.
Config.SEA_WIND = Vector3.new(-0.6, 0, 0.8) -- Direction the wind blows toward.
Config.SEA_WIND_DRIFT = 1.4 -- Studs/s of drift in calm weather (storms push harder).

-- Boats ----------------------------------------------------------------------
-- Real physics hulls floating on the Sea functions (BoatSim.lua). Arcade, not maritime: quick
-- to launch, sharp to steer, and happy to slide. Each type is good at something different:
--   skiff   the fastest and the best drifter; outruns anything, but two bad crashes sink it
--   cutter  slower than a patrol ship, so it cannot simply run: it carries a cannon and three
--           passengers, shrugs off crashes and hits hard when it rams
--   navy    AI patrol ship: fast in a straight line, wide in a turn, too deep for shallows
-- size: hull box. draft: studs below the surface at rest. accel/maxSpeed in studs/s.
-- turn: rad/s when slow; turnFade: speed at which the turn rate has halved. grip: how hard the
-- keel resists sliding sideways; driftGrip/driftTurn multiply grip and turn while drifting.
-- crashTaken/ramPower scale the hull damage it takes and deals in a collision.
-- V13: SEVEN PLAYER CLASSES. The Skiff and the Cutter are free and always yours; the other five are permanent unlocks
-- (Shinies, or Robux once a human sets products up). Different is not better: every class is the best at one thing
-- and worse at others, and the free Skiff is still the fastest boat in a straight line. Each class has one ABILITY on
-- the stunt key (R / R1 / the touch STUNT button) while on the water; in the air that key still does tricks.
-- Extra fields BoatSim and Boats read (absent means "as a Skiff"):
--   ability        a key into Config.BOAT_ABILITIES
--   boostCooldown  seconds (Config.BOAT_BOOST_COOLDOWN if absent)
--   jumpMult       the hop and super jump, as a multiple
--   airControl     share of the steering kept in the air (Config.BOAT_AIR_CONTROL if absent)
--   trickSpeed     tricks play this much faster (more of them fit in one jump)
--   landKick       the clean-landing burst, as a multiple
--   airHop         one extra hop in the air per flight (SPACE)
--   stormSails     top speed and thrust multiple inside a storm cell or near a tornado (and the swell rocks it less)
--   twisterBail    the tornado bail-out throw, as a multiple
--   shoveTaken     how much of a shove (a monster, a blast, a cannon) reaches the hull
--   righting       the upright assist, as a multiple
--   surfer         (V13.2) how hard the water's own flow (a rogue wave, a whirlpool) carries it, as a multiple
--   class          true: a player class the showroom and the catalogue list (the Navy is not one)
-- V13.2 (Sea of Chaos): TEN PLAYER CLASSES ON ONE SPEED BAND. The V13 playtest found the free Skiff simply best: the
-- fastest top speed, the quickest 0-to-top and Nitro on top. Now every class cruises between 106 and 118 studs/s and
-- reaches it in about the same time (accel is about 0.6 of top speed for every class: 90% of top in 3.5 to 3.9 s),
-- and the classes differ in HOW they play: handling, toughness, crew, air, and an ability that escapes or disrupts.
-- (V13: 96 to 135, the Skiff 0-to-top in about 3 s and the Ironbelly in over 4.) Measured island-to-Hoard times are in
-- docs/reports/2026-10-19-v13-2-sea-of-chaos.md. Every class also has a bow gun its driver fires with a click
-- (Config.BOAT_GUN), separate from its ability.
Config.BOAT_TYPES = {
	skiff = {
		name = "Skiff",
		class = true,
		ability = "nitro",
		size = Vector3.new(9, 3, 20),
		draft = 1.3,
		density = 0.75,
		accel = 72, -- V13.2 (V13: 100, the extreme 0-to-top the playtest named)
		maxSpeed = 118, -- V13.2 (V13: 135): still the top of the band, by 2 studs/s
		turn = 2.6, -- V13.2 (V13: 2.5): agile is its job now, not speed
		turnFade = 240,
		grip = 3.4,
		driftGrip = 0.32, -- the best drifter
		driftTurn = 1.7,
		lean = 40,
		health = 170,
		crashTaken = 1,
		ramPower = 1,
		passengers = 1,
	},
	cutter = {
		name = "Cutter",
		class = true,
		ability = "rally",
		size = Vector3.new(14, 4, 34),
		draft = 2.1,
		density = 0.8,
		accel = 69,
		maxSpeed = 114,
		turn = 1.9,
		turnFade = 210,
		grip = 2.8,
		driftGrip = 0.45,
		driftTurn = 1.4,
		lean = 24,
		health = 420,
		crashTaken = 0.6,
		ramPower = 1.8,
		passengers = 3,
		cannons = true, -- the passenger's deck cannon (a prompt), as since V7
		righting = 1.25, -- stable: it rights itself sooner
	},
	reefhopper = {
		name = "Reefhopper",
		class = true,
		ability = "spring",
		size = Vector3.new(10, 3, 18),
		draft = 1.2,
		density = 0.72,
		accel = 70,
		maxSpeed = 113,
		turn = 2.45,
		turnFade = 225,
		grip = 3.0,
		driftGrip = 0.4,
		driftTurn = 1.5,
		lean = 34,
		health = 160,
		crashTaken = 1.1,
		ramPower = 0.8,
		passengers = 1,
		jumpMult = 1.25,
		airControl = 0.75,
		trickSpeed = 1.35,
		landKick = 1.5,
		airHop = true,
	},
	broadside = {
		name = "Broadside",
		class = true,
		ability = "volley",
		size = Vector3.new(16, 5, 38),
		draft = 2.4,
		density = 0.85,
		accel = 63,
		maxSpeed = 108,
		turn = 1.5,
		turnFade = 180,
		grip = 2.6,
		driftGrip = 0.5,
		driftTurn = 1.3,
		lean = 16,
		health = 520,
		crashTaken = 0.5,
		ramPower = 2.0,
		passengers = 3,
		boostCooldown = 6,
		broadside = true, -- two gunner cannons, one each side (Cannons.mountOnBoat)
		righting = 1.3,
		shoveTaken = 0.8,
	},
	stormrunner = {
		name = "Stormrunner",
		class = true,
		ability = "twister",
		size = Vector3.new(11, 3.5, 26),
		draft = 1.6,
		density = 0.78,
		accel = 67,
		maxSpeed = 112, -- 132 in a storm or beside a tornado (stormSails)
		turn = 2.15,
		turnFade = 215,
		grip = 3.0,
		driftGrip = 0.4,
		driftTurn = 1.5,
		lean = 30,
		health = 270,
		crashTaken = 0.85,
		ramPower = 1.1,
		passengers = 2,
		stormSails = 1.18,
		twisterBail = 1.45,
		airControl = 0.55,
	},
	wraith = {
		name = "Wraith",
		class = true,
		ability = "slip",
		size = Vector3.new(8, 2.6, 22),
		draft = 1.1,
		density = 0.7,
		accel = 71,
		maxSpeed = 115,
		turn = 3.1, -- the sharpest steering in the fleet
		turnFade = 260,
		grip = 3.8,
		driftGrip = 0.3,
		driftTurn = 1.8,
		lean = 42,
		health = 130, -- the most fragile
		crashTaken = 1.25,
		ramPower = 0.7,
		passengers = 1,
	},
	ironbelly = {
		name = "Ironbelly",
		class = true,
		ability = "plow",
		size = Vector3.new(18, 6, 36),
		draft = 2.6,
		density = 0.9,
		accel = 61,
		maxSpeed = 106, -- the bottom of the band (V13: 96, ten seconds behind a Skiff on a long crossing)
		turn = 1.4,
		turnFade = 170,
		grip = 2.4,
		driftGrip = 0.55,
		driftTurn = 1.25,
		lean = 12,
		health = 640,
		crashTaken = 0.3,
		ramPower = 2.6,
		passengers = 4,
		boostCooldown = 6,
		shoveTaken = 0.5, -- monsters, blasts and cannons move it half as far
		righting = 1.6,
		boardReach = 40, -- swimmers can climb aboard from far off (a rescue boat)
	},
	-- V13.2 classes ---------------------------------------------------------------------------------------------------
	anchorjack = {
		name = "Anchorjack",
		class = true,
		ability = "anchor",
		size = Vector3.new(13, 4, 28),
		draft = 1.9,
		density = 0.82,
		accel = 65,
		maxSpeed = 110,
		turn = 2.2,
		turnFade = 220,
		grip = 3.1,
		driftGrip = 0.42,
		driftTurn = 1.5,
		lean = 26,
		health = 360,
		crashTaken = 0.7,
		ramPower = 1.6,
		passengers = 2,
		righting = 1.2,
	},
	wavebreaker = {
		name = "Wavebreaker",
		class = true,
		ability = "breaker",
		size = Vector3.new(14, 4, 26),
		draft = 1.8,
		density = 0.8,
		accel = 66,
		maxSpeed = 111,
		turn = 2.0,
		turnFade = 210,
		grip = 2.9,
		driftGrip = 0.45,
		driftTurn = 1.45,
		lean = 22,
		health = 320,
		crashTaken = 0.75,
		ramPower = 1.3,
		passengers = 2,
		jumpMult = 1.1,
		surfer = 1.6, -- rides a rogue wave's push farther (BoatSim: the water's own flow pulls it harder)
		shoveTaken = 0.75,
		righting = 1.3,
	},
	corsair = {
		name = "Corsair",
		class = true,
		ability = "hook",
		size = Vector3.new(11, 3.6, 27),
		draft = 1.5,
		density = 0.78,
		accel = 68,
		maxSpeed = 116,
		turn = 2.3,
		turnFade = 230,
		grip = 3.2,
		driftGrip = 0.38,
		driftTurn = 1.6,
		lean = 34,
		health = 250,
		crashTaken = 0.9,
		ramPower = 1.4,
		passengers = 2,
	},
	navy = {
		name = "Patrol Ship",
		size = Vector3.new(16, 6, 42),
		draft = 3.8,
		density = 0.85,
		accel = 64,
		maxSpeed = 104, -- V13.2 (V13: 106): just under the slowest player class, so any boat can leave one behind
		turn = 1.3, -- (V6: 1.15)
		turnFade = 160, -- (V6: 120)
		grip = 2.4,
		driftGrip = 1,
		driftTurn = 1,
		lean = 14,
		health = 480,
		crashTaken = 0.5,
		ramPower = 2.2,
		passengers = 0,
	},
	-- V13.3: the Tiny Boat Regatta's RACING TUB (server/Regatta.lua). Not a class (nobody owns one; the Port lends them)
	-- and no ability (R on the water does nothing; R in the air is still a trick). As small as the Wraith is narrow and
	-- shorter than the Reefhopper, so its physics stay inside what the fleet already floats. It never sinks: the
	-- regatta is for bumping, not wrecking.
	racer = {
		name = "Racing Tub",
		size = Vector3.new(8, 2.6, 16),
		draft = 1.1,
		density = 0.7,
		accel = 70,
		maxSpeed = 112,
		turn = 2.6,
		turnFade = 240,
		grip = 3.4,
		driftGrip = 0.34,
		driftTurn = 1.7,
		lean = 36,
		health = 5000,
		crashTaken = 0.15,
		ramPower = 1.3,
		passengers = 0,
		boardReach = 30,
	},
}
Config.BOAT_BOOST_MULT = 1.42 -- Top speed while boosting (V13.2: a Skiff 168, an Ironbelly 150; V13: 1.5, a skiff 202).
Config.BOAT_BOOST_THRUST = 2.2 -- V13.2 (V13: 2.4, V6: 2.1)
Config.BOAT_BOOST_TIME = 2.4 -- (V6: 2.2)
Config.BOAT_BOOST_COOLDOWN = 5 -- (V6: 5.5, V2: 7)
Config.BOAT_BOOST_PUNCH = 14 -- Speed added the moment a boost starts: the kick in the back.
Config.BOAT_LAUNCH_PUNCH = 0.6 -- Extra thrust from a standstill, fading out by half speed. (V13.2; V13: 0.9, which made
-- the Skiff's start a jump-cut. Every class still answers the throttle at once.)
Config.BOAT_BRAKE = 1.7 -- Thrust against the way you are moving: S is a brake, not a slow reverse.
Config.BOAT_REVERSE = 0.5 -- Reverse thrust relative to forward.
Config.BOAT_BEACH_SHOVE = 1.6 -- Thrust (as a share of accel) for shoving a hull along that is in the air or on a ledge the ground check cannot see...
Config.BOAT_BEACH_SPEED = 12 -- ...which only works below this speed.
-- V7: a boat can drive on land, slowly (Minecraft's boats do), so a beached boat is never stuck and a
-- narrow spit is a shortcut. The speed is about a goblin's sprint: water stays far better.
Config.BOAT_LAND_SPEED = 0.3 -- Top speed on land, as a share of the hull's maxSpeed (a skiff: 40; it measures about 23 under load). A boost does not raise it.
Config.BOAT_LAND_THRUST = 1.6 -- Engine power on land, as a share of accel: enough to climb a steep beach, which the low top speed keeps in check.
Config.BOAT_LAND_COAST = 1.8 -- Land drag off the throttle, as a multiple of the on-throttle drag: it stops quickly.
Config.BOAT_LAND_TURN = 0.8 -- Share of the steering kept on land.
Config.BOAT_LAND_SLOPE = 0.45 -- The ground's normal must point up at least this much (Y) to count as a floor, not a wall.
-- V7: Space at the wheel hops the boat. It needs water or ground under the hull and a cooldown, so there is
-- no flying; a jump from a charged drift releases the burst.
Config.BOAT_JUMP_SPEED = 80 -- Upward speed of a plain hop: about 16 studs up, 0.8 s in the air (V7: 58, 8.5 studs).
Config.BOAT_JUMP_COOLDOWN = 1.1 -- (V7: 1.3)
-- V8, the SUPER JUMP. Space while the hull is going faster than BOAT_SUPER_MIN (so: boosting, on a hoop chain,
-- out of a drift burst; plain cruising is 135) throws it far higher: the jump's upward speed grows from the
-- hop's to BOAT_SUPER_SPEED as the hull's speed goes from BOAT_SUPER_MIN to BOAT_SUPER_FULL. At full it is 57
-- studs up and a second and a half in the air: 330 studs of flight at chain speed, over a rock, a patrol ship
-- or a sea monster's back. Not on land. A clean landing from one pays the landing burst; a plain hop does not.
Config.BOAT_SUPER_MIN = 132 -- V13.2 (V13: 150): above every class's cruise (118 at most), below every boost (150+)
Config.BOAT_SUPER_FULL = 188 -- V13.2 (V13: 215)
Config.BOAT_SUPER_SPEED = 150
Config.BOAT_SUPER_PITCH = 0.5 -- How hard a super jump throws the bow up (the upright assist levels it again).
Config.BOAT_YAW_SNAP = 8 -- How quickly the hull reaches the turn rate you ask for (V2: 5).
Config.BOAT_SLIP_LOSS = 0.15 -- Speed shed by sliding sideways in an ordinary turn (V2: 0.5).
Config.BOAT_COAST_DRAG = 0.35 -- Share of the engine-on drag that remains off the throttle: boats coast.
Config.BOAT_BUOY_DAMPING = 1.1 -- How quickly a hull stops bouncing on its springs (V2: 0.85).
Config.BOAT_MAX_STEP = 0.1 -- Longest frame the boat physics will integrate in one go (10 frames a second).
Config.BOAT_AIR_CONTROL = 0.35 -- Share of the steering you keep while airborne.
Config.BOAT_AIR_MIN = 0.4 -- Seconds off the water before a touchdown counts as a landing.
Config.BOAT_LANDING_AIR = 0.7 -- Seconds in the air before a clean landing also bursts. (A plain hop never does: BoatSim marks it.)
Config.BOAT_FLIP_TIME = 1 -- Seconds a hull lies capsized before it pops back upright.
Config.BOAT_LANDING_KICK = 16 -- Speed added by a clean landing (V6: 12).
Config.BOAT_PAYLOAD_DRAG = 0.03 -- Each unit of loot weight aboard cuts thrust and top speed by this much.

-- V13: BOAT ABILITIES, one per class, on the stunt key while the hull is on the water (shared/BoatSim.lua plays the
-- physical part on whichever machine simulates the hull; server/BoatAbilities.lua checks the cooldown, fires what the
-- server owns and tells Boats.police what speed to allow). `glyph` and `verb` are what the HUD and the showroom show.
-- V13.2: every ability helps its driver ESCAPE, DISRUPTS someone, or both; the universal bow gun (Config.BOAT_GUN, a
-- click) is separate from all of them. Three new ones (anchor, breaker, hook), the Cutter's became RALLY (its bow gun is
-- every boat's now), and Nitro is a short escape burst that breaks free of grabs instead of a straight-line win.
Config.BOAT_ABILITIES = {
	nitro = { -- Skiff: the escape artist's afterburner.
		name = "NITRO",
		glyph = "🔥",
		verb = "A short afterburner that breaks free of anchors, hooks and whirlpools",
		cooldown = 15, -- V13.2 (V13: 14)
		time = 1.1, -- V13.2 (V13: 1.3)
		mult = 1.45, -- V13.2 (V13: 1.75): only a touch above a boost (1.42); its worth is getting loose
		thrust = 2.6,
		kick = 18, -- V13.2 (V13: 30)
		shrug = 0.3, -- share of a shove that reaches the hull while it burns
	},
	rally = { -- Cutter (V13.2): a foghorn for a convoy.
		name = "RALLY HORN",
		glyph = "📯",
		verb = "Boats near you surge forward; chasing monsters flinch back",
		cooldown = 16,
		radius = 150, -- every boat this close surges with you (friends, and rivals who happen to be there)
		boost = 2.2, -- seconds of boost it gives each boat
		patch = 40, -- hull the Cutter patches
		flinch = 190, -- pursuers this close are knocked back
		push = 120,
	},
	spring = { -- Reefhopper: leap off flat water like a ramp; SPACE in the air hops once more.
		name = "SPRING",
		glyph = "🌀",
		verb = "Leap off flat water; SPACE again in the air",
		cooldown = 9,
		up = 104,
		keep = 1.06,
		airHop = 72, -- the second hop, in the air
	},
	volley = { -- Broadside: three shots from the side the driver looks to.
		name = "BROADSIDE",
		glyph = "💣",
		verb = "A three-gun volley from the side you look at",
		cooldown = 10,
		shots = 3,
		spread = 9, -- studs between the shots' landing points
		range = 300,
	},
	twister = { -- Stormrunner: a tornado spins up in its wake.
		name = "TWISTER",
		glyph = "🌪",
		verb = "Spin up a tornado in your wake",
		cooldown = 24, -- V13.2 (V13: 28)
		life = 12,
		behind = 85, -- studs behind the stern
		drift = 12, -- studs/s it follows your heading
		homeClear = 760, -- never this close to the Hoard
		max = 4, -- summoned tornadoes on the whole sea at once
		grace = 5, -- seconds its summoner's own boat is ignored by funnels (time to get clear of its own twister)
	},
	slip = { -- Wraith: a sideways dash, leaving a ghost of the boat running straight on.
		name = "PHANTOM",
		glyph = "👻",
		verb = "Slip aside and leave a ghost that fools pursuers",
		cooldown = 11,
		side = 92, -- studs/s sideways
		decoy = 2.6, -- seconds the ghost runs on (and fools whatever chases you)
		fool = 700, -- pursuers this close are fooled
	},
	plow = { -- Ironbelly: a battering charge.
		name = "RAM PLOW",
		glyph = "🐗",
		verb = "A charge that shoves boats and monsters aside",
		cooldown = 14,
		time = 2.6,
		thrust = 1.7,
		top = 1.18,
		shove = 95, -- studs/s given to a boat it plows into
		reach = 10, -- studs beyond the bow that count as a hit
	},
	-- V13.2 -------------------------------------------------------------------------------------------------------------
	anchor = { -- Anchorjack: the anchor, which no other boat has any more.
		name = "ANCHOR",
		glyph = "⚓",
		verb = "Throw the anchor where you look: snag a rival's boat, or a rock to swing round it",
		cooldown = 9,
		range = 150, -- studs the anchor flies
		arc = 0.2, -- the aim must be at least this far forward (a dot product with the bow): no throwing it backwards
		assist = 22, -- a rival hull this close to the aim line is snagged
		snag = 3.5, -- seconds a snagged rival is chained to you
		snagSlack = 1.0, -- the chain's length is the gap when it caught, times this (it never pulls you together)
		snagMin = 34,
		swing = 2.6, -- seconds you swing round a rock or the sea bed before it lets go (R lets go sooner)
		swingMin = 26, -- the shortest chain to swing on
		sling = 34, -- studs/s added along your swing when you let go: the slingshot
		strength = 9, -- how hard a taut chain corrects motion (per second)
	},
	breaker = { -- Wavebreaker: the hull slams down and the sea itself shoves outward.
		name = "BREAKER",
		glyph = "🌊",
		verb = "Slam a ring of water out: boats and swimmers thrown away, you ride the crest",
		cooldown = 11,
		radius = 115, -- boats inside are thrown outward
		push = 96, -- at the middle; falls to edgePush at the edge
		edgePush = 34,
		lift = 46,
		swimRadius = 75, -- goblins in the water this close are washed away
		swimPush = 70,
		flinch = 130, -- pursuers this close are knocked back
		ride = 62, -- your own hop onto the crest
		surge = 30, -- and a surge forward (or the way you steer)
		boost = 1.4, -- seconds of boost after it
	},
	hook = { -- Corsair: a boarding hook that reels you in.
		name = "BOARDING HOOK",
		glyph = "⚔",
		verb = "Harpoon the boat ahead and reel in; reach it to BOARD (a carrier drops their treasure)",
		cooldown = 14,
		range = 170, -- studs to a rival hull
		cone = 0.72, -- it must be ahead of the bow (a dot product)
		reel = 70, -- studs/s faster than the target the Corsair closes
		reelTime = 2.4, -- seconds the line holds before it slips
		board = 24, -- studs between the hulls' middles (plus half their widths) that count as BOARDED
		lag = 0.35, -- when the Corsair's own client says it arrived, the server (which sees that hull a moment late, as
		-- that client saw the rival) also allows both boats' speeds along the line for this many seconds
		snap = 1.7, -- the line snaps if the gap grows past its starting length times this
		hitShove = 70, -- the boarded boat is shoved aside this hard...
		slow = 0.5, -- ...and keeps this share of its speed
		hullDamage = 24, -- to the boarded boat
		selfDamage = 12, -- the Corsair's own hull, for slamming alongside
		zip = 130, -- no boat in reach: the hook bites a rock this close and zips you toward it
	},
}
-- The showroom's order and what it says (1 to 5 pips each). Stats here are DESCRIPTIONS of the numbers above, kept
-- beside them so a retune is one file; the tests check every class has a row and an ability.
-- V13.2: speed pips are close together now (the band is 106 to 118); the difference is the rest of the row.
Config.BOAT_CLASSES = {
	{
		id = "skiff",
		role = "ESCAPE ARTIST",
		best = "Nimble and the best drifter; Nitro breaks free of anchors, hooks and whirlpools",
		worst = "Fragile: two hard crashes sink it",
		pips = { speed = 4, handling = 4, toughness = 1, air = 3, firepower = 1 },
	},
	{
		id = "cutter",
		role = "ALL-ROUNDER",
		best = "Steady, tough, three friends aboard, a deck cannon; RALLY HORN surges the whole convoy",
		worst = "A wide turner next to the small boats",
		pips = { speed = 3, handling = 3, toughness = 4, air = 2, firepower = 3 },
	},
	{
		id = "reefhopper",
		role = "STUNT BOAT",
		best = "Leaps off flat water, hops again in the air, quick tricks",
		worst = "Fragile and a little slow on the straight",
		pips = { speed = 3, handling = 4, toughness = 1, air = 5, firepower = 1 },
	},
	{
		id = "broadside",
		role = "GUNBOAT",
		best = "A three-gun volley and two cannon seats for friends",
		worst = "Wide-turning, a big target",
		pips = { speed = 2, handling = 2, toughness = 4, air = 1, firepower = 5 },
	},
	{
		id = "stormrunner",
		role = "STORM CHASER",
		best = "Faster in storms and near tornadoes; summons its own",
		worst = "Ordinary in calm water",
		pips = { speed = 3, handling = 3, toughness = 3, air = 4, firepower = 2 },
	},
	{
		id = "wraith",
		role = "PHANTOM",
		best = "The sharpest steering; slips aside and leaves a ghost",
		worst = "The most fragile hull in the fleet",
		pips = { speed = 4, handling = 5, toughness = 1, air = 3, firepower = 1 },
	},
	{
		id = "ironbelly",
		role = "BRUISER",
		best = "Shrugs off hits, rams anything aside, rescues swimmers",
		worst = "The heaviest, widest turner",
		pips = { speed = 2, handling = 1, toughness = 5, air = 1, firepower = 3 },
	},
	{
		id = "anchorjack",
		role = "ANCHOR",
		best = "Chains a rival boat to you, or swings round a rock and slingshots out",
		worst = "A plain sailer without its anchor",
		pips = { speed = 3, handling = 3, toughness = 3, air = 2, firepower = 3 },
	},
	{
		id = "wavebreaker",
		role = "WAVE MAKER",
		best = "A ring of water throws everything near it away; rides big waves farther",
		worst = "Must be in the thick of it to matter",
		pips = { speed = 3, handling = 3, toughness = 3, air = 3, firepower = 2 },
	},
	{
		id = "corsair",
		role = "BOARDER",
		best = "Hooks the boat ahead and reels in to board it: a carrier drops their treasure",
		worst = "Lightly built; boarding puts you right beside your target's guns",
		pips = { speed = 4, handling = 3, toughness = 2, air = 2, firepower = 4 },
	},
}
-- V13.2: EVERY BOAT'S BOW GUN, fired by its driver with a click (gamepad R2, the touch GUN button). A light shot built to
-- shove and splash: it never sinks a boat on its own, never knocks treasure loose (Corsair boarding, Broadside volleys,
-- swords, kegs and grapples still do), and never reaches anyone in the Port or at home.
Config.BOAT_GUN = {
	cooldown = 2.2,
	range = 240, -- studs: farther aims land at the most it can reach that way
	arc = 0.34, -- the aim must be in front of the bow (a dot product: about 70 degrees either side)
	radius = 12,
	damage = 5,
	knockback = 64,
	hullDamage = 12,
	boatPush = 74,
	sameBoatGrace = 1.0, -- a hull hit by a bow gun within this many seconds takes the next one at half strength
}
-- The Broadside's (and the Cutter's bow gun's) shot: built to shove and splash, not to sink. A ship's cannon at a
-- fort or on a patrol ship keeps CANNON_* below.
Config.BOAT_SHOT = {
	radius = 13,
	damage = 6,
	knockback = 70,
	hullDamage = 22,
	boatPush = 82,
}

-- Drift (hold C in a turn, at speed): the keel lets go and the boat swings round. Holding the
-- slide charges a burst that fires when you let go, in two levels.
Config.BOAT_DRIFT_MIN_SPEED = 0.38 -- Fraction of top speed needed to break the keel loose.
Config.BOAT_DRIFT_ANGLE = { math.rad(38), math.rad(58) } -- The hull swings out freely to the first angle and holds by the second.
Config.BOAT_DRIFT_SLIP_LOSS = 0.05 -- Speed shed while drifting and during the burst after (an ordinary slide sheds BOAT_SLIP_LOSS).
Config.BOAT_DRIFT_CHARGE = { 0.75, 1.7 } -- Charge needed for each level (about 0.6 s and 1.4 s of sliding).
Config.BOAT_MINI_KICK = { 20, 34 } -- Speed added at once (V6: 16, 28).
Config.BOAT_MINI_TIME = { 1.0, 1.6 } -- Seconds the raised top speed lasts.
Config.BOAT_MINI_MULT = 1.2 -- Top speed while a burst runs (V6: 1.16).

-- Hoops and kickers.
Config.BOAT_HOOP_KICK = 34 -- Speed a boost hoop adds along its arrow (V6: 30).
Config.BOAT_HOOP_TIME = 2 -- A hoop also boosts for this long.
-- Chains: a hoop taken within BOAT_CHAIN_WINDOW seconds of the last one kicks harder, by
-- BOAT_CHAIN_KICK for each hoop in the chain so far, up to BOAT_CHAIN_MAX steps (30, 35, ... 50).
Config.BOAT_CHAIN_WINDOW = 4
Config.BOAT_CHAIN_KICK = 7 -- (V6: 5)
Config.BOAT_CHAIN_MAX = 5 -- (V6: 4)
Config.BOAT_CHAIN_TOP = 8 -- A kick stops at the boat's boosted top speed plus this per link (a skiff: 210 to 242; V6 151 to 175).
Config.BOAT_KICK_SPEED = 76 -- Upward speed a kicker ramp gives a boat at BOAT_KICK_MIN_SPEED...
Config.BOAT_KICK_PER_SPEED = 0.2 -- ...plus this much for every stud/s faster (V9: a ramp at boost speed throws higher)...
Config.BOAT_KICK_MAX = 112 -- ...up to this: about 32 studs up and 2.2 s in the air, room for two or three tricks.
Config.BOAT_KICK_MIN_SPEED = 34 -- Slower than this and a kicker is only a bump.
-- V9: FORGIVING HOOPS. A hoop counts if the hull visibly touches it, not only if its middle passes the middle.
-- The check sweeps the hull from where it was last frame to where it is now (so nothing is stepped over at 240
-- studs/s or at 10 frames a second), and counts a pass if the hull crossed the hoop's plane within the hoop's
-- radius plus half the hull's width plus this:
Config.BOAT_HOOP_REACH = 2
Config.BOAT_HOOP_DEPTH = 0.6 -- A hull that ends a frame this share of its own length from the plane also counts (a glancing touch).

-- Crashes. The server watches each hull's velocity; a change the boat's own forces cannot
-- explain is a collision. Harder hits cost more, one hit never sinks a healthy boat, and a
-- hull left alone patches itself slowly, so a mistake is something you recover from.
Config.BOAT_IMPACT_WINDOW = 0.05 -- Seconds a crash is measured over (a collision lands in a frame or two).
Config.BOAT_IMPACT_MIN = 12 -- Unexplained speed change (studs/s) below this is only a bump.
Config.BOAT_IMPACT_DAMAGE = 1.5 -- Hull damage per stud/s above the minimum.
Config.BOAT_IMPACT_CAP = 0.45 -- One crash never takes more than this fraction of a hull.
Config.BOAT_IMPACT_GRACE = 0.7 -- Seconds after a crash when further bumps don't count.
Config.BOAT_SCRAPE_DAMAGE = 16 -- Hull damage per second while dragging fast over sand or rock.
Config.BOAT_SCRAPE_SPEED = 44 -- Slower than this, running aground costs nothing (V7: above a boat's land speed, so driving on land is free).
Config.BOAT_REPAIR_DELAY = 9 -- Seconds without damage before a hull starts patching itself.
Config.BOAT_REPAIR_RATE = 4 -- Hull points per second after that.
Config.BOAT_SINK_TIME = 7 -- Seconds a wreck takes to go under.
Config.BOAT_RESPAWN_TIME = 16 -- A sunk boat comes back at its dock after this long (V2: 22).
Config.BOAT_SLEEP_DISTANCE = 650 -- Empty boats farther than this from every player are frozen.

-- Who simulates a driven boat. true: the driver's own client runs BoatSim on the hull, so the
-- wheel answers at once; the server watches it and takes the boat back for a few seconds if it
-- moves in a way the physics could not (too fast, flying, teleporting). false: the server
-- simulates every boat, as V2 did; steering then lags by the driver's ping.
Config.BOAT_CLIENT_PHYSICS = true
Config.BOAT_SPEED_SLACK = 1.15 -- A driven boat may exceed its modelled top speed by this factor...
Config.BOAT_SPEED_MARGIN = 40 -- ...plus this (currents, waves, hoops), before it counts as cheating.
Config.BOAT_MAX_ALTITUDE = 130 -- Studs above the sea a hull can be (a super jump reaches about 57, off a ramp a little more; V7: 80).
Config.BOAT_STRIKE_TIME = 1.2 -- Seconds over a limit before the server takes the boat back.
Config.BOAT_RECLAIM_TIME = 5 -- Seconds the server then drives it before handing it back.

-- The skyship and the dive (V7) --------------------------------------------------------------------
-- Every raid starts aboard a flying ship over the middle of the sea (server/Skyship.lua). The raid
-- clock runs from the moment the bell goes; WINDOW seconds later whoever is still aboard is fired off.
-- Pursuit (V8): what lives on an island follows a thief out to sea (server/Pursuit.lua). Each form's own
-- numbers (speed, tell, rest) are beside its description there; these are the rules they all share.
-- V9: a pursuit no longer ends on a timer or a leash. It follows the thief ALMOST HOME and stops at the
-- sanctuary (SANCTUARY, below): danger stays close until the Hoard is in sight. What keeps it fair is pacing
-- (PACE), not distance: a pursuer that falls far behind surges, one that is close hangs just behind, and a
-- thief who loses speed (a rock, a missed hoop, a rival) is the one it catches.
Config.PURSUIT = {
	MAX = 14, -- Pursuers out at once in the whole sea: one per island, so this only guards against a bug.
	PER_TARGET = 2, -- At most this many island pursuers on one goblin (a thief carries one treasure, but a
	-- pursuer whose treasure was snatched may still be closing on its new holder).
	CHECK = 0.5, -- Seconds between looks for a new thief to follow.
	CLEAR = 70, -- A thief must be this far off the island's shore, on the water, before it sets out. (A form may
	-- set its own `clear`: V13.1's jade frogs and the Chill follow you into the water at once.)
	LEASH = 99999, -- V9: no distance leash (V8: 1100 studs from the shore). A form may still set its own.
	TIME = 150, -- Seconds a pursuit lasts at most: a backstop for one stuck behind an island, not a design limit (V8: 50).
	COOLDOWN = 25, -- Seconds before the same island can send its pursuer again (V8: 40, of a twelve-minute raid).
	FLINCH = 4, -- Seconds a pursuer reels from an explosion; the second one sends it home.
	MISS_REST = 1.6, -- After a strike that MISSED it rests only this long (its form's own rest is for a hit).
	-- Pacing: speeds are set from the gap to the thief, not fixed.
	SURGE_GAP = 320, -- Farther behind than this a pursuer surges at its form's `surge` speed.
	FAR_GAP = 900, -- Farther than this, out of the thief's sight behind them, it may resurface closer (see `catchUp`).
	CATCH_UP_TO = 420, -- ...to this far behind them, along their wake. Never in front, never within sight of their bow.
	STUCK_TIME = 3, -- Seconds blocked by land before it takes the long way (it resurfaces behind the thief).
	LIFT_GRACE = 3, -- After a pursuer launches a goblin high (the Guardian's ability), no world hit for this long.
	GRAVITY = 140, -- Studs/s/s on a pursuer thrown into the air (a ramp, a tornado).
}
-- V9, the SANCTUARY: the water round Goblin Cove. A pursuer that reaches it with its thief gives up there,
-- with a show of it; none enters it; the Leviathan turns back at its edge. It is marked on the water by a
-- ring of gold lantern buoys and on the minimap and map. (PvP is not affected: a rival can still catch you.)
Config.SANCTUARY = {
	RADIUS = 450, -- Studs from the Hoard: just off Goblin Cove's coast all round. The harbor mouth (the harbor jump)
	-- is 326 out and the docks about 210. (520 was tried first: Coral Atoll's shore was inside it, so its clam
	-- never got to chase anyone.)
	BUOYS = 28, -- Lantern buoys round the edge (only where there is water).
}
-- Sea mobs (V8): the ordinary life of the open water (server/SeaMobs.lua). A fixed number, placed once.
Config.SEA_MOBS = {
	SPREAD = 520, -- Studs from a region's middle that its mobs may be placed.
	HOME_CLEAR = 900, -- None this close to the Hoard: home water is quiet.
	SHORE_CLEAR = 150, -- None this close to any island's shore.
	LEASH = 420, -- A nibbler school gives up this far from where it lives.
	NIBBLER_SIGHT = 150,
	NIBBLER_SPEED = 128, -- A little faster than any class cruises (118 at most), slower than a boost. (V13.2; V13: 150.)
	NIBBLER_CHASE = 9,
	NIBBLER_HOLD = 5, -- Seconds they stay on a hull that does not jump.
	NIBBLER_BITE = 1.5, -- Hull lost each half second (never below IMPACT.HULL_FLOOR).
	NIBBLER_REST = 14,
	PUFFER_LIFT = 140, -- Studs/s up: about as high as a full super jump (86 was only a hop's worth: 18 studs).
	PUFFER_PUSH = 55,
	PUFFER_REST = 6,
	LANCER_SIGHT = 230,
	LANCER_TELL = 1.1, -- Seconds the line shows before it goes.
	LANCER_SPEED = 260,
	LANCER_RUN = 300, -- Studs it travels.
	LANCER_PUSH = 72,
	LANCER_HULL = 6,
	LANCER_REST = 12,
}
Config.STORM_CEILING = 200 -- Lightning and storm-seeding ignore goblins above this height (the skyship, a flight).
-- V13.2: THE SKYSHIP FLIES A ROUTE (shared/SkyRoute.lua, server/Skyship.lua). Through V13 it hung still over the middle
-- of the sea and its cannons reached every island, so the drop was a menu. Now it waits at one end of a route while
-- goblins board and aim (PREP: the cannons are LOCKED, by the server), then crosses the archipelago in PASS seconds; a
-- cannon throws about 1,200 studs across (DIVE.CANNON_SPEED), so what you can reach changes as it flies: fire when an
-- island you want is in reach, or pick one on the map and the ship fires you as it passes. Anyone still aboard when the
-- pass ends is fired at the nearest landing in reach. Each raid flies one of ROUTES (forwards or backwards), never the
-- same as the raid before, chosen and shown in the Port. The six-minute clock starts when the pass ends.
Config.SKYSHIP = {
	POSITION = Vector3.new(0, 540, -80), -- The deck's height (and where it is built). The sea's walls are 700 high.
	BEAM = 44,
	PREP = 10, -- Seconds aboard before the cannons unlock and the ship sets off (V13: 2, which a goblin never noticed).
	PASS = 32, -- Seconds the ship takes to fly its route, whatever its length (152 to 222 studs/s).
	WINDOW = 42, -- PREP + PASS: from boarding to the raid clock starting. (V13: 20 standing still.)
	-- V12: a goblin who comes aboard late in the window (a join, a respawn) is never fired off before this many
	-- seconds on the deck: a first-timer gets time to find a cannon. The raid's clock is not changed.
	MIN_DECK = 12,
	LATE_DECK = 24, -- A goblin who joins once the pass is over rides the ship's next lap this long before it fires them.
	TURN = 3, -- Seconds the ship takes to swing round at either end of its route (it flies back for late arrivals).
	-- Each route: a name for the Port's board and the map, and its points { x, z } (north is -Z). Every route reaches 6
	-- to 10 of the 16 major islands, and every island is in reach on at least two routes (tests/luau/Specs/SkyRouteSpec).
	ROUTES = {
		{ name = "THE WESTWIND", points = { { -2700, 2150 }, { 2700, -2450 } } },
		{ name = "THE EASTWIND", points = { { 2750, 2150 }, { -2650, -2450 } } },
		{ name = "THE NORTHERN ARC", points = { { -2750, 250 }, { 0, -1650 }, { 2750, 250 } } },
		{ name = "THE SOUTHERN SWEEP", points = { { -2750, -500 }, { -500, 1050 }, { 2750, -250 } } },
		{ name = "THE SPINE", points = { { 450, 2250 }, { -250, -2550 } } },
		{ name = "THE CINDER RUN", points = { { 1150, 2250 }, { 1750, 250 }, { 1550, -2550 } } },
		{ name = "THE NAVY RUN", points = { { -1450, 2250 }, { -1950, 250 }, { -1350, -2550 } } },
	},
}
Config.DIVE = {
	-- V8: the THROW gives the reach (a plain arc under GRAVITY, aimed where you look); the air gives
	-- control, never distance. See shared/Dive.lua.
	GRAVITY = 60, -- Studs/s^2 on a thrown goblin (the world's is 196: this is a long, readable arc).
	-- Tumble: no keys held. The arc you were given, with a little push from the keys.
	TUMBLE_STEER = 16, -- Studs/s^2 sideways: about 500 studs of correction over a full-sea flight.
	TUMBLE_FLOOR = 40, -- From a standstill (a hop off the wing) the keys can get you this fast.
	TUMBLE_SPIN = 2.4, -- Radians/s end over end.
	-- Glide: Space held. An air brake: the fall eases to GLIDE_SINK, the speed across bleeds to GLIDE_SPEED.
	GLIDE_SINK = 55,
	GLIDE_SPEED = 50, -- So a glide covers under a stud across per stud down (V7: 5.7 across per stud down).
	GLIDE_BRAKE = 2.4, -- Per second: how hard the fall is caught.
	GLIDE_DRAG = 0.9, -- Per second: how quickly the speed across is lost.
	GLIDE_STEER = 60,
	-- Dive: Shift held. Head first, down hard.
	PENCIL_GRAVITY = 170,
	PENCIL_FALL_MAX = 420,
	PENCIL_DRAG = 0.6,
	PENCIL_STEER = 28,
	PENCIL_FLOOR = 30,
	-- What throws.
	CANNON_SPEED = 215, -- The skyship's cannons: about 1,200 studs of reach from 540 up (SkyRoute.reach). V13.2; V13: 440,
	-- 3,560 studs, the whole sea from one spot.
	CANNON_ELEVATION = math.rad(32),
	CATAPULT_SPEED = 200, -- An island catapult: about 575 studs over level ground, more off a hill.
	CATAPULT_ELEVATION = math.rad(60), -- A high lob: it has walls and cliffs to clear (at 44 degrees all three fell short).
	MIN_SPEED = 14, -- Aimed straight down: a plop over the side.
	AIM_RANGE = 9000, -- The farthest point a client may ask a launcher to aim at.
	FUSE = 0.5, -- From Fire to launch (V7: 0.9).
	LOADED_TIMEOUT = 25, -- Seconds a goblin may sit in an island catapult before it tips them out.
	MAX_TIME = 45, -- A flight that has not come down by now is ended where it is.
	-- The sea: a fast goblin skips off it, each bounce smaller; the fourth touch is a swim.
	BOUNCE_UP = { 95, 66, 40 }, -- Studs/s up: about 75, 36 and 13 studs high.
	BOUNCE_KEEP = 0.45, -- Share of the speed across kept through each bounce...
	BOUNCE_MAX_SPEED = 150, -- ...and never more than this: three skips cover at most about 650 studs.
	BOUNCE_MIN_FALL = 62, -- Arriving slower than this (a glide is 55) is a plain landing in the water.
	BOUNCE_GRACE = 0.5, -- Seconds after a bounce before the sea can be touched again.
	-- The ground.
	OSTRICH_SPEED = 95, -- Hitting ground this fast goes in head first; braking with a glide lands on your feet.
	EMBED_TIME = 1.1, -- Seconds stuck in the ground.
	POP_SPEED = 62, -- The hop out.
}

-- V13.2: WORLD CHAOS (server/WorldChaos.lua, client/ChaosFx.lua). Every raid gets ONE of these, chosen when the Port
-- opens and shown there (name, icon, one line) before anyone picks a boat. During the raid it plays EPISODES: a big
-- physical event somewhere near goblins (never in the Port, never inside the sanctuary round home), telegraphed, then a
-- calm. Each episode is drawn differently (its size, count, shape and place), so no two raids play the same. Events hit
-- through the game's own rules: explosions are Blasts (every creature, sea mob, ship and mine already reacts to those),
-- boats are shoved through Boats.shove (with the world's hull floor: chaos batters, it never sinks), goblins through
-- Impact's grace (no juggling) and small damage, waves and whirlpools are part of the sea itself (shared/Sea.lua).
Config.CHAOS = {
	-- The order the Port's board lists them in, and what it says.
	EVENTS = {
		{
			id = "meteors",
			name = "METEOR MAYHEM",
			icon = "☄",
			line = "Meteor showers crash into the sea and the islands. Watch the sky for burning rings.",
		},
		{
			id = "kraken",
			name = "KRAKEN'S TANTRUM",
			icon = "🐙",
			line = "Giant tentacles burst up and swat boats sky-high. Bubbles mean MOVE.",
		},
		{
			id = "waves",
			name = "ROGUE WAVE RAMPAGE",
			icon = "🌊",
			line = "Walls of water roll across the sea: surf them, jump them, or get thrown.",
		},
		{
			id = "crossfire",
			name = "CANNONBALL CROSSFIRE",
			icon = "💣",
			line = "A rogue armada shells the sea. Dodge the rings, or lead your pursuers in.",
		},
		{
			id = "barrels",
			name = "BARREL APOCALYPSE",
			icon = "💥",
			line = "Fields of powder kegs drift in. One spark and the whole lot goes up.",
		},
		{
			id = "whirls",
			name = "WHIRLPOOL OUTBREAK",
			icon = "🌀",
			line = "Wandering whirlpools suck boats in, spin them round and fling them out.",
		},
		{
			id = "haunted",
			name = "HAUNTED SEAS",
			icon = "👻",
			line = "Ghost portals open: sail through one and come out of its twin. Phantom ships ram.",
		},
		{
			id = "thunder",
			name = "THUNDERSTRUCK",
			icon = "⚡",
			line = "Giant lightning strikes the busiest water: a shockwave throws boats, and SUPERCHARGES them.",
		},
	},
	FIRST = { 22, 34 }, -- Seconds into the six-minute clock before the first episode (time to land and steal).
	CALM = { 18, 30 }, -- Seconds of calm after an episode ends before the next one starts.
	LAST = 18, -- No new episode in the last this-many seconds.
	HOME_CLEAR = 650, -- Never centred this close to the Hoard (the sanctuary is 450).
	FOCUS_JITTER = { 80, 260 }, -- An episode is centred this far off the goblins it is aimed near (not on their heads).
	ALERT_RANGE = 900, -- Goblins this close to an episode get its warning banner.
	-- Each event's numbers. Ranges { a, b } are drawn afresh for each episode.
	meteors = {
		count = { 5, 9 },
		spread = { 180, 300 }, -- studs round the centre the meteors fall in
		gap = { 0.45, 0.85 }, -- seconds between them
		warn = 2.4, -- the burning ring before a meteor lands
		radius = 40, -- its blast
		launch = 76, -- boats this close are thrown...
		up = { 120, 170 }, -- ...this hard upward (studs/s) at the middle
		out = 85, -- ...and outward
		damage = 10,
		hull = 26,
		bigChance = 0.3, -- an episode may bring THE BIG ONE first: one meteor, all of it bigger
		bigScale = 1.8,
		bigWarn = 3.8,
	},
	kraken = {
		strikes = { 4, 6 },
		gap = { 1.6, 2.4 },
		warn = 1.5, -- bubbles before a tentacle rises
		area = { 160, 240 },
		sweepLength = 72, -- a sweeping tentacle's reach
		sweepArc = math.rad(120),
		sweepTime = 1.3,
		width = 14,
		swat = 115, -- sideways
		lift = 70,
		slamRadius = 42,
		slamUp = 125,
		tossUp = 190, -- a tentacle coming up under a boat
	},
	waves = {
		count = { 1, 2 },
		speed = { 58, 74 },
		height = { 20, 30 },
		width = { 30, 40 }, -- how thick the ridge is (studs either side of the crest)
		half = { 320, 480 }, -- half its length along the front
		start = 760, -- how far off the focus it starts (it rolls through it)
		push = 55, -- goblins swimming in the crest are carried this fast...
		lift = 26,
	},
	crossfire = {
		time = { 14, 18 },
		every = { 0.32, 0.5 }, -- seconds between shells
		zone = { 180, 250 }, -- the bombarded water's radius
		standoff = { 520, 650 }, -- how far off the armada lies
		roll = 0.45, -- chance the barrage rolls across the sea instead of holding still
		rollSpeed = 22,
		warn = 1.4,
		radius = 24,
		damage = 7,
		knockback = 78,
		hull = 16,
		push = 82,
		aimAtBoats = 0.6, -- share of shells aimed at a boat's path
	},
	barrels = {
		count = { 26, 40 },
		spread = { 120, 180 },
		powder = 0.7, -- share that explode
		life = 55, -- seconds before the field sinks
		max = 60, -- barrels on the whole sea at once
		touch = 5, -- studs beyond a hull's half-length that count as touching
		radius = 26,
		damage = 8,
		knockback = 85,
		hull = 18,
		push = 86,
		chain = 32, -- powder barrels this close to an explosion go up too...
		chainDelay = 0.16, -- ...this long after
		snapshot = 0.12, -- seconds between the positions sent to clients
	},
	whirls = {
		count = { 2, 4 },
		radius = { 70, 110 },
		spin = { 42, 58 },
		pull = { 26, 34 }, -- (grows toward the eye: shared/Sea.lua)
		dip = { 7, 12 },
		wander = { 6, 14 },
		life = { 22, 28 },
		spread = { 140, 380 },
		eye = 0.3, -- share of the radius that is the eye: a boat there is FLUNG
		fling = 120,
		flingUp = 95,
		flingRest = 2.5, -- a flung boat is left alone this long
	},
	haunted = {
		time = { 24, 30 },
		pairDistance = { 600, 900 },
		portalRadius = 22,
		shipEvery = { 5, 7.5 },
		shipSpeed = 115,
		shipLife = 9,
		ram = 18, -- studs: a ghost ship this close to a hull rams it
		ramPush = 110,
		volleyRange = 160,
		volleyEvery = 3.2,
	},
	thunder = {
		strikes = { 4, 7 },
		gap = { 1.4, 2.4 },
		warn = 2.0,
		area = { 220, 320 },
		ring = 170, -- the shockwave's reach
		ringTime = 1.1,
		push = 72,
		lift = 46,
		damage = 6,
		hull = 12,
		chain = 90, -- the bolt jumps between boats this close together...
		chainMax = 3, -- ...this many times
		charge = 1.6, -- seconds of free boost a struck boat gets: SUPERCHARGED
	},
}

-- The sixteen major islands and what is around them (V7) -------------------------------------------
-- A MAJOR island has a main treasure, something living or moving on it, and a tier. The rest are
-- supporting geography: Gull Rock, Twin Stacks and Pilgrim's Rock have nothing to take; the three
-- keys (Kelp Cay, Lantern Key, Driftwood Key) keep a small stash each AND a gear cache (below).
-- Difficulty is computed, not asserted: each factor is 0 to 3 and the tier follows their sum, so a
-- change to an island moves its tier.
--   guardian  what lives there and how hard it is to out-think      traverse  how hard the way to the
--   hazard    what the island does to a thief                       treasure is, on foot
--   extract   how hard the way HOME is (Navy base, distance)        gear      always 0 since V8: no treasure
--                                                                             needs equipment any more
-- tag: the kind of challenge. line: the one-sentence identity. alerts: see Alerts.lua.
Config.ISLAND_INFO = {
	Pebble = {
		major = true,
		tag = "NAVIGATION",
		line = "A quiet shingle spit: learn the route home.",
		g = 0,
		t = 0,
		h = 0,
		x = 0,
		r = 0,
	},
	Coral = {
		major = true,
		tag = "TIMING",
		line = "A giant clam that opens and shuts: take the pearl while it gapes.",
		g = 1,
		t = 0,
		h = 0,
		x = 1,
		r = 0,
	},
	Smuggler = {
		major = true,
		tag = "STEALTH",
		line = "A hidden stash behind a bell: do not ring it.",
		g = 0,
		t = 1,
		h = 1,
		x = 1,
		r = 0,
	},
	Windmill = {
		major = true,
		tag = "TIMING",
		line = "A windmill with a ram on the hill: the Golden Gear spins the blades up.",
		g = 1,
		t = 2,
		h = 2,
		x = 1,
		r = 0,
	},
	Cross = {
		major = true,
		tag = "STEALTH",
		line = "Statues that only move when nobody is looking at them.",
		g = 2,
		t = 1,
		h = 0,
		x = 1,
		r = 0,
	},
	Shoals = {
		major = true,
		tag = "ENVIRONMENT",
		line = "A wrecked fleet on a sandbar: a crab underfoot and cannons overhead.",
		g = 1,
		t = 1,
		h = 2,
		x = 2,
		r = 0,
	},
	Crystal = {
		major = true,
		tag = "TERRAIN",
		line = "Caves of crystal and a cave-in behind you, with an echo that follows.",
		g = 1,
		t = 2,
		h = 2,
		x = 1,
		r = 0,
	},
	Tangle = {
		major = true,
		tag = "SPEED",
		line = "Rope bridges that snap, and imps that carry your treasure off.",
		g = 2,
		t = 2,
		h = 2,
		x = 2,
		r = 0,
	},
	Tide = {
		major = true,
		tag = "FLOOD",
		line = "A vault that floods when you take the pearl: get out before the eel finds you.",
		g = 1,
		t = 2,
		h = 3,
		x = 2,
		r = 0,
		helps = "Rebreather",
	},
	Maelstrom = {
		major = true,
		tag = "BOAT SKILL",
		line = "A whirlpool with a fin in it: sail it, do not fight it.",
		g = 1,
		t = 1,
		h = 3,
		x = 2,
		r = 0,
	},
	Fort = {
		major = true,
		tag = "COMBAT",
		line = "The Navy's own fort: marines, turrets and a harbor chain.",
		g = 3,
		t = 2,
		h = 2,
		x = 3,
		r = 0,
	},
	Ember = {
		major = true,
		tag = "FIRE",
		line = "A volcano with the crown in its crater, and little fires that run ahead of you.",
		g = 1,
		t = 2,
		h = 3,
		x = 2,
		r = 0,
		helps = "CinderBoots",
	},
	Temple = {
		major = true,
		tag = "COMBAT",
		line = "The Sun Temple's Guardian: huge, loud and fair.",
		g = 3,
		t = 2,
		h = 2,
		x = 3,
		r = 0,
	},
	Frost = {
		major = true,
		tag = "CLIMB",
		line = "A glacier with a cold that follows you up it.",
		g = 1,
		t = 3,
		h = 2,
		x = 2,
		r = 0,
		helps = "FrostClaws",
	},
	Bone = {
		major = true,
		tag = "BOSS",
		line = "Leviathan's Rest: the sea itself is awake.",
		g = 3,
		t = 1,
		h = 3,
		x = 3,
		r = 0,
		boss = true,
	},
	Skull = {
		major = true,
		tag = "STEALTH",
		line = "A skull with a throne room, a sleeping captain and a ghost fleet.",
		g = 2,
		t = 3,
		h = 2,
		x = 3,
		r = 0,
	},
	-- Supporting geography.
	Gull = { major = false, tag = "WATCHPOST", line = "A bare rock with a view." },
	Twin = { major = false, tag = "ZIPLINE", line = "Two stacks joined by a zipline." },
	Pilgrim = { major = false, tag = "ZIPLINE", line = "A stack at the end of the Sun Spire's zipline." },
	Kelp = { major = false, tag = "CACHE", line = "A kelp cay: a small stash and a rebreather.", gear = "Rebreather" },
	Lantern = {
		major = false,
		tag = "CACHE",
		line = "A lighthouse key: a small stash, and a choice of cinder boots or frost claws.",
		gear = "CinderBoots",
		gear2 = "FrostClaws",
	},
	Driftwood = { major = false, tag = "WRECKAGE", line = "A driftwood key: a small stash among the bones of a wreck." },
}
-- Total of the factors, to a tier of 1 to 4.
function Config.islandTier(id)
	local info = Config.ISLAND_INFO[id]
	if not info or not info.major then
		return 0
	end
	local sum = info.g + info.t + info.h + info.x + info.r
	return sum <= 3 and 1 or (sum <= 6 and 2 or (sum <= 9 and 3 or 4))
end
for id, info in pairs(Config.ISLAND_INFO) do
	info.tier = Config.islandTier(id)
	info.id = id
end
Config.TIER_NAMES = { "EASY", "RISKY", "DANGEROUS", "DEADLY" }
Config.TIER_COLORS = {
	Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(255, 215, 80),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(255, 70, 70),
}

-- Gear: found in the world, never sold for Robux. Each piece changes one island's hazard a lot. V8: it is
-- OPTIONAL. (V7 refused the treasure on three islands without it; the playtest found that a chore, so every
-- treasure can now be taken bare-handed.) A cache on a key island hands it out for the rest of the raid, once
-- per goblin (Lantern Key offers boots OR claws: you carry one at a time, so you choose). Shinies can buy "start with it".
Config.REBREATHER_SWIM = 1.4 -- Swim speed with the rebreather, as a multiple.
Config.CLAWS_CHILL = 0.25 -- The Chill's drain with frost claws, as a multiple.
Config.GEAR = {
	Rebreather = {
		name = "Diver's Rebreather",
		short = "REBREATHER",
		island = "Kelp",
		for_ = "Tide",
		effect = "Swim at full speed with no stamina cost, and the flooded vault drains you less.",
		color = Color3.fromRGB(110, 230, 255),
	},
	CinderBoots = {
		name = "Cinder Boots",
		short = "CINDER BOOTS",
		island = "Lantern",
		for_ = "Ember",
		effect = "Lava, fire patches and lava bombs cannot hurt you.",
		color = Color3.fromRGB(255, 130, 60),
	},
	FrostClaws = {
		name = "Frost Claws",
		short = "FROST CLAWS",
		island = "Lantern",
		for_ = "Frost",
		effect = "The Chill drains a quarter as much stamina, and ice cannot throw you.",
		color = Color3.fromRGB(170, 230, 255),
	},
}

-- Regional alerts (V7, server/Alerts.lua). A theft puts its island on guard (level 0 to 3), and the
-- islands it is linked to by LINKS[island][other] times as much. Levels fall by DECAY per second.
Config.ALERT = {
	STEAL = 1.0, -- Level added to the robbed island.
	DECAY = 1 / 40, -- A level lasts about 40 seconds.
	WAKE_PER_LEVEL = 0.3, -- Creatures notice you from this much farther per level.
	NAVY_LEVEL = 2, -- At this level the Navy comes.
	NAVY_RANGE = 1800, -- Every patrol ship this close turns toward the island...
	NAVY_TIME = 35, -- ...for this long.
	CALL_GAP = 30,
	LINKS = {
		Tangle = { Fort = 0.8, Shoals = 0.5 },
		Fort = { Tangle = 0.8, Shoals = 0.4, Tide = 0.4 },
		Shoals = { Tide = 0.6, Kelp = 0.4, Tangle = 0.4 },
		Tide = { Shoals = 0.6, Kelp = 0.6 },
		Cross = { Pilgrim = 0.7, Temple = 0.6 },
		Temple = { Cross = 0.7, Pilgrim = 0.5, Frost = 0.4 },
		Windmill = { Crystal = 0.6, Smuggler = 0.4 },
		Crystal = { Windmill = 0.6, Twin = 0.6, Maelstrom = 0.4 },
		Maelstrom = { Crystal = 0.4, Windmill = 0.4 },
		Ember = { Skull = 0.6, Lantern = 0.6 },
		Skull = { Ember = 0.6, Lantern = 0.5 },
		Frost = { Bone = 0.6, Lantern = 0.4, Temple = 0.4 },
		Bone = { Frost = 0.6, Driftwood = 0.6, Temple = 0.3 },
		Smuggler = { Coral = 0.5, Pebble = 0.3 },
		Coral = { Smuggler = 0.5, Pebble = 0.4 },
		Pebble = { Coral = 0.4, Gull = 0.4 },
	},
}

-- Lasting progress (V7, V11: server/Progress.lua, Economy.lua, ProfileStore.lua) ---------------------------------------
-- SHINIES are what a goblin keeps; raid GOLD is what wins a raid. A raid pays PARTICIPATION to
-- everyone who was there for MIN_PRESENT seconds, PER_GOLD for each gold banked (up to GOLD_CAP), a WIN
-- bonus for the winner (a tie shares it) and an UNDERDOG bonus to a goblin who banked something and sits at or
-- below the middle. At most RAID_CAP a raid.
-- V9: raids are about half as long, so a raid pays a little over half what it did and Shinies per HOUR stay
-- about where V8 had them. (V8: participation 10, gold cap 30, win 25, underdog 5, cap 70, present 90 s.)
-- V11 economy (docs/GAME_DESIGN.md "V11: Goblin Life", the report's economy section): the raid formula is V9's.
-- A goblin who takes part earns about 6 (nothing banked) to 15 (one treasure) to 28 (several) a raid, a winner
-- about 40; roughly 9 raids an hour. Prices follow from that (shared/Catalog.lua): commons 25 to 80 (one to three
-- raids, sooner with the welcome Shinies), uncommons 80 to 150, rares 180 to 280, legendaries 600 to 700 (a few
-- hours), pets 100 to 220. Achievements pay 25 to 150 once each.
-- V13 economy (the report's economy model, docs/reports/2026-10-18-v13-goblin-port.md): a raid cycle is now about 7.4
-- minutes (60 s in the Port, 20 s launching, 360 s raiding), so about 8 raids an hour, not 9; and there is much more to
-- work toward (five boats, 37 more pets). PARTICIPATION rose from 6 to 8 and the cap from 42 to 50, and a raid pays for
-- a few DEEDS a goblin does anyway: taking a treasure from its spot, getting away from a pursuer to the sanctuary,
-- clean trick landings, snatching from a rival. Shinies per hour: about 70 for a goblin who never banks, 180 for one
-- treasure a raid, 260 for two, 340 for a regular winner. The first specialty boat (350) is one to two hours of play.
Config.PROGRESS = {
	STORE = "LootGoblinsProfile_v1", -- The same DataStore V7 wrote: V7 profiles are migrated in place (never reset).
	PARTICIPATION = 8, -- V13 (V9-V12: 6)
	PER_GOLD = 1,
	GOLD_CAP = 22,
	WIN = 15,
	UNDERDOG = 3,
	RAID_CAP = 50, -- V13 (V9-V12: 42)
	-- V13: each pays once a raid (tricks: per clean landing, up to tricksMax).
	DEEDS = { steal = 2, escape = 4, snatch = 3, trick = 1, tricksMax = 3 },
	MIN_PRESENT = 60,
	WELCOME = 60, -- Shinies on a goblin's first visit (new and migrated profiles): enough for a first cosmetic at once.
	AUTOSAVE = 60, -- Seconds between saves of a changed profile (each save also refreshes the session lock).
	LOCK_STALE = 180, -- A lock not refreshed for this long belongs to a server that is gone: it may be taken over.
	OPEN_RETRY = 4, -- Seconds between attempts to open a profile another server is still closing...
	OPEN_TRIES = 5, -- ...this many times before playing on unsaved and retrying in the background...
	BACKGROUND_RETRY = 20, -- ...every this many seconds.
	PRESETS = 3, -- Outfit presets per goblin.
	HISTORY = 40, -- Purchases remembered in the profile.
	RECEIPTS_KEEP = 500, -- Robux receipt ids remembered (so a re-sent receipt grants once).
	ACTIONS_PER_SECOND = 8, -- Shop requests a goblin may make; more are ignored.
	STUDIO_MOCK = true, -- In Studio without DataStore access, use an in-memory store (progress resets when Play stops).
}
Config.KIT_PRICE = 90 -- Starting a raid already carrying one piece of gear (Catalog kit_* items).
-- Five pets, each a different VERB rather than a different percentage. Equipped one at a time. Every one can be
-- bought with Shinies (Catalog); Robux is only ever a second way to the same pet. V11: cheaper (100 to 220, was
-- 120 to 200 for V7's longer raids, reordered by how much each helps), and the Shell Tortoise rests 45 s (V7: 30)
-- with its shell glowing when ready, so the one pet that touches player-versus-player is visible and rarer.
-- Pets can be changed only where nothing is chasing you: on the skyship, at the Hoard, or between raids.
-- V13: the bestiary grew to forty-two species, but there are still only a few ABILITIES (archetypes), and each pet
-- has one of them, so a rare or premium pet is never stronger, only different to look at. One pet out at a time.
-- The five V11 abilities keep their keys (the code asks Gear.petIs(player, "Crab") and so on, meaning "a pet with the
-- Crab's ability"); V13 adds the Mender (boat recovery). The Gilded Whelp (Robux only) has no ability at all.
Config.PET_ABILITIES = {
	Crab = { name = "TUG", glyph = "⚓", effect = "Boat calls (B) arrive on a 40% shorter wait." },
	Gull = { name = "SCOUT", glyph = "🔭", effect = "Spots the nearest waiting treasure and says how far it is." },
	Frog = { name = "SPRING", glyph = "💨", effect = "Your dash recharges 35% faster." },
	Tortoise = {
		name = "SHELL",
		glyph = "🛡",
		effect = "Bounces off one grapple catch, then rests 45 s. It glows while ready, for everyone to see.",
	},
	-- V13.1: Poltergoblin is switched off, so SPIRIT is about the knockout now (Config.KNOCKOUT).
	Ghost = { name = "SPIRIT", glyph = "👻", effect = "You wake from a knockout 40% sooner." },
	Mender = {
		name = "MENDER",
		glyph = "🔧",
		effect = "Your boat starts patching its hull after 4 s instead of 9, twice as fast.",
	},
}
local rgb = Color3.fromRGB
Config.PETS = {
	-- V11
	Crab = { name = "Tug Crab", ability = "Crab", color = rgb(235, 110, 90) },
	Gull = { name = "Scout Gull", ability = "Gull", color = rgb(240, 240, 245) },
	Frog = { name = "Spring Frog", ability = "Frog", color = rgb(110, 220, 110) },
	Tortoise = { name = "Shell Tortoise", ability = "Tortoise", color = rgb(110, 150, 90) },
	Ghost = { name = "Pocket Ghost", ability = "Ghost", color = rgb(190, 220, 255) },
	-- V13: ocean
	Inky = { name = "Inky", ability = "Mender", color = rgb(204, 92, 176) },
	Puffle = { name = "Puffle", ability = "Tortoise", color = rgb(250, 214, 120) },
	Nibs = { name = "Nibs the Shark", ability = "Frog", color = rgb(110, 132, 164) },
	Bubbles = { name = "Bubbles", ability = "Gull", color = rgb(255, 150, 112) },
	Wobble = { name = "Wobble", ability = "Ghost", color = rgb(244, 160, 236) },
	Twinkle = { name = "Twinkle", ability = "Frog", color = rgb(255, 140, 70) },
	Nudi = { name = "Nudi", ability = "Crab", color = rgb(140, 90, 220) },
	Tusk = { name = "Tusk the Narwhal", ability = "Mender", color = rgb(150, 170, 196) },
	Lumo = { name = "Lumo", ability = "Gull", color = rgb(110, 230, 210) },
	Otter = { name = "Kelp the Otter", ability = "Crab", color = rgb(132, 92, 62) },
	-- pirate
	Parrot = { name = "Captain Squawk", ability = "Gull", color = rgb(232, 50, 46) },
	Rat = { name = "Scuttlebutt", ability = "Crab", color = rgb(150, 146, 150) },
	Bat = { name = "Flittermouse", ability = "Gull", color = rgb(86, 64, 96) },
	Monkey = { name = "Rascal", ability = "Crab", color = rgb(150, 96, 56) },
	Ferret = { name = "Noodle", ability = "Frog", color = rgb(176, 130, 90) },
	Fuse = { name = "Fuse", ability = "Mender", color = rgb(255, 196, 70) },
	Chompers = { name = "Chompers", ability = "Tortoise", color = rgb(150, 96, 54) },
	-- magic
	Shard = { name = "Shard", ability = "Ghost", color = rgb(186, 120, 255) },
	Flurry = { name = "Flurry", ability = "Ghost", color = rgb(170, 228, 255) },
	Glimmer = { name = "Glimmer", ability = "Ghost", color = rgb(255, 236, 150) },
	Dubloon = { name = "Dubloon", ability = "Tortoise", color = rgb(255, 200, 64) },
	Rubble = { name = "Rubble", ability = "Tortoise", color = rgb(140, 132, 124) },
	Spore = { name = "Spore", ability = "Frog", color = rgb(226, 54, 52) },
	Moth = { name = "Lantern Moth", ability = "Gull", color = rgb(255, 180, 80) },
	Whelp = { name = "Gilded Whelp", ability = nil, color = rgb(255, 200, 60) }, -- Robux only: no ability
	-- island (the seven escape pets are earned by getting away from that island's creature; the rest are sold)
	Levi = { name = "Little Leviathan", ability = "Mender", color = rgb(36, 96, 110) },
	Sunny = { name = "Sunny", ability = "Tortoise", color = rgb(255, 196, 46) },
	Echo = { name = "Little Echo", ability = "Ghost", color = rgb(196, 120, 255) },
	Lamb = { name = "Lambkin", ability = "Frog", color = rgb(244, 238, 222) },
	Bones = { name = "Bones", ability = "Ghost", color = rgb(170, 255, 220) },
	Zap = { name = "Zap", ability = "Mender", color = rgb(110, 240, 255) },
	Peek = { name = "Peek", ability = "Gull", color = rgb(176, 170, 164) },
	Waddles = { name = "Waddles", ability = "Frog", color = rgb(36, 40, 52) },
	Cinderling = { name = "Cinderling", ability = "Mender", color = rgb(255, 120, 30) },
	Bonefish = { name = "Bonefish", ability = "Mender", color = rgb(236, 228, 206) },
	Clammy = { name = "Clammy", ability = "Crab", color = rgb(255, 176, 196) },
	Twig = { name = "Twig", ability = "Crab", color = rgb(96, 190, 84) },
}
Config.PET_MENDER_DELAY = 4 -- seconds without damage before a Mender's boat starts patching (Config.BOAT_REPAIR_DELAY is 9)
Config.PET_MENDER_RATE = 2 -- times BOAT_REPAIR_RATE
Config.PET_CRAB_RECALL = 0.6 -- Recall cooldown multiple.
Config.PET_FROG_DASH = 0.65 -- Dash cooldown multiple.
Config.PET_GHOST_COOLDOWN = 0.75 -- Poltergoblin cooldown multiple (while it is switched off: unused).
Config.PET_GHOST_KNOCKOUT = 0.6 -- V13.1: a SPIRIT pet's goblin is knocked out for this share of KNOCKOUT.TIME.
Config.PET_TORTOISE_REST = 45 -- Seconds before the shell works again (V7: 30).
Config.PET_GULL_RANGE = 1400 -- How far the gull sees.
-- Pets drawn on each client (client/Pets.lua): how far other goblins' pets are drawn, and the distance within which
-- they are updated every frame (to 140 studs every 2nd frame, beyond that every 4th; your own always every frame).
Config.PET_DRAW_RANGE = 360
Config.PET_FULL_RATE_RANGE = 50

-- Robux (V7, V11: server/Monetization.lua, server/Receipts.lua). NOTHING HERE IS ON SALE until a human:
--   1. creates the Game Pass (recommended for permanent items: Roblox itself remembers who owns it) or Developer
--      Product in the Creator Dashboard, with its own price and icon;
--   2. pastes its numeric id into `id` below (and sets `kind` to "pass" or "product" to match what was created);
--   3. sets SALES_ENABLED = true.
-- No id or price is invented here. Until then no purchase window ever opens: a premium item is hidden in live
-- servers, and in Studio it is shown, previewable and marked "not on sale yet" (SHOW_UNCONFIGURED_IN_STUDIO).
-- Every pet listed here is also sold for Shinies; the premium-only items are cosmetic.
-- Setup and testing: docs/MONETIZATION.md.
Config.MONETIZATION = {
	SALES_ENABLED = false,
	SHOW_UNCONFIGURED_IN_STUDIO = true,
	DUPLICATE_SHINIES = 150, -- A permanent item paid for twice: the second payment becomes this many Shinies.
	PRODUCTS = {
		pet_Crab = { kind = "pass", id = nil, grants = { "Crab" } },
		pet_Frog = { kind = "pass", id = nil, grants = { "Frog" } },
		pet_Gull = { kind = "pass", id = nil, grants = { "Gull" } },
		pet_Ghost = { kind = "pass", id = nil, grants = { "Ghost" } },
		pet_Tortoise = { kind = "pass", id = nil, grants = { "Tortoise" } },
		outfit_admiral = { kind = "pass", id = nil, grants = { "outfit_admiral" } },
		livery_starlit = { kind = "pass", id = nil, grants = { "livery_starlit" } },
		trail_aurora = { kind = "pass", id = nil, grants = { "trail_aurora" } },
		petskin_crab_gold = { kind = "pass", id = nil, grants = { "petskin_crab_gold" } },
		-- V13. Every boat is also earnable with Shinies (Catalog); a pass is only a shortcut. The Whelp and the Moon
		-- Jelly are show-only (no ability), so buying them buys no power.
		boat_reefhopper = { kind = "pass", id = nil, grants = { "boat_reefhopper" } },
		boat_wraith = { kind = "pass", id = nil, grants = { "boat_wraith" } },
		boat_stormrunner = { kind = "pass", id = nil, grants = { "boat_stormrunner" } },
		boat_ironbelly = { kind = "pass", id = nil, grants = { "boat_ironbelly" } },
		boat_broadside = { kind = "pass", id = nil, grants = { "boat_broadside" } },
		-- V13.2: the three new classes, also earnable with Shinies. No id: a human creates them in the Creator Dashboard.
		boat_anchorjack = { kind = "pass", id = nil, grants = { "boat_anchorjack" } },
		boat_wavebreaker = { kind = "pass", id = nil, grants = { "boat_wavebreaker" } },
		boat_corsair = { kind = "pass", id = nil, grants = { "boat_corsair" } },
		pet_Whelp = { kind = "pass", id = nil, grants = { "Whelp" } },
		petskin_wobble_moon = { kind = "pass", id = nil, grants = { "petskin_wobble_moon" } },
		-- A possible bundle (all eight unlockable boats, V13.2). No catalog item points at it, so the shop does not show
		-- it; it is here so a human who makes the pass has its grants ready.
		bundle_fleet = {
			kind = "pass",
			id = nil,
			grants = {
				"boat_reefhopper",
				"boat_wraith",
				"boat_stormrunner",
				"boat_ironbelly",
				"boat_broadside",
				"boat_anchorjack",
				"boat_wavebreaker",
				"boat_corsair",
			},
		},
	},
}

-- Navigation (V7). The compass strip only lists treasure this close (all nineteen across the top was the
-- clutter), and a carrier gets a waypoint arrow toward the Hoard.
Config.COMPASS_LOOT_RANGE = 1300
-- V9: NO TEXT ON THE HORIZON. Every sign in the world (island names, the sea's landmarks, lanes, courses,
-- ramps, currents) is a close-range label now; the map (M) and the minimap carry names and tiers. Short
-- prompts (E to steal...) are unchanged.
Config.WORLD_LABEL_RANGE = 220 -- Studs: a landmark's name shows only when you are nearly on it (V8: 420 to 700).
Config.ISLAND_SIGN_RANGE = 240 -- An island's name, from its middle (V8: 1,500: every island named across the sea).
Config.LOOT_TAG_RANGE = 170 -- A treasure's name and value over it (V8: 3,000, always on top: the whole map).
Config.WAYPOINT_HIDE_WITHIN = 90 -- The arrow goes away this close to the Hoard: you are there.

-- The Leviathan's body (server/Leviathan.lua): drawn by the Sleeper's tick, no health, no AI of its own.
-- V9: NO SPECIAL ATTACK. The V8 breach (a ring, then the head up through it) is gone. The danger is the body
-- and how CLOSE it is: it swims right behind a fleeing boat, matching its speed, all the way to the sanctuary.
-- It has momentum (it cannot brake like a boat), so a boat that loses speed (a rock, a missed hoop, a rival,
-- a bad landing) is run into. A clean, fast run is never touched. It still roars and lunges, and a lunge
-- falls just short of a boat that keeps its speed.
Config.LEVIATHAN = {
	SCALE = 2.6, -- Every part of it is this many times its V7 size (V8: 2.2; the head is now 57 x 36 x 68 studs).
	HUMPS = 11,
	NECK = 12,
	RADIUS = 150, -- Of the circle its back swims while it lurks.
	SWIM_SPEED = 22,
	LURK_MIN = 0.25, -- How much of its back shows when the Sleeper is hardly aware.
	GAP = 0.2, -- Radians between humps on the circle.
	-- The hunt.
	FOLLOW = 46, -- Studs between its snout and the boat's stern while it shadows a boat that keeps its speed.
	CLOSE_RATE = 40, -- Studs/s it gains on a boat while closing to FOLLOW from farther back (plus the boat's speed).
	SURGE_GAP = 300, -- Farther back than this it surges...
	SURGE_SPEED = 300, -- ...at this (a boost is 202, a full hoop chain 242: a surge catches anything).
	ACCEL = 150, -- Studs/s/s it can speed up...
	DECEL = 55, -- ...and slow down. It cannot stop like a boat: a boat that slows is caught.
	MIN_SPEED = 60, -- It never drops below this while hunting (it does not stop behind a stopped boat: it hits it).
	TURN = 2.2, -- Radians/s: wide turns, wider than a skiff's at speed (V8: 1.3). A drift gets inside it.
	SIGHT = 600, -- It may change to a nearer crewed boat within this of its head...
	SWITCH_RATIO = 0.55, -- ...only one this much nearer than its target...
	SWITCH_GAP = 5, -- ...and no more often than this.
	CONTACT = 18, -- Studs between its snout and the hull's nearest end that count as a catch.
	CONTACT_REST = 4, -- Seconds after a catch before it can catch the same boat again (it drops back to FOLLOW).
	CONTACT_HULL = 8, -- Hull damage of a catch (before IMPACT.HULL_SCALE; never below IMPACT.HULL_FLOOR).
	CONTACT_DAMAGE = 10, -- To the goblin it catches (V13.1: aboard too; plus KNOCKOUT.HIT for a carrier).
	-- V13.1 (the V13 playtest: "the leviathan needs to be able to attack"): the lunge is a real BITE now. A roar and
	-- jaws open for LUNGE_TELL (the tell), then it surges LUNGE_SPEED faster for LUNGE_TIME: a boat that keeps
	-- straight is caught and bitten; a boost, a hard turn or a jump gets away. V9: a near miss every time.
	LUNGE_GAP = 6, -- Seconds between lunges...
	LUNGE_TELL = 0.9, -- ...the roar before each...
	LUNGE_SPEED = 150, -- ...this much faster than the boat...
	LUNGE_TIME = 1.2, -- ...for this long.
	BITE_DAMAGE = 14, -- To the goblin aboard (plus KNOCKOUT.HIT for a carrier).
	BITE_HULL = 16,
	SHALLOW = 7, -- Water shallower than this (studs) it will not enter: it waits at the edge...
	SHALLOW_GIVE_UP = 10, -- ...and gives up after the boat has stayed in it this long.
	HUNT_TIME = 180, -- A backstop, not a design limit (V8: 55 s and a 2,400-stud leash; now the sanctuary ends it).
	FLINCH = 4.5, -- Seconds it reels from an explosion on its head; the third sends it home.
	WAKE_RADIUS = 70, -- Boats this close beside the swimming head are thrown aside by its bow wave...
	WAKE_PUSH = 58, -- ...this hard. No damage.
	THIEF_WINDOW = 90, -- Seconds after the Tooth is taken in which putting to sea starts a hunt.
}

-- Being hit by the world (V8, server/Impact.lua and Loot.knockLoose). Chaos should move you, not end you.
Config.IMPACT = {
	GRACE = 1.2, -- After a world hit lands, nothing else from the world lands on that goblin for this long.
	DAMAGE_SCALE = 0.55, -- World damage to goblins, as a share of what each source asks for.
	LAST_STAND = 30, -- A goblin with more health than this cannot be knocked out by one world hit (it leaves 1).
	-- V13.1: except a goblin carrying treasure: for a carrier, being hit is the danger (Config.KNOCKOUT).
	HULL_SCALE = 0.6, -- The same for hulls: world blasts (boulders, lightning, monsters) bite this much smaller.
	HULL_FLOOR = 0.12, -- A creature or sea-mob hit never takes a hull below this share of its health: only
	-- cannons, shells, mines, kegs and real crashes sink boats.
}
-- V13.1 (the V13 playtest): the KNOCKOUT. A goblin whose health runs out is not killed and respawned at home: they
-- are knocked out where they fall for TIME seconds, drop whatever they carry (it lies there, loose, for anyone), and
-- get up with full health. Nothing from the world takes treasure out of a goblin's hands any more (no creature, boss
-- or boulder steals): instead every hit that used to loosen a carrier's grip HURTS (HIT, on top of its own damage),
-- so a creature that keeps landing hits knocks a carrier out, and that is how treasure is lost to the world.
-- Rivals still steal with a sword, a keg, a cannon or a grapple catch (unchanged). server/Knockout.lua.
Config.KNOCKOUT = {
	TIME = 5, -- Seconds knocked out. (A SPIRIT pet: PET_GHOST_KNOCKOUT of this.)
	HIT = 22, -- Health a world hit takes from a CARRIER on top of its own damage: about four knock one out.
	WAKE_GRACE = 2, -- Seconds after getting up before the world can land another hit.
	WAIT = 9, -- Seconds a pursuer circles a knocked-out thief and their treasure before it goes home.
	VOID_Y = -250, -- A body below this has fallen out of the world: it is put back properly (a real respawn).
}
-- The two-strike grip (V8 to V13; RETIRED in V13.1 by the knockout above: Loot.knockLoose no longer drops treasure
-- for the world). An ordinary world hit did not knock treasure out of a carrier's hands: it LOOSENED their
-- grip for SLIP_TIME seconds (they are told). A second world hit inside that time drops it. A few rare,
-- clearly marked attacks (HEAVY) drop it at once. Once the world has made a goblin drop treasure, it cannot do
-- so again for RECOVER seconds. None of this applies to another goblin's sword, keg, cannon or grapple.
Config.GRIP = {
	SLIP_TIME = 6,
	RECOVER = 10,
	HEAVY = { guardianleap = true },
}

-- V9: TORNADOES (shared/Twister.lua, server/Tornadoes.lua, client/Twisters.lua). Independent of the storms: they
-- wander open water in fine weather. A tornado LIFTS whatever enters its funnel (a boat, a goblin, a pursuer, a
-- patrol ship) in a spiral up to its top and throws it out: a ride, not a trap. A driver can bail out at any
-- point with the jump key; a goblin is thrown into the skydive (glide, dive, water skips all work).
Config.TWISTER = {
	MAX = 3, -- At once on the whole sea.
	FIRST = 25, -- Seconds into a raid before the first.
	GAP = { 14, 26 }, -- Seconds between one ending and another starting.
	LIFE = { 70, 105 }, -- Seconds each lasts (plus FADE either side).
	FADE = 5,
	SPEED = { 8, 16 }, -- Studs/s it wanders.
	WANDER = 300, -- Studs from its alley's middle it may wander.
	HOME_CLEAR = 1100, -- Never this close to the Hoard.
	RADIUS = 30, -- Of the funnel at the water (it widens with height).
	FLARE = 1.7, -- The funnel's radius at the top, as a multiple of RADIUS.
	CATCH = 1.5, -- Things within this many radii are drawn in.
	HEIGHT = 190, -- The top of the funnel: things are thrown out there.
	RISE = 74, -- Studs/s up while inside: the ride to the top takes about 2.5 s.
	SWIRL = 58, -- Studs/s round the funnel.
	PULL = 3, -- How hard it holds things in toward its middle.
	CAPTURE = 5, -- Per second: how quickly motion across is turned into the swirl inside the funnel (a boat at
	-- 110 studs/s went straight through with 2.2; at 5 it is taken up).
	THROW = 95, -- Studs/s outward at the top...
	THROW_UP = 30, -- ...and up.
	BAIL = 120, -- Studs/s a boat is thrown the way it points when its driver bails out (the jump key)...
	BAIL_UP = 34,
	IGNORE = 2, -- ...after which the funnel ignores it this long (it would only pull it back in).
	GOBLIN_UP = 112, -- A goblin caught on foot or swimming is thrown into a skydive this fast upward...
	GOBLIN_SWIRL = 46, -- ...and round...
	GOBLIN_REHIT = 2.5, -- ...and can be caught again after this long (fall back in and it throws you again).
	GOBLIN_LOW = 45, -- Only goblins below this height are caught (one already high in it is mid-throw).
	HULL_DAMAGE = 0, -- A ride costs nothing.
	ALTITUDE = 300, -- The anti-cheat's altitude limit for a hull near a tornado or just thrown by one (normally BOAT_MAX_ALTITUDE).
	SPEED_ALLOW = 170, -- Extra speed the anti-cheat allows for the same.
	ALLOW_TIME = 7, -- Seconds after leaving a tornado that those allowances last.
	-- Where they wander: open water on the routes goblins sail (x, z), each a long way from any shore.
	ALLEYS = {
		{ -720, 560, "the West Run" },
		{ 860, 330, "the Eastern Reach" },
		{ 740, -420, "the Open Sea" },
		{ -560, -1560, "the Leviathan Road" },
		{ 470, -1640, "the Far North" },
		{ 1930, -1330, "the Cinders" },
		{ -2040, -150, "Navy Waters" },
		{ 2140, 300, "the Maelstrom Reach" },
	},
}

-- V9: BOAT TRICKS. In the air, the trick key (R, gamepad R1) throws the boat into a trick: a flat spin first, then
-- each further press in the same flight the next in a combo (corkscrew, front flip, double spin); A or D held: a
-- roll that way; S held: a backflip. A press during a trick is kept for when it ends. Each takes TIME seconds;
-- a hull still mid-trick when it lands comes down level anyway (a sketchy landing: no burst). Landing clean after
-- tricks pays a burst and hands back some boost cooldown: style, not gold.
Config.TRICK = {
	TIME = { spin = 0.45, roll = 0.5, flip = 0.6, corkscrew = 0.7 }, -- (a super jump is about 1.2 s in the air)
	MIN_HEIGHT = 5, -- The hull must be at least this far above the water to start one.
	KICK = 9, -- Speed added on a clean landing, per trick (up to MAX_PAID)...
	REFUND = 0.8, -- ...and seconds off the boost cooldown, per trick.
	MAX_PAID = 4,
}

-- V9: THE SUN TEMPLE GUARDIAN'S BOAT (server/Pursuit.lua, forms.Temple). When the Golden Idol's thief puts to sea
-- the Guardian leaps onto a tiny stone speedboat and chases them at an absurd speed. It turns wide and overshoots,
-- and every COOLDOWN seconds it can LAUNCH: a stone fist punches up out of the sea under the thief (marked first)
-- and throws them, boat and all, about 20 feet up. No damage to speak of, the treasure stays in their hands.
Config.GUARDIAN_BOAT = {
	SPEED = 250, -- Cruise while it closes (a skiff 135, a boost 202).
	SURGE = 360, -- "Mach 7": when it is far behind.
	ACCEL = 190,
	TURN = 1.9, -- Wide: at full speed it overshoots a boat that turns, then skids round.
	FOLLOW = 40, -- How close behind it hangs between launches.
	COOLDOWN = 9, -- Seconds between launches.
	REACH = 120, -- It launches when the thief is this close.
	TELL = 0.85, -- Seconds the mark shows before the fist comes up.
	RADIUS = 20, -- Of the mark.
	-- V13.1 (the V13 playtest: "literally needs to send your ship flying very high into the air and send it
	-- spinning"): up at 255 studs/s is about 165 studs high and 2.6 s in the air, tumbling end over end the whole
	-- way (BoatSim.tumble), landing level. V9: 118 (about 35 studs).
	LIFT = 255,
	PUSH = 70, -- Studs/s along the thief's way: it throws you on, not back.
	ALTITUDE = 330, -- Studs above the sea Boats.police allows a launched boat for LAUNCH_ALLOW seconds...
	LAUNCH_ALLOW = 8, -- ...(a driver's own hull is never this high).
	HULL = 4,
	LEAP_TIME = 1.6, -- The Guardian's leap from where it stands onto its boat.
}

-- V9: THE GHOST FLEET (server/GhostFleet.lua). Taking the Skull Chalice raises SHIPS ghost ships crewed by ghost
-- pirates. They sail after the thief together, spread out, firing marked volleys. Once the thief is DEPLOY studs
-- from Skull Rock's shore the pirates take to tiny rowing boats (DINGHIES, one or two from each ship) that chase
-- much faster than the ships and keep going to the sanctuary; the ships fall back into the fog.
Config.GHOST_FLEET = {
	SHIPS = 3,
	CREW = 4, -- Ghost pirates on each ship's deck.
	-- V13.1 (the V13 playtest: the ships got stuck and did not follow): ghost ships sail THROUGH land (they are
	-- ghosts), surge to catch up and, when the pirates take to the dinghies, keep sailing ALONGSIDE them all the
	-- way to the sanctuary instead of sinking into the fog. V9: 170 / 230, stopped by every rock.
	SHIP_SPEED = 190,
	SHIP_SURGE = 330,
	SHIP_TURN = 1.4,
	ESCORT = 150, -- Studs either side of the thief's wake the ships keep once the dinghies are out.
	ESCORT_VOLLEY_GAP = 7, -- Seconds between a ship's volleys while it escorts (the dinghies do most of the work).
	SPACING = 110, -- Studs apart across the thief's wake.
	VOLLEY_GAP = 4.5, -- Seconds between a ship's volleys.
	VOLLEY_RANGE = 360,
	VOLLEY_DELAY = 1.5,
	VOLLEY_SHOTS = 2,
	SHELL_RADIUS = 12,
	SHELL_HULL = 22, -- Before IMPACT.HULL_SCALE, never below the hull floor: ghosts batter, they do not sink.
	SHELL_PUSH = 60,
	DEPLOY = 650, -- Studs off Skull Rock's shore at which the dinghies go over the side.
	DINGHIES = 5, -- In all.
	DINGHY_SPEED = 190,
	DINGHY_SURGE = 290,
	DINGHY_TURN = 3.2,
	BOARD_REACH = 20, -- A pirate this close leaps aboard and lays into you (V13.1: a hit, Config.KNOCKOUT)...
	BOARD_TELL = 0.7, -- ...after waving its cutlass this long.
	BOARD_REST = 3.5, -- Fleet-wide seconds between leaps (V9: 6, when a leap loosened the grip).
	BOARD_DAMAGE = 10,
	SHIP_FADE = 14, -- (V9 to V13: seconds after the dinghies went before the ships sank. V13.1: they stay.)
	HEAD_START = 18, -- Seconds late if the Captain's shade was dozing (BestiaryMinor).
}

-- V9: how much bigger the guardians are than V8 (island bodies and their sea forms). The Crystal Echo is the
-- exception: it stays small (ECHO_SCALE shrinks its sea form).
Config.GUARDIAN_SCALE = {
	Guardian = 1.7,
	Watcher = 1.6,
	Crab = 1.6,
	Ram = 1.7,
	Eel = 1.6,
	Chill = 1.5,
	Clam = 1.5,
	Maw = 1.4,
	SeaForm = 1.6, -- Every sea form except the Echo's.
	ECHO = 0.55,
}

-- Recall (B): a boat for a goblin with none. See server/Recall.lua.
Config.RECALL_COOLDOWN = 45 -- Per goblin.
Config.RECALL_OFFSHORE = 520 -- Studs out from the shore the boat starts: about four seconds of sailing.
Config.RECALL_SHORE_MAX = 420 -- The goblin must be this near water a skiff can use.
Config.RECALL_BOAT_CLEAR = 70 -- No call while a free boat is this close.
Config.RECALL_ARRIVE = 45 -- The boat stops this far from the shore point.
-- V13.1 (the V13 playtest: "it comes in like a tesla, keep that, but it should stop reliably near you"): the called
-- boat races in at boost speed and then BRAKES HARD to a stop at its parking spot, the water nearest the caller (moved
-- along with them if they walk the shore), instead of letting go of the throttle and coasting past.
Config.RECALL_PARK = 10 -- Studs short of the parking spot it aims to stop (measured: 18 left it 65 from the caller).
Config.RECALL_BRAKE = 260 -- Studs/s/s of braking in the last stretch (it starts braking just in time for this).
Config.RECALL_HOLD = 30 -- Seconds a parked boat holds its spot for the caller (then it is an ordinary boat again).
Config.RECALL_HINT_EDGE = 80 -- (client) A carrier on foot with water this close is "at the edge": the B hint shows.
Config.RECALL_TIMEOUT = 32 -- Seconds before a boat that is stuck is put beside the shore.
Config.RECALL_EXTRA_MAX = 10 -- Skiffs and Cutters Recall may build when every one is busy (V13: 10, was 6; a goblin's
-- own specialty boat does not count: there is at most one each).

-- Carrying and fighting ---------------------------------------------------------
-- A carrier can swing, but it is a slow, short, tiring bash: the sword stays a way to contest loot
-- without making carriers harmless.
Config.CARRY_SWORD_COOLDOWN = 1.15
Config.CARRY_SWORD_RANGE = 6
Config.CARRY_SWORD_DAMAGE = 12
Config.CARRY_SWORD_KNOCKBACK = 22
Config.CARRY_SWING_STAMINA = 15 -- Before the loot's weight is added (CARRY_STAMINA_PER_WEIGHT): 17-26.

-- Cannons (island emplacements, the Cutter, practice range) -------------------------------------
Config.CANNON_SPEED = 220 -- Muzzle speed, studs/s. Balls use their own, lighter gravity.
Config.CANNON_GRAVITY = 95
Config.CANNON_COOLDOWN = 2.8
Config.CANNON_RADIUS = 14
Config.CANNON_DAMAGE = 30
Config.CANNON_KNOCKBACK = 85
Config.CANNON_HULL_DAMAGE = 80
Config.CANNON_BOAT_PUSH = 45

-- Powder kegs (G) --------------------------------------------------------------------------------
Config.KEG_MAX = 2
Config.KEG_RANGE = 80
Config.KEG_FUSE = 2.0
Config.KEG_THROW_GAP = 0.7
Config.KEG_RADIUS = 13
Config.KEG_DAMAGE = 30
Config.KEG_KNOCKBACK = 78
Config.KEG_HULL_DAMAGE = 60
Config.KEG_BOAT_PUSH = 55

-- Island mechanisms ---------------------------------------------------------------------------------
Config.GATE_OPEN_TIME = 28 -- A pulled lever holds its gate open this long.
Config.CHAIN_HOLD_TIME = 40 -- Fort Barnacle's harbor chain stays up this long: no ship leaves port.
-- Signal beacons: light one and every patrol ship within BEACON_RANGE sails over to look.
Config.BEACON_RANGE = 1100 -- (V4: 1500, on a wider sea)
Config.BEACON_TIME = 16 -- Seconds a ship ignores carriers while it goes to look.
Config.BEACON_BURN = 20 -- Seconds the fire shows.
Config.BEACON_COOLDOWN = 75 -- Before the same beacon can be lit again.
Config.WINDMILL_DAMAGE = 14
Config.WINDMILL_RAGE_TIME = 25

-- Storms and lightning ---------------------------------------------------------------------------------
Config.STORM_FIRST_DELAY = 40 -- Quiet time at the start of a raid. (V8: 50, of twelve minutes)
Config.STORM_GAP_MIN = 35 -- V9 (V8: 45). Seconds between new ambient storms (each lasts 90-125 s). (V3: 95-140, one at a time)
Config.STORM_GAP_MAX = 60
Config.STORM_MAX_AMBIENT = 3 -- At once. The sea is big; one storm would never be met.
Config.STORM_NEAR_MIN = 600 -- A storm starts this far from someone out at sea...
Config.STORM_NEAR_MAX = 1050 -- ...and blows back across their water.
Config.STORM_HOME_CLEAR = 750 -- Never seeded this close to the Hoard, or on a goblin this close to it.
Config.STORM_SPEED_MIN = 16
Config.STORM_SPEED_MAX = 28 -- A boat does 86-108, so you can always outrun one.
Config.STORM_FADE = 10 -- Seconds a storm takes to build and to fade.
Config.LIGHTNING_FIRST_DELAY = 6
Config.LIGHTNING_GAP_MIN = 2.4
Config.LIGHTNING_GAP_MAX = 4.2
Config.LIGHTNING_DELAY = 1.3 -- From marker to strike.
Config.LIGHTNING_DAMAGE = 24
Config.LIGHTNING_HULL_DAMAGE = 48
Config.TEMPEST_DISTANCE = 560 -- How far off the hunting storm starts.
Config.TEMPEST_SPEED = 42 -- Slower than any boat, faster than anyone on foot (V2: 15).
Config.TEMPEST_DURATION = 80

-- Waterspouts: twisters that wander inside a storm. One throws whatever it catches into the
-- air and off its line. They are tall and easy to see: a hazard to steer around, or a launch.
Config.SPOUT_COUNT = 2 -- Per ordinary storm.
Config.SPOUT_COUNT_TEMPEST = 3
Config.SPOUT_RADIUS = 18
Config.SPOUT_LIFT = 64 -- Upward speed it gives a boat or a goblin.
Config.SPOUT_PUSH = 26 -- Sideways speed, along its spin.
Config.SPOUT_HULL_DAMAGE = 14
Config.SPOUT_REHIT = 5 -- Seconds before the same spout can throw the same thing again.
Config.FRENZY_ROUGH = 0.45 -- Extra swell everywhere at FRENZY heat.

-- The Navy -----------------------------------------------------------------------------------------------
Config.NAVY_MAX = 3
Config.NAVY_SIGHT = 700 -- Sight range in clear weather (needs a clear line). (V3: 600)
Config.NAVY_SEARCH_TIME = 25 -- They check your last position this long, then go home.
Config.NAVY_LEAVE_TIME = 30 -- A ship heading home leaves the sea after this long.
Config.NAVY_STANDOFF = 95 -- Against a thief ashore they hold at this range and shell.
Config.NAVY_FIRE_RANGE = 320
Config.NAVY_FIRE_GAP = 3.6
Config.NAVY_FIRST_SHOT_DELAY = 5
Config.NAVY_SHELL_DELAY = 1.5 -- Marker to landing: time to read it and move.
Config.NAVY_SHELL_DAMAGE = 22
Config.NAVY_SHELL_HULL_DAMAGE = 55
Config.NAVY_SPREAD_RANGE = 140 -- Closer than this they fire a spread along your course.
Config.NAVY_SPREAD_SHOTS = 3
Config.NAVY_REPLAN = 1.0
Config.NAVY_COAST_WEIGHT = 3 -- How hard their routes keep off the coasts (a fast ship turns wide).
Config.NAVY_DISPATCH_GAP = 20
-- Where they come from: the fort if it is this close to the thief, otherwise the horizon, on
-- the side the thief has to sail home through.
Config.NAVY_BASE_RANGE = 1150 -- Navy Waters: Tangle Isle, Driftwood Key and the Serpent Channel are the fort's (V4: 1500 on a wider sea).
Config.NAVY_SPAWN_MIN = 750 -- Far enough that you see it coming and have time to choose a course.
Config.NAVY_SPAWN_MAX = 950
Config.NAVY_LEAD_MAX = 5 -- A hunter aims at most this many seconds ahead of the thief.
Config.NAVY_BLOCK_AHEAD = 280 -- A blocker sits this far along the thief's line home...
Config.NAVY_BLOCK_RELEASE = 150 -- ...and turns hunter when the thief gets this close.
Config.NAVY_RAM_RANGE = 170 -- Lined up within this range of a boat, a ship sounds its horn and charges.
Config.NAVY_RAM_TIME = 2.6 -- The charge holds one bearing for this long: turn and it misses.
Config.NAVY_RAM_GAP = 11
Config.NAVY_FIRST_RAM_DELAY = 9 -- A new ship does not charge until it has been out this long.
Config.NAVY_PEEL_TIME = 3.5 -- After a charge the ship swings out wide for this long before closing again.
Config.NAVY_PEEL_DISTANCE = 180
Config.NAVY_STATION = 110 -- Between charges it runs alongside at this range and fires.

-- Mines: a blocker sows them across the way home. Bright, still, and they go off for anyone.
Config.MINE_MAX = 10 -- On the whole sea at once (the oldest goes when another is laid).
Config.MINE_LAY_GAP = 2.4 -- Seconds between mines while a blocker is laying.
Config.MINE_LAY_RANGE = 480 -- Only while the thief is this close.
Config.MINE_ARM_TIME = 1.2
Config.MINE_LIFETIME = 40
Config.MINE_TRIGGER = 8 -- A hull or a swimmer this close sets it off.
Config.MINE_RADIUS = 16
Config.MINE_DAMAGE = 24
Config.MINE_HULL_DAMAGE = 70

-- Heat reactions --------------------------------------------------------------------------------------------
Config.FLARE_GAP = 6 -- ALERT and up: a carrier outside the ward fires a flare this often.

-- The Guardian's new moves -------------------------------------------------------------------------------
Config.GUARDIAN_LEAP_MIN = 30
Config.GUARDIAN_LEAP_MAX = 150 -- (V2: 95)
Config.GUARDIAN_LEAP_WINDUP = 0.9
Config.GUARDIAN_LEAP_RADIUS = 15
Config.GUARDIAN_LEAP_DAMAGE = 25
Config.GUARDIAN_LEAP_KNOCKBACK = 78
Config.GUARDIAN_LEAP_GAP = 4.5 -- (V2: 7)
Config.GUARDIAN_THROW_MIN = 70
Config.GUARDIAN_THROW_MAX = 260 -- Far enough to reach a boat pulling away (V2: 200).
Config.GUARDIAN_THROW_DELAY = 1.4
Config.GUARDIAN_THROW_RADIUS = 11
Config.GUARDIAN_THROW_GAP = 4 -- (V2: 6)
-- STOMP: up close it raises both fists, slams the ground, and a ring races outward along it.
-- Anyone standing on the ground when the ring passes is thrown and drops their loot. Be in the
-- air (jump, air jump, dash off a ledge) and it passes under you.
Config.GUARDIAN_STOMP_RANGE = 60 -- It stomps when its target is this close.
Config.GUARDIAN_STOMP_WINDUP = 0.8
Config.GUARDIAN_STOMP_RADIUS = 75 -- How far the ring travels.
Config.GUARDIAN_STOMP_SPEED = 55 -- Studs/s: the ring is 6 studs deep, so the jump has to be timed.
Config.GUARDIAN_STOMP_GAP = 6
Config.GUARDIAN_STOMP_DAMAGE = 14
Config.GUARDIAN_STOMP_KNOCKBACK = 46

-- Per-treasure trouble ---------------------------------------------------------------------------------------
Config.GULLS_REVEAL_TIME = 10
Config.FLOOD_TIME = 20
Config.SQUALL_TIME = 45
Config.ERUPTION_TIME = 26
Config.ERUPTION_BOMB_DELAY = 1.6
Config.AVALANCHE_BALLS = 6
Config.AVALANCHE_GAP = 2.4
Config.AVALANCHE_WARNING = 2
Config.KRAKEN_TIME = 36
Config.KRAKEN_GAP = 3
Config.KRAKEN_DELAY = 1.6
Config.GHOST_FOG_TIME = 80
Config.QUAKE_DELAY = 1.6

-- Island creatures (Creatures.lua, Bestiary.lua, BestiaryMinor.lua) --------------------------
-- One table per inhabitant. Speeds are studs/s: a goblin runs at 28, sprints at 38, and a
-- carrier runs at 21.5 to 27, so anything faster than 27 has to be out-thought, not outrun.
Config.CREATURES = {
	-- Crossroads Ruins. Statues that move only while nobody faces them, and carry treasure back.
	Watcher = {
		speed = 30,
		carrySpeed = 13, -- With treasure in its arms it is slow, and it moves whether watched or not.
		sight = 170, -- A goblin this close who is facing it holds it still...
		gaze = 0.35, -- ...where "facing" is this dot product or better (about 70 degrees either side).
		reach = 7.5, -- V9: the Watchers are 1.6 times the size (V8: 5)
		island = 340, -- They wake for carriers this close to the island's center, and never go farther.
		topple = 8, -- Seconds on its back after a blast.
		restAfter = 6, -- With no carrier about for this long they go back to their plinths.
	},
	-- Crystal Isle. A double that retraces a carrier's exact path, `delay` seconds behind.
	Echo = { delay = 3, reach = 4.5, damage = 16, push = 42, reform = 5, max = 3, island = 340 },
	-- Shipwreck Shoals. A crab that travels under the sand and comes up beneath carriers.
	Crab = {
		speed = 34,
		island = 370,
		erupt = 0.85, -- Seconds of warning ring before it comes up.
		radius = 14, -- V9: a bigger crab (V8: 10)
		toss = 72,
		damage = 10,
		exposed = 4, -- Seconds it sits above ground afterwards: the time to hit it.
		retreat = 20, -- Seconds it stays away after being blasted.
		grab = 1.2, -- Seconds it takes to rebury loose treasure it has reached.
	},
	-- Windmill Hills. A ram that charges in straight lines and tosses whatever it hits.
	Ram = {
		notice = 55,
		windup = 0.9,
		speed = 72,
		range = 115,
		toss = 88,
		lift = 56,
		damage = 6,
		rest = 3, -- Seconds between charges.
		stun = 3.5, -- Seconds dazed after charging into a cliff.
		roam = 70,
		rage = 25, -- Seconds of temper after the Golden Gear is taken: it charges without resting.
	},
	-- Tide Vault. An eel that circles the shallows and hunts whoever is in the water after a theft.
	Eel = {
		radius = 78,
		speed = 26,
		huntSpeed = 40,
		reach = 16, -- V9: a bigger eel (V8: 12)
		damage = 12,
		lift = 34,
		hunt = 30, -- Seconds it hunts after the pearl is taken.
		leash = 172,
		stun = 5,
		waterY = 5, -- A goblin whose root is below this is in the water.
	},
	-- Tangle Isle (V13.1, the V13 playtest): JADE FROGS, the treasure's guardians. They bound after a goblin carrying
	-- the Jade Frog anywhere on the island and POUNCE (a ring where you are, then a belly slam), and they hop into
	-- the sea after you (Pursuit forms.Tangle). They never take the treasure. Replaces V5's imps.
	JadeFrog = {
		count = 3,
		island = 380, -- They chase a carrier this close to the island's middle.
		hop = 64, -- Studs/s on the ground (in bounds of hop, about 26 studs each).
		hopLength = 26,
		pounce = 0.75, -- Seconds of ring before the slam: the time to get off it.
		reach = 10, -- The ring's radius.
		damage = 12,
		push = 62,
		lift = 46,
		rest = 1.4, -- Seconds after a pounce before that frog pounces again.
		range = 48, -- It pounces from this close.
	},
	-- Fort Barnacle. Marines who throw intruders over the wall.
	Marine = {
		patrol = 12,
		chase = 34,
		sight = 62,
		cone = 35, -- Degrees either side of where it faces.
		whistle = 0.7, -- Seconds between the whistle and the charge.
		reach = 5,
		throw = 105,
		lift = 82,
		chaseTime = 5,
		rest = 3,
		stun = 5,
	},
	-- Ember Isle. Cinderlings that run ahead of a carrier and set fire to the path.
	Cinder = {
		speed = 34,
		island = 250,
		ahead = 2.2, -- Seconds of the carrier's own movement they aim in front of.
		patch = 0.45, -- Seconds between fire patches.
		radius = 5.5,
		life = 5,
		burn = 8, -- Damage per half second standing in a patch.
		respawn = 25,
		quench = 20, -- A carrier standing in the sea this close: the cinderling jumps in after them and goes out.
	},
	-- Frost Spire. A drifting cold that drains stamina.
	Chill = {
		speed = 15,
		carrierSpeed = 21,
		aura = 40, -- V9: 40 (V8: 30), it is bigger
		wakeHeight = 30,
		leash = 270,
		scatter = 12,
		-- V13.1 (the V13 playtest: "the aurora gem island and boss needs a rework"): the Chill now ATTACKS a goblin
		-- carrying the Aurora Gem: HAIL, an icy ring where they are going, then a crash of ice (a hit), every
		-- hailEvery seconds while it can see them. It follows them down the mountain and into the sea.
		carrierSpeed2 = 44, -- Its speed after a carrier (V9: 21: it could never keep up)
		hailEvery = 3.4,
		hailTell = 1.0,
		hailRadius = 13,
		hailRange = 150,
		hailDamage = 12,
		hailLift = 40,
	},
	-- Leviathan's Rest. Something under the water that wakes to the noise of fast boats.
	Sleeper = {
		range = 240,
		quiet = 45, -- A boat slower than this makes no noise.
		rise = 0.9, -- Awareness per second from a boat at full noise: a skiff at top speed wakes it in about 2 s.
		fall = 0.12,
		strikes = 3,
		gap = 0.9,
		rest = 8,
		delay = 1.6,
		hull = 45,
		damage = 24,
	},
	-- Skull Rock. The Captain's shade dozes: the skull's eyes go dark. Steal then for a head start.
	Shade = { awake = 16, asleep = 9, headStart = 18 },
	-- Maelstrom Rock. A fin that circles the whirlpool and shoves boats along.
	Maw = { radius = 150, speed = 30, reach = 26, push = 70 }, -- V9: reach 26 (V8: 20), it is bigger
	-- Coral Atoll. The pearl's clam opens and shuts.
	Clam = { open = 5, shut = 3, toss = 58, damage = 8, reach = 6.5 },
	-- Goblin Cove. Gobbo the dockhand hands out kegs and shouts warnings.
	Gobbo = { kegEvery = 25, warnEvery = 30, navyRange = 900, stormRange = 850 },
}
Config.CHILL_REGEN = 0 -- Stamina regen multiplier inside the Chill: none comes back.
Config.CHILL_DRAIN = 6 -- Stamina lost per second inside it: a full bar is gone in 17 s.

-- Coins, runs and salvage (Coins.lua) ------------------------------------------------
-- Coins are picked up by passing through them. They are a reason to take the interesting line,
-- not a second economy: ten make 1 gold at the Hoard, and a raid pays out at most COIN_GOLD_CAP.
Config.COIN_BOAT_REACH = 13 -- A hull this close takes the coin: generous, so it works at full boost.
Config.COIN_FOOT_REACH = 7
Config.COIN_HEIGHT = 16 -- ...and within this height of it (the coins over a ramp hang high).
Config.COIN_RESPAWN = 80 -- Seconds before a taken coin comes back, for the next goblin along.
Config.COIN_BOOST_REFUND = 0.5 -- Seconds off the boat's boost cooldown, per coin.
Config.COIN_REPAIR = 1.5 -- Hull points patched, per coin.
Config.COINS_PER_GOLD = 10
Config.COIN_GOLD_CAP = 6 -- Gold from coins in one raid: about one middle treasure.
-- Timed runs.
Config.RUN_REACH = 20 -- A hull this close to a run's hoop has passed it.
Config.RUN_COINS = 6 -- Finishing a run, once a raid.
Config.RUN_PAR_COINS = 10 -- On top, the first time it is finished under par in a raid.
Config.RUN_GIVE_UP = 2.5 -- A run abandoned for this many times its par is forgotten.
-- Salvage crates.
Config.SALVAGE_MAX = 8 -- Afloat at once.
Config.SALVAGE_LIFETIME = 150
Config.SALVAGE_COINS = 8
Config.SALVAGE_REPAIR = 60
Config.SALVAGE_ADRIFT = 4 -- Set adrift on the runs at the start of each raid.

-- Sound and far-off effects (client: Effects.lua) -------------------------------------
-- A world sound is played where it happens and fades to silence at its range. Past the range
-- it is not played at all, so nothing is heard from across the sea.
Config.AUDIO = {
	NEAR = 15, -- Full volume inside this many studs (an ordinary sound: a keg, a splash).
	RANGE = 350, -- An ordinary sound is silent from here on. Callers give bigger sounds more.
	FLOOR = 0.004, -- Quieter than this where the player stands: not worth playing.
	-- A blast (a keg, a shell, a cannonball) carries farther than a splash: clear at 100 studs,
	-- faint at 300, gone by 600.
	BLAST_NEAR = 20,
	BLAST_RANGE = 600,
	-- Thunder carries: full inside a storm cell, a rumble as one approaches, silent beyond.
	-- (Ambient storms are seeded 600-1050 studs from a goblin at sea, so the first rumbles
	-- are the warning that one is coming.)
	THUNDER_NEAR = 150,
	THUNDER_RANGE = 900,
	-- At most VOICE_LIMIT world sounds of one kind within VOICE_WINDOW seconds.
	VOICE_LIMIT = 3,
	VOICE_WINDOW = 0.3,
	-- The compressor on the world's sound group: holds down a pile of blasts at once.
	COMPRESS_THRESHOLD = -14,
	COMPRESS_RATIO = 6,
	-- How far away things are still drawn for this player.
	DRAW_MARKER = 900, -- A danger marker (its column is 60 studs tall).
	DRAW_BLAST = 900,
	DRAW_BOLT = 1800, -- Lightning is tall and bright: it is a way to see where the storms are.
	FLASH_FULL = 300, -- The sky goes white for a bolt this close...
	FLASH_NONE = 1400, -- ...and does not flicker at all for one this far off.
	-- The server does not even send lightning and blast effects to goblins farther than this
	-- from them (Blast.lua): generous, since a marker is also the warning to get out of the way.
	SEND_RANGE = 1200,
	SEND_BOLT_RANGE = 2000,
}

-- Traversal ------------------------------------------------------------------
Config.ZIPLINE_SPEED = 110 -- The long lines are 550 studs: five seconds (V3: 90).

-- V13.3, THE LIVING PORT ----------------------------------------------------------------------------------------------
-- Seven Port games (server/Minigames.lua and one module each), the Captain's Quest Board, weekly and monthly
-- leaderboards, a pet sanctuary per goblin with pet expeditions, and challenges between goblins. Layouts (where things
-- stand) are in shared/PortGames.lua and shared/Habitat.lua; every number a playtest might change is here.
--
-- THE REWARD BUDGET (Shinies; docs/GAME_DESIGN.md has the full table). Raids stay the main way to earn: a typical raid
-- pays about 24 in 7.3 minutes (about 196 an hour). Around them, everything is small and CAPPED PER GOBLIN PER UTC DAY,
-- and the caps live in the goblin's saved profile, so leaving, rejoining or switching servers resets nothing:
--   Port games      1 to 6 a run (a medal, winning a heat of two or more, a personal best), at most 40 a day
--   daily quests    3 a day, 12 to 25 each (about 55 a day if all are done; unclaimed ones are paid at the reset)
--   weekly quests   3 a week, 50 to 100 each, and a cosmetic for finishing all three
--   leaderboards    tiers anyone can reach (10 to 35 a board a week) and placements (15 to 250), cosmetic prestige
--   expeditions     6 to 20 a trip, at most 30 a day, whatever the pet
--   challenges      4 for a win, 2 for a tie, at most 5 paid wins a day and 2 against the same goblin
-- Casual (30 min a day) about 150 a day, raids 60% of it; active (2 h) about 500, raids two thirds; skilled about 640.
-- Nothing here is ever sold for Robux, and nothing changes how strong a goblin is.

Config.PLAYGROUND = {
	-- Every finished run pays a little, by its medal (see each game's MEDALS); never more than the daily caps.
	REWARD = { played = 1, bronze = 1, silver = 2, gold = 4, winner = 1, best = 2 },
	DAILY_RUNS = 6, -- Paid runs per game per UTC day (a run after that still counts for bests, quests and boards).
	DAILY_SHINIES = 40, -- The most Shinies Port games pay one goblin in a UTC day.
	DAILY_BESTS = 3, -- Personal-best bonuses a day (a new best still counts as a best after that).
	LOBBY = 8, -- Seconds a heat waits for more goblins after the first steps in (a challenge skips it).
	COUNTDOWN = 3, -- 3, 2, 1, GO.
	RESULTS = 5, -- Seconds the results stay on the venue before it opens again.
	RAID_WARN = 15, -- A goblin signed up for the raid is warned this long before it leaves (it ends their game).
	INPUT_RATE = 12, -- Game inputs a goblin may send a second (a throw, a cheer, a shot); more are ignored.
	VENUE_DRAW = 320, -- (client) Studs from the camera within which a venue's moving parts are drawn.

	-- TINY BOAT REGATTA: one lap of the water round the Port in a Racing Tub (Config.BOAT_TYPES.racer).
	REGATTA = {
		MAX = 8,
		RADIUS = 600, -- The course: a ring this far round the island's middle (PortGames.ISLAND).
		CHECKPOINTS = 12, -- Every 30 degrees; all must be passed, in order.
		GATE_RADIUS = 70, -- A checkpoint is a stretch of water this wide, not a hoop.
		LIMIT = 80, -- Seconds after GO; anyone still out does not finish.
		MIN_TIME = 20, -- A lap faster than this is not believed (no score, no reward).
		MEDALS = { gold = 36, silver = 43, bronze = 54 }, -- Seconds (first guesses: nobody has raced it yet).
		REJOIN_AFTER = 2.5, -- Out of your tub this long: back at your last checkpoint, seated, at rest.
		SPLASH_EVERY = 4.5, -- The splash cannons: one shot each this often...
		SPLASH_WARN = 1.4, -- ...after a ring on the water this long...
		SPLASH_RADIUS = 20, -- ...throwing every tub inside it...
		SPLASH_LIFT = 72, -- ...this fast upwards...
		SPLASH_PUSH = 38, -- ...and this fast outwards.
		SPLASH_LEAD = 1.2, -- They aim this many seconds ahead of the nearest tub.
	},
	-- GRAPPLE GAUNTLET: a course in the air over the north-west water: swing rings, bounce pads, a beam and a zipline.
	GAUNTLET = {
		MAX_RUNNERS = 12, -- At once (every run is its own; a challenge starts two together).
		LIMIT = 180,
		MIN_TIME = 14,
		MEDALS = { gold = 40, silver = 55, bronze = 80 },
		FALL_Y = 3.5, -- A goblin this low over the water has fallen: back to the last checkpoint (the clock runs on).
	},
	-- CANNON GOLF: a tee cannon, three floating greens, one shot at each. Aim the way you look; hold to charge.
	GOLF = {
		TEES = 3, -- Three tee cannons side by side: three goblins can play at once.
		ELEVATION = math.rad(42),
		MIN_SPEED = 45,
		MAX_SPEED = 135, -- About 300 studs on flat water: the far green needs most of it.
		POWER_CYCLE = 1.5, -- (client) Seconds for the power meter to go up and down once.
		YAW_MAX = 70, -- Degrees either side of the tee's own heading.
		RETURN = 1.8, -- Seconds after landing before you are back in the cannon for the next hole.
		LIMIT = 150,
		CUP = 4, -- Studs from the pin: in the cup...
		NEAR = 8, -- ...so close...
		GREEN = 15, -- ...on the green...
		FRINGE = 26, -- ...on the fringe. Farther: a splash.
		POINTS = { cup = 100, near = 70, green = 45, fringe = 20, miss = 0 },
		MEDALS = { gold = 200, silver = 120, bronze = 50 }, -- Points out of 300.
	},
	-- PET DERBY: your pet (or a loaned crab) races three or more round an oval with hurdles. CHEER as it reaches one.
	DERBY = {
		FIELD = 4, -- Bots from the menagerie fill the field to this many.
		MAX = 6,
		SPEED = 9.5, -- Every pet, whatever it is: rarity is never speed.
		ZOOM = 1.5, -- A clean jump: this much faster...
		ZOOM_TIME = 1.2, -- ...for this long.
		TRIP = 0.3, -- A missed or mistimed hurdle: this share of speed...
		TRIP_TIME = 1.0, -- ...for this long (a tumble).
		STUMBLE = 0.4, -- A cheer with no hurdle near: a little stumble (no mashing).
		EARLY = 0.6, -- A cheer up to this long before the hurdle is clean...
		LATE = 0.18, -- ...and up to this long after it (the server sees the pet a moment late)...
		TOO_EARLY = 1.3, -- ...earlier than EARLY but within this: it jumps too soon and trips.
		SNIFF = 0.6, -- Every pet stops once to sniff a flower (the same pause for all; only where differs).
		BOT_SKILL = 0.62, -- A bot pet's chance of a clean jump.
		LIMIT = 70,
	},
	-- TREASURE TOSS: throw chests into moving baskets, a rowboat, a parrot's perch and the Goblin King's mouth.
	TOSS = {
		ROUND = 40,
		MAX = 6,
		SPEED = 74, -- Every throw leaves this fast, the way you look...
		GRAVITY = 60, -- ...under the dive's readable gravity (the world's 196 makes a throw a lob of 25 studs).
		RELOAD = 0.55,
		PITCH_MIN = -10, -- Degrees: a throw is between this and PITCH_MAX above level,
		PITCH_MAX = 65,
		YAW_MAX = 80, -- and within this of the booth's facing.
		CHEST = 1.2, -- The chest's own radius.
		MEDALS = { gold = 40, silver = 22, bronze = 8 },
	},
	-- TARGET SHIP GALLERY: man a shore cannon and sink the cut-out pirate fleet sailing past.
	GALLERY = {
		ROUND = 45,
		STATIONS = 4,
		SPEED = 220, -- The island cannons' muzzle speed and gravity (Config.CANNON_SPEED, CANNON_GRAVITY).
		GRAVITY = 95,
		RELOAD = 1.1,
		DOWN_TIME = 2.6, -- A hit ship keels over and comes back up after this long.
		BALL = 1.6,
		MEDALS = { gold = 36, silver = 20, bronze = 8 },
	},
	-- CRAB CHAOS: a crate of crabs bursts on the beach. Catch them (run into them; a dash helps).
	CRABS = {
		ROUND = 45,
		MAX = 8,
		COUNT = 16,
		GOLDEN = 2, -- Golden crabs: worth GOLDEN_POINTS, faster, burrow more.
		GOLDEN_POINTS = 3,
		CATCH = 3.6, -- Studs from a goblin's middle.
		WANDER = 5,
		FLEE = 15, -- Slower than any running goblin (21 to 38), but they turn.
		GOLD_FLEE = 19,
		SCARE = 14, -- A goblin this close sends a crab running.
		JINK = 0.6, -- Seconds between zigzags.
		BURROW_NEAR = 6, -- Cornered this close, a crab may burrow...
		BURROW_CHANCE = 0.3,
		BURROW_TIME = 1.4, -- ...and come up 12 to 20 studs away after this.
		BURROW_REST = 5,
		ALL_BONUS = 5, -- Every crab caught before the end: everyone in the round scores this many more.
		MEDALS = { gold = 8, silver = 5, bronze = 2 },
	},
}

-- THE CAPTAIN'S QUEST BOARD (server/Quests.lua, shared/Seasons.lua). Three daily and three weekly quests, the same for
-- everyone on the day (so goblins can do them together). Resets: every day at 00:00 UTC, every Monday 00:00 UTC.
-- Progress is the server's, saved in the profile; a finished quest nobody claimed is paid at the reset, never lost.
Config.QUESTS = {
	DAILY = 3,
	WEEKLY = 3,
	REWARD = { easy = 12, medium = 18, hard = 25 }, -- Daily.
	WEEKLY_REWARD = { easy = 50, medium = 75, hard = 100 },
	BUNDLE_SHINIES = 60, -- All three weekly quests claimed: the week's cosmetic, or this if it is already owned.
}

-- LEADERBOARDS (server/Leaderboards.lua, shared/Seasons.lua). Weekly: the biggest single-raid haul, the fastest
-- Regatta, the best Cannon Golf round. Monthly: the PIRATE CHAMPIONSHIP (the sum of a goblin's best CHAMPION_RAIDS raid
-- hauls of the month: skill, not hours) and the fastest Gauntlet. Every score is the server's own measurement. Rewards
-- are paid to each goblin's own profile after the period ends (whenever they are next in a server), once.
Config.SEASONS = {
	CHAMPION_RAIDS = 5,
	SETTLE = 900, -- Seconds after a period ends before its final standings are written (late saves land first).
	REFRESH = 120, -- Seconds between reads of each board's top ten.
	WRITE_GAP = 20, -- A goblin's improved score is written at most this often per board.
	SHOW = 10, -- Rows on a board.
	HALL = 100, -- Places kept in the final standings (placement rewards reach this far).
	KEEP = 8, -- Periods of a goblin's own scores kept in their profile.
	GIVE_UP_DAYS = 14, -- Final standings still missing after this: the tier reward is paid without a placement.
	-- Placement rewards (Shinies) by rank, per period kind.
	PLACE = {
		week = {
			{ rank = 1, shinies = 100 },
			{ rank = 3, shinies = 60 },
			{ rank = 10, shinies = 40 },
			{ rank = 100, shinies = 15 },
		},
		month = {
			{ rank = 1, shinies = 250 },
			{ rank = 3, shinies = 150 },
			{ rank = 10, shinies = 80 },
			{ rank = 100, shinies = 30 },
		},
	},
	TIER = { week = { bronze = 10, silver = 20, gold = 35 }, month = { bronze = 25, silver = 50, gold = 80 } },
}

-- THE PET SANCTUARY (server/Sanctuary.lua, client/Sanctuary.lua, shared/Habitat.lua). Every goblin in the server has a
-- little floating isle over the Port where the pets they own wander, eat, chase a ball and come running to a bell.
-- (Not Config.SANCTUARY: that is V9's safe water round Goblin Cove.)
Config.PET_ISLES = {
	RINGS = { { radius = 250, y = 190, count = 10 }, { radius = 410, y = 230, count = 22 } }, -- 32 isles.
	ISLE = 30, -- An isle's radius.
	RESIDENTS = 12, -- Pets shown on an isle at once (the owner picks them; the newest first otherwise).
	DRAW = 240, -- (client) An isle's pets are animated only within this of the camera.
	FEED_GAP = 12, -- Seconds between feedings (anyone on the isle can feed, the owner's pets come running).
	TOY_GAP = 2.5,
	BELL_GAP = 8,
}
-- PET EXPEDITIONS: send a pet you own scavenging; it comes back with Shinies on its own clock (the server's), even
-- while you are offline. Small on purpose: at most DAILY_CAP a UTC day, whatever the pet; a rare pet earns no more.
Config.EXPEDITIONS = {
	DAILY_CAP = 30,
	TRIPS = {
		{ id = "shore", name = "Shore Scavenge", hours = 2, shinies = 6 },
		{ id = "reef", name = "Reef Run", hours = 6, shinies = 12 },
		{ id = "voyage", name = "Long Voyage", hours = 12, shinies = 20 },
	},
}

-- CHALLENGES (server/Challenges.lua): ask a goblin in the Port to a game. Two of you, one heat, no matchmaking.
Config.CHALLENGES = {
	INVITE_TIME = 20, -- Seconds an invitation waits for an answer.
	GAP = 3, -- Seconds between invitations from one goblin.
	WIN = 4,
	TIE = 2,
	DAILY_PAID = 5, -- Paid challenge wins a day...
	PER_OPPONENT = 2, -- ...and against any one goblin.
	REMATCH = 15, -- Seconds both have to press REMATCH.
}

return Config

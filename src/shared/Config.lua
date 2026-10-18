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
Config.INTERMISSION = 10 -- V9 (V8: 12). Spent on the deck: results, then pick where to land.
Config.FIRST_INTERMISSION = 6 -- Gives the first players time to load in.
Config.RESPAWN_TIME = 3

-- Movement -------------------------------------------------------------------
-- Running is fast and free. Stamina never slows a normal run: it pays for the exceptional
-- moves (sprint, dash, air jump, a carrier's sword swing).
Config.WALK_SPEED = 28 -- Running. (V2 jogged at 20.)
Config.JUMP_POWER = 56 -- Roblox's default is 50: a little higher and longer.
Config.WATER_SPEED_MULT = 0.85 -- Wading or swimming. Carry and spirit speed stack with it.
Config.WATER_ROOT_Y = 3 -- A root lower than this is standing or swimming in the sea.

-- Sprint (hold Shift): a burst on top of the run, on land or in the water. Not in a seat.
Config.SPRINT_MULT = 1.36 -- 28 -> 38 empty-handed.
Config.CARRY_SPRINT_MULT = 1.25 -- Carriers run at 21-27 and sprint at 27-34.
Config.STAMINA_MAX = 100
Config.STAMINA_DRAIN = 11 -- Per second of sprinting: a full bar lasts 9 s.
Config.STAMINA_REGEN = 32 -- Per second, once you stop spending.
Config.STAMINA_REGEN_DELAY = 0.6 -- Pause after spending before stamina comes back.
Config.STAMINA_RECOVER = 25 -- Run it dry and you're winded (no sprint) until it refills this far.
-- Loot makes every stamina cost bigger instead of making you slow: each unit of the treasure's
-- weight adds this much to sprint drain and to the cost of a dash, an air jump or a swing.
Config.CARRY_STAMINA_PER_WEIGHT = 0.12 -- Leviathan Tooth (weight 6): everything costs 1.72x.

-- Dash (C): a short burst the way you are moving, on the ground or in the air. It is the dodge:
-- out of a marked circle, across a gap, away from a sword.
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
Config.GRAPPLE_CARRY_COOLDOWN = 5 -- A carrier's pull: usable, but not spammable.
Config.GRAPPLE_POP_SPEED = 42 -- Upward hop at the end of a pull, to climb onto ledges.
Config.GRAPPLE_KEEP_SPEED = 0.6 -- How much of the pull's sideways speed you keep when it ends.
Config.GRAPPLE_BOAT_ASSIST = 18 -- Aim passing this close to a boat hooks the boat (a fast boat is ahead of where you see it).

-- Poltergoblin (was Soul Unbound, Yone's E) ----------------------------------------
-- E leaves your body behind and sends your spirit out. Whatever loot the spirit
-- holds rides the tether back to the body.
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
Config.BOAT_TYPES = {
	skiff = {
		name = "Skiff",
		size = Vector3.new(9, 3, 20),
		draft = 1.3,
		density = 0.75,
		accel = 100, -- (V6: 84, V2: 44)
		maxSpeed = 135, -- (V6: 108, V2: 72)
		turn = 2.5, -- (V6: 2.1)
		turnFade = 230, -- (V6: 150) Slower to lose its bite: a V7 skiff at chain speed turns about as tightly as V6's did.
		grip = 3.4,
		driftGrip = 0.35,
		driftTurn = 1.65,
		lean = 40,
		health = 160,
		crashTaken = 1,
		ramPower = 1,
		passengers = 1,
	},
	cutter = {
		name = "Cutter",
		size = Vector3.new(14, 4, 34),
		draft = 2.1,
		density = 0.8,
		accel = 68, -- (V6: 56, V2: 28)
		maxSpeed = 104, -- (V6: 86, V2: 56)
		turn = 1.7, -- (V6: 1.45)
		turnFade = 190, -- (V6: 130)
		grip = 2.7,
		driftGrip = 0.45,
		driftTurn = 1.4,
		lean = 24,
		health = 420,
		crashTaken = 0.6,
		ramPower = 1.8,
		passengers = 3,
		cannons = true,
	},
	navy = {
		name = "Patrol Ship",
		size = Vector3.new(16, 6, 42),
		draft = 3.8,
		density = 0.85,
		accel = 68, -- (V6: 58, V2: 27)
		maxSpeed = 106, -- (V6: 88, V2: 54) Slower than an empty skiff, a touch faster than a cutter.
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
}
Config.BOAT_BOOST_MULT = 1.5 -- Top speed while boosting (a skiff: 202; V6: 1.4).
Config.BOAT_BOOST_THRUST = 2.4 -- (V6: 2.1)
Config.BOAT_BOOST_TIME = 2.4 -- (V6: 2.2)
Config.BOAT_BOOST_COOLDOWN = 5 -- (V6: 5.5, V2: 7)
Config.BOAT_BOOST_PUNCH = 14 -- Speed added the moment a boost starts: the kick in the back.
Config.BOAT_LAUNCH_PUNCH = 0.9 -- Extra thrust from a standstill, fading out by half speed.
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
Config.BOAT_SUPER_MIN = 150
Config.BOAT_SUPER_FULL = 215
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
	CLEAR = 70, -- A thief must be this far off the island's shore, on the water, before it sets out.
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
	NIBBLER_SPEED = 150, -- A little faster than a cruising skiff (135), slower than a boost.
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
Config.SKYSHIP = {
	POSITION = Vector3.new(0, 540, -80), -- Centre of the deck. The sea's walls are 700 high.
	BEAM = 44,
	-- V9: the deployment window is 20 s (V8: 40, V7: 28) and the six-minute clock starts when it closes (Raid.lua).
	-- A goblin can climb into a cannon and aim during the intermission; the cannons fire from COUNTDOWN on.
	WINDOW = 20,
	COUNTDOWN = 2, -- The cannons unlock this long after the raid starts (so a crowd goes together). (V8: 3)
	-- V12: a goblin who comes aboard late in the window (a join, a respawn) is never fired off before this many
	-- seconds on the deck: a first-timer gets time to find a cannon. The raid's clock is not changed.
	MIN_DECK = 12,
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
	CANNON_SPEED = 440, -- The skyship's cannons: 3,560 studs of reach from 540 up (the farthest island is 3,130 away).
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
Config.PROGRESS = {
	STORE = "LootGoblinsProfile_v1", -- The same DataStore V7 wrote: V7 profiles are migrated in place (never reset).
	PARTICIPATION = 6,
	PER_GOLD = 1,
	GOLD_CAP = 22,
	WIN = 15,
	UNDERDOG = 3,
	RAID_CAP = 42,
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
Config.PETS = {
	Crab = {
		name = "Tug Crab",
		price = 100,
		color = Color3.fromRGB(235, 110, 90),
		effect = "Boat calls arrive on a 40% shorter wait.",
	},
	Gull = {
		name = "Scout Gull",
		price = 150,
		color = Color3.fromRGB(240, 240, 245),
		effect = "Flies toward the nearest waiting treasure and tells you how far it is.",
	},
	Frog = {
		name = "Spring Frog",
		price = 130,
		color = Color3.fromRGB(110, 220, 110),
		effect = "Your dash recharges 35% faster.",
	},
	Tortoise = {
		name = "Shell Tortoise",
		price = 220,
		color = Color3.fromRGB(110, 150, 90),
		effect = "Bounces off one grapple catch, then rests 45 s. Its shell glows while it is ready, for everyone to see.",
	},
	Ghost = {
		name = "Pocket Ghost",
		price = 180,
		color = Color3.fromRGB(190, 220, 255),
		effect = "Poltergoblin recharges 25% faster.",
	},
}
Config.PET_CRAB_RECALL = 0.6 -- Recall cooldown multiple.
Config.PET_FROG_DASH = 0.65 -- Dash cooldown multiple.
Config.PET_GHOST_COOLDOWN = 0.75 -- Poltergoblin cooldown multiple.
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
	CONTACT_DAMAGE = 10, -- To a goblin it catches swimming.
	LUNGE_GAP = 7, -- Seconds between lunges (a roar, jaws open, a burst of speed)...
	LUNGE_SPEED = 55, -- ...this much faster than it was going...
	LUNGE_TIME = 0.8, -- ...for this long. Against a boat holding its speed it falls about 10 studs short.
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
	LAST_STAND = 30, -- A goblin with more health than this cannot be killed by one world hit (it leaves 1).
	HULL_SCALE = 0.6, -- The same for hulls: world blasts (boulders, lightning, monsters) bite this much smaller.
	HULL_FLOOR = 0.12, -- A creature or sea-mob hit never takes a hull below this share of its health: only
	-- cannons, shells, mines, kegs and real crashes sink boats.
}
-- The two-strike grip. An ordinary world hit does not knock treasure out of a carrier's hands: it LOOSENS their
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
	LIFT = 118, -- Studs/s up (about 35 studs, roughly 20 feet of goblin-scale height, 1.2 s in the air).
	PUSH = 30, -- Studs/s along the thief's way: it throws you on, not back.
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
	SHIP_SPEED = 170,
	SHIP_SURGE = 230,
	SHIP_TURN = 1.1,
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
	BOARD_REACH = 20, -- A pirate this close leaps for the treasure (a grip hit, no damage)...
	BOARD_TELL = 0.7, -- ...after waving its cutlass this long.
	BOARD_REST = 6, -- Fleet-wide: with the tell, 6.7 s between leaps, longer than the grip's SLIP_TIME (6), so
	-- pirates alone never strip a thief; it takes a pirate and something else.
	SHIP_FADE = 14, -- Seconds after the dinghies go before the ships sink into the fog.
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
Config.RECALL_TIMEOUT = 32 -- Seconds before a boat that is stuck is put beside the shore.
Config.RECALL_EXTRA_MAX = 6 -- Skiffs Recall may build when every boat is busy.

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
	-- Tangle Isle. Imps that snatch treasure in the canopy and run off to a nest with it.
	Imp = {
		notice = 105, -- A carrier this close, up in the canopy, is fair game.
		leap = 1.1, -- Seconds from shriek to landing: the time to get off the mark.
		reach = 7,
		hold = 18, -- Seconds it sits on the treasure at the nest before putting it back.
		scare = 9, -- Get this close and it drops the treasure and bolts.
		rest = 6,
		hop = 95, -- Studs/s between perches.
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
	Chill = { speed = 15, carrierSpeed = 21, aura = 40, wakeHeight = 30, leash = 270, scatter = 12 }, -- V9: aura 40 (V8: 30), it is bigger
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

return Config

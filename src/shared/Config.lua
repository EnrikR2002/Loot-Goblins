-- Every tuning number lives here so a playtest can be rebalanced in one file.
-- Times are seconds, distances are studs, speeds are studs per second.
local Config = {}

-- Raid -----------------------------------------------------------------------
-- A raid is one timed match. Bank the most gold before the timer runs out.
Config.RAID_DURATION = 480 -- The sea is big now; a deep run takes a while.
Config.LAST_CALL = 60 -- The HUD turns red for the final stretch.
Config.INTERMISSION = 12
Config.FIRST_INTERMISSION = 6 -- Gives the first players time to load in.
Config.RESPAWN_TIME = 3

-- Movement -------------------------------------------------------------------
Config.WALK_SPEED = 20 -- Jogging.
Config.WATER_SPEED_MULT = 0.7 -- Wading or swimming. Carry and spirit speed stack with it.
Config.WATER_ROOT_Y = 3 -- A root lower than this is standing or swimming in the sea.

-- Sprint (hold Shift). Costs stamina; no sprinting in the water or in a seat.
Config.SPRINT_MULT = 1.45 -- 20 -> 29 empty-handed.
Config.CARRY_SPRINT_MULT = 1.2 -- Loot is heavy: carriers only hustle a little (13-16 -> 16-19).
Config.STAMINA_MAX = 100
Config.STAMINA_DRAIN = 20 -- Per second of sprinting: a full bar lasts 5 s.
Config.STAMINA_REGEN = 25 -- Per second, once you stop sprinting.
Config.STAMINA_REGEN_DELAY = 0.8 -- Pause after sprinting before stamina comes back.
Config.STAMINA_RECOVER = 35 -- Run it dry and you're winded until it refills this far.

-- Loot -----------------------------------------------------------------------
-- Value is gold when banked (it grows a little while nobody takes it: see LOOT_INTEREST).
-- weight slows boats carrying it. carrySpeed replaces WALK_SPEED while held.
-- heat is added when it is taken from its spot. respawn is seconds after banking.
-- trouble is what the world does the moment it leaves its spot (Threats / Troubles).
-- island is the Archipelago id. visual picks the model (Loot.lua).
-- The rule of the map: more gold means farther, harder to carry and nastier trouble.
Config.LOOT = {
	{
		id = "Compass",
		name = "Lost Compass",
		place = "Pebble Isle",
		island = "Pebble",
		visual = "disc",
		value = 1,
		weight = 1,
		carrySpeed = 19,
		heat = 4,
		respawn = 25,
		trouble = "Gulls",
		color = Color3.fromRGB(255, 225, 150),
	},
	{
		id = "Pearl",
		name = "Giant Pearl",
		place = "Coral Atoll",
		island = "Coral",
		visual = "orb",
		value = 2,
		weight = 1,
		carrySpeed = 18,
		heat = 6,
		respawn = 30,
		trouble = "Gulls",
		color = Color3.fromRGB(255, 190, 220),
	},
	{
		id = "Stash",
		name = "Smuggler's Stash",
		place = "Smuggler's Cove",
		island = "Smuggler",
		visual = "chest",
		value = 2,
		weight = 2,
		carrySpeed = 17,
		heat = 8,
		respawn = 30,
		trouble = "Bell",
		color = Color3.fromRGB(190, 150, 100),
	},
	{
		id = "Gear",
		name = "Golden Gear",
		place = "the Windmill",
		island = "Windmill",
		visual = "gear",
		value = 3,
		weight = 2,
		carrySpeed = 17,
		heat = 10,
		respawn = 35,
		trouble = "Windmill",
		color = Color3.fromRGB(255, 205, 60),
	},
	{
		id = "Lens",
		name = "Lighthouse Lens",
		place = "the Lighthouse",
		island = "Cross",
		visual = "disc",
		value = 3,
		weight = 2,
		carrySpeed = 16,
		heat = 15,
		respawn = 30,
		trouble = "Bell",
		color = Color3.fromRGB(255, 240, 140),
	},
	{
		id = "Chest",
		name = "Captain's Chest",
		place = "the Shipwreck",
		island = "Shoals",
		visual = "chest",
		value = 4,
		weight = 4,
		carrySpeed = 13,
		heat = 20,
		respawn = 40,
		trouble = "Barrage",
		color = Color3.fromRGB(255, 160, 70),
	},
	{
		id = "Heart",
		name = "Crystal Heart",
		place = "Crystal Isle",
		island = "Crystal",
		visual = "orb",
		value = 5,
		weight = 3,
		carrySpeed = 15,
		heat = 25,
		respawn = 45,
		trouble = "CaveIn",
		color = Color3.fromRGB(215, 110, 255),
	},
	{
		id = "Frog",
		name = "Jade Frog",
		place = "Tangle Isle",
		island = "Tangle",
		visual = "idol",
		value = 5,
		weight = 2,
		carrySpeed = 15,
		heat = 22,
		respawn = 45,
		trouble = "Quake",
		color = Color3.fromRGB(110, 235, 130),
	},
	{
		id = "Vault",
		name = "Pearl of the Deep",
		place = "the Tide Vault",
		island = "Tide",
		visual = "orb",
		value = 6,
		weight = 3,
		carrySpeed = 15,
		heat = 26,
		respawn = 50,
		trouble = "Flood",
		color = Color3.fromRGB(110, 230, 255),
	},
	{
		id = "Trident",
		name = "Tempest Trident",
		place = "Maelstrom Rock",
		island = "Maelstrom",
		visual = "gem",
		value = 6,
		weight = 3,
		carrySpeed = 15,
		heat = 24,
		respawn = 50,
		trouble = "Squall",
		color = Color3.fromRGB(150, 190, 255),
	},
	{
		id = "Strongbox",
		name = "Admiral's Strongbox",
		place = "Fort Barnacle",
		island = "Fort",
		visual = "chest",
		value = 7,
		weight = 5,
		carrySpeed = 13,
		heat = 30,
		respawn = 55,
		trouble = "Navy",
		color = Color3.fromRGB(255, 110, 100),
	},
	{
		id = "Crown",
		name = "Ember Crown",
		place = "the Volcano",
		island = "Ember",
		visual = "crown",
		value = 8,
		weight = 3,
		carrySpeed = 14,
		heat = 32,
		respawn = 55,
		trouble = "Eruption",
		color = Color3.fromRGB(255, 130, 50),
	},
	{
		id = "Idol",
		name = "Golden Idol",
		place = "the Sun Temple",
		island = "Temple",
		visual = "idol",
		value = 10,
		weight = 4,
		carrySpeed = 14,
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
		value = 12,
		weight = 4,
		carrySpeed = 13,
		heat = 38,
		respawn = 75,
		trouble = "Avalanche",
		color = Color3.fromRGB(150, 245, 255),
	},
	{
		id = "Tooth",
		name = "Leviathan Tooth",
		place = "Leviathan's Rest",
		island = "Bone",
		visual = "tooth",
		value = 13,
		weight = 6,
		carrySpeed = 12,
		heat = 42,
		respawn = 80,
		trouble = "Kraken",
		color = Color3.fromRGB(245, 240, 215),
	},
	{
		id = "Chalice",
		name = "Skull Chalice",
		place = "Skull Rock",
		island = "Skull",
		visual = "chalice",
		value = 14,
		weight = 5,
		carrySpeed = 12,
		heat = 45,
		respawn = 85,
		trouble = "GhostFleet",
		color = Color3.fromRGB(130, 255, 180),
	},
}

-- Loot nobody takes grows more valuable: +1 gold per LOOT_INTEREST_EVERY seconds
-- untouched, up to LOOT_INTEREST_MAX. A treasure everyone ignores becomes the best deal
-- on the map, so the crowd is always deciding between "now, with company" and "later".
Config.LOOT_INTEREST_EVERY = 80
Config.LOOT_INTEREST_MAX = 3

Config.PICKUP_DISTANCE = 10
Config.STEAL_HOLD = 0.6 -- Holding E to pry loot off its spot.
Config.GRAB_HOLD = 0.15 -- Holding E to grab loose loot.
Config.STEAL_IMMUNITY = 1.5 -- After loot changes hands, nobody can take it for this long.
Config.THROW_SPEED = 55
Config.THROW_UP_SPEED = 38
Config.THROW_REGRAB_DELAY = 0.6 -- The thrower can't instantly catch their own throw.
Config.THROWN_BANK_WINDOW = 8 -- Loose loot entering the Hoard banks for whoever last held it.
Config.LOOSE_RETURN_TIME = 45 -- Loose loot nobody touches goes back to its spot.
Config.KNOCK_LOOSE_SPEED = 26

Config.BANK_RADIUS = 14
Config.WARD_RADIUS = 55 -- Around the Hoard: no Poltergoblin, no Guardian.

-- Out of bounds. Loot past these returns to its spot. Invisible walls stand at
-- the X/Z edges, built from several parts because one part can't pass 2048 studs.
Config.BOUNDS_MIN = Vector3.new(-1500, -45, -1560)
Config.BOUNDS_MAX = Vector3.new(1700, 600, 1180)

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
		hint = "The Navy sails out. The Guardian hunts.",
	},
	{
		name = "FRENZY",
		at = 80,
		color = Color3.fromRGB(255, 45, 60),
		hint = "The sea turns on the thief. A tempest is coming.",
	},
}
Config.HEAT_CARRY_RATE = 0.45 -- Per carrier outside the ward, per second.
Config.HEAT_CARRY_RATE_CAP = 1.2
Config.HEAT_DECAY_RATE = 0.8 -- Per second while nobody carries loot.
Config.REVEAL_TIER = 2 -- ALERT and up: carriers are visible through walls.

-- Guardian -------------------------------------------------------------------
-- Wakes when the Golden Idol is taken, or when Heat reaches GUARDIAN_WAKE_TIER.
Config.GUARDIAN_WAKE_TIER = 3
Config.GUARDIAN_SPEED = 16
Config.GUARDIAN_FRENZY_SPEED = 19
Config.GUARDIAN_WADE_MULT = 0.6
Config.GUARDIAN_LEASH = 260 -- From the temple island's center, until FRENZY.
Config.GUARDIAN_HIT_RANGE = 9
Config.GUARDIAN_DAMAGE = 20
Config.GUARDIAN_KNOCKBACK = 60
Config.GUARDIAN_HIT_COOLDOWN = 1.2
Config.GUARDIAN_RECOVER = 1 -- It stands still this long after a smash.

-- Totems ---------------------------------------------------------------------
-- Stone watchers by the loot spots. They charge, then lob a blast at a carrier.
Config.TOTEM_TIER = 2
Config.TOTEM_RANGE = 110
Config.TOTEM_TELEGRAPH = 0.9
Config.TOTEM_INTERVAL = { [2] = 4.5, [3] = 3.2, [4] = 2.2 } -- By Heat tier.
Config.TOTEM_LEAD = 0.25 -- Aims this many seconds ahead of the target.

Config.BLAST_SPEED = 85
Config.BLAST_MAX_TIME = 2
Config.BLAST_RADIUS = 8
Config.BLAST_DAMAGE = 15
Config.BLAST_KNOCKBACK = 55

-- Trouble (what each loot does when taken) -------------------------------------
Config.BOULDER_SIZE = 11
Config.BOULDER_SPEED = 30
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
Config.SWORD_RANGE = 8
Config.SWORD_MIN_DOT = 0.3
Config.SWORD_COOLDOWN = 0.55
Config.SWORD_KNOCKBACK = 34

-- F: a grappling hook. Aimed at loot (or near a carrier) it steals it, with a
-- clear line of sight. Aimed at ground, walls or cliffs it pulls you there.
-- Carriers can't use it (hands full). A miss costs no cooldown.
Config.GRAPPLE_RANGE = 60 -- Steal range.
Config.GRAPPLE_AIM_ASSIST = 7 -- Loot or a carrier this far off your aim line still counts.
Config.GRAPPLE_COOLDOWN = 6 -- After a successful steal.
Config.GRAPPLE_FAIL_COOLDOWN = 1 -- After a steal that slipped off (steal immunity).
Config.GRAPPLE_PULL_RANGE = 130
Config.GRAPPLE_PULL_SPEED = 95
Config.GRAPPLE_PULL_COOLDOWN = 2
Config.GRAPPLE_POP_SPEED = 38 -- Upward hop at the end of a pull, to climb onto ledges.

-- Poltergoblin (was Soul Unbound, Yone's E) ----------------------------------------
-- E leaves your body behind and sends your spirit out. Whatever loot the spirit
-- holds rides the tether back to the body.
Config.POLTER_DASH_DISTANCE = 14
Config.POLTER_DASH_TIME = 0.16
Config.POLTER_DURATION = 5
Config.POLTER_RECAST_DELAY = 0.5
Config.POLTER_COOLDOWN = 10 -- Starts on cast.
Config.POLTER_SPEED_BONUS_START = 0.1
Config.POLTER_SPEED_BONUS_END = 0.3
Config.POLTER_ECHO_FRACTION = 0.35
Config.POLTER_TETHER = 75 -- Straying farther from the body snaps you back.

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
-- Real physics hulls floating on the Sea functions. The server owns them, so
-- every player sees the same boat. Skiffs are quick and twitchy, the cutter is
-- heavy and carries a cannon, Navy patrol ships sit deep and can't cross shallows.
-- size: hull box. draft: studs below the surface at rest. accel/maxSpeed in
-- studs/s. turn: rad/s at speed. grip: how hard the keel resists sliding sideways.
Config.BOAT_TYPES = {
	skiff = {
		name = "Skiff",
		size = Vector3.new(9, 3, 20),
		draft = 1.3,
		density = 0.75,
		accel = 44,
		maxSpeed = 72,
		turn = 1.7,
		grip = 3.0,
		lean = 38,
		health = 150,
		passengers = 1,
	},
	cutter = {
		name = "Cutter",
		size = Vector3.new(14, 4, 34),
		draft = 2.1,
		density = 0.8,
		accel = 28,
		maxSpeed = 56,
		turn = 1.1,
		grip = 2.5,
		lean = 22,
		health = 380,
		passengers = 3,
		cannons = true,
	},
	navy = {
		name = "Patrol Ship",
		size = Vector3.new(16, 6, 42),
		draft = 3.8,
		density = 0.85,
		accel = 27,
		maxSpeed = 54,
		turn = 0.9,
		grip = 2.2,
		lean = 14,
		health = 460,
		passengers = 0,
	},
}
Config.BOAT_BOOST_MULT = 1.45 -- Top speed while boosting.
Config.BOAT_BOOST_THRUST = 1.9
Config.BOAT_BOOST_TIME = 2.2
Config.BOAT_BOOST_COOLDOWN = 7
Config.BOAT_REVERSE = 0.5 -- Reverse thrust relative to forward.
Config.BOAT_PAYLOAD_DRAG = 0.035 -- Each unit of loot weight aboard cuts thrust by this much.
Config.BOAT_IMPACT_MIN = 14 -- A sudden speed change bigger than this is a crash.
Config.BOAT_IMPACT_DAMAGE = 1.7 -- Hull damage per stud/s above the minimum.
Config.BOAT_IMPACT_CAP = 0.5 -- One crash never takes more than this fraction of a hull.
Config.BOAT_IMPACT_GRACE = 0.8 -- Seconds after a crash when further bumps don't count.
Config.BOAT_SINK_TIME = 7 -- Seconds a wreck takes to go under.
Config.BOAT_RESPAWN_TIME = 22 -- A sunk boat comes back at its dock after this long.
Config.BOAT_SLEEP_DISTANCE = 650 -- Empty boats farther than this from every player are frozen.

-- Carrying and fighting ---------------------------------------------------------
-- A carrier can swing, but it is a slow, short, tiring bash: the sword stays a way to contest loot
-- without making carriers harmless.
Config.CARRY_SWORD_COOLDOWN = 1.15
Config.CARRY_SWORD_RANGE = 6
Config.CARRY_SWORD_DAMAGE = 12
Config.CARRY_SWORD_KNOCKBACK = 22
Config.CARRY_SWING_STAMINA = 22

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
Config.WINDMILL_DAMAGE = 14
Config.WINDMILL_RAGE_TIME = 25
Config.BOAT_KICK_SPEED = 72 -- Upward speed a kicker ramp gives a fast boat.

-- Storms and lightning ---------------------------------------------------------------------------------
Config.STORM_FIRST_DELAY = 50 -- Quiet time at the start of a raid.
Config.STORM_GAP_MIN = 95 -- Seconds between ambient storms (then 120 s or so of weather).
Config.STORM_GAP_MAX = 140
Config.STORM_SPEED_MIN = 9
Config.STORM_SPEED_MAX = 16 -- A boat does 56-72, so you can always outrun one.
Config.STORM_FADE = 10 -- Seconds a storm takes to build and to fade.
Config.LIGHTNING_FIRST_DELAY = 6
Config.LIGHTNING_GAP_MIN = 2.4
Config.LIGHTNING_GAP_MAX = 4.2
Config.LIGHTNING_DELAY = 1.3 -- From marker to strike.
Config.LIGHTNING_DAMAGE = 24
Config.LIGHTNING_HULL_DAMAGE = 48
Config.TEMPEST_DISTANCE = 520 -- How far off the hunting storm starts.
Config.TEMPEST_SPEED = 15
Config.TEMPEST_DURATION = 85
Config.FRENZY_ROUGH = 0.45 -- Extra swell everywhere at FRENZY heat.

-- The Navy -----------------------------------------------------------------------------------------------
Config.NAVY_MAX = 3
Config.NAVY_SIGHT = 520 -- Sight range in clear weather (needs a clear line).
Config.NAVY_SEARCH_TIME = 22 -- They check your last position this long, then go home.
Config.NAVY_STANDOFF = 95 -- They hold at this range and shell you.
Config.NAVY_FIRE_RANGE = 300
Config.NAVY_FIRE_GAP = 4.2
Config.NAVY_FIRST_SHOT_DELAY = 6
Config.NAVY_SHELL_DELAY = 1.7 -- Marker to landing: time to read it and move.
Config.NAVY_SHELL_DAMAGE = 22
Config.NAVY_SHELL_HULL_DAMAGE = 60
Config.NAVY_REPLAN = 1.4
Config.NAVY_DISPATCH_GAP = 22

-- Heat reactions --------------------------------------------------------------------------------------------
Config.FLARE_GAP = 7 -- ALERT and up: a carrier outside the ward fires a flare this often.

-- The Guardian's new moves -------------------------------------------------------------------------------
Config.GUARDIAN_LEAP_MIN = 28
Config.GUARDIAN_LEAP_MAX = 95
Config.GUARDIAN_LEAP_WINDUP = 0.95
Config.GUARDIAN_LEAP_RADIUS = 15
Config.GUARDIAN_LEAP_DAMAGE = 25
Config.GUARDIAN_LEAP_KNOCKBACK = 78
Config.GUARDIAN_LEAP_GAP = 7
Config.GUARDIAN_THROW_MIN = 80
Config.GUARDIAN_THROW_MAX = 200
Config.GUARDIAN_THROW_DELAY = 1.6
Config.GUARDIAN_THROW_RADIUS = 11
Config.GUARDIAN_THROW_GAP = 6

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
Config.GHOST_SHIPS = 2
Config.GHOST_FOG_TIME = 80
Config.QUAKE_DELAY = 1.6

-- Traversal ------------------------------------------------------------------
Config.ZIPLINE_SPEED = 70

return Config

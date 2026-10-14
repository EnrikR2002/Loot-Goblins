-- Every tuning number lives here so a playtest can be rebalanced in one file.
-- Times are seconds, distances are studs, speeds are studs per second.
local Config = {}

-- Raid -----------------------------------------------------------------------
-- A raid is one timed match. Bank the most gold before the timer runs out.
Config.RAID_DURATION = 720 -- V7: twelve minutes for a server of up to 32, a sixteen-island sea and a deployment from the skyship. (V5/V6: 540, V4: 600, V3: 420)
Config.LAST_CALL = 60 -- The HUD turns red for the final stretch.
-- V7, the final rush: in the last FINAL_RUSH seconds every treasure banked pays FINAL_RUSH_MULT times its gold. It
-- gives everybody a reason to run for the Hoard at the end, and lets a goblin who is behind catch up with one big
-- run; it is a multiplier on what is banked, never on what is held, so a rival still has to be robbed to profit.
Config.FINAL_RUSH = 90
Config.FINAL_RUSH_MULT = 1.25
Config.INTERMISSION = 12
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
-- The rule of the map: more gold means farther, harder to carry and nastier trouble.
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
		value = 1,
		weight = 1,
		carrySpeed = 27,
		heat = 4,
		respawn = 20,
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
		carrySpeed = 26.5,
		heat = 6,
		respawn = 25,
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
		carrySpeed = 26,
		heat = 8,
		respawn = 25,
		trouble = "Bell",
		color = Color3.fromRGB(190, 150, 100),
	},
	{
		id = "Gear",
		name = "Golden Gear",
		place = "the Windmill",
		island = "Windmill",
		visual = "gear",
		value = 4,
		weight = 2,
		carrySpeed = 26,
		heat = 10,
		respawn = 30,
		trouble = "Windmill",
		color = Color3.fromRGB(255, 205, 60),
	},
	{
		id = "Lens",
		name = "Lighthouse Lens",
		place = "the Lighthouse",
		island = "Cross",
		visual = "disc",
		value = 4,
		weight = 2,
		carrySpeed = 25.5,
		heat = 15,
		respawn = 25,
		trouble = "Bell",
		color = Color3.fromRGB(255, 240, 140),
	},
	{
		id = "Sextant",
		name = "Sunken Sextant",
		place = "Kelp Cay",
		island = "Kelp",
		visual = "gear",
		value = 4,
		weight = 1,
		carrySpeed = 26.5,
		heat = 10,
		respawn = 30,
		trouble = "Gulls",
		color = Color3.fromRGB(150, 220, 160),
	},
	{
		id = "Chest",
		name = "Captain's Chest",
		place = "the Shipwreck",
		island = "Shoals",
		visual = "chest",
		value = 5,
		weight = 4,
		carrySpeed = 23.5,
		heat = 20,
		respawn = 35,
		trouble = "Barrage",
		color = Color3.fromRGB(255, 160, 70),
	},
	{
		id = "Heart",
		name = "Crystal Heart",
		place = "Crystal Isle",
		island = "Crystal",
		visual = "orb",
		value = 7,
		weight = 3,
		carrySpeed = 24.5,
		heat = 25,
		respawn = 40,
		trouble = "CaveIn",
		color = Color3.fromRGB(215, 110, 255),
	},
	{
		id = "Frog",
		name = "Jade Frog",
		place = "Tangle Isle",
		island = "Tangle",
		visual = "idol",
		value = 9,
		weight = 2,
		carrySpeed = 25,
		heat = 22,
		respawn = 40,
		trouble = "Quake",
		color = Color3.fromRGB(110, 235, 130),
	},
	{
		id = "Vault",
		name = "Pearl of the Deep",
		place = "the Tide Vault",
		island = "Tide",
		visual = "orb",
		value = 8,
		weight = 3,
		carrySpeed = 24.5,
		heat = 26,
		respawn = 45,
		trouble = "Flood",
		color = Color3.fromRGB(110, 230, 255),
	},
	{
		id = "Trident",
		name = "Tempest Trident",
		place = "Maelstrom Rock",
		island = "Maelstrom",
		visual = "gem",
		value = 8,
		weight = 3,
		carrySpeed = 24.5,
		heat = 24,
		respawn = 45,
		trouble = "Squall",
		color = Color3.fromRGB(150, 190, 255),
	},
	{
		id = "Lantern",
		name = "Storm Lantern",
		place = "Lantern Key",
		island = "Lantern",
		visual = "gem",
		value = 9,
		weight = 2,
		carrySpeed = 25.5,
		heat = 22,
		respawn = 45,
		trouble = "Bell",
		color = Color3.fromRGB(255, 200, 110),
	},
	{
		id = "Castaway",
		name = "Castaway's Hoard",
		place = "Driftwood Key",
		island = "Driftwood",
		visual = "chest",
		value = 9,
		weight = 4,
		carrySpeed = 23.5,
		heat = 24,
		respawn = 45,
		trouble = "Gulls",
		color = Color3.fromRGB(205, 175, 130),
	},
	{
		id = "Strongbox",
		name = "Admiral's Strongbox",
		place = "Fort Barnacle",
		island = "Fort",
		visual = "chest",
		value = 13,
		weight = 5,
		carrySpeed = 22.5,
		heat = 30,
		respawn = 50,
		trouble = "Navy",
		color = Color3.fromRGB(255, 110, 100),
	},
	{
		id = "Crown",
		name = "Ember Crown",
		place = "the Volcano",
		island = "Ember",
		visual = "crown",
		value = 13,
		weight = 3,
		carrySpeed = 24,
		heat = 32,
		respawn = 50,
		trouble = "Eruption",
		color = Color3.fromRGB(255, 130, 50),
	},
	{
		id = "Idol",
		name = "Golden Idol",
		place = "the Sun Temple",
		island = "Temple",
		visual = "idol",
		value = 14,
		weight = 4,
		carrySpeed = 23.5,
		heat = 40,
		respawn = 60,
		trouble = "Guardian",
		color = Color3.fromRGB(255, 205, 40),
	},
	{
		id = "Aurora",
		name = "Aurora Gem",
		place = "Frost Spire",
		island = "Frost",
		visual = "gem",
		value = 17,
		weight = 4,
		carrySpeed = 23.5,
		heat = 38,
		respawn = 65,
		trouble = "Avalanche",
		color = Color3.fromRGB(150, 245, 255),
	},
	{
		id = "Tooth",
		name = "Leviathan Tooth",
		place = "Leviathan's Rest",
		island = "Bone",
		visual = "tooth",
		value = 17,
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
		value = 20,
		weight = 5,
		carrySpeed = 22.5,
		heat = 45,
		respawn = 75,
		trouble = "GhostFleet",
		color = Color3.fromRGB(130, 255, 180),
	},
}

-- Loot nobody takes grows more valuable: one step per LOOT_INTEREST_EVERY seconds untouched,
-- up to LOOT_INTEREST_MAX steps. A step is LOOT_INTEREST_SHARE of the treasure's value (at
-- least 1 gold), so a far prize left alone gains as much, in proportion, as a near one. A
-- treasure everyone ignores becomes the best deal on the map, so the crowd is always deciding
-- between "now, with company" and "later".
Config.LOOT_INTEREST_EVERY = 80
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
Config.BOAT_JUMP_SPEED = 58 -- Upward speed: about 8.5 studs of height from rest, a long arc under boost.
Config.BOAT_JUMP_COOLDOWN = 1.3
Config.BOAT_YAW_SNAP = 8 -- How quickly the hull reaches the turn rate you ask for (V2: 5).
Config.BOAT_SLIP_LOSS = 0.15 -- Speed shed by sliding sideways in an ordinary turn (V2: 0.5).
Config.BOAT_COAST_DRAG = 0.35 -- Share of the engine-on drag that remains off the throttle: boats coast.
Config.BOAT_BUOY_DAMPING = 1.1 -- How quickly a hull stops bouncing on its springs (V2: 0.85).
Config.BOAT_MAX_STEP = 0.1 -- Longest frame the boat physics will integrate in one go (10 frames a second).
Config.BOAT_AIR_CONTROL = 0.35 -- Share of the steering you keep while airborne.
Config.BOAT_AIR_MIN = 0.4 -- Seconds off the water before a touchdown counts as a landing.
Config.BOAT_LANDING_AIR = 0.7 -- Seconds in the air before a clean landing also bursts (a plain hop in flight 0.6 s does not).
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
Config.BOAT_KICK_SPEED = 76 -- Upward speed a kicker ramp gives a fast boat.
Config.BOAT_KICK_MIN_SPEED = 34 -- Slower than this and a kicker is only a bump.

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
Config.BOAT_MAX_ALTITUDE = 80 -- Studs above the sea a hull can be (kickers reach about 15).
Config.BOAT_STRIKE_TIME = 1.2 -- Seconds over a limit before the server takes the boat back.
Config.BOAT_RECLAIM_TIME = 5 -- Seconds the server then drives it before handing it back.

-- The skyship and the dive (V7) --------------------------------------------------------------------
-- Every raid starts aboard a flying ship over the middle of the sea (server/Skyship.lua). The raid
-- clock runs from the moment the bell goes; WINDOW seconds later whoever is still aboard is fired off.
Config.SKYSHIP = {
	POSITION = Vector3.new(0, 540, -80), -- Centre of the deck. The sea's walls are 700 high.
	BEAM = 44,
	WINDOW = 28, -- Seconds from the raid's start: the deployment window.
	COUNTDOWN = 3, -- The cannons unlock this long after the raid starts (so a crowd goes together).
}
Config.DIVE = {
	PENCIL_REACH = 55, -- Studs/s along, head down.
	PENCIL_FALL = 150, -- Studs/s down, head down.
	PENCIL_RATE = 1.6, -- How quickly the velocity settles on those numbers (per second).
	GLIDE_REACH = 175, -- Space held: arms out.
	GLIDE_SINK = 30,
	GLIDE_RATE = 1.1,
	COAST_SHARE = 0.8, -- With no steering a goblin holds its heading at this share of its reach.
	LAUNCH_SPEED = 230, -- What a cannon gives; the dive's numbers take over within a couple of seconds.
	LAUNCH_ELEVATION = math.rad(24),
	NUDGE_YAW = math.rad(14), -- How far the player can turn a cannon off its island.
	NUDGE_PITCH = math.rad(10),
	FUSE = 0.9, -- From Fire to launch.
	BOUNCES = 1, -- A splash bounces a diver this many times; the next one is a plain swim.
	BOUNCE_UP = 135, -- Studs/s up after a splash.
	BOUNCE_GRAVITY = 85, -- The bounce is a hop with its own gravity: about 105 studs high and three seconds of flight.
	BOUNCE_KEEP = 0.5, -- Share of the sideways speed kept through the bounce.
	OSTRICH_SPEED = 95, -- Hitting ground this fast (a pencil dive; a glide is about 30) goes head first.
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
--   extract   how hard the way HOME is (Navy base, distance)        gear      2 if the island is far
--                                                                             better with equipment
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
		tag = "EQUIPMENT",
		line = "A vault that floods: swim the drain, or bring a rebreather.",
		g = 1,
		t = 2,
		h = 3,
		x = 2,
		r = 1,
		gear = "Rebreather",
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
		tag = "EQUIPMENT",
		line = "A volcano and a river of fire: boots make it a walk.",
		g = 1,
		t = 2,
		h = 3,
		x = 2,
		r = 2,
		gear = "CinderBoots",
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
		tag = "EQUIPMENT",
		line = "A glacier with a cold that follows you: claws and a plan.",
		g = 1,
		t = 3,
		h = 2,
		x = 2,
		r = 2,
		gear = "FrostClaws",
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

-- Gear (V7): found in the world, never sold for Robux. Each piece changes one island's hazard a lot, and the treasure
-- on that island cannot be pried loose without it. A cache on a key island hands it out for the rest of the raid, once
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

-- Lasting progress (V7, server/Progress.lua) -------------------------------------------------------------
-- SHINIES are what a goblin keeps; raid GOLD is what wins a raid. A raid pays PARTICIPATION to
-- everyone who was there for MIN_PRESENT seconds, PER_GOLD for each gold banked (up to GOLD_CAP), a WIN
-- bonus for the winner (a tie shares it) and an UNDERDOG bonus to a goblin who banked something and sits at or
-- below the middle. At most RAID_CAP a raid. A pet costs 120 to 200: two to five raids.
Config.PROGRESS = {
	STORE = "LootGoblinsProfile_v1",
	PARTICIPATION = 10,
	PER_GOLD = 1,
	GOLD_CAP = 30,
	WIN = 25,
	UNDERDOG = 5,
	RAID_CAP = 70,
	MIN_PRESENT = 90,
	AUTOSAVE = 120,
}
Config.KIT_PRICE = 90 -- Starting a raid already carrying one piece of gear.
-- Five pets, each a different VERB rather than a different percentage. Equipped one at a time.
Config.PETS = {
	Crab = {
		name = "Tug Crab",
		price = 120,
		color = Color3.fromRGB(235, 110, 90),
		effect = "Boat calls arrive on a 40% shorter wait.",
	},
	Gull = {
		name = "Scout Gull",
		price = 150,
		color = Color3.fromRGB(240, 240, 245),
		effect = "Shows how far the nearest waiting treasure is.",
	},
	Frog = {
		name = "Spring Frog",
		price = 140,
		color = Color3.fromRGB(110, 220, 110),
		effect = "Your dash recharges 35% faster.",
	},
	Tortoise = {
		name = "Shell Tortoise",
		price = 180,
		color = Color3.fromRGB(110, 150, 90),
		effect = "The first grapple catch on you each 30 s bounces off.",
	},
	Ghost = {
		name = "Pocket Ghost",
		price = 200,
		color = Color3.fromRGB(190, 220, 255),
		effect = "Poltergoblin recharges 25% faster.",
	},
}
Config.PET_CRAB_RECALL = 0.6 -- Recall cooldown multiple.
Config.PET_FROG_DASH = 0.65 -- Dash cooldown multiple.
Config.PET_GHOST_COOLDOWN = 0.75 -- Poltergoblin cooldown multiple.
Config.PET_TORTOISE_REST = 30 -- Seconds before the shell works again.
Config.PET_GULL_RANGE = 1400 -- How far the gull sees.
-- Robux. EMPTY until a human creates Developer Products and pastes their ids here:
--   [123456789] = { pet = "Gull" },
Config.MONETIZATION = { PRODUCTS = {} }

-- Navigation (V7). The compass strip only lists treasure this close (all nineteen across the top was the
-- clutter), and a carrier gets a waypoint arrow toward the Hoard.
Config.COMPASS_LOOT_RANGE = 1300
Config.WAYPOINT_HIDE_WITHIN = 90 -- The arrow goes away this close to the Hoard: you are there.

-- The Leviathan's body (server/Leviathan.lua): drawn by the Sleeper's tick, no health, no AI of its own.
Config.LEVIATHAN = {
	HUMPS = 7,
	NECK = 12,
	RADIUS = 150, -- Of the circle its back swims.
	SWIM_SPEED = 22,
	LURK_MIN = 0.25, -- How much of its back shows when the Sleeper is hardly aware.
	GAP = 0.12, -- Radians between humps.
	ARC_HEIGHT = 75,
	NECK_GAP = 0.05,
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
Config.STORM_FIRST_DELAY = 50 -- Quiet time at the start of a raid.
Config.STORM_GAP_MIN = 45 -- Seconds between new ambient storms (each lasts 90-125 s). (V3: 95-140, one at a time)
Config.STORM_GAP_MAX = 75
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
Config.GHOST_SHIPS = 2
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
		reach = 5,
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
		radius = 10,
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
		reach = 12,
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
	Chill = { speed = 15, carrierSpeed = 21, aura = 30, wakeHeight = 30, leash = 270, scatter = 12 },
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
	Maw = { radius = 150, speed = 30, reach = 20, push = 70 },
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

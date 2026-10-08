-- Every tuning number lives here so a playtest can be rebalanced in one file.
-- Times are seconds, distances are studs, speeds are studs per second.
local Config = {}

-- Raid -----------------------------------------------------------------------
-- A raid is one timed match. Bank the most gold before the timer runs out.
Config.RAID_DURATION = 360 -- The islands are far apart now; runs take longer.
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
-- value: gold when banked. carrySpeed: replaces WALK_SPEED while held.
-- place: where it spawns, for HUD and feed text.
-- heat: added when taken from its spot. respawn: seconds after banking.
-- trouble: what the world does the moment it leaves its spot (see Threats).
Config.LOOT = {
	{
		id = "Lens",
		name = "Lighthouse Lens",
		place = "the Lighthouse",
		value = 3,
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
		value = 4,
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
		value = 5,
		carrySpeed = 15,
		heat = 25,
		respawn = 45,
		trouble = "CaveIn",
		color = Color3.fromRGB(215, 110, 255),
	},
	{
		id = "Idol",
		name = "Golden Idol",
		place = "the Sun Temple",
		value = 10,
		carrySpeed = 14,
		heat = 40,
		respawn = 70,
		trouble = "Guardian",
		color = Color3.fromRGB(255, 205, 40),
	},
}

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
-- the X/Z edges. Each span stays under 2048, the biggest a single part can be.
Config.BOUNDS_MIN = Vector3.new(-1000, -45, -1020)
Config.BOUNDS_MAX = Vector3.new(1000, 600, 980)

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
		hint = "Carriers glow through walls. Totems fire.",
	},
	{ name = "HUNTED", at = 50, color = Color3.fromRGB(255, 120, 40), hint = "The Guardian hunts carriers." },
	{ name = "FRENZY", at = 80, color = Color3.fromRGB(255, 45, 60), hint = "The Guardian follows you anywhere." },
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

-- Boats ----------------------------------------------------------------------
-- Every island has a dock with a boat; Goblin Cove has four.
Config.BOAT_SPEED = 62
Config.BOAT_TURN_RATE = math.rad(70)

-- Traversal ------------------------------------------------------------------
Config.ZIPLINE_SPEED = 70

return Config

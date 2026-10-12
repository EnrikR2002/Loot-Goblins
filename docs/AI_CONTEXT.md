# Loot Goblins — AI context

Master context for a Claude Code or Codex session that opens this repository with no history. It explains what the game is, how the code works, and how we build and test it.

**`AGENTS.md` holds the rules** (branching, approval, safety). This file is background only. If they ever disagree, `AGENTS.md` wins, and you should fix this file.

## Where things stand

| Where | What it contains |
| --- | --- |
| Shared `main` (as of `84b762a`, 2026-10-07) | The **vertical slice** (PR #7: raids, loot, Heat, Guardian/totems/trouble, Poltergoblin, HUD, module split) and the double-click launcher (PR #8). |
| Unmerged: PR #9, branch `claude/sprinting-grapple-map-expansion-japzs8` | **Sprint + stamina**, the **grapple hook**, and a bigger map. Waiting for a Studio playtest and approval. |
| Unmerged: PR #10, branch `feature/v2-archipelago` (stacked on PR #9; merge #9 first) | **V2**: a 19-island archipelago, a physical sea (waves, currents, storms), physics boats, Navy pursuit, per-treasure troubles, Heat that changes the world, cannons, kegs, destructibles. Report: `docs/reports/2026-10-08-v2-archipelago.md`. One human playtest since: the world is more interesting to explore; the goblin and boats felt too slow. |
| Unmerged: PR #11, branch `feature/v3-speed-agency-danger` (stacked on PR #10; merge #9, then #10, then this) | **V3**: fast movement (dash, air jump, stamina for the exceptional only), fast boats with drift, driver-owned boat physics, a Navy that intercepts, charges and lays mines, a Guardian stomp, waterspouts. Report: `docs/reports/2026-10-11-v3-power-speed-peril.md`. One human playtest since: movement and boats feel right, and they have outgrown the world. |
| Unmerged: PR #12, branch `feature/v4-living-archipelago` (stacked on PR #11; merge #9, #10, #11, then this) | **V4**: a sea 4.6 times the size laid out in regions, the original islands moved (not rebuilt) and grown with generated land, reefs, shallows, stack fields and currents between them, a harbor chain, signal beacons, catapults, 19 treasures, retuned economy, Heat and storms. Report: `docs/reports/2026-10-12-v4-living-archipelago.md`. One human playtest since: the sea is too spread out, the boost hoops are the best part of sailing, and the islands need things living on them. |
| Unmerged: PR #13, branch `feature/v5-living-threats-playful-seas` (stacked on PR #12; merge #9, #10, #11, #12, then this) | **V5**: the sea pulled in to 55% of V4's area (islands keep their size), 110 boost hoops laid out as 16 runs with chains and timed runs, coins, salvage, and **21 island inhabitants of 13 kinds** on one shared framework. Raids 9 minutes, values and Heat retuned. Report: `docs/reports/2026-10-12-v5-living-threats-playful-seas.md`. One human playtest since: the map size, the boats and the creatures are right; the hoops and coins are fun but crowded and oddly placed, worst of all outside the harbor; and there have been explosions in the distance since V2. |
| Unmerged: PR #14, branch `feature/v6-ocean-flow-audio` (stacked on PR #13; merge #9 to #13, then this) | **V6**: no new system. The hoops, coins, lanes and timed courses laid out again by a few written rules (Home Bay calm, straight lanes that point at docks, courses set apart, coins for skill and secrets), every lane and course driven by an autopilot and its par measured, and the map-wide thunder fixed (world sounds are positional and fade to silence). Report: `docs/reports/2026-10-12-v6-ocean-flow-audio.md`. Studio-tested by one AI on one client, sound checked from logs only; **no human playtest of V6 yet**. |

Check the real state before you trust this table: `git log --oneline origin/main` and the open PRs. Update this table when a branch merges.

Everything below describes the V6 branch.

## Purpose

Loot Goblins is a Roblox game by Ethan, Ninety and Enrik. The one-sentence thesis is: *steal ridiculous treasure from dangerous islands and other players, then somehow get it home.*

The loop: **explore (awe) → steal treasure → the world reacts → escape (panic) → bank → repeat.** Going out should feel like adventure; coming home with something valuable should feel like needing to GET OUT. V3's aim on top of that: **the player should feel powerful, the world should feel dangerous, and the fun is where those two meet.** Moving and sailing should be enjoyable in themselves, not the price of reaching the fun. V4's aim: **the world should be big and varied enough to deserve that movement**, with geography that is itself something to learn and use. V5's aim: **every island should have something living on it that a player can learn**, and the sea between them should be a playground, not a commute. V6's aim: **placement over quantity.** What the sea offers should be few enough, and laid out plainly enough, that a goblin can see it and choose.

The design principle is **active novelty**: surprises the player participates in (a geyser to time, a ring to jump, a charge to dodge, a storm to steer around), not things that just happen on screen.

`docs/DESIGN_THESIS.txt` holds the long-term vision. That vision is **not** permission to build shops, XP, pets, monetization, rarity tables, trading, or saved progress.

## Core loop

1. Players spawn at **Goblin Cove** next to **the Hoard**. A raid lasts `Config.RAID_DURATION` (540 s), then a short intermission.
2. Nineteen treasures wait on 17 islands, each with a light pillar and a name tag visible from anywhere. **Value rises with distance and danger**: 1–2 g near home, 13–20 g in the far north. Values follow travel time and how hard the island is to leave (see the V5 report, section 11).
3. Prying treasure off its spot (hold E, 0.6 s) adds Heat and triggers that treasure's own **trouble** (a flooding vault, a volcano, tentacles, ghost ships, snapping bridges...). Most big islands also have an **inhabitant** with one rule to learn (see Island inhabitants).
4. The carrier is hunted by the world (see Heat), can be robbed by other players, pays more stamina for every move and slows the boat they sit in. On foot they are only a little slower than anyone else.
5. Carrying treasure into the Hoard ring banks its gold. Banked treasure respawns later; treasure nobody takes grows more valuable (**interest**: `LOOT_INTEREST_SHARE` of its value, at least 1 g, per 80 s, three steps at most).
6. **Coins** on the water are a side dish: ten make 1 gold at the Hoard, at most `COIN_GOLD_CAP` (6) gold a raid. Treasure is the score.
7. When the timer ends, the most gold wins (`Wins` +1). Everything resets.

## Controls

| Input | Action | Where |
| --- | --- | --- |
| Hold `E` on treasure | Steal from spot / grab loose treasure (ProximityPrompt) | `Loot` |
| `E` on a boat | Board it (driver seat first, then passengers) | `Boats` |
| `W A S D` in the driver seat | Drive. `S` against your motion is a brake | `BoatSim`, client `BoatDrive` |
| `Shift` in the driver seat | **Boost** (2.2 s, 5.5 s cooldown). Gamepad `X` | `Boats`, client `BoatDrive` |
| Hold `C` in a turn, driver seat | **Drift**: slide round the turn, let go for a speed burst. Gamepad `B` | `BoatSim` |
| `R` near a boat's winch | Drop or raise the anchor | `Boats` |
| `E` at a cannon | Fire it where you aim | `Cannons` |
| `E` at a lever | Pull it (Tide Vault gate, Fort Barnacle's harbor chain) | `Mechanisms` |
| Hold `E` at a signal beacon | Light it: patrol ships within `BEACON_RANGE` go to look | `Mechanisms`, `Navy.distract` |
| `G` | Throw a powder keg (take kegs from keg crates with `E`) | `Kegs` |
| `E` at Gobbo, on the home dock | Take a powder keg from him | `BestiaryMinor` |
| Drive or walk through a coin or a salvage crate | Collect it. No button | `Coins` |
| Hold `Shift` on foot | Sprint (×1.36, carriers ×1.25), on land or swimming. Uses stamina | `Movement` |
| `C` on foot | **Dash** the way you are moving, ground or air. 18 stamina. Gamepad `B` | client `Main`, `Movement` |
| `Space` in the air | **Air jump**, once per flight. 12 stamina. Gamepad `A` | client `Main`, `Movement` |
| Click (sword) | Swing. A carrier's swing is slower, shorter, weaker and costs stamina | `Combat` |
| `F` | Grapple hook: steal loot / from a carrier, or hook a surface **or a boat** and get pulled (a boat seats you). Carriers can only pull, on a 5 s cooldown | `Combat`, client `Main` |
| `Q` | Throw held treasure | `Loot` |
| `E` with no prompt showing | Poltergoblin (cast / early return) | `Poltergoblin` |
| `E` at a zipline | Ride; jump to let go | client `Main` |
| `M` | World map | client `Map` |
| `H` | Help panel | client `Hud` |

Abilities are keyboard and mouse, with the gamepad buttons above. Prompts and the sword also work on touch; nothing else has touch buttons yet.

## Systems

All tuning numbers live in `src/shared/Config.lua`. Gameplay modules never hardcode tuning.

### World and map

- **`Archipelago.lua`** (shared) is the one list of islands (id, name, x, z, radius, ring, colour) and of the sea's **regions** (names for the map). The server builds terrain from it; the client's map, compass and signs read it. North is -Z. The sea is 5080 x 4390 studs (`Config.BOUNDS_*`; V4 was 6900 x 5840); its header explains the regions and why the distances are what they are. The home ring kept V4's spacing; everything else is about 30% closer.
- **`World.lua`** builds the environment (sea floor, boundary walls in ≤2000-stud pieces, far-sea horizon slabs, haze) and the eight original islands (Goblin Cove, Crossroads, Sun Temple, Crystal Isle, Shipwreck Shoals, Gull Rock, Smuggler's Cove, Twin Stacks). **Those builders are written in the coordinates they were first built at**; each runs with a build offset (`Kit.setShift`, set by `moved(id, builder)`) that moves it, unchanged, to its place in `Archipelago`. Anything they leave in `refs` goes through `Kit.world` (aliased `W`). Offsets must be multiples of 4 studs (asserted), so the terrain lands on the same voxels. **To move an original island, change its x and z in `Archipelago.lua` in steps of 4; do not edit the builder's coordinates.** Twin Stacks must keep its offset from Crystal Isle (a zipline joins them).
- **`Islands.lua`** (Pebble, Coral Atoll, Windmill Hills, Tide Vault, Smuggler's stash) and **`IslandsFar.lua`** (Fort Barnacle, Tangle Isle, Ember Isle, Maelstrom Rock, Frost Spire, Leviathan's Rest, Skull Rock) already build relative to `Archipelago` and run with no offset.
- **`Landform.lua`** writes natural land into the Terrain voxels from a list of lobes (hills, ridges, mesas, cuts): wobbling coastlines, shelving seabeds, cliff-walled crags. It only adds to what is there. `Landform.shaper(cx, cz, spec)` is the convenient way in. It also makes the horizon **silhouettes** (`Landform.silhouette`, `Landform.mark`). Heights given to it are real heights (it compensates for the two studs the engine adds: see the Studio section).
- **`Outlands.lua`** is the new land around every island (`lands.<Id>`, built BEFORE the island builders so they lay their ground on it and carve their harbors out of it) and what stands on it (`places.<Id>`, built AFTER: docks, spare boats, ziplines, catapults, beacons, the harbor chain, the three new treasures). Offsets there are from the island's center.
- **`Seaways.lua`** is the water between islands: Wrecker's Reef and the Gate, the Western Shelf, the Teeth, the Serpent Channel, the Cinders, lone rocks, currents. **Everything in it is placed from island positions** (`from(id, dx, dz)`, or a point between two islands), never from fixed world coordinates, so it follows when `Archipelago.lua` changes. It exposes what other modules need to find (`Seaways.GATE`, `SHELF`, `TEETH`, `serpent()`, `rock(name)`).
- **`Searuns.lua`** is what is laid on that water: the lanes, the timed courses, the ramps and the coins. **Its header holds the layout rules; read them before adding a hoop** (they are summarized under "Lanes, courses, coins and salvage" below). It fills `refs.boostGates`, `refs.coins`, `refs.runs` (timed courses) and `refs.lanes`, and adds a line to `refs.buildWarnings` (which `Main` prints) for any hoop over water shallower than 3.2 studs.
- **`WorldKit.lua`** holds the shared helpers (parts, terrain shapes, docks, ladders, signs, cannons, bridges, geysers, and V4's `hoop`, `kicker`, `stream`, `hookPost`, `catapult`, `beacon`). It also records where anything was built (`Kit.touch`, exposed as `refs.builtOn`).
- **Builders only describe.** They leave data in `refs` (`breakables`, `barrels`, `kegCrates`, `cannons`, `levers`, `gates`, `beacons`, `spinners`, `geysers`, `lavaZones`, `boostGates`, `coins`, `runs`, `lanes`, `navyBases`, `troubleSites`, `targets`) and the mechanism modules run it. Never put logic in a builder.
- About 5,400 server parts and 43 boats, 101 gates (95 hoops, 6 ramps), 132 coins. **The world takes 3 to 4 s to build and the sea grid another 3 s** (V3: 3 s in all); `Main` prints both with a breakdown at start-up. Watch that line when you add terrain.
- **Depths that matter:** a skiff needs 3.1 studs of water, a cutter 3.9, a patrol ship 5.6 (`SeaNav`: draft + 1.8). Reef crest 1.2, reef passes 3.7, the Western Shelf 4.8. **Green lamps mark water a patrol ship cannot enter; gold lamps mark the Gate.** Keep that language if you add shallows.
- **Folders** under `workspace.LootGoblinsGenerated`: `Ground` (walkable; the Guardian walks on it), `Structures` (boats live here), `Decor`, `Loot`, `Threats`, `Effects` (also mines and waterspouts), `Coins` (coins and salvage crates), `SpiritBodies`, `LaunchPads` (also geyser vents), `Ziplines`, `Landmarks` (persistent: island signs, `HoardMarker`, and the horizon silhouettes).
- **Streaming is on** (`default.project.json`: min 256, target 2048). Loot models, island signs, the Hoard marker and the silhouettes are `Persistent`; everything else streams. Client code must never assume far parts exist. The far islands are thousands of studs from home, so the silhouettes (plain blocks buried inside each island's tall ground, built in the background after start-up by `World.buildHorizon`) are what a far island looks like. With the islands closer, more of the world sits inside the streaming radius (a client at the Crossroads holds about 6,800 world instances).
- **Signs** made with `Kit.sign` are tagged `RangedSign`, and the client hides one that is really farther than its `MaxDistance` (Roblox measures a billboard's distance along the line of sight, so signs far off to one side would all show). Give a new sign the range you mean.

### Sea (`shared/Sea.lua`, `SeaNav.lua`, `Storms.lua`)

- `Sea` is pure math: `waveAt(x, z, t)` (three crossing swells), `currentAt` (wind drift + streams + whirlpools), `stormAt`, `shelterAt`. Swell is calmer beside land (shelter) and wild in a storm. The Terrain water is only the visual surface.
- **`Sea` is shared** (`ReplicatedStorage.LootGoblins.Sea`) because a driven boat floats on the driver's client. `src/server/Sea.lua` only forwards to it. The server sends the static half once (`ReplicatedStorage.LootGoblinsSea`, a JSON StringValue: streams, whirlpools, the shelter grid as one digit per cell, the boat gates), and `Sea.follow()` on the client keeps the storms and the global roughness current from `workspace.StormData` and `workspace.SeaRough`.
- **Currents** (`Kit.stream`, readable chevrons): Rushing Strait, Temple Drift, Cinder Run, Northern Drift, Mill Race, the Serpent Channel (the fastest, 28), and the Maelstrom whirlpool (strongest at mid-radius, calm in the eye).
- `SeaNav` builds a 40-stud grid from the finished terrain: water depth per cell, distance to land (shelter), and A* routes. **It only raycasts where a builder touched the map** (`refs.builtOn`, plus one cell of margin); everywhere else is taken to be open water 26 deep. A raycast on untouched terrain makes the engine build its collision, and doing that for the whole sea cost five seconds of start-up. Anything that raises the seabed must therefore go through `Kit.terrain`, `Kit.part` into `Ground`, or `Landform` (they record it); a raw `workspace.Terrain` call would be invisible to ships. A hull can only use cells deeper than its draft + 1.8, so deep ships cannot cross shallows. `SeaNav.path` takes a coast weight; the Navy uses a strong one so its fast, wide-turning ships keep off headlands.
- **Storms**: moving cells (rough water, wind, lightning). After a 50 s calm, up to `STORM_MAX_AMBIENT` (3) ambient ones at once, a new one every 45–75 s, **seeded 600–1050 studs from a player who is out at sea and set to blow across them** (never within `STORM_HOME_CLEAR` of the Hoard), at 16–28 studs/s; Maelstrom's treasure calls a squall; FRENZY heat sends a hunting **tempest** at 42 (slower than any boat, faster than anyone on foot); Skull Rock calls **fog**. Published as one string attribute `workspace.StormData`. Lightning is **marked** 1.3 s ahead. `Storms.Spent` fires where an ambient storm blows itself out (salvage listens).
- **Waterspouts**: each storm cell carries two (the tempest three) circling its heart. Server parts in `Effects`. One flings any boat or goblin it catches upward and sideways (`SPOUT_*`).

### Boats (`shared/BoatSim.lua`, `server/Boats.lua`, `client/BoatDrive.lua`)

- **`BoatSim.step(boat, input, dt, t)` is the physics**, shared, and runs on whichever machine owns the hull. Forces: buoyancy springs at six hull points toward `Sea.waveAt`; thrust (only while wet) with a launch punch and a real brake; an arcade keel that redirects drift instead of braking; a yaw-rate target; banking; an upright assist; drag toward the water's own flow. It **measures** how much Roblox's Terrain water slows the hull and cancels it under power, so `maxSpeed` in Config is the speed actually reached, on any hull at any frame rate.
- **Drift**: `input.drift` held in a turn at speed lowers the grip, swings the hull out to a slide angle and holds it there, and charges `driftCharge`; releasing pays a burst (`BOAT_MINI_KICK`, two levels). **Landing**: after `BOAT_AIR_MIN` seconds off the water, an upright, straight touchdown gives a burst. **Capsize**: a hull upside down for `BOAT_FLIP_TIME` pops upright.
- **Who simulates** (`Config.BOAT_CLIENT_PHYSICS`, default true): an empty or AI boat, the server; a boat with a driver, **the driver's client** (`BoatDrive` runs `BoatSim` in `PreSimulation`, reading the seat's `ThrottleFloat`/`SteerFloat`). The server calls `hull:SetNetworkOwner(driver)` and sets the model's `Pilot` attribute. With the setting off the server simulates everything, as V2 did.
- **`Boats.lua` (server) stays in charge:** hull health, crashes, scrapes, repair, sinking, respawn, anchors, seats, boost cooldowns, sleeping far boats. `watchHull` measures crashes on every hull from its velocity (a change over `BOAT_IMPACT_WINDOW` that the engine and keel cannot explain). `police` checks every driven hull each frame (speed, altitude, jumps) and takes it back for `BOAT_RECLAIM_TIME` if it breaks a rule.
- **Rules for code that touches boats:** to push a hull use `Boats.shove` (a driven hull is pushed by telling its driver's client); to move one use `Boats.place` (it takes the hull back first); to hurt one use `Boats.damage` or a `Blast`. Never write a driven hull's velocity or CFrame directly from the server.
- Types in `Config.BOAT_TYPES`: **skiff** (108, the best drifter, fragile), **cutter** (86, cannon, 3 passengers, shrugs off crashes, rams hard), **navy** patrol ship (88, wide turns, deep draft, AI only, no bow skid).
- **Beaching**: player hulls carry an invisible sloped `BowSkid` so they ride up gentle shores and slide to a stop. Out of the water the engine does nothing except a slow shove either way (`BOAT_BEACH_SHOVE`), so a beached boat can be worked back to the sea but cannot drive over an island. Steep edges (Coral's reef) are still walls.
- **Gates**: boost hoops and kicker ramps from `refs.boostGates`, applied by the simulating machine (`BoatSim.gate`); the server broadcasts the effect. A hoop made with `Kit.hoop` pushes whichever way the boat is already going (`both`) unless it is made one-way. A kicker must stand in open water: one built on a sandbar stalls the boat.
- **Hoop chains** (in `BoatSim.gate`, so they run on whichever machine owns the hull): a hoop within `BOAT_CHAIN_WINDOW` (4 s) of the last one kicks `BOAT_CHAIN_KICK` harder per link, up to `BOAT_CHAIN_MAX` links. **A kick never takes a boat past a ceiling** (boosted top speed plus `BOAT_CHAIN_TOP` per link: 151 to 175 for a skiff). Without it a chain down a current reached 257 studs/s, above what `police` allows. Keep the ceiling if you add kicks. **At chain speed a skiff barely steers** (about 180 studs of turning radius, and its course lags its bow): that is what the layout rules below are built on.
- `Boats.refund(boat, seconds)` shortens a boost cooldown (attribute `BoostRefund` tells the driver's client); `Boats.patch(boat, amount)` repairs a hull.
- AI boats take `boat.input = {throttle, steer, boost}` (see Navy).

### Treasure, Heat and consequences

- **Loot** (`Loot.lua`): 19 treasures in `Config.LOOT` (id, island, value, weight, carry speed, heat, respawn, trouble, visual). States `spot`, `carried` (welded above the head), `loose` (server physics; floats), `away` (banked). Steal immunity after any change of hands. **Interest**: untouched treasure gains value (`bonus`); banking pays `item.bankedValue`. **Treasure a creature carries stays `loose`**: `Loot.hold(item, cframe)` pins it (`item.held`), `Loot.letGo(item, velocity)` drops it, `Loot.sendHome(item, reason)` puts it back on its spot. So anyone can still grab it and every existing rule keeps working; do not add a state for it.
- **Heat** (`Heat.lua`): shared 0–100, tiers CALM, ALERT (25), HUNTED (50), FRENZY (80). It rises on theft and while carrying outside the ward (`HEAT_CARRY_RATE` 0.62: V4 was 0.48 on a sea with trips 30% longer); falls while nobody carries.
- **Escalation** (`Escalation.lua`) is what each tier *does*:
  - **ALERT**: carriers fire flares every 6 s that every player sees; totems and Fort turrets wake; carriers glow through walls.
  - **HUNTED**: a Navy **hunter** comes for the most valuable carrier; the Guardian hunts.
  - **FRENZY**: a second ship (a **blocker**) takes the way home and lays mines; a tempest steers at the thief; rougher sea everywhere.
  - Dropping below HUNTED stands the Navy down.
- **Threats** (`Threats.lua`): the Guardian (kinematic golem; walks Terrain and `Ground`, wades; speed 27, 32 at FRENZY; leashed to 520 studs from the temple's center until FRENZY, which is the whole of the bigger island). Its moves, all announced: **stomp** (fists up 0.8 s, then a ring races outward along the ground and hits only players standing on something as it passes: jump it), **leap** to a marked circle, **boulder throw** at a marked circle. Also totems, rollers, carrier reveal. Handlers for new trouble plug into `Threats.handlers`.
- **Troubles** (`Troubles.lua`) — one per treasure:

  | Treasure | Trouble |
  | --- | --- |
  | Lost Compass, Giant Pearl, Sunken Sextant, Castaway's Hoard | Gulls: the thief is revealed to everyone for 10 s |
  | Smuggler's Stash, Lighthouse Lens, Storm Lantern | Bell: the thief is revealed for 20 s |
  | Golden Gear | The windmill spins up (blades sweep the balcony) |
  | Captain's Chest | The wreck's cannon barrage |
  | Crystal Heart | Cave-in seals the tunnel |
  | Jade Frog | Quake: the rope bridges snap |
  | Pearl of the Deep | The vault gate slams shut and the chamber floods (swim the drain tunnel, or a friend pulls the lever) |
  | Tempest Trident | A squall settles on the whirlpool |
  | Admiral's Strongbox | Two patrol ships launch at once (if the fort's harbor chain is up, the moment it drops) |
  | Ember Crown | The volcano rains marked lava bombs |
  | Golden Idol | The Guardian wakes and a boulder rolls |
  | Aurora Gem | Snow boulders roll down the glacier |
  | Leviathan Tooth | Tentacles slam up around the island |
  | Skull Chalice | Fog, and a ghost fleet (18 s late if the Captain's shade is dozing: see Island inhabitants) |

- **Navy** (`Navy.lua`): AI patrol ships on `SeaNav` routes after the most valuable carrier they can *see* (line of sight, range 700, shorter in storms).
  - **Where they come from:** the fort if it is within `NAVY_BASE_RANGE` (1150: Navy Waters) of the thief, otherwise open deep water on the horizon, 750–950 studs out, on the thief's side of home and in sight.
  - **The harbor chain:** while the fort's chain is raised (`base.chain.progress`), `Navy.dispatch` sends nothing from the fort. Ships already out are not affected.
  - **Beacons:** `Navy.distract(position)` makes every patrol ship within `BEACON_RANGE` ignore carriers for `BEACON_TIME` and sail to that position.
  - **Roles:** a **hunter** sails an intercept (where the thief will be), runs alongside at `NAVY_STATION` firing, and charges. A **blocker** sits `NAVY_BLOCK_AHEAD` studs along the thief's line home and sows **mines** (`Navy.layMine`), then turns hunter when the thief is close. Every second ship is a blocker.
  - **Shells** land where a marker closes in over 1.5 s; up close it is a spread of three along the thief's course.
  - **The charge:** a horn (`NavyRam` event), then `NAVY_RAM_TIME` seconds on one bearing aimed where the thief will be if they hold course. It is not corrected, so turning dodges it. Then the ship swings wide before closing again.
  - **Mines:** bright, still, 40 s lifetime, go off for any hull or swimmer, and any blast sets off the mines it reaches (`Blast.Hit`).
  - They lose you behind islands or in the shallows (the reef passes and the whole Western Shelf are closed to them), search your last position for 25 s, then leave. They can be sunk. Carriers inside the Hoard ward are unreachable.
- **Blast** (`Blast.lua`): every explosion goes through `Blast.at` (players, boats, loose loot, destructibles) and fires `Blast.Hit`. `Blast.strike` shows a marker first. The blast's owner takes the shove at half strength and no damage (a keg at your feet is a launcher). A player sitting in a boat is moved with the hull, not separately.

### Lanes, courses, coins and salvage (`Searuns.lua`, `Coins.lua`)

- **The layout rules** (V6; the V5 playtest found the same content fun and badly placed):
  - **A teal hoop is a lane.** It points at a dock across open water, straight unless there is a reason to bend, a hoop about every 190 studs, with a small sign at each end saying where it leads. 13 of them (`refs.lanes`).
  - **An orange hoop is a timed course**, set apart from the lanes: a run threaded through stacks (The Teeth, Cinder Slalom), a sprint down a current (Serpent Run), or a lap round a landmark (Lookout Loop, Maelstrom Ring).
  - **A coin marks a line worth taking**: a weave through a course, a stack to hug, the air over a ramp, a trail into somewhere hidden. Six long lanes carry one between hoops. Coins never just fill water.
  - **Home Bay is calm**: one line of hoops from the harbor through the Gate. Some water (the fort's, the skull's, the far east, the south) has no lane at all, on purpose.
  - **A line of hoops must hardly bend.** A chain holds a skiff at 150 to 175 studs a second. Driven, a boat stayed on a line that bent 8 degrees at a gate and left one that bent 24. Keep to about 10 degrees a gate at 150 studs apart; a lap needs about 300 studs of radius; and **where the way really twists, use coins, not hoops** (the channel across the Western Shelf is a coin trail for this reason).
  - **A lane must not deliver a boat onto an island's threat.** The Leviathan Road stops 300 studs short of the Sleeper.
- **Coins** are server parts in the `Coins` folder with a `Value` attribute (1, or 5 for the big ones). `Coins.tick` checks every driven hull and every goblin on foot against a 64-stud grid of coins 20 times a second, and also half way back to the last check, so nothing is skipped at speed. Reach: `COIN_BOAT_REACH` 13, `COIN_FOOT_REACH` 7. **The client never claims a coin**; it only hides one a moment early so the pickup feels instant.
- **A coin right now:** `COIN_BOOST_REFUND` off the boat's boost cooldown and `COIN_REPAIR` hull. **A coin later:** the purse (`Coins` attribute) pays 1 gold per `COINS_PER_GOLD` at the Hoard, at most `COIN_GOLD_CAP` a raid (`CoinGold` attribute). A taken coin comes back after `COIN_RESPAWN`. Everything resets with the raid. There is nothing to spend coins on, and there must not be. All 132 coins are worth 240, four times one goblin's cap.
- **Timed courses** (`refs.runs`): a course starts at the hoop at either end and wants every hoop in order. A **lap** (`loop = true`) starts and ends at its first hoop, either way round; the clock keeps running for the next lap, and crossing the line with hoops missed starts a new one. A course pays `RUN_COINS` once a raid and `RUN_PAR_COINS` more the first time under par, and keeps the best time and name on its sign for the session. **Pars are measured** (the `PAR` table in `Searuns.lua`): a clean run by the test autopilot plus 15 to 20 percent. Change a course and measure its par again.
- **Salvage** (`Coins.dropSalvage(position, why)`): a floating crate worth `SALVAGE_COINS`, a keg, `SALVAGE_REPAIR` hull and a boost refill. `Main` drops one where a patrol ship sinks (`Boats.Sunk`) and where a storm blows out (`Storms.Spent`); `SALVAGE_ADRIFT` are set adrift each raid 45 to 70 studs to one side of a lane (never the Gate Run: Home Bay stays calm).

### Island inhabitants (`Creatures.lua`, `Bestiary.lua`, `BestiaryMinor.lua`)

- **`Creatures.lua` is the shared machinery; a creature is a table** registered with `Creatures.add({ name, island, home, wake, build, tick, reset, onTaken, onBlast })`. Numbers live in `Config.CREATURES`. To add one, copy the smallest (the clam or the fin in `BestiaryMinor.lua`).
- What the framework gives: `Creatures.body` (one anchored root, everything else welded, so moving it is one CFrame write), `pose`, `walk` (follows the ground; an `allowed` callback can refuse a step), `floor`, `canSee`, `players`, `carriers`, `nearest`, `looseLoot`, `strike` (**the one way a creature touches a player**: damage, push, knock loot loose, toast), `mark` (the ring), `fx` (a `Creature` GameEvent the client turns into a sound and a puff).
- **Sleep:** a creature is ticked only while a player is within its `wake` radius of its `home`, or while it sets `busy` (carrying treasure back, say). A test that does not put a player in range will see nothing happen.
- **Kinematic, like the Guardian:** no collisions, no raycast hits. They walk through walls and props.
- **Hooks:** `Creatures.onTaken(item, player, fromSpot)` is called from `Loot.Taken` in `Main`; `onBlast` from `Blast.Hit` (a keg stops every creature that can be stopped); `Creatures.reset()` from `Raid.resetWorld`. `Creatures.generation` is bumped on reset so a delayed action from an old raid never lands.
- **The rule for a new creature:** one idea a player can learn, a visible tell, no stun, no instant kill, nothing that leaves its island, and not the Guardian with a different skin.

  | Island | Creature | Rule | Effect |
  | --- | --- | --- | --- |
  | Crossroads Ruins | The Watchers (4) | Move only while no goblin within 170 studs is facing them | Touch knocks loot loose; one carries it back to its spot (slowly, and it can be taken from its arms) |
  | Crystal Isle | The Echo | Retraces the carrier's path 3 s behind | 16 damage, loot loose, to anyone it walks into |
  | Shipwreck Shoals | Old Clacker (crab) | Travels only under sand and shallows; a ring 0.85 s before it comes up | Toss, 10 damage, loot loose; reburies loose treasure it reaches |
  | Windmill Hills | Bramble (ram) | Charges in a straight line after a 0.9 s windup; only at goblins ashore | Long toss, 6 damage. Dazed if it hits a cliff. Rages after the Gear is taken |
  | Tide Vault | The Warden (eel) | Circles the shallows; hunts whoever is in the water for 30 s after the pearl is taken | 12 damage, loot loose, in water only |
  | Tangle Isle | The Imps (2) | A shriek and a ring, then it lands in 1.1 s | Takes the treasure to a nest in the west; drops it if approached; returns it after 18 s |
  | Fort Barnacle | The Garrison (2 marines) | A drawn vision cone on a patrol route | Whistle, charge, throws the goblin over the wall. No damage |
  | Ember Isle | Cinderlings (3) | Run to where a carrier is heading | Lay fire patches (8 damage per half second). Never touch the player |
  | Frost Spire | The Chill | A drifting cold that follows climbers | `Movement.chill`: stamina drains, none returns |
  | Leviathan's Rest | The Sleeper | Wakes to boats faster than 45 studs/s | Three marked tentacle strikes at the loudest boat (45 hull) |
  | Skull Rock | The Captain's shade | Eyes lit 16 s, dark 9 s, by the clock | Chalice taken while dark: the ghost fleet is 18 s late (it wraps `Threats.handlers.GhostFleet`) |
  | Maelstrom Rock | The Maw (fin) | Circles the whirlpool | Shoves boats (`Boats.shove`). No damage |
  | Coral Atoll | The Clam | Open 5 s, shut 3 s | The Giant Pearl's prompt only works while open; shut on a goblin: toss, 8 damage |
  | Goblin Cove | Gobbo | Friendly | A keg every 25 s; warns in the feed of a patrol ship or storm near home |

  The Sun Temple keeps the Guardian (`Threats.lua`). Pebble Isle, Gull Rock, Smuggler's Cove, Twin Stacks and the three keys have nothing living on them.

### Interactive island pieces

- **Destructibles** (`Destructibles.lua`): cracked walls (any blast), gates (cannonball), rope bridges (any blast, or a quake), powder barrels (chain reactions). Broken pieces become debris and are rebuilt from stored copies on reset.
- **Cannons** (`Cannons.lua`): island emplacements (Fort Barnacle's wall, the home practice range) and the Cutter. `E` fires where you aim; the server validates range, cooldown and aim, solves the arc and flies the ball.
- **Kegs** (`Kegs.lua`): `KEG_MAX` per player from crates, thrown with `G`, fuse 2 s.
- **Mechanisms** (`Mechanisms.lua`): the windmill's sweeping blades, the Maelstrom's foam spirals, levers and gates, lava that burns, and **signal beacons** (`Mechanisms.light`; fires `Mechanisms.BeaconLit`, which `Main` wires to `Navy.distract`). A gate entry may carry `hold` (seconds it stays moved) and `pulled` (the feed text): **Fort Barnacle's harbor chain** is a gate whose "open" position is raised across the harbor mouth.
- **Catapults** (`Kit.catapult`) are launch pads with a `Carry` attribute: the client holds the throw's sideways speed for that many seconds (a goblin's own air control would stop it short). Dash, air jump, a grapple or a zipline ends it. **Geysers** are animated and launch on the **client** from timestamps (attributes on the vent), so the server does nothing per frame.

### Movement, combat, spirit, raid

- **Movement** (`Movement.lua`): the only writer of `WalkSpeed`; owns stamina. Running (28) is free. Stamina pays for sprint, dash, air jump and a carrier's sword swing; `Movement.spend` scales every cost by the held treasure's weight (`CARRY_STAMINA_PER_WEIGHT`). `Movement.request(player, "dash" | "airjump")` is the client asking the server to pay for a move it already played. `Movement.chill(player, seconds)` stops regeneration and drains stamina (`CHILL_REGEN`, `CHILL_DRAIN`; attribute `Chilled`).
- **Combat**: sword (carriers swing slowly and tiredly), grapple. The grapple pull follows a moving anchor; aim that passes near a moving boat catches the boat (`GRAPPLE_BOAT_ASSIST`), and the server seats the player on the boat it hooked for them (`Combat.hookedBoat`).
- **Poltergoblin**: unchanged apart from a slightly longer dash and tether.
- **Raid** (`Raid.lua`): phases, scoring, `resetWorld()` resets every system (loot, Heat, threats, Navy and its mines, storms and their spouts, destructibles, mechanisms, cannons, kegs, boats, flood, coins and salvage, creatures).
- `Players.CharacterAutoLoads` is off until the world is built, then everyone is loaded.

### Client

- `Hud.lua`: timer, Heat bar, sorted treasure board (with interest), feed, banner, objective line, ability slots (sword, throw, grapple, keg, Poltergoblin; stamina and dash bottom-left), boat panel (speed, hull, boost, **drift meter**, hoop chain, anchor, cargo drag), the coin purse above the stamina bar, help.
- `BoatDrive.lua`: runs `BoatSim` on the boat you drive; boost and drift input; applies server pushes and boost refunds; reports hoop chains to the HUD; draws every nearby boat's wake and spray.
- `Map.lua`: the world map (`M`) and the **compass strip** (Hoard, treasures, storms).
- `Weather.lua`: reads `StormData`; draws cloud walls, fog, rain and darkening; sets wave size; warns "STORM TO THE NORTH-EAST - 600 STUDS".
- `Effects.lua`: sounds from `rbxasset://sounds/*`, neon effects, **markers** (a closing ring on the ground: the one visual language for "this lands here"), the Guardian's shockwave, lightning bolts, flares, shells, tentacles, fireworks, dash and air-jump puffs. The field of view follows speed (`Effects.setSpeed`) and kicks for a dash or a launch (`punchFov`); one writer per frame. **Sound has two kinds**, and `Effects.sound` decides by whether it is given a position: an INTERFACE sound (a chime, an alarm) plays in the player's ears; a WORLD sound plays at its place with `InverseTapered` rolloff, fades to silence at its `range`, and is **not played at all** beyond it or when it would be inaudible. At most `VOICE_LIMIT` of one sound start within `VOICE_WINDOW`, and the world's sound group has a compressor. Thunder is a world sound (`Effects.thunder`). Far-off markers, blasts and bolts are not drawn either. Numbers: `Config.AUDIO`.
- `Main.client.lua`: input, sprint, dash, air jump, grapple, zipline/pad/geyser movement, cannon and keg input, hiding coins the moment you pass them, hiding signs that are out of range, creature sounds and puffs (`CREATURE_FX`), event routing.

## Architecture

| Repository path | Rojo maps it to | Holds |
| --- | --- | --- |
| `src/server/Main.server.lua` | `ServerScriptService.LootGoblinsServer.Main` | Boot, wiring, player lifecycle, the one Heartbeat |
| `src/server/<Module>.lua` | `...LootGoblinsServer.<Module>` (ModuleScripts) | `Net`, `Util`, `Movement`, `Sea` (forwards to shared), `SeaNav`, `WorldKit`, `Landform`, `World`, `Islands`, `IslandsFar`, `Outlands`, `Seaways`, `Searuns`, `Boats`, `Loot`, `Heat`, `Poltergoblin`, `Destructibles`, `Blast`, `Cannons`, `Kegs`, `Mechanisms`, `Combat`, `Threats`, `Storms`, `Navy`, `Troubles`, `Escalation`, `Coins`, `Creatures`, `Bestiary`, `BestiaryMinor`, `Raid` |
| `src/client/Main.client.lua` | `StarterPlayerScripts.LootGoblinsClient.Main` | Input, client movement, event routing |
| `src/client/*.lua` | ModuleScripts next to it | `Hud`, `Effects`, `Map`, `Weather`, `BoatDrive` |
| `src/shared/*.lua` | `ReplicatedStorage.LootGoblins` | `Config` (tuning), `Archipelago` (the island list), `Sea` (sea math), `BoatSim` (boat physics) |

- **Plain modules, no framework.** Direct calls and tiny `Util.signal()` events. Require order has no cycles: `Net`/`Util` → `Movement` → `Sea`/`SeaNav` → `World`/`Boats` → `Loot` → `Heat` → `Poltergoblin` → `Destructibles` → `Blast` → `Cannons`/`Kegs`/`Mechanisms` → `Combat`/`Threats` → `Storms` → `Navy` → `Troubles` → `Escalation` → `Coins` → `Creatures` → `Bestiary`/`BestiaryMinor` → `Raid` → `Main`. (`Main` requires the two bestiary modules only so they register their creatures before `Creatures.build`.) Injections that avoid cycles: `Loot.canBank`, `Destructibles.explode` (set by `Blast`), `Threats.handlers` (filled by `Troubles`), `Blast.Hit` (Navy's mines listen), `Mechanisms.BeaconLit` (Main tells the Navy), `Landform.touch` (set by `World`), `Boats.Sunk` and `Storms.Spent` (Main drops salvage), `Loot.Taken` (Main tells `Creatures.onTaken`).
- **Remotes** (`ReplicatedStorage.LootGoblinsRemotes`, recreated at boot). Client → server: `ThrowRequest`, `GrappleRequest`, `PoltergoblinRequest`, `SprintRequest`, `MoveRequest("dash" | "airjump")`, `BoatBoostRequest`, `BoatDriftRequest(held)`, `BoatFxRequest(kind)`, `BoatBoardRequest`, `CannonRequest(basePart, aimPoint)`, `KegRequest(aimPoint)`.
- **`GameEvent(kind, payload)`** server → client. V2's kinds plus: `Dash`, `AirJump`, `BoatFx` (a drift burst or clean landing on someone else's boat), `BoatPush` (to a driver: apply this push to your hull), `GuardianStomp`, `NavyRam`, `Spout`, `Beacon`, and V5's `Coin` (you took one), `CoinsBanked`, `Run` (started, finished, new best), `Creature` (a creature did something here: the client picks the sound and puff by `kind`). **V5 and V6 added no remote.** `Net.broadcastNear(position, range, kind, payload)` sends an event only to goblins within `range` of where it happened; `Blast.lua` uses it for markers, bolts and blasts (a storm across the sea is nobody's business at home). Use it for anything loud and local.
- **Replicated state is attributes** (times in `workspace:GetServerTimeNow()` units). Player: `CarryingLoot`, `Kegs`, `Stamina`, `Sprinting`, `Winded`, `Chilled`, `Coins`, `CoinGold`, grapple/Poltergoblin timers. Boat model: `BoatType`, `Health`, `MaxHealth`, `Pilot` (UserId of the client simulating it), `Moored`, `BoostEndsAt`, `BoostReadyAt`, `BoostRefund`, `Payload`. Coin part: `Value`. `workspace`: `RaidPhase`, `PhaseEndsAt`, `Heat`, `HeatTier`, `GuardianState`, `StormData`, `SeaRough`. `Loot` folder: `<id>State`, `Carrier`, `CarrierId`, `ReturnAt`, `Bonus`. Vent: `GeyserPeriod/Active/Phase`, `Launch`. Launch pad: `Launch`, and `Carry` on a catapult.

Integration points new code must respect:

- **WalkSpeed and stamina:** go through `Movement`. **Player damage:** `Util.damage` + `Poltergoblin.markDamage` (or just use `Blast.at`). **Knocking loot loose:** `Loot.knockLoose` respects immunity; `Loot.dropFor` ignores it. **Teleports/resets:** cancel Poltergoblin, unseat players. **Pushing players:** `Util.knockback`. **Pushing or moving boats:** `Boats.shove`, `Boats.place`. **Explosions:** `Blast.at` / `Blast.strike`, never ad-hoc. **Telegraphs:** anything dangerous must show a `Marker` (or its own clear tell) first. **Sounds:** a sound that happens somewhere must be given its `position` (never play a world event as an interface sound: that was the map-wide thunder of V2 to V5). **Creatures:** touch a player only through `Creatures.strike`, and hold treasure only through `Loot.hold`.
- **The shared E key:** a visible prompt always wins over Poltergoblin.
- **The shared C key:** dash on foot, drift in a driver's seat.

## Who decides what (server vs client)

- **The server owns:** treasure state and possession, steals, banking, scores, raid phases, Heat, every threat, **boat health, crashes, sinking, boost cooldowns and seats**, every blast, cannon/keg counts and firing, gates and levers, damage, cooldowns, WalkSpeed, stamina, teleports, **every coin pickup, run time, purse payment and everything a creature does**.
- **The client owns:** its own character physics (Roblox default): walking, dash, air jump, the Poltergoblin dash, ziplines, launch pads and catapult flights, geyser launches and the grapple pull toward a server-chosen anchor; **the physics of the boat it is driving** (checked by the server every frame: speed, altitude, jumps); plus HUD and effects.
- **What clients send:** intent only ("dash", "boost", "fire cannon X at point P", "throw keg at P", grapple aim, "seat me on the boat you hooked"). The server checks range, cooldown, stamina, finiteness and that the cannon/boat exists. The client never says who it hit, how much damage, or which boat to board.
- **Known gap:** a modified client driving a boat can gain a little more than a boost's worth of speed inside the server's margins, turn tighter than the physics allow, and avoid crash damage. Blasts, shells, mines and sinking still apply. `BOAT_CLIENT_PHYSICS = false` closes the gap at the cost of steering lag.

## Important files

| File | Why it matters |
| --- | --- |
| `AGENTS.md` | Rules for every AI session. Read it first. |
| `README.md` | Player-facing summary and controls |
| `docs/reports/2026-10-12-v6-ocean-flow-audio.md` | V6: what was wrong with V5's layout, the layout rules, every lane and course with its measured time, the sound fault and its fix, before and after maps and pictures, tests, limits and the human playtest checklist |
| `docs/reports/2026-10-12-v5-living-threats-playful-seas.md` | V5: the compressed layout and travel table, the runs, coins, the creature roster and each one's counterplay, measurements, tests, limits and the human playtest checklist |
| `docs/reports/2026-10-12-v4-living-archipelago.md` | V4: the layout and why, what each island gained, the travel table, measurements, tests, limits and the human playtest checklist |
| `docs/reports/2026-10-11-v3-power-speed-peril.md` | V3 reasoning, before/after numbers, measurements, tests, limits |
| `docs/reports/2026-10-08-v2-archipelago.md` | V2 design reasoning and its checklist |
| `docs/reports/2026-10-07-sprint-grapple-bigger-map.md` | Sprint, grapple and the earlier map |
| `docs/reports/2026-10-06-vertical-slice-foundation.md` | The vertical slice's reasoning |
| `docs/WORKSTATION.md` | Setup, daily commands, Studio verification, troubleshooting |
| `docs/DESIGN_THESIS.txt` | Long-term vision (not current scope) |
| `Play Loot Goblins.bat`, `scripts/play.ps1` | One-click play for Ethan and Ninety |
| `scripts/bootstrap.ps1`, `dev.ps1`, `check.ps1`, `common.ps1` | Tool install, Rojo build/serve, checks |
| `rokit.toml` | Pinned Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0 |

## Development workflow

`AGENTS.md` is the authority. In short: sync `main`, then work on one short-lived task branch. Run checks and Studio tests, open a PR, and **never merge without explicit human approval**. PR descriptions follow `.github/pull_request_template.md`.

- **Ethan and Ninety do not use terminals.** They double-click `Play Loot Goblins.bat`. You run the Git steps and `./scripts/play.ps1` for them.
- `./scripts/check.ps1 -Fix` runs StyLua, Selene, a Rojo build and `git diff --check`. CI runs the same script.
- `check.ps1` and `dev.ps1` rebuild `build/LootGoblinsTest001.rbxlx`, a disposable output.

## Rojo and Studio MCP

- Rojo serves on `127.0.0.1:34872` (our other games use other ports; with several Studio windows open, connect each plugin to the right port by hand).
- **The Rojo plugin drops its connection each time play mode starts or stops, and Rojo 7.7.1 can crash when a watched file vanishes mid-write.** Run `rojo serve` in a restart loop, reconnect the plugin after each play session, and confirm `#Script.Source` matches the file before trusting a test.
- **The plugin's Connect button cannot be pressed through MCP.** If the human is away and the plugin is not connected, an Edit-mode `execute_luau` can set `Source` on the mapped scripts itself (the V3 session pulled `src/` from a helper on the loopback address; that needs `HttpService.HttpEnabled` in the disposable built place, switched off again afterwards). Compare sources before trusting a test either way.
- **Studio caps a background window at 15 frames per second, and stops rendering when the display sleeps.** Client-side timings are then one 67 ms frame coarse, injected keys stop arriving and screenshots time out. Measure the client's frame rate before trusting a client-side number, and say so in the report.
- **Use the official Studio MCP only.** Call `list_roblox_studios` first. Studio MCP lists every open Studio to every AI client, so pick the one named `LootGoblinsTest001.rbxlx`. `get_studio_state`, `execute_luau` (Edit/Server/Client), `start_stop_play`, `get_console_output`, `screen_capture`, and `user_keyboard_input` all exist.
- **Never `require()` a game module from `execute_luau`.** It loads a separate copy, and a separate copy of `Net.lua` destroys and recreates `LootGoblinsRemotes`, which cuts the running game off from its own remotes (nothing errors; inputs just stop working). Read attributes and instances instead. For deep tests install a temporary Script in `Workspace` (Studio session only, never committed; Rojo does not manage Workspace) that requires the game's own modules and obeys a `DebugCmd` attribute with fixed, named commands.
- **A raycast on terrain nothing has touched makes the engine build that terrain's collision** (about 90 microseconds each, the first time). Never probe the whole map with raycasts at start-up.
- **Terrain is found about two studs above the height a voxel fill suggests** (a block filled to -28 is at -26 to a raycast). `Landform` compensates; the old fill helpers do not. Measure a depth with a raycast before trusting it.
- **After moving or adding world geometry, check it by machine:** known objects by name near where they should be, no part far from every island, every boat's hull over at least 3.2 studs of water, every zipline's line clear (sweep a sphere along it).
- **Designing a layout (V6's method).** Survey the sea once by raycast on a 10-stud grid from a test command and post it to a loopback helper (223,000 rays take 2 seconds). Draw it, with every hoop and coin dumped from `refs`, as a picture you can look at. Lay new routes out in a script that uses the same curve maths as `Searuns.lua` and checks them against the survey, then build, dump again and compare. It is far quicker than a play session per idea, and the picture shows what a list of coordinates hides.
- **Drive what you lay.** A test command can seat the goblin in a skiff with `Config.BOAT_CLIENT_PHYSICS` off and set `boat.input` each frame, so the server drives the hoops with the real `BoatSim`: steer at a point 45 to 100 studs ahead along the course, boost when pointing the right way. It found every fault listed in the V6 report, section 13. It is not a person: it says whether a route can be followed, not whether it is clear or fun.
- **A `Sound` with a position uses `RollOffMode.Inverse` by default**, which never reaches silence and cuts off dead at `RollOffMaxDistance`. `InverseTapered` fades to nothing at the range. A client-side logger on `SoundService.ChildAdded` and `workspace.Terrain.DescendantAdded` shows every sound the game plays, with its settings and distance: the way to check audio without ears.
- **`BillboardGui.MaxDistance` is measured along the camera's line of sight**, not to the adornee.
- **When Studio's window is in front the client runs at 60 frames a second** and injected keys arrive. Measure the client's frame rate first, every session, and take client readings when it says 60.
- **Keep a shell command under about 8,000 characters** on Windows: a longer one is cut off and fails with a quoting error. Write long scripts and edits to a file and run the file.
- **Never build a text replacement from positions without checking their order.** An empty search string replaces between every character (it turned a 23 KB file into 12 MB; taking the inserted text back out restored it). Assert that the text to replace is found exactly once.
- Never open a second Studio copy of the same place. Never force-kill Studio. Stop play mode when you finish.
- Cloud sessions have no Studio. Say so plainly.

## Testing expectations

- Every change: `check.ps1` passes. Gameplay changes also need a Studio playtest with an empty console, then play mode stopped. Report anything you could not test.
- Timed effects are shorter than MCP round trips: record state in a `task.spawn` loop and read it afterwards.
- Single-client MCP play cannot test player-vs-player features. Teleporting 1000+ studs under streaming can let a character fall through terrain that has not loaded yet; that is a test artifact, not a game bug.
- Boat physics run on the test client when it drives. To test them without depending on injected keys, set `boat.input` from a temporary test script (the server then simulates with the same `BoatSim`).
- Studio's network simulator (`settings():GetService("NetworkSettings").IncomingReplicationLag`) is a Studio-wide setting: put it back to 0.
- The real validation is the human multiplayer test: **Test > Server & Clients > 4 players > Play**. The V6 report has a checklist.
- A sleeping creature is not ticked. To test one, put a goblin within its `wake` radius first; `Creatures.active()` says how many are awake.

## Design philosophy

- Serve the loop. Ugly and fast beats polished and slow. Primitive parts and terrain are fine.
- **Travel is play, not a toll.** Running and sailing must be fun with nothing else going on. Never restore difficulty by making the player sluggish.
- Threats target carriers, not players. Holding treasure is what makes you the problem. (Two creatures bend this on purpose, the eel's circuit and the ram: both are visible from far off and do little damage.)
- **A creature is a rule, not a health bar.** Each inhabitant asks one question (which way are you facing? what are you standing on? who can see you?) and knowing the answer should be power. Most take the treasure, the route or the ground, not hit points.
- **Commitment is not difficulty.** Deeper treasure is worth more because it is far, costly to carry and nasty to leave, not because a lock is harder.
- **A carrier is exposed, not crippled.** Loot costs stamina, fighting power, stealth and boat speed. It does not make walking feel bad.
- **Qualitative escalation.** Heat should change what the world does (a ship ahead of you, mines across the way home, a storm that chases), not just raise damage numbers.
- **Telegraph everything dangerous, and make the answer an action.** A ring to leave, a ring to jump, a horn to turn away from. "I saw that coming, tried something, almost made it" is the target; "I have no idea what hit me" is a bug.
- **Preserve quiet.** Storms come in gaps, not constantly.
- **Geography is a mechanic.** A reef, a shelf, a strait or a crag should change what a player can do or where a pursuer can go, and should be readable (green lamps mean shallow). Prefer one rule that works everywhere to a special case on one island.
- **Distance is measured in seconds.** Choose where things go from travel time at the boats' real speeds, and put something on every leg. V4 at 4.6 times V3's area was too far; V5 settled at 2.5 times.
- **Offers, not fences.** A hoop run or a coin trail goes where a boat already wanted to go and never blocks the water beside it. Side rewards (coins) stay small enough that treasure is still the score.
- **Placement over quantity.** More things to do is not more to do: past a point they hide each other. Give each kind of thing one look and one meaning (teal lane, orange course, coin for skill or a secret), keep the first view calm, and leave some water empty so the busy water reads as busy.
- **A valid placement is not a good one.** A route can clear every rock on paper and still be unfollowable at the speed the game gives. Look at it from the player's camera and drive it.
- **The world sounds as far away as it is.** A thing that happens somewhere is heard from there, quieter with distance and not at all from across the sea.
- Deepen what exists before adding content. Keep diffs small and local, reuse the patterns, put numbers in `Config.lua`.

## Major implementation decisions

- **The world is generated at runtime**, terrain included; builders describe, mechanism modules run.
- **The original islands are moved by a build offset, not rewritten**, and new land is generated around them first. It keeps what was playtested byte-for-byte the same shape. The price is that their builders' coordinates are no longer where things are: read `Archipelago.lua` for that.
- **The sea's features are placed from island positions**, so the layout is one list of numbers. V5's compression was that list plus re-laying the runs.
- **One creature framework, many small behaviors**, all kinematic and asleep unless a player is near (all 21 ticking at once cost 0.15 ms a frame).
- **Coins are plain server parts**, collected by a server check on a grid, not a client claim.
- **The sea's layout is hand-placed data under written rules**, not a formula: every lane is two or a few points in `Searuns.lua`, chosen on a map and then driven.
- **Loud, local effects are sent only to goblins near them** and culled again by each client's own camera.
- **A bigger world costs start-up time** (6 to 7 s, was 3). The silhouettes are built in the background after players are in; the rest is terrain, water and the sea grid.
- **Boat physics are one shared module run by whoever owns the hull.** A driven boat is simulated by its driver's client so steering is immediate (measured: 64 ms key-to-motion against 400 ms server-owned, with 100 ms of lag each way); the server keeps health, crashes, sinking and cooldowns and polices the hull. The cost is the cheating gap described above. One Config flag reverts it.
- **Sea math is separate from the visual water**, and shared, so waves, currents and shelter are cheap, deterministic and the same on both machines.
- **Streaming is on**; far parts come and go; key landmarks are persistent.
- **The Guardian is kinematic** (no collisions, can't push loot off the map) and walks over walls.
- **Sounds** use only `rbxasset://sounds/` files. No uploaded assets.

## Known limitations

- Primitive art; the skull, ribs and fort are blocky.
- Steep shore edges still stop a boat dead; boats pass through dock posts.
- Dash, drift, boost, grapple, throw, keg, cannon and Poltergoblin have no touch buttons.
- The Guardian walks through walls and can't enter tunnels. So does every creature: a marine goes through a barracks, a Watcher climbs the outside of the lighthouse.
- Creatures are a few blocks each. Their numbers and the timed runs' pars are first guesses.
- Old Clacker will not follow treasure into the water. Gobbo stands a little above the ground.
- The insides of the treasure sites were designed for V2's movement. V3's jump, air jump, dash and longer grapple were not checked against them.
- The new land is plain: trees, a few props and the features in the V4 report, no set dressing. Silhouettes are blocky and only cover ground taller than about 12 studs.
- A sign at the very edge of its range can blink (the range check runs every 0.4 s). Treasure tags still show across the whole map, by design. The map's region name "THE LONG REACH" no longer describes its water.
- The two laps are large (580 and 660 studs across). Whether they are worth their size, and whether straight lanes are better or duller than V5's, is unjudged.
- A patrol ship returning to the fort while the chain is up bumps against it until it gives up.
- Not tested with more than one player, on mobile, on weaker hardware, or with real latency. Client frame rate was first measured in V6: 60.0 fps on a desktop with nothing happening nearby. It has not been measured in a busy scene.

## Known bugs

- None confirmed. **Not exercised in V6:** whether any of the new layout is clearer or more fun to a person; **any sound by ear** (checked from logs of what was played and how loud by the falloff formula); the final blast range (20 to 600 studs) by log; any ramp; the coin trail across the Western Shelf; laps by hand (the autopilot's were not all clean); a patrol ship catching a carrier on a lane; anything with two players. **Not exercised in V5, and still open:** any creature against a player who moves or dodges, or with two players (a Watcher held by one goblin while it chases another, an Echo hurting a rival); driving the runs by hand apart from the Gate Run, so every par; Gobbo's keg and warnings; Bramble's rage after the Gear is taken; a cinderling going out in the sea; salvage from a real sunk patrol ship or spent storm; a coin coming back after 80 s; reaching the 6-gold cap. **Not exercised in V4, and the islands have moved since:** walking any of the new land, riding any zipline, driving by hand through the reef passes, inlets, the rib run or the Serpent Channel, fifteen of the sixteen new hoops, the new guns, the river of fire, taking the three new treasures, a patrol ship meeting the raised chain. **Still not exercised from V3:** anything between two players, drift with `BOAT_CLIENT_PHYSICS = false`, the Navy's charge against a cutter, windmill blade hits, the ice slide, anchoring in a current. **Unexplained:** Studio's process grew by 2.3 GB over a 67-minute unattended run while the game's own script memory and instance counts stayed flat (V4 report, section 11).

## Keeping this file useful

Update this file in the same PR whenever systems, controls, architecture, authority boundaries, or known bugs change. Keep it short and current. Session narratives belong in PR descriptions or `docs/reports/YYYY-MM-DD-<topic>.md`.

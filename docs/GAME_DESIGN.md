# Loot Goblins: game design and current systems

This is the single editable source for this game's vision, current mechanics, controls, architecture, design decisions, bugs, and limitations. Read AGENTS.md for team rules. Current code and dated evidence determine what is implemented; ideas and historical proposals do not authorize new features.

The AI updates affected sections here, records task evidence under docs/reports/, and runs the existing guide export. Generated root GAME_GUIDE.md packages this document, exact tuning, the shared quality rubric and lessons, and full dated reports into one attachment for another AI. Do not edit that generated file. The manifest and freshness files under docs/game-guide/ are export metadata, not additional game descriptions.

## Loot Goblins V8: identity, journey, and current scope

Loot Goblins is a social possession-and-escape game: steal ridiculous treasure from dangerous islands and other players, then somehow get it home. The desired rhythm is explore with awe, take something valuable, feel the world react, improvise an escape, bank the reward, and choose another risk. Fast movement and boat handling should be enjoyable before a reward appears. Danger challenges that power rather than restoring difficulty by making ordinary travel sluggish.

This guide describes the **V8** code on branch feature/v8-chaos-and-counterplay, which is stacked on V7 (branch feature/v7-skyfall-competitive-archipelago, PR #17, itself not yet merged into main). V8 is described in the section **V8 systems** below and in docs/reports/2026-10-13-v8-chaos-and-counterplay.md; where a V7 paragraph here disagrees with that section, V8 is what the code does. V7 and V8 have each been tested by one AI on one Studio client and **neither has been played by a person or with a second player**; their reports say exactly what was and was not exercised. The portable guide retains historical reports as history, while these current chapters describe the latest code.

### The first raid from a player's perspective

The world generates when Play starts, taking several seconds on the reported development machine; players are loaded after world construction. **A raid begins aboard the skyship** (V7): a flying pirate ship hung 540 studs over the middle of the sea. Goblins climb into a cannon and aim it by looking at where they want to land (V8), are thrown on a plain arc and tumble with loose limbs, and come down on land (head first like an ostrich if they fall fast, on their feet if they brake with a glide) or on the sea (which skips a fast goblin up to three times, each bounce smaller). They can also walk out along the ship's wings and step off. Goblin Cove is home. The Hoard is the visible gold ring/beam where treasure and coin proceeds are banked; it is never on the ship. Home also has boats, keg access, a practice cannon, movement toys, and a harbor jump. The intended introductory line is the harbor jump, the teal Gate Run, and the passage through the reef to the Crossroads. Home Bay deliberately leaves calm water and visual breathing room.

The near islands offer inexpensive short trips. Middle destinations add longer journeys and characteristic trouble. Far islands offer larger treasure with heavier carrying costs and harder return routes. A treasure pillar/name and the map/compass help choose a destination; the physical geography gives currents, reef passes, cover, high ground, and alternate routes that influence pursuit. A thief normally carries one treasure at a time. The personal decision is which treasure is worth exposing oneself for, and how to return without being robbed or stopped by the world.

A raid lasts twelve minutes (`Config.RAID_DURATION` 720) with a short intermission spent on the skyship; the first intermission is six seconds. The clock runs from the first second of deployment; the cannons unlock 3 s in and anyone still aboard at 40 s is fired off. In the last 90 s banking pays 25% more (the final rush). Banking adds Gold for that raid. At its end, every player tied for the highest positive Gold receives a Win; a zero-score raid has no winner. Gold resets next raid, and the world resets its systems. Wins are session values, not saved progression. Loose or carried treasure not banked in time does not become score. Death drops carried treasure and respawns the player at home after three seconds, allowing others to recover the object.

Taking treasure triggers its own trouble and adds shared Heat. Continuing to carry outside the home ward raises Heat; when nobody carries, Heat cools. Other players and world threats create exposure. The intended social result is improvised chases, theft, escape, group reactions, and another raid. Existing solo mechanical observations and some human feedback do not establish full multiplayer fun or fairness.

### Player verbs and tradeoffs

Run, sprint, dash, air-jump, grapple, board, steer, brake, drift, boost, anchor, steal, throw, swing, light a beacon, raise a chain, launch a keg, fire a cannon, hide, and bank. Not every verb needs a new system. The shared E key favors an actual visible prompt over spirit casting; C means dash on foot and drift while driving.

Running at 28 is free. Stamina pays for sprinting and exceptional moves; carrying treasure increases their costs and slightly slows the carrier. A carrier can defend themselves with a weaker, slower, shorter, tiring sword swing, and can grapple to surfaces/boats but cannot use the grapple to steal another treasure. Boats trade speed, durability, draft, handling, capacity, and cannon access. Geography can separate a shallow-water player route from a deep-draft Navy route. A beacon diverts nearby Navy, and the fort chain prevents new departures from its harbor for a period.

The score remains treasure. Coins encourage taking a skillful or interesting route, repair a little hull, and refund some boost cooldown; ten convert to one Gold when banked, with at most six Gold from coins in a raid. Timed courses provide a different movement challenge and a local best-time sign. Their presence should not turn every quiet crossing into a course.

### What has evolved through feedback

V2's world was worth exploring but travel and danger felt weak. V3 made movement and boats more powerful and changed threats to intercept, commit, and leave actionable tells. V4 enlarged and differentiated the world; a subsequent human playtest found the sea too spread out. V5 brought it closer and added inhabitants and sea activities; its feedback praised the map, boats, and creatures but found hoops/coins crowded and oddly placed. V6 rearranged the same offers, measured routes, and repaired global thunder. These are attributed historical findings, not controlled causal experiments or a guarantee of broad player preference.

V6's report was later amended after Ninety discovered the blocked Skull Chalice approach. The source now contains the ladder/hatch repair. Its earlier 'nobody has played V6' wording describes an earlier checkpoint; it must not erase that later feedback. Broader V6 layout, sound-by-ear, multiplayer, mobile, and balance acceptance remain outstanding.

### Current guardrails and absent features

V7 adds, on the team's explicit instruction in the V7 prompt (AGENTS.md still lists these as excluded before prototype approval; that line needs a human decision), a small progression layer: Shinies, five pets, start-with-gear kits and a saved profile, plus an inert Robux receipt foundation. There is still no XP, rarity economy, trading, boat upgrade tree or production architecture. The original long-term design vision appears later, explicitly as future direction. Rough geometry, primitive creature models, built-in sounds, and incomplete advertised input coverage are prototype compromises; they are not proof of release readiness.

An outside AI should deepen possession and escape, preserve movement agency, compare ideas against existing verbs, distinguish current V6 from historical configurations, and propose a small experiment behind the active gate. A mechanic rejected for another game is not automatically rejected here. A larger map, more inhabitants, or permanent progression requires an actual reason and human scope approval.

## Current approved version and development history

| Where | What it contains |
| --- | --- |
| Earlier main at `84b762a` (2026-10-07) | The **vertical slice** (PR #7: raids, loot, Heat, Guardian/totems/trouble, Poltergoblin, HUD, module split) and the double-click launcher (PR #8). |
| Included in V6: PR #9 | **Sprint + stamina**, the **grapple hook**, and a bigger map. Included in the V6 integration approved by Enrik on October 12. |
| Included in V6: PR #10 | **V2**: a 19-island archipelago, a physical sea (waves, currents, storms), physics boats, Navy pursuit, per-treasure troubles, Heat that changes the world, cannons, kegs, destructibles. Report: `docs/reports/2026-10-08-v2-archipelago.md`. One human playtest since: the world is more interesting to explore; the goblin and boats felt too slow. |
| Included in V6: PR #11 | **V3**: fast movement (dash, air jump, stamina for the exceptional only), fast boats with drift, driver-owned boat physics, a Navy that intercepts, charges and lays mines, a Guardian stomp, waterspouts. Report: `docs/reports/2026-10-11-v3-power-speed-peril.md`. One human playtest since: movement and boats feel right, and they have outgrown the world. |
| Included in V6: PR #12 | **V4**: a sea 4.6 times the size laid out in regions, the original islands moved (not rebuilt) and grown with generated land, reefs, shallows, stack fields and currents between them, a harbor chain, signal beacons, catapults, 19 treasures, retuned economy, Heat and storms. Report: `docs/reports/2026-10-12-v4-living-archipelago.md`. One human playtest since: the sea is too spread out, the boost hoops are the best part of sailing, and the islands need things living on them. |
| Included in V6: PR #13 | **V5**: the sea pulled in to 55% of V4's area (islands keep their size), 110 boost hoops laid out as 16 runs with chains and timed runs, coins, salvage, and **21 island inhabitants of 13 kinds** on one shared framework. Raids 9 minutes, values and Heat retuned. Report: `docs/reports/2026-10-12-v5-living-threats-playful-seas.md`. One human playtest since: the map size, the boats and the creatures are right; the hoops and coins are fun but crowded and oddly placed, worst of all outside the harbor; and there have been explosions in the distance since V2. |
| Included in V6: PR #14 | **V6**: no new system. The hoops, coins, lanes and timed courses laid out again by a few written rules (Home Bay calm, straight lanes that point at docks, courses set apart, coins for skill and secrets), every lane and course driven by an autopilot and its par measured, and the map-wide thunder fixed (world sounds are positional and fade to silence). Report: `docs/reports/2026-10-12-v6-ocean-flow-audio.md`. Studio-tested by one AI on one client, sound checked from logs only; **no human playtest of V6 yet**. |
| V7 (branch feature/v7-skyfall-competitive-archipelago) | **V7**: a flying-ship start (cannons, pencil dive and glide, splash bounce, head-first landing), a sea 20% wider with 16 major islands and computed difficulty tiers, faster boats with a hop, slow land driving and call-a-boat (B), a grapple that catches and an E that steals, regional alerts, gear-gated treasure, a visible Leviathan, white Navy ships, Shinies/pets/saved profile, twelve-minute raids, a final rush, route fixes (windmill, fort, Ember crater, Tide Vault). Report: `docs/reports/2026-10-13-v7-skyfall-competitive-archipelago.md`. **One AI, one client, no human or second-player test.** |
| V8 (branch feature/v8-chaos-and-counterplay, stacked on V7) | **V8, Chaos & Counterplay**: one flight system for the skyship's cannons and the island catapults (aim by looking, a ballistic throw, glide as a brake, dive, three diminishing water skips, loose limbs while tumbling), walkable wings, a stronger boat hop and a speed-based super jump, a sea form for every island's creature (`Pursuit.lua`), three kinds of ordinary sea mob (`SeaMobs.lua`), a Leviathan 2.2 times the size that hunts boats, one rule for being hit by the world (`Impact.lua`: grace, smaller bites, a two-strike grip on treasure, hulls battered but never sunk by creatures), no gear requirement on any treasure, a front door to the Tide Vault, treasure values flattened. Report: `docs/reports/2026-10-13-v8-chaos-and-counterplay.md`. Studio-tested by one AI on one client; **no human playtest and no second player yet**. |

The V6 report was subsequently amended after Ninety found the blocked Skull Chalice route; revision `8f399c7` repairs its ladder/hatch and records a single-client on-foot test. The table's earlier "no human playtest" wording describes an earlier checkpoint. This later route feedback is real, while the broad V6 layout, sound-by-ear, multiplayer, mobile, and balance acceptance remain outstanding.

Enrik explicitly authorized merging the complete latest V6 development line into main on October 12, 2026. PR #14 targets main and includes the ancestor work from PRs #9–13 plus the shared-memory rollout in PR #15. GitHub records the actual integration outcome. This approval does not certify outstanding human, multiplayer, audio-by-ear, or device tests. Historical reports below retain their original checkpoint status.

Everything below describes the approved V6 code and its current limitations.

## Purpose

Loot Goblins is a Roblox game by Ethan, Ninety and Enrik. The one-sentence thesis is: *steal ridiculous treasure from dangerous islands and other players, then somehow get it home.*

The loop: **explore (awe) → steal treasure → the world reacts → escape (panic) → bank → repeat.** Going out should feel like adventure; coming home with something valuable should feel like needing to GET OUT. V3's aim on top of that: **the player should feel powerful, the world should feel dangerous, and the fun is where those two meet.** Moving and sailing should be enjoyable in themselves, not the price of reaching the fun. V4's aim: **the world should be big and varied enough to deserve that movement**, with geography that is itself something to learn and use. V5's aim: **every island should have something living on it that a player can learn**, and the sea between them should be a playground, not a commute. V6's aim: **placement over quantity.** What the sea offers should be few enough, and laid out plainly enough, that a goblin can see it and choose. V7's aim: **a server of up to 32 should start with a spectacle and have somewhere different to go**: a ship to fall from, sixteen islands that each ask something different, an island robbed makes its neighbours wary, and what a goblin keeps between raids is a sidegrade, not power.

The design principle is **active novelty**: surprises the player participates in (a geyser to time, a ring to jump, a charge to dodge, a storm to steer around), not things that just happen on screen.

The long-term vision later in this document is not permission by itself to add anything; V7's progression is limited to what is described under "V7 systems".

## Core loop

1. Players start each raid on the **skyship** (V7), dive to an island of their choice, and bring treasure to **the Hoard** at **Goblin Cove**. A raid lasts `Config.RAID_DURATION` (720 s), then a short intermission on the ship.
2. Nineteen treasures wait on 19 islands (16 major, three keys with small stashes), each with a light pillar and a name tag visible from anywhere. **Value rises with distance and danger**: 1–2 g near home, 13–20 g in the far north. Values follow travel time and how hard the island is to leave (see the V5 report, section 11).
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
| `Shift` in the driver seat | **Boost** (2.4 s, 5 s cooldown, a kick at the start). Gamepad `X` | `Boats`, client `BoatDrive` |
| `Space` in the driver seat | **Hop** the boat (about 18 studs up, 1.1 s cooldown). Faster than `BOAT_SUPER_MIN` (150: a boost, a hoop chain, a drift burst) it is a **super jump**, up to about 38 studs at 187 studs/s and 57 at 215; a clean landing from one pays the landing burst. It does not leave the seat | `BoatSim`, client `BoatDrive` |
| `X` (gamepad `Y`) in a seat | Leave the boat | client `Main` |
| `B` (D-pad down) | **Call a boat** to the nearest shore (45 s cooldown) | `Recall` |
| `E` at a cannon on the skyship, or at an island catapult | Climb in. **Look** (mouse, or `W A S D`) at where you want to land; the ring is where you come down. Click or `Space` fires, `X` climbs out. `M` then an island points a ship's cannon at it | `Flight`, client `Skyship` |
| In the air after a launch | `W A S D` nudge the arc. Hold `Space`: **glide** (an air brake: slower fall, speed bled off, a soft landing). Hold `Shift`: **dive** (head first, down hard). Nothing held: you tumble | client `Skyship`, `Dive`, `Flight` |
| `P` | The locker: Shinies, pets, start-with gear | client `Shop` |
| `T` | Show every treasure on the board (default: loose or carried only) | client `Hud` |
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
| `F` | Grapple hook: grab loose loot (70 studs), **catch a carrier within 40 studs** (knocked down 2 s, nothing stolen), or hook a surface **or a boat** and get pulled (a boat seats you). Carriers can only pull, on a 5 s cooldown | `Combat`, client `Main` |
| `E` on a goblin who is down | **Steal** what they carry (within 8 studs, nothing in the way). `Space` gets a caught goblin up after 0.9 s | `Combat` |
| `Q` | Throw held treasure | `Loot` |
| `E` with no prompt showing | Poltergoblin (cast / early return) | `Poltergoblin` |
| `E` at a zipline | Ride; jump to let go | client `Main` |
| `M` | World map: islands, difficulty, who is on guard, your landing choice | client `Map` |
| `H` | Help panel | client `Hud` |

Abilities are keyboard and mouse, with the gamepad buttons above. Prompts and the sword also work on touch; nothing else has touch buttons yet.

## Systems

All tuning numbers live in `src/shared/Config.lua`. Gameplay modules never hardcode tuning.

### World and map

- **`Archipelago.lua`** (shared) is the one list of islands (id, name, x, z, radius, ring, colour) and of the sea's **regions** (names for the map). The server builds terrain from it; the client's map, compass and signs read it. North is -Z. The sea is 5880 x 5010 studs (`Config.BOUNDS_*`; V5 and V6 were 5080 x 4390, V4 6900 x 5840); its header explains the regions and why the distances are what they are. V7 moved every island beyond the home ring 20% farther from Goblin Cove along the same line; the islands kept their size. `Config.ISLAND_INFO` lists the sixteen major islands (tier, challenge, gear) and the supporting ones.
- **`World.lua`** builds the environment (sea floor, boundary walls in ≤2000-stud pieces, far-sea horizon slabs, haze) and the eight original islands (Goblin Cove, Crossroads, Sun Temple, Crystal Isle, Shipwreck Shoals, Gull Rock, Smuggler's Cove, Twin Stacks). **Those builders are written in the coordinates they were first built at**; each runs with a build offset (`Kit.setShift`, set by `moved(id, builder)`) that moves it, unchanged, to its place in `Archipelago`. Anything they leave in `refs` goes through `Kit.world` (aliased `W`). Offsets must be multiples of 4 studs (asserted), so the terrain lands on the same voxels. **To move an original island, change its x and z in `Archipelago.lua` in steps of 4; do not edit the builder's coordinates.** Twin Stacks must keep its offset from Crystal Isle (a zipline joins them).
- **`Islands.lua`** (Pebble, Coral Atoll, Windmill Hills, Tide Vault, Smuggler's stash) and **`IslandsFar.lua`** (Fort Barnacle, Tangle Isle, Ember Isle, Maelstrom Rock, Frost Spire, Leviathan's Rest, Skull Rock) already build relative to `Archipelago` and run with no offset.
- **`Landform.lua`** writes natural land into the Terrain voxels from a list of lobes (hills, ridges, mesas, cuts): wobbling coastlines, shelving seabeds, cliff-walled crags. It only adds to what is there. `Landform.shaper(cx, cz, spec)` is the convenient way in. It also makes the horizon **silhouettes** (`Landform.silhouette`, `Landform.mark`). Heights given to it are real heights (it compensates for the two studs the engine adds: see the Studio section).
- **`Outlands.lua`** is the new land around every island (`lands.<Id>`, built BEFORE the island builders so they lay their ground on it and carve their harbors out of it) and what stands on it (`places.<Id>`, built AFTER: docks, spare boats, ziplines, catapults, beacons, the harbor chain, the three new treasures). Offsets there are from the island's center.
- **`Seaways.lua`** is the water between islands: Wrecker's Reef and the Gate, the Western Shelf, the Teeth, the Serpent Channel, the Cinders, lone rocks, currents. **Everything in it is placed from island positions** (`from(id, dx, dz)`, or a point between two islands), never from fixed world coordinates, so it follows when `Archipelago.lua` changes. It exposes what other modules need to find (`Seaways.GATE`, `SHELF`, `TEETH`, `serpent()`, `rock(name)`).
- **`Searuns.lua`** is what is laid on that water: the lanes, the timed courses, the ramps and the coins. **Its header holds the layout rules; read them before adding a hoop** (they are summarized under "Lanes, courses, coins and salvage" below). It fills `refs.boostGates`, `refs.coins`, `refs.runs` (timed courses) and `refs.lanes`, and adds a line to `refs.buildWarnings` (which `Main` prints) for any hoop over water shallower than 3.2 studs.
- **`WorldKit.lua`** holds the shared helpers (parts, terrain shapes, docks, ladders, signs, cannons, bridges, geysers, and V4's `hoop`, `kicker`, `stream`, `hookPost`, `catapult`, `beacon`). It also records where anything was built (`Kit.touch`, exposed as `refs.builtOn`).
- **Builders only describe.** They leave data in `refs` (`breakables`, `barrels`, `kegCrates`, `cannons`, `levers`, `gates`, `beacons`, `spinners`, `geysers`, `lavaZones`, `boostGates`, `coins`, `runs`, `lanes`, `navyBases`, `troubleSites`, `targets`) and the mechanism modules run it. Never put logic in a builder.
- About 5,700 server parts (the skyship is about 290) and 43 boats, 101 gates (95 hoops, 6 ramps), 132 coins. **The world takes 3 to 4 s to build and the sea grid another 3 s** (V3: 3 s in all); `Main` prints both with a breakdown at start-up. Watch that line when you add terrain.
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
- Types in `Config.BOAT_TYPES`: **skiff** (135, the best drifter, fragile), **cutter** (104, cannon, 3 passengers, shrugs off crashes, rams hard), **navy** patrol ship (106, wide turns, deep draft, AI only, no bow skid, **white** with a blue stripe). V6's numbers were 108, 86 and 88; turn rate and its fade with speed were raised so chain-speed turning is no worse.
- **Hop, land, recall (V7).** `input.jump` hops a hull that has water or ground under it (`BOAT_JUMP_*`). A hull on the ground (`boat.grounded`, a raycast under it) drives at `BOAT_LAND_SPEED` of its top speed (about 22 studs/s measured; a boost does not raise it), and reversing backs it off a steep beach. `Recall.lua` (B) brings the nearest free boat, or builds a skiff (at most `RECALL_EXTRA_MAX`), to the nearest shore: placed `RECALL_OFFSHORE` studs out and driven in by the same physics.
- **Beaching**: player hulls carry an invisible sloped `BowSkid` so they ride up gentle shores. V7 boats drive on land slowly (see above); a steep step (about 30 degrees) still stops a hull, and reversing takes it back to the sea.
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
  | Pearl of the Deep | The vault floods to just below the top of its stairway (V8: the way out is the way in, up the stairs; or a grapple through the skylight) and the Warden follows a thief to sea |
  | Tempest Trident | A squall settles on the whirlpool |
  | Admiral's Strongbox | Two patrol ships launch at once (if the fort's harbor chain is up, the moment it drops) |
  | Ember Crown | The volcano rains marked lava bombs |
  | Golden Idol | The Guardian wakes and a boulder rolls |
  | Aurora Gem | Snow boulders roll down the glacier |
  | Leviathan Tooth | V8: the Leviathan hunts the thief once they put to sea (V7: tentacle strikes round the island) |
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
- **Combat**: sword (carriers swing slowly and tiredly), grapple. **V7: a grapple at a carrier catches, it does not rob**: `Combat.catch` knocks them down (`PlatformStand`, yanked toward the thrower, `DownedUntil` attribute, 2 s, then 6 s of immunity), and `Combat.stealFrom` (the E key, sent by a prompt the client builds on a goblin who is down) validates the thief, distance, line of sight, the hold and the throw cooldown before `Loot.steal`. The Hoard's ward protects. A pet Shell Tortoise absorbs one catch per 30 s. The grapple pull follows a moving anchor; aim that passes near a moving boat catches the boat (`GRAPPLE_BOAT_ASSIST`), and the server seats the player on the boat it hooked for them (`Combat.hookedBoat`).
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

## V8 systems

V8 (Chaos & Counterplay) answers the first human playtest of V7: the chaos was the fun part and its price was too high. The aim is more things going wrong, each of them survivable. Everything here was added on top of V7's systems; the V7 section below still describes the ship, alerts, progression, recall and navigation, except where a line here says otherwise.

### Being hit by the world (`Impact.lua`, `Loot.knockLoose`, `Blast.lua`, `Boats.hitAt`)

One set of rules for everything that is not another goblin (creatures, the Guardian, lava, blades, boulders, lightning, sea monsters). PvP is untouched: a sword, a thrown keg, a fired cannon and the grapple catch keep their own rules, so a creature brushing a carrier never shields them from a thief.

- **Grace.** After a world hit lands on a goblin, nothing else from the world can land on them for `IMPACT.GRACE` (1.2 s). `Impact.open(player)` is asked before every world hit.
- **Smaller bites.** World damage is multiplied by `IMPACT.DAMAGE_SCALE` (0.55), and one hit cannot kill a goblin who had more than `IMPACT.LAST_STAND` (30) health: it leaves them on 1.
- **The grip.** A world hit on a carrier does not take the treasure: it starts `GRIP.SLIP_TIME` (6 s) of "your grip is slipping". Only a second hit inside that window drops it, and after a drop the world cannot strip that goblin again for `GRIP.RECOVER` (10 s). The one exception is the Guardian's leap (`GRIP.HEAVY`), which still drops at once. The imps use the same rule.
- **Hulls.** A blast nobody fired is multiplied by `IMPACT.HULL_SCALE` (0.6) on boats and cannot take a hull below `IMPACT.HULL_FLOOR` (12%): the world batters boats, it does not sink them. The Navy's shells and mines say `sinks` and are exempt: being sunk by the Navy is the price of Heat. Crashing your own boat is not softened.
- Knockback is unchanged everywhere. Being thrown is the point.

### Flight: one system for cannons and catapults (`shared/Dive.lua`, `server/Flight.lua`, `client/Skyship.lua`)

- **Launchers.** The skyship's twelve cannons and the three island catapults (Crossroads, Sun Temple, Fort Barnacle) are the same thing: `Flight.addLauncher`. A goblin climbs in (`E`), the client sends the **point** it is looking at (never a velocity), and the server works out the throw with `Dive.solve` from that launcher's own numbers (`CANNON_SPEED` 440 at 32 degrees: 3,560 studs of reach from the ship, the farthest island is 3,130 away; `CATAPULT_SPEED` 200 at 60 degrees: about 575 studs). Out of reach, it throws as far as it can that way and the ring turns red.
- **Aiming is looking.** In a launcher the mouse (or `W A S D`) turns a camera above it; the middle of the screen is the aim. The gold ring is the first place the flight touches, drawn from the same model the flight uses, with smaller rings where the sea will skip you on to. From a ship's cannon the ship is hidden (only your own barrel stays, faintly) and every major island wears its name and tier. A launcher starts aimed at a sensible place (an island picked on the map, or what a catapult was built to reach) and stays exactly on it until the player turns it.
- **The air.** The throw gives the distance: a plain arc under `DIVE.GRAVITY` (60). No keys: **tumble**, with a small sideways push from `W A S D` (`TUMBLE_STEER` 16). `Space`: **glide**, an air brake (fall eases to `GLIDE_SINK` 55, speed across bleeds to `GLIDE_SPEED` 50: under one stud across per stud down, where V7's glide covered 5.7). `Shift`: **dive** (`PENCIL_GRAVITY` 170, head first). None of them adds distance.
- **Loose limbs.** A tumbling goblin's shoulders, elbows, hips and knees are switched off on the server and hang on ball sockets; taking hold (glide or dive) switches them back and the goblin strikes a pose. Joints are disabled, never removed, and the neck and waist are left alone. Both kinds of Roblox avatar joint are handled (`AnimationConstraint` and `Motor6D`).
- **Endings**, decided by the server from the goblin's root: the sea, fast: a splash and a **bounce**, up to three (`BOUNCE_UP` 95, 66, 40: about 75, 36 and 13 studs high), keeping 45% of the speed across and never more than 150, so three skips cover at most about 650 studs; the sea, gently or while gliding: a plain landing at the surface; the ground at more than `OSTRICH_SPEED` (95) without a glide: head first into it for 1.1 s, then spat out; the ground slower or gliding: on your feet at once. A flight that has not ended after 45 s is ended where it is.
- **The ship.** Its wings are deck: a gate amidships on each side opens onto a broad wing with a plank walkway and a diving board at the tip. Stepping off anywhere is a free dive. The deployment window is 40 s. Storms ignore anyone above `STORM_CEILING` (200 studs): lightning used to find goblins on the deck.

### Boats: the super jump (`shared/BoatSim.lua`)

`Space` at any speed is a stronger hop (`BOAT_JUMP_SPEED` 80: about 18 studs, V7 was 8.5). Faster than `BOAT_SUPER_MIN` (150 studs/s; cruising is 135, a boost 215) the jump grows with speed up to `BOAT_SUPER_SPEED` (150): measured 37.7 studs up and 1.2 s in the air at 188 studs/s with a real driver. The bow comes up and the upright assist levels it; the landing burst is paid for a super jump and not for a plain hop. `BOAT_MAX_ALTITUDE` is 130 so the anti-cheat accepts it.

### Pursuit: every island's creature follows a thief to sea (`Pursuit.lua`)

When a goblin carrying an island's treasure is on the water more than `PURSUIT.CLEAR` (70) studs off that island's shore, the island sends its **sea form** after them. One per island, `PURSUIT.MAX` (5) at once. Every form has a tell before it strikes and a rest after; ends after `PURSUIT.TIME` (50 s), beyond its leash (studs from the shore), when the treasure is banked, dropped or taken, or when the thief has been ashore 5 s; flinches for 4 s from any explosion near it and goes home after the second; and is removed by the raid's reset. A strike that misses earns only a short rest (`MISS_REST` 1.6 s). Hull damage from them goes through `Pursuit.batter` (never below the hull floor).

| Island | Sea form | What it does | The answer |
| --- | --- | --- | --- |
| Windmill Hills | **Bramble the ram, in a washtub** (150 studs/s) | Lines up and charges in a straight line it cannot turn out of (240 studs/s): rams the boat sideways and up | Turn or jump when he bleats |
| Tangle Isle | **The imps' raft** (158) | Pulls alongside; one imp leaps for the treasure (a grip hit, no damage) | Get away from the raft's side for a second: boost, jump, turn |
| Shipwreck Shoals | **Old Clacker**, under the surface (150) | A ring opens under where your boat is going; a second later the crab comes up through it and the boat goes into the air | Change speed or course when the ring opens |
| Tide Vault | **The Warden eel** (170, leash 800) | Goes under the bow and lashes the boat round: you end up pointing the wrong way | Outrun its short leash; a blast |
| Coral Atoll | **The clam** (jets, about 150) | Clamps onto the hull and drags for up to 4 s | **Jump**: it cannot hold a boat that leaves the water |
| Maelstrom Rock | **The Wandering Maw** (74) | Its whirlpool follows you: boats within 170 studs are pulled in and round, and the middle spits them into the air | It is slow: leave. Do not stop near it |
| Crystal Isle | **The Echo** | Repeats the exact way your boat went, a few seconds behind, the gap closing from 3.4 s to 1 s | Keep moving; never double back |
| Fort Barnacle | **The garrison's launch** (140) | Hangs back and drops swivel-gun shot ahead of you, each marked first | Weave; it only rocks the boat |
| Sun Temple | **The Guardian's boulders** (it will not swim) | Throws a boulder every 3.1 s at where you will be, marked 1.75 s ahead | Steer off the ring; get out of range (950 from shore) |
| Crossroads Ruins | **The Watchers' gaze** | Walks a row of five marks across the water at you | Turn across the line |
| Ember Isle | **The Cinderlings' fire** | Spits fire that burns on the water for 7 s | Steer round the patches |
| Frost Spire | **The Chill's breath** | Freezes a patch of sea ahead of you for 5.5 s; a boat on it is held | Steer round it |
| Leviathan's Rest | **The Leviathan** | See below | See below |
| Skull Rock | **The Ghost Fleet** (V4, unchanged) | Ghost ships hunt the thief | As before |

Pebble Isle, Smuggler's Cove and the three keys have no hostile inhabitant and send nothing.

### Sea mobs (`SeaMobs.lua`)

Twenty-five, placed once at build time by a fixed seed (so players can learn them), by region: none in Home Bay (the nearest is 1,086 studs from the Hoard) or Navy Waters, none within 150 studs of any shore. A mob nobody is near does nothing at all.

- **Nibblers** (7 schools): chase a passing boat for up to 9 s, latch on, gnaw 1.5 hull each half second and drag. A jump shakes them off at once; they give up after 5 s anyway.
- **Puffers** (11): float and do nothing until a boat runs into one, then bounce it into the air (`PUFFER_LIFT` 140). No damage: a free jump for a driver who aims for one.
- **Lancers** (7): mark a straight 300-stud line on the water and, 1.1 s later, go down it at 260 studs/s, knocking aside what is on it (6 hull, a grip hit). Leave the line.

### The Leviathan hunts (`Leviathan.lua`)

2.2 times its V7 size (the head is 48 x 31 x 57 studs, nine humps). It still lurks on its circle off the east dock of Leviathan's Rest. **How to start a hunt:** drive a boat faster than 45 studs/s within 240 studs of the Sleeper's eye for about two seconds, or steal the Leviathan Tooth and put to sea within 90 s. It swims after the nearest crewed boat at 165 studs/s in wide turns (it surges to 260 when the boat is more than 260 studs ahead), throws boats beside its head aside with a bow wave (no damage), and when it is within 220 studs it sinks, opens a 30-stud ring where the boat is going to be, and 1.6 s later comes straight up through it: a boat on the ring is thrown into the air and battered (48 hull before scaling, never sunk). It re-picks the nearest boat after every breach. It gives up after 55 s, 2,400 studs from home, in water shallower than 9 studs, or after three explosions on its head. Measured: a passive cruising skiff is hit twice and escapes at the leash; a boost and a super jump when the ring opens clears the breach untouched.

### Treasure

No treasure needs gear: the Rebreather, Cinder Boots and Frost Claws still exist and still help, and the server no longer checks for them. **Values are flat:** Lost Compass 4, Giant Pearl 5, Smuggler's Stash 5 (the three nearest home, with long respawns of 150 to 160 s so they cannot be farmed); Sunken Sextant 7, Storm Lantern 8, Castaway's Hoard 8 (the keys); everything else 9 to 11. Interest still adds up to three steps of about 12%. **The Tide Vault has a front door:** a boardwalk from the dock to the north ramp, and at the top of the ramp an open stairway down to the pearl under a skylight. Taking the pearl floods the vault to just below the top of the stairs, so the way out is the way in. Measured on foot: dock to pearl 5.0 s, and out again carrying it 5.4 s.

### The E key

`E` now acts on the nearest prompt the goblin is in reach of even when the camera is turned away from it (Roblox only shows a prompt that is on screen, so `E` used to cast Poltergoblin instead of stealing).

## V7 systems

Everything here is V7. Numbers are in `src/shared/Config.lua` (`SKYSHIP`, `DIVE`, `RECALL_*`, `BOAT_*`, `GRAPPLE_PVP_RANGE`, `CATCH_*`, `STEAL_*`, `ALERT`, `GEAR`, `ISLAND_INFO`, `PROGRESS`, `PETS`, `LEVIATHAN`, `FINAL_RUSH`).

### The skyship and the dive (`Skyship.lua`, `client/Skyship.lua`, `shared/Dive.lua`)

- The ship is built from plain parts into `Landmarks` (persistent) at `Config.SKYSHIP.POSITION` (0, 540, -80). Twelve cannons stand in its rails. Its parts are in the collision group `SkyshipHull`, and a goblin in a dive is in `SkyDiver`, which does not collide with the hull: that is how a diver starts inside a cannon and falls past a rail.
- **States** (player attribute `DeployState`): `aboard`, `loaded` (in a cannon, anchored; attribute `DeployAim` is the launch velocity), `fuse` (0.9 s), `diving`, `embedded`, `landed`. `Skyship.board` puts a goblin on the deck (a 6 x 6 grid of spots, spread by user id), `boardAll` is called when a raid ends and when one starts, `open` starts the window (`DeployOpensAt`, `DeployEndsAt` on `workspace`). A goblin below the deck before the cannons unlock is put back; after, it is a free dive. At the end of the window a goblin still aboard is fired off (`launch`) at their island or a near one.
- **Who decides what.** The client chooses (`DeployRequest("choose", id)`, `("aim", yaw, pitch)`, `("fire")`, `("leave")`); the server places, clamps the nudge to +-14 and +-10 degrees, fuses and launches, then **tells the diver's client where to start** (`DiveStart`). The goblin's own client flies (`Dive.step` each physics step, setting its root's velocity and orientation), exactly as a driven boat is simulated by its driver. The server watches the root every frame and decides how every dive ends (`resolveLanding`): water at or under the surface bounces once (`DiveBounce`: the client gives the hop its own gravity), ground at an impact of 95 studs/s or more buries the goblin head first (anchored 1.1 s, a wiggle, popped out), anything slower is a soft landing.
- `Dive.predict` draws the two landing arcs the cannon aim shows. The diver's pose (arms) is applied on every client from the `Diving` attribute and the root's orientation (`client/Skyship.lua`, `PreRender`).

### Regional alerts (`Alerts.lua`)

A theft puts its island on guard and, at a weight, the islands in `Config.ALERT.LINKS`. The level (0 to 3) falls with time and is published as `workspace` attribute `Alert_<id>` (the map draws a red ring). `Alerts.wakeFactor(island)` widens every creature's wake range; at level 2 `Navy.distract(position, range, time)` turns the patrol ships within 1,800 studs toward the island for 35 s. Heat is not touched.

### Gear (`Gear.lua`)

The player attribute `Gear` is one of `Rebreather`, `CinderBoots`, `FrostClaws`. Caches on Kelp Cay and Lantern Key hand them out (`ProximityPrompt`), `Gear.reset` clears them each raid, `Progress.onRaidStart` gives a bought start-kit. `Gear.allows(player, island)` is asked by the treasure's prompt: Tide Vault, Ember Isle and Frost Spire refuse their treasure without the piece. `Gear.fireproof` is asked by lava (`Mechanisms`), the burning patches (`BestiaryMinor`) and `Blast.at` (`opts.fire`); `Movement` applies the swim multiplier and the claws' chill drain. `Gear.pet` and `Gear.petIs` are where every pet effect is read (a server-validated attribute).

### The Leviathan (`Leviathan.lua`)

A set of anchored parts the Sleeper's tick moves: lurking humps, and a head and neck that slam at the marked circle. A blast near the head makes it recoil (`Blast.Hit`) and the Sleeper rest twice as long.

### Progress, pets, Robux (`Progress.lua`, `Monetization.lua`, `client/Shop.lua`)

Shinies are the lasting currency; raid Gold only decides the raid. `Progress.award` pays once per goblin per raid (participation, banked gold, the win, a small underdog lift, capped). The profile is one DataStore key per player; a profile that failed to load is **never saved over** the stored one (`SaveState` is `saved`, `unsaved` or `unavailable`). Purchases are checked against `Config.PETS`/`Config.KIT_PRICE`. Pets are drawn on every client from the attribute `Pet`. The Robux receipt handler is installed only when `Config.MONETIZATION.PRODUCTS` has an entry (it is empty): receipts are idempotent by purchase id and confirmed only after a successful save.

### Recall (`Recall.lua`), the final rush, navigation

See Boats (B). In the last `FINAL_RUSH` seconds `Raid.onBanked` pays `FINAL_RUSH_MULT` times. A carrier gets a waypoint arrow toward the Hoard (`Map.lua`); the compass lists only treasure within `COMPASS_LOOT_RANGE`; the treasure board shows only loose or carried treasure unless `T` is pressed.

## Architecture

| Repository path | Rojo maps it to | Holds |
| --- | --- | --- |
| `src/server/Main.server.lua` | `ServerScriptService.LootGoblinsServer.Main` | Boot, wiring, player lifecycle, the one Heartbeat |
| `src/server/<Module>.lua` | `...LootGoblinsServer.<Module>` (ModuleScripts) | `Net`, `Util`, `Gear`, `Movement`, `Sea` (forwards to shared), `SeaNav`, `WorldKit`, `Landform`, `World`, `Islands`, `IslandsFar`, `Outlands`, `Seaways`, `Searuns`, `Boats`, `Recall`, `Skyship`, `Loot`, `Heat`, `Poltergoblin`, `Destructibles`, `Blast`, `Cannons`, `Kegs`, `Mechanisms`, `Combat`, `Threats`, `Storms`, `Navy`, `Alerts`, `Troubles`, `Escalation`, `Coins`, `Creatures`, `Leviathan`, `Bestiary`, `BestiaryMinor`, `Progress`, `Monetization`, `Raid` |
| `src/client/Main.client.lua` | `StarterPlayerScripts.LootGoblinsClient.Main` | Input, client movement, event routing |
| `src/client/*.lua` | ModuleScripts next to it | `Hud`, `Effects`, `Map`, `Weather`, `BoatDrive`, `Skyship`, `Shop` |
| `src/shared/*.lua` | `ReplicatedStorage.LootGoblins` | `Config` (tuning), `Archipelago` (the island list), `Sea` (sea math), `BoatSim` (boat physics), `Dive` (the dive model) |

- **Plain modules, no framework.** Direct calls and tiny `Util.signal()` events. Require order has no cycles: `Net`/`Util` → `Movement` → `Sea`/`SeaNav` → `World`/`Boats` → `Loot` → `Heat` → `Poltergoblin` → `Destructibles` → `Blast` → `Cannons`/`Kegs`/`Mechanisms` → `Combat`/`Threats` → `Storms` → `Navy` → `Troubles` → `Escalation` → `Coins` → `Creatures` → `Bestiary`/`BestiaryMinor` → `Raid` → `Main`. (`Main` requires the two bestiary modules only so they register their creatures before `Creatures.build`.) Injections that avoid cycles: `Loot.canBank`, `Destructibles.explode` (set by `Blast`), `Threats.handlers` (filled by `Troubles`), `Blast.Hit` (Navy's mines listen), `Mechanisms.BeaconLit` (Main tells the Navy), `Landform.touch` (set by `World`), `Boats.Sunk` and `Storms.Spent` (Main drops salvage), `Loot.Taken` (Main tells `Creatures.onTaken`).
- **Remotes** (`ReplicatedStorage.LootGoblinsRemotes`, recreated at boot). Client → server: `ThrowRequest`, `GrappleRequest`, `PoltergoblinRequest`, `SprintRequest`, `MoveRequest("dash" | "airjump")`, `BoatBoostRequest`, `BoatDriftRequest(held)`, `BoatFxRequest(kind)`, `BoatBoardRequest`, `CannonRequest(basePart, aimPoint)`, `KegRequest(aimPoint)`; V7: `BoatJumpRequest`, `BoatRecallRequest`, `StealRequest(player)`, `DeployRequest(action, a, b)`, `ShopRequest(action, id)`.
- **`GameEvent(kind, payload)`** server → client. V2's kinds plus: `Dash`, `AirJump`, `BoatFx` (a drift burst or clean landing on someone else's boat), `BoatPush` (to a driver: apply this push to your hull), `GuardianStomp`, `NavyRam`, `Spout`, `Beacon`, and V5's `Coin` (you took one), `CoinsBanked`, `Run` (started, finished, new best), `Creature` (a creature did something here: the client picks the sound and puff by `kind`). V7's server events: `DiveStart`, `DiveBounce`, `DiveFire`, `DiveImpact`, `DeployOpen`, `RecallCalled`, `AlertRaised`; `GrappleFX` gained `catch`. **V5 and V6 added no remote.** `Net.broadcastNear(position, range, kind, payload)` sends an event only to goblins within `range` of where it happened; `Blast.lua` uses it for markers, bolts and blasts (a storm across the sea is nobody's business at home). Use it for anything loud and local.
- **Replicated state is attributes** (times in `workspace:GetServerTimeNow()` units). Player: `CarryingLoot`, `Kegs`, `Stamina`, `Sprinting`, `Winded`, `Chilled`, `Coins`, `CoinGold`, grapple/Poltergoblin timers. Boat model: `BoatType`, `Health`, `MaxHealth`, `Pilot` (UserId of the client simulating it), `Moored`, `BoostEndsAt`, `BoostReadyAt`, `BoostRefund`, `Payload`. Coin part: `Value`. `workspace`: `RaidPhase`, `PhaseEndsAt`, `Heat`, `HeatTier`, `GuardianState`, `StormData`, `SeaRough`. `Loot` folder: `<id>State`, `Carrier`, `CarrierId`, `ReturnAt`, `Bonus`. Vent: `GeyserPeriod/Active/Phase`, `Launch`. Launch pad: `Launch`, and `Carry` on a catapult. V7: player `DeployState`, `DeployDest`, `DeployAim`, `Diving`, `DownedUntil`, `CatchImmuneUntil`, `Gear`, `Pet`, `Shinies`, `OwnedPets`, `OwnedKits`, `Kit`, `SaveState`, `RecallReadyAt`; boat `Recalled`; `workspace` `DeployOpensAt`, `DeployEndsAt`, `Alert_<island>`.

Integration points new code must respect:

- **WalkSpeed and stamina:** go through `Movement`. **Player damage:** `Util.damage` + `Poltergoblin.markDamage` (or just use `Blast.at`). **Knocking loot loose:** `Loot.knockLoose` respects immunity; `Loot.dropFor` ignores it. **Teleports/resets:** cancel Poltergoblin, unseat players. **Pushing players:** `Util.knockback`. **Pushing or moving boats:** `Boats.shove`, `Boats.place`. **Explosions:** `Blast.at` / `Blast.strike`, never ad-hoc. **Telegraphs:** anything dangerous must show a `Marker` (or its own clear tell) first. **Sounds:** a sound that happens somewhere must be given its `position` (never play a world event as an interface sound: that was the map-wide thunder of V2 to V5). **Creatures:** touch a player only through `Creatures.strike`, and hold treasure only through `Loot.hold`.
- **The shared E key:** a visible prompt always wins over Poltergoblin.
- **The shared C key:** dash on foot, drift in a driver's seat.

## Who decides what (server vs client)

- **The server owns:** treasure state and possession, steals, banking, scores, raid phases, Heat, every threat, **boat health, crashes, sinking, boost cooldowns and seats**, every blast, cannon/keg counts and firing, gates and levers, damage, cooldowns, WalkSpeed, stamina, teleports, **every coin pickup, run time, purse payment and everything a creature does**.
- **The client owns:** its own character physics (Roblox default): walking, dash, air jump, the Poltergoblin dash, ziplines, launch pads and catapult flights, geyser launches and the grapple pull toward a server-chosen anchor; **the physics of the boat it is driving** (checked by the server every frame: speed, altitude, jumps); plus HUD and effects.
- **What clients send:** intent only ("dash", "boost", "fire cannon X at point P", "throw keg at P", grapple aim, "seat me on the boat you hooked"). The server checks range, cooldown, stamina, finiteness and that the cannon/boat exists. The client never says who it hit, how much damage, or which boat to board.
- **Known gap:** a modified client driving a boat can gain a little more than a boost's worth of speed inside the server's margins, turn tighter than the physics allow, and avoid crash damage. Blasts, shells, mines and sinking still apply. `BOAT_CLIENT_PHYSICS = false` closes the gap at the cost of steering lag.

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
- Not tested with more than one player, on mobile, on weaker hardware, or with real latency. Client frame rate: 60.0 fps (V6) and 59.8 fps (V7, at Skull Rock); never measured in a busy scene.
- **V7 has never had a second player.** The 32-player target is a code audit and a wider spawn pad, not a measurement. The ship, the dive pose, the Leviathan, the white Navy and the pets have not been looked at by a person; real DataStore saving has not run (Studio had no API access); the Robux receipt path is untested against a real purchase and is inert; touch has no buttons for the new actions; the island and boat cannons have an aim ring but no trajectory arc.

## Known bugs

- **V8 has not been played by a person, and never with two players.** Everything in the V8 report was measured by one AI on one Studio client. Other players seeing the loose limbs, two goblins flying at once, a pursuer choosing between two carriers and two boats sharing the Leviathan are untested.
- **V8 creature art is primitive**: the sea forms and mobs are a handful of blocks and balls each. The Leviathan's breach was measured (hull hits, states, the jump that dodges it) but never caught in a screenshot.
- **Pursuers swim in straight lines round land** (a look-ahead probe on `SeaNav`), not along routes: among tight rocks one can stall, and it gives up after its time limit.
- **Lobbers** (boulders, the Watchers, fire, ice) do not flinch from explosions: the answer to them is range.
- **The old catapult flight code on the client** (`flight` in `Main.client.lua`, for pads with a `Carry` attribute) is no longer reached; it was left in place.
- **Fixed in V7 and walked on foot:** the windmill ladder, the fort's cannon-stand ladder, the Ember crater (it was solid), the Tide Vault (the gate now starts open), and Skull Rock's ladder was re-walked. The other ladders (`DeckLadder`, `HoldLadder`, `UndercroftLadder`) were blocked on three of four faces in V6's scan and have not been climbed. **Not exercised in V7:** anything with two players; the skyship's pose; the dive from every cannon; two goblins calling a boat at once; the alert's Navy effect with a ship out; boots against real lava; claws against the Chill; picking gear up from a cache; the Leviathan and Navy by eye; the lap hoops are not all clean for the autopilot (Maelstrom Ring misses a hoop or two by 4 to 7 studs). **Not exercised in V6:** whether any of the new layout is clearer or more fun to a person; **any sound by ear** (checked from logs of what was played and how loud by the falloff formula); the final blast range (20 to 600 studs) by log; any ramp; the coin trail across the Western Shelf; laps by hand (the autopilot's were not all clean); a patrol ship catching a carrier on a lane; anything with two players. **Not exercised in V5, and still open:** any creature against a player who moves or dodges, or with two players (a Watcher held by one goblin while it chases another, an Echo hurting a rival); driving the runs by hand apart from the Gate Run, so every par; Gobbo's keg and warnings; Bramble's rage after the Gear is taken; a cinderling going out in the sea; salvage from a real sunk patrol ship or spent storm; a coin coming back after 80 s; reaching the 6-gold cap. **Not exercised in V4, and the islands have moved since:** walking any of the new land, riding any zipline, driving by hand through the reef passes, inlets, the rib run or the Serpent Channel, fifteen of the sixteen new hoops, the new guns, the river of fire, taking the three new treasures, a patrol ship meeting the raised chain. **Still not exercised from V3:** anything between two players, drift with `BOAT_CLIENT_PHYSICS = false`, the Navy's charge against a cutter, windmill blade hits, the ice slide, anchoring in a current. **Unexplained:** Studio's process grew by 2.3 GB over a 67-minute unattended run while the game's own script memory and instance counts stayed flat (V4 report, section 11).

## Additional system contracts for portable understanding

The complete current system catalogue, controls, creature roster, remote/state inventory, architecture, and exact tuning are embedded later. This chapter supplies context that a standalone AI must not infer from words such as 'unchanged'.

### Treasure states and banking

Treasure is a server-owned object with spot, carried, loose, and away states. Taking it from its spot involves a 0.6-second hold, triggers trouble, and assigns ownership. Loose treasure can be grabbed. A carry change gives temporary steal immunity; attacks should use the existing knock-loose path so that immunity is respected. Throwing, death, disconnect, boarding, spirit return, and reset must preserve one authoritative owner and avoid duplicate payment.

Untaken treasure gains interest in discrete eighty-second steps, at most three steps, using its value and the configured share; the exact tuning is included below. Its bankedValue stores the payout used by the score code. A carrier entering the Hoard ring banks it unless excluded by the ward/spirit rules. The object becomes away and returns later after its own respawn time. Gold is earned only when the server accepts a bank, not just when a client sees a pickup animation.

Creatures that carry treasure do not add a new ownership state: the item remains loose while Loot.hold pins it to the creature. A player can still grab it using existing rules. Loot.letGo releases it, and Loot.sendHome restores its spot. The distinction prevents a second inventory/possession implementation. A recently thrown item landing inside the Hoard can also bank for its last holder within THROWN_BANK_WINDOW; bank credit is still decided by the server. Lost or long-abandoned loose objects return to their spots under the existing bounds/timeout rules.

### Poltergoblin in full

Poltergoblin is a temporary spirit excursion, not a death/ghost mode. Press E without an active prompt to dash out of your body. The body stays frozen as a visible vulnerable copy. For five seconds, the spirit can move faster, fight, grapple, and grab treasure, then returns to the body's original position. E can request early return after a brief recast delay. The ten-second cooldown begins at casting; a ninety-stud tether also forces an early return.

Loot rides back along the tether, so the ability is a grab-and-rewind tool rather than advancing carried loot toward home. A sword hit on the abandoned body shatters the spirit: it returns hurt, its held loot drops where the spirit stood, and no damage echo is paid. A normal return repeats 35% of the spirit's accumulated damage on marked victims. Death and cancellation have distinct cleanup outcomes. The home ward blocks casting, pulls an entering spirit back, and prevents spirit banking.

The server owns body state, timers, damage marks, returns, and possession; the client predicts its own initial dash for responsiveness. Any system moving/respawning a player must cancel the ability appropriately. Its real player-versus-player behavior still needs human multiplayer acceptance.

### Player and boat motion boundaries

Movement is the single server writer of WalkSpeed and stamina. Ordinary running, carried speed, water scaling, sprint, and spirit bonuses compose through it. The client predicts dash/air-jump and sends intent; the server charges stamina and enforces eligibility/cooldowns. Regeneration pauses after spending, and exhausting the meter creates a winded recovery threshold. Chill suppresses regeneration and drains stamina.

BoatSim is shared physics code. Driven boats normally run on their driver's client, while empty and AI boats run on the server. Buoyancy samples six hull points against deterministic wave math; powered thrust, braking, grip, yaw, drift, bank, recovery, current drag, and controlled bursts determine motion. Server Boats owns seats, anchors, health, crash/scrape damage, sinking, respawn, boost cooldowns, and coarse motion policing. Setting BOAT_CLIENT_PHYSICS false returns driven simulation to the server for comparison.

The documented policing gap matters: a modified driver may exploit speed margins, turn tighter, or avoid crash damage. Do not describe all boat motion as fully trusted just because damage and scoring are server-owned. Real-latency and multi-driver acceptance remain separate from single-client measurements. New movement strategies or authority changes require the human's architecture approval.

Use existing Boats.shove and Boats.place APIs for pushes and relocations; writing a client-driven hull's CFrame or velocity directly from the server can conflict with its owner. Empty unanchored boats drift. Far unoccupied boats sleep. Anchoring, theft, abandonment, sinking, and rediscovery are gameplay choices rather than private player ownership.

### Threats and player-readable counters

Heat moves from CALM to ALERT at 25, HUNTED at 50, and FRENZY at 80. The escalation should change decisions: visible carrier flares, a pursuing/intercepting hunter, a blocker/mines on the return line, and a carrier-following tempest. Navy uses deep-water routes, visibility, committed charges, and search/retreat rather than omniscient permanent homing. A charge announces a horn and holds a bearing; changing course is the intended answer. Shelled target circles close before impact. Islands, shallows, the home ward, a beacon, or the fort chain can change pursuit.

The Guardian has marked leaps and boulders plus a ground shockwave that invites jumping. Individual island inhabitants each teach a rule: watched statues, a delayed path echo, a burrowing crab, straight-line charging ram, water-bound eel, treasure-snatching imps, throwing marines, fire laying ahead of movement, stamina-draining cold, a noise-sensitive sleeper, a dozing shade, a shoving whirlpool fin, and a timed clam. The current roster and parameters later in the guide describe each. Gobbo is a friendly dockhand with kegs and proximity warnings.

Most dangers target possession, routes, or terrain rather than adding identical health bars. Telegraphs must leave an actionable response. Onboarding should teach those counters through encounters and readable cues rather than relying only on the help panel. A reported single-client creature action does not prove behavior when two people face a Watcher or interact with an Echo.

### Sea activity grammar and sound

A teal hoop line offers transit toward a dock. Orange hoops mark separate timed courses. Coins mark skillful lines, jump arcs, or secrets. Boost chains raise speed enough that tight turns may become impossible; routes were changed after real-physics autopilot tests. Those tests establish mechanical feasibility, not how a beginner interprets or enjoys them. Placement must preserve calm home water and optional routes.

World sounds belong to a position with distance falloff and a finite range; interface chimes belong to the player. V6 also bounds simultaneous repeated voices and compresses the world sound group. Thunder, blasts, distant markers, and lightning use tuned hearing/drawing/sending distances. Their values are current source, not universal recommended distances. V6's audio measurements came from logs and calculations; the author could not hear the result. A human still needs to listen.

### Cleanup and integration

One server Heartbeat coordinates modules; builder modules describe geometry and references while mechanism modules run behavior. Raid reset cancels spirits; resets loot, Heat, threats, blasts, trouble, Navy/mines, storms/spouts, escalation, destructibles, mechanisms, cannon/keg state, boats, coins/salvage, and creatures. Joining, leaving, death, and three successive raids need real lifecycle tests. World generation and shared-state attributes must work under streaming, with no duplicate authority or second implementation.

Game-specific designs and facts stay in this repository. Reusable observations go to the shared notebook. This guide embeds current records and full report history, allowing an outside AI to evaluate mechanics without the original chat. Historical commands and versions in those reports are evidence context, not instructions to bypass the current team's rules.

## Game-specific test observations and methods

These notes came from earlier development sessions. Verify present tool capabilities and use the current AGENTS.md rules; historical testing workarounds are not permission to bypass durable-source or Studio safety requirements.

### Rojo and Studio MCP

- Rojo serves on `127.0.0.1:34872` (our other games use other ports; with several Studio windows open, connect each plugin to the right port by hand).
- **The Rojo plugin drops its connection each time play mode starts or stops, and Rojo 7.7.1 can crash when a watched file vanishes mid-write.** Run `rojo serve` in a restart loop, reconnect the plugin after each play session, and confirm `#Script.Source` matches the file before trusting a test.
- **The plugin's Connect button cannot be pressed through MCP.** If the human is away and the plugin is not connected, an Edit-mode `execute_luau` can set `Source` on the mapped scripts itself (the V3 session pulled `src/` from a helper on the loopback address; that needs `HttpService.HttpEnabled` in the disposable built place, switched off again afterwards). Compare sources before trusting a test either way.
- **Studio caps a background window at 15 frames per second, and stops rendering when the display sleeps.** Client-side timings are then one 67 ms frame coarse, injected keys stop arriving and screenshots time out. Measure the client's frame rate before trusting a client-side number, and say so in the report.
- **Use the official Studio MCP only.** Call `list_roblox_studios` first. Studio MCP lists every open Studio to every AI client, so pick the one named `LootGoblinsTest001.rbxlx`. `get_studio_state`, `execute_luau` (Edit/Server/Client), `start_stop_play`, `get_console_output`, `screen_capture`, and `user_keyboard_input` all exist.
- **Never `require()` a game module from `execute_luau`.** It loads a separate copy, and a separate copy of `Net.lua` destroys and recreates `LootGoblinsRemotes`, which cuts the running game off from its own remotes (nothing errors; inputs just stop working). Read attributes and instances instead. For deep tests install a temporary Script in `Workspace` (Studio session only, never committed; Rojo does not manage Workspace) that requires the game's own modules and obeys a `DebugCmd` attribute with fixed, named commands.
- **A raycast on terrain nothing has touched makes the engine build that terrain's collision** (about 90 microseconds each, the first time). Never probe the whole map with raycasts at start-up.
- **Terrain is found about two studs above the height a voxel fill suggests** (a block filled to -28 is at -26 to a raycast). `Landform` compensates; the old fill helpers do not. Measure a depth with a raycast before trusting it.
- **Test a treasure's route on foot, not by teleport.** The Skull Chalice was unreachable from V2 to V6 and every test passed, because every test teleported to it. A ladder needs clear air over the climber on the side they climb, and **a floor to walk onto on the far side of its top** (that is the way off a Roblox ladder: moving away from it climbs down). Cut a terrain shaft at least 8 studs wide: terrain is 4-stud cells, and a 4.5-stud round hole left rock across it. A client-side test can walk a goblin with `Humanoid:Move` bound just after the control script's render step.
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
- **V7 lessons.** (1) **A terrain air fill thinner than one 4-stud cell removes nothing**: Ember's crater was cut with 2.2-stud slabs and was solid from V4 to V6. Use blocks and cylinders at least 4 (better 6) studs thick, then check by reading voxels (`Terrain:ReadVoxels`) or a raycast. (2) A test boat flagged `ai` is removed by the raid's start-of-raid reset: wait for `RaidPhase == "raid"` first. (3) A goblin teleported while `DeployState` is `aboard` becomes a free diver: wait for `landed` before teleporting for route tests. (4) The real key path works from the tools: `user_keyboard_input` (client) with Studio's window in front; mouse coordinates for `user_mouse_input` are offset by the top bar (about 58 px up). (5) A second player cannot be launched from here: PvP was tested server-side with a stand-in table that mimics a player (`Character`, `SetAttribute`, `DisplayName`), parented under a folder the line-of-sight check ignores; `Net.send` was wrapped to skip it. (6) `PathfindingService:CreatePath(...):ComputeAsync` from a beach to the treasure is a quick 'can a goblin get there' check; reaching the goal is necessary, not sufficient. (7) A raycast that hits the voxel at the crater's middle tells you the summit is a lid long before a person does.

### Testing expectations

- Every change: `check.ps1` passes. Gameplay changes also need a Studio playtest with an empty console, then play mode stopped. Report anything you could not test.
- Timed effects are shorter than MCP round trips: record state in a `task.spawn` loop and read it afterwards.
- Single-client MCP play cannot test player-vs-player features. Teleporting 1000+ studs under streaming can let a character fall through terrain that has not loaded yet; that is a test artifact, not a game bug.
- Boat physics run on the test client when it drives. To test them without depending on injected keys, set `boat.input` from a temporary test script (the server then simulates with the same `BoatSim`).
- Studio's network simulator (`settings():GetService("NetworkSettings").IncomingReplicationLag`) is a Studio-wide setting: put it back to 0.
- The real validation is the human multiplayer test: **Test > Server & Clients > 4 players > Play**. The V6 report has a checklist.
- A sleeping creature is not ticked. To test one, put a goblin within its `wake` radius first; `Creatures.active()` says how many are awake.

## Human prototype experiment and decision

Through V6: no shops, XP, pets, rarity tables, monetization, trading, boat trees, hideout decorating, or saved progress. V7 added Shinies, pets, start-with gear and a saved profile on the team's explicit instruction (the V7 prompt); AGENTS.md still carries the older exclusion and needs a human decision. Everything V7 sells is a sidegrade, gear is free in the world, and no essential content is paid. The loot values and `Wins` still score a raid.

For a local multiplayer test: **top-left Test dropdown > Server & Clients > set player count to 3 > blue Play button**. Play several raids with Ethan, Ninety, and Enrik. The checklist in the latest report under `docs/reports/` says what to look for.

Afterward make one decision:

- **KILL** — possession/escape isn't fun.
- **RE-PROTOTYPE** — fun exists but a core variable is weak.
- **GREENLIGHT** — the loop creates yelling, betrayal, improvisation, tension, and "one more raid."

The complete V6 line was approved for integration into main; this does not record a production GREENLIGHT or establish multiplayer fun. Record the human's actual decision and supporting playtest evidence here when it happens.

## Original long-term vision: historical proposal, not implemented scope

The following original design text is preserved in full as attributed design history. Its suggestions and assignments are not current instructions, approval, or a list of built features. Current implemented systems above and actual human decisions take precedence.

```text
TL;DR
We lock Concept 1.
Working title: Loot Goblins.
The game is a colorful social extraction sandbox where you sail between bizarre islands, steal increasingly stupid valuables, trigger escalating chaos, and desperately get the loot home before another player steals it from you.
The emotional loop is the product:
“I shouldn't do this” → steal → OH SHIT → chase gets worse → almost home → someone tries to rob me → barely make it → YESSS HAHAHA → put trophy in collection → go after something harder.
Do not build the progression game yet. First prove that stealing one object and escaping with friends/enemies is hilarious.

LOOT GOBLINS — Game Thesis v0.1
The fantasy
You are a tiny, greedy creature sailing around an enormous colorful archipelago filled with things that absolutely do not belong to you.
Ancient treasure. Giant eggs. Royal crowns. Weird animals. Alien technology. Haunted furniture. Enormous gems. Entire statues.
Your response to nearly everything is:
Can I steal that?
The world has the adventurous discovery of an ocean journey, the playful visual absurdity of a toybox platformer, and the emergent sandbox chaos of a physics-heavy multiplayer game.
But it needs its own identity.
Cute world. Criminal intentions.
That contrast is strong.

The core loop
SAIL → DISCOVER → STEAL → CAUSE TROUBLE → ESCAPE → BANK → FLEX / SELL / TRADE → EVOLVE → STEAL SOMETHING WORSE
The key difference from normal collection games:
Acquiring the item does not end the challenge.
It starts it.
You finally pull the legendary crown off the sleeping king?
Great.
Now the castle alarm activates.
Guards pour out.
Another player sees the crown icon.
Your boat is parked on the other side of the island.
Ninety has stolen your boat.
You're carrying the crown while chasing him.
Enrik grapples onto the back.
Someone accidentally blows up the dock.
That is Loot Goblins.

The rule that makes the whole game work
Every valuable object has two attributes:
Value determines why you want it.
Trouble determines what happens once you take it.
A cheap coconut might cause almost nothing.
A massive golden egg might summon its mother.
A cursed sword might possess whoever carries it.
Alien technology might attract a UFO.
A royal crown might put a giant bounty marker above your head.
A sleeping monster's tooth might require you to physically yank it out without waking him.
So rarity isn't merely:
0.01% drop rate.
Rarity can mean:
This thing is fucking difficult to get home.
Much better.

The HEAT system
Stealing important things increases Heat.
At low Heat, maybe a few NPCs chase you.
Then things escalate.
More guards. More aggressive creatures. Doors locking. Cannons firing. Your position becoming visible. Bounty rewards for other players interfering. Island-wide hazards activating.
And crucially:
Heat follows the stolen item.
Not necessarily the player.
If Ethan drops the crown and Ninety grabs it:
Congratulations Ninety.
You're the problem now.
That creates incredible physical comedy.

Player theft without making people uninstall
We need theft.
But permanent destruction of hours of progress will turn the funny game into a rage-quit machine.
So:
Banked loot is safe.
Once something reaches your hideout and gets deposited, ownership is secure.
What can be stolen is unbanked loot currently being transported.
That gives us all the:
GIVE ME THAT
GET THE FUCK AWAY FROM ME
HE TOOK IT
CATCH HIM
without someone waking up tomorrow and discovering their three-week collection is gone.
This is a very important floor-versus-ceiling decision.
The ceiling of total theft is hilarious.
The human floor is children quitting because someone erased their favorite pet.
Keep the chaos. Remove the misery.

Getting home should physically matter
Don't make extraction:
Stand inside green circle for 3 seconds.
Your hideout is a physical location.
You need to actually transport the object there.
Small objects can be carried.
Medium objects might require dragging.
Huge objects could require boats, carts, balloons, cranes, friends, tow cables, or completely stupid improvised solutions.
That means the treasure itself changes gameplay.
Stealing a crown and stealing a grand piano shouldn't feel identical.
Imagine four players trying to shove a giant golden statue onto a tiny sailboat while guards attack them.
Now the treasure is also a physics toy.

Your sandbox toys
This is where the Halo 3 influence becomes valuable.
Don't design hundreds of canned jokes.
Design objects that create jokes.
Your grappling hook pulls players, treasure and vehicles.
Your spring trap launches anything standing on it.
Your sticky rocket can attach to objects.
Your magnet can yank metallic treasure toward you.
Your decoy creates fake valuables.
Your smoke bomb creates confusion.
Your tow hook connects objects together.
Now combinations emerge.
Rocket + boat.
Grapple + crown.
Spring trap + giant chicken.
Tow cable + enemy vehicle.
Players produce the clips for us.

Boats are your first major evolution fantasy
I think this should be one of the game's signature progression systems.
You begin with something pathetic.
Tiny raft.
Eventually players are cruising around in ridiculous ships that visibly communicate status.
Not just:
+17% movement speed.
Your ship physically changes.
More storage.
More tow capacity.
Different traversal options.
More gadget slots.
Maybe eventually gliding, diving, ghost sailing, alien propulsion.
Someone should enter the server and you immediately think:
What the fuck is THAT boat?
That's status.

Your hideout is the trophy case
Every player gets a small island hideout.
This becomes the physical record of their career.
Not a menu saying:
73/200 collectibles.
I want to walk through your shit.
Your enormous stolen dragon skull is mounted above the entrance.
Your legendary UFO is parked outside.
Your rare creatures wander around.
Your Crown of Whatever is inside a glass case.
Your boat sits at the dock.
Visitors should understand your accomplishments without opening a stats page.
That's status + collection working together.

Sell versus Keep becomes an actual decision
You return with something extremely rare.
Now:
SELL IT
Get lots of currency toward upgrades.
Or:
KEEP IT
Add it permanently to your collection and flex it.
Or:
TRADE IT
Maybe someone wants it badly enough to give you something better.
That makes objects feel like objects rather than XP packets.

The world
The archipelago structure is perfect for Roblox because it gives us expandable content without rebuilding the game.
Your starting sea might have:
Goblin Cove as the safe home region.
Royal Isle where players steal valuables from a pompous kingdom.
Critter Island full of strange creatures and dangerous eggs.
Ghost Graveyard with cursed treasure and abandoned ships.
Skyfall Atoll containing mysterious high-tech ruins, vehicles and physics toys.
Later we can get much stranger.
Every island asks a slightly different question:
How the hell do I steal THIS?
That prevents the loop from becoming mechanically flat.

The viral engine
This game should naturally manufacture sentences kids want to tell their friends:
BRO I STOLE THE KING'S CROWN.
COME HELP ME MOVE THIS THING.
HE FUCKING TOOK IT FROM ME.
GET IN THE BOAT.
DON'T TOUCH THAT.
WHY IS THAT CHICKEN SO BIG?
I'M ALMOST HOME.
NO NO NO NO—
YESSSSS.
That's stronger than designing around “TikTok moments” artificially.
The mechanic itself creates stories.

The first prototype
And now we show discipline.
Your team's own operating system says the prototype's job is to answer the riskiest fun question cheaply, not build Game Version 0.1. How we build games v1 - Mickey …
So Ninety should NOT build Loot Goblins.
He should build:
LOOT GOBLINS TEST 001
Three players.
One tiny island.
One tiny home island.
One shitty boat.
One valuable golden idol.
Basic physics carrying.
Players can grab/drop the idol.
Players can knock/grapple it away from each other.
Stealing it wakes one giant NPC creature.
Creature chases whoever possesses the idol.
Get the idol physically onto your boat.
Sail home.
Cross your dock carrying it.
BANKED.
Round resets.
That's fucking it.
No XP.
No shop.
No pets.
No rarity system.
No trading.
No elaborate UI.
No huge map.
No monetization.
No thirty gadgets.
We are answering one question:
When three idiots fight over something valuable while being chased and try to get it home, do we start screaming and laughing?
If the answer is yes, you've found the nucleus.
Then Enrik turns that experiment into something structurally real, exactly as your workflow calls for after greenlight. How we build games v1 - Mickey …
If the answer is no, we change the mechanic instead of spending three months explaining why it will eventually become fun.
The greenlight test
I want all three of you to play ten rounds.
By the end, you should naturally be doing things we didn't explicitly tell you to do.
Betraying each other.
Blocking boats.
Pretending to cooperate.
Intercepting treasure.
Laughing when somebody gets fucked over.
Taking risky shortcuts.
Trying stupid physics tricks.
Wanting one more round.
If that's happening, we've got something.
Next Actions
Ethan: lock this one-sentence thesis: “Steal ridiculous treasure from dangerous islands and other players, then somehow get it home.”
Ninety: build Loot Goblins Test 001 exactly around steal → chase → player interference → extraction. Nothing else.
Enrik: stay out of production architecture until the prototype proves the emotional loop. Explore first. Then we earn complexity.
```

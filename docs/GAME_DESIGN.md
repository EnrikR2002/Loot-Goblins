# Loot Goblins: game design and current systems

This is the single editable source for this game's vision, current mechanics, controls, architecture, design decisions, bugs, and limitations. Read AGENTS.md for team rules. Current code and dated evidence determine what is implemented; ideas and historical proposals do not authorize new features.

The AI updates affected sections here, records task evidence under docs/reports/, and runs the existing guide export. Generated root GAME_GUIDE.md packages this document, exact tuning, the shared quality rubric and lessons, and full dated reports into one attachment for another AI. Do not edit that generated file. The manifest and freshness files under docs/game-guide/ are export metadata, not additional game descriptions.

## Loot Goblins V11: identity, journey, and current scope

Loot Goblins is a social possession-and-escape game: steal ridiculous treasure from dangerous islands and other players, then somehow get it home. The desired rhythm is explore with awe, take something valuable, feel the world react, improvise an escape, bank the reward, and choose another risk. Fast movement and boat handling should be enjoyable before a reward appears. Danger challenges that power rather than restoring difficulty by making ordinary travel sluggish.

This guide describes the **V11 (Goblin Life)** code on branch feature/v11-goblin-life: V10 (The Living Archipelago, merged into main on 2026-10-17 with V9) plus a customization, pets, progression and monetization pass. **V11 adds what a goblin keeps and wears and changes nothing about how a raid plays**: see **V11: Goblin Life** below, docs/reports/2026-10-17-v11-goblin-life.md and docs/MONETIZATION.md. V10 changed only how the world looks (see **V10: the look** and docs/ART_DIRECTION.md); V9 is described in **V9 systems**; where a V8 or V7 paragraph here disagrees with a later section, the later section is what the code does. V7 to V11 have each been tested by one AI on one Studio client; **none of V9, V10 or V11 has been played by a person or with a second player** (V8 had one human multiplayer playtest, which V9 answers). The reports say exactly what was and was not exercised. The portable guide retains historical reports as history, while these current chapters describe the latest code.

### The first raid from a player's perspective

The world generates when Play starts, taking several seconds on the reported development machine; players are loaded after world construction. **A raid begins aboard the skyship** (V7): a flying pirate ship hung 540 studs over the middle of the sea. Goblins climb into a cannon and aim it by looking at where they want to land (V8), are thrown on a plain arc and tumble with loose limbs, and come down on land (head first like an ostrich if they fall fast, on their feet if they brake with a glide) or on the sea (which skips a fast goblin up to three times, each bounce smaller). They can also walk out along the ship's wings and step off. Goblin Cove is home. The Hoard is the visible gold ring/beam where treasure and coin proceeds are banked; it is never on the ship. Home also has boats, keg access, a practice cannon, movement toys, and a harbor jump. The intended introductory line is the harbor jump, the teal Gate Run, and the passage through the reef to the Crossroads. Home Bay deliberately leaves calm water and visual breathing room.

The near islands offer inexpensive short trips. Middle destinations add longer journeys and characteristic trouble. Far islands have harder return routes. Values are flat (4 to 11 gold) except the **Golden Idol (17)**, the prize of the sea. A treasure's light pillar, the map (M), the compass and the minimap help choose a destination; since V9 no names or values float on the horizon (they show only up close). Since V9 whatever guards a treasure **follows the thief across the sea almost to Goblin Cove**, ending at the sanctuary's gold lantern buoys. The physical geography gives currents, reef passes, ramps, cover, high ground, and alternate routes that influence pursuit. A thief normally carries one treasure at a time. The personal decision is which treasure is worth exposing oneself for, and how to return without being robbed or stopped by the world.

A raid is **six minutes** of play (`Config.RAID_DURATION` 360, V9) with a 10 s intermission spent on the skyship (the first is six seconds). The raid opens with a 20 s launch window and **the six-minute clock starts when the window closes**, so a goblin who fires late still gets the whole six minutes; the cannons fire from 2 s in (a goblin can climb in and aim during the intermission) and anyone still aboard at 20 s is fired off. In the last 50 s banking pays 25% more (the final rush). Banking adds Gold for that raid. At its end, every player tied for the highest positive Gold receives a Win; a zero-score raid has no winner. Gold resets next raid, and the world resets its systems. Wins are session values, not saved progression. Loose or carried treasure not banked in time does not become score. Death drops carried treasure and respawns the player at home after three seconds, allowing others to recover the object.

Taking treasure triggers its own trouble and adds shared Heat. Continuing to carry outside the home ward raises Heat; when nobody carries, Heat cools. Other players and world threats create exposure. The intended social result is improvised chases, theft, escape, group reactions, and another raid. Existing solo mechanical observations and some human feedback do not establish full multiplayer fun or fairness.

### Player verbs and tradeoffs

Run, sprint, dash, air-jump, grapple, board, steer, brake, drift, boost, anchor, steal, throw, swing, light a beacon, raise a chain, launch a keg, fire a cannon, hide, and bank. Not every verb needs a new system. The shared E key favors an actual visible prompt over spirit casting; C means dash on foot and drift while driving.

Running at 28 is free. Stamina pays for sprinting and exceptional moves; carrying treasure increases their costs and slightly slows the carrier. A carrier can defend themselves with a weaker, slower, shorter, tiring sword swing, and can grapple to surfaces/boats but cannot use the grapple to steal another treasure. Boats trade speed, durability, draft, handling, capacity, and cannon access. Geography can separate a shallow-water player route from a deep-draft Navy route. A beacon diverts nearby Navy, and the fort chain prevents new departures from its harbor for a period.

The score remains treasure. Coins encourage taking a skillful or interesting route, repair a little hull, and refund some boost cooldown; ten convert to one Gold when banked, with at most six Gold from coins in a raid. Timed courses provide a different movement challenge and a local best-time sign. Their presence should not turn every quiet crossing into a course.

### What has evolved through feedback

V2's world was worth exploring but travel and danger felt weak. V3 made movement and boats more powerful and changed threats to intercept, commit, and leave actionable tells. V4 enlarged and differentiated the world; a subsequent human playtest found the sea too spread out. V5 brought it closer and added inhabitants and sea activities; its feedback praised the map, boats, and creatures but found hoops/coins crowded and oddly placed. V6 rearranged the same offers, measured routes, and repaired global thunder. These are attributed historical findings, not controlled causal experiments or a guarantee of broad player preference.

V6's report was later amended after Ninety discovered the blocked Skull Chalice approach. The source now contains the ladder/hatch repair. Its earlier 'nobody has played V6' wording describes an earlier checkpoint; it must not erase that later feedback. Broader V6 layout, sound-by-ear, multiplayer, mobile, and balance acceptance remain outstanding.

### Current guardrails and absent features

V7 added a small progression layer (Shinies, five pets, start-with-gear kits, a saved profile, an inert Robux receipt foundation). **V11 turned it into Goblin Life**: a 121-item catalogue of goblin cosmetics, boat paint, flags, figureheads, trails, wakes, trick effects, callout styles, emotes and victory dances; five redesigned pets with looks and hats; outfit presets; 11 achievements; a shop and locker with 3D previews; a session-locked, migrating saved profile; and Robux plumbing that stays switched off until a human creates products. Expression over power: nothing sold or earned makes a goblin stronger except the five pets (small sidegrades, all sold for Shinies) and the start kits (gear that is free in the world). There is no XP, trading, crafting, random reward or boat upgrade tree. Since 2026-10-14 the scope is open: the team can add any of these whenever they want (see AGENTS.md). The original long-term design vision appears later as inspiration. Rough geometry, primitive creature models, built-in sounds, and incomplete advertised input coverage are prototype compromises; they are not proof of release readiness.

An outside AI should deepen possession and escape, preserve movement agency, compare ideas against existing verbs, and distinguish current V8 from historical configurations. A mechanic rejected for another game is not automatically rejected here. What gets built next is the team's call; a teammate's request is enough.

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
| Merged 2026-10-14: PR #17 | **V7**: a flying-ship start (cannons, pencil dive and glide, splash bounce, head-first landing), a sea 20% wider with 16 major islands and computed difficulty tiers, faster boats with a hop, slow land driving and call-a-boat (B), a grapple that catches and an E that steals, regional alerts, gear-gated treasure, a visible Leviathan, white Navy ships, Shinies/pets/saved profile, twelve-minute raids, a final rush, route fixes (windmill, fort, Ember crater, Tide Vault). Report: `docs/reports/2026-10-13-v7-skyfall-competitive-archipelago.md`. **One AI, one client, no human or second-player test.** |
| Merged 2026-10-17: PR #20 | **V9, Relentless Chaos**, answering the V8 human playtest's fifteen points: six-minute rounds after a 20 s launch window; pursuits that follow a thief almost home and end at a sanctuary round Goblin Cove (`Pursuit.lua` rewritten: pacing with momentum, lock-on tells, resurfacing, flying pursuers); a Leviathan with no special attack that shadows boats and catches what slows; the Sun Temple Guardian in a stone speedboat with a launch, the Golden Idol worth 17; a tiny fast Echo; a crewed Ghost Fleet with pirate dinghies (`GhostFleet.lua`); one-button boat tricks; seven ramps; independent rideable tornadoes (`Twister.lua`, `Tornadoes.lua`); swept hoop detection; no horizon text; a minimap; bigger guardians. Report: `docs/reports/2026-10-14-v9-relentless-chaos.md`. Studio-tested by one AI on one client; **no human playtest and no second player yet**. |
| Merged 2026-10-17: PR #21 | **V10, The Living Archipelago**: a visual identity pass with no gameplay change. An art direction (`docs/ART_DIRECTION.md`, `shared/Palette.lua`); new light, water, sea floor, terrain colours, sky and grade; a signature landmark for each of the 16 major islands (`Art.lua`); redesigned Guardian (`GuardianLook.lua`, also its boat rider), Leviathan, Echo, Ghost Fleet and every island creature; goblin players (`GoblinLook.lua`); treasure (the Golden Idol as a crowned goblin king); boat liveries; the skyship dressed as the Golden Goblin; opaque storm clouds, a new tornado funnel, an aurora, whirlpool foam. Collision was fingerprinted against V9 and is unchanged. Report: `docs/reports/2026-10-17-v10-living-archipelago.md`. Studio-checked by one AI on one client; **no human playtest and no second player yet**. |
| Branch feature/v11-goblin-life (PR to main) | **V11, Goblin Life**: customization, pets, progression and monetization on one ownership system. A 121-item catalogue (`shared/Catalog.lua`) and 11 achievements; saved profile v2 with V7 migration and session-locked `UpdateAsync` saves (`ProfileSchema`, `ProfileStore`, `Progress`); pure ownership rules (`Economy`); goblin cosmetics built by shared code for live goblins and previews (`Wardrobe`); boats wearing their driver's paint, flag, figurehead, trail, wake, trick effect and callout (`BoatLook`, `BoatStyle`, client `Looks`); emotes and victory dances (`EmoteMoves`, `Emotes`); five redesigned pets that walk, ride, cling and react (`PetLook`, client `Pets`); the Goblin Wardrobe shop and locker (client `Shop`), emote wheel and raid results; idempotent Robux receipts and game-pass checks, switched off (`Monetization`, `Receipts`); 46 Luau tests (`tests/luau`). Report: `docs/reports/2026-10-17-v11-goblin-life.md`. Studio-tested by one AI on one client with an in-memory store; **no human playtest, no second player, no live DataStore and no real purchase yet**. |
| Merged 2026-10-14: PR #18 | **V8, Chaos & Counterplay**: one flight system for the skyship's cannons and the island catapults (aim by looking, a ballistic throw, glide as a brake, dive, three diminishing water skips, loose limbs while tumbling), walkable wings, a stronger boat hop and a speed-based super jump, a sea form for every island's creature (`Pursuit.lua`), three kinds of ordinary sea mob (`SeaMobs.lua`), a Leviathan 2.2 times the size that hunts boats, one rule for being hit by the world (`Impact.lua`: grace, smaller bites, a two-strike grip on treasure, hulls battered but never sunk by creatures), no gear requirement on any treasure, a front door to the Tide Vault, treasure values flattened. Report: `docs/reports/2026-10-13-v8-chaos-and-counterplay.md`. Studio-tested by one AI on one client; **no human playtest and no second player yet**. |

The V6 report was subsequently amended after Ninety found the blocked Skull Chalice route; revision `8f399c7` repairs its ladder/hatch and records a single-client on-foot test. The table's earlier "no human playtest" wording describes an earlier checkpoint. This later route feedback is real, while the broad V6 layout, sound-by-ear, multiplayer, mobile, and balance acceptance remain outstanding.

Enrik explicitly authorized merging the complete latest V6 development line into main on October 12, 2026. PR #14 targets main and includes the ancestor work from PRs #9–13 plus the shared-memory rollout in PR #15. GitHub records the actual integration outcome. This approval does not certify outstanding human, multiplayer, audio-by-ear, or device tests. Historical reports below retain their original checkpoint status.

Everything below describes the V11 code: V9's systems (with the V8, V7 and V6 sections they build on) under V10's look, with V11's customization and progression on top, and their current limitations.

## Purpose

Loot Goblins is a Roblox game by Ethan, Ninety and Enrik. The one-sentence thesis is: *steal ridiculous treasure from dangerous islands and other players, then somehow get it home.*

The loop: **explore (awe) → steal treasure → the world reacts → escape (panic) → bank → repeat.** Going out should feel like adventure; coming home with something valuable should feel like needing to GET OUT. V3's aim on top of that: **the player should feel powerful, the world should feel dangerous, and the fun is where those two meet.** Moving and sailing should be enjoyable in themselves, not the price of reaching the fun. V4's aim: **the world should be big and varied enough to deserve that movement**, with geography that is itself something to learn and use. V5's aim: **every island should have something living on it that a player can learn**, and the sea between them should be a playground, not a commute. V6's aim: **placement over quantity.** What the sea offers should be few enough, and laid out plainly enough, that a goblin can see it and choose. V7's aim: **a server of up to 32 should start with a spectacle and have somewhere different to go**: a ship to fall from, sixteen islands that each ask something different, an island robbed makes its neighbours wary, and what a goblin keeps between raids is a sidegrade, not power.

The design principle is **active novelty**: surprises the player participates in (a geyser to time, a ring to jump, a charge to dodge, a storm to steer around), not things that just happen on screen.

The long-term vision later in this document is inspiration, not a plan; the team decides what to build from it.

## Core loop

1. Players start each raid on the **skyship** (V7), dive to an island of their choice, and bring treasure to **the Hoard** at **Goblin Cove**. A raid is a 20 s launch window and then `Config.RAID_DURATION` (360 s) of clock, then a 10 s intermission on the ship (V9).
2. Nineteen treasures wait on 19 islands (16 major, three keys with small stashes), each with a light pillar; its name and value show within 170 studs (V9; through V8 across the whole map). **Values are flat since V8** (4 to 11 g) with one exception since V9: **the Golden Idol, 17 g**.
3. Prying treasure off its spot (hold E, 0.6 s) adds Heat and triggers that treasure's own **trouble** (a flooding vault, a volcano, the Leviathan, the Ghost Fleet, snapping bridges...). Most big islands also have an **inhabitant** with one rule to learn (see Island inhabitants), and since V9 every one of them **follows the thief to sea almost all the way home** (see V9 systems).
4. The carrier is hunted by the world (see Heat), can be robbed by other players, pays more stamina for every move and slows the boat they sit in. On foot they are only a little slower than anyone else.
5. Carrying treasure into the Hoard ring banks its gold. Banked treasure respawns later; treasure nobody takes grows more valuable (**interest**: `LOOT_INTEREST_SHARE` of its value, at least 1 g, per 45 s since V9, three steps at most).
6. **Coins** on the water are a side dish: ten make 1 gold at the Hoard, at most `COIN_GOLD_CAP` (6) gold a raid. Treasure is the score.
7. When the timer ends, the most gold wins (`Wins` +1). Everything resets.

## Controls

| Input | Action | Where |
| --- | --- | --- |
| Hold `E` on treasure | Steal from spot / grab loose treasure (ProximityPrompt) | `Loot` |
| `E` on a boat | Board it (driver seat first, then passengers) | `Boats` |
| `W A S D` in the driver seat | Drive. `S` against your motion is a brake | `BoatSim`, client `BoatDrive` |
| `Shift` in the driver seat | **Boost** (2.4 s, 5 s cooldown, a kick at the start). Gamepad `X` | `Boats`, client `BoatDrive` |
| `Space` in the driver seat | **Hop** the boat (about 18 studs up, 1.1 s cooldown). Faster than `BOAT_SUPER_MIN` (150: a boost, a hoop chain, a drift burst) it is a **super jump**, up to about 38 studs at 187 studs/s and 57 at 215; a clean landing from one pays the landing burst. It does not leave the seat. **Inside a tornado it bails out** (V9): the boat is thrown the way it points | `BoatSim`, client `BoatDrive` |
| `R` (gamepad `R1`) in the driver seat, in the air | **A trick** (V9). First press a spin, then each press the next in a combo (corkscrew, front flip, double spin); hold `A`/`D` for a roll, `S` for a backflip. A press during a trick plays when it ends. Landing clean after tricks pays a speed burst and some boost cooldown | `BoatSim.TRICKS`, client `BoatDrive`, `Tricks` |
| `X` (gamepad `Y`) in a seat | Leave the boat | client `Main` |
| `B` (D-pad down) | **Call a boat** to the nearest shore (45 s cooldown) | `Recall` |
| `E` at a cannon on the skyship, or at an island catapult | Climb in. **Look** (mouse, or `W A S D`) at where you want to land; the ring is where you come down. Click or `Space` fires, `X` climbs out. `M` then an island points a ship's cannon at it | `Flight`, client `Skyship` |
| In the air after a launch | `W A S D` nudge the arc. Hold `Space`: **glide** (an air brake: slower fall, speed bled off, a soft landing). Hold `Shift`: **dive** (head first, down hard). Nothing held: you tumble | client `Skyship`, `Dive`, `Flight` |
| `P` (gamepad D-pad right; the 🧥 button on the left of the screen; `E` at the tailor's stall on the skyship) | **The Goblin Wardrobe** (V11): SHOP and LOCKER, Shinies, cosmetics, boat paint, style, emotes, pets, start kits, outfits, trophies. Buying takes two presses | client `Shop` |
| `V` (gamepad D-pad up; the 😀 button) | **The emote wheel** (V11). Pick with a click, a tap, a number key or the left stick and A. Moving stops an emote | client `Emotes`, server `Emotes` |
| `T` | Show every treasure on the board (default: loose or carried only) | client `Hud` |
| Hold `C` in a turn, driver seat | **Drift**: slide round the turn, let go for a speed burst. Gamepad `B` | `BoatSim` |
| `R` near a boat's winch | Drop or raise the anchor (not for the driver while driving since V9: `R` is the trick key) | `Boats` |
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
| `M` | World map: islands, difficulty, who is on guard, your landing choice, the sanctuary, tornadoes | client `Map` |
| (always shown) | **Minimap** (V9), top right: turns with the camera; islands, the island you are at, the Hoard and sanctuary, tornadoes, whatever is chasing you | client `Minimap` |
| `H` | Help panel | client `Hud` |

Abilities are keyboard and mouse, with the gamepad buttons above. Prompts and the sword also work on touch; nothing else has touch buttons yet (the V9 trick included). V11's wardrobe, emote wheel and results are built for mouse, touch and gamepad (large buttons, two always-visible screen buttons, gamepad selection rings, a compact layout on short screens), but none of it has been tried on a phone or with a real controller.

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
- About 8,800 server parts since V10 (V9: about 6,000; the skyship is about 400 with its V10 dressing, the 16 landmarks about 630) and 43 boats, 101 gates (95 hoops, 6 ramps), 132 coins. **The world takes 3 to 4 s to build and the sea grid another 3 s** (V3: 3 s in all); `Main` prints both with a breakdown at start-up. Watch that line when you add terrain.
- **Depths that matter:** a skiff needs 3.1 studs of water, a cutter 3.9, a patrol ship 5.6 (`SeaNav`: draft + 1.8). Reef crest 1.2, reef passes 3.7, the Western Shelf 4.8. **Green lamps mark water a patrol ship cannot enter; gold lamps mark the Gate.** Keep that language if you add shallows.
- **Folders** under `workspace.LootGoblinsGenerated`: `Ground` (walkable; the Guardian walks on it), `Structures` (boats live here), `Decor`, `Loot`, `Threats`, `Effects` (also mines and waterspouts), `Coins` (coins and salvage crates), `SpiritBodies`, `LaunchPads` (also geyser vents), `Ziplines`, `Landmarks` (persistent: island signs, `HoardMarker`, the horizon silhouettes, the skyship and, since V10, each island's `Landmark<Id>` model and Frost Spire's `Aurora`).
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

## V11: Goblin Life

V11 (Goblin Life) is a customization, pets, progression and monetization pass built on V7's Shinies, pets and profile. Its aim: **play a raid → bank treasure → earn Shinies → unlock something → wear it → show it off next raid**, with expression over power. Nothing in a raid plays differently: no speed, damage, value, timer or physics changed. The only gameplay-adjacent changes are the Shell Tortoise resting 45 s instead of 30 (with a visible glow while ready), pets changing only on the skyship, at the Hoard or between raids, and V7's pet prices. Full evidence: `docs/reports/2026-10-17-v11-goblin-life.md`. Robux setup: `docs/MONETIZATION.md`.

### What a goblin keeps (`shared/Catalog.lua`, `server/Economy.lua`)

- **One currency, Shinies.** Raid payout unchanged from V9 (`Config.PROGRESS`: 6 for taking part, 1 per gold banked up to 22, +15 to the winner, +3 for banking something and finishing in the bottom half, at most 42). New: 60 welcome Shinies once per goblin (`WELCOME`), and achievements paying 25 to 150 once each.
- **The catalogue**: 121 items in 21 slots (`Catalog.SLOTS`, grouped Goblin / Boat / Style / Pets & Kits): 13 free, 94 for Shinies, 10 trophies (achievement-only), 4 premium-only cosmetics (Robux, not on sale). Rarity (common, uncommon, rare, legendary, trophy, premium) labels cost and difficulty; there are no random rewards anywhere. Each slot holds one item, except emotes (every owned emote is in the wheel). Slots with a `default` (skin, ears, nose, paint, flag, callout, victory dance) always show something; the defaults are V10's look.
- **11 achievements** (`Catalog.ACHIEVEMENTS`), each one deed read from lasting stats: First Haul, Raid Champion, Sticky Fingers (snatch from a downed goblin), Trick Master (four tricks in one jump, as checked by the server through `Boats.TrickLanded`), Idol Thief, Serpent Slipper (Leviathan's Tooth), Skull Rock Survivor (Skull Chalice), Island Hopper (8 islands), Old Salt (25 raids), Hoarder (150 gold), Hoard Legend (750 gold). Most unlock a trophy item.
- **The look** is one string attribute on the player (`Look`, e.g. `hat=hat_tricorn;pet=Crab;...`, `Catalog.encodeLook`/`decodeLook`). The server writes it from what is owned (`Economy.look`); every client reads it for pets, boat effects and callouts. `decodeLook` drops anything unknown or in the wrong slot.

### Saving (`server/ProfileSchema.lua`, `server/ProfileStore.lua`, `server/Progress.lua`)

- Profile **version 2**, one key per player in V7's DataStore (`LootGoblinsProfile_v1`, key `u<UserId>`): shinies, owned, equipped, petSkins, presets (3), stats, achievements, receipts (last 500), history (last 40), welcomed, lock. **V7's version 1 is migrated in place** on first open (every Shiny, pet, kit, choice, total and receipt kept). Damaged fields are repaired; unknown ids and fields are kept; a profile from a newer version (v > 2) is never written.
- **Session lock**: every open and save is one `UpdateAsync` that checks `lock.session`. A fresh lock held by another session (refreshed within `LOCK_STALE` = 180 s) is never taken; a stale one is. A save whose lock is no longer this session's is refused ("lost") and that server stops saving the profile. Leaving releases the lock.
- **Sessions** (player attribute `SaveState`): `loading` (playing on a blank stand-in while it opens: 5 tries 4 s apart), `saved` / `saving`, `standin` (could not open yet: retried every 20 s; Shinies and stats earned meanwhile are merged when it opens; buying waits), `newer`, `lost`, `studio` (Studio with no DataStore access: an in-memory store, reset when Play stops), `off`.
- Saves: within 6 s of a change (at once after a purchase, receipt or achievement), every `AUTOSAVE` (60) s anyway, on leaving (with release) and on shutdown. Each call retries 4 times with growing waits and waits for request budget.
- `Progress.handle` (the `ShopRequest` remote) is the only way a client changes anything: `buy`, `equip`, `unequip`, `presetsave`, `presetload`, `opened`; `robux` goes to Monetization. At most `ACTIONS_PER_SECOND` (8) a second. Answers come back as a `ShopResult` event.

### Goblins (`shared/Wardrobe.lua`, `server/GoblinLook.lua`)

`Wardrobe.dress(character, look)` paints skin (BodyColors and every body part), then builds ears, nose, hat, eyewear, face, outfit and back piece as parts welded to body parts: **massless, non-colliding, not hit by rays, not touched**. Head items are authored for a 1.2-stud head and scaled per axis; body items are sized from the real parts. A worn Roblox avatar item that would clash is hidden while the game item is worn (hats and hair under a hat, face accessories under eyewear or face, shirts/jackets under an outfit and trousers when it has legs, back items under a back piece) and comes back afterwards. It is idempotent: it rebuilds only when the look or the head/torso changed. It runs on spawn, on appearance loaded, 2 s after spawn and on every `Look` change. Cloth is SmoothPlastic (Fabric reads as knitted wool at this scale). The heaviest goblin is 80 parts. The same function dresses the shop's preview, so the preview is the game's look.

### Boats (`shared/BoatLook.lua`, `server/BoatStyle.lua`, `client/Looks.lua`, `shared/StyleFx.lua`)

A player boat wears its **driver's** look: `Boats.tick` calls `Boats.style(boat, driver)` when a different goblin takes the driver's seat; `Recall` styles a called boat for its caller; `respawn` returns it to class colours. Passengers change nothing; AI boats (Navy, Guardian) are never styled. Paint recolours V10's named parts by role and remembers each part's own colour (so Class Colours restores V10); flags and figureheads are welded decoration in a `BoatCosmetics` folder. Boat attributes: `StyleOwner`, `StyleSig`, `Trail`, `Wake`, `TrickFx`, `Callout`. Each client draws trails (a Trail ribbon while `BoostEndsAt` is ahead), wakes and trick effects for boats within `StyleFx.DRAW_RANGE` (420); bursts are capped at 40 and halved on low graphics. Trick mechanics are V9's, unchanged; `Tricks.lua` dresses callouts in each goblin's callout style.

### Emotes and victory dances (`shared/EmoteMoves.lua`, `server/Emotes.lua`, `client/Emotes.lua`, `client/Looks.lua`)

Procedural poses written to each joint's `Transform` every frame (no animation assets). The player attribute `Emote = "id@serverTime"` is the whole state: the server allows an owned emote on a live goblin standing on something (not seated, flying, downed or a spirit), at most one start a second, and clears it at its end or when the goblin moves 2.5 studs, sits or flies; the goblin's own client stops posing the moment they move or jump. An emote never moves the character. The raid's winners play their `victory` dance on the deck 1.2 s after `RaidEnd` (`Emotes.celebrate`, `Celebrate` event with coins or a crown); the client holds its auto-opening map back 5.5 s (`Skyship.holdMap`). The wheel (`V`, D-pad up, the dock's button) takes number keys, A, B and the left stick from the game while open.

### Pets (`shared/PetLook.lua`, `client/Pets.lua`)

Five rigs of 11 to 27 anchored parts (each with a rest CFrame, a group and group pivots), 5 alternative looks (`petskin`, worn by its own pet only, kept per pet in `profile.petSkins`) and 4 hats. Drawn on every client from the `Pet` and `Look` attributes; abilities stay on the server (`Gear.pet`). Movement: walkers walk/hop/plod beside the goblin with a spring led by the goblin's velocity; in a boat they ride the deck by the driver's seat; in the air, the water, a dive or above 60 studs/s they cling (crab on the back, frog on the head, tortoise as a backpack); fliers hold a spot in the goblin's own frame and sway back on acceleration; a 0.35 s hop between modes; a puff and a jump when more than 40 studs off. Reactions: cheer (steal, snatch, bank), tumble (Guardian launch), dance (win), trembling while a model's `Chasing` attribute is the owner. Idle quirks when the owner stands still. One `BulkMoveTo` a frame; LOD: every frame within `PET_FULL_RATE_RANGE` (50), every 2nd frame to 140, every 4th beyond, none beyond `PET_DRAW_RANGE` (360); the nearest 12 only on low graphics. The Shell Tortoise's shell glows (for everyone) while `ShellReadyAt` has passed.

### The Goblin Wardrobe and results (`client/Shop.lua`, `client/Ui.lua`, `client/Results.lua`)

One window, SHOP and LOCKER tabs, opened by `P`, D-pad right, the dock's 🧥 button or the tailor stall on the skyship's quarterdeck (a prompt with the `OpensWardrobe` attribute, built in `server/Skyship.lua`). Left: four group tabs and their sections (the locker adds Outfits and Trophies). Middle: a 3D stage previewing the goblin (a copy of the player's own character posed by forward kinematics and dressed by `Wardrobe.dress`), a boat (a still copy of a real skiff from `ReplicatedStorage.LootGoblinsPreview`, made by `Boats.build`) or a pet; trails, wakes, trick effects and callouts preview flat because a ViewportFrame cannot draw particles. Right: cards with 3D thumbnails and state. Buying is two presses within 5 s. Closes with `P`, X, gamepad B, clicking outside, or by itself on climbing into a cannon, flying or picking up treasure. A compact layout is used on screens under 560 points tall. Raid results (right side) show the winner, the gold table, your Shinies breakdown (`RaidReward` event, sent just before `RaidEnd`), trophies earned and an optional Open Wardrobe button; a first visit gets a short welcome card (`Welcome` event).

### Robux (`server/Monetization.lua`, `server/Receipts.lua`, `docs/MONETIZATION.md`)

`Config.MONETIZATION.PRODUCTS`: the five pets (a second way to the same pet) and four premium-only cosmetics, each `{ kind = "pass" | "product", id = nil, grants }`. **No id exists and `SALES_ENABLED` is false**: no purchase window can open; premium items are hidden live and shown in Studio as not on sale. Game passes are checked with `UserOwnsGamePassAsync` when a profile opens and granted from `PromptGamePassPurchaseFinished`. Developer Products go through `ProcessReceipt` → `Receipts.process`: unknown products and absent or not-open goblins are retried; the purchase id is recorded in the profile with the grant and confirmed only after a save; repeats grant nothing; a second payment for an owned item becomes `DUPLICATE_SHINIES` (150). Prices come from `GetProductInfoAsync` (workspace attribute `PremiumPrices`).

### Analytics (`server/Analytics.lua`)

AnalyticsService only, every call wrapped: Shinies sources and sinks (`LogEconomyEvent`), onboarding steps (joined, first raid finished, first Shinies purchase, first item worn), and custom events ShopOpened, FirstShiniesPurchase, CosmeticEquipped, PetEquipped, AchievementUnlocked, PremiumPurchase, PurchaseFailed, SaveFailed. No personal data, no outside service.

### Adding content (no system rewrites needed)

- **A goblin cosmetic**: add a row to `Catalog.lua` (a new stable id, slot, name, blurb, rarity, and one of `price` / `free` / `unlock` / `premium`), then a builder `ITEMS.<id> = function(c) ... end` in `Wardrobe.lua` (`c.head` for head pieces in head units, `c.on`/`c.shell` for body pieces; an outfit returns true if it dresses the legs). Skins go in `Wardrobe.SKINS`, ears in `EARS`, noses in `NOSES`.
- **A boat paint, flag or figurehead**: `BoatLook.LIVERIES` (colours by role, optional `EXTRAS[id]`), `FLAGS[id]` (return true to hide the boat's own flag) or `FIGUREHEADS[id]`.
- **A trail, wake, trick effect or callout**: a row in `StyleFx` (`TRAILS`, `WAKES`, `TRICKFX`, `CALLOUTS`).
- **An emote or victory dance**: `EmoteMoves.MOVES[id] = { duration, pose = function(t) return { Joint = CFrame } end }` (add `victory = true`, and `fx = "coins" | "crown"` for a celebration effect), and an emoji in the wheel's and shop's `GLYPHS`.
- **A pet**: `Config.PETS[id]` (name, price, ability text; the ability itself is server code reading `Gear.petIs`), a catalogue row with the same id and price, `PetLook` `BUILD[id]` and `KIND[id]`, its follow spots in `client/Pets.lua` (`OFFSET`, plus `DECK` and `CLING` for walkers). A pet look: `PetLook.SKINS[id] = { pet, look }`. A pet hat: `PetLook.HATS[id]`.
- **An achievement**: a row in `Catalog.ACHIEVEMENTS` with a `stat` (an existing one, `bank_<lootId>`, or a new stat recorded through `Economy.record`) and a goal; its reward item gets `unlock = "<achievement id>"`.
- **A Robux item**: see `docs/MONETIZATION.md`.
- Then run the Luau tests (`tests/luau`): they fail for a missing look, a broken build, a part budget exceeded, a solid or ray-hit part, a dangling achievement or Robux key, or a price that disagrees with `Config.PETS`.

## V10: the look

V10 (The Living Archipelago) is a visual identity pass. Its aim: **a sunlit storybook sea, built from chunky toy pieces, where everything dangerous is drawn bigger and everything you drive is drawn smaller**, and a goblin who sees it wants to play. The design system (palette, materials, shapes, island identities, creatures, effects, rendering rules) is `docs/ART_DIRECTION.md`; this section says what the code does.

- **The contract: art never changes play.** Every V10 part is decoration (anchored or welded, non-colliding, not hit by rays, not touchable). Where a solid prop was redesigned, its V9 solid stays exactly as it was, invisible, under the new look (palm trunks, coral heads; tree trunks kept V9's size). Treasure cores keep their size and physics; new treasure trim is not hit by rays. Boat hulls, seats and physics are untouched (trim is welded and massless). A fingerprint of every solid or ray-hit anchored part (name, position, size, rotation) matched V9's exactly apart from things that move by themselves (parked boats bobbing, windmill sails turning). No speed, value, damage, timer or Config tuning changed; the Jade Frog's `visual` field (a look) is the only Config edit.
- **Palette** (`shared/Palette.lua`): the base colours, accents, leaf pairs, coral colours, boat liveries and goblin skin. `WorldKit`'s base colours read from it.
- **Environment** (`World.buildEnvironment`): deep teal water (`12, 92, 132`, transparency 0.62) over a dark `Mud` sea floor so the shallows turn turquoise; warm gold sand; warm grey rock and slate; charcoal basalt; blue-white snow; late-afternoon sun (`ClockTime` 15.2, brightness 2.7), lighter ambient, atmosphere density 0.15, clouds cover 0.4, a colour grade, bloom and sun rays. The far-sea slabs were retuned to meet the water with a fainter seam.
- **Props** (`WorldKit`): palms with a curved three-piece trunk, seven drooping fronds and coconuts; round two-tone tree canopies; rock clusters; branching coral; column bases and capitals; docks with trim and a lantern at the sea end. All deterministic from their position.
- **Island landmarks** (`server/Art.lua`, `Art.dress(refs)`, run at the end of `World.build`): one signature shape per major island (see the table in `docs/ART_DIRECTION.md`). `Art.findSpot(island, mode, minF, maxF, clear)` searches rings round the island for high ground, low shore or 2-to-14-stud shallows, keeping `clear + 12` studs from treasure spots, boat spawns and the Hoard and `clear` studs from any built part (structures, ground, ziplines, launch pads, loot, coins, hoops, ramps, kickers, buoys); deterministic; a crowded island gets a second, wider search. Windmill Hills (patchwork fields, whitewashed mill, red roofs) and Fort Barnacle (banners and bunting) restyle what is there; Skull Rock's eyes glow ghost-teal with lanterns round its shore. Each landmark is a persistent model of 7 to 100 parts. `Art.landmarks()` lists where each went; a landmark that finds no spot adds a line to `refs.buildWarnings`.
- **Creatures**: the Sun Temple Guardian is one design (`GuardianLook.lua`: a top-heavy sandstone golem with gold bands, moss, burning eyes and a turning sun halo) used for the island golem and its speedboat rider. The Leviathan is ellipsoid humps on a travelling wave with fins, flukes, horns, frills, teeth and wake foam. The Echo is a crystal imp at sea and on its island. Ghost ships are galleons with glowing sails, a skull figurehead, lit stern windows and lanterns, crewed by tricorn-hatted ghost pirates. The Watchers, Bramble, Old Clacker, the Warden (now a real eel with a dark back, fins, eyes and a jaw, each segment facing along its body), imps, marines, cinderlings, the Chill, the Maw and Gobbo gained faces, limbs and props by added parts; parts that code finds by name kept their names.
- **Goblins** (`server/GoblinLook.lua`): every player gets goblin-green skin, long pointed ears and a big nose (welded, massless, never solid, never hit by rays), applied when the avatar's appearance has loaded and again 2 s after spawning (avatar loading replaces the head and body colours). One default look; no customization system.
- **Treasure** (`Loot.lua`): the Golden Idol is a crowned golden goblin king with ruby eyes and a sun halo, with a stronger glow and more sparkle (its core is invisible, same size and physics); chests have domed lids on coins and a jewel; gems have gold settings; the Jade Frog has its own frog look (`visual = "frog"`).
- **Boats and the skyship**: liveries by class (hull colour, a stripe, cap rails, a transom, a bow lantern, striped sails with yards; the Navy keeps blue and brass). The skyship is dressed as the Golden Goblin (curved three-tier hull, gold stripe, golden goblin figurehead, jib, striped sails, rigging, crow's nest, pennant, lit stern windows, lanterns and two propellers each client turns); all of it is non-colliding, so the deck, wings and cannons are unchanged.
- **Weather and effects**: storm clouds are opaque ellipsoid billows (dark below, light above) with a wide anvil; fog banks stay pale and see-through; tornadoes as described under Tornadoes; Frost Spire's aurora is three rippling curtains of light rays; the Maelstrom's foam is long streaks along the flow; Ember Isle has lava streams down its flanks.

## V9 systems

V9 (Relentless Chaos) answers the V8 human playtest, which found the best moments were a creature right behind a fleeing boat. Its aim: **danger stays close, consequences stay small; the journey home is the funniest part.** Everything here sits on top of V8; where a V8 paragraph below disagrees, this section is what the code does. Numbers are in `Config.lua` (`PURSUIT`, `SANCTUARY`, `LEVIATHAN`, `GUARDIAN_BOAT`, `GHOST_FLEET`, `TWISTER`, `TRICK`, `GUARDIAN_SCALE`, `BOAT_HOOP_*`, `BOAT_KICK_*`, `WORLD_LABEL_RANGE`, `ISLAND_SIGN_RANGE`, `LOOT_TAG_RANGE`).

### The round (`Raid.lua`, `Skyship.lua`, `Flight.lua`, client `Hud.lua`)

A raid is a 20 s launch window (`SKYSHIP.WINDOW`) then 360 s of clock (`RAID_DURATION`): the clock starts when the window closes (`workspace.RaidClockAt`; the HUD reads `LAUNCH WINDOW 18 | RAID 6:00 STARTS AFTER`). The intermission is 10 s; during it a goblin can climb into a cannon and aim (`Skyship.preopen` publishes the bell's time as `DeployOpensAt`), and a launcher's `canFire` holds the shot until the bell, 2 s into the raid. `Skyship.boardAll(true)` at the raid's start leaves goblins already aboard where they are. Final rush 50 s (the HUD says FINAL RUSH), last call 30 s, interest every 45 s, the three nearest treasures respawn after 100 to 105 s, first storm at 40 s, first tornado at 25 s, an island's pursuer can set out again after 25 s. Shinies per raid were lowered so Shinies per hour stay about where V8 had them.

### Pursuit and the sanctuary (`Pursuit.lua`)

- **The sanctuary**: the water within `SANCTUARY.RADIUS` (450) of the Hoard, ringed by gold lantern buoys (built in `Searuns.lua`, 24 on water), and drawn on the map and minimap. No pursuer steps into it (`Pursuit.inSanctuary`, checked by `Pursuit.swim`); when its thief enters, a pursuer stops at the edge, says its own line (`form.quit`) and sinks away. The Leviathan and the Ghost Fleet obey it too. PvP is unaffected.
- **How a pursuit ends**: the sanctuary; the treasure banked or out of the thief's hands for 3 s (a rival who snatches it at sea becomes the quarry); the thief dead or gone (`Pursuit.forget`); 12 s ashore; two explosions; the raid's reset; 150 s as a backstop (`PURSUIT.TIME`). There is **no leash and no 50 s timer**.
- **Pacing** (`tickMover`): beyond `SURGE_GAP` (320) a pursuer surges at its form's `surge`; closing, it gains `close` on the thief's speed; close, it hangs at `follow` matching speed. It accelerates at `accel` and slows at only `decel`, so a thief who loses speed is caught. Every `lungeEvery` seconds it lunges (`lunge` faster for `lungeTime`), which is when its tell shows.
- **Tells lock on**: a form with `reach` 40 or less holds onto the hull and matches its speed during its wind-up, so the strike lands unless the thief boosts, turns or jumps; a long-reach form (Bramble) keeps pace and lines up.
- **Resurfacing**: 900+ studs behind (and behind the thief) or blocked by land for 3 s, a pursuer reappears `CATCH_UP_TO` (420) studs behind the thief along their wake.
- **Flying** (`Pursuit.air`): kinematic pursuers have an altitude and a vertical speed. A sea ramp throws one, a tornado lifts and spins it (`Twister.accel`), gravity `PURSUIT.GRAVITY` brings it down; in the air it cannot strike.
- **Hits** (`Pursuit.hit`): `Impact.open` is asked before anything touches the goblin **or their boat** (`Creatures.strike` takes `opened`), so nothing juggles. `Impact.protect(player, seconds)` gives a longer grace (the Guardian's launch: 3 s). Hulls never go below `IMPACT.HULL_FLOOR`. The two-strike grip is unchanged.
- **Budget**: one per island, `PER_TARGET` (2) island pursuers on one goblin, `MAX` (14) in all. Pursuer models carry the attributes `Pursuer` (its name) and `Chasing` (the target's UserId), which the minimap reads.

| Island | Sea form (V9) | What it does | The answer |
| --- | --- | --- | --- |
| Windmill Hills | Bramble in a washtub (160, surge 270) | Hangs 135 back; bleats and charges straight at 260+ | Turn or jump when he bleats |
| Tangle Isle | The imps' raft (165, surge 270) | Pulls alongside; an imp leaps for the treasure (a grip hit). Two leaps inside 6 s rob you: they are thieves | Get away from its side: boost, turn, jump |
| Shipwreck Shoals | Old Clacker under the water (160, surge 280) | A ring where you are going, then it comes up through it | Change speed or course on the ring |
| Tide Vault | The Warden eel (175, surge 290) | Under the bow, lashes the boat round | Boost or turn during its zap |
| Coral Atoll | The clam (jets, 170) | Clamps on and drags up to 4 s | Jump: it cannot hold a boat in the air |
| Maelstrom Rock | The wandering Maw (110, surge 195) | Its whirlpool follows, pulling boats in; the middle spits them up. Slow: it drains away and reforms behind you | Do not stop near it |
| Crystal Isle | **The Echo**: tiny, 230 to 340, turns at 9 rad/s, accelerates at 480 | Far off it cuts at you; close it runs your exact wake 0.6 to 0.3 s behind; it darts every 1 to 2 s. A small sideways bump that saps speed; never the treasure | Keep your speed; boost through its 0.45 s tell |
| Fort Barnacle | The garrison's gunboat (160, surge 260) | Hangs 100 back and drops marked shot ahead of you | Weave |
| Sun Temple | **The Guardian's speedboat** | See below | See below |
| Crossroads Ruins | **A Watcher surfing a stone slab** (180, surge 300) | Moves only while no goblin within 280 faces it (a goblin in a boat faces where it points); grabs the boat (a grip hit) | Turn and face it: it freezes; a friend can hold it |
| Ember Isle | **The cinderlings' lava raft** (175, surge 285) | Races AHEAD of you and lays burning patches across your way | Steer round the patches |
| Frost Spire | **The Chill** (160, surge 260) | Drifts after you and freezes patches of sea ahead (a boat on one is held) | Steer round the ice |
| Leviathan's Rest | The Leviathan | See below | Keep your speed |
| Skull Rock | The Ghost Fleet | See below | Outrun the ships; mind the dinghies |

### The Leviathan (`Leviathan.lua`)

**The V8 breach is removed** (no ring, no head up through it). Started as before (noise near the Sleeper's eye, or the Tooth's thief at sea), it **shadows** the boat: its snout `FOLLOW` (46) studs behind the stern, matching speed, surging at 300 when 300+ behind, accelerating at 150 and slowing at only 55. A boat that keeps its speed is never closed below 26 studs; every 7 s it roars and **lunges** and falls short. A boat that slows (under 80, or 22% under its recent speed) is **caught**: bumped on, swiped aside or (nearly stopped) tossed over its head; 8 hull, a grip hit, never sunk; then 4 s before it can catch the same boat again, during which it swerves off alongside and falls in behind. Boats beside its head are shoved by its bow wave. It surfaces for show (no hit) only when 140+ studs from its quarry. It stays out of water shallower than 7 studs (gives up after 10 s), stops at the sanctuary, may switch to a boat 45% nearer at most every 5 s, and flinches from explosions (three send it home). Its head part carries the `Chasing` attribute. Scale 2.6 (11 humps).

### The Guardian's speedboat (`Pursuit.lua` forms.Temple, `Threats.lua`)

When the Golden Idol's thief is at sea, a tiny stone speedboat appears off the temple's shore on their side and the Guardian **leaps** onto it from wherever it stands (`Threats.guardianBoard`, 1.6 s; `GuardianState` = `board`, then `sail`; the island stands empty until `Threats.guardianReturn` when the chase ends). It cruises at 250, surges at 360, turns at 1.9 rad/s (it overshoots a hard turn) and hangs 40 back. **The launch**: every 9 s within 120 studs it raises its fists, a 20-stud gold ring opens where the thief is going (0.85 s) and a stone fist punches up: whatever is on the ring is thrown 118 up (about 34 studs) and 30 along; no grip hit, about 1 health, 4 hull, then `Impact.protect` for 3 s. A miss retries in 4.5 s. The Golden Idol is worth 17 (the most of any treasure). The island Guardian is 1.7 times its V8 size.

### The Ghost Fleet (`GhostFleet.lua`, called by `Troubles`' GhostFleet handler)

Taking the Chalice raises the fog and `SHIPS` (3) kinematic ghost ships with `CREW` (4) ghost pirates each (posed every frame with one `BulkMoveTo`: swaying, cutlasses waving). They sail spread across the thief's wake (170, surge 230) and fire marked volleys of two that throw and batter but **never loosen a grip**, never into the sanctuary, never below the hull floor. At `DEPLOY` (650) studs off Skull Rock's shore pirates leap (visibly) from the decks into `DINGHIES` (5) tiny boats that chase at up to 290, spread across the wake, and the ships sink into the fog 14 s later. A dinghy within 20 studs waves its cutlass (0.7 s) and its pirate leaps aboard (a grip hit); one leap at a time fleet-wide, every 6.7 s at most, so pirates alone never strip a thief. Any explosion sinks a dinghy it reaches. The Shade's head start (18 s late while he dozes) still applies. `Navy.dispatchGhosts` is no longer used.

### Tornadoes (`shared/Twister.lua`, `server/Tornadoes.lua`, client `Twisters.lua`)

Independent of storms: up to `TWISTER.MAX` (3), from 25 s into a raid, 70 to 105 s each (plus a 5 s fade either side), wandering 8 to 16 studs/s within 300 studs of one of eight open-water alleys (`TWISTER.ALLEYS`), never within 1,100 of the Hoard, turning off shallows; half form at the alley nearest a goblin at sea. The server publishes them as `workspace.TwisterData` (JSON: position, velocity, birth, death); every machine extrapolates the same positions (`Twister.follow`). `Twister.accel(position, velocity, t, gravity)` is the one rule: inside the funnel (30 wide at the water, 51 at the top, 190 tall) motion across is turned into the swirl (`CAPTURE` 5 per second), lift toward 74 studs/s, swirl 58, a pull toward the middle; the skirt (1.5 radii) draws in and lifts a little; the top throws out (95 out, 30 up). **Boats**: `BoatSim.step` applies it on whichever machine simulates the hull, spins the hull with the funnel, and the jump key bails out (120 the way it points, then the funnel ignores the hull for 2 s); `Boats.police` allows 300 studs of altitude and 170 more speed near a tornado and for 7 s after. **Goblins** on foot or swimming below 45 studs, inside the funnel, are thrown into the skydive by `Tornadoes` (`Flight.launch`, 112 up), every 2.5 s at most. **Pursuers** through `Pursuit.air`. The client draws each funnel itself, up to 4,200 studs away: since V10 a soft core of seven tall ellipsoids wrapped in three spiral arms of wisps that race round and up it, eighteen bright streaks, debris, a billowing storm-cloud cap, spray and a looped roar (V9: 14 translucent cylinder bands under a flat disc).

### Boats: tricks, ramps and hoops (`shared/BoatSim.lua`, client `BoatDrive.lua`, `Tricks.lua`)

- **Tricks**: `BoatSim.startTrick(boat, kind, side, t)` (in the air, 5+ studs up); while one runs `BoatSim.step` writes the hull's orientation outright (the heading at the start times the trick's eased rotation) and zeroes its spin, skipping steering and righting; at the end the hull is exactly level and facing the way it started. Touching water mid-trick snaps it level (`sketchy`, no burst). A clean landing after tricks pays `BOAT_LANDING_KICK` + `TRICK.KICK` per trick (up to 4) and the client reports `trickland`; the server refunds `TRICK.REFUND` of boost cooldown per trick only for a hull it saw 8+ studs up in the last 2 s, once per flight. Kinds: spin, spin2, roll, backflip, frontflip, corkscrew (`BoatSim.TRICKS`). `BoatDrive.trick` picks the kind (combo order spin, corkscrew, frontflip, spin2; A/D roll; S backflip) and queues a press made during a trick. The driver's anchor prompt is hidden while driving. Callouts and other players' trick labels: client `Tricks.lua`.
- **Ramps**: the kick is `BOAT_KICK_SPEED` + `BOAT_KICK_PER_SPEED` per stud/s over `BOAT_KICK_MIN_SPEED`, up to `BOAT_KICK_MAX` (112), and it clears pitch and roll spin so the boat flies level. Seven new ramps (`buildRamps` in `Searuns.lua`) stand beside lanes; `ramp()` refuses a site without open water to ride and land in (`refs.ramps` lists them).
- **Hoops** (`BoatSim.gate`): the hull is swept from its position at the last check (`boat.gatePosition`); a hoop counts if the path crosses its plane within its radius plus half the hull's width plus `BOAT_HOOP_REACH`, scaled separately for height (half the hull's height), or the hull ends a frame across the plane (`BOAT_HOOP_DEPTH`). Hoops carry their ring's height (`ringY` / `cy`).

### Clarity: labels, the minimap, the map

Island names show within `ISLAND_SIGN_RANGE` (240) of the island's middle, treasure tags within `LOOT_TAG_RANGE` (170), landmarks and course signs within `WORLD_LABEL_RANGE` (220) or less, the Guardian's tag within 120. The label over the Hoard shows only while carrying; the screen-edge Hoard arrow (`Map.lua`) hides while the Hoard is on screen. From the skyship only the island the aim ring is on wears its name and tier (client `Skyship.lua`, `focusIsland`). The **minimap** (client `Minimap.lua`, top right; the treasure board moved below it) is a clipped rounded square about 1,100 studs to the edge, turning with the camera, drawing islands from `Archipelago`, the island you are at (name and tier underneath), the Hoard (an arrow on the rim when off the map, pulsing while you carry), the sanctuary ring, nearby waiting or loose treasure (not while you carry), tornadoes, and only the models whose `Chasing` attribute is you. The map (M) shows the sanctuary and tornadoes.

### Bigger guardians

`Creatures.body` and `Pursuit.body` take a scale (sizes and offsets). `GUARDIAN_SCALE`: the Guardian 1.7 (its reach scales), Watchers 1.6, Old Clacker 1.6, Bramble 1.7, the Warden 1.6, the Chill 1.5, the Maw 1.4, sea forms 1.6, the Echo's sea form tiny. Minions (imps, marines, cinderlings) are not scaled; the island clam is the Pearl's housing and is not scaled.

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

**Superseded by V9** (the sanctuary, pacing, no leash or timer, new forms for the Guardian, the Watchers, the Cinderlings and the Chill, a new Echo): see V9 systems. The V8 description follows as history.

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

**Superseded by V9**: the breach described here no longer exists; see V9 systems. The V8 description follows as history.

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

**Superseded by V11** (see **V11: Goblin Life**): the paragraph below describes V7.

Shinies are the lasting currency; raid Gold only decides the raid. `Progress.award` pays once per goblin per raid (participation, banked gold, the win, a small underdog lift, capped). The profile is one DataStore key per player; a profile that failed to load is **never saved over** the stored one (`SaveState` is `saved`, `unsaved` or `unavailable`). Purchases are checked against `Config.PETS`/`Config.KIT_PRICE`. Pets are drawn on every client from the attribute `Pet`. The Robux receipt handler is installed only when `Config.MONETIZATION.PRODUCTS` has an entry (it is empty): receipts are idempotent by purchase id and confirmed only after a successful save.

### Recall (`Recall.lua`), the final rush, navigation

See Boats (B). In the last `FINAL_RUSH` seconds `Raid.onBanked` pays `FINAL_RUSH_MULT` times. A carrier gets a waypoint arrow toward the Hoard (`Map.lua`); the compass lists only treasure within `COMPASS_LOOT_RANGE`; the treasure board shows only loose or carried treasure unless `T` is pressed.

## Architecture

| Repository path | Rojo maps it to | Holds |
| --- | --- | --- |
| `src/server/Main.server.lua` | `ServerScriptService.LootGoblinsServer.Main` | Boot, wiring, player lifecycle, the one Heartbeat |
| `src/server/<Module>.lua` | `...LootGoblinsServer.<Module>` (ModuleScripts) | `Net`, `Util`, `Gear`, `Movement`, `Sea` (forwards to shared), `SeaNav`, `WorldKit`, `Landform`, `World`, `Islands`, `IslandsFar`, `Outlands`, `Seaways`, `Searuns`, `Boats`, `Recall`, `Skyship`, `Loot`, `Heat`, `Poltergoblin`, `Destructibles`, `Blast`, `Cannons`, `Kegs`, `Mechanisms`, `Combat`, `Threats`, `Storms`, `Navy`, `Alerts`, `Troubles`, `Escalation`, `Coins`, `Creatures`, `Leviathan`, `Bestiary`, `BestiaryMinor`, `Progress`, `Monetization`, `Raid`; V8 `Impact`, `Flight`, `Pursuit`, `SeaMobs`; V9 `Tornadoes`, `GhostFleet`; V10 `Art` (island landmarks), `GuardianLook` (the Guardian's design), `GoblinLook` (players' goblin look, V11: dressed from the `Look` attribute); V11 `ProfileSchema`, `ProfileStore`, `Economy`, `Receipts`, `Analytics`, `Emotes`, `BoatStyle` |
| `src/client/Main.client.lua` | `StarterPlayerScripts.LootGoblinsClient.Main` | Input, client movement, event routing |
| `src/client/*.lua` | ModuleScripts next to it | `Hud`, `Effects`, `Map`, `Weather`, `BoatDrive`, `Skyship`, `Shop` (V11: the Goblin Wardrobe); V9 `Tricks` (trick callouts), `Twisters` (tornado drawing), `Minimap`; V11 `Ui` (interface kit), `Pets`, `Looks` (boat style, emote poses, celebrations), `Emotes` (the wheel), `Results` |
| `src/shared/*.lua` | `ReplicatedStorage.LootGoblins` | `Config` (tuning), `Archipelago` (the island list), `Sea` (sea math), `BoatSim` (boat physics, V9 tricks and swept hoops), `Dive` (the dive model), V9 `Twister` (tornado maths), V10 `Palette` (the art direction's colours), V11 `Catalog`, `Wardrobe`, `BoatLook`, `PetLook`, `EmoteMoves`, `StyleFx` |
| `tests/luau/` | `ServerStorage.LootGoblinsTests` (only in `test.project.json`) | V11's Luau tests: `Runner` and `Specs/*`. Run in Studio's Edit mode: `require(game.ServerStorage.LootGoblinsTests.Runner).run().summary` |

- **Plain modules, no framework.** Direct calls and tiny `Util.signal()` events. Require order has no cycles: `Net`/`Util` → `Movement` → `Sea`/`SeaNav` → `World`/`Boats` → `Loot` → `Heat` → `Poltergoblin` → `Destructibles` → `Blast` → `Cannons`/`Kegs`/`Mechanisms` → `Combat`/`Threats` → `Storms` → `Navy` → `Troubles` → `Escalation` → `Coins` → `Creatures` → `Bestiary`/`BestiaryMinor` → `Raid` → `Main`. (`Main` requires the two bestiary modules only so they register their creatures before `Creatures.build`.) Injections that avoid cycles: `Loot.canBank`, `Destructibles.explode` (set by `Blast`), `Threats.handlers` (filled by `Troubles`), `Blast.Hit` (Navy's mines listen), `Mechanisms.BeaconLit` (Main tells the Navy), `Landform.touch` (set by `World`), `Boats.Sunk` and `Storms.Spent` (Main drops salvage), `Loot.Taken` (Main tells `Creatures.onTaken`).
- **Remotes** (`ReplicatedStorage.LootGoblinsRemotes`, recreated at boot). Client → server: `ThrowRequest`, `GrappleRequest`, `PoltergoblinRequest`, `SprintRequest`, `MoveRequest("dash" | "airjump")`, `BoatBoostRequest`, `BoatDriftRequest(held)`, `BoatFxRequest(kind)`, `BoatBoardRequest`, `CannonRequest(basePart, aimPoint)`, `KegRequest(aimPoint)`; V7: `BoatJumpRequest`, `BoatRecallRequest`, `StealRequest(player)`, `DeployRequest(action, a, b)`, `ShopRequest(action, id)`.
- **V11 remotes and events.** Client → server: `ShopRequest(action, a, b)` (now `buy`, `equip`, `unequip`, `presetsave`, `presetload`, `opened`, `robux`), `EmoteRequest(emoteId | "stop")`. Server → client `GameEvent` kinds: `ShopResult`, `Welcome`, `Achievement`, `Premium`, `RaidReward`, `Celebrate`. Player attributes: `Look`, `Owned`, `Achievements`, `AchievementProgress` (JSON), `Presets` (JSON), `Emote`, `Shinies`, `SaveState`, `Pet`, `Kit`. Boat attributes: `StyleOwner`, `StyleSig`, `Trail`, `Wake`, `TrickFx`, `Callout`. Workspace: `PremiumPrices`, `PremiumPreview`. `ReplicatedStorage.LootGoblinsPreview` holds still copies of a skiff and a cutter for the shop.
- **V9 added no remote.** `BoatFxRequest` carries more kinds (`trick` with its name, `trickland` with a count, `sketchy`, `bail`) and the server relays them as `BoatFx`; V9's server events are `SeaFx` kinds `quit`, `roar`, `spout`, `dart`, `gfist`, `yarr`, `cannon`, `stone`, and `GuardianLaunch`, `TwisterBorn`, `TwisterThrow`. V9 attributes: `workspace.TwisterData`, `workspace.RaidClockAt`, `workspace.GuardianState` (`board`, `sail`), pursuer models' `Pursuer` and `Chasing`.
- **`GameEvent(kind, payload)`** server → client. V2's kinds plus: `Dash`, `AirJump`, `BoatFx` (a drift burst or clean landing on someone else's boat), `BoatPush` (to a driver: apply this push to your hull), `GuardianStomp`, `NavyRam`, `Spout`, `Beacon`, and V5's `Coin` (you took one), `CoinsBanked`, `Run` (started, finished, new best), `Creature` (a creature did something here: the client picks the sound and puff by `kind`). V7's server events: `DiveStart`, `DiveBounce`, `DiveFire`, `DiveImpact`, `DeployOpen`, `RecallCalled`, `AlertRaised`; `GrappleFX` gained `catch`. **V5 and V6 added no remote.** `Net.broadcastNear(position, range, kind, payload)` sends an event only to goblins within `range` of where it happened; `Blast.lua` uses it for markers, bolts and blasts (a storm across the sea is nobody's business at home). Use it for anything loud and local.
- **Replicated state is attributes** (times in `workspace:GetServerTimeNow()` units). Player: `CarryingLoot`, `Kegs`, `Stamina`, `Sprinting`, `Winded`, `Chilled`, `Coins`, `CoinGold`, grapple/Poltergoblin timers. Boat model: `BoatType`, `Health`, `MaxHealth`, `Pilot` (UserId of the client simulating it), `Moored`, `BoostEndsAt`, `BoostReadyAt`, `BoostRefund`, `Payload`. Coin part: `Value`. `workspace`: `RaidPhase`, `PhaseEndsAt`, `Heat`, `HeatTier`, `GuardianState`, `StormData`, `SeaRough`. `Loot` folder: `<id>State`, `Carrier`, `CarrierId`, `ReturnAt`, `Bonus`. Vent: `GeyserPeriod/Active/Phase`, `Launch`. Launch pad: `Launch`, and `Carry` on a catapult. V7: player `DeployState`, `DeployDest`, `DeployAim`, `Diving`, `DownedUntil`, `CatchImmuneUntil`, `Gear`, `Pet`, `Shinies`, `OwnedPets`, `OwnedKits`, `Kit`, `SaveState`, `RecallReadyAt`; boat `Recalled`; `workspace` `DeployOpensAt`, `DeployEndsAt`, `Alert_<island>`.

Integration points new code must respect:

- **WalkSpeed and stamina:** go through `Movement`. **Player damage:** `Util.damage` + `Poltergoblin.markDamage` (or just use `Blast.at`). **Knocking loot loose:** `Loot.knockLoose` respects immunity; `Loot.dropFor` ignores it. **Teleports/resets:** cancel Poltergoblin, unseat players. **Pushing players:** `Util.knockback`. **Pushing or moving boats:** `Boats.shove`, `Boats.place`. **Explosions:** `Blast.at` / `Blast.strike`, never ad-hoc. **Telegraphs:** anything dangerous must show a `Marker` (or its own clear tell) first. **Sounds:** a sound that happens somewhere must be given its `position` (never play a world event as an interface sound: that was the map-wide thunder of V2 to V5). **Creatures:** touch a player only through `Creatures.strike`, and hold treasure only through `Loot.hold`.
- **V9:** a creature's hit at sea goes through `Pursuit.hit` (it asks `Impact.open` before touching the goblin or the boat). A pursuer's altitude and throws go through `Pursuit.air`. Nothing that follows a thief may enter the sanctuary (`Pursuit.inSanctuary`). Anything that lifts a boat or a goblin into the air should use `Twister.accel` or `Flight.launch` rather than writing velocities, and new hull-throwing effects must stay inside `Boats.police`'s allowances (it now tracks `lastHighAt`, `twistedAt` and server shoves).
- **The shared E key:** a visible prompt always wins over Poltergoblin.
- **The shared C key:** dash on foot, drift in a driver's seat.
- **The R key (V9):** a trick in a driver's seat; the anchor prompt elsewhere (hidden for the driver while driving).
- **V11:** ownership, balances, achievements and Robux grants are decided only by `Progress`/`Economy`/`Monetization` on the server; anything a goblin wears is applied by the server (`GoblinLook`, `BoatStyle`) or drawn by clients from replicated attributes; cosmetics are always massless, non-colliding, not ray-hit and not touched; an emote never moves a character; pets never collide.

## Who decides what (server vs client)

- **The server owns (V11):** Shinies, everything owned and worn, presets, achievements, payouts and Robux grants, and when a pet may change. **The client draws** pets, trails, wakes, trick effects, emote poses and previews from replicated attributes, and sends only intent.
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

- **V11**: live DataStore saving and real Robux purchases have not run (no API access in the Studio place, no products); nothing was tested with a second player, on a phone or with a real controller; emotes on the classic six-part avatar map only some joints; dynamic and Rthro heads were not looked at; previews of trails, wakes and trick effects are flat colour previews (a ViewportFrame cannot draw particles); capes are static; prices are first guesses. See the V11 report, section 28.
- The art is still built from primitive parts and ellipsoids (V10 made it deliberate, not detailed). V10 was judged by one AI from screenshots; a person has not looked at it. Close up, the landmarks' stone heads and arches are blocky by design.
- Steep shore edges still stop a boat dead; boats pass through dock posts.
- Dash, drift, boost, grapple, throw, keg, cannon and Poltergoblin have no touch buttons.
- The Guardian walks through walls and can't enter tunnels. So does every creature: a marine goes through a barracks, a Watcher climbs the outside of the lighthouse.
- Creatures are a few dozen parts each since V10 (V9: a few blocks). Their numbers and the timed runs' pars are first guesses.
- Old Clacker will not follow treasure into the water. Gobbo stands a little above the ground.
- The insides of the treasure sites were designed for V2's movement. V3's jump, air jump, dash and longer grapple were not checked against them.
- The new land is still mostly plain between the landmarks: trees, palms, rocks and the features in the V4 report. Silhouettes are blocky and only cover ground taller than about 12 studs.
- A sign at the very edge of its range can blink (the range check runs every 0.4 s). Since V9 treasure tags show only within 170 studs (they showed across the whole map through V8). The map's region name "THE LONG REACH" no longer describes its water.
- The two laps are large (580 and 660 studs across). Whether they are worth their size, and whether straight lanes are better or duller than V5's, is unjudged.
- A patrol ship returning to the fort while the chain is up bumps against it until it gives up.
- Not tested with more than one player, on mobile, on weaker hardware, or with real latency. Client frame rate: 60.0 fps (V6) and 59.8 fps (V7, at Skull Rock); never measured in a busy scene.
- **V7 has never had a second player.** The 32-player target is a code audit and a wider spawn pad, not a measurement. The ship, the dive pose, the Leviathan, the white Navy and the pets have not been looked at by a person; real DataStore saving has not run (Studio had no API access); the Robux receipt path is untested against a real purchase and is inert; touch has no buttons for the new actions; the island and boat cannons have an aim ring but no trajectory arc.

## Known bugs

- **V11 has not been played by a person, and never with two players.** Not seen in the world: the ghost and tortoise following, the Self-Crowning crown, the clean-landing confetti burst, the tailor's stall; the rainbow trail and Comic Pop callouts were fixed after their only screenshots. The pet level-of-detail was not re-measured with 32 pets after it was added.
- **V9 has not been played by a person, and never with two players.** Everything in the V9 report was measured by one AI on one Studio client, mostly with a test autopilot. A pursuer choosing between two thieves, two boats in one tornado, other players seeing tricks, and the trick boost refund were not observed.
- **V9 guardian bodies were scaled without checking their fit** on their islands (clipping into ruins, the temple). V10 looked at the Guardian, the Watchers, Bramble, Old Clacker, a marine and the Warden at rest and saw no clipping; their full patrols and chases were not watched for it.
- **V10 has not been looked at by a person.** Every V10 judgement is one AI's, from Studio screenshots on one client. Things a person may still dislike: the far-sea seam (fainter, still visible from height), the stone head and sea arch up close, the Bramble's wool reading grey in shade.
- **The Guardian is away from the Sun Temple while it chases at sea**; a second goblin there meets no Guardian until the chase ends.
- **The imps can rob a thief at sea on their own** (two leaps inside 6 s); intended, unplayed.
- **Ghost ships were faint in Skull Rock's fog** (V9); V10 redrew them (darker hull, glowing torn sails and waterline, lit stern windows); a clear still is in the V10 report.
- **V8 has not been played by a person, and never with two players.** Everything in the V8 report was measured by one AI on one Studio client. Other players seeing the loose limbs, two goblins flying at once, a pursuer choosing between two carriers and two boats sharing the Leviathan are untested.
- **V8 creature art was primitive**: V10 redrew the Guardian, the Leviathan, the Echo and the Ghost Fleet and added detail to every island creature; the other sea forms (the tub, the raft, the gunboat, the clam, the slab, the lava raft) and the sea mobs are still V9's. The Leviathan's breach was measured (hull hits, states, the jump that dodges it) but never caught in a screenshot.
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

- **V9 lessons.** (1) **The Rojo plugin was not connected and the Rojo server crashed when StyLua rewrote files**; a loopback file server (`python -m http.server` bound to 127.0.0.1, serving `src/`) and an Edit-mode `execute_luau` that sets every mapped script's `Source` from it (with `HttpService.HttpEnabled` switched on only for the call) kept Studio identical to disk after every fix; compare sources rather than trusting either. (2) The harness used for V9 (a Workspace Script obeying a `DebugCmd` attribute) stole treasure for real, put a skiff off the island and drove home with `boat.input` and `SeaNav.path`; drive at `route[index]`, never a look-ahead (it cut a corner across an island), and pick test water without puffers (they knock a test boat off its line). (3) A frame-by-frame probe of one pursuer's state and distance to the hull found the tell overshoot that summary numbers hid. (4) `screen_capture` with a camera position during play is how chases were photographed; aim where the boats will be about a second later, or stop the boat (most pursuers then settle behind it). (5) A round `CanvasGroup` did not clip in Studio; use a frame with `ClipsDescendants`.

- **V10 lessons.** (1) **A `Ball` part with a non-uniform size renders as a sphere the size of its smallest side**; for ellipsoids use a block with a `SpecialMesh` sphere (V9's storm clouds and fog were small spheres because of this). (2) **A long-range coloured `PointLight` dyes everything round it**: a red eye with a 40-stud light turned a grey head pink. (3) **Terrain colours do not render as written** (`Slate`/`Rock` read lilac; `Basalt` set to warm reds rendered teal): check each in a screenshot. (4) **`os.clock()` is CPU time, not real time**: a wait loop timed by it stalls; use `time()`. (5) **Avatar loading replaces the head and body colours just after a character spawns** (`HasAppearanceLoaded` can be true too early): apply looks on `CharacterAppearanceLoaded` and again after a delay, idempotently. (6) **Collision fingerprint**: hash every solid or ray-hit anchored part (name, position to 0.1, size, rotation) grouped by folder and name, build the old version's sources from a second loopback server, and compare; only self-moving things (parked boats, the windmill's sails) should differ. (7) **Studio's 3D view can go blank white** (the interface still draws, in Edit mode too) after the machine pauses or sleeps; only restarting Studio brings it back, so ask the human to close it.

- **V11 lessons.** (1) **`ServerScriptService.LoadStringEnabled` cannot be set from Studio MCP**; for deep tests a temporary Workspace Script exposing a `BindableFunction` that calls the running game's own module functions by name worked (tables are copied across it, so mutate state through a command, not a returned table). (2) **Studio caches `require` in Edit mode**: a test run after a sync used the old module until each ModuleScript was replaced with a clone. (3) **Mouse coordinates for `user_mouse_input` do not match screenshot pixels** (Studio's top bar): a click meant for a tab closed the wardrobe through its backdrop; give interface objects unique names and click by `instance_path`. (4) **A second press sent in a later MCP call can arrive seconds later**: put both presses of a two-press action in one input sequence. (5) **Screen captures arrive a second or two after the call**: trigger short effects (an emote, a victory dance) just before capturing, and confirm them from client state. (6) **Roblox's Fabric material reads as knitted wool on goblin-sized parts**; use SmoothPlastic for small cloth. (7) **A ViewportFrame does not draw particles or trails**, so effect previews must be flat. (8) **The intermission rule moves goblins back onto the skyship**; boat tests need a running raid (the harness ended and started raids, and lengthened `Config.INTERMISSION` for ship tests).

### Testing expectations

- Every change: `check.ps1` passes. Gameplay changes also need a Studio playtest with an empty console, then play mode stopped. Report anything you could not test.
- **V11 Luau tests**: after any change to the catalogue, economy, saving or receipts, run `tests/luau` in Studio's Edit mode with the test place (`test.project.json`, built by `check.ps1` to `build/LootGoblinsTests.rbxlx`) or with `ServerStorage.LootGoblinsTests` synced in: `require(game.ServerStorage.LootGoblinsTests.Runner).run().summary`. Studio caches `require` in Edit mode: replace the ModuleScripts with fresh clones (or reopen the place) before re-running after an edit, or the old code runs.
- Timed effects are shorter than MCP round trips: record state in a `task.spawn` loop and read it afterwards.
- Single-client MCP play cannot test player-vs-player features. Teleporting 1000+ studs under streaming can let a character fall through terrain that has not loaded yet; that is a test artifact, not a game bug.
- Boat physics run on the test client when it drives. To test them without depending on injected keys, set `boat.input` from a temporary test script (the server then simulates with the same `BoatSim`).
- Studio's network simulator (`settings():GetService("NetworkSettings").IncomingReplicationLag`) is a Studio-wide setting: put it back to 0.
- The real validation is the human multiplayer test: **Test > Server & Clients > 4 players > Play**. The V6 report has a checklist.
- A sleeping creature is not ticked. To test one, put a goblin within its `wake` radius first; `Creatures.active()` says how many are awake.

## Human prototype experiment and decision

Through V6: no shops, XP, pets, rarity tables, monetization, trading, boat trees, hideout decorating, or saved progress. V7 added Shinies, pets, start-with gear and a saved profile on the team's explicit instruction (the V7 prompt); Enrik kept them on 2026-10-14 and opened the scope. Robux sales stay off until someone creates real products in the Creator Dashboard. Everything V7 sells is a sidegrade, gear is free in the world, and no essential content is paid. The loot values and `Wins` still score a raid.

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

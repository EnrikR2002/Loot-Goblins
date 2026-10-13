# Report: V4, the living archipelago

| | |
| --- | --- |
| Date | 2026-10-12 |
| Request | Ninety's "V4 One-Shot: The Living Archipelago" prompt |
| Agent | Claude Code (Opus 5.5), local session on Ninety's machine with Roblox Studio MCP |
| Branch | `feature/v4-living-archipelago`, **stacked on** PR #11's branch `feature/v3-speed-agency-danger` (itself stacked on PR #10, then PR #9) |
| Pull request | [#12](https://github.com/EnrikR2002/Loot-Goblins/pull/12), base branch is `feature/v3-speed-agency-danger` |
| Merge status | **Not merged.** Nothing was merged, including PRs #9, #10 and #11. Needs a human playtest and explicit approval. |

## 1. Summary

The V3 playtest said the goblin and the boats now feel right, and that they have outgrown the world: a skiff crossed the whole map in 20 seconds. V4 rebuilds the geography around what the player can now do.

- **The sea is 4.6 times bigger** (6900 x 5840 studs, was 3200 x 2740) and is laid out in **regions** with different characters, not in even rings.
- **Every large island is bigger and has more than one way in**: headlands, hills, cliff-walled crags, hidden inlets a boat can follow, second docks. The treasure sites themselves are unchanged.
- **The water between islands has things in it**: a reef that closes Home Bay, a shelf of shallows only small boats can cross, three fields of sea stacks, a narrow fast strait, lone rocks to steer by, seven currents and sixteen boost hoops.
- **Five new kinds of thing to use**: a harbor chain that locks the Navy in port, signal beacons that send patrol ships the wrong way, catapults, ziplines off the new crags, and boat ramps over sandbars.
- **Four new small islands** as places to stop on the long crossings, three with a small treasure (19 treasures in all).
- **Far islands stay on the horizon** as plain silhouettes that never stream out.
- **Numbers retuned for the distances**: far treasure pays more, Heat builds slower per second, storms are seeded near players, raids are 10 minutes, every island has a boat (43, was 14).

The game is tested in Studio by one AI on one client. **Nobody has played V4.** Start-up takes about 7 seconds (V3: 3). Section 12 says exactly what was and was not verified.

## 2. How I read the prompt, and what I did not do

- "Substantially larger" is tied to travel time, not to a multiplier. I sized the sea so that a near island is 6 to 8 seconds by skiff, a middle island 13 to 29, and a far one 37 to 49. Section 4 has the table.
- "Not uniform scaling": islands were not scaled. The eight original islands were **moved whole** (their terrain lands on the same voxels, so their shapes are identical), and new land was generated around all of them.
- I kept every V3 system and did not change movement, stamina, dash, air jump, grapple, Poltergoblin, drift or boost.
- I did not add progression, shops, new boats, or weapons. The three new treasures use existing models and existing trouble.
- I did not rebuild the inside of any treasure site. Routes inside the Sun Temple, the Fort's keep, the Tide Vault and so on are as they were in V3.
- **Two things in the plan changed while building.** Twin Stacks stayed beside Crystal Isle (the zipline between them is the reason they exist) instead of moving next to the Crossroads; the stack field near the Crossroads is a new feature, the Teeth. And the hook posts I planned as a general tool ended up only at the Gate: sea stacks and crags are already things to grapple.

## 3. The shape of the sea

North is up (-Z). Goblin Cove is in the south.

| Region | Islands | Character |
| --- | --- | --- |
| **Home Bay** | Goblin Cove, Pebble Isle, Coral Atoll, Gull Rock, Smuggler's Cove | Sheltered. Wrecker's Reef closes the bay to the north with one deep gap (the Gate) and two shallow passes. |
| **The Crossing** | Crossroads Ruins | The hub. Every northern route passes it. The Home Stream runs from it down to the Gate. |
| **Western Shallows** | Shipwreck Shoals, Kelp Cay (new), the Tide Vault | A sandy shelf 4.8 studs deep and about 800 across, with dry bars to steer around. A patrol ship cannot enter it. |
| **Eastern Reach** | Windmill Hills, Crystal Isle, Twin Stacks, Maelstrom Rock | A cluster, then one rock alone in open water. The Teeth (a stack field) lie between it and the Crossroads. |
| **Navy Waters** | Tangle Isle, Fort Barnacle, Driftwood Key (new) | Within 1500 studs of the fort, patrol ships launch from its harbor. The Serpent Channel runs between the two big islands with the fastest current in the sea. |
| **The Far North** | Sun Temple, Pilgrim's Rock (new), Frost Spire, Leviathan's Rest | Long open crossings, with lone rocks (the Old Man, Two Sisters, North Pillar) as the only landmarks. |
| **The Cinders** | Ember Isle, Lantern Key (new), Skull Rock | Basalt stacks scattered between three islands. |

Why these shapes:

- **Remote islands** (Skull Rock, Frost Spire, Leviathan's Rest) are far from everything, so going is a commitment and a lost boat is a real problem. Each now has a spare boat.
- **Clusters** (Home Bay, Eastern Reach, the Cinders) put several goblins in the same water, so they meet.
- **A narrow strait** (the Serpent Channel) and **a gated bay** (Home Bay) are the two places the map forces a choice of line.
- **Sheltered water** (the Shallows) is somewhere a thief in a small boat is safe from the Navy, at the price of a slower, twistier route.
- **Staging points** (the four keys and rocks) break the longest legs. Each has a dock and a skiff; three have a beacon.

The world map (`M`) now shows the region names.

## 4. Separation and sea travel

Straight-line distance from Goblin Cove, and the time at a skiff's top speed (108 studs a second). Real trips are a little longer: a boat takes about four seconds to reach top speed, and the line is rarely straight.

| Island | V3 studs | V3 seconds | V4 studs | V4 seconds | Change |
| --- | --- | --- | --- | --- | --- |
| Pebble Isle | 378 | 3.5 | 666 | 6.2 | 1.8x |
| Gull Rock | 438 | 4.1 | 669 | 6.2 | 1.5x |
| Coral Atoll | 432 | 4.0 | 783 | 7.3 | 1.8x |
| Smuggler's Cove | 466 | 4.3 | 826 | 7.7 | 1.8x |
| Crossroads Ruins | 650 | 6.0 | 1450 | 13.4 | 2.2x |
| Windmill Hills | 760 | 7.0 | 1772 | 16.4 | 2.3x |
| Shipwreck Shoals | 941 | 8.7 | 2139 | 19.8 | 2.3x |
| Kelp Cay | new | | 2224 | 20.6 | |
| Twin Stacks | 1038 | 9.6 | 2475 | 22.9 | 2.4x |
| Crystal Isle | 997 | 9.2 | 2516 | 23.3 | 2.5x |
| Tide Vault | 1063 | 9.9 | 2524 | 23.4 | 2.4x |
| Pilgrim's Rock | new | | 2692 | 24.9 | |
| Maelstrom Rock | 1416 | 13.1 | 3084 | 28.6 | 2.2x |
| Tangle Isle | 1465 | 13.6 | 3301 | 30.6 | 2.3x |
| Sun Temple | 1370 | 12.7 | 3310 | 30.6 | 2.4x |
| Ember Isle | 1563 | 14.5 | 3969 | 36.8 | 2.5x |
| Lantern Key | new | | 4203 | 38.9 | |
| Fort Barnacle | 1506 | 13.9 | 4404 | 40.8 | 2.9x |
| Driftwood Key | new | | 4610 | 42.7 | |
| Leviathan's Rest | 1903 | 17.6 | 4693 | 43.5 | 2.5x |
| Frost Spire | 1877 | 17.4 | 4729 | 43.8 | 2.5x |
| Skull Rock | 2108 | 19.5 | 5284 | 48.9 | 2.5x |

**Measured in Studio** (a skiff driven by the server at full throttle, the same physics a player's client runs):

- From outside the harbor mouth to the Crossroads beach: **1000 studs in 10.0 s** from a standing start. It reached 102 studs/s in 4 s, and the hoop in the Gate took it to 142.
- Back from the Crossroads to the harbor through the Gate, carrying the Lighthouse Lens: **930 studs in about 10 s**.

**Keeping the trips busy.** A longer trip is only better if something happens on it. On the measured Home to Crossroads leg a boat passes, in order: the harbor mouth between two watch crags, a hoop, the reef and its lamps, the Gate and its hoop, the Home Stream, and the Chimney rock off to the east. Nothing on a main lane is more than about ten seconds from the next thing. The far north is deliberately emptier.

## 5. What was added to each island

Offsets and shapes are in `src/server/Outlands.lua`, one function per island.

| Island | Added |
| --- | --- |
| **Goblin Cove** | Two arms reach north round the docks and make a harbor. A watch crag on each point with a **harbor gun**; a ramp up each; a zipline from the west crag down to the docks. A third dock (seven boats at home, was four). Hills behind the Hoard with **the Back Door**, a cove with its own dock, so there are two ways home. |
| **Crossroads Ruins** | High ground to the north-west ending in the Watch Crag: a **beacon** and a **catapult** that lands you on the acropolis. A meadow and a second dock facing the temple. A sand spit east. A drowned colonnade you can wade west to an islet with a keg crate. |
| **Sun Temple** | Now the middle of a much bigger island: jungle west and east, highlands behind the mesa. **The Serpent River**, an inlet a boat can follow from the east coast to the old shore, with a hidden skiff at its head. **The Moon Altar**, a crag with a **catapult** onto the mesa. The Sun Spire's zipline now runs out to Pilgrim's Rock. |
| **Crystal Isle** | A north shore, a south-east beach with a second dock, and **the Shards**: five basalt needles on a shelf off the north-east coast, three with perches, one with kegs and a zipline to the beach. |
| **Shipwreck Shoals** | A ring of sandbars with gaps, a second wreck broken on the north bar with a working **gun**, a spare skiff. |
| **Windmill Hills** | Shepherd's Ridge east to a watch crag: a **beacon**, a ramp, a long zipline back to the dock. Terraced fields north, a meadow and a second dock west. |
| **Tide Vault** | A broken ring of sandbars round the shallows, two drowned towers (the west one has a **beacon**), a boat ramp over the south-west shoal. |
| **Tangle Isle** | More jungle, four more pillars with perches (one rope bridge between two of them, one zipline, one keg crate). **The Hidden River**: a boat can come in from the north, out of sight of the dock, to a skiff under the trees. |
| **Fort Barnacle** | Two stone moles and **the harbor chain** between them (lever on the west mole). **Siege Hill** to the east: a cannon that bears on the cracked wall, a **catapult** over the wall, kegs. Gallows Point to the west with a spare skiff out of sight. A landing beach north-west. |
| **Ember Isle** | A lava delta east with **a river of fire** down its middle (it burns; jump it). A black beach south with a second dock below the geysers. The first four of the Cinders. |
| **Frost Spire** | An ice shelf west, a second peak north with a zipline down to the floes, and **seven ice floes** off the north shore to hop across or slalom through. |
| **Leviathan's Rest** | Salt hills south, three rock tusks west (two with perches), and **the rib run**: eight arches of a second skeleton over open water with a hoop at each end. |
| **Skull Rock** | Six teeth of rock ringing the approach to the mouth, a spine of high ground north with a zipline, **a skiff in the lagoon inside the skull**. |
| **Smuggler's Cove** | A horseshoe ridge to the south hiding a lagoon with a spare skiff and kegs. |
| **Pebble Isle** | A sandbar tail and a spare skiff. Left simple on purpose. |
| **Gull Rock, Twin Stacks** | A **beacon** on each. Left simple on purpose. |
| **Coral Atoll, Maelstrom Rock** | A spare skiff. Otherwise unchanged. |
| **Kelp Cay** (new) | A low key in the middle of the Shallows: dock, skiff, **beacon**, kegs, the Sunken Sextant (4 gold). |
| **Pilgrim's Rock** (new) | A 30-stud stack south of the temple: the temple zipline's landing, a ramp, a dock and skiff, a **beacon**. No treasure: it is the ambush spot for whoever just robbed the temple. |
| **Lantern Key** (new) | A rock with a lantern tower between Ember, Frost and Skull: dock, skiff, **beacon**, the Storm Lantern (10 gold) on the gallery. |
| **Driftwood Key** (new) | Wreckage on the crossing from the fort to Leviathan's Rest: dock, skiff, **beacon**, the Castaway's Hoard (11 gold). |

## 6. Active novelty, island by island

The prompt asks for four things: **Discovery** (something to find), **Engagement** (the player does it, not watches it), **Consequence** (using it changes what happens next) and **Improvisation** (it is useful for something its builder did not script). I scored what V3 had, then added where an axis was empty. "+" is what V4 added.

| Island | Before V4 | Weakest axis | V4's answer |
| --- | --- | --- | --- |
| Goblin Cove | Toys, practice cannon | Consequence: nothing at home mattered to a raid | + Two guns that cover the harbor mouth, and a second way in. Coming home is now a decision. |
| Crossroads | Lighthouse climb, launch pads, the bell | Improvisation | + Catapult (a way in, a way to chase a thief up the acropolis), beacon, wading route |
| Sun Temple | Guardian, boulder, stairs | Discovery: one approach | + River inlet, catapult from the Moon Altar, zipline off the island |
| Crystal Isle | Cave, cave-in, the leap | Discovery | + The Shards (find the kegs, find the zipline) |
| Shipwreck Shoals | Wreck, barrage | Improvisation | + A gun anyone can fire, and bars that turn the approach into a maze |
| Windmill Hills | Sails to time | Consequence | + Beacon (changes where the Navy is), zipline out |
| Tide Vault | Lever, gate, flood, drain | already the best in V3 | + Beacon, a ramp. Left mostly alone. |
| Tangle Isle | Canopy bridges that snap | Discovery | + Hidden River, more canopy |
| Fort Barnacle | Cracked wall, gate, cannon, turrets | Consequence beyond the walls | + **Harbor chain**: it changes what the Navy can do, for everyone, for 40 s. + Catapult and siege gun. |
| Ember Isle | Geysers, lava, eruption | Discovery | + Second dock under the geysers, the river of fire, the Cinders |
| Frost Spire | The climb, ice slide, avalanche | Improvisation | + Floes and a zipline to them |
| Leviathan's Rest | Spine walk, tentacles | Engagement at sea | + The rib run |
| Skull Rock | Sail into the mouth, ghost fleet | Consequence: no way out if your boat sank | + A skiff in the lagoon; teeth to hide behind |
| Maelstrom Rock | The whirlpool | fine as it is | + A spare skiff |
| Pebble, Coral, Gull, Twin, Smuggler's | Simple | intentionally simple | + Spare boats, two beacons, one hidden lagoon |

**The mechanics I would defend as systemic**, in the prompt's sense of "I wonder if I can use that":

1. **The harbor chain.** Pull the lever and the chain rises for 40 seconds. While it is up, no patrol ship sails from the fort, and the Strongbox's own trouble (two ships at once) waits until it drops. It also stops every other boat, including yours and your rivals'. It was not built for the Strongbox only: in Navy Waters it delays any Heat-driven patrol.
2. **Beacons** (ten of them). Lighting one makes every patrol ship within 1500 studs break off and sail to it for 16 seconds. It is a decoy, a way to pull the Navy onto a rival, or a way to clear the Gate before you run it. 75 second cooldown each.
3. **Shallow water as a place.** The reef's two passes and the whole Western Shelf are marked with green lamps, and the rule is simple and learnable: green means a patrol ship cannot follow. The Navy's route-finding already respected depth; V4 gives the map places where that matters.
4. **Catapults** (three). They throw you a long way on a fixed arc. Dash, air jump or grapple cancels the throw, so the arc is a starting point.
5. **Boat ramps and hoops** are the same parts V2 had at Coral Atoll and the harbor, now used across the sea. Hoops on a lane push whichever way you are already going.

## 7. How the geography uses V3's movement

- **Crags are too tall to jump and are meant to be grappled.** A jump plus an air jump reaches about 15 studs. The new crags are 30 to 70. Each has a ramp as the slow way; the hook (170 studs of reach) is the fast way, and the Shards, Tangle's pillars, the Cinders and Skull Rock's teeth are spaced so one hook reaches the next.
- **Gaps sized for a dash.** The river of fire is 13 studs wide, sized so a plain running jump is not enough and a jump with a dash is. (By arithmetic; not jumped by hand.)
- **Ziplines are the way down** from every crag that has a ramp up, so high ground is a place you pass through at speed, not a dead end.
- **Boats.** Sandbars, reef gaps and stack fields are for drifting through; the Navy slows for all of them. The Gate is 220 studs wide, enough for a full-speed drift.
- **What I did not do:** re-walk the insides of the V3 treasure sites at V3's speeds. That gap from the V3 report is still open.

## 8. Ocean geography and finding your way

- **Wrecker's Reef** runs from Gull Rock to Smuggler's Cove. The crest is 1.2 studs under the surface with rocks and coral showing. **The Gate** (gold lamps, two posts you can grapple, a hoop) is the only deep gap. **Gull Pass** and **Smuggler's Gap** (green lamps) are 3.7 deep.
- **The Western Shelf**: sixteen green lamps ring it. Dry bars inside, one thin enough to jump from the ramp in front of it (the Sandbar Jump).
- **The Teeth** (11 stacks, three perches, a rope bridge that can be blown, kegs, two hoops), **the Cinders** (8, one perch with kegs) and the **Serpent Channel**'s rocks (8).
- **Lone rocks** where the horizon was empty: the Old Man (96 studs tall), Two Sisters, the Anvil (flat-topped, with kegs and a beacon), Lookout Stack, the Chimney, North Pillar, the Widow.
- **Currents:** Home Stream (Crossroads to the Gate), Rushing Strait (Shoals to Crossroads), Temple Drift (north up the Long Reach), Cinder Run (Ember toward Twin Stacks), Northern Drift (Frost to Leviathan's Rest), Mill Race (Windmill into Home Bay), and the Serpent Channel at 28 studs/s.
- **The horizon.** Terrain streams out beyond 2048 studs, and islands are now up to 5000 apart. Each island leaves **a silhouette**: plain blocks buried inside its tall ground, and a pillar inside every crag and stack, in a model that never streams out. Up close they are hidden inside the terrain (each block is checked against the voxels, so none shows in a cave or tunnel). From far away they are the island's shape in haze.

## 9. Economics, Heat and pursuit

All in `src/shared/Config.lua`.

| | V3 | V4 | Why |
| --- | --- | --- | --- |
| Raid length | 420 s | 600 s | The farthest round trip is about three minutes; three should fit |
| Treasure values | 1 to 14 | 1 to 24 | Follows travel time: roughly 2.5 gold a minute near home, 4 to 5 in the middle, 6 to 8 far out, for a goblin alone |
| Interest | +1 per 70 s, up to +3 | 12% of value per 80 s, three steps | A flat +1 meant nothing on a 24-gold prize |
| Heat per second carrying | 0.8 | 0.48 | Trips are 2 to 3 times longer; the same treasure should end its trip at about the same Heat |
| Heat decay | 0.6 | 0.5 | |
| Guardian leash | 300 | 520 | The whole of the bigger temple island |
| Navy sight | 600 | 700 | |
| Fort's waters (ships launch from the fort inside this) | 900 | 1500 | Makes the north-west the Navy's, as a region |
| Ambient storms | one at a time, anywhere, every 95 to 140 s | up to three, every 45 to 75 s, **seeded 700 to 1300 studs from someone at sea and blowing across them** | One storm in a sea this size would never be met |
| Storm radius | 230 to 320 | 300 to 420 | |
| Zipline speed | 90 | 110 | The long lines are 560 studs |
| Boats | 14 | 43 | Every island has at least one; home has seven |

New values, in gold: Golden Gear and Lighthouse Lens 4, Sunken Sextant 4, Captain's Chest 6, Crystal Heart 8, Pearl of the Deep 9, Jade Frog, Tempest Trident and Storm Lantern 10, Castaway's Hoard 11, Admiral's Strongbox and Ember Crown 15, Golden Idol 16, Aurora Gem 20, Leviathan Tooth 21, Skull Chalice 24. The three cheapest (Lost Compass, Giant Pearl, Smuggler's Stash) are unchanged.

**For 4 to 8 players** the changes that matter are the seven boats at home, 19 treasures across seven regions, and clusters that put people in the same water. None of it was tested with more than one player.

## 10. How it is built, and the decisions worth challenging

**Moving the old islands.** `World.lua`'s original builders are written in the coordinates they were first built at. `WorldKit` now has a build offset (`Kit.setShift`): terrain fills, parts and ground raycasts land shifted, and anything a builder leaves in `refs` goes through `Kit.world`. Each original island runs with its own offset. The alternative was rewriting 1,400 lines of hand-placed coordinates. `World.lua` asserts every offset is a multiple of 4 studs, so terrain lands on the same voxels. I checked afterwards that 20 named objects from the old islands were where they should be and that nothing was left at an old position.

**`Landform.lua`** (new) writes natural land from a short description: a list of hills, ridges, mesas and cuts. It replaces nothing; the old shape helpers are still used by the old builders. New land is built **first**, then the island builders lay their own ground on it and carve their own harbors out of it.

**`Outlands.lua`** (new) is the new land and what stands on it, one function per island. **`Seaways.lua`** (new) is everything between islands.

**Decisions and tradeoffs:**

1. **Start-up is slower: about 7 seconds, was 3.** Roughly half is writing terrain and water for a sea 4.6 times the size. The other half is the engine building collision for terrain the first time a raycast touches it, which the sea-depth grid has to do around every island. I cut it from about 11.5 s by recording where builders touched the map and probing only there (the open sea is known to be flat), and by moving the silhouettes to a background task after players are in. Going further would mean reading depths from voxels instead of raycasts, and the two disagree by about two studs (see section 13), which is the difference between a patrol ship passing and not.
2. **The chain blocks everyone.** I considered making it stop only Navy ships. A real barrier is easier to understand, and "I shut the harbor on the boat behind me" is the kind of story the prompt asks for.
3. **The Strongbox's trouble waits for the chain instead of being cancelled.** Cancelled would make the chain the only correct play.
4. **Beacons have no cost except the detour and the cooldown.** If they turn out to be too strong, the first thing to try is making the lighter visible to everyone for a few seconds.
5. **The temple catapult lands on the mesa's west side, not on the ziggurat.** The first version put you 15 studs from the Idol.
6. **Three new treasures.** The prompt did not ask for them. Without them the four new islands are only petrol stations, and 16 treasures across 4.6 times the water is thin for eight players.
7. **Hoops and ramps are placed by hand, by eye.** Nobody has driven most of them (section 12).

## 11. Performance

Measured on Ninety's machine in Studio's play-solo mode, on the server unless stated.

| | V3 (same session, same machine) | V4 |
| --- | --- | --- |
| Start-up, server boot to world ready | 2.9 s | 6.4 to 7.5 s over five runs |
| of which terrain, parts and water | not split out | 3.5 to 4.0 s (new land 1.2, places and sea features 1.0 to 1.4, water 0.5 to 1.4, the old islands 0.1 to 0.2, sea floor 0.2) |
| of which the sea-depth grid | not split out | 3.3 to 3.4 s (25,258 cells, 51,535 raycasts) |
| Generated parts | 2,333 | 4,742 |
| Instances | 48,236 | 51,295 |
| Boats | 14 | 43 (empty boats far from every player are frozen, as in V3) |
| Sea-depth cells | 5,520 | 25,258 |
| Server frame rate, idle | 60.0, worst frame 19.0 ms | 60.0, worst frame 18.3 to 19.5 ms |
| Server script time per frame | 0.76 to 0.90 ms | 0.05 to 0.9 ms |
| The game's own script memory | 3 MB | 5 MB |
| Navy route, longest plausible | 4,893 studs: 9.5 ms | 3,951 studs (fort to home): 9.4 ms. 6,283 studs (fort to Skull Rock): 20.8 ms. Under 1,000 studs: 0.1 to 2.6 ms |
| Horizon | none | 121 blocks plus one pillar per crag, built in the background in 1 to 2 s at 4 ms a frame; the frame rate stayed at 60.0 while it ran |

- **Streaming at speed:** with the server driving a skiff at 104 to 126 studs/s across open sea, the client checked for water under the boat and 300, 600 and 1000 studs ahead, four times a second for 20 s. **308 samples, none missing.**
- **Unattended for 67 minutes** (about six raids and dozens of storms): no errors in the console, 60.0 fps at the end, the game's script memory flat at 5 MB, instance counts flat.
- **Not measured: client frame rate.** Studio's window was in the background, which caps the client at 15 fps (measured: 15.0). A ship route recalculates once a second per ship, so a 20 ms route is a visible hitch only on the very longest chases; I did not see one.
- **One thing I could not explain:** Studio's whole process grew from 2.8 GB to 5.1 GB over those 67 minutes. The game's script memory and instance counts did not grow, the process also showed 4.6 GB in the short V3 run that followed, and Studio reports its editor, plugins, server and client as one number. I did not soak V3 for comparison. Worth a look on a real server before anyone calls it a leak or not.

## 12. Tests performed, and their limits

### Limits that apply to everything below

- **Nobody has played V4.** I can say things work, not that they are fun.
- One AI, one client. Nothing between two players was exercised.
- The client ran at 15 fps the whole time. Boats in these tests were driven by the server with the same physics code, not by a hand on the keys.
- No mobile, gamepad, touch or real-latency test.

### Verified working

- **The world builds** with an empty console on every run (twelve runs).
- **The moved islands:** all 19 treasure spots, the Hoard, the spawn and the Guardian's lair are on their islands; 20 named objects from the old islands are where they should be; nothing was left at an old position.
- **All 43 boats** float in at least 3.2 studs of water at all five points of their hull.
- **Depths match the design** after the fix in section 13: reef crest -1.3, passes -3.6 to -3.8, shelf -4.8.
- **Navy routes:** round the reef through the Gate, never over it; a skiff-draft route goes straight through Gull Pass; no route onto the shelf (a cutter-draft route crosses it); out of the fort's harbor between the moles.
- **The harbor chain:** the lever raises it; a patrol launch is refused while it is up; with it up, stealing the Strongbox sent no ships for 40 s and then two the moment it dropped; with it down, ships left the harbor and reached the west shore in 12 s.
- **A beacon:** the ship within range (about 1,430 studs away) stopped chasing and sailed toward it; the ship out of range (about 1,600) did not.
- **All three catapults**, flown by the test client: Crossroads crag to the acropolis top (on target), Siege Hill over the wall onto the barracks roof (on target), Moon Altar to the temple mesa (40 studs short of the aim point, on the mesa, clear of the ziggurat).
- **All 11 ziplines** have a clear line for a rider (a sphere swept along each).
- **The Guardian** woke on the Idol, came off the mesa, crossed onto the new east jungle past its old leash and knocked the Idol loose.
- **A full loop:** stole the Lens, sailed home through the Gate, banked it (7 gold with interest), ended the raid, and the reset put back the boats, the chain, a lit beacon, Heat, the treasure and the player.
- **The Sandbar Jump:** took off at 102 studs/s, cleared the bar, landed at 77 with no hull damage.
- **A lane hoop** (the Gate's): 102 to 142 studs/s.
- **A storm** was seeded about 800 studs from the test player at sea.
- **Seen on screen for the first time** (V3 could not): the boat panel with its three meters, and the help panel. Both fit. Also the map with the new layout and region names.

### Not verified

- **Walking any of the new land.** I teleported to it. Ramps onto crags, the wading routes, the floes and the perches have not been walked, and no grapple route between stacks has been tried.
- **Riding a zipline.** Only the lines' clearance was checked. Two are 560 studs long.
- **Driving by hand** through the reef passes, the three inlets (Serpent River, Hidden River, the Back Door), the rib run, the Serpent Channel, the Teeth or the Tide Vault ramp. Fifteen of the sixteen new hoops were never crossed.
- **A cutter on the shelf** (only its depth and its route).
- **A patrol ship meeting the raised chain**, standing off outside the Shallows, or in the Serpent Channel.
- **The new guns** (harbor, siege, second wreck), **the river of fire's damage**, and **taking the three new treasures** (their models are in place; none was picked up).
- **More than one storm at once** (the 67-minute run produced about one a minute, which is what the settings should give, but I did not count them at one moment).
- **Scraping over a reef crest.**
- The new values and Heat rates are arithmetic. Whether a far trip *feels* worth 24 gold is a playtest question.

## 13. Bugs found and fixed while testing

1. **Generated ground sat two studs higher than its numbers.** The engine draws and collides a voxel column about two studs above what its fill suggests. Reef crests meant to be under water were sandbars, and the "skiff passes" were 1.8 deep, not 3.7. Fixed in `Landform` (columns are written two studs lower); every depth above was re-measured afterwards.
2. **Patrol ships could not leave the fort.** The first moles left a channel 75 studs wide, narrower than the sea grid can resolve, so ships steered through the harbor wall and ground against it. The moles are now 126 apart.
3. **The shelf let patrol ships in.** It sloped smoothly, so only its middle was shallow enough. It is now flat.
4. **Start-up took 11.5 s.** See section 10.
5. **Three ziplines dragged the rider across the crag they start from, and the Gull Rock line clipped the shore** at its new, shallower angle. Lines now start at the crag's rim; the Gull line ends six studs higher.
6. **A palm tree stood in the Sandbar Jump's flight path.** Boats hit it at the top of the arc. (It took two wrong fixes to notice.)
7. **A ramp built on a sandbar stalls a boat.** A ramp has to stand in open water in front of the bar.
8. **The Tide Vault ramp pointed along its shoal** instead of across it.
9. **The temple catapult landed beside the Idol.** Re-aimed.
10. **The client warned "infinite yield"** waiting for sea data during the longer start-up. It now waits with a timeout.

## 14. Known issues

- **Start-up is about 7 seconds** before anyone spawns.
- **Too many floating names on the horizon** from some viewpoints: island names, sea feature names and current names can stack on top of each other. I shortened the range of the new ones; the island names were already like this in V3 and there are now more islands in view.
- **The shelf does not look shallow from above.** Green lamps and a sign mark it; the water colour does not change.
- **Silhouettes are blocky** and only cover ground taller than about 12 studs, so low islands (Pebble, Kelp, Coral) have none.
- **The new land is plainer than the old.** It has trees, a few props and the features listed; it has no ruins, huts or set dressing.
- **A patrol ship that is already out is not affected by the chain**, and one returning to port while it is up will bump against it until it gives up and leaves.
- **Legacy shape helpers still write heights two studs high** (the old islands always did); only `Landform` is corrected, so the two meet without a visible step but the numbers in the old builders are not literal heights.
- Everything in V3's known limitations still applies (no touch buttons, the Guardian walks through walls, boats pass through dock posts).

## 15. Human playtest instructions

Run **Test > Server & Clients > 4 players > Play** if you can; alone is still useful. Press `H` in the game first.

**Ten minutes alone:**

1. **From the hill behind the Hoard, look north.** Can you tell where things are without the map? Does the horizon look like places to go?
2. **Take a skiff out through the Gate** (gold lamps) to the Crossroads. Did the trip feel like travel or like waiting? Count the seconds if you like: it should be about 12.
3. **Come back through Gull Pass** (green lamps, to the west). Did you find it? Did it feel like a shortcut?
4. **At the Crossroads, climb to the Watch Crag** (north-west, ramp or grapple) and step on the orange catapult. Fun, or just a teleport?
5. **Open the map (`M`).** Do the region names help? Is anything unreadable?

**A real raid, ideally with others:**

6. **Rob the fort two ways.** Once normally. Once after pulling the lever on the west mole (the harbor chain). Did the head start feel earned? Is 40 seconds too generous?
7. **Light a beacon while a patrol ship is hunting someone** (Gull Rock and the Crossroads crag are the easy ones). Did you see the ship turn? Is it too strong?
8. **Take something from the Tide Vault or the Shoals and run for home through the Western Shallows** with the Navy out. Does the ship standing off outside feel fair? Is the maze of bars fun or annoying?
9. **Rob the Sun Temple and leave three ways:** the south dock, the Sun Spire zipline to Pilgrim's Rock, and the hidden skiff at the head of the river inlet on the east side. Which felt best?
10. **Go to one far island** (Skull Rock, Frost Spire or Leviathan's Rest) and come back with its treasure. Was the trip out interesting? Was the trip home tense or just long? Did the gold feel worth it?
11. **Does the world feel alive between islands,** or did you find a stretch of nothing? Where?
12. **With 4 or more: did you meet each other?** Where? Or did everyone sail off alone?
13. **Frame rate** at home, in a stack field, and in a storm. Say what device and settings.

Say what felt bad, and send a screenshot of any red error. Things I could not check and would most like looked at: any ramp or perch you cannot actually reach, any zipline that drops you somewhere stupid, any hoop pointing at a rock, and any boat that spawns aground.

## 16. Recommended next priorities

1. **Play it.** Most of section 12's unverified list is five minutes of a human sailing around.
2. **If far trips feel long rather than tense:** bring the far ring in before adding more to the sea. The layout is one list of numbers in `Archipelago.lua`.
3. **If players never meet:** fewer, richer destinations, or a reason to converge (one very valuable treasure that everyone can see being carried already exists as flares; a single shared event might be worth more than more islands).
4. **Dress the new land.** It is the plainest part of the map.
5. **Touch controls**, still.
6. **The legacy islands' interiors** at V3's movement speeds, still.

## 17. Studio tooling lessons

- **A raycast on terrain nothing has touched makes the engine build that terrain's collision**, about 90 microseconds each the first time. Probing a whole map with raycasts at start-up pays for collision nobody needs. Record where you built and only look there.
- **Terrain surfaces sit about two studs above the height a voxel fill suggests.** Measure with a raycast before trusting a depth.
- **Check a moved world by name and by emptiness:** look for known objects where they should be, and for any part far from every island.
- **Two wrong fixes before the real one** on the Sandbar Jump: when a moving thing loses speed in mid-air, look for something in the air.
- A second helper on another port serving a second checkout made a like-for-like V3 baseline a five-minute job.
- V3's lessons held: no `require` from `execute_luau`; the client is capped at 15 fps in a background window.

## 18. Branch, commits, PR

- Branch `feature/v4-living-archipelago`, created from `origin/feature/v3-speed-agency-danger` at `ee4281c`.
- Pull request: [#12](https://github.com/EnrikR2002/Loot-Goblins/pull/12), base `feature/v3-speed-agency-danger`. **Merge order: #9, #10, #11, then this.**
- **Nothing was merged.** No force-push, no history rewrite. `main` is untouched.
- `./scripts/check.ps1` passes (formatting, lint, Rojo build, whitespace).
- Studio was left in Edit mode with the temporary test scripts removed and `HttpService.HttpEnabled` off. The open place has script edits that are not saved; they are all in this branch.

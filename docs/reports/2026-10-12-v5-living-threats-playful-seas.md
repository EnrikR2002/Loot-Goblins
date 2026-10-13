# Report: V5, living threats and playful seas

| | |
| --- | --- |
| Date | 2026-10-12 |
| Request | Ninety's "V5 One-Shot: Living Threats & Playful Seas" prompt |
| Agent | Claude Code (Opus 5.5), local session on Ninety's machine with Roblox Studio MCP |
| Branch | `feature/v5-living-threats-playful-seas`, **stacked on** PR #12's branch `feature/v4-living-archipelago` (then #11, #10, #9) |
| Pull request | [#13](https://github.com/EnrikR2002/Loot-Goblins/pull/13), base branch is `feature/v4-living-archipelago` |
| Merge status | **Not merged.** Nothing was merged, including PRs #9 to #12. Needs a human playtest and explicit approval. |

## 1. Summary

The V4 playtest said three things: the sea is too spread out, the boost hoops are the best part of sailing, and the islands need things living on them. V5 answers all three.

- **The sea is pulled in.** 5080 x 4390 studs, 55% of V4's area (V3: 3200 x 2740, V4: 6900 x 5840). The near islands kept their distance; everything else came about 30% closer. Islands kept their V4 size and features.
- **Hoops are a system now.** 110 of them (V4: 19) laid out as 16 named runs: easy chains on the main lanes, slaloms through the stack fields, six timed runs with a best time on the sign. Taking hoops in a row builds a chain that kicks harder.
- **Coins.** 326 along the runs, round the rocks and in the air over ramps, picked up by driving through at any speed. Each one shortens the boost cooldown and patches the hull a little. Ten are worth 1 gold at the Hoard, at most 6 gold a raid.
- **Salvage and stunts.** Crates float where a patrol ship sank or a storm blew out. Seven ramps (V4: four) have coins hanging over them.
- **Something different lives on every big island.** Twenty-one creatures of thirteen kinds, built on one shared framework. Each has one rule a player can learn: statues that only move when nobody faces them, a double that retraces your steps, a crab that owns the sand, a ram that charges in straight lines, an eel that owns the water, imps that steal from the thief, marines who throw you over the wall, and more. Section 8 is the roster.
- **Retuned** for the shorter trips: raids 9 minutes, far treasure 13 to 20 gold, Heat a little faster.

Tested in Studio by one AI on one client. **Nobody has played V5**, and nothing between two players was exercised. Section 13 says exactly what was and was not verified.

## 2. How I read the prompt, and what I left out

- "About half of V4's area": I took that as a starting point, as the prompt said, and laid the islands out by travel time. The result is 55%. The near ring was already 6 to 8 seconds from home and I left it there.
- "Do not give every island the Guardian with a different skin": no new creature chases a carrier across its island swinging at them. Most do no damage. What they threaten is the treasure, the route, or the ground under you.
- "Preserve boat agency": boat counts are unchanged (43). No creature destroys a boat. The eel and the fin shove boats without damage; only the Sleeper can hurt a hull, it is announced, and its strikes are 45 hull against a skiff's 160.
- **Not built** (ideas from the prompt I chose to leave):
  - **Target challenges** for cannons. Only the cutter and a few emplacements can shoot, so few players would meet them.
  - **Dolphins or other sea creatures to follow.** I wanted a pod whose wake gives a boost; it did not make the cut.
  - **Dynamic events beyond salvage** (a naval battle to loot, for instance).
  - **A creature for every small island.** Pebble Isle, Gull Rock, Smuggler's Cove, Twin Stacks, the Shallows' Kelp Cay, and the three keys have none. The prompt allowed small islands to stay simple.
- **Changed while building:** the imps moved to the pillars beside the shrine and now react to the theft itself (as first placed, a thief leaving by the zipline never passed one). The Watchers were given the job of carrying treasure back, which I had first planned only for the crab.

## 3. Geography: what moved and what was kept

| | V3 | V4 | V5 |
| --- | --- | --- | --- |
| Sea | 3200 x 2740 | 6900 x 5840 | 5080 x 4390 |
| Area, in millions of square studs | 8.8 | 40.3 | 22.3 |
| Against V4 | 22% | 100% | 55% |

**Kept from V4, unchanged:** every island's size and outlands (headlands, crags, inlets, second docks), the harbor chain, beacons, catapults, ziplines, the three new treasures, the regions and their characters, the horizon silhouettes.

**Moved:** every island except the home ring. Because V4 left island positions as one list (`shared/Archipelago.lua`) and built the old islands with an offset, moving them was a change of numbers.

**Re-laid:** everything in the open sea. V4's reef, shelf, stack fields and currents were written in fixed world coordinates and would all have been in the wrong place. `Seaways.lua` now places each of them from the islands' positions (an offset from an island, or a point between two), so they follow the next time the map moves.

**What changed in character:**

- **The Crossing** is now just outside the Gate. The Crossroads is 10 seconds from home, close enough to be the hub it was meant to be.
- **Western Shallows:** the shelf is smaller (radius 400, was 520) and sits tighter between the Shoals, Kelp Cay and the Tide Vault.
- **Navy Waters:** Tangle Isle and Fort Barnacle are about 290 studs apart at the narrowest. The Serpent Channel is a real strait now.
- **Eastern Reach:** Smuggler's Cove and Windmill Hills are close enough that the water between them is a strait too (the Mill Run goes down it).
- **The Long Reach** between the Crossroads and the temple is 460 studs of water with Pilgrim's Rock in the middle. It is no longer long. The name is still on the map.
- **Lost:** the Home Stream current. With the Crossroads this close to the Gate there was no room for it; a hoop run does its job.

## 4. Distances and travel times

Straight-line seconds from Goblin Cove at a skiff's top speed (108 studs a second).

| Island | V3 | V4 | V5 | V5 as a share of V4 |
| --- | --- | --- | --- | --- |
| Pebble Isle | 3.5 | 6.2 | 5.6 | 91% |
| Gull Rock | 4.1 | 6.2 | 6.2 | 100% |
| Coral Atoll | 4.0 | 7.3 | 6.5 | 90% |
| Smuggler's Cove | 4.3 | 7.7 | 7.7 | 100% |
| Crossroads Ruins | 6.0 | 13.4 | 10.2 | 76% |
| Windmill Hills | 7.0 | 16.4 | 12.6 | 77% |
| Shipwreck Shoals | 8.7 | 19.8 | 14.1 | 71% |
| Kelp Cay | | 20.6 | 15.3 | 74% |
| Twin Stacks | 9.6 | 22.9 | 16.5 | 72% |
| Pilgrim's Rock | | 24.9 | 16.5 | 66% |
| Crystal Isle | 9.2 | 23.3 | 16.7 | 72% |
| Tide Vault | 9.9 | 23.4 | 17.8 | 76% |
| Maelstrom Rock | 13.1 | 28.6 | 20.4 | 71% |
| Tangle Isle | 13.6 | 30.6 | 21.2 | 69% |
| Sun Temple | 12.7 | 30.6 | 21.9 | 71% |
| Ember Isle | 14.5 | 36.8 | 26.3 | 71% |
| Lantern Key | | 38.9 | 27.8 | 71% |
| Fort Barnacle | 13.9 | 40.8 | 29.7 | 73% |
| Leviathan's Rest | 17.6 | 43.5 | 30.2 | 70% |
| Driftwood Key | | 42.7 | 30.4 | 71% |
| Frost Spire | 17.4 | 43.8 | 30.4 | 69% |
| Skull Rock | 19.5 | 48.9 | 34.5 | 70% |

**Measured in Studio:** a skiff driven by the server at full throttle from the harbor mouth to the Crossroads' beach, standing start, taking the Gate Run's hoops: **589 studs in 6.3 seconds**, top speed 159. V4's same trip was 1000 studs in 10.0 seconds. From the docks it is about 8 seconds.

## 5. The hoop runs

`src/server/Searuns.lua`. A run is a chain of hoops along a line someone would want to sail anyway, about 120 studs apart, so each kick carries into the next. Lane hoops push whichever way you are going.

| Run | Kind | Where |
| --- | --- | --- |
| **Bay Circuit** | timed, 10 hoops | A lap of the water inside the reef. The first thing to try. |
| Gate Run | lane | Out of the harbor, through the Gate, to the Crossroads' dock |
| Back Door Arc | lane | Coral Atoll, round the south of home past the Back Door, to Pebble Isle |
| West Run | lane, with a ramp | Gull Pass to the Shipwreck Shoals |
| Mill Run | lane | Smuggler's Gap, round Smuggler's Cove, down the strait to Windmill Hills |
| Reach Run | lane | Pilgrim's Rock to Twin Stacks, north of the Teeth |
| Tangle Lane | lane | The temple's south-west shore to Tangle Isle |
| Ember Reach | lane, with a ramp | Crystal Isle's beach, past the Anvil, to Ember Isle |
| Lantern Line | lane | The mouth of the temple's river, past Two Sisters, to Lantern Key |
| Maelstrom Sling | lane | Round the outside of the whirlpool |
| **Pilgrim's Run** | timed, 7 hoops | The Crossroads' north dock, past Pilgrim's Rock, to the temple |
| **The Teeth** | timed slalom, 7 hoops | Between the sea stacks east of the Crossroads. One hoop per gap; the coins weave. |
| **Serpent Run** | timed, 5 hoops | Down the Serpent Channel with the current |
| **Cinder Slalom** | timed slalom, 5 hoops | Through the basalt stacks toward Ember Isle |
| **Northern Drift** | timed, 7 hoops, with a ramp | Along the top of the map with the current |
| Shelf Hop | stunt | Two hoops, the Sandbar Jump, one hoop |

Plus the two hoops at Leviathan's rib run and the three in Coral Atoll's lagoon from before.

**Chains.** A hoop taken within 4 seconds of the last one kicks 5 studs/s harder, up to four steps (30, 35, 40, 45, 50). The boat panel shows "HOOP CHAIN x3" and the note of the sound climbs. A kick never takes a boat past a ceiling (its boosted top speed plus 6 per link: 151 to 175 for a skiff). I added the ceiling after the first test: five hoops and the Serpent's current reached **257 studs/s**, which is unreadable and above what the server's anti-cheat check allows.

**They are offers, not fences.** Nothing blocks the water beside a run. A lane run goes where the lane already went.

## 6. Coins and what they are worth

`src/server/Coins.lua`.

- **Picking up:** pass within 13 studs in a boat (7 on foot). No button. The server checks where hulls and goblins actually are, 20 times a second, and also half way back to the last check so nothing is skipped at speed. The client hides a coin a moment early so it feels instant; it never claims one.
- **Where:** three between each pair of hoops on a run; bigger coins (worth 5) hugging the stacks in the slaloms, deeper in the whirlpool, on the reef's crest and in the fort's harbor; coins in the air over every ramp; and trails that lead into the Back Door, Smuggler's lagoon, the temple's river, Tangle's hidden river, the skull's mouth and under Leviathan's ribs.
- **What a coin does right now:** half a second off the boat's boost cooldown and 1.5 hull patched. A trail of coins keeps a boat boosting and afloat, which is the real reason to take one.
- **What coins are worth:** ten make 1 gold when you are next at the Hoard. **At most 6 gold a raid**, about one middle treasure. The HUD shows the purse and how much has been paid.
- **Against farming:** the cap; a taken coin comes back after 80 seconds; a timed run pays once a raid; everything resets with the raid. There is no second currency and nothing to spend coins on.

All 326 coins together are worth 426, so one goblin sweeping the entire sea would hit the cap about seven times over. The cap is what keeps treasure the score.

## 7. Runs, ramps and salvage

- **Timed runs** start when a boat passes the hoop at either end and finish at the other, hoops in order. Finishing pays 6 coins once a raid, and 10 more the first time it is done under par. The best time stays on the signs at both ends, with a name, for the rest of the session. Wander off and the run is quietly forgotten.
- **Pars are guesses.** They come from the run's length at a brisk speed. Nobody has driven them by hand. A straight server-driven skiff did the Serpent Run in 3.0 seconds against a par of 4.
- **Ramps:** the harbor jump, Coral's kicker, the Sandbar Jump and the Tide Vault's ramp from before, plus the West Jump, the Anvil Jump and the Drift Jump beside three of the lanes. Each has three coins over the flight, the middle one worth 5.
- **Salvage:** a floating crate with a glow and a label. 8 coins, a powder keg, 60 hull patched and the boost refilled. One appears where a patrol ship sinks, one where a storm blows itself out, and four are set adrift on the runs each raid. 150 seconds each, eight at most.

## 8. The inhabitants

`src/server/Creatures.lua` is the shared machinery; `Bestiary.lua` and `BestiaryMinor.lua` are the creatures; the numbers are in `Config.CREATURES`.

| Island | Who | The rule to learn | What it does to you | What you can do about it |
| --- | --- | --- | --- | --- |
| **Sun Temple** | The Stone Guardian (unchanged from V3) | It pursues carriers; jump the ring | Damage, knocks treasure loose | Outrun it, jump the stomp, leave the island |
| **Crossroads Ruins** | **The Watchers** (4 statues) | They move only while nobody is facing them. Lit eyes mean free to move. | No damage. A touch knocks treasure loose, and a Watcher carries it back to its place. | Face them. Have a friend watch your back. Grab the treasure out of its arms. Sprint: a Watcher does 30 studs/s, which beats a Lens carrier who only runs (25.5) and loses to one who sprints (32). |
| **Crystal Isle** | **The Echo** | A crystal double walks your exact path, 3 seconds behind | 16 damage and treasure loose to whoever it walks into, including a rival on your heels | Never double back. Never stop. Jump over it in the tunnel after the cave-in. |
| **Shipwreck Shoals** | **Old Clacker**, a crab | It travels under sand and shallows. Decks, rock and deep water are not its ground. | A ring warns for 0.85 s, then it comes up: tossed, 10 damage, treasure loose. It reburies treasure left on the sand. | Stay off the sand. Bait it and dash out of the ring. It sits exposed for 4 s afterwards. |
| **Windmill Hills** | **Bramble**, a ram | It charges in a straight line and cannot turn | Tossed a long way, 6 damage. It charges anyone, carrying or not. | Sidestep. Bait it into a cliff (it is dazed). Stand so the toss sends you where you want to go. |
| **Tide Vault** | **The Warden**, an eel | It owns the water. It circles the shallows; after the pearl is taken it hunts whoever is in the water for 30 s. | 12 damage, treasure loose, only in the water | Time its circuit on the way in. On the way out stay on stone: the platform, the columns, the pavilion (grapple between them), or bring the boat to the ramp first. |
| **Tangle Isle** | **The Imps** (2) | A shriek and a marked ring: one is jumping for your treasure and lands in 1.1 s | It takes the treasure and runs across the canopy to a nest in the west | Get off the ring. Or chase it: get close and it drops the treasure and bolts. Left alone for 18 s it puts the treasure back. |
| **Fort Barnacle** | **The Garrison** (2 marines) | The lines on the ground are what a marine can see. Out of the light, you are not there. | A whistle, a charge, and it throws you over the wall. No damage. Treasure stays in the yard. | Stay out of the cone, keep to the walls and roofs (they cannot climb), or use the throw as a way out. |
| **Ember Isle** | **Cinderlings** (3) | They run to where a carrier is going and set fire to it. They never touch you. | Fire on the ground: 8 damage per half second standing in it | Change direction. Stand in the sea and one that follows goes out. |
| **Frost Spire** | **The Chill** | A drifting cold that follows climbers | No damage. Inside it stamina leaks away (6 a second) and none comes back. | Stay ahead of it (it is slower than a run). It attacks the thing you climb with. |
| **Leviathan's Rest** | **The Sleeper** | An eye under the water off the east dock that wakes to the noise of fast boats | Three marked tentacle strikes at the loudest boat (45 hull each) | Slower than 45 makes no noise. Or go fast and straight: the strikes land behind you. |
| **Skull Rock** | **The Captain's shade** | The skull's eyes are lit while he is awake (16 s) and dark while he dozes (9 s). They can be read from the sea. | Nothing by himself | Take the Chalice while the eyes are dark and the ghost fleet is 18 s late |
| **Maelstrom Rock** | **The Maw**, a fin | It circles the whirlpool | Shoves boats along its path. No damage. | Avoid it, or let it push you |
| **Coral Atoll** | **The Clam** | Open 5 s, shut 3 s | Shut on your hand: tossed, 8 damage. The pearl can only be taken while it is open. | Time it |
| **Goblin Cove** | **Gobbo** the dockhand | Friendly | Hands out a powder keg (E), and shouts in the feed when a patrol ship or a storm is near home | |

A blast (a powder keg) stops every creature that can be stopped: Watchers topple for 8 s, the Echo shatters, the crab retreats for 20 s, the ram and the marines are dazed, the eel is stunned, an imp drops what it holds, a cinderling goes out, the Chill scatters.

### How each differs from the Guardian, in one line

The Guardian asks "can you outrun me?" The others ask different questions: *which way are you facing?* (Watchers), *where have you been?* (Echo), *what are you standing on?* (crab, eel), *where will you be in a second?* (ram, imps, cinderlings), *who can see you?* (marines), *how much stamina do you have left?* (the Chill), *how fast are you going?* (the Sleeper), *when do you act?* (the Captain, the clam).

## 9. How they use the world that was already there

- **The Echo and the cave-in.** Taking the Crystal Heart already seals half the tunnel. Now the thief has to turn round in a tunnel with their own double coming up it.
- **The Warden and the flood.** Taking the pearl already slams the gate and floods the vault; the way out is the drain tunnel into the shallows, which is now where the eel hunts. The colonnade and pavilion that were scenery are the safe route.
- **The Imps and the quake.** Taking the Jade Frog already snaps the canopy bridges. An imp that gets the Frog crosses the broken canopy in five seconds; a goblin chasing it has to grapple from pillar to pillar.
- **The Captain and the ghost fleet.** His sleep changes when the existing trouble starts.
- **The Garrison and the fort.** The walls, towers and barracks roofs that were set dressing are now cover and high ground. The catapult from Siege Hill lands a goblin on a barracks roof, above the marines' sight.
- **Old Clacker and the wreck.** The decks and rope bridges are safe ground for a reason now.
- **Rivals.** An Echo hurts whoever walks into it. A Watcher frozen by one goblin's gaze is not chasing another. Bramble tosses anyone. A marine throws out whoever it sees first. None of this was exercised with two players.
- **Treasure that creatures carry stays "loose"** the whole time, so anyone can grab it out of a Watcher's arms or off an imp's nest, and the existing rules (bounds, the Hoard, the grapple) keep working.

## 10. Agency

What I held to, from section 10 of the prompt:

- **No stuns.** Nothing takes control away. The longest loss of control is a toss.
- **No instant kills.** The hardest single hit from a new creature is the Echo's 16. The Sleeper's 24 is a marked area strike.
- **Everything warns.** A ring on the ground (crab, ram, imps, Sleeper), lit eyes (Watchers), lines on the ground (marines), a body you can see coming (eel, fin, Chill, cinderlings), eyes readable from the sea (the Captain).
- **Nothing outruns everything.** The Watchers (30) lose to a sprint and stop for a look. The eel (40) only works in water. The ram (72) cannot turn. The imp can be dodged in 1.1 s.
- **Nothing punishes simply being there**, with two deliberate exceptions: the eel's circuit and Bramble. Both are visible from a long way off, both do little damage, and both are things to play with. If the playtest finds them annoying, making them carrier-only is one condition each.
- **No creature leaves its island.**
- **Boats:** the eel and the fin shove without damage. The Sleeper is the only one that can hurt a hull.

## 11. Treasure, Heat and the economy

| | V4 | V5 | Why |
| --- | --- | --- | --- |
| Raid length | 600 s | 540 s | The farthest round trip is a little over two minutes |
| Heat per second carrying | 0.48 | 0.62 | Trips are 30% shorter; the same treasure should end its trip at about the same Heat |
| Fort's waters | 1500 | 1150 | Scaled with the sea |
| Beacon range | 1500 | 1100 | Scaled with the sea |
| Storms seeded from a player | 700 to 1300 | 600 to 1050 | Scaled with the sea |
| Treasure | 1 to 24 | 1 to 20 | See below |

New values, in gold: Captain's Chest 5, Crystal Heart 7, Pearl of the Deep and Tempest Trident 8, Jade Frog, Storm Lantern and Castaway's Hoard 9, Admiral's Strongbox and Ember Crown 13, Golden Idol 14, Aurora Gem and Leviathan Tooth 17, Skull Chalice 20. The cheaper ones are unchanged.

Values came down less than distances did (about 15% against 30%), because every big island is now harder to leave with its treasure. That is a judgment, not a measurement. **The one I am least sure of:** treasures whose island creature takes the treasure back (Lens, Chest, Frog) may now be worth too little for the trouble, and the three keys' treasures (9 gold, no creature) may be the best deal on the map.

Coins add at most 6 gold a raid per goblin. Boats: unchanged.

## 12. Architecture and performance decisions

- **One creature framework, small behaviors.** `Creatures.lua` gives every creature a body (one anchored root, the rest welded, so moving it is one write), sleep, ground and water queries, walking that follows the ground, player lookups, one way to hurt or shove a player, one way to mark a spot, and the reset, treasure-taken and blast hooks. A creature is a table with `build`, `tick`, `reset`. The seven in `Bestiary.lua` are about 160 lines each, the seven in `BestiaryMinor.lua` about 95.
- **Sleep.** A creature is only ticked while a player is within its wake range of its home, or while it is in the middle of something. With one player at home, 1 of 21 is active.
- **Kinematic, like the Guardian.** Creatures never collide, so they cannot shove treasure off the map or wedge a boat. They answer no raycasts, so a grapple aimed at one goes to the ground behind it.
- **Treasure in a creature's grip** is three small functions in `Loot.lua` (`hold`, `letGo`, `sendHome`) that keep the item in its ordinary "loose" state. I did not add a new state to the treasure state machine.
- **Coins are server parts.** 326 of them. The alternative, drawing them on each client from a list, would save instances and cost a second code path; streaming already keeps a client from holding ones it cannot see.
- **Hoops are eight bars, not sixteen cubes**, because there are a hundred of them.
- **The sea is placed from island positions**, so the next change of layout is a change of numbers.
- **The server decides** every pickup, every run time, every purse payment and everything a creature does. Clients send nothing new: no remote was added.
- **Start-up** is a little quicker than V4 because the sea is smaller.

### Measurements

Same machine and method as the V4 report.

| | V3 | V4 | V5 |
| --- | --- | --- | --- |
| Start-up to world ready | 2.9 s | 6.4 to 7.5 s | 5.7 to 6.8 s |
| Generated parts | 2,333 | 4,742 | 5,677 |
| Instances | 48,236 | 51,295 | 52,397 |
| Sea-depth cells | 5,520 | 25,258 | 13,970 |
| Boats | 14 | 43 | 43 |
| Server, idle | 60.0 fps, 0.8 to 0.9 ms of script a frame | 60.0, 0.05 to 0.9 | 60.0, 0.8 to 0.85 |

- **Every creature ticking at once** (forced, as if a goblin stood on every island): 0.99 ms of script a frame against 0.85 with one awake. 60.0 fps.
- **A demanding scene:** FRENZY Heat, two patrol ships chasing, a storm overhead, all 21 creatures ticking, 4 salvage crates. Over 6 seconds: **59.2 fps mean, 8 frames over 20 ms, worst frame 56 ms**, 1.21 ms of script a frame. The spike is at the moment the ships are created.
- **The game's script memory:** 6 to 7 MB.
- **Client frame rate: not measured.** Studio's window was in the background again, which caps the client at 15 fps (measured: 15.0).
- **A thing to watch on weaker devices:** with the islands closer, more of the world sits inside the streaming radius. A client standing at the Crossroads held about 7,500 instances of the world. I did not take the same reading in V4, so I cannot say how much more that is, and I have no frame-rate number to go with it.

## 13. Tests performed, and their limits

### Limits that apply to everything below

- **Nobody has played V5.** I can say things work as written, not that they are fun or fair.
- **One AI, one client.** Nothing between two players was exercised: no Watcher held by one goblin while it chased another, no Echo hurting a rival, no coin taken by two boats at once.
- The client ran at 15 fps. Creatures were tested by teleporting a goblin to them and standing still or facing a direction; **no creature has faced a moving, dodging player.**
- No mobile, gamepad, touch or real-latency test.

### Verified working

- **The world** built with an empty console on every run (about fifteen), and after each change of layout the machine checks passed: all 19 treasure spots and the Hoard on their islands, all 43 boats over at least 3.2 studs of water, all 11 ziplines clear, no hoop over land.
- **A full loop:** stole the Lost Compass, banked it (+1 gold), raid end, reset.
- **Hoops:** a server-driven skiff on the Gate Run reached 164 before the ceiling and 159 after; on the Serpent Run 257 before and 177 after. A **client-driven** skiff (the W key held, the driver's own physics) took the Gate Run: the chain showed, coins were collected (45 in the purse), no errors.
- **A timed run:** the Serpent Run started, finished, paid 16 coins and wrote the best time (3.0 s) and the driver's name on its sign.
- **The purse:** 28 coins became 2 gold at the Hoard. **Salvage:** a crate gave coins and a keg. **Reset:** every coin back, purse empty, four crates adrift.
- **The Sandbar Jump** still works at its new place (checked by depth and position, not re-flown after the move).
- **Watchers:** advanced at 30 studs/s with the goblin's back turned, stopped dead when faced, knocked the Lens loose, and another carried it back to the lighthouse in 7 s.
- **Echo:** reached a goblin who stood still 3.0 s after the theft and hit for 16.
- **Old Clacker:** came under the sand, warned, came up, tossed for 10. The first toss did not loosen the Chest (the usual 1.5 s of protection after a grab); the second did, and it reburied the Chest within 8 s.
- **Bramble:** 0.9 s of warning, charged, tossed the goblin about 50 studs into the sea, stopped at the water's edge.
- **The Warden:** shocked a goblin standing on its circuit twice as it passed (11 each). After the pearl was taken it left its circuit, crossed the shallows at 40 studs/s and shocked the thief; the pearl dropped.
- **Imps:** on the theft one leapt in 1.1 s, took the Frog, reached the nest in 5 s across seven perches, and dropped the Frog when the goblin arrived at the nest.
- **Garrison:** a marine saw the goblin in its cone, whistled, and threw them over the south wall into the harbor.
- **Cinderlings:** ran to within 11 studs of a carrier and laid 33 patches of fire in 5 s without touching them; went home when the carrier left.
- **The Chill:** stamina fell at 6 a second inside it.
- **The Sleeper:** awareness rose with a skiff at 104 studs/s, struck at full, and the strikes missed the boat. A boat left circling near it earlier was later found at 54 of 160 hull.
- **The Captain:** with the eyes dark, the Chalice was taken and the ghost ships appeared 18 s later.
- **The Maw** shoved a parked skiff. **The Clam** shut on a goblin and tossed them; opened again after 3 s.
- **A blast on each of nine creatures**: no errors, and each reacted as written.

### Not verified

- **Anything with two players**, as above.
- **Any creature against a player who moves.** In particular whether the Watchers can be outrun, whether the imp's ring can be dodged in 1.1 s, whether Bramble's line can be read, whether the cinderlings actually cut a runner off.
- **Driving the runs by hand**, apart from holding W up the Gate Run. The slaloms, the Bay Circuit and every par are untested.
- **Gobbo's** keg and his warnings. **Bramble's temper** after the Gear is taken. **A cinderling going out in the sea.** **The Captain awake** (the ordinary case: the fleet rises at once, as in V4).
- **Salvage from a sunk patrol ship or a spent storm** (the crate itself was tested; the two events that drop one were not made to happen).
- **A coin coming back after 80 s.** **The 6-gold cap being reached.**
- **Client frame rate.**
- V4's unverified list (walking the new land, riding ziplines, the inlets) is still open, and the islands have moved since.

## 14. Bugs found and fixed while testing

1. **A hoop chain reached 257 studs/s.** Kicks now stop at a ceiling.
2. **A walker never arrived.** A creature closing on its stopping distance crept toward it for ever (floating point), so the first Watcher stood beside the lighthouse holding the Lens and never put it back. One small margin.
3. **The imps never met a thief.** See section 2.
4. **The Chill did nothing.** Stamina came back faster than it leaked.
5. **The Captain's clock stopped when nobody was near**, so the eyes flipped the moment someone arrived. It now runs by the clock.
6. **Bramble charged at swimmers** and stopped at the water's edge, again and again.
7. **Pilgrim's Run went over Pilgrim's Rock's beach and dock.** Re-routed past its west side. (The builder now warns about any hoop over water too shallow for a skiff, and Main prints the warnings.)
8. **A zipline ended in the hill it lands on** after the move. Its end is higher.
9. **A marine's patrol went through the south wall** (a slip in its route numbers).
10. **A text splice doubled the island list** while I was moving the islands. Caught at once; mentioned because the fix was to stop splicing by hand.

## 15. Known issues

- **The pars are guesses**, and so are most creature numbers. Expect to change them after one session.
- **Creatures are kinematic.** They walk through walls and props (a marine goes through a barracks), and a Watcher will climb the outside of the lighthouse to put the Lens back.
- **Creatures are blocky.** They are a few parts each.
- **The coin and hoop count** adds about 900 parts to the world.
- **Old Clacker will not follow treasure into the water**, so a Chest dropped in the lagoon is safe from it.
- **Gobbo stands a little above the ground.**
- **The map's region names** are placed by hand and "THE LONG REACH" no longer describes its water.
- **Floating names on the horizon** stack more than they did in V4, because more of the world is in view.
- Everything in V4's known issues that was not about distance still applies.

## 16. Human playtest instructions

Run **Test > Server & Clients > 4 players > Play** if you can. Press `H` first: the help panel mentions hoops, coins and the islands' inhabitants.

**Alone, ten minutes:**

1. **Sail the Bay Circuit** (orange hoops just outside the harbor). Is chaining hoops fun? Is the top speed still controllable? What time did you get against the par?
2. **Take the Gate Run to the Crossroads.** Is 10 seconds the right distance now? Too close?
3. **Collect coins on the way.** Does picking them up feel instant? Do you care about them? Go home with ten or more and stand on the Hoard.
4. **Try one slalom** (the Teeth, east of the Crossroads). Fair, or do you just hit rocks?
5. **Look for a salvage crate** (a glowing box with a label).

**The islands, one at a time. For each: could you tell what the thing was doing, and did knowing help?**

6. **Crossroads:** take the Lens and come down. Watch the statues. Turn your back, then turn round.
7. **Crystal Isle:** take the Heart and leave through the tunnel. Then try doubling back.
8. **Shipwreck Shoals:** take the Chest and cross the sand. Then try staying on the wreck and the bridges.
9. **Windmill Hills:** walk into the west meadow.
10. **Tide Vault:** wade in, take the pearl, and get out without touching the water.
11. **Tangle Isle:** take the Frog. Dodge the imp, or chase it.
12. **Fort Barnacle:** get to the keep without being seen. Then get seen on purpose.
13. **Ember Isle, Frost Spire:** take the treasure and come down.
14. **Leviathan's Rest:** sail to the east dock slowly, then fast.
15. **Skull Rock:** watch the eyes from the sea before you go in.

**With others:**

16. **Did you meet each other more than in V4?** Where?
17. **Use a creature on a rival.** Lead someone into your Echo. Let a Watcher have someone else's treasure and take it from its arms. Get Bramble to toss them.
18. **Race a timed run** and beat each other's time on the sign.
19. **Frame rate** at the Crossroads, where the most is in view. Say what device.

**What I most want to know:** which creature was the best and which was just annoying; whether any island is now not worth robbing; whether coins matter; and whether the sea is the right size.

## 17. Recommended next priorities

1. **Play it and cut.** Thirteen kinds of creature in one pass will not all be good. Keep the three or four that make people laugh or swear, and spend the next pass making those deeper.
2. **Tune the pars and the creature numbers** from real play.
3. **Two-player behavior** of the Watchers and the Echo, which is where I expect the best stories and have tested nothing.
4. **Check the treasure values** against section 11's worry.
5. **A creature each for the keys**, if the keys turn out to be free money.
6. **Client performance** at the Crossroads on a weak device.
7. Still open from before: touch controls; the insides of the old treasure sites at V3's speeds.

## 18. Branch, commits, PR

- Branch `feature/v5-living-threats-playful-seas`, created from `origin/feature/v4-living-archipelago` at `ec120e9`.
- Pull request: [#13](https://github.com/EnrikR2002/Loot-Goblins/pull/13), base `feature/v4-living-archipelago`. **Merge order: #9, #10, #11, #12, then this.**
- **Nothing was merged.** No force-push, no history rewrite. `main` is untouched.
- `./scripts/check.ps1` passes (formatting, lint, Rojo build, whitespace).
- Studio was left in Edit mode with the temporary test scripts removed and `HttpService.HttpEnabled` off. The open place has script edits that are not saved; they are all in this branch.

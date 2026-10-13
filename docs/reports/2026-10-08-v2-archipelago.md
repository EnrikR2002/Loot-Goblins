# Report: V2, the archipelago

| | |
| --- | --- |
| Date | 2026-10-08 |
| Request | Ninety's "V2 One-Shot Development" prompt, run by Claude Code on Enrik's machine because Ninety ran out of usage |
| Agent | Claude Code (Sonnet 5.5), local session with Roblox Studio MCP |
| Branch | `feature/v2-archipelago`, **stacked on** PR #9's branch `claude/sprinting-grapple-map-expansion-japzs8` |
| Pull request | [#10](https://github.com/EnrikR2002/Loot-Goblins/pull/10), base branch is PR #9's |
| Merge status | **Not merged.** Needs a human multiplayer playtest and explicit approval. |

## 1. Summary

The prompt asked for a much bigger, more physical, more dynamic game. What got built:

- **19 islands** (Goblin Cove plus 18) in three rings, spread over roughly 3,200 × 2,700 studs. Every island has its own silhouette, a couple of ways up or in, and at least one thing to interact with.
- **A physical sea.** Boats float on three crossing wave trains, are carried by currents (two straits and a whirlpool), and run into storm cells that cross the map. The visible Terrain water is only the surface; the waves are maths (`Sea.lua`).
- **Rebuilt boats.** Server-owned physics hulls with buoyancy, banking, drift, crashes, hull health, sinking, anchors, boost hoops, kicker ramps, and weight from the treasure you carry. Three types: skiff, cutter (cannon, three seats), and the AI Navy ship.
- **A real "get out" phase.** Heat now changes what the world does. ALERT: flares everyone sees. HUNTED: Navy patrol ships sail for the carrier and shell it from a standoff. FRENZY: a tempest steers at the thief and the sea runs rough. The Guardian leaps and throws boulders, always from a marked circle.
- **Sixteen treasures, each with its own trouble** (flooding vault, snapping bridges, lava bombs, tentacles, ghost ships...). Value rises with distance and danger. Treasure nobody takes grows more valuable.
- **Interactive islands.** Cracked walls, rope bridges, powder barrels, cannons, kegs, levers, gates, geysers, spinning windmill sails, lava. Destruction is selective: only pieces that matter to routes or fights break, and everything rebuilds each raid.
- **A home area worth messing around in.** Bounce pads, a practice cannon with floating bullseye rafts, keg crates, barrels and a harbor jump.
- **Readability.** A one-line objective that says what the world is doing to you, a compass strip, a world map (`M`), storm warnings with direction and distance, and a closing ring marker before every dangerous hit.

**Honest status:** all of this was tested by one AI on one client in Studio. Nobody has played it with other humans. Section 8 lists what was and was not exercised, and section 10 is the checklist for real players. I think the systems work. I do not know if it is fun.

## 2. How I read the prompt, and what I did not do

- **Sprint and grapple.** The prompt asks for sprinting and stamina. PR #9 already has both, plus the grapple, and Ninety had not tried them. Per Enrik's instruction I kept ours and did not re-add his versions. Stamina is reused for the new carrier swing.
- **Branch and PR.** `AGENTS.md` says PRs target `main`. PR #9 is not merged and V2 builds on its map and movement, so I stacked V2 on its branch. **Merge PR #9 first** (or retarget this PR to `main` after it merges). This is a deviation from the written workflow, chosen on purpose; tell me if you'd rather have it another way.
- **Scope.** No progression, shops, pets, monetization, rarity tables or trading. Prototype code is still ugly in places; no new framework or networking strategy.

## 3. What changed, by area

### 3.1 Map: the archipelago

`src/shared/Archipelago.lua` is the single island list (id, name, position, radius, ring, colour). The server builds terrain from it; the client's map, compass and signs read it.

| Ring | Islands | Feel |
| --- | --- | --- |
| Home | Goblin Cove | Safe ward, the Hoard, docks, toys |
| 1: near | Pebble Isle, Coral Atoll, Gull Rock, Smuggler's Cove | A short ride; cheap treasure (1–2 g); learn the sea |
| 2: middle | Windmill Hills, Crossroads Ruins, Shipwreck Shoals, Crystal Isle, Tide Vault, Twin Stacks, Tangle Isle, Maelstrom Rock | Real trips, real mechanisms (3–6 g) |
| 3: far | Fort Barnacle, Sun Temple, Ember Isle, Frost Spire, Leviathan's Rest, Skull Rock | Long, dangerous, valuable (7–14 g) |

Highlights: Windmill Hills has working sails that sweep the balcony holding the Golden Gear. Tide Vault is a lever-gated vault that floods when the treasure is taken, with a drain tunnel as the back door. Fort Barnacle has a cannon wall and a Navy base. Ember Isle is a crater with stepping stones over lava. Frost Spire is three glacier peaks with a slippery ice band and an ice tunnel. Leviathan's Rest is a whale skeleton with ribs arching over a high spine walkway. Skull Rock is a giant skull you can sail into through its mouth channel. The Maelstrom is a treasure inside a whirlpool.

Islands have multiple landing points, caves or tunnels, ruins and wrecks. `Kit.dock` places boats at docks so most mid and far islands have a way back.

Files: `World.lua` (environment, home, original islands), `Islands.lua` (new near and middle islands), `IslandsFar.lua` (far ring), `WorldKit.lua` (shared builders). The split exists to keep each file readable; `World.lua` no longer holds everything.

### 3.2 The ocean

- `Sea.lua`: `waveAt`, `currentAt`, `stormAt`, `shelterAt`. Waves are calmer in the lee of land (shelter) and grow in storms. A global `Sea.rough` raises them during FRENZY.
- Currents: the Rushing Strait and the Home Stream (chevrons on the water show the direction), and the Maelstrom whirlpool (strongest at mid-radius, calm in the eye). Currents are shortcuts if you read them and traps if you do not.
- `SeaNav.lua`: a 40-stud grid built from the finished terrain (depth, distance to land, A* with a draft check and string pulling). Navy ships use it; so can any future AI.
- `Storms.lua`: moving cells with rough water, wind and marked lightning (1.3 s ahead). Ambient storms start after 50 s of calm, then come every 95–140 s and cross the map slowly (9–16 studs/s versus a boat's 56–72), so you can always outrun one. Storm data is one string attribute. The client (`Weather.lua`) draws cloud walls, fog and rain from it and warns with direction and distance.
- Quiet is preserved on purpose: calm water hugs coasts, there is a gap between ambient storms, and the first 50 s of a raid are clear.

### 3.3 Boats

`Boats.lua` was rewritten. Server-owned physics, per boat:

- Buoyancy springs at six hull points toward the wave surface, so boats pitch and heave on swells and can leave the water.
- Thrust only while wet; an arcade keel redirects sideways drift instead of braking; banking into turns (`lean` 38/22/14 for skiff/cutter/navy); an upright assist so a boat recovers from tipping; drag toward the water's own flow.
- Crashes are measured as an unexplained horizontal speed change, with a minimum, a per-hit cap of half the hull and a short grace period. Hull health 150 (skiff), 380 (cutter), 460 (navy). At zero the boat ejects everyone, sinks (7 s), and respawns at its dock after 22 s.
- Strategy: unoccupied boats drift unless anchored (`R` at the winch); empty boats far from every player go to sleep; carried treasure adds drag so a rich cargo is slower; **anyone can drive any boat**, so parking, abandoning and stealing all matter. Boost (`Shift`, 2.2 s, 7 s cooldown) and kicker ramps are for escapes and shortcuts.
- Four boats wait at Goblin Cove (three skiffs and a cutter) and the Crossroads hub keeps a cutter. 14 boats at the start of a raid.

### 3.4 Getting out: Heat, Escalation, the Guardian

- `Heat.lua` tiers are unchanged (CALM, ALERT 25, HUNTED 50, FRENZY 80), but carry heat now scales with the treasure's own heat value, so a cheap trinket stays quiet and a deep treasure escalates fast.
- `Escalation.lua` is new and owns what each tier does (table in `AI_CONTEXT.md`). Dropping a tier stands the Navy down. Everything is answerable: patrol ships lose you behind islands or in shallows, the tempest is slower than any boat, flares reveal where you are rather than where you are heading, and carriers inside the Hoard ward cannot be targeted.
- `Navy.lua`: AI ships use `SeaNav` routes, see only with a clear line (range 520, shorter in storms), hold at 95 studs and shell the carrier. Each shell lands where a marker closes in over 1.7 s. They search your last known position for 22 s, then leave. They can be sunk by cannons, barrels, ramming or lightning.
- The Guardian now leaps to a marked circle and throws boulders at marked circles, with a grace period after waking. It remains a kinematic golem.
- `Troubles.lua`: one trouble per treasure, plugged into `Threats.handlers`.
- **Plan A fails, Plan B possible:** when a bridge snaps, a tunnel is sealed or a gate slams, there is always another way (drain tunnel, a friend on the lever, a keg for a cracked wall, a boat waiting at a different dock).

### 3.5 Treasure economics

- Value tracks distance, travel time and difficulty: 1 g (Compass, ~250 studs away) up to 14 g (Skull Chalice, ~2,100 studs from home, with fog and ghost ships).
- Weight, carry speed and heat rise with value, and so does the trouble, so rich treasure costs time, exposure and risk.
- **Interest:** untaken treasure gains +1 g per 80 s, max +3, shown in the HUD treasure board. This creates opportunity cost and competition for treasure everyone has been avoiding.
- Designed for 4–8 player lobbies. Nothing here has been tried with more than one player.

### 3.6 Interactive islands

- **Blast** (`Blast.lua`): every explosion goes through one function: players, boats, loose treasure, destructibles. `Blast.strike` shows a marker first. The owner of a blast takes half the shove and no damage, so a keg at your feet is a launcher, not a suicide.
- **Destructibles**: cracked walls (any blast), gates (cannonballs), rope bridges (blasts or quakes), powder barrels (chain reactions).
- **Cannons**: island emplacements and the cutter. The client says "fire at this point"; the server checks range, cooldown and aim, solves the arc and flies the ball with its own gravity.
- **Kegs** (`G`): carried from crates, thrown, fuse 2 s.
- **Mechanisms**: sweeping windmill sails, levers and gates, lava that burns, geysers (animated and launched from timestamps on the client, so the server does nothing per frame).

### 3.7 Movement and combat

- Sprint and stamina: kept from PR #9, unchanged.
- **Carriers can now swing the sword**, but only slowly, short (range 6), for less damage (12), and each swing costs 22 stamina. The trade-off: a carrier can defend themselves from a lone chaser, but not stand and fight a group, and swinging leaves them winded. I think this is better than a total ban because it keeps the chase from feeling hopeless.
- The interference toolkit is small on purpose: sword, grapple, kegs, cannons, and the boats themselves. Poltergoblin is untouched.

### 3.8 Onboarding and readability

- One objective line at the top that changes with your situation (home, sailing, carrying and what is hunting you, spirit form).
- Compass strip, `M` map, island signs visible from afar, storm warnings, closing-ring markers for every incoming hit, heat-tier hints, a boat panel (speed, hull, boost, anchor, cargo drag), and the `H` help panel.
- Mobile and gamepad: prompts and sword work; grapple, throw, keg, cannon and Poltergoblin are keyboard and mouse only.

## 4. Architecture

No new framework, dependency or networking strategy. Same plain modules, same single Heartbeat in `Main.server.lua`, same attribute-based replication. New modules and the require order are in `AI_CONTEXT.md`. Builders describe mechanisms in `refs` and mechanism modules run them, so a map change never touches game logic.

Authority: the server owns boats, blasts, damage, cannon/keg counts, gates, treasure, scores, Heat and every threat. Clients send intent (boost, fire at P, throw at P, grapple aim) and the server validates range, cooldown and finiteness. The only client-driven motion is geyser and pad launches, walking, ziplines and the grapple pull toward a server-chosen anchor, which are unchanged or purely cosmetic for scoring.

`default.project.json` now turns on `StreamingEnabled` (min radius 256, target 2048). Loot models, island signs and the Hoard marker are persistent.

## 5. Decisions worth challenging

| Decision | Why | Cost |
| --- | --- | --- |
| Boats are server-owned physics | Everyone sees the same boat; crashes and damage are authoritative; stealing boats works | Driver input latency (untested with real latency) |
| Wave maths separate from the Terrain water | Cheap, deterministic, tunable | Water visuals do not exactly match the wave heights |
| The Guardian is kinematic | Cannot push loot off the map or get stuck | It walks through walls and cannot follow into tunnels |
| Carrier sword is allowed but weak | Carriers should not be helpless | A small balance risk if carriers can still swing too well |
| Heat scales with treasure heat | Cheap loot should stay quiet | One more number to tune |
| All sounds are Roblox's built-in ones | No uploaded assets or permissions | Sounds are pitched copies of a handful of clips |
| Stacked PR | V2 needs PR #9 | PR #9 must merge first |

## 6. Performance (measured vs estimated)

Measured in Studio, play mode, one client, on Enrik's development machine (Studio itself uses 2+ GB, so memory figures are not a game budget):

| Metric | Result |
| --- | --- |
| Server frame, average / worst over the sample | 16.67 ms (60 fps) / 20.3 ms |
| Heartbeat time reported by Stats | about 0.14 ms |
| Physics step rate | 60 Hz |
| Boats during the sample | 17 in total: 8 awake, 9 asleep |
| Client FPS | 60.2 with streaming on |
| Instances in the data model | about 48,000 (server) and 51,000 (client) |
| Generated server parts | about 2,200 (terrain is separate) |
| Parts streamed in on the client | about 2,060 around the player |

Estimates and unknowns (not measured):

- **Mobile and low-end hardware:** not tested. I make no claim. The risk areas are the six-point buoyancy per boat, the amount of terrain, and the weather effects.
- **Many players:** untested. Server cost grows with the number of awake boats and Navy ships. Sleeping empty boats exists to cap this.
- **Network:** boats replicate through normal physics ownership. Behaviour at 100+ ms latency is unknown.
- **Streaming:** the far islands appear as you approach. It looked fine on one machine; the first impression for a client with a slow connection is unknown.
- **Memory on a real client:** unknown.

## 7. Studio tooling lessons

These cost real time, so they are in `AI_CONTEXT.md` and `WORKSTATION.md`:

- The Rojo plugin drops its connection every play cycle, and Rojo 7.7.1 can crash when a watched file vanishes mid-write. I ran Rojo under a restart loop and re-verified script source length after each cycle. Once, an old script ran because sync had not happened.
- A sleeping display stalls Studio rendering and screenshots.
- `require()` from the MCP `execute_luau` returns a separate module copy, so deep tests need a temporary script inside the game (never committed).
- Teleporting 1,000+ studs can drop a character through not-yet-loaded terrain. That is a test artifact.

## 8. Tests performed

Everything below was one AI on one client, using Studio MCP.

**Verified working**
- World builds without errors; console clean after the final changes; selene and stylua clean; `check.ps1` passes.
- Boats: float, steer, bank, accelerate, boost, hit ramps and kickers, crash, lose health, sink, respawn; drift when empty; anchor state; sleep of far empty boats; sit only through the E prompt (seats are not touch-activated); cutter at the home and Crossroads docks with a working cannon.
- Sea: waves move boats; currents carry boats; storms spawn, move, show on the client and strike marked lightning (lightning also wrecked idle docked boats in a test storm, which is the intended behaviour).
- Heat: tiers rise and fall; flares fire at ALERT; Navy ships launch at HUNTED, navigate, see, shell with markers and lose targets; the tempest spawns at FRENZY.
- Full run: boarded a boat, auto-piloted to Pebble Isle, stole the Compass with the real prompt, sailed home, walked into the Hoard and banked it (the gold included interest). Died while carrying: treasure dropped, player respawned at home.
- Cannons (island and cutter), kegs, barrels, cracked walls, gates, rope bridges, geysers, lava, levers, the flood, the sealed tunnel, the Guardian's leap and boulder markers, per-treasure troubles on several islands.
- Windmill sails rotate (a spar moved 21 studs in 1.5 s).

**Not verified**
- **Any multiplayer behaviour**: stealing from another player, carrier swings against a real chaser, grapple robberies, Navy targeting two carriers, shared storms, steal immunity between humans, boat theft.
- **Windmill blades hitting a player** (the one attempt put the character inside the mill geometry, so it proved nothing).
- The Frost Spire ice slide, anchoring in a real current, and lightning damage to a player.
- Any touch or gamepad play, mobile, low-end hardware, and real network latency.
- Whether the economics (values, distances, interest) feel right. I only know they function.

## 9. Known issues and limits

- Boats beach hard against vertical sand edges and pass through dock posts.
- The Guardian walks through walls and cannot follow into tunnels.
- Primitive art; the skull, ribs and fort are blocky.
- Grapple, throw, keg, cannon and Poltergoblin have no touch or gamepad controls.
- Boat crash damage and the drift/grip numbers took several tuning rounds in Studio and have never been felt by a second person.
- Island routes (ladders, ramps, tunnels, ziplines) were not walked end to end systematically. Expect a few awkward or unreachable spots.

## 10. Human playtest checklist

Run **Test > Server & Clients > 4 players > Play** (or Ethan, Ninety and Enrik on three machines through Team Test). Report what felt bad, and send a screenshot of any red error.

**Sea and boats**
1. Board a skiff and a cutter. Does steering feel good, or twitchy or sluggish? Does leaning into a turn feel good?
2. Sail into a wave swell and a storm. Can you read which way a current pushes you? Does a storm feel like a threat you can see coming and avoid, or random punishment?
3. Crash into a beach, a rock and another boat. Is the damage fair? Does sinking feel like a consequence or a gotcha?
4. Anchor a boat in the Home Stream. Does it hold? Take someone else's boat. Does stealing or abandoning boats become part of your plans?
5. Ride a kicker ramp and a boost hoop. Fun, or a gimmick?

**Treasure and escape**
6. Which islands did you choose first, and why? Did anyone head for the 10+ g treasure in the first 2 minutes? Was the near ring too easy and the far ring too hard?
7. Take a mid-ring treasure. Did the trouble read clearly before it hurt you? Could you escape it without luck?
8. Carry treasure out. Did the flare, the Navy, and the tempest each change what you did, or was it just noise? Did the carrier-sword trade-off feel right?
9. Hide from a patrol ship behind an island. Did it lose you? Did the Guardian's leap and boulders feel fair?
10. Rob another player at sea. Is it fun for both sides? Does a rich carrier feel hunted by players or only by AI?

**Pace and readability**
11. Did anyone get lost or not know what to do? Was the objective line, compass, map, or `H` panel the thing that helped?
12. Was there a quiet moment worth keeping? Did travel ever feel like waiting?
13. Does a full 8-minute raid feel right? Does interest on abandoned treasure pull people in?
14. Join late, die while carrying, leave while carrying, and let the raid end with someone mid-sea. Does everything reset?

**Performance** (note device and settings)
15. Frame rate near the volcano, the Fort in a Navy fight, and in a storm. Any streaming pop-in that confuses navigation?

## 11. Observations and recommendations

- Treat boat handling and Heat escalation as the make-or-break systems. If the first boat ride is not fun, nothing else matters.
- Before tuning anything, find out what the loop does with real players. If people ignore the far ring, lower the distance or raise rewards; if they all dogpile one treasure, add a second one of the same value.
- Candidate follow-ups, only if the playtest supports them: wedge beaches so boats can run up a shore, Guardian pathfinding into tunnels, touch and gamepad controls for abilities, and a performance pass on a real mobile device.
- Not recommended yet: progression, shops, larger lobbies, or more islands.

## 12. Branch, commits, PR

- Branch: `feature/v2-archipelago`, based on PR #9's branch (itself from `origin/main` at `84b762a`).
- Commits: `5ce2bdc` (V2) and `7843a5f` (tuning after Studio testing), plus the docs commit that adds this report.
- The diff against PR #9 is large (about 34 files). It is mostly new modules; the existing systems changed in `Boats`, `Loot`, `Heat`, `Threats`, `Combat`, `Movement` (small hooks), `Raid` (resets), `Main`, `Hud`, `Effects` and `Config`.
- Merge: **do not merge** until PR #9 is approved and a human playtest of this branch has passed.
- Studio state at handoff: play mode stopped; a temporary debug script exists only in the AI's Studio session and was never committed.

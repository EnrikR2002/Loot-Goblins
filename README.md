# Loot Goblins — V5 prototype: living threats and playful seas

An intentionally ugly Roblox prototype. It grew from Test 001 (one idol, one boat) into a **big physical sea**: a 19-island archipelago to explore, boats that float on real waves, storms and currents to read, and treasure that fights back on the way home. V3 made the goblin and the boats fast and expressive (dash, air jump, drift), and made the world able to keep up (a Navy that cuts you off, a Guardian you have to jump, storms with waterspouts). V4 makes the world big enough for them: a sea 4.6 times the size, laid out in regions, with bigger islands, reefs, shallows, stack fields and currents between them, and new things to use (a harbor chain, signal beacons, catapults). V5 pulls that sea in to about half the area (the islands keep their size), turns the boost hoops into runs to chain and race, scatters coins and salvage on the water, and puts **something different living on every big island**.

**Explore the sea → steal valuable treasure → the world reacts → escape across dangerous water → bank it at home → go again.**

The question it answers: **is going out into a huge sea, stealing something valuable, and desperately getting it home fun enough that people want another raid?**

## Play it (no terminal needed)

1. Open the Loot Goblins folder on your computer.
2. Double-click **Play Loot Goblins** (the file ending in `.bat`).
3. Wait. It gets the newest version, builds the game, and opens Roblox Studio. If Loot Goblins is already open in Studio, close that window first (other games can stay open).
4. In Studio, press the blue **Play** button at the top. The sky stays blank until you press it.
5. Press `H` in the game to read how to play.

To test with friends on one computer: **Test tab > Server & Clients > 3 players > blue Play**.

To try someone's new changes, ask your AI helper: **"Update me to the newest version of [the branch or PR name] and open the game."** The AI does the Git work and tells you what to try.

## Get set up (once per computer)

Ethan, Ninety, and Enrik use [one shared repository](https://github.com/EnrikR2002/Loot-Goblins), [AGENTS.md](AGENTS.md), and pinned tools.

**Give your Codex or Claude Code the [teammate setup prompt](docs/TEAM_SETUP_PROMPT.md).** It uses the existing setup, installs missing prerequisites, and verifies the connection to Studio. The [workstation guide](docs/WORKSTATION.md) has detailed onboarding, task, approval, and handoff instructions.

These are the Windows helpers the AI operates:

```powershell
./scripts/bootstrap.ps1
./scripts/dev.ps1 -OpenStudio
./scripts/check.ps1
```

The development place in `build/` is generated from this repository. Players only need `Play Loot Goblins.bat`. The AI uses `dev.ps1` and the official Rojo plugin (`localhost:34872`) when editing code. The blank sky in Edit mode is expected: the server creates the whole world (terrain included) when Play starts. Permanent changes belong in shared source/content.

## Daily workflow

Tell the AI: **Start a task for [TASK]. Follow AGENTS.md, handle sync/branch/checks/testing, and open a PR. Wait for my approval before merging.**

Playtest/review the PR, then approve the AI to sync, check, and merge it. When switching between Codex and Claude Code, stop the previous writer and continue the same folder/branch with a short handoff.

## How a raid plays

- A **raid** lasts 9 minutes, then a short intermission. Most gold banked wins the raid (`Gold` and `Wins` leaderstats).
- Goblin Cove is home. **Boats** (press `E` on one) are how you travel: seven wait at home (six at the harbor docks, one at the Back Door cove behind the Hoard), and every island has at least one. Open `M` for the map; the compass strip along the top shows the Hoard and treasure.
- **The sea has regions.** Home Bay is closed by a reef: sail out through **the Gate** (gold lamps), or through a shallow pass (**green lamps**) if your boat is small. Green lamps always mean the same thing: water too shallow for a patrol ship. The Western Shallows are a whole region of it. By skiff the near islands are 6 to 8 seconds away, the Crossroads 10, the far north 30 to 35.
- **Nineteen treasures**, and the deeper the island, the more it is worth and the nastier the trouble:

  | Treasure | Gold | Where | Trouble when taken |
  | --- | --- | --- | --- |
  | Lost Compass | 1 | Pebble Isle (near home) | Gulls reveal you for 10 s |
  | Giant Pearl | 2 | Coral Atoll, inside a clam that opens and shuts | Gulls; the reef and a harbor-style jump to try |
  | Smuggler's Stash | 2 | Smuggler's Cove (behind a cracked wall: use a keg) | The bell reveals you |
  | Golden Gear | 4 | Windmill Hills (on a balcony the sails sweep) | The mill runs wild |
  | Lighthouse Lens | 4 | Top of the Crossroads lighthouse | The bell reveals you |
  | Sunken Sextant | 4 | Kelp Cay, in the Western Shallows | Gulls |
  | Captain's Chest | 5 | Shipwreck Shoals | The wreck's cannon barrage |
  | Crystal Heart | 7 | Crystal Isle tunnel | Cave-in |
  | Pearl of the Deep | 8 | Tide Vault (lever-gated; drain tunnel back door) | Gate slams, chamber floods |
  | Tempest Trident | 8 | Maelstrom Rock (in a whirlpool) | A squall settles on it |
  | Jade Frog | 9 | Tangle Isle shrine | Quake: the rope bridges snap |
  | Storm Lantern | 9 | Lantern Key's tower | The bell reveals you |
  | Castaway's Hoard | 9 | Driftwood Key | Gulls |
  | Admiral's Strongbox | 13 | Fort Barnacle keep | Patrol ships launch (unless the harbor chain is up: then they wait) |
  | Ember Crown | 13 | Volcano crater (stepping stones over lava) | Lava bombs rain |
  | Golden Idol | 14 | Sun Temple ziggurat | The Guardian wakes |
  | Aurora Gem | 17 | Frost Spire summit | Avalanche |
  | Leviathan Tooth | 17 | Skull of Leviathan's Rest | Tentacles |
  | Skull Chalice | 20 | Skull Rock's cranium | Fog and ghost ships |

  Treasure nobody takes grows more valuable (about an eighth of its value every 80 s, three times at most).
- **Something lives on every big island**, and each one follows a rule you can learn. None of them leaves its island.

  | Island | Who | What to know |
  | --- | --- | --- |
  | Crossroads Ruins | The Watchers, four statues | They only move while nobody is looking at them. Lit eyes mean one is free to move. They take treasure back to where it came from |
  | Crystal Isle | The Echo | A crystal copy of you walks your exact path, three seconds behind. Never double back |
  | Shipwreck Shoals | Old Clacker, a crab | It travels under the sand. A ring warns you before it comes up. Decks and rock are safe |
  | Windmill Hills | Bramble, a ram | It charges in a straight line and cannot turn. Step aside, or let it throw you where you wanted to go |
  | Tide Vault | The Warden, an eel | It owns the water. After the pearl is taken, stay on stone |
  | Tangle Isle | The Imps | A shriek and a ring: one is jumping for your treasure. Get off the ring, or chase it to its nest |
  | Fort Barnacle | The Garrison, two marines | The lines on the ground are what a marine can see. Get seen and it throws you over the wall |
  | Ember Isle | Cinderlings | They run ahead of you and set fire to your path. Change direction |
  | Frost Spire | The Chill | A drifting cold that drains your stamina. Stay ahead of it |
  | Leviathan's Rest | The Sleeper | It wakes to the noise of fast boats. Go slow, or go fast and straight |
  | Skull Rock | The Captain's shade | The skull's eyes go dark when he dozes. Steal then, and the ghost ships come late |
  | Maelstrom Rock | The Maw, a fin | It circles the whirlpool and shoves boats along |
  | Sun Temple | The Stone Guardian | See below |

  A powder keg stops any of them for a while. At home, **Gobbo** the dockhand hands out kegs and shouts when a patrol ship or a storm is near.
- Carry treasure into **the Hoard** (gold ring and beam at Goblin Cove) to bank it. Carrying barely slows you on foot; instead heavy treasure makes every stamina move cost more, and slows the boat you sit in.
- **You run fast for free.** Stamina pays for the special moves: sprint, a dash (also in the air) and one extra jump per flight. It refills in about three seconds.
- **Heat** is a shared meter. Stealing adds a chunk, carrying keeps adding, and it cools when nobody carries. At **ALERT** carriers fire flares everyone can see. At **HUNTED** a patrol ship appears on the horizon *ahead* of the thief, shells them, and charges (it sounds a horn first: turn and it misses). At **FRENZY** a second ship takes the water between the thief and home and lays mines across it, and a tempest chases the thief. The world only ever targets **carriers**, every strike is marked with a ring on the ground, and everything can be outrun, out-steered or hidden from.
- The **Guardian** is as fast as a carrier who only runs. It leaps onto a marked circle, throws boulders, and up close it slams the ground: a ring races outward, and you have to be in the air when it reaches you.
- The **sea has weather**: storm cells cross it (dark clouds on the horizon, rough water, marked lightning, and **waterspouts** that fling a boat into the air), currents carry boats (chevrons on the water show which way; the Serpent Channel past the fort is the fastest), and calm water hugs the coasts. Storms now start near whoever is out at sea.
- **Things to use.** Pull the lever on Fort Barnacle's west mole and a **chain** shuts the harbor for 40 seconds: no patrol ship leaves port. Light a **signal beacon** (ten of them, on high places) and every patrol ship in sight sails over to look. Orange pads are **catapults**.
- **The sea is a playground.** Hoops on the water give a boat a kick, and there are more than a hundred, laid out as **runs** along the ways you would sail anyway. Take them one after another and each kicks harder (the boat panel shows the **hoop chain**). Six runs are **timed** (start with the **Bay Circuit** just outside the harbor): the sign at each end keeps the best time and whose it is. Ramps throw a boat into the air.
- **Coins** hang along the runs, round the rocks and over the ramps. Drive through them: no button. Each one shortens your boost cooldown and patches the hull a little, and ten are worth 1 gold when you are next at the Hoard (at most 6 gold a raid, so treasure is still what wins). Glowing **salvage crates** drift where a patrol ship sank or a storm blew out: coins, a keg and a repair.

## Controls

| Input | Action |
| --- | --- |
| Hold `E` on treasure | Steal it from its spot (0.6 s), or grab it when loose |
| `E` on a boat | Board it. `W A S D` drives from the driver seat; `S` is a real brake |
| `Shift` in the driver seat | Boost (2.2 s, 5.5 s cooldown) |
| Hold `C` in a turn, in the driver seat | **Drift**: the boat slides round the turn. Let go for a burst of speed (bigger the longer you held the slide) |
| `R` near a boat's winch | Drop or raise the anchor |
| `E` at a cannon | Fire it where you aim |
| `E` at a lever | Pull it (the Tide Vault's gate, Fort Barnacle's harbor chain) |
| Hold `E` at a signal beacon | Light it: patrol ships nearby go to look |
| `G` | Throw a powder keg (take kegs from keg crates, or from Gobbo on the home dock, with `E`) |
| Hold `Shift` on foot | Sprint (on land or swimming). Uses stamina |
| `C` on foot | **Dash** the way you are moving, on the ground or in the air. Uses stamina |
| `Space` in the air | One extra jump per flight. Uses stamina |
| Click (sword) | Swing. Hits knock treasure loose. Carriers swing too, but slow, short and tiring |
| `F` | Grappling hook: pulls you to a surface or onto a passing boat (you take a seat), or steals treasure from a carrier. While you carry, it only pulls, on a longer cooldown |
| `Q` | Throw your treasure |
| `E` (no prompt showing) | **Poltergoblin**: leave your body and run as a faster spirit for 5 s, then snap back |
| `E` at a zipline post | Ride the zipline. Jump to let go |
| `M` | World map |
| `H` | Show or hide the how-to-play panel |

Green pads and timed steam geysers launch you; orange pads are catapults that throw you a long way (dash or jump to drop out early). Ladders, ramps and ziplines take you up and across the islands; tall crags and sea stacks are for the grapple. Home has bounce pads, a practice cannon with floating targets, keg crates and a harbor jump.

## What NOT to add yet

No shops, XP, pets, rarity tables, monetization, trading, boat trees, hideout decorating, or saved progress. The loot values and `Wins` exist only to score a raid.

For a local multiplayer test: **top-left Test dropdown > Server & Clients > set player count to 3 > blue Play button**. Play several raids with Ethan, Ninety, and Enrik. The checklist in the latest report under `docs/reports/` says what to look for.

Afterward make one decision:

- **KILL** — possession/escape isn't fun.
- **RE-PROTOTYPE** — fun exists but a core variable is weak.
- **GREENLIGHT** — the loop creates yelling, betrayal, improvisation, tension, and "one more raid."

## Known prototype compromises

- V4 had a human playtest (the sea was too spread out, the hoops were the best part, the islands needed inhabitants). V5 answers that and was tested by an AI in Studio on one client: every creature was made to do its thing to a goblin standing still, and none has met a player who dodges or a second player. Whether they are fun or fair, multiplayer, mobile performance and balance are unknown. The report lists what to test.
- The creatures are a few blocks each and walk through walls. Their numbers, and the par times on the timed runs, are first guesses.
- The world takes 6 to 7 seconds to build when Play starts. Nobody spawns until it is ready.
- A driven boat's physics run on the driver's own computer so steering answers at once; the server watches it and takes the boat back if it moves in a way the physics could not. `BOAT_CLIENT_PHYSICS` in `src/shared/Config.lua` switches back to the old server-run boats for comparison.
- The Guardian is a kinematic stone golem that walks over terrain instead of using pathfinding. It cannot follow into tunnels. The other inhabitants are built the same way.
- Grapple, throw, keg, cannon and Poltergoblin are keyboard and mouse only. A gamepad also gets sprint (left stick click), dash and drift (`B`), air jump (`A`) and boat boost (`X`). There are no touch buttons for any of these yet.
- Boats ride up gentle beaches and slide to a stop (press `S` or `W` to shove a beached boat along slowly), but still hit steep edges like a wall, and pass through dock posts.
- Shift sprints, so Roblox's shift lock is turned off.
- Art is primitive geometry and terrain. Sounds are pitched versions of the few sounds built into the Roblox client.

These are deliberate. Production architecture comes after the loop proves itself.

## Design reference

The [original design thesis](docs/DESIGN_THESIS.txt) preserves the broader vision and future ideas. Those ideas are not authorization to expand the prototype; follow the requested task and `AGENTS.md`. [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) describes the current systems.

The redundant original ZIP and duplicate README were removed from the current tree. The original distribution remains recoverable from Git history in baseline commit `a3d7185`; the active project is `src/` plus `default.project.json`.

# Loot Goblins — V2 archipelago prototype

An intentionally ugly Roblox prototype. It grew from Test 001 (one idol, one boat) into a **big physical sea**: a 19-island archipelago to explore, boats that float on real waves, storms and currents to read, and treasure that fights back on the way home.

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

- A **raid** lasts 8 minutes, then a short intermission. Most gold banked wins the raid (`Gold` and `Wins` leaderstats).
- Goblin Cove is home. **Boats** (press `E` on one) are how you travel: four wait at the home docks, and most mid-ring islands have one. Open `M` for the map; the compass strip along the top shows the Hoard and treasure.
- **Sixteen treasures**, and the deeper the island, the more it is worth and the nastier the trouble:

  | Treasure | Gold | Where | Trouble when taken |
  | --- | --- | --- | --- |
  | Lost Compass | 1 | Pebble Isle (near home) | Gulls reveal you for 10 s |
  | Giant Pearl | 2 | Coral Atoll | Gulls; the reef and a harbor-style jump to try |
  | Smuggler's Stash | 2 | Smuggler's Cove (behind a cracked wall: use a keg) | The bell reveals you |
  | Golden Gear | 3 | Windmill Hills (on a balcony the sails sweep) | The mill runs wild |
  | Lighthouse Lens | 3 | Top of the Crossroads lighthouse | The bell reveals you |
  | Captain's Chest | 4 | Shipwreck Shoals | The wreck's cannon barrage |
  | Crystal Heart | 5 | Crystal Isle tunnel | Cave-in |
  | Jade Frog | 5 | Tangle Isle shrine | Quake: the rope bridges snap |
  | Pearl of the Deep | 6 | Tide Vault (lever-gated; drain tunnel back door) | Gate slams, chamber floods |
  | Tempest Trident | 6 | Maelstrom Rock (in a whirlpool) | A squall settles on it |
  | Admiral's Strongbox | 7 | Fort Barnacle keep | Patrol ships launch |
  | Ember Crown | 8 | Volcano crater (stepping stones over lava) | Lava bombs rain |
  | Golden Idol | 10 | Sun Temple ziggurat | The Guardian wakes |
  | Aurora Gem | 12 | Frost Spire summit | Avalanche |
  | Leviathan Tooth | 13 | Skull of Leviathan's Rest | Tentacles |
  | Skull Chalice | 14 | Skull Rock's cranium | Fog and ghost ships |

  Treasure nobody takes grows more valuable (+1 gold per 80 s, up to +3).
- Carry treasure into **the Hoard** (gold ring and beam at Goblin Cove) to bank it. Heavy treasure slows boats.
- **Heat** is a shared meter. Stealing adds a chunk, carrying keeps adding, and it cools when nobody carries. At **ALERT** carriers fire flares everyone can see. At **HUNTED** the Navy sails out after the carrier. At **FRENZY** a tempest comes for the thief. The world only ever targets **carriers**, every strike is marked with a closing ring on the ground, and everything can be outrun, out-steered or hidden from.
- The **sea has weather**: storm cells cross it (dark clouds on the horizon, rough water, marked lightning), currents carry boats (the Rushing Strait, the Home Stream, the Maelstrom), and calm water hugs the coasts.

## Controls

| Input | Action |
| --- | --- |
| Hold `E` on treasure | Steal it from its spot (0.6 s), or grab it when loose |
| `E` on a boat | Board it. `W A S D` drives from the driver seat |
| `Shift` in the driver seat | Boost (2.2 s, 7 s cooldown) |
| `R` near a boat's winch | Drop or raise the anchor |
| `E` at a cannon | Fire it where you aim |
| `G` | Throw a powder keg (take kegs from keg crates with `E`) |
| Hold `Shift` on foot | Sprint. Uses stamina; none in water or seats |
| Click (sword) | Swing. Hits knock treasure loose. Carriers swing too, but slow, short and tiring |
| `F` | Grappling hook: pulls you to a surface, or steals treasure from a carrier. Not while you carry |
| `Q` | Throw your treasure |
| `E` (no prompt showing) | **Poltergoblin**: leave your body and run as a faster spirit for 5 s, then snap back |
| `E` at a zipline post | Ride the zipline. Jump to let go |
| `M` | World map |
| `H` | Show or hide the how-to-play panel |

Green pads and timed steam geysers launch you. Ladders, ramps and ziplines take you up and across the islands. Home has bounce pads, a practice cannon with floating targets, keg crates and a harbor jump.

## What NOT to add yet

No shops, XP, pets, rarity tables, monetization, trading, boat trees, hideout decorating, or saved progress. The loot values and `Wins` exist only to score a raid.

For a local multiplayer test: **top-left Test dropdown > Server & Clients > set player count to 3 > blue Play button**. Play several raids with Ethan, Ninety, and Enrik. The checklist in the latest report under `docs/reports/` says what to look for.

Afterward make one decision:

- **KILL** — possession/escape isn't fun.
- **RE-PROTOTYPE** — fun exists but a core variable is weak.
- **GREENLIGHT** — the loop creates yelling, betrayal, improvisation, tension, and "one more raid."

## Known prototype compromises

- Not played by real people yet: V2 was tested by an AI in Studio on one client. Multiplayer fun, mobile performance and balance are unknown. The report lists what to test.
- The Guardian is a kinematic stone golem that walks over terrain instead of using pathfinding. It cannot follow into tunnels.
- Grapple, throw, keg, cannon and Poltergoblin are keyboard and mouse only (sprint also toggles with a gamepad's left stick click).
- Boats beach hard against vertical sand edges and pass through dock posts.
- Shift sprints, so Roblox's shift lock is turned off.
- Art is primitive geometry and terrain. Sounds are pitched versions of the few sounds built into the Roblox client.

These are deliberate. Production architecture comes after the loop proves itself.

## Design reference

The [original design thesis](docs/DESIGN_THESIS.txt) preserves the broader vision and future ideas. Those ideas are not authorization to expand the prototype; follow the requested task and `AGENTS.md`. [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) describes the current systems.

The redundant original ZIP and duplicate README were removed from the current tree. The original distribution remains recoverable from Git history in baseline commit `a3d7185`; the active project is `src/` plus `default.project.json`.

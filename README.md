# Loot Goblins — vertical slice prototype

An intentionally ugly Roblox prototype. It grew out of Test 001 (one idol, one boat) into the first playable foundation of the whole loop:

**Go somewhere dangerous → steal loot → the world reacts → players fight over it → physically escape → bank it at home → go again.**

The question it answers: **is stealing valuable loot, fighting over it while the world hunts you, and getting it home fun enough that people want another raid?**

## Get set up

Ethan, Ninety, and Enrik use [one shared repository](https://github.com/EnrikR2002/Loot-Goblins), [AGENTS.md](AGENTS.md), and pinned tools.

**Give your Codex or Claude Code the [teammate setup prompt](docs/TEAM_SETUP_PROMPT.md).** It uses the existing setup, installs missing prerequisites, and verifies the connection to Studio. The [workstation guide](docs/WORKSTATION.md) has detailed onboarding, task, approval, and handoff instructions.

These are the Windows helpers the AI operates:

```powershell
./scripts/bootstrap.ps1
./scripts/dev.ps1 -OpenStudio
./scripts/check.ps1
```

The development place in `build/` is generated from this repository. Connect the official Rojo plugin to `localhost:34872` and keep the dev process running. The blank sky in Edit mode is expected: the server creates the whole world (terrain included) when Play starts. Permanent changes belong in shared source/content.

## Daily workflow

Tell the AI: **Start a task for [TASK]. Follow AGENTS.md, handle sync/branch/checks/testing, and open a PR. Wait for my approval before merging.**

Playtest/review the PR, then approve the AI to sync, check, and merge it. When switching between Codex and Claude Code, stop the previous writer and continue the same folder/branch with a short handoff.

## How a raid plays

- A **raid** lasts 5 minutes, then a short intermission. Most gold banked wins the raid (`Gold` and `Wins` leaderstats).
- Four pieces of loot glow at their spots, each with a light pillar you can see from anywhere:

  | Loot | Gold | Where | Trouble when taken |
  | --- | --- | --- | --- |
  | Lighthouse Lens | 3 | Top of the lighthouse, Crossroads Ruins | The bell rings: the thief glows through walls for 20 s |
  | Captain's Chest | 4 | Inside the shipwreck, Shipwreck Shoals | The wreck's cannon fires a barrage at the thief. Heavy (slowest carry). |
  | Crystal Heart | 5 | Chamber inside Crystal Isle | Cave-in: rocks fall and the west tunnel is sealed for 25 s |
  | Golden Idol | 10 | Top of the Sun Temple | The Guardian wakes, and a boulder rolls down the stairs |

- Carry loot into **the Hoard** (gold ring and beam at Goblin Cove) to bank it. Banked loot respawns at its spot after a while. Loot still out when the raid ends is lost.
- **Heat** is a shared meter. Stealing adds a chunk, carrying keeps adding, and it cools when nobody carries anything. At ALERT, carriers glow through walls and totems shoot them. At HUNTED, the Guardian hunts carriers near the temple. At FRENZY, it follows them anywhere. The world only ever targets **carriers**.
- Carriers are slow, can't swing the sword, and one sword hit knocks their loot loose.

## Controls

| Input | Action |
| --- | --- |
| Hold `E` on loot | Steal it from its spot (0.6 s), or grab it when loose |
| Click (sword) | Swing. Everyone spawns with a sword. Hits knock loot loose. Carriers can't swing. |
| `F` | Grapple: steals loot from a carrier, or yanks loose loot to you. Needs a clear line of sight. |
| `Q` | Throw your loot. Pass it, toss it over a gap, or throw it into the Hoard. |
| `E` (no prompt showing) | **Poltergoblin**: leave your body and run as a faster spirit for 5 s, then snap back (`E` again to return early). Loot the spirit holds comes back with you. Your body can be struck, and that drops your loot. Doesn't work inside the Hoard's ward. |
| `E` at a zipline post | Ride the zipline. Jump to let go. |
| Sit in `Driver` | WASD drives a boat. Two wait at the home docks. |
| `H` | Show or hide the how-to-play panel |

Green pads launch you upward.

## What NOT to add yet

No shops, XP, pets, rarity tables, monetization, trading, boat trees, hideout decorating, or saved progress. The loot values and `Wins` exist only to score a raid.

For a local multiplayer test: **top-left Test dropdown > Server & Clients > set player count to 3 > blue Play button**. Play several raids with Ethan, Ninety, and Enrik. The checklist in the latest report under `docs/reports/` says what to look for.

Afterward make one decision:

- **KILL** — possession/escape isn't fun.
- **RE-PROTOTYPE** — fun exists but a core variable is weak.
- **GREENLIGHT** — the loop creates yelling, betrayal, improvisation, tension, and "one more raid."

## Known prototype compromises

- Boats are intentionally kinematic instead of production physics vehicles.
- The Guardian is a kinematic stone golem that walks over terrain instead of using pathfinding. It cannot follow into tunnels.
- Grapple, throw and Poltergoblin are keyboard and mouse only.
- Art is primitive geometry and terrain. Sounds are pitched versions of the few sounds built into the Roblox client.

These are deliberate. Production architecture comes after the loop proves itself.

## Design reference

The [original design thesis](docs/DESIGN_THESIS.txt) preserves the broader vision and future ideas. Those ideas are not authorization to expand the prototype; follow the requested task and `AGENTS.md`. [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) describes the current systems.

The redundant original ZIP and duplicate README were removed from the current tree. The original distribution remains recoverable from Git history in baseline commit `a3d7185`; the active project is `src/` plus `default.project.json`.

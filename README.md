# Loot Goblins — Test 001

This is an intentionally ugly Roblox prototype that tests one thing:

**Is stealing one valuable object, fighting over possession of it, and getting it home inherently fun?**

## Get set up

Ethan, Ninety, and Enrik use [one shared repository](https://github.com/EnrikR2002/Loot-Goblins), [AGENTS.md](AGENTS.md), and pinned tools.

**Give your Codex or Claude Code the [teammate setup prompt](docs/TEAM_SETUP_PROMPT.md).** It uses the existing setup, installs missing prerequisites, and verifies the connection to Studio. The [workstation guide](docs/WORKSTATION.md) has detailed onboarding, task, approval, and handoff instructions.

These are the Windows helpers the AI operates:

```powershell
./scripts/bootstrap.ps1
./scripts/dev.ps1 -OpenStudio
./scripts/check.ps1
```

The development place in `build/` is generated from this repository. Connect the official Rojo plugin to `localhost:34872` and keep the dev process running. The blank sky in Edit mode is expected: the server creates the prototype world when Play starts. Permanent changes belong in shared source/content.

## Daily workflow

Tell the AI: **Start a task for [TASK]. Follow AGENTS.md, handle sync/branch/checks/testing, and open a PR. Wait for my approval before merging.**

Playtest/review the PR, then approve the AI to sync, check, and merge it. When switching between Codex and Claude Code, stop the previous writer and continue the same folder/branch with a short handoff.

## What it creates automatically

- Home island + bank pad
- Treasure island + idol altar
- Golden Idol with ProximityPrompt pickup
- Carry slowdown
- Guardian that wakes when the idol is stolen and follows possession
- Guardian smack that knocks the idol loose
- One ugly 3-seat boat
- Basic F-key grapple/steal
- Q-key manual drop
- Banking + round reset
- `Banks` leaderstat
- Minimal HUD

## Controls

- `E` — grab idol through Roblox's ProximityPrompt
- `F` — grapple toward your mouse target; clicking idol/current carrier steals it
- `Q` — drop idol
- Sit in `Driver` seat — WASD drives the prototype boat

## What NOT to add before the first playtest

No shops, XP, pets, rarity tables, monetization, multiple islands, trading, boat trees, hideout decorating, or full Heat system.

For a local multiplayer test: **top-left Test dropdown > Server & Clients > set player count to 3 > blue Play button**. First run 10 rounds with Ethan, Ninety, and Enrik.

Afterward make one decision:

- **KILL** — possession/escape isn't fun.
- **RE-PROTOTYPE** — fun exists but a core variable is weak.
- **GREENLIGHT** — the loop creates yelling, betrayal, improvisation, tension, and "one more round."

## Known prototype compromises

- Boat is intentionally kinematic instead of a production physics vehicle.
- Grapple is intentionally simple and mouse-first.
- Guardian navigation is simple `Humanoid:MoveTo`, so the generated island is kept open.
- Art is primitive geometry.

These are deliberate. Production architecture comes after the loop proves itself.

## Design reference

The [original design thesis](docs/DESIGN_THESIS.txt) preserves the broader vision and future ideas. Those ideas are not authorization to expand Test 001; follow the requested task and `AGENTS.md`.

The redundant original ZIP and duplicate README were removed from the current tree. The original distribution remains recoverable from Git history in baseline commit `a3d7185`; the active project is `src/` plus `default.project.json`.

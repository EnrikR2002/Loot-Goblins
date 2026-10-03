# Loot Goblins — Test 001

This is an intentionally ugly Roblox prototype that tests one thing:

**Is stealing one valuable object, fighting over possession of it, and getting it home inherently fun?**

## Team development

Ethan, Ninety, and Enrik use [one shared repository](https://github.com/EnrikR2002/Loot-Goblins), [AGENTS.md](AGENTS.md), and pinned tools. See [the short workstation guide](docs/WORKSTATION.md).

```powershell
./scripts/bootstrap.ps1
./scripts/dev.ps1 -OpenStudio
./scripts/check.ps1
```

The development place in `build/` is generated from this repository. The server creates the prototype world when play starts. Permanent changes belong in shared source/content; the manual installation notes below describe the original prototype distribution.

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

## Fastest install: Rojo

1. Put this folder somewhere on Enrik's machine.
2. Install/use Rojo if already part of your Roblox workflow.
3. Run Rojo against `default.project.json` and sync into a blank place.
4. Press **Test > Start** with 3 players.

## Manual Studio install (no Rojo)

Create these objects:

### ReplicatedStorage
- Folder: `LootGoblins`
  - ModuleScript: `Config`
    - Paste `src/shared/Config.lua`

### ServerScriptService
- Script: `LootGoblinsServer`
  - Paste `src/server/Main.server.lua`

### StarterPlayer > StarterPlayerScripts
- LocalScript: `LootGoblinsClient`
  - Paste `src/client/Main.client.lua`

Then press **Test > Start** and choose 3 players.

The server script generates the entire prototype world on startup.

## Controls

- `E` — grab idol through Roblox's ProximityPrompt
- `F` — grapple toward your mouse target; clicking idol/current carrier steals it
- `Q` — drop idol
- Sit in `Driver` seat — WASD drives the prototype boat

## What NOT to add before the first playtest

No shops, XP, pets, rarity tables, monetization, multiple islands, trading, boat trees, hideout decorating, or full Heat system.

First run 10 rounds with Ethan, Ninety, and Enrik.

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

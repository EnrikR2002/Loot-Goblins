# Loot Goblins — AI context

Master context for a Claude Code or Codex session that opens this repository with no history. It explains what the game is, how the code works, and how we build and test it.

**`AGENTS.md` holds the rules** (branching, approval, safety). This file is background only. If they ever disagree, `AGENTS.md` wins, and you should fix this file.

## Where things stand

| Where | What it contains |
| --- | --- |
| Shared `main` (as of `84b762a`, 2026-10-07) | The **vertical slice** (PR #7: raids, four loot pieces, Heat, Guardian/totems/trouble, Poltergoblin, HUD, module split) and the double-click launcher (PR #8). Report: `docs/reports/2026-10-06-vertical-slice-foundation.md`. |
| Unmerged: PR #9, branch `claude/sprinting-grapple-map-expansion-japzs8` | **Sprint + stamina**, the **grapple reworked into a hook that pulls you** (and steals with forgiving aim), and a **much bigger, taller map** with islands ~700 studs apart, 9 boats and 3 islets. Report: `docs/reports/2026-10-07-sprint-grapple-bigger-map.md`. Waiting for a Studio playtest and approval. |

Check the real state before you trust this table: `git log --oneline origin/main` and the open PRs. Update this table when a branch merges.

Everything below describes the sprint/grapple/bigger-map branch.

## Purpose

Loot Goblins is a Roblox game by Ethan, Ninety and Enrik. The one-sentence thesis is: *steal ridiculous treasure from dangerous islands and other players, then somehow get it home.*

Test 001 (one idol, one boat, one guardian) proved the pieces work. The vertical slice turns them into a first coherent game: **go somewhere dangerous → steal loot → the world reacts → players interfere → physically escape → bank → go again.** The question is still whether that loop is fun with three players.

`docs/DESIGN_THESIS.txt` holds the long-term vision (hideouts, boats as progression, sell/keep). That vision is **not** permission to build those things now. No shops, XP, pets, monetization, rarity tables, trading, or saved progress.

## Core loop

1. Players spawn at **Goblin Cove** next to **the Hoard**. A raid lasts `Config.RAID_DURATION` (360 s), then a short intermission.
2. Four loot items wait at spots around the map, each with a light pillar and a name tag visible from anywhere.
3. Prying loot off its spot (hold E, 0.6 s) adds Heat and triggers that item's **trouble** (boulder, cave-in, cannon barrage, bell).
   The islands are far apart: a run is usually a boat ride out, a climb, a steal, and a boat ride home.
4. The carrier is slow, can't swing, and is hunted by the world: totems at ALERT, Guardian at HUNTED (temple only) or FRENZY (anywhere).
5. Other players sword the loot loose, grapple it away, chase, or wait at chokepoints and the Hoard.
6. Carrying loot into the Hoard ring banks its gold. A throw that lands in the ring counts for the thrower. Banked loot respawns later.
7. When the timer ends, the most gold wins (`Wins` +1). Loot still out is lost; everything resets.

## Controls

| Input | Action | Where |
| --- | --- | --- |
| Hold `E` on loot | Steal from spot / grab loose loot (ProximityPrompt) | `Loot` |
| Hold `Shift` (gamepad: click left stick) | Sprint (×1.45, carriers ×1.2). Uses stamina; none in water or seats. Shift lock is turned off. | `Movement`, client `Main` |
| Click (sword) | Swing. Given on every spawn. Server picks targets. | `Combat` |
| `F` | Grapple hook. Near loot or a carrier (within 60, aim assist 7 studs, line of sight): steal it. Anywhere else: hook the first solid thing within 130 and get pulled there. Carriers can't use it. A miss costs no cooldown. | `Combat`, client `Main` |
| `Q` | Throw held loot | `Loot` |
| `E` with no prompt showing | Poltergoblin (cast / early return) | `Poltergoblin` |
| `E` at zipline start | Ride (client-driven), jump to let go | client `Main` |
| Sit in `Driver` | WASD drives a boat | `Boats` |
| `H` | Help panel | client `Hud` |

Abilities are keyboard and mouse only. Prompts and the sword also work on touch and gamepad, and sprint toggles with a gamepad's left stick click.

## Systems

All tuning numbers live in `src/shared/Config.lua`. Gameplay modules never hardcode tuning.

- **World** (`World.lua`). Built at runtime into `workspace.LootGoblinsGenerated` with Terrain (islands, cliffs, rock ramps, tunnels, sea) plus anchored parts. It returns `World.refs` (Hoard, spawn points, loot spots, totems, Guardian lair, boulder start, cave-in plug, boat spawns, folders). Folders:
  - `Ground`: walkable parts the Guardian may walk on.
  - `Structures`: walls and props, which block line of sight.
  - `Decor`: non-colliding props, `CanQuery` off.
  - `Loot`, `Threats`, `Effects`, `SpiritBodies`, `LaunchPads`, `Ziplines`.
- **Map.** North is -Z. About 1,800 × 1,800 studs of islands inside 2,000 × 2,000 bounds. The five big islands sit ~700 studs apart center to center (280–650 studs of open sea between shores), so boats are the main way around and swimming is the slow fallback. Every island has a dock with one boat; home has four (9 total).
  - **Goblin Cove** (home, z ≈ 650): Hoard, spawn, 4 boats, hideout hill with a hilltop lookout and crow's nest.
  - **Crossroads Ruins** (hub, origin): a lower town (y 10) and the **acropolis** cliff (y 42) in the middle. Ways up: grand stairs (south), a rock ramp (east), a launch pad (west), the aqueduct from the west knoll, and the **undercroft** tunnel under it with a ladder shaft. The **lighthouse** stands on the acropolis rim (Lens at y ≈ 119). Watchtower knoll, harbor houses, sniper tower with a pad.
  - **Sun Temple** (z ≈ −720): jungle (y 8) around a **mesa** (y 56) with the ziggurat on top (Idol at y ≈ 98). Ways up: the pilgrim rock ramp (south cliff), two ladders (east cliff), the **sea cave** (enters at the west waterline under a hill chain and climbs inside the mountain to the courtyard). Ways out: the **Sun Spire zipline** (572 studs, to the Crossroads acropolis), the south dock, the cave.
  - **Crystal Isle** (x ≈ 720): a basalt spire of five shelves (y 20/50/85/115/135) linked by rock ramps spiralling up. A sea-level tunnel runs through it past the Heart chamber; a launch pad in the tunnel shoots up a shaft to the 115 shelf. **The Leap**: a broken bridge off the 85 shelf with a 15-stud gap (5 down) that only an empty-handed sprint jump clears; past it, the Needle has a zipline to Twin Stacks.
  - **Shipwreck Shoals** (x ≈ −700): an atoll. Wadeable shallows ring a lagoon; a reef channel on the south-east lets boats in. A three-deck galleon sits on a sandbank in the middle (Chest in the hold; ladders between decks, climbable masts, crow's nests, cannon on the stern cabin). Three sea stacks with rope bridges; a zipline from the tallest drops onto the galleon.
  - **Islets**: Gull Rock (ladder up a pinnacle, zipline down into Goblin Cove), Smuggler's Cove (spare boat, a rock arch boats sail under), Twin Stacks (two stacks, rope bridge, the Crystal zipline lands here).

  Water is real terrain water; wading or swimming is slower (`WATER_SPEED_MULT`). Invisible walls sit at `Config.BOUNDS_*`. Floating island names (`islandSign`) are readable from across the sea.
- **Loot** (`Loot.lua`). Items are defined in `Config.LOOT`. Each is a physics core part with welded decoration, a prompt, a tag and a light pillar. States: `spot`, `carried` (welded above the head), `loose` (server-owned physics; floats), `away` (banked, respawning).
  - Steal immunity (`STEAL_IMMUNITY`) after any change of hands.
  - Loose loot returns to its spot after `LOOSE_RETURN_TIME` or if it leaves the bounds.
  - Signals: `Taken`, `Loosened`, `Banked`, `Returned`.
  - The client reads loot state from attributes on the `Loot` folder (`<id>State`, `<id>Carrier`, `<id>CarrierId`, `<id>ReturnAt`).
- **Heat** (`Heat.lua`). 0–100, with tiers CALM, ALERT (25), HUNTED (50) and FRENZY (80). It rises when loot is stolen from its spot and while loot is carried outside the ward, and cools while nobody carries. Replicated as `workspace` attributes `Heat` and `HeatTier`.
- **Threats** (`Threats.lua`). Everything targets carriers only.
  - **Guardian.** A kinematic golem that walks on Terrain and `Ground`, wades in water, and stays out of tunnels and the ward. Leashed to the temple until FRENZY. It smashes (damage, knockback, loot knocked loose), then pauses.
  - **Totems** (6, including the wreck cannon). At ALERT and above, a carrier in range with line of sight gets a red charge beam, then a slow blast.
  - **Trouble**, the moment loot leaves its spot: boulder (Idol), cave-in plug and rocks (Heart), cannon barrage (Chest), bell reveal (Lens).
  - **Reveal.** Carriers get an always-on-top `Highlight` named `CarrierReveal` at ALERT and above, or after the bell.
- **Combat** (`Combat.lua`).
  - Sword: range 8, 20 damage, knockback. A hit on a carrier knocks the loot loose. Carriers can't swing. Swings also check spirit bodies.
  - Grapple: the client sends only its aim (camera ray hit point and part). The server picks: (1) **steal** the clicked loot, or the loose/carried loot (or its carrier) nearest the aim line within `GRAPPLE_AIM_ASSIST`, if in `GRAPPLE_RANGE` with line of sight; a wall in the way turns it into (2) a **pull**: the server raycasts along the aim up to `GRAPPLE_PULL_RANGE` and broadcasts the anchor. Nothing in range (or only the sea floor) is a **miss** with no cooldown; requests closer together than 0.25 s are ignored. Carriers can't grapple; seated players can steal but not pull. Cooldowns: steal 6 s, slip (steal immunity) 1 s, pull 2 s, exposed as `GrappleReadyAt` and `GrappleCooldown`.
- **Poltergoblin** (`Poltergoblin.lua`; Soul Unbound / Yone's E, renamed and reworked). E dashes the spirit out and leaves a frozen, labeled clone body. The spirit lasts 5 s with +10→30% speed, then snaps back (E again after 0.5 s returns early). Spirit sword hits leave marks that echo 35% on return. The rules that make it an extraction decision:
  - Loot the spirit holds rides back to the body.
  - Tether length `POLTER_TETHER`: going past it snaps you back.
  - Striking the body shatters the spirit: snap back, take damage, no echo, and the spirit's loot drops where it stood.
  - Spirits can't cast inside, enter, or bank in the Hoard ward.
- **Movement** (`Movement.lua`). The only writer of `WalkSpeed`: carry speed (per item) × sprint × water multiplier × spirit boost. It also owns **stamina**: the client only reports "sprint key held"; the server sprints you only while you move, stand on foot (not seated), are out of the water and have stamina. Draining to 0 makes you **winded** until stamina refills to `STAMINA_RECOVER`. Published as player attributes `Stamina` (whole numbers), `Sprinting`, `Winded`.
- **Boats** (`Boats.lua`). Kinematic boats, one per `refs.boatSpawns` entry (World's `dock()` adds them). The server reads the Driver seat each Heartbeat and stops at land, docks, shallows and the bounds (short downward raycasts at the bow or stern). Speed 62.
- **Raid** (`Raid.lua`). Phases `raid` and `intermission`, published as `workspace` attributes `RaidPhase` and `PhaseEndsAt`. `start()` resets every system and teleports everyone home. `finish()` scores, awards `Wins`, broadcasts results and resets. Leaderstats are `Gold` (this raid) and `Wins`.
- **Client.**
  - `Hud.lua`: timer, Heat bar, loot board, feed, banner, objective line, ability slots, Hoard waypoint, results, help.
  - `Effects.lua`: sounds from `rbxasset://sounds/*` client files, neon effects, particles, camera shake, Heat and spirit tint.
  - `Main.client.lua`: input, sprint key, Poltergoblin dash prediction, ziplines, launch pads, the grapple pull (a `LinearVelocity` toward the server's anchor; jump lets go, it pops you up at the end, it stops if snagged), event handlers.

## Architecture

| Repository path | Rojo maps it to | Holds |
| --- | --- | --- |
| `src/server/Main.server.lua` | `ServerScriptService.LootGoblinsServer.Main` | Boot, wiring, player lifecycle, the one Heartbeat |
| `src/server/<Module>.lua` | `ServerScriptService.LootGoblinsServer.<Module>` (ModuleScripts) | `Net`, `Util`, `Movement`, `World`, `Boats`, `Loot`, `Heat`, `Poltergoblin`, `Combat`, `Threats`, `Raid` |
| `src/client/Main.client.lua` | `StarterPlayerScripts.LootGoblinsClient.Main` | Input, client movement toys, event routing |
| `src/client/Hud.lua`, `Effects.lua` | ModuleScripts next to it | HUD and local effects |
| `src/shared/Config.lua` | `ReplicatedStorage.LootGoblins.Config` | Tuning only |

- **Plain modules, no framework.** Each module is a table of functions with a header comment explaining its rules. They talk through direct calls and tiny `Util.signal()` events.
- **Require order has no cycles.** `Net`/`Util` → `Movement` → `World`/`Boats` → `Loot` → `Heat` → `Poltergoblin` → `Combat`/`Threats` → `Raid` → `Main`. Main injects the one back-reference: `Loot.canBank = not Poltergoblin.isSpirit`.
- **Remotes.** `ReplicatedStorage.LootGoblinsRemotes` is recreated at boot. Client → server: `ThrowRequest()`, `GrappleRequest(hitPosition, target)`, `PoltergoblinRequest()`, `SprintRequest(held)`.
- **One broadcast channel.** `GameEvent(kind, payload)` from server to client. Kinds:
  - `Message`, `Feed`, `Toast`
  - `Stolen`, `Snatched`, `Grabbed`, `LootLoose`, `Banked`
  - `Trouble`, `HeatTier`
  - `GuardianWake`, `GuardianSmash`, `TotemCharge`, `TotemFire`, `Blast`, `CaveIn`
  - `GrappleFX` (kind `steal`, `pull` or `miss`; misses go only to the thrower), `SwordHit`, `Polter` (phase `cast`, `return`, `shatter` or `echo`)
  - `RaidStart`, `RaidEnd`, `LastCall`
- **Replicated state lives in attributes**, with times in `workspace:GetServerTimeNow()` units.
  - Player: `CarryingLoot`, `PolterEndsAt`, `PolterReadyAt`, `PolterBody`, `GrappleReadyAt`, `GrappleCooldown`, `Stamina`, `Sprinting`, `Winded`.
  - `workspace`: `RaidPhase`, `PhaseEndsAt`, `Heat`, `HeatTier`, `GuardianState`.
  - `Loot` folder: per-item state.
- **Place settings.** `workspace.StreamingEnabled` is false; the client relies on seeing the whole generated world. Shift sprints, so the server turns shift lock off: `StarterPlayer.EnableMouseLockOption = false`, and `DevEnableMouseLock = false` on each player (the StarterPlayer default only reaches players who join after it is set).

Integration points new code must respect:

- **WalkSpeed:** go through `Movement` (`setCarrySpeed`, `setBoost`, `setSprintHeld`). Anything else gets overwritten every frame.
- **Player damage:** use `Util.damage` and pass the result to `Poltergoblin.markDamage(attacker, humanoid, dealt)` if a player caused it.
- **Knocking loot loose:** `Loot.knockLoose` respects steal immunity. `Loot.dropFor` ignores it (death, leaving, shatter).
- **Teleports and resets:** call `Poltergoblin.finish(player, "cancel")` or `Poltergoblin.cancelAll()` first, and unseat players.
- **Pushing players:** `Util.knockback` uses a short replicated `LinearVelocity`, because clients own their characters.
- **Shared E key:** a visible prompt always wins over Poltergoblin.

## Who decides what (server vs client)

- **The server owns:** loot state and possession, steals and immunity, banking, scores, raid phases, Heat, Guardian, totems, trouble, all damage and hit detection, cooldowns, WalkSpeed, teleports, and the spirit timer, body, tether, marks and return.
- **The client owns:** its own character physics (Roblox default). That covers walking, the Poltergoblin dash, zipline rides, launch-pad velocity and the grapple pull toward a server-chosen anchor, plus HUD, effects and its own prompt use.
- **What clients send:** only intent ("throw", "Poltergoblin", "sprint key held") and grapple aim, which the server checks for type, range, cooldown and line of sight. Stamina and sprint speed are the server's. The client never says who it hit, how much damage it did, who holds loot, or where to teleport. Keep it that way.

## Important files

| File | Why it matters |
| --- | --- |
| `AGENTS.md` | Rules for every AI session. Read it first. |
| `README.md` | Player-facing summary, controls, guardrails, the playtest decision |
| `docs/reports/2026-10-07-sprint-grapple-bigger-map.md` | Sprint, grapple and big-map reasoning, numbers, headless test results and the human playtest checklist for this branch |
| `docs/reports/2026-10-07-map.png` | Top-down render of the current generated map (not a screenshot) |
| `docs/reports/2026-10-06-vertical-slice-foundation.md` | Design reasoning for the vertical slice (raids, loot, Heat, threats, Poltergoblin). Its map section describes the old, smaller map |
| `docs/WORKSTATION.md` | Setup, daily commands, Studio verification, troubleshooting |
| `docs/DESIGN_THESIS.txt` | Long-term vision (not current scope) |
| `Play Loot Goblins.bat`, `scripts/play.ps1` | One-click play for Ethan and Ninety: update, build, open Studio. No terminal, no Rojo |
| `scripts/bootstrap.ps1`, `dev.ps1`, `check.ps1`, `common.ps1` | Tool install, Rojo build/serve, checks |
| `.github/workflows/check.yml` | CI: `bootstrap.ps1 -Headless`, then `check.ps1` on Windows |
| `rokit.toml` | Pinned Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0 (do not casually bump) |

## Development workflow

`AGENTS.md` is the authority. In short: sync `main`, then work on one short-lived task branch. Run checks and Studio tests, open a PR, and **never merge without explicit human approval**. PR descriptions follow `.github/pull_request_template.md`. They use plain, short sentences and an honest **Not tested** list.

- **Ethan and Ninety do not use terminals.** They double-click `Play Loot Goblins.bat`. When one asks to try new changes, you run the Git steps and `./scripts/play.ps1` for them and explain how to play in plain words. See the "Teammates who do not use terminals" section of `AGENTS.md`. Rojo is only needed when you edit code.
- `./scripts/check.ps1 -Fix` runs StyLua (with AST verification), Selene, a Rojo build, and `git diff --check`. CI runs the same script. On Linux, the same pinned binaries can be run directly (`stylua --check src`, `selene src`, `rojo build`).
- `check.ps1` and `dev.ps1` both rebuild `build/LootGoblinsTest001.rbxlx`, which is usually the place open in Studio. It is a disposable output. If a human might have saved Studio-only work into it, build to a temp path first and compare hashes.
- CI can fail in **Install pinned project tools** with a rokit `403 Forbidden` from `api.github.com`. That is an unauthenticated rate limit, not your code. Read the log before changing anything; a rerun or new push retries it.

## Rojo and Studio MCP

- Rojo serves on `127.0.0.1:34872`. **A server is often already running** (started together with Studio by `dev.ps1 -OpenStudio`). In that case a second `dev.ps1` fails with "address in use". Check with `curl http://127.0.0.1:34872/api/rojo` first.
- **Confirm Studio has your edits:** in the Edit datamodel, compare `#Script.Source` with each file's byte size (`wc -c`). Rojo syncs saved files live. There are now many ModuleScripts; check the ones you changed.
- **Use the official Studio MCP only.** Call `list_roblox_studios` at the start of every session. The `studio_id` changes whenever the place is reopened.
  - `get_studio_state` shows the mode.
  - `execute_luau` runs code in a chosen datamodel (`Edit`, `Server`, `Client`).
  - `start_stop_play` starts and stops play mode.
  - `get_console_output` reads errors.
  - `screen_capture` takes screenshots; it can take an optional camera position.
  - `user_keyboard_input` sends real key presses, and ProximityPrompts respond to them.
- Never open a second Studio copy. Never force-kill Studio. Stop play mode when you finish.
- Cloud sessions have no Studio. Say so plainly; static checks and headless runs are not a playtest.

## Testing expectations

- Every change: `check.ps1` passes.
- Gameplay changes also need a Studio playtest through MCP, with an empty console, then play mode stopped. Report anything you could not test.
- **Timed effects are shorter than MCP round trips** (each call takes about 1–3 s). Before sending input, arm a recorder: `task.spawn` inside `execute_luau` that waits for the event, samples state, and writes a summary string to an attribute. Read the attribute afterwards.
- **Useful tricks:**
  - Shorten `Config.RAID_DURATION` and respawn times in the Server datamodel's required table for a quick test, but don't commit test values.
  - Teleport players from the `Server` datamodel by setting `root.CFrame`.
  - Fire a prompt from the `Client` datamodel with `prompt:InputHoldBegin()` / `InputHoldEnd()`. Loot spot prompts need a 0.6 s hold.
  - Read state from attributes: the player's `CarryingLoot`; `workspace` `Heat`, `HeatTier`, `RaidPhase`, `GuardianState`; the `Loot` folder.
  - Jump Heat for testing with `require(ServerScriptService.LootGoblinsServer.Heat).add(60)` in the Server datamodel.
- **Limit:** single-client MCP play cannot test player-vs-player effects (sword hits, grapple steals, body strikes, echoes). `StudioTestService:ExecuteMultiplayerTestAsync(numPlayers, args)` exists but has not been tried here.
- The real validation is the human 3-player test: **Test > Server & Clients > 3 players > Play**. The report has a checklist.

## Design philosophy

- Serve the loop. Ugly and fast beats polished and slow. Primitive parts and terrain are fine.
- Threats target carriers, not players. Holding loot is what makes you the problem.
- Every mobility tool must leave carrying loot home a physical journey. Poltergoblin rewinds and never transports. Ziplines and pads are exposed and predictable. The grapple pull is for empty hands only. Carriers sprint only a little (×1.2), so the Leap's sprint-jump gap rejects them. Boats are fast but have to be found, kept and docked.
- Keep diffs small and local, reuse the existing patterns, and put numbers in `Config.lua`.
- Visual feedback goes on the client. State changes go through the server.

## Major implementation decisions

- **The world is generated at runtime**, terrain included. The repository stays the only source of truth.
- **The Guardian is kinematic.** It no longer uses `Humanoid:MoveTo`, so it can't push loot off the map (the Test 001 bug) and never gets stuck on the new terrain. In exchange it walks through walls and can't enter tunnels; tunnels are deliberate safe routes.
- **Loot floats** (density 0.5), so drops in the sea stay reachable. Loot outside the bounds or idle too long returns to its spot.
- **The sword is given on spawn.** The Test 001 pedestal is gone; it only shared the E key with Poltergoblin.
- **Carriers can't swing.** Carrying is a vulnerable role. Throwing (Q) is how a carrier frees their hands.
- **Poltergoblin keeps Yone's E mechanics** (dash, body, speed ramp, 0.5 s recast, 5 s, 35% echo, 10 s cooldown on cast) under an original goblin-ghost presentation (green spirit, purple marks).
- **Sounds** use only `rbxasset://sounds/` files shipped in every client (`impact_explosion_03.mp3`, `impact_water.mp3`, `action_*.mp3`, `volume_slider.ogg`, `ouch.ogg`), pitched for variety. No uploaded assets, no asset permissions.

## Known limitations

- Deliberate compromises: primitive art, kinematic boats and Guardian, pitched built-in sounds.
- Grapple, throw and Poltergoblin have no touch or gamepad controls. Sprint has a gamepad toggle (left stick click) but no touch button.
- Boats pass through dock posts (visual only).
- The Guardian walks over the tops of buildings and through walls and cliffs (its feet follow a ray from the top of the map), and can't reach players in tunnels or the temple sea cave.
- The grapple pull and the ziplines move the character on the client; other players see it through normal character replication.
- Single-player MCP tests cannot cover player-vs-player features.

## Known bugs

- None confirmed yet. Neither the vertical slice nor this branch has been playtested in Studio (both build sessions had no Studio). Treat everything in the reports' "not tested" lists as unverified.
- The Test 001 bug where the Guardian pushed a loose idol off the map is fixed by design: the kinematic Guardian has no collisions, and loot outside the bounds returns to its spot.
- CI rokit `403` flake (see Development workflow).

## Keeping this file useful

Update this file in the same PR whenever systems, controls, architecture, authority boundaries, or known bugs change. Keep it short and current: no session narratives or temporary details. Those belong in PR descriptions or `docs/reports/YYYY-MM-DD-<topic>.md`.

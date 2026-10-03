# Loot Goblins — AI context

Master context for a Claude Code or Codex session that opens this repository with no history. It explains what the game is, how the code works, and how we build and test it.

**`AGENTS.md` holds the rules** (branching, approval, safety). This file is background only. If they ever disagree, `AGENTS.md` wins, and you should fix this file.

## Where things stand

| Where | What it contains |
| --- | --- |
| Shared `main` (as of `d74989c`, 2026-10-03) | Test 001 prototype, the sword (PR #3), and team tooling. Everything under "Systems on `main`" below. |
| Unmerged: PR #5, branch `feature/yone-soul-unbound` | **Soul Unbound** (Yone's E from League of Legends), this file, and `docs/reports/2026-10-03-yone-e-test.md`. Waiting for human playtest approval. |

Check the real state before you trust this table: `git log --oneline origin/main` and `gh pr view 5 --repo EnrikR2002/Loot-Goblins --json state`. When PR #5 merges, move the Soul Unbound section into "Systems on `main`" and update this table.

## Purpose

Loot Goblins is a Roblox game by Ethan, Ninety and Enrik. The one-sentence thesis is: *steal ridiculous treasure from dangerous islands and other players, then somehow get it home.*

The current build is **Test 001**, an intentionally ugly prototype. It answers one question: **is stealing one valuable object, fighting over it, and getting it home fun with three players?** After about 10 rounds, the team decides KILL, RE-PROTOTYPE, or GREENLIGHT (see `README.md`).

`docs/DESIGN_THESIS.txt` holds the long-term vision (Heat, hideouts, boats as progression, sell/keep). That vision is **not** permission to build those things now. Before prototype approval, do not add progression, shops, pets, monetization, rarity, trading, big maps, or production architecture.

## Core loop (Test 001)

1. Players spawn on the home island. The boat waits at the home dock.
2. Someone sails to the treasure island and grabs the Golden Idol from its altar.
3. The first grab wakes the Guardian. It chases whoever holds the idol, hits them, and knocks the idol loose.
4. Other players fight over the idol. Grapple (F) and the sword steal it or kill the carrier, and death drops it.
5. The carrier gets it to the bank pad on the home island. That is +1 `Banks`, then after 4 seconds the round resets.

## Controls

| Input | Action | Where |
| --- | --- | --- |
| `E` near a prompt | Grab the idol, or grab a sword at the pedestal (Roblox ProximityPrompt) | `main` |
| `E` with no prompt showing | Soul Unbound | PR #5 only |
| Click (sword equipped) | Swing the sword | `main` |
| `F` | Grapple: aiming at the idol or the current carrier steals the idol. It does **not** pull the player. | `main` |
| `Q` | Drop the idol | `main` |
| Sit in `Driver` | WASD drives the boat | `main` |

All abilities are keyboard-only. Only the prompts and the sword tool work on touch or gamepad.

## Systems on `main`

All of these live in `src/server/Main.server.lua`. Tuning numbers are in `src/shared/Config.lua`.

- **World.** The server builds everything when it starts, in `workspace.LootGoblinsGenerated`. That includes the water (a *solid* part that players can stand on), two islands, docks, spawn, `BANK` pad, idol altar, boat, guardian, and sword pedestal. Edit mode shows an empty sky; that is expected.
- **Idol and carrying.** The idol is a `GoldenIdol` ball with a `GrabPrompt`. Carrying welds it to the carrier's `HumanoidRootPart` with a `WeldConstraint` (the idol is made massless). Carrying sets WalkSpeed to 12 (normal is 16). The server keeps `carrier`, `roundActive` and `resetting` as script locals.
- **Grapple (F).** Range 70, 2.75 s cooldown. The server checks the target is the idol or the carrier and that it is within range. It broadcasts `GrappleFX` either way.
- **Guardian.** A Humanoid model (`GiantGuardian`, 500 HP, speed 21). Once a round is active, every Heartbeat it calls `MoveTo` toward the carrier, or toward the loose idol. Within 7 studs, every 1.1 s, it does 12 damage plus knockback and detaches the idol. Players cannot damage it.
- **Sword (PR #3).** The pedestal prompt gives one `Sword` tool per player, which is lost on death. On swing, the **server** picks targets: range 8, facing dot ≥ 0.3. A hit does 20 damage and knockback, with a 0.6 s cooldown. It only hits players.
- **Boat.** `ShittyBoat` is kinematic. Each Heartbeat the server reads the Driver seat's throttle and steer and calls `PivotTo` on the boat.
- **Banking and reset.** The carrier within 13 studs of `BANK` adds +1 to the `Banks` leaderstat. Then `resetRound()` puts the idol back on the altar, resets the boat and guardian, and teleports everyone home.
- **HUD (client).** A status banner at the top and a help line at the bottom. They react to `GameEvent` messages.

## Unmerged: Soul Unbound (PR #5)

This is Yone's E. **E** with no prompt showing dashes your spirit 14 studs and leaves your body behind as a frozen clone of your avatar, tied to the spirit by a tether. For 5 s the spirit gets +10% → +30% move speed, applied on top of the carry slowdown. Then it snaps back to the body. Press E again after 0.5 s to return early. A carried idol comes back too. Sword hits landed as a spirit leave a mark that repeats 35% of that damage on return. The cooldown is 10 s from the cast. Numbers are in `Config.SOUL_*`.

Integration points other code must respect:

- **WalkSpeed.** During spirit form, `walkSpeedFor(player)` re-applies the speed every Heartbeat and overrides other WalkSpeed writes. New speed effects must go through it.
- **Damage marks.** Every new source of player damage should call `markSoulDamage(attacker, victimHumanoid, actualDamage)`, as `swingSword` does.
- **Ending the spirit.** Anything that teleports or resets players should call `endSoulUnbound(player, "cancel")` first, as `resetRound` does. Death uses `"death"`; a normal return uses `"return"`.
- **Shared E key.** A visible prompt always takes E. While you own a sword, the client hides the sword prompt for you only.

## Architecture

| Repository path | Rojo maps it to | Holds |
| --- | --- | --- |
| `src/server/Main.server.lua` | `ServerScriptService.LootGoblinsServer.Main` | World, rules, remotes, everything authoritative |
| `src/client/Main.client.lua` | `StarterPlayer.StarterPlayerScripts.LootGoblinsClient.Main` | Input, HUD, visual effects |
| `src/shared/Config.lua` | `ReplicatedStorage.LootGoblins.Config` | Tuning numbers only |

- **Three scripts, no framework.** Each script is split into sections with `-- Name ----` banner comments. New features are added as a new section, following the same patterns.
- **Order matters.** Locals are defined top-down, so a section must come after anything it uses. For example, Soul Unbound sits before Sword because sword hits call it.
- **Remotes.** The server recreates `ReplicatedStorage.LootGoblinsRemotes` when it starts. Client → server: `DropRequest()`, `GrappleRequest(hitPosition, target)`, and on PR #5 `SoulUnboundRequest()`.
- **One broadcast channel.** `GameEvent` carries everything server → client as `(kind, payload)`. Kinds: `Message`, `Carrier`, `Banked`, `GrappleFX`, and on PR #5 `SoulUnbound` with `phase` set to `cast`, `return`, or `echo`.
- **Replicated state.** Per-player state the client needs goes in player attributes. Times are in `workspace:GetServerTimeNow()` units. On PR #5 these are `SoulUnboundEndsAt` and `SoulUnboundReadyAt`.
- **Place settings.** `workspace.StreamingEnabled` is false, and `FallenPartsDestroyHeight` is -500.

## Who decides what (server vs client)

- **The server owns:** idol possession, carrier, banking, round state, guardian, all damage and hit detection, cooldowns, WalkSpeed, teleports, and on PR #5 the spirit timer, body, marks and return.
- **The client owns:** its own character physics (Roblox default), so walking and dashes are client-side. Also the HUD, visual effects, and its own prompt visibility.
- **What clients send:** only intent ("drop", "soul unbound"), plus grapple aim, which the server checks for type, range and cooldown. The client never says who it hit, how much damage it did, who holds the idol, or where something should teleport. Keep it that way.

## Important files

| File | Why it matters |
| --- | --- |
| `AGENTS.md` | Rules for every AI session. Read it first. |
| `README.md` | Player-facing summary, controls, what not to add, the playtest decision |
| `docs/WORKSTATION.md` | Setup, daily commands, Studio verification, troubleshooting |
| `docs/DESIGN_THESIS.txt` | Long-term vision (not current scope) |
| `docs/reports/` | Dated reports from individual task sessions |
| `scripts/bootstrap.ps1`, `dev.ps1`, `check.ps1`, `common.ps1` | Tool install, Rojo build/serve, checks |
| `.github/workflows/check.yml` | CI: `bootstrap.ps1 -Headless`, then `check.ps1` on Windows |
| `rokit.toml` | Pinned Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0 (do not casually bump) |

## Development workflow

`AGENTS.md` is the authority. In short: sync `main`, then work on one short-lived `feature/`, `fix/`, `chore/` or `prototype/` branch per task. Run checks and Studio tests, open a PR with `gh`, and **never merge without explicit human approval**. PR descriptions follow `.github/pull_request_template.md`. They use plain, short sentences and an honest **Not tested** list.

- `./scripts/check.ps1 -Fix` runs StyLua (with AST verification), Selene, a Rojo build, and `git diff --check`. CI runs the same script.
- `check.ps1` and `dev.ps1` both rebuild `build/LootGoblinsTest001.rbxlx`, which is usually the place open in Studio. It is a disposable output. If a human might have saved Studio-only work into it, build to a temp path first and compare hashes.
- CI can fail in **Install pinned project tools** with a rokit `403 Forbidden` from `api.github.com`. That is an unauthenticated rate limit, not your code. Read the log before changing anything; a rerun or new push retries it.

## Rojo and Studio MCP

- Rojo serves on `127.0.0.1:34872`. **A server is often already running** (started together with Studio by `dev.ps1 -OpenStudio`). In that case a second `dev.ps1` fails with "address in use". Check with `curl http://127.0.0.1:34872/api/rojo` first.
- **Confirm Studio has your edits:** in the Edit datamodel, compare `#Script.Source` with each file's byte size (`wc -c`). Rojo syncs saved files live.
- **Use the official Studio MCP only.** Call `list_roblox_studios` at the start of every session. The `studio_id` changes whenever the place is reopened.
  - `get_studio_state` shows the mode.
  - `execute_luau` runs code in a chosen datamodel (`Edit`, `Server`, `Client`).
  - `start_stop_play` starts and stops play mode.
  - `get_console_output` reads errors.
  - `screen_capture` takes screenshots; it can take an optional camera position.
  - `user_keyboard_input` sends real key presses, and ProximityPrompts respond to them.
- Never open a second Studio copy. Never force-kill Studio. Stop play mode when you finish.

## Testing expectations

- Every change: `check.ps1` passes.
- Gameplay changes also need a Studio playtest through MCP, with an empty console, then play mode stopped. Report anything you could not test.
- **Timed effects are shorter than MCP round trips** (each call takes about 1–3 s). Before sending input, arm a recorder: `task.spawn` inside `execute_luau` that waits for the event, samples state, and writes a summary string to an attribute. Read the attribute afterwards.
- **Useful tricks:**
  - Teleport players from the `Server` datamodel by setting `root.CFrame`.
  - Fire a prompt from the `Client` datamodel with `prompt:InputHoldBegin()` / `InputHoldEnd()`.
  - Read ability state from player attributes.
- **Limit:** single-client MCP play cannot test player-vs-player effects (sword hits, soul marks). `StudioTestService:ExecuteMultiplayerTestAsync(numPlayers, args)` exists but has not been tried here.
- The real validation is the human 3-player test: **Test > Server & Clients > 3 players > Play**.

## Design philosophy

- Serve the Test 001 question. Ugly and fast beats polished and slow. Primitive parts are fine.
- Keep diffs small and local, reuse the existing patterns, and put numbers in `Config.lua`.
- When adapting an outside mechanic (like Soul Unbound), keep the feel faithful but bend it toward the idol fight. Explain each judgment call in the PR.
- Visual feedback goes on the client. State changes go through the server.

## Major implementation decisions

- **The world is generated at runtime** instead of stored in a place file. The repository stays the only source of truth.
- **One script per side** for the prototype. Adding modules or a framework needs human approval (`AGENTS.md`).
- **The boat is kinematic** and **the guardian uses `Humanoid:MoveTo`**, chosen for simplicity (see README "Known prototype compromises").
- **The idol is carried by a weld to the root.** Any teleport of the root moves the idol with it.
- **Sword hits are computed on the server** from distance and facing. There is no client hit reporting.
- **Soul Unbound (PR #5):**
  - The dash is client-predicted with a `LinearVelocity` so it feels instant. The server records the body position when the request arrives, so the client never sends a position.
  - The body is a clone of the character, with scripts, tools and billboards stripped and all parts anchored and non-collidable.
  - The values are League's max rank (10 s cooldown, 35% echo).

## Known limitations

- These are deliberate compromises: primitive art, a kinematic boat, a simple guardian, no sound, and a help line that wraps onto 2 lines.
- F, Q, and Soul Unbound have no touch or gamepad controls.
- Characters collide with each other and with walls. Dashes stop on contact (in League, Yone's dash passes through).
- Single-player MCP tests cannot cover player-vs-player features.

## Known bugs

- **The guardian can push a loose idol off the map** (on `main`; seen 2026-10-03). The guardian's `MoveTo` toward a loose idol shoves the collidable ball, and nothing stops it at the edge. In one session it crossed the water past x = 450 and fell below -500, where the idol was destroyed. Nothing respawns it, so the round can't be won until the server restarts. Not fixed yet; a separate fix task was suggested. Details are in `docs/reports/2026-10-03-yone-e-test.md`.
- CI rokit `403` flake (see Development workflow).

## Keeping this file useful

Update this file in the same PR whenever systems, controls, architecture, authority boundaries, or known bugs change. Keep it short and current: no session narratives or temporary details. Those belong in PR descriptions or `docs/reports/YYYY-MM-DD-<topic>.md`.

# Loot Goblins — AI context

Master context for a Claude Code or Codex session that opens this repository with no history. It explains what the game is, how the code works, and how we build and test it.

**`AGENTS.md` holds the rules** (branching, approval, safety). This file is background only. If they ever disagree, `AGENTS.md` wins, and you should fix this file.

## Where things stand

| Where | What it contains |
| --- | --- |
| Shared `main` (as of `84b762a`, 2026-10-07) | The **vertical slice** (PR #7: raids, loot, Heat, Guardian/totems/trouble, Poltergoblin, HUD, module split) and the double-click launcher (PR #8). |
| Unmerged: PR #9, branch `claude/sprinting-grapple-map-expansion-japzs8` | **Sprint + stamina**, the **grapple hook**, and a bigger map. Waiting for a Studio playtest and approval. |
| Unmerged: branch `feature/v2-archipelago` (stacked on PR #9) | **V2**: a 19-island archipelago, a physical sea (waves, currents, storms), physics boats, Navy pursuit, per-treasure troubles, Heat that changes the world, cannons, kegs, destructibles. Report: `docs/reports/2026-10-08-v2-archipelago.md`. Studio-tested by one AI on one client; **no human or multiplayer playtest yet**. |

Check the real state before you trust this table: `git log --oneline origin/main` and the open PRs. Update this table when a branch merges.

Everything below describes the V2 branch.

## Purpose

Loot Goblins is a Roblox game by Ethan, Ninety and Enrik. The one-sentence thesis is: *steal ridiculous treasure from dangerous islands and other players, then somehow get it home.*

V2 asks whether the loop survives a big, physical sea: **explore (awe) → steal treasure → the world reacts → escape (panic) → bank → repeat.** Going out should feel like adventure; coming home with something valuable should feel like needing to GET OUT. The design principle is **active novelty**: surprises the player participates in (a geyser to time, a gate to open, a keg to throw, a storm to steer around), not things that just happen on screen.

`docs/DESIGN_THESIS.txt` holds the long-term vision. That vision is **not** permission to build shops, XP, pets, monetization, rarity tables, trading, or saved progress.

## Core loop

1. Players spawn at **Goblin Cove** next to **the Hoard**. A raid lasts `Config.RAID_DURATION` (480 s), then a short intermission.
2. Sixteen treasures wait on 14 islands, each with a light pillar and a name tag visible from anywhere. **Value rises with distance and danger**: 1–2 g near home, 10–14 g deep in the far ring.
3. Prying treasure off its spot (hold E, 0.6 s) adds Heat and triggers that treasure's own **trouble** (a flooding vault, a volcano, tentacles, ghost ships, snapping bridges...).
4. The carrier is slowed (by weight), hunted by the world (see Heat), and can be robbed by other players.
5. Carrying treasure into the Hoard ring banks its gold. Banked treasure respawns later; treasure nobody takes grows more valuable (**interest**, +1 g per 80 s, max +3).
6. When the timer ends, the most gold wins (`Wins` +1). Everything resets.

## Controls

| Input | Action | Where |
| --- | --- | --- |
| Hold `E` on treasure | Steal from spot / grab loose treasure (ProximityPrompt) | `Loot` |
| `E` on a boat | Board it (driver seat first, then passengers) | `Boats` |
| `W A S D` in the driver seat | Drive | `Boats` |
| `Shift` in the driver seat | **Boost** (2.2 s, 7 s cooldown). On foot: sprint | `Boats`, client `Main` |
| `R` near a boat's winch | Drop or raise the anchor | `Boats` |
| `E` at a cannon | Fire it where you aim | `Cannons` |
| `G` | Throw a powder keg (take kegs from keg crates with `E`) | `Kegs` |
| Hold `Shift` on foot | Sprint (×1.45, carriers ×1.2). Uses stamina; none in water or seats | `Movement` |
| Click (sword) | Swing. Carriers can swing too: slower, shorter, weaker, and it costs 22 stamina | `Combat` |
| `F` | Grapple hook: steal loot / carrier, or hook a surface and get pulled. Not while carrying | `Combat`, client `Main` |
| `Q` | Throw held treasure | `Loot` |
| `E` with no prompt showing | Poltergoblin (cast / early return) | `Poltergoblin` |
| `E` at a zipline | Ride; jump to let go | client `Main` |
| `M` | World map | client `Map` |
| `H` | Help panel | client `Hud` |

Abilities are keyboard and mouse. Prompts and the sword also work on touch and gamepad; the rest is not adapted yet.

## Systems

All tuning numbers live in `src/shared/Config.lua`. Gameplay modules never hardcode tuning.

### World and map

- **`Archipelago.lua`** (shared) is the one list of islands (id, name, x, z, radius, ring, colour). The server builds terrain from it; the client's map, compass and signs read it. North is -Z.
- **`World.lua`** builds the environment (sea floor, boundary walls in ≤2000-stud pieces, far-sea horizon slabs, haze), Goblin Cove, and the original islands (Crossroads, Sun Temple, Crystal Isle, Shipwreck Shoals, Gull Rock, Smuggler's Cove, Twin Stacks). **`Islands.lua`** builds the near and middle new islands (Pebble, Coral Atoll, Windmill Hills, Tide Vault, Smuggler's stash). **`IslandsFar.lua`** builds the far ring (Fort Barnacle, Tangle Isle, Ember Isle, Maelstrom Rock, Frost Spire, Leviathan's Rest, Skull Rock). **`WorldKit.lua`** holds the shared helpers (parts, terrain shapes, docks, ladders, signs, cannons, bridges, geysers...).
- **Builders only describe.** They leave data in `refs` (`breakables`, `barrels`, `kegCrates`, `cannons`, `levers`, `gates`, `spinners`, `geysers`, `lavaZones`, `boostGates`, `navyBases`, `troubleSites`, `targets`) and the mechanism modules run it. Never put logic in a builder.
- About 2,300 server parts; terrain builds in well under a second.
- **Folders** under `workspace.LootGoblinsGenerated`: `Ground` (walkable; the Guardian walks on it), `Structures`, `Decor`, `Loot`, `Threats`, `Effects`, `SpiritBodies`, `LaunchPads` (also geyser vents), `Ziplines`, `Landmarks` (persistent: island signs, `HoardMarker`).
- **Streaming is on** (`default.project.json`: min 256, target 2048). Loot models, island signs and the Hoard marker are `Persistent`; everything else streams. Client code must never assume far parts exist.

### Sea (`Sea.lua`, `SeaNav.lua`, `Storms.lua`)

- `Sea` is pure math: `waveAt(x, z, t)` (three crossing swells), `currentAt` (wind drift + streams + whirlpools), `stormAt`, `shelterAt`. Swell is calmer beside land (shelter) and wild in a storm. The Terrain water is only the visual surface.
- **Currents**: the Rushing Strait and Home Stream (readable chevrons), and the Maelstrom whirlpool (strongest at mid-radius, calm in the eye).
- `SeaNav` builds a 40-stud grid from the finished terrain: water depth per cell, distance to land (shelter), and A* routes. A hull can only use cells deeper than its draft + 1.8, so deep ships cannot cross shallows.
- **Storms**: moving cells (rough water, wind, lightning). Ambient ones cross the sea every ~2 minutes after a 50 s calm; Maelstrom's treasure calls a squall; FRENZY heat sends a hunting **tempest**; Skull Rock calls **fog**. Published as one string attribute `workspace.StormData`. Lightning is **marked** 1.3 s ahead.

### Boats (`Boats.lua`)

- Real unanchored physics hulls owned by the server. Forces: buoyancy springs at six hull points toward `Sea.waveAt`, thrust (only while wet), an arcade keel that redirects drift instead of braking, banking into turns, an upright assist, and drag toward the water's own flow (currents carry you).
- Types in `Config.BOAT_TYPES`: **skiff** (fast, twitchy), **cutter** (heavy, takes a cannon, 3 passengers), **navy** patrol ship (deep draft, AI only).
- **Hull health**: crashes are measured as an unexplained speed change (capped per hit, short grace). At 0 the boat ejects everyone, goes under, and respawns at its dock after 22 s.
- **Strategy**: unoccupied boats drift unless anchored (`R`); empty boats far from every player freeze; carried treasure adds weight that cuts thrust; anyone can drive any boat (steal them, strand them).
- **Gates**: boost hoops (+speed) and kicker ramps (launch a fast boat ~13 studs up) from `refs.boostGates`. Home has a harbor jump; Coral Atoll has a kicker over the reef.
- AI boats take `boat.input = {throttle, steer, boost}` (see Navy).

### Treasure, Heat and consequences

- **Loot** (`Loot.lua`): 16 treasures in `Config.LOOT` (id, island, value, weight, carry speed, heat, respawn, trouble, visual). States `spot`, `carried` (welded above the head), `loose` (server physics; floats), `away` (banked). Steal immunity after any change of hands. **Interest**: untouched treasure gains value (`bonus`); banking pays `item.bankedValue`.
- **Heat** (`Heat.lua`): shared 0–100, tiers CALM, ALERT (25), HUNTED (50), FRENZY (80). It rises on theft and while carrying outside the ward; falls while nobody carries.
- **Escalation** (`Escalation.lua`) is what each tier *does*:
  - **ALERT**: carriers fire flares every 7 s that every player sees (beam of light); totems and Fort turrets wake; carriers glow through walls.
  - **HUNTED**: Navy patrol ships sail from Fort Barnacle at the most valuable carrier; the Guardian hunts.
  - **FRENZY**: a tempest sails in from a flank, steering slowly at the thief (slower than a boat); a second ship; rougher sea everywhere.
  - Dropping a tier stands the Navy down.
- **Threats** (`Threats.lua`): the Guardian (kinematic golem; walks Terrain and `Ground`, wades; now **leaps** to a marked circle and **throws boulders** at marked circles, with a grace period after waking), totems, rollers, carrier reveal. Handlers for new trouble plug into `Threats.handlers`.
- **Troubles** (`Troubles.lua`) — one per treasure:

  | Treasure | Trouble |
  | --- | --- |
  | Lost Compass, Giant Pearl | Gulls: the thief is revealed to everyone for 10 s |
  | Smuggler's Stash, Lighthouse Lens | Bell: the thief is revealed for 20 s |
  | Golden Gear | The windmill spins up (blades sweep the balcony) |
  | Captain's Chest | The wreck's cannon barrage |
  | Crystal Heart | Cave-in seals the tunnel |
  | Jade Frog | Quake: the rope bridges snap |
  | Pearl of the Deep | The vault gate slams shut and the chamber floods (swim the drain tunnel, or a friend pulls the lever) |
  | Tempest Trident | A squall settles on the whirlpool |
  | Admiral's Strongbox | Two patrol ships launch at once |
  | Ember Crown | The volcano rains marked lava bombs |
  | Golden Idol | The Guardian wakes and a boulder rolls |
  | Aurora Gem | Snow boulders roll down the glacier |
  | Leviathan Tooth | Tentacles slam up around the island |
  | Skull Chalice | Fog, and a ghost fleet |

- **Navy** (`Navy.lua`): AI patrol ships follow `SeaNav` routes at the most valuable carrier they can *see* (line of sight, range 520, shorter in storms). They hold at 95 studs and shell the carrier: a **marker** closes in over 1.7 s, then the shell lands. They lose you behind islands or in the shallows, search your last position for 22 s, then go home. They can be sunk (cannons, barrels, ramming, lightning). Carriers inside the Hoard ward are unreachable.
- **Blast** (`Blast.lua`): every explosion goes through `Blast.at` (players, boats, loose loot, destructibles). `Blast.strike` shows a marker first. The blast's owner takes the shove at half strength and no damage (a keg at your feet is a launcher).

### Interactive island pieces

- **Destructibles** (`Destructibles.lua`): cracked walls (any blast), gates (cannonball), rope bridges (any blast, or a quake), powder barrels (chain reactions). Broken pieces become debris and are rebuilt from stored copies on reset.
- **Cannons** (`Cannons.lua`): island emplacements (Fort Barnacle's wall, the home practice range) and the Cutter. `E` fires where you aim; the server validates range, cooldown and aim, solves the arc and flies the ball.
- **Kegs** (`Kegs.lua`): `KEG_MAX` per player from crates, thrown with `G`, fuse 2 s.
- **Mechanisms** (`Mechanisms.lua`): the windmill's sweeping blades, the Maelstrom's foam spirals, levers and gates, lava that burns. **Geysers** are animated and launch on the **client** from timestamps (attributes on the vent), so the server does nothing per frame. Boost hoops/kickers live in `Boats`.

### Movement, combat, spirit, raid

- **Movement** (`Movement.lua`): the only writer of `WalkSpeed`; owns stamina (`spend` for heavy swings).
- **Combat**: sword (carriers swing slowly and tiredly), grapple (unchanged from PR #9).
- **Poltergoblin**: unchanged.
- **Raid** (`Raid.lua`): phases, scoring, `resetWorld()` resets every system (loot, Heat, threats, Navy, storms, destructibles, mechanisms, cannons, kegs, boats, flood).
- `Players.CharacterAutoLoads` is off until the world is built, then everyone is loaded.

### Client

- `Hud.lua`: timer, Heat bar, sorted treasure board (with interest), feed, banner, objective line (says what the world is doing to a carrier), ability slots (sword, throw, grapple, keg, Poltergoblin, sprint), boat panel (speed, hull, boost, anchor, cargo drag), help.
- `Map.lua`: the world map (`M`) and the **compass strip** (Hoard, treasures, storms).
- `Weather.lua`: reads `StormData`; draws cloud walls, fog, rain and darkening; sets wave size; warns "STORM TO THE NORTH-EAST - 600 STUDS".
- `Effects.lua`: sounds from `rbxasset://sounds/*`, neon effects, **markers** (a closing ring on the ground: the one visual language for "this lands here"), lightning bolts, flares, shells, tentacles, fireworks.
- `Main.client.lua`: input, sprint, grapple, zipline/pad/geyser movement, cannon and keg input, event routing.

## Architecture

| Repository path | Rojo maps it to | Holds |
| --- | --- | --- |
| `src/server/Main.server.lua` | `ServerScriptService.LootGoblinsServer.Main` | Boot, wiring, player lifecycle, the one Heartbeat |
| `src/server/<Module>.lua` | `...LootGoblinsServer.<Module>` (ModuleScripts) | `Net`, `Util`, `Movement`, `Sea`, `SeaNav`, `WorldKit`, `World`, `Islands`, `IslandsFar`, `Boats`, `Loot`, `Heat`, `Poltergoblin`, `Destructibles`, `Blast`, `Cannons`, `Kegs`, `Mechanisms`, `Combat`, `Threats`, `Storms`, `Navy`, `Troubles`, `Escalation`, `Raid` |
| `src/client/Main.client.lua` | `StarterPlayerScripts.LootGoblinsClient.Main` | Input, client movement toys, event routing |
| `src/client/*.lua` | ModuleScripts next to it | `Hud`, `Effects`, `Map`, `Weather` |
| `src/shared/Config.lua`, `Archipelago.lua` | `ReplicatedStorage.LootGoblins` | Tuning; the island list |

- **Plain modules, no framework.** Direct calls and tiny `Util.signal()` events. Require order has no cycles: `Net`/`Util` → `Movement` → `World`/`Boats` → `Loot` → `Heat` → `Poltergoblin` → `Destructibles` → `Blast` → `Cannons`/`Kegs`/`Mechanisms` → `Combat`/`Threats` → `Storms` → `Navy` → `Troubles` → `Escalation` → `Raid` → `Main`. Injections that avoid cycles: `Loot.canBank`, `Destructibles.explode` (set by `Blast`), `Threats.handlers` (filled by `Troubles`).
- **Remotes** (`ReplicatedStorage.LootGoblinsRemotes`, recreated at boot). Client → server: `ThrowRequest`, `GrappleRequest`, `PoltergoblinRequest`, `SprintRequest`, `BoatBoostRequest`, `CannonRequest(basePart, aimPoint)`, `KegRequest(aimPoint)`.
- **`GameEvent(kind, payload)`** server → client. Original kinds plus: `Marker`, `Bolt`, `Flare`, `Shell`, `Tentacle`, `Gulls`, `NavySpawn`, `Frenzy`, `GuardianLeap`, `GuardianThrow`, `CannonFire`, `KegLit`, `TargetHit`, `Broke`, `GateMove`, `GatePass`, `BoatImpact`, `BoatSunk`, `BoatBoost`, `Quake`, `Rumble`, `Flood`, `Burn`.
- **Replicated state is attributes** (times in `workspace:GetServerTimeNow()` units). Player: `CarryingLoot`, `Kegs`, `Stamina`, `Sprinting`, `Winded`, grapple/Poltergoblin timers. Boat model: `BoatType`, `Health`, `MaxHealth`, `Speed`, `Moored`, `BoostEndsAt`, `BoostReadyAt`, `Payload`. `workspace`: `RaidPhase`, `PhaseEndsAt`, `Heat`, `HeatTier`, `GuardianState`, `StormData`. `Loot` folder: `<id>State`, `Carrier`, `CarrierId`, `ReturnAt`, `Bonus`. Vent: `GeyserPeriod/Active/Phase`, `Launch`.

Integration points new code must respect:

- **WalkSpeed:** go through `Movement`. **Player damage:** `Util.damage` + `Poltergoblin.markDamage` (or just use `Blast.at`). **Knocking loot loose:** `Loot.knockLoose` respects immunity; `Loot.dropFor` ignores it. **Teleports/resets:** cancel Poltergoblin, unseat players. **Pushing players:** `Util.knockback`. **Explosions:** `Blast.at` / `Blast.strike`, never ad-hoc. **Telegraphs:** anything dangerous must show a `Marker` first.
- **The shared E key:** a visible prompt always wins over Poltergoblin.

## Who decides what (server vs client)

- **The server owns:** treasure state and possession, steals, banking, scores, raid phases, Heat, every threat, **boat physics**, every blast, cannon/keg counts and firing, gates and levers, damage, cooldowns, WalkSpeed, teleports.
- **The client owns:** its own character physics (Roblox default): walking, the Poltergoblin dash, ziplines, launch pads, **geyser launches**, and the grapple pull toward a server-chosen anchor, plus HUD and effects.
- **What clients send:** intent only ("boost", "fire cannon X at point P", "throw keg at P", grapple aim). The server checks range, cooldown, finiteness and that the cannon/boat exists. The client never says who it hit or how much damage.

## Important files

| File | Why it matters |
| --- | --- |
| `AGENTS.md` | Rules for every AI session. Read it first. |
| `README.md` | Player-facing summary and controls |
| `docs/reports/2026-10-08-v2-archipelago.md` | V2 design reasoning, measured results, tests, limits and the human playtest checklist |
| `docs/reports/2026-10-07-sprint-grapple-bigger-map.md` | Sprint, grapple and the earlier map |
| `docs/reports/2026-10-06-vertical-slice-foundation.md` | The vertical slice's reasoning |
| `docs/WORKSTATION.md` | Setup, daily commands, Studio verification, troubleshooting |
| `docs/DESIGN_THESIS.txt` | Long-term vision (not current scope) |
| `Play Loot Goblins.bat`, `scripts/play.ps1` | One-click play for Ethan and Ninety |
| `scripts/bootstrap.ps1`, `dev.ps1`, `check.ps1`, `common.ps1` | Tool install, Rojo build/serve, checks |
| `rokit.toml` | Pinned Rojo 7.7.1, StyLua 2.5.2, Selene 0.32.0 |

## Development workflow

`AGENTS.md` is the authority. In short: sync `main`, then work on one short-lived task branch. Run checks and Studio tests, open a PR, and **never merge without explicit human approval**. PR descriptions follow `.github/pull_request_template.md`.

- **Ethan and Ninety do not use terminals.** They double-click `Play Loot Goblins.bat`. You run the Git steps and `./scripts/play.ps1` for them.
- `./scripts/check.ps1 -Fix` runs StyLua, Selene, a Rojo build and `git diff --check`. CI runs the same script.
- `check.ps1` and `dev.ps1` rebuild `build/LootGoblinsTest001.rbxlx`, a disposable output.

## Rojo and Studio MCP

- Rojo serves on `127.0.0.1:34872` (our other games use other ports; with several Studio windows open, connect each plugin to the right port by hand).
- **The Rojo plugin drops its connection each time play mode starts or stops, and Rojo 7.7.1 can crash when a watched file vanishes mid-write.** Run `rojo serve` in a restart loop, reconnect the plugin after each play session, and confirm `#Script.Source` matches the file before trusting a test.
- **Studio's rendering stalls when the display sleeps** (screenshots time out). Keep the display awake for long sessions.
- **Use the official Studio MCP only.** Call `list_roblox_studios` first. Studio MCP lists every open Studio to every AI client, so pick the one named `LootGoblinsTest001.rbxlx`. `get_studio_state`, `execute_luau` (Edit/Server/Client), `start_stop_play`, `get_console_output`, `screen_capture` (works during play, with `camera_position` / `look_at_position`), and `user_keyboard_input` all exist.
- **`require()` from `execute_luau` gives a separate module copy**, so you cannot change the live game's module state that way. For deep tests install a temporary Script in `Workspace` (Studio session only, never committed; Rojo does not manage Workspace) that requires the game's own modules and obeys a `DebugCmd` attribute.
- Never open a second Studio copy of the same place. Never force-kill Studio. Stop play mode when you finish.
- Cloud sessions have no Studio. Say so plainly.

## Testing expectations

- Every change: `check.ps1` passes. Gameplay changes also need a Studio playtest with an empty console, then play mode stopped. Report anything you could not test.
- Timed effects are shorter than MCP round trips: record state in a `task.spawn` loop and read it afterwards.
- Single-client MCP play cannot test player-vs-player features. Teleporting 1000+ studs under streaming can let a character fall through terrain that has not loaded yet; that is a test artifact, not a game bug.
- The real validation is the human multiplayer test: **Test > Server & Clients > 4 players > Play**. The V2 report has a checklist.

## Design philosophy

- Serve the loop. Ugly and fast beats polished and slow. Primitive parts and terrain are fine.
- Threats target carriers, not players. Holding treasure is what makes you the problem.
- **Commitment is not difficulty.** Deeper treasure is worth more because it is far, heavy to carry and nasty to leave, not because a lock is harder.
- **Qualitative escalation.** Heat should change what the world does (ships, storms, closed gates, falling bridges), not just raise damage numbers.
- **Telegraph everything dangerous** with a marker, and make every effect end. A skilled player can always read it, dodge it or cross it.
- **Preserve quiet.** Storms come in gaps, not constantly.
- Every mobility tool must leave carrying treasure home a physical journey.
- Keep diffs small and local, reuse the patterns, put numbers in `Config.lua`.

## Major implementation decisions

- **The world is generated at runtime**, terrain included; builders describe, mechanism modules run.
- **Boats are server-owned physics**, not kinematic and not client-owned: every player sees the same boat, crashes are real, and the server can enforce damage. The cost is input latency for the driver.
- **Sea math is separate from the visual water**, so waves, currents and shelter are cheap, deterministic and tunable.
- **Streaming is on**; far parts come and go; key landmarks are persistent.
- **The Guardian is kinematic** (no collisions, can't push loot off the map) and walks over walls.
- **Sounds** use only `rbxasset://sounds/` files. No uploaded assets.

## Known limitations

- Primitive art; the skull, ribs and fort are blocky.
- Boats beach hard against vertical sand edges; no wedge beaches yet.
- Grapple, throw, keg, cannon and Poltergoblin have no touch or gamepad controls.
- Boats pass through dock posts; the Guardian walks through walls and can't enter tunnels.
- Not tested with real players, on mobile, or on weaker hardware.

## Known bugs

- None confirmed beyond the limits above. Cannon/keg/Navy/Guardian behaviour has been exercised by a single AI client; **player-vs-player effects, windmill blade hits, the ice slide, anchoring and lightning damage were not exercised**.

## Keeping this file useful

Update this file in the same PR whenever systems, controls, architecture, authority boundaries, or known bugs change. Keep it short and current. Session narratives belong in PR descriptions or `docs/reports/YYYY-MM-DD-<topic>.md`.

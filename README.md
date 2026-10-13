# Loot Goblins

Steal ridiculous treasure from dangerous islands and other players, then somehow get it home. This branch is the V7 prototype: every raid starts on a flying pirate ship (cannons, a dive, a splash or a head-first landing), over a wider archipelago of sixteen major islands with physical boats and sea, island inhabitants, readable lanes and courses, positional world audio, regional alerts, gear, and a small saved progression (Shinies and pets). Nobody has played V7 yet: it was tested by one AI on one client.

## Play it

1. Open the Loot Goblins folder on your computer.
2. Double-click **Play Loot Goblins** (the file ending in `.bat`).
3. Wait. It gets the newest version, builds the game, and opens Roblox Studio. If Loot Goblins is already open in Studio, close that window first (other games can stay open).
4. In Studio, press the blue **Play** button at the top. The sky stays blank until you press it.
5. Press `H` in the game to read how to play.

To test with friends on one computer: **Test tab > Server & Clients > 3 players > blue Play**.

To try someone's new changes, ask your AI helper: **"Update me to the newest version of [the branch or PR name] and open the game."** The AI does the Git work and tells you what to try.

## First-time setup

Give your Codex or Claude Code the [teammate setup prompt](docs/TEAM_SETUP_PROMPT.md). The AI gets the game, installs missing tools, and checks access. Humans do not use terminals. For troubleshooting, see [the workstation guide](docs/WORKSTATION.md).

The world appears when Play starts. While editing, this game's Rojo connection uses localhost:34872; other games use their own folders and ports. The AI follows [AGENTS.md](AGENTS.md) and keeps permanent changes in shared source/content.

## The raid

Explore, take treasure, survive the reaction, escape, and bank at the Hoard. A raid lasts twelve minutes and starts on the skyship: press `M`, click an island, climb into a cannon with `E`, press `Space` to fire, then dive (hold `Space` to glide a long way, let go to plunge). Gold wins the raid; **Shinies** are what you keep between raids (open the locker with `P` to buy pets and starting gear). The map shows how dangerous each island is and which ones are on guard. Carrying treasure? An arrow on the screen points to the Hoard. Teal hoops are travel lanes; orange hoops are timed courses. The final 90 seconds pay 25% more.

## Controls

| Input | Action |
| --- | --- |
| Hold `E` on treasure | Steal it from its spot (0.6 s), or grab it when loose |
| `E` on a boat | Board it. `W A S D` drives from the driver seat; `S` is a real brake |
| `Shift` in the driver seat | Boost (2.4 s, 5 s cooldown) |
| `Space` in the driver seat | Hop the boat. `X` leaves the boat |
| `B` | Call a boat to the nearest shore if you are stranded |
| On the skyship: `E` at a cannon | Climb in. `A`/`D` turn, `W`/`S` tilt, `Space` fires, `X` climbs out. Hold `Space` while diving to glide |
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
| `F` | Grappling hook: pulls you to a surface or onto a passing boat (you take a seat), or **catches** a carrier within 40 studs (they fall; run up and press `E` to steal). While you carry, it only pulls, on a longer cooldown |
| `Q` | Throw your treasure |
| `E` (no prompt showing) | **Poltergoblin**: leave your body and run as a faster spirit for 5 s, then snap back |
| `E` at a zipline post | Ride the zipline. Jump to let go |
| `M` | World map (island difficulty, who is on guard) |
| `P` | The locker: Shinies, pets, starting gear |
| `T` | Show every treasure on the board |
| `H` | Show or hide the how-to-play panel |

Green pads and timed steam geysers launch you; orange pads are catapults that throw you a long way (dash or jump to drop out early). Ladders, ramps and ziplines take you up and across the islands; tall crags and sea stacks are for the grapple. Home has bounce pads, a practice cannon with floating targets, keg crates and a harbor jump.

## Work and feedback

Tell the AI what to change or what felt bad. It handles GitHub, documentation, checks, and shared lessons. Playtest its changes and give it approval when you want them merged. Stop the previous AI writer before switching to another in the same folder.

The single detailed source is [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): current mechanics, future direction, decisions, bugs, and test limits. Dated evidence stays in [docs/reports/](docs/reports/). V7's second-player test, the 32-player target, how the ship and the dive look, real saving, audio by ear, mobile, and broad fun/balance acceptance remain outstanding.

To ask another AI for ideas, ask your coding AI to open **GAME_GUIDE.md** and attach it. That generated file includes the complete game description, exact tuning, shared rubric/lessons, and dated history. [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md) explains the system; the AI maintains it.

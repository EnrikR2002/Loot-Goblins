# Loot Goblins

Steal ridiculous treasure from dangerous islands and other players, then somehow get it home. This branch is the V8 prototype (**Chaos & Counterplay**): every raid starts on a flying pirate ship whose cannons you aim by looking, you tumble through the air with loose limbs and skip across the sea, boats super-jump, every island's creature chases a thief out onto the water (a ram in a washtub, a crab from below, a walking whirlpool), the Leviathan hunts boats, and being hit knocks you about instead of taking everything from you. V8 was tested by one AI on one client: nobody has played it yet, and it has never had a second player.

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

Explore, take treasure, survive the reaction, escape, and bank at the Hoard. A raid lasts twelve minutes and starts on the skyship: climb into a cannon with `E`, look at where you want to land (the gold ring), click or press `Space` to fire. In the air you tumble; hold `Space` to glide (a brake and a soft landing), hold `Shift` to dive, and the sea skips you up to three times. Gold wins the raid; **Shinies** are what you keep between raids (open the locker with `P` for pets and starting gear). No treasure needs gear, and most are worth about the same (9 to 11 gold; the three nearest home 4 to 5), so pick the island you fancy.

## Controls

| Input | Action |
| --- | --- |
| Hold `E` on treasure | Steal it from its spot (0.6 s), or grab it when loose |
| `E` on a boat | Board it. `W A S D` drives from the driver seat; `S` is a real brake |
| `Shift` in the driver seat | Boost (2.4 s, 5 s cooldown) |
| `Space` in the driver seat | Hop the boat. At boost speed it is a **super jump** (about 38 studs up). `X` leaves the boat |
| `B` | Call a boat to the nearest shore if you are stranded |
| On the skyship: `E` at a cannon | Climb in. **Look** (mouse, or `W A S D`) at where you want to land, click or `Space` to fire, `X` climbs out. `M` then an island points the cannon at it. Or walk out on a wing and step off |
| In the air | `W A S D` nudge. Hold `Space`: glide (brake, soft landing). Hold `Shift`: dive |
| `E` at an island catapult | Climb in and aim it the same way as a cannon |
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

Green pads and timed steam geysers launch you; catapults are aimed like the skyship's cannons. Ladders, ramps and ziplines take you up and across the islands; tall crags and sea stacks are for the grapple. Home has bounce pads, a practice cannon with floating targets, keg crates and a harbor jump. Out at sea: a ring on the water means something is about to land there; puffer fish bounce your boat into the air (a free jump); a jump shakes off nibblers and the clam.

## Work and feedback

Tell the AI what to change or what felt bad. It handles GitHub, documentation, checks, and shared lessons. Playtest its changes and give it approval when you want them merged. Stop the previous AI writer before switching to another in the same folder.

The single detailed source is [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): current mechanics, future direction, decisions, bugs, and test limits. Dated evidence stays in [docs/reports/](docs/reports/). V7's second-player test, the 32-player target, how the ship and the dive look, real saving, audio by ear, mobile, and broad fun/balance acceptance remain outstanding.

To ask another AI for ideas, ask your coding AI to open **GAME_GUIDE.md** and attach it. That generated file includes the complete game description, exact tuning, shared rubric/lessons, and dated history. [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md) explains the system; the AI maintains it.

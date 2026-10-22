# Loot Goblins

Steal ridiculous treasure from dangerous islands and other players, then somehow get it home. This is **V13.2, Sea of Chaos**: every raid has one wild world event (meteor showers, a kraken, rogue waves, a rogue armada, powder-keg fields, whirlpools, ghost portals or giant lightning), the flying pirate ship crosses the sea so where you can drop changes as it flies, every boat has a cannon on the click, ten boat classes share one speed band and differ in what they do (an anchor that chains a rival, a wave that throws everyone away, a hook that boards a boat and spills its treasure), and on foot you build speed by running and swing on your grapple. Between raids you hang out in a harbour town, the Goblin Port (a shipyard of ten boats to earn, a menagerie of 42 pets, the wardrobe, a spyglass to watch the raid, a podium for the winners), and join the next raid when you want to; raids last six minutes and start on that flying pirate ship, guardians that **follow you home across the sea** (a stone Guardian in a tiny speedboat, the Leviathan, a ghost fleet), tornadoes, ramps and stylish boat tricks, in V10's sunlit storybook look. Between raids you spend the **Shinies** you earned in the Goblin Wardrobe: dress your goblin in ridiculous hats and coats, paint your boat, pick a trail and a trick style, learn emotes, and adopt a pet that follows you everywhere. Every boat class has its own trick on `R` (a Nitro, a rally horn, a giant spring, a three-gun broadside, a summoned tornado, a ghost decoy, a battering ram, an anchor, a breaking wave, a boarding hook). V11 to V13.2 were tested by one AI on one client, and the team has since played V13.2 (its feedback is still to be written up). Phones and controllers are untried, and Robux purchases are switched off.

## Play it

1. Open the Loot Goblins folder on your computer.
2. Double-click **Play Loot Goblins** (the file ending in `.bat`).
3. Wait. It gets the newest version, builds the game, and opens Roblox Studio. If Loot Goblins is already open in Studio, close that window first (other games can stay open).
4. In Studio, press the blue **Play** button at the top. The sky stays blank until you press it.
5. You arrive in the **Goblin Port**. Look around (the Shipyard, the pet pens, the wardrobe, the Spyglass). To go on the next raid press **JOIN NEXT RAID** at the top (or walk up the gangplank onto the little airship): nobody is sent unless they join, and the countdown starts once someone has. When it ends everyone who joined flies to the raid. Press `H` for help: in the Port it shows what is where, in a raid every control (and a button to leave the raid).

To test with friends on one computer: **Test tab > Server & Clients > 3 players > blue Play**.

To try someone's new changes, ask your AI helper: **"Update me to the newest version of [the branch or PR name] and open the game."** The AI does the Git work and tells you what to try.

## First-time setup

Give your Codex or Claude Code the [teammate setup prompt](docs/TEAM_SETUP_PROMPT.md). The AI gets the game, installs missing tools, and checks access. Humans do not use terminals. For troubleshooting, see [the workstation guide](docs/WORKSTATION.md).

The world appears when Play starts. While editing, this game's Rojo connection uses localhost:34872; other games use their own folders and ports. The AI follows [AGENTS.md](AGENTS.md) and keeps permanent changes in shared source/content.

## The raid

Explore, take treasure, survive the chase, escape, and bank at the Hoard. Between raids you are in the Goblin Port. Join the next raid when you want to (JOIN NEXT RAID or walk aboard the little airship; AUTO-JOIN keeps you in): the countdown is 60 seconds from the first goblin who joins, or 8 once everyone who joined is aboard. If a raid is already running you can watch it or join it while at least two minutes are left, and you can leave a raid early (the `H` card), giving up that raid's gold. The Port also shows the next raid's **chaos event** and the skyship's **route**. A raid is six minutes of play and starts on the skyship, which flies across the sea: for 10 seconds it waits while you climb into a cannon with `E` and aim (the cannons are locked), then it sets off. A cannon throws about 1,200 studs, so the islands you can reach change as it flies: fire (click or `Space`) when yours is in reach, or pick it on the map (`M`) and the ship fires you as it passes. The six-minute clock starts once it has crossed. In the air you tumble; hold `Space` to glide (a brake and a soft landing), hold `Shift` to dive, and the sea skips you up to three times. Gold wins the raid; **Shinies** are what you keep between raids: every raid pays some, banking and winning pay more, and trophies pay extra. Spend them in the **Goblin Wardrobe** (`P`, the 🧥 button, or the Port's shops): boats, pets, cosmetics. The boat you call with `B` is the one you chose; it changes only in the Port or at the Hoard. No treasure needs gear, and most are worth about the same (9 to 11 gold; the three nearest home 4 to 5), except the **Golden Idol** at the Sun Temple: 17 gold, and its Guardian comes after you in a boat. Whatever you steal, its guardian follows you across the sea until the gold lantern buoys round Goblin Cove: keep your speed up. Guardians never take your treasure, they hurt you: run out of health and you are **knocked out** for 5 seconds, dropping what you carry, then get up where you fell.

## Controls

| Input | Action |
| --- | --- |
| Hold `E` on treasure | Steal it from its spot (0.6 s), or grab it when loose |
| `E` on a boat | Board it. `W A S D` drives from the driver seat; `S` is a real brake |
| Click in the driver seat | **Fire your boat's cannon** where you look (every boat has one; it shoves and splashes rather than sinking anyone; not in the Port or at home) |
| `Shift` in the driver seat | Boost (2.4 s, 5 s cooldown) |
| `Space` in the driver seat | Hop the boat. At boost speed it is a **super jump** (about 38 studs up). Inside a tornado it **bails out**. `E` or `X` leaves the boat |
| `R` on the water, in the driver seat | **Your boat's ability** (each class has its own; the boat panel shows it and its cooldown). With the Anchorjack, `R` again lets go of the anchor (a swing lets go as a slingshot) |
| `R` in the air, in the driver seat | **A trick.** Press again for a combo; hold `A`/`D` to roll, `S` to backflip. Land clean for a speed burst |
| `B` | Call a boat: it races in and stops right by you, at the water's edge. With treasure at the shore a big **B · CALL A BOAT** shows |
| Drive over loose treasure | Scoop it up into your boat |
| On the skyship: `E` at a cannon | Climb in. **Look** (mouse, or `W A S D`) at where you want to land, click or `Space` to fire, `X` climbs out. `M` then an island points the cannon at a dry spot beside its treasure (the beam marks it). Or walk out on a wing and step off |
| In the air | `W A S D` nudge. Hold `Space`: glide (brake, soft landing). Hold `Shift`: dive |
| `E` at an island catapult | Climb in and aim it the same way as a cannon |
| Hold `C` in a turn, in the driver seat | **Drift**: the boat slides round the turn. Let go for a burst of speed (bigger the longer you held the slide) |
| `E` at a cannon | Fire it where you aim |
| `E` at a lever | Pull it (the Tide Vault's gate, Fort Barnacle's harbor chain) |
| Hold `E` at a signal beacon | Light it: patrol ships nearby go to look |
| `G` | Throw a powder keg (take kegs from keg crates, or from Gobbo on the home dock, with `E`) |
| Run | You **build speed** the longer you keep running (no sprint key); sharp turns and stopping lose it, jumps and swings keep it |
| `Shift` or `C` on foot | **Dash** the way you are moving, on the ground or in the air. Uses stamina |
| `Space` in the air | One extra jump per flight. Uses stamina |
| Click (sword) | Swing. Hits knock treasure loose. Carriers swing too, but slow, short and tiring |
| `F` | Grappling hook. Aim at something **above** you (a rock, a tree, a bridge, a mast) and you **swing**: `W` pumps, hold `F` to reel in, `F` or `Space` lets go and you keep the speed. Aimed level or down, it pulls you there; at a boat it puts you aboard. At a carrier within 40 studs it throws a hook that **catches** them (they fall; run up and press `E` to steal), unless they dash out of its way |
| `Q` | Throw your treasure |
| `E` (no prompt showing) | Nothing on foot (Poltergoblin is switched off for now). A step short of a boat or a cannon it tells you to step closer |
| `E` at a zipline post | Ride the zipline. Jump to let go |
| `M` | World map (island difficulty, who is on guard, tornadoes). The **minimap** is always top right |
| `P` (or the 🧥 button) | **The Goblin Wardrobe**: shop and locker for boats, cosmetics, boat paint, trails, emotes, pets and starting gear. Buying takes two presses |
| In the Port | **JOIN NEXT RAID** (or walk up the gangplank) to go on the next raid; press it again to stay in the Port; AUTO-JOIN keeps you joined. `E` at a boat in the Shipyard, at the pet pavilion or at the wardrobe opens that shop. WATCH (or `E` at the Spyglass) watches the raid: left/right change who, `Backspace` goes back. JOIN jumps into a running raid |
| `V` (or the 😀 button) | **Emote wheel**. Moving stops an emote |
| `T` | Show every treasure on the board |
| `H` | Show or hide the help card (the Port's, or the raid's controls). In a raid it has **LEAVE THIS RAID** (press twice): home to the Port, dropping what you carry, losing that raid's gold |
| Controller | `A` jump / fire, `X` boost, `B` dash / drift, `Y` leave a boat, `R2` boat cannon, `R1` boat ability / trick, `L2` hook, `L1` throw, click the right stick for the map (left stick click: dash); D-pad: down calls a boat, left throws a keg, right the wardrobe, up the emotes |
| Touch | Buttons appear when they mean something: FIRE in a cannon; BOAT, HOOK, THROW on foot; GUN, BOOST, HOP, STUNT (ability or trick) at the wheel (untried on a real phone) |

Green pads and timed steam geysers launch you; catapults are aimed like the skyship's cannons. Ladders, ramps and ziplines take you up and across the islands; tall crags and sea stacks are for the grapple. Home has bounce pads, a practice cannon with floating targets, keg crates and a harbor jump. Out at sea: a ring on the water means something is about to land there; ramps beside the hoop lanes throw a fast boat high; **tornadoes** lift you into the sky (trick on the way down); puffer fish bounce your boat into the air (a free jump); a jump shakes off nibblers and the clam. Turn and face a Watcher and it freezes. When something chases you, a red arrow at the edge of the screen points at it.

## Work and feedback

Tell the AI what to change or what felt bad. It handles GitHub, documentation, checks, and shared lessons. Playtest its changes and give it approval when you want them merged. Stop the previous AI writer before switching to another in the same folder.

The single detailed source is [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): current mechanics, future direction, decisions, bugs, and test limits. Dated evidence stays in [docs/reports/](docs/reports/). A second-player test, the 32-player target, real saving on a published place, real Robux test purchases, audio by ear, mobile, and broad fun/balance acceptance remain outstanding. Robux setup is in [docs/MONETIZATION.md](docs/MONETIZATION.md).

To ask another AI for ideas, ask your coding AI to open **GAME_GUIDE.md** and attach it. That generated file includes the complete game description, exact tuning, shared rubric/lessons, and dated history. [docs/SHARED_MEMORY.md](docs/SHARED_MEMORY.md) explains the system; the AI maintains it.

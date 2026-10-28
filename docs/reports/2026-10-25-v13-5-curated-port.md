# V13.5: The Curated Port (2026-10-25)

Ninety's brief, after the team's multiplayer playtests found the extraction loop essentially finished: **remove the four weakest Port games, make the Regatta and Cannon Golf exceptional, give the Gauntlet targeted polish, make the Port coherent, and polish the presentation of the core actions and of world chaos.** No new systems for their own sake; raids, boats, guardians, treasure, the knockout, pets and the economy unchanged. Built by Claude Opus 5.5 on branch `feature/v13-5-curated-port`, cut from `feature/v13-4-port-polish` (V13.4, PR #29, itself stacked on V13.3's PR #28; neither merged, so V13.5 stacks on the latest complete work). **Not merged**, as the brief asked.

**Read this first.** As the brief asked, **nobody played V13.5 to build it**: no AI playthroughs, no screenshots, no simulated input. It was checked by code review, StyLua, Selene, both Rojo builds, **150 automated Luau tests** in Studio's Edit mode, a numeric check of the new layouts, and **two brief starts of Play** to read the console (the second confirmed a fix the first found). Everything about feel is the team's checklist in section 9. Full description: `docs/GAME_DESIGN.md`, **V13.5: The Curated Port**.

## 1. Four games removed, cleanly

- **Gone**: the Pet Derby, Treasure Toss, the Target Ship Gallery and Crab Chaos: server modules, venues, prompts, signs, flags, signpost arms, client parts (`PlayRange`, `PlayCritters`), tuning and shapes. Every list of games (signpost, flags, challenges, the what's-next card, the help card) reads `PortGames.GAMES`, so it shows three. The code stays in Git history.
- **Kept for goblins**: saved plays and bests for the removed games, `stats.derbyWins`, and the **Derby Day** achievement and **Derby Laurel** pet hat for whoever earned them, now `unearnable` (still owned and worn, hidden from the shop and trophy list unless owned, never unlocked again). **Port Regular** asks for the three games there are; whoever has it keeps it.
- **Quests**: the four removed games' daily quests left the pool; new ones show off the rebuilt games ("Race the Regatta in 2 different boats", "Skip 3 times off the sea in one Cannon Golf shot", weekly "Race the Regatta in 4 different boats"); "Finish 5 different Port games" became "all 3". **A goblin already holding a removed quest gets today's quest for that slot at their next quest check, and a finished one is paid first.** A claimed one is left as it was.

## 2. The Tiny Boat Regatta

- **A real circuit** in the east water off the dock (about 2,150 studs, 2,000 through the shortcut): the Pier Straight's hoop chain, the Lighthouse Bend, **the Leap** (a ramp, then a reef across the lane's middle with gaps at its edges and a gold hoop only a jump reaches), **the Flume** (a hairpin with a current that carries you round: the banked turn), Barrel Alley, **the Teeth** (a narrow channel through the rocks, or the safe way round), the Bumper Chicane, Cannon Corner and the Home Straight. Ten checkpoints; a fall puts you back facing on.
- **Test drives**: in the lobby pick the Racing Tub or **any of the ten classes**, owned or not; or press **TEST DRIVE IT** on any boat in the showroom (it takes you to the dock). The boat is a loaner the Port builds for the lap and takes back; it handles as in a raid and **its `R` ability works on the course** (only there in the Port). After a test drive in a boat you do not own, the results card offers **🛒 SHOWROOM**.
- **Fair records**: bests are kept per boat. The **FASTEST REGATTA** board now takes **Racing Tub laps only** (everyone in the same boat), and every boat has the week's **CLASS RECORD** on a board at the dock. The old ring course's board is retired: this week's places on it are still paid.
- **Presentation**: start lights (three red, then green), a ring at every gate, ⚡ THROUGH THE TEETH!, splits and places, fireworks and white water at the line, 🏆 FIRST ACROSS THE LINE!.

## 3. Cannon Golf: water skipping

- **Six holes in strokes, par 16**: the Puddle Jump (a lob), the Skipping Stone (too far to fly: skip it), the Bend (stacks in the way: skim wide and curve), the Lily Pad (small and close), Over the Top (lob the ridge or skip round it) and the Kraken's Crown (an islet in a reef: through the gap, then glide to stop on it).
- **The skimmer** (`Config.DIVE.SKIM`): look **down** for a skimmer and it skips across the sea like a stone, each skip lower and flatter; look **up** for a lob and it drops where it lands; hold `Space` in the air to stop skipping; `A`/`D` curve it (at half the usual steering). The panel says honestly whether this shot will skip. The skydiver's sea is unchanged.
- **Scoring**: land on the target to hole out (in the cup: that stroke; elsewhere on it: one putt more); a splash costs a stroke and you are back in the cannon at once; after par + 1 shots it is picked up at par + 3. The **CANNON GOLF** board is now fewest strokes (the old points board retired and still paid).
- **Presentation**: a chase camera through the skips that holds on the landing, SKIP x2! callouts with rising chimes, splashes as big as the arrival, golf names on landing (HOLE IN ONE!, BIRDIE!), the card on the results.

## 4. The Grapple Gauntlet (targeted)

Hooks have a big invisible catch (aim near the gold ball and you swing from its middle); the next leg's hooks glow; a fall faces you at the next platform; splashes are counted; a shortcut says how many platforms it skipped. The course is unchanged.

## 5. The Port

The Derby's lawn is **THE LOOKOUT** (benches, a lantern tree, a telescope), Crab Chaos's beach is **THE 19TH HOLE** by the golf jetty (a bonfire with log seats, deck chairs, parasols), there is a **REGATTA STAND** facing the start line and a lit **PROMENADE** where the Toss stood; **flags in each game's colour** lead from the square to its venue, and the **Hall of Legends** has a column of gold light over it. Everything stands on what a ray down finds and keeps off buildings (the boot log: 31 pieces placed, 3 spots kept off). The Blender overhaul was not started, as the brief asked.

## 6. Feel and world chaos

- **Core actions**: dust and a jolt when you prise treasure off its spot; LOOSE! when it is knocked free; a shower of gold coins and "+N GOLD" when you bank; planks and a thump as hard as a boat crash; powder smoke on cannon and skyship launches; dust and clods on a head-first landing; columns of white water on fast splashes; dust and rock off the Guardian's smash; a thump and KO! on a knockout. Only `rbxasset://sounds/` sounds; no HUD text added.
- **World chaos**: each episode has a **mood** (a flurry, the usual, or a big one, announced, with a longer calm after), so raids stop feeling the same. A meteor's blast now rolls on as a **shockwave** that throws boats and swimmers, knocks back pursuers and staggers guardians as far as it reaches. Sharper warnings and impacts for the others: the kraken's swelling dome, the rogue wave's roar, the armada's smoke and whistle, barrel staves, whirlpool spouts, crackling SUPERCHARGED boats. Cleanup is unchanged in kind (the chaos folder and `Debris` timers); recovery rules (hull floor, Impact's grace) unchanged.

## 7. Economy, quests and boards

No new currency or reward stream. Test drives pay from the Regatta's one daily cap (six paid runs, whatever the boat); golf from golf's; class records pay nothing; a removed game's finished quest is paid once when replaced; the retired boards pay their periods exactly as before. **No profile version change**: the new bests are new keys in maps the profile already has, which a V13.4 server keeps untouched.

## 8. Tests and checks

- **StyLua** clean, **Selene** 0 errors and 0 warnings, both **Rojo** builds.
- **Luau tests: 150 passed, 0 failed** (Studio Edit mode, test files loaded over a loopback server, the place freshly built from this branch; re-run after the fixes on fresh module copies). New or rewritten: the removed games gone from every list, their trophies kept and unearnable, Port Regular's goal; per-boat Regatta bests and the old course's best left alone; the one daily cap across eleven boats; the circuit's lane off the coast, inside the Port and clear of the dock, its checkpoints in order, the Teeth's two ways apart and its rocks off the safe lane, the grid for the biggest boats, obstacles placed right, abilities only on the course, `MIN_TIME` only refusing the impossible; the Gauntlet's facing respawns and hook legs; golf's aim and elevation limits, the skimmer's rules (skips flatter each time, steep plops, glides never skip, a skydiver unchanged) and the longest skimmer staying in the Port; the six holes reachable as meant; strokes, putts, pickups and par names; retired boards still paying; removed quests replaced and paid; chaos moods and the shockwave.
- **Layout by numbers first**: the circuit and the holes were checked in a script before building, which found the Flume's lane past the Port's edge and the Teeth's rocks clipping the safe way (both fixed; the same checks are now in `PortGamesSpec`).
- **Two boot checks** (Play started, console read, stopped). The first: no errors; every venue, the circuit, the holes, the lights, the records board and the beacon built, no removed venue; **but the Port's new furniture was missing** (section 10). The second, after the fix: 31 pieces placed, 3 spots kept off, 12 barrels, no solid furniture overlapping a building, console free of errors.
- **Not run**: any game, lap, shot or effect by hand; a second player; a phone or controller; real DataStores (the class records used Studio's stand-in).

## 9. Human playtest checklist (three people, about 30 minutes)

Start: double-click **Play Loot Goblins**, then **Test > Server & Clients > 3 players > Play**.

1. **Find your way**: from the square, follow the coloured flags to the Regatta, the golf jetty and the Gauntlet. Does the Port feel tidier? Can you see the Hall's gold light?
2. **Regatta, Racing Tub**: race twice. Is the lap fun? Do the Leap, the Flume's current, the Teeth's gap and the chicane feel like choices? Any corner that feels unfair, any long dull bit?
3. **Regatta, test drives**: each of you pick a different boat (one you don't own). Do the boats feel different? Try every `R` ability on the course. Does 🛒 SHOWROOM make you want the boat?
4. **TEST DRIVE IT**: from the wardrobe's showroom: does it take you to the race smoothly?
5. **Records**: is the CLASS RECORDS board at the dock readable? Does a new record feel like a moment?
6. **Cannon Golf**: play all six holes. Is it clear when a shot will skip (SKIPS / LOB)? Do skips feel spectacular? Is the chase camera good? Too hard, too easy? Which hole is best, which worst?
7. **Gauntlet**: are the hooks easier to catch? Do the glowing hooks help?
8. **A raid with chaos**: watch for a meteor's shockwave, a "big one", and the new splashes, planks and coin showers. Too much, too little?
9. **Quests**: anything odd on the Quest Board after updating (it should show three quests, none for a removed game)?

**How to report**: say what felt bad or confusing, and send a screenshot of any red error (View > Output). Numbers are easy to change: name the game, the hole or corner, and what felt off.

## 10. Bugs found and fixed before anyone played

1. **The Port's new furniture all came out missing on the first boot**: terrain poured in the same frame does not answer a ray yet, so every spot looked "built on" and was skipped (only the signs, which don't ask, appeared). `Port.curate` now runs after every building exists and waits until the terrain answers; the boot log counts what it placed.
2. The Regatta stand's first spot was on the menagerie pens' floor (moved south of the dock).
3. The first circuit's Flume lane reached past the Port's edge, and the Teeth's rock walls clipped the safe way's lane at both ends (walls now stop short of the channel's mouths).
4. Barrel Alley's last two barrels sat in the Teeth's fork (twelve now).
5. Marking the Derby Laurel with the catalogue's existing `retired` flag would have taken it off its owners: it is `unearnable` instead.
6. A test's arithmetic: the day's Shiny cap, not the run cap, stopped its laps (the test was fixed, not the game).

## 11. Known limitations

- **Unplayed and unlooked-at**: every lap, shot, ability on the course, effect and piece of furniture; placement was checked by numbers and the boot log only.
- **First guesses**: the Regatta's medals (23 / 28 / 36 s) and the Flume's 24 studs/s; golf's pars, medals (14 / 17 / 21), the skimmer's numbers and the pickup; the moods and the shockwave.
- A test drive trusts its driver's client like any boat; a Stormrunner's twister on the course can catch rivals (by design, untested).
- The class records' DataStore has only run against Studio's stand-in.

Studio was opened once through `./scripts/dev.ps1 -OpenStudio` for the tests and the two boot checks; it is still open in Edit mode (the place in `build/` is disposable). Close it with File > Exit when done.

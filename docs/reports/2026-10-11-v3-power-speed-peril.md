# Report: V3, power, speed and peril

| | |
| --- | --- |
| Date | 2026-10-11 |
| Request | Ninety's "V3 One-Shot: Power, Speed & Peril" prompt |
| Agent | Claude Code (Opus 5.5), local session on Ninety's machine with Roblox Studio MCP |
| Branch | `feature/v3-speed-agency-danger`, **stacked on** PR #10's branch `feature/v2-archipelago` (itself stacked on PR #9) |
| Pull request | PR_LINK, base branch is `feature/v2-archipelago` |
| Merge status | **Not merged.** Nothing was merged, including PR #9 and PR #10. Needs a human playtest and explicit approval. |

## 1. Summary

The V2 playtest said the bigger world was worth exploring, but the goblin and the boats were too slow and the danger too tame. V3 makes the player powerful and makes the world able to challenge that power.

- **Movement.** Running is 40% faster and never costs stamina. Stamina now pays for the exceptional moves: a stronger sprint, a new **dash** (`C`, works in the air) and one **air jump** per flight. Carrying treasure barely slows you; instead the treasure's weight makes every stamina move cost more. The grapple is faster, reaches farther, hooks **moving boats** (and seats you on them), and carriers can use it to pull themselves around.
- **Boats.** Top speed is up 50% (skiff 72 to 108, cutter 56 to 86), with a punchy launch, a real brake, a long coast, and a **drift** (`C` at the wheel) that slides the boat round a turn and pays out a speed burst when you let go. Crashes hurt less, hulls repair themselves slowly, boats ride up gentle beaches instead of stopping dead, and a clean landing off a ramp gives a burst.
- **Boat responsiveness.** A driven boat's physics now run on the driver's own client, so steering answers on the next frame instead of a network round trip later. Measured with 100 ms of simulated lag each way: **64 ms** from key to motion, against **400 ms** the old way. The server still owns hull health, crashes, sinking and cooldowns, and takes a boat back if it moves in a way the physics could not. One setting switches back to the old way for comparison.
- **Danger.** Navy ships no longer follow from behind. They appear on the horizon *ahead* of the thief, sail an intercept, fire a spread along your course, and make a **committed charge** after a horn (turn and it misses). At FRENZY a second ship takes the water between you and the Hoard and **lays mines**. The Guardian is as fast as a carrier who only runs, leaps and throws farther, and gains a **stomp**: a ring that races out along the ground and only hits whoever is standing on it. Storms move faster and carry **waterspouts** that fling a boat into the air.
- **Balance.** Heat builds faster while carrying (trips are shorter now), raids are a minute shorter, and the Navy sits between a cutter and an empty skiff in speed, so the boat you chose and the weight you carry decide whether you run or fight.

**Honest status.** Everything was tested by one AI on one client in Studio. Nobody has played V3. The systems work; I measured speeds, delays, damage and frame times, and those numbers are in section 9. I cannot tell you whether it *feels* good. Three things limit what I could check, and all three are spelled out in section 10: Studio's window was in the background the whole session, so the test client ran at 15 frames per second; near the end the display went to sleep, so the last screenshots and keyboard tests could not be done; and there was only ever one player.

## 2. How I read the prompt, and what I did not do

- **Branch and PR.** I verified the state before starting: PR #9 and PR #10 were both open and unmerged, and `origin/feature/v2-archipelago` was at `61fa5a7` with a clean working tree. V3 branches from that commit and its PR targets `feature/v2-archipelago`, as the prompt asked. This deviates from "PR against `main`" in `AGENTS.md`, on purpose and at the human's request. **Merge order: #9, then #10, then this.**
- **No new islands, progression, shops, weapons or customization.** The map is unchanged. No terrain was edited.
- **A limited number of new moves.** Two on foot (dash, air jump) and one at the wheel (drift), all on one key (`C`) plus the jump key. I left out wall-running, sliding and a sword lunge: each would have been a feature for its own sake.
- **One architecture change, because the old structure prevented the goal.** Boats were server-owned physics, which cannot feel immediate under real latency. The prompt asked for this to be investigated and for "the best practical Roblox implementation"; section 6 explains what changed, what it costs and how to switch it off. `AGENTS.md` asks for human approval of a new networking strategy. I am treating the prompt's explicit request as that approval for building it, and flagging it here so you can confirm or reverse it.
- **I asked before starting.** The prompt arrived as pasted text with no message, so I confirmed with Ninety before running it.

## 3. Player movement and stamina

The V2 rule was "you jog, and sprinting is rationed". The V3 rule is "you run, and stamina buys the exceptional".

| | V2 | V3 |
| --- | --- | --- |
| Run speed | 20 | **28**, always available |
| Sprint | 29, 5 s of stamina | **38**, 9 s of stamina, also works while swimming |
| Stamina refill | 25/s after 0.8 s | 32/s after 0.6 s (a full bar in about 3 s) |
| Jump | Roblox default (50) | 56: a little higher and longer |
| Dash | none | **`C`**: about 14 studs in 0.17 s, on the ground or in the air; 18 stamina, 0.9 s cooldown |
| Air jump | none | **one extra jump per flight**; 12 stamina. A grapple pull gives it back |
| Swimming | 70% speed | 85% speed |
| Ziplines | 70 | 90 |

- **Stamina never slows a normal run.** Running it dry by sprinting leaves you "winded": no sprint until it refills to 25, but you still run at full speed and can still dash as soon as you can afford it.
- **The moves chain.** A grapple pull keeps 60% of its swing when it ends (was 35%) and restores your air jump, so pull, jump off, air jump, dash is one continuous line. An air dash cancels your fall for its duration, so it crosses gaps.
- **Dash and air jump are played on the client at once** so the key feels instant, and the server takes the stamina and enforces the cooldown. This adds no new trust: Roblox already gives each client its own character physics (walking, the grapple pull and the Poltergoblin dash already worked this way).
- **The field of view follows your speed** (on foot and in a boat), and kicks wider for a dash, a boost or a launch.

### Carrying treasure

A carrier used to be slow (12 to 19 against 20). Now a carrier is only a little slower, and vulnerable in other ways.

| | V2 | V3 |
| --- | --- | --- |
| Carry speed | 12 to 19 (60% to 95% of a jog) | 21.5 to 27 (77% to 96% of a run) |
| Carrier sprint | 14 to 23 | 27 to 34 |
| Stamina costs while carrying | same as empty-handed | **+12% per unit of the treasure's weight**: a Leviathan Tooth (weight 6) makes sprint, dash, air jump and sword swings cost 1.72 times as much |
| Grapple while carrying | not allowed | pull only (no stealing), 5 s cooldown instead of 1.4 s |

So the heaviest treasure still runs at 21.5 and sprints at 27, but its carrier gets about five seconds of sprint and three dashes from a full bar instead of nine seconds and five. Everything else that made a carrier vulnerable is unchanged: they are lit up for everyone, hunted by the world, swing a weaker sword and cannot steal. Whether this is the right balance is the first thing to find out with people.

## 4. Boats

### Handling

| | V2 skiff | V3 skiff | V2 cutter | V3 cutter |
| --- | --- | --- | --- | --- |
| Top speed | 72 | **108** | 56 | **86** |
| Acceleration | 44 | 84 | 28 | 56 |
| Boost top speed | 104 | 151 | 81 | 120 |
| Boost cooldown | 7 s | 5.5 s | 7 s | 5.5 s |
| Hull | 150 | 160 | 380 | 420 |

Measured in Studio (section 9): a skiff reaches 51 in half a second, 97 in three seconds and settles at 104 to 109; a cutter settles at 84 to 86.

- **Launch.** Extra thrust from a standstill that fades out by half speed.
- **Brake.** `S` against your motion is 1.7 times the engine, so it is a brake and not a slow reverse (32 to 0 in 0.3 s).
- **Coast.** Off the throttle a hull keeps most of its speed for a couple of seconds (99 to 49 in 1.4 s), so momentum is something you carry through a manoeuvre.
- **Turning.** Sharper when slow, wider at top speed, and an ordinary turn sheds far less speed than before (a 68-degree turn at 106 cost 7 studs/s; an early V3 build that still used a slip rule close to V2's lost 50 of 125 in a 90-degree turn).
- **Drift.** Hold `C` in a turn at speed. The hull swings out to a slide angle (up to about 57 degrees) and holds it instead of spinning, the boat keeps its speed, and the slide charges a meter. Let go and the keel bites: the boat snaps onto its new heading with a burst (+16 after about 0.6 s of sliding, +28 after about 1.4 s) and a higher top speed for a second or so. Measured: an 87-degree change of course in about 1.5 s, leaving at 121 after entering at 99. Steering the other way swings the hull straight back.
- **Air.** A little steering in the air, a stronger self-righting, and a **clean landing** (upright, pointing the way you travel) gives a +12 burst. The harbor jump measured 16.7 studs high and about 60 studs long.
- **Capsizing.** A hull that lies capsized for a second pops back upright with a hop. (V2's nudge did not work on an upside-down hull: section 8.)

### Crashing, beaching, repairing

- **Crashes are gentler and measured differently.** The server watches every hull's velocity and calls it a crash when the change over a twentieth of a second is more than the engine and the keel could have produced. A full-speed hit on a wall costs 45% of a skiff (the cap for one hit; measured). By the same formula a hit at 60 costs about 28% and a bump at 30 almost nothing (not measured).
- **Boats ride up beaches.** An invisible sloped "bow skid" in front of each player hull lets it climb a gentle shore and slide to a stop instead of hitting it like a wall. Dragging a hull fast over ground scrapes it (16 hull per second). Out of the water the engine does nothing, but `W` or `S` shoves the hull along at up to 12 studs/s, so a beached boat can always be worked back to the sea.
- **Steep edges are still walls.** I tried to make fast boats skim over the low reef at Coral Atoll. It does not work: the reef edge stops a hull dead (46 damage at 100). I left it, because it keeps the atoll's gates and kicker ramp meaningful.
- **Hulls repair themselves:** 4 per second after 9 seconds without damage. A mistake is something you recover from.
- **Sunk boats come back in 16 s** (was 22).

### What each boat is for

- **Skiff:** the fastest and the best drifter. Two bad crashes sink it.
- **Cutter:** slower than a patrol ship, so it cannot simply run. It carries the cannon and three passengers, takes 60% crash damage and deals 1.8 times as much when it rams.
- **Patrol ship (AI):** 88, with wide turns. Faster than a cutter, slower than an empty skiff, about level with a skiff carrying heavy treasure. No bow skid: it bumps a shore instead of climbing it.

## 5. Danger

### The Navy

V2's ships sailed from Fort Barnacle toward where you were and held at 95 studs, shelling. V3's ships have jobs.

| | V2 | V3 |
| --- | --- | --- |
| Speed | 54 | 88 (about 100 while boosting) |
| Where they come from | always the fort | the fort if it is within 900 studs of the thief; otherwise **the horizon, 750 to 950 studs away, on the side the thief is sailing home through, and in plain sight** |
| Where they sail | the thief's position | **hunter:** where the thief will be (up to 5 s ahead). **blocker:** 280 studs along the thief's line home |
| Up close | hold at 95 studs and shell | run alongside at 110 studs firing a three-shell spread along your course; every 11 s a **charge** |
| The charge | none | A horn and a banner for the target, then 2.6 s on one bearing, aimed where the thief will be *if they hold their course*. The ship does not correct it |
| Mines | none | A blocker ahead of the thief sows one every 2.4 s. Bright red, tall beacon, never move, go off for any hull or swimmer (the Navy included), and any blast sets off the mines it reaches |
| Shells | 1.7 s warning, 60 hull | 1.5 s warning, 55 hull |

- In a test the charge worked as designed: against a skiff that kept going straight it hit; against a skiff that drifted away after the horn it "thundered past" and needed about seven seconds to come about, by which time the skiff was 550 studs away.
- **Their routes keep off the coasts** and they slow for land ahead, because a ship at 90 turns too wide to shave a headland (an early version crashed into Smuggler's Cove).
- Everything that made them a puzzle in V2 still holds: they need to see you, they cannot cross shallows, they search your last position and give up, and they can be sunk.
- Heat sends one hunter at HUNTED and adds a blocker at FRENZY. The Admiral's Strongbox still launches two at once.

### The Guardian

| | V2 | V3 |
| --- | --- | --- |
| Speed | 16 (19 at FRENZY) | **27** (32 at FRENZY) |
| Leap | 28 to 95 studs, every 7 s | 30 to 150 studs, every 4.5 s |
| Boulder throw | 80 to 200 studs, every 6 s | 70 to 260 studs, every 4 s |
| Stomp | none | **new** |

- At 27 it outpaces a carrier who only runs (21.5 to 27) and loses to one who sprints (27 to 34). Stamina is the lifeline, and a straight line is how you spend it.
- **The stomp.** When its target is within 60 studs it raises both fists for 0.8 s (the whole reach of the ring shows faintly on the ground, with a banner), then a ring races outward at 55 studs/s for 75 studs. It only hits players who are standing on something as it passes under them (14 damage, thrown, treasure knocked loose). A jump, an air jump or a dash off a ledge clears it. In the test a standing carrier was hit, and one that jumped on time was not.

### Storms and the sea

- Storms cross the sea at 16 to 28 (was 9 to 16) and the FRENZY tempest chases the thief at 42 (was 15): still slower than any boat, now faster than anyone on foot.
- **Waterspouts.** Each storm carries two twisters (the tempest three) circling its heart. One throws whatever it catches into the air and sideways (a boat: up at 64, 14 hull damage). They are tall columns you can see from across the storm: a hazard to steer round, or, for the brave, a launch into a clean-landing burst.

### Heat and the rest

- Carrying heats the world faster (0.8 per second for a mid treasure, was 0.5; the cap is 2.0, was 1.2) because trips are shorter. Heat cools a little slower (0.6, was 0.8).
- Totem shots fly at 125 (was 85) and lead more; the temple boulder rolls at 44 (was 30); avalanche boulders start at 28 (was 18).
- Every danger still announces itself: a ring, a horn, raised fists, a beacon. Nothing new is unavoidable.

## 6. Who simulates a boat (the one architecture change)

**Before.** The server simulated every boat. The driver's keys went to the server, the server moved the boat, and the result came back: at least one network round trip plus Roblox's smoothing before the boat visibly reacted.

**Now.** The physics live in one shared module, `src/shared/BoatSim.lua`, and run on whichever machine owns the hull:

- an empty boat, an anchored boat or a Navy ship: the server, as before;
- a boat with a driver: **the driver's client** (`src/client/BoatDrive.lua`). The server hands the hull's network ownership to the driver when they sit down and takes it back when they leave.

The sea's math (`Sea.lua`) moved to shared for the same reason: both machines must float the boat on the same waves and currents. The server sends the static part (currents, the shelter map, the gates) once, and the client follows the weather through two attributes.

**What the server still owns:** hull health, crashes and scrapes (measured from the hull's velocity on the server, the same way whoever simulates), sinking, repair, anchors, who may sit where, the boost cooldown, and every blast. A blast or a waterspout pushes a driven hull by telling its driver's client to apply the push.

**What stops a cheating client.** Roblox lets the owner of a part move it however it likes, so the server checks every driven hull every frame: no faster than the boat's top speed (with boost if the server granted one) times 1.15 plus 40 for currents and bursts; no higher than 80 studs above the sea; no jumping from place to place. A hull that breaks a rule for 1.2 seconds (or jumps once) is taken back and driven by the server for 5 seconds: slowed to its limit if it was only too fast, stopped and put back where it last behaved if it jumped or flew. Under 100 ms of simulated lag a boost and two drifts at up to 159 studs/s raised no strikes and no false crash.

**What it does not stop.** The margins are generous on purpose, so that currents, bursts and lag never punish an honest driver. A cheater can therefore gain a little more than a permanent boost's worth of speed inside them, can turn tighter than the physics allow, and can avoid crash damage by never producing a sudden change of velocity. Shells, mines, lightning and sinking still apply to them, because those are the server's. This is the same class of trust the game already gives every client over its own character.

**How to switch it off.** `Config.BOAT_CLIENT_PHYSICS = false` makes the server simulate every boat again. The same physics module runs either way, so you can compare the feel directly.

**Measured** (section 9): 64 ms from key to motion with driver-owned physics against 400 ms server-owned, both with 100 ms of simulated lag each way.

## 7. Design decisions worth challenging

| Decision | Why | Cost or risk |
| --- | --- | --- |
| Run at 28 for free; stamina only for sprint, dash and air jump | The playtest said the player felt slow and restricted | The 19 islands are effectively smaller. Some routes may now be too easy; none were re-walked by a person |
| Loot costs stamina, not speed | "Vulnerable" should not mean "sluggish" | Carriers escape more easily on foot. If robbing a carrier becomes too hard, raise the per-weight cost before lowering their speed |
| Carriers may grapple-pull (5 s cooldown) | Expressive escapes while carrying | A carrier can now climb straight up some cliffs |
| One key (`C`) for dash and drift | Fewer keys to learn | Nothing on touch screens yet |
| Driver-owned boat physics | Steering that answers at once | A cheating client gets more room (section 6) |
| The Navy is about as fast as a laden skiff | Running in a straight line should not be an answer | With no boost and no steering a laden skiff is caught. That is intended, but only a playtest can say if it is fun or oppressive |
| The charge does not correct its aim | "I saw that coming" needs a commitment to read | A ship charging past may hit an island. It takes the damage |
| Mines chain | Shooting a gap, or watching one cook off, is a story | Three mines 14 studs apart sank a skiff and nearly killed its driver in a test. Real spacing is 50 studs or more, so chains should be rare |
| Guardian at 27 | It should be a threat to a carrier on foot | A carrier with no stamina cannot outrun it at all |
| No reef skimming | It does not work with Roblox's terrain edges | Coral Atoll plays as in V2 |
| Raid 7 minutes (was 8) | Everything is faster | A guess |

## 8. Bugs found and fixed while testing

1. **An idle swimmer sank to the sea floor.** The sword's handle was real-density metal and outweighed a goblin's buoyancy. It is in V2 and on `main` too. The sword parts are now light.
2. **A capsized boat stayed capsized.** V2's recovery was a push, and an upside-down hull has no buoyancy points in the water, so it just sat there. A hull capsized for a second now pops upright.
3. **A blast shoved a seated player and the boat separately**, flinging the boat twice. Seated players now move with the hull.
4. **A hook thrown at a passing boat flew behind it.** At 60 studs/s a boat is several studs ahead of where the player sees it. Aim that passes within 18 studs of a moving boat now catches the boat.
5. **A grapple onto a moving boat left the player in its wake.** The pull now goes to the middle of the deck, rides along with the boat, and the server seats the player (only on the boat the server itself just hooked for them).
6. **Boat top speed depended on frame rate.** The first calibration was done on a client that turned out to be throttled to 15 frames per second, with a step limit that cut its forces to 75%. Boats now integrate the real frame time (down to 10 fps), and instead of a tuned constant the physics *measure* how much Roblox's Terrain water slows each hull and cancel it. `maxSpeed` in `Config.lua` is now the speed a boat really reaches (skiff 104 to 109 for 108; cutter 84 to 86 for 86).
7. **A boat could drive across an island** once it had a bow skid and low friction. Out of the water the engine now does nothing beyond a slow shove.
8. **A beached boat could not get off** (the reverse shove was weaker than the friction). Fixed by the same shove.
9. **Moving a driven boat from the server was undone by its driver's client** and then caught as a teleport. `Boats.place` takes the hull back first; respawning uses it.
10. **A full-speed hit on a beach registered no crash** with the first, longer measuring window. The window is now a twentieth of a second.
11. **Navy ships climbed onto beaches** (the skid) and **crashed into headlands** (routes too close to land at their new speed). AI ships have no skid, keep off the coasts and slow for land ahead.
12. **The first ship reached a parked boat five seconds after it was announced.** They now appear 750 to 950 studs out and do not charge in their first nine seconds.

## 9. Measurements

All in Studio play mode, one client, on Ninety's machine. "Measured" means a script read the value from the running game.

### Movement and boats

| What | Result |
| --- | --- |
| Run, sprint | 28, 38 studs/s |
| Dash | 83 to 85 studs/s for about 0.17 s |
| Jump, then air jump | apex 9 studs, then to 17 studs above the start |
| Stamina | dash 100 to 82, air jump to 70, full again after 2.5 s rest |
| Skiff from rest | 51 at 0.5 s, 70 at 1 s, 97 at 3 s, then 104 to 109 |
| Skiff boosting | up to 146 (nominal 151) |
| Cutter from rest | 37 at 0.5 s, 77 at 3 s, then 84 to 86 |
| Patrol ship | about 84 to 91 cruising, 100 to 103 while boosting |
| Turn at speed | 68 degrees in 1.1 s, 106 to 99 |
| Short drift (1 s) | course changed 87 degrees in about 1.5 s; 99 in, 121 out |
| Long drift (2.2 s) | held a 55-degree slide at 113 to 118 |
| Coast | 99 to 49 in 1.4 s |
| Brake | 32 to 0 in 0.3 s |
| Harbor jump | 16.7 studs high, about 60 long, landing burst 65 to 74 |
| Boost hoop | 59 to 94 at the hoop, 117 a moment later |
| Wall at 104 | 72 hull (the 45% cap) |
| Coral reef edge at 100 | 46 hull, boat stopped |
| Gentle beach at 102 | 0 to 41 hull depending on the spot, plus about 4 scrape; slid 20 to 38 studs up the beach |
| Grapple onto a boat doing 50 to 67 | on the deck in 0.4 s, seated as driver |

### Responsiveness

Studio's network simulator set to 100 ms on every received packet (about 200 ms round trip). The client was running at 15 frames per second (see the next table), so one frame is 67 ms.

| Who simulates the boat | Key to motion | Steer to turning |
| --- | --- | --- |
| Driver's client (V3) | 64 ms | 65 ms |
| Server (V2's way, same code) | 400 ms | 334 ms |

The 64 ms is one frame of that throttled client: with driver-owned physics the delay is the frame time and does not depend on the network. On a client at 60 fps I would expect one or two frames (17 to 33 ms), and the server-owned figure to be somewhat lower than 400; **I did not measure either.**

### Performance

| Metric | V2 report | V3, busy scene |
| --- | --- | --- |
| Server frame, average / worst | 16.67 / 20.3 ms | 16.67 / 19.9 ms (60.0 fps) |
| Server script time per frame (`HeartbeatTimeMs`) | about 0.14 ms | 0.73 to 0.91 ms |
| Server physics step | not reported | 0.11 to 0.39 ms |
| Instances (server) | about 48,000 | about 48,250 |

The busy scene was FRENZY heat with a hunting tempest and a second storm, five waterspouts, a patrol ship, a driven skiff drifting and boosting, and 2 to 8 other boats awake.

- **The server's script time per frame rose about five times, and it is still under 1 ms of a 16.7 ms frame.** The new per-frame work is the watching of each awake hull, the Navy's steering probes, the waterspouts and the mines.
- **Client frame rate: not measured.** Studio's window was in the background for the whole session, and Studio caps a background window at 15 fps (measured: exactly 15.0 fps while standing still in an empty scene). Client script time was 0.68 ms per frame and client physics 0.12 ms, and the driver's client sent about 66 kbps while driving. Whether V3 holds 60 fps on a real client is **unknown**.
- **Mobile, low-end hardware, several players, real latency:** not tested. The costs that grow with players are one hull check per awake boat per frame on the server, and one boat simulation per driver on that driver's own client (which is work the server no longer does).

## 10. Tests performed, and their limits

### Limits that apply to everything below

- **One AI, one client.** Nothing between two players was exercised.
- **The client ran at 15 frames per second** throughout (Studio in the background). Speeds, damage and timings are valid; nothing here says how it looks or feels at 60.
- **Keyboard tests** used Studio MCP's injected keys. Some checks instead called the game's own remotes from the test client, or had the server drive a boat with the same physics code; the list says which.
- **Near the end the display went to sleep.** After that, rendering stopped, injected keys stopped arriving and screenshots timed out. The checks I could not do because of it are listed under "Not verified".

### Verified working

- `./scripts/check.ps1`: formatting, lint, Rojo build and whitespace all pass. Console empty at the end of every test session.
- **Movement** (keyboard): run, sprint, dash on the ground, jump, air jump, air dash; stamina spent and refilled as designed.
- **Poltergoblin** (remote): cast, spirit speed bonus, pulled back to the body when the timer ended.
- **Boats, driven from the keyboard on the driver-owned path:** launch, top speed (skiff and cutter), boost, turning, short and long drifts with their bursts, coasting, braking, reversing, beaching and shoving back off, a wall crash, the reef, scrape damage, self-repair, jumping out of the seat at speed (you keep the boat's speed), capsize recovery.
- **Boats, server-driven with the same code:** the harbor jump with its clean-landing burst, a boost hoop, and the whole of the old server-owned path (during the lag comparison).
- **Ownership and the checks on it:** the hull is handed to the driver and back; a server teleport of a driven boat; a blast pushing a driven boat; the take-back firing on a real jump; no false take-back or false crash under 100 ms of simulated lag.
- **Grapple:** pull onto a stationary boat and onto one moving at 50 to 67 studs/s, with a seat at the end.
- **Navy:** horizon spawn ahead of the thief and in sight; intercept; the spread; the charge hitting a straight-running skiff and missing one that drifted away; coming about afterwards; mines laid by a blocker; a mine going off on contact, chaining to two neighbours and sinking a skiff; standing down when Heat fell.
- **Guardian:** waking, closing at about 27 studs/s, a stomp hitting a standing carrier, the same stomp missing a carrier that jumped on time, a leap, a smash.
- **Storms:** waterspouts created, circling, and throwing a boat 9 studs into the air; lightning still striking.
- **The loop:** stole the Lost Compass, carried it, walked into the Hoard and banked it (2 gold with interest); ended the raid; everything reset (ships, mines, spouts, storms, Heat, boats, the driver's ownership); the next raid started and the win counted.
- **Swimming:** an idle goblin now floats.

### Not verified

- **How any of it feels.** Especially dash and air-jump timing, drift, and whether the Navy and the Guardian are fair.
- **Anything with two or more players:** robbing a carrier at V3 speeds, stealing a driven boat, a passenger's view of a boat someone else drives, two drivers colliding, the Navy choosing between carriers, the take-back check against a real cheat.
- **The on-screen changes.** The top bar, treasure board, stamina, dash and ability slots were seen in one screenshot and look right. **The new boat panel (three meters with the drift meter) and the enlarged help panel were never seen**: the display was asleep by the time I tried.
- **Drift on the server-owned path** (`BOAT_CLIENT_PHYSICS = false`). The key is wired; I did not drive it.
- **The Navy's charge against a cutter, a mine line across a real route home, a waterspout launch followed by a clean landing, a carrier's grapple pull, dash and stomp on slopes and stairs.**
- **Client frame rate, mobile, gamepad, touch, real latency.** There are no touch buttons for dash, drift or boost.
- **The islands' routes at the new speeds.** A higher jump, an air jump, a dash and a longer grapple may make some climbs trivial or open shortcuts nobody intended. None were re-walked.

## 11. Human playtest instructions

Double-click **Play Loot Goblins**, press the blue Play button, press `H`. For a group: **Test tab > Server & Clients > 4 players > Play**. Say what felt bad, and send a screenshot of any red error.

**First five minutes, alone**

1. Run around Goblin Cove without touching Shift. Is this fast enough to be fun on its own?
2. Sprint, jump, jump again in the air, dash (`C`), and dash in the air. Do they chain? Does stamina run out before you are done having fun, or never?
3. Hook a cliff with `F`, jump off the rope mid-pull, air jump, dash. Does it flow?
4. Check the bottom of the screen: are the stamina bar and the dash slot readable?

**Boats**

5. Take a skiff. Does it leap off the line? Is the top speed exciting or just fast?
6. Hold `C` through a turn and let go. Do you understand the drift meter at the bottom of the boat panel (grey, then blue, then orange)? Is the burst satisfying? Can you thread a channel with it?
7. Hit the harbor jump straight and fast. Did you get "Clean landing"?
8. Run a boat up a beach, jump out, come back and press `S` to shove it off. Annoying or fine?
9. Crash on purpose a few times. Is the damage fair? Do you notice the hull repairing?
10. Take the cutter. Does it feel like a different boat with a reason to exist?
11. Does steering respond the moment you press a key? If someone has a poor connection, ask them especially.
12. **Is the boat panel laid out properly, and does the help panel (`H`) fit on the screen?** (I could not see either.)

**Danger**

13. Steal something worth 5 gold or more and sail home. Did you see the patrol ship before it reached you? Did the horn and the "RAMMING SPEED" banner give you time to turn? Did turning work?
14. Push Heat to FRENZY (carry something from the far ring). Did you see the mines in time? Did they change your route?
15. Take the Golden Idol and run. Can you read the Guardian's raised fists and jump the ring? Is 27 too fast, too slow?
16. Sail into a storm on purpose. Can you see the waterspouts? Did one throw you, and was that funny or infuriating?

**With other players**

17. Chase a carrier on foot. Can you catch them? Should you be able to?
18. Hook a moving boat with `F` and take a seat. Then try it on someone else's boat.
19. Ram each other. Skiff against cutter.
20. One drives while another rides as a passenger. Does the passenger's view stutter?

**Afterwards:** which of dash, air jump, drift, the charge, mines, stomp and waterspouts would you keep, and which did you not notice?

## 12. Recommended next priorities

1. **Playtest this branch before building anything else.** Start with instruction 12 (the two panels I could not see) and instruction 11 (steering response), then the feel questions.
2. **Tune from what the playtest says.** The likely knobs, all in `Config.lua`: `WALK_SPEED`, `DASH_COST`, `CARRY_STAMINA_PER_WEIGHT`, the boat `maxSpeed` and `accel` values, `BOAT_DRIFT_CHARGE`, `GUARDIAN_SPEED`, the Navy's `maxSpeed` and `NAVY_RAM_GAP`, `MINE_LAY_GAP`, `HEAT_CARRY_RATE`.
3. **Decide on driver-owned boat physics** after a multiplayer session: keep it, or set `BOAT_CLIENT_PHYSICS = false`.
4. **Walk the islands at the new speeds** and fix routes that have become trivial or broken.
5. **Touch and gamepad buttons** for dash, drift, boost, grapple and the rest, if phones matter for the next test.
6. **A frame-rate pass on a real client** (and a phone) in a storm with the Navy out.
7. Ideas I left out on purpose, in case the playtest asks for more: kicker ramps and hoops along the main sea lanes, a sword lunge, wedge-shaped beaches, Guardian pathfinding.

## 13. Studio tooling lessons

In `docs/AI_CONTEXT.md` too, because each of these cost time.

- **Studio caps a background window at 15 fps, and stops rendering when the display sleeps.** Anything timed on the client is affected, injected keys stop arriving, and screenshots time out. Measure the frame rate before trusting a client-side timing.
- **Never `require` a game module from `execute_luau`.** It loads a second copy, and a second copy of `Net.lua` destroys and recreates the remotes, cutting the running game off from its own remotes. I lost a test session to this. Read attributes and instances instead, or use a temporary test script inside the place.
- **Live sync without the Rojo plugin.** The plugin's Connect button cannot be pressed through MCP. With the human away I used a small helper outside the repository that served `src/` on the loopback address, and an Edit-mode snippet that pulled each file into its mapped script. It needs `HttpService.HttpEnabled` in the disposable built place; I turned that off again at the end.
- **A temporary test script with fixed, named commands** (board a boat, place a boat, start a storm, send the Navy) made deep tests possible. It lived only in the Studio session and was removed at the end.

## 14. Branch, commits, PR

- Branch: `feature/v3-speed-agency-danger`, from `origin/feature/v2-archipelago` at `61fa5a7`.
- PR base: `feature/v2-archipelago` (PR #10), which is based on PR #9's branch, which is based on `main`.
- Commits: movement; boats and ownership; danger; grapple-onto-boats and the fixes from testing; docs.
- Size: about 2,800 lines added and 700 removed across 20 source files. New files: `src/shared/BoatSim.lua`, `src/shared/Sea.lua` (moved from the server; `src/server/Sea.lua` now forwards to it), `src/client/BoatDrive.lua`. `Boats.lua` and `Navy.lua` were largely rewritten.
- Merge: **do not merge** until PR #9 and PR #10 are approved and a human playtest of this branch has passed.
- Studio state at handoff: play mode stopped; the temporary test script removed; `HttpEnabled` off; Studio's network simulator back at 0. The built place in `build/` was regenerated by `check.ps1` and is disposable.

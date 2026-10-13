# Additional system contracts for portable understanding

The complete current system catalogue, controls, creature roster, remote/state inventory, architecture, and exact tuning are embedded later. This chapter supplies context that a standalone AI must not infer from words such as 'unchanged'.

## Treasure states and banking

Treasure is a server-owned object with spot, carried, loose, and away states. Taking it from its spot involves a 0.6-second hold, triggers trouble, and assigns ownership. Loose treasure can be grabbed. A carry change gives temporary steal immunity; attacks should use the existing knock-loose path so that immunity is respected. Throwing, death, disconnect, boarding, spirit return, and reset must preserve one authoritative owner and avoid duplicate payment.

Untaken treasure gains interest in discrete eighty-second steps, at most three steps, using its value and the configured share; the exact tuning is included below. Its bankedValue stores the payout used by the score code. A carrier entering the Hoard ring banks it unless excluded by the ward/spirit rules. The object becomes away and returns later after its own respawn time. Gold is earned only when the server accepts a bank, not just when a client sees a pickup animation.

Creatures that carry treasure do not add a new ownership state: the item remains loose while Loot.hold pins it to the creature. A player can still grab it using existing rules. Loot.letGo releases it, and Loot.sendHome restores its spot. The distinction prevents a second inventory/possession implementation. A recently thrown item landing inside the Hoard can also bank for its last holder within THROWN_BANK_WINDOW; bank credit is still decided by the server. Lost or long-abandoned loose objects return to their spots under the existing bounds/timeout rules.

## Poltergoblin in full

Poltergoblin is a temporary spirit excursion, not a death/ghost mode. Press E without an active prompt to dash out of your body. The body stays frozen as a visible vulnerable copy. For five seconds, the spirit can move faster, fight, grapple, and grab treasure, then returns to the body's original position. E can request early return after a brief recast delay. The ten-second cooldown begins at casting; a ninety-stud tether also forces an early return.

Loot rides back along the tether, so the ability is a grab-and-rewind tool rather than advancing carried loot toward home. A sword hit on the abandoned body shatters the spirit: it returns hurt, its held loot drops where the spirit stood, and no damage echo is paid. A normal return repeats 35% of the spirit's accumulated damage on marked victims. Death and cancellation have distinct cleanup outcomes. The home ward blocks casting, pulls an entering spirit back, and prevents spirit banking.

The server owns body state, timers, damage marks, returns, and possession; the client predicts its own initial dash for responsiveness. Any system moving/respawning a player must cancel the ability appropriately. Its real player-versus-player behavior still needs human multiplayer acceptance.

## Player and boat motion boundaries

Movement is the single server writer of WalkSpeed and stamina. Ordinary running, carried speed, water scaling, sprint, and spirit bonuses compose through it. The client predicts dash/air-jump and sends intent; the server charges stamina and enforces eligibility/cooldowns. Regeneration pauses after spending, and exhausting the meter creates a winded recovery threshold. Chill suppresses regeneration and drains stamina.

BoatSim is shared physics code. Driven boats normally run on their driver's client, while empty and AI boats run on the server. Buoyancy samples six hull points against deterministic wave math; powered thrust, braking, grip, yaw, drift, bank, recovery, current drag, and controlled bursts determine motion. Server Boats owns seats, anchors, health, crash/scrape damage, sinking, respawn, boost cooldowns, and coarse motion policing. Setting BOAT_CLIENT_PHYSICS false returns driven simulation to the server for comparison.

The documented policing gap matters: a modified driver may exploit speed margins, turn tighter, or avoid crash damage. Do not describe all boat motion as fully trusted just because damage and scoring are server-owned. Real-latency and multi-driver acceptance remain separate from single-client measurements. New movement strategies or authority changes require the human's architecture approval.

Use existing Boats.shove and Boats.place APIs for pushes and relocations; writing a client-driven hull's CFrame or velocity directly from the server can conflict with its owner. Empty unanchored boats drift. Far unoccupied boats sleep. Anchoring, theft, abandonment, sinking, and rediscovery are gameplay choices rather than private player ownership.

## Threats and player-readable counters

Heat moves from CALM to ALERT at 25, HUNTED at 50, and FRENZY at 80. The escalation should change decisions: visible carrier flares, a pursuing/intercepting hunter, a blocker/mines on the return line, and a carrier-following tempest. Navy uses deep-water routes, visibility, committed charges, and search/retreat rather than omniscient permanent homing. A charge announces a horn and holds a bearing; changing course is the intended answer. Shelled target circles close before impact. Islands, shallows, the home ward, a beacon, or the fort chain can change pursuit.

The Guardian has marked leaps and boulders plus a ground shockwave that invites jumping. Individual island inhabitants each teach a rule: watched statues, a delayed path echo, a burrowing crab, straight-line charging ram, water-bound eel, treasure-snatching imps, throwing marines, fire laying ahead of movement, stamina-draining cold, a noise-sensitive sleeper, a dozing shade, a shoving whirlpool fin, and a timed clam. The current roster and parameters later in the guide describe each. Gobbo is a friendly dockhand with kegs and proximity warnings.

Most dangers target possession, routes, or terrain rather than adding identical health bars. Telegraphs must leave an actionable response. Onboarding should teach those counters through encounters and readable cues rather than relying only on the help panel. A reported single-client creature action does not prove behavior when two people face a Watcher or interact with an Echo.

## Sea activity grammar and sound

A teal hoop line offers transit toward a dock. Orange hoops mark separate timed courses. Coins mark skillful lines, jump arcs, or secrets. Boost chains raise speed enough that tight turns may become impossible; routes were changed after real-physics autopilot tests. Those tests establish mechanical feasibility, not how a beginner interprets or enjoys them. Placement must preserve calm home water and optional routes.

World sounds belong to a position with distance falloff and a finite range; interface chimes belong to the player. V6 also bounds simultaneous repeated voices and compresses the world sound group. Thunder, blasts, distant markers, and lightning use tuned hearing/drawing/sending distances. Their values are current source, not universal recommended distances. V6's audio measurements came from logs and calculations; the author could not hear the result. A human still needs to listen.

## Cleanup and integration

One server Heartbeat coordinates modules; builder modules describe geometry and references while mechanism modules run behavior. Raid reset cancels spirits; resets loot, Heat, threats, blasts, trouble, Navy/mines, storms/spouts, escalation, destructibles, mechanisms, cannon/keg state, boats, coins/salvage, and creatures. Joining, leaving, death, and three successive raids need real lifecycle tests. World generation and shared-state attributes must work under streaming, with no duplicate authority or second implementation.

Game-specific designs and facts stay in this repository. Reusable observations go to the shared notebook. This guide embeds current records and full report history, allowing an outside AI to evaluate mechanics without the original chat. Historical commands and versions in those reports are evidence context, not instructions to bypass the current team's rules.

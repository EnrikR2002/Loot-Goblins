# Loot Goblins V6: identity, journey, and current scope

Loot Goblins is a social possession-and-escape game: steal ridiculous treasure from dangerous islands and other players, then somehow get it home. The desired rhythm is explore with awe, take something valuable, feel the world react, improvise an escape, bank the reward, and choose another risk. Fast movement and boat handling should be enjoyable before a reward appears. Danger challenges that power rather than restoring difficulty by making ordinary travel sluggish.

This guide describes the V6 development line at gameplay revision 8f399c7. It does not describe current main: V6 is stacked on V5, V4, V3, V2, and the sprint/grapple branch. Those gameplay PRs still have their own approval and merge sequence. The memory-system PR is based on V6 as Enrik requested, so its changes can travel with that version. Nothing here authorizes or performs those gameplay merges.

## The first raid from a player's perspective

The world generates when Play starts, taking several seconds on the reported development machine; players are loaded after world construction. Goblin Cove is home. The Hoard is the visible gold ring/beam where treasure and coin proceeds are banked. Home also has boats, keg access, a practice cannon, movement toys, and a harbor jump. The intended introductory line is the harbor jump, the teal Gate Run, and the passage through the reef to the Crossroads. Home Bay deliberately leaves calm water and visual breathing room.

The near islands offer inexpensive short trips. Middle destinations add longer journeys and characteristic trouble. Far islands offer larger treasure with heavier carrying costs and harder return routes. A treasure pillar/name and the map/compass help choose a destination; the physical geography gives currents, reef passes, cover, high ground, and alternate routes that influence pursuit. A thief normally carries one treasure at a time. The personal decision is which treasure is worth exposing oneself for, and how to return without being robbed or stopped by the world.

A raid lasts nine minutes with a short intermission; the first intermission is six seconds. Banking adds Gold for that raid. At its end, every player tied for the highest positive Gold receives a Win; a zero-score raid has no winner. Gold resets next raid, and the world resets its systems. Wins are session values, not saved progression. Loose or carried treasure not banked in time does not become score. Death drops carried treasure and respawns the player at home after three seconds, allowing others to recover the object.

Taking treasure triggers its own trouble and adds shared Heat. Continuing to carry outside the home ward raises Heat; when nobody carries, Heat cools. Other players and world threats create exposure. The intended social result is improvised chases, theft, escape, group reactions, and another raid. Existing solo mechanical observations and some human feedback do not establish full multiplayer fun or fairness.

## Player verbs and tradeoffs

Run, sprint, dash, air-jump, grapple, board, steer, brake, drift, boost, anchor, steal, throw, swing, light a beacon, raise a chain, launch a keg, fire a cannon, hide, and bank. Not every verb needs a new system. The shared E key favors an actual visible prompt over spirit casting; C means dash on foot and drift while driving.

Running at 28 is free. Stamina pays for sprinting and exceptional moves; carrying treasure increases their costs and slightly slows the carrier. A carrier can defend themselves with a weaker, slower, shorter, tiring sword swing, and can grapple to surfaces/boats but cannot use the grapple to steal another treasure. Boats trade speed, durability, draft, handling, capacity, and cannon access. Geography can separate a shallow-water player route from a deep-draft Navy route. A beacon diverts nearby Navy, and the fort chain prevents new departures from its harbor for a period.

The score remains treasure. Coins encourage taking a skillful or interesting route, repair a little hull, and refund some boost cooldown; ten convert to one Gold when banked, with at most six Gold from coins in a raid. Timed courses provide a different movement challenge and a local best-time sign. Their presence should not turn every quiet crossing into a course.

## What has evolved through feedback

V2's world was worth exploring but travel and danger felt weak. V3 made movement and boats more powerful and changed threats to intercept, commit, and leave actionable tells. V4 enlarged and differentiated the world; a subsequent human playtest found the sea too spread out. V5 brought it closer and added inhabitants and sea activities; its feedback praised the map, boats, and creatures but found hoops/coins crowded and oddly placed. V6 rearranged the same offers, measured routes, and repaired global thunder. These are attributed historical findings, not controlled causal experiments or a guarantee of broad player preference.

V6's report was later amended after Ninety discovered the blocked Skull Chalice approach. The source now contains the ladder/hatch repair. Its earlier 'nobody has played V6' wording describes an earlier checkpoint; it must not erase that later feedback. Broader V6 layout, sound-by-ear, multiplayer, mobile, and balance acceptance remain outstanding.

## Current guardrails and absent features

No shops, XP, pet system, rarity economy, monetization, trading, boat upgrade tree, saved progress, or production architecture is implemented or authorized by this documentation task. The original long-term design vision appears later, explicitly as future direction. Rough geometry, primitive creature models, built-in sounds, and incomplete advertised input coverage are prototype compromises; they are not proof of release readiness.

An outside AI should deepen possession and escape, preserve movement agency, compare ideas against existing verbs, distinguish current V6 from historical configurations, and propose a small experiment behind the active gate. A mechanic rejected for another game is not automatically rejected here. A larger map, more inhabitants, or permanent progression requires an actual reason and human scope approval.

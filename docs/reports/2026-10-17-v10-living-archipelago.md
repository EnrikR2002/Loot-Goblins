# V10: The Living Archipelago (2026-10-17)

Requested by Ninety with the "V10 One-Shot: The Living Archipelago" prompt and three sentences of their own: make me impressed, make it beautiful, make me want to play it. Built by Claude Opus 5.5 in one session (2026-10-16 to 17).

**Read this first.** V10 is a visual pass. It changes how Loot Goblins looks and is built so that it changes nothing about how it plays. Everything below was built and judged by one AI on **one** Roblox Studio client, from screenshots I took and looked at. Nobody has looked at V10 yet, and it has never had a second player. Where I built something and did not look at its final version, I say so.

![The Golden Idol as a crowned goblin king, the Sun Temple's giant sun behind it](2026-10-17-v10-after-golden-idol.jpg)

## 1. Executive summary

- **An art direction** (`docs/ART_DIRECTION.md`) and one palette in code (`src/shared/Palette.lua`): a sunlit storybook sea of chunky toy pieces where danger is drawn big and what you drive is drawn small.
- **New light and water**: a deep teal sea that turns turquoise over warm gold sand, a warm late-afternoon sun, softer haze, a colour grade, bloom and sun rays; terrain recoloured (warm rock, charcoal basalt, blue-white snow).
- **Every one of the 16 major islands has a signature shape** you can name from a boat: a pebble tower, a coral crown and giant clam, a sea arch, a colossal stone head, a broken galleon, crystal spires, a colossal tree, a drowned dome, black spikes, lava streams, a giant golden sun, an ice needle under an aurora, a sea serpent's skeleton, ghost-lit skull eyes; Windmill Hills became farm country and Fort Barnacle flies navy banners.
- **Creatures redesigned**: the Stone Guardian (one design for the golem and its speedboat rider), the Leviathan, the Echo, the Ghost Fleet, and added detail on every island creature.
- **Every player is a goblin**: green skin, long ears, a big nose.
- **Treasure**: the Golden Idol is a crowned golden goblin king with a halo; chests, gems and the Jade Frog restyled.
- **Boats** wear class liveries; **the skyship** is dressed as the Golden Goblin with turning propellers.
- **Weather**: opaque cartoon storm clouds (V9's were small dark spheres), a new tornado funnel, Frost Spire's aurora, flowing whirlpool foam.
- **Nothing that plays changed**, and I proved the part that matters most by machine: a fingerprint of every solid or ray-hit part in the built world matched V9's (section 24).
- **Frame rate unchanged** on this machine (about 60); parts up from about 6,000 to about 8,800.

## 2. Git branch, base and PR

PR #20 (V9, `feature/v9-relentless-chaos`) is open and not merged, so V10 is branch `feature/v10-living-archipelago`, cut from the V9 branch at `713995e`, and its pull request targets `feature/v9-relentless-chaos` (a stacked PR). When V9 merges, the V10 PR's base should be moved to `main` before the V9 branch is deleted. Nothing was force-pushed and nothing was merged.

## 3. Art direction

`docs/ART_DIRECTION.md` is the working style guide: the one-line idea, three rules (light first, silhouette before detail, keep the jokes), the palette with roles, accents with one meaning each, regional palettes for all sixteen islands, material and shape language, the island landmark table, creature rules, goblins, treasure, vehicles, light and weather, the rendering rules learned in this pass, the collision contract, performance rules and where the code lives. Future passes extend it.

## 4. Material and colour system

`src/shared/Palette.lua` holds the base colours (sand, wet sand, meadow, jungle, rock, sea floor, water, far sea, wood, driftwood, canvas, rope), the accents (gold, danger, ghost, crystal, ember, frost, snow, bone, navy, coral), leaf pairs (default, jungle, autumn, blossom, frost, ash), reef colours, boat liveries (skiff, cutter, Navy) and goblin skin. `WorldKit`'s base stone, wood and gold now read from it, so every builder follows. `World.buildEnvironment` sets the terrain material colours.

Colours I changed after seeing them rendered (each one checked in a screenshot):

| What | First value | Final | Why |
| --- | --- | --- | --- |
| Sand | `240, 222, 172` | `222, 194, 140` | the shallows read as a white sheet in full sun |
| Rock (terrain) | `132, 118, 128` | `126, 118, 116` | rendered lilac |
| Slate (terrain) | `150, 136, 142` | `146, 132, 124` | rendered lilac |
| Basalt | `58, 50, 64` | `44, 40, 44` | rendered olive; warm reds rendered teal; charcoal reads right |
| Snow | `244, 248, 255` | `222, 234, 248` | pure white blew out |
| Far sea | `20, 86, 128`, reflectance 0.3 | `18, 80, 124`, 0.24 | a lighter band at the map's edge |

## 5. Environment generation

- **Light**: `ClockTime` 15.2, latitude 30, brightness 2.7, ambient `104, 100, 116` and outdoor ambient `176, 176, 190` (so sails and hulls in shade stay light), environment diffuse 0.55 and specular 0.45, exposure +0.05, soft shadows. **Atmosphere** density 0.15, offset 0.3, haze 0.9. **Clouds** cover 0.4, density 0.3. A colour grade (`LootGoblinsGrade`), bloom (`LootGoblinsBloom`, 0.35 at 0.93), faint sun rays.
- **Water**: colour `12, 92, 132`, transparency 0.62, wave size 0.14, reflectance 0.32, over a sea floor filled with `Mud` coloured `14, 44, 66`, so deep water is dark teal and water over sand is turquoise.
- **Reusable props** (`WorldKit.lua`, all deterministic from their position): palms with a curved three-piece trunk, seven drooping two-tone fronds and coconuts; trees with a dark canopy mass and light puffs on top; rock clusters (a big rock and two smaller ones); branching coral with round tips; columns with bases and capitals; docks with trim beams and a lantern at the sea end.
- **The landmark system** (`server/Art.lua`): `Art.dress(refs)` runs at the end of `World.build` (after the water, because it looks for water). `Art.findSpot(island, mode, minF, maxF, clear)` walks seven rings of 36 points round an island (from `minF` to `maxF` of its radius), raycasts terrain and ground, scores high ground, low shore or 2-to-14-stud shallows, and rejects any point within `clear + 12` of a treasure spot, a boat spawn or the Hoard, or within `clear` of any built part (structures, ground, ziplines, launch pads, loot, coins, hoops, ramps, kickers, buoys). Deterministic; a crowded island gets a second, wider search with less room. Landmark pieces come from a few helpers (`piece`, `egg` for ellipsoids, `ball`, `beam`, `spire`, `light`), are anchored, non-colliding, not hit by rays and not touchable, and each landmark is a persistent model. Build time: 0.6 s.

## 6. Island-by-island changes

| Island | What changed | Status |
| --- | --- | --- |
| Pebble Isle | A tower of five giant pebbles (grey-blue and tan), loose pebbles at its foot, a sky-blue pennant | Improved but incompletely inspected (the final colours were not re-photographed; the first version read as a snowman, see `after-pebble`) |
| Coral Atoll | A crown of six branching coral heads round a giant pink clam with a glowing pearl and ridged lid | Improved but incompletely inspected (the clam's final colours were not re-photographed) |
| Smuggler's Cove | A natural sea arch of 15 rock chunks with a hooked crag and three hanging lanterns | Fully improved and visually inspected |
| Windmill Hills | Patchwork fields (wheat, lavender, pumpkins, tulips, in rows), whitewashed mill with a red cap and canvas sails, red barn roofs | Fully improved and visually inspected |
| Crossroads Ruins | A colossal stone head, half sunk and leaning, topknot, moss, one burning red eye | Fully improved and visually inspected |
| Shipwreck Shoals | A galleon broken in two on the sandbar, bare ribs, masts askew, lit stern windows | Improved but incompletely inspected (enlarged 1.4 times after the photo) |
| Crystal Isle | Seven violet and cyan crystal spires round a 96-stud central spire with glowing cores; charcoal rock | Improved but incompletely inspected (more saturated after the photo) |
| Tangle Isle | A colossal twisted tree: seven buttress roots, layered canopy, purple blossom, hanging vines | Fully improved and visually inspected |
| Tide Vault | A drowned marble dome with a green patina, dark arched windows, a gold finial, a ring of broken columns | Improved but incompletely inspected (patina and windows added after the photo) |
| Maelstrom Rock | Seven black spikes leaning out round the whirlpool, foam at their feet; the whirlpool's foam as flowing streaks | Improved but incompletely inspected (spikes sharpened and turned outward, foam streaks built, after the photo) |
| Fort Barnacle | Navy banners (white stripe, red tail, gold badge) down each tower, bunting between them | Fully improved and visually inspected |
| Ember Isle | Lava streams down the charcoal volcano (the crater's smoke and glow were already there) | Fully improved and visually inspected |
| Sun Temple | A giant golden sun disc with twelve rays on a stone pillar beside the temple | Fully improved and visually inspected (moved to a clearer spot after the first photo; seen in `after-golden-idol`) |
| Frost Spire | A twisted ice needle with shards; three aurora curtains of light rays | Improved but incompletely inspected (the needle was seen; the aurora was rebuilt as one persistent banded curtain and not photographed) |
| Leviathan's Rest | A sea serpent's skeleton: curved ribs, a long spine, a horned skull with its jaw fallen open | Fully improved and visually inspected |
| Skull Rock | The skull's eyes glow ghost-teal (short light), ghost lanterns round the shore | Fully improved and visually inspected |

## 7. Supporting geography

Palms, trees, rock piles, coral, columns and docks everywhere were restyled through `WorldKit` (section 5). Terrain colours changed everywhere (section 4). The far sea's seam is fainter. The small islands (keys, rocks, stacks) have no landmark of their own: **Unchanged or deferred**.

## 8. Guardian-by-guardian changes

| Creature | What changed | Status |
| --- | --- | --- |
| Stone Guardian (Sun Temple) | One design in `GuardianLook.lua`: a top-heavy sandstone golem (huge shoulders and fists, stubby legs), gold belt and cuffs, a gold sun on its chest, moss, a heavy brow over burning eyes, a gold sun halo that turns behind its head (slowly while it sleeps); 35 parts | Fully improved and visually inspected |
| The Watchers (Crossroads) | Brow, mouth, stone shoulders, moss crown, a red rune on the chest; their eyes (the tell) unchanged | Fully improved and visually inspected |
| Bramble (Windmill) | Fleece of wool curls, pale muzzle, yellow eyes, curled horn tips, hooves, a woolly tail | Fully improved and visually inspected (the wool reads grey in shade) |
| Old Clacker (Shoals) | Six legs, pincers, pupils on its eye stalks, barnacles, the wreck's broken mast and a rag | Improved but incompletely inspected (seen asleep as the wreck mound; not seen risen) |
| The Warden (Tide Vault) | A real eel: dark back over each glowing segment, a fin on each, eyes and a jaw on the head; segments face along the body | Improved but incompletely inspected (seen coiled at rest, not swimming) |
| Imps (Tangle) | Grin, pale belly, horns, hands, a tail tuft | Initial prototype (built, not photographed) |
| Marines (Fort) | Tricorn with a white plume, gold epaulettes, belt and buckle, eyes, moustache, a musket | Fully improved and visually inspected |
| Cinderlings (Ember) | A crust of cooled rock, side flames, a grin, feet | Initial prototype (built, not photographed) |
| The Chill (Frost) | A face in the frost and a crown of icicles | Initial prototype (built, not photographed) |
| The Maw (Maelstrom) | Snout, teeth, yellow eyes, side fins, a pale belly | Initial prototype (built, not photographed) |
| The Clam (Coral) | Unchanged (its lid is part of the island) | Unchanged or deferred |
| Gobbo (home) | Nose, eyes, belt, buckle | Initial prototype (built, not photographed) |
| Sea forms other than the Guardian's boat, the Echo and the Ghost Fleet (the tub, the raft, the gunboat, the slab, the lava raft, the Chill at sea) and the sea mobs | Unchanged | Unchanged or deferred |

## 9. Leviathan redesign

Ellipsoid humps (wider than tall, long) ride one wave that travels down the body, each lying along the path and pitching with the wave, so it reads as one animal arching through the sea. Dorsal fins on every other hump, two tail flukes. The head: ellipsoid skull and jaws, brows, two horns a side, frills, deep sockets with amber eyes and pupils, a dark mouth, eight teeth, and wake foam either side while it runs at the surface. Placed with `BulkMoveTo`. The breach stays removed and nothing about its hunting changed (the body segments drive no logic; the head's position is computed exactly as in V9). **Fully improved and visually inspected** (`after-leviathan`).

## 10. Stone Guardian and its speedboat

The speedboat rider is built from the same design (`GuardianLook.posed`) without its legs, gripping the gunwales, with red eyes; the raised-fist pose for the launch uses the same arms. The boat got a keel, a red stripe, a gold bow tip, a diamond-plate motor with a red cap, a flame and a windshield. The joke is intact: a mountain of stone in a bathtub with a motor. **Fully improved and visually inspected** for the island golem (`after-guardian`); the boat form is built from the same parts and was not photographed: **Improved but incompletely inspected**.

## 11. Echo

Still tiny. At sea it is a crystal imp riding a glass shard: faceted body, a glowing core, a diamond head with cyan eyes, horns, arms and three spikes. The island Echoes match (a glowing core, cyan eyes, horns, a shard). **Fully improved and visually inspected** at sea (`after-echo`); the island bodies are **Initial prototype**.

## 12. Ghost Fleet

Each ghost ship is a galleon: a darker, less see-through hull (V9's was faint in fog), a glowing waterline and gunwale, a pointed bow with a bowsprit and a bone skull figurehead with glowing eyes, a two-tier stern castle with green-lit windows, three masts of torn glowing sails (two ragged halves per yard), a crow's nest, a black skull flag, two lanterns with lights, cannon ports. The pirates have tricorn hats, beards, belts, cutlasses and ghostly tails; the dinghies have a lantern on a pole. **Fully improved and visually inspected** (`after-ghost-fleet`, in clear weather; not photographed inside the fog).

## 13. Goblin appearance

`server/GoblinLook.lua` makes every player a goblin: goblin-green skin (`126, 184, 72`, yellower than the grass), long pointed ears pink inside, a big nose, over whatever the avatar wears. Applied when the avatar's appearance has loaded and again 2 s after spawning; idempotent. Checked on spawn and on respawn (ears present, skin green); the ears and nose are massless, non-colliding, not hit by rays and not touchable. No customization system (that is for a later version). **Fully improved and visually inspected** (`after-goblin`).

## 14. Boats and Navy ships

Each boat wears its class livery: hull colour, a stripe down each side (skiff gold, cutter teal, Navy blue), cap rails, a transom, a bow lantern, and every sail a coloured band and a yard, every mast a cap. The Navy keeps its blue and brass. All of it is welded, massless, non-colliding and not hit by rays; hull size, seats, physics, centre of mass and anti-cheat policing are untouched (hull sizes compared against V9: identical). Boarding by the prompt and driving out were walked and driven by hand (section 25). **Fully improved and visually inspected** (`after-ghost-fleet` shows a skiff).

## 15. Skyship

Dressed as the Golden Goblin: a rounded hull in three tiers of planking with a gold stripe, a curved prow with a golden goblin figurehead (ears back, glowing eyes) and a bowsprit, a jib, red bands and gold hems on the sails, rigging, a crow's nest and pennant, five glowing stern windows, stern lanterns, and two propellers that each client turns. Every piece is non-colliding and not hit by rays, so the deck, wings, cannons and aim are exactly what they were (the skyship's solid parts matched V9 in the fingerprint). The 20-second deployment window is unchanged. **Fully improved and visually inspected** (`after-skyship`, `after-deck-view`).

## 16. Ocean and coast

The new water and sea floor (section 5), warm sand so shallows read as sand, docks with trim and lanterns, coral reefs restyled, whirlpool foam as streaks. Coast foam along beaches was not added: **Unchanged or deferred**.

## 17. Tornado, storm and weather

- **Storm clouds**: V9's puffs were `Ball` parts given flat sizes, which Roblox draws as small spheres (the "black balls"). They are now opaque ellipsoid billows, dark underneath and light on top, with a wide anvil, so a storm reads as a towering cartoon cloud from the horizon. **Fully improved and visually inspected** (`after-storm-clouds`; `before-storm`).
- **Fog banks**: the same ellipsoids, pale and see-through (transparency 0.58). Not photographed: **Improved but incompletely inspected**.
- **Tornadoes** (client `Twisters.lua`): a soft core of seven tall ellipsoids, three spiral arms of fourteen wisps that race round and up the funnel, eighteen bright streaks, debris, a wide billowing storm cloud on top, spray and the roar. **Improved but incompletely inspected**: the final funnel was seen only in the background of `after-tornado`; an intermediate version was looked at up close.
- **Spatial thunder (V6)** is untouched.
- **Aurora** over Frost Spire: three rippling curtains of light rays, green at the hem, violet at the top, one persistent model (V9's were three flat neon sheets that read as floating glass). **Improved but incompletely inspected** (not photographed in its final form).

## 18. Movement, trick and banking effects

**Unchanged or deferred.** V9's dash and air-jump puffs, trick callouts, landing bursts and banking effects are as they were. This was the lowest priority against the world, the creatures and the treasure.

## 19. Treasure models

A treasure's core (the part carried and thrown) keeps its V9 size and physics; the look is welded decoration, and V10's new decoration is not hit by rays (`trim` in `Loot.lua`), so a grapple's target area is what it was.

- **The Golden Idol** is the prize and looks it: a crowned golden goblin king with ruby eyes, a ruby on its brow, long ears, folded arms over a fat belly, a gold crown and a sun halo, on a base; brighter glow and more sparkle than anything else. Its core is invisible. **Fully improved and visually inspected**.
- **Chests** have domed lids propped open on coins and a jewel; **gems** have gold settings; **the Jade Frog** has its own look (a jade frog on a gold lily pad, gold-ringed eyes; `Config` `visual = "frog"`). **Improved but incompletely inspected** (built; not photographed).

Carrying, throwing and banking a restyled treasure were not exercised in this session (the code that carries and throws uses the core, which is unchanged).

## 20. UI consistency

No interface change. V9's clean horizon (no distant floating text) is kept: every V10 addition is geometry, with no billboards or labels. **Unchanged or deferred.**

## 21. Performance comparison

One Studio client on this machine, single player, at the start of a raid. "V9" is the audit at the start of the session (V9 code), "V10" is after the main pass (before the last collision-preservation change, which added about 270 invisible parts and the decorative coral, palm and tree pieces in their place).

| Measure | V9 | V10 |
| --- | --- | --- |
| Server parts (generated world) | 5,989 | 8,835 |
| of which Structures / Decor / Threats / Landmarks | 1,761 / 2,709 / 320 / 304 | 2,322 / 3,906 / 545 / 1,133 |
| Lights | 166 | 202 |
| Particle emitters (server) | 22 | 22 |
| Instances (server) | 53,959 | 57,587 |
| Server heartbeat | 0.09 ms (one reading) | 0.33 to 0.68 ms (three readings) |
| Physics FPS | 60 | 60 |
| Client frame rate | 59.6 | 59.9 (capped at 60) |
| Client memory | 3,707 MB | about 3,728 MB |
| World build | about 4.2 s | 4.5 to 4.9 s (landmarks 0.6 s) |

The heartbeat readings are noisy single samples in Studio and are not a trend. **Not validated:** mobile, weaker hardware, 32 players, or any busy multi-player scene.

## 22. Screenshots

All taken in Studio play mode on this client. "Before" is V9 at the start of the session.

| Before (V9) | After (V10) |
| --- | --- |
| ![](2026-10-17-v10-before-aerial.jpg) | ![](2026-10-17-v10-after-deck-view.jpg) |
| ![](2026-10-17-v10-before-hoard.jpg) | ![](2026-10-17-v10-after-hoard.jpg) |
| ![](2026-10-17-v10-before-skyship.jpg) | ![](2026-10-17-v10-after-skyship.jpg) |
| ![](2026-10-17-v10-before-temple.jpg) | ![](2026-10-17-v10-after-sun-temple.jpg) |
| ![](2026-10-17-v10-before-skull.jpg) | ![](2026-10-17-v10-after-skull-rock.jpg) |
| ![](2026-10-17-v10-before-boat.jpg) | ![](2026-10-17-v10-after-ghost-fleet.jpg) |
| ![](2026-10-17-v10-before-storm.jpg) | ![](2026-10-17-v10-after-storm-clouds.jpg) |
| ![](2026-10-17-v10-before-tornado.jpg) | ![](2026-10-17-v10-after-tornado.jpg) |

`after-hoard` and `after-deck-view` were taken mid-pass, before the final rock and sand colours. The Leviathan, the Guardian, the Echo, the goblin and the Golden Idol had no V9 photo in this session to compare with.

Islands (V10): ![](2026-10-17-v10-after-pebble.jpg) ![](2026-10-17-v10-after-coral.jpg) ![](2026-10-17-v10-after-smuggler.jpg) ![](2026-10-17-v10-after-windmill.jpg) ![](2026-10-17-v10-after-crossroads.jpg) ![](2026-10-17-v10-after-shipwreck.jpg) ![](2026-10-17-v10-after-crystal.jpg) ![](2026-10-17-v10-after-tangle.jpg) ![](2026-10-17-v10-after-tide-vault.jpg) ![](2026-10-17-v10-after-maelstrom.jpg) ![](2026-10-17-v10-after-fort.jpg) ![](2026-10-17-v10-after-ember.jpg) ![](2026-10-17-v10-after-leviathans-rest.jpg)

Creatures and people (V10): ![](2026-10-17-v10-after-guardian.jpg) ![](2026-10-17-v10-after-leviathan.jpg) ![](2026-10-17-v10-after-echo.jpg) ![](2026-10-17-v10-after-ram.jpg) ![](2026-10-17-v10-after-marine.jpg) ![](2026-10-17-v10-after-goblin.jpg)

**Not captured:** a dense environment close-up at ground level other than the islands above, the final aurora, the final tornado up close, the whirlpool foam streaks, the Ghost Fleet inside its fog, and the second pass of Pebble, Coral, Shipwreck, Crystal, Tide Vault and Maelstrom.

## 23. Visual defects fixed

- Storm clouds and fog drawn as small spheres (V9's `Ball` parts with flat sizes): now ellipsoids.
- Black storm-cloud balls: now light-topped, dark-bottomed billows.
- Tornado funnels like stacked plates under a flat disc: now a swirling funnel under a cloud.
- The aurora as three floating glass sheets: now curtains of light.
- The whirlpool's foam as floating white squares: now streaks.
- Ghost ships faint in fog: darker hull, glowing sails and lights.
- A whiteout from the skyship with thicker atmosphere and clouds (found while tuning): tuned down.
- Shallows bleached white by pale sand; lilac rock and slate; olive and teal basalt; blown-out snow: recoloured.
- A red eye-light dyeing a stone head pink; Skull Rock dyed teal by its eye lights: lights removed or shortened.
- The far sea's edge as a lighter band: fainter.
- Ears that vanished a moment after spawning (my own first version, see section 24).

## 24. Gameplay regressions found and fixed

All found by me during this pass, none shipped:

- **Collision.** My first pass made the new palm trunk segments, tree trunk lean, extra rocks, coral arms, column bases and capitals and the dock lantern posts solid (the lantern post stood where boats tie up). Fixed: all decoration is non-solid, and where a solid prop was redesigned its V9 solid is kept exactly (palms: V9's straight post, invisible; coral: V9's blocks from the same random draws, invisible; trees: V9's trunk size and place). **Proof:** I fingerprinted every solid or ray-hit anchored part in the built world (2,025 parts: folder, name, position to 0.1 stud, size, rotation), then synced V9's exact sources (from `git archive` of `713995e`, served from a second loopback server) into Studio, built V9, and fingerprinted it. Every group matched except parked boat hulls (they bob and drift; their sizes match) and the windmill's sails (they turn; their sizes match). Then I restored V10.
- **Grapple target areas.** New treasure decoration (the Idol's halo, the frog's body) would have enlarged what a grapple can hit; it is now not hit by rays.
- **Goblin ears.** My first version waited using `os.clock()` (CPU time, which barely moves) and then applied a frame before Roblox replaced the head with the avatar's, so the ears vanished. Fixed: applied on appearance loaded and 2 s after spawning, idempotent; checked on spawn and respawn.

## 25. Tests performed

On one Studio client, V10 code synced from disk and compared:

- `./scripts/check.ps1` (format, lint, tests, Rojo build, guide freshness): see the PR.
- **Collision fingerprint**, V10 against V9 (section 24): identical apart from self-moving parts.
- **Windmill ladder, on foot, no teleport on the route**: from the ground east of the mill, walked to the ladder and climbed it (the humanoid entered `Climbing`), ground at y 42 to the top at y 69, and stepped off at the gallery.
- **Dock, boarding and launch, real keys**: walked the length of a Goblin Cove dock (62 studs), boarded a skiff with **E** (driver seat, the client took the boat's physics), held **W** for 4 s: 398 studs out at about 125 studs/s.
- **Goblin look**: on spawn and on respawn (ears present, skin green, ears massless, non-colliding, not queryable, not touchable).
- **Every landmark built** in every run (16 of 16 after the Coral fix; `buildWarnings` empty), with part counts and positions logged; build 0.6 s.
- **Creatures built and posed** in every run (no errors in the console); the Watchers', Bramble's, Old Clacker's, a marine's and the Warden's new parts looked at.
- **A tornado** summoned with the test hook and photographed (an intermediate funnel up close, the final in the background).
- **Console**: no errors from the game in any run (only Roblox's own UIBlox warnings and a missing default asset, as in V9).
- **Performance** (section 21).

**Not tested:** Fort Barnacle, the Ember crater, the Tide Vault entrance, Skull Rock, catapults, the skyship's cannons and wings, ramps and Hoard banking were **not walked or driven** in V10. Their collision is identical to V9's (the fingerprint), where they were walked; V10 added nothing solid near them. Carrying, throwing and banking a restyled treasure; a pursuit by eye; the Ghost Fleet in fog; the Warden swimming; Old Clacker risen; a second player; mobile.

## 26. Known limitations

- One AI's judgement from screenshots; no person has looked at V10.
- Six landmarks, the aurora, the final tornado and the whirlpool foam were changed after their last photo (section 22).
- The art is primitive parts and ellipsoids by design; close up, the stone head and the arch are blocky.
- The far-sea seam is fainter but still visible from height.
- Bramble's wool reads grey in shade.
- Sea forms other than the Guardian's boat, the Echo and the Ghost Fleet, and the sea mobs, are V9's.
- Lava streams on Ember Isle are decoration only; they do not burn (the crater's lava zone is unchanged).
- About 2,800 more parts. Fine at 60 fps here; unmeasured on phones or with 32 players.

## 27. Incomplete or deferred

- Final photos of the second-pass landmarks, the aurora, the final tornado, the whirlpool foam, the Ghost Fleet in fog, and a fresh Hoard photo with the final colours. (Studio's 3D view went blank white near the end of the session, in Edit mode too, and needs Studio restarted.)
- A route walk of the Fort, Ember crater, Tide Vault entrance, Skull Rock, a catapult, a skyship cannon and wing, a ramp and Hoard banking.
- A performance reading after the collision-preservation change.
- Movement, trick and banking effects; coast foam; sea forms and sea mobs; the small islands.
- A second player; mobile.

## 28. Next priorities

1. **A person looks at it.** Three goblins playing a few raids and saying what is beautiful and what is ugly.
2. Finish the photos and route walks in section 27 (one Studio restart).
3. Restyle the remaining sea forms and the sea mobs to match their islands.
4. Movement and trick effects: the moments that should feel the best (super jump, trick landing, banking) deserve a pass of their own.
5. Coast foam and small-island dressing.
6. Cosmetics (V11): the goblin look is the default to build on.

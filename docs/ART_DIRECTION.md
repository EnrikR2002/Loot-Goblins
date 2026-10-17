# Loot Goblins: art direction

How Loot Goblins looks, as a working system: what to use, where, and why. The colours below are the ones the code uses (`src/shared/Palette.lua` and `server/World.lua`); change them there and here together. Written for V10 (The Living Archipelago) and extended for V11 (Goblin Life: cosmetics, boat looks, pets, effects and the wardrobe interface); later passes extend it rather than replace it.

## The idea in one line

**A sunlit storybook sea, built from chunky toy pieces, where everything dangerous is drawn bigger and everything you drive is drawn smaller.**

Three rules follow from it:

1. **Light first.** A warm late-afternoon sun, a deep teal sea that turns turquoise over sand, soft white clouds. Most of the world's beauty comes from the light and the water, not from the props.
2. **Silhouette before detail.** Every island has one shape you can name from a boat 600 studs away (a windmill, a skull, a spire, a ribcage). Detail goes near paths and treasure, where goblins stand.
3. **Keep the jokes.** Big things are huge and heavy; the boats they use are tiny. The Guardian is a mountain of stone in a bathtub with a motor. Polish the joke, never fix it.

And one contract that is not negotiable: **art never changes how the game plays.** See "The collision contract" below.

## Colour

### The base palette

| Role | Colour | Used for |
| --- | --- | --- |
| Deep sea | water `12, 92, 132` (transparency 0.62) over a dark `Mud` sea floor `14, 44, 66` | open water |
| Shallows | turquoise: the same water over sand | reefs, beaches, island margins |
| Far sea | `18, 80, 124`, reflectance 0.24 | the flat slabs beyond the map walls (tuned to meet the real water with the faintest seam) |
| Sand | `222, 194, 140` (a warm gold) | beaches, sandbars |
| Meadow | `112, 196, 86` | ordinary grass |
| Jungle | `52, 150, 74` | Tangle Isle, deep foliage |
| Rock (terrain) | `126, 118, 116`, a warm brown grey | cliffs, boulders |
| Slate (terrain) | `146, 132, 124` | plateaus, fort grounds |
| Basalt | `44, 40, 44`, charcoal | volcanic rock, Crystal Isle's rock |
| Snow | `222, 234, 248` | Frost Spire |
| Wood | `150, 98, 58` with trim `92, 58, 36` | docks, boats, shacks |
| Rope and canvas | `236, 222, 190` | sails, awnings, rigging |
| Goblin skin | `126, 184, 72` (yellower than the meadow, so a goblin never melts into grass) | every player |

### Accents (one meaning each)

| Accent | Colour | Means |
| --- | --- | --- |
| Goblin gold | `255, 196, 46` | treasure, the Hoard, the skyship's trim, anything good |
| Danger red | `232, 64, 52` | the eyes of things that hunt you, warnings |
| Ghost teal | `110, 255, 210` | the supernatural (Skull Rock, the Ghost Fleet) |
| Crystal violet | `168, 92, 255` with cyan `60, 214, 255` | Crystal Isle and the Echo |
| Ember orange | `255, 120, 40` | fire, lava, cinderlings |
| Frost blue | `170, 228, 255` | ice, the Chill |

Accents are for focal points. A scene should have one or two of them against calm surfaces; if everything glows, nothing does.

### Regional palettes

| Region | Surfaces | Accent |
| --- | --- | --- |
| Goblin Cove (home) | meadow, gold sand, honey wood | goblin gold, red-and-white awnings |
| Pebble Isle | sand, grey-blue and tan pebbles | sky blue |
| Coral Atoll | pink-peach coral, sand | coral pink, the pearl's white glow |
| Smuggler's Cove | dark wood, dark violet rock | lantern orange |
| Windmill Hills | meadow, whitewashed mill, patchwork fields | mill red, wheat gold, lavender |
| Crossroads Ruins | grey stone, moss | the stone head's red eye |
| Shipwreck Shoals | driftwood, red hull stripe | lantern yellow |
| Crystal Isle | charcoal basalt | crystal violet and cyan |
| Tangle Isle | jungle greens, twisted brown roots | purple blossoms |
| Tide Vault | marble, green patina | gold finial |
| Maelstrom Rock | black spikes, white foam streaks | storm blue |
| Fort Barnacle | weathered grey stone | navy banners, red tails, gold badges |
| Ember Isle | charcoal basalt | ember orange lava streams |
| Sun Temple | stone, sun gold | gold |
| Frost Spire | blue-white snow, glacier blue | frost blue, the aurora |
| Leviathan's Rest | sand, bone | the Leviathan's amber eyes |
| Skull Rock | bone, dark rock | ghost teal |

## Material language

Roblox materials, chosen for a polished toy look rather than realism.

| Thing | Material | Notes |
| --- | --- | --- |
| Wood | `WoodPlanks` for decks and hulls, `Wood` for posts and trunks | always two tones: body and darker trim |
| Stone (built) | `Cobblestone` walls, `Marble` for temples, `Slate` for ruins and statues | a lighter cap stone on top of walls |
| Rock (natural) | `Slate` parts | grouped in clusters of three, never one lonely block |
| Foliage | `Grass` balls and ellipsoids | at least two greens per tree |
| Crystal, ice | `Glass` with a bright `Neon` core, or `Ice` | crystals grow in clusters of odd numbers |
| Lava, magic, eyes | `Neon` | small and deliberate: Neon is the loudest material we have |
| Sails, flags | `Fabric` | cream, striped or dyed by region |
| Metal | `Metal` (cannons, bands, the Golden Idol) or `DiamondPlate` (the Guardian's motor) | dark, with gold trim where it matters |
| Clouds, domes, skulls, pebbles | a `SpecialMesh` sphere on a block: an ellipsoid | see the rendering rules |

## Shape language

- **Chunky and tilted.** Natural things lean (5 to 15 degrees); nothing grown is a perfectly upright box.
- **Tapered.** Trunks, towers, masts and spires get narrower as they rise; roofs overhang.
- **Stacked.** Rocks, crystals, coral and ruins come in clusters: one big, two medium, a few small.
- **Rounded tops.** Foliage, clouds and creature heads are ball-built; architecture is block-built. The contrast reads at speed.
- **Curves from chains.** Arches, ribs, horns and roots are short beams chained along a curve (`Art.lua`'s `beam` and `chain`), never one straight block.
- **Big landmarks, small clutter.** A landmark is tall (40 to 150 studs) and alone. Small props sit near paths and docks, in groups.

## Island identity

Every major island has a **signature landmark**: its silhouette from the sea. `server/Art.lua` builds them after the world is built (`Art.dress`). Each one finds its own spot (`Art.findSpot`: high ground for tall ones, the shallows for sea ones) well clear of treasure, boat spawns, the Hoard, and anything built (docks, ladders, decks, ziplines, catapults, launch pads, cannons, levers, hoops, ramps). The search is deterministic, so a landmark stands in the same place every raid. Windmill Hills and Fort Barnacle restyle what is already there instead.

| Island | Signature landmark |
| --- | --- |
| Pebble Isle | a tower of five giant pebbles balanced on each other, a sky-blue pennant on top |
| Coral Atoll | a crown of giant branching coral round an opened pink clam with a glowing pearl |
| Smuggler's Cove | a natural sea arch of dark rock with a hooked crag, lanterns hanging from the span |
| Windmill Hills | farm country: a whitewashed mill with a red cap, patchwork fields (wheat, lavender, tulips, pumpkins), red barn roofs |
| Crossroads Ruins | a colossal stone head, half sunk and leaning, with a topknot, moss and one burning red eye |
| Shipwreck Shoals | a galleon broken in two on the sandbar, ribs bare between the halves, masts askew, stern windows lit |
| Crystal Isle | a crown of violet and cyan crystal spires glowing from inside |
| Tangle Isle | a colossal twisted tree: buttress roots, a layered jungle canopy, purple blossom, hanging vines |
| Tide Vault | a drowned marble dome with a green patina, dark arched windows and a ring of broken columns |
| Maelstrom Rock | black spikes leaning out round the whirlpool, foam at their feet; the whirlpool's foam is long flowing streaks |
| Fort Barnacle | navy banners (white stripe, red tail, gold badge) down every tower and bunting strung between them |
| Ember Isle | the volcano: lava streams glowing down its charcoal flanks (the crater smoke and glow were already there) |
| Sun Temple | a giant golden sun disc with twelve rays on a stone pillar beside the temple |
| Frost Spire | a twisted ice needle with shards at its foot, under three rippling aurora curtains |
| Leviathan's Rest | a sea serpent's skeleton: curved ribs on a long spine, a horned skull with its jaw fallen open |
| Skull Rock | the skull's eyes burn ghost-teal; ghost lanterns ring the shore |

## Creatures

- **Readable from a moving boat.** Each creature has one feature you can see at 150 studs: Bramble's curled horns and yellow eyes, Old Clacker's wreck-and-mast on its back, the Watchers' red eyes and chest rune, the Chill's icicle crown, the Guardian's turning sun halo, the Leviathan's horns and frills.
- **Eyes are the focal point.** Hunters have bright eyes (Neon), so a goblin always knows which way danger is looking.
- **Proportion is personality.** Huge shoulders and fists on stubby legs for the Guardian; tiny bodies and big ears for imps; a long low body for the Warden.
- **Island form and sea form match.** One design, used twice (`server/GuardianLook.lua` is the Guardian's for both the golem and its speedboat rider), so the thing chasing you is obviously the thing you robbed.
- **Named parts are load-bearing.** Code finds some parts by name (the Watchers' `EyeL`/`EyeR`, the Sleeper's `Iris`). Restyle by adding parts; keep those names.
- **Animation is procedural and cheap:** bobbing, swaying, a turning halo, a travelling wave down the Leviathan. One CFrame write per creature per frame; bodies are welded to one anchored root.

## Goblins

Every player is a goblin (`shared/Wardrobe.lua`, applied by `server/GoblinLook.lua`): goblin-green skin, long pointed ears pink inside and a big nose by default, over whatever their avatar wears. V11 makes it a costume box rather than one look: skin shades (greens first, then a few fantasy hues; the Golden Goblin is a trophy), ear and nose styles, and hats, eyewear, face pieces, outfits and back pieces on top. The goblin must still read as a goblin from across the water: no item hides the ears and nose (a hat sits behind and above them, eyewear leaves the nose out front).

### Cosmetics (V11)

- **Built like everything else**: chunky primitives, ellipsoids from a block with a sphere mesh, two tones per piece, one accent. No uploaded meshes or textures.
- **Clean colour, not texture**: cloth is SmoothPlastic. Roblox's Fabric material reads as noisy knitted wool on goblin-sized parts (checked in a screenshot); keep Fabric for big cloth (sails, flags). Metal for buckles, crowns and lids; Glass for lenses; Neon only for small glowing details (a ghost coat's trim, a brow gem).
- **Personality before price**: every slot mixes the adventurous, the silly, the spooky, the nautical and the elegant. Expensive does not mean gold and glowing: the Royal Robe is purple and ermine, the Captain's Hat is a huge black bicorne, the Plumed Hat is magenta with a palm-frond feather.
- **Exaggerate the joke**: hats too small (Tiny Sailor Cap) or far too big (a bicorne three heads wide), a barrel worn as overalls, googly eyes, a stuffed parrot sewn to the shoulder.
- **Fit any avatar**: head pieces are drawn for a 1.2-stud head and scaled to the real one; body pieces are sized from the real body parts. An avatar's own item that would clash (a hat under a hat, a shirt under a coat) is hidden while the game item is worn.
- **The collision contract applies**: every piece is welded, massless, non-colliding, never hit by rays and never touched (see below).
- **Budgets**: a hat at most 18 parts, eyewear and face 9, an outfit 24, a back piece 12 (the tests check). The heaviest goblin is 80 parts; a typical full look is 40 to 60.

### Boats (V11)

A boat wears its driver's paint, flag and figurehead (`shared/BoatLook.lua`). Paint recolours V10's parts by role (hull, stripe, trim, sails, sail stripe, mast, cabin); Class Colours is V10's look exactly. A paint has a personality and a detail or two that reads from a distance: the shark's teeth and eyes on the bow, the Jolly Goblin's skull sails, the Leviathan's amber eyes and scales, the pumpkin's stalk, the reef's spotted sails. Flags fly from the boat's own flag spot; the free Jolly Goblin flag keeps each boat's coloured flag (the colours tell boats apart) and adds a skull. Figureheads lean out over the bow and are big enough to see from another boat (a giant rubber duck is allowed).

### Pets (V11)

Pets are little characters, not floating icons (`shared/PetLook.lua`): a silhouette you can name (a crab with eye stalks and one big claw, a round gull with black wing tips, a fat frog with huge eyes, a domed tortoise, a wispy ghost), a face, two or three colours, and a way of moving that is their personality (the crab scuttles sideways, the frog hops, the tortoise plods, the gull flaps and glides, the ghost bobs and loops). About knee to waist height on a goblin. Alternative looks change the palette and add one prop (a striped shell, a pumpkin, a garden of flowers). The Shell Tortoise's ready glow is gameplay information and stays visible to everyone.

### Effects (V11)

Trails, wakes, trick effects and callouts (`shared/StyleFx.lua`) are expressive but never cover the game: thin, short-lived ribbons; one emitter per effect; capped bursts; the big burst only for a landing of three tricks or more; nothing drawn beyond 420 studs; half the particles on low graphics. Over the bright sea a glowing ribbon washes out to white, so trails keep a low light emission. Callout backings hug the words.

### The interface (V11)

The wardrobe, the emote wheel and the results card share one kit (`client/Ui.lua`): a dark-wood frame, parchment cards, goblin gold for the main action and anything good, FredokaOne for titles and Gotham for text, rounded corners, chunky buttons at least 44 points tall with a gold ring when a gamepad is on them. Rarity is a coloured edge and chip (common sand, uncommon green, rare blue, legendary gold, trophy violet, premium mint), never the only signal: the card also says the price, OWNED, WEARING ✔ or 🔒 TROPHY. Celebrations are short (a pop, a chime, a small burst) and never block play. Previews show the real thing: your own goblin, a real boat, the real pet.

## Treasure

- A treasure's **core** (the part you carry and throw) keeps its V9 size and physics. The look is welded decoration.
- **The Golden Idol is the prize** and looks it: a crowned golden goblin king with ruby eyes, a sun halo, a stronger glow and more sparkle than anything else. Its core is invisible; the figure is the look.
- Chests have domed lids propped open on coins; gems have gold settings; the Jade Frog is a frog on a gold lily pad.
- New decoration is not hit by rays (`trim` in `Loot.lua`), so a grapple's target area is what it was.

## Vehicles

- **Boats are toys.** A clear bow and stern, a two-tone hull, a class stripe (skiff gold, cutter teal, Navy blue), cap rails, a transom, a bow lantern, a striped sail with a yard.
- **The skyship is the Golden Goblin:** a curved hull in three tiers of planking with a gold stripe, a golden goblin figurehead, a jib, striped sails, rigging, a crow's nest, glowing stern windows and two propellers that turn. Its deck, wings and cannons are exactly what they were.

## Light, atmosphere and weather

- **Sun:** late afternoon (`ClockTime` 15.2), brightness 2.7, warm; soft shadows.
- **Ambient:** `104, 100, 116` indoor, `176, 176, 190` outdoor, so shaded sails and hulls stay light.
- **Post:** a gentle grade (saturation +0.16, contrast +0.08, a warm tint), bloom 0.35 at threshold 0.93, faint sun rays.
- **Atmosphere:** density 0.15, haze 0.9. Thicker atmosphere with thicker clouds whites out the whole world from skyship height.
- **Storms** are opaque cartoon cumulus: dark billows underneath, light on top, a wide anvil. **Fog** banks are pale, low and see-through.
- **Tornadoes** are a soft core wrapped in spiral wisps that race round and up, bright streaks, debris, and a wide storm cloud on top.
- **Regional mood** is carried by local lights and colour, not by changing the whole sky: lava on Ember Isle, the aurora on Frost Spire, teal at Skull Rock.

## Rendering rules we learned the hard way

- **A `Ball` part with a non-uniform size renders as a sphere the size of its smallest side.** For ellipsoids use a block with a `SpecialMesh` of type `Sphere`.
- **See-through overlapping ellipsoids read as soap bubbles.** Clouds that should look solid are opaque.
- **A long-range coloured `PointLight` dyes everything near it.** A red eye with a 40-stud light turned a grey stone head pink. Let `Neon` glow by itself; keep lights short.
- **Terrain colours do not render as written.** `Slate` and `Rock` read lilac in our light unless pushed warm; `Basalt` set to warm reds renders teal. Check every terrain colour in a screenshot.
- **Pale sand bleaches the shallows.** Through clear water in full sun, near-white sand reads as a white sheet; warm gold reads as sand.
- **Far-sea slabs show a seam** against terrain water. Match colour and reflectance by eye from deck height and from the skyship.
- **Streaming hides decoration.** Things meant to be seen from far away (landmarks, the aurora) are persistent models.

## The collision contract

V10 changed how everything looks and nothing about where you can walk, sail, hook or shoot.

- Decoration is **anchored (or welded), non-colliding, not hit by rays and not touchable**: landmarks, creature details, boat trim, skyship dressing, treasure trim, goblin ears, and (V11) every cosmetic, boat paint detail, flag, figurehead, pet and the skyship's tailor stall.
- Where a prop that used to be solid was redesigned, its **old solid stays exactly as it was, made invisible**, and the new look is decoration on top: palm trunks (V9's straight post), coral heads (V9's blocks, same random draws), tree trunks (V9's upright trunk).
- **How to check:** fingerprint every solid or ray-hit anchored part (name, position, size, rotation) in a built world and compare with the previous version. V10's matched V9's except things that move by themselves (parked boats bobbing, the windmill's sails turning). See the V10 report.

## Performance rules

- No scripts on decorative objects; anything that moves is stepped by one existing system (the skyship's propellers by the client's skyship module).
- **PointLights** only where light tells you something (lanterns at docks, eyes, lava, the pearl, the sun disc).
- A landmark costs tens of parts, not hundreds (the 16 landmarks together: about 630).
- Measure: part count, light count and frame time before and after each pass (see the V10 report).

## Where the code lives

| What | Where |
| --- | --- |
| Palette colours | `src/shared/Palette.lua` |
| Light, sky, water, terrain colours | `server/World.lua` (`buildEnvironment`) |
| Reusable props (palms, trees, rocks, coral, columns, docks) | `server/WorldKit.lua` |
| Island landmarks, restyles and the spot finder | `server/Art.lua` (`Art.dress`, `Art.findSpot`) |
| The aurora, the whirlpool foam | `server/IslandsFar.lua` |
| Storm clouds and fog | `client/Weather.lua` |
| Tornadoes | `client/Twisters.lua` |
| The Guardian's design | `server/GuardianLook.lua` (used by `Threats.lua` and `Pursuit.lua`) |
| Creatures | `Bestiary.lua`, `BestiaryMinor.lua`, `Pursuit.lua` (sea forms), `Leviathan.lua`, `GhostFleet.lua`, `SeaMobs.lua` |
| Players' goblin look and every goblin cosmetic | `shared/Wardrobe.lua` (applied by `server/GoblinLook.lua`) |
| Boat paint, flags, figureheads | `shared/BoatLook.lua` (applied by `server/BoatStyle.lua`) |
| Trails, wakes, trick effects, callout styles | `shared/StyleFx.lua` (drawn by `client/Looks.lua`, `client/Tricks.lua`) |
| Pets, pet looks and hats | `shared/PetLook.lua` (moved by `client/Pets.lua`) |
| Emotes and victory dances | `shared/EmoteMoves.lua` |
| The wardrobe, emote wheel and results | `client/Ui.lua`, `client/Shop.lua`, `client/Emotes.lua`, `client/Results.lua` |
| Boats and the skyship | `server/Boats.lua`, `server/Skyship.lua`, `client/Skyship.lua` (propellers) |
| Treasures | `server/Loot.lua` |

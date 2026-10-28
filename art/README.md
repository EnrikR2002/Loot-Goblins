# Loot Goblins art pipeline (V14)

Blender-made art for Loot Goblins, from source to the game, reproducibly. The look itself (target, shapes, colour,
composition, light) is `docs/ART_DIRECTION.md` ("V14"); what the game does with it is `docs/GAME_DESIGN.md` ("V14: The
Visual Renaissance"); the evidence is `docs/reports/2026-10-26-v14-visual-renaissance.md`.

**Status (2026-10-26).** Verified in Studio on one desktop client: Blender authoring, the export, the game building every
asset from the repository's data (EditableMesh), the three showcases, the V10/V14 compare key, a skiff driven with its
skin. **Not verified:** a published experience (it must allow Mesh / Image APIs), phones and low-end devices, and the
upload path (FBX/glTF through Studio's 3D Importer or Roblox's Blender plugin, then asset ids in the manifest): it is
written and documented below, never run. Nothing here has been uploaded to Roblox; no asset id exists.

## Folders and names

| Path | Holds |
| --- | --- |
| `blender/<Set>.blend` | the editable sources: `HD_HarborDistrict.blend` (Harbour District), `SK_HeroSkiff.blend`, `PB_PebbleCoast.blend`. Each has an `ASSETS_<Set>` collection (one `SM_` object per asset, laid in a row), a `LAYOUT_<Set>` collection (the composition) and `REF_<Set>` (the captured ground and the sea's surface, not exported) |
| `blender/scripts/` | the build scripts that make those files (`build_harbor.py`, `build_skiff.py`, `build_pebble.py`), the asset modules (`props`, `architecture`, `buildings`, `waterfront`, `coast`, `skiff`), the kit (`lgkit`: materials library, modelling helpers, baked shading, previews), composition (`layout`, `ground`, `contour`) and the exporter (`lgexport`) |
| `exports/<Set>/<Asset>.fbx` and `.glb` | each asset as one object per group, for a manual import (generated) |
| `manifest/assets.json` | every asset: source, size, triangles, vertices, groups (Roblox material, paint role, transparency, offset, size, a hash, and an uploaded `assetId` once a human records one), collision proxies, lights, lettering (generated; `assetId`/`uploadedHash` are the only fields a human edits) |
| `manifest/materials.json` | the materials library as data (generated from `lgkit.LIBRARY`) |
| `textures/LG_MaterialSwatches.png` | the library's colours as a swatch sheet, in `materials.json`'s order (generated). V14 uses no image textures: colour is vertex colour |
| `references/` | ground and object captures from the game that compositions stand on (see its README) |

**Names.** Sets: `HD_` Harbour District, `SK_` skiff (boat skins), `PB_` Pebble Isle, `CO_` shared coast pieces (V14.1
will add one prefix per island). Assets are `<SET>_<Name>[_<Variant>]` (`HD_Palm_A`, `PB_Boulder_B`); the Blender object
is `SM_<Asset>`, its helpers `COL_<Asset>_<n>` (collision box), `LIGHT_<Asset>_<n>` (point light), `TEXT_<Asset>_<n>`
(painted lettering). Materials are `M_<LibraryName>`. In a layout: instances are named `<Asset>.<nnn>`, plus `HIDE_<label>`
and `SOLID_<n>` boxes. In the game: `src/client/Art14/Meshes/<Asset>/<group>.lua`, `Layouts/<Set>.lua`, `Manifest.lua`.

## The pipeline

```
build_<set>.py ──(Blender 4.5, headless)──> blender/<Set>.blend ──lgexport.py──┬─> src/client/Art14/Meshes, Layouts, Manifest ─> client MeshKit (EditableMesh) ─> the game
   (assets + layout,                           (editable by hand)               ├─> exports/<Set>/*.fbx, *.glb ─> (human) 3D Importer or Blender plugin ─> asset ids
    deterministic)                                                              └─> manifest/assets.json, materials.json         └─> assets.json "assetId" ─> MeshKit loads the uploaded mesh
```

Commands (the AI runs them; nobody on the team needs a terminal):

- `./scripts/art.ps1` rebuilds every set from its build script and exports it; `./scripts/art.ps1 harbor` one set.
- `./scripts/art.ps1 -Export art/blender/HD_HarborDistrict.blend` exports a `.blend` someone edited by hand. **Once a
  `.blend` has been edited by hand it is the source**: re-running its build script would overwrite it.
- `-Preview -Out <scratch folder>` also renders Workbench previews (the layout from above and from the sea, the skiff);
  they are for checking, not committed.
- Then `./scripts/check.ps1` and the Luau tests in Studio (`tests/luau/Specs/ArtSpec.lua` checks the export).

The build is deterministic: rebuilding with nothing changed writes identical game data and manifests, so a diff shows only real changes (the `.fbx` files also record when they were written, and a `.blend` file records where it was saved).

## Conventions the exporter and the game depend on

- **Units and axes.** 1 Blender unit = 1 stud. Blender is Z-up; the exporter maps Blender (x, y, z) to Roblox (x, z, -y):
  an asset's **front faces Blender +Y** (Roblox -Z, a part's LookVector). The `SM_` object's origin is the asset's pivot:
  the middle of its footprint at ground level for buildings and props, the hull part's centre for a boat skin.
- **Groups.** Faces are grouped by Roblox material, paint role and transparency; each group becomes one MeshPart, and its
  module stays under Roblox's 200,000-character script limit (`MAX_TRIS` in `lgexport.py` cuts big groups).
- **Colour.** The corner colour attribute `Col` (sRGB) holds the piece's colour (from the library, varied per piece by
  hand), times baked ambient occlusion (`lgkit.build`'s `ao`: reach and strength; `ground` adds a ground plane), times a
  gradient that darkens towards the base, with bevels painted lighter. Big flat panels take little occlusion (`ao=` per
  piece; Plaster's library default is 0.3): their few corners would grey the whole panel.
- **Paint roles** (boats): BoatPaint, BoatStripe, BoatTrim, BoatMast, Sailcloth, SailStripe are white in the mesh; the game
  colours them from the boat's V10 parts (Hull, Strake, CapRail, Mast, Sail, SailStripe), which carry the goblin's livery.
- **Normals** are per corner and never smooth across pieces (each piece's `smooth=` angle): chunky, faceted where meant.
- **Helpers** (children of the `SM_` object): `COL_` empty cubes become client collision boxes (only for new structures:
  art that replaces V10/V13 parts must not have any, `ArtSpec` checks); `LIGHT_` point lights become PointLights (`range`
  and `brightness` custom properties); `TEXT_` empties become a SurfaceGui board (custom properties `text`, `color`, `w`,
  `h`, `double`; the empty's +Y is the way the lettering faces).
- **Layouts.** A `LAYOUT_<Set>` collection with `lg_anchor` (a Roblox position; Blender's origin is that point) holds
  linked instances of `SM_` meshes (location, rotation, scale), `HIDE_` empty cubes (custom properties `names`: the
  V10/V13 part names to hide inside the box, and `asset`: what replaces them; nothing is hidden unless that asset was
  built) and `SOLID_` empty cubes (client collision). `lg_motion` on an instance: `bob` (moored boats), `surf` (foam).
  `lg_order` is the build order (the most important first).
- **Ground.** Compositions stand on terrain captured from the game (`references/*_ground.txt`, read by `ground.py`);
  shores are traced from it (`contour.py`: marching squares at the waterline, offsets by the loop's winding).

## Modelling standards

**Buildings** (`architecture.py`): timber frame first (posts on a rhythm, rails at storey lines, braces in some bays),
plaster or boards as infill set back 0.18; a stone footing; openings framed (sills, headers, mullions, shutters, flower
boxes on the faces people see); steep overhanging roofs in short runs of tiles, a sagging ridge, barge boards; one
silhouette extra (chimney, flag, cupola, hoist). A building that dresses an existing one stands its wall planes on that
building's collision (`HD_RagwortWardrobe` on V13's ShopFront/ShopSide/ShopBack and counter). Budget: 3,000 to 5,500
triangles (a hero shop up to about 8,500).

**Rocks** (`coast.rock`, `coast.cliff`): the convex hull of points on a lumpy ellipsoid (big flat facets), bevelled
lightly, a lighter weathered cap, moss on the top; clusters of one big, two medium, a few small; sunk a little into the
ground; on the land side of the waterline. 150 to 1,100 triangles. Pebbles (`coast.pebbles`) are smooth and rounded.

**Trees** (`props.palm`, `props.bush`): a banded trunk that curves and tapers, fronds as folded double-sided strips in
two greens, darker underneath, coconuts; bushes from a few lumpy balls in two greens. 400 to 900 triangles.

**Boats** (`skiff.py`): built on the class's own landmarks (the hull part's frame, deck height, seats, mast foot, the
bow where figureheads go); clinker planking in bands of even depth, a wale, caps, a stem post, a planked deck, thwarts
under the seats, a bellied sail with its band; every paint role present; under 2,000 triangles.

**Props**: readable at 30 studs; bevel only what is big and structural; 60 to 600 triangles.

## The materials library

| Library | Colour | Roblox material | Notes |
| --- | --- | --- | --- |
| Timber, DarkWood, Driftwood, Bark | (178,120,72), (98,64,42), (176,162,140), (128,96,66) | Wood | two woods per building: body and trim |
| PaintedWood | per piece | Wood | painted boards, shutters, doors: the grain shows through |
| BoatPaint, BoatStripe, Sailcloth, SailStripe | white | SmoothPlastic | tinted by the livery in game |
| BoatTrim, BoatMast | white | Wood | tinted by the livery in game |
| Plaster | (244,232,204) | SmoothPlastic | little baked shadow (`ao` 0.3) |
| Canvas, RoofTile, Rope, Glass, Pebble, Foliage, Flower | per piece | SmoothPlastic | Roblox's Grass and Fabric are too noisy on small pieces |
| Sandstone | (214,180,128) | Sandstone | footings, sills, steps |
| Cobble | (176,164,150) | Cobblestone | chimneys |
| Flagstone | (208,192,160) | Concrete | paths (Pavement's brick pattern fought the stones' shapes) |
| Slate, CoastRock | (84,92,112), (140,128,120) | Slate | roofs, cliffs, boulders |
| Sand, WetSand | (228,198,142), (196,166,116) | Sand | |
| Soil | (124,88,58) | Ground | |
| Metal, GoldTrim | (74,74,82), (255,196,46) | Metal | |
| Glow | (255,214,140) | Neon | lantern glass only |
| ShopGlass | (190,228,250) | Glass, 0.72 | a shop window you see through |
| Foam | white | SmoothPlastic, 0.45 | surf |

`manifest/materials.json` is the authoritative list (generated). Change a material in `lgkit.LIBRARY` and re-export.

## In the game

`src/client/MeshKit.lua` builds an asset once per client and shares it across copies; `src/client/Renaissance.lua` builds a
set while the camera is near it (`Config.ART.RADIUS`) and releases it when left, hides the V10/V13 parts it replaces on
that client only (`LocalTransparencyModifier`; their collision stays), adds client collision for new structures, paints
lettering, animates moored boats and surf, puts the Hero Skiff on every skiff, and sets V14's light. **`K` in Studio**
flips V14 and V10 for comparison; **`Config.ART.V14 = false`** turns V14 off everywhere (the rollback). An asset that
cannot be built (no Mesh / Image APIs, or a device's budget full) is skipped and the V10 part it would have replaced
stays: the game looks like V10 at worst.

**Budgets** (`Config.ART.BUDGET`, vertices of editable mesh per set; `ArtSpec` checks): Harbor 22,000 (uses 18,693),
Pebble 9,000 (4,986), Skiff 1,500 (1,297). Measured in Studio on one desktop: about 36,000 vertices of a dense test mesh
fit before creation failed; the real Harbour District fitted twice over plus the skiff. **Phones are not measured**:
their budget is unknown, and that is the first thing to test on a real device.

## Turning it on in a published experience

EditableMesh fails in a published experience until a person with access switches on **Enable Mesh / Image APIs** in the
Creator Dashboard (the experience's Configure, then Settings; in Studio: Game Settings, Security, Allow Mesh / Image APIs)
after reading Roblox's terms. Studio's local file needs nothing. Until then V14 falls back to V10 by itself.

## Uploading meshes instead (the manual path, not run yet)

Building from repository data needs no account. To ship uploaded meshes instead (no editable-mesh budget, no 3 MB of data
in the client scripts), a human uploads the exports and records the ids:

1. **Who uploads**: the experience's owner, or a member uploading **to the group that owns the experience**. An asset
   uploaded to someone else's account may not be usable in the experience (asset permissions); never upload team art to a
   personal account unless that person owns the experience.
2. In Studio, with the experience's place open (saved or published), open the **3D Importer** and choose
   `art/exports/<Set>/<Asset>.fbx` (or `.glb`). Settings: **Import Only As Model** on (one model, one MeshPart per group),
   **Insert In Workspace** on (for a restricted asset this also grants the experience permission to use it), **Set Pivot
   to Scene Origin** on, **Anchored** on, **Merge Meshes** off, **Scale Unit** Studs, **World Forward** Front and **World
   Up** Top, **Ignore Vertex Colors** off (the colour is in the vertex colours). Check the creator the upload goes to.
3. The model holds one MeshPart per group, named `<Asset>_<n>_<RobloxMaterial>`: `<n>` is the group's index. Check each
   MeshPart's size against `assets.json`'s `groups[n].size` (if it is 100 or 3.57 times off, the unit was misread:
   import again with another Scale Unit, or use the `.glb`).
4. In `art/manifest/assets.json`, for that asset's group `n`: set `"assetId": "rbxassetid://<the MeshPart's MeshId
   number>"` and `"uploadedHash"` to that group's `"hash"`. Then export once (`./scripts/art.ps1 harbor`, say): the
   exporter keeps the ids and `Manifest.lua` gains them; the game then loads that group's uploaded mesh instead of
   building it. Delete the imported model from the place (the game builds its own).
5. If the geometry changes later, the group's `hash` changes and the old upload is ignored (the game falls back to the
   repository data) until someone uploads again and updates `uploadedHash`. **Rollback**: clear `assetId`, or revert the
   JSON in git.

**Roblox's Blender plugin** ([docs](https://create.roblox.com/docs/art/modeling/roblox-blender-plugin),
[source](https://github.com/Roblox/roblox-blender-plugin)) is an open-source Open Cloud implementation that links a
Roblox account and sends objects from Blender into a Studio session. It needs a person to sign in with their Roblox
account (OAuth), so it was not used here; the same rule applies: upload as the experience's owner or its group, then
record the ids as in step 4. The Blender MCP server configured on Ninety's machine (for Codex) was not available to this
session; nothing here needs it, because the build scripts run Blender headless.

## Updating and rolling back

- Change an asset: edit its function (or its `.blend` by hand), rebuild or export, run the checks and `ArtSpec`, look at
  it in Studio with `K` to compare. The diff shows only what changed.
- Remove an asset from the game: delete its instances from the layout (and its `HIDE_` box if it had one) and export; the
  V10 part it replaced shows again. Delete `Meshes/<Asset>` and its manifest entry if nothing uses it.
- Turn V14 off: `Config.ART.V14 = false`. Revert a set: git revert its generated files.

## Licences

Everything here is original, made for Loot Goblins by the build scripts in this folder (generated geometry, the team's
own palette). **No third-party models, textures, fonts or images are used** (lettering uses Roblox's built-in FredokaOne).
Blender is GPL software; what it outputs belongs to its author, not to Blender's licence. The ground captures in
`references/` are data from this game.

## Capturing the ground

`references/port_ground.txt` and `pebble_ground.txt` are 4-stud grids of downward rays over the built world, made in a
Studio play session (server side): a header `anchor <x> <z> step 4 x <x0>..<x1> z <z0>..<z1>`, then one row per z, each
token `<terrain height><material letter>[^<height of something built on top>[d]]`. The other files list the parts nearby
(`name|parent|position|size|...`). If the Port's terrain or an island changes, capture again and rebuild its set.

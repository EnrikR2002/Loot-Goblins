"""Builds art/blender/PB_PebbleCoast.blend (V14 Showcase C: Pebble Isle's coastline) and exports it.

    blender --background --factory-startup --python art/blender/scripts/build_pebble.py

Pebble Isle is the first treasure most goblins take, and every boat from Goblin Cove passes it. Its coast gets: a
rock shelf on the north flank of the dune (where the sand used to just stop), sea-worn pebbles round the beach, boulders
on the islet at the end of the sandbar, dune grass, driftwood, V14 palms and a V14 wreck where V10's stood, a band of
wet sand and the surf laid along the real waterline (traced from art/references/pebble_ground.txt).

Decoration only: nothing here is solid (the terrain is the island's collision, as before), so it keeps above the
waterline and away from the treasure, the landmark and the beaching lanes.
Once someone edits the .blend by hand, the .blend is the source: export it with lgexport.py instead of re-running this.
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coast  # noqa: E402
import contour  # noqa: E402
import ground as G  # noqa: E402
import lgexport  # noqa: E402
import lgkit as K  # noqa: E402
import props  # noqa: E402
from layout import Layout  # noqa: E402

SET = "Pebble"
BLEND = os.path.join(K.ART, "blender", "PB_PebbleCoast.blend")
ANCHOR = (-540.0, 0.0, 1972.0)
SLATE_BLUE = (136, 148, 166)


def assets():
    rock = dict(ground=0.0, ao=(3.0, 0.7), gradient=(0.72, 3.0))
    return [
        (coast.cliff("PB_Cliff_A", seed=401, length=24.0, height=9.0, depth=7.0, color=SLATE_BLUE), dict(ground=0.0, ao=(4.0, 0.7), gradient=(0.65, 6.0))),
        (coast.cliff("PB_Cliff_B", seed=402, length=14.0, height=6.0, depth=5.0, color=(150, 156, 166)), dict(ground=0.0, ao=(4.0, 0.7), gradient=(0.65, 5.0))),
        (coast.rock("PB_Boulder_A", seed=411, r=3.4, squash=0.62, color=SLATE_BLUE), rock),
        (coast.rock("PB_Boulder_B", seed=412, r=2.2, squash=0.7, color=(158, 150, 140), moss=False), rock),
        (coast.pebbles("PB_Pebbles_A", seed=421, spread=4.0, count=7), dict(ground=0.0, ao=(1.5, 0.6), gradient=(0.8, 1.0))),
        (coast.pebbles("PB_Pebbles_B", seed=422, spread=6.0, count=9), dict(ground=0.0, ao=(1.5, 0.6), gradient=(0.8, 1.0))),
        (coast.pebbles("PB_Pebbles_C", seed=423, spread=2.5, count=5), dict(ground=0.0, ao=(1.5, 0.6), gradient=(0.8, 1.0))),
        (props.grass_clump("PB_DuneGrass", seed=431, color=(156, 178, 104)), dict(ground=0.0, ao=(1.0, 0.5), gradient=(0.7, 1.4))),
        (coast.driftwood("PB_Driftwood", seed=441, length=8.0), dict(ground=0.0)),
        (props.palm("PB_Palm_A", seed=451, h=15, lean=14), dict(ground=0.0, ao=(3.0, 0.6), gradient=(0.75, 5.0))),
        (props.palm("PB_Palm_B", seed=452, h=12, lean=20, fronds=7), dict(ground=0.0, ao=(3.0, 0.6), gradient=(0.75, 5.0))),
        (props.bush("PB_Bush", seed=461, r=1.8), dict(ground=0.0, ao=(2.0, 0.8), gradient=(0.7, 2.0))),
        (coast.dinghy("PB_Wreck", seed=471, paint=(150, 112, 92), length=11.0, beam=4.6), dict(ground=None, ao=(2.0, 0.7), gradient=(0.75, 2.0))),
    ]


def ring_points(gr, level, spacing, near=None):
    """The longest isoline at `level` (optionally the one passing nearest `near`), evenly resampled."""
    lines = contour.isolines(gr, level)
    if near:
        lines.sort(key=lambda ln: min(math.dist(p, near) for p in ln))
    return contour.resample(lines[0], spacing)


def compose(L, gr):
    h = gr.height
    rng = random.Random(7)
    # The rock shelf on the dune's north flank, its foot on the beach; a smaller one facing the sandbar.
    L.put("PB_Cliff_A", -14, h(-14, -42) - 0.8, -42, face=(0, -1))
    L.put("PB_Cliff_B", 30, h(30, 36) - 0.6, 36, face=(0.6, 0.8))
    for asset, x, z, s in (("PB_Boulder_A", -30, -40, 1.0), ("PB_Boulder_B", -24, -46, 1.0), ("PB_Boulder_B", 2, -45, 0.8),
                           ("PB_Boulder_A", 166, 104, 1.1), ("PB_Boulder_B", 174, 101, 1.0), ("PB_Boulder_A", 160, 92, 0.8),
                           ("PB_Boulder_B", 176, 90, 0.9), ("PB_Boulder_A", 40, 30, 0.8)):
        L.put(asset, x, h(x, z) - 0.7 * s, z, face=(math.cos(x), math.sin(z)), scale=s)
    # Pebbles round the beach, just above the waterline (from the traced line at 1.0 studs, pulled a little inland).
    beach = ring_points(gr, 1.0, 13.0, near=(0, 55))
    beach = contour.offset_loop(beach[:-1], 1.5, inward=True)
    for i, (x, z) in enumerate(beach):
        if math.dist((x, z), (2, 24)) < 26 or math.dist((x, z), (-32, 24)) < 10:
            continue  # the landmark's foot and the wreck
        if i % 2 == 0:
            asset = ("PB_Pebbles_A", "PB_Pebbles_B", "PB_Pebbles_C")[i % 3]
            L.put(asset, x, h(x, z) - 0.25, z, face=(rng.uniform(-1, 1), rng.uniform(-1, 1)))
    # Dune grass on the upper sand, driftwood on the beach.
    upper = ring_points(gr, 4.0, 11.0, near=(0, 40))
    for i, (x, z) in enumerate(upper):
        if math.dist((x, z), (6, -4)) < 16 or math.dist((x, z), (2, 24)) < 18:
            continue  # the treasure on the dune top, the landmark
        L.put("PB_DuneGrass", x, h(x, z) - 0.1, z, face=(rng.uniform(-1, 1), rng.uniform(-1, 1)), scale=rng.uniform(0.9, 1.3))
    for x, z, face in ((-44, 12, (1, 0.3)), (46, -18, (0.2, 1)), (70, 58, (1, -0.6))):
        L.put("PB_Driftwood", x, h(x, z), z, face=face)
    # V14 palms where V10's stand (their invisible straight trunks stay as the collision), bushes at their feet.
    for i, (x, z) in enumerate(((-18, 9.9), (30, 18.4), (8, -32.3), (168, 96.1))):
        L.put("PB_Palm_A" if i % 2 == 0 else "PB_Palm_B", x, h(x, z) - 0.3, z, face=(math.cos(i * 2.1), math.sin(i * 2.1)))
        L.hide("Palm%d" % (i + 1), ["PalmTrunkLook", "PalmFrond", "Coconut"], x, 12, z, 30, 40, 30, asset="PB_Palm_A")
        L.put("PB_Bush", x + 3.5, h(x + 3.5, z + 2.5) - 0.2, z + 2.5)
    # The wreck: V14's rowboat half buried where V10's lies (V10's hull stays as the collision).
    L.put("PB_Wreck", -32, h(-32, 24) - 0.5, 24, face=(0.65, -0.76), tilt=(10, 16))
    L.hide("Wreck", ["Rowboat", "RowboatRib"], -32, 2, 24, 20, 14, 20, asset="PB_Wreck")


def shore(gr):
    """The surf and the wet sand along the waterline, as two made-to-measure assets."""
    water = ring_points(gr, 0.2, 3.0, near=(0, 55))
    loop = water[:-1]
    surf_line = contour.offset_loop(loop, 0.8, inward=False)
    surf_line.append(surf_line[0])
    foam = coast.foam_line("PB_Surf", [(x, -z, 0.0) for x, z in surf_line], width=1.6, seed=9)
    land = contour.offset_loop(loop, 3.2, inward=True)
    edge = contour.offset_loop(loop, 0.2, inward=True)
    land.append(land[0])
    edge.append(edge[0])
    inner = [(x, -z, gr.height(x, z) + 0.25) for x, z in land]
    outer = [(x, -z, max(gr.height(x, z), 0.0) + 0.2) for x, z in edge]
    wet = coast.band("PB_WetSand", inner, outer, seed=10)
    return foam, wet


def main():
    K.reset_scene()
    gr = G.Ground("pebble_ground.txt")
    col = K.collection("ASSETS_" + SET)
    L = Layout(SET, ANCHOR)
    x = 0.0
    for asset, opts in assets():
        asset.props["set"] = SET
        obj = K.build(asset, collection_=col, **opts)
        obj.location = (x, 400, 0)
        x += max(6.0, max(v.x for v in asset.verts) - min(v.x for v in asset.verts) + 4.0)
        L.register(obj)
    foam, wet = shore(gr)
    for a in (foam, wet):
        a.props["set"] = SET
        obj = K.build(a, collection_=col, ground=None, ao=(1.0, 0.0), gradient=(1.0, 0.0))
        L.register(obj)
    compose(L, gr)
    L.put("PB_WetSand", 0, 0, 0)
    L.put("PB_Surf", 0, 0, 0, motion="surf")
    L.ground_ref(gr, -160, 260, -160, 180)
    K.save(BLEND)
    lgexport.export_file(SET)
    out = os.environ.get("LG_PREVIEW")
    if out:
        bpy.context.view_layer.update()
        for o in col.objects:
            o.hide_render = True
        K.preview(os.path.join(out, "pebble_top.png"), (40, -20, 420), (40, -20, 0), lens=30, light="FLAT")
        K.preview(os.path.join(out, "pebble_sea.png"), (-120, 140, 40), (0, 0, 6), lens=30, light="FLAT")


main()

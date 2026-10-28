"""Builds art/blender/HD_HarborDistrict.blend (V14 Showcase A: the Goblin Port's Harbour District) and exports it.

    blender --background --factory-startup --python art/blender/scripts/build_harbor.py

The district runs from Madame Ragwort's Wardrobe (south of the plaza) east along the promenade to the Port's east
shore: a boardwalk above the beach, three waterfront houses facing the sea and the regattas, a jetty with rowboats,
the Regatta dock re-planked, flagstone paths, palms, bushes, props, rocks and surf. Coordinates are the game's, relative
to the Port's centre (Config.PORT.CENTER = 0, 0, 4600), on the ground captured in art/references/port_ground.txt.

Once someone edits the .blend by hand, the .blend is the source: export it with lgexport.py instead of re-running this.
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import buildings  # noqa: E402
import coast  # noqa: E402
import ground as G  # noqa: E402
import lgexport  # noqa: E402
import lgkit as K  # noqa: E402
import props  # noqa: E402
import waterfront as Wf  # noqa: E402
from layout import Layout  # noqa: E402

SET = "Harbor"
BLEND = os.path.join(K.ART, "blender", "HD_HarborDistrict.blend")
ANCHOR = (0.0, 0.0, 4600.0)
HOUSE = dict(ground=0.0, ao=(5.0, 0.7), gradient=(0.82, 8.0))
PROP = dict(ground=0.0)


def assets():
    return [
        (buildings.ragwort_wardrobe(), HOUSE),
        (Wf.tavern(), HOUSE),
        (Wf.net_loft(), HOUSE),
        (Wf.chandlery(), HOUSE),
        (Wf.boardwalk(), dict(ground=-4.4, ao=(3.0, 0.6), gradient=(0.6, 4.0))),
        (Wf.dock_module(), dict(ground=-6.0, ao=(3.0, 0.6), gradient=(0.55, 6.0))),
        (coast.flagstones(), dict(ground=None, ao=(1.0, 0.3), gradient=(1.0, 0.0))),
        (props.barrel(), PROP),
        (props.crate(), PROP),
        (props.lantern_post(), dict(ground=0.0, gradient=(0.8, 4.0))),
        (props.bench(), PROP),
        (props.sack(), PROP),
        (props.rope_coil(), PROP),
        (props.bollard(), PROP),
        (props.lobster_pot(), PROP),
        (props.anchor(), PROP),
        (props.planter(), dict(ground=0.0, gradient=(0.85, 1.5))),
        (props.palm("HD_Palm_A", seed=11, h=16, lean=12), dict(ground=0.0, ao=(3.0, 0.6), gradient=(0.75, 5.0))),
        (props.palm("HD_Palm_B", seed=29, h=12, lean=18, fronds=7), dict(ground=0.0, ao=(3.0, 0.6), gradient=(0.75, 5.0))),
        (props.bush("HD_Bush_A", seed=12, r=1.6), dict(ground=0.0, ao=(2.0, 0.8), gradient=(0.7, 2.0))),
        (props.bush("HD_Bush_B", seed=31, r=2.2), dict(ground=0.0, ao=(2.5, 0.8), gradient=(0.7, 2.5))),
        (props.grass_clump(), dict(ground=0.0, ao=(1.0, 0.5), gradient=(0.7, 1.4))),
        (coast.rock("CO_Rock_A", seed=201, r=3.2), dict(ground=0.0, ao=(3.0, 0.7), gradient=(0.7, 3.0))),
        (coast.rock("CO_Rock_B", seed=202, r=2.0, squash=0.6), dict(ground=0.0, ao=(2.0, 0.7), gradient=(0.7, 2.0))),
        (coast.rock("CO_Rock_C", seed=203, r=1.2, squash=0.65, moss=False), dict(ground=0.0, ao=(1.5, 0.7), gradient=(0.75, 1.5))),
        (coast.driftwood("CO_Driftwood", seed=211), PROP),
        (coast.dinghy("HD_Dinghy_Red", seed=221, paint=(196, 66, 52)), dict(ground=None, ao=(2.0, 0.6), gradient=(0.8, 2.0))),
        (coast.dinghy("HD_Dinghy_Teal", seed=222, paint=(56, 150, 150)), dict(ground=None, ao=(2.0, 0.6), gradient=(0.8, 2.0))),
    ]


# The east shore's waterline (where the captured terrain crosses the sea's surface), north to south-west.
WATERLINE = [
    (205, 96), (205, 120), (205, 144), (201, 152), (197, 162), (192, 168), (188, 174), (184, 180), (180, 184),
    (176, 188), (172, 192), (165, 196), (160, 200), (152, 204), (144, 208), (136, 212), (131, 216), (124, 220),
    (119, 224), (115, 228), (108, 232), (100, 236), (95, 240), (88, 244), (83, 248), (79, 252), (75, 256),
]
BOARDWALK = [(186, 114), (186, 152), (174, 168), (163, 176)]


def compose(L, gr):
    h = gr.height
    # Madame Ragwort's Wardrobe, exactly on V13's (its walls, floor and counter stay as the collision).
    L.put("HD_RagwortWardrobe", 0, 6, 112, face=(0, -1))
    L.hide("Wardrobe", buildings.ragwort_hides(), 0, 15, 112, 38, 40, 40, asset="HD_RagwortWardrobe")
    # The promenade: V13's lanterns and benches, redrawn where they stand (benches keep their solid seats).
    for x, z in ((78, 96), (98, 122), (118, 96), (138, 122), (158, 96)):
        L.put("HD_LanternPost", x, h(x, z), z, face=(0, 1) if z < 109 else (0, -1))
    for x in (98, 138):
        L.put("HD_Bench", x, h(x, 109), 109, face=(-1, 0))
    L.hide("PromenadeLamps", ["PathLanternPost", "PathLantern"], 118, 10, 109, 96, 20, 40, asset="HD_LanternPost")
    L.hide("PromenadeBenches", ["Bench", "BenchBack", "BenchLeg"], 118, 10, 109, 96, 20, 40, asset="HD_Bench")
    # A flagstone path from the Wardrobe's corner to the boardwalk (laid just on the turf: decoration, no collision).
    L.along("HD_Flagstones", [(22, 103), (158, 103), (176, 117)], 8.0, lambda x, z: h(x, z) + 0.02)
    # The waterfront houses on the plateau, fronts to the sea.
    L.put("HD_Tavern", 166, 6, 132, face=(1, 0))
    L.put("HD_NetLoft", 166, 6, 155.5, face=(1, 0))
    L.put("HD_Chandlery", 146, 6, 175.6, face=(0.6, 0.8))
    # The boardwalk, flush with the plateau, its piles down on the beach; a jetty out over the water at the tavern.
    L.along("HD_Boardwalk", BOARDWALK, 12.0, 6.0, face_side=1)
    for (ax, az), (bx, bz) in zip(BOARDWALK, BOARDWALK[1:]):
        length = math.hypot(bx - ax, bz - az)
        L.solid((ax + bx) / 2, 5.5, (az + bz) / 2, 10.4, 1.0, length + 2.0, face=((bx - ax) / length, (bz - az) / length))
    for x in (197, 209):
        L.put("HD_Boardwalk", x, 6.0, 140, face=(0, -1))
    L.solid(203, 5.5, 140, 26.0, 1.0, 10.4)
    L.put("HD_Dinghy_Red", 215, 0.2, 133.5, face=(0, 1), motion="bob", phase=0.0)
    L.put("HD_Dinghy_Teal", 216, 0.2, 147, face=(0.2, -1), motion="bob", phase=1.7)
    for z in (135.5, 144.5):
        L.put("HD_Bollard", 213.5, 6.0, z)
    # Lanterns, bollards and cargo along the boardwalk.
    for x, z in ((191, 120), (191, 146), (183.5, 160.5), (171, 173.5)):
        L.put("HD_LanternPost", x, 6.0, z, face=(-1, 0))
    for x, z in ((191, 130), (191, 152), (178, 167)):
        L.put("HD_Bollard", x, 6.0, z)
    L.put("HD_Barrel", 179, 6, 124, face=(1, 0))
    L.put("HD_Barrel", 180.6, 6, 126.5, face=(1, 0.3))
    L.put("HD_Barrel", 178.2, 6, 127.4, face=(0.4, 1), scale=0.9)
    L.put("HD_Crate", 180, 6, 138.5, face=(1, 0.2))
    L.put("HD_Crate", 180, 9.0, 138.7, face=(1, -0.3), scale=0.8)
    L.put("HD_Sack", 182.5, 6, 141, face=(1, 0))
    L.put("HD_RopeCoil", 189, 6, 136)
    L.put("HD_Planter", 176.6, 6, 121.0, face=(1, 0))
    L.put("HD_LobsterPot", 174.5, 6, 149.5, face=(1, 0.5))
    L.put("HD_LobsterPot", 175.0, 6, 151.5, face=(1, -0.4))
    L.put("HD_LobsterPot", 174.6, 7.2, 150.4, face=(1, 0.1), scale=0.9)
    L.put("HD_RopeCoil", 174, 6, 162)
    L.put("HD_Anchor", 160.5, 6, 184.5, face=(0.6, 0.8))
    L.put("HD_Crate", 141.5, 6, 186.0, face=(0.5, 1))
    L.put("HD_Barrel", 139.0, 6, 183.6, face=(0.6, 0.8))
    # The Regatta dock, re-planked over V13's (its deck and posts stay as the collision).
    for k in range(7):
        L.put("HD_DockModule", 163 + 80 / 7 * (k + 0.5), 6.0, 62, face=(0, -1), scale=(80 / 7 / 12, 1, 1))
    L.hide("RegattaDock", ["RegattaDock", "DockPost"], 203, 0, 62, 92, 30, 22, asset="HD_DockModule")
    # Green: palms between the houses and on the beach, bushes at the corners, grass on the sand.
    for asset, x, z, s in (("HD_Palm_A", 179, 115.5, 1.0), ("HD_Palm_B", 177, 147.5, 1.0), ("HD_Palm_A", 155, 164.5, 0.9),
                           ("HD_Palm_B", 150, 196, 1.1), ("HD_Palm_A", 120, 206, 1.0), ("HD_Palm_B", 160, 117, 0.85)):
        L.put(asset, x, h(x, z) - 0.3, z, scale=s)
    for asset, x, z in (("HD_Bush_A", 154, 120.5), ("HD_Bush_B", 152, 143), ("HD_Bush_A", 158.5, 146.5), ("HD_Bush_B", 156, 160),
                        ("HD_Bush_A", 135, 168), ("HD_Bush_B", 18, 98), ("HD_Bush_A", -19, 99), ("HD_Bush_B", 60, 99)):
        L.put(asset, x, h(x, z) - 0.2, z)
    for x, z in ((166, 190), (140, 200), (128, 210), (110, 222), (96, 232), (176, 180), (150, 190), (104, 214)):
        L.put("HD_GrassClump", x, h(x, z) - 0.1, z, face=(math.cos(x), math.sin(z)))
    # The shore: rocks along the step from the turf down to the beach and at the waterline, driftwood, the dinghies'
    # cousins pulled up on the sand, the surf.
    for asset, x, z, s in (("CO_Rock_A", 140, 192, 1.0), ("CO_Rock_B", 145, 189, 1.0), ("CO_Rock_C", 136, 194.5, 1.0),
                           ("CO_Rock_A", 101, 214, 1.1), ("CO_Rock_C", 106, 211, 1.2), ("CO_Rock_B", 86, 226, 1.0),
                           ("CO_Rock_A", 166, 197, 0.9), ("CO_Rock_C", 162, 200.5, 1.0), ("CO_Rock_B", 128, 217, 0.8),
                           ("CO_Rock_A", 202, 104, 0.8), ("CO_Rock_C", 199, 110, 1.0), ("CO_Rock_B", 203, 158, 0.9)):
        L.put(asset, x, h(x, z) - 0.6 * s, z, face=(math.cos(x * 1.7), math.sin(z * 1.3)), scale=s)
    L.put("CO_Driftwood", 128, h(128, 206), 206, face=(1, 0.4))
    L.put("CO_Driftwood", 158, h(158, 194), 194, face=(0.3, 1), scale=0.8)
    L.put("HD_Dinghy_Teal", 132, h(132, 200) + 0.1, 200, face=(0.5, 0.8), tilt=(4, -6))
    surf = [(x + 1.5, z + 0.8) for x, z in WATERLINE]
    return surf


def main():
    K.reset_scene()
    gr = G.Ground("port_ground.txt")
    col = K.collection("ASSETS_" + SET)
    L = Layout(SET, ANCHOR)
    x = 0.0
    for asset, opts in assets():
        asset.props["set"] = SET
        obj = K.build(asset, collection_=col, **opts)
        obj.location = (x, -400, 0)  # a row of every asset, out of the way of the layout
        x += max(6.0, max(v.x for v in asset.verts) - min(v.x for v in asset.verts) + 4.0)
        L.register(obj)
    surf = compose(L, gr)
    foam = coast.foam_line("HD_Surf", [(px, -pz, 0.0) for px, pz in surf], width=1.5, seed=5)
    foam.props["set"] = SET
    foam_obj = K.build(foam, collection_=col, ground=None, ao=(1.0, 0.0), gradient=(1.0, 0.0))
    L.register(foam_obj)
    foam_obj.location = (0, 0, 0)
    L.put("HD_Surf", 0, 0, 0, motion="surf")
    foam_obj.location = (x, -400, 0)
    L.ground_ref(gr, -60, 260, 40, 300)
    K.save(BLEND)
    lgexport.export_file(SET)
    out = os.environ.get("LG_PREVIEW")
    if out:
        bpy.context.view_layer.update()
        hide = [o for o in col.objects]
        for o in hide:
            o.hide_render = True
        K.preview(os.path.join(out, "harbor_top.png"), (110, -150, 420), (110, -150, 0), lens=30, light="FLAT")
        K.preview(os.path.join(out, "harbor_sea.png"), (330, -150, 40), (150, -150, 6), lens=28, light="FLAT")
        K.preview(os.path.join(out, "harbor_promenade.png"), (60, -60, 14), (150, -130, 8), lens=26, light="FLAT")


main()

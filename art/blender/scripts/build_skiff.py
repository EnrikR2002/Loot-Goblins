"""Builds art/blender/SK_HeroSkiff.blend (V14 Showcase B: the Hero Skiff) and exports it.

    blender --background --factory-startup --python art/blender/scripts/build_skiff.py

The skiff is not placed by a layout: the game puts it on every skiff's hull part (client/Renaissance.lua).
Once someone edits the .blend by hand, the .blend is the source: export it with lgexport.py instead of re-running this.
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lgexport  # noqa: E402
import lgkit as K  # noqa: E402
import skiff  # noqa: E402

SET = "Skiff"
BLEND = os.path.join(K.ART, "blender", "SK_HeroSkiff.blend")


def main():
    K.reset_scene()
    col = K.collection("ASSETS_" + SET)
    a = skiff.hero_skiff()
    a.props["set"] = SET
    print("[skiff]", a.tris(), "tris", len(a.verts), "verts |", K.report(a))
    # Occlusion with the sea's surface as the ground (the hull's waterline is 0.2 below the hull part's centre).
    obj = K.build(a, collection_=col, ground=-1.7, ao=(3.0, 0.6), gradient=(0.8, 3.0))
    # A reference of V10's skiff hull part and seats (not exported), to check the fit by eye.
    ref = K.collection("REF_" + SET)
    for name, size, pos in (("REF_HullPart", (9, 20, 3), (0, 0, 0)), ("REF_Driver", (3.4, 3.4, 0.8), (0, -6, 2.2)), ("REF_Passenger", (3.4, 3.4, 0.8), (0, -2, 2.2))):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "CUBE"
        e.location = pos
        e.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
        ref.objects.link(e)
    K.save(BLEND)
    lgexport.export_file(SET)
    out = os.environ.get("LG_PREVIEW")
    if out:
        K.preview(os.path.join(out, "skiff_34.png"), (22, 26, 12), (0, 1, 3), lens=35, light="FLAT")
        K.preview(os.path.join(out, "skiff_side.png"), (34, -2, 4), (0, 1, 4), lens=35, light="STUDIO")
    del obj


main()

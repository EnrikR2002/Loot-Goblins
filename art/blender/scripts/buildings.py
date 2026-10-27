"""Harbour District buildings (V14). Each returns an lgkit.Asset whose origin is the middle of its footprint at ground
level, its front towards +Y (Roblox -Z).

HD_RagwortWardrobe dresses Madame Ragwort's Wardrobe exactly where V13 built it (Port centre + (0, 6, 112), front
towards the plaza): its walls stand on V13's walls, which stay as the collision, so nothing about walking, the counter
or the window changes. The waterfront houses are new and bring their own collision proxies (COL_ boxes).
"""

import math
import random

from mathutils import Vector

import architecture as A
import lgkit as K
import props
from lgkit import R, S, T

PURPLE = (118, 52, 128)
CREAM = (250, 244, 230)
GOLD = (255, 196, 46)
RED_TILE = (192, 76, 56)


def _scissors(a, board_m):
    """Ragwort's emblem on her hanging sign: gold shears, on both faces."""
    for face in (-1, 1):
        m = board_m @ T(face * 0.2, 0, 0) @ R(0, 0, 90 if face > 0 else -90) @ R(90, 0, 0)
        for side in (-1, 1):
            blade = [(side * 0.15, -0.9, 0), (side * 0.05, 0.0, 0), (-side * 0.2, 0.7, 0)]
            a.add(K.tube(blade, [0.06, 0.14, 0.04], n=4), "GoldTrim", matrix=m @ R(0, 0, side * 12), jitter=0)
            ring = [(side * 0.35 + math.cos(t / 8 * 2 * math.pi) * 0.28, -1.15 + math.sin(t / 8 * 2 * math.pi) * 0.28, 0) for t in range(9)]
            a.add(K.tube(ring, 0.06, n=4), "GoldTrim", matrix=m, jitter=0)


def ragwort_wardrobe():
    """Madame Ragwort's Wardrobe: a crooked half-timbered tailor's house, cream plaster, red tiles, her purple."""
    a = K.Asset("HD_RagwortWardrobe", seed=41)
    W, D, H = 34.0, 24.0, 18.0
    hw, hd = W / 2, D / 2
    plaster = (246, 234, 206)
    # Footings: a course of dressed stone round the walls (front: either side of the shop window only).
    # Side and back walls: two storeys of frame and plaster.
    posts = [0, 8.0, 16.0, 24.0]
    rails = [1.2, 7.0, 12.4, 18.0]
    west = T(-hw, -hd, 0) @ R(0, 0, 90)  # runs back to front along +Y, its face out (-X)
    east = T(hw, hd, 0) @ R(0, 0, -90)  # front to back, face out (+X)
    back = T(hw, -hd, 0) @ R(0, 0, 180)  # east to west, face out (-Y)
    A.stone_footing(a, back, W, 1.2, seed=1)
    A.stone_footing(a, west, D, 1.2, seed=2)
    A.stone_footing(a, east, D, 1.2, seed=3)
    ops = []
    ops += A.timber_wall(a, west, D, H, posts, rails, {(0, 0): "brace", (1, 0): "door", (2, 0): "window_shutters", (0, 1): "window", (1, 1): "window", (2, 1): "brace_r", (0, 2): "cross", (2, 2): "cross"}, plaster=plaster, seed=10)
    ops += A.timber_wall(a, east, D, H, posts, rails, {(0, 0): "window_shutters", (1, 0): "window_shutters", (2, 0): "brace", (0, 1): "window", (1, 1): "window", (2, 1): "brace", (0, 2): "cross", (2, 2): "cross"}, plaster=plaster, seed=20)
    ops += A.timber_wall(a, back, W, H, [0, 8.5, 17.0, 25.5, 34.0], rails, {(0, 0): "brace", (1, 0): "window", (2, 0): "window", (3, 0): "brace_r", (0, 1): "cross", (1, 1): "window", (2, 1): "window", (3, 1): "cross"}, plaster=plaster, seed=30)
    for kind, m, w, h in ops:
        if kind == "door":
            dm = A.door_in_bay(a, m, w, h, door_w=3.8, door_h=5.2, plaster=plaster, color=PURPLE, seed=7)
            A.lantern_on_wall(a, dm @ T(2.9, 0, 1.4))
        else:
            on_back = m.translation.y < -D / 2 + 0.5
            A.window(a, m, w - 0.2, h - 0.3, shutters=(84, 140, 132) if kind == "window_shutters" else None, box=[(232, 78, 96), (255, 210, 80), (190, 120, 230)] if kind == "window" and h < 6 and not on_back else None, seed=int(m.translation.x * 10 + m.translation.y))
    # The shop front (+Y): stone stall riser, a full-width display window (V13's mannequins stand behind it), corner
    # posts, a carved bressummer over it, a plastered band above where the painted sign hangs.
    fy = hd
    for x in (-hw + 0.4, hw - 0.4):
        a.add(K.box(1.0, 1.0, H, bevel=0.1, wonk=0.04, seed=int(x)), "DarkWood", color=A.FRAME, matrix=T(x, fy - 0.4, H / 2))
    a.add(K.box(W - 1.6, 1.3, 2.0, bevel=0.12, wonk=0.04, seed=3), "Sandstone", matrix=T(0, fy - 0.55, 1.0))
    a.add(K.box(W - 1.6, 0.3, 0.3), "GoldTrim", matrix=T(0, fy + 0.12, 2.05), jitter=0)
    a.add(K.box(30.0, 0.2, 9.2), "ShopGlass", matrix=T(0, fy - 0.9, 6.6), jitter=0)
    for x in (-15.2, -10, -5, 0, 5, 10, 15.2):
        a.add(K.box(0.5 if abs(x) > 15 else 0.32, 0.5, 9.4, bevel=0.06), "PaintedWood", color=(60, 40, 52), matrix=T(x, fy - 0.6, 6.6))
    a.add(K.box(30.4, 0.5, 0.32, bevel=0.06), "PaintedWood", color=(60, 40, 52), matrix=T(0, fy - 0.6, 9.3))
    for x in (-12.5, -7.5, -2.5, 2.5, 7.5, 12.5):
        a.add(K.box(0.2, 0.4, 2.0), "PaintedWood", color=(60, 40, 52), matrix=T(x, fy - 0.6, 10.3))
    # bressummer with corbels
    a.add(K.box(W + 0.4, 1.3, 1.4, bevel=0.15, wonk=0.05, seed=5), "DarkWood", color=A.FRAME, matrix=T(0, fy - 0.3, 12.1))
    for x in (-hw + 0.6, -8.0, 8.0, hw - 0.6):
        a.add(K.slab([(0, 0), (1.4, 0), (0, -1.4)], 0.8, bevel=0.05), "DarkWood", color=A.FRAME, matrix=T(x + 0.4, fy + 0.3, 11.4) @ R(90, 0, -90))
    # upper band: plaster panel with a frame, then the top plate
    a.add(K.box(W - 1.6, 0.8, 5.4), "Plaster", color=plaster, matrix=T(0, fy - 0.58, 15.4), smooth=10, jitter=0.02)
    a.add(K.box(W + 0.4, 0.9, 0.8, bevel=0.1, wonk=0.04, seed=6), "DarkWood", color=A.FRAME, matrix=T(0, fy - 0.3, 18.1))
    # the signboard backing behind V13's painted sign (its letters float just in front of this board)
    sb = T(0, fy + 0.15, 17.2)
    a.add(K.box(27.6, 0.6, 4.6, bevel=0.2, wonk=0.06, seed=8), "PaintedWood", color=(66, 40, 58), matrix=sb)
    for z in (-1, 1):
        a.add(K.box(28.2, 0.7, 0.28), "GoldTrim", matrix=sb @ T(0, 0.05, z * 2.35), jitter=0)
    for x in (-1, 1):
        a.add(K.box(0.28, 0.7, 4.9), "GoldTrim", matrix=sb @ T(x * 14.0, 0.05, 0), jitter=0)
        a.add(K.ball(0.5, subdiv=1, seed=x), "GoldTrim", matrix=sb @ T(x * 14.0, 0.2, 2.4), jitter=0)
    # Roof: steep and red-tiled, its gable towards the plaza (so the eaves never cover the painted sign).
    rise = A.tiled_roof(a, T(0, 0, H + 0.6) @ R(0, 0, 90), D, W, 36, overhang=1.6, gable_overhang=1.4, tile=RED_TILE, rows=7, sag=0.5, seed=9)
    A.gable_infill(a, T(0, hd, H + 0.4), W, rise - 0.3, color=plaster, seed=11)
    A.gable_infill(a, T(0, -hd, H + 0.4) @ R(0, 0, 180), W, rise - 0.3, color=plaster, seed=12)
    # collar beam and two small shuttered windows in the front gable, an oculus with a gold star above
    a.add(K.box(W * 0.62, 0.6, 0.6, bevel=0.08, wonk=0.05, seed=21), "DarkWood", color=A.FRAME, matrix=T(0, hd + 0.05, H + 0.4 + rise * 0.42))
    for x in (-8.5, 8.5):
        A.window(a, T(x, hd + 0.5, H + 2.8), 2.4, 2.6, shutters=(84, 140, 132), panes=(2, 2), seed=int(x))
    ocu = T(0, hd + 0.3, H + 0.4 + rise * 0.66)
    ring = [(math.cos(t / 12 * 2 * math.pi) * 1.5, 0, math.sin(t / 12 * 2 * math.pi) * 1.5) for t in range(13)]
    a.add(K.tube(ring, 0.3, n=5), "DarkWood", color=A.FRAME, matrix=ocu, smooth=50)
    a.add(K.cyl(1.3, 1.3, 0.2, n=10), "Glass", matrix=ocu @ T(0, -0.25, 0) @ R(-90, 0, 0), smooth=10)
    for k in range(4):
        a.add(K.box(0.18, 0.12, 2.2), "GoldTrim", matrix=ocu @ T(0, 0.02, 0) @ R(0, k * 45, 0), jitter=0)
    A.window(a, T(0, -hd - 0.5, H + 0.4 + rise * 0.4) @ R(0, 0, 180), 2.6, 2.8, panes=(2, 2), seed=4)
    # a finial on the front gable's peak
    a.add(K.cyl(0.3, 0.0, 1.6, n=5), "GoldTrim", matrix=T(0, hd + 1.4, H + 0.35 + rise + 0.6), jitter=0)
    # chimney through the back slope
    A.chimney(a, T(11, -4, H + 2.0), h=12.0, w=2.8, seed=12, lean=2.5)
    # Awning over the counter (V13's was purple and cream): from the bressummer out over the counter.
    A.awning(a, T(0, fy + 0.4, 11.6), 33.0, 6.6, 2.2, [PURPLE, CREAM], seed=13)
    # The counter, where V13's stands (its collision stays): a panelled front, a dark top, bolts of cloth.
    cm = T(0, fy + 5.0, 0)
    a.add(K.box(12.2, 3.2, 3.4, bevel=0.15, wonk=0.04, seed=14), "PaintedWood", color=(92, 54, 84), matrix=cm @ T(0, 0, 1.7))
    for x in (-4.5, -1.5, 1.5, 4.5):
        a.add(K.box(2.4, 0.2, 1.9, bevel=0.08), "PaintedWood", color=(120, 74, 108), matrix=cm @ T(x, 1.62, 1.55))
        a.add(K.box(2.0, 0.24, 0.12), "GoldTrim", matrix=cm @ T(x, 1.7, 2.5), jitter=0)
    a.add(K.box(12.8, 3.6, 0.45, bevel=0.12, wonk=0.03, seed=15), "DarkWood", color=(60, 40, 30), matrix=cm @ T(0, 0, 3.6))
    rng = random.Random(16)
    for k, c in enumerate([(220, 70, 70), (70, 120, 200), (240, 200, 90), (110, 180, 120), (180, 110, 200)]):
        a.add(K.cyl(0.42, 0.42, 3.0, n=8), "Canvas", color=c, matrix=cm @ T(-5.5 + k * 0.95, -0.6, 3.95) @ R(0, 90, rng.uniform(-8, 8)) @ T(0, 0, -1.5), smooth=40, jitter=0.03)
    a.add(K.cyl(0.6, 0.6, 0.35, n=10), "Canvas", color=(200, 60, 80), matrix=cm @ T(4.2, 0.3, 3.5), smooth=40)
    for k in range(5):
        ang = k * 72
        a.add(K.cyl(0.04, 0.04, 0.5, n=3), "GoldTrim", matrix=cm @ T(4.2, 0.3, 3.8) @ R(25, 0, ang), jitter=0)
    # Corner lanterns, a hanging sign towards the promenade, planters by the window.
    A.lantern_on_wall(a, T(-hw - 0.1, fy - 1.2, 10.2) @ R(0, 0, 90))
    A.lantern_on_wall(a, T(hw + 0.1, fy - 1.2, 10.2) @ R(0, 0, -90))
    A.hanging_sign(a, T(hw, fy - 2.5, 14.5) @ R(0, 0, -90), w=3.6, h=2.8, board=(70, 36, 66), emblem=_scissors, seed=17)
    for x in (-hw + 2.4, hw - 2.4):
        pm = T(x, fy + 1.8, 0)
        a.add(K.cyl(1.0, 1.3, 1.6, n=8, bevel=0.1), "RoofTile", color=(184, 98, 64), matrix=pm, smooth=35)
        a.add(K.ball(1.2, subdiv=1, squash=0.9, lump=0.15, seed=int(x)), "Foliage", color=(86, 160, 70), matrix=pm @ T(0, 0, 2.3), smooth=70)
        for k in range(4):
            ang = k * math.pi / 2 + 0.4
            a.add(K.ball(0.25, subdiv=0, seed=k), "Flower", color=(232, 78, 120), matrix=pm @ T(math.cos(ang) * 0.9, math.sin(ang) * 0.9, 2.9), smooth=70)
    # Inside, seen through the window: a plank floor, a back wall of shelves with bolts of cloth, two hanging lamps.
    for k in range(6):
        a.add(K.box(W - 2.2, (D - 2) / 6 - 0.08, 0.3, wonk=0.01, seed=k), "Timber", matrix=T(0, -hd + 1 + (D - 2) * (k + 0.5) / 6, 0.35), smooth=10, jitter=0.08)
    a.add(K.box(W - 2.4, 0.4, 11.0), "Plaster", color=(226, 206, 180), matrix=T(0, -hd + 1.4, 6.5), smooth=10)
    for z in (4.0, 8.0):
        a.add(K.box(W - 4, 1.4, 0.3, bevel=0.05), "DarkWood", color=A.FRAME, matrix=T(0, -hd + 2.2, z))
        x = -W / 2 + 3
        while x < W / 2 - 3:
            c = (rng.randint(80, 240), rng.randint(60, 200), rng.randint(70, 220))
            a.add(K.box(0.9, 1.1, 1.7), "Canvas", color=c, matrix=T(x, -hd + 2.2, z + 1.0), smooth=10, jitter=0.05)
            x += 1.8 + rng.uniform(0, 0.6)
    for x in (-8, 8):
        props.lantern_head(a, T(x, 2.0, 12.0))
    a.light((0, 2, 9), color=(255, 214, 160), range_=24, brightness=0.8)
    return a


def ragwort_hides():
    """V13's Wardrobe parts this asset replaces (inside a box round the building): their collision stays."""
    return [
        "ShopFloor",
        "ShopBack",
        "ShopSide",
        "ShopBeam",
        "ShopFront",
        "ShopFrontBeam",
        "ShopWindow",
        "Roof",
        "Chimney",
        "WardrobeSign",
        "ShopAwning",
        "ShopCounter",
    ]

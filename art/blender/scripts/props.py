"""Harbour props (V14): the small things goblins stand next to. Each function returns an lgkit.Asset.

Shared by the Harbour District (build_harbor.py) and the Pebble Isle coast (build_pebble.py). Front = Blender +Y.
"""

import math
import random

from mathutils import Vector

import lgkit as K
from lgkit import R, S, T


def barrel(asset_id="HD_Barrel", seed=1, h=3.2, r=1.25):
    """Bulging staves (each a slightly different tone), two dark iron hoops, a planked lid."""
    a = K.Asset(asset_id, seed)
    n = 12
    rings = []
    for k in range(6):
        z = h * k / 5
        rr = r * (0.84 + 0.16 * math.sin(math.pi * k / 5))
        rings.append([Vector((math.cos(2 * math.pi * i / n) * rr, math.sin(2 * math.pi * i / n) * rr, z)) for i in range(n)])
    # One piece per stave column so each can take its own tone.
    for i in range(n):
        bm = K.bmesh.new()
        cols = []
        for ring in rings:
            p0, p1 = ring[i], ring[(i + 1) % n]
            cols.append((bm.verts.new(p0), bm.verts.new(p1)))
        for (a0, a1), (b0, b1) in zip(cols, cols[1:]):
            bm.faces.new((a0, a1, b1, b0))
        K.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        # recalc can flip an open strip inwards: make them face out
        for f in bm.faces:
            c = f.calc_center_median()
            if f.normal.dot(Vector((c.x, c.y, 0))) < 0:
                f.normal_flip()
        tone = (168, 108, 62) if i % 2 else (184, 122, 70)
        a.add((bm, set()), "Timber", color=tone, smooth=40, jitter=0.07)
    lid = K.cyl(r * 0.86, r * 0.86, 0.12, n=n)
    a.add(lid, "DarkWood", matrix=T(0, 0, h - 0.18), smooth=10)
    for k in (-1, 0, 1):
        a.add(K.box(0.06, r * 1.6, 0.04), "DarkWood", color=(70, 46, 30), matrix=T(k * 0.55, 0, h - 0.05), jitter=0)
    for z in (0.55, h - 0.55):
        rr = r * (0.84 + 0.16 * math.sin(math.pi * z / h)) + 0.05
        pts = [(math.cos(2 * math.pi * i / 16) * rr, math.sin(2 * math.pi * i / 16) * rr, z) for i in range(17)]
        a.add(K.tube(pts, 0.11, n=4), "Metal", smooth=60, jitter=0.03)
    a.solid((r * 2, r * 2, h), T(0, 0, h / 2))
    return a


def crate(asset_id="HD_Crate", seed=2, s=3.0):
    """A slatted crate: a body, dark corner battens and a diagonal brace on two sides."""
    a = K.Asset(asset_id, seed)
    a.add(K.box(s - 0.2, s - 0.2, s - 0.2, bevel=0.05), "Timber", matrix=T(0, 0, s / 2), smooth=20)
    b = 0.32
    for x in (-1, 1):
        for y in (-1, 1):
            a.add(K.box(b, b, s, bevel=0.05, wonk=0.02, seed=x + 3 * y), "DarkWood", matrix=T(x * (s / 2 - b / 2), y * (s / 2 - b / 2), s / 2))
    for z in (b / 2, s - b / 2):
        for x in (-1, 1):
            a.add(K.box(b, s - 2 * b, b, bevel=0.05), "DarkWood", matrix=T(x * (s / 2 - b / 2), 0, z))
        for y in (-1, 1):
            a.add(K.box(s - 2 * b, b, b, bevel=0.05), "DarkWood", matrix=T(0, y * (s / 2 - b / 2), z))
    # slats: three planks per side face, slightly proud
    for face in range(4):
        rot = R(0, 0, face * 90)
        for k in range(3):
            z = 0.55 + k * (s - 1.1) / 2
            a.add(
                K.box(s - 2 * b, 0.12, (s - 2 * b) / 3 - 0.12, bevel=0.03, wonk=0.015, seed=face * 3 + k),
                "Timber",
                matrix=rot @ T(0, s / 2 - 0.12, z) @ R(0, a.rng.uniform(-2, 2), 0),
                jitter=0.08,
            )
        if face % 2 == 0:
            length = math.hypot(s - 2 * b, s - 2 * b)
            a.add(
                K.box(length - 0.3, 0.14, 0.32, bevel=0.04),
                "DarkWood",
                matrix=rot @ T(0, s / 2 - 0.02, s / 2) @ R(0, 45, 0),
            )
    a.solid((s, s, s), T(0, 0, s / 2))
    return a


def lantern_head(a, base):
    """A hanging iron lantern with a glowing core, at matrix `base` (the hook point, lantern hangs below)."""
    a.add(K.box(0.1, 0.1, 0.5), "Metal", matrix=base @ T(0, 0, -0.25))
    a.add(K.cyl(0.55, 0.15, 0.45, n=4), "Metal", matrix=base @ T(0, 0, -0.95) @ R(0, 0, 45), smooth=20)
    a.add(K.cyl(0.42, 0.42, 1.1, n=4), "Glow", matrix=base @ T(0, 0, -2.05) @ R(0, 0, 45), smooth=20, jitter=0)
    for i in range(4):
        a.add(K.box(0.09, 0.09, 1.25), "Metal", matrix=base @ R(0, 0, i * 90 + 45) @ T(0.45, 0, -1.5))
    a.add(K.cyl(0.5, 0.5, 0.14, n=4), "Metal", matrix=base @ T(0, 0, -2.15) @ R(0, 0, 45), smooth=20)


def lantern_post(asset_id="HD_LanternPost", seed=3, h=8.0):
    """A leaning harbour lamp: a stone foot, a tapered timber post, a curled bracket and a hanging lantern."""
    a = K.Asset(asset_id, seed)
    a.add(K.cyl(0.9, 0.75, 0.8, n=8, bevel=0.1, wonk=0.04, seed=seed), "Sandstone", smooth=30)
    lean = R(1.5, -1.0, 0)
    a.add(K.cyl(0.36, 0.26, h, n=8, bevel=0.05, wonk=0.03, seed=seed + 1), "DarkWood", matrix=lean @ T(0, 0, 0.6), smooth=35)
    top = lean @ T(0, 0, h + 0.5)
    a.add(K.cyl(0.42, 0.42, 0.25, n=8, bevel=0.05), "Metal", matrix=lean @ T(0, 0, h + 0.2))
    a.add(K.cyl(0.18, 0.0, 0.6, n=6), "GoldTrim", matrix=top @ T(0, 0, 0), smooth=40, jitter=0)
    # bracket: a beam out with a curled iron strap under it
    a.add(K.box(0.28, 2.4, 0.32, bevel=0.06), "DarkWood", matrix=lean @ T(0, 1.15, h - 0.4))
    curl = [(0, 0.2, h - 1.6), (0, 0.8, h - 1.2), (0, 1.5, h - 0.75), (0, 2.1, h - 0.6)]
    a.add(K.tube(curl, 0.08, n=4), "Metal", matrix=lean, smooth=50)
    hook = lean @ T(0, 2.2, h - 0.6)
    lantern_head(a, hook)
    a.light((lean @ T(0, 2.2, h - 2.6)).translation, color=(255, 196, 120), range_=20, brightness=1.1)
    return a


def bench(asset_id="HD_Bench", seed=4):
    """A chunky park bench sized like V10's (6 long, seat top 1.85 above the ground). Front = +Y."""
    a = K.Asset(asset_id, seed)
    for x in (-2.4, 2.4):
        a.add(K.box(0.45, 1.6, 1.6, bevel=0.08, wonk=0.03, seed=int(x)), "DarkWood", matrix=T(x, 0, 0.8))
        a.add(K.box(0.4, 0.4, 1.8, bevel=0.06), "DarkWood", matrix=T(x, -0.75, 2.4) @ R(-8, 0, 0))
    for k in range(3):
        a.add(
            K.box(6.2, 0.58, 0.18, bevel=0.05, wonk=0.02, seed=k),
            "Timber",
            matrix=T(0, -0.62 + k * 0.62, 1.72) @ R(0, a.rng.uniform(-1, 1), 0),
            jitter=0.08,
        )
    for k in range(2):
        a.add(
            K.box(6.2, 0.16, 0.5, bevel=0.05, wonk=0.02, seed=k + 9),
            "Timber",
            matrix=T(0, -0.95, 2.35 + k * 0.62) @ R(-8, 0, 0),
            jitter=0.08,
        )
    return a


def sack(asset_id="HD_Sack", seed=5):
    a = K.Asset(asset_id, seed)
    a.add(K.ball(0.9, subdiv=2, squash=1.0, lump=0.12, seed=seed), "Canvas", matrix=T(0, 0, 0.85) @ S(1, 0.85, 1.05), smooth=75)
    a.add(K.cyl(0.35, 0.25, 0.4, n=8), "Canvas", matrix=T(0, 0, 1.75), smooth=60)
    a.add(K.tube([(0.32, 0, 1.85), (0, 0.33, 1.85), (-0.32, 0, 1.85), (0, -0.33, 1.85), (0.32, 0, 1.85)], 0.06, n=4), "Rope")
    a.add(K.ball(0.32, subdiv=1, squash=0.6, seed=seed + 1), "Canvas", matrix=T(0, 0, 2.15), smooth=70)
    return a


def rope_coil(asset_id="HD_RopeCoil", seed=6):
    a = K.Asset(asset_id, seed)
    pts = []
    turns = 3.2
    for i in range(int(turns * 14) + 1):
        t = i / 14
        rr = 1.0 - 0.06 * t
        pts.append((math.cos(t * 2 * math.pi) * rr, math.sin(t * 2 * math.pi) * rr, 0.16 + t * 0.2))
    a.add(K.tube(pts, 0.17, n=6), "Rope", smooth=70)
    a.add(K.tube([(1.0, 0, 0.16), (1.6, 0.4, 0.1), (2.2, 0.3, 0.1)], 0.16, n=6), "Rope", smooth=70)
    return a


def bollard(asset_id="HD_Bollard", seed=7):
    """A mooring post with a rope wrapped round it."""
    a = K.Asset(asset_id, seed)
    a.add(K.cyl(0.62, 0.55, 2.4, n=8, bevel=0.1, wonk=0.04, seed=seed), "Driftwood", smooth=35)
    a.add(K.cyl(0.7, 0.62, 0.35, n=8, bevel=0.06), "DarkWood", matrix=T(0, 0, 2.3))
    pts = [(math.cos(t * 0.6) * 0.66, math.sin(t * 0.6) * 0.66, 1.2 + t * 0.03) for t in range(22)]
    a.add(K.tube(pts, 0.11, n=4), "Rope", smooth=60)
    return a


def lobster_pot(asset_id="HD_LobsterPot", seed=8):
    a = K.Asset(asset_id, seed)
    a.add(K.box(2.2, 1.5, 0.18, bevel=0.04), "DarkWood", matrix=T(0, 0, 0.09))
    for i in range(5):
        x = -0.95 + i * 0.475
        arc = [(x, -0.75 + 1.5 * j / 8, 0.15 + math.sin(math.pi * j / 8) * 1.0) for j in range(9)]
        a.add(K.tube(arc, 0.05, n=4), "Timber", smooth=50)
    for j in range(1, 8):
        ang = math.pi * j / 8
        y, z = -0.75 + 1.5 * j / 8, 0.15 + math.sin(ang) * 1.0
        a.add(K.tube([(-1.0, y, z), (1.0, y, z)], 0.035, n=3), "Rope", smooth=50)
    a.add(K.ball(0.28, subdiv=1, seed=seed), "Canvas", color=(230, 90, 60), matrix=T(1.25, 0.3, 0.25), smooth=70)
    return a


def anchor(asset_id="HD_Anchor", seed=9):
    """A big iron anchor leaning on its stock, for a doorstep or a quay corner."""
    a = K.Asset(asset_id, seed)
    lean = R(0, -18, 0) @ T(0.9, 0, 0)
    a.add(K.cyl(0.24, 0.2, 4.2, n=6, bevel=0.04), "Metal", matrix=lean @ T(0, 0, 0.5), smooth=30)
    a.add(K.box(2.6, 0.32, 0.32, bevel=0.06), "DarkWood", matrix=lean @ T(0, 0, 4.0))
    ring = [(math.cos(t / 8 * 2 * math.pi) * 0.42, 0, 4.9 + math.sin(t / 8 * 2 * math.pi) * 0.42) for t in range(9)]
    a.add(K.tube(ring, 0.09, n=4), "Metal", matrix=lean, smooth=60)
    arm = [(math.sin(t / 8 * math.pi - math.pi / 2) * 1.5, 0, 0.75 - math.cos(t / 8 * math.pi - math.pi / 2) * 0.9 + 0.3) for t in range(9)]
    a.add(K.tube(arm, [0.16, 0.2, 0.22, 0.24, 0.24, 0.24, 0.22, 0.2, 0.16], n=6), "Metal", matrix=lean, smooth=40)
    for side in (-1, 1):
        a.add(K.cyl(0.42, 0.0, 0.8, n=4), "Metal", matrix=lean @ T(side * 1.5, 0, 0.75) @ R(0, side * -50, 0), smooth=20)
    return a


def planter(asset_id="HD_Planter", seed=10, flowers=((232, 78, 96), (255, 200, 70), (180, 120, 230))):
    """A window box / street planter: planks, soil, two greens and flowers in three colours."""
    a = K.Asset(asset_id, seed)
    w, d, h = 4.0, 1.4, 1.0
    for side in (-1, 1):
        a.add(K.box(w, 0.16, h, bevel=0.04, wonk=0.02, seed=side), "PaintedWood", color=(70, 140, 132), matrix=T(0, side * (d / 2 - 0.08), h / 2))
        a.add(K.box(0.16, d, h, bevel=0.04), "PaintedWood", color=(70, 140, 132), matrix=T(side * (w / 2 - 0.08), 0, h / 2))
    a.add(K.box(w - 0.3, d - 0.3, 0.3), "Soil", matrix=T(0, 0, h - 0.2), jitter=0)
    rng = random.Random(seed)
    for i in range(7):
        x = -w / 2 + 0.5 + i * (w - 1) / 6 + rng.uniform(-0.1, 0.1)
        green = (86, 164, 70) if i % 2 else (112, 188, 84)
        a.add(K.ball(0.45, subdiv=1, lump=0.2, seed=seed + i), "Foliage", color=green, matrix=T(x, rng.uniform(-0.15, 0.15), h + 0.25), smooth=70)
        if i % 2 == 0:
            c = flowers[(i // 2) % len(flowers)]
            for k in range(3):
                fx, fy = x + rng.uniform(-0.3, 0.3), rng.uniform(-0.35, 0.35)
                a.add(K.ball(0.16, subdiv=1, seed=k), "Flower", color=c, matrix=T(fx, fy, h + 0.62 + rng.uniform(0, 0.15)), smooth=70, jitter=0.04)
    return a


def palm(asset_id="HD_Palm", seed=11, h=16.0, lean=12.0, fronds=8):
    """A banded, curving trunk with drooping fronds (two greens) and coconuts."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    ang = math.radians(rng.uniform(0, 360))
    dirx, diry = math.cos(ang), math.sin(ang)
    pts, radii = [], []
    segs = 9
    for i in range(segs + 1):
        t = i / segs
        off = math.sin(t * math.pi * 0.5) * math.tan(math.radians(lean)) * h * t
        pts.append((dirx * off, diry * off, t * h))
        radii.append(0.75 - 0.32 * t)
    # trunk as bands: one short tube per segment, alternating tone, slightly flared at the bottom
    for i in range(segs):
        p0, p1 = Vector(pts[i]), Vector(pts[i + 1])
        mid = p0.lerp(p1, 0.55)
        tone = (132, 98, 66) if i % 2 else (118, 86, 58)
        a.add(K.tube([p0, mid, p1], [radii[i] * 1.12, radii[i] * 0.98, radii[i + 1] * 1.04], n=7), "Bark", color=tone, smooth=60, jitter=0.04)
    top = Vector(pts[-1])
    a.add(K.ball(0.95, subdiv=1, squash=0.7, seed=seed), "Bark", color=(110, 84, 56), matrix=T(*top), smooth=60)
    for i in range(fronds):
        fa = 2 * math.pi * i / fronds + rng.uniform(-0.15, 0.15)
        length = rng.uniform(6.5, 8.0)
        droop = rng.uniform(2.6, 4.0)
        lift = rng.uniform(0.6, 1.4)
        path, widths = [], []
        for k in range(8):
            t = k / 7
            r_ = t * length
            z = lift * math.sin(t * math.pi * 0.6) - droop * t * t
            path.append(top + Vector((math.cos(fa) * r_, math.sin(fa) * r_, z + 0.2)))
            widths.append(0.4 + 1.9 * math.sin(math.pi * min(1.0, t * 1.15)) if t < 0.95 else 0.15)
        green = (78, 156, 64) if i % 2 else (104, 182, 78)
        a.add(K.strip(path, widths, fold=0.22), "Foliage", color=green, smooth=55, jitter=0.05)
        a.add(K.strip(path, widths, normal=Vector((0, 0, -1)), fold=-0.22), "Foliage", color=K.dim(green, 0.25), smooth=55, jitter=0.05)
    for i in range(3):
        ca = 2 * math.pi * i / 3 + 0.4
        a.add(K.ball(0.42, subdiv=1, seed=seed + i), "Bark", color=(96, 70, 44), matrix=T(*(top + Vector((math.cos(ca) * 0.6, math.sin(ca) * 0.6, -0.55)))), smooth=70)
    return a


def bush(asset_id="HD_Bush", seed=12, r=1.6):
    """A round shrub: three overlapping lumpy balls in two greens, darker underneath."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    for i in range(4):
        ang = 2 * math.pi * i / 4 + rng.uniform(-0.3, 0.3)
        rr = r * rng.uniform(0.55, 0.8)
        off = (math.cos(ang) * r * 0.45, math.sin(ang) * r * 0.45, rr * 0.75)
        green = (78, 146, 68) if i % 2 else (98, 166, 76)
        a.add(K.ball(rr, subdiv=2, squash=0.85, lump=0.18, seed=seed + i), "Foliage", color=green, matrix=T(*off), smooth=70)
    a.add(K.ball(r * 0.7, subdiv=2, squash=0.9, lump=0.15, seed=seed + 9), "Foliage", color=(112, 178, 86), matrix=T(0, 0, r * 1.05), smooth=70)
    return a


def grass_clump(asset_id="HD_GrassClump", seed=13, color=(132, 176, 86)):
    """Beach grass: a fan of folded blades."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    for i in range(9):
        ang = 2 * math.pi * i / 9 + rng.uniform(-0.2, 0.2)
        tilt = rng.uniform(0.25, 0.6)
        length = rng.uniform(1.6, 2.6)
        path = []
        for k in range(4):
            t = k / 3
            path.append((math.cos(ang) * (0.15 + tilt * length * t * t), math.sin(ang) * (0.15 + tilt * length * t * t), length * t))
        a.add(K.strip(path, [0.28, 0.24, 0.16, 0.03], normal=Vector((math.cos(ang), math.sin(ang), 0)), fold=0.15), "Foliage", color=color, smooth=60, jitter=0.1)
    return a

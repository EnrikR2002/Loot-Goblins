"""Coast pieces (V14): rocks, pebbles, cliff shelves, driftwood, flagstones, rowboats and the surf line.

Rocks are chunky and faceted (a convex hull of scattered points, big flat facets, bevelled edges caught by the light)
and come in clusters: one big, two medium, a few small. Pebbles are smooth and rounded. Everything sits with its base at
z=0 and is made to be sunk a little into the ground or the sand when it is placed.
"""

import math
import random

from mathutils import Vector

import lgkit as K
from lgkit import R, S, T

ROCK = (150, 138, 128)
ROCK_TOP = (176, 166, 150)
MOSS = (120, 150, 84)


def rock(asset_id, seed, r=3.0, squash=0.7, mat="CoastRock", color=ROCK, moss=True):
    """A boulder: faceted body, a lighter sun-bleached top, a little moss on the upper facets."""
    a = K.Asset(asset_id, seed)
    bm, hl = K.rock(r, seed, squash=squash, points=24, bevel=r * 0.06)
    # paint by facet: top facets lighter (and some mossy), the rest the rock colour
    rng = random.Random(seed)
    a.add((bm, hl), mat, color=color, matrix=T(0, 0, r * squash * 0.42), smooth=28, jitter=0.07, edge=0.18)
    # A cap of lighter facets: a second, smaller hull sitting on the first (cheap and reads as weathering).
    cap, chl = K.rock(r * 0.72, seed + 1, squash=squash * 0.5, points=14, bevel=r * 0.05)
    a.add((cap, chl), mat, color=ROCK_TOP, matrix=T(rng.uniform(-0.2, 0.2) * r, rng.uniform(-0.2, 0.2) * r, r * squash * 0.95), smooth=28, jitter=0.06, edge=0.2)
    if moss:
        a.add(K.ball(r * 0.36, subdiv=1, squash=0.35, lump=0.3, seed=seed + 2), "Foliage", color=MOSS, matrix=T(-r * 0.25, r * 0.15, r * squash * 1.18), smooth=60)
    return a


def pebbles(asset_id, seed, spread=4.0, count=7):
    """A cluster of smooth sea-worn pebbles in grey-blue and tan (Pebble Isle's signature)."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    tones = [(150, 162, 176), (178, 166, 146), (126, 140, 156), (196, 186, 166), (160, 150, 140)]
    for i in range(count):
        ang = rng.uniform(0, 2 * math.pi)
        d = spread * math.sqrt(rng.random()) * (0.2 if i == 0 else 1.0)
        r = rng.uniform(0.7, 1.6) * (1.6 if i == 0 else 1.0)
        sq = rng.uniform(0.45, 0.7)
        a.add(
            K.ball(r, subdiv=2 if i == 0 else 1, squash=sq, lump=0.06, seed=seed + i),
            "Pebble",
            color=tones[rng.randrange(len(tones))],
            matrix=T(math.cos(ang) * d, math.sin(ang) * d, r * sq * 0.7) @ R(rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(0, 180)) @ S(1, rng.uniform(0.65, 0.95), 1),
            smooth=80,
            jitter=0.05,
        )
    return a


def cliff(asset_id, seed, length=16.0, height=10.0, depth=6.0, color=ROCK):
    """A cliff shelf: three stacked strata of faceted rock, each stepping back, a grassy lip on top."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    z = 0.0
    layers = 3
    for k in range(layers):
        h = height / layers * rng.uniform(0.85, 1.15)
        n = max(2, int(length / 6.0))
        for i in range(n):
            x = -length / 2 + (i + 0.5) * length / n + rng.uniform(-0.6, 0.6)
            r = length / n * 0.62
            bm, hl = K.rock(r, seed + k * 10 + i, squash=h / (r * 2) * 1.25, points=18, bevel=0.25)
            tone = K.dim(color, rng.uniform(-0.08, 0.1) + 0.05 * (layers - k - 1))
            a.add((bm, hl), "CoastRock", color=tone, matrix=T(x, -k * depth * 0.18 + rng.uniform(-0.4, 0.4), z + h * 0.45) @ S(1, depth / (r * 2), 1), smooth=30, jitter=0.06, edge=0.2)
        z += h * 0.88
    # grassy lip
    for i in range(max(2, int(length / 5))):
        x = -length / 2 + (i + 0.5) * length / max(2, int(length / 5))
        a.add(K.ball(2.6, subdiv=1, squash=0.35, lump=0.25, seed=seed + 50 + i), "Foliage", color=(104, 176, 78), matrix=T(x, -layers * depth * 0.18, z + 0.2), smooth=60)
    return a


def driftwood(asset_id, seed, length=7.0):
    """A bleached log with a stub of branch."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    pts = [(-length / 2, 0, 0.5), (-length / 6, rng.uniform(-0.3, 0.3), 0.6), (length / 6, rng.uniform(-0.3, 0.3), 0.55), (length / 2, 0, 0.45)]
    a.add(K.tube(pts, [0.45, 0.55, 0.5, 0.35], n=6, twist=0.2), "Driftwood", smooth=50, jitter=0.05)
    a.add(K.tube([(length / 8, 0, 0.6), (length / 8 + 0.8, 0.9, 1.2), (length / 8 + 1.0, 1.6, 1.3)], [0.2, 0.15, 0.08], n=4), "Driftwood", smooth=50)
    return a


def flagstones(asset_id="HD_Flagstones", seed=121, size=8.0, colors=((214, 198, 166), (198, 184, 156), (226, 212, 184))):
    """An 8 x 8 patch of irregular paving stones (a 3 x 3 grid, each corner pushed about), tiled along paths."""
    a = K.Asset(asset_id, seed)
    rng = random.Random(seed)
    n = 3
    cell = size / n
    jitter = cell * 0.18
    corners = {}
    for i in range(n + 1):
        for j in range(n + 1):
            edge_i, edge_j = i in (0, n), j in (0, n)
            dx = 0 if edge_i else rng.uniform(-jitter, jitter)
            dy = 0 if edge_j else rng.uniform(-jitter, jitter)
            corners[(i, j)] = (-size / 2 + i * cell + dx, -size / 2 + j * cell + dy)
    gap = 0.16
    for i in range(n):
        for j in range(n):
            quad = [corners[(i, j)], corners[(i + 1, j)], corners[(i + 1, j + 1)], corners[(i, j + 1)]]
            cx = sum(p[0] for p in quad) / 4
            cy = sum(p[1] for p in quad) / 4
            pts = [(cx + (p[0] - cx) * (1 - gap / cell * 2), cy + (p[1] - cy) * (1 - gap / cell * 2)) for p in quad]
            a.add(K.slab(pts, 0.22 + rng.uniform(-0.03, 0.05)), "Flagstone", color=colors[rng.randrange(len(colors))], matrix=T(0, 0, -0.1), smooth=10, jitter=0.06, ao=0.4)
    return a


def dinghy(asset_id, seed, paint=(196, 66, 52), length=9.0, beam=3.6):
    """A little rowboat: a painted plank hull lofted from U-shaped frames, a bleached gunwale, two thwarts, oars."""
    a = K.Asset(asset_id, seed)
    sections = []
    n = 7
    for k in range(n):
        t = k / (n - 1)
        y = -length / 2 + t * length
        w = beam / 2 * math.sin(math.pi * (0.08 + 0.84 * t)) ** 0.7
        w = max(w, 0.08)
        d = 1.4 * (0.55 + 0.45 * math.sin(math.pi * t))
        z0 = 0.15 + 0.6 * (abs(t - 0.5) * 2) ** 3
        ring = []
        for s in range(7):
            ang = math.pi * s / 6
            ring.append(Vector((math.cos(ang) * w, y, z0 + 1.5 - math.sin(ang) * d)))
        sections.append(ring)
    # outer hull: the U sections skinned (open at the top)
    bm = K.bmesh.new()
    rows = [[bm.verts.new(p) for p in ring] for ring in sections]
    for ra, rb in zip(rows, rows[1:]):
        for s in range(6):
            bm.faces.new((ra[s], ra[s + 1], rb[s + 1], rb[s]))
    K.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    a.add((bm, set()), "PaintedWood", color=paint, smooth=50, jitter=0.04)
    # inside: a darker skin a little in
    bm2 = K.bmesh.new()
    rows2 = [[bm2.verts.new(Vector((p.x * 0.9, p.y * 0.97, p.z + 0.12))) for p in ring] for ring in sections]
    for ra, rb in zip(rows2, rows2[1:]):
        for s in range(6):
            bm2.faces.new((rb[s], rb[s + 1], ra[s + 1], ra[s]))
    a.add((bm2, set()), "Timber", color=(150, 104, 64), smooth=50, jitter=0.04)
    # gunwale
    for side in (-1, 1):
        rail = [Vector((side * (sec[0].x if side > 0 else -sec[-1].x) * 1.0, sec[0].y, sec[0].z + 0.05)) for sec in sections]
        a.add(K.tube(rail, 0.16, n=4), "Driftwood", smooth=40)
    for y in (-1.2, 1.6):
        k = (y + length / 2) / length * (n - 1)
        w = beam / 2 * math.sin(math.pi * (0.08 + 0.84 * k / (n - 1))) ** 0.7
        a.add(K.box(w * 1.9, 0.9, 0.22), "Timber", matrix=T(0, y, 1.25))
    # oars resting across
    for side in (-1, 1):
        a.add(K.tube([(side * 0.3, -2.6, 1.55), (side * 2.6, 2.4, 1.3)], 0.1, n=4), "Driftwood")
        a.add(K.box(0.15, 1.6, 0.6), "Driftwood", matrix=T(side * 2.75, 2.8, 1.28) @ R(0, 0, side * -25))
    return a


def foam_line(asset_id, points, width=2.2, seed=0):
    """The surf along a waterline: a soft white band (two strips, the outer one wider), its points in Blender space at
    the water's surface (z=0). Made per shore, not instanced."""
    a = K.Asset(asset_id, seed)
    pts = [Vector(p) for p in points]
    rng = random.Random(seed)
    inner = [p + Vector((0, 0, 0.12)) for p in pts]
    widths = [width * rng.uniform(0.6, 1.0) for _ in pts]
    a.add(K.strip(inner, widths), "Foam", color=(255, 255, 255), smooth=80, jitter=0, ao=0)
    outer = [p + Vector((0, 0, 0.06)) for p in pts]
    a.add(K.strip(outer, [w * 1.7 for w in widths]), "Foam", color=(236, 248, 252), smooth=80, jitter=0, ao=0)
    return a


def band(asset_id, inner, outer, mat="WetSand", color=None, seed=0):
    """A ribbon between two polylines of Blender points (inner and outer edge, same count): the wet sand along a
    shore, laid a hair above the terrain."""
    a = K.Asset(asset_id, seed)
    bm = K.bmesh.new()
    rows = [(bm.verts.new(Vector(p)), bm.verts.new(Vector(q))) for p, q in zip(inner, outer)]
    for (a0, b0), (a1, b1) in zip(rows, rows[1:]):
        for tri in ((a0, b0, b1), (a0, b1, a1)):
            f = bm.faces.new(tri)
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
    a.add((bm, set()), mat, color=color, smooth=80, jitter=0, ao=0)
    return a

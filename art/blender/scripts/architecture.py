"""Harbour architecture kit (V14): timber-frame walls, plank walls, tiled roofs, windows, doors, chimneys, awnings.

Storybook rules (art/README.md "Modelling standards: buildings"): nothing quite straight (posts lean a degree, ridges
sag, tiles are laid by hand), two woods per building (frame and trim), plaster and paint in one colour per house with
one accent, roofs steep and overhanging, and every opening framed so it reads from the far side of the harbour.

Wall frame: a wall's local X runs along it (0..length), Z up (0..height), and its outer face is at local Y = 0 with the
body behind it (towards -Y). Place it with a matrix whose +Y points out of the building.
"""

import math
import random

from mathutils import Vector

import lgkit as K
from lgkit import R, T

FRAME = (88, 58, 38)  # dark oak frame
TRIM = (70, 46, 30)


def wall_matrix(origin, facing_deg):
    """A wall standing at origin (its left end), its outer face looking towards facing_deg (0 = +Y)."""
    return T(*origin) @ R(0, 0, facing_deg)


def timber_wall(a, m, length, height, posts, rails, cells, plaster=(242, 228, 198), frame=FRAME, t=1.0, seed=0, bevel=0.0):
    """A half-timbered wall. posts: x of each post; rails: z of each rail (both include the ends).
    cells: {(i, j): kind} for the bay between posts i,i+1 and rails j,j+1; kinds: 'plaster' (default),
    'brace' / 'brace_r', 'cross', 'window', 'window_shutters', 'door', 'open' (left empty for the caller),
    'planks' (painted boards). Returns the list of window/door openings (centre matrix, w, h) the caller dressed."""
    rng = random.Random(seed)
    pw = 0.75  # post width
    inset = 0.18  # plaster sits back from the frame's face
    for j in range(len(rails) - 1):
        for i in range(len(posts) - 1):
            x0, x1 = posts[i] + pw / 2, posts[i + 1] - pw / 2
            z0, z1 = rails[j] + pw / 2, rails[j + 1] - pw / 2
            w, h = x1 - x0, z1 - z0
            if w <= 0.05 or h <= 0.05:
                continue
            kind = cells.get((i, j), "plaster")
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if kind == "open" or kind.startswith("window") or kind == "door":
                continue
            if kind == "planks":
                n = min(4, max(2, int(w / 1.4)))
                for k in range(n):
                    bw = w / n
                    a.add(
                        K.box(bw - 0.06, t * 0.5, h, wonk=0.02, seed=seed + i * 31 + k),
                        "PaintedWood",
                        color=plaster,
                        matrix=m @ T(x0 + bw * (k + 0.5), -inset - t * 0.25, cz),
                        jitter=0.07,
                    )
                continue
            a.add(K.box(w + 0.1, t - inset, h + 0.1), "Plaster", color=plaster, matrix=m @ T(cx, -inset - (t - inset) / 2, cz), smooth=10, jitter=0.03)
            if kind in ("brace", "brace_r", "cross"):
                ang = math.degrees(math.atan2(h, w))
                length_ = math.hypot(w, h) - 0.2
                dirs = {"brace": [ang], "brace_r": [-ang], "cross": [ang, -ang]}[kind]
                for d in dirs:
                    a.add(
                        K.box(length_, 0.32, 0.55, wonk=0.03, seed=seed + i + j * 7),
                        "DarkWood",
                        color=frame,
                        matrix=m @ T(cx, 0.0, cz) @ R(0, -d, 0),
                        jitter=0.06,
                    )
    for i, x in enumerate(posts):
        lean = rng.uniform(-1.2, 1.2)
        a.add(
            K.box(pw, 0.62, rails[-1] - rails[0] + 0.1, bevel=bevel, wonk=0.05, seed=seed + 100 + i),
            "DarkWood",
            color=frame,
            matrix=m @ T(x, 0.0, (rails[0] + rails[-1]) / 2) @ R(0, lean, 0),
            jitter=0.06,
        )
    for j, z in enumerate(rails):
        a.add(
            K.box(posts[-1] - posts[0] + 0.5, 0.62, pw * (1.25 if j in (0, len(rails) - 1) else 1.0), bevel=bevel, wonk=0.05, seed=seed + 200 + j),
            "DarkWood",
            color=frame,
            matrix=m @ T((posts[0] + posts[-1]) / 2, 0.02, z) @ R(rng.uniform(-0.6, 0.6), 0, 0),
            jitter=0.05,
        )
    openings = []
    for (i, j), kind in cells.items():
        if not (kind.startswith("window") or kind == "door"):
            continue
        x0, x1 = posts[i] + pw / 2, posts[i + 1] - pw / 2
        z0, z1 = rails[j] + pw / 2, rails[j + 1] - pw / 2
        openings.append((kind, m @ T((x0 + x1) / 2, 0, (z0 + z1) / 2), x1 - x0, z1 - z0))
    return openings


def window(a, m, w, h, shutters=None, box=None, panes=(2, 2), glass=(64, 92, 110), seed=0):
    """A window filling a w x h bay centred on m (outer face at y=0): a dark pane with a light streak, mullions,
    a deep sill, optional open shutters (a colour) and a flower box (a list of flower colours)."""
    a.add(K.box(w, 0.2, h), "Glass", color=glass, matrix=m @ T(0, -0.45, 0), smooth=5, jitter=0.02)
    a.add(K.box(w * 0.18, 0.05, h * 0.75), "Glass", color=K.dim((200, 230, 245), 0.0), matrix=m @ T(-w * 0.18, -0.33, h * 0.05) @ R(0, 18, 0), jitter=0)
    cols, rows = panes
    for k in range(1, cols):
        a.add(K.box(0.18, 0.2, h), "PaintedWood", color=(236, 230, 214), matrix=m @ T(-w / 2 + w * k / cols, -0.28, 0), jitter=0.03)
    for k in range(1, rows):
        a.add(K.box(w, 0.2, 0.18), "PaintedWood", color=(236, 230, 214), matrix=m @ T(0, -0.28, -h / 2 + h * k / rows), jitter=0.03)
    a.add(K.box(w + 0.9, 0.9, 0.35, wonk=0.03, seed=seed), "Sandstone", matrix=m @ T(0, 0.25, -h / 2 - 0.2))
    a.add(K.box(w + 0.5, 0.35, 0.4), "DarkWood", color=TRIM, matrix=m @ T(0, 0.12, h / 2 + 0.15))
    if shutters:
        for side in (-1, 1):
            sw = w / 2
            hinge = m @ T(side * (w / 2 + 0.1), 0.15, 0) @ R(0, 0, side * 20)
            for k in range(3):
                a.add(
                    K.box(sw / 3 - 0.05, 0.16, h, wonk=0.02, seed=seed + k * side),
                    "PaintedWood",
                    color=shutters,
                    matrix=hinge @ T(side * sw / 3 * (k + 0.5), 0, 0),
                    jitter=0.07,
                )
            a.add(K.box(sw, 0.2, 0.22), "PaintedWood", color=K.dim(shutters, 0.25), matrix=hinge @ T(side * sw / 2, 0.08, h * 0.25), jitter=0)
            a.add(K.box(sw, 0.2, 0.22), "PaintedWood", color=K.dim(shutters, 0.25), matrix=hinge @ T(side * sw / 2, 0.08, -h * 0.25), jitter=0)
    if box:
        rng = random.Random(seed)
        bm = m @ T(0, 0.75, -h / 2 - 0.85)
        a.add(K.box(w + 0.6, 1.0, 0.8), "PaintedWood", color=(120, 80, 52), matrix=bm, jitter=0.05)
        a.add(K.box(w + 0.3, 0.8, 0.7, wonk=0.12, seed=seed), "Foliage", color=(98, 172, 76), matrix=bm @ T(0, 0, 0.6), smooth=60)
        n = min(4, max(2, int(w / 1.4)))
        for k in range(n):
            x = -w / 2 + 0.4 + k * (w - 0.8) / max(1, n - 1)
            c = box[k % len(box)]
            a.add(K.ball(0.26, subdiv=0, seed=seed + k), "Flower", color=c, matrix=bm @ T(x + rng.uniform(-0.15, 0.15), rng.uniform(-0.2, 0.2), 1.05), smooth=20, jitter=0.03)


def door(a, m, w, h, color=(120, 70, 48), seed=0, step=True):
    """A planked door with iron strap hinges and a ring pull, its frame and a stone step."""
    n = max(3, int(w / 0.8))
    for k in range(n):
        a.add(
            K.box(w / n - 0.05, 0.25, h, wonk=0.02, seed=seed + k),
            "PaintedWood",
            color=color,
            matrix=m @ T(-w / 2 + w / n * (k + 0.5), -0.35, 0),
            jitter=0.08,
        )
    for z in (-h * 0.3, h * 0.3):
        a.add(K.box(w * 0.75, 0.1, 0.22), "Metal", matrix=m @ T(-w * 0.12, -0.2, z))
    ring = [(w * 0.3 + math.cos(t / 8 * 2 * math.pi) * 0.22, -0.12, math.sin(t / 8 * 2 * math.pi) * 0.22 - 0.2) for t in range(9)]
    a.add(K.tube(ring, 0.05, n=4), "GoldTrim", matrix=m, jitter=0)
    if step:
        a.add(K.box(w + 1.4, 1.6, 0.5, wonk=0.06, seed=seed), "Sandstone", matrix=m @ T(0, 0.75, -h / 2 - 0.25))


def tiled_roof(a, m, width, depth, pitch, overhang=1.4, gable_overhang=1.0, tile=(198, 92, 62), rows=7, sag=0.35, seed=0, mat="RoofTile", hip=False):
    """A gable roof on m (its eaves line centre at z=0, ridge along X), laid in overlapping rows of tiles cut into
    short runs, so it reads hand-laid; the ridge sags a little; dark barge boards on the gable ends.
    Returns the ridge height."""
    rng = random.Random(seed)
    half = depth / 2 + overhang
    rise = (depth / 2) * math.tan(math.radians(pitch))
    slope_len = half / math.cos(math.radians(pitch))
    total_w = width + 2 * gable_overhang
    runs = max(2, int(total_w / 7.0))
    for side in (-1, 1):
        for r in range(rows):
            t0 = r / rows
            along = slope_len * (t0 + 0.5 / rows)
            for k in range(runs):
                x = -total_w / 2 + total_w * (k + 0.5) / runs
                fx = x / (total_w / 2)
                drop = sag * (1 - fx * fx)
                y = side * (half - along * math.cos(math.radians(pitch)))
                z = -overhang * math.tan(math.radians(pitch)) + along * math.sin(math.radians(pitch)) - drop
                tone = K.dim(tile, rng.uniform(-0.06, 0.12))
                a.add(
                    K.box(total_w / runs + 0.08, slope_len / rows + 0.45, 0.42, wonk=0.04, seed=seed + r * 13 + k + side * 101),
                    mat,
                    color=tone,
                    matrix=m @ T(x, y, z + 0.2) @ R(-side * pitch + rng.uniform(-1.5, 1.5), rng.uniform(-0.8, 0.8), 0),
                    smooth=20,
                    jitter=0.05,
                )
    # ridge cap: short rounded runs
    for k in range(runs):
        x = -total_w / 2 + total_w * (k + 0.5) / runs
        fx = x / (total_w / 2)
        a.add(
            K.cyl(0.55, 0.55, total_w / runs + 0.05, n=5),
            mat,
            color=K.dim(tile, 0.12),
            matrix=m @ T(x - total_w / (runs * 2), 0, rise - sag * (1 - fx * fx) + 0.45) @ R(0, 90, 0),
            smooth=50,
            jitter=0.04,
        )
    # barge boards
    for gx in (-1, 1):
        for side in (-1, 1):
            length = slope_len + 0.6
            a.add(
                K.box(0.45, length, 0.9, wonk=0.04, seed=seed + gx * 3 + side),
                "DarkWood",
                color=TRIM,
                matrix=m @ T(gx * (total_w / 2 + 0.15), side * half / 2, rise / 2 - overhang * math.tan(math.radians(pitch)) / 2 + 0.1) @ R(-side * pitch, 0, 0),
            )
    return rise


def gable_infill(a, m, width, rise, color=(242, 228, 198), mat="Plaster", frame=FRAME, king_post=True, seed=0):
    """The triangle under a gable (m: its base centre on the outer face, facing +Y), plastered, with a king post."""
    hw = width / 2
    pts = [(-hw, 0), (hw, 0), (0, rise)]
    # slab() extrudes along Z: build it lying down then stand it up facing +Y.
    tri = K.slab([(p[0], p[1]) for p in pts], 0.8)
    a.add(tri, mat, color=color, matrix=m @ R(90, 0, 0) @ T(0, 0, 0.18), smooth=10, jitter=0.03)
    if king_post:
        a.add(K.box(0.7, 0.6, rise - 0.6, bevel=0.07), "DarkWood", color=frame, matrix=m @ T(0, 0.05, (rise - 0.6) / 2))
        for side in (-1, 1):
            ang = math.degrees(math.atan2(rise * 0.5, hw * 0.6))
            a.add(K.box(hw * 0.75, 0.55, 0.55, bevel=0.06), "DarkWood", color=frame, matrix=m @ T(side * hw * 0.32, 0.05, rise * 0.22) @ R(0, side * ang, 0))


def chimney(a, m, h=9.0, w=2.6, stone="Cobble", color=(170, 160, 150), lean=3.0, seed=0):
    """A crooked stone chimney (m: its base), courses stepping in, a slab cap and a clay pot."""
    rng = random.Random(seed)
    courses = int(h / 1.3)
    tilt = R(lean, rng.uniform(-lean, lean), 0)
    for k in range(courses):
        s = w * (1 - 0.05 * k / courses)
        a.add(
            K.box(s, s, 1.32, wonk=0.1, seed=seed + k),
            stone,
            color=color,
            matrix=m @ tilt @ T(rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.65 + k * 1.3) @ R(0, 0, rng.uniform(-3, 3)),
            jitter=0.08,
        )
    top = m @ tilt @ T(0, 0, courses * 1.3)
    a.add(K.box(w + 0.7, w + 0.7, 0.4, bevel=0.1), "Sandstone", matrix=top @ T(0, 0, 0.2))
    a.add(K.cyl(0.55, 0.42, 1.2, n=8, bevel=0.06), "RoofTile", color=(176, 84, 56), matrix=top @ T(0, 0, 0.4), smooth=40)
    return top @ T(0, 0, 1.6)


def awning(a, m, width, depth, drop, colors, scallops=True, seed=0):
    """A striped canvas awning (m: its back edge centre on the wall, sloping out along +Y and down by drop), on two
    iron brackets, with a scalloped valance."""
    n = max(4, int(width / 2.2))
    slope = math.degrees(math.atan2(drop, depth))
    length = math.hypot(depth, drop)
    for k in range(n):
        x = -width / 2 + width * (k + 0.5) / n
        c = colors[k % len(colors)]
        a.add(
            K.box(width / n + 0.02, length, 0.16),
            "Canvas",
            color=c,
            matrix=m @ T(x, depth / 2, -drop / 2) @ R(-slope, 0, 0),
            smooth=10,
            jitter=0.04,
        )
        if scallops:
            tri = K.slab([(-width / n / 2, 0), (width / n / 2, 0), (0, -0.9)], 0.12)
            a.add(tri, "Canvas", color=c, matrix=m @ T(x, depth + 0.02, -drop) @ R(90, 0, 0), smooth=10, jitter=0.04)
    for side in (-1, 1):
        arm = [(side * (width / 2 - 0.3), 0, -drop - 1.6), (side * (width / 2 - 0.3), depth * 0.5, -drop * 0.8), (side * (width / 2 - 0.3), depth, -drop)]
        a.add(K.tube(arm, 0.09, n=4), "Metal", matrix=m)


def hanging_sign(a, m, w=4.0, h=2.6, board=(70, 46, 30), border=(255, 196, 46), emblem=None, seed=0):
    """An iron bracket out from a wall (m: the wall point, +Y out) with a board hanging under it. Returns the matrix
    of the board's front face centre (for painted text) in asset space."""
    a.add(K.box(0.3, w + 1.6, 0.3), "Metal", matrix=m @ T(0, (w + 1.6) / 2, 0))
    a.add(K.tube([(0, 0.2, -1.4), (0, 1.2, -0.5), (0, 2.2, -0.1)], 0.08, n=4), "Metal", matrix=m)
    a.add(K.cyl(0.18, 0.0, 0.5, n=6), "GoldTrim", matrix=m @ T(0, w + 1.6, -0.1) @ R(-90, 0, 0), jitter=0)
    hang = m @ T(0, w / 2 + 1.0, 0)
    for side in (-1, 1):
        a.add(K.tube([(0, side * (w / 2 - 0.4), 0), (0, side * (w / 2 - 0.4), -0.7)], 0.05, n=3), "Metal", matrix=hang)
    board_m = hang @ T(0, 0, -0.7 - h / 2)
    a.add(K.box(0.35, w, h, bevel=0.12, wonk=0.05, seed=seed), "PaintedWood", color=board, matrix=board_m)
    for z in (-1, 1):
        a.add(K.box(0.42, w + 0.1, 0.18), "GoldTrim", color=border, matrix=board_m @ T(0, 0, z * (h / 2 - 0.05)), jitter=0)
    for y in (-1, 1):
        a.add(K.box(0.42, 0.18, h), "GoldTrim", color=border, matrix=board_m @ T(0, y * (w / 2 - 0.05), 0), jitter=0)
    if emblem:
        emblem(a, board_m)
    return board_m


def plank_wall(a, m, length, height, color, t=0.7, batten=True, seed=0, mat="PaintedWood"):
    """Board-and-batten: vertical boards of slightly different widths and tones, battens over the joints."""
    rng = random.Random(seed)
    x = 0.0
    k = 0
    while x < length - 0.05:
        bw = min(length - x, rng.uniform(1.0, 1.5))
        a.add(
            K.box(bw - 0.04, t, height + rng.uniform(-0.08, 0.08), wonk=0.03, seed=seed + k),
            mat,
            color=color,
            matrix=m @ T(x + bw / 2, -t / 2, height / 2),
            jitter=0.08,
        )
        if batten and x > 0:
            a.add(K.box(0.28, 0.2, height), mat, color=K.dim(color, 0.18), matrix=m @ T(x, 0.08, height / 2), jitter=0.05)
        x += bw
        k += 1


def stone_footing(a, m, length, height=1.2, color=(196, 170, 128), seed=0):
    """A course of dressed stones along a wall's foot (m: left end on the outer face)."""
    rng = random.Random(seed)
    x = 0.0
    k = 0
    while x < length - 0.05:
        sw = min(length - x, rng.uniform(2.6, 4.0))
        a.add(
            K.box(sw - 0.08, 1.3, height, wonk=0.08, seed=seed + k),
            "Sandstone",
            color=color,
            matrix=m @ T(x + sw / 2, -0.45, height / 2),
            jitter=0.09,
        )
        x += sw
        k += 1


def lantern_on_wall(a, m, light=True):
    """A wall lantern on a short bracket (m: wall point, +Y out)."""
    from props import lantern_head

    a.add(K.box(0.3, 1.4, 0.3), "Metal", matrix=m @ T(0, 0.7, 0))
    a.add(K.box(0.6, 0.15, 0.9), "Metal", matrix=m @ T(0, 0.05, -0.2))
    lantern_head(a, m @ T(0, 1.35, 0) @ K.S(0.8))
    if light:
        a.light((m @ T(0, 1.35, -1.7)).translation, color=(255, 196, 120), range_=16, brightness=0.9)


def flagpole(a, m, h=12.0, flag=(214, 58, 48), stripe=(255, 196, 46), seed=0):
    a.add(K.cyl(0.25, 0.16, h, n=6, bevel=0.03), "DarkWood", matrix=m, smooth=40)
    a.add(K.ball(0.35, subdiv=1, seed=seed), "GoldTrim", matrix=m @ T(0, 0, h + 0.2), jitter=0)
    pts = [Vector((0, 0.2 + k * 1.1, h - 0.6 - math.sin(k * 0.8) * 0.25)) for k in range(6)]
    a.add(K.strip(pts, [2.4, 2.2, 2.0, 1.7, 1.3, 0.8], normal=Vector((1, 0, 0)), fold=0.0), "Canvas", color=flag, matrix=m, smooth=50, jitter=0.03)
    a.add(K.strip(pts, [2.4, 2.2, 2.0, 1.7, 1.3, 0.8], normal=Vector((-1, 0, 0)), fold=0.0), "Canvas", color=flag, matrix=m, smooth=50, jitter=0.03)
    pts2 = [p + Vector((0.02, 0, -0.1)) for p in pts]
    a.add(K.strip(pts2, [0.5, 0.45, 0.4, 0.35, 0.3, 0.2], normal=Vector((1, 0, 0))), "Canvas", color=stripe, matrix=m @ T(0.03, 0, 0), smooth=50, jitter=0)
    a.add(K.strip(pts2, [0.5, 0.45, 0.4, 0.35, 0.3, 0.2], normal=Vector((-1, 0, 0))), "Canvas", color=stripe, matrix=m @ T(-0.03, 0, 0), smooth=50, jitter=0)


def door_in_bay(a, m, bay_w, bay_h, door_w=3.6, door_h=5.2, plaster=(242, 228, 198), color=(120, 70, 48), seed=0):
    """A door at the foot of a timber bay (m: the bay's centre on the outer face), plaster round it."""
    door_h = min(door_h, bay_h - 0.2)
    door_w = min(door_w, bay_w - 0.4)
    inset = 0.18
    side_w = (bay_w - door_w) / 2
    for side in (-1, 1):
        if side_w > 0.05:
            a.add(K.box(side_w + 0.05, 0.8, bay_h + 0.1), "Plaster", color=plaster, matrix=m @ T(side * (door_w + side_w) / 2, -inset - 0.4, 0), smooth=10, jitter=0.03)
    top_h = bay_h - door_h
    if top_h > 0.05:
        a.add(K.box(door_w + 0.1, 0.8, top_h + 0.05), "Plaster", color=plaster, matrix=m @ T(0, -inset - 0.4, bay_h / 2 - top_h / 2), smooth=10, jitter=0.03)
    dm = m @ T(0, 0, -bay_h / 2 + door_h / 2)
    a.add(K.box(door_w + 0.7, 0.5, 0.5), "DarkWood", color=TRIM, matrix=dm @ T(0, 0.05, door_h / 2 + 0.2))
    for side in (-1, 1):
        a.add(K.box(0.4, 0.5, door_h), "DarkWood", color=TRIM, matrix=dm @ T(side * (door_w / 2 + 0.15), 0.05, 0))
    door(a, dm, door_w, door_h, color=color, seed=seed)
    return dm

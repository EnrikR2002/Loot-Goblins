"""The Harbour District's waterfront (V14): three new houses on the Port's east shore, the boardwalk in front of them
and the Regatta dock's new planking. Origins at ground level in the middle of each footprint; fronts towards +Y.

The houses are new (V13 had open lawn there), so each carries COL_ proxies: on a client that shows V14, its goblin
cannot walk through them. The dock module only dresses V13's Regatta dock, whose collision stays as it is.
"""

import math

import architecture as A
import lgkit as K
from lgkit import R, S, T


def _barnacle_emblem(a, board_m):
    """The tavern's sign: a gold tankard over its painted name, on both faces."""
    for face in (-1, 1):
        m = board_m @ T(face * 0.22, 0, 1.0) @ S(0.75)
        a.add(K.box(0.12, 0.9, 1.1), "GoldTrim", matrix=m @ T(0, -0.15, -0.1), jitter=0)
        a.add(K.box(0.12, 1.1, 0.25), "GoldTrim", color=(250, 246, 230), matrix=m @ T(0, -0.15, 0.55), jitter=0)
        handle = [(0, 0.3, 0.3), (0, 0.75, 0.25), (0, 0.8, -0.3), (0, 0.3, -0.45)]
        a.add(K.tube(handle, 0.08, n=4), "GoldTrim", matrix=m, jitter=0)


def _walls(a, W, D, lean=None):
    lean = lean or R()
    hw, hd = W / 2, D / 2
    return (
        lean @ T(-hw, hd, 0),
        lean @ T(-hw, -hd, 0) @ R(0, 0, 90),
        lean @ T(hw, hd, 0) @ R(0, 0, -90),
        lean @ T(hw, -hd, 0) @ R(0, 0, 180),
    )


def tavern():
    """The Salty Barnacle: a broad two-storey harbour inn, ochre plaster, a dark slate roof, green shutters, a bay
    window and a door to the boardwalk, a fat stone chimney and a red pennant (its long-range silhouette)."""
    a = K.Asset("HD_Tavern", seed=51)
    W, D, H = 24.0, 18.0, 15.0
    hw, hd = W / 2, D / 2
    ochre = (232, 190, 118)
    green = (66, 128, 88)
    front, west, east, back = _walls(a, W, D)
    for m, length, seed in ((front, W, 1), (west, D, 2), (east, D, 3), (back, W, 4)):
        A.stone_footing(a, m, length, 1.0, color=(178, 160, 132), seed=seed)
    rails = [1.0, 7.5, 15.0]
    cells = {(0, 0): "open", (1, 0): "open", (2, 0): "door", (3, 0): "window_shutters"}
    cells.update({(0, 1): "window", (1, 1): "brace", (2, 1): "window", (3, 1): "window"})
    ops = A.timber_wall(a, front, W, H, [0, 6, 12, 18, 24], rails, cells, plaster=ochre, seed=61, bevel=0.08)
    ops += A.timber_wall(a, west, D, H, [0, 9, 18], rails, {(0, 0): "window_shutters", (1, 0): "brace", (0, 1): "cross", (1, 1): "window"}, plaster=ochre, seed=62)
    ops += A.timber_wall(a, east, D, H, [0, 9, 18], rails, {(0, 0): "brace_r", (1, 0): "window_shutters", (0, 1): "window", (1, 1): "cross"}, plaster=ochre, seed=63)
    ops += A.timber_wall(a, back, W, H, [0, 8, 16, 24], rails, {(0, 0): "brace", (1, 0): "window", (2, 0): "brace_r", (0, 1): "window", (1, 1): "cross", (2, 1): "window"}, plaster=ochre, seed=64)
    for kind, m, w, h in ops:
        if kind == "door":
            dm = A.door_in_bay(a, m, w, h, door_w=3.8, door_h=5.6, plaster=ochre, color=(120, 60, 40), seed=8)
            A.lantern_on_wall(a, dm @ T(-2.9, 0, 1.6))
        else:
            box = [(232, 78, 96), (255, 210, 80)] if kind == "window" and m.translation.y > hd - 0.5 else None
            A.window(a, m, w - 0.2, h - 0.3, shutters=green if kind == "window_shutters" else None, box=box, seed=int(m.translation.x * 7 + m.translation.y))
    # The bay window across the first two bays: a projecting box of small panes on a stone sill, a slate roof.
    bay = T(-hw + 6.0, hd, 1.0)
    a.add(K.box(11.6, 2.6, 1.6, wonk=0.05, seed=5), "Sandstone", color=(196, 176, 140), matrix=bay @ T(0, 1.1, 0.8))
    a.add(K.box(11.0, 0.2, 4.6), "Glass", matrix=bay @ T(0, 2.25, 4.0), jitter=0)
    for x in (-5.4, -2.7, 0, 2.7, 5.4):
        a.add(K.box(0.35, 0.5, 4.8), "PaintedWood", color=(240, 232, 214), matrix=bay @ T(x, 2.3, 4.0), jitter=0.03)
    for z in (2.0, 4.0, 6.2):
        a.add(K.box(11.4, 0.45, 0.25), "PaintedWood", color=(240, 232, 214), matrix=bay @ T(0, 2.3, z), jitter=0.03)
    for side in (-1, 1):
        a.add(K.box(0.2, 2.4, 4.6), "Glass", matrix=bay @ T(side * 5.6, 1.1, 4.0), jitter=0)
    a.add(K.box(12.4, 3.2, 0.5, wonk=0.04, seed=6), "Slate", color=(70, 80, 98), matrix=bay @ T(0, 1.3, 6.6) @ R(-12, 0, 0))
    a.add(K.box(12.0, 0.2, 2.2), "Plaster", color=ochre, matrix=bay @ T(0, -0.1, 4.0), ao=0.2)
    # Roof: dark slate, ridge along the front, a fat chimney on the north gable, a pennant on the south.
    rise = A.tiled_roof(a, T(0, 0, H + 0.6), W, D, 38, overhang=1.6, gable_overhang=1.2, tile=(80, 90, 110), rows=6, sag=0.4, seed=7, mat="Slate")
    for gx, face in ((-hw, 90), (hw, -90)):
        A.gable_infill(a, T(gx, 0, H + 0.65) @ R(0, 0, face), D, rise - 0.3, color=ochre, seed=int(gx))
        A.window(a, T(gx, 0, H + 0.65) @ R(0, 0, face) @ T(0, 0.5, rise * 0.35), 2.4, 2.4, shutters=green, seed=3)
    A.chimney(a, T(-hw + 1.6, -2.0, 0), h=H + rise + 3.0, w=3.6, stone="Cobble", color=(150, 140, 132), lean=1.5, seed=13)
    A.flagpole(a, T(hw - 0.8, 0, H + 0.6 + rise + 0.3), h=8.0, flag=(214, 58, 48), stripe=(255, 196, 46), seed=14)
    # Dormers in the front slope.
    for x in (-5.0, 5.0):
        dm = T(x, hd - 2.2, H + 0.6)
        a.add(K.box(3.4, 4.0, 4.6), "Plaster", color=ochre, matrix=dm @ T(0, -0.5, 2.3), ao=0.3)
        A.window(a, dm @ T(0, 2.0, 2.6), 2.4, 2.2, panes=(2, 1), seed=int(x))
        a.add(K.prism(3.6, 4.6, 1.7), "Slate", color=(76, 86, 106), matrix=dm @ T(0, -0.4, 4.6) @ R(0, 0, 90) @ S(1, 1.15, 1))
    # The sign beside the door, hung out over the boardwalk (the name is painted on in game: a TEXT board).
    board = A.hanging_sign(a, T(hw - 0.6, hd, 10.0), w=4.8, h=3.6, board=(40, 70, 64), emblem=_barnacle_emblem, seed=15)
    for face in (-1, 1):
        name = (board @ T(face * 0.24, 0, -0.6) @ R(0, 0, -90 * face), (4.3, 1.8), "THE SALTY\nBARNACLE", (255, 214, 120), "y")
        a.texts.append(name)
    a.solid((W + 0.8, D + 0.8, H), T(0, 0, H / 2))
    a.solid((12.4, 3.0, 7.0), T(-hw + 6.0, hd + 1.4, 3.5))
    a.light((hw - 4.0, hd + 2.0, 5.0), color=(255, 200, 130), range_=18, brightness=0.9)
    return a


def net_loft():
    """The Net Loft: a tall, leaning fisherman's store in sea-blue boards, its gable to the sea, a hoist beam over the
    loft door, nets hung to dry on its side."""
    a = K.Asset("HD_NetLoft", seed=71)
    W, D, H = 12.0, 12.0, 20.0
    hw, hd = W / 2, D / 2
    blue = (70, 128, 168)
    lean = R(0, 1.2, 0)
    front, west, east, back = _walls(a, W, D, lean)
    for m, length, seed in ((front, W, 1), (west, D, 2), (east, D, 3), (back, W, 4)):
        A.stone_footing(a, m, length, 1.4, color=(170, 160, 150), seed=seed)
        A.plank_wall(a, m @ T(0, 0, 1.3), length, H - 1.3, blue, seed=seed * 7)
    for x in (-hw, hw):
        for y in (-hd, hd):
            a.add(K.box(0.9, 0.9, H, bevel=0.1, wonk=0.05, seed=int(x + y * 3)), "DarkWood", color=A.FRAME, matrix=lean @ T(x, y, H / 2))
    fd = lean @ T(0, hd + 0.05, 0)
    A.door(a, fd @ T(-2.0, 0.3, 3.2), 3.4, 5.0, color=(196, 96, 60), seed=4)
    a.add(K.box(4.4, 0.5, 0.5), "DarkWood", color=A.TRIM, matrix=fd @ T(-2.0, 0.35, 5.9))
    A.window(a, fd @ T(2.6, 0.75, 4.2), 2.6, 3.0, shutters=(240, 236, 220), seed=5)
    A.window(a, fd @ T(0, 0.75, 10.2), 3.0, 3.2, shutters=(240, 236, 220), box=[(255, 210, 80), (232, 78, 96)], seed=6)
    loft = fd @ T(0, 0.3, 16.0)
    for k in range(3):
        a.add(K.box(4.0 / 3 - 0.05, 0.3, 4.0, wonk=0.03, seed=k), "PaintedWood", color=(196, 96, 60), matrix=loft @ T(-4.0 / 3 + k * 4.0 / 3, 0, 0), jitter=0.07)
    a.add(K.box(4.8, 0.6, 0.5), "DarkWood", color=A.TRIM, matrix=loft @ T(0, 0.1, 2.25))
    A.window(a, west @ T(D / 2, 0.75, 9.0), 2.4, 3.0, shutters=(240, 236, 220), seed=7)
    A.window(a, east @ T(D / 2, 0.75, 9.0), 2.4, 3.0, shutters=(240, 236, 220), seed=8)
    # Roof: steep red-brown tiles, gable to the sea.
    rise = A.tiled_roof(a, lean @ T(0, 0, H + 0.4) @ R(0, 0, 90), D, W, 50, overhang=1.2, gable_overhang=1.6, tile=(170, 82, 60), rows=5, sag=0.3, seed=9)
    A.gable_infill(a, lean @ T(0, hd, H + 0.45), W, rise - 0.3, color=blue, mat="PaintedWood", seed=10)
    A.gable_infill(a, lean @ T(0, -hd, H + 0.45) @ R(0, 0, 180), W, rise - 0.3, color=blue, mat="PaintedWood", seed=11)
    # The hoist: a beam out of the gable over the loft door, a block, a rope and a bundle of nets hanging on it.
    hb = lean @ T(0, hd, H + rise * 0.55)
    a.add(K.box(0.8, 5.2, 0.8, bevel=0.1, wonk=0.04, seed=12), "DarkWood", color=A.FRAME, matrix=hb @ T(0, 2.4, 0))
    a.add(K.tube([(0, 1.2, -1.6), (0, 2.6, -0.4)], 0.18, n=4), "DarkWood", color=A.FRAME, matrix=hb)
    a.add(K.cyl(0.45, 0.45, 0.5, n=6), "Metal", matrix=hb @ T(-0.25, 4.6, -0.7) @ R(0, 90, 0), smooth=40)
    a.add(K.tube([(0, 4.6, -0.7), (0, 4.6, -6.5)], 0.08, n=4), "Rope", matrix=hb)
    a.add(K.ball(1.2, subdiv=1, squash=1.2, lump=0.25, seed=13), "Rope", color=(150, 170, 140), matrix=hb @ T(0, 4.6, -7.6), smooth=50)
    a.add(K.ball(0.3, subdiv=0, seed=14), "Canvas", color=(240, 130, 60), matrix=hb @ T(0.8, 4.4, -7.4), smooth=40)
    # Nets drying on the south side: two frames with a sagging mesh and orange floats.
    side = west @ T(D / 2, 0.6, 0)
    for k, x in enumerate((-3.2, 3.2)):
        fm = side @ T(x, 1.0, 0)
        for px in (-2.2, 2.2):
            a.add(K.box(0.3, 0.3, 7.0), "Driftwood", matrix=fm @ T(px, 0, 3.5))
        a.add(K.box(4.8, 0.3, 0.3), "Driftwood", matrix=fm @ T(0, 0, 6.8))
        for r in range(6):
            z = 6.6 - r * 0.9
            pts = [(-2.0 + j * 0.8, 0.05 + 0.25 * math.sin(j * 0.9 + r), z - 0.25 * math.sin(math.pi * j / 5)) for j in range(6)]
            a.add(K.tube(pts, 0.05, n=3), "Rope", color=(120, 150, 130), matrix=fm, smooth=60)
        for j in range(6):
            x0 = -2.0 + j * 0.8
            a.add(K.tube([(x0, 0.05, 6.6), (x0, 0.12, 2.0)], 0.05, n=3), "Rope", color=(120, 150, 130), matrix=fm)
        for j in range(3):
            a.add(K.ball(0.28, subdiv=0, seed=j + k * 3), "Canvas", color=(240, 130, 60), matrix=fm @ T(-1.6 + j * 1.6, 0.2, 6.3 - (j % 2) * 1.8))
    a.solid((W + 1.0, D + 1.0, H), T(0, 0, H / 2))
    return a


def chandlery():
    """The Chandlery: a low whitewashed boat shed with teal timbers, big doors to the beach, a terracotta roof and a
    little cupola with a gold fish weather vane (its long-range silhouette)."""
    a = K.Asset("HD_Chandlery", seed=81)
    W, D, H = 20.0, 14.0, 12.0
    hw, hd = W / 2, D / 2
    white = (246, 244, 236)
    teal = (52, 132, 128)
    front, west, east, back = _walls(a, W, D)
    for m, length, seed in ((front, W, 1), (west, D, 2), (east, D, 3), (back, W, 4)):
        A.stone_footing(a, m, length, 1.0, color=(190, 176, 150), seed=seed)
    rails = [1.0, H]
    ops = A.timber_wall(a, front, W, H, [0, 4.5, 15.5, 20], rails, {(0, 0): "window_shutters", (1, 0): "open", (2, 0): "window_shutters"}, plaster=white, frame=teal, seed=91, bevel=0.08)
    ops += A.timber_wall(a, west, D, H, [0, 7, 14], rails, {(0, 0): "brace", (1, 0): "window"}, plaster=white, frame=teal, seed=92)
    ops += A.timber_wall(a, east, D, H, [0, 7, 14], rails, {(0, 0): "window", (1, 0): "brace_r"}, plaster=white, frame=teal, seed=93)
    ops += A.timber_wall(a, back, W, H, [0, 10, 20], rails, {(0, 0): "brace", (1, 0): "brace_r"}, plaster=white, frame=teal, seed=94)
    for kind, m, w, h in ops:
        A.window(a, m, w - 0.2, h - 0.3, shutters=(232, 120, 60) if kind == "window_shutters" else None, seed=int(m.translation.x * 5 + m.translation.y))
    # big double doors, one swung open, with iron straps
    dm = T(0, hd, 1.0)
    for side in (-1, 1):
        hinge = dm @ T(side * 5.3, 0, 0) @ R(0, 0, -28 if side > 0 else 0)
        for k in range(4):
            a.add(K.box(1.3, 0.35, 7.6, wonk=0.03, seed=k + side * 5), "PaintedWood", color=teal, matrix=hinge @ T(-side * (0.65 + k * 1.32), 0.2, 3.8), jitter=0.07)
        for z in (1.5, 6.0):
            a.add(K.box(4.8, 0.15, 0.3), "Metal", matrix=hinge @ T(-side * 2.6, 0.45, z))
    a.add(K.box(11.6, 0.8, 3.4), "Plaster", color=white, matrix=dm @ T(0, -0.4, 9.3), ao=0.3)
    # inside, glimpsed through the doors: a back wall, oars, a coil of rope
    a.add(K.box(10.6, 0.4, 8.6), "Plaster", color=(200, 196, 186), matrix=T(0, -hd + 0.8, 5.3), ao=0.2)
    for x in (-3.5, -1.5, 0.5):
        a.add(K.box(0.3, 0.3, 6.0), "Timber", matrix=T(x, -hd + 1.3, 4.8) @ R(0, 8, 0))
    a.add(K.cyl(1.0, 1.0, 1.2, n=8), "Rope", matrix=T(3.4, -hd + 2.6, 1.0), smooth=50)
    a.add(K.box(W - 2, D - 2, 0.3), "Timber", matrix=T(0, 0, 1.0), smooth=10, ao=0.4)
    # Roof: terracotta, ridge along the front, a cupola on the ridge with a fish weather vane.
    rise = A.tiled_roof(a, T(0, 0, H + 0.6), W, D, 32, overhang=1.4, gable_overhang=1.0, tile=(206, 108, 66), rows=5, sag=0.35, seed=95)
    for gx, face in ((-hw, 90), (hw, -90)):
        A.gable_infill(a, T(gx, 0, H + 0.65) @ R(0, 0, face), D, rise - 0.3, color=white, frame=teal, seed=int(gx))
    cu = T(0, 0, H + 0.6 + rise - 0.2)
    a.add(K.box(3.0, 3.0, 2.8, bevel=0.1), "Plaster", color=white, matrix=cu @ T(0, 0, 1.4), ao=0.3)
    for x in (-1, 1):
        for y in (-1, 1):
            a.add(K.box(0.4, 0.4, 2.9), "PaintedWood", color=teal, matrix=cu @ T(x * 1.4, y * 1.4, 1.45))
    for face in range(4):
        a.add(K.box(1.6, 0.15, 1.6), "Glass", matrix=cu @ R(0, 0, face * 90) @ T(0, 1.52, 1.6), jitter=0)
    a.add(K.cyl(2.4, 0.0, 2.2, n=4), "RoofTile", color=(206, 108, 66), matrix=cu @ T(0, 0, 2.8) @ R(0, 0, 45), smooth=10)
    a.add(K.cyl(0.08, 0.08, 2.4, n=4), "Metal", matrix=cu @ T(0, 0, 4.8))
    fish = cu @ T(0, 0, 6.6)
    a.add(K.ball(0.55, subdiv=1, squash=0.55, seed=3), "GoldTrim", matrix=fish @ S(2.2, 0.35, 1.0), smooth=60, jitter=0)
    a.add(K.slab([(0, 0), (0.9, 0.6), (0.9, -0.6)], 0.15), "GoldTrim", matrix=fish @ T(1.1, 0.07, 0) @ R(90, 0, 0), jitter=0)
    # a painted sign board over the doors (its name is a TEXT board)
    sign = dm @ T(0, 0.3, 8.8)
    a.add(K.box(9.0, 0.4, 1.8, bevel=0.15, wonk=0.04, seed=96), "PaintedWood", color=(40, 70, 70), matrix=sign)
    for z in (-1, 1):
        a.add(K.box(9.2, 0.5, 0.18), "GoldTrim", matrix=sign @ T(0, 0.03, z * 0.85), jitter=0)
    a.texts.append((sign @ T(0, 0.22, 0), (8.6, 1.5), "CHANDLERY", (255, 214, 120), "y"))
    A.lantern_on_wall(a, T(-6.2, hd + 0.1, 7.2))
    A.lantern_on_wall(a, T(6.2, hd + 0.1, 7.2))
    a.solid((W + 0.8, D + 0.8, H), T(0, 0, H / 2))
    return a


def boardwalk(length=12.0, width=10.0, drop=4.4):
    """One module of the timber boardwalk along the plateau's edge: planks across the walk, a dark kerb on the sea
    side, piles down to the beach (drop: how far below the deck the sand is) with cross braces, a rope rail on posts.
    The deck's top is at z=0, its land edge at y=-width/2, sea edge at y=+width/2; modules join along X."""
    a = K.Asset("HD_Boardwalk", seed=101)
    n = int(length / 1.0)
    for k in range(n):
        x = -length / 2 + (k + 0.5) * length / n
        a.add(K.box(length / n - 0.08, width, 0.4, wonk=0.03, seed=k), "Driftwood" if k % 5 == 3 else "Timber", matrix=T(x, 0, -0.2) @ R(0, 0, a.rng.uniform(-0.6, 0.6)), smooth=10, jitter=0.1)
    for y in (-width / 2 + 0.5, 0, width / 2 - 0.5):
        a.add(K.box(length, 0.6, 0.6), "DarkWood", matrix=T(0, y, -0.7))
    a.add(K.box(length, 0.7, 0.7, bevel=0.1, wonk=0.04, seed=3), "DarkWood", matrix=T(0, width / 2 + 0.05, 0.15))
    for x in (-length / 2 + 0.6, length / 2 - 0.6):
        a.add(K.cyl(0.55, 0.5, drop + 1.2, n=6, wonk=0.04, seed=int(x)), "Driftwood", matrix=T(x, width / 2 - 0.2, -drop - 1.0), smooth=40)
        a.add(K.cyl(0.5, 0.45, drop + 0.5, n=6, wonk=0.04, seed=int(x) + 5), "Driftwood", matrix=T(x, -width / 2 + 1.0, -drop - 0.5), smooth=40)
    diag = math.hypot(length - 1.2, drop - 0.6)
    a.add(K.box(diag, 0.3, 0.45), "Driftwood", matrix=T(0, width / 2 - 0.15, -drop / 2 - 0.4) @ R(0, math.degrees(math.atan2(drop - 0.6, length - 1.2)), 0))
    # the rail: posts at the module's ends, a sagging rope between
    for x in (-length / 2 + 0.6, length / 2 - 0.6):
        a.add(K.box(0.45, 0.45, 3.0, bevel=0.06), "DarkWood", matrix=T(x, width / 2 + 0.05, 1.6))
        a.add(K.cyl(0.32, 0.0, 0.4, n=4), "DarkWood", matrix=T(x, width / 2 + 0.05, 3.1))
    rope = [(x, width / 2 + 0.05, 2.7 - 0.45 * math.sin(math.pi * (x + length / 2 - 0.6) / (length - 1.2))) for x in [(-length / 2 + 0.6) + i * (length - 1.2) / 6 for i in range(7)]]
    a.add(K.tube(rope, 0.09, n=4), "Rope", smooth=60)
    return a


def dock_module(length=12.0, width=14.0):
    """The Regatta dock's planking, laid over V13's dock (whose deck, at the same height, stays as the collision):
    planks across, edge beams, chunky piles at the corners rising into bollards, a lantern on alternate modules."""
    a = K.Asset("HD_DockModule", seed=111)
    n = int(length / 1.0)
    for k in range(n):
        x = -length / 2 + (k + 0.5) * length / n
        a.add(K.box(length / n - 0.08, width, 0.42, wonk=0.03, seed=k), "Driftwood" if k % 4 == 1 else "Timber", matrix=T(x, 0, -0.21) @ R(0, 0, a.rng.uniform(-0.6, 0.6)), smooth=10, jitter=0.1)
    for y in (-width / 2 - 0.1, width / 2 + 0.1):
        a.add(K.box(length, 0.7, 0.9, bevel=0.1, wonk=0.04, seed=int(y)), "DarkWood", matrix=T(0, y, -0.25))
    for y in (-width / 2 + 0.3, width / 2 - 0.3):
        a.add(K.cyl(0.85, 0.8, 9.0, n=7, wonk=0.05, seed=int(y) + 3), "Driftwood", matrix=T(-length / 2 + 0.9, y, -7.8), smooth=40)
        a.add(K.cyl(0.95, 0.85, 0.5, n=7), "DarkWood", matrix=T(-length / 2 + 0.9, y, 1.2), smooth=30)
        pts = [(-length / 2 + 0.9 + math.cos(t * 0.7) * 0.9, y + math.sin(t * 0.7) * 0.9, 0.6 + t * 0.02) for t in range(10)]
        a.add(K.tube(pts, 0.12, n=4), "Rope", smooth=60)
    return a

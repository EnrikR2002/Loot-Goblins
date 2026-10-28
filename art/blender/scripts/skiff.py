"""The Hero Skiff (V14 Showcase B): a new look for the Skiff, the boat most goblins sail.

It is drawn over V10's skiff and replaces only its look: the hull part BoatSim drives (9 x 3 x 20 studs), the seats,
the bow gun, the flag, the paint job's extras and every collision stay V10's. So it is built in the hull's own frame
(origin at the hull part's centre, Blender +Y = the bow = Roblox -Z) and keeps V10's landmarks where other things
attach: the deck at z = 1.5 (where feet and the bow gun stand), the seats at y = -6 and -2, the mast at y = +2 rising
to 13.5 (the flag flies from there), the stem reaching y = +14.6 (where figureheads lean out).

Paint: the hull, its wale stripe, rails and transom, the mast, the sail and the sail's band are white times shading and
carry a tint role (BoatPaint, BoatStripe, BoatTrim, BoatMast, Sailcloth, SailStripe): the game colours them from the
goblin's paint job (shared/BoatLook.lua), so every livery dresses the Hero Skiff.
"""

import math

from mathutils import Vector

import lgkit as K
from lgkit import R, T

L_STERN, L_BOW = -10.4, 14.6


def _half_section(t):
    """The hull's half cross-section at t (0 = transom, 1 = stem): (half beam at the sheer, sheer height, keel depth,
    y). The sheer sweeps up to the bow; the beam peaks a little aft of the middle."""
    y = L_STERN + t * (L_BOW - L_STERN)
    beam = 4.75 * (math.sin(math.pi * min(1.0, 0.18 + 0.86 * t)) ** 0.62)
    if t > 0.9:
        beam *= max(0.06, (1 - t) / 0.1)
    sheer = 2.25 + 1.5 * t**3 + 0.35 * (1 - t) ** 4
    keel = -1.55 + 1.3 * max(0.0, t - 0.75) ** 1.5 + 0.25 * max(0.0, 0.08 - t) * 10
    return beam, sheer, keel, y


def _side_point(t, f, side, inset=0.0, lift=0.0):
    """A point on the hull's skin at t, a share f (0 = sheer, 1 = keel) of the way down, on side +1 / -1."""
    beam, sheer, keel, y = _half_section(t)
    beam = max(0.05, beam - inset)
    down = min(1.0, f ** (4.0 / 3.0))  # z falls evenly with f (the bilge's curve is in the sideways position)
    s = math.sqrt(max(0.0, 1.0 - down * down))
    # a soft round bilge: sides flare, the bottom flattens a little
    x = side * s * beam * (1.0 - 0.18 * down**4)
    z = sheer + lift - (sheer - keel) * f
    return Vector((x, y, z))


def _ring(t, inset=0.0, lift=0.0, bands=4):
    """Points round the hull's skin at t from the starboard sheer down to the keel and up to the port sheer, spaced so
    each plank band takes an even share of the depth."""
    starboard = [_side_point(t, k / bands, 1, inset, lift) for k in range(bands + 1)]
    port = [_side_point(t, k / bands, -1, inset, lift) for k in range(bands - 1, -1, -1)]
    return starboard + port


def hero_skiff():
    a = K.Asset("SK_HeroSkiff", seed=301)
    stations = [i / 10 for i in range(11)]
    # Clinker planking: the skin in bands (strakes), each a slightly different shade, so the planks read.
    rings = [_ring(t) for t in stations]
    nseg = len(rings[0]) - 1
    for k in range(nseg):
        bm = K.bmesh.new()
        rows = [(bm.verts.new(r[k]), bm.verts.new(r[k + 1])) for r in rings]
        for (a0, a1), (b0, b1) in zip(rows, rows[1:]):
            bm.faces.new((a0, b0, b1, a1))
        K.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            c = f.calc_center_median()
            if f.normal.dot(Vector((c.x, 0, c.z + 0.6))) < 0:
                f.normal_flip()
        tone = (255, 255, 255) if k % 2 == 0 else (228, 228, 228)
        a.add((bm, set()), "BoatPaint", color=tone, smooth=55, jitter=0.0, ao=0.6)
    # The wale: a rounded rubbing strake just under the gunwale, the paint job's stripe colour.
    for side in (1, -1):
        wale = [_side_point(t, 0.16, side) + Vector((side * 0.12, 0, 0)) for t in stations[:-1]]
        wale.append(_side_point(0.97, 0.16, side))
        a.add(K.tube(wale, 0.24, n=5), "BoatStripe", color=(255, 255, 255), smooth=50, jitter=0)
    # The inside of the hull: a darker skin a little inboard, so looking over the rail you see planking, not void.
    inner = [_ring(t, inset=0.35, lift=-0.05) for t in stations]
    for k in range(nseg):
        bm = K.bmesh.new()
        rows = [(bm.verts.new(r[k]), bm.verts.new(r[k + 1])) for r in inner]
        for (a0, a1), (b0, b1) in zip(rows, rows[1:]):
            bm.faces.new((a0, a1, b1, b0))
        K.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            c = f.calc_center_median()
            if f.normal.dot(Vector((c.x, 0, c.z + 0.6))) > 0:
                f.normal_flip()
        a.add((bm, set()), "Timber", color=(150, 100, 60), smooth=50, jitter=0.05, ao=0.5)
    # Transom: a flat board across the stern, a gold-trimmed name panel, the rudder.
    st = _ring(0.0)
    tb = K.bmesh.new()
    vs = [tb.verts.new(p + Vector((0, -0.05, 0))) for p in st]
    tb.faces.new(vs)
    K.bmesh.ops.recalc_face_normals(tb, faces=tb.faces)
    for f in tb.faces:
        if f.normal.y > 0:
            f.normal_flip()
    a.add((tb, set()), "BoatTrim", color=(255, 255, 255), smooth=10, jitter=0)
    a.add(K.box(4.2, 0.2, 0.9, bevel=0.08), "PaintedWood", color=(40, 30, 26), matrix=T(0, L_STERN - 0.12, 1.6))
    a.add(K.box(4.4, 0.24, 0.14), "GoldTrim", matrix=T(0, L_STERN - 0.14, 2.1), jitter=0)
    a.add(K.box(4.4, 0.24, 0.14), "GoldTrim", matrix=T(0, L_STERN - 0.14, 1.1), jitter=0)
    a.add(K.box(0.35, 1.2, 3.2, bevel=0.08), "DarkWood", matrix=T(0, L_STERN - 0.7, -0.6) @ R(-6, 0, 0))
    a.add(K.box(0.18, 0.9, 0.2), "Metal", matrix=T(0, L_STERN - 0.4, 1.0))
    # Gunwale caps along the sheer, rubbing strake (the wale) below them.
    for side in (1, -1):
        cap = [Vector((r[0].x if side > 0 else r[-1].x, r[0].y, r[0].z + 0.1)) for r in rings]
        a.add(K.tube(cap, 0.24, n=5), "BoatTrim", color=(255, 255, 255), smooth=40, jitter=0)
    # Stem post curling up at the bow with a gold finial; a little bowsprit.
    stem = [Vector((0, L_BOW - 1.6, -0.6)), Vector((0, L_BOW - 0.4, 1.6)), Vector((0, L_BOW + 0.1, 3.4)), Vector((0, L_BOW - 0.3, 4.4))]
    a.add(K.tube(stem, [0.3, 0.32, 0.3, 0.24], n=6), "BoatTrim", color=(255, 255, 255), smooth=50, jitter=0)
    a.add(K.ball(0.36, subdiv=1, seed=3), "GoldTrim", matrix=T(0, L_BOW - 0.35, 4.75), jitter=0)
    # The deck: planks at z = 1.5 (where V10's hull top is, so feet and the bow gun sit on it), inside the hull.
    for k in range(9):
        y0 = L_STERN + 0.4 + k * 2.6
        t0 = (y0 - L_STERN) / (L_BOW - L_STERN)
        t1 = (y0 + 2.5 - L_STERN) / (L_BOW - L_STERN)
        beam = min(_half_section(min(0.97, t0))[0], _half_section(min(0.97, t1))[0])
        w = max(0.6, (beam - 0.95) * 2)
        a.add(K.box(w, 2.5, 0.22), "Timber", color=(196, 150, 96), matrix=T(0, y0 + 1.3, 1.39), smooth=10, jitter=0.08, ao=0.6)
    # Thwarts under V10's two seats (their tops where the seats are, so a goblin sits on wood), knees at the ends.
    for y in (-6.0, -2.0):
        t = (y - L_STERN) / (L_BOW - L_STERN)
        beam = _half_section(t)[0]
        a.add(K.box(beam * 2 - 0.5, 1.6, 0.4, bevel=0.06), "Timber", color=(176, 124, 74), matrix=T(0, y, 2.15), jitter=0.06)
        for side in (-1, 1):
            a.add(K.box(0.4, 0.9, 0.9), "DarkWood", matrix=T(side * (beam - 0.5), y, 1.9))
    # The mast (tinted), a gold cap, a boom and a yard (trim), the sail (tinted, bellied, a band across it).
    a.add(K.cyl(0.42, 0.26, 12.4, n=8, bevel=0.04), "BoatMast", color=(255, 255, 255), matrix=T(0, 2.0, 1.2), smooth=45, jitter=0)
    a.add(K.ball(0.6, subdiv=1, seed=5), "GoldTrim", matrix=T(0, 2.0, 13.6), jitter=0)
    a.add(K.cyl(0.18, 0.18, 7.2, n=6), "BoatTrim", color=(255, 255, 255), matrix=T(0, 2.3, 4.4) @ R(90, 0, 0), smooth=40, jitter=0)
    a.add(K.cyl(0.16, 0.16, 7.0, n=6), "BoatTrim", color=(255, 255, 255), matrix=T(0.05, 2.3, 12.75) @ R(92, 0, 0), smooth=40, jitter=0)
    for band in (False, True):
        front, back = _sail(band)
        mat = "SailStripe" if band else "Sailcloth"
        a.add(front, mat, color=(255, 255, 255), smooth=60, jitter=0, ao=0.3)
        a.add(back, mat, color=(236, 236, 236), smooth=60, jitter=0, ao=0.3)
    # Rigging: forestay to the stem, shrouds to the rails, a sheet to the stern.
    head = Vector((0, 2.0, 13.2))
    for end in (Vector((0, L_BOW - 0.4, 4.2)), Vector((3.9, 0.5, 2.4)), Vector((-3.9, 0.5, 2.4)), Vector((0, L_STERN + 1.2, 2.3))):
        a.add(K.tube([head, end], 0.06, n=3), "Rope", smooth=10, jitter=0)
    # Little things that say someone sails it: a coiled rope, a keg, an oar along each side, the stern lantern.
    coil = [(math.cos(t * 0.8) * (0.7 - 0.02 * t), math.sin(t * 0.8) * (0.7 - 0.02 * t), 1.65 + 0.03 * t) for t in range(20)]
    a.add(K.tube(coil, 0.13, n=4), "Rope", matrix=T(2.1, 5.4, 0), smooth=50)
    a.add(K.cyl(0.55, 0.55, 1.1, n=8), "DarkWood", color=(140, 92, 54), matrix=T(-2.4, 5.6, 1.5), smooth=40)
    for side in (-1, 1):
        a.add(K.tube([(side * 2.7, -7.5, 2.5), (side * 2.9, 5.5, 2.35)], 0.11, n=4), "Driftwood", smooth=20)
        a.add(K.box(0.14, 1.6, 0.5), "Driftwood", matrix=T(side * 2.92, 6.1, 2.33))
    from props import lantern_head

    lantern_head(a, T(0, L_STERN + 0.4, 5.2) @ K.S(0.7))
    a.add(K.cyl(0.12, 0.12, 3.4, n=5), "DarkWood", matrix=T(0, L_STERN + 0.4, 1.9), smooth=30)
    a.add(K.box(0.14, 0.6, 0.14), "DarkWood", matrix=T(0, L_STERN + 0.4, 5.25))
    a.light((0, L_STERN + 0.4, 3.8), color=(255, 200, 130), range_=12, brightness=0.8)
    return a


def _sail(band, z0=4.6, z1=12.6):
    """The sail between the boom (z0) and the yard (z1), from the mast (y 2.0) aft to y -4.6, bellied to starboard.
    Returns its two faces (each one-sided): the band rows (band=True, the painted stripe) or the rest."""
    cols, rows = 6, 8
    stripe = (5, 6)  # the rows painted as the sail's band
    grid = []
    for j in range(rows + 1):
        v = j / rows
        z = z0 + (z1 - z0) * v
        row = []
        for i in range(cols + 1):
            u = i / cols
            y = 1.75 - u * (6.4 - 0.4 * v)
            belly = 0.9 * math.sin(math.pi * u) * math.sin(math.pi * (0.15 + 0.85 * v))
            row.append(Vector((belly + 0.12, y, z)))
        grid.append(row)
    out = []
    for flip in (False, True):
        bm = K.bmesh.new()
        vs = [[bm.verts.new(p if not flip else p - Vector((0.08, 0, 0))) for p in row] for row in grid]
        for j in range(rows):
            if (j in stripe) != band:
                continue
            for i in range(cols):
                quad = (vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i])
                bm.faces.new(quad if not flip else tuple(reversed(quad)))
        for f in bm.faces:
            f.normal_update()
            if (f.normal.x > 0) == flip:
                f.normal_flip()
        for v in [v for v in bm.verts if not v.link_faces]:
            bm.verts.remove(v)
        out.append((bm, set()))
    return out

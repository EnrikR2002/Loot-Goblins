"""Shorelines from captured ground (V14): marching squares over a Ground grid gives the line where the terrain crosses a
height (the waterline at 0.2, the wet-sand edge at 1.2...), as closed or open polylines in Roblox (x, z) relative to
the anchor. Used to lay the surf and the wet sand exactly where the game's water meets its sand."""

import math


def isolines(ground, level, x0=None, x1=None, z0=None, z1=None):
    """Polylines where height == level, each a list of (x, z), longest first."""
    g = ground
    step = g.step
    nx, nz = len(g.h[0]), len(g.h)
    segs = []

    def interp(p, q, hp, hq):
        t = (level - hp) / (hq - hp) if hq != hp else 0.5
        return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)

    for j in range(nz - 1):
        for i in range(nx - 1):
            x, z = g.x0 + i * step, g.z0 + j * step
            if x0 is not None and (x < x0 or x > x1 or z < z0 or z > z1):
                continue
            corners = [(x, z), (x + step, z), (x + step, z + step), (x, z + step)]
            hs = [g.h[j][i], g.h[j][i + 1], g.h[j + 1][i + 1], g.h[j + 1][i]]
            inside = [h >= level for h in hs]
            pts = []
            for k in range(4):
                a, b = k, (k + 1) % 4
                if inside[a] != inside[b]:
                    pts.append(interp(corners[a], corners[b], hs[a], hs[b]))
            if len(pts) == 2:
                segs.append((pts[0], pts[1]))
            elif len(pts) == 4:
                segs.append((pts[0], pts[1]))
                segs.append((pts[2], pts[3]))
    return _chain(segs)


def _key(p):
    return (round(p[0], 2), round(p[1], 2))


def _chain(segs):
    ends = {}
    for idx, (a, b) in enumerate(segs):
        ends.setdefault(_key(a), []).append(idx)
        ends.setdefault(_key(b), []).append(idx)
    used = [False] * len(segs)
    lines = []
    for start in range(len(segs)):
        if used[start]:
            continue
        used[start] = True
        line = [segs[start][0], segs[start][1]]
        for direction in (1, -1):
            while True:
                tip = line[-1] if direction == 1 else line[0]
                nxt = None
                for idx in ends.get(_key(tip), []):
                    if not used[idx]:
                        nxt = idx
                        break
                if nxt is None:
                    break
                used[nxt] = True
                a, b = segs[nxt]
                other = b if _key(a) == _key(tip) else a
                if direction == 1:
                    line.append(other)
                else:
                    line.insert(0, other)
        lines.append(line)
    lines.sort(key=len, reverse=True)
    return lines


def resample(line, spacing):
    """Even spacing along a polyline (closing it if its ends meet)."""
    closed = math.dist(line[0], line[-1]) < 0.5
    out = [line[0]]
    carry = 0.0
    for a, b in zip(line, line[1:]):
        seg = math.dist(a, b)
        d = spacing - carry
        while d <= seg:
            t = d / seg
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            d += spacing
        carry = seg - (d - spacing)
    if closed and math.dist(out[0], out[-1]) > spacing * 0.3:
        out.append(out[0])
    return out


def offset(line, distance, ground=None, toward_land=True):
    """Moves each point sideways by distance: towards higher ground (land) if toward_land, else towards the sea."""
    out = []
    for i, p in enumerate(line):
        a = line[max(0, i - 1)]
        b = line[min(len(line) - 1, i + 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / n, tx / n
        if ground is not None:
            up = ground.height(p[0] + nx * 2, p[1] + nz * 2) > ground.height(p[0] - nx * 2, p[1] - nz * 2)
            if up != toward_land:
                nx, nz = -nx, -nz
        out.append((p[0] + nx * distance, p[1] + nz * distance))
    return out


def offset_loop(line, distance, inward=True):
    """Moves each point of a closed loop sideways by distance, into the loop (inward) or out of it, by the loop's own
    winding (steadier than probing the ground at every point)."""
    area = 0.0
    for a, b in zip(line, line[1:] + line[:1]):
        area += a[0] * b[1] - b[0] * a[1]
    sign = 1.0 if area > 0 else -1.0
    if not inward:
        sign = -sign
    out = []
    n_pts = len(line)
    for i, p in enumerate(line):
        a = line[(i - 1) % n_pts]
        b = line[(i + 1) % n_pts]
        tx, tz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(tx, tz) or 1.0
        # the left of the direction of travel; for a counter-clockwise loop (positive area) that is inside
        nx, nz = -tz / n * sign, tx / n * sign
        out.append((p[0] + nx * distance, p[1] + nz * distance))
    return out

"""Loot Goblins art kit for Blender 4.5 (V14: The Visual Renaissance).

Everything an asset build script needs: the materials library, chunky stylised modelling helpers with a hand-made
wobble, baked shading (ambient occlusion, a ground gradient and light bevel edges, all stored in vertex colours), and
the conventions the exporter (lgexport.py) relies on. See art/README.md for the whole pipeline.

Conventions (the exporter and the game depend on them):
  * 1 Blender unit = 1 Roblox stud. Blender is Z-up; the exporter maps Blender (x, y, z) to Roblox (x, z, -y), so an
    asset's FRONT faces Blender +Y (Roblox -Z, a part's LookVector). The object origin is the asset's pivot.
  * Every asset is one mesh object named SM_<AssetId>. Its faces use library materials (M_<Name>); faces that share a
    Roblox material (and tint role and transparency) become one MeshPart in game.
  * Colour lives in the corner colour attribute "Col" (sRGB): the library colour, varied per piece, times the baked
    shading. Painted boat parts keep white times shading and are tinted in game by the goblin's paint (tint roles).
  * Optional helpers inside an asset's collection: COL_<AssetId>_<n> boxes (client collision proxies),
    LIGHT_<AssetId>_<n> point lights (become PointLights). Layout collections hold placed instances and HIDE_ boxes.
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", ".."))
REPO = os.path.dirname(ART)

# --------------------------------------------------------------------------------------------------------------------
# The materials library. colour: sRGB 0-255 (the painted base colour); rbx: the Roblox material the faces render with;
# tint: a paint role the game recolours (boats); alpha: MeshPart transparency; glow: lights itself (Neon).
# Roblox's built-in materials ignore mesh UVs and tile in studs, so a material's grain is the same size on every
# asset. Keep the noisy ones (Grass, Fabric, Rock) off small pieces: colour and shape carry the style.
LIBRARY = {
    "Timber": dict(color=(178, 120, 72), rbx="Wood", note="honey timber: posts, frames, planks, crates"),
    "DarkWood": dict(color=(98, 64, 42), rbx="Wood", note="dark timber: beams, braces, trim, barrel staves"),
    "Driftwood": dict(color=(176, 162, 140), rbx="Wood", note="sun-bleached grey wood: piles, driftwood, old docks"),
    "PaintedWood": dict(color=(255, 255, 255), rbx="Wood", note="painted boards, shutters, doors: colour per piece"),
    "BoatPaint": dict(color=(255, 255, 255), rbx="SmoothPlastic", tint="hull", note="a hull's paint (tinted in game)"),
    "BoatStripe": dict(color=(255, 255, 255), rbx="SmoothPlastic", tint="stripe", note="a hull's stripe (tinted)"),
    "BoatTrim": dict(color=(255, 255, 255), rbx="Wood", tint="trim", note="rails, transom, yard (tinted)"),
    "BoatMast": dict(color=(255, 255, 255), rbx="Wood", tint="mast", note="the mast (tinted)"),
    "Sailcloth": dict(color=(255, 255, 255), rbx="SmoothPlastic", tint="sail", note="a sail (tinted by the paint)"),
    "SailStripe": dict(color=(255, 255, 255), rbx="SmoothPlastic", tint="sailStripe", note="a sail's band (tinted)"),
    "Canvas": dict(color=(238, 226, 198), rbx="SmoothPlastic", note="awnings, sacks, banners: colour per piece"),
    "Plaster": dict(color=(244, 232, 204), rbx="SmoothPlastic", ao=0.3, note="lime-washed walls"),
    "Sandstone": dict(color=(214, 180, 128), rbx="Sandstone", note="dressed stone: plinths, quoins, steps"),
    "Cobble": dict(color=(176, 164, 150), rbx="Cobblestone", note="chimneys and rough stonework"),
    "Flagstone": dict(color=(208, 192, 160), rbx="Concrete", ao=0.5, note="paving flags on paths and quays"),
    "RoofTile": dict(color=(198, 92, 62), rbx="SmoothPlastic", note="terracotta tiles, modelled in rows"),
    "Slate": dict(color=(84, 92, 112), rbx="Slate", note="slate roofs and dark stone"),
    "CoastRock": dict(color=(140, 128, 120), rbx="Slate", note="coastal rock: chunky faceted boulders and cliffs"),
    "Pebble": dict(color=(156, 164, 172), rbx="SmoothPlastic", note="smooth sea-worn pebbles (Pebble Isle)"),
    "Sand": dict(color=(228, 198, 142), rbx="Sand", note="sand mounds and dune skirts"),
    "WetSand": dict(color=(196, 166, 116), rbx="Sand", ao=0.0, note="the darker band the waves keep wet"),
    "Soil": dict(color=(124, 88, 58), rbx="Ground", note="planters, earth under roots"),
    "Foliage": dict(color=(92, 170, 74), rbx="SmoothPlastic", note="leaves and bushes: two greens per plant"),
    "Bark": dict(color=(128, 96, 66), rbx="Wood", note="palm trunks and roots"),
    "Flower": dict(color=(255, 255, 255), rbx="SmoothPlastic", note="petals: colour per piece"),
    "Metal": dict(color=(74, 74, 82), rbx="Metal", note="iron: bands, hinges, anchors, cannon"),
    "GoldTrim": dict(color=(255, 196, 46), rbx="Metal", note="goblin gold: finials, sign lettering plates, trim"),
    "Rope": dict(color=(214, 190, 146), rbx="SmoothPlastic", note="rope, rigging, nets"),
    "Glass": dict(color=(70, 96, 112), rbx="SmoothPlastic", note="dark window panes (a lighter streak painted on)"),
    "Glow": dict(color=(255, 214, 140), rbx="Neon", glow=True, note="lantern glass: small, deliberate"),
    "ShopGlass": dict(color=(190, 228, 250), rbx="Glass", alpha=0.72, note="a shop window you can see through"),
    "Foam": dict(color=(250, 252, 255), rbx="SmoothPlastic", alpha=0.45, note="surf and foam at the waterline"),
}
ORDER = list(LIBRARY)


def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


# --------------------------------------------------------------------------------------------------------------------
# Scene and materials


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"  # 1 unit = 1 stud
    return scene


def material(name):
    """The Blender material M_<name> for a library entry, made once per file."""
    key = "M_" + name
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    entry = LIBRARY[name]
    mat = bpy.data.materials.new(key)
    c = rgb(*entry["color"])
    mat.diffuse_color = (c[0], c[1], c[2], 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    if entry.get("glow"):
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 2.0
    if entry.get("alpha"):
        bsdf.inputs["Alpha"].default_value = 1.0 - entry["alpha"]
    mat["rbx"] = entry["rbx"]
    mat["tint"] = entry.get("tint", "")
    mat["alpha"] = float(entry.get("alpha", 0.0))
    mat["lg"] = name
    return mat


def collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if not col:
        col = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(col)
    return col


# --------------------------------------------------------------------------------------------------------------------
# Colour helpers (sRGB 0-1 tuples)


def vary(col, amount, rng):
    """A hand-painted variation: value and a touch of hue, so no two planks are the same."""
    v = 1.0 + rng.uniform(-amount, amount)
    w = rng.uniform(-amount, amount) * 0.35
    return (clamp(col[0] * v * (1 + w)), clamp(col[1] * v), clamp(col[2] * v * (1 - w)))


def lighten(col, k):
    return tuple(clamp(c + (1 - c) * k) for c in col)


def darken(col, k):
    return tuple(clamp(c * (1 - k)) for c in col)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def dim(color, k):
    """A darker 0-255 colour (the underside of a leaf, the shadow side of a stripe)."""
    return tuple(max(0, min(255, int(c * (1 - k)))) for c in color)


def clamp(x, lo=0.0, hi=1.0):
    return lo if x < lo else hi if x > hi else x


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0)) if e1 != e0 else 1.0
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------------------------------------------------
# Transforms


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(x=0.0, y=0.0, z=0.0):
    """Rotation in degrees, applied X then Y then Z."""
    return (
        Matrix.Rotation(math.radians(z), 4, "Z")
        @ Matrix.Rotation(math.radians(y), 4, "Y")
        @ Matrix.Rotation(math.radians(x), 4, "X")
    )


def S(x=1.0, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1.0))


def look(frm, to, up=Vector((0, 0, 1))):
    """A matrix at frm whose +Y points at to (Z kept as close to up as possible)."""
    frm, to = Vector(frm), Vector(to)
    fwd = (to - frm).normalized()
    side = fwd.cross(up)
    if side.length < 1e-6:
        side = fwd.cross(Vector((1, 0, 0)))
    side.normalize()
    upv = side.cross(fwd)
    m = Matrix((side, fwd, upv)).transposed().to_4x4()
    m.translation = frm
    return m


# --------------------------------------------------------------------------------------------------------------------
# The asset: a growing list of faces, each remembering its material, colour, piece and smoothing angle.


class Asset:
    def __init__(self, asset_id, seed=1):
        self.id = asset_id
        self.verts = []
        self.faces = []  # (vertex indices, material, colour, piece id, smooth degrees)
        self.pieces = 0
        self.rng = random.Random(seed)
        self.solids = []  # (matrix, size) collision proxies
        self.lights = []  # (position, colour, range, brightness)
        self.texts = []  # (matrix, (w, h), text, colour, "y" | "x"): painted lettering, drawn in game
        self.props = {}

    def add(self, piece, mat, color=None, matrix=None, smooth=32.0, jitter=0.06, edge=0.12, ao=None):
        """Adds a piece (bm, highlight faces) in `mat`, placed by `matrix`. color: sRGB 0-255 tuple or None for
        the library colour; jitter: the hand-painted variation; edge: how much lighter the bevel faces are; ao: how
        much baked occlusion it takes (big flat panels take little: their few corners would darken all of them)."""
        if ao is None:
            ao = LIBRARY[mat].get("ao", 1.0)
        bm, highlight = piece
        if matrix is None:
            matrix = Matrix()
        base_col = rgb(*(color or LIBRARY[mat]["color"]))
        col = vary(base_col, jitter, self.rng) if jitter else base_col
        edge_col = lighten(col, edge)
        flip = matrix.to_3x3().determinant() < 0
        start = len(self.verts)
        # Some bmesh operators return elements in memory order: sort them, so a rebuild writes identical files.
        order = sorted(bm.verts, key=lambda v: (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)))
        number = {}
        for i, v in enumerate(order):
            number[v] = i
            self.verts.append(matrix @ v.co)
        pid = self.pieces
        self.pieces += 1
        for f in sorted(bm.faces, key=lambda f: sorted(number[v] for v in f.verts)):
            local = [number[v] for v in f.verts]
            first = local.index(min(local))
            idx = [start + i for i in local[first:] + local[:first]]
            if flip:
                idx.reverse()
            self.faces.append((idx, mat, edge_col if f in highlight else col, pid, smooth, ao))
        bm.free()
        return pid

    def solid(self, size, matrix):
        """A box the player's character collides with (built on each client with the visuals)."""
        self.solids.append((matrix.copy(), tuple(size)))

    def light(self, pos, color=(255, 200, 130), range_=16.0, brightness=1.0):
        self.lights.append((Vector(pos), color, range_, brightness))

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.faces)


# --------------------------------------------------------------------------------------------------------------------
# Pieces. Each returns (bm, highlight) in local space: highlight is the set of bevel faces, painted lighter.


def bevel_sharp(bm, offset, angle=50.0, segments=1):
    if offset <= 0:
        return set()
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > math.radians(angle)]
    if not edges:
        return set()
    res = bmesh.ops.bevel(
        bm,
        geom=edges,
        offset=offset,
        offset_type="OFFSET",
        segments=segments,
        profile=0.5,
        affect="EDGES",
        clamp_overlap=True,
    )
    return set(res["faces"])


def box(sx, sy, sz, bevel=0.0, wonk=0.0, seed=0):
    """A box centred on the origin, bevelled. wonk: how far its corners wander (hand-made)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if wonk:
        jiggle(bm, wonk, seed)
    hl = bevel_sharp(bm, min(bevel, sx * 0.45, sy * 0.45, sz * 0.45))
    return bm, hl


def cyl(r1, r2, h, n=8, bevel=0.0, wonk=0.0, seed=0, cap=True):
    """A (tapered) cylinder along Z, its base at z=0."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=n, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    if wonk:
        jiggle(bm, wonk, seed)
    hl = bevel_sharp(bm, min(bevel, r1 * 0.4, r2 * 0.4 if r2 > 0 else bevel, h * 0.3), angle=60)
    return bm, hl


def ball(r, subdiv=1, squash=1.0, lump=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    off = _offset(seed)
    for v in bm.verts:
        d = v.co.normalized()
        k = 1.0 + lump * noise.noise(d * 1.7 + off)
        v.co = Vector((d.x * r * k, d.y * r * k, d.z * r * k * squash))
    return bm, set()


def rock(r, seed, squash=0.72, points=22, bevel=0.0, flat=0.45):
    """A chunky faceted boulder: the convex hull of points scattered on a lumpy ellipsoid, its base flattened."""
    rng = random.Random(seed)
    off = _offset(seed)
    pts = []
    for _ in range(points):
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        k = 1.0 + 0.32 * noise.noise(d * 1.4 + off) + rng.uniform(-0.08, 0.08)
        p = Vector((d.x * r * k, d.y * r * k * rng.uniform(0.82, 1.0), d.z * r * k * squash))
        p.z = max(p.z, -r * squash * flat)
        pts.append(p)
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=verts)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hl = bevel_sharp(bm, bevel, angle=35)
    return bm, hl


def prism(w, d, h, overhang=0.0):
    """A gable: a triangular prism along X (width w), depth d, apex height h above z=0."""
    bm = bmesh.new()
    hw, hd = w / 2 + overhang, d / 2
    a = [bm.verts.new(p) for p in ((-hw, -hd, 0), (-hw, hd, 0), (-hw, 0, h))]
    b = [bm.verts.new(p) for p in ((hw, -hd, 0), (hw, hd, 0), (hw, 0, h))]
    bm.faces.new((a[0], a[2], a[1]))
    bm.faces.new((b[0], b[1], b[2]))
    bm.faces.new((a[0], a[1], b[1], b[0]))
    bm.faces.new((a[1], a[2], b[2], b[1]))
    bm.faces.new((a[2], a[0], b[0], b[2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, set()


def slab(points, thickness, bevel=0.0):
    """An extruded outline: points are (x, y) in the XY plane (counter-clockwise), extruded up by thickness."""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, 0)) for x, y in points]
    face = bm.faces.new(bottom)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, thickness), verts=top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hl = bevel_sharp(bm, bevel, angle=50)
    return bm, hl


def loft(rings, cap_start=True, cap_end=True):
    """Skins a list of rings (each a list of Vectors, same count, counter-clockwise seen from the start)."""
    bm = bmesh.new()
    vrings = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vrings, vrings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start:
        bm.faces.new(list(reversed(vrings[0])))
    if cap_end:
        bm.faces.new(vrings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, set()


def tube(points, radii, n=6, cap=True, twist=0.0):
    """A tube along a path (ropes, trunks, vines, curved beams). radii: one per point (or one number)."""
    pts = [Vector(p) for p in points]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    rings = []
    prev_side = None
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        t.normalize()
        if prev_side is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            side = t.cross(ref).normalized()
        else:
            side = (prev_side - t * prev_side.dot(t)).normalized()
        prev_side = side
        up = side.cross(t).normalized()
        ring = []
        for k in range(n):
            a = 2 * math.pi * k / n + twist * i
            ring.append(p + (side * math.cos(a) + up * math.sin(a)) * radii[i])
        rings.append(ring)
    return loft(rings, cap, cap)


def strip(points, widths, normal=Vector((0, 0, 1)), fold=0.0, thickness=0.0):
    """A ribbon along a path (palm fronds, flags, foam). fold lifts the middle line (a V cross-section)."""
    pts = [Vector(p) for p in points]
    if not isinstance(widths, (list, tuple)):
        widths = [widths] * len(pts)
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(normal).normalized()
        up = side.cross(t).normalized()
        w = widths[i] / 2
        rows.append(
            [
                bm.verts.new(p - side * w),
                bm.verts.new(p + up * fold * widths[i]),
                bm.verts.new(p + side * w),
            ]
        )
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], b[0], b[1], a[1]))
        bm.faces.new((a[1], b[1], b[2], a[2]))
    if thickness:
        res = bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thickness)
        del res
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, set()


def merge(*pieces):
    """Joins several pieces into one (they then share a material, colour and smoothing)."""
    out = bmesh.new()
    hl = set()
    for bm, h in pieces:
        me = bpy.data.meshes.new("_tmp")
        bm.to_mesh(me)
        base = len(out.faces)
        out.from_mesh(me)
        out.faces.ensure_lookup_table()
        bm.faces.index_update()
        for f in h:
            hl.add(out.faces[base + f.index])
        bpy.data.meshes.remove(me)
        bm.free()
    return out, hl


def place(piece, matrix):
    """Moves a piece in its own space (before Asset.add places it)."""
    bm, hl = piece
    bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    return bm, hl


def jiggle(bm, amount, seed):
    """Moves every vertex a little (shared corners move together): the hand-made wobble."""
    off = _offset(seed)
    for v in bm.verts:
        p = v.co
        v.co = p + Vector(
            (
                noise.noise(p * 0.37 + off) * amount,
                noise.noise(p * 0.37 + off + Vector((17.3, 0, 0))) * amount,
                noise.noise(p * 0.37 + off + Vector((0, 31.7, 0))) * amount,
            )
        )


def sag(bm, axis, length, amount, up=2):
    """Bends a long piece down in the middle (ridge lines, ropes, old beams)."""
    for v in bm.verts:
        t = clamp(v.co[axis] / (length / 2) if length else 0, -1, 1)
        v.co[up] -= amount * (1 - t * t)


def _offset(seed):
    r = random.Random(seed * 7919 + 13)
    return Vector((r.uniform(-50, 50), r.uniform(-50, 50), r.uniform(-50, 50)))


# --------------------------------------------------------------------------------------------------------------------
# Building the object: normals that never smooth across pieces, baked shading, materials.

_HEMI = None


def _hemisphere(count=28):
    """Fixed cosine-weighted directions around +Z (deterministic, so a rebuild is identical)."""
    global _HEMI
    if _HEMI is None or len(_HEMI) != count:
        out = []
        golden = math.pi * (3 - math.sqrt(5))
        for i in range(count):
            u = (i + 0.5) / count
            r = math.sqrt(u)
            a = i * golden
            out.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - u)))))
        _HEMI = out
    return _HEMI


def _basis(n):
    ref = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
    t = n.cross(ref).normalized()
    return t, n.cross(t)


def build(asset, ground=None, ao=(4.0, 0.75), gradient=(0.72, 6.0), occluders=None, collection_=None, sky=0.0):
    """Turns an Asset into the mesh object SM_<id>: per-corner normals (smoothed only within a piece, under its angle),
    then corner colours = piece colour x ambient occlusion x a gradient that darkens towards the ground.
    ground: the height (z) of a ground plane that occludes (None: no ground); ao: (reach in studs, strength);
    gradient: (darkness at the base, height over which it fades); occluders: extra BVHTrees (neighbours)."""
    verts = asset.verts
    faces = asset.faces
    # Face normals and areas
    fnorm, farea = [], []
    for idx, *_ in faces:
        n = Vector()
        p0 = verts[idx[0]]
        for i in range(1, len(idx) - 1):
            n += (verts[idx[i]] - p0).cross(verts[idx[i + 1]] - p0)
        a = n.length / 2
        fnorm.append(n.normalized() if a > 1e-9 else Vector((0, 0, 1)))
        farea.append(a)
    # Faces round each vertex
    around = [[] for _ in verts]
    for fi, (idx, *_r) in enumerate(faces):
        for v in idx:
            around[v].append(fi)
    corner_normals = []
    for fi, (idx, _m, _c, pid, smooth, _ao) in enumerate(faces):
        limit = math.cos(math.radians(smooth))
        nf = fnorm[fi]
        for v in idx:
            n = Vector()
            for g in around[v]:
                if faces[g][3] == pid and fnorm[g].dot(nf) >= limit:
                    n += fnorm[g] * max(farea[g], 1e-6)
            corner_normals.append(n.normalized() if n.length > 1e-9 else nf)
    # Occlusion: the asset itself, a ground plane, neighbours.
    tris = []
    for idx, *_ in faces:
        for i in range(1, len(idx) - 1):
            tris.append((idx[0], idx[i], idx[i + 1]))
    trees = [BVHTree.FromPolygons(verts, tris, all_triangles=True)]
    zmin = min(v.z for v in verts) if verts else 0.0
    if ground is not None:
        g = 400.0
        gv = [Vector((-g, -g, ground)), Vector((g, -g, ground)), Vector((g, g, ground)), Vector((-g, g, ground))]
        trees.append(BVHTree.FromPolygons(gv, [(0, 1, 2, 3)]))
    trees += occluders or []
    reach, strength = ao
    dirs = _hemisphere()
    cache = {}
    colors = []
    k = 0
    gdark, gheight = gradient
    for fi, (idx, _m, col, _pid, _s, face_ao) in enumerate(faces):
        for v in idx:
            n = corner_normals[k]
            key = (v, round(n.x, 2), round(n.y, 2), round(n.z, 2))
            occ = cache.get(key)
            if occ is None:
                p = verts[v] + n * 0.03
                t, b = _basis(n)
                hits = 0.0
                for d in dirs:
                    w = t * d.x + b * d.y + n * d.z
                    for tree in trees:
                        loc, _nn, _i, dist = tree.ray_cast(p, w, reach)
                        if loc is not None:
                            hits += 1.0 - (dist / reach) * 0.5
                            break
                occ = hits / len(dirs)
                cache[key] = occ
            shade = 1.0 - strength * face_ao * occ
            if gheight > 0:
                shade *= gdark + (1 - gdark) * smoothstep(0.0, gheight, verts[v].z - zmin)
            if sky:
                shade *= 1.0 + sky * max(0.0, n.z)
            colors.append(tuple(clamp(c * shade) for c in col))
            k += 1
    # The Blender mesh
    me = bpy.data.meshes.new("SM_" + asset.id)
    me.from_pydata([tuple(v) for v in verts], [], [f[0] for f in faces])
    me.validate()
    me.update()
    assert len(me.polygons) == len(faces), "%s: a degenerate face was dropped" % asset.id
    used = []
    for f in faces:
        if f[1] not in used:
            used.append(f[1])
    used.sort(key=ORDER.index)
    for name in used:
        me.materials.append(material(name))
    me.polygons.foreach_set("material_index", [used.index(f[1]) for f in faces])
    me.polygons.foreach_set("use_smooth", [True] * len(faces))
    attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    flat = []
    for c in colors:
        flat += (c[0], c[1], c[2], 1.0)
    attr.data.foreach_set("color_srgb", flat)
    me.color_attributes.active_color = attr
    me.normals_split_custom_set(corner_normals)
    obj = bpy.data.objects.new("SM_" + asset.id, me)
    obj["lg_id"] = asset.id
    for key, value in asset.props.items():
        obj["lg_" + key] = value
    col = collection_ or bpy.context.scene.collection
    col.objects.link(obj)
    for i, (m, size) in enumerate(asset.solids):
        proxy = bpy.data.objects.new("COL_%s_%d" % (asset.id, i + 1), None)
        proxy.empty_display_type = "CUBE"
        proxy.matrix_world = m @ Matrix.Diagonal((size[0] / 2, size[1] / 2, size[2] / 2, 1))
        proxy.parent = obj
        col.objects.link(proxy)
    for i, (m, size, text, color, axis) in enumerate(asset.texts):
        # The helper's +Y is the way the lettering faces; "x" boards (hanging signs) face +-X and get both sides.
        if axis == "x":
            m = m @ Matrix.Rotation(math.radians(-90), 4, "Z")
        label = bpy.data.objects.new("TEXT_%s_%d" % (asset.id, i + 1), None)
        label.empty_display_type = "SINGLE_ARROW"
        label.matrix_world = m
        label["text"] = text
        label["color"] = list(color)
        label["w"], label["h"] = size
        label["double"] = axis == "x"
        label.parent = obj
        col.objects.link(label)
    for i, (pos, color, range_, brightness) in enumerate(asset.lights):
        data = bpy.data.lights.new("LIGHT_%s_%d" % (asset.id, i + 1), "POINT")
        data.color = rgb(*color)
        data.energy = brightness * 40
        data.shadow_soft_size = 0.2
        data["range"] = range_
        data["brightness"] = brightness
        lamp = bpy.data.objects.new("LIGHT_%s_%d" % (asset.id, i + 1), data)
        lamp.location = pos
        lamp.parent = obj
        col.objects.link(lamp)
    return obj


def tree_of(obj):
    """A BVHTree of an object's mesh in world space (to occlude a neighbour's shading)."""
    me = obj.data
    mw = obj.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    return BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in me.polygons])


def save(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)


def preview(path, eye, target, lens=35.0, size=(1280, 800), objects=None, ortho=None, light="STUDIO"):
    """Renders a quick Workbench picture (vertex colours, soft studio light, shadows and cavity) for checking an
    asset or a layout without opening Studio. eye/target: Blender coordinates."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = light
    shading.color_type = "VERTEX"
    shading.show_shadows = False
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("_preview")
    scene.world.color = (0.55, 0.72, 0.9)
    scene.display.light_direction = (0.45, -0.35, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    cam_data = bpy.data.cameras.get("_preview") or bpy.data.cameras.new("_preview")
    cam_data.lens = lens
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.type = "PERSP"
    cam_data.clip_end = 5000
    cam = bpy.data.objects.get("_preview") or bpy.data.objects.new("_preview", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    m = look(eye, target)
    # a camera looks down its -Z with +Y up: turn look()'s frame (+Y forward, +Z up) into that
    cam.matrix_world = m @ Matrix.Rotation(math.radians(90), 4, "X")
    scene.camera = cam
    hidden = []
    if objects is not None:
        keep = set(objects)
        for o in scene.objects:
            if o.type == "MESH" and o not in keep and not o.hide_render:
                o.hide_render = True
                hidden.append(o)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in hidden:
        o.hide_render = False
    bpy.data.objects.remove(cam)


def report(asset):
    """Triangles per material (to find what blows a budget)."""
    out = {}
    for idx, mat, *_ in asset.faces:
        out[mat] = out.get(mat, 0) + len(idx) - 2
    return ", ".join("%s %d" % kv for kv in sorted(out.items(), key=lambda kv: -kv[1]))


def write_library(json_path, png_path, cell=64, per_row=8):
    """The materials library as data (art/manifest/materials.json) and a swatch sheet (art/textures), in ORDER."""
    import json

    data = {}
    for name in ORDER:
        e = LIBRARY[name]
        data[name] = {
            "blender": "M_" + name,
            "color": list(e["color"]),
            "roblox": e["rbx"],
            "tint": e.get("tint", ""),
            "alpha": e.get("alpha", 0.0),
            "glow": bool(e.get("glow", False)),
            "ao": e.get("ao", 1.0),
            "note": e.get("note", ""),
        }
    os.makedirs(os.path.dirname(json_path), exist_ok=True)
    with open(json_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"order": ORDER, "materials": data}, handle, indent=1)
        handle.write("\n")
    rows = (len(ORDER) + per_row - 1) // per_row
    w, h = per_row * cell, rows * cell
    img = bpy.data.images.new("_swatches", w, h, alpha=False)
    px = [0.12, 0.09, 0.07, 1.0] * (w * h)
    for i, name in enumerate(ORDER):
        r, g, b = LIBRARY[name]["color"]
        col = [(c / 255.0) ** 2.2 for c in (r, g, b)]  # the image stores linear values
        cx, cy = (i % per_row) * cell, (rows - 1 - i // per_row) * cell
        for y in range(cy + 4, cy + cell - 4):
            for x in range(cx + 4, cx + cell - 4):
                k = (y * w + x) * 4
                px[k : k + 3] = col
    img.pixels.foreach_set(px)
    img.filepath_raw = png_path
    img.file_format = "PNG"
    os.makedirs(os.path.dirname(png_path), exist_ok=True)
    img.save()
    bpy.data.images.remove(img)

"""Loot Goblins exporter (V14): Blender assets and layouts -> the game, plus files for a manual Roblox import.

Run it on a saved .blend (a build script calls export_file itself):
    blender --background art/blender/<File>.blend --python art/blender/scripts/lgexport.py

What it writes for every SM_<AssetId> object in the file:
  * src/client/Art14/Meshes/<AssetId>.lua  the mesh data the game builds MeshParts from at run time (EditableMesh):
                                            one group per Roblox material, positions/normals/colours/triangles
  * art/exports/<Set>/<AssetId>.fbx|.glb   the same groups as separate objects, for the Studio 3D Importer or the
                                            Roblox Blender plugin (each object becomes one MeshPart)
  * art/manifest/assets.json               the asset's entry: source, sizes, budgets, groups, collision, lights and
                                            the Roblox asset id of each group once a human uploads it
and for every LAYOUT_<Set> collection: src/client/Art14/Layouts/<Set>.lua (placed instances and what they hide).
Finally src/client/Art14/Manifest.lua is regenerated from assets.json (the game reads only that).
"""

import hashlib
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lgkit  # noqa: E402

REPO = lgkit.REPO
LUA_ROOT = os.path.join(REPO, "src", "client", "Art14")
MANIFEST = os.path.join(lgkit.ART, "manifest", "assets.json")

# Blender (x, y, z) -> Roblox (x, z, -y)
A = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))


def to_rbx(v):
    return Vector((v[0], v[2], -v[1]))


def num(x, digits):
    s = ("%." + str(digits) + "f") % x
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "", "-") else s


def lua_list(values, digits=None):
    if digits is None:
        return "{ " + ", ".join(str(int(v)) for v in values) + " }"
    return "{ " + ", ".join(num(v, digits) for v in values) + " }"


def rel(path):
    return os.path.relpath(path, REPO).replace("\\", "/")


# --------------------------------------------------------------------------------------------------------------------
# Reading an asset object


def asset_groups(obj):
    """The asset's triangles grouped by Roblox material, tint and transparency, in Roblox coordinates."""
    me = obj.data
    me.calc_loop_triangles()
    col = me.color_attributes.get("Col")
    cn = me.corner_normals
    groups = {}
    order = []
    for tri in me.loop_triangles:
        mat = me.materials[tri.material_index] if me.materials else None
        lg = mat.get("lg", "Timber") if mat else "Timber"
        entry = lgkit.LIBRARY.get(lg, lgkit.LIBRARY["Timber"])
        key = (entry["rbx"], entry.get("tint", ""), float(entry.get("alpha", 0.0)), bool(entry.get("glow")))
        g = groups.get(key)
        if not g:
            g = groups[key] = {"key": key, "corners": [], "libs": []}
            order.append(key)
        if lg not in g["libs"]:
            g["libs"].append(lg)
        corners = []
        for li in tri.loops:
            vi = me.loops[li].vertex_index
            p = to_rbx(me.vertices[vi].co)
            n = to_rbx(cn[li].vector)
            c = col.data[li].color_srgb if col else (1, 1, 1, 1)
            corners.append((vi, p, n, (round(c[0] * 255), round(c[1] * 255), round(c[2] * 255))))
        g["corners"].append(corners)
    # Glowing and see-through groups last, so the solid body is the first MeshPart.
    order.sort(key=lambda k: (k[3], k[2] > 0))
    return [groups[k] for k in order]


def pack(group):
    """Deduplicated positions, normals and colours, and triangles indexing them; positions centred on the group."""
    pos_index, nrm_index, col_index = {}, {}, {}
    pos, nrm, cols, faces = [], [], [], []
    for tri in group["corners"]:
        vs, ns, cs = [], [], []
        for vi, p, n, c in tri:
            if vi not in pos_index:
                pos_index[vi] = len(pos)
                pos.append(p)
            vs.append(pos_index[vi])
            nk = (round(n.x, 3), round(n.y, 3), round(n.z, 3))
            if nk not in nrm_index:
                nrm_index[nk] = len(nrm)
                nrm.append(nk)
            ns.append(nrm_index[nk])
            if c not in col_index:
                col_index[c] = len(cols)
                cols.append(c)
            cs.append(col_index[c])
        faces.append(vs + ns + cs)
    lo = Vector((min(p.x for p in pos), min(p.y for p in pos), min(p.z for p in pos)))
    hi = Vector((max(p.x for p in pos), max(p.y for p in pos), max(p.z for p in pos)))
    centre = (lo + hi) / 2
    size = hi - lo
    return {
        "pos": [p - centre for p in pos],
        "nrm": nrm,
        "col": cols,
        "faces": faces,
        "offset": centre,
        "size": Vector((max(size.x, 0.05), max(size.y, 0.05), max(size.z, 0.05))),
    }


def helpers(obj):
    """COL_ collision boxes, LIGHT_ lamps and TEXT_ lettering parented to an asset, in the asset's Roblox space."""
    bpy.context.view_layer.update()
    inv = obj.matrix_world.inverted()
    solids, lights, texts = [], [], []
    for child in obj.children:
        m = inv @ child.matrix_world
        if child.name.startswith("COL_"):
            loc, rot, scale = m.decompose()
            r = A @ rot.to_matrix() @ A.transposed()
            p = to_rbx(loc)
            size = (abs(scale.x) * 2, abs(scale.z) * 2, abs(scale.y) * 2)
            solids.append({"cf": [p.x, p.y, p.z] + [r[i][j] for i in range(3) for j in range(3)], "size": size})
        elif child.name.startswith("TEXT_"):
            loc, rot, _scale = m.decompose()
            r = A @ rot.to_matrix() @ A.transposed()
            p = to_rbx(loc)
            texts.append(
                {
                    "cf": [p.x, p.y, p.z] + [r[i][j] for i in range(3) for j in range(3)],
                    "size": [float(child["w"]), float(child["h"])],
                    "text": str(child["text"]),
                    "color": [int(c) for c in child["color"]],
                    "double": bool(child.get("double", False)),
                }
            )
        elif child.name.startswith("LIGHT_") and child.type == "LIGHT":
            p = to_rbx(m.translation)
            c = child.data.color
            lights.append(
                {
                    "pos": [p.x, p.y, p.z],
                    "color": [round(c[0] * 255), round(c[1] * 255), round(c[2] * 255)],
                    "range": float(child.data.get("range", 16)),
                    "brightness": float(child.data.get("brightness", 1)),
                }
            )
    return solids, lights, texts


# --------------------------------------------------------------------------------------------------------------------
# Writing


# Roblox refuses a script source of 200,000 characters or more (set by a plugin, Rojo's sync included), so each
# group is its own module and a big group is cut into several (more MeshParts, same look).
MAX_TRIS = 2200


def split_groups(groups):
    out = []
    for g in groups:
        corners = g["corners"]
        if len(corners) <= MAX_TRIS:
            out.append(g)
            continue
        for k in range(0, len(corners), MAX_TRIS):
            out.append({"key": g["key"], "libs": g["libs"], "corners": corners[k : k + MAX_TRIS]})
    return out


def write_mesh_module(asset_id, set_name, source, packed, groups):
    """Meshes/<asset>/<n>.lua: one module per group (MeshKit requires them by number)."""
    folder = os.path.join(LUA_ROOT, "Meshes", asset_id)
    if os.path.isdir(folder):
        for old in os.listdir(folder):
            os.remove(os.path.join(folder, old))
    os.makedirs(folder, exist_ok=True)
    for index, (g, pk) in enumerate(zip(groups, packed), start=1):
        flat_p = [c for p in pk["pos"] for c in (p.x, p.y, p.z)]
        flat_n = [c for n in pk["nrm"] for c in n]
        flat_c = [c for col in pk["col"] for c in col]
        flat_f = [i + 1 for f in pk["faces"] for i in f]
        lines = [
            "-- Generated by art/blender/scripts/lgexport.py from %s (SM_%s, group %d: %s). Do not edit: change the"
            % (source, asset_id, index, g["key"][0]),
            "-- .blend (or its build script) and export again. p: positions in studs, centred on the group (Manifest.lua",
            "-- has its offset); n: normals; c: colours; f: each triangle's 3 positions, 3 normals, 3 colours (1-based).",
            "return {",
            "\tp = %s," % lua_list(flat_p, 2),
            "\tn = %s," % lua_list(flat_n, 2),
            "\tc = %s," % lua_list(flat_c),
            "\tf = %s," % lua_list(flat_f),
            "}",
        ]
        text = "\n".join(lines) + "\n"
        assert len(text) < 199000, "%s group %d is %d characters: lower MAX_TRIS" % (asset_id, index, len(text))
        with open(os.path.join(folder, "%d.lua" % index), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    return folder


def group_objects(asset_id, groups, packed):
    """Builds one temporary object per group (for the FBX/glTF files)."""
    objs = []
    for gi, (g, pk) in enumerate(zip(groups, packed)):
        rbx, tint, alpha, glow = g["key"]
        verts = [Vector((p.x + pk["offset"].x, -(p.z + pk["offset"].z), p.y + pk["offset"].y)) for p in pk["pos"]]
        faces = [tuple(f[0:3]) for f in pk["faces"]]
        me = bpy.data.meshes.new("%s_%d_%s" % (asset_id, gi + 1, rbx))
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.update()
        me.materials.append(lgkit.material(g["libs"][0]))
        me.polygons.foreach_set("use_smooth", [True] * len(faces))
        loop_normals, loop_colors = [], []
        for f in pk["faces"]:
            for k in range(3):
                n = pk["nrm"][f[3 + k]]
                loop_normals.append((n[0], -n[2], n[1]))
                c = pk["col"][f[6 + k]]
                loop_colors += (c[0] / 255, c[1] / 255, c[2] / 255, 1.0)
        attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        attr.data.foreach_set("color_srgb", loop_colors)
        me.color_attributes.active_color = attr
        me.normals_split_custom_set(loop_normals)
        obj = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(obj)
        objs.append(obj)
    return objs


def scrub_paths(path):
    """Blender's FBX writer records the .blend's absolute path (a machine's folders, its user name): replace it, in
    place and at the same length (FBX strings are length-prefixed), with the path inside the repository."""
    if not bpy.data.filepath:
        return
    absolute = os.path.abspath(bpy.data.filepath).encode("utf-8")
    relative = rel(bpy.data.filepath).encode("utf-8")
    with open(path, "rb") as handle:
        data = handle.read()
    for variant in (absolute, absolute.replace(b"\\", b"/")):
        if variant in data and len(relative) <= len(variant):
            data = data.replace(variant, relative + b" " * (len(variant) - len(relative)))
    with open(path, "wb") as handle:
        handle.write(data)


def export_files(asset_id, set_name, groups, packed):
    out_dir = os.path.join(lgkit.ART, "exports", set_name)
    os.makedirs(out_dir, exist_ok=True)
    objs = group_objects(asset_id, groups, packed)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    fbx = os.path.join(out_dir, asset_id + ".fbx")
    glb = os.path.join(out_dir, asset_id + ".glb")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="OFF",
        colors_type="SRGB",
        add_leaf_bones=False,
        bake_anim=False,
    )
    scrub_paths(fbx)
    try:
        bpy.ops.export_scene.gltf(
            filepath=glb,
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_vertex_color="ACTIVE",
            export_animations=False,
        )
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_yup=True)
    for o in objs:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    return fbx, glb


def export_asset(obj, set_name, source):
    asset_id = obj.get("lg_id") or obj.name[3:]
    groups = split_groups(asset_groups(obj))
    packed = [pack(g) for g in groups]
    solids, lights, texts = helpers(obj)
    lua = write_mesh_module(asset_id, set_name, source, packed, groups)
    fbx, glb = export_files(asset_id, set_name, groups, packed)
    lo = Vector((math.inf, math.inf, math.inf))
    hi = -lo
    for pk in packed:
        lo = Vector((min(lo[i], pk["offset"][i] - pk["size"][i] / 2) for i in range(3)))
        hi = Vector((max(hi[i], pk["offset"][i] + pk["size"][i] / 2) for i in range(3)))
    entry = {
        "set": set_name,
        "source": source,
        "object": obj.name,
        "data": rel(lua),
        "exports": [rel(fbx), rel(glb)],
        "size": [round(hi[i] - lo[i], 2) for i in range(3)],
        "tris": sum(len(pk["faces"]) for pk in packed),
        "verts": sum(len(pk["pos"]) for pk in packed),
        "motion": obj.get("lg_motion", ""),
        "groups": [],
        "solids": solids,
        "lights": lights,
        "texts": texts,
    }
    for g, pk in zip(groups, packed):
        rbx, tint, alpha, glow = g["key"]
        digest = hashlib.sha1(
            json.dumps([[list(p) for p in pk["pos"]], pk["nrm"], pk["col"], pk["faces"]], separators=(",", ":"))
            .encode("utf-8")
        ).hexdigest()[:12]
        entry["groups"].append(
            {
                "material": rbx,
                "tint": tint,
                "alpha": alpha,
                "glow": glow,
                "library": g["libs"],
                "offset": [round(pk["offset"][i], 3) for i in range(3)],
                "size": [round(pk["size"][i], 3) for i in range(3)],
                "tris": len(pk["faces"]),
                "verts": len(pk["pos"]),
                "hash": digest,
                # Filled in by a human after uploading this group's object from the .fbx (see art/README.md).
                "assetId": None,
                "uploadedHash": None,
            }
        )
    return asset_id, entry


def export_layout(col):
    """A LAYOUT_<Set> collection: instances of assets (objects sharing an SM_ mesh) and HIDE_ boxes."""
    set_name = col.name[len("LAYOUT_") :]
    anchor = col.get("lg_anchor", (0, 0, 0))
    items, hides, solids = [], [], []
    for obj in sorted(col.all_objects, key=lambda o: (o.get("lg_order", 1e9), o.name)):
        m = obj.matrix_world
        loc, rot, scale = m.decompose()
        r = A @ rot.to_matrix() @ A.transposed()
        p = to_rbx(loc)
        rows = [r[i][j] for i in range(3) for j in range(3)]
        if obj.type == "MESH" and obj.data.name.startswith("SM_"):
            asset_id = obj.data.name[3:]
            items.append(
                {
                    "asset": asset_id,
                    "cf": [p.x, p.y, p.z] + rows,
                    "scale": [abs(scale.x), abs(scale.z), abs(scale.y)],
                    "motion": obj.get("lg_motion", ""),
                    "phase": float(obj.get("lg_phase", 0.0)),
                }
            )
        elif obj.name.startswith("HIDE_"):
            hides.append(
                {
                    "asset": obj.get("asset", ""),
                    "label": obj.name[5:],
                    "names": [n.strip() for n in obj.get("names", "").split(",") if n.strip()],
                    "cf": [p.x, p.y, p.z] + rows,
                    "size": [abs(scale.x) * 2, abs(scale.z) * 2, abs(scale.y) * 2],
                }
            )
        elif obj.name.startswith("SOLID_"):
            solids.append({"cf": [p.x, p.y, p.z] + rows, "size": [abs(scale.x) * 2, abs(scale.z) * 2, abs(scale.y) * 2]})
    lines = [
        "-- Generated by art/blender/scripts/lgexport.py from the LAYOUT_%s collection of %s. Do not edit: move things"
        % (set_name, rel(bpy.data.filepath) if bpy.data.filepath else "?"),
        "-- in Blender and export again. cf: position then rotation rows (relative to anchor); scale per axis;",
        "-- hides: V10 parts (by name, inside the box) this layout replaces; solids: extra client collision boxes.",
        "return {",
        "\tset = %s," % json.dumps(set_name),
        "\tanchor = %s," % lua_list(list(anchor), 2),
        "\titems = {",
    ]
    for it in items:
        extra = ""
        if it["motion"]:
            extra = ", motion = %s, phase = %s" % (json.dumps(it["motion"]), num(it["phase"], 2))
        lines.append(
            "\t\t{ asset = %s, cf = %s, scale = %s%s },"
            % (json.dumps(it["asset"]), lua_list(it["cf"], 3), lua_list(it["scale"], 3), extra)
        )
    lines.append("\t},")
    lines.append("\thides = {")
    for h in hides:
        lines.append(
            "\t\t{ label = %s,%s names = { %s }, cf = %s, size = %s },"
            % (
                json.dumps(h["label"]),
                (" asset = %s," % json.dumps(h["asset"])) if h["asset"] else "",
                ", ".join(json.dumps(n) for n in h["names"]),
                lua_list(h["cf"], 3),
                lua_list(h["size"], 2),
            )
        )
    lines.append("\t},")
    lines.append("\tsolids = {")
    for s in solids:
        lines.append("\t\t{ cf = %s, size = %s }," % (lua_list(s["cf"], 3), lua_list(s["size"], 2)))
    lines.append("\t},")
    lines.append("}")
    path = os.path.join(LUA_ROOT, "Layouts", set_name + ".lua")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    return set_name, len(items), len(hides)


# --------------------------------------------------------------------------------------------------------------------
# The manifest


def load_manifest():
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as handle:
            return json.load(handle)
    return {"version": 1, "assets": {}}


def merge_entry(manifest, asset_id, entry):
    """Keeps a human's uploaded asset ids across re-exports (matched by group position and material)."""
    old = manifest["assets"].get(asset_id)
    if old:
        for i, g in enumerate(entry["groups"]):
            if i < len(old.get("groups", [])):
                og = old["groups"][i]
                if og.get("material") == g["material"] and og.get("assetId"):
                    g["assetId"] = og["assetId"]
                    g["uploadedHash"] = og.get("uploadedHash")
    manifest["assets"][asset_id] = entry


def write_manifest(manifest):
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    manifest["assets"] = dict(sorted(manifest["assets"].items()))
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=1)
        handle.write("\n")
    lines = [
        "-- Generated by art/blender/scripts/lgexport.py from art/manifest/assets.json. Do not edit: the JSON is the",
        "-- source (a human records uploaded Roblox asset ids there; see art/README.md).",
        "-- Each asset: its set, size in studs, triangle and vertex budget, and its groups (one MeshPart each): the",
        "-- Roblox material, paint role, transparency, offset/size inside the asset, and an uploaded mesh id when a",
        "-- current one exists (otherwise the game builds the group from Meshes/<asset>.lua).",
        "return {",
    ]
    for asset_id, e in manifest["assets"].items():
        lines.append("\t%s = {" % asset_id)
        lines.append("\t\tset = %s," % json.dumps(e["set"]))
        lines.append("\t\tsize = %s," % lua_list(e["size"], 2))
        lines.append("\t\ttris = %d," % e["tris"])
        lines.append("\t\tverts = %d," % e["verts"])
        if e.get("motion"):
            lines.append("\t\tmotion = %s," % json.dumps(e["motion"]))
        lines.append("\t\tgroups = {")
        for g in e["groups"]:
            uploaded = g.get("assetId") if g.get("assetId") and g.get("uploadedHash") == g["hash"] else None
            parts = [
                "material = %s" % json.dumps(g["material"]),
                "offset = %s" % lua_list(g["offset"], 3),
                "size = %s" % lua_list(g["size"], 3),
            ]
            if g.get("tint"):
                parts.append("tint = %s" % json.dumps(g["tint"]))
            if g.get("alpha"):
                parts.append("alpha = %s" % num(g["alpha"], 2))
            if g.get("glow"):
                parts.append("glow = true")
            if uploaded:
                parts.append("assetId = %s" % json.dumps(uploaded))
            lines.append("\t\t\t{ %s }," % ", ".join(parts))
        lines.append("\t\t},")
        if e.get("solids"):
            lines.append("\t\tsolids = {")
            for s in e["solids"]:
                lines.append("\t\t\t{ cf = %s, size = %s }," % (lua_list(s["cf"], 3), lua_list(s["size"], 2)))
            lines.append("\t\t},")
        if e.get("texts"):
            lines.append("		texts = {")
            for tx in e["texts"]:
                lines.append(
                    "			{ cf = %s, size = %s, text = %s, color = %s%s },"
                    % (lua_list(tx["cf"], 3), lua_list(tx["size"], 2), json.dumps(tx["text"]), lua_list(tx["color"]), ", double = true" if tx["double"] else "")
                )
            lines.append("		},")
        if e.get("lights"):
            lines.append("\t\tlights = {")
            for li in e["lights"]:
                lines.append(
                    "\t\t\t{ pos = %s, color = %s, range = %s, brightness = %s },"
                    % (lua_list(li["pos"], 2), lua_list(li["color"]), num(li["range"], 1), num(li["brightness"], 2))
                )
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    path = os.path.join(LUA_ROOT, "Manifest.lua")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def export_file(set_name=None):
    """Exports every asset and layout in the open .blend."""
    source = rel(bpy.data.filepath) if bpy.data.filepath else "(unsaved)"
    bpy.context.view_layer.update()  # world matrices of objects made this session
    manifest = load_manifest()
    count = 0
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith("SM_") and obj.data.name == obj.name:
            asset_id, entry = export_asset(obj, set_name or obj.get("lg_set", "Misc"), source)
            merge_entry(manifest, asset_id, entry)
            count += 1
            print("[lgexport] %-28s %5d tris %5d verts %d groups" % (asset_id, entry["tris"], entry["verts"], len(entry["groups"])))
    for col in bpy.data.collections:
        if col.name.startswith("LAYOUT_"):
            name, n, h = export_layout(col)
            print("[lgexport] layout %s: %d items, %d hides" % (name, n, h))
    write_manifest(manifest)
    lgkit.write_library(os.path.join(lgkit.ART, "manifest", "materials.json"), os.path.join(lgkit.ART, "textures", "LG_MaterialSwatches.png"))
    print("[lgexport] %d assets from %s" % (count, source))


if __name__ == "__main__":
    export_file()

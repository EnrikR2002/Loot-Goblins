"""Composing a set in Blender (V14): placing asset instances, HIDE_ boxes and SOLID_ boxes in a LAYOUT_<Set>
collection, in the game's own coordinates.

Positions here are Roblox coordinates relative to the layout's anchor (X east, Y up, Z south: north is -Z, like the
sea). Blender gets (X, -Z, Y). `face` is the compass direction an asset's front should look, as a Roblox (dx, dz).
"""

import math

import bpy
from mathutils import Euler, Matrix, Vector

import lgkit as K


def to_blender(x, y, z):
    return Vector((x, -z, y))


def yaw_for(face):
    """Blender Z rotation (radians) that turns an asset's front (Blender +Y) to look along the Roblox (dx, dz)."""
    bx, by = face[0], -face[1]
    return math.atan2(-bx, by)


class Layout:
    def __init__(self, set_name, anchor):
        self.set = set_name
        self.col = K.collection("LAYOUT_" + set_name)
        self.col["lg_anchor"] = list(anchor)
        self.assets = {}
        self.count = {}

    def register(self, obj):
        self.assets[obj["lg_id"]] = obj

    def put(self, asset_id, x, y, z, face=(0, -1), scale=1.0, tilt=(0.0, 0.0), motion="", phase=0.0):
        """An instance of an asset (linked mesh) at Roblox (x, y, z) relative to the anchor, its front facing `face`.
        scale: a number or (sx, sy, sz) in the asset's own axes (Roblox order); tilt: small lean in degrees."""
        src = self.assets[asset_id]
        n = self.count.get(asset_id, 0) + 1
        self.count[asset_id] = n
        obj = bpy.data.objects.new("%s.%03d" % (asset_id, n), src.data)
        obj.location = to_blender(x, y, z)
        obj.rotation_euler = Euler((math.radians(tilt[0]), math.radians(tilt[1]), yaw_for(face)), "XYZ")
        if isinstance(scale, (int, float)):
            obj.scale = (scale, scale, scale)
        else:
            obj.scale = (scale[0], scale[2], scale[1])
        obj["lg_order"] = sum(self.count.values())  # the game builds a layout in the order it was composed
        if motion:
            obj["lg_motion"] = motion
            obj["lg_phase"] = phase
        self.col.objects.link(obj)
        return obj

    def along(self, asset_id, points, spacing, y, face_side=1, length=None, offset=0.0, scale=1.0):
        """Instances along a polyline of Roblox (x, z) points, each turned along its segment; face_side picks which
        side of the line the asset's front (Blender +Y... its 'right' when walking the line) looks to."""
        out = []
        for (ax, az), (bx, bz) in zip(points, points[1:]):
            dx, dz = bx - ax, bz - az
            seg = math.hypot(dx, dz)
            ux, uz = dx / seg, dz / seg
            d = offset + spacing / 2
            while d <= seg - spacing / 2 + 0.01:
                x, z = ax + ux * d, az + uz * d
                yy = y(x, z) if callable(y) else y
                # the asset's +X runs along the line, its front (+Y) to the side
                side = (uz * face_side, -ux * face_side)
                out.append(self.put(asset_id, x, yy, z, face=side, scale=scale))
                d += spacing
        return out

    def hide(self, label, names, x, y, z, sx, sy, sz, yaw=0.0, asset=None):
        """V10/V13 parts with these names inside this box are hidden on V14 clients (their collision stays), once
        `asset` (what replaces them) has been built there."""
        e = bpy.data.objects.new("HIDE_" + label, None)
        if asset:
            e["asset"] = asset
        e.empty_display_type = "CUBE"
        e.location = to_blender(x, y, z)
        e.rotation_euler = (0, 0, math.radians(yaw))
        e.scale = (sx / 2, sz / 2, sy / 2)
        e["names"] = ",".join(names)
        self.col.objects.link(e)
        return e

    def solid(self, x, y, z, sx, sy, sz, face=(0, -1)):
        """A collision box (Roblox size sx, sy, sz in its own axes) only V14 clients have, e.g. under a boardwalk."""
        e = bpy.data.objects.new("SOLID_%d" % len([o for o in self.col.objects if o.name.startswith("SOLID_")]), None)
        e.empty_display_type = "CUBE"
        e.location = to_blender(x, y, z)
        e.rotation_euler = (0, 0, yaw_for(face))
        e.scale = (sx / 2, sz / 2, sy / 2)
        self.col.objects.link(e)
        return e

    def ground_ref(self, ground, x0, x1, z0, z1, step=4.0):
        """A reference mesh of the captured terrain (not exported) to compose against in Blender."""
        verts, faces = [], []
        xs = [x0 + i * step for i in range(int((x1 - x0) / step) + 1)]
        zs = [z0 + j * step for j in range(int((z1 - z0) / step) + 1)]
        for z in zs:
            for x in xs:
                verts.append(tuple(to_blender(x, max(ground.height(x, z), -2.0), z)))
        w = len(xs)
        for j in range(len(zs) - 1):
            for i in range(w - 1):
                a = j * w + i
                faces.append((a, a + w, a + w + 1, a + 1))
        me = bpy.data.meshes.new("REF_Ground_" + self.set)
        me.from_pydata(verts, [], faces)
        me.update()
        obj = bpy.data.objects.new("REF_Ground_" + self.set, me)
        ref = K.collection("REF_" + self.set)
        ref.objects.link(obj)
        sea = bpy.data.meshes.new("REF_Sea_" + self.set)
        c = [to_blender(x0, 0, z0), to_blender(x1, 0, z0), to_blender(x1, 0, z1), to_blender(x0, 0, z1)]
        sea.from_pydata([tuple(v) for v in c], [], [(0, 1, 2, 3)])
        sea.update()
        sea_obj = bpy.data.objects.new("REF_Sea_" + self.set, sea)
        ref.objects.link(sea_obj)
        return obj, sea_obj


def matrix_of(obj):
    return obj.matrix_world.copy() if obj else Matrix()

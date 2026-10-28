"""Ground heights captured from the game (art/references/*_ground.txt): where the terrain is, so a layout composed in
Blender stands on the real ground. Each file is a grid of downward ray hits made in Studio (see art/README.md,
"Capturing the ground"); a token is <height><material>[^<height of something built on top>]."""

import os
import re

import lgkit as K

_TOKEN = re.compile(r"(-?\d+\.\d)([A-Z\-\?])(\^(-?\d+\.\d)d?)?")


class Ground:
    def __init__(self, name):
        path = os.path.join(K.ART, "references", name)
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
        head = lines[0].split()
        # "anchor <x> <z> step <s> x <x0>..<x1> z <z0>..<z1>"
        self.anchor = (float(head[1]), float(head[2]))
        self.step = float(head[4])
        self.x0, self.x1 = (float(v) for v in head[6].split(".."))
        self.z0, self.z1 = (float(v) for v in head[8].split(".."))
        self.h, self.mat, self.built = [], [], []
        for row in lines[1:]:
            hs, ms, bs = [], [], []
            for tok in row.split(" "):
                m = _TOKEN.match(tok)
                hs.append(float(m.group(1)))
                ms.append(m.group(2))
                bs.append(float(m.group(4)) if m.group(4) else None)
            self.h.append(hs)
            self.mat.append(ms)
            self.built.append(bs)

    def _cell(self, x, z):
        fx = (x - self.x0) / self.step
        fz = (z - self.z0) / self.step
        i = max(0, min(len(self.h[0]) - 2, int(fx)))
        j = max(0, min(len(self.h) - 2, int(fz)))
        return i, j, fx - i, fz - j

    def height(self, x, z):
        """Terrain height (Roblox Y) at a point relative to the anchor (Roblox X, Z), bilinear."""
        i, j, u, v = self._cell(x, z)
        h = self.h
        a = h[j][i] * (1 - u) + h[j][i + 1] * u
        b = h[j + 1][i] * (1 - u) + h[j + 1][i + 1] * u
        return a * (1 - v) + b * v

    def material(self, x, z):
        i, j, u, v = self._cell(x, z)
        return self.mat[j + (1 if v > 0.5 else 0)][i + (1 if u > 0.5 else 0)]

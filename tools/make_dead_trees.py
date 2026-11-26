#!/usr/bin/env python3
"""Builds the dead trees of the graveyard woods (assets/graveyard/tree_dead_*.gltf) and their bark.

Each tree is grown from a seed: a gnarled trunk with a flared foot and a few roots, limbs that fork
into branches, sub-branches and thin twigs with pointed tips, some of them snapped off. The bark is a
tileable grey-brown PNG with deep fissures, ridges, dark crevices and a little lichen (assets/graveyard/
dead_bark.png). Low saturation on purpose: tree.gdshader treats saturated texels as leaves.

Usage: python3 tools/make_dead_trees.py [--preview DIR]
"""
import json, math, os, struct, sys
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "graveyard")
TEX = "dead_bark.png"
TEX_SIZE = 256


# ---------------------------------------------------------------- bark texture
def _noise(rng, shape, cells):
    """Tileable value noise, cells=(cy, cx) lattice points, smooth-interpolated up to shape."""
    g = rng.random(cells)
    ys = np.linspace(0, cells[0], shape[0], endpoint=False)
    xs = np.linspace(0, cells[1], shape[1], endpoint=False)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cells[0]; x1 = (x0 + 1) % cells[1]
    a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x1)]; c = g[np.ix_(y1, x0)]; d = g[np.ix_(y1, x1)]
    fy = fy[:, None]; fx = fx[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def make_bark(seed=7):
    rng = np.random.default_rng(seed)
    n = TEX_SIZE
    # Stretched along v (rows): long vertical fissures.
    ridge = np.zeros((n, n))
    amp = 1.0
    for cy, cx in ((4, 16), (8, 32), (16, 64)):
        ridge += amp * _noise(rng, (n, n), (cy, cx)); amp *= 0.55
    ridge /= 1.0 + 0.55 + 0.3
    # Fissures: where the noise crosses a level, thin dark valleys.
    valley = 1.0 - np.clip(np.abs(ridge - 0.5) * 9.0, 0, 1)
    fine = _noise(rng, (n, n), (64, 64))
    fine2 = _noise(rng, (n, n), (32, 128))
    plates = _noise(rng, (n, n), (6, 24))
    lichen = np.clip((_noise(rng, (n, n), (5, 5)) - 0.62) * 6.0, 0, 1)
    moss = np.clip((_noise(rng, (n, n), (3, 6)) - 0.7) * 6.0, 0, 1)
    light = 0.62 + 0.5 * (ridge - 0.5) + 0.18 * (fine - 0.5) + 0.12 * (fine2 - 0.5) + 0.1 * (plates - 0.5)
    light *= 1.0 - 0.72 * valley ** 1.5
    # Grey-brown wood, weathered; warmer in the ridges, cooler grey in the plates.
    warm = np.stack([0.50, 0.40, 0.31])
    cool = np.stack([0.44, 0.42, 0.38])
    mix = np.clip(0.5 + (plates - 0.5) * 1.6, 0, 1)[..., None]
    col = (warm * (1 - mix) + cool * mix) * (light[..., None] * 1.9)
    col = col * (1 - 0.5 * lichen[..., None]) + np.array([0.52, 0.55, 0.42]) * (0.5 + 0.4 * fine[..., None]) * 0.5 * lichen[..., None]
    col = col * (1 - 0.35 * moss[..., None]) + np.array([0.28, 0.36, 0.16]) * 0.35 * moss[..., None]
    return Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- tree skeleton
def unit(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else np.array([0, 1.0, 0])


def perp(d):
    a = np.array([1.0, 0, 0]) if abs(d[0]) < 0.9 else np.array([0, 0, 1.0])
    p = unit(np.cross(d, a))
    return p, np.cross(d, p)


class Tree:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)
        self.tubes = []  # (points Nx3, radii N, sides, bumpy)

    def limb(self, start, direction, length, r0, depth, max_depth, droop=0.0, snapped=False, sides=None):
        """Grows one limb as a wobbling path and forks off children along it."""
        rng = self.rng
        steps = max(3, int(length / 0.22 + 2))
        d = unit(direction)
        pts = [np.array(start, float)]
        rad = []
        seg = length / steps
        wob = 0.3 if depth else 0.1
        for i in range(steps):
            d = unit(d + rng.normal(0, wob, 3) * np.array([1, 0.6, 1]) + np.array([0, -droop * seg * 1.2, 0]))
            pts.append(pts[-1] + d * seg)
        tip_r = 0.0 if not snapped else r0 * 0.5
        expo = 0.55 if depth == 0 else 0.9
        taper = lambda t: r0 * (1 - t) ** expo + tip_r * t  # noqa: E731
        radii = [max(taper(i / steps), 0.012 if depth else 0.07) for i in range(steps + 1)]
        # A snapped limb ends in a jagged, thick stump; others end in a point.
        if snapped:
            radii[-1] = radii[-2] * 0.8
        self.tubes.append((np.array(pts), np.array(radii), sides or (9 if r0 > 0.2 else 6 if r0 > 0.07 else 4), depth < 1))
        if depth >= max_depth:
            return
        kids = {0: 6, 1: 4, 2: 3, 3: 2}.get(depth, 0)
        kids += int(rng.integers(0, 2)) if depth < 2 else 0
        # Forks start about a third of the way up (the trunk, a quarter), spread evenly with a jitter.
        first = 0.32 if depth == 0 else 0.3
        for k in range(kids):
            t = first + (0.82 - first) * (k + rng.random() * 0.6) / max(kids, 1)
            idx = min(int(t * steps), steps)
            at = pts[idx]
            parent_d = unit(pts[min(idx + 1, steps)] - pts[max(idx - 1, 0)])
            ang = rng.random() * math.tau
            p, q = perp(parent_d)
            out = p * math.cos(ang) + q * math.sin(ang)
            spread = rng.uniform(1.1, 1.7) if depth == 0 else rng.uniform(0.6, 1.0)
            nd = unit(parent_d * (1.0 - 0.5 * spread) + out * spread + np.array([0, 0.15 if depth == 0 else -0.05, 0]))
            r_here = radii[idx]
            self.limb(at, nd, length * rng.uniform(0.38, 0.6) * (1 - 0.45 * t) if depth == 0 else length * rng.uniform(0.4, 0.62) * (1 - 0.35 * t), r_here * rng.uniform(0.55, 0.8),
                      depth + 1, max_depth, droop=droop + (0.25 if depth == 0 else 0.1 * depth), snapped=bool(rng.random() < 0.12 and depth >= 1))
        # The tip forks too, so no limb ends as one bare stick.
        if depth >= 1 and not snapped and length > 0.5:
            for _ in range(2):
                ang = rng.random() * math.tau
                p, q = perp(d)
                nd = unit(d + (p * math.cos(ang) + q * math.sin(ang)) * rng.uniform(0.5, 0.9))
                self.limb(pts[-2] if steps > 2 else pts[-1], nd, length * rng.uniform(0.25, 0.4), radii[-2] * 0.6, depth + 1, max_depth, droop=droop)


def grow(kind, seed):
    t = Tree(seed)
    rng = t.rng
    height, base_r, nroots, depth = {"large": (4.5, 0.34, 6, 3), "medium": (3.6, 0.26, 5, 3), "small": (2.5, 0.2, 4, 2)}[kind]
    lean = {"large": 0.05, "medium": 0.1, "small": 0.28}[kind]
    d = unit(np.array([lean, 1.0, lean * 0.4]))
    t.limb(np.array([0, -0.25, 0]), d, height, base_r, 0, depth, droop=0.0)
    # Roots: thick, short, crawling out and down into the ground.
    for i in range(nroots):
        a = (i + rng.random() * 0.7) / nroots * math.tau
        out = np.array([math.cos(a), -0.15, math.sin(a)])
        t.limb(np.array([0, 0.15, 0]), unit(out + np.array([0, 0.9, 0])), base_r * 2.2, base_r * 0.8, 3, 3, droop=0.9, sides=8)
    return t


# ---------------------------------------------------------------- mesh
def build_mesh(tree, bark_scale=1.0):
    P, N, UV, I = [], [], [], []
    rng = np.random.default_rng(1)
    for pts, radii, sides, bumpy in tree.tubes:
        n = len(pts)
        # Frame along the path, carried forward so it doesn't twist.
        dirs = [unit(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]) for i in range(n)]
        p, q = perp(dirs[0])
        base = len(P)
        v = 0.0
        phase = rng.random() * math.tau
        for i in range(n):
            if i:
                v += np.linalg.norm(pts[i] - pts[i - 1])
                p = unit(p - dirs[i] * np.dot(p, dirs[i]))
                q = np.cross(dirs[i], p)
            r = radii[i]
            circ = math.tau * max(radii[0], 0.02) * 0.6 + 0.0
            for s in range(sides + 1):
                a = s / sides * math.tau
                wob = 1.0 + (0.16 * math.sin(a * 3 + phase + i * 1.3) + 0.08 * math.sin(a * 5 + i * 2.1)) * (1 if bumpy else 0.5)
                rr = r * wob
                nrm = p * math.cos(a) + q * math.sin(a)
                P.append(pts[i] + nrm * rr)
                N.append(nrm)
                # u wraps once round; the bark tile is ~1.1 m round and ~1.1 m tall.
                UV.append(((s / sides) * max(1.0, round(r * math.tau / 0.55)), v / 1.1 * bark_scale))
        for i in range(n - 1):
            for s in range(sides):
                a = base + i * (sides + 1) + s
                b = a + 1; c = a + sides + 1; dd = c + 1
                I += [a, c, b, b, c, dd]
        # Cap the tip (point or flat stump) with a fan.
        tip = len(P)
        P.append(pts[-1] + dirs[-1] * (radii[-1] * 0.8 + 0.02)); N.append(dirs[-1]); UV.append((0.5, v / 1.1))
        last = base + (n - 1) * (sides + 1)
        for s in range(sides):
            I += [last + s, tip, last + s + 1] if False else [last + s, last + s + 1, tip]
    return np.array(P, np.float32), np.array(N, np.float32), np.array(UV, np.float32), np.array(I, np.uint32)


def write_gltf(name, mesh):
    P, N, UV, I = mesh
    UV = UV.copy()
    UV[:, 1] = UV[:, 1]  # glTF v runs downward; the texture tiles, so direction doesn't matter
    idx_t = np.uint16 if len(P) < 65535 else np.uint32
    blobs = [P.tobytes(), UV.astype(np.float32).tobytes(), N.tobytes(), I.astype(idx_t).tobytes()]
    with open(os.path.join(OUT, name + ".bin"), "wb") as f:
        for b in blobs:
            f.write(b + b"\0" * (-len(b) % 4))
    offs, o = [], 0
    for b in blobs:
        offs.append(o); o += len(b) + (-len(b) % 4)
    g = {
        "asset": {"generator": "tools/make_dead_trees.py", "version": "2.0"},
        "scene": 0, "scenes": [{"name": "Scene", "nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "materials": [{"name": "DeadBark", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0, "roughnessFactor": 0.9}}],
        "meshes": [{"name": name + "_mesh", "primitives": [{"attributes": {"POSITION": 0, "TEXCOORD_0": 1, "NORMAL": 2}, "indices": 3, "material": 0}]}],
        "textures": [{"sampler": 0, "source": 0}],
        "images": [{"mimeType": "image/png", "name": "dead_bark", "uri": TEX}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(P), "type": "VEC3", "min": P.min(0).tolist(), "max": P.max(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(P), "type": "VEC2"},
            {"bufferView": 2, "componentType": 5126, "count": len(P), "type": "VEC3"},
            {"bufferView": 3, "componentType": 5123 if idx_t is np.uint16 else 5125, "count": len(I), "type": "SCALAR"},
        ],
        "bufferViews": [{"buffer": 0, "byteOffset": offs[i], "byteLength": len(blobs[i]), "target": 34963 if i == 3 else 34962} for i in range(4)],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "buffers": [{"byteLength": o, "uri": name + ".bin"}],
    }
    with open(os.path.join(OUT, name + ".gltf"), "w") as f:
        json.dump(g, f, indent=1)


# ---------------------------------------------------------------- preview (software rasteriser)
def render(meshes_tex, size=(640, 800), yaw=0.5, pitch=0.25, zoom=1.0, offset=(0, 0, 0)):
    mesh, tex = meshes_tex
    P, N, UV, I = mesh
    W, H = size
    cy, sy = math.cos(yaw), math.sin(yaw)
    R = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    cp, sp = math.cos(pitch), math.sin(pitch)
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    M = Rx @ R
    Q = (P + np.array(offset)) @ M.T
    Nn = N @ M.T
    scale = H / 6.2 * zoom
    sx = W / 2 + Q[:, 0] * scale
    sy_ = H * 0.86 - Q[:, 1] * scale
    z = Q[:, 2]
    img = np.zeros((H, W, 3), np.float32); img[:] = [0.30, 0.36, 0.2]
    zb = np.full((H, W), 1e9, np.float32)
    T = np.asarray(tex, np.float32) / 255
    th, tw = T.shape[:2]
    light = unit(np.array([-0.5, 0.8, 0.45]))
    for t in range(0, len(I), 3):
        a, b, c = I[t:t + 3]
        x = sx[[a, b, c]]; y = sy_[[a, b, c]]
        x0, x1 = int(max(x.min(), 0)), int(min(x.max() + 1, W - 1))
        y0, y1 = int(max(y.min(), 0)), int(min(y.max() + 1, H - 1))
        if x1 <= x0 or y1 <= y0:
            continue
        den = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if abs(den) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        l0 = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / den
        l1 = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / den
        l2 = 1 - l0 - l1
        m = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
        if not m.any():
            continue
        zz = l0 * z[a] + l1 * z[b] + l2 * z[c]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        m &= zz < sub
        if not m.any():
            continue
        u = l0 * UV[a, 0] + l1 * UV[b, 0] + l2 * UV[c, 0]
        v = l0 * UV[a, 1] + l1 * UV[b, 1] + l2 * UV[c, 1]
        col = T[(v * th).astype(int) % th, (u * tw).astype(int) % tw]
        nn = l0[..., None] * Nn[a] + l1[..., None] * Nn[b] + l2[..., None] * Nn[c]
        nn /= np.linalg.norm(nn, axis=-1, keepdims=True) + 1e-9
        lam = np.clip((nn @ (light @ M.T)) * 0.6 + 0.55, 0.3, 1.2)
        sub[m] = zz[m]
        img[y0:y1 + 1, x0:x1 + 1][m] = (col * lam[..., None])[m]
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


SEEDS = {"large": 15, "medium": 6, "small": 1}


def main():
    bark = make_bark()
    bark.save(os.path.join(OUT, TEX))
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    sheets = []
    for kind, seed in SEEDS.items():
        mesh = build_mesh(grow(kind, seed))
        write_gltf("tree_dead_" + kind, mesh)
        print(kind, "verts", len(mesh[0]), "tris", len(mesh[3]) // 3, "bounds", mesh[0].min(0).round(2), mesh[0].max(0).round(2))
        if preview:
            sheets.append(render((mesh, bark), size=(360, 460), yaw=0.6))
    if preview:
        os.makedirs(preview, exist_ok=True)
        sheet = Image.new("RGB", (360 * len(sheets), 460))
        for i, s in enumerate(sheets):
            sheet.paste(s, (360 * i, 0))
        sheet.save(os.path.join(preview, "dead_trees_after.png"))


if __name__ == "__main__":
    main()

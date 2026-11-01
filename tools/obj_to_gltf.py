#!/usr/bin/env python3
"""Turns one weapon of the Medieval Weapon Pack (Omie's Assets, CC0) into a
small glTF the game can hold in a hand, like the KayKit weapons.

The pack's meshes stand on their end with the guard across Z and the pommel
at y = 0; the KayKit weapons the hands are made for have the guard across X
and the middle of the grip at the origin. So each mesh is turned a quarter
round the upright axis, moved so the grip sits in the hand, and scaled to the
KayKit size. Only the colour texture is kept, shrunk to a small PNG.

Usage:
  python3 tools/obj_to_gltf.py MESH.obj BASECOLOR.tga OUT_NAME GRIP_Y SCALE [TURN_DEGREES]
Writes assets/weapons/forge/OUT_NAME.gltf, .bin and _texture.png.
"""
import json
import math
import os
import struct
import sys

from PIL import Image

TEXTURE_SIZE = 256
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "weapons", "forge")


def read_obj(path):
    vs, vts, vns, corners = [], [], [], []
    with open(path) as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "v":
                vs.append(tuple(map(float, parts[1:4])))
            elif parts[0] == "vt":
                vts.append(tuple(map(float, parts[1:3])))
            elif parts[0] == "vn":
                vns.append(tuple(map(float, parts[1:4])))
            elif parts[0] == "f":
                face = []
                for c in parts[1:]:
                    idx = (c.split("/") + ["", ""])[:3]
                    face.append(tuple(int(i) - 1 if i else -1 for i in idx))
                for i in range(1, len(face) - 1):  # A fan for quads and more.
                    corners += [face[0], face[i], face[i + 1]]
    return vs, vts, vns, corners


def main():
    obj, tga, name, grip_y, scale = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5])
    turn = math.radians(float(sys.argv[6]) if len(sys.argv) > 6 else 90.0)
    c, s = math.cos(turn), math.sin(turn)
    vs, vts, vns, corners = read_obj(obj)

    def place(v):  # Turn round Y, put the grip at the origin, scale.
        x, y, z = v
        return ((x * c + z * s) * scale, (y - grip_y) * scale, (-x * s + z * c) * scale)

    def turn_normal(n):
        x, y, z = n
        return (x * c + z * s, y, -x * s + z * c)

    unique, indices = {}, []
    pos, nor, uv = [], [], []
    for corner in corners:
        if corner not in unique:
            unique[corner] = len(pos)
            pos.append(place(vs[corner[0]]))
            nor.append(turn_normal(vns[corner[2]]) if corner[2] >= 0 else (0.0, 1.0, 0.0))
            t = vts[corner[1]] if corner[1] >= 0 else (0.0, 0.0)
            uv.append((t[0], 1.0 - t[1]))
        indices.append(unique[corner])

    os.makedirs(OUT_DIR, exist_ok=True)
    blob = bytearray()
    views = []

    def add(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        return len(views) - 1

    flat = lambda rows: [x for r in rows for x in r]
    p_view = add(struct.pack("<%df" % (len(pos) * 3), *flat(pos)), 34962)
    n_view = add(struct.pack("<%df" % (len(nor) * 3), *flat(nor)), 34962)
    t_view = add(struct.pack("<%df" % (len(uv) * 2), *flat(uv)), 34962)
    i_view = add(struct.pack("<%dI" % len(indices), *indices), 34963)
    lo = [min(p[i] for p in pos) for i in range(3)]
    hi = [max(p[i] for p in pos) for i in range(3)]

    Image.open(tga).convert("RGB").resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS).save(
        os.path.join(OUT_DIR, name + "_texture.png"), optimize=True)
    with open(os.path.join(OUT_DIR, name + ".bin"), "wb") as f:
        f.write(blob)
    gltf = {
        "asset": {"generator": "tools/obj_to_gltf.py", "version": "2.0"},
        "scene": 0,
        "scenes": [{"name": "Scene", "nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "materials": [{"name": name, "doubleSided": True,
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987}],
        "images": [{"uri": name + "_texture.png", "name": name + "_texture"}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "accessors": [
            {"bufferView": p_view, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": n_view, "componentType": 5126, "count": len(nor), "type": "VEC3"},
            {"bufferView": t_view, "componentType": 5126, "count": len(uv), "type": "VEC2"},
            {"bufferView": i_view, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
        ],
        "bufferViews": views,
        "buffers": [{"uri": name + ".bin", "byteLength": len(blob)}],
    }
    with open(os.path.join(OUT_DIR, name + ".gltf"), "w") as f:
        json.dump(gltf, f, indent=1)
    print(name, len(pos), "vertices", len(indices) // 3, "triangles", "size", [round(h - l, 2) for l, h in zip(lo, hi)])


if __name__ == "__main__":
    main()

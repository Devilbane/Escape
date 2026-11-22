#!/usr/bin/env python3
"""Compares two sets of lighting reference pictures (see tests/lighting_reference_shots.gd).

    python3 tools/lighting_compare.py <reference folder> <new folder> [<output folder>]

For every picture in both folders it measures how far the new one is from the reference and
prints a table, worst first:

  lum    mean brightness of the new picture relative to the reference (1.00 = the same)
  dE     mean colour distance of the blurred pictures (CIE76 in Lab; under 2 is hard to see,
         over 5 is plain). Blurring first ignores villagers, flames and leaves that moved.
  hue    how far the average colour drifted (Lab a/b distance of the two means)
  dark   brightness ratio of the darkest tenth (shadows), bright: of the brightest tenth (lamps)
  ok     "yes" when the picture matches: dE at most MATCH_DE and lum within MATCH_LUM. Two runs of
         the same renderer differ by about dE 2 (villagers walk, flames flicker), so that is the floor.

With an output folder it also writes <name>.png there: reference left, new right, and
report.json with the numbers. The exit code is 1 when a picture is missing in the new folder.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


MATCH_DE = 4.0
MATCH_LUM = (0.8, 1.25)


def matched(row: dict) -> bool:
    return row["dE"] <= MATCH_DE and MATCH_LUM[0] <= row["lum"] <= MATCH_LUM[1]


def _linear(srgb: np.ndarray) -> np.ndarray:
    c = srgb.astype(np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _lab(srgb: np.ndarray) -> np.ndarray:
    rgb = _linear(srgb)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = rgb @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])], axis=-1)


def _ratio(new: float, ref: float) -> float:
    return (new + 1e-4) / (ref + 1e-4)


def measure(ref: Image.Image, new: Image.Image) -> dict:
    if new.size != ref.size:
        new = new.resize(ref.size, Image.LANCZOS)
    blur = max(ref.size) / 80.0
    a = np.asarray(ref.filter(ImageFilter.GaussianBlur(blur)).convert("RGB"))
    b = np.asarray(new.filter(ImageFilter.GaussianBlur(blur)).convert("RGB"))
    lab_a, lab_b = _lab(a), _lab(b)
    lum_a = _linear(np.asarray(ref.convert("RGB"))) @ np.array([0.2126, 0.7152, 0.0722])
    lum_b = _linear(np.asarray(new.convert("RGB"))) @ np.array([0.2126, 0.7152, 0.0722])
    low_a, high_a = np.percentile(lum_a, [10, 90])
    low_b, high_b = np.percentile(lum_b, [10, 90])
    mean_a, mean_b = lab_a.reshape(-1, 3).mean(0), lab_b.reshape(-1, 3).mean(0)
    return {
        "lum": round(_ratio(lum_b.mean(), lum_a.mean()), 3),
        "dE": round(float(np.sqrt(((lab_a - lab_b) ** 2).sum(-1)).mean()), 2),
        "hue": round(float(np.hypot(mean_a[1] - mean_b[1], mean_a[2] - mean_b[2])), 2),
        "dark": round(_ratio(low_b, low_a), 3),
        "bright": round(_ratio(high_b, high_a), 3),
    }


def side_by_side(ref: Image.Image, new: Image.Image, name: str, labels: tuple) -> Image.Image:
    if new.size != ref.size:
        new = new.resize(ref.size, Image.LANCZOS)
    w, h = ref.size
    out = Image.new("RGB", (w * 2 + 4, h + 22), (24, 24, 24))
    out.paste(ref.convert("RGB"), (0, 22))
    out.paste(new.convert("RGB"), (w + 4, 22))
    draw = ImageDraw.Draw(out)
    draw.text((6, 5), "%s: %s" % (name, labels[0]), fill=(230, 230, 230))
    draw.text((w + 10, 5), labels[1], fill=(230, 230, 230))
    return out


def _label(folder: Path) -> str:
    manifest = folder / "manifest.json"
    if manifest.exists():
        data = json.loads(manifest.read_text())
        return "%s (%s)" % (data.get("method", "?"), data.get("driver", "?"))
    return folder.name


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    ref_dir, new_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else None
    if out_dir:
        out_dir.mkdir(parents=True, exist_ok=True)
    labels = (_label(ref_dir), _label(new_dir))
    rows, missing = [], []
    for ref_path in sorted(ref_dir.glob("*.png")):
        new_path = new_dir / ref_path.name
        if not new_path.exists():
            missing.append(ref_path.stem)
            continue
        ref, new = Image.open(ref_path), Image.open(new_path)
        row = {"name": ref_path.stem, **measure(ref, new)}
        rows.append(row)
        if out_dir:
            side_by_side(ref, new, ref_path.stem, labels).save(out_dir / ref_path.name)
    rows.sort(key=lambda r: -r["dE"])
    print("%-34s %6s %6s %6s %6s %6s  %s" % ("shot", "lum", "dE", "hue", "dark", "bright", "ok"))
    for r in rows:
        r["ok"] = bool(matched(r))
        print("%-34s %6.2f %6.2f %6.2f %6.2f %6.2f  %s" % (r["name"], r["lum"], r["dE"], r["hue"], r["dark"], r["bright"], "yes" if r["ok"] else "-"))
    if rows:
        print("%-34s %6.2f %6.2f" % ("mean of %d" % len(rows), float(np.mean([r["lum"] for r in rows])), float(np.mean([r["dE"] for r in rows]))))
        print("matched %d of %d" % (sum(1 for r in rows if r["ok"]), len(rows) + len(missing)))
    for name in missing:
        print("MISSING in %s: %s" % (new_dir, name))
    if out_dir:
        (out_dir / "report.json").write_text(json.dumps({"reference": labels[0], "new": labels[1], "shots": rows, "missing": missing}, indent="\t"))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())

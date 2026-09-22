#!/usr/bin/env python3
"""Lighting contrast report for a capture directory.

Three numbers decide whether a frame is lit or merely bright:

  contrast    brightest / darkest ground, ignoring the extreme 2% each way.
              Mid-morning Libyan sun on concrete is 4:1 to 6:1. Below 2:1
              means ambient is drowning the key and no normal map, no
              modelling and no form will read no matter how good the mesh is.

  shadow%     fraction of world pixels below 0.25. A lit exterior wants
              8-18%. Near zero means nothing in frame is in shade.

  clip%       fraction above 0.98. Above ~2% the highlights are gone and
              the grade has nowhere left to go.

Usage: tools/light_report.py captures/<dir> [more dirs...]
"""
import sys, os, glob
from PIL import Image

SKY_ROWS = 150      # skip sky and the HUD block
GROUND_FROM = 0.76  # ground band as a fraction of frame height


def report(path):
    pngs = sorted(glob.glob(os.path.join(path, "*.png")))
    if not pngs:
        print(f"{path}: no frames")
        return
    print(f"\n{path}")
    print(f"  {'frame':<10}{'contrast':>9}{'shadow%':>9}{'clip%':>8}{'median':>8}")
    agg = []
    for p in pngs:
        im = Image.open(p).convert("RGB")
        px = im.load()
        w, h = im.size
        ground, world = [], []
        for y in range(SKY_ROWS, h, 3):
            for x in range(0, w, 3):
                r, g, b = px[x, y]
                # Rec.709 luminance, NOT max(r,g,b). The first version of this
                # tool used the max channel and reported Brega's warm sunset at
                # a median of 0.965 — it was measuring the red channel of an
                # orange image, not its brightness, and would have sent every
                # warm level chasing an exposure problem it did not have.
                v = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                world.append(v)
                if y > h * GROUND_FROM:
                    ground.append(v)
        ground.sort()
        world.sort()
        n, m = len(ground), len(world)
        lo = ground[n * 2 // 100]
        hi = ground[n * 98 // 100]
        contrast = hi / max(lo, 1e-4)
        shadow = sum(1 for v in world if v < 0.25) / m * 100.0
        clip = sum(1 for v in world if v > 0.98) / m * 100.0
        median = world[m // 2]
        agg.append((contrast, shadow, clip, median))
        print(f"  {os.path.basename(p):<10}{contrast:>9.2f}{shadow:>9.1f}{clip:>8.1f}{median:>8.3f}")
    k = len(agg)
    c, s, cl, md = (sum(a[i] for a in agg) / k for i in range(4))
    flags = []
    if c < 2.0:
        flags.append("FLAT - ambient is drowning the key")
    elif c > 9.0:
        flags.append("HARSH - shadows are crushing")
    if s < 4.0:
        flags.append("no real shadow in frame")
    if cl > 2.5:
        flags.append("highlights clipping")
    print(f"  {'MEAN':<10}{c:>9.2f}{s:>9.1f}{cl:>8.1f}{md:>8.3f}"
          + ("   <- " + "; ".join(flags) if flags else "   ok"))


if __name__ == "__main__":
    for d in sys.argv[1:] or ["captures"]:
        report(d)

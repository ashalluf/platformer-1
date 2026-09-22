#!/usr/bin/env python3
"""Compare a capture's colour statistics against the reference art.

The art direction is a set of numbers, not a feeling: the reference frames run
mean saturation 0.55-0.61 with 78-91% of pixels above S 0.35, and 96-99% of
their saturated pixels inside hue 0-60. Eyeballing a capture cannot tell you
which of those you missed. This can.

    python3 tools/colour_report.py captures/port4/0068.png [more.png ...]
"""
import sys, colorsys, collections
from PIL import Image

TARGET = {"sat": (0.55, 0.61), "hi_sat": (0.78, 0.91), "warm": (0.96, 0.99)}


def stats(path):
    im = Image.open(path).convert("RGB")
    im.thumbnail((400, 400))
    px = list(im.getdata())
    sats, vals, warm, hi = [], [], 0, 0
    for r, g, b in px:
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        sats.append(s)
        vals.append(v)
        if s > 0.15:
            warm += 1 if (h * 360 <= 60 or h * 360 >= 330) else 0
            hi += 1
    n = len(px)
    return {
        "sat": sum(sats) / n,
        "val": sum(vals) / n,
        "hi_sat": sum(1 for s in sats if s > 0.35) / n,
        "bright": sum(1 for v in vals if v > 0.85) / n,
        "warm": warm / max(hi, 1),
    }


def verdict(key, got):
    lo, hi = TARGET[key]
    if got < lo:
        return f"LOW  (target {lo:.2f}-{hi:.2f})"
    if got > hi:
        return f"HIGH (target {lo:.2f}-{hi:.2f})"
    return f"ok   (target {lo:.2f}-{hi:.2f})"


for path in sys.argv[1:]:
    s = stats(path)
    print(f"\n{path}")
    print(f"  saturation   {s['sat']:.3f}  {verdict('sat', s['sat'])}")
    print(f"  S>0.35       {s['hi_sat']:.1%}  {verdict('hi_sat', s['hi_sat'])}")
    print(f"  warm hue     {s['warm']:.1%}  {verdict('warm', s['warm'])}")
    print(f"  value        {s['val']:.3f}   (port 0.674, yard 0.397)")
    print(f"  V>0.85       {s['bright']:.1%}   (port 53%, yard 6%)")

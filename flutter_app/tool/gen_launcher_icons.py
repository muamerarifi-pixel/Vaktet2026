#!/usr/bin/env python3
"""Draws the Android launcher icons (needs Pillow):  python3 tool/gen_launcher_icons.py

The icon is an upright crescent, mirror-symmetric top to bottom and centred, on the app's green.
It has the proportions of the web app's crescent (outer circle 11, inner circle 12.5, sharing the two horn tips),
but upright instead of tilted. crescent = outer disc minus inner disc.

Writes into android/app/src/main/res:
  mipmap-*/ic_launcher_foreground.png   adaptive icon foreground (108dp canvas), crescent only
  mipmap-*/ic_launcher.png              icon for Android 7 and older (rounded square, transparent corners)
"""
import math
import pathlib

from PIL import Image, ImageChops, ImageDraw

RES = pathlib.Path(__file__).resolve().parent.parent / "android/app/src/main/res"
BG = (0x1D, 0x5E, 0x50)  # the app's green
FG = (0xF4, 0xF8, 0xF6)  # the crescent's off-white

# ---- Geometry, in "units" (outer circle radius = 11) ----
R, r = 11.0, 12.5
HALF_CHORD_SQ = 101.16  # (half the distance between the horn tips)^2, as in the web icon
D = math.sqrt(R * R - HALF_CHORD_SQ) + math.sqrt(r * r - HALF_CHORD_SQ)  # distance between the circle centres
X_TIP = (D * D + R * R - r * r) / (2 * D)  # x of the horn tips, from the outer circle's centre
BBOX_CENTRE_X = (-R + X_TIP) / 2  # horizontally the crescent spans [-R, X_TIP]; vertically [-R, R]


def crescent_mask(size, scale, cx, cy, ss=8):
    """Anti-aliased mask: outer circle centre at (cx, cy) px, `scale` px per unit."""
    big = size * ss
    outer = Image.new("L", (big, big), 0)
    inner = Image.new("L", (big, big), 0)
    ox, oy, ix = cx * ss, cy * ss, (cx + D * scale) * ss
    ImageDraw.Draw(outer).ellipse([ox - R * scale * ss, oy - R * scale * ss, ox + R * scale * ss, oy + R * scale * ss], fill=255)
    ImageDraw.Draw(inner).ellipse([ix - r * scale * ss, oy - r * scale * ss, ix + r * scale * ss, oy + r * scale * ss], fill=255)
    return ImageChops.subtract(outer, inner).resize((size, size), Image.LANCZOS)


def area_centroid_x(n=700):
    """Where the crescent's weight is, horizontally (from the outer circle's centre); numerical."""
    sc = n / 40.0
    ox = n / 2 - 6 * sc
    px = crescent_mask(n, sc, ox, n / 2, ss=1).load()
    total = wx = 0
    for y in range(n):
        for x in range(n):
            v = px[x, y]
            total += v
            wx += v * x
    return (wx / total - ox) / sc


# The crescent is thicker on its left, so centre it between its bounding box and its centre of weight.
OPTICAL_CENTRE_X = (BBOX_CENTRE_X + area_centroid_x()) / 2


def centred_mask(size, scale):
    return crescent_mask(size, scale, size / 2 - OPTICAL_CENTRE_X * scale, size / 2)


def adaptive_foreground(density_factor):
    size = round(108 * density_factor)  # the adaptive canvas is 108dp
    scale = 2.0 * density_factor  # 2dp per unit: the crescent is 44dp tall, inside the 66dp safe circle
    img = Image.new("RGBA", (size, size), FG + (0,))
    img.putalpha(centred_mask(size, scale))
    return img


def legacy_icon(size):
    ss = 8
    big = size * ss
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, big - 1, big - 1], radius=round(big * 0.22), fill=BG + (255,))
    img = img.resize((size, size), Image.LANCZOS)
    scale = 0.61 * size / (2 * R)  # the crescent is 61% of the icon's height
    img.alpha_composite(Image.composite(Image.new("RGBA", (size, size), FG + (255,)), Image.new("RGBA", (size, size), (0, 0, 0, 0)), centred_mask(size, scale)))
    return img


if __name__ == "__main__":
    for name, factor in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        adaptive_foreground(factor).save(RES / f"mipmap-{name}/ic_launcher_foreground.png", optimize=True)
        legacy_icon(round(48 * factor)).save(RES / f"mipmap-{name}/ic_launcher.png", optimize=True)
    print("optical centre x = %.3f units (bounding box %.3f, weight %.3f)" % (OPTICAL_CENTRE_X, BBOX_CENTRE_X, area_centroid_x()))

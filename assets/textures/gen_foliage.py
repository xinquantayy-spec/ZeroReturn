#!/usr/bin/env python3
"""Zero Return - foliage card atlas (owner 2026-11-01: "i dont want the leaves totally opaque"). Original synthesis.
One 1024 x 1024 RGBA atlas, four 512 cells, each a branch spray seen from above on a transparent background:
  cell 0 (top left)     spruce spray, dark      cell 1 (top right)    spruce spray, younger and lighter
  cell 2 (bottom left)  birch leaves            cell 3 (bottom right) shrub leaves
The spray fills a lens-shaped envelope from the root (left, u = 0.03) to the tip (right, u = 0.97), widest at 45 %,
matching the plate shape the Blender generator gives every spray (build_nature.py), so the cut-outs follow the plate.
Usage: python3 -I assets/textures/gen_foliage.py <out_dir>
"""
import math, os, sys, random
from PIL import Image, ImageDraw, ImageFilter

N, CELL = 1024, 512


def envelope(f):
    """half-width of the spray (0..1 of the cell's half height) at fraction f of its length; matches build_nature.spray"""
    pts = ((0.0, 0.18), (0.5, 0.8), (1.0, 0.12))
    if f <= 0.5:
        a, b, t = pts[0][1], pts[1][1], f / 0.5
    else:
        a, b, t = pts[1][1], pts[2][1], (f - 0.5) / 0.5
    return (a + (b - a) * t) / 0.8 * 0.92


def cell_xy(c, u, v):
    """cell c, u along the spray 0..1 (root..tip), v across -1..1 -> pixel"""
    ox, oy = (c % 2) * CELL, (c // 2) * CELL
    x = ox + (0.03 + 0.94 * u) * CELL
    y = oy + CELL / 2 - v * (CELL / 2 - 6)
    return x, y


def jitter(col, rnd, k=0.12):
    return tuple(max(0, min(255, int(ch * (1 + rnd.uniform(-k, k))))) for ch in col[:3]) + (255,)


def conifer(d, c, rnd, greens, twig):
    # the main twig, slightly curved
    pts = []
    for i in range(41):
        u = i / 40
        pts.append(cell_xy(c, u, 0.05 * math.sin(u * 3.0)))
    d.line(pts, fill=twig, width=7)
    # side twigs out to the envelope, alternating, close together, angled toward the tip
    twigs = []
    side = 1
    u = 0.04
    while u < 0.93:
        span = envelope(min(1.0, u + 0.08)) * rnd.uniform(0.8, 1.0)
        a = cell_xy(c, u, 0.03 * side)
        b = cell_xy(c, min(0.985, u + span * 0.38), side * span)
        twigs.append((a, b))
        side = -side
        u += rnd.uniform(0.032, 0.044)
    # needles: two passes, long and dark first, then shorter and lighter near the twig tips (new growth)
    for pas in range(2):
        for (a, b) in twigs:
            d.line([a, b], fill=twig, width=3)
            n = 26 if pas == 0 else 12
            for k in range(n):
                t = k / (n - 1)
                if pas == 1:
                    t = 0.55 + 0.45 * t
                px, py = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                for s in (-1, 1):
                    ang = math.atan2(b[1] - a[1], b[0] - a[0]) + s * rnd.uniform(0.45, 1.05)
                    L = rnd.uniform(16, 26) * (1.0 if pas == 0 else 0.7) * (1.0 - 0.35 * t)
                    col = greens[rnd.randrange(len(greens))]
                    if pas == 1:
                        col = tuple(min(255, int(ch * 1.25)) for ch in col)
                    d.line([(px, py), (px + math.cos(ang) * L, py + math.sin(ang) * L)], fill=jitter(col, rnd), width=4 if pas == 0 else 3)
    # needles along the main twig
    for k in range(90):
        u = k / 89 * 0.97
        px, py = cell_xy(c, u, 0.05 * math.sin(u * 3.0))
        for s in (-1, 1):
            ang = s * rnd.uniform(0.4, 1.2)
            L = rnd.uniform(14, 24)
            d.line([(px, py), (px + math.cos(ang) * L, py - math.sin(ang) * L)], fill=jitter(greens[rnd.randrange(len(greens))], rnd), width=4)


def leaf(d, cx, cy, ang, L, W, col, vein):
    # an ovate leaf with a point, as a polygon
    pts = []
    for i in range(14):
        t = i / 13 * math.pi
        r = math.sin(t) ** 0.8
        x = math.cos(t) * L / 2
        y = r * W / 2
        pts.append((x, y))
    pts += [(x, -y) for (x, y) in reversed(pts)]
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for (x, y) in pts]
    d.polygon(poly, fill=col)
    d.line([(cx - ca * L / 2, cy - sa * L / 2), (cx + ca * L / 2, cy + sa * L / 2)], fill=vein, width=1)


def broadleaf(d, c, rnd, greens, twig, size, count):
    # a main twig and short side twigs out to the envelope; leaves sit on short stalks along the side twigs
    pts = [cell_xy(c, u / 30, 0.04 * math.sin(u / 5)) for u in range(31)]
    d.line(pts, fill=twig, width=5)
    twigs = []
    side = 1
    u = 0.05
    while u < 0.92:
        span = envelope(min(1.0, u + 0.06)) * rnd.uniform(0.7, 0.95)
        a = cell_xy(c, u, 0.03 * side)
        b = cell_xy(c, min(0.98, u + span * 0.3), side * span)
        twigs.append((a, b))
        d.line([a, b], fill=twig, width=2)
        side = -side
        u += rnd.uniform(0.06, 0.09)
    per = max(4, count // max(1, len(twigs)))
    for (a, b) in twigs:
        for k in range(per):
            t = rnd.uniform(0.15, 1.0)
            px, py = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            base = math.atan2(b[1] - a[1], b[0] - a[0])
            ang = base + rnd.choice((-1, 1)) * rnd.uniform(0.3, 1.0)
            stalk = rnd.uniform(3, 8)
            x, y = px + math.cos(ang) * (stalk + size * 0.45), py + math.sin(ang) * (stalk + size * 0.45)
            d.line([(px, py), (px + math.cos(ang) * stalk, py + math.sin(ang) * stalk)], fill=twig, width=2)
            col = jitter(greens[rnd.randrange(len(greens))], rnd, 0.16)
            vein = tuple(int(ch * 0.82) for ch in col[:3]) + (255,)
            L = size * rnd.uniform(0.8, 1.25)
            leaf(d, x, y, ang, L, L * rnd.uniform(0.55, 0.75), col, vein)
    # a few leaves on the main twig, toward the tip
    for k in range(10):
        u = rnd.uniform(0.6, 0.98)
        x, y = cell_xy(c, u, rnd.uniform(-0.12, 0.12))
        col = jitter(greens[rnd.randrange(len(greens))], rnd, 0.16)
        leaf(d, x, y, rnd.uniform(-0.8, 0.8), size, size * 0.62, col, tuple(int(ch * 0.82) for ch in col[:3]) + (255,))


def build(out):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(20261101)
    twig = (78, 62, 46, 255)
    conifer(d, 0, rnd, [(46, 66, 40), (52, 74, 44), (40, 58, 36), (58, 80, 48)], twig)
    conifer(d, 1, rnd, [(66, 92, 52), (74, 100, 56), (60, 86, 50), (82, 108, 60)], twig)
    broadleaf(d, 2, rnd, [(96, 118, 54), (108, 128, 60), (88, 110, 50), (118, 134, 64)], (120, 104, 84, 255), 40, 170)
    broadleaf(d, 3, rnd, [(70, 88, 46), (78, 96, 50), (64, 82, 42), (86, 102, 54)], twig, 36, 200)
    # soften the cut edges a little (alpha to coverage reads better at distance)
    a = img.split()[3].filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(a)
    # bleed the colour under the transparent areas (no dark fringes when mip-mapped)
    rgb = img.convert("RGB")
    for _ in range(4):
        rgb = Image.composite(rgb, rgb.filter(ImageFilter.MaxFilter(5)), a.point(lambda x: 255 if x > 8 else 0))
    out_img = rgb.copy()
    out_img.putalpha(a)
    p = os.path.join(out, "ZR_Foliage_Color.png")
    out_img.save(p, optimize=True)
    return p


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    print(build(out))

#!/usr/bin/env python3
"""Zero Return - original procedural UI/post textures (no third-party art).
Usage: python3 assets/textures/gen_textures.py <out_dir>
  ZR_TEX_Grain.png  256x256  animated-by-offset film grain tile (black/white specks, soft clumps)
  ZR_TEX_Lens.png   1024x576 bodycam lens: vignette, chromatic edge fringe, faint dust/smudges
  ZR_TEX_Icons.png  512x128  16 white icons (64px) tinted at runtime via ImageColor3
  ZR_TEX_Glow.png   128x128  soft radial glow (bloom imitation behind HUD numerals)
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

rng = np.random.default_rng(4417)


def grain(path):
    n = 256
    base = rng.standard_normal((n, n))
    clumps = np.array(Image.fromarray(((rng.standard_normal((n // 2, n // 2)) * 40) + 128).clip(0, 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), dtype=float)
    v = base * 0.7 + (clumps - 128) / 40 * 0.5
    white = v > 0
    a = np.clip(np.abs(v) * 46, 0, 120).astype(np.uint8)
    rgb = np.where(white[..., None], 255, 0).astype(np.uint8).repeat(3, axis=2)
    img = np.dstack([rgb, a])
    Image.fromarray(img, "RGBA").save(path)


def lens(path):
    w, h = 1024, 576
    y, x = np.mgrid[0:h, 0:w].astype(float)
    nx, ny = (x / w - 0.5) * 2, (y / h - 0.5) * 2
    r = np.sqrt((nx * 1.0) ** 2 + (ny * 0.92) ** 2)
    vig = np.clip((r - 0.62) / 0.75, 0, 1) ** 1.6
    alpha = vig * 0.88
    rgb = np.zeros((h, w, 3))
    # chromatic fringe: warm on one side of the ring, cold on the other (reads as lens CA at the edges)
    ring = np.exp(-((r - 1.02) / 0.09) ** 2)
    side = np.clip(nx * 0.8 + ny * 0.3, -1, 1)
    warm = ring * np.clip(-side, 0, 1)
    cold = ring * np.clip(side, 0, 1)
    rgb[..., 0] += warm * 255 * 0.32
    rgb[..., 1] += cold * 170 * 0.32
    rgb[..., 2] += cold * 255 * 0.32
    alpha = np.maximum(alpha, (warm + cold) * 0.06)
    img = Image.fromarray(np.dstack([rgb.clip(0, 255), alpha * 255]).astype(np.uint8), "RGBA")
    # dust / smudges: faint, mostly away from the centre
    dust = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(dust)
    for _ in range(14):
        px, py = rng.uniform(0, w), rng.uniform(0, h)
        if abs(px / w - 0.5) < 0.22 and abs(py / h - 0.5) < 0.22:
            continue
        rad = rng.uniform(3, 18)
        a = int(rng.uniform(5, 12))
        d.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(205, 205, 195, a))
    for _ in range(5):
        px, py = rng.uniform(0, w), rng.uniform(0, h)
        ang, ln = rng.uniform(0, math.pi), rng.uniform(40, 160)
        d.line([px, py, px + math.cos(ang) * ln, py + math.sin(ang) * ln], fill=(220, 220, 210, 14), width=1)
    dust = dust.filter(ImageFilter.GaussianBlur(5))
    img = Image.alpha_composite(img, dust)
    img.save(path)


def icons(path):
    S = 256  # draw at 4x, downsample to 64
    sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))

    def canvas():
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        return im, ImageDraw.Draw(im)

    W = (255, 255, 255, 255)
    out = []
    # 0 plus
    im, d = canvas(); d.rounded_rectangle([96, 28, 160, 228], 18, fill=W); d.rounded_rectangle([28, 96, 228, 160], 18, fill=W); out.append(im)
    # 1 bolt
    im, d = canvas(); d.polygon([(150, 16), (60, 142), (122, 142), (98, 240), (196, 104), (134, 104), (170, 16)], fill=W); out.append(im)
    # 2 blood drop
    im, d = canvas(); d.ellipse([62, 96, 194, 228], fill=W); d.polygon([(128, 18), (66, 150), (190, 150)], fill=W); out.append(im)
    # 3 bone
    im, d = canvas()
    d.rounded_rectangle([92, 100, 164, 156], 20, fill=W, ) if False else None
    d.line([(70, 186), (186, 70)], fill=W, width=40)
    for cx, cy in ((52, 186), (70, 204), (186, 52), (204, 70)):
        d.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], fill=W)
    out.append(im)
    # 4 pain (jagged star)
    im, d = canvas()
    pts = []
    for i in range(16):
        ang = i / 16 * math.tau - math.pi / 2
        rr = 112 if i % 2 == 0 else 52
        pts.append((128 + math.cos(ang) * rr, 128 + math.sin(ang) * rr))
    d.polygon(pts, fill=W); out.append(im)
    # 5 energy (can)
    im, d = canvas(); d.rounded_rectangle([64, 44, 192, 228], 22, fill=W); d.rectangle([80, 28, 176, 52], fill=W); d.rectangle([64, 96, 192, 112], fill=(0, 0, 0, 0)); out.append(im)
    # 6 hydration (drop with wave cut)
    im, d = canvas(); d.ellipse([58, 92, 198, 232], fill=W); d.polygon([(128, 14), (62, 146), (194, 146)], fill=W); d.arc([84, 132, 172, 214], 200, 330, fill=(0, 0, 0, 0), width=14); out.append(im)
    # 7 weight
    im, d = canvas(); d.polygon([(66, 92), (190, 92), (226, 226), (30, 226)], fill=W); d.ellipse([92, 26, 164, 98], outline=W, width=22); out.append(im)
    # 8 rec dot
    im, d = canvas(); d.ellipse([40, 40, 216, 216], fill=W); out.append(im)
    # 9 ring
    im, d = canvas(); d.ellipse([36, 36, 220, 220], outline=W, width=26); out.append(im)
    # 10 skull
    im, d = canvas(); d.ellipse([46, 30, 210, 176], fill=W); d.rounded_rectangle([86, 150, 170, 226], 14, fill=W)
    for cx in (98, 158):
        d.ellipse([cx - 26, 82, cx + 26, 134], fill=(0, 0, 0, 0))
    d.polygon([(128, 140), (114, 168), (142, 168)], fill=(0, 0, 0, 0))
    for x0 in (102, 124, 146):
        d.rectangle([x0, 196, x0 + 8, 226], fill=(0, 0, 0, 0))
    out.append(im)
    # 11 person
    im, d = canvas(); d.ellipse([92, 24, 164, 96], fill=W); d.rounded_rectangle([60, 108, 196, 236], 40, fill=W); out.append(im)
    # 12 exit arrow
    im, d = canvas(); d.polygon([(128, 20), (226, 126), (166, 126), (166, 236), (90, 236), (90, 126), (30, 126)], fill=W); out.append(im)
    # 13 armor plate
    im, d = canvas(); d.polygon([(40, 40), (98, 26), (128, 52), (158, 26), (216, 40), (216, 150), (128, 234), (40, 150)], fill=W); out.append(im)
    # 14 helmet
    im, d = canvas(); d.pieslice([30, 50, 226, 246], 180, 360, fill=W); d.rectangle([18, 140, 238, 170], fill=W); out.append(im)
    # 15 magazine
    im, d = canvas(); d.polygon([(92, 24), (164, 24), (176, 120), (198, 232), (122, 232), (100, 120)], fill=W); d.rectangle([84, 18, 172, 40], fill=W); out.append(im)

    for i, im in enumerate(out):
        small = im.resize((64, 64), Image.LANCZOS)
        sheet.paste(small, ((i % 8) * 64, (i // 8) * 64), small)
    sheet.save(path)


def glow(path):
    n = 128
    y, x = np.mgrid[0:n, 0:n].astype(float)
    r = np.sqrt(((x - n / 2 + 0.5) / (n / 2)) ** 2 + ((y - n / 2 + 0.5) / (n / 2)) ** 2)
    a = np.exp(-(r / 0.45) ** 2) * (r < 1)
    img = np.dstack([np.full((n, n), 255), np.full((n, n), 255), np.full((n, n), 255), (a * 255)]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(path)


def scope(path):
    n = 1024
    y, x = np.mgrid[0:n, 0:n].astype(float)
    cx = cy = (n - 1) / 2
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (n / 2)
    alpha = np.clip((r - 0.86) / 0.04, 0, 1)  # black outside the eyepiece, soft edge
    rim = np.exp(-((r - 0.87) / 0.025) ** 2) * 0.6  # dark rim shadow inside the tube
    alpha = np.maximum(alpha, rim)
    rgb = np.zeros((n, n, 3))
    img = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    c = int(cx)
    # fine crosshair with thicker outer posts and a small center gap
    d.line([(c, int(n * 0.12)), (c, c - 18)], fill=(10, 10, 10, 230), width=2)
    d.line([(c, c + 18), (c, int(n * 0.88))], fill=(10, 10, 10, 230), width=2)
    d.line([(int(n * 0.12), c), (c - 18, c)], fill=(10, 10, 10, 230), width=2)
    d.line([(c + 18, c), (int(n * 0.88), c)], fill=(10, 10, 10, 230), width=2)
    for k in (1, -1):
        d.rectangle([c - 4, c + k * 200, c + 4, c + k * 430][::1] if k > 0 else [c - 4, c - 430, c + 4, c - 200], fill=(10, 10, 10, 240))
        d.rectangle([c + k * 200, c - 4, c + k * 430, c + 4] if k > 0 else [c - 430, c - 4, c - 200, c + 4], fill=(10, 10, 10, 240))
    for i in range(1, 6):
        for k in (1, -1):
            yy = c + k * i * 34
            d.line([(c - 7, yy), (c + 7, yy)], fill=(10, 10, 10, 220), width=2)
    d.ellipse([c - 3, c - 3, c + 3, c + 3], fill=(200, 40, 30, 255))
    img.save(path)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    grain(os.path.join(out, "ZR_TEX_Grain.png"))
    lens(os.path.join(out, "ZR_TEX_Lens.png"))
    icons(os.path.join(out, "ZR_TEX_Icons.png"))
    glow(os.path.join(out, "ZR_TEX_Glow.png"))
    scope(os.path.join(out, "ZR_TEX_Scope.png"))
    for f in sorted(os.listdir(out)):
        print(f, os.path.getsize(os.path.join(out, f)))

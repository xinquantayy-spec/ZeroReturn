#!/usr/bin/env python3
"""Zero Return - procedural grime and wear decals (M12 Look 2.0). Original synthesis, no photos.
RGBA overlays used by the client detail layer as Decal (one-off marks) or Texture (tiling strips) objects on
thin carrier parts in front of walls and floors: water streaks under roof edges, dirt and damp rising from the
ground, rust runs, cracks (including diagonal stress cracks from window corners), spalled concrete with
exposed rebar, peeling paint, soot, oil, puddle stains, ground cracks with weeds, papers, debris, leaves,
skid marks, a manhole cover, chain-link mesh, water damage, floor dust with boot prints, window grime, old
bullet holes and spray-painted tags.
Usage: python3 assets/textures/gen_wear.py <out_dir> [names...]
"""
import os, sys, math, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


def rng_for(name):
    return np.random.default_rng(zlib.crc32(("wear:" + name).encode()))


# ── noise helpers (tileable squares; crop for strips) ─────────────────────────
def fbm(rng, n, f0=4.0, beta=2.0):
    white = rng.standard_normal((n, n))
    F = np.fft.rfft2(white)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.rfftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    filt = 1.0 / np.maximum(f, f0) ** (beta / 2)
    filt[0, 0] = 0
    out = np.fft.irfft2(F * filt, s=(n, n))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def blur(a, r, wrap=True):
    if r <= 0:
        return a
    if wrap:
        h, w = a.shape
        F = np.fft.rfft2(a)
        fy = np.fft.fftfreq(h)[:, None]
        fx = np.fft.rfftfreq(w)[None, :]
        g = np.exp(-2 * (math.pi * r) ** 2 * (fx * fx + fy * fy))
        return np.fft.irfft2(F * g, s=a.shape)
    from scipy.ndimage import gaussian_filter
    return gaussian_filter(a, r, mode="constant")


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def warp(rng, a, amount, f0=6.0):
    h, w = a.shape
    n = max(h, w)
    wx = fbm(rng, n, f0=f0)[:h, :w] * amount
    wy = fbm(rng, n, f0=f0)[:h, :w] * amount
    y, x = np.mgrid[0:h, 0:w]
    return a[((y + wy).astype(int)) % h, ((x + wx).astype(int)) % w]


def grid(h, w):
    y, x = np.mgrid[0:h, 0:w]
    return x / w, y / h


def profile1d(rng, W, base=0.06):
    """smooth tileable 1D wobble (sum of integer-frequency sines)"""
    x = np.arange(W) / W
    p = np.zeros(W)
    for f, a in ((1, 1.0), (2, 0.8), (3, 0.6), (5, 0.4), (8, 0.25), (13, 0.15), (21, 0.08)):
        p += a * np.sin(2 * np.pi * (f * x + rng.uniform()))
    return base * p / 2.0


def rgba(color, alpha, var=None, var_amt=0.12):
    """color: (r,g,b) 0..255 or HxWx3 array; alpha 0..1 HxW; var: noise HxW to modulate brightness"""
    h, w = alpha.shape
    c = np.ones((h, w, 3)) * np.array(color, dtype=np.float64)[None, None, :] if np.ndim(color) == 1 else np.asarray(color, dtype=np.float64)
    if var is not None:
        c = c * (1 + var_amt * var)[..., None]
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(c, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    # premultiplied fringe guard: transparent pixels keep their colour (no black halos when filtered)
    return Image.fromarray(out, "RGBA")


class Canvas:
    """float canvas with optional horizontal wrap (draw 3 copies side by side, fold back)"""

    def __init__(self, w, h, wrap_x=False, wrap_y=False):
        self.w, self.h, self.wx, self.wy = w, h, wrap_x, wrap_y
        self.img = Image.new("F", (w * 3 if wrap_x else w, h * 3 if wrap_y else h), 0.0)
        self.d = ImageDraw.Draw(self.img)
        self.ox = w if wrap_x else 0
        self.oy = h if wrap_y else 0

    def line(self, pts, fill, width):
        self.d.line([(x + self.ox, y + self.oy) for x, y in pts], fill=float(fill), width=max(1, int(round(width))))

    def poly(self, pts, fill):
        self.d.polygon([(x + self.ox, y + self.oy) for x, y in pts], fill=float(fill))

    def ellipse(self, cx, cy, rx, ry, fill):
        self.d.ellipse([cx - rx + self.ox, cy - ry + self.oy, cx + rx + self.ox, cy + ry + self.oy], fill=float(fill))

    def get(self, mode="max"):
        a = np.array(self.img, dtype=np.float64)
        if not (self.wx or self.wy):
            return a
        nx = 3 if self.wx else 1
        ny = 3 if self.wy else 1
        out = np.zeros((self.h, self.w))
        for i in range(ny):
            for j in range(nx):
                tile = a[i * self.h:(i + 1) * self.h, j * self.w:(j + 1) * self.w]
                out = np.maximum(out, tile) if mode == "max" else out + tile
        return out


def crack_walk(cv, rng, x, y, ang, steps, width, alpha, seg=(8, 20), turn=0.18, branch=0.18, depth=0):
    pts = []
    for _ in range(steps):
        l = rng.uniform(*seg)
        ang += rng.normal(0, turn)
        if rng.random() < 0.07:
            ang += rng.normal(0, 0.6)
        nx, ny = x + math.cos(ang) * l, y + math.sin(ang) * l
        mx = (x + nx) / 2 + rng.normal(0, l * 0.14) * -math.sin(ang)
        my = (y + ny) / 2 + rng.normal(0, l * 0.14) * math.cos(ang)
        cv.line([(x, y), (mx, my), (nx, ny)], alpha, width)
        pts.append((nx, ny))
        if depth < 2 and rng.random() < branch:
            crack_walk(cv, rng, nx, ny, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.2), max(2, int(steps * 0.4)),
                       max(1, width - 1), alpha * 0.8, seg, turn, branch * 0.6, depth + 1)
        x, y = nx, ny
        alpha *= rng.uniform(0.94, 1.0)
        width = max(1, width * rng.uniform(0.93, 1.0))
    return pts


# ── textures ──────────────────────────────────────────────────────────────────
def tex_streaks(name):
    """water/dirt runs hanging from a roof edge or sill; tiles horizontally (Texture strip, one tile tall)"""
    rng = rng_for(name)
    W, H = 512, 1024
    cv = Canvas(W, H, wrap_x=True)
    for _ in range(140):
        x = rng.uniform(0, W)
        y = rng.uniform(-10, H * 0.08)
        length = H * rng.uniform(0.12, 0.95) ** 1.3
        w = rng.uniform(2, 11)
        s = rng.uniform(0.25, 1.0)
        steps = int(length / 6) + 2
        px, py = x, y
        for k in range(steps):
            t = k / steps
            nx, ny = px + rng.normal(0, 0.7), py + length / steps
            cv.line([(px, py), (nx, ny)], s * (1 - t) ** 1.2, w * (1 - 0.55 * t))
            px, py = nx, ny
    st = blur(cv.get(), 1.6)
    u, v = grid(H, W)
    n = fbm(rng, 1024, f0=6)[:H, :W]
    top = smoothstep(0.075, 0.0, v + 0.02 * n)  # drip line under the edge
    a = np.clip(0.62 * st + 0.7 * top, 0, 1) * np.clip(0.75 + 0.3 * fbm(rng, 1024, f0=10)[:H, :W], 0.3, 1.1)
    col = np.array([46, 42, 35]) * 1.0
    return rgba(col, np.clip(a, 0, 0.82), n, 0.1)


def tex_base(name, damp=False):
    """dirt, splash and damp rising from the ground; tiles horizontally"""
    rng = rng_for(name)
    W = H = 512
    u, v = grid(H, W)
    up = 1 - v  # 0 at the bottom edge
    edge = 0.24 + profile1d(rng, W, 0.07)[None, :] + 0.012 * fbm(rng, 512, f0=10, beta=2.6)
    dirt = smoothstep(edge + 0.1, edge - 0.14, up) ** 1.25
    low = np.clip(0.8 + 0.22 * fbm(rng, 512, f0=4, beta=2.8), 0.45, 1.15)
    cv = Canvas(W, H, wrap_x=True)
    for _ in range(700):
        x, y = rng.uniform(0, W), H - abs(rng.normal(0, 22))
        r = rng.uniform(0.6, 2.2)
        cv.ellipse(x, y, r, r * rng.uniform(0.6, 1.2), rng.uniform(0.3, 0.9))
    splash = blur(cv.get(), 0.6)
    a = np.clip(0.72 * dirt * low + 0.45 * splash * (1 - dirt), 0, 0.8)
    n = fbm(rng, 512, f0=8)
    if damp:
        green = smoothstep(0.14, 0.0, up + 0.04 * n)
        col = np.stack([44 - 8 * green, 46 + 10 * green, 34 - 2 * green], -1) * np.ones((H, W, 1))
        a = np.clip(a + 0.22 * green, 0, 0.85)
    else:
        col = np.stack([60 - 20 * dirt, 53 - 18 * dirt, 44 - 14 * dirt], -1)
    return rgba(col, a, n, 0.1)


def tex_rustrun(name):
    rng = rng_for(name)
    W, H = 256, 512
    cv = Canvas(W, H)
    for k in range(18):
        x = W / 2 + rng.normal(0, 10)
        y = 18 + rng.uniform(0, 14)
        length = H * rng.uniform(0.35, 0.95)
        w = rng.uniform(3, 14) if k < 6 else rng.uniform(1.5, 4)
        s = rng.uniform(0.4, 1.0)
        steps = int(length / 5) + 2
        px, py = x, y
        for i in range(steps):
            t = i / steps
            nx, ny = px + rng.normal(0, 0.8), py + length / steps
            cv.line([(px, py), (nx, ny)], s * (1 - t) ** 1.1, w * (1 + 0.6 * t))
            px, py = nx, ny
    cv.ellipse(W / 2, 22, 16, 12, 1.0)
    a = blur(cv.get(), 2.2, wrap=False)
    n = fbm(rng, 512, f0=10)[:H, :W]
    col = np.stack([118 + 30 * n, 60 + 12 * n, 28 + 6 * n], -1)
    return rgba(col, np.clip(a * 0.85, 0, 0.88), None)


def tex_crack(name, corner=False):
    rng = rng_for(name)
    W = H = 512
    core = Canvas(W, H)
    if corner:
        crack_walk(core, rng, 6, H - 6, math.radians(-48), 34, 4, 1.0, seg=(10, 18), turn=0.07, branch=0.25)
        crack_walk(core, rng, 6, H - 6, math.radians(-62), 12, 2, 0.8, seg=(8, 14), turn=0.1, branch=0.15)
    else:
        cx, cy = W / 2, H / 2
        for k in range(3):
            crack_walk(core, rng, cx, cy, k * 2.1 + rng.normal(0, 0.4), 16, 4 - k, 1.0, seg=(9, 18), branch=0.3)
    c = core.get()
    rim = np.roll(np.roll(c, -2, 0), -1, 1)  # light rim above-left of the dark line (spalled edge catching light)
    halo = blur(c, 6, wrap=False)
    a = np.clip(np.maximum(c * 0.95, np.maximum(rim * 0.5, halo * 0.35)), 0, 1)
    light = np.clip(rim - c, 0, 1)
    col = np.stack([28 + 120 * light, 26 + 118 * light, 24 + 112 * light], -1) + (1 - np.clip(c + light, 0, 1))[..., None] * np.array([40, 37, 32])
    return rgba(col, a, None)


def jagged(rng, cx, cy, rx, ry, n=28, rough=0.22):
    """irregular chipped outline (polygon points)"""
    pts = []
    rr = 1.0
    for k in range(n):
        t = 2 * math.pi * k / n + rng.normal(0, 0.05)
        rr = 0.6 * rr + 0.4 * (1 + rng.normal(0, rough))
        rr = min(1.35, max(0.55, rr))
        pts.append((cx + math.cos(t) * rx * rr, cy + math.sin(t) * ry * rr))
    return pts


def tex_spall(name):
    rng = rng_for(name)
    W = H = 512
    cv = Canvas(W, H)
    cv.poly(jagged(rng, W * 0.5, H * 0.5, W * 0.36, H * 0.27, n=40, rough=0.3), 1.0)
    for _ in range(5):  # smaller chips around the main spall
        ang = rng.uniform(0, 6.283)
        cx, cy = W * 0.5 + math.cos(ang) * W * 0.36, H * 0.5 + math.sin(ang) * H * 0.28
        cv.poly(jagged(rng, cx, cy, rng.uniform(14, 34), rng.uniform(10, 26), n=12, rough=0.35), 1.0)
    inside = blur(cv.get(), 0.9, wrap=False)
    depth = blur(inside, 10, wrap=False)
    gy = np.roll(depth, 6, 0) - np.roll(depth, -6, 0)  # >0 near the lower rim, <0 near the upper rim
    agg = fbm(rng, 512, f0=48, beta=0.9)
    base = 74 + 13 * agg - 24 * np.clip(1 - depth, 0, 1)
    col = np.stack([base, base * 0.97, base * 0.93], -1)
    col = col + (np.clip(-gy, 0, 1) * 70)[..., None] - (np.clip(gy, 0, 1) * 40)[..., None]
    rimc = Canvas(W, H)
    rimc.d.line([(x, y) for x, y in jagged(rng, W * 0.5, H * 0.5, W * 0.37, H * 0.28, n=40, rough=0.3)], fill=1.0, width=5)
    rim = blur(rimc.get(), 1.2, wrap=False) * (1 - inside)
    col = col * (1 - rim[..., None]) + rim[..., None] * np.array([170, 166, 156])
    bars = Canvas(W, H)
    for yy in (0.45, 0.59):
        y0 = H * (yy + rng.normal(0, 0.012))
        bars.line([(W * 0.1, y0), (W * 0.5, y0 + rng.normal(0, 3)), (W * 0.9, y0 + rng.normal(0, 3))], 1.0, 9)
    b = blur(bars.get(), 0.8, wrap=False) * inside
    bshade = np.roll(b, 4, 0) * (1 - b)  # bar shadow
    col = col * (1 - 0.5 * bshade[..., None])
    col = col * (1 - b[..., None]) + b[..., None] * np.array([92, 50, 28])
    rust = Canvas(W, H)
    for _ in range(12):
        x = rng.uniform(W * 0.25, W * 0.75)
        y = H * rng.uniform(0.66, 0.72)
        length = H * rng.uniform(0.08, 0.26)
        rust.line([(x, y), (x + rng.normal(0, 2), y + length)], rng.uniform(0.3, 0.7), rng.uniform(2, 6))
    r = blur(rust.get(), 2.5, wrap=False) * (1 - inside)
    col = col * (1 - r[..., None]) + r[..., None] * np.array([110, 62, 32])
    a = np.clip(np.maximum(np.maximum(inside, rim * 0.6), r * 0.7), 0, 1)
    return rgba(col, a, None)


def tex_peel(name):
    """peeling paint flakes over plaster; tiles both ways"""
    rng = rng_for(name)
    N = 512
    flakes = Canvas(N, N, wrap_x=True, wrap_y=True)
    lips = Canvas(N, N, wrap_x=True, wrap_y=True)
    for _ in range(5):  # clusters
        cx, cy = rng.uniform(0, N), rng.uniform(0, N)
        for _ in range(int(rng.integers(5, 14))):
            x, y = cx + rng.normal(0, 46), cy + rng.normal(0, 36)
            rx, ry = rng.uniform(8, 38), rng.uniform(6, 26)
            pts = jagged(rng, x, y, rx, ry, n=16, rough=0.4)
            flakes.poly(pts, 1.0)
            lips.d.line([(px + flakes.ox, py + flakes.oy) for px, py in pts + pts[:1]], fill=1.0, width=3)
    patch = blur(flakes.get(), 0.7)
    lip = np.clip(blur(lips.get(), 0.6) - 0.35 * patch, 0, 1)
    shadow = np.clip(np.roll(np.roll(patch, 3, 0), 2, 1) - patch, 0, 1)
    col = np.ones((N, N, 3)) * np.array([112, 104, 90])
    col = col * (1 - 0.45 * shadow[..., None])
    col = col * (1 - lip[..., None]) + lip[..., None] * np.array([214, 212, 200])
    a = np.clip(np.maximum(np.maximum(patch * 0.92, lip * 0.95), shadow * 0.5), 0, 1)
    return rgba(col, a, fbm(rng, N, f0=30), 0.12)


def tex_soot(name):
    rng = rng_for(name)
    W = H = 512
    u, v = grid(H, W)
    up = 1 - v
    width = 0.12 + 0.3 * up
    plume = np.exp(-((u - 0.5) / width) ** 2) * smoothstep(0.0, 0.08, up) * smoothstep(1.0, 0.35, up)
    n = warp(rng, fbm(rng, 512, f0=5), 30)
    a = np.clip(plume * (0.75 + 0.35 * n), 0, 0.92)
    return rgba(np.array([22, 20, 18]), a, n, 0.2)


def tex_oil(name):
    rng = rng_for(name)
    N = 512
    u, v = grid(N, N)
    d = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) * 2.4
    f = warp(rng, 1 - d + 0.35 * fbm(rng, N, f0=4), 24)
    a = smoothstep(0.0, 0.18, f) * 0.82
    cv = Canvas(N, N)
    for _ in range(40):
        ang, rr = rng.uniform(0, 6.283), rng.uniform(0.25, 0.48) * N
        r = rng.uniform(2, 9)
        cv.ellipse(N / 2 + math.cos(ang) * rr, N / 2 + math.sin(ang) * rr, r, r * rng.uniform(0.6, 1), rng.uniform(0.5, 0.9))
    a = np.clip(np.maximum(a, blur(cv.get(), 1.0, wrap=False) * 0.8), 0, 0.88)
    n = fbm(rng, N, f0=10)
    col = np.stack([20 + 6 * n, 18 + 5 * n, 15 + 4 * n], -1)
    return rgba(col, a, None)


def tex_groundcrack(name):
    rng = rng_for(name)
    N = 512
    cv = Canvas(N, N, wrap_x=True, wrap_y=True)
    for _ in range(5):
        crack_walk(cv, rng, rng.uniform(0, N), rng.uniform(0, N), rng.uniform(0, 6.283), 26, 4, 1.0, seg=(10, 22), turn=0.22, branch=0.3)
    c = cv.get()
    halo = blur(c, 5)
    weeds = Canvas(N, N, wrap_x=True, wrap_y=True)
    ys, xs = np.nonzero(c > 0.5)
    if len(xs):
        for i in rng.choice(len(xs), size=min(260, len(xs)), replace=False):
            r = rng.uniform(1.5, 4)
            weeds.ellipse(xs[i] + rng.normal(0, 3), ys[i] + rng.normal(0, 3), r, r * rng.uniform(0.5, 1), 1.0)
    w = blur(weeds.get(), 0.8)
    a = np.clip(np.maximum(c * 0.95, np.maximum(halo * 0.3, w * 0.9)), 0, 1)
    col = np.ones((N, N, 3)) * np.array([26, 25, 22])
    col = col * (1 - w[..., None]) + w[..., None] * np.array([62, 72, 38])
    return rgba(col, a, None)


def tex_wet(name):
    rng = rng_for(name)
    N = 512
    u, v = grid(N, N)
    d = np.sqrt(((u - 0.5) / 0.5) ** 2 + ((v - 0.5) / 0.36) ** 2)
    f = warp(rng, 1 - d + 0.3 * fbm(rng, N, f0=3), 20)
    a = smoothstep(0.0, 0.35, f) * 0.6
    return rgba(np.array([24, 27, 27]), a, fbm(rng, N, f0=8), 0.15)


def spray_text(text, font_path, size, W, H, rng, color, drips=True, stencil=False, angle=0.0):
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, size)
    bb = d.textbbox((0, 0), text, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((W - tw) / 2 - bb[0], (H - th) / 2 - bb[1]), text, font=font, fill=255)
    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC)
    m = np.array(img, dtype=np.float64) / 255
    if stencil:
        # stencil bridges: thin horizontal gaps through the letters
        u, v = grid(H, W)
        for y0 in (0.5,):
            m *= 1 - (np.abs(v - y0) < 0.012)
    m = warp(rng, m, 1.5 if stencil else 2.2, f0=10)
    halo = blur(m, 7, wrap=False) * (0.25 if stencil else 0.45)  # overspray
    if drips:
        cv = Canvas(W, H)
        ys, xs = np.nonzero(m > 0.5)
        bottom = {}
        for x, y in zip(xs, ys):
            if y > bottom.get(x, -1):
                bottom[x] = y
        keys = list(bottom.keys())
        for _ in range(min(26, len(keys))):
            x = keys[int(rng.integers(0, len(keys)))]
            y = bottom[x]
            cv.line([(x, y), (x + rng.normal(0, 0.5), y + rng.uniform(10, 70))], 0.9, rng.uniform(2, 4))
            cv.ellipse(x, y + 2, 2.5, 2.5, 0.9)
        m = np.maximum(m, blur(cv.get(), 0.7, wrap=False))
    grain = np.clip(0.75 + 0.35 * fbm(rng, max(W, H), f0=60, beta=0.5)[:H, :W], 0, 1)
    a = np.clip(np.maximum(m * grain, halo), 0, 1) * 0.92
    col = np.ones((H, W, 3)) * np.array(color, dtype=np.float64)
    return a, col


FONT_BOLD = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
FONT_COND = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"


def tex_tag(name, kind):
    rng = rng_for(name)
    W, H = 512, 256
    if kind == 1:  # big two-tone "Q7" throw-up
        a1, _ = spray_text("Q7", FONT_BOLD, 200, W, H, rng, (0, 0, 0), drips=False, angle=-4)
        outline = np.clip(blur(a1, 5, wrap=False) * 3, 0, 1)
        a2, _ = spray_text("Q7", FONT_BOLD, 200, W, H, rng, (0, 0, 0), drips=True, angle=-4)
        a = np.clip(np.maximum(outline * 0.9, a2), 0, 0.95)
        fill = np.clip(a2 / 0.92, 0, 1)
        col = np.ones((H, W, 3)) * np.array([22, 22, 24])
        col = col * (1 - fill[..., None]) + fill[..., None] * np.array([168, 58, 44])
        return rgba(col, a, None)
    if kind == 2:  # white drippy words
        a, col = spray_text("NO WAY OUT", FONT_BOLD, 74, W, H, rng, (214, 210, 200), angle=3)
        return rgba(col, a, None)
    if kind == 3:  # tally marks and an arrow
        cv = Canvas(W, H)
        x0 = 40
        for g in range(3):
            for k in range(4):
                x = x0 + g * 110 + k * 18
                cv.line([(x + rng.normal(0, 2), 70 + rng.normal(0, 3)), (x + rng.normal(0, 3), 190 + rng.normal(0, 4))], 1.0, 9)
            cv.line([(x0 + g * 110 - 12, 170), (x0 + g * 110 + 70, 92)], 1.0, 8)
        cv.line([(380, 130), (480, 130)], 1.0, 10)
        cv.line([(452, 100), (482, 130), (452, 160)], 1.0, 10)
        m = warp(rng, cv.get(), 2.5, f0=12)
        a = np.clip(np.maximum(m, blur(m, 6, wrap=False) * 0.4), 0, 0.9)
        return rgba(np.array([26, 26, 26]), a, None)
    # stencil "NO ENTRY" in faded yellow
    a, col = spray_text("NO ENTRY", FONT_COND, 82, W, H, rng, (196, 160, 56), drips=False, stencil=True)
    a *= np.clip(0.85 + 0.25 * fbm(rng, 512, f0=8)[:H, :W], 0.45, 1)
    return rgba(col, a, None)


def tex_papers(name):
    rng = rng_for(name)
    N = 512
    cv = Canvas(N, N)
    lines = Canvas(N, N)
    shade = Canvas(N, N)
    for k in range(9):
        cx, cy = rng.uniform(70, N - 70), rng.uniform(70, N - 70)
        w, h = rng.uniform(46, 72), rng.uniform(64, 98)
        ang = rng.uniform(0, math.pi)
        ca, sa = math.cos(ang), math.sin(ang)

        def P(x, y):
            return (cx + x * ca - y * sa, cy + x * sa + y * ca)

        crumpled = rng.random() < 0.35
        if crumpled:
            pts = [P(math.cos(t) * w * 0.35 * rng.uniform(0.7, 1.2), math.sin(t) * w * 0.35 * rng.uniform(0.7, 1.2)) for t in np.linspace(0, 6.283, 11)[:-1]]
            cv.poly(pts, 1.0)
            for _ in range(5):
                shade.line([P(rng.uniform(-w * .3, w * .3), rng.uniform(-w * .3, w * .3)), P(rng.uniform(-w * .3, w * .3), rng.uniform(-w * .3, w * .3))], 0.6, 2)
        else:
            cv.poly([P(-w / 2, -h / 2), P(w / 2, -h / 2), P(w / 2, h / 2), P(-w / 2, h / 2)], 1.0)
            for j in range(int(h / 9) - 2):
                y = -h / 2 + 12 + j * 9
                if rng.random() < 0.85:
                    lines.line([P(-w / 2 + 7, y), P(-w / 2 + 7 + (w - 14) * rng.uniform(0.4, 1.0), y)], 0.8, 1.5)
            if rng.random() < 0.6:
                shade.line([P(-w / 2, rng.uniform(-h / 4, h / 4)), P(w / 2, rng.uniform(-h / 4, h / 4))], 0.5, 2)
    m = cv.get()
    l = lines.get() * m
    s = blur(shade.get(), 1.2, wrap=False) * m
    edge_shadow = np.clip(blur(m, 3, wrap=False) - m, 0, 1)
    tone = 200 + 18 * fbm(rng, N, f0=6)
    col = np.stack([tone, tone * 0.98, tone * 0.9], -1) * (1 - 0.5 * l[..., None]) * (1 - 0.35 * s[..., None])
    a = np.clip(np.maximum(m, edge_shadow * 0.35), 0, 1)
    col = col * m[..., None] + (1 - m[..., None]) * np.array([20, 20, 20])
    return rgba(col, a, None)


def tex_debris(name):
    rng = rng_for(name)
    N = 512
    cv = Canvas(N, N, wrap_x=True, wrap_y=True)
    colmap = np.zeros((N, N, 3))
    tone = Canvas(N, N, wrap_x=True, wrap_y=True)
    for _ in range(1400):
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        r = rng.uniform(0.8, 3.2) if rng.random() < 0.9 else rng.uniform(4, 9)
        pts = [(x + math.cos(t) * r * rng.uniform(0.6, 1.3), y + math.sin(t) * r * rng.uniform(0.6, 1.3)) for t in np.linspace(0, 6.283, 6)[:-1]]
        cv.poly(pts, 1.0)
        tone.poly(pts, rng.uniform(0.2, 1.0))
    for _ in range(14):  # cigarette butts
        x, y, ang = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(0, 6.283)
        cv.line([(x, y), (x + math.cos(ang) * 9, y + math.sin(ang) * 9)], 1.0, 3)
        tone.line([(x, y), (x + math.cos(ang) * 9, y + math.sin(ang) * 9)], 1.5, 3)
    m = np.clip(cv.get(), 0, 1)
    t = tone.get()
    base = 40 + 90 * np.clip(t, 0, 1)
    col = np.stack([base, base * 0.96, base * 0.9], -1)
    butt = (t > 1.2)
    col[butt] = np.array([200, 186, 150])
    dust = blur(m, 4) * 0.5
    a = np.clip(np.maximum(m, dust * 0.5), 0, 1)
    return rgba(col, a, None)


def tex_leaves(name):
    rng = rng_for(name)
    N = 512
    cv = Canvas(N, N, wrap_x=True, wrap_y=True)
    tone = Canvas(N, N, wrap_x=True, wrap_y=True)
    palette = [(92, 62, 30), (120, 86, 40), (70, 50, 28), (104, 96, 50), (60, 44, 26), (136, 100, 52)]
    pcanv = [Canvas(N, N, wrap_x=True, wrap_y=True) for _ in palette]
    for _ in range(320):
        x, y, ang = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(0, 6.283)
        L, Wd = rng.uniform(10, 22), rng.uniform(4, 9)
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for t in np.linspace(0, 1, 9):
            pts.append((x + ca * L * (t - 0.5) - sa * Wd * math.sin(t * math.pi) * 0.5, y + sa * L * (t - 0.5) + ca * Wd * math.sin(t * math.pi) * 0.5))
        for t in np.linspace(1, 0, 9)[1:-1]:
            pts.append((x + ca * L * (t - 0.5) + sa * Wd * math.sin(t * math.pi) * 0.5, y + sa * L * (t - 0.5) - ca * Wd * math.sin(t * math.pi) * 0.5))
        k = int(rng.integers(0, len(palette)))
        pcanv[k].poly(pts, 1.0)
        cv.poly(pts, 1.0)
    m = np.clip(cv.get(), 0, 1)
    col = np.zeros((N, N, 3))
    for k, c in enumerate(palette):
        mk = np.clip(pcanv[k].get(), 0, 1)
        col = col * (1 - mk[..., None]) + mk[..., None] * np.array(c)
    a = np.clip(np.maximum(m * 0.96, blur(m, 3) * 0.25), 0, 1)
    return rgba(col, a, fbm(rng, N, f0=20), 0.15)


def tex_skid(name):
    rng = rng_for(name)
    W, H = 1024, 256
    u, v = grid(H, W)
    a = np.zeros((H, W))
    for c in (0.3, 0.7):
        center = c + 0.04 * np.sin(u * 3.1 + rng.uniform(0, 6))
        band = smoothstep(0.1, 0.06, np.abs(v - center))
        tread = 0.75 + 0.25 * np.sin(u * W / 5.0)
        a = np.maximum(a, band * tread)
    fade = smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.7, u)
    a *= fade * np.clip(0.7 + 0.4 * fbm(rng, 1024, f0=12)[:H, :W], 0.2, 1) * 0.75
    return rgba(np.array([16, 16, 16]), a, None)


def tex_manhole(name):
    rng = rng_for(name)
    N = 256
    u, v = grid(N, N)
    r = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) * 2
    disc = smoothstep(0.98, 0.94, r)
    rim = smoothstep(0.8, 0.86, r) * disc
    gx = (np.abs(((u * 14) % 1) - 0.5) < 0.12) | (np.abs(((v * 14) % 1) - 0.5) < 0.12)
    base = 56 + 18 * fbm(rng, N, f0=12)
    col = np.stack([base, base * 0.95, base * 0.9], -1)
    col = col * (1 - 0.35 * (gx * (r < 0.78))[..., None])
    rust = smoothstep(0.4, 1.4, fbm(rng, N, f0=6)) * disc
    col = col * (1 - rust[..., None]) + rust[..., None] * np.array([96, 56, 32])
    col = col * (1 - 0.4 * rim[..., None])
    return rgba(col, disc, None)


def tex_chainlink(name):
    rng = rng_for(name)
    N = 256
    cv = Canvas(N, N, wrap_x=True, wrap_y=True)
    s = N / 8
    for k in range(-8, 17):
        cv.line([(k * s, 0), (k * s + N, N)], 1.0, 3)
        cv.line([(k * s, N), (k * s + N, 0)], 1.0, 3)
    m = np.clip(cv.get(), 0, 1)
    rust = smoothstep(0.5, 1.6, fbm(rng, N, f0=6))
    base = 116 + 14 * fbm(rng, N, f0=30)
    col = np.stack([base, base, base * 0.97], -1)
    col = col * (1 - rust[..., None] * 0.7) + rust[..., None] * 0.7 * np.array([110, 70, 40])
    return rgba(col, m, None)


def tex_leak(name):
    rng = rng_for(name)
    N = 512
    u, v = grid(N, N)
    d = np.sqrt((u - 0.5) ** 2 + (v - 0.45) ** 2) * 2.2
    f = warp(rng, d + 0.18 * fbm(rng, N, f0=4), 18)
    rings = np.zeros((N, N))
    for r0 in (0.35, 0.55, 0.72, 0.86):
        rings += smoothstep(0.03, 0.0, np.abs(f - r0)) * rng.uniform(0.5, 1)
    inner = smoothstep(0.9, 0.2, f) * 0.35
    a = np.clip(rings * 0.6 + inner, 0, 0.8)
    col = np.stack([112 - 20 * rings, 92 - 18 * rings, 56 - 10 * rings], -1)
    return rgba(col, a, fbm(rng, N, f0=10), 0.1)


def tex_floordust(name):
    rng = rng_for(name)
    N = 512
    dust = smoothstep(0.2, 1.6, warp(rng, fbm(rng, N, f0=4, beta=2.4), 20)) * 0.45
    prints = Canvas(N, N, wrap_x=True, wrap_y=True)
    for walk in range(3):
        x, y, ang = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(0, 6.283)
        for step in range(9):
            side = 1 if step % 2 == 0 else -1
            px = x + math.cos(ang + math.pi / 2) * 9 * side
            py = y + math.sin(ang + math.pi / 2) * 9 * side
            ca, sa = math.cos(ang), math.sin(ang)
            for t in range(6):  # sole as tread bars
                o = -14 + t * 5.5
                prints.line([(px + ca * o - sa * 5, py + sa * o + ca * 5), (px + ca * o + sa * 5, py + sa * o - ca * 5)], 0.8, 3)
            x += ca * 30
            y += sa * 30
            ang += rng.normal(0, 0.12)
    p = blur(prints.get(), 0.8)
    a = np.clip(dust + p * 0.5, 0, 0.7)
    return rgba(np.array([70, 64, 54]), a, fbm(rng, N, f0=12), 0.1)


def tex_grime(name):
    """dirty window / glass film; tiles both ways"""
    rng = rng_for(name)
    N = 512
    film = smoothstep(-0.4, 1.8, warp(rng, fbm(rng, N, f0=5), 26)) * 0.42
    spots = Canvas(N, N, wrap_x=True, wrap_y=True)
    for _ in range(260):
        x, y, r = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(1, 5)
        spots.ellipse(x, y, r, r, rng.uniform(0.3, 0.8))
    s = blur(spots.get(), 1.4) * 0.35
    a = np.clip(film + s, 0, 0.6)
    return rgba(np.array([88, 84, 72]), a, fbm(rng, N, f0=16), 0.12)


def tex_holes(name):
    rng = rng_for(name)
    N = 512
    crater = Canvas(N, N)
    core = Canvas(N, N)
    cracks = Canvas(N, N)
    cx0, cy0 = N / 2, N / 2
    for _ in range(int(rng.integers(6, 10))):
        x, y = cx0 + rng.normal(0, 70), cy0 + rng.normal(0, 60)
        R = rng.uniform(10, 18)
        pts = [(x + math.cos(t) * R * rng.uniform(0.65, 1.25), y + math.sin(t) * R * rng.uniform(0.65, 1.25)) for t in np.linspace(0, 6.283, 13)[:-1]]
        crater.poly(pts, 1.0)
        core.ellipse(x, y, R * 0.32, R * 0.3, 1.0)
        for k in range(int(rng.integers(2, 5))):
            ang = rng.uniform(0, 6.283)
            crack_walk(cracks, rng, x + math.cos(ang) * R * 0.8, y + math.sin(ang) * R * 0.8, ang, 3, 1, 0.8, seg=(5, 10), branch=0.1)
    cr, co, ck = crater.get(), blur(core.get(), 1.2, wrap=False), cracks.get()
    soot = blur(cr, 9, wrap=False) * 0.4
    shade = np.clip(np.roll(blur(cr, 3, wrap=False), 3, 0) - cr, 0, 1)
    col = np.ones((N, N, 3)) * np.array([128, 124, 116])
    col = col * (1 - 0.45 * shade[..., None])
    col = col * (1 - co[..., None]) + co[..., None] * np.array([18, 17, 16])
    col = col * (1 - ck[..., None] * 0.8) + ck[..., None] * 0.8 * np.array([30, 28, 26])
    col = col * (cr[..., None]) + (1 - cr[..., None]) * np.array([34, 31, 28])
    a = np.clip(np.maximum(np.maximum(cr, ck * 0.85), soot), 0, 1)
    return rgba(col, a, None)


TEXTURES = {
    "Streaks": lambda n: tex_streaks(n),
    "BaseGrime": lambda n: tex_base(n),
    "BaseDamp": lambda n: tex_base(n, damp=True),
    "RustRun": lambda n: tex_rustrun(n),
    "Crack": lambda n: tex_crack(n),
    "CornerCrack": lambda n: tex_crack(n, corner=True),
    "Spall": lambda n: tex_spall(n),
    "Peel": lambda n: tex_peel(n),
    "Soot": lambda n: tex_soot(n),
    "Oil": lambda n: tex_oil(n),
    "GroundCrack": lambda n: tex_groundcrack(n),
    "Wet": lambda n: tex_wet(n),
    "Tag1": lambda n: tex_tag(n, 1),
    "Tag2": lambda n: tex_tag(n, 2),
    "Tag3": lambda n: tex_tag(n, 3),
    "Stencil": lambda n: tex_tag(n, 4),
    "Papers": lambda n: tex_papers(n),
    "Debris": lambda n: tex_debris(n),
    "Leaves": lambda n: tex_leaves(n),
    "Skid": lambda n: tex_skid(n),
    "Manhole": lambda n: tex_manhole(n),
    "ChainLink": lambda n: tex_chainlink(n),
    "Leak": lambda n: tex_leak(n),
    "FloorDust": lambda n: tex_floordust(n),
    "Grime": lambda n: tex_grime(n),
    "Holes": lambda n: tex_holes(n),
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out", "wear")
    names = sys.argv[2:] or list(TEXTURES)
    os.makedirs(out, exist_ok=True)
    for n in names:
        img = TEXTURES[n](n)
        p = os.path.join(out, "ZR_DEC_%s.png" % n)
        img.save(p, optimize=True)
        print(p, img.size)


if __name__ == "__main__":
    main()

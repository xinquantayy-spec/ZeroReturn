#!/usr/bin/env python3
"""Zero Return - procedural worn-surface material set (M12 Look 2.0). Original synthesis, no photos.
Each material is a seamless tile: colour (near-neutral so Part.Color tints it), normal (OpenGL, +Y up) and
roughness maps. They become MaterialVariants in MaterialService (Rojo: src/materials/*.model.json).
Wear vocabulary (Tarkov-style imperfection): water streaks and rust runs, stains and mould, chips and spalls,
hairline cracks, bad patch repairs, peeling paint, scuffs, oil, grime in seams.
Usage: python3 assets/textures/gen_materials.py <out_dir> [names...]
"""
import os, sys, math, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 1024


# ── tileable building blocks ─────────────────────────────────────────────────
def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def fbm(rng, n=N, f0=4.0, beta=2.0, fmax=None):
    """tileable fractal noise (FFT-filtered white noise): f0 = low-frequency cut (features per tile), beta = slope"""
    white = rng.standard_normal((n, n))
    F = np.fft.rfft2(white)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.rfftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    filt = 1.0 / np.maximum(f, f0) ** (beta / 2)
    filt[0, 0] = 0
    if fmax:
        filt *= np.exp(-(f / fmax) ** 2)
    out = np.fft.irfft2(F * filt, s=(n, n))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def band(rng, size_px, n=N):
    """tileable blobs about size_px across"""
    white = rng.standard_normal((n, n))
    F = np.fft.rfft2(white)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.rfftfreq(n)[None, :] * n
    f = np.sqrt(fx * fx + fy * fy)
    fc = n / size_px
    out = np.fft.irfft2(F * np.exp(-(f / fc) ** 2), s=(n, n))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def blur(a, r):
    """wrap-around gaussian blur (tileable)"""
    if r <= 0:
        return a
    n = a.shape[0]
    F = np.fft.rfft2(a)
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.rfftfreq(n)[None, :]
    g = np.exp(-2 * (math.pi * r) ** 2 * (fx * fx + fy * fy))
    return np.fft.irfft2(F * g, s=a.shape)


def canvas(n=N):
    """3x3 tiled drawing canvas (draw with offsets, then fold() back to one seamless tile)"""
    img = Image.new("F", (3 * n, 3 * n), 0.0)
    return img, ImageDraw.Draw(img)


def fold(img, n=N):
    a = np.array(img, dtype=np.float64)
    out = np.zeros((n, n))
    for i in range(3):
        for j in range(3):
            out += a[i * n:(i + 1) * n, j * n:(j + 1) * n]
    return out


def streaks(rng, count, len_rng, width_rng, n=N, wobble=0.6):
    """water/rust runs: vertical streaks that fade downward (wrap around), returns 0..1"""
    img, d = canvas(n)
    for _ in range(count):
        x = rng.uniform(0, n)
        y = rng.uniform(0, n)
        length = rng.uniform(*len_rng)
        w = rng.uniform(*width_rng)
        strength = rng.uniform(0.35, 1.0)
        steps = int(length / 4) + 2
        px, py = x, y
        for k in range(steps):
            t = k / steps
            a = strength * (1 - t) ** 1.4
            ww = w * (1 - 0.6 * t)
            nx = px + rng.normal(0, wobble)
            ny = py + length / steps
            d.line([(nx + n, ny + n), (px + n, py + n)], fill=float(a), width=max(1, int(round(ww))))
            px, py = nx, ny
    out = fold(img, n)
    return np.clip(blur(out, 1.2), 0, 1)


def cracks(rng, count, n=N, seg=(10, 26), branch=0.25, width=(1, 2), steps=(12, 40), turn=0.16):
    """jagged crack lines: mostly straight with small kinks and occasional branches, returns 0..1"""
    img, d = canvas(n)

    def walk(x, y, ang, s, w, a):
        for _ in range(s):
            l = rng.uniform(*seg)
            ang += rng.normal(0, turn)
            if rng.random() < 0.08:
                ang += rng.normal(0, 0.7)  # a sharper kink now and then
            nx, ny = x + math.cos(ang) * l, y + math.sin(ang) * l
            # jagged: two half segments with a sideways offset
            mx = (x + nx) / 2 + rng.normal(0, l * 0.12) * -math.sin(ang)
            my = (y + ny) / 2 + rng.normal(0, l * 0.12) * math.cos(ang)
            d.line([(x + n, y + n), (mx + n, my + n), (nx + n, ny + n)], fill=float(a), width=w)
            if rng.random() < branch * 0.12:
                walk(nx, ny, ang + rng.choice([-1, 1]) * rng.uniform(0.45, 1.1), max(2, int(s * 0.35)), max(1, w - 1), a * 0.7)
            x, y = nx, ny
            a *= rng.uniform(0.93, 1.0)

    for _ in range(count):
        walk(rng.uniform(0, n), rng.uniform(0, n), rng.uniform(0, 2 * math.pi), int(rng.integers(*steps)), int(rng.integers(width[0], width[1] + 1)), rng.uniform(0.6, 1.0))
    return np.clip(fold(img, n), 0, 1)


def stain(rng, f0, lo=0.3, hi=1.6, warp=40.0):
    """soft cloudy stains with fractal edges (domain-warped noise), returns 0..1"""
    base = fbm(rng, f0=f0, beta=2.4)
    wx = fbm(rng, f0=f0 * 2, beta=2.0) * warp
    wy = fbm(rng, f0=f0 * 2, beta=2.0) * warp
    y, x = np.mgrid[0:N, 0:N]
    xi = ((x + wx).astype(int)) % N
    yi = ((y + wy).astype(int)) % N
    warped = base[yi, xi] + fbm(rng, f0=f0 * 6, beta=1.4) * 0.25
    return smoothstep(lo, hi, warped)


def dots(rng, count, r_rng, n=N, soft=0.6):
    """pits / bolt holes / speckles, returns 0..1"""
    img, d = canvas(n)
    for _ in range(count):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        r = rng.uniform(*r_rng)
        d.ellipse([x + n - r, y + n - r, x + n + r, y + n + r], fill=1.0)
    out = fold(img, n)
    return np.clip(blur(out, soft), 0, 1)


def rects(rng, count, w_rng, h_rng, n=N, jag=0.0):
    """patch repairs: rectangles (slightly irregular), returns 0..1 mask"""
    img, d = canvas(n)
    for _ in range(count):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        w, h = rng.uniform(*w_rng), rng.uniform(*h_rng)
        pts = []
        for cx, cy in ((0, 0), (w, 0), (w, h), (0, h)):
            pts.append((x + cx + n + rng.normal(0, jag), y + cy + n + rng.normal(0, jag)))
        d.polygon(pts, fill=1.0)
    return np.clip(fold(img, n), 0, 1)


def oriented(rng, s_par, s_perp, theta=0.0, n=N):
    """tileable noise stretched along a direction (theta radians from the x axis): features about s_par px along the
    stroke and s_perp px across it - brush strokes, roller marks, wood grain. Unit variance."""
    F = np.fft.rfft2(rng.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.rfftfreq(n)[None, :]
    fa = fx * math.cos(theta) + fy * math.sin(theta)
    fp = -fx * math.sin(theta) + fy * math.cos(theta)
    g = np.exp(-2 * math.pi ** 2 * ((s_par * fa) ** 2 + (s_perp * fp) ** 2))
    out = np.fft.irfft2(F * g, s=(n, n))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def strokes(rng, count, len_rng, width_rng, ang=(-0.4, 0.4), ypdf=None, n=N):
    """scuff marks: short straight strokes at shallow angles (heels, trolleys, shoulders, scratches), returns 0..1.
    ypdf(rng) -> a row, to keep them toward the foot of the tile; wraps round the edges like the other marks"""
    img, d = canvas(n)
    for _ in range(count):
        x = rng.uniform(0, n)
        y = ypdf(rng) if ypdf else rng.uniform(0, n)
        l = rng.uniform(*len_rng)
        a = rng.uniform(*ang)
        w = max(1, int(round(rng.uniform(*width_rng))))
        s = rng.uniform(0.3, 1.0)
        d.line([(x + n, y + n), (x + n + math.cos(a) * l, y + n + math.sin(a) * l)], fill=float(s), width=w)
    return np.clip(blur(fold(img, n), 0.8), 0, 1)


def normal_map(height, strength):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(height)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.dstack([nx / l, ny / l, nz / l]) * 0.5 + 0.5
    return (rgb * 255).clip(0, 255).astype(np.uint8)


def to_rgb(col):
    return (np.clip(col, 0, 1) * 255).astype(np.uint8)


def tint(gray, rgb):
    return gray[..., None] * np.array(rgb)[None, None, :]


def half(a):
    """2x2 box downsample (keeps the tile seamless); normal, roughness and metal maps ship at 512 for phones"""
    if a.ndim == 2:
        return a.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2).mean(axis=(1, 3))
    return a.reshape(a.shape[0] // 2, 2, a.shape[1] // 2, 2, a.shape[2]).mean(axis=(1, 3))


def save(out, name, color, height, rough, strength, metal=None):
    Image.fromarray(to_rgb(color), "RGB").save(os.path.join(out, f"ZR_MAT_{name}_Color.png"), optimize=True)
    nrm = normal_map(half(height), strength * 0.5).astype(np.uint8)
    Image.fromarray(nrm, "RGB").save(os.path.join(out, f"ZR_MAT_{name}_Normal.png"), optimize=True)
    Image.fromarray((np.clip(half(rough), 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(out, f"ZR_MAT_{name}_Rough.png"), optimize=True)
    if metal is not None:
        Image.fromarray((np.clip(half(metal), 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(out, f"ZR_MAT_{name}_Metal.png"), optimize=True)


WARM = (1.0, 0.86, 0.72)  # rust / water-stain warmth (survives the part colour tint as a hue shift)
COOL = (0.94, 0.97, 1.0)


# ── materials ────────────────────────────────────────────────────────────────
def concrete_worn(out):
    """cast concrete walls: mottling, cloudy stains, water streaks, rust runs, pits, cracks, bad patch repairs"""
    r = rng_for("concrete_worn")
    mott = fbm(r, f0=3, beta=2.4) * 0.06
    grain = fbm(r, f0=60, beta=0.6, fmax=400) * 0.035
    stains = stain(r, 3, 0.2, 1.8) * 0.16
    wet = streaks(r, 110, (140, 620), (2, 8)) * 0.34
    rust = streaks(r, 10, (60, 260), (2, 5), wobble=0.3) * 0.55
    pits = dots(r, 1100, (0.6, 2.0), soft=0.4)
    crk = cracks(r, 6, seg=(8, 20), steps=(8, 26))
    patch = rects(r, 3, (90, 260), (60, 180), jag=3.0)
    patchTone = patch * 0.05 * (1 + fbm(r, f0=30) * 0.3)
    v = 0.84 + mott + grain - stains - wet - pits * 0.22 - crk * 0.42 + patchTone
    col = tint(v, (1, 1, 1))
    col = col * (1 - rust[..., None] * (1 - np.array(WARM)) * 1.4)
    col = col * (1 - stains[..., None] * 0.5 * (1 - np.array(WARM)))
    height = mott * 2 + grain * 3 - pits * 1.6 - crk * 2.4 + patch * 0.6 + fbm(r, f0=30, beta=1.2) * 0.25
    rough = 0.9 - wet * 0.6 - stains * 0.2 + grain
    save(out, "ConcreteWorn", col, height, rough, 2.2)


def concrete_panel(out):
    """precast panels: joints, lifting holes, chipped joint edges, streaks from the joints, efflorescence"""
    r = rng_for("concrete_panel")
    y, x = np.mgrid[0:N, 0:N]
    joint = np.zeros((N, N))
    for jy in (0, N // 2):
        joint = np.maximum(joint, np.exp(-((((y - jy + N / 2) % N) - N / 2) / 2.2) ** 2))
    joint = np.maximum(joint, np.exp(-((((x + N / 2) % N) - N / 2) / 2.2) ** 2))
    chips = smoothstep(0.55, 1.5, band(r, 14)) * smoothstep(0.02, 0.4, blur(joint, 9) * 6)
    mott = fbm(r, f0=3, beta=2.2) * 0.06 + band(r, 120) * 0.04
    grain = fbm(r, f0=60, beta=0.6, fmax=400) * 0.03
    holes = np.zeros((N, N))
    for hx in (N * 0.22, N * 0.78):
        for hy in (N * 0.14, N * 0.64):
            holes = np.maximum(holes, np.exp(-(((x - hx) ** 2 + (y - hy) ** 2) / (2 * 9 ** 2))))
    run = blur(np.roll(joint, 6, axis=0) * smoothstep(0.3, 1.3, band(r, 30)), 1)
    wet = streaks(r, 55, (90, 380), (2, 7)) * 0.22 + np.clip(blur(run, 2), 0, 1) * 0.12
    effl = smoothstep(0.9, 2.0, band(r, 60)) * 0.08
    v = 0.83 + mott + grain - joint * 0.45 - chips * 0.2 - holes * 0.55 - wet + effl
    col = tint(v, (1, 1, 1)) * (1 - wet[..., None] * 0.25 * (1 - np.array(WARM)))
    height = mott * 2 + grain * 3 - joint * 3 - chips * 1.5 - holes * 3
    rough = 0.88 - wet * 0.5 + grain
    save(out, "ConcretePanel", col, height, rough, 2.4)


def plaster_peel(out):
    """interior painted plaster: peeling paint showing grey render, damp stains, scuffs, cracks"""
    r = rng_for("plaster_peel")
    mott = fbm(r, f0=4, beta=2.0) * 0.035
    peelField = fbm(r, f0=5, beta=2.2) + fbm(r, f0=24, beta=1.2) * 0.45
    peel = smoothstep(1.45, 1.6, peelField)
    lip = smoothstep(1.3, 1.45, peelField) - peel
    damp = stain(r, 2.5, 0.4, 1.8) * 0.2
    tide = np.clip(np.abs(np.sin(stain(r, 2.5, 0.0, 2.0) * 8)) * damp, 0, 1) * 0.35
    scuff = streaks(r, 25, (20, 60), (1, 3), wobble=2.5) * 0.12
    crk = cracks(r, 5, seg=(6, 14), width=(1, 1), steps=(10, 30))
    render = 0.58 + fbm(r, f0=20, beta=1.0) * 0.05
    paint = 0.9 + mott
    v = paint * (1 - peel) + render * peel + lip * 0.05 - damp - tide - scuff - crk * 0.32
    col = tint(v, (1, 1, 1)) * (1 - (damp + tide)[..., None] * 0.7 * (1 - np.array(WARM)))
    height = -peel * 1.2 + lip * 0.9 + mott * 2 - crk * 1.5
    rough = 0.75 + peel * 0.2 - damp * 0.2
    save(out, "PlasterPeel", col, height, rough, 2.0)


def metal_paint(out):
    """painted steel: chipped paint in clusters showing rust and bare metal, scratches, rust runs, grime"""
    r = rng_for("metal_paint")
    mott = fbm(r, f0=4, beta=2.0) * 0.04
    cluster = stain(r, 3, 0.5, 1.6)
    chipField = fbm(r, f0=30, beta=1.2) + cluster * 1.4
    chip = smoothstep(1.45, 1.62, chipField)
    rustAround = smoothstep(1.1, 1.45, chipField) * (1 - chip)
    scratches = cracks(r, 34, seg=(25, 70), branch=0.0, width=(1, 1), steps=(1, 3), turn=0.03)
    runs = streaks(r, 26, (80, 320), (2, 6), wobble=0.3) * (0.35 + cluster * 0.65)
    grime = stain(r, 2, 0.4, 1.8) * 0.14
    v = 0.86 + mott - grime
    col = tint(v, (1, 1, 1))
    rustCol = np.array((0.6, 0.4, 0.28)) * (0.85 + fbm(r, f0=40)[..., None] * 0.12)
    col = col * (1 - chip[..., None]) + rustCol * chip[..., None]
    col = col * (1 - rustAround[..., None] * 0.45 * (1 - np.array(WARM)))
    col = col * (1 - runs[..., None] * (1 - np.array(WARM)) * 0.9)
    col = col + scratches[..., None] * 0.08
    height = -chip * 0.8 + rustAround * 0.2 + mott * 2 - scratches * 0.4
    rough = 0.55 + chip * 0.35 + rustAround * 0.15 + grime * 0.3
    metal = scratches * 0.7
    save(out, "MetalPaint", col, height, rough, 1.6, metal)


def corrugated(out):
    """corrugated sheet: ridges with dark troughs, faded paint, rust runs in the troughs, dents, a few holes"""
    r = rng_for("corrugated")
    y, x = np.mgrid[0:N, 0:N]
    period = N / 8
    ph = (x % period) / period
    wave = np.cos(2 * math.pi * ph)  # ridge at the panel edge, trough in the middle
    profile = np.sign(wave) * np.abs(wave) ** 0.6
    ao = smoothstep(-1.0, 0.6, profile) * 0.18
    dents = fbm(r, f0=3, beta=2.6) * 0.5
    trough = smoothstep(0.2, 1.0, -profile)
    fade = stain(r, 2, 0.3, 1.7) * 0.12
    runs = streaks(r, 46, (150, 700), (3, 9), wobble=0.15) * (0.3 + 0.7 * trough)
    holes = dots(r, 7, (2, 5), soft=0.3)
    v = 0.66 + ao + fbm(r, f0=5) * 0.04 + fade - runs * 0.32 - holes * 0.7
    col = tint(v, (1, 1, 1)) * (1 - runs[..., None] * (1 - np.array(WARM)) * 1.3)
    height = profile * 4 + dents - holes * 2
    rough = 0.7 + runs * 0.2 - fade
    save(out, "Corrugated", col, height, rough, 2.2)


def asphalt_cracked(out):
    """worn asphalt: aggregate, crack network, sealed patches, oil stains, sun-faded areas"""
    r = rng_for("asphalt_cracked")
    agg = (fbm(r, f0=80, beta=0.2, fmax=500) > 1.1).astype(float) * 0.08 + fbm(r, f0=60, beta=0.7) * 0.03
    fade = smoothstep(0.2, 1.6, band(r, 220)) * 0.08
    crk = cracks(r, 9, seg=(18, 40), branch=0.7, width=(1, 3), steps=(10, 30), turn=0.12)
    alligator = cracks(r, 40, seg=(5, 10), branch=1.0, width=(1, 1), steps=(4, 9), turn=0.9) * stain(r, 2, 0.6, 1.4)
    patch = rects(r, 4, (80, 300), (60, 200), jag=6)
    oil = stain(r, 6, 0.9, 2.0) * 0.22
    v = 0.78 + agg + fade - crk * 0.45 - alligator * 0.25 - patch * 0.12 - oil + fbm(r, f0=4) * 0.04
    col = tint(v, (1, 1, 1))
    height = agg * 6 - crk * 2.5 - alligator * 1.5 + patch * 0.4
    rough = 0.92 - oil * 1.5 - patch * 0.08
    save(out, "AsphaltCracked", col, height, rough, 2.0)


def floor_concrete(out):
    """interior slab: saw-cut joints, trowel swirls, oil and rust stains, scuffs, dust"""
    r = rng_for("floor_concrete")
    y, x = np.mgrid[0:N, 0:N]
    joint = np.maximum(np.exp(-((((x + N / 2) % N) - N / 2) / 1.6) ** 2), np.exp(-((((y + N / 2) % N) - N / 2) / 1.6) ** 2))
    swirl = np.sin(band(r, 60) * 6) * 0.015
    oil = stain(r, 5, 0.6, 1.7) * 0.3
    rustSt = stain(r, 9, 1.1, 2.0) * 0.2
    scuff = streaks(r, 90, (20, 90), (1, 4), wobble=3) * 0.16
    dust = stain(r, 2, 0.2, 1.6) * 0.08
    crk = cracks(r, 3, seg=(10, 24), steps=(6, 16))
    v = 0.8 + fbm(r, f0=4) * 0.06 + swirl + dust - oil - joint * 0.4 - scuff - crk * 0.35
    col = tint(v, (1, 1, 1)) * (1 - rustSt[..., None] * (1 - np.array(WARM)) * 1.5)
    height = -joint * 2 + swirl * 4 + fbm(r, f0=40, beta=1) * 0.2 - crk * 2
    rough = 0.82 - oil * 1.6 + dust
    save(out, "FloorConcrete", col, height, rough, 2.0)


def wood_weathered(out):
    """grey weathered planks: gaps, grain, knots, nail holes, dirt"""
    r = rng_for("wood_weathered")
    y, x = np.mgrid[0:N, 0:N]
    plank = N / 6
    gap = np.exp(-((((x + plank / 2) % plank) - plank / 2) / 2.0) ** 2)
    pid = (x // plank).astype(int)
    tone = np.array([r.uniform(-0.06, 0.06) for _ in range(7)])[pid]
    grainLines = np.sin((x + fbm(r, f0=3, beta=2.5) * 25) * 0.9) * 0.04 + fbm(r, f0=20, beta=0.8) * 0.03
    knots = dots(r, 10, (5, 10), soft=3)
    nails = np.zeros((N, N))
    for k in range(6):
        for ny in (0.1, 0.6):
            cx, cy = (k + 0.5) * plank, ny * N + r.uniform(-8, 8)
            nails = np.maximum(nails, np.exp(-(((x - cx - 18) ** 2 + (y - cy) ** 2) / 8)) + np.exp(-(((x - cx + 18) ** 2 + (y - cy) ** 2) / 8)))
    dirt = stain(r, 3, 0.4, 1.8) * 0.12
    v = 0.8 + tone + grainLines - gap * 0.55 - knots * 0.2 - nails * 0.5 - dirt
    col = tint(v, (1, 1, 1))
    height = grainLines * 4 - gap * 3 - nails * 1.5
    rough = 0.85 + dirt * 0.3
    save(out, "WoodWeathered", col, height, rough, 2.2)


# ── M13 Meridian Mall surfaces ───────────────────────────────────────────────
def grid_lines(n_cells, width, n=N):
    """distance-based grid line mask (cells per tile, line width in px), returns 0..1 (1 on the line)"""
    y, x = np.mgrid[0:n, 0:n]
    cell = n / n_cells
    dx = np.abs(((x + cell / 2) % cell) - cell / 2)
    dy = np.abs(((y + cell / 2) % cell) - cell / 2)
    d = np.minimum(dx, dy)
    return smoothstep(width * 0.5 + 0.8, width * 0.5 - 0.4, d)


def cell_index(n_cells, n=N):
    y, x = np.mgrid[0:n, 0:n]
    cell = n / n_cells
    return (x // cell).astype(int), (y // cell).astype(int)


def terrazzo(out):
    """mall floor: polished terrazzo panels (4 studs, 16 studs per tile) with dark joint strips, a slightly different
    tone per panel, mixed stone chips, traffic scuffs and grime along the joints, hairline cracks, water marks.
    v2: joints and panel tones strong enough to read at walking distance (fine chips alone average out)"""
    r = rng_for("terrazzo")
    n_cells = 4
    gx, gy = cell_index(n_cells)
    panel = r.uniform(-0.06, 0.05, (n_cells, n_cells))[gx, gy]
    warmth = r.uniform(-0.03, 0.03, (n_cells, n_cells))[gx, gy]
    base = 0.8 + panel + fbm(r, f0=3, beta=2.2) * 0.03
    col = np.dstack([base * (1.0 + warmth), base * 0.97, base * (0.93 - warmth)])
    for count, rad, tone in ((9000, (0.8, 2.0), (0.44, 0.44, 0.45)), (3800, (1.2, 3.2), (0.95, 0.94, 0.9)),
                             (1600, (1.6, 3.6), (0.58, 0.56, 0.54)), (600, (1.8, 4.2), (0.24, 0.24, 0.25)),
                             (240, (2.0, 4.6), (0.62, 0.38, 0.3)), (200, (2.0, 4.4), (0.78, 0.7, 0.52))):
        m = dots(r, count, rad, soft=0.35)
        col = col * (1 - m[..., None]) + np.array(tone)[None, None, :] * m[..., None]
    strip = grid_lines(n_cells, 7.0)
    grimeEdge = np.clip(blur(strip, 7) * 3.0, 0, 1) * 0.16
    traffic = smoothstep(0.1, 1.6, band(r, 260)) * 0.14
    scuff = streaks(r, 160, (20, 90), (2, 5), wobble=3.5) * 0.2
    heel = dots(r, 220, (1.2, 3.0), soft=0.6) * 0.3
    water = stain(r, 3, 0.9, 1.9)
    tide = np.clip(np.abs(np.sin(water * 7)) * water, 0, 1) * 0.16
    crk = cracks(r, 6, seg=(10, 26), width=(1, 2), steps=(8, 22))
    shade = 1 - grimeEdge - traffic * 0.7 - scuff - heel - tide - crk * 0.45
    col = col * shade[..., None]
    joint = np.array((0.3, 0.29, 0.27))
    col = col * (1 - strip[..., None]) + joint[None, None, :] * strip[..., None]
    col = col * (1 - water[..., None] * 0.08 * (1 - np.array(WARM)))
    height = -strip * 1.4 - crk * 2.2 + fbm(r, f0=6, beta=2.0) * 0.08
    rough = 0.2 + traffic * 2.6 + scuff * 1.5 + grimeEdge * 1.5 + crk * 0.5 + heel + strip * 0.5
    metal = strip * 0.0
    save(out, "Terrazzo", col, height, rough, 1.6, metal)


def floor_tiles(out):
    """large ceramic floor tiles (2 studs, 8 studs per tile): tone variation, dirty grout, chipped corners, two
    cracked tiles, scuffs and dried spills"""
    r = rng_for("floor_tiles")
    n_cells = 4
    gx, gy = cell_index(n_cells)
    tone = r.uniform(-0.07, 0.06, (n_cells, n_cells))[gx, gy]
    grout = grid_lines(n_cells, 11.0)
    groutDirt = 0.3 + fbm(r, f0=8, beta=1.6) * 0.08
    mott = fbm(r, f0=10, beta=1.8) * 0.02 + fbm(r, f0=60, beta=0.8, fmax=420) * 0.012
    y, x = np.mgrid[0:N, 0:N]
    cell = N / n_cells
    lx, ly = (x % cell) / cell, (y % cell) / cell
    chips = np.zeros((N, N))
    for _ in range(9):
        cx, cy = int(r.integers(0, n_cells)), int(r.integers(0, n_cells))
        corner = (r.integers(0, 2), r.integers(0, 2))
        ox, oy = (cx + corner[0]) * cell, (cy + corner[1]) * cell
        rad = r.uniform(8, 20)
        chips = np.maximum(chips, smoothstep(rad, rad * 0.6, np.sqrt(((x - ox + N / 2) % N - N / 2) ** 2 + ((y - oy + N / 2) % N - N / 2) ** 2)))
    crk = np.zeros((N, N))
    for k in range(2):
        cx, cy = int(r.integers(0, n_cells)), int(r.integers(0, n_cells))
        c = cracks(r, 3, seg=(8, 18), width=(1, 2), steps=(6, 14))
        crk = np.maximum(crk, c * ((gx == cx) & (gy == cy)))
    spill = stain(r, 5, 1.0, 1.9) * 0.18
    scuff = streaks(r, 70, (14, 50), (1, 3), wobble=3) * 0.14
    v = 0.86 + tone + mott - spill - scuff - crk * 0.45 - chips * 0.25
    v = v * (1 - grout) + groutDirt * grout
    col = tint(v, (1.0, 0.99, 0.96))
    col = col * (1 - spill[..., None] * 0.6 * (1 - np.array(WARM)))
    height = -grout * 1.2 - crk * 1.6 - chips * 0.8 + mott * 2
    rough = 0.32 + grout * 0.55 + spill * 1.2 + scuff + chips * 0.4 + crk * 0.3
    save(out, "FloorTiles", col, height, rough, 1.6)


def ceiling_tiles(out):
    """suspended acoustic ceiling seen from below (2-stud tiles, 8 studs per tile): fissured tiles with uneven age,
    a painted T-bar grid with a shadow line, tide-marked water stains, mould spots"""
    r = rng_for("ceiling_tiles")
    n_cells = 4
    gx, gy = cell_index(n_cells)
    age = r.uniform(-0.06, 0.02, (n_cells, n_cells))[gx, gy]
    bar = grid_lines(n_cells, 7.0)
    shadow = np.clip(np.roll(grid_lines(n_cells, 3.0), 4, axis=0) + np.roll(grid_lines(n_cells, 3.0), 4, axis=1), 0, 1) * (1 - bar)
    fiss = dots(r, 9000, (0.5, 1.4), soft=0.4) * 0.16 + cracks(r, 260, seg=(2, 5), branch=0, width=(1, 1), steps=(1, 3), turn=0.8) * 0.12
    mott = fbm(r, f0=12, beta=1.6) * 0.015
    water = stain(r, 2.2, 0.8, 1.9)
    tide = np.clip(np.abs(np.sin(water * 9)) * water, 0, 1)
    mould = dots(r, 260, (0.8, 2.4), soft=0.8) * smoothstep(0.4, 1.0, water)
    v = 0.9 + age + mott - fiss - water * 0.1 - tide * 0.14 - mould * 0.35 - shadow * 0.14
    v = v * (1 - bar) + 0.84 * bar
    col = tint(v, (1.0, 0.99, 0.96))
    col = col * (1 - (water * 0.25 + tide * 0.5)[..., None] * (1 - np.array(WARM)) * 1.4)
    height = -fiss * 4 + bar * 1.0 - shadow * 0.5
    rough = 0.95 - bar * 0.4
    save(out, "CeilingTiles", col, height, rough, 1.4)


def vinyl_floor(out):
    """supermarket vinyl tiles (1 stud, 8 studs per tile): two alternating speckled tones, seams, heel scuffs,
    trolley wheel tracks, dirt patches and worn walkways"""
    r = rng_for("vinyl_floor")
    n_cells = 8
    gx, gy = cell_index(n_cells)
    checker = ((gx + gy) % 2).astype(float)
    tone = 0.86 - checker * 0.07 + r.uniform(-0.012, 0.012, (n_cells, n_cells))[gx, gy]
    speck = dots(r, 7000, (0.5, 1.4), soft=0.3) * 0.12 - dots(r, 2600, (0.5, 1.2), soft=0.3) * 0.06
    seam = grid_lines(n_cells, 1.6)
    y, x = np.mgrid[0:N, 0:N]
    tracks = np.zeros((N, N))
    for _ in range(6):
        x0 = r.uniform(0, N)
        wob = fbm(r, f0=2, beta=2.6) * 18
        for off in (0, 26):
            tracks = np.maximum(tracks, np.exp(-((((x - x0 - off - wob + N / 2) % N) - N / 2) / 1.3) ** 2) * r.uniform(0.3, 0.7))
    heel = streaks(r, 120, (10, 36), (2, 4), wobble=5) * 0.3
    dirt = stain(r, 3, 0.6, 1.8) * 0.12
    worn = smoothstep(0.2, 1.6, band(r, 200)) * 0.06
    v = tone + speck - seam * 0.18 - tracks * 0.08 - heel - dirt + worn * 0.5
    col = tint(v, (1.0, 0.98, 0.94))
    height = -seam * 0.8 + speck * 0.5
    rough = 0.42 + dirt * 1.4 + heel * 0.6 + worn * 1.8 + seam * 0.3
    save(out, "VinylFloor", col, height, rough, 1.2)


def carpet_worn(out):
    """cinema carpet (8 studs per tile): an original lattice motif in gold and navy on burgundy, fibre noise,
    flattened walkways, dark drink spills and gum spots"""
    r = rng_for("carpet_worn")
    y, x = np.mgrid[0:N, 0:N]
    p = N / 8
    u, v_ = (x % p) / p - 0.5, (y % p) / p - 0.5
    diamond = np.abs(u) + np.abs(v_)
    lattice = smoothstep(0.035, 0.015, np.abs(diamond - 0.5))
    centre = smoothstep(0.09, 0.06, np.sqrt(u * u + v_ * v_))
    ring = smoothstep(0.02, 0.0, np.abs(np.sqrt(u * u + v_ * v_) - 0.2)) * 0.8
    fibre = fbm(r, f0=120, beta=0.3, fmax=500) * 0.05 + fbm(r, f0=30, beta=1.0) * 0.03
    burg = np.array((0.42, 0.13, 0.15))
    gold = np.array((0.74, 0.58, 0.3))
    navy = np.array((0.16, 0.18, 0.3))
    col = burg[None, None, :] * (1 + fibre[..., None])
    col = col * (1 - lattice[..., None]) + gold * lattice[..., None]
    col = col * (1 - centre[..., None]) + navy * centre[..., None]
    col = col * (1 - ring[..., None]) + gold * 0.8 * ring[..., None]
    worn = smoothstep(0.1, 1.5, band(r, 220))
    spill = stain(r, 6, 1.1, 2.0)
    gum = dots(r, 90, (1.5, 3.5), soft=0.5)
    col = col * (1 + worn[..., None] * 0.12) * (1 - spill[..., None] * 0.45)
    col = col * (1 - gum[..., None]) + np.array((0.32, 0.3, 0.3)) * gum[..., None]
    height = fibre * 6 - worn * 0.4 + gum * 0.6
    rough = np.ones((N, N)) * 0.97 - spill * 0.15
    save(out, "CarpetWorn", col, height, rough, 1.2)


# ── Walls: the finishes of Soviet-era interiors (docs/look/WALLS.md) ─────────────────────────────────────────
# Two-tone corridors (gloss oil paint to 1.5 m, whitewash above), faded wallpaper, glazed wall tiles, bare brick, wood
# panelling. All near-neutral: Part.Color gives the hue (World.applyWear picks it from a palette).
def chips(rng, count, rad_rng, ypdf=None, squash=1.0, n=N):
    """ragged-edged chips (paint knocked off a corridor dado): irregular polygons, returns 0..1 (wraps round the edges)"""
    img, d = canvas(n)
    for _ in range(count):
        cx = rng.uniform(0, n)
        cy = ypdf(rng) if ypdf else rng.uniform(0, n)
        base = rng.uniform(*rad_rng)
        k = int(rng.integers(7, 12))
        a0 = rng.uniform(0, 2 * math.pi)
        pts = []
        for i in range(k):
            a = a0 + 2 * math.pi * i / k + rng.normal(0, 0.12)
            rad = base * rng.uniform(0.55, 1.15)
            pts.append((cx + n + math.cos(a) * rad, cy + n + math.sin(a) * rad * squash))
        d.polygon(pts, fill=1.0)
    return np.clip(blur(fold(img, n), 0.6), 0, 1)


def water_mark(rng, f0, thr, soft=0.14):
    """a damp stain with a tide line, smooth (no dust at the edge): returns (wash, edge), both 0..1. wash is the wetted
    area, edge the darker rim where the water stopped"""
    f = fbm(rng, f0=f0, beta=3.2) + fbm(rng, f0=f0 * 3, beta=2.4) * 0.2
    wash = smoothstep(thr - soft, thr + soft, f)
    edge = np.exp(-((f - thr) / (soft * 0.8)) ** 2) * 0.9
    return wash, edge


def paint_gloss(out):
    """gloss oil paint over plaster, the dado of a corridor (4.7 studs = 1.5 m per tile): fine horizontal brush marks and
    roller stipple, ragged chips that show the plaster, wide scuffs, scratches and dirt that gather toward the foot of the
    tile (a mild periodic band, because how a tile lands on a part is not guaranteed), a few drips"""
    r = rng_for("paint_gloss")
    y, x = np.mgrid[0:N, 0:N]
    foot = 0.5 + 0.5 * np.exp(-((((y - 0.86 * N + N / 2) % N) - N / 2) / (0.1 * N)) ** 2)  # periodic: a band of dirt about 15 cm up

    def low(g):
        return N * (1.0 - 0.55 * g.random() ** 1.6) if g.random() < 0.65 else g.uniform(0, N)

    mott = fbm(r, f0=3, beta=2.4) * 0.018 + band(r, 140) * 0.008
    brush = oriented(r, 70, 1.1) * 0.011 + oriented(r, 22, 0.8, 0.08) * 0.006
    stipple = fbm(r, f0=220, beta=0.0, fmax=420) * 0.009
    chip = chips(r, 30, (5, 17), ypdf=low, squash=0.85)
    rim = np.clip(blur(chip, 1.6) * 2.0, 0, 1) * (1 - chip)
    smear = blur(strokes(r, 60, (40, 160), (5, 11), ang=(-0.3, 0.3), ypdf=low), 1.4)
    scr = strokes(r, 40, (30, 120), (1, 2), ang=(-0.5, 0.5), ypdf=low)
    dirt = np.clip(foot * (0.04 + 0.03 * band(r, 90)), 0, 1)
    drips = streaks(r, 5, (70, 190), (2, 4), wobble=0.2)
    plaster = 0.93 + fbm(r, f0=24, beta=1.0) * 0.012
    paint = 0.8 + mott + brush + stipple - smear * 0.09 * foot - scr * 0.1 - dirt
    v = paint * (1 - chip) + plaster * chip + rim * 0.04
    col = tint(v, (1, 1, 1))
    height = brush * 20 + stipple * 22 - chip * 1.6 + rim * 0.5 + drips * 0.5 - scr * 0.3
    rough = 0.26 + brush * 1.2 + stipple + smear * 0.22 + scr * 0.3 + dirt * 2.0 + chip * 0.62 + rim * 0.15
    save(out, "PaintGloss", col, height, rough, 1.8)


def whitewash(out):
    """whitewash and distemper (10 studs per tile): matte and a little uneven, wide brush sweeps, chalky grain, a faint damp
    stain with a tide line, runs, a few flakes and hairlines. Far lighter wear than PlasterPeel"""
    r = rng_for("whitewash")
    mott = fbm(r, f0=3, beta=2.2) * 0.026 + band(r, 60) * 0.011
    sweep = oriented(r, 150, 18, 0.7) * 0.02 + oriented(r, 110, 14, -0.8) * 0.014
    grain = fbm(r, f0=110, beta=0.4, fmax=420) * 0.016
    wash, edge = water_mark(r, 2.5, 1.6)
    runs = streaks(r, 16, (120, 520), (2, 7)) * 0.06
    flake = smoothstep(2.7, 3.0, band(r, 5) * 0.8 + fbm(r, f0=70, beta=0.5) * 0.5 + stain(r, 4, 0.8, 1.8))
    crk = cracks(r, 4, seg=(6, 14), width=(1, 1), steps=(8, 22))
    v = 0.9 + mott + sweep + grain - wash * 0.03 - edge * 0.04 - runs - flake * 0.16 - crk * 0.12
    col = tint(v, (1, 1, 1)) * (1 - (wash * 0.15 + edge * 0.3)[..., None] * (1 - np.array(WARM)) * 1.2)
    height = mott * 2 + sweep * 6 + grain * 3 - flake - crk * 1.2
    rough = 0.93 + grain * 0.8 - runs * 0.3 - flake * 0.05
    save(out, "Whitewash", col, height, rough, 1.6)


STRIP = N // 4  # one roll of wallpaper, 0.5 m; four rolls hang side by side in a 2 m (6.25 stud) tile


def damask(u, v):
    """one 0.5 m cell of an original damask (u, v in -1..1 across the cell): an eight-lobed rosette with a ringed eye, four
    pointed leaves on the diagonals with a rib, bud pairs on the axes and a dot at each corner. Printed mask 0..1"""
    rr = np.sqrt(u * u + v * v)
    th = np.arctan2(v, u)
    lobe = 0.44 + 0.1 * np.cos(8 * th)
    rose = smoothstep(lobe + 0.025, lobe - 0.025, rr)
    gap = smoothstep(0.135, 0.15, rr) * smoothstep(0.215, 0.2, rr)
    ink = np.clip(rose * (1 - gap) + smoothstep(0.085, 0.07, rr), 0, 1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = (sx * u + sy * v) / math.sqrt(2) - 0.84
            b = (-sy * u + sx * v) / math.sqrt(2)
            t = a / 0.32
            hw = 0.16 * np.clip(1 - t * t, 0, 1) ** 0.75
            leaf = (np.abs(t) < 1) * smoothstep(hw + 0.025, hw - 0.025, np.abs(b))
            rib = smoothstep(0.035, 0.018, np.abs(b)) * (np.abs(t) < 0.86)
            ink = np.maximum(ink, leaf * (1 - rib))
    bud_v = smoothstep(1.15, 0.85, (u / 0.065) ** 2 + ((np.abs(v) - 0.8) / 0.15) ** 2)
    bud_u = smoothstep(1.15, 0.85, ((np.abs(u) - 0.8) / 0.15) ** 2 + (v / 0.065) ** 2)
    corner = smoothstep(0.1, 0.075, np.hypot(1 - np.abs(u), 1 - np.abs(v)))
    return np.clip(np.maximum.reduce([ink, bud_v, bud_u, corner]), 0, 1)


def lattice(x, y):
    """a geometric cell (128 px = 0.25 m): a thin diamond lattice, a ring in every other diamond and a dot in the rest,
    small squares where the lines cross. Printed mask 0..1"""
    p = 128.0
    s, t = (x + y) % p, (x - y) % p
    line = np.maximum(smoothstep(2.6, 1.3, np.minimum(s, p - s) / math.sqrt(2)), smoothstep(2.6, 1.3, np.minimum(t, p - t) / math.sqrt(2)))
    mx, my = x % p, y % p
    d1 = np.hypot(mx - 64, np.minimum(my, p - my))
    d2 = np.hypot(np.minimum(mx, p - mx), my - 64)
    ring = smoothstep(16.5, 15.2, d1) * smoothstep(11.0, 12.3, d1)
    dot = smoothstep(7.5, 6.0, d2)
    sq1 = smoothstep(5.8, 4.6, np.maximum(np.minimum(mx, p - mx), np.minimum(my, p - my)))
    sq2 = smoothstep(5.8, 4.6, np.maximum(np.abs(mx - 64), np.abs(my - 64)))
    return np.clip(np.maximum.reduce([line * 0.9, ring, dot, sq1, sq2]), 0, 1)


def pat_a(x, y, k, match):
    u = ((x % STRIP) - STRIP / 2) / (STRIP / 2)
    v = (((y + (k % 2) * (STRIP // 2) + match) % STRIP) - STRIP / 2) / (STRIP / 2)
    return damask(u, v)


def pat_b(x, y, k, match):
    return lattice(x, y + match)


def wallpaper(out, name, pattern, ink_tone, ink_rough, stripe, emboss, stains=False):
    """shared by the two wallpapers: four 0.5 m rolls hung side by side (a 2 m, 6.25 stud tile). Each seam shows as a dark
    line with a lifted edge, and the rolls differ a little in dye lot and in how the print was matched. With stains, patches
    have also faded in the light, water has run down and left tide marks, and two seams hang curled; those repeated every 2 m
    on a long wall (WALLS.md, pattern repeat), so the shipped tiles are clean and the stains come from the wall decals"""
    r = rng_for(name)
    y, x = np.mgrid[0:N, 0:N]
    k = x // STRIP
    dye = r.uniform(-0.016, 0.016, 4)[k]
    match = r.integers(-4, 5, 4)[k]
    ink = pattern(x, y, k, match)
    paper = 0.92 + dye + fbm(r, f0=120, beta=0.3, fmax=420) * 0.012 - stripe * (((x // 32) % 2) * 0.03)
    fade = smoothstep(0.1, 1.5, band(r, 300)) if stains else np.zeros((N, N))
    amt = ink * (0.88 + 0.12 * fbm(r, f0=40, beta=0.8)) * (1 - 0.6 * fade)
    v = paper * (1 - amt) + ink_tone * amt + fade * 0.025
    dx = ((x + STRIP // 2) % STRIP) - STRIP // 2
    seam = np.exp(-(dx / 0.9) ** 2)
    lip = np.exp(-((dx - 2.4) / 1.5) ** 2)
    v = v - seam * 0.2 + lip * 0.045
    water, tide, runs = np.zeros((N, N)), np.zeros((N, N)), np.zeros((N, N))
    if stains:
        w1, e1 = water_mark(r, 2.4, 1.35)
        w2, e2 = water_mark(r, 4.0, 1.7)
        water, tide = np.maximum(w1, w2), np.maximum(e1, e2)
        runs = streaks(r, 8, (150, 500), (2, 6)) * 0.07
    v = v - water * 0.04 - tide * 0.1 - runs
    rag = fbm(r, f0=60, beta=1.0)
    bare = np.zeros((N, N))
    flap = np.zeros((N, N))
    for xs, y0, length, wmax in (zip(r.choice([STRIP, 2 * STRIP, 3 * STRIP], 2, replace=False), r.uniform(0.05 * N, 0.55 * N, 2),
                                     r.uniform(240, 420, 2), r.uniform(24, 38, 2)) if stains else ()):
        t = (y - y0 + rag * 5) / length
        inside = ((t >= 0) & (t <= 1)).astype(float)
        w = wmax * np.clip(1 - t, 0, 1) ** 0.7
        dxr = (x - xs) % N
        bare = np.maximum(bare, inside * smoothstep(w, w - 2.0, dxr))
        flap = np.maximum(flap, inside * smoothstep(w - 9, w - 7, dxr) * smoothstep(w + 2, w, dxr))
    wall = 0.58 + fbm(r, f0=22, beta=1.0) * 0.04
    shade = np.clip(blur(flap, 3.0), 0, 1) * bare * (1 - flap)
    v = v * (1 - bare) + (wall - shade * 0.2) * bare
    v = v * (1 - flap) + 0.95 * flap
    col = tint(v, (1, 1, 1)) * (1 - (water * 0.2 + tide * 0.5)[..., None] * (1 - np.array(WARM)) * 1.2)
    height = -seam * 0.9 + lip * 0.25 + amt * emboss - bare * 1.6 + flap * 1.4 + fbm(r, f0=100, beta=0.4, fmax=400) * 0.1
    rough = 0.76 + amt * ink_rough - stripe * (((x // 32) % 2) * 0.12) + bare * 0.14 - flap * 0.06
    save(out, name.replace("wallpaper_", "Wallpaper"), col, height, rough, 1.4)


def wallpaper_a(out):
    """wallpaper A: a flocked damask, tone on tone (the print stands proud and matte)"""
    wallpaper(out, "wallpaper_A", pat_a, 0.7, 0.08, 0.0, 0.7)


def wallpaper_b(out):
    """wallpaper B: a vinyl-coated geometric, diamond lattice over soft vertical stripes (the print is flatter and glossier)"""
    wallpaper(out, "wallpaper_B", pat_b, 0.72, -0.2, 1.0, 0.25)


def wall_tiles(out):
    """glazed wall tiles, 15 cm squares in a regular grid (16 x 16 per tile = 2.4 m = 7.5 studs): a bevelled glaze edge, a
    little tone variation tile to tile, grout gone dark, soap scum, crazing, six cracked tiles, ragged chipped corners and two
    missing tiles that leave the notched adhesive showing"""
    r = rng_for("wall_tiles")
    n = 16
    T = N // n
    y, x = np.mgrid[0:N, 0:N]
    gx, gy = cell_index(n)
    lx, ly = (x % T).astype(float), (y % T).astype(float)
    ex, ey = np.minimum(lx, T - lx), np.minimum(ly, T - ly)
    e = np.minimum(ex, ey)
    g = 3.0
    body = smoothstep(g - 0.7, g + 0.7, e)
    grout = 1 - body
    bev = smoothstep(g + 4.5, g + 0.5, e) * body
    lit = ((ly < T / 2) & (ey <= ex)) | ((lx < T / 2) & (ex < ey))
    hl, sh = bev * lit, bev * (~lit)
    tone = r.uniform(-0.04, 0.03, (n, n))[gx, gy]
    pool = fbm(r, f0=8, beta=1.6) * 0.012
    scum = streaks(r, 70, (30, 160), (2, 6)) * 0.05
    craze = cracks(r, 150, seg=(3, 8), branch=0.0, width=(1, 1), steps=(2, 6), turn=0.9) * 0.06
    rag = fbm(r, f0=30, beta=0.5)
    bleed = blur(grout, 5.0) * 0.12
    taken = set()

    def free_cell():
        while True:
            c = (int(r.integers(0, n)), int(r.integers(0, n)))
            if c not in taken:
                taken.add(c)
                return c

    def tile_crack():
        img = Image.new("F", (T, T), 0.0)
        d = ImageDraw.Draw(img)
        sides = r.choice(4, 2, replace=False)

        def pt(s):
            q = r.uniform(0.15, 0.85) * T
            return [(q, 0), (T - 1, q), (q, T - 1), (0, q)][s]

        a, b = pt(sides[0]), pt(sides[1])
        pts = [a]
        for f in (0.3, 0.55, 0.8):
            pts.append((a[0] + (b[0] - a[0]) * f + r.normal(0, 3.0), a[1] + (b[1] - a[1]) * f + r.normal(0, 3.0)))
        pts.append(b)
        d.line(pts, fill=1.0, width=2)
        return np.array(img)

    def tile_chip():
        img = Image.new("F", (T, T), 0.0)
        d = ImageDraw.Draw(img)
        cx, cy = (0 if r.random() < 0.5 else T), (0 if r.random() < 0.5 else T)
        base = r.uniform(7, 15)
        k = 8
        a0 = r.uniform(0, 2 * math.pi)
        d.polygon([(cx + math.cos(a0 + 2 * math.pi * i / k) * base * r.uniform(0.55, 1.15),
                    cy + math.sin(a0 + 2 * math.pi * i / k) * base * r.uniform(0.55, 1.15)) for i in range(k)], fill=1.0)
        return np.array(img)

    crack = np.zeros((N, N))
    for _ in range(6):
        cx, cy = free_cell()
        crack[cy * T:(cy + 1) * T, cx * T:(cx + 1) * T] = tile_crack()
    crack = np.clip(blur(crack, 0.5) * 1.6, 0, 1) * body
    chip = np.zeros((N, N))
    for _ in range(14):
        cx, cy = int(r.integers(0, n)), int(r.integers(0, n))
        sl = (slice(cy * T, (cy + 1) * T), slice(cx * T, (cx + 1) * T))
        chip[sl] = np.maximum(chip[sl], tile_chip())
    chip = np.clip(blur(chip, 0.6), 0, 1) * body
    miss = np.zeros((N, N))
    for _ in range(2):
        cx, cy = free_cell()
        miss = np.maximum(miss, ((gx == cx) & (gy == cy)) * smoothstep(0.2, 1.6, e + rag * 0.7))
    ridge = 0.5 + 0.5 * np.sin(2 * math.pi * (y + fbm(r, f0=3, beta=2.0) * 4) / 13.0)
    inner = miss * (1 - np.clip(blur(miss, 5.0), 0, 1))
    adhesive = 0.52 + ridge * 0.1 + fbm(r, f0=50, beta=0.8) * 0.03 - inner * 0.2
    aoMiss = np.clip(blur(miss, 3) - miss, 0, 1)
    groutCol = 0.52 + fbm(r, f0=8, beta=1.6) * 0.07 - scum * 1.5
    v = 0.9 + tone + pool + hl * 0.04 - sh * 0.055 - scum - craze * body - crack * 0.4 - chip * 0.2 - aoMiss * 0.12 - bleed * body
    v = v * body + groutCol * grout
    v = v * (1 - miss) + adhesive * miss
    col = tint(v, (1, 1, 1))
    height = -grout * 1.9 - bev * 0.4 - crack * 1.5 - chip * 1.3 + miss * (-3.2 + ridge * 1.2) + pool * 4
    rough = 0.14 + fbm(r, f0=12, beta=1.0) * 0.015 + scum * 1.8 + crack * 0.5 + chip * 0.65 + grout * 0.78 + miss * 0.8
    save(out, "WallTiles", col, height, rough, 2.0)


def brick_wall(out):
    """running-bond brick (6.5 studs per tile, 8 bricks x 28 courses: a 250 x 65 mm brick with 10 mm joints): a tone and a
    small warm or cool shift per brick, a few burnt dark ones, sandy faces, shaded edges, struck mortar with a few joints
    washed out, chipped corners, three spalled faces, salts and run marks"""
    r = rng_for("brick_wall")
    rows, per = 28, 8
    ch, bw = N / rows, N / per
    jm = 4.6
    y, x = np.mgrid[0:N, 0:N]
    ri = np.floor(y / ch).astype(int)
    xs = (x + (ri % 2) * (bw / 2)) % N
    ci = np.floor(xs / bw).astype(int) % per
    lxp, lyp = xs - ci * bw, y - ri * ch
    e = np.minimum(np.minimum(lxp, bw - lxp), np.minimum(lyp, ch - lyp))
    mortar = smoothstep(jm / 2 + 0.9, jm / 2 - 0.9, e)
    face = 1 - mortar
    tone = r.normal(0, 0.05, (rows, per))
    tone = tone + np.where(r.random((rows, per)) < 0.08, -0.15, 0.0) + np.where(r.random((rows, per)) < 0.07, 0.07, 0.0)
    tone = tone[ri, ci]
    warm = r.uniform(-0.05, 0.05, (rows, per))[ri, ci]
    sand = fbm(r, f0=90, beta=0.3, fmax=420) * 0.028 + fbm(r, f0=14, beta=1.2) * 0.018
    pits = dots(r, 5200, (0.6, 1.3), soft=0.3) * 0.05
    ao = smoothstep(jm / 2 + 6, jm / 2 + 0.5, e) * face * 0.1
    wash = smoothstep(0.9, 1.9, band(r, 55)) * mortar
    rag = fbm(r, f0=34, beta=0.6)
    chip = np.zeros((N, N))
    for _ in range(9):
        R, Cc = int(r.integers(0, rows)), int(r.integers(0, per))
        cxp = 0 if r.random() < 0.5 else bw
        cyp = 0 if r.random() < 0.5 else ch
        rad = r.uniform(10, 22) * (1 + 0.3 * rag)
        dd = np.sqrt((lxp - cxp) ** 2 + ((lyp - cyp) * 2.6) ** 2)
        chip = np.maximum(chip, ((ri == R) & (ci == Cc)) * smoothstep(rad + 1.5, rad - 1.5, dd))
    chip = chip * face
    spall = np.zeros((N, N))
    local = fbm(r, f0=20, beta=1.2)
    for _ in range(3):
        R, Cc = int(r.integers(0, rows)), int(r.integers(0, per))
        spall = np.maximum(spall, ((ri == R) & (ci == Cc)) * face * smoothstep(-0.2, 0.3, local))
    eff = smoothstep(1.3, 2.1, band(r, 45)) * 0.06
    wet = streaks(r, 40, (150, 600), (2, 8)) * 0.07
    soot = stain(r, 2.5, 0.8, 1.9) * 0.07
    base = 0.74 + tone + sand - pits - ao
    brickRGB = np.dstack([base * (1 + warm), base, base * (1 - warm)])
    mortarV = 0.88 + fbm(r, f0=40, beta=0.8) * 0.04 + dots(r, 3000, (0.6, 1.2), soft=0.3) * 0.04 - wash * 0.14
    col = brickRGB * (1 - mortar[..., None]) + tint(mortarV, (1, 1, 1)) * mortar[..., None]
    core = tint(0.84 + fbm(r, f0=60, beta=0.5) * 0.02, (1, 0.98, 0.95))
    col = col * (1 - chip[..., None]) + core * chip[..., None]
    col = col * (1 - (spall * 0.75)[..., None]) + core * 0.92 * (spall * 0.75)[..., None]
    col = col * (1 + eff[..., None]) * (1 - (wet + soot)[..., None] * (1 - np.array(WARM)) * 1.2) - (wet * 0.6)[..., None]
    height = -blur(mortar, 0.8) * 1.8 - wash * 0.8 + sand * 4 - pits * 6 - chip * 1.2 - spall * 0.9
    rough = 0.88 + sand * 1.2 + mortar * 0.08 + chip * 0.04 + spall * 0.04 - eff * 1.5
    save(out, "BrickWall", col, height, rough, 2.2)


def wood_panel(out):
    """vertical wood panelling (5 studs = 1.6 m per tile, 16 boards of 10 cm): V grooves between the boards, flat-sawn grain
    with a few knots, a tone per board, varnish worn through in long patches, scratches and a water mark"""
    r = rng_for("wood_panel")
    boards = 16
    T = N // boards
    y, x = np.mgrid[0:N, 0:N]
    bi = x // T
    lx = (x % T).astype(float)
    dg = np.minimum(lx, T - lx)
    groove = smoothstep(2.9, 1.1, dg)
    flank = smoothstep(7.0, 2.9, dg) * (1 - groove)
    lit = lx < T / 2
    tone = r.uniform(-0.06, 0.055, boards)[bi]
    hue = r.uniform(-0.025, 0.025, boards)[bi]
    per = r.uniform(7.0, 13.0, boards)[bi]
    ph = r.uniform(0, 1, boards)[bi]
    amp = r.uniform(2.0, 7.0, boards)[bi]
    ph2 = r.uniform(0, 2 * math.pi, boards)[bi]
    drift = oriented(r, 260, 10, math.pi / 2) * 6.0 + oriented(r, 90, 3, math.pi / 2) * 1.6
    swing = np.sin(2 * math.pi * 2 * y / N + ph2) * amp
    ring = 0.5 + 0.5 * np.sin(2 * math.pi * ((lx + drift + swing) / per + ph))
    late = smoothstep(0.7, 0.98, ring)
    fibre = oriented(r, 140, 0.6, math.pi / 2) * 0.02
    kn = np.zeros((N, N))
    kring = np.zeros((N, N))
    for _ in range(6):
        b = int(r.integers(0, boards))
        kx, ky = (b + r.uniform(0.3, 0.7)) * T, r.uniform(0, N)
        dx, dy = x - kx, ((y - ky + N / 2) % N) - N / 2
        kk = np.exp(-((dx / 5.5) ** 2 + (dy / 13.0) ** 2))
        kn = np.maximum(kn, kk)
        kring = np.maximum(kring, kk * (0.5 + 0.5 * np.sin(np.sqrt((dx / 2.2) ** 2 + (dy / 5.2) ** 2) * 2.8)))
    worn = smoothstep(0.8, 1.7, oriented(r, 260, 20, math.pi / 2) + band(r, 160) * 0.4)
    age = stain(r, 3, 0.4, 1.8) * 0.07
    wash, edge = water_mark(r, 2.5, 1.5)
    scr = strokes(r, 70, (10, 55), (1, 1), ang=(-math.pi, math.pi))
    v = 0.74 + tone - late * 0.12 + fibre - kn * 0.2 - kring * 0.07 - groove * 0.34 + flank * lit * 0.03 - flank * (~lit) * 0.05
    v = v + worn * 0.06 + scr * 0.07 - age - wash * 0.04 - edge * 0.06
    col = tint(v, (1.0, 0.97, 0.93)) * (1 + hue[..., None] * np.array([1.0, 0.0, -1.0])[None, None, :])
    col = col * (1 - (wash * 0.15 + edge * 0.3)[..., None] * (1 - np.array(WARM)) * 1.1)
    height = late * 0.45 * (1.2 - worn) + fibre * 6 - groove * 2.8 - flank * lit * 1.0 - scr * 0.5
    rough = 0.3 + fibre * 2 + worn * 0.4 + groove * 0.5 + scr * 0.25 + age * 0.5
    save(out, "WoodPanel", col, height, rough, 2.0)


PREVIEW = [
    ("PaintGloss", (0.42, 0.52, 0.40)), ("Whitewash", (0.78, 0.76, 0.68)), ("WallpaperA", (0.74, 0.70, 0.58)),
    ("WallpaperB", (0.62, 0.69, 0.74)), ("WallTiles", (0.70, 0.76, 0.74)), ("BrickWall", (0.55, 0.36, 0.28)),
    ("WoodPanel", (0.58, 0.44, 0.30)),
]


def walls_preview(out):
    """contact sheet of the wall set: per material a colour tile (tinted as in game, shown 2 x 2 so the repeat is visible),
    the neutral colour map, the normal map and the roughness map. Reads the PNGs in out, writes walls_preview.png next to
    the materials folder (or into out when it is not called 'materials')"""
    cell, pad, head = 256, 8, 18
    cols, rows = 4, len(PREVIEW)
    sheet = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + head + pad) + pad), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    for i, (nm, hue) in enumerate(PREVIEW):
        c = np.array(Image.open(os.path.join(out, f"ZR_MAT_{nm}_Color.png")).convert("RGB"), dtype=np.float64) / 255
        tinted = np.clip(c * np.array(hue)[None, None, :] * 1.15, 0, 1)
        tiled = np.tile(tinted, (2, 2, 1))
        pics = [Image.fromarray((tiled * 255).astype(np.uint8)), Image.open(os.path.join(out, f"ZR_MAT_{nm}_Color.png")).convert("RGB"),
                Image.open(os.path.join(out, f"ZR_MAT_{nm}_Normal.png")).convert("RGB"), Image.open(os.path.join(out, f"ZR_MAT_{nm}_Rough.png")).convert("RGB")]
        labels = [f"ZR_{nm} tinted, 2x2 tiles", "colour map (neutral)", "normal map", "roughness map"]
        y0 = pad + i * (cell + head + pad)
        for j, (pic, lab) in enumerate(zip(pics, labels)):
            x0 = pad + j * (cell + pad)
            d.text((x0, y0), lab, fill=(220, 220, 210))
            sheet.paste(pic.resize((cell, cell), Image.LANCZOS), (x0, y0 + head))
    parent = os.path.dirname(os.path.abspath(out)) if os.path.basename(os.path.abspath(out)) == "materials" else out
    sheet.save(os.path.join(parent, "walls_preview.png"), optimize=True)
    print("preview ->", os.path.join(parent, "walls_preview.png"))


ALL = {
    "ConcreteWorn": concrete_worn, "ConcretePanel": concrete_panel, "PlasterPeel": plaster_peel,
    "MetalPaint": metal_paint, "Corrugated": corrugated, "AsphaltCracked": asphalt_cracked,
    "FloorConcrete": floor_concrete, "WoodWeathered": wood_weathered,
    "Terrazzo": terrazzo, "FloorTiles": floor_tiles, "CeilingTiles": ceiling_tiles, "VinylFloor": vinyl_floor,
    "CarpetWorn": carpet_worn,
    "PaintGloss": paint_gloss, "Whitewash": whitewash, "WallpaperA": wallpaper_a, "WallpaperB": wallpaper_b,
    "WallTiles": wall_tiles, "BrickWall": brick_wall, "WoodPanel": wood_panel,
    "WallsPreview": walls_preview,  # not a material: the contact sheet of the wall set (needs those seven built first)
}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = sys.argv[2:] or list(ALL)
    for nm in names:
        ALL[nm](out)
        print("built", nm)

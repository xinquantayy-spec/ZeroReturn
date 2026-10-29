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


ALL = {
    "ConcreteWorn": concrete_worn, "ConcretePanel": concrete_panel, "PlasterPeel": plaster_peel,
    "MetalPaint": metal_paint, "Corrugated": corrugated, "AsphaltCracked": asphalt_cracked,
    "FloorConcrete": floor_concrete, "WoodWeathered": wood_weathered,
    "Terrazzo": terrazzo, "FloorTiles": floor_tiles, "CeilingTiles": ceiling_tiles, "VinylFloor": vinyl_floor,
    "CarpetWorn": carpet_worn,
}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = sys.argv[2:] or list(ALL)
    for nm in names:
        ALL[nm](out)
        print("built", nm)

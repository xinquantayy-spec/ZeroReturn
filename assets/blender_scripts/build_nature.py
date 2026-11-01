"""Zero Return - M13 nature kit for PINEWATCH (woods-type map). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_nature.py").read(), g)
Generates objects in scene "ZR_Nature", exports assets/exports/ZR_Nature.fbx (+ .blend source + .meta.json).
All geometry is original and procedural (no external assets). Vertex colour only, low poly (mobile-safe).

Trees come in two parts that share one origin (base of the trunk):
  *_T  trunk: the server makes it solid (blocks movement, bullets and sight)
  *_C  crown: no collision and no queries (shots and AI sight pass; it hides you from other players' eyes)
Other pieces (origin bottom-centre): rocks, a fallen log, a stump and a log pile are solid gameplay props;
bushes, ferns, grass and reeds are cosmetic (bushes are server-placed concealment, the rest client detail).
"""
import math, os, sys, random
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
import importlib, zr_lib
importlib.reload(zr_lib)
from zr_lib import Builder, hexc, grey, batch_scene, export_batch, vnoise
from mathutils import Vector

R = math.radians


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def mul(c, k):
    return (min(1, c[0] * k), min(1, c[1] * k), min(1, c[2] * k), 1.0)


BARK, BARK_D, BARK_L = hexc("57463A"), hexc("3A2F25"), hexc("75624F")
NEEDLE = [hexc("34482F"), hexc("3C5235"), hexc("2F4129"), hexc("46593A")]
ROCK, ROCK_D, MOSS = hexc("7A7A71"), hexc("595953"), hexc("56623A")
LEAF = [hexc("45542F"), hexc("4F5E33"), hexc("3D4A2D")]


def trunk(b, h, r0, r1, seed, roots=True):
    rnd = random.Random(seed)
    # a slightly bent trunk from two tapered segments
    lean = Vector((rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), 0))
    mid = Vector((0, 0, h * 0.5)) + lean * 0.5
    top = Vector((0, 0, h)) + lean
    b.cyl((0, 0, -0.4), tuple(mid), r0, BARK, r2=(r0 + r1) / 2, seg=7)
    b.cyl(tuple(mid), tuple(top), (r0 + r1) / 2, BARK, r2=r1, seg=7)
    if roots:
        for k in range(4):
            a = k * math.pi / 2 + rnd.uniform(-0.4, 0.4)
            b.cyl((math.cos(a) * r0 * 0.5, math.sin(a) * r0 * 0.5, 0.7), (math.cos(a) * r0 * 1.7, math.sin(a) * r0 * 1.7, -0.15), r0 * 0.38, BARK_D, r2=r0 * 0.12, seg=5)

    def bark(p, c):
        t = max(0.0, min(1.0, p.z / max(1.0, h)))
        n = vnoise(p, 1.3, seed)
        base = mix(BARK_D, BARK, min(1.0, t * 3.0))
        return mul(mix(base, BARK_L, max(0.0, n) * 0.35), 1 + 0.06 * n)
    b.paint_fn(bark)


def crown(b, base, top, rmax, tiers, seed, taper=0.86, droop=0.0):
    rnd = random.Random(seed)
    for i in range(tiers):
        t = i / max(1, tiers - 1)
        z0 = base + (top - base - 2.6) * t
        r = rmax * (1 - t * taper) + rnd.uniform(-0.25, 0.25)
        hgt = 2.6 + 2.4 * (1 - t)
        col = NEEDLE[rnd.randrange(len(NEEDLE))]
        for layer in range(2):
            ang = rnd.uniform(0, 6.283)
            off = Vector((math.cos(ang), math.sin(ang), 0)) * rnd.uniform(0.0, 0.35 * r)
            rr = r * (1.0 if layer == 0 else 0.78)
            b.cyl((off.x, off.y, z0 - droop * (1 - t) + layer * 0.9), (off.x * 0.3, off.y * 0.3, z0 + hgt + layer * 0.6), rr, mul(col, 0.92 + 0.12 * layer), r2=0.0, seg=8 if layer == 0 else 7)
    b.cyl((0, 0, top - 2.8), (0, 0, top + 0.6), 0.9, NEEDLE[1], r2=0.0, seg=6)

    def shade(p, c):
        # darker inside and low, lighter tips; a little noise
        k = 0.72 + 0.38 * max(0.0, min(1.0, (p.z - base) / max(1.0, top - base)))
        n = vnoise(p, 0.8, seed + 3)
        return mul(c, k * (1 + 0.08 * n))
    b.paint_fn(shade)


# foliage atlas (assets/textures/gen_foliage.py): four 512 cells in a 1024 image; 0 spruce dark, 1 spruce young,
# 2 birch, 3 shrub. A spray station at fraction f of its length, across a (-1 right edge .. 1 left edge), maps to the cell.
def _env(f):
    pts = ((0.0, 0.18), (0.5, 0.8), (1.0, 0.12))
    if f <= 0.5:
        a, b, t = pts[0][1], pts[1][1], f / 0.5
    else:
        a, b, t = pts[1][1], pts[2][1], (f - 0.5) / 0.5
    return (a + (b - a) * t) / 0.8 * 0.92


def atlas_uv(cell, f, across):
    ox, oy = (cell % 2) * 512, (cell // 2) * 512
    x = ox + (0.03 + 0.94 * f) * 512
    y = oy + 256 - across * _env(f) * 250
    return (x / 1024.0, 1.0 - y / 1024.0)


def crown_whorl(b, base, top, rmax, tiers, seed, taper=0.86, droop=0.0):
    """A conifer crown as whorls of drooping, ragged branch sprays with open gaps between them (owner 2026-11-01: the
    stacked-cone crowns read as solid green blocks). Each spray is a thin double-sided plate along a bent spine, wide in
    the middle and narrow at the root and tip; light and sight pass between sprays and between whorls. About 1,300
    triangles a crown, vertex colour only (no textures, no transparency: the cost stays that of an opaque mesh)."""
    rnd = random.Random(seed)
    span = top - base
    rmax = rmax * 1.22  # sprays need more reach than solid cones to read as full
    whorls = tiers * 2 - 1
    for i in range(whorls):
        t = i / max(1, whorls - 1)
        z = base + span * 0.9 * t + rnd.uniform(-0.3, 0.3)
        r = max(0.9, rmax * (1 - t * taper) * rnd.uniform(0.85, 1.1))
        k = 7 if t < 0.5 else (6 if t < 0.8 else 4)
        a0 = rnd.uniform(0, 6.283)
        for j in range(k):
            a = a0 + j * 6.283 / k + rnd.uniform(-0.28, 0.28)
            col = NEEDLE[rnd.randrange(len(NEEDLE))]
            ca, sa = math.cos(a), math.sin(a)
            px, py = -sa, ca
            rr = r * rnd.uniform(0.75, 1.05)
            dn = (0.30 + droop * 0.25) * rr * (1 - 0.45 * t) * rnd.uniform(0.75, 1.25)
            # stations along the spine: (fraction of the length, width as a fraction of the reach)
            st = ((0.0, 0.18), (0.5, 0.8), (1.0, 0.12))
            cell = 0 if rnd.random() < 0.65 else 1
            L, C, R = [], [], []
            for f, w in st:
                d = rr * f
                h = z - dn * (f ** 1.4) + (0.10 * rr if f == 1.0 else 0.0) * (1 - t)
                cx, cy = ca * d, sa * d
                ww = rr * w * rnd.uniform(0.85, 1.15)
                ridge = 0.05 * ww
                # the side twigs hang from the spine (a comb spruce), so each spray is a tent rather than a flat plate
                # and a whorl still reads when seen level from the side (2026-11-01: flat plates vanished edge-on)
                drop = ww * rnd.uniform(0.44, 0.6)
                C.append((cx, cy, h + ridge))
                L.append((cx + px * ww / 2 + ca * rnd.uniform(-0.15, 0.15) * ww, cy + py * ww / 2 + sa * rnd.uniform(-0.15, 0.15) * ww, h - drop + rnd.uniform(-0.1, 0.1)))
                R.append((cx - px * ww / 2 + ca * rnd.uniform(-0.15, 0.15) * ww, cy - py * ww / 2 + sa * rnd.uniform(-0.15, 0.15) * ww, h - drop + rnd.uniform(-0.1, 0.1)))
            for q in range(len(st) - 1):
                f0, f1 = st[q][0], st[q + 1][0]
                b.face_uv((L[q], C[q], C[q + 1], L[q + 1]), (atlas_uv(cell, f0, 1), atlas_uv(cell, f0, 0), atlas_uv(cell, f1, 0), atlas_uv(cell, f1, 1)), col, double=True)
                b.face_uv((C[q], R[q], R[q + 1], C[q + 1]), (atlas_uv(cell, f0, 0), atlas_uv(cell, f0, -1), atlas_uv(cell, f1, -1), atlas_uv(cell, f1, 0)), col, double=True)
    # the leader: a short spike at the top
    b.cyl((0, 0, top - 2.4), (0, 0, top + 0.5), 0.45, NEEDLE[1], r2=0.0, seg=5)

    def shade(p, c):
        # dark inside and low, lighter at the tips and the top; a little noise
        rad = math.sqrt(p.x * p.x + p.y * p.y)
        hz = max(0.0, min(1.0, (p.z - base) / max(1.0, span)))
        k = (0.62 + 0.30 * hz) * (0.76 + 0.36 * min(1.0, rad / max(1.0, rmax * 0.75)))
        n = vnoise(p, 0.9, seed + 3)
        return mul(c, k * (1 + 0.09 * n))
    b.paint_fn(shade)


def snag(b):
    trunk(b, 24, 0.7, 0.18, 41)
    rnd = random.Random(42)
    for k in range(6):
        z = rnd.uniform(6, 21)
        a = rnd.uniform(0, 6.283)
        L = rnd.uniform(1.0, 2.6)
        b.cyl((0, 0, z), (math.cos(a) * L, math.sin(a) * L, z + rnd.uniform(-0.6, 0.4)), 0.18, grey(0.42), r2=0.05, seg=5)
    b.paint_fn(lambda p, c: mul(mix(c, grey(0.5), 0.55), 0.95 + 0.1 * vnoise(p, 1.1, 7)))


def rock(b, size, seed, mossy=0.45, pieces=1, spread=0.0):
    rnd = random.Random(seed)
    for k in range(pieces):
        s = (size[0] * rnd.uniform(0.75, 1.1), size[1] * rnd.uniform(0.75, 1.1), size[2] * rnd.uniform(0.7, 1.0))
        off = (rnd.uniform(-spread, spread), rnd.uniform(-spread, spread), 0)
        # keep the authored proportions (wide boulders, flat slabs): only a small tilt and a free spin
        rot = (rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), rnd.uniform(0, 6.283))
        b.chunk((off[0], off[1], s[2] * 0.42), s, ROCK, seed=rnd.randint(0, 9999), rough=0.22, rot=rot, subdiv=2 if pieces == 1 else 1)

    def paint(p, c):
        n = vnoise(p, 0.9, seed)
        col = mix(ROCK_D, ROCK, 0.55 + 0.45 * n)
        top = max(0.0, min(1.0, (p.z - size[2] * 0.45) / max(0.5, size[2] * 0.5)))
        return mix(col, MOSS, mossy * top * (0.6 + 0.4 * max(0.0, vnoise(p, 2.1, seed + 9))))
    b.paint_fn(paint)
    b.ao(0, max(1.0, size[2]), 0.6, 1.0)


def log(b, length, r, seed):
    rnd = random.Random(seed)
    b.cyl((-length / 2, 0, r * 0.95), (length / 2, 0, r * 0.9), r, BARK, r2=r * 0.85, seg=8)
    for k in range(3):
        x = rnd.uniform(-length / 2 + 1, length / 2 - 1)
        a = rnd.uniform(0.3, 2.8)
        b.cyl((x, 0, r), (x + rnd.uniform(-0.4, 0.4), math.cos(a) * 1.2, r + math.sin(a) * 1.2), 0.18, BARK_D, r2=0.06, seg=5)
    # sawn ends
    for sx in (-1, 1):
        b.cyl((sx * length / 2, 0, r * 0.93), (sx * (length / 2 + 0.02), 0, r * 0.93), r * 0.92, hexc("9C8466"), seg=8)
    b.paint_fn(lambda p, c: mul(c, 0.9 + 0.12 * vnoise(p, 1.4, seed)))


def stump(b):
    b.cyl((0, 0, -0.2), (0, 0, 1.3), 0.95, BARK, r2=0.85, seg=8)
    b.cyl((0, 0, 1.3), (0, 0, 1.36), 0.84, hexc("8E775A"), seg=8)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        b.cyl((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.5), (math.cos(a) * 1.5, math.sin(a) * 1.5, -0.1), 0.3, BARK_D, r2=0.1, seg=5)


def logpile(b):
    rnd = random.Random(51)
    rows = [4, 3, 2, 1]
    r = 0.62
    for j, n in enumerate(rows):
        for i in range(n):
            y = (i - (n - 1) / 2) * r * 2.05
            z = r + j * r * 1.75
            L = 10 + rnd.uniform(-0.5, 0.5)
            x0 = rnd.uniform(-0.3, 0.3)
            b.cyl((x0 - L / 2, y, z), (x0 + L / 2, y, z), r * rnd.uniform(0.9, 1.05), mul(BARK, rnd.uniform(0.85, 1.1)), seg=7)
            for sx in (-1, 1):
                b.cyl((x0 + sx * L / 2, y, z), (x0 + sx * (L / 2 + 0.02), y, z), r * 0.88, hexc("A08A6A"), seg=7)
    # stakes holding the pile
    for sx in (-3.5, 3.5):
        for sy in (-2.9, 2.9):
            b.box((sx, sy, 1.6), (0.25, 0.25, 3.4), BARK_D)
    b.ao(0, 4.0, 0.7, 1.0)


def bush(b, size, seed, parts=5):
    rnd = random.Random(seed)
    for k in range(parts):
        s = (size[0] * rnd.uniform(0.45, 0.7), size[1] * rnd.uniform(0.45, 0.7), size[2] * rnd.uniform(0.55, 0.85))
        c = (rnd.uniform(-size[0] / 3, size[0] / 3), rnd.uniform(-size[1] / 3, size[1] / 3), s[2] * 0.5)
        b.chunk(c, s, LEAF[rnd.randrange(len(LEAF))], seed=rnd.randint(0, 9999), rough=0.25, subdiv=1)
    b.paint_fn(lambda p, c: mul(c, 0.8 + 0.3 * max(0.0, min(1.0, p.z / max(0.5, size[2])))))


BIRCH_LEAF = [hexc("5E7036"), hexc("6B7B3C"), hexc("55682F"), hexc("71823F")]
BIRCH_BARK, BIRCH_MARK = hexc("D8D4C6"), hexc("2F2B27")


def spray(b, root, d, length, width, col, rnd, droop=0.25, rise=0.0, cell=3):
    """one leafy spray: a thin double-sided plate along a bent spine from root along the unit vector d (2 segments,
    16 triangles), wide in the middle, narrow at both ends; used by the bush and birch generators"""
    up = Vector((0, 0, 1))
    side = d.cross(up)
    if side.length < 0.01:
        side = Vector((1, 0, 0))
    side.normalize()
    # bank the plate around its spine at random and let its edges hang (a tent), so a clump reads from every side
    roll = rnd.uniform(-0.6, 0.6)
    side = (side * math.cos(roll) + d.cross(side) * math.sin(roll)).normalized()
    nrm = side.cross(d).normalized()
    if nrm.z < 0:
        nrm = -nrm
    st = ((0.0, 0.18), (0.5, 0.8), (1.0, 0.12))
    L, C, R = [], [], []
    for f, w in st:
        p = Vector(root) + d * (length * f) + up * (rise * length * f - droop * length * (f ** 1.5))
        ww = width * w * rnd.uniform(0.85, 1.15)
        drop = ww * rnd.uniform(0.2, 0.34)
        C.append(tuple(p + nrm * (0.05 * ww)))
        L.append(tuple(p + side * (ww / 2) - nrm * drop + up * rnd.uniform(-0.04, 0.04) * length))
        R.append(tuple(p - side * (ww / 2) - nrm * drop + up * rnd.uniform(-0.04, 0.04) * length))
    for q in range(2):
        f0, f1 = st[q][0], st[q + 1][0]
        b.face_uv((L[q], C[q], C[q + 1], L[q + 1]), (atlas_uv(cell, f0, 1), atlas_uv(cell, f0, 0), atlas_uv(cell, f1, 0), atlas_uv(cell, f1, 1)), col, double=True)
        b.face_uv((C[q], R[q], R[q + 1], C[q + 1]), (atlas_uv(cell, f0, 0), atlas_uv(cell, f0, -1), atlas_uv(cell, f1, -1), atlas_uv(cell, f1, 0)), col, double=True)


def bush_sprays(b, size, seed, n=14):
    """a shrub as a clump of leafy sprays rising and arching out from a low centre, with gaps between them (owner
    2026-11-01: solid clumps read as green rocks); about 450 triangles"""
    rnd = random.Random(seed)
    sx, sy, sz = size
    for k in range(n):
        a = rnd.uniform(0, 6.283)
        lift = rnd.uniform(0.35, 1.1)
        d = Vector((math.cos(a), math.sin(a), lift)).normalized()
        base = Vector((rnd.uniform(-0.15, 0.15) * sx, rnd.uniform(-0.15, 0.15) * sy, rnd.uniform(0.05, 0.35) * sz))
        length = rnd.uniform(0.45, 0.7) * max(sx, sy)
        spray(b, base, d, length, length * rnd.uniform(0.55, 0.8), LEAF[rnd.randrange(len(LEAF))], rnd, droop=rnd.uniform(0.2, 0.45), rise=0.0)
    b.paint_fn(lambda p, c: mul(c, (0.72 + 0.38 * max(0.0, min(1.0, p.z / max(0.5, sz)))) * (1 + 0.08 * vnoise(p, 1.3, seed))))


def birch_trunk(b, h, r0, r1, seed):
    """a slim birch trunk: white bark with dark horizontal marks, a slight lean"""
    rnd = random.Random(seed)
    lean = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))
    mid = Vector((0, 0, h * 0.5)) + lean * 0.4
    top = Vector((0, 0, h)) + lean
    # stacked open rings (about every 3.5 studs) so the vertex-coloured marks have vertices to sit on; caps only at the ends
    n = max(4, int(round(h / 3.5)))
    prev = Vector((0, 0, -0.4))
    for i in range(1, n + 1):
        t = i / n
        q = Vector((0, 0, -0.4 + (h + 0.4) * t)) + lean * (t ** 1.6)
        b.cyl(tuple(prev), tuple(q), r0 + (r1 - r0) * ((i - 1) / n), BIRCH_BARK, r2=r0 + (r1 - r0) * t, seg=7, cap=(i == 1 or i == n))
        prev = q

    def bark(p, c):
        # dark bands (lenticels) here and there, darker and rougher at the foot
        band = math.sin(p.z * 3.1 + vnoise(p, 2.0, seed) * 2.5)
        foot = max(0.0, 1.0 - p.z / 3.0)
        dark = 0.0
        if band > 0.86:
            dark = 0.8
        dark = max(dark, foot * 0.75)
        return mix(BIRCH_BARK, BIRCH_MARK, dark * (0.6 + 0.4 * max(0.0, vnoise(p, 3.3, seed + 1))))
    b.paint_fn(bark)


def birch_crown(b, base, top, rmax, seed, clumps=10):
    """a birch crown: thin upswept branches, each ending in a clump of small leafy sprays; open and airy, about 750
    triangles. The branches are part of the crown, so they never block movement."""
    rnd = random.Random(seed)
    span = top - base
    for k in range(clumps):
        t = (k + 0.5) / clumps
        a = rnd.uniform(0, 6.283)
        z0 = base + span * (0.15 + 0.6 * t) + rnd.uniform(-0.5, 0.5)
        reach = rmax * (0.55 + 0.45 * math.sin(math.pi * min(1.0, 0.25 + t * 0.75))) * rnd.uniform(0.8, 1.1)
        end = Vector((math.cos(a) * reach, math.sin(a) * reach, z0 + reach * rnd.uniform(0.35, 0.7)))
        b.cyl((math.cos(a) * 0.15, math.sin(a) * 0.15, z0), tuple(end), 0.09, BIRCH_BARK, r2=0.04, seg=4)
        for j in range(4):
            aa = a + rnd.uniform(-1.5, 1.5)
            d = Vector((math.cos(aa), math.sin(aa), rnd.uniform(-0.3, 0.5))).normalized()
            L = rnd.uniform(3.2, 5.0) * (rmax / 5.2)
            spray(b, tuple(end + Vector((0, 0, rnd.uniform(-0.6, 0.4)))), d, L, L * 0.7, BIRCH_LEAF[rnd.randrange(len(BIRCH_LEAF))], rnd, droop=rnd.uniform(0.3, 0.6), cell=2)
    # a few clumps near the top
    for j in range(5):
        aa = rnd.uniform(0, 6.283)
        d = Vector((math.cos(aa), math.sin(aa), rnd.uniform(0.0, 0.6))).normalized()
        L = rnd.uniform(2.6, 3.6) * (rmax / 5.2)
        spray(b, (0, 0, top - rnd.uniform(0.5, 2.0)), d, L, L * 0.7, BIRCH_LEAF[rnd.randrange(len(BIRCH_LEAF))], rnd, droop=0.35, cell=2)

    def shade(p, c):
        if c[0] > 0.6 and c[1] > 0.6:  # the white branches keep their colour
            return c
        hz = max(0.0, min(1.0, (p.z - base) / max(1.0, span)))
        return mul(c, (0.74 + 0.32 * hz) * (1 + 0.1 * vnoise(p, 1.1, seed + 5)))
    b.paint_fn(shade)


def fern(b, seed):
    rnd = random.Random(seed)
    for k in range(7):
        a = k * 2 * math.pi / 7 + rnd.uniform(-0.2, 0.2)
        L = rnd.uniform(0.8, 1.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0)) * 0.16
        tip = d * L + Vector((0, 0, 0.35))
        mid = d * L * 0.5 + Vector((0, 0, 0.45))
        col = LEAF[rnd.randrange(len(LEAF))]
        b.face([(0, 0, 0.05), tuple(mid + side), tuple(tip), tuple(mid - side)], col, double=True)


def grass(b, seed, h=0.9, blades=9, col=None):
    rnd = random.Random(seed)
    for k in range(blades):
        a = rnd.uniform(0, 6.283)
        r = rnd.uniform(0, 0.35)
        x, y = math.cos(a) * r, math.sin(a) * r
        lean = Vector((rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), 0))
        w = 0.07
        c = col or LEAF[rnd.randrange(len(LEAF))]
        bh = h * rnd.uniform(0.7, 1.2)
        b.face([(x - w, y, 0), (x + w, y, 0), (x + lean.x, y + lean.y, bh)], mul(c, rnd.uniform(0.9, 1.15)), double=True)


def branch(b, seed):
    rnd = random.Random(seed)
    L = 6.0
    pts = [(-L / 2, 0, 0.17), (-L / 6, rnd.uniform(-0.3, 0.3), 0.2), (L / 6, rnd.uniform(-0.3, 0.3), 0.18), (L / 2, 0, 0.12)]
    b.tube(pts, 0.16, BARK, seg=5, smooth=False, caps=True, r_end=0.07)
    for k in range(5):
        x = rnd.uniform(-L / 2 + 0.6, L / 2 - 0.4)
        side = rnd.choice((-1, 1))
        a = rnd.uniform(0.3, 1.0)
        lk = rnd.uniform(0.7, 1.6)
        b.cyl((x, 0, 0.18), (x + lk * 0.5, side * math.cos(a) * lk, 0.18 + math.sin(a) * lk * 0.35), 0.06, BARK_D, r2=0.02, seg=4)
    b.paint_fn(lambda p, c: mul(c, 0.85 + 0.2 * vnoise(p, 2.0, seed)))


def build(scene):
    col = scene.collection
    objs = []

    def make(name, fn, *a):
        b = Builder(name)
        fn(b, *a)
        objs.append(b.finish(col))

    make("ZR_NAT_PineA_T", trunk, 32, 0.8, 0.2, 1)
    make("ZR_NAT_PineA_C", crown_whorl, 8, 33, 5.6, 7, 2)
    make("ZR_NAT_PineB_T", trunk, 40, 0.9, 0.22, 3)
    make("ZR_NAT_PineB_C", crown_whorl, 15, 41, 4.6, 7, 4, 0.8)
    make("ZR_NAT_PineC_T", trunk, 17, 0.45, 0.12, 5, False)
    make("ZR_NAT_PineC_C", crown_whorl, 2.2, 18, 4.2, 6, 6, 0.9, 0.6)
    make("ZR_NAT_Snag_T", snag)
    make("ZR_NAT_Rock1", rock, (5.0, 4.0, 3.4), 61)
    make("ZR_NAT_Rock2", rock, (11.0, 8.0, 6.0), 62, 0.55)
    make("ZR_NAT_Rock3", rock, (8.0, 6.0, 1.6), 63, 0.3)
    make("ZR_NAT_RockPile", rock, (2.6, 2.2, 1.8), 64, 0.4, 5, 2.0)
    make("ZR_NAT_Log", log, 12, 0.75, 71)
    make("ZR_NAT_Stump", stump)
    make("ZR_NAT_LogPile", logpile)
    make("ZR_NAT_Bush1", bush_sprays, (3.2, 3.0, 2.2), 81, 13)
    make("ZR_NAT_Bush2", bush_sprays, (4.6, 3.8, 2.8), 82, 17)
    make("ZR_NAT_BirchA_T", birch_trunk, 30, 0.55, 0.14, 101)
    make("ZR_NAT_BirchA_C", birch_crown, 9, 31, 5.2, 102, 18)
    make("ZR_NAT_BirchB_T", birch_trunk, 22, 0.45, 0.12, 103)
    make("ZR_NAT_BirchB_C", birch_crown, 6, 23, 4.2, 104, 14)
    make("ZR_NAT_Fern", fern, 91)
    make("ZR_NAT_Grass", grass, 92)
    make("ZR_NAT_Reeds", grass, 93, 1.6, 12, hexc("5E6A3A"))
    make("ZR_NAT_Branch", branch, 95)
    return objs


scene = batch_scene("ZR_Nature")
objects = build(scene)
fbx, blend, meta = export_batch(objects, "ZR_Nature", scene)
print("EXPORTED", fbx, os.path.getsize(fbx), "objects", len(objects))
tot = 0
for k, v in meta.items():
    tot += v["tris"]
    print(k, v["tris"], "size", v["size"], "center", v["center"])
print("TOTAL TRIS", tot)

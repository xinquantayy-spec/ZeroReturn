"""Zero Return - M12 wear kit (Tarkov-style imperfection). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_wear_kit.py").read(), g)
Generates objects in scene "ZR_WearKit", exports assets/exports/ZR_WearKit.fbx (+ .blend source + .meta.json).
All geometry is original and procedural (no external assets). Vertex colour only, low poly (mobile-safe).

Two families:
  ZR_WK_*   cosmetic detail for the client detail layer (no collision, never cover): rubble, chips, litter,
            cardboard, trash bags, a tyre, planks, bricks, weeds, puddle, wall conduit, sagging cables,
            downpipe, pipe run, AC unit, electrical box, wall lamp, vent, broken window glass and frame,
            hanging wires, fallen ceiling tile, tipped chair and bin, radiator, mattress, barbed wire, rebar.
  ZR_PROP_* gameplay props placed by the server (everyone sees them, they block movement and bullets):
            dented drum, tyre stack, cinder blocks on a pallet, dumpster, burnt-out car, cable reel,
            broken barrier, sandbag wall, pallet stack.
Origins: ground props bottom-centre; wall pieces back-centre on the wall plane, body toward Blender -Y
(Roblox LookVector), so CFrame.lookAt(point, point + outwardNormal) mounts them.
"""
import math, os, sys, random
import bmesh
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
import importlib, zr_lib
importlib.reload(zr_lib)
from zr_lib import Builder, hexc, grey, batch_scene, export_batch, vnoise
from mathutils import Vector, Matrix, Euler

R = math.radians


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def mul(c, k):
    return (min(1, c[0] * k), min(1, c[1] * k), min(1, c[2] * k), 1.0)


RUST, RUST2, SOOT = hexc("7A4A2A"), hexc("5A3420"), hexc("221E1B")
WOOD = [hexc("7E6A52"), hexc("6E5C47"), hexc("8A765C"), hexc("5F5040")]


def rust_fn(amount=0.5, scale=1.6, seed=0, low_z=None):
    def fn(p, c):
        n = vnoise(p, scale, seed)
        t = max(0.0, n - (1 - amount)) / max(0.05, amount)
        if low_z is not None:
            t = max(t, max(0.0, 1 - (p.z - low_z[0]) / low_z[1]) * 0.6)
        return mix(c, RUST if n > 0.6 else RUST2, min(0.85, t))
    return fn


# ── cosmetic: ground ──────────────────────────────────────────────────────────
def rubble(b, seed, n, w, d, hmax, smin=0.16, smax=0.55, slab=False):
    rnd = random.Random(seed)
    pts = [(math.cos(t) * w * 0.55 * rnd.uniform(0.75, 1.1), math.sin(t) * d * 0.55 * rnd.uniform(0.75, 1.1), 0.015) for t in [k * 2 * math.pi / 14 for k in range(14)]]
    b.face(pts, grey(0.62))  # dust bed
    for i in range(n):
        x, y = rnd.gauss(0, w * 0.22), rnd.gauss(0, d * 0.22)
        r = min(1.0, (x / (w / 2)) ** 2 + (y / (d / 2)) ** 2)
        s = rnd.uniform(smin, smax) * (1.25 - 0.7 * r)
        z = s * 0.3 + (1 - r) * hmax * 0.55 * rnd.random()
        g = rnd.uniform(0.7, 0.96)
        b.chunk((x, y, z), (s * rnd.uniform(0.8, 1.6), s * rnd.uniform(0.8, 1.4), s * rnd.uniform(0.45, 0.85)), grey(g), seed=rnd.randint(0, 99999))
    if slab:
        b.box((0.3, 0.1, hmax * 0.45), (2.2, 1.5, 0.24), grey(0.86), rot=(R(14), R(-22), R(30)))
        for k in range(3):
            a = R(rnd.uniform(-40, 40))
            p0 = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.6, 0.6), hmax * 0.5))
            b.tube([p0, p0 + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 0.35)), p0 + Vector((math.cos(a) * 1.2, math.sin(a) * 1.1, 0.5 + rnd.uniform(0, 0.4)))], 0.045, RUST, seg=5)


def litter(b, seed):
    rnd = random.Random(seed)
    cans = [hexc("8E3A2E"), hexc("3E5A78"), hexc("6E7A3C"), hexc("B0A890")]
    for k in range(4):
        x, y, a = rnd.uniform(-1, 1), rnd.uniform(-0.7, 0.7), rnd.uniform(0, 6.28)
        d = Vector((math.cos(a), math.sin(a), 0)) * 0.19
        c = Vector((x, y, 0.11))
        b.cyl(c - d, c + d, 0.11, cans[k % 4], seg=8)
    for k in range(2):  # bottles
        x, y, a = rnd.uniform(-1, 1), rnd.uniform(-0.7, 0.7), rnd.uniform(0, 6.28)
        d = Vector((math.cos(a), math.sin(a), 0))
        c = Vector((x, y, 0.12))
        col = hexc("4E6A44") if k == 0 else hexc("6A4A2A")
        b.cyl(c - d * 0.25, c + d * 0.12, 0.12, col, seg=8)
        b.cyl(c + d * 0.12, c + d * 0.34, 0.12, col, r2=0.045, seg=8)
    for k in range(4):  # paper wads, a cup
        b.chunk((rnd.uniform(-1, 1), rnd.uniform(-0.7, 0.7), 0.1), (0.24, 0.22, 0.18), grey(rnd.uniform(0.78, 0.92)), seed=rnd.randint(0, 9999), rough=0.4)
    b.box((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.6, 0.6), 0.03), (0.42, 0.3, 0.05), hexc("A8402E"), rot=(0, 0, rnd.uniform(0, 3)))  # flattened pack


def cardboard(b):
    CB, TAPE = hexc("9C7A50"), hexc("B8A27A")
    b.box((-0.5, 0.1, 0.04), (1.9, 1.5, 0.06), CB, rot=(0, 0, R(18)))
    b.box((-0.5, 0.1, 0.075), (0.25, 1.5, 0.01), TAPE, rot=(0, 0, R(18)))
    # half-collapsed box with open flaps
    o = Vector((0.7, -0.2, 0))
    b.box(o + Vector((0, 0, 0.42)), (1.2, 1.0, 0.84), CB, rot=(R(4), R(-6), R(-12)))
    for i, (dx, dy, rx, ry) in enumerate(((0, 0.55, R(-70), 0), (0, -0.55, R(60), 0), (0.65, 0, 0, R(75)), (-0.65, 0, 0, R(-110)))):
        b.box(o + Vector((dx, dy, 0.9)), (1.15 if dx == 0 else 0.08, 0.08 if dx == 0 else 0.95, 0.5), mul(CB, 0.92), rot=(rx, ry, R(-12)))


def trashbags(b):
    for i, (x, y, s) in enumerate(((-0.45, 0.1, 1.0), (0.55, -0.15, 0.85))):
        b.chunk((x, y, 0.45 * s), (1.25 * s, 1.05 * s, 0.95 * s), hexc("26282A"), seed=31 + i, rough=0.14, subdiv=2)
        b.chunk((x + 0.1, y, 0.92 * s), (0.28, 0.24, 0.3), hexc("2E3032"), seed=40 + i, rough=0.3)
    b.paint_fn(lambda p, c: mul(c, 1.0 + 0.35 * max(0, p.z - 0.5)))  # plastic catches light on top


def tyre(b, center=(0, 0, 0.36), rot=(0, 0, 0)):
    b.torus(center, 0.95, 0.36, hexc("242424"), segU=18, segV=8, rot=rot)
    m = Matrix.LocRotScale(Vector(center), Euler(rot).to_quaternion(), Vector((1, 1, 1)))
    b.cyl(m @ Vector((0, 0, -0.2)), m @ Vector((0, 0, 0.2)), 0.62, hexc("3A3A38"), seg=12, cap=True)


def planks(b, seed):
    rnd = random.Random(seed)
    for k in range(4):
        L = rnd.uniform(1.8, 3.4)
        b.box((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.6, 0.6), 0.07 + k * 0.025), (0.36, L, 0.12), WOOD[k % 4], rot=(0, R(rnd.uniform(-4, 4)), rnd.uniform(0, 3.1)))
    b.box((0.4, 0.3, 0.3), (0.34, 1.6, 0.12), WOOD[1], rot=(R(12), 0, R(40)))  # one leaning on the others
    b.jitter(0.06, seed)


def bricks(b, seed):
    rnd = random.Random(seed)
    cols = [hexc("8A4A36"), hexc("7A3E2E"), hexc("945844"), hexc("6E3A2C")]
    for k in range(13):
        L = 0.73 if rnd.random() > 0.3 else 0.38
        z = 0.12 + (0.22 if k > 7 else 0) + (0.2 if k > 11 else 0)
        b.box((rnd.uniform(-0.7, 0.7), rnd.uniform(-0.5, 0.5), z), (L, 0.36, 0.23), cols[k % 4], rot=(R(rnd.uniform(-8, 8)), R(rnd.uniform(-8, 8)), rnd.uniform(0, 3.1)))
    for k in range(6):
        b.chunk((rnd.uniform(-0.9, 0.9), rnd.uniform(-0.7, 0.7), 0.06), (0.16, 0.14, 0.1), cols[k % 4], seed=rnd.randint(0, 999))


def weeds(b, seed, tufts=6):
    rnd = random.Random(seed)
    greens = [hexc("5E6A34"), hexc("6E7040"), hexc("7A6A3E"), hexc("4E5A2E")]
    for t in range(tufts):
        cx, cy = rnd.uniform(-0.7, 0.7), rnd.uniform(-0.7, 0.7)
        h0 = rnd.uniform(0.35, 1.0)
        for k in range(7):
            a = rnd.uniform(0, 6.28)
            lean = rnd.uniform(0.1, 0.45) * h0
            w = rnd.uniform(0.05, 0.09)
            h = h0 * rnd.uniform(0.6, 1.1)
            base = Vector((cx + rnd.uniform(-0.06, 0.06), cy + rnd.uniform(-0.06, 0.06), 0))
            side = Vector((-math.sin(a), math.cos(a), 0)) * w
            tip = base + Vector((math.cos(a) * lean, math.sin(a) * lean, h))
            b.face([base - side, base + side, tip], greens[(t + k) % 4], double=True)


def puddle(b, seed):
    rnd = random.Random(seed)
    n = 18
    pts = []
    rr = 1.0
    for k in range(n):
        t = 2 * math.pi * k / n
        rr = 0.65 * rr + 0.35 * rnd.uniform(0.7, 1.25)
        pts.append((math.cos(t) * 1.6 * rr, math.sin(t) * 1.1 * rr, 0.02))
    b.face(pts, hexc("2E3434"), double=True)


# ── cosmetic: on walls and ceilings ─────────────────────────────────────────────
def conduit(b):
    G = grey(0.78)
    b.cyl((-4, -0.2, 0), (4, -0.2, 0), 0.11, G, seg=6, smooth=True)
    for x in (-3, 0, 3):
        b.box((x, -0.12, 0), (0.14, 0.24, 0.3), grey(0.55))
    b.box((4.0, -0.2, 0), (0.46, 0.3, 0.46), grey(0.7), bevel=0.02)
    b.cyl((4.0, -0.2, -0.23), (4.0, -0.2, -1.4), 0.08, G, seg=6)


def cablesag(b):
    for i, (dy, sag, z0) in enumerate(((-0.18, 0.85, 0.0), (-0.28, 1.0, -0.06), (-0.23, 1.2, 0.05))):
        pts = []
        for k in range(15):
            t = k / 14
            x = -5 + 10 * t
            z = z0 - sag * (1 - (2 * t - 1) ** 2)
            pts.append((x, dy, z))
        b.tube(pts, 0.035, hexc("1E1E1E") if i != 1 else hexc("2A2622"), seg=4)
    for x in (-5, 5):
        b.box((x, -0.12, 0), (0.18, 0.24, 0.24), grey(0.4))


def downpipe_fixed(b):
    """rain downpipe 10 studs: hopper at the top, three brackets, kick-out shoe at the bottom"""
    P = grey(0.72)
    b.cyl((0, -0.3, 0.7), (0, -0.3, 9.6), 0.22, P, seg=8, smooth=True)
    b.tube([(0, -0.3, 0.75), (0, -0.36, 0.4), (0, -0.66, 0.16)], 0.22, P, seg=8)
    for z in (2.0, 5.5, 8.8):
        b.box((0, -0.27, z), (0.56, 0.08, 0.12), grey(0.45))
        b.box((0, -0.04, z), (0.2, 0.08, 0.12), grey(0.45))
    b.box((0, -0.34, 9.85), (0.72, 0.62, 0.5), P)
    b.paint_fn(rust_fn(0.35, 1.3, 3, low_z=(0.0, 1.2)))


def piperun(b):
    P = grey(0.74)
    for x0, x1 in ((-4, 0), (0, 4)):
        b.cyl((x0, -0.6, 0), (x1, -0.6, 0), 0.34, P, seg=10, smooth=True)
    for x in (-3.98, 0, 3.98):
        b.cyl((x - 0.07, -0.6, 0), (x + 0.07, -0.6, 0), 0.47, grey(0.62), seg=10)
    for x in (-2.2, 2.2):
        b.box((x, -0.04, -0.15), (0.36, 0.08, 0.9), grey(0.5))
        b.box((x, -0.45, -0.42), (0.3, 0.86, 0.1), grey(0.5))
        b.box((x, -0.3, -0.24), (0.08, 0.5, 0.08), grey(0.5), rot=(R(-38), 0, 0))
    b.paint_fn(rust_fn(0.45, 1.1, 5))


def acunit(b):
    BODY = hexc("C4C0B2")
    b.box((0, -0.6, 0), (2.4, 0.95, 1.7), BODY, bevel=0.03)
    b.torus((-0.45, -1.08, 0), 0.55, 0.04, grey(0.3), segU=16, segV=4, rot=(R(90), 0, 0))
    b.cyl((-0.45, -1.06, 0), (-0.45, -1.1, 0), 0.5, grey(0.2), seg=14)
    for a in (0, 60, 120):
        b.box((-0.45, -1.11, 0), (1.05, 0.03, 0.06), grey(0.42), rot=(0, R(a), 0))
    for k in range(7):
        b.box((0.6, -1.08, -0.6 + k * 0.2), (0.85, 0.04, 0.05), mul(BODY, 0.62))
    for x in (-0.9, 0.9):
        b.box((x, -0.55, -0.92), (0.1, 1.1, 0.1), grey(0.4))
        b.box((x, -0.02, -0.75), (0.1, 0.06, 0.5), grey(0.4))
        b.box((x, -0.42, -0.98), (0.08, 0.08, 0.9), grey(0.4), rot=(R(52), 0, 0))
    b.cyl((1.05, -0.4, -0.85), (1.05, -0.4, -2.2), 0.05, grey(0.3), seg=5)  # condensate pipe
    b.paint_fn(lambda p, c: mul(c, 0.78 + 0.22 * min(1, max(0, (p.z + 0.85) / 1.7))))  # dirtier at the bottom
    b.paint_fn(rust_fn(0.25, 2.2, 7))


def elecbox(b):
    BX = grey(0.7)
    b.box((0, -0.26, 0), (1.3, 0.46, 1.7), BX, bevel=0.02)
    b.box((0, -0.5, 0), (1.18, 0.03, 1.58), mul(BX, 0.92))
    b.box((0.45, -0.53, 0), (0.06, 0.06, 0.26), grey(0.25))
    for z in (-0.55, 0.55):
        b.box((-0.6, -0.52, z), (0.06, 0.06, 0.18), grey(0.3))
    b.face([(0.0, -0.525, 0.55), (-0.18, -0.525, 0.25), (0.18, -0.525, 0.25)], hexc("C8A232"))
    for x in (-0.35, 0.0, 0.3):
        b.cyl((x, -0.26, -0.85), (x, -0.26, -3.2), 0.07, grey(0.6), seg=6)
    b.paint_fn(rust_fn(0.3, 2.0, 9))


def walllamp(b):
    b.cyl((0, 0, 0), (0, -0.12, 0), 0.34, grey(0.3), seg=12)
    b.cyl((0, -0.12, 0), (0, -0.32, 0), 0.27, hexc("D9D0AA"), seg=12, smooth=True)
    for a in (0, 60, 120):
        b.box((0, -0.34, 0), (0.6, 0.04, 0.04), grey(0.25), rot=(0, R(a), 0))


def vent(b):
    b.box((0, -0.06, 0), (1.2, 0.12, 0.8), grey(0.45))
    b.box((0, -0.1, 0), (1.06, 0.06, 0.66), grey(0.12))
    for k in range(6):
        b.box((0, -0.13, -0.27 + k * 0.11), (1.04, 0.03, 0.1), grey(0.5), rot=(R(-35), 0, 0))
    b.paint_fn(rust_fn(0.4, 3, 11))


def shards(b, seed, W=4.0, H=3.2):
    """glass remnants along the edges of a W x H opening (centre open); window plane y = 0"""
    rnd = random.Random(seed)
    G = hexc("A8B8B4")
    edges = [((-W / 2, H / 2), (W / 2, H / 2), (0, -1)), ((W / 2, H / 2), (W / 2, -H / 2), (-1, 0)),
             ((W / 2, -H / 2), (-W / 2, -H / 2), (0, 1)), ((-W / 2, -H / 2), (-W / 2, H / 2), (1, 0))]
    for (ax, az), (bx, bz), (nx, nz) in edges:
        L = math.hypot(bx - ax, bz - az)
        n = max(3, int(L / 0.8))
        for k in range(n):
            if rnd.random() < 0.25:
                continue
            t0, t1 = k / n, (k + 1) / n
            p0 = (ax + (bx - ax) * t0, az + (bz - az) * t0)
            p1 = (ax + (bx - ax) * t1, az + (bz - az) * t1)
            tm = rnd.uniform(t0, t1)
            depth = rnd.uniform(0.12, 0.6) * (1.2 if k in (0, n - 1) else 1)
            tip = (ax + (bx - ax) * tm + nx * depth, az + (bz - az) * tm + nz * depth)
            b.face([(p0[0], 0, p0[1]), (p1[0], 0, p1[1]), (tip[0], 0, tip[1])], G, double=True)
    for _ in range(4):  # loose shards on the sill
        x = rnd.uniform(-W / 2 + 0.3, W / 2 - 0.3)
        b.face([(x, -0.05, -H / 2 + 0.02), (x + 0.25, -0.2, -H / 2 + 0.02), (x + 0.05, -0.3, -H / 2 + 0.02)], G, double=True)


def windowframe(b, W=4.0, H=3.2):
    F = WOOD[3]
    t = 0.16
    b.box((0, -0.05, H / 2 - t / 2), (W, 0.18, t), F)
    b.box((0, -0.05, -H / 2 + t / 2), (W, 0.18, t), F)
    b.box((-W / 2 + t / 2, -0.05, 0), (t, 0.18, H), F)
    b.box((W / 2 - t / 2, -0.05, 0), (t, 0.18, H), F)
    b.box((0, -0.05, H / 4), (0.12, 0.14, H / 2 - t), F)  # mullion, snapped
    b.box((0.25, -0.12, -H / 4 - 0.2), (0.12, 0.14, H / 2 - 0.5), F, rot=(R(10), R(-14), 0))
    b.box((0, -0.05, 0.02), (W - 2 * t, 0.12, 0.1), F)
    b.jitter(0.08, 5)


def wireshang(b):
    b.cyl((0, 0, 0), (0, 0, -0.06), 0.16, grey(0.7), seg=8)
    cols = [hexc("1E1E1E"), hexc("6A4A2A"), hexc("3A4A6A")]
    for i, (dx, dy, L) in enumerate(((0.05, 0.02, 2.2), (-0.04, 0.03, 1.4), (0.02, -0.05, 2.8))):
        pts = [(dx * (k / 6) * 6, dy * (k / 6) * 6 + 0.08 * math.sin(k + i), -0.06 - L * k / 6) for k in range(7)]
        b.tube(pts, 0.025, cols[i], seg=4)
    b.cyl((0.3, 0.12, -2.86), (0.3, 0.12, -3.1), 0.07, grey(0.85), seg=6)


def ceilingtile(b):
    b.sheet((0, 0, 0.18), (2.0, 2.0), hexc("BEB9A8"), nx=4, ny=4, disp=lambda u, v: 0.42 * (u * v) ** 1.6 - 0.12 + 0.04 * math.sin(u * 9), thick=0.05, rot=(0, 0, R(20)))
    b.paint_fn(lambda p, c: mix(c, hexc("8C7A52"), max(0, 0.5 - ((p.x + 0.3) ** 2 + (p.y - 0.2) ** 2)) * 0.9))


def chair(b):
    FR, SEAT = grey(0.32), hexc("4E3A2E")
    # modelled upright then laid on its back
    b.box((0, 0, 1.55), (1.4, 1.4, 0.12), SEAT)
    b.box((0, 0.66, 2.35), (1.4, 0.12, 1.2), SEAT, rot=(R(-8), 0, 0))
    for sx in (-0.62, 0.62):
        for sy in (-0.62, 0.62):
            b.cyl((sx, sy, 0), (sx, sy, 1.5), 0.05, FR, seg=6)
        b.cyl((sx, 0.66, 1.5), (sx, 0.72, 2.95), 0.05, FR, seg=6)
    b.transform(Matrix.Translation(Vector((0, -0.75, 0))) @ Matrix.Rotation(R(-90), 4, 'X'))
    zmin = min(v.co.z for v in b.bm.verts)
    b.transform(Matrix.Translation(Vector((0, 0, -zmin))))


def bin_tipped(b):
    BIN = grey(0.55)
    b.cyl((0, 0, 0.55), (1.3, 0, 0.55), 0.55, BIN, r2=0.62, seg=12, cap=False, smooth=True)
    before = set(b.bm.faces)
    b.cyl((0.03, 0, 0.55), (1.29, 0, 0.55), 0.52, mul(BIN, 0.6), r2=0.59, seg=12, cap=False, smooth=True)
    bmesh.ops.reverse_faces(b.bm, faces=[f for f in b.bm.faces if f not in before])
    b.cyl((0, 0, 0.55), (0.02, 0, 0.55), 0.55, BIN, seg=12)
    for k in range(4):
        b.chunk((1.6 + k * 0.25, -0.3 + k * 0.2, 0.12), (0.26, 0.24, 0.2), grey(0.85), seed=70 + k, rough=0.4)
    zmin = min(v.co.z for v in b.bm.verts)
    b.transform(Matrix.Translation(Vector((-0.9, 0, -zmin))))


def radiator(b):
    W = hexc("CFCAB8")
    for k in range(10):
        b.box((-1.08 + k * 0.24, -0.22, 0.95), (0.16, 0.32, 1.4), W, bevel=0.02)
    for z in (0.3, 1.62):
        b.cyl((-1.25, -0.22, z), (1.25, -0.22, z), 0.07, W, seg=6)
    b.cyl((1.3, -0.22, 0.3), (1.6, -0.22, 0.3), 0.06, grey(0.4), seg=6)
    b.box((1.62, -0.22, 0.42), (0.1, 0.1, 0.18), hexc("8E3A2E"))
    b.paint_fn(rust_fn(0.25, 2.5, 13))
    b.paint_fn(lambda p, c: mul(c, 0.8 + 0.2 * min(1, p.z / 1.6)))


def mattress(b):
    BASE = hexc("A8A694")
    for i, (y, h, rx) in enumerate(((-2.1, 0.0, R(-3)), (0, 0.02, 0), (2.1, 0.12, R(6)))):
        b.box((0, y, 0.25 + h), (3.0, 2.08, 0.5), BASE, rot=(rx, 0, 0), bevel=0.08)

    def stain(p, c):
        s = max(0.0, vnoise(p, 0.9, 4) - 0.25) * 1.4
        return mix(c, hexc("7E6A44"), min(0.7, s))
    b.paint_fn(stain)


def barbed(b):
    pts = []
    turns, per = 16, 6
    for k in range(turns * per + 1):
        a = 2 * math.pi * k / per
        pts.append((-4 + 8 * k / (turns * per), math.cos(a) * 0.42, 0.45 + math.sin(a) * 0.42))
    b.tube(pts, 0.022, grey(0.55), seg=3)
    for y in (-0.08, 0.08):
        b.tube([(-4, y, 0.06), (4, y, 0.06)], 0.02, grey(0.5), seg=3)


def rebar(b, seed):
    rnd = random.Random(seed)
    for k in range(4):
        y = -0.4 + k * 0.25
        pts = [(-2.6, y + rnd.uniform(-0.1, 0.1), 0.06), (-0.4, y, 0.06 + rnd.uniform(0, 0.08)), (1.6, y + rnd.uniform(-0.2, 0.2), 0.06), (2.6 + rnd.uniform(-0.4, 0.4), y + rnd.uniform(-0.6, 0.6), 0.2 + rnd.uniform(0, 0.6))]
        b.tube(pts, 0.055, RUST if k % 2 else RUST2, seg=5)


# ── gameplay props (server) ─────────────────────────────────────────────────────
def drum_dented(b, seed):
    rnd = random.Random(seed)
    seg, rings, Rr, H = 14, 9, 1.6, 4.4
    dents = [(rnd.uniform(0, 6.28), rnd.uniform(0.8, 3.6), rnd.uniform(0.18, 0.32), rnd.uniform(0.5, 0.9)) for _ in range(2)]
    grid = []
    for j in range(rings):
        z = H * j / (rings - 1)
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            r = Rr
            for da, dz, depth, width in dents:
                d = math.hypot((((a - da + math.pi) % (2 * math.pi)) - math.pi) * Rr, z - dz)
                r -= depth * math.exp(-(d / width) ** 2)
            row.append(b.bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        grid.append(row)
    faces = []
    for j in range(rings - 1):
        for i in range(seg):
            i2 = (i + 1) % seg
            faces.append(b.bm.faces.new((grid[j][i], grid[j][i2], grid[j + 1][i2], grid[j + 1][i])))
    faces.append(b.bm.faces.new(list(reversed(grid[0]))))
    faces.append(b.bm.faces.new(grid[-1]))
    b._paint(faces, grey(0.86), smooth=True)
    for z in (1.45, 2.95):
        b.torus((0, 0, z), Rr + 0.01, 0.07, grey(0.62), segU=14, segV=4)
    b.cyl((0, 0, H), (0, 0, H + 0.08), 1.58, grey(0.7), seg=14)
    b.cyl((0.8, 0.5, H + 0.08), (0.8, 0.5, H + 0.15), 0.18, grey(0.4), seg=8)
    b.paint_fn(rust_fn(0.4, 1.3, seed, low_z=(0.0, 0.9)))
    b.ao(0, H, 0.6, 1.0)


def tyre_stack(b):
    rnd = random.Random(4)
    for k in range(4):
        tyre(b, (rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12), 0.36 + k * 0.7), rot=(R(rnd.uniform(-3, 3)), R(rnd.uniform(-3, 3)), 0))
    tyre(b, (1.9, 0.6, 1.0), rot=(R(72), 0, R(30)))  # one leaning against the stack


def pallet(b, z0=0.0, yaw=0.0, jit=0):
    rnd = random.Random(jit)
    m = Matrix.Translation(Vector((0, 0, z0))) @ Matrix.Rotation(yaw, 4, 'Z')

    def bx(c, s, col):
        b.box(tuple(m @ Vector(c)), s, col, rot=(0, 0, yaw))
    for i, y in enumerate((-1.8, 0, 1.8)):
        bx((0, y, 0.05), (5, 0.55, 0.1), WOOD[i % 4])
        for x in (-2.2, 0, 2.2):
            bx((x, y, 0.26), (0.55, 0.55, 0.32), WOOD[(i + 2) % 4])
    for k in range(7):
        if rnd.random() < 0.12:
            continue  # missing deck board
        bx((-2.2 + k * 0.733, 0, 0.47), (0.55, 4.2, 0.1), WOOD[k % 4])


def cinder_stack(b):
    pallet(b)
    C = grey(0.8)
    for layer in range(3):
        for i in range(3):
            for j in range(2):
                if layer == 2 and i == 2 and j == 1:
                    continue
                x, y, z = -1.5 + i * 1.5, -0.8 + j * 1.6, 0.52 + 0.36 + layer * 0.72
                b.box((x, y, z), (1.42, 1.5, 0.7), C, rot=(0, 0, R(90) if layer % 2 else 0))
                for hx in (-0.35, 0.35):
                    if layer == 2 or (layer == 1 and i == 2 and j == 1):
                        b.box((x + (hx if layer % 2 == 0 else 0), y + (0 if layer % 2 == 0 else hx), z + 0.351), (0.45, 0.6, 0.01) if layer % 2 == 0 else (0.6, 0.45, 0.01), grey(0.35))
    b.chunk((2.9, 1.0, 0.25), (0.8, 0.6, 0.5), C, seed=5)
    b.chunk((3.2, 0.3, 0.18), (0.5, 0.4, 0.35), C, seed=6)
    b.jitter(0.05, 9)
    b.ao(0, 3, 0.65, 1.0)


def dumpster(b):
    D = grey(0.8)
    b.prism([(-1.8, 0.4), (1.8, 0.4), (2.1, 3.6), (-2.1, 3.6)], -3.0, 3.0, D)
    b.box((0, 0, 3.62), (6.1, 4.3, 0.12), mul(D, 0.9))  # rim
    b.box((0, 2.5, 4.3), (5.8, 0.1, 2.0), mul(D, 0.85), rot=(R(-18), 0, 0))  # lid open, leaning back
    for x in (-2.6, 2.6):
        for y in (-1.4, 1.4):
            b.cyl((x, y, 0.42), (x, y, 0.1), 0.32, grey(0.25), seg=8)
    for x in (-1.6, 1.6):
        b.box((x, 0, 1.3), (0.7, 4.0, 0.5), mul(D, 0.75))  # fork pockets
    b.paint_fn(rust_fn(0.5, 0.9, 17, low_z=(0.3, 1.4)))
    b.ao(0, 4.5, 0.6, 1.0)


def car_wreck(b):
    """burnt-out saloon on its rims; front toward Blender -Y (Roblox -Z)"""
    BODY = hexc("4A4440")
    lift = -0.45
    prof = [(7.75, 1.0), (7.85, 1.6), (7.6, 2.6), (3.8, 2.75), (2.9, 2.8), (-3.4, 2.75), (-5.6, 2.55), (-7.6, 2.25), (-7.8, 1.6), (-7.6, 1.0),
            (-6.6, 1.0), (-6.35, 1.65), (-5.75, 2.05), (-4.75, 2.05), (-4.15, 1.65), (-3.9, 1.0),
            (3.6, 1.0), (3.85, 1.65), (4.45, 2.05), (5.45, 2.05), (6.05, 1.65), (6.3, 1.0)]
    prof = [(y, z + lift) for y, z in prof]
    for x0, x1 in ((-3.05, -2.85), (2.85, 3.05)):  # side skins (the cabin stays hollow)
        b.prism(prof, x0, x1, BODY)
    front = [(-3.4, 2.75), (-5.6, 2.55), (-7.6, 2.25), (-7.8, 1.6), (-7.6, 1.0), (-6.6, 1.0), (-6.35, 1.65), (-5.75, 2.05), (-4.75, 2.05), (-4.15, 1.65), (-3.9, 1.0), (-3.4, 1.0)]
    rear = [(3.5, 1.0), (3.6, 1.0), (3.85, 1.65), (4.45, 2.05), (5.45, 2.05), (6.05, 1.65), (6.3, 1.0), (7.75, 1.0), (7.85, 1.6), (7.6, 2.6), (3.8, 2.75), (3.5, 2.75)]
    b.prism([(y, z + lift) for y, z in front], -2.86, 2.86, BODY)
    b.prism([(y, z + lift) for y, z in rear], -2.86, 2.86, BODY)
    b.box((0, 0.05, 1.12 + lift), (5.7, 6.9, 0.25), mul(BODY, 0.7))  # floor pan
    roofz = 4.55 + lift
    for sx in (-2.8, 2.8):
        b.box((sx, -2.55, (2.75 + roofz) / 2 + lift / 2 + 0.05), (0.22, 0.25, 2.25), BODY, rot=(R(-38), 0, 0))  # A pillar
        b.box((sx, 0.55, (2.8 + roofz) / 2 + lift / 2), (0.22, 0.3, 1.85), BODY)  # B pillar
        b.box((sx, 3.35, (2.8 + roofz) / 2 + lift / 2), (0.22, 0.25, 2.1), BODY, rot=(R(34), 0, 0))  # C pillar
    b.box((0, 0.5, roofz), (5.5, 4.5, 0.16), BODY, rot=(R(1.5), R(-2), 0))
    b.box((0, -6.5, 2.55 + lift), (5.7, 2.4, 0.12), BODY, rot=(R(-5), R(3), 0))  # buckled hood
    for x in (-1.3, 1.3):  # burnt seat frames
        b.box((x, -0.4, 1.6 + lift), (1.6, 1.7, 0.2), SOOT)
        b.box((x, 0.45, 2.4 + lift), (1.6, 0.2, 1.5), SOOT, rot=(R(12), 0, 0))
    b.box((0, 2.2, 1.6 + lift), (5.0, 1.6, 0.25), SOOT)
    b.box((0, -2.2, 2.45 + lift), (5.4, 0.8, 0.5), SOOT)  # dash
    b.torus((-1.3, -1.75, 2.75 + lift), 0.42, 0.05, SOOT, segU=12, segV=4, rot=(R(60), 0, 0))
    for y in (-5.25, 4.95):
        for sx in (-2.75, 2.75):
            b.cyl((sx - 0.25, y, 0.75), (sx + 0.25, y, 0.75), 0.75, grey(0.32), seg=12)
    for y in (-7.9, 7.95):
        b.box((0, y, 1.35 + lift), (6.0, 0.35, 0.55), mul(BODY, 0.6))

    def burn(p, c):
        n1 = vnoise(p, 0.55, 2)
        n2 = vnoise(p, 1.4, 8)
        if c[0] < 0.2 and c[1] < 0.2:
            return mix(c, hexc("3A2E26"), 0.3 * max(0, n2))
        col = mix(c, RUST, min(0.8, max(0, n1) * 0.9))
        col = mix(col, hexc("8A8680"), min(0.6, max(0, n2 - 0.3)))  # ash
        if p.z < 1.6 and n1 < -0.35:
            col = mix(col, hexc("3E5466"), 0.55)  # the last of the paint
        return col
    b.paint_fn(burn)
    b.ao(0, 4.2, 0.55, 1.0)


def cable_reel(b):
    for x in (-1.2, 1.2):
        b.cyl((x - 0.1, 0, 2.0), (x + 0.1, 0, 2.0), 2.0, WOOD[0], seg=16)
    b.cyl((-1.1, 0, 2.0), (1.1, 0, 2.0), 0.95, WOOD[2], seg=12)
    for k in range(5):
        b.cyl((-1.05 + k * 0.42, 0, 2.0), (-0.7 + k * 0.42, 0, 2.0), 1.25, hexc("2A2A2A"), seg=12, smooth=True)
    for a in range(0, 360, 45):
        b.box((1.32, math.cos(R(a)) * 1.2, 2.0 + math.sin(R(a)) * 1.2), (0.06, 0.5, 0.12), grey(0.4), rot=(R(a), 0, 0))
    b.jitter(0.05, 3)


def barrier_broken(b):
    prof = [(-1.2, 0), (1.2, 0), (1.2, 0.3), (0.8, 0.95), (0.3, 2.6), (-0.3, 2.6), (-0.8, 0.95), (-1.2, 0.3)]
    b.prism(prof, -4, 0.6, grey(0.82))
    rnd = random.Random(12)
    for k in range(7):
        b.chunk((0.75 + rnd.uniform(0, 0.4), rnd.uniform(-0.9, 0.9), rnd.uniform(0.2, 1.8)), (0.5, 0.6, 0.6), grey(0.78), seed=rnd.randint(0, 999))
    for k in range(3):
        z = 0.4 + k * 0.6
        b.tube([(0.5, -0.4 + k * 0.4, z), (1.3, -0.4 + k * 0.4 + rnd.uniform(-0.2, 0.2), z + rnd.uniform(-0.2, 0.3)), (1.8, -0.5 + k * 0.5, z + rnd.uniform(-0.5, 0.4))], 0.05, RUST, seg=5)
    b.chunk((2.6, 0.6, 0.45), (1.6, 1.4, 1.0), grey(0.8), seed=33, rough=0.2)
    b.chunk((3.4, -0.5, 0.25), (0.8, 0.7, 0.5), grey(0.8), seed=34)
    b.ao(0, 2.6, 0.6, 1.0)


def sandbags(b):
    rnd = random.Random(21)
    KH = hexc("948866")
    for row in range(3):
        n = 5 - row // 2
        for i in range(n):
            x = -2.4 + i * 1.2 + (0.6 if row % 2 else 0) + rnd.uniform(-0.05, 0.05)
            if x > 2.5:
                continue
            b.chunk((x, rnd.uniform(-0.05, 0.05), 0.24 + row * 0.44), (1.3, 0.78, 0.5), mul(KH, rnd.uniform(0.85, 1.05)), seed=rnd.randint(0, 9999), rough=0.08, subdiv=2)
    b.ao(0, 1.4, 0.65, 1.0)


def pallet_stack(b):
    for k in range(5):
        pallet(b, z0=k * 0.53, yaw=R(random.Random(k).uniform(-6, 6)), jit=k)
    b.ao(0, 2.7, 0.7, 1.0)


# ── batch ────────────────────────────────────────────────────────────────────
def build(scene):
    col = scene.collection
    objs = []

    def make(name, fn, *a):
        b = Builder(name)
        fn(b, *a)
        objs.append(b.finish(col))

    make("ZR_WK_Rubble", rubble, 11, 16, 2.6, 2.0, 0.7)
    make("ZR_WK_RubbleLarge", rubble, 12, 34, 5.0, 3.5, 1.4, 0.2, 0.75, True)
    make("ZR_WK_Chips", rubble, 13, 24, 3.0, 2.0, 0.1, 0.06, 0.2)
    make("ZR_WK_Litter", litter, 14)
    make("ZR_WK_Cardboard", cardboard)
    make("ZR_WK_TrashBag", trashbags)
    make("ZR_WK_Tyre", tyre)
    make("ZR_WK_Planks", planks, 15)
    make("ZR_WK_Bricks", bricks, 16)
    make("ZR_WK_Weeds", weeds, 17)
    make("ZR_WK_Puddle", puddle, 18)
    make("ZR_WK_Conduit", conduit)
    make("ZR_WK_CableSag", cablesag)
    make("ZR_WK_Downpipe", downpipe_fixed)
    make("ZR_WK_PipeRun", piperun)
    make("ZR_WK_AC", acunit)
    make("ZR_WK_ElecBox", elecbox)
    make("ZR_WK_WallLamp", walllamp)
    make("ZR_WK_Vent", vent)
    make("ZR_WK_Shards", shards, 19)
    make("ZR_WK_WindowFrame", windowframe)
    make("ZR_WK_WiresHang", wireshang)
    make("ZR_WK_CeilingTile", ceilingtile)
    make("ZR_WK_ChairTipped", chair)
    make("ZR_WK_BinTipped", bin_tipped)
    make("ZR_WK_Radiator", radiator)
    make("ZR_WK_Mattress", mattress)
    make("ZR_WK_Barbed", barbed)
    make("ZR_WK_Rebar", rebar, 20)
    make("ZR_PROP_DrumDented", drum_dented, 22)
    make("ZR_PROP_TyreStack", tyre_stack)
    make("ZR_PROP_CinderStack", cinder_stack)
    make("ZR_PROP_Dumpster", dumpster)
    make("ZR_PROP_CarWreck", car_wreck)
    make("ZR_PROP_CableReel", cable_reel)
    make("ZR_PROP_BarrierBroken", barrier_broken)
    make("ZR_PROP_Sandbags", sandbags)
    make("ZR_PROP_PalletStack", pallet_stack)
    return objs


scene = batch_scene("ZR_WearKit")
objects = build(scene)
fbx, blend, meta = export_batch(objects, "ZR_WearKit", scene)
print("EXPORTED", fbx, os.path.getsize(fbx), "objects", len(objects))
tot = 0
for k, v in meta.items():
    tot += v["tris"]
    print(k, v["tris"], "size", v["size"], "center", v["center"])
print("TOTAL TRIS", tot)

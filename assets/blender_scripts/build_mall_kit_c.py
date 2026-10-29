"""Zero Return - Meridian Mall kit, batch C: back of house, outdoor and vehicles (M13). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_mall_kit_c.py").read(), g); g["build"](names or None)
   then g["export"]() -> assets/exports/ZR_MallKitC.fbx (+ .blend, .meta.json, .props.json)
Origin bottom-centre, front toward Blender -Y (Roblox LookVector). Car bodies are near-white in their vertex
colours so the MeshPart colour picks the paint. All geometry is original and procedural (no real models/brands).
"""
import math, os, sys, random
import bmesh
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
import importlib, zr_lib, zr_kit
importlib.reload(zr_lib)
importlib.reload(zr_kit)
from zr_lib import hexc, grey, batch_scene, vnoise
from zr_kit import Prop, mix, shade, rnd, broken_pane, scatter_shards, rebar, chunks, kit_export, contact_sheet, turntable
from mathutils import Vector, Matrix, Euler
import bpy

R = math.radians
SCENE = "ZR_MallKit"
BATCH = "ZR_MallKitC"

WHITE = (0.86, 0.86, 0.83, 1)
STEEL = (0.52, 0.53, 0.54, 1)
STEEL_D = (0.26, 0.27, 0.28, 1)
CHROME = (0.74, 0.75, 0.76, 1)
GLASS = (0.55, 0.62, 0.64, 1)
GLASS_D = (0.22, 0.26, 0.28, 1)
BLACK = (0.08, 0.08, 0.085, 1)
RUBBER = (0.1, 0.1, 0.1, 1)
BODY = (0.86, 0.86, 0.85, 1)
CARD = hexc("A88A5E")
CARD_D = hexc("8C7048")
WOOD = hexc("8A745A")
ORANGE = hexc("C86A2A")
BLUE = hexc("2E4E7E")
YELLOW = hexc("D9A82E")
OLIVE = hexc("6A6E4E")
LAM_D = hexc("5E4B3B")
FAB_DARK = hexc("2E2F33")


def mul(c, k):
    return shade(c, k)


def boxes_stack(b, r, cx, cy, z0, w, d, h, n_max=12, palette=(CARD, CARD_D, mul(CARD, 1.1))):
    """cardboard boxes stacked on an area w x d up to height h"""
    z = z0
    while z < z0 + h - 0.4:
        bh = r.uniform(0.6, 1.0)
        nx = r.randint(1, 3)
        ny = r.randint(1, 2)
        for i in range(nx):
            for j in range(ny):
                if r.random() < 0.12:
                    continue
                bw, bd = w / nx, d / ny
                x = cx - w / 2 + (i + 0.5) * bw + r.uniform(-0.05, 0.05)
                y = cy - d / 2 + (j + 0.5) * bd + r.uniform(-0.05, 0.05)
                b.box((x, y, z + bh / 2), (bw - 0.06, bd - 0.06, bh - 0.02), r.choice(palette), rot=(0, 0, r.uniform(-0.04, 0.04)))
                b.box((x, y - bd / 2 + 0.02, z + bh - 0.12), (bw * 0.6, 0.02, 0.08), hexc("C8B88A"))  # tape
        z += bh


def pallet(b, cx, cy, z0, w=4.0, d=4.0, col=WOOD):
    for k in range(5):
        b.box((cx - w / 2 + 0.2 + k * (w - 0.4) / 4, cy, z0 + 0.42), (0.36, d, 0.08), col)
    for y in (-d / 2 + 0.2, 0, d / 2 - 0.2):
        b.box((cx, cy + y, z0 + 0.22), (w, 0.32, 0.36), mul(col, 0.9))
    for k in range(3):
        b.box((cx - w / 2 + 0.3 + k * (w - 0.6) / 2, cy, z0 + 0.03), (0.4, d, 0.06), col)


# ── back of house ──────────────────────────────────────────────────────────────
def pallet_rack(name, seed):
    """warehouse racking 16 long x 14 tall x 4 deep: three beam levels, pallets of boxes, some empty slots"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, W, C = P("paint"), P("metal"), P("wood"), P("cardboard")
    L, H, D = 16.0, 14.0, 4.2
    for x in (-L / 2, 0, L / 2):
        for y in (-D / 2, D / 2):
            pa.box((x, y, H / 2), (0.3, 0.25, H), BLUE)
        for z in range(1, int(H), 2):
            pa.box((x, 0, z), (0.12, D, 0.1), BLUE, rot=(R(26 if z % 4 == 1 else -26), 0, 0))
    for z in (0.0, 4.6, 9.2):
        if z > 0:
            for y in (-D / 2, D / 2):
                pa.box((0, y, z - 0.25), (L, 0.18, 0.5), ORANGE)
            me.box((0, 0, z - 0.04), (L - 0.2, D, 0.06), mul(STEEL, 0.9))
        for bay in (-L / 4, L / 4):
            if r.random() < 0.22:
                continue
            for k, dx in enumerate((-1.9, 1.9)):
                if r.random() < 0.18:
                    continue
                pallet(W, bay + dx, 0, z, w=3.4, d=3.8)
                boxes_stack(C, r, bay + dx, 0, z + 0.48, 3.2, 3.6, r.uniform(2.0, 3.6))
    return P


def pallet_boxes(name, seed):
    P = Prop(name)
    r = rnd(seed)
    W, C = P("wood"), P("cardboard")
    pallet(W, 0, 0, 0)
    boxes_stack(C, r, 0, 0, 0.48, 3.8, 3.8, 3.8)
    return P


def roll_cage(name, seed):
    P = Prop(name)
    r = rnd(seed)
    me, C, rb = P("metal"), P("cardboard"), P("rubber")
    W_, D_, H_ = 2.6, 3.4, 5.6
    me.box((0, 0, 0.4), (W_, D_, 0.12), STEEL)
    for (x, y) in ((-1.1, -1.5), (1.1, -1.5), (-1.1, 1.5), (1.1, 1.5)):
        rb.cyl((x, y, 0.2), (x, y + 0.01, 0.2), 0.2, RUBBER, seg=8)
        rb.cyl((x - 0.08, y, 0.2), (x + 0.08, y, 0.2), 0.2, RUBBER, seg=8)
    for sx in (-1, 1):
        x = sx * W_ / 2
        for y in (-D_ / 2, D_ / 2):
            me.tube([(x, y, 0.45), (x, y, H_)], 0.05, STEEL, seg=4)
        for z in (1.4, 2.6, 3.8, H_):
            me.tube([(x, -D_ / 2, z), (x, D_ / 2, z)], 0.035, STEEL, seg=4)
        for k in range(6):
            y = -D_ / 2 + (k + 0.5) * D_ / 6
            me.tube([(x, y, 0.45), (x, y, H_)], 0.025, STEEL, seg=4)
    for z in (1.4, 2.6, 3.8, H_):
        me.tube([(-W_ / 2, D_ / 2, z), (W_ / 2, D_ / 2, z)], 0.035, STEEL, seg=4)
    boxes_stack(C, r, 0, 0, 0.48, W_ - 0.2, D_ - 0.2, r.uniform(2.5, 4.5))
    return P


def storage_shelf(name, seed, empty=False):
    """storeroom steel shelving 8 x 7 x 2 with cartons"""
    P = Prop(name)
    r = rnd(seed)
    me, C = P("metal"), P("cardboard")
    L, H, D = 8.0, 7.0, 2.0
    for x in (-L / 2 + 0.1, L / 2 - 0.1):
        for y in (-D / 2 + 0.1, D / 2 - 0.1):
            me.box((x, y, H / 2), (0.14, 0.14, H), STEEL_D)
    for z in (0.4, 2.1, 3.8, 5.5, 6.9):
        me.box((0, 0, z), (L, D, 0.08), STEEL)
        if z < 6.5 and not empty:
            x = -L / 2 + 0.3
            while x < L / 2 - 0.8:
                if r.random() < 0.8:
                    w, h = r.uniform(0.9, 1.8), r.uniform(0.7, 1.5)
                    C.box((x + w / 2, r.uniform(-0.1, 0.1), z + 0.04 + h / 2), (w - 0.05, D - 0.25, h), r.choice((CARD, CARD_D, mul(CARD, 1.1))))
                    x += w
                else:
                    x += r.uniform(0.6, 1.2)
    if empty:
        for k in range(3):
            C.box((r.uniform(-3, 3), -1.6, 0.2), (1.4, 1.2, 0.08), CARD, rot=(0, 0, r.uniform(0, 3)))
    return P


def lockers(name, seed):
    P = Prop(name)
    r = rnd(seed)
    pa, me = P("paint"), P("metal")
    n, w, H, D = 4, 1.5, 6.4, 1.8
    col = r.choice((hexc("5E6E5A"), hexc("4E5E6E")))
    pa.box((0, 0.1, H / 2), (n * w, D - 0.2, H), col)
    for k in range(n):
        x = -n * w / 2 + (k + 0.5) * w
        open_ = (k == 2)
        if open_:
            m = Matrix.Translation((x - w / 2, -D / 2, 0)) @ Matrix.Rotation(R(-110), 4, "Z") @ Matrix.Translation((-(x - w / 2), D / 2, 0))
            bf = set(pa.bm.verts)
        pa.box((x, -D / 2 + 0.04, H / 2), (w - 0.06, 0.06, H - 0.1), mul(col, 1.05))
        for z in (H - 0.6, H - 0.85, 0.6, 0.85):
            pa.box((x, -D / 2 - 0.0, z), (w * 0.6, 0.02, 0.06), mul(col, 0.6))
        pa.box((x + w / 2 - 0.25, -D / 2 - 0.04, H / 2), (0.08, 0.06, 0.5), STEEL_D)
        if open_:
            bmesh.ops.transform(pa.bm, matrix=m, verts=[v for v in pa.bm.verts if v not in bf])
            me.box((x, -0.1, H / 2), (w - 0.2, D - 0.4, H - 0.3), mul(BLACK, 1.5))  # dark inside
    return P


def office_desk(name, seed):
    P = Prop(name)
    r = rnd(seed)
    W, me, pr, F = P("wood"), P("metal"), P("plastic"), P("fabric")
    W.box((0, 0, 2.55), (6.0, 3.0, 0.15), LAM_D)
    W.box((-2.4, 0, 1.25), (1.2, 2.8, 2.5), mul(LAM_D, 0.9))
    for (x, y) in ((2.8, -1.3), (2.8, 1.3)):
        me.box((x, y, 1.25), (0.12, 0.12, 2.5), STEEL_D)
    pr.box((0.6, 0.9, 3.5), (2.2, 0.15, 1.4), BLACK)
    pr.box((0.6, 1.0, 2.75), (0.6, 0.4, 0.3), BLACK)
    pr.box((0.6, -0.1, 2.66), (1.8, 0.6, 0.06), mul(BLACK, 1.6))
    for k in range(4):
        pr.box((r.uniform(-2, -0.8), r.uniform(-0.8, 0.8), 2.64 + k * 0.01), (0.85, 1.1, 0.01), WHITE, rot=(0, 0, r.uniform(-0.5, 0.5)))
    m = Matrix.Translation((0.6, -2.3, 0)) @ Matrix.Rotation(R(r.uniform(-40, 40)), 4, "Z")
    bf = set(F.bm.verts), set(me.bm.verts)
    me.cyl((0, 0, 0.1), (0, 0, 1.8), 0.08, STEEL_D, seg=6)
    for a in range(5):
        an = a * 2 * math.pi / 5
        me.box((math.cos(an) * 0.55, math.sin(an) * 0.55, 0.12), (1.1, 0.12, 0.08), STEEL_D, rot=(0, 0, an))
    F.box((0, 0, 1.95), (1.6, 1.6, 0.3), FAB_DARK)
    F.box((0, -0.75, 3.1), (1.5, 0.22, 2.0), FAB_DARK)
    bmesh.ops.transform(F.bm, matrix=m, verts=[v for v in F.bm.verts if v not in bf[0]])
    bmesh.ops.transform(me.bm, matrix=m, verts=[v for v in me.bm.verts if v not in bf[1]])
    return P


def cctv_desk(name, seed):
    """security office: a long desk and a wall rack of nine monitors (some dead or smashed)"""
    P = Prop(name)
    r = rnd(seed)
    W, me, pr = P("wood"), P("metal"), P("plastic")
    W.box((0, 0, 2.55), (9.0, 3.0, 0.15), LAM_D)
    W.box((0, 0.9, 1.25), (9.0, 1.2, 2.5), mul(LAM_D, 0.9))
    me.box((0, 1.4, 6.0), (9.0, 0.3, 6.6), STEEL_D)
    for i in range(3):
        for j in range(3):
            x, z = -3.0 + i * 3.0, 4.0 + j * 2.0
            pr.box((x, 1.15, z), (2.8, 0.25, 1.8), BLACK)
            dead = r.random() < 0.3
            pr.box((x, 1.01, z), (2.6, 0.02, 1.6), (0.05, 0.06, 0.06, 1) if not dead else (0.12, 0.13, 0.14, 1))
    for k in range(3):
        pr.box((-2.5 + k * 2.5, 0.2, 2.68), (1.4, 0.5, 0.06), mul(BLACK, 1.6))
    pr.box((3.6, -0.3, 2.75), (0.8, 0.8, 0.3), hexc("4A5A4A"))  # radio base station
    return P


def electric_cabinet(name, seed):
    P = Prop(name)
    r = rnd(seed)
    pa, me = P("paint"), P("metal")
    for k in range(3):
        x = -2.0 + k * 2.0
        pa.box((x, 0, 3.5), (1.9, 1.6, 7.0), hexc("8A8E86"))
        pa.box((x, -0.82, 3.6), (1.7, 0.04, 6.0), mul(hexc("8A8E86"), 1.05))
        pa.box((x + 0.6, -0.86, 3.6), (0.1, 0.06, 0.5), STEEL_D)
        pa.box((x, -0.85, 6.2), (0.6, 0.02, 0.4), YELLOW)  # warning plate
    for k in range(4):
        me.cyl((-2.6 + k * 1.7, 0.2, 7.0), (-2.6 + k * 1.7, 0.2, 9.5), 0.18, STEEL, seg=8)
    return P


def generator(name, seed):
    """diesel generator in an acoustic enclosure 14 x 5 x 7, control panel at the -X end (the power switch)"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, pr = P("paint"), P("metal"), P("plastic")
    L, W_, H_ = 14.0, 5.0, 7.0
    col = hexc("6E7458")
    me.box((0, 0, 0.5), (L + 0.4, W_ + 0.4, 1.0), STEEL_D)  # fuel tank base
    pa.box((0, 0, 1.0 + (H_ - 1.0) / 2), (L, W_, H_ - 1.0), col)
    pa.box((0, 0, H_ + 0.15), (L + 0.2, W_ + 0.2, 0.3), mul(col, 0.9))
    for s in (-1, 1):
        for k in range(4):
            x = -L / 2 + 2.0 + k * 3.2
            pa.box((x, s * (W_ / 2 + 0.02), 4.0), (2.6, 0.06, 4.6), mul(col, 1.06))
            for j in range(9):
                pa.box((x, s * (W_ / 2 + 0.07), 2.2 + j * 0.42), (2.3, 0.05, 0.12), mul(col, 0.7))
            pa.box((x + 1.0, s * (W_ / 2 + 0.1), 4.0), (0.1, 0.08, 0.6), STEEL_D)
    me.cyl((L / 2 - 2.0, 0, H_ + 0.3), (L / 2 - 2.0, 0, H_ + 3.4), 0.45, mul(STEEL_D, 1.2), seg=10)
    me.cyl((L / 2 - 2.0, 0, H_ + 3.4), (L / 2 - 2.0, -0.5, H_ + 3.9), 0.45, mul(STEEL_D, 1.2), seg=10)
    # control panel box at the -X end
    pa.box((-L / 2 - 0.5, 0, 3.6), (1.0, 2.6, 2.6), hexc("8A8E86"))
    pr.box((-L / 2 - 1.02, 0.4, 3.9), (0.04, 1.2, 0.8), (0.06, 0.07, 0.07, 1))  # dead display
    pr.box((-L / 2 - 1.04, -0.6, 3.4), (0.06, 0.5, 0.5), hexc("C83A3A"))  # big red switch
    pr.cyl((-L / 2 - 1.04, 0.5, 3.1), (-L / 2 - 1.12, 0.5, 3.1), 0.12, hexc("3AAE5A"), seg=8)
    me.box((-L / 2 - 0.5, 0, 0.6), (1.0, 2.6, 1.2), STEEL_D)
    # cables running off to the building and stains
    me.tube([(-L / 2 - 0.2, 1.0, 1.0), (-L / 2 - 1.2, 2.0, 0.15), (-L / 2 - 4.0, 2.6, 0.15)], 0.16, RUBBER, seg=6)
    return P


def forklift(name, seed):
    P = Prop(name)
    r = rnd(seed)
    pa, me, rb, F = P("paint"), P("metal"), P("rubber"), P("leather")
    pa.box((0, 0.6, 1.6), (3.6, 5.6, 1.8), YELLOW)
    pa.box((0, 3.0, 2.6), (3.6, 1.4, 2.6), mul(YELLOW, 0.8))  # counterweight
    F.box((0, 1.6, 3.0), (1.6, 1.4, 0.4), FAB_DARK)
    F.box((0, 2.3, 3.9), (1.6, 0.3, 1.6), FAB_DARK)
    for (x, y) in ((-1.6, -1.3), (1.6, -1.3), (-1.6, 2.6), (1.6, 2.6)):
        me.tube([(x, y, 2.4), (x, y, 7.2)], 0.1, STEEL_D, seg=5)
    me.box((0, 0.65, 7.25), (3.4, 4.2, 0.12), STEEL_D)
    me.cyl((0, 0.0, 3.8), (0, -0.3, 4.4), 0.06, STEEL_D, seg=5)
    rb.torus((0, -0.3, 4.45), 0.45, 0.06, RUBBER, segU=12, segV=4, rot=(R(70), 0, 0))
    for (x, y, rr) in ((-1.6, -1.2, 0.95), (1.6, -1.2, 0.95), (-1.5, 2.8, 0.8), (1.5, 2.8, 0.8)):
        rb.cyl((x - 0.35, y, rr), (x + 0.35, y, rr), rr, RUBBER, seg=10)
    for x in (-1.2, 1.2):
        me.box((x, -2.4, 4.2), (0.3, 0.3, 8.0), STEEL_D)
    me.box((0, -2.55, 1.4), (2.8, 0.3, 1.6), STEEL_D)
    for x in (-0.9, 0.9):
        me.box((x, -4.2, 0.12), (0.4, 3.4, 0.2), STEEL_D)
        me.box((x, -2.6, 0.9), (0.4, 0.2, 1.6), STEEL_D)
    return P


def dock_door(name, seed, open_=False):
    """loading-dock sectional door 12 wide x 12 tall in a frame, rubber seal and bumpers, leveller plate; origin
    at the floor of the dock opening, outside toward -Y"""
    P = Prop(name)
    r = rnd(seed)
    pa, rb, me, G = P("paint"), P("rubber"), P("metal"), P("glass")
    W_, H_ = 12.0, 12.0
    col = hexc("8C9088")
    for x in (-W_ / 2 - 0.4, W_ / 2 + 0.4):
        rb.box((x, -0.5, H_ / 2), (0.8, 1.0, H_ + 0.4), RUBBER)
    rb.box((0, -0.5, H_ + 0.6), (W_ + 1.6, 1.0, 0.8), RUBBER)
    for x in (-W_ / 2 + 1.2, W_ / 2 - 1.2):
        rb.box((x, -0.9, 1.4), (1.0, 0.8, 1.6), RUBBER)
    me.box((0, -1.0, -0.06), (W_ - 2.0, 2.0, 0.12), mul(STEEL, 0.8))
    if open_:
        for k in range(6):
            pa.box((0, 0.6 + k * 2.0, H_ + 0.1), (W_, 2.0, 0.15), mul(col, 1 - k * 0.02))
        me.box((0, 0.4, H_ + 1.2), (W_ + 1.0, 0.8, 0.8), STEEL_D)
    else:
        bent = r.uniform(0.0, 1.0)
        for k in range(6):
            z = 1.0 + k * 2.0
            dy = 0.6 * bent if k == 0 else 0.0
            pa.box((0, 0.2 + dy, z), (W_, 0.15, 1.95), mul(col, 1 - (k % 2) * 0.04), rot=(R(12 * bent) if k == 0 else 0, 0, 0))
            if k == 3:
                for j in range(4):
                    G.box((-4.5 + j * 3.0, 0.1, z), (2.0, 0.06, 0.8), GLASS_D)
        pa.box((0, 0.1, 0.2), (W_, 0.2, 0.4), STEEL_D)
    for x in (-W_ / 2, W_ / 2):
        me.box((x, 0.4, H_ / 2 + 0.5), (0.25, 0.4, H_ + 1.0), STEEL_D)
    return P


def cargo_lift(name, seed):
    """freight lift car 8 wide x 6 deep x 10 tall, diamond-plate walls, bi-parting doors open toward -Y"""
    P = Prop(name)
    r = rnd(seed)
    me, pa, pr = P("metal"), P("paint"), P("plastic")
    W_, D_, H_ = 8.0, 6.0, 10.0
    me.box((0, 0, 0.15), (W_, D_, 0.3), mul(STEEL, 0.85))
    me.box((-W_ / 2 + 0.1, 0, H_ / 2), (0.2, D_, H_), STEEL)
    me.box((W_ / 2 - 0.1, 0, H_ / 2), (0.2, D_, H_), STEEL)
    me.box((0, D_ / 2 - 0.1, H_ / 2), (W_, 0.2, H_), STEEL)
    me.box((0, 0, H_ - 0.15), (W_, D_, 0.3), STEEL_D)
    for z in (1.2, 3.5):
        for x in (-W_ / 2 + 0.25, W_ / 2 - 0.25):
            pa.box((x, 0, z), (0.12, D_ - 0.4, 0.5), mul(YELLOW, 0.8))  # bump rails
    for s in (-1, 1):
        pa.box((s * (W_ / 2 + 0.6), -D_ / 2 - 0.15, H_ / 2 - 0.5), (1.6, 0.2, H_ - 1.0), mul(STEEL, 1.1))  # door leaves parked open
    me.box((0, -D_ / 2 - 0.1, H_ - 0.5), (W_ + 3.0, 0.4, 1.0), STEEL_D)
    pr.box((W_ / 2 - 0.25, -1.0, 4.4), (0.08, 0.8, 1.4), mul(BLACK, 1.6))
    for k in range(4):
        pr.cyl((W_ / 2 - 0.3, -1.0, 4.0 + k * 0.28), (W_ / 2 - 0.36, -1.0, 4.0 + k * 0.28), 0.08, (YELLOW, WHITE, WHITE, hexc("C83A3A"))[k], seg=6)
    pr.box((0, 0, H_ - 0.35), (2.0, 1.0, 0.1), WHITE)
    return P


# ── outdoor ────────────────────────────────────────────────────────────────────
def car(name, seed, kind="sedan", smashed=False):
    """abandoned car along Y (front -Y): body from side profiles, glasshouse, flat tyres, dust"""
    P = Prop(name)
    r = rnd(seed)
    pa, G, rb, me, pr, F = P("paint"), P("glass"), P("rubber"), P("metal"), P("plastic"), P("fabric")
    if kind == "sedan":
        Lh, Wd = 7.4, 5.9
        body = [(-7.4, 1.0), (-7.4, 2.25), (-7.1, 2.8), (-3.6, 3.05), (-2.0, 3.15), (4.6, 3.25), (7.0, 3.1), (7.35, 2.55), (7.35, 1.0)]
        cab = [(-2.0, 3.15), (-0.2, 4.55), (3.2, 4.6), (4.7, 3.25)]
        wheels = (-4.6, 4.5)
    else:
        Lh, Wd = 6.4, 5.7
        body = [(-6.4, 1.0), (-6.4, 2.3), (-6.1, 2.85), (-3.2, 3.1), (-1.7, 3.2), (6.0, 3.3), (6.35, 2.6), (6.35, 1.0)]
        cab = [(-1.7, 3.2), (0.1, 4.7), (5.6, 4.75), (6.2, 3.3)]
        wheels = (-3.9, 3.9)
    sag = 0.25 if not smashed else 0.4
    body = [(y, z - sag) for y, z in body]
    cab = [(y, z - sag) for y, z in cab]
    pa.prism(body, -Wd / 2, Wd / 2, BODY)
    # glasshouse: glass prism a little narrower, roof skin and pillars in body colour
    if not smashed:
        G.prism(cab, -Wd / 2 + 0.35, Wd / 2 - 0.35, GLASS_D)
    else:  # glass gone: a dark cabin liner and shards everywhere
        G.prism([(cab[0][0] + 0.3, cab[0][1] - 0.6), (cab[1][0] + 0.3, cab[1][1] - 0.15), (cab[2][0] - 0.3, cab[2][1] - 0.15), (cab[3][0] - 0.3, cab[3][1] - 0.6)],
                -Wd / 2 + 0.5, -Wd / 2 + 0.52, GLASS_D)
    roof = [(cab[1][0] + 0.2, cab[1][1] + 0.02), (cab[2][0] - 0.2, cab[2][1] + 0.02), (cab[2][0] - 0.2, cab[2][1] + 0.14), (cab[1][0] + 0.2, cab[1][1] + 0.14)]
    pa.prism([(y, z) for y, z in roof], -Wd / 2 + 0.45, Wd / 2 - 0.45, BODY)
    for s in (-1, 1):
        x = s * (Wd / 2 - 0.33)
        for (a, b) in ((cab[0], cab[1]), (cab[2], cab[3])):
            pa.tube([(x, a[0], a[1]), (x, b[0], b[1])], 0.12, BODY, seg=4, smooth=False)
        my = (cab[1][0] + cab[2][0]) / 2
        pa.box((x, my, (cab[1][1] + cab[0][1]) / 2 + 0.2), (0.14, 0.3, cab[1][1] - cab[0][1] + 0.2), BODY)
        pr.box((s * (Wd / 2 + 0.3), cab[0][0] + 0.4, cab[0][1] + 0.35), (0.5, 0.4, 0.35), mul(BLACK, 1.5))  # mirror
    # wheels (flat: squashed at the bottom), rims, arches dark
    for y in wheels:
        for s in (-1, 1):
            x = s * (Wd / 2 - 0.45)
            rb.cyl((x - 0.45, y, 0.95), (x + 0.45, y, 0.95), 1.05, RUBBER, seg=12)
            rb.box((x, y, 0.12), (0.95, 1.6, 0.24), RUBBER)  # flattened contact patch
            me.cyl((x + s * 0.46, y, 0.95), (x + s * 0.5, y, 0.95), 0.62, STEEL, seg=10)
    # bumpers, lights, plates, grille
    yF, yR = body[0][0], body[-1][0]
    pr.box((0, yF - 0.15, 1.6 - sag), (Wd + 0.1, 0.5, 0.8), mul(BLACK, 2.0))
    pr.box((0, yR + 0.15, 1.6 - sag), (Wd + 0.1, 0.5, 0.8), mul(BLACK, 2.0))
    for s in (-1, 1):
        pr.box((s * (Wd / 2 - 0.9), yF + 0.02, 2.45 - sag), (1.3, 0.1, 0.45), (0.85, 0.85, 0.8, 1))
        pr.box((s * (Wd / 2 - 0.8), yR - 0.02, 2.5 - sag), (1.1, 0.1, 0.5), hexc("8E2A2A"))
    me.box((0, yF - 0.02, 2.2 - sag), (2.2, 0.08, 0.5), STEEL_D)
    pr.box((0, yF - 0.42, 1.65 - sag), (1.6, 0.04, 0.4), WHITE)
    pr.box((0, yR + 0.42, 1.7 - sag), (1.6, 0.04, 0.4), WHITE)
    # interior: seats, dash, steering wheel
    F.box((0, cab[0][0] + 0.6, cab[0][1] - 0.3), (Wd - 1.0, 1.0, 0.6), mul(BLACK, 2.0))
    for y in (cab[1][0] + 0.8, cab[1][0] + 3.0):
        for s in (-1, 1):
            F.box((s * 1.2, y, 2.6 - sag), (1.7, 1.6, 0.5), FAB_DARK)
            F.box((s * 1.2, y + 0.75, 3.4 - sag), (1.7, 0.35, 1.5), FAB_DARK)
    pr.torus((1.2, cab[0][0] + 1.1, 3.35 - sag), 0.5, 0.06, BLACK, segU=12, segV=4, rot=(R(60), 0, 0))
    # door seams and handles
    for s in (-1, 1):
        x = s * (Wd / 2 + 0.01)
        for y in (cab[1][0] - 0.3, (cab[1][0] + cab[2][0]) / 2, cab[2][0] + 0.1):
            pa.box((x, y, 2.2 - sag), (0.02, 0.05, 1.8), mul(BODY, 0.6))
        for y in (cab[1][0] + 0.5, (cab[1][0] + cab[2][0]) / 2 + 0.6):
            me.box((x + s * 0.02, y, 2.75 - sag), (0.06, 0.5, 0.12), CHROME)
    if smashed:
        # caved roof, glass gone, shards
        for v in pa.bm.verts:
            if v.co.z > 4.0 - sag:
                v.co.z -= 0.3 + 0.2 * math.sin(v.co.y * 1.3)
        scatter_shards(G, r, 0, cab[1][0], 3.5, 50, GLASS)
        scatter_shards(G, r, 0, cab[1][0] + 1.0, 2.0, 30, GLASS, z=2.9 - sag)
    # dust/grime on the body is added by the bake (dust on up-facing panels)
    return P


def parking_barrier(name, seed):
    P = Prop(name)
    r = rnd(seed)
    pa, pr, me = P("paint"), P("plastic"), P("metal")
    pa.box((0, 0, 2.0), (1.4, 1.4, 4.0), YELLOW)
    pa.box((0, 0, 4.1), (1.6, 1.6, 0.2), mul(YELLOW, 0.8))
    for k in range(6):  # boom arm with red/white bands, along -X, snapped near the end
        x0 = -0.8 - k * 1.6
        pa.box((x0 - 0.8, 0, 3.5), (1.6, 0.25, 0.3), WHITE if k % 2 == 0 else hexc("B8352E"))
    pa.box((-11.0, 0.3, 0.2), (1.8, 0.25, 0.3), hexc("B8352E"), rot=(0, R(8), R(30)))  # the broken-off tip on the ground
    pa.box((4.0, 1.0, 2.4), (1.2, 1.0, 4.8), mul(WHITE, 0.9))  # ticket machine
    pr.box((4.0, 0.48, 3.3), (0.8, 0.04, 0.6), (0.05, 0.06, 0.06, 1))
    pr.box((4.0, 0.47, 2.5), (0.5, 0.04, 0.2), mul(BLACK, 1.6))
    me.box((4.0, 1.0, 4.95), (1.4, 1.2, 0.15), STEEL_D)
    return P


def bus_shelter(name, seed):
    P = Prop(name)
    r = rnd(seed)
    me, G, pr, W = P("metal"), P("glass"), P("plastic"), P("wood")
    L, D, H = 10.0, 4.0, 8.0
    for x in (-L / 2, 0, L / 2):
        me.box((x, D / 2 - 0.1, H / 2), (0.2, 0.2, H), STEEL_D)
    for x in (-L / 2, L / 2):
        me.box((x, -D / 2 + 0.6, H / 2), (0.2, 0.2, H), STEEL_D)
    me.box((0, 0.2, H + 0.1), (L + 0.6, D + 0.8, 0.25), STEEL)
    pr.box((0, 0.2, H - 0.05), (L, D, 0.05), (0.5, 0.55, 0.55, 1))
    for k, (x0, x1) in enumerate(((-L / 2, 0), (0, L / 2))):
        if k == 1:
            broken_pane(G, x0 + 0.1, x1 - 0.1, 0.6, H - 0.6, GLASS, r, y=D / 2 - 0.1)
            scatter_shards(G, r, (x0 + x1) / 2, D / 2 - 1.0, 1.6, 26, GLASS)
        else:
            G.box(((x0 + x1) / 2, D / 2 - 0.1, H / 2), (x1 - x0 - 0.2, 0.06, H - 1.2), GLASS)
    G.box((-L / 2, (D / 2 - 0.1 + (-D / 2 + 0.6)) / 2, H / 2), (0.06, D - 0.7, H - 1.2), GLASS)
    pr.box((L / 2, 0.2, H / 2 + 0.4), (0.4, D - 1.0, 5.0), mul(BLACK, 2.0))  # ad panel (blank)
    pr.box((L / 2 - 0.22, 0.2, H / 2 + 0.4), (0.02, D - 1.4, 4.6), (0.75, 0.74, 0.7, 1))
    me.box((-1.0, D / 2 - 0.9, 1.5), (6.0, 1.0, 0.12), STEEL)
    for x in (-3.6, 1.6):
        me.box((x, D / 2 - 0.9, 0.75), (0.15, 0.8, 1.5), STEEL_D)
    return P


def trolley_bay(name, seed):
    P = Prop(name)
    me, pr = P("metal"), P("plastic")
    L, D, H = 12.0, 6.0, 7.0
    for x in (-L / 2, 0, L / 2):
        for y in (-D / 2, D / 2):
            me.tube([(x, y, 0), (x, y, H)], 0.12, STEEL_D, seg=6)
    for y in (-D / 2, D / 2):
        me.tube([(-L / 2, y, H), (L / 2, y, H)], 0.12, STEEL_D, seg=6)
        me.tube([(-L / 2, y, 2.4), (L / 2, y, 2.4)], 0.08, STEEL, seg=6)
    pr.box((0, 0, H + 0.2), (L + 0.6, D + 0.6, 0.15), hexc("2E5E7E"))
    pr.box((0, -D / 2 - 0.35, H - 0.6), (L + 0.6, 0.1, 1.0), hexc("2E5E7E"))
    return P


def hvac(name, seed):
    """rooftop air-handling unit 10 x 5 x 5 with fan housings and louvres"""
    P = Prop(name)
    r = rnd(seed)
    pa, me = P("paint"), P("metal")
    col = (0.68, 0.69, 0.66, 1)
    me.box((0, 0, 0.4), (10.4, 5.4, 0.8), STEEL_D)
    pa.box((0, 0, 3.0), (10.0, 5.0, 4.4), col)
    for k in range(2):
        x = -2.5 + k * 5.0
        me.cyl((x, 0, 5.2), (x, 0, 5.8), 1.9, mul(col, 0.9), seg=16)
        me.cyl((x, 0, 5.8), (x, 0, 5.85), 1.7, mul(BLACK, 2), seg=16)
        for a in range(5):
            an = a * 2 * math.pi / 5 + r.uniform(0, 0.4)
            me.box((x + math.cos(an) * 0.8, math.sin(an) * 0.8, 5.6), (1.4, 0.4, 0.05), STEEL, rot=(R(20), 0, an))
    for s in (-1, 1):
        for j in range(8):
            pa.box((2.6, s * 2.52, 1.6 + j * 0.4), (4.0, 0.05, 0.12), mul(col, 0.7))
    me.cyl((-5.0, 1.5, 1.4), (-7.0, 1.5, 1.4), 0.35, STEEL, seg=8)
    me.cyl((-5.0, -1.5, 1.4), (-7.0, -1.5, 1.4), 0.25, STEEL, seg=8)
    return P


def projector(name, seed):
    P = Prop(name)
    pa, me = P("paint"), P("metal")
    me.box((0, 0, 1.6), (2.4, 2.4, 3.2), STEEL_D)
    pa.box((0, 0, 4.2), (2.2, 3.6, 2.0), hexc("3A3E46"))
    me.cyl((0, -1.8, 4.2), (0, -2.8, 4.2), 0.45, mul(BLACK, 1.5), seg=12)
    for y in (-0.8, 1.0):
        me.cyl((-1.3, y, 5.6), (1.3, y, 5.6), 0.9, STEEL, seg=14)  # reels
    me.cyl((0, 1.0, 5.2), (0, 1.0, 7.0), 0.3, STEEL_D, seg=8)
    return P


def cardboard_pile(name, seed):
    P = Prop(name)
    r = rnd(seed)
    C = P("cardboard")
    for k in range(6):
        C.box((r.uniform(-1.5, 1.5), r.uniform(-1.2, 1.2), 0.03 + k * 0.03), (r.uniform(1.6, 2.6), r.uniform(1.2, 2.0), 0.04), r.choice((CARD, CARD_D)),
              rot=(0, 0, r.uniform(0, 3.1)))
    for k in range(4):
        w = r.uniform(0.8, 1.4)
        C.box((r.uniform(-1.4, 1.4), r.uniform(-1.0, 1.0), w / 2), (w, w * 0.8, w), r.choice((CARD, CARD_D)), rot=(R(r.uniform(-10, 10)), 0, r.uniform(0, 3)))
    return P


def scaffold_barrier(name, seed):
    """a construction hoarding run 12 long: plywood panels on a scaffold frame, one panel kicked in"""
    P = Prop(name)
    r = rnd(seed)
    W, me = P("wood"), P("metal")
    L, H = 12.0, 8.0
    for k in range(3):
        x = -L / 2 + (k + 0.5) * L / 3
        if k == 1:
            W.box((x, -0.8, 1.6), (L / 3 - 0.1, 0.12, 3.6), mul(WOOD, 0.95), rot=(R(-68), 0, R(6)))
            W.box((x, 0, 6.0), (L / 3 - 0.1, 0.12, 4.0), mul(WOOD, 1.05))
        else:
            W.box((x, 0, H / 2), (L / 3 - 0.1, 0.12, H), mul(WOOD, 1.0 + r.uniform(-0.06, 0.06)))
    for x in (-L / 2, 0, L / 2):
        me.tube([(x, 0.4, 0), (x, 0.4, H + 0.5)], 0.1, STEEL, seg=6)
    for z in (1.0, 4.5, H):
        me.tube([(-L / 2, 0.4, z), (L / 2, 0.4, z)], 0.08, STEEL, seg=6)
    return P


PROPS = {
    "PalletRack": lambda: pallet_rack("PalletRack", 401),
    "PalletBoxes": lambda: pallet_boxes("PalletBoxes", 402),
    "RollCage": lambda: roll_cage("RollCage", 403),
    "StorageShelf": lambda: storage_shelf("StorageShelf", 404),
    "StorageShelfEmpty": lambda: storage_shelf("StorageShelfEmpty", 405, empty=True),
    "Lockers": lambda: lockers("Lockers", 406),
    "OfficeDesk": lambda: office_desk("OfficeDesk", 407),
    "CCTVDesk": lambda: cctv_desk("CCTVDesk", 408),
    "ElectricCabinet": lambda: electric_cabinet("ElectricCabinet", 409),
    "Generator": lambda: generator("Generator", 410),
    "Forklift": lambda: forklift("Forklift", 411),
    "DockDoor": lambda: dock_door("DockDoor", 412),
    "DockDoorOpen": lambda: dock_door("DockDoorOpen", 413, open_=True),
    "CargoLift": lambda: cargo_lift("CargoLift", 414),
    "CarSedan": lambda: car("CarSedan", 421, "sedan"),
    "CarHatch": lambda: car("CarHatch", 422, "hatch"),
    "CarSedanSmashed": lambda: car("CarSedanSmashed", 423, "sedan", smashed=True),
    "ParkingBarrier": lambda: parking_barrier("ParkingBarrier", 431),
    "BusShelter": lambda: bus_shelter("BusShelter", 432),
    "TrolleyBay": lambda: trolley_bay("TrolleyBay", 433),
    "HVAC": lambda: hvac("HVAC", 434),
    "Projector": lambda: projector("Projector", 435),
    "CardboardPile": lambda: cardboard_pile("CardboardPile", 436),
    "Hoarding": lambda: scaffold_barrier("Hoarding", 437),
}
BAKE = {
    "PalletRack": dict(ao_dist=2.0),
    "CarSedan": dict(dust=0.24),
    "CarHatch": dict(dust=0.24),
    "CarSedanSmashed": dict(dust=0.3),
}


def scene():
    return batch_scene(SCENE)


def clear(prefix):
    for o in list(bpy.data.objects):
        if o.name.startswith(prefix):
            m = o.data
            bpy.data.objects.remove(o)
            if m and m.users == 0:
                bpy.data.meshes.remove(m)


def build(names=None, budget=45.0):
    import time
    scn = scene()
    out = {}
    t0 = time.time()
    for nm in (names or list(PROPS)):
        clear("ZR_MK_%s__" % nm)
        P = PROPS[nm]()
        objs = P.finish(scn.collection, **BAKE.get(nm, {}))
        out[nm] = sum(len(o.data.polygons) for o in objs)
        if time.time() - t0 > budget:
            out["_stopped_after"] = nm
            break
    return out


def objects():
    keys = set(PROPS)
    return [o for o in scene().collection.objects if o.name.startswith("ZR_MK_") and o.name[6:].split("__")[0] in keys]


def export():
    objs = objects()
    fbx, meta, props = kit_export(objs, BATCH, scene())
    return fbx, len(objs), props


def turn(nm, out_png=None, **kw):
    out_png = out_png or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "build", "kit_%s.png" % nm)
    return turntable([o for o in objects() if o.name.startswith("ZR_MK_%s__" % nm)], out_png, **kw)

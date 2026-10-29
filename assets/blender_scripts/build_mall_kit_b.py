"""Zero Return - Meridian Mall kit, batch B: store furnishings (M13). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_mall_kit_b.py").read(), g); g["build"](names or None)
   then g["export"]() -> assets/exports/ZR_MallKitB.fbx (+ .blend, .meta.json, .props.json)
Origin bottom-centre, front toward Blender -Y (Roblox LookVector). Shelf products are low-poly blocks, cans and
bottles in packaging colours (original, no brands). All geometry is original and procedural.
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
BATCH = "ZR_MallKitB"

WHITE = (0.86, 0.86, 0.83, 1)
SHELF_W = (0.8, 0.8, 0.78, 1)
STEEL = (0.52, 0.53, 0.54, 1)
STEEL_D = (0.26, 0.27, 0.28, 1)
CHROME = (0.74, 0.75, 0.76, 1)
GLASS = (0.64, 0.72, 0.73, 1)
BLACK = (0.08, 0.08, 0.085, 1)
RUBBER = (0.11, 0.11, 0.11, 1)
LAM_L = hexc("B9A98C")
LAM_D = hexc("5E4B3B")
LAM_W = (0.82, 0.81, 0.77, 1)
FAB_RED = hexc("7E2A2C")
FAB_DARK = hexc("2E2F33")
CONC = (0.62, 0.62, 0.6, 1)
SOOT = hexc("1E1B19")

PACK = [hexc(h) for h in ("B8352E", "D9A82E", "2E5E9E", "3E8E4A", "E0DED5", "D97A2E", "6A3E8E", "C8C2B0", "9E2E5E", "4FA0B8",
                          "E8D24A", "8C5A3A", "A8B83A", "D45A8A", "3A6E6E", "F0EEE6")]
MEDS = [hexc(h) for h in ("F0EEE8", "E6E8F0", "3E6EAE", "4FA0B8", "D9D2C0", "8EC0D8", "E8F0E8", "C83A3A", "6AAE6E")]
BOOKS = [hexc(h) for h in ("7A2E2E", "2E4A6E", "3E5E3E", "8C6A3A", "5A3E6A", "B8A88A", "2E2E2E", "A84A2E", "D8CCAA")]
CLOTH = [hexc(h) for h in ("3A3F4A", "6A2E2E", "C8C0B0", "2E4A3E", "8C7A5A", "4A5A7A", "B8B8B4", "5A4A6A", "A86A4A", "2A2A2A", "D8D0C0")]


def mul(c, k):
    return shade(c, k)


def frange(a, b, s):
    out = []
    x = a
    while x <= b + 1e-6:
        out.append(x)
        x += s
    return out


# ── products ───────────────────────────────────────────────────────────────────
def products(b, r, x0, x1, ya, yb, z, hmax, density=0.92, palette=PACK, kinds=("box", "box", "can", "bottle", "jar"), fallen=0.06):
    """a shelf strip from x0 to x1, depth ya (front) .. yb (back), standing on z; front facings in detail, the
    rest of the row as one darker filler block behind them"""
    depth = abs(yb - ya)
    sgn = 1 if yb > ya else -1
    x = x0 + 0.03
    while x < x1 - 0.12:
        if r.random() > density:
            x += r.uniform(0.25, 0.7)
            continue
        kind = r.choice(kinds)
        col = mix(r.choice(palette), (0.72, 0.71, 0.68, 1), 0.12)
        if kind == "box":
            w = min(r.uniform(0.28, 0.62), x1 - x)
            h = min(hmax - 0.05, r.uniform(0.5, 1.15))
            d = depth * r.uniform(0.7, 0.95)
            if r.random() < fallen:
                b.box((x + w / 2, ya + sgn * (0.25), z + 0.14), (w * 0.95, h * 0.9, 0.26), col, rot=(0, 0, r.uniform(-0.3, 0.3)))
            else:
                b.box((x + w / 2, ya + sgn * d / 2, z + h / 2), (w - 0.03, d, h), col)
                b.box((x + w / 2, ya + sgn * 0.001 - sgn * 0.002, z + h * 0.62), (w - 0.06, 0.012, h * 0.22), mul(col, 1.25))  # label band
            x += w
        elif kind in ("can", "jar"):
            dia = r.uniform(0.2, 0.3) if kind == "can" else r.uniform(0.26, 0.36)
            h = min(hmax - 0.05, r.uniform(0.32, 0.46) if kind == "can" else r.uniform(0.34, 0.5))
            cx = x + dia / 2
            b.cyl((cx, ya + sgn * dia / 2, z), (cx, ya + sgn * dia / 2, z + h), dia / 2, col if kind == "can" else mul(col, 0.9), seg=7)
            if kind == "jar":
                b.cyl((cx, ya + sgn * dia / 2, z + h), (cx, ya + sgn * dia / 2, z + h + 0.07), dia * 0.42, mul(PACK[0], 0.9), seg=7)
            b.box((cx, ya + sgn * (dia + (depth - dia) / 2), z + h * 0.48), (dia * 0.9, max(0.05, depth - dia - 0.04), h * 0.95), mul(col, 0.55))
            x += dia + 0.02
        else:  # bottle
            dia = r.uniform(0.24, 0.3)
            h = min(hmax - 0.08, r.uniform(0.75, 1.05))
            cx = x + dia / 2
            yc = ya + sgn * dia / 2
            b.cyl((cx, yc, z), (cx, yc, z + h * 0.68), dia / 2, col, seg=7)
            b.cyl((cx, yc, z + h * 0.68), (cx, yc, z + h * 0.88), dia / 2, col, r2=dia * 0.18, seg=7)
            b.cyl((cx, yc, z + h * 0.88), (cx, yc, z + h), dia * 0.16, mul(col, 0.7), seg=6)
            b.box((cx, ya + sgn * (dia + (depth - dia) / 2), z + h * 0.4), (dia * 0.9, max(0.05, depth - dia - 0.04), h * 0.8), mul(col, 0.5))
            x += dia + 0.03


def floor_spill(b, r, cx, cy, rad, n, palette=PACK):
    """products knocked onto the floor"""
    for _ in range(n):
        a, d = r.uniform(0, 6.283), rad * math.sqrt(r.random())
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        col = mix(r.choice(palette), (0.7, 0.7, 0.68, 1), 0.15)
        if r.random() < 0.6:
            w, h, dd = r.uniform(0.3, 0.6), r.uniform(0.18, 0.3), r.uniform(0.5, 1.0)
            b.box((x, y, h / 2), (w, dd, h), col, rot=(0, 0, r.uniform(0, 6.28)))
        else:
            dia, L = r.uniform(0.2, 0.3), r.uniform(0.32, 0.9)
            ang = r.uniform(0, 6.28)
            dv = Vector((math.cos(ang), math.sin(ang), 0)) * L / 2
            c = Vector((x, y, dia / 2))
            b.cyl(c - dv, c + dv, dia / 2, col, seg=7)


# ── shelving ───────────────────────────────────────────────────────────────────
def gondola(name, seed, state="full", palette=PACK, L=8.0, H=6.0, D=3.6, levels=(0.55, 1.75, 2.95, 4.15)):
    """double-sided supermarket gondola along X; state: full, sparse, toppled"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, pr = P("paint"), P("metal"), P("plastic")
    density = {"full": 0.95, "sparse": 0.42, "toppled": 0.0}[state]
    pa.box((0, 0, 0.25), (L, D - 0.1, 0.5), mul(SHELF_W, 0.78))
    pa.box((0, 0, H / 2), (L, 0.1, H - 0.2), SHELF_W)
    for x in (-L / 2 + 0.06, 0, L / 2 - 0.06):
        pa.box((x, 0, H / 2), (0.12, 0.5, H), mul(SHELF_W, 0.88))
    for side in (-1, 1):
        for i, z in enumerate(levels):
            ya, yb = side * (D / 2), side * 0.08
            if i > 0:
                me.box((0, (ya + yb) / 2, z - 0.04), (L - 0.14, abs(ya - yb), 0.06), STEEL)
            pr.box((0, ya + side * 0.01, z + 0.06), (L - 0.14, 0.03, 0.16), r.choice((WHITE, hexc("E8D24A"))))  # ticket strip
            top = levels[i + 1] if i + 1 < len(levels) else H - 0.3
            if density > 0:
                products(pr, r, -L / 2 + 0.12, L / 2 - 0.12, ya + side * 0.05, yb - side * 0.02, z + 0.02, top - z - 0.1,
                         density=density, palette=palette, fallen=0.05 if state == "full" else 0.22)
    pr.box((0, 0, H + 0.35), (L * 0.55, 0.12, 0.7), mul(WHITE, 0.95))  # header board
    if state == "sparse":
        floor_spill(pr, r, r.uniform(-2, 2), -D / 2 - 1.0, 1.4, 7, palette)
    if state == "toppled":
        # the whole unit lies on its back (-Y side up), products all over the floor in front
        P.transform(Matrix.Translation((0, D / 2, 0)) @ Matrix.Rotation(R(-86), 4, "X") @ Matrix.Translation((0, -D / 2, 0)))
        P.transform(Matrix.Translation((0, -H / 2, 0)))
        floor_spill(pr, r, 0, -2.0, 3.2, 26, palette)
        floor_spill(pr, r, 0, 4.5, 2.5, 14, palette)
    return P


def wall_shelf(name, seed, state="stocked", palette=PACK, L=8.0, H=7.0, D=2.0, kinds=("box", "box", "can", "bottle", "jar")):
    """single-sided shelving against a wall (back at +Y), shelves face -Y"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, pr = P("paint"), P("metal"), P("plastic")
    levels = (0.5, 1.7, 2.9, 4.1, 5.3)
    density = {"stocked": 0.93, "sparse": 0.38, "empty": 0.06}[state]
    pa.box((0, D / 2 - 0.05, H / 2), (L, 0.1, H), SHELF_W)
    pa.box((0, 0, 0.22), (L, D, 0.44), mul(SHELF_W, 0.75))
    for x in (-L / 2 + 0.06, 0, L / 2 - 0.06):
        pa.box((x, D / 2 - 0.25, H / 2), (0.12, 0.5, H), mul(SHELF_W, 0.86))
    for i, z in enumerate(levels):
        if i > 0:
            me.box((0, 0.0, z - 0.04), (L - 0.14, D - 0.1, 0.06), STEEL)
        pr.box((0, -D / 2 + 0.03, z + 0.06), (L - 0.14, 0.03, 0.16), WHITE)
        top = levels[i + 1] if i + 1 < len(levels) else H - 0.2
        products(pr, r, -L / 2 + 0.12, L / 2 - 0.12, -D / 2 + 0.08, D / 2 - 0.15, z + 0.02, top - z - 0.1, density=density,
                 palette=palette, kinds=kinds, fallen=0.05 if state == "stocked" else 0.25)
    pr.box((0, D / 2 - 0.2, H + 0.4), (L * 0.6, 0.12, 0.8), WHITE)
    if state != "stocked":
        floor_spill(pr, r, r.uniform(-2.5, 2.5), -D / 2 - 0.9, 1.2, 6, palette)
    return P


def fridge(name, seed, state="dead"):
    """upright glass-door fridge run, 8 long, 7 tall, 3 deep, doors on -Y; one door hangs open"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, pr, G = P("paint"), P("metal"), P("plastic"), P("glass")
    L, H, D = 8.0, 7.0, 3.0
    pa.box((0, 0.1, H / 2), (L, D - 0.2, H), WHITE)
    pa.box((0, -D / 2 + 0.25, H - 0.45), (L, 0.5, 0.9), mul(WHITE, 0.9))  # canopy
    pa.box((0, -D / 2 + 0.25, 0.3), (L, 0.5, 0.6), STEEL_D)  # kick grille
    me.box((0, -0.2, H / 2), (L - 0.4, D - 0.8, H - 1.6), mul(STEEL_D, 0.7))  # dark interior liner
    for z in (1.2, 2.4, 3.6, 4.8):
        me.box((0, -0.35, z), (L - 0.5, D - 1.0, 0.05), STEEL)
        products(pr, r, -L / 2 + 0.3, L / 2 - 0.3, -D / 2 + 0.55, D / 2 - 0.6, z + 0.03, 1.1, density=0.75, kinds=("bottle", "bottle", "can", "box"))
    for k in range(4):
        x0 = -L / 2 + 0.15 + k * (L - 0.3) / 4
        x1 = x0 + (L - 0.3) / 4
        open_ = (k == 2)
        frame_y = -D / 2 + 0.05
        if open_:
            # door swung open ~100 degrees about its left hinge
            m = Matrix.Translation((x0, frame_y, 0)) @ Matrix.Rotation(R(-100), 4, "Z") @ Matrix.Translation((-x0, -frame_y, 0))
        else:
            m = Matrix.Identity(4)
        bf_me, bf_g = set(me.bm.verts), set(G.bm.verts)
        for (cx, cz, sx, sz) in (((x0 + x1) / 2, 0.75, x1 - x0, 0.18), ((x0 + x1) / 2, H - 1.0, x1 - x0, 0.18), (x0 + 0.06, (H - 0.25) / 2 + 0.4, 0.12, H - 1.6), (x1 - 0.06, (H - 0.25) / 2 + 0.4, 0.12, H - 1.6)):
            me.box((cx, frame_y, cz), (sx, 0.12, sz), CHROME)
        me.box((x1 - 0.3, frame_y - 0.12, 3.6), (0.08, 0.08, 2.2), CHROME)  # handle
        if k == 1 and state == "broken":
            broken_pane(G, x0 + 0.12, x1 - 0.12, 0.84, H - 1.09, GLASS, r, y=frame_y)
        else:
            G.box(((x0 + x1) / 2, frame_y, (0.84 + H - 1.09) / 2), (x1 - x0 - 0.24, 0.05, H - 1.93), GLASS)
        if open_:
            bmesh.ops.transform(me.bm, matrix=m, verts=[v for v in me.bm.verts if v not in bf_me])
            bmesh.ops.transform(G.bm, matrix=m, verts=[v for v in G.bm.verts if v not in bf_g])
    if state == "broken":
        scatter_shards(G, r, -1.3, -D / 2 - 1.0, 1.0, 22, GLASS)
        floor_spill(pr, r, 0, -D / 2 - 1.2, 1.6, 8)
    return P


def checkout(name, seed):
    """checkout counter along X (customer side -Y, cashier side +Y): belt, scanner, register, card terminal,
    bagging well, cashier chair, lane light"""
    P = Prop(name)
    r = rnd(seed)
    W, me, rb, pr = P("wood"), P("metal"), P("rubber"), P("plastic")
    L = 8.0
    W.box((0, 0, 1.5), (L, 2.4, 3.0), LAM_L)
    W.box((0, -1.22, 1.5), (L - 0.2, 0.04, 2.6), mul(LAM_L, 0.85))
    me.box((-1.4, -0.4, 3.04), (5.0, 1.5, 0.08), STEEL)
    rb.box((-1.4, -0.4, 3.1), (4.6, 1.2, 0.05), RUBBER)
    me.box((1.6, -0.2, 3.06), (1.0, 1.2, 0.12), STEEL_D)  # scanner bed
    pr.box((1.6, -0.2, 3.14), (0.7, 0.7, 0.04), (0.2, 0.25, 0.2, 1))
    me.box((3.3, -0.2, 2.5), (1.4, 2.0, 0.08), STEEL)  # bagging well
    for x in (2.6, 4.0):
        me.box((x, -0.2, 2.8), (0.08, 2.0, 0.6), STEEL)
    # register: screen on a post, keyboard, drawer open toward the cashier
    me.cyl((1.0, 0.8, 3.0), (1.0, 0.8, 3.9), 0.08, STEEL_D, seg=6)
    pr.box((1.0, 0.75, 4.3), (1.1, 0.12, 0.8), BLACK, rot=(R(-12), 0, 0))
    pr.box((0.4, 0.6, 3.08), (0.9, 0.5, 0.1), mul(BLACK, 1.5))
    pr.box((0.6, 1.35, 2.6), (1.4, 0.9, 0.35), mul(BLACK, 1.4))  # drawer (open)
    for k in range(4):
        pr.box((0.15 + k * 0.32, 1.45, 2.8), (0.28, 0.6, 0.02), hexc("6E8A5A"))
    # card terminal and a divider bar
    me.cyl((-0.4, -1.0, 3.0), (-0.4, -1.0, 3.6), 0.05, STEEL_D, seg=6)
    pr.box((-0.4, -1.05, 3.75), (0.35, 0.18, 0.55), BLACK, rot=(R(20), 0, 0))
    pr.box((-2.2, -0.5, 3.18), (1.2, 0.12, 0.18), hexc("C83A3A"))
    # lane light pole with a number box
    me.cyl((-L / 2 + 0.3, 1.0, 3.0), (-L / 2 + 0.3, 1.0, 7.4), 0.07, STEEL, seg=6)
    pr.box((-L / 2 + 0.3, 1.0, 7.8), (0.7, 0.7, 0.8), WHITE)
    # cashier chair (pushed back, a little turned)
    m = Matrix.Translation((-0.6, 2.4, 0)) @ Matrix.Rotation(R(r.uniform(-30, 30)), 4, "Z")
    bf = set(pr.bm.verts), set(me.bm.verts)
    me.cyl((0, 0, 0.1), (0, 0, 2.0), 0.08, STEEL_D, seg=6)
    for a in range(5):
        an = a * 2 * math.pi / 5
        me.box((math.cos(an) * 0.55, math.sin(an) * 0.55, 0.12), (1.1, 0.12, 0.08), STEEL_D, rot=(0, 0, an))
    pr.box((0, 0, 2.1), (1.4, 1.4, 0.3), FAB_DARK)
    pr.box((0, 0.68, 3.0), (1.3, 0.2, 1.4), FAB_DARK)
    bmesh.ops.transform(pr.bm, matrix=m, verts=[v for v in pr.bm.verts if v not in bf[0]])
    bmesh.ops.transform(me.bm, matrix=m, verts=[v for v in me.bm.verts if v not in bf[1]])
    # a few products left on the belt
    for k in range(3):
        pr.box((-3.0 + k * 0.9, -0.4, 3.3), (0.5, 0.4, r.uniform(0.3, 0.6)), r.choice(PACK), rot=(0, 0, r.uniform(-0.4, 0.4)))
    return P


def trolley(name, seed, tipped=False, count=1):
    """shopping trolley along Y (handle at +Y); count > 1 nests a row"""
    P = Prop(name)
    r = rnd(seed)
    C, pr, rb = P("chrome"), P("plastic"), P("rubber")
    for n in range(count):
        oy = -n * 1.0
        bfC, bfP, bfR = set(C.bm.verts), set(pr.bm.verts), set(rb.bm.verts)
        # chassis
        for sx in (-0.75, 0.75):
            C.tube([(sx, 1.4 + oy, 0.45), (sx * 0.8, -1.4 + oy, 0.45)], 0.05, CHROME, seg=5)
        C.tube([(-0.75, 1.4 + oy, 0.45), (0.75, 1.4 + oy, 0.45)], 0.05, CHROME, seg=5)
        C.tube([(-0.6, -1.4 + oy, 0.45), (0.6, -1.4 + oy, 0.45)], 0.05, CHROME, seg=5)
        for (x, y) in ((-0.7, 1.3), (0.7, 1.3), (-0.55, -1.3), (0.55, -1.3)):
            rb.cyl((x - 0.06, y + oy, 0.18), (x + 0.06, y + oy, 0.18), 0.17, RUBBER, seg=8)
            C.tube([(x, y + oy, 0.45), (x, y + oy, 0.3)], 0.04, CHROME, seg=4)
        # basket: tapered wire box from z 1.3 to 2.9, longer at the top
        def corner(sx, sy, z):
            t = (z - 1.3) / 1.6
            w = 0.7 + 0.15 * t
            yb, yf = 1.3 + 0.1 * t, -1.2 - 0.3 * t
            return (sx * w, (yb if sy > 0 else yf) + oy, z)
        for z in (1.3, 1.85, 2.4, 2.9):
            pts = [corner(-1, -1, z), corner(1, -1, z), corner(1, 1, z), corner(-1, 1, z), corner(-1, -1, z)]
            C.tube(pts, 0.035 if z < 2.9 else 0.05, CHROME, seg=4, smooth=False)
        for k in range(7):
            t = k / 6
            for sx in (-1, 1):
                a, b = corner(sx, -1, 1.3), corner(sx, 1, 1.3)
                c, d = corner(sx, -1, 2.9), corner(sx, 1, 2.9)
                p0 = Vector(a).lerp(Vector(b), t)
                p1 = Vector(c).lerp(Vector(d), t)
                C.tube([p0, p1], 0.028, CHROME, seg=4, smooth=False)
        for k in range(5):
            t = k / 4
            p0 = Vector(corner(-1, -1, 1.3)).lerp(Vector(corner(1, -1, 1.3)), t)
            p1 = Vector(corner(-1, -1, 2.9)).lerp(Vector(corner(1, -1, 2.9)), t)
            C.tube([p0, p1], 0.028, CHROME, seg=4, smooth=False)
        # frame posts and the handle
        for sx in (-0.72, 0.72):
            C.tube([(sx, 1.4 + oy, 0.45), (sx * 1.05, 1.55 + oy, 3.0), (sx * 1.05, 1.75 + oy, 3.35)], 0.05, CHROME, seg=5)
        pr.cyl((-0.85, 1.78 + oy, 3.38), (0.85, 1.78 + oy, 3.38), 0.09, hexc("B8352E"), seg=8)
        if tipped and n == 0:
            m = Matrix.Translation((0.95, 0, 0)) @ Matrix.Rotation(R(-82), 4, "Y") @ Matrix.Translation((-0.95, 0, 0))
            for b, bf in ((C, bfC), (pr, bfP), (rb, bfR)):
                bmesh.ops.transform(b.bm, matrix=m, verts=[v for v in b.bm.verts if v not in bf])
    if tipped:
        floor_spill(pr, r, -1.6, -0.5, 1.4, 6)
    return P


def kiosk(name, seed, burnt=False):
    """island kiosk 10 x 6: counters on four sides with a gap at the back, posts, canopy with a sign band"""
    P = Prop(name)
    r = rnd(seed)
    W, me, pr = P("wood"), P("metal"), P("plastic")
    LX, LY = 10.0, 6.0
    lam = SOOT if burnt else LAM_W
    top = mul(SOOT, 1.3) if burnt else LAM_D
    W.box((0, -LY / 2 + 0.6, 1.6), (LX, 1.2, 3.2), lam)
    W.box((-LX / 2 + 0.6, 0.3, 1.6), (1.2, LY - 2.4, 3.2), lam)
    W.box((LX / 2 - 0.6, 0.3, 1.6), (1.2, LY - 2.4, 3.2), lam)
    W.box((-2.0, LY / 2 - 0.6, 1.6), (LX - 6.0 + 2.0, 1.2, 3.2), lam)
    for (x, y, sx, sy) in ((0, -LY / 2 + 0.6, LX + 0.2, 1.4), (-LX / 2 + 0.6, 0.3, 1.4, LY - 2.4), (LX / 2 - 0.6, 0.3, 1.4, LY - 2.4), (-2.0, LY / 2 - 0.6, 6.2, 1.4)):
        W.box((x, y, 3.25), (sx, sy, 0.1), top)
    posts = ((-LX / 2 + 0.3, -LY / 2 + 0.3), (LX / 2 - 0.3, -LY / 2 + 0.3), (-LX / 2 + 0.3, LY / 2 - 0.3), (LX / 2 - 0.3, LY / 2 - 0.3))
    for (x, y) in posts:
        me.box((x, y, 6.4), (0.25, 0.25, 6.2), STEEL_D)
    if burnt:
        # canopy collapsed on one side, scorched
        me.box((0, 0, 8.4), (LX + 0.6, LY + 0.6, 0.25), mul(SOOT, 1.4), rot=(R(14), R(-6), 0))
        pr.box((0, -LY / 2 - 0.2, 8.0), (LX * 0.8, 0.2, 1.0), mul(SOOT, 1.6), rot=(R(30), 0, R(8)))
        chunks(W, r, 0, -LY / 2 - 1.2, 2.0, 10, 0.4, SOOT)
        chunks(W, r, 1.0, 0.5, 2.0, 8, 0.45, mul(SOOT, 1.4), zbase=0.0)
    else:
        me.box((0, 0, 9.5), (LX + 0.6, LY + 0.6, 0.3), mul(WHITE, 0.9))
        pr.box((0, -LY / 2 - 0.32, 9.0), (LX + 0.6, 0.12, 1.0), hexc("2E5E7E"))
        pr.box((0, LY / 2 + 0.32, 9.0), (LX + 0.6, 0.12, 1.0), hexc("2E5E7E"))
        # stock on the counters and racks inside
        products(pr, r, -LX / 2 + 1.4, LX / 2 - 1.4, -LY / 2 + 0.25, -LY / 2 + 1.05, 3.3, 1.0, density=0.6, kinds=("box", "box", "jar"))
        me.box((0, 0.3, 2.0), (LX - 3.0, 0.1, 4.0), STEEL)
        for z in (1.2, 2.4, 3.6):
            me.box((0, 0.6, z), (LX - 3.2, 0.6, 0.05), STEEL)
            products(pr, r, -LX / 2 + 1.7, LX / 2 - 1.7, 0.35, 0.9, z + 0.03, 1.0, density=0.7)
        pr.box((2.5, LY / 2 - 0.4, 0.6), (1.0, 1.0, 1.2), FAB_DARK)  # stool
    return P


def clothes_rack(name, seed, fallen=False):
    """round garment rack (dia 4.4): chrome ring on a centre post, hanging garments around"""
    P = Prop(name)
    r = rnd(seed)
    C, F = P("chrome"), P("fabric")
    Rr = 2.1
    C.cyl((0, 0, 0.0), (0, 0, 0.12), 1.1, CHROME, seg=12)
    C.cyl((0, 0, 0.12), (0, 0, 4.7), 0.07, CHROME, seg=6)
    C.torus((0, 0, 4.6), Rr, 0.05, CHROME, segU=20, segV=4)
    for k in range(4):
        a = k * math.pi / 2
        C.tube([(0, 0, 4.6), (math.cos(a) * Rr, math.sin(a) * Rr, 4.6)], 0.04, CHROME, seg=4)
    n = 26
    for k in range(n):
        if r.random() < 0.18:
            continue
        a = 2 * math.pi * k / n + r.uniform(-0.05, 0.05)
        col = mix(r.choice(CLOTH), (0.6, 0.6, 0.58, 1), 0.1)
        L = r.uniform(2.3, 3.4)
        c = Vector((math.cos(a) * Rr, math.sin(a) * Rr, 4.55 - L / 2))
        F.box(tuple(c), (0.16, 1.15, L), col, rot=(R(r.uniform(-4, 4)), 0, a + math.pi / 2 + r.uniform(-0.1, 0.1)))
        F.box(tuple(c + Vector((0, 0, L / 2 - 0.25))), (0.18, 1.5, 0.3), mul(col, 0.95), rot=(0, 0, a + math.pi / 2))
    if fallen:
        P.transform(Matrix.Translation((0, -0.4, 0.2)) @ Matrix.Rotation(R(84), 4, "X"))
        for k in range(5):
            F.box((r.uniform(-2, 2), r.uniform(-3, 1), 0.06), (1.2, 2.0, 0.08), r.choice(CLOTH), rot=(0, 0, r.uniform(0, 6.28)))
    return P


def mannequin(name, seed, fallen=False, dressed=True):
    """an abstract featureless display figure (6 tall) on a glass-foot stand; original generic form"""
    P = Prop(name)
    r = rnd(seed)
    pr, me, F = P("plastic"), P("chrome"), P("fabric")
    SK = (0.88, 0.87, 0.84, 1)
    me.cyl((0, 0, 0), (0, 0, 0.1), 0.9, CHROME, seg=12)
    me.cyl((0, 0, 0.1), (0, 0, 1.6), 0.05, CHROME, seg=6)
    pr.cyl((0, 0, 3.6), (0, 0, 4.85), 0.55, SK, r2=0.62, seg=10, smooth=True)  # chest
    pr.cyl((0, 0, 2.8), (0, 0, 3.6), 0.48, SK, r2=0.55, seg=10, smooth=True)  # waist
    pr.cyl((0, 0, 4.85), (0, 0, 5.2), 0.18, SK, seg=8)  # neck
    pr.chunk((0, 0, 5.55), (0.6, 0.7, 0.8), SK, seed=3, rough=0.02, subdiv=2)  # head (smooth ovoid)
    for s in (-1, 1):
        pr.cyl((s * 0.62, 0, 4.7), (s * 0.85, 0.1, 3.3), 0.15, SK, r2=0.12, seg=8, smooth=True)
        pr.cyl((s * 0.85, 0.1, 3.3), (s * 0.85, -0.25, 2.3), 0.12, SK, r2=0.1, seg=8, smooth=True)
        pr.cyl((s * 0.25, 0, 2.9), (s * 0.3, 0, 1.6), 0.22, SK, r2=0.17, seg=8, smooth=True)
        pr.cyl((s * 0.3, 0, 1.6), (s * 0.3, 0.05, 0.25), 0.16, SK, r2=0.12, seg=8, smooth=True)
        pr.box((s * 0.3, -0.15, 0.15), (0.3, 0.6, 0.2), SK)
    if dressed:
        col = r.choice(CLOTH)
        F.cyl((0, 0, 3.0), (0, 0, 4.95), 0.6, col, r2=0.66, seg=10, smooth=True)
        F.cyl((0, 0, 2.75), (0, 0, 3.05), 0.56, mul(col, 0.8), seg=10)
        F.cyl((0, 0, 1.9), (0, 0, 2.8), 0.52, r.choice(CLOTH), r2=0.55, seg=10, smooth=True)
    if fallen:
        P.transform(Matrix.Translation((0, 0, 0.35)) @ Matrix.Rotation(R(88), 4, "X") @ Matrix.Rotation(R(r.uniform(-20, 20)), 4, "Z"))
    return P


def display_table(name, seed, palette=CLOTH):
    P = Prop(name)
    r = rnd(seed)
    W, F = P("wood"), P("fabric")
    W.box((0, 0, 2.75), (6.0, 3.0, 0.2), LAM_W)
    W.box((0, 0, 1.3), (5.6, 2.6, 2.6), mul(LAM_W, 0.9))
    for k in range(6):
        x, y = -2.3 + (k % 3) * 2.3, -0.7 + (k // 3) * 1.4
        h = r.uniform(0.3, 0.9)
        col = r.choice(palette)
        for j in range(int(h / 0.15)):
            F.box((x + r.uniform(-0.05, 0.05), y + r.uniform(-0.05, 0.05), 2.93 + j * 0.15), (1.6, 1.1, 0.14), mul(col, 1 + r.uniform(-0.05, 0.05)), rot=(0, 0, r.uniform(-0.06, 0.06)))
    return P


def tv_wall(name, seed):
    """electronics wall unit, 8 long x 7 tall, TVs on brackets, a low cabinet; some screens cracked"""
    P = Prop(name)
    r = rnd(seed)
    pa, pr, me = P("paint"), P("plastic"), P("metal")
    pa.box((0, 0.75, 3.5), (8.0, 0.2, 7.0), mul(BLACK, 2.6))
    pa.box((0, 0.0, 0.8), (8.0, 1.6, 1.6), mul(BLACK, 2.2))
    for (x, z, w, h) in ((-2.0, 3.0, 3.4, 2.0), (2.0, 3.0, 3.4, 2.0), (-2.4, 5.4, 2.6, 1.6), (0.6, 5.5, 2.0, 1.2), (3.0, 5.4, 1.6, 1.0)):
        if r.random() < 0.12:
            continue
        pr.box((x, 0.45, z), (w, 0.14, h), BLACK)
        cracked = r.random() < 0.35
        pr.box((x, 0.37, z), (w - 0.12, 0.02, h - 0.12), (0.035, 0.04, 0.045, 1) if not cracked else (0.08, 0.09, 0.1, 1))
        if cracked:
            cx, cz = x + r.uniform(-w / 4, w / 4), z + r.uniform(-h / 4, h / 4)
            for k in range(6):
                a = r.uniform(0, 6.28)
                L = r.uniform(0.3, min(w, h) * 0.6)
                pr.box((cx + math.cos(a) * L / 2, 0.355, cz + math.sin(a) * L / 2), (L, 0.01, 0.025), (0.5, 0.52, 0.55, 1), rot=(0, a, 0))
        me.box((x, 0.6, z), (0.6, 0.2, 0.4), STEEL_D)
    # boxed stock on the cabinet
    for k in range(3):
        pr.box((-3.0 + k * 2.6, -0.1, 1.6 + 0.6), (1.8, 0.5, 1.2), mul(PACK[k * 3], 0.8))
    return P


def tech_table(name, seed):
    """electronics display table with laptops, tablets on stands and phones on security posts"""
    P = Prop(name)
    r = rnd(seed)
    W, pr, me = P("wood"), P("plastic"), P("metal")
    W.box((0, 0, 2.9), (6.0, 3.0, 0.2), LAM_W)
    W.box((0, 0, 1.4), (5.4, 2.4, 2.8), mul(LAM_W, 0.88))
    for k in range(3):
        x = -2.0 + k * 2.0
        if r.random() < 0.25:
            me.cyl((x, -0.4, 3.0), (x, -0.4, 3.1), 0.06, STEEL_D, seg=6)  # stolen: only the post is left
            continue
        pr.box((x, -0.35, 3.04), (1.3, 0.9, 0.06), mul(BLACK, 2.2))
        pr.box((x, 0.08, 3.5), (1.3, 0.06, 0.88), mul(BLACK, 2.2), rot=(R(-12), 0, 0))
        pr.box((x, 0.05, 3.5), (1.18, 0.02, 0.76), (0.04, 0.045, 0.05, 1), rot=(R(-12), 0, 0))
    for k in range(4):
        x = -2.4 + k * 1.6
        me.cyl((x, 1.0, 3.0), (x, 1.0, 3.35), 0.05, STEEL_D, seg=6)
        if r.random() < 0.6:
            pr.box((x, 1.0, 3.6), (0.4, 0.06, 0.75), mul(BLACK, 1.6), rot=(R(-20), 0, 0))
    return P


def food_table(name, seed, mess=False):
    """food-court table (3 x 3 top on a pedestal) with four moulded chairs"""
    P = Prop(name)
    r = rnd(seed)
    W, me, pr = P("wood"), P("metal"), P("plastic")
    W.box((0, 0, 2.5), (3.0, 3.0, 0.12), LAM_W)
    me.cyl((0, 0, 0.0), (0, 0, 0.1), 0.9, STEEL_D, seg=10)
    me.cyl((0, 0, 0.1), (0, 0, 2.45), 0.12, STEEL_D, seg=8)
    chair_col = hexc("C8642E")
    for k in range(4):
        a = k * math.pi / 2
        tipped = mess and r.random() < 0.5
        dist = 2.2 + (r.uniform(0.2, 1.4) if mess else 0)
        yaw = a + (r.uniform(-0.5, 0.5) if mess else 0)
        bf_p, bf_m = set(pr.bm.verts), set(me.bm.verts)
        # chair in local frame (seat centre at origin, back toward +Y)
        pr.box((0, 0, 1.55), (1.5, 1.4, 0.12), chair_col)
        pr.box((0, 0.72, 2.45), (1.5, 0.12, 1.6), chair_col, rot=(R(-8), 0, 0))
        for (x, y) in ((-0.6, -0.55), (0.6, -0.55), (-0.6, 0.55), (0.6, 0.55)):
            me.cyl((x, y, 0), (x, y, 1.5), 0.05, STEEL_D, seg=5)
        m = Matrix.Translation((math.cos(a) * dist, math.sin(a) * dist, 0)) @ Matrix.Rotation(yaw - math.pi / 2, 4, "Z")
        if tipped:
            m = m @ Matrix.Translation((0, 0.8, 0.0)) @ Matrix.Rotation(R(-80), 4, "X") @ Matrix.Translation((0, -0.8, 0))
        bmesh.ops.transform(pr.bm, matrix=m, verts=[v for v in pr.bm.verts if v not in bf_p])
        bmesh.ops.transform(me.bm, matrix=m, verts=[v for v in me.bm.verts if v not in bf_m])
    if mess:
        pr.box((0.4, -0.3, 2.62), (1.4, 1.0, 0.08), hexc("B8352E"), rot=(0, 0, 0.3))  # tray
        pr.cyl((0.2, -0.2, 2.66), (0.2, -0.2, 3.2), 0.18, WHITE, r2=0.22, seg=8)
        pr.cyl((-0.8, 0.6, 2.56), (-0.8, 0.6, 2.62), 0.4, WHITE, seg=10)
        pr.box((-1.6, -2.4, 0.08), (1.0, 0.7, 0.12), hexc("B8352E"), rot=(0, 0, 1.0))
    return P


def food_counter(name, seed):
    """food-court counter 12 long: tiled front, steel top, equipment behind (fryers, griddle, drinks), menu
    board on top (8.2..10.2)"""
    P = Prop(name)
    r = rnd(seed)
    T, me, pr = P("tile"), P("metal"), P("plastic")
    L = 12.0
    T.box((0, 0, 1.75), (L, 0.4, 3.5), mix(WHITE, hexc("C8B080"), r.uniform(0, 0.3)))
    me.box((0, 0.6, 3.6), (L, 1.6, 0.15), STEEL)
    me.box((0, 0.6, 1.75), (L - 0.2, 1.2, 3.5), mul(STEEL, 0.8))
    me.box((0, 3.0, 1.7), (L, 1.8, 3.4), STEEL)  # back line: fryers, griddle
    for k in range(3):
        me.box((-4.0 + k * 1.4, 3.0, 3.45), (1.1, 1.4, 0.15), STEEL_D)
        me.box((-4.0 + k * 1.4, 3.0, 3.6), (0.9, 1.0, 0.05), (0.18, 0.15, 0.1, 1))  # dried oil
    me.box((1.5, 3.0, 3.48), (3.0, 1.5, 0.12), mul(STEEL_D, 0.8))
    pr.box((4.6, 3.1, 4.4), (1.8, 1.4, 2.0), mul(WHITE, 0.85))  # drinks machine
    for k in range(4):
        pr.box((4.0 + k * 0.4, 2.4, 4.0), (0.2, 0.2, 0.4), PACK[k])
    me.box((0, 3.9, 6.0), (L, 0.2, 4.6), mul(STEEL, 0.9))  # back splash
    # menu board lightbox on posts
    pr.box((0, 2.0, 9.2), (L - 1.0, 0.4, 2.0), mul(BLACK, 1.4))
    for k in range(3):
        pr.box((-3.6 + k * 3.6, 1.78, 9.2), (3.2, 0.02, 1.7), mix(r.choice(PACK), WHITE, 0.4))
    for x in (-L / 2 + 1.0, L / 2 - 1.0):
        me.cyl((x, 2.0, 3.7), (x, 2.0, 8.2), 0.08, STEEL_D, seg=6)
    # register on the counter, cups, a napkin stack
    pr.box((-3.5, 0.5, 3.95), (0.9, 0.7, 0.55), mul(BLACK, 1.5))
    for k in range(5):
        pr.cyl((2.0 + k * 0.4, 0.4, 3.68), (2.0 + k * 0.4, 0.4, 4.1), 0.14, WHITE, r2=0.17, seg=7)
    return P


def cinema_row(name, seed, torn=False, n=4):
    """a row of n rocker seats along X (1.9 pitch), facing -Y"""
    P = Prop(name)
    r = rnd(seed)
    F, pr, me = P("fabric"), P("plastic"), P("metal")
    pitch = 1.9
    x0 = -(n - 1) * pitch / 2
    for k in range(n + 1):  # armrests / standards
        x = x0 + (k - 0.5) * pitch
        pr.box((x, 0.1, 1.4), (0.22, 2.4, 2.8), mul(BLACK, 1.8))
        pr.box((x, -0.2, 2.25), (0.3, 1.8, 0.14), mul(BLACK, 2.2))
        if k < n:
            pr.cyl((x + 0.05, -0.85, 2.32), (x + 0.05, -0.85, 2.5), 0.12, mul(BLACK, 2.5), seg=8)  # cup holder
    for k in range(n):
        x = x0 + k * pitch
        col = FAB_RED if not (torn and r.random() < 0.3) else mix(FAB_RED, hexc("4A3A30"), 0.6)
        folded = torn and r.random() < 0.25
        if folded:  # broken seat hanging down
            F.box((x, -0.3, 1.0), (1.6, 0.4, 1.4), mul(col, 0.9), rot=(R(15), 0, 0))
        else:
            F.box((x, -0.35, 1.45), (1.6, 1.5, 0.45), col)
        F.box((x, 0.75, 2.6), (1.6, 0.45, 2.7), col, rot=(R(-10), 0, 0))
        if torn and r.random() < 0.5:
            F.box((x + r.uniform(-0.4, 0.4), 0.5, 3.0), (0.5, 0.05, 0.6), hexc("C8B88A"), rot=(R(-10), 0, r.uniform(-0.5, 0.5)))  # stuffing
    me.box((0, 1.1, 0.06), (n * pitch, 0.6, 0.12), STEEL_D)
    return P


def ticket_booth(name, seed):
    """cinema box office 12 x 5 x 9: counter, glass screen with speaking hole, back wall, header"""
    P = Prop(name)
    r = rnd(seed)
    W, G, me, pr = P("wood"), P("glass"), P("metal"), P("plastic")
    L, D = 12.0, 5.0
    W.box((0, -D / 2 + 0.6, 1.8), (L, 1.2, 3.6), LAM_D)
    W.box((0, -D / 2 + 0.6, 3.68), (L + 0.2, 1.5, 0.16), mul(LAM_D, 1.2))
    W.box((-L / 2 + 0.3, 0, 4.5), (0.6, D, 9.0), LAM_D)
    W.box((L / 2 - 0.3, 0, 4.5), (0.6, D, 9.0), LAM_D)
    W.box((0, D / 2 - 0.2, 4.5), (L, 0.4, 9.0), mul(LAM_D, 0.85))
    me.box((0, -D / 2 + 0.25, 8.6), (L, 0.5, 0.8), mul(BLACK, 2.0))
    for k in range(3):
        x0 = -L / 2 + 0.6 + k * (L - 1.2) / 3
        x1 = x0 + (L - 1.2) / 3
        if k == 1:
            broken_pane(G, x0 + 0.1, x1 - 0.1, 3.8, 8.2, GLASS, r, y=-D / 2 + 0.4)
        else:
            G.box(((x0 + x1) / 2, -D / 2 + 0.4, 6.0), (x1 - x0 - 0.2, 0.06, 4.4), GLASS)
        me.box((x1, -D / 2 + 0.4, 6.0), (0.12, 0.14, 4.4), STEEL)
    pr.box((0, -D / 2 - 0.05, 9.8), (L - 2, 0.2, 1.4), hexc("2A2A30"))  # header panel
    for k in range(3):
        pr.box((-4 + k * 4, 0.2, 3.9), (0.8, 0.6, 0.45), mul(BLACK, 1.6))  # ticket printers
    scatter_shards(G, r, 0, -D / 2 - 1.0, 1.4, 18, GLASS)
    return P


def bench(name, seed):
    P = Prop(name)
    r = rnd(seed)
    me, W = P("metal"), P("wood")
    for x in (-2.4, 2.4):
        me.box((x, 0, 0.75), (0.2, 1.8, 1.5), STEEL_D)
        me.box((x, 0.7, 2.0), (0.2, 0.25, 1.6), STEEL_D, rot=(R(-12), 0, 0))
    for k in range(4):
        W.box((0, -0.65 + k * 0.42, 1.55), (6.0, 0.34, 0.12), mul(LAM_L, 1 - k * 0.02))
    for k in range(2):
        W.box((0, 0.82 + k * 0.08, 2.1 + k * 0.5), (6.0, 0.12, 0.34), LAM_L, rot=(R(-12), 0, 0))
    return P


def planter(name, seed):
    P = Prop(name)
    r = rnd(seed)
    C, S, W, PL = P("concrete"), P("soil"), P("wood"), P("plant")
    C.box((0, 0, 1.3), (6.0, 6.0, 2.6), CONC, bevel=0.06)
    S.box((0, 0, 2.45), (5.2, 5.2, 0.2), hexc("3E3226"))
    for k in range(5):  # dead shrub stems
        a = r.uniform(0, 6.28)
        p0 = Vector((r.uniform(-1.6, 1.6), r.uniform(-1.6, 1.6), 2.55))
        p1 = p0 + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, r.uniform(1.4, 2.6)))
        p2 = p1 + Vector((math.cos(a + 0.8) * 0.6, math.sin(a + 0.8) * 0.6, r.uniform(0.4, 1.0)))
        W.tube([p0, p1, p2], 0.06, hexc("4A3A2A"), seg=4)
    for k in range(9):
        PL.chunk((r.uniform(-2.2, 2.2), r.uniform(-2.2, 2.2), 2.65), (r.uniform(0.6, 1.2), r.uniform(0.5, 1.0), 0.3), mix(hexc("6E5A30"), hexc("4E5A2E"), r.random()),
                 seed=r.randint(0, 99999), rough=0.45)
    PL.chunk((3.2, -1.0, 0.1), (0.8, 0.6, 0.15), hexc("6E5A30"), seed=7, rough=0.5)  # spilled leaves
    return P


def litter_bin(name, seed):
    P = Prop(name)
    me, pr = P("metal"), P("plastic")
    me.cyl((0, 0, 0), (0, 0, 2.8), 0.8, (0.3, 0.33, 0.32, 1), seg=12)
    me.cyl((0, 0, 2.8), (0, 0, 3.1), 0.85, mul(STEEL_D, 1.2), seg=12)
    pr.cyl((0, 0, 2.75), (0, 0, 2.85), 0.72, (0.12, 0.12, 0.12, 1), seg=10)
    return P


def vending(name, seed, broken=False):
    P = Prop(name)
    r = rnd(seed)
    pa, G, pr, me = P("paint"), P("glass"), P("plastic"), P("metal")
    W_, H_, D_ = 3.6, 6.4, 3.0
    pa.box((0, 0, H_ / 2), (W_, D_, H_), hexc("8E2A2A"))
    me.box((-0.35, -D_ / 2 + 0.25, 3.6), (2.6, 0.5, 4.8), mul(BLACK, 1.3))
    for z in (1.6, 2.6, 3.6, 4.6, 5.6):
        me.box((-0.35, -D_ / 2 + 0.6, z), (2.5, 1.0, 0.04), STEEL)
        products(pr, r, -1.55, 0.85, -D_ / 2 + 0.3, -D_ / 2 + 1.0, z + 0.03, 0.8, density=0.55 if broken else 0.85, kinds=("can", "bottle", "box"))
    if broken:
        broken_pane(G, -1.6, 0.9, 1.3, 5.9, GLASS, r, y=-D_ / 2 - 0.02)
        scatter_shards(G, r, -0.4, -D_ / 2 - 0.9, 0.9, 16, GLASS)
    else:
        G.box((-0.35, -D_ / 2 - 0.02, 3.6), (2.5, 0.05, 4.6), GLASS)
    pr.box((1.35, -D_ / 2 - 0.02, 4.0), (0.6, 0.06, 1.6), mul(BLACK, 1.6))  # keypad
    pr.box((-0.35, -D_ / 2 - 0.05, 0.75), (2.4, 0.1, 0.7), mul(BLACK, 1.3))  # flap
    return P


def atm(name, seed):
    P = Prop(name)
    me, pr = P("metal"), P("plastic")
    me.box((0, 0, 2.8), (2.6, 2.2, 5.6), mul(STEEL, 0.75))
    me.box((0, -1.05, 3.6), (2.2, 0.3, 1.8), mul(STEEL, 0.6), rot=(R(15), 0, 0))
    pr.box((0, -1.22, 3.8), (1.2, 0.04, 0.9), (0.04, 0.05, 0.05, 1), rot=(R(15), 0, 0))
    pr.box((0, -1.25, 2.9), (1.0, 0.4, 0.1), mul(BLACK, 1.6))
    pr.box((0, -1.13, 2.35), (1.4, 0.06, 0.18), mul(BLACK, 1.2))
    pr.box((0, -0.9, 5.4), (2.4, 0.4, 0.4), hexc("2E5E9E"))
    return P


def arcade(name, seed):
    P = Prop(name)
    r = rnd(seed)
    W, pr = P("wood"), P("plastic")
    col = r.choice((hexc("2A2A3A"), hexc("3A1E2E"), hexc("1E2E3A")))
    W.box((0, 0.2, 3.25), (3.0, 3.0, 6.5), col)
    W.box((0, -1.25, 2.9), (3.0, 0.5, 0.9), mul(col, 1.2))
    pr.box((0, -1.5, 3.4), (2.8, 0.8, 0.12), mul(BLACK, 1.5), rot=(R(-15), 0, 0))
    for k in range(6):
        pr.cyl((-0.9 + (k % 3) * 0.35, -1.55 - (k // 3) * 0.25, 3.45), (-0.9 + (k % 3) * 0.35, -1.55 - (k // 3) * 0.25, 3.55), 0.09,
               (PACK[0], PACK[1], PACK[2], PACK[3], PACK[9], PACK[11])[k], seg=6)
    pr.cyl((0.8, -1.55, 3.45), (0.8, -1.55, 3.9), 0.05, BLACK, seg=5)
    pr.box((0, -1.2, 4.9), (2.4, 0.08, 2.0), (0.04, 0.045, 0.05, 1), rot=(R(-12), 0, 0))
    pr.box((0, -0.9, 6.2), (3.0, 0.6, 0.8), mix(r.choice(PACK), WHITE, 0.3))  # marquee
    return P


def treadmill(name, seed):
    P = Prop(name)
    pr, rb, me = P("plastic"), P("rubber"), P("metal")
    pr.box((0, 0.4, 0.4), (2.6, 5.6, 0.8), mul(BLACK, 2.2))
    rb.box((0, 0.6, 0.82), (1.8, 4.8, 0.06), RUBBER)
    for s in (-1, 1):
        me.tube([(s * 1.2, -1.8, 0.8), (s * 1.2, -2.2, 4.0), (s * 1.0, -1.6, 4.2)], 0.09, STEEL, seg=6)
    pr.box((0, -2.15, 4.5), (2.2, 0.8, 0.9), mul(BLACK, 2.0), rot=(R(-25), 0, 0))
    return P


def weight_rack(name, seed):
    P = Prop(name)
    r = rnd(seed)
    me, rb = P("metal"), P("rubber")
    for x in (-2.8, 2.8):
        me.box((x, 0, 1.4), (0.2, 2.2, 2.8), STEEL_D)
    for z, y in ((1.2, -0.5), (2.3, 0.4)):
        me.box((0, y, z), (5.8, 0.9, 0.1), STEEL_D, rot=(R(-12), 0, 0))
        for k in range(6):
            if r.random() < 0.2:
                continue
            x = -2.2 + k * 0.9
            s = 0.16 + k * 0.03
            rb.cyl((x - 0.32, y, z + 0.25), (x - 0.18, y, z + 0.25), s, RUBBER, seg=8)
            rb.cyl((x + 0.18, y, z + 0.25), (x + 0.32, y, z + 0.25), s, RUBBER, seg=8)
            me.cyl((x - 0.18, y, z + 0.25), (x + 0.18, y, z + 0.25), 0.05, STEEL, seg=6)
    rb.cyl((1.5, -1.8, 0.2), (1.5, -1.5, 0.2), 0.22, RUBBER, seg=8)  # dumbbell head on the floor
    return P


def sofa(name, seed):
    P = Prop(name)
    r = rnd(seed)
    F, W = P("fabric"), P("wood")
    col = r.choice((hexc("5A5E66"), hexc("6E5A48"), hexc("3E4A3E")))
    F.box((0, 0, 1.25), (7.0, 3.0, 1.0), col)
    F.box((0, 1.15, 2.4), (7.0, 0.7, 2.2), mul(col, 0.95))
    for s in (-1, 1):
        F.box((s * 3.25, 0, 1.9), (0.5, 3.0, 1.6), mul(col, 0.92))
    for k in range(3):
        F.box((-2.2 + k * 2.2, -0.15, 1.9), (2.1, 2.5, 0.35), mul(col, 1.05 - k * 0.03), rot=(R(r.uniform(-3, 3)), 0, 0))
    for (x, y) in ((-3.2, -1.3), (3.2, -1.3), (-3.2, 1.3), (3.2, 1.3)):
        W.box((x, y, 0.37), (0.25, 0.25, 0.75), LAM_D)
    F.box((1.0, -0.6, 2.25), (1.2, 0.4, 1.0), r.choice(CLOTH), rot=(R(-30), 0, R(20)))  # cushion
    return P


def bed(name, seed):
    P = Prop(name)
    r = rnd(seed)
    F, W = P("fabric"), P("wood")
    W.box((0, 0, 0.8), (5.4, 7.2, 1.0), LAM_D)
    W.box((0, 3.6, 2.2), (5.6, 0.4, 3.6), mul(LAM_D, 1.1))
    F.box((0, -0.2, 1.65), (5.2, 6.8, 0.7), (0.82, 0.8, 0.76, 1))
    F.box((0, -0.8, 2.05), (5.3, 4.6, 0.12), r.choice(CLOTH), rot=(R(1), 0, R(r.uniform(-3, 3))))
    for s in (-1, 1):
        F.box((s * 1.3, 2.9, 2.2), (2.2, 1.1, 0.45), (0.9, 0.89, 0.86, 1))
    return P


def jewel_case(name, seed, smashed=True):
    """jeweller's display counter: wood body, velvet bed, glass top (smashed)"""
    P = Prop(name)
    r = rnd(seed)
    W, G, F, me = P("wood"), P("glass"), P("fabric"), P("chrome")
    L, D = 6.0, 2.4
    W.box((0, 0, 1.4), (L, D, 2.8), LAM_D)
    F.box((0, 0, 2.86), (L - 0.3, D - 0.3, 0.1), hexc("2A2E4A"))
    for k in range(6):
        if r.random() < 0.6:
            me.cyl((-2.2 + k * 0.9, -0.2, 2.9), (-2.2 + k * 0.9, -0.2, 3.3), 0.08, CHROME, seg=6)
    for x in (-L / 2 + 0.05, L / 2 - 0.05):
        me.box((x, 0, 3.5), (0.08, D, 1.4), CHROME)
    me.box((0, -D / 2 + 0.04, 4.2), (L, 0.08, 0.08), CHROME)
    me.box((0, D / 2 - 0.04, 4.2), (L, 0.08, 0.08), CHROME)
    if smashed:
        broken_pane(G, -L / 2 + 0.1, L / 2 - 0.1, 2.95, 4.15, GLASS, r, y=-D / 2 + 0.02)
        scatter_shards(G, r, 0, 0, 1.6, 30, GLASS, z=2.93)
        scatter_shards(G, r, 0.4, -D / 2 - 1.0, 1.2, 18, GLASS)
    else:
        G.box((0, -D / 2 + 0.02, 3.55), (L - 0.2, 0.06, 1.2), GLASS)
        G.box((0, 0, 4.18), (L - 0.2, D - 0.1, 0.06), GLASS)
    return P


def ball_pit(name, seed):
    """soft-play ball pit 12 x 12: padded walls and a lumpy bed of coloured balls (one surface, cheap)"""
    P = Prop(name)
    r = rnd(seed)
    F, pr = P("fabric"), P("plastic")
    S = 12.0
    for (x, y, sx, sy) in ((0, -S / 2 + 0.4, S, 0.8), (0, S / 2 - 0.4, S, 0.8), (-S / 2 + 0.4, 0, 0.8, S - 1.6), (S / 2 - 0.4, 0, 0.8, S - 1.6)):
        F.box((x, y, 1.3), (sx, sy, 2.6), hexc("2E6EAE") if sx > sy else hexc("D9A82E"))
        F.box((x, y, 2.75), (sx, sy, 0.3), hexc("C83A3A"))
    balls = [hexc(h) for h in ("D83A3A", "3A6ED8", "E8D24A", "3AAE5A", "E87A2E", "8E4AC8")]

    def disp(u, v):
        return 0.18 * math.sin(u * 37.0) * math.sin(v * 41.0) + 0.1 * math.sin(u * 13 + v * 7)
    before = set(pr.bm.faces)
    pr.sheet((0, 0, 1.6), (S - 1.6, S - 1.6), (1, 1, 1, 1), nx=28, ny=28, disp=disp)
    for f in pr.bm.faces:
        if f not in before:
            col = mix(r.choice(balls), (0.7, 0.7, 0.7, 1), 0.1)
            for l in f.loops:
                l[pr.col] = col
    for k in range(14):  # stray balls outside
        a, d = r.uniform(0, 6.28), r.uniform(7, 9)
        pr.chunk((math.cos(a) * d, math.sin(a) * d, 0.3), (0.6, 0.6, 0.6), r.choice(balls), seed=k, rough=0.02, subdiv=1)
    return P


PROPS = {
    "Gondola": lambda: gondola("Gondola", 101, "full"),
    "GondolaSparse": lambda: gondola("GondolaSparse", 102, "sparse"),
    "GondolaToppled": lambda: gondola("GondolaToppled", 103, "toppled"),
    "WallShelf": lambda: wall_shelf("WallShelf", 111, "stocked"),
    "WallShelfSparse": lambda: wall_shelf("WallShelfSparse", 112, "sparse"),
    "WallShelfMeds": lambda: wall_shelf("WallShelfMeds", 113, "stocked", palette=MEDS, kinds=("box", "box", "box", "bottle", "jar")),
    "WallShelfBooks": lambda: wall_shelf("WallShelfBooks", 114, "stocked", palette=BOOKS, kinds=("box",)),
    "WallShelfTools": lambda: wall_shelf("WallShelfTools", 115, "sparse", palette=[hexc(h) for h in ("C8642E", "3E5E8E", "8E8E8A", "D9A82E", "2E2E2E", "6E3E2E")], kinds=("box", "box", "jar", "can")),
    "Fridge": lambda: fridge("Fridge", 121, "dead"),
    "FridgeBroken": lambda: fridge("FridgeBroken", 122, "broken"),
    "Checkout": lambda: checkout("Checkout", 131),
    "Trolley": lambda: trolley("Trolley", 141),
    "TrolleyTipped": lambda: trolley("TrolleyTipped", 142, tipped=True),
    "TrolleyRow": lambda: trolley("TrolleyRow", 143, count=5),
    "Kiosk": lambda: kiosk("Kiosk", 151),
    "KioskBurnt": lambda: kiosk("KioskBurnt", 152, burnt=True),
    "ClothesRack": lambda: clothes_rack("ClothesRack", 161),
    "ClothesRackFallen": lambda: clothes_rack("ClothesRackFallen", 162, fallen=True),
    "Mannequin": lambda: mannequin("Mannequin", 171),
    "MannequinFallen": lambda: mannequin("MannequinFallen", 172, fallen=True),
    "DisplayTable": lambda: display_table("DisplayTable", 181),
    "TVWall": lambda: tv_wall("TVWall", 191),
    "TechTable": lambda: tech_table("TechTable", 192),
    "FoodTable": lambda: food_table("FoodTable", 201),
    "FoodTableMess": lambda: food_table("FoodTableMess", 202, mess=True),
    "FoodCounter": lambda: food_counter("FoodCounter", 211),
    "CinemaRow": lambda: cinema_row("CinemaRow", 221),
    "CinemaRowTorn": lambda: cinema_row("CinemaRowTorn", 222, torn=True),
    "TicketBooth": lambda: ticket_booth("TicketBooth", 231),
    "Bench": lambda: bench("Bench", 241),
    "Planter": lambda: planter("Planter", 251),
    "Bin": lambda: litter_bin("Bin", 261),
    "Vending": lambda: vending("Vending", 271),
    "VendingBroken": lambda: vending("VendingBroken", 272, broken=True),
    "ATM": lambda: atm("ATM", 281),
    "Arcade": lambda: arcade("Arcade", 291),
    "Treadmill": lambda: treadmill("Treadmill", 301),
    "WeightRack": lambda: weight_rack("WeightRack", 302),
    "Sofa": lambda: sofa("Sofa", 311),
    "Bed": lambda: bed("Bed", 312),
    "JewelCase": lambda: jewel_case("JewelCase", 321),
    "BallPit": lambda: ball_pit("BallPit", 331),
}
BAKE = {
    "GondolaToppled": dict(ao_dist=1.8),
    "BallPit": dict(ao_dist=1.6),
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

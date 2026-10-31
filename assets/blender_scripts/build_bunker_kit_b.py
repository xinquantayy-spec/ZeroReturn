"""Zero Return - Relay 7 bunker kit, batch B: furnishings and stations (the lobby, 2026-10-29). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_bunker_kit_b.py").read(), g); g["build"](names or None)
   then g["export"]() -> assets/exports/ZR_BunkerKitB.fbx (+ .blend, .meta.json, .props.json)
Units are studs. Origin bottom-centre, front toward Blender -Y. Wall-mounted props have their back at +Y. Boards
(departure board, roster, task board, map boards, booth displays) are plain surfaces: the game writes on them.
All geometry is original and procedural.
"""
import math, os, sys, random
import bmesh
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
import importlib, zr_lib, zr_kit
importlib.reload(zr_lib)
importlib.reload(zr_kit)
from zr_lib import hexc, grey, batch_scene, vnoise
from zr_kit import Prop, mix, shade, rnd, chunks, kit_export, contact_sheet, turntable
from mathutils import Vector, Matrix
import bpy

R = math.radians
SCENE = "ZR_BunkerKit"
BATCH = "ZR_BunkerKitB"

OLIVE = hexc("5B5F45")
OLIVE_D = hexc("464A36")
OLIVE_L = hexc("6E7354")
STEEL = (0.5, 0.51, 0.52, 1)
STEEL_D = (0.25, 0.26, 0.27, 1)
RUST = hexc("7A4B32")
YELLOW = hexc("C9A13C")
BLACK = (0.07, 0.07, 0.075, 1)
WHITE = (0.84, 0.84, 0.8, 1)
PAPER = hexc("D8D2BC")
PAPER_Y = hexc("D9C98A")
RED = hexc("8E2F24")
GREEN = hexc("3F6B45")
BLUE = hexc("3A5470")
WOOD = hexc("7A6448")
WOOD_D = hexc("5C4A36")
CORK = hexc("9C7A52")
FAB_G = hexc("4F5440")
FAB_B = hexc("3D4148")
FAB_W = hexc("B8B4A4")
RUBBER = (0.09, 0.09, 0.09, 1)
GLASS = (0.55, 0.6, 0.6, 1)
WARM = (1.0, 0.92, 0.76, 1)
CARD = hexc("A88A5E")


def mul(c, k):
    return (min(1, c[0] * k), min(1, c[1] * k), min(1, c[2] * k), 1)


def chipped(b, chip=RUST, seed=0, amount=0.35, scale=1.6):
    def fn(p, c):
        n = vnoise(p, scale, seed)
        if n > 1 - amount:
            t = min(1.0, (n - (1 - amount)) / 0.25)
            return mix(c, chip, 0.75 * t)
        return c
    b.paint_fn(fn)


def lump(b, center, size, color, r, bevel=0.12, tilt=0.05):
    """a soft thing (mattress, pillow, bag): a bevelled box, slightly skewed"""
    b.box(center, size, color, rot=(r.uniform(-tilt, tilt), r.uniform(-tilt, tilt), r.uniform(-tilt * 2, tilt * 2)), bevel=bevel)


def merge_into(dst, src_prop, matrix):
    """move every piece of a temporary Prop into dst through a matrix (a door swung open, an object turned)"""
    for mat_key, b in src_prop.b.items():
        b.transform(matrix)
        me_tmp = bpy.data.meshes.new("_zr_tmp")
        b.bm.to_mesh(me_tmp)
        dst(mat_key).bm.from_mesh(me_tmp)
        bpy.data.meshes.remove(me_tmp)
        b.bm.free()


# ── bunk room ────────────────────────────────────────────────────────────────
def bunk_bed(name, seed, messy=False):
    """steel double bunk 7 x 3: posts, rails, spring bars, thin mattresses, a ladder; messy: blanket and a bag"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, fa = P("paint"), P("metal"), P("fabric")
    L, Wd, H = 6.8, 2.9, 6.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            pa.box((sx * (L / 2 - 0.12), sy * (Wd / 2 - 0.12), H / 2), (0.22, 0.22, H), OLIVE, bevel=0.02)
    for z in (1.4, 4.4):
        for sy in (-1, 1):
            pa.box((0, sy * (Wd / 2 - 0.12), z), (L, 0.18, 0.28), OLIVE)
        for sx in (-1, 1):
            pa.box((sx * (L / 2 - 0.12), 0, z), (0.18, Wd, 0.28), OLIVE)
        for k in range(9):
            me.box((-L / 2 + 0.5 + k * (L - 1.0) / 8, 0, z + 0.05), (0.05, Wd - 0.4, 0.05), STEEL_D)
        lump(fa, (0, 0, z + 0.42), (L - 0.4, Wd - 0.35, 0.55), mix(FAB_G, FAB_W, 0.15 * r.random()), r, 0.16)
        lump(fa, (-L / 2 + 0.9, 0, z + 0.85), (1.1, 1.8, 0.35), FAB_W, r, 0.14)  # pillow
        if not messy:
            lump(fa, (L / 2 - 1.3, 0, z + 0.8), (1.6, Wd - 0.6, 0.3), FAB_B, r, 0.08)  # folded blanket
    for k in range(4):  # ladder
        pa.box((L / 2 + 0.05, -0.6 + 0, 1.8 + k * 0.85), (0.1, 1.0, 0.1), OLIVE_D)
    for s in (-1, 1):
        pa.box((L / 2 + 0.05, s * 0.55 - 0.05, 3.3), (0.1, 0.1, 3.4), OLIVE_D)
    if messy:
        # a blanket draped over the lower bunk's edge and a duffel bag on the top bunk
        # a blanket kicked half off the lower bunk: rumpled on the mattress, the rest hanging over the front edge
        fa.sheet((0.8, -0.15, 1.98), (L - 2.2, Wd - 0.6, 0), FAB_B, nx=8, ny=4,
                 disp=lambda u, v: 0.12 * math.sin(u * 11.0 + v * 3.0) * math.sin(v * 3.1), double=True)
        fa.sheet((0.8, -Wd / 2 + 0.05, 1.45), (L - 2.4, 1.1, 0), FAB_B, nx=8, ny=2,
                 disp=lambda u, v: 0.08 * math.sin(u * 13.0), rot=(R(90), 0, 0), double=True)
        fa.cyl((0.6, 0.2, 5.15), (2.6, 0.1, 5.15), 0.42, hexc("5A5A3A"), seg=10, smooth=True)  # duffel bag
        fa.box((1.2, -Wd / 2 - 0.35, 0.18), (0.45, 1.0, 0.36), BLACK, rot=(0, 0, R(12)), bevel=0.06)  # boots
        fa.box((1.8, -Wd / 2 - 0.3, 0.18), (0.45, 1.0, 0.36), BLACK, rot=(0, 0, R(-8)), bevel=0.06)
    chipped(pa, RUST, seed, 0.3, 2.0)
    return P


def locker(name, seed, open_=False):
    """single steel locker 2 x 7 x 2: louvres, a handle and a name-card slot; open: the door swung out, a jacket inside"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, fa = P("paint"), P("metal"), P("fabric")
    W, H, D = 1.9, 7.0, 1.9
    col = mix(OLIVE, OLIVE_L, r.random() * 0.5)
    pa.box((0, 0.05, H / 2), (W, D - 0.1, H), col, bevel=0.02)
    pa.box((0, 0.0, H + 0.05), (W + 0.05, D, 0.1), mul(col, 0.9))
    me.box((0, 0.05, 0.12), (W, D - 0.1, 0.24), STEEL_D)  # plinth
    door = Prop(name + "_door_tmp")
    dp, dm = door("paint"), door("metal")
    dp.box((0, -D / 2 + 0.02, H / 2 + 0.1), (W - 0.1, 0.06, H - 0.5), mul(col, 1.06))
    for k in range(6):
        dp.box((0, -D / 2 - 0.02, H - 1.0 - k * 0.15), (W * 0.6, 0.03, 0.06), mul(col, 0.55))
        dp.box((0, -D / 2 - 0.02, 1.0 + k * 0.15), (W * 0.6, 0.03, 0.06), mul(col, 0.55))
    dm.box((W / 2 - 0.3, -D / 2 - 0.05, H / 2), (0.1, 0.08, 0.6), STEEL_D)
    dm.box((0, -D / 2 - 0.03, H - 1.9), (0.8, 0.03, 0.35), STEEL)  # name card slot
    dp.box((0, -D / 2 - 0.045, H - 1.9), (0.7, 0.01, 0.25), mix(col, (0.8, 0.78, 0.7, 1), 0.7))
    ang = R(-105) if open_ else 0
    hinge = Vector((-W / 2 + 0.05, -D / 2, 0))
    merge_into(P, door, Matrix.Translation(hinge) @ Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation(-hinge))
    if open_:
        me.box((0, 0.1, H / 2), (W - 0.2, D - 0.4, H - 0.4), mul(BLACK, 1.4))  # dark inside
        me.box((0, 0.1, H - 1.5), (W - 0.25, D - 0.5, 0.08), STEEL_D)  # shelf
        fa.box((0, 0.2, H - 3.2), (1.2, 0.5, 2.6), FAB_G, bevel=0.12)  # jacket on a hook
        fa.box((0.3, 0.1, H - 1.25), (0.8, 0.8, 0.4), hexc("4A4F3A"), bevel=0.1)  # helmet bag on the shelf
    chipped(pa, RUST, seed, 0.28, 2.2)
    return P


def mirror_sink(name, seed):
    """cracked wall mirror over a steel trough sink, tap, drain pipe, a towel on a hook, soap"""
    P = Prop(name)
    r = rnd(seed)
    me, gl, pl, fa = P("metal"), P("glass"), P("plastic"), P("fabric")
    me.box((0, 0.35, 5.6), (3.4, 0.12, 4.2), STEEL_D)  # frame
    gl.box((0, 0.26, 5.6), (3.1, 0.04, 3.9), (0.7, 0.74, 0.74, 1))
    for k in range(7):  # cracks radiating from an impact
        an = r.uniform(0, math.pi * 2)
        ln = r.uniform(0.6, 1.6)
        pl.box((0.6 + math.cos(an) * ln / 2, 0.23, 6.1 + math.sin(an) * ln / 2), (ln, 0.01, 0.03), BLACK, rot=(0, -an, 0))
    me.box((0, 0.0, 2.9), (3.2, 1.4, 0.6), STEEL)  # trough
    me.box((0, 0.0, 3.17), (2.9, 1.1, 0.08), STEEL_D)  # basin
    me.cyl((0, 0.45, 3.2), (0, 0.45, 3.8), 0.06, STEEL, seg=6)
    me.cyl((0, 0.45, 3.8), (0, 0.1, 3.8), 0.06, STEEL, seg=6)
    me.cyl((0, 0.3, 2.6), (0, 0.3, 0.0), 0.1, STEEL_D, seg=6)
    me.box((-1.4, 0.3, 1.5), (0.12, 0.6, 2.8), STEEL_D)
    me.box((1.4, 0.3, 1.5), (0.12, 0.6, 2.8), STEEL_D)
    me.cyl((1.9, 0.45, 4.2), (1.9, 0.2, 4.2), 0.05, STEEL, seg=6)  # towel hook
    fa.sheet((1.9, 0.18, 3.5), (0.8, 1.4, 0), FAB_W, nx=3, ny=4, disp=lambda u, v: 0.05 * math.sin(u * 6), rot=(R(90), 0, 0), double=True)
    pl.box((-0.9, -0.2, 3.25), (0.4, 0.25, 0.15), hexc("C8B88A"), bevel=0.04)  # soap
    return P


# ── ops room ─────────────────────────────────────────────────────────────────
def map_table(name, seed):
    """plotting table 24 x 10: heavy wood top on steel legs, four map boards (the game draws the maps), pins, a
    desk lamp, a field radio, mugs, binders, a ruler"""
    P = Prop(name)
    r = rnd(seed)
    wo, me, pl, gw, pa = P("wood"), P("metal"), P("plastic"), P("glow"), P("paint")
    L, Wd, H = 24.0, 10.0, 3.4
    wo.box((0, 0, H - 0.15), (L, Wd, 0.3), WOOD, bevel=0.05)
    wo.box((0, 0, H - 0.45), (L - 0.6, Wd - 0.6, 0.3), WOOD_D)
    for x in (-L / 2 + 0.6, 0.0, L / 2 - 0.6):
        for y in (-Wd / 2 + 0.6, Wd / 2 - 0.6):
            me.box((x, y, (H - 0.6) / 2), (0.35, 0.35, H - 0.6), STEEL_D)
    me.box((0, 0, 0.6), (L - 1.2, 0.2, 0.2), STEEL_D)
    # four map boards (pale card, raised a little) - the game puts the map art and names on them
    for i, x in enumerate((-8.6, -2.9, 2.9, 8.6)):
        pl.box((x, -0.6, H + 0.02), (5.2, 4.2, 0.04), PAPER)
        for k in range(5):  # faint grid
            pl.box((x - 2.1 + k * 1.05, -0.6, H + 0.045), (0.02, 4.0, 0.01), mul(PAPER, 0.8))
            pl.box((x, -0.6 - 1.6 + k * 0.8, H + 0.045), (5.0, 0.02, 0.01), mul(PAPER, 0.8))
        for k in range(3):  # pins
            px, py = x + r.uniform(-2.0, 2.0), -0.6 + r.uniform(-1.6, 1.6)
            pl.cyl((px, py, H + 0.04), (px, py, H + 0.3), 0.03, STEEL, seg=4)
            pl.cyl((px, py, H + 0.3), (px, py, H + 0.42), 0.09, RED if k else YELLOW, seg=6)
    # desk lamp
    me.cyl((-11.0, 3.6, H), (-11.0, 3.6, H + 0.1), 0.4, STEEL_D, seg=10)
    me.tube([(-11.0, 3.6, H + 0.1), (-10.6, 3.4, H + 1.6), (-9.8, 3.0, H + 2.0)], 0.05, STEEL_D, seg=5)
    me.cyl((-9.8, 3.0, H + 2.0), (-9.6, 2.9, H + 1.6), 0.15, OLIVE_D, r2=0.42, seg=10)
    gw.cyl((-9.65, 2.92, H + 1.72), (-9.6, 2.9, H + 1.62), 0.14, WARM, seg=8)
    # field radio
    pa.box((10.5, 3.4, H + 0.5), (1.8, 1.0, 1.0), OLIVE_D, bevel=0.04)
    for k in range(3):
        me.cyl((9.9 + k * 0.4, 2.88, H + 0.6), (9.9 + k * 0.4, 2.8, H + 0.6), 0.1, BLACK, seg=8)
    pl.box((10.9, 2.89, H + 0.6), (0.6, 0.02, 0.35), (0.25, 0.4, 0.25, 1))
    me.cyl((11.2, 3.6, H + 1.0), (11.4, 3.7, H + 3.2), 0.025, STEEL_D, seg=4)  # whip antenna
    pl.tube([(10.0, 3.9, H + 0.4), (9.4, 4.4, H + 0.05), (8.2, 4.6, H + 0.05)], 0.04, BLACK, seg=4)  # handset cord
    pl.box((8.0, 4.4, H + 0.12), (0.5, 0.25, 0.2), BLACK, bevel=0.03)
    # mugs, binders, a ruler, loose papers
    for (x, y) in ((-5.6, 3.8), (6.0, -4.0)):
        pl.cyl((x, y, H), (x, y, H + 0.42), 0.18, WHITE if x < 0 else OLIVE_L, seg=10)
    for k in range(3):
        pl.box((-3.0 + k * 0.45, 3.9, H + 0.6), (0.4, 1.2, 1.2), (BLUE, BLACK, RED)[k], rot=(0, 0, 0), bevel=0.02)
    pl.box((0.5, 3.6, H + 0.02), (3.0, 0.25, 0.03), YELLOW, rot=(0, 0, R(12)))
    for k in range(5):
        pl.box((r.uniform(-11, 11), r.uniform(3.0, 4.5), H + 0.01 + k * 0.004), (0.85, 1.1, 0.01), PAPER, rot=(0, 0, r.uniform(-0.6, 0.6)))
    return P


def departure_board(name, seed):
    """split-flap departure board 12 x 4.2: a steel case, four rows of dark flaps (the game writes on it)"""
    P = Prop(name)
    me, pl, gw = P("metal"), P("plastic"), P("glow")
    W, H = 12.0, 4.2
    me.box((0, 0.25, H / 2), (W, 0.5, H), STEEL_D, bevel=0.05)
    pl.box((0, -0.02, H / 2 - 0.2), (W - 0.6, 0.06, H - 1.0), BLACK)
    for row in range(4):
        for k in range(24):
            pl.box((-W / 2 + 0.55 + k * 0.47, -0.06, 0.6 + row * 0.72), (0.42, 0.02, 0.6), mix(BLACK, STEEL_D, 0.35))
    me.box((0, -0.03, H - 0.35), (W - 0.6, 0.04, 0.5), OLIVE_D)  # header strip
    gw.box((W / 2 - 0.6, -0.05, H - 0.35), (0.18, 0.02, 0.18), (0.95, 0.75, 0.3, 1))  # status lamp
    for s in (-1, 1):
        me.cyl((s * (W / 2 - 0.8), 0.25, H), (s * (W / 2 - 0.8), 0.25, H + 1.6), 0.05, STEEL_D, seg=6)
    return P


def whiteboard(name, seed):
    """roster whiteboard 6 x 4 in an aluminium frame with a marker tray and magnets (the game writes the roster)"""
    P = Prop(name)
    r = rnd(seed)
    pl, me = P("plastic"), P("metal")
    pl.box((0, 0.08, 2.0), (6.0, 0.12, 4.0), mul(WHITE, 1.05))
    me.box((0, 0.05, 4.02), (6.1, 0.18, 0.1), STEEL)
    me.box((0, 0.05, -0.02), (6.1, 0.18, 0.1), STEEL)
    for s in (-1, 1):
        me.box((s * 3.02, 0.05, 2.0), (0.1, 0.18, 4.1), STEEL)
    me.box((0, -0.2, 0.0), (5.0, 0.4, 0.08), STEEL)
    for k in range(2):
        pl.cyl((-1.0 + k * 0.6, -0.25, 0.08), (-0.6 + k * 0.6, -0.25, 0.08), 0.06, (BLACK, RED)[k], seg=6)
    for k in range(6):
        x, z = r.uniform(-2.7, 2.7), r.uniform(0.4, 3.7)
        pl.cyl((x, 0.01, z), (x, -0.06, z), 0.1, (RED, BLUE, YELLOW, GREEN)[k % 4], seg=8)
    return P


def cork_board(name, seed):
    """task board 8 x 4: cork in a wooden frame, pinned papers and photos (the game pins the task cards)"""
    P = Prop(name)
    r = rnd(seed)
    wo, pl, co = P("wood"), P("plastic"), P("fabric")
    co.box((0, 0.08, 2.0), (8.0, 0.12, 4.0), CORK)
    for z in (-0.05, 4.05):
        wo.box((0, 0.05, z), (8.2, 0.2, 0.12), WOOD_D)
    for s in (-1, 1):
        wo.box((s * 4.05, 0.05, 2.0), (0.12, 0.2, 4.2), WOOD_D)
    for k in range(11):
        x, z = r.uniform(-3.4, 3.4), r.uniform(0.5, 3.5)
        c = (PAPER, PAPER_Y, WHITE, hexc("A8B4B0"))[k % 4]
        pl.box((x, 0.0, z), (r.uniform(0.7, 1.1), 0.01, r.uniform(0.8, 1.2)), c, rot=(0, r.uniform(-0.15, 0.15), 0))
        pl.cyl((x, -0.01, z + 0.4), (x, -0.08, z + 0.4), 0.05, (RED, BLUE, YELLOW)[k % 3], seg=6)
    return P


def insurance_window(name, seed):
    """a service hatch in the wall: steel frame, scratched glass with a speaking hole, a counter shelf, a bell,
    a paper tray and a rubber stamp"""
    P = Prop(name)
    me, gl, pl, wo = P("metal"), P("glass"), P("plastic"), P("wood")
    W, H0, H1 = 10.0, 3.0, 7.0
    me.box((0, 0.3, H0 - 0.15), (W + 0.6, 0.6, 0.3), STEEL_D)
    me.box((0, 0.3, H1 + 0.15), (W + 0.6, 0.6, 0.3), STEEL_D)
    for x in (-W / 2, -W / 6, W / 6, W / 2):
        me.box((x, 0.3, (H0 + H1) / 2), (0.25, 0.6, H1 - H0), STEEL_D)
    gl.box((0, 0.3, (H0 + H1) / 2), (W, 0.06, H1 - H0), GLASS)
    me.cyl((0, 0.36, 4.6), (0, 0.24, 4.6), 0.35, STEEL, seg=12)  # speaking grille
    wo.box((0, -0.5, H0 - 0.05), (W + 0.6, 1.6, 0.15), WOOD_D, bevel=0.03)  # counter shelf
    me.box((0, -0.8, H0 - 0.6), (W, 0.12, 1.0), STEEL_D)
    me.cyl((-3.0, -0.6, H0 + 0.03), (-3.0, -0.6, H0 + 0.08), 0.25, STEEL_D, seg=10)  # bell
    me.cyl((-3.0, -0.6, H0 + 0.08), (-3.0, -0.6, H0 + 0.3), 0.22, YELLOW, r2=0.05, seg=10)
    pl.box((2.5, -0.5, H0 + 0.1), (1.2, 0.9, 0.18), BLACK)  # paper tray
    pl.box((2.5, -0.5, H0 + 0.2), (1.0, 0.75, 0.04), PAPER)
    pl.cyl((1.0, -0.7, H0), (1.0, -0.7, H0 + 0.35), 0.12, WOOD, seg=8)  # stamp
    pl.cyl((1.0, -0.7, H0 + 0.35), (1.0, -0.7, H0 + 0.45), 0.2, BLACK, seg=8)
    return P


# ── traders' hall ────────────────────────────────────────────────────────────
def counter(name, seed):
    """trader counter 12 x 3.6 x 3: a heavy wood top, a dented steel front, under-shelves with boxes, a cash box,
    a ledger and a lamp"""
    P = Prop(name)
    r = rnd(seed)
    wo, pa, me, pl, ca, gw = P("wood"), P("paint"), P("metal"), P("plastic"), P("cardboard"), P("glow")
    L, H, D = 12.0, 3.6, 3.0
    wo.box((0, 0, H - 0.12), (L, D, 0.24), WOOD, bevel=0.04)
    pa.sheet((0, -D / 2 + 0.05, (H - 0.24) / 2), (L, H - 0.24, 0), OLIVE_D, nx=10, ny=3,
             disp=lambda u, v: 0.05 * math.sin(u * 17 + v * 3) * math.sin(v * 3.1), rot=(R(90), 0, 0), double=True)
    for x in (-L / 2 + 0.1, L / 2 - 0.1):
        pa.box((x, 0, (H - 0.24) / 2), (0.2, D, H - 0.24), OLIVE_D)
    me.box((0, 0.3, 1.2), (L - 0.4, D - 0.8, 0.1), STEEL_D)  # under shelf (customer side is -Y)
    for k in range(6):
        ca.box((-L / 2 + 1.2 + k * 1.9, 0.4, 1.7), (1.4, 1.2, 0.9 + r.uniform(0, 0.4)), mix(CARD, mul(CARD, 0.8), r.random()), bevel=0.02)
    me.box((-3.5, 0.6, H + 0.25), (1.6, 1.0, 0.5), STEEL_D, bevel=0.03)  # cash box
    pl.box((2.5, 0.0, H + 0.06), (1.6, 1.2, 0.12), hexc("3A2C24"))  # ledger
    pl.box((2.5, 0.0, H + 0.13), (1.5, 1.1, 0.02), PAPER)
    me.cyl((5.2, 0.9, H), (5.2, 0.9, H + 1.6), 0.05, STEEL_D, seg=6)
    me.cyl((5.2, 0.9, H + 1.6), (5.0, 0.7, H + 1.3), 0.12, OLIVE_D, r2=0.35, seg=10)
    gw.cyl((5.03, 0.73, H + 1.36), (5.0, 0.7, H + 1.3), 0.1, WARM, seg=6)
    chipped(pa, RUST, seed, 0.3, 1.5)
    return P


def gun_rack(name, seed):
    """wall rack 10 x 6 for long guns: two notched rails and a bottom ledge (the game hangs real builds on it)"""
    P = Prop(name)
    wo, me = P("wood"), P("metal")
    W, H = 10.0, 6.0
    wo.box((0, 0.35, H / 2), (W, 0.2, H), WOOD_D)
    for z in (1.2, 4.2):
        wo.box((0, 0.05, z), (W - 0.4, 0.45, 0.3), WOOD)
        for k in range(6):
            wo.box((-W / 2 + 1.0 + k * 1.6, -0.18, z + 0.18), (0.3, 0.1, 0.2), WOOD_D)
    wo.box((0, -0.05, 0.25), (W - 0.4, 0.8, 0.3), WOOD)
    me.box((0, 0.2, H - 0.25), (W - 0.6, 0.1, 0.12), STEEL_D)  # chain bar
    for k in range(7):
        me.box((-W / 2 + 1.0 + k * 1.35, 0.15, H - 0.6), (0.06, 0.06, 0.6), STEEL, rot=(0, R(10 * (-1) ** k), 0))
    return P


def pegboard(name, seed):
    """pegboard 10 x 5 with hooks, a few tools and boxes of parts (the game hangs real parts on it)"""
    P = Prop(name)
    r = rnd(seed)
    wo, me, ca = P("wood"), P("metal"), P("cardboard")
    W, H = 10.0, 5.0
    wo.box((0, 0.3, H / 2), (W, 0.12, H), hexc("8A7254"))
    for k in range(9):
        for j in range(4):
            me.box((-W / 2 + 1.0 + k * 1.0, 0.18, 0.8 + j * 1.1), (0.05, 0.25, 0.05), STEEL_D)
    for k in range(4):  # spanners
        me.box((3.0 + k * 0.35, 0.16, 3.4), (0.12, 0.04, 1.0 + k * 0.15), STEEL)
    me.box((-3.5, 0.16, 3.6), (0.9, 0.06, 0.18), STEEL)  # a hacksaw blade
    me.box((-3.5, 0.16, 3.3), (0.12, 0.06, 0.5), RED)
    for k in range(3):
        ca.box((-2.0 + k * 1.3, 0.0, 0.35), (1.0, 0.6, 0.6), mix(CARD, mul(CARD, 0.8), r.random()))
    return P


def med_shelf(name, seed):
    """medicine shelving 6 x 7 x 1.6: a glass-door cabinet on top of open shelves with boxes and bottles"""
    P = Prop(name)
    r = rnd(seed)
    pa, gl, pl, ca = P("paint"), P("glass"), P("plastic"), P("cardboard")
    W, H, D = 6.0, 7.0, 1.6
    # an open-fronted case: back, sides, top and plinth
    pa.box((0, D / 2 - 0.06, H / 2), (W, 0.12, H), mul(WHITE, 0.7))
    for sx in (-1, 1):
        pa.box((sx * (W / 2 - 0.06), 0, H / 2), (0.12, D, H), mul(WHITE, 0.9))
    pa.box((0, 0, H - 0.06), (W, D, 0.12), mul(WHITE, 0.9))
    pa.box((0, 0, 0.15), (W, D, 0.3), mul(WHITE, 0.8))
    for z in (1.2, 2.6, 4.0, 5.5):
        pa.box((0, -0.1, z), (W - 0.3, D - 0.4, 0.08), mul(WHITE, 0.85))
        for k in range(int(r.uniform(4, 8))):
            x = -W / 2 + 0.5 + r.uniform(0, W - 1.0)
            c = (WHITE, BLUE, GREEN, mix(WHITE, RED, 0.3), PAPER_Y)[r.randrange(5)]
            if r.random() < 0.4:
                pl.cyl((x, -0.2, z + 0.04), (x, -0.2, z + 0.04 + r.uniform(0.4, 0.8)), 0.14, c, seg=8)
            else:
                ca.box((x, -0.2, z + 0.25), (r.uniform(0.4, 0.8), 0.6, 0.45), c)
    gl.box((-W / 4, -D / 2 + 0.05, 4.75), (W / 2 - 0.1, 0.05, 2.4), GLASS)
    gl.box((W / 4 + 0.3, -D / 2 - 0.4, 4.75), (W / 2 - 0.1, 0.05, 2.4), GLASS, rot=(0, 0, R(-40)))  # a door ajar
    chipped(pa, hexc("9A8A6A"), seed, 0.22, 2.4)
    return P


def mannequin(name, seed, rig=False):
    """display torso on a pole wearing a plate carrier (or a chest rig) for TILDA's wall"""
    P = Prop(name)
    r = rnd(seed)
    pl, me, fa = P("plastic"), P("metal"), P("fabric")
    me.cyl((0, 0, 0.0), (0, 0, 0.15), 0.9, STEEL_D, seg=10)
    me.cyl((0, 0, 0.15), (0, 0, 3.6), 0.08, STEEL_D, seg=6)
    pl.box((0, 0, 4.6), (1.8, 1.0, 2.2), mix(WHITE, PAPER, 0.4), bevel=0.25)
    pl.box((0, 0, 5.9), (0.5, 0.5, 0.4), mix(WHITE, PAPER, 0.4), bevel=0.1)
    col = FAB_G if not rig else hexc("5E5A44")
    if not rig:
        fa.box((0, -0.05, 4.7), (2.0, 1.25, 2.0), col, bevel=0.12)
        for k in range(3):
            fa.box((-0.6 + k * 0.6, -0.72, 4.3), (0.5, 0.3, 0.7), mul(col, 0.85), bevel=0.06)
        fa.box((0, -0.7, 5.15), (1.4, 0.15, 0.4), mul(col, 0.9))
        for s in (-1, 1):
            fa.box((s * 0.65, 0, 5.75), (0.35, 1.0, 0.25), mul(col, 0.95))
    else:
        fa.box((0, -0.62, 4.3), (1.9, 0.5, 1.0), col, bevel=0.08)
        for k in range(4):
            fa.box((-0.7 + k * 0.47, -0.92, 4.4), (0.4, 0.25, 0.8), mul(col, 0.85), bevel=0.05)
        for s in (-1, 1):
            fa.box((s * 0.5, -0.1, 5.2), (0.2, 1.2, 0.15), mul(col, 0.8), rot=(R(20), 0, 0))
    return P


def pigeonholes(name, seed):
    """mail pigeonholes 6 x 5: a 4 x 3 grid of wooden cells, letters and a parcel in some (the game lights the
    cells that have mail for you)"""
    P = Prop(name)
    r = rnd(seed)
    wo, pl, ca = P("wood"), P("plastic"), P("cardboard")
    W, H, D, cols, rows = 6.0, 4.2, 1.2, 4, 3
    z0 = 3.0
    wo.box((0, 0.5, z0 + H / 2), (W, 0.12, H), WOOD_D)
    for k in range(cols + 1):
        wo.box((-W / 2 + k * W / cols, 0, z0 + H / 2), (0.1, D, H), WOOD)
    for j in range(rows + 1):
        wo.box((0, 0, z0 + j * H / rows), (W, D, 0.1), WOOD)
    for k in range(cols):
        for j in range(rows):
            if r.random() < 0.45:
                x = -W / 2 + (k + 0.5) * W / cols
                z = z0 + j * H / rows + 0.12
                pl.box((x, 0.1, z + 0.02), (1.1, 0.7, 0.04), PAPER, rot=(0, 0, r.uniform(-0.2, 0.2)))
                if r.random() < 0.3:
                    ca.box((x, 0.1, z + 0.3), (0.9, 0.7, 0.5), CARD)
    wo.box((0, 0, z0 - 1.5), (W, D, 0.1), WOOD_D)  # a shelf under it
    for s in (-1, 1):
        wo.box((s * (W / 2 - 0.1), 0, z0 - 0.75), (0.1, D, 1.5), WOOD_D)
    return P


def fence_stall(name, seed):
    """the Fence's corner: crates as a table under a tarp, junk for sale (a radio, cans, a lamp, a toaster), a chair"""
    P = Prop(name)
    r = rnd(seed)
    wo, fa, me, pl, gw = P("wood"), P("fabric"), P("metal"), P("plastic"), P("glow")
    for (x, y) in ((-1.0, 0.0), (1.0, 0.0)):
        wo.box((x, y, 1.0), (2.0, 2.0, 2.0), mix(WOOD, WOOD_D, r.random()), bevel=0.04)
        for k in range(3):
            wo.box((x, y - 1.01, 0.3 + k * 0.7), (1.9, 0.04, 0.12), WOOD_D)
    fa.sheet((0, 0, 2.05), (4.4, 2.4, 0), hexc("4A5246"), nx=6, ny=4, disp=lambda u, v: 0.04 * math.sin(u * 13) - (0.0 if 0.1 < v < 0.9 else 0.5), double=True)
    pl.box((-1.2, 0.2, 2.35), (0.9, 0.5, 0.55), hexc("5A4A3A"), bevel=0.04)  # radio
    for k in range(4):
        me.cyl((0.0 + k * 0.35, -0.4, 2.1), (0.0 + k * 0.35, -0.4, 2.55), 0.13, (STEEL, RED, YELLOW, GREEN)[k], seg=8)
    me.cyl((1.4, 0.4, 2.1), (1.4, 0.4, 2.9), 0.05, STEEL_D, seg=6)
    me.cyl((1.4, 0.4, 2.9), (1.3, 0.3, 2.7), 0.1, OLIVE_D, r2=0.28, seg=8)
    gw.cyl((1.32, 0.32, 2.74), (1.3, 0.3, 2.7), 0.08, WARM, seg=6)
    me.box((0.9, 0.6, 2.35), (0.7, 0.45, 0.5), STEEL, bevel=0.05)  # a toaster
    # folding chair behind
    me.box((0.0, 2.2, 1.5), (1.2, 1.2, 0.1), STEEL_D)
    for sx in (-0.5, 0.5):
        me.box((sx, 2.2, 0.75), (0.06, 1.3, 0.06), STEEL_D, rot=(R(25), 0, 0))
        me.box((sx, 2.2, 0.75), (0.06, 1.3, 0.06), STEEL_D, rot=(R(-25), 0, 0))
    me.box((0.0, 2.75, 2.4), (1.2, 0.08, 1.0), STEEL_D)
    return P


# ── hideout wing ─────────────────────────────────────────────────────────────
def hideout_generator(name, seed):
    """small diesel generator set 6 x 3 x 3.6 on skids: engine, alternator, fuel tank, exhaust, control panel"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, pl, ru = P("paint"), P("metal"), P("plastic"), P("rubber")
    for y in (-1.2, 1.2):
        me.box((0, y, 0.15), (6.2, 0.3, 0.3), STEEL_D)
    pa.box((-0.8, 0, 1.4), (3.0, 2.2, 2.2), hexc("6E7458"), bevel=0.06)  # engine
    for k in range(5):
        pa.box((-0.8, -1.12, 1.0 + k * 0.25), (2.6, 0.04, 0.1), mul(hexc("6E7458"), 0.7))
    pa.cyl((1.6, 0, 1.4), (2.9, 0, 1.4), 0.95, hexc("8A3A2E"), seg=14, smooth=True)  # alternator
    me.box((0.0, 0.0, 0.55), (5.0, 2.4, 0.5), STEEL_D)  # base tank
    me.cyl((-1.6, 0.6, 2.5), (-1.6, 0.6, 4.2), 0.18, STEEL_D, seg=8)  # exhaust
    me.cyl((-1.6, 0.6, 4.2), (-1.6, 0.0, 4.5), 0.18, STEEL_D, seg=8)
    pa.box((2.4, -1.15, 2.6), (1.2, 0.3, 1.0), hexc("8A8E86"))  # panel
    pl.box((2.2, -1.32, 2.7), (0.5, 0.02, 0.35), (0.05, 0.07, 0.06, 1))
    pl.box((2.75, -1.32, 2.5), (0.2, 0.04, 0.2), (0.75, 0.2, 0.15, 1))
    ru.tube([(2.9, 0.5, 1.0), (3.4, 0.9, 0.12), (4.4, 1.6, 0.1)], 0.1, RUBBER, seg=6)
    chipped(pa, RUST, seed, 0.35, 1.6)
    return P


def med_cot(name, seed):
    """field hospital cot with a thin mattress and pillow, an IV stand and a trolley with a tray of supplies"""
    P = Prop(name)
    r = rnd(seed)
    me, fa, pl, gl = P("metal"), P("fabric"), P("plastic"), P("glass")
    L, Wd = 6.6, 2.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            me.cyl((sx * (L / 2 - 0.2), sy * (Wd / 2 - 0.15), 0.0), (sx * (L / 2 - 0.2), sy * (Wd / 2 - 0.15), 2.2), 0.08, STEEL, seg=6)
    for sy in (-1, 1):
        me.cyl((-L / 2, sy * (Wd / 2 - 0.15), 2.1), (L / 2, sy * (Wd / 2 - 0.15), 2.1), 0.08, STEEL, seg=6)
    lump(fa, (0, 0, 2.4), (L - 0.3, Wd - 0.3, 0.45), mix(FAB_W, FAB_G, 0.25), r, 0.14)
    lump(fa, (-L / 2 + 0.8, 0, 2.75), (1.0, 1.6, 0.3), FAB_W, r, 0.12)
    # IV stand
    me.cyl((L / 2 + 0.6, -1.0, 0.0), (L / 2 + 0.6, -1.0, 6.0), 0.05, STEEL, seg=6)
    for a in range(4):
        an = a * math.pi / 2
        me.box((L / 2 + 0.6 + math.cos(an) * 0.35, -1.0 + math.sin(an) * 0.35, 0.08), (0.7, 0.08, 0.08), STEEL, rot=(0, 0, an))
    gl.box((L / 2 + 0.6, -0.95, 5.3), (0.5, 0.15, 0.8), (0.75, 0.82, 0.8, 1), bevel=0.05)
    pl.tube([(L / 2 + 0.6, -0.95, 4.9), (L / 2 + 0.3, -0.8, 3.6), (L / 2 - 0.4, -0.5, 2.8)], 0.02, WHITE, seg=4)
    # trolley
    for z in (1.0, 2.6):
        me.box((L / 2 + 0.4, 1.4, z), (1.6, 1.2, 0.08), STEEL)
    for sx in (-0.7, 0.7):
        for sy in (-0.5, 0.5):
            me.cyl((L / 2 + 0.4 + sx, 1.4 + sy, 0.1), (L / 2 + 0.4 + sx, 1.4 + sy, 2.6), 0.04, STEEL, seg=4)
    for k in range(4):
        pl.cyl((L / 2 + 0.0 + k * 0.3, 1.3, 2.64), (L / 2 + 0.0 + k * 0.3, 1.3, 2.64 + r.uniform(0.3, 0.6)), 0.1, (WHITE, BLUE, PAPER_Y, GREEN)[k], seg=8)
    return P


def craft_bench(name, seed):
    """hideout workbench 8 x 3 x 3.2: steel frame, worn top, a vise, a reloading press, a drill press, a tool wall"""
    P = Prop(name)
    r = rnd(seed)
    wo, me, pa, pl = P("wood"), P("metal"), P("paint"), P("plastic")
    L, D, H = 8.0, 3.0, 3.2
    wo.box((0, 0, H - 0.15), (L, D, 0.3), mix(WOOD, WOOD_D, 0.4), bevel=0.04)
    for sx in (-1, 1):
        for sy in (-1, 1):
            pa.box((sx * (L / 2 - 0.25), sy * (D / 2 - 0.25), (H - 0.3) / 2), (0.25, 0.25, H - 0.3), OLIVE_D)
    me.box((0, 0, 0.7), (L - 0.6, D - 0.6, 0.08), STEEL_D)
    me.box((-L / 2 + 0.9, -D / 2 + 0.3, H + 0.35), (1.0, 0.7, 0.6), STEEL_D)  # vise
    me.box((-L / 2 + 0.9, -D / 2 - 0.15, H + 0.4), (0.12, 0.6, 0.12), STEEL)
    pa.box((0.0, 0.3, H + 0.9), (0.6, 0.6, 1.6), RED)  # reloading press
    me.cyl((0.0, 0.0, H + 1.5), (0.0, -0.8, H + 1.2), 0.05, STEEL, seg=5)
    pa.box((2.8, 0.6, H + 0.15), (1.0, 1.0, 0.3), hexc("4E5A62"))  # drill press base
    pa.cyl((2.8, 0.9, H + 0.3), (2.8, 0.9, H + 3.2), 0.12, STEEL_D, seg=8)
    pa.box((2.8, 0.6, H + 2.9), (0.9, 1.2, 0.8), hexc("4E5A62"), bevel=0.05)
    for k in range(5):  # ammo boxes
        pl.box((-1.6 + k * 0.35, 0.8, H + 0.18), (0.3, 0.5, 0.35), mix(GREEN, YELLOW, 0.3 * (k % 2)))
    me.box((0, D / 2 - 0.05, H + 2.5), (L, 0.1, 3.0), hexc("8A7254"))  # tool wall
    for k in range(6):
        me.box((-3.0 + k * 1.1, D / 2 - 0.15, H + 2.6), (0.12, 0.05, 0.9 + 0.1 * k), STEEL)
    chipped(pa, RUST, seed, 0.3, 1.8)
    return P


def water_tank(name, seed):
    """water collector: a riveted steel tank on legs, a filter column, a hand pump, pipes and a drip tray"""
    P = Prop(name)
    pa, me, pl, gl = P("paint"), P("metal"), P("plastic"), P("glass")
    pa.cyl((0, 0.3, 1.2), (0, 0.3, 6.0), 1.9, hexc("54606A"), seg=16, smooth=True)
    pa.cyl((0, 0.3, 6.0), (0, 0.3, 6.5), 1.9, hexc("54606A"), r2=0.6, seg=16)
    for z in (2.2, 3.8, 5.4):
        me.torus((0, 0.3, z), 1.92, 0.06, STEEL_D, segU=20, segV=4)
    for a in range(4):
        an = a * math.pi / 2 + math.pi / 4
        me.box((math.cos(an) * 1.5, 0.3 + math.sin(an) * 1.5, 0.6), (0.2, 0.2, 1.2), STEEL_D)
    pl.cyl((2.6, -0.6, 0.0), (2.6, -0.6, 3.6), 0.35, (0.82, 0.84, 0.82, 1), seg=10)  # filter column
    gl.cyl((2.6, -0.6, 1.2), (2.6, -0.6, 2.6), 0.36, (0.45, 0.6, 0.66, 1), seg=10)
    me.tube([(1.8, 0.3, 1.6), (2.6, 0.0, 1.6), (2.6, -0.6, 3.6), (2.6, -0.6, 4.4), (1.0, 0.3, 6.2)], 0.1, STEEL, seg=6)
    me.box((-2.4, -0.6, 2.2), (0.3, 0.3, 4.4), STEEL_D)  # hand pump
    me.box((-2.4, -1.2, 4.3), (0.15, 1.4, 0.12), STEEL, rot=(R(-20), 0, 0))
    me.box((0.0, -1.2, 0.08), (3.0, 1.4, 0.16), STEEL_D)  # drip tray
    chipped(pa, RUST, seed, 0.32, 1.2)
    return P


def storage_rack(name, seed, empty=False):
    """steel shelving 8 x 7 x 2 with crates, ammo cans and bags; empty: the bare rack and a single box"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, ca, fa = P("paint"), P("metal"), P("cardboard"), P("fabric")
    L, H, D = 8.0, 7.0, 2.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            pa.box((sx * (L / 2 - 0.1), sy * (D / 2 - 0.1), H / 2), (0.15, 0.15, H), OLIVE_D)
    for z in (0.4, 2.6, 4.8, 6.9):
        me.box((0, 0, z), (L, D, 0.1), STEEL_D)
    if not empty:
        for z in (0.45, 2.65, 4.85):
            x = -L / 2 + 0.4
            while x < L / 2 - 0.8:
                w = r.uniform(0.8, 1.8)
                kind = r.random()
                if kind < 0.45:
                    ca.box((x + w / 2, 0, z + 0.5), (w - 0.1, D - 0.4, 0.9 + r.uniform(0, 0.6)), mix(CARD, mul(CARD, 0.75), r.random()), bevel=0.02)
                elif kind < 0.75:
                    pa.box((x + w / 2, 0, z + 0.45), (min(w, 1.2) - 0.1, 0.7, 0.8), OLIVE, bevel=0.04)  # ammo can
                else:
                    fa.box((x + w / 2, 0, z + 0.5), (w - 0.1, D - 0.5, 0.9), FAB_G, bevel=0.2)
                x += w
    else:
        ca.box((1.5, 0, 0.95), (1.4, 1.4, 1.0), CARD)
    chipped(pa, RUST, seed, 0.3, 1.8)
    return P


# ── gunsmith and range ───────────────────────────────────────────────────────
def gun_bench(name, seed):
    """gunsmith bench 14 x 3 x 3.2: a thick top on steel legs, a padded vise (the game clamps your gun in it), a
    lamp on an arm, a cleaning kit, rods, rags and a parts tray"""
    P = Prop(name)
    r = rnd(seed)
    wo, me, pa, pl, fa, gw = P("wood"), P("metal"), P("paint"), P("plastic"), P("fabric"), P("glow")
    L, D, H = 14.0, 3.0, 3.2
    wo.box((0, 0, H - 0.2), (L, D, 0.4), WOOD, bevel=0.05)
    for x in (-L / 2 + 0.4, 0.0, L / 2 - 0.4):
        for y in (-D / 2 + 0.3, D / 2 - 0.3):
            pa.box((x, y, (H - 0.4) / 2), (0.3, 0.3, H - 0.4), OLIVE_D)
    me.box((0, 0, 0.6), (L - 0.8, D - 0.6, 0.08), STEEL_D)
    fa.box((0, -0.3, H + 0.02), (5.0, 1.8, 0.04), hexc("3E4A3E"))  # bench mat
    # vise in the middle: the gun sits over it
    me.box((-0.6, -0.2, H + 0.45), (0.7, 0.9, 0.9), STEEL_D)
    me.box((0.6, -0.2, H + 0.45), (0.7, 0.9, 0.9), STEEL_D)
    fa.box((-0.27, -0.2, H + 0.75), (0.08, 0.8, 0.4), RED)
    fa.box((0.27, -0.2, H + 0.75), (0.08, 0.8, 0.4), RED)
    me.cyl((0.95, -0.2, H + 0.3), (1.6, -0.2, H + 0.3), 0.06, STEEL, seg=6)
    # lamp on an arm
    me.box((5.5, 1.2, H + 0.1), (0.5, 0.5, 0.2), STEEL_D)
    me.tube([(5.5, 1.2, H + 0.2), (5.3, 1.1, H + 2.6), (4.2, 0.6, H + 3.0)], 0.05, STEEL_D, seg=5)
    me.cyl((4.2, 0.6, H + 3.0), (4.0, 0.4, H + 2.6), 0.15, OLIVE_D, r2=0.45, seg=10)
    gw.cyl((4.05, 0.45, H + 2.72), (4.0, 0.4, H + 2.62), 0.13, WARM, seg=6)
    # cleaning kit, rods, rags, a parts tray
    pa.box((-4.5, 0.3, H + 0.25), (2.0, 1.0, 0.5), OLIVE, bevel=0.04)
    for k in range(3):
        me.cyl((-6.2, -0.8 + k * 0.15, H + 0.05), (-2.6, -0.8 + k * 0.15, H + 0.05), 0.03, STEEL, seg=4)
    fa.box((3.0, -0.6, H + 0.06), (1.0, 0.8, 0.1), WHITE, rot=(0, 0, 0.4), bevel=0.04)
    me.box((2.0, 0.6, H + 0.1), (1.6, 1.0, 0.2), STEEL)
    for k in range(6):
        pl.box((1.5 + (k % 3) * 0.35, 0.4 + (k // 3) * 0.4, H + 0.24), (0.2, 0.25, 0.1), (BLACK, STEEL, YELLOW)[k % 3])
    return P


def range_booth(name, seed):
    """shooting booth divider 10 x 7 with a shelf at the firing line, an ear-protection hook and a spent-brass bin"""
    P = Prop(name)
    pa, wo, me, pl = P("paint"), P("wood"), P("metal"), P("plastic")
    L, H = 10.0, 7.0
    pa.box((0, 0, H / 2), (L, 0.25, H), OLIVE_D)
    pa.box((-L / 2 + 0.75, -2.6, 3.2), (1.5, 5.2, 0.2), WOOD)  # shelf along the firing line (x = -L/2)
    pa.box((-L / 2 + 1.4, -2.6, 1.6), (0.15, 5.0, 3.2), OLIVE_D)
    me.cyl((1.5, -0.13, 4.8), (1.5, -0.45, 4.8), 0.04, STEEL, seg=5)
    pl.torus((1.5, -0.5, 4.5), 0.35, 0.08, RED, segU=12, segV=5, rot=(R(90), 0, 0))
    pl.box((1.2, -0.55, 4.25), (0.25, 0.25, 0.35), BLACK, bevel=0.04)
    pl.box((1.8, -0.55, 4.25), (0.25, 0.25, 0.35), BLACK, bevel=0.04)
    me.cyl((0.5, -1.5, 0.0), (0.5, -1.5, 1.4), 0.5, STEEL_D, seg=10)  # brass bin
    me.cyl((0.5, -1.5, 1.38), (0.5, -1.5, 1.4), 0.45, hexc("A8843A"), seg=10)
    return P


def steel_plate(name, seed):
    """AR500-style steel plate on an A-frame stand, white paint shot through to bare grey"""
    P = Prop(name)
    r = rnd(seed)
    me, pa = P("metal"), P("paint")
    for s in (-1, 1):
        me.box((s * 0.8, 0, 1.0), (0.12, 0.12, 2.2), STEEL_D, rot=(0, s * R(12), 0))
    me.box((0, 0, 0.05), (2.0, 1.2, 0.1), STEEL_D)
    me.box((0, 0, 2.1), (1.6, 0.12, 0.12), STEEL_D)
    pa.box((0, -0.1, 3.0), (1.2, 0.18, 1.8), WHITE, bevel=0.03)
    for k in range(9):
        x, z = r.gauss(0, 0.22), 3.0 + r.gauss(0, 0.3)
        pa.cyl((x, -0.2, z), (x, -0.205, z), 0.06, (0.45, 0.46, 0.46, 1), seg=6)
    me.cyl((-0.4, -0.05, 2.2), (-0.4, -0.05, 2.1), 0.05, STEEL, seg=4)
    me.cyl((0.4, -0.05, 2.2), (0.4, -0.05, 2.1), 0.05, STEEL, seg=4)
    return P


def paper_target(name, seed):
    """paper target on a wooden frame: a generic silhouette and scoring rings"""
    P = Prop(name)
    wo, pl = P("wood"), P("plastic")
    for s in (-1, 1):
        wo.box((s * 1.1, 0, 2.2), (0.15, 0.15, 4.4), WOOD_D)
    wo.box((0, 0, 0.6), (2.4, 0.15, 0.15), WOOD_D)
    pl.box((0, -0.08, 3.0), (2.0, 0.02, 2.6), PAPER)
    pl.box((0, -0.095, 3.1), (0.9, 0.01, 1.4), mul(PAPER, 0.55))  # torso
    pl.cyl((0, -0.095, 4.05), (0, -0.1, 4.05), 0.32, mul(PAPER, 0.55), seg=10)  # head
    for k, rr in enumerate((0.55, 0.35, 0.15)):
        pl.cyl((0, -0.1 - k * 0.002, 3.15), (0, -0.102 - k * 0.002, 3.15), rr, (BLACK, mul(PAPER, 0.4), RED)[k], seg=12)
    return P


def range_display(name, seed):
    """small display box over a booth (the game shows hits, group size and time on it)"""
    P = Prop(name)
    me, pl = P("metal"), P("plastic")
    me.box((0, 0.15, 0.6), (2.4, 0.3, 1.2), STEEL_D, bevel=0.03)
    pl.box((0, -0.01, 0.6), (2.1, 0.02, 0.9), (0.03, 0.04, 0.035, 1))
    me.cyl((0, 0.15, 1.2), (0, 0.15, 2.2), 0.04, STEEL_D, seg=4)
    return P


# ── furniture and clutter ────────────────────────────────────────────────────
def table(name, seed):
    """steel-framed table 6 x 3 with a worn top, a mug and papers"""
    P = Prop(name)
    r = rnd(seed)
    wo, me, pl = P("wood"), P("metal"), P("plastic")
    wo.box((0, 0, 2.6), (6.0, 3.0, 0.2), mix(WOOD, WOOD_D, 0.5), bevel=0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            me.box((sx * 2.75, sy * 1.25, 1.25), (0.15, 0.15, 2.5), STEEL_D)
    pl.cyl((1.5, 0.5, 2.7), (1.5, 0.5, 3.1), 0.18, WHITE, seg=10)
    for k in range(3):
        pl.box((r.uniform(-2, 1), r.uniform(-0.8, 0.8), 2.71 + k * 0.004), (0.85, 1.1, 0.01), PAPER, rot=(0, 0, r.uniform(-0.5, 0.5)))
    return P


def chair(name, seed):
    """folding steel chair"""
    P = Prop(name)
    me, pl = P("metal"), P("plastic")
    pl.box((0, 0, 1.55), (1.3, 1.3, 0.12), OLIVE_D, bevel=0.03)
    for sx in (-0.55, 0.55):
        me.box((sx, 0, 0.78), (0.07, 1.45, 0.07), STEEL_D, rot=(R(28), 0, 0))
        me.box((sx, 0, 0.78), (0.07, 1.45, 0.07), STEEL_D, rot=(R(-28), 0, 0))
        me.box((sx, 0.62, 2.3), (0.07, 0.07, 1.6), STEEL_D)
    pl.box((0, 0.66, 2.7), (1.2, 0.1, 0.8), OLIVE_D, bevel=0.03)
    return P


def ammo_crate(name, seed):
    """olive wooden ammunition crate with rope handles and painted marks"""
    P = Prop(name)
    r = rnd(seed)
    wo, fa, pa = P("wood"), P("fabric"), P("paint")
    wo.box((0, 0, 0.75), (3.0, 1.6, 1.5), OLIVE, bevel=0.03)
    for x in (-1.2, 1.2):
        wo.box((x, 0, 0.75), (0.2, 1.7, 1.55), OLIVE_D)
    wo.box((0, 0, 1.52), (3.05, 1.65, 0.08), OLIVE_D)
    for s in (-1, 1):
        fa.torus((s * 1.55, 0, 1.0), 0.25, 0.05, hexc("8A7A5A"), segU=10, segV=4, rot=(0, R(90), 0))
    pa.box((0, -0.82, 0.9), (1.2, 0.02, 0.35), YELLOW)
    return P


def drum(name, seed):
    """steel drum, dented and rust-streaked"""
    P = Prop(name)
    r = rnd(seed)
    pa, me = P("paint"), P("metal")
    col = r.choice((hexc("2E4E6E"), hexc("6A6E4E"), hexc("8A3A2E")))
    pa.cyl((0, 0, 0.05), (0, 0, 2.85), 0.95, col, seg=16, smooth=True)
    for z in (0.95, 1.9):
        me.torus((0, 0, z), 0.96, 0.04, mul(col, 0.7), segU=16, segV=4)
    me.cyl((0, 0, 2.85), (0, 0, 2.9), 0.92, mul(col, 0.8), seg=16)
    me.cyl((0.4, 0.3, 2.9), (0.4, 0.3, 2.98), 0.12, STEEL_D, seg=8)
    chipped(pa, RUST, seed, 0.45, 1.3)
    return P


PROPS = {
    "BunkBed": lambda: bunk_bed("BunkBed", 801),
    "BunkBedMessy": lambda: bunk_bed("BunkBedMessy", 802, messy=True),
    "Locker": lambda: locker("Locker", 803),
    "LockerOpen": lambda: locker("LockerOpen", 804, open_=True),
    "MirrorSink": lambda: mirror_sink("MirrorSink", 805),
    "MapTable": lambda: map_table("MapTable", 806),
    "DepartureBoard": lambda: departure_board("DepartureBoard", 807),
    "Whiteboard": lambda: whiteboard("Whiteboard", 808),
    "CorkBoard": lambda: cork_board("CorkBoard", 809),
    "InsuranceWindow": lambda: insurance_window("InsuranceWindow", 810),
    "Counter": lambda: counter("Counter", 811),
    "GunRack": lambda: gun_rack("GunRack", 812),
    "Pegboard": lambda: pegboard("Pegboard", 813),
    "MedShelf": lambda: med_shelf("MedShelf", 814),
    # (not "Mannequin": the mall kit owns ZR_MK_Mannequin__*; kit prop names must be unique across every kit batch)
    "ArmorStand": lambda: mannequin("ArmorStand", 815),
    "RigStand": lambda: mannequin("RigStand", 816, rig=True),
    "Pigeonholes": lambda: pigeonholes("Pigeonholes", 817),
    "FenceStall": lambda: fence_stall("FenceStall", 818),
    "HideoutGenerator": lambda: hideout_generator("HideoutGenerator", 819),
    "MedCot": lambda: med_cot("MedCot", 820),
    "CraftBench": lambda: craft_bench("CraftBench", 821),
    "WaterTank": lambda: water_tank("WaterTank", 822),
    "StorageRack": lambda: storage_rack("StorageRack", 823),
    "StorageRackEmpty": lambda: storage_rack("StorageRackEmpty", 824, empty=True),
    "GunBench": lambda: gun_bench("GunBench", 825),
    "RangeBooth": lambda: range_booth("RangeBooth", 826),
    "SteelPlate": lambda: steel_plate("SteelPlate", 827),
    "PaperTarget": lambda: paper_target("PaperTarget", 828),
    "RangeDisplay": lambda: range_display("RangeDisplay", 829),
    "Table": lambda: table("Table", 830),
    "Chair": lambda: chair("Chair", 831),
    "AmmoCrate": lambda: ammo_crate("AmmoCrate", 832),
    "Drum": lambda: drum("Drum", 833),
}
WALL = dict(ground=False, floor_dirt=0.0)
BAKE = {
    "MirrorSink": dict(floor_dirt=0.1),
    "DepartureBoard": WALL, "Whiteboard": WALL, "CorkBoard": WALL, "GunRack": WALL, "Pegboard": WALL,
    "RangeDisplay": WALL, "InsuranceWindow": dict(floor_dirt=0.0),
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


def sheet(out_png=None, names=None, **kw):
    out_png = out_png or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "build", "%s_sheet.png" % BATCH)
    objs = [o for o in objects() if (not names or o.name[6:].split("__")[0] in names)]
    return contact_sheet(objs, out_png, **kw)

"""Zero Return - Relay 7 bunker kit, batch C: the motor pool (the lobby, 2026-10-29). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_bunker_kit_c.py").read(), g); g["build"](names or None)
   then g["export"]() -> assets/exports/ZR_BunkerKitC.fbx (+ .blend, .meta.json, .props.json)
Units are studs. Origin bottom-centre, front toward Blender -Y. The van's rear doors are separate props (VanDoor,
hinge at the origin, closed along +X; VanDoorR its mirror image) so the game can swing them shut when the squad has
boarded.
All geometry is original and procedural (no real vehicle is copied).
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
BATCH = "ZR_BunkerKitC"

VAN = hexc("5E6350")
VAN_D = hexc("484C3C")
STEEL = (0.5, 0.51, 0.52, 1)
STEEL_D = (0.25, 0.26, 0.27, 1)
RUST = hexc("7A4B32")
YELLOW = hexc("C9A13C")
BLACK = (0.07, 0.07, 0.075, 1)
WHITE = (0.84, 0.84, 0.8, 1)
RED = hexc("8E2F24")
RUBBER = (0.09, 0.09, 0.09, 1)
GLASS = (0.32, 0.36, 0.37, 1)
CONCRETE = hexc("6E6B63")
CONCRETE_D = hexc("55524C")
FAB = hexc("3E4236")
WARM = (1.0, 0.92, 0.76, 1)


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


def wheel(me, ru, x, y, z, r=1.3, w=0.9):
    ru.cyl((x - w / 2, y, z), (x + w / 2, y, z), r, RUBBER, seg=16, smooth=True)
    me.cyl((x + (w / 2 + 0.02) * (1 if x > 0 else -1), y, z), (x + (w / 2 + 0.06) * (1 if x > 0 else -1), y, z), r * 0.55, STEEL_D, seg=12)
    for k in range(6):
        an = k * math.pi / 3
        me.cyl((x + (w / 2 + 0.08) * (1 if x > 0 else -1), y + math.cos(an) * r * 0.35, z + math.sin(an) * r * 0.35),
               (x + (w / 2 + 0.14) * (1 if x > 0 else -1), y + math.cos(an) * r * 0.35, z + math.sin(an) * r * 0.35), 0.07, STEEL, seg=6)


# ── the van ──────────────────────────────────────────────────────────────────
def van(name, seed):
    """armoured panel van 6.6 wide, 19 long, 7.8 tall; front toward -Y. Cab with glass, bull bar, armour plates
    bolted on, roof rack, side steps; the rear is open (doors are VanDoor props) onto two bench seats inside"""
    P = Prop(name)
    r = rnd(seed)
    pa, me, ru, gl, fa, pl, gw = P("paint"), P("metal"), P("rubber"), P("glass"), P("fabric"), P("plastic"), P("glow")
    W, L, H = 6.6, 19.0, 7.8
    y0, y1 = -L / 2, L / 2
    zc = 1.6  # floor of the body
    # chassis and wheels
    me.box((0, 0, 1.2), (W - 1.4, L - 2.0, 0.6), STEEL_D)
    for y in (y0 + 3.6, y1 - 3.6):
        for s in (-1, 1):
            wheel(me, ru, s * (W / 2 - 0.45), y, 1.3)
            pa.box((s * (W / 2 - 0.2), y, 2.4), (0.6, 3.4, 0.5), VAN_D)  # wheel arch lip
    # cargo box (rear 12.5) with a hollow interior: floor, walls, roof
    bx0, bx1 = y0 + 6.5, y1
    pa.box((0, (bx0 + bx1) / 2, zc + 0.1), (W, bx1 - bx0, 0.2), VAN_D)  # floor
    for s in (-1, 1):
        pa.box((s * (W / 2 - 0.15), (bx0 + bx1) / 2, (zc + H) / 2), (0.3, bx1 - bx0, H - zc), VAN)
    pa.box((0, (bx0 + bx1) / 2, H - 0.15), (W, bx1 - bx0, 0.3), VAN)
    pa.box((0, bx0 + 0.15, (zc + H) / 2), (W, 0.3, H - zc), VAN)  # bulkhead behind the cab
    for s in (-1, 1):  # rear door frame posts
        pa.box((s * (W / 2 - 0.35), y1 - 0.2, (zc + H) / 2), (0.7, 0.4, H - zc), VAN_D)
    pa.box((0, y1 - 0.2, H - 0.35), (W, 0.4, 0.7), VAN_D)
    me.box((0, y1 + 0.3, zc - 0.3), (W - 0.6, 0.9, 0.25), STEEL_D)  # rear step
    # interior: two bench seats with webbing straps, a gun rack bar, a dome light
    for s in (-1, 1):
        fa.box((s * (W / 2 - 1.0), (bx0 + bx1) / 2 + 1.0, zc + 1.4), (1.2, bx1 - bx0 - 3.0, 0.35), FAB, bevel=0.06)
        fa.box((s * (W / 2 - 0.45), (bx0 + bx1) / 2 + 1.0, zc + 2.6), (0.25, bx1 - bx0 - 3.0, 1.8), FAB, bevel=0.05)
        me.box((s * (W / 2 - 1.0), (bx0 + bx1) / 2 + 1.0, zc + 0.7), (1.0, bx1 - bx0 - 3.2, 0.12), STEEL_D)
        for k in range(4):
            fa.box((s * (W / 2 - 0.35), bx0 + 2.5 + k * 2.4, zc + 3.2), (0.1, 0.15, 2.8), YELLOW)
    me.box((0, bx0 + 0.6, H - 0.8), (W - 1.0, 0.12, 0.12), STEEL)
    gw.box((0, (bx0 + bx1) / 2, H - 0.32), (1.2, 0.6, 0.06), (1.0, 0.55, 0.4, 1))
    # cab
    cz = 5.8
    pa.box((0, y0 + 3.5, (zc + cz) / 2), (W, 6.0, cz - zc), VAN)
    pa.box((0, y0 + 4.5, cz + 0.6), (W, 4.0, 1.2), VAN)  # cab roof step
    pa.box((0, y0 + 1.2, 3.3), (W - 0.4, 2.4, 1.6), VAN, bevel=0.1)  # hood
    gl.box((0, y0 + 2.62, 6.0), (W - 0.8, 0.12, 1.5), GLASS, rot=(R(-18), 0, 0))  # windscreen
    for s in (-1, 1):
        gl.box((s * (W / 2 + 0.01), y0 + 4.2, 5.9), (0.06, 2.4, 1.3), GLASS)
        me.box((s * (W / 2 + 0.25), y0 + 2.9, 5.6), (0.3, 0.12, 0.6), STEEL_D)  # mirrors
        me.box((s * (W / 2 + 0.55), y0 + 2.9, 5.6), (0.12, 0.5, 0.8), BLACK)
        me.box((s * (W / 2 + 0.25), y0 + 4.5, 1.8), (0.5, 2.6, 0.15), STEEL_D)  # cab step
    # grille, lights, bull bar
    me.box((0, y0 + 0.02, 3.1), (W - 1.8, 0.1, 1.2), BLACK)
    for k in range(6):
        me.box((0, y0 - 0.02, 2.6 + k * 0.18), (W - 2.0, 0.04, 0.06), STEEL_D)
    for s in (-1, 1):
        pl.box((s * (W / 2 - 0.7), y0 + 0.02, 3.4), (0.9, 0.1, 0.5), WHITE)
        pl.box((s * (W / 2 - 0.7), y1 + 0.01, 3.0), (0.6, 0.06, 1.0), RED)
    me.box((0, y0 - 0.7, 1.5), (W - 0.4, 0.3, 0.3), STEEL_D)
    me.box((0, y0 - 0.7, 3.0), (W - 0.4, 0.3, 0.3), STEEL_D)
    for x in (-2.2, -0.7, 0.7, 2.2):
        me.box((x, y0 - 0.65, 2.25), (0.25, 0.25, 1.8), STEEL_D)
    # bolted armour plates along the cargo sides, the roof rack, a spare wheel on the back
    for s in (-1, 1):
        for k in range(4):
            yy = bx0 + 1.6 + k * 2.9
            pa.box((s * (W / 2 + 0.06), yy, 4.4), (0.12, 2.7, 3.2), VAN_D, bevel=0.03)
            for (dy, dz) in ((-1.2, 1.4), (1.2, 1.4), (-1.2, -1.4), (1.2, -1.4)):
                me.cyl((s * (W / 2 + 0.12), yy + dy, 4.4 + dz), (s * (W / 2 + 0.18), yy + dy, 4.4 + dz), 0.07, STEEL, seg=6)
    for s in (-1, 1):
        me.box((s * (W / 2 - 0.3), (bx0 + bx1) / 2, H + 0.4), (0.15, bx1 - bx0 - 0.6, 0.15), STEEL_D)
    for k in range(6):
        me.box((0, bx0 + 0.8 + k * 2.2, H + 0.4), (W - 0.6, 0.12, 0.12), STEEL_D)
    fa.box((-0.8, bx0 + 4.0, H + 0.75), (2.4, 2.6, 0.6), FAB, bevel=0.15)  # a tarp bundle on the rack
    me.box((1.6, bx0 + 7.0, H + 0.65), (1.4, 1.4, 0.5), hexc("4A4E3E"))  # a jerry can box
    chipped(pa, RUST, seed, 0.25, 0.9)
    return P


def van_door(name, seed, mirror=False):
    """one rear door leaf of the van: hinge at the origin, closed it runs along +X (3.2 wide), outside toward +Y;
    mirror: the other leaf (runs along -X), so the pair opens like real barn doors (Roblox cannot mirror a mesh)"""
    P = Prop(name)
    pa, me, gl = P("paint"), P("metal"), P("glass")
    Wd, H, T = 3.15, 6.0, 0.25
    s = -1.0 if mirror else 1.0
    pa.box((s * Wd / 2, 0, H / 2), (Wd, T, H), VAN, bevel=0.04)
    gl.box((s * Wd / 2, 0.14, H - 1.4), (Wd - 1.0, 0.04, 1.0), GLASS)
    me.box((s * Wd / 2, 0.16, H - 1.4), (0.08, 0.06, 1.0), STEEL_D)  # window bar
    for z in (0.9, H - 0.9):
        me.cyl((0.0, 0, z - 0.3), (0.0, 0, z + 0.3), 0.12, STEEL_D, seg=8)  # hinge knuckles
    me.box((s * (Wd - 0.35), 0.18, H / 2), (0.12, 0.12, 0.8), STEEL)  # handle
    pa.box((s * Wd / 2, 0.15, 1.5), (Wd - 0.4, 0.06, 1.6), VAN_D)  # armour patch
    chipped(pa, RUST, seed, 0.25, 1.4)
    return P


# ── ramp, roller door, hatch ─────────────────────────────────────────────────
def ramp(name, seed):
    """concrete vehicle ramp 13 wide, 36 long, rising 9 from the front (-Y, at the floor) to the back: anti-slip
    grooves, steel edge rails, hazard stripes at the foot"""
    P = Prop(name)
    r = rnd(seed)
    co, me, pa = P("concrete"), P("metal"), P("paint")
    W, L, Hh = 13.0, 36.0, 9.0
    prof = [(-L / 2, 0.0), (L / 2, 0.0), (L / 2, Hh), (-L / 2, 0.02)]
    co.prism([(y, z) for (y, z) in prof], -W / 2, W / 2, CONCRETE)
    slope = Hh / L
    for k in range(17):  # anti-slip grooves across the slope
        y = -L / 2 + 1.5 + k * 2.0
        z = (y + L / 2) * slope
        co.box((0, y, z + 0.02), (W - 1.2, 0.18, 0.06), CONCRETE_D, rot=(math.atan(slope), 0, 0))
    for s in (-1, 1):  # edge rails (kerbs with a steel cap)
        x0, x1 = (W / 2 - 0.6, W / 2) if s > 0 else (-W / 2, -W / 2 + 0.6)
        me.prism([(-L / 2, 0.0), (L / 2, Hh), (L / 2, Hh + 0.7), (-L / 2, 0.7)], x0, x1, STEEL_D)
    for i in range(8):  # hazard stripes at the foot
        x = -W / 2 + 0.8 + i * (W - 1.6) / 8
        pa.box((x + (W - 1.6) / 16, -L / 2 + 0.6, 0.18), ((W - 1.6) / 8 * 0.96, 1.0, 0.04), YELLOW if i % 2 == 0 else BLACK, rot=(math.atan(slope), 0, 0))
    chipped(me, RUST, seed, 0.35, 0.8)
    return P


def roller_door(name, seed):
    """roller shutter 13 x 9 in a steel frame: corrugated slats, a bottom rail, a dent and a padlocked latch"""
    P = Prop(name)
    r = rnd(seed)
    me, pa = P("metal"), P("paint")
    W, H = 13.0, 9.0
    for s in (-1, 1):
        me.box((s * (W / 2 + 0.3), 0.2, H / 2), (0.6, 0.6, H + 0.4), STEEL_D)
    me.box((0, 0.3, H + 0.7), (W + 1.2, 1.4, 1.4), STEEL_D)  # roller housing
    for k in range(int(H / 0.4)):
        z = 0.2 + k * 0.4
        dent = 0.12 if 2.0 < z < 3.6 else 0.0
        pa.box((0, 0.0 + dent * math.sin(k), z + 0.2), (W, 0.12, 0.38), mul(hexc("6E7468"), 0.92 + 0.08 * (k % 2)))
    me.box((0, -0.05, 0.12), (W, 0.25, 0.25), STEEL_D)
    me.box((2.0, -0.2, 0.5), (0.5, 0.2, 0.6), STEEL)
    me.torus((2.0, -0.32, 0.45), 0.18, 0.05, STEEL, segU=10, segV=4, rot=(R(90), 0, 0))
    chipped(pa, RUST, seed, 0.4, 1.0)
    return P


def manhole(name, seed):
    """the scav hatch: a square steel frame in the floor, the lid swung open on its hinge, the top rungs of a ladder
    down a dark shaft"""
    P = Prop(name)
    me, pa, pl = P("metal"), P("paint"), P("plastic")
    S = 4.2
    for s in (-1, 1):
        me.box((s * (S / 2 - 0.2), 0, 0.08), (0.4, S, 0.16), STEEL_D)
        me.box((0, s * (S / 2 - 0.2), 0.08), (S, 0.4, 0.16), STEEL_D)
    pl.box((0, 0, 0.005), (S - 0.8, S - 0.8, 0.01), (0.01, 0.01, 0.012, 1))  # the dark shaft
    for k in range(3):  # ladder rungs just below the rim
        me.box((0, S / 2 - 0.6, -0.05 - k * 0.0), (1.4, 0.1, 0.06), STEEL, rot=(0, 0, 0))
    me.box((-0.7, S / 2 - 0.6, 0.06), (0.1, 0.12, 0.2), STEEL)
    me.box((0.7, S / 2 - 0.6, 0.06), (0.1, 0.12, 0.2), STEEL)
    # the lid, open about 110 degrees on the back hinge
    lid = Matrix.Translation((0, S / 2 - 0.2, 0.16)) @ Matrix.Rotation(R(-110), 4, "X") @ Matrix.Translation((0, -(S / 2 - 0.2), -0.16))
    before = set(pa.bm.verts)
    pa.box((0, 0, 0.24), (S - 0.6, S - 0.6, 0.16), hexc("3E423A"))
    for k in range(5):
        pa.box((0, -S / 2 + 0.8 + k * 0.6, 0.34), (S - 1.2, 0.08, 0.04), hexc("2E302C"))
    bmesh.ops.transform(pa.bm, matrix=lid, verts=[v for v in pa.bm.verts if v not in before])
    for s in (-1, 1):
        me.cyl((s * 1.2, S / 2 - 0.2, 0.16), (s * 0.8, S / 2 - 0.2, 0.16), 0.12, STEEL_D, seg=8)
    chipped(pa, RUST, seed, 0.4, 1.4)
    return P


def sign_post(name, seed):
    """sign board 3 x 2 on a post (the game writes the scav cooldown on it)"""
    P = Prop(name)
    me, pa = P("metal"), P("paint")
    me.cyl((0, 0.2, 0.0), (0, 0.2, 4.6), 0.08, STEEL_D, seg=6)
    me.cyl((0, 0.2, 0.0), (0, 0.2, 0.1), 0.4, STEEL_D, seg=8)
    pa.box((0, 0.0, 4.6), (3.0, 0.1, 2.0), hexc("2E302C"), bevel=0.02)
    pa.box((0, -0.06, 5.45), (2.8, 0.02, 0.2), YELLOW)
    chipped(pa, RUST, seed, 0.3, 1.8)
    return P


# ── garage clutter ───────────────────────────────────────────────────────────
def tool_chest(name, seed):
    """red rolling tool chest 3 x 4 x 1.8 with drawers, one pulled out, casters and a top box"""
    P = Prop(name)
    pa, me = P("paint"), P("metal")
    pa.box((0, 0, 2.0), (3.0, 1.8, 3.4), RED, bevel=0.05)
    for k in range(6):
        z = 0.7 + k * 0.5
        out = 0.6 if k == 2 else 0.0
        pa.box((0, -0.9 - out / 2, z), (2.8, 0.04 + out, 0.42), mul(RED, 1.1))
        me.box((0, -0.95 - out, z + 0.05), (1.6, 0.06, 0.06), STEEL)
    pa.box((0, 0, 4.0), (3.0, 1.8, 0.6), mul(RED, 0.95), bevel=0.05)
    for sx in (-1.2, 1.2):
        for sy in (-0.6, 0.6):
            me.cyl((sx, sy, 0.0), (sx, sy, 0.3), 0.15, BLACK, seg=8)
    chipped(pa, RUST, seed, 0.3, 2.0)
    return P


def tyre_stack(name, seed):
    """four worn tyres stacked, the top one slipped"""
    P = Prop(name)
    r = rnd(seed)
    ru = P("rubber")
    for k in range(4):
        dx = 0.25 if k == 3 else r.uniform(-0.08, 0.08)
        ru.torus((dx, 0, 0.45 + k * 0.85), 1.05, 0.42, RUBBER, segU=18, segV=6, rot=(0, R(8) if k == 3 else 0, 0))
    return P


def jerry_cans(name, seed):
    """three jerry cans, one on its side"""
    P = Prop(name)
    pa, me = P("paint"), P("metal")
    cols = (hexc("4A5A3A"), hexc("8E2F24"), hexc("4A5A3A"))
    for k, (x, rot) in enumerate(((-0.8, 0), (0.0, 0), (1.1, R(90)))):
        z = 1.05 if rot == 0 else 0.4
        pa.box((x, 0, z), (0.7, 1.6, 2.1) if rot == 0 else (0.7, 2.1, 1.6), cols[k], bevel=0.06)
        if rot == 0:
            me.box((x, -0.3, 2.2), (0.2, 0.5, 0.2), STEEL_D)
    chipped(pa, RUST, seed, 0.3, 2.0)
    return P


def work_light(name, seed):
    """tripod work light with a twin head (glow), a cable to the wall"""
    P = Prop(name)
    me, gw, ru = P("metal"), P("glow"), P("rubber")
    for a in range(3):
        an = a * 2 * math.pi / 3
        me.cyl((math.cos(an) * 1.0, math.sin(an) * 1.0, 0.0), (0, 0, 2.6), 0.05, YELLOW, seg=6)
    me.cyl((0, 0, 2.6), (0, 0, 5.2), 0.06, YELLOW, seg=6)
    me.box((0, 0, 5.3), (1.8, 0.15, 0.15), STEEL_D)
    for s in (-1, 1):
        me.box((s * 0.6, -0.1, 5.55), (0.9, 0.5, 0.7), STEEL_D, bevel=0.04)
        gw.box((s * 0.6, -0.37, 5.55), (0.75, 0.04, 0.55), WARM)
    ru.tube([(0, 0, 2.6), (0.3, 0.6, 0.1), (1.5, 1.6, 0.06), (3.0, 2.2, 0.06)], 0.06, BLACK, seg=5)
    return P


def hose_reel(name, seed):
    """wall-mounted hose reel with a coiled air hose"""
    P = Prop(name)
    me, ru = P("metal"), P("rubber")
    me.box((0, 0.3, 1.0), (1.4, 0.15, 1.6), STEEL_D)
    me.cyl((0, 0.25, 1.0), (0, -0.4, 1.0), 0.75, YELLOW, seg=14)
    for k in range(5):
        ru.torus((0, -0.1 + k * -0.06, 1.0), 0.55 + k * 0.03, 0.06, hexc("2E4E6E"), segU=16, segV=4, rot=(R(90), 0, 0))
    ru.tube([(0.7, -0.2, 0.9), (1.0, -0.6, 0.3), (1.6, -1.2, 0.05)], 0.06, hexc("2E4E6E"), seg=5)
    return P


def oil_stain(name, seed):
    """a dark oil patch on the floor with a rag and a funnel (a few millimetres high)"""
    P = Prop(name)
    r = rnd(seed)
    pl, fa = P("plastic"), P("fabric")
    pts = []
    for k in range(14):
        an = k * 2 * math.pi / 14
        rr = 2.2 * (0.7 + 0.3 * r.random())
        pts.append((math.cos(an) * rr, math.sin(an) * rr * 0.7, 0.01))
    pl.face(pts, (0.04, 0.04, 0.04, 1))
    fa.box((1.2, 0.6, 0.06), (0.9, 0.7, 0.1), mix(WHITE, BLACK, 0.4), rot=(0, 0, 0.5), bevel=0.04)
    pl.cyl((-1.0, -0.4, 0.05), (-1.0, -0.4, 0.5), 0.1, YELLOW, r2=0.45, seg=10)
    return P


PROPS = {
    "Van": lambda: van("Van", 901),
    "VanDoor": lambda: van_door("VanDoor", 902),
    "VanDoorR": lambda: van_door("VanDoorR", 913, mirror=True),
    "Ramp": lambda: ramp("Ramp", 903),
    "RollerDoor": lambda: roller_door("RollerDoor", 904),
    "Manhole": lambda: manhole("Manhole", 905),
    "SignPost": lambda: sign_post("SignPost", 906),
    "ToolChest": lambda: tool_chest("ToolChest", 907),
    "TyreStack": lambda: tyre_stack("TyreStack", 908),
    "JerryCans": lambda: jerry_cans("JerryCans", 909),
    "WorkLight": lambda: work_light("WorkLight", 910),
    "HoseReel": lambda: hose_reel("HoseReel", 911),
    "OilStain": lambda: oil_stain("OilStain", 912),
}
BAKE = {
    "Van": dict(ao_dist=3.0, dust=0.22),
    "Ramp": dict(dust=0.2),
    "RollerDoor": dict(ground=False, floor_dirt=0.0),
    "HoseReel": dict(ground=False, floor_dirt=0.0),
    "OilStain": dict(bake=False),
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

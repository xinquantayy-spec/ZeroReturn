"""Zero Return - Relay 7 bunker kit, batch A: structure and fittings (the lobby, 2026-10-29). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_bunker_kit_a.py").read(), g); g["build"](names or None)
   then g["export"]() -> assets/exports/ZR_BunkerKitA.fbx (+ .blend, .meta.json, .props.json)
Units are studs. Origin bottom-centre, front toward Blender -Y (Roblox LookVector). Wall-mounted props have their
back at +Y (the wall) so the placing code puts the origin half the prop's depth off the wall. Colour, ambient
occlusion, grime and dust are baked into vertex colours (zr_kit.Prop.bake); Roblox materials give the surface grain.
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
BATCH = "ZR_BunkerKitA"

OLIVE = hexc("5B5F45")
OLIVE_D = hexc("464A36")
STEEL = (0.5, 0.51, 0.52, 1)
STEEL_D = (0.25, 0.26, 0.27, 1)
RUST = hexc("7A4B32")
RUST_D = hexc("5A3626")
YELLOW = hexc("C9A13C")
BLACK = (0.07, 0.07, 0.075, 1)
WHITE = (0.84, 0.84, 0.8, 1)
RED = hexc("8E2F24")
GREEN = hexc("3F6B45")
PIPE_GREEN = hexc("4E6450")
PIPE_GREY = hexc("7A7C78")
CONCRETE = hexc("77736A")
CONCRETE_D = hexc("5A5750")
RUBBER = (0.09, 0.09, 0.09, 1)
SAND = hexc("8A7E5E")
SAND_D = hexc("6E6448")
GLASS = (0.55, 0.6, 0.6, 1)
WARM = (1.0, 0.92, 0.76, 1)


def mul(c, k):
    return (min(1, c[0] * k), min(1, c[1] * k), min(1, c[2] * k), 1)


def chipped(b, base, chip=RUST, seed=0, amount=0.35, scale=1.6):
    """worn paint: patches of the under-colour where a noise field peaks (edges of a prop wear first)"""
    def fn(p, c):
        n = vnoise(p, scale, seed)
        if n > 1 - amount:
            t = min(1.0, (n - (1 - amount)) / 0.25)
            return mix(c, chip, 0.75 * t)
        return c
    b.paint_fn(fn)


def hazard(b, x0, x1, z, h, y, k=6, depth=0.04):
    """yellow and black stripes painted as thin boxes across [x0, x1] at height z (a door jamb, a kick plate)"""
    w = (x1 - x0) / k
    for i in range(k):
        b.box((x0 + (i + 0.5) * w, y, z + h / 2), (w * 0.98, depth, h), YELLOW if i % 2 == 0 else BLACK)


def rivets(b, pts, y, color, s=0.12):
    for (x, z) in pts:
        b.box((x, y, z), (s, s * 0.6, s), color)


# ── doors ────────────────────────────────────────────────────────────────────
def blast_door(name, seed, open_=True):
    """steel blast door in a heavy frame for an 8 x 8.5 doorway in a 1.2-stud wall; the leaf stands open 95 degrees
    against the wall on the front side, wheel and dogs on its face"""
    P = Prop(name)
    r = rnd(seed)
    pa, me = P("paint"), P("metal")
    W, H, T = 8.0, 8.5, 2.0
    # jambs and header (the frame wraps the wall opening, 0.4 proud each side)
    for s in (-1, 1):
        pa.box((s * (W / 2 + 0.55), 0, (H + 1.1) / 2), (1.1, T, H + 1.1), OLIVE, bevel=0.05)
        hazard(pa, s * (W / 2 + 0.55) - 0.5, s * (W / 2 + 0.55) + 0.5, 0.05, 1.8, -T / 2 - 0.02, k=4)
    pa.box((0, 0, H + 0.55), (W + 2.2, T, 1.1), OLIVE, bevel=0.05)
    rivets(pa, [(x, H + 0.55) for x in (-4.6, -2.3, 0, 2.3, 4.6)], -T / 2 - 0.03, STEEL_D)
    pa.box((0, -T / 2 - 0.03, H + 0.55), (2.2, 0.04, 0.6), mul(OLIVE, 1.25))  # number plate
    me.box((0, 0, 0.06), (W, T, 0.12), STEEL_D)  # threshold sill
    # the leaf
    leaf = Prop(name + "_leaf_tmp")
    lp, lm = leaf("paint"), leaf("metal")
    lw, lh, lt = W + 0.2, H + 0.1, 0.55
    lp.box((0, 0, lh / 2), (lw, lt, lh), mul(OLIVE, 0.95), bevel=0.06)
    for (x, z) in ((-lw / 2 + 0.35, 0.4), (lw / 2 - 0.35, 0.4), (-lw / 2 + 0.35, lh - 0.4), (lw / 2 - 0.35, lh - 0.4)):
        lm.box((x, -lt / 2 - 0.04, z), (0.22, 0.1, 0.22), STEEL_D)
    for z in (1.2, lh / 2, lh - 1.2):  # stiffening ribs
        lp.box((0, -lt / 2 - 0.08, z), (lw - 0.6, 0.16, 0.3), mul(OLIVE, 0.85))
    lm.torus((0, -lt / 2 - 0.45, lh / 2), 0.85, 0.09, STEEL, segU=18, segV=5, rot=(R(90), 0, 0))
    for a in range(4):
        an = a * math.pi / 2 + R(20)
        lm.box((math.cos(an) * 0.42, -lt / 2 - 0.45, lh / 2 + math.sin(an) * 0.42), (0.85, 0.08, 0.08), STEEL, rot=(0, -an, 0))
    lm.cyl((0, -lt / 2, lh / 2), (0, -lt / 2 - 0.45, lh / 2), 0.14, STEEL_D, seg=8)
    for z in (1.0, lh - 1.0):  # dogs on the latch edge
        lm.box((-lw / 2 + 0.2, -lt / 2 - 0.12, z), (0.5, 0.24, 0.25), STEEL_D)
    leaf("rubber").box((lw / 2 - 0.04, 0, lh / 2), (0.08, lt + 0.02, lh - 0.2), RUBBER)  # seal strip
    # swing the leaf open about the hinge at the frame's right inner edge, front side
    ang = R(95) if open_ else 0
    hinge = Vector((W / 2 + 0.05, -T / 2 - lt / 2 - 0.05, 0))
    m = Matrix.Translation(hinge) @ Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation(Vector((-lw / 2, 0, 0)))
    for mat_key, b in leaf.b.items():
        b.transform(m)
        dst = P(mat_key)
        me_tmp = bpy.data.meshes.new("_zr_leaf_tmp")
        b.bm.to_mesh(me_tmp)
        dst.bm.from_mesh(me_tmp)
        bpy.data.meshes.remove(me_tmp)
        b.bm.free()
    # hinge knuckles on the frame
    for z in (1.2, H / 2, H - 1.2):
        me.cyl((W / 2 + 0.25, -T / 2 - 0.3, z - 0.5), (W / 2 + 0.25, -T / 2 - 0.3, z + 0.5), 0.22, STEEL_D, seg=8)
    chipped(pa, OLIVE, RUST, seed, 0.3)
    return P


def door_frame(name, seed):
    """lighter steel frame for an inner 8 x 8.5 doorway: jambs, header with a number plate, kick plates"""
    P = Prop(name)
    pa, me = P("paint"), P("metal")
    W, H, T = 8.0, 8.5, 1.6
    for s in (-1, 1):
        pa.box((s * (W / 2 + 0.25), 0, (H + 0.5) / 2), (0.5, T, H + 0.5), OLIVE_D, bevel=0.03)
        hazard(pa, s * (W / 2 + 0.25) - 0.24, s * (W / 2 + 0.25) + 0.24, 0.05, 1.2, -T / 2 - 0.02, k=3)
    pa.box((0, 0, H + 0.25), (W + 1.0, T, 0.5), OLIVE_D, bevel=0.03)
    me.box((0, -T / 2 - 0.03, H + 0.25), (1.6, 0.04, 0.36), STEEL)
    me.box((0, 0, 0.04), (W, T, 0.08), STEEL_D)
    chipped(pa, OLIVE_D, RUST, seed, 0.28)
    return P


# ── pipes, trays, beams, ducts ───────────────────────────────────────────────
def pipe_run(name, seed, color=PIPE_GREEN, small=PIPE_GREY):
    """16-stud wall run of two pipes on three U-strap brackets (back at +Y = the wall), flanged joints"""
    P = Prop(name)
    r = rnd(seed)
    pa, me = P("paint"), P("metal")
    L = 16.0
    yb, yf = 0.45, -0.2
    for x in (-6.0, 0.0, 6.0):
        me.box((x, yb - 0.05, 0.8), (0.3, 0.12, 1.9), STEEL_D)  # wall plate
        me.box((x, 0.05, 0.25), (0.25, 0.85, 0.12), STEEL_D)  # arm under the big pipe
        me.box((x, 0.05, 1.25), (0.25, 0.85, 0.1), STEEL_D)
    pa.cyl((-L / 2, yf, 0.62), (L / 2, yf, 0.62), 0.36, color, seg=12, smooth=True)
    pa.cyl((-L / 2, yf + 0.1, 1.55), (L / 2, yf + 0.1, 1.55), 0.2, small, seg=10, smooth=True)
    for x in (-L / 2 + 0.15, 3.0, L / 2 - 0.15):  # flanges
        me.cyl((x - 0.12, yf, 0.62), (x + 0.12, yf, 0.62), 0.48, mul(color, 0.8), seg=12)
    chipped(pa, color, RUST, seed, 0.38, 1.2)
    return P


def pipe_valve(name, seed):
    """a pipe drop from the ceiling with a gate valve (red wheel) and a pressure gauge, wall bracketed"""
    P = Prop(name)
    pa, me, pl, gl = P("paint"), P("metal"), P("plastic"), P("glass")
    H = 11.0
    pa.cyl((0, 0, 0.3), (0, 0, H), 0.3, PIPE_GREEN, seg=12, smooth=True)
    me.cyl((0, 0, 0.0), (0, 0, 0.3), 0.5, STEEL_D, seg=12)  # floor flange
    me.cyl((0, 0, 3.6), (0, 0, 4.4), 0.45, STEEL_D, seg=12)  # valve body
    me.cyl((0, 0, 4.4), (0, -0.9, 4.4), 0.12, STEEL, seg=8)
    pa.torus((0, -0.95, 4.4), 0.55, 0.08, RED, segU=14, segV=5, rot=(R(90), 0, 0))
    for a in range(3):
        an = a * 2 * math.pi / 3
        pa.box((math.cos(an) * 0.27, -0.95, 4.4 + math.sin(an) * 0.27), (0.55, 0.06, 0.06), RED, rot=(0, -an, 0))
    me.cyl((0, 0, 6.0), (0, -0.55, 6.0), 0.08, STEEL, seg=6)
    me.cyl((0, -0.55, 6.0), (0, -0.7, 6.0), 0.32, STEEL_D, seg=12)
    pl.cyl((0, -0.7, 6.0), (0, -0.72, 6.0), 0.28, WHITE, seg=12)
    gl.cyl((0, -0.72, 6.0), (0, -0.75, 6.0), 0.28, GLASS, seg=12)
    pl.box((0.08, -0.735, 6.06), (0.03, 0.01, 0.2), BLACK, rot=(0, R(-35), 0))  # needle
    for z in (2.0, 8.0):
        me.box((0, 0.42, z), (0.9, 0.1, 0.25), STEEL_D)
        me.box((0, 0.2, z), (0.12, 0.4, 0.12), STEEL_D)
    chipped(pa, PIPE_GREEN, RUST, seed, 0.4, 1.4)
    return P


def cable_tray(name, seed):
    """16-stud ceiling cable tray (U-channel on hanger rods) with a bundle of cables, some sagging out"""
    P = Prop(name)
    r = rnd(seed)
    me, ru = P("metal"), P("rubber")
    L, Wd = 16.0, 1.4
    me.box((0, 0, 0.04), (L, Wd, 0.08), STEEL)
    for s in (-1, 1):
        me.box((0, s * Wd / 2, 0.25), (L, 0.06, 0.5), STEEL)
    for x in (-6.5, 0.0, 6.5):
        for s in (-1, 1):
            me.cyl((x, s * (Wd / 2 + 0.1), 0.0), (x, s * (Wd / 2 + 0.1), 2.0), 0.05, STEEL_D, seg=6)
        me.box((x, 0, -0.06), (0.12, Wd + 0.4, 0.1), STEEL_D)
    cols = (BLACK, mul(BLACK, 1.8), hexc("3A3A44"), hexc("5A3A2A"), hexc("2E3A2E"))
    for k in range(7):
        y = -Wd / 2 + 0.2 + k * (Wd - 0.4) / 6
        z = 0.18 + (k % 2) * 0.12
        ru.tube([(-L / 2, y, z), (-L / 4, y + r.uniform(-0.05, 0.05), z), (L / 4, y + r.uniform(-0.05, 0.05), z), (L / 2, y, z)], 0.07 + 0.03 * (k % 3), cols[k % len(cols)], seg=5)
    # one cable sagging out of the tray
    ru.tube([(1.0, Wd / 2 - 0.1, 0.3), (2.0, Wd / 2 + 0.3, -0.6), (3.5, Wd / 2 + 0.35, -1.0), (5.0, Wd / 2 + 0.2, -0.5), (6.0, Wd / 2 - 0.1, 0.3)], 0.08, BLACK, seg=5)
    return P


def beam(name, seed):
    """16-stud steel I-beam under the ceiling with end plates and bolts"""
    P = Prop(name)
    pa, me = P("paint"), P("metal")
    L = 16.0
    pa.box((0, 0, 0.06), (L, 0.9, 0.12), OLIVE_D)
    pa.box((0, 0, 1.14), (L, 0.9, 0.12), OLIVE_D)
    pa.box((0, 0, 0.6), (L, 0.12, 1.0), OLIVE_D)
    for x in (-L / 2 + 0.1, L / 2 - 0.1):
        me.box((x, 0, 0.6), (0.2, 1.1, 1.3), STEEL_D)
        for y in (-0.35, 0.35):
            for z in (0.25, 0.95):
                me.cyl((x - 0.12, y, z), (x - 0.22, y, z), 0.07, STEEL, seg=6)
    for x in (-4.0, 0.0, 4.0):  # web stiffeners
        pa.box((x, 0, 0.6), (0.1, 0.8, 1.0), mul(OLIVE_D, 0.9))
    chipped(pa, OLIVE_D, RUST, seed, 0.3, 1.0)
    return P


def duct(name, seed):
    """16-stud rectangular ventilation duct with seams, a grille and hangers (ceiling)"""
    P = Prop(name)
    me = P("metal")
    L = 16.0
    me.box((0, 0, 0.75), (L, 2.0, 1.5), mul(STEEL, 1.1))
    for x in (-6.0, -2.0, 2.0, 6.0):
        me.box((x, 0, 0.75), (0.14, 2.06, 1.56), mul(STEEL, 0.9))  # seams
    me.box((3.5, -1.03, 0.75), (1.6, 0.06, 1.0), STEEL_D)  # grille
    for k in range(5):
        me.box((3.5, -1.07, 0.35 + k * 0.2), (1.5, 0.04, 0.06), STEEL)
    for x in (-5.0, 5.0):
        for s in (-1, 1):
            me.cyl((x, s * 1.1, 0.0), (x, s * 1.1, 2.4), 0.05, STEEL_D, seg=6)
        me.box((x, 0, -0.05), (0.15, 2.4, 0.1), STEEL_D)
    return P


# ── lights and wall fittings ─────────────────────────────────────────────────
def fluoro(name, seed, dead=False):
    """twin-tube fluorescent fitting on short chains: housing, reflector, wire guard; dead: dark tubes, one gone"""
    P = Prop(name)
    me, gl = P("metal"), P("plastic" if dead else "glow")
    L = 4.4
    me.box((0, 0, 0.5), (L, 0.9, 0.18), mul(WHITE, 0.92))
    me.box((0, 0, 0.36), (L - 0.1, 0.8, 0.1), mul(WHITE, 0.8))
    for s in (-1, 1):
        me.box((s * (L / 2 - 0.1), 0, 0.22), (0.12, 0.8, 0.32), mul(WHITE, 0.85))
    tubes = ((-0.2, True), (0.2, not dead))
    for y, on in tubes:
        if on:
            gl.cyl((-L / 2 + 0.2, y, 0.2), (L / 2 - 0.2, y, 0.2), 0.08, WARM if not dead else mul(WHITE, 0.55), seg=8)
    for x in (-1.5, 0.0, 1.5):  # wire guard
        me.box((x, 0, 0.04), (0.04, 0.85, 0.04), STEEL_D)
    for s in (-1, 1):
        me.box((0, s * 0.42, 0.04), (L - 0.3, 0.04, 0.04), STEEL_D)
        me.cyl((s * 1.6, 0, 0.6), (s * 1.6, 0, 1.2), 0.03, STEEL_D, seg=4)  # chains
    return P


def cage_lamp(name, seed, color=WARM):
    """wall bulkhead light: back plate, glass dome, cage bars, a bulb (glow)"""
    P = Prop(name)
    me, gl, gw = P("metal"), P("glass"), P("glow")
    me.box((0, 0.3, 0.6), (0.9, 0.12, 1.2), STEEL_D)
    me.cyl((0, 0.24, 0.6), (0, -0.05, 0.6), 0.42, STEEL_D, seg=12)
    gw.cyl((0, -0.05, 0.6), (0, -0.4, 0.6), 0.18, color, r2=0.12, seg=10)
    gl.cyl((0, -0.05, 0.6), (0, -0.55, 0.6), 0.36, GLASS, r2=0.28, seg=12)
    for a in range(4):
        an = a * math.pi / 4
        me.box((0, -0.32, 0.6), (0.04, 0.55, 0.82), STEEL_D, rot=(0, an, 0))
    return P


def vent(name, seed):
    """wall vent with louvres and a grimy surround (back at +Y)"""
    P = Prop(name)
    me = P("metal")
    W, H = 3.0, 2.0
    me.box((0, 0.1, H / 2), (W, 0.2, H), STEEL_D)
    me.box((0, -0.02, H / 2), (W - 0.3, 0.06, H - 0.3), BLACK)
    for k in range(7):
        me.box((0, -0.06, 0.25 + k * 0.24), (W - 0.35, 0.05, 0.12), STEEL, rot=(R(-30), 0, 0))
    for (x, z) in ((-W / 2 + 0.15, 0.15), (W / 2 - 0.15, 0.15), (-W / 2 + 0.15, H - 0.15), (W / 2 - 0.15, H - 0.15)):
        me.cyl((x, -0.0, z), (x, -0.05, z), 0.06, STEEL, seg=6)
    return P


def junction_box(name, seed):
    """grey junction box with conduits running up the wall"""
    P = Prop(name)
    me, pa = P("metal"), P("paint")
    pa.box((0, 0.25, 0.8), (1.3, 0.5, 1.6), hexc("7E827C"), bevel=0.04)
    me.box((0, -0.02, 0.8), (1.1, 0.04, 1.4), hexc("6E726C"))
    pa.box((0, -0.04, 1.15), (0.5, 0.02, 0.35), YELLOW)  # warning label
    for x in (-0.35, 0.0, 0.35):
        me.cyl((x, 0.3, 1.6), (x, 0.3, 4.2), 0.08, STEEL, seg=6)
    me.cyl((0.2, 0.3, 0.0), (0.2, 0.3, 0.05), 0.08, STEEL, seg=6)
    chipped(pa, hexc("7E827C"), RUST, seed, 0.25, 2.0)
    return P


def fuse_box(name, seed):
    """distribution panel with its door ajar: breakers in rows, a hazard sticker, cables in from the top"""
    P = Prop(name)
    pa, me, pl, ru = P("paint"), P("metal"), P("plastic"), P("rubber")
    W, H, D = 2.4, 3.2, 0.7
    pa.box((0, 0.2, H / 2), (W, D - 0.3, H), hexc("8A8E86"))
    me.box((0, -0.12, H / 2), (W - 0.3, 0.04, H - 0.3), STEEL_D)
    for row in range(4):
        for k in range(8):
            pl.box((-0.85 + k * 0.24, -0.16, 0.6 + row * 0.62), (0.18, 0.08, 0.36), BLACK if (k + row) % 5 else RED)
    # the door, open 70 degrees on its left hinge
    door = Matrix.Translation((-W / 2, -0.15, 0)) @ Matrix.Rotation(R(-70), 4, "Z") @ Matrix.Translation((W / 2, 0.15, 0))
    before = set(pa.bm.verts)
    pa.box((0, -0.18, H / 2), (W, 0.06, H), hexc("8A8E86"))
    pa.box((0.3, -0.22, H - 0.5), (0.5, 0.02, 0.45), YELLOW)
    bmesh.ops.transform(pa.bm, matrix=door, verts=[v for v in pa.bm.verts if v not in before])
    for x in (-0.6, -0.2, 0.3, 0.7):
        ru.tube([(x, 0.25, H), (x, 0.3, H + 0.6), (x + 0.1, 0.4, H + 1.5)], 0.07, BLACK, seg=5)
    chipped(pa, hexc("8A8E86"), RUST, seed, 0.25, 1.8)
    return P


def extinguisher(name, seed):
    """red extinguisher on a wall bracket under a sign plate"""
    P = Prop(name)
    pa, me, pl, ru = P("paint"), P("metal"), P("plastic"), P("rubber")
    pa.cyl((0, -0.1, 0.0), (0, -0.1, 1.9), 0.33, RED, seg=12, smooth=True)
    pa.cyl((0, -0.1, 1.9), (0, -0.1, 2.15), 0.33, RED, r2=0.16, seg=12, smooth=True)
    me.box((0, -0.1, 2.3), (0.16, 0.16, 0.3), STEEL)
    me.box((0.1, -0.15, 2.45), (0.5, 0.08, 0.06), BLACK)
    ru.tube([(-0.12, -0.12, 2.35), (-0.4, -0.3, 2.0), (-0.42, -0.35, 1.2)], 0.05, RUBBER, seg=5)
    me.box((0, 0.28, 1.3), (0.5, 0.08, 0.8), STEEL_D)  # bracket
    pl.box((0, 0.3, 3.0), (0.9, 0.04, 0.9), RED)  # sign plate
    pl.box((0, 0.27, 3.0), (0.5, 0.02, 0.5), WHITE)
    return P


def first_aid(name, seed):
    """white wall cabinet with a green cross, one hinge loose"""
    P = Prop(name)
    pa, pl = P("paint"), P("plastic")
    pa.box((0, 0.2, 0.7), (1.6, 0.4, 1.4), WHITE, bevel=0.03)
    pl.box((0, -0.01, 0.7), (0.9, 0.02, 0.3), GREEN)
    pl.box((0, -0.01, 0.7), (0.3, 0.02, 0.9), GREEN)
    pl.box((0, -0.02, 0.7), (0.62, 0.02, 0.1), WHITE)
    pl.box((0, -0.02, 0.7), (0.1, 0.02, 0.62), WHITE)
    chipped(pa, WHITE, hexc("9A8A6A"), seed, 0.22, 2.5)
    return P


def wall_phone(name, seed):
    """old wall telephone: box, handset on its hook, coiled cord"""
    P = Prop(name)
    pl, me, ru = P("plastic"), P("metal"), P("rubber")
    pl.box((0, 0.15, 0.8), (0.8, 0.3, 1.4), hexc("3A3C38"), bevel=0.05)
    pl.box((0.0, -0.08, 0.85), (0.24, 0.3, 1.2), BLACK, bevel=0.05)
    for k in range(9):
        me.box((0.25, -0.02, 0.55 + (k % 3) * 0.18), (0.08, 0.02, 0.08), WHITE)
    pts = [(0.0, -0.1, 0.2)]
    for k in range(10):
        pts.append((0.08 * math.cos(k * 1.9), -0.12 + 0.08 * math.sin(k * 1.9), 0.2 - k * 0.09))
    ru.tube(pts, 0.03, BLACK, seg=4)
    return P


def speaker(name, seed):
    """PA horn speaker on a wall bracket"""
    P = Prop(name)
    me, pa = P("metal"), P("paint")
    me.box((0, 0.4, 0.3), (0.5, 0.1, 0.6), STEEL_D)
    me.box((0, 0.15, 0.3), (0.1, 0.5, 0.1), STEEL_D)
    pa.cyl((0, 0.0, 0.3), (0, -0.9, 0.0), 0.22, hexc("8A8E86"), r2=0.62, seg=12)
    me.cyl((0, 0.05, 0.32), (0, 0.25, 0.34), 0.25, STEEL_D, seg=10)
    return P


def wall_clock(name, seed):
    """round clock, glass cracked, stopped at twenty past four"""
    P = Prop(name)
    pl, gl, me = P("plastic"), P("glass"), P("metal")
    pl.cyl((0, 0.1, 0.7), (0, -0.05, 0.7), 0.7, BLACK, seg=16)
    pl.cyl((0, -0.05, 0.7), (0, -0.06, 0.7), 0.62, WHITE, seg=16)
    for k in range(12):
        an = k * math.pi / 6
        pl.box((math.sin(an) * 0.52, -0.07, 0.7 + math.cos(an) * 0.52), (0.04, 0.01, 0.1), BLACK, rot=(0, -an, 0))
    me.box((0.12, -0.08, 0.73), (0.04, 0.01, 0.28), BLACK, rot=(0, R(-60), 0))
    me.box((0.0, -0.09, 0.85), (0.03, 0.01, 0.36), BLACK, rot=(0, R(-120), 0))
    gl.cyl((0, -0.08, 0.7), (0, -0.1, 0.7), 0.62, GLASS, seg=16)
    return P


# ── sandbags and rubble ──────────────────────────────────────────────────────
def sandbags(name, seed, w=6.0, rows=4):
    """a wall of sandbags (fabric), bags staggered, slumped, a few split"""
    P = Prop(name)
    r = rnd(seed)
    fa = P("fabric")
    bw, bh, bd = 1.5, 0.62, 1.0
    for row in range(rows):
        n = int(w / bw)
        off = (row % 2) * bw / 2
        for k in range(n - (row % 2)):
            x = -w / 2 + bw / 2 + off + k * bw + r.uniform(-0.06, 0.06)
            for d in (-0.5, 0.5):
                c = mix(SAND, SAND_D, r.random())
                fa.box((x, d * bd * 0.95, bh / 2 + row * bh * 0.92), (bw * 0.96, bd * 0.95, bh), c, rot=(0, r.uniform(-0.05, 0.05), r.uniform(-0.04, 0.04)), bevel=0.14)
    return P


def rubble(name, seed):
    """corner pile of concrete crumbs and a broken block"""
    P = Prop(name)
    r = rnd(seed)
    co = P("concrete")
    chunks(co, r, 0, 0, 1.6, 22, 0.35, CONCRETE)
    co.chunk((0.5, 0.3, 0.3), (1.2, 0.9, 0.6), CONCRETE_D, seed=seed + 3)
    return P


PROPS = {
    "BlastDoor": lambda: blast_door("BlastDoor", 701),
    "DoorFrame": lambda: door_frame("DoorFrame", 702),
    "PipeRun": lambda: pipe_run("PipeRun", 703),
    "PipeRunRust": lambda: pipe_run("PipeRunRust", 704, RUST, PIPE_GREY),
    "PipeValve": lambda: pipe_valve("PipeValve", 705),
    "CableTray": lambda: cable_tray("CableTray", 706),
    "Beam": lambda: beam("Beam", 707),
    "Duct": lambda: duct("Duct", 708),
    "Fluoro": lambda: fluoro("Fluoro", 709),
    "FluoroDead": lambda: fluoro("FluoroDead", 710, dead=True),
    "CageLamp": lambda: cage_lamp("CageLamp", 711),
    "CageLampRed": lambda: cage_lamp("CageLampRed", 712, (1.0, 0.35, 0.25, 1)),
    "Vent": lambda: vent("Vent", 713),
    "JunctionBox": lambda: junction_box("JunctionBox", 714),
    "FuseBox": lambda: fuse_box("FuseBox", 715),
    "Extinguisher": lambda: extinguisher("Extinguisher", 716),
    "FirstAid": lambda: first_aid("FirstAid", 717),
    "WallPhone": lambda: wall_phone("WallPhone", 718),
    "Speaker": lambda: speaker("Speaker", 719),
    "WallClock": lambda: wall_clock("WallClock", 720),
    "Sandbags": lambda: sandbags("Sandbags", 721),
    "SandbagsLow": lambda: sandbags("SandbagsLow", 722, 6.0, 2),
    "Rubble": lambda: rubble("Rubble", 723),
}
BAKE = {
    "PipeRun": dict(ground=False, floor_dirt=0.0, dust=0.28),
    "PipeRunRust": dict(ground=False, floor_dirt=0.0, dust=0.3),
    "CableTray": dict(ground=False, floor_dirt=0.0, dust=0.35),
    "Beam": dict(ground=False, floor_dirt=0.0, dust=0.3),
    "Duct": dict(ground=False, floor_dirt=0.0, dust=0.32),
    "Fluoro": dict(ground=False, floor_dirt=0.0, dust=0.2),
    "FluoroDead": dict(ground=False, floor_dirt=0.0, dust=0.3),
    "CageLamp": dict(ground=False, floor_dirt=0.0),
    "CageLampRed": dict(ground=False, floor_dirt=0.0),
    "Vent": dict(ground=False, floor_dirt=0.0, dust=0.25),
    "JunctionBox": dict(ground=False, floor_dirt=0.0),
    "FuseBox": dict(ground=False, floor_dirt=0.0),
    "Extinguisher": dict(ground=False, floor_dirt=0.0),
    "FirstAid": dict(ground=False, floor_dirt=0.0),
    "WallPhone": dict(ground=False, floor_dirt=0.0),
    "Speaker": dict(ground=False, floor_dirt=0.0),
    "WallClock": dict(ground=False, floor_dirt=0.0),
    "Sandbags": dict(dust=0.12),
    "SandbagsLow": dict(dust=0.12),
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

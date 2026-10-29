"""Zero Return - Meridian Mall kit, batch A: structure and fixtures (M13). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_mall_kit_a.py").read(), g); g["build"](names or None)
   then g["export"]() -> assets/exports/ZR_MallKitA.fbx (+ .blend, .meta.json, .props.json)
Objects live in scene "ZR_MallKit"; the user's scene is never touched. All geometry is original and procedural.

Props (origin bottom-centre unless noted, front toward Blender -Y = Roblox LookVector):
  StoreFront, StoreFrontBroken  16 x 12 aluminium shopfront, centre door opening 4 x 8, transom glass
  Shutter, ShutterHalf, ShutterBent  16 x 12 roller shutter (half: raised to 3.2; bent: lower-left corner
                                pried up into a 4.4 x 6.4 gap)
  Column, ColumnDamaged         2.6 square clad column, 17 tall; the damaged one is spalled to the core with rebar
  CeilingHole, CeilingCollapse  16 x 16 suspended-ceiling modules around a hole (origin at the ceiling plane):
                                T-bar grid, tiles, hanging tiles, cables, insulation, a dangling light, plenum
                                ducts and pipes above
  CeilingDebris                 fallen tiles, insulation, bent T-bar on the floor
  Balustrade, BalustradeBroken  8 long glass balustrade with steel posts and a handrail
  Escalator                     stopped escalator: 3 landing, 31 x 18 incline toward -Y, 3 top landing
  Fountain                      dry atrium fountain (r 9) with an original ring sculpture
  WallBreach                    8 x 9 blockwork wall panel with a knocked-through opening
  SlabCollapse                  a 12 x 24 floor slab fallen at 36 degrees onto rubble, rebar at the break
  BrokenEdge                    12 wide broken slab edge with rebar (hangs below its origin)
  RubbleA, RubbleB, GlassShards floor debris
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
BATCH = "ZR_MallKitA"

ALU = (0.66, 0.67, 0.68, 1)
ALU_D = (0.42, 0.43, 0.44, 1)
GLASS = (0.64, 0.72, 0.73, 1)
STEEL = (0.5, 0.52, 0.53, 1)
STEEL_D = (0.28, 0.29, 0.3, 1)
WHITE = (0.86, 0.86, 0.83, 1)
OFFWHITE = (0.8, 0.79, 0.74, 1)
CONC = (0.62, 0.62, 0.6, 1)
CONC_D = (0.48, 0.48, 0.47, 1)
RUST = hexc("6E4428")
SHUT = (0.6, 0.62, 0.62, 1)
STONE = (0.74, 0.72, 0.68, 1)
STONE_D = (0.5, 0.49, 0.47, 1)
RUBBER = (0.12, 0.12, 0.12, 1)
PLASTER = (0.84, 0.83, 0.79, 1)
INSUL = hexc("C8B26A")
CABLE = [(0.1, 0.1, 0.1, 1), (0.55, 0.12, 0.1, 1), (0.15, 0.2, 0.45, 1), (0.85, 0.8, 0.2, 1)]


def mul(c, k):
    return shade(c, k)


# ── storefronts ───────────────────────────────────────────────────────────────
def storefront(name, broken, seed):
    P = Prop(name)
    r = rnd(seed)
    A, G = P("metal"), P("glass")
    W, H, D = 16.0, 12.0, 0.5
    A.box((0, 0, 0.2), (W, D, 0.4), ALU)
    for x0, x1 in ((-7.85, -2.15), (2.15, 7.85)):
        A.box(((x0 + x1) / 2, 0, 0.75), (x1 - x0, 0.22, 0.7), ALU_D)
    for x in (-7.85, -5.0, -2.15, 2.15, 5.0, 7.85):
        A.box((x, 0, H / 2), (0.3, D, H), ALU)
    A.box((0, 0, 8.2), (W, D, 0.4), ALU)
    A.box((0, 0, H - 0.25), (W, D + 0.1, 0.5), ALU)
    A.box((0, -0.05, 0.02), (4.0, 0.7, 0.04), ALU_D)  # door track (leaves gone)
    for x in (-2.0, 2.0):  # door pivots / stops
        A.box((x, -0.3, 7.85), (0.25, 0.12, 0.3), ALU_D)
    panes = [(-7.7, -5.15), (-4.85, -2.3), (2.3, 4.85), (5.15, 7.7)]
    gone = {0, 2} if broken else set()
    for i, (x0, x1) in enumerate(panes):
        if i in gone:
            broken_pane(G, x0, x1, 1.1, 8.0, GLASS, r)
        else:
            G.box(((x0 + x1) / 2, 0, 4.55), (x1 - x0, 0.08, 6.9), GLASS)
    for x0, x1 in panes[:2] + [(-2.0, 2.0)] + panes[2:]:
        if broken and r.random() < 0.25:
            broken_pane(G, x0, x1, 8.4, 11.5, GLASS, r)
        else:
            G.box(((x0 + x1) / 2, 0, 9.95), (x1 - x0, 0.08, 3.1), GLASS)
    if broken:
        scatter_shards(G, r, -6.4, -1.4, 1.6, 26, GLASS)
        scatter_shards(G, r, 3.6, -1.2, 1.4, 22, GLASS)
        scatter_shards(G, r, -5.0, 1.2, 1.2, 14, GLASS)
    return P


# ── roller shutters ───────────────────────────────────────────────────────────
def shutter(name, kind, seed):
    P = Prop(name)
    r = rnd(seed)
    S, M = P("paint"), P("metal")
    W, HC = 16.0, 11.0
    for x in (-7.85, 7.85):
        M.box((x, 0, HC / 2), (0.4, 0.55, HC), STEEL_D)
    S.box((0, 0.05, HC + 0.55), (16.4, 1.1, 1.1), mul(SHUT, 0.92))

    def curtain(x0, x1, z0, z1, disp_extra=None, rot=(R(90), 0, 0), centre=None):
        ny = max(2, int(round((z1 - z0) / 0.18)))

        def d(u, v):
            z = 0.045 * math.cos(v * ny * math.pi)
            if disp_extra:
                z += disp_extra(u, v)
            return z
        c = centre or ((x0 + x1) / 2, 0, (z0 + z1) / 2)
        S.sheet(c, (x1 - x0, z1 - z0), SHUT, nx=max(2, int((x1 - x0) / 2)), ny=ny, disp=d, rot=rot, thick=0.04)

    if kind == "closed":
        curtain(-7.65, 7.65, 0.2, HC)
        S.box((0, 0, 0.12), (15.3, 0.32, 0.24), STEEL_D)
        M.box((0, -0.22, 0.55), (0.6, 0.12, 0.3), STEEL)  # lock housing
        M.cyl((0, -0.3, 0.55), (0, -0.42, 0.55), 0.08, (0.6, 0.55, 0.3, 1), seg=8)
    elif kind == "half":
        curtain(-7.65, 7.65, 3.4, HC)
        S.box((0, 0, 3.3), (15.3, 0.32, 0.24), STEEL_D)
    else:  # bent: the lower-left corner pried up and folded outward
        curtain(-7.65, 7.65, 6.6, HC)
        curtain(-3.2, 7.65, 0.2, 6.6)
        S.box((2.2, 0, 0.12), (10.8, 0.32, 0.24), STEEL_D)
        # the flap: hinged at z 6.6 and folded out and up ~110 degrees, crumpled
        fx0, fx1, fh = -7.65, -3.2, 6.4
        ny = int(fh / 0.18)

        def crumple(u, v):
            return 0.25 * math.sin(u * 7.1 + v * 3.3) * v + 0.4 * (u - 0.5) ** 2 * v
        m = Matrix.Translation((0, 0, 6.6)) @ Matrix.Rotation(R(-112), 4, "X")
        before = set(S.bm.verts)
        S.sheet(((fx0 + fx1) / 2, 0, -fh / 2), (fx1 - fx0, fh), SHUT, nx=4, ny=ny,
                disp=lambda u, v: 0.045 * math.cos(v * ny * math.pi) + crumple(u, 1 - v), rot=(R(90), 0, 0), thick=0.04)
        S.box(((fx0 + fx1) / 2, 0, -fh + 0.12), (fx1 - fx0, 0.32, 0.24), STEEL_D)  # the flap's bottom bar
        new = [v for v in S.bm.verts if v not in before]
        bmesh.ops.transform(S.bm, matrix=m, verts=new)
        # torn guide and debris under the gap
        M.box((-7.85, -0.35, 2.6), (0.38, 0.5, 5.2), STEEL_D, rot=(R(10), 0, R(-6)))
        chunks(S, r, -5.4, -1.6, 1.4, 5, 0.35, CONC_D)
    return P


# ── columns ────────────────────────────────────────────────────────────────────
def column(name, damaged, seed):
    P = Prop(name)
    r = rnd(seed)
    PL, ST, M = P("plaster"), P("stone"), P("metal")
    H, S = 17.0, 2.4
    ST.box((0, 0, 0.3), (2.9, 2.9, 0.6), STONE_D, bevel=0.05)
    PL.box((0, 0, H - 0.35), (2.7, 2.7, 0.7), mul(PLASTER, 0.95), bevel=0.04)  # capital band
    for sx in (-1, 1):  # steel corner guards
        for sy in (-1, 1):
            M.box((sx * 1.17, sy * 1.17, 1.3), (0.12, 0.12, 1.4), STEEL)
    if not damaged:
        PL.box((0, 0, (H - 0.6 + 0.6) / 2), (S, S, H - 1.3), PLASTER, bevel=0.06)
        return P
    C = P("concrete")
    # cladding: below z 3 and above z 7.4 whole; between, an L-shape with the -x/-y corner gone
    PL.box((0, 0, 1.8), (S, S, 2.4), PLASTER, bevel=0.06)
    PL.box((0, 0, (7.4 + H - 0.7) / 2), (S, S, H - 0.7 - 7.4), PLASTER, bevel=0.06)
    PL.box((0.55, 0, 5.2), (1.3, S, 4.4), PLASTER)
    PL.box((-0.6, 0.6, 5.2), (1.2, 1.2, 4.4), PLASTER)
    # concrete core where the cladding spalled away (jagged)
    C.box((-0.35, -0.35, 5.2), (1.3, 1.3, 4.6), CONC)
    for k in range(9):
        z = 3.0 + k * 0.5
        C.chunk((-1.15 + r.uniform(-0.1, 0.1), -0.4 + r.uniform(-0.4, 0.4), z), (0.4, 0.5, 0.45), CONC, seed=r.randint(0, 99999), rough=0.35)
        C.chunk((-0.4 + r.uniform(-0.4, 0.4), -1.15 + r.uniform(-0.1, 0.1), z), (0.5, 0.4, 0.45), CONC, seed=r.randint(0, 99999), rough=0.35)
    for x, y in ((-1.0, -0.6), (-0.6, -1.0), (-1.0, 0.2), (0.2, -1.0)):
        bend = Vector((r.uniform(-0.3, 0.1), r.uniform(-0.3, 0.1), 0))
        rebar(M, [(x, y, 2.9), (x, y, 4.6), Vector((x, y, 6.0)) + bend * 0.6, Vector((x, y, 7.5)) + bend * 0.2], RUST, r=0.05)
    for z in (3.6, 5.0, 6.4):  # stirrups
        M.tube([(-1.05, -1.05, z), (0.3, -1.05, z), (0.3, 0.3, z)], 0.035, RUST, seg=4)
        M.tube([(-1.05, -1.05, z), (-1.05, 0.3, z)], 0.035, RUST, seg=4)
    chunks(C, r, -1.6, -1.6, 1.2, 9, 0.45, CONC_D)
    chunks(PL, r, -1.8, -1.2, 1.4, 6, 0.4, PLASTER, flat=0.3)
    return P


# ── ceilings ───────────────────────────────────────────────────────────────────
def ceiling(name, collapse, seed):
    """origin at the ceiling plane (z 0 = underside of the tiles); 16 x 16; tiles 2 x 2"""
    P = Prop(name)
    r = rnd(seed)
    M, PL, F, PA, C = P("metal"), P("plaster"), P("fabric"), P("paint"), P("concrete")
    N, T = 8, 2.0
    tile_th = 0.12
    # which tiles are missing (a blob near the middle), which hang
    holes, hangs = set(), []
    cx, cy = r.uniform(-2, 2), r.uniform(-2, 2)
    rad = 4.2 if collapse else 3.0
    for i in range(N):
        for j in range(N):
            x, y = -8 + (i + 0.5) * T, -8 + (j + 0.5) * T
            d = math.hypot(x - cx, y - cy) + r.uniform(-1.2, 1.2)
            if d < rad:
                holes.add((i, j))
    for (i, j) in list(holes):
        if r.random() < (0.3 if collapse else 0.22):
            hangs.append((i, j))
    # T-bar grid (main runners along X every 2; cross tees); bent runners hang down in the collapse
    for j in range(N + 1):
        y = -8 + j * T
        if collapse and abs(y - cy) < 2.5:
            # bent main runner dropping into the hole
            M.tube([(-8, y, 0.02), (cx - 3.2, y, 0.02), (cx - 1.0, y, -1.6), (cx + 1.6, y, -3.2)], 0.05, WHITE, seg=4)
            M.tube([(8, y, 0.02), (cx + 4.4, y, 0.02), (cx + 3.3, y, -0.8)], 0.05, WHITE, seg=4)
            continue
        M.box((0, y, 0.0), (16, 0.08, 0.14), WHITE)
    for i in range(N + 1):
        x = -8 + i * T
        for j in range(N):
            y0 = -8 + j * T
            inside = (i < N and (i, j) in holes) and (i > 0 and (i - 1, j) in holes)
            if inside and r.random() < 0.75:
                continue
            M.box((x, y0 + T / 2, 0.0), (0.08, T, 0.14), WHITE)
    # tiles
    for i in range(N):
        for j in range(N):
            if (i, j) in holes:
                continue
            x, y = -8 + (i + 0.5) * T, -8 + (j + 0.5) * T
            stain = 0.0
            dd = math.hypot(x - cx, y - cy)
            if dd < rad + 2.5:
                stain = (1 - (dd - rad) / 2.5) * 0.25 if dd > rad else 0.25
            col = mix(PLASTER, hexc("8A7452"), max(0.0, stain + r.uniform(-0.03, 0.05)))
            PL.box((x, y, tile_th / 2 + 0.01), (T - 0.1, T - 0.1, tile_th), col)
    # hanging tiles: rotated about one edge
    for (i, j) in hangs:
        x, y = -8 + (i + 0.5) * T, -8 + (j + 0.5) * T
        ang = R(r.uniform(35, 80))
        edge = r.choice(("x", "y"))
        if edge == "x":
            m = Matrix.Translation((x, y - T / 2, 0)) @ Matrix.Rotation(-ang, 4, "X") @ Matrix.Translation((0, T / 2, -tile_th / 2))
        else:
            m = Matrix.Translation((x - T / 2, y, 0)) @ Matrix.Rotation(ang, 4, "Y") @ Matrix.Translation((T / 2, 0, -tile_th / 2))
        loc, rot, _ = m.decompose()
        PL.box(tuple(loc), (T - 0.12, T - 0.12, tile_th), mix(PLASTER, hexc("8A7452"), 0.3), rot=rot.to_euler())
    # plenum above the hole: slab underside, a duct, pipes, a cable tray
    C.box((0, 0, 4.2), (16, 16, 0.3), CONC_D)
    PA.box((cx + 0.5, 0, 2.4), (2.4, 16, 1.6), (0.62, 0.64, 0.64, 1))
    for k in range(8):
        PA.box((cx + 0.5, -8 + k * 2 + 1, 3.45), (0.1, 0.1, 0.6), STEEL_D)
    for dx, rr, col in ((-3.0, 0.22, (0.55, 0.2, 0.15, 1)), (-3.7, 0.16, STEEL), (3.6, 0.28, (0.3, 0.42, 0.3, 1))):
        PA.cyl((cx + dx, -8, 3.2), (cx + dx, 8, 3.2), rr, col, seg=8, smooth=True)
    M.box((cy * 0.3 - 1.8, 0, 3.75), (0.9, 16, 0.12), STEEL)  # cable tray
    # insulation batts and dangling cables / a dangling light fitting
    for k in range(3 if collapse else 2):
        ix, iy = r.uniform(cx - 2.5, cx + 2.5), r.uniform(cy - 2.5, cy + 2.5)
        F.chunk((ix, iy, r.uniform(-0.4, 0.4)), (1.4, 1.0, 0.35), INSUL, seed=r.randint(0, 99999), rough=0.35)
    for k in range(5 if collapse else 3):
        x0, y0 = r.uniform(cx - 3, cx + 3), r.uniform(cy - 3, cy + 3)
        drop = r.uniform(2.0, 4.6)
        pts = [(x0, y0, 3.7), (x0 + r.uniform(-0.3, 0.3), y0 + r.uniform(-0.3, 0.3), 0.5),
               (x0 + r.uniform(-0.6, 0.6), y0 + r.uniform(-0.6, 0.6), -drop * 0.6), (x0 + r.uniform(-0.8, 0.8), y0 + r.uniform(-0.8, 0.8), -drop)]
        M.tube(pts, 0.035, r.choice(CABLE), seg=4)
    # a light fitting hanging by its cables
    lx, ly = cx + r.uniform(-1.5, 1.5), cy + r.uniform(-1.5, 1.5)
    tilt = R(r.uniform(25, 60))
    M.box((lx, ly, -2.2), (1.9, 3.9, 0.22), WHITE, rot=(tilt, 0, R(r.uniform(-30, 30))))
    for s in (-1, 1):
        M.tube([(lx + s * 0.6, ly + s * 1.5, 0.3), (lx + s * 0.6, ly + s * 1.2, -1.2), (lx + s * 0.5, ly + s * 0.9, -2.0)], 0.025, CABLE[0], seg=4)
    return P


def ceiling_debris(name, seed):
    P = Prop(name)
    r = rnd(seed)
    PL, F, M = P("plaster"), P("fabric"), P("metal")
    for k in range(10):
        a, d = r.uniform(0, 6.283), r.uniform(0, 3.2)
        x, y = math.cos(a) * d, math.sin(a) * d
        if r.random() < 0.6:
            PL.box((x, y, 0.08 + k * 0.012), (r.uniform(0.6, 2.0), r.uniform(0.6, 2.0), 0.1), mix(PLASTER, hexc("8A7452"), r.uniform(0, 0.3)),
                   rot=(R(r.uniform(-8, 8)), R(r.uniform(-8, 8)), r.uniform(0, 6.28)))
        else:
            PL.chunk((x, y, 0.1), (r.uniform(0.3, 0.8), r.uniform(0.3, 0.7), 0.12), PLASTER, seed=r.randint(0, 99999), rough=0.4)
    for k in range(2):
        F.chunk((r.uniform(-2, 2), r.uniform(-2, 2), 0.18), (1.4, 1.0, 0.3), INSUL, seed=r.randint(0, 99999), rough=0.4)
    for k in range(3):
        a = r.uniform(0, 6.28)
        p0 = Vector((r.uniform(-2, 2), r.uniform(-2, 2), 0.06))
        d = Vector((math.cos(a), math.sin(a), 0))
        M.tube([p0, p0 + d * 1.4 + Vector((0, 0, 0.1)), p0 + d * 2.6 + Vector((0.3, 0.2, 0.05))], 0.045, WHITE, seg=4)
    chunks(PL, r, 0, 0, 3.4, 14, 0.18, PLASTER, flat=0.4)
    return P


# ── balustrades ────────────────────────────────────────────────────────────────
def balustrade(name, broken, seed):
    """8 long along X, 3.6 tall; the glass sits in a floor channel; handrail on top"""
    P = Prop(name)
    r = rnd(seed)
    M, G, C = P("metal"), P("glass"), P("chrome")
    L, H = 8.0, 3.6
    M.box((0, 0, 0.18), (L, 0.5, 0.36), STEEL_D)
    for x in (-L / 2 + 0.15, L / 2 - 0.15):
        M.box((x, 0, H / 2), (0.22, 0.22, H), STEEL)
    C.cyl((-L / 2, 0, H), (L / 2, 0, H), 0.16, (0.72, 0.73, 0.74, 1), seg=10, smooth=True)
    if broken:
        broken_pane(G, -L / 2 + 0.3, L / 2 - 0.3, 0.36, H - 0.3, GLASS, r)
        scatter_shards(G, r, r.uniform(-2, 2), -1.2, 1.8, 30, GLASS)
        scatter_shards(G, r, r.uniform(-2, 2), 1.0, 1.2, 12, GLASS)
    else:
        G.box((0, 0, (0.36 + H - 0.3) / 2), (L - 0.5, 0.1, H - 0.66), GLASS)
    return P


# ── escalator ──────────────────────────────────────────────────────────────────
def escalator(name, seed):
    """origin: bottom comb plate centre at the floor; rises toward -Y: landing 3, incline 31 x 18, landing 3"""
    P = Prop(name)
    r = rnd(seed)
    M, G, RB, C = P("metal"), P("glass"), P("rubber"), P("chrome")
    LB, RUN, RISE, LT = 3.0, 31.0, 18.0, 3.0
    W_STEP, W_ALL = 3.6, 5.4
    y_b0, y_b1 = 0.0, -LB
    y_t0, y_t1 = -LB - RUN, -LB - RUN - LT
    slope = RISE / RUN

    def zline(y):  # step nosing line
        if y > y_b1:
            return 0.0
        if y < y_t0:
            return RISE
        return (y_b1 - y) * slope
    # landings (comb plates and floor plates)
    M.box((0, (y_b0 + y_b1) / 2, 0.06), (W_STEP + 0.4, LB, 0.12), STEEL)
    M.box((0, (y_t0 + y_t1) / 2, RISE + 0.06), (W_STEP + 0.4, LT, 0.12), STEEL)
    # steps: tread + riser
    n = int(RUN / 1.3)
    for k in range(n):
        y0 = y_b1 - k * (RUN / n)
        z = zline(y0 - RUN / n)
        M.box((0, y0 - RUN / n / 2, z - 0.06), (W_STEP, RUN / n, 0.12), mul(STEEL_D, 1.2))
        M.box((0, y0 - 0.03, z - RISE / n / 2), (W_STEP, 0.06, RISE / n), STEEL_D)
        M.box((0, y0 - 0.1, z + 0.005), (W_STEP, 0.14, 0.02), hexc("A88A2E"))  # yellow nosing strip
    # truss: sloped box under the steps and the end pits
    L = math.hypot(RUN, RISE)
    ang = math.atan2(RISE, RUN)
    mid = Vector((0, (y_b1 + y_t0) / 2, RISE / 2 - 2.2))
    M.box(tuple(mid), (W_ALL, L + 0.5, 2.0), STEEL, rot=(-ang, 0, 0))
    M.box((0, (y_t0 + y_t1) / 2 - 0.2, RISE - 1.4), (W_ALL, LT + 0.6, 2.8), STEEL)
    # side cladding panels (brushed) and skirts
    for s in (-1, 1):
        x = s * (W_ALL / 2 - 0.1)
        M.box((x, mid.y, RISE / 2 - 1.2), (0.2, L + 0.6, 2.6), (0.7, 0.71, 0.72, 1), rot=(-ang, 0, 0))
        M.box((s * (W_STEP / 2 + 0.15), mid.y, RISE / 2 + 0.25), (0.3, L, 0.5), STEEL_D, rot=(-ang, 0, 0))
        M.box((s * (W_STEP / 2 + 0.15), (y_b0 + y_b1) / 2, 0.25), (0.3, LB, 0.5), STEEL_D)
        M.box((s * (W_STEP / 2 + 0.15), (y_t0 + y_t1) / 2, RISE + 0.25), (0.3, LT, 0.5), STEEL_D)
    # balustrade glass (a long parallelogram per side) and the handrail
    HR = 3.3
    for s in (-1, 1):
        x = s * (W_STEP / 2 + 0.15)
        pts = [(x, y_b1 + 0.6, 0.5), (x, y_t0 - 0.6, RISE + 0.5), (x, y_t0 - 0.6, RISE + HR - 0.2), (x, y_b1 + 0.6, HR - 0.2)]
        if s < 0:
            pts = list(reversed(pts))
        G.face(pts, GLASS, double=True)
        # newel ends (rounded) at both landings
        for (ya, za, d) in ((y_b1 + 0.6, 0.0, 1), (y_t0 - 0.6, RISE, -1)):
            G.face([(x, ya, za + 0.5), (x, ya + d * 1.6, za + 0.5), (x, ya + d * 1.6, za + HR - 0.2), (x, ya, za + HR - 0.2)], GLASS, double=True)
        rail = [(x, y_b1 + 2.4, HR - 0.25), (x, y_b1 + 2.2, HR), (x, y_b1 + 0.6, HR), (x, y_t0 - 0.6, RISE + HR), (x, y_t0 - 2.2, RISE + HR), (x, y_t0 - 2.4, RISE + HR - 0.25)]
        RB.tube(rail, 0.13, RUBBER, seg=8)
        C.box((x, y_b1 + 1.4, 0.3), (0.32, 3.4, 0.6), (0.7, 0.71, 0.72, 1))
        C.box((x, y_t0 - 1.4, RISE + 0.3), (0.32, 3.4, 0.6), (0.7, 0.71, 0.72, 1))
    # damage: a missing step and a cracked glass panel shard pile at the bottom
    scatter_shards(G, r, 1.0, 1.2, 1.0, 10, GLASS)
    return P


# ── fountain ───────────────────────────────────────────────────────────────────
def fountain(name, seed):
    P = Prop(name)
    r = rnd(seed)
    ST, T, M, C = P("stone"), P("tile"), P("paint"), P("concrete")
    RO, WALL_T, HW = 9.0, 0.9, 1.6
    seg = 28
    for k in range(seg):  # wall ring as segments with a coping lip
        a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        am = (a0 + a1) / 2
        rm = RO - WALL_T / 2
        chord = 2 * RO * math.sin(math.pi / seg) + 0.05
        ST.box((math.cos(am) * rm, math.sin(am) * rm, HW / 2), (WALL_T, chord, HW), STONE, rot=(0, 0, am))
        ST.box((math.cos(am) * (rm + 0.05), math.sin(am) * (rm + 0.05), HW + 0.12), (WALL_T + 0.35, chord + 0.04, 0.24),
               mul(STONE, 1.05 if k % 7 else 0.85), rot=(0, 0, am))
    # basin floor (tiles), slight dirt
    T.cyl((0, 0, 0.0), (0, 0, 0.35), RO - WALL_T + 0.05, (0.42, 0.55, 0.58, 1), seg=seg)
    # central plinth and the sculpture: two interlocking steel ring arcs (an original "meridian" motif)
    ST.cyl((0, 0, 0.35), (0, 0, 2.7), 2.2, STONE_D, seg=16)
    ST.cyl((0, 0, 2.7), (0, 0, 3.0), 2.5, STONE, seg=16)
    M.torus((0, 0, 7.6), 4.4, 0.32, (0.42, 0.46, 0.44, 1), segU=32, segV=8, rot=(R(90), R(18), 0))
    M.torus((0, 0, 7.0), 3.4, 0.24, (0.6, 0.5, 0.32, 1), segU=28, segV=8, rot=(R(90), R(-24), R(64)))
    M.cyl((0, 0, 3.0), (0, 0, 3.6), 0.5, STEEL_D, seg=10)
    # rust streaks on the plinth and dried leaves / grime in the basin
    for k in range(5):
        a = r.uniform(0, 6.28)
        C.chunk((math.cos(a) * r.uniform(3, 7), math.sin(a) * r.uniform(3, 7), 0.42), (r.uniform(0.6, 1.4), r.uniform(0.5, 1.2), 0.08),
                hexc("4E4232"), seed=r.randint(0, 9999), rough=0.4)
    chunks(C, r, -4.5, 3.0, 1.5, 6, 0.4, CONC_D, zbase=0.35)
    return P


# ── wall breach ────────────────────────────────────────────────────────────────
def wall_breach(name, seed):
    """8 wide x 9 tall x 0.8 blockwork panel (origin bottom-centre) with an irregular opening ~4 x 6.5"""
    P = Prop(name)
    r = rnd(seed)
    C, PL = P("concrete"), P("plaster")
    W, H, T = 8.0, 9.0, 0.8
    bw, bh = 1.33, 0.66
    hole = [(-1.9, 0), (1.7, 0), (2.2, 2.0), (1.6, 4.4), (1.9, 5.6), (0.6, 6.7), (-0.8, 6.4), (-1.6, 5.2), (-2.3, 3.0)]

    def inside(x, z):
        c = False
        n = len(hole)
        for i in range(n):
            x1, z1 = hole[i]
            x2, z2 = hole[(i + 1) % n]
            if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1 + 1e-9) + x1:
                c = not c
        return c
    rows = int(H / bh)
    for j in range(rows):
        off = (j % 2) * bw / 2
        x = -W / 2 - off
        while x < W / 2:
            x0, x1 = max(x, -W / 2), min(x + bw, W / 2)
            if x1 - x0 > 0.05:
                cx, cz = (x0 + x1) / 2, j * bh + bh / 2
                if not inside(cx, cz):
                    edge = any(inside(cx + dx, cz + dz) for dx, dz in ((0.9, 0), (-0.9, 0), (0, 0.6), (0, -0.6)))
                    col = mix(CONC, (0.55, 0.53, 0.5, 1), r.uniform(0, 0.4))
                    if edge and r.random() < 0.6:
                        C.chunk((cx, r.uniform(-0.1, 0.1), cz), (x1 - x0 - 0.06, T * r.uniform(0.6, 1.0), bh - 0.05), col, seed=r.randint(0, 99999), rough=0.25)
                    else:
                        C.box((cx, 0, cz), (x1 - x0 - 0.03, T, bh - 0.03), col)
            x += bw
    # plaster skins on both faces with a ragged edge (wider than the hole), as strips
    for side in (-1, 1):
        y = side * (T / 2 + 0.03)
        for j in range(int(H / 0.5)):
            z0 = j * 0.5
            # find the hole span at this height, widened by the spall
            xs = [x / 20 for x in range(-80, 81)]
            cut = [x for x in xs if inside(x * 0.8, z0 + 0.25) or inside(x, z0 + 0.25)]
            if cut:
                a, b = min(cut) - r.uniform(0.2, 0.7), max(cut) + r.uniform(0.2, 0.7)
                if a > -W / 2:
                    PL.box(((-W / 2 + a) / 2, y, z0 + 0.25), (a + W / 2, 0.06, 0.5), PLASTER)
                if b < W / 2:
                    PL.box(((b + W / 2) / 2, y, z0 + 0.25), (W / 2 - b, 0.06, 0.5), PLASTER)
            else:
                PL.box((0, y, z0 + 0.25), (W, 0.06, 0.5), PLASTER)
    chunks(C, r, 0.2, -1.4, 1.6, 12, 0.5, CONC)
    chunks(C, r, -0.4, 1.3, 1.3, 8, 0.45, CONC)
    chunks(PL, r, 0.0, -1.0, 2.0, 8, 0.35, PLASTER, flat=0.3)
    return P


# ── collapsed slab, broken edges, rubble ───────────────────────────────────────
def slab_collapse(name, seed):
    """a 12 x 24 slab lying from its top edge (y = -20, z = 17) down to a rubble pile (y = 0, z ~3): the top face
    is the floor finish (stone, terrazzo in game), the rest concrete; rebar at both broken edges"""
    P = Prop(name)
    r = rnd(seed)
    C, ST, M = P("concrete"), P("stone"), P("metal")
    Wd, L, T = 12.0, 24.0, 1.2
    top = Vector((0, -20.0, 17.0))
    bot = Vector((0, 0.0, 3.0))
    d = (top - bot)
    L = d.length
    ang = math.atan2(d.z, -d.y)
    mid = (top + bot) / 2
    C.box(tuple(mid), (Wd, L, T), CONC, rot=(-ang, 0, 0))
    nrm = Vector((0, math.sin(ang), math.cos(ang)))
    ST.box(tuple(mid + nrm * (T / 2 + 0.03)), (Wd - 0.1, L - 0.2, 0.06), STONE, rot=(-ang, 0, 0))
    # cracks across the finish (darker strips)
    for k in range(4):
        t = r.uniform(0.15, 0.85)
        p = bot + d * t + nrm * (T / 2 + 0.07)
        ST.box(tuple(p), (Wd - 0.2, 0.08, 0.02), STONE_D, rot=(-ang, 0, r.uniform(-0.2, 0.2)))
    # broken edges: jagged chunks and rebar at both ends
    for end, sgn in ((top, -1), (bot, 1)):
        for k in range(10):
            x = -Wd / 2 + (k + 0.5) * Wd / 10
            C.chunk(tuple(end + Vector((x, 0, 0)) + Vector((0, math.cos(ang), -math.sin(ang))) * 0.0), (1.3, 1.0, 1.4), CONC_D, seed=r.randint(0, 99999), rough=0.35)
        for k in range(7):
            x = -Wd / 2 + 0.8 + k * (Wd - 1.6) / 6
            dirv = Vector((0, -math.cos(ang), math.sin(ang))) * (-sgn)
            p0 = end + Vector((x, 0, 0))
            bend = Vector((r.uniform(-0.4, 0.4), 0, -r.uniform(0.2, 0.9)))
            rebar(M, [p0 - dirv * 0.6, p0 + dirv * r.uniform(0.6, 1.4), p0 + dirv * r.uniform(1.6, 2.6) + bend], RUST, r=0.06)
    # rubble pile under the low end
    for k in range(26):
        a, dd = r.uniform(0, 6.28), 4.2 * math.sqrt(r.random())
        x, y = math.cos(a) * dd * 1.4, math.sin(a) * dd * 0.9 + 1.0
        s = r.uniform(0.5, 1.4)
        z = max(0.2, 3.0 * (1 - dd / 4.4)) * r.uniform(0.4, 1.0)
        C.chunk((x, y, z * 0.6 + s * 0.2), (s * 1.3, s, s * 0.7), mix(CONC, CONC_D, r.random()), seed=r.randint(0, 99999), rough=0.32)
    chunks(C, r, 0, 2.5, 5.5, 18, 0.35, CONC_D)
    return P


def broken_edge(name, seed):
    """the broken edge of a floor slab: origin at the top of the slab edge, centre of a 12 wide run along X; the
    break hangs toward -Y (into the hole) and down"""
    P = Prop(name)
    r = rnd(seed)
    C, M = P("concrete"), P("metal")
    Wd, T = 12.0, 1.0
    for k in range(14):
        x = -Wd / 2 + (k + 0.5) * Wd / 14
        C.chunk((x, r.uniform(-0.6, 0.0), -T / 2 + r.uniform(-0.2, 0.15)), (0.95, r.uniform(0.6, 1.3), T * r.uniform(0.8, 1.2)), CONC_D,
                seed=r.randint(0, 99999), rough=0.32)
    for k in range(9):
        x = -Wd / 2 + 0.6 + k * (Wd - 1.2) / 8
        drop = r.uniform(0.6, 2.6)
        rebar(M, [(x, 0.4, -0.3), (x, -0.7, -0.35), (x + r.uniform(-0.4, 0.4), -1.6, -0.35 - drop * 0.5), (x + r.uniform(-0.6, 0.6), -2.0, -0.4 - drop)], RUST, r=0.055)
    return P


def rubble(name, seed, w, h, n):
    P = Prop(name)
    r = rnd(seed)
    C, M = P("concrete"), P("metal")
    C.face([(math.cos(t) * w * 0.55, math.sin(t) * w * 0.45, 0.012) for t in [k * 2 * math.pi / 12 for k in range(12)]], CONC_D)
    for k in range(n):
        a, d = r.uniform(0, 6.28), math.sqrt(r.random())
        x, y = math.cos(a) * d * w * 0.5, math.sin(a) * d * w * 0.4
        s = r.uniform(0.3, 1.0) * (1.2 - d * 0.6) * (w / 4)
        z = (1 - d) * h * r.uniform(0.3, 0.9)
        C.chunk((x, y, z * 0.7 + s * 0.25), (s * 1.3, s, s * 0.7), mix(CONC, CONC_D, r.random()), seed=r.randint(0, 99999), rough=0.3)
    for k in range(3):
        a = r.uniform(0, 6.28)
        p0 = Vector((r.uniform(-w / 4, w / 4), r.uniform(-w / 5, w / 5), h * 0.4))
        rebar(M, [p0, p0 + Vector((math.cos(a), math.sin(a), 0.2)) * w * 0.25, p0 + Vector((math.cos(a) * w * 0.4, math.sin(a) * w * 0.4, -h * 0.2))], RUST, r=0.05)
    return P


def glass_shards(name, seed):
    P = Prop(name)
    r = rnd(seed)
    G = P("glass")
    scatter_shards(G, r, 0, 0, 2.2, 60, GLASS)
    scatter_shards(G, r, 0.8, 0.4, 0.9, 25, GLASS)
    return P


PROPS = {
    "StoreFront": lambda: storefront("StoreFront", False, 11),
    "StoreFrontBroken": lambda: storefront("StoreFrontBroken", True, 12),
    "Shutter": lambda: shutter("Shutter", "closed", 21),
    "ShutterHalf": lambda: shutter("ShutterHalf", "half", 22),
    "ShutterBent": lambda: shutter("ShutterBent", "bent", 23),
    "Column": lambda: column("Column", False, 31),
    "ColumnDamaged": lambda: column("ColumnDamaged", True, 32),
    "CeilingHole": lambda: ceiling("CeilingHole", False, 41),
    "CeilingCollapse": lambda: ceiling("CeilingCollapse", True, 42),
    "CeilingDebris": lambda: ceiling_debris("CeilingDebris", 43),
    "Balustrade": lambda: balustrade("Balustrade", False, 51),
    "BalustradeBroken": lambda: balustrade("BalustradeBroken", True, 52),
    "Escalator": lambda: escalator("Escalator", 61),
    "Fountain": lambda: fountain("Fountain", 71),
    "WallBreach": lambda: wall_breach("WallBreach", 81),
    "SlabCollapse": lambda: slab_collapse("SlabCollapse", 91),
    "BrokenEdge": lambda: broken_edge("BrokenEdge", 92),
    "RubbleA": lambda: rubble("RubbleA", 93, 4.0, 1.2, 22),
    "RubbleB": lambda: rubble("RubbleB", 94, 8.0, 2.6, 40),
    "GlassShards": lambda: glass_shards("GlassShards", 95),
}
# per-prop bake settings (ceiling modules hang from their origin: no floor plane)
BAKE = {
    "CeilingHole": dict(ground=False, floor_dirt=0.0, dust=0.0, ao_dist=1.6),
    "CeilingCollapse": dict(ground=False, floor_dirt=0.0, dust=0.0, ao_dist=1.6),
    "BrokenEdge": dict(ground=False, floor_dirt=0.0),
    "Escalator": dict(ao_dist=2.6),
    "SlabCollapse": dict(ao_dist=2.4, floor_dirt=0.1),
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


def build(names=None):
    scn = scene()
    out = {}
    for nm in (names or list(PROPS)):
        clear("ZR_MK_%s__" % nm)
        P = PROPS[nm]()
        objs = P.finish(scn.collection, **BAKE.get(nm, {}))
        out[nm] = sum(len(o.data.polygons) for o in objs)
    return out


def objects():
    keys = set(PROPS)
    return [o for o in scene().collection.objects if o.name.startswith("ZR_MK_") and o.name[6:].split("__")[0] in keys]


def export():
    objs = objects()
    fbx, meta, props = kit_export(objs, BATCH, scene())
    return fbx, len(objs), props


def preview(out_png=None, cols=5):
    out_png = out_png or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "build", BATCH + "_preview.png")
    return contact_sheet(objects(), out_png, cols=cols)


def turn(nm, out_png=None, **kw):
    out_png = out_png or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "build", "kit_%s.png" % nm)
    return turntable([o for o in objects() if o.name.startswith("ZR_MK_%s__" % nm)], out_png, **kw)

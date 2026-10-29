"""Zero Return - item models A: weapons, weapon mods, magazines, ammunition, grenades, repair kit.
Original designs (fictional guns built from generic parts), modelled in metres (zr_items.U scales to studs).
Guns: barrel along -Y, top +Z, pistol grip at the origin; icons show the left side, muzzle to the left.
"""
import math, random
from mathutils import Vector, Matrix
from zr_items import col, mixc, shade, rbox, label_band, cyl_x, cyl_y, cyl_z, R
from zr_item_reg import item

GUN = col("26292A")       # dark receiver steel
GUN2 = col("33373A")      # lighter steel
BLUE = col("1F2326")      # blued barrel
POLY = col("4E5650")      # olive-grey polymer
POLY_D = col("2C3030")    # black polymer
WOOD = col("6A4A31")
WOOD_D = col("4E3523")
TAN = col("7C6E52")
BRASS = col("B8903E")
COPPER = col("B0653A")
STEEL = col("8C9290")


# ── gun parts ──────────────────────────────────────────────────────────────────
def rail(b, y0, y1, z, w=0.022, color=GUN, slots=True):
    """Picatinny-style top rail: a base strip and raised teeth"""
    b.box((0, (y0 + y1) / 2, z + 0.004), (w, abs(y1 - y0), 0.008), color, bevel=0.001)
    if slots:
        n = int(abs(y1 - y0) / 0.01)
        for k in range(n):
            y = min(y0, y1) + 0.005 + k * 0.01
            b.box((0, y, z + 0.0105), (w * 1.05, 0.0055, 0.005), color, bevel=0.0008)


def barrel(b, y0, y1, r, color=BLUE, seg=14):
    cyl_y(b, 0, y0, y1, 0, r, color, seg=seg)


def flash_hider(b, y, r, color=GUN, length=0.055):
    cyl_y(b, 0, y, y - length, 0, r, color, seg=12)
    for k in range(4):  # slots
        a = k * math.pi / 2 + math.pi / 4
        b.box((math.cos(a) * r * 0.98, y - length * 0.55, math.sin(a) * r * 0.98), (0.004, length * 0.6, 0.004), shade(color, 0.4),
              rot=(0, a, 0))


def pistol_grip(b, y, z_top, color, rake=16, h=0.115, w=0.031, d=0.042):
    m = Matrix.Translation((0, y, z_top)) @ Matrix.Rotation(R(-rake), 4, "X")
    bf = set(b.bm.verts)
    b.box((0, 0, -h / 2), (w, d, h), color, bevel=0.006)
    for k in range(3):  # finger grooves
        b.box((0, -d / 2 - 0.001, -0.025 - k * 0.028), (w * 0.9, 0.006, 0.012), shade(color, 0.85), bevel=0.002)
    import bmesh
    bmesh.ops.transform(b.bm, matrix=m, verts=[v for v in b.bm.verts if v not in bf])


def trigger_guard(b, y0, y1, z, color=GUN):
    b.tube([(0, y0, z), (0, y0, z - 0.03), (0, (y0 + y1) / 2, z - 0.036), (0, y1, z - 0.024), (0, y1, z)], 0.0035, color, seg=6)
    b.box((0, (y0 + y1) / 2 + 0.008, z - 0.012), (0.004, 0.006, 0.02), shade(color, 1.3))  # trigger


def mag_profile(length, depth, curve, n=10):
    """side profile (y, z) of a box magazine hanging down from (0, 0): its spine bends forward (-Y) by `curve`
    degrees over its length; counter-clockwise seen from +X"""
    th = R(curve)
    sp = []
    for k in range(n + 1):
        t = k / n
        if th > 1e-4:
            rc = length / th
            a = th * t
            y, z = -rc * (1 - math.cos(a)), -rc * math.sin(a)
        else:
            a, y, z = 0.0, 0.0, -length * t
        sp.append((y, z, math.cos(a), -math.sin(a), a))
    front = [(y - ny * depth / 2, z - nz * depth / 2) for y, z, ny, nz, _ in sp]
    back = [(y + ny * depth / 2, z + nz * depth / 2) for y, z, ny, nz, _ in sp]
    return front + list(reversed(back)), sp


def box_mag(b, y_top, z_top, length=0.2, width=0.026, depth=0.062, curve=6, color=GUN2, ribs=True, plate=None):
    """one smooth box magazine hanging from (y_top, z_top), curving forward; a base plate and two ribs"""
    import bmesh
    prof, sp = mag_profile(length, depth, curve)
    b.prism([(y_top + y, z_top + z) for y, z in prof], -width / 2, width / 2, color, bevel=0.0028)

    def strip(t, h, grow, c):
        k = min(len(sp) - 1, int(round(t * (len(sp) - 1))))
        y, z, ny, nz, a = sp[k]
        bf = set(b.bm.verts)
        b.box((0, 0, 0), (width + grow, depth + grow, h), c, bevel=0.002)
        m = Matrix.Translation((0, y_top + y, z_top + z)) @ Matrix.Rotation(a, 4, "X")
        bmesh.ops.transform(b.bm, matrix=m, verts=[v for v in b.bm.verts if v not in bf])

    if ribs:
        strip(0.32, 0.008, 0.004, shade(color, 0.92))
        strip(0.64, 0.008, 0.004, shade(color, 0.92))
    strip(0.985, 0.016, 0.008, plate or shade(color, 0.78))


def side_details(b, y, z, color=GUN):
    """selector lever and screws on the left side (+X)"""
    cyl_x(b, 0.026, 0.031, y, z, 0.007, color, seg=10)
    b.box((0.031, y - 0.012, z + 0.004), (0.004, 0.026, 0.006), shade(color, 1.2), rot=(R(20), 0, 0), bevel=0.0015)


def sling_loop(b, y, z, color=GUN):
    b.tube([(0.0, y - 0.008, z), (0.0, y - 0.008, z - 0.012), (0.0, y + 0.008, z - 0.012), (0.0, y + 0.008, z)], 0.0022, color, seg=5)


# ── weapons ────────────────────────────────────────────────────────────────────
def grip_prism(b, color, y=0.0, z=-0.055, rake=16, h=0.118, w=0.031, d=0.044, grooves=3):
    """pistol grip side profile with finger grooves on the front strap, raked back by `rake` degrees"""
    t = math.tan(R(rake))
    pts = [(y - d / 2, z)]
    for k in range(grooves):
        z0 = z - 0.018 - k * 0.03
        pts += [(y - d / 2 + t * (z - z0), z0), (y - d / 2 + t * (z - z0 + 0.012) - 0.004, z0 - 0.012)]
    zb = z - h
    pts += [(y - d / 2 + t * h + 0.004, zb), (y + d / 2 + t * h, zb + 0.004), (y + d / 2, z)]
    # counter-clockwise seen from +X (y right): we walked down the front and up the back, i.e. clockwise
    b.prism(list(reversed(pts)), -w / 2, w / 2, color, bevel=0.004)


def stock_prism(b, color, y0, z_top=0.04, length=0.17, h=0.09, w=0.046):
    pts = [(y0, z_top), (y0 + length, z_top), (y0 + length + 0.004, z_top - h), (y0 + length - 0.05, z_top - h + 0.01),
           (y0 + 0.03, z_top - 0.045), (y0, z_top - 0.03)]
    b.prism(list(reversed(pts)), -w / 2, w / 2, color, bevel=0.006)


@item("R17_RIFLE", 5, 2, view="left", margin=0.06)
def r17(I):
    g, p, s, r = I("gunmetal"), I("polymer"), I("metal"), I("rubber")
    # lower and upper receiver
    g.box((0, -0.06, -0.03), (0.05, 0.26, 0.06), GUN, bevel=0.004)
    g.box((0, -0.11, 0.028), (0.054, 0.42, 0.058), GUN2, bevel=0.004)
    g.box((0.0275, -0.02, 0.03), (0.002, 0.07, 0.022), shade(GUN, 0.55), bevel=0.001)  # bolt-carrier window
    g.box((0.027, 0.03, -0.012), (0.004, 0.018, 0.026), shade(GUN, 1.25), bevel=0.002)  # bolt catch
    cyl_x(g, 0.025, 0.029, -0.09, -0.04, 0.0055, shade(GUN, 1.3), seg=10)  # magazine release
    for yy in (-0.03, 0.012):
        cyl_x(g, 0.025, 0.0275, yy, -0.04, 0.0028, shade(GUN, 1.4), seg=8)  # trigger pins
    rail(g, 0.09, -0.32, 0.057)
    g.box((0, 0.105, 0.05), (0.04, 0.02, 0.012), GUN, bevel=0.002)  # charging handle
    # handguard with vents and its own rail
    p.box((0, -0.475, 0.012), (0.066, 0.31, 0.074), POLY, bevel=0.01)
    for k in range(6):
        p.box((0.0335, -0.36 - k * 0.042, 0.012), (0.004, 0.026, 0.026), shade(POLY, 0.4), bevel=0.004)
    rail(g, -0.33, -0.62, 0.05, w=0.02)
    # gas block, barrel, front sight, flash hider
    barrel(s, -0.62, -0.84, 0.0095)
    g.box((0, -0.655, 0.0), (0.03, 0.03, 0.03), GUN, bevel=0.003)
    g.box((0, -0.61, 0.085), (0.008, 0.012, 0.055), GUN, bevel=0.0015)
    g.box((0, -0.61, 0.061), (0.026, 0.018, 0.012), GUN, bevel=0.002)
    flash_hider(g, -0.84, 0.012)
    # rear sight
    g.box((0, 0.05, 0.08), (0.026, 0.024, 0.028), GUN, bevel=0.003)
    g.box((0, 0.05, 0.097), (0.012, 0.01, 0.012), shade(GUN, 0.7))
    # grip, trigger guard, magazine well and magazine
    grip_prism(I("polymer"), POLY_D, y=0.035, z=-0.055)
    trigger_guard(g, -0.03, 0.025, -0.06)
    g.box((0, -0.13, -0.075), (0.056, 0.075, 0.035), GUN, bevel=0.004)
    box_mag(s, -0.13, -0.09, length=0.19, curve=9, color=col("3E4440"))
    side_details(g, 0.0, -0.025)
    # buffer tube and stock
    cyl_y(g, 0, 0.11, 0.33, 0.018, 0.016, GUN, seg=14)
    stock_prism(p, col("3A403C"), 0.2, z_top=0.045)
    r.box((0, 0.373, -0.002), (0.05, 0.012, 0.094), POLY_D, bevel=0.004)
    sling_loop(g, 0.33, -0.044)


@item("R17_MAG", 1, 2, view="left", margin=0.12)
def r17_mag(I):
    m = I("metal")
    box_mag(m, 0.0, 0.2, length=0.19, curve=9, color=col("3E4440"))
    b = I("brass")
    b.box((0, -0.002, 0.204), (0.012, 0.045, 0.008), BRASS, bevel=0.003)  # top round
    I("copper").box((0, -0.03, 0.205), (0.009, 0.014, 0.007), COPPER, bevel=0.003)


@item("A62_FMJ", 1, 1, view="three_q_low", margin=0.14)
def a62_fmj(I):
    rounds(I, case=0.04, bullet=0.016, r=0.0052, tip=COPPER, n=5)


def rounds(I, case, bullet, r, tip, n=5, tipcol2=None, shell=False, casecol=BRASS):
    """a little group of cartridges lying side by side, staggered, bullets toward -Y"""
    b, cu = I("brass"), I("copper")
    rng = random.Random(len(I.name))
    for k in range(n):
        x = (k - (n - 1) / 2) * r * 2.15
        y = (k - (n - 1) / 2) * (case + bullet) * 0.09 + rng.uniform(-0.002, 0.002)
        L = case + bullet
        # lying along Y: case then bullet toward -Y
        cyl_y(b, x, y + L / 2, y + L / 2 - case, r, r, casecol, seg=12)
        cyl_y(b, x, y + L / 2 + 0.0015, y + L / 2, r, r * 1.05, shade(casecol, 0.85), seg=12)  # rim
        cyl_y(cu, x, y + L / 2 - case, y - L / 2 + bullet * 0.35, r, r * 0.9, tip, seg=12, r2=r * 0.82)
        cyl_y(cu, x, y - L / 2 + bullet * 0.35, y - L / 2, r, r * 0.82, tipcol2 or tip, seg=12, r2=r * 0.14)


def mag_top_round(I, y, z, tip=COPPER, r=0.006, L=0.05):
    cyl_y(I("brass"), 0, y + L * 0.3, y - L * 0.2, z, r, BRASS, seg=10)
    cyl_y(I("copper"), 0, y - L * 0.2, y - L * 0.5, z, r * 0.9, tip, seg=10, r2=r * 0.2)


@item("R17_MAG40", 1, 3, view="left", margin=0.1)
def r17_mag40(I):
    box_mag(I("metal"), 0.0, 0.3, length=0.29, curve=14, color=col("3A403D"))
    mag_top_round(I, -0.002, 0.306)


@item("KST_MAG", 1, 2, view="left", margin=0.1)
def kst_mag(I):
    box_mag(I("polymer"), 0.0, 0.22, length=0.21, curve=22, depth=0.07, width=0.03, color=col("6A4E36"), plate=col("3A2E24"))
    mag_top_round(I, -0.004, 0.226, tip=col("8C8F86"))


@item("SPARROW_MAG", 1, 2, view="left", margin=0.12)
def sparrow_mag(I):
    box_mag(I("metal"), 0.0, 0.2, length=0.2, curve=0, depth=0.036, width=0.024, color=col("3F4346"), ribs=False)
    for k in range(5):  # witness holes
        I("polymer").box((0.0125, 0.0, 0.17 - k * 0.032), (0.002, 0.008, 0.008), shade(col("3F4346"), 0.35))
    mag_top_round(I, 0.0, 0.205, r=0.0048, L=0.03)


@item("P9_MAG", 1, 1, view="left", margin=0.14)
def p9_mag(I):
    box_mag(I("metal"), 0.0, 0.13, length=0.125, curve=0, depth=0.034, width=0.022, color=col("3C3F41"), ribs=False,
            plate=col("26292A"))
    mag_top_round(I, 0.0, 0.134, r=0.0048, L=0.028)


# ── more guns ────────────────────────────────────────────────────────────────
@item("KST_RIFLE", 5, 2, view="left", margin=0.06)
def kst(I):
    g, w, s = I("gunmetal"), I("wood"), I("metal")
    g.box((0, -0.08, 0.0), (0.05, 0.38, 0.07), GUN, bevel=0.004)  # receiver
    g.box((0, -0.06, 0.046), (0.046, 0.33, 0.026), GUN2, bevel=0.008)  # dust cover
    for k in range(4):
        g.box((0.0245, -0.17 + k * 0.012, 0.047), (0.002, 0.004, 0.014), shade(GUN2, 0.6))
    g.box((0.026, -0.03, 0.01), (0.004, 0.11, 0.008), shade(GUN, 1.3), rot=(R(4), 0, 0), bevel=0.001)  # selector lever (seen through)
    # rear sight block and leaf
    g.box((0, -0.29, 0.05), (0.03, 0.05, 0.028), GUN, bevel=0.003)
    g.box((0, -0.29, 0.068), (0.022, 0.04, 0.006), shade(GUN, 1.2))
    # wooden handguard (lower and upper) and the gas tube
    w.box((0, -0.43, -0.004), (0.058, 0.2, 0.058), WOOD, bevel=0.012)
    w.box((0, -0.42, 0.045), (0.036, 0.18, 0.026), WOOD_D, bevel=0.01)
    cyl_y(g, 0, -0.3, -0.56, 0.046, 0.011, GUN, seg=12)
    # barrel, front sight block, muzzle brake
    barrel(s, -0.52, -0.82, 0.01)
    g.box((0, -0.7, 0.02), (0.026, 0.04, 0.05), GUN, bevel=0.003)
    g.box((0, -0.7, 0.058), (0.006, 0.012, 0.03), GUN)
    cyl_y(g, 0, -0.82, -0.88, 0, 0.0145, GUN, seg=12)
    for k in range(3):
        g.box((0.0, -0.835 - k * 0.016, 0.013), (0.022, 0.006, 0.006), shade(GUN, 0.35))
    # grip, trigger guard, magazine
    grip_prism(I("polymer"), col("3A2C22"), y=0.06, z=-0.035, rake=20, h=0.11)
    trigger_guard(g, -0.02, 0.04, -0.036)
    box_mag(I("polymer"), -0.17, -0.03, length=0.21, curve=22, depth=0.07, width=0.03, color=col("6A4E36"), plate=col("3A2E24"))
    # wooden stock
    pts = [(0.1, 0.03), (0.2, 0.012), (0.42, -0.02), (0.43, -0.13), (0.39, -0.135), (0.22, -0.05), (0.1, -0.03)]
    w.prism(list(reversed(pts)), -0.024, 0.024, WOOD, bevel=0.006)
    I("rubber").box((0, 0.432, -0.074), (0.05, 0.012, 0.118), col("2A2622"), rot=(R(-5), 0, 0), bevel=0.003)
    sling_loop(g, 0.36, -0.07)


@item("SPARROW_SMG", 4, 2, view="left", margin=0.07)
def sparrow(I):
    g, p, s = I("gunmetal"), I("polymer"), I("metal")
    g.box((0, -0.08, 0.02), (0.05, 0.36, 0.07), GUN2, bevel=0.012)  # stamped receiver
    cyl_y(g, 0, 0.08, -0.26, 0.028, 0.028, GUN2, seg=18)
    g.box((0, -0.03, 0.072), (0.034, 0.12, 0.014), GUN, bevel=0.003)  # rear sight drum base
    cyl_x(g, -0.014, 0.014, -0.0, 0.088, 0.012, GUN, seg=12)
    g.box((0, -0.25, 0.072), (0.03, 0.03, 0.03), GUN, bevel=0.003)  # front sight hood
    p.box((0, -0.29, 0.0), (0.06, 0.13, 0.06), POLY_D, bevel=0.012)  # handguard
    barrel(s, -0.36, -0.44, 0.0085)
    cyl_y(g, 0, -0.42, -0.45, 0, 0.012, GUN, seg=12)
    g.box((0.024, -0.16, 0.035), (0.004, 0.05, 0.012), shade(GUN, 1.3), bevel=0.002)  # cocking handle
    grip_prism(p, POLY_D, y=0.03, z=-0.015, rake=12, h=0.11, d=0.042)
    trigger_guard(g, -0.035, 0.015, -0.016)
    g.box((0, -0.09, -0.025), (0.034, 0.05, 0.03), GUN, bevel=0.003)
    box_mag(s, -0.09, -0.035, length=0.2, curve=0, depth=0.036, width=0.024, color=col("3F4346"), ribs=False)
    # folding wire stock
    for zz in (0.035, -0.035):
        cyl_y(g, 0.0, 0.1, 0.33, zz, 0.007, GUN, seg=8)
    g.box((0, 0.335, 0.0), (0.05, 0.016, 0.1), GUN, bevel=0.004)
    I("rubber").box((0, 0.346, 0.0), (0.052, 0.008, 0.102), POLY_D, bevel=0.002)
    side_details(g, -0.0, 0.01)


@item("HARROW12", 5, 1, view="left", margin=0.04)
def harrow(I):
    g, p, s = I("gunmetal"), I("polymer"), I("metal")
    g.box((0, -0.02, 0.0), (0.05, 0.2, 0.085), GUN, bevel=0.008)  # receiver
    g.box((0.0255, -0.03, 0.012), (0.002, 0.07, 0.03), shade(GUN, 0.5))  # ejection port shadow
    barrel(s, -0.12, -0.86, 0.0115)
    cyl_y(s, 0, -0.12, -0.72, -0.03, 0.012, GUN2, seg=14)  # magazine tube
    cyl_y(g, 0, -0.72, -0.735, -0.03, 0.013, GUN, seg=14)
    g.box((0, -0.845, 0.016), (0.006, 0.006, 0.008), BRASS)  # bead sight
    p.box((0, -0.36, -0.03), (0.056, 0.2, 0.05), POLY_D, bevel=0.012)  # pump forend
    for k in range(7):
        p.box((0.0285, -0.28 - k * 0.025, -0.03), (0.002, 0.008, 0.044), shade(POLY_D, 0.6))
    grip_prism(p, POLY_D, y=0.08, z=-0.03, rake=22, h=0.1)
    trigger_guard(g, 0.01, 0.065, -0.04)
    pts = [(0.08, 0.03), (0.18, 0.01), (0.42, -0.01), (0.43, -0.13), (0.39, -0.135), (0.2, -0.06), (0.08, -0.04)]
    p.prism(list(reversed(pts)), -0.024, 0.024, POLY_D, bevel=0.006)
    I("rubber").box((0, 0.434, -0.07), (0.05, 0.012, 0.12), col("1C1E1F"), bevel=0.003)
    for k in range(4):  # side saddle shells
        cyl_z(I("plastic"), 0.03, -0.05 + k * 0.022, -0.035, 0.03, 0.0095, col("8E2A22"), seg=10)
        cyl_z(I("brass"), 0.03, -0.05 + k * 0.022, -0.045, -0.035, 0.0098, BRASS, seg=10)


@item("TUNDRA_BOLT", 6, 1, view="left", margin=0.04)
def tundra(I):
    g, w, s = I("gunmetal"), I("wood"), I("metal")
    # full wooden stock: one long profile
    pts = [(-0.52, 0.0), (-0.12, 0.012), (0.12, 0.012), (0.2, 0.005), (0.5, -0.02), (0.51, -0.14), (0.47, -0.145),
           (0.24, -0.07), (0.12, -0.06), (0.05, -0.1), (0.0, -0.1), (-0.02, -0.035), (-0.52, -0.03)]
    w.prism(list(reversed(pts)), -0.025, 0.025, col("7A5233"), bevel=0.006)
    I("rubber").box((0, 0.513, -0.078), (0.052, 0.012, 0.13), col("2A2622"), rot=(R(-6), 0, 0), bevel=0.003)
    g.box((0, -0.05, 0.03), (0.045, 0.3, 0.04), GUN, bevel=0.01)  # receiver
    barrel(s, -0.2, -1.0, 0.0105)
    cyl_y(g, 0, -1.0, -1.02, 0.0, 0.012, GUN, seg=12)
    g.box((0, -0.98, 0.022), (0.006, 0.012, 0.022), GUN)  # front sight
    g.box((0, -0.16, 0.06), (0.024, 0.03, 0.016), GUN, bevel=0.002)  # rear sight
    # bolt handle and knob (on the right side; seen behind the receiver)
    g.box((-0.035, 0.07, 0.04), (0.05, 0.012, 0.012), GUN2, rot=(0, 0, R(-10)), bevel=0.002)
    I("metal").cyl((-0.062, 0.072, 0.03), (-0.062, 0.072, 0.012), 0.012, STEEL, seg=12, smooth=True)
    trigger_guard(g, 0.0, 0.06, -0.035)
    g.box((0, -0.06, -0.035), (0.03, 0.09, 0.012), GUN, bevel=0.003)  # floor plate
    sling_loop(g, 0.38, -0.105)
    sling_loop(g, -0.4, -0.03)


@item("P9_PISTOL", 2, 1, view="left", margin=0.07)
def p9(I):
    g, p = I("gunmetal"), I("polymer")
    g.box((0, -0.06, 0.032), (0.03, 0.19, 0.034), GUN2, bevel=0.004)  # slide
    for k in range(7):  # rear serrations
        g.box((0.0152, 0.012 + k * 0.006, 0.032), (0.002, 0.0026, 0.028), shade(GUN2, 0.45))
    g.box((0.0152, -0.08, 0.034), (0.002, 0.045, 0.012), shade(GUN2, 0.4))  # ejection port shadow
    g.box((0, -0.15, 0.052), (0.005, 0.008, 0.008), GUN)  # front sight
    g.box((0, 0.025, 0.052), (0.02, 0.008, 0.008), GUN)  # rear sight
    p.box((0, -0.075, 0.003), (0.028, 0.16, 0.024), POLY_D, bevel=0.004)  # frame
    cyl_y(I("metal"), 0, -0.155, -0.158, 0.03, 0.0055, shade(GUN, 0.3), seg=10)  # muzzle
    grip_prism(p, POLY_D, y=0.012, z=-0.008, rake=16, h=0.105, w=0.03, d=0.046, grooves=0)
    for k in range(5):  # grip texture
        p.box((0.0152, 0.02 + k * 0.004, -0.04 - k * 0.012), (0.002, 0.03, 0.006), shade(POLY_D, 1.25), rot=(R(-16), 0, 0))
    trigger_guard(g, -0.045, 0.0, -0.01)
    g.box((0, 0.03, -0.12), (0.03, 0.046, 0.012), GUN, rot=(R(-16), 0, 0), bevel=0.003)  # mag base


@item("FIELD_KNIFE", 1, 2, view="left", margin=0.08)
def knife(I):
    m, r = I("chrome"), I("rubber")
    # vertical: the blade up, the handle down
    pts = [(0.0, 0.13), (0.012, 0.31), (0.004, 0.33), (-0.016, 0.3), (-0.018, 0.13)]
    m.prism(list(reversed(pts)), -0.0025, 0.0025, col("A9AEAB"), bevel=0.0)
    I("metal").box((0, -0.004, 0.2), (0.0052, 0.004, 0.13), col("6E7370"))  # fuller line
    I("gunmetal").box((0, 0, 0.125), (0.014, 0.05, 0.012), GUN, bevel=0.003)  # guard
    r.box((0, -0.002, 0.065), (0.022, 0.03, 0.11), col("2E2F2C"), bevel=0.008)
    for k in range(6):
        r.box((0, -0.0175, 0.025 + k * 0.016), (0.02, 0.003, 0.006), col("242523"))
    I("gunmetal").box((0, -0.002, 0.005), (0.02, 0.028, 0.012), GUN, bevel=0.004)  # pommel


# ── weapon mods ───────────────────────────────────────────────────────────────
@item("RED_DOT", 1, 1, view="three_q", margin=0.1)
def red_dot(I):
    g, gl = I("gunmetal"), I("glass")
    g.box((0, 0, 0.007), (0.034, 0.064, 0.014), GUN, bevel=0.003)  # rail mount
    for yy in (-0.02, 0.0, 0.02):
        g.box((0.0, yy, 0.002), (0.04, 0.006, 0.006), GUN, bevel=0.0015)  # clamp teeth
    g.box((0, 0.014, 0.026), (0.032, 0.03, 0.026), GUN2, bevel=0.006)  # emitter body
    # open frame with a tinted window
    for sx in (-1, 1):
        g.box((sx * 0.0165, -0.012, 0.042), (0.005, 0.02, 0.05), GUN2, bevel=0.002)
    g.box((0, -0.012, 0.068), (0.038, 0.02, 0.006), GUN2, bevel=0.002)
    g.box((0, -0.012, 0.017), (0.038, 0.02, 0.006), GUN2, bevel=0.002)
    gl.box((0, -0.012, 0.043), (0.028, 0.0025, 0.046), col("8AC0C8"))
    I("emissive").box((0, -0.0105, 0.044), (0.0035, 0.0012, 0.0035), col("FF2A1A"))
    cyl_x(g, 0.016, 0.024, 0.016, 0.028, 0.008, GUN, seg=12)  # brightness knob
    I("paper").box((0.0245, 0.016, 0.028), (0.001, 0.004, 0.006), col("C9A23C"))


@item("SCOPE_4X", 2, 1, view="left_hi", margin=0.06)
def scope4(I):
    g, gl = I("gunmetal"), I("glass")
    cyl_y(g, 0, -0.07, 0.07, 0.05, 0.02, GUN2, seg=20)  # body
    cyl_y(g, 0, -0.07, -0.11, 0.05, 0.02, GUN2, r2=0.026, seg=20)  # objective bell
    cyl_y(g, 0, -0.11, -0.13, 0.05, 0.026, GUN, seg=20)
    cyl_y(g, 0, 0.07, 0.1, 0.05, 0.02, GUN2, r2=0.024, seg=20)  # eyepiece
    cyl_y(I("rubber"), 0, 0.1, 0.125, 0.05, 0.024, col("1E1F20"), seg=20)
    gl.cyl((0, -0.1305, 0.05), (0, -0.131, 0.05), 0.022, col("5A7E8A"), seg=20)
    g.box((0, 0.0, 0.074), (0.024, 0.04, 0.012), GUN, bevel=0.003)  # turret
    g.box((0, 0.0, 0.015), (0.03, 0.12, 0.02), GUN, bevel=0.003)  # mount
    for yy in (-0.035, 0.035):
        g.box((0, yy, 0.028), (0.034, 0.02, 0.016), GUN, bevel=0.002)


def suppressor(I, length, r, color):
    g = I("gunmetal")
    cyl_y(g, 0, -length / 2, length / 2, r, r, color, seg=22)
    cyl_y(g, 0, -length / 2 - 0.005, -length / 2, r, r * 0.92, shade(color, 0.85), seg=22)
    cyl_y(g, 0, length / 2, length / 2 + 0.02, r, r * 0.7, shade(color, 0.9), seg=18)  # mount
    for k in range(2):
        yy = -length / 2 + length * (0.33 + k * 0.33)
        cyl_y(g, 0, yy - 0.003, yy + 0.003, r, r * 1.01, shade(color, 0.75), seg=22)


@item("SUPP_62", 2, 1, view="left", margin=0.08)
def supp62(I):
    suppressor(I, 0.17, 0.021, col("2E3233"))


@item("SUPP_9", 2, 1, view="left", margin=0.12)
def supp9(I):
    suppressor(I, 0.15, 0.019, col("3A3A36"))


@item("BRAKE_76", 1, 1, view="three_q_low", margin=0.14)
def brake(I):
    g = I("gunmetal")
    cyl_y(g, 0, -0.04, 0.04, 0.016, 0.016, GUN, seg=18)
    for k in range(3):
        g.box((0, -0.025 + k * 0.022, 0.016 + 0.016), (0.022, 0.009, 0.006), shade(GUN, 0.3))
    cyl_y(g, 0, 0.04, 0.05, 0.016, 0.013, shade(GUN, 0.85), seg=18)


@item("GRIP_V", 1, 1, view="three_q_low", margin=0.12)
def grip_v(I):
    p = I("polymer")
    p.box((0, 0, 0.1), (0.03, 0.06, 0.016), POLY_D, bevel=0.004)  # rail clamp
    cyl_z(p, 0, 0, 0.0, 0.095, 0.015, POLY_D, seg=16, r2=0.017)
    for k in range(4):
        cyl_z(p, 0, 0, 0.012 + k * 0.02, 0.018 + k * 0.02, 0.0162, shade(POLY_D, 0.8), seg=16)


@item("LIGHT_T", 1, 1, view="three_q", margin=0.12)
def light_t(I):
    g = I("gunmetal")
    cyl_y(g, 0, -0.06, 0.04, 0.02, 0.014, GUN2, seg=18)
    cyl_y(g, 0, -0.06, -0.08, 0.02, 0.019, GUN2, seg=18)
    I("glass").cyl((0, -0.0805, 0.02), (0, -0.081, 0.02), 0.016, col("DDE8E8"), seg=18)
    I("emissive").cyl((0, -0.079, 0.02), (0, -0.0795, 0.02), 0.006, col("FFF6D8"), seg=12)
    g.box((0, 0.0, 0.0), (0.02, 0.05, 0.012), GUN, bevel=0.003)  # mount
    cyl_y(I("rubber"), 0, 0.04, 0.05, 0.02, 0.008, col("1E1F20"), seg=12)  # tail switch


# ── ammunition ─────────────────────────────────────────────────────────────────
STEEL_CASE = col("6E7360")


def ammo_item(iid, case, bullet, r, tip, tip2=None, casecol=BRASS, n=5):
    @item(iid, 1, 1, view="top_tilt", margin=0.06)
    def fn(I):
        rounds(I, case=case, bullet=bullet, r=r, tip=tip, n=n, tipcol2=tip2, casecol=casecol)
    return fn


ammo_item("A62_FMJ", 0.04, 0.016, 0.0052, COPPER)
ammo_item("A62_AP", 0.04, 0.016, 0.0052, COPPER, tip2=col("1E1E1E"))
ammo_item("A62_HP", 0.04, 0.015, 0.0052, col("C88A4A"), tip2=col("6E4A2A"))
ammo_item("A76_PS", 0.039, 0.02, 0.0058, col("A9886A"), casecol=STEEL_CASE)
ammo_item("A76_BP", 0.039, 0.02, 0.0058, col("A9886A"), tip2=col("1E1E1E"), casecol=STEEL_CASE)
ammo_item("A76_US", 0.039, 0.022, 0.0058, col("A9886A"), tip2=col("2E3E2A"), casecol=STEEL_CASE)
ammo_item("A9_PST", 0.019, 0.011, 0.0049, col("9C9A90"), n=6)
ammo_item("A9_AP", 0.019, 0.011, 0.0049, col("9C9A90"), tip2=col("1E1E1E"), n=6)
ammo_item("A9_RIP", 0.019, 0.012, 0.0049, col("C27A3A"), tip2=col("8E2A1E"), n=6)
ammo_item("A76L_LPS", 0.054, 0.024, 0.0062, col("8C8F86"), tip2=col("B8B8B8"), casecol=STEEL_CASE, n=4)
ammo_item("A76L_SNB", 0.054, 0.024, 0.0062, col("8C8F86"), tip2=col("1E1E1E"), casecol=BRASS, n=4)


def shells(I, hull, tip=None, n=3):
    pl, b = I("plastic"), I("brass")
    for k in range(n):
        x = (k - (n - 1) / 2) * 0.0215
        y = (k - (n - 1) / 2) * 0.008
        cyl_y(pl, x, y + 0.03, y - 0.034, 0.0102, 0.0102, hull, seg=16)
        cyl_y(b, x, y + 0.034, y + 0.018, 0.0102, 0.0108, BRASS, seg=16)
        cyl_y(b, x, y + 0.035, y + 0.034, 0.0102, 0.0115, shade(BRASS, 0.8), seg=16)
        if tip:
            cyl_y(I("metal"), x, y - 0.034, y - 0.036, 0.0102, 0.008, tip, seg=12)


@item("A12_BUCK", 1, 1, view="top_tilt", margin=0.08)
def a12_buck(I):
    shells(I, col("A42A20"))


@item("A12_SLUG", 1, 1, view="top_tilt", margin=0.08)
def a12_slug(I):
    shells(I, col("2E5A3A"), tip=col("8C8F8A"))


# ── grenades ─────────────────────────────────────────────────────────────────
def fuze(I, z, lever_side=1, color=col("6E7360")):
    m = I("metal")
    cyl_z(m, 0, 0, z, z + 0.022, 0.009, color, seg=14)
    m.box((lever_side * 0.012, 0, z - 0.03), (0.006, 0.016, 0.08), color, rot=(0, R(lever_side * -8), 0), bevel=0.002)  # spoon
    m.torus((0, 0.016, z + 0.012), 0.009, 0.0016, col("B8B8B0"), segU=14, segV=5, rot=(R(90), 0, 0))  # pin ring


@item("GREN_RK5", 1, 1, view="three_q_low", margin=0.1)
def gren_rk5(I):
    b = I("metal")
    b.cyl((0, 0, 0.0), (0, 0, 0.06), 0.028, col("556048"), r2=0.03, seg=20, smooth=True)
    b.cyl((0, 0, 0.06), (0, 0, 0.082), 0.03, col("556048"), r2=0.016, seg=20, smooth=True)
    b.cyl((0, 0, -0.012), (0, 0, 0.0), 0.02, col("556048"), r2=0.028, seg=20, smooth=True)
    label_band(I("paper"), (0, -0.0292, 0.03), (0.026, 0, 0.008), col("C9A23C"))
    fuze(I, 0.082)


@item("GREN_F7", 1, 1, view="three_q_low", margin=0.1)
def gren_f7(I):
    b = I("metal")
    body = col("4A5640")
    b.cyl((0, 0, -0.01), (0, 0, 0.075), 0.03, body, seg=12, smooth=True)
    # cast segments: rings and vertical ribs
    for k in range(5):
        z = 0.0 + k * 0.016
        b.cyl((0, 0, z), (0, 0, z + 0.006), 0.0318, shade(body, 0.85), seg=12)
    for k in range(6):
        a = k * math.pi / 3
        b.box((math.cos(a) * 0.029, math.sin(a) * 0.029, 0.032), (0.006, 0.006, 0.084), shade(body, 0.85), rot=(0, 0, a))
    b.cyl((0, 0, -0.016), (0, 0, -0.01), 0.018, body, r2=0.026, seg=12)
    fuze(I, 0.075)


@item("GREN_STUN", 1, 1, view="three_q_low", margin=0.1)
def gren_stun(I):
    b = I("metal")
    body = col("4D5257")
    cyl_z(b, 0, 0, 0.0, 0.1, 0.022, body, seg=20)
    for k in range(3):
        for j in range(6):
            a = j * math.pi / 3 + k * 0.5
            b.box((math.cos(a) * 0.0222, math.sin(a) * 0.0222, 0.02 + k * 0.03), (0.002, 0.008, 0.008), shade(body, 0.3), rot=(0, 0, a))
    label_band(I("paper"), (0, -0.0225, 0.085), (0.03, 0, 0.012), col("D8D4C8"))
    fuze(I, 0.1)


@item("GREN_SMOKE", 1, 1, view="three_q_low", margin=0.1)
def gren_smoke(I):
    b = I("metal")
    body = col("6C7469")
    cyl_z(b, 0, 0, 0.0, 0.11, 0.024, body, seg=20)
    cyl_z(b, 0, 0, 0.11, 0.114, 0.024, shade(body, 0.8), seg=20)
    label_band(I("paper"), (0, -0.0245, 0.06), (0.034, 0, 0.05), col("D8D6CC"))
    label_band(I("paper"), (0, -0.0247, 0.07), (0.028, 0, 0.008), col("2A2A2A"))
    fuze(I, 0.114)


# ── repair kit ────────────────────────────────────────────────────────────────
@item("WEAPON_KIT", 2, 1, view="three_q", margin=0.08)
def weapon_kit(I):
    pl, m = I("plastic"), I("metal")
    case = col("5B5E52")
    pl.box((0, 0, 0.03), (0.3, 0.14, 0.06), case, bevel=0.012)
    pl.box((0, 0, 0.066), (0.3, 0.14, 0.012), shade(case, 0.88), bevel=0.005)  # lid line
    for x in (-0.11, 0.11):
        m.box((x, -0.072, 0.05), (0.03, 0.008, 0.02), col("8C9290"), bevel=0.002)  # latches
    pl.tube([(-0.05, 0, 0.072), (-0.05, 0, 0.09), (0.05, 0, 0.09), (0.05, 0, 0.072)], 0.007, shade(case, 0.7), seg=8)
    label_band(I("paper"), (0.0, -0.0705, 0.03), (0.12, 0, 0.03), col("C9C2A8"))

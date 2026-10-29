"""Zero Return - Kestrel KS-7 parts (AK-type 7.6x39 rifle, original design). Conventions: zr_guns.py.

Receiver frame: bore axis z = 0, receiver rear y = 0, receiver walls up to z = 0.012 (the dust cover sits on
them), front trunnion y = -0.26, muzzle shoulder y = -0.605. Iron sight line 0.038 above the bore.
"""
import math
from mathutils import Vector, Matrix
from zr_items import col, shade, mixc, R
from zr_guns import (gpart, preset, side, box, ybar, ring, ylathe, pica, slots_row, screw, pin, vents, grip_profile,
                     box_mag, round_top, sling_loop, lens, dot, suppressor,
                     BLACK, BLACK2, PARK, BLUED, STEEL, BRIGHT, POLY, POLY2, FDE, ODG, PLUM, WOOD, WOOD2, WOODL, RUBBER, WHITE)

AK_STEEL = col("343736")
AK_BLUE = col("2B2F31")
SL = 0.038                      # sight line above the bore
BAKELITE = col("7A4630")
MAG_STEEL = col("3A3B38")


@gpart("KST_RIFLE", 5, 2, family="kst", margin=0.03)
def kst_receiver(P):
    g, s = P("gunmetal"), P("metal")
    W = 0.031
    # stamped receiver
    side(g, [(0.0, 0.012), (-0.262, 0.012), (-0.262, -0.03), (-0.205, -0.036), (-0.14, -0.042), (-0.02, -0.042), (0.0, -0.03)], W, AK_STEEL, bevel=0.0015)
    side(g, [(0.004, 0.006), (-0.03, 0.006), (-0.03, -0.034), (0.004, -0.03)], W + 0.002, shade(AK_STEEL, 0.9), bevel=0.001)   # rear trunnion
    side(g, [(-0.232, 0.012), (-0.268, 0.012), (-0.268, -0.034), (-0.232, -0.034)], W + 0.002, shade(AK_STEEL, 0.9), bevel=0.001)  # front trunnion
    for sx in (-1, 1):                                                   # rivets
        for y, z in ((-0.008, -0.01), (-0.018, -0.022), (-0.008, -0.024), (-0.238, -0.004), (-0.25, -0.004), (-0.238, -0.024), (-0.25, -0.024)):
            g.cyl((sx * (W / 2 + 0.001), y, z), (sx * (W / 2 + 0.0022), y, z), 0.0021, shade(AK_STEEL, 1.15), seg=8)
        g.cyl((sx * (W / 2 + 0.0004), -0.178, -0.02), (sx * (W / 2 + 0.0012), -0.178, -0.02), 0.0045, shade(AK_STEEL, 0.6), seg=12)  # mag guide dimple
    # left side dovetail rail for side mounts
    side(g, [(-0.05, -0.002), (-0.145, -0.002), (-0.145, -0.018), (-0.05, -0.018)], 0.006, shade(AK_STEEL, 1.1), x=W / 2 + 0.003, bevel=0.0008)
    # trigger guard, magazine catch, trigger
    g.tube([(0, -0.028, -0.042), (0, -0.03, -0.062), (0, -0.12, -0.064), (0, -0.138, -0.052), (0, -0.142, -0.042)], 0.0034, AK_STEEL, seg=6)
    s.box((0, -0.149, -0.05), (0.012, 0.006, 0.02), STEEL, rot=(R(-12), 0, 0), bevel=0.001)
    s.tube([(0, -0.064, -0.042), (0, -0.068, -0.05), (0, -0.066, -0.058)], 0.002, STEEL, seg=5)
    # right side: the big selector lever and the charging handle on the bolt carrier
    s.box((-W / 2 - 0.0015, -0.11, -0.003), (0.003, 0.15, 0.009), STEEL, rot=(R(4), 0, 0), bevel=0.0012)
    s.box((-W / 2 - 0.009, -0.168, 0.006), (0.016, 0.012, 0.008), STEEL, bevel=0.002)
    s.cyl((-W / 2 - 0.017, -0.168, 0.006), (-W / 2 - 0.02, -0.168, 0.006), 0.006, STEEL, seg=12)
    # gas block, barrel, front sight block, cleaning rod
    ybar(g, -0.262, -0.605, 0.0, 0.0108, AK_BLUE, seg=18)
    side(g, [(-0.442, -0.012), (-0.474, -0.012), (-0.474, 0.03), (-0.452, 0.034), (-0.442, 0.03)], 0.02, AK_STEEL, bevel=0.002)
    ybar(g, -0.452, -0.476, 0.022, 0.0082, AK_STEEL, seg=14)
    for k in range(3):
        g.box((0.0084, -0.455 - k * 0.006, 0.022), (0.0012, 0.0034, 0.0034), shade(AK_STEEL, 0.3))   # gas vents
    side(g, [(-0.578, -0.012), (-0.605, -0.012), (-0.605, 0.016), (-0.596, 0.02), (-0.582, 0.02), (-0.578, 0.016)], 0.02, AK_STEEL, bevel=0.002)
    for sx in (-1, 1):                                                   # front sight ears
        g.box((sx * 0.0072, -0.59, 0.03), (0.0024, 0.012, 0.022), AK_STEEL, bevel=0.0007)
    s.box((0, -0.59, SL - 0.007), (0.0022, 0.0022, 0.014), shade(STEEL, 0.5))
    g.box((0, -0.594, -0.018), (0.008, 0.016, 0.01), AK_STEEL, bevel=0.0012)   # bayonet lug
    s.cyl((0, -0.29, -0.019), (0, -0.592, -0.019), 0.0032, shade(STEEL, 0.85), seg=8)  # cleaning rod
    s.box((0, -0.586, -0.019), (0.006, 0.006, 0.006), STEEL, bevel=0.001)
    P.slot("dustcover", (0, 0.0, 0.012))
    P.slot("handguard", (0, -0.262, 0.0))
    P.slot("grip", (0, -0.026, -0.042))
    P.slot("stock", (0, 0.0, -0.012))
    P.slot("rearsight", (0, -0.262, 0.014))
    P.slot("mount", (W / 2 + 0.006, -0.098, -0.01))
    P.slot("muzzle", (0, -0.605, 0.0))
    P.slot("mag", (0, -0.176, -0.026))
    P.anchor("muzzle", (0, -0.612, 0.0))
    P.anchor("port", (-0.016, -0.12, 0.004))
    P.anchor("eye", (0, -0.27, SL))
    P.anchor("hand", (0, -0.36, -0.02))


# ── dust covers ──────────────────────────────────────────────────────────────
def dust_cover(g, color, rail=False):
    prof = [(-0.003, 0.0), (-0.234, 0.0), (-0.234, 0.012), (-0.226, 0.019), (-0.012, 0.021), (-0.003, 0.016)]
    side(g, prof, 0.0315, color, bevel=0.004)
    for k in range(3):                                                   # stamped ribs
        g.box((0.0158, -0.03 - k * 0.012, 0.011), (0.0016, 0.005, 0.014), shade(color, 1.15), bevel=0.0012)
    g.box((0, -0.0005, 0.012), (0.012, 0.004, 0.008), shade(color, 0.4))   # recoil spring button slot
    if rail:
        side(g, [(-0.012, 0.019), (-0.226, 0.019), (-0.226, 0.026), (-0.012, 0.026)], 0.024, color, bevel=0.0015)
        pica(g, -0.016, -0.222, 0.026, color=color)


@gpart("KST_DC_STD", 3, 1, family="kst", view="left_hi")
def kst_dc_std(P):
    dust_cover(P("gunmetal"), AK_STEEL)


@gpart("KST_DC_RAIL", 3, 1, family="kst", view="left_hi")
def kst_dc_rail(P):
    g = P("gunmetal")
    dust_cover(g, BLACK, rail=True)
    g.box((0.0, -0.236, 0.018), (0.02, 0.008, 0.012), BLACK2, bevel=0.002)      # front lock to the rear sight block
    P.slot("scope", (0, -0.12, 0.026 + 0.0095))


# ── handguards (origin at the front trunnion on the bore axis) ───────────────
def gas_tube(g, color=AK_STEEL, L=0.19):
    ybar(g, -0.004, -L, 0.022, 0.0088, color, seg=14)


@gpart("KST_HG_WOOD", 3, 1, family="kst")
def kst_hg_wood(P):
    g, w = P("gunmetal"), P("wood")
    gas_tube(g)
    side(w, [(-0.012, 0.012), (-0.16, 0.012), (-0.166, 0.004), (-0.166, -0.022), (-0.155, -0.027), (-0.02, -0.027), (-0.012, -0.02)], 0.042, WOOD, bevel=0.005)
    for k in range(3):                                                   # finger ribs
        w.box((0.0213, -0.05 - k * 0.032, -0.012), (0.0016, 0.012, 0.017), shade(WOOD, 0.75), bevel=0.003)
    ybar(w, -0.008, -0.162, 0.024, 0.0122, WOODL, seg=16)                 # upper wood on the gas tube
    for y in (-0.006, -0.164):
        side(g, [(y + 0.004, 0.034), (y - 0.004, 0.034), (y - 0.004, -0.029), (y + 0.004, -0.029)], 0.044, AK_STEEL, bevel=0.0015)
    P.anchor("hand", (0, -0.09, -0.026))


@gpart("KST_HG_POLY", 3, 1, family="kst")
def kst_hg_poly(P):
    g, p = P("gunmetal"), P("polymer")
    gas_tube(g)
    side(p, [(-0.012, 0.012), (-0.16, 0.012), (-0.166, 0.004), (-0.166, -0.024), (-0.155, -0.029), (-0.02, -0.029), (-0.012, -0.022)], 0.043, PLUM, bevel=0.005)
    for k in range(5):
        p.box((0.0218, -0.03 - k * 0.026, -0.01), (0.0012, 0.016, 0.006), shade(PLUM, 0.6), bevel=0.002)
    ybar(p, -0.008, -0.162, 0.024, 0.0125, PLUM, seg=16)
    for k in range(4):
        p.box((0.0, -0.03 - k * 0.035, 0.0368), (0.006, 0.02, 0.0012), shade(PLUM, 0.55))
    pica(g, -0.06, -0.12, -0.029, face="bottom", color=BLACK)
    for y in (-0.006, -0.164):
        side(g, [(y + 0.004, 0.034), (y - 0.004, 0.034), (y - 0.004, -0.031), (y + 0.004, -0.031)], 0.045, AK_STEEL, bevel=0.0015)
    P.slot("foregrip", (0, -0.09, -0.029 - 0.0095))
    P.anchor("hand", (0, -0.1, -0.03))


@gpart("KST_HG_RAIL", 3, 1, family="kst")
def kst_hg_rail(P):
    g = P("gunmetal")
    gas_tube(g, BLACK)
    box(g, (0, -0.088, -0.006), (0.04, 0.158, 0.04), BLACK, bevel=0.007)
    pica(g, -0.014, -0.162, -0.026, face="bottom")
    pica(g, -0.014, -0.162, -0.006, x=0.02, face="left")
    pica(g, -0.014, -0.162, -0.006, x=-0.02, face="right")
    side(g, [(-0.008, 0.014), (-0.165, 0.014), (-0.165, 0.032), (-0.008, 0.032)], 0.026, BLACK, bevel=0.003)   # gas tube cover
    pica(g, -0.012, -0.16, 0.032)
    for k in range(4):
        g.box((0.0145, -0.03 - k * 0.035, 0.024), (0.0012, 0.022, 0.006), shade(BLACK, 0.25), bevel=0.0015)
    P.slot("foregrip", (0, -0.1, -0.0355))
    P.slot("tactical", (0.0295, -0.14, -0.006), rot=(0, -90, 0))
    P.slot("top", (0, -0.1, 0.0415))
    P.anchor("hand", (0, -0.095, -0.036))


# ── pistol grips (origin under the receiver, behind the trigger guard) ───────
@gpart("AK_PG_STD", 1, 2, family="kst", margin=0.1)
def ak_pg_std(P):
    p = P("polymer")
    side(p, grip_profile(0.004, 0.0, 14, 0.098, 0.032, grooves=0, swell=0.003), 0.027, BAKELITE, bevel=0.0035)
    for k in range(6):
        for j in range(3):
            p.box((0.0138, 0.008 + j * 0.006 + k * 0.0024, -0.025 - k * 0.011), (0.0008, 0.0035, 0.006), shade(BAKELITE, 0.6))
    P.anchor("grip", (0, 0.01, -0.045))


@gpart("AK_PG_ERGO", 1, 2, family="kst", margin=0.1)
def ak_pg_ergo(P):
    p = P("polymer")
    side(p, grip_profile(0.004, 0.0, 15, 0.1, 0.037, grooves=3, swell=0.002), 0.029, POLY, bevel=0.004)
    side(p, grip_profile(0.006, -0.014, 15, 0.072, 0.024, grooves=0), 0.0302, shade(POLY, 0.65), bevel=0.002)
    P.anchor("grip", (0, 0.011, -0.046))


@gpart("AK_PG_RUB", 1, 2, family="kst", margin=0.1)
def ak_pg_rub(P):
    r = P("rubber")
    side(r, grip_profile(0.005, 0.0, 18, 0.1, 0.036, grooves=2, swell=0.003), 0.029, col("2F3332"), bevel=0.004)
    for k in range(9):
        r.box((0.0146, 0.008 + k * 0.0016, -0.018 - k * 0.009), (0.0008, 0.022, 0.003), shade(col("2F3332"), 0.6))
    P.anchor("grip", (0, 0.012, -0.046))


# ── stocks (origin at the rear trunnion, on the stock's attachment axis) ─────
@gpart("KST_STK_WOOD", 3, 1, family="kst")
def kst_stk_wood(P):
    w, s = P("wood"), P("metal")
    prof = [(0.0, 0.016), (0.03, 0.016), (0.25, -0.012), (0.258, -0.017), (0.258, -0.128), (0.246, -0.134), (0.05, -0.04), (0.0, -0.026)]
    side(w, prof, 0.038, WOOD, bevel=0.005)
    side(s, [(0.258, -0.014), (0.266, -0.014), (0.266, -0.131), (0.258, -0.131)], 0.04, AK_STEEL, bevel=0.0025)   # butt plate
    s.box((0.0, 0.263, -0.04), (0.012, 0.008, 0.02), shade(AK_STEEL, 0.6), bevel=0.002)                        # trap door
    sling_loop(s, 0.215, -0.11, color=STEEL)
    for k in range(4):                                                   # grain lines
        w.box((0.0192, 0.08 + k * 0.04, -0.03 - k * 0.012), (0.0004, 0.05, 0.0012), shade(WOOD, 0.8), rot=(R(-12), 0, 0))
    s.box((0, 0.006, -0.002), (0.034, 0.012, 0.03), AK_STEEL, bevel=0.0015)   # stock tang plate


@gpart("KST_STK_FOLD", 3, 1, family="kst")
def kst_stk_fold(P):
    g, s = P("gunmetal"), P("metal")
    g.box((0.0, 0.012, -0.004), (0.036, 0.026, 0.034), AK_STEEL, bevel=0.003)          # hinge block
    s.cyl((0.0195, 0.016, -0.004), (0.0225, 0.016, -0.004), 0.006, STEEL, seg=12)
    g.tube([(0, 0.022, 0.006), (0, 0.24, -0.006)], 0.0058, AK_STEEL, seg=10, caps=True)
    g.tube([(0, 0.022, -0.016), (0, 0.24, -0.12)], 0.0058, AK_STEEL, seg=10, caps=True)
    side(g, [(0.232, 0.004), (0.248, 0.004), (0.248, -0.128), (0.232, -0.128)], 0.034, AK_STEEL, bevel=0.003)
    for k in range(3):
        g.box((0.0175, 0.24, -0.02 - k * 0.04), (0.0012, 0.01, 0.025), shade(AK_STEEL, 0.5))


def tube_stock(P, color, adapter=AK_STEEL):
    g, p, r = P("gunmetal"), P("polymer"), P("rubber")
    g.box((0.0, 0.01, -0.004), (0.034, 0.022, 0.036), adapter, bevel=0.003)          # receiver adapter
    ybar(g, 0.02, 0.2, 0.0, 0.0145, BLACK, seg=18)
    ybar(g, 0.02, 0.028, 0.0, 0.0175, BLACK2, seg=12)
    prof = [(0.084, 0.018), (0.12, 0.018), (0.128, 0.026), (0.198, 0.027), (0.205, 0.022), (0.205, -0.08), (0.196, -0.083),
            (0.17, -0.06), (0.124, -0.026), (0.104, -0.02), (0.093, -0.02), (0.084, -0.013)]
    side(p, prof, 0.036, color, bevel=0.003)
    side(r, [(0.205, 0.0245), (0.218, 0.0245), (0.218, -0.084), (0.205, -0.084)], 0.039, RUBBER, bevel=0.0025)
    g.box((0, 0.1, -0.021), (0.008, 0.028, 0.0065), BLACK2, bevel=0.0015)


@gpart("KST_STK_TUBE", 3, 1, family="kst")
def kst_stk_tube(P):
    tube_stock(P, FDE)


# ── rear sight (origin on the rear sight block) ──────────────────────────────
@gpart("KST_RS_TAN", 1, 1, family="kst", margin=0.12)
def kst_rs_tan(P):
    g, s = P("gunmetal"), P("metal")
    g.box((0, -0.012, 0.004), (0.028, 0.03, 0.01), AK_STEEL, bevel=0.002)
    side(g, [(0.002, 0.009), (-0.05, 0.016), (-0.05, 0.024), (0.002, 0.016)], 0.014, AK_STEEL, bevel=0.0012)   # leaf
    for k in range(8):
        g.box((0.0072, -0.006 - k * 0.0055, 0.017 + k * 0.0009), (0.0006, 0.0012, 0.003), WHITE)
    g.box((0, -0.026, 0.02), (0.02, 0.008, 0.008), shade(AK_STEEL, 1.1), bevel=0.0015)   # slider
    side(g, [(-0.046, 0.016), (-0.05, 0.016), (-0.05, SL - 0.012), (-0.046, SL - 0.012)], 0.018, AK_STEEL)
    s.box((0.0, -0.048, SL - 0.012), (0.0024, 0.005, 0.0008), shade(STEEL, 0.3))   # notch
    P.anchor("eye", (0, -0.048, SL - 0.014))


# ── side mount (origin on the dovetail; the rail ends up over the bore) ──────
@gpart("KST_MNT_SIDE", 1, 1, family="kst", margin=0.1, view=(0.6, -0.8, 0.5))
def kst_mnt_side(P):
    g = P("gunmetal")
    X0 = -0.0215                                                        # bore centre seen from the dovetail
    g.box((0.004, 0.0, 0.0), (0.012, 0.09, 0.02), BLACK, bevel=0.002)                # clamp on the dovetail
    g.box((0.012, 0.015, -0.002), (0.006, 0.04, 0.008), BLACK2, rot=(R(5), 0, 0), bevel=0.0015)   # lever
    side(g, [(0.04, 0.008), (-0.04, 0.008), (-0.04, 0.058), (0.04, 0.058)], 0.008, BLACK, x=0.004, bevel=0.002)   # arm up the side
    g.box((X0 / 2 + 0.002, 0.0, 0.062), (abs(X0) + 0.018, 0.09, 0.01), BLACK, bevel=0.002)   # bridge over the cover
    pica(g, 0.042, -0.042, 0.067, x=X0)
    for y in (0.02, -0.02):
        g.box((0.0085, y, 0.032), (0.002, 0.024, 0.02), shade(BLACK, 0.3), bevel=0.002)   # lightening cuts
    P.slot("scope", (X0, 0.0, 0.067 + 0.0095))


# ── muzzle devices (origin at the thread shoulder) ───────────────────────────
@gpart("KST_FH_SLANT", 1, 1, family="kst", margin=0.14, view="left_hi")
def kst_fh_slant(P):
    g = P("gunmetal")
    ybar(g, 0.0, -0.022, 0.0, 0.0115, AK_STEEL, seg=18)
    side(g, [(-0.022, -0.0115), (-0.022, 0.0115), (-0.031, 0.0115), (-0.026, -0.0115)], 0.023, AK_STEEL, bevel=0.0012)   # slant cut
    g.box((0, -0.026, 0.0085), (0.009, 0.006, 0.006), shade(AK_STEEL, 0.25))
    P.anchor("muzzle", (0, -0.03, 0.0))


@gpart("BRAKE_76", 1, 1, family="kst", margin=0.14, view="left_hi")
def brake_76(P):
    g = P("gunmetal")
    ybar(g, 0.0, -0.016, 0.0, 0.0112, AK_STEEL, seg=18)
    ybar(g, -0.016, -0.072, 0.0, 0.0132, AK_STEEL, seg=20)
    for k in range(2):
        for sx in (-1, 1):
            g.box((sx * 0.0126, -0.034 - k * 0.022, 0.0), (0.004, 0.012, 0.014), shade(AK_STEEL, 0.12), bevel=0.0018)
    g.box((0, -0.064, 0.012), (0.01, 0.01, 0.004), shade(AK_STEEL, 0.12), bevel=0.002)
    ybar(g, -0.071, -0.0725, 0.0, 0.0085, shade(AK_STEEL, 0.3), seg=16)
    P.anchor("muzzle", (0, -0.072, 0.0))


@gpart("SUPP_76", 2, 1, family="kst", margin=0.07)
def supp_76(P):
    suppressor(P, 0.19, 0.0215, col("2E302C"))


# ── magazines ────────────────────────────────────────────────────────────────
@gpart("KST_MAG", 1, 2, family="kst", margin=0.1)
def kst_mag(P):
    m = P("metal")
    box_mag(m, 0.205, 0.026, 0.07, 24, BAKELITE, plate=col("3A2E24"), ribs=(0.3, 0.58), rib_color=shade(BAKELITE, 0.85))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.04, color=col("8C8F86"))


@gpart("KST_MAG_POLY", 1, 2, family="kst", margin=0.1)
def kst_mag_poly(P):
    p = P("polymer")
    box_mag(p, 0.205, 0.026, 0.07, 24, POLY, plate=shade(POLY, 0.7), ribs=(0.18, 0.3, 0.42, 0.54, 0.66, 0.78))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.04, color=col("8C8F86"))


@gpart("KST_MAG40", 1, 3, family="kst", margin=0.1)
def kst_mag40(P):
    m = P("metal")
    box_mag(m, 0.27, 0.026, 0.07, 32, MAG_STEEL, plate=shade(MAG_STEEL, 0.7), ribs=(0.25, 0.5, 0.75))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.04, color=col("8C8F86"))


# ── builds ───────────────────────────────────────────────────────────────────
def _kst(dc="KST_DC_STD", hg="KST_HG_WOOD", grip="AK_PG_STD", stock="KST_STK_WOOD", muzzle="KST_FH_SLANT", rs="KST_RS_TAN",
         mag="KST_MAG", mount=None, dc_kids=None, hg_kids=None):
    t = {"dustcover": (dc, dc_kids or {}), "handguard": (hg, hg_kids or {}), "grip": (grip, {}), "stock": (stock, {}),
         "mag": (mag, {})}
    if muzzle:
        t["muzzle"] = (muzzle, {})
    if rs:
        t["rearsight"] = (rs, {})
    if mount:
        t["mount"] = mount
    return t


preset("KST_RIFLE", "KST_RIFLE", _kst())
preset("KST_TAC", "KST_RIFLE", _kst(dc="KST_DC_RAIL", dc_kids={"scope": ("HOLO_EX", {})}, hg="KST_HG_RAIL",
                                    hg_kids={"foregrip": ("GRIP_ANG", {}), "tactical": ("LIGHT_T", {})}, grip="AK_PG_ERGO",
                                    stock="KST_STK_TUBE", muzzle="BRAKE_76", mag="KST_MAG_POLY"))
preset("KST_QUIET", "KST_RIFLE", _kst(hg="KST_HG_POLY", hg_kids={"foregrip": ("GRIP_STOP", {})}, grip="AK_PG_RUB",
                                      stock="KST_STK_FOLD", muzzle="SUPP_76", mount=("KST_MNT_SIDE", {"scope": ("SCOPE_4X", {})})))

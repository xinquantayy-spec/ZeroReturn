"""Zero Return - Sparrow SMG-9 parts (roller-delayed 9x19 submachine gun, original design). Conventions: zr_guns.py.

Receiver frame: bore axis z = 0, receiver rear y = 0, receiver top z = 0.024, barrel end (three-lug shoulder)
y = -0.338. The drum rear sight and the hooded front post are part of the receiver; sight line 0.044.
"""
import math
from zr_items import col, shade, R
from zr_guns import (gpart, preset, side, box, ybar, ring, ylathe, pica, screw, pin, grip_profile, box_mag, round_top,
                     trigger_guard, trigger, sling_loop, lens,
                     BLACK, BLACK2, PARK, STEEL, POLY, POLY2, FDE, RUBBER, WHITE)

SMG = col("2F3233")
SL = 0.044


@gpart("SPARROW_SMG", 4, 2, family="spr", margin=0.03)
def spr_receiver(P):
    g, s = P("gunmetal"), P("metal")
    W = 0.034
    # stamped receiver with its top rib and the cocking tube in front
    side(g, [(0.0, 0.024), (-0.2, 0.024), (-0.21, 0.016), (-0.21, -0.026), (-0.12, -0.028), (0.0, -0.022)], W, SMG, bevel=0.003)
    side(g, [(-0.004, 0.024), (-0.196, 0.024), (-0.196, 0.03), (-0.004, 0.03)], 0.012, shade(SMG, 1.08), bevel=0.0012)   # top rib
    for y in (-0.03, -0.09, -0.15):                                       # claw mount bosses
        g.box((0, y, 0.0315), (0.016, 0.008, 0.004), shade(SMG, 1.15), bevel=0.0012)
    for k in range(2):                                                    # pressed ribs on the sides
        g.box((W / 2 + 0.0006, -0.105, -0.006 - k * 0.012), (0.0012, 0.17, 0.0028), shade(SMG, 1.12), bevel=0.0005)
    ybar(g, -0.18, -0.315, 0.017, 0.0105, SMG, seg=18)                    # cocking tube
    side(g, [(-0.205, 0.023), (-0.285, 0.023), (-0.285, 0.028), (-0.205, 0.028)], 0.004, shade(SMG, 0.3), x=0.0105)  # handle slot
    s.box((0.017, -0.21, 0.02), (0.022, 0.008, 0.007), STEEL, bevel=0.0018)          # cocking handle (folded, left side)
    s.cyl((0.029, -0.21, 0.02), (0.033, -0.21, 0.02), 0.0055, POLY, seg=12)
    ybar(g, -0.21, -0.338, 0.0, 0.0102, PARK, seg=18)                     # barrel
    for k in range(3):                                                    # three lugs
        a = k * 2 * math.pi / 3 + math.pi / 2
        g.box((0.0112 * math.cos(a), -0.322, 0.0112 * math.sin(a)), (0.004, 0.012, 0.004), PARK, rot=(0, -a, 0), bevel=0.001)
    # drum rear sight (integrated) and the hooded front sight
    g.box((0, -0.016, 0.033), (0.02, 0.018, 0.01), SMG, bevel=0.002)
    g.cyl((-0.012, -0.018, SL), (0.012, -0.018, SL), 0.0085, shade(SMG, 1.1), seg=16)
    for k in range(4):
        a = k * math.pi / 2
        g.cyl((0.0122, -0.018 + 0.006 * math.cos(a), SL + 0.006 * math.sin(a)), (0.0128, -0.018 + 0.006 * math.cos(a), SL + 0.006 * math.sin(a)), 0.0012, WHITE, seg=6)
    side(g, [(-0.29, 0.024), (-0.31, 0.024), (-0.31, 0.034), (-0.29, 0.034)], 0.016, SMG, bevel=0.001)
    g.torus((0, -0.3, SL), 0.0085, 0.0018, SMG, segU=14, segV=5, rot=(R(90), 0, 0))
    s.box((0, -0.3, SL - 0.005), (0.0022, 0.0022, 0.01), shade(STEEL, 0.5))
    # magazine well and catch
    side(g, [(-0.155, -0.026), (-0.2, -0.026), (-0.198, -0.056), (-0.16, -0.056)], W + 0.002, SMG, bevel=0.002)
    s.box((0, -0.15, -0.05), (0.012, 0.006, 0.014), STEEL, bevel=0.001)
    sling_loop(s, -0.006, -0.02, x=0.018, color=STEEL)
    P.slot("grip", (0, -0.006, -0.024))
    P.slot("stock", (0, 0.0, 0.004))
    P.slot("handguard", (0, -0.21, 0.0))
    P.slot("muzzle", (0, -0.338, 0.0))
    P.slot("mount", (0, -0.09, 0.0335))
    P.slot("mag", (0, -0.178, -0.03))
    P.anchor("muzzle", (0, -0.338, 0.0))
    P.anchor("port", (-0.017, -0.08, 0.004))
    P.anchor("eye", (0, -0.018, SL))
    P.anchor("hand", (0, -0.26, -0.03))


# ── trigger groups with pistol grip (origin under the receiver rear) ─────────
def trigger_group(P, color, ambi=False):
    p, s = P("polymer"), P("metal")
    side(p, [(0.004, 0.0), (-0.11, 0.0), (-0.112, -0.012), (-0.07, -0.016), (-0.032, -0.016), (-0.02, -0.006), (0.006, -0.006)], 0.032, color, bevel=0.003)
    side(p, grip_profile(0.012, -0.004, 18, 0.096, 0.038, grooves=3, swell=0.002), 0.03, color, bevel=0.004)
    p.tube([(0, -0.03, -0.012), (0, -0.034, -0.03), (0, -0.07, -0.034), (0, -0.098, -0.026), (0, -0.104, -0.012)], 0.0036, color, seg=6)
    trigger(s, -0.05, -0.014)
    s.cyl((0.0162, -0.012, -0.006), (0.0185, -0.012, -0.006), 0.0068, STEEL, seg=14)   # selector
    s.box((0.019, -0.006, -0.002), (0.003, 0.014, 0.004), STEEL, rot=(R(-25), 0, 0), bevel=0.0008)
    for k, a in enumerate((-50, 0, 50)):
        p.box((0.0163, -0.012 + 0.0115 * math.sin(R(a)), -0.006 + 0.0115 * math.cos(R(a))), (0.0006, 0.0022, 0.0022), WHITE if k else col("C24A35"))
    if ambi:
        s.cyl((-0.0162, -0.012, -0.006), (-0.0185, -0.012, -0.006), 0.0068, STEEL, seg=14)
    P.anchor("grip", (0, 0.022, -0.05))


@gpart("SPR_GRIP_STD", 2, 2, family="spr", margin=0.1)
def spr_grip_std(P):
    trigger_group(P, POLY)


@gpart("SPR_GRIP_NAVY", 2, 2, family="spr", margin=0.1)
def spr_grip_navy(P):
    trigger_group(P, col("2B2D2E"), ambi=True)


# ── stocks (origin at the receiver rear) ─────────────────────────────────────
@gpart("SPR_STK_FIXED", 2, 1, family="spr")
def spr_stk_fixed(P):
    p, r = P("polymer"), P("rubber")
    side(p, [(0.0, 0.024), (0.03, 0.024), (0.205, 0.016), (0.212, 0.012), (0.212, -0.085), (0.2, -0.09), (0.05, -0.034), (0.0, -0.024)], 0.036, POLY, bevel=0.004)
    side(r, [(0.212, 0.014), (0.222, 0.014), (0.222, -0.088), (0.212, -0.088)], 0.038, RUBBER, bevel=0.003)
    p.box((0.0, 0.17, -0.06), (0.037, 0.026, 0.008), shade(POLY, 0.25), rot=(R(-28), 0, 0), bevel=0.002)


@gpart("SPR_STK_SLIDE", 2, 1, family="spr")
def spr_stk_slide(P):
    g, r = P("gunmetal"), P("rubber")
    g.box((0, 0.012, 0.0), (0.03, 0.024, 0.04), SMG, bevel=0.003)          # end cap with the rail guides
    for sx in (-1, 1):
        g.tube([(sx * 0.013, 0.02, 0.012), (sx * 0.013, 0.17, 0.012)], 0.0042, SMG, seg=8, caps=True)
    g.tube([(0, 0.02, -0.012), (0, 0.17, -0.012)], 0.0042, SMG, seg=8, caps=True)
    side(g, [(0.165, 0.022), (0.18, 0.022), (0.18, -0.07), (0.165, -0.07)], 0.034, SMG, bevel=0.003)
    side(r, [(0.18, 0.024), (0.19, 0.024), (0.19, -0.072), (0.18, -0.072)], 0.036, RUBBER, bevel=0.003)
    g.box((0, 0.03, -0.024), (0.01, 0.014, 0.008), shade(SMG, 1.2), bevel=0.002)   # release paddle


@gpart("SPR_STK_CAP", 1, 1, family="spr", margin=0.12, view="left_hi")
def spr_stk_cap(P):
    g = P("gunmetal")
    g.box((0, 0.01, 0.0), (0.032, 0.02, 0.042), SMG, bevel=0.004)
    sling_loop(g, 0.012, -0.022, color=STEEL)


# ── handguards (origin at the front of the receiver on the bore axis) ────────
@gpart("SPR_HG_SLIM", 2, 1, family="spr")
def spr_hg_slim(P):
    p = P("polymer")
    # slim handguard under the cocking tube: round belly, flat top
    side(p, [(0.0, 0.004), (-0.118, 0.004), (-0.124, -0.002), (-0.124, -0.022), (-0.11, -0.03), (-0.01, -0.03), (0.0, -0.024)], 0.034, POLY, bevel=0.008)
    for k in range(6):
        p.box((0.0172, -0.018 - k * 0.0175, -0.014), (0.0012, 0.007, 0.014), shade(POLY, 0.5), bevel=0.003)
    P.anchor("hand", (0, -0.07, -0.03))


@gpart("SPR_HG_TRI", 2, 1, family="spr")
def spr_hg_tri(P):
    g = P("gunmetal")
    box(g, (0, -0.062, -0.006), (0.038, 0.124, 0.042), BLACK, bevel=0.008)
    pica(g, -0.006, -0.12, -0.027, face="bottom")
    pica(g, -0.006, -0.12, -0.006, x=0.019, face="left")
    pica(g, -0.006, -0.12, -0.006, x=-0.019, face="right")
    for k in range(3):
        g.box((0.016, -0.03 - k * 0.032, 0.012), (0.0012, 0.018, 0.006), shade(BLACK, 0.25), bevel=0.0015)
    P.slot("foregrip", (0, -0.07, -0.0365))
    P.slot("tactical", (0.0285, -0.095, -0.006), rot=(0, -90, 0))
    P.anchor("hand", (0, -0.065, -0.037))


# ── claw mount (origin on the receiver's claw bosses) ────────────────────────
@gpart("SPR_MNT_CLAW", 2, 1, family="spr", margin=0.08, view="left_hi")
def spr_mnt_claw(P):
    g = P("gunmetal")
    side(g, [(0.06, 0.0), (-0.07, 0.0), (-0.07, 0.016), (0.06, 0.016)], 0.03, BLACK, bevel=0.003)
    for y in (0.06, -0.0, -0.06):                                         # claws
        for sx in (-1, 1):
            g.box((sx * 0.0135, y, -0.006), (0.003, 0.01, 0.012), BLACK, bevel=0.001)
    g.box((0.017, 0.02, 0.006), (0.004, 0.026, 0.007), BLACK2, bevel=0.0015)   # lever
    pica(g, 0.055, -0.065, 0.016)
    P.slot("scope", (0, -0.005, 0.016 + 0.0095))


# ── muzzle device ────────────────────────────────────────────────────────────
@gpart("SPR_FH_3L", 1, 1, family="spr", margin=0.14, view="left_hi")
def spr_fh_3l(P):
    g = P("gunmetal")
    ybar(g, 0.012, -0.044, 0.0, 0.0128, SMG, seg=18)
    for k in range(4):
        a = math.pi / 2 + (k - 1.5) * 0.7
        g.box((0.0128 * math.cos(a), -0.028, 0.0128 * math.sin(a)), (0.0016, 0.022, 0.0034), shade(SMG, 0.15), rot=(0, -a, 0))
    ring(g, 0.006, 0.0, 0.0128, 0.0012, shade(SMG, 1.2), seg=18, l=0.006)
    P.anchor("muzzle", (0, -0.044, 0.0))


# ── magazines ────────────────────────────────────────────────────────────────
@gpart("SPARROW_MAG", 1, 2, family="spr", margin=0.12)
def sparrow_mag(P):
    m = P("metal")
    box_mag(m, 0.205, 0.0235, 0.036, 14, col("3F4346"), ribs=(), witness=5, wcol=shade(col("3F4346"), 0.25))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.028)


@gpart("SPR_MAG50", 2, 2, family="spr", margin=0.08, view="left_hi")
def spr_mag50(P):
    """50-round drum: a feed tower into the magazine well and the drum below"""
    m, p = P("metal"), P("polymer")
    box_mag(m, 0.07, 0.0235, 0.036, 6, col("3F4346"), ribs=(), feed=True)
    p.cyl((-0.032, -0.0, -0.11), (0.032, -0.0, -0.11), 0.058, POLY, seg=32, smooth=True)
    p.cyl((0.032, 0.0, -0.11), (0.036, 0.0, -0.11), 0.05, POLY2, seg=32)
    p.cyl((0.036, 0.0, -0.11), (0.041, 0.0, -0.11), 0.012, shade(POLY, 1.3), seg=16)   # winding key
    p.box((0.042, 0.0, -0.11), (0.003, 0.03, 0.006), shade(POLY, 1.3), bevel=0.001)
    for k in range(12):
        a = k * math.pi / 6
        p.box((0.0325, 0.044 * math.cos(a), -0.11 + 0.044 * math.sin(a)), (0.001, 0.004, 0.012), shade(POLY, 0.6), rot=(-a, 0, 0))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.028)


preset("SPARROW_SMG", "SPARROW_SMG", {"grip": ("SPR_GRIP_STD", {}), "stock": ("SPR_STK_SLIDE", {}), "handguard": ("SPR_HG_SLIM", {}),
                                      "mag": ("SPARROW_MAG", {})})
preset("SPR_TAC", "SPARROW_SMG", {"grip": ("SPR_GRIP_NAVY", {}), "stock": ("SPR_STK_FIXED", {}),
                                  "handguard": ("SPR_HG_TRI", {"foregrip": ("GRIP_V", {}), "tactical": ("LASER_COMBO", {})}),
                                  "muzzle": ("SUPP_9", {}), "mount": ("SPR_MNT_CLAW", {"scope": ("RED_DOT", {})}), "mag": ("SPARROW_MAG", {})})

"""Zero Return - R-17 Carbine parts (AR-type 6.2x40 rifle, original design). See zr_guns.py for the conventions.

Frame of the lower and upper receivers: bore axis z = 0, receiver rear y = 0, parting line z = -0.012, upper rail
top z = 0.0305, receiver face y = -0.19. Iron sight line 0.066 above the bore (front post and rear aperture).
"""
import math
from mathutils import Vector, Matrix
from zr_items import col, shade, mixc, R
from zr_guns import (gpart, preset, Part, side, box, ybar, ring, ylathe, pica, slots_row, screw, pin, vents, grip_profile,
                     box_mag, round_top, trigger_guard, trigger, sling_loop, lens, dot, suppressor,
                     BLACK, BLACK2, PARK, BLUED, STEEL, BRIGHT, POLY, POLY2, FDE, ODG, RUBBER, WHITE)

RAIL_TOP = 0.0305
SIGHT_H = 0.066 - RAIL_TOP     # iron sight line above a rail top
MAGC = col("3E4440")


# ── lower receiver (the weapon item) ─────────────────────────────────────────
@gpart("R17_RIFLE", 5, 2, family="r17", margin=0.03)
def r17_lower(P):
    g = P("gunmetal")
    W = 0.0235
    prof = [(-0.166, -0.012), (-0.168, -0.050), (-0.163, -0.066), (-0.155, -0.073), (-0.086, -0.073), (-0.081, -0.064),
            (-0.079, -0.041), (-0.026, -0.041), (-0.018, -0.037), (0.004, -0.034), (0.012, -0.029), (0.012, 0.012),
            (-0.003, 0.012), (-0.005, -0.012)]
    side(g, prof, W, BLACK, bevel=0.0016)
    # raised panels: the magazine well, the trigger pocket and the rear, with a bevelled step between them
    side(g, [(-0.163, -0.016), (-0.165, -0.05), (-0.159, -0.064), (-0.09, -0.064), (-0.086, -0.016)], W + 0.0016, shade(BLACK, 1.06), bevel=0.0008)
    side(g, [(-0.072, -0.016), (-0.072, -0.038), (-0.03, -0.038), (-0.008, -0.031), (-0.004, -0.016)], W + 0.0012, shade(BLACK, 1.04), bevel=0.0006)
    # magwell flare, front pivot lug, fences around the magazine release
    box(g, (0, -0.120, -0.0695), (W + 0.004, 0.072, 0.0075), BLACK2, bevel=0.0016)
    box(g, (0, -0.160, -0.010), (0.012, 0.012, 0.008), BLACK, bevel=0.002)
    for sx in (-1, 1):
        box(g, (sx * (W / 2 + 0.0014), -0.0795, -0.026), (0.0028, 0.005, 0.024), BLACK2, bevel=0.0008)
        box(g, (sx * (W / 2 + 0.0012), -0.0725, -0.039), (0.0024, 0.018, 0.004), BLACK2, bevel=0.0008)
    for k in range(2):                                                  # magwell grip ribs
        g.box((W / 2 + 0.0012, -0.126, -0.046 - k * 0.008), (0.0012, 0.05, 0.0022), shade(BLACK, 1.18), bevel=0.0004)
    # pins
    for y, z in ((-0.159, -0.016), (0.003, -0.019), (-0.044, -0.027), (-0.061, -0.027)):
        pin(g, y, z, 0.0021, W, shade(STEEL, 0.75))
    # left side: selector, bolt catch, markings
    s = P("metal")
    s.cyl((W / 2, -0.016, -0.026), (W / 2 + 0.0022, -0.016, -0.026), 0.0062, STEEL, seg=14)
    s.box((W / 2 + 0.0026, -0.009, -0.0215), (0.0025, 0.016, 0.0042), shade(STEEL, 0.9), rot=(R(-30), 0, 0), bevel=0.0008)
    for k, a in enumerate((-55, 0, 55)):
        g.box((W / 2 + 0.0004, -0.016 + 0.0105 * math.sin(R(a + 90)), -0.026 + 0.0105 * math.cos(R(a + 90))), (0.0005, 0.0024, 0.0014), WHITE)
    g.box((W / 2 + 0.0018, -0.089, -0.021), (0.0036, 0.006, 0.02), BLACK2, bevel=0.0008)       # bolt catch paddle
    g.box((W / 2 + 0.0004, -0.118, -0.024), (0.0005, 0.036, 0.0035), shade(WHITE, 0.55))        # stamped markings
    g.box((W / 2 + 0.0004, -0.118, -0.031), (0.0005, 0.026, 0.0025), shade(WHITE, 0.5))
    # right side: magazine release
    s.cyl((-W / 2, -0.078, -0.035), (-W / 2 - 0.003, -0.078, -0.035), 0.0045, STEEL, seg=12)
    # trigger guard and trigger
    trigger_guard(g, -0.031, -0.078, -0.041, color=BLACK2)
    trigger(s, -0.05, -0.041, color=STEEL)
    # receiver extension (buffer tube) with castle nut, end plate and stock lock holes
    ybar(g, 0.012, 0.200, -0.002, 0.0145, BLACK, seg=20)
    ybar(g, 0.0125, 0.0195, -0.002, 0.0172, BLACK2, seg=12)
    for k in range(6):
        a = k * math.pi / 3 + 0.3
        g.box((0.0172 * math.cos(a), 0.016, -0.002 + 0.0172 * math.sin(a)), (0.004, 0.0072, 0.004), shade(BLACK, 0.4), rot=(0, -a, 0))
    g.box((0, 0.0122, -0.004), (0.03, 0.0018, 0.036), BLACK2, bevel=0.0006)                         # end plate
    sling_loop(s, 0.0122, 0.012, x=0.016, color=STEEL, r=0.0012, s=0.004)
    for k in range(6):
        g.box((0, 0.095 + k * 0.018, -0.0168), (0.004, 0.006, 0.0012), shade(BLACK, 0.35))
    ybar(g, 0.2, 0.203, -0.002, 0.0125, BLACK2, seg=16)
    P.slot("upper", (0, 0, 0))
    P.slot("grip", (0, -0.012, -0.036))
    P.slot("stock", (0, 0.0195, -0.002))
    P.slot("mag", (0, -0.119, -0.033))
    P.anchor("eye", (0, -0.02, 0.058))
    P.anchor("hand", (0, -0.32, -0.025))


# ── upper receiver ───────────────────────────────────────────────────────────
@gpart("R17_UPPER", 3, 1, family="r17")
def r17_upper(P):
    g = P("gunmetal")
    W = 0.025
    prof = [(-0.190, -0.012), (-0.190, 0.021), (-0.004, 0.021), (-0.004, 0.0135), (0.002, 0.0135), (0.002, -0.012)]
    side(g, prof, W, BLACK, bevel=0.0014)
    ybar(g, -0.188, -0.193, 0, 0.0158, BLACK2, seg=20)                  # receiver face threads
    pica(g, -0.004, -0.186, 0.021, color=BLACK)
    for k in range(0, 18, 2):                                           # rail T-marks
        g.box((0.0108, -0.009 - k * 0.0102, 0.026), (0.0004, 0.0012, 0.0026), WHITE)
    # right side: ejection port with its closed cover, brass deflector, forward assist
    g.box((-W / 2 - 0.0003, -0.083, 0.004), (0.0008, 0.064, 0.016), shade(BLACK, 0.5), bevel=0.0004)
    g.box((-W / 2 - 0.0009, -0.083, 0.004), (0.0008, 0.06, 0.0145), BLACK2, bevel=0.0004)
    g.box((-W / 2 - 0.0014, -0.073, 0.0105), (0.0008, 0.006, 0.0025), STEEL)
    side(g, [(-0.045, 0.006), (-0.034, 0.006), (-0.030, 0.019), (-0.045, 0.019)], 0.006, BLACK, x=-W / 2 - 0.002)
    s = P("metal")
    g.cyl((-0.011, -0.026, 0.006), (-0.019, -0.012, 0.006), 0.0062, BLACK, seg=14)
    s.cyl((-0.019, -0.012, 0.006), (-0.021, -0.0085, 0.006), 0.0068, STEEL, seg=14)
    # left side: a shallow relief and the case deflector line
    g.box((W / 2 + 0.0003, -0.11, 0.004), (0.0006, 0.12, 0.012), shade(BLACK, 1.12), bevel=0.0003)
    P.slot("barrel", (0, -0.19, 0))
    P.slot("handguard", (0, -0.19, 0))
    P.slot("charge", (0, 0.002, 0.0135))
    P.slot("scope", (0, -0.098, RAIL_TOP))
    P.slot("rearsight", (0, -0.012, RAIL_TOP))
    P.anchor("port", (-0.013, -0.083, 0.005))
    P.anchor("eye", (0, -0.02, 0.058))


# ── charging handles ─────────────────────────────────────────────────────────
def charging_handle(P, latch):
    g = P("gunmetal")
    g.box((0, 0.004, 0.0), (0.016, 0.02, 0.0065), BLACK, bevel=0.0012)
    g.box((0, 0.012, 0.0), (0.042, 0.0075, 0.0065), BLACK, bevel=0.0018)
    for sx in (-1, 1):
        for k in range(3):
            g.box((sx * (0.012 + k * 0.0035), 0.0158, 0.0), (0.0012, 0.0006, 0.005), shade(BLACK, 0.5))
    lw, ll = latch
    g.box((0.021 + lw / 2, 0.006, 0.0), (lw, ll, 0.0058), BLACK2, bevel=0.001)
    if lw > 0.008:
        for k in range(4):
            g.box((0.021 + lw - 0.001, 0.0 + k * 0.0035, 0.0), (0.0012, 0.0012, 0.006), shade(BLACK2, 0.55))


@gpart("AR_CH_STD", 1, 1, family="r17", view="left_hi", margin=0.12)
def ar_ch_std(P):
    charging_handle(P, (0.006, 0.012))


@gpart("AR_CH_EXT", 1, 1, family="r17", view="left_hi", margin=0.12)
def ar_ch_ext(P):
    charging_handle(P, (0.014, 0.018))


# ── barrels ──────────────────────────────────────────────────────────────────
GAS_AT = 0.185


def ar_barrel(P, L, fluted=False):
    g = P("gunmetal")
    ybar(g, 0.0, -0.012, 0, 0.0168, BLACK, seg=24)                     # barrel nut
    for k in range(12):
        a = k * math.pi / 6
        g.box((0.0168 * math.cos(a), -0.006, 0.0168 * math.sin(a)), (0.004, 0.012, 0.004), shade(BLACK, 0.45), rot=(0, -a, 0))
    ybar(g, -0.012, -GAS_AT + 0.016, 0, 0.0096, PARK, seg=18)
    ybar(g, -GAS_AT + 0.016, -GAS_AT - 0.016, 0, 0.0098, shade(PARK, 0.9), seg=18)
    ybar(g, -GAS_AT - 0.016, -L + 0.012, 0, 0.0084, PARK, seg=18)
    if fluted:
        for k in range(6):
            a = k * math.pi / 3
            g.box((0.0084 * math.cos(a), -(GAS_AT + 0.016 + L - 0.012) / 2, 0.0084 * math.sin(a)), (0.0016, L - GAS_AT - 0.06, 0.0016),
                  shade(PARK, 0.55), rot=(0, -a, 0))
    s = P("metal")
    ybar(s, -L + 0.012, -L, 0, 0.0071, shade(STEEL, 0.6), seg=14)        # thread
    for k in range(5):
        ring(s, -L + 0.0105 - k * 0.0022, 0, 0.0071, 0.0004, shade(STEEL, 0.45), seg=14, l=0.0009)
    P.slot("gas", (0, -GAS_AT, 0))
    P.slot("muzzle", (0, -L + 0.012, 0))     # a muzzle device screws over the thread up to its shoulder
    P.anchor("muzzle", (0, -L, 0))


@gpart("R17_BRL_105", 3, 1, family="r17")
def r17_brl_105(P):
    ar_barrel(P, 0.267)


@gpart("R17_BRL_145", 4, 1, family="r17")
def r17_brl_145(P):
    ar_barrel(P, 0.368)


@gpart("R17_BRL_18", 5, 1, family="r17")
def r17_brl_18(P):
    ar_barrel(P, 0.457, fluted=True)


# ── gas blocks ───────────────────────────────────────────────────────────────
@gpart("R17_GAS_FSP", 1, 1, family="r17", margin=0.1)
def r17_gas_fsp(P):
    g = P("gunmetal")
    ybar(g, 0.016, -0.016, 0, 0.0142, BLACK, seg=18)
    side(g, [(0.013, 0.008), (-0.013, 0.008), (-0.006, 0.047), (0.006, 0.047)], 0.012, BLACK, bevel=0.0012)
    for sx in (-1, 1):                                                   # protective ears
        g.box((sx * 0.0072, 0.0, 0.056), (0.0024, 0.009, 0.02), BLACK, bevel=0.0007)
    g.box((0, 0.0, 0.048), (0.0168, 0.009, 0.004), BLACK, bevel=0.0008)
    s = P("metal")
    s.box((0, 0.0, 0.058), (0.0024, 0.0024, 0.018), shade(STEEL, 0.5))   # front post (top at the sight line)
    g.box((0, -0.004, -0.017), (0.006, 0.02, 0.008), BLACK, bevel=0.0012)  # bayonet lug
    s.torus((0, 0.006, -0.02), 0.0055, 0.0013, STEEL, segU=12, segV=5, rot=(0, R(90), 0))
    for y in (0.008, -0.008):
        g.cyl((-0.0145, y, 0.004), (0.0145, y, 0.004), 0.0016, shade(STEEL, 0.6), seg=6)
    P.anchor("frontsight", (0, 0, 0.066))


@gpart("R17_GAS_LOW", 1, 1, family="r17", margin=0.16, view="three_q_low")
def r17_gas_low(P):
    g = P("gunmetal")
    ybar(g, 0.012, -0.012, 0, 0.0128, BLACK, seg=18)
    g.box((0, 0.0, 0.0105), (0.016, 0.022, 0.006), BLACK, bevel=0.0015)
    for y in (0.006, -0.006):
        screw(g, 0, y, 0.0137, r=0.0022, color=shade(STEEL, 0.6), axis="z")


# ── handguards ───────────────────────────────────────────────────────────────
@gpart("R17_HG_CARB", 3, 1, family="r17")
def r17_hg_carb(P):
    g, p = P("gunmetal"), P("polymer")
    ybar(g, -0.003, -0.016, 0, 0.0266, BLACK, seg=24)                    # delta ring
    ring(g, -0.0095, 0, 0.0266, 0.0012, BLACK2, seg=24, l=0.002)
    ybar(p, -0.016, -0.166, 0, 0.0232, POLY, seg=20)
    for k in range(10):                                                  # ribs
        a = k * math.pi / 5 + math.pi / 10
        p.box((0.0232 * math.cos(a), -0.091, 0.0232 * math.sin(a)), (0.0032, 0.146, 0.0042), POLY2, rot=(0, -a, 0), bevel=0.0009)
    for zrow in (0.008, -0.008):                                         # vents between the ribs
        vents(p, -0.03, -0.155, 6, zrow, 0.0235, shade(POLY, 0.3), r=0.0032)
    p.box((0.0236, -0.091, 0.0), (0.0006, 0.146, 0.0009), shade(POLY, 0.45))   # parting line
    ybar(g, -0.166, -0.172, 0, 0.0225, BLACK, seg=20)                    # cap
    P.anchor("hand", (0, -0.108, -0.024))


@gpart("R17_HG_QUAD", 3, 1, family="r17")
def r17_hg_quad(P):
    g = P("gunmetal")
    ybar(g, -0.0, -0.009, 0, 0.0255, BLACK2, seg=24)
    box(g, (0, -0.088, 0), (0.042, 0.158, 0.042), BLACK, bevel=0.007)
    for face, x, z in (("top", 0, 0.021), ("bottom", 0, -0.021)):
        pica(g, -0.012, -0.166, z, face=face)
    for face, x in (("left", 0.021), ("right", -0.021)):
        pica(g, -0.012, -0.166, 0.0, x=x, face=face)
    for k in range(4):                                                   # vents between the rails
        a = k * math.pi / 2 + math.pi / 4
        for j in range(5):
            y = -0.03 - j * 0.028
            g.box((0.0262 * math.cos(a), y, 0.0262 * math.sin(a)), (0.0016, 0.016, 0.0055), shade(BLACK, 0.3), rot=(0, -a, 0), bevel=0.002)
    for y in (-0.02, -0.16):
        screw(g, 0.016, y, 0.016, r=0.002, color=shade(STEEL, 0.5), axis="x")
    P.slot("foregrip", (0, -0.112, -0.0305))
    P.slot("tactical", (0.0305, -0.142, 0.0), rot=(0, -90, 0))
    P.slot("top", (0, -0.152, RAIL_TOP))
    P.anchor("hand", (0, -0.1, -0.034))


@gpart("R17_HG_MLOK", 5, 1, family="r17")
def r17_hg_mlok(P):
    g = P("gunmetal")
    L = 0.33
    ybar(g, 0.0, -0.011, 0, 0.0245, BLACK2, seg=24)                      # barrel nut
    box(g, (0, -L / 2 - 0.004, 0), (0.0405, L - 0.008, 0.042), BLACK, bevel=0.0095)
    pica(g, -0.006, -L + 0.004, 0.021)
    slots_row(g, -0.03, -0.31, 7, 0.0, shade(BLACK, 0.18), x=0.02025, face="left")
    slots_row(g, -0.03, -0.31, 7, 0.0, shade(BLACK, 0.18), x=-0.02025, face="right")
    slots_row(g, -0.03, -0.12, 3, -0.021, shade(BLACK, 0.18), face="bottom")
    slots_row(g, -0.21, -0.31, 3, -0.021, shade(BLACK, 0.18), face="bottom")
    pica(g, -0.132, -0.192, -0.021, face="bottom", teeth=True)          # short rail for a foregrip
    pica(g, -0.266, -0.304, 0.0, x=0.02025, face="left")                # short rail for a light
    for y in (-0.135, -0.188, -0.27, -0.3):
        screw(g, 0.0, y, -0.0285, r=0.0018, color=shade(STEEL, 0.5), axis="z", slot=False)
    ybar(g, -L + 0.004, -L, 0, 0.0218, BLACK2, seg=8)
    P.slot("foregrip", (0, -0.162, -0.0305))
    P.slot("tactical", (0.0298, -0.285, 0.0), rot=(0, -90, 0))
    P.slot("top", (0, -0.31, RAIL_TOP))
    P.anchor("hand", (0, -0.15, -0.034))


# ── stocks (origin on the buffer tube behind the castle nut) ─────────────────
@gpart("AR_STK_CARB", 2, 1, family="r17")
def ar_stk_carb(P):
    p, r, g = P("polymer"), P("rubber"), P("gunmetal")
    # body: a tube housing with a cheek riser, the butt and a sloped lower web
    prof = [(0.084, 0.018), (0.12, 0.018), (0.128, 0.026), (0.198, 0.027), (0.205, 0.022), (0.205, -0.08), (0.196, -0.083),
            (0.17, -0.06), (0.124, -0.026), (0.104, -0.02), (0.093, -0.02), (0.084, -0.013)]
    side(p, prof, 0.036, POLY, bevel=0.003)
    side(p, [(0.128, 0.013), (0.2, 0.013), (0.2, -0.003), (0.128, -0.003)], 0.0405, shade(POLY, 1.08), bevel=0.0025)   # tube housing
    side(p, [(0.15, -0.012), (0.193, -0.012), (0.193, -0.062), (0.176, -0.052)], 0.0375, shade(POLY, 0.3), bevel=0.001)  # lightening pocket
    p.box((0, 0.183, -0.068), (0.039, 0.016, 0.006), shade(POLY, 0.2), rot=(R(-38), 0, 0), bevel=0.0018)  # sling slot
    side(r, [(0.205, 0.0245), (0.218, 0.0245), (0.218, -0.084), (0.205, -0.084)], 0.039, RUBBER, bevel=0.0025)
    for k in range(6):
        r.box((0.0197, 0.2115, 0.016 - k * 0.0175), (0.0006, 0.012, 0.0045), shade(RUBBER, 1.7))
    g.box((0, 0.1, -0.021), (0.008, 0.028, 0.0065), BLACK2, bevel=0.0015)          # adjustment lever
    g.cyl((0.0205, 0.112, 0.006), (0.0225, 0.112, 0.006), 0.0042, STEEL, seg=12)      # QD sling socket
    p.box((0.0185, 0.16, 0.019), (0.0006, 0.06, 0.0018), shade(POLY, 1.4))
    P.anchor("cheek", (0, 0.14, 0.026))


@gpart("AR_STK_A2", 3, 1, family="r17")
def ar_stk_a2(P):
    p, r, g = P("polymer"), P("rubber"), P("metal")
    prof = [(0.0, 0.016), (0.25, 0.026), (0.25, -0.092), (0.24, -0.094), (0.12, -0.038), (0.03, -0.022), (0.0, -0.018)]
    side(p, prof, 0.042, POLY, bevel=0.004)
    g.box((0.0, 0.255, -0.034), (0.044, 0.008, 0.11), shade(STEEL, 0.55), bevel=0.003)  # butt plate with trap door
    g.box((0.022, 0.255, -0.03), (0.0006, 0.005, 0.05), shade(STEEL, 0.35))
    sling_loop(g, 0.205, -0.079, color=STEEL)
    for k in range(4):
        p.box((0.0212, 0.06 + k * 0.035, -0.002), (0.0006, 0.012, 0.0012), shade(POLY, 1.3))


@gpart("AR_STK_SKEL", 2, 1, family="r17")
def ar_stk_skel(P):
    g, r = P("gunmetal"), P("rubber")
    ybar(g, 0.06, 0.19, 0.0, 0.017, BLACK, seg=16)                       # tube collar
    g.tube([(0, 0.07, -0.014), (0, 0.13, -0.05), (0, 0.205, -0.07)], 0.0058, BLACK, seg=10, caps=True)
    g.tube([(0, 0.19, 0.012), (0, 0.205, 0.012)], 0.006, BLACK, seg=10, caps=True)
    side(g, [(0.198, 0.02), (0.21, 0.02), (0.21, -0.078), (0.198, -0.078)], 0.022, BLACK, bevel=0.003)
    side(r, [(0.21, 0.022), (0.22, 0.022), (0.22, -0.08), (0.21, -0.08)], 0.03, RUBBER, bevel=0.003)
    g.box((0, 0.075, -0.018), (0.008, 0.02, 0.006), BLACK2, bevel=0.0015)


# ── pistol grips (origin at the lower's grip seat) ───────────────────────────
@gpart("AR_PG_A2", 1, 2, family="r17", margin=0.1)
def ar_pg_a2(P):
    p = P("polymer")
    side(p, grip_profile(0.004, 0.0, 19, 0.094, 0.039, grooves=1, swell=0.003), 0.028, POLY, bevel=0.0035)
    for k in range(6):                                                   # side checkering
        for j in range(4):
            p.box((0.0142, 0.012 + j * 0.005 + k * 0.0035, -0.03 - k * 0.0095), (0.0008, 0.003, 0.0045), shade(POLY, 0.55))
    P.anchor("grip", (0, 0.012, -0.045))


@gpart("AR_PG_ERGO", 1, 2, family="r17", margin=0.1)
def ar_pg_ergo(P):
    p, r = P("polymer"), P("rubber")
    side(p, grip_profile(0.005, 0.0, 17, 0.104, 0.038, grooves=3, swell=0.0), 0.03, ODG, bevel=0.004)
    side(r, grip_profile(0.0065, -0.012, 17, 0.08, 0.026, grooves=0), 0.031, shade(ODG, 0.7), bevel=0.0025)
    P.anchor("grip", (0, 0.012, -0.047))


@gpart("AR_PG_ANG", 1, 2, family="r17", margin=0.1)
def ar_pg_ang(P):
    p = P("polymer")
    side(p, grip_profile(0.007, 0.0, 26, 0.098, 0.032, grooves=0), 0.026, FDE, bevel=0.0035)
    p.box((0, 0.052, -0.094), (0.024, 0.026, 0.006), shade(FDE, 0.7), rot=(R(26), 0, 0), bevel=0.002)   # storage cap
    for k in range(7):
        p.box((0.0132, 0.018 + k * 0.0042, -0.03 - k * 0.008), (0.0006, 0.002, 0.03), shade(FDE, 0.7), rot=(R(26), 0, 0))
    P.anchor("grip", (0, 0.016, -0.044))


# ── iron sights (origin on the rail top) ─────────────────────────────────────
@gpart("R17_RS_FLIP", 1, 1, family="r17", margin=0.12)
def r17_rs_flip(P):
    g, s = P("gunmetal"), P("metal")
    g.box((0, 0.0, 0.004), (0.0235, 0.034, 0.008), BLACK, bevel=0.0018)
    g.box((0, 0.0, 0.0005), (0.0172, 0.03, 0.002), BLACK2)                 # rail clamp jaws
    s.cyl((0.012, 0.004, 0.004), (0.016, 0.004, 0.004), 0.0042, STEEL, seg=12)    # clamp knob
    g.box((0, 0.006, 0.021), (0.0145, 0.006, 0.027), BLACK, bevel=0.0014)    # tower
    for sx in (-1, 1):
        g.box((sx * 0.0085, 0.006, 0.034), (0.0025, 0.007, 0.017), BLACK, bevel=0.0007)
    g.torus((0, 0.006, SIGHT_H), 0.0042, 0.0016, BLACK, segU=14, segV=5, rot=(R(90), 0, 0))
    g.box((0, 0.006, SIGHT_H + 0.0072), (0.008, 0.005, 0.003), BLACK, bevel=0.0008)
    P.anchor("eye", (0, 0.012, SIGHT_H))


@gpart("R17_FS_FLIP", 1, 1, family="r17", margin=0.12)
def r17_fs_flip(P):
    g, s = P("gunmetal"), P("metal")
    g.box((0, 0.0, 0.004), (0.0235, 0.03, 0.008), BLACK, bevel=0.0018)
    s.cyl((0.012, -0.004, 0.004), (0.016, -0.004, 0.004), 0.004, STEEL, seg=12)
    g.box((0, -0.002, 0.018), (0.012, 0.007, 0.022), BLACK, bevel=0.0012)
    for sx in (-1, 1):
        g.box((sx * 0.007, -0.002, 0.028), (0.0024, 0.008, 0.02), BLACK, bevel=0.0007)
    s.box((0, -0.002, SIGHT_H - 0.006), (0.0024, 0.0024, 0.012), shade(STEEL, 0.5))
    P.anchor("frontsight", (0, -0.002, SIGHT_H))


# ── muzzle devices (origin at the thread, pointing -Y) ───────────────────────
@gpart("R17_FH_A2", 1, 1, family="r17", margin=0.14, view="left_hi")
def r17_fh_a2(P):
    g = P("gunmetal")
    ring(g, -0.001, 0, 0.0092, 0.0018, BLACK2, seg=16, l=0.002)          # crush washer
    ybar(g, -0.002, -0.057, 0, 0.0107, BLACK, seg=18)
    for k in range(5):                                                    # birdcage slots (closed underneath)
        a = math.pi / 2 + (k - 2) * 0.62
        g.box((0.0108 * math.cos(a), -0.033, 0.0108 * math.sin(a)), (0.0016, 0.028, 0.0034), shade(BLACK, 0.18), rot=(0, -a, 0))
    ybar(g, -0.0565, -0.0575, 0, 0.0085, shade(BLACK, 0.3), seg=16)
    P.anchor("muzzle", (0, -0.057, 0))


@gpart("R17_BRK", 1, 1, family="r17", margin=0.14, view="left_hi")
def r17_brk(P):
    g = P("gunmetal")
    ybar(g, -0.0, -0.062, 0, 0.0124, BLACK, seg=20)
    for k in range(3):
        for sx in (-1, 1):
            g.box((sx * 0.0118, -0.02 - k * 0.0135, 0.0), (0.004, 0.0075, 0.012), shade(BLACK, 0.12), bevel=0.0012)
    for k in range(2):
        g.box((0, -0.026 - k * 0.016, 0.0118), (0.006, 0.006, 0.0035), shade(BLACK, 0.12), bevel=0.0015)
    ybar(g, -0.0615, -0.0625, 0, 0.0095, shade(BLACK, 0.3), seg=16)
    P.anchor("muzzle", (0, -0.062, 0))


@gpart("R17_COMP", 1, 1, family="r17", margin=0.14, view="left_hi")
def r17_comp(P):
    g = P("gunmetal")
    ylathe(g, [(0.0095, 0.0), (0.0118, 0.004), (0.0118, 0.044), (0.0098, 0.05)], BLACK, seg=20)
    for k in range(3):
        g.cyl((0, -0.016 - k * 0.011, 0.008), (0, -0.016 - k * 0.011, 0.0125), 0.0028, shade(BLACK, 0.12), seg=10)
    for sx in (-1, 1):
        g.box((sx * 0.0112, -0.04, 0.0), (0.003, 0.012, 0.007), shade(BLACK, 0.15), bevel=0.0015)
    P.anchor("muzzle", (0, -0.05, 0))


@gpart("SUPP_62", 2, 1, family="r17", margin=0.07)
def supp_62(P):
    suppressor(P, 0.175, 0.0195, BLACK)


@gpart("SUPP_62C", 2, 1, family="r17", margin=0.08)
def supp_62c(P):
    suppressor(P, 0.115, 0.0185, col("2D2F2C"))


# ── magazines (origin at the top, inside the magazine well) ──────────────────
@gpart("R17_MAG", 1, 2, family="r17", margin=0.12)
def r17_mag(P):
    m = P("metal")
    box_mag(m, 0.172, 0.0225, 0.061, 8, MAGC, witness=0)
    for k in range(3):                                                   # stiffening ribs on the side
        m.box((0.0115, -0.004, -0.06 - k * 0.032), (0.0008, 0.042, 0.0035), shade(MAGC, 1.15), bevel=0.0003)
    round_top(P("brass"), -0.004, 0.003, r=0.0046, l=0.034)


@gpart("R17_MAG40", 1, 3, family="r17", margin=0.1)
def r17_mag40(P):
    m = P("metal")
    box_mag(m, 0.245, 0.0225, 0.061, 12, col("3A403D"))
    for k in range(4):
        m.box((0.0115, -0.004 - k * 0.002, -0.06 - k * 0.04), (0.0008, 0.04, 0.0035), shade(MAGC, 1.15), bevel=0.0003)
    round_top(P("brass"), -0.004, 0.003, r=0.0046, l=0.034)


@gpart("R17_MAG60", 1, 3, family="r17", margin=0.1)
def r17_mag60(P):
    p = P("polymer")
    box_mag(p, 0.06, 0.0225, 0.061, 4, POLY, plate=POLY, ribs=(), feed=True)
    side(p, [(0.029, -0.04), (-0.033, -0.04), (-0.046, -0.215), (0.02, -0.215)], 0.044, POLY, bevel=0.006)
    side(p, [(0.03, -0.215), (-0.048, -0.215), (-0.048, -0.228), (0.03, -0.228)], 0.048, shade(POLY, 0.7), bevel=0.003)
    for k in range(6):
        p.box((0.0222, -0.008 - k * 0.0018, -0.07 - k * 0.022), (0.0008, 0.05, 0.004), shade(POLY, 1.3))
    round_top(P("brass"), -0.004, 0.003, r=0.0046, l=0.034)


# ── default and upgraded builds ──────────────────────────────────────────────
def _r17(barrel="R17_BRL_145", muzzle="R17_FH_A2", gas="R17_GAS_FSP", hg="R17_HG_CARB", stock="AR_STK_CARB",
         grip="AR_PG_A2", ch="AR_CH_STD", mag="R17_MAG", scope=None, rear="R17_RS_FLIP", hg_kids=None):
    upper = {"barrel": (barrel, {"muzzle": (muzzle, {}), "gas": (gas, {})}) if muzzle else (barrel, {"gas": (gas, {})}),
             "handguard": (hg, hg_kids or {}), "charge": (ch, {})}
    if rear:
        upper["rearsight"] = (rear, {})
    if scope:
        upper["scope"] = scope
    return {"grip": (grip, {}), "stock": (stock, {}), "upper": ("R17_UPPER", upper), "mag": (mag, {})}


preset("R17_RIFLE", "R17_RIFLE", _r17())
preset("R17_PATROL", "R17_RIFLE", _r17(hg="R17_HG_QUAD", hg_kids={"foregrip": ("GRIP_V", {}), "tactical": ("LIGHT_T", {})},
                                       scope=("RED_DOT", {}), rear="R17_RS_FLIP", grip="AR_PG_ERGO"))
preset("R17_DMR", "R17_RIFLE", _r17(barrel="R17_BRL_18", muzzle="R17_BRK", gas="R17_GAS_LOW", hg="R17_HG_MLOK",
                                    hg_kids={"foregrip": ("GRIP_ANG", {}), "top": ("R17_FS_FLIP", {})}, stock="AR_STK_A2",
                                    scope=("MNT_RINGS", {"scope": ("SCOPE_16", {})}), mag="R17_MAG40", ch="AR_CH_EXT"))
preset("R17_CQB", "R17_RIFLE", _r17(barrel="R17_BRL_105", muzzle="SUPP_62C", gas="R17_GAS_LOW", hg="R17_HG_QUAD",
                                    hg_kids={"foregrip": ("GRIP_STUB", {}), "tactical": ("LASER_COMBO", {}), "top": ("R17_FS_FLIP", {})},
                                    stock="AR_STK_SKEL", grip="AR_PG_ANG", scope=("HOLO_EX", {})))

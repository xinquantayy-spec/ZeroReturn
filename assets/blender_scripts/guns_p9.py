"""Zero Return - P-9 Vesna parts (9x19 striker pistol, original design). Conventions: zr_guns.py; pictures use the
"pistol" class (more cells per metre, as Tarkov draws pistols larger than rifles).

Frame: bore axis z = 0, slide rear y = 0, slide front y = -0.186, grip raked 20 degrees. Sight line 0.031.
"""
import math
from zr_items import col, shade, R
from zr_guns import (gpart, preset, side, box, ybar, ring, ylathe, pica, screw, pin, grip_profile, box_mag, round_top, trigger,
                     BLACK, BLACK2, PARK, STEEL, BRIGHT, POLY, POLY2, FDE, RUBBER, WHITE)

FRAME = col("2C2F30")
SLIDE = col("34383A")
SL = 0.031


@gpart("P9_PISTOL", 2, 1, family="p9", cls="pistol", margin=0.04)
def p9_frame(P):
    p, s = P("polymer"), P("metal")
    W = 0.026
    # dust cover and frame top under the slide
    side(p, [(0.004, -0.008), (-0.172, -0.008), (-0.172, -0.026), (-0.11, -0.03), (-0.06, -0.03), (-0.02, -0.024), (0.004, -0.02)], W, FRAME, bevel=0.0025)
    pica(p, -0.118, -0.164, -0.028, face="bottom", color=FRAME)
    # grip, raked back, with the textured panels and the beavertail
    side(p, grip_profile(-0.03, -0.018, 20, 0.09, 0.043, grooves=3, swell=0.0015), 0.0285, FRAME, bevel=0.004)
    t = math.tan(R(20))
    for k in range(6):
        for j in range(5):
            dz = 0.03 + k * 0.009
            p.box((0.0146, -0.042 + j * 0.0065 + t * dz, -0.018 - dz), (0.0008, 0.0045, 0.006), shade(FRAME, 0.6))
    side(p, [(-0.008, -0.016), (0.006, -0.018), (0.003, -0.027), (-0.01, -0.03)], 0.024, FRAME, bevel=0.002)    # beavertail
    # trigger guard (squared front) and trigger
    side(p, [(-0.044, -0.026), (-0.05, -0.026), (-0.05, -0.042), (-0.098, -0.042), (-0.098, -0.03), (-0.104, -0.028), (-0.106, -0.047),
             (-0.1, -0.05), (-0.048, -0.05), (-0.044, -0.046)], 0.012, FRAME, bevel=0.0018)     # trigger guard (squared, polymer)
    trigger(s, -0.064, -0.026, color=col("4A4E50"))
    s.box((0.0132, -0.055, -0.016), (0.0016, 0.012, 0.004), STEEL, bevel=0.0006)      # slide stop
    s.box((0.0132, -0.098, -0.014), (0.0014, 0.006, 0.003), STEEL, bevel=0.0005)      # takedown
    s.cyl((0.0128, -0.04, -0.031), (0.0145, -0.04, -0.031), 0.0032, STEEL, seg=10)    # magazine release
    P.slot("slide", (0, 0.0, 0.0))
    P.slot("barrel", (0, -0.012, 0.0))
    P.slot("tactical", (0, -0.141, -0.0375))
    P.slot("mag", (0, -0.034, -0.02), rot=(20, 0, 0))
    P.anchor("grip", (0, -0.016, -0.06))
    P.anchor("hand", (-0.012, -0.01, -0.07))
    P.anchor("eye", (0, -0.006, SL))


# ── slides (origin at the slide rear on the bore axis) ───────────────────────
def slide(P, cut=False):
    g, s = P("gunmetal"), P("metal")
    W = 0.0255
    prof = [(0.002, -0.006), (-0.186, -0.006), (-0.186, 0.016), (-0.18, 0.022), (-0.004, 0.022), (0.002, 0.016)]
    side(g, prof, W, SLIDE, bevel=0.0022)
    for k in range(7):                                                    # rear and front serrations
        g.box((W / 2 + 0.0004, -0.008 - k * 0.0042, 0.008), (0.0008, 0.0018, 0.022), shade(SLIDE, 0.45))
        g.box((W / 2 + 0.0004, -0.15 - k * 0.0042, 0.008), (0.0008, 0.0018, 0.022), shade(SLIDE, 0.45))
    g.box((-W / 2 - 0.0004, -0.06, 0.014), (0.0008, 0.05, 0.014), shade(SLIDE, 0.3))   # ejection port (right side)
    g.box((0, -0.06, 0.0222), (0.016, 0.05, 0.0006), shade(SLIDE, 0.3))
    g.box((W / 2 + 0.0003, -0.1, 0.004), (0.0006, 0.04, 0.003), shade(WHITE, 0.6))     # markings
    if cut:
        g.box((0, -0.03, 0.0215), (0.0215, 0.04, 0.002), shade(SLIDE, 0.55))            # optic cut floor
        P.slot("optic", (0, -0.03, 0.0185))
    # sights: a notched rear and a dotted front post
    side(s, [(-0.002, 0.022), (-0.014, 0.022), (-0.014, SL + 0.002), (-0.006, SL + 0.002)], 0.018, BLACK, bevel=0.0012)
    s.box((0, -0.008, SL + 0.0015), (0.0034, 0.009, 0.004), shade(BLACK, 0.3))
    for sx in (-1, 1):
        P("emissive").cyl((sx * 0.0052, -0.0141, SL - 0.0005), (sx * 0.0052, -0.0143, SL - 0.0005), 0.0011, WHITE, seg=6)
    side(s, [(-0.172, 0.022), (-0.18, 0.022), (-0.18, SL), (-0.172, SL)], 0.0036, BLACK, bevel=0.0008)
    P("emissive").cyl((0.0, -0.18, SL - 0.002), (0.0, -0.1803, SL - 0.002), 0.0012, col("D8E8A0"), seg=6)
    P.anchor("eye", (0, -0.006, SL))


@gpart("P9_SLIDE_STD", 2, 1, family="p9", cls="pistol")
def p9_slide_std(P):
    slide(P)


@gpart("P9_SLIDE_CUT", 2, 1, family="p9", cls="pistol")
def p9_slide_cut(P):
    slide(P, cut=True)


# ── barrels (origin at the chamber) ──────────────────────────────────────────
def p9_barrel(P, thread):
    g = P("metal")
    side(g, [(0.0, 0.005), (-0.04, 0.005), (-0.04, 0.016), (0.0, 0.016)], 0.014, STEEL, bevel=0.0015)   # chamber hood
    ybar(g, -0.04, -0.176, 0.0, 0.0072, STEEL, seg=16)
    if thread:
        ybar(g, -0.176, -0.192, 0.0, 0.0062, shade(STEEL, 0.7), seg=14)
        for k in range(5):
            ring(g, -0.178 - k * 0.003, 0.0, 0.0062, 0.0004, shade(STEEL, 0.45), seg=14, l=0.0011)
        P.slot("muzzle", (0, -0.178, 0.0))
        P.anchor("muzzle", (0, -0.192, 0.0))
    else:
        ybar(g, -0.176, -0.178, 0.0, 0.0045, shade(STEEL, 0.3), seg=14)
        P.anchor("muzzle", (0, -0.176, 0.0))


@gpart("P9_BRL_STD", 2, 1, family="p9", cls="pistol", view="left_hi")
def p9_brl_std(P):
    p9_barrel(P, False)


@gpart("P9_BRL_THR", 2, 1, family="p9", cls="pistol", view="left_hi")
def p9_brl_thr(P):
    p9_barrel(P, True)


@gpart("P9_COMP", 1, 1, family="p9", cls="pistol", margin=0.14, view="left_hi")
def p9_comp(P):
    g = P("gunmetal")
    side(g, [(0.0, -0.012), (-0.038, -0.012), (-0.038, 0.014), (-0.004, 0.014), (0.0, 0.01)], 0.026, SLIDE, bevel=0.003)
    for k in range(3):
        g.box((0, -0.01 - k * 0.0095, 0.0142), (0.009, 0.005, 0.002), shade(SLIDE, 0.15), bevel=0.0015)
    P.anchor("muzzle", (0, -0.038, 0.0))


# ── magazines (origin at the top, hanging straight; the frame turns them with the grip) ──
@gpart("P9_MAG", 1, 1, family="p9", cls="pistol", margin=0.12)
def p9_mag(P):
    m = P("metal")
    box_mag(m, 0.104, 0.0215, 0.034, 0, col("2F3233"), plate=col("232526"), ribs=(), witness=4, wcol=shade(col("2F3233"), 0.25))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.026)


@gpart("P9_MAG33", 1, 2, family="p9", cls="pistol", margin=0.1)
def p9_mag33(P):
    m = P("metal")
    box_mag(m, 0.19, 0.0215, 0.034, 0, col("2F3233"), plate=col("232526"), ribs=(0.62,), witness=6, wcol=shade(col("2F3233"), 0.25))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.026)


preset("P9_PISTOL", "P9_PISTOL", {"slide": ("P9_SLIDE_STD", {}), "barrel": ("P9_BRL_STD", {}), "mag": ("P9_MAG", {})})
preset("P9_TAC", "P9_PISTOL", {"slide": ("P9_SLIDE_CUT", {"optic": ("SIGHT_MICRO", {})}), "barrel": ("P9_BRL_THR", {"muzzle": ("SUPP_9", {})}),
                               "tactical": ("LIGHT_T", {}), "mag": ("P9_MAG33", {})})

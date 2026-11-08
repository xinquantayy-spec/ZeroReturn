"""Zero Return - the guns of economy-1a's tenth slice (2026-11-08), original designs:

- Wren W-21 (EFT's SR-1MP Gyurza, 9x21): a long-slide service pistol with a polymer frame, a squared trigger guard,
  a grip safety strip down the back strap and an 18-round double-stack magazine. Bore axis z = 0, slide rear y = 0,
  muzzle y = -0.2.
- Jay J-21 (EFT's SR-2M Veresk, 9x21): a compact submachine gun with a short receiver, a top rail, a folding front
  grip, the magazine ahead of the trigger guard and a pressed-steel stock folded up over the receiver.
  Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.34. Sight line 0.036.
- Tern T-215 (EFT's VPO-215 Gornostay, .366 TKM = our 9.6x39): a sporting bolt-action rifle on an old military action,
  a walnut stock with a straight comb, a 600 mm barrel, a short top rail over the receiver and a 4-round box magazine.
  Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.82. Sight line 0.034.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, ylathe, pica, box_mag, round_top, trigger, trigger_guard, grip_profile, BLACK, STEEL, BLUED

W21_POLY = col("2B2D2E")
W21_SLIDE = col("3A3E40")
W21_SL = 0.026
J21_STEEL = col("33373A")
J21_POLY = col("2A2C2D")
J21_SL = 0.036
T215_STEEL = col("2E3236")
T215_WOOD = col("5E3A22")
T215_SL = 0.034


@gpart("W21_PISTOL", 2, 1, family="g21", cls="pistol", margin=0.05)
def w21_pistol(P):
    s, g, p = P("metal"), P("gunmetal"), P("polymer")
    W = 0.026
    # the long slide with rear cocking grooves and a front bevel, the sights
    side(g, [(0.004, -0.004), (-0.192, -0.004), (-0.2, 0.002), (-0.2, 0.014), (-0.192, 0.02), (-0.004, 0.02), (0.004, 0.013)], W, W21_SLIDE, bevel=0.003)
    for k in range(9):
        for sx in (-1, 1):
            g.box((sx * (W / 2 + 0.0004), -0.012 - k * 0.0034, 0.008), (0.0008, 0.0014, 0.018), shade(W21_SLIDE, 0.45))
    side(s, [(-0.004, 0.02), (-0.012, 0.02), (-0.012, W21_SL + 0.001), (-0.006, W21_SL + 0.001)], 0.014, BLACK, bevel=0.001)
    side(s, [(-0.186, 0.02), (-0.193, 0.019), (-0.193, W21_SL - 0.001), (-0.188, W21_SL - 0.001)], 0.0035, BLACK, bevel=0.0006)
    s.box((-W / 2 - 0.0006, -0.062, 0.008), (0.0012, 0.018, 0.008), shade(STEEL, 0.6))                    # ejection port edge
    # the polymer frame: dust cover with a short rail, the squared guard, the grip with its back-strap safety
    side(p, [(0.006, -0.004), (-0.17, -0.004), (-0.17, -0.02), (-0.1, -0.026), (-0.03, -0.026), (0.006, -0.018)], W + 0.001, W21_POLY, bevel=0.002)
    pica(p, -0.118, -0.164, -0.026, color=W21_POLY, w=0.02, h=0.006, face="bottom")
    side(p, grip_profile(-0.026, -0.018, 16, 0.104, 0.042, grooves=4, swell=0.0015), 0.0285, W21_POLY, bevel=0.003)
    trigger_guard(p, -0.03, -0.09, -0.026, color=W21_POLY, r=0.0036)
    trigger(s, -0.056, -0.026)
    s.box((0, 0.006, 0.01), (0.007, 0.01, 0.012), shade(STEEL, 1.1), bevel=0.0015)                         # hammer spur
    P.slot("mag", (0, -0.034, -0.02), rot=(16, 0, 0))
    P.anchor("grip", (0, -0.02, -0.06))
    P.anchor("hand", (-0.013, -0.016, -0.07))
    P.anchor("eye", (0, -0.006, W21_SL))
    P.anchor("muzzle", (0, -0.2, 0.0))


@gpart("J21_SMG", 3, 2, family="g21", margin=0.04)
def j21_smg(P):
    g, s, p = P("gunmetal"), P("metal"), P("polymer")
    W = 0.034
    # the short receiver with its top rail and folding irons, the charging handle on the left
    side(g, [(0.0, -0.022), (-0.24, -0.022), (-0.25, -0.012), (-0.25, 0.026), (-0.012, 0.026), (0.0, 0.014)], W, J21_STEEL, bevel=0.003)
    pica(g, -0.006, -0.2, 0.026)
    for y0, y1 in ((-0.004, -0.016), (-0.19, -0.202)):
        side(g, [(y0, 0.0355), (y1, 0.0355), (y1 + 0.002, J21_SL + 0.004), (y0 - 0.002, J21_SL + 0.004)], 0.016, BLACK, bevel=0.001)
    s.box((W / 2 + 0.006, -0.11, 0.012), (0.012, 0.014, 0.008), STEEL, bevel=0.002)
    # the polymer fore-end with its folding front grip, the pistol grip and the guard
    side(p, [(-0.15, -0.022), (-0.25, -0.022), (-0.25, -0.036), (-0.16, -0.036)], 0.036, J21_POLY, bevel=0.003)
    side(p, [(-0.2, -0.036), (-0.226, -0.036), (-0.23, -0.1), (-0.204, -0.1)], 0.026, J21_POLY, bevel=0.003)
    side(p, grip_profile(-0.006, -0.022, 12, 0.1, 0.034, grooves=3), 0.03, J21_POLY, bevel=0.003)
    trigger_guard(g, -0.03, -0.08, -0.022, color=J21_STEEL, r=0.0034)
    trigger(s, -0.052, -0.022)
    # the barrel with a short thread collar and a slotted compensator
    ybar(g, -0.25, -0.31, 0.0, 0.0085, BLUED, seg=16)
    ybar(g, -0.305, -0.34, 0.0, 0.0105, shade(J21_STEEL, 0.8), seg=16)
    for k in range(3):
        g.box((0, -0.312 - k * 0.009, 0.0102), (0.004, 0.004, 0.002), shade(J21_STEEL, 0.3))
    # the pressed-steel stock unfolded behind the receiver: its strut, the hinge and the butt plate
    side(s, [(0.0, 0.012), (0.2, 0.004), (0.2, -0.006), (0.0, 0.0)], 0.022, shade(J21_STEEL, 1.1), bevel=0.0015)
    side(s, [(0.06, -0.004), (0.2, -0.05), (0.2, -0.06), (0.06, -0.014)], 0.018, shade(J21_STEEL, 1.1), bevel=0.0015)
    s.cyl((-0.016, 0.004, 0.006), (0.016, 0.004, 0.006), 0.005, STEEL, seg=10)
    side(s, [(0.198, 0.016), (0.212, 0.016), (0.212, -0.076), (0.198, -0.076)], 0.034, shade(J21_STEEL, 0.9), bevel=0.002)
    P.slot("scope", (0, -0.1, 0.026 + 0.0095))
    P.slot("mag", (0, -0.12, -0.036))
    P.anchor("muzzle", (0, -0.34, 0.0))
    P.anchor("port", (W / 2 + 0.002, -0.08, 0.01))
    P.anchor("eye", (0, -0.01, J21_SL))
    P.anchor("hand", (0, -0.215, -0.07))
    P.anchor("grip", (0, -0.006, -0.065))


@gpart("T215_BOLT", 6, 1, family="g21", margin=0.03)
def t215_bolt(P):
    g, s, w = P("gunmetal"), P("metal"), P("wood")
    # the walnut sporter stock: butt with a straight comb, the wrist and the fore-end to half the barrel
    side(w, [(0.37, -0.008), (0.37, -0.13), (0.34, -0.136), (0.12, -0.07), (0.08, -0.084), (0.05, -0.084), (0.03, -0.04),
             (0.0, -0.03), (0.0, -0.012), (0.08, -0.01), (0.24, -0.006)], 0.036, T215_WOOD, bevel=0.004)
    side(w, [(0.0, -0.008), (-0.4, -0.008), (-0.4, -0.03), (-0.2, -0.04), (-0.04, -0.042), (0.0, -0.032)], 0.036, T215_WOOD, bevel=0.004)
    for k in range(6):                                                                                       # chequering on the wrist
        for sx in (-1, 1):
            w.box((sx * 0.0182, 0.065 + k * 0.006, -0.05 + k * 0.002), (0.0008, 0.004, 0.018), shade(T215_WOOD, 0.6))
    s.box((0, 0.374, -0.068), (0.038, 0.008, 0.122), col("1E1F1E"), bevel=0.003)                            # butt pad
    # the round receiver with its short rail and the bolt handle turned down
    ybar(g, 0.0, -0.2, 0.0, 0.016, T215_STEEL, seg=22)
    pica(g, -0.03, -0.17, 0.016, color=BLACK)
    g.box((-0.011, -0.08, 0.006), (0.008, 0.07, 0.012), shade(T215_STEEL, 0.4))
    b = P.sub("bolt")
    bs = b("metal")
    bs.cyl((0, 0.0, 0.0), (0, 0.04, 0.0), 0.012, T215_STEEL, seg=16)
    bs.cyl((-0.012, 0.004, 0.002), (-0.044, 0.008, -0.018), 0.004, STEEL, seg=10)
    bs.cyl((-0.044, 0.008, -0.018), (-0.054, 0.01, -0.024), 0.009, STEEL, seg=16, smooth=True)
    # the 600 mm barrel with its crown
    ylathe(g, [(0.0145, 0.2), (0.0145, 0.26), (0.0122, 0.42), (0.0105, 0.82)], T215_STEEL, seg=22)
    ybar(g, -0.816, -0.822, 0.0, 0.006, shade(T215_STEEL, 0.3), seg=14)
    # the guard, the trigger and the magazine well's floor
    trigger_guard(g, 0.055, -0.005, -0.032, color=T215_STEEL, r=0.0034)
    trigger(s, 0.028, -0.032)
    side(g, [(-0.05, -0.032), (-0.14, -0.032), (-0.14, -0.042), (-0.05, -0.042)], 0.03, T215_STEEL, bevel=0.0015)
    P.slot("scope", (0, -0.1, 0.016 + 0.0095))
    P.slot("mag", (0, -0.095, -0.032))
    P.anchor("muzzle", (0, -0.822, 0.0))
    P.anchor("port", (-0.014, -0.08, 0.01))
    P.anchor("bolt", (-0.054, 0.01, -0.024))
    P.anchor("eye", (0, -0.12, T215_SL))
    P.anchor("hand", (0, -0.33, -0.04))
    P.anchor("grip", (0, 0.07, -0.065))


@gpart("W21_MAG", 1, 1, family="g21", cls="pistol", margin=0.12)
def w21_mag(P):
    box_mag(P("metal"), 0.11, 0.019, 0.034, 0, col("2D3032"), plate=col("232526"), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.03, color=col("B8903E"))


@gpart("J21_MAG20", 1, 2, family="g21", margin=0.1)
def j21_mag20(P):
    box_mag(P("metal"), 0.12, 0.022, 0.036, 4, col("2B2E30"), plate=col("232526"), ribs=(0.4,), rib_color=col("353839"))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.03, color=col("B8903E"))


@gpart("J21_MAG30", 1, 2, family="g21", margin=0.1)
def j21_mag30(P):
    box_mag(P("metal"), 0.17, 0.022, 0.036, 6, col("2B2E30"), plate=col("232526"), ribs=(0.35, 0.7), rib_color=col("353839"))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.03, color=col("B8903E"))


@gpart("T215_MAG", 1, 1, family="g21", margin=0.12)
def t215_mag(P):
    box_mag(P("metal"), 0.05, 0.024, 0.07, 0, col("2E3236"), plate=col("232526"), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.0048, l=0.05, color=col("B8903E"))


preset("W21_PISTOL", "W21_PISTOL", {"mag": ("W21_MAG", {})})
preset("J21_SMG", "J21_SMG", {"mag": ("J21_MAG30", {})})
preset("T215_BOLT", "T215_BOLT", {"mag": ("T215_MAG", {})})

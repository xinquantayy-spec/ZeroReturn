"""Zero Return - the 11.4x23 guns and the 5.7x28 pistol of economy-1a's eighth slice (2026-11-08), original designs:

- Harrier HS-45 (EFT's HK UMP 45, .45 ACP = our 11.4x23): a boxy polymer submachine gun with a top rail, drum rear sight
  and hooded front post, a straight 25-round magazine and a folding skeleton stock (shown open).
  Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.33. Sight line 0.05.
- Lark L-11 (EFT's Colt M1911A1, .45 ACP): a single-action steel pistol with a spur hammer, grip safety and brown
  panels; 7- and 11-round magazines. Frame and slide in one piece. Bore axis z = 0, slide rear y = 0, muzzle y = -0.21.
- Finch F-57 (EFT's FN Five-seveN MK2, 5.7x28): a light polymer-framed pistol with a deep grip for the long rounds and
  a 20-round magazine. Bore axis z = 0, slide rear y = 0, muzzle y = -0.205.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, pica, box_mag, round_top, trigger, trigger_guard, grip_profile, BLACK, STEEL

UMP_POLY = col("1E1F20")
UMP_SL = 0.05
L11_STEEL = col("2C2E30")
L11_GRIP = col("4E3626")
L11_SL = 0.026
F57_POLY = col("1C1D1E")
F57_SLIDE = col("26282A")
F57_SL = 0.029


@gpart("UMP_SMG", 3, 2, family="p45", margin=0.04)
def ump_smg(P):
    p, g, s = P("polymer"), P("gunmetal"), P("metal")
    W = 0.034
    side(p, [(0.0, 0.028), (-0.3, 0.028), (-0.312, 0.014), (-0.312, -0.03), (-0.2, -0.03), (-0.12, -0.036), (-0.02, -0.036), (0.0, -0.03)], W, UMP_POLY, bevel=0.004)
    pica(g, -0.012, -0.21, 0.028)
    # the drum rear sight and the hooded front post on the rail
    side(g, [(-0.004, 0.037), (-0.03, 0.037), (-0.028, UMP_SL + 0.006), (-0.006, UMP_SL + 0.006)], 0.018, BLACK, bevel=0.002)
    g.torus((0, -0.017, UMP_SL), 0.0034, 0.0011, BLACK, segU=12, segV=5, rot=(R(90), 0, 0))
    for sx in (-1, 1):
        side(g, [(-0.272, 0.037), (-0.292, 0.037), (-0.292, UMP_SL + 0.004), (-0.274, UMP_SL + 0.004)], 0.0022, BLACK, x=sx * 0.0075)
    side(g, [(-0.278, 0.037), (-0.286, 0.037), (-0.286, UMP_SL - 0.002), (-0.28, UMP_SL - 0.002)], 0.003, BLACK)
    # charging handle on the left front, the grip and its big guard, the barrel
    s.box((W / 2 + 0.006, -0.25, 0.012), (0.012, 0.012, 0.008), shade(STEEL, 0.5), bevel=0.002)
    side(p, grip_profile(0.022, -0.034, 12, 0.085, 0.034, grooves=0, swell=0.002), 0.03, UMP_POLY, bevel=0.003)
    trigger_guard(p, -0.002, -0.07, -0.036, color=UMP_POLY, r=0.0045)
    trigger(s, -0.025, -0.036)
    ybar(g, -0.305, -0.33, 0.0, 0.0085, STEEL, seg=14)
    # the folding skeleton stock, open: top and lower struts, the butt
    side(p, [(0.0, 0.016), (0.24, 0.006), (0.24, -0.006), (0.0, 0.0)], 0.024, UMP_POLY, bevel=0.003)
    side(p, [(0.04, -0.03), (0.24, -0.07), (0.24, -0.085), (0.04, -0.045)], 0.024, UMP_POLY, bevel=0.003)
    side(p, [(0.232, 0.012), (0.252, 0.012), (0.252, -0.095), (0.232, -0.095)], 0.03, UMP_POLY, bevel=0.004)
    P.slot("scope", (0, -0.11, 0.028 + 0.0095))
    P.slot("mag", (0, -0.12, -0.036))
    P.anchor("muzzle", (0, -0.33, 0.0))
    P.anchor("port", (-0.017, -0.1, 0.008))
    P.anchor("eye", (0, -0.017, UMP_SL))
    P.anchor("hand", (0, -0.24, -0.036))
    P.anchor("grip", (0, 0.022, -0.07))


@gpart("M1911_PISTOL", 2, 1, family="p45", cls="pistol", margin=0.05)
def m1911_pistol(P):
    s, g, w = P("metal"), P("gunmetal"), P("wood")
    W = 0.0235
    # slide with rear serrations, the port, the sights; the frame with its dust cover
    side(g, [(0.004, -0.006), (-0.205, -0.006), (-0.21, -0.002), (-0.21, 0.012), (-0.204, 0.018), (-0.004, 0.019), (0.004, 0.012)], W, L11_STEEL, bevel=0.003)
    for k in range(9):
        g.box((W / 2 + 0.0004, -0.012 - k * 0.0034, 0.006), (0.0008, 0.0014, 0.018), shade(L11_STEEL, 0.45))
    g.box((-W / 2 - 0.0004, -0.06, 0.01), (0.0008, 0.04, 0.012), shade(L11_STEEL, 0.3))
    side(s, [(-0.004, 0.019), (-0.012, 0.019), (-0.012, L11_SL + 0.001), (-0.006, L11_SL + 0.001)], 0.013, BLACK, bevel=0.001)
    side(s, [(-0.196, 0.018), (-0.204, 0.016), (-0.204, L11_SL - 0.001), (-0.198, L11_SL - 0.001)], 0.003, BLACK, bevel=0.0006)
    side(g, [(0.006, -0.006), (-0.16, -0.006), (-0.16, -0.02), (-0.1, -0.026), (-0.05, -0.026), (-0.012, -0.024), (0.006, -0.018)], W + 0.0005, L11_STEEL, bevel=0.002)
    ybar(s, -0.205, -0.212, 0.0, 0.0068, shade(L11_STEEL, 0.6), seg=14)                               # barrel bushing
    # grip with its panels and the grip safety, the spur hammer, the thumb safety and slide stop
    side(g, grip_profile(-0.024, -0.016, 18, 0.092, 0.04, grooves=0, swell=0.0012), 0.0262, L11_STEEL, bevel=0.003)
    t = math.tan(R(18))
    for sx in (-1, 1):
        side(w, [(-0.03 + t * 0.008, -0.024), (-0.062 + t * 0.008, -0.024), (-0.062 + t * 0.082, -0.098), (-0.03 + t * 0.082, -0.098)], 0.002,
             L11_GRIP, x=sx * 0.0138, bevel=0.0006)
        for k in range(7):
            w.box((sx * 0.015, -0.046 + t * (0.03 + k * 0.009), -0.03 - k * 0.009), (0.0006, 0.024, 0.0014), shade(L11_GRIP, 0.6))
    s.box((0, 0.008, -0.016), (0.012, 0.012, 0.01), shade(L11_STEEL, 1.15), bevel=0.002)             # grip safety tang
    s.box((0, 0.009, 0.008), (0.006, 0.01, 0.012), shade(L11_STEEL, 1.2), bevel=0.0015)              # spur hammer
    s.box((W / 2 + 0.002, -0.01, -0.004), (0.004, 0.014, 0.005), STEEL, bevel=0.0012)                # thumb safety, left
    s.box((W / 2 + 0.002, -0.07, -0.01), (0.004, 0.022, 0.005), STEEL, bevel=0.0012)                 # slide stop, left
    trigger_guard(g, -0.044, -0.094, -0.026, color=L11_STEEL, r=0.0028)
    trigger(s, -0.058, -0.026)
    P.slot("mag", (0, -0.034, -0.018), rot=(18, 0, 0))
    P.anchor("grip", (0, -0.022, -0.058))
    P.anchor("hand", (-0.012, -0.016, -0.066))
    P.anchor("eye", (0, -0.006, L11_SL))
    P.anchor("muzzle", (0, -0.212, 0.0))


@gpart("FN57_PISTOL", 2, 1, family="p45", cls="pistol", margin=0.05)
def fn57_pistol(P):
    s, g, p = P("metal"), P("gunmetal"), P("polymer")
    W = 0.026
    side(g, [(0.004, -0.004), (-0.2, -0.004), (-0.205, 0.002), (-0.205, 0.014), (-0.198, 0.02), (-0.004, 0.022), (0.004, 0.014)], W, F57_SLIDE, bevel=0.0035)
    for k in range(8):
        g.box((W / 2 + 0.0004, -0.012 - k * 0.0036, 0.009), (0.0008, 0.0016, 0.016), shade(F57_SLIDE, 0.45))
    g.box((-W / 2 - 0.0004, -0.06, 0.012), (0.0008, 0.04, 0.01), shade(F57_SLIDE, 0.3))
    side(s, [(-0.004, 0.022), (-0.012, 0.022), (-0.012, F57_SL + 0.001), (-0.006, F57_SL + 0.001)], 0.014, BLACK, bevel=0.001)
    side(s, [(-0.192, 0.02), (-0.2, 0.019), (-0.2, F57_SL - 0.001), (-0.194, F57_SL - 0.001)], 0.003, BLACK, bevel=0.0006)
    # the polymer frame with its rail under the dust cover, the long grip, the guard
    side(p, [(0.006, -0.004), (-0.19, -0.004), (-0.19, -0.022), (-0.11, -0.028), (-0.05, -0.028), (-0.012, -0.024), (0.006, -0.018)], W + 0.001, F57_POLY, bevel=0.002)
    for k in range(3):
        p.box((0, -0.12 - k * 0.022, -0.026), (0.02, 0.01, 0.005), shade(F57_POLY, 0.7))
    side(p, grip_profile(-0.03, -0.016, 15, 0.1, 0.05, grooves=0, swell=0.0015), 0.028, F57_POLY, bevel=0.004)
    trigger_guard(p, -0.046, -0.1, -0.028, color=F57_POLY, r=0.003)
    trigger(s, -0.062, -0.028)
    P.slot("mag", (0, -0.044, -0.018), rot=(15, 0, 0))
    P.anchor("grip", (0, -0.03, -0.06))
    P.anchor("hand", (-0.012, -0.024, -0.068))
    P.anchor("eye", (0, -0.006, F57_SL))
    P.anchor("muzzle", (0, -0.205, 0.0))


@gpart("UMP_MAG", 1, 2, family="p45", margin=0.1)
def ump_mag(P):
    box_mag(P("polymer"), 0.15, 0.024, 0.04, 0, UMP_POLY, plate=shade(UMP_POLY, 0.8), ribs=(), rib_color=None)
    round_top(P("brass"), -0.002, 0.003, r=0.0057, l=0.032, color=col("B8903E"))


@gpart("M1911_MAG", 1, 1, family="p45", cls="pistol", margin=0.12)
def m1911_mag(P):
    box_mag(P("metal"), 0.092, 0.0175, 0.034, 0, col("2E3032"), plate=col("232526"), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.0057, l=0.03, color=col("B8903E"))


@gpart("M1911_MAG11", 1, 1, family="p45", cls="pistol", margin=0.1)
def m1911_mag11(P):
    box_mag(P("metal"), 0.124, 0.0175, 0.034, 0, col("2E3032"), plate=col("1E2021"), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.0057, l=0.03, color=col("B8903E"))


@gpart("FN57_MAG", 1, 1, family="p45", cls="pistol", margin=0.1)
def fn57_mag(P):
    box_mag(P("polymer"), 0.105, 0.016, 0.044, 0, F57_POLY, plate=shade(F57_POLY, 0.8), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.004, l=0.04, color=col("B8903E"))


preset("UMP_SMG", "UMP_SMG", {"mag": ("UMP_MAG", {})})
preset("M1911_PISTOL", "M1911_PISTOL", {"mag": ("M1911_MAG", {})})
preset("FN57_PISTOL", "FN57_PISTOL", {"mag": ("FN57_MAG", {})})

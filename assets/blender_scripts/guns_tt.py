"""Zero Return - the 7.6x25 guns of economy-1a's ninth slice (2026-11-08), original designs:

- Pipit P-33 (EFT's TT-33, 7.62x25 TT = our 7.6x25): a flat single-action steel pistol with an exposed hammer, slim
  grip panels and an 8-round magazine. Bore axis z = 0, slide rear y = 0, muzzle y = -0.196.
- Grackle G-41 (EFT's PPSh-41, 7.62x25): a wooden-stocked submachine gun with a perforated barrel jacket ending in a
  slanted muzzle brake, a hinged receiver, a 35-round curved magazine or a 71-round drum.
  Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.44. Sight line 0.034.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, box_mag, round_top, trigger, trigger_guard, grip_profile, BLACK, STEEL, BLUED

TT_STEEL = col("2D3032")
TT_GRIP = col("2A2422")
TT_SL = 0.025
PP_STEEL = col("2B2E30")
PP_WOOD = col("6A4228")
PP_SL = 0.034


@gpart("TT_PISTOL", 2, 1, family="tt", cls="pistol", margin=0.05)
def tt_pistol(P):
    s, g, p = P("metal"), P("gunmetal"), P("polymer")
    W = 0.0225
    side(g, [(0.004, -0.006), (-0.19, -0.006), (-0.196, -0.002), (-0.196, 0.012), (-0.19, 0.017), (-0.004, 0.018), (0.004, 0.011)], W, TT_STEEL, bevel=0.003)
    for k in range(12):                                                                       # the slide's fine serrations
        g.box((W / 2 + 0.0004, -0.01 - k * 0.0028, 0.006), (0.0008, 0.0012, 0.016), shade(TT_STEEL, 0.45))
    g.box((-W / 2 - 0.0004, -0.058, 0.01), (0.0008, 0.034, 0.011), shade(TT_STEEL, 0.3))
    side(s, [(-0.004, 0.018), (-0.011, 0.018), (-0.011, TT_SL + 0.001), (-0.006, TT_SL + 0.001)], 0.012, BLACK, bevel=0.001)
    side(s, [(-0.184, 0.017), (-0.191, 0.016), (-0.191, TT_SL - 0.001), (-0.186, TT_SL - 0.001)], 0.003, BLACK, bevel=0.0006)
    side(g, [(0.005, -0.006), (-0.15, -0.006), (-0.15, -0.019), (-0.1, -0.025), (-0.05, -0.025), (-0.012, -0.022), (0.005, -0.017)], W + 0.0005, TT_STEEL, bevel=0.002)
    side(g, grip_profile(-0.024, -0.016, 14, 0.09, 0.038, grooves=0, swell=0.001), 0.0248, TT_STEEL, bevel=0.003)
    t = math.tan(R(14))
    for sx in (-1, 1):
        side(p, [(-0.029 + t * 0.008, -0.022), (-0.058 + t * 0.008, -0.022), (-0.058 + t * 0.08, -0.094), (-0.029 + t * 0.08, -0.094)], 0.002,
             TT_GRIP, x=sx * 0.0132, bevel=0.0006)
        for k in range(8):
            p.box((sx * 0.0144, -0.043 + t * (0.03 + k * 0.008), -0.028 - k * 0.008), (0.0006, 0.022, 0.0012), shade(TT_GRIP, 0.55))
    s.box((0, 0.008, 0.009), (0.006, 0.01, 0.012), shade(TT_STEEL, 1.2), bevel=0.0015)      # hammer
    trigger_guard(g, -0.042, -0.09, -0.025, color=TT_STEEL, r=0.0027)
    trigger(s, -0.056, -0.025)
    P.slot("mag", (0, -0.032, -0.018), rot=(14, 0, 0))
    P.anchor("grip", (0, -0.02, -0.058))
    P.anchor("hand", (-0.012, -0.014, -0.066))
    P.anchor("eye", (0, -0.006, TT_SL))
    P.anchor("muzzle", (0, -0.196, 0.0))


@gpart("PPSH_SMG", 5, 2, family="tt", margin=0.03)
def ppsh_smg(P):
    g, s, w = P("gunmetal"), P("metal"), P("wood")
    W = 0.03
    # the wooden stock: butt, wrist and the fore-end under the receiver
    side(w, [(0.4, -0.02), (0.4, -0.13), (0.37, -0.135), (0.12, -0.072), (0.05, -0.062), (0.0, -0.04), (-0.17, -0.04), (-0.17, -0.016),
             (0.0, -0.014), (0.1, -0.008), (0.25, -0.012)], 0.036, PP_WOOD, bevel=0.004)
    s.box((0, 0.403, -0.075), (0.036, 0.008, 0.112), shade(STEEL, 0.5), bevel=0.002)                       # butt plate
    # the receiver with its bolt handle slot, the rear sight, the perforated jacket and the slanted brake
    side(g, [(0.0, -0.016), (-0.17, -0.016), (-0.17, 0.016), (-0.15, 0.022), (-0.02, 0.022), (0.0, 0.014)], W, PP_STEEL, bevel=0.002)
    s.box((-W / 2 - 0.005, -0.06, 0.008), (0.01, 0.01, 0.008), STEEL, bevel=0.002)
    side(g, [(-0.01, 0.022), (-0.04, 0.022), (-0.04, PP_SL - 0.002), (-0.015, PP_SL - 0.002)], 0.016, PP_STEEL, bevel=0.001)
    ybar(g, -0.17, -0.425, 0.0, 0.0145, PP_STEEL, seg=20)
    for k in range(7):
        for a in (40, 140, 220, 320):
            r = R(a)
            g.box((0.0146 * math.cos(r), -0.19 - k * 0.032, 0.0146 * math.sin(r)), (0.002, 0.016, 0.006), shade(PP_STEEL, 0.25), rot=(0, -r, 0))
    side(g, [(-0.415, -0.015), (-0.44, -0.015), (-0.452, 0.004), (-0.44, 0.016), (-0.415, 0.016)], 0.032, PP_STEEL, bevel=0.002)
    side(g, [(-0.418, 0.016), (-0.426, 0.016), (-0.426, PP_SL), (-0.42, PP_SL)], 0.0035, PP_STEEL)                   # front post
    trigger_guard(g, 0.02, -0.03, -0.04, color=PP_STEEL, r=0.0034)
    trigger(s, 0.0, -0.04)
    P.slot("mag", (0, -0.13, -0.034))
    P.anchor("muzzle", (0, -0.452, 0.004))
    P.anchor("port", (-0.016, -0.09, 0.012))
    P.anchor("eye", (0, -0.025, PP_SL))
    P.anchor("hand", (0, -0.21, -0.03))
    P.anchor("grip", (0, 0.06, -0.06))


@gpart("TT_MAG", 1, 1, family="tt", cls="pistol", margin=0.12)
def tt_mag(P):
    box_mag(P("metal"), 0.088, 0.0155, 0.032, 0, col("2E3133"), plate=col("232526"), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.0042, l=0.026, color=col("B8903E"))


@gpart("PPSH_MAG35", 1, 2, family="tt", margin=0.1)
def ppsh_mag35(P):
    box_mag(P("metal"), 0.19, 0.022, 0.034, 14, col("2B2E30"), plate=col("232526"), ribs=(0.35, 0.7), rib_color=col("353839"))
    round_top(P("brass"), -0.002, 0.003, r=0.0042, l=0.026, color=col("B8903E"))


@gpart("PPSH_DRUM", 2, 2, family="tt", margin=0.08)
def ppsh_drum(P):
    """the 71-round drum: a round can below the gun, its axis along the bore, with a neck into the magazine well"""
    m = P("metal")
    m.box((0, 0.0, -0.018), (0.02, 0.03, 0.036), col("2B2E30"), bevel=0.002)
    m.cyl((0, 0.034, -0.085), (0, -0.034, -0.085), 0.068, col("2D3032"), seg=28)
    m.cyl((0, 0.036, -0.085), (0, 0.03, -0.085), 0.06, shade(col("2D3032"), 0.7), seg=28)
    m.cyl((0, 0.04, -0.085), (0, 0.034, -0.085), 0.012, STEEL, seg=12)                                              # the winding key


preset("TT_PISTOL", "TT_PISTOL", {"mag": ("TT_MAG", {})})
preset("PPSH_SMG", "PPSH_SMG", {"mag": ("PPSH_DRUM", {})})

"""Zero Return - the 9x39 rifles of economy-1a's sixth slice (2026-11-08), original designs:

- Owl SV-9 (EFT's VSS Vintorez, 9x39): a short AK-type receiver with a wooden thumbhole skeleton stock and a wooden
  handguard over the rear of the integral barrel-suppressor, which is its own part as in EFT; a tangent rear sight, the
  side dovetail for a scope mount, 10- and 20-round magazines.
- Nightjar AV-9 (EFT's AS VAL, 9x39): the same action with a plum polymer pistol grip and handguard and a folding steel
  skeleton stock; its own barrel-suppressor.
Frame: bore axis z = 0, receiver rear y = 0, receiver front y = -0.24 (the barrel slot; the suppressors reach y = -0.38
from it). Sight line 0.034.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, screw, box_mag, round_top, trigger, trigger_guard, grip_profile, BLACK, STEEL, WOOD

VS_STEEL = col("2D3032")
VS_WOOD = col("6B4429")
PLUM = col("5A3A34")
SL = 0.034
W = 0.03


def _action(P, wood_hg):
    """the receiver, dust cover, sights, dovetail, controls and trigger shared by both rifles"""
    g, s = P("gunmetal"), P("metal")
    side(g, [(0.0, 0.012), (-0.24, 0.012), (-0.24, -0.028), (-0.18, -0.034), (-0.04, -0.034), (0.0, -0.024)], W, VS_STEEL, bevel=0.0015)
    side(g, [(0.002, 0.012), (-0.215, 0.012), (-0.215, 0.022), (-0.2, 0.027), (-0.01, 0.026), (0.002, 0.02)], W - 0.002, shade(VS_STEEL, 1.08), bevel=0.002)
    side(g, [(-0.03, -0.004), (-0.15, -0.004), (-0.15, -0.02), (-0.03, -0.02)], 0.006, shade(VS_STEEL, 1.12), x=W / 2 + 0.003, bevel=0.0008)   # dovetail
    s.box((-W / 2 - 0.0015, -0.09, -0.004), (0.003, 0.11, 0.009), STEEL, bevel=0.0012)                                      # safety
    s.box((-W / 2 - 0.008, -0.17, 0.006), (0.014, 0.011, 0.008), STEEL, bevel=0.002)                                        # charging handle
    side(g, [(-0.205, 0.022), (-0.24, 0.022), (-0.24, SL - 0.002), (-0.21, SL)], 0.018, VS_STEEL, bevel=0.0008)             # tangent rear sight
    for k in range(4):
        g.box((0.0095, -0.212 - k * 0.007, 0.026), (0.0006, 0.0012, 0.0022), col("C8CCC6"))
    trigger_guard(g, -0.03, -0.1, -0.034, color=VS_STEEL, r=0.0033)
    trigger(s, -0.055, -0.034)
    s.box((0, -0.118, -0.04), (0.01, 0.006, 0.008), STEEL, bevel=0.001)                                                    # magazine catch
    hg = P("wood") if wood_hg else P("polymer")
    side(hg, [(-0.235, -0.025), (-0.37, -0.023), (-0.37, 0.021), (-0.235, 0.024)], 0.048, VS_WOOD if wood_hg else PLUM, bevel=0.005)
    for k in range(3):
        for sx in (-1, 1):
            hg.box((sx * 0.0242, -0.26 - k * 0.035, 0.0), (0.0012, 0.02, 0.012), shade(VS_WOOD if wood_hg else PLUM, 0.4))
    P.slot("barrel", (0, -0.24, 0.0))
    P.slot("mount", (W / 2 + 0.006, -0.09, -0.012))
    P.slot("mag", (0, -0.155, -0.034))
    P.anchor("port", (-0.016, -0.12, 0.006))
    P.anchor("eye", (0, -0.22, SL))
    P.anchor("hand", (0, -0.3, -0.026))


@gpart("VSS_RIFLE", 5, 2, family="vss", margin=0.03)
def vss_rifle(P):
    _action(P, True)
    w, s = P("wood"), P("metal")
    # the wooden thumbhole skeleton stock: comb, lower bar, butt, the grip in the thumbhole
    side(w, [(0.0, 0.006), (0.24, 0.004), (0.27, 0.004), (0.27, -0.02), (0.24, -0.02), (0.1, -0.024), (0.03, -0.03), (0.0, -0.03)], 0.032, VS_WOOD, bevel=0.004)
    side(w, [(0.08, -0.095), (0.27, -0.11), (0.27, -0.126), (0.24, -0.135), (0.08, -0.115)], 0.032, VS_WOOD, bevel=0.004)
    side(w, [(0.24, -0.02), (0.27, -0.02), (0.27, -0.13), (0.24, -0.135)], 0.034, VS_WOOD, bevel=0.003)
    side(w, grip_profile(0.03, -0.03, 10, 0.075, 0.038, grooves=0, swell=0.002), 0.03, VS_WOOD, bevel=0.004)
    side(w, [(0.035, -0.1), (0.1, -0.095), (0.1, -0.115), (0.04, -0.118)], 0.028, VS_WOOD, bevel=0.003)
    s.box((0, 0.274, -0.063), (0.034, 0.008, 0.14), shade(STEEL, 0.55), bevel=0.002)
    P.anchor("grip", (0, 0.05, -0.065))


@gpart("VAL_RIFLE", 5, 2, family="vss", margin=0.03)
def val_rifle(P):
    _action(P, False)
    p, s = P("polymer"), P("metal")
    side(p, grip_profile(0.012, -0.03, 14, 0.085, 0.032, grooves=3), 0.028, PLUM, bevel=0.003)
    # the folding steel skeleton stock (open): top and lower struts, the butt plate
    s.cyl((0, 0.0, 0.004), (0, 0.235, 0.0), 0.0055, VS_STEEL, seg=10)
    s.cyl((0, 0.03, -0.03), (0, 0.235, -0.085), 0.0055, VS_STEEL, seg=10)
    s.cyl((0, 0.03, -0.03), (0, 0.0, -0.02), 0.0055, VS_STEEL, seg=10)
    s.box((0, 0.24, -0.04), (0.03, 0.012, 0.105), shade(VS_STEEL, 0.8), bevel=0.003)
    s.box((0, 0.249, -0.04), (0.032, 0.006, 0.11), col("1F2021"), bevel=0.002)                                              # rubber pad
    P.anchor("grip", (0, 0.03, -0.065))


def _supp(P, length, r, color, ribs):
    g = P("gunmetal")
    ybar(g, 0.0, -length, 0.0, r, color, seg=22)
    for k in range(ribs):
        g.box((0, -0.15 - k * 0.04, 0.0), (r * 2 + 0.0012, 0.004, r * 2 + 0.0012), shade(color, 0.85), bevel=0.001)
    ybar(g, -length + 0.002, -length - 0.002, 0.0, 0.0055, shade(color, 0.3), seg=14)
    side(g, [(-length + 0.012, r - 0.002), (-length + 0.03, r - 0.002), (-length + 0.028, SL - 0.003), (-length + 0.016, SL - 0.003)], 0.004, color)   # front sight
    for sx in (-1, 1):
        side(g, [(-length + 0.01, r - 0.002), (-length + 0.032, r - 0.002), (-length + 0.032, SL - 0.007), (-length + 0.012, SL - 0.007)], 0.002, color, x=sx * 0.007)
    P.anchor("muzzle", (0, -length, 0.0))


@gpart("VSS_SUPP", 2, 1, family="vss", margin=0.06, view="left_hi")
def vss_supp(P):
    """the integral barrel-suppressor: a fat tube round the ported barrel, the front sight on its end"""
    _supp(P, 0.38, 0.0185, col("2A2C2E"), 4)


@gpart("VAL_SUPP", 2, 1, family="vss", margin=0.06, view="left_hi")
def val_supp(P):
    _supp(P, 0.37, 0.019, col("2E3032"), 3)


@gpart("VSS_MAG10", 1, 1, family="vss", margin=0.1)
def vss_mag10(P):
    box_mag(P("metal"), 0.07, 0.024, 0.062, 4, col("2B2D2E"), plate=col("222425"), ribs=(0.5,), rib_color=col("35383A"))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.044, color=col("8C8F86"))


@gpart("VSS_MAG20", 1, 2, family="vss", margin=0.1)
def vss_mag20(P):
    box_mag(P("polymer"), 0.12, 0.026, 0.064, 9, PLUM, plate=shade(PLUM, 0.8), ribs=(0.3, 0.62), rib_color=shade(PLUM, 1.1))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.044, color=col("8C8F86"))


preset("VSS_RIFLE", "VSS_RIFLE", {"barrel": ("VSS_SUPP", {}), "mag": ("VSS_MAG10", {})})
preset("VAL_RIFLE", "VAL_RIFLE", {"barrel": ("VAL_SUPP", {}), "mag": ("VSS_MAG20", {})})

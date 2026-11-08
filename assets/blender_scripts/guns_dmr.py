"""Zero Return - the self-loading rifles of economy-1a's fourth slice (2026-11-08), original designs:

- Siskin SK-45 (EFT's TOZ Simonov SKS, 7.62x39 = our 7.6x39): one piece, a full-length wooden stock, a fixed 10-round
  magazine ahead of the trigger guard, a gas tube over the barrel, a tangent rear sight and a folding blade bayonet.
  Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.62. Sight line 0.03.
- Merlin MR-10 (EFT's SVD / SVDS, 7.62x54R = our 7.6x54R): a long stamped receiver with the side dovetail for a scope
  mount, a skeleton thumbhole stock, a vented wooden handguard, a 10-round detachable magazine and a slotted flash
  hider (it takes the Tundra's muzzle devices). Frame: bore axis z = 0, receiver rear y = 0, muzzle shoulder y = -0.78.
  Iron sight line 0.034.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import (gpart, preset, side, box, ybar, ring, ylathe, screw, pin, grip_profile, box_mag, round_top, trigger, trigger_guard,
                     BLACK, STEEL, BLUED, WOOD, WOOD2, WOODL, WHITE)

SK_STEEL = col("2F3335")
SK_WOOD = col("7A4A2A")
SK_SL = 0.03
SV_STEEL = col("34383A")
SV_WOOD = col("6A3E24")
SV_SL = 0.034


@gpart("SKS_RIFLE", 6, 1, family="dmr", margin=0.03)
def sks_rifle(P):
    g, s, w = P("gunmetal"), P("metal"), P("wood")
    # the one-piece stock: butt, wrist and the fore-stock under the barrel
    side(w, [(0.36, -0.03), (0.36, -0.115), (0.33, -0.12), (0.12, -0.062), (0.05, -0.05), (0.0, -0.032), (0.0, -0.012),
             (0.05, -0.012), (0.14, 0.002), (0.34, 0.004), (0.36, 0.0)], 0.036, SK_WOOD, bevel=0.004)
    side(w, [(0.0, -0.012), (-0.42, -0.012), (-0.42, -0.026), (-0.2, -0.034), (-0.04, -0.036), (0.0, -0.032)], 0.032, SK_WOOD, bevel=0.003)
    side(w, [(-0.22, 0.008), (-0.4, 0.008), (-0.4, 0.03), (-0.23, 0.032)], 0.026, shade(SK_WOOD, 1.08), bevel=0.003)   # handguard over the gas tube
    s.box((0, 0.355, -0.058), (0.038, 0.012, 0.118), shade(STEEL, 0.6), bevel=0.002)                                   # butt plate
    # the receiver with its cover, the bolt carrier and charging handle on the right
    side(g, [(0.004, -0.012), (-0.2, -0.012), (-0.2, 0.018), (-0.05, 0.022), (0.004, 0.016)], 0.03, SK_STEEL, bevel=0.002)
    s.box((-0.017, -0.12, 0.006), (0.004, 0.09, 0.01), STEEL, bevel=0.0012)
    s.cyl((-0.019, -0.15, 0.007), (-0.034, -0.15, 0.007), 0.0045, STEEL, seg=10)
    # the fixed magazine and the trigger guard behind it
    side(g, [(-0.08, -0.03), (-0.19, -0.03), (-0.185, -0.078), (-0.09, -0.078)], 0.03, SK_STEEL, bevel=0.002)
    trigger_guard(g, -0.008, -0.07, -0.034, color=SK_STEEL, r=0.0032)
    trigger(s, -0.03, -0.034)
    # barrel, gas block, front sight and the folded bayonet
    ybar(g, -0.2, -0.62, 0.0, 0.0095, BLUED, seg=18)
    ybar(g, -0.2, -0.42, 0.022, 0.0075, SK_STEEL, seg=14)                                                                # gas tube
    side(g, [(-0.42, -0.01), (-0.46, -0.01), (-0.46, 0.03), (-0.42, 0.03)], 0.022, SK_STEEL, bevel=0.002)                # gas block
    side(g, [(-0.585, -0.01), (-0.61, -0.01), (-0.61, 0.02), (-0.585, 0.02)], 0.018, SK_STEEL, bevel=0.0015)
    for sx in (-1, 1):
        g.box((sx * 0.0068, -0.597, 0.028), (0.0022, 0.012, 0.018), SK_STEEL, bevel=0.0006)                             # front sight hood
    s.box((0, -0.597, SK_SL - 0.006), (0.0022, 0.0022, 0.012), shade(STEEL, 0.5))
    s.box((0, -0.5, -0.018), (0.004, 0.2, 0.012), shade(STEEL, 1.15), bevel=0.0015)                                      # folded blade
    s.box((0, -0.6, -0.018), (0.01, 0.02, 0.016), STEEL, bevel=0.002)                                                    # its hinge
    # tangent rear sight on the receiver front
    side(g, [(-0.2, 0.018), (-0.26, 0.018), (-0.26, 0.026), (-0.205, SK_SL - 0.002)], 0.018, SK_STEEL, bevel=0.0008)
    for k in range(5):
        g.box((0.0095, -0.212 - k * 0.009, 0.024), (0.0006, 0.0012, 0.0022), WHITE)
    P.anchor("muzzle", (0, -0.62, 0.0))
    P.anchor("port", (-0.016, -0.11, 0.008))
    P.anchor("eye", (0, -0.21, SK_SL))
    P.anchor("hand", (0, -0.3, -0.03))
    P.anchor("grip", (0, 0.05, -0.05))


@gpart("SVD_RIFLE", 6, 2, family="dmr", margin=0.03)
def svd_rifle(P):
    g, s, w = P("gunmetal"), P("metal"), P("wood")
    W = 0.032
    # the long stamped receiver with its dust cover and the left-side dovetail for the scope mount
    side(g, [(0.0, 0.012), (-0.3, 0.012), (-0.3, -0.03), (-0.24, -0.038), (-0.14, -0.044), (-0.02, -0.044), (0.0, -0.03)], W, SV_STEEL, bevel=0.0015)
    side(g, [(0.002, 0.012), (-0.27, 0.012), (-0.27, 0.024), (-0.255, 0.03), (-0.01, 0.028), (0.002, 0.022)], W - 0.002, shade(SV_STEEL, 1.08), bevel=0.002)
    side(g, [(-0.04, -0.002), (-0.17, -0.002), (-0.17, -0.02), (-0.04, -0.02)], 0.006, shade(SV_STEEL, 1.12), x=W / 2 + 0.003, bevel=0.0008)
    s.box((-W / 2 - 0.0015, -0.13, -0.003), (0.003, 0.14, 0.009), STEEL, bevel=0.0012)                                   # safety lever
    s.box((-W / 2 - 0.009, -0.2, 0.006), (0.016, 0.012, 0.008), STEEL, bevel=0.002)                                      # charging handle
    trigger_guard(g, -0.03, -0.11, -0.044, color=SV_STEEL, r=0.0034)
    trigger(s, -0.06, -0.044)
    # the skeleton thumbhole stock: comb, lower bar, butt and the grip section
    side(w, [(0.0, 0.006), (0.36, 0.012), (0.4, 0.012), (0.4, -0.02), (0.36, -0.02), (0.12, -0.022), (0.03, -0.03), (0.0, -0.03)], 0.034, SV_WOOD, bevel=0.004)
    side(w, [(0.1, -0.1), (0.4, -0.12), (0.4, -0.136), (0.37, -0.15), (0.1, -0.12)], 0.034, SV_WOOD, bevel=0.004)
    side(w, [(0.37, -0.02), (0.4, -0.02), (0.4, -0.14), (0.37, -0.15)], 0.036, SV_WOOD, bevel=0.003)
    side(w, grip_profile(0.03, -0.03, 10, 0.08, 0.04, grooves=0, swell=0.002), 0.03, SV_WOOD, bevel=0.004)              # the grip in the thumbhole
    side(w, [(0.035, -0.108), (0.13, -0.1), (0.13, -0.12), (0.04, -0.124)], 0.03, SV_WOOD, bevel=0.003)                   # under the thumbhole
    s.box((0, 0.403, -0.066), (0.036, 0.008, 0.17), shade(STEEL, 0.55), bevel=0.002)                                      # butt plate
    side(w, [(0.2, 0.012), (0.33, 0.016), (0.33, 0.04), (0.2, 0.034)], 0.03, shade(SV_WOOD, 1.1), bevel=0.004)           # cheek rest
    # barrel, the vented wooden handguard, gas block and the front sight near the muzzle
    ybar(g, -0.3, -0.78, 0.0, 0.0105, BLUED, seg=18)
    side(w, [(-0.3, -0.026), (-0.52, -0.024), (-0.52, 0.026), (-0.3, 0.03)], 0.04, SV_WOOD, bevel=0.005)
    for k in range(4):
        for sx in (-1, 1):
            w.box((sx * 0.0202, -0.34 - k * 0.045, 0.004), (0.0012, 0.026, 0.008), shade(SV_WOOD, 0.35))                 # vent slots
    side(g, [(-0.52, -0.012), (-0.56, -0.012), (-0.56, 0.03), (-0.52, 0.03)], 0.024, SV_STEEL, bevel=0.002)               # gas block
    ybar(g, -0.53, -0.555, 0.024, 0.0085, SV_STEEL, seg=12)
    side(g, [(-0.745, -0.012), (-0.775, -0.012), (-0.775, 0.022), (-0.745, 0.022)], 0.02, SV_STEEL, bevel=0.0015)
    for sx in (-1, 1):
        g.box((sx * 0.0072, -0.76, 0.03), (0.0022, 0.012, 0.016), SV_STEEL, bevel=0.0006)
    s.box((0, -0.76, SV_SL - 0.006), (0.0022, 0.0022, 0.012), shade(STEEL, 0.5))
    side(g, [(-0.27, 0.024), (-0.31, 0.024), (-0.31, SV_SL - 0.002), (-0.275, SV_SL)], 0.018, SV_STEEL, bevel=0.0008)    # rear sight
    P.slot("muzzle", (0, -0.78, 0.0))
    P.slot("mount", (W / 2 + 0.006, -0.105, -0.011))
    P.slot("mag", (0, -0.17, -0.03))
    P.anchor("muzzle", (0, -0.78, 0.0))
    P.anchor("port", (-0.016, -0.14, 0.004))
    P.anchor("eye", (0, -0.29, SV_SL))
    P.anchor("hand", (0, -0.42, -0.026))
    P.anchor("grip", (0, 0.05, -0.07))


@gpart("SVD_FH", 1, 1, family="dmr", margin=0.14, view="left_hi")
def svd_fh(P):
    """the long slotted flash hider: five slots round a cylinder"""
    g = P("gunmetal")
    ybar(g, 0.0, -0.085, 0.0, 0.0118, SV_STEEL, seg=20)
    for k in range(5):
        a = R(36 + k * 72)
        g.box((0.0115 * math.cos(a), -0.05, 0.0115 * math.sin(a)), (0.004, 0.05, 0.004), shade(SV_STEEL, 0.15), rot=(0, -a, 0))
    ybar(g, -0.084, -0.086, 0.0, 0.0075, shade(SV_STEEL, 0.3), seg=16)
    P.anchor("muzzle", (0, -0.086, 0.0))


@gpart("SVD_MAG", 1, 1, family="dmr", margin=0.1)
def svd_mag(P):
    m = P("metal")
    box_mag(m, 0.125, 0.027, 0.072, 5, col("2E3133"), plate=col("232526"), ribs=(0.45,), rib_color=col("383B3D"))
    round_top(P("brass"), -0.004, 0.004, r=0.0058, l=0.05, color=col("8C8F86"))


preset("SKS_RIFLE", "SKS_RIFLE", {})
preset("SVD_RIFLE", "SVD_RIFLE", {"muzzle": ("SVD_FH", {}), "mag": ("SVD_MAG", {})})
preset("SVD_SCOPED", "SVD_RIFLE", {"muzzle": ("SVD_FH", {}), "mag": ("SVD_MAG", {}), "mount": ("KST_MNT_SIDE", {"scope": ("SCOPE_4X", {})})})

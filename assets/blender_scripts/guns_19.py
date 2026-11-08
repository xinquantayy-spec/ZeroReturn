"""Zero Return - the 9x19 guns of economy-1a's twelfth slice (2026-11-08), original designs:

- Dunlin D-17 (EFT's Glock 17): a striker-fired polymer pistol with a square-edged slide, a short accessory rail and
  a 17-round magazine. Bore axis z = 0, slide rear y = 0, muzzle y = -0.186.
- Avocet AV-9 (EFT's SIG MPX): a submachine gun on a rifle-style upper and lower, a short slotted handguard, a full
  top rail, a collapsing stock and 20- or 30-round magazines. Receiver rear y = 0, muzzle y = -0.3. Sight line 0.05.
- Bunting B-19 (EFT's PP-19-01 Vityaz): a 9x19 submachine gun on a Kalashnikov-pattern receiver with a ribbed
  dust cover, a side dovetail, a slotted muzzle device, a side-folding skeleton stock and a 30-round magazine.
  Receiver rear y = 0, muzzle y = -0.47. Sight line 0.034.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, pica, box_mag, round_top, trigger, trigger_guard, grip_profile, BLACK, STEEL, BLUED

D17_POLY = col("2A2C2D")
D17_SLIDE = col("2F3234")
D17_SL = 0.024
AV_BLACK = col("2B2E31")
AV_SL = 0.05
BN_STEEL = col("303437")
BN_POLY = col("26282A")
BN_SL = 0.034


@gpart("D17_PISTOL", 2, 1, family="g19", cls="pistol", margin=0.05)
def d17_pistol(P):
    s, g, p = P("metal"), P("gunmetal"), P("polymer")
    W = 0.0255
    # the square slide with its rear grooves and the sights
    side(g, [(0.004, -0.004), (-0.18, -0.004), (-0.186, 0.0), (-0.186, 0.016), (-0.182, 0.019), (-0.002, 0.019), (0.004, 0.014)], W, D17_SLIDE, bevel=0.0018)
    for k in range(7):
        for sx in (-1, 1):
            g.box((sx * (W / 2 + 0.0004), -0.01 - k * 0.0034, 0.008), (0.0008, 0.0014, 0.017), shade(D17_SLIDE, 0.45))
    side(s, [(-0.004, 0.019), (-0.012, 0.019), (-0.012, D17_SL + 0.001), (-0.006, D17_SL + 0.001)], 0.014, BLACK, bevel=0.001)
    side(s, [(-0.172, 0.019), (-0.179, 0.019), (-0.179, D17_SL - 0.001), (-0.174, D17_SL - 0.001)], 0.0035, BLACK, bevel=0.0006)
    s.box((-W / 2 - 0.0006, -0.058, 0.009), (0.0012, 0.02, 0.008), shade(STEEL, 0.6))
    # the polymer frame: dust cover with a short rail, the guard and the grip with its finger grooves
    side(p, [(0.006, -0.004), (-0.16, -0.004), (-0.16, -0.018), (-0.1, -0.024), (-0.03, -0.024), (0.006, -0.016)], W + 0.0015, D17_POLY, bevel=0.002)
    pica(p, -0.112, -0.152, -0.018, color=D17_POLY, w=0.02, h=0.006, face="bottom")
    side(p, grip_profile(-0.024, -0.016, 18, 0.1, 0.042, grooves=3, swell=0.0015), 0.029, D17_POLY, bevel=0.003)
    trigger_guard(p, -0.03, -0.088, -0.024, color=D17_POLY, r=0.0036)
    trigger(s, -0.054, -0.024)
    P.slot("mag", (0, -0.032, -0.018), rot=(18, 0, 0))
    P.anchor("grip", (0, -0.018, -0.058))
    P.anchor("hand", (-0.013, -0.014, -0.068))
    P.anchor("eye", (0, -0.006, D17_SL))
    P.anchor("muzzle", (0, -0.186, 0.0))


@gpart("AV9_SMG", 3, 2, family="g19", margin=0.04)
def av9_smg(P):
    g, s, p = P("gunmetal"), P("metal"), P("polymer")
    W = 0.03
    # upper with its full top rail, the short slotted handguard, the lower with the magazine well
    side(g, [(0.0, -0.002), (-0.16, -0.002), (-0.16, 0.03), (0.0, 0.03)], W, AV_BLACK, bevel=0.002)
    pica(g, 0.0, -0.26, 0.03)
    for y0, y1 in ((-0.004, -0.016), (-0.246, -0.258)):                                                              # flip-up irons
        side(g, [(y0, 0.0395), (y1, 0.0395), (y1 + 0.002, AV_SL + 0.004), (y0 - 0.002, AV_SL + 0.004)], 0.016, BLACK, bevel=0.001)
    side(g, [(-0.16, -0.012), (-0.27, -0.012), (-0.27, 0.03), (-0.16, 0.03)], 0.036, AV_BLACK, bevel=0.003)
    for k in range(5):
        for sx in (-1, 1):
            g.box((sx * 0.0182, -0.175 - k * 0.019, 0.01), (0.001, 0.011, 0.012), shade(AV_BLACK, 0.3))
    side(g, [(0.0, -0.002), (-0.13, -0.002), (-0.13, -0.03), (-0.08, -0.034), (0.0, -0.03)], W, shade(AV_BLACK, 1.08), bevel=0.002)
    side(g, [(-0.08, -0.03), (-0.13, -0.03), (-0.13, -0.044), (-0.08, -0.044)], 0.028, AV_BLACK, bevel=0.002)      # magazine well
    s.box((-W / 2 - 0.004, -0.02, 0.018), (0.008, 0.012, 0.008), STEEL, bevel=0.0015)                              # charging handle
    # the grip, the guard and the trigger
    side(p, grip_profile(-0.01, -0.03, 18, 0.09, 0.034, grooves=2), 0.028, col("2A2C2D"), bevel=0.003)
    trigger_guard(g, -0.03, -0.075, -0.03, color=AV_BLACK, r=0.0034)
    trigger(s, -0.052, -0.03)
    # the barrel and its flash hider
    ybar(g, -0.27, -0.3, 0.0, 0.0085, BLUED, seg=14)
    ybar(g, -0.28, -0.305, 0.0, 0.0105, shade(AV_BLACK, 0.8), seg=14)
    # the collapsing stock: two rods and a butt pad
    for sx in (-1, 1):
        s.cyl((sx * 0.012, 0.0, 0.012), (sx * 0.012, 0.15, 0.012), 0.004, shade(STEEL, 0.6), seg=10)
    side(p, [(0.15, 0.03), (0.165, 0.03), (0.165, -0.06), (0.15, -0.06)], 0.036, col("2A2C2D"), bevel=0.003)
    P.slot("scope", (0, -0.09, 0.03 + 0.0095))
    P.slot("mag", (0, -0.105, -0.044))
    P.anchor("muzzle", (0, -0.305, 0.0))
    P.anchor("port", (W / 2 + 0.002, -0.06, 0.012))
    P.anchor("eye", (0, -0.02, AV_SL))
    P.anchor("hand", (0, -0.22, -0.035))
    P.anchor("grip", (0, -0.01, -0.07))


@gpart("B19_SMG", 4, 2, family="g19", margin=0.035)
def b19_smg(P):
    g, s, p = P("gunmetal"), P("metal"), P("polymer")
    W = 0.032
    # the stamped receiver with its ribbed dust cover and the side dovetail
    side(g, [(0.0, -0.022), (-0.2, -0.022), (-0.2, 0.022), (-0.03, 0.026), (0.0, 0.022)], W, BN_STEEL, bevel=0.002)
    side(g, [(0.0, 0.022), (-0.2, 0.022), (-0.2, 0.03), (0.0, 0.03)], W - 0.004, shade(BN_STEEL, 1.1), bevel=0.002)
    for k in range(4):
        g.box((0, -0.03 - k * 0.04, 0.031), (W - 0.008, 0.004, 0.002), shade(BN_STEEL, 0.6))
    g.box((W / 2 + 0.0015, -0.1, 0.002), (0.003, 0.11, 0.012), shade(BN_STEEL, 0.7))                              # dovetail
    s.box((-W / 2 - 0.008, -0.16, 0.012), (0.016, 0.006, 0.006), STEEL, bevel=0.0012)                              # charging handle
    # the polymer handguard and lower, the pistol grip, the guard
    side(p, [(-0.2, -0.018), (-0.33, -0.018), (-0.33, 0.024), (-0.2, 0.024)], 0.04, BN_POLY, bevel=0.003)
    side(p, grip_profile(0.0, -0.022, 14, 0.09, 0.034, grooves=3), 0.03, BN_POLY, bevel=0.003)
    trigger_guard(g, -0.008, -0.062, -0.022, color=BN_STEEL, r=0.0034)
    trigger(s, -0.032, -0.022)
    # the rear and front sights, the barrel and the slotted muzzle device
    side(g, [(-0.2, 0.03), (-0.235, 0.03), (-0.235, BN_SL - 0.002), (-0.205, BN_SL - 0.002)], 0.016, BN_STEEL, bevel=0.001)
    ybar(g, -0.33, -0.44, 0.0, 0.0085, BLUED, seg=14)
    side(g, [(-0.41, -0.008), (-0.428, -0.008), (-0.428, BN_SL), (-0.416, BN_SL)], 0.012, BN_STEEL, bevel=0.001)
    ybar(g, -0.44, -0.47, 0.0, 0.011, shade(BN_STEEL, 0.8), seg=14)
    for k in range(3):
        g.box((0, -0.448 - k * 0.008, 0.0108), (0.004, 0.004, 0.002), shade(BN_STEEL, 0.3))
    # the side-folding skeleton stock, unfolded
    side(s, [(0.0, 0.014), (0.22, 0.004), (0.22, -0.006), (0.0, 0.004)], 0.018, shade(BN_STEEL, 1.05), bevel=0.0015)
    side(s, [(0.02, -0.024), (0.22, -0.064), (0.22, -0.074), (0.02, -0.034)], 0.018, shade(BN_STEEL, 1.05), bevel=0.0015)
    side(s, [(0.215, 0.012), (0.23, 0.012), (0.23, -0.082), (0.215, -0.082)], 0.032, shade(BN_STEEL, 0.9), bevel=0.002)
    P.slot("mag", (0, -0.13, -0.022))
    P.anchor("muzzle", (0, -0.47, 0.0))
    P.anchor("port", (W / 2 + 0.002, -0.1, 0.012))
    P.anchor("eye", (0, -0.21, BN_SL))
    P.anchor("hand", (0, -0.27, -0.04))
    P.anchor("grip", (0, 0.0, -0.065))


@gpart("D17_MAG", 1, 1, family="g19", cls="pistol", margin=0.12)
def d17_mag(P):
    box_mag(P("metal"), 0.1, 0.019, 0.032, 0, col("2A2C2D"), plate=col("232526"), ribs=(), witness=0)
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.029, color=col("B8903E"))


@gpart("AV9_MAG20", 1, 1, family="g19", margin=0.12)
def av9_mag20(P):
    box_mag(P("metal"), 0.1, 0.022, 0.034, 3, col("2B2E30"), plate=col("232526"), ribs=(0.45,), rib_color=col("353839"))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.029, color=col("B8903E"))


@gpart("AV9_MAG30", 1, 2, family="g19", margin=0.1)
def av9_mag30(P):
    box_mag(P("metal"), 0.16, 0.022, 0.034, 5, col("2B2E30"), plate=col("232526"), ribs=(0.35, 0.7), rib_color=col("353839"))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.029, color=col("B8903E"))


@gpart("B19_MAG", 1, 2, family="g19", margin=0.1)
def b19_mag(P):
    box_mag(P("polymer"), 0.18, 0.024, 0.036, 8, col("2A2B2C"), plate=col("232526"), ribs=(0.3, 0.62), rib_color=col("333436"))
    round_top(P("brass"), -0.002, 0.003, r=0.0045, l=0.029, color=col("B8903E"))


preset("D17_PISTOL", "D17_PISTOL", {"mag": ("D17_MAG", {})})
preset("AV9_SMG", "AV9_SMG", {"mag": ("AV9_MAG30", {})})
preset("B19_SMG", "B19_SMG", {"mag": ("B19_MAG", {})})

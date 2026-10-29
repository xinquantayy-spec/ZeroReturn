"""Zero Return - Tundra parts (bolt-action 7.6x54R carbine, original design). Conventions: zr_guns.py.

Action frame: bore axis z = 0, receiver rear (tang) y = 0, receiver front y = -0.2, muzzle y = -0.72. The bolt
handle and cocking knob are the moving sub-part "bolt". Sight line (ladder rear sight, hooded front) 0.026.
"""
import math
from zr_items import col, shade, R
from zr_guns import (gpart, preset, side, box, ybar, ring, ylathe, pica, screw, pin, grip_profile, trigger, sling_loop, suppressor,
                     BLACK, BLACK2, PARK, BLUED, STEEL, BRIGHT, POLY, POLY2, FDE, ODG, WOOD, WOOD2, WOODL, RUBBER, WHITE)

BL = col("2A2E31")
SL = 0.026


@gpart("TUNDRA_BOLT", 6, 1, family="tun", margin=0.03)
def tun_action(P):
    g, s = P("gunmetal"), P("metal")
    ybar(g, 0.0, -0.2, 0.0, 0.0172, BL, seg=20)                           # round receiver
    side(g, [(-0.03, 0.006), (-0.15, 0.006), (-0.15, 0.019), (-0.03, 0.019)], 0.03, shade(BL, 1.05), bevel=0.002)   # receiver flats
    g.box((0.0, -0.09, 0.0175), (0.016, 0.1, 0.004), shade(BL, 0.35))                # loading port (bolt visible)
    s.box((0.0, -0.08, 0.0145), (0.012, 0.11, 0.006), STEEL, bevel=0.002)             # bolt body
    # barrel: stepped profile with the rear sight base and the hooded front sight
    ylathe(g, [(0.0145, 0.2), (0.0145, 0.28), (0.0128, 0.29), (0.0128, 0.45), (0.0112, 0.46), (0.0105, 0.72)], BL, seg=20)
    side(g, [(-0.24, 0.0), (-0.32, 0.0), (-0.32, 0.017), (-0.25, 0.019), (-0.24, 0.017)], 0.024, BL, bevel=0.002)   # rear sight base
    side(g, [(-0.245, 0.017), (-0.315, 0.021), (-0.315, 0.025), (-0.245, 0.021)], 0.016, shade(BL, 1.15), bevel=0.0008)  # ladder leaf
    for k in range(6):
        g.box((0.0082, -0.252 - k * 0.01, 0.021 + k * 0.0006), (0.0006, 0.0012, 0.0024), WHITE)
    g.box((0, -0.29, 0.024), (0.016, 0.008, 0.006), shade(BL, 1.25), bevel=0.0012)            # slider
    side(g, [(-0.305, 0.022), (-0.312, 0.022), (-0.312, SL), (-0.305, SL)], 0.014, BL)          # notch block
    side(g, [(-0.695, 0.0), (-0.715, 0.0), (-0.715, 0.018), (-0.695, 0.018)], 0.018, BL, bevel=0.0015)   # front sight base
    g.torus((0, -0.705, SL - 0.002), 0.0085, 0.0016, BL, segU=14, segV=5, rot=(R(90), 0, 0))
    s.box((0, -0.705, SL - 0.004), (0.0022, 0.0022, 0.008), shade(STEEL, 0.5))
    # trigger, magazine box and floor plate
    side(g, [(-0.03, -0.017), (-0.135, -0.017), (-0.13, -0.058), (-0.04, -0.058)], 0.026, BL, bevel=0.002)
    g.box((0, -0.085, -0.06), (0.03, 0.1, 0.004), shade(BL, 0.9), bevel=0.0012)
    g.tube([(0, -0.0, -0.02), (0, -0.002, -0.042), (0, -0.026, -0.05), (0, -0.04, -0.04)], 0.0032, BL, seg=6)
    trigger(s, -0.016, -0.02)
    # moving bolt handle (straight, on the right) and cocking knob
    b = P.sub("bolt")
    bs = b("metal")
    bs.cyl((0, 0.0, 0.003), (0, 0.04, 0.003), 0.0105, STEEL, seg=16)                # cocking piece
    bs.cyl((0, 0.04, 0.003), (0, 0.052, 0.003), 0.0135, shade(STEEL, 0.9), seg=16)
    bs.cyl((-0.012, 0.012, 0.004), (-0.052, 0.012, 0.004), 0.0042, STEEL, seg=10)   # handle stem
    bs.cyl((-0.052, 0.012, 0.004), (-0.064, 0.012, 0.004), 0.0095, STEEL, seg=16, smooth=True)   # knob
    P.slot("stock", (0, 0.0, 0.0))
    P.slot("muzzle", (0, -0.72, 0.0))
    P.slot("sidemount", (0.0175, -0.1, 0.0))
    P.slot("scout", (0, -0.29, 0.0128))
    P.anchor("muzzle", (0, -0.72, 0.0))
    P.anchor("port", (-0.008, -0.09, 0.016))
    P.anchor("bolt", (-0.058, 0.012, 0.004))
    P.anchor("eye", (0, -0.31, SL))


# ── stocks (origin at the tang on the bore axis; they hold the action) ───────
@gpart("TUN_STK_WOOD", 6, 1, family="tun", margin=0.03)
def tun_stk_wood(P):
    w, s = P("wood"), P("metal")
    prof = [(-0.62, -0.006), (-0.2, -0.006), (-0.15, -0.014), (0.0, -0.012), (0.03, -0.02), (0.31, -0.044), (0.318, -0.05), (0.318, -0.145),
            (0.304, -0.15), (0.11, -0.072), (0.065, -0.06), (0.04, -0.07), (-0.02, -0.06), (-0.15, -0.04), (-0.62, -0.028)]
    side(w, prof, 0.036, WOOD, bevel=0.005)
    side(w, [(-0.34, 0.006), (-0.6, 0.004), (-0.6, 0.014), (-0.34, 0.016)], 0.026, WOODL, bevel=0.004)   # upper handguard
    for y in (-0.35, -0.58):
        side(s, [(y + 0.006, 0.02), (y - 0.006, 0.02), (y - 0.006, -0.03), (y + 0.006, -0.03)], 0.039, BL, bevel=0.002)   # bands
    ylathe(s, [(0.013, 0.62), (0.016, 0.625), (0.016, 0.645)], BL, seg=16)                               # nose cap
    side(s, [(0.318, -0.046), (0.326, -0.046), (0.326, -0.148), (0.318, -0.148)], 0.038, BL, bevel=0.002)   # butt plate
    for y in (0.21, -0.36):
        s.box((0.0, y, -0.06 if y > 0 else -0.032), (0.039, 0.016, 0.006), shade(WOOD, 0.3), bevel=0.002)   # sling slots
    for k in range(5):
        w.box((0.0182, 0.06 + k * 0.05, -0.05 - k * 0.012), (0.0004, 0.07, 0.0012), shade(WOOD, 0.78), rot=(R(-8), 0, 0))
    P.anchor("grip", (0, 0.052, -0.05))
    P.anchor("hand", (0, -0.42, -0.022))


@gpart("TUN_STK_SPORT", 5, 1, family="tun", margin=0.03)
def tun_stk_sport(P):
    w, r = P("wood"), P("rubber")
    prof = [(-0.4, -0.006), (-0.15, -0.012), (0.0, -0.012), (0.04, -0.012), (0.12, 0.004), (0.29, -0.004), (0.296, -0.012),
            (0.296, -0.13), (0.282, -0.136), (0.12, -0.07), (0.075, -0.074), (0.05, -0.1), (0.02, -0.1), (0.015, -0.062),
            (-0.15, -0.042), (-0.4, -0.032)]
    side(w, prof, 0.038, WOODL, bevel=0.006)
    side(r, [(0.296, -0.008), (0.312, -0.008), (0.312, -0.134), (0.296, -0.134)], 0.04, RUBBER, bevel=0.003)
    for k in range(6):
        w.box((0.0192, 0.05 + k * 0.003, -0.07 - k * 0.004), (0.0006, 0.012, 0.0022), shade(WOODL, 0.6), rot=(R(30), 0, 0))
    P.anchor("grip", (0, 0.038, -0.07))
    P.anchor("hand", (0, -0.28, -0.03))


@gpart("TUN_STK_CHAS", 5, 1, family="tun", margin=0.03)
def tun_stk_chas(P):
    g, p, r = P("gunmetal"), P("polymer"), P("rubber")
    side(g, [(-0.36, 0.008), (0.02, 0.008), (0.02, -0.032), (-0.36, -0.032)], 0.042, BLACK, bevel=0.006)    # chassis and forend
    for k in range(5):
        g.box((0.0212, -0.08 - k * 0.055, -0.012), (0.0012, 0.032, 0.0068), shade(BLACK, 0.2))
    pica(g, -0.24, -0.34, -0.032, face="bottom")
    side(p, grip_profile(0.04, -0.03, 18, 0.096, 0.036, grooves=3, swell=0.002), 0.029, POLY, bevel=0.004)
    ybar(g, 0.02, 0.21, -0.004, 0.0145, BLACK, seg=18)
    prof = [(0.084, 0.018), (0.12, 0.018), (0.128, 0.026), (0.198, 0.027), (0.205, 0.022), (0.205, -0.08), (0.196, -0.083),
            (0.17, -0.06), (0.124, -0.026), (0.104, -0.02), (0.093, -0.02), (0.084, -0.013)]
    side(p, [(y + 0.01, z - 0.004) for y, z in prof], 0.036, POLY, bevel=0.003)
    side(r, [(0.215, 0.0205), (0.228, 0.0205), (0.228, -0.088), (0.215, -0.088)], 0.039, RUBBER, bevel=0.0025)
    P.slot("foregrip", (0, -0.29, -0.0415))
    P.anchor("grip", (0, 0.05, -0.075))
    P.anchor("hand", (0, -0.25, -0.04))


# ── mounts ───────────────────────────────────────────────────────────────────
@gpart("TUN_MNT_SIDE", 2, 1, family="tun", margin=0.08, view=(0.6, -0.8, 0.5))
def tun_mnt_side(P):
    g = P("gunmetal")
    X0 = -0.0175
    g.box((0.004, 0.0, 0.0), (0.01, 0.07, 0.024), BLACK, bevel=0.002)
    for y in (0.02, -0.02):
        g.cyl((0.009, y, 0.0), (0.013, y, 0.0), 0.004, STEEL, seg=10)
    side(g, [(0.035, 0.008), (-0.035, 0.008), (-0.03, 0.05), (0.03, 0.05)], 0.008, BLACK, x=0.004, bevel=0.002)
    g.box((X0 / 2 + 0.002, 0.0, 0.054), (abs(X0) + 0.018, 0.08, 0.01), BLACK, bevel=0.002)
    pica(g, 0.04, -0.04, 0.059, x=X0)
    P.slot("scope", (X0, 0.0, 0.059 + 0.0095))


@gpart("TUN_MNT_SCOUT", 2, 1, family="tun", margin=0.08, view="left_hi")
def tun_mnt_scout(P):
    g = P("gunmetal")
    ybar(g, 0.02, -0.11, 0.0, 0.0158, BLACK, seg=18)                      # clamp round the barrel
    side(g, [(0.02, 0.006), (-0.11, 0.006), (-0.11, 0.016), (0.02, 0.016)], 0.022, BLACK, bevel=0.002)
    pica(g, 0.018, -0.108, 0.016)
    for y in (0.0, -0.09):
        screw(g, 0.0118, y, -0.006, r=0.0022, color=STEEL)
    P.slot("scope", (0, -0.045, 0.016 + 0.0095))


# ── muzzle devices ───────────────────────────────────────────────────────────
@gpart("TUN_BRK", 1, 1, family="tun", margin=0.14, view="left_hi")
def tun_brk(P):
    g = P("gunmetal")
    ybar(g, 0.0, -0.07, 0.0, 0.0128, BLACK, seg=20)
    for k in range(4):
        for sx in (-1, 1):
            g.box((sx * 0.0122, -0.016 - k * 0.013, 0.0), (0.004, 0.0065, 0.012), shade(BLACK, 0.12), bevel=0.0012)
    P.anchor("muzzle", (0, -0.07, 0.0))


@gpart("SUPP_76L", 2, 1, family="tun", margin=0.07)
def supp_76l(P):
    suppressor(P, 0.21, 0.0225, col("3A3A35"))


preset("TUNDRA_BOLT", "TUNDRA_BOLT", {"stock": ("TUN_STK_WOOD", {})})
preset("TUN_SCOUT", "TUNDRA_BOLT", {"stock": ("TUN_STK_SPORT", {}), "scout": ("TUN_MNT_SCOUT", {"scope": ("SCOPE_4X", {})}), "muzzle": ("TUN_BRK", {})})
preset("TUN_MARKSMAN", "TUNDRA_BOLT", {"stock": ("TUN_STK_CHAS", {"foregrip": ("GRIP_STUB", {})}),
                                       "sidemount": ("TUN_MNT_SIDE", {"scope": ("MNT_RINGS", {"scope": ("SCOPE_8X", {})})}),
                                       "muzzle": ("SUPP_76L", {})})

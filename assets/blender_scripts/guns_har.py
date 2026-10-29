"""Zero Return - Harrow-12 parts (12-gauge pump shotgun, original design). Conventions: zr_guns.py.

Receiver frame: bore axis z = 0, receiver rear y = 0, receiver face y = -0.2, magazine tube axis z = -0.03. The
forend slides on the tube (the pump: its pieces and children move together). Sight line: the bead, 0.014.
"""
import math
from zr_items import col, shade, R
from zr_guns import (gpart, preset, side, box, ybar, ring, ylathe, pica, screw, pin, grip_profile, trigger, sling_loop,
                     BLACK, BLACK2, PARK, BLUED, STEEL, BRIGHT, POLY, POLY2, FDE, ODG, WOOD, WOOD2, WOODL, RUBBER, WHITE)

RCV = col("2E3133")
TUBE_Z = -0.03


@gpart("HARROW12", 5, 1, family="har", margin=0.03)
def har_receiver(P):
    g, s = P("gunmetal"), P("metal")
    W = 0.034
    side(g, [(0.0, 0.026), (-0.2, 0.026), (-0.2, -0.042), (-0.03, -0.042), (-0.01, -0.035), (0.0, -0.02)], W, RCV, bevel=0.003)
    side(g, [(-0.035, 0.026), (-0.17, 0.026), (-0.17, 0.03), (-0.035, 0.03)], 0.02, RCV, bevel=0.001)
    pica(g, -0.04, -0.165, 0.03, color=BLACK)
    g.box((-W / 2 - 0.0004, -0.1, 0.004), (0.0012, 0.07, 0.022), shade(RCV, 0.35), bevel=0.0008)     # ejection port (right)
    g.box((0, -0.12, -0.0425), (0.022, 0.1, 0.0012), shade(RCV, 0.35))                              # loading port
    s.box((0, -0.006, 0.029), (0.008, 0.012, 0.005), STEEL, bevel=0.0012)                            # tang safety
    for k in range(2):
        g.box((W / 2 + 0.0004, -0.1, -0.012 - k * 0.012), (0.0008, 0.12, 0.0018), shade(RCV, 1.2))
    # trigger plate and guard
    side(g, [(-0.004, -0.035), (-0.1, -0.042), (-0.1, -0.048), (-0.004, -0.044)], 0.024, BLACK, bevel=0.0015)
    g.tube([(0, -0.03, -0.046), (0, -0.034, -0.064), (0, -0.07, -0.068), (0, -0.092, -0.056), (0, -0.094, -0.046)], 0.0033, BLACK, seg=6)
    trigger(s, -0.055, -0.046)
    s.box((0, -0.08, -0.05), (0.008, 0.012, 0.006), STEEL, bevel=0.001)                              # action release
    for y in (-0.03, -0.17):
        pin(g, y, -0.03, 0.0022, W, shade(STEEL, 0.7))
    P.slot("barrel", (0, -0.2, 0.0))
    P.slot("tube", (0, -0.2, TUBE_Z))
    P.slot("forend", (0, -0.2, TUBE_Z))
    P.slot("stock", (0, 0.0, -0.006))
    P.slot("scope", (0, -0.1, 0.0395))
    P.anchor("port", (-0.018, -0.1, 0.004))
    P.anchor("eye", (0, -0.02, 0.018))


# ── barrels (origin at the receiver face) ────────────────────────────────────
def har_barrel(P, L, shield=False):
    g, s = P("gunmetal"), P("metal")
    ybar(g, 0.0, -0.012, 0.0, 0.0145, PARK, seg=20)
    ybar(g, -0.012, -L, 0.0, 0.0118, PARK, seg=20)
    side(g, [(-L + 0.07, -0.012), (-L + 0.04, -0.012), (-L + 0.04, TUBE_Z + 0.006), (-L + 0.07, TUBE_Z + 0.006)], 0.014, PARK, bevel=0.002)   # tube lug
    s.cyl((0, -L + 0.012, 0.0118), (0, -L + 0.012, 0.0145), 0.0022, BRIGHT, seg=10)               # bead
    if shield:
        ybar(g, -0.03, -L * 0.62, 0.0, 0.0158, BLACK, seg=20, cap=False)
        for k in range(10):
            g.box((0.0, -0.05 - k * (L * 0.56) / 10, 0.0158), (0.007, 0.012, 0.0012), shade(BLACK, 0.25), bevel=0.002)
    P.slot("muzzle", (0, -L, 0.0))
    P.anchor("muzzle", (0, -L, 0.0))
    P.anchor("frontsight", (0, -L + 0.012, 0.0145))


@gpart("HAR_BRL_14", 3, 1, family="har")
def har_brl_14(P):
    har_barrel(P, 0.33)


@gpart("HAR_BRL_18", 4, 1, family="har")
def har_brl_18(P):
    har_barrel(P, 0.45)


@gpart("HAR_BRL_20", 5, 1, family="har")
def har_brl_20(P):
    har_barrel(P, 0.5, shield=True)


# ── magazine tubes (origin at the receiver face on the tube axis) ────────────
def har_tube(P, L):
    g = P("gunmetal")
    ybar(g, 0.0, -L, 0.0, 0.0118, BLACK, seg=18)
    ylathe(g, [(0.0128, 0.0), (0.0135, 0.006), (0.0135, 0.022), (0.009, 0.026)], BLACK2, y=-L, seg=18)   # cap
    for k in range(4):
        a = k * math.pi / 2
        g.box((0.0135 * math.cos(a), -L - 0.014, 0.0135 * math.sin(a)), (0.0016, 0.012, 0.0016), shade(BLACK2, 0.4), rot=(0, -a, 0))


@gpart("HAR_TUBE_4", 3, 1, family="har")
def har_tube_4(P):
    har_tube(P, 0.29)


@gpart("HAR_TUBE_6", 4, 1, family="har")
def har_tube_6(P):
    har_tube(P, 0.38)


@gpart("HAR_TUBE_8", 5, 1, family="har")
def har_tube_8(P):
    har_tube(P, 0.47)


# ── forends (origin at the receiver face on the tube axis; slide back to pump) ─
@gpart("HAR_FE_WOOD", 2, 1, family="har")
def har_fe_wood(P):
    w, g = P("wood"), P("gunmetal")
    ylathe(w, [(0.016, 0.07), (0.0215, 0.08), (0.0225, 0.1), (0.0225, 0.22), (0.0205, 0.235), (0.016, 0.24)], WOOD, seg=20)
    for k in range(9):                                                    # grooves round the forend
        ring(w, -0.105 - k * 0.013, 0.0, 0.0221, 0.0006, shade(WOOD, 0.62), seg=20, l=0.004)
    g.box((0.0, -0.075, 0.016), (0.006, 0.01, 0.012), BLACK, bevel=0.001)              # action bar
    P.anchor("hand", (0, -0.16, -0.022))


@gpart("HAR_FE_POLY", 2, 1, family="har")
def har_fe_poly(P):
    p = P("polymer")
    side(p, [(-0.07, 0.014), (-0.24, 0.014), (-0.245, 0.004), (-0.245, -0.022), (-0.235, -0.028), (-0.08, -0.028), (-0.07, -0.02)], 0.042, POLY, bevel=0.005)
    for k in range(6):
        p.box((0.0212, -0.1 - k * 0.022, -0.008), (0.0012, 0.01, 0.016), shade(POLY, 0.55), bevel=0.003)
    P.anchor("hand", (0, -0.16, -0.028))


@gpart("HAR_FE_RAIL", 2, 1, family="har")
def har_fe_rail(P):
    p, g = P("polymer"), P("gunmetal")
    side(p, [(-0.07, 0.014), (-0.24, 0.014), (-0.245, 0.004), (-0.245, -0.022), (-0.235, -0.028), (-0.08, -0.028), (-0.07, -0.02)], 0.04, col("2B2D2E"), bevel=0.005)
    pica(g, -0.18, -0.235, -0.006, x=0.02, face="left")
    pica(g, -0.14, -0.23, -0.028, face="bottom")
    P.slot("tactical", (0.0295, -0.207, -0.006), rot=(0, -90, 0))
    P.anchor("hand", (0, -0.15, -0.029))


# ── stocks (origin at the receiver rear) ─────────────────────────────────────
@gpart("HAR_STK_WOOD", 3, 1, family="har")
def har_stk_wood(P):
    w, r, s = P("wood"), P("rubber"), P("metal")
    prof = [(0.0, 0.03), (0.02, 0.028), (0.08, 0.004), (0.29, -0.006), (0.296, -0.012), (0.296, -0.118), (0.285, -0.124), (0.16, -0.062),
            (0.095, -0.05), (0.06, -0.06), (0.04, -0.058), (0.02, -0.04), (0.0, -0.036)]
    side(w, prof, 0.038, WOOD, bevel=0.005)
    side(r, [(0.296, -0.008), (0.31, -0.008), (0.31, -0.122), (0.296, -0.122)], 0.04, RUBBER, bevel=0.003)
    for k in range(3):
        w.box((0.0192, 0.12 + k * 0.045, -0.035 - k * 0.006), (0.0004, 0.06, 0.0012), shade(WOOD, 0.8), rot=(R(-6), 0, 0))
    sling_loop(s, 0.24, -0.1, color=STEEL)
    P.anchor("grip", (0, 0.052, -0.045))


@gpart("HAR_STK_PG", 3, 1, family="har")
def har_stk_pg(P):
    p, r = P("polymer"), P("rubber")
    prof = [(0.0, 0.03), (0.02, 0.028), (0.06, 0.006), (0.29, 0.0), (0.296, -0.006), (0.296, -0.112), (0.285, -0.118), (0.13, -0.05),
            (0.08, -0.03), (0.04, -0.034), (0.0, -0.036)]
    side(p, prof, 0.038, POLY, bevel=0.005)
    side(p, grip_profile(0.03, -0.03, 16, 0.092, 0.036, grooves=2), 0.03, POLY, bevel=0.004)
    side(r, [(0.296, -0.002), (0.31, -0.002), (0.31, -0.116), (0.296, -0.116)], 0.04, RUBBER, bevel=0.003)
    p.box((0.0, 0.2, -0.07), (0.039, 0.05, 0.012), shade(POLY, 0.25), rot=(R(-20), 0, 0), bevel=0.002)
    P.anchor("grip", (0, 0.038, -0.075))


@gpart("HAR_STK_TACT", 3, 1, family="har")
def har_stk_tact(P):
    g, p, r = P("gunmetal"), P("polymer"), P("rubber")
    g.box((0, 0.012, -0.004), (0.034, 0.024, 0.04), BLACK, bevel=0.003)
    side(p, grip_profile(0.03, -0.02, 18, 0.094, 0.036, grooves=3, swell=0.002), 0.029, POLY, bevel=0.004)
    ybar(g, 0.022, 0.21, 0.0, 0.0145, BLACK, seg=18)
    prof = [(0.084, 0.018), (0.12, 0.018), (0.128, 0.026), (0.198, 0.027), (0.205, 0.022), (0.205, -0.08), (0.196, -0.083),
            (0.17, -0.06), (0.124, -0.026), (0.104, -0.02), (0.093, -0.02), (0.084, -0.013)]
    side(p, [(y + 0.01, z) for y, z in prof], 0.036, FDE, bevel=0.003)
    side(r, [(0.215, 0.0245), (0.228, 0.0245), (0.228, -0.084), (0.215, -0.084)], 0.039, RUBBER, bevel=0.0025)
    P.anchor("grip", (0, 0.04, -0.065))


# ── muzzle devices (origin at the muzzle) ────────────────────────────────────
@gpart("HAR_CHOKE", 1, 1, family="har", margin=0.14, view="left_hi")
def har_choke(P):
    g = P("gunmetal")
    ylathe(g, [(0.0118, 0.0), (0.0135, 0.003), (0.0135, 0.03), (0.0125, 0.036)], BLACK2, seg=20)
    for k in range(6):
        a = k * math.pi / 3
        g.box((0.0135 * math.cos(a), -0.018, 0.0135 * math.sin(a)), (0.0016, 0.022, 0.0016), shade(BLACK2, 0.5), rot=(0, -a, 0))
    P.anchor("muzzle", (0, -0.036, 0.0))


@gpart("HAR_BRK", 1, 1, family="har", margin=0.14, view="left_hi")
def har_brk(P):
    g = P("gunmetal")
    ybar(g, 0.0, -0.058, 0.0, 0.0145, BLACK, seg=20)
    for k in range(4):                                                    # breaching teeth
        a = k * math.pi / 2 + math.pi / 4
        g.box((0.011 * math.cos(a), -0.062, 0.011 * math.sin(a)), (0.006, 0.01, 0.006), BLACK, rot=(0, -a, 0), bevel=0.001)
    for k in range(3):
        for sx in (-1, 1):
            g.box((sx * 0.0138, -0.016 - k * 0.014, 0.0), (0.004, 0.008, 0.012), shade(BLACK, 0.12), bevel=0.0015)
    P.anchor("muzzle", (0, -0.066, 0.0))


def _har(barrel="HAR_BRL_18", tube="HAR_TUBE_6", fe="HAR_FE_WOOD", stock="HAR_STK_WOOD", muzzle=None, scope=None, fe_kids=None):
    t = {"barrel": (barrel, {"muzzle": (muzzle, {})} if muzzle else {}), "tube": (tube, {}), "forend": (fe, fe_kids or {}),
         "stock": (stock, {})}
    if scope:
        t["scope"] = scope
    return t


preset("HARROW12", "HARROW12", _har())
preset("HAR_TAC", "HARROW12", _har(barrel="HAR_BRL_20", tube="HAR_TUBE_8", fe="HAR_FE_RAIL", stock="HAR_STK_TACT",
                                   muzzle="HAR_BRK", scope=("RED_DOT", {}), fe_kids={"tactical": ("LIGHT_T", {})}))
preset("HAR_SHORT", "HARROW12", _har(barrel="HAR_BRL_14", tube="HAR_TUBE_4", fe="HAR_FE_POLY", stock="HAR_STK_PG", muzzle="HAR_CHOKE"))

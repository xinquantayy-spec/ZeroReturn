"""Zero Return - Tern T-209 (decision economy-1a, fourteenth slice, 2026-11-09): an original design in the place of EFT's
Molot VPO-209, a civilian hunting carbine on the AKM in .366 TKM (our 9.6x39). EFT's wiki: "Based on the AKM, with nearly
identical appearance, weight, and dimensions", a smooth bore with its last part rifled. Same frame and conventions as
guns_kst.py (zr_guns.py): bore z = 0, receiver rear y = 0, muzzle toward -Y, every slot where the KS-7 has it, so the KS-7's
dust covers, handguards, grips and stocks sit exactly as on the KS-7. Unlike the KS-7 (EFT's VPO-209 against the AKM): no
side dovetail and no bayonet lug or cleaning rod, a thread protector over its 9.6 thread, its own short hunting rear sight
and a hunting-pattern stock with a rubber pad, a civilian black-oxide finish.

Parts: T209_RIFLE (receiver and barrel), T209_TP (thread protector), T209_RS (rear sight), T209_STK (wooden stock),
SUPP_96 (Kaltan SR-96 suppressor, in the place of EFT's Rotor 43 .366 TKM), KST_MAG10 (the KS-7's 10-round aluminium
magazine, EFT's AK 7.62x39 aluminium 10-round magazine and the VPO-209's default) and, for a gun we already have, SUPP_54
(the KS-74's Kaltan TS-5 suppressor, EFT's AK-74 TGP-A 5.45x39's place). The default build is EFT's VPO-209
preset with the KS-7's dust cover, wooden handguard and pistol grip in the place of the Molot ones (EFT gives those the AKM
parts' figures). Batch ZR_GunsVPO (family "vpo"); register in build_guns_all.GUN_MODULES and BATCHES.
"""
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, ylathe, ring, box_mag, round_top, sling_loop, suppressor, STEEL, RUBBER, WHITE

VPO_STEEL = col("303335")       # civilian black oxide, a shade off the KS-7's
VPO_BLUE = col("27292B")
VPO_WOOD = col("7A5232")        # lighter hunting walnut than the KS-7's furniture
SR96 = col("2C2E2B")
ALU = col("7E827E")             # the 10-round magazine's bare aluminium
SL = 0.038                      # sight line above the bore (as the KS-7)


@gpart("T209_RIFLE", 5, 2, family="vpo", margin=0.03)
def t209_receiver(P):
    g, s = P("gunmetal"), P("metal")
    W = 0.031
    # the stamped receiver in the KS-7's outline; a maker's panel on each side where the KS-7 has its dovetail rail
    side(g, [(0.0, 0.012), (-0.262, 0.012), (-0.262, -0.03), (-0.205, -0.036), (-0.14, -0.042), (-0.02, -0.042), (0.0, -0.03)], W, VPO_STEEL, bevel=0.0015)
    side(g, [(0.004, 0.006), (-0.03, 0.006), (-0.03, -0.034), (0.004, -0.03)], W + 0.002, shade(VPO_STEEL, 0.9), bevel=0.001)       # rear trunnion
    side(g, [(-0.232, 0.012), (-0.268, 0.012), (-0.268, -0.034), (-0.232, -0.034)], W + 0.002, shade(VPO_STEEL, 0.9), bevel=0.001)  # front trunnion
    for sx in (-1, 1):
        for y, z in ((-0.008, -0.01), (-0.018, -0.022), (-0.008, -0.024), (-0.238, -0.004), (-0.25, -0.004), (-0.238, -0.024), (-0.25, -0.024)):
            g.cyl((sx * (W / 2 + 0.001), y, z), (sx * (W / 2 + 0.0022), y, z), 0.0021, shade(VPO_STEEL, 1.15), seg=8)          # rivets
        g.cyl((sx * (W / 2 + 0.0004), -0.178, -0.02), (sx * (W / 2 + 0.0012), -0.178, -0.02), 0.0045, shade(VPO_STEEL, 0.6), seg=12)  # magazine guide dimple
        g.box((sx * (W / 2 + 0.0004), -0.098, -0.012), (0.0008, 0.058, 0.011), shade(VPO_STEEL, 0.72))                         # maker's panel
    # trigger guard, magazine catch and trigger as the KS-7's
    g.tube([(0, -0.028, -0.042), (0, -0.03, -0.062), (0, -0.12, -0.064), (0, -0.138, -0.052), (0, -0.142, -0.042)], 0.0034, VPO_STEEL, seg=6)
    s.box((0, -0.149, -0.05), (0.012, 0.006, 0.02), STEEL, rot=(R(-12), 0, 0), bevel=0.001)
    s.tube([(0, -0.064, -0.042), (0, -0.068, -0.05), (0, -0.066, -0.058)], 0.002, STEEL, seg=5)
    # right side: the safety lever (safe and single shots only) and the charging handle on the bolt carrier
    s.box((-W / 2 - 0.0015, -0.11, -0.003), (0.003, 0.15, 0.009), STEEL, rot=(R(4), 0, 0), bevel=0.0012)
    s.box((-W / 2 - 0.009, -0.168, 0.006), (0.016, 0.012, 0.008), STEEL, bevel=0.002)
    s.cyl((-W / 2 - 0.017, -0.168, 0.006), (-W / 2 - 0.02, -0.168, 0.006), 0.006, STEEL, seg=12)
    # the barrel at the KS-7's length, stepping down to the 9.6 thread under the protector; gas block and tube support
    ybar(g, -0.262, -0.596, 0.0, 0.0108, VPO_BLUE, seg=18)
    ybar(g, -0.596, -0.605, 0.0, 0.0086, shade(VPO_BLUE, 0.8), seg=16)
    side(g, [(-0.442, -0.012), (-0.474, -0.012), (-0.474, 0.03), (-0.452, 0.034), (-0.442, 0.03)], 0.02, VPO_STEEL, bevel=0.002)
    ybar(g, -0.452, -0.476, 0.022, 0.0082, VPO_STEEL, seg=14)
    for k in range(3):
        g.box((0.0084, -0.455 - k * 0.006, 0.022), (0.0012, 0.0034, 0.0034), shade(VPO_STEEL, 0.3))                             # gas vents
    # the front sight block, set back to bare the thread; no bayonet lug, no cleaning rod
    side(g, [(-0.566, -0.012), (-0.594, -0.012), (-0.594, 0.016), (-0.585, 0.02), (-0.571, 0.02), (-0.566, 0.016)], 0.02, VPO_STEEL, bevel=0.002)
    for sx in (-1, 1):
        g.box((sx * 0.0072, -0.579, 0.03), (0.0024, 0.012, 0.022), VPO_STEEL, bevel=0.0007)                                     # front sight ears
    s.box((0, -0.579, SL - 0.007), (0.0022, 0.0022, 0.014), shade(STEEL, 0.5))                                                    # post
    P.slot("dustcover", (0, 0.0, 0.012))
    P.slot("handguard", (0, -0.262, 0.0))
    P.slot("grip", (0, -0.026, -0.042))
    P.slot("stock", (0, 0.0, -0.012))
    P.slot("rearsight", (0, -0.262, 0.014))
    P.slot("muzzle", (0, -0.605, 0.0))
    P.slot("mag", (0, -0.176, -0.026))
    P.anchor("muzzle", (0, -0.612, 0.0))
    P.anchor("port", (-0.016, -0.12, 0.004))
    P.anchor("eye", (0, -0.27, SL))
    P.anchor("hand", (0, -0.36, -0.02))


# ── thread protector (origin at the thread shoulder) ─────────────────────────
@gpart("T209_TP", 1, 1, family="vpo", margin=0.16, view="left_hi")
def t209_tp(P):
    g = P("gunmetal")
    ylathe(g, [(0.0086, 0.0), (0.0097, 0.002), (0.0097, 0.016), (0.0086, 0.0195), (0.0035, 0.0195)], VPO_STEEL, seg=20)
    for k in range(5):                                                   # knurled bands
        ring(g, -0.004 - k * 0.0024, 0.0, 0.0097, 0.0004, shade(VPO_STEEL, 0.6), seg=20, l=0.0012)
    P.anchor("muzzle", (0, -0.0195, 0.0))


# ── rear sight (origin on the rear sight block, as the KS-7's tangent) ───────
@gpart("T209_RS", 1, 1, family="vpo", margin=0.12)
def t209_rs(P):
    g, s = P("gunmetal"), P("metal")
    g.box((0, -0.012, 0.004), (0.028, 0.03, 0.01), VPO_STEEL, bevel=0.002)                                                       # base
    side(g, [(-0.002, 0.009), (-0.034, 0.011), (-0.034, SL - 0.012), (-0.03, SL - 0.012), (-0.002, 0.016)], 0.014, VPO_STEEL, bevel=0.0012)  # short fixed leaf
    side(g, [(-0.03, SL - 0.017), (-0.038, SL - 0.017), (-0.038, SL - 0.01), (-0.03, SL - 0.01)], 0.026, VPO_STEEL, bevel=0.0008)  # wide notch blade
    s.box((0.0, -0.034, SL - 0.0105), (0.0045, 0.009, 0.0014), shade(STEEL, 0.3))                                                # the wide notch
    g.box((0.0072, -0.018, 0.0125), (0.0006, 0.004, 0.003), WHITE)                                                                # one range mark
    P.anchor("eye", (0, -0.034, SL - 0.014))


# ── stock (origin at the rear trunnion, on the stock's attachment axis) ──────
@gpart("T209_STK", 2, 1, family="vpo")
def t209_stk(P):
    w, r, s = P("wood"), P("rubber"), P("metal")
    # a hunting-pattern stock: a straighter comb than the KS-7's with a raised cheek piece, a deep butt and a rubber pad
    prof = [(0.0, 0.016), (0.03, 0.016), (0.11, 0.004), (0.2, 0.004), (0.244, -0.006), (0.25, -0.012), (0.25, -0.13),
            (0.238, -0.136), (0.07, -0.05), (0.0, -0.028)]
    side(w, prof, 0.04, VPO_WOOD, bevel=0.005)
    side(w, [(0.1, 0.0), (0.205, 0.0), (0.205, -0.012), (0.1, -0.014)], 0.043, shade(VPO_WOOD, 1.08), bevel=0.004)             # cheek piece
    side(r, [(0.25, -0.01), (0.264, -0.01), (0.264, -0.133), (0.25, -0.133)], 0.042, RUBBER, bevel=0.003)                         # butt pad
    for k in range(5):
        r.box((0.0, 0.2648, -0.026 - k * 0.022), (0.036, 0.0016, 0.008), shade(RUBBER, 0.7))                                     # pad ridges
    sling_loop(s, 0.2, -0.112, color=STEEL)
    for k in range(4):                                                   # grain lines
        w.box((0.0202, 0.07 + k * 0.042, -0.034 - k * 0.012), (0.0004, 0.05, 0.0012), shade(VPO_WOOD, 0.8), rot=(R(-12), 0, 0))
    s.box((0, 0.006, -0.002), (0.034, 0.012, 0.03), VPO_STEEL, bevel=0.0015)                                                       # tang plate


# ── the SR-96 suppressor (origin at the thread shoulder) ─────────────────────
@gpart("SUPP_96", 2, 1, family="vpo", margin=0.07)
def supp_96(P):
    suppressor(P, 0.215, 0.0225, SR96)
    g = P("gunmetal")
    for k in range(4):                                                   # front vent slots, its own look
        g.box((0.0, -0.165 - k * 0.011, 0.0222), (0.0055, 0.006, 0.0014), shade(SR96, 0.35))


# ── the KS-74's TS-5 suppressor (EFT's AK-74 TGP-A's place; origin at the 5.4 thread shoulder) ──────────────────
@gpart("SUPP_54", 2, 1, family="vpo", margin=0.07)
def supp_54(P):
    suppressor(P, 0.2, 0.021, col("2A2D2F"), collar=0.024)
    g = P("gunmetal")
    for k in range(3):                                                   # clamp bands, its own look
        ring(g, -0.05 - k * 0.05, 0.0, 0.021, 0.0007, shade(col("2A2D2F"), 0.7), seg=24, l=0.004)


# ── the KS-7's 10-round magazine (fits every KS-7-family gun) ────────────────
@gpart("KST_MAG10", 1, 2, family="vpo", margin=0.1)
def kst_mag10(P):
    m = P("metal")
    box_mag(m, 0.118, 0.026, 0.07, 9, ALU, plate=shade(ALU, 0.72), ribs=(0.48,), rib_color=shade(ALU, 0.86))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.04, color=col("8C8F86"))


# ── builds ───────────────────────────────────────────────────────────────────
# EFT's VPO-209 default preset (EFT's globals ItemPresets "AKM VPO-209", as SPT copies them): the Molot gas tube and the
# VPO-209 wooden handguard (our KS-7 wooden handguard), the VPO-209 thread protector, the Molot bakelite grip (our KS-7
# grip), the Molot AKM-type dust cover (our KS-7 dust cover), the VPO-209 rear sight and wooden stock, and the AK
# aluminium 10-round magazine
preset("T209_RIFLE", "T209_RIFLE", {"dustcover": ("KST_DC_STD", {}), "handguard": ("KST_HG_WOOD", {}), "grip": ("AK_PG_STD", {}),
                                    "stock": ("T209_STK", {}), "muzzle": ("T209_TP", {}), "rearsight": ("T209_RS", {}),
                                    "mag": ("KST_MAG10", {})})

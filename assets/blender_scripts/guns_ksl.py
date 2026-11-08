"""Zero Return - Kestrel KS-L light machine gun (decision ai-5b, 2026-11-08): the KS-7's light machine gun, an original
design in the place of EFT's RPK-16 (Killa's gun): the KS-7 receiver with a reinforced front trunnion, a long heavy
barrel with a folding bipod clamped under the muzzle, and a 95-round drum (EFT's RPK-16 drum: 95 rounds, 0.68 kg).
Same frame and conventions as guns_kst.py (zr_guns.py): bore z = 0, receiver rear y = 0, muzzle toward -Y.
Every KS-7 part fits it (dust covers, handguards, grips, stocks, rear sights, side mounts, muzzle devices), and the
drum fits the KS-7 too, as an RPK drum fits an AK.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, ring, box_mag, round_top, STEEL, BLACK, POLY, POLY2

AK_STEEL = col("343736")
AK_BLUE = col("2B2F31")
SL = 0.038                      # sight line above the bore (as the KS-7)
DRUM = col("2E3131")
MUZZLE_Y = -0.76                # the heavy barrel ends 0.155 past the KS-7's


@gpart("KSL_LMG", 6, 2, family="ksl", margin=0.03)
def ksl_receiver(P):
    g, s = P("gunmetal"), P("metal")
    W = 0.031
    # stamped receiver, a thicker front trunnion for the heavy barrel
    side(g, [(0.0, 0.012), (-0.262, 0.012), (-0.262, -0.03), (-0.205, -0.036), (-0.14, -0.042), (-0.02, -0.042), (0.0, -0.03)], W, AK_STEEL, bevel=0.0015)
    side(g, [(0.004, 0.006), (-0.03, 0.006), (-0.03, -0.034), (0.004, -0.03)], W + 0.002, shade(AK_STEEL, 0.9), bevel=0.001)
    side(g, [(-0.226, 0.012), (-0.27, 0.012), (-0.27, -0.038), (-0.226, -0.038)], W + 0.004, shade(AK_STEEL, 0.88), bevel=0.001)
    for sx in (-1, 1):                                                   # rivets
        for y, z in ((-0.008, -0.01), (-0.018, -0.022), (-0.008, -0.024), (-0.234, -0.004), (-0.248, -0.004), (-0.234, -0.026), (-0.248, -0.026), (-0.262, -0.015)):
            g.cyl((sx * (W / 2 + 0.002), y, z), (sx * (W / 2 + 0.0032), y, z), 0.0021, shade(AK_STEEL, 1.15), seg=8)
        g.cyl((sx * (W / 2 + 0.0004), -0.178, -0.02), (sx * (W / 2 + 0.0012), -0.178, -0.02), 0.0045, shade(AK_STEEL, 0.6), seg=12)
    side(g, [(-0.05, -0.002), (-0.145, -0.002), (-0.145, -0.018), (-0.05, -0.018)], 0.006, shade(AK_STEEL, 1.1), x=W / 2 + 0.003, bevel=0.0008)
    # trigger guard, magazine catch, trigger, selector, charging handle (as the KS-7)
    g.tube([(0, -0.028, -0.042), (0, -0.03, -0.062), (0, -0.12, -0.064), (0, -0.138, -0.052), (0, -0.142, -0.042)], 0.0034, AK_STEEL, seg=6)
    s.box((0, -0.149, -0.05), (0.012, 0.006, 0.02), STEEL, rot=(R(-12), 0, 0), bevel=0.001)
    s.tube([(0, -0.064, -0.042), (0, -0.068, -0.05), (0, -0.066, -0.058)], 0.002, STEEL, seg=5)
    s.box((-W / 2 - 0.0015, -0.11, -0.003), (0.003, 0.15, 0.009), STEEL, rot=(R(4), 0, 0), bevel=0.0012)
    s.box((-W / 2 - 0.009, -0.168, 0.006), (0.016, 0.012, 0.008), STEEL, bevel=0.002)
    s.cyl((-W / 2 - 0.017, -0.168, 0.006), (-W / 2 - 0.02, -0.168, 0.006), 0.006, STEEL, seg=12)
    # the heavy barrel: thicker than the KS-7's, with cooling rings ahead of the gas block
    ybar(g, -0.262, MUZZLE_Y, 0.0, 0.0128, AK_BLUE, seg=20)
    for k in range(5):
        ring(g, -0.5 - k * 0.022, 0.0, 0.0128, 0.0016, shade(AK_BLUE, 0.85), seg=20, l=0.006)
    # gas block and tube support (as the KS-7), the front sight block at the muzzle
    side(g, [(-0.442, -0.014), (-0.474, -0.014), (-0.474, 0.03), (-0.452, 0.034), (-0.442, 0.03)], 0.022, AK_STEEL, bevel=0.002)
    ybar(g, -0.452, -0.476, 0.022, 0.0082, AK_STEEL, seg=14)
    for k in range(3):
        g.box((0.0094, -0.455 - k * 0.006, 0.022), (0.0012, 0.0034, 0.0034), shade(AK_STEEL, 0.3))
    fy = MUZZLE_Y + 0.03
    side(g, [(fy + 0.026, -0.014), (fy - 0.004, -0.014), (fy - 0.004, 0.018), (fy + 0.004, 0.022), (fy + 0.02, 0.022), (fy + 0.026, 0.018)], 0.022, AK_STEEL, bevel=0.002)
    for sx in (-1, 1):                                                   # front sight ears
        g.box((sx * 0.0074, fy + 0.012, 0.032), (0.0024, 0.012, 0.022), AK_STEEL, bevel=0.0007)
    s.box((0, fy + 0.012, SL - 0.007), (0.0022, 0.0022, 0.014), shade(STEEL, 0.5))
    # the folding bipod: a clamp behind the front sight, two legs folded back under the barrel, feet by the gas block
    ring(g, fy + 0.05, 0.0, 0.0128, 0.0034, shade(AK_STEEL, 0.95), seg=20, l=0.016)
    g.box((0, fy + 0.05, -0.018), (0.014, 0.016, 0.01), shade(AK_STEEL, 0.95), bevel=0.0015)
    for sx in (-1, 1):
        x = sx * 0.0072
        s.cyl((x, fy + 0.05, -0.021), (x, -0.47, -0.024), 0.0032, shade(STEEL, 0.55), seg=8)       # leg
        s.cyl((x, -0.47, -0.024), (x, -0.458, -0.024), 0.0048, shade(STEEL, 0.4), seg=10)            # foot
        s.box((x, fy + 0.03, -0.022), (0.0042, 0.03, 0.0042), shade(STEEL, 0.45), bevel=0.0008)     # leg sleeve
    s.cyl((0, -0.29, -0.019), (0, fy + 0.07, -0.019), 0.0032, shade(STEEL, 0.85), seg=8)            # cleaning rod
    P.slot("dustcover", (0, 0.0, 0.012))
    P.slot("handguard", (0, -0.262, 0.0))
    P.slot("grip", (0, -0.026, -0.042))
    P.slot("stock", (0, 0.0, -0.012))
    P.slot("rearsight", (0, -0.262, 0.014))
    P.slot("mount", (W / 2 + 0.006, -0.098, -0.01))
    P.slot("muzzle", (0, MUZZLE_Y, 0.0))
    P.slot("mag", (0, -0.176, -0.026))
    P.anchor("muzzle", (0, MUZZLE_Y - 0.007, 0.0))
    P.anchor("port", (-0.016, -0.12, 0.004))
    P.anchor("eye", (0, -0.27, SL))
    P.anchor("hand", (0, -0.36, -0.02))


@gpart("KSL_DRUM95", 2, 2, family="ksl", margin=0.08)
def ksl_drum95(P):
    """a 95-round drum: a short curved feed tower into a drum lying across the gun, a winding key on its left face"""
    m, p = P("metal"), P("polymer")
    box_mag(m, 0.058, 0.026, 0.068, 8, DRUM, plate=shade(DRUM, 0.9), ribs=(0.45,), rib_color=shade(DRUM, 0.85))
    round_top(P("brass"), -0.004, 0.004, r=0.0055, l=0.04, color=col("8C8F86"))
    cy, cz, r, w = 0.004, -0.112, 0.068, 0.074
    p.cyl((-w / 2, cy, cz), (w / 2, cy, cz), r, POLY, seg=36)                       # the drum shell
    for sx in (-1, 1):
        p.cyl((sx * (w / 2 - 0.004), cy, cz), (sx * (w / 2 + 0.0015), cy, cz), r - 0.006, POLY2, seg=36)   # face plates
        for k in range(6):                                                            # face ribs
            a = R(k * 60)
            p.box((sx * (w / 2 + 0.002), cy + math.cos(a) * r * 0.55, cz + math.sin(a) * r * 0.55), (0.0024, 0.006, r * 0.5),
                  shade(POLY2, 0.85), rot=(a + R(90), 0, 0), bevel=0.0008)
    m.cyl((w / 2 + 0.0015, cy, cz), (w / 2 + 0.008, cy, cz), 0.012, shade(DRUM, 1.2), seg=16)      # winding key hub
    m.box((w / 2 + 0.0095, cy, cz), (0.003, 0.03, 0.007), shade(DRUM, 1.3), bevel=0.001)          # winding key
    p.box((0, cy - r + 0.004, cz - 0.01), (w + 0.004, 0.012, 0.03), shade(POLY, 0.8), bevel=0.003)  # front window band


# ── builds ───────────────────────────────────────────────────────────────────
def _ksl(dc="KST_DC_STD", hg="KST_HG_POLY", grip="AK_PG_STD", stock="KST_STK_TUBE", muzzle="KST_FH_SLANT", rs="KST_RS_TAN",
         mag="KSL_DRUM95", dc_kids=None, hg_kids=None):
    t = {"dustcover": (dc, dc_kids or {}), "handguard": (hg, hg_kids or {}), "grip": (grip, {}), "stock": (stock, {}),
         "mag": (mag, {})}
    if muzzle:
        t["muzzle"] = (muzzle, {})
    if rs:
        t["rearsight"] = (rs, {})
    return t


preset("KSL_LMG", "KSL_LMG", _ksl())
# THE CARETAKER's (Killa's RPK-16 carries a red dot on its railed cover): a railed cover with the reflex sight, a brake
preset("KSL_BOSS", "KSL_LMG", _ksl(dc="KST_DC_RAIL", dc_kids={"scope": ("HOLO_EX", {})}, hg="KST_HG_RAIL", grip="AK_PG_ERGO",
                                   muzzle="BRAKE_76"))

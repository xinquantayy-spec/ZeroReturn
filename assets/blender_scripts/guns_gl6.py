"""Zero Return - Bittern GL-6 grenade launcher (decision ai-5b, 2026-11-08): MORTAR's launcher, an original design in
the place of EFT's M32A1 MSGL (Big Pipe's): a six-round revolving cylinder for 40x46 grenades under a top strap with a
rail, a short ribbed barrel with a folding front grip, a pistol grip and a collapsible tube stock. One part (the
cylinder, barrel and furniture are not modular), with a rail for a sight. Conventions: zr_guns.py (bore z = 0, the
frame's rear face y = 0, muzzle toward -Y; metres).
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, ring, pica, screw, grip_profile, trigger_guard, trigger, STEEL, BLACK, POLY, POLY2, RUBBER

FRAME = col("2F3331")           # anodised frame
CYL = col("3B3F3C")             # the cylinder's steel
TAN = col("7D6E55")             # the furniture (our own two-tone, not a maker's colour)
SL = 0.072                      # sight line above the bore (the ladder sight on the rail)
CYL_Z = -0.052                  # the cylinder's axis under the bore (the top chamber lines up with the barrel)
CYL_R = 0.064
BARREL_Y0, BARREL_Y1 = -0.215, -0.5


@gpart("GL6_LAUNCHER", 4, 2, family="gl6", margin=0.03)
def gl6_launcher(P):
    g, s, p = P("gunmetal"), P("metal"), P("polymer")
    # the cylinder: six chambers round an axis under the bore, flutes between them
    ybar(g, -0.035, -0.205, CYL_Z, CYL_R, CYL, seg=36)
    for k in range(6):
        a = R(30 + k * 60)
        y0, y1 = -0.035, -0.205
        cx, cz = math.cos(a) * CYL_R, CYL_Z + math.sin(a) * CYL_R
        g.box((cx * 0.98, (y0 + y1) / 2, cz), (0.012, (y0 - y1) - 0.03, 0.012), shade(CYL, 0.55), rot=(0, -a, 0), bevel=0.003)  # flutes
    for k in range(6):                                                   # chamber mouths on the front face
        a = R(90 + k * 60)
        s.cyl((math.cos(a) * 0.036, -0.205, CYL_Z + math.sin(a) * 0.036), (math.cos(a) * 0.036, -0.207, CYL_Z + math.sin(a) * 0.036), 0.0205, shade(CYL, 0.3), seg=16)
    ybar(s, -0.03, -0.215, CYL_Z, 0.012, STEEL, seg=12)                 # the axis pin
    # the frame: rear plate, front plate, the top strap over the cylinder and the bottom bar
    side(g, [(0.0, 0.03), (-0.035, 0.03), (-0.035, -0.125), (0.0, -0.125)], 0.07, FRAME, bevel=0.003)
    side(g, [(-0.205, 0.03), (-0.225, 0.03), (-0.225, -0.11), (-0.205, -0.11)], 0.06, FRAME, bevel=0.003)
    side(g, [(0.0, 0.042), (-0.225, 0.042), (-0.225, 0.026), (0.0, 0.026)], 0.03, FRAME, bevel=0.002)
    side(g, [(-0.03, -0.118), (-0.21, -0.118), (-0.21, -0.13), (-0.03, -0.13)], 0.024, FRAME, bevel=0.002)
    for sx in (-1, 1):
        screw(g, sx * 0.036, -0.016, 0.0, r=0.0035, color=shade(FRAME, 1.3))
        screw(g, sx * 0.031, -0.215, -0.04, r=0.0035, color=shade(FRAME, 1.3))
    pica(g, -0.01, -0.215, 0.042, color=BLACK)                             # the top rail
    # the ladder sight at the rail's rear, a post at the muzzle
    for sx in (-1, 1):
        s.box((sx * 0.009, -0.02, 0.06), (0.003, 0.008, 0.034), shade(STEEL, 0.45), bevel=0.0008)
    s.box((0, -0.02, SL), (0.021, 0.004, 0.006), shade(STEEL, 0.45), bevel=0.0008)
    s.box((0, -0.02, SL - 0.012), (0.021, 0.004, 0.0025), shade(STEEL, 0.6))
    # the barrel: a ribbed sleeve, the front grip's clamp and the front post
    ybar(g, BARREL_Y0, BARREL_Y1, 0.0, 0.03, FRAME, seg=28)
    ybar(s, BARREL_Y1 + 0.002, BARREL_Y1 - 0.004, 0.0, 0.0205, shade(STEEL, 0.25), seg=24)    # the bore's mouth
    for k in range(9):
        ring(g, -0.24 - k * 0.026, 0.0, 0.03, 0.0022, shade(FRAME, 0.8), seg=28, l=0.01)
    s.box((0, BARREL_Y1 + 0.02, 0.042), (0.004, 0.006, 0.026), shade(STEEL, 0.45), bevel=0.0006)
    g.box((0, BARREL_Y1 + 0.02, 0.03), (0.016, 0.014, 0.008), FRAME, bevel=0.002)
    ring(g, -0.33, 0.0, 0.03, 0.004, shade(FRAME, 0.9), seg=28, l=0.03)
    # the folding front grip under the barrel
    p.box((0, -0.33, -0.045), (0.022, 0.026, 0.026), TAN, bevel=0.004)
    p.tube([(0, -0.33, -0.05), (0, -0.336, -0.1), (0, -0.338, -0.135)], 0.0145, TAN, seg=12)
    p.box((0, -0.338, -0.14), (0.03, 0.03, 0.012), shade(TAN, 0.85), bevel=0.004)
    # pistol grip, trigger guard and trigger behind the cylinder, on a lower frame that runs back from the rear plate
    side(g, [(0.0, -0.05), (0.058, -0.05), (0.058, -0.122), (0.0, -0.13)], 0.032, FRAME, bevel=0.003)
    gp = grip_profile(0.03, -0.12, 14, 0.105, 0.034, grooves=3)
    side(p, gp, 0.03, TAN, bevel=0.004)
    trigger_guard(g, -0.03, 0.012, -0.12, color=FRAME)
    trigger(s, 0.005, -0.12)
    # the collapsible stock: a tube, the sliding body and a rubber pad
    ybar(g, 0.0, 0.2, -0.02, 0.013, FRAME, seg=16)
    side(p, [(0.12, 0.012), (0.255, 0.018), (0.262, -0.1), (0.24, -0.11), (0.21, -0.05), (0.12, -0.04)], 0.04, TAN, bevel=0.005)
    side(p, [(0.262, 0.02), (0.282, 0.022), (0.282, -0.11), (0.262, -0.112)], 0.046, RUBBER, bevel=0.004)
    P.slot("scope", (0, -0.11, 0.042 + 0.0095))
    P.anchor("muzzle", (0, BARREL_Y1 - 0.006, 0.0))
    P.anchor("frontsight", (0, BARREL_Y1 + 0.02, 0.055))
    P.anchor("eye", (0, -0.0, SL))
    P.anchor("hand", (0, -0.337, -0.09))
    P.anchor("grip", (0, 0.038, -0.07))
    P.anchor("port", (-0.03, -0.12, -0.02))


preset("GL6_LAUNCHER", "GL6_LAUNCHER", {})
# MORTAR's: a reflex sight on the rail, as Big Pipe's launcher carries one
preset("GL6_BOSS", "GL6_LAUNCHER", {"scope": ("HOLO_EX", {})})

"""Zero Return - the revolvers of economy-1a's eleventh slice (2026-11-08), original designs:

- Crake C-357 (EFT's Chiappa Rhino 50DS, .357 Magnum = our 9x33R): a six-shot double-action revolver that fires from
  the bottom chamber, so the bore sits low under the cylinder's axis; a flat-sided shroud over a 5-inch barrel, a
  cocking lever on top and a raked rubber grip. Bore axis z = 0, frame rear y = 0, muzzle y = -0.2.
- Crake C-9 (EFT's Rhino 200DS, 9x19): the same frame with a 2-inch barrel. Muzzle y = -0.125.
- Bustard B-12 (EFT's RSh-12, 12.7x55): a heavy five-shot revolver, also firing from the bottom chamber, with a long
  full-lug barrel, a rail under it and a large grip. Muzzle y = -0.27.
The cylinders are part of the gun (no detachable magazine: rounds are loaded one by one, as in EFT).
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, pica, trigger, trigger_guard, grip_profile, BLACK, STEEL, BLUED

CR_STEEL = col("3A3E42")
CR_GRIP = col("26282A")
CR_SL = 0.034
BZ_STEEL = col("34383B")
BZ_GRIP = col("2A2B2C")
BZ_SL = 0.046


def _cylinder(b, y0, y1, zc, r, n, color, chamber_r, bore_z=0.0):
    """a revolver cylinder about a Y axis at height zc: flutes, and the chamber mouths on its front face"""
    b.cyl((0, y0, zc), (0, y1, zc), r, color, seg=24)
    rc = zc - bore_z
    for k in range(n):
        a = R(270 + k * 360 / n)                                                   # the first chamber at the bottom, on the bore
        cx, cz = rc * math.cos(a), zc + rc * math.sin(a)
        b.cyl((cx, y1 + 0.0004, cz), (cx, y1 - 0.0006, cz), chamber_r, shade(color, 0.2), seg=12)
        fa = a + R(180 / n)                                                          # flutes between the chambers
        fx, fz = (r - 0.001) * math.cos(fa), zc + (r - 0.001) * math.sin(fa)
        b.box((fx, (y0 + y1) / 2, fz), (0.004, abs(y1 - y0) * 0.6, 0.004), shade(color, 0.55), rot=(0, -fa, 0))


def _crake(P, muzzle):
    g, s, p = P("gunmetal"), P("metal"), P("rubber")
    W = 0.03
    # the frame: a low front around the bore, the window for the cylinder, the top strap, the rear with the lever
    side(g, [(0.004, -0.024), (-0.07, -0.024), (-0.07, -0.008), (-0.018, -0.008), (-0.018, 0.034), (0.004, 0.034)], W, CR_STEEL, bevel=0.003)
    side(g, [(-0.018, 0.034), (-0.072, 0.034), (-0.072, 0.03), (-0.018, 0.03)], W - 0.004, CR_STEEL, bevel=0.0015)
    _cylinder(s, -0.02, -0.068, 0.014, 0.02, 6, shade(CR_STEEL, 1.15), 0.0042)
    # the barrel under its flat-sided shroud, the front sight
    ybar(g, -0.07, muzzle, 0.0, 0.0072, BLUED, seg=16)
    side(g, [(-0.07, 0.0), (muzzle, 0.0), (muzzle, 0.022), (-0.07, 0.03)], 0.022, CR_STEEL, bevel=0.002)
    side(s, [(muzzle + 0.012, 0.022), (muzzle + 0.004, 0.022), (muzzle + 0.004, CR_SL), (muzzle + 0.01, CR_SL)], 0.004, BLACK, bevel=0.0006)
    side(s, [(-0.004, 0.034), (-0.014, 0.034), (-0.014, CR_SL + 0.002), (-0.006, CR_SL + 0.002)], 0.012, BLACK, bevel=0.0008)
    s.box((0, 0.008, 0.026), (0.008, 0.014, 0.01), shade(STEEL, 1.1), bevel=0.0015)                 # the cocking lever
    # the guard, the trigger and the raked grip
    trigger_guard(g, -0.004, -0.06, -0.024, color=CR_STEEL, r=0.0034)
    trigger(s, -0.03, -0.024)
    side(p, grip_profile(0.004, -0.016, 22, 0.1, 0.04, grooves=4, swell=0.002), 0.032, CR_GRIP, bevel=0.004)
    P.anchor("grip", (0, 0.012, -0.06))
    P.anchor("hand", (-0.014, 0.016, -0.07))
    P.anchor("eye", (0, -0.01, CR_SL))
    P.anchor("muzzle", (0, muzzle, 0.0))
    P.anchor("port", (0, -0.044, 0.014))


@gpart("CRK357_REV", 2, 1, family="rev", cls="pistol", margin=0.05)
def crk357_rev(P):
    _crake(P, -0.2)


@gpart("CRK9_REV", 2, 1, family="rev", cls="pistol", margin=0.06)
def crk9_rev(P):
    _crake(P, -0.125)


@gpart("BZ12_REV", 3, 1, family="rev", cls="pistol", margin=0.04)
def bz12_rev(P):
    g, s, p = P("gunmetal"), P("metal"), P("rubber")
    W = 0.04
    # the heavy frame and top strap, the five-shot cylinder above the bore
    side(g, [(0.006, -0.032), (-0.09, -0.032), (-0.09, -0.01), (-0.024, -0.01), (-0.024, 0.046), (0.006, 0.046)], W, BZ_STEEL, bevel=0.004)
    side(g, [(-0.024, 0.046), (-0.094, 0.046), (-0.094, 0.04), (-0.024, 0.04)], W - 0.006, BZ_STEEL, bevel=0.002)
    _cylinder(s, -0.026, -0.088, 0.019, 0.027, 5, shade(BZ_STEEL, 1.15), 0.0072)
    # the full-lug barrel with a rail under it, the sights
    ybar(g, -0.09, -0.27, 0.0, 0.0105, BLUED, seg=18)
    side(g, [(-0.09, 0.0), (-0.27, 0.0), (-0.27, 0.028), (-0.09, 0.038)], 0.03, BZ_STEEL, bevel=0.003)
    side(g, [(-0.09, -0.002), (-0.25, -0.002), (-0.25, -0.016), (-0.09, -0.02)], 0.026, BZ_STEEL, bevel=0.002)
    pica(g, -0.12, -0.24, -0.016, color=BLACK, w=0.02, h=0.007, face="bottom")
    side(s, [(-0.262, 0.028), (-0.27, 0.028), (-0.27, BZ_SL), (-0.264, BZ_SL)], 0.006, BLACK, bevel=0.0008)
    side(s, [(-0.004, 0.046), (-0.016, 0.046), (-0.016, BZ_SL + 0.002), (-0.006, BZ_SL + 0.002)], 0.016, BLACK, bevel=0.001)
    s.box((0, 0.012, 0.034), (0.01, 0.018, 0.012), shade(STEEL, 1.1), bevel=0.002)                  # the hammer
    # the guard, the trigger and the large grip
    trigger_guard(g, -0.006, -0.074, -0.032, color=BZ_STEEL, r=0.004)
    trigger(s, -0.038, -0.032)
    side(p, grip_profile(0.006, -0.024, 16, 0.125, 0.05, grooves=4, swell=0.003), 0.04, BZ_GRIP, bevel=0.005)
    P.anchor("grip", (0, 0.014, -0.075))
    P.anchor("hand", (-0.018, 0.018, -0.088))
    P.anchor("eye", (0, -0.012, BZ_SL))
    P.anchor("muzzle", (0, -0.27, 0.0))
    P.anchor("port", (0, -0.056, 0.019))


preset("CRK357_REV", "CRK357_REV", {})
preset("CRK9_REV", "CRK9_REV", {})
preset("BZ12_REV", "BZ12_REV", {})

"""Zero Return - the 7.6x51 rifles of economy-1a's fifth slice (2026-11-08), original designs:

- Shrike S-14 (EFT's Springfield Armory M1A, 7.62x51 NATO = our 7.6x51): a self-loading rifle with a black synthetic
  stock, a ventilated handguard over the barrel, the operating rod and its handle on the right, an aperture rear sight
  on the receiver and the front sight on its flash suppressor; 10- and 20-round magazines; a bridge mount for a scope.
  Frame: bore axis z = 0, receiver rear y = 0, barrel end y = -0.72 (the suppressor adds 0.076). Sight line 0.04.
- Osprey OB-7 (EFT's Remington Model 700, 7.62x51): a bolt-action rifle with a round receiver, a heavy free-floated
  barrel, an olive overmolded stock, a detachable 5- or 10-round box magazine and no iron sights; a rail base on the
  receiver takes a scope. Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.842.
Conventions: zr_guns.py.
"""
import math
from zr_items import col, shade, R
from zr_guns import gpart, preset, side, ybar, ylathe, screw, pica, box_mag, round_top, trigger, trigger_guard, BLACK, STEEL, BLUED

NB = col("262826")          # parkerised steel
NS = col("2A2C2B")          # black synthetic stock
NG = col("363A35")          # fibreglass handguard
M1_SL = 0.04
OB_STEEL = col("2A2D2F")
OB_STOCK = col("4B5442")    # olive overmolded stock
OB_SPECK = col("2C3129")
BRASS = col("B8903E")


@gpart("M1A_RIFLE", 6, 2, family="nato", margin=0.03)
def m1a_rifle(P):
    g, s, w = P("gunmetal"), P("metal"), P("polymer")
    # the receiver, the bolt seen from above, the aperture rear sight with its knobs
    side(g, [(0.0, -0.012), (-0.235, -0.012), (-0.235, 0.012), (-0.215, 0.02), (-0.05, 0.022), (-0.01, 0.02), (0.0, 0.012)], 0.028, NB, bevel=0.002)
    s.box((0, -0.075, 0.022), (0.014, 0.05, 0.007), STEEL, bevel=0.0015)
    s.cyl((-0.01, -0.06, 0.02), (-0.017, -0.06, 0.02), 0.004, STEEL, seg=10)                                       # bolt roller
    side(g, [(-0.005, 0.02), (-0.035, 0.02), (-0.035, 0.03), (-0.021, M1_SL + 0.006), (-0.011, M1_SL + 0.006), (-0.005, 0.03)], 0.02, NB, bevel=0.001)
    g.torus((0, -0.016, M1_SL), 0.0042, 0.0013, NB, segU=12, segV=5, rot=(R(90), 0, 0))
    for sx in (-1, 1):
        s.cyl((sx * 0.01, -0.02, 0.027), (sx * 0.017, -0.02, 0.027), 0.0052, shade(STEEL, 0.55), seg=12)           # windage / elevation knobs
    # the operating rod and its handle on the right
    s.box((-0.017, -0.31, -0.002), (0.005, 0.27, 0.007), shade(STEEL, 0.55), bevel=0.0012)
    s.box((-0.021, -0.15, 0.004), (0.008, 0.05, 0.008), shade(STEEL, 0.55), bevel=0.0012)
    s.box((-0.03, -0.128, 0.006), (0.016, 0.012, 0.014), shade(STEEL, 0.6), bevel=0.002)
    # the synthetic stock: butt and wrist, then the fore-end under the receiver and barrel
    side(w, [(0.33, -0.016), (0.33, -0.135), (0.305, -0.14), (0.1, -0.082), (0.06, -0.078), (0.035, -0.05), (0.0, -0.036),
             (0.0, -0.012), (0.06, -0.008), (0.2, -0.012)], 0.036, NS, bevel=0.004)
    side(w, [(0.0, -0.012), (-0.44, -0.012), (-0.44, -0.028), (-0.25, -0.036), (-0.17, -0.04), (-0.06, -0.042), (0.0, -0.036)], 0.034, NS, bevel=0.003)
    s.box((0, 0.334, -0.076), (0.038, 0.008, 0.12), shade(STEEL, 0.5), bevel=0.002)                                  # butt plate
    # the ventilated handguard over the barrel
    side(w, [(-0.24, 0.006), (-0.42, 0.006), (-0.42, 0.026), (-0.25, 0.028)], 0.026, NG, bevel=0.003)
    for k in range(4):
        for sx in (-1, 1):
            w.box((sx * 0.0132, -0.27 - k * 0.04, 0.018), (0.0012, 0.022, 0.006), shade(NG, 0.35))
    # barrel, front band, gas cylinder and its lock
    ybar(g, -0.235, -0.72, 0.0, 0.0095, BLUED, seg=18)
    side(g, [(-0.44, -0.03), (-0.47, -0.03), (-0.47, 0.012), (-0.44, 0.012)], 0.03, NB, bevel=0.002)
    ybar(g, -0.47, -0.58, -0.02, 0.0085, NB, seg=14)
    side(g, [(-0.58, -0.032), (-0.6, -0.032), (-0.6, 0.002), (-0.58, 0.002)], 0.02, NB, bevel=0.0015)
    # trigger guard, trigger, safety and the magazine catch
    trigger_guard(g, 0.035, -0.03, -0.036, color=NB, r=0.0038)
    trigger(s, 0.008, -0.036)
    s.box((0, -0.034, -0.038), (0.006, 0.006, 0.01), STEEL, bevel=0.001)
    s.box((0, -0.06, -0.042), (0.012, 0.006, 0.008), STEEL, bevel=0.001)
    P.slot("muzzle", (0, -0.72, 0.0))
    P.slot("mount", (0, -0.12, 0.022))
    P.slot("mag", (0, -0.11, -0.036))
    P.anchor("muzzle", (0, -0.72, 0.0))
    P.anchor("port", (-0.014, -0.08, 0.016))
    P.anchor("eye", (0, -0.016, M1_SL))
    P.anchor("hand", (0, -0.33, -0.04))
    P.anchor("grip", (0, 0.055, -0.06))


@gpart("M1A_FH", 1, 1, family="nato", margin=0.14, view="left_hi")
def m1a_fh(P):
    """the flash suppressor with the front sight and the bayonet lug (EFT's M1A National Match flash suppressor)"""
    g = P("gunmetal")
    side(g, [(0.0, -0.012), (-0.022, -0.012), (-0.022, 0.012), (0.0, 0.012)], 0.028, NB, bevel=0.0015)               # collar
    ybar(g, -0.02, -0.075, 0.0, 0.0118, NB, seg=20)
    for k in range(6):
        a = R(30 + k * 60)
        g.box((0.0116 * math.cos(a), -0.052, 0.0116 * math.sin(a)), (0.0035, 0.036, 0.0035), shade(NB, 0.15), rot=(0, -a, 0))
    ybar(g, -0.074, -0.076, 0.0, 0.0072, shade(NB, 0.3), seg=16)
    g.box((0, -0.012, -0.018), (0.008, 0.02, 0.01), NB, bevel=0.001)                                                 # bayonet lug
    side(g, [(-0.006, 0.01), (-0.018, 0.01), (-0.016, M1_SL - 0.003), (-0.01, M1_SL - 0.003)], 0.0032, NB)          # front sight blade
    for sx in (-1, 1):
        side(g, [(-0.004, 0.01), (-0.02, 0.01), (-0.02, M1_SL - 0.006), (-0.006, M1_SL - 0.006)], 0.0018, NB, x=sx * 0.0065)
    P.anchor("muzzle", (0, -0.076, 0.0))


@gpart("M1A_MNT", 2, 1, family="nato", margin=0.08, view="left_hi")
def m1a_mnt(P):
    """a bridge over the receiver clamped to its left side, a rail on top"""
    g = P("gunmetal")
    side(g, [(0.07, 0.006), (-0.075, 0.006), (-0.075, 0.016), (0.07, 0.016)], 0.03, BLACK, bevel=0.002)
    for y in (0.05, -0.055):
        side(g, [(y + 0.015, -0.03), (y - 0.015, -0.03), (y - 0.015, 0.016), (y + 0.015, 0.016)], 0.006, BLACK, x=0.018, bevel=0.0012)
        screw(g, 0.0215, y, -0.02, r=0.0026, color=STEEL)
    pica(g, 0.068, -0.073, 0.016)
    P.slot("scope", (0, -0.003, 0.016 + 0.0095))


def _mag(P, length, width, depth, curve, color, plate, ribs):
    box_mag(P("metal"), length, width, depth, curve, color, plate=plate, ribs=ribs, rib_color=shade(color, 1.2))
    round_top(P("brass"), -0.004, 0.004, r=0.0058, l=0.05, color=BRASS)


@gpart("M1A_MAG", 1, 1, family="nato", margin=0.1)
def m1a_mag(P):
    _mag(P, 0.062, 0.03, 0.076, 1, col("2C2E2C"), col("232524"), (0.5,))


@gpart("M1A_MAG20", 1, 2, family="nato", margin=0.1)
def m1a_mag20(P):
    _mag(P, 0.112, 0.03, 0.076, 3, col("2C2E2C"), col("232524"), (0.3, 0.62))


@gpart("M700_BOLT", 6, 2, family="nato", margin=0.03)
def m700_bolt(P):
    g, s, w, r = P("gunmetal"), P("metal"), P("polymer"), P("rubber")
    # the round receiver, its port with the bolt body, the recoil lug
    ybar(g, 0.0, -0.21, 0.0, 0.0175, OB_STEEL, seg=22)
    g.box((-0.012, -0.1, 0.006), (0.008, 0.075, 0.014), shade(OB_STEEL, 0.4))
    s.box((-0.009, -0.1, 0.008), (0.006, 0.07, 0.01), STEEL, bevel=0.0015)
    side(g, [(-0.2, -0.026), (-0.215, -0.026), (-0.215, 0.0), (-0.2, 0.0)], 0.03, OB_STEEL, bevel=0.0015)
    # the heavy barrel and its crown
    ylathe(g, [(0.0158, 0.21), (0.0158, 0.27), (0.0138, 0.42), (0.0118, 0.84)], OB_STEEL, seg=22)
    ybar(g, -0.836, -0.842, 0.0, 0.0065, shade(OB_STEEL, 0.3), seg=14)
    # the overmolded stock: butt and grip, the flat fore-end under the floated barrel, flecks of the pattern
    side(w, [(0.36, -0.006), (0.36, -0.14), (0.33, -0.145), (0.13, -0.085), (0.11, -0.105), (0.075, -0.105), (0.04, -0.045),
             (0.0, -0.036), (0.0, -0.012), (0.08, -0.012), (0.22, -0.008)], 0.038, OB_STOCK, bevel=0.005)
    side(w, [(0.0, -0.006), (-0.47, -0.006), (-0.47, -0.04), (-0.2, -0.046), (-0.05, -0.046), (0.0, -0.036)], 0.044, OB_STOCK, bevel=0.005)
    for y, z in ((0.3, -0.05), (0.25, -0.09), (0.18, -0.04), (0.12, -0.06), (-0.08, -0.03), (-0.2, -0.02), (-0.3, -0.035), (-0.41, -0.022)):
        for sx in (-1, 1):
            hw = 0.0195 if y > 0 else 0.0225
            w.box((sx * hw, y, z), (0.001, 0.012, 0.007), OB_SPECK)
    r.box((0, 0.368, -0.073), (0.04, 0.016, 0.136), col("1E1F1E"), bevel=0.004)                                       # recoil pad
    # trigger guard, trigger, the magazine well's bottom metal and its catch
    trigger_guard(g, 0.06, -0.005, -0.034, color=OB_STEEL, r=0.0036)
    trigger(s, 0.03, -0.034)
    side(g, [(-0.055, -0.034), (-0.165, -0.034), (-0.165, -0.046), (-0.055, -0.046)], 0.034, OB_STEEL, bevel=0.0015)
    s.box((0, -0.05, -0.048), (0.008, 0.008, 0.006), STEEL, bevel=0.001)
    # the bolt (moves when cycled): shroud, cocking piece, the handle swept down on the right
    b = P.sub("bolt")
    bs = b("metal")
    bs.cyl((0, 0.0, 0.0), (0, 0.045, 0.0), 0.0135, OB_STEEL, seg=16)
    bs.cyl((0, 0.045, 0.0), (0, 0.052, 0.0), 0.0085, shade(OB_STEEL, 0.8), seg=14)
    bs.cyl((-0.012, 0.006, 0.002), (-0.048, 0.01, -0.016), 0.0042, STEEL, seg=10)
    bs.cyl((-0.048, 0.01, -0.016), (-0.06, 0.012, -0.022), 0.0095, STEEL, seg=16, smooth=True)
    P.slot("mount", (0, -0.105, 0.0175))
    P.slot("mag", (0, -0.11, -0.034))
    P.anchor("muzzle", (0, -0.842, 0.0))
    P.anchor("port", (-0.014, -0.1, 0.01))
    P.anchor("bolt", (-0.06, 0.012, -0.022))
    P.anchor("eye", (0, -0.12, 0.032))
    P.anchor("hand", (0, -0.36, -0.045))
    P.anchor("grip", (0, 0.085, -0.07))


@gpart("M700_RAIL", 2, 1, family="nato", margin=0.08, view="left_hi")
def m700_rail(P):
    """a long rail base screwed to the receiver's top"""
    g = P("gunmetal")
    side(g, [(0.095, -0.004), (-0.105, -0.004), (-0.105, 0.006), (0.095, 0.006)], 0.022, BLACK, bevel=0.0015)
    pica(g, 0.093, -0.103, 0.006)
    P.slot("scope", (0, -0.005, 0.006 + 0.0095))


@gpart("M700_MAG", 1, 1, family="nato", margin=0.12)
def m700_mag(P):
    _mag(P, 0.048, 0.028, 0.078, 0, col("262829"), col("1E2021"), ())


@gpart("M700_MAG10", 1, 1, family="nato", margin=0.1)
def m700_mag10(P):
    _mag(P, 0.084, 0.028, 0.078, 0, col("262829"), col("1E2021"), (0.5,))


preset("M1A_RIFLE", "M1A_RIFLE", {"muzzle": ("M1A_FH", {}), "mag": ("M1A_MAG", {})})
preset("M700_BOLT", "M700_BOLT", {"mag": ("M700_MAG", {}), "mount": ("M700_RAIL", {})})

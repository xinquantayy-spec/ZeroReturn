"""Zero Return - the personal defence weapons of economy-1a's seventh slice (2026-11-08), original designs:

- Swift PW-46 (EFT's HK MP7A1, 4.6x30): a compact polymer body with a full-length top rail and folding irons, the
  magazine inside the pistol grip, a folding front grip and a sliding two-rod stock (shown open).
  Frame: bore axis z = 0, receiver rear y = 0, muzzle y = -0.255. Sight line 0.056 (the irons on the rail).
- Petrel PD-57 (EFT's FN P90, 5.7x28): a bullpup shell with the thumbhole grip, the 50-round magazine lying on top
  and a built-in ring sight; empty cases drop out underneath.
  Frame: bore axis z = 0, butt y = 0, muzzle y = -0.5. Sight line 0.083.
Conventions: zr_guns.py.
"""
from zr_items import col, shade
from zr_guns import gpart, preset, side, ybar, pica, box_mag, round_top, trigger, trigger_guard, grip_profile, BLACK, STEEL

PW_POLY = col("232526")
PW_SL = 0.056
PD_POLY = col("3B3E36")          # dark olive shell
PD_GRIP = col("26282A")
PD_SL = 0.083


@gpart("MP7_SMG", 3, 2, family="pdw", margin=0.04)
def mp7_smg(P):
    p, g, s = P("polymer"), P("gunmetal"), P("metal")
    # the body, the rail with folding irons, the charging handle
    side(p, [(0.0, 0.03), (-0.2, 0.03), (-0.212, 0.018), (-0.212, -0.024), (-0.12, -0.03), (-0.04, -0.032), (0.0, -0.022)], 0.032, PW_POLY, bevel=0.004)
    pica(g, -0.002, -0.172, 0.03)
    for y0, y1 in ((0.0, -0.012), (-0.158, -0.17)):
        side(g, [(y0, 0.0395), (y1, 0.0395), (y1 + 0.002, PW_SL + 0.004), (y0 - 0.002, PW_SL + 0.004)], 0.016, BLACK, bevel=0.001)
    g.torus((0, -0.006, PW_SL), 0.0035, 0.0011, BLACK, segU=12, segV=5, rot=(1.5708, 0, 0))
    s.box((0, 0.006, 0.026), (0.03, 0.012, 0.01), shade(STEEL, 0.5), bevel=0.002)
    # the grip that holds the magazine, the trigger in front of it, the folding front grip
    side(p, grip_profile(0.0, -0.03, 8, 0.1, 0.034, grooves=3), 0.03, PW_POLY, bevel=0.003)
    trigger_guard(g, -0.032, -0.082, -0.032, color=PW_POLY, r=0.0034)
    trigger(s, -0.052, -0.032)
    side(p, [(-0.14, -0.032), (-0.17, -0.032), (-0.172, -0.092), (-0.142, -0.092)], 0.024, PW_POLY, bevel=0.003)
    # barrel and its flash hider
    ybar(g, -0.21, -0.24, 0.0, 0.0075, STEEL, seg=14)
    ybar(g, -0.236, -0.255, 0.0, 0.0088, shade(STEEL, 0.7), seg=14)
    # the sliding stock, open: two rods and the butt plate
    for sx in (-1, 1):
        s.cyl((sx * 0.011, 0.0, 0.004), (sx * 0.011, 0.17, 0.004), 0.0045, shade(STEEL, 0.6), seg=10)
    side(p, [(0.17, 0.02), (0.182, 0.02), (0.182, -0.07), (0.17, -0.07)], 0.034, PW_POLY, bevel=0.003)
    P.slot("scope", (0, -0.085, 0.03 + 0.0095))
    P.slot("mag", (0, 0.004, -0.034))
    P.anchor("muzzle", (0, -0.255, 0.0))
    P.anchor("port", (-0.016, -0.08, 0.008))
    P.anchor("eye", (0, -0.006, PW_SL))
    P.anchor("hand", (0, -0.156, -0.07))
    P.anchor("grip", (0, 0.004, -0.07))


@gpart("P90_SMG", 3, 2, family="pdw", margin=0.04)
def p90_smg(P):
    p, g, s = P("polymer"), P("gunmetal"), P("metal")
    # the bullpup shell: the front grip, the thumbhole, the stock under the hand
    side(p, [(0.0, 0.035), (-0.4, 0.035), (-0.44, 0.015), (-0.45, -0.025), (-0.32, -0.03), (-0.3, -0.11), (-0.255, -0.115),
             (-0.25, -0.05), (-0.18, -0.05), (-0.15, -0.11), (-0.01, -0.12), (0.0, -0.06)], 0.055, PD_POLY, bevel=0.006)
    side(p, [(-0.3, -0.06), (-0.31, -0.105), (-0.26, -0.108), (-0.258, -0.06)], 0.057, PD_GRIP, bevel=0.003)          # grip panels
    s.box((0, -0.1, -0.121), (0.03, 0.06, 0.004), shade(PD_POLY, 0.4))                                                  # ejection chute
    # the built-in ring sight over the front of the magazine
    side(g, [(-0.3, 0.035), (-0.37, 0.035), (-0.37, 0.07), (-0.345, PD_SL + 0.01), (-0.305, PD_SL + 0.01), (-0.3, 0.07)], 0.03, PD_GRIP, bevel=0.003)
    g.torus((0, -0.3, PD_SL), 0.006, 0.0014, shade(PD_GRIP, 0.6), segU=14, segV=5, rot=(1.5708, 0, 0))
    # barrel, flash hider, the charging handles either side, the trigger in the front grip
    ybar(g, -0.44, -0.48, 0.0, 0.0085, STEEL, seg=14)
    ybar(g, -0.476, -0.5, 0.0, 0.0105, shade(STEEL, 0.7), seg=14)
    for sx in (-1, 1):
        s.box((sx * 0.029, -0.36, 0.0), (0.006, 0.012, 0.008), shade(STEEL, 0.5), bevel=0.0015)
    trigger(s, -0.29, -0.05)
    P.slot("mag", (0, -0.2, 0.035))
    P.anchor("muzzle", (0, -0.5, 0.0))
    P.anchor("port", (0, -0.1, -0.11))
    P.anchor("eye", (0, -0.2, PD_SL))
    P.anchor("hand", (0, -0.4, -0.02))
    P.anchor("grip", (0, -0.275, -0.075))


def _mp7_mag(P, length):
    box_mag(P("polymer"), length, 0.022, 0.036, 0, col("1E1F20"), plate=col("171819"), ribs=(), rib_color=None)
    round_top(P("brass"), -0.002, 0.002, r=0.0026, l=0.026, color=col("B8903E"))


@gpart("MP7_MAG20", 1, 1, family="pdw", margin=0.12)
def mp7_mag20(P):
    _mp7_mag(P, 0.12)


@gpart("MP7_MAG30", 1, 2, family="pdw", margin=0.1)
def mp7_mag30(P):
    _mp7_mag(P, 0.165)


@gpart("MP7_MAG40", 1, 2, family="pdw", margin=0.1)
def mp7_mag40(P):
    _mp7_mag(P, 0.21)


@gpart("P90_MAG", 2, 1, family="pdw", margin=0.08, view="left_hi")
def p90_mag(P):
    """the 50-round magazine that lies along the top: a smoky polymer box with the rounds lying crosswise in it"""
    m, b = P("polymer"), P("brass")
    side(m, [(0.15, 0.0), (-0.15, 0.0), (-0.15, 0.03), (0.13, 0.032), (0.15, 0.028)], 0.05, col("4A4D4F"), bevel=0.004)
    for k in range(10):
        b.cyl((-0.026, 0.12 - k * 0.026, 0.015), (0.026, 0.12 - k * 0.026, 0.015), 0.0029, col("B8903E"), seg=8)


preset("MP7_SMG", "MP7_SMG", {"mag": ("MP7_MAG30", {})})
preset("P90_SMG", "P90_SMG", {"mag": ("P90_MAG", {})})

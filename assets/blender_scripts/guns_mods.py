"""Zero Return - generic weapon parts for rails (sights, mounts, foregrips, tactical devices) and the multitool.
Original designs. Rail parts have their origin on the rail top (devices hang below a bottom rail: their origin
is the rail surface and the device is under it); scopes for rings have their origin on the tube axis.
"""
import math
from zr_items import col, shade, mixc, R
from zr_guns import (gpart, side, box, ybar, ring, ylathe, pica, screw, lens, dot, suppressor,
                     BLACK, BLACK2, STEEL, POLY, POLY2, FDE, ODG, RUBBER, GLASS, WHITE, DOT)

TAN = col("7C6A4E")
LENS_TINT = col("3B5A66")
COATING = col("6B4D8A")


def clamp_base(g, L, color=BLACK, w=0.026, h=0.007, lever=False, knob=True, y=0.0, below=False):
    """a rail clamp: a body on the rail face and two jaws hugging the rail sides with a cross bolt (below: the
    device hangs under a bottom rail, so the body is under the origin and the jaws above it)"""
    jz = 0.002 if below else -0.002
    g.box((0, y, -h / 2 if below else h / 2), (w, L, h), color, bevel=0.0016)
    for sx in (-1, 1):
        g.box((sx * 0.0115, y, jz), (0.004, L * 0.9, 0.006), color, bevel=0.001)
    if knob:
        g.cyl((0.0125, y, jz), (0.017, y, jz), 0.0045, shade(color, 1.3), seg=12)
    if lever:
        g.box((0.016, y + 0.006, 0.0), (0.004, 0.026, 0.006), shade(color, 1.2), rot=(R(6), 0, 0), bevel=0.0012)


# ── reflex / holographic / compact sights ────────────────────────────────────
@gpart("RED_DOT", 1, 1, margin=0.1)
def red_dot(P):
    g, s = P("gunmetal"), P("metal")
    H = 0.042
    clamp_base(g, 0.036, lever=True)
    side(g, [(0.018, 0.007), (-0.018, 0.007), (-0.012, H - 0.012), (0.012, H - 0.012)], 0.02, BLACK, bevel=0.002)
    ybar(g, 0.03, -0.034, H, 0.0185, BLACK, seg=24)
    for y in (0.03, -0.034):
        ybar(g, y + (0.003 if y > 0 else -0.003), y, H, 0.0205, BLACK2, seg=24)
    g.cyl((0, -0.004, H + 0.017), (0, -0.004, H + 0.025), 0.0068, BLACK2, seg=14)     # elevation cap
    g.cyl((-0.017, -0.004, H), (-0.025, -0.004, H), 0.0068, BLACK2, seg=14)           # windage cap
    s.cyl((0.017, 0.006, H - 0.004), (0.026, 0.006, H - 0.004), 0.0075, STEEL, seg=16)  # brightness dial
    for k in range(8):
        a = k * math.pi / 4
        s.box((0.026, 0.006 + 0.0075 * math.cos(a), H - 0.004 + 0.0075 * math.sin(a)), (0.002, 0.0016, 0.0016), shade(STEEL, 0.6))
    lens(P, -0.0365, H, 0.0158, facing=-1, tint=COATING)
    lens(P, 0.0325, H, 0.0158, facing=1, tint=LENS_TINT)
    dot(P, 0.031, H, r=0.0008)
    P.anchor("eye", (0, 0.033, H))


@gpart("HOLO_EX", 1, 1, margin=0.1)
def holo_ex(P):
    """holographic sight: a battery body on a clamp, and an open window frame (two cut-out side wings and a top
    bar) around the glass"""
    g = P("gunmetal")
    H = 0.038
    clamp_base(g, 0.07, w=0.028, lever=True)
    side(g, [(0.034, 0.007), (-0.034, 0.007), (-0.034, 0.016), (-0.028, 0.02), (0.03, 0.02), (0.034, 0.016)], 0.03, BLACK, bevel=0.003)
    for k in range(4):                                                    # body grip ribs
        g.box((0.0152, 0.018 - k * 0.007, 0.013), (0.0008, 0.0035, 0.007), shade(BLACK, 0.55))
    side(g, [(0.034, 0.02), (0.022, 0.02), (0.022, 0.028), (0.034, 0.028)], 0.022, BLACK2, bevel=0.0015)   # rear buttons
    for k in range(2):
        g.box((0.0, 0.0345, 0.022 + k * 0.0045), (0.01, 0.0012, 0.003), shade(BLACK2, 1.7), bevel=0.0005)
    for sx in (-1, 1):                                                    # side wings: a frame with a cut-out
        x = sx * 0.0158
        g.box((x, -0.0005, 0.0215), (0.0035, 0.043, 0.004), BLACK, bevel=0.0012)
        g.box((x, -0.0005, H + 0.0175), (0.0035, 0.043, 0.004), BLACK, bevel=0.0012)
        g.box((x, 0.0195, H), (0.0035, 0.004, 0.0335), BLACK, bevel=0.0012)
        g.box((x, -0.0205, H), (0.0035, 0.004, 0.0335), BLACK, bevel=0.0012)
    g.box((0.0, -0.0005, H + 0.0195), (0.0355, 0.043, 0.0035), BLACK, bevel=0.0012)   # top bar
    P("glass").box((0.0, 0.012, H + 0.001), (0.028, 0.0018, 0.031), COATING)
    P("glass").box((0.0, -0.016, H + 0.001), (0.028, 0.0018, 0.031), LENS_TINT)
    dot(P, 0.011, H, r=0.0012)
    P.anchor("eye", (0, 0.014, H))


@gpart("SIGHT_MICRO", 1, 1, margin=0.14, view="left_hi")
def sight_micro(P):
    """compact open reflex on its own rail plate (on a pistol slide cut the plate sits in the cut)"""
    g = P("gunmetal")
    H = 0.017
    clamp_base(g, 0.034, w=0.024, h=0.004, knob=True)
    g.box((0, 0.0, 0.0075), (0.024, 0.04, 0.007), BLACK, bevel=0.0022)
    side(g, [(0.004, 0.009), (-0.02, 0.009), (-0.018, 0.028), (-0.014, 0.031), (-0.002, 0.031)], 0.0225, BLACK, bevel=0.0018)
    P("glass").box((0, -0.008, 0.02), (0.019, 0.0015, 0.016), COATING)
    dot(P, 0.0, H + 0.002, r=0.0007)
    P.anchor("eye", (0, -0.006, H + 0.003))


# ── magnified optics ─────────────────────────────────────────────────────────
@gpart("SCOPE_4X", 2, 1, margin=0.07, view="left_hi")
def scope_4x(P):
    g, r = P("gunmetal"), P("rubber")
    H = 0.046
    clamp_base(g, 0.05, w=0.028, h=0.009, knob=False, y=0.006)
    for y in (-0.008, 0.02):                                            # thumb nuts
        g.cyl((0.014, y, 0.002), (0.02, y, 0.002), 0.0055, BLACK2, seg=12)
    side(g, [(0.05, 0.009), (-0.045, 0.009), (-0.055, H - 0.004), (-0.055, H + 0.02), (0.035, H + 0.02), (0.05, H + 0.004)], 0.03, TAN, bevel=0.004)
    ybar(g, -0.055, -0.088, H, 0.0185, TAN, seg=24)                     # objective
    ybar(g, -0.084, -0.09, H, 0.0205, shade(TAN, 0.8), seg=24)
    ybar(g, 0.05, 0.075, H + 0.004, 0.0152, TAN, seg=20)                 # eyepiece
    ybar(r, 0.075, 0.084, H + 0.004, 0.0165, RUBBER, seg=20)
    g.box((0, 0.004, H + 0.024), (0.012, 0.03, 0.006), shade(TAN, 0.85), bevel=0.002)   # top fibre housing
    P("emissive").box((0, 0.004, H + 0.0272), (0.004, 0.026, 0.0008), col("E8A23A"))
    g.cyl((0.015, -0.01, H + 0.006), (0.021, -0.01, H + 0.006), 0.0065, shade(TAN, 0.8), seg=14)
    g.cyl((0, -0.01, H + 0.02), (0, -0.01, H + 0.027), 0.0065, shade(TAN, 0.8), seg=14)
    lens(P, -0.0905, H, 0.0168, facing=-1, tint=COATING)
    lens(P, 0.0845, H + 0.004, 0.0118, facing=1, tint=LENS_TINT)
    P.anchor("eye", (0, 0.085, H + 0.004))


def tube_scope(P, L, obj_r, obj_len, eye_r=0.0205, color=BLACK, shade_len=0.0, lever=True, parallax=False):
    """a 30 mm tube scope: origin on the tube axis at the centre of the rings"""
    g, r = P("gunmetal"), P("rubber")
    y_eye = L - 0.07 - obj_len - shade_len     # rear face of the eyepiece (the front lens is at -0.07 - obj - shade)
    ybar(g, y_eye - 0.058, -0.07, 0.0, 0.015, color, seg=24)
    # objective bell
    ylathe(g, [(0.015, 0.0), (0.0165, 0.012), (obj_r, obj_len * 0.6), (obj_r, obj_len)], color, y=-0.07, seg=28)
    if shade_len:
        ybar(g, -0.07 - obj_len, -0.07 - obj_len - shade_len, 0.0, obj_r + 0.0006, shade(color, 0.85), seg=28)
    # eyepiece (widest at its rear face)
    ylathe(g, [(eye_r, 0.0), (eye_r, 0.035), (0.0168, 0.05), (0.015, 0.06)], color, y=y_eye, seg=26)
    ybar(r, y_eye + 0.002, y_eye - 0.006, 0.0, eye_r + 0.0009, RUBBER, seg=26)
    for k in range(8):                                                   # magnification ring grip
        a = k * math.pi / 4
        g.box((0.018 * math.cos(a), y_eye - 0.045, 0.018 * math.sin(a)), (0.002, 0.008, 0.002), shade(color, 0.6), rot=(0, -a, 0))
    if lever:
        g.box((0.0, y_eye - 0.045, 0.024), (0.004, 0.006, 0.012), shade(color, 1.4), bevel=0.0012)
    # turret saddle, elevation (top), windage (right), illumination or parallax (left)
    g.box((0, -0.002, 0.0), (0.036, 0.04, 0.036), color, bevel=0.007)
    g.cyl((0, -0.002, 0.016), (0, -0.002, 0.034), 0.0105, shade(color, 1.1), seg=20)
    g.cyl((-0.016, -0.002, 0.0), (-0.034, -0.002, 0.0), 0.0105, shade(color, 1.1), seg=20)
    for k in range(16):
        a = k * math.pi / 8
        g.box((0.0105 * math.cos(a), -0.002 + 0.0105 * math.sin(a), 0.03), (0.0012, 0.0012, 0.006), shade(color, 0.5))
    g.cyl((0.016, -0.002, 0.0), (0.03, -0.002, 0.0), 0.011 if parallax else 0.0085, shade(color, 1.05), seg=20)
    g.box((0.0305, -0.002, 0.004), (0.0008, 0.0012, 0.006), WHITE)
    for k in range(5):                                                   # turret index marks
        g.box((0.0, -0.002 - 0.0108, 0.02 + k * 0.0028), (0.0016, 0.0006, 0.0006), WHITE)
    lens(P, -0.07 - obj_len - shade_len - 0.0004, 0.0, obj_r - 0.0012, facing=-1, tint=COATING)
    lens(P, y_eye + 0.0004, 0.0, eye_r - 0.002, facing=1, tint=LENS_TINT)
    P.anchor("eye", (0, y_eye, 0.0))


@gpart("SCOPE_16", 3, 1, margin=0.05)
def scope_16(P):
    tube_scope(P, 0.27, 0.0205, 0.04)


@gpart("SCOPE_8X", 3, 1, margin=0.05)
def scope_8x(P):
    tube_scope(P, 0.33, 0.0265, 0.065, shade_len=0.035, lever=False, parallax=True)


# ── mounts ───────────────────────────────────────────────────────────────────
@gpart("MNT_RISER", 1, 1, margin=0.14, view="left_hi")
def mnt_riser(P):
    g = P("gunmetal")
    clamp_base(g, 0.042, h=0.008)
    side(g, [(0.021, 0.008), (-0.021, 0.008), (-0.017, 0.019), (0.017, 0.019)], 0.02, BLACK, bevel=0.0015)
    for y in (0.012, -0.012):
        g.box((0.0, y, 0.0135), (0.021, 0.008, 0.006), shade(BLACK, 0.3))   # lightening cuts
    pica(g, 0.02, -0.02, 0.019)
    P.slot("scope", (0, 0.0, 0.019 + 0.0095))


@gpart("MNT_RINGS", 2, 1, margin=0.08, view="left_hi")
def mnt_rings(P):
    """one-piece 30 mm cantilever mount: ring centres 0.038 above the rail top"""
    g = P("gunmetal")
    H = 0.038
    clamp_base(g, 0.08, h=0.008, y=0.01)
    for y in (0.035, -0.018):
        g.cyl((0.0125, y, -0.001), (0.017, y, -0.001), 0.0045, shade(BLACK, 1.3), seg=12)
    side(g, [(0.05, 0.008), (-0.045, 0.008), (-0.055, 0.02), (-0.03, 0.02), (0.04, 0.016)], 0.016, BLACK, bevel=0.0015)
    for y in (0.03, -0.045):                                             # two rings with split caps
        g.box((0, y, H - 0.024), (0.02, 0.012, 0.016), BLACK, bevel=0.002)
        g.torus((0, y, H), 0.0172, 0.0026, BLACK, segU=24, segV=6, rot=(R(90), 0, 0))
        for sx in (-1, 1):
            g.box((sx * 0.0175, y, H + 0.001), (0.0048, 0.011, 0.005), BLACK2, bevel=0.0008)
            g.cyl((sx * 0.0175, y, H + 0.0035), (sx * 0.0175, y, H + 0.0055), 0.0018, STEEL, seg=8)
    P.slot("scope", (0, -0.008, H))


# ── foregrips (origin on the rail surface; the grip hangs below) ─────────────
@gpart("GRIP_V", 1, 1, margin=0.12)
def grip_v(P):
    g, p = P("gunmetal"), P("polymer")
    g.box((0, 0.0, -0.005), (0.026, 0.034, 0.01), BLACK, bevel=0.0018)
    for sx in (-1, 1):
        g.box((sx * 0.0115, 0.0, 0.002), (0.004, 0.03, 0.006), BLACK, bevel=0.001)
    p.cyl((0, 0.0, -0.01), (0, 0.0, -0.108), 0.0158, POLY, seg=20, smooth=True)
    for k in range(4):                                                   # finger grooves
        ring_z = -0.03 - k * 0.019
        p.torus((0, 0.0, ring_z), 0.0158, 0.0022, shade(POLY, 0.6), segU=20, segV=5)
    p.cyl((0, 0.0, -0.108), (0, 0.0, -0.112), 0.0145, shade(POLY, 0.7), seg=20)
    P.anchor("hand", (0, 0.0, -0.055))


@gpart("GRIP_ANG", 1, 1, margin=0.12)
def grip_ang(P):
    p = P("polymer")
    side(p, [(0.032, 0.0), (-0.046, 0.0), (-0.046, -0.012), (-0.038, -0.022), (0.012, -0.037), (0.03, -0.031)], 0.028, FDE, bevel=0.0035)
    for k in range(5):
        p.box((0.0142, 0.02 - k * 0.012, -0.016), (0.0006, 0.004, 0.018), shade(FDE, 0.7))
    P.anchor("hand", (0, 0.004, -0.027))


@gpart("GRIP_STUB", 1, 1, margin=0.14)
def grip_stub(P):
    g, p = P("gunmetal"), P("polymer")
    g.box((0, 0.0, -0.005), (0.026, 0.03, 0.01), BLACK, bevel=0.0018)
    p.cyl((0, 0.0, -0.01), (0, 0.0, -0.056), 0.0165, POLY, seg=20, smooth=True)
    p.cyl((0, 0.0, -0.056), (0, 0.0, -0.06), 0.0175, shade(POLY, 0.7), seg=20)
    for k in range(6):
        a = k * math.pi / 3
        p.box((0.0166 * math.cos(a), 0.0166 * math.sin(a), -0.034), (0.002, 0.002, 0.03), shade(POLY, 0.55), rot=(0, 0, a))
    P.anchor("hand", (0, 0.0, -0.035))


@gpart("GRIP_STOP", 1, 1, margin=0.14, view="left_hi")
def grip_stop(P):
    p = P("polymer")
    side(p, [(0.02, 0.0), (-0.02, 0.0), (-0.02, -0.018), (-0.012, -0.02), (0.02, -0.006)], 0.022, POLY, bevel=0.0025)
    screw(p, 0.0115, 0.0, -0.006, r=0.0022, color=shade(STEEL, 0.6))
    P.anchor("hand", (0, 0.03, -0.012))


# ── tactical devices (origin on the rail surface; device below; "L" = left side rail) ──
@gpart("LIGHT_T", 1, 1, margin=0.12, rolls={"L": (0, -90, 0)})
def light_t(P):
    g, r = P("gunmetal"), P("rubber")
    clamp_base(g, 0.026, w=0.024, h=0.006, knob=False, below=True)
    g.box((0, 0.0, -0.009), (0.018, 0.024, 0.012), BLACK, bevel=0.002)
    Z = -0.021
    ybar(g, 0.036, -0.046, Z, 0.0124, BLACK, seg=22)
    for k in range(6):                                                   # grip knurl rings
        ring(g, 0.02 - k * 0.006, Z, 0.0124, 0.0006, shade(BLACK, 0.55), seg=22, l=0.0016)
    ylathe(g, [(0.0124, 0.0), (0.0165, 0.012), (0.0165, 0.028)], BLACK, y=-0.046, z=Z, seg=24)
    for k in range(6):                                                   # bezel crenellations
        a = k * math.pi / 3
        g.box((0.0158 * math.cos(a), -0.0745, Z + 0.0158 * math.sin(a)), (0.004, 0.003, 0.004), shade(BLACK, 0.4), rot=(0, -a, 0))
    lens(P, -0.0745, Z, 0.0145, facing=-1, tint=col("D8D8C8"))
    ybar(r, 0.036, 0.046, Z, 0.0118, RUBBER, seg=20)                     # tail switch
    P.anchor("beam", (0, -0.076, Z))


@gpart("LASER_COMBO", 1, 1, margin=0.12, rolls={"L": (0, -90, 0)})
def laser_combo(P):
    g = P("gunmetal")
    clamp_base(g, 0.03, w=0.024, h=0.006, knob=True, below=True)
    side(g, [(0.034, -0.006), (-0.04, -0.006), (-0.044, -0.012), (-0.044, -0.034), (0.03, -0.034), (0.036, -0.026)], 0.034, TAN, bevel=0.003)
    for k in range(3):
        g.box((0.0172, 0.02 - k * 0.008, -0.026), (0.0008, 0.0045, 0.009), shade(TAN, 0.6), bevel=0.0006)
    g.box((0.0, 0.0365, -0.02), (0.016, 0.002, 0.008), shade(TAN, 1.25), bevel=0.0008)   # switches on the back
    lens(P, -0.0445, -0.026, 0.0068, facing=-1, tint=col("D8D8C8"))
    lens(P, -0.0445, -0.016, 0.0035, facing=-1, tint=col("C02A20"))
    P.anchor("beam", (0, -0.046, -0.026))
    P.anchor("laser", (0, -0.046, -0.016))


@gpart("LASER_DOT", 1, 1, margin=0.14, rolls={"L": (0, -90, 0)})
def laser_dot(P):
    g = P("gunmetal")
    clamp_base(g, 0.022, w=0.022, h=0.005, knob=False, below=True)
    ybar(g, 0.024, -0.03, -0.014, 0.0088, BLACK, seg=18)
    ylathe(g, [(0.0088, 0.0), (0.0098, 0.004), (0.0098, 0.01)], BLACK2, y=-0.03, z=-0.014, seg=18)
    lens(P, -0.0405, -0.014, 0.004, facing=-1, tint=col("C02A20"))
    g.box((0.0, 0.024, -0.014), (0.006, 0.003, 0.006), shade(BLACK, 1.6), bevel=0.001)
    P.anchor("laser", (0, -0.041, -0.014))


# ── 9 mm suppressor (pistol threads and the SMG's three-lug barrel) ──────────
@gpart("SUPP_9", 2, 1, margin=0.08)
def supp_9(P):
    suppressor(P, 0.158, 0.0168, BLACK, collar=0.016)

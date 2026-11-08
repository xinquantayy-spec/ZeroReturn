"""Zero Return - item models E: the pictures the boss and event items were missing (2026-11-08): the antidote
injector, the red and green signal flares, the cult's amulet and knife, the Forester's pack and the Stoker's welding
mask. Original designs; the pack and the mask are the meshes characters wear (build_items_b.wearable), the rest are
modelled here in metres (front toward -Y, top +Z). The launcher round (AGL30_ROUND) is never carried and has none.
"""
import math
from zr_items import col, shade, label_band, cyl_x, cyl_z, R
from zr_item_reg import item
from build_items_b import wearable, BACK_VIEW

BONE = col("D9CDB0")
BLACKENED = col("2C2D2B")


@item("ANTIDOTE", 1, 1, view="three_q", margin=0.1)
def antidote(I):
    p, m = I("plastic"), I("metal")
    body = col("5C6B4A")
    cyl_x(p, -0.06, 0.05, 0.0, 0.012, 0.012, body, seg=18)                     # the barrel, lying
    cyl_x(p, 0.05, 0.075, 0.0, 0.012, 0.0125, col("D8A53A"), seg=18)          # the safety cap
    cyl_x(m, -0.072, -0.06, 0.0, 0.012, 0.008, col("9A9F9C"), seg=14, r2=0.006)  # the needle end
    label_band(I("paper"), (-0.005, -0.0122, 0.012), (0.07, 0, 0.012), col("E6E2D2"))
    label_band(I("paper"), (-0.005, -0.0124, 0.012), (0.07, 0, 0.003), col("B8302A"))


def flare(I, cap):
    c, p, m = I("cardboard"), I("plastic"), I("metal")
    cyl_z(c, 0, 0, 0.012, 0.16, 0.018, col("8A7F62"), seg=20)                # the paper tube
    cyl_z(p, 0, 0, 0.16, 0.19, 0.0195, cap, seg=20)                          # the coloured cap
    cyl_z(p, 0, 0, 0.19, 0.196, 0.012, shade(cap, 0.8), seg=16)
    cyl_z(m, 0, 0, 0.0, 0.012, 0.019, col("8C9290"), seg=20)                 # the base ring and its striker
    I("metal").torus((0, 0, -0.004), 0.012, 0.0022, col("8C9290"), segU=16, segV=6, rot=(R(90), 0, 0))
    label_band(I("paper"), (0, -0.0183, 0.09), (0.026, 0, 0.05), col("E2DCC6"))
    label_band(I("paper"), (0, -0.0185, 0.105), (0.026, 0, 0.008), cap)


@item("FLARE_RED", 1, 2, view="front_hi", margin=0.12)
def flare_red(I):
    flare(I, col("B8302A"))


@item("FLARE_GREEN", 1, 2, view="front_hi", margin=0.12)
def flare_green(I):
    flare(I, col("3E8A3A"))


@item("RITUAL_AMULET", 1, 1, view="top_tilt", margin=0.08)
def amulet(I):
    b, l = I("brass"), I("leather")
    tarnish = col("7A6A3E")
    cyl_z(b, 0, 0, 0.0, 0.004, 0.026, tarnish, seg=24)                        # the disc
    b.torus((0, 0, 0.0045), 0.02, 0.0018, shade(tarnish, 1.15), segU=24, segV=6)  # a raised ring
    cyl_z(b, 0, 0, 0.004, 0.007, 0.007, shade(tarnish, 1.2), seg=12)          # the boss
    for k in range(6):  # notches round the rim
        a = k * math.pi / 3
        b.box((0.023 * math.cos(a), 0.023 * math.sin(a), 0.004), (0.004, 0.004, 0.002), shade(tarnish, 0.7), rot=(0, 0, a))
    b.torus((0, 0.03, 0.002), 0.005, 0.0015, tarnish, segU=12, segV=5, rot=(0, R(90), 0))  # the bail
    l.torus((0, 0.07, 0.002), 0.038, 0.0016, col("3A2A1E"), segU=28, segV=5)  # the cord, coiled


@item("RITUAL_KNIFE", 1, 2, view="left", margin=0.08)
def ritual_knife(I):
    g, bone = I("gunmetal"), I("plastic")
    # vertical: the blade up (a curved, blackened edge), the bone grip down
    pts = [(0.0, 0.12), (0.014, 0.2), (0.016, 0.27), (0.006, 0.32), (-0.006, 0.31), (-0.014, 0.24), (-0.016, 0.12)]
    g.prism(list(reversed(pts)), -0.0025, 0.0025, BLACKENED, bevel=0.0)
    g.box((0, 0, 0.115), (0.012, 0.042, 0.01), shade(BLACKENED, 1.2), bevel=0.003)  # guard
    bone.box((0, -0.002, 0.06), (0.024, 0.028, 0.1), BONE, bevel=0.009)              # the grip
    for k in range(4):  # carved rings
        bone.box((0, -0.0165, 0.025 + k * 0.022), (0.022, 0.002, 0.004), shade(BONE, 0.72))
    g.box((0, -0.002, 0.004), (0.02, 0.026, 0.01), shade(BLACKENED, 1.2), bevel=0.004)  # pommel


wearable("FORESTER_PACK", 4, 3, [("ZR_EQ_PackCanvas", "4C4A36", "fabric")], view=BACK_VIEW)
wearable("MASK_WELDER", 2, 2, [("ZR_EQ_FacePlate", "2B2C28", "metal")], view="front_hi")

EXTRA = ["ANTIDOTE", "FLARE_RED", "FLARE_GREEN", "RITUAL_AMULET", "RITUAL_KNIFE", "FORESTER_PACK", "MASK_WELDER"]

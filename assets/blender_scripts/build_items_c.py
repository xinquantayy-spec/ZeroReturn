"""Zero Return - item models C: medicine, food and drink, keys and keycards, quest items, valuables and barter
goods. Original designs, modelled in metres (zr_items.U scales to studs); the front faces -Y, the top +Z.
"""
import math, random
from mathutils import Vector, Matrix
from zr_items import col, mixc, shade, rbox, label_band, cyl_x, cyl_y, cyl_z, lathe, R
from zr_item_reg import item

WHITE = col("E6E4DC")
RED = col("B8302A")
OLIVE = col("5A5C44")
STEELC = col("9A9F9C")
BLACK = col("1E1F20")
BRASSC = col("B8903E")
GOLDC = col("D4AA3A")


# ── medicine ───────────────────────────────────────────────────────────────────
@item("BANDAGE", 1, 1, view="three_q", margin=0.1)
def bandage(I):
    f, pa = I("foil"), I("paper")
    pack = col("6E6E52")
    f.box((0, 0, 0.012), (0.1, 0.07, 0.024), pack, bevel=0.008)
    f.box((0, 0.0, 0.012), (0.106, 0.074, 0.006), shade(pack, 0.85), bevel=0.002)  # crimped seam
    label_band(pa, (0, -0.01, 0.0245), (0.064, 0.036, 0), col("D8D2B8"), axis="z", sign=1)
    label_band(pa, (0, -0.02, 0.0247), (0.05, 0.006, 0), RED, axis="z", sign=1)
    # a loose roll beside the packet
    cyl_x(I("fabric"), -0.03, 0.02, 0.06, 0.016, 0.016, col("E2DECF"), seg=18)
    I("fabric").box((0.0, 0.06, 0.002), (0.05, 0.022, 0.002), col("E2DECF"))


@item("TOURNIQUET", 1, 1, view="top_tilt", margin=0.08)
def tourniquet(I):
    f, p = I("fabric"), I("polymer")
    strap = col("232425")
    f.torus((0, 0, 0.012), 0.032, 0.01, strap, segU=24, segV=6, rot=(0, 0, 0))
    f.box((0.0, -0.045, 0.012), (0.08, 0.022, 0.008), strap, rot=(0, 0, R(-20)), bevel=0.003)
    p.cyl((-0.04, 0.0, 0.03), (0.04, 0.0, 0.03), 0.006, BLACK, seg=10)  # windlass
    p.box((0, 0.0, 0.03), (0.02, 0.016, 0.014), col("2A2B2C"), bevel=0.003)
    label_band(I("paper"), (0.035, 0.0, 0.0365), (0.012, 0.012, 0), RED, axis="z", sign=1)  # red tip
    I("metal").box((0.03, 0.03, 0.02), (0.022, 0.014, 0.006), STEELC, bevel=0.002)  # buckle


@item("HEMOSTAT", 1, 1, view="three_q", margin=0.1)
def hemostat(I):
    f = I("foil")
    f.box((0, 0, 0.01), (0.08, 0.1, 0.02), col("9DA3A0"), bevel=0.008)
    f.box((0, 0, 0.01), (0.084, 0.104, 0.004), col("8A908D"), bevel=0.002)
    pa = I("paper")
    label_band(pa, (0, 0.0, 0.0205), (0.06, 0.07, 0), col("2E4A6E"), axis="z", sign=1)
    label_band(pa, (0, 0.012, 0.0207), (0.044, 0.014, 0), WHITE, axis="z", sign=1)
    label_band(pa, (0, -0.02, 0.0207), (0.03, 0.006, 0), col("C9A23C"), axis="z", sign=1)


@item("SPLINT", 1, 1, view="three_q", margin=0.08)
def splint(I):
    m = I("metal")
    al = col("A8AEAC")
    for k in range(4):  # folded ladder splint, zig-zag layers
        z = 0.004 + k * 0.007
        m.box((0.004 * (k % 2), 0, z), (0.12, 0.05, 0.004), shade(al, 1.0 - k * 0.04), bevel=0.0015)
    for j in range(6):  # rungs (raised)
        m.box((-0.05 + j * 0.02, 0.0, 0.03), (0.004, 0.046, 0.003), shade(al, 0.85))
    I("fabric").box((0.04, 0.0, 0.017), (0.012, 0.056, 0.036), col("2E3A2E"), bevel=0.003)  # velcro strap


@item("PAINKILLERS", 1, 1, view="three_q", margin=0.08)
def painkillers(I):
    pl = I("plastic")
    lathe(pl, [(0.0, 0.0), (0.019, 0.0), (0.02, 0.004), (0.02, 0.05), (0.018, 0.053)], WHITE, seg=20, x=-0.018)
    lathe(I("plastic"), [(0.0185, 0.053), (0.021, 0.053), (0.021, 0.068), (0.0, 0.068)], col("C83A2E"), seg=20, x=-0.018)
    lathe(I("paper"), [(0.0202, 0.012), (0.0202, 0.04)], col("D8D6CC"), seg=20, x=-0.018, cap_top=False, cap_bottom=False)
    # blister strip
    f = I("foil")
    f.box((0.03, -0.01, 0.002), (0.045, 0.07, 0.003), col("B8BEC0"), bevel=0.001)
    for r in range(4):
        for c in range(2):
            lathe(I("plastic"), [(0.0, 0.0035), (0.0055, 0.0035), (0.005, 0.0065), (0.0, 0.0072)], col("E8E6E0"), seg=10,
                  x=0.02 + c * 0.02, y=-0.035 + r * 0.017)


def soft_kit(I, w, d, h, color, cross_col=WHITE):
    f = I("fabric")
    f.box((0, 0, h / 2), (w, d, h), color, bevel=min(w, d, h) * 0.22)
    f.tube([(-w / 2 + 0.01, -d * 0.2, h), (w / 2 - 0.01, -d * 0.2, h)], 0.003, BLACK, seg=6)  # zip
    pa = I("paper")
    s = min(w, h) * 0.42
    label_band(pa, (0, -d / 2 - 0.001, h * 0.52), (s, 0, s * 0.3), cross_col)
    label_band(pa, (0, -d / 2 - 0.0012, h * 0.52), (s * 0.3, 0, s), cross_col)
    I("metal").box((w * 0.32, -d * 0.2, h + 0.004), (0.006, 0.018, 0.004), STEELC, bevel=0.001)


@item("MEDKIT_S", 1, 1, view="three_q", margin=0.1)
def medkit_s(I):
    soft_kit(I, 0.1, 0.045, 0.075, col("C8502E"))


@item("MEDKIT_M", 1, 2, view="front_hi", margin=0.08)
def medkit_m(I):
    p = I("plastic")
    p.box((0, 0, 0.11), (0.1, 0.05, 0.22), WHITE, bevel=0.008)
    p.box((0, 0, 0.11), (0.104, 0.054, 0.006), shade(WHITE, 0.85), bevel=0.002)
    pa = I("paper")
    label_band(pa, (0, -0.0262, 0.13), (0.05, 0, 0.016), col("2E8A4A"))
    label_band(pa, (0, -0.0264, 0.13), (0.016, 0, 0.05), col("2E8A4A"))
    label_band(pa, (0, -0.0262, 0.05), (0.07, 0, 0.012), col("2A2A2A"))
    I("metal").box((0, -0.028, 0.2), (0.03, 0.006, 0.012), STEELC, bevel=0.002)  # catch


@item("MEDKIT_L", 1, 2, view="front_hi", margin=0.08)
def medkit_l(I):
    soft_kit(I, 0.11, 0.07, 0.2, OLIVE, cross_col=col("C83A2E"))
    f = I("fabric")
    for k in range(3):
        f.box((0, 0.036, 0.04 + k * 0.05), (0.09, 0.004, 0.016), shade(OLIVE, 0.85), bevel=0.002)


@item("MEDKIT_XL", 2, 2, view="three_q", margin=0.08)
def medkit_xl(I):
    p, m = I("plastic"), I("metal")
    case = col("C8482A")
    p.box((0, 0, 0.09), (0.32, 0.12, 0.18), case, bevel=0.014)
    p.box((0, 0, 0.09), (0.326, 0.126, 0.01), shade(case, 0.75), bevel=0.003)
    pa = I("paper")
    label_band(pa, (0, -0.0606, 0.11), (0.09, 0, 0.026), WHITE)
    label_band(pa, (0, -0.0608, 0.11), (0.026, 0, 0.09), WHITE)
    for x in (-0.11, 0.11):
        m.box((x, -0.064, 0.13), (0.03, 0.01, 0.034), STEELC, bevel=0.003)
    p.tube([(-0.05, 0, 0.18), (-0.05, 0, 0.205), (0.05, 0, 0.205), (0.05, 0, 0.18)], 0.008, BLACK, seg=8)


@item("SURGKIT", 2, 1, view="three_q", margin=0.07)
def surgkit(I):
    f, m = I("fabric"), I("chrome")
    f.box((0, 0, 0.022), (0.24, 0.12, 0.044), col("3A4A3E"), bevel=0.016)
    f.box((0.0, -0.01, 0.046), (0.2, 0.08, 0.004), col("D8D6CC"), bevel=0.002)  # opened liner
    for k, (x, l) in enumerate(((-0.07, 0.07), (-0.035, 0.09), (0.0, 0.08), (0.04, 0.065))):
        m.box((x, -0.01, 0.051), (0.006, l, 0.004), col("C8CDCB"), bevel=0.001)
        m.torus((x, -0.01 + l / 2 + 0.008, 0.051), 0.006, 0.0015, col("C8CDCB"), segU=10, segV=4)
    label_band(I("paper"), (0.08, -0.0605, 0.022), (0.03, 0, 0.01), col("C83A2E"))


# ── food and drink ───────────────────────────────────────────────────────────────
@item("WATER", 1, 2, view="front", margin=0.1)
def water(I):
    lathe(I("glass"), [(0.0, 0.0), (0.03, 0.0), (0.032, 0.006), (0.032, 0.15), (0.026, 0.175), (0.012, 0.19), (0.012, 0.2)],
          col("BFD8E2"), seg=24)
    lathe(I("plastic"), [(0.0125, 0.198), (0.014, 0.198), (0.014, 0.214), (0.0, 0.214)], col("2E6AA8"), seg=20)
    lathe(I("paper"), [(0.0322, 0.06), (0.0322, 0.11)], col("2E7AB0"), seg=24, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0325, 0.085), (0.034, 0, 0.012), WHITE)


@item("STEW", 1, 1, view="three_q", margin=0.1)
def stew(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.034, 0.0), (0.036, 0.004), (0.036, 0.07), (0.034, 0.074), (0.0, 0.074)], col("A9AEAB"), seg=24)
    for z in (0.012, 0.062):
        lathe(m, [(0.0362, z), (0.0362, z + 0.003)], col("8E9390"), seg=24, cap_top=False, cap_bottom=False)
    lathe(I("paper"), [(0.0364, 0.016), (0.0364, 0.058)], col("8F6A4A"), seg=24, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0366, 0.037), (0.04, 0, 0.016), col("E2D8B8"))
    m.torus((0.012, 0.0, 0.0748), 0.009, 0.0016, col("C8CDCB"), segU=12, segV=4)  # pull ring


@item("HARDTACK", 1, 1, view="three_q", margin=0.08)
def hardtack(I):
    f = I("foil")
    f.box((0, 0.01, 0.014), (0.1, 0.07, 0.028), col("6E6A4E"), bevel=0.008)
    label_band(I("paper"), (0, 0.004, 0.0284), (0.06, 0.03, 0), col("C9B88A"), axis="z", sign=1)
    c = I("cardboard")
    for k in range(2):  # two crackers in front
        c.box((-0.02 + k * 0.04, -0.04, 0.003 + k * 0.002), (0.04, 0.04, 0.006), col("C8A86A"), rot=(0, 0, R(8 - k * 14)), bevel=0.002)
        for j in range(4):
            c.box((-0.02 + k * 0.04 + (j % 2 - 0.5) * 0.016, -0.04 + (j // 2 - 0.5) * 0.016, 0.0065 + k * 0.002), (0.003, 0.003, 0.001), col("8A6A3A"))


@item("VOLT_DRINK", 1, 2, view="front", margin=0.1)
def volt(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.024, 0.0), (0.0265, 0.006), (0.0265, 0.155), (0.022, 0.166), (0.021, 0.168), (0.0, 0.168)],
          col("6E8F3C"), seg=24)
    lathe(I("paper"), [(0.0267, 0.05), (0.0267, 0.075)], col("E8D23A"), seg=24, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0268, 0.11), (0.018, 0, 0.03), col("1E2A12"))
    m.box((0, 0.006, 0.1685), (0.012, 0.016, 0.002), col("B8BEC0"), bevel=0.001)  # tab


@item("JUICE", 1, 2, view="three_q", margin=0.08)
def juice(I):
    c = I("cardboard")
    c.box((0, 0, 0.07), (0.06, 0.06, 0.14), col("C8962E"), bevel=0.003)
    c.prism([(-0.03, 0.14), (0.03, 0.14), (0.0, 0.165)], -0.03, 0.03, col("C8962E"))  # gable top
    c.box((0, 0, 0.17), (0.06, 0.006, 0.012), col("B8862A"), bevel=0.001)
    label_band(I("paper"), (0, -0.0305, 0.07), (0.044, 0, 0.06), col("E8E2C8"))
    label_band(I("paper"), (0, -0.0307, 0.075), (0.026, 0, 0.026), col("D8582A"))
    lathe(I("plastic"), [(0.0, 0.0), (0.008, 0.0), (0.008, 0.012), (0.0, 0.012)], col("2E8A4A"), seg=14, x=0.012, y=-0.012, z=0.148)


@item("CHOC_BAR", 1, 1, view="three_q", margin=0.08)
def choc(I):
    f = I("foil")
    f.box((0.012, 0, 0.007), (0.1, 0.045, 0.014), col("6E3E2A"), bevel=0.004)
    label_band(I("paper"), (0.02, 0, 0.0142), (0.05, 0.025, 0), col("D8B04A"), axis="z", sign=1)
    I("foil").box((-0.05, 0, 0.007), (0.025, 0.046, 0.013), col("C0C4C2"), bevel=0.002)  # torn foil end
    c = I("plastic")
    for k in range(2):
        c.box((-0.068 - k * 0.0, -0.011 + k * 0.022, 0.007), (0.012, 0.02, 0.011), col("4A2A1C"), bevel=0.002)


# ── keys and keycards ──────────────────────────────────────────────────────────
def key(I, head_color, metal=BRASSC, tag=None, old=False, seed=0):
    """flat key lying on its side (top view): rubber or metal bow at -X, blade toward +X, cuts on one edge"""
    rng = random.Random(seed)
    m = I("brass" if metal == BRASSC else "metal")
    if old:
        m.torus((-0.03, 0, 0.003), 0.014, 0.003, metal, segU=16, segV=5)
        m.box((0.012, 0, 0.003), (0.07, 0.006, 0.006), metal, bevel=0.0015)
        m.box((0.042, -0.009, 0.003), (0.012, 0.014, 0.005), metal, bevel=0.001)
        m.box((0.032, -0.011, 0.003), (0.006, 0.01, 0.005), metal, bevel=0.001)
    else:
        bow = I("rubber") if head_color else m
        bow.box((-0.024, 0, 0.004), (0.03, 0.03, 0.008), head_color or metal, bevel=0.007)
        m.box((0.016, 0.0, 0.0025), (0.05, 0.013, 0.004), metal, bevel=0.001)
        for k in range(5):  # cuts
            d = rng.uniform(0.002, 0.005)
            m.box((0.0 + k * 0.009, -0.0065 + d / 2, 0.0025), (0.006, d, 0.0042), shade(metal, 0.7))
        m.box((0.016, 0.002, 0.0046), (0.046, 0.002, 0.0006), shade(metal, 0.75))  # groove
    m.torus((-0.044 if not old else -0.05, 0.0, 0.0025), 0.011, 0.0015, STEELC, segU=16, segV=4)  # key ring
    if tag:
        p = I("plastic")
        p.box((-0.06, 0.022, 0.003), (0.03, 0.022, 0.004), tag, rot=(0, 0, R(30)), bevel=0.003)
        label_band(I("paper"), (-0.06, 0.022, 0.0052), (0.018, 0.009, 0), WHITE, axis="z", sign=1)


def key_item(iid, head, metal=BRASSC, tag=None, old=False):
    @item(iid, 1, 1, view="top_tilt", margin=0.08)
    def fn(I):
        key(I, head, metal=metal, tag=tag, old=old, seed=len(iid) * 7 + ord(iid[-1]))
    return fn


key_item("KEY_OFFICE", None, BRASSC, tag=col("8C7A4E"))
key_item("KEY_PINE_BUNKER", None, col("6E6A5A"), old=True)
key_item("KEY_SMELT_OFFICE", col("7A6E58"), STEELC)
key_item("KEY_DORM_104", None, BRASSC, tag=col("7E8A6B"))
key_item("KEY_DORM_203", None, BRASSC, tag=col("6B7E8A"))
key_item("KEY_MALL_STAFF", col("6E7A8A"), STEELC)
key_item("KEY_MALL_SECURITY", col("3E4E6E"), STEELC, tag=col("C83A2E"))
key_item("KEY_VOLTA_STORE", col("C8B23A"), STEELC)
key_item("KEY_MEDIQ", col("4E8A6E"), STEELC)


def card(I, color, stripe=BLACK, chip=None, rust=False):
    p = I("plastic")
    p.box((0, 0, 0.0015), (0.086, 0.054, 0.003), color, bevel=0.003)
    label_band(I("paper"), (0, 0.012, 0.0031), (0.086, 0.01, 0), stripe, axis="z", sign=1)
    label_band(I("paper"), (-0.012, -0.012, 0.0031), (0.05, 0.004, 0), shade(color, 1.6), axis="z", sign=1)
    if chip:
        I("gold").box((0.025, -0.008, 0.0032), (0.012, 0.01, 0.0006), chip, bevel=0.0005)
    if rust:
        for k in range(6):
            label_band(I("paper"), (-0.03 + k * 0.012, -0.02 + (k % 3) * 0.012, 0.00315), (0.008, 0.006, 0), col("6E3A22"), axis="z", sign=1)
    p.box((-0.036, 0.0, 0.0015), (0.006, 0.006, 0.0032), shade(color, 0.6))  # lanyard hole


@item("RUSTED_KEYCARD", 1, 1, view="top_tilt", margin=0.08)
def rusted_card(I):
    card(I, col("8A6252"), stripe=col("2A2420"), rust=True)


@item("CARD_MALL_VAULT", 1, 1, view="top_tilt", margin=0.08)
def vault_card(I):
    card(I, col("8C3E5A"), stripe=col("D8C8A0"), chip=GOLDC)


# ── quest items ───────────────────────────────────────────────────────────────
@item("SEALED_DRIVE", 1, 1, view="three_q", margin=0.08)
def sealed_drive(I):
    f = I("foil")
    f.box((0, 0, 0.008), (0.1, 0.075, 0.016), col("8A9094"), bevel=0.006)
    f.box((0.0, 0.034, 0.008), (0.104, 0.012, 0.006), col("6E7478"), bevel=0.002)  # sealed lip
    label_band(I("paper"), (0, -0.006, 0.0162), (0.06, 0.035, 0), col("E2D8C0"), axis="z", sign=1)
    label_band(I("paper"), (0.012, -0.006, 0.0164), (0.024, 0.024, 0), col("B83A2A"), axis="z", sign=1)  # stamp


@item("LEDGER", 1, 1, view="three_q", margin=0.08)
def ledger(I):
    l, pa = I("leather"), I("paper")
    l.box((0, 0, 0.003), (0.1, 0.13, 0.006), col("6A3E26"), bevel=0.003)
    pa.box((0.002, 0, 0.012), (0.094, 0.124, 0.012), col("D8CCA8"), bevel=0.001)
    l.box((0, 0, 0.021), (0.1, 0.13, 0.006), col("7A4A2E"), bevel=0.003)
    l.box((-0.048, 0, 0.012), (0.008, 0.13, 0.024), col("5A3420"), bevel=0.003)  # spine
    l.box((0.02, 0, 0.0245), (0.016, 0.134, 0.002), col("3A2216"))  # strap
    I("brass").box((0.02, -0.06, 0.025), (0.02, 0.012, 0.003), BRASSC, bevel=0.001)


# ── barter goods and valuables ─────────────────────────────────────────────────
def bolt(m, x, y, z, length, r, color, yaw=0.0):
    # lying bolt: hex head + shank along a direction in the XY plane
    dx, dy = math.cos(yaw), math.sin(yaw)
    m.cyl((x, y, z), (x + dx * 0.008, y + dy * 0.008, z), r * 1.9, color, seg=6)
    m.cyl((x + dx * 0.008, y + dy * 0.008, z), (x + dx * length, y + dy * length, z), r, shade(color, 0.92), seg=10)


@item("BOLTS", 1, 1, view="top_tilt", margin=0.06)
def bolts(I):
    m = I("metal")
    rng = random.Random(3)
    for k in range(7):
        x, y = rng.uniform(-0.03, 0.02), rng.uniform(-0.03, 0.03)
        bolt(m, x, y, 0.005, rng.uniform(0.03, 0.05), 0.0035, col("8C8F8A"), yaw=rng.uniform(0, 6.28))
    for k in range(4):
        x, y = rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)
        m.cyl((x, y, 0.0), (x, y, 0.004), 0.0065, col("7B7C78"), seg=6)


@item("DUCT_TAPE", 1, 1, view="three_q", margin=0.08)
def duct_tape(I):
    p = I("plastic")
    lathe(p, [(0.03, 0.0), (0.05, 0.0), (0.05, 0.05), (0.03, 0.05)], col("8E9091"), seg=28)
    lathe(I("cardboard"), [(0.028, 0.0), (0.0305, 0.0), (0.0305, 0.05), (0.028, 0.05)], col("A88A5A"), seg=24)
    p.box((0.0, -0.06, 0.025), (0.02, 0.02, 0.05), col("8E9091"), rot=(0, 0, R(10)))  # loose end


@item("WIRES", 1, 1, view="top_tilt", margin=0.06)
def wires(I):
    pl, cu = I("plastic"), I("copper")
    for k, c in enumerate((col("B83A2A"), col("2E5AA8"), col("2A2A2A"), col("C8B23A"))):
        r = 0.03 - k * 0.004
        pl.torus((0.004 * k, 0, 0.004 + k * 0.004), r, 0.0028, c, segU=22, segV=5)
        cu.cyl((r + 0.004 * k, 0, 0.004 + k * 0.004), (r + 0.004 * k + 0.02, -0.012, 0.006 + k * 0.004), 0.0014, col("C87A3A"), seg=6)


@item("CIGARETTES", 1, 1, view="three_q", margin=0.08)
def cigarettes(I):
    c = I("cardboard")
    c.box((0, 0, 0.045), (0.055, 0.022, 0.09), WHITE, rot=(0, R(4), 0), bevel=0.003)
    label_band(I("paper"), (0, -0.0112, 0.06), (0.05, 0, 0.03), col("B8302A"))
    label_band(I("paper"), (0, -0.0114, 0.025), (0.03, 0, 0.008), col("2A2A2A"))
    for k in range(2):  # two cigarettes sticking out
        cyl_z(I("paper"), -0.012 + k * 0.012, 0.0, 0.09, 0.105 - k * 0.006, 0.0038, col("E8E4DA"), seg=10)
        cyl_z(I("paper"), -0.012 + k * 0.012, 0.0, 0.06, 0.09, 0.0038, col("C8964A"), seg=10)


@item("MATCHES", 1, 1, view="three_q", margin=0.08)
def matches(I):
    c = I("cardboard")
    c.box((0, 0, 0.008), (0.055, 0.036, 0.016), col("9E5E3A"), bevel=0.0015)
    c.box((0.0, -0.016, 0.006), (0.05, 0.034, 0.012), col("D8CCA8"), bevel=0.001)  # drawer pulled out
    label_band(I("paper"), (0, 0.0, 0.0162), (0.04, 0.02, 0), col("D8B04A"), axis="z", sign=1)
    for k in range(4):
        cyl_y(I("wood"), -0.015 + k * 0.009, -0.03, -0.005, 0.012, 0.0016, col("D8C08A"), seg=6)
        lathe(I("plastic"), [(0.0, 0.0), (0.0026, 0.0), (0.0026, 0.004), (0.0, 0.006)], col("8E2A1E"), seg=8, x=-0.015 + k * 0.009,
              y=-0.032, z=0.012, axis="y")


@item("SPARK_PLUG", 1, 1, view="three_q_low", margin=0.08)
def spark_plug(I):
    cer, m = I("ceramic"), I("metal")
    lathe(m, [(0.0, 0.0), (0.006, 0.0), (0.006, 0.022)], col("8C8F8A"), seg=14, cap_top=False)  # thread
    m.cyl((0, 0, 0.022), (0, 0, 0.034), 0.012, col("9A9F9C"), seg=6)  # hex
    lathe(cer, [(0.009, 0.034), (0.008, 0.06), (0.0065, 0.07), (0.005, 0.085), (0.0, 0.086)], col("ECEAE2"), seg=16)
    m.cyl((0, 0, 0.085), (0, 0, 0.095), 0.003, col("8C8F8A"), seg=8)
    m.box((0.0, 0.0, -0.003), (0.004, 0.003, 0.006), col("6E716E"))


@item("SIGNAL_COIL", 1, 1, view="three_q", margin=0.08)
def signal_coil(I):
    cu, p = I("copper"), I("plastic")
    p.cyl((0, 0, 0.0), (0, 0, 0.004), 0.034, col("2A2A2A"), seg=20)
    p.cyl((0, 0, 0.05), (0, 0, 0.054), 0.034, col("2A2A2A"), seg=20)
    p.cyl((0, 0, 0.004), (0, 0, 0.05), 0.012, col("3A3A3A"), seg=16)
    for k in range(9):
        cu.torus((0, 0, 0.007 + k * 0.005), 0.024, 0.0026, col("C87A3A"), segU=24, segV=5)
    cu.cyl((0.028, 0, 0.05), (0.046, 0.0, 0.07), 0.0014, col("C87A3A"), seg=6)


@item("CERAMIC_FUSE", 1, 1, view="three_q_low", margin=0.1)
def ceramic_fuse(I):
    cer, m = I("ceramic"), I("metal")
    cyl_x(cer, -0.03, 0.03, 0, 0.012, 0.012, col("B9B3A2"), seg=18)
    for x in (-0.03, 0.03):
        cyl_x(m, x - 0.01 * (1 if x < 0 else -1), x + 0.004 * (-1 if x < 0 else 1), 0, 0.012, 0.0135, col("A8AEAC"), seg=18)
    label_band(I("paper"), (0, -0.0124, 0.012), (0.024, 0, 0.01), col("2A2A2A"))


@item("CAPACITOR", 1, 1, view="three_q", margin=0.08)
def capacitor(I):
    p, m = I("plastic"), I("metal")
    lathe(p, [(0.0, 0.0), (0.028, 0.0), (0.03, 0.004), (0.03, 0.09), (0.0, 0.09)], col("5F7A86"), seg=22)
    lathe(m, [(0.0, 0.09), (0.03, 0.09), (0.028, 0.095), (0.0, 0.095)], col("A8AEAC"), seg=22)
    for x in (-0.012, 0.012):
        m.cyl((x, 0, 0.095), (x, 0, 0.108), 0.005, col("B8BEC0"), seg=8)
    label_band(I("paper"), (0, -0.0302, 0.05), (0.03, 0, 0.026), col("D8D6CC"))


@item("CRACKED_LENS", 1, 1, view="three_q", margin=0.08)
def cracked_lens(I):
    m, g = I("gunmetal"), I("glass")
    lathe(m, [(0.034, 0.0), (0.04, 0.0), (0.04, 0.018), (0.034, 0.018)], col("2E3233"), seg=28)
    lathe(g, [(0.0, 0.004), (0.034, 0.004), (0.034, 0.016), (0.02, 0.0205), (0.0, 0.022)], col("8EB8C0"), seg=28)  # convex lens
    I("emissive").cyl((0, 0, 0.0221), (0, 0, 0.0223), 0.012, col("3A6A8A"), seg=20)  # coating sheen
    for k in range(4):  # cracks
        a = 0.6 + k * 1.6
        I("paper").box((math.cos(a) * 0.012, math.sin(a) * 0.012, 0.0215), (0.026, 0.0009, 0.0006), col("E8F2F2"), rot=(0, 0, a + 0.3))


@item("BATTERY", 2, 1, view="three_q", margin=0.08)
def battery(I):
    p, m = I("plastic"), I("metal")
    p.box((0, 0, 0.065), (0.24, 0.14, 0.13), col("2E3033"), bevel=0.008)
    p.box((0, 0, 0.133), (0.24, 0.14, 0.008), col("3A3D40"), bevel=0.003)
    for x, c in ((-0.08, col("B8302A")), (0.08, col("2A2A2A"))):
        m.cyl((x, 0.04, 0.137), (x, 0.04, 0.155), 0.01, col("A8AEAC"), seg=12)
        p.box((x, 0.015, 0.138), (0.03, 0.02, 0.004), c)
    label_band(I("paper"), (0, -0.0705, 0.07), (0.16, 0, 0.06), col("C8B23A"))
    label_band(I("paper"), (0, -0.0707, 0.07), (0.12, 0, 0.014), col("1E1F20"))
    p.tube([(-0.05, 0, 0.137), (-0.05, 0, 0.16), (0.05, 0, 0.16), (0.05, 0, 0.137)], 0.006, col("1E1F20"), seg=8)


def pcb(I, w, d, color=col("2E6A3A"), chips=6, seed=1, gold=True):
    p = I("plastic")
    p.box((0, 0, 0.0008), (w, d, 0.0016), color, bevel=0.0003)
    rng = random.Random(seed)
    for k in range(chips):
        cw, cd = rng.uniform(0.008, 0.02), rng.uniform(0.008, 0.016)
        x, y = rng.uniform(-w / 2 + cw, w / 2 - cw), rng.uniform(-d / 2 + cd, d / 2 - cd)
        p.box((x, y, 0.003), (cw, cd, 0.003), col("1C1D1E"), bevel=0.0004)
    for k in range(10):
        x, y = rng.uniform(-w / 2 + 0.004, w / 2 - 0.004), rng.uniform(-d / 2 + 0.004, d / 2 - 0.004)
        I("ceramic").box((x, y, 0.0022), (0.003, 0.0016, 0.0012), col("B8A88A"))
    if gold:
        for k in range(int(w / 0.004)):
            I("gold").box((-w / 2 + 0.003 + k * 0.004, -d / 2 + 0.003, 0.0017), (0.0022, 0.005, 0.0003), GOLDC)


@item("LOGIC_BOARD", 1, 1, view="top_tilt", margin=0.06)
def logic_board(I):
    pcb(I, 0.09, 0.07, seed=4)
    I("plastic").box((0.03, 0.02, 0.006), (0.024, 0.012, 0.01), col("D8D6CC"), bevel=0.001)  # connector


@item("FUEL_CAN", 2, 2, view="three_q", margin=0.07)
def fuel_can(I):
    m = I("metal")
    c = col("8A3A2A")
    m.box((0, 0, 0.16), (0.3, 0.12, 0.32), c, bevel=0.016)
    for k in range(2):  # pressed X panels
        m.box((0, -0.061, 0.16), (0.24, 0.004, 0.02), shade(c, 0.85), rot=(0, R(38) * (1 if k else -1), 0))
    m.box((0, 0, 0.34), (0.2, 0.04, 0.03), c, bevel=0.008)  # handle bar
    for x in (-0.07, 0.0, 0.07):
        m.box((x, 0, 0.325), (0.02, 0.04, 0.03), c, bevel=0.004)
    m.cyl((0.12, 0, 0.32), (0.13, 0, 0.36), 0.018, col("4A4D4A"), seg=12)  # spout cap
    label_band(I("paper"), (-0.08, -0.0605, 0.24), (0.06, 0, 0.03), col("D8D2B8"))


@item("MED_TOOLS", 1, 2, view="top_tilt", margin=0.06)
def med_tools(I):
    f, m = I("fabric"), I("chrome")
    roll = col("2E4A3E")
    f.box((0, 0, 0.003), (0.1, 0.22, 0.006), roll, bevel=0.002)  # unrolled
    f.cyl((-0.05, 0.11, 0.012), (0.05, 0.11, 0.012), 0.012, shade(roll, 0.85), seg=14)  # rolled end
    for k in range(5):  # pockets
        f.box((-0.04 + k * 0.02, -0.05, 0.007), (0.017, 0.09, 0.004), shade(roll, 1.15), bevel=0.0015)
    tools = ((-0.04, 0.15, "scalpel"), (-0.02, 0.17, "forceps"), (0.0, 0.16, "probe"), (0.02, 0.15, "scissors"), (0.04, 0.13, "clamp"))
    for x, l, kind in tools:
        m.box((x, -0.005, 0.0105), (0.0045, l, 0.003), col("C8CDCB"), bevel=0.0008)
        if kind == "scissors":
            m.torus((x - 0.004, -0.005 - l / 2 + 0.006, 0.0105), 0.005, 0.0012, col("C8CDCB"), segU=10, segV=4)
            m.torus((x + 0.004, -0.005 - l / 2 + 0.006, 0.0105), 0.005, 0.0012, col("C8CDCB"), segU=10, segV=4)
        elif kind == "scalpel":
            m.box((x, -0.005 + l / 2 + 0.01, 0.0105), (0.006, 0.02, 0.0012), col("E2E6E6"), bevel=0.0005)
    f.box((0.0, -0.105, 0.007), (0.1, 0.01, 0.008), shade(roll, 0.8), bevel=0.002)  # tie


@item("OLD_COIN", 1, 1, view="top_tilt", margin=0.16)
def old_coin(I):
    m = I("chrome")
    lathe(m, [(0.0, 0.0), (0.02, 0.0), (0.021, 0.001), (0.021, 0.0035), (0.019, 0.004), (0.0, 0.004)], col("B8B8A8"), seg=32)
    lathe(m, [(0.0, 0.0041), (0.012, 0.0041), (0.0122, 0.0046), (0.0, 0.0048)], col("9A9A8A"), seg=24)  # relief
    m.torus((0, 0, 0.0042), 0.017, 0.0007, col("A8A898"), segU=32, segV=4)


@item("DECK_TRANSCEIVER", 2, 2, view="three_q", margin=0.07)
def transceiver(I):
    p, m = I("plastic"), I("metal")
    body = col("4B5652")
    p.box((0, 0, 0.07), (0.24, 0.16, 0.14), body, bevel=0.008)
    p.box((0, -0.081, 0.07), (0.22, 0.004, 0.12), shade(body, 0.9), bevel=0.002)  # front panel
    I("emissive").box((-0.05, -0.0835, 0.1), (0.08, 0.002, 0.026), col("8ACB6A"))  # display
    for k in range(3):
        p.cyl((0.04 + k * 0.03, -0.083, 0.1), (0.04 + k * 0.03, -0.095, 0.1), 0.009, col("1E1F20"), seg=14)
    for k in range(6):
        p.box((-0.08 + k * 0.022, -0.0835, 0.045), (0.014, 0.004, 0.01), col("2A2B2C"), bevel=0.002)
    m.cyl((0.1, 0.06, 0.14), (0.1, 0.06, 0.26), 0.004, col("2A2B2C"), seg=8)  # antenna
    p.box((-0.07, 0.03, 0.15), (0.06, 0.03, 0.02), col("2A2B2C"), bevel=0.005)  # handset on top
    p.tube([(-0.04, 0.03, 0.15), (-0.01, 0.0, 0.16), (0.03, 0.02, 0.145)], 0.003, col("1E1F20"), seg=6)


@item("GOLD_CHAIN", 1, 1, view="top_tilt", margin=0.06)
def gold_chain(I):
    g = I("gold")
    n = 26
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 0.03 + 0.006 * math.sin(a * 3)
        x, y = math.cos(a) * r, math.sin(a) * r
        g.torus((x, y, 0.003), 0.0042, 0.0012, GOLDC, segU=10, segV=4, rot=(R(90 if k % 2 else 0), 0, a))


@item("CAPT_WATCH", 1, 1, view="top_tilt", margin=0.06)
def capt_watch(I):
    m, l, gl = I("chrome"), I("leather"), I("glass")
    l.box((0, 0.045, 0.004), (0.02, 0.05, 0.004), col("3A2A1E"), bevel=0.0015)
    l.box((0, -0.045, 0.004), (0.02, 0.05, 0.004), col("3A2A1E"), bevel=0.0015)
    lathe(m, [(0.0, 0.0), (0.019, 0.0), (0.02, 0.004), (0.02, 0.01), (0.0, 0.01)], col("B39A5A"), seg=28)
    lathe(I("gunmetal"), [(0.0155, 0.0101), (0.02, 0.0101), (0.0195, 0.0125), (0.0155, 0.0125)], col("1E2A3A"), seg=28)  # bezel
    lathe(I("plastic"), [(0.0, 0.0101), (0.0155, 0.0101), (0.0, 0.0103)], col("1A1C20"), seg=24)  # dial
    for k in range(12):
        a = 2 * math.pi * k / 12
        I("emissive").box((math.cos(a) * 0.012, math.sin(a) * 0.012, 0.0106), (0.002, 0.0012, 0.0004), col("E8E2C8"), rot=(0, 0, a))
    m.box((0.003, 0.004, 0.0108), (0.0012, 0.01, 0.0005), col("E8E2C8"), rot=(0, 0, R(-30)))
    m.box((-0.002, 0.003, 0.0109), (0.0012, 0.007, 0.0005), col("E8E2C8"), rot=(0, 0, R(60)))
    gl.cyl((0, 0, 0.0104), (0, 0, 0.0122), 0.0152, col("D8E8E8"), seg=24)
    m.cyl((0.0205, 0, 0.006), (0.025, 0, 0.006), 0.0025, col("B39A5A"), seg=10)  # crown


@item("FLASH_MODULE", 1, 1, view="three_q", margin=0.1)
def flash_module(I):
    p, m = I("plastic"), I("metal")
    p.box((0.008, 0, 0.007), (0.05, 0.022, 0.014), col("2E3440"), bevel=0.004)
    m.box((-0.026, 0, 0.007), (0.018, 0.016, 0.008), col("B8BEC0"), bevel=0.001)
    label_band(I("paper"), (0.008, 0, 0.0142), (0.03, 0.014, 0), col("4F6E8C"), axis="z", sign=1)
    I("emissive").box((0.028, 0.0, 0.0142), (0.003, 0.003, 0.0008), col("3AD84A"))


@item("INTEL_FOLDER", 1, 1, view="top_tilt", margin=0.06)
def intel_folder(I):
    c, pa = I("cardboard"), I("paper")
    c.box((0, 0, 0.002), (0.1, 0.13, 0.004), col("9C7A4A"), bevel=0.001)
    pa.box((0.004, 0.003, 0.006), (0.094, 0.122, 0.004), col("E2DCC8"), rot=(0, 0, R(3)))
    c.box((-0.002, -0.002, 0.009), (0.1, 0.13, 0.002), col("A9864E"), bevel=0.0008)
    label_band(pa, (0.01, 0.03, 0.0101), (0.05, 0.02, 0), col("E2DCC8"), axis="z", sign=1)
    label_band(pa, (-0.02, -0.03, 0.0102), (0.03, 0.03, 0), col("B83A2A"), axis="z", sign=1)  # stamp
    c.box((-0.03, 0.068, 0.006), (0.03, 0.01, 0.01), col("A9864E"))  # tab


@item("MIL_CIRCUIT", 2, 1, view="top_tilt", margin=0.06)
def mil_circuit(I):
    m = I("metal")
    m.box((0, 0, 0.003), (0.16, 0.08, 0.006), col("5A5E5C"), bevel=0.002)
    pcb(I, 0.14, 0.064, color=col("2F5A3A"), chips=9, seed=11)
    for x in (-0.075, 0.075):
        for y in (-0.035, 0.035):
            m.cyl((x, y, 0.006), (x, y, 0.009), 0.003, col("A8AEAC"), seg=8)
    I("plastic").box((0.0, 0.0, 0.007), (0.03, 0.02, 0.008), col("C8B23A"), bevel=0.001)


@item("COLD_WALLET", 1, 1, view="three_q", margin=0.1)
def cold_wallet(I):
    p = I("plastic")
    p.box((0, 0, 0.006), (0.06, 0.03, 0.012), col("C07946"), bevel=0.005)
    I("emissive").box((-0.006, 0.0, 0.0122), (0.03, 0.016, 0.0006), col("8AC8E8"))
    for x in (0.016, 0.024):
        p.cyl((x, 0, 0.012), (x, 0, 0.0135), 0.003, col("2A2A2A"), seg=10)
    I("metal").box((-0.032, 0, 0.006), (0.006, 0.012, 0.004), col("B8BEC0"))


@item("BRASS_LION", 2, 2, view="three_q", margin=0.07)
def brass_lion(I):
    b, w = I("brass"), I("wood")
    lion = col("B08A3C")
    w.box((0, 0, 0.012), (0.2, 0.09, 0.024), col("4A2E1E"), bevel=0.004)  # plinth
    b.cyl((-0.03, 0, 0.065), (0.05, 0, 0.065), 0.03, lion, r2=0.026, seg=16, smooth=True)  # body
    lathe(b, [(0.0, -0.022), (0.03, -0.015), (0.034, 0.0), (0.03, 0.018), (0.0, 0.026)], lion, seg=16, x=-0.058, z=0.09, axis="x")  # mane
    b.cyl((-0.075, 0, 0.092), (-0.095, 0, 0.088), 0.016, lion, r2=0.012, seg=12, smooth=True)  # muzzle
    for x in (-0.03, 0.045):
        for y in (-0.018, 0.018):
            b.cyl((x, y, 0.024), (x, y, 0.06), 0.008, lion, seg=10, smooth=True)  # legs
            b.box((x - 0.004, y, 0.028), (0.02, 0.012, 0.008), lion, bevel=0.003)  # paws
    b.tube([(0.075, 0, 0.07), (0.095, 0, 0.06), (0.1, 0, 0.035), (0.11, 0, 0.03)], 0.004, lion, seg=6)  # tail
    lathe(b, [(0.0, 0.0), (0.006, 0.004), (0.0, 0.01)], lion, seg=10, x=0.112, z=0.026)  # tail tuft


@item("GPU_CARD", 2, 1, view="three_q", margin=0.06)
def gpu(I):
    p, m = I("plastic"), I("metal")
    shroud = col("2A2E34")
    p.box((0, 0, 0.02), (0.28, 0.11, 0.04), shroud, bevel=0.006)  # shroud, fans on top
    m.box((0, 0.0, -0.002), (0.27, 0.1, 0.004), col("3A4A5A"), bevel=0.002)  # backplate underneath
    for x in (-0.07, 0.07):
        lathe(I("plastic"), [(0.0, 0.0), (0.042, 0.0), (0.042, 0.0012), (0.0, 0.0012)], col("16181B"), seg=28, x=x, z=0.0401)
        lathe(I("plastic"), [(0.0, 0.0), (0.012, 0.0), (0.012, 0.004), (0.0, 0.004)], col("3A4A5A"), seg=16, x=x, z=0.0405)  # hub
        for k in range(9):
            a = k * 2 * math.pi / 9
            p.box((x + math.cos(a) * 0.026, math.sin(a) * 0.026, 0.0418), (0.028, 0.008, 0.0014), col("2E3238"), rot=(R(12), 0, a + 1.1))
    I("gold").box((0.02, -0.057, 0.004), (0.12, 0.006, 0.006), GOLDC)  # PCIe fingers
    m.box((-0.142, 0.0, 0.03), (0.004, 0.11, 0.06), col("A8AEAC"), bevel=0.001)  # bracket
    label_band(I("emissive"), (0.0, -0.0555, 0.03), (0.2, 0, 0.003), col("4A9AD8"))  # light strip on the edge


@item("HDD", 1, 1, view="three_q", margin=0.08)
def hdd(I):
    m = I("metal")
    m.box((0, 0, 0.0125), (0.1, 0.146, 0.025), col("8C9294"), bevel=0.002)
    label_band(I("paper"), (0, 0.01, 0.0252), (0.08, 0.09, 0), col("E2E2DC"), axis="z", sign=1)
    label_band(I("paper"), (0, 0.04, 0.0254), (0.06, 0.012, 0), col("2A4A8A"), axis="z", sign=1)
    I("plastic").box((0.0, -0.075, 0.008), (0.06, 0.006, 0.01), BLACK)  # connectors


@item("RAM_STICK", 1, 1, view="top_tilt", margin=0.06)
def ram(I):
    pcb(I, 0.13, 0.032, color=col("2E6A3A"), chips=0, seed=2)
    for k in range(8):
        I("plastic").box((-0.055 + k * 0.0155, 0.003, 0.003), (0.011, 0.016, 0.0024), BLACK, bevel=0.0004)
    I("plastic").box((0.0, 0.0, 0.0012), (0.014, 0.034, 0.0008), col("1C1D1E"))  # key notch shadow


@item("PHONE", 1, 1, view="top_tilt", margin=0.06)
def phone(I):
    p, gl = I("plastic"), I("glass")
    p.box((0, 0, 0.004), (0.07, 0.14, 0.008), col("2E3238"), bevel=0.006)
    I("plastic").box((0, 0, 0.0082), (0.064, 0.13, 0.0006), col("101418"), bevel=0.002)  # screen
    for k in range(4):  # cracks
        a = 0.4 + k * 1.3
        I("plastic").box((0.01 + math.cos(a) * 0.012, 0.03 + math.sin(a) * 0.012, 0.0088), (0.032, 0.0007, 0.0003), col("8A9AA8"),
                         rot=(0, 0, a))
    p.cyl((0, 0.06, 0.0084), (0, 0.06, 0.0088), 0.0025, BLACK, seg=10)


@item("POWER_BANK", 1, 1, view="three_q", margin=0.08)
def power_bank(I):
    p = I("plastic")
    p.box((0, 0, 0.011), (0.06, 0.1, 0.022), col("4A5E7A"), bevel=0.008)
    for k in range(2):
        I("metal").box((-0.012 + k * 0.024, -0.0502, 0.011), (0.012, 0.002, 0.005), col("B8BEC0"))
    for k in range(4):
        I("emissive").box((-0.009 + k * 0.006, -0.03, 0.0222), (0.003, 0.003, 0.0006), col("6AE88A") if k < 2 else col("2A3A2E"))


@item("LIGHTBULB", 1, 1, view="three_q", margin=0.06)
def lightbulb(I):
    gl, m = I("glass"), I("metal")
    lathe(gl, [(0.0, 0.03), (0.012, 0.032), (0.014, 0.045), (0.027, 0.07), (0.03, 0.09), (0.024, 0.11), (0.012, 0.12), (0.0, 0.122)],
          col("E8E2C8"), seg=24)
    lathe(m, [(0.0, 0.0), (0.006, 0.0), (0.012, 0.006), (0.0125, 0.03), (0.0, 0.03)], col("B8BEC0"), seg=20)
    for k in range(4):
        lathe(m, [(0.0127, 0.009 + k * 0.006), (0.0127, 0.011 + k * 0.006)], col("9A9F9C"), seg=20, cap_top=False, cap_bottom=False)
    I("metal").tube([(0, 0, 0.04), (0.004, 0, 0.07), (-0.004, 0, 0.08), (0.004, 0, 0.09)], 0.0007, col("6E6A5A"), seg=4)


@item("TOOTHPASTE", 1, 1, view="three_q", margin=0.06)
def toothpaste(I):
    p = I("plastic")
    p.cyl((-0.05, 0, 0.012), (0.03, 0, 0.012), 0.012, col("5A8EB8"), r2=0.013, seg=16, smooth=True)
    p.box((-0.055, 0, 0.012), (0.012, 0.03, 0.004), col("4A7EA8"), bevel=0.001)  # crimped end
    lathe(p, [(0.0, 0.0), (0.009, 0.0), (0.009, 0.014), (0.0, 0.014)], WHITE, seg=14, x=0.044, z=0.012, axis="x")
    label_band(I("paper"), (-0.01, -0.0125, 0.014), (0.04, 0, 0.008), WHITE)


@item("SOAP", 1, 1, view="three_q", margin=0.08)
def soap(I):
    pa = I("paper")
    pa.box((0, 0, 0.012), (0.085, 0.055, 0.024), col("C8B8D8"), bevel=0.007)
    label_band(pa, (0, -0.0277, 0.012), (0.05, 0, 0.012), WHITE)
    label_band(pa, (0, 0.0, 0.0242), (0.04, 0.024, 0), col("8E6AA8"), axis="z", sign=1)


@item("BLEACH", 1, 2, view="three_q", margin=0.08)
def bleach(I):
    p = I("plastic")
    p.box((0, 0, 0.09), (0.09, 0.06, 0.18), col("D8DCE0"), bevel=0.016)
    p.box((0.0, 0.0, 0.2), (0.04, 0.04, 0.04), col("D8DCE0"), bevel=0.01)
    p.tube([(0.03, 0, 0.17), (0.045, 0, 0.21), (0.03, 0.0, 0.222)], 0.008, col("D8DCE0"), seg=8)  # handle
    lathe(I("plastic"), [(0.0, 0.0), (0.017, 0.0), (0.017, 0.02), (0.0, 0.02)], col("2E6AA8"), seg=18, z=0.22)
    label_band(I("paper"), (0, -0.0302, 0.09), (0.07, 0, 0.08), col("2E6AA8"))
    label_band(I("paper"), (0, -0.0304, 0.1), (0.05, 0, 0.016), WHITE)


@item("DOGTAG", 1, 1, view="top_tilt", margin=0.06)
def dogtag(I):
    m = I("metal")
    for k, (x, y, a) in enumerate(((-0.012, 0.0, 0.2), (0.012, -0.008, -0.3))):
        m.box((x, y, 0.001 + k * 0.0012), (0.03, 0.05, 0.0012), col("A7A9A0"), rot=(0, 0, a), bevel=0.0028)
        for j in range(4):
            m.box((x + math.cos(a + 1.57) * (0.008 - j * 0.005), y + math.sin(a + 1.57) * (0.008 - j * 0.005), 0.0019 + k * 0.0012),
                  (0.016, 0.0012, 0.0003), col("6E706A"), rot=(0, 0, a))
    n = 24
    for k in range(n):  # ball chain
        a = 2 * math.pi * k / n
        lathe(m, [(0.0, -0.0015), (0.0015, 0.0), (0.0, 0.0015)], col("B8BAB2"), seg=6, x=math.cos(a) * 0.03, y=0.035 + math.sin(a) * 0.018,
              z=0.0015)


# ── M14: the multitool (lets you change vital weapon parts in raid, as in Tarkov) ──
@item("MULTITOOL", 2, 1, view="three_q", margin=0.08)
def multitool(I):
    m, r = I("metal"), I("rubber")
    STEELC = col("A4A9A6")
    for sx in (-1, 1):                                                  # two folded handles
        m.box((sx * 0.0072, 0.0, 0.006), (0.0062, 0.1, 0.012), STEELC, bevel=0.0018)
        r.box((sx * 0.0105, 0.008, 0.006), (0.0012, 0.066, 0.0085), col("B04A2A"), bevel=0.0005)   # grip inserts
        for k in range(3):
            m.cyl((sx * 0.0105, 0.042 - k * 0.04, 0.006), (sx * 0.0112, 0.042 - k * 0.04, 0.006), 0.0018, shade(STEELC, 0.6), seg=8)
    # plier jaws out of the front, a blade and a screwdriver tucked in the handles
    m.box((0.0, -0.064, 0.006), (0.009, 0.03, 0.007), shade(STEELC, 0.9), bevel=0.0015)
    m.box((0.0, -0.082, 0.006), (0.006, 0.012, 0.005), shade(STEELC, 0.85), bevel=0.0012)
    for k in range(5):
        m.box((0.0047, -0.058 - k * 0.0045, 0.006), (0.0006, 0.002, 0.0055), shade(STEELC, 0.5))
    m.box((0.0, 0.054, 0.0125), (0.004, 0.02, 0.0012), shade(STEELC, 1.12), bevel=0.0004)
    m.cyl((0.0, 0.05, 0.006), (0.0, 0.05, 0.0135), 0.003, shade(STEELC, 0.7), seg=10)
    label_band(I("paper"), (0.0, 0.01, 0.0125), (0.006, 0.03, 0.0), col("2A2C2C"), axis="z", sign=1)


# ── Border Yard keys (2026-11-01): dorm rooms brass with a coloured tag, works and strongrooms steel with a rubber
# head, fuel stop and watchhouse brass with a rubber head, sheds and trailers old pressed keys. Colours as in Items.luau.
_BY_KEYS = [
    ("KEY_BY_314", "dorm", "8C7A4E"), ("KEY_BY_RECORDS", "works", "7A6E50"), ("KEY_BY_BOILER", "works", "6F5F45"),
    ("KEY_BY_K11", "works", "5B6066"), ("KEY_BY_STORE", "works", "7A6A4A"), ("KEY_BY_RED", "works", "8C3A30"),
    ("KEY_BY_BASTION", "works", "4E5248"), ("KEY_BY_MOTOR", "works", "6A5A40"), ("KEY_BY_A103", "dorm", "7E8A6B"),
    ("KEY_BY_A125", "dorm", "7A8466"), ("KEY_BY_A128", "dorm", "6E7C8A"), ("KEY_BY_A201", "dorm", "8A7E5E"),
    ("KEY_BY_A212", "dorm", "7B8A6E"), ("KEY_BY_A225", "dorm", "8A6E5E"), ("KEY_BY_A228", "dorm", "6E8A7E"),
    ("KEY_BY_A229", "dorm", "7E6E8A"), ("KEY_BY_A303", "dorm", "8A8A5E"), ("KEY_BY_A310", "dorm", "5E7E8A"),
    ("KEY_BY_A317", "dorm", "8A5E6E"), ("KEY_BY_A325", "dorm", "6E8A5E"), ("KEY_BY_B103", "dorm", "7A8A72"),
    ("KEY_BY_B111", "dorm", "8A7A6A"), ("KEY_BY_B116", "dorm", "6A7A8A"), ("KEY_BY_B124", "dorm", "8A6A7A"),
    ("KEY_BY_B223", "dorm", "7A6A8A"), ("KEY_BY_FUELSTORE", "shop", "8A7A3E"), ("KEY_BY_FUELTILL", "shop", "7A6A3E"),
    ("KEY_BY_WATCHROOM", "shop", "5E4E6A"), ("KEY_BY_WATCHSTORE", "shop", "6A5E4E"), ("KEY_BY_ARMYHUT", "works", "5E6648"),
    ("KEY_BY_HUTSKIOSK", "old", "7A7E5E"), ("KEY_BY_TRAILERA", "old", "7E6A4E"), ("KEY_BY_TRAILERB", "old", "6E7E4E"),
    ("KEY_BY_SHACK4", "old", "6A6E5A"), ("KEY_BY_ROADSHACK", "old", "706A56"), ("KEY_BY_SQUAT", "old", "7A4E42"),
    ("KEY_BY_PUMPS", "old", "7E6E44"),
]
for _iid, _style, _hex in _BY_KEYS:
    if _style == "dorm":
        key_item(_iid, None, BRASSC, tag=col(_hex))
    elif _style == "works":
        key_item(_iid, col(_hex), STEELC)
    elif _style == "shop":
        key_item(_iid, col(_hex), BRASSC)
    else:
        key_item(_iid, None, mixc(col(_hex), col("8A8478"), 0.55), old=True)


@item("PROPANE_TANK", 1, 2, view="front", margin=0.1)
def propane_tank(I):
    """household propane cylinder: rounded steel body, foot ring, collar with hand holes round the valve"""
    m = I("metal")
    body = col("C45C22")
    lathe(m, [(0.0, 0.0), (0.1, 0.0), (0.104, 0.012), (0.104, 0.03)], shade(body, 0.8), seg=28)  # foot ring
    lathe(m, [(0.0, 0.03), (0.13, 0.04), (0.15, 0.07), (0.15, 0.36), (0.13, 0.4), (0.07, 0.425), (0.0, 0.43)], body, seg=32)
    lathe(m, [(0.088, 0.425), (0.092, 0.425), (0.092, 0.5), (0.088, 0.5)], shade(body, 0.9), seg=28, cap_top=False, cap_bottom=False)  # collar
    for a in (0.0, math.pi):
        m.box((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.478), (0.012, 0.04, 0.022), col("1E1E1C"))  # hand holes
    b = I("brass")
    b.cyl((0.0, 0.0, 0.43), (0.0, 0.0, 0.47), 0.016, col("B89A4A"), seg=12)  # valve
    b.cyl((0.0, 0.0, 0.47), (0.0, 0.0, 0.485), 0.026, col("2A2C2C"), seg=14)  # hand wheel
    b.cyl((0.0, -0.015, 0.455), (0.0, -0.04, 0.455), 0.007, col("B89A4A"), seg=8)  # outlet
    label_band(I("paper"), (0.0, -0.1505, 0.22), (0.07, 0, 0.05), col("E8E2D0"))
    m.box((0.0, -0.151, 0.13), (0.16, 0.003, 0.004), shade(body, 0.7))  # weld seam

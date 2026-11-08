"""Zero Return - item models J: the barter goods of economy-1a's second slice (2026-11-08), the tools, building
materials, electronics and supplies EFT's hideout is built from. Original designs after what each thing is, no maker's
marks. Modelled in metres (front toward -Y, top +Z); sizes are the inventory cells (EFT's grid sizes).
"""
import math
from zr_items import col, shade, label_band, cyl_x, cyl_y, cyl_z, lathe, R
from zr_item_reg import item

STEEL, DARK, BLACK, WHITE = col("9A9C96"), col("3A3C3E"), col("1E2022"), col("E4E4DE")
BRASS_C, GOLD_C, CARD = col("B08A3C"), col("C9A13C"), col("A8885A")


def torus(b, c, rr, r, color, axis="z", seg=24, rseg=8):
    """a ring of tube radius r around a circle of radius rr (hoses, cords, rings)"""
    prof = [(rr + r * math.cos(2 * math.pi * k / rseg), r * math.sin(2 * math.pi * k / rseg)) for k in range(rseg + 1)]
    lathe(b, prof, color, seg=seg, x=c[0], y=c[1], z=c[2], cap_top=False, cap_bottom=False, axis=axis)


def screw(b, x, y, z, ln, r, color, rot_z=0.0):
    """a screw lying along X (rotated about Z): a head, a shank and a point"""
    ca, sa = math.cos(rot_z), math.sin(rot_z)
    p = lambda d: (x + ca * d, y + sa * d, z)
    b.cyl(p(0), p(r * 0.8), r * 2.0, color, seg=12)
    b.cyl(p(r * 0.8), p(ln * 0.85), r, color, seg=10)
    b.cyl(p(ln * 0.85), p(ln), r, color, r2=0.0002, seg=10)


def hexnut(b, x, y, z, r, h, color):
    b.cyl((x, y, z), (x, y, z + h), r, color, seg=6)
    b.cyl((x, y, z + h), (x, y, z + h + 0.0004), r * 0.5, shade(color, 0.35), seg=12)


# ── building materials ───────────────────────────────────────────────────────────────────────────────────────────
@item("SCREWS", 1, 1, view="three_q", margin=0.1)
def screws(I):
    """a paper pack of screws, a few lying on top"""
    c = I("cardboard")
    c.box((0, 0, 0.016), (0.07, 0.048, 0.032), col("C8B88A"), bevel=0.002)
    label_band(I("paper"), (0, -0.0241, 0.017), (0.05, 0, 0.016), col("3A5A8A"))
    m = I("metal")
    for k, (x, y, a) in enumerate(((-0.022, -0.006, 0.3), (-0.012, 0.01, -0.2), (0.0, -0.012, 0.9))):
        screw(m, x, y, 0.0345, 0.04, 0.0018, col("B8B8AE"), rot_z=a)


@item("NUTS", 1, 1, view="three_q", margin=0.1)
def nuts(I):
    m = I("metal")
    for x, y, z in ((-0.012, -0.008, 0), (0.012, -0.006, 0), (0.0, 0.012, 0), (-0.002, 0.0, 0.008), (0.022, 0.014, 0)):
        hexnut(m, x, y, z, 0.0105, 0.008, col("A8AAA2"))


@item("NAILS", 1, 1, view="three_q", margin=0.1)
def nails(I):
    c = I("cardboard")
    c.box((0, 0.006, 0.012), (0.06, 0.04, 0.024), col("2E5A8A"), bevel=0.002)
    label_band(I("paper"), (0, -0.0141, 0.012), (0.04, 0, 0.012), col("E0D8B8"))
    m = I("metal")
    for k in range(4):
        x0 = -0.03 + k * 0.004
        y0 = -0.024 - k * 0.004
        m.cyl((x0, y0, 0.002), (x0 + 0.05, y0 + 0.006, 0.002), 0.0012, col("8E9088"), seg=8)
        m.cyl((x0 - 0.0006, y0, 0.002), (x0, y0, 0.002), 0.003, col("8E9088"), seg=10)


@item("SILICONE_TUBE", 1, 1, view="three_q", margin=0.08)
def silicone_tube(I):
    p = I("plastic")
    cyl_x(p, -0.1, 0.07, 0, 0.025, 0.024, col("E4E4DA"), seg=24)
    cyl_x(p, 0.07, 0.078, 0, 0.025, 0.018, col("D0D0C6"), seg=20)
    p.cyl((0.078, 0, 0.025), (0.13, 0, 0.025), 0.008, col("E8E8E0"), r2=0.002, seg=16)
    cyl_x(I("plastic"), -0.1, -0.097, 0, 0.025, 0.0245, col("B8B8AE"), seg=24)
    lb = I("paper")
    lathe(lb, [(0.0244, -0.06), (0.0244, 0.03)], col("3A6A9A"), seg=24, x=0, y=0, z=0.025, axis="x", cap_top=False, cap_bottom=False)


@item("CORR_HOSE", 2, 1, view="three_q", margin=0.06)
def corr_hose(I):
    """a coil of ribbed hose with a clamp on each end"""
    r = I("rubber")
    torus(r, (0, 0, 0.02), 0.07, 0.014, col("34424C"), axis="z", seg=40, rseg=10)
    torus(r, (0.012, 0.006, 0.046), 0.064, 0.014, col("3E4E58"), axis="z", seg=40, rseg=10)
    m = I("metal")
    cyl_x(m, 0.06, 0.1, -0.05, 0.02, 0.016, STEEL, seg=16)
    cyl_x(m, 0.072, 0.082, -0.05, 0.02, 0.018, col("C8C8C0"), seg=16)


@item("PRESSURE_GAUGE", 2, 1, view="front", margin=0.08)
def pressure_gauge(I):
    b = I("brass")
    cyl_y(b, 0.0, -0.04, 0.0, 0.0, 0.05, BRASS_C, seg=32)
    torus(b, (0.0, -0.042, 0.0), 0.046, 0.005, BRASS_C, axis="y", seg=32, rseg=8)
    face = I("paper")
    cyl_y(face, 0.0, -0.0425, -0.0405, 0.0, 0.043, col("F4F2EA"), seg=32)
    for k in range(9):
        a = R(225 - k * 33.75)
        face.box((0.034 * math.cos(a), -0.0428, 0.034 * math.sin(a)), (0.003, 0.0006, 0.009), BLACK, rot=(0, -a + R(90), 0))
    I("metal").box((0.009, -0.0433, 0.006), (0.036, 0.0008, 0.004), col("C8302A"), rot=(0, R(-30), 0))
    cyl_y(I("metal"), 0.0, -0.0436, -0.043, 0.0, 0.004, BLACK, seg=12)
    cyl_x(b, 0.05, 0.13, -0.022, 0.0, 0.009, BRASS_C, seg=16)
    I("brass").cyl((0.11, -0.022, 0), (0.12, -0.022, 0), 0.013, shade(BRASS_C, 0.85), seg=6)


@item("SEAL_TAPE", 1, 1, view="three_q", margin=0.08)
def seal_tape(I):
    p = I("plastic")
    lathe(p, [(0.022, 0.0), (0.05, 0.0), (0.05, 0.05), (0.022, 0.05), (0.022, 0.0)], col("C8A43A"), seg=32)
    lathe(I("cardboard"), [(0.019, 0.0), (0.022, 0.0), (0.022, 0.05), (0.019, 0.05), (0.019, 0.0)], CARD, seg=24)
    p.box((0.03, -0.046, 0.025), (0.03, 0.002, 0.05), shade(col("C8A43A"), 0.9), rot=(0, 0, R(-20)))


@item("FOAM", 1, 3, view="front", margin=0.08)
def foam(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.032, 0.0), (0.033, 0.006), (0.033, 0.2), (0.026, 0.215), (0.012, 0.222)], col("5E7A3E"), seg=28)
    label_band(I("paper"), (0, -0.0335, 0.11), (0.05, 0, 0.1), col("D8C83A"))
    label_band(I("paper"), (0, -0.0338, 0.085), (0.05, 0, 0.012), col("2E3226"))
    p = I("plastic")
    p.box((0, 0, 0.232), (0.022, 0.03, 0.02), col("2E3034"), bevel=0.003)
    p.cyl((0, -0.012, 0.236), (0, -0.09, 0.25), 0.003, col("E4E4DA"), seg=10)


@item("SPARE_PARTS", 1, 1, view="three_q", margin=0.1)
def spare_parts(I):
    m = I("metal")
    m.box((-0.012, -0.008, 0.002), (0.04, 0.012, 0.004), STEEL, rot=(0, 0, R(20)))
    m.box((-0.03, -0.012, 0.012), (0.004, 0.012, 0.024), STEEL, rot=(0, 0, R(20)))
    for k in range(7):
        torus(m, (0.018, 0.012, 0.004 + k * 0.004), 0.008, 0.0012, col("8E9088"), axis="z", seg=14, rseg=6)
    m.cyl((-0.02, 0.018, 0.003), (0.01, 0.026, 0.003), 0.0025, col("C8C8C0"), seg=10)
    hexnut(m, 0.02, -0.018, 0.0, 0.007, 0.005, col("A8AAA2"))


# ── electronics ──────────────────────────────────────────────────────────────────────────────────────────────────
@item("RELAY", 1, 1, view="three_q", margin=0.1)
def relay(I):
    p = I("plastic")
    p.box((0, 0, 0.03), (0.036, 0.06, 0.06), col("D8D6CC"), bevel=0.002)
    p.box((0, -0.0305, 0.034), (0.026, 0.002, 0.03), col("3F4A5A"))
    label_band(I("paper"), (0, -0.0318, 0.042), (0.02, 0, 0.006), WHITE)
    I("emissive").box((0.008, -0.0318, 0.026), (0.004, 0.001, 0.004), col("3ADA4A"))
    m = I("metal")
    for x in (-0.01, 0.01):
        for z in (0.058, 0.004):
            cyl_z(m, x, -0.02, z, z + 0.004, 0.003, STEEL, seg=10)


@item("MOTOR", 2, 2, view="three_q", margin=0.08)
def motor(I):
    m = I("metal")
    col_m = col("4E5A4A")
    cyl_x(m, -0.07, 0.07, 0, 0.06, 0.05, col_m, seg=28)
    for k in range(9):
        x = -0.06 + k * 0.015
        cyl_x(m, x, x + 0.004, 0, 0.06, 0.054, shade(col_m, 0.85), seg=28)
    cyl_x(m, 0.07, 0.08, 0, 0.06, 0.045, shade(col_m, 0.8), seg=28)
    cyl_x(m, -0.08, -0.07, 0, 0.06, 0.045, shade(col_m, 0.8), seg=28)
    cyl_x(I("metal"), 0.08, 0.115, 0, 0.06, 0.008, STEEL, seg=14)
    m.box((0, 0, 0.006), (0.12, 0.09, 0.012), shade(col_m, 0.75), bevel=0.002)
    m.box((0.0, 0.0, 0.112), (0.04, 0.036, 0.016), shade(col_m, 0.9), bevel=0.002)
    label_band(I("paper"), (-0.03, -0.0505, 0.06), (0.03, 0, 0.016), col("C8C8B8"))


@item("PSU", 2, 2, view="three_q", margin=0.08)
def psu(I):
    m = I("metal")
    m.box((0, 0, 0.043), (0.15, 0.14, 0.086), col("4A4E52"), bevel=0.002)
    cyl_z(m, 0.02, 0.0, 0.086, 0.0875, 0.05, col("2A2C2E"), seg=28)
    for k in range(6):
        a = R(k * 30)
        m.box((0.02, 0.0, 0.0882), (0.1, 0.002, 0.001), col("5A5E62"), rot=(0, 0, a))
    cyl_z(I("plastic"), 0.02, 0.0, 0.086, 0.0885, 0.012, BLACK, seg=16)
    r = I("rubber")
    for k, cc in enumerate((col("D83A2A"), col("E8D84A"), BLACK, BLACK)):
        r.cyl((-0.075, -0.03 + k * 0.006, 0.03), (-0.12, -0.04 + k * 0.012, 0.004), 0.0025, cc, seg=8)
    label_band(I("paper"), (-0.03, -0.0705, 0.045), (0.06, 0, 0.04), col("D8D8D0"))


@item("CPU_FAN", 1, 1, view="three_q", margin=0.08)
def cpu_fan(I):
    m = I("metal")
    m.box((0, 0, 0.004), (0.08, 0.08, 0.008), col("B8BAB6"))
    for k in range(11):
        m.box((-0.04 + k * 0.008, 0, 0.022), (0.0015, 0.08, 0.028), col("C8CAC6"))
    p = I("plastic")
    for dx, dy in ((0.0375, 0), (-0.0375, 0), (0, 0.0375), (0, -0.0375)):
        p.box((dx, dy, 0.047), (0.08 if dy else 0.005, 0.005 if dy else 0.08, 0.014), col("2E3034"))
    cyl_z(p, 0, 0, 0.042, 0.054, 0.012, col("2E3034"), seg=20)
    label_band(I("paper"), (0, 0, 0.0545), (0.014, 0.014, 0), col("C83A2A"), axis="z", sign=1)
    for k in range(7):
        a = R(k * 51.4)
        p.box((0.022 * math.cos(a), 0.022 * math.sin(a), 0.048), (0.024, 0.008, 0.002), col("3A3C40"), rot=(R(25), 0, a + R(90)))


@item("POWER_CORD", 2, 1, view="three_q", margin=0.06)
def power_cord(I):
    r = I("rubber")
    for k in range(4):
        torus(r, (0.0 + k * 0.006, 0.0, 0.006 + k * 0.007), 0.05, 0.0045, col("2E3034"), axis="z", seg=28, rseg=6)
    p = I("plastic")
    p.box((0.085, -0.02, 0.008), (0.03, 0.022, 0.016), col("2A2C2E"), bevel=0.002)
    r.cyl((0.05, -0.012, 0.006), (0.07, -0.018, 0.008), 0.0045, col("2E3034"), seg=8)
    m = I("metal")
    for dy in (-0.006, 0.006):
        cyl_x(m, 0.1, 0.118, -0.02 + dy, 0.008, 0.002, STEEL, seg=8)


@item("TPLUG", 1, 1, view="three_q", margin=0.1)
def tplug(I):
    p = I("plastic")
    p.box((0, 0, 0.022), (0.06, 0.036, 0.044), WHITE, bevel=0.004)
    p.box((0.0, 0, 0.052), (0.036, 0.036, 0.02), WHITE, bevel=0.004)
    for dy in (-0.007, 0.007):
        cyl_x(p, 0.0295, 0.031, dy, 0.024, 0.0025, BLACK, seg=10)
        cyl_x(p, -0.031, -0.0295, dy, 0.024, 0.0025, BLACK, seg=10)
        cyl_z(p, dy, 0.0, 0.0615, 0.063, 0.0025, BLACK, seg=10)
    m = I("metal")
    for dy in (-0.007, 0.007):
        m.cyl((0.0, dy, 0.0), (0.0, dy, -0.016), 0.002, STEEL, seg=8)


@item("POWER_FILTER", 1, 1, view="three_q", margin=0.08)
def power_filter(I):
    m = I("metal")
    oc = col("4E5A3E")
    m.box((0, 0, 0.025), (0.08, 0.05, 0.05), oc, bevel=0.003)
    for x in (-0.042, 0.042):
        m.box((x, 0, 0.003), (0.012, 0.06, 0.006), shade(oc, 0.8))
    for x in (-0.02, 0.02):
        cyl_y(m, x, -0.032, -0.025, 0.026, 0.009, shade(oc, 0.7), seg=16)
        cyl_y(I("metal"), x, -0.034, -0.032, 0.026, 0.0065, STEEL, seg=16)
    label_band(I("paper"), (0, 0, 0.0506), (0.05, 0.026, 0), col("C8C4A8"), axis="z", sign=1)


@item("MIL_CABLE", 2, 1, view="three_q", margin=0.06)
def mil_cable(I):
    r = I("rubber")
    for k in range(3):
        torus(r, (0.0, 0.0, 0.008 + k * 0.009), 0.055, 0.006, col("3E4632"), axis="z", seg=28, rseg=6)
    m = I("metal")
    for x, y in ((0.07, -0.03), (-0.075, 0.025)):
        cyl_x(m, x - 0.012, x + 0.012, y, 0.01, 0.012, col("5E6650"), seg=16)
        cyl_x(m, x + 0.012, x + 0.016, y, 0.01, 0.009, STEEL, seg=16)
        r.cyl((x - 0.012 if x > 0 else x + 0.012, y, 0.01), (x * 0.75, y * 0.4, 0.012), 0.006, col("3E4632"), seg=8)


@item("ES_LAMP", 1, 1, view="front", margin=0.08)
def es_lamp(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.008, 0.002), (0.013, 0.006), (0.013, 0.03)], STEEL, seg=20)
    for k in range(4):
        torus(m, (0, 0, 0.01 + k * 0.006), 0.0135, 0.0012, shade(STEEL, 0.85), axis="z", seg=20, rseg=5)
    p = I("plastic")
    lathe(p, [(0.013, 0.03), (0.022, 0.034), (0.022, 0.05), (0.018, 0.054)], WHITE, seg=24)
    g = I("ceramic")
    for k in range(6):
        z = 0.06 + k * 0.012
        torus(g, (0, 0, z), 0.014, 0.0055, col("F0F0EA"), axis="z", seg=20, rseg=6)
    lathe(g, [(0.0, 0.135), (0.012, 0.13)], col("F0F0EA"), seg=16)


@item("POWER_DRILL", 2, 2, view="three_q_low", margin=0.06)
def power_drill(I):
    p = I("plastic")
    oc = col("C86A2A")
    p.box((0, 0, 0.13), (0.15, 0.05, 0.06), oc, bevel=0.012)
    p.box((-0.02, 0, 0.075), (0.042, 0.04, 0.09), col("2E3034"), rot=(0, R(12), 0), bevel=0.008)
    p.box((-0.03, 0, 0.018), (0.09, 0.07, 0.036), col("2A2C2E"), bevel=0.006)
    cyl_x(I("metal"), 0.075, 0.11, 0, 0.13, 0.016, col("3A3C3E"), seg=16)
    I("metal").cyl((0.11, 0, 0.13), (0.17, 0, 0.13), 0.003, STEEL, seg=8)
    p.box((0.01, -0.02, 0.098), (0.012, 0.012, 0.016), BLACK)
    label_band(I("paper"), (-0.03, -0.0255, 0.135), (0.05, 0, 0.012), BLACK)


# ── info ─────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("SSD", 1, 1, view="three_q", margin=0.1)
def ssd(I):
    m = I("metal")
    m.box((0, 0, 0.0035), (0.07, 0.1, 0.007), col("2E3640"), bevel=0.0015)
    label_band(I("paper"), (0, 0.006, 0.0071), (0.054, 0.06, 0), col("C8CCD0"), axis="z", sign=1)
    label_band(I("paper"), (0, -0.01, 0.0073), (0.04, 0.008, 0), col("3A6A9A"), axis="z", sign=1)
    I("plastic").box((0.012, -0.0505, 0.0035), (0.03, 0.002, 0.004), BLACK)


@item("SURVEY_MAPS", 2, 1, view="three_q", margin=0.06)
def survey_maps(I):
    p = I("paper")
    cyl_x(p, -0.12, 0.12, 0.0, 0.03, 0.03, col("D8CCA6"), seg=28)
    cyl_x(p, -0.1205, -0.12, 0.0, 0.03, 0.022, col("C8BC96"), seg=24)
    cyl_x(p, 0.12, 0.1205, 0.0, 0.03, 0.022, col("C8BC96"), seg=24)
    r = I("rubber")
    for x in (-0.06, 0.06):
        cyl_x(r, x - 0.003, x + 0.003, 0.0, 0.03, 0.0305, col("8A3A2A"), seg=28)
    p.box((0.04, -0.035, 0.0015), (0.16, 0.06, 0.003), col("E0D6B4"), rot=(0, 0, R(-6)))
    for k in range(5):
        label_band(p, (0.0 + k * 0.022, -0.035, 0.0031), (0.0008, 0.05, 0), col("6A8A5A"), axis="z", sign=1)


@item("SECURE_FLASH", 1, 1, view="three_q", margin=0.12)
def secure_flash(I):
    m = I("metal")
    m.box((0, 0, 0.005), (0.05, 0.018, 0.009), col("5A6E7A"), bevel=0.002)
    m.box((0.031, 0, 0.005), (0.014, 0.012, 0.0045), STEEL)
    I("plastic").box((0.033, 0, 0.0055), (0.01, 0.009, 0.0015), BLACK)
    torus(m, (-0.03, 0, 0.005), 0.006, 0.0012, STEEL, axis="z", seg=16, rseg=6)
    label_band(I("paper"), (-0.005, 0, 0.0096), (0.022, 0.01, 0), col("C83A2A"), axis="z", sign=1)


# ── energy ───────────────────────────────────────────────────────────────────────────────────────────────────────
@item("LI_BATTERY", 1, 1, view="three_q", margin=0.1)
def li_battery(I):
    p = I("plastic")
    gc = col("3E7A4A")
    p.box((0, 0, 0.03), (0.07, 0.04, 0.06), gc, bevel=0.003)
    label_band(I("paper"), (0, -0.0205, 0.032), (0.05, 0, 0.03), col("D8D8C8"))
    label_band(I("paper"), (0, -0.0208, 0.04), (0.05, 0, 0.006), BLACK)
    m = I("metal")
    for x in (-0.018, 0.018):
        cyl_z(m, x, 0, 0.06, 0.066, 0.005, STEEL, seg=12)
    I("plastic").box((0.018, 0, 0.0606), (0.008, 0.008, 0.001), col("C83A2A"))


# ── flammable materials ──────────────────────────────────────────────────────────────────────────────────────────
@item("PEN_OIL", 1, 1, view="front", margin=0.1)
def pen_oil(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.02, 0.0), (0.021, 0.004), (0.021, 0.08), (0.016, 0.09), (0.009, 0.094)], col("3A5A9A"), seg=24)
    label_band(I("paper"), (0, -0.0212, 0.045), (0.03, 0, 0.035), col("E8C83A"))
    I("plastic").box((0, 0, 0.1), (0.014, 0.018, 0.012), col("2E3034"), bevel=0.002)
    I("plastic").cyl((0.0, -0.009, 0.102), (0.0, -0.06, 0.104), 0.0018, col("C83A2A"), seg=8)


@item("TNT", 1, 1, view="three_q", margin=0.08)
def tnt(I):
    p = I("paper")
    p.box((0, 0, 0.025), (0.1, 0.05, 0.05), col("8E8A6A"), bevel=0.003)
    for x in (-0.03, 0.03):
        label_band(p, (x, -0.0256, 0.025), (0.006, 0, 0.05), col("2E3226"))
    label_band(p, (0, -0.0258, 0.03), (0.04, 0, 0.012), col("2E3226"))
    cyl_z(I("metal"), 0.0, 0.0, 0.05, 0.0505, 0.008, col("3A3C3E"), seg=16)


@item("THERMITE", 1, 1, view="three_q", margin=0.1)
def thermite(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.03, 0.0), (0.031, 0.004), (0.031, 0.07), (0.03, 0.074), (0.0, 0.074)], col("8E918A"), seg=28)
    lathe(I("paper"), [(0.0312, 0.015), (0.0312, 0.06)], col("C86A2A"), seg=28, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0314, 0.04), (0.03, 0, 0.012), BLACK)
    torus(m, (0, 0, 0.074), 0.026, 0.002, shade(col("8E918A"), 0.8), axis="z", seg=24, rseg=6)


@item("LIGHTER", 1, 1, view="three_q", margin=0.14)
def lighter(I):
    p = I("plastic")
    p.box((0, 0, 0.032), (0.024, 0.012, 0.064), col("C83A2A"), bevel=0.004)
    m = I("metal")
    m.box((0, 0, 0.072), (0.024, 0.012, 0.014), STEEL, bevel=0.001)
    cyl_y(m, -0.006, -0.006, 0.006, 0.081, 0.004, col("6A6C68"), seg=12)
    p.box((0.006, 0, 0.08), (0.008, 0.008, 0.004), BLACK)


@item("GUN_LUBE", 1, 1, view="front", margin=0.1)
def gun_lube(I):
    p = I("plastic")
    lathe(p, [(0.0, 0.0), (0.02, 0.0), (0.021, 0.004), (0.021, 0.07), (0.012, 0.08), (0.006, 0.084)], col("2E5A7A"), seg=24)
    lathe(I("plastic"), [(0.006, 0.084), (0.007, 0.096), (0.0012, 0.12), (0.0, 0.122)], col("E4E4DA"), seg=16)
    label_band(I("paper"), (0, -0.0212, 0.04), (0.03, 0, 0.034), col("E8E8E0"))
    label_band(I("paper"), (0, -0.0215, 0.05), (0.03, 0, 0.006), col("C83A2A"))


# ── household materials ──────────────────────────────────────────────────────────────────────────────────────────
@item("TOILET_PAPER", 1, 1, view="three_q", margin=0.1)
def toilet_paper(I):
    p = I("paper")
    lathe(p, [(0.02, 0.0), (0.055, 0.0), (0.055, 0.1), (0.02, 0.1), (0.02, 0.0)], col("EEEEE8"), seg=32)
    lathe(I("cardboard"), [(0.018, 0.0), (0.02, 0.0), (0.02, 0.1), (0.018, 0.1), (0.018, 0.0)], CARD, seg=20)
    p.box((0.03, -0.054, 0.04), (0.04, 0.002, 0.08), col("E4E4DE"), rot=(R(8), 0, R(-15)))


@item("SALT", 1, 1, view="three_q", margin=0.1)
def salt(I):
    m = I("metal")
    lathe(m, [(0.0, 0.0), (0.035, 0.0), (0.036, 0.004), (0.036, 0.09), (0.035, 0.094), (0.0, 0.094)], STEEL, seg=28)
    lathe(I("paper"), [(0.0362, 0.01), (0.0362, 0.084)], col("E8ECEE"), seg=28, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0364, 0.05), (0.04, 0, 0.016), col("2E5A9A"))
    cyl_z(I("plastic"), 0.012, 0.0, 0.094, 0.0965, 0.01, col("2E5A9A"), seg=16)


@item("CHLORINE", 2, 1, view="three_q", margin=0.06)
def chlorine(I):
    p = I("foil")
    p.box((0, 0, 0.015), (0.16, 0.08, 0.03), col("E0E4D8"), bevel=0.01)
    for x in (-0.08, 0.08):
        p.box((x, 0, 0.015), (0.008, 0.08, 0.004), col("D0D4C8"))
    label_band(I("paper"), (0, -0.0, 0.0302), (0.08, 0.05, 0), col("2E6AA8"), axis="z", sign=1)
    label_band(I("paper"), (0, 0.012, 0.0304), (0.06, 0.008, 0), WHITE, axis="z", sign=1)


@item("ALKALI", 1, 2, view="front", margin=0.08)
def alkali(I):
    p = I("plastic")
    bc = col("4A7AA8")
    p.box((0, 0, 0.09), (0.08, 0.05, 0.18), bc, bevel=0.012)
    p.box((0, 0, 0.19), (0.05, 0.04, 0.03), bc, bevel=0.01)
    cyl_z(I("plastic"), 0.0, 0.0, 0.205, 0.225, 0.016, col("E8D84A"), seg=20)
    p.box((0.044, 0, 0.15), (0.012, 0.02, 0.07), shade(bc, 0.9), bevel=0.004)
    label_band(I("paper"), (0, -0.0255, 0.09), (0.06, 0, 0.08), WHITE)
    label_band(I("paper"), (0, -0.0258, 0.11), (0.06, 0, 0.012), col("C83A2A"))


# ── medical supplies ─────────────────────────────────────────────────────────────────────────────────────────────
@item("SYRINGE", 1, 1, view="top_tilt", margin=0.08)
def syringe(I):
    g = I("plastic")
    a = R(35)
    d = (math.cos(a), math.sin(a), 0)
    p = lambda t: (d[0] * t, d[1] * t, 0.006)
    g.cyl(p(-0.04), p(0.03), 0.006, col("E8EEF0"), seg=16)
    g.cyl(p(-0.06), p(-0.04), 0.0035, WHITE, seg=10)
    g.cyl(p(-0.062), p(-0.06), 0.008, WHITE, seg=14)
    g.cyl(p(-0.042), p(-0.04), 0.009, WHITE, seg=14)
    g.cyl(p(0.03), p(0.036), 0.003, col("2E8AC8"), seg=10)
    I("metal").cyl(p(0.036), p(0.065), 0.0006, STEEL, seg=6)
    for k in range(6):
        t = -0.03 + k * 0.01
        label_band(I("paper"), (d[0] * t, d[1] * t, 0.0121), (0.002, 0.002, 0), BLACK, axis="z", sign=1)


@item("MEDS_PILE", 1, 1, view="three_q", margin=0.08)
def meds_pile(I):
    for k, (x, y, rz, cc) in enumerate(((-0.006, -0.004, 10, col("D8D8D0")), (0.008, 0.01, -25, col("C8B8E0")), (0.0, -0.016, 60, col("E8D8B8")))):
        z = 0.002 + k * 0.004
        f = I("foil")
        f.box((x, y, z), (0.07, 0.035, 0.002), cc, rot=(0, 0, R(rz)))
        ca, sa = math.cos(R(rz)), math.sin(R(rz))
        for i in range(4):
            for j in range(2):
                lx, ly = -0.024 + i * 0.016, -0.008 + j * 0.016
                I("plastic").cyl((x + lx * ca - ly * sa, y + lx * sa + ly * ca, z + 0.001), (x + lx * ca - ly * sa, y + lx * sa + ly * ca, z + 0.0035),
                                 0.0045, col("F4F4F0"), seg=10)


@item("SALINE", 1, 1, view="front", margin=0.1)
def saline(I):
    p = I("plastic")
    lathe(p, [(0.0, 0.0), (0.028, 0.0), (0.03, 0.006), (0.03, 0.09), (0.02, 0.104), (0.011, 0.11)], col("E0ECF2"), seg=24)
    cyl_z(I("plastic"), 0, 0, 0.11, 0.124, 0.012, col("2E6AA8"), seg=18)
    label_band(I("paper"), (0, -0.0302, 0.05), (0.04, 0, 0.05), WHITE)
    label_band(I("paper"), (0, -0.0305, 0.064), (0.04, 0, 0.008), col("2E6AA8"))


@item("BLOODSET", 1, 1, view="three_q", margin=0.08)
def bloodset(I):
    p = I("plastic")
    p.box((0, 0.01, 0.006), (0.06, 0.08, 0.012), col("D8C8C8"), bevel=0.005)
    label_band(I("paper"), (0, 0.012, 0.0122), (0.04, 0.03, 0), col("B83A3A"), axis="z", sign=1)
    r = I("plastic")
    pts = [(0.0, -0.03, 0.006), (0.02, -0.045, 0.006), (0.0, -0.055, 0.006), (-0.025, -0.045, 0.006), (-0.03, -0.02, 0.006)]
    for a, b in zip(pts, pts[1:]):
        r.cyl(a, b, 0.0022, col("C8D8E0"), seg=8)
    I("plastic").cyl((-0.03, -0.02, 0.006), (-0.036, 0.0, 0.006), 0.004, col("2E8AC8"), seg=10)


@item("LEDX", 1, 1, view="three_q", margin=0.08)
def ledx(I):
    p = I("plastic")
    bc = col("E8ECEE")
    p.box((0, 0.01, 0.016), (0.044, 0.09, 0.032), bc, bevel=0.01)
    cyl_z(p, 0, -0.04, 0.0, 0.032, 0.032, bc, seg=28)
    cyl_z(I("plastic"), 0, -0.04, 0.032, 0.034, 0.028, col("2E3238"), seg=28)
    for k in range(10):
        a = 2 * math.pi * k / 10
        cyl_z(I("emissive"), 0.021 * math.cos(a), -0.04 + 0.021 * math.sin(a), 0.034, 0.0352, 0.0025, col("F0B04A"), seg=8)
    p.box((0, 0.03, 0.0325), (0.02, 0.02, 0.002), col("3A6E8A"))
    label_band(I("paper"), (0, 0.006, 0.0322), (0.03, 0.012, 0), col("3A6E8A"), axis="z", sign=1)


@item("OPHTHALMOSCOPE", 1, 1, view="three_q", margin=0.08)
def ophthalmoscope(I):
    m = I("metal")
    cyl_z(I("rubber"), 0, 0, 0.0, 0.09, 0.014, col("2E3238"), seg=20)
    for k in range(8):
        cyl_z(m, 0, 0, 0.01 + k * 0.009, 0.013 + k * 0.009, 0.0145, col("3E4248"), seg=20)
    cyl_z(m, 0, 0, 0.09, 0.098, 0.012, STEEL, seg=18)
    p = I("plastic")
    p.box((0, 0, 0.118), (0.03, 0.022, 0.04), col("2E3238"), bevel=0.006)
    cyl_y(I("glass"), 0.0, -0.0125, -0.011, 0.124, 0.005, col("8AB8D8"), seg=14)
    cyl_y(p, 0.0, 0.011, 0.013, 0.11, 0.009, col("3A3C40"), seg=16)


# ── others ───────────────────────────────────────────────────────────────────────────────────────────────────────
@item("WEAPON_PARTS", 2, 1, view="three_q", margin=0.06)
def weapon_parts(I):
    f = I("fabric")
    f.box((0, 0, 0.002), (0.17, 0.08, 0.004), col("8A6A4A"), rot=(0, 0, R(4)))
    m = I("gunmetal")
    for k in range(8):
        torus(m, (-0.05 + k * 0.006, -0.01, 0.01), 0.006, 0.0011, col("6A6C68"), axis="x", seg=12, rseg=5)
    m.box((0.01, 0.012, 0.008), (0.04, 0.008, 0.008), col("3A3C3E"), rot=(0, 0, R(-10)), bevel=0.001)
    for k in range(3):
        m.cyl((0.04 + k * 0.01, -0.02, 0.006), (0.06 + k * 0.01, -0.012, 0.006), 0.0018, STEEL, seg=8)
    m.box((-0.03, 0.022, 0.007), (0.02, 0.01, 0.006), col("4A4C4E"), bevel=0.001)


@item("WATER_FILTER", 1, 2, view="front", margin=0.08)
def water_filter(I):
    p = I("plastic")
    cyl_z(p, 0, 0, 0.012, 0.188, 0.034, col("E4E8EA"), seg=28)
    for z in (0.0, 0.188):
        cyl_z(p, 0, 0, z, z + 0.012, 0.037, col("7A7E82"), seg=28)
    cyl_z(p, 0, 0, 0.2, 0.214, 0.012, col("5A5E62"), seg=18)
    for k in range(6):
        z = 0.03 + k * 0.028
        cyl_z(p, 0, 0, z, z + 0.004, 0.0345, col("C8CCD0"), seg=28)
    label_band(I("paper"), (0, -0.0347, 0.1), (0.03, 0, 0.05), col("2E6AA8"))


@item("FUZE", 1, 1, view="three_q", margin=0.1)
def fuze(I):
    m = I("metal")
    oc = col("5E6650")
    cyl_z(m, 0, 0, 0.0, 0.03, 0.008, oc, seg=16)
    cyl_z(m, 0, 0, 0.03, 0.05, 0.011, shade(oc, 0.9), seg=16)
    m.box((0.013, 0, 0.032), (0.006, 0.012, 0.05), oc, rot=(0, R(6), 0))
    m.box((0.008, 0, 0.058), (0.016, 0.012, 0.004), oc)
    torus(I("metal"), (-0.012, -0.006, 0.045), 0.009, 0.0012, STEEL, axis="y", seg=16, rseg=6)
    I("metal").cyl((-0.004, -0.006, 0.045), (0.012, -0.006, 0.045), 0.0012, STEEL, seg=6)


# ── valuables ────────────────────────────────────────────────────────────────────────────────────────────────────
@item("GOLD_ROOSTER", 2, 2, view="three_q_low", margin=0.06)
def gold_rooster(I):
    w = I("wood")
    w.box((0, 0, 0.012), (0.12, 0.08, 0.024), col("5A3A22"), bevel=0.004)
    g = I("gold")
    for x in (-0.012, 0.012):
        g.cyl((x, 0, 0.024), (x * 0.6, 0, 0.06), 0.004, GOLD_C, seg=8)
    lathe(g, [(0.0, 0.05), (0.022, 0.055), (0.032, 0.07), (0.033, 0.09), (0.026, 0.108), (0.012, 0.118), (0.0, 0.12)], GOLD_C, seg=24, x=0.0, axis="z")
    g.cyl((0.02, 0, 0.1), (0.034, 0, 0.142), 0.011, GOLD_C, seg=16)
    lathe(g, [(0.0, 0.138), (0.013, 0.142), (0.014, 0.156), (0.0, 0.166)], GOLD_C, seg=18, x=0.036)
    g.box((0.036, 0, 0.17), (0.016, 0.004, 0.012), col("B8402A"))
    g.cyl((0.048, 0, 0.152), (0.062, 0, 0.148), 0.004, GOLD_C, r2=0.0005, seg=10)
    for k in range(5):
        a = R(100 + k * 18)
        g.box((-0.03 + 0.025 * math.cos(a), 0, 0.1 + 0.04 * math.sin(a)), (0.008, 0.006, 0.05), GOLD_C, rot=(0, -(a - R(90)), 0))


@item("SKULL_RING", 1, 1, view="three_q", margin=0.12)
def skull_ring(I):
    g = I("gold")
    torus(g, (0, 0, 0.012), 0.011, 0.0025, GOLD_C, axis="y", seg=24, rseg=8)
    lathe(g, [(0.0, 0.022), (0.009, 0.024), (0.011, 0.03), (0.01, 0.036), (0.006, 0.04), (0.0, 0.041)], GOLD_C, seg=18)
    for x in (-0.004, 0.004):
        cyl_y(I("rubber"), x, -0.0115, -0.009, 0.032, 0.0025, BLACK, seg=10)
    I("rubber").box((0, -0.0105, 0.027), (0.002, 0.002, 0.003), BLACK)


# ── tools ────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("SCREWDRIVER", 1, 1, view="top_tilt", margin=0.06)
def screwdriver(I):
    a = R(40)
    d = (math.cos(a), math.sin(a))
    p = lambda t, z=0.012: (d[0] * t, d[1] * t, z)
    pl = I("plastic")
    pl.cyl(p(-0.09), p(-0.02), 0.012, col("C83A2A"), seg=8)
    pl.cyl(p(-0.02), p(-0.012), 0.008, col("C83A2A"), r2=0.005, seg=12)
    I("metal").cyl(p(-0.012), p(0.07), 0.003, STEEL, seg=10)
    I("metal").box(p(0.074), (0.01, 0.0055, 0.0012), STEEL, rot=(0, 0, a))


@item("PLIERS", 1, 1, view="top", margin=0.06)
def pliers(I):
    m = I("metal")
    for s in (-1, 1):
        a = R(90 + s * 8)
        m.box((s * 0.006, 0.03, 0.006), (0.009, 0.05, 0.005), STEEL, rot=(0, 0, R(s * -6)))
        I("rubber").box((s * 0.018, -0.04, 0.006), (0.012, 0.08, 0.008), col("3A5A9A"), rot=(0, 0, R(s * 10)), bevel=0.003)
        m.box((s * 0.011, -0.004, 0.006), (0.01, 0.02, 0.006), STEEL, rot=(0, 0, R(s * 8)))
    cyl_z(m, 0, 0.004, 0.002, 0.011, 0.007, col("B8BAB6"), seg=14)


@item("WRENCH", 1, 1, view="top", margin=0.06)
def wrench(I):
    m = I("metal")
    a = R(35)
    ca, sa = math.cos(a), math.sin(a)
    m.box((0, 0, 0.003), (0.13, 0.014, 0.006), STEEL, rot=(0, 0, a), bevel=0.002)
    for s, r0 in ((1, 0.013), (-1, 0.011)):
        cx, cy = s * 0.07 * ca, s * 0.07 * sa
        cyl_z(m, cx, cy, 0.0, 0.006, r0, STEEL, seg=18)
        cyl_z(I("rubber"), cx + s * 0.006 * ca, cy + s * 0.006 * sa, 0.0062, 0.0064, r0 * 0.55, col("D8DAD6"), seg=6)


@item("RATCHET", 1, 2, view="top", margin=0.06)
def ratchet(I):
    m = I("metal")
    m.box((0, -0.02, 0.005), (0.016, 0.16, 0.009), STEEL, bevel=0.003)
    I("rubber").box((0, -0.07, 0.005), (0.02, 0.07, 0.012), col("2E3034"), bevel=0.004)
    cyl_z(m, 0, 0.07, 0.0, 0.012, 0.018, STEEL, seg=24)
    cyl_z(m, 0, 0.07, 0.012, 0.016, 0.006, col("6A6C68"), seg=10)
    cyl_z(m, 0, 0.07, -0.02, 0.0, 0.012, col("C8CAC6"), seg=18)


@item("PIPE_WRENCH", 1, 2, view="top", margin=0.06)
def pipe_wrench(I):
    m = I("metal")
    rc = col("A83A2A")
    m.box((0, -0.03, 0.007), (0.026, 0.17, 0.014), rc, bevel=0.004)
    m.box((-0.004, 0.07, 0.008), (0.03, 0.04, 0.016), col("8E918A"), bevel=0.002)
    m.box((0.012, 0.09, 0.008), (0.036, 0.012, 0.016), col("8E918A"))
    m.box((0.008, 0.06, 0.008), (0.036, 0.012, 0.016), col("6E716A"))
    cyl_x(m, -0.02, 0.02, 0.04, 0.008, 0.009, col("8E918A"), seg=14)
    for k in range(6):
        cyl_x(m, -0.0185 + k * 0.007, -0.0165 + k * 0.007, 0.04, 0.008, 0.0098, col("6E716A"), seg=14)


@item("HAND_DRILL", 3, 2, view="front", margin=0.06)
def hand_drill(I):
    m = I("metal")
    w = I("wood")
    cyl_x(w, -0.15, -0.09, 0, 0.06, 0.016, col("8A5A32"), seg=14)
    cyl_x(m, -0.09, 0.09, 0, 0.06, 0.006, STEEL, seg=12)
    cyl_y(m, -0.01, -0.006, 0.006, 0.06, 0.045, col("6E716A"), seg=32)
    for k in range(24):
        a = 2 * math.pi * k / 24
        m.box((-0.01 + 0.047 * math.cos(a), 0, 0.06 + 0.047 * math.sin(a)), (0.004, 0.012, 0.004), col("6E716A"), rot=(0, -a, 0))
    m.cyl((-0.01, -0.008, 0.06), (0.025, -0.012, 0.08), 0.004, STEEL, seg=8)
    cyl_y(w, 0.025, -0.03, -0.012, 0.08, 0.007, col("8A5A32"), seg=10)
    w.cyl((0.0, 0, 0.065), (0.0, 0, 0.12), 0.01, col("8A5A32"), seg=12)
    cyl_x(m, 0.09, 0.12, 0, 0.06, 0.012, col("8E918A"), seg=16)
    m.cyl((0.12, 0, 0.06), (0.17, 0, 0.06), 0.003, STEEL, r2=0.0008, seg=8)


@item("TOOLSET", 2, 2, view="three_q", margin=0.06)
def toolset(I):
    p = I("plastic")
    bc = col("2E3238")
    p.box((0, 0, 0.04), (0.16, 0.11, 0.08), bc, bevel=0.008)
    p.box((0, 0, 0.0405), (0.162, 0.112, 0.004), shade(bc, 0.75))
    p.box((0, 0, 0.09), (0.06, 0.012, 0.01), shade(bc, 0.85), bevel=0.003)
    for x in (-0.034, 0.034):
        p.box((x, 0, 0.083), (0.008, 0.012, 0.012), shade(bc, 0.85))
    for x in (-0.05, 0.05):
        I("metal").box((x, -0.0565, 0.04), (0.014, 0.003, 0.018), STEEL)
    label_band(I("paper"), (0, -0.0556, 0.022), (0.05, 0, 0.012), col("C83A2A"))


@item("FILE_SET", 2, 2, view="three_q", margin=0.06)
def file_set(I):
    f = I("fabric")
    f.box((0, 0, 0.012), (0.16, 0.1, 0.024), col("5A4632"), bevel=0.008)
    f.box((0, 0, 0.0245), (0.04, 0.1, 0.002), col("3A2E22"))
    w = I("wood")
    m = I("gunmetal")
    for k, y in enumerate((-0.03, -0.01, 0.01, 0.03)):
        cyl_x(w, -0.12, -0.08, y, 0.03, 0.008, col("8A5A32"), seg=12)
        m.box((-0.03, y, 0.03), (0.1, 0.008, 0.004 if k % 2 == 0 else 0.007), col("4A4C4E"))


@item("TAPE_MEASURE", 1, 1, view="three_q", margin=0.1)
def tape_measure(I):
    p = I("plastic")
    yc = col("D8B43A")
    p.box((0, 0, 0.03), (0.06, 0.03, 0.06), yc, bevel=0.012)
    cyl_y(I("rubber"), 0.0, -0.0165, -0.015, 0.03, 0.02, col("2E3034"), seg=24)
    I("metal").box((0.034, 0, 0.006), (0.012, 0.018, 0.003), col("E8D84A"))
    I("metal").box((0.04, 0, 0.004), (0.002, 0.018, 0.008), STEEL)
    p.box((-0.008, 0.016, 0.03), (0.01, 0.002, 0.04), STEEL)


@item("AWL", 1, 1, view="top_tilt", margin=0.06)
def awl(I):
    a = R(35)
    d = (math.cos(a), math.sin(a))
    p = lambda t: (d[0] * t, d[1] * t, 0.012)
    w = I("wood")
    lathe(w, [(0.0, -0.08), (0.009, -0.078), (0.012, -0.06), (0.011, -0.03), (0.007, -0.02), (0.0, -0.018)], col("8A6A42"), seg=16, axis="x",
          x=0.0, y=0.0, z=0.012)
    I("metal").cyl((-0.018, 0, 0.012), (0.07, 0, 0.012), 0.0022, STEEL, r2=0.0003, seg=8)
    I("metal").cyl((-0.02, 0, 0.012), (-0.016, 0, 0.012), 0.0065, col("B08A3C"), seg=12)


@item("SEWING_KIT", 1, 1, view="three_q", margin=0.1)
def sewing_kit(I):
    m = I("metal")
    pc = col("7A5A8A")
    cyl_z(m, 0, 0, 0.0, 0.022, 0.04, pc, seg=28)
    cyl_z(m, 0, 0, 0.022, 0.026, 0.0415, shade(pc, 0.85), seg=28)
    label_band(I("paper"), (0, 0, 0.0262), (0.04, 0.02, 0), col("E8D8B8"), axis="z", sign=1)
    cyl_z(I("wood"), 0.028, -0.032, 0.0, 0.022, 0.008, col("D8C8A0"), seg=14)
    cyl_z(I("fabric"), 0.028, -0.032, 0.004, 0.018, 0.0095, col("B83A3A"), seg=14)
    for k in range(2):
        I("metal").cyl((-0.03 + k * 0.006, -0.044, 0.002), (0.0 + k * 0.006, -0.05, 0.002), 0.0007, STEEL, seg=6)


EXTRA = ["SCREWS", "NUTS", "NAILS", "SILICONE_TUBE", "CORR_HOSE", "PRESSURE_GAUGE", "SEAL_TAPE", "FOAM", "SPARE_PARTS", "RELAY",
         "MOTOR", "PSU", "CPU_FAN", "POWER_CORD", "TPLUG", "POWER_FILTER", "MIL_CABLE", "ES_LAMP", "POWER_DRILL", "SSD",
         "SURVEY_MAPS", "SECURE_FLASH", "LI_BATTERY", "PEN_OIL", "TNT", "THERMITE", "LIGHTER", "GUN_LUBE", "TOILET_PAPER",
         "SALT", "CHLORINE", "ALKALI", "SYRINGE", "MEDS_PILE", "SALINE", "BLOODSET", "LEDX", "OPHTHALMOSCOPE",
         "WEAPON_PARTS", "WATER_FILTER", "FUZE", "GOLD_ROOSTER", "SKULL_RING", "SCREWDRIVER", "PLIERS", "WRENCH", "RATCHET",
         "PIPE_WRENCH", "HAND_DRILL", "TOOLSET", "FILE_SET", "TAPE_MEASURE", "AWL", "SEWING_KIT"]

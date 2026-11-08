"""Zero Return - item models H: the hideout's three barter goods (decision economy-7b, 2026-11-08). Original designs, no
maker's marks: the Powder Tin (in the place of EFT's gunpowder "Kite", "Hawk" and "Eagle"), the Fabric Roll (its aramid,
Cordura, ripstop and fleece) and the Moonshine (its bottle of moonshine). Modelled in metres (front toward -Y, top +Z).
"""
import math
from zr_items import col, shade, label_band, cyl_x, lathe, R
from zr_item_reg import item

OLIVE = col("5E6650")


@item("GUNPOWDER", 1, 2, view="three_q", margin=0.1)
def gunpowder(I):
    """a squat olive tin of smokeless powder standing up: a rounded rectangular body with rolled seams, a screw cap off
    to one side of the top, a carrying lip and a stencilled label with a hazard band"""
    m, p = I("metal"), I("paper")
    w, d, h = 0.075, 0.05, 0.13
    m.box((0, 0, h / 2), (w, d, h), OLIVE, bevel=0.008)                                    # the body
    for z in (0.004, h - 0.004):
        m.box((0, 0, z), (w + 0.002, d + 0.002, 0.004), shade(OLIVE, 0.8), bevel=0.0015)  # rolled seams
    lathe(m, [(0.0, h), (0.013, h), (0.013, h + 0.004)], shade(OLIVE, 0.7), seg=20, x=0.018)   # the spout's collar
    lathe(I("plastic"), [(0.0, h + 0.004), (0.0125, h + 0.004), (0.0125, h + 0.02), (0.0, h + 0.02)], col("2B2D27"), seg=20, x=0.018)
    for k in range(8):                                                                      # grip ribs on the cap
        a = R(k * 45)
        I("plastic").box((0.018 + 0.0128 * math.cos(a), 0.0128 * math.sin(a), h + 0.012), (0.002, 0.002, 0.014), col("1E201C"))
    m.box((-0.02, 0, h + 0.006), (0.026, 0.006, 0.012), shade(OLIVE, 0.75), bevel=0.002)    # the carrying lip
    label_band(p, (0, -d / 2 - 0.0006, 0.07), (0.058, 0, 0.034), col("D8CFAE"))             # the stencilled label
    label_band(p, (0, -d / 2 - 0.0009, 0.082), (0.058, 0, 0.006), col("C9452E"))            # its hazard band
    for k, wl in enumerate((0.04, 0.03, 0.036)):                                            # stencil lines
        label_band(p, (-0.006, -d / 2 - 0.0011, 0.068 - k * 0.008), (wl, 0, 0.003), col("2E3226"))


@item("FABRIC", 1, 1, view="three_q", margin=0.08)
def fabric(I):
    """a tight roll of olive aramid weave lying on its side, the layers showing at its ends, a webbing strap with a
    buckle round its middle and a ripstop offcut tucked under it"""
    c = I("fabric")
    r, z = 0.032, 0.034
    cyl_x(c, -0.05, 0.05, 0.0, z, r, col("5C6B4E"), seg=28)                                 # the roll
    for k, rr in enumerate((0.026, 0.019, 0.012, 0.006)):                                   # layers at both ends
        for x in (-0.0505, 0.0505):
            cyl_x(c, x - 0.0004, x + 0.0004, 0.0, z, rr, shade(col("5C6B4E"), 0.72 if k % 2 == 0 else 1.1), seg=24)
    cyl_x(c, -0.05, -0.035, 0.0, z, r + 0.0015, col("4A5840"), seg=28)                      # the loose outer end
    cyl_x(I("rubber"), -0.006, 0.006, 0.0, z, r + 0.0022, col("2A2C26"), seg=28)            # the strap
    I("metal").box((0, -r - 0.003, z), (0.016, 0.004, 0.014), col("8E918A"), bevel=0.0015)  # its buckle
    c.box((0.012, 0.018, 0.0015), (0.07, 0.05, 0.003), col("7C7A5E"), rot=(0, 0, R(-12)), bevel=0.0012)  # ripstop offcut
    for k in range(5):                                                                      # the ripstop grid
        c.box((0.012 + (k - 2) * 0.013, 0.018, 0.0032), (0.0012, 0.05, 0.0006), shade(col("7C7A5E"), 0.75), rot=(0, 0, R(-12)))


@item("MOONSHINE", 1, 2, view="front", margin=0.1)
def moonshine(I):
    """a corked brown-glass bottle of cloudy spirit with a hand-written paper label tied on with string"""
    g = I("glass")
    lathe(g, [(0.0, 0.0), (0.03, 0.0), (0.032, 0.005), (0.032, 0.125), (0.027, 0.15), (0.0125, 0.172), (0.0115, 0.2),
              (0.013, 0.202), (0.013, 0.206)], col("6B3A16"), seg=24)                       # the bottle
    lathe(I("wood"), [(0.0, 0.2), (0.0105, 0.2), (0.0112, 0.222), (0.0, 0.222)], col("B98B57"), seg=18)  # the cork
    lathe(I("paper"), [(0.0322, 0.045), (0.0322, 0.1)], col("E3D6B0"), seg=24, cap_top=False, cap_bottom=False)  # label
    for k, wl in enumerate((0.03, 0.022, 0.026)):                                           # the hand-written lines
        label_band(I("paper"), (-0.004 + k * 0.002, -0.0325, 0.085 - k * 0.012), (wl, 0, 0.0025), col("3A2A1E"))
    lathe(I("fabric"), [(0.0132, 0.168), (0.0132, 0.172)], col("C9B98E"), seg=18, cap_top=False, cap_bottom=False, z=0.0)  # string


EXTRA = ["GUNPOWDER", "FABRIC", "MOONSHINE"]

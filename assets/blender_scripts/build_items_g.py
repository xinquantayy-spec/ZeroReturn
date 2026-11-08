"""Zero Return - item models G: the stimulant injectors (decision gameplay-4b, 2026-11-08). Original designs: auto-
injector pens lying on their side, each in its own colours so the four read apart at a glance (no maker's marks):
RG-5 regenerative (pale green, after EFT's Propital), SV-3 combat stimulant (graphite and orange, after SJ6), HM-2
hemostatic (deep red, after Zagustin) and the adrenaline injector (white with a blue cap). Modelled in metres (front
toward -Y, top +Z); all 1 x 1 in the grid, like the antidote (build_items_e.py).
"""
from zr_items import col, shade, label_band, cyl_x
from zr_item_reg import item


def pen(I, body, cap, band, label=col("E6E2D2"), grip=None, length=0.13):
    """an auto-injector lying along X: the barrel, a grip ring, the coloured safety cap, the needle end, a label and a
    colour band"""
    p, m = I("plastic"), I("metal")
    x0, x1 = -length / 2, length / 2
    cyl_x(p, x0 + 0.012, x1 - 0.026, 0.0, 0.012, 0.0115, body, seg=18)                 # the barrel
    cyl_x(I("rubber"), x1 - 0.034, x1 - 0.026, 0.0, 0.012, 0.0122, grip or shade(body, 0.6), seg=18)  # the grip ring
    cyl_x(p, x1 - 0.026, x1, 0.0, 0.012, 0.0125, cap, seg=18)                          # the safety cap
    cyl_x(p, x1, x1 + 0.004, 0.0, 0.012, 0.009, shade(cap, 0.8), seg=14)                # the cap's end
    cyl_x(m, x0, x0 + 0.012, 0.0, 0.012, 0.009, col("9A9F9C"), seg=14, r2=0.006)       # the needle end
    label_band(I("paper"), (-0.008, -0.0118, 0.012), (0.06, 0, 0.0125), label)         # the label
    label_band(I("paper"), (-0.008, -0.012, 0.012), (0.06, 0, 0.0035), band)           # its colour stripe


@item("STIM_REGEN", 1, 1, view="three_q", margin=0.1)
def stim_regen(I):
    pen(I, col("9DBB8E"), col("2E5A36"), col("2E5A36"))


@item("STIM_STAMINA", 1, 1, view="three_q", margin=0.1)
def stim_stamina(I):
    pen(I, col("3A3D40"), col("E07A1F"), col("E07A1F"), label=col("CFCBBE"))


@item("STIM_HEMO", 1, 1, view="three_q", margin=0.1)
def stim_hemo(I):
    pen(I, col("7A2420"), col("D8D2C4"), col("D8D2C4"), label=col("E8E2D0"))


@item("STIM_ADREN", 1, 1, view="three_q", margin=0.1)
def stim_adren(I):
    pen(I, col("E4E6E2"), col("2F5FA8"), col("E2B83A"), label=col("F2F0E8"), grip=col("6A6E70"), length=0.12)


EXTRA = ["STIM_REGEN", "STIM_STAMINA", "STIM_HEMO", "STIM_ADREN"]

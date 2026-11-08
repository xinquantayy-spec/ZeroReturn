"""Zero Return - item models F: the map-first tasks' quest items and devices (decision economy-6a, 2026-11-08). Original
designs: logbooks and ledgers in their own cover colours, letters, a sample cold case, a reagent case, clipboards, a
taped parcel, a seal press, a recorder tape, and the Spot Marker, trail camera and signal beacon the tasks plant.
Modelled in metres (front toward -Y, top +Z); all 1 x 1 in the grid.
"""
from zr_items import col, shade, rbox, label_band, cyl_x, cyl_y, cyl_z, R
from zr_item_reg import item

PAGE = col("E2DCC8")
INK = col("2A2B28")


def book(I, cover, w=0.15, l=0.21, t=0.03, band=None, label=None):
    """a closed hardback lying flat: cover boards, the page block, a spine"""
    c, p = I("leather"), I("paper")
    c.box((0, 0, 0.002), (w, l, 0.004), cover, bevel=0.0015)            # back board
    c.box((0, 0, t - 0.002), (w, l, 0.004), cover, bevel=0.0015)        # front board
    p.box((0.003, 0, t / 2), (w - 0.012, l - 0.008, t - 0.006), PAGE)   # pages
    c.box((-w / 2 + 0.003, 0, t / 2), (0.008, l, t), shade(cover, 0.85), bevel=0.002)  # spine
    if band:
        label_band(p, (0.01, -0.03, t + 0.0005), (w * 0.7, 0.02, 0), band, axis="z", sign=1)
    if label:
        label_band(p, (0.01, 0.04, t + 0.0005), (w * 0.55, 0.05, 0), label, axis="z", sign=1)


@item("QI_WATCHLOG", 1, 1, view="top_tilt", margin=0.1)
def watchlog(I):
    book(I, col("5E5A4A"), band=col("B8A05A"), label=col("D8D0B4"))


@item("QI_NOTEBOOK", 1, 1, view="top_tilt", margin=0.1)
def notebook(I):
    book(I, col("4E3E2E"), w=0.11, l=0.16, t=0.018, band=col("2A221A"))
    I("rubber").box((0.05, 0, 0.0185), (0.004, 0.16, 0.002), col("1E1A16"))  # the elastic strap


@item("QI_BOATLOG", 1, 1, view="top_tilt", margin=0.1)
def boatlog(I):
    book(I, col("3E5068"), band=col("C8B070"), label=col("D8D4C4"))


@item("QI_FURNACE", 1, 1, view="top_tilt", margin=0.1)
def furnace(I):
    book(I, col("6E4A3A"), l=0.24, t=0.035, band=col("1E1E1C"), label=col("CFC6AE"))


@item("QI_REGISTER", 1, 1, view="top_tilt", margin=0.1)
def register(I):
    book(I, col("5A6A4A"), w=0.17, l=0.24, t=0.04, label=col("D6D0BA"))


@item("QI_PRICELIST", 1, 1, view="top_tilt", margin=0.1)
def pricelist(I):
    book(I, col("C27A2E"), w=0.14, l=0.2, t=0.022, band=col("3A2A1E"), label=col("EDE6D2"))


@item("QI_LETTERS", 1, 1, view="top_tilt", margin=0.1)
def letters(I):
    p, f = I("paper"), I("fabric")
    for k, (dx, dy, rz) in enumerate(((0, 0, 0), (0.006, -0.004, 6), (-0.005, 0.005, -5), (0.003, 0.002, 3))):
        p.box((dx, dy, 0.003 + k * 0.004), (0.16, 0.1, 0.0035), shade(col("D8CFB0"), 1 - k * 0.03), rot=(0, 0, R(rz)))
    f.box((0, 0, 0.018), (0.004, 0.106, 0.002), col("8A6A44"))   # the string
    f.box((0, 0, 0.018), (0.166, 0.004, 0.002), col("8A6A44"))


@item("QI_SAMPLES", 1, 1, view="three_q", margin=0.1)
def samples(I):
    p = I("plastic")
    rbox(p, (0, 0, 0.045), (0.16, 0.11, 0.09), col("E2E6E4"), bevel=0.12)
    p.box((0, 0, 0.088), (0.162, 0.112, 0.012), col("4F7FA8"), bevel=0.004)     # the lid band
    label_band(I("paper"), (0.0, -0.0556, 0.05), (0.07, 0, 0.035), col("C8302A"))  # the seal
    p.box((0, 0, 0.1), (0.07, 0.016, 0.012), col("3E5E7E"), bevel=0.004)         # handle


@item("QI_REAGENT", 1, 1, view="three_q", margin=0.1)
def reagent(I):
    f, p = I("fabric"), I("plastic")
    rbox(f, (0, 0, 0.04), (0.18, 0.12, 0.08), col("6A8A7A"), bevel=0.2)
    p.box((0, 0, 0.081), (0.08, 0.018, 0.014), col("2E3430"), bevel=0.004)
    f.box((0, -0.061, 0.04), (0.17, 0.003, 0.006), shade(col("6A8A7A"), 0.75))   # zip line
    label_band(I("paper"), (0.04, -0.0612, 0.05), (0.05, 0, 0.025), col("E2DEC8"))


def clipboard(I, sheet):
    w, p, m = I("wood"), I("paper"), I("metal")
    w.box((0, 0, 0.003), (0.16, 0.22, 0.006), col("8A6A44"), bevel=0.002)
    for k in range(3):
        p.box((0.002 * k, -0.004 * k, 0.0065 + k * 0.0012), (0.145, 0.19, 0.001), shade(sheet, 1 - 0.04 * k))
    m.box((0, 0.1, 0.012), (0.06, 0.03, 0.012), col("9A9F9C"), bevel=0.003)       # the clip
    for k in range(5):
        label_band(p, (-0.01, 0.05 - k * 0.03, 0.0104), (0.11, 0.005, 0), INK, axis="z", sign=1)


@item("QI_MANIFEST", 1, 1, view="top_tilt", margin=0.08)
def manifest(I):
    clipboard(I, col("E6DCC0"))
    label_band(I("paper"), (0.04, -0.07, 0.0106), (0.04, 0.025, 0), col("B8302A"), axis="z", sign=1)  # a stamp


@item("QI_UNIT14", 1, 1, view="top_tilt", margin=0.08)
def unit14(I):
    clipboard(I, col("E8E8DC"))


@item("QI_PARCEL", 1, 1, view="three_q", margin=0.1)
def parcel(I):
    c, p = I("cardboard"), I("plastic")
    c.box((0, 0, 0.05), (0.16, 0.13, 0.1), col("A88A5E"), bevel=0.004)
    p.box((0, 0, 0.1005), (0.04, 0.132, 0.001), col("C8B888"))                   # tape over the top
    p.box((0, -0.0655, 0.05), (0.04, 0.001, 0.1), col("C8B888"))
    label_band(I("paper"), (0.05, -0.066, 0.06), (0.04, 0, 0.03), col("D8B030"))  # the seizure tag


@item("QI_SEAL", 1, 1, view="three_q", margin=0.1)
def seal(I):
    m, w = I("metal"), I("wood")
    m.box((0, 0, 0.012), (0.12, 0.08, 0.024), col("6E6450"), bevel=0.004)        # the base
    m.box((0, 0.02, 0.06), (0.03, 0.03, 0.07), col("5A5244"), bevel=0.004)        # the column
    m.box((0, -0.005, 0.1), (0.03, 0.08, 0.018), col("5A5244"), bevel=0.004)      # the head
    cyl_z(m, 0, -0.03, 0.026, 0.05, 0.016, col("8A7A5A"), seg=16)                 # the die
    cyl_y(w, 0, -0.04, 0.09, 0.1, 0.008, col("4A3A2A"), seg=10)                   # the lever's grip


@item("QI_TAPE", 1, 1, view="top_tilt", margin=0.1)
def tape(I):
    p = I("plastic")
    p.box((0, 0, 0.0125), (0.19, 0.105, 0.025), col("2E2E32"), bevel=0.003)
    for x in (-0.045, 0.045):
        cyl_z(p, x, 0, 0.0252, 0.0262, 0.017, col("1A1A1C"), seg=14)                # the spool windows
    label_band(I("paper"), (0, -0.032, 0.0256), (0.15, 0.03, 0), col("E2DEC8"), axis="z", sign=1)
    label_band(I("paper"), (-0.03, -0.032, 0.0258), (0.06, 0.006, 0), INK, axis="z", sign=1)


@item("MARKER", 1, 1, view="three_q", margin=0.1)
def marker(I):
    p, r = I("polymer"), I("rubber")
    rbox(p, (0, 0, 0.022), (0.06, 0.04, 0.044), col("3E4436"), bevel=0.15)
    cyl_z(r, 0.018, 0, 0.044, 0.12, 0.003, col("1E1F20"), seg=8)                  # the antenna
    I("emissive").box((-0.012, -0.0205, 0.034), (0.006, 0.001, 0.006), col("FF3A2A"))  # the lamp


@item("CAMERA", 1, 1, view="three_q", margin=0.1)
def camera(I):
    p, g, f = I("polymer"), I("glass"), I("fabric")
    rbox(p, (0, 0, 0.05), (0.09, 0.06, 0.12), col("5A5638"), bevel=0.12)
    cyl_y(g, 0, -0.031, -0.026, 0.07, 0.016, col("1A2228"), seg=16)               # the lens
    p.box((0, -0.031, 0.025), (0.03, 0.004, 0.02), col("2A2A26"))                  # the sensor window
    f.box((0, 0.034, 0.05), (0.1, 0.006, 0.02), col("2E2E28"))                     # the strap


@item("BEACON", 1, 1, view="three_q", margin=0.1)
def beacon(I):
    p, m = I("plastic"), I("metal")
    cyl_z(p, 0, 0, 0.0, 0.1, 0.03, col("D8A53A"), seg=18)
    cyl_z(m, 0, 0, 0.1, 0.112, 0.024, col("6E7370"), seg=14)
    cyl_z(I("rubber"), 0, 0, 0.112, 0.2, 0.004, col("1E1F20"), seg=8)            # the whip antenna
    label_band(I("paper"), (0, -0.0302, 0.05), (0.03, 0, 0.03), col("2A2B28"))


EXTRA = ["QI_WATCHLOG", "QI_NOTEBOOK", "QI_BOATLOG", "QI_FURNACE", "QI_REGISTER", "QI_PRICELIST", "QI_LETTERS",
         "QI_SAMPLES", "QI_REAGENT", "QI_MANIFEST", "QI_UNIT14", "QI_PARCEL", "QI_SEAL", "QI_TAPE", "MARKER", "CAMERA",
         "BEACON"]

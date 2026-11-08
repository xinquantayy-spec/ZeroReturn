"""Zero Return - item models S: economy-1a's thirteenth catalogue slice (2026-11-08), the EFT items that let more of
its hideout crafts in. Original designs after what each thing is, no maker's marks: a ream of printer paper, a baking
cookbook and a semiconductor textbook standing on end, a handheld Geiger counter with its probe, a speaker ring magnet,
a sledgehammer, the SV-1 combat stimulant (the stims' pen in its own colours) and the 7.6x39 and 7.6x54R FMJ rounds.
Modelled in metres (front toward -Y, top +Z); sizes are the inventory cells (EFT's grid sizes; the textbook's ours).
"""
import math
from zr_items import col, shade, label_band, cyl_y, cyl_z, R
from zr_item_reg import item
from build_items_a import ammo_item, STEEL_CASE
from build_items_g import pen

WHITE, BLACK, STEEL = col("E8E8E2"), col("1E2022"), col("9A9C96")
CLAD = col("A87048")             # copper-clad steel jacket
PAGES = col("EDE6D2")            # page edges

# ── rounds: plain copper-clad jackets on lacquered steel cases, no tip colour (the FMJ loads) ──────────────────────
ammo_item("A76_FMJ", 0.039, 0.02, 0.0058, CLAD, casecol=STEEL_CASE)
ammo_item("A76L_FMJ", 0.054, 0.024, 0.0062, CLAD, casecol=STEEL_CASE, n=4)


# ── the SV-1 (EFT's SJ1): the stims' auto-injector, graphite with a teal cap and band ───────────────────────────────
@item("STIM_COMBAT", 1, 1, view="three_q", margin=0.1)
def stim_combat(I):
    pen(I, col("3A3D40"), col("2A8A8A"), col("2A8A8A"), label=col("CFCBBE"))


# ── household: a ream of printer paper ───────────────────────────────────────────────────────────────────────────
@item("PRINTER_PAPER", 2, 1, view="three_q", margin=0.06)
def printer_paper(I):
    """a ream of A4 lying flat in its paper wrapper, a printed band round it, the wrapper's folded ends"""
    p = I("paper")
    band = col("3A6A9A")
    p.box((0, 0, 0.025), (0.297, 0.21, 0.05), col("E6E4DA"), bevel=0.002)
    label_band(p, (0.0, -0.1052, 0.025), (0.13, 0, 0.044), band)                          # the band, front
    label_band(p, (0.0, -0.1055, 0.03), (0.13, 0, 0.006), WHITE)                          # a white stripe across it
    label_band(p, (0.0, 0.0, 0.0502), (0.13, 0.21, 0), band, axis="z", sign=1)            # the band over the top
    for s in (-1, 1):                                                                     # the folded ends
        label_band(p, (s * 0.1487, 0.0, 0.025), (0, 0.15, 0.03), col("D8D6CC"), axis="x", sign=s)


# ── info: two books standing on end, the cover toward the camera ────────────────────────────────────────────────────
def book(I, w, t, h, cover, spine=None):
    """boards, spine and page block of a hardback standing on end (spine at -X); returns the front cover's face (y)"""
    b, pg = I("cardboard"), I("paper")
    b.box((0, -t / 2 + 0.0015, h / 2), (w, 0.003, h), cover, bevel=0.0012)                # the front board
    b.box((0, t / 2 - 0.0015, h / 2), (w, 0.003, h), cover, bevel=0.0012)                 # the back board
    b.box((-w / 2 + 0.0015, 0, h / 2), (0.003, t, h), spine or shade(cover, 0.75), bevel=0.0012)  # the spine
    pg.box((0.002, 0, h / 2), (w - 0.008, t - 0.006, h - 0.008), PAGES)                    # the page block
    return -t / 2


@item("COOK_BOOK", 1, 2, view="front", margin=0.08)
def cook_book(I):
    """a red cloth cookbook: a cream panel with a round loaf on it and a title line"""
    cover = col("B8442E")
    y = book(I, 0.17, 0.034, 0.24, cover)
    pa = I("paper")
    label_band(pa, (0.004, y - 0.0002, 0.15), (0.12, 0, 0.12), col("EADFC4"))              # the cream panel
    label_band(pa, (0.004, y - 0.0005, 0.192), (0.1, 0, 0.012), shade(cover, 0.7))         # the title line
    label_band(pa, (0.004, y - 0.0005, 0.106), (0.07, 0, 0.006), shade(cover, 0.7))        # a second, shorter line
    pa.cyl((0.004, y - 0.0004, 0.148), (0.004, y - 0.0016, 0.148), 0.028, col("C8873A"), seg=24)   # the loaf
    pa.cyl((0.004, y - 0.0016, 0.152), (0.004, y - 0.0022, 0.152), 0.02, col("D89A4E"), seg=20)    # its crust
    for k in (-1, 0, 1):                                                                     # the scores
        pa.box((0.004 + k * 0.012, y - 0.0024, 0.152), (0.003, 0.0004, 0.022), col("8A5A2A"), rot=(0, R(20), 0))


@item("SEMI_TEXTBOOK", 1, 2, view="front", margin=0.08)
def semi_textbook(I):
    """a thick blue textbook: a lattice of small squares (a crystal diagram), a white title band, a stripe at the foot"""
    cover = col("2E4A7A")
    y = book(I, 0.17, 0.05, 0.245, cover, spine=col("223A60"))
    pa = I("paper")
    label_band(pa, (0.004, y - 0.0002, 0.208), (0.13, 0, 0.026), WHITE)                     # the title band
    label_band(pa, (0.004, y - 0.0005, 0.208), (0.1, 0, 0.006), cover)                      # the title
    for i in range(4):                                                                       # the lattice
        for j in range(5):
            x = -0.045 + i * 0.03
            z = 0.06 + j * 0.026
            label_band(pa, (0.004 + x, y - 0.0003, z), (0.012, 0, 0.012), col("8AB0D8"))
            if i < 3:
                label_band(pa, (0.004 + x + 0.015, y - 0.0002, z), (0.018, 0, 0.002), col("5A7EAA"))
    label_band(pa, (0.004, y - 0.0002, 0.026), (0.15, 0, 0.012), col("C8A43A"))             # the stripe at the foot


# ── electronics ────────────────────────────────────────────────────────────────────────────────────────────────────
@item("GEIGER", 1, 2, view="three_q", margin=0.08)
def geiger(I):
    """a handheld radiation counter standing up: a yellow case, a meter and a knob on the front, a carry handle, the
    probe clipped to its right side on a coiled lead"""
    p, m, rb = I("plastic"), I("metal"), I("rubber")
    case = col("C8A43A")
    p.box((0, 0, 0.075), (0.08, 0.055, 0.15), case, bevel=0.006)
    p.box((0, -0.0285, 0.11), (0.062, 0.004, 0.042), BLACK, bevel=0.002)                    # the meter's bezel
    label_band(I("paper"), (0, -0.0306, 0.11), (0.052, 0, 0.032), col("E8E4D0"))            # the meter face
    label_band(I("paper"), (0, -0.0309, 0.118), (0.04, 0, 0.002), BLACK)                    # its scale
    p.box((0.004, -0.032, 0.106), (0.0015, 0.0006, 0.026), BLACK, rot=(0, R(25), 0))        # the needle
    cyl_y(rb, -0.018, -0.0275, -0.036, 0.05, 0.009, BLACK, seg=16)                         # the range knob
    p.box((0.018, -0.03, 0.05), (0.012, 0.006, 0.008), BLACK, bevel=0.001)                 # the switch
    label_band(I("paper"), (0.0, -0.0281, 0.022), (0.05, 0, 0.01), BLACK)                  # a band at the foot
    p.tube([(-0.028, 0, 0.148), (-0.028, 0, 0.172), (0.028, 0, 0.172), (0.028, 0, 0.148)], 0.0055, col("2A2C2E"), seg=8)  # handle
    # the probe on its clip, and its coiled lead into the case
    cyl_z(m, 0.052, 0, 0.03, 0.13, 0.011, col("8C9290"), seg=16)
    cyl_z(rb, 0.052, 0, 0.13, 0.138, 0.0105, BLACK, seg=16)
    cyl_z(rb, 0.052, 0, 0.022, 0.03, 0.009, BLACK, seg=16)
    p.box((0.044, 0, 0.1), (0.012, 0.014, 0.012), BLACK)                                    # the clip
    pts = [(0.052 + 0.006 * math.cos(k * 0.9), 0.006 * math.sin(k * 0.9), 0.022 - k * 0.0009) for k in range(16)]
    pts.append((0.042, 0, 0.008))
    rb.tube(pts, 0.0018, BLACK, seg=6)


@item("MAGNET", 1, 1, view="three_q", margin=0.12)
def magnet(I):
    """a ring magnet off a speaker: a dark ferrite ring between two steel plates, the pole piece through its middle"""
    c, m = I("ceramic"), I("metal")
    cyl_z(m, 0, 0, 0.0, 0.003, 0.041, STEEL, seg=32)                                         # the back plate
    cyl_z(c, 0, 0, 0.003, 0.019, 0.04, col("34373A"), seg=32)                                # the ferrite ring
    cyl_z(m, 0, 0, 0.019, 0.022, 0.039, STEEL, seg=32)                                       # the front plate
    cyl_z(c, 0, 0, 0.022, 0.0224, 0.017, BLACK, seg=24)                                      # the gap round the pole
    cyl_z(m, 0, 0, 0.0, 0.025, 0.012, col("B8BCB8"), seg=24)                                 # the pole piece


# ── tools: a sledgehammer standing on its handle ────────────────────────────────────────────────────────────────────
@item("SLEDGEHAMMER", 2, 5, view="front", margin=0.05)
def sledgehammer(I):
    """a long ash-coloured handle with a rubber grip, a painted steel head with bare striking faces"""
    w, rb, g, m = I("wood"), I("rubber"), I("gunmetal"), I("metal")
    cyl_z(w, 0, 0, 0.0, 0.82, 0.016, col("C8A878"), seg=14)                                 # the handle
    w.box((0, 0, 0.795), (0.038, 0.03, 0.04), col("B89868"), bevel=0.004)                   # its swell under the head
    cyl_z(rb, 0, 0, 0.0, 0.2, 0.019, col("2A2C2E"), seg=14)                                  # the grip
    cyl_z(rb, 0, 0, -0.006, 0.0, 0.021, col("2A2C2E"), seg=14)                               # its end knob
    g.box((0, 0, 0.84), (0.2, 0.068, 0.068), col("4A4E52"), bevel=0.006)                    # the head
    for s in (-1, 1):
        m.box((s * 0.1005, 0, 0.84), (0.004, 0.062, 0.062), STEEL, bevel=0.002)             # the striking faces


EXTRA = ["A76_FMJ", "A76L_FMJ", "STIM_COMBAT", "PRINTER_PAPER", "COOK_BOOK", "SEMI_TEXTBOOK", "GEIGER", "MAGNET", "SLEDGEHAMMER"]

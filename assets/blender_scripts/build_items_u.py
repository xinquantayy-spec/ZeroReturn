"""Zero Return - item models U: economy-1a's fifteenth catalogue slice (2026-11-09), EFT's remaining barter goods.
Original designs after what each thing is, with no maker's names, logos or lettering (printed areas are plain bands):
electronics (a disc drive, a desktop processor, a working and a cracked LCD panel, a handheld game console, a programmable
processor on its carrier board, a rugged storage module, a gas analyser), the three fabrics beside aramid (FABRIC is
drawn again here at EFT's 2x1, folded like the others), the flake and ball powder tins (the fine powder keeps
build_items_h's olive tin), heavy-duty pliers, a ratchet cable cutter, a can of mounting foam with its straw, a twin tube
of cold-weld epoxy, a roll of insulating tape, a windproof lighter, hunting matches, sodium bicarbonate, shampoo,
multivitamins, hydrogen peroxide, a tin of coffee beans, a pack of sugar, and the books: an optoelectronics textbook, a
diary, a slim diary, a ring-bound technical manual and a battered antique book.
Modelled in metres (front toward -Y, top +Z), conventions in zr_items.py; sizes are the inventory cells (EFT's grids).
"""
import math
from zr_items import col, shade, label_band, cyl_x, cyl_y, cyl_z, lathe, R
from zr_item_reg import item
from build_items_s import book, WHITE, BLACK, STEEL
from build_items_j import torus

BEIGE = col("C8C2B0")
PCB = col("2E5A3A")
GOLDP = col("C8A040")             # gold contacts
GLASSD = col("1A1E24")            # a dark screen


# ── electronics ────────────────────────────────────────────────────────────────────────────────────────────────────
@item("DISC_DRIVE", 2, 1, view="three_q", margin=0.06)
def disc_drive(I):
    """a desktop optical drive lying flat: a beige steel case, a black bezel with the tray half open, an eject button
    and a lamp, a plain label on the lid"""
    m, p = I("metal"), I("plastic")
    m.box((0, 0, 0.021), (0.146, 0.17, 0.042), BEIGE, bevel=0.0015)
    p.box((0, -0.0865, 0.021), (0.148, 0.004, 0.043), col("1E2022"), bevel=0.001)          # the bezel
    p.box((0, -0.11, 0.025), (0.128, 0.046, 0.005), col("26282A"), bevel=0.001)            # the tray, half out
    cyl_z(p, 0, -0.105, 0.0275, 0.0285, 0.016, col("3A3C3E"), seg=24)                       # the disc well
    cyl_z(p, 0, -0.105, 0.0285, 0.0295, 0.005, col("4A4C4E"), seg=12)                       # the spindle
    p.box((0.052, -0.0895, 0.011), (0.014, 0.002, 0.005), col("5A5C5E"), bevel=0.0008)       # eject button
    I("emissive").box((0.034, -0.0892, 0.011), (0.003, 0.001, 0.002), col("3AD84A"))         # the lamp
    label_band(I("paper"), (0.025, 0.03, 0.042), (0.06, 0.045, 0), col("E8E4D8"), axis="z", sign=1)
    label_band(I("paper"), (0.025, 0.04, 0.0422), (0.045, 0.006, 0), col("3A3C3E"), axis="z", sign=1)
    for k in range(4):                                                                        # vent slots at the back
        label_band(m, (-0.05 + k * 0.012, 0.07, 0.0421), (0.006, 0.02, 0), shade(BEIGE, 0.6), axis="z", sign=1)


@item("PC_CPU", 1, 1, view="top_tilt", margin=0.12)
def pc_cpu(I):
    """a square desktop processor: a green substrate, a nickel heat spreader with a stepped edge, a gold corner mark and
    a field of gold contacts showing under the edge"""
    p, m, g = I("plastic"), I("metal"), I("gold")
    p.box((0, 0, 0.0008), (0.0375, 0.0375, 0.0016), PCB, bevel=0.0003)                     # the substrate
    m.box((0, 0, 0.0028), (0.03, 0.03, 0.0024), col("B8BCBA"), bevel=0.0008)                # the heat spreader
    m.box((0, 0, 0.0041), (0.026, 0.026, 0.0004), col("C8CCCA"))                            # its raised top
    g.box((-0.0165, -0.0165, 0.0017), (0.003, 0.003, 0.0003), GOLDP)                         # the corner mark
    for i in range(6):                                                                        # contacts round the rim
        g.box((-0.0125 + i * 0.005, -0.0178, 0.0004), (0.0016, 0.0016, 0.0008), GOLDP)
        g.box((-0.0178, -0.0125 + i * 0.005, 0.0004), (0.0016, 0.0016, 0.0008), GOLDP)
    for k in range(3):                                                                        # small parts on the substrate
        p.box((0.0165, -0.008 + k * 0.008, 0.0019), (0.002, 0.004, 0.0008), col("8A6A3A"))


def lcd(I, cracked):
    """a bare LCD panel standing up: a dark screen in a thin steel frame, the driver board along the foot and a ribbon
    cable hanging from it; cracked, a web of light lines from one corner and a chipped edge"""
    m, c, p = I("metal"), I("ceramic"), I("plastic")
    w, t, h = 0.11, 0.004, 0.17
    m.box((0, 0, h / 2), (w, t, h), col("8A8E90"), bevel=0.0006)                             # the frame
    c.box((0, -t / 2 - 0.0003, h / 2 + 0.006), (w - 0.008, 0.0008, h - 0.022), GLASSD)       # the screen
    p.box((0, 0.0005, 0.007), (w - 0.012, t + 0.002, 0.012), PCB)                            # the driver board
    I("foil").box((0.018, 0.0, -0.012), (0.026, 0.0012, 0.03), col("B8763A"), rot=(R(10), 0, 0))  # the ribbon
    p.box((0.018, 0.002, -0.027), (0.028, 0.004, 0.004), col("E8E4D8"))                      # its connector
    if cracked:
        y = -t / 2 - 0.0009
        ox, oz = 0.038, 0.14                                                                   # the impact point
        for k, (dx, dz) in enumerate(((-0.06, -0.05), (-0.03, -0.09), (-0.075, 0.0), (0.0, -0.11), (-0.05, 0.02), (0.012, 0.022))):
            crack(c, ox, oz, ox + dx, oz + dz, y, 0.0011, col("8A96A2") if k % 2 == 0 else col("6A7682"))
        for r in (0.012, 0.022):                                                               # rings round the impact
            for k in range(8):
                a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 0.8) / 8
                crack(c, ox + r * math.cos(a0), oz + r * math.sin(a0), ox + r * math.cos(a1), oz + r * math.sin(a1), y, 0.0008, col("7A8692"))
        m.box((w / 2 - 0.006, 0, h - 0.008), (0.014, t + 0.001, 0.016), col("2A2C2E"), rot=(0, R(30), 0))  # the chipped corner


def crack(b, x0, z0, x1, z1, y, wd, color):
    """a thin straight line on a face toward -Y, from (x0, z0) to (x1, z1)"""
    dx, dz = x1 - x0, z1 - z0
    ln = math.hypot(dx, dz) or 1.0
    nx, nz = -dz / ln * wd / 2, dx / ln * wd / 2
    b.face([(x0 - nx, y, z0 - nz), (x1 - nx, y, z1 - nz), (x1 + nx, y, z1 + nz), (x0 + nx, y, z0 + nz)], color, double=True)


@item("LCD_PANEL", 1, 2, view="front", margin=0.08)
def lcd_panel(I):
    lcd(I, False)


@item("LCD_BROKEN", 1, 2, view="front", margin=0.08)
def lcd_broken(I):
    lcd(I, True)


@item("GAME_CONSOLE", 1, 2, view="front", margin=0.08)
def game_console(I):
    """a pocket game console standing up: an olive-grey plastic body, a small greenish screen in a dark bezel, a cross
    pad and two round buttons, speaker slots, a cartridge in the top slot"""
    p, rb = I("plastic"), I("rubber")
    body = col("A8AC9A")
    p.box((0, 0, 0.065), (0.075, 0.022, 0.13), body, bevel=0.006)
    p.box((0, -0.0115, 0.095), (0.06, 0.002, 0.048), col("3A3C40"), bevel=0.002)             # the bezel
    I("ceramic").box((0, -0.0128, 0.096), (0.044, 0.0008, 0.036), col("8A9A5A"))             # the screen
    pad = col("2A2C2E")
    rb.box((-0.018, -0.012, 0.045), (0.022, 0.004, 0.007), pad, bevel=0.001)                  # the cross pad
    rb.box((-0.018, -0.012, 0.045), (0.007, 0.004, 0.022), pad, bevel=0.001)
    for x, z in ((0.014, 0.04), (0.026, 0.05)):                                               # the two buttons
        cyl_y(rb, x, -0.011, -0.0145, z, 0.0052, col("8A2E4A"), seg=14)
    for x in (-0.006, 0.004):                                                                 # start and select
        rb.box((x, -0.0118, 0.022), (0.007, 0.0016, 0.002), col("4A4C50"), rot=(0, R(-25), 0))
    for k in range(3):                                                                        # the speaker slots
        rb.box((0.018 + k * 0.004, -0.0118, 0.014), (0.0016, 0.0016, 0.012), col("4A4C50"))
    p.box((0, 0.002, 0.135), (0.05, 0.008, 0.016), col("4A4E58"), bevel=0.001)              # the cartridge
    label_band(I("paper"), (0, -0.0022, 0.137), (0.036, 0, 0.008), col("C8B04A"))


@item("FPGA_CHIP", 1, 1, view="top_tilt", margin=0.1)
def fpga_chip(I):
    """a small carrier board: a big square processor with a metal lid in the middle, two memory chips, a row of gold
    edge contacts and mounting holes"""
    p, m, g = I("plastic"), I("metal"), I("gold")
    p.box((0, 0, 0.0008), (0.055, 0.05, 0.0016), col("1E4A2E"), bevel=0.0004)               # the board
    p.box((0.0, 0.002, 0.0026), (0.028, 0.028, 0.002), col("1E2022"), bevel=0.0006)          # the package
    m.box((0.0, 0.002, 0.004), (0.022, 0.022, 0.0008), col("A8ACAA"))                        # its lid
    for x in (-0.021, 0.021):                                                                 # memory chips
        p.box((x, 0.006, 0.0022), (0.008, 0.014, 0.0012), col("26282A"))
    for k in range(10):                                                                       # edge contacts
        g.box((-0.0225 + k * 0.005, -0.0235, 0.00165), (0.003, 0.004, 0.0002), GOLDP)
    for x, y in ((-0.024, 0.021), (0.024, 0.021)):                                            # mounting holes
        cyl_z(m, x, y, 0.0016, 0.0019, 0.0022, col("C8C8C0"), seg=12)
    for k in range(5):                                                                        # small parts
        p.box((-0.012 + k * 0.006, -0.016, 0.0019), (0.002, 0.0035, 0.0008), col("8A6A3A"))


@item("STORAGE_MODULE", 1, 1, view="three_q", margin=0.1)
def storage_module(I):
    """a rugged flash storage module: a dark anodised case with cooling fins on top, a backplane connector at the rear,
    two captive screws and a plain plate at the front"""
    m, g, p = I("metal"), I("gold"), I("plastic")
    case = col("4A5258")
    m.box((0, 0, 0.0125), (0.06, 0.075, 0.025), case, bevel=0.0015)
    for k in range(7):                                                                        # the fins
        m.box((-0.024 + k * 0.008, 0.004, 0.0275), (0.003, 0.06, 0.005), shade(case, 1.15), bevel=0.0005)
    p.box((0, 0.039, 0.011), (0.05, 0.004, 0.014), col("1E2022"))                            # the connector
    for k in range(8):
        g.box((-0.0175 + k * 0.005, 0.0412, 0.011), (0.0022, 0.0006, 0.009), GOLDP)
    for x in (-0.022, 0.022):                                                                 # captive screws
        cyl_y(m, x, -0.0375, -0.042, 0.0125, 0.0035, col("B8BAB6"), seg=14)
        cyl_y(m, x, -0.042, -0.0435, 0.0125, 0.0042, col("A8AAA6"), seg=14)
    label_band(I("paper"), (0, -0.0381, 0.0125), (0.026, 0, 0.012), col("C8C4B0"))          # the plate
    label_band(I("paper"), (0, -0.0384, 0.015), (0.018, 0, 0.002), col("2A2C2E"))


@item("GAS_ANALYSER", 1, 2, view="three_q", margin=0.08)
def gas_analyser(I):
    """a handheld gas detector standing up: a yellow body in black rubber bumpers, a sensor grille at the top, a small
    display and three buttons, a belt clip at the back"""
    p, rb = I("plastic"), I("rubber")
    body = col("D8A82E")
    p.box((0, 0, 0.06), (0.06, 0.032, 0.12), body, bevel=0.006)
    for z in (0.006, 0.114):                                                                  # the bumpers
        rb.box((0, 0, z), (0.064, 0.036, 0.014), col("26282A"), bevel=0.004)
    for k in range(5):                                                                        # the sensor grille
        rb.box((0, -0.0165, 0.1 - k * 0.004), (0.036, 0.002, 0.002), col("1E2022"))
    p.box((0, -0.0165, 0.07), (0.044, 0.002, 0.026), col("2A2C2E"), bevel=0.001)             # the display bezel
    I("ceramic").box((0, -0.0177, 0.07), (0.036, 0.0006, 0.018), col("6A8A6A"))              # the display
    for k in range(3):                                                                        # buttons
        cyl_y(rb, -0.014 + k * 0.014, -0.016, -0.019, 0.042, 0.0045, col("3A3C3E"), seg=12)
    I("emissive").box((0.018, -0.0167, 0.088), (0.004, 0.001, 0.003), col("E83A2A"))         # the alarm lamp
    p.box((0, 0.02, 0.07), (0.022, 0.006, 0.06), col("2A2C2E"), bevel=0.002)                # the belt clip


# ── fabrics: folded lengths of cloth (EFT's 2x1) ────────────────────────────────────────────────────────────────────
def folded(I, cloth, grid=None, sheen=False, fluffy=False, tie=col("2A2C26")):
    """a length of cloth folded into a flat bundle lying down: three stacked folds, the rolled edges at the sides, a
    weave or grid printed on top, a cord tied round it"""
    f = I("fabric")
    w, d = 0.15, 0.075
    for k, (dz, ox) in enumerate(((0.0, 0.0), (0.0065, 0.003), (0.013, -0.002))):
        f.box((ox, 0, 0.0035 + dz), (w - k * 0.004, d - k * 0.002, 0.0068), shade(cloth, 0.9 + k * 0.06), bevel=0.0028 if fluffy else 0.0018)
    for s in (-1, 1):                                                                         # the folded edges
        cyl_y(f, s * (w / 2 - 0.002), -d / 2 + 0.002, d / 2 - 0.002, 0.0105, 0.0105, shade(cloth, 0.82), seg=14)
    top = 0.0198
    if grid:                                                                                  # the grid or weave
        n = 9
        for i in range(n):
            label_band(f, (-w / 2 + 0.012 + i * (w - 0.024) / (n - 1), 0, top), (0.0012, d - 0.01, 0), grid, axis="z", sign=1)
        for j in range(5):
            label_band(f, (0, -d / 2 + 0.01 + j * (d - 0.02) / 4, top), (w - 0.02, 0.0012, 0), grid, axis="z", sign=1)
    if sheen:                                                                                 # a coated band of light
        label_band(f, (0.01, -0.012, top + 0.0001), (w - 0.03, 0.012, 0), shade(cloth, 1.25), axis="z", sign=1)
    if fluffy:                                                                                # tufts on the fleece
        for i in range(6):
            for j in range(3):
                f.box((-0.05 + i * 0.02 + (j % 2) * 0.008, -0.022 + j * 0.022, top - 0.0004), (0.012, 0.012, 0.0022), shade(cloth, 1.08), bevel=0.0009)
    I("rubber").box((0.03, 0, 0.011), (0.004, d + 0.004, 0.024), tie, bevel=0.0015)        # the cord


@item("FABRIC", 2, 1, view="three_q", margin=0.06)
def fabric_aramid(I):
    """aramid fiber fabric: a golden-yellow weave with a fine darker grid (redrawn at EFT's 2x1 in the fifteenth slice)"""
    folded(I, col("C8A43A"), grid=col("8A6E22"))


@item("FABRIC_POLY", 2, 1, view="three_q", margin=0.06)
def fabric_poly(I):
    """heavy coated polyamide canvas in olive drab, a sheen of its coating across the top"""
    folded(I, col("5A6448"), sheen=True, tie=col("1E201C"))


@item("FABRIC_RIPSTOP", 2, 1, view="three_q", margin=0.06)
def fabric_ripstop(I):
    """light khaki ripstop with its square reinforcing grid"""
    folded(I, col("8A8A68"), grid=col("5E5E44"))


@item("FABRIC_FLEECE", 2, 1, view="three_q", margin=0.06)
def fabric_fleece(I):
    """soft grey-brown fleece, its pile in tufts"""
    folded(I, col("8A8478"), fluffy=True, tie=col("3A3830"))


# ── the two other powder tins (the fine powder, EFT's "Kite", is build_items_h's olive tin) ──────────────────────────
def powder_tin(I, body, label, band):
    """a squat tin of smokeless powder standing up (build_items_h's shape in other colours): rounded body, rolled seams,
    a screw cap off to one side, a carrying lip, a stencilled label with a coloured band"""
    m, p, pl = I("metal"), I("paper"), I("plastic")
    w, d, h = 0.075, 0.05, 0.13
    m.box((0, 0, h / 2), (w, d, h), body, bevel=0.008)
    for z in (0.004, h - 0.004):
        m.box((0, 0, z), (w + 0.002, d + 0.002, 0.004), shade(body, 0.8), bevel=0.0015)
    lathe(m, [(0.0, h), (0.013, h), (0.013, h + 0.004)], shade(body, 0.7), seg=20, x=0.018)
    lathe(pl, [(0.0, h + 0.004), (0.0125, h + 0.004), (0.0125, h + 0.02), (0.0, h + 0.02)], col("2B2D27"), seg=20, x=0.018)
    for k in range(8):
        a = R(k * 45)
        pl.box((0.018 + 0.0128 * math.cos(a), 0.0128 * math.sin(a), h + 0.012), (0.002, 0.002, 0.014), col("1E201C"))
    m.box((-0.02, 0, h + 0.006), (0.026, 0.006, 0.012), shade(body, 0.75), bevel=0.002)
    label_band(p, (0, -d / 2 - 0.0006, 0.07), (0.058, 0, 0.034), label)
    label_band(p, (0, -d / 2 - 0.0009, 0.082), (0.058, 0, 0.006), band)
    for k, wl in enumerate((0.04, 0.03, 0.036)):
        label_band(p, (-0.006, -d / 2 - 0.0011, 0.068 - k * 0.008), (wl, 0, 0.003), col("2E3226"))


@item("POWDER_FLAKE", 1, 2, view="three_q", margin=0.1)
def powder_flake(I):
    powder_tin(I, col("6E3A30"), col("D8CFAE"), col("C8A43A"))


@item("POWDER_BALL", 1, 2, view="three_q", margin=0.1)
def powder_ball(I):
    powder_tin(I, col("3E5A3A"), col("D8D4C0"), col("2E4E8A"))


# ── tools ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("PLIERS_HD", 1, 1, view="top", margin=0.06)
def pliers_hd(I):
    """forged combination pliers lying open a little: polished jaws with a cutting edge, a big rivet, red and black
    two-tone grips with flared ends"""
    m, rb = I("metal"), I("rubber")
    for s in (-1, 1):
        m.box((s * 0.0055, 0.03, 0.006), (0.01, 0.046, 0.006), col("C8CCCA"), rot=(0, 0, R(s * -4)), bevel=0.001)   # the jaws
        m.box((s * 0.003, 0.046, 0.0062), (0.004, 0.012, 0.0062), col("8A8E8C"), rot=(0, 0, R(s * -4)))           # serrations
        rb.box((s * 0.017, -0.036, 0.006), (0.013, 0.074, 0.009), col("B83A2E"), rot=(0, 0, R(s * 9)), bevel=0.0035)  # grips
        rb.box((s * 0.0235, -0.072, 0.006), (0.016, 0.012, 0.011), col("1E2022"), rot=(0, 0, R(s * 9)), bevel=0.004)   # flared ends
        m.box((s * 0.0105, -0.002, 0.006), (0.011, 0.02, 0.007), col("B8BCBA"), rot=(0, 0, R(s * 8)))
    cyl_z(m, 0, 0.006, 0.002, 0.0115, 0.0075, col("D8DAD6"), seg=16)                         # the rivet


@item("CABLE_CUTTER", 1, 2, view="front", margin=0.06)
def cable_cutter(I):
    """long-handled ratchet cable cutters standing on their grips: a hooked steel jaw ring and its curved blade at the top,
    the ratchet plates and pivot, red rubber grips"""
    m, rb, g = I("metal"), I("rubber"), I("gunmetal")
    for s in (-1, 1):
        m.box((s * 0.01, 0, 0.1), (0.008, 0.008, 0.14), col("9A9E9C"), rot=(0, R(s * -4), 0), bevel=0.0015)        # the arms
        rb.box((s * 0.014, 0, 0.055), (0.016, 0.014, 0.1), col("C8442E"), rot=(0, R(s * -4), 0), bevel=0.005)        # grips
    g.box((0, 0, 0.178), (0.034, 0.012, 0.03), col("3A3E40"), bevel=0.002)                   # the ratchet plates
    cyl_y(m, 0, -0.008, 0.008, 0.178, 0.006, col("C8CCCA"), seg=16)                          # the pivot
    torus(g, (0, 0, 0.215), 0.024, 0.006, col("4A4E52"), axis="y", seg=24, rseg=8)          # the jaw ring
    m.box((0.006, 0, 0.226), (0.03, 0.004, 0.008), col("D8DCDA"), rot=(0, R(-35), 0))        # the blade


# ── building materials ─────────────────────────────────────────────────────────────────────────────────────────────
@item("FOAM_MOUNT", 1, 3, view="front", margin=0.08)
def foam_mount(I):
    """a tall can of mounting foam with a valve and a long straw nozzle bent down beside it (the sealing foam's can is a
    gun-type green one); a blue can, a white band"""
    m, p = I("metal"), I("plastic")
    lathe(m, [(0.0, 0.0), (0.031, 0.0), (0.032, 0.006), (0.032, 0.21), (0.025, 0.226), (0.011, 0.233)], col("3A6E9A"), seg=28)
    label_band(I("paper"), (0, -0.0325, 0.12), (0.05, 0, 0.09), col("E8E8E0"))
    label_band(I("paper"), (0, -0.0328, 0.14), (0.05, 0, 0.014), col("C8442E"))
    label_band(I("paper"), (0, -0.0328, 0.1), (0.036, 0, 0.004), col("2A2C2E"))
    lathe(p, [(0.0, 0.233), (0.009, 0.233), (0.009, 0.245), (0.0, 0.245)], col("E8E4D8"), seg=16)   # the valve cap
    p.tube([(0.0, -0.004, 0.243), (0.012, -0.012, 0.252), (0.04, -0.014, 0.24), (0.046, -0.014, 0.12)], 0.0025, col("E8E4D8"), seg=8)  # straw


@item("COLD_WELD", 1, 1, view="top_tilt", margin=0.08)
def cold_weld(I):
    """a twin tube of two-part epoxy on its card: two short tubes side by side, a grey one and a white one, joined caps,
    a plain card with a coloured band"""
    c, m, p = I("cardboard"), I("metal"), I("plastic")
    c.box((0, 0, 0.0006), (0.06, 0.08, 0.0012), col("E8E4D8"))                              # the card
    label_band(c, (0, 0.028, 0.0013), (0.06, 0.016, 0), col("2E4E8A"), axis="z", sign=1)
    for x, tube in ((-0.0085, col("7A7E80")), (0.0085, col("E8E8E0"))):
        cyl_y(m, x, -0.03, 0.02, 0.009, 0.0078, tube, seg=18)                                # the tubes
        cyl_y(m, x, 0.02, 0.024, 0.009, 0.0078, shade(tube, 0.8), seg=18, r2=0.003)          # their crimped shoulders
    p.box((0, -0.034, 0.009), (0.03, 0.008, 0.015), col("2A2C2E"), bevel=0.002)             # the joined caps


@item("INSUL_TAPE", 1, 1, view="three_q", margin=0.12)
def insul_tape(I):
    """a roll of blue electrical tape lying flat on its side: the wound tape, a cardboard core, the loose end lifting"""
    p, c = I("plastic"), I("cardboard")
    ri, ro, h = 0.0145, 0.026, 0.019
    lathe(p, [(ri, 0.0), (ro, 0.0), (ro, h), (ri, h), (ri, 0.0)], col("2E4E9A"), seg=32, cap_top=False, cap_bottom=False)
    lathe(c, [(ri - 0.0025, 0.0), (ri, 0.0), (ri, h), (ri - 0.0025, h), (ri - 0.0025, 0.0)], col("C8B88A"), seg=28, cap_top=False, cap_bottom=False)
    for k in range(3):                                                                        # the wound layers on top
        lathe(p, [(ri + 0.003 + k * 0.003, h + 0.0002), (ri + 0.0035 + k * 0.003, h + 0.0002)], shade(col("2E4E9A"), 0.8), seg=32,
              cap_top=False, cap_bottom=False)
    p.box((ro + 0.004, -0.012, h / 2), (0.006, 0.014, h), col("2E4E9A"), rot=(0, 0, R(30)))   # the loose end


# ── flammables ─────────────────────────────────────────────────────────────────────────────────────────────────────
@item("LIGHTER_WIND", 1, 1, view="three_q", margin=0.12)
def lighter_wind(I):
    """a brushed steel petrol lighter with its lid flipped open: the case, the chimney with its holes, the wick, the flint
    wheel and the hinge"""
    m, w = I("chrome"), I("fabric")
    m.box((0, 0, 0.019), (0.038, 0.013, 0.038), col("B8BAB6"), bevel=0.003)                 # the case
    m.box((-0.004, 0, 0.044), (0.022, 0.011, 0.012), col("A8AAA6"), bevel=0.0008)            # the chimney
    for i in range(3):
        for j in range(2):
            label_band(m, (-0.01 + i * 0.006, -0.0056, 0.041 + j * 0.005), (0.0028, 0, 0.0028), col("2A2C2E"))
    cyl_z(w, -0.004, 0, 0.05, 0.054, 0.002, col("E8E4D0"), seg=8)                            # the wick
    cyl_x(m, 0.009, 0.015, 0.0, 0.047, 0.0035, col("6A6C6E"), seg=14)                        # the flint wheel
    m.box((0.031, 0, 0.056), (0.012, 0.013, 0.03), col("B8BAB6"), rot=(0, R(-25), 0), bevel=0.003)  # the open lid
    cyl_y(m, 0.019, -0.006, 0.006, 0.038, 0.0016, col("8A8C8A"), seg=8)                      # the hinge


@item("MATCHES_HUNT", 1, 1, view="three_q", margin=0.1)
def matches_hunt(I):
    """a box of long stormproof matches, its tray slid out to show the matches with fat red heads, a striker strip on the
    side, two matches lying beside it"""
    c, w = I("cardboard"), I("wood")
    c.box((-0.006, 0, 0.0062), (0.068, 0.032, 0.0124), col("D8C8A8"), bevel=0.0005)          # the tray, slid out left
    c.box((0.012, 0, 0.008), (0.072, 0.036, 0.016), col("C86A2E"), bevel=0.0008)             # the sleeve
    label_band(c, (0.012, 0, 0.0162), (0.06, 0.022, 0), col("E8D8A8"), axis="z", sign=1)
    label_band(c, (0.012, -0.0182, 0.008), (0.066, 0, 0.01), col("4A3A2E"))                  # the striker
    for k in range(5):                                                                        # matches, heads showing
        cyl_x(w, -0.034, 0.03, -0.01 + k * 0.005, 0.0105, 0.0016, col("D8B888"), seg=8)
        cyl_x(w, -0.04, -0.034, -0.01 + k * 0.005, 0.0105, 0.0028, col("B83A2A"), seg=10)
    for k in range(2):                                                                        # two lying in front
        cyl_x(w, -0.03, 0.03, -0.026 - k * 0.006, 0.0018, 0.0016, col("D8B888"), seg=8)
        cyl_x(w, 0.03, 0.036, -0.026 - k * 0.006, 0.0018, 0.0028, col("B83A2A"), seg=10)


# ── household and medical ──────────────────────────────────────────────────────────────────────────────────────────
@item("BICARB", 1, 1, view="three_q", margin=0.1)
def bicarb(I):
    """a paper pack of baking soda standing up: white with a blue band and an orange stripe, the top folded and glued"""
    c = I("paper")
    c.box((0, 0, 0.042), (0.055, 0.035, 0.084), col("E8E4D8"), bevel=0.0012)
    label_band(c, (0, -0.0176, 0.045), (0.055, 0, 0.026), col("2E5A9A"))
    label_band(c, (0, -0.0179, 0.03), (0.055, 0, 0.004), col("D8742E"))
    label_band(c, (0, -0.0179, 0.065), (0.03, 0, 0.004), col("2A2C2E"))
    c.box((0, 0, 0.0855), (0.05, 0.03, 0.003), col("D8D4C8"), bevel=0.0008)                 # the folded top
    label_band(c, (0, 0, 0.0871), (0.05, 0.004, 0), col("C8C4B8"), axis="z", sign=1)         # its glued seam


@item("SHAMPOO", 1, 2, view="front", margin=0.1)
def shampoo(I):
    """a tall green bottle of herbal shampoo with a white flip cap and a cream label with a leaf-green band"""
    p = I("plastic")
    lathe(p, [(0.0, 0.0), (0.026, 0.0), (0.028, 0.006), (0.028, 0.15), (0.024, 0.17), (0.012, 0.178)], col("4A8A5A"), seg=24)
    lathe(p, [(0.0, 0.178), (0.0135, 0.178), (0.0135, 0.2), (0.0, 0.2)], col("E8E8E0"), seg=20)      # the cap
    p.box((0, -0.008, 0.2), (0.012, 0.01, 0.003), col("D8D8D0"))                            # its flip lid
    lathe(I("paper"), [(0.0284, 0.04), (0.0284, 0.12)], col("E8E0C8"), seg=24, cap_top=False, cap_bottom=False)  # the label
    label_band(I("paper"), (0, -0.0288, 0.095), (0.034, 0, 0.012), col("2E6A3A"))
    label_band(I("paper"), (0, -0.0288, 0.07), (0.026, 0, 0.003), col("4A3A2E"))


@item("MULTIVITAMINS", 1, 1, view="three_q", margin=0.1)
def multivitamins(I):
    """a round plastic tub of tablets: orange with a white ribbed screw cap and a white label band"""
    p = I("plastic")
    lathe(p, [(0.0, 0.0), (0.024, 0.0), (0.025, 0.004), (0.025, 0.05), (0.022, 0.054)], col("E8A030"), seg=28)
    lathe(p, [(0.0, 0.054), (0.0235, 0.054), (0.0235, 0.068), (0.0, 0.068)], col("F0F0E8"), seg=28)  # the cap
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.box((0.0237 * math.cos(a), 0.0237 * math.sin(a), 0.061), (0.0015, 0.0015, 0.012), col("D8D8D0"), rot=(0, 0, a))
    lathe(I("paper"), [(0.0254, 0.012), (0.0254, 0.042)], col("F0F0E8"), seg=28, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0258, 0.027), (0.03, 0, 0.008), col("C8442E"))


@item("PEROXIDE", 1, 1, view="front", margin=0.1)
def peroxide(I):
    """a small brown bottle with a white screw cap and a white label"""
    p = I("plastic")
    lathe(p, [(0.0, 0.0), (0.018, 0.0), (0.019, 0.004), (0.019, 0.055), (0.014, 0.064), (0.008, 0.068)], col("5A3A2A"), seg=24)
    lathe(p, [(0.0, 0.068), (0.0095, 0.068), (0.0095, 0.082), (0.0, 0.082)], col("F0F0E8"), seg=18)
    lathe(I("paper"), [(0.0194, 0.014), (0.0194, 0.045)], col("F0F0E8"), seg=24, cap_top=False, cap_bottom=False)
    label_band(I("paper"), (0, -0.0198, 0.03), (0.022, 0, 0.005), col("2E4E8A"))


# ── provisions ─────────────────────────────────────────────────────────────────────────────────────────────────────
@item("COFFEE_BEANS", 1, 1, view="three_q", margin=0.1)
def coffee_beans(I):
    """a vacuum tin of coffee beans with a gold band and a clear lid, three roasted beans in front of it"""
    m, p = I("metal"), I("plastic")
    lathe(m, [(0.0, 0.0), (0.03, 0.0), (0.031, 0.004), (0.031, 0.066), (0.03, 0.07)], col("4A2A1A"), seg=28)
    lathe(m, [(0.0312, 0.026), (0.0312, 0.046)], col("C8A040"), seg=28, cap_top=False, cap_bottom=False)   # the band
    lathe(p, [(0.0, 0.07), (0.031, 0.07), (0.031, 0.076), (0.0, 0.076)], col("8A6A4A"), seg=28)          # the lid
    for k, (x, y) in enumerate(((0.02, -0.04), (0.032, -0.03), (0.008, -0.045))):           # beans
        b = I("wood")
        b.box((x, y, 0.004), (0.011, 0.008, 0.007), col("5A321E"), rot=(0, 0, R(30 * k)), bevel=0.0025)
        label_band(b, (x, y, 0.0076), (0.0012, 0.007, 0), col("2A1A10"), axis="z", sign=1)


@item("SUGAR", 1, 1, view="three_q", margin=0.1)
def sugar(I):
    """a paper pack of white sugar standing up with a blue band, two sugar cubes in front of it"""
    c, k = I("paper"), I("ceramic")
    c.box((0, 0, 0.045), (0.06, 0.04, 0.09), col("F0F0EC"), bevel=0.0012)
    label_band(c, (0, -0.0201, 0.05), (0.06, 0, 0.03), col("2E4E9A"))
    for i in range(3):                                                                        # cubes printed on the band
        label_band(c, (-0.014 + i * 0.014, -0.0204, 0.05), (0.008, 0, 0.008), col("F0F0EC"))
    c.box((0, 0, 0.0915), (0.056, 0.036, 0.003), col("E0E0DC"), bevel=0.0008)
    for x, y in ((0.018, -0.036), (0.03, -0.028)):                                           # the cubes
        k.box((x, y, 0.005), (0.01, 0.01, 0.01), col("F4F4F0"), rot=(0, 0, R(20)), bevel=0.0008)


# ── info and valuables: the other books ────────────────────────────────────────────────────────────────────────────
@item("OPTO_TEXTBOOK", 1, 2, view="front", margin=0.08)
def opto_textbook(I):
    """a thick violet textbook: a white title band, a light path through a lens drawn on the cover, a band at the foot"""
    cover = col("5A2E6A")
    y = book(I, 0.17, 0.05, 0.245, cover, spine=col("44224F"))
    pa = I("paper")
    label_band(pa, (0.004, y - 0.0002, 0.208), (0.13, 0, 0.026), WHITE)                     # the title band
    label_band(pa, (0.004, y - 0.0005, 0.208), (0.1, 0, 0.006), cover)                      # the title
    pa.cyl((0.004, y - 0.0003, 0.12), (0.004, y - 0.0012, 0.12), 0.026, col("C8B8E8"), seg=28)   # the lens
    pa.cyl((0.004, y - 0.0012, 0.12), (0.004, y - 0.0018, 0.12), 0.018, col("A898D0"), seg=24)
    for k in (-1, 0, 1):                                                                      # the rays
        label_band(pa, (-0.04, y - 0.0004, 0.12 + k * 0.012), (0.05, 0, 0.0018), col("E8D84A"))
        label_band(pa, (0.048, y - 0.0004, 0.12 + k * 0.005), (0.05, 0, 0.0018), col("E8D84A"))
    label_band(pa, (0.004, y - 0.0002, 0.026), (0.15, 0, 0.012), col("C8A43A"))             # the band at the foot


@item("DIARY", 1, 2, view="front", margin=0.08)
def diary(I):
    """a brown leather hardback diary closed by an elastic band, a ribbon marker hanging from the foot"""
    cover = col("6A4A2E")
    y = book(I, 0.15, 0.03, 0.21, cover, spine=col("5A3E26"))
    rb = I("rubber")
    rb.box((0.05, 0, 0.105), (0.008, 0.032, 0.212), col("1E1A16"))                          # the elastic band
    I("fabric").box((-0.02, -0.004, -0.012), (0.006, 0.001, 0.03), col("8A2E2A"))           # the ribbon
    for s in (-1, 1):                                                                         # embossed corners
        label_band(I("leather"), (0.004 + s * 0.055, y - 0.0003, 0.19), (0.02, 0, 0.02), shade(cover, 0.8))


@item("SLIM_DIARY", 1, 1, view="top_tilt", margin=0.08)
def slim_diary(I):
    """a thin pocket diary lying flat: a worn dark leather cover with rounded corners, a strap with a press stud, the page
    edges along one side"""
    lt, pg, m = I("leather"), I("paper"), I("metal")
    lt.box((0, 0, 0.0045), (0.062, 0.092, 0.009), col("3A2A22"), bevel=0.0025)
    pg.box((0.002, 0, 0.0045), (0.058, 0.088, 0.0066), col("E8E0C8"))                       # the page block
    lt.box((0.024, 0, 0.0092), (0.016, 0.094, 0.0012), col("2A1E18"))                       # the strap over the top
    cyl_z(m, 0.028, -0.03, 0.0098, 0.0112, 0.004, col("B8A060"), seg=14)                     # the press stud
    label_band(lt, (-0.012, 0.02, 0.0091), (0.02, 0.03, 0), shade(col("3A2A22"), 1.25), axis="z", sign=1)  # worn patch


@item("TECH_MANUAL", 1, 2, view="front", margin=0.08)
def tech_manual(I):
    """a ring-bound service manual standing up: a pale yellow card cover with a wiring diagram, an oil smudge, black rings
    through the spine"""
    c, pg = I("cardboard"), I("paper")
    w, t, h = 0.16, 0.02, 0.23
    c.box((0, -t / 2 + 0.001, h / 2), (w, 0.002, h), col("D8C878"), bevel=0.0008)           # the front cover
    c.box((0, t / 2 - 0.001, h / 2), (w, 0.002, h), col("C8B868"), bevel=0.0008)            # the back cover
    pg.box((0.004, 0, h / 2), (w - 0.012, t - 0.004, h - 0.006), col("EDE6D2"))             # the pages
    for k in range(9):                                                                        # the rings
        torus(I("plastic"), (-w / 2 + 0.004, 0, 0.022 + k * 0.023), 0.008, 0.0018, col("1E2022"), axis="z", seg=14, rseg=6)
    y = -t / 2 - 0.0002
    ink = col("2A2C2E")
    label_band(pg, (0.01, y, 0.2), (0.11, 0, 0.012), ink)                                    # the title block
    for (x, z, sw, sz) in ((-0.02, 0.13, 0.06, 0.0015), (0.03, 0.13, 0.0015, 0.05), (0.0, 0.105, 0.06, 0.0015),
                           (-0.02, 0.085, 0.0015, 0.04), (0.04, 0.08, 0.03, 0.0015)):        # the diagram
        label_band(pg, (x, y, z), (sw, 0, sz), ink)
    for (x, z) in ((-0.05, 0.13), (0.03, 0.105), (0.055, 0.08)):
        label_band(pg, (x, y, z), (0.008, 0, 0.008), ink)
    label_band(pg, (0.045, y - 0.0002, 0.05), (0.04, 0, 0.03), shade(col("D8C878"), 0.62))   # the oil smudge


@item("ANTIQUE_BOOK", 1, 2, view="front", margin=0.08)
def antique_book(I):
    """an old leather-bound book: dark red-brown boards with a gilt border, raised bands across the spine, corners worn
    to the pale board beneath"""
    cover = col("5A2A1E")
    y = book(I, 0.15, 0.045, 0.22, cover, spine=col("4A2218"))
    g, lt = I("gold"), I("leather")
    for z in (0.012, 0.208):                                                                  # the gilt border
        label_band(g, (0.004, y - 0.0003, z), (0.13, 0, 0.003), col("C8A040"))
    for x in (-0.06, 0.068):
        label_band(g, (x, y - 0.0003, 0.11), (0.003, 0, 0.196), col("C8A040"))
    label_band(g, (0.004, y - 0.0004, 0.15), (0.05, 0, 0.03), col("B89038"))                # the title plate
    for k in range(4):                                                                        # raised bands on the spine
        lt.box((-0.0755, 0, 0.05 + k * 0.04), (0.003, 0.047, 0.006), shade(cover, 0.7), bevel=0.001)
    for x, z in ((0.07, 0.212), (0.07, 0.008)):                                               # worn corners
        label_band(lt, (x, y - 0.0005, z), (0.012, 0, 0.012), col("A88A68"))


EXTRA = ["DISC_DRIVE", "PC_CPU", "LCD_PANEL", "LCD_BROKEN", "GAME_CONSOLE", "FPGA_CHIP", "STORAGE_MODULE", "GAS_ANALYSER",
         "FABRIC", "FABRIC_POLY", "FABRIC_RIPSTOP", "FABRIC_FLEECE", "POWDER_FLAKE", "POWDER_BALL", "PLIERS_HD",
         "CABLE_CUTTER", "FOAM_MOUNT", "COLD_WELD", "INSUL_TAPE", "LIGHTER_WIND", "MATCHES_HUNT", "BICARB", "SHAMPOO",
         "MULTIVITAMINS", "PEROXIDE", "COFFEE_BEANS", "SUGAR", "OPTO_TEXTBOOK", "DIARY", "SLIM_DIARY", "TECH_MANUAL",
         "ANTIQUE_BOOK"]

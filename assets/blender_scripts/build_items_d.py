"""Zero Return - item models D: ballistic plates (decision gameplay-2a). Original designs, no maker's marks: a cut plate
(the top corners cut away for the arms, SAPI-like), a taller plate with deeper cuts for the Russian-style carriers
(Korund-like) and small side plates, in three finishes: polyethylene (an off-white slab with a printed label),
ceramic (in a dark nylon cover with a white label) and steel (dark anti-spall coating, a stencilled band). The
class is not painted on: the tile's short name carries it (KITE III, BASALT V). Modelled in metres, standing up with
the strike face toward -Y (front views); the inventory sizes are 2 x 3 (front and back) and 1 x 2 (side).
"""
from mathutils import Matrix
from zr_items import col, shade, label_band, R
from zr_item_reg import item

PE = col("E6E2D4")       # polyethylene: off-white
PE_GREY = col("D2CFC6")
LABEL = col("E8E6DE")
INK = col("2A2B28")


def cut_plate(w=0.25, h=0.32, cx=0.055, cz=0.075):
    """the front or back plate's outline (x across, z up), counter-clockwise from the front: top corners cut"""
    return [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, h - cz), (w / 2 - cx, h), (-w / 2 + cx, h), (-w / 2, h - cz)]


def tall_plate(w=0.26, h=0.37):
    """a taller chest plate, the top corners cut deep and the bottom ones a little"""
    return [(-w / 2 + 0.02, 0.0), (w / 2 - 0.02, 0.0), (w / 2, 0.03), (w / 2, h - 0.095), (w / 2 - 0.07, h),
            (-w / 2 + 0.07, h), (-w / 2, h - 0.095), (-w / 2, 0.03)]


def side_plate(w=0.15, h=0.2, c=0.018):
    return [(-w / 2 + c, 0.0), (w / 2 - c, 0.0), (w / 2, c), (w / 2, h - c), (w / 2 - c, h), (-w / 2 + c, h),
            (-w / 2, h - c), (-w / 2, c)]


def slab(I, mat, outline, t, color, bevel=0.003):
    """the plate body: the outline extruded t thick (the prism runs along x; the item is turned at the end)"""
    I(mat).prism([(x, z) for x, z in outline], -t / 2, t / 2, color, bevel=bevel)


def face_label(I, mat, t, x, z, w, h, color):
    """a flat label on the strike face (before the turn the face looks toward -X)"""
    label_band(I(mat), (-t / 2, x, z), (0, w, h), color, axis="x", sign=-1)


def finish(I):
    # turn the plate so its face looks toward -Y (prism profile y -> world -x, thickness x -> world y)
    I.transform(Matrix.Rotation(R(90), 4, "Z"))


def pe_plate(I, outline, t, band, grey=False):
    w = max(x for x, _ in outline) * 2
    h = max(z for _, z in outline)
    slab(I, "plastic", outline, t, PE_GREY if grey else PE, bevel=min(0.004, t * 0.3))
    face_label(I, "paper", t, 0.0, h * 0.42, w * 0.5, h * 0.3, LABEL)
    face_label(I, "paper", t + 0.0012, 0.0, h * 0.52, w * 0.5, h * 0.05, band)      # the coloured band on the label
    face_label(I, "paper", t + 0.0012, 0.0, h * 0.36, w * 0.36, h * 0.025, INK)     # a line of print
    face_label(I, "paper", t + 0.0012, 0.0, h * 0.32, w * 0.3, h * 0.02, INK)
    finish(I)


def ceramic_plate(I, outline, t, cover):
    w = max(x for x, _ in outline) * 2
    h = max(z for _, z in outline)
    slab(I, "fabric", outline, t, cover, bevel=min(0.006, t * 0.35))
    face_label(I, "paper", t, 0.0, h * 0.6, w * 0.46, h * 0.2, LABEL)
    face_label(I, "paper", t + 0.0012, 0.0, h * 0.64, w * 0.36, h * 0.025, INK)
    face_label(I, "paper", t + 0.0012, 0.0, h * 0.58, w * 0.3, h * 0.02, INK)
    # the cover's stitched seam a little inside the edge, low on the face
    face_label(I, "fabric", t, 0.0, h * 0.1, w * 0.8, 0.004, shade(cover, 0.7))
    finish(I)


def steel_plate(I, outline, t, coat):
    w = max(x for x, _ in outline) * 2
    h = max(z for _, z in outline)
    slab(I, "rubber", outline, t, coat, bevel=min(0.003, t * 0.3))
    face_label(I, "paper", t, 0.0, h * 0.7, w * 0.5, h * 0.045, col("C9C3AE"))     # a stencilled band
    face_label(I, "paper", t, 0.0, h * 0.62, w * 0.3, h * 0.03, col("C9C3AE"))
    finish(I)


# ── the western-cut plates (front or back) ──────────────────────────────────────
@item("PLATE_PE3", 2, 3, view="front_hi", margin=0.12)
def plate_pe3(I):
    pe_plate(I, cut_plate(), 0.012, col("5E7A4A"))


@item("PLATE_PE4", 2, 3, view="front_hi", margin=0.12)
def plate_pe4(I):
    pe_plate(I, cut_plate(), 0.02, col("3E5E86"))


@item("PLATE_PE5", 2, 3, view="front_hi", margin=0.12)
def plate_pe5(I):
    pe_plate(I, cut_plate(), 0.024, col("9A3A2E"), grey=True)


@item("PLATE_PE6", 2, 3, view="front_hi", margin=0.12)
def plate_pe6(I):
    pe_plate(I, cut_plate(), 0.03, col("2B2C2A"))


@item("PLATE_CE4", 2, 3, view="front_hi", margin=0.12)
def plate_ce4(I):
    ceramic_plate(I, cut_plate(), 0.022, col("666A55"))


@item("PLATE_CE5", 2, 3, view="front_hi", margin=0.12)
def plate_ce5(I):
    ceramic_plate(I, cut_plate(), 0.025, col("44453F"))


@item("PLATE_CE6", 2, 3, view="front_hi", margin=0.12)
def plate_ce6(I):
    ceramic_plate(I, cut_plate(), 0.03, col("8C7C5A"))


@item("PLATE_CE5S", 1, 2, view="front_hi", margin=0.12)
def plate_ce5s(I):
    ceramic_plate(I, side_plate(), 0.022, col("44453F"))


# ── the Russian-style carriers' own plates ──────────────────────────────────────
@item("PLATE_PC4F", 2, 3, view="front_hi", margin=0.12)
def plate_pc4f(I):
    steel_plate(I, tall_plate(), 0.01, col("5C6250"))


@item("PLATE_PC4B", 2, 3, view="front_hi", margin=0.12)
def plate_pc4b(I):
    steel_plate(I, cut_plate(), 0.01, col("5C6250"))


@item("PLATE_HP5F", 2, 3, view="front_hi", margin=0.12)
def plate_hp5f(I):
    steel_plate(I, tall_plate(), 0.012, col("474B42"))


@item("PLATE_HP5B", 2, 3, view="front_hi", margin=0.12)
def plate_hp5b(I):
    steel_plate(I, cut_plate(), 0.012, col("474B42"))


@item("PLATE_HP5S", 1, 2, view="front_hi", margin=0.12)
def plate_hp5s(I):
    steel_plate(I, side_plate(), 0.01, col("474B42"))


@item("PLATE_BWF", 2, 3, view="front_hi", margin=0.12)
def plate_bwf(I):
    ceramic_plate(I, cut_plate(0.26, 0.34), 0.032, col("505750"))


@item("PLATE_BWB", 2, 3, view="front_hi", margin=0.12)
def plate_bwb(I):
    ceramic_plate(I, cut_plate(0.26, 0.34), 0.032, col("505750"))


@item("PLATE_BWS", 1, 2, view="front_hi", margin=0.12)
def plate_bws(I):
    ceramic_plate(I, side_plate(0.16, 0.21), 0.024, col("505750"))


PLATES = ["PLATE_PE3", "PLATE_PE4", "PLATE_PE5", "PLATE_PE6", "PLATE_CE4", "PLATE_CE5", "PLATE_CE6", "PLATE_CE5S",
          "PLATE_PC4F", "PLATE_PC4B", "PLATE_HP5F", "PLATE_HP5B", "PLATE_HP5S", "PLATE_BWF", "PLATE_BWB", "PLATE_BWS"]


def pack_extra(ids, sheet_name):
    """add the ids' icons to atlas.json on sheet `sheet_name`, leaving the other uploaded sheets as they are: a new
    sheet, or that sheet packed again with the icons it already held (it must then be uploaded again)"""
    import os, json
    import numpy as np
    import bpy
    import zr_items
    path = os.path.join(zr_items.OUT, "atlas.json")
    with open(path) as f:
        atlas = json.load(f)
    cell, size, pad = atlas["cell"], atlas["size"], atlas.get("pad", 2)
    from zr_item_reg import REG
    fname = sheet_name + ".png"
    sizes = {i: (REG[i]["w"], REG[i]["h"]) for i in ids}
    if fname in atlas["sheets"]:
        idx = atlas["sheets"].index(fname)
        for k, e in list(atlas["items"].items()):
            if e["sheet"] == idx:
                sizes.setdefault(k, (e["w"] // cell, e["h"] // cell))
                del atlas["items"][k]
    else:
        idx = len(atlas["sheets"])
        atlas["sheets"].append(fname)
    entries = sorted([(i, w, h) for i, (w, h) in sizes.items()], key=lambda e: (-e[2], -e[1], e[0]))
    sheet = np.zeros((size, size, 4), dtype=np.float32)
    x, y, shelf = pad, pad, 0
    for iid, w, h in entries:
        pw, ph = w * cell, h * cell
        if x + pw + pad > size:
            x, y, shelf = pad, y + shelf, 0
        assert y + ph + pad <= size, "the extra sheet is full"
        px = zr_items._load_scaled(os.path.join(zr_items.OUT, iid + ".png"), pw, ph)
        y0 = size - y - ph
        sheet[y0:y0 + ph, x:x + pw, :] = px
        atlas["items"][iid] = {"sheet": idx, "x": x, "y": y, "w": pw, "h": ph}
        x += pw + pad
        shelf = max(shelf, ph + pad)
    img = bpy.data.images.new(sheet_name, size, size, alpha=True)
    img.pixels[:] = sheet.ravel()
    out = os.path.join(zr_items.OUT, sheet_name + ".png")
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    with open(path, "w") as f:
        json.dump(atlas, f, indent=1, sort_keys=True)
    return out, idx

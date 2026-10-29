"""Zero Return - item models B: worn equipment (helmets, headwear, headsets, face cover, armour, rigs, packs) and
the secure containers. Worn items render the same Blender meshes the characters wear (build_char_gear.py and
helmet A from build_char_base.py), tinted with the item's colour from Equipment.luau, so the inventory picture is
what you see on a player. Their pieces are made under new names (ZR_IT_<ITEM>__g<n>); the character batches in
the file are left alone.
"""
import os, math
import bpy
from mathutils import Vector, Matrix
from zr_items import col, mixc, shade, rbox, label_band, cyl_x, cyl_y, cyl_z, R
from zr_item_reg import item

HERE = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts")
_GEAR = None


def gear_ns():
    """the equipment builders without running their export"""
    global _GEAR
    if _GEAR is None:
        g = {"ZR_NO_EXPORT": True, "__name__": "zr_gear_ns"}
        exec(open(os.path.join(HERE, "build_char_gear.py")).read(), g)
        src = open(os.path.join(HERE, "build_char_base.py")).read()
        gb = {"__name__": "zr_base_ns"}
        exec(src[:src.index("\ndef build(scene)")], gb)
        g["PIECE_FN"] = dict(g["PIECES"])
        g["PIECE_FN"]["ZR_EQ_HelmetA"] = gb["helmet_a"]
        _GEAR = g
    return _GEAR


def tint(o, hexcol):
    """multiply the sRGB vertex colours by the item colour, as MeshPart.Color does in game"""
    t = col(hexcol)
    a = o.data.color_attributes.get("Col")
    if not a:
        return
    for d in a.data:
        c = d.color
        d.color = (c[0] * t[0], c[1] * t[1], c[2] * t[2], c[3])


def gear(coll, item_id, parts):
    """parts: [(piece, tint, render material, offset (Blender x, y, z) or None, mirror x)]"""
    g = gear_ns()
    objs = []
    for k, p in enumerate(parts):
        piece, hexcol, mat = p[0], p[1], p[2]
        off = p[3] if len(p) > 3 else None
        mirror = p[4] if len(p) > 4 else False
        b = g["CB"]("ZR_IT_%s__g%d" % (item_id, k))
        g["PIECE_FN"][piece](b)
        if mirror:
            b.transform(Matrix.Scale(-1, 4, (1, 0, 0)))
            import bmesh
            bmesh.ops.reverse_faces(b.bm, faces=b.bm.faces[:])
        if off:
            b.transform(Matrix.Translation(off))
        o = b.finish(coll)
        tint(o, hexcol)
        o["zr_mat"] = mat
        objs.append(o)
    return objs


BACK_VIEW = (0.5, 0.88, 0.36)  # packs: their outer face is toward +Y (the wearer's back)


def wearable(item_id, w, h, parts, view="three_q", margin=0.08):
    @item(item_id, w, h, view=view, margin=margin, raw=True)
    def fn(coll):
        return gear(coll, item_id, parts)
    return fn


# helmets and headwear (three-quarter front view)
wearable("HELMET_C2", 2, 2, [("ZR_EQ_HelmetB", "55593F", "polymer")])
wearable("HELMET_C3", 2, 2, [("ZR_EQ_HelmetA", "4F5340", "polymer")])
wearable("HELMET_C4", 2, 2, [("ZR_EQ_HelmetA", "3B3F36", "polymer")])
wearable("HELMET_C5", 2, 2, [("ZR_EQ_HelmetB", "34372F", "polymer"), ("ZR_EQ_FacePlate", "4A4D4A", "metal")])
wearable("HARDHAT_FOREMAN", 2, 2, [("ZR_EQ_HardHat", "D4A93A", "plastic")])
wearable("CAP_FIELD", 2, 1, [("ZR_EQ_Cap", "4A4A3E", "fabric")], view="front_hi", margin=0.06)
wearable("BEANIE", 1, 1, [("ZR_EQ_Beanie", "3A3833", "fabric")])
wearable("HEADSET_GS1", 2, 1, [("ZR_EQ_Headset", "3A3D36", "polymer")], view="front_hi", margin=0.06)
wearable("HEADSET_COMM", 2, 1, [("ZR_EQ_Headset", "2A2C2E", "polymer"), ("ZR_EQ_BoomMic", "2A2C2E", "polymer")], view="front_hi", margin=0.06)
wearable("GAITER", 1, 1, [("ZR_EQ_Mask", "6B6B5E", "fabric")], view="front")

# body armour and rigs (front view)
wearable("ARMOR_C2", 3, 3, [("ZR_EQ_SoftVest", "2E3540", "fabric")], view="front")
wearable("ARMOR_C3", 3, 3, [("ZR_EQ_SoftVest", "4A5242", "fabric")], view="front")
wearable("ARMOR_C4", 3, 3, [("ZR_EQ_CarrierA", "575A47", "fabric")], view="front")
wearable("ARMOR_C5", 3, 3, [("ZR_EQ_CarrierA", "4D4F45", "fabric"), ("ZR_EQ_ArmorCollar", "4D4F45", "fabric")], view="front")
wearable("ARMOR_C6", 4, 4, [("ZR_EQ_CarrierA", "3E423D", "fabric"), ("ZR_EQ_ArmorCollar", "3E423D", "fabric"),
                            ("ZR_EQ_ArmGuard", "3E423D", "fabric", (1.42, 0.05, 0.42)),
                            ("ZR_EQ_ArmGuard", "3E423D", "fabric", (-1.42, 0.05, 0.42), True)], view="front")
wearable("RIG_BELT", 2, 2, [("ZR_EQ_BeltRig", "5E5A47", "fabric")], view=BACK_VIEW)
wearable("RIG_CHEST", 2, 2, [("ZR_EQ_ChestRig", "5A5844", "fabric")], view="front")
wearable("RIG_PLATE", 3, 3, [("ZR_EQ_CarrierA", "4F513F", "fabric"), ("ZR_EQ_CarrierPouches", "4F513F", "fabric")], view="front")

# packs (from behind, their outer face; the shoulder straps are left off the picture)
wearable("BAG_SLING", 2, 2, [("ZR_EQ_PackSmall", "6B6A4E", "fabric")], view=BACK_VIEW)
wearable("CANVAS_BAG", 3, 3, [("ZR_EQ_PackCanvas", "7A7458", "fabric")], view=BACK_VIEW)
wearable("BAG_PATROL", 4, 4, [("ZR_EQ_PackA", "5C5B44", "fabric")], view=BACK_VIEW)
wearable("BAG_RAID", 5, 5, [("ZR_EQ_PackRaid", "53523F", "fabric")], view=BACK_VIEW)


# ── secure containers (own models) ─────────────────────────────────────────────
NYLON = col("3B3F3F")
ZIP = col("1E2020")


def zipper(b, pts, color=ZIP):
    b.tube(pts, 0.0035, color, seg=6, smooth=True)


def pouch(I, w, h, d, color, lock=True, molle=True):
    f, m = I("fabric"), I("metal")
    f.box((0, 0, h / 2), (w, d, h), color, bevel=min(w, d, h) * 0.18)
    f.box((0, -d / 2 + 0.004, h * 0.62), (w * 0.86, 0.012, h * 0.5), shade(color, 1.08), bevel=0.01)  # front flap
    zipper(f, [(-w / 2 + 0.02, -d * 0.22, h - 0.003), (w / 2 - 0.02, -d * 0.22, h - 0.003)])
    zipper(f, [(-w / 2 + 0.012, -d / 2 + 0.002, h * 0.86), (w / 2 - 0.012, -d / 2 + 0.002, h * 0.86)])
    if molle:
        for k in range(3):
            f.box((0, -d / 2 - 0.004, h * 0.22 + k * h * 0.11), (w * 0.8, 0.006, 0.018), shade(color, 0.86), bevel=0.003)
    if lock:
        m.box((w * 0.18, -d / 2 - 0.012, h * 0.84), (0.026, 0.012, 0.03), col("8C9290"), bevel=0.003)
        m.torus((w * 0.18, -d / 2 - 0.012, h * 0.84 + 0.022), 0.011, 0.003, col("B8B8B0"), segU=12, segV=5, rot=(R(90), 0, 0))
        m.box((w * 0.18, -d / 2 - 0.019, h * 0.84), (0.012, 0.002, 0.012), col("2A2C2C"))  # keyhole plate
    for x in (-w * 0.3, w * 0.3):  # zip pullers
        m.box((x, -d * 0.22, h + 0.004), (0.006, 0.02, 0.004), col("8C9290"), bevel=0.001)


@item("SECURE_S", 2, 2, view="three_q", margin=0.08)
def secure_s(I):
    pouch(I, 0.16, 0.13, 0.07, NYLON)


@item("SECURE_M", 3, 3, view="three_q", margin=0.08)
def secure_m(I):
    pouch(I, 0.24, 0.2, 0.09, col("39403E"))


@item("SECURE_L", 3, 4, view="three_q", margin=0.08)
def secure_l(I):
    p, m = I("plastic"), I("metal")
    case = col("2E3333")
    p.box((0, 0, 0.17), (0.24, 0.1, 0.34), case, bevel=0.018)
    p.box((0, 0, 0.17), (0.244, 0.104, 0.012), shade(case, 0.8), bevel=0.004)  # lid seam
    for k in range(4):  # ribs
        p.box((0, -0.051, 0.05 + k * 0.08), (0.2, 0.004, 0.012), shade(case, 1.15), bevel=0.002)
    for x in (-0.08, 0.08):  # latches
        m.box((x, -0.054, 0.2), (0.04, 0.012, 0.045), col("8C9290"), bevel=0.003)
        m.box((x, -0.061, 0.2), (0.028, 0.004, 0.012), col("5A5E5C"))
    p.tube([(-0.05, 0, 0.34), (-0.05, 0, 0.37), (0.05, 0, 0.37), (0.05, 0, 0.34)], 0.009, col("1E2020"), seg=8)  # handle
    m.box((0.0, -0.053, 0.27), (0.03, 0.008, 0.03), col("B89A4A"), bevel=0.002)  # lock
    label_band(I("paper"), (0.0, -0.0525, 0.1), (0.1, 0, 0.03), col("C9C2A8"))

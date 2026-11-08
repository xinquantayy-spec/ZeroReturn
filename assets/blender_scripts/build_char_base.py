"""Zero Return - M16 character base batch: block body (15 R15-named segments, body version ZR_BLOCK_R15_V1),
helmet A and a labelled calibration cube. Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_char_base.py").read(), g)
Reads rig_spec.json (tools/rig_def.py). Every body segment is fitted to exactly its rig part box, so the game
sets MeshPart.Size = RigSpec size. Body proportions follow the owner's block-body reference; clothing detail
(jacket yoke, collar, zip, chest pockets, hem, belt, sleeve cuffs, elbow and knee reinforcement, cargo pockets,
gloves, boots with soles and laces) is modelled in neutral greys so MeshPart.Color tints each outfit.
Equipment (helmet A) is authored in its host part's local space (origin = host centre).
Exports assets/exports/ZR_CharBase.fbx (+ .blend + .meta.json) in its own scene "ZR_CharBase".
"""
import json, math, os, sys
HERE = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts")
sys.path.insert(0, HERE)
import importlib, zr_lib, zr_char
importlib.reload(zr_lib)
importlib.reload(zr_char)
from zr_lib import hexc, grey, batch_scene, export_batch
from zr_char import CB, lerp_table

SPEC = json.load(open(os.path.join(HERE, "rig_spec.json")))
assert SPEC.get("bodyVersion") == "ZR_BLOCK_R15_V1", SPEC.get("bodyVersion")

CLOTH, LIGHT, MID, DARK, SEAM = grey(0.86), grey(0.93), grey(0.72), grey(0.5), grey(0.3)
METAL = grey(0.8)
SKIN = grey(0.92)
EYE = hexc("141414")
GLOVE, KNUCK = grey(0.86), grey(0.6)
SOLE, LACE = grey(0.32), grey(0.97)


def upper_torso(b, s):
    w, h, d = s
    b.rround((0, -0.03, 0), (w * 0.985, h * 0.96, d * 0.95), CLOTH, r=0.13, segs=2)            # jacket body
    b.rround((0, h / 2 - 0.13, 0), (w, 0.26, d), CLOTH, r=0.12, segs=2)                         # padded yoke
    b.rround((0, h / 2 - 0.05, 0.02), (0.92, 0.1, 0.8), DARK, r=0.04, segs=1)                   # collar ring
    b.rround((0, -h / 2 + 0.08, 0), (w, 0.16, d), MID, r=0.06, segs=1)                          # hem band
    b.rbox((0, -0.06, -d * 0.475 - 0.008), (0.05, h * 0.82, 0.02), SEAM)                        # zip
    for sx in (-1, 1):
        b.rround((sx * 0.52, 0.18, -d * 0.475 - 0.02), (0.5, 0.42, 0.05), LIGHT, r=0.04, segs=1)  # chest pocket
        b.rround((sx * 0.52, 0.37, -d * 0.475 - 0.035), (0.53, 0.12, 0.05), MID, r=0.03, segs=1)  # flap
        b.rbox((sx * (w / 2 - 0.005), -0.08, 0), (0.02, h * 0.8, 0.04), SEAM)                     # side seam
    b.rbox((0, 0.36, d * 0.475 + 0.006), (w * 0.86, 0.03, 0.02), SEAM)                           # back yoke seam
    b.rround((0, -0.12, d * 0.475 + 0.012), (w * 0.5, 0.62, 0.03), MID, r=0.03, segs=1)          # back panel
    b.ao(-h / 2, h / 2, 0.8, 1.0)


def lower_torso(b, s):
    w, h, d = s
    b.rround((0, 0, 0), (w * 0.99, h, d * 0.97), CLOTH, r=0.06, segs=1)
    b.rround((0, 0.06, 0), (w, 0.16, d), DARK, r=0.04, segs=1)                                  # belt
    b.rbox((0, 0.06, -d / 2 - 0.012), (0.26, 0.14, 0.04), METAL, bevel=0.015)                   # buckle
    for x in (-0.95, -0.5, 0.5, 0.95):
        b.rbox((x, 0.06, -d / 2 - 0.006), (0.06, 0.2, 0.03), SEAM)                              # loops
        b.rbox((x, 0.06, d / 2 + 0.006), (0.06, 0.2, 0.03), SEAM)
    b.rbox((0, -0.12, -d / 2 - 0.004), (0.03, 0.14, 0.02), SEAM)                                 # fly seam


def head(b, s):
    w, h, d = s
    b.rround((0, 0, 0), (w, h, d * 0.985), SKIN, r=0.26, segs=3)
    for sx in (-1, 1):
        b.rround((sx * 0.21, 0.07, -d / 2 + 0.004), (0.13, 0.22, 0.02), EYE, r=0.055, segs=2)  # eyes


def upper_arm(b, s, side):
    w, h, d = s
    b.rround((0, -0.02, 0), (w * 0.97, h * 0.96, d * 0.97), CLOTH, r=0.12, segs=2)
    b.rround((0, h / 2 - 0.1, 0), (w, 0.2, d), CLOTH, r=0.1, segs=2)                            # shoulder
    b.rround((side * (w * 0.485 + 0.012), 0.05, 0), (0.04, 0.34, 0.52), MID, r=0.03, segs=1)    # patch
    b.ao(-h / 2, h / 2, 0.85, 1.0)


def lower_arm(b, s, side):
    w, h, d = s
    b.rround((0, 0.04, 0), (w * 0.96, h * 0.92, d * 0.96), CLOTH, r=0.1, segs=2)
    b.rround((0, -h / 2 + 0.085, 0), (w, 0.17, d), DARK, r=0.05, segs=1)                        # cuff
    b.rround((0, h / 2 - 0.2, d * 0.48 + 0.01), (w * 0.62, 0.3, 0.04), MID, r=0.03, segs=1)       # elbow
    b.ao(-h / 2, h / 2, 0.85, 1.0)


def hand(b, s, side):
    w, h, d = s
    b.rround((0, 0, 0), (w * 0.96, h * 0.96, d * 0.96), GLOVE, r=0.08, segs=2)
    b.rround((0, h / 2 - 0.035, 0), (w, 0.07, d), KNUCK, r=0.03, segs=1)                        # glove cuff
    b.rround((0, -0.03, -d * 0.48 - 0.01), (w * 0.78, 0.13, 0.05), KNUCK, r=0.03, segs=1)        # knuckle pad
    b.rround((-side * (w * 0.48 + 0.01), 0.0, -0.18), (0.04, 0.16, 0.36), KNUCK, r=0.02, segs=1)  # thumb seam


def upper_leg(b, s, side):
    w, h, d = s
    b.rround((0, 0, 0), (w * 0.97, h, d * 0.97), CLOTH, r=0.1, segs=2)
    b.rround((side * (w * 0.485 + 0.02), -0.06, 0.03), (0.06, 0.5, 0.56), MID, r=0.04, segs=1)    # cargo pocket
    b.rround((side * (w * 0.485 + 0.035), 0.22, 0.03), (0.06, 0.13, 0.6), DARK, r=0.03, segs=1)  # flap
    b.rbox((0, 0, -d * 0.485 - 0.006), (0.03, h * 0.9, 0.02), SEAM)                              # crease
    b.ao(-h / 2, h / 2, 0.82, 1.0)


def lower_leg(b, s, side):
    w, h, d = s
    b.rround((0, 0.08, 0), (w * 0.96, h * 0.84, d * 0.96), CLOTH, r=0.1, segs=2)
    b.rround((0, -h / 2 + 0.11, 0), (w * 0.9, 0.22, d * 0.9), DARK, r=0.06, segs=1)              # tucked into boot
    b.rround((0, h / 2 - 0.2, -d * 0.48 - 0.012), (w * 0.7, 0.32, 0.05), MID, r=0.04, segs=1)     # knee panel
    b.ao(-h / 2, h / 2, 0.8, 1.0)


def foot(b, s, side):
    w, h, d = s
    b.rround((0, -h / 2 + 0.05, -0.01), (w, 0.1, d), SOLE, r=0.04, segs=1)                       # sole
    b.rround((0, 0.03, 0.03), (w * 0.94, h * 0.82, d * 0.9), GLOVE, r=0.08, segs=2)              # upper
    b.rround((0, -0.0, -d * 0.39), (w * 0.9, h * 0.62, d * 0.22), MID, r=0.07, segs=1)          # toe cap
    for i in range(3):
        b.rbox((0, h / 2 - 0.035, -d * 0.12 - i * 0.11), (0.44, 0.03, 0.035), LACE)             # laces


BUILD = {"UpperTorso": upper_torso, "LowerTorso": lower_torso, "Head": head,
         "UpperArm": upper_arm, "LowerArm": lower_arm, "Hand": hand, "UpperLeg": upper_leg, "LowerLeg": lower_leg, "Foot": foot}


# ── helmet A: high-cut ballistic shell for the block head (head-local, origin = head centre) ─────────────
HELMET_A_RIM = [(0, 0.2), (38, 0.17), (58, 0.1), (70, 0.24), (102, 0.24), (118, 0.02), (148, -0.12), (180, -0.16)]
SHELL, SHELL_DARK, RAIL, PAD = grey(0.84), grey(0.62), grey(0.42), grey(0.5)


def helmet_a(b):
    """High-cut shell: rounded-box superellipsoid (power 3) that clears the block head's corners, brow at the
    eyebrows, ear cut-outs for a headset, deep nape; side rails, NVG shroud, patches, flat chin straps."""
    rim = lambda phi: lerp_table(HELMET_A_RIM, phi)
    b.shell((0, 0.05, 0.02), (0.8, 0.78, 0.78), SHELL, rim, power=3.0, thick=0.05, useg=20, vseg=12, lip_color=SHELL_DARK)
    for sx in (-1, 1):
        b.rround((sx * 0.78, 0.36, 0.05), (0.07, 0.1, 0.62), RAIL, r=0.02, segs=1)               # side rail
        for k in range(3):
            b.rbox((sx * 0.815, 0.36, -0.16 + k * 0.2), (0.02, 0.05, 0.08), SHELL_DARK)
        b.strap([(sx * 0.67, 0.2, 0.08), (sx * 0.67, -0.2, -0.06), (sx * 0.62, -0.5, -0.4)], 0.08, 0.025, PAD, up=(sx, 0, 0))  # chin strap
    b.rround((0, 0.52, -0.76), (0.3, 0.2, 0.09), RAIL, r=0.03, segs=1)                           # NVG shroud
    b.rround((0, 0.42, -0.79), (0.12, 0.08, 0.06), SHELL_DARK, r=0.02, segs=1)
    b.rround((0, 0.82, 0.02), (0.42, 0.03, 0.36), PAD, r=0.015, segs=1)                           # top patch
    b.rround((0, 0.42, 0.78), (0.36, 0.2, 0.03), PAD, r=0.015, segs=1, rot=(math.radians(-25), 0, 0))  # rear patch


def calib_cube(b):
    """2x2x2 stud cube, origin bottom-centre; FRONT bump (Roblox -Z, 0.2) and RIGHT bump (Roblox +X, 0.1)
    make orientation measurable: expected Roblox size (2.1, 2.0, 2.2), centre offset (0.05, 1.0, -0.1)."""
    ORANGE, MARK = hexc("C07946"), hexc("33383B")
    b.rbox((0, 1.0, 0), (2.0, 2.0, 2.0), ORANGE)
    b.rbox((0, 1.0, -1.1), (0.6, 0.6, 0.2), MARK)  # front (Roblox -Z)
    b.rbox((1.05, 1.0, 0), (0.1, 0.4, 0.4), MARK)  # right (Roblox +X)


def build(scene):
    col = scene.collection
    objs = []
    for name, part in SPEC["parts"].items():
        b = CB("ZR_BLK_" + name)
        s = part["size"]
        if name in BUILD:
            BUILD[name](b, s)
        else:
            side = 1 if name.startswith("Right") else -1
            BUILD[name[5:] if side == 1 else name[4:]](b, s, side)
        b.fit(s)
        objs.append(b.finish(col))
    b = CB("ZR_EQ_HelmetA")
    helmet_a(b)
    objs.append(b.finish(col))
    b = CB("ZR_CAL_Cube2")
    calib_cube(b)
    objs.append(b.finish(col))
    return objs


if not globals().get("ZR_NO_EXPORT"):   # zr_gtex.py builds the pieces without exporting (art-4b texture sheets)
    scene = batch_scene("ZR_CharBase")
    objs = build(scene)
    fbx, blend, meta = export_batch(objs, "ZR_CharBase", scene)
    print("ZR_CharBase exported", fbx, os.path.getsize(fbx), "bytes,", len(objs), "objects,", sum(m["tris"] for m in meta.values()), "tris")
    for k in sorted(meta):
        print(k, meta[k]["tris"], "size", meta[k]["size"], "center", meta[k]["center"])

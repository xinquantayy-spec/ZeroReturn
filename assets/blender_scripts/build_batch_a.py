"""Zero Return - asset batch A (hero weapon + core quay props). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_batch_a.py").read(), g)
Generates objects in scene "ZR_Assets", exports assets/exports/ZR_BatchA.fbx (+ .blend source + .meta.json).
All geometry is original and procedural (no external assets).
"""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
import importlib, zr_lib
importlib.reload(zr_lib)
from zr_lib import Builder, hexc, grey, batch_scene, export_batch

R = math.radians
VS = 0.55  # first-person viewmodel scale (matches Weapon.luau)

# palette
GUN_DARK, GUN_MID, METAL = hexc("2B2F2E"), hexc("3A3F3D"), hexc("4A504D")
FURN, FURN2, RUBBER = hexc("515B55"), hexc("47504B"), hexc("1E2120")
GLOVE, GLOVE2, SLEEVE, CUFF = hexc("2A2C2B"), hexc("353836"), hexc("5E6448"), hexc("6B6A4E")


def rifle(b, detail=True):
    # lower+upper receiver side profile (y forward is negative), width 0.24
    b.prism([(0.32, 0.05), (0.32, -0.12), (0.10, -0.13), (-0.30, -0.13), (-0.30, -0.21), (-0.68, -0.21),
             (-0.68, -0.12), (-1.00, -0.10), (-1.00, 0.12), (-0.92, 0.17), (0.25, 0.17), (0.32, 0.12)],
            -0.12, 0.12, GUN_DARK)
    b.box((0, -0.40, 0.195), (0.15, 1.10, 0.05), METAL)
    if detail:
        for k in range(9):
            b.box((0, 0.08 - k * 0.12, 0.226), (0.16, 0.045, 0.018), GUN_MID)
        for k in range(4):
            for sx in (-0.137, 0.137):
                b.box((sx, -1.13 - k * 0.18, 0.04), (0.02, 0.11, 0.05), RUBBER)
        b.box((-0.122, -0.42, 0.055), (0.012, 0.22, 0.075), hexc("141615"))  # ejection port (right side)
        b.box((-0.14, -0.30, 0.10), (0.05, 0.09, 0.05), METAL)  # charging handle
        b.box((0.125, 0.0, 0.02), (0.02, 0.05, 0.04), METAL)  # selector
        b.box((0, -0.15, -0.16), (0.02, 0.03, 0.08), METAL)  # trigger
    b.box((0, -1.42, 0.0), (0.27, 0.86, 0.27), FURN, bevel=0.05)  # handguard
    b.box((0, -1.90, 0.04), (0.12, 0.08, 0.12), GUN_MID)  # gas block
    b.cyl((0, -1.85, 0.03), (0, -2.38, 0.03), 0.038, METAL, seg=8, smooth=True)
    b.box((0, -2.46, 0.03), (0.11, 0.18, 0.11), GUN_DARK, bevel=0.015)  # muzzle brake
    if detail:
        for y in (-2.42, -2.50):
            b.box((0, y, 0.066), (0.12, 0.03, 0.04), RUBBER)
    # sights (sight line z = 0.27): front post between ears, rear aperture ears
    b.box((0, -1.78, 0.14), (0.12, 0.08, 0.06), GUN_DARK)
    b.box((0, -1.78, 0.205), (0.035, 0.035, 0.12), GUN_DARK)
    for sx in (-0.055, 0.055):
        b.box((sx, -1.78, 0.20), (0.02, 0.06, 0.11), GUN_DARK)
    b.box((0, -0.10, 0.225), (0.13, 0.09, 0.03), GUN_DARK)
    for sx in (-0.05, 0.05):
        b.box((sx, -0.10, 0.26), (0.025, 0.06, 0.08), GUN_DARK)
    # grip + trigger guard
    b.box((0, 0.05, -0.30), (0.12, 0.16, 0.36), FURN2, rot=(R(18), 0, 0), bevel=0.02)
    b.box((0, -0.20, -0.17), (0.05, 0.28, 0.03), GUN_DARK)
    # skeleton stock
    b.box((0, 0.62, 0.08), (0.10, 0.62, 0.07), FURN)
    b.box((0, 0.60, -0.11), (0.08, 0.66, 0.06), FURN, rot=(R(-8), 0, 0))
    b.box((0, 0.62, 0.15), (0.11, 0.30, 0.06), FURN2)
    b.box((0, 0.94, -0.03), (0.16, 0.06, 0.40), RUBBER, bevel=0.015)


def build(scene):
    col = scene.collection
    objs = []

    # ── first-person R-17 (grip at origin), magazine, arms ──
    b = Builder("ZR_VM_R17")
    rifle(b, True)
    b.jitter(0.035, 7)
    b.scale(VS)
    objs.append(b.finish(col))

    b = Builder("ZR_VM_R17_Mag")
    b.prism([(0.11, 0.24), (-0.11, 0.24), (-0.16, -0.22), (0.05, -0.24)], -0.065, 0.065, hexc("33383B"))
    b.box((-0.05, -0.0, -0.25), (0.15, 0.24, 0.035), GUN_DARK)
    b.box((0, 0.0, 0.245), (0.10, 0.18, 0.02), hexc("A08A5C"))  # visible top cartridge
    b.scale(VS)
    objs.append(b.finish(col))

    b = Builder("ZR_VM_Arms")
    # right hand on the grip (shooter's right = -X)
    b.box((-0.05, 0.0, -0.27), (0.20, 0.24, 0.26), GLOVE, bevel=0.03)
    b.box((0.05, -0.10, -0.27), (0.10, 0.07, 0.22), GLOVE2, bevel=0.015)  # fingers wrapping front
    b.box((0.075, -0.04, -0.15), (0.06, 0.16, 0.06), GLOVE2, rot=(R(-20), 0, 0))  # thumb
    b.cyl((-0.08, 0.10, -0.33), (-0.14, 0.22, -0.39), 0.12, GLOVE, seg=8)
    b.cyl((-0.11, 0.14, -0.35), (-0.46, 1.00, -0.66), 0.13, SLEEVE, r2=0.165, seg=8, smooth=True)
    b.cyl((-0.13, 0.18, -0.37), (-0.16, 0.26, -0.41), 0.14, CUFF, seg=8)
    # left hand under the handguard
    b.box((0.04, -1.38, -0.15), (0.22, 0.28, 0.20), GLOVE, bevel=0.03)
    b.box((0.15, -1.38, -0.05), (0.06, 0.24, 0.12), GLOVE2, bevel=0.015)
    b.box((-0.13, -1.36, -0.03), (0.05, 0.14, 0.06), GLOVE2)
    b.cyl((0.06, -1.30, -0.20), (0.12, -1.16, -0.29), 0.115, GLOVE, seg=8)
    b.cyl((0.08, -1.24, -0.24), (0.50, -0.34, -0.66), 0.12, SLEEVE, r2=0.155, seg=8, smooth=True)
    b.cyl((0.10, -1.20, -0.26), (0.13, -1.12, -0.31), 0.13, CUFF, seg=8)
    b.scale(VS)
    objs.append(b.finish(col))

    # ── third-person rifle (character scale, fewer details) ──
    b = Builder("ZR_WPN_R17_TP")
    rifle(b, False)
    b.scale(1.15)
    objs.append(b.finish(col))

    # ── shipping container 20ft (neutral, tinted in Roblox), origin bottom-centre ──
    b = Builder("ZR_ENV_Container20")
    b.box((0, 0, 4.7), (22, 8.8, 9.4), grey(0.84))
    for i in range(-9, 10):
        for sy in (-4.46, 4.46):
            b.box((i * 1.15, sy, 4.7), (0.5, 0.16, 8.3), grey(0.72))
    for x in (-7, 0, 7):
        b.box((x, 0, 9.43), (0.3, 8.6, 0.06), grey(0.7))
    for sx in (-10.75, 10.75):
        for sy in (-4.2, 4.2):
            b.box((sx, sy, 4.8), (0.7, 0.7, 9.6), grey(0.42))
    for sy in (-4.2, 4.2):
        b.box((0, sy, 9.3), (22, 0.45, 0.45), grey(0.5))
        b.box((0, sy, 0.3), (22, 0.5, 0.5), grey(0.45))
    for sx in (-10.8, 10.8):
        for z in (9.3, 0.3):
            b.box((sx, 0, z), (0.45, 8.8, 0.45), grey(0.48))
    for sy in (-2.15, 2.15):
        b.box((11.07, sy, 4.7), (0.12, 4.15, 8.3), grey(0.8))
        for z in (2.4, 4.7, 7.0):
            b.box((11.14, sy, z), (0.08, 3.9, 0.28), grey(0.7))
    for sy in (-3.2, -0.9, 0.9, 3.2):
        b.cyl((11.22, sy, 0.6), (11.22, sy, 8.8), 0.09, grey(0.35), seg=6)
        b.box((11.3, sy, 4.0), (0.12, 0.55, 0.12), grey(0.3))
    b.ao(0, 9.6, 0.55, 1.0)
    b.jitter(0.04, 3)
    objs.append(b.finish(col))

    # ── steel drum (neutral, tinted) ──
    b = Builder("ZR_PROP_Barrel")
    b.cyl((0, 0, 0), (0, 0, 4.4), 1.6, grey(0.86), seg=14, smooth=True)
    for z in (1.45, 2.95):
        b.cyl((0, 0, z - 0.08), (0, 0, z + 0.08), 1.67, grey(0.6), seg=14, smooth=True)
    b.cyl((0, 0, 4.3), (0, 0, 4.42), 1.63, grey(0.7), seg=14, smooth=True)
    b.cyl((0.8, 0.5, 4.4), (0.8, 0.5, 4.48), 0.18, grey(0.4), seg=8)
    b.cyl((-0.9, -0.3, 4.4), (-0.9, -0.3, 4.48), 0.14, grey(0.4), seg=8)
    b.ao(0, 4.5, 0.6, 1.0)
    objs.append(b.finish(col))

    # ── wooden pallet ──
    b = Builder("ZR_PROP_Pallet")
    woods = [hexc("8A7356"), hexc("7A644A"), hexc("6E5A44"), hexc("82694D")]
    for i, y in enumerate((-1.8, 0, 1.8)):
        b.box((0, y, 0.05), (5, 0.55, 0.1), woods[i % 4])
        b.box((0, y, 0.47), (5, 0.55, 0.1), woods[(i + 1) % 4])
        for x in (-2.2, 0, 2.2):
            b.box((x, y, 0.26), (0.55, 0.55, 0.32), woods[(i + 2) % 4])
    for k in range(7):
        b.box((-2.2 + k * 0.733, 0, 0.57), (0.55, 4.2, 0.1), woods[k % 4])
    b.ao(0, 0.62, 0.7, 1.0)
    b.jitter(0.06, 11)
    objs.append(b.finish(col))

    # ── jersey barrier (neutral concrete, tinted) ──
    b = Builder("ZR_PROP_Barrier")
    b.prism([(-1.2, 0), (1.2, 0), (1.2, 0.3), (0.8, 0.95), (0.3, 2.6), (-0.3, 2.6), (-0.8, 0.95), (-1.2, 0.3)], -4, 4, grey(0.82))
    for x in (-2.5, 2.5):
        b.box((x, 0, 2.6), (0.5, 0.62, 0.05), grey(0.35))
    b.ao(0, 2.6, 0.6, 1.0)
    objs.append(b.finish(col))

    # ── harbour light pole (arm toward Roblox +X = Blender -X) ──
    b = Builder("ZR_PROP_LightPole")
    b.box((0, 0, 0.125), (1.0, 1.0, 0.25), hexc("2B2F2E"))
    b.cyl((0, 0, 0.25), (0, 0, 18), 0.32, hexc("3A3F3D"), r2=0.2, seg=8, smooth=True)
    b.box((-1.25, 0, 17.95), (2.6, 0.22, 0.22), hexc("3A3F3D"))
    b.cyl((0, 0, 16.6), (-1.2, 0, 17.85), 0.06, hexc("3A3F3D"), seg=6)
    b.box((-2.4, 0, 17.95), (1.4, 0.9, 0.32), hexc("2B2F2E"), bevel=0.04)
    b.ao(0, 18, 0.7, 1.0)
    objs.append(b.finish(col))
    return objs


scene = batch_scene("ZR_Assets")
objects = build(scene)
fbx, blend, meta = export_batch(objects, "ZR_BatchA", scene)
print("EXPORTED", fbx, os.path.getsize(fbx))
for k, v in meta.items():
    print(k, v["tris"], "tris size", v["size"], "center", v["center"])

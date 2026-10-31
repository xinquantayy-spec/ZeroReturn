"""Zero Return - eyewear, gas mask, head strap and night-vision goggle meshes for the block head (ZR_BLOCK_R15_V1).
HOW TO RUN (inside Blender, the same way as build_char_gear.py; this script has NOT been run yet, see KNOWN_ISSUES.md):
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_eyewear.py").read(), g)
It exports assets/exports/ZR_EyeGear.fbx (+ assets/blender_sources/ZR_EyeGear.blend and assets/exports/ZR_EyeGear.meta.json)
from its own scene "ZR_EyeGear". Then follow docs/PIPELINE.md: upload the FBX (zr_upload.upload_model(fbx, "ZR_EyeGear")), add the
batch id to src/shared/AssetIds.luau, and check the printed sizes and centres against Equipment.SIZE and AssetMeta in src/shared
(the TARGETS below force every bounding box, so they agree to 0.001 and AssetMeta already holds the centres). Finally delete the
uploaded keys from Equipment.PENDING in src/shared/Equipment.luau. Nothing else in the game changes: the items, the slot, the
blocking rules, the overlays and the character wiring already exist and show neutral boxes until these meshes are in.

Original procedural meshes in the head part's local space (origin = head centre, Roblox axes via zr_char), attached in game
with head.CFrame * CFrame.new(AssetMeta[key]). The block head is 1.26 x 1.16 x 1.18: flat front and back for |x| < 0.37, flat
sides for |z| < 0.321, corners rounded r 0.26, front face z -0.581, eyes at x +-0.21, y 0.07 (0.13 x 0.22).
The glasses, the gas mask and the goggles carry their REAL colours (lenses, frames, rubber, accents) and the game places them with
a white tint, so the lens colours survive; Equipment.VIS gives each a dark fallback colour for the neutral box shown until they are
uploaded. The head strap is neutral grey (tinted in game like the other head gear). Triangle targets (project hypotheses):
glasses 150-400, gas mask ~900, goggles 400-800.

Eyewear (EYEWEAR slot, group "eyes"):  GlassSun (brown sport sunglasses), GlassRange (yellow wrap-around shooting glasses),
             GlassBallistic (clear class 1: frame only, so the eyes show), GlassFrag (class 2: blue lens, thick frame, head strap)
Face cover:  GasMask (rubber facepiece, two lenses, front filter canister, two-band harness)
Head device: NvStrap (head harness with a front bracket: the mount for goggles when there is no helmet),
             Nv<Mono|Bino|Green|Quad|Thermal><Down|Up> (group "nvg"): the goggles of NV_MONO, NV_BINO, NV_GREEN, NV_QUAD, TH_T7 on
             their mount, DOWN over the eyes or flipped UP on the front of the head. Both poses share one hinge position (the
             mount shroud of ZR_EQ_HelmetA at head (0, 0.52, -0.76)), so helmets C3/C4 and the strap hold them the same way.
Device frame used by the goggle code: x right, y up, f forward from the eyepiece plane; tr() maps it into head space for each pose.
"""
import math, os, sys
HERE = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts")
sys.path.insert(0, HERE)
import importlib, zr_lib, zr_char
importlib.reload(zr_lib)
importlib.reload(zr_char)
from zr_lib import hexc, grey, batch_scene, export_batch
from zr_char import CB, B

R = math.radians

# ── colours (real ones for the glasses, mask and goggles: MeshPart.Color is white for these; the strap is neutral grey) ──
BRN_FR, BRN_LENS = hexc("3A2A1E"), hexc("5A3A22")
YEL_LENS, GRY_FR = hexc("D6B93A"), grey(0.34)
CLR_FR = hexc("2B3033")
BLU_LENS, BLU_FR = hexc("2F5C9E"), hexc("1D2125")
RUBBER, CANISTER = hexc("2D342B"), hexc("59623F")
RING, MASK_GLASS, HARNESS = grey(0.32), hexc("1B2829"), grey(0.2)
BODY, BODY_DK, MET, RUB, GLASS = hexc("3B4339"), hexc("2C322B"), grey(0.45), grey(0.13), hexc("142222")
STRAP_COL, PLATE, TAB = grey(0.78), grey(0.58), grey(0.4)
ACC = {"Mono": hexc("7FBF8A"), "Bino": hexc("4E8E9A"), "Green": hexc("6BA85E"), "Quad": hexc("A8D8B0"), "Thermal": hexc("C4883A")}

# bounding boxes forced on every mesh: key -> (centre, size) in head space. They are also Equipment.SIZE (the neutral fallback
# boxes) and AssetMeta (the placement centres) in src/shared, so the game works with boxes before the upload and the upload agrees.
# Measured on the unscaled build with a dry run of these functions; build() stretches each mesh to exactly this box.
TARGETS = {
    "ZR_EQ_GlassSun": ((0.000, 0.080, -0.303), (1.380, 0.300, 0.707)),
    "ZR_EQ_GlassRange": ((0.000, 0.082, -0.305), (1.390, 0.325, 0.711)),
    "ZR_EQ_GlassBallistic": ((0.000, 0.082, -0.302), (1.390, 0.325, 0.703)),
    "ZR_EQ_GlassFrag": ((0.000, 0.076, -0.016), (1.415, 0.373, 1.309)),
    "ZR_EQ_GasMask": ((0.000, -0.145, -0.207), (1.370, 0.830, 1.686)),
    "ZR_EQ_NvStrap": ((0.000, 0.472, -0.062), (1.375, 0.311, 1.485)),
    "ZR_EQ_NvMonoDown": ((0.165, 0.208, -1.030), (0.490, 0.675, 0.700)),
    "ZR_EQ_NvBinoDown": ((0.000, 0.218, -1.000), (0.780, 0.655, 0.640)),
    "ZR_EQ_NvGreenDown": ((0.000, 0.208, -1.000), (0.820, 0.675, 0.640)),
    "ZR_EQ_NvQuadDown": ((0.000, 0.233, -1.010), (1.432, 0.625, 0.660)),
    "ZR_EQ_NvThermalDown": ((0.000, 0.198, -1.050), (0.740, 0.695, 0.740)),
    "ZR_EQ_NvMonoUp": ((0.165, 0.868, -0.875), (0.490, 0.825, 0.450)),
    "ZR_EQ_NvBinoUp": ((0.000, 0.838, -0.880), (0.780, 0.765, 0.400)),
    "ZR_EQ_NvGreenUp": ((0.000, 0.838, -0.890), (0.820, 0.765, 0.420)),
    "ZR_EQ_NvQuadUp": ((0.000, 0.848, -0.865), (1.432, 0.785, 0.370)),
    "ZR_EQ_NvThermalUp": ((0.000, 0.887, -0.885), (0.740, 0.865, 0.470)),
}


# ── head-hugging paths ───────────────────────────────────────────────────────────────────────────────────
def hug(clear, a0, a1, n):
    """points (x >= 0, z) on the head's front-side corner, `clear` studs off the skin, from a0 to a1 degrees (0 = ahead, 90 = side)"""
    r = 0.26 + clear
    out = []
    for k in range(n + 1):
        a = R(a0 + (a1 - a0) * (k / n if n else 0.0))
        out.append((0.37 + r * math.sin(a), -0.321 - r * math.cos(a)))
    return out


def wrap(y, clear, ang):
    """path across the face at height y hugging the front corners out to `ang` degrees, left end to right end"""
    right = hug(clear, 0, ang, 2)
    return [(-x, y, z) for x, z in reversed(right)] + [(x, y, z) for x, z in right]


def ring(y, clear, gap=0.05, n=3):
    """path round the whole head at height y, `clear` studs off the skin, left open by `gap` at the back centre"""
    r = 0.26 + clear
    right = [(gap, 0.321 + r)]
    right += [(0.37 + r * math.sin(R(90.0 * k / n)), 0.321 + r * math.cos(R(90.0 * k / n))) for k in range(n + 1)]
    right += [(0.37 + r * math.sin(R(90.0 - 90.0 * k / n)), -0.321 - r * math.cos(R(90.0 - 90.0 * k / n))) for k in range(n + 1)]
    right.append((0.0, -0.321 - r))
    return [(-x, y, z) for x, z in right] + [(x, y, z) for x, z in reversed(right[:-1])]


def temples(b, color, y, a0, clear, radial, height, reach=0.05, first=None):
    """arms from the lens end (a0 degrees round the corner) along the side of the head to the ear at z = reach"""
    for sx in (-1, 1):
        pts = [(sx * x, y, z) for x, z in hug(clear, a0, 90, 2)]
        if first:
            pts.insert(0, (sx * first[0], y, first[1]))
        pts.append((sx * (0.63 + clear), y, reach))
        b.strap(pts, radial, height, color, up=(0, 1, 0))


def back_loop(b, y, clear, radial, height, color, z0, front=None):
    """band round the back of the head from the side (z0) or from the front edge `front` = (x, z) on each side, round the back"""
    r = 0.26 + clear
    right = [(0.63 + clear, z0), (0.63 + clear, 0.321)] + [(0.37 + r * math.sin(R(a)), 0.321 + r * math.cos(R(a))) for a in (60, 30, 0)]
    if front:
        right = [front] + hug(clear, 50, 90, 2) + right[1:]
    pts = [(-x, y, z) for x, z in right] + [(x, y, z) for x, z in reversed(right)]
    b.strap(pts, radial, height, color, up=(0, 1, 0))


# ── eyewear ──────────────────────────────────────────────────────────────────────────────────────────────
def glass_sun(b):
    """sport sunglasses: two rimmed brown lenses on a bridge, arms to the ears"""
    for sx in (-1, 1):
        b.rround((sx * 0.23, 0.08, -0.625), (0.44, 0.3, 0.04), BRN_FR, r=0.07, segs=1)
        b.rround((sx * 0.23, 0.08, -0.648), (0.38, 0.24, 0.018), BRN_LENS, r=0.05, segs=1)
    b.rround((0, 0.15, -0.625), (0.14, 0.06, 0.04), BRN_FR, r=0.02, segs=1)
    temples(b, BRN_FR, 0.15, 40, 0.045, 0.03, 0.05, first=(0.45, -0.625))


def glass_range(b):
    """shooting glasses: one wrap-around yellow lens under a light brow bar, nose pads, grey arms"""
    b.strap(wrap(0.08, 0.05, 62), 0.02, 0.25, YEL_LENS, up=(0, 1, 0))
    b.strap(wrap(0.225, 0.06, 62), 0.04, 0.04, GRY_FR, up=(0, 1, 0))
    for sx in (-1, 1):
        b.rround((sx * 0.07, -0.02, -0.6), (0.04, 0.12, 0.04), GRY_FR, r=0.012, segs=1)
    temples(b, GRY_FR, 0.17, 62, 0.05, 0.03, 0.045)


def glass_ballistic(b):
    """clear class 1 ballistic glasses: no lens plate (so the eyes show), a heavy brow bar, a thin lower rim, side and centre posts"""
    b.strap(wrap(0.215, 0.05, 62), 0.045, 0.06, CLR_FR, up=(0, 1, 0))
    b.strap(wrap(-0.035, 0.045, 62), 0.03, 0.03, CLR_FR, up=(0, 1, 0))
    x, z = hug(0.05, 62, 62, 0)[0]
    for sx in (-1, 1):
        b.rround((sx * x, 0.09, z), (0.04, 0.27, 0.04), CLR_FR, r=0.012, segs=1)
        b.rround((sx * 0.07, -0.02, -0.6), (0.04, 0.12, 0.04), CLR_FR, r=0.012, segs=1)
    b.rround((0, 0.09, -0.628), (0.06, 0.27, 0.04), CLR_FR, r=0.012, segs=1)
    temples(b, CLR_FR, 0.17, 62, 0.05, 0.03, 0.05)


def glass_frag(b):
    """class 2 anti-fragmentation glasses: a deep blue wrap lens in a thick black frame, nose pads, an elastic head strap"""
    b.strap(wrap(0.08, 0.05, 66), 0.022, 0.26, BLU_LENS, up=(0, 1, 0))
    b.strap(wrap(0.225, 0.065, 66), 0.05, 0.075, BLU_FR, up=(0, 1, 0))
    b.strap(wrap(-0.06, 0.06, 66), 0.04, 0.05, BLU_FR, up=(0, 1, 0))
    x, z = hug(0.06, 66, 66, 0)[0]
    for sx in (-1, 1):
        b.rround((sx * x, 0.08, z), (0.05, 0.3, 0.05), BLU_FR, r=0.015, segs=1)
        b.rround((sx * 0.07, -0.04, -0.6), (0.05, 0.14, 0.05), BLU_FR, r=0.015, segs=1)
    temples(b, BLU_FR, 0.17, 66, 0.06, 0.035, 0.06, reach=-0.05)
    back_loop(b, 0.17, 0.045, 0.025, 0.1, HARNESS, -0.05)


def gas_mask(b):
    """full-face mask: a rubber facepiece over eyes, nose and mouth, two round lenses, a front filter canister, a two-band harness"""
    b.rround((0, -0.12, -0.685), (0.98, 0.78, 0.2), RUBBER, r=0.14, segs=2)
    b.rround((0, -0.4, -0.66), (0.78, 0.26, 0.16), RUBBER, r=0.08, segs=1)
    for sx in (-1, 1):
        b.rcyl((sx * 0.24, 0.07, -0.78), (sx * 0.24, 0.07, -0.86), 0.2, RING, seg=8)
        b.rcyl((sx * 0.24, 0.07, -0.86), (sx * 0.24, 0.07, -0.88), 0.155, MASK_GLASS, seg=8)
    b.rcyl((0, -0.34, -0.8), (0, -0.34, -0.83), 0.22, RING, seg=8)       # canister collar
    b.rcyl((0, -0.34, -0.83), (0, -0.34, -1.02), 0.19, CANISTER, seg=10)  # filter canister
    b.rcyl((0, -0.34, -1.02), (0, -0.34, -1.05), 0.14, RING, seg=8)      # canister cap
    for y in (0.2, -0.2):
        back_loop(b, y, 0.04, 0.03, 0.09, HARNESS, 0.0, front=(0.49, -0.6))


# ── head harness for goggles (no helmet) ─────────────────────────────────────────────────────────────────
def nv_strap(b):
    """elastic head harness: a band round the forehead, a crown strap over the top, a rear adjuster and a front bracket that
    steps out to where the helmet's mount shroud is, so goggles hang on it exactly as on helmet A"""
    b.strap(ring(0.4, 0.04), 0.035, 0.14, STRAP_COL, up=(0, 1, 0))
    r = 0.295
    crown = [(0, 0.32 + r * math.sin(R(a)), -0.321 - r * math.cos(R(a))) for a in (0, 30, 60)] + [(0, 0.615, -0.321), (0, 0.615, 0.321)]
    crown += [(0, 0.32 + r * math.sin(R(a)), 0.321 + r * math.cos(R(a))) for a in (60, 30, 0)]
    b.strap(crown, 0.025, 0.1, STRAP_COL, up=(1, 0, 0))
    b.rround((0, 0.4, 0.655), (0.3, 0.14, 0.05), PLATE, r=0.02, segs=1)    # rear adjuster
    b.rround((0, 0.4, -0.66), (0.34, 0.16, 0.06), PLATE, r=0.02, segs=1)   # bracket plate on the band
    b.rround((0, 0.46, -0.72), (0.16, 0.12, 0.12), TAB, r=0.02, segs=1)    # bracket arm
    b.rround((0, 0.52, -0.76), (0.3, 0.2, 0.09), PLATE, r=0.03, segs=1)    # shroud (the helmet's own mount position)


# ── night-vision goggles on the mount ────────────────────────────────────────────────────────────────────
EYE_Y, EYE_Z = 0.07, -0.70   # down: the eyepiece plane, just in front of any glasses
UP_Y, UP_Z = 0.6, -0.9       # up: where the eyepiece plane sits when the goggles are flipped up in front of the helmet


def tr(pose, x, y, f):
    """device frame -> head space. Down: forward is -z. Up: the device is turned 90 degrees, forward points up, its top faces back"""
    return (x, EYE_Y + y, EYE_Z - f) if pose == "down" else (x, UP_Y + f, UP_Z + y)


def sz(pose, sx, sy, sf):
    return (sx, sy, sf) if pose == "down" else (sx, sf, sy)


def dbox(b, pose, c, s, color, r=0.04):
    b.rround(tr(pose, *c), sz(pose, *s), color, r=r, segs=1)


def dcyl(b, pose, a, e, r, color, r2=None):
    b.rcyl(tr(pose, *a), tr(pose, *e), r, color, r2=r2, seg=8)


def mount(b, pose):
    """hinge pin on the mount shroud and the arm to the device"""
    b.rcyl((-0.08, 0.5, -0.8), (0.08, 0.5, -0.8), 0.045, MET, seg=8)
    if pose == "down":
        b.strap([(0, 0.5, -0.8), (0, 0.42, -0.9), (0, 0.3, -0.93)], 0.05, 0.1, MET, up=(1, 0, 0))
    else:
        b.strap([(0, 0.5, -0.8), (0, 0.58, -0.88)], 0.05, 0.1, MET, up=(1, 0, 0))


def tube(b, pose, x0, x1, f0, f1, r, color, r2=None):
    dcyl(b, pose, (x0, 0, f0), (x1, 0, f1), r, color, r2)


def nv_mono(b, pose):
    """single-tube monocular in front of the right eye"""
    x = 0.21
    tube(b, pose, x, x, -0.02, 0.12, 0.13, RUB)
    tube(b, pose, x, x, 0.12, 0.5, 0.165, BODY)
    tube(b, pose, x, x, 0.26, 0.36, 0.185, MET)
    tube(b, pose, x, x, 0.18, 0.22, 0.17, ACC["Mono"])
    tube(b, pose, x, x, 0.5, 0.66, 0.19, MET, r2=0.2)
    tube(b, pose, x, x, 0.66, 0.68, 0.15, GLASS)
    dbox(b, pose, (0.1, 0.2, 0.3), (0.32, 0.1, 0.24), BODY_DK)  # bridge from the centred mount arm out to the tube
    mount(b, pose)


def nv_bino(b, pose, green=False):
    """twin-tube goggles on a bridge housing and battery pack; the G-15 (green) has fatter tubes and bells"""
    r, bell = (0.16, 0.19) if green else (0.15, 0.17)
    body = hexc("34402F") if green else BODY
    key = "Green" if green else "Bino"
    for sx in (-1, 1):
        x = sx * 0.21
        tube(b, pose, x, x, -0.02, 0.1, 0.12, RUB)
        tube(b, pose, x, x, 0.1, 0.46, r, body)
        tube(b, pose, x, x, 0.24, 0.3, r + 0.015, ACC[key])
        tube(b, pose, x, x, 0.46, 0.6, bell, MET, r2=bell + 0.01)
        tube(b, pose, x, x, 0.6, 0.62, bell - 0.035, GLASS)
    dbox(b, pose, (0, 0.0, 0.22), (0.3, 0.26, 0.36), BODY_DK)
    dbox(b, pose, (0, 0.17, 0.26), (0.34, 0.1, 0.4), BODY_DK)
    mount(b, pose)


def nv_quad(b, pose):
    """four-tube panoramic goggles: two straight tubes in front of the eyes and two toed out to each side"""
    for sx in (-1, 1):
        tube(b, pose, sx * 0.17, sx * 0.17, -0.02, 0.1, 0.11, RUB)
        tube(b, pose, sx * 0.17, sx * 0.17, 0.1, 0.5, 0.13, BODY)
        tube(b, pose, sx * 0.17, sx * 0.17, 0.5, 0.62, 0.15, MET)
        tube(b, pose, sx * 0.17, sx * 0.17, 0.62, 0.64, 0.115, GLASS)
        tube(b, pose, sx * 0.42, sx * 0.55, 0.04, 0.48, 0.12, BODY)
        tube(b, pose, sx * 0.55, sx * 0.58, 0.46, 0.58, 0.14, MET)
        tube(b, pose, sx * 0.58, sx * 0.585, 0.58, 0.6, 0.105, GLASS)
        tube(b, pose, sx * 0.17, sx * 0.17, 0.26, 0.32, 0.14, ACC["Quad"])
    dbox(b, pose, (0, 0.0, 0.22), (0.9, 0.26, 0.3), BODY_DK)
    dbox(b, pose, (0, 0.17, 0.26), (0.5, 0.1, 0.4), BODY_DK)
    mount(b, pose)


def th_t7(b, pose):
    """thermal goggles: one wide housing, two eyecups, a single big objective, a top rail and an amber strip"""
    dbox(b, pose, (0, 0.0, 0.32), (0.74, 0.4, 0.56), BODY_DK, r=0.08)
    for sx in (-1, 1):
        tube(b, pose, sx * 0.2, sx * 0.2, -0.02, 0.1, 0.12, RUB)
    tube(b, pose, 0, 0, 0.6, 0.7, 0.19, MET)
    tube(b, pose, 0, 0, 0.7, 0.72, 0.15, hexc("5A4630"))
    dbox(b, pose, (0, 0.22, 0.32), (0.4, 0.06, 0.4), MET, r=0.02)
    dbox(b, pose, (0, -0.2, 0.32), (0.5, 0.04, 0.4), ACC["Thermal"], r=0.015)
    dbox(b, pose, (0.33, 0.08, 0.4), (0.06, 0.12, 0.12), grey(0.2), r=0.02)
    mount(b, pose)


PIECES = [
    ("ZR_EQ_GlassSun", glass_sun), ("ZR_EQ_GlassRange", glass_range), ("ZR_EQ_GlassBallistic", glass_ballistic),
    ("ZR_EQ_GlassFrag", glass_frag), ("ZR_EQ_GasMask", gas_mask), ("ZR_EQ_NvStrap", nv_strap),
]
for _pose in ("Down", "Up"):
    for _name, _fn in (("Mono", nv_mono), ("Bino", nv_bino), ("Green", lambda b, p: nv_bino(b, p, True)), ("Quad", nv_quad), ("Thermal", th_t7)):
        PIECES.append(("ZR_EQ_Nv" + _name + _pose, (lambda f, p: (lambda b: f(b, p)))(_fn, _pose.lower())))


def fit_at(b, key):
    """scale the piece so its bounding box is exactly the TARGET size, centred on the TARGET centre (head space)"""
    center, size = TARGETS[key]
    b.fit(size)
    off = B(*center)
    for v in b.bm.verts:
        v.co = v.co + off


def build(scene):
    col = scene.collection
    objs = []
    for name, fn in PIECES:
        b = CB(name)
        fn(b)
        fit_at(b, name)
        objs.append(b.finish(col))
    return objs


if not globals().get("ZR_NO_EXPORT"):
    scene = batch_scene("ZR_EyeGear")
    objs = build(scene)
    fbx, blend, meta = export_batch(objs, "ZR_EyeGear", scene)
    print("ZR_EyeGear exported", fbx, os.path.getsize(fbx), "bytes,", len(objs), "objects,", sum(m["tris"] for m in meta.values()), "tris")
    drift = 0.0
    for k in sorted(meta):
        center, size = TARGETS[k]
        d = max(abs(a - b_) for a, b_ in zip(meta[k]["center"] + meta[k]["size"], list(center) + list(size)))
        drift = max(drift, d)
        print(k, meta[k]["tris"], "size", meta[k]["size"], "center", meta[k]["center"], "(off target by %.4f)" % d)
    print("largest difference from the TARGETS (Equipment.SIZE / AssetMeta): %.4f" % drift)

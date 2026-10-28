"""Zero Return - M16 character equipment batch for the block body (ZR_BLOCK_R15_V1). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_char_gear.py").read(), g)
Original procedural equipment, authored in each host body part's local space (origin = host centre, Roblox axes
via zr_char), so the game attaches a piece with host.CFrame * CFrame.new(meta.center). Rounded shells, padded
panels, pouches and straps in neutral greys (tinted per item / faction by MeshPart.Color) with small fixed-colour
accents. Triangle targets (project hypotheses, not Roblox limits): helmet 400-900, carrier with pouches
900-1800, backpack 500-1000, whole equipped character 6k-10k.

Layering contract (src/shared/Equipment.luau): the torso is 2.16 x 1.70 x 1.08 with its shoulder edge rounded
r 0.12. Torso layers (outfit overlay -> armour -> chest rig) are authored directly on the body; the game scales a
layer about the torso centre so it clears the layers worn under it. Shoulder straps keep to lanes: armour and rig
straps at |x| 0.55-0.58, backpack straps at |x| 0.9. Backpacks are authored with their padded back on the torso
(front face z 0.60) and moved back by the worn layers; the shared pack straps end inside every pack body.

Head:        HelmetB (full-cut, covers the ears), FacePlate (HelmetB visor), Headset (band over the head),
             HeadsetNeck (band behind the head, worn with headwear), BoomMic, Mask (gaiter), Cap, Beanie,
             HardHat (the Foreman's signature)
UpperTorso:  CarrierA (slick plate carrier), CarrierPouches (armoured-rig pouches), ArmorCollar (heavy armour),
             SoftVest, ChestRig (front + shoulder harness), ChestRigBack (X harness, hidden under a backpack),
             BodyCam, PackA (patrol), PackRaid, PackCanvas, PackSmall, PackStraps, PaddedJacket, FleeceCollar,
             Hood (worn down)
LowerTorso:  BeltRig      RightUpperLeg: Holster      UpperArm: ArmGuard, Armband, ShoulderMarker
LowerLeg:    KneePads, BootCuffs
First person (viewmodel studs): FPSleeve (unit length along +X), FPCuff
Exports assets/exports/ZR_CharGear.fbx (+ .blend + .meta.json) in its own scene "ZR_CharGear".
"""
import math, os, sys
HERE = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts")
sys.path.insert(0, HERE)
import importlib, zr_lib, zr_char
importlib.reload(zr_lib)
importlib.reload(zr_char)
from zr_lib import hexc, grey, batch_scene, export_batch
from zr_char import CB, lerp_table

R = math.radians
P, PD, WEB, ST, DK = grey(0.86), grey(0.64), grey(0.72), grey(0.5), grey(0.32)
SHELL, SHELL_DARK = grey(0.84), grey(0.62)
FZ, BZ = -0.54 - 0.085, 0.54 + 0.085  # carrier front / back panel centres (UpperTorso space)
EDGE_Y, EDGE_Z = 0.73, 0.42           # centre of the rounded shoulder edge (torso top 0.85, faces z +-0.54, r 0.12)


def shoulder_path(x, r, y_front, y_back=None, n=4):
    """strap centreline over the shoulder at lane x: up the chest, round the rounded shoulder edge (radius r about
    the edge centre), across the top, down the back. r = 0.12 edge + half strap thickness + clearance."""
    zf = -(EDGE_Z + r)
    pts = [(x, y_front, zf), (x, EDGE_Y, zf)]
    for k in range(1, n):
        a = math.pi / 2 * k / n
        pts.append((x, EDGE_Y + r * math.sin(a), -(EDGE_Z + r * math.cos(a))))
    pts += [(x, EDGE_Y + r, -EDGE_Z), (x, EDGE_Y + r, EDGE_Z)]
    for k in range(n - 1, 0, -1):
        a = math.pi / 2 * k / n
        pts.append((x, EDGE_Y + r * math.sin(a), EDGE_Z + r * math.cos(a)))
    pts.append((x, EDGE_Y, EDGE_Z + r))
    if y_back is not None:
        pts.append((x, y_back, EDGE_Z + r))
    return pts


# ── head gear (head 1.26 x 1.16 x 1.18, top y 0.58, front z -0.59, edges rounded r 0.26) ──────────────
HELMET_B_RIM = [(0, 0.17), (40, 0.12), (70, -0.06), (110, -0.1), (150, -0.18), (180, -0.2)]


def helmet_b(b):
    """full-cut patrol helmet: rounder dome down over the temples and ears, cover band, chin straps, rear tab"""
    rim = lambda phi: lerp_table(HELMET_B_RIM, phi)
    b.shell((0, 0.04, 0.02), (0.84, 0.8, 0.83), SHELL, rim, power=2.6, thick=0.06, useg=20, vseg=12, lip_color=SHELL_DARK)
    b.band((0, 0.04, 0.02), (0.84, 0.8, 0.83), 2.6, 0.3, 0.38, DK, seg=24, out=0.012)
    for sx in (-1, 1):
        b.strap([(sx * 0.7, -0.06, 0.1), (sx * 0.67, -0.3, -0.06), (sx * 0.6, -0.54, -0.38)], 0.09, 0.025, ST, up=(sx, 0, 0))
    b.rround((0, 0.62, 0.66), (0.3, 0.12, 0.03), DK, r=0.015, segs=1, rot=(R(-35), 0, 0))


def face_plate(b):
    """steel visor tucked under helmet B's brow: brow strip, eye slot with a centre bar, chin plate, side hinges"""
    S = grey(0.7)
    c, rad, pw = (0, 0, 0.02), (0.8, 0.78), 2.6
    b.arc_plate(c, rad, pw, -72, 72, 0.15, 0.24, 0.05, S, seg=14)
    b.arc_plate(c, rad, pw, -72, 72, -0.5, 0.0, 0.05, S, seg=14)
    b.arc_plate(c, rad, pw, -5, 5, 0.0, 0.15, 0.05, S, seg=1)
    b.arc_plate(c, (0.81, 0.79), pw, -30, 30, -0.36, -0.3, 0.02, grey(0.5), seg=6)  # breathing ridge
    for sx in (-1, 1):
        b.rcyl((sx * 0.77, 0.05, -0.24), (sx * 0.84, 0.05, -0.24), 0.05, DK, seg=8)


def headset(b, neck=False):
    CUP, PAD = grey(0.42), grey(0.26)
    for sx in (-1, 1):
        b.rround((sx * 0.74, -0.02, 0.05), (0.2, 0.52, 0.58), CUP, r=0.08, segs=2)
        b.rround((sx * 0.65, -0.02, 0.05), (0.06, 0.46, 0.5), PAD, r=0.04, segs=1)
        b.rround((sx * 0.85, 0.07, 0.05), (0.04, 0.12, 0.2), grey(0.6), r=0.02, segs=1)  # volume knob plate
    pts = []
    if neck:
        for k in range(9):
            a = math.pi * k / 8
            pts.append((-0.72 * math.cos(a), -0.3, 0.12 + 0.56 * math.sin(a)))
        b.strap(pts, 0.05, 0.1, CUP, up=(0, 1, 0))
    else:
        for k in range(11):
            a = math.pi * k / 10
            pts.append((-0.78 * math.cos(a), 0.2 + 0.5 * math.sin(a), 0.05))
        b.strap(pts, 0.05, 0.14, CUP, up=(0, 0, 1))
        b.rround((0, 0.715, 0.05), (0.5, 0.03, 0.16), PAD, r=0.012, segs=1)  # head pad


def boom_mic(b):
    b.rtube([(-0.8, -0.14, -0.15), (-0.7, -0.3, -0.5), (-0.36, -0.36, -0.68)], 0.025, DK, seg=5)
    b.rround((-0.3, -0.36, -0.69), (0.1, 0.09, 0.09), DK, r=0.04, segs=1)


def mask(b):
    """thin fabric gaiter over the lower face, sides and nape (eyes stay clear)"""
    C = grey(0.6)
    b.rround((0, -0.32, 0.0), (1.31, 0.52, 1.23), C, r=0.2, segs=2)
    b.rround((0, -0.075, 0.0), (1.32, 0.05, 1.24), grey(0.5), r=0.024, segs=1)
    for k in range(3):
        b.rbox((0, -0.22 - k * 0.11, -0.617), (0.86 - k * 0.12, 0.014, 0.012), grey(0.44))


def cap(b):
    C = grey(0.82)
    b.rround((0, 0.5, 0.02), (1.3, 0.24, 1.24), C, r=0.12, segs=2)
    b.rround((0, 0.64, 0.02), (1.12, 0.12, 1.06), C, r=0.06, segs=2)
    b.rround((0, 0.4, -0.84), (0.96, 0.04, 0.52), grey(0.7), r=0.02, segs=1, rot=(R(-8), 0, 0))
    b.rround((0, 0.71, 0.02), (0.1, 0.03, 0.1), grey(0.6), r=0.01, segs=1)
    b.rround((0, 0.5, 0.64), (0.4, 0.1, 0.03), grey(0.55), r=0.01, segs=1)  # back strap


def beanie(b):
    K = grey(0.78)
    b.rround((0, 0.52, 0.0), (1.32, 0.34, 1.24), K, r=0.16, segs=2)
    b.rround((0, 0.36, 0.0), (1.35, 0.14, 1.27), grey(0.68), r=0.06, segs=1)
    b.rround((0, 0.7, 0.0), (0.92, 0.1, 0.86), K, r=0.08, segs=2)


def hardhat(b):
    """the Foreman's battered hard hat: high dome, oval brim with a longer peak, crown ridge, reflective band,
    lamp bracket and a taped crack"""
    W = grey(0.95)
    c, rad, pw = (0, 0.2, 0.0), (0.8, 0.62, 0.86), 2.2
    b.shell(c, rad, W, lambda phi: 0.0, power=pw, thick=0.05, useg=22, vseg=10)
    b.arc_plate((0, 0.18, -0.06), (0.98, 1.06), 2.4, -180, 180, 0.0, 0.045, 0.28, grey(0.9), seg=28, closed=True)
    ridge = []
    for k in range(11):
        t = R(-62 + 124 * k / 10)
        z = 0.88 * math.copysign(abs(math.sin(t)) ** (2 / pw), math.sin(t))
        y = 0.2 + 0.64 * abs(math.cos(t)) ** (2 / pw)
        ridge.append((0, y, z))
    b.strap(ridge, 0.07, 0.16, grey(0.88), up=(1, 0, 0))
    b.band(c, rad, pw, 0.1, 0.16, hexc("D9D4B0"), seg=22, out=0.008)
    b.rround((0, 0.36, -0.85), (0.24, 0.16, 0.05), DK, r=0.02, segs=1, rot=(R(-12), 0, 0))  # lamp bracket
    b.rround((0.3, 0.55, -0.62), (0.06, 0.24, 0.02), grey(0.7), r=0.008, segs=1, rot=(R(-40), 0, R(25)))  # tape


# ── torso gear (UpperTorso 2.16 x 1.70 x 1.08) ──────────────────────────────────────────────────
def carrier_a(b):
    """slick plate carrier: padded front/back plate bags, wrap-round cummerbund, shoulder straps, webbing rows,
    admin flap (no pouches: those are CarrierPouches)"""
    b.rround((0, 0.02, FZ), (1.52, 1.2, 0.17), P, r=0.07, segs=2)
    b.rround((0, 0.02, BZ), (1.52, 1.25, 0.17), P, r=0.07, segs=2)
    b.rround((0, 0.02, FZ + 0.035), (1.58, 1.26, 0.08), PD, r=0.04, segs=1)
    b.rround((0, 0.02, BZ - 0.035), (1.58, 1.31, 0.08), PD, r=0.04, segs=1)
    for sx in (-1, 1):
        b.rround((sx * 1.11, -0.3, 0.0), (0.07, 0.48, 1.3), P, r=0.03, segs=1)            # cummerbund side
        for sz in (-1, 1):
            b.rround((sx * 0.93, -0.3, sz * 0.6), (0.36, 0.48, 0.07), P, r=0.03, segs=1)  # wrap to the plate bags
        b.rround((sx * 1.15, -0.3, -0.26), (0.03, 0.5, 0.08), PD, r=0.012, segs=1)        # velcro tab
        b.strap(shoulder_path(sx * 0.58, 0.163, 0.55, y_back=0.58), 0.07, 0.24, P, up=(1, 0, 0))
        b.rround((sx * 0.58, 0.68, -0.605), (0.26, 0.1, 0.03), PD, r=0.012, segs=1)        # strap buckle
    for k in range(3):
        b.rbox((0, -0.1 - k * 0.16, FZ - 0.093), (1.34, 0.05, 0.022), WEB)
        b.rbox((0, 0.12 - k * 0.18, BZ + 0.093), (1.34, 0.05, 0.022), WEB)
    b.rround((0, 0.42, FZ - 0.11), (0.62, 0.3, 0.06), PD, r=0.03, segs=1)  # admin flap
    b.rbox((0, 0.47, FZ - 0.142), (0.4, 0.012, 0.01), DK)
    b.rround((0, 0.38, BZ + 0.1), (0.5, 0.2, 0.03), PD, r=0.015, segs=1)   # back name tape
    b.ao(-0.85, 0.85, 0.82, 1.0)


def carrier_pouches(b):
    """three rifle-magazine pouches and a radio pouch on CarrierA (the armoured-rig version)"""
    for i in (-1, 0, 1):
        x = i * 0.4
        b.rround((x, -0.3, -0.81), (0.34, 0.46, 0.22), P, r=0.06, segs=2)
        b.rround((x, -0.07, -0.82), (0.36, 0.1, 0.24), PD, r=0.04, segs=1)
        b.rbox((x, -0.15, -0.932), (0.1, 0.1, 0.02), DK)
        b.rbox((x, -0.5, -0.925), (0.24, 0.012, 0.012), grey(0.5))
    b.rround((1.17, -0.2, -0.18), (0.18, 0.5, 0.3), P, r=0.05, segs=2)
    b.rround((1.17, 0.07, -0.18), (0.2, 0.08, 0.32), PD, r=0.03, segs=1)
    b.rcyl((1.18, 0.1, -0.24), (1.18, 0.42, -0.24), 0.028, DK, seg=6)
    b.ao(-0.6, 0.2, 0.8, 1.0)


def armor_collar(b):
    """padded neck protector of the heavy armour (wide enough for the block head to turn inside it)"""
    for sx in (-1, 1):
        b.rround((sx * 0.8, 0.95, 0.06), (0.14, 0.17, 1.2), P, r=0.06, segs=2)
        b.rround((sx * 0.6, 0.94, -0.73), (0.38, 0.16, 0.14), P, r=0.06, segs=2)
    b.rround((0, 0.95, 0.76), (1.66, 0.17, 0.16), P, r=0.06, segs=2)
    b.ao(0.85, 1.05, 0.85, 1.0)


def soft_vest(b):
    fz, bz = -0.54 - 0.05, 0.54 + 0.05
    b.rround((0, -0.02, fz), (1.56, 1.3, 0.1), P, r=0.05, segs=2)
    b.rround((0, -0.02, bz), (1.56, 1.36, 0.1), P, r=0.05, segs=2)
    for sx in (-1, 1):
        b.rround((sx * 1.12, -0.12, 0), (0.08, 0.9, 1.14), P, r=0.04, segs=1)
        for sz in (-1, 1):
            b.rround((sx * 0.93, -0.12, sz * 0.59), (0.36, 0.9, 0.1), P, r=0.04, segs=1)
        b.rround((sx * 1.165, -0.12, -0.3), (0.03, 0.6, 0.22), PD, r=0.012, segs=1)
        b.strap(shoulder_path(sx * 0.58, 0.158, 0.56, y_back=0.6), 0.06, 0.26, P, up=(1, 0, 0))
    b.rround((0, 0.5, fz - 0.06), (0.72, 0.16, 0.03), PD, r=0.015, segs=1)
    for k in range(4):
        b.rbox((0, -0.5 + k * 0.28, fz - 0.052), (1.4, 0.012, 0.01), grey(0.6))  # quilting
    b.ao(-0.85, 0.85, 0.85, 1.0)


def chest_rig(b):
    """open chest rig: pouch panel low on the chest, padded shoulder harness and side straps"""
    fz = -0.54 - 0.06
    b.rround((0, -0.3, fz), (1.5, 0.62, 0.12), P, r=0.05, segs=2)
    for i in range(4):
        x = -0.54 + i * 0.36
        b.rround((x, -0.32, fz - 0.15), (0.3, 0.46, 0.2), P, r=0.05, segs=2)
        b.rround((x, -0.11, fz - 0.16), (0.32, 0.1, 0.22), PD, r=0.03, segs=1)
        b.rbox((x, -0.18, fz - 0.262), (0.08, 0.08, 0.016), DK)
    for sx in (-1, 1):
        b.strap(shoulder_path(sx * 0.55, 0.153, -0.02, y_back=0.55), 0.05, 0.2, ST, up=(1, 0, 0))
        b.rbox((sx * 1.105, -0.32, 0.0), (0.04, 0.12, 1.18), ST)
        b.rbox((sx * 0.93, -0.32, 0.585), (0.36, 0.12, 0.04), ST)
    b.ao(-0.7, 0.9, 0.8, 1.0)


def chest_rig_back(b):
    """X harness across the back (a backpack covers it)"""
    z1, z2 = 0.42 + 0.153, 0.42 + 0.153 + 0.03
    b.strap([(0.55, 0.55, z1), (0.1, 0.12, z1), (-0.75, -0.32, z1)], 0.05, 0.2, ST, up=(1, 0, 0))
    b.strap([(-0.55, 0.55, z2), (-0.1, 0.12, z2), (0.75, -0.32, z2)], 0.05, 0.2, ST, up=(1, 0, 0))
    b.rbox((0, -0.32, 0.585), (1.5, 0.12, 0.04), ST)


def body_cam(b):
    b.rround((-0.55, 0.42, -0.62), (0.3, 0.4, 0.14), hexc("1E2022"), r=0.04, segs=2)
    b.rcyl((-0.55, 0.49, -0.69), (-0.55, 0.49, -0.73), 0.07, hexc("0C0D0E"), seg=10)
    b.rbox((-0.47, 0.3, -0.695), (0.05, 0.04, 0.02), hexc("C24A35"))
    b.rbox((-0.55, 0.42, -0.535), (0.2, 0.3, 0.05), hexc("2C2F31"))


def pack(b, s=1.0, top_roll=False, frame=False):
    z0 = 0.54 + 0.06
    D, W, H = 0.72 * s, 1.46 * s, 1.62 * s
    cz, cy = z0 + D / 2, -0.02
    b.rround((0, cy - H * 0.22, cz), (W, H * 0.56, D), P, r=0.16, segs=2)
    b.rround((0, cy + H * 0.2, cz - 0.03), (W * 0.9, H * 0.5, D * 0.86), P, r=0.16, segs=2)
    b.rround((0, cy + H * 0.45, cz - 0.02), (W * 0.92, H * 0.12, D * 0.95), PD, r=0.05, segs=1)
    b.rround((0, cy - H * 0.25, cz + D / 2 + 0.07), (W * 0.7, H * 0.36, 0.16), P, r=0.06, segs=2)
    for k in range(3):
        b.rbox((0, cy - H * 0.16 - k * 0.13, cz + D / 2 + 0.152), (W * 0.62, 0.045, 0.02), PD)
    for sx in (-1, 1):
        b.rround((sx * (W / 2 + 0.06), cy - H * 0.2, cz), (0.14, H * 0.45, D * 0.7), P, r=0.05, segs=2)
        b.rbox((sx * W * 0.32, cy, cz + D / 2 + 0.012), (0.05, H * 0.9, 0.02), ST)
    b.rround((0, 0.0, z0 - 0.03), (W * 0.8, H * 0.8, 0.06), PD, r=0.03, segs=1)  # padded back
    b.rround((0, cy + H * 0.52, cz - 0.1), (0.3, 0.05, 0.08), ST, r=0.02, segs=1)  # grab handle
    if top_roll:
        b.rcyl((-W * 0.5, cy + H * 0.6, cz), (W * 0.5, cy + H * 0.6, cz), 0.2 * s, grey(0.7), seg=10)
        for sx in (-1, 1):
            b.rround((sx * W * 0.3, cy + H * 0.6, cz), (0.06, 0.44 * s, 0.44 * s), ST, r=0.02, segs=1)
    if frame:
        for sx in (-1, 1):
            b.rcyl((sx * W * 0.46, cy - H * 0.5, z0 + 0.02), (sx * W * 0.46, cy + H * 0.62, z0 + 0.02), 0.035, DK, seg=6)
        b.rcyl((-W * 0.46, cy + H * 0.62, z0 + 0.02), (W * 0.46, cy + H * 0.62, z0 + 0.02), 0.035, DK, seg=6)
    b.ao(-0.85 * s - 0.6, 0.85 * s, 0.75, 1.0)


def pack_canvas(b):
    z0 = 0.54 + 0.05
    b.rround((0, -0.2, z0 + 0.32), (1.32, 1.24, 0.62), P, r=0.28, segs=2)
    b.rround((0, 0.38, z0 + 0.3), (1.0, 0.18, 0.5), PD, r=0.08, segs=1)                     # drawstring neck
    b.rround((0, 0.22, z0 + 0.6), (1.06, 0.62, 0.08), PD, r=0.06, segs=1, rot=(R(12), 0, 0))  # flap
    b.rround((0, -0.38, z0 + 0.66), (0.8, 0.46, 0.14), P, r=0.08, segs=1)
    for sx in (-1, 1):
        b.rbox((sx * 0.28, 0.0, z0 + 0.66), (0.06, 0.5, 0.02), ST, rot=(R(12), 0, 0))       # flap straps
    b.ao(-0.9, 0.5, 0.78, 1.0)


def pack_small(b):
    z0 = 0.54 + 0.06
    b.rround((0, 0.12, z0 + 0.25), (1.1, 1.05, 0.5), P, r=0.18, segs=2)
    b.rround((0, -0.05, z0 + 0.53), (0.8, 0.5, 0.1), PD, r=0.06, segs=1)
    b.rbox((0, 0.21, z0 + 0.585), (0.7, 0.014, 0.012), DK)
    b.rround((0, 0.12, z0 - 0.02), (0.9, 0.85, 0.05), PD, r=0.025, segs=1)
    b.rround((0, 0.66, z0 + 0.2), (0.28, 0.05, 0.08), ST, r=0.02, segs=1)
    b.ao(-0.45, 0.7, 0.78, 1.0)


def pack_straps(b):
    """padded shoulder straps shared by every backpack: down the chest at |x| 0.9 (outside the armour lanes),
    back ends inside the pack body"""
    for sx in (-1, 1):
        pts = shoulder_path(sx * 0.9, 0.153, 0.4)
        pts += [(sx * 0.86, 0.6, 0.64), (sx * 0.7, 0.5, 0.78), (sx * 0.45, 0.3, 0.9)]
        b.strap(pts, 0.05, 0.18, ST, up=(1, 0, 0))
        b.rround((sx * 0.9, 0.38, -0.585), (0.16, 0.08, 0.05), DK, r=0.015, segs=1)  # adjuster buckle
        b.rbox((sx * 0.9, 0.26, -0.585), (0.06, 0.2, 0.015), ST)                     # loose strap end


def padded_jacket(b):
    b.rround((0, -0.05, 0), (2.28, 1.66, 1.22), P, r=0.16, segs=2)
    for k in range(5):
        b.rround((0, -0.62 + k * 0.3, 0), (2.3, 0.024, 1.24), PD, r=0.01, segs=1)
    b.rbox((0, -0.05, -0.616), (0.05, 1.5, 0.02), DK)
    for sx in (-1, 1):
        b.rround((sx * 0.6, -0.48, -0.62), (0.5, 0.36, 0.05), PD, r=0.03, segs=1)  # hand-warmer pockets


def fleece_collar(b):
    b.rround((0, 0.8, 0.12), (1.52, 0.28, 1.14), grey(0.95), r=0.13, segs=2)
    b.rround((0, 0.73, -0.47), (0.5, 0.2, 0.08), grey(0.8), r=0.04, segs=1)  # chest tab


def hood(b):
    """hood worn down, bunched behind the neck"""
    b.rround((0, 0.79, 0.7), (1.24, 0.3, 0.36), P, r=0.14, segs=2)
    b.rround((0, 0.66, 0.86), (0.92, 0.3, 0.1), grey(0.78), r=0.05, segs=1)
    for sx in (-1, 1):
        b.rcyl((sx * 0.3, 0.72, -0.56), (sx * 0.31, 0.3, -0.57), 0.018, grey(0.9), seg=5)  # drawstrings


# ── lower torso / legs / arms ─────────────────────────────────────────────────────────────────────
def belt_rig(b):
    """battle belt with pouches at the back and back corners (clear of the thighs and the hanging hands)"""
    b.rround((0, 0.02, 0), (2.24, 0.2, 1.16), ST, r=0.04, segs=1)
    b.rbox((0, 0.02, -0.59), (0.28, 0.16, 0.04), grey(0.75))
    for x, z, side in ((-0.5, 0.66, False), (0.5, 0.66, False), (-0.9, 0.5, True), (0.9, 0.5, True)):
        rot = (0, R(-35 if x > 0 else 35), 0) if side else None
        b.rround((x, -0.05, z), (0.38, 0.36, 0.22), P, r=0.06, segs=2, rot=rot)
        b.rround((x, 0.12, z + 0.01), (0.4, 0.08, 0.24), PD, r=0.03, segs=1, rot=rot)


def holster(b):
    b.rround((0.62, -0.05, 0.05), (0.16, 0.62, 0.4), grey(0.4), r=0.05, segs=2)
    b.rround((0.64, 0.33, 0.0), (0.2, 0.22, 0.32), grey(0.25), r=0.04, segs=1)
    for y in (0.15, -0.25):
        b.rround((0, y, 0), (1.12, 0.08, 1.12), grey(0.32), r=0.03, segs=1)


def arm_guard(b):
    b.rround((0, 0.2, 0), (1.16, 0.6, 1.16), P, r=0.14, segs=2)
    b.rround((0, 0.52, 0), (1.0, 0.08, 1.0), PD, r=0.04, segs=1)
    b.rround((0, -0.12, 0), (1.18, 0.08, 1.18), ST, r=0.03, segs=1)


def knee_pads(b):
    b.rround((0, 0.24, -0.6), (0.72, 0.4, 0.14), grey(0.42), r=0.07, segs=2)
    b.rround((0, 0.24, -0.672), (0.5, 0.26, 0.02), grey(0.3), r=0.03, segs=1)
    b.rround((0, 0.22, 0), (1.1, 0.07, 1.1), grey(0.3), r=0.03, segs=1)


def boot_cuffs(b):
    b.rround((0, -0.3, 0.0), (1.12, 0.32, 1.12), grey(0.86), r=0.06, segs=2)
    b.rround((0, -0.15, 0), (1.14, 0.04, 1.14), grey(0.6), r=0.02, segs=1)
    for k in range(3):
        b.rbox((0, -0.4 + k * 0.08, -0.565), (0.36, 0.025, 0.02), grey(0.96))


def armband(b):
    b.rround((0, 0.05, 0), (1.09, 0.22, 1.09), grey(0.92), r=0.04, segs=1)


def shoulder_marker(b):
    b.rround((0, 0.5, 0), (0.74, 0.06, 0.42), grey(0.92), r=0.02, segs=1)
    b.rround((0, 0.16, 0), (1.08, 0.12, 1.08), grey(0.96), r=0.03, segs=1)
    b.rround((0, 0.16, 0), (1.09, 0.03, 1.09), hexc("C8C8BE"), r=0.01, segs=1)


# ── first person (viewmodel studs) ────────────────────────────────────────────────────────────────
def fp_sleeve(b):
    """block sleeve segment, unit length along X (the viewmodel stretches X to the bone length)"""
    b.rround((0, 0, 0), (1.0, 0.25, 0.25), P, r=0.06, segs=2)
    b.rbox((0, 0.126, 0), (0.98, 0.006, 0.02), PD)


def fp_cuff(b):
    b.rround((0, 0, 0), (0.08, 0.27, 0.27), PD, r=0.03, segs=1)


PIECES = [
    ("ZR_EQ_HelmetB", helmet_b), ("ZR_EQ_FacePlate", face_plate), ("ZR_EQ_Headset", lambda b: headset(b)),
    ("ZR_EQ_HeadsetNeck", lambda b: headset(b, neck=True)), ("ZR_EQ_BoomMic", boom_mic), ("ZR_EQ_Mask", mask),
    ("ZR_EQ_Cap", cap), ("ZR_EQ_Beanie", beanie), ("ZR_EQ_HardHat", hardhat),
    ("ZR_EQ_CarrierA", carrier_a), ("ZR_EQ_CarrierPouches", carrier_pouches), ("ZR_EQ_ArmorCollar", armor_collar),
    ("ZR_EQ_SoftVest", soft_vest), ("ZR_EQ_ChestRig", chest_rig), ("ZR_EQ_ChestRigBack", chest_rig_back),
    ("ZR_EQ_BodyCam", body_cam), ("ZR_EQ_PackA", lambda b: pack(b)), ("ZR_EQ_PackRaid", lambda b: pack(b, 1.22, top_roll=True, frame=True)),
    ("ZR_EQ_PackCanvas", pack_canvas), ("ZR_EQ_PackSmall", pack_small), ("ZR_EQ_PackStraps", pack_straps),
    ("ZR_EQ_BeltRig", belt_rig), ("ZR_EQ_Holster", holster), ("ZR_EQ_ArmGuard", arm_guard),
    ("ZR_OV_PaddedJacket", padded_jacket), ("ZR_OV_FleeceCollar", fleece_collar), ("ZR_OV_Hood", hood),
    ("ZR_OV_KneePads", knee_pads), ("ZR_OV_BootCuffs", boot_cuffs), ("ZR_OV_Armband", armband), ("ZR_OV_ShoulderMarker", shoulder_marker),
    ("ZR_FP_Sleeve", fp_sleeve), ("ZR_FP_Cuff", fp_cuff),
]


def build(scene):
    col = scene.collection
    objs = []
    for name, fn in PIECES:
        b = CB(name)
        fn(b)
        objs.append(b.finish(col))
    return objs


if not globals().get("ZR_NO_EXPORT"):
    scene = batch_scene("ZR_CharGear")
    objs = build(scene)
    fbx, blend, meta = export_batch(objs, "ZR_CharGear", scene)
    print("ZR_CharGear exported", fbx, os.path.getsize(fbx), "bytes,", len(objs), "objects,", sum(m["tris"] for m in meta.values()), "tris")
    for k in sorted(meta):
        print(k, meta[k]["tris"], "size", meta[k]["size"], "center", meta[k]["center"])

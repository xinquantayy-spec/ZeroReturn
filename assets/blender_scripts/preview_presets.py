"""Zero Return - Blender fit preview of the M16 role presets (operator, two scavengers, guard, bodyguard, Foreman)
using the ZR_CharBase body and the ZR_CharGear equipment, with the same layering rules as the game
(src/shared/Equipment.luau: a torso layer is scaled about the torso centre by the shells worn under it, backpacks
move back by the worn shells, the body cam forward). Renders front / side / back lineups in a separate scene.
   g = {"OUT": r"C:/.../docs/character/evidence"}; exec(open(r"<project>/assets/blender_scripts/preview_presets.py").read(), g)
"""
import os, sys
HERE = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts")
sys.path.insert(0, HERE)
import importlib, zr_preview
importlib.reload(zr_preview)
from zr_preview import lineup, spec

OUT = globals().get("OUT") or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "docs", "character", "evidence")
TAG = globals().get("TAG", "v1")
os.makedirs(OUT, exist_ok=True)

# torso layer shells (front, back, top, side) - mirror of Equipment.SHELLS
SHELL = {"jacket": (0.07, 0.07, 0.0, 0.07), "vest": (0.1, 0.1, 0.07, 0.08), "carrier": (0.17, 0.17, 0.08, 0.07), "rig": (0.05, 0.05, 0.0, 0.0)}


def inflate(*layers):
    f = sum(SHELL[l][0] for l in layers)
    bk = sum(SHELL[l][1] for l in layers)
    t = sum(SHELL[l][2] for l in layers)
    sd = sum(SHELL[l][3] for l in layers)
    return {"scale": ((2.16 + 2 * sd) / 2.16, (1.7 + 2 * t) / 1.7, (1.08 + f + bk) / 1.08), "shift": (0, 0, (bk - f) / 2)}


def back(*layers):
    return {"shift": (0, 0, sum(SHELL[l][1] for l in layers))}


def front(*layers):
    return {"shift": (0, 0, -sum(SHELL[l][0] for l in layers))}


CLOTH = {"UpperTorso": "jacket", "LeftUpperArm": "jacket", "RightUpperArm": "jacket", "LeftLowerArm": "jacket", "RightLowerArm": "jacket",
         "LowerTorso": "pants", "LeftUpperLeg": "pants", "RightUpperLeg": "pants", "LeftLowerLeg": "pants", "RightLowerLeg": "pants",
         "Head": "skin", "LeftHand": "glove", "RightHand": "glove", "LeftFoot": "boot", "RightFoot": "boot"}
LOOKS = {
    "operator": dict(jacket="#5A6047", pants="#40433A", skin="#C9A58A", glove="#2A2B29", boot="#5A4936"),
    "scav": dict(jacket="#5C554A", pants="#3D3B36", skin="#C4A386", glove="#4A4134", boot="#4A3F33"),
    "scav2": dict(jacket="#4B5560", pants="#4A4438", skin="#BF9C80", glove="#3A3631", boot="#3E352C"),
    "guard": dict(jacket="#3B4652", pants="#2E343A", skin="#BF9C80", glove="#1E2022", boot="#2A2826"),
    "bodyguard": dict(jacket="#2B2F33", pants="#25282B", skin="#C9A58A", glove="#1A1B1C", boot="#222120"),
    "foreman": dict(jacket="#7E5F36", pants="#3B3A35", skin="#B8957A", glove="#3A2F25", boot="#4A3A2A"),
}


def body(look):
    L = LOOKS[look]
    return [("ZR_BLK_" + n, n, L[CLOTH[n]]) for n in spec()["parts"]]


def both(key, part, tint, opts=None):
    out = []
    for side in ("Left", "Right"):
        e = (key, side + part, tint) + ((opts,) if opts else ())
        out.append(e)
    return out


OPERATOR = body("operator") + [
    ("ZR_EQ_HelmetA", "Head", "#4E5240"), ("ZR_EQ_HeadsetNeck", "Head", "#3A3D36"),
    ("ZR_EQ_CarrierA", "UpperTorso", "#5F5E46"), ("ZR_EQ_CarrierPouches", "UpperTorso", "#5F5E46"),
    ("ZR_EQ_BodyCam", "UpperTorso", "#FFFFFF", front("carrier")),
    ("ZR_EQ_PackA", "UpperTorso", "#6B6A4E", back("carrier")), ("ZR_EQ_PackStraps", "UpperTorso", "#55553F"),
    ("ZR_EQ_BeltRig", "LowerTorso", "#5F5E46"), ("ZR_EQ_Holster", "RightUpperLeg", "#2E3134"),
] + both("ZR_OV_KneePads", "LowerLeg", "#3A3C35")
SCAV_A = body("scav") + [
    ("ZR_EQ_Beanie", "Head", "#3A3833"), ("ZR_EQ_Mask", "Head", "#6B6B5E"),
    ("ZR_EQ_ChestRig", "UpperTorso", "#5E5A47"), ("ZR_EQ_PackCanvas", "UpperTorso", "#6B6A4E"), ("ZR_EQ_PackStraps", "UpperTorso", "#55503F"),
]
SCAV_B = body("scav2") + [
    ("ZR_EQ_Cap", "Head", "#4A4A3E"), ("ZR_OV_Hood", "UpperTorso", "#4B5560"), ("ZR_EQ_BeltRig", "LowerTorso", "#5E5A47"),
    ("ZR_EQ_SoftVest", "UpperTorso", "#3E4A3A"),
]
GUARD = body("guard") + [
    ("ZR_EQ_HelmetB", "Head", "#1F2326"), ("ZR_EQ_SoftVest", "UpperTorso", "#2B2F33"),
    ("ZR_EQ_ChestRig", "UpperTorso", "#2B2F33", inflate("vest")), ("ZR_EQ_ChestRigBack", "UpperTorso", "#2B2F33", inflate("vest")),
    ("ZR_OV_Armband", "LeftUpperArm", "#B59B3A"),
] + both("ZR_OV_KneePads", "LowerLeg", "#26292B")
BODYGUARD = body("bodyguard") + [
    ("ZR_EQ_HelmetA", "Head", "#22252A"), ("ZR_EQ_HeadsetNeck", "Head", "#2A2C2E"), ("ZR_EQ_BoomMic", "Head", "#2A2C2E"),
    ("ZR_EQ_CarrierA", "UpperTorso", "#2A2D2F"), ("ZR_EQ_ChestRig", "UpperTorso", "#2A2D2F", inflate("carrier")),
    ("ZR_EQ_PackSmall", "UpperTorso", "#2E3133", back("carrier")), ("ZR_EQ_PackStraps", "UpperTorso", "#2A2D2F"),
] + both("ZR_OV_ShoulderMarker", "UpperArm", "#D8D2C0") + both("ZR_OV_KneePads", "LowerLeg", "#202224")
FOREMAN = body("foreman") + [
    ("ZR_EQ_HardHat", "Head", "#D4A93A"), ("ZR_OV_PaddedJacket", "UpperTorso", "#7E5F36"), ("ZR_OV_FleeceCollar", "UpperTorso", "#CFC6B0"),
    ("ZR_EQ_ChestRig", "UpperTorso", "#3B3A33", inflate("jacket")), ("ZR_EQ_ChestRigBack", "UpperTorso", "#3B3A33", inflate("jacket")),
    ("ZR_EQ_BeltRig", "LowerTorso", "#3B3A33"),
] + both("ZR_OV_BootCuffs", "LowerLeg", "#8A8478")

ROSTER = [OPERATOR, SCAV_A, SCAV_B, GUARD, BODYGUARD, FOREMAN]
files = []
for yaw, name in ((0, "front"), (90, "side"), (180, "back")):
    files.append(lineup(ROSTER, os.path.join(OUT, "C09_roster_%s_%s.png" % (name, TAG)), yaw=yaw, size=(2600, 760), spacing=4.5, focus_y=2.75))
# close-ups: operator and Foreman, three-quarter front / back
files.append(lineup([(OPERATOR, 35), (OPERATOR, 215), (FOREMAN, 35), (FOREMAN, 215)], os.path.join(OUT, "C09_closeup_operator_foreman_%s.png" % TAG), size=(2000, 900), spacing=4.6, focus_y=2.8))
files.append(lineup([(GUARD, 35), (BODYGUARD, 35), (SCAV_A, 215), (BODYGUARD, 215)], os.path.join(OUT, "C09_closeup_guard_scav_%s.png" % TAG), size=(2000, 900), spacing=4.6, focus_y=2.8))
print("\n".join(files))

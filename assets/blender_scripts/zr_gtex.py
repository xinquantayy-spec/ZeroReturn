"""Zero Return - art-4b, worn gear: PBR texture sheets for the character equipment batch (ZR_CharGear).

Tarkov's armour, rigs, packs and headwear are textured PBR models: woven nylon with seams, binding tape and stitching
along the panel edges, dirt in the folds, scuffed edges, painted or moulded shells. Ours are build_char_gear.py's
low-poly pieces (neutral greys tinted per item in game); this module gives them the same kind of maps without changing
their shape, with zr_tex's machinery (the gun sheets):

  colour  the vertex colours (neutral greys and the fixed accents) with grime along concave edges, edges scuffed
          lighter in patches and a faint 2 cm mottle; it stays neutral so SurfaceAppearance.Color tints it per item,
          as MeshPart.Color tinted the vertex colours
  normal  edges rounded by Cycles' bevel (4 mm), and on fabric a woven grain and soft creases
  rough   fabric about 0.9, shells and plastics lower, scuffs and grime varied
  metal   0 (no bare metal on the gear)

Each piece is one finish (FINISH below); the pieces go on four sheets by where they are worn (SHEETS: head, torso,
packs and overlays at 1024 px, about 0.25 to 0.4 px per mm; the first-person sleeve and cuff on a 512 px sheet of their
own, seen up close all raid), so a character loads few sheets. The batch is exported again with these UVs and without vertex colours; the game
clones each sheet's SurfaceAppearance (src/shared/ZR_GearSA, GearTex.luau, tools/gun_tex.py --gear) into the pieces and
sets its Color to the item's tint.

Run inside Blender, a step per MCP call:
    import zr_gtex as GT
    GT.prepare()          # build the pieces, assign finishes, pack and unwrap the sheets -> sheet summary
    GT.bake(45)           # zr_tex.bake: repeat until nothing is left
    GT.look(sheet)        # optional: a render of the sheet's pieces with their maps, for review
    GT.export()           # PNGs to assets/textures/gear, ZR_CharGear.fbx with UVs, ZR_CharGear.tex.json
"""
import bpy, os, math, importlib
import zr_tex
from zr_lib import EXP, ROOT

BATCH = "ZR_CharGear"
TEX = os.path.join(ROOT, "assets", "textures", "gear")
SPREAD = 3.5                 # studs between pieces while baking
MM = zr_tex.MM

# the finish of each piece (default fabric): shells and moulded plastic apart from the woven gear
FINISH = {
    "ZR_EQ_HelmetB": "shell", "ZR_EQ_HardHat": "plastic", "ZR_EQ_FacePlate": "shell", "ZR_EQ_BodyCam": "plastic",
    "ZR_EQ_BoomMic": "plastic", "ZR_EQ_Headset": "plastic", "ZR_EQ_HeadsetNeck": "plastic",
}
# zr_tex's finishes plus the gear's own: fabric scuffs lighter at the edges; the shell is a painted composite
GFIN = {
    "fabric": dict(r=0.9, m=0.0, wear=0.3, wc=None, wr=0.97, wm=0.0, bevel=4.0, weave=0.5, crease=0.6),
    "shell": dict(r=0.62, m=0.0, wear=0.35, wc=None, wr=0.5, wm=0.0, bevel=4.0, weave=0.0, crease=0.0),
    "plastic": dict(r=0.5, m=0.0, wear=0.25, wc=None, wr=0.4, wm=0.0, bevel=2.5, weave=0.0, crease=0.0),
}
MASK_KW = dict(wear_in=3.0 * MM, wear_out=10.0 * MM, grime_in=4.0 * MM, grime_out=20.0 * MM, sharp=math.radians(30))
STATE = {}
_GUN_MATERIAL = [zr_tex._material]   # zr_tex's own bake material builder (prepare() swaps zr_tex._material while packing)


def _gear_material(fin):
    """zr_tex's bake material for the nearest gun finish, with the gear's bevel and, on fabric, a woven grain and
    creases in the normal pass"""
    g = GFIN[fin]
    base = {"fabric": "fabric", "shell": "polymer", "plastic": "plastic"}[fin]
    saved = dict(zr_tex.FIN[base])
    zr_tex.FIN[base] = dict(saved, r=g["r"], m=g["m"], wear=g["wear"], wc=g["wc"], wr=g["wr"], wm=g["wm"])
    try:
        mat = _GUN_MATERIAL[0](base)
    finally:
        zr_tex.FIN[base] = saved
    mat.name = "ZR_GX_" + fin
    nt = mat.node_tree
    N, L = nt.nodes.new, nt.links.new
    bev = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeBevel")
    bev.inputs["Radius"].default_value = g["bevel"] * MM
    if g["weave"] > 0 or g["crease"] > 0:
        tc = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeTexCoord")

        def mathn(op, a, b):
            n = N("ShaderNodeMath")
            n.operation = op
            for i, v in ((0, a), (1, b)):
                if isinstance(v, (int, float)):
                    n.inputs[i].default_value = v
                else:
                    L(v, n.inputs[i])
            return n.outputs[0]

        # woven grain: a 6 mm noise (a texel is 2.5 to 4 mm on the body sheets; anything finer would alias into speckle);
        # creases (below); a 6 cm mottle of wear and dirt
        weave = N("ShaderNodeTexNoise")
        weave.inputs["Scale"].default_value = 1.0 / (6.0 * MM)
        weave.inputs["Detail"].default_value = 2.0
        L(tc.outputs["Object"], weave.inputs["Vector"])
        # creases: a 5 cm noise stretched three times along the piece's up axis (wave bands read as corduroy)
        cmap = N("ShaderNodeMapping")
        cmap.inputs["Scale"].default_value = (1.0, 1.0, 1.0 / 3.0)
        L(tc.outputs["Object"], cmap.inputs["Vector"])
        crease = N("ShaderNodeTexNoise")
        crease.inputs["Scale"].default_value = 1.0 / (50.0 * MM)
        crease.inputs["Detail"].default_value = 1.5
        crease.inputs["Distortion"].default_value = 0.6
        L(cmap.outputs["Vector"], crease.inputs["Vector"])
        mott = N("ShaderNodeTexNoise")
        mott.inputs["Scale"].default_value = 1.0 / (60.0 * MM)
        mott.inputs["Detail"].default_value = 3.0
        L(tc.outputs["Object"], mott.inputs["Vector"])
        # the normal pass: grain and creases as a height on the bevelled normal
        height = mathn("ADD", mathn("MULTIPLY", weave.outputs["Fac"], g["weave"]), mathn("MULTIPLY", crease.outputs["Fac"], g["crease"]))
        bump = N("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 1.0
        bump.inputs["Distance"].default_value = 2.5 * MM
        L(height, bump.inputs["Height"])
        L(bev.outputs["Normal"], bump.inputs["Normal"])
        bsdf = nt.nodes["BSDF"]
        for l in list(bsdf.inputs["Normal"].links):
            nt.links.remove(l)
        L(bump.outputs["Normal"], bsdf.inputs["Normal"])
        # the colour: the creases' hollows a shade darker, the mottle +-12 %, the grain +-4 % (it stays neutral: the
        # item's tint multiplies it in game)
        coat = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeVectorMath" and n.operation == "SCALE")
        k0 = coat.inputs["Scale"].links[0].from_socket
        shade = mathn("SUBTRACT", 1.0, mathn("MULTIPLY", mathn("SUBTRACT", 1.0, crease.outputs["Fac"]), 0.06))
        mot = mathn("ADD", 0.88, mathn("MULTIPLY", mott.outputs["Fac"], 0.24))
        grn = mathn("ADD", 0.98, mathn("MULTIPLY", weave.outputs["Fac"], 0.04))
        L(mathn("MULTIPLY", mathn("MULTIPLY", k0, shade), mathn("MULTIPLY", mot, grn)), coat.inputs["Scale"])
    mat["zr_fin"] = fin
    return mat


def _build_pieces(scn):
    g = {"ZR_NO_EXPORT": True, "__name__": "zr_gtex_build"}
    path = os.path.join(ROOT, "assets", "blender_scripts", "build_char_gear.py")
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), g)
    return g["build"](scn)


# four sheets by where the gear is worn, so a character loads few of them: the density of each follows from what it
# holds (pack_islands scales its islands to fill the sheet); the first-person sleeve, seen up close all raid, gets a
# small sheet of its own at a far higher density
SHEETS = [
    ("ZR_GR_Head", 1024, ["ZR_EQ_HelmetB", "ZR_EQ_FacePlate", "ZR_EQ_Headset", "ZR_EQ_HeadsetNeck", "ZR_EQ_BoomMic", "ZR_EQ_Mask",
                          "ZR_EQ_Cap", "ZR_EQ_Beanie", "ZR_EQ_HardHat"]),
    ("ZR_GR_Torso", 1024, ["ZR_EQ_CarrierA", "ZR_EQ_CarrierPouches", "ZR_EQ_ArmorCollar", "ZR_EQ_SoftVest", "ZR_EQ_ChestRig",
                           "ZR_EQ_ChestRigBack", "ZR_EQ_BodyCam", "ZR_EQ_BeltRig", "ZR_EQ_Holster", "ZR_EQ_ArmGuard"]),
    ("ZR_GR_Pack", 1024, ["ZR_EQ_PackA", "ZR_EQ_PackRaid", "ZR_EQ_PackCanvas", "ZR_EQ_PackSmall", "ZR_EQ_PackStraps",
                          "ZR_OV_PaddedJacket", "ZR_OV_FleeceCollar", "ZR_OV_Hood", "ZR_OV_KneePads", "ZR_OV_BootCuffs",
                          "ZR_OV_Armband", "ZR_OV_ShoulderMarker"]),
    ("ZR_GR_FP", 512, ["ZR_FP_Sleeve", "ZR_FP_Cuff"]),
]


def _clear_sheets():
    st = zr_tex.STATE.get(BATCH)
    for sh in (st or {}).get("sheets", []):
        for img in sh["imgs"].values():
            im = bpy.data.images.get(img)
            if im:
                bpy.data.images.remove(im)


def pack():
    """the pieces into SHEETS, each sheet unwrapped into one UV space, bake materials and empty images"""
    st = zr_tex.STATE[BATCH]
    scn = bpy.data.scenes[st["scene"]]
    _clear_sheets()
    known = {n for _, _, names in SHEETS for n in names}
    missing = [n for n in st["all"] if n not in known]
    assert not missing, "pieces with no sheet: %s" % missing
    mats, out = {}, []
    with zr_tex._in_scene(scn):
        for name, size, names in SHEETS:
            sobjs = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
            for o in scn.objects:
                o.select_set(False)
            for o in sobjs:
                o.select_set(True)
                fin = o["zr_mat"]
                if fin not in mats:
                    mats[fin] = _gear_material(fin)
                o.data.materials.clear()
                o.data.materials.append(mats[fin])
                o["zr_sheet"] = name
            bpy.context.view_layer.objects.active = sobjs[0]
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
            bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.004)
            bpy.ops.object.mode_set(mode="OBJECT")
            imgs = {
                "mask": zr_tex._image(name + "_mask", (0, 0, 0, 1), True, size),
                "color": zr_tex._image(name + "_col", (0.5, 0.5, 0.5, 1), False, size),
                "rough": zr_tex._image(name + "_rgh", (0.5, 0.5, 0.5, 1), True, size),
                "metal": zr_tex._image(name + "_mtl", (0, 0, 0, 1), True, size),
                "normal": zr_tex._image(name + "_nrm", (0.5, 0.5, 1.0, 1), True, size),
            }
            area = sum(zr_tex._area(o) for o in sobjs)
            out.append({"name": name, "objs": [o.name for o in sobjs], "imgs": {k: v.name for k, v in imgs.items()},
                        "done": [], "area": round(area, 3), "size": size, "mask_kw": MASK_KW,
                        "px_per_stud": round(size * (0.6 / max(area, 1e-6)) ** 0.5)})
    st["sheets"] = out
    return [(s["name"], len(s["objs"]), s["area"], s["px_per_stud"]) for s in out]


def prepare():
    """build the gear pieces in their own scene, give each its finish, then pack(); returns pack()'s summary"""
    importlib.reload(zr_tex)
    _GUN_MATERIAL[0] = zr_tex._material
    scn = zr_tex._scene(BATCH)
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    objs = _build_pieces(scn)
    for i, o in enumerate(sorted(objs, key=lambda o: o.name)):
        o["zr_mat"] = FINISH.get(o.name, "fabric")
        o.location.x += (i % 6) * SPREAD
        o.location.z += (i // 6) * SPREAD
    zr_tex.STATE[BATCH] = {"scene": scn.name, "parts": [(o.name, [o.name]) for o in objs], "all": [o.name for o in objs],
                           "sheets": [], "times": {}}
    return pack()


def rebake():
    """forget the baked passes (pieces and UVs stay) and rebuild the gear materials, after a change to them"""
    st = zr_tex.STATE[BATCH]
    mats = {}
    for sh in st["sheets"]:
        sh["done"] = []
        for n in sh["objs"]:
            o = bpy.data.objects[n]
            fin = o["zr_mat"]
            if fin not in mats:
                mats[fin] = _gear_material(fin)
            o.data.materials.clear()
            o.data.materials.append(mats[fin])
    return len(mats)


def bake(seconds=45.0, only=None):
    return zr_tex.bake(BATCH, seconds, only)


def export():
    """the sheets' PNGs to assets/textures/gear, ZR_CharGear.fbx again with these UVs and no vertex colours, its
    meta and ZR_CharGear.tex.json"""
    saved = (zr_tex.TEX, zr_tex.PX_PER_STUD)
    zr_tex.TEX = TEX
    zr_tex.PX_PER_STUD = min(sh["px_per_stud"] for sh in zr_tex.STATE[BATCH]["sheets"])   # the record's px_per_mm: the lowest
    objs = [bpy.data.objects[n] for n in zr_tex.STATE[BATCH]["all"]]
    for o in objs:   # the FBX's material slot only names the finish; the item render materials have no "shell"
        if o["zr_mat"] == "shell":
            o["zr_mat"] = "polymer"
    try:
        return zr_tex.export(BATCH)
    finally:
        zr_tex.TEX, zr_tex.PX_PER_STUD = saved
        for o in objs:
            if o.name in FINISH and FINISH[o.name] == "shell":
                o["zr_mat"] = "shell"

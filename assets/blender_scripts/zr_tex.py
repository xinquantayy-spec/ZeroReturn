"""Zero Return - art-4b (the owner's pick "hybrid", audit art-4): PBR texture sheets for the gun parts.

Tarkov's guns and attachments are textured PBR models (colour, normal and gloss maps baked from high-poly sculpts:
rounded edges, worn coatings, machining and moulding grain, markings). Ours are the procedural part scripts' low-poly
meshes; this module gives them the same kind of maps without changing their shape:

  colour  the vertex colours (the whole part's AO and a little wear, zr_guns.bake_part) with grime along sharp
          concave edges and the coating worn back to bare steel along sharp convex ones, in patches (masks measured
          from the mesh per texel), and a faint 8 mm variation
  normal  edges rounded by Cycles' bevel (1.2 mm), tangent space +Y (Blender's and Roblox's convention); surface
          grain is finer than a texel at 1.5 px/mm, so none
  rough   each finish's roughness with variation; worn edges polished, cavities dusty
  metal   coatings, polymers, wood 0 (they behave like paint); bare-metal parts and worn edges 1

Pieces (a part's mesh per material, ZR_WP_<PART>__<mat>) are packed into 1024 px sheets by surface area at about
1.5 px per mm (glass and lights get none). The batch is then exported again with these UVs and without vertex colours
(the colour map carries them); Roblox clones each sheet's SurfaceAppearance into its pieces (src/shared/ZR_GunSA,
GunTex.luau, written by tools/gun_tex.py).

Run inside Blender, a step per MCP call:
    import zr_tex as T
    T.prepare("ZR_GunsAR")     # build the pieces, assign sheets, unwrap, bake materials  -> sheet summary
    T.bake("ZR_GunsAR", 60)    # bake passes until the time budget is spent; repeat until nothing is left
    T.export("ZR_GunsAR")      # PNGs to assets/textures/guns, the FBX with UVs, <batch>.tex.json
"""
import bpy, bmesh, math, os, json, time
import zr_items, zr_guns
from zr_lib import batch_scene, EXP, ROOT, meta_for

TEX = os.path.join(ROOT, "assets", "textures", "guns")
SIZE = 1024
PX_PER_STUD = 480            # 1.5 px per mm (a stud is 320 mm): about 3 sheets for the R-17 family (2.6 px/mm took 14)
PACK = 0.6                   # share of a sheet the packed islands fill
SKIP = ("glass", "emissive")
PASSES = ("mask", "color", "rough", "metal", "normal")
SAMPLES = {"mask": 1, "color": 1, "rough": 1, "metal": 1, "normal": 12}
SPREAD = 2.0                 # studs between parts while baking (each part is built at the origin)
MM = 0.003125                # a millimetre in studs

# finish -> coat roughness r, coat metalness m, edge wear amount, worn colour wc (linear; None = the coat lightened),
# worn roughness wr and metalness wm, grain scale gs (per stud) and bump gb
FIN = {
    "gunmetal": dict(r=0.5, m=0.0, wear=0.45, wc=(0.2, 0.205, 0.21), wr=0.3, wm=1.0, gs=900.0, gb=0.1),
    "metal": dict(r=0.36, m=1.0, wear=0.35, wc=(0.45, 0.46, 0.47), wr=0.24, wm=1.0, gs=1300.0, gb=0.05),
    "brass": dict(r=0.3, m=1.0, wear=0.3, wc=None, wr=0.2, wm=1.0, gs=1300.0, gb=0.03),
    "copper": dict(r=0.32, m=1.0, wear=0.3, wc=None, wr=0.2, wm=1.0, gs=1300.0, gb=0.03),
    "chrome": dict(r=0.12, m=1.0, wear=0.0, wc=None, wr=0.1, wm=1.0, gs=1300.0, gb=0.0),
    "gold": dict(r=0.2, m=1.0, wear=0.0, wc=None, wr=0.15, wm=1.0, gs=1300.0, gb=0.0),
    "polymer": dict(r=0.7, m=0.0, wear=0.35, wc=None, wr=0.5, wm=0.0, gs=700.0, gb=0.22),
    "plastic": dict(r=0.45, m=0.0, wear=0.25, wc=None, wr=0.35, wm=0.0, gs=900.0, gb=0.06),
    "rubber": dict(r=0.88, m=0.0, wear=0.0, wc=None, wr=0.8, wm=0.0, gs=500.0, gb=0.25),
    "wood": dict(r=0.62, m=0.0, wear=0.4, wc=None, wr=0.45, wm=0.0, gs=260.0, gb=0.15),
    "fabric": dict(r=0.92, m=0.0, wear=0.0, wc=None, wr=0.9, wm=0.0, gs=600.0, gb=0.3),
    "leather": dict(r=0.62, m=0.0, wear=0.3, wc=None, wr=0.5, wm=0.0, gs=700.0, gb=0.15),
    "paper": dict(r=0.85, m=0.0, wear=0.0, wc=None, wr=0.85, wm=0.0, gs=600.0, gb=0.04),
    "cardboard": dict(r=0.9, m=0.0, wear=0.0, wc=None, wr=0.9, wm=0.0, gs=500.0, gb=0.08),
    "ceramic": dict(r=0.3, m=0.0, wear=0.2, wc=None, wr=0.25, wm=0.0, gs=900.0, gb=0.03),
    "foil": dict(r=0.25, m=0.9, wear=0.0, wc=None, wr=0.25, wm=0.9, gs=900.0, gb=0.08),
}
STATE = {}


def _scene(batch):
    scn = batch_scene("ZR_TEX_" + batch)
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.render.bake.margin = 6
    scn.render.bake.margin_type = "EXTEND"
    scn.render.bake.use_clear = True
    scn.render.bake.target = "IMAGE_TEXTURES"
    return scn


class _in_scene:
    """make scn the window's scene (bake and the UV operators work on the context scene)"""

    def __init__(self, scn):
        self.scn = scn

    def __enter__(self):
        self.win = bpy.context.window
        self.prev = self.win.scene
        self.win.scene = self.scn
        return self.scn

    def __exit__(self, *a):
        self.win.scene = self.prev


def _area(o):
    return sum(p.area for p in o.data.polygons)


def _image(name, color, noncolor, size=SIZE):
    img = bpy.data.images.get(name)
    if img and (img.size[0] != size or img.size[1] != size):
        bpy.data.images.remove(img)
        img = None
    if not img:
        img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color" if noncolor else "sRGB"
    img.generated_color = color
    return img


def _material(fin):
    """one bake material per finish: masks, colour, roughness and metalness as emission inputs; the normal pass
    through a Principled BSDF with bevel and grain; TARGET is the image being baked, MASK the sheet's edge mask"""
    name = "ZR_TX_" + fin
    mat = bpy.data.materials.get(name)
    if mat:
        bpy.data.materials.remove(mat)
    f = FIN.get(fin, FIN["plastic"])
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    N, L = nt.nodes.new, nt.links.new

    def math_node(op, a=None, b=None, clamp=False):
        n = N("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, v in ((0, a), (1, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                L(v, n.inputs[i])
        return n.outputs[0]

    out = N("ShaderNodeOutputMaterial")
    emit = N("ShaderNodeEmission")
    emit.name = "EMIT"
    bsdf = N("ShaderNodeBsdfPrincipled")
    bsdf.name = "BSDF"
    tgt = N("ShaderNodeTexImage")
    tgt.name = "TARGET"
    mask = N("ShaderNodeTexImage")
    mask.name = "MASK"
    mask.interpolation = "Linear"
    tc = N("ShaderNodeTexCoord")
    col = N("ShaderNodeAttribute")
    col.attribute_name = "Col"
    col.attribute_type = "GEOMETRY"

    # the mask image read back (colour, roughness, metalness passes)
    sep = N("ShaderNodeSeparateColor")
    L(mask.outputs["Color"], sep.inputs[0])
    m_edge, m_cav = sep.outputs[0], sep.outputs[1]
    # wear in patches: edges times a 5 mm noise
    pn = N("ShaderNodeTexNoise")
    pn.inputs["Scale"].default_value = 1.0 / (5.0 * MM)
    pn.inputs["Detail"].default_value = 3.0
    L(tc.outputs["Object"], pn.inputs["Vector"])
    patch = math_node("MULTIPLY", math_node("SUBTRACT", pn.outputs["Fac"], 0.47), 3.0, clamp=True)
    wear = math_node("MULTIPLY", math_node("MULTIPLY", m_edge, patch), f["wear"], clamp=True)
    # variation: 8 mm blotches (any finer noise aliases at 1.5 px/mm into speckle)
    gn = N("ShaderNodeTexNoise")
    gn.inputs["Scale"].default_value = 1.0 / (8.0 * MM)
    gn.inputs["Detail"].default_value = 1.0
    L(tc.outputs["Object"], gn.inputs["Vector"])
    grain = math_node("SUBTRACT", gn.outputs["Fac"], 0.5)

    # colour: coat = vertex colour x grime x grain, worn toward the bare colour
    k = math_node("MULTIPLY", math_node("ADD", 1.0, math_node("MULTIPLY", grain, 0.07)),
                  math_node("SUBTRACT", 1.0, math_node("MULTIPLY", m_cav, 0.35)))
    coat = N("ShaderNodeVectorMath")
    coat.operation = "SCALE"
    L(col.outputs["Color"], coat.inputs[0])
    L(k, coat.inputs["Scale"])
    if f["wc"] is not None:
        # the bare metal under the coat
        rgb = N("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*f["wc"], 1.0)
        bare = rgb.outputs[0]
    else:
        # the same colour, lighter (scuffed polymer, bare wood)
        lift = N("ShaderNodeVectorMath")
        lift.operation = "MULTIPLY_ADD"
        L(col.outputs["Color"], lift.inputs[0])
        lift.inputs[1].default_value = (1.7, 1.7, 1.7)
        lift.inputs[2].default_value = (0.03, 0.03, 0.03)
        bare = lift.outputs[0]
    albedo = N("ShaderNodeMix")
    albedo.data_type = "RGBA"
    albedo.name = "ALBEDO"
    L(wear, next(x for x in albedo.inputs if x.name == "Factor" and x.type == "VALUE"))
    L(coat.outputs[0], next(x for x in albedo.inputs if x.name == "A" and x.type == "RGBA"))
    L(bare, next(x for x in albedo.inputs if x.name == "B" and x.type == "RGBA"))

    # roughness and metalness
    r0 = math_node("ADD", f["r"], math_node("ADD", math_node("MULTIPLY", grain, 0.12), math_node("MULTIPLY", m_cav, 0.08)))
    rough = math_node("ADD", math_node("MULTIPLY", r0, math_node("SUBTRACT", 1.0, wear)), math_node("MULTIPLY", wear, f["wr"]), clamp=True)
    metal = math_node("ADD", math_node("MULTIPLY", wear, f["wm"] - f["m"]), f["m"], clamp=True)
    for nm, sock in (("ROUGH", rough), ("METAL", metal)):
        cc = N("ShaderNodeCombineColor")
        L(sock, cc.inputs[0])
        L(sock, cc.inputs[1])
        L(sock, cc.inputs[2])
        cc.name = nm

    # the normal pass: rounded edges (surface grain is finer than a texel at this density)
    bev = N("ShaderNodeBevel")
    bev.samples = 8
    bev.inputs["Radius"].default_value = 1.2 * MM
    L(bev.outputs["Normal"], bsdf.inputs["Normal"])

    L(emit.outputs[0], out.inputs["Surface"])
    nt.nodes.active = tgt
    mat["zr_fin"] = fin
    return mat


def _route(mat, what):
    """point the output at what the pass bakes"""
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial")
    emit = nt.nodes["EMIT"]
    for l in list(out.inputs["Surface"].links):
        nt.links.remove(l)
    for l in list(emit.inputs["Color"].links):
        nt.links.remove(l)
    if what == "normal":
        nt.links.new(nt.nodes["BSDF"].outputs[0], out.inputs["Surface"])
        return
    src = {"color": next(x for x in nt.nodes["ALBEDO"].outputs if x.type == "RGBA"),
           "rough": nt.nodes["ROUGH"].outputs[0], "metal": nt.nodes["METAL"].outputs[0]}[what]
    nt.links.new(src, emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])


def _geo_masks(sh, wear_in=0.5 * MM, wear_out=1.8 * MM, grime_in=1.0 * MM, grime_out=4.0 * MM, sharp=math.radians(25)):
    """the sheet's masks from the meshes themselves (R: near a sharp convex edge, G: near a sharp concave one), per
    texel through the UVs: ray-traced AO saw the parts' overlapping inner boxes and wore whole faces"""
    import numpy as np
    W = sh.get("size", SIZE)
    R = np.zeros((W, W), np.float32)
    Gm = np.zeros((W, W), np.float32)
    for n in sh["objs"]:
        o = bpy.data.objects[n]
        bm = bmesh.new()
        bm.from_mesh(o.data)
        uvl = bm.loops.layers.uv.active
        cvx, ccv = {}, {}
        for e in bm.edges:
            if len(e.link_faces) != 2:
                continue
            try:
                ang = e.calc_face_angle_signed()
            except ValueError:
                continue
            seg = (np.array(e.verts[0].co), np.array(e.verts[1].co))
            if ang > sharp:
                for f in e.link_faces:
                    cvx.setdefault(f.index, []).append(seg)
            elif ang < -sharp:
                for f in e.link_faces:
                    ccv.setdefault(f.index, []).append(seg)
        for tri in bm.calc_loop_triangles():
            fi = tri[0].face.index
            ce, ge = cvx.get(fi), ccv.get(fi)
            if not ce and not ge:
                continue
            uv = np.array([(l[uvl].uv.x * W, l[uvl].uv.y * W) for l in tri])
            P3 = np.array([tuple(l.vert.co) for l in tri])
            x0, x1 = max(0, int(uv[:, 0].min()) - 1), min(W - 1, int(uv[:, 0].max()) + 1)
            y0, y1 = max(0, int(uv[:, 1].min()) - 1), min(W - 1, int(uv[:, 1].max()) + 1)
            if x1 < x0 or y1 < y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            (ax, ay), (bx, by), (cx, cy) = uv
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9:
                continue
            w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
            w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
            w2 = 1.0 - w0 - w1
            tol = -0.6 / max(1.0, np.abs(den) ** 0.5)
            inside = (w0 >= tol) & (w1 >= tol) & (w2 >= tol)
            if not inside.any():
                continue
            pts = w0[..., None] * P3[0] + w1[..., None] * P3[1] + w2[..., None] * P3[2]
            for segs, out, d_in, d_out in ((ce, R, wear_in, wear_out), (ge, Gm, grime_in, grime_out)):
                if not segs:
                    continue
                d = np.full(xs.shape, 1e9)
                for a, b in segs:
                    ab = b - a
                    l2 = float(ab.dot(ab))
                    t = np.clip(((pts - a) @ ab) / max(l2, 1e-12), 0.0, 1.0)
                    d = np.minimum(d, np.linalg.norm(pts - (a + t[..., None] * ab), axis=-1))
                m = np.clip(1.0 - (d - d_in) / (d_out - d_in), 0.0, 1.0) * inside
                sub = out[y0:y1 + 1, x0:x1 + 1]
                np.maximum(sub, m.astype(np.float32), out=sub)
        bm.free()
    px = np.zeros((W, W, 4), np.float32)
    px[..., 0], px[..., 1], px[..., 3] = R, Gm, 1.0
    img = bpy.data.images[sh["imgs"]["mask"]]
    img.pixels.foreach_set(px.ravel())
    img.update()
    return float(R.mean()), float(Gm.mean())


def _batch_pids(batch):
    import build_guns_all as G
    fam = G.BATCHES[batch]
    return [p for p in sorted(zr_guns.GP) if zr_guns.GP[p]["family"] == fam]


def build(batch, wear=0.25):
    """build the batch's pieces (vertex AO, a little vertex wear) and spread the parts apart (slow: a few minutes for
    the R-17 family; pack() can then be re-run on its own)"""
    scn = _scene(batch)
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    objs, parts = [], []
    for i, pid in enumerate(_batch_pids(batch)):
        P = zr_guns.make_part(pid)
        zr_guns.bake_part(P, wear=wear)
        po = P.finish(scn.collection)
        for o in po:
            o.location.x += (i % 8) * SPREAD
            o.location.z += (i // 8) * SPREAD
        objs += po
        parts.append((pid, [o.name for o in po if o["zr_mat"] not in SKIP]))
    STATE[batch] = {"scene": scn.name, "parts": parts, "all": [o.name for o in objs], "sheets": [], "times": {}}
    return len(parts), len(objs)


def pack(batch):
    """pack the pieces into sheets by area (a part's pieces together, parts in id order) and unwrap each sheet into
    one UV space; bake materials and empty images"""
    st = STATE[batch]
    scn = bpy.data.scenes[st["scene"]]
    cap = (SIZE / PX_PER_STUD) ** 2 * PACK
    total = sum(_area(bpy.data.objects[n]) for _, names in st["parts"] for n in names)
    size = 512 if total <= (512 / PX_PER_STUD) ** 2 * PACK else SIZE     # a small family: one 512 sheet
    sheets, cur, area = [], [], 0.0
    for pid, names in st["parts"]:
        po = [bpy.data.objects[n] for n in names]
        if not po:
            continue
        a = sum(_area(o) for o in po)
        if cur and area + a > cap:
            sheets.append(cur)
            cur, area = [], 0.0
        cur += po
        area += a
    if cur:
        sheets.append(cur)
    mats = {}
    out = []
    with _in_scene(scn):
        for si, sobjs in enumerate(sheets):
            name = "%s_T%d" % (batch.replace("ZR_Guns", "ZR_GT_"), si + 1)
            for o in scn.objects:
                o.select_set(False)
            for o in sobjs:
                o.select_set(True)
                fin = o["zr_mat"]
                if fin not in mats:
                    mats[fin] = _material(fin)
                o.data.materials.clear()
                o.data.materials.append(mats[fin])
                o["zr_sheet"] = name
            bpy.context.view_layer.objects.active = sobjs[0]
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
            bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.006)
            bpy.ops.object.mode_set(mode="OBJECT")
            imgs = {
                "mask": _image(name + "_mask", (0, 0, 0, 1), True, size),
                "color": _image(name + "_col", (0.5, 0.5, 0.5, 1), False, size),
                "rough": _image(name + "_rgh", (0.5, 0.5, 0.5, 1), True, size),
                "metal": _image(name + "_mtl", (0, 0, 0, 1), True, size),
                "normal": _image(name + "_nrm", (0.5, 0.5, 1.0, 1), True, size),
            }
            out.append({"name": name, "objs": [o.name for o in sobjs], "imgs": {k: v.name for k, v in imgs.items()},
                        "done": [], "area": round(sum(_area(o) for o in sobjs), 3), "size": size})
    st["sheets"] = out
    return [(s["name"], len(s["objs"]), s["area"]) for s in out], round(cap, 3)


def prepare(batch, wear=0.25):
    build(batch, wear)
    return pack(batch)


def bake(batch, seconds=60.0, only=None):
    """bake the next passes (sheet by sheet) until the budget is spent; returns (done now, left)"""
    st = STATE[batch]
    scn = bpy.data.scenes[st["scene"]]
    t0 = time.time()
    done = []
    with _in_scene(scn):
        for sh in st["sheets"]:
            if only and sh["name"] != only:
                continue
            for ps in PASSES:
                if ps in sh["done"]:
                    continue
                if done and time.time() - t0 > seconds:
                    break
                if ps == "mask":
                    t1 = time.time()
                    sh["mask_means"] = _geo_masks(sh, **sh.get("mask_kw", {}))   # a sheet may carry its own edge widths (gear)
                    st["times"]["%s/%s" % (sh["name"], ps)] = round(time.time() - t1, 1)
                    sh["done"].append(ps)
                    done.append("%s/%s" % (sh["name"], ps))
                    continue
                objs = [bpy.data.objects[n] for n in sh["objs"]]
                mats = {o.data.materials[0] for o in objs}
                for m in mats:
                    nt = m.node_tree
                    nt.nodes["TARGET"].image = bpy.data.images[sh["imgs"][ps]]
                    nt.nodes["MASK"].image = bpy.data.images[sh["imgs"]["mask"]]
                    nt.nodes.active = nt.nodes["TARGET"]
                    _route(m, ps)
                for o in scn.objects:
                    o.select_set(False)
                for o in objs:
                    o.select_set(True)
                bpy.context.view_layer.objects.active = objs[0]
                scn.cycles.samples = SAMPLES[ps]
                t1 = time.time()
                if ps == "normal":
                    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
                else:
                    bpy.ops.object.bake(type="EMIT")
                st["times"]["%s/%s" % (sh["name"], ps)] = round(time.time() - t1, 1)
                sh["done"].append(ps)
                done.append("%s/%s" % (sh["name"], ps))
    left = sum(len(PASSES) - len(sh["done"]) for sh in st["sheets"])
    return done, left, st["times"]


def rebake(batch):
    """forget the baked passes (pieces and UVs stay) and rebuild the bake materials, after a change to them"""
    st = STATE[batch]
    mats = {}
    for sh in st["sheets"]:
        sh["done"] = []
        for n in sh["objs"]:
            o = bpy.data.objects[n]
            fin = o["zr_mat"]
            if fin not in mats:
                mats[fin] = _material(fin)
            o.data.materials.clear()
            o.data.materials.append(mats[fin])
    return len(mats)


def flat(img):
    """True when a bake came out one value everywhere: the body's first colour bake did (0.502 grey on every texel)
    without any error, and its arms showed black in game under the olive tint"""
    import numpy as np
    px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return float(px.reshape(-1, 4)[:, :3].std(axis=0).max()) < 1e-3


def export(batch):
    """save the sheets' PNGs, export the batch again with these UVs and no vertex colours, write <batch>.tex.json"""
    st = STATE[batch]
    scn = bpy.data.scenes[st["scene"]]
    os.makedirs(TEX, exist_ok=True)
    files = []
    for sh in st["sheets"]:
        assert len(sh["done"]) == len(PASSES), sh["name"] + " is not baked"
        for ps in ("color", "normal"):   # metalness may be all zero (no metal on the sheet); these never are
            assert not flat(bpy.data.images[sh["imgs"][ps]]), "%s: the %s bake came out flat, rebake the sheet" % (sh["name"], ps)
        for ps, suffix in (("color", "col"), ("normal", "nrm"), ("rough", "rgh"), ("metal", "mtl")):
            img = bpy.data.images[sh["imgs"][ps]]
            path = os.path.join(TEX, "%s_%s.png" % (sh["name"], suffix))
            img.filepath_raw = path
            img.file_format = "PNG"
            img.save()
            files.append(path)
    objs = [bpy.data.objects[n] for n in st["all"]]
    for o in objs:
        o.location = (0.0, 0.0, 0.0)
        o.data.materials.clear()
        o.data.materials.append(zr_items.render_material(o["zr_mat"]))
    fbx = os.path.join(EXP, batch + ".fbx")
    with _in_scene(scn):
        for o in scn.objects:
            o.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                                 axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", colors_type="NONE",
                                 add_leaf_bones=False, bake_anim=False)
    meta = {o.name: meta_for(o) for o in objs}
    with open(os.path.join(EXP, batch + ".meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    rec = {"batch": batch, "size": max(sh.get("size", SIZE) for sh in st["sheets"]), "px_per_mm": round(PX_PER_STUD / 320.0, 2),
           "sheets": {sh["name"]: sh["objs"] for sh in st["sheets"]}}
    with open(os.path.join(EXP, batch + ".tex.json"), "w") as f:
        json.dump(rec, f, indent=1, sort_keys=True)
    return fbx, [os.path.basename(p) for p in files]


# ── the driver: every batch from build to upload, a time budget per MCP call ──────────────────────────────────────
UPLOADS = os.path.join(TEX, "uploads.json")
RUN = {}


def _build_some(batch, seconds, t0, wear=0.25):
    """build the batch's parts a few at a time (the vertex AO is slow); True when all are built"""
    r = RUN[batch]
    if "pids" not in r:
        scn = _scene(batch)
        for o in list(scn.collection.objects):
            bpy.data.objects.remove(o)
        r["pids"], r["i"], r["parts"], r["all"] = _batch_pids(batch), 0, [], []
    scn = bpy.data.scenes["ZR_TEX_" + batch]
    while r["i"] < len(r["pids"]):
        if time.time() - t0 > seconds:
            return False
        pid = r["pids"][r["i"]]
        P = zr_guns.make_part(pid)
        zr_guns.bake_part(P, wear=wear)
        po = P.finish(scn.collection)
        r["parts"].append((pid, [o.name for o in po if o["zr_mat"] not in SKIP]))
        r["all"] += [o.name for o in po]
        r["i"] += 1
    STATE[batch] = {"scene": scn.name, "parts": r["parts"], "all": r["all"], "sheets": [], "times": {}}
    return True


def _uploads():
    if os.path.exists(UPLOADS):
        with open(UPLOADS) as f:
            return json.load(f)
    return {}


def _upload_some(batch, seconds, t0):
    g = RUN.setdefault("_g", {})
    if "upload_model" not in g:
        g["__name__"] = "zr_upload_run"
        exec(open(os.path.join(ROOT, "assets", "blender_scripts", "zr_upload.py"), encoding="utf-8").read(), g)
    up = _uploads()
    keys = ["%s_%s" % (sh["name"], s) for sh in STATE[batch]["sheets"] for s in ("col", "nrm", "rgh", "mtl")]
    for key in keys + [batch]:
        if key in up:
            continue
        if time.time() - t0 > seconds:
            return False
        if key == batch:
            r = g["upload_model"](os.path.join(EXP, batch + ".fbx"), batch, "Zero Return gun parts with UVs for their texture sheets (art-4b)", force=True, asset_type="Model")
        else:
            r = g["upload_model"](os.path.join(TEX, key + ".png"), key, "Zero Return gun texture sheet (original procedural bake)", asset_type="Decal")
        if not r.get("ok"):
            raise RuntimeError("upload %s: %s" % (key, str(r)[:200]))
        up[key] = r["assetId"]
        with open(UPLOADS, "w") as f:
            json.dump(up, f, indent=1, sort_keys=True)
    return True


def run(batches, seconds=45.0):
    """advance each batch (build, pack, bake, export, upload) within the budget; returns a line per batch"""
    import io, contextlib
    t0 = time.time()
    with contextlib.redirect_stdout(io.StringIO()):
        for b in batches:
            r = RUN.setdefault(b, {"phase": "build"})
            while r["phase"] != "done" and time.time() - t0 < seconds:
                ph = r["phase"]
                if ph == "build":
                    if _build_some(b, seconds, t0):
                        r["phase"] = "pack"
                elif ph == "pack":
                    if seconds - (time.time() - t0) < 22:
                        break                      # pack (up to ~40 s for a big family) with enough budget left
                    pack(b)
                    r["phase"] = "bake"
                elif ph == "bake":
                    if bake(b, max(1.0, seconds - (time.time() - t0)))[1] == 0:
                        r["phase"] = "export"
                elif ph == "export":
                    export(b)
                    r["phase"] = "upload"
                elif ph == "upload":
                    if _upload_some(b, seconds, t0):
                        r["phase"] = "done"
            if time.time() - t0 >= seconds:
                break
    out = []
    for b in batches:
        r = RUN.get(b, {"phase": "build"})
        st = STATE.get(b)
        extra = ""
        if r["phase"] == "build" and "pids" in r:
            extra = " %d/%d" % (r["i"], len(r["pids"]))
        elif st and st.get("sheets"):
            extra = " %d sheets, %d passes left" % (len(st["sheets"]), sum(len(PASSES) - len(sh["done"]) for sh in st["sheets"]))
        out.append(b.replace("ZR_Guns", "") + ":" + r["phase"] + extra)
    return "; ".join(out) + " (%.0f s)" % (time.time() - t0)


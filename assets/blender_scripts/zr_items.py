"""Zero Return - item models and inventory icons (M13 owner request: "a blender image for every item").
Runs inside Blender after zr_lib.py (sys.path holds assets/blender_scripts).

Every item is modelled in metres and scaled to studs at the end (U = 3.125 studs per metre, the scale of the
characters and the weapons). An item is one zr_lib Builder per material, named ZR_IT_<ITEM>__<mat>, sharing one
origin (bottom-centre; the front faces Blender -Y, the top +Z; long guns point their muzzle along -Y).

The pieces are:
  * rendered to an inventory icon: EEVEE, orthographic camera, transparent background, image aspect = the item's
    grid size (w x h cells), lit like a studio product shot, materials from the material key below;
  * baked and exported for the loose loot lying in the world (build_items_export.py).
Icons go to assets/renders/items/<ITEM>.png at CELL_PX pixels per grid cell; pack_atlas() packs them into
1024 x 1024 sheets and writes assets/renders/items/atlas.json (sheet, offset and size per item).
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, Matrix, Euler
from zr_lib import Builder, hexc, grey

U = 3.125  # studs per metre
ROOT = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov")
OUT = os.path.join(ROOT, "assets", "renders", "items")
CELL_PX = 128  # source renders; the atlas stores ATLAS_CELL px per cell
ATLAS_CELL = 64
ATLAS_SIZE = 1024

# material key -> render look (Principled BSDF): metallic, roughness, bump strength, extra
ITEM_MATS = {
    "metal": dict(metallic=0.85, rough=0.34, bump=0.02),       # bare steel, aluminium
    "gunmetal": dict(metallic=0.6, rough=0.46, bump=0.015),    # blued / parkerised gun steel
    "brass": dict(metallic=1.0, rough=0.26, bump=0.0),
    "copper": dict(metallic=1.0, rough=0.3, bump=0.0),
    "gold": dict(metallic=1.0, rough=0.18, bump=0.0),
    "chrome": dict(metallic=1.0, rough=0.1, bump=0.0),
    "plastic": dict(metallic=0.0, rough=0.42, bump=0.01),      # glossy moulded plastic
    "polymer": dict(metallic=0.0, rough=0.68, bump=0.03),      # textured gun polymer
    "rubber": dict(metallic=0.0, rough=0.88, bump=0.04),
    "fabric": dict(metallic=0.0, rough=0.92, bump=0.12, sheen=0.06),  # nylon, canvas, cotton (a strong sheen washed dark kit out)
    "leather": dict(metallic=0.0, rough=0.62, bump=0.05),
    "paper": dict(metallic=0.0, rough=0.82, bump=0.015),
    "cardboard": dict(metallic=0.0, rough=0.9, bump=0.05),
    "wood": dict(metallic=0.0, rough=0.62, bump=0.04),
    "ceramic": dict(metallic=0.0, rough=0.3, bump=0.0),
    "glass": dict(metallic=0.0, rough=0.04, bump=0.0, glass=True),
    "emissive": dict(metallic=0.0, rough=0.5, bump=0.0, emit=2.5),
    "foil": dict(metallic=0.9, rough=0.22, bump=0.08),          # blister packs, wrappers
}

R = math.radians


def col(h, k=1.0):
    return hexc(h, k)


def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def shade(c, k):
    return (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k), 1.0)


class Item:
    """one item: a Builder per material, all modelled in metres around one origin"""

    def __init__(self, name):
        self.name = name
        self.b = {}

    def __call__(self, mat):
        assert mat in ITEM_MATS, mat
        if mat not in self.b:
            self.b[mat] = Builder("ZR_IT_%s__%s" % (self.name, mat))
        return self.b[mat]

    def transform(self, m):
        for b in self.b.values():
            b.transform(m)

    def finish(self, coll):
        """scale to studs, make the objects (vertex colour attribute "Col" on every piece)"""
        objs = []
        for mat in sorted(self.b):
            b = self.b[mat]
            if len(b.bm.faces) == 0:
                b.bm.free()
                continue
            b.transform(Matrix.Scale(U, 4))
            o = b.finish(coll)
            o["zr_mat"] = mat
            objs.append(o)
        return objs


# ── small shape helpers (metres) ─────────────────────────────────────────────
def rbox(b, c, s, color, rot=(0, 0, 0), bevel=0.0):
    """box with a bevel as a share of its smallest side (rounded product look)"""
    m = min(s)
    b.box(c, s, color, rot=rot, bevel=bevel * m if bevel < 0.5 else bevel)


def label_band(b, c, s, color, axis="y", sign=-1):
    """a thin printed band on a face: a flat quad just off the surface (2 triangles)"""
    x, y, z = c
    sx, sy, sz = s
    if axis == "y":
        yy = y + sign * 0.0006
        pts = [(x - sx / 2, yy, z - sz / 2), (x + sx / 2, yy, z - sz / 2), (x + sx / 2, yy, z + sz / 2), (x - sx / 2, yy, z + sz / 2)]
        if sign > 0:
            pts.reverse()
    elif axis == "x":
        xx = x + sign * 0.0006
        pts = [(xx, y + sy / 2, z - sz / 2), (xx, y - sy / 2, z - sz / 2), (xx, y - sy / 2, z + sz / 2), (xx, y + sy / 2, z + sz / 2)]
        if sign < 0:
            pts.reverse()
    else:  # z (top)
        zz = z + sign * 0.0006
        pts = [(x - sx / 2, y - sy / 2, zz), (x + sx / 2, y - sy / 2, zz), (x + sx / 2, y + sy / 2, zz), (x - sx / 2, y + sy / 2, zz)]
        if sign < 0:
            pts.reverse()
    b.face(pts, color)


def cyl_z(b, x, y, z0, z1, r, color, seg=16, r2=None, smooth=True, cap=True):
    b.cyl((x, y, z0), (x, y, z1), r, color, r2=r2, seg=seg, smooth=smooth, cap=cap)


def cyl_y(b, x, y0, y1, z, r, color, seg=16, r2=None, smooth=True, cap=True):
    b.cyl((x, y0, z), (x, y1, z), r, color, r2=r2, seg=seg, smooth=smooth, cap=cap)


def cyl_x(b, x0, x1, y, z, r, color, seg=16, r2=None, smooth=True, cap=True):
    b.cyl((x0, y, z), (x1, y, z), r, color, r2=r2, seg=seg, smooth=smooth, cap=cap)


def lathe(b, profile, color, seg=20, x=0.0, y=0.0, z=0.0, smooth=True, cap_top=True, cap_bottom=True, axis="z"):
    """surface of revolution: profile = [(radius, height), ...] from the bottom up (bottles, bulbs, knobs)"""
    import bmesh
    before = set(b.bm.faces)
    rings = []
    for r, h in profile:
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            if axis == "z":
                p = (x + math.cos(a) * r, y + math.sin(a) * r, z + h)
            elif axis == "y":
                p = (x + math.cos(a) * r, y + h, z + math.sin(a) * r)
            else:
                p = (x + h, y + math.cos(a) * r, z + math.sin(a) * r)
            ring.append(b.bm.verts.new(p))
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append(b.bm.faces.new((r0[k], r0[k2], r1[k2], r1[k])))
    if cap_bottom and profile[0][0] > 1e-5:
        faces.append(b.bm.faces.new(list(reversed(rings[0]))))
    if cap_top and profile[-1][0] > 1e-5:
        faces.append(b.bm.faces.new(rings[-1]))
    new = [f for f in b.bm.faces if f not in before]
    bmesh.ops.recalc_face_normals(b.bm, faces=new)
    ngons = [f for f in new if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(b.bm, faces=ngons, quad_method="BEAUTY", ngon_method="EAR_CLIP")
    new = [f for f in b.bm.faces if f not in before]
    b._paint(new, color, smooth)
    for f in new:
        f.smooth = smooth and len(f.verts) == 4


# ── render materials ───────────────────────────────────────────────────────────
def render_material(key):
    name = "ZR_IT_M3_" + key
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    p = ITEM_MATS[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    attr.attribute_type = "GEOMETRY"
    # gentle colour variation and grain (object space, so it follows the item)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.0
    noise.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    vary = nt.nodes.new("ShaderNodeMapRange")
    vary.inputs["To Min"].default_value = 0.93
    vary.inputs["To Max"].default_value = 1.06
    nt.links.new(noise.outputs["Fac"], vary.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    # the "Col" values are sRGB (that is what the FBX export and Roblox expect): linearise them for shading
    lin = nt.nodes.new("ShaderNodeGamma")
    lin.inputs["Gamma"].default_value = 2.2
    nt.links.new(attr.outputs["Color"], lin.inputs["Color"])
    nt.links.new(lin.outputs["Color"], mul.inputs[6])
    nt.links.new(vary.outputs["Result"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = p["metallic"]
    # roughness varies a little across the surface
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = max(0.0, p["rough"] - 0.08)
    rr.inputs["To Max"].default_value = min(1.0, p["rough"] + 0.08)
    nt.links.new(noise.outputs["Fac"], rr.inputs["Value"])
    nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
    if p.get("bump", 0) > 0:
        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 140.0 if key in ("fabric", "cardboard", "rubber", "polymer") else 60.0
        fine.inputs["Detail"].default_value = 4.0
        nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = p["bump"]
        nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    if p.get("sheen"):
        try:
            bsdf.inputs["Sheen Weight"].default_value = p["sheen"]
        except KeyError:
            pass
    if p.get("glass"):
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        bsdf.inputs["IOR"].default_value = 1.45
        bsdf.inputs["Alpha"].default_value = 0.45
        try:
            mat.surface_render_method = "BLENDED"
        except AttributeError:
            pass
    if p.get("emit"):
        nt.links.new(lin.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = p["emit"]
    return mat


# ── the icon studio ────────────────────────────────────────────────────────────
def studio():
    scn = bpy.data.scenes.get("ZR_Icons")
    if scn is None:
        scn = bpy.data.scenes.new("ZR_Icons")
    if scn.world is None or scn.world.name != "ZR_IconsWorld":
        w = bpy.data.worlds.get("ZR_IconsWorld") or bpy.data.worlds.new("ZR_IconsWorld")
        w.use_nodes = True
        bg = w.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = (0.3, 0.31, 0.32, 1.0)
        bg.inputs["Strength"].default_value = 0.7
        scn.world = w
    r = scn.render
    r.engine = "BLENDER_EEVEE"
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.resolution_percentage = 100
    r.filter_size = 1.2
    # Standard keeps the authored colours; the lights are set so that nothing clips
    scn.view_settings.view_transform = "Standard"
    try:
        scn.view_settings.look = "None"
    except TypeError:
        pass
    scn.view_settings.exposure = 0.55
    scn.view_settings.gamma = 1.0
    ee = scn.eevee
    for k, v in (("taa_render_samples", 32), ("use_shadows", True), ("use_raytracing", True), ("shadow_ray_count", 2), ("shadow_step_count", 8)):
        try:
            setattr(ee, k, v)
        except (AttributeError, TypeError):
            pass
    # camera
    cam = bpy.data.objects.get("ZR_IconCam")
    if cam is None:
        cd = bpy.data.cameras.new("ZR_IconCam")
        cd.type = "ORTHO"
        cam = bpy.data.objects.new("ZR_IconCam", cd)
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.clip_start = 0.01
    cam.data.clip_end = 400.0
    # three suns: key from the upper left front, a soft fill from the right, a rim from behind
    for name, rot, energy, angle, color in (
        ("ZR_IconKey", (R(42), R(0), R(-30)), 3.0, R(8), (1.0, 0.97, 0.93)),
        ("ZR_IconFill", (R(64), R(0), R(125)), 0.9, R(35), (0.88, 0.94, 1.0)),
        ("ZR_IconRim", (R(-62), R(0), R(195)), 2.6, R(5), (1.0, 1.0, 1.0)),
        ("ZR_IconTop", (R(5), R(0), R(0)), 0.8, R(25), (1.0, 1.0, 1.0)),
    ):
        lo = bpy.data.objects.get(name)
        if lo is None:
            ld = bpy.data.lights.new(name, "SUN")
            lo = bpy.data.objects.new(name, ld)
        if lo.name not in scn.collection.objects:
            scn.collection.objects.link(lo)
        lo.data.energy = energy
        lo.data.angle = angle
        lo.data.color = color
        lo.rotation_euler = rot
    coll = bpy.data.collections.get("ZR_IconItems")
    if coll is None:
        coll = bpy.data.collections.new("ZR_IconItems")
    if coll.name not in scn.collection.children:
        scn.collection.children.link(coll)
    return scn, cam, coll


# view name -> direction from the item toward the camera (Blender space; the item's front faces -Y)
VIEWS = {
    "left": Vector((1, 0, 0)),             # long guns, knives, mags lying: muzzle/tip to the left of the picture
    "left_hi": Vector((1, -0.05, 0.22)),
    "front": Vector((0, -1, 0.12)),
    "front_hi": Vector((0.18, -1, 0.42)),
    "three_q": Vector((0.62, -0.9, 0.55)),   # boxes and devices: front, side and top
    "three_q_low": Vector((0.6, -0.95, 0.3)),
    "top": Vector((0.0, -0.18, 1.0)),        # flat things: keys, cards, coins, folders
    "top_tilt": Vector((0.25, -0.55, 1.0)),
}


def _corners(objs):
    out = []
    for o in objs:
        for v in o.data.vertices:
            out.append(o.matrix_world @ v.co)
    return out


def frame(cam, objs, w_cells, h_cells, view, margin=0.1, roll=0.0):
    d = VIEWS[view] if isinstance(view, str) else Vector(view)
    d = d.normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((0, 1, 0))
    z = d
    x = up.cross(z).normalized()
    y = z.cross(x).normalized()
    if roll:
        x, y = (x * math.cos(roll) + y * math.sin(roll)), (y * math.cos(roll) - x * math.sin(roll))
    m = Matrix((x, y, z)).transposed()
    # lights follow the camera, so every view is lit the same way in the picture: key from the upper left
    # front, a soft fill from the right, a rim from behind and above, a little top light
    for name, v in (("ZR_IconKey", -0.5 * x + 0.62 * y + 0.6 * z), ("ZR_IconFill", 0.85 * x + 0.05 * y + 0.52 * z),
                    ("ZR_IconRim", 0.35 * x + 0.55 * y - 0.75 * z), ("ZR_IconTop", 0.1 * x + 1.0 * y + 0.1 * z)):
        lo = bpy.data.objects.get(name)
        if lo:
            lo.rotation_mode = "QUATERNION"
            lo.rotation_quaternion = v.normalized().to_track_quat("Z", "Y")
    pts = _corners(objs)
    inv = m.inverted()
    loc = [inv @ p for p in pts]
    xs = [p.x for p in loc]
    ys = [p.y for p in loc]
    zs = [p.z for p in loc]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ext_x, ext_y = max(xs) - min(xs), max(ys) - min(ys)
    aspect = w_cells / h_cells
    vis_w = max(ext_x, ext_y * aspect) * (1 + margin)
    cam.data.ortho_scale = vis_w if aspect >= 1 else vis_w / aspect
    depth = max(zs) + 50.0
    cam.matrix_world = Matrix.Translation(m @ Vector((cx, cy, depth))) @ m.to_4x4()
    cam.data.clip_end = depth - min(zs) + 60.0


def render_icon(item_id, objs, w_cells, h_cells, view="three_q", margin=0.1, roll=0.0, px=CELL_PX):
    scn, cam, coll = studio()
    for o in list(coll.objects):
        coll.objects.unlink(o)
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        mat = render_material(o.get("zr_mat", "plastic"))
        o.data.materials.clear()
        o.data.materials.append(mat)
    frame(cam, objs, w_cells, h_cells, view, margin, roll)
    scn.render.resolution_x = int(w_cells * px)
    scn.render.resolution_y = int(h_cells * px)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, item_id + ".png")
    scn.render.filepath = path
    win = bpy.context.window
    prev = win.scene
    win.scene = scn
    try:
        bpy.ops.render.render(write_still=True, scene=scn.name)
    finally:
        win.scene = prev
    return path


def clear_items(coll=None):
    coll = coll or bpy.data.collections.get("ZR_IconItems")
    if not coll:
        return
    for o in list(coll.objects):
        me = o.data
        bpy.data.objects.remove(o)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)


# ── atlas ──────────────────────────────────────────────────────────────────────
PAD = 2  # transparent pixels between icons, so filtering never bleeds a neighbour in


def _load_scaled(path, pw, ph):
    """load a CELL_PX render and box-filter it down to (pw, ph) with premultiplied alpha (no dark fringes)"""
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    sw, sh = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(sh, sw, 4)
    bpy.data.images.remove(img)
    fx, fy = sw // pw, sh // ph
    if fx >= 1 and fy >= 1 and sw == pw * fx and sh == ph * fy:
        a = px[:, :, 3:4]
        pre = np.concatenate([px[:, :, :3] * a, a], axis=2)
        pre = pre.reshape(ph, fy, pw, fx, 4).mean(axis=(1, 3))
        alpha = pre[:, :, 3:4]
        rgb = np.where(alpha > 1e-4, pre[:, :, :3] / np.maximum(alpha, 1e-4), 0.0)
        return np.concatenate([rgb, alpha], axis=2)
    # odd sizes: let Blender scale it
    img = bpy.data.images.load(path, check_existing=False)
    img.scale(pw, ph)
    out = np.array(img.pixels[:], dtype=np.float32).reshape(ph, pw, 4)
    bpy.data.images.remove(img)
    return out


def pack_atlas(entries, out_prefix="ZR_ItemIcons", cell=ATLAS_CELL, size=ATLAS_SIZE):
    """entries: [(item_id, w_cells, h_cells)] -> sheets of size x size (shelf packing, tallest first, PAD px
    apart). Each icon is box-filtered to (w*cell, h*cell). Writes atlas.json and the sheets; returns both."""
    import numpy as np
    items = sorted(entries, key=lambda e: (-e[2], -e[1], e[0]))
    sheets, placed = [], {}
    cur = None
    x = y = shelf_h = 0
    for iid, w, h in items:
        pw, ph = w * cell, h * cell
        if cur is None or x + pw + PAD > size:
            x = PAD
            y += shelf_h
            shelf_h = 0
        if cur is None or y + ph + PAD > size:
            cur = np.zeros((size, size, 4), dtype=np.float32)
            sheets.append(cur)
            x, y, shelf_h = PAD, PAD, 0
        px = _load_scaled(os.path.join(OUT, iid + ".png"), pw, ph)
        # Blender pixel rows run bottom-up: the icon's top-left (x, y) in image space is row size - y - ph
        y0 = size - y - ph
        cur[y0:y0 + ph, x:x + pw, :] = px
        placed[iid] = {"sheet": len(sheets) - 1, "x": x, "y": y, "w": pw, "h": ph}
        x += pw + PAD
        shelf_h = max(shelf_h, ph + PAD)
    files = []
    for i, arr in enumerate(sheets):
        name = "%s_%d" % (out_prefix, i)
        img = bpy.data.images.new(name, size, size, alpha=True)
        img.pixels[:] = arr.ravel()
        path = os.path.join(OUT, name + ".png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        files.append(path)
    with open(os.path.join(OUT, "atlas.json"), "w") as f:
        json.dump({"cell": cell, "size": size, "pad": PAD, "sheets": [os.path.basename(p) for p in files], "items": placed}, f, indent=1, sort_keys=True)
    return placed, files

"""Zero Return - procedural low-poly modelling helpers for Blender (bmesh, vertex colours, FBX export).
Conventions (verified by calibration, see docs/PIPELINE.md):
  1 Blender unit = 1 stud. Objects face -Y (Blender front) -> Roblox -Z (LookVector).
  Blender (x, y, z) -> Roblox (-x, z, y). Props: origin bottom-centre. Viewmodel parts: origin at the grip.
  No textures: colour lives in a "Col" corner colour attribute; neutral props are tinted by MeshPart.Color.
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, Matrix, Euler

ROOT = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov")
SRC = os.path.join(ROOT, "assets", "blender_sources")
EXP = os.path.join(ROOT, "assets", "exports")


def hexc(h, mul=1.0):
    h = h.lstrip("#")
    return tuple(min(1.0, int(h[i:i + 2], 16) / 255 * mul) for i in (0, 2, 4)) + (1.0,)


def grey(v):
    return (v, v, v, 1.0)


class Builder:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")

    def _new(self, before):
        return [f for f in self.bm.faces if f not in before]

    def _paint(self, faces, color, smooth=False):
        for f in faces:
            f.smooth = smooth
            for l in f.loops:
                l[self.col] = color

    def _bevel(self, faces, amount):
        if amount <= 0:
            return
        edges = list({e for f in faces for e in f.edges})
        bmesh.ops.bevel(self.bm, geom=edges, offset=amount, offset_type='OFFSET', segments=1,
                        profile=0.5, affect='EDGES', clamp_overlap=True)

    def box(self, center, size, color, rot=(0, 0, 0), bevel=0.0):
        before = set(self.bm.faces)
        m = Matrix.LocRotScale(Vector(center), Euler(rot).to_quaternion(), Vector(size))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        new = self._new(before)
        self._bevel(new, bevel)
        self._paint(self._new(before), color)

    def cyl(self, a, b, r1, color, r2=None, seg=8, smooth=False, cap=True):
        """Cylinder/cone from point a to point b."""
        before = set(self.bm.faces)
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        m = Matrix.LocRotScale((a + b) / 2, q, Vector((1, 1, 1)))
        bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r1,
                              radius2=r2 if r2 is not None else r1, depth=d.length, matrix=m)
        new = self._new(before)
        self._paint(new, color, False)
        for f in new:
            f.smooth = smooth and len(f.verts) == 4  # smooth sides, flat caps

    def prism(self, profile, x0, x1, color, bevel=0.0):
        """Extrude a side profile [(y, z), ...] (counter-clockwise seen from +X) between x0 and x1."""
        before = set(self.bm.faces)
        va = [self.bm.verts.new((x0, y, z)) for y, z in profile]
        vb = [self.bm.verts.new((x1, y, z)) for y, z in profile]
        n = len(profile)
        self.bm.faces.new(list(reversed(va)))
        self.bm.faces.new(vb)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((va[i], va[j], vb[j], vb[i]))
        new = self._new(before)
        bmesh.ops.recalc_face_normals(self.bm, faces=new)
        self._bevel(new, bevel)
        new = self._new(before)
        caps = [f for f in new if len(f.verts) > 4]
        if caps:
            bmesh.ops.triangulate(self.bm, faces=caps, quad_method='BEAUTY', ngon_method='EAR_CLIP')
        self._paint(self._new(before), color)

    def ao(self, zmin, zmax, low=0.62, high=1.0):
        """Cheap baked ambient occlusion: darken toward the bottom."""
        h = max(1e-4, zmax - zmin)
        for f in self.bm.faces:
            for l in f.loops:
                t = max(0.0, min(1.0, (l.vert.co.z - zmin) / h))
                k = low + (high - low) * (t ** 0.6)
                c = l[self.col]
                l[self.col] = (c[0] * k, c[1] * k, c[2] * k, 1.0)

    def jitter(self, amount, seed=1):
        rnd = random.Random(seed)
        for f in self.bm.faces:
            k = 1 + rnd.uniform(-amount, amount)
            for l in f.loops:
                c = l[self.col]
                l[self.col] = (min(1, c[0] * k), min(1, c[1] * k), min(1, c[2] * k), 1.0)

    def scale(self, s):
        bmesh.ops.scale(self.bm, vec=(s, s, s), verts=self.bm.verts)

    def finish(self, collection):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        old = bpy.data.objects.get(self.name)
        if old:
            bpy.data.objects.remove(old)
        oldm = bpy.data.meshes.get(self.name)
        if oldm:
            bpy.data.meshes.remove(oldm)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        me.materials.append(vertex_material())
        return obj


def vertex_material():
    mat = bpy.data.materials.get("ZR_M_VertexPalette")
    if mat:
        return mat
    mat = bpy.data.materials.new("ZR_M_VertexPalette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


def batch_scene(name):
    scn = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    return scn


def meta_for(obj):
    """Bounding box in Roblox space: size and centre offset from the object origin."""
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cb = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    size_b = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return {
        "center": [round(-cb[0], 4), round(cb[2], 4), round(cb[1], 4)],
        "size": [round(size_b[0], 4), round(size_b[2], 4), round(size_b[1], 4)],
        "tris": tris,
    }


def export_batch(objs, batch_name, scene):
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(EXP, exist_ok=True)
    win = bpy.context.window
    prev = win.scene
    win.scene = scene
    for o in scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    fbx = os.path.join(EXP, batch_name + ".fbx")
    kw = dict(filepath=fbx, use_selection=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
              axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', colors_type='SRGB', add_leaf_bones=False,
              bake_anim=False)
    bpy.ops.export_scene.fbx(**kw)
    win.scene = prev
    blend = os.path.join(SRC, batch_name + ".blend")
    blocks = set(objs) | {o.data for o in objs} | {vertex_material()}
    bpy.data.libraries.write(blend, blocks, fake_user=True)
    meta = {o.name: meta_for(o) for o in objs}
    with open(os.path.join(EXP, batch_name + ".meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return fbx, blend, meta

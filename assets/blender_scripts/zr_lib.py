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

    # ── M12 wear-kit helpers ────────────────────────────────────────────────
    def chunk(self, center, size, color, seed=0, rough=0.28, rot=None, subdiv=1):
        """irregular rock / concrete chunk (jittered icosphere, flat shaded)"""
        rnd = random.Random(seed)
        before = set(self.bm.faces)
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=0.5, matrix=Matrix.Identity(4), calc_uvs=False)
        rot = rot if rot is not None else (rnd.uniform(0, 6.283), rnd.uniform(0, 6.283), rnd.uniform(0, 6.283))
        q = Euler(rot).to_quaternion()
        c = Vector(center)
        for v in res["verts"]:
            k = 1 + rnd.uniform(-rough, rough)
            p = Vector((v.co.x * k * size[0], v.co.y * k * size[1], v.co.z * k * size[2]))
            v.co = c + q @ p
        self._paint(self._new(before), color)

    def tube(self, pts, r, color, seg=6, smooth=True, caps=False, r_end=None):
        """swept circle along a polyline (cables, bent pipes, rebar)"""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        rings, prev = [], None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == n - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
            if prev is None:
                up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                nrm = t.cross(up).normalized()
            else:
                nrm = (prev - t * prev.dot(t)).normalized()
            bnm = t.cross(nrm).normalized()
            prev = nrm
            rr = r if r_end is None else r + (r_end - r) * i / max(1, n - 1)
            rings.append([self.bm.verts.new(p + (nrm * math.cos(2 * math.pi * k / seg) + bnm * math.sin(2 * math.pi * k / seg)) * rr) for k in range(seg)])
        faces = []
        for i in range(n - 1):
            A, B = rings[i], rings[i + 1]
            for k in range(seg):
                k2 = (k + 1) % seg
                faces.append(self.bm.faces.new((A[k], A[k2], B[k2], B[k])))
        if caps:
            faces.append(self.bm.faces.new(list(reversed(rings[0]))))
            faces.append(self.bm.faces.new(rings[-1]))
        self._paint(faces, color, smooth)

    def torus(self, center, R, r, color, segU=16, segV=6, rot=(0, 0, 0), smooth=True):
        m = Matrix.LocRotScale(Vector(center), Euler(rot).to_quaternion(), Vector((1, 1, 1)))
        rings = []
        for i in range(segU):
            u = 2 * math.pi * i / segU
            cu, su = math.cos(u), math.sin(u)
            rings.append([self.bm.verts.new(m @ Vector(((R + r * math.cos(2 * math.pi * j / segV)) * cu,
                                                         (R + r * math.cos(2 * math.pi * j / segV)) * su,
                                                         r * math.sin(2 * math.pi * j / segV)))) for j in range(segV)])
        faces = []
        for i in range(segU):
            A, B = rings[i], rings[(i + 1) % segU]
            for j in range(segV):
                j2 = (j + 1) % segV
                faces.append(self.bm.faces.new((A[j], B[j], B[j2], A[j2])))
        self._paint(faces, color, smooth)

    def sheet(self, center, size, color, nx=4, ny=4, disp=None, rot=(0, 0, 0), double=False, thick=0.0):
        """displaced grid in local XY (normal +Z); disp(u, v) -> z offset; optional back face / thickness"""
        m = Matrix.LocRotScale(Vector(center), Euler(rot).to_quaternion(), Vector((1, 1, 1)))
        faces = []

        def layer(zoff, flip):
            grid = []
            for j in range(ny + 1):
                row = []
                for i in range(nx + 1):
                    u, v = i / nx, j / ny
                    z = (disp(u, v) if disp else 0.0) + zoff
                    row.append(self.bm.verts.new(m @ Vector(((u - 0.5) * size[0], (v - 0.5) * size[1], z))))
                grid.append(row)
            for j in range(ny):
                for i in range(nx):
                    q = (grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
                    faces.append(self.bm.faces.new(tuple(reversed(q)) if flip else q))
            return grid

        top = layer(0.0, False)
        if double or thick > 0:
            bot = layer(-max(thick, 0.004), True)
            if thick > 0:  # close the rim
                ring_t = [top[0][i] for i in range(nx + 1)] + [top[j][nx] for j in range(1, ny + 1)] + [top[ny][i] for i in range(nx - 1, -1, -1)] + [top[j][0] for j in range(ny - 1, 0, -1)]
                ring_b = [bot[0][i] for i in range(nx + 1)] + [bot[j][nx] for j in range(1, ny + 1)] + [bot[ny][i] for i in range(nx - 1, -1, -1)] + [bot[j][0] for j in range(ny - 1, 0, -1)]
                for k in range(len(ring_t)):
                    k2 = (k + 1) % len(ring_t)
                    faces.append(self.bm.faces.new((ring_t[k], ring_b[k], ring_b[k2], ring_t[k2])))
        self._paint(faces, color)

    def face(self, pts, color, double=False):
        """flat polygon (glass shards, puddles, blades); double adds an offset back face"""
        pts = [Vector(p) for p in pts]
        vs = [self.bm.verts.new(p) for p in pts]
        fs = [self.bm.faces.new(vs)]
        if double:
            fs[0].normal_update()
            nrm = fs[0].normal.copy()
            vs2 = [self.bm.verts.new(p - nrm * 0.004) for p in reversed(pts)]
            fs.append(self.bm.faces.new(vs2))
        self._paint(fs, color)

    def face_uv(self, pts, uvs, color, double=False):
        """flat polygon with texture coordinates (foliage cards); double adds an offset back face with the same UVs"""
        if not hasattr(self, "uv"):
            self.uv = self.bm.loops.layers.uv.get("UVMap") or self.bm.loops.layers.uv.new("UVMap")
        pts = [Vector(p) for p in pts]
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        for l, uv in zip(f.loops, uvs):
            l[self.uv].uv = uv
        fs = [f]
        if double:
            f.normal_update()
            nrm = f.normal.copy()
            vs2 = [self.bm.verts.new(p - nrm * 0.004) for p in reversed(pts)]
            f2 = self.bm.faces.new(vs2)
            for l, uv in zip(f2.loops, list(reversed(uvs))):
                l[self.uv].uv = uv
            fs.append(f2)
        self._paint(fs, color)

    def paint_fn(self, fn):
        """recolour every corner: fn(position Vector, (r, g, b, a)) -> (r, g, b, a)"""
        for f in self.bm.faces:
            for l in f.loops:
                l[self.col] = fn(l.vert.co, l[self.col])

    def transform(self, matrix):
        bmesh.ops.transform(self.bm, matrix=matrix, verts=self.bm.verts)

    def finish(self, collection):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        ngons = [f for f in self.bm.faces if len(f.verts) > 4]
        if ngons:  # importers can mis-triangulate concave n-gons
            bmesh.ops.triangulate(self.bm, faces=ngons, quad_method='BEAUTY', ngon_method='EAR_CLIP')
        old = bpy.data.objects.get(self.name)
        if old:
            bpy.data.objects.remove(old)
        oldm = bpy.data.meshes.get(self.name)
        if oldm:
            bpy.data.meshes.remove(oldm)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        try:  # make "Col" the active/render colour attribute (viewport, Workbench preview, FBX)
            ca = me.color_attributes.get("Col")
            if ca:
                me.color_attributes.active_color = ca
                me.color_attributes.render_color_index = me.color_attributes.active_color_index
        except Exception:
            pass
        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        me.materials.append(vertex_material())
        return obj


def vnoise(p, s=1.0, seed=0):
    """cheap smooth 3D value noise in [-1, 1] from sines (deterministic, no textures)"""
    x, y, z = p.x * s + seed * 1.7, p.y * s - seed * 0.9, p.z * s + seed * 0.4
    return (math.sin(x * 1.7 + math.sin(y * 1.3)) * math.cos(y * 1.1 + math.sin(z * 1.9)) * 0.6
            + math.sin(z * 2.3 + x * 0.7) * 0.25 + math.sin((x + y + z) * 3.1) * 0.15)


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

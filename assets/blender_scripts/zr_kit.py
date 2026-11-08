"""Zero Return - modular map kit helpers (M13 Meridian Mall onward). Runs inside Blender after zr_lib.py.

A kit prop is split by material: every material is its own object named ZR_MK_<Prop>__<mat>, all sharing one
origin (bottom-centre, front toward Blender -Y). In Roblox each piece gets that material (and a MaterialVariant
where one fits); Roblox materials tile at a fixed studs-per-texture on meshes, so the pieces need no UVs and no
textures of their own (docs/PIPELINE.md, "Materials on meshes").

Colour, ambient occlusion and grime are baked into the "Col" vertex colours:
  * ambient occlusion: hemisphere rays from every corner against the whole prop and the floor plane;
  * floor dirt on the lowest stud, dust on up-facing surfaces, low-frequency colour variation.
Usage: imported by the build_mall_kit_*.py scripts (sys.path holds assets/blender_scripts).
"""
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
from zr_lib import Builder, vnoise, export_batch, EXP, hexc, grey, vertex_material

# material keys -> what the Roblox side does with them (src/shared/KitMeta.luau mirrors this list)
KIT_MATS = ("metal", "paint", "chrome", "plastic", "glass", "fabric", "wood", "rubber", "concrete", "stone",
            "tile", "cardboard", "leather", "neon", "glow", "plaster", "soil", "plant", "carpet")
NO_AO = ("glass", "neon", "glow")
DUST = (0.62, 0.6, 0.56, 1.0)


def _hemi(n=18):
    """cosine-weighted directions around +Z (Fibonacci spiral)"""
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        r = math.sqrt((i + 0.5) / n)
        a = i * ga
        x, y = r * math.cos(a), r * math.sin(a)
        out.append(Vector((x, y, math.sqrt(max(0.0, 1 - x * x - y * y)))))
    return out


HEMI = _hemi()


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def shade(c, k):
    return (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k), 1.0)


class Prop:
    """one kit prop: a zr_lib Builder per material, all with the same origin"""

    def __init__(self, name):
        self.name = name
        self.b = {}

    def __call__(self, mat):
        assert mat in KIT_MATS, mat
        if mat not in self.b:
            self.b[mat] = Builder("ZR_MK_%s__%s" % (self.name, mat))
        return self.b[mat]

    def transform(self, m):
        for b in self.b.values():
            b.transform(m)

    def bake(self, ao_dist=2.2, ao_strength=0.78, ground=True, floor_dirt=0.22, dust=0.16, noise=0.06, seed=0):
        bm_all = bmesh.new()
        for mat, b in self.b.items():
            if mat in NO_AO:
                continue
            me = bpy.data.meshes.new("_zr_ao_tmp")
            b.bm.to_mesh(me)
            bm_all.from_mesh(me)
            bpy.data.meshes.remove(me)
        bvh = BVHTree.FromBMesh(bm_all) if len(bm_all.faces) else None
        nh = len(HEMI)
        for mat, b in self.b.items():
            bm = b.bm
            bm.normal_update()
            glassy = mat in NO_AO
            cache = {}
            for f in bm.faces:
                n = f.normal.copy()
                if n.length < 0.5:
                    continue
                t = n.orthogonal().normalized()
                bt = n.cross(t)
                fc = f.calc_center_median()
                up = n.z > 0.6
                for l in f.loops:
                    p = l.vert.co
                    ao = 1.0
                    if not glassy and bvh is not None:
                        # sample a little inside the face (up to 30% toward its centre, at most 0.6 studs): a corner
                        # colour stands for the area around it, not the crevice right at the edge
                        to_c = fc - p
                        dist = to_c.length
                        k = min(0.3, 0.6 / dist) if dist > 1e-6 else 0.0
                        key = (round(p.x, 3), round(p.y, 3), round(p.z, 3), round(fc.x, 2), round(fc.y, 2), round(fc.z, 2))
                        ao = cache.get(key)
                        if ao is None:
                            o = p + to_c * k + n * 0.015
                            occ = 0.0
                            for d in HEMI:
                                w = t * d.x + bt * d.y + n * d.z
                                hit = bvh.ray_cast(o, w, ao_dist)
                                if hit[0] is not None:
                                    occ += 1.0 - 0.55 * (hit[3] / ao_dist)
                                elif ground and w.z < -1e-3 and o.z > -1e-3:
                                    tz = -o.z / w.z
                                    if tz < ao_dist:
                                        occ += 1.0 - 0.55 * (tz / ao_dist)
                            ao = 1.0 - ao_strength * occ / nh
                            cache[key] = ao
                    c = l[b.col]
                    k = ao
                    if not glassy:
                        if floor_dirt > 0 and ground:
                            k *= 1.0 - floor_dirt * max(0.0, 1.0 - max(0.0, p.z) / 1.1)
                        k *= 1.0 + noise * vnoise(p, 0.7, seed)
                    c = shade(c, k)
                    if up and dust > 0 and not glassy:
                        c = mix(c, DUST, dust * (0.55 + 0.45 * (0.5 + 0.5 * vnoise(p, 2.3, seed + 7))))
                    l[b.col] = c
        bm_all.free()

    def finish(self, coll, **kw):
        if kw.get("bake", True):
            self.bake(**{k: v for k, v in kw.items() if k != "bake"})
        objs = []
        for mat in sorted(self.b):
            b = self.b[mat]
            if len(b.bm.faces) == 0:
                b.bm.free()
                continue
            objs.append(b.finish(coll))
        return objs


# ── shared shapes ────────────────────────────────────────────────────────────
def rnd(seed):
    return random.Random(seed)


def shard_poly(r, cx, cz, w, h, y=0.0):
    """an irregular glass shard (polygon in the XZ plane at depth y), base along the bottom edge"""
    pts = [(cx - w / 2, y, cz), (cx + w / 2, y, cz)]
    k = r.randint(1, 3)
    for i in range(k):
        t = 1 - (i + 0.5) / k
        pts.append((cx - w / 2 + w * t + r.uniform(-w * 0.2, w * 0.2), y, cz + h * r.uniform(0.35, 1.0)))
    return pts


def broken_pane(b, x0, x1, z0, z1, color, r, y=0.0):
    """jagged glass shards left in a frame opening (bottom, top and side edges); centre missing"""
    w, h = x1 - x0, z1 - z0
    # bottom edge: upward shards
    x = x0
    while x < x1 - 0.05:
        sw = min(r.uniform(0.25, 0.9), x1 - x)
        sh = r.uniform(0.15, 0.55) * min(1.0, h / 3) + (r.random() < 0.18) * r.uniform(0.4, 1.4)
        b.face([(x, y, z0), (x + sw, y, z0), (x + sw * r.uniform(0.3, 0.7), y, z0 + sh)], color, double=True)
        x += sw
    # top edge: downward shards (longer, glass hangs)
    x = x0
    while x < x1 - 0.05:
        sw = min(r.uniform(0.3, 1.0), x1 - x)
        sh = r.uniform(0.2, 0.9) + (r.random() < 0.25) * r.uniform(0.5, 1.6)
        b.face([(x + sw, y, z1), (x, y, z1), (x + sw * r.uniform(0.3, 0.7), y, z1 - sh)], color, double=True)
        x += sw
    # side edges
    for sx, dirn in ((x0, 1), (x1, -1)):
        z = z0 + 0.3
        while z < z1 - 0.3:
            sh = min(r.uniform(0.3, 1.0), z1 - z)
            sw = r.uniform(0.1, 0.4)
            pts = [(sx, y, z), (sx, y, z + sh), (sx + dirn * sw, y, z + sh * r.uniform(0.3, 0.7))]
            if dirn < 0:
                pts = list(reversed(pts))
            b.face(pts, color, double=True)
            z += sh


def scatter_shards(b, r, cx, cy, radius, n, color, z=0.01):
    """flat glass shards lying on the floor"""
    for _ in range(n):
        a = r.uniform(0, 2 * math.pi)
        d = radius * math.sqrt(r.random())
        px, py = cx + math.cos(a) * d, cy + math.sin(a) * d
        s = r.uniform(0.08, 0.35)
        rot = r.uniform(0, 2 * math.pi)
        pts = []
        for k in range(3):
            aa = rot + k * 2.1 + r.uniform(-0.4, 0.4)
            pts.append((px + math.cos(aa) * s * r.uniform(0.6, 1.3), py + math.sin(aa) * s * r.uniform(0.6, 1.3), z + r.uniform(0, 0.02)))
        b.face(pts, color)


def rebar(b, pts, color, r=0.06):
    b.tube(pts, r, color, seg=5, smooth=True)


def chunks(b, r, cx, cy, radius, n, size, color, zbase=0.0, flat=0.55):
    """a scatter of rubble chunks"""
    for i in range(n):
        a = r.uniform(0, 2 * math.pi)
        d = radius * math.sqrt(r.random())
        s = size * r.uniform(0.4, 1.0)
        b.chunk((cx + math.cos(a) * d, cy + math.sin(a) * d, zbase + s * flat * 0.45), (s, s * r.uniform(0.7, 1.2), s * flat),
                color, seed=r.randint(0, 10 ** 6), rough=0.3, rot=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(0, 6.283)))


def contact_sheet(objs, out_png, cols=6, size=(1800, 1100), elev=28.0, azim=-35.0, pad=2.0, label=True):
    """Workbench preview of a kit batch (vertex colours, cavity, shadows) in its own scene: props in a grid seen
    from the front-left above. The source objects stay where they are (the sheet links copies of their meshes)."""
    scn = bpy.data.scenes.get("ZR_KitPreview") or bpy.data.scenes.new("ZR_KitPreview")
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    groups = {}
    for o in objs:
        groups.setdefault(o.name[len("ZR_MK_"):].split("__")[0], []).append(o)
    names = sorted(groups)
    dims = {}
    for nm in names:
        xs, ys, zs = [], [], []
        for o in groups[nm]:
            for v in o.data.vertices:
                xs.append(v.co.x); ys.append(v.co.y); zs.append(v.co.z)
        dims[nm] = (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))
    cell = max(max(d[1] - d[0], d[3] - d[2]) for d in dims.values()) + pad
    rows = (len(names) + cols - 1) // cols
    for i, nm in enumerate(names):
        cx, cy = (i % cols) * cell, -(i // cols) * cell
        d = dims[nm]
        for o in groups[nm]:
            c = bpy.data.objects.new(o.name + "_pv", o.data)
            c.location = (cx - (d[0] + d[1]) / 2, cy - (d[2] + d[3]) / 2, 0)
            scn.collection.objects.link(c)
        if label:
            cu = bpy.data.curves.new("lbl_" + nm, "FONT")
            cu.body = nm
            cu.size = cell * 0.07
            t = bpy.data.objects.new("lbl_" + nm, cu)
            t.location = (cx - cell * 0.45, cy - cell * 0.42, 0.02)
            scn.collection.objects.link(t)
    w, h = cols * cell, rows * cell
    zmax = max(d[5] for d in dims.values())
    _camera(scn, (-cell / 2, (cols - 0.5) * cell), (-(rows - 0.5) * cell, cell / 2), (0, zmax), elev, azim, size)
    _render(scn, out_png, size)
    return out_png


def _camera(scn, xr, yr, zr, elev, azim, size, margin=1.04):
    """orthographic camera from (elev, azim) fitted to the box xr x yr x zr"""
    cam_d = bpy.data.cameras.get("ZR_KitCam") or bpy.data.cameras.new("ZR_KitCam")
    cam_d.type = "ORTHO"
    cam = bpy.data.objects.get("ZR_KitCamObj") or bpy.data.objects.new("ZR_KitCamObj", cam_d)
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    e, a = math.radians(elev), math.radians(azim)
    dirv = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    q = (-dirv).to_track_quat("-Z", "Y")
    right, up = q @ Vector((1, 0, 0)), q @ Vector((0, 1, 0))
    corners = [Vector((x, y, z)) for x in xr for y in yr for z in zr]
    cx = sum(c.x for c in corners) / 8
    cy = sum(c.y for c in corners) / 8
    cz = sum(c.z for c in corners) / 8
    centre = Vector((cx, cy, cz))
    us = [(c - centre).dot(right) for c in corners]
    vs = [(c - centre).dot(up) for c in corners]
    du, dv = max(us) - min(us), max(vs) - min(vs)
    centre += right * (max(us) + min(us)) / 2 + up * (max(vs) + min(vs)) / 2
    span = max(du, dv * size[0] / size[1]) * margin
    cam.location = centre + dirv * (span * 3 + 50)
    cam.rotation_euler = q.to_euler()
    cam_d.ortho_scale = span
    cam_d.clip_end = span * 8 + 200
    scn.camera = cam


def _render(scn, out_png, size):
    if scn.world is None:
        scn.world = bpy.data.worlds.get("ZR_KitWorld") or bpy.data.worlds.new("ZR_KitWorld")
    scn.world.color = (0.32, 0.33, 0.34)
    scn.render.engine = "BLENDER_WORKBENCH"
    sh = scn.display.shading
    sh.light = "STUDIO"
    for ct in ("VERTEX", "ATTRIBUTE"):
        try:
            sh.color_type = ct
            break
        except Exception:
            pass
    sh.show_shadows = True
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    scn.display.shadow_focus = 0.6
    scn.render.resolution_x, scn.render.resolution_y = size
    scn.render.film_transparent = False
    scn.render.filepath = out_png
    win = bpy.context.window
    prev = win.scene
    win.scene = scn
    try:
        bpy.ops.render.render(write_still=True)
    finally:
        win.scene = prev
    return out_png


def turntable(objs, out_png, yaws=(-35, 35, 145), elev=16.0, size=(1800, 800), gap=1.5):
    """one prop (all its material pieces) seen from several sides, side by side"""
    scn = bpy.data.scenes.get("ZR_KitPreview") or bpy.data.scenes.new("ZR_KitPreview")
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    xs, ys, zs = [], [], []
    for o in objs:
        for v in o.data.vertices:
            xs.append(v.co.x); ys.append(v.co.y); zs.append(v.co.z)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    rad = max(math.hypot(x - cx, y - cy) for x, y in zip(xs, ys))
    step = 2 * rad + gap
    for i, yaw in enumerate(yaws):
        for o in objs:
            c = bpy.data.objects.new(o.name + "_tt%d" % i, o.data)
            c.matrix_world = Matrix.Translation((i * step, 0, 0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Translation((-cx, -cy, 0))
            scn.collection.objects.link(c)
    _camera(scn, (-rad, (len(yaws) - 1) * step + rad), (-rad, rad), (min(zs), max(zs)), elev, 0.0, size)
    _render(scn, out_png, size)
    return out_png


def kit_export(objs, batch_name, scene):
    """export a kit batch (FBX + .blend + per-mesh meta) and the per-prop bounding boxes (Roblox space)"""
    fbx, blend, meta = export_batch(objs, batch_name, scene)
    props = {}
    for o in objs:
        prop = o.name[len("ZR_MK_"):].split("__")[0]
        xs = [v.co.x for v in o.data.vertices]
        ys = [v.co.y for v in o.data.vertices]
        zs = [v.co.z for v in o.data.vertices]
        bb = props.setdefault(prop, [1e9, -1e9, 1e9, -1e9, 1e9, -1e9, []])
        bb[0], bb[1] = min(bb[0], min(xs)), max(bb[1], max(xs))
        bb[2], bb[3] = min(bb[2], min(ys)), max(bb[3], max(ys))
        bb[4], bb[5] = min(bb[4], min(zs)), max(bb[5], max(zs))
        bb[6].append(o.name.split("__")[1])
    out = {}
    for prop, bb in props.items():
        cx, cy, cz = (bb[0] + bb[1]) / 2, (bb[2] + bb[3]) / 2, (bb[4] + bb[5]) / 2
        out[prop] = {"size": [round(bb[1] - bb[0], 3), round(bb[5] - bb[4], 3), round(bb[3] - bb[2], 3)],
                     "center": [round(-cx, 3), round(cz, 3), round(cy, 3)], "mats": sorted(bb[6])}
    with open(os.path.join(EXP, batch_name + ".props.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
    return fbx, meta, out


# ── art-5b phase 2: merged pieces (docs/look/MODULAR_KIT.md, "Merged pieces") ─────────────────────────────────────
# Roblox draws each MeshPart on its own, so a prop of five materials costs five parts. The merged export joins a prop's
# opaque pieces into one ZR_MK_<Prop>__<mat>_M mesh under one material. Play does not change: the pieces are cosmetic
# (no collision, no queries) and the prop's box colliders keep the material they have today (Maps/Kit.luau: the
# first piece's), which is what bullets and footsteps read. The look does: the joined surfaces take the main
# material's grain, variant and reflectance; their colours stay, because colour is the baked vertex colour.
# How each material key renders in Roblox (Maps/Kit.luau's Kit.MATS: material, variant, reflectance); keys that render
# alike join at no cost.
KIT_LOOK = {
    "metal": ("Metal", None, 0), "paint": ("Metal", "ZR_MetalPaint", 0), "chrome": ("Metal", None, 0.12),
    "plastic": ("SmoothPlastic", None, 0), "glass": ("Glass", None, 0.05), "fabric": ("Fabric", None, 0),
    "wood": ("Wood", None, 0), "rubber": ("Rubber", None, 0), "concrete": ("Concrete", "ZR_ConcreteWorn", 0),
    "stone": ("Marble", None, 0), "tile": ("CeramicTiles", None, 0), "cardboard": ("Cardboard", None, 0),
    "leather": ("Leather", None, 0), "neon": ("SmoothPlastic", None, 0), "glow": ("Neon", None, 0),
    "plaster": ("Plaster", "ZR_PlasterPeel", 0), "soil": ("Ground", None, 0), "plant": ("Fabric", None, 0),
    "carpet": ("Carpet", None, 0),
}
MERGE_APART = ("glass", "glow")  # see-through glass; glow, which the lobby switches on and off (Lobby.luau)
# props the game uses piece by piece (Maps/Kit.luau's Kit.NOMERGE): a shot steel plate falls by its paint piece
# (Lobby.luau); the first aid box, which has no collider, is a loot container through its biggest piece
MERGE_SKIP = ("SteelPlate", "FirstAid")
MERGE_ABSORB = 1.0  # the share of a prop's opaque area a material may have and still join (1.0: one opaque piece)


def merge_plan(areas, absorb=MERGE_ABSORB):
    """The rule. areas: {mat: surface area} of one prop's pieces. The opaque pieces join under the material with the
    most area (a tie: the first in KIT_MATS); a material joins when it renders like that one or its share of the
    opaque area is absorb or less (1.0: all of them, one opaque piece per prop). Glass and glow stay apart.
    -> (mat, [joined mats in KIT_MATS order], look cost: the joined area that renders differently from mat), or None
    when fewer than two pieces would join."""
    opaque = sorted((m for m in areas if m not in MERGE_APART), key=KIT_MATS.index)
    if len(opaque) < 2:
        return None
    rep = max(opaque, key=lambda m: (areas[m], -KIT_MATS.index(m)))
    total = sum(areas[m] for m in opaque) or 1.0
    joined = [m for m in opaque if m == rep or KIT_LOOK[m] == KIT_LOOK[rep] or areas[m] / total <= absorb + 1e-9]
    if len(joined) < 2:
        return None
    return rep, joined, sum(areas[m] for m in joined if KIT_LOOK[m] != KIT_LOOK[rep])


def piece_area(o):
    """an exported piece's surface area (studs squared)"""
    return sum(p.area for p in o.data.polygons)


def kit_export_merged(objs, batch_name, scene=None, absorb=MERGE_ABSORB, expect=None):
    """Export <batch>M: the batch's props with their opaque pieces joined by merge_plan, one ZR_MK_<Prop>__<mat>_M mesh
    per prop (FBX + .blend + .meta.json, as export_batch), and <batch>M.props.json: per prop the material, the pieces
    joined, every piece's area and the look cost (the share of the prop's surface that renders differently). Props with
    fewer than two pieces to join, and MERGE_SKIP, are left out: they keep their pieces. objs: a built batch (its build
    script's objects()); expect: the batch's prop names (its PROPS), so a half-built batch is refused rather than
    exported without some props; the joined meshes are made in their own scene and removed after the export."""
    groups = {}
    for o in objs:
        prop, mat = o.name[len("ZR_MK_"):].split("__", 1)
        groups.setdefault(prop, {})[mat] = o
    missing = [n for n in (expect or ()) if n not in groups]
    if missing:
        raise RuntimeError("%d props of %s are not built (first: %s): build them, then export again" % (len(missing), batch_name, missing[0]))
    scn = bpy.data.scenes.get("ZR_KitMerged") or bpy.data.scenes.new("ZR_KitMerged")
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    made, report = [], {}
    cost_all = area_all = 0.0
    for prop in sorted(groups):
        if prop in MERGE_SKIP:
            continue
        pcs = groups[prop]
        areas = {m: piece_area(o) for m, o in pcs.items()}
        plan = merge_plan(areas, absorb)
        if plan is None:
            continue
        rep, joined, cost = plan
        name = "ZR_MK_%s__%s_M" % (prop, rep)
        old = bpy.data.meshes.get(name)
        if old:
            bpy.data.meshes.remove(old)
        bm = bmesh.new()
        for m in joined:
            bm.from_mesh(pcs[m].data)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        try:  # "Col" as the active and render colour attribute, as zr_lib.Builder.finish does
            ca = me.color_attributes.get("Col")
            if ca:
                me.color_attributes.active_color = ca
                me.color_attributes.render_color_index = me.color_attributes.active_color_index
        except Exception:
            pass
        me.materials.append(vertex_material())
        ob = bpy.data.objects.new(name, me)
        scn.collection.objects.link(ob)
        made.append(ob)
        area = sum(areas.values())
        cost_all += cost
        area_all += area
        report[prop] = {"mat": rep, "of": joined, "areas": {m: round(areas[m], 3) for m in sorted(areas)},
                        "look": round(cost / area, 4) if area > 0 else 0.0}
    if not made:
        print("%sM: no prop to merge" % batch_name)
        return None, 0, report
    fbx, blend, meta = export_batch(made, batch_name + "M", scn)
    with open(os.path.join(EXP, batch_name + "M.props.json"), "w") as f:
        json.dump(report, f, indent=1, sort_keys=True)
    for o in made:
        me = o.data
        bpy.data.objects.remove(o)
        if me.users == 0:
            bpy.data.meshes.remove(me)
    saved = sum(len(r["of"]) - 1 for r in report.values())
    print("%sM: %d props merged, %d pieces fewer for one of each; look cost %.1f %% of the merged props' surface" % (
        batch_name, len(made), saved, 100.0 * cost_all / area_all if area_all else 0.0))
    return fbx, len(made), report

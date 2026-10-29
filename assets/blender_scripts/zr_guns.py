"""Zero Return - modular gun parts (M14, owner request 2026-10-29: Tarkov-style weapon modding).

Every weapon part is its own model, built in metres (zr_items.U scales to studs) in its own frame:
  * origin = the point where it attaches to its parent's slot (a receiver's origin is the bore axis at its rear);
  * the gun points along Blender -Y (muzzle), top +Z, its left side +X (the side the pictures show);
  * P.slot(name, pos, rot) records where children attach (rot = degrees XYZ, e.g. (0, -90, 0) puts a rail
    device on the left side rail); P.anchor(name, pos) records hands, eye, muzzle, light beam, ejection port;
  * P.sub(name) starts a moving sub-part (the Tundra's bolt handle) exported as its own pieces.

From every part come (docs/weapons/WEAPON_MODDING.md):
  * an inventory picture through the item icon pipeline (a weapon base shows its default build);
  * side-view sprites at a fixed cells-per-metre scale (CLASSES), with the pixel of the part's origin, so the
    client can put any build's picture together from its parts;
  * meshes per material ZR_WP_<PART>__<mat> (sub-parts ZR_WP_<PART>__S<sub>__<mat>) with baked AO and edge wear;
  * a JSON record: pieces, slots, anchors and the 2D extents (assets/exports/ZR_Guns.parts.json).
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
import zr_items
from zr_items import Item, ITEM_MATS, col, mixc, shade, cyl_x, cyl_y, cyl_z, lathe, R, U
from zr_lib import Builder, vnoise, export_batch, EXP, ROOT
from zr_item_reg import item

SPR_OUT = os.path.join(ROOT, "assets", "renders", "guns")
# cells per metre of each picture class: a build's picture is put together from its parts at this scale, and its
# grid size is its length and height in cells (see WeaponParts.sizeOf)
CLASSES = {"long": 5.5, "pistol": 8.0}
SPRITE_CELL = 64          # atlas pixels per grid cell
SPRITE_SS = 2             # render supersampling
NO_BAKE = ("glass", "emissive")
GUN_EXPOSURE = 1.35       # dark guns read better a little brighter than the other item pictures (they sit on dark tiles)

GP = {}       # part id -> dict(fn, w, h, view, margin, cls, family, rolls)
PRESETS = {}  # preset id -> (base id, tree dict)

# ── colours ──────────────────────────────────────────────────────────────────
BLACK = col("35393B")       # anodised aluminium / phosphate
BLACK2 = col("404446")
PARK = col("3E413F")        # parkerised steel
BLUED = col("2C3237")
STEEL = col("7E8482")       # bare steel (bolt, pins)
BRIGHT = col("A9AEAA")
POLY = col("313537")        # black polymer
POLY2 = col("3B3F41")
FDE = col("8A7556")         # flat dark earth polymer
ODG = col("4F5444")         # olive drab polymer
PLUM = col("4A3530")        # plum bakelite (AK furniture)
WOOD = col("6E4A2E")
WOOD2 = col("5A3A23")
WOODL = col("80583A")
RUBBER = col("242628")
GLASS = col("2A4B5A")
COAT = col("6A4E7A")        # lens coating tint
DOT = col("FF3020")
WHITE = col("C8CCC6")

# ── the part class ────────────────────────────────────────────────────────────
class Part(Item):
    """one weapon part: a Builder per material (ZR_WP_<PART>__<mat>), slots, anchors and moving sub-parts"""

    def __init__(self, pid, prefix="ZR_WP_"):
        super().__init__(pid)
        self.prefix = prefix
        self.slots = {}
        self.anchors = {}
        self.subs = {}

    def __call__(self, mat):
        assert mat in ITEM_MATS, mat
        if mat not in self.b:
            self.b[mat] = Builder("%s%s__%s" % (self.prefix, self.name, mat))
        return self.b[mat]

    def slot(self, name, pos, rot=(0, 0, 0)):
        self.slots[name] = (Vector(pos), tuple(rot))

    def anchor(self, name, pos):
        self.anchors[name] = Vector(pos)

    def sub(self, name):
        if name not in self.subs:
            self.subs[name] = Part("%s__S%s" % (self.name, name), self.prefix)
        return self.subs[name]

    def all_builders(self):
        out = [(None, m, b) for m, b in self.b.items()]
        for sn, s in self.subs.items():
            out += [(sn, m, b) for m, b in s.b.items()]
        return out

    def finish(self, coll):
        objs = []
        for sn, mat, b in self.all_builders():
            if len(b.bm.faces) == 0:
                b.bm.free()
                continue
            b.transform(Matrix.Scale(U, 4))
            o = b.finish(coll)
            o["zr_mat"] = mat
            o["zr_part"] = self.name
            if sn:
                o["zr_sub"] = sn
            objs.append(o)
        return objs


def gpart(pid, w, h, view="left", margin=0.06, cls="long", family=None, rolls=None):
    """register a weapon part; fn(P) models it. rolls: extra sprite orientations, e.g. {"L": (0, -90, 0)}"""
    def deco(fn):
        GP[pid] = dict(fn=fn, w=w, h=h, view=view, margin=margin, cls=cls, family=family, rolls=rolls or {})

        @item(pid, w, h, view=view, margin=margin, raw=True)
        def _icon(coll):
            if pid in PRESETS:
                return build_tree(PRESETS[pid][1], coll)
            return build_part(pid, coll)[0]
        return fn
    return deco


def preset(pid, base, tree):
    """a build: tree = {slot: (part, {slot: ...})}; pid == base registers the weapon's default build"""
    PRESETS[pid] = (base, (base, tree))


def make_part(pid):
    P = Part(pid)
    GP[pid]["fn"](P)
    return P


def build_part(pid, coll, m=None, bake=True):
    P = make_part(pid)
    if bake:
        bake_part(P)
    objs = P.finish(coll)
    if m is not None:
        for o in objs:
            o.matrix_world = m @ o.matrix_world
    return objs, P


def slot_matrix(pos, rot):
    """slot frame in studs (pos in metres, rot in degrees XYZ)"""
    return Matrix.Translation(Vector(pos) * U) @ Euler(tuple(R(a) for a in rot)).to_matrix().to_4x4()


def build_tree(tree, coll, m=None, bake=True):
    """build (part, {slot: subtree}) into objects placed at their slots"""
    m = m if m is not None else Matrix.Identity(4)
    pid, kids = tree
    objs, P = build_part(pid, coll, m, bake)
    for sname, sub in kids.items():
        if sname not in P.slots:
            raise KeyError("%s has no slot %s" % (pid, sname))
        pos, rot = P.slots[sname]
        objs += build_tree(sub, coll, m @ slot_matrix(pos, rot), bake)
    return objs


# ── geometry helpers (metres) ────────────────────────────────────────────────
def ccw(pts):
    """profile [(y, z)] counter-clockwise seen from +X (y right, z up), as Builder.prism wants"""
    a = 0.0
    for i in range(len(pts)):
        y0, z0 = pts[i]
        y1, z1 = pts[(i + 1) % len(pts)]
        a += y0 * z1 - y1 * z0
    return list(pts) if a > 0 else list(reversed(pts))


def side(b, pts, w, color, bevel=0.0, x=0.0):
    """extrude a side profile [(y, z)] symmetric about x (width w)"""
    b.prism(ccw(pts), x - w / 2, x + w / 2, color, bevel=bevel)


def box(b, c, s, color, bevel=0.0, rot=(0, 0, 0)):
    b.box(c, s, color, rot=rot, bevel=bevel)


def ybar(b, y0, y1, z, r, color, seg=16, x=0.0, smooth=True, cap=True, r2=None):
    """cylinder along Y"""
    b.cyl((x, y0, z), (x, y1, z), r, color, r2=r2, seg=seg, smooth=smooth, cap=cap)


def ring(b, y, z, r, t, color, seg=20, x=0.0, l=None):
    """a thin collar around the Y axis (a raised band)"""
    l = l if l is not None else t
    b.cyl((x, y - l / 2, z), (x, y + l / 2, z), r + t, color, seg=seg, smooth=True)


def ylathe(b, profile, color, seg=24, x=0.0, y=0.0, z=0.0, smooth=True, cap0=True, cap1=True):
    """surface of revolution about a Y axis: profile [(radius, dy)] with dy along -Y (toward the muzzle)"""
    lathe(b, [(r, -h) for r, h in profile], color, seg=seg, x=x, y=y, z=z, smooth=smooth, cap_top=cap1, cap_bottom=cap0, axis="y")


def pica(b, y0, y1, z, color=BLACK, w=0.0212, x=0.0, h=0.0095, teeth=True, face="top"):
    """Picatinny-type rail on a face: body plus cross teeth every 10 mm. z = the surface it sits on (top: the
    rail rises +Z from z); face "left"/"right"/"bottom" build it on the side or under (rotated about the bore)."""
    ya, yb = min(y0, y1), max(y0, y1)
    L = yb - ya
    pts = []
    body = (0.0, (ya + yb) / 2, h * 0.32, w * 0.78, L, h * 0.64)
    boxes = [body]
    if teeth:
        n = max(1, int(L / 0.01))
        off = ya + (L - (n - 1) * 0.01) / 2
        for k in range(n):
            boxes.append((0.0, off + k * 0.01, h * 0.82, w, 0.0047, h * 0.36))
    else:
        boxes.append((0.0, (ya + yb) / 2, h * 0.82, w, L, h * 0.36))
    for (bx, by, bz, sx, sy, sz) in boxes:
        if face == "top":
            b.box((x + bx, by, z + bz), (sx, sy, sz), color)
        elif face == "bottom":
            b.box((x + bx, by, z - bz), (sx, sy, sz), color)
        elif face == "left":   # rail on the +X side, rising toward +X
            b.box((x + bz, by, z + bx), (sz, sy, sx), color)
        else:                  # right, toward -X
            b.box((x - bz, by, z + bx), (sz, sy, sx), color)


def slots_row(b, y0, y1, n, z, color, w=0.0068, l=0.032, x=None, face="left", depth=0.0012):
    """a row of dark rail slots (M-LOK style) on a side face at x (or on the bottom at z)"""
    gap = (abs(y1 - y0) - n * l) / max(1, n - 1) if n > 1 else 0
    ya = min(y0, y1)
    for k in range(n):
        y = ya + l / 2 + k * (l + gap)
        if face == "left":
            b.box((x + depth / 2, y, z), (depth, l, w), color)
        elif face == "right":
            b.box((x - depth / 2, y, z), (depth, l, w), color)
        else:
            b.box((0, y, z - depth / 2), (w, l, depth), color)


def screw(b, x, y, z, r=0.0022, color=STEEL, axis="x", slot=True):
    """a screw head on a face (axis = the face normal)"""
    if axis == "x":
        b.cyl((x - 0.0006, y, z), (x + 0.0006, y, z), r, color, seg=8)
        if slot:
            b.box((x + 0.0007, y, z), (0.0003, r * 1.5, r * 0.35), shade(color, 0.35))
    elif axis == "z":
        b.cyl((x, y, z - 0.0006), (x, y, z + 0.0006), r, color, seg=8)
        if slot:
            b.box((x, y, z + 0.0007), (r * 1.5, r * 0.35, 0.0003), shade(color, 0.35))
    else:
        b.cyl((x, y - 0.0006, z), (x, y + 0.0006, z), r, color, seg=8)


def pin(b, y, z, r, w, color=STEEL):
    """a cross pin through the receiver (both sides)"""
    b.cyl((-w / 2 - 0.0005, y, z), (w / 2 + 0.0005, y, z), r, color, seg=8)


def vents(b, y0, y1, n, z, x, color, r=0.0035, l=None, face="left"):
    """a row of round or slotted vents (dark) on a side"""
    for k in range(n):
        y = y0 + (y1 - y0) * (k + 0.5) / n
        sx = 0.0012
        xx = x + (sx / 2 if face == "left" else -sx / 2)
        if l:
            b.box((xx, y, z), (sx, l, r * 2), color, bevel=r * 0.9)
        else:
            b.cyl((xx - sx / 2, y, z), (xx + sx / 2, y, z), r, color, seg=10)


def grip_profile(y, z, rake, h, d, grooves=3, bottom=0.004, swell=0.0):
    """pistol grip side profile hanging from (y, z), raked back by `rake` degrees: finger ridges on the front
    strap, a palm swell on the back strap"""
    t = math.tan(R(rake))

    def fx(depth):
        return y - d / 2 + t * depth

    pts = [(fx(0.0), z)]
    for k in range(grooves):
        dd = 0.02 + k * (h - 0.035) / max(1, grooves)
        pts += [(fx(dd) - 0.0032, z - dd), (fx(dd + 0.009), z - dd - 0.009)]
    pts += [(fx(h) + 0.002, z - h), (fx(h) + d - bottom, z - h - 0.002), (fx(h) + d, z - h + 0.006)]
    if swell:
        pts.append((fx(h * 0.5) + d + swell, z - h * 0.5))
    pts += [(y + d / 2 + 0.003, z - 0.012), (y + d / 2, z)]
    return pts


def mag_profile(length, depth, curve, n=10):
    """side profile of a box magazine hanging from (0, 0), its spine curving forward (-Y) by `curve` degrees"""
    th = R(curve)
    sp = []
    for k in range(n + 1):
        t = k / n
        if th > 1e-4:
            rc = length / th
            a = th * t
            yy, zz = -rc * (1 - math.cos(a)), -rc * math.sin(a)
        else:
            a, yy, zz = 0.0, 0.0, -length * t
        sp.append((yy, zz, math.cos(a), -math.sin(a), a))
    front = [(yy - ny * depth / 2, zz - nz * depth / 2) for yy, zz, ny, nz, _ in sp]
    back = [(yy + ny * depth / 2, zz + nz * depth / 2) for yy, zz, ny, nz, _ in sp]
    return front + list(reversed(back)), sp


def box_mag(b, length, width, depth, curve, color, plate=None, ribs=(0.3, 0.62), rib_color=None, y=0.0, z=0.0,
            witness=0, wcol=None, feed=True):
    """a box magazine hanging from (y, z): body, ribs, base plate, feed lips and witness holes"""
    prof, sp = mag_profile(length, depth, curve)
    b.prism(ccw([(y + a, z + c) for a, c in prof]), -width / 2, width / 2, color, bevel=0.0022)

    def band(t, hh, grow, c):
        k = min(len(sp) - 1, int(round(t * (len(sp) - 1))))
        yy, zz, ny, nz, a = sp[k]
        bf = set(b.bm.verts)
        b.box((0, 0, 0), (width + grow, depth + grow, hh), c, bevel=0.0015)
        m = Matrix.Translation((0, y + yy, z + zz)) @ Matrix.Rotation(-a, 4, "X")
        bmesh.ops.transform(b.bm, matrix=m, verts=[v for v in b.bm.verts if v not in bf])

    for t in ribs:
        band(t, 0.006, 0.003, rib_color or shade(color, 0.9))
    band(0.985, 0.013, 0.006, plate or shade(color, 0.75))
    if feed:   # feed lips
        for sx in (-1, 1):
            b.box((sx * width * 0.32, y - depth * 0.1, z + 0.002), (width * 0.18, depth * 0.55, 0.004), shade(color, 1.1))
    for k in range(witness):
        kk = min(len(sp) - 1, int(round((0.18 + k * 0.6 / max(1, witness)) * (len(sp) - 1))))
        yy, zz, ny, nz, a = sp[kk]
        b.box((width / 2 + 0.0004, y + yy, z + zz), (0.0008, 0.005, 0.005), wcol or shade(color, 0.3))


def round_top(b, y, z, r=0.0045, l=0.03, color=None):
    """the top cartridge in a magazine's feed lips (brass case, copper tip)"""
    ybar(b, y + l * 0.35, y - l * 0.2, z, r, color or col("B8903E"), seg=10)


def trigger_guard(b, y0, y1, z, w=0.01, color=BLACK, r=0.0036):
    b.tube([(0, y0, z), (0, y0 - 0.004, z - 0.014), (0, (y0 + y1) / 2, z - 0.019), (0, y1, z - 0.016), (0, y1 - 0.004, z)], r, color, seg=6)


def trigger(b, y, z, color=STEEL):
    b.tube([(0, y, z), (0, y - 0.004, z - 0.008), (0, y - 0.002, z - 0.016)], 0.0018, color, seg=5)


def sling_loop(b, y, z, color=STEEL, x=0.0, r=0.0016, s=0.008):
    b.tube([(x, y - s, z), (x, y - s, z - s * 1.4), (x, y + s, z - s * 1.4), (x, y + s, z)], r, color, seg=5)


def lens(P, y, z, r, x=0.0, facing=-1, tint=None):
    """a coated glass disc facing -Y (objective) or +Y (eyepiece) with a dark ring"""
    g = P("glass")
    yy = y + facing * 0.0005
    g.cyl((x, y, z), (x, yy, z), r, tint or GLASS, seg=24)


def dot(P, y, z, r=0.0009, color=DOT, x=0.0):
    P("emissive").cyl((x, y - 0.0003, z), (x, y + 0.0003, z), r, color, seg=8)


def suppressor(P, L, r, color, collar=0.02):
    g = P("gunmetal")
    ylathe(g, [(0.0105, 0.0), (0.0155, 0.004), (0.0155, collar), (r - 0.0015, collar + 0.003), (r, collar + 0.008),
               (r, L - 0.008), (r - 0.0025, L - 0.003), (0.0075, L)], color, seg=28)
    for k in range(5):                                                   # grip grooves on the collar
        ring(g, -0.0045 - k * 0.0028, 0, 0.0155, 0.0006, shade(color, 0.55), seg=20, l=0.0012)
    ring(g, -(collar + 0.012), 0, r, 0.0004, shade(color, 0.6), seg=28, l=0.002)
    g.box((r * 0.98, -L * 0.55, 0.0), (0.0006, L * 0.32, 0.007), shade(color, 1.45))   # printed band
    ybar(g, -L + 0.0002, -L - 0.0004, 0, 0.0058, shade(color, 0.2), seg=16)
    P.anchor("muzzle", (0, -L, 0))


# ── baking: ambient occlusion, edge wear, colour variation ───────────────────
def _hemi(n=16):
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        r = math.sqrt((i + 0.5) / n)
        a = i * ga
        x, y = r * math.cos(a), r * math.sin(a)
        out.append(Vector((x, y, math.sqrt(max(0.0, 1 - x * x - y * y)))))
    return out


HEMI = _hemi()
WEAR_KEYS = {"gunmetal": 0.85, "metal": 0.5, "polymer": 0.3, "wood": 0.38, "plastic": 0.2, "rubber": 0.0,
             "glass": 0.0, "emissive": 0.0, "brass": 0.15, "copper": 0.1, "chrome": 0.1, "fabric": 0.1, "leather": 0.25}


def bake_part(P, ao_dist=0.03, strength=0.72, offset=0.0012, noise=0.05, wear=1.0, seed=None):
    """AO from the whole part (all materials but glass/lights), convex edge wear and soft colour variation"""
    seed = seed if seed is not None else (sum(ord(c) for c in P.name) % 97)
    bm_all = bmesh.new()
    for sn, mat, b in P.all_builders():
        if mat in NO_BAKE or len(b.bm.faces) == 0:
            continue
        me = bpy.data.meshes.new("_zr_gao")
        b.bm.to_mesh(me)
        bm_all.from_mesh(me)
        bpy.data.meshes.remove(me)
    bvh = BVHTree.FromBMesh(bm_all) if len(bm_all.faces) else None
    bm_all.free()
    nh = len(HEMI)
    for sn, mat, b in P.all_builders():
        bm = b.bm
        if mat in NO_BAKE or len(bm.faces) == 0:
            continue
        bm.normal_update()
        # convexity per vertex: the sharpest convex edge around it
        convex = {}
        for e in bm.edges:
            if len(e.link_faces) != 2:
                continue
            try:
                ang = e.calc_face_angle_signed()
            except ValueError:
                continue
            if ang > R(18):
                k = min(1.0, (ang - R(18)) / R(32))
                for v in e.verts:
                    convex[v] = max(convex.get(v, 0.0), k)
        wk = WEAR_KEYS.get(mat, 0.2) * wear
        cache = {}
        for f in bm.faces:
            n = f.normal.copy()
            if n.length < 0.5:
                continue
            t = n.orthogonal().normalized()
            bt = n.cross(t)
            fc = f.calc_center_median()
            for l in f.loops:
                p = l.vert.co
                key = (round(p.x, 4), round(p.y, 4), round(p.z, 4), round(n.x, 2), round(n.y, 2), round(n.z, 2))
                ao = cache.get(key)
                if ao is None:
                    ao = 1.0
                    if bvh is not None:
                        to_c = fc - p
                        dist = to_c.length
                        kk = min(0.3, 0.004 / dist) if dist > 1e-7 else 0.0
                        o = p + to_c * kk + n * offset
                        occ = 0.0
                        for d in HEMI:
                            w = t * d.x + bt * d.y + n * d.z
                            hit = bvh.ray_cast(o, w, ao_dist)
                            if hit[0] is not None:
                                occ += 1.0 - 0.6 * (hit[3] / ao_dist)
                        ao = 1.0 - strength * occ / nh
                    cache[key] = ao
                c = l[b.col]
                k = ao * (1.0 + noise * vnoise(p, 40.0, seed))
                c = (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k), 1.0)
                cv = convex.get(l.vert, 0.0)
                if cv > 0 and wk > 0:
                    patch = max(0.0, min(1.0, 0.55 + 0.9 * vnoise(p, 160.0, seed + 3)))
                    a = wk * cv * patch
                    lift = 0.42 if mat in ("gunmetal", "metal") else (0.3 if mat == "wood" else 0.24)
                    c = (min(1.0, c[0] + (lift - c[0] * 0.2) * a), min(1.0, c[1] + (lift - c[1] * 0.2) * a),
                         min(1.0, c[2] + (lift * 0.98 - c[2] * 0.2) * a), 1.0)
                l[b.col] = c


# ── lighting for gun renders ─────────────────────────────────────────────────
def gun_world():
    """a soft vertical gradient (dark floor, light sky): metal and polymer pick up a lighter top edge and a
    darker underside, as in a product shot; used for every gun picture, sprite and review render"""
    w = bpy.data.worlds.get("ZR_GunWorld")
    if w is None:
        w = bpy.data.worlds.new("ZR_GunWorld")
        w.use_nodes = True
        nt = w.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        out = nt.nodes.new("ShaderNodeOutputWorld")
        bg = nt.nodes.new("ShaderNodeBackground")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = -1.0
        mr.inputs["From Max"].default_value = 1.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.25, (0.04, 0.042, 0.045, 1.0)
        el[1].position, el[1].color = 1.0, (0.7, 0.71, 0.74, 1.0)
        mid = el.new(0.56)
        mid.color = (0.26, 0.27, 0.28, 1.0)
        nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
        nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 0.9
        nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    return w


class gun_lighting:
    """context: render with the gun world"""

    def __enter__(self):
        gun_world()
        self.prev = (zr_items.WORLD, zr_items.EXPOSURE)
        zr_items.WORLD = "ZR_GunWorld"
        zr_items.EXPOSURE = GUN_EXPOSURE

    def __exit__(self, *a):
        zr_items.WORLD, zr_items.EXPOSURE = self.prev


def run_icons(pids, seconds=45.0):
    """render the inventory pictures of these parts (a weapon base shows its default build)"""
    import zr_item_reg
    with gun_lighting():
        return zr_item_reg.run_budget(pids, seconds)


# ── review renders (docs and checking) ───────────────────────────────────────
def render_review(what, name, w=1600, h=640, view="left", margin=0.04):
    """render a part id, a preset id or a tree at w x h to assets/renders/guns/review_<name>.png"""
    with gun_lighting():
        return _render_review(what, name, w, h, view, margin)


def _render_review(what, name, w, h, view, margin):
    scn, cam, coll = zr_items.studio()
    zr_items.clear_items(coll)
    if isinstance(what, str) and what in PRESETS:
        objs = build_tree(PRESETS[what][1], coll)
    elif isinstance(what, str):
        objs = build_part(what, coll)[0]
    else:
        objs = build_tree(what, coll)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(zr_items.render_material(o.get("zr_mat", "plastic")))
    zr_items.frame(cam, objs, w, h, view, margin)
    scn.render.resolution_x, scn.render.resolution_y = w, h
    os.makedirs(SPR_OUT, exist_ok=True)
    path = os.path.join(SPR_OUT, "review_%s.png" % name)
    scn.render.filepath = path
    win = bpy.context.window
    prev = win.scene
    win.scene = scn
    try:
        bpy.ops.render.render(write_still=True, scene=scn.name)
    finally:
        win.scene = prev
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    zr_items.clear_items(coll)
    return path, tris


# ── side sprites ─────────────────────────────────────────────────────────────
def _sprite_cam(scn):
    cam = bpy.data.objects.get("ZR_SpriteCam")
    if cam is None:
        cd = bpy.data.cameras.new("ZR_SpriteCam")
        cd.type = "ORTHO"
        cam = bpy.data.objects.new("ZR_SpriteCam", cd)
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    cam.data.sensor_fit = "AUTO"
    return cam


def render_sprite(name, objs, cpm, pad=2):
    """render objs from the left (muzzle to the left) at cpm cells per metre; returns the record
    {w, h, ox, oy} in atlas pixels: the sprite size and the pixel of the part origin (from its top-left)"""
    scn, _, coll = zr_items.studio()
    cam = _sprite_cam(scn)
    prev_cam = scn.camera
    scn.camera = cam
    for o in list(coll.objects):
        coll.objects.unlink(o)
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        mat = zr_items.render_material(o.get("zr_mat", "plastic"))
        o.data.materials.clear()
        o.data.materials.append(mat)
    pts = zr_items._corners(objs)
    pps = cpm * SPRITE_CELL / U                    # atlas pixels per stud
    ss = SPRITE_SS
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    z0, z1 = min(p.z for p in pts), max(p.z for p in pts)
    W = int(math.ceil((y1 - y0) * pps)) + 2 * pad
    H = int(math.ceil((z1 - z0) * pps)) + 2 * pad
    cy, cz = (y0 + y1) / 2, (z0 + z1) / 2
    xmax = max(p.x for p in pts)
    # the same lighting as the item pictures' "left" view
    zr_items.frame(cam, objs, max(1, W), max(1, H), "left", 0.0)
    cam.data.ortho_scale = max(W, H) / pps
    cam.matrix_world = Matrix.Translation((xmax + 50.0, cy, cz)) @ Euler((R(90), 0, R(90))).to_matrix().to_4x4()
    cam.data.clip_start = 0.01
    cam.data.clip_end = 200.0
    scn.render.resolution_x = W * ss
    scn.render.resolution_y = H * ss
    os.makedirs(SPR_OUT, exist_ok=True)
    path = os.path.join(SPR_OUT, name + ".png")
    scn.render.filepath = path
    win = bpy.context.window
    prevs = win.scene
    win.scene = scn
    try:
        bpy.ops.render.render(write_still=True, scene=scn.name)
    finally:
        win.scene = prevs
        scn.camera = prev_cam
    # where the origin (0, 0, 0) lands: image x grows with +Y, image rows grow downward with -Z
    left = cy - W / (2 * pps)
    top = cz + H / (2 * pps)
    return {"w": W, "h": H, "ox": round((0.0 - left) * pps, 2), "oy": round((top - 0.0) * pps, 2), "file": name}


def sprite_jobs():
    """(sprite name, part id, class, roll name, rot) for every part: weapon parts in their family's class; generic
    parts (family None) in every class; rail devices also turned for side rails"""
    jobs = []
    for pid, e in GP.items():
        classes = [e["cls"]] if e["family"] else list(CLASSES)
        for cls in classes:
            jobs.append(("%s@%s" % (pid, cls), pid, cls, "", (0, 0, 0)))
            for rn, rot in e["rolls"].items():
                jobs.append(("%s@%s@%s" % (pid, cls, rn), pid, cls, rn, rot))
    return jobs


def run_sprites(names=None, seconds=45.0, done=None):
    """render sprites for the given job names (all by default) within a time budget; returns (records, left)"""
    with gun_lighting():
        return _run_sprites(names, seconds, done)


def _run_sprites(names, seconds, done):
    import time
    t0 = time.time()
    scn, _, coll = zr_items.studio()
    out = {}
    jobs = [j for j in sprite_jobs() if names is None or j[0] in names]
    left = []
    for name, pid, cls, rn, rot in jobs:
        if done is not None and name in done:
            continue
        if time.time() - t0 > seconds:
            left.append(name)
            continue
        zr_items.clear_items(coll)
        m = Euler(tuple(R(a) for a in rot)).to_matrix().to_4x4()
        objs, _ = build_part(pid, coll, m)
        rec = render_sprite(name, objs, CLASSES[cls])
        out[name] = rec
        if done is not None:
            done[name] = rec
        zr_items.clear_items(coll)
    return out, left


def _load_down(path, w, h, ss):
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    sw, sh = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(sh, sw, 4)
    bpy.data.images.remove(img)
    if sw != w * ss or sh != h * ss:
        raise ValueError("sprite size mismatch %s" % path)
    a = px[:, :, 3:4]
    pre = np.concatenate([px[:, :, :3] * a, a], axis=2).reshape(h, ss, w, ss, 4).mean(axis=(1, 3))
    alpha = pre[:, :, 3:4]
    rgb = np.where(alpha > 1e-4, pre[:, :, :3] / np.maximum(alpha, 1e-4), 0.0)
    return np.concatenate([rgb, alpha], axis=2)


def pack_sprites(records, prefix="ZR_GunSprites", size=1024, pad=2):
    """shelf-pack the rendered sprites (already at atlas size after the supersampling filter) into sheets"""
    import numpy as np
    items = sorted(records.items(), key=lambda kv: (-kv[1]["h"], -kv[1]["w"], kv[0]))
    sheets, placed = [], {}
    cur = None
    x = y = shelf = 0
    for name, r in items:
        w, h = r["w"], r["h"]
        if cur is None or x + w + pad > size:
            x = pad
            y += shelf
            shelf = 0
        if cur is None or y + h + pad > size:
            cur = np.zeros((size, size, 4), dtype=np.float32)
            sheets.append(cur)
            x, y, shelf = pad, pad, 0
        px = _load_down(os.path.join(SPR_OUT, r["file"] + ".png"), w, h, SPRITE_SS)
        y0 = size - y - h
        cur[y0:y0 + h, x:x + w, :] = px
        placed[name] = {"sheet": len(sheets) - 1, "x": x, "y": y, "w": w, "h": h, "ox": r["ox"], "oy": r["oy"]}
        x += w + pad
        shelf = max(shelf, h + pad)
    files = []
    for i, arr in enumerate(sheets):
        nm = "%s_%d" % (prefix, i)
        img = bpy.data.images.new(nm, size, size, alpha=True)
        img.pixels[:] = arr.ravel()
        path = os.path.join(SPR_OUT, nm + ".png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        files.append(path)
    with open(os.path.join(SPR_OUT, "sprites.json"), "w") as f:
        json.dump({"size": size, "cell": SPRITE_CELL, "classes": CLASSES, "sheets": [os.path.basename(p) for p in files], "sprites": placed}, f, indent=1, sort_keys=True)
    return placed, files


# ── export: meshes and the part records ──────────────────────────────────────
def to_rbx(v):
    """Blender metres -> Roblox studs (x, y, z) -> (-x, z, y)"""
    return [round(-v.x * U, 5), round(v.z * U, 5), round(v.y * U, 5)]


def part_record(P, objs):
    ys = [((o.matrix_world @ v.co).y) for o in objs for v in o.data.vertices]
    zs = [((o.matrix_world @ v.co).z) for o in objs for v in o.data.vertices]
    return {
        "slots": {k: {"pos": to_rbx(p), "rot": [r[0], r[2], r[1]]} for k, (p, r) in P.slots.items()},
        "anchors": {k: to_rbx(p) for k, p in P.anchors.items()},
        # 2D extents in Roblox studs: z along the gun (+Z toward the stock), y up
        "ext": [round(min(ys), 5) if ys else 0, round(max(ys), 5) if ys else 0, round(min(zs), 5) if zs else 0, round(max(zs), 5) if zs else 0],
        "tris": sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons),
    }


def export_family(batch, pids):
    """bake, export the meshes of these parts as one FBX batch; returns ({part: record}, fbx path, tris)"""
    from zr_lib import batch_scene
    scn = batch_scene(batch)
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    objs, recs = [], {}
    for pid in pids:
        po, P = build_part(pid, scn.collection)
        recs[pid] = part_record(P, po)
        recs[pid]["family"] = GP[pid]["family"]
        recs[pid]["cls"] = GP[pid]["cls"]
        recs[pid]["batch"] = batch
        objs += po
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(zr_items.render_material(o["zr_mat"]))
    fbx, blend, meta = export_batch(objs, batch, scn)
    for pid in pids:
        recs[pid]["pieces"] = {}
    for o in objs:
        pid = o["zr_part"]
        recs[pid]["pieces"][o.name] = {"mat": o["zr_mat"], "sub": o.get("zr_sub"), "center": meta[o.name]["center"], "size": meta[o.name]["size"]}
    return recs, fbx, sum(m["tris"] for m in meta.values())


def tree_json(tree):
    pid, kids = tree
    return {"id": pid, "mods": {k: tree_json(v) for k, v in sorted(kids.items())}}


def write_records(recs, path=None):
    """merge part records into assets/exports/ZR_Guns.parts.json (with every preset build)"""
    path = path or os.path.join(EXP, "ZR_Guns.parts.json")
    data = {"parts": {}, "presets": {}}
    if os.path.exists(path):
        with open(path) as f:
            data = json.load(f)
    data.setdefault("parts", {}).update(recs)
    data["presets"] = {k: {"base": v[0], "tree": tree_json(v[1])} for k, v in sorted(PRESETS.items())}
    data["classes"] = CLASSES
    with open(path, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)
    return path

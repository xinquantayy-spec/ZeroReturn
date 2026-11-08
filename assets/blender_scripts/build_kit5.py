"""Zero Return - modular kit 5 (decision art-5b, docs/look/MODULAR_KIT.md): stair flights, handrails and railings as merged
meshes with baked shading, placed by the map builders (src/server/Maps/MapKit.luau k5Flight / k5Rail) instead of loose
parts. Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_kit5.py").read(), g)
   g["build"]()          # builds what is not built yet, about 45 s a call: call again until it says remaining 0
   g["export"]()         # -> assets/exports/ZR_Kit5A.fbx (flights) and ZR_Kit5B.fbx (handrails, railings), each with its
                         #    .blend, .meta.json and .props.json
   g["sheet"]("A")       # a contact sheet of a batch for review (build/ZR_Kit5A_sheet.png)
then upload both FBX (zr_upload.upload_model(fbx, "ZR_Kit5A") / "ZR_Kit5B"), add the ids to src/shared/AssetIds.luau and
regenerate the metadata: python3 tools/kit_meta.py ZR_MallKitA ZR_MallKitB ZR_MallKitC ZR_BunkerKitA ZR_BunkerKitB
ZR_BunkerKitC ZR_Kit5A ZR_Kit5B. Until both are loaded every builder keeps its part-built stairs and railings.

Variants (every name below is a kit prop ZR_MK_<name>__<mat>, one material piece each, origin and front as in zr_kit):
  K5StairC<n>   solid concrete flight of n steps (n 4..36 and 50): the sawtooth block down to SKIRT below the foot, a steel
                angle on every nosing                                                                        piece "concrete"
  K5StairO<n>   concrete flight with an open, straight soffit (a waist slab OPEN_DEPTH thick at the risers) (n 4..24)
                                                                                                              piece "concrete"
  K5StairS<n>   steel flight: treads with a folded nosing on two flat stringers, open risers (n 4..36)    piece "metal"
  K5StairE<n>   a stopped escalator's step block: grooved metal treads, yellow edge lines (n 50)          piece "metal"
  K5HandA<n>    one side's handrail for an n-step flight with 0.5-stud risers (n 4..36): posts on the treads, a top and a
                mid rail parallel to the nosing line                                                         piece "metal"
  K5HandB<n>    the same for 0.65-stud risers (n 4..24)                                                      piece "metal"
  K5Rail<i>     a level railing module RAILS[i - 1] studs long: posts (one inset at each end, more every RAIL_SPACING),
                a top rail, a mid rail and a toe board                                                       piece "metal"
Flights are modelled at FLIGHT's riser, tread and width and the game scales each one to its flight (the step count is
never changed by scaling); the game tints every piece with the builder's colour, so the baked colours are near white
(ambient occlusion, dust, worn nosings). The lists come from the measured flights and rails of Border Yard, Meridian Mall,
the Smelter and Quay 7 (tools/kit_census.py) plus spare counts so a small layout change still finds its variant.
Flight origin: the front edge of the first riser, the middle of the width, the floor it starts from; the flight climbs
toward Blender -Y (Roblox LookVector). Railing origin: the start of the run on the deck, running toward -Y.
All geometry is original and procedural. Outside Blender, expected_meta() gives the metadata tools/kit_meta.py will write
(tools/kit_census.py uses it to count the maps with the kit loaded).
"""
import math, os, sys

try:
    import bpy  # noqa: F401  (inside Blender)
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False

SCENE = "ZR_Kit5"
BATCHES = {"A": "ZR_Kit5A", "B": "ZR_Kit5B"}

# every flight variant's riser, tread and width, and the solid flight's skirt (studs): MapKit.luau's K5 has the same numbers
FLIGHT = {"h0": 0.5, "t0": 0.8, "w0": 4.0, "skirt": 0.25, "open_depth": 1.5}
STRINGER = {"w": 0.18, "above": 0.15, "below": 0.9}
HAND = {"A": 0.5, "B": 0.65}  # handrail families by riser
HAND_TOP, HAND_MID, HAND_POST, HAND_SPACING = 3.2, 1.6, 0.14, 8.0  # above the nosing line; post size; most between posts
RAILS = [0.56, 0.67, 0.8, 0.96, 1.16, 1.39, 1.67, 2, 2.4, 2.9, 3.5, 4.1, 5, 6, 7.2, 8.6, 10.3, 12.4, 14.9, 17.8, 21.4, 25.7, 30.8, 37, 44.4, 53.3, 64]  # MapKit's K5.RAIL_LENGTHS
RAIL_TOP, RAIL_MID, RAIL_POST, RAIL_INSET, RAIL_SPACING, RAIL_KICK = 3.3, 1.7, 0.14, 0.1, 6.0, 0.3

# the counts the maps build (tools/kit_census.py, 2026-11-09): C 7 8 10 11 12 16 17 18 21 22 23 24 25 26 28 30 32 34 50;
# O 11 20 22; S 9 10 11 12 14 20 32; E 50; hands A 12 16 20 24 25 26 32, B 10 18 20; rails 0.5 to 189 studs
FLIGHTS = {"C": list(range(4, 37)) + [50], "O": list(range(4, 25)), "S": list(range(4, 37)), "E": [50]}
HANDS = {"A": list(range(4, 37)), "B": list(range(4, 25))}

# baked colours (near white: the game's tint multiplies them)
BASE = (0.93, 0.93, 0.91, 1.0)
NOSE = (0.52, 0.52, 0.53, 1.0)
STEEL = (0.9, 0.9, 0.9, 1.0)
STEEL_D = (0.62, 0.62, 0.63, 1.0)
ESC = (0.2, 0.21, 0.22, 1.0)
ESC_L = (0.32, 0.33, 0.34, 1.0)
YELLOW = (0.79, 0.63, 0.24, 1.0)


def prop_names():
    """{name: (batch key, builder)} in build order."""
    out = {}
    for st, ns in FLIGHTS.items():
        for n in ns:
            out["K5Stair%s%d" % (st, n)] = ("A", (lambda P, st=st, n=n: flight(P, st, n)))
    for fam, ns in HANDS.items():
        for n in ns:
            out["K5Hand%s%d" % (fam, n)] = ("B", (lambda P, fam=fam, n=n: handrail(P, fam, n)))
    for i, l0 in enumerate(RAILS, 1):
        out["K5Rail%d" % i] = ("B", (lambda P, l0=l0: railing(P, l0)))
    return out


# ── geometry (written against zr_lib.Builder's box / prism / cyl; outside Blender a bounds recorder stands in) ──────
def nosing(y):
    """height of the nosing line at y (flight frame, y <= 0), at the nominal riser and tread"""
    return FLIGHT["h0"] + (-y) * FLIGHT["h0"] / FLIGHT["t0"]


def sawtooth(n, h, t):
    pts = []
    for k in range(1, n):
        pts += [(-k * t, k * h), (-k * t, (k + 1) * h)]
    return pts


def flight(P, style, n):
    h, t, w = FLIGHT["h0"], FLIGHT["t0"], FLIGHT["w0"]
    if style in ("C", "E"):
        b = P("metal" if style == "E" else "concrete")
        sk = FLIGHT["skirt"]
        prof = [(0.0, -sk), (0.0, h)] + sawtooth(n, h, t) + [(-n * t, n * h), (-n * t, -sk)]
        b.prism(prof, -w / 2, w / 2, ESC if style == "E" else BASE)
        for k in range(1, n + 1):
            y0, z0 = -(k - 1) * t, k * h
            if style == "C":
                # a steel angle along the nosing, standing proud of the tread and the riser by a hair (no coplanar faces)
                b.box((0, y0 - 0.05 + 0.01, z0 - 0.03 + 0.01), (w - 0.4, 0.1, 0.06), NOSE)
            else:
                # escalator step: cleats along the travel, a yellow line at the back edge and both sides
                for i in range(10):
                    x = -w / 2 + 0.45 + i * (w - 0.9) / 9
                    b.box((x, y0 - t / 2, z0 + 0.015), (0.05, t - 0.12, 0.03), ESC_L)
                b.box((0, y0 - t + 0.06, z0 + 0.012), (w - 0.3, 0.08, 0.024), YELLOW)
                for sx in (-1, 1):
                    b.box((sx * (w / 2 - 0.12), y0 - t / 2, z0 + 0.012), (0.08, t - 0.04, 0.024), YELLOW)
    elif style == "O":
        b = P("concrete")
        d = FLIGHT["open_depth"]
        prof = [(0.0, h - d), (0.0, h)] + sawtooth(n, h, t) + [(-n * t, n * h), (-n * t, n * h - d)]
        b.prism(prof, -w / 2, w / 2, BASE)
        for k in range(1, n + 1):
            y0, z0 = -(k - 1) * t, k * h
            b.box((0, y0 - 0.05 + 0.01, z0 - 0.03 + 0.01), (w - 0.4, 0.1, 0.06), NOSE)
    elif style == "S":
        b = P("metal")
        sw, above, below = STRINGER["w"], STRINGER["above"], STRINGER["below"]
        inner = w - 2 * sw
        for k in range(1, n + 1):
            y0, z0 = -(k - 1) * t, k * h
            b.box((0, y0 - t / 2, z0 - 0.06), (inner, t + 0.04, 0.12), STEEL)  # the tread plate
            b.box((0, y0 + 0.02 - 0.02, z0 - 0.17), (inner, 0.04, 0.22), STEEL_D)  # its folded nosing
            for sx in (-1, 1):  # angle brackets under the plate's ends
                b.box((sx * (inner / 2 - 0.06), y0 - t / 2, z0 - 0.2), (0.1, t * 0.6, 0.14), STEEL_D)
        yb0 = -(below - h) * t / h
        prof = [(0.0, 0.0), (0.0, h + above), (-(n - 1) * t, n * h + above), (-n * t, n * h + above),
                (-n * t, (n + 1) * h - below), (yb0, 0.0)]
        for sx in (-1, 1):
            x0 = sx * (w / 2 - sw)
            b.prism(prof, min(x0, sx * w / 2), max(x0, sx * w / 2), STEEL_D)
    return P


def handrail(P, fam, n):
    """one side's handrail: x = 0 is the rail line; posts on the tread centres and every HAND_SPACING between"""
    h, t = HAND[fam], FLIGHT["t0"]
    b = P("metal")

    def nose(y):
        return h + (-y) * h / t

    y_first, y_last = -0.5 * t, -(n - 0.5) * t
    span = y_first - y_last
    m = max(1, math.ceil(span / HAND_SPACING - 1e-9))
    for j in range(m + 1):
        y = y_first - span * j / m
        k = int(math.floor(-y / t)) + 1  # the step under the post
        foot, top = k * h, nose(y) + HAND_TOP
        b.box((0, y, (foot + top) / 2), (HAND_POST, HAND_POST, top - foot), STEEL)
        b.box((0, y, foot + 0.02), (0.3, 0.3, 0.04), STEEL_D)
    for z_off, r in ((HAND_TOP, 0.085), (HAND_MID, 0.065)):
        a = (0.0, y_first + 0.1, nose(y_first + 0.1) + z_off)
        c = (0.0, y_last - 0.1, nose(y_last - 0.1) + z_off)
        b.cyl(a, c, r, STEEL, seg=8, smooth=True)
    return P


def railing(P, l0):
    """a level railing module l0 long: inset end posts, more every RAIL_SPACING, top and mid rails, a toe board"""
    b = P("metal")
    y0, y1 = -RAIL_INSET, -(l0 - RAIL_INSET)
    m = max(1, math.ceil((y0 - y1) / RAIL_SPACING - 1e-9))
    for j in range(m + 1):
        y = y0 + (y1 - y0) * j / m
        b.box((0, y, (RAIL_TOP + 0.08) / 2), (RAIL_POST, RAIL_POST, RAIL_TOP + 0.08), STEEL)
        b.box((0, y, 0.02), (0.2, 0.2, 0.04), STEEL_D)  # within the module's ends: two modules meet without overlapping
    b.cyl((0.0, 0.0, RAIL_TOP), (0.0, -l0, RAIL_TOP), 0.08, STEEL, seg=8, smooth=True)
    b.cyl((0.0, 0.0, RAIL_MID), (0.0, -l0, RAIL_MID), 0.065, STEEL, seg=8, smooth=True)
    b.box((0, -l0 / 2, 0.06 + RAIL_KICK / 2), (0.03, l0 - 0.02, RAIL_KICK), STEEL_D)
    return P


# ── metadata without Blender ──────────────────────────────────────────────────────────────────────────────────
class _Bounds:
    """stands in for zr_lib.Builder: records the extent (Blender space) and a triangle estimate"""

    def __init__(self):
        self.lo = [1e9, 1e9, 1e9]
        self.hi = [-1e9, -1e9, -1e9]
        self.tris = 0

    def _pt(self, p):
        for i in range(3):
            self.lo[i] = min(self.lo[i], p[i])
            self.hi[i] = max(self.hi[i], p[i])

    def box(self, center, size, color, rot=(0, 0, 0), bevel=0.0):
        assert rot == (0, 0, 0)
        for sx in (-0.5, 0.5):
            for sy in (-0.5, 0.5):
                for sz in (-0.5, 0.5):
                    self._pt((center[0] + sx * size[0], center[1] + sy * size[1], center[2] + sz * size[2]))
        self.tris += 12

    def prism(self, profile, x0, x1, color, bevel=0.0):
        for y, z in profile:
            self._pt((x0, y, z))
            self._pt((x1, y, z))
        self.tris += 2 * (len(profile) - 2) + 2 * len(profile)

    def cyl(self, a, b, r1, color, r2=None, seg=8, smooth=False, cap=True):
        # an axis in the y-z plane (rails, handrails): the ring reaches r across x and r * cos/sin across y and z
        dy, dz = b[1] - a[1], b[2] - a[2]
        ln = math.hypot(dy, dz) or 1.0
        ny, nz = -dz / ln, dy / ln  # the in-plane normal
        for p in (a, b):
            for s in (-1, 1):
                self._pt((p[0] + s * r1, p[1], p[2]))
                self._pt((p[0], p[1] + s * r1 * ny, p[2] + s * r1 * nz))
        self.tris += seg * 4

    def paint_fn(self, fn):
        pass


class _BoundsProp:
    def __init__(self, name):
        self.name = name
        self.b = {}

    def __call__(self, mat):
        if mat not in self.b:
            self.b[mat] = _Bounds()
        return self.b[mat]


def _rbx(lo, hi):
    """Blender extent -> Roblox size and centre (zr_lib.meta_for: Blender (x, y, z) -> Roblox (-x, z, y))"""
    c = [(lo[i] + hi[i]) / 2 for i in range(3)]
    s = [hi[i] - lo[i] for i in range(3)]
    return [round(s[0], 4), round(s[2], 4), round(s[1], 4)], [round(-c[0], 4), round(c[2], 4), round(c[1], 4)]


def expected_meta():
    """{name: {batch, size, center, pieces: [{mat, size, center, tris}]}} as tools/kit_meta.py will write it after export"""
    out = {}
    for name, (bk, fn) in prop_names().items():
        P = fn(_BoundsProp(name))
        lo, hi = [1e9] * 3, [-1e9] * 3
        pieces = []
        for mat in sorted(P.b):
            bb = P.b[mat]
            size, center = _rbx(bb.lo, bb.hi)
            pieces.append({"mat": mat, "size": size, "center": center, "tris": bb.tris})
            lo = [min(lo[i], bb.lo[i]) for i in range(3)]
            hi = [max(hi[i], bb.hi[i]) for i in range(3)]
        size, center = _rbx(lo, hi)
        out[name] = {"batch": BATCHES[bk], "size": size, "center": center, "pieces": pieces}
    return out


# ── Blender: build, export, review ───────────────────────────────────────────────────────────────────────────
BAKE_FLIGHT = dict(ao_dist=2.0, ao_strength=0.7, ground=True, floor_dirt=0.1, dust=0.06, noise=0.05)
BAKE_RAIL = dict(ao_dist=1.2, ao_strength=0.5, ground=True, floor_dirt=0.12, dust=0.0, noise=0.04)
BAKE_HAND = dict(ao_dist=1.2, ao_strength=0.5, ground=False, floor_dirt=0.0, dust=0.0, noise=0.04)


def _blender():
    sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
    import importlib
    import zr_lib, zr_kit
    importlib.reload(zr_lib)
    importlib.reload(zr_kit)
    return zr_lib, zr_kit


def scene():
    zr_lib, _ = _blender()
    return zr_lib.batch_scene(SCENE)


def clear(prefix):
    for o in list(bpy.data.objects):
        if o.name.startswith(prefix):
            me = o.data
            bpy.data.objects.remove(o)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)


def _built(name):
    return any(o.name.startswith("ZR_MK_%s__" % name) for o in scene().collection.objects)


def build(names=None, budget=45.0, rebuild=False):
    """builds the named props (default: all not built yet) for up to `budget` seconds; returns what it built and how many
    are left"""
    import time
    _, zr_kit = _blender()
    scn = scene()
    table = prop_names()
    todo = [n for n in (names or list(table)) if rebuild or names or not _built(n)]
    t0, done = time.time(), []
    for nm in todo:
        clear("ZR_MK_%s__" % nm)
        P = table[nm][1](zr_kit.Prop(nm))
        kw = BAKE_FLIGHT if nm.startswith("K5Stair") else (BAKE_HAND if nm.startswith("K5Hand") else BAKE_RAIL)
        P.finish(scn.collection, **kw)
        done.append(nm)
        if time.time() - t0 > budget:
            break
    left = [n for n in table if not _built(n)]
    return {"built": len(done), "last": done[-1] if done else None, "remaining": len(left)}


def objects(batch=None):
    table = prop_names()
    keep = {n for n, (bk, _) in table.items() if batch is None or bk == batch}
    return [o for o in scene().collection.objects if o.name.startswith("ZR_MK_") and o.name[6:].split("__")[0] in keep]


def export(batch=None):
    """exports batch "A", "B" or both (None); refuses while a variant is missing"""
    _, zr_kit = _blender()
    out = {}
    for bk in ([batch] if batch else ["A", "B"]):
        want = [n for n, (b, _) in prop_names().items() if b == bk]
        missing = [n for n in want if not _built(n)]
        if missing:
            raise RuntimeError("%d variants of batch %s are not built yet (first: %s): run build() again" % (len(missing), bk, missing[0]))
        objs = objects(bk)
        fbx, meta, props = zr_kit.kit_export(objs, BATCHES[bk], scene())
        out[BATCHES[bk]] = (fbx, len(objs), len(props))
    return out


def sheet(batch="A", out_png=None, names=None, **kw):
    _, zr_kit = _blender()
    out_png = out_png or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "build", "%s_sheet.png" % BATCHES[batch])
    objs = [o for o in objects(batch) if (not names or o.name[6:].split("__")[0] in names)]
    return zr_kit.contact_sheet(objs, out_png, **kw)


def turn(nm, out_png=None, **kw):
    _, zr_kit = _blender()
    out_png = out_png or os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "build", "kit5_%s.png" % nm)
    return zr_kit.turntable([o for o in objects() if o.name.startswith("ZR_MK_%s__" % nm)], out_png, **kw)


if __name__ == "__main__" and not IN_BLENDER:
    m = expected_meta()
    print(len(m), "props;", sum(len(v["pieces"]) for v in m.values()), "pieces;", "batch A", sum(1 for v in m.values() if v["batch"] == "ZR_Kit5A"),
          "batch B", sum(1 for v in m.values() if v["batch"] == "ZR_Kit5B"))
    for k in ("K5StairC12", "K5StairO11", "K5StairS20", "K5StairE50", "K5HandA20", "K5Rail9"):
        print(k, m[k])

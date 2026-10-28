"""Zero Return - operator gear meshes (M10). Run inside Blender:
   g = {}; exec(open(r"<project>/assets/blender_scripts/build_gear.py").read(), g)
Original procedural low-poly geometry: ballistic helmet, face plate, plate carrier, pouch, backpack, body
camera, pistol holster. Neutral grey vertex colours (tinted per faction by MeshPart.Color in game, like the
operator body); the body camera keeps fixed colours. Every mesh is centred on its bounding box and fitted to a
reference size, so Chars sets MeshPart.Size to whatever the gear part needs.
Exports assets/exports/ZR_Gear.fbx (+ .blend + .meta.json) in its own scene "ZR_Gear".
"""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "blender_scripts"))
import importlib, zr_lib
importlib.reload(zr_lib)
import bmesh
from zr_lib import Builder, hexc, grey, batch_scene, export_batch
from mathutils import Vector, Matrix

BASE, MID, DARK, DEEP = grey(0.86), grey(0.68), grey(0.48), grey(0.32)
CAM_BODY, CAM_TRIM, LENS, LED = hexc("1E2022"), hexc("2C2F31"), hexc("0C0D0E"), hexc("C24A35")


def B(x, y, z):
    """Roblox (x, y, z) -> Blender coordinates."""
    return (-x, z, y)


def BS(sx, sy, sz):
    return (sx, sz, sy)


class Gear(Builder):
    """Builder working in Roblox axes (x right, y up, z back; the front faces -z)."""

    def rbox(self, c, s, color, bevel=0.0):
        self.box(B(*c), BS(*s), color, bevel=bevel)

    def rcyl(self, a, b, r1, color, r2=None, seg=10, smooth=True):
        self.cyl(B(*a), B(*b), r1, color, r2=r2, seg=seg, smooth=smooth)

    def dome(self, c, radii, color, ymin=0.0, seg=18, rings=10):
        """Upper part of an ellipsoid (Roblox axes): keeps vertices with local y >= ymin * ry."""
        before = set(self.bm.faces)
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0)
        verts = res["verts"]
        # cut the lower part: flatten vertices below ymin (Blender z is Roblox y)
        for v in verts:
            if v.co.z < ymin:
                v.co.z = ymin
        rx, ry, rz = radii
        for v in verts:
            x, y, z = v.co.x, v.co.y, v.co.z
            v.co = Vector((x * rx, y * rz, z * ry)) + Vector(B(*c))
        new = [f for f in self.bm.faces if f not in before]
        self._paint(new, color, smooth=True)

    def fit(self, size):
        """scale/translate so the bounding box is exactly `size` (Roblox axes) and centred at the origin"""
        vs = self.bm.verts
        lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
        hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
        tgt = Vector(BS(*size))
        c = (lo + hi) / 2
        for v in vs:
            for i in range(3):
                ext = max(1e-6, hi[i] - lo[i])
                v.co[i] = (v.co[i] - c[i]) * (tgt[i] / ext)


def helmet(col):
    b = Gear("ZR_GEAR_Helmet")
    b.dome((0, 0, 0.02), (0.46, 0.5, 0.5), BASE, ymin=-0.18)
    # ear cut-outs read as darker side panels, a rim band, side rails, NVG shroud and a rear counterweight pouch
    for sx in (-1, 1):
        b.rbox((sx * 0.43, -0.02, 0.06), (0.06, 0.16, 0.38), MID, bevel=0.015)       # side rail
        b.rbox((sx * 0.44, -0.06, -0.05), (0.03, 0.1, 0.14), DARK, bevel=0.01)       # rail clamp
    b.rbox((0, -0.07, 0.02), (0.9, 0.05, 0.96), MID, bevel=0.015)                    # rim band
    b.rbox((0, 0.09, -0.46), (0.22, 0.14, 0.06), DARK, bevel=0.015)                  # NVG shroud
    b.rbox((0, 0.04, 0.48), (0.26, 0.16, 0.08), MID, bevel=0.02)                     # counterweight
    b.ao(-0.2, 0.5, low=0.7)
    b.fit((0.9, 0.52, 1.0))
    return b.finish(col)


def face_plate(col):
    b = Gear("ZR_GEAR_FacePlate")
    # slightly curved armoured visor made of three angled panels with an eye slot
    for i, (x, ry) in enumerate(((-0.27, 18), (0, 0), (0.27, -18))):
        before = set(b.bm.faces)
        m = Matrix.LocRotScale(Vector(B(x, 0, 0.02 * abs(i - 1))), Matrix.Rotation(math.radians(ry), 4, 'Z').to_quaternion(), Vector(BS(0.28, 0.56, 0.06)))
        bmesh.ops.create_cube(b.bm, size=1.0, matrix=m)
        b._paint([f for f in b.bm.faces if f not in before], DARK)
    b.rbox((0, 0.08, -0.04), (0.6, 0.06, 0.04), DEEP)                                # eye slot shadow
    b.fit((0.74, 0.56, 0.1))
    return b.finish(col)


def vest(col):
    b = Gear("ZR_GEAR_Vest")
    W, H, D = 1.44, 1.1, 0.98
    # front and back plate bags, cummerbund, shoulder straps, MOLLE rows, a chest admin flap
    b.rbox((0, -0.04, -D / 2 + 0.09), (W * 0.74, H * 0.86, 0.18), BASE, bevel=0.04)
    b.rbox((0, -0.02, D / 2 - 0.09), (W * 0.74, H * 0.9, 0.18), BASE, bevel=0.04)
    for sx in (-1, 1):
        b.rbox((sx * (W / 2 - 0.08), -H * 0.22, 0), (0.16, H * 0.42, D * 0.8), MID, bevel=0.03)   # cummerbund
        b.rbox((sx * 0.3, H / 2 - 0.05, 0), (0.24, 0.1, D * 0.86), MID, bevel=0.03)              # shoulder strap
        b.rbox((sx * 0.3, H / 2 - 0.05, -D / 2 + 0.08), (0.26, 0.14, 0.12), DARK, bevel=0.02)    # strap buckle
    for k in range(3):
        y = -0.32 + k * 0.17
        b.rbox((0, y, -D / 2 - 0.005), (W * 0.7, 0.035, 0.03), DARK)                         # MOLLE
        b.rbox((0, y, D / 2 + 0.005), (W * 0.7, 0.035, 0.03), DARK)
    b.rbox((0, 0.28, -D / 2 - 0.01), (W * 0.42, 0.2, 0.06), MID, bevel=0.02)                  # admin flap
    b.rbox((0, -H / 2 + 0.06, 0), (W * 0.9, 0.1, D * 0.9), DEEP, bevel=0.02)                  # lower edge
    b.ao(-H / 2, H / 2, low=0.72)
    b.fit((W, H, D))
    return b.finish(col)


def pouch(col):
    b = Gear("ZR_GEAR_Pouch")
    b.rbox((0, -0.03, 0), (0.27, 0.28, 0.18), BASE, bevel=0.03)
    b.rbox((0, 0.12, -0.005), (0.29, 0.08, 0.2), MID, bevel=0.025)                    # flap
    b.rbox((0, 0.06, -0.1), (0.08, 0.06, 0.02), DARK)                                 # pull tab
    b.rbox((0, -0.08, -0.095), (0.24, 0.02, 0.01), DARK)                              # bungee
    b.ao(-0.17, 0.17, low=0.7)
    b.fit((0.27, 0.34, 0.18))
    return b.finish(col)


def pack(col):
    b = Gear("ZR_GEAR_Pack")
    W, H, D = 1.25, 1.5, 0.66
    b.rbox((0, -0.05, 0.02), (W * 0.92, H * 0.86, D * 0.88), BASE, bevel=0.1)          # main bag
    b.rbox((0, H / 2 - 0.12, 0.02), (W * 0.96, 0.22, D * 0.94), MID, bevel=0.07)       # lid
    b.rbox((0, -0.18, D / 2 - 0.04), (W * 0.62, H * 0.42, 0.14), MID, bevel=0.05)      # front pocket (away from the back)
    for sx in (-1, 1):
        b.rbox((sx * (W / 2 - 0.04), -0.1, 0.02), (0.06, H * 0.6, D * 0.6), MID, bevel=0.02)   # side pocket
        for y in (0.16, -0.32):
            b.rbox((sx * (W / 2 - 0.02), y, 0.02), (0.04, 0.05, D * 0.92), DARK)              # compression strap
        b.rbox((sx * 0.3, H / 2 - 0.2, -D / 2 + 0.03), (0.16, 0.3, 0.06), DARK, bevel=0.02)   # shoulder strap tops
    b.ao(-H / 2, H / 2, low=0.68)
    b.jitter(0.04, seed=7)
    b.fit((W, H, D))
    return b.finish(col)


def bodycam(col):
    b = Gear("ZR_GEAR_BodyCam")
    b.rbox((0, 0, 0), (0.2, 0.26, 0.1), CAM_BODY, bevel=0.02)
    b.rbox((0, 0, 0.055), (0.16, 0.22, 0.03), CAM_TRIM, bevel=0.01)                     # clip plate (back)
    b.rcyl((0, 0.05, -0.05), (0, 0.05, -0.08), 0.045, CAM_TRIM, seg=12)                 # lens bezel
    b.rcyl((0, 0.05, -0.078), (0, 0.05, -0.085), 0.032, LENS, seg=12)                   # lens
    b.rbox((0.06, -0.08, -0.052), (0.035, 0.035, 0.01), LED)                            # record LED
    b.rbox((-0.04, -0.08, -0.052), (0.06, 0.03, 0.01), CAM_TRIM)                        # button
    b.fit((0.2, 0.26, 0.12))
    return b.finish(col)


def holster(col):
    b = Gear("ZR_GEAR_Holster")
    b.rbox((0, -0.02, 0), (0.14, 0.36, 0.3), BASE, bevel=0.03)                          # shell
    b.rbox((0, 0.15, 0.02), (0.16, 0.1, 0.32), MID, bevel=0.02)                         # hood
    b.rbox((-0.07, 0.04, 0), (0.04, 0.3, 0.12), DARK)                                   # belt loop
    b.ao(-0.21, 0.21, low=0.7)
    b.fit((0.18, 0.42, 0.34))
    return b.finish(col)


def build():
    scn = batch_scene("ZR_Gear")
    col = scn.collection
    for o in list(col.objects):
        col.objects.unlink(o)
    objs = [helmet(col), face_plate(col), vest(col), pouch(col), pack(col), bodycam(col), holster(col)]
    fbx, blend, meta = export_batch(objs, "ZR_Gear", scn)
    return fbx, meta


RESULT = build()
print("ZR_Gear", RESULT[0], {k: v["tris"] for k, v in RESULT[1].items()})

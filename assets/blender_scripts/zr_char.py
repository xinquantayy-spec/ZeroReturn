"""Zero Return - character/equipment modelling helpers (M16 block body, Blender 4.x/5.x, bmesh).
Shared by build_char_base.py (block body, helmet A, calibration cube) and the later gear batches.

Conventions (same as zr_lib / docs/PIPELINE.md): 1 Blender unit = 1 stud; Roblox (x, y, z) -> Blender (-x, z, y);
Roblox -Z (LookVector) is the character's front. All authoring calls here take ROBLOX coordinates, relative to the
host body part's centre, so an equipment mesh is attached with host.CFrame * CFrame.new(meta.center).
Colour lives in the "Col" corner attribute (vertex colours); neutral greys are tinted by MeshPart.Color in game.
"""
import math, random
import bmesh
from mathutils import Vector, Matrix, Euler
from zr_lib import Builder, hexc, grey


def B(x, y, z):
    """Roblox position -> Blender position."""
    return Vector((-x, z, y))


def BS(sx, sy, sz):
    """Roblox size -> Blender size."""
    return Vector((sx, sz, sy))


def lerp_table(tab, x):
    """piecewise-linear lookup in [(x, y), ...] (sorted by x)"""
    if x <= tab[0][0]:
        return tab[0][1]
    for (x0, y0), (x1, y1) in zip(tab, tab[1:]):
        if x <= x1:
            t = (x - x0) / max(1e-9, x1 - x0)
            return y0 + (y1 - y0) * t
    return tab[-1][1]


class CB(Builder):
    """Character builder working in Roblox axes (x right, y up, z back; the front faces -z)."""

    # ── primitives ──────────────────────────────────────────────────────────────
    def rround(self, c, s, color, r=0.08, segs=2, smooth=True, rot=None):
        """rounded box (all edges bevelled with `segs` segments); rot = Roblox Euler XYZ (radians)"""
        before = set(self.bm.faces)
        q = Euler(rot_b(rot)).to_quaternion() if rot else Euler((0, 0, 0)).to_quaternion()
        m = Matrix.LocRotScale(B(*c), q, BS(*s))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        new = self._new(before)
        rr = min(r, 0.49 * min(s))
        if rr > 0.002:
            edges = list({e for f in new for e in f.edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=rr, offset_type='OFFSET', segments=segs, profile=0.5,
                            affect='EDGES', clamp_overlap=True)
        self._paint(self._new(before), color, smooth)

    def rbox(self, c, s, color, bevel=0.0, rot=None):
        before = set(self.bm.faces)
        q = Euler(rot_b(rot)).to_quaternion() if rot else Euler((0, 0, 0)).to_quaternion()
        m = Matrix.LocRotScale(B(*c), q, BS(*s))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        new = self._new(before)
        self._bevel(new, bevel)
        self._paint(self._new(before), color)

    def rcyl(self, a, b, r1, color, r2=None, seg=10, smooth=True, cap=True):
        self.cyl(B(*a), B(*b), r1, color, r2=r2, seg=seg, smooth=smooth, cap=cap)

    def rtube(self, pts, r, color, seg=6, smooth=True, caps=True):
        self.tube([B(*p) for p in pts], r, color, seg=seg, smooth=smooth, caps=caps)

    def strap(self, pts, width, thick, color, up=(0, 1, 0)):
        """flat band through Roblox points (seat belts, straps); `up` = band normal hint"""
        before = set(self.bm.faces)
        P = [B(*p) for p in pts]
        U = B(*up).normalized()
        rings = []
        for i, p in enumerate(P):
            t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
            n = (U - t * U.dot(t))
            n = n.normalized() if n.length > 1e-6 else Vector((0, 0, 1))
            side = t.cross(n).normalized()
            hw, ht = width / 2, thick / 2
            rings.append([self.bm.verts.new(p + side * sx * hw + n * sy * ht) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
        faces = []
        for i in range(len(rings) - 1):
            A, C = rings[i], rings[i + 1]
            for k in range(4):
                k2 = (k + 1) % 4
                faces.append(self.bm.faces.new((A[k], A[k2], C[k2], C[k])))
        faces.append(self.bm.faces.new(list(reversed(rings[0]))))
        faces.append(self.bm.faces.new(rings[-1]))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self._paint(faces, color, smooth=False)

    # ── shells ──────────────────────────────────────────────────────────────────
    def shell(self, c, radii, color, rim, power=3.0, thick=0.05, useg=24, vseg=14, smooth=True, lip_color=None):
        """Superellipsoid dome (Roblox axes) cut along a rim height profile and given a thickness.
        radii = (a, b, e) half sizes along x, y, z; rim(phi_deg) -> local y of the rim at azimuth phi
        (0 = front -z, 90 = side, 180 = back). power 2 = ellipsoid, 3-4 = rounded box."""
        before = set(self.bm.faces)
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=useg, v_segments=vseg, radius=1.0)
        verts = res["verts"]
        a, b, e = radii
        cc = B(*c)
        for v in verts:
            d = v.co.normalized()  # Blender dir
            rx, rz, ry = -d.x, d.y, d.z  # Roblox dir (x, z) from Blender (-x, y); y from Blender z
            den = (abs(rx / a) ** power + abs(ry / b) ** power + abs(rz / e) ** power) ** (1.0 / power)
            rlen = 1.0 / max(den, 1e-6)
            X, Y, Z = rx * rlen, ry * rlen, rz * rlen
            phi = math.degrees(math.atan2(abs(X), -Z)) if (abs(X) + abs(Z)) > 1e-6 else 0.0
            ymin = rim(phi)
            if Y < ymin:
                Y = ymin
            v.co = cc + Vector((-X, Z, Y))
        bmesh.ops.remove_doubles(self.bm, verts=verts, dist=1e-4)
        new = [f for f in self.bm.faces if f not in before]
        bmesh.ops.dissolve_degenerate(self.bm, edges=list({e for f in new if f.is_valid for e in f.edges}), dist=1e-4)
        new = [f for f in self.bm.faces if f not in before and f.is_valid]
        # drop the flat bottom cap left by clamping (faces lying on the rim surface pointing down)
        cap = []
        for f in new:
            f.normal_update()
            if f.normal.z < -0.5 and all(abs((v.co.z - cc.z) - rim(_phi(v.co, cc))) < 0.02 for v in f.verts):
                cap.append(f)
        if cap:
            bmesh.ops.delete(self.bm, geom=cap, context='FACES')
        new = [f for f in self.bm.faces if f not in before and f.is_valid]
        if thick > 0:
            res2 = bmesh.ops.solidify(self.bm, geom=new, thickness=thick)
        new = [f for f in self.bm.faces if f not in before and f.is_valid]
        self._paint(new, color, smooth)
        if lip_color is not None:
            for f in new:
                if abs(f.normal.z) < 0.35 and all(abs((v.co.z - cc.z) - rim(_phi(v.co, cc))) < thick * 1.6 + 0.01 for v in f.verts):
                    for l in f.loops:
                        l[self.col] = lip_color

    def band(self, c, radii, power, y0, y1, color, seg=24, out=0.012, smooth=True):
        """ring strip hugging a superellipsoid between local heights y0..y1 (helmet cover bands, straps)"""
        before = set(self.bm.faces)
        a, b, e = radii
        cc = B(*c)
        rings = []
        for yy in (y0, y1):
            s = max(1e-4, 1 - abs(yy / b) ** power)
            k = s ** (1.0 / power)
            ring = []
            for i in range(seg):
                t = 2 * math.pi * i / seg
                ct, st = math.cos(t), math.sin(t)
                x = a * k * math.copysign(abs(ct) ** (2.0 / power), ct)
                z = e * k * math.copysign(abs(st) ** (2.0 / power), st)
                n = Vector((x / max(a, 1e-6), 0, z / max(e, 1e-6))).normalized()
                X, Z = x + n.x * out, z + n.z * out
                ring.append(self.bm.verts.new(cc + Vector((-X, Z, yy))))
            rings.append(ring)
        faces = []
        A, C = rings
        for i in range(seg):
            j = (i + 1) % seg
            faces.append(self.bm.faces.new((A[i], A[j], C[j], C[i])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        # outward: flip if the first face points to the centre
        f0 = faces[0]
        f0.normal_update()
        if f0.normal.dot(f0.calc_center_median() - Vector((cc.x, cc.y, f0.calc_center_median().z))) < 0:
            bmesh.ops.reverse_faces(self.bm, faces=faces)
        self._paint(faces, color, smooth)

    def arc_plate(self, c, radii, power, phi0, phi1, y0, y1, thick, color, seg=12, smooth=True, closed=False):
        """curved plate on a vertical superellipse cylinder around `c` (face shields, brims, collar panels):
        azimuth phi0..phi1 degrees (0 = front -z, +90 = +x side), heights y0..y1 (local), outer radii (a, e) along
        x / z, `thick` grown inward; closed=True makes a full ring (phi0..phi1 should span 360 degrees)"""
        a, e = radii
        cc = B(*c)
        n = seg if closed else seg + 1
        grid = []
        for k in range(2):
            sc = 1.0 if k == 0 else max(0.05, 1.0 - thick / min(a, e))
            rows = []
            for yy in (y0, y1):
                row = []
                for i in range(n):
                    phi = math.radians(phi0 + (phi1 - phi0) * i / seg)
                    st, ct = math.sin(phi), -math.cos(phi)  # x = sin, z = -cos (0 deg = front -z)
                    x = a * sc * math.copysign(abs(st) ** (2.0 / power), st)
                    z = e * sc * math.copysign(abs(ct) ** (2.0 / power), ct)
                    row.append(self.bm.verts.new(cc + Vector((-x, z, yy))))
                rows.append(row)
            grid.append(rows)
        (o0, o1), (i0, i1) = grid
        broad, rim = [], []
        for i in range(seg):
            j = (i + 1) % n
            broad.append(self.bm.faces.new((o0[i], o0[j], o1[j], o1[i])))  # outer
            broad.append(self.bm.faces.new((i0[j], i0[i], i1[i], i1[j])))  # inner
            rim.append(self.bm.faces.new((o0[j], o0[i], i0[i], i0[j])))  # bottom
            rim.append(self.bm.faces.new((o1[i], o1[j], i1[j], i1[i])))  # top
        if not closed:
            rim.append(self.bm.faces.new((o0[0], o1[0], i1[0], i0[0])))
            rim.append(self.bm.faces.new((o1[seg], o0[seg], i0[seg], i1[seg])))
        bmesh.ops.recalc_face_normals(self.bm, faces=broad + rim)
        self._paint(broad, color, smooth)
        self._paint(rim, color, False)

    def fit(self, size):
        """scale/translate so the bounding box is exactly `size` (Roblox axes) and centred at the origin"""
        vs = self.bm.verts
        lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
        hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
        tgt = BS(*size)
        c = (lo + hi) / 2
        for v in vs:
            for i in range(3):
                ext = max(1e-6, hi[i] - lo[i])
                v.co[i] = (v.co[i] - c[i]) * (tgt[i] / ext)

    def ao_y(self, ymin, ymax, low=0.7, high=1.0):
        """baked occlusion darkening toward Roblox -y (Blender z)"""
        self.ao(ymin, ymax, low, high)


def _phi(co, cc):
    X = -(co.x - cc.x)
    Z = co.y - cc.y
    return math.degrees(math.atan2(abs(X), -Z)) if (abs(X) + abs(Z)) > 1e-6 else 0.0


def rot_b(rot):
    """Roblox Euler (rx, ry, rz) -> Blender Euler (rotation about -x, about z(=roblox y), about y(=roblox z))"""
    rx, ry, rz = rot
    return (-rx, rz, ry)

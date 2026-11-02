#!/usr/bin/env python3
"""Zero Return - original touch-control icons (no third-party art), drawn from simple shapes.
Usage: python3 assets/textures/gen_touch_icons.py <out_dir>
  ZR_TEX_TouchIcons.png  1024x512  32 white icons in 128 px cells (8 per row), tinted at runtime (ImageColor3).
The cell order is TouchIcons.ICON in src/shared/TouchLayout.luau. Each icon is drawn at 4x in a 100 x 100 design
space and scaled down, so the strokes stay smooth at button size.
"""
import math, os, sys
from PIL import Image, ImageDraw

CELL, SS = 128, 4  # final cell, supersampling
BIG = CELL * SS
K = BIG / 100.0  # design units -> pixels
W = (255, 255, 255, 255)


def P(x, y):
    return (x * K, y * K)


class Pen:
    def __init__(self):
        self.img = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def dot(self, x, y, r, fill=W):
        self.d.ellipse([P(x - r, y - r), P(x + r, y + r)], fill=fill)

    def line(self, pts, w, fill=W):
        pts = [P(*p) for p in pts]
        self.d.line(pts, fill=fill, width=int(w * K), joint="curve")
        for p in pts:  # round caps and joints
            r = w * K / 2
            self.d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)

    def ring(self, x, y, r, w, fill=W):
        self.d.ellipse([P(x - r, y - r), P(x + r, y + r)], outline=fill, width=int(w * K))

    def arc(self, x, y, r, a0, a1, w, fill=W):
        # angles in degrees, 0 = +x, clockwise (PIL)
        self.d.arc([P(x - r, y - r), P(x + r, y + r)], a0, a1, fill=fill, width=int(w * K))
        for a in (a0, a1):
            px, py = x + r * math.cos(math.radians(a)), y + r * math.sin(math.radians(a))
            self.dot(px, py, w / 2, fill)

    def poly(self, pts, fill=W):
        self.d.polygon([P(*p) for p in pts], fill=fill)

    def rect(self, x0, y0, x1, y1, rad=0, fill=W, outline=None, w=0):
        if outline:
            self.d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=rad * K, outline=outline, width=int(w * K))
        else:
            self.d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=rad * K, fill=fill)

    def cut(self, fn):
        """draw with transparency (punch a hole)"""
        clear = (0, 0, 0, 0)
        fn(clear)

    mirror = False

    def done(self):
        img = self.img.transpose(Image.FLIP_LEFT_RIGHT) if self.mirror else self.img
        return img.resize((CELL, CELL), Image.LANCZOS)


def arrow_head(p, x, y, ang, size, w):
    # a chevron head at (x, y) pointing along ang (degrees, 0 = +x, 90 = down)
    a = math.radians(ang)
    for s in (150, -150):
        b = a + math.radians(s)
        p.line([(x + size * math.cos(b), y + size * math.sin(b)), (x, y)], w)


def cartridge(p, cx, top, h, w):
    """an upright cartridge: pointed bullet on a case with a rim; top = tip y, h = total height, w = case width"""
    nose = h * 0.36
    x0, x1 = cx - w / 2, cx + w / 2
    tip = top
    base = top + nose
    pts = [(x0, base)]
    for i in range(1, 12):
        t = i / 12
        # ogive: tangent-ish curve from the shoulder to the tip
        y = base - nose * (1 - (1 - t) ** 2)
        x = x0 + (cx - x0) * (1 - (1 - t) ** 0.6)
        pts.append((x, y))
    pts.append((cx, tip))
    right = [(2 * cx - px, py) for (px, py) in reversed(pts[:-1])]
    p.poly(pts + right)
    gap = h * 0.05
    p.rect(x0, base + gap, x1, top + h - h * 0.06, rad=w * 0.08)
    p.rect(x0 - w * 0.12, top + h - h * 0.08, x1 + w * 0.12, top + h, rad=w * 0.06)


def person(p, head, joints, w=7, hr=8):
    """stick figure: head = (x, y); joints = list of polylines"""
    p.dot(head[0], head[1], hr)
    for pl in joints:
        p.line(pl, w)


def magazine(p, x, y, sc=1.0):
    # a curved rifle magazine (a banana): the front edge bows forward, the back edge follows it
    n = 10
    front, back = [], []
    for i in range(n + 1):
        t = i / n
        cx = x + 22 * sc * t * t  # curves forward toward the bottom
        cy = y + 60 * sc * t
        front.append((cx + 18 * sc, cy))
        back.append((cx, cy))
    p.poly(back + list(reversed(front)))
    # the top round showing at the feed lips
    p.rect(x + 2 * sc, y - 7 * sc, x + 15 * sc, y - 1 * sc, rad=2)


def eye(p, cx, cy, s=1.0, w=6):
    # almond outline + iris + pupil
    rx, ry = 34 * s, 20 * s
    top = [(cx - rx + 2 * rx * i / 20, cy - ry * math.sin(math.pi * i / 20)) for i in range(21)]
    bot = [(cx - rx + 2 * rx * i / 20, cy + ry * math.sin(math.pi * i / 20)) for i in range(21)]
    p.line(top, w * s)
    p.line(bot, w * s)
    p.dot(cx, cy, 12 * s)
    p.dot(cx, cy, 5 * s, fill=(0, 0, 0, 0))


def reticle(p, cx, cy, r, w):
    p.ring(cx, cy, r, w)
    g = r * 0.42
    p.line([(cx - r - w, cy), (cx - g, cy)], w)
    p.line([(cx + g, cy), (cx + r + w, cy)], w)
    p.line([(cx, cy - r - w), (cx, cy - g)], w)
    p.line([(cx, cy + g), (cx, cy + r + w)], w)
    p.dot(cx, cy, w * 0.75)


def rifle(p, y=50, sc=1.0):
    p.rect(8, y - 3 * sc, 40, y + 2 * sc, rad=1)  # barrel and handguard
    p.rect(26, y - 6 * sc, 44, y + 5 * sc, rad=2)  # handguard
    p.rect(42, y - 8 * sc, 66, y + 6 * sc, rad=2)  # receiver
    p.poly([(64, y - 6 * sc), (92, y - 2 * sc), (92, y + 12 * sc), (64, y + 6 * sc)])  # stock
    p.poly([(46, y + 4 * sc), (54, y + 4 * sc), (52, y + 20 * sc), (44, y + 20 * sc)])  # magazine
    p.poly([(58, y + 4 * sc), (64, y + 4 * sc), (66, y + 14 * sc), (60, y + 14 * sc)])  # grip


ICONS = []


def icon(fn):
    ICONS.append(fn)
    return fn


@icon
def FIRE(p):
    cartridge(p, 50, 10, 80, 24)


@icon
def AIM(p):
    reticle(p, 50, 50, 30, 6)


@icon
def RELOAD(p):
    p.arc(50, 50, 33, 200, 500 - 30, 7)
    a = math.radians(470)
    arrow_head(p, 50 + 33 * math.cos(a), 50 + 33 * math.sin(a), 470 + 90, 12, 7)
    cartridge(p, 50, 30, 40, 12)


@icon
def CROUCH(p):
    # down on one knee, rifle-ready arms forward
    person(p, (44, 24), [
        [(44, 34), (40, 58)],  # torso, nearly upright
        [(40, 58), (64, 60), (64, 86)],  # front leg: thigh level, shin down
        [(40, 58), (36, 84), (22, 86)],  # back leg: knee on the ground, foot behind
        [(43, 40), (60, 48), (74, 44)],  # arms forward
    ])
    p.line([(10, 92), (90, 92)], 3)


@icon
def PRONE(p):
    person(p, (18, 56), [
        [(27, 58), (64, 64)],  # body
        [(64, 64), (90, 68)],  # legs
        [(30, 60), (22, 70), (10, 72)],  # arm forward
    ])
    p.line([(8, 82), (92, 82)], 3)


@icon
def JUMP(p):
    p.line([(50, 78), (50, 22)], 8)
    arrow_head(p, 50, 18, -90, 20, 8)
    p.line([(26, 90), (74, 90)], 6)


def lean(p, sgn):
    # the upper body tilted to one side from the hips (the legs stay planted), a chevron on that side
    hip = (54 + 0 * sgn, 60)
    a = math.radians(-24 * sgn)  # tilt of the upper body
    def U(dx, dy):  # a point of the upper body, relative to the hip, tilted
        return (hip[0] + dx * math.cos(a) - dy * math.sin(a), hip[1] + dx * math.sin(a) + dy * math.cos(a))
    person(p, U(0, -38), [
        [U(0, -28), U(0, 0)],
        [U(0, -22), U(-14, -10)],
        [U(0, -22), U(14, -10)],
        [hip, (hip[0] - 8, 90)],
        [hip, (hip[0] + 8, 90)],
    ])
    cx = 50 - 34 * sgn
    p.line([(cx + 8 * sgn, 30), (cx - 4 * sgn, 42), (cx + 8 * sgn, 54)], 6)


@icon
def LEAN_L(p):
    lean(p, 1)


@icon
def LEAN_R(p):
    lean(p, 1)
    p.mirror = True  # the exact mirror image of LEAN_L


@icon
def GRENADE(p):
    p.d.ellipse([P(28, 34), P(72, 90)], fill=W)
    p.rect(40, 24, 60, 38, rad=2)  # fuze cap
    p.poly([(58, 26), (70, 30), (72, 58), (66, 58), (64, 34), (56, 32)])  # spoon
    p.ring(34, 22, 8, 4)  # pull ring
    # segments (cut)
    for y in (52, 66, 78):
        p.line([(30, y), (70, y)], 2.4, fill=(0, 0, 0, 0))
    p.line([(50, 40), (50, 88)], 2.4, fill=(0, 0, 0, 0))


@icon
def MED(p):
    p.rect(39, 14, 61, 86, rad=4)
    p.rect(14, 39, 86, 61, rad=4)


@icon
def SWAP(p):
    p.line([(18, 36), (78, 36)], 7)
    arrow_head(p, 82, 36, 0, 14, 7)
    p.line([(82, 64), (22, 64)], 7)
    arrow_head(p, 18, 64, 180, 14, 7)


@icon
def MODE(p):
    for x in (28, 50, 72):
        cartridge(p, x, 22, 46, 12)
    p.line([(18, 82), (82, 82)], 5)
    p.poly([(22, 74), (34, 74), (28, 82)])


@icon
def MORE(p):
    for x in (24, 50, 76):
        p.dot(x, 50, 9)


@icon
def LOOK(p):
    eye(p, 50, 50)


@icon
def LIGHT(p):
    p.rect(10, 42, 40, 58, rad=3)
    p.poly([(40, 38), (52, 32), (52, 68), (40, 62)])
    p.line([(60, 38), (88, 24)], 5)
    p.line([(60, 50), (92, 50)], 5)
    p.line([(60, 62), (88, 76)], 5)


@icon
def NV(p):
    p.ring(32, 54, 15, 6)
    p.ring(68, 54, 15, 6)
    p.rect(44, 48, 56, 58, rad=2)
    p.line([(20, 42), (32, 22), (68, 22), (80, 42)], 5)


@icon
def GEAR(p):
    cx, cy = 50, 50
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        # a tooth: a short wide block on the rim
        pts = []
        for da, r in ((-11, 30), (-8, 42), (8, 42), (11, 30)):
            b = a + math.radians(da)
            pts.append((cx + r * math.cos(b), cy + r * math.sin(b)))
        p.poly(pts)
    p.dot(cx, cy, 32)
    p.dot(cx, cy, 13, fill=(0, 0, 0, 0))


@icon
def EXITS(p):
    p.line([(46, 22), (22, 22), (22, 86), (46, 86)], 6)
    p.poly([(22, 22), (40, 30), (40, 94), (22, 86)])
    p.line([(48, 54), (84, 54)], 7)
    arrow_head(p, 88, 54, 0, 14, 7)


@icon
def BAG(p):
    p.arc(50, 30, 12, 180, 360, 5)
    p.rect(26, 28, 74, 90, rad=12)
    p.rect(36, 58, 64, 80, rad=4, fill=(0, 0, 0, 0))
    p.rect(39, 61, 61, 77, rad=3)
    p.line([(26, 48), (74, 48)], 3, fill=(0, 0, 0, 0))


@icon
def RUN(p):
    person(p, (62, 16), [
        [(58, 27), (46, 54)],
        [(46, 54), (62, 66), (58, 86)],
        [(46, 54), (32, 68), (16, 64)],
        [(55, 33), (40, 40), (30, 32)],
        [(55, 33), (68, 46), (78, 40)],
    ])


@icon
def LOCK(p):
    p.arc(50, 42, 17, 180, 360, 7)
    p.line([(33, 42), (33, 50)], 7)
    p.line([(67, 42), (67, 50)], 7)
    p.rect(26, 48, 74, 88, rad=6)
    p.dot(50, 64, 5, fill=(0, 0, 0, 0))
    p.rect(48, 64, 52, 78, fill=(0, 0, 0, 0))


@icon
def BREATH(p):
    p.line([(50, 12), (50, 40)], 6)
    p.line([(50, 38), (40, 46)], 5)
    p.line([(50, 38), (60, 46)], 5)
    p.d.ellipse([P(18, 34), P(46, 90)], fill=W)
    p.d.ellipse([P(54, 34), P(82, 90)], fill=W)
    p.rect(44, 40, 56, 92, fill=(0, 0, 0, 0))


@icon
def CHAMBER(p):
    cartridge(p, 30, 22, 66, 18)
    p.ring(64, 42, 17, 6)
    p.line([(76, 54), (90, 68)], 9)


@icon
def MAGCHECK(p):
    magazine(p, 16, 20, 1.05)
    p.ring(70, 46, 15, 6)
    p.line([(81, 57), (92, 68)], 8)


@icon
def INSPECT(p):
    rifle(p, 58)
    p.ring(70, 24, 12, 5)
    p.line([(79, 33), (88, 42)], 6)


@icon
def ZERO_UP(p):
    reticle(p, 40, 56, 22, 5)
    p.line([(82, 80), (82, 26)], 7)
    arrow_head(p, 82, 22, -90, 13, 7)


@icon
def ZERO_DOWN(p):
    reticle(p, 40, 44, 22, 5)
    p.line([(82, 20), (82, 74)], 7)
    arrow_head(p, 82, 78, 90, 13, 7)


@icon
def SIGHT(p):
    # a scope from the side, and below it two arrows chasing each other (switch its mode)
    p.rect(16, 30, 84, 44, rad=4)
    p.rect(8, 24, 22, 50, rad=4)
    p.rect(72, 20, 92, 54, rad=4)
    p.rect(44, 18, 56, 30, rad=2)
    p.arc(50, 74, 14, 200, 340, 5)
    arrow_head(p, 50 + 14 * math.cos(math.radians(340)), 74 + 14 * math.sin(math.radians(340)), 70, 8, 5)
    p.arc(50, 74, 14, 20, 160, 5)
    arrow_head(p, 50 + 14 * math.cos(math.radians(160)), 74 + 14 * math.sin(math.radians(160)), 250, 8, 5)


@icon
def DEVICE(p):
    p.rect(8, 40, 34, 60, rad=3)
    p.line([(36, 50), (80, 50)], 3)
    p.dot(84, 50, 8)
    p.ring(84, 50, 14, 2.5)


@icon
def MODECHECK(p):
    for x in (24, 42, 60):
        cartridge(p, x, 14, 40, 10)
    eye(p, 56, 76, 0.62, 6)


@icon
def CLOSE(p):
    p.line([(24, 24), (76, 76)], 9)
    p.line([(76, 24), (24, 76)], 9)


@icon
def AUTO(p):
    p.ring(50, 50, 38, 6)
    p.rect(42, 26, 58, 74, rad=3)
    p.rect(26, 42, 74, 58, rad=3)


def main(out):
    os.makedirs(out, exist_ok=True)
    sheet = Image.new("RGBA", (CELL * 8, CELL * 4), (0, 0, 0, 0))
    for i, fn in enumerate(ICONS):
        p = Pen()
        fn(p)
        sheet.alpha_composite(p.done(), ((i % 8) * CELL, (i // 8) * CELL))
    path = os.path.join(out, "ZR_TEX_TouchIcons.png")
    sheet.save(path)
    print("wrote", path, len(ICONS), "icons:", ", ".join(f.__name__ for f in ICONS))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out"))

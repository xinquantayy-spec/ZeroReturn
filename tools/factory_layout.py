#!/usr/bin/env python3
"""Smelter layout generator: docs/maps/reference/factory_layout.json -> src/server/Maps/SmelterParts/Layout.luau.

The reference (EFT Factory in metres, x east, z south, game y; docs/maps/reference/FACTORY_REFERENCE.md) becomes
map-local studs for the Smelter (docs/maps/SMELTER_FACTORY_BUILD.md): S = 3.125 studs per metre, local y = (game y -
0.1) * S, so the main hall floor is y 0. Floors, walls, stairs, railings and roofs are worked out here (a 0.1 m raster
for floors and walls, the reference's stair symbols for the flights) so the Luau builder only places boxes.
Run from the repo root:  python3 -I tools/factory_layout.py      (needs numpy, scipy and Pillow)
"""
import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/maps/reference/factory_layout.json"
OUT = ROOT / "src/server/Maps/SmelterParts/Layout.luau"
S = 3.125
HALL_GY = 0.1  # game y of the main hall floor (SPT spawn points 0.04..0.31)
RES = 0.1  # raster cell, metres
X0, Z0, NX, NZ = -68.0, -74.0, 1360, 1480  # raster origin and size (covers the 131.9 x 142.5 m frame and a margin)


def ly(gy):
    return (gy - HALL_GY) * S


# levels (local studs): reference "levels"; roofs and the pit depth of the service pits are ours (grade D)
LV = {
    "basement": ly(-2.6), "sump": ly(-3.86), "hall": 0.0, "west": ly(1.08), "gallery": ly(2.73), "second": ly(4.57), "third": ly(8.23),
}
ROOF_HALL = ly(12.6)  # ours: 4.4 m over the catwalks
ROOF_LOW = ly(6.0)  # ours: the single-storey annexes and corridors
YARD_WALL = ly(4.5)  # ours: the walls round the two open yards
SLAB = 1.0  # floor slab thickness, studs
DECK = 0.5  # catwalk deck thickness
WALL_T = 0.4  # metres: the wall band round every floor
SERVICE_PIT = 1.5 * S  # ours: depth of the two service pits
# walking room (Roblox, not EFT): EFT's doorways are 0.8-1.0 m, but Roblox's pathfinding agent (radius 1 stud, 5.6
# studs tall) found no way through 0.85 m gaps in Studio (exitcheck 2026-11-09). Every walk-through gap is made at least
# MIN_PASS wide and every stair, landing and floor keeps HEAD studs of head room (tools/smelter_preview.py paths checks)
MIN_PASS = 1.4  # metres (4.4 studs)
HEAD = 7.0  # studs
# doors and doorways at floor level: EFT's are about 2.1 m; Roblox's pathfinding (agent 5.6 studs, the AI's and the exit
# walk's) found no way through a 2.1 m (6.56-stud) doorway on the office's third floor and did at 2.18 m (Studio 2026-11-09)
DOOR_H = 2.3  # metres


def r1(v):
    return round(v + 0.0, 1)


def r2(v):
    return round(v + 0.0, 2)


# ── raster helpers ──────────────────────────────────────────────────────────────────────────────────────────
def to_px(x, z):
    return ((x - X0) / RES, (z - Z0) / RES)


def poly_mask(pts):
    im = Image.new("L", (NX, NZ), 0)
    ImageDraw.Draw(im).polygon([to_px(x, z) for x, z in pts], fill=1)
    return np.asarray(im).astype(bool)


def rect_mask(x0, x1, z0, z1):
    m = np.zeros((NZ, NX), bool)
    i0, i1 = int(round((z0 - Z0) / RES)), int(round((z1 - Z0) / RES))
    j0, j1 = int(round((x0 - X0) / RES)), int(round((x1 - X0) / RES))
    m[max(0, i0):max(0, i1), max(0, j0):max(0, j1)] = True
    return m


def box_mask(b):
    # an oriented box {cx, cz, w, d, rot}
    c, s = math.cos(math.radians(b["rot"])), math.sin(math.radians(b["rot"]))
    pts = []
    for a, bb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        u, v = a * b["w"] / 2, bb * b["d"] / 2
        pts.append((b["cx"] + u * c - v * s, b["cz"] + u * s + v * c))
    return poly_mask(pts)


def rects_of(mask, min_cells=1):
    """Greedy decomposition into axis-aligned rectangles (row runs merged downward). Returns metres (x0, x1, z0, z1)."""
    out = []
    active = {}  # (j0, j1) -> i0
    prev = set()
    for i in range(NZ + 1):
        runs = set()
        if i < NZ:
            row = mask[i]
            if row.any():
                d = np.diff(np.concatenate(([0], row.astype(np.int8), [0])))
                starts, ends = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
                runs = set(zip(starts.tolist(), ends.tolist()))
        for run in prev - runs:
            i0 = active.pop(run)
            if (i - i0) * (run[1] - run[0]) >= min_cells:
                out.append((X0 + run[0] * RES, X0 + run[1] * RES, Z0 + i0 * RES, Z0 + i * RES))
        for run in runs - prev:
            active[run] = i
        prev = runs
    return out


def inmask(mask, x, z):
    j, i = int((x - X0) / RES), int((z - Z0) / RES)
    return 0 <= i < NZ and 0 <= j < NX and bool(mask[i, j])


def dilate(mask, metres):
    n = max(1, int(round(metres / RES)))
    return ndimage.binary_dilation(mask, structure=np.ones((3, 3), bool), iterations=n)


def disk(r_cells):
    yy, xx = np.mgrid[-r_cells:r_cells + 1, -r_cells:r_cells + 1]
    return xx * xx + yy * yy <= r_cells * r_cells


PASSES = []  # the widened gaps (metres: x, z, level), kept clear of loot boxes


def mouths(part, core):
    """How many separate places a narrow part of a floor opens onto its wide parts: two or more for a doorway or a
    passage (even into the same room), one for a corner or a dead end."""
    contact = ndimage.binary_dilation(part, iterations=2) & core & ~part
    return ndimage.label(contact, structure=np.ones((3, 3), bool))[1]


def runs(m, axis):
    """The length (cells) of the run of floor each cell is in, along x (axis 1) or z (axis 0)."""
    a = m if axis == 1 else m.T
    out = np.zeros(a.shape, np.int32)
    for i in np.nonzero(a.any(axis=1))[0]:
        d = np.diff(np.concatenate(([0], a[i].astype(np.int8), [0])))
        for s, e in zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]):
            out[i, s:e] = e - s
    return out if axis == 1 else out.T


def widen_necks(m, limit, level, min_w=None):
    """Passages of a floor narrower than MIN_PASS across x or z (EFT's doorways, 0.8-1.0 m, and a few tight
    corridors) that open onto wider floor at two or more places are taken to MIN_PASS: each short run across them grows
    about its middle, within `limit`. Corners, niches and dead ends (one opening) are left as they are."""
    min_w = MIN_PASS if min_w is None else min_w
    need = int(round(min_w / RES))
    rx, rz = runs(m, 1), runs(m, 0)
    narrow = m & ((rx < need) | (rz < need))
    wide = m & ~narrow
    lab, _ = ndimage.label(narrow, structure=np.ones((3, 3), bool))
    sel = np.zeros_like(m)
    for k, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl is None:
            continue
        i0, i1 = max(0, sl[0].start - 3), min(NZ, sl[0].stop + 3)
        j0, j1 = max(0, sl[1].start - 3), min(NX, sl[1].stop + 3)
        part = lab[i0:i1, j0:j1] == k
        if part.sum() >= 3 and mouths(part, wide[i0:i1, j0:j1]) >= 2:
            sel[i0:i1, j0:j1] |= part
            ii, jj = np.nonzero(part)
            PASSES.append((X0 + (j0 + jj.mean() + 0.5) * RES, Z0 + (i0 + ii.mean() + 0.5) * RES, level))
    add = np.zeros_like(m)
    for axis in (0, 1):
        a, s_ = (m, sel) if axis == 0 else (m.T, sel.T)
        ad = add if axis == 0 else add.T
        for j in np.nonzero(s_.any(axis=0))[0]:
            d = np.diff(np.concatenate(([0], a[:, j].astype(np.int8), [0])))
            for s, e in zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]):
                if e - s < need and s_[s:e, j].any():
                    c0 = int(round((s + e) / 2 - need / 2))
                    ad[max(0, c0):min(a.shape[0], c0 + need), j] = True
    add &= limit & ~m
    return m | add, add


# ── the reference ───────────────────────────────────────────────────────────────────────────────────────────
ref = json.loads(SRC.read_text())
F = ref["floors"]


def rings(level, role=None, idx=None):
    return [r for r in F[level] if (role is None or r["role"] == role) and (idx is None or r["i"] in idx)]


def union(rs):
    m = np.zeros((NZ, NX), bool)
    for r in rs:
        m |= poly_mask(r["pts"])
    return m


# ground
G_out = union(rings("ground", "outer"))
G_holes = {r["i"]: poly_mask(r["pts"]) for r in rings("ground", "hole")}
G_floor = G_out.copy()
for k, m in G_holes.items():
    G_floor &= ~m
# the doorways with a door leaf keep the leaf's width (the openings below cut them to MIN_PASS exactly)
DOOR_KEEP = (rect_mask(50.75 - 1.6, 50.75 + 1.6, 24.83 - 1.6, 24.83 + 1.6) | rect_mask(-42.05 - 1.6, -42.05 + 1.6, 26.04 - 1.6, 26.04 + 1.6)
             | rect_mask(30.8 - 1.6, 30.8 + 1.6, -60.95 - 1.6, -60.95 + 1.6))
G_floor, g_add = widen_necks(G_floor, dilate(G_out, 0.35) & ~DOOR_KEEP, "ground")
for k in G_holes:
    G_holes[k] &= ~g_add
ledges = ref["ledges"]
PIT = [l for l in ledges if l["w"] > 30][0]
SPITS = [l for l in ledges if l["w"] < 10]
DOCK = [l for l in ledges if 15 < l["w"] < 30][0]  # the loading dock (a raised ledge; ring 21 is its east and south wall)
pit_m = box_mask(PIT)
dock_m = box_mask(DOCK) & G_out
# the raised west part (SPT: the south-west wing, the courtyard and the office ground floor stand at game y 1.08)
west_m = (G_out & rect_mask(-70, -32.45, -31.3, 75)) | poly_mask([r for r in F["ground"] if r["i"] == 18][0]["pts"])
west_m &= ~dock_m
COURT = [r for r in F["ground"] if r["i"] == 18][0]
court_m = poly_mask(COURT["pts"])
# the east yard (open sky): the part of the outline east of x 38.6 between z -42.3 and 16.4
yard_e = G_out & rect_mask(38.55, 70, -42.3, 16.4)
open_m = court_m | yard_e

# basement
B_out = union(rings("basement", "outer"))
B_holes = union(rings("basement", "hole"))
B_floor = B_out & ~B_holes
B_floor, _ = widen_necks(B_floor, dilate(B_out, 0.35) & ~DOOR_KEEP, "basement")
B_floor |= rect_mask(-42.39, -41.71, 26.04 - MIN_PASS / 2, 26.04 + MIN_PASS / 2)  # the sealed store's doorway (SVG 1.09 m)
B_floor |= rect_mask(30.8 - MIN_PASS / 2, 30.8 + MIN_PASS / 2, -61.05, -60.85)  # the cable cellar's doorway (SVG 1.0 m)
B_isl = union(rings("basement", "island"))  # the two service pits
sump_m = B_floor & (rect_mask(9.9, 70, 1.7, 30.2) | rect_mask(0.0, 70, 22.5, 36))

# second floor pieces
S2 = {r["i"]: r for r in F["second"]}
s2_office = poly_mask(S2[4]["pts"]) & ~poly_mask(S2[5]["pts"])
s2_dock = s2_office & rect_mask(-37.9, -32.0, -1.45, 20)
s2_office &= ~s2_dock
s2_bridge = poly_mask(S2[0]["pts"]) | rect_mask(-33.56, -32.2, 27.0, 29.13) | rect_mask(-19.3, -17.8, 27.2, 29.13)
s2_deck = poly_mask(S2[1]["pts"]) & ~poly_mask(S2[2]["pts"])
boilers = [o for o in ref["obstacles"]["ground"] if o.get("kind") == "boiler"]
for b in boilers:
    s2_deck &= ~box_mask(b)
s2_pump = poly_mask(S2[3]["pts"])
s2_east = poly_mask(S2[6]["pts"]) & ~poly_mask(S2[7]["pts"])
s2_block = poly_mask(S2[5]["pts"])  # the closed block beside the drop (re3mr: black)
s2_office, _ = widen_necks(s2_office, dilate(s2_office, 0.35) & ~s2_dock & ~s2_block, "second")
s2_pump, _ = widen_necks(s2_pump, dilate(s2_pump, 0.35), "second")
s2_east, _ = widen_necks(s2_east, dilate(s2_east, 0.35) & ~poly_mask(S2[7]["pts"]), "second")

# third floor
T_out = union(rings("third", "outer"))
T_void_thin = []
T_floor = T_out.copy()
for r in rings("third", "void"):
    xs = [p[0] for p in r["pts"]]
    zs = [p[1] for p in r["pts"]]
    if min(max(xs) - min(xs), max(zs) - min(zs)) < 1.0:
        T_void_thin.append(r)  # thin "voids" are walls and beams
    T_floor &= ~poly_mask(r["pts"])
OFFICE3 = rect_mask(-40.6, -32.0, -32.4, -1.2)  # the office block's third floor (hand-read walls below)
# EFT's rafters are 0.9 m catwalks, in places two of them side by side 0.6 m apart: here those pairs are one deck and
# every catwalk narrower than MIN_PASS widens to it (Roblox's pathfinding agent found no way along them, art-1a)
_away = ~dilate(OFFICE3, 0.6)
_seams = ndimage.binary_closing(T_floor, structure=np.ones((3, 3), bool), iterations=4) & ~T_floor & _away
T_floor |= _seams
T_floor, _ = widen_necks(T_floor, dilate(T_floor, 0.35) & _away, "third")
T_out |= T_floor

# ── roofs and wall heights ──────────────────────────────────────────────────────────────────────────────────
# low annexes and corridors (ours): name, x0, x1, z0, z1
LOW = [
    ("NORTH GALLERY", -41, 33, -66, -61.7), ("ORE GATE ANNEX", -66, -40.4, -57, -49), ("FORKLIFT BAY", 32, 67, -70, -53.4),
    ("SOUTH ANNEX", -9.5, -2, 29.1, 55), ("GATE CORRIDOR", 38.2, 64, 19.9, 27.5), ("SLAG GATE CORRIDOR", -58, -50.5, 52.2, 72),
    ("EAST BAYS", 36.3, 62.5, -42.4, -35.2),
]
roof_h = np.full((NZ, NX), ROOF_HALL)
for _, x0, x1, z0, z1 in LOW:
    roof_h[rect_mask(x0, x1, z0, z1)] = ROOF_LOW
roof_h[open_m] = YARD_WALL
all_ground = G_out | dock_m


UPPER = []  # (mask, floor height): filled once the upper floors are known; a wall under one stops below it


def wall_height(rect):
    x0, x1, z0, z1 = rect
    m = rect_mask(x0 - 0.6, x1 + 0.6, z0 - 0.6, z1 + 0.6) & all_ground
    top = float(roof_h[m].max()) if m.any() else ROOF_LOW
    inner = rect_mask(x0, x1, z0, z1)
    n = inner.sum()
    if n:
        for um, uy, th in UPPER:
            if (um & inner).sum() > 0.3 * n:
                top = min(top, uy - th)
    return top


# ── floors ──────────────────────────────────────────────────────────────────────────────────────────────────
slabs = []  # x0, x1, z0, z1, yTop, thickness, kind


def close(mask, metres=0.3):
    """Fill notches narrower than about twice `metres` (the walls stand over them anyway): fewer, larger slabs."""
    n = max(1, int(round(metres / RES)))
    return ndimage.binary_closing(mask, structure=np.ones((3, 3), bool), iterations=n) | mask


def add_slabs(mask, ytop, th, kind, min_cells=4):
    for x0, x1, z0, z1 in rects_of(mask, min_cells):
        slabs.append([r2(x0 * S), r2(x1 * S), r2(z0 * S), r2(z1 * S), r2(ytop), r2(th), kind])


# stair flights first (their footprints cut the slabs they pass through)
flights = []  # x0, x1, z0, z1, yBottom, rise, dir, stacked, id
landings = []  # x0, x1, z0, z1, yTop
cuts = []  # (mask, ylevel-from, ylevel-to): open the slabs whose top is in (from, to]


def level_at(kind, x, z):
    """The local floor height of a level at a point (None when there is no floor there)."""
    if kind == "basement":
        if inmask(B_floor, x, z):
            return LV["sump"] if inmask(sump_m, x, z) else LV["basement"]
        return None
    if kind == "ground":
        if inmask(dock_m, x, z):
            return LV["gallery"]
        if inmask(G_floor, x, z) or inmask(court_m, x, z):
            return LV["west"] if inmask(west_m, x, z) else LV["hall"]
        return None
    if kind == "second":
        if inmask(s2_office, x, z) or inmask(s2_deck, x, z) or inmask(s2_pump, x, z) or inmask(s2_east, x, z):
            return LV["second"]
        if inmask(s2_dock, x, z) or inmask(s2_bridge, x, z):
            return LV["gallery"]
        return None
    if kind == "third":
        return LV["third"] if inmask(T_floor, x, z) or inmask(OFFICE3, x, z) else None
    return None


def axis_box(st):
    if abs(st["rot"]) < 1:
        return st["cx"] - st["w"] / 2, st["cx"] + st["w"] / 2, st["cz"] - st["d"] / 2, st["cz"] + st["d"] / 2, "x"
    return st["cx"] - st["d"] / 2, st["cx"] + st["d"] / 2, st["cz"] - st["w"] / 2, st["cz"] + st["w"] / 2, "z"


def solve_straight(st, lo, hi):
    """One flight over the symbol from level `lo` up to level `hi`; the direction is the one whose low end opens onto
    the lower floor and whose high end onto the upper floor (0.7 m beyond each end)."""
    x0, x1, z0, z1, ax = axis_box(st)
    best = None
    for sgn in (1, -1):
        if ax == "x":
            lowp = (x0 - 0.7, (z0 + z1) / 2) if sgn > 0 else (x1 + 0.7, (z0 + z1) / 2)
            highp = (x1 + 0.7, (z0 + z1) / 2) if sgn > 0 else (x0 - 0.7, (z0 + z1) / 2)
            inner_low = (x0 + 0.3, (z0 + z1) / 2) if sgn > 0 else (x1 - 0.3, (z0 + z1) / 2)
        else:
            lowp = ((x0 + x1) / 2, z0 - 0.7) if sgn > 0 else ((x0 + x1) / 2, z1 + 0.7)
            highp = ((x0 + x1) / 2, z1 + 0.7) if sgn > 0 else ((x0 + x1) / 2, z0 - 0.7)
            inner_low = ((x0 + x1) / 2, z0 + 0.3) if sgn > 0 else ((x0 + x1) / 2, z1 - 0.3)
        ylo = level_at(lo, *lowp)
        if ylo is None:
            ylo = level_at(lo, *inner_low)
        yhi = level_at(hi, *highp)
        score = (2 if level_at(lo, *lowp) is not None else 0) + (2 if yhi is not None else 0)
        if best is None or score > best[0]:
            best = (score, sgn, ylo, yhi)
    score, sgn, ylo, yhi = best
    if ylo is None:
        ylo = LV["basement"] if lo == "basement" else LV["hall"]
    if yhi is None:
        yhi = {"basement": LV["basement"], "ground": LV["hall"], "second": LV["second"], "third": LV["third"]}[hi]
    d = ("+" if sgn > 0 else "-") + ax
    return [r2(x0 * S), r2(x1 * S), r2(z0 * S), r2(z1 * S), r2(ylo), r2(yhi - ylo), d, False, st["id"], score]


def u_tower(st, levels, half_landing_side=None):
    """A switchback tower over the symbol: two flights per storey in the two halves of its long side, landings at
    both ends (the storey landing at the end that opens onto the floors)."""
    x0, x1, z0, z1, ax = axis_box(st)
    # the symbol can reach into the wall at a tower's end (the office's two stairs by 0.6 m): the tower stops where
    # the ground storey's floor does, or its half landing is too shallow to turn on
    fl = G_floor | court_m
    if (fl & rect_mask(x0, x1, z0, z1)).sum() > 0.5 * rect_mask(x0, x1, z0, z1).sum():
        def full(a0, a1, b0, b1):
            m_ = rect_mask(a0, a1, b0, b1)
            return (fl & m_).sum() >= 0.8 * max(1, m_.sum())
        if ax == "x":
            while x1 - x0 > 4 and not full(x0, x0 + 0.1, z0, z1):
                x0 += 0.1
            while x1 - x0 > 4 and not full(x1 - 0.1, x1, z0, z1):
                x1 -= 0.1
        else:
            while z1 - z0 > 4 and not full(x0, x1, z0, z0 + 0.1):
                z0 += 0.1
            while z1 - z0 > 4 and not full(x0, x1, z1 - 0.1, z1):
                z1 -= 0.1
    land = 1.25 if (x1 - x0 if ax == "x" else z1 - z0) < 7 else 1.5  # metres at each end
    out_f, out_l = [], []
    # which end opens onto the floors: test both ends on the first upper level
    ends = []
    for e in (-1, 1):
        if ax == "x":
            p = ((x1 + 0.8) if e > 0 else (x0 - 0.8), (z0 + z1) / 2)
        else:
            p = ((x0 + x1) / 2, (z1 + 0.8) if e > 0 else (z0 - 0.8))
        ends.append((sum(1 for lv in levels[1:] if level_at(lv, *p) is not None), e))
    ends.sort(reverse=True)
    floor_end = ends[0][1]
    ys = []
    for lv in levels:
        y = None
        for e in (-1, 1):
            if ax == "x":
                p = ((x1 + 0.8) if e > 0 else (x0 - 0.8), (z0 + z1) / 2)
            else:
                p = ((x0 + x1) / 2, (z1 + 0.8) if e > 0 else (z0 - 0.8))
            y = y if y is not None else level_at(lv, *p)
        if y is None:
            y = {"basement": LV["basement"], "ground": LV["hall"], "second": LV["second"], "third": LV["third"]}[lv]
        ys.append(y)
    # halves across the short side
    if ax == "x":
        halves = [(z0, (z0 + z1) / 2 - 0.06), ((z0 + z1) / 2 + 0.06, z1)]
        run0, run1 = x0 + land, x1 - land
    else:
        halves = [(x0, (x0 + x1) / 2 - 0.06), ((x0 + x1) / 2 + 0.06, x1)]
        run0, run1 = z0 + land, z1 - land
    away = -floor_end  # the first flight of each storey climbs away from the floor end
    for k in range(len(ys) - 1):
        ya, yb = ys[k], ys[k + 1]
        mid = (ya + yb) / 2
        for f, (y_from, y_to, h) in enumerate(((ya, mid, halves[0]), (mid, yb, halves[1]))):
            dsign = away if f == 0 else -away
            if ax == "x":
                rect = (run0, run1, h[0], h[1])
            else:
                rect = (h[0], h[1], run0, run1)
            d = ("+" if dsign > 0 else "-") + ax
            out_f.append([r2(rect[0] * S), r2(rect[1] * S), r2(rect[2] * S), r2(rect[3] * S), r2(y_from), r2(y_to - y_from), d, True, st["id"], 9])
        # the half landing at the far end and the storey landing at the floor end (the full width)
        for (yl, e) in ((mid, away), (yb, floor_end)):
            if ax == "x":
                lx0, lx1 = (x1 - land, x1) if e > 0 else (x0, x0 + land)
                out_l.append([r2(lx0 * S), r2(lx1 * S), r2(z0 * S), r2(z1 * S), r2(yl)])
            else:
                lz0, lz1 = (z1 - land, z1) if e > 0 else (z0, z0 + land)
                out_l.append([r2(x0 * S), r2(x1 * S), r2(lz0 * S), r2(lz1 * S), r2(yl)])
    return out_f, out_l, (x0, x1, z0, z1), ys


# the upper floor of these stairs is the gallery level (the dock and the control gallery), not the second floor
TOP_GALLERY = {"stair-130", "stair-63", "stair-140", "stair-141"}
stair_log = []
tower_boxes = []
for st in ref["stairs"]:
    lv = st["levels"]
    if st["id"] == "drop":
        continue
    if st["u_turn"]:
        fl, la, box, ys = u_tower(st, lv)
        flights += fl
        landings += la
        tower_boxes.append((st["id"], box, ys))
        stair_log.append((st["id"], "tower", lv, [r1(y) for y in ys]))
        continue
    if lv == ["basement", "ground"]:
        f = solve_straight(st, "basement", "ground")
    elif lv == ["basement", "ground", "second"]:
        f = solve_straight(st, "ground", "second")  # stair-140: the gallery flight (its cellar flight is a gap)
    else:
        f = solve_straight(st, "ground", "second")
    if st["id"] in TOP_GALLERY:
        f[5] = r2(LV["gallery"] - f[4])
    # a cellar stair steeper than 45 degrees is the top of a longer flight: it runs on downhill to 1.1 m per metre of rise
    run_m = (f[1] - f[0] if f[6][1] == "x" else f[3] - f[2]) / S
    need = f[5] / S * 1.1
    # so does a flight to the second floor steeper than 45 degrees (the east block's two: EFT's symbols give 50)
    if lv != ["basement", "ground"] and st["id"] not in TOP_GALLERY:
        need = max(need / 1.1, f[5] / S)
    if run_m < need:
        ext = (need - run_m) * S
        if f[6] == "+x":
            f[0] = r2(f[0] - ext)
        elif f[6] == "-x":
            f[1] = r2(f[1] + ext)
        elif f[6] == "+z":
            f[2] = r2(f[2] - ext)
        else:
            f[3] = r2(f[3] + ext)
    flights.append(f)
    stair_log.append((st["id"], f[6], lv, r1(f[4]), r1(f[5]), f[9]))

# where a straight flight arrives at the second floor: a landing a metre deep beyond its top step (the floor can
# stop short of it), kept clear of the second floor's walls (Studio and the offline walk: the east block's two
# stairs ran into the wall round its floor)
ARRIVE2 = np.zeros((NZ, NX), bool)
for f in list(flights):
    if f[7] or abs(f[4] + f[5] - LV["second"]) > 0.3:
        continue
    x0_, x1_, z0_, z1_ = f[0] / S, f[1] / S, f[2] / S, f[3] / S
    if f[6] == "+x":
        la = (x1_, x1_ + 1.0, z0_, z1_)
    elif f[6] == "-x":
        la = (x0_ - 1.0, x0_, z0_, z1_)
    elif f[6] == "+z":
        la = (x0_, x1_, z1_, z1_ + 1.0)
    else:
        la = (x0_, x1_, z0_ - 1.0, z0_)
    landings.append([r2(la[0] * S), r2(la[1] * S), r2(la[2] * S), r2(la[3] * S), r2(LV["second"])])
    ARRIVE2 |= rect_mask(min(x0_, la[0]), max(x1_, la[1]), min(z0_, la[2]), max(z1_, la[3]))

# the two service pits: a flight of steps at the south end of each (ours)
for sp in SPITS:
    x0, x1 = sp["cx"] - sp["d"] / 2, sp["cx"] + sp["d"] / 2
    z0, z1 = sp["cz"] - sp["w"] / 2, sp["cz"] + sp["w"] / 2
    flights.append([r2(x0 * S), r2(x1 * S), r2((z1 - 1.6) * S), r2(z1 * S), r2(-SERVICE_PIT), r2(SERVICE_PIT), "+z", False, "pit", 4])


def flight_mask(f):
    return rect_mask(f[0] / S, f[1] / S, f[2] / S, f[3] / S)


def open_over(mask_level, ytop, th=SLAB):
    """Remove from a level's mask every flight footprint whose climb passes this level's top or ends less than HEAD
    under its underside, the stair landings at this height (the landing is the floor there) and those less than HEAD
    under it (a switchback's half landings: Studio 2026-11-09 found no way from the office's second floor to the
    third, the floors over the half landings left 4.5 studs of head room)."""
    m = mask_level.copy()
    for f in flights:
        yb, rise = f[4], f[5]
        if yb + 0.25 < ytop <= yb + rise + 0.25 or (yb + rise + 0.25 < ytop and yb + rise > ytop - th - HEAD):
            m &= ~flight_mask(f)
    for l in landings:
        if abs(l[4] - ytop) < 0.3 or (l[4] < ytop - 0.3 and l[4] > ytop - th - HEAD):
            m &= ~rect_mask(l[0] / S, l[1] / S, l[2] / S, l[3] / S)
    return m


# ground slabs: the hall at 0, the raised west part at 3.06 (solid down to the basement ceiling), the dock at 8.22
g_hall = G_out & ~west_m & ~pit_m & ~dock_m
for sp in SPITS:
    g_hall &= ~box_mask(sp)
for d in ref["icons"]["drop"]:
    if d["from"] == "ground":
        g_hall &= ~rect_mask(d["x"] - 0.8, d["x"] + 0.8, d["z"] - 0.8, d["z"] + 0.8)
g_hall = open_over(close(g_hall) & ~west_m & ~pit_m & ~dock_m, 0.0)
for sp in SPITS:
    g_hall &= ~box_mask(sp)
add_slabs(g_hall, 0.0, SLAB, "hall")
g_west = open_over(close(west_m) & ~dock_m, LV["west"])
add_slabs(g_west, LV["west"], LV["west"] + SLAB, "west")
add_slabs(open_over(dock_m, LV["gallery"]), LV["gallery"], LV["gallery"], "dock")
for sp in SPITS:
    add_slabs(box_mask(sp), -SERVICE_PIT, SLAB, "pitfloor")
# basement floors (the sump lower)
b_main = close(B_floor) & ~sump_m
add_slabs(b_main, LV["basement"], SLAB, "tunnel")
add_slabs(sump_m, LV["sump"], SLAB, "sump")
# second floor
add_slabs(open_over(s2_office | s2_pump | s2_east, LV["second"]), LV["second"], SLAB, "floor2")
add_slabs(open_over(s2_deck, LV["second"]), LV["second"], DECK, "deck")
add_slabs(open_over(s2_dock, LV["gallery"]), LV["gallery"], SLAB, "dock")
add_slabs(open_over(s2_bridge, LV["gallery"]), LV["gallery"], SLAB, "bridge")
s2_drop = [d for d in ref["icons"]["drop"] if d["from"] == "second"][0]
# third floor: the office floor is a slab, the catwalks diamond-plate decks
t_floor = open_over(T_floor | OFFICE3, LV["third"])
add_slabs(t_floor & OFFICE3, LV["third"], SLAB, "floor3")
add_slabs(close(t_floor & ~OFFICE3, 0.2) & T_out, LV["third"], DECK, "catwalk")

# the ground round the works (outside the outline and the courtyard), at the hall's level: also the roof of the
# tunnels that run beyond the building (the cable cellar's end, the sewer pipe)
outside = rect_mask(X0 + 0.2, X0 + NX * RES - 0.2, Z0 + 0.2, Z0 + NZ * RES - 0.2) & ~dilate(G_out | court_m, WALL_T)
add_slabs(outside, 0.0, SLAB, "ground", 50)

# roofs over everything but the two yards
roof_mask = (G_out | dock_m | court_m) & ~open_m
for hgt in (ROOF_LOW, ROOF_HALL):
    m = roof_mask & (roof_h == hgt)
    add_slabs(m, hgt + 1.0, 1.0, "roof", 50)

# ── walls ───────────────────────────────────────────────────────────────────────────────────────────────────
walls = []  # x0, x1, z0, z1, y0, y1, kind


def add_walls(mask, y0, y1_fn, kind, min_cells=6):
    for rc in rects_of(mask, min_cells):
        y1 = y1_fn(rc) if callable(y1_fn) else y1_fn
        walls.append([r2(rc[0] * S), r2(rc[1] * S), r2(rc[2] * S), r2(rc[3] * S), r2(y0), r2(y1), kind])


# ground: a band round every floor (outline, gaps between floors, room walls) and every hole filled (walls, the
# solid block in the east yard, the dock's east and south wall). The pit and the service pits are not walls.
UPPER.extend([(s2_dock | s2_bridge, LV["gallery"], SLAB), (s2_office | s2_pump | s2_east | s2_block, LV["second"], SLAB),
              (s2_deck, LV["second"], DECK), (OFFICE3, LV["third"], SLAB), (T_floor, LV["third"], DECK)])
UPPER.sort(key=lambda u: u[1])
g_all = G_floor | court_m | pit_m
g_band = dilate(g_all, WALL_T) & ~g_all
for k, m in G_holes.items():
    g_band |= m
add_walls(g_band, -SLAB, wall_height, "wall")
# the dock: a solid block up to its deck
# basement: the band round the tunnels, from the tunnel floor's underside to the ground slab
b_band = dilate(B_floor | B_isl, WALL_T) & ~(B_floor | B_isl)
add_walls(b_band, LV["sump"] - SLAB, -SLAB, "tunnelwall")
# second floor: the walls of the office floor, the pump house room and the east block upper floor
s2_rooms = s2_office | s2_pump | s2_east
s2_band = dilate(s2_rooms, 0.3) & ~s2_rooms & ~s2_dock & ~dilate(s2_bridge, 0.1)
s2_band &= ~open_m & ~dilate(ARRIVE2, 0.1)
add_walls(s2_band, LV["second"], LV["third"], "wall2")
add_walls(s2_block, LV["second"], LV["third"], "wall2")
# third floor: the office block (hand-read from the re3mr top floor: west wall x -40, room fronts x -35, partitions
# z -21.6 and -16.6, the east wall x -32.4, the stairwells; windows and doors cut by the builder)
OFF3_WALLS = [  # x0, x1, z0, z1 metres
    (-40.25, -39.95, -28.1, -5.5), (-32.55, -32.25, -32.3, -1.5), (-42.0, -32.25, -32.6, -32.3), (-42.0, -32.25, -1.5, -1.2),
    (-42.0, -41.7, -32.3, -1.5), (-40.0, -35.0, -21.75, -21.45), (-40.0, -35.0, -16.75, -16.45),
    (-35.15, -34.85, -28.1, -5.5), (-40.0, -35.15, -28.25, -27.95), (-40.0, -35.15, -5.65, -5.35),
]
for x0, x1, z0, z1 in OFF3_WALLS:
    walls.append([r2(x0 * S), r2(x1 * S), r2(z0 * S), r2(z1 * S), r2(LV["third"]), r2(ROOF_HALL), "wall3"])
for r in T_void_thin:
    xs = [p[0] for p in r["pts"]]
    zs = [p[1] for p in r["pts"]]
    big = max(max(xs) - min(xs), max(zs) - min(zs))
    top = ROOF_HALL if big > 5 and min(xs) < -30 else LV["third"] + 1.1 * S
    walls.append([r2(min(xs) * S), r2(max(xs) * S), r2(min(zs) * S), r2(max(zs) * S), r2(LV["third"]), r2(top), "beam" if top < ROOF_HALL else "wall3"])

# the reference's wall lines (centre lines, 0.25 m): full = to the roof over them, storey = to the floor above,
# part = 3.5 m partitions, low = 1.2 m (rails, conveyor sides), tent = the aid post's canvas, glass = the north gallery's
# glazing (ours: the reference gives no heights)
LINE_KIND = {
    "ground": {**{i: "full" for i in (10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 40, 41, 42, 49, 50)},
               **{i: "part" for i in (0, 7, 8, 9, 26, 27, 48)}, **{i: "low" for i in (1, 2, 3, 4, 5, 6, 28, 29)},
               **{i: "tent" for i in (38, 39)}, **{i: "glass" for i in (43, 44, 45, 46, 47)}},
    "second": {0: "storey", 1: "storey", 5: "storey", 6: "storey", 2: "stall", 3: "stall", 4: "stall"},
    "third": {2: "low", 3: "low", 4: "storey"},
}
lines = []  # x0, z0, x1, z1, thickness, y0, y1, kind (studs)
DOOR_AT = [(50.75, 24.83), (30.8, -60.95), (-42.05, 26.04)]  # the leaves' doorways: cut to MIN_PASS by the openings


def widen_line_gaps(segs, level):
    """The doorways between two wall lines that face each other end to end (EFT's 0.9-1.1 m doors): each end steps
    back so the gap is MIN_PASS (a stub never loses more than all but 5 cm)."""
    n = 0
    for s1 in range(len(segs)):
        for e1 in (0, 1):
            for s2 in range(s1 + 1, len(segs)):
                for e2 in (0, 1):
                    p1, q1 = segs[s1][e1], segs[s1][1 - e1]
                    p2, q2 = segs[s2][e2], segs[s2][1 - e2]
                    gx, gz = p2[0] - p1[0], p2[1] - p1[1]
                    d = math.hypot(gx, gz)
                    l1, l2 = math.hypot(p1[0] - q1[0], p1[1] - q1[1]), math.hypot(p2[0] - q2[0], p2[1] - q2[1])
                    if not (0.05 < d < MIN_PASS) or l1 < 0.06 or l2 < 0.06:
                        continue
                    u1 = ((p1[0] - q1[0]) / l1, (p1[1] - q1[1]) / l1)
                    u2 = ((p2[0] - q2[0]) / l2, (p2[1] - q2[1]) / l2)
                    if (u1[0] * gx + u1[1] * gz) / d < 0.95 or -(u2[0] * gx + u2[1] * gz) / d < 0.95:
                        continue
                    mx, mz = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
                    if any(math.hypot(mx - dx, mz - dz) < 1.5 for dx, dz in DOOR_AT):
                        continue
                    cut = (MIN_PASS - d) / 2
                    for p, u, ln_ in ((p1, u1, l1), (p2, u2, l2)):
                        c = min(cut, ln_ - 0.05)
                        p[0] -= u[0] * c
                        p[1] -= u[1] * c
                    PASSES.append((mx, mz, level))
                    n += 1
    return n


for lvname, rows in ref["walls"].items():
    segs = []
    for i, pl in enumerate(rows):
        k = LINE_KIND[lvname].get(i)
        if k is None:
            continue
        for a, b in zip(pl[:-1], pl[1:]):
            segs.append([[a[0], a[1]], [b[0], b[1]], k])
    nw_ = widen_line_gaps(segs, lvname)
    print(f"  {lvname}: {nw_} doorways between wall lines widened to {MIN_PASS} m")
    for a, b, k in segs:
        if math.hypot(b[0] - a[0], b[1] - a[1]) < 0.1:
            continue
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if lvname == "ground":
            y0 = LV["west"] if inmask(west_m, mx, mz) else 0.0
            top = {"full": wall_height((min(a[0], b[0]), max(a[0], b[0]), min(a[1], b[1]), max(a[1], b[1]))), "part": y0 + 3.5 * S,
                   "low": y0 + 1.2 * S, "tent": y0 + 2.6 * S, "glass": wall_height((min(a[0], b[0]), max(a[0], b[0]), min(a[1], b[1]), max(a[1], b[1])))}[k]
        elif lvname == "second":
            y0 = LV["second"]
            top = LV["third"] if k == "storey" else y0 + 2.2 * S
        else:
            y0 = LV["third"]
            top = ROOF_HALL if k == "storey" else y0 + 1.1 * S
        lines.append([r2(a[0] * S), r2(a[1] * S), r2(b[0] * S), r2(b[1] * S), 0.78, r2(y0), r2(top), k])

# lintels over the two tunnel doors (the doorways run to the tunnel's ceiling; the leaves are 2.1 m)
for lx0, lx1, lz0, lz1 in ((30.8 - MIN_PASS / 2, 30.8 + MIN_PASS / 2, -61.05, -60.85), (-42.39, -41.71, 26.04 - MIN_PASS / 2, 26.04 + MIN_PASS / 2)):
    walls.append([r2(lx0 * S), r2(lx1 * S), r2(lz0 * S), r2(lz1 * S), r2(LV["basement"] + DOOR_H * S), r2(-SLAB), "tunnelwall"])

# ── openings: doors and windows cut out of the walls (metres; y from the floor of that level) ───────────────
# re3mr reads (grade B): the third-floor room doors, the office windows, the jump windows from the courtyard, the
# high bridge door, the locked doors' gaps; widths and sills ours (door MIN_PASS x 2.1 m, window sill 0.9 m to 2.1 m).
# EFT's courtyard windows are vaulted through; with no vaulting here the three on the courtyard's walks are broken out
# to the floor (the courtyard and its stair otherwise stand closed off: Studio 2026-11-09)
OPEN = []  # x0, x1, z0, z1, y0, y1 (studs)


def opening(x0, x1, z0, z1, ylv, a, b):
    OPEN.append((x0 * S, x1 * S, z0 * S, z1 * S, ylv + a * S, ylv + b * S))


T3 = LV["third"]
for zc in (-24.3, -19.6, -14.0, -8.0):  # manager's office, records room, shift office (two doors)
    opening(-35.3, -34.7, zc - MIN_PASS / 2, zc + MIN_PASS / 2, T3, 0, DOOR_H)
for zc in (-24.0, -19.0, -14.8, -11.0, -7.6):  # west windows; -11.0 is the shift office window exit
    opening(-40.4, -39.8, zc - 0.6, zc + 0.6, T3, 0.9, 2.1)
for zc in (-22.9, -16.7, -10.7, -3.7):  # east windows over the hall
    opening(-32.7, -32.1, zc - 0.6, zc + 0.6, T3, 0.9, 2.1)
opening(-32.7, -32.1, -31.8, -29.4, T3, 0, DOOR_H)  # the high bridge door
# second floor: west windows, the jump window over the courtyard stair
S2Y = LV["second"]
for zc in (-27.0, -24.0, -13.0, -10.0):
    opening(-47.9, -47.2, zc - 0.6, zc + 0.6, S2Y, 0.9, 2.1)
opening(-47.9, -47.2, -6.1, -4.5, S2Y, 0, DOOR_H)  # broken out to the floor
# ground floor: the two jump windows from the courtyard into the office rooms
WY = LV["west"]
opening(-45.4, -44.3, -22.8 - MIN_PASS / 2, -22.8 + MIN_PASS / 2, WY, 0, DOOR_H)  # broken out to the floor
opening(-43.3, -42.2, -8.3 - MIN_PASS / 2, -8.3 + MIN_PASS / 2, WY, 0, DOOR_H)
# the aid post gate passage door (re3mr lock at 51.1, 25.0; the SVG gap is 0.94 m, ours MIN_PASS)
opening(50.4, 51.1, 24.83 - MIN_PASS / 2, 24.83 + MIN_PASS / 2, 0.0, 0, DOOR_H)
# the cable cellar door in the new cross wall, the sealed store's door (east wall of the room in the south-west tunnels)
# (the cable cellar's door stands in the SVG's doorway at x 30.8, z -60.95: the re3mr lock is 0.7 m off it)
# (the sealed store's doorway is in the reference already: x -42.39..-41.71, z 25.49..26.58; the floor takes it to
# MIN_PASS, z 25.34..26.74)


def cut_box(w, o):
    """Split an axis-aligned wall box around an opening box; returns the pieces (or [w] when they do not meet)."""
    x0, x1, z0, z1, y0, y1, kind = w
    ox0, ox1, oz0, oz1, oy0, oy1 = o
    if ox1 <= x0 or ox0 >= x1 or oz1 <= z0 or oz0 >= z1 or oy1 <= y0 or oy0 >= y1:
        return [w]
    out = []
    # along the wall's long axis
    if x1 - x0 >= z1 - z0:
        a0, a1 = max(x0, ox0), min(x1, ox1)
        if a0 > x0 + 0.01:
            out.append([x0, r2(a0), z0, z1, y0, y1, kind])
        if a1 < x1 - 0.01:
            out.append([r2(a1), x1, z0, z1, y0, y1, kind])
        if oy0 > y0 + 0.01:
            out.append([r2(a0), r2(a1), z0, z1, y0, r2(oy0), kind])
        if oy1 < y1 - 0.01:
            out.append([r2(a0), r2(a1), z0, z1, r2(oy1), y1, kind])
    else:
        a0, a1 = max(z0, oz0), min(z1, oz1)
        if a0 > z0 + 0.01:
            out.append([x0, x1, z0, r2(a0), y0, y1, kind])
        if a1 < z1 - 0.01:
            out.append([x0, x1, r2(a1), z1, y0, y1, kind])
        if oy0 > y0 + 0.01:
            out.append([x0, x1, r2(a0), r2(a1), y0, r2(oy0), kind])
        if oy1 < y1 - 0.01:
            out.append([x0, x1, r2(a0), r2(a1), r2(oy1), y1, kind])
    return out


for o in OPEN:
    nw = []
    for w in walls:
        nw += cut_box(w, o)
    walls = nw
# a doorway broken out of the second floor's outer wall gets a sill (the floor slab stops at the wall's inner face)
for o in OPEN:
    if abs(o[4] - LV["second"]) < 0.05:
        slabs.append([r2(o[0]), r2(o[1]), r2(o[2]), r2(o[3]), r2(o[4]), r2(SLAB), "floor2"])
# line walls along z or x crossing an opening: cut them the same way (they are axis-aligned there)
nl = []
for ln in lines:
    x0, z0, x1, z1, t, y0, y1, kind = ln
    if abs(x0 - x1) < 0.01 or abs(z0 - z1) < 0.01:
        box = [min(x0, x1) - t / 2, max(x0, x1) + t / 2, min(z0, z1) - t / 2, max(z0, z1) + t / 2, y0, y1, kind]
        if abs(x0 - x1) < 0.01:
            box[2], box[3] = min(z0, z1), max(z0, z1)
        else:
            box[0], box[1] = min(x0, x1), max(x0, x1)
        pieces = [box]
        for o in OPEN:
            pp = []
            for b in pieces:
                pp += cut_box(b, o)
            pieces = pp
        if len(pieces) == 1 and pieces[0] is box:
            nl.append(ln)
        else:
            for b in pieces:
                walls.append(b[:6] + [kind if kind in ("glass", "tent") else "wall"])
    else:
        nl.append(ln)
lines = nl

# the courtyard stair's top landing against the office's west wall (stair-135 arrives 3 m short of it)
landings.append([r2(-50.7 * S), r2(-47.3 * S), r2(-6.2 * S), r2(-4.0 * S), r2(LV["second"])])

# doors (World makes the leaves): id, label, x, y (floor), z, width, height, axis the leaf spans, key
DOORS = [
    ("SM_GATEDOOR", "Aid post gate passage", 50.75, 0.0, 24.83, MIN_PASS, DOOR_H, "z", "KEY_SMELT_OFFICE"),
    ("SM_CELLAR", "Cable cellar door", 30.8, LV["basement"], -60.95, MIN_PASS, DOOR_H, "x", "KEY_SMELT_OFFICE"),
    ("SM_MGR", "Manager's office", -35.0, T3, -24.3, MIN_PASS, DOOR_H, "z", "KEY_SMELT_OFFICE"),
    ("SM_RECORDS", "Records room", -35.0, T3, -19.6, MIN_PASS, DOOR_H, "z", None),
    ("SM_SHIFT", "Shift office", -35.0, T3, -14.0, MIN_PASS, DOOR_H, "z", None),
    ("SM_STORE", "Sealed store", -42.05, LV["basement"], 26.04, MIN_PASS, DOOR_H, "z", "CARD"),
]
doors = [[d[0], d[1], r2(d[2] * S), r2(d[3]), r2(d[4] * S), r2(d[5] * S), r2(d[6] * S), d[7], d[8] or ""] for d in DOORS]

# ── railings ────────────────────────────────────────────────────────────────────────────────────────────────
rails = []  # x0, z0, x1, z1, y


def mask_edges(mask, ytop, keep=None, min_len=0.6):
    """Boundary runs of a mask (axis-aligned), as railing segments at height ytop; keep(x, z) filters each run."""
    out = []
    m = mask
    # horizontal edges (between row i-1 and i)
    for i in range(1, NZ):
        diff = m[i] != m[i - 1]
        if not diff.any():
            continue
        d = np.diff(np.concatenate(([0], diff.astype(np.int8), [0])))
        for a, b in zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]):
            if (b - a) * RES >= min_len:
                out.append((X0 + a * RES, Z0 + i * RES, X0 + b * RES, Z0 + i * RES))
    for j in range(1, NX):
        diff = m[:, j] != m[:, j - 1]
        if not diff.any():
            continue
        d = np.diff(np.concatenate(([0], diff.astype(np.int8), [0])))
        for a, b in zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]):
            if (b - a) * RES >= min_len:
                out.append((X0 + j * RES, Z0 + a * RES, X0 + j * RES, Z0 + b * RES))
    for x0, z0, x1, z1 in out:
        if keep is None or keep((x0 + x1) / 2, (z0 + z1) / 2):
            rails.append([r2(x0 * S), r2(z0 * S), r2(x1 * S), r2(z1 * S), r2(ytop)])


# stair arrivals stay open: the landings and the flights' top ends
arrive = np.zeros((NZ, NX), bool)
for f in flights:
    arrive |= dilate(flight_mask(f), 0.3)
for l in landings:
    arrive |= dilate(rect_mask(l[0] / S, l[1] / S, l[2] / S, l[3] / S), 0.3)
cat = (T_floor & ~OFFICE3)
cat_solid = cat | OFFICE3 | dilate(OFFICE3, 0.3)
mask_edges(cat | OFFICE3, LV["third"], keep=lambda x, z: not inmask(arrive, x, z) and not inmask(dilate(OFFICE3, 0.2), x, z))
mask_edges(s2_deck, LV["second"], keep=lambda x, z: not inmask(arrive, x, z))
mask_edges(s2_bridge, LV["gallery"], keep=lambda x, z: not inmask(arrive, x, z))
mask_edges(s2_dock, LV["gallery"], keep=lambda x, z: not inmask(arrive, x, z) and not inmask(dilate(s2_office, 0.3), x, z))
mask_edges(pit_m & G_out, 0.0, keep=lambda x, z: not inmask(arrive, x, z))


# the switchback towers (walk test 2026-11-09: holding W up a hall tower's first flight carried the player across its
# half landing and off the far edge): each flight's outer side gets a steel side panel from its foot to a rail's height
# over its top step, each landing a rail on its open edges (a storey landing's end stays open where a floor lies
# beyond it); a side against a wall gets nothing
def walled(x, z, y):
    """a wall stands at (x, z) metres between 1 and 3 studs over height y"""
    xs, zs = x * S, z * S
    return any(w[0] <= xs <= w[1] and w[2] <= zs <= w[3] and w[4] < y + 3 and w[5] > y + 1 for w in walls)


def level_name(y):
    return min((("basement", LV["basement"]), ("ground", 0.0), ("ground", LV["west"]), ("second", LV["gallery"]), ("second", LV["second"]),
                ("third", LV["third"])), key=lambda t: abs(t[1] - y))[0]


n_panels, n_lrails = 0, 0
for tid, (bx0, bx1, bz0, bz1), ys in tower_boxes:
    tfl = [f for f in flights if f[8] == tid]
    if not tfl:
        continue
    ax = tfl[0][6][1]
    for f in tfl:
        fx0, fx1, fz0, fz1 = f[0] / S, f[1] / S, f[2] / S, f[3] / S
        y0, y1 = f[4] - 0.2, f[4] + f[5] + 3.5
        if ax == "x":
            lo = abs(fz0 - bz0) < abs(fz1 - bz1)
            zc, oz = (fz0, -1) if lo else (fz1, 1)
            if not walled((fx0 + fx1) / 2, zc + oz * 0.3, f[4] + f[5] / 2):
                za, zb = (zc - 0.25, zc) if lo else (zc, zc + 0.25)
                walls.append([r2(fx0 * S), r2(fx1 * S), r2(za * S), r2(zb * S), r2(y0), r2(y1), "beam"])
                n_panels += 1
        else:
            lo = abs(fx0 - bx0) < abs(fx1 - bx1)
            xc, ox = (fx0, -1) if lo else (fx1, 1)
            if not walled(xc + ox * 0.3, (fz0 + fz1) / 2, f[4] + f[5] / 2):
                xa, xb = (xc - 0.25, xc) if lo else (xc, xc + 0.25)
                walls.append([r2(xa * S), r2(xb * S), r2(fz0 * S), r2(fz1 * S), r2(y0), r2(y1), "beam"])
                n_panels += 1
    for l in landings:
        lx0, lx1, lz0, lz1, ly_ = l[0] / S, l[1] / S, l[2] / S, l[3] / S, l[4]
        if lx0 < bx0 - 0.05 or lx1 > bx1 + 0.05 or lz0 < bz0 - 0.05 or lz1 > bz1 + 0.05:
            continue
        storey = any(abs(ly_ - yy) < 0.1 for yy in ys)
        if ax == "x":
            end = bx0 if abs(lx0 - bx0) < 0.05 else bx1
            sgn = -1 if end == bx0 else 1
            edges = [((lx0, bz0), (lx1, bz0), (0, -1)), ((lx0, bz1), (lx1, bz1), (0, 1))]
            beyond = level_at(level_name(ly_), end + sgn * 0.8, (bz0 + bz1) / 2)
            if not storey or beyond is None or abs(beyond - ly_) > 1.0:
                edges.append(((end, bz0), (end, bz1), (sgn, 0)))
        else:
            end = bz0 if abs(lz0 - bz0) < 0.05 else bz1
            sgn = -1 if end == bz0 else 1
            edges = [((bx0, lz0), (bx0, lz1), (-1, 0)), ((bx1, lz0), (bx1, lz1), (1, 0))]
            beyond = level_at(level_name(ly_), (bx0 + bx1) / 2, end + sgn * 0.8)
            if not storey or beyond is None or abs(beyond - ly_) > 1.0:
                edges.append(((bx0, end), (bx1, end), (0, sgn)))
        for (xa, za), (xb, zb), (ox, oz) in edges:
            if walled((xa + xb) / 2 + ox * 0.3, (za + zb) / 2 + oz * 0.3, ly_):
                continue
            rails.append([r2(xa * S), r2(za * S), r2(xb * S), r2(zb * S), r2(ly_)])
            n_lrails += 1
print(f"  switchback towers: {n_panels} side panels, {n_lrails} landing rails")

# ── steps where the floor changes level (the raised west part, the sump) ────────────────────────────────────
steps = []  # x0, x1, z0, z1, yLow, rise, dir


def level_steps(high_m, low_m, yhigh, ylow, kind):
    """Where a high floor meets a low one with no wall between, a short flight on the low side."""
    edge_h = high_m & dilate(low_m, 0.15)
    lab, n = ndimage.label(edge_h)
    for k in range(1, n + 1):
        ii, jj = np.nonzero(lab == k)
        x0, x1 = X0 + jj.min() * RES, X0 + (jj.max() + 1) * RES
        z0, z1 = Z0 + ii.min() * RES, Z0 + (ii.max() + 1) * RES
        if max(x1 - x0, z1 - z0) < 0.8:
            continue
        run = (yhigh - ylow) / S * 1.6  # about 32 degrees
        # which side is low: probe the four sides of the strip
        cxm, czm = (x0 + x1) / 2, (z0 + z1) / 2
        if x1 - x0 < z1 - z0:  # a strip along z: steps along x
            if inmask(low_m, x1 + 0.3, czm):
                steps.append([r2(x1 * S), r2((x1 + run) * S), r2(z0 * S), r2(z1 * S), r2(ylow), r2(yhigh - ylow), "-x", kind])
            elif inmask(low_m, x0 - 0.3, czm):
                steps.append([r2((x0 - run) * S), r2(x0 * S), r2(z0 * S), r2(z1 * S), r2(ylow), r2(yhigh - ylow), "+x", kind])
        else:
            if inmask(low_m, cxm, z1 + 0.3):
                steps.append([r2(x0 * S), r2(x1 * S), r2(z1 * S), r2((z1 + run) * S), r2(ylow), r2(yhigh - ylow), "-z", kind])
            elif inmask(low_m, cxm, z0 - 0.3):
                steps.append([r2(x0 * S), r2(x1 * S), r2((z0 - run) * S), r2(z0 * S), r2(ylow), r2(yhigh - ylow), "+z", kind])


level_steps(west_m & G_floor, G_floor & ~west_m & ~pit_m & ~dock_m, LV["west"], 0.0, "west")
level_steps(B_floor & ~sump_m, sump_m, LV["basement"], LV["sump"], "sump")

# ── everything that stands on the floors ────────────────────────────────────────────────────────────────────
boxes = []  # cx, cz, w, d, rot, y0, h, kind  (studs)
for o in ref["obstacles"]["ground"]:
    y0 = LV["west"] if inmask(west_m, o["cx"], o["cz"]) else 0.0
    kind = o["kind"]
    h = {"boiler": ly(7.3), "tank skid": 3.2 * S, "pallet row": 1.4 * S, "forklift": 2.2 * S, "vehicle": 2.6 * S}.get(kind, 1.8 * S)
    boxes.append([r2(o["cx"] * S), r2(o["cz"] * S), r2(o["w"] * S), r2(o["d"] * S), o["rot"], r2(y0), r2(h), kind])
for o in ref["obstacles"]["second"]:
    boxes.append([r2(o["cx"] * S), r2(o["cz"] * S), r2(o["w"] * S), r2(o["d"] * S), o["rot"], r2(LV["second"]), r2(2.0 * S), o["kind"]])
mh = ref["machine_house"]["box"]
boxes.append([r2(mh["cx"] * S), r2(mh["cz"] * S), r2(mh["w"] * S), r2(mh["d"] * S), mh["rot"], 0.0, r2(ly(6.0)), "machine house"])
cyls = []  # cx, cz, r, y0, h, kind
for s in ref["silos"]:
    if s["in_pit"]:
        cyls.append([r2(s["cx"] * S), r2(s["cz"] * S), r2(s["r"] * S), r2(LV["basement"]), r2(9.4 * S), "crucible"])
    else:
        cyls.append([r2(s["cx"] * S), r2(s["cz"] * S), r2(s["r"] * S), 0.0, r2(6.3 * S), "vessel"])

# ── named points, gameplay positions (studs, local y on the floor) ──────────────────────────────────────────
LEVEL_OF = {"ground": "ground", "basement": "basement", "second": "second", "third": "third", "courtyard": "ground"}


def floor_y(level, x, z):
    y = level_at(LEVEL_OF.get(level, level), x, z)
    if y is None:
        y = {"basement": LV["basement"], "ground": 0.0, "courtyard": LV["west"], "second": LV["second"], "third": LV["third"]}[level]
    return y


labels = []
for lb in ref["labels"]:
    lo = lb["game_y_from"] if lb["game_y_from"] is not None else -1
    level = "basement" if lo < -5 else ("third" if lo >= 6 else ("second" if lo >= 3 else "ground"))
    labels.append([lb["ours"], r2(lb["x"] * S), r2(floor_y(level, lb["x"], lb["z"])), r2(lb["z"] * S), level])
extracts = []
for e in ref["extracts"]:
    extracts.append([e["id"], e["ours"], r2(e["x"] * S), r2(floor_y(e["level"], e["x"], e["z"])), r2(e["z"] * S), "+".join(e["sides"]), e["eft"]])
transits = []
for t in ref["transits"]:
    if t["ours"]:
        transits.append([t["ours"], r2(t["x"] * S), r2(floor_y(t["level"], t["x"], t["z"])), r2(t["z"] * S)])
spawns = []
SPAWN_PICK = []  # (cluster, the points to choose from), resolved below once the free floor is known
for c in ref["spawns"]["player_clusters"]:
    if not (-66 < c["x"] < 66 and -71.3 < c["z"] < 71.3) or c["n"] < 3:
        continue  # SPT's cluster east of the frame (0.12 map) and a lone point
    SPAWN_PICK.append(c)


def snap_y(x, z, gy):
    """The floor height nearest an SPT point's own height (a few SPT points stand on crates or a vehicle)."""
    y, best = ly(gy), None
    for lvn in ("basement", "ground", "second", "third"):
        fy = level_at(lvn, x, z)
        if fy is not None and (best is None or abs(fy - y) < abs(best - y)):
            best = fy
    return best if best is not None else y


# where a body fits: off the walls, wall lines, machines and stairs (the crucibles and vessels stand on legs over
# the pit and the hall: room under them)
blocked = np.zeros((NZ, NX), bool)
for ln in lines:
    a, b = (ln[0] / S, ln[1] / S), (ln[2] / S, ln[3] / S)
    n = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 0.1))
    for k in range(n + 1):
        x, z = a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n
        i, j = int((z - Z0) / RES), int((x - X0) / RES)
        if 0 <= i < NZ and 0 <= j < NX:
            blocked[i, j] = True
for o in ref["obstacles"]["ground"]:
    blocked |= box_mask(o)
blocked |= box_mask(ref["machine_house"]["box"])
for f in flights:
    blocked |= flight_mask(f)
for c_ in ref["silos"]:  # the legs under the crucibles and vessels (Shell: a cross of four at 0.6 r)
    for qx, qz in ((0.6, 0), (-0.6, 0), (0, 0.6), (0, -0.6)):
        lx, lz = c_["cx"] + qx * c_["r"], c_["cz"] + qz * c_["r"]
        blocked |= rect_mask(lx - 0.2, lx + 0.2, lz - 0.2, lz + 0.2)
blocked = dilate(blocked, 0.6)


def free_mask(lvn):
    if lvn == "basement":
        return B_floor & ~blocked
    if lvn == "ground":
        return (G_floor | court_m) & ~pit_m & ~blocked
    return None


def nudge(x, z, lvn, reach=4.0):
    """The free floor point nearest (x, z) on a level, within reach metres (the point itself when it is free)."""
    fm = free_mask(lvn)
    if fm is None:
        return x, z
    fm = fm & ~dilate(~fm, 0.6)
    if inmask(fm, x, z):
        return x, z
    r = int(reach / RES)
    i0, j0 = int((z - Z0) / RES), int((x - X0) / RES)
    win = fm[max(0, i0 - r):i0 + r, max(0, j0 - r):j0 + r]
    ii, jj = np.nonzero(win)
    if len(ii) == 0:
        print(f"  warning: no free floor near ({x:.1f}, {z:.1f}) on {lvn}")
        return x, z
    zz = Z0 + (max(0, i0 - r) + ii + 0.5) * RES
    xx = X0 + (max(0, j0 - r) + jj + 0.5) * RES
    k = int(np.argmin((xx - x) ** 2 + (zz - z) ** 2))
    return float(xx[k]), float(zz[k])


def clear_of(lvn, x, z):
    """How far (metres) a point stands from the nearest wall, wall line, machine or stair on its level."""
    if lvn == "basement":
        fm = B_floor & ~blocked
    elif lvn == "ground":
        fm = (G_floor | court_m) & ~pit_m & ~blocked
    elif lvn == "second":
        fm = (s2_office | s2_pump | s2_east | s2_dock | s2_bridge) & ~blocked
    else:
        return 9.0
    i, j = int((z - Z0) / RES), int((x - X0) / RES)
    win = fm[max(0, i - 12):i + 13, max(0, j - 12):j + 13]
    if not fm[i, j]:
        return 0.0
    ii, jj = np.nonzero(~win)
    if len(ii) == 0:
        return 1.3
    di = (ii + max(0, i - 12) - i) * RES
    dj = (jj + max(0, j - 12) - j) * RES
    return float(np.sqrt(di * di + dj * dj).min())


for c in SPAWN_PICK:
    lvn = "basement" if c["y"] < -1 else ("second" if c["y"] > 2.5 else "ground")
    if c["y"] > 6:
        lvn = "third"
    scored = sorted(c["points"], key=lambda p: (-min(clear_of(lvn, p[0], p[1]), 1.0), (p[0] - c["x"]) ** 2 + (p[1] - c["z"]) ** 2))
    best = scored[0]
    x, z = best[0], best[1]
    if clear_of(lvn, x, z) < 0.5 and lvn in ("ground", "basement"):
        x, z = nudge(x, z, lvn, 3.0)
        fm = free_mask(lvn) & ~dilate(~free_mask(lvn), 0.5)
        if not inmask(fm, x, z):
            r = int(3.0 / RES)
            i0, j0 = int((z - Z0) / RES), int((x - X0) / RES)
            win = fm[max(0, i0 - r):i0 + r, max(0, j0 - r):j0 + r]
            ii, jj = np.nonzero(win)
            if len(ii):
                zz = Z0 + (max(0, i0 - r) + ii + 0.5) * RES
                xx = X0 + (max(0, j0 - r) + jj + 0.5) * RES
                k = int(np.argmin((xx - x) ** 2 + (zz - z) ** 2))
                x, z = float(xx[k]), float(zz[k])
    spawns.append([r2(x * S), r2(snap_y(x, z, best[2])), r2(z * S), best[3]])


def spt_point(p):
    lvn = "basement" if p[2] < -1 else "ground"
    x, z = nudge(p[0], p[1], lvn)
    return [r2(x * S), r2(snap_y(x, z, p[2])), r2(z * S)]


scav = [spt_point(p) for p in ref["spawns"]["scav_bot"]]
boss = [spt_point(p) for p in ref["spawns"]["boss_capable"]]


def clear_spot(x, z, lvn, need=2.2, reach=8.0):
    """The point nearest (x, z) at least `need` metres from every wall, machine and stair on a level."""
    dist = ndimage.distance_transform_edt(free_mask(lvn)) * RES
    r = int(reach / RES)
    i0, j0 = int((z - Z0) / RES), int((x - X0) / RES)
    ii, jj = np.nonzero(dist[max(0, i0 - r):i0 + r, max(0, j0 - r):j0 + r] >= need)
    if len(ii) == 0:
        print(f"  warning: no clear floor near ({x:.1f}, {z:.1f}) on {lvn}")
        return x, z
    zz = Z0 + (max(0, i0 - r) + ii + 0.5) * RES
    xx = X0 + (max(0, j0 - r) + jj + 0.5) * RES
    k = int(np.argmin((xx - x) ** 2 + (zz - z) ** 2))
    return float(xx[k]), float(zz[k])


# the transit's zone stands on clear floor (the reference's point is under the van parked at the east yard's gate)
for t_ in transits:
    tx, tz = clear_spot(t_[1] / S, t_[3] / S, "ground")
    t_[1], t_[2], t_[3] = r2(tx * S), r2(floor_y("ground", tx, tz)), r2(tz * S)

# ── AI: guard routes (ours, along open floor) and THE CULT's three night zones (SPT: cultists come out at any scav
# point on Night Factory; ours: three dark spots, the warriors a few metres round the priest) ───────────────
ROUTES = {
    "HL": ("ground", [(-21.0, 21.0), (8.0, 21.0), (34.5, 17.5), (24.0, -12.0), (-3.0, -18.0), (-24.0, -6.0)]),
    "FN": ("ground", [(-30.0, -45.0), (-16.0, -38.0), (12.0, -45.0), (22.0, -57.0), (0.0, -59.0), (-24.0, -57.0)]),
    "TN": ("basement", [(-48.0, 3.9), (-14.7, 10.9), (16.3, -14.1), (9.9, -34.9), (-5.1, -52.6)]),
    "WW": ("ground", [(-37.5, -12.0), (-45.0, 10.0), (-52.0, 33.0), (-44.0, 44.0), (-55.0, 60.0)]),
}
routes = {}
obst_m = np.zeros((NZ, NX), bool)
for o in ref["obstacles"]["ground"]:
    obst_m |= dilate(box_mask(o), 0.5)
for rid, (lvn, pts) in ROUTES.items():
    row = []
    for x, z in pts:
        x, z = nudge(x, z, lvn)
        y = level_at(lvn, x, z)
        if y is None or (lvn == "ground" and inmask(obst_m, x, z)):
            print(f"  warning: route {rid} point ({x}, {z}) is off the {lvn} floor or on a machine")
            y = 0.0 if y is None else y
        row.append([r2(x * S), r2(y), r2(z * S)])
    routes[rid] = row
CULT = [("SOUTH TUNNEL", "basement", -28.5, 37.8), ("EAST TUNNEL", "basement", 32.1, -18.1), ("CONTAINER ROOM", "ground", -61.4, 25.7)]
cult = []
for name, lvn, x, z in CULT:
    x, z = nudge(x, z, lvn)
    fl = (B_floor if lvn == "basement" else (G_floor & west_m)) & ~blocked
    near = rect_mask(x - 4.5, x + 4.5, z - 4.5, z + 4.5) & ~rect_mask(x - 1.5, x + 1.5, z - 1.5, z + 1.5)
    crew = []
    dist = ndimage.distance_transform_edt(fl) * RES
    ii, jj = np.nonzero(fl & near & (dist >= 0.7) & ~obst_m)
    rs = np.random.default_rng(len(cult) + 7)
    order = rs.permutation(len(ii))
    for k in order:
        px, pz = X0 + (jj[k] + 0.5) * RES, Z0 + (ii[k] + 0.5) * RES
        if all(math.hypot(px - q[0], pz - q[1]) > 2.0 for q in crew):
            crew.append((px, pz))
        if len(crew) == 3:
            break
    yh = level_at(lvn, x, z)
    cult.append([name, r2(x * S), r2(yh), r2(z * S), [[r2(px * S), r2(level_at(lvn, px, pz)), r2(pz * S)] for px, pz in crew]])

# ── lamps (ours): a grid over each lit floor, kept off walls; hanging lamps in the halls, ceiling lamps elsewhere ──
lamps = []  # x, y (the lamp), z, kind


def lamp_grid(floor, step, y_of, kind, off=0.0):
    dist = ndimage.distance_transform_edt(floor) * RES
    for gx in np.arange(-66 + off, 66, step):
        for gz in np.arange(-71 + off, 71, step):
            # the free point nearest the grid point within half a step
            i0, j0 = int((gz - Z0) / RES), int((gx - X0) / RES)
            r = int(step / 2 / RES)
            win = dist[max(0, i0 - r):i0 + r, max(0, j0 - r):j0 + r]
            if win.size == 0 or win.max() < 1.2:
                continue
            k = np.unravel_index(np.argmax(win), win.shape)
            x, z = X0 + (max(0, j0 - r) + k[1] + 0.5) * RES, Z0 + (max(0, i0 - r) + k[0] + 0.5) * RES
            lamps.append([r2(x * S), r2(y_of(x, z)), r2(z * S), kind])


indoor = (G_floor & ~open_m) | dock_m
lamp_grid(indoor & (roof_h == ROOF_HALL), 15.0, lambda x, z: ROOF_HALL - 2.2 * S, "hall")
lamp_grid(indoor & (roof_h == ROOF_LOW), 12.0, lambda x, z: ROOF_LOW - 0.5, "low", 3)
lamp_grid(B_floor, 12.0, lambda x, z: -SLAB - 0.45, "tunnel", 2)
lamp_grid(s2_office | s2_pump | s2_east, 7.0, lambda x, z: LV["third"] - 0.5, "office", 1)
lamp_grid(OFFICE3, 6.0, lambda x, z: ROOF_HALL - 0.5, "office", 1.5)

# ── loot: containers and loose spots (positions ours, counts from SPT's container groups) ───────────────────
# SPT gives Factory's containers by kind and group but every position is zero, so they are placed here: against the
# walls of each area, away from stairs, doors, exits, spawns and machines, spread out, the front to the room. The
# areas follow SPT's groups (wb_Administration_office, the basement weapon-box group, wb_Area_01..04, the exit group,
# terra_stock) and the kinds their counts (reference "containers").
keep_out = np.zeros((NZ, NX), bool)
for f in flights:
    keep_out |= dilate(flight_mask(f), 1.2)
for l in landings:
    keep_out |= dilate(rect_mask(l[0] / S, l[1] / S, l[2] / S, l[3] / S), 1.0)
for st_ in steps:
    keep_out |= dilate(rect_mask(st_[0] / S, st_[1] / S, st_[2] / S, st_[3] / S), 1.0)
for o in OPEN:
    if o[5] - o[4] > 1.5 * S:  # doors (windows do not keep a container off the wall)
        keep_out |= dilate(rect_mask(o[0] / S, o[1] / S, o[2] / S, o[3] / S), 1.6)
for e in ref["extracts"]:  # (EFT keeps weapon boxes near its exits: SPT's NearWithExit group; the zone itself stays clear)
    keep_out |= rect_mask(e["x"] - 2.5, e["x"] + 2.5, e["z"] - 2.5, e["z"] + 2.5)
for t in ref["transits"]:
    keep_out |= rect_mask(t["x"] - 3.5, t["x"] + 3.5, t["z"] - 3.5, t["z"] + 3.5)
for sp_ in spawns:
    keep_out |= rect_mask(sp_[0] / S - 2.5, sp_[0] / S + 2.5, sp_[2] / S - 2.5, sp_[2] / S + 2.5)
for o in ref["obstacles"]["ground"] + ref["obstacles"]["second"]:
    keep_out |= dilate(box_mask(o), 0.8)
for s_ in ref["silos"]:
    keep_out |= rect_mask(s_["cx"] - s_["r"] - 1, s_["cx"] + s_["r"] + 1, s_["cz"] - s_["r"] - 1, s_["cz"] + s_["r"] + 1)
keep_out |= dilate(pit_m, 1.0) | dilate(dock_m, 0.6)
keep_out |= rect_mask(-39.9, -36.0, -27.9, -25.0)  # the manager's desk (task SM_MANAGER)
keep_out |= rect_mask(27.5, 33.5, 21.5, 25.5)  # the aid post table (task SM_CASTING)
keep_out |= rect_mask(45.5, 54.5, 5.0, 13.0)  # the slag heap in the east yard (task STACK, Dress)
keep_out |= dilate(blocked, 0.3)  # wall lines, machines, stairs
for p_ in scav + boss + [q for r_ in routes.values() for q in r_] + [c_[1:4] for c_ in cult] + [q for c_ in cult for q in c_[4]]:
    keep_out |= rect_mask(p_[0] / S - 1.6, p_[0] / S + 1.6, p_[2] / S - 1.6, p_[2] / S + 1.6)
for fx, fz, hx, hz in ((-37.6, -15.5, 1.0, 0.8), (-37.6, -6.3, 1.0, 0.8), (-37.5, -21.0, 1.3, 0.35), (-35.6, -10.5, 0.2, 1.0),
                       (1.6, -4.0, 0.6, 1.3), (4.6, -14.0, 0.4, 0.5), (-30.0, -34.0, 0.6, 1.3), (-30.6, -52.0, 0.4, 1.4), (36.0, -49.3, 0.5, 1.0),
                       (44.0, -57.0, 0.6, 0.5), (-60.0, -54.5, 0.4, 0.4), (-36.0, 30.0, 0.6, 0.6), (-60.5, 10.0, 0.4, 1.4), (-60.5, 40.0, 0.4, 1.4)):
    keep_out |= rect_mask(fx - hx - 0.7, fx + hx + 0.7, fz - hz - 0.7, fz + hz + 0.7)  # Dress's furniture (half sizes + 0.7 m)
for d in ref["icons"]["drop"]:
    keep_out |= rect_mask(d["x"] - 1.6, d["x"] + 1.6, d["z"] - 1.6, d["z"] + 1.6)
for dd in DOORS:
    keep_out |= rect_mask(dd[2] - 2.0, dd[2] + 2.0, dd[4] - 2.0, dd[4] + 2.0)
rng = np.random.default_rng(1313)
# what stands on each storey's floor (machines, wall lines, stairs; lockers and benches upstairs): a passage is
# measured between them
STANDS = {"basement": blocked, "ground": blocked, "second": np.zeros((NZ, NX), bool), "third": np.zeros((NZ, NX), bool)}
for o in ref["obstacles"]["second"]:
    STANDS["second"] |= dilate(box_mask(o), 0.3)


# the office's third floor keeps its own clear spots (the shared keep-out above is the ground storey's: it took every
# spot in the shift office): its doors, the exit window, the furniture and the stair towers' landings
KEEP_THIRD = rect_mask(-39.9, -36.0, -27.9, -25.0)  # the manager's desk (task SM_MANAGER)
for dd in DOORS:
    if abs(dd[3] - T3) < 0.1:
        KEEP_THIRD |= rect_mask(dd[2] - 1.6, dd[2] + 1.6, dd[4] - 1.6, dd[4] + 1.6)
for o in OPEN:
    if abs(o[4] - T3) < 0.1:
        KEEP_THIRD |= dilate(rect_mask(o[0] / S, o[1] / S, o[2] / S, o[3] / S), 1.0)
for e in ref["extracts"]:
    if e["level"] == "third":
        KEEP_THIRD |= rect_mask(e["x"] - 2.0, e["x"] + 2.0, e["z"] - 2.0, e["z"] + 2.0)
for fx, fz, hx, hz in ((-37.6, -15.5, 1.0, 0.8), (-37.6, -6.3, 1.0, 0.8), (-37.5, -21.0, 1.3, 0.35), (-35.6, -10.5, 0.2, 1.0)):
    KEEP_THIRD |= rect_mask(fx - hx - 0.6, fx + hx + 0.6, fz - hz - 0.6, fz + hz + 0.6)
for _id, (bx0, bx1, bz0, bz1), _ys in tower_boxes:
    KEEP_THIRD |= rect_mask(bx0 - 0.8, bx1 + 0.8, bz0 - 0.8, bz1 + 0.8)
# and the second floor its own: the stairs that reach it, its lockers and benches, the spawn on it, the drop, the
# broken-out door to the courtyard stair
KEEP_SECOND = dilate(ARRIVE2, 1.0) | dilate(STANDS["second"], 0.5)
for f in flights:
    if f[4] - 0.3 <= LV["second"] <= f[4] + f[5] + 0.3:
        KEEP_SECOND |= dilate(flight_mask(f), 1.0)
for l in landings:
    if abs(l[4] - LV["second"]) < 0.3:
        KEEP_SECOND |= dilate(rect_mask(l[0] / S, l[1] / S, l[2] / S, l[3] / S), 1.0)
for sp_ in spawns:
    if abs(sp_[1] - LV["second"]) < 1.0:
        KEEP_SECOND |= rect_mask(sp_[0] / S - 2.5, sp_[0] / S + 2.5, sp_[2] / S - 2.5, sp_[2] / S + 2.5)
for o in OPEN:
    if abs(o[4] - LV["second"]) < 0.1:
        KEEP_SECOND |= dilate(rect_mask(o[0] / S, o[1] / S, o[2] / S, o[3] / S), 1.6)
for d in ref["icons"]["drop"]:
    if d["from"] == "second":
        KEEP_SECOND |= rect_mask(d["x"] - 1.6, d["x"] + 1.6, d["z"] - 1.6, d["z"] + 1.6)
for _id, (bx0, bx1, bz0, bz1), _ys in tower_boxes:
    KEEP_SECOND |= rect_mask(bx0 - 0.8, bx1 + 0.8, bz0 - 0.8, bz1 + 0.8)


def pass_keep(level):
    """the widened doorways and necks of a level, 1.8 m round: no box stands in them"""
    m = np.zeros((NZ, NX), bool)
    for px_, pz_, lv_ in PASSES:
        if lv_ == level:
            m |= rect_mask(px_ - 1.8, px_ + 1.8, pz_ - 1.8, pz_ + 1.8)
    return m


def bridges(m, half):
    """The parts of a floor narrower than 2 x half metres that join two wider parts of it."""
    core = ndimage.binary_opening(m, structure=disk(int(round(half / RES))))
    lab_c, _ = ndimage.label(core)
    lab_t, _ = ndimage.label(m & ~core, structure=np.ones((3, 3), bool))
    out = np.zeros_like(m)
    for k, sl in enumerate(ndimage.find_objects(lab_t), start=1):
        if sl is None:
            continue
        i0, i1 = max(0, sl[0].start - 3), min(NZ, sl[0].stop + 3)
        j0, j1 = max(0, sl[1].start - 3), min(NX, sl[1].stop + 3)
        part = lab_t[i0:i1, j0:j1] == k
        if mouths(part, lab_c[i0:i1, j0:j1] > 0) >= 2:
            out[i0:i1, j0:j1] |= part
    return out


def spots_in(floor, area, n, band=(0.74, 1.05), spacing=4.0, avoid=None, stands=None, keep=None):
    """n spots 0.6-0.95 m off a wall inside `area` on `floor`, spread out; each with the angle facing away from the wall."""
    if n <= 0:
        return []
    # a box (up to 1.7 m from its wall) leaves a walker at least 1.2 m: no boxes in a passage under 2.9 m wide (a part
    # that narrow joining two wider ones; corners and dead ends may take boxes)
    narrow = bridges(floor & ~stands if stands is not None else floor, 1.45)
    dist = ndimage.distance_transform_edt(floor) * RES
    cand = floor & area & (dist >= band[0]) & (dist <= band[1]) & ~(keep_out if keep is None else keep) & ~dilate(narrow, 1.0)
    if avoid is not None:
        cand &= ~avoid
    ii, jj = np.nonzero(cand)
    if len(ii) == 0:
        return []
    pts = np.stack([X0 + (jj + 0.5) * RES, Z0 + (ii + 0.5) * RES], 1)
    gz, gx = np.gradient(dist)
    picked = []
    order = rng.permutation(len(pts))
    pts = pts[order]
    ii, jj = ii[order], jj[order]
    mind = np.full(len(pts), np.inf)
    k = 0
    while len(picked) < n:
        if picked:
            p = pts[k]
            mind = np.minimum(mind, np.hypot(pts[:, 0] - p[0], pts[:, 1] - p[1]))
            k = int(np.argmax(mind))
            if mind[k] < spacing:
                break
        i, j = ii[k], jj[k]
        ang = math.degrees(math.atan2(gz[i, j], gx[i, j]))  # up the distance field: away from the wall
        picked.append((float(pts[k][0]), float(pts[k][1]), round(ang / 90) * 90 % 360))
        mind[k] = 0
    return picked


containers, loose = [], []
LABEL = {"crate": "Wooden crate", "toolbox": "Toolbox", "jacket": "Work jacket", "duffle": "Gym bag", "weaponbox": "Weapon case",
         "grenade": "Grenade box", "drawer": "Desk drawers", "medbag": "First-aid bag", "safe": "Safe", "banksafe": "Strongbox",
         "techbox": "Tech supply crate"}
KIND = {"crate": "crate", "toolbox": "toolbox", "jacket": "jacket", "duffle": "crate", "weaponbox": "weaponbox", "grenade": "crate",
        "drawer": "drawer", "medbag": "medbag", "safe": "safe", "banksafe": "safe", "techbox": "techbox"}


def placed_near(y):
    """the footprints (grown by 1.6 m) of the boxes already placed within 4 studs of height y (None: all)"""
    m = np.zeros((NZ, NX), bool)
    for c in containers:
        if y is None or abs(c[4] - y) < 4:
            m |= rect_mask(c[3] / S - 1.6, c[3] / S + 1.6, c[5] / S - 1.6, c[5] / S + 1.6)
    return m


_OPEN_CACHE = {}
LEVEL_FLOOR = {"basement": B_floor, "ground": G_floor | court_m, "second": s2_office | s2_pump | s2_east | s2_deck | s2_dock | s2_bridge,
               "third": T_floor | OFFICE3}


def reach_floor(floor, y):
    """The part of a floor at height y (studs) a walker gets to: the floor less the walls, wall lines and machines
    standing on it, in the pieces that hold a stair end, a landing, a spawn, an AI point or an exit (a room the
    reference's walls seal takes no loot: two boxes stood in one over the office's north stair)"""
    key = round(y, 1)
    if key not in _OPEN_CACHE:
        m = np.zeros((NZ, NX), bool)
        for w in walls:
            if w[4] < y + 5 and w[5] > y + 1:
                i0, i1 = int(round((w[2] / S - Z0) / RES)), int(round((w[3] / S - Z0) / RES))
                j0, j1 = int(round((w[0] / S - X0) / RES)), int(round((w[1] / S - X0) / RES))
                m[max(0, i0):max(0, i1), max(0, j0):max(0, j1)] = True
        for ln in lines:
            if ln[5] < y + 5 and ln[6] > y + 1:
                a_, b_ = (ln[0] / S, ln[1] / S), (ln[2] / S, ln[3] / S)
                n_ = max(2, int(math.hypot(b_[0] - a_[0], b_[1] - a_[1]) / 0.05))
                for k_ in range(n_ + 1):
                    i_ = int((a_[1] + (b_[1] - a_[1]) * k_ / n_ - Z0) / RES)
                    j_ = int((a_[0] + (b_[0] - a_[0]) * k_ / n_ - X0) / RES)
                    if 0 <= i_ < NZ and 0 <= j_ < NX:
                        m[i_, j_] = True
        for bx in boxes:
            if bx[5] < y + 5 and bx[5] + bx[6] > y + 1:
                m |= box_mask({"cx": bx[0] / S, "cz": bx[1] / S, "w": bx[2] / S, "d": bx[3] / S, "rot": bx[4]})
        seeds = [(p_[0] / S, p_[1], p_[2] / S) for p_ in spawns + scav + boss + [q for r_ in routes.values() for q in r_]]
        seeds += [((l[0] + l[1]) / 2 / S, l[4], (l[2] + l[3]) / 2 / S) for l in landings]
        seeds += [(e[2] / S, e[3], e[4] / S) for e in extracts]
        for f in flights:
            cx_, cz_ = (f[0] + f[1]) / 2 / S, (f[2] + f[3]) / 2 / S
            lo_, hi_ = {"+x": ((f[0] / S, cz_), (f[1] / S, cz_)), "-x": ((f[1] / S, cz_), (f[0] / S, cz_)),
                        "+z": ((cx_, f[2] / S), (cx_, f[3] / S)), "-z": ((cx_, f[3] / S), (cx_, f[2] / S))}[f[6]]
            seeds += [(lo_[0], f[4], lo_[1]), (hi_[0], f[4] + f[5], hi_[1])]
        _OPEN_CACHE[key] = (m, seeds)
    m, seeds = _OPEN_CACHE[key]
    lab, _ = ndimage.label(floor & ~dilate(m, 0.2), structure=np.ones((3, 3), bool))
    keep = set()
    for sx, sy, sz in seeds:
        if abs(sy - y) > 2.5:
            continue
        i_, j_ = int((sz - Z0) / RES), int((sx - X0) / RES)
        win = lab[max(0, i_ - 8):i_ + 9, max(0, j_ - 8):j_ + 9]
        keep |= set(np.unique(win).tolist()) - {0}
    return np.isin(lab, sorted(keep)) if keep else np.zeros_like(floor)


def place(tag, floor, area, ylevel, kinds, spacing=4.0):
    want = []
    for k, c in kinds.items():
        want += [k] * c
    yref = None if callable(ylevel) else ylevel
    level = "basement" if yref is None or yref < -5 else ("ground" if yref < 10 else ("second" if yref < 20 else "third"))
    yr_ = LV["basement"] if yref is None else yref
    area = area & reach_floor(LEVEL_FLOOR[level], yr_)
    # passages are measured between everything standing on this storey: its walls and wall lines too (a box stood
    # in the doorway of the room north of the office's north stair, on the second floor)
    wallm_ = _OPEN_CACHE[round(yr_, 1)][0]
    stands_ = STANDS[level] | dilate(wallm_, 0.2)
    # and a box keeps clear of every wall standing on its storey (two stood into the second floor's wall lines)
    pts = spots_in(floor, area, len(want), spacing=spacing, avoid=placed_near(yref) | pass_keep(level) | dilate(wallm_, 0.7), stands=stands_,
                   keep={"third": KEEP_THIRD, "second": KEEP_SECOND}.get(level))
    for (x, z, ang), k in zip(pts, want):
        y = ylevel(x, z) if callable(ylevel) else ylevel
        containers.append(["SM" + str(len(containers) + 1), KIND[k], LABEL[k], r2(x * S), r2(y), r2(z * S), ang, tag])
    if len(pts) < len(want):
        print(f"  warning: {tag}: {len(pts)} of {len(want)} container spots found")


g_lv = lambda x, z: level_at("ground", x, z)
hall_floor = G_floor & ~west_m & ~pit_m & ~dock_m & ~open_m
west_floor = (G_floor | court_m) & west_m & ~dock_m & ~court_m
tun_floor = B_floor & ~sump_m
off3 = OFFICE3 & T_floor | OFFICE3
place("office ground", G_floor & west_m, rect_mask(-45, -32.4, -31.2, -1.6), LV["west"], {"drawer": 3, "crate": 1, "jacket": 1, "medbag": 1}, 2.5)
place("office second", s2_office, rect_mask(-48, -32, -42, -1.5), LV["second"], {"jacket": 5, "crate": 1, "drawer": 1, "medbag": 1}, 2.5)
place("manager's office", rect_mask(-39.9, -35.2, -27.9, -21.8), rect_mask(-39.9, -35.2, -27.9, -21.8), T3, {"safe": 1, "drawer": 2}, 1.5)
place("records room", rect_mask(-39.9, -35.2, -21.4, -16.8), rect_mask(-39.9, -35.2, -21.4, -16.8), T3, {"drawer": 1, "crate": 1}, 1.5)
place("shift office", rect_mask(-39.9, -35.2, -16.4, -5.7), rect_mask(-39.9, -35.2, -16.4, -5.7), T3, {"safe": 1, "drawer": 2, "crate": 1}, 2.0)
place("tunnels", tun_floor, rect_mask(-70, 70, -75, 75) & ~rect_mask(-48.5, -42, 23, 31.5), lambda x, z: level_at("basement", x, z),
      {"crate": 6, "weaponbox": 2, "grenade": 2, "toolbox": 2, "jacket": 1, "duffle": 1}, 7.0)
place("sump", sump_m, sump_m, LV["sump"], {"crate": 1, "duffle": 1}, 6.0)
place("sealed store", B_floor, rect_mask(-48.2, -42.6, 23.6, 30.8), LV["basement"], {"banksafe": 2, "techbox": 1}, 1.2)
place("hall north-west", hall_floor, rect_mask(-42, 3, -62, -20), 0.0, {"crate": 4, "toolbox": 3, "duffle": 1, "jacket": 2, "grenade": 1, "techbox": 1}, 6.0)
place("hall north-east", hall_floor, rect_mask(3, 38.3, -62, -15), 0.0, {"crate": 4, "toolbox": 3, "duffle": 1, "jacket": 1, "weaponbox": 1, "techbox": 1}, 6.0)
place("south-west wing", west_floor, rect_mask(-66, -32.4, -1.6, 72), LV["west"], {"crate": 4, "toolbox": 2, "duffle": 2, "jacket": 1, "weaponbox": 1, "grenade": 1}, 6.0)
place("hall south", hall_floor, rect_mask(-32, 38.3, -15, 56), 0.0, {"crate": 4, "toolbox": 2, "duffle": 1, "jacket": 1, "weaponbox": 1, "medbag": 1, "grenade": 1}, 6.0)
place("ore gate annex", hall_floor, rect_mask(-66, -40.5, -57, -49.5), 0.0, {"weaponbox": 1}, 3.0)
place("gate corridor", hall_floor, rect_mask(38.3, 63, 20.2, 26.7), 0.0, {"weaponbox": 1, "crate": 1}, 3.0)
place("east yard", yard_e & G_floor, yard_e, 0.0, {"crate": 1, "weaponbox": 1, "duffle": 1}, 6.0)
place("courtyard", court_m, court_m, LV["west"], {"crate": 1, "weaponbox": 1}, 6.0)
place("forklift bay", hall_floor, rect_mask(32, 66, -70, -53.4), 0.0, {"toolbox": 1, "crate": 1}, 4.0)


def prune_boxes(agent=0.45):
    """Walk each storey in 2D with the boxes standing (an agent `agent` metres round): a box that cuts floor off from
    the stairs, spawns and AI points, or that no one can reach, goes (offline walk 2026-11-09: three boxes closed the
    corridor north of the office's north stair on the second floor)."""
    removed = []
    for lvn, ys in (("basement", (LV["basement"], LV["sump"])), ("ground", (0.0, LV["west"])), ("second", (LV["second"],)), ("third", (T3,))):
        for y in ys:
            reach_floor(LEVEL_FLOOR[lvn], y)  # fills the cache
            wallm, seeds = _OPEN_CACHE[round(y, 1)]
            fl = LEVEL_FLOOR[lvn] & ~dilate(wallm, agent)
            sd = [(sx, sz) for sx, sy, sz in seeds if abs(sy - y) <= 2.5]

            def reach(mask):
                lab, _ = ndimage.label(mask, structure=np.ones((3, 3), bool))
                keep = set()
                for sx, sz in sd:
                    i_, j_ = int((sz - Z0) / RES), int((sx - X0) / RES)
                    keep |= set(np.unique(lab[max(0, i_ - 8):i_ + 9, max(0, j_ - 8):j_ + 9]).tolist()) - {0}
                return np.isin(lab, sorted(keep)) if keep else np.zeros_like(mask)

            base = reach(fl)
            for _ in range(12):
                here = [c for c in containers if abs(c[4] - y) < 1.5]
                boxm = np.zeros((NZ, NX), bool)
                for c in here:
                    boxm |= rect_mask(c[3] / S - 0.64 - agent, c[3] / S + 0.64 + agent, c[5] / S - 0.64 - agent, c[5] / S + 0.64 + agent)
                now = reach(fl & ~boxm)
                lost = base & ~now & ~boxm
                lab_l, n_l = ndimage.label(lost)
                worst = None
                if n_l:
                    sizes_ = ndimage.sum(lost, lab_l, range(1, n_l + 1))
                    k = int(np.argmax(sizes_)) + 1
                    if sizes_[k - 1] * RES * RES > 0.5:
                        ii, jj = np.nonzero(lab_l == k)
                        cx_, cz_ = X0 + (jj.mean() + 0.5) * RES, Z0 + (ii.mean() + 0.5) * RES
                        worst = min(here, key=lambda c: math.hypot(c[3] / S - cx_, c[5] / S - cz_)) if here else None
                if worst is None:  # boxes nobody reaches
                    for c in here:
                        i_, j_ = int((c[5] / S - Z0) / RES), int((c[3] / S - X0) / RES)
                        r_ = int((0.64 + agent + 0.6) / RES)
                        if not now[max(0, i_ - r_):i_ + r_ + 1, max(0, j_ - r_):j_ + r_ + 1].any():
                            worst = c
                            break
                if worst is None:
                    break
                containers.remove(worst)
                removed.append(worst[7])
    if removed:
        print(f"  {len(removed)} loot boxes left out where they would close a way or stand out of reach: {', '.join(removed)}")


prune_boxes()
for i_, c in enumerate(containers):  # ids in order again
    c[0] = "SM" + str(i_ + 1)

# loose spots (ours): office floors and desks get office loot, the halls and tunnels junk, a few keys
avoid_c = np.zeros((NZ, NX), bool)
for c in containers:
    avoid_c |= rect_mask(c[3] / S - 1.6, c[3] / S + 1.6, c[5] / S - 1.6, c[5] / S + 1.6)


def clear_of_walls(xs, ys, zs, gap=0.5):
    """a loose spot keeps half a stud off every wall standing at its level (seen in Studio 2026-11-09: four
    third-floor spots drawn inside the office partitions)"""
    for w in walls:
        if not (w[4] - 0.5 <= ys + 1.0 <= w[5] + 0.5):
            continue
        dx = max(w[0] - xs, 0.0, xs - w[1])
        dz = max(w[2] - zs, 0.0, zs - w[3])
        if dx * dx + dz * dz < gap * gap:
            return False
    return True


def walls_at(y):
    """the footprints (grown by 0.3 m) of the walls standing at height y, as a mask the spots keep out of"""
    m = np.zeros((NZ, NX), bool)
    for w in walls:
        if w[4] - 0.5 <= y + 1.0 <= w[5] + 0.5:
            m |= rect_mask(w[0] / S - 0.3, w[1] / S + 0.3, w[2] / S - 0.3, w[3] / S + 0.3)
    return m


def loose_in(floor, area, ylevel, n, tbl, chance, spacing):
    """n spots near the walls of `area`; where the floor runs under its walls (the office block), further in"""
    k = 0
    yl = ylevel if not callable(ylevel) else None
    avoid = (avoid_c | walls_at(yl)) if yl is not None else avoid_c
    lvn_ = "basement" if yl is None or yl < -5 else ("ground" if yl < 10 else ("second" if yl < 20 else "third"))
    area = area & reach_floor(LEVEL_FLOOR[lvn_], LV["basement"] if yl is None else yl)
    taken = []
    for band in ((0.45, 0.75), (0.9, 1.3), (1.3, 1.8)):
        if k >= n:
            break
        for x, z, _ in spots_in(floor, area, (n - k) * 4, band=band, spacing=spacing, avoid=avoid):
            y = ylevel(x, z) if callable(ylevel) else ylevel
            if k >= n or not clear_of_walls(x * S, y, z * S) or any(math.hypot(x - a, z - b) < spacing for a, b in taken):
                continue
            loose.append([r2(x * S), r2(y + 0.05), r2(z * S), tbl, chance])
            taken.append((x, z))
            k += 1


loose_in(G_floor & west_m, rect_mask(-45, -32.4, -31.2, -1.6), LV["west"], 4, "office", 0.45, 3.0)
loose_in(s2_office, rect_mask(-48, -32, -42, -1.5), LV["second"], 5, "office", 0.45, 3.0)
loose_in(OFFICE3, OFFICE3, T3, 6, "office", 0.5, 2.5)
loose_in(OFFICE3, rect_mask(-39.9, -35.2, -27.9, -21.8), T3, 1, "keys", 0.35, 2.0)
loose_in(tun_floor, rect_mask(-70, 70, -75, 75), lambda x, z: level_at("basement", x, z), 8, "junk", 0.35, 9.0)
loose_in(tun_floor, rect_mask(-70, 70, -75, 75), lambda x, z: level_at("basement", x, z), 2, "keys", 0.25, 20.0)
loose_in(sump_m, sump_m, LV["sump"], 3, "junk", 0.35, 6.0)
loose_in(hall_floor, rect_mask(-42, 38.3, -66, 56), 0.0, 14, "junk", 0.4, 9.0)
loose_in(west_floor, rect_mask(-66, -32.4, -1.6, 72), LV["west"], 5, "junk", 0.4, 8.0)
loose_in(hall_floor, rect_mask(23.8, 36.6, 20.4, 26.7), 0.0, 2, "keys", 0.3, 3.0)
loose_in(s2_pump | s2_east, s2_pump | s2_east, LV["second"], 3, "junk", 0.4, 4.0)


def lua_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        f = float(v)
        if f == int(f):
            return str(int(f))
        return repr(round(f, 2))
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    raise TypeError(v)


def lua_list(name, rows, per_line=1):
    lines = [f"L.{name} = {{"]
    for i in range(0, len(rows), per_line):
        lines.append("\t" + ", ".join(lua_val(r) for r in rows[i:i + per_line]) + ",")
    lines.append("}")
    return "\n".join(lines)


head = f'''--!nonstrict
-- GENERATED by tools/factory_layout.py from docs/maps/reference/factory_layout.json: do not edit by hand.
-- EFT Factory's layout (tarkov-dev-svg-maps Factory.svg, the re3mr plans, SPT 0.16.9 spawn data; the reference doc has
-- the sources, grades and licence notes) in Smelter map-local studs: x east, z south, y up, S = 3.125 studs per metre,
-- local y = (game y - 0.1) * S (the main hall floor is y 0). Our names; see docs/maps/SMELTER_FACTORY_BUILD.md.
-- Rows (all studs):
--   slabs     {{ x0, x1, z0, z1, yTop, thickness, kind }}      floors, decks, roofs (kind picks the look)
--   walls     {{ x0, x1, z0, z1, y0, y1, kind }}               walls and solid masses
--   lines     {{ x0, z0, x1, z1, thickness, y0, y1, kind }}    the reference's wall lines (some at an angle)
--   doors     {{ id, label, x, yFloor, z, width, height, axis, key }}   door leaves ("CARD": the sealed store's card)
--   flights   {{ x0, x1, z0, z1, yBottom, rise, dir, stacked, id }}   stairs climbing toward dir ("+x" ...)
--   landings  {{ x0, x1, z0, z1, yTop }}                       stair landings
--   steps     {{ x0, x1, z0, z1, yLow, rise, dir, kind }}       short flights where a floor changes level
--   rails     {{ x0, z0, x1, z1, y }}                          railings on deck edges
--   boxes     {{ cx, cz, w, d, rotDeg, y0, h, kind }}          machines, vehicles, pallets (the reference's obstacles)
--   cyls      {{ cx, cz, r, y0, h, kind }}                     the crucibles in the pit and the vessels beside it
--   labels    {{ name, x, y, z, level }}                       our names at the reference's label points
--   extracts  {{ id, name, x, y, z, sides, eft }}              exits (rules in Play)
--   transits  {{ name, x, y, z }}
--   spawns    {{ x, y, z, faceDeg }}                           SPT player spawn points (one per group)
--   scav, boss  {{ x, y, z }}                                  SPT bot and boss-capable points
--   containers  {{ id, kind, label, x, y, z, faceDeg, area }}   loot containers (positions ours, counts SPT's)
--   loose     {{ x, y, z, pool, chance }}                      loose loot spots (ours)
--   routes    {{ id = {{ {{ x, y, z }}, ... }} }}                   guard routes (ours)
--   cult      {{ name, x, y, z, {{ {{ x, y, z }} x3 }} }}             THE CULT's night zones and the warriors' spots
--   lamps     {{ x, y, z, kind }}                              lamp heads (ours): hall, low, tunnel, office
local L = {{}}
L.S = {S}
L.LV = {{ basement = {r2(LV["basement"])}, sump = {r2(LV["sump"])}, hall = 0, west = {r2(LV["west"])}, gallery = {r2(LV["gallery"])}, second = {r2(LV["second"])}, third = {r2(LV["third"])}, roof = {r2(ROOF_HALL)}, roofLow = {r2(ROOF_LOW)}, yardWall = {r2(YARD_WALL)}, servicePit = {r2(-SERVICE_PIT)} }}
-- the map's extent (the reference frame, 131.9 x 142.5 m) and the playable outline's box
L.frame = {{ {r2(-65.95 * S)}, {r2(-71.25 * S)}, {r2(65.95 * S)}, {r2(71.25 * S)} }}
-- the extent the layout fills (the outside ground runs to it; beyond it the builder lays open ground to the horizon)
L.outer = {{ {r2(X0 * S)}, {r2(Z0 * S)}, {r2((X0 + NX * RES) * S)}, {r2((Z0 + NZ * RES) * S)} }}
'''
parts = [head]
parts.append(lua_list("slabs", slabs, 3))
parts.append(lua_list("walls", walls, 3))
parts.append(lua_list("lines", lines, 2))
parts.append(lua_list("doors", doors, 1))
parts.append(lua_list("flights", [f[:9] for f in flights], 2))
parts.append(lua_list("landings", landings, 3))
parts.append(lua_list("steps", steps, 2))
parts.append(lua_list("rails", rails, 3))
parts.append(lua_list("boxes", boxes, 2))
parts.append(lua_list("cyls", cyls, 2))
parts.append(lua_list("labels", labels, 2))
parts.append(lua_list("extracts", extracts, 1))
parts.append(lua_list("transits", transits, 1))
parts.append(lua_list("spawns", spawns, 3))
parts.append(lua_list("scav", scav, 4))
parts.append(lua_list("boss", boss, 4))
parts.append(lua_list("containers", containers, 1))
parts.append("L.routes = {\n" + "\n".join(f"\t{k} = {lua_val(v)}," for k, v in routes.items()) + "\n}")
parts.append(lua_list("cult", cult, 1))
parts.append(lua_list("lamps", lamps, 4))
parts.append(lua_list("loose", loose, 3))
parts.append("return L\n")
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(parts))
print(f"{OUT.relative_to(ROOT)}: {len(slabs)} slabs, {len(walls)} walls, {len(flights)} flights, {len(landings)} landings, "
      f"{len(steps)} level steps, {len(rails)} rails, {len(boxes)} boxes, {len(cyls)} cylinders, {len(labels)} labels, "
      f"{len(extracts)} extracts, {len(spawns)} spawns, {len(scav)} scav and {len(boss)} boss points, {len(containers)} containers, "
      f"{len(loose)} loose spots")
if "-j" in sys.argv:
    dump = {"slabs": slabs, "walls": walls, "lines": lines, "doors": doors, "flights": flights, "landings": landings, "steps": steps, "rails": rails, "boxes": boxes,
            "cyls": cyls, "containers": containers, "loose": loose, "routes": routes, "cult": cult, "lamps": lamps, "labels": labels, "extracts": extracts, "transits": transits, "spawns": spawns, "scav": scav, "boss": boss, "LV": LV}
    pathlib.Path(sys.argv[sys.argv.index("-j") + 1]).write_text(json.dumps(dump))
if "-c" in sys.argv:
    # every gameplay point on a floor of its level (local y within 1 stud of the floor there)
    def chk(tag, x, y, z):
        best = None
        for lvn in ("basement", "ground", "second", "third"):
            fy = level_at(lvn, x / S, z / S)
            if fy is not None and (best is None or abs(fy - y) < abs(best - y)):
                best = fy
        if best is None or abs(best - y) > 1.0:
            print(f"  check: {tag} at ({x / S:.1f}, {z / S:.1f}) y {y:.2f}: nearest floor {best}")
    for i, sp_ in enumerate(spawns):
        chk(f"spawn {i}", sp_[0], sp_[1], sp_[2])
    for i, p_ in enumerate(scav):
        chk(f"scav {i}", p_[0], p_[1], p_[2])
    for i, p_ in enumerate(boss):
        chk(f"boss {i}", p_[0], p_[1], p_[2])
    for e in extracts:
        chk(f"extract {e[0]}", e[2], e[3], e[4])
    for c in containers:
        chk(f"container {c[0]}", c[3], c[4], c[5])
    for l in loose:
        chk("loose", l[0], l[1] - 0.05, l[2])
if "-v" in sys.argv:
    for s in stair_log:
        print("  stair", s)

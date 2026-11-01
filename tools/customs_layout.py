#!/usr/bin/env python3
"""Border Yard layout generator: docs/maps/reference/customs_layout.json -> src/server/Maps/Border/Layout.luau.

Converts the reference (metres, x east, z south, game y) to map-local studs for the Border map (docs/maps/
BORDER_CUSTOMS_BUILD.md): S = 3.125 studs per metre, local y = (game y - 1.3) * S (0 = the flat plain), and
adds our names. Run from the repo root with:  python3 -I tools/customs_layout.py
The output is compact data (flat arrays, positional records); the header of Layout.luau says what every field is.
"""
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/maps/reference/customs_layout.json"
OUT = ROOT / "src/server/Maps/Border/Layout.luau"
S = 3.125
PLAIN = 1.3  # game y of the flat plain
DZ = 16  # river row spacing in studs

# ── names (the layout is Customs', the names are ours: docs/maps/BORDER_CUSTOMS_BUILD.md) ──────────────────────
BLD_NAMES = {
    0: "STORE 17 GARAGE A", 1: "STORE 17 GARAGE B", 2: "TRAILER LOT GARAGES", 3: "STORAGE YARD EAST ROW",
    4: "STORAGE YARD WEST ROW", 5: "RED STORES CABIN A", 6: "RED STORES CABIN B", 7: "STORAGE YARD DIAGONAL ROW",
    8: "STORAGE BLOCK NW", 9: "STORAGE BLOCK NE", 10: "STORAGE BLOCK SW", 11: "STORAGE BLOCK SE",
    12: "FUEL TANK 1", 13: "FUEL TANK 2", 14: "PUMP PLATFORM N", 15: "FUEL TANK 3", 16: "FUEL TANK 4",
    17: "PUMP PLATFORM S", 18: "WATCHHOUSE", 19: "PUMP HOUSE", 20: "STORE 7", 21: "DEPOT", 22: "STORE 3", 23: "STORE 4",
    24: "FUEL STOP", 25: "BLOCK B", 26: "BLOCK A", 27: "THE DERRICK", 28: "THE BASTION", 29: "THE SQUAT",
    30: "MOTOR SHOP + BOILER HOUSE", 31: "STORE 17", 32: "OLD WORKS", 33: "RED STORES", 34: "THE FRAME",
    35: "OLD PUMPS SHED A", 36: "ARMY POST HUT", 37: "ARMY POST BARRACKS", 38: "PYLON PAD BOOTH", 39: "BUS STOP BOOTH A",
    40: "BUS STOP BOOTH B", 41: "BLOCK A GATEHOUSE", 42: "HUTS KIOSK A", 43: "HUTS KIOSK B", 44: "OLD PUMPS",
    45: "WORKS BOOTH", 46: "ROADSIDE HUT", 47: "HILL ROADBLOCK BOOTH", 48: "STORE 17 BOOTH", 49: "RIDGE BOOTH",
    50: "BUNKER K-11 SHED", 51: "SMUGGLERS' HOLE SHED", 52: "BRIDGE BOOTH A", 53: "BRIDGE BOOTH B",
    54: "RED STORES BOOTH", 55: "TRAILER LOT SHACK", 56: "TRAILER A", 57: "TRAILER B", 58: "TRAILER C",
    59: "TRAILER LOT SHED", 60: "TRAILER D", 61: "SQUAT KIOSK", 62: "FRAME KIOSK", 63: "STORE 4 SHACK",
    64: "ROADSIDE SHACK W", 65: "ROADSIDE SHACK E", 66: "OLD PUMPS SHED B",
}
# roof heights known from the reference (game y of the roof): tower 54.7, depot 14.8, boiler house 16.2
ROOF_Y = {27: 54.7, 21: 14.8, 30: 16.2}
YARD_NAMES = {
    0: "RED STORES YARD", 1: "STORAGE YARD", 2: "NORTH TRAILER PAD", 3: "FRAME NORTH APRON", 4: "MOTOR SHOP FORECOURT",
    5: "WORKS YARD", 6: "BASTION WEST YARD", 7: "OLD PUMPS FORECOURT", 8: "FUEL STOP FORECOURT", 9: "STORE 3-4 APRON",
    10: "STORE 7 YARD", 11: "BUS STOP PAD", 12: "FRAME SOUTH APRON", 13: "PYLON PAD", 14: "BLOCKS PAD",
    15: "SCRAP BRIDGE LANDING W", 16: "SCRAP BRIDGE LANDING E",
}
LABEL_NAMES = {
    "Big Red": "RED STORES", "Dorms": "BLOCKS", "New Gas": "FUEL STOP", "Old Gas": "OLD PUMPS", "Fortress": "THE BASTION",
    "Crackhouse": "THE SQUAT", "Streamer House": "WATCHHOUSE", "Main Bridge": "MAIN BRIDGE", "Sniper Hill": "THE HILL",
    "Storage": "STORAGE YARD", "Trailer Park": "TRAILER LOT", "Junk Bridge": "SCRAP BRIDGE", "Repair Shop": "MOTOR SHOP",
    "Sniper Ridge": "THE RIDGE", "Old Construction": "OLD WORKS", "Skeleton": "THE FRAME", "Warehouse 3": "STORE 3",
    "Depot": "DEPOT", "Warehouse 7": "STORE 7", "Military Checkpoint": "ARMY POST", "Bus Station": "BUS STOP",
    "Warehouse 4": "STORE 4", "Powerline Tower": "PYLON PAD", "Warehouse 17": "STORE 17",
}
ZONE_NAMES = {
    "ZoneBlockPost": "ARMY POST", "ZoneBrige": "RIVER BANK", "ZoneCrossRoad": "HUTS CROSSROAD", "ZoneCustoms": "EAST YARDS",
    "ZoneDormitory": "BLOCKS", "ZoneFactoryCenter": "DEPOT YARDS", "ZoneFactorySide": "TANK FARM", "ZoneGasStation": "FUEL STOP",
    "ZoneOldAZS": "OLD PUMPS", "ZoneScavBase": "THE BASTION", "ZoneTankSquare": "MOTOR YARD", "ZoneWade": "THE FORD",
}
SNIPER_NAMES = {
    "ZoneBlockPostSniper": "ARMY POST HUT", "ZoneSnipeBrige": "BOILER HOUSE ROOF", "ZoneSnipeFactory": "DEPOT ROOF",
    "ZoneSnipeTower": "DERRICK ROOF",
}
# reference extract name -> (id, our name, spawn group override or None, rule, zone size (x, y, z) in studs)
# rule keys follow the game's extract kinds: kind open | paid (cost; a car also has chance, seats, depart) | key (key) |
# chance (chance) | power (switch, needs) | scav. Groups: east / west = the PMC entry half that may use it (the reference's entry_group: east-half
# spawners leave in the WEST), both = shared, scav = scav-only.
EXTRACTS = {
    "ZB-1011": ("K11", "BUNKER K-11", None, {"kind": "open"}, (16, 10, 16)),
    "Smugglers' Bunker (ZB-1012)": ("SH", "SMUGGLERS' HOLE", None, {"kind": "chance", "chance": 0.5}, (14, 10, 14)),
    "Old Gas Station": ("OP", "OLD PUMPS", None, {"kind": "chance", "chance": 0.5, "signal": "green"}, (14, 10, 14)),
    # a car (Tarkov's V-Ex): chance = the SPT 50 %, seats = max 4 players, depart = the 60 s shared timer (the game's Extract.luau)
    "Dorms V-Ex": ("DC", "DORMS CAR", None, {"kind": "paid", "cost": 25000, "chance": 0.5, "seats": 4, "depart": 60}, (26, 12, 26)),
    "ZB-013 (also written ZB-1013)": ("K13", "BUNKER K-13", None,
                                      {"kind": "power", "switch": "BORDER_STORE4", "needs": "NO POWER  ·  THROW THE LEVER IN STORE 4"}, (16, 10, 16)),
    "Crossroads": ("CR", "CROSSROADS", None, {"kind": "open"}, (30, 12, 30)),
    "Trailer Park": ("TL", "TRAILER LOT", None, {"kind": "open"}, (28, 12, 28)),
    "RUAF Roadblock": ("AR", "ARMY ROADBLOCK", None, {"kind": "open"}, (28, 12, 28)),
    "Smugglers' Boat": ("SB", "SMUGGLERS' BOAT", None, {"kind": "chance", "chance": 0.5}, (24, 10, 24)),
    "Railroad Passage (Flare)": ("NL", "NORTH LINE", None, {"kind": "flare", "radius": 94}, (30, 12, 30)),
    "Boiler Room Basement (Co-op)": ("BC", "BOILER CELLAR", None, {"kind": "key", "key": "KEY_BY_BOILER"}, (16, 10, 16)),
    "Administration Gate": ("OF", "OFFICE GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Factory Far Corner": ("FC", "FAR CORNER", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Scav Checkpoint": ("OC", "OLD CHECKPOINT", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Military Base CP": ("AG", "ARMY GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Passage Between Rocks": ("RP", "ROCK PASS", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Railroad to Military Base": ("AL", "ARMY LINE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Warehouse 4": ("S4", "STORE 4 GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Factory Shacks": ("HG", "HUTS GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Old Road Gate": ("OR", "OLD ROAD GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Warehouse 17": ("S17", "STORE 17 GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Sniper Roadblock": ("HR", "HILL ROADBLOCK", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Railroad to Port": ("PL", "PORT LINE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Railroad to Tarkov": ("CL", "CITY LINE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Trailer Park Workers' Shack": ("TS", "SHACK GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
    "Old Gas Station Gate": ("PG", "PUMPS GATE", "scav", {"kind": "scav"}, (22, 12, 22)),
}
SIDE_OF_ROAD = {"gravel": "G"}


# ── helpers ───────────────────────────────────────────────────────────────────────────────────────────────────
def num(v, nd=1):
    """Short number text: rounded, no trailing zeros, no -0."""
    r = round(v, nd)
    if r == 0:
        return "0"
    if r == int(r):
        return str(int(r))
    return ("%." + str(nd) + "f") % r


def X(v):
    return v * S


def YL(g):
    return (g - PLAIN) * S


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def poly_edge(poly, x, z):
    """Signed distance from (x, z) to the closed polygon (flat [x, z, ...], positive inside) and the nearest edge point."""
    n = len(poly) // 2
    best, near, inside = 1e18, (x, z), False
    j = n - 1
    for e in range(n):
        ax, az, bx, bz = poly[2 * e], poly[2 * e + 1], poly[2 * j], poly[2 * j + 1]
        if (az > z) != (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax:
            inside = not inside
        dx, dz = bx - ax, bz - az
        l2 = dx * dx + dz * dz
        t = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / l2))
        px, pz = ax + dx * t, az + dz * t
        d = math.hypot(x - px, z - pz)
        if d < best:
            best, near = d, (px, pz)
        j = e
    return (best if inside else -best), near


def pull_inside(poly, x, z, need):
    """Moves (x, z) (studs) inward until it lies at least `need` studs inside the polygon. Returns (x, z, studs moved).
    The reference puts some extract icons on or outside the traced limit (grades B and C are good to 5 to 25 m); the
    invisible boundary walls would make such an extract unreachable."""
    x0, z0 = x, z
    for _ in range(12):
        d, (px, pz) = poly_edge(poly, x, z)
        if d >= need:
            break
        if d < 0:
            ux, uz = px - x, pz - z  # outside: the nearest edge point lies toward the inside
        else:
            ux, uz = x - px, z - pz  # inside but close: away from the edge
        l = math.hypot(ux, uz)
        if l < 1e-6:
            break
        x, z = px + ux / l * need, pz + uz / l * need
    return x, z, math.hypot(x - x0, z - z0)


def flat(pts, nd=1):
    """x,z pairs (metres) -> flat studs list text body."""
    return ", ".join(num(c * S, nd) for p in pts for c in (p[0], p[1]))


def wrap(items, per=14, indent="\t"):
    lines = []
    for i in range(0, len(items), per):
        lines.append(indent + ", ".join(items[i:i + per]) + ",")
    return "\n".join(lines)


def flat_block(pts, nd=1, per=14, indent="\t\t"):
    vals = [num(c * S, nd) for p in pts for c in (p[0], p[1])]
    return wrap(vals, per, indent)


def seg_dist(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    l2 = dx * dx + dz * dz
    t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * dx + (pz - az) * dz) / l2))
    cx, cz = ax + t * dx, az + t * dz
    return math.hypot(px - cx, pz - cz)


def poly_dist(px, pz, pts):
    return min(seg_dist(px, pz, a[0], a[1], b[0], b[1]) for a, b in zip(pts, pts[1:]))


def yaw_of(facing_deg):
    """reference facing (0 east, 90 south, degrees) -> Roblox yaw (CFrame.Angles(0, rad(yaw), 0): 0 north, 90 west)."""
    f = math.radians(facing_deg)
    return math.degrees(math.atan2(-math.cos(f), -math.sin(f)))


# ── relief knots from the spawn-point heights ─────────────────────────────────────────────────────────────────
def build_relief(d):
    """Knots [x, z, y, sigma] in studs for the Gaussian-weighted relief field, plus rail embankment heights.
    Samples within 0.8 m of the plain are dropped; samples on a railway embankment feed that rail instead."""
    items = d["spawns"]["relief_samples"]["items"]
    rails = {r["id"]: r["pts"] for r in d["railway"]}
    emb_votes = {}
    keep = []
    for x, z, y in items:
        dev = y - PLAIN
        if abs(dev) < 0.8:
            continue
        taken = False
        if dev > 1.2:
            for rid, pts in rails.items():
                if poly_dist(x, z, pts) < 10:
                    emb_votes.setdefault(rid, []).append(dev)
                    taken = True
                    break
        if not taken:
            keep.append((x, z, dev))
    emb = {}
    for rid, v in emb_votes.items():
        if len(v) >= 2:
            v.sort()
            emb[rid] = v[len(v) // 2] * S
    # merge samples closer than 8 m (grid cells) into one knot
    cells = {}
    for x, z, dev in keep:
        cells.setdefault((int(x // 8), int(z // 8)), []).append((x, z, dev))
    knots = []
    for pts in cells.values():
        cx = sum(p[0] for p in pts) / len(pts)
        cz = sum(p[1] for p in pts) / len(pts)
        dv = sum(p[2] for p in pts) / len(pts)
        if dv >= 4.5:
            sg = 45.0  # plateau
        elif dv <= -4.5:
            sg = 32.0  # the south river valley
        elif dv >= 1.5:
            sg = 26.0  # ridge and slopes
        else:
            sg = 15.0  # dips and low spots
        knots.append((cx * S, cz * S, dv * S, sg * S))
    knots.sort(key=lambda k: (round(k[1]), round(k[0])))
    return knots, emb


# ── river rows ────────────────────────────────────────────────────────────────────────────────────────────────
def slice_poly(pts, z):
    xs = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if (a[1] <= z < b[1]) or (b[1] <= z < a[1]):
            xs.append(a[0] + (z - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
    if len(xs) < 2:
        return None
    return min(xs), max(xs)


def build_river(d):
    """Rows every DZ studs from the north end of the river to the south end: xl, xr (bank x) and the scheduled
    water surface (local y studs). Seams between the four reference polygons are filled by interpolation."""
    polys = [[(p[0] * S, p[1] * S) for p in r["poly"]] for r in d["river"]["polys"] if r["id"] != "river_1"]
    zs = [p[1] for poly in polys for p in poly]
    z0 = math.ceil(min(zs) / DZ) * DZ
    z1 = math.floor(max(zs) / DZ) * DZ
    rows = []
    z = z0
    while z <= z1:
        lo = hi = None
        for poly in polys:
            r = slice_poly(poly, z + 0.01)
            if r:
                lo = r[0] if lo is None else min(lo, r[0])
                hi = r[1] if hi is None else max(hi, r[1])
        rows.append([z, lo, hi])
        z += DZ
    # fill missing rows (seams) by linear interpolation between the neighbours
    for i, r in enumerate(rows):
        if r[1] is None:
            a = i - 1
            while a >= 0 and rows[a][1] is None:
                a -= 1
            b = i + 1
            while b < len(rows) and rows[b][1] is None:
                b += 1
            if a < 0 or b >= len(rows):
                raise SystemExit("river rows: open end at %s" % r[0])
            t = (r[0] - rows[a][0]) / (rows[b][0] - rows[a][0])
            r[1] = rows[a][1] + (rows[b][1] - rows[a][1]) * t
            r[2] = rows[a][2] + (rows[b][2] - rows[a][2]) * t
    # light smoothing of the banks (the traced outlines are jagged)
    sm = []
    for i in range(len(rows)):
        w = [rows[j] for j in range(max(0, i - 1), min(len(rows), i + 2))]
        sm.append([rows[i][0], sum(r[1] for r in w) / len(w), sum(r[2] for r in w) / len(w)])
    # scheduled water surface: metres below the plain, north to south (the valley deepens southward)
    sched = [(-211, -1.5), (-60, -1.5), (0, -2.0), (42, -2.4), (75, -4.5), (110, -8.0), (140, -11.5), (160, -13.5), (181, -15.0)]

    def ws(zst):
        zm = zst / S
        if zm <= sched[0][0]:
            return sched[0][1] * S
        for (za, wa), (zb, wb) in zip(sched, sched[1:]):
            if zm <= zb:
                return (wa + (wb - wa) * (zm - za) / (zb - za)) * S
        return sched[-1][1] * S

    for r in sm:
        r.append(ws(r[0]))
    return sm


# ── main ──────────────────────────────────────────────────────────────────────────────────────────────────────
def main():
    d = json.loads(SRC.read_text())
    out = []
    w = out.append

    knots, emb = build_relief(d)
    rows = build_river(d)

    w("--!nonstrict")
    w("-- GENERATED by tools/customs_layout.py from docs/maps/reference/customs_layout.json. Do not edit by hand: change the")
    w("-- tool and run  python3 -I tools/customs_layout.py  from the repo root.")
    w("-- Border Yard layout (the Customs layout, our names) in MAP-LOCAL STUDS: x east, z south (north = -z), origin = the")
    w("-- centre of the 1070 x 544 m map bounds, S = 3.125 studs per metre. Heights are local y: 0 = the flat plain (game y 1.3),")
    w("-- y = (game y - 1.3) x S. Add the map origin (B.O, MapKit's H.V) for world coordinates. Ids are the reference's, for")
    w("-- traceability. Accuracy grade conf: A footprint traced, B matched, C inferred, D unknown (docs/maps/reference).")
    w("-- Rotations: rot = angle of the long (w) side from +x toward +z in degrees (-90..90); place a box with")
    w("--   CFrame.new(cx, y, cz) * CFrame.Angles(0, -math.rad(rot), 0)  and Size (w, height, d)   (H.CF takes -rot in degrees).")
    w("-- yaw = Roblox yaw in degrees (CFrame.Angles(0, math.rad(yaw), 0): 0 faces north, 90 west, 180 south, -90 east).")
    w("-- Flat arrays are x, z, x, z ... (or the stride named below). Tables and fields:")
    w("--   S, box {x0, z0, x1, z1}        scale; bounding box of the playable polygon")
    w("--   boundary                         playable polygon, flat x, z (closed implicitly); sniper = the border sniper quad")
    w("--   river {z0, dz, n, rows}          rows = xl, xr, ws per row (stride 3), row k at z = z0 + k * dz: bank x west/east and")
    w("--                                    the scheduled water surface (local y; the build lowers it where the banks are low)")
    w("--   island                           island polygon, flat x, z; bridges = the two crossings (see the table)")
    w("--   roads {id, surf, w, pts}         surf H highway, M main road, T small tarmac, G gravel track; w = width in studs")
    w("--   rails {id, emb, pts}             emb = embankment height in studs (0 = at grade); rcross {road, rail, x, z}")
    w("--   fences {id, pts}                 open polylines; forests {id, cx, cz, w, d, rot, pts}; rocks flat x, z, r (stride 3)")
    w("--   power {id, pts}, towers          power lines (polylines through the towers) and the tower positions, flat x, z")
    w("--   yards {id, name, cx, cz, w, d, rot, pts}   concrete pads (pts = the traced outline)")
    w("--   blds {id, name, kind, cx, cz, w, d, rot, floors, h, base, conf}   h = roof height above the plain in studs (0 unknown),")
    w("--                                    base = 1 when there is a basement; outline[id] = flat outline of a concave building;")
    w("--                                    upper / locked = {id, level, cx, cz, w, d, rot} (upper-floor shapes, locked rooms)")
    w("--   under {id, name, kind, cx, cz, w, d, rot, lo, hi, open}   terrain voids dug by Ground (floor lo, ceiling hi, local y;")
    w("--                                    open = 1: no earth roof); stairs {id, level, cx, cz, w, d, rot} (level 0 = shafts")
    w("--                                    from the surface to the underground), floors {layer, name, y0, y1, x0, z0, x1, z1}")
    w("--   labels {name, x, z}              area names for the map")
    w("--   ext {id, name, grp, x, z, sx, sy, sz, rule, conf, note}   extracts; grp east / west = the PMC spawn half that may use it")
    w("--                                    (east-half spawners leave in the west of the map), both, scav; rule = {kind=...} as")
    w("--                                    World's extract rules; (x, z) the reference position, (sx, sy, sz) the zone size")
    w("--   spawns {east, west}              every reference PMC spawn point {x, z, y, yaw}; clusters {east, west} = the 5-point")
    w("--                                    groups {cx, cz, y0, y1, n, bld} (bld = id of the building the cluster is inside)")
    w("--   scav {id, name, x0, z0, x1, z1, normal, boss, bot}   scav zones; the three lists are flat x, z, y, yaw (stride 4)")
    w("--   snipers {zone, name, x, z, y, r, bld}   marksman perches; bosses {id, ours, chance, zones, guards, note}")
    w("--   hazard {sniper, flare, airdrop, raid, mounted, propane}   hazards (positions unknown stay empty)")
    w("--   relief {x, z, y, sigma, ...}     flat knots (stride 4): relief deviations from the plain, Gaussian width sigma (studs)")
    w("local L = {}")
    w("L.S = %s" % num(S, 3))

    # boundary
    b = d["boundary"]["poly"]
    bpoly = [c * S for p in b for c in (p[0], p[1])]
    bb = d["boundary"]["bbox"]
    w("L.box = { %s, %s, %s, %s }" % (num(bb[0] * S), num(bb[1] * S), num(bb[2] * S), num(bb[3] * S)))
    w("L.boundary = {\n%s\n}" % flat_block(b))
    w("L.sniper = { %s }" % flat(d["border_sniper_zone"]["poly"]))

    # river
    w("L.river = {")
    w("\tz0 = %s, dz = %d, n = %d," % (num(rows[0][0]), DZ, len(rows)))
    w("\trows = {")
    vals = []
    for r in rows:
        vals += [num(r[1]), num(r[2]), num(r[3])]
    w(wrap(vals, 12, "\t\t"))
    w("\t},")
    w("}")
    isl = d["river"]["polys"][1]["poly"]
    w("L.island = { %s }" % flat(isl))
    cr = d["river"]["crossings"][0]
    junk = [y for y in d["yards"] if y["name"].startswith("Junk Bridge deck")]
    w("L.bridges = {")
    w("\tmain = { x0 = %s, z0 = %s, x1 = %s, z1 = %s, w = %s }, -- MAIN BRIDGE: east end to west end, width in studs" % (
        num(cr["from"][0] * S), num(cr["from"][1] * S), num(cr["to"][0] * S), num(cr["to"][1] * S), num(cr["width_m"] * S)))
    decks = ", ".join("{ %s, %s, %s, %s, %s }" % (num(y["cx"] * S), num(y["cz"] * S), num(y["w"] * S), num(y["d"] * S), num(y["rot_deg"], 1)) for y in junk)
    ic = ((227.8 + 239.5) / 2, (67.7 + 93.6) / 2)
    w("\tscrap = { decks = { %s }, island = { %s, %s, %s, %s } }, -- SCRAP BRIDGE: decks {cx, cz, w (length), d (width), rot}" % (
        decks, num(233.0 * S), num(81.0 * S), num(12 * S), num(26 * S)))
    w("}")
    _ = ic

    # roads
    cls = {12: "H", 8: "M"}
    w("L.roads = {")
    for r in d["roads"]:
        if r["surface"] == "gravel":
            c = "G"
        else:
            c = cls.get(r["width_m"], "T")
        w("\t{ %s, %s, %s, { %s } }," % (q(r["id"]), q(c), num(r["width_m"] * S), flat(r["pts"])))
    w("}")

    # rails
    w("L.rails = {")
    for r in d["railway"]:
        w("\t{ %s, %s, { %s } }," % (q(r["id"]), num(emb.get(r["id"], 0)), flat(r["pts"])))
    w("}")
    w("L.rcross = {")
    for c in d["rail_road_crossings"]:
        w("\t{ %s, %s, %s, %s }," % (q(c["road"]), q(c["rail"]), num(c["at"][0] * S), num(c["at"][1] * S)))
    w("}")

    # fences
    w("L.fences = {")
    for f in d["fences"]:
        w("\t{ %s, { %s } }," % (q(f["id"]), flat(f["pts"])))
    w("}")

    # forests
    w("L.forests = {")
    for f in d["forests"]:
        o = f["obb"]
        w("\t{ %s, %s, %s, %s, %s, %s, { %s } }," % (q(f["id"]), num(o[0] * S), num(o[1] * S), num(o[2] * S), num(o[3] * S), num(o[4]), flat(f["poly"])))
    w("}")
    rocks = d["rocks"]["items"]
    w("L.rocks = {")
    w(wrap([num(v * S) for r in rocks for v in r], 15, "\t"))
    w("}")

    # power
    w("L.power = {")
    for p in d["powerlines"]["lines"]:
        w("\t{ %s, { %s } }," % (q(p["id"]), flat(p["pts"])))
    w("}")
    w("L.towers = { %s }" % flat(d["powerlines"]["towers"]))

    # yards
    w("L.yards = {")
    for y in d["yards"]:
        w("\t{ %d, %s, %s, %s, %s, %s, %s, { %s } }," % (
            y["id"], q(YARD_NAMES.get(y["id"], y["name"].upper())), num(y["cx"] * S), num(y["cz"] * S), num(y["w"] * S), num(y["d"] * S), num(y["rot_deg"]), flat(y["outline"])))
    w("}")

    # buildings
    w("L.blds = {")
    for bd in d["buildings"]:
        h = YL(ROOF_Y[bd["id"]]) if bd["id"] in ROOF_Y else 0
        w("\t{ %d, %s, %s, %s, %s, %s, %s, %s, %d, %s, %d, %s }," % (
            bd["id"], q(BLD_NAMES[bd["id"]]), q(bd["kind"]), num(bd["cx"] * S), num(bd["cz"] * S), num(bd["w"] * S), num(bd["d"] * S),
            num(bd["rot_deg"]), bd["floors"], num(h), 1 if bd["basement"] else 0, q(bd["confidence"])))
    w("}")
    w("L.outline = {")
    for bd in d["buildings"]:
        if "outline" in bd:
            w("\t[%d] = { %s }," % (bd["id"], flat(bd["outline"])))
    w("}")
    for key, field in (("upper", "upper_floor_polys"), ("locked", "locked_rooms")):
        w("L.%s = {" % key)
        for bd in d["buildings"]:
            for u in bd.get(field, []):
                w("\t{ %d, %d, %s, %s, %s, %s, %s }," % (bd["id"], u["level"], num(u["cx"] * S), num(u["cz"] * S), num(u["w"] * S), num(u["d"] * S), num(u["rot_deg"])))
        w("}")

    # underground voids (terrain digs) and stairs
    ug = d["underground"]
    polys = ug["polygons"]
    ext = {e["name"]: e for e in ug["tarkov_dev_extents"]}

    def inside_ext(p, e):
        return e["x_min"] - 3 <= p["cx"] <= e["x_max"] + 3 and e["z_min"] - 3 <= p["cz"] <= e["z_max"] + 3

    voids = []
    names = {"zb-1011": ("K11", "BUNKER K-11", "tunnel"), "zb-1012": ("SH", "SMUGGLERS' HOLE", "tunnel"),
             "old gas": ("OP", "OLD PUMPS CELLAR", "room"), "switch basement": ("S4", "STORE 4 BASEMENT", "room"),
             "zb-013": ("K13", "BUNKER K-13", "room"), "boiler room": ("BC", "BOILER CELLAR", "room")}
    for key, (vid, nm, kind) in names.items():
        e = ext[key]
        match = [p for p in polys if inside_ext(p, e)]
        if key in ("old gas", "boiler room") or not match:
            # no usable polygon: the tarkov.dev extent box
            cx, cz = (e["x_min"] + e["x_max"]) / 2, (e["z_min"] + e["z_max"]) / 2
            vw, vd, rot = e["x_max"] - e["x_min"], e["z_max"] - e["z_min"], 0.0
        else:
            p = match[0]
            cx, cz, vw, vd, rot = p["cx"], p["cz"], p["w"] + 1.0, p["d"] + 1.0, p["rot_deg"]
        voids.append((vid, nm, kind, cx, cz, vw, vd, rot))
    w("L.under = {")
    for vid, nm, kind, cx, cz, vw, vd, rot in voids:
        w("\t{ %s, %s, %s, %s, %s, %s, %s, %s, -16, -4, 0 }," % (q(vid), q(nm), q(kind), num(cx * S), num(cz * S), num(vw * S), num(vd * S), num(rot)))
    w("}")
    w("L.stairs = {")
    for s in ug["stairs"]:
        w("\t{ %s, %d, %s, %s, %s, %s, %s }," % (q(s["id"]), s["level"], num(s["cx"] * S), num(s["cz"] * S), num(s["w"] * S), num(s["d"] * S), num(s["rot_deg"])))
    w("}")
    w("L.floors = {")
    for f in d["floor_extents"]:
        layer = {"2nd Floor": 2, "3rd Floor": 3, "4th Floor": 4}.get(f["layer"], 1)
        y1 = f["y_max"] if f["y_max"] < 900 else 999
        w("\t{ %d, %s, %s, %s, %s, %s, %s, %s }," % (layer, q(f["name"]), num(YL(f["y_min"])), num(YL(y1)) if y1 < 900 else "9999",
                                                     num(f["x_min"] * S), num(f["z_min"] * S), num(f["x_max"] * S), num(f["z_max"] * S)))
    w("}")
    w("L.labels = {")
    for lb in d["labels"]:
        w("\t{ %s, %s, %s }," % (q(LABEL_NAMES.get(lb["text"], lb["text"].upper())), num(lb["x"] * S), num(lb["z"] * S)))
    w("}")

    # extracts
    w("L.ext = {")
    missing = []
    for e in d["extracts"]:
        spec = EXTRACTS.get(e["name"])
        if not spec:
            missing.append(e["name"])
            continue
        eid, nm, grp, rule, size = spec
        grp = grp or e["entry_group"]
        rtxt = ", ".join("%s = %s" % (k, q(v) if isinstance(v, str) else num(v, 2)) for k, v in rule.items())
        note = (e["requirement"] or "")[:80]
        ex, ez = e["x"] * S, e["z"] * S
        # the whole zone must lie inside the invisible boundary: pull it in when the reference puts it on or past the limit
        ex, ez, moved = pull_inside(bpoly, ex, ez, size[0] / 2 + 2)
        if moved > 0.5:
            note = ("moved %s studs inward (reference position at or past the limit); " % num(moved, 0)) + note
            print("extract %s moved %.1f studs inward" % (eid, moved))
        w("\t{ %s, %s, %s, %s, %s, %d, %d, %d, { %s }, %s, %s }," % (
            q(eid), q(nm), q(grp), num(ex), num(ez), size[0], size[1], size[2], rtxt, q(e["confidence"]), q(note)))
    w("}")
    if missing:
        raise SystemExit("extracts without a name: %s" % missing)

    # spawns
    sp = d["spawns"]
    w("L.spawns = {")
    for side, key in (("east", "pmc_group_east"), ("west", "pmc_group_west")):
        w("\t%s = {" % side)
        vals = []
        for x, z, y, f in sp[key]["points"]:
            vals.append("{ %s, %s, %s, %s }" % (num(x * S), num(z * S), num(YL(y)), num(yaw_of(f), 0)))
        w(wrap(vals, 5, "\t\t"))
        w("\t},")
    w("}")
    w("L.clusters = {")
    for side, key in (("east", "pmc_group_east"), ("west", "pmc_group_west")):
        w("\t%s = {" % side)
        for c in sp[key]["clusters"]:
            w("\t\t{ %s, %s, %s, %s, %d, %s }," % (num(c["cx"] * S), num(c["cz"] * S), num(YL(c["y_min"])), num(YL(c["y_max"])), c["n"], c["building"] if c["building"] is not None else "false"))
        w("\t},")
    w("}")
    w("L.scav = {")
    for zid, z in sp["scav_zones"].items():
        bx = z["bbox"]
        def pts4(lst):
            return ", ".join("%s, %s, %s, %s" % (num(p[0] * S), num(p[1] * S), num(YL(p[2])), num(yaw_of(p[3]), 0)) for p in lst)
        w("\t{ %s, %s, %s, %s, %s, %s," % (q(zid), q(ZONE_NAMES[zid]), num(bx[0] * S), num(bx[1] * S), num(bx[2] * S), num(bx[3] * S)))
        w("\t\t{ %s }," % pts4(z["normal"]))
        w("\t\t{ %s }," % pts4(z["boss"]))
        w("\t\t{ %s } }," % pts4(z["pmc_bot"]))
    w("}")
    w("L.snipers = {")
    for s in sp["scav_snipers"]:
        w("\t{ %s, %s, %s, %s, %s, %s, %s }," % (q(s["zone"]), q(SNIPER_NAMES[s["zone"]]), num(s["x"] * S), num(s["z"] * S), num(YL(s["y"])), num(s["radius_m"] * S), s["building"] if s["building"] is not None else "false"))
    w("}")
    # bosses: ours only where the game has one (THE BROKER); the rest are logged gaps
    w("L.bosses = {")
    bz = {"ZoneDormitory": "ZoneDormitory", "ZoneGasStation": "ZoneGasStation", "ZoneScavBase": "ZoneScavBase"}
    for bs in d["bosses"]:
        ours = "THE BROKER" if bs["internal"] == "bossBully" else ""
        ch = {"bossBully": 0.4, "bossKnight": 0.2, "sectantPriest": 0.2, "bossPartisan": 0.15}.get(bs["internal"], 0.2)
        zl = ", ".join(q(z.split(" ")[0]) for z in bs["zones"])
        w("\t{ %s, %s, %s, { %s }, %s, %s }," % (q(bs["internal"]), q(ours), num(ch, 2), zl, q(bs["guards"][:60]), q("not built yet" if not ours else "THE BROKER and his crew")))
    w("}")
    _ = bz
    hz = d["hazards"]
    ad = hz["airdrop"]
    w("L.hazard = {")
    w("\tsniper = { %s }," % flat(hz["border_sniper"]["zone"]))
    w("\tflare = { %s, %s, %s }, -- the flare exit's area (position unknown in the reference: the north rail tip)" % (num(-10 * S), num(-245 * S), num(30 * S)))
    w("\tairdrop = { chance = %s, minPlayers = %d, first = { %d, %d }, cooldown = { %d, %d } }," % (num(ad["chance"], 2), ad["min_players"], ad["start_s"][0], ad["start_s"][1], ad["cooldown_s"][0], ad["cooldown_s"][1]))
    w("\traid = 2400,")
    w("\tmounted = {}, -- AGS and NSV positions are not in any source")
    w("\tpropane = {}, -- propane cylinder positions are not in any source")
    w("}")

    # relief knots
    w("L.relief = {")
    w(wrap([num(v) for k in knots for v in k], 12, "\t"))
    w("}")
    w("return L")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out) + "\n")
    print("wrote %s: %d lines, %d bytes; %d relief knots, %d river rows, embankments %s" % (
        OUT.relative_to(ROOT), len(out), len("\n".join(out)), len(knots), len(rows), {k: round(v, 1) for k, v in emb.items()}))


if __name__ == "__main__":
    sys.exit(main())

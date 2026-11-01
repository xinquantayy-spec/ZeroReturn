#!/usr/bin/env python3
"""Meridian Mall layout generator: docs/maps/reference/interchange_layout.json -> src/server/Maps/Meridian/Layout.luau.

Converts the Interchange reference (metres, x east, z south, game y) to map-local studs for the Meridian map (docs/maps/
MERIDIAN_INTERCHANGE_BUILD.md): S = 3.125 studs per metre, local y = (game y - 21.4) * S (0 = the flat ground and the car
park floor L0), and adds our names. Run from the repo root with:  python3 -I tools/interchange_layout.py
The output is compact data (flat arrays, positional records for the outside, named fields for the mall); the header of
Layout.luau says what every field is. The reference's own store names, labels and brands are never copied into the output
(only its record ids, which are internal): every name in Layout.luau is ours, and the stores that the spec does not name
carry name = "" for the stores agents to fill.
"""
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/maps/reference/interchange_layout.json"
OUT = ROOT / "src/server/Maps/Meridian/Layout.luau"
S = 3.125
GROUND = 21.4  # game y of the flat ground (and of the car park floor)

# ── names (the layout is Interchange's, the names are ours: docs/maps/MERIDIAN_INTERCHANGE_BUILD.md) ─────────────
BLD_NAMES = {
    0: "SUBSTATION YARD SHED B", 1: "SUBSTATION YARD SHED A", 2: "NESTA TOWER BASE", 3: "RAILSIDE HUT", 4: "NORTH SHED A",
    5: "THE SUBSTATION", 6: "NORTH SHED B", 7: "SUBSTATION SHED 1", 8: "SUBSTATION SHED 2", 9: "SUBSTATION SHED 3",
    10: "SUBSTATION SHED 4", 11: "SUBSTATION SHED 5", 12: "SUBSTATION SHED 6", 13: "KART PIT HOUSE",
    14: "HIGHWAY BOOTH 1", 15: "HIGHWAY BOOTH 2", 16: "HIGHWAY BOOTH 3", 17: "EAST HUT 1", 18: "EAST HUT 2", 19: "EAST HUT 3",
    20: "LOT BOOTH", 21: "EAST HUT 4", 22: "ROADSIDE BOOTH", 23: "HIGHWAY BOOTH 4", 24: "HIGHWAY BOOTH 5", 25: "HIGHWAY BOOTH 6",
    26: "HIGHWAY BOOTH 7", 27: "SHELTER VESTIBULE", 28: "WEST CAMP HUT 1", 29: "WEST CAMP HUT 2", 30: "WEST CAMP HUT 3",
    31: "WALL BREAK HUT", 32: "WEST CAMP HUT 4", 33: "WEST CAMP HUT 5", 34: "WEST CAMP HUT 6", 35: "WEST CAMP HUT 7",
    36: "WEST CAMP HUT 8", 37: "WEST CAMP HUT 9", 38: "WEST CAMP HUT 10", 39: "RESCUE CAMP TENT 1", 40: "RESCUE CAMP CONTAINER 1",
    41: "BOLTWORKS TOWER BASE", 42: "RESCUE CAMP TENT 2", 43: "RESCUE CAMP TENT 3", 44: "RESCUE CAMP CONTAINER 2",
    45: "RESCUE CAMP CONTAINER 3", 46: "RESCUE CAMP TENT 4", 47: "RESCUE CHECKPOINT OFFICE", 48: "RESCUE CAMP CONTAINER 4",
    49: "RESCUE CHECKPOINT GUARDHOUSE",
}
# what Outside builds each footprint as: sub (substation main), shed, booth, hut, camp (west camp hut), rescue (rescue camp
# tent or container), check (rescue checkpoint building), tower (sign pylon base), kart (pit house), mall (inside the mall:
# the shell's), rail (the railside hut)
BLD_GRP = {5: "sub", 2: "tower", 41: "tower", 13: "kart", 27: "mall", 3: "rail", 47: "check", 49: "check"}
for i in (0, 1, 7, 8, 9, 10, 11, 12, 4, 6):
    BLD_GRP[i] = "shed"
for i in (14, 15, 16, 20, 22, 23, 24, 25, 26):
    BLD_GRP[i] = "booth"
for i in (17, 18, 19, 21, 31):
    BLD_GRP[i] = "hut"
for i in (28, 29, 30, 32, 33, 34, 35, 36, 37, 38):
    BLD_GRP[i] = "camp"
for i in (39, 40, 42, 43, 44, 45, 46, 48):
    BLD_GRP[i] = "rescue"
YARD_NAMES = {
    0: "NORTH SERVICE YARD", 1: "SUBSTATION APRON", 2: "NESTA DOCK APRON", 3: "SUBSTATION PAD 1", 4: "SUBSTATION PAD 2",
    5: "SUBSTATION PAD 3", 6: "SUBSTATION PAD 4", 7: "CARGO YARD EAST", 8: "KART PAD", 9: "KART TRACK", 10: "WEST LOT 2",
    11: "WEST LOT 3", 12: "WEST LOT 4", 13: "WEST LOT 5", 14: "WEST LOT 6", 15: "CARGO YARD WEST", 16: "EAST SERVICE LANE",
    17: "EAST TRUCK LOT", 18: "BOLTWORKS DOCK APRON", 19: "NORTH ACCESS PAD", 20: "WEST CAMP PAD",
}
# surface of each pad: A asphalt, C concrete
YARD_SURF = {8: "A", 10: "A", 11: "A", 12: "A", 13: "A", 14: "A", 17: "A"}
# the five west car parks get painted bays
YARD_LOT = {10, 11, 12, 13, 14}
OUT_LABELS = {
    "Power Station": "THE SUBSTATION", "Go Kart": "KART TRACK", "Four Camp": "WEST LOT 3", "Cargo Containers": "CARGO YARDS",
    "Wall Break": "WALL BREAK", "Ramps": "DOCK RAMPS", "Oli Tower": "BOLTWORKS TOWER", "Idea Tower": "NESTA TOWER",
    "Scav Camp": "HIGHWAY CAMP", "Highway Construction": "HIGHWAY WORKS",
    "Garage A": "CAR PARK A", "Garage B": "CAR PARK B", "Garage C": "CAR PARK C", "Garage D": "CAR PARK D",
}
# mall records the spec names (by reference id); every other store keeps name = "" for the stores agents
STORE_NAMES = {
    "L0_garage_a_central_parking_north_hall": "CAR PARK A", "L0_garage_b_central_parking": "CAR PARK B",
    "L0_garage_c_central_parking": "CAR PARK C", "L0_garage_d_central_parking_south": "CAR PARK D",
    "L0_idea_garage": "NESTA GARAGE", "L0_goshan_garage": "KASSA GARAGE", "L0_oli_garage": "BOLTWORKS GARAGE",
    "L0_scav_camp_tunnel_co_op_extract": "SERVICE TUNNEL", "L0_saferoom_exfil_room": "THE SHELTER",
    "L0_object_14_container_room": "UNIT 14",
    "L1_idea": "NESTA", "L1_idea_bistro": "NESTA CANTEEN", "L1_goshan": "KASSA", "L1_oli": "BOLTWORKS",
    "L1_kiba": "IRONSIGHT", "L1_emercom": "RESCUE POINT",
    "L2_techlight": "VOLTA", "L2_apteka": "MEDIQ", "L2_ultra_med_locked_room": "MEDIQ STORE ROOM",
}
ZONE_NAMES = {
    "ZoneCenter": "CENTRAL MALL", "ZoneCenterBot": "CENTRAL CONCOURSE", "ZoneGoshan": "KASSA HALL", "ZoneIDEA": "NESTA HALL",
    "ZoneIDEAPark": "NESTA PARK", "ZoneOLI": "BOLTWORKS HALL", "ZoneOLIPark": "BOLTWORKS PARK", "ZonePowerStation": "SUBSTATION",
    "ZoneRoad": "RING ROAD", "ZoneTrucks": "TRUCK YARDS",
}
# reference extract name -> (id, our name, spawn group, rule, zone size (x, y, z) in studs, note). Groups: nw / se = the PMC
# entry half that is OFFERED the extract in the SPT data (MallNW spawners are offered the south-east exit, MallSE spawners
# the north-west one; the 2026 sources call both corner exits neutral: Play decides), both, scav = scav-only. Rule kinds are
# World's extract rules: open | paid (cost; a car also has chance, seats, depart) | key (key) | chance (chance) | power (switch, needs) | scav, plus nobag (new:
# the backpack slot must be empty).
EXTRACTS = {
    "Railway Exfil": ("RS", "RAIL SIDING", "se", {"kind": "open"}, (30, 12, 30),
                      "north-west corner beside the west double railway; SPT offers it to MallSE spawners, 2026 sources: both"),
    "Emercom Checkpoint": ("RC", "RESCUE CHECKPOINT", "nw", {"kind": "open"}, (30, 12, 30),
                           "south-east corner beside the checkpoint buildings; SPT offers it to MallNW spawners, 2026 sources: both"),
    "Power Station V-Ex": ("SC", "SUBSTATION CAR", "both", {"kind": "paid", "cost": 20000, "chance": 0.5, "seats": 4, "depart": 60}, (26, 12, 26),
                           "north-east corner by the sniper band; a car: 50% chance (SPT), 4 seats, 60 s shared timer; 20000 is the 2026 figure (SPT/wiki 5000); karma pricing is a gap"),
    "Saferoom Exfil": ("SE", "SHELTER EXIT", "both",
                       {"kind": "power", "switch": "MALL_POWER", "needs": "NO POWER  ·  THROW THE SWITCH AT THE SUBSTATION"}, (16, 10, 16),
                       "hidden room east of car park C; after power: the hidden switch in the L2 washroom (poi.WASHROOM) and the keycard at the panel, door at poi.SHELTER_DOOR; power is the only rule World supports"),
    "Scav Camp (Co-Op)": ("WC", "WEST CAMP", "scav", {"kind": "scav"}, (22, 10, 22),
                          "reference position is the service tunnel between car park B/C and the KASSA garage (NOT the west camp huts): co-op (scav + PMC) becomes scav-only; the spec name is kept"),
    "Path to River (flare)": ("RP", "RIVER PATH", "both", {"kind": "open"}, (28, 12, 28),
                              "far west edge on the dirt road past the highway; the flare is a gap (plain open exit); likely flare spot poi.FLARE_SPOT"),
    "Hole in the Fence": ("FG", "FENCE GAP", "both", {"kind": "nobag"}, (24, 10, 24),
                          "grade D: behind the NESTA hall on the east service lane in the 46 m fence gap; the backpack slot must be empty (kind nobag is new)"),
}
BOSS_NAMES = {"bossKilla": "THE CARETAKER"}
BOSS_CHANCE = {"bossKilla": 0.6, "bossTagilla": 0.35}
ICON_WHERE = {
    "IDEA hall": "NESTA hall", "central block concourse": "central concourse", "Goshan hall": "KASSA hall", "OLI hall": "BOLTWORKS hall",
    "upper floor central corridor": "upper floor central corridor",
}
# keys: item id, our name, what it opens (ours), level, reference position (x, z) metres or None, needs mall power, the item
# already exists in src/shared/Items.luau, note
KEYS = [
    ("KEY_MM_IRON_FRONT", "IRONSIGHT front door key", "IRONSIGHT front door", "L1", (90.0, -29.0), True, False, "the door lock icon on the plan; the alarm sounds about 3 s after the door opens (poi.IRON_ALARM)"),
    ("KEY_MM_IRON_GRATE", "IRONSIGHT back grate key", "IRONSIGHT inner grate (the weapon room)", "L1", (98.8, -20.8), True, False, "needs the front door first"),
    ("KEY_MM_RESCUE", "RESCUE POINT key", "RESCUE POINT: three doors N (59,-104), E (72,-97), W (49,-101)", "L1", (49.0, -98.0), False, False, "each opening costs a use"),
    ("KEY_MEDIQ", "MEDIQ Dispensary Key", "MEDIQ STORE ROOM (L2)", "L2", (10.3, 18.8), True, True, "the door itself is not drawn; the shop MEDIQ lies 33 m south"),
    ("KEY_VOLTA_STORE", "VOLTA Store Room Key", "VOLTA stock room (L2)", "L2", (-11.7, 58.8), False, True, "not in the reference's 16 keys (the spec adds it)"),
    ("KEY_MM_NESTA_REG", "NESTA register key", "NESTA cash registers (about 20)", "L1", (52.0, -241.0), False, False, "key spawn tile on the plan"),
    ("KEY_MM_KASSA_REG", "KASSA register key", "KASSA cash registers (about 27)", "L1", (163.0, -18.0), False, False, "key spawn tile on the plan"),
    ("KEY_MM_BOLT_REG", "BOLTWORKS register key", "BOLTWORKS cash registers (about 18)", "L1", (4.0, 160.0), False, False, "in the west offices"),
    ("KEY_MM_BOLT_OFFICE", "BOLTWORKS OFFICE key", "BOLTWORKS OFFICE (administration)", "L1", (4.0, 160.0), False, False, "west offices x -12..20, z 130..190, grade D"),
    ("KEY_MM_BOLT_GOODS", "BOLTWORKS GOODS-IN key", "BOLTWORKS GOODS-IN (logistics)", "L1", (4.0, 160.0), False, False, "west offices, grade D"),
    ("KEY_MM_SUBSTATION", "SUBSTATION utility room key", "THE SUBSTATION utility room (a loot room, not the switch room)", "outside", (288.3, -346.2), False, False, "Outside builds the room and its door (id SUB_UTILITY)"),
    ("CARD_MALL_VAULT", "Savings Vault Keycard", "the hidden keycard panel in the L2 washroom (opens the SHELTER door)", "L2", (115.0, -92.0), True, True, "reuse for the Saferoom card (Object #11SR in the reference); update the item text"),
    ("KEY_MM_UNIT14", "UNIT 14 keycard", "UNIT 14 container room", "L0", (11.0, -250.0), True, False, "the reference opens it with a lever inside the SHELTER; the spec wants a card"),
    ("KEY_MALL_SECURITY", "Mall Security Key", "SECURITY ROOM with the alarm terminal (L1 near (190,75), grade D)", "L1", (190.0, 75.0), False, True, "kept: the reference has a security-room terminal that stops the IRONSIGHT alarm"),
    ("KEY_MALL_STAFF", "Meridian Staff Key", "STAFF DOOR of the NESTA CANTEEN kitchen / the L2 food court kitchen", "L2", (99.0, -92.0), False, True, "kept: a staff door has no reference position; the stores agent places it"),
]


# ── helpers ───────────────────────────────────────────────────────────────────────────────────────────────────────
def num(v, nd=1):
    """Short number text: rounded, no trailing zeros, no -0."""
    r = round(v, nd)
    if r == 0:
        return "0"
    if r == int(r):
        return str(int(r))
    return ("%." + str(nd) + "f") % r


def YL(g):
    return (g - GROUND) * S


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
    The reference puts some extract icons on or past the traced limit (grades B and C are good to 5 to 25 m); the invisible
    boundary walls would make such an extract unreachable."""
    x0, z0 = x, z
    for _ in range(12):
        d, (px, pz) = poly_edge(poly, x, z)
        if d >= need:
            break
        if d < 0:
            ux, uz = px - x, pz - z
        else:
            ux, uz = x - px, z - pz
        l = math.hypot(ux, uz)
        if l < 1e-6:
            break
        x, z = px + ux / l * need, pz + uz / l * need
    return x, z, math.hypot(x - x0, z - z0)


def flat(pts, nd=1):
    """x,z pairs (metres) -> flat studs text body."""
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
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def yaw_of(facing_deg):
    """reference facing (0 east, 90 south, degrees) -> Roblox yaw (CFrame.Angles(0, rad(yaw), 0): 0 north, 90 west)."""
    f = math.radians(facing_deg)
    return math.degrees(math.atan2(-math.cos(f), -math.sin(f)))


def area2(pts):
    a = 0.0
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        a += pts[i][0] * pts[j][1] - pts[j][0] * pts[i][1]
    return a / 2


def fl(p):
    return [c for pt in p for c in pt]


# ── relief knots from the spawn-point heights ─────────────────────────────────────────────────────────────────────
def build_relief(d):
    """Knots [x, z, y, sigma] in studs for the Gaussian-weighted relief field. Samples within 0.8 m of the plain are dropped,
    the rest merge per 8 m cell. sigma by height: deep lowland 32 m, rises 26 m, shallow dips 15 m."""
    keep = []
    for x, z, y in d["relief"]["samples"]:
        dev = y - GROUND
        if abs(dev) < 0.8:
            continue
        keep.append((x, z, dev))
    cells = {}
    for x, z, dev in keep:
        cells.setdefault((int(x // 8), int(z // 8)), []).append((x, z, dev))
    knots = []
    for pts in cells.values():
        cx = sum(p[0] for p in pts) / len(pts)
        cz = sum(p[1] for p in pts) / len(pts)
        dv = sum(p[2] for p in pts) / len(pts)
        if dv <= -4.5:
            sg = 32.0  # the north-west lowland
        elif dv >= 1.5:
            sg = 26.0  # the south-east bank
        else:
            sg = 15.0  # dips and low spots
        knots.append((cx * S, cz * S, dv * S, sg * S))
    knots.sort(key=lambda k: (round(k[1]), round(k[0])))
    return knots


def outer_limit(d):
    """The outer limit polygon in metres, clockwise on a north-up map from the north-west corner: the north 'Limit' chain with
    its tabs, the OUTER edge of the east sniper band, the south 'Limit' chain and the OUTER edge of the west minefield band.
    The bands are lethal but walkable, so the invisible walls stand outside them."""
    b = d["boundary"]
    mw = [tuple(p) for p in b["minefield_west"]["poly"]]  # 0 inner north end, 1..19 the outer chain north to south, 20.. inner
    sn = [tuple(p) for p in b["sniper_east"]["poly"]]  # 0..10 the outer chain south to north, then the inner chain
    north = [tuple(p) for p in b["limit_north"]]  # (-446.3,-408.7) ... (413.4,-412.9)
    south = [tuple(p) for p in b["limit_south"]]  # (477.8,261.3) ... (-63.0,405.1), (-449.9,405.2)
    pts = [mw[1]]  # the minefield's north-west corner, then east along its north edge (z -408.6) onto the north chain
    pts += north
    pts += list(reversed(sn[:11]))  # (421.9,-413) down the outer edge of the sniper band to (503.7,261.3)
    pts += south[:-1]  # west along the south limit to (-63,405.1)
    pts += [mw[19]]  # (-476, 405.2): the minefield's south-west corner
    pts += [mw[i] for i in range(18, 1, -1)]  # up the outer edge of the minefield band
    return pts


def poly_inside(poly_flat, x, z):
    """Inside or within 1.5 studs of the edge (the inner and outer polygons share the north and south limit lines to 0.1 m)."""
    d, _ = poly_edge(poly_flat, x, z)
    return d >= -1.5


# ── main ──────────────────────────────────────────────────────────────────────────────────────────────────────────
def main():
    d = json.loads(SRC.read_text(encoding="utf-8"))
    out = []
    w = out.append

    # ── geometry shared by several sections ──
    inner = d["boundary"]["poly"]
    limit = outer_limit(d)
    inner_s = [c * S for p in inner for c in p]
    limit_s = [c * S for p in limit for c in p]
    if area2(limit) < 0:
        limit = list(reversed(limit))
        limit_s = [c * S for p in limit for c in p]
    bad = [p for p in inner if not poly_inside(limit_s, p[0] * S, p[1] * S)]
    if bad:
        raise SystemExit("inner boundary points outside the outer limit: %s" % bad)
    xs = [p[0] for p in inner]
    zs = [p[1] for p in inner]
    box = (min(xs) * S, min(zs) * S, max(xs) * S, max(zs) * S)
    lxs = [p[0] for p in limit]
    lzs = [p[1] for p in limit]
    lbox = (min(lxs) * S, min(lzs) * S, max(lxs) * S, max(lzs) * S)
    knots = build_relief(d)
    m = d["mall"]
    y1, y2 = YL(m["heights"]["y_L1"]), YL(m["heights"]["y_L2"])

    w("--!nonstrict")
    w("-- GENERATED by tools/interchange_layout.py from docs/maps/reference/interchange_layout.json. Do not edit by hand: change")
    w("-- the tool and run  python3 -I tools/interchange_layout.py  from the repo root.")
    w("-- Meridian Mall layout (the Interchange layout, our names) in MAP-LOCAL STUDS: x east, z south (north = -z), origin = the")
    w("-- centre of the reference's 1031 x 868 m bounds, S = 3.125 studs per metre. Heights are local y: 0 = the flat ground and")
    w("-- the car park floor L0 (game y 21.4), y = (game y - 21.4) x S. Add the map origin (B.O; MapKit's H.V) for world coords.")
    w("-- Ids are the reference's, for traceability only (never show one to a player). Accuracy grade conf: A footprint traced,")
    w("-- B matched, C inferred, D unknown (docs/maps/reference/INTERCHANGE_REFERENCE.md, section 1). The reference is a layout")
    w("-- guide: no store name, label or brand of the original appears here; name = \"\" means the stores agents name it.")
    w("-- Rotations: rot = angle of the long (w) side from +x toward +z in degrees (-90..90); place a box with")
    w("--   CFrame.new(cx, y, cz) * CFrame.Angles(0, -math.rad(rot), 0)  and Size (w, height, d)   (H.CF takes -rot in degrees).")
    w("--   rot 0 = the long side runs east-west, 90 = north-south. yaw = Roblox yaw in degrees (CFrame.Angles(0, math.rad(yaw), 0):")
    w("--   0 faces north, 90 west, 180 south, -90 east). Flat arrays are x, z, x, z ... (or the stride named below); polygons are")
    w("--   closed implicitly (the first point is not repeated).")
    w("-- OUTSIDE (positional records, as Border Yard's Layout):")
    w("--   S, H, box {x0, z0, x1, z1}       scale; heights {ground, L1, L2, ceil = {L0, L1, L2}, roof, slab}; bbox of boundary")
    w("--   boundary, limit, pre             boundary = the PLAYABLE polygon (inside the minefield and sniper bands); limit = the")
    w("--                                    OUTER limit (outside both bands): the invisible walls stand on it, players may enter the")
    w("--                                    bands (lethal, Play's job); pre = the pre-1.0 playable polygon (older spawn data);")
    w("--                                    lbox = bbox of limit")
    w("--   mine {poly, inner}, snipe {...}  west minefield band and east sniper band: poly = the whole band, inner = the edge toward")
    w("--                                    the playable area (flat x, z, an open polyline)")
    w("--   relief {x, z, dy, sigma, ...}    flat knots (stride 4): deviation from the ground in studs, Gaussian width sigma (studs);")
    w("--                                    samples {x, z, dy, ...} = the 155 raw spawn-height samples (stride 3, studs)")
    w("--   water {id, kind, depth, cx, cz, w, d, rot, pts}   13 ponds and the east canal (kind pond | canal); Ground digs ditches")
    w("--   rockFields {id, area, pts}, rocks flat x, z, r (stride 3)   19 rock fields (area in m2) and 42 boulders")
    w("--   roads {id, surf, w, pts}         surf H highway, T tarmac, G gravel track; w = width in studs; closed loops repeat point 1")
    w("--   rails {id, out, pts}             out = 1: lies outside the limit (the two south border rails)")
    w("--   fences {id, pts}                 open polylines; power {id, pts} lines, towers flat x, z (23)")
    w("--   yards {id, name, surf, cx, cz, w, d, rot, lot, pts}   pads (surf A asphalt, C concrete; lot = 1: a west car park with")
    w("--                                    painted bays); pts = the traced outline")
    w("--   blds {id, name, kind, grp, cx, cz, w, d, rot, floors, conf}   50 outdoor footprints; grp = what Outside builds (sub,")
    w("--                                    shed, booth, hut, camp, rescue, check, tower, kart, rail; mall = the shell's)")
    w("--   labels {name, x, z}              our names for the outdoor places and the four car park zones")
    w("--   poi {NAME = {x, z, note}}        named reference points (the switch, the alarm, the shelter door, the flare spot ...)")
    w("--   ext {id, name, grp, x, z, sx, sy, sz, rule = {kind=...}, conf, note}   extracts: grp se / nw = the PMC entry half that is")
    w("--                                    offered it (SPT), both, scav; rule as World's extract rules (nobag is new)")
    w("--   pmc {nw, se}                     every SPT PMC spawn point {x, z, y, yaw}; clusters {nw, se} = the 5-point groups")
    w("--                                    {cx, cz, y, n}; rings {x, z, grp, strip, spt}: the 25 PMC spawn rings of 2026 (grp nw | se,")
    w("--                                    strip = 1 when outside the pre-1.0 area, spt = 1 when an SPT site lies within 25 m)")
    w("--   scav {id, name, x0, z0, x1, z1, normal, boss, bot}   scav zones; the three lists are flat x, z, y, yaw (stride 4); bot =")
    w("--                                    the AI-PMC points; aiIcons {x, z, level} the 2026 AI scav icons")
    w("--   bosses {id, ours, chance, zones, icons, note}   icons {x, z, level, where}")
    w("--   hazard {mine, snipe, ironAlarm, airdrop, raid, mounted, propane}")
    w("-- THE MALL (named fields), L.mall:")
    w("--   box, outline (22 pts, the ground footprint), outL1, outL2 (the upper volumes), y {L0, L1, L2}, ceil, roof")
    w("--   levels[1..3] = {key, y, ceil, area, floor (flat outline), stores, corr, walls, ...}; store = {id, name, kind, cx, cz, w, d,")
    w("--      rot, pts, ent = {{side, x, z, w}, ...}, conf}: the reference's rectangle of each unit; its ENTRANCES are gaps in the")
    w("--      wall mask (side N/S/E/W of the rectangle, centre, width; a width over 12 m is an open front); name = ours or \"\"")
    w("--   corr {cx, cz, w, d, rot, axis}  free rectangles of walkable floor (galleries, concourses); walls {id, kind, cx, cz, w, d,")
    w("--      rot, pts}  wall, partition_or_small_block and block_or_void polygons of the plans")
    w("--   vert {id, kind, joins, w, x0, z0, x1, z1, run, rise, conf} stairs, escalators, ramps (x0, z0 = low end, x1, z1 = high end);")
    w("--      icons carry at = {x, z}; atria (octagon domes, joins L1 and L2), voids (L2 floor openings), docks, service, terraces, pads")
    w("-- GAMEPLAY: keys {id, name, opens, level, x, z, power, exists, note} (exists = the item is already in Items.luau), poi.")
    w("local L = {}")
    w("L.S = %s" % num(S, 3))
    w("L.H = { ground = 0, L1 = %s, L2 = %s, ceil = { %s, %s, %s }, roof = %s, slab = 1.6 }" % (
        num(y1, 2), num(y2, 2), num((m["levels"][0]["y_ceiling"] - GROUND) * S, 2), num((m["levels"][1]["y_ceiling"] - GROUND) * S, 2),
        num(y2 + 20, 2), num(y2 + 21.6, 2)))
    w("L.box = { %s, %s, %s, %s }" % tuple(num(v) for v in box))
    w("L.lbox = { %s, %s, %s, %s }" % tuple(num(v) for v in lbox))
    w("L.boundary = {\n%s\n}" % flat_block(inner))
    w("L.limit = {\n%s\n}" % flat_block(limit))
    w("L.pre = {\n%s\n}" % flat_block(d["boundary"]["pre_1_0_polygon"]["poly"]))
    mf, sn = d["boundary"]["minefield_west"], d["boundary"]["sniper_east"]
    w("L.mine = {\n\tpoly = {\n%s\n\t},\n\tinner = {\n%s\n\t},\n}" % (flat_block(mf["poly"], indent="\t\t\t"), flat_block(mf["inner_edge"], indent="\t\t\t")))
    w("L.snipe = {\n\tpoly = {\n%s\n\t},\n\tinner = {\n%s\n\t},\n}" % (flat_block(sn["poly"], indent="\t\t\t"), flat_block(sn["inner_edge"], indent="\t\t\t")))

    # relief
    w("L.relief = {")
    w(wrap([num(v) for k in knots for v in k], 12, "\t"))
    w("}")
    w("L.samples = {")
    w(wrap([num(v) for x, z, y in d["relief"]["samples"] for v in (x * S, z * S, (y - GROUND) * S)], 12, "\t"))
    w("}")

    # water
    w("L.water = {")
    for wt in d["water"]:
        kind = "canal" if wt["area_m2"] > 5000 else "pond"
        depth = 8 if kind == "canal" else 5
        w("\t{ %s, %s, %d, %s, %s, %s, %s, %s, { %s } }," % (
            q(wt["id"]), q(kind), depth, num(wt["cx"] * S), num(wt["cz"] * S), num(wt["w"] * S), num(wt["d"] * S), num(wt["rot_deg"]), flat(wt["poly"])))
    w("}")
    w("L.rockFields = {")
    for r in d["rocks"]["big"]:
        w("\t{ %s, %d, { %s } }," % (q(r["id"]), r["area_m2"], flat(r["poly"])))
    w("}")
    w("L.rocks = {")
    w(wrap([num(v * S) for r in d["rocks"]["items"] for v in r], 15, "\t"))
    w("}")

    # roads
    w("L.roads = {")
    for r in d["roads"]:
        c = {"gravel": "G", "tarmac": "T", "tarmac_highway": "H"}[r["surface"]]
        pts = list(r["pts"])
        if r["closed"]:
            pts.append(pts[0])
        w("\t{ %d, %s, %s, { %s } }," % (r["id"], q(c), num(r["width_m"] * S), flat(pts)))
    w("}")
    # rails
    w("L.rails = {")
    for r in d["railway"]:
        outside = all(not poly_inside(limit_s, p[0] * S, p[1] * S) for p in r["pts"])
        w("\t{ %s, %d, { %s } }," % (q(r["id"]), 1 if outside else 0, flat(r["pts"])))
    w("}")
    w("L.fences = {")
    for f in d["fences"]:
        pts = list(f["pts"])
        if f["closed"]:
            pts.append(pts[0])
        w("\t{ %s, { %s } }," % (q(f["id"]), flat(pts)))
    w("}")
    w("L.power = {")
    for p in d["powerlines"]["lines"]:
        w("\t{ %s, { %s } }," % (q(p["id"]), flat(p["pts"])))
    w("}")
    w("L.towers = { %s }" % flat(d["powerlines"]["towers"]))

    # yards
    w("L.yards = {")
    for y in d["yards"]:
        surf = YARD_SURF.get(y["id"], "C")
        w("\t{ %d, %s, %s, %s, %s, %s, %s, %s, %d, { %s } }," % (
            y["id"], q(YARD_NAMES[y["id"]]), q(surf), num(y["cx"] * S), num(y["cz"] * S), num(y["w"] * S), num(y["d"] * S),
            num(y["rot_deg"]), 1 if y["id"] in YARD_LOT else 0, flat(y["outline"])))
    w("}")
    # buildings
    w("L.blds = {")
    for bd in d["buildings"]:
        w("\t{ %d, %s, %s, %s, %s, %s, %s, %s, %s, %d, %s }," % (
            bd["id"], q(BLD_NAMES[bd["id"]]), q(bd["kind"]), q(BLD_GRP[bd["id"]]), num(bd["cx"] * S), num(bd["cz"] * S), num(bd["w"] * S),
            num(bd["d"] * S), num(bd["rot_deg"]), bd["floors"], q(bd["confidence"])))
    w("}")
    w("L.labels = {")
    for lb in d["labels"]:
        if lb["text"] in OUT_LABELS:
            w("\t{ %s, %s, %s }," % (q(OUT_LABELS[lb["text"]]), num(lb["x"] * S), num(lb["z"] * S)))
    w("}")

    # points of interest: positions in the reference that gameplay needs (metres -> studs); notes are ours
    poi = [
        ("SUBSTATION_SWITCH", 288.3, -346.2, "the power switch inside THE SUBSTATION main building (grade B, +-15 m); Outside builds the real one, B.points.SUBSTATION_SWITCH"),
        ("SHELTER_DOOR", 132.0, 55.0, "padlocked door of THE SHELTER on L0 in car park C"),
        ("SHELTER_ICON", 164.0, 24.7, "the extract icon inside the shelter"),
        ("UNIT14_PADLOCK", 11.0, -250.0, "padlock of UNIT 14 (L0, car park A side)"),
        ("IRON_ALARM", 98.8, -20.8, "IRONSIGHT store alarm (grade C)"),
        ("SECURITY_L1", 190.0, 75.0, "alarm terminal star, L1 (grade D, +-30 m)"),
        ("SECURITY_L2", 127.0, -45.0, "alarm terminal star, L2 (grade D, +-30 m)"),
        ("FLARE_SPOT", -428.0, 90.0, "most likely flare spot: the dirt road crossing the N-S gravel track between the two power lines (grade C)"),
        ("YARD_CONTAINER", -58.0, 285.0, "south-west container yard centre: the locked weapon container of the reference (Terragroup)"),
        ("FENCE_GAP", 303.0, -70.0, "the 46 m gap in the east service lane fence (fence_18 / fence_19), z -91..-45"),
        ("COOP_TUNNEL", 175.9, -67.1, "service tunnel (L0): the reference's co-op extract icon"),
        ("WASHROOM", 115.0, -92.0, "centre of the L2 rectangle x 97.5..133, z -99..-85 (the washroom with the hidden switch; exact spot unknown, grade D)"),
        ("OLD_SCAV_CAMP", -180.7, -3.1, "label position of the old scav camp by the highway booths"),
    ]
    w("L.poi = {")
    for name, x, z, note in poi:
        w("\t%s = { %s, %s, %s }," % (name, num(x * S), num(z * S), q(note)))
    w("}")

    # ── the mall ──
    w("L.mall = {")
    mb = m["bbox"]
    w("\tbox = { %s, %s, %s, %s }," % (num(mb[0] * S), num(mb[1] * S), num(mb[2] * S), num(mb[3] * S)))
    w("\toutline = { %s }," % flat(m["outline"]))
    w("\toutL1 = { %s }," % flat(m["outline_L1"]))
    w("\toutL2 = { %s }," % flat(m["outline_L2"]))
    w("\ty = { 0, %s, %s }," % (num(y1, 2), num(y2, 2)))
    w("\tceil = { %s, %s, %s }," % (num((m["levels"][0]["y_ceiling"] - GROUND) * S, 2), num((m["levels"][1]["y_ceiling"] - GROUND) * S, 2), num(y2 + 20, 2)))
    w("\troof = %s," % num(y2 + 21.6, 2))
    w("\tlevels = {")
    n_store = 0
    n_named = 0
    for lv in m["levels"]:
        w("\t\t{")
        w("\t\t\tkey = %s, y = %s, ceil = %s, area = %d," % (
            q(lv["key"]), num(YL(lv["y_floor"]), 2), "nil" if lv["y_ceiling"] is None else num(YL(lv["y_ceiling"]), 2), lv["area_m2"]))
        w("\t\t\tfloor = {\n%s\n\t\t\t}," % flat_block(lv["floor_outline"], indent="\t\t\t\t"))
        w("\t\t\tstores = {")
        for s in lv["stores"]:
            name = STORE_NAMES.get(s["id"], "")
            n_store += 1
            if name:
                n_named += 1
            ent = ", ".join("{ %s, %s, %s, %s }" % (q(e["side"]), num(e["at"][0] * S), num(e["at"][1] * S), num(e["width"] * S)) for e in s.get("entrances", []))
            w("\t\t\t\t{ id = %s, name = %s, kind = %s, cx = %s, cz = %s, w = %s, d = %s, rot = %s, conf = %s,\n\t\t\t\t  pts = { %s },\n\t\t\t\t  ent = { %s } }," % (
                q(s["id"]), q(name), q(s["kind"]), num(s["cx"] * S), num(s["cz"] * S), num(s["w"] * S), num(s["d"] * S), num(s["rot_deg"]),
                q(s["confidence"]), flat(s["outline"]), ent))
        w("\t\t\t},")
        w("\t\t\tcorr = {")
        for c in lv["corridors"]:
            w("\t\t\t\t{ cx = %s, cz = %s, w = %s, d = %s, rot = %s, axis = %s }," % (
                num(c["cx"] * S), num(c["cz"] * S), num(c["w"] * S), num(c["d"] * S), num(c["rot_deg"]), q(c["axis"])))
        w("\t\t\t},")
        w("\t\t\twalls = {")
        for b in lv.get("walls_and_blocks") or []:
            kind = {"partition_or_small_block": "small", "wall": "wall", "block_or_void": "block"}[b["kind"]]
            w("\t\t\t\t{ id = %s, kind = %s, cx = %s, cz = %s, w = %s, d = %s, rot = %s, pts = { %s } }," % (
                q(b["id"]), q(kind), num(b["cx"] * S), num(b["cz"] * S), num(b["w"] * S), num(b["d"] * S), num(b["rot_deg"]), flat(b["outline"])))
        w("\t\t\t},")
        w("\t\t},")
    w("\t},")

    # vertical circulation (unique across levels)
    seen = set()
    w("\tvert = {")
    for lv in m["levels"]:
        for v in lv["vertical"]:
            if v["id"] in seen:
                continue
            seen.add(v["id"])
            joins = "{ %s }" % ", ".join(q(j) for j in v["joins"])
            if v.get("low"):
                w("\t\t{ id = %s, kind = %s, joins = %s, w = %s, x0 = %s, z0 = %s, x1 = %s, z1 = %s, run = %s, rise = %s, conf = %s }," % (
                    q(v["id"]), q(v["kind"]), joins, num(v["width_m"] * S), num(v["low"][0] * S), num(v["low"][1] * S), num(v["high"][0] * S),
                    num(v["high"][1] * S), num(v["run_m"] * S), num(v["rise_m"] * S), q(v["confidence"])))
            else:
                w("\t\t{ id = %s, kind = %s, joins = %s, at = { %s, %s }, conf = %s }," % (
                    q(v["id"]), q(v["kind"]), joins, num(v["at"][0] * S), num(v["at"][1] * S), q(v["confidence"])))
    w("\t},")
    # atria and voids
    w("\tatria = {")
    done = set()
    for lv in m["levels"]:
        for a in lv["atria"]:
            if a["kind"] != "octagon_dome_atrium":
                continue
            key = (a["cx"], a["cz"])
            if key in done:
                continue
            done.add(key)
            w("\t\t{ id = %s, cx = %s, cz = %s, w = %s, conf = %s, pts = { %s } }," % (
                q("north" if a["cz"] < 0 else "south"), num(a["cx"] * S), num(a["cz"] * S), num(a["w"] * S), q(a["confidence"]), flat(a["poly"])))
    w("\t},")
    w("\tvoids = {")
    for a in m["levels"][2]["atria"]:
        if a["kind"] == "octagon_dome_atrium":
            continue
        w("\t\t{ id = %s, kind = %s, cx = %s, cz = %s, w = %s, conf = %s, pts = { %s } }," % (
            q(a["id"]), q(a["kind"]), num(a["cx"] * S), num(a["cz"] * S), num(a["w"] * S), q(a["confidence"]), flat(a["poly"])))
    w("\t},")
    # docks, service
    l1s = m["levels"][1]["service"]
    w("\tdocks = {")
    for dk, nm in zip(l1s["docks"], ("NESTA DOCKS", "BOLTWORKS DOCKS")):
        w("\t\t{ name = %s, bays = %d, pitch = %s, wallX = %s, apexX = %s, tooth = %s, apexZ = { %s }, conf = %s }," % (
            q(nm), dk["bays"], num(dk["pitch_m"] * S), num(dk["wall_x"] * S), num(dk["apex_x"] * S), num(dk["tooth_depth_m"] * S),
            ", ".join(num(z * S) for z in dk["bay_apex_z"]), q(dk["confidence"])))
    w("\t},")
    w("\tservice = {")
    l0s = m["levels"][0]["service"]
    tn = l0s["tunnel"]["rect"]
    w("\t\ttunnel = { name = \"SERVICE TUNNEL\", x0 = %s, x1 = %s, z0 = %s, z1 = %s, conf = %s }," % (
        num(tn[0] * S), num(tn[1] * S), num(tn[2] * S), num(tn[3] * S), q(l0s["tunnel"]["confidence"])))
    sr = l0s["saferoom"]["rects"]
    w("\t\tshelter = { x0 = %s, x1 = %s, z0 = %s, z1 = %s, door = { %s, %s }, conf = \"D\" }, -- THE SHELTER block (room size not drawn)" % (
        num(sr[0][0] * S), num(sr[0][1] * S), num(sr[0][2] * S), num(sr[0][3] * S), num(l0s["saferoom"]["door"][0] * S), num(l0s["saferoom"]["door"][1] * S)))
    w("\t\tunit14 = { x0 = %s, x1 = %s, z0 = %s, z1 = %s, conf = \"D\" }, -- UNIT 14 container room" % (
        num(sr[1][0] * S), num(sr[1][1] * S), num(sr[1][2] * S), num(sr[1][3] * S)))
    back_names = ("NESTA STOCK ROOMS", "KASSA BACK OF HOUSE", "BOLTWORKS STOCK BLOCK", "BOLTWORKS OFFICES")
    w("\t\tback = { -- partitioned back-of-house blocks (grade D); the BOLTWORKS OFFICES hold OFFICE and GOODS-IN")
    for bk, nm in zip(l1s["back_of_house"], back_names):
        r = bk["rect"]
        w("\t\t\t{ name = %s, x0 = %s, x1 = %s, z0 = %s, z1 = %s }," % (q(nm), num(r[0] * S), num(r[1] * S), num(r[2] * S), num(r[3] * S)))
    w("\t\t},")
    wr = m["restrooms"]["items"][0]["in_rect"]
    w("\t\twashroom = { level = 3, x0 = %s, x1 = %s, z0 = %s, z1 = %s }, -- the L2 rectangle that holds the washroom with the hidden switch" % (
        num(wr[0] * S), num(wr[1] * S), num(wr[2] * S), num(wr[3] * S)))
    w("\t},")
    w("\tterraces = {")
    for t in m["levels"][1]["terraces"]:
        w("\t\t{ id = %s, pts = { %s } }," % (q(t["id"].replace("L1_terrace_", "")), flat(t["poly"])))
    w("\t},")
    w("\tpads = {")
    for e in m["levels"][0]["extra_polygons"]:
        w("\t\t{ id = %s, pts = { %s } }," % (q(e["id"]), flat(e["poly"])))
    w("\t},")
    w("}")

    # ── extracts ──
    w("L.ext = {")
    missing = []
    names = {e["name"]: e for e in d["extracts"]}
    for ref, spec in EXTRACTS.items():
        e = names.get(ref)
        if not e:
            missing.append(ref)
            continue
        eid, nm, grp, rule, size, note = spec
        rtxt = ", ".join("%s = %s" % (k, q(v) if isinstance(v, str) else num(v, 2)) for k, v in rule.items())
        ex, ez = e["x"] * S, e["z"] * S
        # the whole zone must lie inside the invisible boundary walls: pull it in when the reference puts it on or past the limit
        ex, ez, moved = pull_inside(limit_s, ex, ez, size[0] / 2 + 2)
        if moved > 0.5:
            note = ("moved %s studs inward (reference position at or past the limit); " % num(moved, 0)) + note
            print("extract %s moved %.1f studs inward" % (eid, moved))
        w("\t{ %s, %s, %s, %s, %s, %d, %d, %d, { %s }, %s, %s }," % (
            q(eid), q(nm), q(grp), num(ex), num(ez), size[0], size[1], size[2], rtxt, q(e["confidence"]), q(note)))
    w("}")
    if missing:
        raise SystemExit("extracts without a spec: %s" % missing)
    if len(EXTRACTS) != len(d["extracts"]):
        raise SystemExit("extract count differs: %d vs %d" % (len(EXTRACTS), len(d["extracts"])))

    # ── spawns ──
    sp = d["spawns"]
    w("L.pmc = {")
    for side, key in (("nw", "pmc_group_mallnw"), ("se", "pmc_group_mallse")):
        w("\t%s = {" % side)
        vals = []
        for x, z, y, f in sp[key]["points"]:
            vals.append("{ %s, %s, %s, %s }" % (num(x * S), num(z * S), num(YL(y)), num(yaw_of(f), 0)))
        w(wrap(vals, 5, "\t\t"))
        w("\t},")
    w("}")
    w("L.clusters = {")
    for side, key in (("nw", "pmc_group_mallnw"), ("se", "pmc_group_mallse")):
        pts = sp[key]["points"]
        w("\t%s = {" % side)
        for cx, cz in sp[key]["clusters_of_5"]:
            near = [p for p in pts if math.hypot(p[0] - cx, p[1] - cz) < 20]
            ys = sorted(p[2] for p in near) or [GROUND]
            w("\t\t{ %s, %s, %s, %d }," % (num(cx * S), num(cz * S), num(YL(ys[len(ys) // 2])), len(near)))
        w("\t},")
    w("}")
    rings = sp["pmc_rings_2026"]
    w("L.rings = {")
    for i, (x, z) in enumerate(rings["points"]):
        n1 = i + 1
        w("\t{ %s, %s, %s, %d, %d }," % (num(x * S), num(z * S), q(rings["groups_by_rule"][i].lower()), 1 if n1 in rings["in_1_0_strip"] else 0,
                                          1 if n1 in rings["near_spt_site_25m"] else 0))
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
    w("L.aiIcons = {")
    for p in sp["ai_scav_icons_2026"]["points"]:
        w("\t{ %s, %s, %s }," % (num(p["x"] * S), num(p["z"] * S), q(p["level"])))
    w("}")
    # bosses: ours only where the game has one (THE CARETAKER); the rest are logged gaps
    w("L.bosses = {")
    for bs in d["bosses"]:
        if bs["internal"] not in ("bossKilla", "bossTagilla"):
            continue
        ours = BOSS_NAMES.get(bs["internal"], "")
        icons = ", ".join("{ %s, %s, %s, %s }" % (num(i["x"] * S), num(i["z"] * S), q(i["level"]), q(ICON_WHERE.get(i["where"], "garage"))) for i in bs["icon_positions"])
        zl = ", ".join(q(ZONE_NAMES.get(z, z)) for z in bs["zones"])
        note = "THE CARETAKER (the existing boss), hunts alone" if ours else "not built yet (a logged gap): hammer icon in the KASSA garage"
        w("\t{ id = %s, ours = %s, chance = %s, zones = { %s }, icons = { %s }, note = %s }," % (
            q(bs["internal"]), q(ours), num(BOSS_CHANCE[bs["internal"]], 2), zl, icons, q(note)))
    w("}")

    # keys
    w("L.keys = {")
    for kid, nm, opens, lvl, pos, power, exists, note in KEYS:
        px = "nil, z = nil" if pos is None else "%s, z = %s" % (num(pos[0] * S), num(pos[1] * S))
        w("\t{ id = %s, name = %s, opens = %s, level = %s, x = %s, power = %s, exists = %s, note = %s }," % (
            q(kid), q(nm), q(opens), q(lvl), px, "true" if power else "false", "true" if exists else "false", q(note)))
    w("}")

    hz = d["hazards"]
    ad = hz["airdrop"]
    w("L.hazard = {")
    w("\tmine = L.mine.poly, snipe = L.snipe.poly,")
    w("\tironAlarm = { %s, %s }, -- IRONSIGHT store alarm" % (num(hz["kiba_alarm"]["x"] * S), num(hz["kiba_alarm"]["z"] * S)))
    w("\tairdrop = { chance = %s, minPlayers = %d, first = { %d, %d }, cooldown = { %d, %d } }," % (
        num(ad["chance"], 2), ad["min_players"], ad["start_s"][0], ad["start_s"][1], ad["cooldown_s"][0], ad["cooldown_s"][1]))
    w("\traid = 2400,")
    w("\tmounted = {}, -- no mounted gun position in any source")
    w("\tpropane = {}, -- no propane cylinder position in any source")
    w("}")
    w("return L")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(out) + "\n"
    OUT.write_text(text, encoding="utf-8")
    print("wrote %s: %d lines, %d bytes; %d relief knots, %d stores (%d named), limit %d points" % (
        OUT.relative_to(ROOT), len(out), len(text), len(knots), n_store, n_named, len(limit)))


if __name__ == "__main__":
    sys.exit(main())

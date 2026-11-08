"""Zero Return - M14 gun pipeline driver (run inside Blender, a step per MCP call; each call stays under a time
budget and can be repeated until it reports nothing left).

    import build_guns_all as G
    G.load_all()          # item registry: build_items_a/b/c, then the gun parts (which replace the old guns)
    G.icons(45)           # inventory pictures of every gun part (and the multitool)  -> repeat until left == 0
    G.sprites(45)         # side sprites of every part                                -> repeat until left == 0
    G.export(name)        # one mesh batch per family (see BATCHES)
    G.pack()              # item icon atlas (all items) and the sprite atlas
"""
import sys, importlib, os, json, time
import zr_items, zr_item_reg

GUN_MODULES = ("guns_mods", "guns_r17", "guns_kst", "guns_ksl", "guns_spr", "guns_har", "guns_tun", "guns_p9", "guns_gl6", "guns_dmr", "guns_nato", "guns_vss")
ITEM_MODULES = ("build_items_a", "build_items_b", "build_items_c")
BATCHES = {
    "ZR_GunsAR": "r17", "ZR_GunsAK": "kst", "ZR_GunsSMG": "spr", "ZR_GunsSG": "har", "ZR_GunsBolt": "tun",
    "ZR_GunsPistol": "p9", "ZR_GunsMods": None, "ZR_GunsLMG": "ksl", "ZR_GunsGL": "gl6", "ZR_GunsDMR": "dmr", "ZR_GunsNATO": "nato", "ZR_GunsVSS": "vss",
}
STATE = {"icons": set(), "sprites": {}, "exported": {}}
REC = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov", "assets", "renders", "guns", "sprite_records.json")
if os.path.exists(REC):
    with open(REC) as f:
        STATE["sprites"] = json.load(f)


def load_all():
    importlib.reload(zr_items)
    importlib.reload(zr_item_reg)
    zr_item_reg.REG.clear()
    import zr_guns
    importlib.reload(zr_guns)
    for m in ITEM_MODULES + GUN_MODULES:
        if m in sys.modules:
            importlib.reload(sys.modules[m])
        else:
            importlib.import_module(m)
    return len(zr_item_reg.REG), len(zr_guns.GP), len(zr_guns.PRESETS)


def gun_ids():
    import zr_guns
    return sorted(zr_guns.GP)


def icons(seconds=45.0):
    import zr_guns
    t0 = time.time()
    out = []
    todo = [p for p in gun_ids() if p not in STATE["icons"]]
    with zr_guns.gun_lighting():
        for pid in todo:
            if time.time() - t0 > seconds:
                break
            out += zr_item_reg.run([pid])
            STATE["icons"].add(pid)
    if "MULTITOOL" not in STATE["icons"] and time.time() - t0 < seconds:
        out += zr_item_reg.run(["MULTITOOL"])
        STATE["icons"].add("MULTITOOL")
    left = [p for p in gun_ids() + ["MULTITOOL"] if p not in STATE["icons"]]
    return len(out), len(left)


def sprites(seconds=45.0, redo=False):
    """render the sprites not rendered yet (redo: start over); records are kept in sprite_records.json"""
    import zr_guns
    if redo:
        STATE["sprites"].clear()
    recs, left = zr_guns.run_sprite_sheets(seconds, STATE["sprites"])
    os.makedirs(os.path.dirname(REC), exist_ok=True)
    with open(REC, "w") as f:
        json.dump(STATE["sprites"], f, indent=1, sort_keys=True)
    return len(STATE["sprites"]), len(left)


def export(batch):
    import zr_guns
    fam = BATCHES[batch]
    pids = [p for p in gun_ids() if zr_guns.GP[p]["family"] == fam]
    recs, fbx, tris = zr_guns.export_family(batch, pids)
    for pid, r in recs.items():
        r["w"], r["h"] = zr_guns.GP[pid]["w"], zr_guns.GP[pid]["h"]
    zr_guns.write_records(recs)
    STATE["exported"][batch] = (len(pids), tris)
    return batch, len(pids), tris, fbx


def pack():
    """item icon atlas for every registered item (the gun parts included) and the gun sprite atlas"""
    import zr_guns
    entries = []
    for iid, e in zr_item_reg.REG.items():
        if os.path.exists(os.path.join(zr_items.OUT, iid + ".png")):
            entries.append((iid, e["w"], e["h"]))
    placed, files = zr_items.pack_atlas(entries)
    sp, sfiles = zr_guns.pack_sprites(STATE["sprites"])
    return len(placed), [os.path.basename(f) for f in files], len(sp), [os.path.basename(f) for f in sfiles]

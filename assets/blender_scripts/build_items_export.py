"""Zero Return - export the item models for loose loot in the world (M13, owner request).
Runs inside Blender after the build_items_*.py registry is loaded (zr_item_reg.REG).

The same models as the inventory pictures, with contact shading baked into the vertex colours (ambient occlusion
from the item itself and the surface it lies on), one mesh per material named ZR_IT_<ITEM>__<mat>, origin at
the bottom centre. Worn equipment is not exported here (loose gear reuses the character meshes) and neither are
guns (they lie as the shared WeaponModels build). Three batches keep each upload small.
"""
import bpy, os, json
from mathutils import Vector
import zr_items, zr_item_reg, zr_kit
from zr_lib import batch_scene, export_batch

SKIP_KINDS = ("weapon", "wear")
WEAR = {"HELMET_C2", "HELMET_C3", "HELMET_C4", "HELMET_C5", "HARDHAT_FOREMAN", "CAP_FIELD", "BEANIE", "HEADSET_GS1",
        "HEADSET_COMM", "GAITER", "ARMOR_C2", "ARMOR_C3", "ARMOR_C4", "ARMOR_C5", "ARMOR_C6", "RIG_BELT", "RIG_CHEST",
        "RIG_PLATE", "BAG_SLING", "CANVAS_BAG", "BAG_PATROL", "BAG_RAID"}
GUNS = {"R17_RIFLE", "KST_RIFLE", "SPARROW_SMG", "HARROW12", "TUNDRA_BOLT", "P9_PISTOL", "FIELD_KNIFE"}


def batches():
    ids = [i for i in zr_item_reg.REG if i not in WEAR and i not in GUNS and not zr_item_reg.REG[i].get("raw")]
    gear = [i for i in ids if i.startswith(("A", "R17_MAG", "KST_MAG", "SPARROW_MAG", "P9_MAG", "GREN_", "WEAPON_KIT", "RED_DOT",
                                            "SCOPE_4X", "SUPP_", "BRAKE_", "GRIP_", "LIGHT_T", "SECURE_"))]
    med = [i for i in ids if i not in gear and i in ("BANDAGE", "TOURNIQUET", "HEMOSTAT", "SPLINT", "PAINKILLERS", "MEDKIT_S", "MEDKIT_M",
                                                       "MEDKIT_L", "MEDKIT_XL", "SURGKIT", "WATER", "STEW", "HARDTACK", "VOLT_DRINK",
                                                       "JUICE", "CHOC_BAR", "SEALED_DRIVE", "LEDGER") or i.startswith(("KEY_", "RUSTED", "CARD_"))]
    rest = [i for i in ids if i not in gear and i not in med]
    return {"ZR_ItemsA": gear, "ZR_ItemsB": med, "ZR_ItemsC": rest}


def build_baked(iid, coll):
    e = zr_item_reg.REG[iid]
    it = zr_items.Item(iid)
    e["fn"](it)
    # AO reach scales with the item (it is still in metres here)
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for b in it.b.values():
        for v in b.bm.verts:
            lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
            hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
    size = max((hi - lo).length, 0.02)
    zr_kit.Prop.bake(it, ao_dist=size * 0.35, ao_strength=0.62, ground=lo.z > -0.005, floor_dirt=0.0, dust=0.04, noise=0.03, seed=len(iid))
    return it.finish(coll)


def export(name, ids):
    scn = batch_scene(name)
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    objs = []
    for iid in ids:
        objs += build_baked(iid, scn.collection)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(zr_items.render_material(o["zr_mat"]))
    fbx, blend, meta = export_batch(objs, name, scn)
    mats = {o.name: o["zr_mat"] for o in objs}
    with open(os.path.join(os.path.dirname(fbx), name + ".mats.json"), "w") as f:
        json.dump(mats, f, indent=1, sort_keys=True)
    return fbx, len(objs), sum(m["tris"] for m in meta.values())


# ---- every other item in the world (art-4b follow-up, 2026-11-09) ----
# Since 2026-10-29 the slices added items with Blender models for their inventory pictures only, so 286 of 577 items
# lay in raids as plain blocks and showed their picture in INSPECT (EFT: every item lies as its own model). The
# batches below carry them (assets/exports/ZR_ItemsWorld.json lists the ids per batch, from the Studio census of items
# with no ItemMeta, gun build or worn mesh). Builds take seconds per item (the contact-shading bake), so the export
# runs in steps that each stay under the Blender bridge's 60 s:
#   import build_items_export as X; X.load_all(); X.world_start("ZR_ItemsD"); X.world_step("ZR_ItemsD") until 0 left;
#   X.world_finish("ZR_ItemsD")  -> assets/exports/ZR_ItemsD.fbx + .meta.json + .mats.json; then tools/item_meta.py
import builtins, glob, importlib, time

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD_JSON = os.path.join(HERE, "..", "exports", "ZR_ItemsWorld.json")
_ST = builtins.__dict__.setdefault("ZR_ITEMS_WORLD", {})   # survives re-imports between bridge calls


def load_all():
    """import every build_items_<letter>.py so zr_item_reg.REG holds every item; returns the count. A module imported
    earlier in the session is run again: it may have registered into an older zr_item_reg (found 2026-11-09)"""
    import sys
    for f in sorted(glob.glob(os.path.join(HERE, "build_items_[a-z].py"))):
        mod = os.path.splitext(os.path.basename(f))[0]
        if mod in sys.modules:
            importlib.reload(sys.modules[mod])
        else:
            importlib.import_module(mod)
    return len(zr_item_reg.REG)


def world_ids(name):
    with open(WORLD_JSON) as f:
        return json.load(f)[name]


def world_start(name, ids=None):
    """a fresh batch scene for `name`; returns the ids it will build and those with no builder"""
    ids = list(ids or world_ids(name))
    scn = batch_scene(name)
    for o in list(scn.collection.objects):
        bpy.data.objects.remove(o)
    missing = [i for i in ids if i not in zr_item_reg.REG or zr_item_reg.REG[i].get("raw")]
    _ST[name] = {"ids": [i for i in ids if i not in missing], "done": [], "objs": [], "err": {}}
    return len(_ST[name]["ids"]), missing


def world_step(name, seconds=45.0):
    """build and bake items of the batch until the time is spent; returns how many are left"""
    st = _ST[name]
    scn = batch_scene(name)
    t0 = time.time()
    for iid in st["ids"]:
        if iid in st["done"]:
            continue
        if time.time() - t0 > seconds:
            break
        try:
            st["objs"] += [o.name for o in build_baked(iid, scn.collection)]
        except Exception as e:   # reported by world_finish; the item keeps its block in game
            st["err"][iid] = repr(e)[:200]
        st["done"].append(iid)
    return len(st["ids"]) - len(st["done"])


def world_finish(name):
    """export the built batch like export(): FBX, meta and mats; returns (fbx, pieces, tris, errors)"""
    st = _ST[name]
    assert len(st["done"]) == len(st["ids"]), "%s: %d items not built yet" % (name, len(st["ids"]) - len(st["done"]))
    objs = [bpy.data.objects[n] for n in st["objs"]]
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(zr_items.render_material(o["zr_mat"]))
    fbx, blend, meta = export_batch(objs, name, batch_scene(name))
    with open(os.path.join(os.path.dirname(fbx), name + ".mats.json"), "w") as f:
        json.dump({o.name: o["zr_mat"] for o in objs}, f, indent=1, sort_keys=True)
    return fbx, len(objs), sum(m["tris"] for m in meta.values()), st["err"]

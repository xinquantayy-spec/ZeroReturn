"""Zero Return - item registry and runner for the inventory icons (see zr_items.py).

Each build_items_*.py registers its items with @item(ID, w, h, view=...). run() builds, renders and clears them;
sheet() lays rendered icons out on a stash-like grid for review.
"""
import bpy, os, json, math
from zr_items import Item, studio, render_icon, clear_items, OUT, CELL_PX

REG = {}


def item(item_id, w, h, view="three_q", margin=0.1, roll=0.0, raw=False):
    """register an item; raw: fn(coll) makes its own objects (equipment from the character batches)"""
    def deco(fn):
        REG[item_id] = dict(id=item_id, w=w, h=h, view=view, margin=margin, roll=roll, fn=fn, raw=raw)
        return fn
    return deco


def build(item_id, coll):
    e = REG[item_id]
    if e.get("raw"):
        return e["fn"](coll)
    it = Item(item_id)
    e["fn"](it)
    return it.finish(coll)


DONE = set()


def run_budget(ids, seconds=45.0, px=CELL_PX):
    """render the ids not rendered yet in this session until the time budget is spent; returns (done, left)"""
    import time
    t0 = time.time()
    out = []
    for iid in ids:
        if iid in DONE:
            continue
        if time.time() - t0 > seconds:
            break
        try:
            out += run([iid], px=px)
            DONE.add(iid)
        except Exception as e:
            out.append((iid, "ERR " + repr(e)[:160]))
            DONE.add(iid)
    left = [i for i in ids if i not in DONE]
    return out, left


def run(ids=None, px=CELL_PX):
    scn, cam, coll = studio()
    out = []
    for iid in (ids or list(REG)):
        e = REG[iid]
        clear_items(coll)
        objs = build(iid, coll)
        tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
        render_icon(iid, objs, e["w"], e["h"], e["view"], e["margin"], e["roll"], px=px)
        out.append((iid, tris))
        clear_items(coll)
    return out


def sheet(ids, out_png, cell=64, cols=12, bg=(0.11, 0.115, 0.12, 1.0), line=(0.2, 0.21, 0.22, 1.0)):
    """review sheet: icons on a dark grid with cell lines, packed left to right like a stash"""
    import numpy as np
    entries = [(i, REG[i]["w"], REG[i]["h"]) for i in ids if os.path.exists(os.path.join(OUT, i + ".png"))]
    # simple shelf packing in cells
    x = y = shelf = 0
    pos = []
    for iid, w, h in entries:
        if x + w > cols:
            x, y, shelf = 0, y + shelf, 0
        pos.append((iid, x, y, w, h))
        x += w
        shelf = max(shelf, h)
    rows = y + shelf
    W, H = cols * cell, max(1, rows) * cell
    img = np.zeros((H, W, 4), dtype=np.float32)
    img[:, :] = bg
    for gx in range(cols + 1):
        img[:, min(W - 1, gx * cell)] = line
    for gy in range(rows + 1):
        img[min(H - 1, gy * cell), :] = line
    from zr_items import _load_scaled
    for iid, cx, cy, w, h in pos:
        px = _load_scaled(os.path.join(OUT, iid + ".png"), w * cell, h * cell)
        y0 = H - (cy + h) * cell
        x0 = cx * cell
        a = px[:, :, 3:4]
        region = img[y0:y0 + h * cell, x0:x0 + w * cell, :3]
        img[y0:y0 + h * cell, x0:x0 + w * cell, :3] = region * (1 - a) + px[:, :, :3] * a
        # item frame (lighter border), like the stash tiles
        img[y0, x0:x0 + w * cell] = (0.32, 0.33, 0.33, 1)
        img[y0 + h * cell - 1, x0:x0 + w * cell] = (0.32, 0.33, 0.33, 1)
        img[y0:y0 + h * cell, x0] = (0.32, 0.33, 0.33, 1)
        img[y0:y0 + h * cell, x0 + w * cell - 1] = (0.32, 0.33, 0.33, 1)
    im = bpy.data.images.new("_zr_sheet", W, H, alpha=True)
    im.pixels[:] = img.ravel()
    im.filepath_raw = out_png
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    return out_png

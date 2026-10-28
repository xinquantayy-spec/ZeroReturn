#!/usr/bin/env python3
"""Stage files changed since the last sync into /mnt/user-data/outputs/ZR and print device_commit_files JSON.
Usage: python3 tools/stage_sync.py [paths...]   (default: src tools docs assets/blender_scripts + root files)"""
import hashlib, json, os, shutil, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
import time
OUT = pathlib.Path("/mnt/user-data/outputs/ZR") / ("run_" + str(int(time.time() * 1000)))  # unique per run: avoids stale uploads of a reused path
STATE = pathlib.Path("/tmp/claude-0/-home-claude/6a163997-7a90-5ac1-b594-c3c8d7a21bf5/scratchpad/sync_state.json")
DEV = "C:\\Users\\lenovo\\Documents\\EscapeFromBloxov\\"
if sys.argv[1:2] == ["--commit"]:  # mark the last staged set as synced (same as tools/sync_done.py)
    import runpy
    runpy.run_path(str(ROOT / "tools" / "sync_done.py"))
    sys.exit(0)
roots = sys.argv[1:] or ["src", "tools", "docs", "assets/blender_scripts", "assets/audio", "assets/textures", "default.project.json", "rokit.toml", ".gitignore"]
# never pushed: files the PC side owns (written by Blender on the dev PC)
SKIP = {"assets/upload_manifest.json"}
state = json.loads(STATE.read_text()) if STATE.exists() else {}
files = []
for r in roots:
    p = ROOT / r
    cands = [p] if p.is_file() else [q for q in p.rglob("*") if q.is_file()]
    for f in cands:
        rel = f.relative_to(ROOT).as_posix()
        if rel in SKIP or "/__pycache__/" in rel:
            continue
        h = hashlib.sha1(f.read_bytes()).hexdigest()
        if state.get(rel) != h:
            dst = OUT / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dst)
            files.append((rel, h))
batches = [files[i:i + 50] for i in range(0, len(files), 50)]
for b in batches:
    print(json.dumps([{"stagedPath": str(OUT / rel), "devicePath": DEV + rel.replace("/", "\\")} for rel, _ in b]))
    print("---")
pend = STATE.with_suffix(".pending.json")
pend.write_text(json.dumps({rel: h for rel, h in files}))
print(f"{len(files)} files staged in {len(batches)} batch(es); run tools/stage_sync.py --commit (or tools/sync_done.py) after a successful commit", file=sys.stderr)

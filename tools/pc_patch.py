#!/usr/bin/env python3
"""Bring the dev PC's project folder up to date when only Python on the PC is reachable (Blender MCP), not the
file bridge. Builds one Python snippet that patches each changed file in Documents/EscapeFromBloxov in place.

Only changed hunks travel (zlib + base64). Every file is checked against the sha1 of the version last synced
before it is touched, and against the sha1 of the new version after; a file that does not match is skipped and
reported, never half-written. New files travel whole. Nothing outside the project folder is written.
Shares the sync state with tools/stage_sync.py, so either route can be used next.

Usage:
  python3 tools/pc_patch.py [paths...]  -> writes <scratchpad>/pc_patch.py (run it with the Blender MCP), prints a summary
  python3 tools/pc_patch.py --plain [paths...] -> the same as a readable snippet (small syncs, pasted directly)
  python3 tools/pc_patch.py --done      -> the snippet reported every file ok: mark them synced
Default paths: the same roots as stage_sync.py.
"""
import base64, difflib, hashlib, json, pathlib, subprocess, sys, zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAD = pathlib.Path("/tmp/claude-0/-home-claude/6a163997-7a90-5ac1-b594-c3c8d7a21bf5/scratchpad")
STATE = PAD / "sync_state.json"
PEND = PAD / "sync_state.pending.json"
OUT = PAD / "pc_patch.py"
ROOTS = ["src", "tools", "docs", "assets/blender_scripts", "assets/audio", "assets/textures", "default.project.json", "rokit.toml", ".gitignore",
         "DEVELOPMENT_STATUS.md", "NEXT_TASK.md", "TEST_RESULTS.md", "KNOWN_ISSUES.md", "ASSET_MANIFEST.md"]
SKIP = {"assets/upload_manifest.json"}


def sha(b):
    return hashlib.sha1(b).hexdigest()


def synced_content(rel, want):
    """bytes of the version the PC has (sha1 = want): the copy kept at the last sync, else git history"""
    if want is None:
        return None
    kept = PAD / "pc_base" / rel
    if kept.exists():
        b = kept.read_bytes()
        if sha(b) == want:
            return b
    r = subprocess.run(["git", "log", "--format=%H", "-n", "30", "--", rel], cwd=ROOT, capture_output=True, text=True)
    for rev in ["HEAD"] + r.stdout.split():
        b = subprocess.run(["git", "show", f"{rev}:{rel}"], cwd=ROOT, capture_output=True).stdout
        if b and sha(b) == want:
            return b
    return None


def hunks(old, new):
    a, b = old.splitlines(keepends=True), new.splitlines(keepends=True)
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    groups = list(sm.get_grouped_opcodes(2))
    out = []
    for gi, g in enumerate(groups):
        lo, hi, jlo, jhi = g[0][1], g[-1][2], g[0][3], g[-1][4]
        prev_hi = groups[gi - 1][-1][2] if gi > 0 else 0
        next_lo = groups[gi + 1][0][1] if gi + 1 < len(groups) else len(a)
        while True:
            o = "".join(a[lo:hi])
            if o and old.count(o) == 1:
                break
            if lo <= prev_hi and hi >= next_lo:
                return None
            if lo > prev_hi:
                lo -= 1
                jlo -= 1
            if hi < next_lo:
                hi += 1
                jhi += 1
        out.append(["".join(a[lo:hi]), "".join(b[jlo:jhi])])
    return out


RUNNER = r'''import base64, hashlib, json, os, zlib
ROOT = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov")
PAY = PAY if "PAY" in globals() else json.loads(zlib.decompress(base64.b64decode(DATA)).decode("utf-8"))
res = []
for e in PAY:
    rel = e["rel"]
    path = os.path.normpath(os.path.join(ROOT, *rel.split("/")))
    if not path.startswith(os.path.normpath(ROOT) + os.sep):
        res.append(rel + ": OUTSIDE"); continue
    cur = open(path, "rb").read() if os.path.exists(path) else None
    if cur is not None and hashlib.sha1(cur).hexdigest() == e["new"]:
        res.append(rel + ": already"); continue
    if e["mode"] == "full":
        if cur is not None and e["base"] is not None and hashlib.sha1(cur).hexdigest() != e["base"]:
            res.append(rel + ": BASE MISMATCH"); continue
        data = base64.b64decode(e["data"])
    else:
        if cur is None or hashlib.sha1(cur).hexdigest() != e["base"]:
            res.append(rel + ": BASE MISMATCH"); continue
        text = cur.decode("utf-8")
        ok = True
        for o, n in e["data"]:
            if text.count(o) != 1:
                ok = False; break
            text = text.replace(o, n, 1)
        if not ok:
            res.append(rel + ": HUNK"); continue
        data = text.encode("utf-8")
    if hashlib.sha1(data).hexdigest() != e["new"]:
        res.append(rel + ": RESULT MISMATCH"); continue
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".zrtmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)
    res.append(rel + ": ok")
print("\n".join(res))
print("files ok:", sum(1 for r in res if r.endswith(": ok") or r.endswith(": already")), "/", len(res))
'''


def main():
    args = sys.argv[1:]
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    if args == ["--done"]:
        pend = json.loads(PEND.read_text())
        state.update(pend)
        PEND.unlink()
        STATE.write_text(json.dumps(state))
        # keep what the PC now has, so the next sync can send only the changes
        for rel in pend:
            dst = PAD / "pc_base" / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes((ROOT / rel).read_bytes())
        # Rojo carries src/ from the PC into Studio, so Studio now has these too (tools/studio_patch.py base)
        for rel in pend:
            if rel.startswith("src/"):
                dst = PAD / "studio_base" / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_bytes((ROOT / rel).read_bytes())
        print("synced entries:", len(state))
        return
    plain = "--plain" in args  # small syncs: hunks as a readable Python literal (pasted into the Blender call)
    args = [a for a in args if a != "--plain"]
    roots = args or ROOTS
    pay, pend = [], {}
    for r in roots:
        p = ROOT / r
        cands = [p] if p.is_file() else [q for q in p.rglob("*") if q.is_file()]
        for f in cands:
            rel = f.relative_to(ROOT).as_posix()
            if rel in SKIP or "/__pycache__/" in rel:
                continue
            new = f.read_bytes()
            hv = sha(new)
            if state.get(rel) == hv:
                continue
            base = synced_content(rel, state.get(rel))
            entry = {"rel": rel, "base": state.get(rel), "new": hv}
            text_ok = True
            try:
                new.decode("utf-8")
                if base is not None:
                    base.decode("utf-8")
            except UnicodeDecodeError:
                text_ok = False
            hs = hunks(base.decode("utf-8"), new.decode("utf-8")) if (base is not None and text_ok) else None
            if hs is not None:
                entry["mode"], entry["data"] = "hunks", hs
            else:
                entry["mode"], entry["data"] = "full", base64.b64encode(new).decode()
            pay.append(entry)
            pend[rel] = hv
            print(f"{rel}: {entry['mode']}" + (f" ({len(hs)} hunks)" if hs is not None else f" ({len(new)} bytes)"))
    if plain:
        OUT.write_text("PAY = " + repr(pay) + "\n" + RUNNER)
    else:
        blob = base64.b64encode(zlib.compress(json.dumps(pay).encode("utf-8"), 9)).decode()
        OUT.write_text("DATA = " + repr(blob) + "\n" + RUNNER)
    PEND.write_text(json.dumps(pend))
    print(f"{len(pay)} files -> {OUT} ({OUT.stat().st_size} bytes); after it reports all ok: python3 tools/pc_patch.py --done")


if __name__ == "__main__":
    main()

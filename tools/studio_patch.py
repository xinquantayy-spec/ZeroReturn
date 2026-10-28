#!/usr/bin/env python3
"""Push local script changes straight into the open Studio place (Edit datamodel) when the PC file bridge is down.

Studio normally gets code from Rojo (files on the dev PC). When the bridge that writes those files is unavailable,
this builds a Luau snippet for the Studio MCP `execute_luau` tool that patches each script's Source in place:
only the changed hunks travel, every hunk must match exactly once, and the result is checked against a hash of the
local file. The PC files must be synced afterwards (tools/stage_sync.py), or Rojo will put the old code back when
it reconnects.

Usage:
  python3 tools/studio_patch.py [files...]   -> writes the snippet to <scratchpad>/studio_patch.luau, prints a summary
  python3 tools/studio_patch.py --done       -> the last snippet ran fine: its files become the new Studio base
  python3 tools/studio_patch.py --lib        -> prints the helper to run once per Studio session (installs _G.ZR_patch)
Base = what Studio has: <scratchpad>/studio_base/<rel> if present, else the file at git HEAD.
"""
import difflib, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAD = pathlib.Path("/tmp/claude-0/-home-claude/6a163997-7a90-5ac1-b594-c3c8d7a21bf5/scratchpad")
BASE = PAD / "studio_base"
OUT = PAD / "studio_patch.luau"
PENDING = PAD / "studio_patch.pending.json"
MOD = 2147483647


def inst_path(rel):
    p = pathlib.PurePosixPath(rel)
    stem = p.name
    for suf in (".server.luau", ".client.luau", ".luau"):
        if stem.endswith(suf):
            stem = stem[: -len(suf)]
            break
    top = {"shared": "ReplicatedStorage.ZR", "server": "ServerScriptService.ZRServer",
           "client": "StarterPlayer.StarterPlayerScripts.ZRClient"}[p.parts[1]]
    return ".".join([top] + list(p.parts[2:-1]) + [stem])


def class_of(rel):
    return "Script" if rel.endswith(".server.luau") else ("LocalScript" if rel.endswith(".client.luau") else "ModuleScript")


def h(data: bytes):
    v = 0
    for b in data:
        v = (v * 31 + b) % MOD
    return v


def base_of(rel):
    b = BASE / rel
    if b.exists():
        return b.read_text()
    r = subprocess.run(["git", "show", "HEAD:" + rel], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def long(s):
    n = 1
    while ("]" + "=" * n + "]") in s or ("[" + "=" * n + "[") in s:
        n += 1
    return "[" + "=" * n + "[" + ("\n" if s.startswith("\n") else "") + s + "]" + "=" * n + "]"


def hunks(old, new):
    a, b = old.splitlines(keepends=True), new.splitlines(keepends=True)
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    groups = list(sm.get_grouped_opcodes(3))
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
                return None  # cannot make this hunk unique without touching a neighbour: full replace
            if lo > prev_hi:
                lo -= 1
                jlo -= 1
            if hi < next_lo:
                hi += 1
                jhi += 1
        out.append(("".join(a[lo:hi]), "".join(b[jlo:jhi])))
    return out


LIB = """local function find(path)
	local inst = game
	for name in string.gmatch(path, "[^%.]+") do
		inst = inst and inst:FindFirstChild(name)
	end
	return inst
end
local function hash(s)
	local v = 0
	for i = 1, #s do
		v = (v * 31 + string.byte(s, i)) % 2147483647
	end
	return v
end
_G.ZR_patch = function(R, path, cls, edits, len, hv)
	local inst = find(path)
	local src
	if not inst then
		if #edits ~= 1 or edits[1][1] ~= "" then table.insert(R, path .. ": MISSING") return end
		local parentPath, name = string.match(path, "^(.*)%.([^%.]+)$")
		local parent = find(parentPath)
		if not parent then table.insert(R, path .. ": NO PARENT") return end
		inst = Instance.new(cls)
		inst.Name = name
		src = ""
		inst.Parent = parent
	else
		src = inst.Source
	end
	for i, e in edits do
		if e[1] == "" then src = e[2] else
			local a, b = string.find(src, e[1], 1, true)
			if not a then table.insert(R, path .. ": hunk " .. i .. " not found") return end
			if string.find(src, e[1], b + 1, true) then table.insert(R, path .. ": hunk " .. i .. " not unique") return end
			src = string.sub(src, 1, a - 1) .. e[2] .. string.sub(src, b + 1)
		end
	end
	if #src ~= len or hash(src) ~= hv then table.insert(R, path .. ": MISMATCH " .. #src .. "/" .. len) return end
	inst.Source = src
	table.insert(R, path .. ": ok")
end
_G.ZR_hash = hash
return "lib installed"
"""


def main():
    args = sys.argv[1:]
    if args == ["--lib"]:
        (PAD / "studio_patch_lib.luau").write_text(LIB)
        print(LIB)
        return
    if args == ["--done"]:
        pend = json.loads(PENDING.read_text())
        for rel in pend:
            dst = BASE / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text((ROOT / rel).read_text())
        PENDING.unlink()
        print("studio base updated:", len(pend), "files")
        return
    if not args:
        r = subprocess.run(["git", "status", "--porcelain", "--", "src"], cwd=ROOT, capture_output=True, text=True)
        args = [l[3:] for l in r.stdout.splitlines() if l[3:].endswith(".luau")]
    lua = ['local P = _G.ZR_patch', 'if not P then return "NO_LIB: run tools/studio_patch.py --lib first" end', 'local R = {}']
    pend = {}
    total = 0
    for rel in args:
        new = (ROOT / rel).read_text()
        old = base_of(rel)
        if old == new:
            continue
        if old is None:
            edits = [("", new)]
        else:
            edits = hunks(old, new) or [("", new)]
        body = ", ".join("{%s, %s}" % (long(o) if o else '""', long(n)) for o, n in edits)
        size = sum(len(o) + len(n) for o, n in edits)
        total += size
        lua.append('P(R, "%s", "%s", {%s}, %d, %d)' % (inst_path(rel), class_of(rel), body, len(new.encode()), h(new.encode())))
        pend[rel] = True
        print(f"{rel}: {len(edits)} edit(s), {size} chars -> {inst_path(rel)}")
    lua.append('return table.concat(R, "\\n")')
    OUT.write_text("\n".join(lua) + "\n")
    PENDING.write_text(json.dumps(pend))
    print(f"snippet: {OUT} ({OUT.stat().st_size} bytes, {total} chars of edits)")


if __name__ == "__main__":
    main()

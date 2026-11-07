#!/usr/bin/env python3
"""The code gate (audit tech-8): run before every sync and before every commit.

Always:   tools/luau_check.py (strings, brackets, blocks) and tools/luau_lint.py (undefined globals, missing locals).
If found: selene (lint), StyLua --check (format, advisory) and luau-lsp analyze (types), the tools pinned in
          rokit.toml. Install them once with `rokit install` in the repo folder; the gate picks them up from PATH.
Usage: python3 tools/gate.py [paths...]   (default: src). Exit status 1 when a required check fails.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def run(label, cmd, required=True):
    print(f"── {label}: {' '.join(cmd)}")
    r = subprocess.run(cmd, cwd=ROOT)
    ok = r.returncode == 0
    print(f"── {label}: {'ok' if ok else ('FAILED' if required else 'advisory: differences found')}")
    return ok or not required


def main(argv):
    paths = argv or ["src"]
    ok = True
    ok &= run("structure", [sys.executable, os.path.join(HERE, "luau_check.py")] + paths)
    ok &= run("globals", [sys.executable, os.path.join(HERE, "luau_lint.py")] + paths)
    if shutil.which("selene"):
        ok &= run("selene", ["selene"] + paths)
    if shutil.which("stylua"):
        run("stylua", ["stylua", "--check"] + paths, required=False)
    if shutil.which("luau-lsp"):
        defs = os.path.join(ROOT, "tools", "globalTypes.d.luau")
        cmd = ["luau-lsp", "analyze"]
        if os.path.exists(defs):
            cmd.append(f"--definitions={defs}")
        if os.path.exists(os.path.join(ROOT, "sourcemap.json")):
            cmd.append("--sourcemap=sourcemap.json")
        ok &= run("types", cmd + paths)
    print("gate:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

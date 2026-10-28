#!/usr/bin/env python3
"""Print device_commit_files JSON for the most recent staged run (one batch of <=50 per line)."""
import json, pathlib
runs = sorted(pathlib.Path("/mnt/user-data/outputs/ZR").glob("run_*"))
OUT = runs[-1]
DEV = "C:\\Users\\lenovo\\Documents\\EscapeFromBloxov\\"
fs = sorted(f for f in OUT.rglob("*") if f.is_file())
b = [{"stagedPath": str(f), "devicePath": DEV + f.relative_to(OUT).as_posix().replace("/", "\\")} for f in fs]
for i in range(0, len(b), 50):
    print(json.dumps(b[i:i + 50], separators=(",", ":")))

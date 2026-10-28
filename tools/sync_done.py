#!/usr/bin/env python3
"""Mark the pending staged files as synced (call after device_commit_files succeeded)."""
import json, pathlib
STATE = pathlib.Path("/tmp/claude-0/-home-claude/6a163997-7a90-5ac1-b594-c3c8d7a21bf5/scratchpad/sync_state.json")
pend = STATE.with_suffix(".pending.json")
state = json.loads(STATE.read_text()) if STATE.exists() else {}
if pend.exists():
    state.update(json.loads(pend.read_text())); pend.unlink()
STATE.write_text(json.dumps(state)); print("synced entries:", len(state))

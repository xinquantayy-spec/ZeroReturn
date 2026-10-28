# Tool audit (2026-10-28)
| Tool | Exact tool name/version | Read-only probe result | Write allowed? | Limitations |
|---|---|---|---|---|
| Blender bridge | Blender MCP addon 1.8 on Blender 5.2.3 | Scene info returned | Yes, inside the project folder only | Never reset the user's scene; use a separate `ZR_Assets` scene |
| Rojo CLI/plugin | Rojo 7.7.1 via Rokit, port 34873 | Serve and plugin connected | Yes, one-way sync | Two-way sync is off |
| Roblox Studio bridge | Studio MCP (execute_luau, start_stop_play, input, console, screen_capture) | Studio state returned | Yes | No RobloxScript capability; `character_navigation` cannot drive the custom character |
| git | git in the cloud workspace | Status OK | Local commits only | No pushes; a bundle backup is copied to the PC |
| optional formatter/linter | `tools/luau_check.py` (structural) | Passes on 41 files | n/a | Not a type checker: no network for luau-lsp or selene |

No integration is claimed unless a read-only call has returned successfully.

# Action map and platform acceptance

Roblox official docs recommend the Input Action System for multi-platform gameplay, `UserInputService.PreferredInput` for primary modality, and adaptive UI. Claude must inspect current API before implementation and use ContextActionService as a documented fallback only if necessary.

| Action | PC | Gamepad | Touch |
|---|---|---|---|
| Move/look | WASD + mouse | left/right sticks | virtual left stick + right swipe |
| Fire | Mouse1 | RT | fire button (right) |
| ADS | Mouse2 held/toggle option | LT | ADS button toggle |
| Reload | R | X/Square | reload icon |
| Interact/loot | E | X/Square (context) | contextual touch button |
| Sprint | Shift | left stick click | sprint toggle |
| Crouch | C / Ctrl | B/Circle (when out of menu) | crouch icon |
| Jump/vault | Space | A/Cross | jump icon |
| Inventory | Tab | Y/Triangle | backpack icon |
| Quick heal | H | D-pad up | med icon or inventory |
| Extraction list | O | D-pad down (hold) | objective icon |
| Back/cancel | Esc/menu | B/Circle in menu | close button |

Bindings are suggestions and must be adjusted for simultaneous reload/interact conflicts; contexts should change meaning when opening menu/loot interface. Console cannot use unsupported keyboard-only operations. Preserve platform menu reservations.

## UI states and context switching
`PLAY`, `INTERACT`, `INVENTORY`, `SAFEHOUSE`, `SPECTATE`, `POST_RAID`, `SETTINGS`. State-driven input contexts, not independent local scripts fighting over controls. When inventory opens, suppress fire and hide touch fire button; gamepad cursor focus through visible `GuiObject.Selectable` elements; a universal back action. Inventory must work with d-pad/analog focus and tap-to-transfer; no tiny inventory grid required for touch.

## Aim assist fairness
Do NOT implement wallhack-like snap lock. Optional subtle controller/touch aim friction tuned separately; server still validates shots. Provide defaults and control sensitivity settings; avoid randomized hidden recoil different by platform.

## Acceptance matrix
- PC: walking, looking, firing, ADS, reload, loot, inventory, extract, trading.
- Touch phone: landscape interface has no clipping, buttons reachable by thumbs, raid navigable with thumbs, item transfers possible without drag, effects off by default on low preset.
- Tablet: labels/buttons not absurdly oversized or minuscule.
- Xbox/PlayStation controller: all main actions and every modal selectable without mouse; menu focus remains visible; no focus trap or mismatched X/Square labels.
- Hot-switch PC/gamepad and tablet/gamepad mid-session updates hints without restarting.
- Simulated devices are presentation validation, not equivalent to real phone/console hardware performance and ergonomics.

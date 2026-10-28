# Real cross-platform performance contract

## Hard discipline
No broad statement of 'mobile optimized' without testing on real mobile hardware. Roblox's Device Simulator is for behavior/layout; Studio PC memory/FPS do not represent a baseline phone. Profile on low-end phone after every art + systems milestone. Console needs physical platform test for certification-level claims; gamepad emulator is only partial coverage.

## Initial targets (benchmarks, NOT guaranteed results)
- Baseline phone chosen by owner: stable 30 FPS in raid for >=10 active minutes, no sustained thermal degradation, usable touch FPS controls, no out-of-memory. Cap/adjust render quality based on settings.
- Midrange phone 45–60 FPS aspirational; PC/console 60 FPS target where device permits.
- Loading: lightweight safehouse first; world streaming used; no multi-second freeze when a gun fires, chest opens or AI spawns.
- Visible scene target as starting hypothesis: <700 draw calls and <700k rendered triangles at baseline bottleneck; Roblox sample guide discusses staying below ~1000 draw calls / 1m triangles on chosen baseline. Measure and tune rather than assume these numbers enforce FPS.
- GUI update > necessary? Rarely; dynamic camera overlay pieces event-driven except timestamp tick (1Hz). No RenderStepped loops for every UI widget.
- No more than 4 high-priority dynamic shadow lights in view; preferably fewer. No 50+ dynamic unanchored physical props, no real projectile Parts for every bullet.

## Profiling procedure
1. Use `Stats`, Performance Summary and MicroProfiler to measure GPU frame time, drawcalls, triangles, instance/texture memory, script time, network bandwidth and ping. Record device model and graphics setting.
2. Baseline test: 10-min AI firefight loop, 2-player raid, opening inventory while moving and firing, high camera motion, busiest map section, low battery/power saving if practical.
3. If frame drops: inspect hotspot; reduce shadow-casting lights/materials, poly/texture atlas count, number of visible props/particles, excessive UI update loops and replication burst before lowering world dimensions.
4. Enable/verify `Workspace.StreamingEnabled` as relevant; test LocalScript handling of temporarily missing models. Don't mark all world props persistent.
5. Test mobile over unstable Wi-Fi/network simulator; ensure loot/shot state coherently recovers without desync. Avoid sending bullet effects to all distant players.

## Quality settings
`LOW`: no film grain, reduced fog/emission, lower shadow scope, fewer decor meshes, essential loot props always visible, simplified distant textures. `MEDIUM`: subtle color correction, some ambient fx. `HIGH`: richer props/audio/soft lighting but no functionality differences. HUD always readable. Distortion is a user option, off on low and with Reduce Motion.

## Accessibility and fairness
Adjustable FOV/sensitivity, subtitles/text for essential events, contrast mode for extraction marker, `Reduce Motion`, ADS toggle, optional reticle, legible UI, equal gameplay collision across LOD, gamepad focus, no epilepsy-risking strobe. Any audio-only key cue should have secondary visual cue.

## Sources
https://create.roblox.com/docs/performance-optimization/design
https://create.roblox.com/docs/performance-optimization/test-on-hardware
https://create.roblox.com/docs/performance-optimization/improve

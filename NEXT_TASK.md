# Next Task

**Current focus:** improvement program milestone **M10 — World** (Tarkov map feel with original places and art).

## M10 plan

1. **Time of day and weather.** Each raid rolls a time (day, dusk, night, dawn) and weather (clear, overcast, fog, rain). Lighting, fog and sky follow it; rain has particles, wet-surface tint, rain and wind ambience and muffled footsteps. Night raids are dark enough that weapon lights matter. The REC timestamp shows the raid's in-world time. AI sight range scales with light and fog.
2. **Loose loot.** Items lying on shelves, tables and floors (not only in containers) from spawn tables with rarity per location; physical item models (procedural per item kind); picked up with F into the raid inventory as found-in-progress. Keys and the keycard spawn as loose loot in fixed rare spots.
3. **New places.** A two-storey **crew dormitory** with several locked rooms (each with its own key found in the raid) and good loot, and a **vault** behind a keycard door (RUSTED_KEYCARD, few uses) with high-value loot. More ordinary doors across existing buildings.
4. **Doors for everyone.** Unlocked doors can be opened and closed by players and AI (AI open doors on their path); doors block sight and muffle sound when closed.
5. **Blender art.** Re-author weapon meshes against the `WeaponModels` anchors (first and third person) and the main gear pieces (plate carrier, chest rig, helmet, backpack) as Blender meshes uploaded through Open Cloud; record them in `ASSET_MANIFEST.md`.
6. **Audio.** Atlas additions: rain, wind gusts, door creaks and locks, key jingle, loose-loot pickup, UI clicks; distant gunfire ambience during raids.
7. Logic tests, Studio test (screenshots of each time of day and weather), docs, commit.

Then M11 (QA: two-client test, device emulation, performance, exploit regression including vault speed checks, scrollable inventory gear column, docs, git bundle backup).

## Resume steps

1. Read `DEVELOPMENT_STATUS.md` and `KNOWN_ISSUES.md`.
2. Start `rojo serve --port 34873` in `Documents\EscapeFromBloxov`; connect the Rojo plugin in Place3.
3. Play, then run `ZR_Dev:Invoke("tests")` (baseline **134/134**).

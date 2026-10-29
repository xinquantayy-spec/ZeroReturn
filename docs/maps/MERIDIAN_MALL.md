# Meridian Mall (M13): design

An abandoned two-level shopping mall with a rooftop car park, loading docks and a surface car park. It plays
like Tarkov's mall map (big dark interior, a central atrium, anchor stores with keyed loot rooms, a power switch
that lights the mall and opens an exit, a roaming heavy boss) but the layout, stores, names and art are original.
Raid time 25 minutes.

Built by `src/server/Maps/MeridianMall.luau` at origin **(-1600, 0, 0)**. Local coordinates: x east, z south,
y up. Ground level y = 0, the upper level (L2) y = 18, the main roof y = 36.

## Plan

```
            z=-152 ──────────────── NORTH YARD (docks, trucks, generator compound, sewer grate) ─────────────
            z=-96  ┌───────────── service corridor (L1, z -96..-84), cargo lift at x 64..76 ──────────────┐
                   │ SUPERMARKET │ storerooms z -84..-64                                  │ KITCHEN       │
                   │  "KASSA"    │ N1 BOLTWORKS │ N2 MEDIQ │ N3 VOLTA     │ N4 KAVA │ N5   │ FOOD COURT    │
                   │  x -160..-96│ x -96..-56   │ -56..-32 │ -32..32,     │ 32..56  │ BANK │ x 96..160     │
                   │  one level, │              │          │ z -64..-40   │         │56..96│ (L2: CINEMA   │
                   │  roof car   ├──────────────┴──────────┤   ATRIUM     ├─────────┴──────┤  "LUMEN")     │
                   │  park y=18  │  CONCOURSE z -16..16     │ x -32..32    │   CONCOURSE    │               │
                   │             ├──────────────┬──────────┤ z -40..40    ├─────────┬──────┤               │
                   │             │ S1 NORDA     │ S2 TOYBOX│  LOBBY x±16  │ S3 PEAK │ S4   │               │
                   │             │ -96..-56     │ -56..-32 │  z 40..72    │ LINE    │AURUM │               │
            z=72   └─────────────┴── storerooms z 56..72 ─┴── main doors ┴─────────┴──────┴───────────────┘
            z=80..188  SOUTH CAR PARK (abandoned cars, light poles, trolley bays, bus shelter), main road z 188..200
   x=-210 west road + broken car ramp up to the roof car park                      x=210 east road, staff car park
```

### Ground level (L1)

| Area | Bounds (x, z) | Notes |
|---|---|---|
| Supermarket KASSA | -160..-96, -96..72 | Checkouts across the concourse entrance, 8 rows of stocked gondolas, fridge wall, bakery counter, trolley bay; warehouse with pallet racking at the back (z -96..-72). |
| N1 BOLTWORKS (hardware) | -96..-56, -64..-16 | Tool walls, paint, a toppled shelf; toolboxes. |
| N2 MEDIQ (pharmacy) | -56..-32, -64..-16 | Counter, shelves, a keyed dispensary (KEY_MEDIQ): medbags. |
| N3 VOLTA (electronics) | -32..32, -64..-40 | Faces the atrium. TV wall, laptop tables, phone counter; keyed store room (KEY_VOLTA_STORE): tech loot, graphics cards. The Caretaker's home. |
| N4 KAVA (café) | 32..56, -64..-16 | Counter, tables. |
| N5 MERIDIAN SAVINGS (bank) | 56..96, -64..-16 | Teller counter, offices, vault behind a keycard door (CARD_MALL_VAULT). |
| S1 NORDA (clothing) | -96..-56, 16..56 | Racks, mannequins, fitting rooms. |
| S2 TOYBOX | -56..-32, 16..56 | Junk loot. |
| S3 PEAKLINE (sports and outdoor) | 32..56 + 56..96, 16..56 | Hunting counter (weapon boxes, ammo), treadmills, ball cage. |
| S4 AURUM (jeweller) | 56..96, 16..56 | Smashed display cases; valuables. |
| Concourse | -96..96, -16..16 | Terrazzo, columns, benches, planters, a burnt kiosk, directory boards. |
| Atrium | -32..32, -40..40 | Dry fountain with an original ring sculpture; two crossing escalators (stopped); skylight. |
| Entrance lobby | -16..16, 40..72 | Double height, glass front, main doors to the car park. |
| Food court | 96..160, -64..56 | Seating hall, 6 counters, tipped tables; kitchen behind (z -84..-64) with the staff exit (KEY_MALL_STAFF). |
| Service corridor | -158..158, -96..-84 | Back doors of every store, dock doors, the cargo lift, a collapsed ceiling run. |

### Upper level (L2, y = 18)

| Area | Bounds | Notes |
|---|---|---|
| Gallery | void x -20..20, z -26..26 | Balustrades (some glass broken), escalator heads. |
| Mall offices and SECURITY | -96..-60, -64..-16 | Security office (KEY_MALL_SECURITY): weapon box, camera desk, keys. |
| NESTA (homewares) | -60..-32, -64..-16 | Sofas, beds, tables. |
| PIXEL PALACE (arcade) | -32..32, -64..-40 | Arcade cabinets, prize counter. |
| MODA (clothing) | 32..60, -64..-16 | |
| IRON YARD (gym) | 60..96, -64..-16 | Treadmills, weight racks. |
| ALMA (department store) | -96..-32, 16..56 | Racks, mannequins, perfume counters. |
| INKWELL (books, office) | 32..60, 16..56 | Office loot. |
| FUNZONE (soft play) | 60..96, 16..56 | Ball pit, soft play frame. |
| Cinema LUMEN | 96..160 | Lobby (ticket booth, concessions) x 96..128, z -24..24; Screen 1 north, Screen 2 south: stadium seating rising east, projection booths at the top. |
| Roof car park | -160..-96, -96..72 (y = 18) | Level with L2, through the west glass doors; parked cars, barriers, the broken ramp. |

### Damage and imperfection (structure)

- A section of the L2 gallery floor north-east of the atrium has collapsed onto L1: a tilted slab with rebar
  and rubble that can be climbed between the levels.
- Missing and sagging ceiling tiles, dangling light fittings and cables, a collapsed ceiling run in the service
  corridor.
- Broken skylight panes over the atrium with glass and leaves on the fountain floor.
- Smashed storefront glass, bent and half-open roller shutters, a wall breach between BOLTWORKS and MEDIQ.
- The car ramp broken at mid-span (cannot be driven or walked across).
- Water damage (stains, puddles), litter, graffiti, spalled columns, cracked terrazzo.

## Rules

- **Power:** the generator in the north yard compound (hold F for 3 s). "GENERATOR STARTING", then after 9 s
  the mall's ceiling lights come on for the rest of the raid, the CARGO LIFT exfil works, everyone in the raid
  gets the new exit state (O shows POWER ON) and the player who started it sees "POWER ON". Before that the
  interior is dark apart from daylight under the skylight, the glass fronts, the green exit signs and a few
  orange emergency lamps. Every new raid starts with the power off.
- **Exfils:** BUS DEPOT (open, west), SERVICE RAMP (open, north-east), CARGO LIFT (needs power), TAXI RANK
  (paid 6,000), STAFF EXIT (KEY_MALL_STAFF), SEWER GRATE (scavs).
- **Spawns:** west road (2), south car park (3), east road (2), north yard (2); each side exits on the far side.
- **AI:** scavs through the concourse, atrium, stores, food court, cinema, car parks and yard; Mall Security
  (Watch) at the security office, the L2 gallery and the docks; **the Caretaker**, a heavily armoured boss who
  roams the atrium, the concourse and VOLTA (some raids). AI move between the levels on the escalators, the
  stair cores, the collapsed slab and the car ramp; the cinema's stadium seating has a side aisle with half
  steps so they can reach the projection booths.
- **No barbed wire** on the building (the map model carries `NoWire`; the detail plan skips wall-cap wire).

## Performance

- Big flat surfaces are Parts with MaterialVariants (terrazzo, floor tiles, ceiling tiles, vinyl, carpet,
  plaster, concrete): one part per surface, no meshes.
- 3D detail is the Blender kit (`ZR_MallKit*` batches): each prop is split by material into MeshParts that share
  one origin; colour, ambient occlusion and grime are baked into vertex colours, and Roblox materials tile at a
  fixed studs-per-texture on meshes (verified, see `docs/PIPELINE.md`), so every prop has the same texel density
  with no texture memory of its own. Repeated props are instances of one mesh.
- Light: emissive panels (Neon on power), a few unshadowed PointLights per area, daylight from the skylight.
- Small clutter (litter, papers, debris, wall fittings) comes from the client detail layer near the camera,
  scaled by the GRAPHICS setting.
- Kit props indoors cast no sun shadows (their contact shadows are baked; the roof shades the interior anyway).
- Depth of field (HIGH only) switches off under a roof: nothing indoors is far enough to blur, and it was the
  most expensive post effect.
- Interior walls get rain streaks only now and then and peeling plaster in patches, not whole-wall layers.

### Measured (2026-10-29, Studio on the T490)

Frames per second from a RenderStepped count. Studio runs the client and the server in one process, so these
are lower than a real client; they are comparisons, not device numbers. Our GRAPHICS setting on HIGH; "q" is
Roblox's own render quality (Studio renders at 21, the maximum; devices pick their own level, phones low).

| View | q21 | q10 | q5 |
|---|---|---|---|
| Quay 7 yard (reference) | 30.1 | 60.1 | 60.0 |
| Atrium | 26.3 | 45.8 | 60.1 |
| Gallery (L2) | 25.6 | 48.8 | 60.0 |
| Concourse | 29.3 | 49.6 | 60.0 |
| Supermarket | 28.9 | 49.3 | 60.0 |
| Food court | 31.4 | 57.3 | 60.0 |
| Surface car park | 28.2 | 57.7 | 60.1 |
| Roof car park | 27.5 | 56.9 | 60.0 |

60 is the frame cap. Before this pass the atrium ran at 23–24 (q21) and 45 (q10), the gallery at 22–23 and 43–47.
What a frame costs indoors (A/B toggles, q10): sun shadows about 5 ms, wall decals 2–3 ms, all kit meshes about
2 ms, the AI about 1 ms; lights (110 with the power on) and glass made no measurable difference. All 114k
triangles of the supermarket shelving cost about 1 ms at q10 and 2.5 ms at q21.

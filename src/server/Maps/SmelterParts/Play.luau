--!nonstrict
-- Smelter play layer (part 2 of 3): everything a raid needs on top of the shell.
--   extracts   EFT Factory's nine (docs/maps/reference/FACTORY_REFERENCE.md section 6) with our names: ORE GATE (Gate 3,
--              PMCs and scavs), SLAG GATE (Gate 0), AID POST GATE (Med Tent Gate, behind the emergency key's door), CABLE
--              CELLAR (Cellars, behind the same key's door), YARD GATE (Courtyard Gate), COKE GATE (Gate 2), BUNKER
--              HATCH and SHIFT OFFICE WINDOW (scavs: Camera Bunker Door, Office Window), SMUGGLERS' CRAWL (the hidden
--              exit; built once its note item exists). One entry point: every PMC exit serves every spawn (SPT).
--   transit    TRANSIT TO BORDER YARD at the east yard's gate (EFT: Factory's transit to Customs, east exterior)
--   spawns     one per SPT player group (16; the re3mr plan's PMC rings), facing as SPT has them
--   AI         scav posts on four routes (EFT's Factory has scavs only), the SPT bot and boss points as scav zones
--   bosses     THE STOKER (Tagilla) at 30 %, from any of SPT's seven boss points, on the hall loop; THE CULT at night
--   tasks      W.visitZones STACK, SM_CATWALK, SM_MANAGER, SM_CASTING, SM_PUMPHOUSE, SM_SIDING re-placed on this layout
--   doors      the emergency key's three doors, the records and shift office doors, the sealed store's card door
--   loot       the containers and loose spots the layout lists (positions ours, SPT's counts by kind)
-- Coordinates: the layout's studs; P(x, z, level) takes the reference's metres for the hand-placed spots below.
return function(B)
	local kit, W, H, L, map = B.kit, B.W, B.H, B.L, B.map
	local hex, M = kit.hex, kit.M
	local V, O, S = H.V, B.O, B.S
	local LV = L.LV
	local count = B.count
	local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("Items"))

	local function try(name, f)
		local ok, err = pcall(f)
		if not ok then
			warn("[ZR] Smelter play: " .. name .. " failed: " .. tostring(err))
		end
	end
	-- a reference point (metres) on a level (local studs, world vector)
	local function P(x, z, y)
		return V(x * S, y, z * S)
	end
	-- the nearest of our place names (labels), preferring one on the same floor (within 6 studs of height)
	local function near(list, x, z, y)
		local best, bd = nil, math.huge
		for _, it in list do
			local d = (it[2] - x) ^ 2 + (it[4] - z) ^ 2
			if y and math.abs((it[3] or 0) - y) > 6 then
				d += 1e6
			end
			if d < bd then
				best, bd = it, d
			end
		end
		return best
	end

	-- ── extracts ─────────────────────────────────────────────────────────────────────────────────────────
	-- rules (SPT factory4_day/night exits and allExtracts; re3mr; tarkovforge): hold 10 s for PMCs, 8 s for scavs in
	-- EFT (ours: the game's one hold time); `who = "pmc"` keeps PMC-only exits from scavs (Extract.scavMay)
	local RULE = {
		G3 = { kind = "open" }, -- Gate 3: PMCs and scavs, always
		G0 = { kind = "open", who = "pmc" }, -- Gate 0: PMCs (SPT DisabledScavExits "Cellars,Gate 0")
		GM = { kind = "open", who = "pmc" }, -- Med Tent Gate: PMCs; its passage door takes the emergency key (SM_GATEDOOR)
		CL = { kind = "open", who = "pmc" }, -- Cellars: PMCs; the tunnel door takes the emergency key (SM_CELLAR)
		GY = { kind = "open", who = "pmc" }, -- Courtyard Gate ("Gate_o"): PMCs
		G2 = { kind = "open", who = "pmc" }, -- Gate 2: PMCs (1.x lists; its conditions are unpublished: ours open)
		CB = { kind = "scav" }, -- Camera Bunker Door
		OW = { kind = "scav" }, -- Office Window
	}
	-- zone sizes (studs, ours): the gate's width and the room in front of it
	local SIZE = {
		G3 = Vector3.new(16, 12, 16), G0 = Vector3.new(16, 12, 12), GM = Vector3.new(12, 12, 16), CL = Vector3.new(9, 9, 14), GY = Vector3.new(10, 12, 18),
		G2 = Vector3.new(16, 12, 12), CB = Vector3.new(10, 9, 10), OW = Vector3.new(5, 8, 6), SC = Vector3.new(8, 9, 8),
	}
	local UNDER = { CL = true, CB = true, SC = true }
	W.sideExtracts = { all = {} }
	try("extracts", function()
		local ex = kit.model("Extracts", map)
		-- the hidden exit takes the note with its code word (EFT 0.16: "factory_secret_ark"); built once the item exists
		local NOTE = "NOTE_SMELT_CRAWL"
		local noteOk = Items.defs[NOTE] ~= nil and Items.defs[NOTE].kind == "key"
		for _, e in L.extracts do
			local id, name, x, y, z, sides = e[1], e[2], e[3], e[4], e[5], e[6]
			local rule = RULE[id]
			if id == "SC" then
				rule = noteOk and { kind = "key", key = NOTE } or nil
				if not noteOk then
					print("[ZR] Smelter: SMUGGLERS' CRAWL waits for its note item " .. NOTE)
				end
			end
			if rule then
				kit.extract(ex, id, name, V(x, y + 0.1, z), SIZE[id] or Vector3.new(12, 10, 12), table.clone(rule), UNDER[id] and { compact = true } or nil)
				if string.find(sides, "pmc", 1, true) then
					table.insert(W.sideExtracts.all, id)
				end
			end
		end
	end)

	-- the gates the exits stand at: a steel gate leaf on the wall (ours; EFT has numbers painted on them, we do not)
	try("gates", function()
		local gm = kit.model("Gates", map)
		local GATE = hex("3F4A4C")
		-- x, z (metres), the wall the leaf hangs on ("x": the wall runs along x), width, height (studs), level
		-- on the inner face of the wall each gate is in (the reference's outline): Gate 3's west end, Gate 0's south end,
		-- the Med Tent Gate passage's east end, the courtyard's west wall, the east yard's north wall (Gate 2) and east edge
		-- (the transit), the cellar tunnel's north end
		local GATES = {
			{ -64.24, -53.0, "z", 14, 13, 0 }, { -54.3, 71.1, "x", 16, 13, 0 }, { 62.75, 23.4, "z", 16, 13, 0 }, { -64.93, -15.0, "z", 14, 12, LV.west },
			{ 47.0, -42.05, "x", 14, 12, 0 }, { 54.8, -11.9, "z", 16, 12, 0 }, { 31.6, -71.15, "x", 8, 7, LV.basement },
		}
		for _, g in GATES do
			local cf = CFrame.new(P(g[1], g[2], g[6] + g[5] / 2))
			if g[3] == "z" then
				cf *= CFrame.Angles(0, math.rad(90), 0)
			end
			local leaf = kit.boxCF(gm, g[4], g[5], 0.5, cf, GATE, M.CorrodedMetal)
			leaf:SetAttribute("NoDetail", true)
			for k = -1, 1 do
				kit.boxCF(gm, g[4], 0.35, 0.7, cf * CFrame.new(0, k * g[5] * 0.32, 0), hex("2C3334"), M.Metal)
			end
		end
	end)

	-- ── the transit (EFT 0.15: Factory's transit to Customs at the east exterior gate; SPT: open after 60 s, 20 s) ──
	try("transits", function()
		local t = L.transits[1]
		if t then
			local p = V(t[2], t[3] + 0.1, t[4])
			W.transits = {
				{ id = "TR_BORDER", name = "TRANSIT TO BORDER YARD", to = "border", pos = p, size = Vector3.new(14, 10, 14), cf = CFrame.new(p + Vector3.new(0, 4.5, 0)) },
			}
		end
	end)

	-- ── spawns: one per SPT player group, named after the nearest of our places ──────────────────────────────
	try("spawns", function()
		local spawns, used = {}, {}
		for i, s in L.spawns do
			local x, y, z, face = s[1], s[2], s[3], s[4]
			local pos = V(x, y + 3.4, z)
			local look = Vector3.new(math.cos(math.rad(face)), 0, math.sin(math.rad(face)))
			local lb = near(L.labels, x, z, y)
			local base = lb and lb[1] or "SMELTER"
			used[base] = (used[base] or 0) + 1
			local name = used[base] > 1 and (base .. " " .. used[base]) or base
			table.insert(spawns, { id = "F" .. i, name = name, cf = CFrame.lookAt(pos, pos + look), side = "all", extracts = W.sideExtracts.all })
		end
		W.spawns = spawns
		count.spawns = #spawns
	end)

	-- ── AI: scav posts on four routes, the SPT bot and boss points as scav zones ─────────────────────────────
	try("ai", function()
		W.patrols = {}
		for id, pts in L.routes do
			local r = {}
			for _, p in pts do
				table.insert(r, V(p[1], p[2], p[3]))
			end
			W.patrols[id] = r
		end
		-- EFT's Factory has scavs only (no raiders or rogues): the posts are scav posts (audit ai-1a)
		W.watchPosts = {
			{ route = "HL", label = "Hall Scav", kind = "scav" },
			{ route = "FN", post = V(L.routes.FN[2][1], L.routes.FN[2][2], L.routes.FN[2][3]), label = "Furnace Scav", kind = "scav" },
			{ route = "TN", label = "Tunnel Scav", kind = "scav" },
			{ route = "WW", post = V(L.routes.WW[1][1], L.routes.WW[1][2], L.routes.WW[1][3]), label = "Office Scav", kind = "scav" },
		}
		local zones = {}
		for _, p in L.scav do
			table.insert(zones, V(p[1], p[2], p[3]))
		end
		for _, p in L.boss do
			table.insert(zones, V(p[1], p[2], p[3]))
		end
		W.scavZones = zones
	end)

	-- ── bosses ───────────────────────────────────────────────────────────────────────────────────────────
	-- THE STOKER (EFT's Tagilla on Factory: 30 % day and night, any of the boss spawn points, no escort; SPT
	-- BossLocationSpawn; LogicTests pins 30 %, 1,220 health and the hammer). Each SPT boss point is a zone; from it he
	-- walks the hall loop. THE CULT (EFT's cultists on Night Factory: any scav spawn; ours three dark spots; 8 % as the
	-- AI audit has it, docs/design/BOSS_CULT.md; SPT 20 %, tarkovforge 15 % during the November 2026 event).
	try("bosses", function()
		local hall = W.patrols.HL
		local zones = {}
		for i, p in L.boss do
			local home = V(p[1], p[2], p[3])
			local lb = near(L.labels, p[1], p[3], p[2])
			table.insert(zones, { name = (lb and lb[1] or "THE HALL") .. " " .. i, home = home, route = hall })
		end
		local stoker = {
			name = "THE STOKER", label = "Stoker", home = zones[1].home, route = hall, look = "stoker", loadout = "stokerLoadout", crew = {},
			chance = 0.3, hp = 1220 / 440, charge = true, zones = zones,
		}
		local cultZones = {}
		for _, c in L.cult do
			local home = V(c[2], c[3], c[4])
			local crew = {}
			for k, q in c[5] do
				table.insert(crew, {
					pos = V(q[1], q[2], q[3]), label = "Cultist", look = "cultist", loadout = "cultistLoadout", hp = 850 / 440, skill = "boss",
					charge = "knife", ambush = true, post = true, chance = k == 3 and 0.5 or nil,
				})
			end
			table.insert(cultZones, { name = c[1], home = home, post = home, crew = crew })
		end
		local cult = {
			name = "THE CULT", label = "Priest", home = cultZones[1].home, route = nil, look = "priest", loadout = "priestLoadout",
			chance = 0.08, night = true, hp = 850 / 440, skill = "boss", charge = "knife", ambush = true, zones = cultZones,
		}
		W.boss = nil
		W.bosses = { stoker, cult }
	end)

	-- ── task places (economy-6a's map tasks, ids kept; QuestData's zone table says where each is now) ─────────────
	try("tasks", function()
		local T3, S2 = LV.third, LV.second
		W.visitZones = W.visitZones or {}
		-- V6 Slag Run: the slag heap in the east yard (Dress heaps it there)
		W.visitZones.STACK = { pos = P(50.0, -22.0, 0), r = 14 }
		-- D7 Relay Watch: a beacon on the catwalks over the main hall (the rafters, south of the beam)
		W.visitZones.SM_CATWALK = { pos = P(-6.0, -13.8, T3 + 0.3), r = 5, free = true, reach = 4 }
		-- K12 Furnace Readings: the furnace log on the manager's desk (third floor, behind SM_MGR and the emergency key)
		W.visitZones.SM_MANAGER = { pos = P(-37.9, -26.4, T3 + 2.76), r = 4 }
		B.points.MANAGER_DESK = P(-37.9, -26.4, T3)
		-- H14 Reagents: the reagent case on the aid post's table (EFT's Med Tent)
		W.visitZones.SM_CASTING = { pos = P(30.5, 23.5, 2.76), r = 4 }
		B.points.AID_TABLE = P(30.5, 23.5, 0)
		-- K3 Static: a beacon inside the pump house (EFT's Pumping Station, its ground floor)
		W.visitZones.SM_PUMPHOUSE = { pos = P(12.6, -34.4, 0.3), r = 5, free = true, reach = 5 }
		-- K14 Black Box: a camera beside the hopper wagons on the rail siding through the hall
		W.visitZones.SM_SIDING = { pos = P(-23.4, -14.0, 0.3), r = 6, free = true, reach = 6 }
		B.points.SIDING = P(-25.5, -20.0, 0)
		local _ = S2
	end)

	-- ── doors ────────────────────────────────────────────────────────────────────────────────────────────
	-- EFT: the Factory emergency exit key (20 uses) opens the Med Tent Gate passage, the Cellars door and the third-floor
	-- locked office; ours is KEY_SMELT_OFFICE (REQUEST: rename it). The breach room's door is an ordinary closed door
	-- here (no breaching yet). The sealed store (EFT's TerraGroup storage room) takes a card once the item exists.
	try("doors", function()
		local dm = kit.model("Doors", map)
		local CARD = "KEY_SMELT_STORE"
		for _, d in L.doors do
			local id, label, x, y, z, w, h, axis, key = d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9]
			local cf = CFrame.new(V(x, y + h / 2, z))
			if axis == "z" then
				cf *= CFrame.Angles(0, math.rad(90), 0)
			end
			local card = false
			if key == "CARD" then
				if Items.defs[CARD] and Items.defs[CARD].kind == "key" then
					key, card = CARD, true
				else
					key = nil
					print("[ZR] Smelter: the sealed store stays unlocked until its card item " .. CARD .. " exists")
				end
			elseif key == "" then
				key = nil
			end
			W.doors[id] = {
				id = id, cf = cf, size = Vector3.new(w - 0.1, h - 0.1, 0.35), key = key, card = card or nil, label = label, parent = dm,
				openChance = key == nil and 0.3 or nil, color = key and hex("4E5552") or hex("6E5E4A"),
			}
		end
	end)

	-- ── loot ─────────────────────────────────────────────────────────────────────────────────────────────
	try("loot", function()
		local lm = kit.model("Loot", map)
		local n = 0
		for _, c in L.containers do
			local id, kind, label, x, y, z, face = c[1], c[2], c[3], c[4], c[5], c[6], c[7]
			local pos = V(x, y, z)
			local look = Vector3.new(math.cos(math.rad(face)), 0, math.sin(math.rad(face)))
			kit.container(lm, id, kind, label, CFrame.lookAt(pos, pos + look))
			n += 1
		end
		count.containers = n
		local nl = 0
		for _, l in L.loose do
			kit.loose(O.X + l[1], l[2], O.Z + l[3], l[4], l[5], "smelter", true)
			nl += 1
		end
		count.loose = nl
	end)
end

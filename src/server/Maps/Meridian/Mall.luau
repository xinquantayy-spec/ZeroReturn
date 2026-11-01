--!nonstrict
-- Meridian Mall shell (mall agent, phase 2 of 3). The building at real scale on the reference's outline, empty and ready for the
-- stores: L0 car park with its columns, gates, zones A to D, the three garages, THE SHELTER, UNIT 14 and the service tunnel; L1 and
-- L2 slabs over it, three anchor halls, the store grid (every unit of L.mall.levels[i].stores as an empty fitted unit), atria with
-- balustrades, a roof with two domes and skylights, stairs, ramps and stopped escalators, dock bays, washrooms, the security room.
-- The geometry comes from a plan (MallPlan.luau: a raster of the layout with walls found as runs along grid lines); this file only
-- builds parts from it, in four steps (each under pcall, a failing step is logged and the rest still builds):
--   Mall        this file: context, helpers, order, summary line, B.units
--   MallShell   floors, unit floor plates, roof, domes, skylights, walls, store fronts, balustrades, door leaves, dock shutters
--   MallLinks   stairs, the ramp, escalators with their rails, the deck pieces at the dock ramps
--   MallFit     signs and stock rooms of the units, the anchors' checkouts, washrooms and security room, columns, L0 markings, lights
-- Map-local studs (x east, z south), world positions add the map origin O. Floor tops are exactly y 0, 17.81 and 47.50 (L.H).
-- B.units[id] = { id, name, kind, level, front, cframe, size, rect, floorY, ceilY, ... } for every unit, see docs/maps/MERIDIAN_MALL.md.
-- B.points: SHELTER_SWITCH (CFrame on the L2 men's room floor, look vector = the way the cabinet faces), SECURITY_TERMINAL (Vector3
-- in the L1 security room), SHELTER_DOOR (Vector3 at the shelter's card door), SHELTER_ROOM (Vector3 in the shelter).
-- Doors (W.doors, ids MM_*): THE SHELTER (CARD_MALL_VAULT) and UNIT 14 (KEY_MM_UNIT14), the security room (KEY_MALL_SECURITY), the
-- stock rooms of the anchors and of every deep store. Power: main lamps follow MALL_POWER through B.powerHooks (off at build);
-- the emergency lamps stay lit. Counts: B.count.mall (parts), B.count.light, B.count.door.
return function(B)
	local kit, W, H, L, O, map = B.kit, B.W, B.H, B.L, B.O, B.map
	local C, M, hex = kit.C, kit.M, kit.hex
	local t0 = os.clock()
	local Plan = require(script.Parent.MallPlan)
	local plan = Plan.build(L)
	local tPlan = os.clock() - t0
	for _, w in plan.warn do
		warn("[ZR] Meridian mall plan: " .. w)
	end
	local count = B.count or {}
	B.count = count
	for _, key in { "mall", "light", "door" } do
		count[key] = count[key] or 0
	end
	B.points = B.points or {}
	B.powerHooks = B.powerHooks or {}
	B.units = B.units or {}

	local ctx = {
		B = B, kit = kit, W = W, H = H, L = L, O = O, C = C, M = M, hex = hex, plan = plan, rng = B.rng,
		n = { parts = 0, lights = 0, doors = 0, shadows = 0 }, stat = {},
		lamps = {}, -- { light, part, on, off }: the main lamps, switched with the power
		units = B.units, count = count,
	}
	local n = ctx.n

	-- ── models ───────────────────────────────────────────────────────────────────────────────────────────
	local root = kit.model("Mall", map)
	ctx.m = {
		root = root,
		[0] = kit.model("L0", root), [1] = kit.model("L1", root), [2] = kit.model("L2", root),
		roof = kit.model("Roof", root), links = kit.model("Links", root), units = kit.model("Units", root),
	}

	-- ── primitives ───────────────────────────────────────────────────────────────────────────────────────
	-- the build hands the thread back now and then (a script that never yields can hit the engine's timeout on a slow server);
	-- called before a part is made, never between making it and setting it up. Outside the engine there is no `task`.
	local lastPace = os.clock()
	local function pace()
		if task and os.clock() - lastPace > 0.04 then
			task.wait()
			lastPace = os.clock()
		end
	end
	ctx.pace = pace
	-- a box from its centre and size (x, z in map-local studs, y world); nil when it would be paper thin
	local function mk(parent, cx, cy, cz, sx, sy, sz, color, mat)
		if sx < 0.02 or sy < 0.02 or sz < 0.02 then
			return nil
		end
		pace()
		local p = kit.part(parent, Vector3.new(sx, sy, sz), CFrame.new(O.X + cx, cy, O.Z + cz), color, mat)
		p.CanTouch = false
		n.parts += 1
		return p
	end
	-- a box from two corners
	local function ab(parent, x0, y0, z0, x1, y1, z1, color, mat)
		return mk(parent, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, color, mat)
	end
	-- a box with a world CFrame
	local function boxCF(parent, cf, sx, sy, sz, color, mat, class)
		if sx < 0.02 or sy < 0.02 or sz < 0.02 then
			return nil
		end
		pace()
		local p = kit.part(parent, Vector3.new(sx, sy, sz), cf, color, mat, class)
		p.CanTouch = false
		n.parts += 1
		return p
	end
	local GLASS = hex("9CC2CA")
	local function glassOf(p)
		if p then
			p.Material = M.Glass
			p.Color = GLASS
			p.Transparency = 0.6
			p.CastShadow = false
		end
		return p
	end
	-- a lamp fixture: `main` ones follow the power (dead until the lever is thrown), emergency ones stay lit
	local LAMP_ON, LAMP_OFF = hex("FFE2B0"), hex("6F6C64")
	local EM_ON = hex("FF6A55")
	local function lamp(parent, cx, cy, cz, sx, sy, sz, range, brightness, main)
		local p = mk(parent, cx, cy, cz, sx, sy, sz, main and LAMP_OFF or EM_ON, main and M.SmoothPlastic or M.Neon)
		if not p then
			return nil
		end
		p.CastShadow = false
		p.CanCollide = false
		p:SetAttribute("NoDetail", true)
		local l = kit.light(p, main and hex("FFD9A8") or hex("FF6A55"), range, brightness, false)
		n.lights += 1
		if main then
			l.Enabled = false
			ctx.lamps[#ctx.lamps + 1] = { light = l, part = p }
		end
		return p
	end
	ctx.mk, ctx.ab, ctx.boxCF, ctx.glassOf, ctx.lamp = mk, ab, boxCF, glassOf, lamp
	ctx.GLASS = GLASS
	B.powerHooks[#B.powerHooks + 1] = function(on)
		for _, q in ctx.lamps do
			q.light.Enabled = on and true or false
			q.part.Material = on and M.Neon or M.SmoothPlastic
			q.part.Color = on and LAMP_ON or LAMP_OFF
		end
	end

	-- ── steps ────────────────────────────────────────────────────────────────────────────────────────────
	local function step(name)
		local ok, err = pcall(function()
			require(script.Parent[name])(ctx)
		end)
		if not ok then
			warn("[ZR] Meridian mall: " .. name .. " failed: " .. tostring(err))
		end
		return ok
	end
	local t1 = os.clock()
	step("MallShell")
	local nShell = n.parts
	step("MallLinks")
	local nLinks = n.parts - nShell
	step("MallFit")
	local nFit = n.parts - nShell - nLinks

	-- every unit gets an entry even when a step failed halfway
	for _, u in plan.units do
		if not B.units[u.id] then
			B.units[u.id] = {
				id = u.id, name = u.name, kind = u.kind, level = u.level, rect = { x0 = u.x0, z0 = u.z0, x1 = u.x1, z1 = u.z1 },
			}
		end
	end

	count.mall = n.parts
	count.light = (count.light or 0) + n.lights
	count.door = (count.door or 0) + n.doors
	local nUnits = 0
	for _ in B.units do
		nUnits += 1
	end
	print(string.format(
		"[ZR] Meridian mall: %d parts (shell %d, links %d, fit %d), %d lights (%d shadowed), %d doors, %d units, plan %.2fs, build %.2fs",
		n.parts, nShell, nLinks, nFit, n.lights, n.shadows, n.doors, nUnits, tPlan, os.clock() - t1
	))
	local st = ctx.stat
	print(string.format(
		"[ZR] Meridian mall detail: floors %d, roof %d, walls %d, signs %d, treads %d, stock walls %d, anchors %d, zone marks %d, columns %d, rooms %d, lamps %d (%d main, %d emergency)",
		st.floors or 0, st.roof or 0, st.walls or 0, st.signs or 0, st.treads or 0, st.stock or 0, st.anchors or 0, st.zones or 0,
		st.columns or 0, st.rooms or 0, st.lamps or 0, st.lampMain or 0, st.lampEm or 0
	))
	if n.parts > 7000 then
		warn(string.format("[ZR] Meridian mall: %d parts is over the 7,000 budget of the shell", n.parts))
	end
	return root
end

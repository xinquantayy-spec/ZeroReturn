--!nonstrict
-- Smelter dressing (part 3 of 3): what stands on the floors and lights them. The reference's obstacles keep their
-- places and sizes (boilers, forklifts, tank skids, pallet rows, vehicles, machines, the locker rows upstairs); what
-- they look like is ours: the two boilers are our blast furnaces, the silos our crucibles (Shell), the rest Blender kit
-- props (KitMeta) or a few plain parts. Also the rail siding through the hall with two hopper wagons, the aid post's
-- canvas, the manager's desk, the slag heap in the east yard (the task places in Play) and the lamps (ours: a grid over
-- each floor, some dead). Kit props cast no sun shadow indoors.
return function(B)
	local kit, H, L, map, Kit = B.kit, B.H, B.L, B.map, B.Kit
	local C, M, hex = kit.C, kit.M, kit.hex
	local V = H.V
	local count = B.count
	local rng = Random.new(1316)

	local function try(name, f)
		local ok, err = pcall(f)
		if not ok then
			warn("[ZR] Smelter dress: " .. name .. " failed: " .. tostring(err))
		end
	end
	local function P(name, parent, cf, opts)
		opts = opts or {}
		if opts.shadows == nil then
			opts.shadows = false
		end
		if Kit.place(parent, name, cf, opts) then
			count.props = (count.props or 0) + 1
		end
	end
	-- the frame of a reference box: centre on its floor, local x along its long side (rot: degrees from +x toward +z)
	local function frame(cx, y, cz, rot)
		return CFrame.new(V(cx, y, cz)) * CFrame.Angles(0, -math.rad(rot), 0)
	end

	-- ── the reference's obstacles ────────────────────────────────────────────────────────────────────────
	try("machines", function()
		local mm = kit.model("Machines", map)
		local FURN, BRICK, IRON = hex("3B3F3C"), hex("6B4B3A"), hex("2F3230")
		for i, b in L.boxes do
			local cx, cz, w, d, rot, y0, h, kind = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8]
			local f = frame(cx, y0, cz, rot)
			if kind == "boiler" then
				-- our blast furnace on the boiler's footprint: a brick plinth, the iron stack, a hood, a flue to the roof,
				-- the tap glowing at the foot
				kit.boxCF(mm, w, 4.5, d, f * CFrame.new(0, 2.25, 0), BRICK, M.Brick)
				kit.boxCF(mm, w * 0.86, h - 4.5, d * 0.86, f * CFrame.new(0, 4.5 + (h - 4.5) / 2, 0), IRON, M.Metal)
				kit.boxCF(mm, w * 0.6, 2.4, d * 0.6, f * CFrame.new(0, h + 1.2, 0), hex("2C2A27"), M.Metal)
				-- (the flue stands at the boiler's north end, clear of the catwalk that crosses over its middle)
				kit.cyl(mm, L.LV.roof - h - 2.4, 2.4, f * CFrame.new(-w * 0.3, h + 2.4 + (L.LV.roof - h - 2.4) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), hex("4B3A30"), M.Metal)
				local tap = kit.boxCF(mm, 2.6, 1.6, 0.4, f * CFrame.new(0, 2.2, -d / 2 - 0.15), hex("FF7A2A"), M.Neon)
				tap.CastShadow = false
				tap.CanCollide = false
				kit.light(tap, hex("FF8A3A"), 26, 1.8, false)
			elseif kind == "forklift" then
				P("Forklift", mm, f * CFrame.Angles(0, math.rad(90), 0), { scale = 1.25, tint = (i % 3 == 0) and hex("C9B23A") or nil })
			elseif kind == "tank skid" then
				kit.boxCF(mm, w, 1.2, d, f * CFrame.new(0, 0.6, 0), hex("3E423F"), M.Metal)
				for _, sx in { -1, 1 } do
					kit.cyl(mm, h - 1.2, d * 0.86, f * CFrame.new(sx * w / 4, 1.2 + (h - 1.2) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), hex("6A7069"), M.Metal)
				end
			elseif kind == "pallet row" then
				P("PalletRack", mm, f, { scale = math.clamp(w / 16.3, 0.7, 1.2) })
			elseif kind == "vehicle" then
				P("Van", mm, f * CFrame.Angles(0, math.rad(90), 0), { scale = math.clamp(w / 20.6, 0.8, 1.2) })
			elseif kind == "container or machine" then
				P("HideoutGenerator", mm, f, { scale = math.clamp(w / 7.6, 0.8, 1.5) })
			elseif kind == "small machine" then
				P(i % 2 == 0 and "WaterTank" or "ToolChest", mm, f)
			elseif kind == "locker row" then
				local n = math.max(1, math.floor(w / 6))
				for k = 1, n do
					P("Lockers", mm, f * CFrame.new(-w / 2 + (k - 0.5) * (w / n), 0, 0) * CFrame.Angles(0, (i % 2 == 0) and 0 or math.rad(180), 0))
				end
			elseif kind == "bench row" then
				local n = math.max(1, math.floor(w / 6))
				for k = 1, n do
					P("Bench", mm, f * CFrame.new(-w / 2 + (k - 0.5) * (w / n), 0, 0))
				end
			elseif kind == "cabinet" then
				P("MirrorSink", mm, f)
			elseif kind == "machine house" then
				kit.boxCF(mm, w, h, d, f * CFrame.new(0, h / 2, 0), hex("5F5B4F"), M.Concrete)
				kit.boxCF(mm, w + 1, 0.8, d + 1, f * CFrame.new(0, h + 0.4, 0), hex("4A4943"), M.CorrodedMetal)
				P("HVAC", mm, f * CFrame.new(0, h + 0.8, 0), { shadows = true })
			end
		end
	end)

	-- ── the rail siding through the hall (re3mr: a track along x -25.5 m) and two hopper wagons ─────────────
	try("siding", function()
		local sm = kit.model("Siding", map)
		local x = -25.5 * 3.125
		for _, dx in { -2.3, 2.3 } do
			H.B(sm, 0.6, 0.45, 262, x + dx, 0.22, -56.25, hex("4A3F36"), M.Metal) -- z -60 to 24 m
		end
		local sp = B.points.SIDING
		local base = sp and (sp.Z - B.O.Z) or -62
		for k, wz in { base - 17, base + 17 } do
			H.B(sm, 9, 7.5, 30, x, 5.4, wz, k == 1 and hex("5E4236") or hex("4F3F35"), M.CorrodedMetal)
			H.B(sm, 9.6, 0.8, 31, x, 9.5, wz, hex("4A3A30"), M.Metal)
			H.B(sm, 6, 1.2, 28, x, 1.2, wz, hex("2F2D2A"), M.Metal)
			count.props = (count.props or 0) + 1
		end
	end)

	-- ── task furniture: the manager's desk, the aid post (canvas, table, cots), the slag heap ─────────────
	try("task furniture", function()
		local tm = kit.model("TaskFurniture", map)
		local md = B.points.MANAGER_DESK
		if md then
			local x, z = md.X - B.O.X, md.Z - B.O.Z
			H.desk(tm, x, md.Y, z, 6, 3)
			P("Chair", tm, CFrame.new(V(x, md.Y, z - 2.4)))
			P("Whiteboard", tm, CFrame.new(V(x + 4.5, md.Y + 3, (-27.9) * 3.125)) * CFrame.Angles(0, math.rad(180), 0))
		end
		local at = B.points.AID_TABLE
		if at then
			local x, z = at.X - B.O.X, at.Z - B.O.Z
			H.desk(tm, x, at.Y, z, 6, 3, hex("B9B7AE"))
			P("MedCot", tm, CFrame.new(V(x - 12, at.Y, z)) * CFrame.Angles(0, math.rad(90), 0))
			P("MedCot", tm, CFrame.new(V(x + 12, at.Y, z)) * CFrame.Angles(0, math.rad(-90), 0))
			-- the canvas over the tent's walls (the reference's tent lines: x 23.8..36.6, z 20.4..26.7 m)
			local tent = H.B(tm, 40.5, 0.3, 20.2, 30.2 * 3.125, 2.7 * 3.125 + 0.15, 23.55 * 3.125, hex("6E7258"), M.Fabric)
			tent.CastShadow = true
		end
		-- the slag heap in the east yard (task STACK): broken slag and a skip
		for k, h in { { 49, -24, 9, 3.2, 7, 15 }, { 52.5, -21, 6, 2.2, 5, -25 }, { 47.5, -20, 5, 1.6, 4, 40 } } do
			local p = H.B(tm, h[3], h[4], h[5], h[1] * 3.125, h[4] / 2, h[2] * 3.125, hex(k == 1 and "3A3631" or "45403A"), M.Basalt, h[6])
			p.Name = "Slag"
		end
	end)

	-- ── office furniture (upstairs rooms of the office block; the ground floor and the hall get workbenches) ─────
	try("furniture", function()
		local fm = kit.model("Furniture", map)
		local T3 = L.LV.third
		local function at(xm, zm, y, ry)
			return CFrame.new(V(xm * 3.125, y, zm * 3.125)) * CFrame.Angles(0, math.rad(ry or 0), 0)
		end
		P("OfficeDesk", fm, at(-37.6, -12.0, T3, 90))
		P("OfficeDesk", fm, at(-37.6, -7.4, T3, 90))
		P("Chair", fm, at(-38.8, -12.0, T3, 90))
		P("StorageShelf", fm, at(-37.5, -21.0, T3, 0))
		P("Pigeonholes", fm, at(-35.6, -10.5, T3, 90))
		P("Whiteboard", fm, at(-37.5, -16.3, T3 + 3, 0))
		-- the hall: workbenches and tool chests against the long dividing wall and in the north-west workshop
		P("CraftBench", fm, at(1.6, -4.0, 0, -90))
		P("ToolChest", fm, at(4.6, -14.0, 0, 90))
		P("CraftBench", fm, at(-30.0, -34.0, 0, 90))
		P("StorageRack", fm, at(-30.6, -52.0, 0, 90))
		P("Drum", fm, at(36.0, -50.0, 0))
		P("Drum", fm, at(36.4, -48.6, 0))
		P("TyreStack", fm, at(44.0, -57.0, 0))
		P("JerryCans", fm, at(-60.0, -54.5, 0))
		P("Trolley", fm, at(-36.0, 30.0, L.LV.west, 30))
		P("StorageRack", fm, at(-60.5, 10.0, L.LV.west, 90))
		P("StorageRack", fm, at(-60.5, 40.0, L.LV.west, 90))
		P("WorkLight", fm, at(20.0, 8.0, L.LV.sump, 0))
		P("Rubble", fm, at(24.0, 14.0, L.LV.sump, 0))
	end)

	-- ── lamps: hanging lamps in the halls, ceiling lamps in the low rooms, the offices and the tunnels; one in three
	-- only glows (no light), one in seven is dead ─────────────────────────────────────────────────────────────
	try("lamps", function()
		local lm = kit.model("Lamps", map)
		local nLit = 0
		for i, l in L.lamps do
			local x, y, z, kind = l[1], l[2], l[3], l[4]
			local dead = i % 7 == 0
			local size = kind == "hall" and Vector3.new(2.4, 0.5, 1.4) or Vector3.new(2, 0.3, 0.9)
			local head = H.B(lm, size.X, size.Y, size.Z, x, y, z, dead and hex("6F6C64") or hex("FFE2B0"), dead and M.SmoothPlastic or M.Neon)
			head.CastShadow = false
			head.CanCollide = false
			head:SetAttribute("NoDetail", true)
			if kind == "hall" then
				-- the cable up to the roof
				local top = L.LV.roof
				H.B(lm, 0.12, top - y, 0.12, x, (top + y) / 2, z, hex("2A2A28"), M.Metal).CanCollide = false
			end
			if not dead and i % 3 ~= 0 then
				local range = (kind == "hall" and 44) or (kind == "tunnel" and 26) or 22
				kit.light(head, (kind == "tunnel") and hex("FFD8A8") or hex("FFE6C4"), range, kind == "hall" and 1.2 or 0.9, false)
				nLit += 1
			end
		end
		count.lamps = nLit
		local _ = C
		local _ = rng
	end)
end

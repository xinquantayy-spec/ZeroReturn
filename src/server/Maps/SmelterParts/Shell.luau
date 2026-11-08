--!nonstrict
-- Smelter shell (part 1 of 3): builds what the generated layout (Layout.luau) lists, in map-local studs.
--   slabs     the hall floor (y 0), the raised west wing and office ground floor (game y 1.08), the loading dock and the
--             control gallery (2.73), the office second floor, the pump house and east block upper rooms (4.57), the
--             office third floor and the catwalks (8.23), the tunnels (-2.6) and the sump (-3.86), the roofs (ours)
--   walls     a 0.4 m band round every floor (the reference's outlines and room walls) and its small holes; the
--             office's upper rooms (re3mr plans); doors and windows already cut out (tools/factory_layout.py)
--   lines     the reference's wall lines (partitions, the glazed north gallery, the aid post's canvas)
--   flights   every stair of the reference (cellar stairs, the office stairwells, the catwalk towers), real-size steps
--   rails     deck edges: catwalks, the furnace deck, the dock, the control gallery, the crucible pit
--   cyls      the three crucibles in the pit and the three vessels beside it (ours: the reference's silos)
--   outside   the ground round the works, a few distant blocks (no collision) and the play boundary
-- Heights not in any source are ours (docs/maps/SMELTER_FACTORY_BUILD.md): roofs, wall tops, the crucibles.
return function(B)
	local kit, H, L, map = B.kit, B.H, B.L, B.map
	local C, M, hex = kit.C, kit.M, kit.hex
	local V = H.V
	local count = B.count
	local function bump(k, n)
		count[k] = (count[k] or 0) + (n or 1)
	end

	-- looks by kind: colour, material (concrete floors, sheet roofs, diamond-plate decks, plaster offices)
	local LOOK = {
		hall = { hex("57594F"), M.Concrete }, west = { hex("5E5D52"), M.Concrete }, dock = { hex("6A675B"), M.Concrete },
		tunnel = { hex("4E504B"), M.Concrete }, sump = { hex("3F4038"), M.Slate }, pitfloor = { hex("47463F"), M.Concrete },
		ground = { hex("4B4A3C"), M.Ground },
		floor2 = { hex("6F6B62"), M.Concrete }, floor3 = { hex("726D63"), M.Concrete }, bridge = { hex("5C615C"), M.DiamondPlate },
		deck = { hex("5A5F57"), M.DiamondPlate }, catwalk = { hex("5A5F57"), M.DiamondPlate }, roof = { hex("4A4943"), M.CorrodedMetal },
	}
	local WALL = {
		wall = { hex("6A6457"), M.Concrete }, tunnelwall = { hex("55574F"), M.Concrete }, wall2 = { hex("7A776C"), M.Plaster },
		wall3 = { hex("7D7A70"), M.Plaster }, beam = { hex("3A3D3B"), M.Metal }, glass = { hex("8FA3AA"), M.Glass },
		tent = { hex("6E7258"), M.Fabric }, full = { hex("6A6457"), M.Concrete }, part = { hex("6F6B5E"), M.Concrete },
		low = { hex("4E514C"), M.Metal }, storey = { hex("7A776C"), M.Plaster }, stall = { hex("8A8C86"), M.SmoothPlastic },
	}

	-- ── floors, decks, roofs ─────────────────────────────────────────────────────────────────────────────────
	local floors = kit.model("Floors", map)
	local roofs = kit.model("Roofs", map)
	for _, s in L.slabs do
		local x0, x1, z0, z1, top, th, kind = s[1], s[2], s[3], s[4], s[5], s[6], s[7]
		local look = LOOK[kind] or LOOK.hall
		local p = H.B(kind == "roof" and roofs or floors, x1 - x0, th, z1 - z0, (x0 + x1) / 2, top - th / 2, (z0 + z1) / 2, look[1], look[2])
		if kind == "roof" then
			p.Name = "Roof"
		elseif kind == "ground" then
			p.Name = "Ground"
			p:SetAttribute("NoDetail", true)
		elseif kind == "catwalk" or kind == "deck" or kind == "bridge" then
			p.Name = "Deck"
		end
		bump("slab")
	end

	-- ── walls (boxes) and wall lines ─────────────────────────────────────────────────────────────────────────
	local wm = kit.model("Walls", map)
	for _, w in L.walls do
		local x0, x1, z0, z1, y0, y1, kind = w[1], w[2], w[3], w[4], w[5], w[6], w[7]
		if y1 - y0 > 0.05 and x1 - x0 > 0.05 and z1 - z0 > 0.05 then
			local look = WALL[kind] or WALL.wall
			local p = H.B(wm, x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, look[1], look[2])
			if kind == "glass" then
				p.Transparency = 0.55
				p.CastShadow = false
				p:SetAttribute("NoDetail", true)
			end
			bump("wall")
		end
	end
	for _, ln in L.lines do
		local x0, z0, x1, z1, t, y0, y1, kind = ln[1], ln[2], ln[3], ln[4], ln[5], ln[6], ln[7], ln[8]
		local a, b = V(x0, (y0 + y1) / 2, z0), V(x1, (y0 + y1) / 2, z1)
		local len = (b - a).Magnitude
		if len > 0.1 then
			local look = WALL[kind] or WALL.wall
			local p = kit.boxCF(wm, t, y1 - y0, len + t, CFrame.lookAt((a + b) / 2, b), look[1], look[2])
			if kind == "glass" or kind == "tent" then
				p.Transparency = kind == "glass" and 0.55 or 0
				p.CastShadow = kind ~= "glass"
				p:SetAttribute("NoDetail", true)
			end
			bump("wall")
		end
	end

	-- ── stairs: real-size steps (two half-stud steps per stud of rise, owner 2026-11-01) ─────────────────────
	-- a flight climbs toward dir; a stacked one (the switchback towers) has thin steps so the flight under it keeps its
	-- head room, the others are solid down to their foot
	local sm = kit.model("Stairs", map)
	local STEP = hex("60625C")
	local function flight(x0, x1, z0, z1, yb, rise, dir, stacked, color, mat)
		local n = math.max(1, math.ceil(rise / 0.5 - 1e-6))
		local h = rise / n
		local alongX = dir == "+x" or dir == "-x"
		local len = alongX and (x1 - x0) or (z1 - z0)
		local tread = len / n
		-- art-5b: the Kit5 flight (one mesh and a ramp; the stacked steel ones keep the head room under them) when the
		-- batch is loaded, these steps otherwise
		local footX = (dir == "+x" and x0) or (dir == "-x" and x1) or (x0 + x1) / 2
		local footZ = (dir == "+z" and z0) or (dir == "-z" and z1) or (z0 + z1) / 2
		local look = (dir == "+x" and Vector3.xAxis) or (dir == "-x" and -Vector3.xAxis) or (dir == "+z" and Vector3.zAxis) or -Vector3.zAxis
		local foot = V(footX, yb, footZ)
		local wide = alongX and (z1 - z0) or (x1 - x0)
		if H.k5Flight(sm, CFrame.lookAt(foot, foot + look), n, h, tread, wide, stacked and "S" or "C", color or STEP, mat or M.Concrete, { base = 0.2 }) then
			bump("flight")
			return
		end
		for k = 1, n do
			local top = yb + k * h
			local bot = stacked and (top - h - 0.8) or (yb - 0.2)
			local a0
			if dir == "+x" then
				a0 = x0 + (k - 1) * tread
			elseif dir == "-x" then
				a0 = x1 - k * tread
			elseif dir == "+z" then
				a0 = z0 + (k - 1) * tread
			else
				a0 = z1 - k * tread
			end
			if alongX then
				H.B(sm, tread, top - bot, z1 - z0, a0 + tread / 2, (top + bot) / 2, (z0 + z1) / 2, color or STEP, mat or M.Concrete)
			else
				H.B(sm, x1 - x0, top - bot, tread, (x0 + x1) / 2, (top + bot) / 2, a0 + tread / 2, color or STEP, mat or M.Concrete)
			end
			bump("step")
		end
	end
	for _, f in L.flights do
		local metal = f[8] == true -- the switchback towers are steel stairs
		flight(f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], metal and hex("4E534F") or nil, metal and M.DiamondPlate or nil)
	end
	for _, l in L.landings do
		H.B(sm, l[2] - l[1], 0.6, l[4] - l[3], (l[1] + l[2]) / 2, l[5] - 0.3, (l[3] + l[4]) / 2, hex("4E534F"), M.DiamondPlate)
		bump("step")
	end
	for _, s in L.steps do
		flight(s[1], s[2], s[3], s[4], s[5], s[6], s[7], false, hex("5E5D52"), M.Concrete)
	end
	-- the inner wall of each switchback (between its two flights): the gap between the halves, floor to top
	local towers = {}
	for _, f in L.flights do
		if f[8] then
			local t = towers[f[9]]
			if not t then
				t = { x0 = math.huge, x1 = -math.huge, z0 = math.huge, z1 = -math.huge, y0 = math.huge, y1 = -math.huge, dir = f[7] }
				towers[f[9]] = t
			end
			t.x0, t.x1, t.z0, t.z1 = math.min(t.x0, f[1]), math.max(t.x1, f[2]), math.min(t.z0, f[3]), math.max(t.z1, f[4])
			t.y0, t.y1 = math.min(t.y0, f[5]), math.max(t.y1, f[5] + f[6])
		end
	end
	for _, t in towers do
		local cx, cz = (t.x0 + t.x1) / 2, (t.z0 + t.z1) / 2
		local h = t.y1 - t.y0 + 3.5
		if t.dir == "+x" or t.dir == "-x" then
			H.B(sm, t.x1 - t.x0, h, 0.35, cx, t.y0 + h / 2, cz, hex("3E423F"), M.Metal)
		else
			H.B(sm, 0.35, h, t.z1 - t.z0, cx, t.y0 + h / 2, cz, hex("3E423F"), M.Metal)
		end
		bump("step")
	end

	-- ── railings: a top and a mid rail on each deck edge, a post every 16 studs ────────────────────────────
	local rm = kit.model("Railings", map)
	local RAIL = hex("2E3230")
	for _, r in L.rails do
		local a, b = V(r[1], r[5], r[2]), V(r[3], r[5], r[4])
		local len = (b - a).Magnitude
		if len > 0.3 and H.k5Rail(rm, a, b, RAIL, M.Metal) then -- art-5b: the Kit5 railing when the batch is loaded
			bump("railKit")
		elseif len > 0.3 then
			local look = CFrame.lookAt((a + b) / 2, b)
			kit.boxCF(rm, 0.25, 0.25, len, look * CFrame.new(0, 3.3, 0), RAIL, M.Metal)
			kit.boxCF(rm, 0.18, 0.18, len, look * CFrame.new(0, 1.7, 0), RAIL, M.Metal)
			bump("rail", 2)
			local nPost = math.max(1, math.floor(len / 16))
			for k = 0, nPost - 1 do
				local p = a:Lerp(b, (k + 0.5) / nPost)
				kit.boxCF(rm, 0.3, 3.4, 0.3, CFrame.new(p + Vector3.new(0, 1.7, 0)), RAIL, M.Metal)
				bump("rail")
			end
		end
	end

	-- ── the crucibles over the pit and the vessels beside it (ours: the reference's six silos, with our heights). They
	-- stand on four legs: SPT has spawn and boss points under them (the pit floor, the hall floor), so a body fits below.
	local vm = kit.model("Crucibles", map)
	local LEGS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } -- a cross (tools/factory_layout.py keeps bodies off them)
	for i, c in L.cyls do
		local cx, cz, r, y0, h, kind = c[1], c[2], c[3], c[4], c[5], c[6]
		local pit = kind == "crucible"
		local lift = pit and (0.5 - y0) or 7.5 -- the crucibles hang at the hall floor's level over the pit
		local yb = y0 + lift
		local body = pit and hex("4A3B33") or hex("5B5F5A")
		local hb = h - lift
		H.VC(vm, hb, r * 2, cx, yb, cz, body, M.Metal).Name = pit and "Crucible" or "Vessel"
		H.VC(vm, 1.2, r * 2 + 1.2, cx, yb + hb * 0.62, cz, hex("3A3D3B"), M.Metal) -- a band
		H.VC(vm, 1.6, r * 1.3, cx, yb + hb, cz, hex("3E3A35"), M.Metal) -- the lid
		for _, q in LEGS do
			H.B(vm, 0.9, lift + 0.2, 0.9, cx + q[1] * r * 0.6, y0 + lift / 2, cz + q[2] * r * 0.6, hex("33383B"), M.Metal)
		end
		if pit then
			-- the pour spout facing the rail (west) and a glow in the tap of every other one
			H.B(vm, 3.2, 1.6, 2.4, cx - r - 1.2, yb + hb * 0.8, cz, hex("3A3631"), M.Metal)
			if i % 2 == 1 then
				local tap = H.B(vm, 0.5, 1.2, 1.8, cx - r - 0.05, yb + 1.6, cz, hex("FF7A2A"), M.Neon)
				tap.CastShadow = false
				tap.CanCollide = false
				kit.light(tap, hex("FF8A3A"), 22, 1.6, false)
			end
		end
		bump("slab", 7)
	end

	-- ── outside: open ground to the horizon beyond the layout's extent, distant blocks, the play boundary ─────
	local out = kit.model("Outside", map)
	local o = L.outer
	local gx0, gz0, gx1, gz1 = o[1], o[2], o[3], o[4]
	for _, g in { { gx0 - 400, gx1 + 400, gz0 - 400, gz0 }, { gx0 - 400, gx1 + 400, gz1, gz1 + 400 }, { gx0 - 400, gx0, gz0, gz1 }, { gx1, gx1 + 400, gz0, gz1 } } do
		local p = H.B(out, g[2] - g[1], 1, g[4] - g[3], (g[1] + g[2]) / 2, -0.5, (g[3] + g[4]) / 2, hex("4B4A3C"), M.Ground)
		p:SetAttribute("NoDetail", true)
	end
	local f = L.frame
	for _, b in { { 0, f[2] - 14, f[3] - f[1] + 60, 4 }, { 0, f[4] + 14, f[3] - f[1] + 60, 4 }, { f[1] - 14, 0, 4, f[4] - f[2] + 60 }, { f[3] + 14, 0, 4, f[4] - f[2] + 60 } } do
		local inv = H.B(out, b[3], 160, b[4], b[1], 60, b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.Name = "Boundary"
		inv:SetAttribute("NoDetail", true)
	end
	local rng = B.rng
	for k = 1, 10 do
		local sx, sz, h = rng:NextNumber(40, 110), rng:NextNumber(40, 110), rng:NextNumber(30, 90)
		local ang = (k / 10) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local rr = rng:NextNumber(420, 560)
		local s = H.B(out, sx, h, sz, math.cos(ang) * rr, h / 2 - 1, math.sin(ang) * rr, kit.jitter(C.concreteDark, 0.1), M.Concrete)
		s.CanCollide = false
		s.CastShadow = false
		s:SetAttribute("NoDetail", true)
	end
	for k = 1, 3 do
		local s = H.VC(out, rng:NextNumber(80, 120), 12, -360 + k * 180, -1, -520, hex("5A4A40"), M.Brick)
		s.CanCollide = false
		s:SetAttribute("NoDetail", true)
	end
end

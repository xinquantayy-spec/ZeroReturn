--!nonstrict
-- M13 map: SMELTER (factory-type). An original layout: a furnace hall with two blast furnaces, catwalks and a
-- crane; a casting shed; a two-storey office block; a pump house; a rail siding and a scrap yard; and service
-- tunnels under the yard joining the hall, the pump house, the offices and a scav-only slag tunnel.
-- Short raids (15 min), close fights. Built once at server start at its own origin (World.kit primitives).
-- Local coordinates: x east, z south, y up; the yard surface is y = 0, the tunnels' floor y = -9.
local O = Vector3.new(1600, 0, 0)

return function(kit, root)
	local W, C, M, hex = kit.World, kit.C, kit.M, kit.hex
	local Props = kit.Props
	local rng = Random.new(1313)
	local map = kit.model("Smelter", root)

	local function V(x, y, z)
		return Vector3.new(O.X + x, y, O.Z + z)
	end
	local function CF(x, y, z, ry)
		local c = CFrame.new(O.X + x, y, O.Z + z)
		if ry then
			c *= CFrame.Angles(0, math.rad(ry), 0)
		end
		return c
	end
	local function B(parent, sx, sy, sz, x, y, z, color, mat, ry)
		return kit.box(parent, sx, sy, sz, O.X + x, y, O.Z + z, color, mat, ry)
	end
	local function VC(parent, h, d, x, y, z, color, mat)
		return kit.vcyl(parent, h, d, O.X + x, y, O.Z + z, color, mat)
	end
	-- wall along x at z (holes { x, width, bottom, top } in map x)
	local function wallX(parent, x0, x1, z, y0, h, t, color, mat, holes)
		local cx = (x0 + x1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { o[1] - cx, o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(cx, y0, z), x1 - x0, h, t, color, mat, hs)
	end
	-- wall along z at x (holes { z, width, bottom, top } in map z)
	local function wallZ(parent, z0, z1, x, y0, h, t, color, mat, holes)
		local cz = (z0 + z1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { -(o[1] - cz), o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(x, y0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, h, t, color, mat, hs)
	end
	-- a slab (top at yTop) over x0..x1, z0..z1 with rectangular holes { x0, x1, z0, z1 }
	local function slab(parent, x0, x1, z0, z1, yTop, th, color, mat, holes)
		local xs, zs, hs = { x0, x1 }, { z0, z1 }, {}
		for _, h in holes or {} do
			if h[2] > x0 and h[1] < x1 and h[4] > z0 and h[3] < z1 then
				table.insert(hs, h)
				table.insert(xs, math.max(h[1], x0))
				table.insert(xs, math.min(h[2], x1))
				table.insert(zs, math.max(h[3], z0))
				table.insert(zs, math.min(h[4], z1))
			end
		end
		local function uniq(t)
			table.sort(t)
			local o = {}
			for _, v in t do
				if #o == 0 or math.abs(o[#o] - v) > 1e-6 then
					table.insert(o, v)
				end
			end
			return o
		end
		xs, zs = uniq(xs), uniq(zs)
		local function inHole(cx, cz)
			for _, h in hs do
				if cx > h[1] and cx < h[2] and cz > h[3] and cz < h[4] then
					return true
				end
			end
			return false
		end
		for i = 1, #xs - 1 do
			local a, b = xs[i], xs[i + 1]
			local run0 = nil
			for j = 1, #zs do
				local solid = j < #zs and not inHole((a + b) / 2, (zs[j] + zs[j + 1]) / 2)
				if solid and not run0 then
					run0 = zs[j]
				elseif not solid and run0 then
					B(parent, b - a, th, zs[j] - run0, (a + b) / 2, yTop - th / 2, (run0 + zs[j]) / 2, color, mat)
					run0 = nil
				end
			end
		end
	end
	-- a railing between two points at deck height y: top and mid rails plus end posts
	local RAIL = hex("2E3230")
	local function rail(parent, x0, z0, x1, z1, y)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		if len < 0.2 then
			return
		end
		local look = CFrame.lookAt(mid, b)
		kit.boxCF(parent, 0.25, 0.25, len, look * CFrame.new(0, 3.3, 0), RAIL, M.Metal)
		kit.boxCF(parent, 0.18, 0.18, len, look * CFrame.new(0, 1.7, 0), RAIL, M.Metal)
		for _, p in { a, b } do
			kit.boxCF(parent, 0.3, 3.4, 0.3, CFrame.new(p + Vector3.new(0, 1.7, 0)), RAIL, M.Metal)
		end
	end
	-- straight stairs: n steps of 1 stud, each `run` deep, from (x, y0, z) along dir ("+x", "-x", "+z", "-z"),
	-- `w` wide; solid blocks down to yBase so nothing can be walked under
	-- real-size steps: each stud of rise is two 0.5-stud steps over the same footprint (owner, 2026-11-01)
	local function stairs(parent, x, z, y0, n, run, w, dir, yBase, color)
		local r = run / 2
		for k = 1, n * 2 do
			local top = y0 + k * 0.5
			local h = top - yBase
			local off = (k - 0.5) * r
			if dir == "+x" then
				B(parent, r, h, w, x + off, yBase + h / 2, z, color, M.Concrete)
			elseif dir == "-x" then
				B(parent, r, h, w, x - off, yBase + h / 2, z, color, M.Concrete)
			elseif dir == "+z" then
				B(parent, w, h, r, x, yBase + h / 2, z + off, color, M.Concrete)
			else
				B(parent, w, h, r, x, yBase + h / 2, z - off, color, M.Concrete)
			end
		end
	end
	local function desk(parent, x, y0, z, w, d)
		B(parent, w, 0.3, d, x, y0 + 2.6, z, C.wood, M.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				B(parent, 0.22, 2.45, 0.22, x + sx * (w / 2 - 0.3), y0 + 1.22, z + sz * (d / 2 - 0.3), C.metalDark, M.Metal)
			end
		end
	end
	local function lampHang(parent, x, y, z, range, dead)
		local head = B(parent, 2, 0.4, 1.2, x, y, z, dead and hex("6F6C64") or hex("FFE2B0"), dead and M.SmoothPlastic or M.Neon)
		head.CastShadow = false
		if not dead then
			kit.light(head, hex("FFD3A0"), range or 30, 1.1, false)
		end
		return head
	end

	local CONC, CONC_D, IRON, RUST = hex("6E6F69"), hex("585A55"), hex("3A3D3B"), hex("6B4E3E")
	local HALL_W = hex("5F5B4F")

	-- ── ground: the yard and building floors (one slab layer, open over the tunnel stairs) ─────────────────
	local H1 = { 40, 46, -22, -8.5 } -- hall stairwell
	local H2 = { 78, 91.5, 46.5, 53.5 } -- pump house hatch
	local H3 = { -96, -89, -50, -38.3 } -- office basement stairs
	local ground = kit.model("Ground", map)
	local xe = { -130, -90, -50, -10, 30, 70, 110, 130 }
	local ze = { -100, -60, -20, 20, 60, 100 }
	for i = 1, #xe - 1 do
		for j = 1, #ze - 1 do
			slab(ground, xe[i], xe[i + 1], ze[j], ze[j + 1], 0, 1, kit.jitter(CONC, 0.05), M.Concrete, { H1, H2, H3 })
		end
	end
	-- outside the fence: rough ground to the horizon
	for _, g in { { -400, 400, -400, -101 }, { -400, 400, 101, 400 }, { -400, -131, -101, 101 }, { 131, 400, -101, 101 } } do
		local p = B(ground, g[2] - g[1], 1, g[4] - g[3], (g[1] + g[2]) / 2, -0.5, (g[3] + g[4]) / 2, hex("4B4A3C"), M.Ground)
		p:SetAttribute("NoDetail", true)
	end
	-- roads: the gate road (west) and the north yard road to the rail gate
	B(ground, 10, 0.12, 194, -67, 0.06, 2, C.asphalt, M.Asphalt)
	B(ground, 166, 0.12, 10, 21, 0.07, -85, C.asphalt, M.Asphalt)
	for z = -90, 90, 14 do
		B(ground, 0.5, 0.14, 6, -67, 0.08, z, C.line, M.SmoothPlastic)
	end

	-- ── perimeter wall (concrete panels, gates) and the play boundary ─────────────────────────────────────
	local per = kit.model("Perimeter", map)
	local PW = hex("595B55")
	wallX(per, -131, 131, 100, 0, 14, 2, PW, M.Concrete, { { -68, 16, 0, 12 } }) -- main gate
	wallX(per, -131, 131, -100, 0, 14, 2, PW, M.Concrete, { { 111, 12, 0, 12 }, { 40, 8, 0, 10 } }) -- rail gate, service gate
	wallZ(per, -99, 99, -130, 0, 14, 2, PW, M.Concrete, { { -80, 4, 0, 8 } }) -- watchman's door
	wallZ(per, -99, 99, 130, 0, 14, 2, PW, M.Concrete, {})
	for _, cap in { { 0, 100, 262, 2.6 }, { 0, -100, 262, 2.6 }, { -130, 0, 2.6, 198 }, { 130, 0, 2.6, 198 } } do
		B(per, cap[3], 0.8, cap[4], cap[1], 14.4, cap[2], C.concreteLight, M.Concrete)
	end
	for _, b in { { 0, -108, 300, 4 }, { 0, 108, 300, 4 }, { -138, 0, 4, 230 }, { 138, 0, 4, 230 } } do
		local inv = B(per, b[3], 120, b[4], b[1], 50, b[2], C.pale, M.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		inv.Name = "Boundary"
		inv:SetAttribute("NoDetail", true)
	end
	-- distant industrial skyline (no collision)
	for k = 1, 8 do
		local sx, sz, h = rng:NextNumber(30, 80), rng:NextNumber(30, 80), rng:NextNumber(25, 70)
		local ang = (k / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(260, 380)
		local s = B(per, sx, h, sz, math.cos(ang) * r, h / 2, math.sin(ang) * r, kit.jitter(C.concreteDark, 0.1), M.Concrete)
		s.CanCollide = false
		s.CastShadow = false
		s:SetAttribute("NoDetail", true)
	end
	for k = 1, 3 do
		local s = VC(per, rng:NextNumber(60, 90), 9, -300 + k * 150, 0, -330, hex("5A4A40"), M.Brick)
		s.CanCollide = false
		s:SetAttribute("NoDetail", true)
	end

	-- ── furnace hall ─────────────────────────────────────────────────────────────────────────────────────
	local fh = kit.model("FurnaceHall", map)
	local HH = 30
	local hallHoles = {
		S = { { -30, 14, 0, 14 }, { 35, 12, 0, 12 } },
		W = { { -20, 4, 0, 8 } },
		E = { { -45, 10, 0, 10 } },
		N = { { 10, 4, 0, 8 } },
	}
	wallX(fh, -60.5, 60.5, 0, 0, HH, 1, HALL_W, M.CorrodedMetal, hallHoles.S)
	wallX(fh, -60.5, 60.5, -60, 0, HH, 1, HALL_W, M.CorrodedMetal, hallHoles.N)
	wallZ(fh, -59.5, -0.5, -60, 0, HH, 1, HALL_W, M.CorrodedMetal, hallHoles.W)
	wallZ(fh, -59.5, -0.5, 60, 0, HH, 1, HALL_W, M.CorrodedMetal, hallHoles.E)
	-- concrete plinth outside the sheet metal
	local function plinthHoles(list)
		local out = {}
		for _, o in list do
			table.insert(out, { o[1], o[2], 0, 4.2 })
		end
		return out
	end
	wallX(fh, -61, 61, 0, 0, 4, 1.6, CONC_D, M.Concrete, plinthHoles(hallHoles.S))
	wallX(fh, -61, 61, -60, 0, 4, 1.6, CONC_D, M.Concrete, plinthHoles(hallHoles.N))
	wallZ(fh, -59.2, -0.8, -60, 0, 4, 1.6, CONC_D, M.Concrete, plinthHoles(hallHoles.W))
	wallZ(fh, -59.2, -0.8, 60, 0, 4, 1.6, CONC_D, M.Concrete, plinthHoles(hallHoles.E))
	-- roof in three strips; the gaps are skylights
	for _, r in { { -60, -43 }, { -39, -23 }, { -19, 0.5 } } do
		local rp = B(fh, 122, 1, r[2] - r[1], 0, HH + 0.5, (r[1] + r[2]) / 2, hex("4E4D45"), M.CorrodedMetal)
		rp.Name = "Roof"
	end
	-- overhead crane
	B(fh, 118, 2.5, 3, 0, 25.25, -30, C.yellow, M.Metal)
	B(fh, 6, 3, 5, 12, 22.5, -30, hex("A27F35"), M.Metal)
	kit.cyl(fh, 7, 0.25, CF(12, 17.5, -30) * CFrame.Angles(0, 0, math.rad(90)), C.metalDark, M.Metal)
	B(fh, 1.6, 1.2, 1.6, 12, 13.4, -30, C.metalDark, M.Metal)
	-- blast furnaces: brick base, iron shaft, collar, top, downcomers, a glowing tap hole and a runner
	for _, fx in { -25, 25 } do
		B(fh, 16, 6, 16, fx, 3, -36, hex("6B4B3A"), M.Brick)
		VC(fh, 22, 12, fx, 6, -36, IRON, M.Metal)
		VC(fh, 1.4, 14, fx, 9.6, -36, hex("4A4E4B"), M.Metal) -- bustle pipe collar under the platform
		VC(fh, 4, 8, fx, 28, -36, hex("2F3230"), M.Metal)
		VC(fh, 26, 2.2, fx - 5, 4, -44.5, RUST, M.Metal)
		VC(fh, 26, 2.2, fx + 5, 4, -44.5, RUST, M.Metal)
		local tap = B(fh, 3, 1.6, 0.4, fx, 2.2, -27.85, hex("FF7A2A"), M.Neon)
		tap.CastShadow = false
		kit.light(tap, hex("FF8A3A"), 30, 2.2, false)
		B(fh, 2.4, 0.6, 7, fx, 0.3, -24.5, hex("2C2A27"), M.Metal)
		local melt = B(fh, 1, 0.12, 6.6, fx, 0.62, -24.5, hex("FF6A20"), M.Neon)
		melt.CastShadow = false
		melt.CanCollide = false
	end
	-- platforms round the furnaces at y 12, the north catwalk, side catwalks, landings and bridges
	local DECK, DY = hex("5A5F57"), 12
	for _, fx in { -25, 25 } do
		slab(fh, fx - 10, fx + 10, -46, -26, DY, 0.6, DECK, M.DiamondPlate, { { fx - 6.6, fx + 6.6, -42.6, -29.4 } })
	end
	B(fh, 119, 0.6, 8, 0, DY - 0.3, -55.5, DECK, M.DiamondPlate) -- north catwalk z -59.5..-51.5
	B(fh, 6, 0.6, 23.5, -56.5, DY - 0.3, -39.75, DECK, M.DiamondPlate) -- west catwalk to z -28
	B(fh, 6, 0.6, 23.5, 56.5, DY - 0.3, -39.75, DECK, M.DiamondPlate) -- east catwalk
	B(fh, 4.5, 0.6, 4, -51.25, DY - 0.3, -26, DECK, M.DiamondPlate) -- west landing x -53.5..-49
	B(fh, 4.5, 0.6, 4, 51.25, DY - 0.3, -26, DECK, M.DiamondPlate) -- east landing
	B(fh, 4, 0.6, 5.5, -25, DY - 0.3, -48.75, DECK, M.DiamondPlate) -- bridge to furnace 1
	B(fh, 4, 0.6, 5.5, 25, DY - 0.3, -48.75, DECK, M.DiamondPlate) -- bridge to furnace 2
	B(fh, 30, 0.6, 4, 0, DY - 0.3, -36, DECK, M.DiamondPlate) -- bridge between the furnace platforms
	-- stairs up to the side catwalks (12 steps, rising north)
	stairs(fh, -51, -6, 0, 12, 1.5, 4, "-z", 0, CONC_D)
	stairs(fh, 51, -6, 0, 12, 1.5, 4, "-z", 0, CONC_D)
	-- railings
	rail(fh, -59.5, -51.5, -27, -51.5, DY)
	rail(fh, -23, -51.5, 23, -51.5, DY)
	rail(fh, 27, -51.5, 59.5, -51.5, DY)
	rail(fh, -53.5, -51.5, -53.5, -28, DY)
	rail(fh, 53.5, -51.5, 53.5, -28, DY)
	rail(fh, -53.5, -28, -49, -28, DY)
	rail(fh, 53.5, -28, 49, -28, DY)
	rail(fh, -49, -28, -49, -24, DY)
	rail(fh, 49, -28, 49, -24, DY)
	for _, fx in { -25, 25 } do
		rail(fh, fx - 2, -51.5, fx - 2, -46, DY)
		rail(fh, fx + 2, -51.5, fx + 2, -46, DY)
		rail(fh, fx - 10, -26, fx + 10, -26, DY)
		rail(fh, fx - 10, -46, fx - 2, -46, DY)
		rail(fh, fx + 2, -46, fx + 10, -46, DY)
		local outer, inner = fx < 0 and fx - 10 or fx + 10, fx < 0 and fx + 10 or fx - 10
		rail(fh, outer, -46, outer, -26, DY)
		rail(fh, inner, -46, inner, -38, DY)
		rail(fh, inner, -34, inner, -26, DY)
	end
	rail(fh, -15, -38, 15, -38, DY)
	rail(fh, -15, -34, 15, -34, DY)
	-- ladle track and two ladle cars (low cover), slag heap, a workbench
	for _, rz in { -16, -12 } do
		B(fh, 94, 0.3, 0.4, -11, 0.15, rz, hex("4A3F36"), M.Metal)
	end
	B(fh, 1.2, 1.4, 6, 36.6, 0.7, -14, C.yellow, M.Metal) -- buffer stop
	for _, lx in { -40, 10 } do
		B(fh, 8, 1.6, 6, lx, 1.1, -14, hex("3E3C38"), M.Metal)
		VC(fh, 4.6, 5.6, lx, 1.9, -14, hex("4B3A30"), M.Metal)
	end
	for i, h in { { 49, -31, 6, 2.2, 5, 15 }, { 53, -27, 5, 1.8, 4, -20 }, { 47, -26, 4, 1.4, 4, 40 } } do
		local p = B(fh, h[3], h[4], h[5], h[1], h[4] / 2, h[2], hex(i == 1 and "3A3631" or "45403A"), M.Basalt, h[6])
		p.Name = "Slag"
	end
	desk(fh, -50, 0, -48, 6, 2.4)
	-- stairwell down to the tunnels: rails round the opening
	rail(fh, 40, -22, 40, -8.5, 0)
	rail(fh, 46, -22, 46, -8.5, 0)
	rail(fh, 40, -8.5, 46, -8.5, 0)
	-- lights: hanging lamps and the furnace glow
	for _, l in { { -40, -18 }, { 0, -20 }, { 30, -8 }, { -40, -46 }, { 40, -50, true }, { 0, -45 } } do
		lampHang(fh, l[1], 23, l[2], 34, l[3])
	end
	-- pipes along the north wall
	kit.cyl(fh, 116, 1.6, CF(0, 20, -58.6), RUST, M.Metal)
	kit.cyl(fh, 116, 1.0, CF(0, 18.4, -58.6), C.metalDark, M.Metal)

	-- ── casting shed ─────────────────────────────────────────────────────────────────────────────────────
	local cs = kit.model("CastingShed", map)
	local CSW = hex("6A6458")
	wallZ(cs, 0.5, 40.5, -60, 0, 16, 1, CSW, M.CorrodedMetal, { { 20, 10, 0, 10 } })
	wallX(cs, -60.5, 0.5, 40, 0, 16, 1, CSW, M.CorrodedMetal, { { -15, 3.9, 0, 7.5 } })
	wallZ(cs, 0.5, 40.5, 0, 0, 16, 1, CSW, M.CorrodedMetal, { { 12, 6, 6, 10 }, { 28, 6, 6, 10 } })
	B(cs, 61, 1, 40, -30, 16.5, 20.5, hex("4E4D45"), M.CorrodedMetal).Name = "Roof"
	for _, bz in { 12, 28 } do
		B(cs, 34, 1.6, 5, -35, 0.8, bz, hex("3B3A36"), M.Metal)
		for k = 0, 5 do
			B(cs, 3, 0.25, 3.4, -49 + k * 5.6, 1.72, bz, hex("2A2826"), M.Metal)
		end
	end
	Props.cover(cs, "PalletStack", CF(-8, 0, 20, 90))
	Props.cover(cs, "PalletStack", CF(-50, 0, 33, 10))
	Props.cover(cs, "DrumDented", CF(-8, 0, 7), C.rust)
	for _, l in { { -45, 20 }, { -25, 20 }, { -8, 30, true } } do
		lampHang(cs, l[1], 14, l[2], 28, l[3])
	end
	W.doors.SM_SHED = { id = "SM_SHED", cf = CF(-15, 3.75, 40), size = Vector3.new(3.9, 7.4, 0.35), label = "Shed door", parent = cs, openChance = 0.5 }

	-- ── office block (two storeys) ───────────────────────────────────────────────────────────────────────
	local ob = kit.model("OfficeBlock", map)
	local OBW, PL = hex("6F6A60"), C.interior
	local X0, X1, Z0, Z1, FH1 = -112, -76, -54, -20, 9
	for floor = 0, 1 do
		local y0 = floor * FH1
		local win = { 3.2, 6.4 }
		local east = { { -46, 3, win[1], win[2] }, { -26, 3, win[1], win[2] } }
		if floor == 0 then
			table.insert(east, { -36, 3.9, 0, 7.5 })
		end
		wallZ(ob, Z0, Z1, X1, y0, FH1, 1, OBW, M.Concrete, east)
		wallZ(ob, Z0, Z1, X0, y0, FH1, 1, OBW, M.Concrete, { { -44, 3, win[1], win[2] }, { -28, 3, win[1], win[2] } })
		wallX(ob, X0 - 0.5, X1 + 0.5, Z0, y0, FH1, 1, OBW, M.Concrete, { { -104, 3, win[1], win[2] }, { -82, 3, win[1], win[2] } })
		wallX(ob, X0 - 0.5, X1 + 0.5, Z1, y0, FH1, 1, OBW, M.Concrete, { { -104, 3, win[1], win[2] }, { -86, 3, win[1], win[2] } })
	end
	-- first floor slab (hole over the stairs), roof and parapet
	slab(ob, X0 + 0.5, X1 - 0.5, Z0 + 0.5, Z1 - 0.5, FH1 + 0.3, 0.6, C.concreteLight, M.Concrete, { { -82, -78, -35.5, -22 } })
	B(ob, X1 - X0 + 1, 0.6, Z1 - Z0 + 1, (X0 + X1) / 2, 2 * FH1 + 0.3, (Z0 + Z1) / 2, CONC_D, M.Concrete)
	wallX(ob, X0 - 0.5, X1 + 0.5, Z0, 2 * FH1 + 0.6, 1, 0.4, CONC_D, M.Concrete, {})
	wallX(ob, X0 - 0.5, X1 + 0.5, Z1, 2 * FH1 + 0.6, 1, 0.4, CONC_D, M.Concrete, {})
	-- ground floor: corridor z -38..-34; north: locker / boiler room (basement stairs) and records; south: break
	-- room and the stair hall
	wallX(ob, X0 + 0.5, X1 - 0.5, -38, 0, FH1, 0.4, PL, M.Plaster, { { -104, 3.6, 0, 7.5 }, { -82, 3.6, 0, 7.5 } })
	wallZ(ob, Z0 + 0.5, -38, -88, 0, FH1, 0.4, PL, M.Plaster, {})
	wallX(ob, X0 + 0.5, X1 - 0.5, -34, 0, FH1, 0.4, PL, M.Plaster, { { -104, 3.6, 0, 7.5 }, { -80, 5, 0, FH1 } })
	wallZ(ob, -34, Z1 - 0.5, -92, 0, FH1, 0.4, PL, M.Plaster, { { -27, 3.6, 0, 7.5 } })
	stairs(ob, -80, -22, 0, 9, 1.5, 4, "-z", 0, C.concreteLight)
	rail(ob, -96, -50, -96, -38.3, 0)
	rail(ob, -89, -50, -89, -38.3, 0)
	rail(ob, -96, -38.3, -89, -38.3, 0)
	-- first floor: manager's office (locked) and office 2 to the north, archive to the south
	wallX(ob, X0 + 0.5, X1 - 0.5, -38, FH1, FH1, 0.4, PL, M.Plaster, { { -100, 3.7, 0, 7.4 }, { -85, 3.6, 0, 7.4 } })
	wallZ(ob, Z0 + 0.5, -38, -94, FH1, FH1, 0.4, PL, M.Plaster, {})
	wallX(ob, X0 + 0.5, X1 - 0.5, -34, FH1, FH1, 0.4, PL, M.Plaster, { { -104, 3.6, 0, 7.4 }, { -80, 5, 0, FH1 } })
	rail(ob, -82, -34, -82, -22, FH1 + 0.3)
	rail(ob, -78, -34, -78, -22, FH1 + 0.3)
	rail(ob, -82, -22, -78, -22, FH1 + 0.3)
	W.doors.SM_OFFICE = { id = "SM_OFFICE", cf = CF(X1, 3.75, -36, 90), size = Vector3.new(3.9, 7.4, 0.35), label = "Office block", parent = ob, openChance = 0.4, color = hex("6E5E4A") }
	W.doors.SM_MGR = { id = "SM_MGR", cf = CF(-100, FH1 + 0.3 + 3.55, -38), size = Vector3.new(3.7, 7.1, 0.3), key = "KEY_SMELT_OFFICE", label = "Manager's office", parent = ob, color = hex("5E4C3A") }
	-- furniture with loot surfaces
	desk(ob, -104, 0, -27, 5, 2.6) -- break room table
	desk(ob, -80, 0, -48, 5, 2.4) -- records desk
	desk(ob, -104, FH1 + 0.3, -48, 5, 2.4) -- manager's desk
	desk(ob, -85, FH1 + 0.3, -46, 5, 2.4) -- office 2
	B(ob, 1.6, 0.2, 8, -110.6, FH1 + 0.3 + 2.4, -26, C.metalDark, M.Metal) -- archive shelf
	for _, l in { { -100, -45 }, { -82, -45, true }, { -100, -27 }, { -84, -36 } } do
		lampHang(ob, l[1], FH1 - 0.4, l[2], 16, l[3])
	end
	for _, l in { { -103, -46 }, { -85, -46 }, { -100, -27, true } } do
		lampHang(ob, l[1], 2 * FH1 - 0.4, l[2], 16, l[3])
	end

	-- ── pump house (the hatch down to the tunnels) ───────────────────────────────────────────────────────
	local ph = kit.model("PumpHouse", map)
	wallZ(ph, 38, 62, 72, 0, 10, 1, CONC, M.Concrete, { { 50, 3.9, 0, 7.5 } })
	wallZ(ph, 38, 62, 100, 0, 10, 1, CONC, M.Concrete, { { 44, 3, 4, 7 } })
	wallX(ph, 71.5, 100.5, 38, 0, 10, 1, CONC, M.Concrete, { { 86, 3, 4, 7 } })
	wallX(ph, 71.5, 100.5, 62, 0, 10, 1, CONC, M.Concrete, {})
	B(ph, 30, 0.6, 25, 86, 10.3, 50, CONC_D, M.Concrete)
	rail(ph, 78, 46.5, 91.5, 46.5, 0)
	rail(ph, 78, 53.5, 91.5, 53.5, 0)
	rail(ph, 78, 46.5, 78, 53.5, 0)
	for _, pz in { 42, 58 } do
		kit.cyl(ph, 6, 3, CF(77, 1.5, pz), hex("4F6272"), M.Metal)
		VC(ph, 8, 0.8, 80.5, 1.5, pz, C.metalDark, M.Metal)
	end
	B(ph, 1.6, 0.2, 6, 98.8, 3.2, 41, C.metalDark, M.Metal) -- shelf
	lampHang(ph, 86, 9.4, 50, 22)
	W.doors.SM_PUMP = { id = "SM_PUMP", cf = CF(72, 3.75, 50, 90), size = Vector3.new(3.9, 7.4, 0.35), label = "Pump house", parent = ph, openChance = 0.3 }

	-- ── service tunnels (floor top -9, ceiling = underside of the yard slab at -1) ──────────────────────
	local tun = kit.model("Tunnels", map)
	local TF, TCE = -9, -1
	local TW, TFL = hex("5A5C57"), hex("4A4C48")
	local WH = TCE - (TF - 1) -- 9: from the floor slab's bottom to the ceiling
	local function tfloor(x0, x1, z0, z1)
		B(tun, x1 - x0, 1, z1 - z0, (x0 + x1) / 2, TF - 0.5, (z0 + z1) / 2, TFL, M.Concrete)
	end
	local function twX(x0, x1, z, holes)
		wallX(tun, x0, x1, z, TF - 1, WH, 1, TW, M.Concrete, holes)
	end
	local function twZ(z0, z1, x, holes)
		wallZ(tun, z0, z1, x, TF - 1, WH, 1, TW, M.Concrete, holes)
	end
	-- junction under the hall stairwell
	for k = 1, 9 do
		local top = -k
		B(tun, 6, top + 10, 1.5, 43, (top - 10) / 2, -22 + (k - 0.5) * 1.5, CONC_D, M.Concrete)
	end
	twZ(-22, -8.5, 39.5, {})
	twZ(-22, -8.5, 46.5, {})
	tfloor(36, 50, -8.5, 3.5)
	twX(35.5, 50.5, -9, { { 43, 6, 0, WH } })
	twZ(-9, 4, 50.5, {})
	twZ(-9, 4, 35.5, { { -3, 7, 0, WH } })
	twX(35.5, 50.5, 4, { { 43, 7, 0, WH } })
	-- south to the pump house
	tfloor(39.5, 46.5, 3.5, 53.5)
	twZ(4.5, 54, 39, {})
	twZ(4.5, 54, 47, { { 50, 7, 0, WH } })
	twX(38.5, 47.5, 54, {})
	tfloor(46.5, 78, 46.5, 53.5)
	twX(47.5, 92, 46, {})
	twX(47.5, 92, 54, {})
	stairs(tun, 78, 50, TF, 9, 1.5, 7, "+x", -10, CONC_D)
	-- west under the hall to the office block
	tfloor(-96, 36, -6.5, 0.5)
	twX(-88.5, 35.5, -7, {})
	twX(-96.5, 35.5, 1, { { 0, 7, 0, WH } })
	tfloor(-96, -89, -38.3, -6.5)
	twZ(-50, 1, -96.5, {})
	twZ(-50, -7, -88.5, {})
	for k = 1, 9 do
		local top = TF + k
		B(tun, 7, top + 10, 1.3, -92.5, (top - 10) / 2, -38.3 - (k - 0.5) * 1.3, CONC_D, M.Concrete)
	end
	-- the slag tunnel (scav exfil at its far end)
	tfloor(-3.5, 3.5, 1, 70)
	twZ(1.5, 70.5, -4, {})
	twZ(1.5, 70.5, 4, {})
	twX(-4.5, 4.5, 70.5, {})
	for k = 0, 4 do
		B(tun, 0.25, 0.25, 0.25, -1, -8.6 + k * 1.6, 69.8, C.metalDark, M.Metal)
		B(tun, 0.25, 0.25, 0.25, 1, -8.6 + k * 1.6, 69.8, C.metalDark, M.Metal)
		B(tun, 2.2, 0.15, 0.15, 0, -8.6 + k * 1.6, 69.8, C.metalDark, M.Metal)
	end
	B(tun, 4, 0.12, 4, 0, -1.06, 67.5, hex("2B2C2A"), M.DiamondPlate).CanCollide = false
	-- pipes along the long tunnel and dim lamps (some dead)
	kit.cyl(tun, 124, 1.2, CF(-26, -2.6, -5.8), RUST, M.Metal)
	kit.cyl(tun, 49, 0.9, CF(40.2, -2.4, 29) * CFrame.Angles(0, math.rad(90), 0), C.metalDark, M.Metal)
	for _, l in { { 43, -2 }, { 43, 20 }, { 43, 40 }, { 62, 50 }, { 20, -3 }, { 0, -3 }, { -25, -3 }, { -50, -3, true }, { -75, -3 },
		{ -92.5, -22 }, { 0, 20 }, { 0, 40, true }, { 0, 58 } } do
		lampHang(tun, l[1], -1.35, l[2], 18, l[3])
	end

	-- ── yard: guard booth, rail siding, coal bunker, weighbridge, stack, scrap ──────────────────────────
	local yard = kit.model("Yard", map)
	-- guard booth by the main gate (door on the road side)
	local GB = hex("6B6E66")
	wallX(yard, -88.2, -77.8, 82, 0, 5, 0.4, GB, M.Concrete, { { -83, 3, 2.2, 4.2 } })
	wallX(yard, -88.2, -77.8, 90, 0, 5, 0.4, GB, M.Concrete, { { -83, 3, 2.2, 4.2 } })
	wallZ(yard, 82, 90, -88, 0, 5, 0.4, GB, M.Concrete, {})
	wallZ(yard, 82, 90, -78, 0, 5, 0.4, GB, M.Concrete, { { 86, 2.6, 0, 4.4 } })
	B(yard, 11, 0.4, 9, -83, 5.2, 86, CONC_D, M.Concrete)
	desk(yard, -84, 0, 83.4, 4, 1.4)
	local arm = B(yard, 12, 0.3, 0.3, -67, 3, 94.5, hex("C9B23A"), M.SmoothPlastic)
	arm.CanCollide = false
	VC(yard, 3, 0.6, -73.5, 0, 94.5, C.metalDark, M.Metal)
	Props.cover(yard, "Sandbags", CF(-74, 0, 78, 90))
	-- rail siding with two hopper wagons
	for _, rx in { 108, 114 } do
		B(yard, 0.6, 0.5, 196, rx, 0.25, -2, hex("4A3F36"), M.Metal)
	end
	for z = -94, 94, 8 do
		B(yard, 9, 0.3, 1.2, 111, 0.15, z, C.wood, M.Wood)
	end
	for _, wz in { -40, 20 } do
		B(yard, 8.5, 6, 20, 111, 4.5, wz, hex("5E4236"), M.CorrodedMetal)
		B(yard, 9, 0.6, 21, 111, 7.8, wz, hex("4A3A30"), M.Metal)
		for _, sx in { -1, 1 } do
			for _, sz in { -7, 7 } do
				kit.cyl(yard, 0.6, 2.2, CF(111 + sx * 3.4, 1.1, wz + sz), C.metalDark, M.Metal)
			end
		end
	end
	-- coal bunker (low walls round a coal heap)
	wallX(yard, -41, -23, 60, 0, 3, 1, CONC_D, M.Concrete, {})
	wallZ(yard, 60, 72, -41, 0, 3, 1, CONC_D, M.Concrete, {})
	wallZ(yard, 60, 72, -23, 0, 3, 1, CONC_D, M.Concrete, {})
	for i, c in { { -32, 66, 10, 2.4, 8, 10 }, { -28, 69, 6, 1.6, 5, -25 } } do
		local p = B(yard, c[3], c[4], c[5], c[1], c[4] / 2, c[2], hex(i == 1 and "242322" or "2E2C2A"), M.Basalt, c[6])
		p.Name = "Coal"
	end
	-- weighbridge with its hut
	B(yard, 22, 0.25, 8, 30, 0.125, 76, hex("4D514E"), M.DiamondPlate)
	wallX(yard, 41.8, 46.2, 80, 0, 4.4, 0.3, hex("6E7369"), M.Metal, { { 44, 2, 2, 3.6 } })
	wallX(yard, 41.8, 46.2, 84, 0, 4.4, 0.3, hex("6E7369"), M.Metal, {})
	wallZ(yard, 80, 84, 42, 0, 4.4, 0.3, hex("6E7369"), M.Metal, { { 82, 2.4, 0, 3.8 } })
	wallZ(yard, 80, 84, 46, 0, 4.4, 0.3, hex("6E7369"), M.Metal, {})
	B(yard, 5, 0.3, 5, 44, 4.55, 82, C.metalDark, M.Metal)
	desk(yard, 44.5, 0, 82.8, 2.4, 1.2)
	-- the stack (landmark, north yard)
	for k = 0, 8 do
		VC(yard, 6, 7 - k * 0.15, -30, k * 6, -72, (k % 3 == 2) and hex("8A3C2E") or hex("6E5143"), M.Brick)
	end
	-- scrap yard: heaps of twisted metal
	for i = 1, 7 do
		local w, h, d = rng:NextNumber(4, 8), rng:NextNumber(1.4, 3.2), rng:NextNumber(3, 6)
		local p = B(yard, w, h, d, rng:NextNumber(72, 98), h / 2 - 0.3, rng:NextNumber(-76, -54), hex(i % 2 == 0 and "5B4A3E" or "4C4842"), M.CorrodedMetal, rng:NextNumber(0, 180))
		p.Name = "Scrap"
	end
	-- two shipping containers in the yard
	Props.container(yard, CF(60, 0, 86, 90), C.teal)
	Props.container(yard, CF(0, 0, -70), C.rust)
	-- street lamps (one flickers, one is dead)
	for _, lp in { { -61, -70 }, { -61, 0, "flicker" }, { -61, 70 }, { 20, -79 }, { 80, -79, "dead" }, { 102, 10 }, { 20, 60 } } do
		Props.lamp(yard, CF(lp[1], 0, lp[2]), lp[3])
	end
	-- cover in the open (wear-kit props)
	for _, c in {
		{ "CarWreck", -20, 50, 75 }, { "CarWreck", 90, -40, 10 }, { "CarWreck", 82, 74, 95 }, { "Dumpster", -48, 46, 0, hex("3D5468") },
		{ "Dumpster", 64, 10, 90, hex("3E5A45") }, { "TyreStack", 94, -62, 0 }, { "TyreStack", 0, 82, 20 }, { "CinderStack", 30, 30, 15, C.concreteLight },
		{ "CinderStack", -100, 30, 0, C.concreteLight }, { "DrumDented", 66, -20, 0, C.red }, { "DrumDented", 69, -18, 0, C.blue },
		{ "CableReel", 75, -40, 90 }, { "BarrierBroken", -55, -88, 0, C.concreteLight }, { "Sandbags", 40, -88, 0, hex("A39A80") },
		{ "PalletStack", 100, 70, 30 }, { "PalletStack", -110, 75, 0 }, { "Sandbags", 105, -90, 90, hex("A39A80") },
	} do
		Props.cover(yard, c[1], CF(c[2], 0, c[3], c[4]), c[5])
	end

	-- ── furnishing and damage pass (Blender kit props; Tarkov's Factory is dense: machines, racks, lockers, desks,
	-- pipes and valves, debris; 2026-11-01) ───────────────────────────────────────────────────────────────
	local Kit = require(script.Parent.Kit)
	local nProps = 0
	local function P(parent, name, x, y, z, ry, opts)
		opts = opts or {}
		if opts.shadows == nil then
			opts.shadows = false
		end
		if Kit.place(parent, name, CF(x, y, z, ry), opts) then
			nProps += 1
		end
	end
	local F1 = FH1 + 0.3
	-- office block, ground floor: locker room (lockers, bench), records, corridor, break room, stair hall
	P(ob, "Lockers", -104, 0, -51.9, 180)
	P(ob, "LockerOpen", -99, 0, -51.7, 180)
	P(ob, "Bench", -107, 0, -43.5, 90)
	P(ob, "JunctionBox", -111.2, 2.5, -49, -90)
	P(ob, "StorageShelf", -86.8, 0, -46, -90)
	P(ob, "Chair", -80, 0, -45.4, 0)
	P(ob, "Extinguisher", -90, 0, -37.4, 180)
	P(ob, "WallPhone", -95, 3.2, -34.5, 0)
	P(ob, "Vending", -96.5, 0, -22.1, 0)
	for _, c in { { -106, -24.9, 0 }, { -102, -24.9, 0 }, { -106, -29.1, 180 }, { -102, -29.1, 180 } } do
		P(ob, "Chair", c[1], 0, c[2], c[3])
	end
	P(ob, "Sofa", -110, 0, -30, -90)
	P(ob, "WallClock", -108.5, 6, -33.7, 180)
	P(ob, "CorkBoard", -97, 3.5, -33.75, 180)
	P(ob, "Bin", -93.4, 0, -32.4)
	P(ob, "FirstAid", -91.6, 3.4, -24, -90)
	-- first floor: manager's office, office 2, the archive's shelf rows
	P(ob, "Chair", -104, F1, -50.4, 180)
	P(ob, "Sofa", -95.7, F1, -46, 90)
	P(ob, "WallShelfBooks", -98.3, F1, -52.45, 180)
	P(ob, "Whiteboard", -107, F1 + 3, -38.5, 0)
	P(ob, "OfficeDesk", -89.5, F1, -50.6, 180)
	P(ob, "Chair", -85, F1, -43.8, 0)
	P(ob, "Pigeonholes", -77.1, F1, -41.4, 90)
	for _, sx in { -96, -88 } do
		P(ob, "StorageShelf", sx, F1, -29.5, 0)
		P(ob, "StorageShelfEmpty", sx, F1, -24.4, 180)
	end
	P(ob, "CardboardPile", -108, F1, -31)
	P(ob, "FluoroDead", -88, F1 + 8.2, -27, 0)
	-- furnace hall: the blower set between the furnaces, racks and pallets under the catwalks, the forklift
	-- bay by the south doors, cabinets and valves on the walls, pipe runs, debris and oil
	P(fh, "Generator", 0, 0, -48, 180)
	P(fh, "StorageRack", -57.9, 0, -40, -90)
	P(fh, "PalletBoxes", -56.5, 0, -31.5)
	P(fh, "PalletBoxes", 56.5, 0, -33, 0, { tint = hex("C9C2B0") })
	P(fh, "Drum", 57.6, 0, -29.6)
	for _, pb in { { -40, -56.5, 0 }, { -35.4, -56.8, 20 }, { 30, -56.3, 0 } } do
		P(fh, "PalletBoxes", pb[1], 0, pb[2], pb[3])
	end
	P(fh, "TyreStack", 36, 0, -57.4)
	P(fh, "Trolley", 41, 0, -55.6, 30)
	for _, px in { -44, -28, 28, 44 } do
		P(fh, px < 0 and "PipeRunRust" or "PipeRun", px, 5, -58.9, 180)
	end
	P(fh, "JunctionBox", 4, 3, -59.2, 180)
	P(fh, "Forklift", 20, 0, -6, 90)
	P(fh, "CraftBench", -8, 0, -2.3, 0)
	P(fh, "ToolChest", -45, 0, -1.8, 0)
	P(fh, "PalletBoxes", -2, 0, -4.5)
	P(fh, "PalletBoxes", 2.6, 0, -4.2, 15)
	for _, d in { { 5.1, -7.2 }, { 7.6, -6.3 }, { 6.1, -9.5 } } do
		P(fh, "Drum", d[1], 0, d[2])
	end
	P(fh, "JerryCans", 10.4, 0, -8.1, 30)
	P(fh, "ElectricCabinet", 58.0, 0, -14, 90)
	P(fh, "FuseBox", 58.05, 0, -19.6, 90)
	P(fh, "PipeValve", 58.7, 0, -8, 90)
	P(fh, "WorkLight", -56, 0, -10, -60)
	for _, d in { { -57.5, -4 }, { -57.8, -6.4 } } do
		P(fh, "Drum", d[1], 0, d[2])
	end
	P(fh, "HoseReel", -59.1, 2, -14, -90)
	for _, o in { { -5, -8.5, 0 }, { 25, -2.5, 40 }, { -30, -50, 10 }, { 14, -30, 70 } } do
		P(fh, "OilStain", o[1], 0.02, o[2], o[3])
	end
	P(fh, "RubbleA", -58, 0, -24.5, 90)
	P(fh, "Rubble", 8, 0, -57.6)
	P(fh, "CeilingDebris", -45, 0, -30, 25)
	P(fh, "SteelPlate", -47, 0, -6, 80)
	-- casting shed: a pallet rack, the tool wall and bench, plates, drums
	P(cs, "PalletRack", -38, 0, 37.27, 0)
	P(cs, "WallShelfTools", -24, 0, 37.5, 0)
	P(cs, "CraftBench", -2.3, 0, 20, 90)
	P(cs, "Pegboard", -0.85, 7.4, 20, 90)
	P(cs, "Trolley", -12, 0, 24, 30)
	P(cs, "JerryCans", -55, 0, 6)
	for _, d in { { -57.5, 9 }, { -57, 11.6 } } do
		P(cs, "Drum", d[1], 0, d[2])
	end
	P(cs, "SteelPlate", -20, 0, 20, 90)
	P(cs, "SteelPlate", -21.6, 0, 21.4, 84)
	P(cs, "WorkLight", -45, 0, 20, 180)
	P(cs, "OilStain", -30, 0.02, 4)
	P(cs, "GlassShards", -2.5, 0.02, 12.5)
	-- pump house: the switch room side
	P(ph, "ElectricCabinet", 88, 0, 60.65, 0)
	P(ph, "FuseBox", 82, 0, 60.05, 0)
	P(ph, "PipeValve", 98.75, 0, 55, 90)
	P(ph, "WaterTank", 95, 0, 41.5, 180)
	P(ph, "HoseReel", 73, 2, 56, -90)
	-- tunnels: cable trays, cabinets, drums, debris
	for _, tx in { -70, -40, -10, 20 } do
		P(tun, "CableTray", tx, -3.6, -0.5, 0)
	end
	P(tun, "FuseBox", 38.5, -9, -7.05, 180)
	P(tun, "Drum", 48, -9, -6)
	P(tun, "Drum", 48.6, -9, -3.8)
	P(tun, "JerryCans", 37.5, -9, 2)
	P(tun, "Rubble", -60, -9, -1.5)
	P(tun, "RubbleA", -20, -9, -5.2, 10)
	P(tun, "Rubble", 2, -9, 30)
	P(tun, "RubbleA", -1.4, -9, 50, 30)
	P(tun, "Drum", 45, -9, 20)
	P(tun, "PalletBoxes", 41.6, -9, 35)
	P(tun, "WorkLight", -80, -9, -1.2, 180)
	print(string.format("[ZR] Smelter: %d kit props", nProps))

	-- ── loot ─────────────────────────────────────────────────────────────────────────────────────────────
	kit.container(cs, "SM1", "crate", "Ingot crate", CF(-52, 0, 4))
	kit.container(cs, "SM2", "toolbox", "Moulder's toolbox", CF(-5, 0, 36))
	kit.container(ob, "SM3", "locker", "Furnace crew locker", CF(-110.5, 0, -45, -90))
	kit.container(ob, "SM4", "locker", "Furnace crew locker", CF(-110.5, 0, -41.5, -90))
	kit.container(ob, "SM5", "drawer", "Records cabinet", CF(-78.5, 0, -52, 180))
	kit.container(ob, "SM6", "drawer", "Office drawers", CF(-78.5, FH1 + 0.3, -52, 180))
	kit.container(ob, "SM7", "safe", "Manager's safe", CF(-110, FH1 + 0.3, -52.2, 180))
	kit.container(yard, "SM8", "weaponbox", "Gate guard's case", CF(-85.5, 0, 87.6))
	kit.container(fh, "SM9", "crate", "Catwalk spares", CF(-12, DY, -57.4))
	kit.container(ph, "SM10", "toolbox", "Pump fitter's toolbox", CF(96, 0, 59))
	kit.container(tun, "SM11", "crate", "Tunnel stores", CF(48, TF, 1.4))
	kit.container(ob, "SM12", "medbag", "First-aid post", CF(-109.4, 0, -22.6, -90))
	local L = kit.loose
	for _, s in {
		{ -45, 1.65, 12, "junk", 0.4 }, { -25, 1.65, 28, "junk", 0.4 }, { -50, 2.76, -48, "junk", 0.45 }, { -40, DY + 0.05, -56, "junk", 0.35 },
		{ 45, DY + 0.05, -55, "junk", 0.35 }, { -32, DY + 0.05, -29, "junk", 0.3 }, { 43, TF + 0.05, 30, "junk", 0.35 },
		{ -60, TF + 0.05, -3, "junk", 0.3 }, { 0, TF + 0.05, 45, "keys", 0.25 }, { -104, 2.76, -27, "office", 0.5 },
		{ -80, 2.76, -48, "office", 0.5 }, { -104, 0.05, -48.6, "junk", 0.35 }, { -104, FH1 + 0.3 + 2.76, -48, "office", 0.75 },
		{ -106, FH1 + 0.3 + 2.76, -48.4, "keys", 0.35 }, { -85, FH1 + 0.3 + 2.76, -46, "office", 0.5 }, { -110.6, FH1 + 0.3 + 2.56, -26, "office", 0.45 },
		{ -84, 2.76, 83.4, "junk", 0.4 }, { 98.8, 3.35, 41, "junk", 0.4 }, { 85, 0.05, -64, "junk", 0.35 }, { -32, 2.45, 63, "junk", 0.3 },
		{ 44.5, 2.76, 82.8, "office", 0.4 },
	} do
		L(O.X + s[1], s[2], O.Z + s[3], s[4], s[5], "smelter")
	end

	-- ── exfils, spawns, AI ───────────────────────────────────────────────────────────────────────────────
	kit.extract(map, "SG", "MAIN GATE", V(-68, 0, 94), Vector3.new(16, 12, 10), { kind = "open" })
	kit.extract(map, "SR", "RAIL GATE", V(111, 0, -94), Vector3.new(12, 12, 10), { kind = "open" })
	kit.extract(map, "SN", "SERVICE GATE", V(40, 0, -94), Vector3.new(8, 10, 10), { kind = "chance", chance = 0.6 })
	kit.extract(map, "SK", "WATCHMAN'S DOOR", V(-126, 0, -80), Vector3.new(6, 9, 6), { kind = "key", key = "KEY_SMELT_OFFICE" })
	kit.extract(map, "ST", "SLAG TUNNEL", V(0, TF, 63), Vector3.new(6, 7, 12), { kind = "scav" }, { compact = true })
	local function sp(id, name, x, z, yaw, side)
		return { id = id, name = name, cf = CF(x, 3.4, z, yaw), side = side }
	end
	W.spawns = {
		sp("SW1", "WEST FENCE", -122, -10, -90, "west"), sp("SW2", "OFFICE GARDEN", -122, 60, -90, "west"),
		sp("SE1", "RAIL SPUR", 124, 60, 90, "east"), sp("SE2", "SCRAP HEAP", 122, -40, 90, "east"),
		sp("SS1", "WEIGHBRIDGE", 30, 92, 0, "south"), sp("SS2", "COAL BUNKER", -20, 92, 0, "south"),
	}
	W.sideExtracts = { west = { "SR", "SN" }, east = { "SG", "SK", "SN" }, south = { "SR", "SK", "SN" } }
	for _, s in W.spawns do
		s.extracts = W.sideExtracts[s.side]
	end
	W.patrols = {
		SH = { V(-40, 0, -20), V(-5, 0, -22), V(30, 0, -6), V(48, 0, -45), V(0, 0, -50), V(-45, 0, -40) },
		SY = { V(-66, 0, 60), V(-66, 0, -60), V(0, 0, -86), V(80, 0, -86), V(100, 0, 0), V(60, 0, 70), V(0, 0, 70) },
	}
	-- the Watch: a hall patrol, a yard patrol, the catwalk overwatch and the gate booth (posts need a route too)
	W.watchPosts = { { route = "SH" }, { route = "SH", post = V(0, DY, -54) }, { route = "SY", post = V(-81, 0, 87) }, { route = "SY" } }
	W.scavZones = {
		V(-40, 0, -20), V(0, 0, -20), V(30, 0, -50), V(-45, 0, -45), V(-30, 0, 20), V(-15, 0, 32), V(-100, 0, -36), V(-82, 0, -27),
		V(43, TF, 20), V(0, TF, -3), V(-60, TF, -3), V(0, TF, 40), V(86, 0, 56), V(-66, 0, 40), V(-66, 0, -40), V(20, 0, -70),
		V(80, 0, -66), V(100, 0, 40), V(30, 0, 70), V(-40, 0, 80), V(-100, 0, 60), V(-110, 0, -80), V(60, 0, -20), V(90, 0, 20),
	}
	W.visitZones = { STACK = { pos = V(-30, 0, -72), r = 14 } }
	W.boss = nil
	-- Tarkov's Factory bosses (audit ai.15): Tagilla at 30 %, roaming the hall with his hammer (our STOKER), and the
	-- cultists at 8 % in night raids, waiting in the dark corners (THE CULT, as on Border Yard)
	local hall = W.patrols.SH
	local stoker = {
		name = "THE STOKER", label = "Stoker", home = hall[1], route = hall, look = "stoker", loadout = "stokerLoadout", crew = {},
		chance = 0.3, hp = 1220 / 440, charge = true, zones = { { name = "FURNACE HALL", home = hall[1], route = hall } },
	}
	local cultZones = {}
	-- three scav-zone floors, each at least 55 studs from a PMC spawn
	for _, z in { { "SLAG STACK", -30, -72 }, { "SCRAP HALL", 60, -20 }, { "WEST SHEDS", -66, 40 } } do
		local home = V(z[2], 0, z[3])
		local crew = {}
		for _, o in { { 7, 5 }, { -7, 5 }, { 6, -7, 0.5 } } do
			table.insert(crew, {
				pos = V(z[2] + o[1], 0, z[3] + o[2]), label = "Cultist", look = "cultist", loadout = "cultistLoadout",
				hp = 850 / 440, skill = "boss", charge = "knife", ambush = true, post = true, chance = o[3],
			})
		end
		table.insert(cultZones, { name = z[1], home = home, post = home, crew = crew })
	end
	local cult = {
		name = "THE CULT", label = "Priest", home = cultZones[1].home, route = nil, look = "priest", loadout = "priestLoadout",
		chance = 0.08, night = true, hp = 850 / 440, skill = "boss", charge = "knife", ambush = true, zones = cultZones,
	}
	W.bosses = { stoker, cult }
	W.bounds = { x0 = O.X - 128, x1 = O.X + 128, z0 = O.Z - 98, z1 = O.Z + 98, yMin = -12, yMax = 16 }
	return map
end

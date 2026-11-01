--!nonstrict
-- Meridian Mall shell, step 1: floors (one slab per rectangle of the plan, a thin plate over each unit), the roof with its skylights
-- and the two domes, every wall of the plan (outer walls, galleries, party walls, store fronts with their glass, balustrades round
-- the voids, the low walls round the decks), the door leaves of the service rooms and the dock bay shutters.
local PI = math.pi
local CollectionService = game:GetService("CollectionService")

return function(ctx)
	local plan, O, W = ctx.plan, ctx.O, ctx.W
	local C, M, hex = ctx.C, ctx.M, ctx.hex
	local YL, CEIL = plan.YL, plan.CEIL
	local mk, ab, boxCF, glassOf = ctx.mk, ctx.ab, ctx.boxCF, ctx.glassOf
	local n = ctx.n
	local kit = ctx.kit
	local SLAB = 1.6
	local FH = 13.5 -- height of a store front's glass and of its entrance

	-- ── colours ──────────────────────────────────────────────────────────────────────────────────────────
	local FLOOR = { [0] = C.concreteDark, [1] = hex("8C8D86"), [2] = hex("8C8D86") }
	local DECK = hex("55585A")
	local INTERIOR = hex("7B7D75")
	local ROOF = hex("5A5D59")
	local METAL = C.metalDark
	local GLASS = ctx.GLASS or hex("9CC2CA") -- shopfront glass (set by Mall.luau)
	local KIND = {
		clothing = hex("6B4E5E"), electronics = hex("3E5868"), food = hex("8A5A3A"), general = hex("5E6448"), homeware = hex("7A6A4E"),
		books = hex("5A4A3A"), lighting = hex("8A7A3E"), shoes = hex("7A3E33"), sports = hex("3D5A57"), toys = hex("A2693A"),
		travel = hex("4A6A7A"), pharmacy = hex("4E7A62"), furniture = hex("6E5A44"), museum = hex("5A5E7A"), anchor = hex("5C6461"),
		["locked store"] = hex("4A4E4C"), ["locked room"] = hex("4A4E4C"), closed = hex("4A4E4C"), unlabelled = hex("5E5F5A"),
		stock = hex("66685F"), security = hex("3E4E6E"), washroom = hex("5E7A7A"),
	}
	local PLATE = {
		food = hex("A39682"), clothing = hex("9A8E94"), electronics = hex("8C9096"), pharmacy = hex("A4B0AA"), washroom = hex("B4BCBA"),
		stock = hex("6C6E68"), security = hex("7C8490"), tunnel = hex("575A56"), shelter = hex("4C4F4B"), unit14 = hex("4C4F4B"),
		vestibule = hex("575A56"),
	}
	-- the reverb a unit's floor plate asks the client for (attribute Reverb, read by Ambience.luau): tiled washrooms ring, the
	-- service tunnel and the shelter are bare concrete. Every other place is sorted by the client's own space probe.
	local PLATE_REVERB = { washroom = "Bathroom", tunnel = "StoneCorridor", shelter = "StoneRoom", vestibule = "StoneRoom", unit14 = "StoneRoom" }
	local function kindColor(kind)
		return KIND[kind] or hex("62665F")
	end
	ctx.kindColor = kindColor
	ctx.INTERIOR = INTERIOR

	-- ── floors ───────────────────────────────────────────────────────────────────────────────────────────
	local nFloor = n.parts
	for level = 0, 2 do
		local y = YL[level]
		local par = ctx.m[level]
		for _, r in plan.slabs[level] do
			local col = FLOOR[level]
			if r.k == 4 then
				col = DECK
			end
			local p = ab(par, r.x0, y - SLAB, r.z0, r.x1, y, r.z1, col, M.Concrete)
			if p then
				p.Name = "Floor"
			end
		end
		for _, r in plan.unitRects[level] do
			local u = plan.units[r.k - 10]
			if u then
				-- the plate is 0.03 proud of the slab so the two never fight; its top is the floor the stores stand on
				local p = ab(par, r.x0, y - 0.3, r.z0, r.x1, y + 0.03, r.z1, PLATE[u.kind] or hex("9A9B93"), M.Concrete)
				if p then
					p.Name = "UnitFloor"
					if PLATE_REVERB[u.kind] then
						p:SetAttribute("Reverb", PLATE_REVERB[u.kind])
					end
					u.plates = u.plates or {}
					u.plates[#u.plates + 1] = p
				end
			end
		end
	end
	-- the deck pieces at the dock ramps: what the terrace slabs do not already cover (no two slabs share a top face)
	local function without(rects, s)
		local out = {}
		for _, r in rects do
			if s.x1 <= r.x0 or s.x0 >= r.x1 or s.z1 <= r.z0 or s.z0 >= r.z1 then
				out[#out + 1] = r
			else
				if s.z0 > r.z0 then
					out[#out + 1] = { x0 = r.x0, z0 = r.z0, x1 = r.x1, z1 = s.z0 }
				end
				if s.z1 < r.z1 then
					out[#out + 1] = { x0 = r.x0, z0 = s.z1, x1 = r.x1, z1 = r.z1 }
				end
				local za, zb = math.max(r.z0, s.z0), math.min(r.z1, s.z1)
				if s.x0 > r.x0 then
					out[#out + 1] = { x0 = r.x0, z0 = za, x1 = s.x0, z1 = zb }
				end
				if s.x1 < r.x1 then
					out[#out + 1] = { x0 = s.x1, z0 = za, x1 = r.x1, z1 = zb }
				end
			end
		end
		return out
	end
	for _, e in plan.extraSlabs do
		local pieces = { { x0 = e.x0, z0 = e.z0, x1 = e.x1, z1 = e.z1 } }
		for _, s in plan.slabs[e.level] do
			pieces = without(pieces, s)
		end
		for _, r in pieces do
			if r.x1 - r.x0 > 0.05 and r.z1 - r.z0 > 0.05 then
				ab(ctx.m[e.level], r.x0, YL[e.level] - SLAB, r.z0, r.x1, YL[e.level], r.z1, DECK, M.Concrete)
			end
		end
	end
	ctx.stat.floors = n.parts - nFloor

	-- ── roof, skylights, domes ───────────────────────────────────────────────────────────────────────────
	local nRoof = n.parts
	local rp = ctx.m.roof
	for _, r in plan.roofRects do
		if r.k == 1 then
			-- the hall roof is thin: its top (CEIL[1] + 0.7 = 46.64) stays more than 0.7 below the L2 floor height, so Play's floor
			-- test (a top within 0.7 of 47.50) does not take the roof for an L2 floor
			ab(rp, r.x0, CEIL[1], r.z0, r.x1, CEIL[1] + 0.7, r.z1, ROOF, M.Concrete)
		elseif r.k == 2 then
			ab(rp, r.x0, CEIL[2], r.z0, r.x1, CEIL[2] + SLAB - 0.04, r.z1, ROOF, M.Concrete)
		elseif r.k == 3 then
			local sky = glassOf(ab(rp, r.x0, CEIL[1] + 0.1, r.z0, r.x1, CEIL[1] + 0.55, r.z1, ROOF, M.Glass))
			if sky then
				CollectionService:AddTag(sky, "ZR_Skylight") -- clients put a little dust in the light under it (Ambience.luau)
			end
		elseif r.k == 4 then
			local sky = glassOf(ab(rp, r.x0, CEIL[2] + 0.5, r.z0, r.x1, CEIL[2] + 0.9, r.z1, ROOF, M.Glass))
			if sky then
				CollectionService:AddTag(sky, "ZR_Skylight")
			end
		end
	end
	-- the domes: an octagonal drum of glass on the roof round each atrium and a stepped cap
	for _, a in plan.atria do
		local pts = a.pts
		local np = math.floor(#pts / 2)
		local ap = math.huge
		for i = 1, np do
			local j = i % np + 1
			local ex, ez = pts[2 * j - 1] - pts[2 * i - 1], pts[2 * j] - pts[2 * i]
			local len = math.sqrt(ex * ex + ez * ez)
			local d = math.abs((a.cx - pts[2 * i - 1]) * ez - (a.cz - pts[2 * i]) * ex) / len
			if d < ap then
				ap = d
			end
		end
		-- the roof hole is the polygon shrunk by 4.6 studs (MallPlan.slabs); the drum stands 1.7 studs inside the atrium's edge, that is
		-- 2.9 studs outside the hole's edge, on solid roof (the hole's raster edge is within 1.6 studs of the shrunk polygon)
		local k = (ap - 1.7) / ap
		local yb = CEIL[2] + SLAB - 0.04
		local hD = 9
		local radius = 0
		for i = 1, np do
			local j = i % np + 1
			local x1, z1 = a.cx + (pts[2 * i - 1] - a.cx) * k, a.cz + (pts[2 * i] - a.cz) * k
			local x2, z2 = a.cx + (pts[2 * j - 1] - a.cx) * k, a.cz + (pts[2 * j] - a.cz) * k
			local ex, ez = x2 - x1, z2 - z1
			local len = math.sqrt(ex * ex + ez * ez)
			radius = math.max(radius, math.sqrt((x1 - a.cx) * (x1 - a.cx) + (z1 - a.cz) * (z1 - a.cz)))
			local cf = CFrame.new(O.X + (x1 + x2) / 2, yb - 0.1 + hD / 2, O.Z + (z1 + z2) / 2) * CFrame.Angles(0, -math.atan2(ez, ex), 0)
			glassOf(boxCF(rp, cf, len + 0.4, hD, 0.5, ROOF, M.Glass))
			boxCF(rp, CFrame.new(O.X + (x1 + x2) / 2, yb + hD + 0.3, O.Z + (z1 + z2) / 2) * CFrame.Angles(0, -math.atan2(ez, ex), 0), len + 0.8, 0.8, 1.0, METAL, M.Metal)
		end
		-- the cap: four discs, each smaller than the one below
		local top = yb + hD + 0.7
		local rad = radius * 1.04
		for q = 1, 4 do
			local d = kit.vcyl(rp, 1.1, rad * 2, O.X + a.cx, top, O.Z + a.cz, q == 4 and METAL or ROOF, q == 4 and M.Metal or M.Concrete)
			d.CanTouch = false
			d.CastShadow = false
			n.parts += 1
			top += 1.1
			rad = rad * 0.7
		end
	end
	ctx.stat.roof = n.parts - nRoof

	-- ── walls ────────────────────────────────────────────────────────────────────────────────────────────
	local nWalls = n.parts
	-- a run's extent along its axis and its line
	local function span(r)
		if r.x0 == r.x1 then
			return r.z0 - (r.ext0 or 0), r.z1 + (r.ext1 or 0), "z", r.x0
		end
		return r.x0 - (r.ext0 or 0), r.x1 + (r.ext1 or 0), "x", r.z0
	end
	-- a wall box along `axis` at `line`, from a to b, thickness t, y from ya to yb
	local function wbox(par, axis, line, a, b, t, ya, yb, color, mat)
		if b - a < 0.02 or yb - ya < 0.02 then
			return nil
		end
		if axis == "x" then
			return ab(par, a, ya, line - t / 2, b, yb, line + t / 2, color, mat)
		end
		return ab(par, line - t / 2, ya, a, line + t / 2, yb, b, color, mat)
	end
	-- the solid pieces and the holes of a span cut by its (sorted) gaps
	local function cut(lo, hi, gaps)
		local solid, holes = {}, {}
		local x = lo
		if gaps then
			for _, gp in gaps do
				local a, b = gp.c - gp.w / 2, gp.c + gp.w / 2
				if a < lo then
					a = lo
				end
				if b > hi then
					b = hi
				end
				if b > a then
					if a > x + 0.01 then
						solid[#solid + 1] = { x, a }
					end
					holes[#holes + 1] = { a, b, gp }
					x = b
				end
			end
		end
		if hi > x + 0.01 then
			solid[#solid + 1] = { x, hi }
		end
		return solid, holes
	end
	-- a wall with openings: short pieces between the holes and one header over the lot when every hole has the same height,
	-- else full pieces with a lintel over each hole
	local function wallRun(par, axis, line, lo, hi, t, y0, top, color, mat, gaps)
		local solid, holes = cut(lo, hi, gaps)
		local ya = y0 - 0.2
		if #holes == 0 then
			wbox(par, axis, line, lo, hi, t, ya, top, color, mat)
			return holes
		end
		local hmin, hmax = math.huge, 0
		for _, h in holes do
			local hh = h[3].h
			if hh < hmin then
				hmin = hh
			end
			if hh > hmax then
				hmax = hh
			end
		end
		if hmax - hmin < 0.01 and y0 + hmin < top - 0.5 then
			for _, s in solid do
				wbox(par, axis, line, s[1], s[2], t, ya, y0 + hmin, color, mat)
			end
			wbox(par, axis, line, lo, hi, t, y0 + hmin, top, color, mat)
		else
			for _, s in solid do
				wbox(par, axis, line, s[1], s[2], t, ya, top, color, mat)
			end
			for _, h in holes do
				if y0 + h[3].h < top - 0.3 then
					wbox(par, axis, line, h[1], h[2], t, y0 + h[3].h, top, color, mat)
				end
			end
		end
		return holes
	end

	-- door leaves (W.doors): the leaf swings into the unit whose wall it stands in
	local DOORYAW = { N = PI, S = 0, W = -PI / 2, E = PI / 2 }
	local OUTWARD = { N = { 0, -1 }, S = { 0, 1 }, W = { -1, 0 }, E = { 1, 0 } }
	local function addDoor(level, axis, line, gp, spec, par, t)
		local d = spec.door
		local y0 = YL[level]
		local x, z = line, gp.c
		if axis == "x" then
			x, z = gp.c, line
		end
		local rec = {
			id = d.id, cf = CFrame.new(O.X + x, y0 + gp.h / 2, O.Z + z) * CFrame.Angles(0, DOORYAW[spec.side] or 0, 0),
			size = Vector3.new(gp.w, gp.h, 0.35), key = d.key, label = d.label, parent = par, color = hex("6A6E66"),
		}
		if not d.key then
			rec.openChance = 0.4
		end
		if d.key == "CARD_MALL_VAULT" or d.key == "KEY_MM_UNIT14" then
			-- a keycard door: heavy plate, a reader beside it on the outside with a status lamp
			rec.card = true
			rec.color = hex("6B706C")
			local out = OUTWARD[spec.side] or { 0, 1 }
			local ax, az = x, z
			if axis == "x" then
				ax = x + gp.w / 2 + 1.5
			else
				az = z + gp.w / 2 + 1.5
			end
			local rx, rz = ax + out[1] * (t / 2 + 0.2), az + out[2] * (t / 2 + 0.2)
			local sx, sz = 1.2, 1.2
			if out[1] ~= 0 then
				sx = 0.4
			else
				sz = 0.4
			end
			local panel = mk(par, rx, y0 + 4.8, rz, sx, 1.9, sz, hex("2E3332"), M.Metal)
			local led = mk(par, rx + out[1] * 0.25, y0 + 5.3, rz + out[2] * 0.25, out[1] ~= 0 and 0.2 or 0.5, 0.5, out[2] ~= 0 and 0.2 or 0.5, hex("C24A35"), M.Neon)
			if panel then
				panel.Name = "Reader"
			end
			if led then
				led.Name = "Led"
				led.CanCollide = false
				led.CastShadow = false
				rec.led = led
			end
		end
		W.doors[d.id] = rec
		n.doors += 1
		if spec.unit then
			spec.unit.doorIds = spec.unit.doorIds or {}
			table.insert(spec.unit.doorIds, d.id)
		end
		return rec
	end

	ctx.wallRun, ctx.addDoor, ctx.cut = wallRun, addDoor, cut

	local function openingDeco(level, axis, line, gp, a, b, par, t)
		local y0 = YL[level]
		if gp.kind == "door" and gp.spec and gp.spec.door then
			addDoor(level, axis, line, gp, gp.spec, par, t)
		elseif gp.kind == "dock" and gp.spec and not gp.spec.open then
			-- a closed roller shutter in the bay
			local p = wbox(par, axis, line, a, b, 0.5, y0, y0 + gp.h - 0.2, hex("6E7A74"), M.CorrodedMetal)
			if p then
				p.Name = "Shutter"
			end
		end
	end

	local frontSides = {} -- unit idx -> { N = len, S = len ... } of the fronts with an entrance
	local signs = {} -- unit idx -> the widest entrance { level, axis, line, c, w, side }

	-- a store front: one header over the whole run, panes of glass between the entrances
	local function shopFront(level, r, lo, hi, axis, line)
		local i = r.info
		local u = i.unit
		local par = ctx.m[level]
		local y0 = YL[level]
		local t = i.t
		local solid, holes = cut(lo, hi, r.gaps)
		local kc = kindColor(u.kind)
		wbox(par, axis, line, lo, hi, t, y0 + FH, i.top, kc, M.Plaster)
		for _, s in solid do
			local p = wbox(par, axis, line, s[1], s[2], 0.5, y0 - 0.1, y0 + FH, GLASS, M.Glass)
			glassOf(p)
		end
		local best = nil
		for _, h in holes do
			local gp = h[3]
			if gp.kind == "shop" then
				if not best or gp.w > best.w then
					best = gp
				end
				local fs = frontSides[u.idx]
				if not fs then
					fs = {}
					frontSides[u.idx] = fs
				end
				fs[i.side] = (fs[i.side] or 0) + (h[2] - h[1])
			elseif gp.kind == "door" then
				openingDeco(level, axis, line, gp, h[1], h[2], par, t)
			end
		end
		if best then
			local old = signs[u.idx]
			if not old or best.w > old.w then
				signs[u.idx] = { level = level, axis = axis, line = line, c = best.c, w = best.w, side = i.side, t = t }
			end
			-- a roller grille housing over the entrances of every third store (the grille itself is rolled up)
			if u.idx % 3 == 0 then
				for _, h in holes do
					if h[3].kind == "shop" then
						local p = wbox(par, axis, line + 0, h[1] - 0.4, h[2] + 0.4, t + 0.8, y0 + FH - 1.5, y0 + FH, METAL, M.Metal)
						if p then
							p.Name = "GrilleHousing"
						end
					end
				end
			end
		end
	end

	-- a balustrade along a void: glass between posts of the handrail
	local function railRun(level, r, lo, hi, axis, line)
		local i = r.info
		local par = ctx.m[level]
		local y0 = YL[level]
		local off = 0.45
		if i.walk == "a" then
			off = -0.45
		end
		local ln = line + off
		local solid = cut(lo, hi, r.gaps)
		for _, s in solid do
			if s[2] - s[1] >= 0.3 then
				glassOf(wbox(par, axis, ln, s[1], s[2], 0.25, y0, y0 + 3.5, GLASS, M.Glass))
				local hr = wbox(par, axis, ln, s[1] - 0.1, s[2] + 0.1, 0.5, y0 + 3.5, y0 + 4.0, METAL, M.Metal)
				if hr then
					hr.Name = "Handrail"
				end
			end
		end
	end

	for level = 0, 2 do
		local par = ctx.m[level]
		local y0 = YL[level]
		for _, orient in { "v", "h" } do
			for _, r in plan.runs[level][orient] do
				local i = r.info
				local lo, hi, axis, line = span(r)
				if i.style == "front" then
					shopFront(level, r, lo, hi, axis, line)
				elseif i.style == "rail" then
					railRun(level, r, lo, hi, axis, line)
				else
					local color, mat = INTERIOR, M.Plaster
					if i.style == "ext" then
						color, mat = C.concrete, M.Concrete
					elseif i.style == "parapet" then
						color, mat = C.concreteLight, M.Concrete
					elseif level == 0 then
						color, mat = C.concrete, M.Concrete
					elseif i.unit and i.unit.service then
						color, mat = hex("74766E"), M.Plaster
					end
					local holes = wallRun(par, axis, line, lo, hi, i.t, y0, i.top, color, mat, r.gaps)
					for _, h in holes do
						openingDeco(level, axis, line, h[3], h[1], h[2], par, i.t)
					end
				end
			end
		end
	end
	ctx.stat.walls = n.parts - nWalls

	-- which side of each unit its entrance is on (the side with the most entrance width; service rooms: the side of a door)
	for _, u in plan.units do
		local best, bl = nil, 0
		local fs = frontSides[u.idx]
		if fs then
			for side, len in fs do
				if len > bl then
					best, bl = side, len
				end
			end
		end
		if not best and u.doors and u.doors[1] then
			best = u.doors[1].side
		end
		if not best then
			for _, e in u.ents do
				best = e.side
				break
			end
		end
		u.front = best
	end

	-- ── signs over the entrances ─────────────────────────────────────────────────────────────────────────
	local nSign = n.parts
	for _, u in plan.units do
		local sg = signs[u.idx]
		if sg then
			local out = OUTWARD[sg.side] or { 0, 1 }
			local y0 = YL[sg.level]
			local text = u.name
			if text == "" then
				text = string.upper(u.kind)
			end
			local width = math.clamp(#text * 1.15 + 4, 8, 26)
			local x, z = sg.line, sg.c
			if sg.axis == "x" then
				x, z = sg.c, sg.line
			end
			local off = sg.t / 2 + 0.2
			local pos = Vector3.new(O.X + x + out[1] * off, y0 + FH + 3.2, O.Z + z + out[2] * off)
			local cf = CFrame.lookAt(pos, pos + Vector3.new(out[1], 0, out[2]))
			local board = boxCF(ctx.m.units, cf, width, 3.4, 0.35, hex("2A2F2E"), M.Metal)
			if board then
				board.Name = "Sign_" .. u.id
				board:SetAttribute("NoDetail", true)
				u.signGui = kit.sign(board, Enum.NormalId.Front, text, hex("E8E2CC"), kindColor(u.kind))
				u.sign = board
			end
		end
	end
	ctx.stat.signs = n.parts - nSign
end

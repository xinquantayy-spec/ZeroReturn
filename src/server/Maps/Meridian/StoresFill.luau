--!nonstrict
-- Meridian Mall small shops, the furnishing pass (docs/maps/MERIDIAN_MALL.md, "Small shops"). StoresL1 and StoresL2 call
-- Fill.shop(a) when a shop's recipe is done. The pass only adds to what the recipe made: a fitting room in the clothes shops, units
-- along the bare stretches of wall (hanging rails, shoe walls, kit shelves, TV walls, pegboards), posters and price boards, fixtures on
-- the free floor and litter beside them. It runs after the recipe with its own random numbers and keeps clear of every container (with
-- the space to stand at it), loose-loot spot, key tile, opening and door, so nothing the recipes registered moves or gets covered.
-- a = { id, level, cf, W, D, ceil, kind, u, rects(), take(x0, d0, x1, d1), noPoster, extra }. Unit coordinates as in StoresL1Kit.luau:
-- x to the right when facing out through the front, d the depth from the front wall, heights above the floor; cf is the middle of
-- the floor looking out through the front. rects() lists what is taken as { x0, d0, x1, d1 }; take() reports what this pass takes.
-- Budget (hard): LIMIT parts over both levels, counting the kit's pieces and colliders as parts. Every part of ours has CastShadow and
-- CanTouch off; the ones nobody bumps into have CanCollide and CanQuery off too, so bullets, the AI's rays and the loot snap pass through.
-- Parts of equal size and colour are reused: long single parts (a rail of hanging clothes, a band of boxes) carry the look, not rows.
return function(B)
	if B.shopFill then
		return B.shopFill
	end
	local kit, W, Kit, O = B.kit, B.W, B.Kit, B.O
	local M, hex = kit.M, kit.hex
	local V = Vector3.new
	local rad = math.rad
	local Fill = {}
	B.shopFill = Fill

	-- the hard budget of this pass: parts it may add on each level and in all (the 2,000 of the task, with a margin)
	local LIMIT = { total = 1960, lv1 = 1650, lv2 = 560 }
	local tot = {
		parts = 0, own = 0, pieces = 0, colliders = 0, props = 0, shops = 0, refused = 0,
		cats = { fit = 0, wall = 0, poster = 0, band = 0, floor = 0, clutter = 0 },
		lv1 = { parts = 0, shops = 0 }, lv2 = { parts = 0, shops = 0 },
		list = {},
	}
	Fill.tot = tot

	local root = kit.model("StoresFill", B.map)
	root:SetAttribute("NoWire", true) -- indoors: no barbed wire from the detail plan
	root:SetAttribute("DetailProfile", "clean")

	-- ── pacing, ids ─────────────────────────────────────────────────────────────────────────────────────
	local lastPace = os.clock()
	local function pace()
		if task and os.clock() - lastPace > 0.04 then
			task.wait()
			lastPace = os.clock()
		end
	end
	local function hashId(s)
		local h = 11
		for i = 1, #s do
			h = (h * 31 + string.byte(s, i)) % 2147483000
		end
		return h + 1
	end

	-- ── colours: a small set, every one defined here ────────────────────────────────────────────────────
	local P = {
		slat = hex("8B7C65"), slatDark = hex("5E5447"), chrome = hex("A9AFAD"), steel = hex("6A7270"), black = hex("272B2A"),
		charcoal = hex("3A3F3D"), cream = hex("CDC5AC"), white = hex("D8D8D0"), grey = hex("6F7370"), wood = hex("77603F"),
		woodDark = hex("554632"), card = hex("A98C63"), cardDark = hex("87714B"), glass = hex("8FB3BD"),
		red = hex("983F37"), blue = hex("3F5F7A"), green = hex("50744F"), yellow = hex("C4A241"), orange = hex("BF703B"),
		plum = hex("6E4F62"), teal = hex("3E6661"), pink = hex("B77A8C"), navy = hex("2F4357"), olive = hex("5E6448"), sand = hex("B1A893"),
	}
	local CLOTH = { P.red, P.blue, P.green, P.plum, P.teal, P.navy, P.olive, P.sand, P.orange, P.grey, P.cream }
	local SHOEBOX = { P.card, P.cardDark, P.white, P.blue, P.red, P.charcoal }
	local BOOKS = { P.red, P.blue, P.green, P.wood, P.cream, P.plum, P.navy }
	local TOYS = { P.red, P.yellow, P.blue, P.green, P.orange, P.pink }
	local FOOD = { P.red, P.yellow, P.green, P.orange, P.white, P.card }
	local SPORT = { P.orange, P.white, P.red, P.blue, P.black }
	local TECH = { P.black, P.charcoal, P.blue, P.teal, P.steel }
	local PHARM = { P.white, P.green, P.teal, P.cream }
	local PAPER = { P.white, P.cream }
	local CARD = { P.card, P.cardDark }
	local SUITCASE = { P.navy, P.red, P.olive, P.grey, P.teal, P.sand }
	local RUGS = { P.plum, P.teal, P.sand, P.olive, P.red, P.navy }
	local BINGOODS = {
		cloth = CLOTH, toy = TOYS, food = FOOD, produce = { P.green, P.red, P.orange, P.yellow }, sport = SPORT, books = BOOKS,
		shoe = SHOEBOX, tech = TECH, pharm = PHARM,
	}
	local POSTERS = {
		fashion = { P.plum, P.pink, P.navy, P.sand, P.teal, P.cream }, tech = { P.navy, P.teal, P.black, P.blue, P.steel },
		sport = { P.red, P.orange, P.black, P.blue, P.white }, book = { P.cream, P.wood, P.green, P.navy, P.red },
		toy = { P.red, P.yellow, P.blue, P.green, P.orange, P.pink }, home = { P.sand, P.cream, P.olive, P.teal, P.wood },
		travel = { P.blue, P.teal, P.sand, P.green, P.orange }, sale = { P.red, P.yellow, P.orange, P.white },
		food = { P.green, P.yellow, P.orange, P.red, P.cream }, pharm = { P.green, P.white, P.teal, P.cream },
		museum = { P.wood, P.navy, P.olive, P.cream },
	}

	-- ── kit prop geometry, as StoresL1Kit.luau has it: footprint (rotated) in unit axes, parts per prop ─────────
	local okMeta, KitMeta = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("ZR"):WaitForChild("KitMeta"))
	end)
	local function kitCost(name, noCollide)
		local pcs = 3
		local p = okMeta and KitMeta and KitMeta.props and KitMeta.props[name]
		if p and p.pieces then
			pcs = #p.pieces
		end
		local cols = 1
		if noCollide then
			cols = 0
		elseif Kit.COLL and Kit.COLL[name] then
			cols = #Kit.COLL[name]
		end
		return pcs + cols
	end
	local function rot(ry, cx, cz, hx, hz)
		if ry == 90 then
			return cz, -cx, hz, hx
		elseif ry == -90 then
			return -cz, cx, hz, hx
		elseif ry == 180 then
			return -cx, -cz, hx, hz
		end
		return cx, cz, hx, hz
	end
	local FP = {}
	local function footprint(name, ry, sc)
		local key = name .. ":" .. ry .. ":" .. (sc and (sc.X .. "," .. sc.Z) or "1")
		local fp = FP[key]
		if fp then
			return fp
		end
		local size, center = Kit.size(name)
		if not size or not center then
			return nil
		end
		local sx, sz, cx, cz = size.X, size.Z, center.X, center.Z
		if sc then
			sx, sz, cx, cz = sx * sc.X, sz * sc.Z, cx * sc.X, cz * sc.Z
		end
		local ox, od, hx, hz = rot(ry, cx, cz, sx / 2, sz / 2)
		fp = { ox = ox, od = od, hx = hx, hz = hz }
		FP[key] = fp
		return fp
	end

	local WALLRY = { B = 0, F = 180, L = -90, R = 90 }
	local RYS = { 0, 90, 180, -90 }

	-- ── one shop's working state ────────────────────────────────────────────────────────────────────────
	local function worldCF(c, x, h, d, ry)
		return c.cf * CFrame.new(x, h, d - c.D / 2) * CFrame.Angles(0, rad(ry or 0), 0)
	end
	local function toUnit(c, p)
		local lp = c.cf:PointToObjectSpace(p)
		return lp.X, lp.Z + c.D / 2, lp.Y
	end
	local function inReach(c, x, d, m)
		return x > -c.hw - m and x < c.hw + m and d > -m and d < c.D + m
	end
	local function pick(c, list)
		return list[c.rng:NextInteger(1, #list)]
	end

	-- free floor: inside the walls and clear of every rectangle taken, `pad` studs apart from them
	local function free(c, x0, d0, x1, d1, pad)
		pad = pad or 0
		if x0 < -c.hw + 0.1 or x1 > c.hw - 0.1 or d0 < 0.1 or d1 > c.D - 0.1 then
			return false
		end
		local occ = c.occ
		for i = 1, #occ do
			local r = occ[i]
			if x0 - pad < r[3] - 0.01 and x1 + pad > r[1] + 0.01 and d0 - pad < r[4] - 0.01 and d1 + pad > r[2] + 0.01 then
				return false
			end
		end
		return true
	end
	-- a solid fixture: kept in our list and reported to the shop's frame
	local function take(c, x0, d0, x1, d1)
		c.occ[#c.occ + 1] = { x0, d0, x1, d1 }
		c.anchors[#c.anchors + 1] = { x0, d0, x1, d1 }
		c.a.take(x0, d0, x1, d1)
	end
	-- parts it may still add now: this shop's share so far, the level's limit, the total
	local function afford(c, cost)
		local lv = tot["lv" .. c.level]
		if tot.parts + cost > LIMIT.total or (lv and lv.parts + cost > LIMIT["lv" .. c.level]) then
			return false
		end
		return c.spent + cost <= c.cap + 0.01
	end
	local function bump(c, own, pieces, colliders)
		local k = own + pieces + colliders
		c.spent += k
		tot.parts += k
		tot.own += own
		tot.pieces += pieces
		tot.colliders += colliders
		tot.cats[c.phase] += k
		c.by[c.phase] += k
		local lv = tot["lv" .. c.level]
		if lv then
			lv.parts += k
		end
	end

	-- ── primitives ──────────────────────────────────────────────────────────────────────────────────────
	local function mk(c, sx, sy, sz, cf, color, mat, collide, name)
		pace()
		local p = kit.boxCF(c.model, sx, sy, sz, cf, color or P.grey, mat or M.SmoothPlastic)
		p.CastShadow = false
		p.CanTouch = false
		if not collide then
			p.CanCollide = false
			p.CanQuery = false
		end
		if mat == M.Glass then
			p.Transparency = 0.55
		end
		p:SetAttribute("NoDetail", true)
		p.Name = name or "Fill"
		bump(c, 1, 0, 0)
		return p
	end
	-- a box from its unit rectangle and heights
	local function box(c, x0, d0, x1, d1, h0, h1, color, mat, collide, name)
		if x1 - x0 < 0.02 or d1 - d0 < 0.02 or h1 - h0 < 0.02 then
			return nil
		end
		return mk(c, x1 - x0, h1 - h0, d1 - d0, worldCF(c, (x0 + x1) / 2, (h0 + h1) / 2, (d0 + d1) / 2, 0), color, mat, collide, name)
	end
	-- (x, d) of a local point of a fixture turned by ry
	local function turn(ry, x, z)
		if ry == 90 then
			return z, -x
		elseif ry == -90 then
			return -z, x
		elseif ry == 180 then
			return -x, -z
		end
		return x, z
	end
	-- a fixture from its part list { x0, z0, x1, z1, y0, y1, colour, material, solid, name } in its own frame (x across, z toward the
	-- wall or back, y up), centred at (cx, cd) and turned by ry
	local function emit(c, list, cx, cd, ry)
		for _, s in list do
			local ax, az = turn(ry, s[1], s[2])
			local bx, bz = turn(ry, s[3], s[4])
			box(c, cx + math.min(ax, bx), cd + math.min(az, bz), cx + math.max(ax, bx), cd + math.max(az, bz), s[5], s[6], s[7], s[8], s[9], s[10])
		end
	end
	-- a kit prop whose footprint is centred on (x, d); o.sc scales it, o.h lifts it
	local function placeKit(c, name, x, d, ry, o)
		o = o or {}
		local fp = footprint(name, ry, o.sc)
		if not fp then
			return false
		end
		pace()
		local opts = { shadows = false }
		if o.sc then
			opts.scale = o.sc
		end
		local m = Kit.place(c.model, name, worldCF(c, x - fp.ox, o.h or 0, d - fp.od, ry), opts)
		if not m then
			return false
		end
		for _, ch in m:GetChildren() do
			if ch.Name == "KitCollider" then
				bump(c, 0, 0, 1)
			else
				bump(c, 0, 1, 0)
			end
		end
		tot.props += 1
		return true
	end
	-- a flat thing on the wall: a0..a1 along it, o0..o1 off its face
	local function wallRect(c, side, along, len, dep, gap)
		if side == "B" then
			return along - len / 2, c.D - gap - dep, along + len / 2, c.D - gap
		elseif side == "F" then
			return along - len / 2, gap, along + len / 2, gap + dep
		elseif side == "L" then
			return -c.hw + gap, along - len / 2, -c.hw + gap + dep, along + len / 2
		end
		return c.hw - gap - dep, along - len / 2, c.hw - gap, along + len / 2
	end
	local function wallBox(c, side, a0, a1, o0, o1, h0, h1, color, mat, name)
		if side == "B" then
			return box(c, a0, c.D - o1, a1, c.D - o0, h0, h1, color, mat, false, name)
		elseif side == "F" then
			return box(c, a0, o0, a1, o1, h0, h1, color, mat, false, name)
		elseif side == "L" then
			return box(c, -c.hw + o0, a0, -c.hw + o1, a1, h0, h1, color, mat, false, name)
		end
		return box(c, c.hw - o1, a0, c.hw - o0, a1, h0, h1, color, mat, false, name)
	end
	-- the walking strip in front of something that stands against `side`
	local function laneOf(side, x0, d0, x1, d1, w)
		if side == "B" then
			return x0, d0 - w, x1, d0
		elseif side == "F" then
			return x0, d1, x1, d1 + w
		elseif side == "L" then
			return x1, d0, x1 + w, d1
		end
		return x0 - w, d0, x0, d1
	end

	-- ── what to keep clear of: loose spots, containers and their space, key tiles ────────────────────────────
	local function addAvoid(c)
		local occ = c.occ
		for _, sp in W.looseSpots do
			if sp.pos then
				local x, d, y = toUnit(c, sp.pos)
				if inReach(c, x, d, 2) and y > -3 and y < 14 then
					occ[#occ + 1] = { x - 1.5, d - 1.5, x + 1.5, d + 1.5 }
				end
			end
		end
		for _, ct in W.containers do
			local p = ct.part
			if p and p.CFrame and p.Size then
				local x0, d0, x1, d1, cy = 1e9, 1e9, -1e9, -1e9, 0
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local lp = c.cf:PointToObjectSpace(p.CFrame * V(sx * p.Size.X / 2, 0, sz * p.Size.Z / 2))
						local dd = lp.Z + c.D / 2
						x0, x1 = math.min(x0, lp.X), math.max(x1, lp.X)
						d0, d1 = math.min(d0, dd), math.max(d1, dd)
						cy = lp.Y
					end
				end
				if x1 > -c.hw - 3 and x0 < c.hw + 3 and d1 > -3 and d0 < c.D + 3 and cy > -3 and cy < 14 then
					occ[#occ + 1] = { x0 - 2.4, d0 - 2.4, x1 + 2.4, d1 + 2.4 }
				end
			end
		end
		local keys = B.L and B.L.keys
		if keys then
			for _, k in keys do
				if k.x and k.z then
					local x, d = toUnit(c, V(O.X + k.x, c.cf.Position.Y, O.Z + k.z))
					if inReach(c, x, d, 6) then
						occ[#occ + 1] = { x - 4, d - 4, x + 4, d + 4 }
					end
				end
			end
		end
		for _, r in c.a.extra or {} do
			occ[#occ + 1] = { r[1], r[2], r[3], r[4] }
		end
		-- the way to the stock door: 7 studs of floor in front of it, a little wider than the leaf
		local st = c.a.u and c.a.u.stock
		local door = st and st.door and W.doors[st.door]
		if door and door.cf then
			local x, d = toUnit(c, door.cf.Position)
			local hw = ((door.size and door.size.X) or 5) / 2 + 0.8
			local dF, dB, dL, dR = math.abs(d), math.abs(c.D - d), math.abs(x + c.hw), math.abs(c.hw - x)
			local m = math.min(dF, dB, dL, dR)
			if m < 5 then
				if m == dB then
					occ[#occ + 1] = { x - hw, c.D - 7, x + hw, c.D + 1 }
				elseif m == dF then
					occ[#occ + 1] = { x - hw, -1, x + hw, 7 }
				elseif m == dL then
					occ[#occ + 1] = { -c.hw - 1, d - hw, -c.hw + 7, d + hw }
				else
					occ[#occ + 1] = { c.hw - 7, d - hw, c.hw + 1, d + hw }
				end
			end
		end
	end

	-- the openings of the unit's walls (entrances and the stock door), as stretches along each wall to keep bare
	local function openingSpans(c, u)
		local open = { B = {}, F = {}, L = {}, R = {} }
		local function add(pos, width)
			local x, d = toUnit(c, pos)
			local dF, dB, dL, dR = math.abs(d), math.abs(c.D - d), math.abs(x + c.hw), math.abs(c.hw - x)
			local m = math.min(dF, dB, dL, dR)
			if m > 5 then
				return
			end
			local half = width / 2 + 1.2
			if m == dB then
				open.B[#open.B + 1] = { x - half, x + half }
			elseif m == dF then
				open.F[#open.F + 1] = { x - half, x + half }
			elseif m == dL then
				open.L[#open.L + 1] = { d - half, d + half }
			else
				open.R[#open.R + 1] = { d - half, d + half }
			end
		end
		if u then
			for _, e in u.entrances or {} do
				if e.pos then
					add(e.pos, e.width or 6)
				end
			end
			local st = u.stock
			local door = st and st.door and W.doors[st.door]
			if door and door.cf then
				add(door.cf.Position, (door.size and door.size.X) or 5)
			end
		end
		return open
	end
	-- [a0, a1] less the cuts
	local function without(a0, a1, cuts)
		local list = {}
		for _, k in cuts do
			list[#list + 1] = k
		end
		table.sort(list, function(p, q)
			return p[1] < q[1]
		end)
		local out, cur = {}, a0
		for _, k in list do
			if k[1] > cur then
				out[#out + 1] = { cur, math.min(k[1], a1) }
			end
			if k[2] > cur then
				cur = k[2]
			end
		end
		if cur < a1 then
			out[#out + 1] = { cur, a1 }
		end
		return out
	end

	-- ── fixtures of our own: part lists in the fixture's frame ──────────────────────────────────────────────
	-- hanging clothes on a slat panel, with a low cabinet of folded stacks under them (5 or 6 parts, 2 deep)
	local function railSpec(c, len)
		local h = len / 2
		local s = -h + len * (0.3 + 0.4 * c.rng:NextNumber())
		local list = {
			{ -h, 0.7, h, 1.0, 0.3, 7.4, P.slat, M.WoodPlanks, false, "Slat" },
			{ -h + 0.1, -0.5, h - 0.1, -0.2, 6.3, 6.55, P.chrome, M.Metal, false, "Rail" },
			{ -h + 0.2, -0.8, s - 0.1, 0.2, 3.0, 6.1, pick(c, CLOTH), M.Fabric, false, "Clothes" },
			{ s + 0.1, -0.8, h - 0.2, 0.2, 3.0, 6.1, pick(c, CLOTH), M.Fabric, false, "Clothes" },
		}
		if c.rng:NextNumber() < 0.7 then
			list[#list + 1] = { -h, -1.0, h, 0.7, 0, 2.5, P.wood, M.WoodPlanks, true, "Cabinet" }
			list[#list + 1] = { -h + 0.3, -0.85, h - 0.3, 0.45, 2.5, 3.0, pick(c, CLOTH), M.Fabric, false, "Folded" }
		end
		return list
	end
	-- three shelves of boxes on a dark panel (4 parts, 1.7 deep)
	local function shoeSpec(c, len)
		local h = len / 2
		local list = { { -h, 0.5, h, 0.85, 0.3, 7.2, P.slatDark, M.WoodPlanks, false, "Panel" } }
		for k = 0, 2 do
			local y = 0.7 + k * 2.3
			list[#list + 1] = { -h + 0.15, -0.85, h - 0.15, 0.5, y, y + 1.6, pick(c, SHOEBOX), M.Cardboard, true, "Boxes" }
		end
		return list
	end
	-- k fitting cubicles in a row against a wall: partitions, a header over the doors, curtains, mirrors, stools (4k + 2 parts)
	local FIT_W, FIT_D = 4.6, 5.2
	-- (the wall behind is the back of a block against a wall; a free-standing block, `lone`, has a back panel of its own: one part more)
	local function fitSpec(c, k, lone)
		local h = k * FIT_W / 2
		local z0, z1 = -FIT_D / 2, FIT_D / 2
		local list = {}
		local back = 0
		if lone then
			back = 0.2
			list[#list + 1] = { -h - 0.15, z1 - 0.2, h + 0.15, z1, 0, 8.0, P.cream, M.Plaster, true, "Back" }
		end
		for i = 0, k do
			local x = -h + i * FIT_W
			list[#list + 1] = { x - 0.15, z0, x + 0.15, z1 - 0.05 - back, 0, 8.0, P.cream, M.Plaster, true, "Partition" }
		end
		list[#list + 1] = { -h, z0, h, z0 + 0.3, 7.4, 8.4, P.slatDark, M.WoodPlanks, false, "Header" }
		for i = 1, k do
			local xc = -h + (i - 0.5) * FIT_W
			list[#list + 1] = { xc - 0.1, z0 + 0.15, xc + FIT_W * 0.42, z0 + 0.4, 0.5, 7.3, pick(c, CLOTH), M.Fabric, false, "Curtain" }
			list[#list + 1] = { xc - 1.2, z1 - 0.1 - back, xc + 1.2, z1 - 0.02 - back, 1.4, 6.6, P.glass, M.SmoothPlastic, false, "Mirror" }
			list[#list + 1] = { xc - 0.9, z1 - 1.5 - back, xc + 0.9, z1 - 0.3 - back, 0, 1.5, P.wood, M.WoodPlanks, true, "Stool" }
		end
		return list
	end
	-- a bin of goods on the floor (2 parts)
	local function binSpec(c)
		local pal = BINGOODS[c.cfg.bin or "cloth"] or CLOTH
		return {
			{ -1.6, -1.2, 1.6, 1.2, 0, 1.4, P.wood, M.WoodPlanks, true, "Bin" },
			{ -1.45, -1.05, 1.45, 1.05, 1.4, 1.85, pick(c, pal), M.Fabric, false, "Goods" },
		}
	end
	-- a plinth with a product or an exhibit on it (2 parts)
	local function plinthSpec(c)
		return {
			{ -1.5, -1.5, 1.5, 1.5, 0, 2.4, P.charcoal, M.SmoothPlastic, true, "Plinth" },
			{ -1.0, -0.9, 1.0, 0.9, 2.4, 3.6, pick(c, c.pal), M.SmoothPlastic, false, "Exhibit" },
		}
	end
	-- a glass counter (3 parts)
	local function counterSpec(c)
		return {
			{ -3.0, -1.2, 3.0, 1.2, 0, 2.7, P.steel, M.Metal, true, "CounterBase" },
			{ -3.0, -1.2, 3.0, 1.2, 2.7, 3.9, P.glass, M.Glass, true, "CounterGlass" },
			{ -2.7, -0.9, 2.7, 0.9, 2.7, 3.2, pick(c, c.pal), M.SmoothPlastic, false, "CounterGoods" },
		}
	end
	-- a standard lamp (2 parts)
	local function lampSpec(c)
		return {
			{ -0.2, -0.2, 0.2, 0.2, 0, 6.2, P.steel, M.Metal, true, "LampPole" },
			{ -0.95, -0.95, 0.95, 0.95, 6.2, 7.6, pick(c, { P.cream, P.sand, P.yellow }), M.Fabric, false, "LampShade" },
		}
	end
	-- two cases stacked (2 parts)
	local function luggageSpec(c)
		return {
			{ -1.5, -0.8, 1.5, 0.8, 0, 3.2, pick(c, SUITCASE), M.Fabric, true, "Case" },
			{ -1.1, -0.65, 1.1, 0.65, 3.2, 5.0, pick(c, SUITCASE), M.Fabric, true, "Case" },
		}
	end
	-- a rug (1 part)
	local function rugSpec(c)
		return { { -3.5, -2.5, 3.5, 2.5, 0, 0.12, pick(c, RUGS), M.Fabric, false, "Rug" } }
	end

	-- ── what goes where ─────────────────────────────────────────────────────────────────────────────────
	-- wall units: own = part list of a unit `len` long, dep its depth; kit = a prop scaled along x to `len` (it is 8 wide, like the
	-- recipes' wall shelves); min / max the lengths it takes; h lifts it
	local WALLS = {
		rail = { own = railSpec, dep = 2.0, min = 8, max = 16 },
		shoe = { own = shoeSpec, dep = 1.7, min = 8, max = 16 },
		shelf = { kit = "WallShelf", min = 7, max = 16 },
		books = { kit = "WallShelfBooks", min = 7, max = 16 },
		meds = { kit = "WallShelfMeds", min = 7, max = 16 },
		tv = { kit = "TVWall", min = 7, max = 16 },
		pegs = { kit = "Pegboard", min = 8, max = 16, h = 2.2 },
		cork = { kit = "CorkBoard", min = 7, max = 14, h = 3.2 },
		fridge = { kit = "Fridge", min = 8, max = 8, fixed = true },
	}
	-- floor fixtures: kit props, or own ones with half sizes hx, hz and their part count; flat ones are not solid
	local FLOORS = {
		rack = { kit = "ClothesRack" }, table = { kit = "DisplayTable" }, mannequin = { kit = "Mannequin" }, techTable = { kit = "TechTable" },
		gondola = { kit = "Gondola" }, weights = { kit = "WeightRack" }, cage = { kit = "RollCage" }, bench = { kit = "Bench" },
		sofa = { kit = "Sofa" }, tableK = { kit = "Table" }, bed = { kit = "Bed" }, arcade = { kit = "Arcade" }, trolley = { kit = "Trolley" },
		case = { kit = "JewelCase" },
		bin = { own = binSpec, hx = 1.6, hz = 1.2, cost = 2 },
		plinth = { own = plinthSpec, hx = 1.5, hz = 1.5, cost = 2 },
		counter = { own = counterSpec, hx = 3.0, hz = 1.2, cost = 3 },
		lamp = { own = lampSpec, hx = 0.95, hz = 0.95, cost = 2 },
		luggage = { own = luggageSpec, hx = 1.5, hz = 0.8, cost = 2 },
		rug = { own = rugSpec, hx = 3.5, hz = 2.5, cost = 1, flat = true },
	}
	-- litter on the floor: own flat things in colours (one part, or two with `two`), and kit props that lie about
	local SCRAP = {
		heap = { pal = CLOTH, sx = { 2.2, 3.6 }, sz = { 1.8, 3.0 }, sy = { 0.25, 0.5 }, mat = M.Fabric },
		heap2 = { pal = CLOTH, sx = { 2.2, 3.4 }, sz = { 1.8, 2.8 }, sy = { 0.25, 0.4 }, mat = M.Fabric, two = true },
		carton = { pal = CARD, sx = { 1.6, 2.6 }, sz = { 1.4, 2.2 }, sy = { 1.0, 1.6 }, mat = M.Cardboard },
		shoebox = { pal = SHOEBOX, sx = { 1.2, 1.8 }, sz = { 0.9, 1.3 }, sy = { 0.4, 0.8 }, mat = M.Cardboard },
		books = { pal = BOOKS, sx = { 1.1, 1.7 }, sz = { 0.9, 1.4 }, sy = { 0.2, 0.5 }, mat = M.Fabric, two = true },
		toys = { pal = TOYS, sx = { 0.9, 1.6 }, sz = { 0.9, 1.6 }, sy = { 0.3, 0.8 }, mat = M.SmoothPlastic, two = true },
		goods = { pal = FOOD, sx = { 1.0, 1.8 }, sz = { 0.9, 1.5 }, sy = { 0.3, 0.9 }, mat = M.SmoothPlastic, two = true },
		papers = { pal = PAPER, sx = { 1.4, 2.4 }, sz = { 1.0, 1.8 }, sy = { 0.06, 0.12 }, mat = M.SmoothPlastic },
	}
	local KITSCRAP = {
		pile = { name = "CardboardPile" }, shards = { name = "GlassShards" }, mannDown = { name = "MannequinFallen", ground = true },
		rackDown = { name = "ClothesRackFallen", ground = true },
	}
	-- per kind of shop: fit = cubicles (clothes), wall / floor / clutter = the styles in turn, bin = what its bins hold, poster = palette
	local KINDS = {
		clothing = {
			fit = 3, wall = { "rail", "shelf", "rail", "pegs", "rail" }, floor = { "rack", "table", "mannequin", "bin", "rack", "mannequin", "table" },
			bin = "cloth", clutter = { "heap", "carton", "heap2", "mannDown", "heap", "rackDown", "pile", "heap" }, poster = "fashion",
		},
		electronics = {
			wall = { "tv", "shelf", "pegs", "tv", "shelf" }, floor = { "techTable", "plinth", "counter", "plinth", "techTable" }, bin = "tech",
			clutter = { "carton", "pile", "shards", "papers", "carton", "shards" }, poster = "tech",
		},
		sports = {
			wall = { "shoe", "shelf", "rail", "pegs", "shoe" }, floor = { "weights", "cage", "bench", "mannequin", "table", "rack" }, bin = "sport",
			clutter = { "heap", "shoebox", "carton", "heap2", "pile", "shoebox" }, poster = "sport",
		},
		books = {
			wall = { "books", "books", "shelf" }, floor = { "gondola", "table", "bench", "gondola", "bin" }, bin = "books",
			clutter = { "books", "papers", "books", "carton", "pile", "books" }, poster = "book",
		},
		toys = {
			wall = { "shelf", "pegs", "shelf" }, floor = { "table", "bin", "arcade", "bin", "gondola", "bin" }, bin = "toy",
			clutter = { "toys", "toys", "carton", "pile", "toys", "toys" }, poster = "toy",
		},
		shoes = {
			wall = { "shoe", "shoe", "shelf" }, floor = { "bench", "table", "bench", "bin", "bench" }, bin = "shoe",
			clutter = { "shoebox", "shoebox", "pile", "heap", "shoebox" }, poster = "fashion",
		},
		homeware = {
			wall = { "shelf", "pegs", "shelf" }, floor = { "sofa", "tableK", "rug", "bed", "lamp", "rug", "lamp" },
			clutter = { "pile", "carton", "heap", "papers", "pile" }, poster = "home",
		},
		lighting = {
			wall = { "shelf", "pegs", "shelf" }, floor = { "table", "lamp", "lamp", "plinth", "lamp", "lamp" },
			clutter = { "carton", "pile", "shards", "carton" }, poster = "tech",
		},
		travel = {
			wall = { "cork", "pegs" }, floor = { "luggage", "bench", "luggage", "tableK" },
			clutter = { "papers", "carton", "papers", "pile" }, poster = "travel",
		},
		general = {
			wall = { "shelf", "fridge", "shelf" }, floor = { "gondola", "bin", "trolley", "bin", "gondola" }, bin = "food",
			clutter = { "goods", "goods", "pile", "carton", "goods", "shards" }, poster = "sale",
		},
		food = {
			wall = { "shelf", "fridge" }, floor = { "bin", "bin", "gondola", "bin" }, bin = "produce",
			clutter = { "goods", "pile", "carton", "goods" }, poster = "food",
		},
		pharmacy = {
			wall = { "meds", "meds", "shelf" }, floor = { "counter", "gondola", "counter" }, bin = "pharm",
			clutter = { "papers", "goods", "carton", "papers" }, poster = "pharm",
		},
		museum = {
			wall = {}, floor = { "plinth", "bench", "plinth", "case", "plinth" },
			clutter = { "carton", "papers", "pile", "shards" }, poster = "museum",
		},
	}
	KINDS.furniture = KINDS.homeware
	-- ── the fitting room ────────────────────────────────────────────────────────────────────────────────
	-- against a free stretch of wall first, else free-standing on the floor with its curtains toward the room
	local RYSIDE = { [0] = "B", [180] = "F", [90] = "R", [-90] = "L" }
	local function phaseFit(c)
		local want = c.cfg.fit
		if not want then
			return
		end
		for k = want, 1, -1 do
			local cost = 4 * k + 2
			if afford(c, cost + 1) then
				local len = k * FIT_W
				for _, side in c.fitSides do
					local lo, hi = -c.hw + len / 2 + 2.5, c.hw - len / 2 - 2.5
					if side ~= "B" then
						-- a long shop keeps its first 14 studs open; a shallow one lets the room stand nearer its front
						lo, hi = math.min(14, c.D * 0.3) + len / 2, c.D - len / 2 - 2.5
					end
					if hi > lo then
						for _ = 1, 14 do
							local along = lo + c.rng:NextNumber() * (hi - lo)
							local x0, d0, x1, d1 = wallRect(c, side, along, len, FIT_D, 0.11)
							local ax0, ad0, ax1, ad1 = laneOf(side, x0, d0, x1, d1, 3.2)
							if free(c, x0, d0, x1, d1, 0) and free(c, ax0, ad0, ax1, ad1, 0) then
								emit(c, fitSpec(c, k, false), (x0 + x1) / 2, (d0 + d1) / 2, WALLRY[side])
								take(c, math.min(x0, ax0), math.min(d0, ad0), math.max(x1, ax1), math.max(d1, ad1))
								return
							end
						end
					end
				end
				-- free-standing: with a back panel, anywhere the floor allows; probed over a grid from a random start so the
				-- first free spot wins (a shallow, busy shop has only a few)
				local order = { 1, 2, 3, 4 }
				for i = 4, 2, -1 do
					local j = c.rng:NextInteger(1, i)
					order[i], order[j] = order[j], order[i]
				end
				for _, ri in order do
					local ry = RYS[ri]
					local hx, hz = len / 2, FIT_D / 2
					if ry == 90 or ry == -90 then
						hx, hz = hz, hx
					end
					local xa, xb = -c.hw + hx + 1.5, c.hw - hx - 1.5
					local da, db = 3 + hz, c.D - hz - 1.5
					if xb >= xa and db >= da then
						local nx, nd = math.floor((xb - xa) / 2) + 1, math.floor((db - da) / 2) + 1
						local start = c.rng:NextInteger(0, nx * nd - 1)
						for j = 0, nx * nd - 1 do
							local idx = (start + j) % (nx * nd)
							local x = xa + math.floor(idx / nd) * 2
							local d = da + (idx % nd) * 2
							local ax0, ad0, ax1, ad1 = laneOf(RYSIDE[ry], x - hx, d - hz, x + hx, d + hz, 3.2)
							if free(c, x - hx, d - hz, x + hx, d + hz, 1.2) and free(c, ax0, ad0, ax1, ad1, 0) then
								emit(c, fitSpec(c, k, true), x, d, ry)
								take(c, math.min(x - hx, ax0), math.min(d - hz, ad0), math.max(x + hx, ax1), math.max(d + hz, ad1))
								return
							end
						end
					end
				end
			end
		end
	end

	-- ── wall units ──────────────────────────────────────────────────────────────────────────────────────
	-- the free stretches [s0, s1] of a wall for something `dep` deep, from the rectangles taken
	local function stretches(c, side, dep, a0, a1)
		local x0, d0, x1, d1 = wallRect(c, side, (a0 + a1) / 2, a1 - a0, dep, 0.15)
		local blocked = {}
		for _, r in c.occ do
			if r[1] < x1 - 0.01 and r[3] > x0 + 0.01 and r[2] < d1 - 0.01 and r[4] > d0 + 0.01 then
				if side == "B" or side == "F" then
					blocked[#blocked + 1] = { r[1], r[3] }
				else
					blocked[#blocked + 1] = { r[2], r[4] }
				end
			end
		end
		return without(a0, a1, blocked)
	end
	local function unitLen(rem, mn, mx)
		if rem < mn - 0.01 then
			return nil
		end
		local k = math.max(1, math.ceil(rem / mx - 0.001))
		return rem / k
	end
	-- one unit of style st on the longest free stretch of a wall: true when built, "dear" when the budget cannot take it, false when
	-- that bit of wall was no good (it is closed, so the next try moves on), nil when no stretch is long enough
	local function wallUnit(c, side, st)
		local a0, a1 = -c.hw + 0.3, c.hw - 0.3
		if side ~= "B" then
			a0, a1 = 5.5, c.D - 0.3
		end
		local best = nil
		for _, s in stretches(c, side, 2.4, a0, a1) do
			if s[2] - s[1] >= st.min - 0.01 and (not best or s[2] - s[1] > best[2] - best[1]) then
				best = s
			end
		end
		if not best then
			return nil
		end
		local len = st.max
		if not st.fixed then
			len = unitLen(best[2] - best[1], st.min, st.max)
		end
		if not len then
			return nil
		end
		local ry = WALLRY[side]
		local spec, sc, dep, cost = nil, nil, st.dep, 0
		local gap = 0.11
		if st.kit then
			local size = Kit.size(st.kit)
			local fp = nil
			if size then
				sc = V(len / size.X, 1, 1)
				fp = footprint(st.kit, ry, sc)
			end
			if not fp then
				return nil
			end
			dep = fp.hz * 2
			if side == "L" or side == "R" then
				dep = fp.hx * 2
			end
			cost = kitCost(st.kit, st.kit == "Pegboard" or st.kit == "CorkBoard")
			gap = 0.15
		else
			spec = st.own(c, len)
			cost = #spec
		end
		if not afford(c, cost) then
			return "dear"
		end
		local x0, d0, x1, d1 = wallRect(c, side, best[1] + len / 2, len, dep, gap)
		local lx0, ld0, lx1, ld1 = laneOf(side, x0, d0, x1, d1, 2.8)
		if free(c, x0, d0, x1, d1, 0) and free(c, lx0, ld0, lx1, ld1, 0) then
			if st.kit then
				placeKit(c, st.kit, (x0 + x1) / 2, (d0 + d1) / 2, ry, { sc = sc, h = st.h })
			else
				emit(c, spec, (x0 + x1) / 2, (d0 + d1) / 2, ry)
			end
			take(c, x0, d0, x1, d1)
			return true
		end
		local bx0, bd0, bx1, bd1 = wallRect(c, side, best[1] + 1.5, 3, 2.6, 0.1)
		c.occ[#c.occ + 1] = { bx0, bd0, bx1, bd1 }
		return false
	end
	local function phaseWalls(c)
		local list = c.cfg.wall
		if not list or #list == 0 then
			return
		end
		local tries, moved = 0, true
		while moved and tries < 45 do
			moved = false
			for _, side in c.sides do
				tries += 1
				for k = 0, #list - 1 do
					local st = WALLS[list[(c.wallK + k) % #list + 1]]
					if st then
						local r = wallUnit(c, side, st)
						if r == true then
							c.wallK += k + 1
							moved = true
							break
						elseif r == false then
							moved = true
							break
						elseif r == nil then
							break
						end
					end
				end
			end
		end
	end

	-- ── posters and price boards ───────────────────────────────────────────────────────────────────────────
	local function phasePosters(c)
		local pal = POSTERS[c.cfg.poster or "sale"] or POSTERS.sale
		local top = c.bandY - 0.4
		local spans, total = {}, 0
		for _, side in c.sides do
			if not c.a.noPoster or not c.a.noPoster[side] then
				local a0, a1 = -c.hw + 2, c.hw - 2
				if side ~= "B" then
					a0, a1 = 4, c.D - 2
				end
				for _, s in without(a0, a1, c.open[side]) do
					if s[2] - s[1] >= 5 then
						spans[#spans + 1] = { side = side, s0 = s[1], s1 = s[2] }
						total += s[2] - s[1]
					end
				end
			end
		end
		if total < 5 then
			return
		end
		local want = math.clamp(math.floor(total / 26), 2, 7)
		local used = { B = {}, L = {}, R = {} }
		local placed, tries = 0, 0
		while placed < want and tries < want * 6 do
			tries += 1
			-- a span picked by its length
			local at = c.rng:NextNumber() * total
			local sp = spans[1]
			for _, s in spans do
				sp = s
				at -= s.s1 - s.s0
				if at <= 0 then
					break
				end
			end
			local w = pick(c, { 2.8, 3.4, 4.2, 5.0 })
			if sp.s1 - sp.s0 >= w + 1 and afford(c, 2) then
				local along = sp.s0 + w / 2 + 0.5 + c.rng:NextNumber() * (sp.s1 - sp.s0 - w - 1)
				local clash = false
				for _, u in used[sp.side] do
					if along - w / 2 < u[2] + 1 and along + w / 2 > u[1] - 1 then
						clash = true
					end
				end
				if not clash then
					-- above the shelves where the wall is taken, at eye level where it is bare
					local x0, d0, x1, d1 = wallRect(c, sp.side, along, w + 1, 2.6, 0.1)
					local y0 = 4.6 + c.rng:NextNumber() * 1.4
					for _, r in c.occ do
						if r[1] < x1 and r[3] > x0 and r[2] < d1 and r[4] > d0 then
							y0 = 8.9
							break
						end
					end
					local h = w * (1.15 + c.rng:NextNumber() * 0.3)
					if y0 + h + 0.3 > top then
						h = top - y0 - 0.3
					end
					if h >= 2.2 then
						used[sp.side][#used[sp.side] + 1] = { along - w / 2, along + w / 2 }
						wallBox(c, sp.side, along - w / 2 - 0.2, along + w / 2 + 0.2, 0.02, 0.14, y0 - 0.2, y0 + h + 0.2, P.charcoal, M.SmoothPlastic, "PosterFrame")
						wallBox(c, sp.side, along - w / 2, along + w / 2, 0.14, 0.2, y0, y0 + h, pick(c, pal), M.SmoothPlastic, "Poster")
						placed += 1
					end
				end
			end
		end
	end

	-- ── a coloured band along the upper wall: the shop's own colour, one part to a stretch of wall ──────────────
	local function phaseBand(c)
		local spans, best = {}, 0
		for _, side in c.sides do
			if not c.a.noPoster or not c.a.noPoster[side] then
				local a0, a1 = -c.hw + 0.3, c.hw - 0.3
				if side ~= "B" then
					a0, a1 = 4, c.D - 0.3
				end
				for _, s in without(a0, a1, c.open[side]) do
					if s[2] - s[1] >= 12 then
						spans[#spans + 1] = { side = side, s0 = s[1] + 0.2, s1 = s[2] - 0.2 }
						best = math.max(best, s[2] - s[1])
					end
				end
			end
		end
		local col = c.pal[hashId(c.id) % #c.pal + 1]
		for _, sp in spans do
			if afford(c, 1) then
				wallBox(c, sp.side, sp.s0, sp.s1, 0.02, 0.16, c.bandY, c.bandY + 1.5, col, M.SmoothPlastic, "Band")
				if sp.s1 - sp.s0 >= best - 0.5 and afford(c, 1) then
					wallBox(c, sp.side, sp.s0, sp.s1, 0.02, 0.14, c.bandY - 0.7, c.bandY - 0.35, P.cream, M.SmoothPlastic, "Band")
				end
			end
		end
	end

	-- ── fixtures on the free floor ──────────────────────────────────────────────────────────────────────────
	local function floorOne(c, name)
		local def = FLOORS[name]
		if not def then
			return 0
		end
		local cost = def.cost or kitCost(def.kit)
		if not afford(c, cost) then
			return 0
		end
		-- aisles of 3.6 studs round it first; a crowded shop gets a second round with 2.8 (still room for two to pass)
		for pass = 1, 2 do
			local pad = 3.6
			if pass == 2 then
				pad = 2.8
			end
			if def.flat then
				pad = 0.8
			end
			for _ = 1, 28 do
				local ry = RYS[c.rng:NextInteger(1, 4)]
				local hx, hz, fp = def.hx, def.hz, nil
				if def.kit then
					fp = footprint(def.kit, ry)
					if not fp then
						return 0
					end
					hx, hz = fp.hx, fp.hz
				elseif ry == 90 or ry == -90 then
					hx, hz = hz, hx
				end
				local xlo, xhi = -c.hw + hx + 3.5, c.hw - hx - 3.5
				-- the entrances keep their own floor free; a shallow shop lets fixtures stand nearer its front and back
				local dlo, dhi = math.min(8, c.D * 0.25) + hz, c.D - hz - math.min(4.5, c.D * 0.18)
				if xhi <= xlo or dhi <= dlo then
					return 0
				end
				local x = xlo + c.rng:NextNumber() * (xhi - xlo)
				local d = dlo + c.rng:NextNumber() * (dhi - dlo)
				if free(c, x - hx, d - hz, x + hx, d + hz, pad) then
					if def.kit then
						if not placeKit(c, def.kit, x, d, ry) then
							return 0
						end
					else
						emit(c, def.own(c), x, d, ry)
					end
					if def.flat then
						c.occ[#c.occ + 1] = { x - hx, d - hz, x + hx, d + hz }
					else
						take(c, x - hx, d - hz, x + hx, d + hz)
					end
					return cost
				end
			end
			if def.flat then
				return 0
			end
		end
		return 0
	end
	local function phaseFloor(c)
		local list = c.cfg.floor
		if not list or #list == 0 then
			return
		end
		local k, fails = 0, 0
		while fails < #list + 2 and k < 40 do
			local made = floorOne(c, list[k % #list + 1])
			k += 1
			if made > 0 then
				fails = 0
			else
				fails += 1
			end
		end
	end

	-- ── litter ──────────────────────────────────────────────────────────────────────────────────────────
	local function rangeOf(c, r)
		return r[1] + c.rng:NextNumber() * (r[2] - r[1])
	end
	local function clutterOne(c, name)
		local sd, kd = SCRAP[name], KITSCRAP[name]
		if not sd and not kd then
			return 0
		end
		local cost, lift, size = 1, 0, nil
		if sd and sd.two then
			cost = 2
		end
		if kd then
			local center = nil
			size, center = Kit.size(kd.name)
			if not size or not center then
				return 0
			end
			cost = kitCost(kd.name, true)
			if kd.ground then
				lift = size.Y / 2 - center.Y
			end
		end
		if not afford(c, cost) then
			return 0
		end
		for _ = 1, 24 do
			local ry = c.rng:NextNumber() * 180
			local sx, sy, sz, hx, hz, fp = 0, 0, 0, 0, 0, nil
			if kd then
				ry = RYS[c.rng:NextInteger(1, 4)]
				fp = footprint(kd.name, ry)
				if not fp then
					return 0
				end
				hx, hz = fp.hx, fp.hz
			else
				sx, sy, sz = rangeOf(c, sd.sx), rangeOf(c, sd.sy), rangeOf(c, sd.sz)
				hx = math.max(sx, sz) * 0.7
				hz = hx
			end
			local x, d = 0, 0
			local r = nil
			if #c.anchors > 0 then
				r = c.anchors[c.rng:NextInteger(1, #c.anchors)]
			end
			if r then
				local t = c.rng:NextNumber()
				local side = c.rng:NextInteger(1, 4)
				if side == 1 then
					x, d = r[1] - hx - 0.9, r[2] + t * (r[4] - r[2])
				elseif side == 2 then
					x, d = r[3] + hx + 0.9, r[2] + t * (r[4] - r[2])
				elseif side == 3 then
					x, d = r[1] + t * (r[3] - r[1]), r[2] - hz - 0.9
				else
					x, d = r[1] + t * (r[3] - r[1]), r[4] + hz + 0.9
				end
			else
				x = -c.hw + 4 + c.rng:NextNumber() * (c.W - 8)
				d = 8 + c.rng:NextNumber() * math.max(1, c.D - 14)
			end
			if free(c, x - hx, d - hz, x + hx, d + hz, 0.25) then
				c.occ[#c.occ + 1] = { x - hx, d - hz, x + hx, d + hz }
				if kd then
					if not placeKit(c, kd.name, x, d, ry, { h = lift }) then
						return 0
					end
				else
					local col = pick(c, sd.pal)
					local solid = sy >= 1.0
					mk(c, sx, sy, sz, worldCF(c, x, sy / 2, d, ry), col, sd.mat, solid, "Litter")
					if sd.two then
						mk(c, sx * 0.6, sy * 0.7, sz * 0.6, worldCF(c, x, sy + sy * 0.35, d, ry + 30), pick(c, sd.pal), sd.mat, false, "Litter")
					end
					if solid then
						c.a.take(x - hx, d - hz, x + hx, d + hz)
					end
				end
				return cost
			end
		end
		return 0
	end
	local function phaseClutter(c)
		local list = c.cfg.clutter
		if not list or #list == 0 then
			return
		end
		local k, fails = 0, 0
		while fails < #list + 3 and k < 40 do
			local made = clutterOne(c, list[k % #list + 1])
			k += 1
			if made > 0 then
				fails = 0
			else
				fails += 1
			end
		end
	end

	-- ── one shop ────────────────────────────────────────────────────────────────────────────────────────
	-- how many parts a shop gets: by floor area, a little less on the upper floor where the recipes already fill more
	local function targetOf(c)
		local area = c.W * c.D
		local t = math.clamp(14 + area / 60, 24, 80)
		if c.level == 2 then
			t = math.clamp(12 + area / 100, 16, 38)
		end
		if c.cfg.fit then
			t = math.max(t, 28)
		end
		return math.floor(t * (c.cfg.scale or 1) + 0.5)
	end
	-- the phases in order, each with the share of the target it may spend (the shop's target caps them all)
	local PHASES = {
		{ "fit", phaseFit, 0.30 }, { "wall", phaseWalls, 0.50 }, { "poster", phasePosters, 0.14 }, { "band", phaseBand, 0.08 },
		{ "floor", phaseFloor, 0.50 }, { "clutter", phaseClutter, 0.24 },
	}

	local function shopInner(a)
		local cfg = KINDS[a.kind]
		if not cfg or not a.cf or not a.W or not a.D or not a.rects or not a.take then
			return 0
		end
		local c = {
			a = a, id = a.id, level = a.level or 1, cf = a.cf, W = a.W, D = a.D, hw = a.W / 2, ceil = a.ceil or 16, cfg = cfg,
			rng = Random.new(hashId(a.id) + 77), occ = {}, anchors = {}, spent = 0, cap = 0, phase = "fit", wallK = 0,
			by = { fit = 0, wall = 0, poster = 0, band = 0, floor = 0, clutter = 0 },
			pal = POSTERS[cfg.poster or "sale"] or POSTERS.sale,
		}
		c.bandY = math.clamp((a.ceil or 16) - 3.2, 9.5, 15.2)
		c.model = kit.model(a.id, root)
		-- what the recipe took; the props among it are what litter lies beside
		for _, r in a.rects() do
			c.occ[#c.occ + 1] = { r[1], r[2], r[3], r[4] }
			local w, h = r[3] - r[1], r[4] - r[2]
			if w > 1 and h > 1 and w < 24 and h < 24 then
				c.anchors[#c.anchors + 1] = { r[1], r[2], r[3], r[4] }
			end
		end
		addAvoid(c)
		c.open = openingSpans(c, a.u)
		-- the walls the pass works on: the back first, then the sides in a shop-specific order
		c.sides = { "B", "L", "R" }
		c.fitSides = { "B", "L", "R" }
		if c.rng:NextNumber() < 0.5 then
			c.sides = { "B", "R", "L" }
		end
		if c.rng:NextNumber() < 0.5 then
			c.fitSides = { "B", "R", "L" }
		end
		c.T = targetOf(c)
		for _, st in PHASES do
			c.phase = st[1]
			c.cap = math.min(c.T, c.spent + math.max(c.T * st[3], st[1] == "fit" and 16 or 0))
			st[2](c)
		end
		local lv = tot["lv" .. c.level]
		if lv then
			lv.shops += 1
		end
		tot.shops += 1
		tot.list[#tot.list + 1] = { id = c.id, level = c.level, parts = c.spent, target = c.T, by = c.by }
		return c.spent
	end

	-- the call the stores make; a failing pass is logged and costs nothing but its own parts
	function Fill.shop(a)
		local ok, res = pcall(shopInner, a)
		if not ok then
			tot.refused += 1
			warn("[ZR] Meridian small shops: " .. tostring(a and a.id) .. " failed: " .. tostring(res))
			return 0
		end
		return res
	end

	-- one line for the log: what was added on a level (or in all with no level)
	function Fill.report(level)
		local lv = tot["lv" .. tostring(level)]
		if lv then
			return string.format("%d shops, +%d parts of the %d allowed on this floor", lv.shops, lv.parts, LIMIT["lv" .. level])
		end
		return string.format(
			"%d shops, +%d parts of the 2,000 allowed (%d own, %d kit pieces, %d colliders; %d kit props); fitting rooms %d, wall units %d, posters %d, bands %d, floor fixtures %d, litter %d; %d shops failed",
			tot.shops, tot.parts, tot.own, tot.pieces, tot.colliders, tot.props, tot.cats.fit, tot.cats.wall, tot.cats.poster, tot.cats.band,
			tot.cats.floor, tot.cats.clutter, tot.refused
		)
	end

	return Fill
end

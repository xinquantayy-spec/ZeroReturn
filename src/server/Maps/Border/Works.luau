--!nonstrict
-- Border Yard works (buildings, part 2 of 3b): the industrial side of the Customs layout, rebuilt as our own
-- Soviet-era works on the footprints in Layout.luau (docs/maps/BORDER_CUSTOMS_BUILD.md, docs/maps/BORDER_YARD.md):
--   STORE 3, 4, 7 and 17, the DEPOT, the RED STORES, THE BASTION, THE DERRICK, THE FRAME, the MOTOR SHOP and
--   BOILER HOUSE, the PUMP HOUSE, OLD WORKS and four STORAGE BLOCKS, the tank farm (tanks and pump platforms) and the
--   bunkers: K-11, SMUGGLERS' HOLE, K-13, the STORE 4 basement, the BOILER CELLAR and the OLD PUMPS cellar.
-- Every building is laid out in its own frame: u along the footprint's long side (w), v along its depth (d), y up from
-- the pad (Layout's rot turns the frame; the pads are flat). The helpers below take building-local numbers; props,
-- doors, containers and loot go through the same World API as the other maps. Dorms, stations, houses, cabins, kiosks,
-- garages and sheds are Living.luau's. B.points gets the named positions the gameplay part uses (world positions at
-- standing height). One building failing is logged and the rest still build.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Wear = require(ReplicatedStorage:WaitForChild("ZR"):WaitForChild("Wear"))

return function(B)
	local kit, W, map, H, Kit, L, O = B.kit, B.W, B.map, B.H, B.Kit, B.L, B.O
	local C, M, hex = kit.C, kit.M, kit.hex
	local count = B.count or {}
	B.count = count
	local points = B.points or {}
	B.points = points
	local works = kit.model("Works", map)
	works:SetAttribute("NoWire", true) -- roofs, gantries and parapets are fighting positions: no barbed wire on them

	-- ── palette ──────────────────────────────────────────────────────────────────────────────────────────
	local PAN, PAN2 = hex("858880"), hex("6C6F68") -- precast concrete panels, new and stained
	local BRK, BRK2 = hex("8A5946"), hex("6B4537") -- brick
	local SHT, SHT2 = hex("66766F"), hex("7B6A58") -- sheet cladding, grey-green and rusted
	local PLS, PLS2 = hex("A8A697"), hex("8A8879") -- plaster inside
	local STL, STL2 = hex("454D4C"), hex("5E4236") -- steel, painted and rusted
	local FLR, FLR2 = hex("5A5C57"), hex("494B47") -- floors
	local ROOF = hex("3F4240")
	local YEL, REDP = C.yellow, hex("8E3B30")
	local WARM, COLD = hex("FFD3A0"), hex("DCE8E4")

	-- ── state of the building being built ────────────────────────────────────────────────────────────────
	local F -- CFrame of the pad centre, turned by the layout's rot; local axes u (x), y, v (z)
	local GY = 0 -- pad height (local y of the map)
	local FY = 0.25 -- top of the ground floor above the pad
	local bm, pm -- model of the building, model for its props
	local pre = "BW" -- prefix of container and door ids
	local nProps, nCont, nLoose, nDoors, nLamps, nSkip = 0, 0, 0, 0, 0, 0
	local bProps, bCap = 0, 1e9 -- props placed in the building being built, and its cap (containers ignore it)
	local contN, doorN, roomN = 0, 0, 0
	local failed = {}
	-- one structure at a time, so a failure leaves the rest standing
	local function run(name, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			table.insert(failed, name)
			warn("[ZR] Border works: " .. name .. " failed: " .. tostring(err))
		end
	end
	local byId = {}
	for _, b in L.blds do
		byId[b[1]] = b
	end

	-- map-local circles (x, z, r) kept free of props: PMC and scav spawn points, extract zones
	local avoid = {}
	for _, side in { "east", "west" } do
		for _, s in L.spawns[side] do
			table.insert(avoid, { s[1], s[2], 4.5 })
		end
	end
	for _, e in L.ext do
		table.insert(avoid, { e[4], e[5], math.max(e[6], e[8]) / 2 })
	end
	for _, z in L.scav do
		for _, k in { 7, 8, 9 } do
			local lst = z[k]
			for i = 1, #lst, 4 do
				table.insert(avoid, { lst[i], lst[i + 1], 3.5 })
			end
		end
	end
	local function reserved(u, v, r)
		local p = F * Vector3.new(u, 0, v)
		local x, z = p.X - O.X, p.Z - O.Z
		for _, a in avoid do
			local dx, dz = x - a[1], z - a[2]
			local rr = a[3] + r
			if dx * dx + dz * dz < rr * rr then
				return true
			end
		end
		return false
	end

	local curRot = 0
	-- the frame of a footprint (centre cx, cz, rot as in Layout) at pad height gy
	local function siteAt(cx, cz, rot, gy, name, prefix, floorY, cap)
		GY = gy
		bProps, bCap = 0, cap or 1e9
		curRot = rot
		F = CFrame.new(O.X + cx, gy, O.Z + cz) * CFrame.Angles(0, -math.rad(rot), 0)
		FY = floorY or 0.25
		bm = kit.model(name, works)
		pm = kit.model("Props", bm)
		pre = prefix
		contN, doorN, roomN = 0, 0, 0
		return bm
	end
	-- a building row of Layout.blds
	local function site(b, name, prefix, floorY, cap)
		local gy = B.ground(b[4], b[5])
		if math.abs(gy) < 0.5 then
			gy = 0
		end
		return siteAt(b[4], b[5], b[8], gy, name, prefix, floorY, cap)
	end
	-- the wall finish of the building being built: the attribute Finish on its Model, read by World.applyWear (docs/look/WALLS.md).
	-- "ZR_BrickWall" turns the concrete and plaster walls of a hall into brick; "" keeps the old look
	local function wallFinish(name)
		bm:SetAttribute("Finish", name)
	end
	-- a point of the current building as a world position
	local function wp(u, y, v)
		return F * Vector3.new(u, y, v)
	end
	local function cfAt(u, y, v, yaw)
		local c = F * CFrame.new(u, y, v)
		if yaw then
			c = c * CFrame.Angles(0, math.rad(yaw), 0)
		end
		return c
	end

	-- ── primitives ───────────────────────────────────────────────────────────────────────────────────────
	-- an axis-aligned box of the building frame by its extents
	local function ab(p, u0, u1, y0, y1, v0, v1, col, mat)
		if u1 < u0 then
			u0, u1 = u1, u0
		end
		if y1 < y0 then
			y0, y1 = y1, y0
		end
		if v1 < v0 then
			v0, v1 = v1, v0
		end
		local sx, sy, sz = u1 - u0, y1 - y0, v1 - v0
		if sx < 0.04 or sy < 0.04 or sz < 0.04 then
			return nil
		end
		return kit.boxCF(p, sx, sy, sz, F * CFrame.new((u0 + u1) / 2, (y0 + y1) / 2, (v0 + v1) / 2), col, mat)
	end
	-- a box by its centre and size, turned by yaw degrees about y
	local function bc(p, sx, sy, sz, u, y, v, col, mat, yaw)
		return kit.boxCF(p, sx, sy, sz, cfAt(u, y, v, yaw), col, mat)
	end
	-- a beam between two points (u, y, v) of the frame, width w across, height h
	local function beam(p, a, b, w, h, col, mat)
		local wa, wb = F * a, F * b
		local len = (wb - wa).Magnitude
		if len < 0.05 then
			return nil
		end
		local mid = (wa + wb) / 2
		if math.abs(wb.X - wa.X) < 1e-4 and math.abs(wb.Z - wa.Z) < 1e-4 then
			return kit.boxCF(p, w, len, h, CFrame.new(mid), col, mat)
		end
		return kit.boxCF(p, w, h, len, CFrame.lookAt(mid, wb), col, mat)
	end
	-- a wall from (u0, v0) to (u1, v1), foot at y0, height h, thickness t; holes { s, width, bottom, top } with s the
	-- distance of the opening's centre from the start of the wall
	local droppedOpenings = {}
	local function wl(p, u0, v0, u1, v1, y0, h, t, col, mat, holes)
		local dx, dz = u1 - u0, v1 - v0
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 0.3 then
			return
		end
		local c = F * CFrame.new((u0 + u1) / 2, y0, (v0 + v1) / 2) * CFrame.Angles(0, -math.atan2(dz, dx), 0)
		local list = {}
		for _, o in holes or {} do
			table.insert(list, o)
		end
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		local hs = {}
		for _, o in list do
			local half = o[2] / 2
			-- openings sharing a stretch of wall (stacked slit windows, a door by a gate) are all cut: World.wallHoles
			if o[2] < len - 0.3 then
				local s = math.clamp(o[1] - len / 2, -len / 2 + half + 0.05, len / 2 - half - 0.05)
				table.insert(hs, { s, o[2], math.max(o[3], 0), math.min(o[4], h) })
			else
				-- an opening too wide for its wall: the wall is built solid there
				table.insert(droppedOpenings, string.format("%s (%.1f wide at %.1f of %.1f)", bm and bm.Name or "?", o[2], o[1], len))
			end
		end
		kit.wallHoles(p, c, len, h, t, col, mat, hs)
	end
	-- the four walls of a rectangle given by its OUTER extents (the wall faces are flush with them); Hs holds the
	-- openings per side: n (the v0 side), s (v1), w (u0), e (u1); n and s are measured from u0, w and e from v0;
	-- skip = { n = true, ... } leaves a side out (shared walls)
	local function rectWalls(p, u0, u1, v0, v1, y0, h, t, col, mat, Hs)
		Hs = Hs or {}
		local skip = Hs.skip or {}
		local a0, a1, b0, b1 = u0 + t / 2, u1 - t / 2, v0 + t / 2, v1 - t / 2
		local function shift(list, d)
			local o = {}
			for _, e in list or {} do
				table.insert(o, { e[1] + d, e[2], e[3], e[4] })
			end
			return o
		end
		if not skip.n then
			wl(p, u0, b0, u1, b0, y0, h, t, col, mat, shift(Hs.n, 0))
		end
		if not skip.s then
			wl(p, u0, b1, u1, b1, y0, h, t, col, mat, shift(Hs.s, 0))
		end
		local vs0 = skip.n and v0 or v0 + t
		local vs1 = skip.s and v1 or v1 - t
		if not skip.w then
			wl(p, a0, vs0, a0, vs1, y0, h, t, col, mat, shift(Hs.w, v0 - vs0))
		end
		if not skip.e then
			wl(p, a1, vs0, a1, vs1, y0, h, t, col, mat, shift(Hs.e, v0 - vs0))
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
	-- a slab (top at yTop, th thick) over u0..u1, v0..v1 with rectangular holes { u0, u1, v0, v1 }
	local function slab(p, u0, u1, v0, v1, yTop, th, col, mat, holes)
		local xs, zs, hs = { u0, u1 }, { v0, v1 }, {}
		for _, h in holes or {} do
			if h[2] > u0 and h[1] < u1 and h[4] > v0 and h[3] < v1 then
				table.insert(hs, h)
				table.insert(xs, math.max(h[1], u0))
				table.insert(xs, math.min(h[2], u1))
				table.insert(zs, math.max(h[3], v0))
				table.insert(zs, math.min(h[4], v1))
			end
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
					ab(p, a, b, yTop - th, yTop, run0, zs[j], col, mat)
					run0 = nil
				end
			end
		end
	end
	local railAt -- the guard rail between two points (defined below); stairs() uses it for their sides
	-- a straight flight climbing from (u, v) at y0 by `rise` studs along dir ("+u", "-u", "+v", "-v"), each stud of
	-- rise taking `run` studs of length, w wide; steps are stepH (default 0.5) high. solid = y of the fill below the treads
	-- (nil: open treads on two stringers)
	local function stairs(p, u, v, y0, rise, run, w, dir, solid, col, mat, rails, stepH)
		local n = math.max(2, math.floor(rise / (stepH or 0.5) + 0.5))
		local dr = rise / n
		local d = run * rise / n
		local su, sv = 0, 0
		if dir == "+u" then
			su = 1
		elseif dir == "-u" then
			su = -1
		elseif dir == "+v" then
			sv = 1
		else
			sv = -1
		end
		-- art-5b: the Kit5 flight (one mesh, a ramp, handrails) when it is loaded; these steps, stringers and rails otherwise.
		-- Open flights are the steel ones (every open flight here is STL2 / Metal); solid ones are concrete
		local foot = F * CFrame.lookAt(Vector3.new(u, y0, v), Vector3.new(u + su, y0, v + sv))
		local kitOpts = { base = solid and (y0 - solid) or nil, hand = rails and "both" or nil, handColor = STL, handMat = M.Metal }
		if H.k5Flight(p, foot, n, dr, d, w, solid and "C" or "S", col, mat, kitOpts) then
			return n * d
		end
		for k = 1, n do
			local top = y0 + k * dr
			local lo = solid or (top - 0.45)
			local o0, o1 = (k - 1) * d, k * d
			if su ~= 0 then
				ab(p, u + su * o0, u + su * o1, lo, top, v - w / 2, v + w / 2, col, mat)
			else
				ab(p, u - w / 2, u + w / 2, lo, top, v + sv * o0, v + sv * o1, col, mat)
			end
		end
		if not solid then
			local len = n * d
			for _, side in { -1, 1 } do
				local a, b
				if su ~= 0 then
					a = Vector3.new(u, y0 + dr * 0.5, v + side * (w / 2 - 0.1))
					b = Vector3.new(u + su * len, y0 + rise - dr * 0.5, v + side * (w / 2 - 0.1))
				else
					a = Vector3.new(u + side * (w / 2 - 0.1), y0 + dr * 0.5, v)
					b = Vector3.new(u + side * (w / 2 - 0.1), y0 + rise - dr * 0.5, v + sv * len)
				end
				beam(p, a - Vector3.new(0, 0.7, 0), b - Vector3.new(0, 0.7, 0), 0.25, 0.9, STL, M.Metal)
			end
		end
		if rails then
			local len = n * d
			for _, side in { -1, 1 } do
				local o = side * (w / 2 - 0.1)
				if su ~= 0 then
					railAt(p, u, v + o, y0 + dr, u + su * len, v + o, y0 + rise)
				else
					railAt(p, u + o, v, y0 + dr, u + o, v + sv * len, y0 + rise)
				end
			end
		end
		return n * d
	end
	-- a guard rail between two points of the frame (y0, y1 are deck heights at the ends)
	local function rail(p, u0, v0, y0, u1, v1, y1, col)
		col = col or STL
		local a, b = Vector3.new(u0, y0, v0), Vector3.new(u1, y1, v1)
		local len = (b - a).Magnitude
		if len < 0.5 then
			return
		end
		-- art-5b: a level rail is a Kit5 railing when the batch is loaded (sloped ones go with their flight)
		if H.k5Rail(p, F * a, F * b, col, M.Metal) then
			return
		end
		local n = math.max(1, math.ceil(len / 10))
		for k = 0, n do
			local q = a:Lerp(b, k / n)
			ab(p, q.X - 0.15, q.X + 0.15, q.Y, q.Y + 3.4, q.Z - 0.15, q.Z + 0.15, col, M.Metal)
		end
		beam(p, a + Vector3.new(0, 3.35, 0), b + Vector3.new(0, 3.35, 0), 0.3, 0.3, col, M.Metal)
		beam(p, a + Vector3.new(0, 1.7, 0), b + Vector3.new(0, 1.7, 0), 0.2, 0.2, col, M.Metal)
	end
	railAt = rail
	-- rails round a rectangle at deck height y; gaps = list of { side, from, to } (side "n","s","w","e"; from/to along
	-- the side in u or v) left open
	local function railRect(p, u0, u1, v0, v1, y, gaps, col)
		local function side(name, ax, ay, bx, by)
			local cuts = {}
			for _, g in gaps or {} do
				if g[1] == name then
					table.insert(cuts, { g[2], g[3] })
				end
			end
			table.sort(cuts, function(a, b)
				return a[1] < b[1]
			end)
			local horiz = (ay == by)
			local s0, s1 = horiz and ax or ay, horiz and bx or by
			local fixed = horiz and ay or ax
			local cur = s0
			local function seg(a, b)
				if b - a < 0.5 then
					return
				end
				if horiz then
					rail(p, a, fixed, y, b, fixed, y, col)
				else
					rail(p, fixed, a, y, fixed, b, y, col)
				end
			end
			for _, c in cuts do
				seg(cur, c[1])
				cur = c[2]
			end
			seg(cur, s1)
		end
		side("n", u0, v0, u1, v0)
		side("s", u0, v1, u1, v1)
		side("w", u0, v0, u0, v1)
		side("e", u1, v0, u1, v1)
	end
	-- a pitched roof over u0..u1, v0..v1 with the ridge along u; eaves at yE, pitch in degrees, with gable ends
	local function gable(p, u0, u1, v0, v1, yE, pitch, col, mat, gcol)
		local tp = math.tan(math.rad(pitch))
		local hs = (v1 - v0) / 2
		local vc = (v0 + v1) / 2
		local rise = hs * tp
		local ov = 1.4
		for _, s in { -1, 1 } do
			local a = Vector3.new((u0 + u1) / 2, yE - ov * tp, vc + s * (hs + ov))
			local b = Vector3.new((u0 + u1) / 2, yE + rise, vc)
			local wa, wb = F * a, F * b
			local look = CFrame.lookAt((wa + wb) / 2, wb)
			kit.boxCF(p, u1 - u0 + 2 * ov, 0.6, (wb - wa).Magnitude + 0.3, look * CFrame.new(0, 0.3, 0), col, mat)
		end
		for _, gu in { u0 + 0.4, u1 - 0.4 } do
			for _, s in { -1, 1 } do
				kit.part(p, Vector3.new(0.8, rise, hs), cfAt(gu, yE + rise / 2, vc + s * hs / 2, s > 0 and 180 or 0), gcol or col, mat, "WedgePart")
			end
		end
		return rise
	end
	local function colm(p, u, v, y0, y1, s, col, mat)
		return ab(p, u - s / 2, u + s / 2, y0, y1, v - s / 2, v + s / 2, col or PAN2, mat or M.Concrete)
	end

	-- a chain-link fence run (posts, a top rail, a see-through mesh that stops walkers and not bullets), foot at y0
	local FENCE = hex("7B817D")
	local function fenceRun(p, u0, v0, u1, v1, y0, h)
		local a, b = Vector3.new(u0, y0, v0), Vector3.new(u1, y0, v1)
		local len = (b - a).Magnitude
		if len < 0.5 then
			return nil
		end
		local wa, wb = F * a, F * b
		local look = CFrame.lookAt((wa + wb) / 2, wb)
		-- art-5b phase 2: the posts and top rail are Kit5 fence modules when the batch is loaded, these parts otherwise
		if not H.k5Fence(p, wa, wb, h, FENCE, M.Metal) then
			local n = math.max(1, math.floor(len / 6 + 0.5))
			for k = 0, n do
				local q = a:Lerp(b, k / n)
				ab(p, q.X - 0.15, q.X + 0.15, y0 - 0.6, y0 + h, q.Z - 0.15, q.Z + 0.15, FENCE, M.Metal)
			end
			kit.boxCF(p, 0.15, 0.15, len, look * CFrame.new(0, h, 0), FENCE, M.Metal)
		end
		local mesh = kit.boxCF(p, 0.08, h - 0.2, len, look * CFrame.new(0, h / 2, 0), FENCE, M.SmoothPlastic)
		mesh.Transparency = 1
		mesh.CanQuery = false
		mesh.CastShadow = false
		mesh:SetAttribute("NoDetail", true)
		mesh.Name = "ChainLink"
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local tx = Instance.new("Texture")
			tx.Texture = Wear.DEC.ChainLink
			tx.Face = face
			tx.StudsPerTileU = 3
			tx.StudsPerTileV = 3
			tx.Parent = mesh
		end
		return mesh
	end

	-- ── props, containers, doors, loot, lamps ────────────────────────────────────────────────────────────
	-- a Blender kit prop at (u, v) turned by yaw (0: its front faces -v), standing on y (default the ground floor);
	-- nil when the spot is a spawn point. Indoor props cast no shadows (opts.shadows = true outdoors).
	local function K(name, u, v, yaw, y, opts)
		local size = Kit.size(name)
		if not size then
			warn("[ZR] Border works: no kit prop " .. tostring(name))
			return nil
		end
		if reserved(u, v, math.max(size.X, size.Z) * 0.35) then
			nSkip += 1
			return nil
		end
		if bProps >= bCap and not (opts and opts.must) then
			nSkip += 1
			return nil
		end
		local o = { shadows = false }
		for k, val in opts or {} do
			o[k] = val
		end
		o.must = nil
		bProps += 1
		nProps += 1
		return Kit.place(pm, name, cfAt(u, y or FY, v, yaw), o)
	end
	-- the look of each container kind: a kit prop whose collider carries the prompt while the building is under its prop
	-- cap (then, or for the other kinds: World's own crate, drawer, locker or safe)
	-- desks by where they stand (desk() below): a "drawer" container on the same spot uses the desk as its look (it put
	-- its own drawer box inside the desk, poking through the top: placement audit, 2026-11-01)
	local desks = {}
	local LOOK = { toolbox = "ToolChest", weaponbox = "AmmoCrate", crate = "PalletBoxes", locker = "Locker", techbox = "FuseBox", medbag = "FirstAid" }
	local function cont(kind, label, u, v, yaw, y, plain)
		y = y or FY
		contN += 1
		local id = pre .. "_C" .. contN
		local anchor = nil
		local prop = LOOK[kind]
		if kind == "drawer" then
			local here = wp(u, y, v)
			for _, dk in desks do
				if dk.m.Parent and (dk.p - here).Magnitude < 1.5 then
					anchor = dk.m:FindFirstChild("KitCollider")
					break
				end
			end
		end
		if anchor then
			-- the desk is the look
		elseif prop then
			-- a container always gets its look (plain ones too), over the building's prop cap: without it every chest,
			-- radio box and first aid bag was the same 4-stud crate, which stood in benches and hung inside racks
			-- (placement audit, 2026-11-01)
			local _ = plain
			local m = K(prop, u, v, yaw, y, { must = true })
			if not m then
				return nil
			end
			anchor = m:FindFirstChild("KitCollider")
			if not anchor then
				-- a wall fitting without a collider (the first aid box): its biggest piece is the container, not a crate
				local bv = 0
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") and p.Size.X * p.Size.Y * p.Size.Z > bv then
						anchor, bv = p, p.Size.X * p.Size.Y * p.Size.Z
					end
				end
			end
		elseif reserved(u, v, 2) then
			nSkip += 1
			return nil
		end
		kit.container(pm, id, kind, label, cfAt(u, y, v, yaw), anchor)
		nCont += 1
		return id
	end
	-- loose loot on a surface at height y (the spot snaps down to what is below it)
	local function lt(pool, chance, u, v, y)
		local p = wp(u, (y or FY) + 0.5, v)
		kit.loose(p.X, p.Y, p.Z, pool, chance, "border", true)
		nLoose += 1
	end
	-- a hinged door whose hole is centred on (u, v): the leaf swings toward dir ("-v", "+v", "+u", "-u")
	local DOORYAW = { ["-v"] = 0, ["+v"] = math.pi, ["+u"] = -math.pi / 2, ["-u"] = math.pi / 2 }
	local function door(id, label, u, v, dir, w, h, y0, key, col)
		y0 = y0 or FY
		local d = {
			id = id, cf = F * CFrame.new(u, y0 + h / 2, v) * CFrame.Angles(0, DOORYAW[dir], 0), size = Vector3.new(w, h, 0.35),
			key = key, label = label, parent = bm, color = col,
		}
		if not key then
			d.openChance = 0.35
		end
		W.doors[id] = d
		nDoors += 1
		return d
	end
	local function doorId(tag)
		doorN += 1
		return pre .. "_D" .. (tag or doorN)
	end
	-- a ceiling lamp: a lit box at (u, y, v) (range 0: a dead fitting); grp collects the light for a switch
	local function lamp(u, y, v, range, bright, grp, col, long)
		local head = bc(pm, long or 3.2, 0.35, 0.8, u, y, v, range > 0 and (col or WARM) or hex("6F6C64"), range > 0 and M.Neon or M.SmoothPlastic, 0)
		head.CastShadow = false
		head.CanCollide = false
		head:SetAttribute("NoDetail", true)
		nLamps += 1
		if range > 0 then
			local l = kit.light(head, col or WARM, range, bright or 1, false)
			if grp then
				table.insert(grp, l)
			end
			return l
		end
		return nil
	end
	-- the named positions the gameplay part uses: world positions at standing height
	local function point(name, u, y, v)
		points[name] = wp(u, y + 3, v)
	end

	-- ── a hall: floor, walls with gates, doors and windows, columns, tie beams, roof and lamps ───────────────
	local INWARD = { n = "+v", s = "-v", w = "+u", e = "-u" }
	local OUTYAW = { n = 0, s = 180, w = 90, e = -90 } -- a prop's front faces outward on that side
	-- a prop standing against the wall on that side of its room, front toward the room (yaw 0 faces -v)
	local FACE = { n = 180, s = 0, w = -90, e = 90 }
	-- o: u0, u1, v0, v1 (outer extents), h (wall height), t (thickness), col, mat, floor (colour), fy (floor top),
	-- hb (height of door and gate sills above the pad), skip (sides left out), gates/doors/windows per side:
	--   gates[side] = { { s, w, h, closed = prop name }, ... }  doors[side] = { { s, key = item, id = tag }, ... }
	--   windows[side] = { from, to, step, w, b, top }  extra[side] = { { s, w, b, top }, ... } (plain openings)
	-- roof = "gable" (pitch) or "flat" (parapet); cu / cv: column lines; lampsU / lampsV: lamp lines
	local function shell(o)
		local t = o.t or 1.2
		local u0, u1, v0, v1, h = o.u0, o.u1, o.v0, o.v1, o.h
		local fy = o.fy or FY
		local hb = o.hb or 0
		if not o.noFloor then
			slab(bm, u0, u1, v0, v1, fy, 1.0, o.floor or FLR, M.Concrete, o.floorHoles)
		end
		local Hs = { skip = o.skip, n = {}, s = {}, w = {}, e = {} }
		local after = {}
		for _, side in { "n", "s", "w", "e" } do
			for _, g in (o.gates or {})[side] or {} do
				table.insert(Hs[side], { g.s, g.w, hb, hb + g.h })
				table.insert(after, { "gate", side, g })
			end
			for _, d in (o.doors or {})[side] or {} do
				table.insert(Hs[side], { d.s, 4.2, hb, hb + 7.9 })
				table.insert(after, { "door", side, d })
			end
			for _, e in (o.extra or {})[side] or {} do
				table.insert(Hs[side], e)
			end
			local wd = (o.windows or {})[side]
			if wd then
				local s = wd.from
				while s <= wd.to + 0.01 do
					local free = true
					for _, e in Hs[side] do
						if math.abs(e[1] - s) < e[2] / 2 + wd.w / 2 + 1 then
							free = false
						end
					end
					if free then
						table.insert(Hs[side], { s, wd.w, wd.b, wd.top })
					end
					s += wd.step
				end
			end
		end
		rectWalls(bm, u0, u1, v0, v1, 0, h, t, o.col or PAN, o.mat or M.Concrete, Hs)
		for _, a in after do
			local kind, side, g = a[1], a[2], a[3]
			local u, v
			if side == "n" then
				u, v = u0 + g.s, v0 + t / 2
			elseif side == "s" then
				u, v = u0 + g.s, v1 - t / 2
			elseif side == "w" then
				u, v = u0 + t / 2, v0 + g.s
			else
				u, v = u1 - t / 2, v0 + g.s
			end
			if kind == "gate" and g.closed then
				K(g.closed, u, v, OUTYAW[side], fy)
			elseif kind == "door" then
				door(g.id or doorId(), g.label or "Door", u, v, INWARD[side], 4.0, 7.4, fy, g.key, g.key and REDP or hex("5A5F57"))
			end
		end
		local top = h
		-- columns and tie beams
		for _, cu in o.cu or {} do
			for _, cv in o.cv or {} do
				if not reserved(cu, cv, 1.5) then
					colm(bm, cu, cv, fy, top - 2, o.cs or 2.2, PAN2, M.Concrete)
				end
			end
		end
		if o.cu then
			for _, cu in o.cu do
				ab(bm, cu - 0.6, cu + 0.6, top - 3.4, top - 1.6, v0 + t, v1 - t, STL, M.Metal)
			end
		end
		if o.roof == "gable" then
			gable(bm, u0, u1, v0, v1, top, o.pitch or 7, o.roofCol or ROOF, M.Metal, o.col or PAN)
		elseif o.roof == "flat" then
			slab(bm, u0, u1, v0, v1, top + 0.8, 0.8, o.roofCol or ROOF, M.Concrete, o.roofHoles)
			local pa = o.parapet or 3
			if pa > 0 then
				rectWalls(bm, u0, u1, v0, v1, top + 0.8, pa, 0.8, o.col or PAN, M.Concrete, o.pgaps)
			end
		end
		-- lamps
		if o.lampsU then
			local i = 0
			for _, lu in o.lampsU do
				for _, lv in o.lampsV or { (v0 + v1) / 2 } do
					i += 1
					lamp(lu, o.lampY or (h - 3.2), lv, (i % 4 == 0) and 0 or (o.lampRange or 34), 0.9, nil, COLD, 4.4)
				end
			end
		end
	end

	-- a room (offices, cabins, cells): plaster walls on its outer extents u0..u1, v0..v1 standing on floor top y0,
	-- doors[side] = { { s, key, id, w, label, dir }, ... }, windows[side] = { { s, w, bottom, top }, ... },
	-- skip = sides left out, ceil = a ceiling slab, floorCol = a floor slab inside, finish = a wall finish (a MaterialVariant name)
	local function room(o)
		local y0 = o.y0 or FY
		local h = o.h or 9
		local t = o.t or 0.8
		local Hs = { skip = o.skip, n = {}, s = {}, w = {}, e = {} }
		local after = {}
		for _, side in { "n", "s", "w", "e" } do
			for _, d in (o.doors or {})[side] or {} do
				table.insert(Hs[side], { d.s, (d.w or 4.2) + 0.2, 0, 7.9 })
				table.insert(after, { side, d })
			end
			for _, e in (o.windows or {})[side] or {} do
				table.insert(Hs[side], e)
			end
		end
		local into = bm
		if o.finish then
			-- o.finish: the finish of the walls (World.applyWear); the Model's name picks the hue from the list
			roomN += 1
			into = kit.model("Room " .. roomN, bm)
			into:SetAttribute("Finish", o.finish)
			into:SetAttribute("Tint", true)
		end
		rectWalls(into, o.u0, o.u1, o.v0, o.v1, y0, h, t, o.col or PLS, o.mat or M.Plaster, Hs)
		for _, a in after do
			local side, d = a[1], a[2]
			local u, v
			if side == "n" then
				u, v = o.u0 + d.s, o.v0 + t / 2
			elseif side == "s" then
				u, v = o.u0 + d.s, o.v1 - t / 2
			elseif side == "w" then
				u, v = o.u0 + t / 2, o.v0 + d.s
			else
				u, v = o.u1 - t / 2, o.v0 + d.s
			end
			local dir = d.dir or INWARD[side]
			door(d.id or doorId(), d.label or "Door", u, v, dir, d.w or 4.0, 7.4, y0, d.key, d.key and REDP or hex("5A5F57"))
		end
		if o.ceil then
			slab(bm, o.u0, o.u1, o.v0, o.v1, y0 + h + 0.4, 0.4, o.ceilCol or ROOF, M.Concrete)
		end
		if o.floorCol then
			slab(bm, o.u0, o.u1, o.v0, o.v1, y0, 0.3, o.floorCol, M.Concrete)
		end
	end
	-- common small furnishings
	local function rackRow(u, v, n, yaw, step)
		for k = 0, n - 1 do
			K("PalletRack", u + k * (step or 16.5), v, yaw)
		end
	end
	local function desk(u, v, yaw, y)
		local m = K("OfficeDesk", u, v, yaw, y)
		if m then
			table.insert(desks, { p = wp(u, y or FY, v), m = m })
		end
		return m
	end

	-- ═══ STORE 3 (id 22): the big single hall ═════════════════════════════════════════════════════════════
	local function store3(b)
		site(b, "STORE 3", "BW_S3", nil, 50)
		local hw, hd = b[6] / 2, b[7] / 2
		shell({
			u0 = -hw, u1 = hw, v0 = -hd, v1 = hd, h = 25, t = 1.4, col = PAN, roof = "gable", pitch = 7,
			gates = {
				n = { { s = 30, w = 13, h = 10.4, closed = "RollerDoor" }, { s = 86, w = 13, h = 10.4 }, { s = 141, w = 13, h = 10.4, closed = "RollerDoor" } },
				s = { { s = 55, w = 13, h = 10.4 }, { s = 115, w = 13, h = 10.4, closed = "RollerDoor" } },
				w = { { s = 60, w = 13, h = 10.4, closed = "RollerDoor" } },
				e = { { s = 60, w = 13, h = 10.4 } },
			},
			doors = { n = { { s = 8 }, { s = 162 } }, s = { { s = 10 }, { s = 85 }, { s = 160 } }, w = { { s = 16 }, { s = 104 } }, e = { { s = 14 }, { s = 106 } } },
			windows = {
				n = { from = 16, to = 156, step = 14, w = 6, b = 15, top = 20.5 },
				s = { from = 16, to = 156, step = 14, w = 6, b = 15, top = 20.5 },
			},
			cu = { -71.1, -42.7, -14.2, 14.2, 42.7, 71.1 }, cv = { -30, 30 },
			lampsU = { -64, -21, 21, 64 }, lampsV = { -30, 30 },
		})
		-- racking: two blocks facing each other across 8.6-stud aisles
		rackRow(-77, -55.5, 5, 180)
		rackRow(-77, -42.5, 5, 0)
		rackRow(-36, 55.5, 4, 0)
		rackRow(-36, 42.5, 4, 180)
		rackRow(14, -55.5, 2, 180) -- two racks: a third ran 3 studs through the office wall and up into its ceiling
		rackRow(14, -42.5, 2, 0)
		-- stacks, cages, drums
		-- (the first four stood inside the office between its desks until 2026-11-02; they are in the hall beside it now)
		for _, p in { { "PalletBoxes", 63, -27, 10 }, { "PalletBoxes", 63, -21, -5 }, { "PalletBoxes", 77, -26, 0 }, { "CardboardPile", 77, -20, 30 },
			{ "PalletBoxes", 78, 50, 0 }, { "PalletBoxes", 70, 52, 15 }, { "CardboardPile", 62, 54, -20 }, { "TyreStack", -78, 46, 0 }, { "TyreStack", -74, 52, 40 },
			{ "RollCage", -62, 8, 25 }, { "RollCage", -62, 14, -15 }, { "RollCage", -57, 4, 0 }, { "Drum", -80, -22, 0 }, { "Drum", -77.5, -22, 0 },
			{ "Drum", -80, -19, 0 }, { "JerryCans", -77, -17, 30 }, { "Forklift", 27, -30, 160 }, { "Forklift", -20, 22, 40 }, { "PalletBoxes", -8, 30, 90 } } do
			K(p[1], p[2], p[3], p[4])
		end
		-- the workshop corner on the west wall
		K("CraftBench", -80, -8, -90)
		K("ToolChest", -79, 2, -90)
		K("ElectricCabinet", -83.2, 26, -90)
		-- the office in the north-east corner
		room({
			u0 = 52, u1 = 83.3, v0 = -58.3, v1 = -38, h = 9.5, ceil = true, skip = { n = true, e = true }, finish = "ZR_WoodPanel",
			doors = { s = { { s = 8, id = "BW_S3_OFFICE" } }, w = { { s = 17 } } },
			windows = { s = { { 20, 5, 3.5, 6.5 } }, w = {} },
		})
		desk(60, -48, 90)
		desk(74, -44, 180)
		K("Chair", 57, -48, 90)
		K("Chair", 74, -48.5, 0)
		K("Locker", 82, -52, FACE.e)
		K("Locker", 82, -56, FACE.e)
		K("Whiteboard", 69, -57.9, FACE.n, FY + 2.6)
		lamp(68, 9.4, -48, 22, 0.8, nil, WARM, 3.2)
		-- containers
		cont("drawer", "Office desk", 60, -48, 90)
		cont("safe", "Office safe", 80, -40.6, FACE.s)
		cont("locker", "Office locker", 82, -48, FACE.e)
		cont("crate", "Pallet of parts", -30, -36, 0)
		cont("crate", "Pallet of parts", 38, -36, 0)
		cont("crate", "Pallet of parts", 30, 36, 90)
		cont("weaponbox", "Ammunition crate", -4, -36, 180)
		cont("weaponbox", "Ammunition crate", 52, 36, 0)
		cont("toolbox", "Workshop chest", -78, -1, -90)
		cont("toolbox", "Mechanic's chest", 20, -36, 0)
		-- the two lockers south of the west door (v 42.3 to 46.3): one stood in it (placement audit, 2026-11-01)
		cont("locker", "Locker", -83, 36.4, FACE.w)
		cont("locker", "Locker", -83, 38.6, FACE.w)
		cont("medbag", "Medical bag", -81, 30, 0, FY)
		for _, s in { { "junk", 0.5, -70, -49, 6.3 }, { "junk", 0.5, -50, -49, 6.3 }, { "junk", 0.45, -25, 50, 6.3 }, { "junk", 0.45, 10, -50, 6.3 }, { "junk", 0.4, 30, 49, 0.3 },
			{ "junk", 0.4, -66, 6, 0.3 }, { "junk", 0.4, 45, -38, 0.3 }, { "office", 0.5, 62, -52, 2.9 }, { "keys", 0.25, 75, -52, 2.9 }, { "junk", 0.45, -80, -12, 3.5 },
			{ "junk", 0.4, 25, -36, 0.3 }, { "junk", 0.4, -28, 40, 0.3 }, { "tech", 0.3, -82, 28, 0.3 }, { "junk", 0.4, 70, 40, 0.3 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
	end

	-- ── underground spaces ───────────────────────────────────────────────────────────────────────────────
	-- Ground dug every L.under entry as air from y -16 to -4 (earth above) and every level-0 stairs entry as a shaft
	-- open to the sky. These helpers line them: a floor, walls, a ceiling under the earth, and lined shafts.
	local UF, UC, UW = -15.9, -4.1, 1.0 -- floor top, ceiling underside, lining thickness
	local powered = { lights = {}, panels = {} } -- the STORE 4 lever switches these

	local function siteU(u, name, prefix, cap)
		siteAt(u[4], u[5], u[8], 0, name, prefix, UF, cap)
		return u[6] / 2, u[7] / 2
	end
	-- the stairs entry s as an axis-aligned rectangle of the current frame
	local function pitRect(s, grow)
		local p = F:PointToObjectSpace(Vector3.new(O.X + s[3], 0, O.Z + s[4]))
		local a = math.rad(s[7] - curRot)
		local ca, sa = math.abs(math.cos(a)), math.abs(math.sin(a))
		local hu = ca * s[5] / 2 + sa * s[6] / 2 + (grow or 0)
		local hv = sa * s[5] / 2 + ca * s[6] / 2 + (grow or 0)
		return { u0 = p.X - hu, u1 = p.X + hu, v0 = p.Z - hv, v1 = p.Z + hv }
	end
	local function stairsEntry(id)
		for _, s in L.stairs do
			if s[1] == id and s[2] == 0 then
				return s
			end
		end
		return nil
	end
	-- merge intervals
	local function merged(cov)
		table.sort(cov, function(x, y)
			return x[1] < y[1]
		end)
		local out = {}
		for _, c in cov do
			local last = out[#out]
			if last and c[1] <= last[2] + 0.05 then
				last[2] = math.max(last[2], c[2])
			else
				table.insert(out, { c[1], c[2] })
			end
		end
		return out
	end
	-- the parts of a..b not inside the intervals in cov
	local function uncovered(a, b, cov)
		local out, cur = {}, a
		for _, c in merged(cov) do
			if c[1] > cur + 0.05 then
				table.insert(out, { cur, math.min(c[1], b) })
			end
			cur = math.max(cur, c[2])
		end
		if cur < b - 0.05 then
			table.insert(out, { cur, b })
		end
		return out
	end
	-- the stretches of an edge (horizontal: at v = fixed from u a to b; else at u = fixed from v a to b) that lie inside
	-- the rectangles in list (apart from r itself)
	local function inside(list, r, horizontal, fixed, a, b)
		local cov = {}
		for _, q in list do
			if q ~= r then
				local lo, hi, f0, f1
				if horizontal then
					lo, hi, f0, f1 = q.u0, q.u1, q.v0, q.v1
				else
					lo, hi, f0, f1 = q.v0, q.v1, q.u0, q.u1
				end
				if f0 < fixed - 1e-4 and fixed + 1e-4 < f1 then
					local c0, c1 = math.max(a, lo), math.min(b, hi)
					if c1 > c0 + 0.05 then
						table.insert(cov, { c0, c1 })
					end
				end
			end
		end
		return cov
	end
	-- walls (UW thick, outside the rectangle) from y0 to y1 along the edges of r: where the edge is not inside any
	-- rectangle of `block`; with `only`, just the stretches that are inside `only` (and not inside block)
	local function edgeWalls(r, block, only, y0, y1, col, mat)
		local function walls(horizontal, fixed, a, b, sign, ext)
			local spans
			if only then
				spans = {}
				for _, c in merged(inside(only, r, horizontal, fixed, a, b)) do
					for _, iv in uncovered(c[1], c[2], inside(block, r, horizontal, fixed, a, b)) do
						table.insert(spans, iv)
					end
				end
			else
				spans = uncovered(a, b, inside(block, r, horizontal, fixed, a, b))
			end
			for _, iv in spans do
				local s0 = iv[1] - ((ext and iv[1] <= a + 0.06) and UW or 0)
				local s1 = iv[2] + ((ext and iv[2] >= b - 0.06) and UW or 0)
				local f0, f1 = fixed, fixed + sign * UW
				if f1 < f0 then
					f0, f1 = f1, f0
				end
				if horizontal then
					ab(bm, s0, s1, y0, y1, f0, f1, col, mat)
				else
					ab(bm, f0, f1, y0, y1, s0, s1, col, mat)
				end
			end
		end
		walls(true, r.v0, r.u0, r.u1, -1, true)
		walls(true, r.v1, r.u0, r.u1, 1, true)
		walls(false, r.u0, r.v0, r.v1, -1, false)
		walls(false, r.u1, r.v0, r.v1, 1, false)
	end
	-- rooms keep an earth roof (a ceiling slab at y -4.1, with holes where extra says); pits stay open up to the surface (lined
	-- to y 0.4)
	local function dugout(rooms, pits, col, extra)
		col = col or PAN2
		local all = {}
		for _, r in rooms do
			table.insert(all, r)
		end
		for _, r in pits do
			table.insert(all, r)
		end
		local done = {}
		for _, r in all do
			local holes = {}
			for _, q in done do
				table.insert(holes, { q.u0, q.u1, q.v0, q.v1 })
			end
			slab(bm, r.u0, r.u1, r.v0, r.v1, UF, 1.0, FLR2, M.Concrete, holes)
			table.insert(done, r)
		end
		local doneRooms = {}
		for _, r in rooms do
			local holes = {}
			for _, q in pits do
				table.insert(holes, { q.u0, q.u1, q.v0, q.v1 })
			end
			for _, q in extra or {} do
				table.insert(holes, { q.u0, q.u1, q.v0, q.v1 })
			end
			for _, q in doneRooms do
				table.insert(holes, { q.u0 - UW, q.u1 + UW, q.v0 - UW, q.v1 + UW })
			end
			slab(bm, r.u0 - UW, r.u1 + UW, r.v0 - UW, r.v1 + UW, UC + 1.0, 1.0, ROOF, M.Concrete, holes)
			table.insert(doneRooms, r)
		end
		for _, r in rooms do
			edgeWalls(r, all, nil, UF - 0.6, UC, col, M.Concrete)
		end
		for _, r in pits do
			edgeWalls(r, all, nil, UF - 0.6, 0.4, col, M.Concrete) -- clear of every room and pit: the full depth
			edgeWalls(r, pits, rooms, UC, 0.4, col, M.Concrete) -- through the earth over a room: its upper band
		end
	end
	-- a cut in the terrain (air) for shafts the voids did not dig; the Ground part has finished by now
	local function dig(u0, u1, y0, y1, v0, v1)
		local ok = pcall(function()
			local t = workspace.Terrain
			local a, b = F * Vector3.new(u0, y0, v0), F * Vector3.new(u1, y1, v1)
			t:FillBlock(F * CFrame.new((u0 + u1) / 2, (y0 + y1) / 2, (v0 + v1) / 2), Vector3.new(u1 - u0, y1 - y0, v1 - v0), Enum.Material.Air)
			local _ = a + b
		end)
		return ok
	end
	-- ceiling lamps along a tunnel from u0 to u1 at v = vmid: every other one lit (grp: switched by the lever)
	local function tunnelLamps(u0, u1, vmid, every, grp, lit, range)
		local u = u0 + every / 2
		local i = 0
		while u < u1 do
			i += 1
			lamp(u, UC - 0.6, vmid, (lit and (i % 2 == 1)) and (range or 22) or 0, 0.8, grp, WARM, 1.8)
			u += every
		end
	end

	-- ═══ the two bunker sheds and tunnels: BUNKER K-11 and SMUGGLERS' HOLE ═══════════════════════════════════
	local UN = {}
	for _, u in L.under do
		UN[u[1]] = u
	end
	-- the shed over a stair shaft: floor with the shaft cut out, brick walls, a flat roof, a door at the head of the
	-- flight (the end the stairs climb toward) and a lamp
	local function bunkerShed(b, stairId, un, name, prefix, plate)
		local s = stairsEntry(stairId)
		site(b, name, prefix, 0.25)
		local pit = pitRect(s)
		local hw, hd = b[6] / 2, b[7] / 2
		local head = 1
		local tc = F:PointToObjectSpace(Vector3.new(O.X + un[4], 0, O.Z + un[5]))
		if tc.X > (pit.u0 + pit.u1) / 2 then
			head = -1 -- the tunnel lies toward +u: the flight climbs toward -u
		end
		slab(bm, -hw, hw, -hd, hd, FY, 1.0, FLR, M.Concrete, { { pit.u0, pit.u1, pit.v0, pit.v1 } })
		-- concrete pads outside both end walls: Ground's open cut for the shaft runs 2 studs past the flight, 0.75 past the end
		-- walls, and the 4-stud terrain columns along them were dug to the cellar's depth, leaving holes in front of the door
		-- and behind the shed; no AI path reached the doorway (exit check, 2026-11-02)
		for _, sgn in { -1, 1 } do
			slab(bm, sgn > 0 and hw or -hw - 4.5, sgn > 0 and hw + 4.5 or -hw, -hd, hd, FY, 1.0, FLR, M.Concrete)
		end
		local pv = (pit.v0 + pit.v1) / 2
		local Hs = { n = {}, s = {}, w = {}, e = {} }
		local dside = head > 0 and "e" or "w"
		table.insert(Hs[dside], { pv + hd, 4.4, 0, 7.9 })
		table.insert(Hs.n, { hw - 4, 3, 4.5, 6.8 })
		table.insert(Hs.s, { hw + 4, 3, 4.5, 6.8 })
		rectWalls(bm, -hw, hw, -hd, hd, 0, 9.5, 1.0, BRK, M.Brick, Hs)
		door(pre .. "_DOOR", "Bunker shed door", head > 0 and hw - 0.5 or -hw + 0.5, pv, head > 0 and "-u" or "+u", 4.0, 7.4, FY, nil, hex("4D534E"))
		slab(bm, -hw - 0.6, hw + 0.6, -hd - 0.6, hd + 0.6, 10.3, 0.8, ROOF, M.Concrete)
		lamp(0, 8.3, pv, 18, 0.9, nil, WARM, 2.4)
		-- the name plate hangs above the doorway (8.05 to 9.35): at 5.2 to 6.8 it left 5.2 studs of headroom in the door, so
		-- nobody could walk in and the two bunker exits had no path (found in Studio, 2026-11-01)
		local pl = ab(bm, head * (hw + 0.05), head * (hw + 0.5), 8.05, 9.35, pv - 2.2, pv + 2.2, STL, M.Metal)
		if pl then
			kit.sign(pl, head > 0 and Enum.NormalId.Right or Enum.NormalId.Left, plate, C.orange)
		end
		return head
	end

	-- the tunnel under it: o.rooms (rectangles in the L.under frame), the pit of the stair shaft, the flight, and what
	-- each style puts in the rooms
	local function bunkerStairs(pit)
		local su = (pit.u0 + pit.u1) / 2
		local sw = math.min(5.6, pit.u1 - pit.u0 - 0.8)
		local rise = 0.25 - UF
		if (pit.v0 + pit.v1) / 2 < 0 then
			local vb = pit.v1 - 0.2
			local len = vb - pit.v0 - 0.1
			stairs(bm, su, vb, UF, rise, len / rise, sw, "-v", UF - 0.5, PAN2, M.Concrete, true)
		else
			local vb = pit.v0 + 0.2
			local len = pit.v1 - vb - 0.1
			stairs(bm, su, vb, UF, rise, len / rise, sw, "+v", UF - 0.5, PAN2, M.Concrete, true)
		end
	end

	local function k11()
		local un = UN.K11
		local hw, hd = siteU(un, "BUNKER K-11", "BW_K11", 18)
		local pit = pitRect(stairsEntry("ladder-33"))
		-- the flight must climb toward -v (away from the tunnel): check the frame's orientation
		local room = { u0 = -hw, u1 = hw, v0 = -hd, v1 = hd }
		dugout({ room }, { pit })
		bunkerStairs(pit)
		-- partitions: the blast door (open for the extract) and the vault door (key)
		local lights = powered.lights
		wl(bm, -9, -hd, -9, hd, UF, UC - UF, 1.0, PAN2, M.Concrete, { { hd, 5.2, 0, 7.8 } })
		wl(bm, 9, -hd, 9, hd, UF, UC - UF, 1.0, PAN2, M.Concrete, { { hd, 4.6, 0, 7.8 } })
		door("BW_K11_BLAST", "Bunker blast door", -9, 0, "+u", 5.0, 7.5, UF, nil, hex("3F4642"))
		door("by_k11", "Bunker K-11 vault", 9, 0, "-u", 4.4, 7.5, UF, "KEY_BY_K11", hex("4E5248"))
		point("K11_DOOR", -9, UF, 0)
		-- lamps: the hall and corridor are lit, the vault is not
		tunnelLamps(-hw, hw, 0, 9, nil, true, 24)
		-- arrival hall
		K("Locker", -23.5, 4.8, FACE.w, UF)
		K("Locker", -23.5, 1.8, FACE.w, UF)
		K("Bench", -12.5, 5.6, 0, UF)
		K("AmmoCrate", -13, -5.4, 20, UF)
		K("SignPost", -10.2, 3.2, 90, UF)
		-- corridor: pipes, a cable tray, bunks in the south alcove
		K("PipeRun", -4, -6.2, 0, UF + 8.3)
		K("PipeRun", 12, -6.2, 0, UF + 8.3)
		K("CableTray", 0, 6.2, 0, UF + 8.8)
		K("BunkBed", -1, 5.3, 0, UF)
		K("BunkBed", 5.5, 5.3, 0, UF)
		K("Extinguisher", -8.3, 6.3, 0, UF + 1.5)
		K("ElectricCabinet", 7.8, -6.1, FACE.n, UF)
		cont("medbag", "First aid bag", -6, 6.3, FACE.s, UF + 3)
		cont("toolbox", "Maintenance chest", 2, -5.4, FACE.n, UF)
		-- vault
		K("GunRack", 23.9, 0, FACE.e, UF + 0.2)
		K("AmmoCrate", 21, -5.6, 90, UF)
		cont("weaponbox", "Armoury crate", 22.5, -4.8, 90, UF)
		cont("weaponbox", "Armoury crate", 22.5, 4.8, 90, UF)
		cont("safe", "Commander's safe", 12, -5.4, FACE.n, UF)
		cont("drawer", "Duty desk", 12, 5.2, FACE.s, UF)
		lt("vault", 0.6, 17, 0, UF)
		lt("vault", 0.5, 14, -4, UF)
		lt("vault", 0.5, 20, 4.5, UF)
		lt("junk", 0.5, -14, 5, UF)
		lt("junk", 0.45, -3, -5, UF)
		-- surface
		bunkerShed(byId[50], "ladder-33", un, "BUNKER K-11 SHED", "BW_K11S", "BUNKER K-11")
		lt("junk", 0.4, 5, 0, 0.25)
	end

	local function smugglers()
		local un = UN.SH
		local hw, hd = siteU(un, "SMUGGLERS' HOLE", "BW_SH", 16)
		local pit = pitRect(stairsEntry("ladder-34"))
		local room = { u0 = -hw, u1 = hw, v0 = -hd, v1 = hd }
		dugout({ room }, { pit }, PAN2)
		bunkerStairs(pit)
		local lights = powered.lights
		local _ = lights
		-- a cache: timber-propped, crates and barrels; a low wall splits the arrival hall from the tunnel
		wl(bm, -8, -hd, -8, -1.2, UF, 9, 0.8, hex("5C4A38"), M.WoodPlanks, nil)
		wl(bm, -8, 1.2, -8, hd, UF, 9, 0.8, hex("5C4A38"), M.WoodPlanks, nil)
		for _, uu in { -4, 4, 12, 20 } do
			ab(bm, uu - 0.4, uu + 0.4, UF, UC, -hd, -hd + 0.5, hex("5C4A38"), M.WoodPlanks)
			ab(bm, uu - 0.4, uu + 0.4, UF, UC, hd - 0.5, hd, hex("5C4A38"), M.WoodPlanks)
			ab(bm, uu - 0.4, uu + 0.4, UC - 0.7, UC, -hd, hd, hex("5C4A38"), M.WoodPlanks)
		end
		tunnelLamps(-hw, hw, 0, 12, nil, true, 20)
		-- the tunnel is 12.8 studs wide (walls at v -6.4 and 6.4): crates, drums and lockers along both walls, a walkway
		-- of about 4.8 down the middle. The first layout ran pallets and lockers 1 to 2 studs into the walls and into each
		-- other, and doubled two crates (placement audit, 2026-11-02).
		for _, p in { { "PalletBoxes", -14, 4.0, 10 }, { "PalletBoxes", -18.9, 3.75, -20 }, { "Drum", -12, -5.3, 0 }, { "Drum", -10, -5.3, 0 }, { "JerryCans", -11, -3.8, 40 },
			{ "CardboardPile", 8, 3.8, 0 }, { "Drum", 11.5, -5.3, 0 }, { "RollCage", 17, 4.6, 90 },
			{ "StorageShelf", 0, -5.35, FACE.n }, { "Lockers", 20.8, -5.45, FACE.n } } do
			K(p[1], p[2], p[3], p[4], UF)
		end
		cont("crate", "Smuggled goods", 2, 4.35, 0, UF)
		cont("crate", "Smuggled goods", 12.5, 4.35, 0, UF)
		cont("weaponbox", "Hidden weapons", -15, -4.9, 0, UF)
		cont("toolbox", "Smuggler's chest", 14, -5.0, 180, UF)
		cont("safe", "Cache safe", 22.5, 2, -90, UF)
		cont("locker", "Locker", 16.6, -5.4, FACE.n, UF)
		for _, s in { { "junk", 0.5, -14, 1 }, { "junk", 0.5, 6, 0 }, { "vault", 0.4, 21, 0 }, { "keys", 0.3, 10, -5 }, { "junk", 0.45, 16, 3 } } do
			lt(s[1], s[2], s[3], s[4], UF)
		end
		point("SMUGGLERS_HOLE", -hw + 6, UF, 2)
		bunkerShed(byId[51], "ladder-34", un, "SMUGGLERS' HOLE SHED", "BW_SHS", "SMUGGLERS' HOLE")
	end

	-- ═══ STORE 4 (id 23): the hall with the office deck, and under it the switch basement with the K-13 lever ══
	local LAMP_ON, LAMP_OFF = hex("7CFF9B"), hex("26302A")
	-- rails round a floor opening, left open on the side the flight arrives on
	local function pitRails(r, y, openSide)
		railRect(bm, r.u0, r.u1, r.v0, r.v1, y, { { openSide, -1000, 1000 } })
	end

	-- the lever: a plate on the west wall of the basement, an arm that swings down when it is thrown, a lamp, and the
	-- invisible panel that carries the prompt. W.switches.BORDER_STORE4 is what the K-13 exit waits for.
	local function lever(u, v, y)
		ab(bm, u - 0.2, u + 0.5, y + 1.2, y + 8.2, v - 2.9, v + 2.9, hex("3B403D"), M.Metal)
		ab(bm, u + 0.5, u + 0.9, y + 1.8, y + 2.6, v - 1, v + 1, hex("55524A"), M.Metal)
		ab(bm, u + 0.5, u + 0.9, y + 6.8, y + 7.6, v - 1, v + 1, hex("55524A"), M.Metal)
		local lampPart = ab(bm, u + 0.5, u + 0.8, y + 7.0, y + 7.6, v + 1.6, v + 2.4, LAMP_OFF, M.SmoothPlastic)
		table.insert(powered.panels, lampPart)
		local pivot = cfAt(u + 1.3, y + 4.7, v)
		local flip = CFrame.Angles(math.rad(180), 0, 0)
		local arm = kit.boxCF(bm, 0.45, 3.0, 0.45, pivot * CFrame.new(0, 1.5, 0), hex("A9A48F"), M.Metal)
		local knob = kit.boxCF(bm, 0.9, 0.9, 0.9, pivot * CFrame.new(0, 3.2, 0), hex("8E2F27"), M.SmoothPlastic)
		arm.Name = "LeverArm"
		arm.CanCollide = false
		knob.CanCollide = false
		local armOff, armOn = arm.CFrame, (pivot * flip) * CFrame.new(0, 1.5, 0)
		local knobOff, knobOn = knob.CFrame, (pivot * flip) * CFrame.new(0, 3.2, 0)
		local panel = kit.boxCF(bm, 3.4, 6, 3.4, cfAt(u + 1.7, y + 4.7, v), hex("6C7A72"), M.Metal)
		panel.Name = "LeverPanel"
		panel.Transparency = 1
		panel.CanCollide = false
		panel:SetAttribute("NoDetail", true)
		local pp = Instance.new("ProximityPrompt")
		pp.KeyboardKeyCode = Enum.KeyCode.F
		pp.ActionText = "Throw the lever"
		pp.ObjectText = "Power switch"
		pp.HoldDuration = 3
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Style = Enum.ProximityPromptStyle.Custom
		pp.Parent = panel
		W.switches.BORDER_STORE4 = {
			id = "BORDER_STORE4", label = "Power switch", part = panel, prompt = pp, delay = 5, startText = "THROWING THE LEVER", doneText = "POWER ON",
			onChange = function(on)
				for _, l in powered.lights do
					l.Enabled = on
				end
				for _, p in powered.panels do
					p.Material = on and M.Neon or M.SmoothPlastic
					p.Color = on and LAMP_ON or LAMP_OFF
				end
				arm.CFrame = on and armOn or armOff
				knob.CFrame = on and knobOn or knobOff
			end,
		}
	end

	-- the basement: three zones split by two walls with doorways, six pillars, two stair shafts, the generator hall
	-- with the lever at the west end
	local function store4Basement()
		local un = UN.S4
		local hw, hd = siteU(un, "STORE 4 BASEMENT", "BW_S4B", 20)
		lever(-hw, -6.6, UF) -- first: the K-13 exit waits for it whatever fails below
		point("STORE4_LEVER", -hw + 4.6, UF, -6.6)
		local room = { u0 = -hw, u1 = hw, v0 = -hd, v1 = hd }
		local pA, pB = pitRect(stairsEntry("ladder-35")), pitRect(stairsEntry("ladder-36"))
		dugout({ room }, { pA, pB })
		local rise = 0.25 - UF
		-- two broad flights climbing out of the corridor: A toward +u, B toward -u
		stairs(bm, pA.u0 + 0.1, (pA.v0 + pA.v1) / 2, UF, rise, (pA.u1 - pA.u0 - 0.3) / rise, pA.v1 - pA.v0 - 0.6, "+u", UF - 0.5, PAN2, M.Concrete, true)
		stairs(bm, pB.u1 - 0.1, (pB.v0 + pB.v1) / 2, UF, rise, (pB.u1 - pB.u0 - 0.3) / rise, pB.v1 - pB.v0 - 0.6, "-u", UF - 0.5, PAN2, M.Concrete, true)
		-- the two partitions (doorways 7 wide)
		wl(bm, -62, -hd, -62, hd, UF, UC - UF, 1.0, PAN2, M.Concrete, { { hd - 6, 7, 0, 8 }, { hd + 18, 6, 0, 8 } })
		wl(bm, 40, -hd, 40, hd, UF, UC - UF, 1.0, PAN2, M.Concrete, { { hd + 8, 7, 0, 8 } })
		for _, pu in { -72, -43, -14, 15, 55, 73 } do
			ab(bm, pu - 2.65, pu + 2.65, UF, UC, 9, 12.2, PAN2, M.Concrete)
		end
		-- lamps: the switched ones, and three that stay lit (lever, stair feet)
		for _, p in { { -74, -14 }, { -50, 14 }, { -20, -12 }, { 12, 14 }, { 62, 14 }, { 76, -14 } } do
			lamp(p[1], UC - 0.6, p[2], 26, 0.8, powered.lights, WARM, 3.6)
		end
		lamp(-80, UC - 0.6, -6.6, 16, 0.6, nil, WARM, 2.4)
		lamp((pA.u0 + pA.u1) / 2, UC - 0.6, (pA.v0 + pA.v1) / 2 - 8, 14, 0.6, nil, WARM, 2.4)
		lamp((pB.u0 + pB.u1) / 2, UC - 0.6, (pB.v0 + pB.v1) / 2 + 8, 14, 0.6, nil, WARM, 2.4)
		-- generator hall (west zone)
		K("HideoutGenerator", -72, 25.2, FACE.s, UF)
		K("ElectricCabinet", -85.4, 3, FACE.w, UF)
		K("ElectricCabinet", -85.4, 10, FACE.w, UF)
		K("FuseBox", -85.4, 17, FACE.w, UF + 0.1)
		K("Table", -76, -21, 0, UF)
		K("Chair", -76, -18, 180, UF)
		K("JunctionBox", -85.8, -14, FACE.w, UF + 3)
		K("Extinguisher", -85.8, -17, FACE.w, UF + 2)
		K("PipeRun", -78, -27, FACE.n, UF + 8.2)
		K("PipeRun", -66, -27, FACE.n, UF + 8.2)
		-- the stores and workshop zones
		for _, p in { { "StorageShelf", -48, -26.9, FACE.n }, { "StorageShelf", -39.5, -26.9, FACE.n }, { "StorageRack", -30, -26.9, FACE.n }, { "PalletBoxes", -20, -24, 10 },
			{ "PalletBoxes", 5, -24, 0 }, { "CardboardPile", 12, -23, 20 }, { "Drum", 20, -26, 0 }, { "Drum", 22, -26, 0 }, { "JerryCans", 27, -25, 30 }, { "RollCage", 30, 22, 20 },
			{ "StorageShelf", -10, 26.9, FACE.s }, { "StorageShelf", 0, 26.9, FACE.s }, { "Table", 49, -24, 0 }, { "CraftBench", 60, 26, FACE.s }, { "ToolChest", 69, 26.2, FACE.s },
			{ "TyreStack", 80, 24, 0 }, { "PipeRun", -28, -27, FACE.n, UF + 8.2 }, { "PipeRun", -12, -27, FACE.n, UF + 8.2 }, { "PipeRunRust", 4, -27, FACE.n, UF + 8.2 },
			{ "CableTray", 20, 26.8, FACE.s, UF + 8.6 }, { "CableTray", 56, 26.8, FACE.s, UF + 8.6 }, { "Duct", 72, -26.8, FACE.n, UF + 8.4 } } do
			K(p[1], p[2], p[3], p[4], p[5] or UF)
		end
		cont("crate", "Stores crate", -20, -24, 0, UF)
		cont("crate", "Stores crate", 5, -24, 0, UF)
		cont("techbox", "Switchgear box", -84.6, 22, FACE.w, UF)
		cont("toolbox", "Electrician's chest", -70, -24.6, FACE.n, UF)
		cont("toolbox", "Workshop chest", 66, 26.2, FACE.s, UF)
		cont("weaponbox", "Sealed crate", 24, -24.6, 0, UF)
		cont("drawer", "Duty desk", 49, -22, 0, UF)
		cont("medbag", "First aid bag", -2, 26.5, FACE.s, UF + 3)
		for _, s in { { "junk", 0.5, -50, -2 }, { "junk", 0.5, -18, 2 }, { "junk", 0.45, 30, -4 }, { "tech", 0.4, -80, 12 }, { "junk", 0.45, 49, -22.5 }, { "keys", 0.3, 8, 26 }, { "junk", 0.4, 60, 6 } } do
			lt(s[1], s[2], s[3], s[4], UF)
		end
	end

	local function store4()
		local b = byId[23]
		site(b, "STORE 4", "BW_S4", nil, 44)
		wallFinish("ZR_BrickWall") -- a brick hall (its shift office has its own finish)
		local hw, hd = b[6] / 2, b[7] / 2
		local pA = pitRect(stairsEntry("ladder-35"), 0.2)
		local pB = pitRect(stairsEntry("ladder-36"), 0.2)
		local DECK = 12.8 -- top of the deck slabs
		local rise = DECK - FY
		local iw, id = hw - 1.4, hd - 1.4 -- inner faces of the walls
		shell({
			u0 = -hw, u1 = hw, v0 = -hd, v1 = hd, h = 26, t = 1.4, col = PAN, roof = "gable", pitch = 8,
			floorHoles = { { pA.u0, pA.u1, pA.v0, pA.v1 }, { pB.u0, pB.u1, pB.v0, pB.v1 } },
			gates = {
				w = { { s = 58.75, w = 13, h = 10.4 } },
				e = { { s = 47, w = 13, h = 10.4, closed = "RollerDoor" } },
				n = { { s = 40, w = 13, h = 10.4 }, { s = 105, w = 13, h = 10.4, closed = "RollerDoor" }, { s = 170, w = 13, h = 10.4 } },
				s = { { s = 60, w = 13, h = 10.4, closed = "RollerDoor" }, { s = 150, w = 13, h = 10.4 } },
			},
			doors = { w = { { s = 20 }, { s = 80 } }, e = { { s = 15 } }, n = { { s = 12 }, { s = 200 } }, s = { { s = 20 }, { s = 190 } } },
			windows = {
				n = { from = 20, to = 195, step = 15, w = 6, b = 15, top = 20.5 },
				s = { from = 20, to = 195, step = 15, w = 6, b = 15, top = 20.5 },
			},
			cu = { -79, -52.7, -26.4, 0, 26.4, 52.7, 79 }, cv = { -30.5, 30.5 },
			lampsU = { -79, -26, 26, 79 }, lampsV = { -26, 26 },
		})
		-- the decks: D1 over the south side, D2 its annex, D3 the far deck in the north-west with its landing
		local D1 = { u0 = -10.2, u1 = iw, v0 = 3.5, v1 = id }
		local D2 = { u0 = -29.8, u1 = -10.2, v0 = 8.8, v1 = 30 }
		local D3 = { u0 = -iw, u1 = -72.1, v0 = -id, v1 = -24 }
		local D3b = { u0 = -iw, u1 = -92.6, v0 = -24, v1 = -19.5 }
		for _, d in { D1, D2, D3, D3b } do
			slab(bm, d.u0, d.u1, d.v0, d.v1, DECK, 0.8, FLR2, M.Concrete)
		end
		for _, cu in { 0, 26.4, 52.7, 79, 100 } do
			colm(bm, cu, 4.6, FY, DECK - 0.8, 1.8, PAN2, M.Concrete)
		end
		for _, c in { { -28.6, 9.8 }, { -28.6, 29 }, { -73.2, -44.4 }, { -73.2, -25.2 }, { -91, -25.2 }, { -102.8, -20.7 } } do
			colm(bm, c[1], c[2], FY, DECK - 0.8, 1.8, PAN2, M.Concrete)
		end
		-- flights: to D1 along +u at v 36, to the far deck along -u under its south edge
		stairs(bm, -30, 36, FY, rise, (D1.u0 + 30) / rise, 5, "+u", FY - 0.2, PAN2, M.Concrete, true)
		stairs(bm, D3.u1, -21.75, FY, rise, (D3.u1 - D3b.u1) / rise, 4.5, "-u", FY - 0.2, PAN2, M.Concrete, true)
		-- rails on every open edge
		railRect(bm, D1.u0, D1.u1, D1.v0, D1.v1, DECK, { { "w", 8.8, 30 }, { "w", 33.5, 38.5 }, { "e", -1000, 1000 }, { "s", -1000, 1000 } })
		railRect(bm, D2.u0, D2.u1, D2.v0, D2.v1, DECK, { { "e", -1000, 1000 } })
		railRect(bm, D3.u0, D3.u1, D3.v0, D3.v1, DECK, { { "w", -1000, 1000 }, { "n", -1000, 1000 }, { "s", D3.u0, D3b.u1 } })
		railRect(bm, D3b.u0, D3b.u1, D3b.v0, D3b.v1, DECK, { { "w", -1000, 1000 }, { "n", -1000, 1000 }, { "e", -1000, 1000 } })
		-- the stair openings in the hall floor
		pitRails(pA, FY, "e")
		pitRails(pB, FY, "w")
		-- the shift office in the south-east corner of D1
		room({
			u0 = 62, u1 = iw, v0 = 27, v1 = id, y0 = DECK, h = 9, ceil = true, skip = { e = true, s = true }, finish = "ZR_WallpaperB",
			doors = { n = { { s = 10, id = "BW_S4_OFFICE" } }, w = { { s = 12 } } },
			windows = { n = { { 26, 5, 3.5, 6.5 } } },
		})
		desk(70, 33, 0, DECK)
		desk(84, 40, 90, DECK)
		K("Chair", 70, 36.5, 0, DECK)
		K("Locker", iw - 1, 31, FACE.e, DECK)
		K("Locker", iw - 1, 34, FACE.e, DECK)
		K("Whiteboard", 80, id - 0.4, FACE.s, DECK + 2.6)
		lamp(82, DECK + 9.4, 36, 22, 0.8, nil, WARM, 3.2)
		cont("drawer", "Shift desk", 70, 33, 0, DECK)
		cont("safe", "Shift office safe", 94, id - 1.8, FACE.s, DECK)
		cont("locker", "Locker", iw - 1, 38, FACE.e, DECK)
		cont("techbox", "Radio spares", 66, id - 1.2, FACE.s, DECK)
		-- the deck: a stockroom along the south wall, the annex, the far deck
		for _, p in { { "StorageRack", 8, id - 1.2, FACE.s }, { "StorageRack", 17, id - 1.2, FACE.s }, { "StorageShelf", 26, id - 1.2, FACE.s }, { "PalletBoxes", 32, 12, 0 },
			{ "PalletBoxes", 40, 14, 20 }, { "CardboardPile", 50, 10, 0 }, { "RollCage", 96, 10, 90 }, { "Table", -20, 14, 0 }, { "Chair", -18, 18, 200 }, { "ClothesRack", -22, 25, 90 },
			{ "Bed", -96, -38, FACE.w }, { "Locker", -iw + 1, -28, FACE.w }, { "Table", -86, -30, 0 } } do
			K(p[1], p[2], p[3], p[4], DECK)
		end
		cont("crate", "Stock crate", 32, 12, 0, DECK)
		cont("crate", "Stock crate", 60, 8, 0, DECK)
		cont("toolbox", "Stockroom chest", 74, 8, 0, DECK)
		cont("weaponbox", "Ammunition crate", 100, 20, 90, DECK)
		cont("drawer", "Annex desk", -20, 14, 0, DECK)
		cont("locker", "Night watch locker", -iw + 1, -32, FACE.w, DECK)
		cont("medbag", "First aid bag", -86, -id + 1.2, FACE.n, DECK + 3)
		-- the ground floor: double rows of pallet racking between the north gates, shelving under the decks, loading area
		for _, u in { -48.4, 17 } do
			rackRow(u, -42, 3, 180)
			rackRow(u, -37.4, 3, 0)
		end
		for _, p in { { "StorageShelf", -100, -id + 1.2, FACE.n }, { "StorageShelf", -91.8, -id + 1.2, FACE.n }, { "StorageRack", -83.6, -id + 1.2, FACE.n }, { "StorageRack", -100, -32, 0 },
			{ "StorageRack", -91, -32, 0 }, { "StorageShelf", 14, id - 1.2, FACE.s }, { "StorageShelf", 30, id - 1.2, FACE.s }, { "StorageRack", 70, id - 1.2, FACE.s },
			{ "PalletBoxes", 40, 14, 10 }, { "PalletBoxes", 46, 14, -10 }, { "CardboardPile", 66, 12, 0 }, { "Forklift", 18, -22, 200 }, { "Forklift", -60, 18, 70 },
			{ "RollCage", 4, 26, 10 }, { "PalletBoxes", 92, -22, 0 }, { "PalletBoxes", 96, -26, 15 }, { "PalletBoxes", 88, -14, 0 }, { "Drum", 100, -40, 0 }, { "Drum", 98, -42, 0 },
			{ "TyreStack", 80, -42, 0 }, { "CraftBench", 20, 20, 180 }, { "ElectricCabinet", iw - 0.8, 20, FACE.e } } do
			K(p[1], p[2], p[3], p[4])
		end
		cont("crate", "Pallet of parts", -60, -22, 0)
		cont("crate", "Pallet of parts", 40, 14, 0)
		cont("crate", "Pallet of parts", 92, -22, 0)
		cont("weaponbox", "Ammunition crate", -20, -22.4, 0)
		cont("weaponbox", "Ammunition crate", 82, 30, 90)
		cont("toolbox", "Mechanic's chest", 26, 20, 180)
		cont("toolbox", "Loader's chest", 8, 30, 90)
		cont("locker", "Locker", iw - 1, 4, FACE.e)
		cont("locker", "Locker", iw - 1, 8, FACE.e)
		cont("drawer", "Dispatcher's desk", -98, 40, 0)
		for _, s in { { "junk", 0.5, -40, -20, 0.3 }, { "junk", 0.45, 10, -20, 0.3 }, { "junk", 0.45, 62, 20, 0.3 }, { "junk", 0.4, 90, -26, 0.3 }, { "junk", 0.4, -20, 30, 0.3 },
			{ "junk", 0.4, -90, 20, 0.3 }, { "office", 0.45, 72, 34, DECK + 3.4 }, { "keys", 0.25, 70, 34, DECK + 3.4 }, { "junk", 0.4, 40, 12, DECK + 0.1 }, { "tech", 0.35, 66, 42, DECK + 0.1 },
			{ "junk", 0.4, -86, -33, DECK + 3.3 }, { "junk", 0.4, -20, 17, DECK + 3.3 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
		lamp(-20, DECK + 8, 20, 20, 0.8, nil, WARM, 3.2)
		lamp(40, DECK + 8, 20, 20, 0.8, nil, COLD, 4.4)
		lamp(-88, DECK + 8, -34, 18, 0.8, nil, WARM, 3.2)
		run("STORE 4 BASEMENT", store4Basement)
		if W.switches.BORDER_STORE4 then
			W.switches.BORDER_STORE4.onChange(false)
		end
	end

	-- ═══ STORE 7 (id 20): two office mezzanines and a locked office (KEY_BY_STORE) ══════════════════════════
	local function store7()
		local b = byId[20]
		site(b, "STORE 7", "BW_S7", nil, 40)
		local hw, hd = b[6] / 2, b[7] / 2
		local iw, id = hw - 1.4, hd - 1.4
		local DECK = 12.8
		local rise = DECK - FY
		shell({
			u0 = -hw, u1 = hw, v0 = -hd, v1 = hd, h = 24, t = 1.4, col = PAN, roof = "gable", pitch = 7,
			gates = {
				n = { { s = 30, w = 13, h = 10.4, closed = "RollerDoor" }, { s = 100, w = 13, h = 10.4 } },
				s = { { s = 45, w = 13, h = 10.4 }, { s = 115, w = 13, h = 10.4, closed = "RollerDoor" } },
				w = { { s = 37.5, w = 13, h = 10.4 } },
				e = { { s = 37.5, w = 13, h = 10.4, closed = "RollerDoor" } },
			},
			doors = { n = { { s = 8 }, { s = 125 } }, s = { { s = 10 }, { s = 80 } }, w = { { s = 12 } }, e = { { s = 62 } } },
			windows = {
				n = { from = 18, to = 120, step = 14, w = 6, b = 14, top = 19.5 },
				s = { from = 18, to = 120, step = 14, w = 6, b = 14, top = 19.5 },
			},
			cu = { -53.4, -26.7, 0, 26.7, 53.4 }, cv = { -26, 26 },
			lampsU = { -45, 0, 45 }, lampsV = { -18, 18 },
		})
		-- two mezzanines in the middle of the hall, each reached by a flight along v = 5 from its east side
		local U1 = { u0 = -51.8, u1 = -28, v0 = -19.95, v1 = 12.55 }
		local U2 = { u0 = -7.9, u1 = 15.9, v0 = -19.55, v1 = 12.95 }
		for _, d in { U1, U2 } do
			slab(bm, d.u0, d.u1, d.v0, d.v1, DECK, 0.8, FLR2, M.Concrete)
			for _, cu in { d.u0 + 1.6, d.u1 - 1.6 } do
				for _, cv in { d.v0 + 1.6, d.v1 - 1.6 } do
					colm(bm, cu, cv, FY, DECK - 0.8, 1.8, PAN2, M.Concrete)
				end
			end
			railRect(bm, d.u0, d.u1, d.v0, d.v1, DECK, { { "e", 2.75, 7.25 } })
		end
		stairs(bm, U2.u0, 5, FY, rise, (U2.u0 - U1.u1) / rise, 4.5, "-u", FY - 0.2, PAN2, M.Concrete, true)
		stairs(bm, 36, 5, FY, rise, (36 - U2.u1) / rise, 4.5, "-u", FY - 0.2, PAN2, M.Concrete, true)
		-- the offices on the mezzanines
		room({
			u0 = U1.u0 + 0.4, u1 = U1.u1 - 6, v0 = U1.v0 + 0.4, v1 = U1.v1 - 0.4, y0 = DECK, h = 9, ceil = true, finish = "ZR_WallpaperA",
			doors = { e = { { s = 24.5, id = "BW_S7_OFFICE1" } } }, windows = { n = { { 9, 5, 3.5, 6.5 } }, w = { { 16, 5, 3.5, 6.5 } } },
		})
		desk(-44, -8, 90, DECK)
		K("Chair", -41, -8, FACE.w, DECK)
		K("Locker", -36, 10.6, FACE.s, DECK)
		K("Whiteboard", -44, 11.8, FACE.s, DECK + 2.6)
		lamp(-40, DECK + 9.4, -4, 20, 0.8, nil, WARM, 3.2)
		cont("drawer", "Dispatcher's desk", -44, -8, 90, DECK)
		cont("safe", "Wages safe", -49, 10, FACE.s, DECK)
		K("PalletBoxes", 2, -12, 10, DECK)
		K("PalletBoxes", 9, -14, -20, DECK)
		K("RollCage", 11, 6, 0, DECK)
		cont("crate", "Stock crate", 2, -12, 0, DECK)
		cont("toolbox", "Loader's chest", 12, -17.6, FACE.n, DECK)
		cont("weaponbox", "Ammunition crate", -3, 10, 0, DECK)
		-- the locked office: south-east corner, one door (KEY_BY_STORE), a window to look in through
		room({
			u0 = 40, u1 = iw, v0 = 14, v1 = id, y0 = FY, h = 10, ceil = true, skip = { e = true, s = true }, finish = "ZR_WoodPanel",
			doors = { n = { { s = 10, key = "KEY_BY_STORE", id = "by_store7", label = "Store 7 office" } } },
			windows = { w = { { 14, 5, 3.5, 6.5 } } },
		})
		desk(52, 22, 90)
		K("Chair", 49, 22, FACE.w)
		K("Lockers", 60, id - 1.6, FACE.s)
		K("StorageShelf", 47.8, id - 1.2, FACE.s) -- clear of the safe by the west wall (it stood 1.6 into it)
		lamp(52, 9.4, 26, 18, 0.7, nil, WARM, 3.2)
		cont("safe", "Store 7 safe", 62, 18, FACE.n)
		cont("safe", "Store 7 safe", 42.3, id - 3, FACE.w)
		cont("drawer", "Filing drawers", 44, 16, FACE.n)
		cont("techbox", "Radio crate", 56, id - 1.4, FACE.s)
		cont("weaponbox", "Strongbox", 64, 28, FACE.e)
		for _, s in { { "vault", 0.6, 52, 24, 2.9 }, { "vault", 0.5, 62, 20, 0.3 }, { "keys", 0.4, 48, 30, 0.3 }, { "office", 0.5, 44, 20, 0.3 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
		-- the hall: racks along the north wall and the south-west, a loading area, cages and pallets
		rackRow(-60, -34, 4, 180)
		rackRow(-60, -29.5, 4, 0)
		rackRow(-58, 33, 3, FACE.s)
		-- (the second forklift stood in the pallet racks at -10, -30 until 2026-11-02; it is parked in the aisle in front of them)
		for _, p in { { "Forklift", 20, 28, 40 }, { "Forklift", -12, -23.4, 96 }, { "RollCage", 30, -10, 10 }, { "RollCage", 33, -6, -20 }, { "PalletBoxes", 44, -30, 0 },
			{ "PalletBoxes", 52, -32, 20 }, { "PalletBoxes", 58, -28, -10 }, { "CardboardPile", 48, -4, 0 }, { "Drum", 62, -8, 0 }, { "Drum", 60, -10, 0 }, { "Drum", 62, -12, 0 },
			{ "TyreStack", -60, 8, 0 }, { "TyreStack", -62, 14, 0 }, { "CraftBench", -62, -4, FACE.w }, { "ToolChest", -61, 4.9, FACE.w }, { "PalletBoxes", 10, 30, 90 },
			{ "ElectricCabinet", -iw + 0.8, 24, FACE.w }, { "JerryCans", 36, 20, 30 } } do
			K(p[1], p[2], p[3], p[4])
		end
		cont("crate", "Pallet of parts", 44, -30, 0)
		cont("crate", "Pallet of parts", -20, 30, 0)
		cont("crate", "Pallet of parts", 10, 30, 90)
		cont("weaponbox", "Ammunition crate", 22, -16, 0)
		cont("toolbox", "Mechanic's chest", -62, 1.8, FACE.w) -- clear of the workbench (v -8 to 0)
		cont("locker", "Locker", iw - 1, -4, FACE.e)
		cont("locker", "Locker", iw - 1, -8, FACE.e)
		cont("medbag", "Medical bag", -62, 22, 0)
		for _, s in { { "junk", 0.5, -35, -33, 6.3 }, { "junk", 0.45, -15, -33, 6.3 }, { "junk", 0.4, 40, -18, 0.3 }, { "junk", 0.45, -30, 22, 0.3 }, { "junk", 0.4, 28, 4, 0.3 },
			{ "junk", 0.4, 58, 24, 0.3 }, { "tech", 0.3, -62, 6, 3.5 }, { "junk", 0.4, 30, -26, 0.3 }, { "junk", 0.4, -44, -4, DECK + 3.2 }, { "junk", 0.4, 6, -4, DECK + 0.1 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
	end

	-- ── walls round a rectilinear footprint (L-shaped halls): corner points { u, v } in order ────────────────
	local function polyInfo(pts, i)
		local n = #pts
		local area = 0
		for k = 1, n do
			local p, q = pts[k], pts[k % n + 1]
			area += p[1] * q[2] - q[1] * p[2]
		end
		local sgn = area > 0 and 1 or -1
		local a, b, c = pts[i], pts[i % n + 1], pts[(i - 2) % n + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / len, dz / len
		local cross = (a[1] - c[1]) * dz - (a[2] - c[2]) * dx
		return { a = a, b = b, ux = ux, uz = uz, nx = -uz * sgn, nz = ux * sgn, len = len, reflex = (sgn * cross < 0) }
	end
	-- walls flush with the outline (inside it), t thick, foot y0, height h; holes[i] = openings of the edge from point i
	-- to point i + 1 ({ s, width, bottom, top }, s from point i)
	local function outlineWalls(p, pts, y0, h, t, col, mat, holes)
		for i = 1, #pts do
			local e = polyInfo(pts, i)
			local ext = e.reflex and t or 0
			local hs = {}
			for _, hh in (holes and holes[i]) or {} do
				table.insert(hs, { hh[1] + ext, hh[2], hh[3], hh[4] })
			end
			wl(p, e.a[1] + e.nx * t / 2 - e.ux * ext, e.a[2] + e.nz * t / 2 - e.uz * ext, e.b[1] + e.nx * t / 2, e.b[2] + e.nz * t / 2, y0, h, t, col, mat, hs)
		end
	end
	-- a point s along the wall of edge i on its centreline, the inward normal, the door swing and the outward yaw
	local function edgeAt(pts, i, s, t)
		local e = polyInfo(pts, i)
		local swing = "+v"
		if math.abs(e.nx) > math.abs(e.nz) then
			swing = (e.nx > 0) and "+u" or "-u"
		else
			swing = (e.nz > 0) and "+v" or "-v"
		end
		return e.a[1] + e.ux * s + e.nx * t / 2, e.a[2] + e.uz * s + e.nz * t / 2, swing, math.deg(math.atan2(e.nx, e.nz)), e
	end
	-- a hinged door in edge i at s
	local function edgeDoor(pts, i, s, t, y0, key, id, label)
		local u, v, swing = edgeAt(pts, i, s, t)
		return door(id or doorId(), label or "Door", u, v, swing, 4.0, 7.4, y0, key, key and REDP or hex("5A5F57"))
	end
	-- a kit prop standing in a gate of edge i, facing out
	local function edgeProp(pts, i, s, t, name, y, shift)
		local u, v, _, yaw, e = edgeAt(pts, i, s, t)
		return K(name, u - e.nx * (shift or 0), v - e.nz * (shift or 0), yaw, y)
	end
	-- window openings along a hole list, skipping the ones that would touch an opening already there
	local function addWindows(list, from, to, step, w, bottom, top)
		local s = from
		while s <= to + 0.01 do
			local free = true
			for _, e in list do
				if math.abs(e[1] - s) < e[2] / 2 + w / 2 + 1 then
					free = false
				end
			end
			if free then
				table.insert(list, { s, w, bottom, top })
			end
			s += step
		end
	end

	-- ═══ STORE 17 (id 31): the big L-shaped hall, a gate bay in the notch, a mezzanine and a gallery ══════════
	local function store17()
		local b = byId[31]
		site(b, "STORE 17", "BW_S17", nil, 44)
		wallFinish("ZR_BrickWall")
		local pts = { { 76.4, -74.4 }, { 75.7, 51.4 }, { -11.1, 51.6 }, { -10.9, 74.3 }, { -76.4, 74.5 }, { -76.1, -25.7 }, { 38.5, -24.6 }, { 38.7, -74.4 } }
		local R1 = { u0 = -76.2, u1 = 76, v0 = -25.2, v1 = 51.5 } -- the main body
		local R2 = { u0 = -76.4, u1 = -11, v0 = 51.5, v1 = 74.4 } -- south-west wing
		local R3 = { u0 = 38.6, u1 = 76.4, v0 = -74.4, v1 = -25.2 } -- north-east wing (the docks)
		local WH, T = 32, 1.4
		local D1, D2 = 12.8, 24.8
		for _, r in { R1, R2, R3 } do
			slab(bm, r.u0, r.u1, r.v0, r.v1, FY, 1.0, FLR, M.Concrete)
			slab(bm, r.u0, r.u1, r.v0, r.v1, WH + 0.8, 0.8, ROOF, M.Concrete)
		end
		-- openings per edge
		local holes = { {}, {}, {}, {}, {}, {}, {}, {} }
		-- the door by the east gate stands at 119.2: at 118 its opening overlapped the gate's (103.5 to 116.5) and was dropped,
		-- leaving the door in a solid wall (placement audit, 2026-11-01)
		holes[1] = { { 30, 13, 0, 10.4 }, { 75, 13, 0, 10.4 }, { 110, 13, 0, 10.4 }, { 10, 4.2, 0, 7.9 }, { 119.2, 4.2, 0, 7.9 } }
		holes[2] = { { 25, 13, 0, 10.4 }, { 60, 4.2, 0, 7.9 } }
		holes[3] = { { 11, 4.2, 0, 7.9 } }
		holes[4] = { { 32, 13, 0, 10.4 }, { 8, 4.2, 0, 7.9 } }
		holes[5] = { { 50, 13, 0, 10.4 }, { 20, 4.2, 0, 7.9 }, { 80, 4.2, 0, 7.9 } }
		holes[6] = { { 79.4, 16, 0, 14.5 }, { 20, 4.2, 0, 7.9 }, { 105, 4.2, 0, 7.9 } } -- the gate bay at u 3.3
		holes[7] = { { 25, 4.2, 0, 7.9 } }
		holes[8] = { { 9, 13.6, 0, 13.4 }, { 28, 13.6, 0, 13.4 } }
		for _, i in { 1, 4, 5, 6 } do
			addWindows(holes[i], 14, polyInfo(pts, i).len - 8, 15, 7, 21, 28)
		end
		outlineWalls(bm, pts, 0, WH, T, PAN, M.Concrete, holes)
		outlineWalls(bm, pts, WH + 0.8, 3.2, 0.8, PAN, M.Concrete, nil) -- the roof parapet
		for _, a in { { 1, 10 }, { 1, 119.2 }, { 2, 60 }, { 3, 11 }, { 4, 8 }, { 5, 20 }, { 5, 80 }, { 6, 20 }, { 6, 105 }, { 7, 25 } } do
			edgeDoor(pts, a[1], a[2], T, FY)
		end
		for _, a in { { 1, 30, "RollerDoor" }, { 4, 32, "RollerDoor" }, { 8, 9, "DockDoor" }, { 8, 28, "DockDoor" } } do
			edgeProp(pts, a[1], a[2], T, a[3], FY)
		end
		-- the gate bay: a canopy, the apron over the notch, bollards and a painted lane
		do
			local gu, gv = 3.3, -25.2
			ab(bm, gu - 14, gu + 14, -0.35, 0.15, gv - 22, gv - 0.2, hex("6A6C66"), M.Concrete)
			for _, sx in { -1, 1 } do
				for _, bz in { -5, -14 } do
					ab(bm, gu + sx * 11 - 0.4, gu + sx * 11 + 0.4, 0, 3.4, gv + bz - 0.4, gv + bz + 0.4, hex("C9A227"), M.Metal)
				end
				colm(bm, gu + sx * 9, gv - 8, 0.15, 15.5, 1.1, STL, M.Metal)
			end
			ab(bm, gu - 10.5, gu + 10.5, 15.5, 16.1, gv - 8.6, gv - 0.2, STL2, M.Metal)
			ab(bm, gu - 0.3, gu + 0.3, 0.15, 0.2, gv - 22, gv - 0.2, YEL, M.SmoothPlastic)
		end
		-- columns
		for _, c in { { -57, 0 }, { -19, 0 }, { 19, 0 }, { 57, 0 }, { -57, 30 }, { -19, 30 }, { 19, 30 }, { 57, 30 }, { -45, 62 }, { -25, 62 }, { 57, -50 } } do
			if not reserved(c[1], c[2], 1.5) then
				colm(bm, c[1], c[2], FY, WH - 2, 2.4, PAN2, M.Concrete)
			end
		end
		-- the mezzanine D1 over the west part and the gallery D2 on its north-west corner
		local M1 = { u0 = -74.7, u1 = -22, v0 = -24.2, v1 = 28 }
		local M2 = { u0 = -74.7, u1 = -49, v0 = -24.2, v1 = -3 }
		slab(bm, M1.u0, M1.u1, M1.v0, M1.v1, D1, 0.8, FLR2, M.Concrete)
		slab(bm, M2.u0, M2.u1, M2.v0, M2.v1, D2, 0.8, FLR2, M.Concrete)
		for _, c in { { -73.5, 26.8 }, { -23.2, 26.8 }, { -23.2, -22.9 }, { -48, 26.8 }, { -48, -22.9 } } do
			colm(bm, c[1], c[2], FY, D1 - 0.8, 1.8, PAN2, M.Concrete)
		end
		for _, c in { { -50.2, -4.2 }, { -50.2, -22.9 }, { -73.5, -4.2 } } do
			colm(bm, c[1], c[2], D1, D2 - 0.8, 1.6, PAN2, M.Concrete)
		end
		stairs(bm, -2, 0, FY, D1 - FY, 20 / (D1 - FY), 5, "-u", FY - 0.2, PAN2, M.Concrete, true)
		stairs(bm, -30, -13.5, D1, D2 - D1, 19 / (D2 - D1), 4.5, "-u", D1 - 0.2, PAN2, M.Concrete, true)
		railRect(bm, M1.u0, M1.u1, M1.v0, M1.v1, D1, { { "w", -1000, 1000 }, { "n", -1000, 1000 }, { "e", -2.5, 2.5 }, { "s", -1000, -50 } })
		railRect(bm, M2.u0, M2.u1, M2.v0, M2.v1, D2, { { "w", -1000, 1000 }, { "n", -1000, 1000 }, { "e", -15.75, -11.25 } })
		-- the foreman's office on the mezzanine
		room({
			u0 = -74.7, u1 = -50, v0 = 6, v1 = 28, y0 = D1, h = 9, ceil = true, skip = { w = true }, finish = "ZR_WoodPanel",
			doors = { n = { { s = 14, id = "BW_S17_OFFICE" } } }, windows = { e = { { 11, 5, 3.5, 6.5 } } },
		})
		desk(-66, 14, 90, D1)
		K("Chair", -63, 14, FACE.w, D1)
		K("Lockers", -66, 27, FACE.s, D1)
		lamp(-62, D1 + 9.4, 17, 20, 0.8, nil, WARM, 3.2)
		cont("drawer", "Foreman's desk", -66, 14, 90, D1)
		cont("safe", "Foreman's safe", -72, 8, FACE.w, D1)
		cont("techbox", "Radio crate", -56, 26.6, FACE.s, D1)
		cont("crate", "Stock crate", -40, 12, 0, D1)
		cont("weaponbox", "Ammunition crate", -30, 22, 90, D1)
		point("BY_STORE17", -60, D1, 20) -- a task's quest item: the foreman's office floor (standing height, as every point)
		K("RollCage", -32, 4, 20, D1)
		cont("toolbox", "Gallery chest", -72, -20, FACE.w, D2)
		cont("medbag", "First aid bag", -67, -23.6, FACE.n, D2 + 3) -- on the wall beside the rack, not inside it
		cont("crate", "Gallery crate", -64, -12, 0, D2)
		K("StorageRack", -60, -23, FACE.n, D2)
		for _, s in { { "vault", 0.5, -70, 12, D1 + 0.1 }, { "junk", 0.45, -50, 20, D1 + 0.1 }, { "junk", 0.4, -64, -10, D2 + 0.1 }, { "junk", 0.4, -54, -15, D2 + 0.1 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
		-- the main hall: racks, cages, pallets, forklifts, the loading floor
		rackRow(2, 30, 3, 0)
		rackRow(2, 36, 3, 180)
		rackRow(2, 4, 3, 0)
		rackRow(2, 10, 3, 180)
		for _, p in { { "Forklift", -14, 40, 100 }, { "Forklift", 30, -12, 200 }, { "RollCage", -4, -10, 20 }, { "RollCage", 0, -14, -10 }, { "RollCage", 6, -8, 0 }, { "PalletBoxes", 40, -16, 0 },
			{ "PalletBoxes", 46, -14, 10 }, { "PalletBoxes", 52, -18, -20 }, { "CardboardPile", 60, -10, 0 }, { "Drum", 70, 8, 0 }, { "Drum", 68, 6, 0 }, { "Drum", 70, 4, 0 }, { "JerryCans", 66, 14, 30 },
			{ "TyreStack", -62, 40, 0 }, { "TyreStack", -58, 46, 30 }, { "CraftBench", -72, 60, FACE.w }, { "ToolChest", -71, 66, FACE.w }, { "HideoutGenerator", -50, 70, FACE.s },
			{ "ElectricCabinet", -33, 72.6, FACE.s }, { "PalletBoxes", 60, -60, 0 }, { "PalletBoxes", 64, -66, 20 } } do
			K(p[1], p[2], p[3], p[4])
		end
		cont("crate", "Pallet of parts", 40, -16, 0)
		cont("crate", "Pallet of parts", 60, -60, 0)
		cont("crate", "Pallet of parts", -14, 20, 0)
		cont("weaponbox", "Ammunition crate", 52, 30, 0)
		cont("toolbox", "Mechanic's chest", -68, 60, FACE.w)
		cont("toolbox", "Loader's chest", 70, -40, FACE.e)
		cont("locker", "Locker", -73, 46, FACE.w)
		cont("locker", "Locker", -73, 50, FACE.w)
		cont("medbag", "Medical bag", 72, 20, 0)
		cont("drawer", "Dispatcher's desk", 56, -40, 90)
		for i, u in { -57, -19, 19, 57 } do
			lamp(u, WH - 4, 12, (i % 3 == 0) and 0 or 38, 0.9, nil, COLD, 4.4)
			lamp(u, WH - 4, 38, (i % 2 == 0) and 0 or 38, 0.9, nil, COLD, 4.4)
		end
		lamp(58, WH - 4, -50, 34, 0.9, nil, COLD, 4.4)
		lamp(-45, WH - 4, 62, 30, 0.9, nil, COLD, 4.4)
		for _, s in { { "junk", 0.5, -40, 40, 0.3 }, { "junk", 0.45, 20, 20, 0.3 }, { "junk", 0.45, 50, 30, 0.3 }, { "junk", 0.4, 56, -30, 0.3 }, { "junk", 0.4, 68, -62, 0.3 },
			{ "junk", 0.4, -30, 64, 0.3 }, { "tech", 0.3, -70, 66, 3.5 }, { "junk", 0.4, 10, -16, 0.3 }, { "junk", 0.4, 30, 46, 0.3 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
	end

	-- ═══ THE DEPOT (id 21): the tall L-shaped factory hall with an overhead crane, roof perch and a stair tower ═
	local function depot()
		local b = byId[21]
		site(b, "THE DEPOT", "BW_DEP", nil, 36)
		local pts = { { 75.8, -64.2 }, { 22, -64.1 }, { 22.1, -57.6 }, { -76.9, -57.4 }, { -76.8, 41.2 }, { -58.8, 41.3 }, { -58.7, 64.1 }, { 76.3, 64.1 } }
		local R1 = { u0 = -76.8, u1 = 22, v0 = -57.5, v1 = 41.2 }
		local R2 = { u0 = 22, u1 = 76.2, v0 = -64.1, v1 = 64.1 }
		local R3 = { u0 = -58.7, u1 = 22, v0 = 41.2, v1 = 64.1 }
		local T = 1.6
		local WH = 41.4 -- wall height: the roof deck is at 42.2
		local ROOFY = 42.2
		for _, r in { R1, R2, R3 } do
			slab(bm, r.u0, r.u1, r.v0, r.v1, FY, 1.0, FLR, M.Concrete)
			slab(bm, r.u0, r.u1, r.v0, r.v1, ROOFY, 0.8, ROOF, M.Concrete)
		end
		local holes = { {}, {}, {}, {}, {}, {}, {}, {} }
		holes[1] = { { 27, 16, 0, 14 } }
		holes[3] = { { 25, 16, 0, 14 }, { 70, 4.2, 0, 7.9 } }
		holes[4] = { { 50, 16, 0, 14 }, { 15, 4.2, 0, 7.9 }, { 85, 4.2, 0, 7.9 } }
		holes[5] = { { 9, 4.2, 0, 7.9 } }
		holes[6] = { { 11, 4.2, 0, 7.9 } }
		holes[7] = { { 22, 16, 0, 14 }, { 70, 4.2, 0, 7.9 }, { 125, 4.2, 0, 7.9 } }
		holes[8] = { { 28, 16, 0, 14 }, { 64, 4.2, 0, 7.9 }, { 100, 16, 0, 14 } }
		for _, i in { 1, 3, 4, 7, 8 } do
			addWindows(holes[i], 12, polyInfo(pts, i).len - 8, 13, 6, 28, 37)
		end
		-- the roof: parapet round the outline with a gap where the stair tower reaches it (edge 7 at s 96.7)
		local phole = { {}, {}, {}, {}, {}, {}, { { 96.7, 5, 0, 3.4 } }, {} }
		outlineWalls(bm, pts, 0, WH, T, PAN, M.Concrete, holes)
		outlineWalls(bm, pts, ROOFY, 3.4, 0.8, PAN, M.Concrete, phole)
		for _, a in { { 3, 70 }, { 4, 15 }, { 4, 85 }, { 5, 9 }, { 6, 11 }, { 7, 70 }, { 7, 125 }, { 8, 64 } } do
			edgeDoor(pts, a[1], a[2], T, FY)
		end
		for _, a in { { 7, 22, "RollerDoor" }, { 8, 28, "RollerDoor" } } do
			edgeProp(pts, a[1], a[2], T, a[3], FY)
		end
		-- columns, crane runways and the crane
		for _, cu in { -51, -25, 0 } do
			for _, cv in { -30, 10 } do
				colm(bm, cu, cv, FY, 34, 2.6, PAN2, M.Concrete)
			end
		end
		for _, c in { { 50, -30 }, { 50, 30 }, { -30, 52 }, { 0, 52 } } do
			colm(bm, c[1], c[2], FY, 38, 2.6, PAN2, M.Concrete)
		end
		for _, cv in { -30, 10 } do
			ab(bm, -57, 7, 33.4, 35.2, cv - 0.9, cv + 0.9, STL, M.Metal)
			ab(bm, -57, 7, 35.2, 35.6, cv - 0.3, cv + 0.3, STL2, M.Metal)
		end
		ab(bm, -21, -19, 33.6, 35.4, -30, 10, STL, M.Metal)
		bc(bm, 3.6, 2.4, 3.6, -20, 31.4, -8, hex("C9A227"), M.Metal, 0)
		bc(bm, 0.5, 8, 0.5, -20, 27, -8, STL, M.Metal, 0)
		-- the inspectors' office against the west wall, then racks and the cargo lift
		room({
			u0 = -75.2, u1 = -58, v0 = -36, v1 = -14, y0 = FY, h = 10, ceil = true, skip = { w = true }, finish = "ZR_WallpaperB",
			doors = { e = { { s = 11, id = "BW_DEP_OFFICE" } } }, windows = { n = { { 9, 5, 3.5, 6.5 } }, s = { { 9, 5, 3.5, 6.5 } } },
		})
		desk(-68, -29, 0)
		K("Chair", -68, -26, 180)
		K("Lockers", -74, -17, FACE.w)
		K("Whiteboard", -66, -35.6, FACE.n, FY + 2.6)
		lamp(-67, 9.4, -25, 20, 0.8, nil, WARM, 3.2)
		cont("drawer", "Inspector's desk", -68, -29, 0)
		cont("safe", "Depot safe", -73.5, -30, FACE.w)
		cont("techbox", "Radio crate", -60, -34.4, FACE.n)
		rackRow(-45, -50, 3, 180)
		rackRow(-45, -45.4, 3, 0)
		rackRow(-45, 28, 3, FACE.s)
		for _, p in { { "CargoLift", 60, -40, 90 }, { "Forklift", 40, 20, 150 }, { "Forklift", -10, -8, 20 }, { "RollCage", 30, -6, 0 }, { "RollCage", 33, -2, 30 }, { "PalletBoxes", 44, -50, 0 },
			{ "PalletBoxes", 50, -54, 20 }, { "PalletBoxes", 70, 40, 0 }, { "PalletBoxes", 66, 50, 10 }, { "CardboardPile", 58, 56, 0 }, { "Drum", 72, -10, 0 }, { "Drum", 70, -12, 0 },
			{ "Drum", 72, -14, 0 }, { "TyreStack", -30, 56, 0 }, { "CraftBench", -56, 58, FACE.s }, { "ToolChest", -48, 61.5, FACE.s }, { "HideoutGenerator", -20, 61, FACE.s },
			{ "WaterTank", 10, 60, FACE.s }, { "PalletBoxes", 4, -50, 0 } } do
			K(p[1], p[2], p[3], p[4])
		end
		cont("crate", "Pallet of parts", 44, -50, 0)
		cont("crate", "Pallet of parts", 70, 40, 0)
		cont("crate", "Pallet of parts", 4, -50, 0)
		cont("weaponbox", "Ammunition crate", 36, -20, 0)
		cont("toolbox", "Mechanic's chest", -52, 61.5, FACE.s)
		cont("toolbox", "Rigger's chest", 74, -30, FACE.e)
		cont("locker", "Locker", 74, 20, FACE.e)
		cont("locker", "Locker", 74, 24, FACE.e)
		cont("medbag", "Medical bag", -10, 62, FACE.s)
		for i, p in { { -57, -10 }, { -30, -10 }, { 0, -10 }, { -40, 20 }, { 50, -40 }, { 50, 10 }, { 50, 50 }, { -30, 52 } } do
			lamp(p[1], 38, p[2], (i % 3 == 0) and 0 or 40, 0.9, nil, COLD, 4.4)
		end
		for _, s in { { "junk", 0.5, -35, -40, 0.3 }, { "junk", 0.45, -10, 10, 0.3 }, { "junk", 0.45, 20, -20, 0.3 }, { "junk", 0.4, 56, 20, 0.3 }, { "junk", 0.4, 40, -56, 0.3 },
			{ "junk", 0.4, -40, 58, 0.3 }, { "tech", 0.3, -50, 61, 3.5 }, { "junk", 0.4, 10, 40, 0.3 }, { "junk", 0.4, -62, -32, 3.5 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
		-- the roof: ventilation boxes and pipes; the sniper perch (14, -5) stays clear
		K("HVAC", 40, 40, 0, ROOFY, { shadows = true })
		K("HVAC", -40, 20, 90, ROOFY, { shadows = true })
		K("PipeRun", -60, -50, 0, ROOFY, { shadows = true })
		K("PipeRun", -44, -50, 0, ROOFY, { shadows = true })
		-- the stair tower on the south wall (u 36..60): four flights up to the roof, out through a gap in the parapet
		do
			local tu0, tu1, tv0, tv1 = 36, 60, 64.1, 76.4
			local top = ROOFY + 8
			local rise = (ROOFY - FY) / 4
			ab(bm, tu0, tu1, -0.6, FY, tv0, tv1, FLR, M.Concrete)
			wl(bm, tu0 + 0.5, tv0, tu0 + 0.5, tv1, FY, top, 1.0, PAN, M.Concrete, { { 3.6, 4.2, 0, 7.9 }, { 8.5, 1.4, 14, 19 }, { 8.5, 1.4, 30, 35 } })
			wl(bm, tu1 - 0.5, tv0, tu1 - 0.5, tv1, FY, top, 1.0, PAN, M.Concrete, { { 3, 1.4, 14, 19 }, { 9, 1.4, 14, 19 }, { 3, 1.4, 30, 35 }, { 9, 1.4, 30, 35 } })
			wl(bm, tu0 + 1, tv1 - 0.5, tu1 - 1, tv1 - 0.5, FY, top, 1.0, PAN, M.Concrete, { { 6, 1.4, 8, 13 }, { 18, 1.4, 8, 13 }, { 6, 1.4, 24, 29 }, { 18, 1.4, 24, 29 }, { 12, 1.4, 38, 43 } })
			local y = FY
			for k = 1, 4 do
				local up = (k % 2 == 1)
				stairs(bm, up and 39 or 57, up and 67.7 or 72.7, y, rise, 18 / rise, 5, up and "+u" or "-u", y - 0.2, PAN2, M.Concrete)
				y += rise
				if up then
					ab(bm, 57, tu1 - 1, y - 0.8, y, tv0, tv1 - 1, FLR2, M.Concrete)
				else
					ab(bm, tu0 + 1, 39, y - 0.8, y, tv0, tv1 - 1, FLR2, M.Concrete)
				end
			end
			ab(bm, tu0, tu1, top, top + 0.8, tv0, tv1, ROOF, M.Concrete)
			lamp(48, 30, 70, 18, 0.8, nil, WARM, 2.4)
			lamp(48, 12, 70, 18, 0.8, nil, WARM, 2.4)
			door("BW_DEP_TOWER", "Roof stairs", tu0 + 0.5, 67.7, "+u", 4.0, 7.4, FY, nil, hex("4D534E"))
			point("DEPOT_ROOF", 14, ROOFY, -5)
		end
	end

	-- ── furniture built from parts: the kit-prop budget goes to loot containers and the big machines ─────────
	local WOOD, WOOD2 = hex("6B5338"), hex("4B3A29")
	local CLOTH, CLOTH2 = hex("56604A"), hex("6A5A4A")
	-- a box that the detail layer leaves alone
	local function fb(p, u0, u1, y0, y1, v0, v1, col, mat)
		local part = ab(p, u0, u1, y0, y1, v0, v1, col, mat)
		if part then
			part:SetAttribute("NoDetail", true)
		end
		return part
	end
	-- a table: top over u0..u1, v0..v1 on four legs
	local function tableP(u0, u1, v0, v1, y, hgt, col)
		hgt = hgt or 2.8
		fb(pm, u0, u1, y + hgt - 0.3, y + hgt, v0, v1, col or WOOD, M.WoodPlanks)
		for _, cu in { u0 + 0.25, u1 - 0.25 } do
			for _, cv in { v0 + 0.25, v1 - 0.25 } do
				fb(pm, cu - 0.15, cu + 0.15, y, y + hgt - 0.3, cv - 0.15, cv + 0.15, WOOD2, M.WoodPlanks)
			end
		end
	end
	-- a bench along u (alongU) or v
	local function benchP(u, v, len, y, alongU)
		local a, b = len / 2, 0.7
		if not alongU then
			a, b = b, a
		end
		fb(pm, u - a, u + a, y + 1.5, y + 1.8, v - b, v + b, WOOD, M.WoodPlanks)
		for _, s in { -1, 1 } do
			if alongU then
				fb(pm, u + s * (a - 0.4) - 0.15, u + s * (a - 0.4) + 0.15, y, y + 1.5, v - b + 0.1, v + b - 0.1, WOOD2, M.WoodPlanks)
			else
				fb(pm, u - a + 0.1, u + a - 0.1, y, y + 1.5, v + s * (b - 0.4) - 0.15, v + s * (b - 0.4) + 0.15, WOOD2, M.WoodPlanks)
			end
		end
	end
	-- a bunk bed 6.4 x 3.2 (long side along u when alongU)
	local function bunkP(u, v, y, alongU, col)
		local a, b = 3.2, 1.6
		if not alongU then
			a, b = b, a
		end
		for _, cu in { u - a + 0.15, u + a - 0.15 } do
			for _, cv in { v - b + 0.15, v + b - 0.15 } do
				fb(pm, cu - 0.15, cu + 0.15, y, y + 5.6, cv - 0.15, cv + 0.15, STL, M.Metal)
			end
		end
		for _, h in { 1.5, 3.7 } do
			fb(pm, u - a + 0.1, u + a - 0.1, y + h, y + h + 0.3, v - b + 0.1, v + b - 0.1, STL, M.Metal)
			fb(pm, u - a + 0.25, u + a - 0.25, y + h + 0.3, y + h + 0.7, v - b + 0.25, v + b - 0.25, col or CLOTH, M.Fabric)
		end
	end
	-- a cot: low frame and a mattress
	local function cotP(u, v, y, alongU, col)
		local a, b = 3.1, 1.3
		if not alongU then
			a, b = b, a
		end
		fb(pm, u - a, u + a, y + 1.1, y + 1.4, v - b, v + b, STL, M.Metal)
		fb(pm, u - a + 0.1, u + a - 0.1, y + 1.4, y + 1.8, v - b + 0.1, v + b - 0.1, col or CLOTH2, M.Fabric)
		for _, cu in { u - a + 0.2, u + a - 0.2 } do
			for _, cv in { v - b + 0.2, v + b - 0.2 } do
				fb(pm, cu - 0.12, cu + 0.12, y, y + 1.1, cv - 0.12, cv + 0.12, STL, M.Metal)
			end
		end
	end
	-- a steel shelf unit against a wall: w along the wall (along u when alongU), 2 deep
	local function shelfP(u, v, w, y, alongU)
		local a, b = w / 2, 1.0
		if not alongU then
			a, b = b, a
		end
		for _, s in { -1, 1 } do
			for _, t in { -1, 1 } do
				fb(pm, u + s * (a - 0.15) - 0.12, u + s * (a - 0.15) + 0.12, y, y + 6.6, v + t * (b - 0.15) - 0.12, v + t * (b - 0.15) + 0.12, STL, M.Metal)
			end
		end
		for k = 0, 3 do
			fb(pm, u - a, u + a, y + 0.6 + k * 1.9, y + 0.8 + k * 1.9, v - b, v + b, STL2, M.Metal)
		end
		for k, off in { -0.55, 0.05, 0.6 } do
			local o = off * w / 2
			local bu, bv = alongU and o or 0, alongU and 0 or o
			local top = y + 0.8 + (k - 1) * 1.9
			fb(pm, u + bu - 0.6, u + bu + 0.6, top, top + 1.0, v + bv - 0.6, v + bv + 0.6, k == 3 and WOOD or hex("5C6657"), k == 3 and M.WoodPlanks or M.Metal)
		end
	end
	-- a wooden crate stack of n boxes at (u, v)
	local function crateP(u, v, y, n)
		for k = 1, n or 1 do
			local o = (k - 1) * 0.35
			fb(pm, u - 1.1 + o, u + 1.1 + o, y + (k - 1) * 2.0, y + k * 2.0, v - 1.0, v + 1.0, WOOD, M.WoodPlanks)
		end
	end
	-- a floor stripe set marking an area (hazard yellow) from u0..u1, v0..v1 at height y
	local function hazardBox(u0, u1, v0, v1, y)
		for _, s in { { u0, u1, v0, v0 + 0.5 }, { u0, u1, v1 - 0.5, v1 }, { u0, u0 + 0.5, v0, v1 }, { u1 - 0.5, u1, v0, v1 } } do
			local part = ab(pm, s[1], s[2], y, y + 0.05, s[3], s[4], YEL, M.SmoothPlastic)
			if part then
				part.CanCollide = false
				part.CastShadow = false
				part:SetAttribute("NoDetail", true)
			end
		end
	end
	-- a horizontal cylinder along u (yaw 90: along v), centre (u, y, v)
	local function hcyl(p, u, y, v, len, dia, col, mat, yaw)
		return kit.cyl(p, len, dia, cfAt(u, y, v, yaw), col, mat)
	end
	-- an upright cylinder standing on y0
	local function ucyl(p, u, y0, v, h, dia, col, mat)
		return kit.cyl(p, h, dia, cfAt(u, y0 + h / 2, v) * CFrame.Angles(0, 0, math.rad(90)), col, mat)
	end

	-- ═══ THE RED STORES (id 33): the long brick hall, a row of shuttered stores, and a wire cage upstairs (KEY_BY_RED) ═══
	local function redStores()
		local b = byId[33]
		site(b, "RED STORES", "BW_RED", nil, 36)
		local hw, hd = b[6] / 2, b[7] / 2
		local iw, id = hw - 1.6, hd - 1.6
		local DECK = 13
		local rise = DECK - FY
		shell({
			u0 = -hw, u1 = hw, v0 = -hd, v1 = hd, h = 22, t = 1.6, col = BRK, mat = M.Brick, roof = "gable", pitch = 6, roofCol = hex("6E3A2E"),
			gates = {
				n = { { s = 40, w = 13, h = 10.4 }, { s = 95, w = 13, h = 10.4, closed = "RollerDoor" }, { s = 150, w = 13, h = 10.4 } },
				w = { { s = 38, w = 13, h = 10.4 } },
				e = { { s = 38, w = 13, h = 10.4, closed = "RollerDoor" } },
			},
			doors = { n = { { s = 12 }, { s = 180 } }, s = { { s = 15 }, { s = 180 } }, w = { { s = 80 } }, e = { { s = 80 } } },
			windows = { n = { from = 20, to = 172, step = 14, w = 6, b = 13, top = 18 }, s = { from = 36, to = 160, step = 14, w = 6, b = 13, top = 18 } },
			cu = { -72, -48, -24, 0, 24, 48, 72 }, cv = { -16 },
			lampsU = { -70, -23, 23, 70 }, lampsV = { -22, 8 },
		})
		-- the store row along the south wall: ten bays of 12, shutters on the hall side
		local V0, V1 = 34, id
		local bays = {}
		for k = 0, 9 do
			table.insert(bays, { c = -54 + 12 * k, open = (k == 1 or k == 3 or k == 4 or k == 6 or k == 8 or k == 9) })
		end
		local fh = {}
		for _, bay in bays do
			table.insert(fh, { bay.c + 60, 10.4, 0, 8.8 })
		end
		wl(bm, -60, V0, 60, V0, FY, 11, 0.8, BRK2, M.Brick, fh)
		for k = 0, 10 do
			wl(bm, -60 + 12 * k, V0, -60 + 12 * k, V1, FY, 11, 0.6, BRK2, M.Brick, nil)
		end
		slab(bm, -60, 60, V0, V1, FY + 11, 0.5, ROOF, M.Concrete)
		for _, bay in bays do
			local sy0 = bay.open and (FY + 7.2) or FY
			local sh = ab(bm, bay.c - 5.2, bay.c + 5.2, sy0, FY + 8.6, V0 - 0.3, V0 + 0.3, hex("7A3B30"), M.CorrodedMetal)
			if sh then
				for r = 1, 6 do
					ab(bm, bay.c - 5.2, bay.c + 5.2, sy0 + r * (8.6 - (sy0 - FY)) / 7, sy0 + r * (8.6 - (sy0 - FY)) / 7 + 0.2, V0 - 0.45, V0 + 0.45, hex("5C2C23"), M.Metal)
				end
			end
			if bay.open then
				lamp(bay.c, FY + 10, 41, 14, 0.7, nil, WARM, 2.4)
			end
		end
		-- inside the open bays
		local fills = {
			[-42] = { { "StorageShelf", -45, 47.2, FACE.s }, { "StorageShelf", -39, 47.2, FACE.s } },
			[-18] = { { "DisplayTable", -18, 42, 0 }, { "Chair", -22, 45, 200 } },
			[-6] = { { "StorageRack", -6, 47.2, FACE.s }, { "ToolChest", -10, 44, FACE.s } },
			[18] = { { "Lockers", 18, 46.2, FACE.s }, { "FirstAid", 13, 42, 0 } },
			[42] = { { "CardboardPile", 42, 44, 20 }, { "PalletBoxes", 46, 42, 0 } },
			[54] = { { "StorageShelf", 52, 47.2, FACE.s }, { "Drum", 57, 44, 0 } },
		}
		for _, f in fills do
			for _, p in f do
				K(p[1], p[2], p[3], p[4])
			end
		end
		cont("crate", "Shop stock", -45, 44, 0)
		cont("crate", "Shop stock", -39, 44, 0)
		cont("drawer", "Till drawer", -18, 38, 90)
		cont("techbox", "Wireless set", -22, 46.6, FACE.s)
		cont("toolbox", "Shopkeeper's chest", -2, 44, FACE.s)
		cont("weaponbox", "Hidden crate", -10, 40, 0)
		cont("locker", "Locker", 22.5, 47.2, FACE.s) -- inside bay 18, beside its lockers (at u 24 it stood in the partition)
		cont("medbag", "First aid bag", 13, 42, 0, FY + 3)
		cont("crate", "Shop stock", 42, 44, 0)
		cont("safe", "Shop safe", 58, 46, FACE.s)
		for _, s in { { "junk", 0.5, -42, 42, 0.3 }, { "mall", 0.4, -18, 44, 3.2 }, { "junk", 0.45, -6, 44, 0.3 }, { "junk", 0.4, 18, 42, 0.3 }, { "junk", 0.45, 48, 44, 0.3 }, { "keys", 0.25, 56, 42, 0.3 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
		-- the hall: pallet stacks, vans, a forklift, cages
		for _, p in { { "Van", -70, -30, 90 }, { "Van", 30, -36, 80 }, { "Forklift", -6, -26, 20 }, { "PalletBoxes", 60, -34, 0 }, { "PalletBoxes", 66, -30, 15 }, { "PalletBoxes", 72, -36, -10 },
			{ "CardboardPile", 80, -20, 0 }, { "RollCage", 10, 20, 10 }, { "RollCage", 14, 24, -20 }, { "Drum", 84, 10, 0 }, { "Drum", 82, 8, 0 }, { "TyreStack", -86, 16, 0 },
			{ "PalletBoxes", 40, 6, 0 }, { "PalletBoxes", 46, 10, 20 }, { "CraftBench", -86, 6, FACE.w }, { "ToolChest", -85, -2, FACE.w } } do
			K(p[1], p[2], p[3], p[4])
		end
		cont("crate", "Pallet of goods", 60, -34, 0)
		cont("crate", "Pallet of goods", 40, 6, 0)
		cont("weaponbox", "Ammunition crate", 70, -12, 0)
		cont("toolbox", "Mechanic's chest", -84, 8, FACE.w)
		point("RED_STORES", 0, FY, 10)
		-- the office deck at the west end (level 2) with its wire cage
		local DK = { u0 = -iw, u1 = -24.85, v0 = -27.7, v1 = 6.7 }
		slab(bm, DK.u0, DK.u1, DK.v0, DK.v1, DECK, 0.8, FLR2, M.Concrete)
		for _, c in { { -92, -26 }, { -60, -26 }, { -26.5, -26 }, { -92, 5 }, { -60, 5 }, { -26.5, 5 }, { -76, -10.9 } } do
			colm(bm, c[1], c[2], FY, DECK - 0.8, 1.8, PAN2, M.Concrete)
		end
		stairs(bm, -4.5, -7, FY, rise, (-4.5 - DK.u1) / rise, 5, "-u", FY - 0.2, PAN2, M.Concrete, true)
		railRect(bm, DK.u0, DK.u1, DK.v0, DK.v1, DECK, { { "w", -1000, 1000 }, { "e", -9.5, -4.5 } })
		room({
			u0 = DK.u0 + 0.4, u1 = -68, v0 = DK.v0 + 0.4, v1 = -15, y0 = DECK, h = 9, ceil = true, finish = "ZR_WallpaperA",
			doors = { s = { { s = 12, id = "BW_RED_OFFICE1" } } }, windows = { e = { { 8, 5, 3.5, 6.5 } } },
		})
		room({
			u0 = -66, u1 = -44, v0 = DK.v0 + 0.4, v1 = -15, y0 = DECK, h = 9, ceil = true, finish = "ZR_WoodPanel",
			doors = { s = { { s = 10, id = "BW_RED_OFFICE2" } } }, windows = { n = { { 11, 5, 3.5, 6.5 } } },
		})
		desk(-82, -22, 0, DECK)
		K("Chair", -82, -19, 180, DECK)
		K("Lockers", -77.5, -25.6, FACE.n, DECK)
		desk(-56, -22, 0, DECK)
		K("Chair", -56, -19, 180, DECK)
		K("Whiteboard", -56, -27.2, FACE.n, DECK + 2.6)
		lamp(-80, DECK + 9.4, -22, 18, 0.7, nil, WARM, 3.2)
		lamp(-54, DECK + 9.4, -22, 18, 0.7, nil, WARM, 3.2)
		cont("drawer", "Manager's desk", -82, -22, 0, DECK)
		cont("safe", "Manager's safe", -92, -20, FACE.w, DECK)
		cont("techbox", "Radio crate", -46, -17, 0, DECK)
		cont("locker", "Locker", -iw + 1, 0, FACE.w, DECK)
		-- the wire cage of seized goods: u -76.55..-38.45, v -13.1..-8.7, one door in its east end (KEY_BY_RED)
		local C0, C1, CV0, CV1 = -76.55, -38.45, -13.1, -8.7
		fenceRun(bm, C0, CV0, C1, CV0, DECK, 8)
		fenceRun(bm, C0, CV1, C1, CV1, DECK, 8)
		fenceRun(bm, C0, CV0, C0, CV1, DECK, 8)
		fenceRun(bm, C1, CV0, C1, CV0 + 0.4, DECK, 8)
		fenceRun(bm, C1, CV1 - 0.4, C1, CV1, DECK, 8)
		ab(bm, C0, C1, DECK + 8, DECK + 8.3, CV0, CV1, hex("5B615D"), M.Metal)
		door("by_red", "Seized goods cage", C1, (CV0 + CV1) / 2, "-u", 3.6, 7.4, DECK, "KEY_BY_RED", hex("6C7A72"))
		lamp((C0 + C1) / 2, DECK + 7.4, (CV0 + CV1) / 2, 16, 0.7, nil, WARM, 3.2)
		for _, p in { { "PalletBoxes", -72, -10.9, 0 }, { "PalletBoxes", -62, -10.9, 20 }, { "CardboardPile", -50, -10.9, 0 }, { "RollCage", -43, -10.9, 90 } } do
			K(p[1], p[2], p[3], p[4], DECK)
		end
		cont("weaponbox", "Seized weapons", -68, -12.1, 0, DECK)
		cont("weaponbox", "Seized weapons", -58, -9.7, 180, DECK)
		point("BY_RED_CAGE", -46.6, DECK, -10.9) -- a task's quest item: inside the seized goods cage, between the cardboard and the roll cage
		cont("crate", "Seized goods", -72, -10.9, 0, DECK)
		cont("crate", "Seized goods", -62, -10.9, 0, DECK)
		cont("safe", "Evidence safe", -76, -10.9, 90, DECK)
		cont("techbox", "Seized electronics", -48, -12.1, 0, DECK)
		cont("jacket", "Seized clothing", -54, -9.5, 180, DECK)
		for _, s in { { "vault", 0.7, -70, -11, DECK + 0.1 }, { "vault", 0.6, -60, -11, DECK + 0.1 }, { "vault", 0.5, -52, -10, DECK + 0.1 }, { "keys", 0.4, -46, -11, DECK + 0.1 }, { "junk", 0.4, -84, -20, DECK + 3.2 } } do
			lt(s[1], s[2], s[3], s[4], s[5])
		end
	end

	-- ═══ THE BASTION (id 28): two storeys and a walkable roof over BUNKER K-13, a double-height drill hall in the north,
	-- a corridor with rooms on both sides, two dog-leg stair halls and the strongroom (KEY_BY_BASTION) ═══════════════
	-- the two K-13 flights as rectangles of the current frame: A (solid, climbing toward +v) and B (open treads, climbing
	-- toward -v); pit = the whole shaft. Each foot stops LANDING studs short of its pit's end, so you can step off and turn
	-- into the hall (B's foot used to run into the west wall between its rails: players were boxed in at the bottom)
	local LANDING = 4.5
	local function k13Flights()
		local a, c = pitRect(stairsEntry("ladder-19")), pitRect(stairsEntry("ladder-38"))
		return { u0 = a.u0 + 0.4, u1 = a.u0 + 5.6, v0 = a.v0 + LANDING, v1 = a.v1 - 0.1, pit = a },
			{ u0 = c.u0 + 0.3, u1 = c.u1 - 0.3, v0 = c.v0 + 0.1, v1 = c.v1 - LANDING, pit = c }
	end
	-- an opening list entry replaces whatever it overlaps
	local function put(list, e)
		for i = #list, 1, -1 do
			local o = list[i]
			if math.abs(o[1] - e[1]) < (o[2] + e[2]) / 2 + 0.8 then
				table.remove(list, i)
			end
		end
		table.insert(list, e)
	end

	local function bastion()
		local b = byId[28]
		site(b, "THE BASTION", "BW_BAS", nil, 34)
		wallFinish("ZR_Whitewash") -- the plaster inside is whitewash, never wallpaper
		local hw, hd = b[6] / 2, b[7] / 2
		local T = 1.6
		local iw, id = hw - T, hd - T
		local DECK, RF = 13.0, 25.8
		local fA, fB = k13Flights()
		local ROOMS = { { -62, -48 }, { -48, -20 }, { -20, 8 }, { 8, 38 }, { 38, 68 }, { 68, iw } }
		local XS = { -48, -20, 8, 38, 68 }
		local DN = { -55, -34, -6, 23, 53, 81.2 } -- the corridor doors of the north rooms
		local DS = { -55, -34, -6, 23, 60, 81.2 } -- ... of the south rooms
		-- the dog-leg stair halls: the lower flight climbs from the ground to the deck, the upper one comes back to the roof
		local RUN, LW = 2.1, 4.6
		local len1, len2 = RUN * (DECK - FY), RUN * (RF - DECK)
		local SA = { u1 = -44.5, u2 = -24.1, vFoot = -4.2 }
		SA.vFar = SA.vFoot - len1
		local SB = { u1 = 42.8, u2 = 49.3, vFoot = 34.0 }
		SB.vFar = SB.vFoot - len1
		local deckHoles, roofHoles = {}, {}
		for _, s in { SA, SB } do
			table.insert(deckHoles, { s.u1 - LW / 2 - 0.1, s.u1 + LW / 2 + 0.1, math.min(s.vFoot, s.vFar), math.max(s.vFoot, s.vFar) })
			table.insert(roofHoles, { s.u2 - LW / 2 - 0.1, s.u2 + LW / 2 + 0.1, math.min(s.vFoot, s.vFar), math.max(s.vFoot, s.vFar) })
		end
		-- floors: ground slab with the two shafts, the deck (not over the drill hall) and the roof
		local pitA, pitB = pitRect(stairsEntry("ladder-19"), 0.2), pitRect(stairsEntry("ladder-38"), 0.2)
		slab(bm, -hw, hw, -hd, hd, FY, 1.0, FLR, M.Concrete, { { pitA.u0, pitA.u1, pitA.v0, pitA.v1 }, { pitB.u0, pitB.u1, pitB.v0, pitB.v1 } })
		slab(bm, -62.4, hw, -hd, hd, DECK, 0.8, FLR2, M.Concrete, deckHoles)
		slab(bm, -hw, hw, -hd, hd, RF, 0.8, ROOF, M.Concrete, roofHoles)
		-- openings of the outer walls: ground floor (H0) and upper floor (H1); s measured from the wall's start
		local H0 = { n = {}, s = {}, w = {}, e = {} }
		local H1 = { n = {}, s = {}, w = {}, e = {} }
		for i, r in ROOMS do
			local c = (r[1] + r[2]) / 2 + hw
			if i ~= 6 then
				table.insert(H0.n, { c, 5, 4, 9 })
				table.insert(H1.n, { c, 5, 5, 10.5 })
			end
			table.insert(H0.s, { c, 5, 4, 9 })
			table.insert(H1.s, { c, 5, 5, 10.5 })
		end
		for _, uu in { -88, -78, -68 } do
			table.insert(H1.n, { uu + hw, 5, 4.5, 10.5 })
			table.insert(H1.s, { uu + hw, 5, 4.5, 10.5 })
		end
		put(H0.s, { -78 + hw, 13, 0, 10.4 }) -- the gate of the drill hall
		for _, uu in { -6, 23, 60 } do
			put(H0.s, { uu + hw, 4.2, 0, 7.9 })
		end
		for _, uu in { -6, 53 } do
			put(H0.n, { uu + hw, 4.2, 0, 7.9 })
		end
		put(H0.w, { hd, 4.2, 0, 7.9 })
		put(H0.e, { hd, 4.2, 0, 7.9 })
		rectWalls(bm, -hw, hw, -hd, hd, 0, DECK - 0.8, T, PAN, M.Concrete, H0)
		rectWalls(bm, -hw, hw, -hd, hd, DECK - 0.8, RF - DECK, T, PAN, M.Concrete, H1)
		rectWalls(bm, -hw, hw, -hd, hd, RF, 3.4, 0.8, PAN, M.Concrete, nil)
		local dc = hex("5A5F57")
		for _, uu in { -6, 23, 60 } do
			door("BW_BAS_W" .. math.floor(uu), "Door", uu, hd - T / 2, "-v", 4.0, 7.4, FY, nil, dc)
		end
		for _, uu in { -6, 53 } do
			door("BW_BAS_E" .. math.floor(uu), "Door", uu, -hd + T / 2, "+v", 4.0, 7.4, FY, nil, dc)
		end
		door("BW_BAS_ENDN", "Door", -hw + T / 2, 0, "+u", 4.0, 7.4, FY, nil, dc)
		door("BW_BAS_ENDS", "Door", hw - T / 2, 0, "-u", 4.0, 7.4, FY, nil, dc)
		-- the drill hall's east wall (full height) with three doorways; the hall is open to the roof
		local hallDoors = {}
		for _, vv in { -20, 0, 20 } do
			table.insert(hallDoors, { vv + id, 4.6, FY, FY + 7.9 })
		end
		wl(bm, -62, -id, -62, id, 0, RF - 0.8, 0.8, PLS, M.Plaster, hallDoors)
		for k, vv in { -20, 0, 20 } do
			door("BW_BAS_H" .. k, "Door", -62, vv, "-u", 4.2, 7.4, FY, nil, dc)
		end
		-- both storeys: corridor walls, cross walls, doors, lamps
		for lv = 0, 1 do
			local y0 = (lv == 0) and 0 or (DECK - 0.8)
			local hgt = (lv == 0) and (DECK - 0.8) or (RF - DECK)
			local fy = (lv == 0) and FY or DECK
			local hn, hs = {}, {}
			for i, r in ROOMS do
				table.insert(hn, { DN[i] + 62, 4.2, fy - y0, fy - y0 + 7.9 })
				table.insert(hs, { DS[i] + 62, 4.2, fy - y0, fy - y0 + 7.9 })
			end
			wl(bm, -62, -3, iw, -3, y0, hgt, 0.8, PLS, M.Plaster, hn)
			wl(bm, -62, 3, iw, 3, y0, hgt, 0.8, PLS, M.Plaster, hs)
			for _, x in XS do
				wl(bm, x, -id, x, -3, y0, hgt, 0.8, PLS, M.Plaster, nil)
				wl(bm, x, 3, x, id, y0, hgt, 0.8, PLS, M.Plaster, nil)
			end
			for i = 1, 6 do
				local strong = (lv == 0 and i == 6)
				local nid = lv == 0 and (strong and "by_bastion" or ("BW_BAS_N" .. i)) or ("BW_BAS_UN" .. i)
				door(nid, strong and "Strongroom" or "Door", DN[i], -3, "-v", 4.0, 7.4, fy, strong and "KEY_BY_BASTION" or nil, strong and REDP or dc)
				door((lv == 0 and "BW_BAS_S" or "BW_BAS_US") .. i, "Door", DS[i], 3, "+v", 4.0, 7.4, fy, nil, dc)
			end
			for k, lu in { -50, -20, 10, 40, 70 } do
				lamp(lu, fy + 10, 0, (k % 2 == 1) and 22 or 0, 0.8, nil, COLD, 4.4)
			end
			if lv == 0 then
				lamp(-78, DECK - 2, -14, 26, 0.9, nil, COLD, 4.4)
				lamp(-78, DECK - 2, 14, 26, 0.9, nil, COLD, 4.4)
			end
		end
		-- the drill hall: columns, roof trusses
		for _, c in { { -86, -18 }, { -86, 18 }, { -65, -18 }, { -65, 18 } } do
			if not reserved(c[1], c[2], 1.5) then
				colm(bm, c[1], c[2], FY, RF - 3.2, 2.0, PAN2, M.Concrete)
			end
		end
		for _, uu in { -88, -76, -64 } do
			ab(bm, uu - 0.5, uu + 0.5, RF - 3.2, RF - 0.8, -id, id, STL, M.Metal)
		end
		-- the stairs of the halls, and the rails round their openings
		for _, s in { SA, SB } do
			stairs(bm, s.u1, s.vFoot, FY, DECK - FY, len1 / (DECK - FY), LW, "-v", FY - 0.2, PAN2, M.Concrete, true)
			stairs(bm, s.u2, s.vFar, DECK, RF - DECK, len2 / (RF - DECK), LW, "+v", DECK - 0.2, PAN2, M.Concrete, true)
		end
		for k, _ in { SA, SB } do
			local d, r = deckHoles[k], roofHoles[k]
			railRect(bm, d[1], d[2], d[3], d[4], DECK, { { "n", -1000, 1000 } })
			railRect(bm, r[1], r[2], r[3], r[4], RF, { { "s", -1000, 1000 } })
		end
		railRect(bm, pitA.u0, pitA.u1, pitA.v0, pitA.v1, FY, { { "s", fA.u0, fA.u1 } })
		railRect(bm, pitB.u0, pitB.u1, pitB.v0, pitB.v1, FY, { { "n", fB.u0, fB.u1 } })
		for k, s in { SA, SB } do
			lamp(s.u1 + 3, DECK - 2, (s.vFoot + s.vFar) / 2, 20, 0.8, nil, WARM, 3)
			lamp(s.u2 + 2, RF - 2, (s.vFoot + s.vFar) / 2, k == 1 and 0 or 20, 0.8, nil, WARM, 3)
		end

		-- the yard: an apron in front of the gate, a guard booth, floodlights, a truck; outdoor props first
		ab(bm, -92, -58, -0.35, 0.15, hd, hd + 24, hex("6A6C66"), M.Concrete)
		K("Van", -62, hd + 14, 100, 0.15, { shadows = true })
		K("Sandbags", -70, hd + 7, 0, 0.15, { shadows = true })
		K("Sandbags", -52, hd + 7, 10, 0.15, { shadows = true })
		K("Drum", -90, hd + 8, 0, 0.15, { shadows = true })
		room({
			u0 = -56, u1 = -46, v0 = hd + 4, v1 = hd + 11, y0 = 0.15, h = 8.4, ceil = true, col = BRK, mat = M.Brick,
			doors = { w = { { s = 3.5, id = "BW_BAS_HUT" } } }, windows = { e = { { 3.5, 4, 3.5, 6.5 } }, s = { { 5, 4, 3.5, 6.5 } } },
		})
		tableP(-53, -49, hd + 5.5, hd + 7.5, 0.15, 2.6)
		lamp(-51, 7.6, hd + 7.5, 14, 0.7, nil, WARM, 2.4)
		for _, lu in { -88, -60 } do
			ab(bm, lu - 0.3, lu + 0.3, 0.15, 14, hd + 22.7, hd + 23.3, STL, M.Metal)
			local head = ab(bm, lu - 1.2, lu + 1.2, 14, 14.5, hd + 21, hd + 23.4, hex("D7D2BC"), M.Neon)
			if head then
				head.CastShadow = false
				head.CanCollide = false
				head:SetAttribute("NoDetail", true)
				kit.light(head, WARM, 40, 0.9, false)
			end
		end
		point("BASTION_YARD", -75, 0.15, hd + 12)

		-- the roof: a water tank and two vent boxes for cover, an aerial mast (the parapet is 3.4 high)
		K("WaterTank", -60, -14, 0, RF, { shadows = true })
		K("HVAC", 30, 18, 0, RF, { shadows = true })
		K("HVAC", 60, -20, 90, RF, { shadows = true })
		ab(bm, -0.3, 0.3, RF, RF + 14, 29.7, 30.3, STL, M.Metal)
		point("BASTION_TOP", 20, RF, 0)

		-- the drill hall
		K("Lockers", -93.2, -26, FACE.w)
		cont("locker", "Locker", -93.4, -20, FACE.w)
		cont("weaponbox", "Guard crate", -92, 22, FACE.w)
		cont("crate", "Supply crate", -88, -30, 0)
		cont("toolbox", "Guard chest", -84, 33, 0)
		tableP(-90, -83, -8, -4, FY, 2.8)
		benchP(-86.5, -11, 6, FY, true)
		benchP(-86.5, 1, 6, FY, true)
		K("Sandbags", -88, 28, 20)
		lt("junk", 0.5, -86, -6, 3.1)
		lt("junk", 0.45, -80, -30, FY)
		lt("junk", 0.45, -90, 14, FY)
		-- north rooms, ground floor: guard room, stair hall, armoury, barracks, mess, strongroom
		tableP(-59, -52, -32, -28, FY, 2.8)
		cont("drawer", "Guard desk", -55.5, -30, 0)
		cont("medbag", "Guard medkit", -50, -36.6, FACE.n, FY + 2.6)
		lt("junk", 0.45, -54, -30, 3.1)
		K("GunRack", -9, -36.4, FACE.n)
		K("GunRack", 2, -36.4, FACE.n)
		cont("weaponbox", "Armoury crate", -14, -30, 0)
		cont("weaponbox", "Armoury crate", -4, -26, 90)
		cont("weaponbox", "Armoury crate", 4, -30, 0)
		lt("vault", 0.5, -8, -28, FY)
		for k = 0, 2 do
			bunkP(14 + k * 8, -34, FY, false)
		end
		cont("locker", "Locker", 36.4, -20, FACE.e)
		cont("crate", "Footlocker", 22, -30, 0)
		lt("junk", 0.45, 24, -22, FY)
		tableP(44, 50, -30, -26, FY, 2.8)
		tableP(56, 62, -30, -26, FY, 2.8)
		benchP(47, -23, 6, FY, true)
		benchP(59, -23, 6, FY, true)
		cont("cooler", "Cooler", 66, -36, FACE.n)
		cont("grocery", "Larder", 40, -36.5, FACE.n)
		lt("junk", 0.45, 47, -28, 3.1)
		cont("safe", "Strongroom safe", 92.6, -33, FACE.e)
		cont("safe", "Strongroom safe", 92.6, -24, FACE.e)
		cont("weaponbox", "Strongroom crate", 80, -34, 0)
		cont("weaponbox", "Strongroom crate", 74, -30, 90)
		lt("vault", 0.7, 86, -20, FY)
		lt("vault", 0.6, 78, -28, FY)
		-- south rooms, ground floor: signals, stores, medical, workshop, generator room
		tableP(-60, -54, 30, 34, FY, 2.8)
		cont("techbox", "Radio set", -52, 36, FACE.s)
		lt("tech", 0.35, -57, 32, 3.1)
		shelfP(-34, 36.4, 8, FY, true)
		shelfP(-26, 36.4, 8, FY, true)
		cont("crate", "Store crate", -40, 31, 0)
		cont("toolbox", "Quartermaster's chest", -22, 30, 0)
		lt("junk", 0.45, -34, 30, FY)
		for k = 0, 2 do
			cotP(-17 + k * 8, 31, FY, false)
		end
		cont("pharmacy", "Medicine cabinet", -2, 36.4, FACE.s)
		cont("medbag", "Medical bag", -12, 24, 0)
		K("CraftBench", 14, 35.4, FACE.s)
		cont("toolbox", "Workshop chest", 28, 35, FACE.s)
		lt("junk", 0.45, 20, 32, FY)
		K("HideoutGenerator", 88, 33, FACE.s)
		K("ElectricCabinet", 93, 12, FACE.e)
		cont("techbox", "Switch cabinet", 74, 36, FACE.s)
		-- second floor, north: officers, stair hall, briefing room, barracks, dormitory, archive
		cotP(-56, -34, DECK, true)
		cont("drawer", "Officer's desk", -55, -28, 0, DECK)
		cont("locker", "Locker", -61, -20, FACE.w, DECK)
		tableP(-8, 2, -26, -20, DECK, 2.8)
		K("Whiteboard", -9, -36.6, FACE.n, DECK + 2.6)
		cont("drawer", "Briefing desk", -2, -23, 0, DECK)
		lt("office", 0.4, -3, -23, DECK + 3.1)
		for k = 0, 2 do
			bunkP(14 + k * 8, -34, DECK, false)
		end
		bunkP(44, -34, DECK, false)
		bunkP(52, -34, DECK, false)
		cont("crate", "Dormitory crate", 62, -30, 0, DECK)
		shelfP(72, -36.4, 8, DECK, true)
		shelfP(82, -36.4, 8, DECK, true)
		cont("crate", "Archive crate", 76, -28, 0, DECK)
		cont("crate", "Archive crate", 88, -30, 0, DECK)
		cont("drawer", "Archive cabinet", 92.6, -20, FACE.e, DECK)
		lt("junk", 0.4, 80, -26, DECK)
		-- second floor, south: officer, quartermaster, dormitory, radio room, lookout
		cotP(-56, 34, DECK, true)
		cont("safe", "Officer's safe", -61, 28, FACE.w, DECK)
		shelfP(-34, 36.4, 8, DECK, true)
		cont("crate", "Quartermaster's crate", -26, 30, 0, DECK)
		cont("toolbox", "Quartermaster's chest", -40, 31, 0, DECK)
		for k = 0, 2 do
			bunkP(-17 + k * 8, 34, DECK, false)
		end
		tableP(12, 18, 24, 28, DECK, 2.8)
		cont("techbox", "Radio set", 32, 36, FACE.s, DECK)
		cont("techbox", "Signals set", 24, 36, FACE.s, DECK)
		lt("tech", 0.35, 15, 26, DECK + 3.1)
		cont("jacket", "Lookout's coat", 72, 30, 0, DECK)
		cont("drawer", "Lookout's locker", 86, 30, 0, DECK)
		lt("junk", 0.4, 78, 26, DECK)
		lt("keys", 0.3, 52, -18, DECK)
	end

	-- BUNKER K-13 (L.under K13): below the Bastion, entered by two flights; a bulkhead with the hermetic exit door splits the
	-- hall; the exit waits for the power lever of STORE 4 (W.switches.BORDER_STORE4)
	local function bunkerK13()
		local un, b = UN.K13, byId[28]
		siteAt(un[4], un[5], b[8], 0, "BUNKER K-13", "BW_K13", UF, 24)
		local hw, hd = 31.7, 37.2
		local fA, fB = k13Flights()
		local room = { u0 = -hw, u1 = hw, v0 = -hd, v1 = hd }
		dugout({ room }, { fA.pit, fB.pit })
		local rise = 0.25 - UF
		stairs(bm, (fA.u0 + fA.u1) / 2, fA.v0, UF, rise, (fA.v1 - fA.v0) / rise, fA.u1 - fA.u0, "+v", UF - 0.5, PAN2, M.Concrete, true)
		stairs(bm, (fB.u0 + fB.u1) / 2, fB.v1, UF, rise, (fB.v1 - fB.v0) / rise, fB.u1 - fB.u0, "-v", nil, PAN2, M.Concrete, true)
		-- the bulkhead: the hermetic door in the middle, a side door at each end
		local BV = -10.5
		wl(bm, -hw, BV, hw, BV, UF, UC - UF, 1.4, PAN2, M.Concrete, { { hw, 6.6, 0, 8.4 }, { hw - 24, 4.4, 0, 7.9 }, { hw + 24, 4.4, 0, 7.9 } })
		door("BW_K13_HERMETIC", "Hermetic door", 0, BV, "-v", 6.4, 8.2, UF, nil, hex("3F4642"))
		door("BW_K13_SIDE1", "Bunker door", -24, BV, "-v", 4.2, 7.4, UF, nil, hex("4D534E"))
		door("BW_K13_SIDE2", "Bunker door", 24, BV, "-v", 4.2, 7.4, UF, nil, hex("4D534E"))
		point("K13_DOOR", 0, UF, BV + 3.5)
		-- the status lamp and the sign over the hermetic door (the lamp goes green when the lever is thrown)
		ab(bm, -3.4, 3.4, UF + 9.0, UF + 10.6, BV + 0.7, BV + 1.0, hex("2B302D"), M.Metal)
		local lampP = ab(bm, -0.8, 0.8, UF + 9.3, UF + 10.3, BV + 1.0, BV + 1.15, LAMP_OFF, M.SmoothPlastic)
		if lampP then
			table.insert(powered.panels, lampP)
		end
		local sign = ab(bm, -4.6, 4.6, UF + 11.0, UF + 13.2, BV + 0.7, BV + 1.0, hex("2F3A35"), M.Metal)
		if sign then
			kit.sign(sign, Enum.NormalId.Back, "EXIT  K-13", C.orange)
		end
		hazardBox(-8.5, 8.5, -8.5, 8.5, UF)
		-- lamps: emergency fittings stay lit, the rest come on with the power
		lamp(-hw + 3, UC - 0.6, 30, 14, 0.5, nil, hex("FFB070"), 2.4)
		lamp(0, UC - 0.6, BV + 3, 14, 0.5, nil, hex("FFB070"), 2.4)
		for _, p in { { -22, 30 }, { 22, 30 }, { -22, 14 }, { 22, 14 }, { -22, -2 }, { 22, -2 }, { -22, -24 }, { 22, -24 }, { 0, -24 }, { 0, 20 } } do
			lamp(p[1], UC - 0.6, p[2], 24, 0.8, powered.lights, WARM, 3.6)
		end
		for _, c in { { -14, 14 }, { 14, 14 }, { -14, 30 }, { 14, 30 }, { -14, -24 }, { 14, -24 } } do
			if not reserved(c[1], c[2], 1.5) then
				ab(bm, c[1] - 1.3, c[1] + 1.3, UF, UC, c[2] - 1.3, c[2] + 1.3, PAN2, M.Concrete)
			end
		end
		-- the shelter hall: bunks, benches, lockers, supplies
		for k = 0, 3 do
			bunkP(-27.5, 4 + k * 8, UF, false)
		end
		for k = 0, 1 do
			bunkP(27.5, 18 + k * 8, UF, false)
		end
		tableP(10, 18, 22, 26, UF, 2.8)
		benchP(14, 19, 7, UF, true)
		benchP(14, 29, 7, UF, true)
		cont("locker", "Locker", -30.6, 34, FACE.w, UF)
		cont("locker", "Locker", 30.6, 6, FACE.e, UF)
		cont("weaponbox", "Shelter crate", -20, 33, 0, UF)
		cont("medbag", "Shelter medkit", 24, 33, 0, UF)
		cont("crate", "Supply crate", -20, 26, 0, UF)
		cont("pharmacy", "Medicine locker", 30.8, 12, FACE.e, UF)
		lt("junk", 0.5, -10, 28, UF)
		lt("junk", 0.45, 6, 34, UF)
		lt("vault", 0.4, 20, 8, UF)
		-- the service area behind the bulkhead: generator, switchgear, pipes, stores
		K("HideoutGenerator", -22, -34, FACE.n, UF)
		K("ElectricCabinet", -8, -36.2, FACE.n, UF)
		K("ElectricCabinet", 6, -36.2, FACE.n, UF)
		K("PipeRun", -14, -18, 0, UF + 6.5)
		cont("toolbox", "Engineer's chest", -28, -22, 0, UF)
		cont("techbox", "Control gear", 14, -35, FACE.n, UF)
		cont("weaponbox", "Sealed crate", 24, -20, 0, UF)
		cont("safe", "Commander's safe", -31, -30, FACE.w, UF)
		shelfP(26, -36.2, 8, UF, true)
		crateP(-10, -24, UF, 2)
		lt("junk", 0.5, 8, -20, UF)
		lt("vault", 0.5, 26, -30, UF)
		lt("tech", 0.35, 14, -33, UF + 3.1)
	end

	-- ═══ THE DERRICK (id 27): an open steel frame. Three platform blocks on two decks (13 and 26 studs), a braced lattice tower
	-- with an open switchback stair to the top deck (158.4) and a mast to 166.9, and a jib out to the sniper perch ════
	local function derrick()
		local b = byId[27]
		site(b, "THE DERRICK", "BW_DER", nil, 6)
		local BA, BB, BC = { -114.8, 1.4, -9.35, 50.2 }, { -40.3, 36.4, -50, -8.2 }, { 35.4, 114.8, -50, 49.8 }
		local pts = { { 115.1, -49.9 }, { -40.1, -50.1 }, { -40.6, -9.4 }, { -114.6, -9.3 }, { -115, 50.2 }, { 1.3, 50.2 }, { 1.5, -8.3 }, { 36, -8.1 }, { 35.6, 49.7 }, { 114.5, 49.8 } }
		local N, TOP, MAST = 12, 158.4, 166.9
		local R = (TOP - FY) / N
		local LV = {}
		for k = 0, N do
			LV[k] = FY + k * R
		end
		local K1, K2 = LV[1], LV[2]
		local TU0, TU1, TV0, TV1 = -76, -44, 14, 46 -- the tower's plan
		local LANE1, LANE2, LW = 17.4, 22.9, 4.6
		local FU0, FU1 = -72, -49.5 -- the flights run between these u
		local PLATE = Enum.Material.DiamondPlate
		local GRID = hex("4A4F4C")
		local function holeOf(r, g)
			return { r[1] - (g or 0), r[2] + (g or 0), r[3] - (g or 0), r[4] + (g or 0) }
		end
		-- deck 1 over the three blocks, with the holes of the two stairs that reach it from below (the tower's first flight
		-- and the south-west access); deck 2 over the north and east blocks, with the hole of the stair up to it
		local d1Holes = { holeOf({ FU0, FU1, LANE1 - LW / 2, LANE1 + LW / 2 }, 0.15), holeOf({ -100, -86.8, 22.4, 27 }, 0.15) }
		local d2Holes = { holeOf({ -37, -23.8, -16.3, -11.7 }, 0.15) }
		slab(bm, BA[1], BA[2], BA[3], BA[4], K1, 0.8, GRID, PLATE, d1Holes)
		slab(bm, BB[1], BB[2], BB[3], BB[4], K1, 0.8, GRID, PLATE, nil)
		slab(bm, BC[1], BC[2], BC[3], BC[4], K1, 0.8, GRID, PLATE, nil)
		slab(bm, BB[1], BB[2], BB[3], BB[4], K2, 0.8, GRID, PLATE, d2Holes)
		slab(bm, BC[1], BC[2], BC[3], BC[4], K2, 0.8, GRID, PLATE, nil)
		-- columns under the decks (skipping the tower and the stair lanes)
		local function free(u, v)
			if u > TU0 - 3 and u < TU1 + 3 and v > TV0 - 3 and v < TV1 + 3 then
				return false
			end
			if u > -104 and u < -82 and v > 14 and v < 30 then
				return false
			end
			if u > -40 and u < -19 and v > -25 and v < -10 then
				return false
			end
			return true
		end
		for _, u in { -108, -82, -56, -30, -4 } do
			for _, v in { -4, 16, 36, 48 } do
				if free(u, v) and not reserved(u, v, 1.5) then
					colm(bm, u, v, 0, K1 - 0.8, 1.6, STL, M.Metal)
				end
			end
		end
		for _, u in { -34, -8, 18, 34 } do
			for _, v in { -46, -28, -12 } do
				if free(u, v) and not reserved(u, v, 1.5) then
					colm(bm, u, v, 0, K2 - 0.8, 1.6, STL, M.Metal)
				end
			end
		end
		for _, u in { 42, 64, 86, 108 } do
			for _, v in { -46, -24, -2, 22, 46 } do
				if free(u, v) and not reserved(u, v, 1.5) then
					colm(bm, u, v, 0, K2 - 0.8, 1.6, STL, M.Metal)
				end
			end
		end
		-- deck beams and a few cross-braces on the long faces
		for _, v in { -50, 49.8 } do
			for k = 0, 3 do
				local u0 = 35.4 + k * 19.85
				beam(bm, Vector3.new(u0, 0.5, v), Vector3.new(u0 + 19.85, K2 - 1, v), 0.5, 0.5, STL2, M.Metal)
				beam(bm, Vector3.new(u0 + 19.85, 0.5, v), Vector3.new(u0, K2 - 1, v), 0.5, 0.5, STL2, M.Metal)
			end
		end
		-- rails: round the outline at deck 1, round the north and east blocks at deck 2
		for i, a in pts do
			local q = pts[i % #pts + 1]
			rail(bm, a[1], a[2], K1, q[1], q[2], K1)
		end
		local D2 = { { -40.3, -50 }, { 114.8, -50 }, { 114.8, 49.8 }, { 35.4, 49.8 }, { 35.4, -8.2 }, { -40.3, -8.2 } }
		for i, a in D2 do
			local q = D2[i % #D2 + 1]
			rail(bm, a[1], a[2], K2, q[1], q[2], K2)
		end
		railRect(bm, -37.15, -23.65, -16.45, -11.55, K2, { { "w", -1000, 1000 } })
		railRect(bm, FU0 - 0.15, FU1 + 0.15, LANE1 - LW / 2 - 0.15, LANE1 + LW / 2 + 0.15, K1, { { "e", -1000, 1000 } })
		railRect(bm, -100.15, -86.65, 22.25, 27.15, K1, { { "w", -1000, 1000 } })

		-- the south-west access: two flights from the ground to deck 1 round a half landing
		do
			local half = FY + (K1 - FY) / 2
			local fl = 13.2
			stairs(bm, -100, 19.7, FY, half - FY, fl / (half - FY), LW, "+u", nil, STL2, M.Metal, true, 0.66)
			ab(bm, -86.8, -82, half - 0.8, half, 17.4, 27, GRID, PLATE)
			stairs(bm, -86.8, 24.7, half, K1 - half, fl / (K1 - half), LW, "-u", nil, STL2, M.Metal, true, 0.66)
			railRect(bm, -86.8, -82, 17.4, 27, half, { { "w", -1000, 1000 } })
		end
		-- the stair up to deck 2 on the north block: two flights round a half landing
		do
			local half = K1 + (K2 - K1) / 2
			local fl = 13.2
			stairs(bm, -37, -19, K1, half - K1, fl / (half - K1), LW, "+u", nil, STL2, M.Metal, true, 0.66)
			ab(bm, -23.8, -19, half - 0.8, half, -21.3, -11.4, GRID, PLATE)
			stairs(bm, -23.8, -14, half, K2 - half, fl / (K2 - half), LW, "-u", nil, STL2, M.Metal, true, 0.66)
			railRect(bm, -23.8, -19, -21.3, -11.4, half, { { "w", -1000, 1000 } })
		end

		-- the lattice tower: four legs, X-braces in every bay of every face, a tie every second level
		for _, c in { { TU0, TV0 }, { TU1, TV0 }, { TU0, TV1 }, { TU1, TV1 } } do
			colm(bm, c[1], c[2], -1, MAST, 2.4, STL, M.Metal)
			ab(bm, c[1] - 2.6, c[1] + 2.6, -1, 1.2, c[2] - 2.6, c[2] + 2.6, hex("6B6E69"), M.Concrete)
		end
		local function face(ua, va, ub, vb)
			for k = 1, N do
				beam(bm, Vector3.new(ua, LV[k - 1], va), Vector3.new(ub, LV[k], vb), 0.6, 0.6, STL2, M.Metal)
				beam(bm, Vector3.new(ub, LV[k - 1], vb), Vector3.new(ua, LV[k], va), 0.6, 0.6, STL2, M.Metal)
				if k % 2 == 0 then
					beam(bm, Vector3.new(ua, LV[k], va), Vector3.new(ub, LV[k], vb), 0.8, 0.8, STL, M.Metal)
				end
			end
		end
		face(TU0, TV0, TU1, TV0)
		face(TU0, TV1, TU1, TV1)
		face(TU0, TV0, TU0, TV1)
		face(TU1, TV0, TU1, TV1)
		-- the stair: flight k climbs from level k - 1 to k, odd ones along lane 1 toward +u, even ones back along lane 2
		for k = 1, N do
			local odd = (k % 2 == 1)
			stairs(bm, odd and FU0 or FU1, odd and LANE1 or LANE2, LV[k - 1], R, (FU1 - FU0) / R, LW, odd and "+u" or "-u", nil, STL2, M.Metal, true, 0.66)
		end
		-- landings and plates, level by level
		for k = 1, N do
			local odd = (k % 2 == 1)
			local y = LV[k]
			if k >= 2 then
				local lu0, lu1 = odd and FU1 or TU0, odd and TU1 or FU0
				slab(bm, lu0, lu1, 14.6, 26, y, 0.8, GRID, PLATE, nil)
				slab(bm, TU0, TU1, 26, TV1, y, 0.8, GRID, PLATE, nil)
				local gaps = { { "n", -1000, 1000 } }
				if k == N then
					gaps = { { "n", -1000, 1000 }, { "s", -63, -57 } }
				end
				railRect(bm, TU0, TU1, 26, TV1, y, gaps)
				if odd then
					railRect(bm, lu0, lu1, 14.6, 26, y, { { "w", -1000, 1000 }, { "s", -1000, 1000 } })
				else
					railRect(bm, lu0, lu1, 14.6, 26, y, { { "e", -1000, 1000 }, { "s", -1000, 1000 } })
				end
			end
		end
		-- the top: a mast with a beacon, the jib and the perch
		for _, u in { -72, -48 } do
			colm(bm, u, 40, TOP, MAST + 1.5, 0.7, STL, M.Metal)
		end
		ab(bm, -72.4, -47.6, MAST + 1, MAST + 1.5, 39.6, 40.4, STL, M.Metal)
		local bea = ab(bm, -61, -59, MAST + 1.5, MAST + 2.7, 39, 41, hex("FF3B2E"), M.Neon)
		if bea then
			bea.CanCollide = false
			bea.CastShadow = false
			bea:SetAttribute("NoDetail", true)
			kit.light(bea, hex("FF4A3A"), 60, 1.2, false)
		end
		ab(bm, -61, -59, MAST + 1.0, MAST + 1.5, 39, 41, STL, M.Metal)
		slab(bm, -63, -57, TV1, 74, TOP, 0.7, GRID, PLATE, nil)
		slab(bm, -66.5, -53.5, 74, 87, TOP, 0.8, GRID, PLATE, nil)
		rail(bm, -63, TV1, TOP, -63, 74, TOP)
		rail(bm, -57, TV1, TOP, -57, 74, TOP)
		railRect(bm, -66.5, -53.5, 74, 87, TOP, { { "n", -63, -57 } })
		for _, u in { -62, -58 } do
			beam(bm, Vector3.new(u, TOP - 0.7, 72), Vector3.new(u, LV[N - 1] + 2, TV1 + 0.5), 0.7, 0.7, STL2, M.Metal)
		end
		beam(bm, Vector3.new(-66.2, TOP - 0.8, 76), Vector3.new(-66.2, TOP - 6, 86.5), 0.6, 0.6, STL2, M.Metal)
		beam(bm, Vector3.new(-53.8, TOP - 0.8, 76), Vector3.new(-53.8, TOP - 6, 86.5), 0.6, 0.6, STL2, M.Metal)
		point("DERRICK_TOP", -60, TOP, 36)
		-- lamps under deck 1 and on the tower's plates
		for k, p in { { -100, 40 }, { -60, 4 }, { -20, 36 }, { -20, -30 }, { 20, -30 }, { 60, -10 }, { 100, 30 }, { 90, -40 } } do
			lamp(p[1], K1 - 1.2, p[2], (k % 3 == 0) and 0 or 30, 0.8, nil, COLD, 3.2)
		end
		for _, k in { 4, 8, 12 } do
			lamp(-60, LV[k] + 8, 36, 24, 0.7, nil, COLD, 3.2)
		end
		-- pipework and drums on deck 1 for cover
		for _, p in { { -90, 2, 12 }, { -20, 24, 10 }, { 20, -36, 16 }, { 62, 16, 12 }, { 96, -30, 12 } } do
			ab(bm, p[1] - p[3] / 2, p[1] + p[3] / 2, K1 + 1.4, K1 + 2.6, p[2] - 0.6, p[2] + 0.6, STL2, M.Metal)
			ab(bm, p[1] - p[3] / 2 + 1, p[1] - p[3] / 2 + 1.5, K1, K1 + 1.4, p[2] - 0.5, p[2] + 0.5, STL, M.Metal)
			ab(bm, p[1] + p[3] / 2 - 1.5, p[1] + p[3] / 2 - 1, K1, K1 + 1.4, p[2] - 0.5, p[2] + 0.5, STL, M.Metal)
		end
		-- loot: deck 1, deck 2, the tower, the perch (plain containers: the budget is for the rooms)
		for _, c in { { "toolbox", "Rig toolbox", -104, 40, K1 }, { "techbox", "Rig control box", -90, 4, K1 }, { "crate", "Rig supplies", -30, 38, K1 }, { "locker", "Locker", -14, 4, K1 },
			{ "crate", "Deck crate", -30, -42, K1 }, { "weaponbox", "Sealed case", 0, -30, K1 }, { "toolbox", "Deck toolbox", 28, -44, K1 }, { "medbag", "First aid bag", 46, -44, K1 },
			{ "crate", "Deck crate", 62, 40, K1 }, { "techbox", "Rig control box", 100, 30, K1 }, { "toolbox", "Deck toolbox", 108, -40, K1 }, { "weaponbox", "Sealed case", 80, 0, K1 },
			{ "safe", "Rig safe", -8, -44, K2 }, { "crate", "Upper deck crate", 12, -30, K2 }, { "techbox", "Rig control box", 50, -44, K2 }, { "toolbox", "Upper deck toolbox", 100, -44, K2 },
			{ "weaponbox", "Sealed case", 70, 20, K2 }, { "medbag", "First aid bag", 108, 30, K2 }, { "drawer", "Foreman's drawer", 40, 0, K2 },
			{ "medbag", "First aid bag", -48, 42, LV[4] }, { "toolbox", "Tower toolbox", -72, 42, LV[6] }, { "techbox", "Tower control box", -48, 42, LV[8] },
			{ "weaponbox", "Sealed case", -72, 42, LV[10] }, { "safe", "Lookout's safe", -48, 42, LV[12] }, { "weaponbox", "Perch crate", -56, 85, LV[12] } } do
			cont(c[1], c[2], c[3], c[4], 0, c[5], true)
		end
		for _, s in { { "junk", 0.5, -70, 4, K1 }, { "junk", 0.45, -20, 40, K1 }, { "junk", 0.45, 14, -40, K1 }, { "junk", 0.4, 90, 10, K1 }, { "vault", 0.4, 0, -44, K2 },
			{ "junk", 0.45, 76, -36, K2 }, { "tech", 0.4, -60, 40, LV[6] }, { "vault", 0.5, -60, 40, LV[12] }, { "junk", 0.4, -60, 82, LV[12] } } do
			lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
		end
	end

	-- a dog-leg stair in the rectangle u0..u1 x v0..v1: flight 1 climbs from y0 to a half landing along lane 1 (the v0 side)
	-- toward +u, flight 2 comes back along lane 2 (the v1 side) to y1 at the u0 end; rn = run per unit of rise. Returns the
	-- rectangle flight 2 passes through in the floor at y1 (for a hole there).
	local function dogleg(u0, u1, v0, v1, y0, y1, rn, col, mat, solid, step)
		local rise = (y1 - y0) / 2
		local half = y0 + rise
		local lw = math.min(5.2, (v1 - v0) / 2 - 0.3)
		local l1, l2 = v0 + lw / 2 + 0.1, v1 - lw / 2 - 0.1
		local uh = u0 + rise * rn
		stairs(bm, u0, l1, y0, rise, rn, lw, "+u", solid and (y0 - 0.2) or nil, col, mat, true, step)
		ab(bm, uh, u1, solid and (y0 - 0.2) or (half - 0.8), half, v0, v1, col, mat)
		stairs(bm, uh, l2, half, rise, rn, lw, "-u", solid and (y0 - 0.2) or nil, col, mat, true, step)
		railRect(bm, uh, u1, v0, v1, half, { { "w", -1000, 1000 } })
		return { u0 - 0.15, uh + 0.15, l2 - lw / 2 - 0.15, l2 + lw / 2 + 0.15 }
	end

	-- ═══ THE FRAME (id 34): an unfinished concrete skeleton, three levels, columns, beams, slabs in strips, two stairs, no
	-- walls; the third level is the top deck ═══════════════════════════════════════════════════════════════════
	local function frame()
		local b = byId[34]
		site(b, "THE FRAME", "BW_FRM", nil, 6)
		local hw, hd = b[6] / 2, b[7] / 2
		local D2, D3 = FY + 12.4, FY + 24.8
		local CON, CON2 = hex("8B8D86"), hex("757872")
		local YB = hex("C9A227")
		-- the stair blocks: ladder-29 from the layout, and one more at the east end
		local s29 = nil
		for _, s in L.stairs do
			if s[1] == "ladder-29" and s[2] == 1 then
				s29 = s
			end
		end
		local r1 = s29 and pitRect(s29) or { u0 = -92.1, u1 = -75.5, v0 = -34.8, v1 = -20.4 }
		local r2 = { u0 = 70, u1 = 86.6, v0 = 20, v1 = 34.4 }
		-- floors: the ground pad, then strips; the third level stops short of the east end
		slab(bm, -hw, hw, -hd, hd, FY, 0.9, hex("65675F"), M.Concrete, nil)
		local h2a, h2b, h3a, h3b = {}, {}, {}, {}
		local top1, top2 = nil, nil
		for k, r in { r1, r2 } do
			local hole1 = dogleg(r.u0, r.u1, r.v0, r.v1, FY, D2, 2.0, CON2, M.Concrete, true, nil)
			local hole2 = dogleg(r.u0, r.u1, r.v0, r.v1, D2, D3, 2.0, CON2, M.Concrete, true, nil)
			table.insert(h2a, hole1)
			table.insert(h3a, hole2)
			if k == 1 then
				top1 = hole2
			else
				top2 = hole2
			end
		end
		local _ = { h2b, h3b, top1, top2 }
		slab(bm, -hw + 0.5, hw - 0.5, -37.5, 0.95, D2, 0.9, CON, M.Concrete, h2a)
		slab(bm, -hw + 0.5, hw - 0.5, 0.95, 37.5, D2, 0.9, CON, M.Concrete, h2a)
		slab(bm, -hw + 0.5, 34, -37.5, 0.95, D3, 0.9, CON, M.Concrete, h3a)
		slab(bm, -hw + 0.5, 34, 0.95, 37.5, D3, 0.9, CON, M.Concrete, h3a)
		-- columns with rebar stubs on top, and the beams under each slab
		local CU, CV = {}, { -35.6, -12, 12, 35.6 }
		for k = 0, 8 do
			table.insert(CU, -91.2 + 22.8 * k)
		end
		for _, u in CU do
			for _, v in CV do
				if not reserved(u, v, 1.5) then
					colm(bm, u, v, 0, D3 + 7, 2.2, CON2, M.Concrete)
					if u > 34 then
						colm(bm, u, v, D3 + 7, D3 + 11, 0.3, hex("5A4A3A"), M.Metal)
					end
				end
			end
		end
		for _, v in CV do
			ab(bm, -hw + 0.5, hw - 0.5, D2 - 2.2, D2 - 0.9, v - 0.7, v + 0.7, CON2, M.Concrete)
			ab(bm, -hw + 0.5, 34, D3 - 2.2, D3 - 0.9, v - 0.7, v + 0.7, CON2, M.Concrete)
		end
		for _, u in CU do
			ab(bm, u - 0.7, u + 0.7, D2 - 2.2, D2 - 0.9, -37.5, 37.5, CON2, M.Concrete)
			if u < 34 then
				ab(bm, u - 0.7, u + 0.7, D3 - 2.2, D3 - 0.9, -37.5, 37.5, CON2, M.Concrete)
			end
		end
		-- barriers: yellow rails round both levels and round the stair holes
		railRect(bm, -hw + 0.5, hw - 0.5, -37.5, 37.5, D2, nil, YB)
		railRect(bm, -hw + 0.5, 34, -37.5, 37.5, D3, { { "e", -1000, 1000 } }, YB)
		rail(bm, 34, -37.5, D3, 34, 37.5, D3, YB)
		for _, h in h2a do
			railRect(bm, h[1], h[2], h[3], h[4], D2, { { "w", -1000, 1000 } }, YB)
		end
		for _, h in h3a do
			railRect(bm, h[1], h[2], h[3], h[4], D3, { { "w", -1000, 1000 } }, YB)
		end
		-- the site: a foreman's cabin on the ground floor, brick pallets, sand, a cement mixer, planks, lamps
		room({
			u0 = 52, u1 = 64, v0 = -34.4, v1 = -26, y0 = FY, h = 8.6, ceil = true, col = hex("6F7E78"), mat = M.Metal,
			doors = { s = { { s = 6, id = "BW_FRM_CABIN" } } }, windows = { w = { { 4, 4, 3.5, 6.5 } } },
		})
		tableP(54, 60, -33.4, -31.4, FY, 2.8)
		cont("drawer", "Foreman's desk", 57, -32.4, 0, FY, true)
		cont("safe", "Site safe", 62.8, -30, FACE.e, FY, true)
		lamp(58, FY + 8, -30, 14, 0.7, nil, WARM, 2.4)
		for _, p in { { -60, -20 }, { -30, 24 }, { 10, 4 }, { 40, 28 }, { 80, -24 } } do
			ab(bm, p[1] - 2, p[1] + 2, FY, FY + 3.2, p[2] - 2, p[2] + 2, BRK, M.Brick)
			ab(bm, p[1] - 2.1, p[1] + 2.1, FY + 3.2, FY + 3.4, p[2] - 2.1, p[2] + 2.1, WOOD, M.WoodPlanks)
		end
		for _, p in { { -10, -24, 4 }, { 30, -8, 3.4 }, { -74, 26, 3 } } do
			ab(bm, p[1] - p[3], p[1] + p[3], FY, FY + p[3] * 0.7, p[2] - p[3] * 0.8, p[2] + p[3] * 0.8, hex("A99B7A"), M.Sand)
		end
		for _, p in { { 20, 30 }, { -45, 4 } } do
			ab(bm, p[1] - 1.2, p[1] + 1.2, FY, FY + 2.6, p[2] - 1.2, p[2] + 1.2, hex("B0801C"), M.Metal)
		end
		for k, p in { { -70, -30 }, { -20, 30 }, { 30, -20 }, { 80, 28 } } do
			lamp(p[1], D2 - 2.6, p[2], (k % 2 == 1) and 30 or 0, 0.8, nil, COLD, 3.2)
		end
		-- loot: the two decks and the ground floor (plain containers)
		for _, c in { { "toolbox", "Builder's toolbox", -80, 30, D2 }, { "crate", "Cement bags", -50, -30, D2 }, { "techbox", "Site electrics", -20, 8, D2 }, { "jacket", "Workers' jackets", 10, -30, D2 },
			{ "locker", "Locker", 30, 30, D2 }, { "medbag", "First aid bag", 60, -4, D2 }, { "toolbox", "Builder's toolbox", 88, -30, D2 }, { "weaponbox", "Hidden case", 90, 30, D2 },
			{ "crate", "Cement bags", -70, 6, D3 }, { "toolbox", "Builder's toolbox", -40, -30, D3 }, { "techbox", "Site electrics", -10, 30, D3 }, { "safe", "Contractor's safe", 14, -28, D3 },
			{ "weaponbox", "Hidden case", 28, 6, D3 }, { "medbag", "First aid bag", -86, -30, D3 }, { "crate", "Cement bags", -30, 0, FY }, { "toolbox", "Builder's toolbox", 74, 4, FY } } do
			cont(c[1], c[2], c[3], c[4], 0, c[5], true)
		end
		for _, s in { { "junk", 0.5, -60, 20, D2 }, { "junk", 0.45, 0, -20, D2 }, { "junk", 0.45, 70, 20, D2 }, { "junk", 0.45, -50, 20, D3 }, { "tech", 0.35, -20, -20, D3 },
			{ "junk", 0.4, 10, 10, D3 }, { "junk", 0.45, -20, 10, FY }, { "junk", 0.4, 50, -10, FY } } do
			lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
		end
		point("FRAME_TOP", -40, D3, -18)
	end

	-- ═══ MOTOR SHOP + BOILER HOUSE (id 30) and the BOILER CELLAR under it (L.under BC) ══════════════════════════
	-- A brick boiler hall (galleries at two levels, a stair tower to its roof, three drum boilers, a stack), the workshop
	-- wing in the west (a gantry crane, a lift, the locked foreman's office: KEY_BY_MOTOR) and the parts store in the
	-- north (a mezzanine and a stair up to its roof). The boilerman's cabin in the hall holds the locked door
	-- (KEY_BY_BOILER) to the stairs down to the cellar, a pump hall whose exit zone takes the same key.
	do
		local MP = { { 87.5, -92.3 }, { 28.7, -92.3 }, { 28.5, -54.7 }, { 66.6, -55 }, { 66.2, -21.5 }, { -93.5, -21.5 }, { -93.5, 16.4 }, { -22.3, 16.4 }, { -22.7, 92.6 }, { 92.9, 92.7 }, { 93.6, -21.5 }, { 85.4, -21.6 } }
		local MT = 1.6
		local MSH = { u0 = 2, u1 = 20, v0 = 22, v1 = 32 } -- the cabin's stair shaft down to the cellar
		local TW = { u0 = 69, u1 = 85.6, v0 = 74, v1 = 88.4 } -- the stair tower in the hall's south-east corner
		local GRID = hex("4D5553")
		local RS = { -22.5, 93.2, -21.5, 92.7 } -- the hall
		local RW = { -93.5, -22.5, -21.5, 16.4 } -- the workshop wing
		local RN = { 28.6, 86.4, -92.3, -55 } -- the parts store
		local RL = { 66.4, 85.6, -55, -21.5 } -- its leg down to the hall
		local SR = { 66.0, 83.5, -66.8, -61.6 } -- the hole in the store's roof for the stair
		local DOORS = { { 1, 44 }, { 2, 20 }, { 3, 6 }, { 4, 14 }, { 5, 70 }, { 5, 102.8 }, { 7, 12 }, { 8, 60 }, { 9, 62 }, { 10, 90 }, { 12, 14 } }
		local GATES = { { 1, 15, 9, 10.4 }, { 5, 30, 12, 14 }, { 6, 19, 9, 10.4 }, { 7, 36, 9, 10.4 }, { 8, 26, 9, 10.4 }, { 9, 30, 12, 14 }, { 10, 52, 12, 14 }, { 12, 58, 9, 10.4 } }
		-- window runs: edge, from, to, step, width, bottom, top (s along the edge)
		local WINS = {
			{ 1, 8, 50, 7, 3.5, 13, 19 }, { 2, 8, 30, 11, 3.5, 13, 19 }, { 3, 14, 34, 10, 3.5, 13, 19 }, { 4, 6, 30, 8, 3.5, 13, 19 }, { 5, 8, 82, 12, 5, 26, 33 },
			{ 5, 100, 155, 9, 3.5, 13, 19 }, { 6, 7, 31, 12, 3.5, 13, 19 }, { 7, 6, 66, 9, 3.5, 13, 19 }, { 8, 8, 70, 12, 5, 26, 33 }, { 9, 8, 108, 12, 5, 26, 33 },
			{ 10, 8, 106, 12, 5, 26, 33 }, { 12, 8, 66, 9, 3.5, 13, 19 },
		}

		-- a wall by absolute heights y0..y1; holes { s, width, bottom, top } (heights above the pad) that miss the band are
		-- dropped; shift moves their s
		local function wlh(p, u0, v0, u1, v1, y0, y1, t, col, mat, holes, shift)
			local hs = {}
			for _, hh in holes or {} do
				local lo, hi = math.max(hh[3], y0), math.min(hh[4], y1)
				if hi - lo > 0.3 then
					table.insert(hs, { hh[1] + (shift or 0), hh[2], lo - y0, hi - y0 })
				end
			end
			wl(p, u0, v0, u1, v1, y0, y1 - y0, t, col, mat, hs)
		end
		-- edge i of the outline from s0 to s1 (default all of it), flush inside the outline
		local function edgeWall(i, y0, y1, t, col, mat, holes, s0, s1)
			local e = polyInfo(MP, i)
			s0, s1 = s0 or 0, s1 or e.len
			local a0 = s0 - (((s0 <= 0.01) and e.reflex) and t or 0)
			local hs = {}
			for _, hh in holes or {} do
				if hh[1] - hh[2] / 2 >= s0 - 0.01 and hh[1] + hh[2] / 2 <= s1 + 0.01 then
					table.insert(hs, hh)
				end
			end
			wlh(bm, e.a[1] + e.ux * a0 + e.nx * t / 2, e.a[2] + e.uz * a0 + e.nz * t / 2, e.a[1] + e.ux * s1 + e.nx * t / 2, e.a[2] + e.uz * s1 + e.nz * t / 2, y0, y1, t, col, mat, hs, -a0)
		end

		-- floors, roofs, the outer walls with their gates, doors and windows, the walls between the three wings
		local function shell(Y3, RF)
			local HB = RF - 0.8
			local H = {}
			for i = 1, 12 do
				H[i] = {}
			end
			table.insert(H[5], { 150.2, 5, 3.5, 6.5 }) -- the foreman's office window
			for _, d in DOORS do
				table.insert(H[d[1]], { d[2], 4.2, 0, 7.9 })
			end
			for _, g in GATES do
				table.insert(H[g[1]], { g[2], g[3], 0, g[4] })
			end
			for _, w in WINS do
				addWindows(H[w[1]], w[2], w[3], w[4], w[5], w[6], w[7])
			end
			slab(bm, RS[1], RS[2], RS[3], RS[4], FY, 1.0, FLR, M.Concrete, { { MSH.u0, MSH.u1, MSH.v0, MSH.v1 } })
			slab(bm, RS[1], RS[2], RS[3], RS[4], RF, 0.8, ROOF, M.Concrete, { { TW.u0 - 0.15, TW.u1 + 0.15, TW.v0 - 0.15, TW.v1 + 0.15 } })
			for _, r in { RW, RN, RL } do
				slab(bm, r[1], r[2], r[3], r[4], FY, 1.0, FLR, M.Concrete, nil)
			end
			slab(bm, RW[1], RW[2], RW[3], RW[4], Y3, 0.8, ROOF, M.Concrete, nil)
			slab(bm, RN[1], RN[2], RN[3], RN[4], Y3, 0.8, ROOF, M.Concrete, { SR })
			slab(bm, RL[1], RL[2], RL[3], RL[4], Y3, 0.8, ROOF, M.Concrete, nil)
			local function wall(i, y0, y1, kind, s0, s1)
				local col, mat = PAN, M.Concrete
				if kind == "b" then
					col, mat = BRK, M.Brick
				elseif kind == "s" then
					col, mat = SHT, M.CorrodedMetal
				end
				edgeWall(i, y0, y1, MT, col, mat, H[i], s0, s1)
			end
			for _, a in { { 1, "p" }, { 2, "p" }, { 3, "p" }, { 4, "p" }, { 12, "p" }, { 6, "s" }, { 7, "s" } } do
				wall(a[1], 0, Y3, a[2])
			end
			wall(5, 0, Y3, "b", 0, 88.8)
			wall(5, 0, Y3, "s", 88.8)
			wall(5, Y3, HB, "b", 0, 88.8)
			for _, i in { 8, 9, 10, 11 } do
				wall(i, 0, Y3, "b")
				wall(i, Y3, HB, "b")
			end
			-- parapets round the low roofs, and round the hall's
			for _, i in { 1, 2, 3, 4, 12, 6, 7 } do
				edgeWall(i, Y3, Y3 + 2.4, 0.8, BRK2, M.Brick, nil)
			end
			edgeWall(5, Y3, Y3 + 2.4, 0.8, BRK2, M.Brick, nil, 88.8)
			rectWalls(bm, RS[1], RS[2], RS[3], RS[4], RF, 3.4, 0.8, BRK2, M.Brick, nil)
			-- the hall's north wall over the leg, and the wall it shares with the workshop wing (a gate, a door, and at roof
			-- level a door onto the wing's roof)
			wlh(bm, 66.4, -20.7, 85.4, -20.7, Y3, HB, MT, BRK, M.Brick, { { 9.5, 5, 26, 33 } })
			local SW = { { 18.5, 9, 0, 10.4 }, { 33, 4.2, 0, 7.9 }, { 18.5, 4.2, Y3, Y3 + 7.9 }, { 6, 4, Y3 + 4, Y3 + 9 } }
			wlh(bm, -21.55, -21.5, -21.55, 16.4, 0, Y3, MT, BRK, M.Brick, SW)
			wlh(bm, -21.55, -21.5, -21.55, 16.4, Y3, HB, MT, BRK, M.Brick, SW)
			door(doorId(), "Door", -21.55, 11.5, "+u", 4.0, 7.4, FY, nil, hex("5A5F57"))
			door(doorId(), "Roof door", -21.55, -3, "+u", 4.0, 7.4, Y3, nil, hex("5A5F57"))
			for _, d in DOORS do
				edgeDoor(MP, d[1], d[2], MT, FY)
			end
		end

		-- the boilerman's cabin over the stairs to the cellar, the shaft, its lining and the flights down
		local function cabin()
			local sh = MSH
			-- the cabin reaches 7.7 studs west of the shaft (u -6): with its wall at -2 the floor between the door and the stair was
			-- 2.7 studs wide, and the pathfinder found no way across it to the cellar (KNOWN_ISSUES 68, 2026-11-02)
			room({
				u0 = -6, u1 = 24, v0 = 18, v1 = 36, y0 = FY, h = 9.2, ceil = true, col = hex("6F7E78"), mat = M.Metal,
				doors = { w = { { s = 11.5, key = "KEY_BY_BOILER", id = "by_boiler", label = "Boiler cellar stair" } } },
				windows = { n = { { 12, 5, 3.5, 6.5 } }, s = { { 12, 5, 3.5, 6.5 } } },
			})
			for _, w in { { sh.u0 - 0.5, sh.u0, sh.v0 - 0.5, sh.v1 + 0.5 }, { sh.u1, sh.u1 + 0.5, sh.v0 - 0.5, sh.v1 + 0.5 }, { sh.u0, sh.u1, sh.v0 - 0.5, sh.v0 }, { sh.u0, sh.u1, sh.v1, sh.v1 + 0.5 } } do
				ab(bm, w[1], w[2], -4.3, 0.4, w[3], w[4], PAN2, M.Concrete)
			end
			dig(sh.u0 - 2, sh.u1 + 2, -4.6, 1.0, sh.v0 - 2, sh.v1 + 2)
			dogleg(sh.u0, sh.u1, sh.v0, sh.v1, UF, FY, 1.6, PAN2, M.Concrete, true, nil)
			railRect(bm, sh.u0 - 0.3, sh.u1 + 0.3, sh.v0 - 0.3, sh.v1 + 0.3, FY, { { "w", 27.2, 31.9 } })
			lamp(10, 8.6, 27, 16, 0.7, nil, WARM, 2.4)
			tableP(14, 20, 33.4, 35.4, FY, 2.8)
			cont("drawer", "Boilerman's desk", 17, 34.4, 0, FY, true)
			cont("locker", "Boilerman's locker", 22.8, 21, FACE.e, FY)
			cont("toolbox", "Boilerman's chest", 4, 35, FACE.s, FY, true)
			lt("junk", 0.45, 18, 34.4, FY + 2.8)
		end

		-- the hall: galleries, the tower, boilers, the stack, cover on the roof
		local function hall(Y2, Y3, Y4, RF, RISE)
			local _ = Y4
			for _, y in { Y2, Y3 } do
				slab(bm, -20.7, -13.7, -20.7, 91.1, y, 0.8, GRID, M.DiamondPlate, nil)
				slab(bm, -13.7, 65, 83.6, 91.1, y, 0.8, GRID, M.DiamondPlate, nil)
				rail(bm, -13.7, -20.7, y, -13.7, 83.6, y)
				rail(bm, -13.7, 83.6, y, 65, 83.6, y)
			end
			slab(bm, -13.7, 66, -20.7, -12.7, Y3, 0.8, GRID, M.DiamondPlate, nil)
			rail(bm, -13.7, -12.7, Y3, 66, -12.7, Y3)
			rail(bm, 66, -20.7, Y3, 66, -12.7, Y3)
			for _, v in { -11, 20, 52 } do
				colm(bm, -13.4, v, FY, Y3 - 0.8, 1.2, STL, M.Metal)
			end
			for _, u in { -4, 24, 52 } do
				colm(bm, u, 83.4, FY, Y3 - 0.8, 1.2, STL, M.Metal)
			end
			for _, u in { 10, 38 } do
				colm(bm, u, -12.9, FY, Y3 - 0.8, 1.2, STL, M.Metal)
			end
			-- the tower: four dog-legs and a landing at the west side of each level
			for k = 1, 4 do
				local y0 = FY + (k - 1) * RISE
				dogleg(TW.u0, TW.u1, TW.v0, TW.v1, y0, y0 + RISE, 1.45, STL2, M.Metal, false, 0.6)
				if k < 4 then
					local y = y0 + RISE
					local vEnd = TW.v1
					if k < 3 then
						vEnd = 83.6 -- the gallery meets the landing from here south
					end
					ab(bm, TW.u0 - 4, TW.u0, y - 0.8, y, TW.v0, TW.v1, GRID, M.DiamondPlate)
					rail(bm, TW.u0 - 4, TW.v0, y, TW.u0, TW.v0, y)
					rail(bm, TW.u0 - 4, TW.v1, y, TW.u0, TW.v1, y)
					rail(bm, TW.u0 - 4, TW.v0, y, TW.u0 - 4, vEnd, y)
				end
			end
			railRect(bm, TW.u0 - 0.15, TW.u1 + 0.15, TW.v0 - 0.15, TW.v1 + 0.15, RF, { { "w", -1000, 1000 } })
			-- three drum boilers on brick cradles with firing fronts, a steam header over them and the stack
			for _, v in { 10, 34, 58 } do
				hcyl(bm, 48, FY + 6.5, v, 40, 9, hex("5E6B66"), M.Metal, 0)
				for _, cu in { 33, 63 } do
					ab(bm, cu - 2.5, cu + 2.5, FY, FY + 2.1, v - 3.2, v + 3.2, BRK2, M.Brick)
				end
				ab(bm, 26.6, 28, FY + 2.2, FY + 10.4, v - 2.8, v + 2.8, hex("3D4543"), M.Metal)
				ab(bm, 47, 53, FY + 11, FY + 12.4, v - 1.2, v + 1.2, hex("3D4543"), M.Metal)
				ab(bm, 61.6, 62.4, FY + 10.9, FY + 14.2, v - 0.4, v + 0.4, STL2, M.Metal)
			end
			ab(bm, 61.6, 62.4, FY + 13.8, FY + 14.6, 9.6, 58.4, STL2, M.Metal)
			ucyl(bm, 80, FY, 12, 60, 8, hex("6B4A3C"), M.Brick)
			-- the hall's middle row of columns; the first stood at (4, 28), inside the cabin on the top steps of the cellar stair,
			-- where it left a 3-stud gap no AI path could take (KNOWN_ISSUES 68); it stands north of the cabin now
			for _, c in { { 4, 39.5 }, { 4, 55 }, { 4, 70 } } do
				colm(bm, c[1], c[2], FY, Y3 - 0.8, 1.6, PAN2, M.Concrete)
			end
			K("Generator", 86, 66, FACE.e, FY)
			K("ElectricCabinet", 90.5, 24, FACE.e, FY)
			K("ElectricCabinet", 90.5, 32, FACE.e, FY)
			K("WaterTank", 2, -17.5, FACE.n, FY) -- its back on the north wall (inner face v -19.6), not 0.8 into it
			K("Drum", 74, 6, 0, FY)
			K("Drum", 76, 4, 0, FY)
			K("WorkLight", 14, 62, 30, FY)
			for k, p in { { 10, 20 }, { 40, 10 }, { 70, 10 }, { 40, 60 }, { 70, 60 }, { 10, 70 }, { 60, 40 } } do
				lamp(p[1], 40, p[2], (k % 3 == 0) and 0 or 36, 0.9, nil, COLD, 4.4)
			end
			for k, p in { { -10, 87 }, { 20, 87 }, { 50, 87 } } do
				lamp(p[1], Y2 - 2.4, p[2], (k % 2 == 1) and 20 or 0, 0.7, nil, WARM, 3)
			end
			for _, c in { { "toolbox", "Stoker's chest", 80, 2, FY }, { "techbox", "Control panel", 90.5, 40, FY }, { "crate", "Spare parts", 20, 80, FY }, { "medbag", "First aid bag", -14, 60, FY },
				{ "jacket", "Stoker's coat", 90, 12, FY }, { "weaponbox", "Locked case", 62, 88, Y2 }, { "toolbox", "Catwalk chest", 10, 88, Y2 }, { "techbox", "Valve panel", 40, 88, Y3 },
				{ "crate", "Catwalk crate", -17, 60, Y3 }, { "toolbox", "Gallery chest", 20, -17, Y3 } } do
				cont(c[1], c[2], c[3], c[4], 0, c[5], true)
			end
			cont("safe", "Boiler master's safe", 90, 18, FACE.e, FY, true)
			for _, s in { { "junk", 0.5, 4, 10, FY }, { "junk", 0.45, 50, 80, FY }, { "tech", 0.35, 90.5, 28, 3.1 }, { "junk", 0.45, 62, 86, Y2 }, { "junk", 0.4, 40, 86, Y3 }, { "vault", 0.4, 90, 14, 3.1 } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
			-- the roof: the sniper's perch at (32, 62), steel cover, a water tank
			for _, p in { { 20, 50 }, { 60, 20 }, { 50, 80 }, { 14, 74 } } do
				ab(bm, p[1] - 3, p[1] + 3, RF, RF + 3, p[2] - 3, p[2] + 3, STL2, M.Metal)
			end
			ucyl(bm, 10, RF, 30, 6, 7, hex("6C7A72"), M.Metal)
			cont("weaponbox", "Perch crate", 36, 66, 0, RF, true)
			lt("junk", 0.4, 30, 60, RF)
		end

		-- the workshop wing: crane, lift, benches, the mezzanine, the locked foreman's office
		local function wing(Y2, Y3)
			local _ = Y3
			for _, v in { -19.2, 14.1 } do
				ab(bm, -92.6, -22.6, 17, 18.2, v - 0.6, v + 0.6, STL, M.Metal)
				for _, u in { -88, -58, -28 } do
					colm(bm, u, v, FY, 17, 1.4, PAN2, M.Concrete)
				end
			end
			ab(bm, -58.8, -57.2, 18.2, 19.6, -19.2, 14.1, STL2, M.Metal)
			ab(bm, -59, -57, 16.2, 18.2, -2, 0.4, hex("B0801C"), M.Metal)
			ab(bm, -58.15, -57.85, 11, 16.2, -1, -0.7, STL, M.Metal)
			ab(bm, -58.6, -57.4, 10, 11, -1.3, -0.4, STL2, M.Metal)
			-- the foreman's office (KEY_BY_MOTOR): the north-west corner, a door onto the shop floor
			room({
				u0 = -91.9, u1 = -76, v0 = -19.9, v1 = -6, y0 = FY, h = 10.4, ceil = true, skip = { n = true, w = true }, finish = "ZR_WoodPanel",
				doors = { e = { { s = 9, key = "KEY_BY_MOTOR", id = "by_motor", label = "Foreman's office" } } },
			})
			tableP(-90, -83, -18.4, -15.4, FY, 2.8)
			cont("drawer", "Foreman's desk", -86.5, -16.9, 0, FY, true)
			-- the safe in the north-east corner and the radio crate by the west wall: they stood in the lockers and in
			-- the door's swing (placement audit, 2026-11-01)
			cont("safe", "Foreman's safe", -79, -17.6, FACE.n, FY, true)
			cont("techbox", "Radio crate", -90.3, -12.2, FACE.w, FY, true)
			K("Lockers", -88, -8.4, FACE.s, FY)
			lamp(-84, 9.6, -13, 18, 0.8, nil, WARM, 3.2)
			for _, s in { { "vault", 0.6, -84, -16.9, 2.9 }, { "keys", 0.35, -80, -9, FY } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
			-- the parts mezzanine along the north wall, its stair
			slab(bm, -72, -47.5, -19.9, -12.7, Y2, 0.8, GRID, M.DiamondPlate, nil)
			rail(bm, -72, -12.7, Y2, -47.5, -12.7, Y2)
			rail(bm, -72, -19.9, Y2, -72, -12.7, Y2)
			stairs(bm, -30, -16.3, FY, Y2 - FY, 1.5, 3.6, "-u", FY - 0.2, PAN2, M.Concrete, true, 0.65)
			for _, u in { -68, -58 } do
				shelfP(u, -18.5, 8, Y2, true)
			end
			colm(bm, -71.4, -13.3, FY, Y2 - 0.8, 1.0, STL, M.Metal)
			colm(bm, -48.1, -13.3, FY, Y2 - 0.8, 1.0, STL, M.Metal)
			cont("crate", "Parts crate", -52, -16, 0, Y2, true)
			cont("toolbox", "Mezzanine chest", -70, -14, 0, Y2, true)
			lt("junk", 0.4, -62, -14, Y2 + 0.1)
			-- the shop floor: a car on a two-post lift, the benches, tyres, drums
			local onLift = K("CarSedan", -50, 0, 90, FY + 3.4)
			if onLift then
				onLift:SetAttribute("Raised", true) -- it rests on the lift arms at its ends: the placement audit skips it
			end
			for _, u in { -57.5, -42.5 } do
				ab(bm, u - 0.5, u + 0.5, FY, FY + 8.6, -5.5, -4.5, hex("B0801C"), M.Metal)
				ab(bm, u - 2.2, u + 2.2, FY + 3.0, FY + 3.4, -5.2, 5.2, STL2, M.Metal)
			end
			-- along the south wall (inner face v 15): the benches' backs against it, the chest and the crate beside them,
			-- not in them (placement audit, 2026-11-01)
			K("GunBench", -64, 13.45, FACE.s, FY)
			K("CraftBench", -36, 13.2, FACE.s, FY)
			K("ToolChest", -26, 13.6, FACE.s, FY)
			K("TyreStack", -88, 12, 0, FY)
			K("TyreStack", -85, 8, 40, FY)
			K("Drum", -47.6, 12.6, 0, FY)
			K("Drum", -49.8, 12.8, 0, FY)
			K("JerryCans", -90, 3, 20, FY)
			cont("toolbox", "Mechanic's chest", -42.6, 13.8, FACE.s, FY, true)
			cont("crate", "Spare parts", -74.6, 12.6, 0, FY, true)
			cont("weaponbox", "Locked case", -30, -18, 0, FY, true)
			cont("locker", "Locker", -91, 12, FACE.w, FY, true)
			cont("medbag", "First aid bag", -92.6, 6, FACE.w, FY, true)
			for k, p in { { -72, -2 }, { -50, 10 }, { -32, -2 } } do
				lamp(p[1], 20, p[2], (k == 2) and 0 or 30, 0.9, nil, COLD, 4.4)
			end
			for _, s in { { "junk", 0.5, -62, 8, FY }, { "junk", 0.45, -40, -14, FY }, { "tech", 0.35, -30, 13.6, 3.1 } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
			point("MOTOR_SHOP", -58, FY, 4)
		end

		-- the parts store in the north: shelving, pallets, a mezzanine on the south wall and the stair up to the roof
		local function store(Y2, Y3)
			slab(bm, 29.15, 66.05, -62.8, -56.5, Y2, 0.8, GRID, M.DiamondPlate, nil)
			slab(bm, 61, 66.05, -66.5, -62.8, Y2, 0.8, GRID, M.DiamondPlate, nil)
			rail(bm, 29.15, -62.8, Y2, 61, -62.8, Y2)
			rail(bm, 29.15, -62.8, Y2, 29.15, -56.5, Y2)
			rail(bm, 61, -66.5, Y2, 66.05, -66.5, Y2)
			rail(bm, 61, -66.5, Y2, 61, -62.8, Y2)
			for _, c in { { 30, -62.2 }, { 45, -62.2 }, { 61.4, -66.1 } } do
				colm(bm, c[1], c[2], FY, Y2 - 0.8, 1.0, STL, M.Metal)
			end
			stairs(bm, 83.5, -58.9, FY, Y2 - FY, 1.5, 5, "-u", FY - 0.2, PAN2, M.Concrete, true, 0.65)
			stairs(bm, 66.1, -64.2, Y2, Y3 - Y2, 1.5, 4.6, "+u", FY - 0.2, PAN2, M.Concrete, true, 0.65)
			railRect(bm, SR[1], SR[2], SR[3], SR[4], Y3, { { "e", -1000, 1000 } })
			for k = 0, 3 do
				shelfP(36 + k * 12, -90.4, 8, FY, true)
			end
			for k = 0, 2 do
				shelfP(38 + k * 12, -78, 8, FY, true)
				shelfP(38 + k * 12, -75, 8, FY, true)
			end
			shelfP(30.3, -70, 8, FY, false)
			for _, p in { { 76, -84 }, { 80, -74 }, { 78, -42 }, { 74, -32 } } do
				crateP(p[1], p[2], FY, 2)
			end
			shelfP(36, -57.5, 8, Y2, true)
			shelfP(48, -57.5, 8, Y2, true)
			K("PalletBoxes", 60, -68, 0, FY)
			K("PalletBoxes", 66, -76, 20, FY)
			K("RollCage", 52, -66, 10, FY)
			cont("crate", "Spare parts", 40, -84, 0, FY, true)
			cont("toolbox", "Storeman's chest", 62, -90, FACE.n, FY, true)
			cont("techbox", "Spares console", 83.6, -69.5, FACE.e, FY, true) -- against the east wall, clear of the roof stair (v -66.5 to -61.9)
			cont("weaponbox", "Locked case", 72, -34, 0, FY, true)
			cont("medbag", "First aid bag", 70, -26, 0, FY, true)
			cont("drawer", "Storeman's desk", 34, -72, 90, FY, true)
			cont("crate", "Parts crate", 54, -58, 0, Y2, true)
			cont("toolbox", "Roof chest", 80, -88, FACE.n, Y3, true)
			cont("crate", "Roof crate", 72, -72, 0, Y3, true)
			for k, p in { { 45, -80 }, { 70, -80 }, { 78, -40 } } do
				lamp(p[1], 20, p[2], (k == 2) and 0 or 28, 0.9, nil, COLD, 4.4)
			end
			for _, s in { { "junk", 0.5, 50, -84, FY }, { "junk", 0.45, 80, -78, FY }, { "junk", 0.45, 76, -36, FY }, { "junk", 0.4, 58, -58, Y2 }, { "junk", 0.4, 60, -80, Y3 } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
			for _, p in { { 40, -84 }, { 56, -60 }, { 80, -50 } } do
				ab(bm, p[1] - 2.2, p[1] + 2.2, Y3, Y3 + 2.4, p[2] - 2.2, p[2] + 2.2, STL2, M.Metal)
			end
		end

		local function motorShop()
			local b = byId[30]
			site(b, "MOTOR SHOP + BOILER HOUSE", "BW_MOT", nil, 26)
			local RF = 46.6
			local RISE = (RF - FY) / 4
			local Y2, Y3, Y4 = FY + RISE, FY + 2 * RISE, FY + 3 * RISE
			shell(Y3, RF)
			cabin()
			hall(Y2, Y3, Y4, RF, RISE)
			wing(Y2, Y3)
			store(Y2, Y3)
		end

		-- the cellar: a pump hall (L.under BC); the cabin's stairs come down at its north-west, the exit zone is at its centre
		local function cellar()
			local un = UN.BC
			local hw, hd = siteU(un, "BOILER CELLAR", "BW_BC", 6)
			local b30 = byId[30]
			local Fm = CFrame.new(O.X + b30[4], 0, O.Z + b30[5]) * CFrame.Angles(0, -math.rad(b30[8]), 0)
			local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
			for _, c in { { MSH.u0, MSH.v0 }, { MSH.u1, MSH.v0 }, { MSH.u0, MSH.v1 }, { MSH.u1, MSH.v1 } } do
				local q = F:PointToObjectSpace(Fm * Vector3.new(c[1], 0, c[2]))
				x0, x1, z0, z1 = math.min(x0, q.X), math.max(x1, q.X), math.min(z0, q.Z), math.max(z1, q.Z)
			end
			dugout({ { u0 = -hw, u1 = hw, v0 = -hd, v1 = hd } }, {}, PAN2, { { u0 = x0, u1 = x1, v0 = z0, v1 = z1 } })
			local function nearShaft(u, v)
				return u > x0 - 3 and u < x1 + 3 and v > z0 - 3 and v < z1 + 3
			end
			for _, cu in { -36, -18, 18, 36 } do
				for _, cv in { -16, 16 } do
					if not nearShaft(cu, cv) and not reserved(cu, cv, 1.5) then
						colm(bm, cu, cv, UF, UC, 2.2, PAN2, M.Concrete)
					end
				end
			end
			-- five feed pumps along the south wall on their bases, with risers and a header
			for k = 0, 4 do
				local u = -40 + k * 17
				hcyl(bm, u, UF + 2.2, 27.5, 8, 3.4, hex("4D5A55"), M.Metal, 0)
				ab(bm, u - 4.4, u + 4.4, UF, UF + 0.7, 25.3, 29.7, STL, M.Metal)
				ab(bm, u + 3.6, u + 4.4, UF + 1, UF + 7, 27.1, 27.9, STL2, M.Metal)
			end
			ab(bm, -38, 40, UF + 6.4, UF + 7.2, 27.1, 27.9, STL2, M.Metal)
			for _, t in { { 40, 14 }, { 40, -12 } } do
				ucyl(bm, t[1], UF, t[2], 10.6, 9, hex("55635E"), M.Metal)
				ucyl(bm, t[1], UF + 10.6, t[2], 0.6, 9.4, hex("3D4543"), M.Metal)
			end
			for _, v in { -31, 22 } do
				ab(bm, -48, 48, UC - 2.4, UC - 1.8, v - 0.4, v + 0.4, STL2, M.Metal)
			end
			for _, u in { 6, 26 } do
				ab(bm, u - 0.4, u + 0.4, UF + 5.8, UF + 6.6, -30, 30, STL2, M.Metal)
			end
			for k, p in { { -48, 10 }, { -30, 10 }, { -12, -20 }, { -12, 20 }, { 12, -20 }, { 12, 20 }, { 32, -20 }, { 32, 22 }, { 0, 0 }, { 46, 0 } } do
				lamp(p[1], UC - 0.6, p[2], (k % 4 == 3) and 0 or 22, 0.8, nil, WARM, 3.6)
			end
			K("Drum", -48, 22, 0, UF)
			K("JerryCans", -45, 25, 30, UF)
			K("PipeValve", -34, 30.6, 0, UF)
			K("PipeValve", 2, 30.6, 0, UF)
			K("ElectricCabinet", 51.6, -22, FACE.e, UF)
			for _, c in { { "toolbox", "Pump engineer's chest", -48, -26, UF }, { "techbox", "Pump panel", 14, -31, UF }, { "crate", "Spare seals", 46, 24, UF }, { "locker", "Locker", 52, -6, UF },
				{ "weaponbox", "Locked case", 46, -28, UF }, { "medbag", "First aid bag", -50, 6, UF }, { "safe", "Boilerman's safe", 20, 31, UF }, { "drawer", "Valve room desk", -26, 30, UF } } do
				cont(c[1], c[2], c[3], c[4], 0, c[5], true)
			end
			tableP(-32, -24, 28, 32, UF, 2.8)
			for _, s in { { "junk", 0.5, -30, 18, UF }, { "junk", 0.5, 18, -20, UF }, { "vault", 0.4, 46, 20, UF }, { "junk", 0.45, -10, 26, UF }, { "tech", 0.3, -26, 30, UF + 2.9 } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
			point("BOILER_CELLAR", 0, UF, 0)
		end

		run("MOTOR SHOP + BOILER HOUSE", motorShop)
		run("BOILER CELLAR", cellar)
	end

	-- ═══ OLD WORKS (id 32) and the PUMP HOUSE (id 19) ═══════════════════════════════════════════════════════════
	do
		-- a personnel door in the wall `side` of the box u0..u1 x v0..v1 (the walls are t thick), s as in rectWalls
		local function pdoor(side, s, u0, u1, v0, v1, t, y0)
			local u, v = u0 + s, v0 + t / 2
			if side == "s" then
				v = v1 - t / 2
			elseif side == "w" then
				u, v = u0 + t / 2, v0 + s
			elseif side == "e" then
				u, v = u1 - t / 2, v0 + s
			end
			door(doorId(), "Door", u, v, INWARD[side], 4.0, 7.4, y0, nil, hex("5A5F57"))
		end
		local function wins(list, from, to, step, w, bt, tp)
			addWindows(list, from, to, step, w, bt, tp)
			return list
		end

		-- an unfinished two-storey concrete works: a one-storey hall in the west under a roof terrace, the two-storey block
		-- in the east with a stair to its deck and another to its roof
		local function oldWorks()
			local b = byId[32]
			site(b, "OLD WORKS", "BW_OW", nil, 14)
			local hw, hd = b[6] / 2, b[7] / 2
			local Y2, Y3 = FY + 11.6, FY + 23.2
			local XW, T = -1.7, 1.2
			slab(bm, -hw, hw, -hd, hd, FY, 1.0, FLR, M.Concrete, nil)
			slab(bm, -hw, XW, -hd, hd, Y2, 0.8, ROOF, M.Concrete, nil)
			slab(bm, XW, hw, -hd, hd, Y2, 0.8, FLR2, M.Concrete, { { 16.7, 21.5, 3.2, 17.8 } })
			slab(bm, XW, hw, -hd, hd, Y3, 0.8, ROOF, M.Concrete, { { 21.5, 38.5, -28.9, -24.1 } })
			-- the hall
			rectWalls(bm, -hw, XW, -hd, hd, 0, Y2 - 0.8, T, PAN, M.Concrete, {
				skip = { e = true },
				n = wins({ { 14, 4.2, 0, 7.9 } }, 6, 32, 9, 5, 4.5, 9),
				s = wins({ { 20, 12, 0, 11 }, { 30, 4.2, 0, 7.9 } }, 6, 32, 9, 5, 4.5, 9),
				w = wins({ { 30, 12, 0, 11 } }, 8, 54, 12, 5, 4.5, 9),
			})
			pdoor("n", 14, -hw, XW, -hd, hd, T, FY)
			pdoor("s", 30, -hw, XW, -hd, hd, T, FY)
			-- the block: ground floor, then the upper floor
			rectWalls(bm, XW, hw, -hd, hd, 0, Y2, T, PAN, M.Concrete, {
				skip = { w = true },
				n = wins({ { 30, 4.2, 0, 7.9 } }, 6, 38, 9, 5, 4.5, 9),
				s = wins({ { 12, 4.2, 0, 7.9 }, { 28, 4.2, 0, 7.9 } }, 6, 38, 9, 5, 4.5, 9),
				e = wins({ { 24, 4.2, 0, 7.9 } }, 8, 54, 12, 5, 4.5, 9),
			})
			pdoor("n", 30, XW, hw, -hd, hd, T, FY)
			pdoor("s", 12, XW, hw, -hd, hd, T, FY)
			pdoor("s", 28, XW, hw, -hd, hd, T, FY)
			pdoor("e", 24, XW, hw, -hd, hd, T, FY)
			rectWalls(bm, XW, hw, -hd, hd, Y2, Y3 - 0.8 - Y2, T, PAN, M.Concrete, {
				skip = { w = true },
				n = wins({}, 5, 38, 7, 6, 3.5, 9),
				s = wins({}, 5, 38, 7, 6, 3.5, 9),
				e = wins({}, 6, 56, 9, 6, 3.5, 9),
			})
			-- the dividing wall: two gates and a door below, a door to the terrace and windows above
			local DW = { { 12, 12, 0, 10.4 }, { 46, 12, 0, 10.4 }, { 29.6, 4.2, 0, 7.9 } }
			wl(bm, XW, -hd + T, XW, hd - T, 0, Y2, T, PAN2, M.Concrete, DW)
			wl(bm, XW, -hd + T, XW, hd - T, Y2, Y3 - 0.8 - Y2, T, PAN2, M.Concrete, { { 29.6, 4.2, 0, 7.9 }, { 12, 6, 3, 8 }, { 46, 6, 3, 8 } })
			door(doorId(), "Door", XW, 0, "+u", 4.0, 7.4, FY, nil, hex("5A5F57"))
			door(doorId(), "Terrace door", XW, 0, "-u", 4.0, 7.4, Y2, nil, hex("5A5F57"))
			rectWalls(bm, -hw, XW, -hd, hd, Y2, 2.4, 0.8, BRK2, M.Brick, { skip = { e = true } })
			rectWalls(bm, XW, hw, -hd, hd, Y3, 2.4, 0.8, BRK2, M.Brick, nil)
			-- the stairs: ground to the deck (ladder-30), deck to the roof
			stairs(bm, 19.1, 3.5, FY, Y2 - FY, 1.25, 4.6, "+v", FY - 0.2, PAN2, M.Concrete, true, 0.65)
			railRect(bm, 16.7, 21.5, 3.2, 17.8, Y2, { { "s", -1000, 1000 } })
			stairs(bm, 38, -26.5, Y2, Y3 - Y2, 1.4, 4.4, "-u", Y2 - 0.1, PAN2, M.Concrete, true, 0.65)
			railRect(bm, 21.5, 38.5, -28.9, -24.1, Y3, { { "w", -1000, 1000 } })
			-- columns of the unfinished block (some with rebar stubs on the roof)
			for _, cu in { 8, 30 } do
				for _, cv in { -20, 0, 20 } do
					if not reserved(cu, cv, 1.5) then
						colm(bm, cu, cv, FY, Y2 - 0.8, 2.0, PAN2, M.Concrete)
						colm(bm, cu, cv, Y2, Y3 - 0.8, 2.0, PAN2, M.Concrete)
					end
				end
			end
			for _, cu in { -30, -16 } do
				for _, cv in { -16, 16 } do
					colm(bm, cu, cv, FY, Y2 - 0.8, 2.0, PAN2, M.Concrete)
				end
			end
			-- the site office on the ground floor of the block
			room({
				u0 = 2, u1 = 14.4, v0 = 19.5, v1 = 29.6, y0 = FY, h = 9.6, ceil = true, skip = { s = true }, finish = "ZR_WallpaperB",
				doors = { n = { { s = 6 } } }, windows = { e = { { 5, 4, 3.5, 6.5 } } },
			})
			tableP(4, 10, 24.5, 27, FY, 2.8)
			cont("drawer", "Site desk", 7, 25.8, 0, FY, true)
			cont("safe", "Site safe", 13, 23, FACE.e, FY, true)
			lamp(8, 9.6, 24, 16, 0.7, nil, WARM, 2.6)
			-- the hall: machine tools, a forklift, pallets
			K("Forklift", -24, 14, 40, FY)
			K("CraftBench", -37.8, -20, FACE.w, FY)
			K("ToolChest", -37, -12, FACE.w, FY)
			K("PalletBoxes", -12, -22, 0, FY)
			K("PalletBoxes", -7, -24, 20, FY)
			K("Generator", -22, 28, FACE.s, FY)
			K("Drum", -34, 24, 0, FY)
			K("Drum", -32, 25, 0, FY)
			K("TyreStack", -8, 24, 30, FY)
			crateP(-28, -26, FY, 2)
			crateP(-20, -24, FY, 1)
			-- the block's deck: building stores
			for _, p in { { 8, -26 }, { 14, -24 }, { 30, 24 }, { 24, 26 } } do
				crateP(p[1], p[2], Y2, 2)
			end
			K("PalletBoxes", 32, -10, 0, Y2)
			K("Drum", 36, 12, 0, Y2)
			for _, c in { { "toolbox", "Builder's toolbox", -38, 8, FY }, { "crate", "Cement bags", -14, 0, FY }, { "techbox", "Site electrics", -37, 26, FY }, { "locker", "Locker", -38, 18, FY },
				{ "toolbox", "Builder's toolbox", 36, -20, FY }, { "medbag", "First aid bag", 24, 28, FY }, { "crate", "Cement bags", 6, -26, Y2 }, { "weaponbox", "Hidden case", 36, 24, Y2 },
				{ "toolbox", "Deck toolbox", 12, 6, Y2 }, { "techbox", "Site electrics", 28, -2, Y2 }, { "crate", "Roof crate", 4, 20, Y2 }, { "toolbox", "Roof chest", 30, -20, Y3 },
				{ "crate", "Roof crate", 34, 22, Y3 } } do
				cont(c[1], c[2], c[3], c[4], 0, c[5], true)
			end
			for k, p in { { -22, -8 }, { -22, 12 }, { 20, -10 }, { 20, 24 } } do
				lamp(p[1], Y2 - 2.4, p[2], (k % 2 == 1) and 24 or 0, 0.8, nil, COLD, 3.6)
			end
			for _, s in { { "junk", 0.5, -26, -14, FY }, { "junk", 0.45, -30, 24, FY }, { "tech", 0.3, -36, -12, 4.3 }, { "junk", 0.45, 12, -20, FY }, { "junk", 0.45, 34, 6, Y2 },
				{ "junk", 0.4, 10, 26, Y2 }, { "junk", 0.4, 28, 10, Y3 }, { "junk", 0.4, -20, -6, Y2 } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
		end

		-- a two-storey brick pump hall: the pumps stand in a double-height void, a gallery runs round it, two stairs up to it
		local function pumpHouse()
			local b = byId[19]
			site(b, "PUMP HOUSE", "BW_PH", nil, 12)
			local hw, hd = b[6] / 2, b[7] / 2
			local T = 1.4
			local Y2 = FY + 11.6
			shell({
				u0 = -hw, u1 = hw, v0 = -hd, v1 = hd, h = 23.2, t = T, col = BRK, mat = M.Brick, roof = "gable", pitch = 12, roofCol = ROOF,
				gates = { n = { { s = 37.4, w = 12, h = 12 } }, s = { { s = 60, w = 9, h = 10.4 } } },
				doors = { n = { { s = 10 } }, s = { { s = 12 } }, w = { { s = 25 } }, e = { { s = 12 } } },
				windows = {
					n = { from = 14, to = 62, step = 12, w = 4, b = 14, top = 20 }, s = { from = 20, to = 62, step = 12, w = 4, b = 14, top = 20 },
					w = { from = 10, to = 40, step = 15, w = 4, b = 14, top = 20 }, e = { from = 24, to = 40, step = 15, w = 4, b = 14, top = 20 },
				},
				cu = { -28, -9.3, 9.3, 28 }, cv = { -14, 14 }, lampsU = { -22, 0, 22 }, lampsV = { 0 }, lampY = 20,
			})
			local VOID = { -22, 22, -11, 11 }
			local SH1 = { -35, -19.5, -21.4, -16.6 }
			local SH2 = { 19.5, 35, 16.6, 21.4 }
			slab(bm, -hw + T, hw - T, -hd + T, hd - T, Y2, 0.8, FLR2, M.Concrete, { VOID, SH1, SH2 })
			railRect(bm, VOID[1], VOID[2], VOID[3], VOID[4], Y2, nil)
			railRect(bm, SH1[1], SH1[2], SH1[3], SH1[4], Y2, { { "e", -1000, 1000 } })
			railRect(bm, SH2[1], SH2[2], SH2[3], SH2[4], Y2, { { "w", -1000, 1000 } })
			stairs(bm, -35, -19, FY, Y2 - FY, 1.35, 4.6, "+u", FY - 0.2, PAN2, M.Concrete, true, 0.65)
			stairs(bm, 35, 19, FY, Y2 - FY, 1.35, 4.6, "-u", FY - 0.2, PAN2, M.Concrete, true, 0.65)
			-- the pumps: four horizontal pumps with motors on bases, a suction header and risers, an overhead crane beam
			for k = 0, 3 do
				local u = -15 + k * 10
				ab(bm, u - 4.4, u + 4.4, FY, FY + 0.8, -2.6, 2.6, STL, M.Metal)
				hcyl(bm, u - 0.6, FY + 2.6, 0, 6.4, 3.4, hex("4D5A55"), M.Metal, 0)
				ab(bm, u + 2.2, u + 4.2, FY + 0.8, FY + 3.6, -1.6, 1.6, hex("3D4543"), M.Metal)
				ab(bm, u - 0.4, u + 0.4, FY + 3.8, FY + 9.6, -0.4, 0.4, STL2, M.Metal)
			end
			ab(bm, -19, 19, FY + 9.2, FY + 10, -0.4, 0.4, STL2, M.Metal)
			ab(bm, -24, 24, FY + 3.4, FY + 4.0, -8.6, -8.0, STL2, M.Metal)
			for _, u in { -20, -4, 12, 24 } do
				ab(bm, u - 0.3, u + 0.3, FY, FY + 3.4, -8.6, -8.0, STL2, M.Metal)
			end
			for _, v in { -12, 12 } do
				ab(bm, -hw + T, hw - T, 19.6, 20.4, v - 0.5, v + 0.5, STL, M.Metal)
			end
			K("PipeValve", 24, -8.3, 0, FY)
			K("PipeValve", -26, -8.3, 0, FY)
			K("ElectricCabinet", hw - T - 1, -14, FACE.e, FY)
			K("Generator", 6, hd - T - 3.2, FACE.s, FY)
			K("WorkLight", -30, 6, 20, FY)
			K("Drum", -32, 18, 0, FY)
			K("JerryCans", -30, 20, 20, FY)
			for _, c in { { "toolbox", "Pump engineer's chest", -34, 8, FY }, { "techbox", "Pump panel", 30, -6, FY }, { "crate", "Spare seals", 30, 4, FY }, { "locker", "Locker", -hw + 1.8, -12, FY },
				{ "medbag", "First aid bag", 33, 12, FY }, { "weaponbox", "Locked case", -30, -13.5, Y2 }, { "toolbox", "Gallery chest", 30, 13.5, Y2 },
				{ "techbox", "Valve panel", 0, -23.4, Y2, FACE.n }, { "crate", "Gallery crate", 0, 21, Y2 }, { "jacket", "Engineer's coat", hw - T - 1, 6, FY } } do
				-- the gallery case and chest stood over the stair shafts (SH1, SH2), 7.7 studs over the floor below; the valve
				-- panel faced the wall (placement audit, 2026-11-01); the first aid bag sat in the east stair's first steps
				-- (LOS probe, 2026-11-07)
				cont(c[1], c[2], c[3], c[4], c[6] or 0, c[5], true)
			end
			cont("safe", "Chief engineer's safe", 34, 8, FACE.e, Y2, true)
			for _, s in { { "junk", 0.5, -26, 12, FY }, { "junk", 0.45, 22, -16, FY }, { "tech", 0.3, 30, -4, 3.1 }, { "junk", 0.45, -10, -21, Y2 }, { "junk", 0.4, 12, 21, Y2 }, { "vault", 0.4, 33, 10, Y2 + 3 } } do
				lt(s[1], s[2], s[3], s[4], s[5] + 0.1)
			end
		end

		run("OLD WORKS", oldWorks)
		run("PUMP HOUSE", pumpHouse)
	end

	-- ═══ the four STORAGE BLOCKS (ids 8-11): long steel-framed sheds, open loading gates on the north side ═════════
	do
		local function storageBlock(id, name, prefix)
			local b = byId[id]
			site(b, name, prefix, nil, 8)
			local w, d = b[6], b[7]
			local hw, hd = w / 2, d / 2
			local nG = math.max(2, math.floor(w / 30))
			local gn = {}
			for k = 1, nG do
				table.insert(gn, { s = w * (k - 0.5) / nG, w = 12, h = 12 })
			end
			local cu = {}
			local nC = math.floor(w / 20)
			for k = 0, nC do
				table.insert(cu, -hw + 10 + k * (w - 20) / nC)
			end
			shell({
				u0 = -hw, u1 = hw, v0 = -hd, v1 = hd, h = 16, t = 1.0, col = SHT, mat = M.CorrodedMetal, roof = "gable", pitch = 8, roofCol = ROOF,
				gates = { n = gn, w = { { s = hd, w = 12, h = 12 } }, e = { { s = hd, w = 12, h = 12 } } },
				doors = { s = { { s = 10 }, { s = w - 14 } } },
				windows = { s = { from = 22, to = w - 22, step = 16, w = 5, b = 9, top = 13 } },
				cu = cu, cv = { -hd + 4, hd - 4 }, lampsU = { -hw * 0.6, 0, hw * 0.6 }, lampsV = { 0 }, lampY = 12.5,
			})
			-- racking on the back wall, pallets near the gates, stacks of crates
			for k = 0, 1 do
				K("PalletRack", -hw + 14 + k * 16.5, hd - 4.0, 0, FY)
				K("PalletRack", hw - 14 - k * 16.5, hd - 4.0, 0, FY)
			end
			K("PalletBoxes", -hw * 0.3, -hd + 6, 10, FY)
			K("PalletBoxes", hw * 0.35, -hd + 8, -15, FY)
			for _, f in { -0.8, -0.35, 0.2, 0.7 } do
				crateP(hw * f, -hd + 14, FY, 2)
				crateP(hw * f + 3.5, -hd + 15, FY, 1)
			end
			for _, c in { { "crate", "Stored goods", -0.55, -6 }, { "crate", "Stored goods", 0.1, 8 }, { "crate", "Stored goods", 0.6, -4 }, { "toolbox", "Storekeeper's chest", -0.92, hd - 3 },
				{ "weaponbox", "Locked case", 0.9, hd - 3 }, { "medbag", "First aid bag", 0.05, hd - 3 } } do
				cont(c[1], c[2], hw * c[3], c[4], 0, FY, true)
			end
			for _, s in { { "junk", 0.5, -0.5, 4 }, { "junk", 0.45, 0.3, -10 }, { "junk", 0.45, 0.8, 12 }, { "junk", 0.4, -0.15, hd - 6 }, { "tech", 0.3, 0.55, hd - 5 } } do
				lt(s[1], s[2], hw * s[3], s[4], FY + 0.1)
			end
		end

		run("STORAGE BLOCK NW", storageBlock, 8, "STORAGE BLOCK NW", "BW_SB1")
		run("STORAGE BLOCK NE", storageBlock, 9, "STORAGE BLOCK NE", "BW_SB2")
		run("STORAGE BLOCK SW", storageBlock, 10, "STORAGE BLOCK SW", "BW_SB3")
		run("STORAGE BLOCK SE", storageBlock, 11, "STORAGE BLOCK SE", "BW_SB4")
	end

	-- ═══ the TANK FARM: four fuel tanks (ids 12, 13, 15, 16) and the two pump platforms (14 and 17) ═══════════════
	do
		local TANKCOL = { hex("8A9288"), hex("93785E"), hex("7F8A8E"), hex("8E8576") }
		-- a standing tank: a steel shell on a concrete ring with bands, a spiral stair up the outside (a post every third step
		-- carries the handrail) and a roof deck with a railed catwalk across it
		local function tank(id, name, prefix, ci)
			local b = byId[id]
			site(b, name, prefix, nil, 2)
			local R = b[6] / 2 - 0.5
			local H = 22
			local top = 0.9 + H + 0.8
			ucyl(bm, 0, 0, 0, 0.9, R * 2 + 3, PAN2, M.Concrete)
			ucyl(bm, 0, 0.9, 0, H, R * 2, TANKCOL[ci], M.Metal)
			for _, y in { 6, 12, 18 } do
				ucyl(bm, 0, y, 0, 0.5, R * 2 + 0.7, STL, M.Metal)
			end
			ucyl(bm, 0, 0.9 + H, 0, 0.8, R * 2 + 0.6, ROOF, M.Metal)
			-- the stair: 36 steps sweeping 150 degrees round the shell, starting at a different bearing on each tank
			local N = 36
			local rc = R + 2.3
			local dth = 2.4 / rc
			local th0 = math.rad(30 + ci * 75)
			local dr = (top - 0.5) / N
			-- a task's mark: on the ground by the foot of the stair, outside the pad
			point(prefix .. "_STAIR", (R + 6) * math.cos(th0 - math.rad(12)), 0, (R + 6) * math.sin(th0 - math.rad(12)))
			local posts = {}
			for k = 1, N do
				local th = th0 + (k - 1) * dth
				local yt = 0.5 + k * dr
				bc(bm, 4.0, 0.45, rc * dth + 0.35, rc * math.cos(th), yt - 0.225, rc * math.sin(th), STL2, M.Metal, -math.deg(th))
				if k % 3 == 1 then
					local ro = R + 4.2
					local pu, pv = ro * math.cos(th), ro * math.sin(th)
					ab(bm, pu - 0.15, pu + 0.15, yt, yt + 3.4, pv - 0.15, pv + 0.15, STL, M.Metal)
					if k % 4 == 1 and yt > 2.2 then
						ab(bm, pu - 0.25, pu + 0.25, 0, yt - 0.45, pv - 0.25, pv + 0.25, STL, M.Metal)
					end
					table.insert(posts, Vector3.new(pu, yt + 3.3, pv))
				end
			end
			for k = 1, #posts - 1 do
				beam(bm, posts[k], posts[k + 1], 0.25, 0.25, STL, M.Metal)
			end
			-- the roof: the catwalk runs from where the stair arrives across the centre and a little past it
			local the = th0 + (N - 1) * dth
			local cu, cv = math.cos(the), math.sin(the)
			local mid = 0.15 * R - 0.5
			bc(bm, 1.7 * R - 1, 0.3, 3, cu * mid, top + 0.15, cv * mid, hex("4D5553"), M.DiamondPlate, -math.deg(the))
			for _, s in { -1.6, 1.6 } do
				local ou, ov = -cv * s, cu * s
				rail(bm, cu * (R - 1) + ou, cv * (R - 1) + ov, top + 0.3, -cu * R * 0.7 + ou, -cv * R * 0.7 + ov, top + 0.3, STL)
			end
			ab(bm, -1.8, 1.8, top, top + 1.6, -1.8, 1.8, STL, M.Metal)
			ucyl(bm, 0, top, 9, 2.4, 1.4, STL2, M.Metal)
			ucyl(bm, 0, top, -9, 2.4, 1.4, STL2, M.Metal)
			-- a level gauge and a fill pipe down the shell on the side away from the stair
			local bu, bv = -cu * (R + 0.5), -cv * (R + 0.5)
			ab(bm, bu - 0.3, bu + 0.3, 0.9, top - 1, bv - 0.3, bv + 0.3, STL2, M.Metal)
		end

		-- a pump platform: a concrete pad with curbs, two pump skids on the centre line, pipe racks along both long sides, a
		-- control hut at the corner and two light poles. PMC spawns stand at |v| of about 9 to 10 on the north one: the middle
		-- strip and the ends stay free
		local function platform(id, name, prefix)
			local b = byId[id]
			site(b, name, prefix, nil, 4)
			-- 14.5 long each way: the traced 43 studs reached 6 to 7 studs into the fuel tanks at both ends (31 studs apart
			-- wall to wall), so the tank walls cut through the deck, its drums and its crate (placement audit, 2026-11-01)
			local hw, hd = math.min(b[6] / 2, 14.5), b[7] / 2
			slab(bm, -hw, hw, -hd, hd, FY, 0.9, hex("6F7168"), M.Concrete, nil)
			for _, s in { -1, 1 } do
				ab(bm, -hw, -7, FY, FY + 0.7, s * (hd - 0.5) - 0.4, s * (hd - 0.5) + 0.4, PAN2, M.Concrete)
				ab(bm, 7, hw, FY, FY + 0.7, s * (hd - 0.5) - 0.4, s * (hd - 0.5) + 0.4, PAN2, M.Concrete)
			end
			for _, u in { -7.5, 7.5 } do
				ab(bm, u - 4.4, u + 4.4, FY, FY + 0.6, -2.8, 2.8, hex("5C5E58"), M.Concrete)
				hcyl(bm, u - 0.8, FY + 2.4, 0, 6.4, 3.2, hex("4D5A55"), M.Metal, 0)
				ab(bm, u + 2.2, u + 4.2, FY + 0.6, FY + 3.4, -1.5, 1.5, hex("3D4543"), M.Metal)
				ab(bm, u - 0.4, u + 0.4, FY + 3.8, FY + 5.8, -0.4, 0.4, STL2, M.Metal)
			end
			ab(bm, -12, 12, FY + 5.4, FY + 6.2, -0.4, 0.4, STL2, M.Metal)
			for _, v in { -12.4, 12.4 } do
				ab(bm, -hw + 2, hw - 2, FY + 3.4, FY + 4.0, v - 0.3, v + 0.3, STL2, M.Metal)
				ab(bm, -hw + 2, hw - 2, FY + 4.4, FY + 5.0, v - 0.3, v + 0.3, STL, M.Metal)
				for _, u in { -hw + 3, -5, 5, hw - 3 } do
					ab(bm, u - 0.25, u + 0.25, FY, FY + 5.0, v - 0.25, v + 0.25, STL, M.Metal)
				end
			end
			for _, u in { -hw + 1.6, hw - 1.6 } do
				ucyl(bm, u, FY, 0, 4, 0.9, STL2, M.Metal)
				ucyl(bm, u, FY, 5, 4, 0.9, STL, M.Metal)
				ucyl(bm, u, FY, -5, 4, 0.9, STL, M.Metal)
			end
			-- the hut, between the north pipe rack (v 12.4) and the west tanks (v 5): it stood across the rack and its post,
			-- and at 5.4 studs deep its west wall was too short for the door's opening, so the door had a solid wall
			-- behind it (placement audit, 2026-11-01). 6 x 6.6 now, the door in the east wall opening out onto the deck.
			room({
				u0 = -hw + 2.8, u1 = -hw + 8.8, v0 = 5.4, v1 = 12.0, y0 = FY, h = 8, ceil = true, finish = "ZR_Whitewash",
				doors = { e = { { s = 3.3, dir = "+u" } } }, windows = { n = { { 3.0, 2.6, 3.5, 6 } } },
			})
			lamp(-hw + 5.8, FY + 7.4, 8.7, 14, 0.7, nil, WARM, 2.2)
			cont("techbox", "Pump controls", -hw + 4.1, 7.5, FACE.w, FY, true) -- the fuse box's origin is 1 stud behind its middle
			cont("toolbox", "Pump chest", 2.5, 8.6, 0, FY, true) -- out on the deck between the pumps: the hut has no room
			for _, u in { -hw + 3, hw - 3 } do
				colm(bm, u, -8, FY, 13, 0.6, STL, M.Metal) -- clear of the pump bases
				lamp(u, 13.2, -8, 26, 0.9, nil, COLD, 2.4)
			end
			K("PipeValve", -hw + 1.6, 10, 0, FY)
			K("Drum", hw - 3, -10, 0, FY)
			K("Drum", hw - 5, -11, 0, FY)
			cont("crate", "Spare fittings", hw - 4, 9, 0, FY, true)
			lt("junk", 0.5, -2, 5, FY + 0.1)
			lt("junk", 0.4, 12, -6, FY + 0.1)
			lt("tech", 0.3, -hw + 6.6, hd - 3.4, FY + 3)
		end

		run("FUEL TANK 1", tank, 12, "FUEL TANK 1", "BW_TK1", 1)
		run("FUEL TANK 2", tank, 13, "FUEL TANK 2", "BW_TK2", 2)
		run("FUEL TANK 3", tank, 15, "FUEL TANK 3", "BW_TK3", 3)
		run("FUEL TANK 4", tank, 16, "FUEL TANK 4", "BW_TK4", 4)
		run("PUMP PLATFORM N", platform, 14, "PUMP PLATFORM N", "BW_PP1")
		run("PUMP PLATFORM S", platform, 17, "PUMP PLATFORM S", "BW_PP2")
	end

	-- ═══ the OLD PUMPS CELLAR (L.under OP): the pump cellar under the old gas station; the stair comes down in the shaft ladder-39 ═══
	do
		local function oldPumpsCellar()
			local un = UN.OP
			local hw, hd = siteU(un, "OLD PUMPS CELLAR", "BW_OP", 8)
			local pit = pitRect(stairsEntry("ladder-39"))
			local room = { u0 = -hw, u1 = hw, v0 = -hd, v1 = hd }
			dugout({ room }, { pit }, PAN2)
			bunkerStairs(pit)
			-- two buried fuel tanks along the east wall with their pipework, a pump bench, shelves and stores in the south
			for _, v in { -8, 9 } do
				hcyl(bm, 5.6, UF + 2.7, v, 12, 5, hex("55635E"), M.Metal, 90)
				ab(bm, 3.4, 7.8, UF, UF + 0.6, v - 6.4, v + 6.4, STL, M.Metal)
				ucyl(bm, 5.6, UF + 5.2, v, 1.6, 1.4, STL2, M.Metal)
			end
			ab(bm, 5.2, 6.0, UC - 2.4, UC - 1.8, -15, 15, STL2, M.Metal)
			ab(bm, 2, 6, UC - 2.4, UC - 1.8, -8.4, -7.6, STL2, M.Metal)
			-- 18.8 x 34.4: the stair comes down the north-west quarter (u -8 to -2, v -18 to 0) and the tanks fill the east
			-- side, so the shelf and the bench line the west wall south of the stair and the rest stands along the south
			-- wall. The first layout put the shelf, the bench and two containers in one another, a safe inside a tank and a
			-- crate in the wall; the station desk is gone, as it had no room (placement audit, 2026-11-02).
			K("PipeValve", 8.2, -1.4, 0, UF)
			K("StorageShelf", -8.35, 4.2, FACE.w, UF)
			K("CraftBench", -7.6, 12.6, FACE.w, UF)
			K("Drum", -0.6, 16.1, 0, UF)
			K("Drum", 1.5, 16.1, 0, UF)
			K("JerryCans", -0.5, 13.0, 20, UF)
			for k, p in { { -5, -12 }, { 0, 4 }, { -3, 14 }, { 4, -12 } } do
				lamp(p[1], UC - 0.6, p[2], (k % 3 == 0) and 0 or 20, 0.8, nil, WARM, 3)
			end
			for _, c in { { "toolbox", "Pump fitter's chest", -3.5, 16.25, FACE.s, UF }, { "crate", "Old stock", 1.0, -15.1, 0, UF },
				{ "weaponbox", "Locked case", 5.5, 16.3, 0, UF }, { "medbag", "First aid bag", 9.2, 0.5, FACE.e, UF + 4 },
				{ "safe", "Station safe", 7.5, -15.6, FACE.n, UF } } do
				cont(c[1], c[2], c[3], c[4], c[5], c[6], true)
			end
			for _, s in { { "junk", 0.5, -2, 10 }, { "junk", 0.45, 4, 12 }, { "vault", 0.4, 7, 14 }, { "tech", 0.3, -8, 11 } } do
				lt(s[1], s[2], s[3], s[4], UF + (s[1] == "tech" and 3.1 or 0.1))
			end
		end

		run("OLD PUMPS CELLAR", oldPumpsCellar)
	end

	-- ── build everything ─────────────────────────────────────────────────────────────────────────────────
	run("STORE 3", store3, byId[22])
	run("STORE 4", store4)
	run("STORE 7", store7)
	run("STORE 17", store17)
	run("THE DEPOT", depot)
	run("RED STORES", redStores)
	run("THE BASTION", bastion)
	run("BUNKER K-13", bunkerK13)
	run("THE DERRICK", derrick)
	run("THE FRAME", frame)
	run("BUNKER K-11", k11)
	run("SMUGGLERS' HOLE", smugglers)

	-- the power lever starts every raid off, whatever order the structures went up in: the lamps and panels it switches
	-- (STORE 4 basement, K-13) go to their off state now
	local lever = W.switches and W.switches.BORDER_STORE4
	if lever and lever.onChange then
		lever.onChange(false)
	end

	-- summary
	local nParts, nShadow = 0, 0
	for _, d in works:GetDescendants() do
		if d:IsA("BasePart") then
			nParts += 1
		elseif d:IsA("Light") and d.Shadows then
			nShadow += 1
		end
	end
	count.works = nParts
	print(string.format(
		"[ZR] Border works: %d parts, %d kit props, %d containers, %d loose spots, %d doors, %d lamps, %d lights with shadows, %d props skipped, %d failed",
		nParts, nProps, nCont, nLoose, nDoors, nLamps, nShadow, nSkip, #failed
	))
	if #droppedOpenings > 0 then
		warn("[ZR] Border works: " .. #droppedOpenings .. " openings left out (wall built solid): " .. table.concat(droppedOpenings, "; "))
	end
end

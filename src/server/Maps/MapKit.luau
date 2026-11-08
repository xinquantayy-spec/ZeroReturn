--!nonstrict
-- M13 building helpers for map modules, in map-local coordinates (x east, z south, heights are world y):
-- walls with holes, slabs with holes, railings, stairs, furniture, hanging lamps, bunks, pitched roofs, timber
-- cabins, multi-storey blocks, army trucks, nature-kit pieces and chain-link fences.
-- Usage: local H = require(script.Parent.MapKit)(kit, origin)
-- art-5b: H.k5Flight / H.k5Rail place the Kit5 stair flights and railings (merged meshes) where the batch is loaded;
-- every stair and railing builder tries them first and keeps its own parts as the fallback (docs/look/MODULAR_KIT.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local AssetMeta = require(Shared:WaitForChild("AssetMeta"))
local Wear = require(Shared:WaitForChild("Wear"))
local KitMeta = require(Shared:WaitForChild("KitMeta"))
local Kit = require(script.Parent:WaitForChild("Kit"))

-- ── art-5b modular kit (ZR_Kit5, assets/blender_scripts/build_kit5.py, docs/look/MODULAR_KIT.md) ──────────────────
-- A stair flight is one merged MeshPart (baked shading) plus one invisible ramp the feet, bullets and the AI meet, as
-- Tarkov does it (a flight's render mesh, a `Stairs_ramp` movement collider and a ballistic collider). A railing is a
-- MeshPart module per stretch plus one invisible collider that stops bodies and passes bullets and sight (Tarkov's
-- LowPolyCollider: thin rails are no cover). Flight variants are per step count (scaling a mesh scales its details, so
-- a count is never stretched to another count), modelled at K5.H0 riser, K5.T0 tread and K5.W0 width and scaled to the
-- flight within the tolerances below; a railing module per nominal length, stretched along its length by at most
-- K5.STRETCH. Without the batch (not uploaded, still loading) or without a variant that fits, every builder keeps its
-- part-built fallback, so the map plays the same either way.
local K5 = {
	H0 = 0.5, T0 = 0.8, W0 = 4, -- every flight variant: riser, tread, width (studs; build_kit5.py's FLIGHT)
	SKIRT = 0.25, -- a solid flight's mesh reaches this far below its foot
	SY = { 0.7, 1.45 }, -- riser scale limits (0.35 .. 0.73 studs)
	SZ = { 0.4, 3.5 }, -- tread scale limits (0.32 .. 2.8 studs)
	SX = { C = { 0.4, 16 }, O = { 0.4, 16 }, E = { 0.4, 16 }, S = { 0.6, 1.8 } }, -- width: stringers are details
	HAND_H0 = { A = 0.5, B = 0.65 }, -- handrail families by riser (a handrail is never stretched more than HAND_SY)
	HAND_SY = 0.14,
	RAIL_LENGTHS = { 0.56, 0.67, 0.8, 0.96, 1.16, 1.39, 1.67, 2, 2.4, 2.9, 3.5, 4.1, 5, 6, 7.2, 8.6, 10.3, 12.4, 14.9, 17.8, 21.4, 25.7, 30.8, 37, 44.4, 53.3, 64 }, -- build_kit5.py's RAILS
	STRETCH = 0.11, -- a railing module may be stretched or squeezed this much along its length
	RAIL_SPLIT = 64, -- runs longer than this are cut into equal modules (32 to 64 studs each)
	RAIL_H = 3.45, -- the railing collider's height above the deck (today's posts are 3.4)
	MOVE_GROUP = "ZR_Move", -- movement-only colliders: bodies and ordinary rays meet them, bullets (ZR_Shot) and sight (ZR_Sight) pass
	RAMP_T = 0.6, -- an open flight's ramp slab, thickness across the slope
	FILL = 1.0, -- a solid flight filled deeper than this below its foot gets a plain block under its mesh (else the skirt hides it)
	enabled = true, -- KitTests turns it off to build the same map with the fallbacks
}
local moveReady = nil
local function moveGroup()
	if moveReady == nil then
		moveReady = pcall(function()
			for _, g in { K5.MOVE_GROUP, "ZR_Shot", "ZR_Sight" } do
				if not PhysicsService:IsCollisionGroupRegistered(g) then
					PhysicsService:RegisterCollisionGroup(g)
				end
			end
			PhysicsService:CollisionGroupSetCollidable(K5.MOVE_GROUP, "ZR_Shot", false)
			PhysicsService:CollisionGroupSetCollidable(K5.MOVE_GROUP, "ZR_Sight", false)
		end)
	end
	return moveReady
end
-- a Kit5 prop is usable when its metadata (KitMeta, from tools/kit_meta.py) and its meshes (ServerStorage.ZR_Assets) are in
local function k5Ready(name)
	return K5.enabled and KitMeta.props[name] ~= nil and Kit.has(name)
end
-- a Kit5 placement is structure, not a prop: without the "Kit" attribute the tidy pass (Maps/Tidy.luau) never moves it or
-- removes it from beside a doorway, as it leaves the part-built stairs and rails alone
local function structure(m, name)
	if m then
		m:SetAttribute("Kit", nil)
		m:SetAttribute("Kit5", name)
	end
	return m
end
local function within(x, lim)
	return x >= lim[1] - 1e-6 and x <= lim[2] + 1e-6
end
-- an invisible collider; group: the movement-only group (railings) or nil (Default: bullets, sight and bodies)
local function collider(parent, cls, size, cf, mat, name, group)
	local p = Instance.new(cls)
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CastShadow = false
	p.Material = mat
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if group then
		p.CollisionGroup = group
	end
	p:SetAttribute("NoDetail", true)
	p.Parent = parent
	return p
end
-- the variant names (build_kit5.py makes the same list)
local function flightName(style, n)
	return "K5Stair" .. style .. n
end
local function handName(fam, n)
	return "K5Hand" .. fam .. n
end
local function railName(i)
	return "K5Rail" .. i
end
-- census hook (tools/kit_census.py sets it offline; nil in the game)
local function note(kind, t)
	local log = (_G :: any).ZR_KIT5_LOG
	if log then
		t.kind = kind
		table.insert(log, t)
	end
end

-- a flight from its foot. cf: at the front edge of the first riser, the middle of the width, on the floor it starts from,
-- looking up the flight (level). n steps of riser h and tread t, w wide. style: "C" solid concrete (opts.base: how far
-- below the foot the fill goes, default 0.2), "O" concrete with an open saw-tooth soffit, "S" steel (treads on two
-- stringers), "E" a stopped escalator. color, mat: the builder's (the mesh's baked shading is tinted by color).
-- opts.hand = "both" | "left" | "right": handrails on those sides (left = -x seen climbing). Returns the model, or nil
-- when the kit cannot build it (the caller then builds its parts).
local function k5Flight(parent, cf, n, h, t, w, style, color, mat, opts)
	opts = opts or {}
	local name = flightName(style, n)
	local sx, sy, sz = w / K5.W0, h / K5.H0, t / K5.T0
	local fits = within(sy, K5.SY) and within(sz, K5.SZ) and within(sx, K5.SX[style] or K5.SX.C)
	local hand = opts.hand
	local fam = nil
	if hand then
		local bestErr = K5.HAND_SY
		for _, f in { "A", "B" } do
			local err = math.abs(h / K5.HAND_H0[f] - 1)
			if err <= bestErr then
				fam, bestErr = f, err
			end
		end
	end
	local ready = fits and k5Ready(name) and (not hand or (fam ~= nil and k5Ready(handName(fam, n)) and moveGroup()))
	note("flight", { n = n, h = h, t = t, w = w, style = style, hand = hand, kit = ready, name = name })
	if not ready then
		return nil
	end
	local pieceMat = (style == "S" or style == "E") and "metal" or "concrete"
	local m = Kit.place(parent, name, cf, {
		scale = Vector3.new(sx, sy, sz), collide = {}, name = opts.name or "Flight",
		-- an escalator's steps carry their own colours (dark metal, yellow lines); every other flight takes the builder's
		tint = { [pieceMat] = style == "E" and Color3.new(1, 1, 1) or color }, mats = { [pieceMat] = { mat } },
	})
	if not m then
		return nil
	end
	structure(m, name)
	-- the ramp: its top runs through the middle of every tread, from half a tread before the first riser (no lip at the
	-- foot) to the back of the last tread (a quarter riser above the landing); prop space: x across, y up, -z up the flight
	local len = (n + 0.5) * t
	local rise = (n + 0.5) * h
	if style == "C" or style == "E" then
		-- solid: a wedge under the slope (bullets meet the stair, not the air under its treads)
		collider(m, "WedgePart", Vector3.new(w, rise, len), cf * CFrame.new(0, rise / 2, t / 2 - len / 2) * CFrame.Angles(0, math.pi, 0), mat, "StairRamp", nil)
		local depth = opts.base or 0.2
		if depth > K5.FILL then
			-- a deep fill (a flight off a landing, built solid down to the floor below): one plain block under it
			local fill = Instance.new("Part")
			fill.Name = "StairFill"
			fill.Anchored = true
			fill.Size = Vector3.new(w - 0.02, depth - K5.SKIRT * sy + 0.05, n * t - 0.02)
			fill.CFrame = cf * CFrame.new(0, -depth + fill.Size.Y / 2, -n * t / 2)
			fill.Color = color
			fill.Material = mat
			fill.TopSurface = Enum.SurfaceType.Smooth
			fill.BottomSurface = Enum.SurfaceType.Smooth
			fill.Parent = m
		end
	else
		-- open (saw-tooth soffit, steel): a slab along the slope, thin enough to keep the head room under a stacked flight
		local th = math.atan2(h, t)
		local d = Vector3.new(0, math.sin(th), -math.cos(th))
		local up = Vector3.new(0, math.cos(th), math.sin(th))
		local a, b = Vector3.new(0, 0, t / 2), Vector3.new(0, rise, -n * t)
		local c = (a + b) / 2 - up * (K5.RAMP_T / 2)
		collider(m, "Part", Vector3.new(w, K5.RAMP_T, (b - a).Magnitude), cf * CFrame.lookAt(c, c + d, up), mat, "StairRamp", nil)
	end
	-- handrails: one mesh per side (the same mesh both sides), scaled like the flight but for the riser (its family's), and a
	-- sloped collider for bodies only
	if hand and fam then
		local hsy = h / K5.HAND_H0[fam]
		local th = math.atan2(h, t)
		local d = Vector3.new(0, math.sin(th), -math.cos(th))
		local up = Vector3.new(0, math.cos(th), math.sin(th))
		local a, b = Vector3.new(0, 0, t / 2), Vector3.new(0, rise, -n * t) -- the ramp's line (feet level)
		local band = K5.RAIL_H * math.cos(th) -- across the slope; its height on the plumb is RAIL_H
		for _, side in { -1, 1 } do
			if hand == "both" or (hand == "left" and side < 0) or (hand == "right" and side > 0) then
				local off = side * (w / 2 - 0.1)
				structure(Kit.place(m, handName(fam, n), cf * CFrame.new(off, 0, 0), {
					scale = Vector3.new(1, hsy, sz), collide = {}, name = "Handrail", tint = { metal = opts.handColor or color },
					mats = { metal = { opts.handMat or Enum.Material.Metal } },
				}), handName(fam, n))
				local c = (a + b) / 2 + up * (band / 2) + Vector3.new(off, 0, 0)
				collider(m, "Part", Vector3.new(0.3, band, (b - a).Magnitude), cf * CFrame.lookAt(c, c + d, up), opts.handMat or Enum.Material.Metal, "RailCollider", K5.MOVE_GROUP)
			end
		end
	end
	m:SetAttribute("Flight", n)
	return m
end

-- a level railing between two world points at deck height: modules of the nearest nominal length (stretched at most
-- K5.STRETCH), runs over K5.RAIL_SPLIT cut into equal modules, one collider for the run. Returns the model or nil.
local function k5Rail(parent, a, b, color, mat, opts)
	opts = opts or {}
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local level = math.abs(b.Y - a.Y) < 0.05
	local k = math.max(1, math.ceil(len / K5.RAIL_SPLIT - 1e-6))
	local piece = len / k
	local best, bestErr = nil, math.huge
	for i, l0 in K5.RAIL_LENGTHS do
		local err = math.abs(piece / l0 - 1)
		if err < bestErr then
			best, bestErr = i, err
		end
	end
	local name = best and railName(best)
	local ready = level and len >= 0.45 and best ~= nil and bestErr <= K5.STRETCH and k5Ready(name) and moveGroup()
	note("rail", { len = len, pieces = k, kit = ready, name = name, level = level })
	if not ready then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = opts.name or "Railing"
	m:SetAttribute("NoDetail", true)
	m:SetAttribute("Kit5", "rail")
	local dir = flat.Unit
	local sz = piece / K5.RAIL_LENGTHS[best]
	for i = 0, k - 1 do
		local p0 = a + dir * (piece * i)
		structure(Kit.place(m, name, CFrame.lookAt(p0, p0 + dir), {
			scale = Vector3.new(1, 1, sz), collide = {}, name = "RailModule", tint = { metal = color }, mats = { metal = { mat } },
		}), name)
	end
	local mid = (a + b) / 2
	collider(m, "Part", Vector3.new(0.3, K5.RAIL_H, len), CFrame.lookAt(mid, mid + dir) * CFrame.new(0, K5.RAIL_H / 2, 0), mat, "RailCollider", K5.MOVE_GROUP)
	m.Parent = parent
	return m
end

local function mapKit(kit, O)
	local C, M, hex = kit.C, kit.M, kit.hex
	local H = {}
	H.K5 = K5
	H.k5Flight = k5Flight
	H.k5Rail = k5Rail
	H.k5Ready = k5Ready

	function H.V(x, y, z)
		return Vector3.new(O.X + x, y, O.Z + z)
	end
	local V = H.V
	function H.CF(x, y, z, ry)
		local c = CFrame.new(O.X + x, y, O.Z + z)
		if ry then
			c *= CFrame.Angles(0, math.rad(ry), 0)
		end
		return c
	end
	local CF = H.CF
	function H.B(parent, sx, sy, sz, x, y, z, color, mat, ry)
		return kit.box(parent, sx, sy, sz, O.X + x, y, O.Z + z, color, mat, ry)
	end
	local B = H.B
	function H.VC(parent, h, d, x, y, z, color, mat)
		return kit.vcyl(parent, h, d, O.X + x, y, O.Z + z, color, mat)
	end
	function H.smooth(t)
		t = math.clamp(t, 0, 1)
		return t * t * (3 - 2 * t)
	end
	function H.lerp(a, b, t)
		return a + (b - a) * t
	end

	-- wall along x at z (holes { x, width, bottom, top } in map x, heights from the wall's foot)
	function H.wallX(parent, x0, x1, z, y0, h, t, color, mat, holes)
		local cx = (x0 + x1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { o[1] - cx, o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(cx, y0, z), x1 - x0, h, t, color, mat, hs)
	end
	-- wall along z at x (holes { z, width, bottom, top } in map z)
	function H.wallZ(parent, z0, z1, x, y0, h, t, color, mat, holes)
		local cz = (z0 + z1) / 2
		local hs = {}
		for _, o in holes or {} do
			table.insert(hs, { -(o[1] - cz), o[2], o[3], o[4] })
		end
		kit.wallHoles(parent, CF(x, y0, cz) * CFrame.Angles(0, math.rad(90), 0), z1 - z0, h, t, color, mat, hs)
	end
	-- a slab (top at yTop) over x0..x1, z0..z1 with rectangular holes { x0, x1, z0, z1 }
	function H.slab(parent, x0, x1, z0, z1, yTop, th, color, mat, holes)
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
	-- a railing between two points at deck height y (the Kit5 railing when it is loaded, else two bars and end posts)
	function H.rail(parent, x0, z0, x1, z1, y, color, mat)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		if len < 0.2 then
			return
		end
		local col, m = color or hex("2E3230"), mat or M.Metal
		if k5Rail(parent, a, b, col, m) then
			return
		end
		local look = CFrame.lookAt(mid, b)
		kit.boxCF(parent, 0.25, 0.25, len, look * CFrame.new(0, 3.3, 0), col, m)
		kit.boxCF(parent, 0.18, 0.18, len, look * CFrame.new(0, 1.7, 0), col, m)
		for _, p in { a, b } do
			kit.boxCF(parent, 0.3, 3.4, 0.3, CFrame.new(p + Vector3.new(0, 1.7, 0)), col, m)
		end
	end
	-- straight stairs: n steps of 1 stud, each `run` deep, from (x, y0, z) along dir; solid down to yBase
	-- real-size steps (owner, 2026-11-01: real-world scale): each stud of rise is two 0.5-stud steps (16 cm, a real
	-- stair's rise) over the same footprint, so the flights keep their length and height
	function H.stairs(parent, x, z, y0, n, run, w, dir, yBase, color, mat)
		local c, m = color or C.concrete, mat or M.Concrete
		local r = run / 2
		local look = (dir == "+x" and Vector3.xAxis) or (dir == "-x" and -Vector3.xAxis) or (dir == "+z" and Vector3.zAxis) or -Vector3.zAxis
		local foot = V(x, y0, z)
		if k5Flight(parent, CFrame.lookAt(foot, foot + look), n * 2, 0.5, r, w, "C", c, m, { base = y0 - yBase }) then
			return
		end
		for k = 1, n * 2 do
			local top = y0 + k * 0.5
			local h = top - yBase
			local off = (k - 0.5) * r
			if dir == "+x" then
				B(parent, r, h, w, x + off, yBase + h / 2, z, c, m)
			elseif dir == "-x" then
				B(parent, r, h, w, x - off, yBase + h / 2, z, c, m)
			elseif dir == "+z" then
				B(parent, w, h, r, x, yBase + h / 2, z + off, c, m)
			else
				B(parent, w, h, r, x, yBase + h / 2, z - off, c, m)
			end
		end
	end
	function H.desk(parent, x, y0, z, w, d, color)
		B(parent, w, 0.3, d, x, y0 + 2.6, z, color or C.wood, M.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				B(parent, 0.22, 2.45, 0.22, x + sx * (w / 2 - 0.3), y0 + 1.22, z + sz * (d / 2 - 0.3), C.metalDark, M.Metal)
			end
		end
	end
	function H.lampHang(parent, x, y, z, range, dead)
		local head = B(parent, 2, 0.4, 1.2, x, y, z, dead and hex("6F6C64") or hex("FFE2B0"), dead and M.SmoothPlastic or M.Neon)
		head.CastShadow = false
		if not dead then
			kit.light(head, hex("FFD3A0"), range or 28, 1.05, false)
		end
		return head
	end
	-- two-tier bunk along x (or z when ry = 90)
	function H.bunk(parent, x, y0, z, ry)
		local cf = CF(x, y0, z, ry or 0)
		for _, sx in { -3, 3 } do
			for _, sz in { -1.2, 1.2 } do
				kit.boxCF(parent, 0.25, 5.6, 0.25, cf * CFrame.new(sx, 2.8, sz), C.metalDark, M.Metal)
			end
		end
		for _, y in { 1.2, 4.0 } do
			kit.boxCF(parent, 6.2, 0.25, 2.6, cf * CFrame.new(0, y, 0), C.metal, M.Metal)
			kit.boxCF(parent, 5.8, 0.45, 2.3, cf * CFrame.new(0, y + 0.35, 0), hex("6E6A58"), M.Fabric)
		end
	end
	-- a single bed with a mattress, along x (or z when ry = 90)
	function H.bed(parent, x, y0, z, ry)
		local cf = CF(x, y0, z, ry or 0)
		kit.boxCF(parent, 6.4, 0.3, 2.8, cf * CFrame.new(0, 1.3, 0), C.metal, M.Metal)
		kit.boxCF(parent, 6, 0.5, 2.5, cf * CFrame.new(0, 1.7, 0), hex("767061"), M.Fabric)
		for _, sx in { -3, 3 } do
			for _, sz in { -1.2, 1.2 } do
				kit.boxCF(parent, 0.2, 1.3, 0.2, cf * CFrame.new(sx, 0.65, sz), C.metalDark, M.Metal)
			end
		end
	end
	-- a pitched roof over x0..x1 / z0..z1 with the walls topping out at yTop; ridge along x (along = "x") or z;
	-- the gable ends are filled with wedges (full height toward the ridge)
	function H.roof(parent, x0, x1, z0, z1, yTop, pitch, along, color, mat, gableColor)
		local tp = math.tan(math.rad(pitch))
		local ov = 1.2
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		if along == "x" then
			local d, len = z1 - z0, x1 - x0 + 2 * ov
			local rise = (d / 2) * tp
			for _, s in { -1, 1 } do
				local eave = V(cx, yTop - ov * tp, cz + s * (d / 2 + ov))
				local ridge = V(cx, yTop + rise, cz)
				kit.boxCF(parent, len, 0.5, (ridge - eave).Magnitude + 0.25, CFrame.lookAt((eave + ridge) / 2, ridge) * CFrame.new(0, 0.25, 0), color, mat)
			end
			for _, gx in { x0 + 0.35, x1 - 0.35 } do
				for _, s in { -1, 1 } do
					kit.part(parent, Vector3.new(0.6, rise, d / 2), CF(gx, yTop + rise / 2, cz + s * d / 4, s > 0 and 180 or 0), gableColor, M.WoodPlanks, "WedgePart")
				end
			end
			B(parent, len, 0.4, 0.6, cx, yTop + rise + 0.3, cz, gableColor, M.WoodPlanks)
		else
			local d, len = x1 - x0, z1 - z0 + 2 * ov
			local rise = (d / 2) * tp
			for _, s in { -1, 1 } do
				local eave = V(cx + s * (d / 2 + ov), yTop - ov * tp, cz)
				local ridge = V(cx, yTop + rise, cz)
				kit.boxCF(parent, len, 0.5, (ridge - eave).Magnitude + 0.25, CFrame.lookAt((eave + ridge) / 2, ridge) * CFrame.new(0, 0.25, 0), color, mat)
			end
			for _, gz in { z0 + 0.35, z1 - 0.35 } do
				for _, s in { -1, 1 } do
					kit.part(parent, Vector3.new(0.6, rise, d / 2), CF(cx + s * d / 4, yTop + rise / 2, gz, s > 0 and -90 or 90), gableColor, M.WoodPlanks, "WedgePart")
				end
			end
			B(parent, 0.6, 0.4, len, cx, yTop + rise + 0.3, cz, gableColor, M.WoodPlanks)
		end
	end
	-- an army cargo truck facing base.LookVector; kind "canvas", "logs", "burnt" or "tanker"
	function H.truck(parent, base, kind)
		local burnt = kind == "burnt"
		local body = burnt and hex("2F2B27") or ((kind == "logs") and hex("5A4E3C") or ((kind == "tanker") and hex("5E5F55") or hex("4F563F")))
		local mat = burnt and M.CorrodedMetal or M.Metal
		local function bx(sx, sy, sz, x, y, z, c, m)
			return kit.boxCF(parent, sx, sy, sz, base * CFrame.new(x, y, z), c or body, m or mat)
		end
		bx(3.8, 0.8, 15.6, 0, 2.1, 0, C.metalDark, M.Metal)
		for _, wz in { -5.4, 2.8, 5.2 } do
			for _, wx in { -2.25, 2.25 } do
				kit.cyl(parent, 1.1, 3.4, base * CFrame.new(wx, 1.7, wz), burnt and hex("1D1B19") or hex("262624"), M.Rubber)
			end
		end
		bx(4.6, 3.8, 3.6, 0, 4.4, -4.6)
		bx(4.2, 1.9, 2.8, 0, 3.4, -7.6)
		bx(4.4, 0.6, 0.4, 0, 2.4, -9.1, C.metalDark, M.Metal)
		bx(3.9, 1.5, 0.1, 0, 5.4, -6.44, burnt and hex("141414") or hex("2B3532"), burnt and M.Slate or M.Glass)
		for _, sx in { -2.31, 2.31 } do
			bx(0.1, 1.4, 2, sx, 5.3, -4.8, burnt and hex("141414") or hex("2B3532"), burnt and M.Slate or M.Glass)
		end
		if kind == "tanker" then
			kit.cyl(parent, 9.4, 4.2, base * CFrame.new(0, 4.9, 2.6) * CFrame.Angles(0, math.rad(90), 0), hex("8C8D86"), M.Metal)
			for _, z in { -1.6, 6.8 } do
				bx(4.4, 0.6, 0.5, 0, 2.8, z, C.metalDark, M.Metal)
			end
			return
		end
		bx(4.8, 0.4, 9.6, 0, 2.9, 2.6)
		bx(0.25, 1.4, 9.6, -2.28, 3.8, 2.6)
		bx(0.25, 1.4, 9.6, 2.28, 3.8, 2.6)
		bx(4.8, 1.4, 0.25, 0, 3.8, 7.3)
		bx(4.8, 2.4, 0.25, 0, 4.3, -2.1)
		if kind == "canvas" then
			local CAN = hex("5B5E46")
			for _, hz in { -1.6, 2.6, 6.8 } do
				bx(4.7, 0.18, 0.18, 0, 7.4, hz, C.metalDark, M.Metal)
			end
			bx(4.9, 0.15, 9.6, 0, 7.55, 2.6, CAN, M.Fabric)
			bx(0.15, 3, 9.6, -2.42, 6.05, 2.6, CAN, M.Fabric)
			bx(0.15, 1.2, 9.6, 2.42, 6.95, 2.6, CAN, M.Fabric)
			bx(0.6, 0.6, 9.4, 2.4, 6.15, 2.6, hex("50533E"), M.Fabric)
		elseif kind == "logs" then
			for _, sz in { -1.6, 2.6, 6.8 } do
				for _, sx in { -2.3, 2.3 } do
					bx(0.3, 3.4, 0.3, sx, 4.8, sz, C.metalDark, M.Metal)
				end
			end
		end
	end
	-- nature kit pieces (ZR_Nature): origin at the base; nil when the kit is missing
	function H.nat(parent, key, cf, scale, color, solid)
		local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
		local t = lib and lib:FindFirstChild(key)
		if not t then
			return nil
		end
		local m = t:Clone()
		local s = (typeof(scale) == "Vector3") and scale or Vector3.one * (scale or 1)
		m.Size = t.Size * s
		m.CFrame = cf * CFrame.new((AssetMeta[key] or Vector3.new(0, t.Size.Y / 2, 0)) * s)
		m.Anchored = true
		m.CanCollide = solid == true
		m.CanQuery = solid == true
		m.CanTouch = false
		if color then
			m.Color = color
		end
		m.Parent = parent
		return m
	end
	-- a chain-link fence run (posts, top rail, a see-through panel that blocks walking but not shots); y0 and y1
	-- are the ground heights at the two ends
	local FENCE = hex("6D716C")
	function H.fence(parent, x0, z0, x1, z1, y0, h, y1)
		y1 = y1 or y0
		local a, b = V(x0, y0, z0), V(x1, y1, z1)
		local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		local n = math.max(1, math.floor(len / 6 + 0.5))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			kit.boxCF(parent, 0.3, h + 0.6, 0.3, CFrame.new(p + Vector3.new(0, (h + 0.6) / 2 - 0.6, 0)), FENCE, M.Metal)
		end
		local mid = (a + b) / 2
		local flatB = Vector3.new(b.X, mid.Y, b.Z)
		local look = CFrame.lookAt(mid, flatB)
		kit.boxCF(parent, 0.15, 0.15, len, look * CFrame.new(0, h, 0), FENCE, M.Metal)
		local mesh = kit.boxCF(parent, 0.08, h - 0.2, len, look * CFrame.new(0, h / 2, 0), FENCE, M.SmoothPlastic)
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
	return H
end

return mapKit

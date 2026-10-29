--!nonstrict
-- M13 building helpers for map modules, in map-local coordinates (x east, z south, heights are world y):
-- walls with holes, slabs with holes, railings, stairs, furniture, hanging lamps, bunks, pitched roofs, timber
-- cabins, multi-storey blocks, army trucks, nature-kit pieces and chain-link fences.
-- Usage: local H = require(script.Parent.MapKit)(kit, origin)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local AssetMeta = require(Shared:WaitForChild("AssetMeta"))
local Wear = require(Shared:WaitForChild("Wear"))

return function(kit, O)
	local C, M, hex = kit.C, kit.M, kit.hex
	local H = {}

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
	-- a railing between two points at deck height y
	function H.rail(parent, x0, z0, x1, z1, y, color, mat)
		local a, b = V(x0, y, z0), V(x1, y, z1)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		if len < 0.2 then
			return
		end
		local col, m = color or hex("2E3230"), mat or M.Metal
		local look = CFrame.lookAt(mid, b)
		kit.boxCF(parent, 0.25, 0.25, len, look * CFrame.new(0, 3.3, 0), col, m)
		kit.boxCF(parent, 0.18, 0.18, len, look * CFrame.new(0, 1.7, 0), col, m)
		for _, p in { a, b } do
			kit.boxCF(parent, 0.3, 3.4, 0.3, CFrame.new(p + Vector3.new(0, 1.7, 0)), col, m)
		end
	end
	-- straight stairs: n steps of 1 stud, each `run` deep, from (x, y0, z) along dir; solid down to yBase
	function H.stairs(parent, x, z, y0, n, run, w, dir, yBase, color, mat)
		local c, m = color or C.concrete, mat or M.Concrete
		for k = 1, n do
			local top = y0 + k
			local h = top - yBase
			local off = (k - 0.5) * run
			if dir == "+x" then
				B(parent, run, h, w, x + off, yBase + h / 2, z, c, m)
			elseif dir == "-x" then
				B(parent, run, h, w, x - off, yBase + h / 2, z, c, m)
			elseif dir == "+z" then
				B(parent, w, h, run, x, yBase + h / 2, z + off, c, m)
			else
				B(parent, w, h, run, x, yBase + h / 2, z - off, c, m)
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
		local lib = ReplicatedStorage:FindFirstChild("ZR_Assets")
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

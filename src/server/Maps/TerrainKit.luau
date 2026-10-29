--!nonstrict
-- M13 terrain for map modules: writes Roblox terrain from a height function, column by column, with water below a
-- level where the map allows it, an optional dug-out space (a bunker or a culvert) and per-column materials.
-- Measured behaviour this follows (docs/maps/MAPS_M13.md): Roblox draws a column's surface 2 studs above the
-- height its occupancies describe, so occupancy comes from h - 2; a partly solid voxel under water fills its free
-- part with water; terrain takes raycasts only from the next frame on (TK.build waits for that).
local TK = {}
local R = 4

-- spec: O (origin, multiples of 4), extX, extZ (half extents), y0, ny (voxel layers from y0), wl (water level, a
-- multiple of 4), ground(x, z) -> h, water(x, z) -> bool, material(x, z, h, slope) -> Material,
-- cave(x, z) -> lo, hi (optional: rock up to lo, air to hi, earth above), colors { [Material] = "hex" }
function TK.build(spec)
	local terrain = workspace.Terrain
	local O = spec.O
	local NX, NZ, NY = (2 * spec.extX) / R, (2 * spec.extZ) / R, spec.ny
	local x0l, z0l, y0 = -spec.extX, -spec.extZ, spec.y0
	local wl = spec.wl or 0
	local HG, WG, CG = table.create(NX), table.create(NX), table.create(NX)
	for i = 1, NX do
		local hc, wc, cc = table.create(NZ), table.create(NZ), table.create(NZ)
		local x = x0l + (i - 0.5) * R
		for k = 1, NZ do
			local z = z0l + (k - 0.5) * R
			hc[k] = spec.ground(x, z)
			wc[k] = spec.water and spec.water(x, z) or false
			if spec.cave then
				local lo, hi = spec.cave(x, z)
				cc[k] = lo and { lo, hi } or false
			else
				cc[k] = false
			end
		end
		HG[i], WG[i], CG[i] = hc, wc, cc
	end
	local MG = table.create(NX)
	for i = 1, NX do
		local mc = table.create(NZ)
		local x = x0l + (i - 0.5) * R
		for k = 1, NZ do
			local i0, i1, k0, k1 = math.max(1, i - 1), math.min(NX, i + 1), math.max(1, k - 1), math.min(NZ, k + 1)
			local sx = (HG[i1][k] - HG[i0][k]) / ((i1 - i0) * R)
			local sz = (HG[i][k1] - HG[i][k0]) / ((k1 - k0) * R)
			mc[k] = spec.material(x, z0l + (k - 0.5) * R, HG[i][k], math.sqrt(sx * sx + sz * sz))
		end
		MG[i] = mc
	end
	local CH = 32
	for ci = 0, NX - 1, CH do
		for ck = 0, NZ - 1, CH do
			local nx, nz = math.min(CH, NX - ci), math.min(CH, NZ - ck)
			local mats, occs = table.create(nx), table.create(nx)
			for a = 1, nx do
				local i = ci + a
				local mcol, ocol = table.create(NY), table.create(NY)
				for j = 1, NY do
					local yb = y0 + (j - 1) * R
					local mrow, orow = table.create(nz), table.create(nz)
					for b = 1, nz do
						local k = ck + b
						local hv = HG[i][k] - 2
						local occ = math.clamp((hv - yb) / R, 0, 1)
						local cave = CG[i][k]
						local m
						if cave then
							local lo, hi = cave[1], cave[2]
							local below = math.clamp((lo - 2 - yb) / R, 0, 1)
							local above = math.min(math.clamp((yb + 2 - hi) / R, 0, 1), occ)
							if below > 0 then
								m, occ = (lo - yb < 8) and Enum.Material.Ground or Enum.Material.Rock, below
							elseif above > 0 then
								m, occ = (hv - yb < R * 2) and MG[i][k] or Enum.Material.Ground, above
							else
								m, occ = Enum.Material.Air, 0
							end
						elseif WG[i][k] and yb + R <= wl then
							if occ > 0 then
								m = MG[i][k]
							else
								m, occ = Enum.Material.Water, 1
							end
						elseif occ <= 0 then
							m = Enum.Material.Air
						elseif hv - yb < R * 2 then
							m = MG[i][k]
						elseif hv - yb < 12 then
							m = Enum.Material.Ground
						else
							m = Enum.Material.Rock
						end
						mrow[b], orow[b] = m, occ
					end
					mcol[j], ocol[j] = mrow, orow
				end
				mats[a], occs[a] = mcol, ocol
			end
			local p0 = Vector3.new(O.X + x0l + ci * R, y0, O.Z + z0l + ck * R)
			terrain:WriteVoxels(Region3.new(p0, p0 + Vector3.new(nx * R, NY * R, nz * R)), R, mats, occs)
		end
	end
	for mat, col in spec.colors or {} do
		terrain:SetMaterialColor(mat, Color3.fromHex(col))
	end

	local T = { HG = HG, NX = NX, NZ = NZ }
	-- ground height between column centres (what the voxels draw)
	function T.hAt(x, z)
		local fx, fz = (x - x0l) / R + 0.5, (z - z0l) / R + 0.5
		local i0, k0 = math.clamp(math.floor(fx), 1, NX - 1), math.clamp(math.floor(fz), 1, NZ - 1)
		local tx, tz = math.clamp(fx - i0, 0, 1), math.clamp(fz - k0, 0, 1)
		local a = HG[i0][k0] + (HG[i0 + 1][k0] - HG[i0][k0]) * tx
		local b = HG[i0][k0 + 1] + (HG[i0 + 1][k0 + 1] - HG[i0][k0 + 1]) * tx
		return a + (b - a) * tz
	end
	local tParams = RaycastParams.new()
	tParams.FilterType = Enum.RaycastFilterType.Include
	tParams.FilterDescendantsInstances = { terrain }
	tParams.IgnoreWater = true
	-- terrain height at a local spot (from above, terrain only); the voxel heights when the ray finds nothing
	function T.gy(x, z)
		local hit = workspace:Raycast(Vector3.new(O.X + x, 160, O.Z + z), Vector3.new(0, -220, 0), tParams)
		if hit then
			return hit.Position.Y, hit.Normal
		end
		return T.hAt(x, z), Vector3.yAxis
	end
	-- terrain takes raycasts from the next frame on: wait for a probe at (px, pz)
	function T.waitReady(px, pz)
		local t0 = os.clock()
		repeat
			task.wait()
		until workspace:Raycast(Vector3.new(O.X + px, 160, O.Z + pz), Vector3.new(0, -220, 0), tParams) or os.clock() - t0 > 6
	end
	return T
end

return TK

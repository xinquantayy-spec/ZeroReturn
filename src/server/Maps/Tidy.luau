--!nonstrict
-- Placement tidy pass, run on every map right after it is built (World.endMap). Owner 2026-11-01: "ensure the placements
-- of the buildings, props, objects etc make sense ... ensure nothing is placed abnormally or glitching". The map builders
-- place thousands of props and trees by rule; this pass removes or moves the few that land wrong, the same way on every
-- server start. It never touches a prop that holds loot or a prompt, a door, or a wall or ceiling fitting. What it fixes
-- (the Studio audit, ZR_Dev "audit", found these on Border Yard on 2026-11-01):
--   doorways   a prop standing in a doorway (the closed leaf's opening and 1.2 studs either side) is removed
--   swings     each door hangs the way that opens widest (hinge at either end, opening to either side); a prop without
--              loot in its way is removed; a door that still meets a wall or loot opens less far
--   twins      the second of two identical props on the same spot is removed
--   trees      a trunk, crown or bush grown through a building, a fence, a rock or another solid is removed, and one
--              standing on a road
--   fences     a fence piece run into a building's wall or floor is removed (the fence stops at the building)
--   stacked    of two props sharing more than 40 % of the smaller one's box, the smaller is removed (a chair under a desk stays)
--   water      an outdoor dressing prop standing on water or over nothing is removed (a boat-sized one, 16 studs or more, stays)
--   sunk       a floor-standing prop sunk into a floor slab or the ground is lifted onto it
--   walls      a floor-standing prop run into a wall, a tank, a wall fitting or a bigger prop is moved out of it (out of a
--              corner too: up to three pushes, at most half its width); small loose dressing that cannot be freed, or is
--              more than half inside, is removed; furniture and anything holding loot is left and logged
local Tidy = {}

-- fittings that hang on walls or ceilings, sit in wall openings, or lie flush in floors: never moved or removed here
local FIXED = {}
for _, n in {
	"BlastDoor", "BrokenEdge", "CableTray", "CageLamp", "CageLampRed", "CarHatch", "CargoLift", "CeilingCollapse", "CeilingDebris",
	"CeilingHole", "Column", "ColumnDamaged", "CorkBoard", "DepartureBoard", "DockDoor", "DockDoorOpen", "DoorFrame", "Duct",
	"Escalator", "Extinguisher", "FirstAid", "Fluoro", "FluoroDead", "GunRack", "HVAC", "Hoarding",
	"HoseReel", "InsuranceWindow", "JunctionBox", "Manhole", "OilStain", "Pegboard", "Pigeonholes", "PipeRun", "PipeRunRust",
	"PipeValve", "Projector", "RangeDisplay", "RollerDoor", "Shutter", "ShutterBent", "ShutterHalf", "SlabCollapse", "Speaker",
	"StoreFront", "StoreFrontBroken", "TVWall", "Vent", "VanDoor", "VanDoorR", "WallBreach", "WallClock", "WallPhone",
	"WallShelf", "WallShelfBooks", "WallShelfMeds", "WallShelfSparse", "WallShelfTools", "Whiteboard", "Beam", "Balustrade",
	"BalustradeBroken", "Ramp", "Escalator", "GlassShards", "SteelPlate", "Fountain",
} do
	FIXED[n] = true
end
Tidy.FIXED = FIXED
-- wall fittings that are furniture: one hung across a doorway is removed like any prop (a shelf, a board, a box)
local WALLFURN = {}
for _, n in { "WallShelf", "WallShelfBooks", "WallShelfMeds", "WallShelfSparse", "WallShelfTools", "Whiteboard", "CorkBoard", "Pegboard",
	"Pigeonholes", "GunRack", "FirstAid", "Extinguisher", "WallPhone", "WallClock", "JunctionBox", "HoseReel", "TVWall", "RangeDisplay" } do
	WALLFURN[n] = true
end
-- what a chair is pushed in under (a chair and one of these share a box by design). Not the office desk: its kit has
-- its own chair, so a second chair in its box stands in that one
local TUCK = { Table = true, TechTable = true, CCTVDesk = true, FoodTable = true, FoodTableMess = true, DisplayTable = true, GunBench = true, CraftBench = true }

local function kitOf(p, stop)
	local m = p:FindFirstAncestorWhichIsA("Model")
	while m and m ~= stop and m:GetAttribute("Kit") == nil do
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
	end
	if m == stop then
		return nil
	end
	return m
end

-- a prop's kit name; a loot container's own box (World's container spot) counts as "Box_<kind>"
local function nameOf(m)
	local k = m:GetAttribute("Kit")
	if k ~= nil then
		return k
	end
	local b = m:GetAttribute("LootBox")
	return b and ("Box_" .. tostring(b)) or "?"
end

-- a prop that holds loot, a prompt or a door is part of the game, not dressing
local function keeps(m)
	for _, d in m:GetDescendants() do
		if d:IsA("ProximityPrompt") or string.sub(d.Name, 1, 5) == "Loot_" or string.sub(d.Name, 1, 5) == "Door_" then
			return true
		end
	end
	return false
end

local function structural(p)
	if p.Transparency >= 0.99 then
		return false
	end
	local s = p.Size
	return ((s.X >= 3 and 1 or 0) + (s.Y >= 3 and 1 or 0) + (s.Z >= 3 and 1 or 0)) >= 2
end

local function nature(p)
	local n = p.Name
	return n == "Trunk" or n == "Crown" or n == "Bush" or string.sub(n, 1, 7) == "ZR_NAT_" or n == "Rock"
end

-- how far box A (cf, size) reaches into part P along P's thinnest axis, and that axis pointing from P towards A; for an
-- upright cylinder (a tank, a silo) the depth is radial and the axis points from its centre line to A
local function intoWall(cf, size, p)
	if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
		local axis = p.CFrame.RightVector
		if math.abs(axis.Y) > 0.9 then
			local rel = cf.Position - p.Position
			local along = rel:Dot(axis)
			local r, u, l = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
			if math.abs(along) >= p.Size.X / 2 + math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y) then
				return 0, nil
			end
			local radial = rel - axis * along
			local dist = radial.Magnitude
			local n = dist > 0.01 and radial / dist or Vector3.xAxis
			local reach = math.abs(r:Dot(n)) + math.abs(u:Dot(n)) + math.abs(l:Dot(n))
			local depth = math.min(p.Size.Y, p.Size.Z) / 2 + reach - dist
			if depth <= 0 then
				return 0, nil
			end
			return depth, n
		end
	end
	local rel = p.CFrame:PointToObjectSpace(cf.Position)
	local half = p.Size / 2
	-- A's extent on P's axes (a box turned in yaw only, as props are)
	local function reach(axis)
		local r, u, l = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
		return math.abs(r:Dot(axis)) + math.abs(u:Dot(axis)) + math.abs(l:Dot(axis))
	end
	-- the part's own axes (ZVector, not LookVector: LookVector is -Z, which turned the pushes into walls with a thin
	-- Z, found 2026-11-02)
	local ax = { { p.CFrame.XVector, rel.X, half.X }, { p.CFrame.YVector, rel.Y, half.Y }, { p.CFrame.ZVector, rel.Z, half.Z } }
	local best, bestDir = math.huge, nil
	for _, a in ax do
		local ra = reach(a[1])
		local o = math.min(a[3], a[2] + ra) - math.max(-a[3], a[2] - ra)
		if o <= 0 then
			return 0, nil
		end
		if o < best then
			best = o
			bestDir = a[1] * ((a[2] >= 0) and 1 or -1)
		end
	end
	return best, bestDir
end

Tidy.intoWall = intoWall
-- what the last run on each map did, one line per prop (ZR_Dev "tidylog" reads it)
Tidy.last = {}

function Tidy.run(mapId, model, doors)
	local t0 = os.clock()
	local res = { roadTrees = 0, fences = 0, doorways = 0, swing = 0, doorsTurned = 0, doorsShort = 0, twins = 0, stacked = 0, trees = 0, water = 0, waterBig = 0, sunk = 0, walls = 0, wallsGone = 0, wallsLeft = 0 }
	local log = {}
	Tidy.last[mapId] = log
	local function note(what, m, detail)
		if #log < 600 then
			local p = m:GetPivot().Position
			local where = m.Parent and m.Parent.Parent and (m.Parent.Parent.Name .. "/" .. m.Parent.Name) or "?"
			table.insert(log, string.format("%s %s (%s) @ %.1f, %.1f, %.1f%s", what, nameOf(m), where, p.X, p.Y, p.Z, detail and (" " .. detail) or ""))
		end
	end
	local props, trunks, crowns, bushes = {}, {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and (d:GetAttribute("Kit") ~= nil or d:GetAttribute("LootBox") ~= nil) then
			table.insert(props, d)
		elseif d:IsA("BasePart") then
			if d.Name == "Trunk" then
				table.insert(trunks, d)
			elseif d.Name == "Crown" then
				table.insert(crowns, d)
			elseif d.Name == "Bush" then
				table.insert(bushes, d)
			end
		end
	end
	local gone = {}
	local function remove(m)
		gone[m] = true
		m:Destroy()
	end
	local solidOP = OverlapParams.new()
	solidOP.FilterType = Enum.RaycastFilterType.Include
	solidOP.FilterDescendantsInstances = { model }
	solidOP.RespectCanCollide = true

	-- 1. doorways
	for _, d in doors or {} do
		if d.part and d.cf and d.part:IsDescendantOf(model) then
			local s = d.part.Size
			local box
			if s.X >= s.Z then
				box = Vector3.new(s.X * 0.9, s.Y * 0.9, s.Z + 2.4)
			else
				box = Vector3.new(s.X + 2.4, s.Y * 0.9, s.Z * 0.9)
			end
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Include
			op.FilterDescendantsInstances = { model }
			local seen = {}
			for _, p in workspace:GetPartBoundsInBox(d.cf, box, op) do
				local km = kitOf(p, model)
				local kk = km and km:GetAttribute("Kit")
				if km and not seen[km] and not gone[km] and (not FIXED[kk] or WALLFURN[kk]) and not km:IsAncestorOf(d.part) then
					seen[km] = true
					if not keeps(km) then
						note("doorway", km)
						remove(km)
						res.doorways += 1
					end
				end
			end
		end
	end

	-- 1b. door swings. Doors.luau turns a leaf about a hinge at one end. Of the four ways a leaf can hang (hinge at
	-- either end, opening to either side) each door takes the one that opens widest, up to 100 degrees: a wall, a
	-- column, a tank or anything holding loot stops the leaf; on a tie, the one with fewest props in the way, then the
	-- builder's (hinge -X, opening toward -Z). Props without loot in the chosen swing are removed. The choice is written
	-- to the door (d.hinge, d.turn, d.swing) and its handle is moved to the free end.
	local leafOP = OverlapParams.new()
	leafOP.FilterType = Enum.RaycastFilterType.Include
	leafOP.FilterDescendantsInstances = { model }
	local function stops(p, cf, box, d)
		if p == d.part or p:IsDescendantOf(d.part) then
			return false
		end
		local km = kitOf(p, model)
		if km then
			return keeps(km) and km:GetAttribute("Kit") ~= "DoorFrame" and not km:IsAncestorOf(d.part)
		end
		if string.sub(p.Name, 1, 5) == "Loot_" then
			return true
		end
		if not p.CanCollide or not structural(p) then
			return false
		end
		if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder and math.abs(p.CFrame.RightVector.Y) > 0.9 then
			return (intoWall(cf, box, p)) > 0.05
		end
		return true
	end
	local HANGS = { { -1, 1 }, { -1, -1 }, { 1, -1 }, { 1, 1 } } -- hinge end (-X or +X), turn (+ swings toward -Z)
	for id, d in doors or {} do
		if d.part and d.cf and d.size and d.part:IsDescendantOf(model) then
			local w, h, th = d.size.X, d.size.Y, math.max(0.2, d.size.Z)
			local leafBox = Vector3.new(math.max(0.1, w - 0.5), h * 0.85, th)
			local outerBox = Vector3.new(w * 0.6, h * 0.8, th)
			local best = nil
			for hi, hang in HANGS do
				local hs, turn = hang[1], hang[2]
				local hinge = d.cf * CFrame.new(hs * w / 2, 0, 0)
				local swing, inWay = 100, {}
				for a = 20, 100, 10 do
					local rot = hinge * CFrame.Angles(0, math.rad(turn * a), 0)
					local leafCF = rot * CFrame.new(-hs * (w / 2 + 0.25), 0, 0)
					local outerCF = rot * CFrame.new(-hs * w * 0.7, 0, 0)
					local blocked = false
					-- walls and columns: the outer 60 % of the leaf (the hinge end turns in the jamb)
					for _, p in workspace:GetPartBoundsInBox(outerCF, outerBox, solidOP) do
						if kitOf(p, model) == nil and stops(p, outerCF, outerBox, d) then
							blocked = true
							break
						end
					end
					-- props: the whole leaf (bar 0.5 at the hinge); one holding loot stops it, the rest are noted
					if not blocked then
						for _, p in workspace:GetPartBoundsInBox(leafCF, leafBox, leafOP) do
							local km = kitOf(p, model)
							if km then
								if not gone[km] and not inWay[km] and km:GetAttribute("Kit") ~= "DoorFrame" and not km:IsAncestorOf(d.part) then
									if keeps(km) then
										blocked = true
										break
									end
									inWay[km] = true
								end
							elseif string.sub(p.Name, 1, 5) == "Loot_" then
								blocked = true
								break
							end
						end
					end
					if blocked then
						swing = a - 10
						break
					end
				end
				local n = 0
				for _ in inWay do
					n += 1
				end
				local score = swing * 100 - n * 3 - hi
				if not best or score > best.score then
					best = { score = score, hs = hs, turn = turn, swing = swing, inWay = inWay, n = n }
				end
			end
			if best then
				for km in best.inWay do
					note("swing", km, "in the way of door " .. tostring(id))
					remove(km)
					res.swing += 1
				end
				if best.hs ~= -1 or best.turn ~= 1 then
					d.hinge, d.turn = best.hs, best.turn
					res.doorsTurned += 1
					if d.handle then
						-- the handle goes to the free end (it is welded to the leaf: unweld, move, weld again)
						local wc = d.handle:FindFirstChildWhichIsA("WeldConstraint")
						if wc then
							wc.Enabled = false
						end
						d.handle.CFrame = d.cf * CFrame.new(-best.hs * (w / 2 - 0.4), -0.3, 0)
						if wc then
							wc.Enabled = true
						end
					end
				end
				if best.swing < 100 then
					d.swing = best.swing
					res.doorsShort += 1
					if #log < 600 then
						local q = d.cf.Position
						table.insert(log, string.format("short door %s @ %.1f, %.1f, %.1f opens %d degrees at best (hinge %d, turn %d)", tostring(id), q.X, q.Y, q.Z, best.swing, best.hs, best.turn))
					end
				end
			end
		end
	end

	-- 2. twins: the same prop twice on one spot
	local spot = {}
	for _, m in props do
		if not gone[m] and m.Parent then
			local p = m:GetPivot().Position
			local key = nameOf(m) .. ":" .. math.floor(p.X * 2 + 0.5) .. ":" .. math.floor(p.Y * 2 + 0.5) .. ":" .. math.floor(p.Z * 2 + 0.5)
			if spot[key] and not keeps(m) then
				note("twin", m)
				remove(m)
				res.twins += 1
			else
				spot[key] = m
			end
		end
	end

	-- 3. trees: through a building, a fence, a rock or another solid (not another tree)
	local function blocked(part, xz, y)
		local inner = Vector3.new(part.Size.X * xz, part.Size.Y * y, part.Size.Z * xz)
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = { model }
		for _, p in workspace:GetPartBoundsInBox(part.CFrame, inner, op) do
			if p ~= part and p.CanCollide and not (p.Name == "Trunk" or p.Name == "Crown" or p.Name == "Bush") and (structural(p) or p.Name == "Rock" or string.sub(p.Name, 1, 7) == "ZR_NAT_") then
				return p
			end
		end
		return nil
	end
	local crownAt = {}
	for _, c in crowns do
		local k = math.floor(c.Position.X / 4) .. ":" .. math.floor(c.Position.Z / 4)
		crownAt[k] = crownAt[k] or {}
		table.insert(crownAt[k], c)
	end
	local function crownOf(trunk)
		local best, bd = nil, 3.5
		local cx, cz = math.floor(trunk.Position.X / 4), math.floor(trunk.Position.Z / 4)
		for i = -1, 1 do
			for k = -1, 1 do
				for _, c in crownAt[(cx + i) .. ":" .. (cz + k)] or {} do
					local d = Vector2.new(c.Position.X - trunk.Position.X, c.Position.Z - trunk.Position.Z).Magnitude
					if d < bd and c.Parent then
						best, bd = c, d
					end
				end
			end
		end
		return best
	end
	for i, t in trunks do
		if i % 400 == 0 then
			task.wait()
		end
		if t.Parent and blocked(t, 0.4, 0.8) then
			local c = crownOf(t)
			if c then
				c:Destroy()
			end
			t:Destroy()
			res.trees += 1
		end
	end
	for _, c in crowns do
		if c.Parent and blocked(c, 0.4, 0.45) then
			c:Destroy() -- a crown through a roof or wall: the trunk alone reads as a dead tree
			res.trees += 1
		end
	end
	for _, b in bushes do
		if b.Parent and blocked(b, 0.45, 0.5) then
			b:Destroy()
			res.trees += 1
		end
	end

	-- 3b. outdoors: a tree or a bush standing on a road goes; a fence piece run into a building (its wall, its floor) goes,
	-- so the fence stops at the building as Tarkov's do
	local roads = model:FindFirstChild("Roads")
	if roads then
		local rop = OverlapParams.new()
		rop.FilterType = Enum.RaycastFilterType.Include
		rop.FilterDescendantsInstances = { roads }
		for _, list in { trunks, bushes } do
			for _, t in list do
				if t.Parent then
					local foot = CFrame.new(t.Position.X, t.Position.Y - t.Size.Y / 2 + 0.5, t.Position.Z)
					if #workspace:GetPartBoundsInBox(foot, Vector3.new(t.Size.X * 0.5, 1.5, t.Size.Z * 0.5), rop) > 0 then
						if t.Name == "Trunk" then
							local c = crownOf(t)
							if c then
								c:Destroy()
							end
						end
						t:Destroy()
						res.roadTrees += 1
					end
				end
			end
		end
	end
	local fences = model:FindFirstChild("Fences")
	if fences then
		local blds = {}
		for _, n in { "Living", "Works", "Outside", "Mall", "StoresL1", "StoresL2", "StoresFill" } do
			local f = model:FindFirstChild(n)
			if f then
				table.insert(blds, f)
			end
		end
		if #blds > 0 then
			local fop = OverlapParams.new()
			fop.FilterType = Enum.RaycastFilterType.Include
			fop.FilterDescendantsInstances = blds
			fop.RespectCanCollide = true
			for i, p in fences:GetDescendants() do
				if i % 500 == 0 then
					task.wait()
				end
				if p:IsA("BasePart") and p.Transparency < 0.99 then
					local inner = Vector3.new(math.max(0.05, p.Size.X - 0.4), math.max(0.05, p.Size.Y - 0.4), math.max(0.05, p.Size.Z - 0.4))
					for _, q in workspace:GetPartBoundsInBox(p.CFrame, inner, fop) do
						if structural(q) and kitOf(q, model) == nil and string.sub(q.Name, 1, 5) ~= "Loot_" then
							local rel = q.CFrame:PointToObjectSpace(p.Position)
							local insideXZ = math.abs(rel.X) < q.Size.X / 2 and math.abs(rel.Z) < q.Size.Z / 2
							if insideXZ or (intoWall(p.CFrame, p.Size, q)) > 0.5 then
								p:Destroy()
								res.fences += 1
								break
							end
						end
					end
				end
			end
		end
	end

	-- 4 to 6: the floor-standing props one by one (world up: a tipped prop still stands on what is under it)
	local UP = Vector3.yAxis
	local function worldBox(cf, size)
		local r, u, l = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
		return Vector3.new(math.abs(r.X) + math.abs(u.X) + math.abs(l.X), math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y), math.abs(r.Z) + math.abs(u.Z) + math.abs(l.Z))
	end
	for i, m in props do
		if i % 300 == 0 then
			task.wait()
		end
		local kit = nameOf(m)
		if not gone[m] and m.Parent and not FIXED[kit] then
			local cf, size = m:GetBoundingBox()
			local e = worldBox(cf, size)
			local bottomY = cf.Position.Y - e.Y
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { m }
			rp.RespectCanCollide = false
			rp.IgnoreWater = false
			-- the first visible thing under a point of the base
			local function under(dx, dz)
				local from = Vector3.new(cf.Position.X + dx, bottomY + 0.3, cf.Position.Z + dz)
				for _ = 1, 4 do
					local h = workspace:Raycast(from, Vector3.new(0, -40, 0), rp)
					if not h then
						return nil
					end
					if h.Instance == workspace.Terrain or h.Instance.Transparency < 0.99 then
						return h
					end
					from = h.Position - Vector3.new(0, 0.02, 0)
				end
				return nil
			end
			local mid = under(0, 0)
			local outdoor = m.Parent and (m.Parent.Name == "Dressing" or m.Parent.Name == "Dress")
			local wet = function(h)
				return h == nil or h.Material == Enum.Material.Water
			end
			if outdoor and wet(mid) and not keeps(m) then
				-- on water or over nothing at every corner too
				local all = true
				for _, o in { { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 }, { -0.7, -0.7 } } do
					if not wet(under(o[1] * e.X, o[2] * e.Z)) then
						all = false
						break
					end
				end
				if all then
					if math.max(e.X, e.Z) * 2 < 16 then
						note("water", m)
						remove(m)
						res.water += 1
					else
						res.waterBig += 1
					end
				end
			elseif mid and (mid.Instance == workspace.Terrain or structural(mid.Instance)) then
				-- sunk: the surface under the middle is above the base (only shallow faults: a ray starting inside a
				-- slab does not see it, so deep ones are left to the builders)
				local depth = mid.Position.Y - bottomY
				if depth > 0.15 and depth < size.Y * 0.6 then
					note("lifted", m, string.format("%.2f off %s", depth, mid.Instance.Name))
					m:PivotTo(m:GetPivot() + UP * depth)
					res.sunk += 1
					cf = cf + UP * depth
					bottomY += depth
				end
			end
			-- walls: a solid wall, slab or tank inside the prop's box (lifted off the floor), or a wall fitting's collider
			if not gone[m] then
				local inner = Vector3.new(math.max(0.1, size.X - 0.2), math.max(0.1, size.Y - 0.5), math.max(0.1, size.Z - 0.2))
				local op = OverlapParams.new()
				op.FilterType = Enum.RaycastFilterType.Exclude
				op.FilterDescendantsInstances = { m }
				op.RespectCanCollide = true
				local myVol = size.X * size.Y * size.Z
				local function solid(p)
					if not p:IsDescendantOf(model) or nature(p) then
						return false
					end
					local km = kitOf(p, model)
					if km == nil then
						-- a loot container's box is not a wall: pushing a prop out of one runs it into the wall behind
						return structural(p) and string.sub(p.Name, 1, 5) ~= "Loot_"
					end
					if p.Name ~= "KitCollider" then
						return false
					end
					local k2, z = km:GetAttribute("Kit"), p.Size
					if FIXED[k2] then
						-- a wall fitting's collider is invisible but stands for the fitting (a roller door, a whiteboard)
						return ((z.X >= 3 and 1 or 0) + (z.Y >= 3 and 1 or 0) + (z.Z >= 3 and 1 or 0)) >= 2
					end
					-- a bigger prop standing on the same floor (a sandbag wall run into a booth, a crate into a rack); not a
					-- chair pushed in under a desk, and nothing standing on a shelf (that one shares most of the box: step 7)
					if z.X * z.Y * z.Z < myVol * 1.5 or (kit == "Chair" and TUCK[k2]) then
						return false
					end
					local e2 = worldBox(p.CFrame, z)
					return math.abs((p.Position.Y - e2.Y) - bottomY) < 0.6
				end
				-- the deepest wall the box at cfX runs into (not the floor under it or a ceiling over it)
				local function deepest(cfX)
					local worst, dir = 0, nil
					for _, p in workspace:GetPartBoundsInBox(cfX * CFrame.new(0, 0.25, 0), inner, op) do
						if solid(p) then
							local d, n = intoWall(cfX, size, p)
							if n and math.abs(n:Dot(UP)) < 0.5 and d > worst then
								worst, dir = d, n
							end
						end
					end
					return worst, dir
				end
				local worst, dir = deepest(cf)
				if dir and worst > 0.15 then
					local limit = math.max(size.X, size.Z) * 0.5
					local shift, freed = Vector3.zero, false
					if worst < limit then
						local d, n = worst, dir
						for _ = 1, 3 do
							local flat = Vector3.new(n.X, 0, n.Z)
							if flat.Magnitude < 0.01 then
								break
							end
							shift += flat.Unit * (d + 0.05)
							d, n = deepest(cf + shift)
							if not n or d <= 0.15 then
								freed = true
								break
							end
						end
					end
					if freed and shift.Magnitude <= limit then
						note("moved", m, string.format("%.2f out of a wall", shift.Magnitude))
						m:PivotTo(m:GetPivot() + shift)
						res.walls += 1
					elseif worst > 0.4 and not keeps(m) and math.max(size.X, size.Z) <= 4.5 and kit ~= "Chair" then
						-- small loose dressing (a drum, a crate, a box pile) wedged in a corridor narrower than itself, or
						-- more than half inside a wall or a tank: it shows through. Furniture is left for its builder to fix.
						note("wedged", m, string.format("%.2f into a wall, size %.1f x %.1f", worst, size.X, size.Z))
						remove(m)
						res.wallsGone += 1
					else
						note("left", m, string.format("%.2f into a wall", worst))
						res.wallsLeft += 1
					end
				end
			end
		end
	end
	-- 7. stacked (after the pushes out of walls, which can move one prop into another): two props sharing most of the
	-- smaller one's box (a chair pushed under a desk or a table is how it stands)
	local boxes = {}
	for _, m in props do
		if not gone[m] and m.Parent and not FIXED[m:GetAttribute("Kit")] then
			local cf, size = m:GetBoundingBox()
			local r, u, l = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
			local e = Vector3.new(math.abs(r.X) + math.abs(u.X) + math.abs(l.X), math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y), math.abs(r.Z) + math.abs(u.Z) + math.abs(l.Z))
			table.insert(boxes, { m = m, lo = cf.Position - e, hi = cf.Position + e, kit = nameOf(m), vol = 8 * e.X * e.Y * e.Z })
		end
	end
	table.sort(boxes, function(a, b)
		return a.lo.X < b.lo.X
	end)
	for i = 1, #boxes do
		local a = boxes[i]
		if not gone[a.m] then
			for j = i + 1, #boxes do
				local b = boxes[j]
				if b.lo.X >= a.hi.X then
					break
				end
				if not gone[b.m] then
					local ox = math.min(a.hi.X, b.hi.X) - math.max(a.lo.X, b.lo.X)
					local oy = math.min(a.hi.Y, b.hi.Y) - math.max(a.lo.Y, b.lo.Y)
					local oz = math.min(a.hi.Z, b.hi.Z) - math.max(a.lo.Z, b.lo.Z)
					if ox > 0 and oy > 0 and oz > 0 then
						local share = ox * oy * oz / math.max(0.01, math.min(a.vol, b.vol))
						local tucked = (a.kit == "Chair" and TUCK[b.kit]) or (b.kit == "Chair" and TUCK[a.kit])
						if share > 0.4 and not tucked and not a.m:IsAncestorOf(b.m) and not b.m:IsAncestorOf(a.m) then
							-- the smaller one goes, unless it holds loot; then the other, unless that does too
							local small, big = a, b
							if b.vol < a.vol then
								small, big = b, a
							end
							local victim = (not keeps(small.m)) and small or ((not keeps(big.m)) and big or nil)
							if victim then
								note("stacked", victim.m, string.format("in %s, %d %%", tostring(victim == small and big.kit or small.kit), math.floor(share * 100)))
								remove(victim.m)
								res.stacked += 1
								if victim == a then
									break
								end
							end
						end
					end
				end
			end
		end
	end

	res.seconds = math.floor((os.clock() - t0) * 100) / 100
	return res
end

return Tidy

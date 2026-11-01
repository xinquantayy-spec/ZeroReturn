--!nonstrict
-- Placement audit for the Studio test bridge (owner 2026-11-01: "ensure the placements of the buildings, props, objects
-- etc make sense ... ensure nothing is placed abnormally or glitching"). ZR_Dev:Invoke("audit", mapId, examples) scans one
-- built map and returns JSON: per check, a count and the first examples (name, position, detail), so each kind of fault
-- can be looked at in Studio and fixed in the map's builder.
-- Checks (kit props are Models with the attribute Kit; trees are the nature kit's Trunk/Crown/Bush meshes):
--   floating  a prop with nothing under its base (0.8 studs down), not hung on a wall or a ceiling (nor marked Raised)
--   sunk      a prop standing more than 0.3 studs (and a fifth of its height, up to 60 %) into the floor, terrain or a solid part
--   clipping  a prop running more than 0.3 studs into a wall, a floor slab or another solid part (not its own colliders)
--   door      a prop in a doorway or in the way of a door's leaf as it opens
--   stairs    a prop standing on a stair flight
--   stacked   two props sharing more than 40 % of the smaller one's box
--   tree      a tree trunk inside a building, or a crown or bush through a roof or wall
--   container a loot container's own box (crate, safe, drawers) run into a prop or a wall
--   road      a tree trunk or a bush standing on a road
--   gap       furniture that belongs against a wall (lockers, shelves, cabinets, desks, benches) 0.25 to 1.6 studs off it
--   fences / rails / power  a fence, a rail or a power pole run through a building
local HttpService = game:GetService("HttpService")

return function(C, ctx)
	-- wall and ceiling fittings and floor-flush props are exempt, as in the tidy pass (Maps/Tidy.luau)
	local okF, Tidy = pcall(require, script.Parent.Parent.Parent.Maps.Tidy)
	local FIXED = okF and Tidy.FIXED or {}
	local function round(v)
		return math.floor(v * 10 + 0.5) / 10
	end
	local function vs(v)
		return string.format("%.1f, %.1f, %.1f", v.X, v.Y, v.Z)
	end

	-- solid world parts only: collidable, not a character, not a kit prop's own collider when we test that prop
	local function solidParams(exclude)
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = exclude
		op.RespectCanCollide = true
		return op
	end
	local function rayParams(exclude)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = exclude
		rp.RespectCanCollide = true
		rp.IgnoreWater = true
		return rp
	end

	local function ownerKitOf(p)
		local m = p:FindFirstAncestorWhichIsA("Model")
		while m and m:GetAttribute("Kit") == nil do
			m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
		end
		return m
	end
	local function structural(p)
		-- invisible world parts (the map's boundary, triggers) are not something a player sees a prop run into; a kit
		-- prop's colliders are invisible too, but they stand for the prop
		if p.Transparency >= 0.99 and ownerKitOf(p) == nil then
			return false
		end
		local s = p.Size
		local a, b, c = s.X, s.Y, s.Z
		local big = (a >= 3 and 1 or 0) + (b >= 3 and 1 or 0) + (c >= 3 and 1 or 0)
		return big >= 2
	end
	local function ownerKit(p)
		local m = p:FindFirstAncestorWhichIsA("Model")
		while m and m:GetAttribute("Kit") == nil do
			m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
		end
		return m
	end
	-- the overlap of two oriented boxes, measured on the second box's axes (good enough for walls and slabs)
	local function depthInto(cfA, sA, part)
		-- an upright tank or silo: radial depth (its box would count the corners round it)
		if okF and part:IsA("Part") and part.Shape == Enum.PartType.Cylinder and math.abs(part.CFrame.RightVector.Y) > 0.9 then
			return (Tidy.intoWall(cfA, sA, part))
		end
		local rel = part.CFrame:PointToObjectSpace(cfA.Position)
		local half = part.Size / 2
		local r = sA / 2
		local dx = math.min(half.X, rel.X + r.X) - math.max(-half.X, rel.X - r.X)
		local dy = math.min(half.Y, rel.Y + r.Y) - math.max(-half.Y, rel.Y - r.Y)
		local dz = math.min(half.Z, rel.Z + r.Z) - math.max(-half.Z, rel.Z - r.Z)
		return math.min(dx, dy, dz)
	end

	-- what the tidy pass did on a map at the last build: lines starting with what (doorway, twin, stacked, water, lifted,
	-- moved, wedged, left), optionally only those
	function C.tidylog(mapId, what)
		local log = okF and Tidy.last and Tidy.last[mapId]
		if not log then
			return "no tidy log for " .. tostring(mapId)
		end
		local out = {}
		for _, line in log do
			if not what or string.sub(line, 1, #what) == what then
				table.insert(out, line)
			end
		end
		return table.concat(out, "\n")
	end

	-- the doors the tidy pass hung another way (hinge at +X, or opening toward +Z) or stopped short: id, position, how
	function C.doorhangs(mapId)
		local W = ctx.World
		local m = W.maps and W.maps[mapId]
		local model = m and m.model
		local out = {}
		for id, d in W.doors or {} do
			if d.part and (not model or d.part:IsDescendantOf(model)) and (d.hinge or d.turn or d.swing) then
				local p = d.cf.Position
				table.insert(out, string.format("%s @ %.1f, %.1f, %.1f hinge %s turn %s swing %s", tostring(id), p.X, p.Y, p.Z,
					tostring(d.hinge or -1), tostring(d.turn or 1), tostring(d.swing or 100)))
			end
		end
		table.sort(out)
		return table.concat(out, "\n")
	end

	-- every exit of a map walked from the spawns that may use it: a path for a player-sized agent (radius 1, 5.6 tall,
	-- jumping allowed) from each spawn to the exit zone. Per exit: its rule, how many of its spawns reach it, the
	-- shortest and longest walk in studs, and the spawns that cannot.
	-- long walks take a while: exitcheck starts the run and returns; exitresult reads it (or how far it has got)
	local exitRuns = {}
	function C.exitresult(mapId)
		local r = exitRuns[mapId]
		if not r then
			return "not started"
		end
		return (r.done and "done" or ("running, " .. #r.out .. " exits so far")) .. "\n" .. table.concat(r.out, "\n")
	end
	function C.exitcheck(mapId, maxSpawns)
		local PFS = game:GetService("PathfindingService")
		local W = ctx.World
		local m = W.maps and W.maps[mapId]
		if not m then
			return "no map " .. tostring(mapId)
		end
		maxSpawns = maxSpawns or 99
		local run = { out = {}, done = false }
		exitRuns[mapId] = run
		task.spawn(function()
		local out = run.out
		local ids = {}
		for id in m.extracts or {} do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local e = m.extracts[id]
			local goal = (e.pos or e.cf.Position) + Vector3.new(0, 2.5, 0)
			local ok, fail, lo, hi, n = 0, {}, math.huge, 0, 0
			for _, sp in m.spawns or {} do
				if n < maxSpawns and (not sp.extracts or table.find(sp.extracts, id)) then
					n += 1
					local path = PFS:CreatePath({ AgentRadius = 1.0, AgentHeight = 5.6, AgentCanJump = true, WaypointSpacing = 12 })
					local from = sp.cf.Position
					local good = pcall(function()
						path:ComputeAsync(from, goal)
					end)
					if good and path.Status == Enum.PathStatus.Success then
						local wps, len = path:GetWaypoints(), 0
						for i = 2, #wps do
							len += (wps[i].Position - wps[i - 1].Position).Magnitude
						end
						ok += 1
						lo, hi = math.min(lo, len), math.max(hi, len)
					else
						table.insert(fail, string.format("%s (%.0f, %.0f)", tostring(sp.name or "?"), from.X, from.Z))
					end
					task.wait()
				end
			end
			local rule = e.rule or {}
			table.insert(out, string.format("%s %s [%s%s]: %d of %d spawns reach it%s%s", id, tostring(e.name), tostring(rule.kind),
				rule.cost and (" " .. tostring(rule.cost)) or "", ok, n, ok > 0 and string.format(", %.0f to %.0f studs", lo, hi) or "",
				#fail > 0 and (" · cannot: " .. table.concat(fail, "; ")) or ""))
		end
		run.done = true
		end)
		return "started"
	end

	function C.audit(mapId, examples)
		examples = examples or 12
		local W = ctx.World
		local m = W.maps and W.maps[mapId]
		local model = m and m.model
		if not model then
			return "no map " .. tostring(mapId)
		end
		local out = {}
		local function note(kind, name, pos, detail)
			local k = out[kind]
			if not k then
				k = { n = 0, ex = {}, by = {} }
				out[kind] = k
			end
			k.n += 1
			local key = string.match(name, "^[^%(]+") or name
			k.by[key] = (k.by[key] or 0) + 1
			if #k.ex < examples then
				table.insert(k.ex, { name = name, at = vs(pos), detail = detail })
			end
		end

		local props, trees, steps = {}, {}, {}
		for _, d in model:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Kit") ~= nil then
				table.insert(props, d)
			elseif d:IsA("MeshPart") and (d.Name == "Trunk" or d.Name == "Crown" or d.Name == "Bush") then
				table.insert(trees, d)
			elseif d:IsA("BasePart") and d.Anchored and d.CanCollide then
				local s = d.Size
				if (math.abs(s.X - 0.8) < 0.05 or math.abs(s.Z - 0.8) < 0.05) and math.max(s.X, s.Z) > 3 and math.max(s.X, s.Z) < 6 then
					table.insert(steps, d)
				end
			end
		end
		local stepSet = {}
		for _, s in steps do
			stepSet[s] = true
		end

		local boxes = {}
		for i, pm in props do
			if i % 200 == 0 then
				task.wait()
			end
			if FIXED[pm:GetAttribute("Kit")] then
				continue
			end
			local cf, size = pm:GetBoundingBox()
			local name = pm:GetAttribute("Kit") .. " (" .. (pm.Parent and pm.Parent.Name or "?") .. ")"
			table.insert(boxes, { cf = cf, size = size, m = pm })
			local up, right, look = cf.UpVector, cf.RightVector, cf.LookVector
			local half = size / 2
			-- the box's lowest face in world space (props stand upright; a tipped prop is checked on its own axes)
			local bottom = cf.Position - up * half.Y
			local rp = rayParams({ pm })
			-- 1. footing: five rays from just above the base down 0.8 studs
			local supported = false
			for _, o in { Vector2.new(0, 0), Vector2.new(0.6, 0.6), Vector2.new(-0.6, 0.6), Vector2.new(0.6, -0.6), Vector2.new(-0.6, -0.6) } do
				local from = bottom + right * (o.X * half.X) + look * (o.Y * half.Z) + up * 0.3
				local hit = workspace:Raycast(from, -up * 1.1, rp)
				if hit then
					supported = true
					break
				end
			end
			if not supported and not pm:GetAttribute("Raised") then
				-- hung: a wall within reach of a side, or a ceiling just above
				local hung = false
				for _, dir in { right, -right, look, -look } do
					local reach = (dir == right or dir == -right) and half.X or half.Z
					if workspace:Raycast(cf.Position, dir * (reach + 0.5), rp) then
						hung = true
						break
					end
				end
				if not hung and workspace:Raycast(cf.Position + up * half.Y, up * 0.8, rp) then
					hung = true
				end
				if not hung then
					local below = workspace:Raycast(bottom, -up * 40, rp)
					note("floating", name, cf.Position, below and string.format("%.1f studs above %s", below.Distance, below.Instance.Name) or "nothing below for 40 studs")
				end
			end
			-- 2. sunk: a solid surface inside the box above its base
			local fromTop = workspace:Raycast(cf.Position + up * (half.Y + 0.05), -up * (size.Y + 1), rp)
			if fromTop and (fromTop.Instance == workspace.Terrain or structural(fromTop.Instance)) and string.sub(fromTop.Instance.Name, 1, 5) ~= "Loot_" then
				local depth = (fromTop.Position - bottom):Dot(up)
				-- deeper than 60 % of its height is a table top or a shelf over it (a chair pushed in), not a floor
				if depth > 0.3 and depth > size.Y * 0.2 and depth < size.Y * 0.6 then
					note("sunk", name, cf.Position, string.format("%.1f of %.1f studs into %s", depth, size.Y, fromTop.Instance.Name))
				end
			end
			-- 3. clipping: solid parts inside the box shrunk by 0.3 (and lifted off the floor)
			local inner = Vector3.new(math.max(0.1, size.X - 0.6), math.max(0.1, size.Y - 0.6), math.max(0.1, size.Z - 0.6))
			local parts = workspace:GetPartBoundsInBox(cf * CFrame.new(0, 0.15, 0), inner, solidParams({ pm }))
			local worst, worstP = 0, nil
			for _, p in parts do
				if not stepSet[p] and p:IsDescendantOf(model) and structural(p) and string.sub(p.Name, 1, 5) ~= "Loot_" then
					local d = depthInto(cf, inner, p)
					if d > worst then
						worst, worstP = d, p
					end
				end
			end
			if worstP and worst > 0.3 then
				note("clipping", name, cf.Position, string.format("%.1f studs into %s %s", worst, worstP.Name, vs(worstP.Size)))
			end
			-- 5. stairs: a step under the base
			for _, o in { Vector2.new(0, 0), Vector2.new(0.5, 0.5), Vector2.new(-0.5, -0.5) } do
				local from = bottom + right * (o.X * half.X) + look * (o.Y * half.Z) + up * 0.3
				local hit = workspace:Raycast(from, -up * 1.1, rp)
				if hit and stepSet[hit.Instance] then
					note("stairs", name, cf.Position, "stands on a stair flight")
					break
				end
			end
		end

		-- 4. doors: props in the doorway (the closed leaf, 1.2 studs either side) or in the leaf's way as it opens to its
		-- angle (Doors.luau: d.swing, else 100 degrees about the hinge)
		local doorN = 0
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = { model }
		for id, d in W.doors or {} do
			if d.part and d.part:IsDescendantOf(model) and d.cf and d.size then
				doorN += 1
				local w = d.size.X
				-- how it hangs (Doors.luau, set by the tidy pass): hinge end, opening side, angle
				local hs, turn = d.hinge or -1, d.turn or 1
				local hinge = d.cf * CFrame.new(hs * w / 2, 0, 0)
				local seen = {}
				local function check(cf, box, why)
					for _, p in workspace:GetPartBoundsInBox(cf, box, op) do
						local km = ownerKit(p)
						if km and km:IsDescendantOf(model) and not seen[km] and not km:IsAncestorOf(d.part) and km:GetAttribute("Kit") ~= "DoorFrame" then
							seen[km] = true
							note("door", km:GetAttribute("Kit") .. " (" .. (km.Parent and km.Parent.Name or "?") .. ")", km:GetPivot().Position, why .. " of door " .. tostring(id))
						end
					end
				end
				check(d.cf, Vector3.new(w * 0.9, d.size.Y * 0.9, d.size.Z + 2.4), "in the doorway")
				for a = 20, d.swing or 100, 10 do
					check(hinge * CFrame.Angles(0, math.rad(turn * a), 0) * CFrame.new(-hs * (w / 2 + 0.25), 0, 0), Vector3.new(math.max(0.1, w - 0.5), d.size.Y * 0.85, math.max(0.2, d.size.Z)), "in the swing")
				end
			end
		end

		-- 6. stacked props
		for i = 1, #boxes do
			local a = boxes[i]
			for j = i + 1, #boxes do
				local b = boxes[j]
				local dp = b.cf.Position - a.cf.Position
				local reach = (a.size.Magnitude + b.size.Magnitude) / 2
				if dp.Magnitude < reach then
					-- world-aligned overlap of the two boxes' extents (props stand upright)
					local function ext(x)
						local cf, s = x.cf, x.size
						local r = cf.RightVector * s.X / 2
						local u = cf.UpVector * s.Y / 2
						local l = cf.LookVector * s.Z / 2
						local e = Vector3.new(math.abs(r.X) + math.abs(u.X) + math.abs(l.X), math.abs(r.Y) + math.abs(u.Y) + math.abs(l.Y), math.abs(r.Z) + math.abs(u.Z) + math.abs(l.Z))
						return cf.Position - e, cf.Position + e
					end
					local a0, a1 = ext(a)
					local b0, b1 = ext(b)
					local ox = math.min(a1.X, b1.X) - math.max(a0.X, b0.X)
					local oy = math.min(a1.Y, b1.Y) - math.max(a0.Y, b0.Y)
					local oz = math.min(a1.Z, b1.Z) - math.max(a0.Z, b0.Z)
					if ox > 0 and oy > 0 and oz > 0 then
						local vo = ox * oy * oz
						local va = (a1.X - a0.X) * (a1.Y - a0.Y) * (a1.Z - a0.Z)
						local vb = (b1.X - b0.X) * (b1.Y - b0.Y) * (b1.Z - b0.Z)
						local share = vo / math.max(0.01, math.min(va, vb))
						-- a prop on a shelf or a table shares its footprint but not its height: count only real interpenetration
						local ka, kb = a.m:GetAttribute("Kit"), b.m:GetAttribute("Kit")
						-- a chair pushed in under a desk or a table is how they stand
						-- (not the office desk: its kit has its own chair)
						local tucked = (ka == "Chair" or kb == "Chair") and (ka == "Table" or kb == "Table" or ka == "TechTable" or kb == "TechTable" or ka == "CCTVDesk" or kb == "CCTVDesk")
						if share > 0.4 and not tucked and not FIXED[ka] and not FIXED[kb] and not a.m:IsAncestorOf(b.m) and not b.m:IsAncestorOf(a.m) then
							note("stacked", a.m:GetAttribute("Kit") .. " + " .. b.m:GetAttribute("Kit"), a.cf.Position, string.format("%d %% of the smaller box shared", math.floor(share * 100)))
						end
					end
				end
			end
			if i % 300 == 0 then
				task.wait()
			end
		end

		-- 8. containers: a loot container's own box (a crate, a safe, a drawer box) run into a prop or a wall
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and string.sub(part.Name, 1, 5) == "Loot_" and ownerKit(part) == nil and part.CanCollide then
				local op2 = OverlapParams.new()
				op2.FilterType = Enum.RaycastFilterType.Include
				op2.FilterDescendantsInstances = { model }
				op2.RespectCanCollide = true
				local inner = Vector3.new(math.max(0.1, part.Size.X - 0.6), math.max(0.1, part.Size.Y - 0.6), math.max(0.1, part.Size.Z - 0.6))
				local worst, what = 0, nil
				for _, p in workspace:GetPartBoundsInBox(part.CFrame * CFrame.new(0, 0.15, 0), inner, op2) do
					if p ~= part and not stepSet[p] and structural(p) and string.sub(p.Name, 1, 5) ~= "Loot_" then
						local d = depthInto(part.CFrame, inner, p)
						if d > worst then
							local km = ownerKit(p)
							worst, what = d, km and km:GetAttribute("Kit") or p.Name
						end
					end
				end
				if what and worst > 0.3 then
					note("container", part.Name .. " in " .. what, part.Position, string.format("%.1f studs into it", worst))
				end
			end
		end

		-- 7. trees: trunks inside buildings, crowns and bushes through roofs and walls
		for i, t in trees do
			if i % 300 == 0 then
				task.wait()
			end
			local shrink = (t.Name == "Trunk") and 0.4 or 0.45
			local inner = Vector3.new(t.Size.X * shrink, t.Size.Y * ((t.Name == "Trunk") and 0.8 or 0.5), t.Size.Z * shrink)
			local hits = workspace:GetPartBoundsInBox(t.CFrame, inner, solidParams({ t }))
			for _, p in hits do
				if p:IsDescendantOf(model) and structural(p) and p.Name ~= "Trunk" and ownerKit(p) == nil then
					note("tree", t.Name, t.Position, "inside " .. p:GetFullName():sub(-60))
					break
				end
			end
		end

		-- 10. gaps: furniture that belongs against a wall standing 0.25 to 1.6 studs off the wall behind it
		local BACKED = {}
		for _, n in { "Locker", "Lockers", "LockerOpen", "StorageShelf", "StorageShelfEmpty", "StorageRack", "MedShelf", "Fridge",
			"FridgeBroken", "ElectricCabinet", "FuseBox", "ToolChest", "CraftBench", "GunBench", "OfficeDesk", "BunkBed", "BunkBedMessy",
			"WaterTank", "HideoutGenerator", "Vending", "VendingBroken", "GondolaSparse", "PalletRack" } do
			BACKED[n] = true
		end
		for _, b in boxes do
			local kitName = b.m:GetAttribute("Kit")
			if BACKED[kitName] then
				local cf, size = b.cf, b.size
				local back = cf.LookVector * -1 -- a kit's front is its -Z (LookVector); the back is the other way
				local half = size.Z / 2
				local rp = rayParams({ b.m })
				local gaps = {}
				for _, h in { -0.25, 0.1, 0.35 } do
					local from = cf.Position + cf.UpVector * (size.Y * h)
					local hit = workspace:Raycast(from, back * (half + 1.6), rp)
					if hit and structural(hit.Instance) and ownerKit(hit.Instance) == nil and hit.Normal:Dot(back) < -0.8 then
						table.insert(gaps, hit.Distance - half)
					else
						table.insert(gaps, false)
					end
				end
				if gaps[1] and gaps[2] and gaps[3] then
					local g = math.min(gaps[1], gaps[2], gaps[3])
					if g > 0.25 and g < 1.6 then
						note("gap", kitName .. " (" .. (b.m.Parent and b.m.Parent.Name or "?") .. ")", cf.Position, string.format("%.2f studs off the wall behind", g))
					end
				end
			end
		end

		-- 9. outdoors: trees and bushes on a road; fences, rails and power poles run through a building
		local function folder(name)
			return model:FindFirstChild(name)
		end
		local roads = folder("Roads")
		if roads then
			local op3 = OverlapParams.new()
			op3.FilterType = Enum.RaycastFilterType.Include
			op3.FilterDescendantsInstances = { roads }
			for i, t in trees do
				if i % 400 == 0 then
					task.wait()
				end
				if t.Name ~= "Crown" then
					-- the foot of the trunk or the bush, a little inside its outline
					local foot = CFrame.new(t.Position.X, t.Position.Y - t.Size.Y / 2 + 0.5, t.Position.Z)
					local hits = workspace:GetPartBoundsInBox(foot, Vector3.new(t.Size.X * 0.5, 1.5, t.Size.Z * 0.5), op3)
					if #hits > 0 then
						note("road", t.Name, t.Position, "stands on " .. hits[1].Name .. " " .. vs(hits[1].Size))
					end
				end
			end
		end
		local buildingSets = {}
		for _, n in { "Living", "Works", "Outside", "Mall", "StoresL1", "StoresL2", "StoresFill" } do
			local f = folder(n)
			if f then
				table.insert(buildingSets, f)
			end
		end
		if #buildingSets > 0 then
			local op4 = OverlapParams.new()
			op4.FilterType = Enum.RaycastFilterType.Include
			op4.FilterDescendantsInstances = buildingSets
			op4.RespectCanCollide = true
			for _, fname in { "Fences", "Rails", "Power" } do
				local f = folder(fname)
				if f then
					local seen = {}
					for i, p in f:GetDescendants() do
						if i % 500 == 0 then
							task.wait()
						end
						if p:IsA("BasePart") and p.Transparency < 0.99 then
							local inner = Vector3.new(math.max(0.05, p.Size.X - 0.4), math.max(0.05, p.Size.Y - 0.4), math.max(0.05, p.Size.Z - 0.4))
							for _, q in workspace:GetPartBoundsInBox(p.CFrame, inner, op4) do
								if structural(q) and ownerKit(q) == nil then
									-- one note per building for each fence, rail or line
									local bld = q
									while bld.Parent and not table.find(buildingSets, bld.Parent) do
										bld = bld.Parent
									end
									local key = (p.Parent and p.Parent.Name or "?") .. "|" .. bld.Name
									if not seen[key] then
										seen[key] = true
										note(string.lower(fname), (p.Parent and p.Parent.Name or "?") .. " through " .. bld.Name, p.Position, p.Name .. " " .. vs(p.Size) .. " into " .. q.Name .. " " .. vs(q.Size))
									end
									break
								end
							end
						end
					end
				end
			end
		end

		local report = { map = mapId, props = #props, trees = #trees, steps = #steps, doors = doorN, checks = out }
		return HttpService:JSONEncode(report)
	end
end

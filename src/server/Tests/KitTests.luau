--!nonstrict
-- Modular kit (decision art-5b, docs/look/MODULAR_KIT.md): stair flights and railings (phase 1) and chain-link fence posts
-- and rails (phase 2) are Kit5 meshes with invisible colliders where the ZR_Kit5A / ZR_Kit5B / ZR_Kit5C batches are loaded,
-- and today's parts where they are not (Maps/MapKit's k5Flight, k5Rail and k5Fence; every stair, railing and fence builder
-- keeps its parts as the fallback). Run via ZR_Dev "tests".
--   K01 the kit's numbers: every Kit5 variant build_kit5.py makes is in the metadata (KitMeta) and its size is MapKit's
--       (riser, tread, width, module length, fence height), or none of a batch is (not uploaded yet: the checks that need
--       that batch are skipped)
--   K02 a flight of each style, a railing and a fence built here, far off the maps: the mesh takes no collisions, rays or
--       touches; the ramp meets a ray at the middle of every tread within 0.05 of the tread, and starts at the foot; the
--       railing's modules and its collider; the fence's modules, its end bays and its chain-link panel, which still
--       collides; a flight, railing or fence no variant fits is left to its builder (nil)
--   K03 ZR_Move: bodies and plain rays meet a railing's collider, bullets (ZR_Shot) and the AI's sight (ZR_Sight) pass it
--   K04 the Smelter rebuilt in a sandbox (never in the world) with the kit and without: every flight and railing call took
--       the kit (when it is loaded) or its parts; without the kit it builds today's 1,109 stair and 837 railing parts, with
--       it at most 200 and 480 (Studio: the 219 rails of the walkability pass take 468) and every other group the same
--   K05 the built maps: every Kit5 flight has its ramp, every Kit5 railing its body-only collider, every Kit5 fence its
--       modules, no kit mesh collides and no Kit5 model is a "Kit" prop (the tidy pass would move it)
--   K06 merged pieces (phase 2): every mall and bunker prop built with Kit.MERGE off and on has the same colliders (count,
--       size, place, material, CanQuery, CanCollide); with a merged mesh loaded the prop takes it and has fewer parts, a
--       tinted placement and the NOMERGE props keep their pieces
--   K07 (a note, not a check; Studio only) does a kit mesh's own collision keep its doorway open? The WallBreach and
--       DoorFrame pieces remade by AssetService:CreateMeshPartAsync at each CollisionFidelity, a ray through the
--       opening and one into the jamb
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local KitMeta = require(Shared:WaitForChild("KitMeta"))

local T = {}

-- build_kit5.py's variant lists (FLIGHTS, HANDS, RAILS): keep in step with it
local FLIGHT_COUNTS = { C = { 4, 36, 50 }, O = { 4, 24 }, S = { 4, 36 }, E = { 50, 50 } }
local HAND_COUNTS = { A = { 4, 36 }, B = { 4, 24 } }
-- the offline census (tools/kit_census.py, 2026-11-09): the Smelter's two pilot groups before and after
local SMELTER_BEFORE = { Stairs = 1109, Railings = 837 } -- after art-1a's walkability pass (tower landing rails, side panels)
local SMELTER_AFTER = { Stairs = 200, Railings = 480 } -- at most (Studio 2026-11-09: 468 railing parts for 219 rails)

local function names()
	local list = {}
	for st, r in FLIGHT_COUNTS do
		for n = r[1], r[2] do
			table.insert(list, "K5Stair" .. st .. n)
		end
		if r[3] then
			table.insert(list, "K5Stair" .. st .. r[3])
		end
	end
	for fam, r in HAND_COUNTS do
		for n = r[1], r[2] do
			table.insert(list, "K5Hand" .. fam .. n)
		end
	end
	return list
end

local function count(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- a kit whose world-facing calls go nowhere (containers, exits, loose loot, guns, foliage) and whose World is a scratch
-- table, so a map can be built into a folder outside the world without touching the live one
local function sandbox(W)
	local kit = table.clone(W.kit())
	local fake = { foliage = { cells = {}, n = 0 } }
	for _, k in { "spawns", "extracts", "containers", "patrols", "doors", "switches", "looseSpots", "sideExtracts", "scavZones", "watchPosts", "visitZones", "natureRegions", "transits", "maps", "bosses" } do
		fake[k] = {}
	end
	local root = Instance.new("Folder")
	root.Name = "KitTestSandbox"
	local trig = Instance.new("Folder")
	trig.Name = "Triggers"
	trig.Parent = root
	kit.World, kit.root = fake, root
	kit.container = function() end
	kit.extract = function() end
	kit.loose = function() end
	kit.foliage = function()
		return {}
	end
	kit.stationary = function()
		return nil
	end
	return kit, root
end

function T.run(ctx)
	local passed, failed, notes, skipped = 0, 0, {}, 0
	local function check(name, cond, info)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name .. (info ~= nil and (" [" .. tostring(info) .. "]") or ""))
		end
	end
	local W = ctx and ctx.World
	if not (W and W.kit) then
		return "0 passed, 0 failed, skipped (no World)"
	end
	local Maps = script.Parent.Parent:WaitForChild("Maps")
	local H = require(Maps:WaitForChild("MapKit"))(W.kit(), Vector3.zero)
	local K5 = H.K5
	local loaded = H.k5Ready("K5StairC12") and H.k5Ready("K5Rail16")
	local fenceLoaded = H.k5Ready("K5Fence16")

	-- ── K01 the numbers ───────────────────────────────────────────────────────────────────────────────────────
	local want, fences = names(), {}
	for i = 1, #K5.RAIL_LENGTHS do
		table.insert(want, "K5Rail" .. i)
		table.insert(fences, "K5Fence" .. i)
	end
	-- a fence module runs from its origin along -Z (its end posts stand on its ends: the caps reach 0.14 past them), sunk
	-- 0.6 into the ground, its caps 0.13 above FENCE_H0
	local function badSize(nm, p)
		local st, n = string.match(nm, "^K5Stair(%a)(%d+)$")
		local ri = tonumber(string.match(nm, "^K5Rail(%d+)$"))
		local fi = tonumber(string.match(nm, "^K5Fence(%d+)$"))
		if #p.pieces ~= 1 then
			return true
		elseif st then
			n = tonumber(n)
			return math.abs(p.size.X - K5.W0) > 0.02 or math.abs(p.size.Z - n * K5.T0) > 0.06
		elseif ri then
			return math.abs(p.size.Z - K5.RAIL_LENGTHS[ri]) > 0.03 or p.size.Y < 3.3 or p.size.Y > 3.5
		elseif fi then
			local l0 = K5.RAIL_LENGTHS[fi]
			return math.abs(p.size.Z - l0 - 0.28) > 0.06 or math.abs(p.center.Z + l0 / 2) > 0.03 or math.abs(p.size.Y - (K5.FENCE_H0 + 0.73)) > 0.06
		end
		return p.size.X > 0.35
	end
	for _, fam in { { want, "ZR_Kit5A / ZR_Kit5B", "flights, handrails and railings" }, { fences, "ZR_Kit5C", "fence modules" } } do
		local present, missing, bad = 0, {}, {}
		for _, nm in fam[1] do
			local p = KitMeta.props[nm]
			if p then
				present += 1
				if badSize(nm, p) then
					table.insert(bad, nm)
				end
			else
				table.insert(missing, nm)
			end
		end
		if present == 0 then
			table.insert(notes, "note: no " .. fam[3] .. " in KitMeta yet (upload " .. fam[2] .. ", then tools/kit_meta.py): the builders use their parts")
		else
			check("K01 every Kit5 variant build_kit5.py makes is in KitMeta (" .. fam[3] .. ")", #missing == 0, #missing .. " missing, first " .. tostring(missing[1]))
			check("K01 every Kit5 variant has MapKit's size, one piece (" .. fam[3] .. ")", #bad == 0, table.concat(bad, ","))
		end
	end
	check("K01 the flight tolerances cover the maps' risers (0.44 .. 0.66 studs) and treads (0.39 .. 2.7)",
		0.44 / K5.H0 >= K5.SY[1] and 0.66 / K5.H0 <= K5.SY[2] and 0.39 / K5.T0 >= K5.SZ[1] and 2.71 / K5.T0 <= K5.SZ[2])
	check("K01 every railing length from 0.5 studs up finds a module within the stretch limit", (function()
		for L = 0.5, 200, 0.25 do
			local k = math.max(1, math.ceil(L / K5.RAIL_SPLIT - 1e-6))
			local piece, best = L / k, math.huge
			for _, l0 in K5.RAIL_LENGTHS do
				best = math.min(best, math.abs(piece / l0 - 1))
			end
			if best > K5.STRETCH then
				return false
			end
		end
		return true
	end)())

	-- ── K02 a flight of each style and a railing, far off the maps ───────────────────────────────────────────────
	local scratch = Instance.new("Folder")
	scratch.Name = "KitTestScratch"
	scratch.Parent = workspace
	local okK2, errK2 = pcall(function()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { scratch }
		-- no variant fits: the builder keeps its parts
		check("K02 a flight no variant fits (a 1.2-stud riser) or no count exists (99 steps) is left to its builder",
			H.k5Flight(scratch, CFrame.new(6000, 600, 6000), 12, 1.2, 0.8, 4, "C", Color3.new(1, 1, 1), Enum.Material.Concrete) == nil
				and H.k5Flight(scratch, CFrame.new(6000, 600, 6000), 99, 0.5, 0.8, 4, "C", Color3.new(1, 1, 1), Enum.Material.Concrete) == nil)
		check("K02 a sloped railing is left to its builder (sloped rails come with their flight)",
			H.k5Rail(scratch, Vector3.new(6000, 600, 6000), Vector3.new(6010, 602, 6000), Color3.new(1, 1, 1), Enum.Material.Metal) == nil)
		K5.enabled = false
		local off = H.k5Flight(scratch, CFrame.new(6000, 600, 6000), 12, 0.5, 0.8, 4, "C", Color3.new(1, 1, 1), Enum.Material.Concrete)
		K5.enabled = true
		check("K02 with the kit switched off a flight is left to its builder", off == nil)
		if not loaded then
			skipped += 4
			return
		end
		for i, spec in { { "C", 12, 0.5, 0.8, 4 }, { "O", 11, 0.5, 0.87, 4 }, { "S", 20, 0.48, 0.95, 6 }, { "E", 50, 0.594, 1.2, 14.4 }, { "C", 18, 0.644, 0.97, 4.6, true } } do
			local st, n, h, t, w, hand = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
			local cf = CFrame.new(6000 + i * 80, 600, 6000) * CFrame.Angles(0, math.rad(37 * i), 0)
			local m = H.k5Flight(scratch, cf, n, h, t, w, st, Color3.new(0.6, 0.6, 0.6), st == "S" and Enum.Material.DiamondPlate or Enum.Material.Concrete,
				{ hand = hand and "both" or nil })
			local tag = st .. n .. (hand and "+hand" or "")
			check("K02 flight " .. tag .. " is built from the kit", m ~= nil)
			if m then
				local meshes, cosmetic, ramp = 0, true, m:FindFirstChild("StairRamp")
				for _, d in m:GetDescendants() do
					if d:IsA("MeshPart") then
						meshes += 1
						cosmetic = cosmetic and not d.CanCollide and not d.CanQuery and not d.CanTouch
					end
				end
				check("K02 flight " .. tag .. ": one mesh (and one per handrail), none collides, takes rays or touches", meshes == (hand and 3 or 1) and cosmetic, meshes)
				check("K02 flight " .. tag .. ": an invisible ramp that collides", ramp ~= nil and ramp.CanCollide and ramp.CanQuery and ramp.Transparency == 1)
				local worst, foot = 0, nil
				for k = 1, n do
					local top = cf * Vector3.new(0, k * h + 3, -(k - 0.5) * t)
					local hit = workspace:Raycast(top, Vector3.new(0, -8, 0), rp)
					local dy = hit and hit.Instance == ramp and math.abs(hit.Position.Y - (cf.Y + k * h)) or math.huge
					worst = math.max(worst, dy)
				end
				-- the ramp reaches the floor half a tread in front of the first riser (no lip to step onto)
				local hitFoot = workspace:Raycast(cf * Vector3.new(0, 2, t / 2 - 0.05), Vector3.new(0, -4, 0), rp)
				foot = hitFoot and hitFoot.Instance == ramp and (hitFoot.Position.Y - cf.Y) or nil
				check("K02 flight " .. tag .. ": the ramp meets the middle of every tread within 0.05", worst <= 0.05, string.format("%.3f", worst))
				check("K02 flight " .. tag .. ": the ramp starts on the floor half a tread before the first riser", foot ~= nil and foot <= 0.06, foot)
				if hand then
					local rc = 0
					for _, d in m:GetChildren() do
						if d.Name == "RailCollider" and d.CollisionGroup == K5.MOVE_GROUP and d.CanCollide then
							rc += 1
						end
					end
					check("K02 flight " .. tag .. ": a body-only collider on each handrail", rc == 2, rc)
				end
				check("K02 flight " .. tag .. ": structure, not a tidy-pass prop", m:GetAttribute("Kit") == nil and m:GetAttribute("Kit5") ~= nil)
			end
		end
		local a, b = Vector3.new(6000, 600, 6200), Vector3.new(6150, 600, 6200)
		local r = H.k5Rail(scratch, a, b, Color3.new(0.3, 0.3, 0.3), Enum.Material.Metal)
		check("K02 a 150-stud railing is three Kit5 modules and one collider", r ~= nil and #r:GetChildren() == 4, r and #r:GetChildren())
		-- ── K03 the collider stops bodies and plain rays, not bullets or sight ─────────────────────────────────────
		if r then
			local function cast(group)
				local p = RaycastParams.new()
				p.FilterType = Enum.RaycastFilterType.Include
				p.FilterDescendantsInstances = { r }
				if group then
					p.CollisionGroup = group
				end
				return workspace:Raycast(Vector3.new(6075, 602, 6195), Vector3.new(0, 0, 10), p)
			end
			local plain, shot, sight = cast(nil), cast("ZR_Shot"), cast("ZR_Sight")
			check("K03 a railing's collider meets plain rays (bodies, the camera, vaults) and passes bullets and the AI's sight",
				plain ~= nil and plain.Instance.Name == "RailCollider" and shot == nil and sight == nil,
				string.format("%s %s %s", tostring(plain and plain.Instance.Name), tostring(shot and shot.Instance.Name), tostring(sight and sight.Instance.Name)))
		end
	end)
	-- fences (phase 2): the posts and the top rail are the kit, the chain-link panel stays the builder's collider
	local okF, errF = pcall(function()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { scratch }
		local grey = Color3.new(0.43, 0.44, 0.42)
		check("K02 a steep fence run (3 studs over 20) or one of an odd height (12 studs) is left to its builder",
			H.k5Fence(scratch, Vector3.new(6000, 600, 6400), Vector3.new(6020, 603, 6400), 7.8, grey, Enum.Material.Metal) == nil
				and H.k5Fence(scratch, Vector3.new(6000, 600, 6400), Vector3.new(6020, 600, 6400), 12, grey, Enum.Material.Metal) == nil)
		K5.enabled = false
		local off = H.k5Fence(scratch, Vector3.new(6000, 600, 6400), Vector3.new(6020, 600, 6400), 7.8, grey, Enum.Material.Metal)
		K5.enabled = true
		check("K02 with the kit switched off a fence is left to its builder", off == nil)
		if not fenceLoaded then
			skipped += 4
			return
		end
		local f = Instance.new("Folder")
		f.Name = "FenceScratch"
		f.Parent = scratch
		local panel = H.fence(f, 6000, 6400, 6040, 6400, 600, 7.8, 600.5)
		local kits, loose, mods, cosmetic = {}, 0, 0, true
		for _, c in f:GetChildren() do
			if c:IsA("Model") and c:GetAttribute("Kit5") == "fence" then
				table.insert(kits, c)
				for _, d in c:GetDescendants() do
					if d:IsA("MeshPart") then
						mods += 1
						cosmetic = cosmetic and not d.CanCollide and not d.CanQuery and not d.CanTouch
					end
				end
			elseif c:IsA("BasePart") and c ~= panel then
				loose += 1
			end
		end
		check("K02 a 40-stud fence is one Kit5 module and its chain-link panel, no post or rail parts",
			#kits == 1 and mods == 1 and loose == 0 and panel ~= nil and panel.Name == "ChainLink", string.format("%d kits, %d modules, %d loose", #kits, mods, loose))
		check("K02 the fence module takes no collisions, rays or touches; structure, not a tidy-pass prop",
			cosmetic and kits[1] ~= nil and kits[1]:GetAttribute("Kit") == nil)
		local hit = workspace:Raycast(Vector3.new(6020, 603, 6395), Vector3.new(0, 0, 10), rp)
		check("K02 the chain-link panel still collides and meets a ray across the fence", panel ~= nil and panel.CanCollide and hit ~= nil and hit.Instance == panel,
			hit and hit.Instance.Name)
		-- the ends a builder marks as the fence line's ends are 8-stud bays of their own (the tidy pass trims a bay)
		local g = Instance.new("Folder")
		g.Name = "FenceScratch2"
		g.Parent = scratch
		H.fence(g, 6000, 6450, 6040, 6450, 600, 7.8, 600, { bayStart = true, bayEnd = true })
		local xs = {}
		for _, d in g:GetDescendants() do
			if d:IsA("MeshPart") then
				table.insert(xs, d.Position.X)
			end
		end
		table.sort(xs)
		check("K02 a fence with both ends marked is an 8-stud bay, the middle and an 8-stud bay",
			#xs == 3 and math.abs(xs[1] - (6000 + K5.FENCE_BAY / 2)) < 0.05 and math.abs(xs[3] - (6040 - K5.FENCE_BAY / 2)) < 0.05,
			table.concat(xs, ","))
	end)
	scratch:Destroy()
	K5.enabled = true
	check("K02 the scratch builds ran", okK2, errK2)
	check("K02 the fence scratch builds ran", okF, errF)

	-- ── K04 the Smelter rebuilt in a sandbox, with the kit and without ─────────────────────────────────────────
	local okK4, errK4 = pcall(function()
		local function build(on)
			K5.enabled = on
			local G = _G :: any
			G.ZR_KIT5_LOG = {}
			local kit, root = sandbox(W)
			local m = require(Maps:WaitForChild("Smelter"))(kit, root)
			local log = G.ZR_KIT5_LOG
			G.ZR_KIT5_LOG = nil
			K5.enabled = true
			local groups = {}
			for _, g in m:GetChildren() do
				groups[g.Name] = count(g)
			end
			root:Destroy()
			return groups, log
		end
		local before, logOff = build(false)
		local after, logOn = build(true)
		check("K04 without the kit the Smelter builds today's stairs and railings (1,109 and 837 parts, Studio 2026-11-09)",
			before.Stairs == SMELTER_BEFORE.Stairs and before.Railings == SMELTER_BEFORE.Railings, string.format("%s / %s", tostring(before.Stairs), tostring(before.Railings)))
		local offOk = #logOff > 0
		for _, e in logOff do
			offOk = offOk and e.kit == false
		end
		check("K04 without the kit every flight and railing call fell back to its parts", offOk, #logOff)
		local same = true
		for g, n in before do
			if g ~= "Stairs" and g ~= "Railings" and after[g] ~= n then
				same = false
			end
		end
		check("K04 the kit changes nothing but the stairs and railings", same)
		if loaded then
			local allKit, flights, rails = true, 0, 0
			for _, e in logOn do
				allKit = allKit and e.kit == true
				if e.kind == "flight" then
					flights += 1
				else
					rails += 1
				end
			end
			check("K04 with the kit every Smelter flight and railing is a Kit5 placement", allKit and flights == 72 and rails == 219, string.format("%d flights, %d rails", flights, rails))
			check("K04 with the kit the stairs drop to 200 parts or fewer (from 1,109)", (after.Stairs or 0) <= SMELTER_AFTER.Stairs, after.Stairs)
			check("K04 with the kit the railings drop to 480 parts or fewer (from 837)", (after.Railings or 0) <= SMELTER_AFTER.Railings, after.Railings)
		else
			skipped += 3
		end
	end)
	K5.enabled = true
	check("K04 the sandbox builds ran", okK4, errK4)

	-- ── K06 merged pieces: the same colliders both ways ───────────────────────────────────────────────────────────
	local Kit = require(Maps:WaitForChild("Kit"))
	local mergeWas = table.clone(Kit.MERGE)
	local okK6, errK6 = pcall(function()
		local list, withMerged = {}, 0
		for nm, p in KitMeta.props do
			if Kit.MERGE[p.batch] ~= nil then
				table.insert(list, nm)
				if p.merged then
					withMerged += 1
				end
			end
		end
		table.sort(list)
		local box = Instance.new("Folder")
		box.Name = "KitTestMerge"
		box.Parent = workspace
		local function build(name, on, opts)
			for b in Kit.MERGE do
				Kit.MERGE[b] = on
			end
			local m = Kit.place(box, name, CFrame.new(7000, 600, 7000) * CFrame.Angles(0, 0.6, 0), opts)
			local cols, pieces, merged = {}, 0, 0
			for _, c in m and m:GetChildren() or {} do
				if c.Name == "KitCollider" then
					table.insert(cols, c)
				elseif c:IsA("BasePart") then
					pieces += 1
					if c:GetAttribute("KitMerged") then
						merged += 1
					end
				end
			end
			return m, cols, pieces, merged
		end
		local diff, took, fewer, tinted, tintOk, skipOk = {}, 0, true, nil, true, true
		for _, nm in list do
			local m1, c1, p1 = build(nm, false)
			local m2, c2, p2, mg2 = build(nm, true)
			local same = #c1 == #c2
			for i = 1, math.min(#c1, #c2) do
				local a, b = c1[i], c2[i]
				same = same and (a.Size - b.Size).Magnitude < 1e-4 and (a.Position - b.Position).Magnitude < 1e-4 and a.Material == b.Material
					and a.CanQuery == b.CanQuery and a.CanCollide == b.CanCollide
			end
			if not same then
				table.insert(diff, nm)
			end
			if mg2 > 0 then
				took += 1
				fewer = fewer and p2 < p1
				skipOk = skipOk and not Kit.NOMERGE[nm]
			end
			local mg = KitMeta.props[nm].merged
			if mg and not tinted and table.find(mg.of, "paint") then
				tinted = nm
				local m3, _, _, mg3 = build(nm, true, { tint = Color3.fromRGB(150, 40, 30) })
				tintOk = mg3 == 0
				if m3 then
					m3:Destroy()
				end
			end
			for _, m in { m1, m2 } do
				if m then
					m:Destroy()
				end
			end
		end
		box:Destroy()
		check("K06 every mall and bunker prop built with Kit.MERGE off and on has the same colliders (count, size, place, material, CanQuery)",
			#list > 0 and #diff == 0, #list .. " props, differ: " .. table.concat(diff, ","))
		if withMerged == 0 then
			table.insert(notes, "note: no merged pieces in KitMeta yet (zr_kit.kit_export_merged, upload, then tools/kit_meta.py): Kit.MERGE changes nothing")
		elseif took == 0 then
			table.insert(notes, "note: KitMeta lists merged pieces but no ZR_MK_*_M mesh is loaded (the <batch>M assets): props keep their pieces")
		else
			check("K06 with the merge on, a prop whose merged mesh is loaded takes it and has fewer parts; NOMERGE props never do", fewer and skipOk, took .. " props merged")
			check("K06 a placement that tints a joined piece keeps its pieces", tinted == nil or tintOk, tinted)
		end
	end)
	for b in Kit.MERGE do
		Kit.MERGE[b] = mergeWas[b]
	end
	check("K06 the merge builds ran", okK6, errK6)

	-- ── K07 (a note): a kit mesh's own collision through its doorway ───────────────────────────────────────────────
	-- whether a prop's mesh could collide by itself instead of its box colliders (one part fewer per box) starts with
	-- whether its collision keeps an opening open: Box and Hull fill it, the finer fidelities may not
	local k7 = {}
	local okK7, errK7 = pcall(function()
		local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
		if not lib then
			return
		end
		local AssetService = game:GetService("AssetService")
		local folder = Instance.new("Folder")
		folder.Name = "KitTestMeshCollision"
		folder.Parent = workspace
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { folder }
		local at = CFrame.new(7400, 600, 7400) * CFrame.Angles(0, 0.4, 0)
		local across = at:VectorToWorldSpace(Vector3.new(0, 0, 12))
		-- prop, a point in the opening, a point in a jamb (prop space; the wall is the plane z = 0)
		for _, pr in { { "WallBreach", Vector3.new(0, 3, -6), Vector3.new(3.2, 4.5, -6) }, { "DoorFrame", Vector3.new(0, 4.25, -6), Vector3.new(4.25, 4.5, -6) } } do
			local p = KitMeta.props[pr[1]]
			local res = {}
			for _, fid in { "Box", "Hull", "Default", "PreciseConvexDecomposition" } do
				folder:ClearAllChildren()
				local made = 0
				for _, pc in p and p.pieces or {} do
					local src = lib:FindFirstChild("ZR_MK_" .. pr[1] .. "__" .. pc.mat)
					if src and src:IsA("MeshPart") and typeof(src.MeshId) == "string" and src.MeshId ~= "" then
						local mp = AssetService:CreateMeshPartAsync(src.MeshId, { CollisionFidelity = Enum.CollisionFidelity[fid] })
						mp.Size = src.Size
						mp.Anchored = true
						mp.CanCollide = true
						mp.CanQuery = true
						mp.CFrame = at * CFrame.new(pc.center)
						mp.Parent = folder
						made += 1
					end
				end
				if made > 0 then
					local open = workspace:Raycast(at * pr[2], across, rp) == nil
					local jamb = workspace:Raycast(at * pr[3], across, rp) ~= nil
					table.insert(res, fid .. (open and " open" or " shut") .. (jamb and "" or " (missed the jamb)"))
				end
			end
			if #res > 0 then
				table.insert(k7, pr[1] .. ": " .. table.concat(res, ", "))
			end
		end
		folder:Destroy()
	end)
	if #k7 > 0 then
		table.insert(notes, "K07 a kit mesh's own collision through its doorway: " .. table.concat(k7, "; "))
	elseif not okK7 then
		table.insert(notes, "K07 not run: " .. tostring(errK7))
	end

	-- ── K05 the built maps ──────────────────────────────────────────────────────────────────────────────────────
	local summary = {}
	for _, id in { "smelter", "border", "meridian", "quay7" } do
		local mm = W.maps and W.maps[id]
		local model = mm and mm.model
		if model then
			local flights, rails, fenceRuns, noRamp, noColl, noMods, solid, props = 0, 0, 0, 0, 0, 0, 0, 0
			for _, d in model:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("Kit5") ~= nil then
					if d:GetAttribute("Kit") ~= nil then
						props += 1
					end
					if d:GetAttribute("Flight") then
						flights += 1
						local ramp = d:FindFirstChild("StairRamp")
						if not (ramp and ramp.CanCollide and ramp.Transparency == 1) then
							noRamp += 1
						end
					elseif d:GetAttribute("Kit5") == "rail" then
						rails += 1
						local c = d:FindFirstChild("RailCollider")
						if not (c and c.CanCollide and c.CollisionGroup == K5.MOVE_GROUP) then
							noColl += 1
						end
					elseif d:GetAttribute("Kit5") == "fence" then
						fenceRuns += 1
						if not d:FindFirstChild("FenceModule") then
							noMods += 1
						end
					end
					for _, p in d:GetChildren() do
						if p:IsA("MeshPart") and (p.CanCollide or p.CanQuery) then
							solid += 1
						end
					end
				end
			end
			table.insert(summary, string.format("%s %d flights %d rails %d fences", id, flights, rails, fenceRuns))
			check("K05 " .. id .. ": every Kit5 flight has its ramp, every railing its body-only collider, every fence its modules",
				noRamp == 0 and noColl == 0 and noMods == 0, noRamp .. "/" .. noColl .. "/" .. noMods)
			check("K05 " .. id .. ": no kit mesh collides or takes rays; no Kit5 model is a tidy-pass prop", solid == 0 and props == 0, solid .. "/" .. props)
			if loaded then
				check("K05 " .. id .. ": the kit is in use (flights or railings are Kit5)", flights + rails > 0)
			end
			if fenceLoaded and (id == "border" or id == "meridian") then
				check("K05 " .. id .. ": the fence kit is in use", fenceRuns > 0)
			end
		end
	end

	local out = string.format("%d passed, %d failed%s", passed, failed, skipped > 0 and string.format(", %d skipped (Kit5 not loaded)", skipped) or "")
	if #summary > 0 then
		out ..= " · " .. table.concat(summary, ", ")
	end
	if #notes > 0 then
		out ..= " :: " .. table.concat(notes, "; ")
	end
	return out
end

return T

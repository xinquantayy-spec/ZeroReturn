--!nonstrict
-- Modular kit, pilot (decision art-5b phase 1, docs/look/MODULAR_KIT.md): stair flights and railings are Kit5 meshes with
-- invisible colliders where the ZR_Kit5A / ZR_Kit5B batches are loaded, and today's parts where they are not (Maps/MapKit's
-- k5Flight and k5Rail; every stair and railing builder keeps its parts as the fallback). Run via ZR_Dev "tests".
--   K01 the kit's numbers: every Kit5 variant build_kit5.py makes is in the metadata (KitMeta) and its size is MapKit's
--       (riser, tread, width, module length), or none is (not uploaded yet: the checks that need the batch are skipped)
--   K02 a flight of each style and a railing built here, far off the maps: the mesh takes no collisions, rays or touches;
--       the ramp meets a ray at the middle of every tread within 0.05 of the tread, and starts at the foot; the railing's
--       modules and its collider; a flight or railing no variant fits is left to its builder (nil)
--   K03 ZR_Move: bodies and plain rays meet a railing's collider, bullets (ZR_Shot) and the AI's sight (ZR_Sight) pass it
--   K04 the Smelter rebuilt in a sandbox (never in the world) with the kit and without: every flight and railing call took
--       the kit (when it is loaded) or its parts; without the kit it builds today's 1,109 stair and 837 railing parts, with
--       it at most 200 and 480 (Studio: the 219 rails of the walkability pass take 468) and every other group the same
--   K05 the built maps: every Kit5 flight has its ramp, every Kit5 railing its body-only collider, no kit mesh collides and
--       no Kit5 model is a "Kit" prop (the tidy pass would move it)
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

	-- ── K01 the numbers ───────────────────────────────────────────────────────────────────────────────────────
	local want = names()
	for i = 1, #K5.RAIL_LENGTHS do
		table.insert(want, "K5Rail" .. i)
	end
	local present, missing, bad = 0, {}, {}
	for _, nm in want do
		local p = KitMeta.props[nm]
		if p then
			present += 1
			local st, n = string.match(nm, "^K5Stair(%a)(%d+)$")
			local ri = tonumber(string.match(nm, "^K5Rail(%d+)$"))
			if st then
				n = tonumber(n)
				if math.abs(p.size.X - K5.W0) > 0.02 or math.abs(p.size.Z - n * K5.T0) > 0.06 or #p.pieces ~= 1 then
					table.insert(bad, nm)
				end
			elseif ri then
				if math.abs(p.size.Z - K5.RAIL_LENGTHS[ri]) > 0.03 or p.size.Y < 3.3 or p.size.Y > 3.5 or #p.pieces ~= 1 then
					table.insert(bad, nm)
				end
			elseif p.size.X > 0.35 or #p.pieces ~= 1 then
				table.insert(bad, nm)
			end
		else
			table.insert(missing, nm)
		end
	end
	if present == 0 then
		table.insert(notes, "note: no Kit5 variant in KitMeta yet (upload ZR_Kit5A / ZR_Kit5B, then tools/kit_meta.py): the builders use their parts")
	else
		check("K01 every Kit5 variant build_kit5.py makes is in KitMeta", #missing == 0, #missing .. " missing, first " .. tostring(missing[1]))
		check("K01 every Kit5 variant has MapKit's width, tread and module length, one piece", #bad == 0, table.concat(bad, ","))
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
	scratch:Destroy()
	K5.enabled = true
	check("K02 the scratch builds ran", okK2, errK2)

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

	-- ── K05 the built maps ──────────────────────────────────────────────────────────────────────────────────────
	local summary = {}
	for _, id in { "smelter", "border", "meridian", "quay7" } do
		local mm = W.maps and W.maps[id]
		local model = mm and mm.model
		if model then
			local flights, rails, noRamp, noColl, solid, props = 0, 0, 0, 0, 0, 0
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
					end
					for _, p in d:GetChildren() do
						if p:IsA("MeshPart") and (p.CanCollide or p.CanQuery) then
							solid += 1
						end
					end
				end
			end
			table.insert(summary, string.format("%s %d flights %d rails", id, flights, rails))
			check("K05 " .. id .. ": every Kit5 flight has its ramp and every railing its body-only collider", noRamp == 0 and noColl == 0, noRamp .. "/" .. noColl)
			check("K05 " .. id .. ": no kit mesh collides or takes rays; no Kit5 model is a tidy-pass prop", solid == 0 and props == 0, solid .. "/" .. props)
			if loaded then
				check("K05 " .. id .. ": the kit is in use (flights or railings are Kit5)", flights + rails > 0)
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

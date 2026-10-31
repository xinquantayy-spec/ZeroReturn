--!nonstrict
-- M13 map checks: every registered map is complete and sound (spawns on a floor with head room, exfils over a
-- floor, loot spots on a surface, containers and doors live, keys real), the vote picks the right map, the AI
-- has cover on every map and the detail plan covers every map. Run with ZR_Dev:Invoke("tests").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Maps = require(Shared.Maps)
local Items = require(Shared.Items)
local Wear = require(Shared.Wear)

local T = {}

function T.run(ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond, info)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name .. (info ~= nil and (" [" .. tostring(info) .. "]") or ""))
		end
	end
	local W = ctx.World
	local models = W.mapModels()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	local solid = table.clone(models)
	table.insert(solid, workspace.Terrain) -- terrain maps stand on terrain
	rp.FilterDescendantsInstances = solid
	rp.IgnoreWater = true
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = models
	local function floorBelow(p, maxd)
		local hit = workspace:Raycast(p, Vector3.new(0, -(maxd or 6), 0), rp)
		return hit and hit.Normal.Y > 0.7 and hit or nil
	end

	-- M01 registry: each map in the shared list is built with its tables
	for _, id in Maps.order do
		local m = W.maps[id]
		check("M01 " .. id .. " is built", m ~= nil and m.model ~= nil and m.model.Parent ~= nil)
		if not m then
			continue
		end
		local nSp, nEx = #m.spawns, 0
		for _ in m.extracts do
			nEx += 1
		end
		check("M01 " .. id .. " has spawns and exfils", nSp >= 4 and nEx >= 3, nSp .. " spawns, " .. nEx .. " exfils")
		local sideOk, sideBad = true, nil
		for side, list in m.sideExtracts do
			local open = false
			for _, ex in list do
				local e = m.extracts[ex]
				if not e then
					sideOk, sideBad = false, side .. ":" .. ex
				elseif e.rule.kind == "open" then
					open = true
				end
			end
			if not open then
				sideOk, sideBad = false, side .. " has no open exfil"
			end
		end
		check("M01 " .. id .. " every side has real exfils, one always open", sideOk, sideBad)
		check("M01 " .. id .. " has AI zones and cover bounds", #m.scavZones >= 10 and m.bounds ~= nil and next(m.watchPosts) ~= nil, #m.scavZones)
		local postsOk = next(m.watchPosts) ~= nil
		for _, wp in m.watchPosts do
			postsOk = postsOk and m.patrols[wp.route] ~= nil
		end
		check("M01 " .. id .. " every Watch post has a patrol route (AI.reset needs one)", postsOk)
		check("M01 " .. id .. " raid length set", Maps.defs[id].raidTime >= 600)
	end

	-- M02 spawns stand on a floor with room for a standing body; M03 exfil zones sit over a floor
	local badSpawn, badEx = {}, {}
	for id, m in W.maps do
		for _, s in m.spawns do
			local f = floorBelow(s.cf.Position + Vector3.new(0, 1, 0), 8)
			local clear = f and #workspace:GetPartBoundsInBox(CFrame.new(f.Position + Vector3.new(0, 3.2, 0)), Vector3.new(2.4, 5, 2.4), op) == 0
			if not clear then
				table.insert(badSpawn, id .. ":" .. s.id)
			end
		end
		for ex, e in m.extracts do
			local f = floorBelow(Vector3.new(e.pos.X, e.pos.Y + 2, e.pos.Z), 4)
			if not f then
				table.insert(badEx, id .. ":" .. ex)
			end
		end
	end
	check("M02 every spawn is on a floor with head room", #badSpawn == 0, table.concat(badSpawn, ","))
	check("M03 every exfil zone is over a floor", #badEx == 0, table.concat(badEx, ","))

	-- M04 loose loot spots rest on a surface (within 0.4 studs below)
	local badLoose, nLoose = {}, 0
	for id, m in W.maps do
		for i, sp in m.looseSpots do
			nLoose += 1
			local hit = workspace:Raycast(sp.pos + Vector3.new(0, 0.3, 0), Vector3.new(0, -0.8, 0), rp)
			if not hit then
				table.insert(badLoose, id .. "#" .. i .. string.format("(%.0f,%.1f,%.0f)", sp.pos.X, sp.pos.Y, sp.pos.Z))
			end
		end
	end
	check("M04 every loose loot spot rests on a surface", #badLoose == 0, table.concat(badLoose, ","))

	-- M05 containers and doors are live, tagged with their map; keyed doors need real keys
	local perMap, badC = {}, nil
	for _, c in W.containers do
		perMap[c.map or "?"] = (perMap[c.map or "?"] or 0) + 1
		if not (c.part and c.part.Parent and c.prompt) then
			badC = c.id
		end
	end
	local counts, fewC = {}, false
	for _, id in Maps.order do
		table.insert(counts, id .. "=" .. (perMap[id] or 0))
		fewC = fewC or (perMap[id] or 0) < 10
	end
	check("M05 containers live on every map", badC == nil and not fewC, (badC or "") .. " " .. table.concat(counts, " "))
	local badD = nil
	for id, d in W.doors do
		if not (d.part and d.prompt and d.map) then
			badD = id
		elseif d.key and not (Items.defs[d.key] and Items.defs[d.key].kind == "key") then
			badD = id .. " key"
		end
	end
	check("M05 doors live with a map tag; keys are real items", badD == nil, badD)
	local keyEx = true
	for _, m in W.maps do
		for _, e in m.extracts do
			if e.rule.kind == "key" and not (Items.defs[e.rule.key] and Items.defs[e.rule.key].kind == "key") then
				keyEx = false
			end
		end
	end
	check("M05 key exfils need real keys", keyEx)

	-- M06 the vote: most votes win; a tie or no votes goes to the pick
	check("M06 most votes win", Maps.winner({ quay7 = 2, smelter = 1 }, function()
		return 1
	end) == "quay7" and Maps.winner({ quay7 = 0, smelter = 3 }, function()
		return 1
	end) == "smelter")
	check("M06 a tie is settled by the pick", Maps.winner({ quay7 = 1, smelter = 1 }, function(n)
		return n
	end) == "smelter" and Maps.winner({}, function()
		return 1
	end) == "quay7")
	do
		local fake = { Name = "MT_fake", UserId = -18 }
		ctx.Match.testQueue(fake, "pmc")
		local ok1 = ctx.Match.vote(fake, "smelter")
		local t1 = ctx.Match.tally().smelter or 0
		local ok2, err2 = ctx.Match.vote(fake, "atlantis")
		local ok3 = ctx.Match.vote(fake, nil)
		local t3 = ctx.Match.tally().smelter or 0
		ctx.Match.testQueue(fake, nil)
		local ok4, err4 = ctx.Match.vote(fake, "quay7")
		check("M06 a queued vote counts, can change to any map, an unknown map is refused", ok1 and t1 >= 1 and not ok2 and err2 == "BAD_INPUT" and ok3 and t3 == t1 - 1)
		check("M06 only queued players vote", not ok4 and err4 == "NOT_QUEUED")
	end

	-- M07 activation swaps every per-raid table (only between raids; restored at once)
	if ctx.Match.state ~= "RUNNING" then
		local before = W.activeMap
		local okA = W.activate("smelter")
		local sm = W.maps.smelter
		local swapped = okA and W.spawns == sm.spawns and W.extracts == sm.extracts and W.looseSpots == sm.looseSpots and W.boss == nil
		W.activate(before)
		check("M07 activating a map swaps spawns, exfils, loot spots and the boss", swapped and W.activeMap == before)
		check("M07 an unknown map is not activated", W.activate("atlantis") == false and W.activeMap == before)
	end

	-- M08 the AI has cover points on every map; M09 the detail plan covers every map
	local AI = ctx.AI
	local t0 = os.clock()
	while AI.cover and not AI.cover.ready and os.clock() - t0 < 150 do -- Border Yard is big: sampling takes a while
		task.wait(0.5)
	end
	local found = {}
	for _, list in AI.cover and AI.cover.cells or {} do
		for _, c in list do
			for id, m in W.maps do
				local b = m.bounds
				if b and c.pos.X >= b.x0 and c.pos.X <= b.x1 and c.pos.Z >= b.z0 and c.pos.Z <= b.z1 then
					found[id] = (found[id] or 0) + 1
				end
			end
		end
	end
	local coverInfo, fewCover = {}, false
	for _, id in Maps.order do
		table.insert(coverInfo, id .. "=" .. (found[id] or 0))
		fewCover = fewCover or (found[id] or 0) < ((id == "quay7") and 300 or 150)
	end
	check("M08 AI cover on every map", not fewCover, table.concat(coverInfo, " "))
	local cellsOn = {}
	for key in ctx.DetailPlan.allCells or {} do
		local cx, cz = string.match(key, "^(-?%d+)_(-?%d+)u?$")
		local x, z = (tonumber(cx) + 0.5) * Wear.CELL, (tonumber(cz) + 0.5) * Wear.CELL
		for id, m in W.maps do
			local b = m.bounds
			if b and x >= b.x0 - 64 and x <= b.x1 + 64 and z >= b.z0 - 64 and z <= b.z1 + 64 then
				cellsOn[id] = (cellsOn[id] or 0) + 1
			end
		end
	end
	local cellInfo, fewCells = {}, false
	for _, id in Maps.order do
		table.insert(cellInfo, id .. "=" .. (cellsOn[id] or 0))
		fewCells = fewCells or (cellsOn[id] or 0) < ((id == "quay7") and 20 or 10)
	end
	check("M09 the detail plan covers every map", not fewCells, table.concat(cellInfo, " "))

	-- M10 terrain maps: the ground is terrain under every spawn and exfil, the lake holds water, foliage hides
	local pw = W.maps.pinewatch
	if pw then
		local tp = RaycastParams.new()
		tp.FilterType = Enum.RaycastFilterType.Include
		tp.FilterDescendantsInstances = { workspace.Terrain }
		local onTerrain = 0
		for _, s in pw.spawns do
			local hit = workspace:Raycast(s.cf.Position + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), tp)
			if hit and hit.Normal.Y > 0.75 then
				onTerrain += 1
			end
		end
		check("M10 Pinewatch spawns stand on gentle terrain", onTerrain == #pw.spawns, onTerrain .. "/" .. #pw.spawns)
		local wet = workspace:Raycast(Vector3.new(100, 20, 1960), Vector3.new(0, -40, 0), tp)
		check("M10 the lake holds water", wet ~= nil and wet.Material == Enum.Material.Water and math.abs(wet.Position.Y) < 0.6, wet and (tostring(wet.Material) .. " " .. string.format("%.1f", wet.Position.Y)))
		check("M10 bushes and young pines registered as foliage", W.foliage.n > 150, W.foliage.n)
		-- a sight line through the middle of a registered bush is blocked; the same line lifted above it is not
		local item
		for _, list in W.foliage.cells do
			item = list[1]
			if item then
				break
			end
		end
		if item then
			local y = (item.y0 + item.y1) / 2
			local a, b = Vector3.new(item.x - 30, y, item.z), Vector3.new(item.x + 30, y, item.z)
			local up = item.y1 + 3
			check("M10 foliage blocks AI sight through it, not over it", W.foliageBetween(a, b) and not W.foliageBetween(Vector3.new(a.X, up, a.Z), Vector3.new(b.X, up, b.Z)))
		end
		local trunks, crownsQuiet = 0, true
		for _, d in pw.model:GetDescendants() do
			if d.Name == "Trunk" then
				trunks += 1
			elseif d.Name == "Crown" or d.Name == "Bush" then
				crownsQuiet = crownsQuiet and not d.CanCollide and not d.CanQuery
			end
		end
		check("M10 the forest stands (solid trunks, crowns and bushes pass shots)", trunks > 600 and crownsQuiet, trunks)
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

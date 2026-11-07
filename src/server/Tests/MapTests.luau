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
	-- a lean server (tech-4b) builds only some maps: every per-map check covers the maps this server planned
	local plan = W.planMaps and W.planMaps()
	local order = {}
	for _, id in Maps.order do
		if plan == nil or plan[id] then
			table.insert(order, id)
		end
	end
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
	for _, id in order do
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
	for _, id in order do
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
	local voteMap = order[1]
	check("M01 this server built every map it planned", #order > 0 and (function()
		for _, id in order do
			if not W.maps[id] then
				return false
			end
		end
		return true
	end)(), table.concat(order, ","))
	if voteMap then
		local fake = { Name = "MT_fake", UserId = -18 }
		ctx.Match.testQueue(fake, "pmc")
		local ok1 = ctx.Match.vote(fake, voteMap)
		local t1 = ctx.Match.tally()[voteMap] or 0
		local ok2, err2 = ctx.Match.vote(fake, "atlantis")
		local ok3 = ctx.Match.vote(fake, nil)
		local t3 = ctx.Match.tally()[voteMap] or 0
		ctx.Match.testQueue(fake, nil)
		local ok4, err4 = ctx.Match.vote(fake, voteMap)
		check("M06 a queued vote counts, can change to any map, an unknown map is refused", ok1 and t1 >= 1 and not ok2 and err2 == "BAD_INPUT" and ok3 and t3 == t1 - 1)
		check("M06 only queued players vote", not ok4 and err4 == "NOT_QUEUED")
		-- tech-4b: a map this server did not build cannot be voted for
		local unbuilt = nil
		for _, id in Maps.order do
			if not W.maps[id] then
				unbuilt = id
				break
			end
		end
		if unbuilt then
			ctx.Match.testQueue(fake, "pmc")
			local ok5, err5 = ctx.Match.vote(fake, unbuilt)
			ctx.Match.testQueue(fake, nil)
			check("M06 a map this server did not build is refused", not ok5 and err5 == "NOT_AVAILABLE", unbuilt)
		end
	end

	-- M07 activation swaps every per-raid table (only between raids; restored at once)
	local other = nil
	for _, id in order do
		if id ~= W.activeMap and W.maps[id] then
			other = id
			break
		end
	end
	if ctx.Match.state ~= "RUNNING" and other then
		local before = W.activeMap
		local okA = W.activate(other)
		local sm = W.maps[other]
		local swapped = okA and W.spawns == sm.spawns and W.extracts == sm.extracts and W.looseSpots == sm.looseSpots and W.boss == sm.boss
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
	for _, id in order do
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
	for _, id in order do
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

	-- M11 airdrops: the map in play (Border Yard or Meridian) has open drop points, spread out and clear of its exits
	local W2 = ctx and ctx.World
	local A = ctx and ctx.Airdrop
	if W2 and A and (W2.activeMap == "border" or W2.activeMap == "meridian") then
		local pts = A.findPoints(W2.activeMap)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("ZR_World") }
		local open, spread, clear = true, true, true
		for i, p in pts do
			local h = workspace:Raycast(p + Vector3.new(0, 600, 0), Vector3.new(0, -620, 0), rp)
			if not h or h.Instance ~= workspace.Terrain or (h.Position - p).Magnitude > 1 then
				open = false
			end
			for j = i + 1, #pts do
				if (pts[j] - p).Magnitude < 200 then
					spread = false
				end
			end
			for _, e in W2.extracts or {} do
				local ep = e.pos or (e.cf and e.cf.Position)
				if ep and (Vector3.new(ep.X, 0, ep.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 60 then
					clear = false
				end
			end
		end
		check("M11 airdrop points: at least 6 on " .. W2.activeMap .. ", under open sky, 200+ studs apart, clear of the exits",
			#pts >= 6 and open and spread and clear, #pts)
	end

	-- M12 every container can be searched (audit quick win tech.5 added a line-of-sight check to looting): from at least
	-- one spot within reach where a character fits, the ray from head height meets the container or its own furniture
	if ctx.Guard and ctx.Guard.canSee then
		local excl = {}
		for _, n in { "ZR_AI", "ZR_Loot", "ZR_Loose", "ZR_Corpses", "ZR_Fx", "ZR_Traps", "ZR_GlassHit", "ZR_Traders", "ZR_Airdrops" } do
			local f = workspace:FindFirstChild(n)
			if f then
				table.insert(excl, f)
			end
		end
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.RespectCanCollide = true
		rp.FilterDescendantsInstances = excl
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.RespectCanCollide = true
		op.FilterDescendantsInstances = excl
		local head = Instance.new("Part")
		head.Name, head.Anchored, head.CanCollide, head.CanQuery, head.Size = "Head", true, false, false, Vector3.one
		local probe = Instance.new("Model")
		head.Parent = probe
		local blind, n = {}, 0
		for i, c in W.containers do
			local a = c.part
			if a and a.Parent then
				n += 1
				local stood, seen = false, false
				for k = 0, 7 do
					local ang = k * math.pi / 4
					for _, dist in { 3, 4.5 } do
						local p = a.Position + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
						local down = workspace:Raycast(p + Vector3.new(0, 1.5, 0), Vector3.new(0, -12, 0), rp)
						if down and down.Normal.Y > 0.7 then
							local hp = down.Position + Vector3.new(0, 4.6, 0)
							if #workspace:GetPartBoundsInRadius(hp, 0.6, op) == 0 and #workspace:GetPartBoundsInRadius(down.Position + Vector3.new(0, 2.5, 0), 0.8, op) == 0 then
								stood = true
								head.CFrame = CFrame.new(hp)
								seen = seen or ctx.Guard.canSee(probe, a, 1.2)
							end
						end
					end
				end
				if stood and not seen then
					table.insert(blind, c.id)
				end
			end
			if i % 150 == 0 then
				task.wait()
			end
		end
		check("M12 every container can be searched from a spot within reach (line of sight)", #blind == 0 and n > 0, n .. " checked; blind: " .. table.concat(blind, ","))
		-- M13 every door can be used from at least one side (Doors.use checks line of sight too); a door with a solid wall
		-- right behind it on one side is listed (a door into a wall)
		local walled, shut, nd = {}, {}, 0
		for id, d in W.doors do
			local slab = d.part
			if slab and slab.Parent then
				nd += 1
				local sides = {}
				for _, sgn in { 1, -1 } do
					local stood, seen = 0, false
					for _, dist in { 1.5, 2.5, 4, 5.5 } do
						for _, lat in { -0.75, 0, 0.75 } do
							local p = ((d.cf or slab.CFrame) * CFrame.new(lat, 0, sgn * dist)).Position -- the closed position
							local down = workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -slab.Size.Y - 4, 0), rp)
							if down and down.Normal.Y > 0.7 then
								local hp = down.Position + Vector3.new(0, 4.6, 0)
								if #workspace:GetPartBoundsInRadius(hp, 0.5, op) == 0 then
									stood += 1
									head.CFrame = CFrame.new(hp)
									seen = seen or ctx.Guard.canSee(probe, slab, 1.5)
								end
							end
						end
					end
					sides[sgn] = stood == 0 or seen
				end
				if not sides[1] and not sides[-1] then
					table.insert(shut, id)
				elseif not sides[1] or not sides[-1] then
					table.insert(walled, id)
				end
			end
		end
		probe:Destroy()
		check("M13 every door can be used from at least one side (line of sight)", #shut == 0 and nd > 0,
			nd .. " checked; shut: " .. table.concat(shut, ",") .. "; walled on one side (KNOWN_ISSUES): " .. table.concat(walled, ","))
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

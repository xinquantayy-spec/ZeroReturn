--!nonstrict
-- Border Yard play layer, minimal (foundation, part 1 of 3). The gameplay agent grows this file: AI routes and watch
-- posts (W.patrols, W.watchPosts: still empty, so MapTests' watch-post check fails until they exist), the boss and his
-- crew (W.boss: none yet), visit zones, border snipers (L.snipers, L.hazard), propane, outdoor loot, the flare for
-- NORTH LINE, the K-13 power lever (W.switches.BORDER_STORE4, built in Store 4: until it exists the extract stays
-- closed), the Voron note for SMUGGLERS' HOLE and SMUGGLERS' BOAT.
-- Here: all 26 reference extracts at their positions with the reference rules and our names, W.sideExtracts for the two
-- PMC spawn halves, a few outdoor spawns per half taken from the reference's spawn groups, and the scav spawn zones.
-- Sides follow the reference: "east" spawners start in the east of the map and leave in the west (BUNKER K-11, OLD
-- PUMPS ...), "west" spawners start in the west and leave in the east (CROSSROADS, TRAILER LOT, ARMY ROADBLOCK); the
-- shared exits (L.ext grp "both") serve both. Scavs may use every extract.
return function(B)
	local kit, W, H, L, map = B.kit, B.W, B.H, B.L, B.map
	local V = H.V
	local ground = B.ground
	local inside = B.inside or function()
		return true
	end
	local riverD = B.riverD or function()
		return -999
	end

	-- extracts: the five underground exits stand on their room's floor, the rest on the ground
	local UNDER = { K11 = true, SH = true, OP = true, K13 = true, BC = true }
	local floorOf = {}
	for _, u in L.under do
		floorOf[u[1]] = u[9]
	end
	local ex = kit.model("Extracts", map)
	local sideIds = { east = {}, west = {} }
	for _, e in L.ext do
		local id, name, grp, x, z = e[1], e[2], e[3], e[4], e[5]
		local y, opts = ground(x, z), nil
		if UNDER[id] and floorOf[id] then
			y, opts = floorOf[id] + 0.1, { compact = true }
		end
		kit.extract(ex, id, name, V(x, y, z), Vector3.new(e[6], e[7], e[8]), table.clone(e[9]), opts)
		if grp == "east" or grp == "both" then
			table.insert(sideIds.east, id)
		end
		if grp == "west" or grp == "both" then
			table.insert(sideIds.west, id)
		end
	end
	W.sideExtracts = sideIds

	-- PMC spawns: four outdoor groups per half, as far apart as the reference's groups allow; each takes the reference
	-- spawn point nearest to its group centre
	local function labelNear(x, z)
		local best, bd = "BORDER YARD", math.huge
		for _, lb in L.labels do
			local d = (lb[2] - x) * (lb[2] - x) + (lb[3] - z) * (lb[3] - z)
			if d < bd then
				best, bd = lb[1], d
			end
		end
		return best
	end
	local function spread(list, n, fromMax)
		local outdoor = {}
		for _, c in list do
			if c[6] == false then
				table.insert(outdoor, c)
			end
		end
		table.sort(outdoor, function(a, b)
			if fromMax then
				return a[1] > b[1]
			end
			return a[1] < b[1]
		end)
		local picked = { outdoor[1] }
		while #picked < n and #picked < #outdoor do
			local best, bestD = nil, -1
			for _, c in outdoor do
				local nearest = math.huge
				for _, p in picked do
					nearest = math.min(nearest, (c[1] - p[1]) * (c[1] - p[1]) + (c[2] - p[2]) * (c[2] - p[2]))
				end
				if nearest > bestD then
					best, bestD = c, nearest
				end
			end
			table.insert(picked, best)
		end
		return picked
	end
	local spawns = {}
	for _, side in { "east", "west" } do
		local tag = "W"
		if side == "east" then
			tag = "E"
		end
		for q, c in spread(L.clusters[side], 4, side == "east") do
			local best, bd = nil, math.huge
			for _, p in L.spawns[side] do
				local d = (p[1] - c[1]) * (p[1] - c[1]) + (p[2] - c[2]) * (p[2] - c[2])
				if d < bd then
					best, bd = p, d
				end
			end
			if best then
				table.insert(spawns, {
					id = tag .. q,
					name = labelNear(best[1], best[2]),
					cf = CFrame.new(V(best[1], ground(best[1], best[2]) + 3.4, best[2])) * CFrame.Angles(0, math.rad(best[4]), 0),
					side = side,
				})
			end
		end
	end
	for _, s in spawns do
		s.extracts = W.sideExtracts[s.side]
	end
	W.spawns = spawns

	-- scav spawn zones: the reference's normal scav points, dry land inside the boundary only
	local zones = {}
	for _, z in L.scav do
		local lst = z[7]
		for q = 1, #lst, 4 do
			local x, zz = lst[q], lst[q + 1]
			if inside(x, zz) and riverD(x, zz) < -2 then
				table.insert(zones, V(x, ground(x, zz) + 0.3, zz))
			end
		end
	end
	W.scavZones = zones
	W.patrols = {}
end

--!nonstrict
-- Smelter on EFT Factory (decision art-1a): the rebuilt map is whole and its hooks stand where they should. Run via
-- ZR_Dev "tests". The layout data (SmelterParts/Layout.luau) is checked against the reference's frame; everything
-- else is checked on the built map (raycasts and box queries against the Smelter model only):
--   S01 the frame is Factory's (131.9 x 142.5 m at 3.125 studs a metre) and the map stays clear of every other map
--   S02 exits: inside the bounds, over a floor, out of the walls, named, our names (no EFT name), PMC and scav exits
--       as EFT has them, the key doors and the transit
--   S03 spawns: one per SPT group, inside the bounds, on a floor with head room, out of the walls, every PMC exit each
--   S04 loot: containers and loose spots inside the bounds, on a floor or a surface, out of the walls
--   S05 task places (the ids QuestData uses) and the AI: scav zones, guard routes, THE STOKER's and THE CULT's points
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Maps = require(Shared.Maps)
local Items = require(Shared.Items)
local QD = require(Shared.QuestData)

local T = {}

-- EFT's names for Factory's places and exits: none of them may reach a player (project rule 1)
local EFT_NAMES = {
	"GATE 0", "GATE 2", "GATE 3", "CELLARS", "MED TENT", "COURTYARD", "CAMERA BUNKER", "OFFICE WINDOW", "SMUGGLERS' PASSAGE", "SMUGGLER'S PASSAGE",
	"FACTORY", "TARKOV", "TAGILLA", "PUMPING STATION", "GLASS HALL", "TERRAGROUP",
}

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
	local W = ctx and ctx.World
	local plan = W and W.planMaps and W.planMaps()
	if plan ~= nil and not plan.smelter then
		return "0 passed, 0 failed, skipped (the Smelter is not built on this server)"
	end
	local m = W and W.maps and W.maps.smelter
	check("S00 the Smelter is built", m ~= nil and m.model ~= nil and m.model.Parent ~= nil)
	if not (m and m.model) then
		return string.format("%d passed, %d failed", passed, failed) .. " :: " .. table.concat(notes, "; ")
	end
	local model = m.model
	local b = m.bounds
	local okL, L = pcall(function()
		return require(script.Parent.Parent.Maps.SmelterParts.Layout)
	end)

	-- ── S01 frame and placement ──────────────────────────────────────────────────────────────────────────
	if okL and L then
		local f = L.frame
		check("S01 the frame is Factory's 131.9 x 142.5 m at 3.125 studs a metre", L.S == 3.125 and math.abs((f[3] - f[1]) / L.S - 131.9) < 0.1
			and math.abs((f[4] - f[2]) / L.S - 142.5) < 0.1)
		check("S01 the levels: tunnels below the hall, the office floors and catwalks above", L.LV.basement < L.LV.hall and L.LV.sump < L.LV.basement
			and L.LV.second > L.LV.gallery and L.LV.third > L.LV.second and L.LV.roof > L.LV.third)
		check("S01 the layout lists the reference's exits (9), spawn groups (16) and SPT's bot and boss points (12 + 7)",
			#L.extracts == 9 and #L.spawns == 16 and #L.scav == 12 and #L.boss == 7, #L.extracts .. "/" .. #L.spawns)
	else
		check("S01 the layout module loads", false, L)
	end
	check("S01 bounds set", b ~= nil and b.x1 > b.x0 and b.z1 > b.z0 and b.yMax > b.yMin)
	local clear = b ~= nil
	for id, o in W.maps do
		local ob = o.bounds
		if id ~= "smelter" and ob and b then
			if not (ob.x1 < b.x0 or ob.x0 > b.x1 or ob.z1 < b.z0 or ob.z0 > b.z1) then
				clear = false
				table.insert(notes, "overlaps " .. id)
			end
		end
	end
	check("S01 the Smelter's area overlaps no other map", clear)

	-- queries against this map only
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { model }
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { model }
	op.RespectCanCollide = true
	local walls = model:FindFirstChild("Walls")
	local wp = OverlapParams.new()
	wp.FilterType = Enum.RaycastFilterType.Include
	wp.FilterDescendantsInstances = { walls or model }
	local function inside(p, pad)
		pad = pad or 0
		return b ~= nil and p.X >= b.x0 - pad and p.X <= b.x1 + pad and p.Z >= b.z0 - pad and p.Z <= b.z1 + pad
	end
	local function floorBelow(p, maxd)
		local hit = workspace:Raycast(p, Vector3.new(0, -(maxd or 6), 0), rp)
		return hit and hit.Normal.Y > 0.7 and hit or nil
	end
	-- is a point inside a wall? (a small box at the point meets a part of the Walls model)
	local function inWall(p)
		return walls ~= nil and #workspace:GetPartBoundsInBox(CFrame.new(p), Vector3.new(0.6, 0.6, 0.6), wp) > 0
	end

	-- ── S02 exits ────────────────────────────────────────────────────────────────────────────────────────
	local nEx, badEx, badName, eftName = 0, {}, {}, {}
	local pmc, scav, open = 0, 0, 0
	for id, e in m.extracts do
		nEx += 1
		local p = e.pos
		if not inside(p) or not floorBelow(p + Vector3.new(0, 2, 0), 4) or inWall(p + Vector3.new(0, 2.5, 0)) then
			table.insert(badEx, id)
		end
		if type(e.name) ~= "string" or #e.name < 3 then
			table.insert(badName, id)
		else
			local up = string.upper(e.name)
			for _, n in EFT_NAMES do
				if string.find(up, n, 1, true) then
					table.insert(eftName, id .. "=" .. e.name)
				end
			end
		end
		if e.rule.kind == "scav" then
			scav += 1
		else
			pmc += 1
			if e.rule.kind == "open" then
				open += 1
			end
		end
	end
	check("S02 the exits stand inside the bounds, over a floor, out of the walls", nEx >= 8 and #badEx == 0, table.concat(badEx, ","))
	check("S02 every exit is named, with our names (no EFT name)", #badName == 0 and #eftName == 0, table.concat(badName, ",") .. " " .. table.concat(eftName, ","))
	check("S02 EFT's exits: six for PMCs (one open to all), two for scavs only", pmc >= 6 and scav == 2 and open >= 1, pmc .. "/" .. scav)
	local G3 = m.extracts.G3
	check("S02 ORE GATE (Gate 3) serves PMCs and scavs alike", G3 ~= nil and G3.rule.kind == "open" and G3.rule.who == nil)
	local pmcOnly = true
	for _, id in { "G0", "GM", "CL", "GY", "G2" } do
		local e = m.extracts[id]
		pmcOnly = pmcOnly and e ~= nil and e.rule.who == "pmc"
	end
	check("S02 SLAG GATE, AID POST GATE, CABLE CELLAR, YARD GATE and COKE GATE are for PMCs only", pmcOnly)
	local list = (m.sideExtracts and m.sideExtracts.all) or {}
	check("S02 one entry point: the side 'all' lists every PMC exit", #list == pmc, #list .. "/" .. pmc)
	local keyOk = true
	for _, id in { "SM_GATEDOOR", "SM_CELLAR", "SM_MGR" } do
		local d = W.doors[id]
		keyOk = keyOk and d ~= nil and d.key == "KEY_SMELT_OFFICE" and d.map == "smelter"
	end
	check("S02 the emergency key's three doors (aid post gate passage, cable cellar, manager's office) take KEY_SMELT_OFFICE",
		keyOk and Items.defs.KEY_SMELT_OFFICE ~= nil and Items.defs.KEY_SMELT_OFFICE.kind == "key")
	local tr = m.transits and m.transits[1]
	check("S02 the transit to Border Yard (EFT: Factory to Customs) stands on a floor", tr ~= nil and tr.to == "border" and inside(tr.pos)
		and floorBelow(tr.pos + Vector3.new(0, 2, 0), 4) ~= nil)

	-- ── S03 spawns ───────────────────────────────────────────────────────────────────────────────────────
	local badSp, allEx = {}, true
	for _, s in m.spawns do
		local p = s.cf.Position
		local f = floorBelow(p + Vector3.new(0, 1, 0), 8)
		local roomy = f and #workspace:GetPartBoundsInBox(CFrame.new(f.Position + Vector3.new(0, 3.2, 0)), Vector3.new(2.4, 5, 2.4), op) == 0
		if not inside(p) or not roomy or inWall(p) then
			table.insert(badSp, s.id .. ":" .. tostring(s.name))
		end
		allEx = allEx and s.side == "all" and s.extracts ~= nil and #s.extracts == #list
	end
	check("S03 16 spawns (SPT's groups), each inside the bounds, on a floor with head room, out of the walls", #m.spawns == 16 and #badSp == 0, table.concat(badSp, ","))
	check("S03 every spawn has every PMC exit (EFT: one entry point)", allEx)

	-- ── S04 loot ─────────────────────────────────────────────────────────────────────────────────────────
	local nC, badC = 0, {}
	for _, c in W.containers do
		if c.map == "smelter" and c.part then
			nC += 1
			local p = c.part.Position
			local f = floorBelow(p + Vector3.new(0, 0.5, 0), c.part.Size.Y + 2)
			local box = c.part.Size - Vector3.new(0.8, 0.8, 0.8)
			local inW = walls ~= nil and #workspace:GetPartBoundsInBox(c.part.CFrame, Vector3.new(math.max(0.2, box.X), math.max(0.2, box.Y), math.max(0.2, box.Z)), wp) > 0
			if not inside(p) or not f or inW then
				table.insert(badC, c.id)
			end
		end
	end
	check("S04 at least 80 containers (SPT: about 93 a raid), inside the bounds, on a floor, out of the walls", nC >= 80 and #badC == 0, nC .. " " .. table.concat(badC, ","))
	local badL = {}
	for i, sp in m.looseSpots do
		if not inside(sp.pos) or not workspace:Raycast(sp.pos + Vector3.new(0, 0.3, 0), Vector3.new(0, -0.8, 0), rp) or inWall(sp.pos + Vector3.new(0, 0.4, 0)) then
			table.insert(badL, i)
		end
	end
	check("S04 loose spots inside the bounds, resting on a surface, out of the walls", #m.looseSpots >= 30 and #badL == 0, #m.looseSpots .. " " .. table.concat(badL, ","))

	-- ── S05 task places and AI ───────────────────────────────────────────────────────────────────────────
	local badZ = {}
	for _, id in { "STACK", "SM_CATWALK", "SM_MANAGER", "SM_CASTING", "SM_PUMPHOUSE", "SM_SIDING" } do
		local z = m.visitZones[id]
		local where = QD.NEW_ZONES and QD.NEW_ZONES[id]
		if not z or not inside(z.pos) or not floorBelow(z.pos + Vector3.new(0, 0.5, 0), 4) or inWall(z.pos + Vector3.new(0, 0.5, 0)) then
			table.insert(badZ, id)
		elseif where ~= nil and where.map ~= nil and where.map ~= "smelter" and id ~= "STACK" then
			table.insert(badZ, id .. " map")
		end
	end
	check("S05 the task places stand inside the bounds, over a floor, out of the walls", #badZ == 0, table.concat(badZ, ","))
	local badA = {}
	local function onFloor(tag, p)
		if not inside(p) or not floorBelow(p + Vector3.new(0, 1.5, 0), 4) or inWall(p + Vector3.new(0, 1.5, 0)) then
			table.insert(badA, tag)
		end
	end
	for i, p in m.scavZones do
		onFloor("scav" .. i, p)
	end
	for id, r in m.patrols do
		for i, p in r do
			onFloor(id .. i, p)
		end
	end
	local stoker, cult = nil, nil
	for _, bo in m.bosses or {} do
		if bo.label == "Stoker" then
			stoker = bo
		elseif bo.label == "Priest" then
			cult = bo
		end
		for _, z in bo.zones or {} do
			onFloor(bo.label .. ":" .. z.name, z.home)
			for k, c in z.crew or {} do
				if typeof(c) == "table" and c.pos then
					onFloor(bo.label .. ":" .. z.name .. ":" .. k, c.pos)
				end
			end
		end
	end
	check("S05 scav zones (at least 10), guard routes and boss points stand on floors inside the bounds", #m.scavZones >= 10 and #badA == 0, table.concat(badA, ","))
	check("S05 THE STOKER at EFT's Tagilla 30 % from SPT's seven boss points; THE CULT at night, three zones", stoker ~= nil and stoker.chance == 0.3
		and #stoker.zones == 7 and cult ~= nil and cult.night == true and #cult.zones == 3)
	check("S05 EFT's Factory has scavs only: every post is a scav post", (function()
		for _, wpost in m.watchPosts do
			if wpost.kind ~= "scav" then
				return false
			end
		end
		return #m.watchPosts > 0
	end)())
	check("S05 Factory's raid: 20 minutes (EFT's day raid)", Maps.defs.smelter.raidTime == 1200)

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

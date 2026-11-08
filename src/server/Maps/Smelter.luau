--!nonstrict
-- M13 map: SMELTER, rebuilt on Escape from Tarkov's Factory at real scale (owner's decision art-1a, 2026-11-08;
-- docs/maps/SMELTER_FACTORY_BUILD.md, docs/maps/reference/FACTORY_REFERENCE.md). The layout is Factory's (the
-- reference's floors, walls, stairs, catwalks and tunnels; generated into SmelterParts/Layout.luau by
-- tools/factory_layout.py); the buildings, the dressing and the names are ours (a smelting works: furnaces, crucibles,
-- slag). The parts live in the sibling folder SmelterParts (this file stays the module World requires, so the laptop's
-- copy of it keeps its name); each part is `return function(B)` and runs in this order, under pcall:
--   Shell  floors, walls, roofs, stairs, landings, railings, the crucibles and vessels, the outside ground
--   Play   extracts, the transit, spawns, AI posts and routes, scav zones, THE STOKER and THE CULT, task places, doors,
--          loot containers and loose loot
--   Dress  the machines, vehicles and furniture (Blender kit props) and the lights
-- Local coordinates: studs, x east, z south (north = -z), S = 3.125 studs per metre, y 0 = the main hall floor
-- (game y 0.1). H.V(x, y, z) adds the map origin O. The context B every part gets: kit, W, map, H (MapKit), Kit (the
-- prop kit), L (Layout), O, S, rng, count (part counters), points (named spots Play publishes for Dress).
local ORIGIN = Vector3.new(1600, 0, 0) -- clear of Quay 7 (0), Meridian (z 9000), Border (z -5200), the tutorial (-2400), the bunker (z 4000)
local S = 3.125

return function(kit, root)
	local W = kit.World
	local t0 = os.clock()
	local map = kit.model("Smelter", root)
	local folder = script.Parent:FindFirstChild("SmelterParts")
	assert(folder, "SmelterParts folder missing")
	local L = require(folder:WaitForChild("Layout"))
	local H = require(script.Parent.MapKit)(kit, ORIGIN)
	local Kit = require(script.Parent.Kit)
	local B = {
		kit = kit, W = W, map = map, H = H, Kit = Kit, L = L, O = ORIGIN, S = S, rng = Random.new(1313), count = {}, points = {},
	}
	for _, name in { "Shell", "Play", "Dress" } do
		local mod = folder:FindFirstChild(name)
		local ok, err = pcall(function()
			require(mod)(B)
		end)
		if not ok then
			warn("[ZR] Smelter: " .. name .. " failed: " .. tostring(err))
		end
	end
	-- the area the AI samples for cover points (world coordinates) and the floor heights it keeps: the sump under the
	-- tunnels to the catwalks and the office's third floor
	local f = L.frame
	W.bounds = { x0 = ORIGIN.X + f[1], x1 = ORIGIN.X + f[3], z0 = ORIGIN.Z + f[2], z1 = ORIGIN.Z + f[4], yMin = L.LV.sump - 2, yMax = L.LV.third + 8, step = 4 }
	local c = B.count
	print(string.format(
		"[ZR] Smelter: %d slabs, %d walls, %d stair steps, %d railing parts, %d kit props, %d containers, %d loose spots, %d parts in all, %.2fs",
		c.slab or 0, c.wall or 0, c.step or 0, c.rail or 0, c.props or 0, c.containers or 0, c.loose or 0, #map:GetDescendants(), os.clock() - t0
	))
	return map
end

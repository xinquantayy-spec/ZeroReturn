--!nonstrict
-- Border Yard (Customs layout) buildings: two modules build them, each on the footprints in Layout.luau
-- (docs/maps/BORDER_CUSTOMS_BUILD.md). Living.luau: the dorm blocks, fuel stop and old pumps, the squat, the
-- watchhouse, houses, the trailer lot, cabins, kiosks and garages. Works.luau: the stores and Red Stores, the
-- Bastion, the Derrick, the Frame, the motor shop and boiler house, tanks, platforms and the bunkers underground.
-- Both fill B.points (named world positions the gameplay part uses) and register their doors, containers and loot.
-- A part that fails is logged and the rest of the map still builds.
return function(B)
	B.points = B.points or {}
	for _, name in { "Living", "Works" } do
		local mod = script:FindFirstChild(name) or script.Parent:FindFirstChild(name)
		if mod then
			local ok, err = pcall(function()
				require(mod)(B)
			end)
			if not ok then
				warn("[ZR] Border buildings: " .. name .. " failed: " .. tostring(err))
			end
		end
	end
end

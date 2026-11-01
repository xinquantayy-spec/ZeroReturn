--!nonstrict
-- Meridian Mall stores: one module per floor fills the empty units the shell made (B.units): StoresL1 (the main floor: the three
-- anchors, IRONSIGHT, RESCUE POINT and every other unit) and StoresL2 (the upper floor). They register their doors, containers
-- and loose loot with the world and put their lamps on B.powerHooks. A module that fails is logged and the other still builds.
return function(B)
	B.points = B.points or {}
	B.powerHooks = B.powerHooks or {}
	for _, name in { "StoresL1", "StoresL2" } do
		local mod = script:FindFirstChild(name) or script.Parent:FindFirstChild(name)
		if mod then
			local ok, err = pcall(function()
				require(mod)(B)
			end)
			if not ok then
				warn("[ZR] Meridian stores: " .. name .. " failed: " .. tostring(err))
			end
		end
	end
end

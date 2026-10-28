--!strict
-- Original UI/post textures (assets/textures/gen_textures.py), uploaded as decals; these are the image IDs.
local T = {
	GRAIN = "rbxassetid://111813157927046", -- 256px film grain tile
	LENS = "rbxassetid://109016583283959", -- 16:9 vignette + edge fringe + dust
	ICONS = "rbxassetid://105791720290643", -- 512x128 atlas, 64px cells
	GLOW = "rbxassetid://132675918858502", -- soft radial glow
	SCOPE = "rbxassetid://82967411651545", -- scope eyepiece overlay (transparent round view, reticle)
	RAIN = "rbxassetid://128103121198950", -- one thin rain streak (particles, VelocityParallel)
	SPLASH = "rbxassetid://103059249710804", -- small splash crown (rain on the ground)
	DROPS = "rbxassetid://85371233706654", -- water droplets on the bodycam lens
	-- bodycam lens v2 (Post): light feathered vignette, soft edge haze (tinted at runtime)
	VIGNETTE = "rbxassetid://128387779983708", -- feathered dark rim (no colour)
	EDGE_HAZE = "rbxassetid://117276628141722", -- soft white ring, tinted to the scene at runtime
}

-- icon atlas cells (row-major, 8 per row)
T.ICON = {
	PLUS = 0, BOLT = 1, BLEED = 2, FRACTURE = 3, PAIN = 4, ENERGY = 5, WATER = 6, WEIGHT = 7,
	DOT = 8, RING = 9, SKULL = 10, PERSON = 11, EXIT = 12, ARMOR = 13, HELMET = 14, MAG = 15,
}

function T.rect(index: number): (Vector2, Vector2)
	return Vector2.new((index % 8) * 64, math.floor(index / 8) * 64), Vector2.new(64, 64)
end

return T

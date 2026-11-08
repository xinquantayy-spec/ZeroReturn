--!strict
-- Zero Return's own hazy skies (audit art.2): clear, overcast and night, drawn by assets/textures/gen_sky.py. The sky
-- depends only on the height above the horizon, so a set is three images (side, up, down); Roblox's Clouds, sun, moon
-- and stars stay on top. Image ids resolved in Studio from the uploaded decals (upload_manifest.json, 2026-11-08):
-- InsertService:LoadAsset(decal).Decal.Texture.
local Sky = {}

Sky.SETS = {
	clear = { side = "rbxassetid://74201166450978", up = "rbxassetid://83771921683968", down = "rbxassetid://136454960582358" },
	overcast = { side = "rbxassetid://120761422302978", up = "rbxassetid://131340961089318", down = "rbxassetid://117767047052457" },
	night = { side = "rbxassetid://128505645103502", up = "rbxassetid://111685599202804", down = "rbxassetid://106157855361340" },
}

-- which set a raid wants: night from dusk to dawn (the sun under the horizon), overcast under any weather but clear
function Sky.pick(weather: string?, hour: number): string
	if hour < 5.25 or hour > 20.75 then
		return "night"
	end
	return (weather == nil or weather == "clear") and "clear" or "overcast"
end

-- point a Sky instance at a set (the four sides share one image)
function Sky.apply(sky: any, name: string)
	local set = Sky.SETS[name] or Sky.SETS.clear
	sky.SkyboxBk, sky.SkyboxFt, sky.SkyboxLf, sky.SkyboxRt = set.side, set.side, set.side, set.side
	sky.SkyboxUp, sky.SkyboxDn = set.up, set.down
end

return Sky

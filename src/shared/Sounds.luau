--!strict
-- Sound asset IDs. ZR_SFX_* are original procedural sounds (assets/audio/synth_sfx.py) uploaded to the
-- developer account (ATLAS = many short effects in one asset, see synth_atlas.py); AMBIENCE is a Roblox-licensed
-- ProSoundEffects library sound. Empty = silent fallback.
return {
	R17_FIRE = "rbxassetid://125276898958159",
	R17_FIRE_FAR = "rbxassetid://72578681964971",
	DRY_FIRE = "rbxassetid://119000594646513",
	RELOAD = "rbxassetid://102400197652572",
	HIT = "rbxassetid://126592306693188",
	IMPACT = "",
	EXTRACT_BEEP = "rbxassetid://120970680447327",
	AMBIENCE = "rbxassetid://9112829678", -- "Marina Ambience 5 (SFX)", ProSoundEffects (Roblox licensed library)
	UI_CLICK = "rbxassetid://126592306693188", -- hit tick, pitched up at playback
	ATLAS = "rbxassetid://117513374968391", -- ZR_SFX_Atlas: 52 short effects played by region (SoundAtlas.luau)
	ENV_ATLAS = "rbxassetid://111806710801040", -- ZR_SFX_Env: rain/wind/insect loops + world and UI one-shots (EnvAtlas.luau)
	COMBAT_ATLAS = "rbxassetid://129340593261177", -- ZR_SFX_Combat (M11): grenades, explosions, tinnitus, malfunctions (CombatAtlas.luau)
	-- ZR_SFX_Amb (atmosphere pass): mall room tone, mains hum, car park tone, drips, distant gunfire, the IRONSIGHT siren, the
	-- generator (AmbAtlas.luau). Uploaded 2026-11-01 through the Blender pipeline (zr_upload, Audio). Empty = every ambience
	-- layer, the siren and the generator stay silent (nothing is created, nothing errors).
	AMB_ATLAS = "rbxassetid://136853086315408",
}

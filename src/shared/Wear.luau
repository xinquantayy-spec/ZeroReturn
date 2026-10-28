--!strict
-- M12 wear decals (assets/textures/gen_wear.py, uploaded as decals; these are the image IDs) and the wear-kit
-- mesh defaults (assets/blender_scripts/build_wear_kit.py -> ZR_WearKit model, loaded into ZR_Assets).
local W = {}

W.DEC = {
	Streaks = "rbxassetid://133179203819922", -- water/dirt runs from a top edge (tiles in U, one tile tall)
	BaseGrime = "rbxassetid://111806551019810", -- dirt and splash rising from the ground (tiles in U)
	BaseDamp = "rbxassetid://125226675738370", -- the same with green damp at the foot
	RustRun = "rbxassetid://76717502113236",
	Crack = "rbxassetid://128523385262525",
	CornerCrack = "rbxassetid://103284426139821", -- starts at the bottom-left corner, runs up and right
	Spall = "rbxassetid://110617881598842", -- chipped concrete with exposed rebar
	Peel = "rbxassetid://95488057120453", -- peeling paint flakes (tiles both ways)
	Soot = "rbxassetid://123574871841027",
	Oil = "rbxassetid://101707154349186",
	GroundCrack = "rbxassetid://123136463938424", -- crack network with weeds (tiles both ways)
	Wet = "rbxassetid://88531136630219",
	Tag1 = "rbxassetid://124258360715409", -- "Q7" throw-up
	Tag2 = "rbxassetid://120756147684045", -- "NO WAY OUT"
	Tag3 = "rbxassetid://80943841818289", -- tally marks and an arrow
	Stencil = "rbxassetid://113127173456151", -- faded "NO ENTRY"
	Papers = "rbxassetid://101863828096874",
	Debris = "rbxassetid://136085582779859", -- gravel, chips and butts (tiles both ways)
	Leaves = "rbxassetid://134875962237378", -- dry leaves (tiles both ways)
	Skid = "rbxassetid://75599738965989",
	Manhole = "rbxassetid://129416724945696",
	ChainLink = "rbxassetid://123658820138971", -- fence mesh (tiles both ways, transparent holes)
	Leak = "rbxassetid://73709199683862",
	FloorDust = "rbxassetid://83877822622339", -- dust and boot prints (tiles both ways)
	Grime = "rbxassetid://72609378829916", -- dirty glass film (tiles both ways)
	Holes = "rbxassetid://85278127380449", -- old bullet holes
}

-- per-mesh client defaults: tint (multiplies the baked vertex colour), material, transparency, shadow
local G = Color3.fromRGB
W.MESH = {
	ZR_WK_Rubble = { color = G(150, 150, 144) },
	ZR_WK_RubbleLarge = { color = G(150, 150, 144), shadow = true },
	ZR_WK_Chips = { color = G(150, 150, 144) },
	ZR_WK_Litter = {},
	ZR_WK_Cardboard = {},
	ZR_WK_TrashBag = { shadow = true },
	ZR_WK_Tyre = {},
	ZR_WK_Planks = {},
	ZR_WK_Bricks = {},
	ZR_WK_Weeds = {},
	ZR_WK_Puddle = { material = Enum.Material.Glass, transparency = 0.3, color = G(70, 78, 80) },
	ZR_WK_Conduit = { color = G(140, 142, 136), shadow = true },
	ZR_WK_CableSag = { shadow = true },
	ZR_WK_Downpipe = { color = G(120, 122, 116), shadow = true },
	ZR_WK_PipeRun = { color = G(110, 104, 92), shadow = true },
	ZR_WK_AC = { shadow = true },
	ZR_WK_ElecBox = { color = G(118, 128, 116), shadow = true },
	ZR_WK_WallLamp = {},
	ZR_WK_Vent = {},
	ZR_WK_Shards = { material = Enum.Material.Glass, transparency = 0.45 },
	ZR_WK_WindowFrame = {},
	ZR_WK_WiresHang = {},
	ZR_WK_CeilingTile = {},
	ZR_WK_ChairTipped = {},
	ZR_WK_BinTipped = { color = G(96, 104, 98) },
	ZR_WK_Radiator = {},
	ZR_WK_Mattress = {},
	ZR_WK_Barbed = { color = G(150, 150, 146) },
	ZR_WK_Rebar = {},
}

-- graphics presets (Settings.quality): 0 POTATO, 1 LOW, 2 MEDIUM, 3 HIGH
W.LEVEL_NAMES = { [0] = "POTATO", [1] = "LOW", [2] = "MEDIUM", [3] = "HIGH" }
W.DETAIL_RADIUS = { [1] = 110, [2] = 170, [3] = 250 } -- studs around the camera with detail built
W.CELL = 64

return W

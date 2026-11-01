--!strict
-- Hideout customisation (Tarkov 0.16: "You can customize the Hideout's floor, walls, ceiling"; styles unlock with
-- character level, tasks and achievements; docs/design/HIDEOUT_STYLE.md). Relay 7 is a bunker everyone shares, so a
-- style is what you see: each player's client paints the shell with that player's choice (the walls' olive band and
-- upper paint, the floor slab, the ceilings). The server keeps the choice in the profile and checks the unlock.
-- A finish: { mat = Enum.Material name, var = MaterialVariant name or "", color = hex }; nil keeps the shell's own.
-- band / line / upper are the wall's three cuts (Relay7.luau: WallPaint, WallLine, Wall).

export type Finish = { mat: string, var: string, color: string }
export type Option = { id: string, name: string, level: number, band: Finish?, line: Finish?, upper: Finish?, surface: Finish? }

local S = {}

local function f(mat: string, var: string, color: string): Finish
	return { mat = mat, var = var, color = color }
end

S.CATS = { "walls", "floor", "ceiling" }
S.NAMES = { walls = "WALLS", floor = "FLOOR", ceiling = "CEILING" }

S.walls = {
	{ id = "olive", name = "Issue olive band", level = 1 },
	{ id = "whitewash", name = "Whitewash", level = 5, band = f("Plaster", "ZR_Whitewash", "C9C6BA"), line = f("SmoothPlastic", "", "6E6C66"), upper = f("Plaster", "ZR_Whitewash", "E2DFD4") },
	{ id = "blue", name = "Blue paint", level = 10, band = f("Plaster", "ZR_PaintGloss", "3E5668"), line = f("SmoothPlastic", "", "232C33"), upper = f("Plaster", "", "A7B4BA") },
	{ id = "wallpaper", name = "Modest wallpaper", level = 15, upper = f("Plaster", "ZR_WallpaperA", "E4DCC8") },
	{ id = "tiles", name = "Tiled wainscot", level = 20, band = f("CeramicTiles", "ZR_WallTiles", "D6D5CC"), line = f("SmoothPlastic", "", "3A3C3A"), upper = f("Plaster", "ZR_Whitewash", "DDD9CC") },
	{ id = "panel", name = "Wood panelling", level = 25, band = f("WoodPlanks", "ZR_WoodPanel", "8E6A47"), line = f("SmoothPlastic", "", "4A3A28"), upper = f("Plaster", "ZR_Whitewash", "D8D2C2") },
	{ id = "brick", name = "Bare brick", level = 30, band = f("Brick", "ZR_BrickWall", "A8735A"), line = f("SmoothPlastic", "", "5A3E30"), upper = f("Brick", "ZR_BrickWall", "A8735A") },
} :: { Option }

S.floor = {
	{ id = "concrete", name = "Bare concrete", level = 1 },
	{ id = "smalltiles", name = "Small tiles", level = 8, surface = f("CeramicTiles", "ZR_FloorTiles", "B4B2AA") },
	{ id = "vinyl", name = "Vinyl sheet", level = 12, surface = f("Plastic", "ZR_VinylFloor", "7F8C7C") },
	{ id = "terrazzo", name = "Terrazzo", level = 18, surface = f("Marble", "ZR_Terrazzo", "ADA799") },
	{ id = "planks", name = "Old planks", level = 24, surface = f("WoodPlanks", "ZR_WoodWeathered", "86684A") },
} :: { Option }

S.ceiling = {
	{ id = "concrete", name = "Bare concrete", level = 1 },
	{ id = "tiles", name = "Ceiling tiles", level = 6, surface = f("Plaster", "ZR_CeilingTiles", "E2E0D8") },
	{ id = "whitewash", name = "Whitewash", level = 14, surface = f("Plaster", "ZR_Whitewash", "E8E6DE") },
	{ id = "wood", name = "Wood boards", level = 22, surface = f("WoodPlanks", "ZR_WoodPanel", "93714D") },
} :: { Option }

-- the option of category cat with id, or nil
function S.option(cat: string, id: string?): Option?
	local list = (S :: any)[cat]
	if type(list) ~= "table" or type(id) ~= "string" then
		return nil
	end
	for _, o in list do
		if o.id == id then
			return o
		end
	end
	return nil
end

-- the first option (the shell as built) is everyone's from the start
function S.default(cat: string): string
	return ((S :: any)[cat] :: { Option })[1].id
end

function S.unlocked(o: Option, level: number): boolean
	return level >= o.level
end

return S

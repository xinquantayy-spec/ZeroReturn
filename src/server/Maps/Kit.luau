--!nonstrict
-- M13 Blender kit props (ZR_MK_<Prop>__<material> pieces from the ZR_MallKit* and ZR_BunkerKit* batches, see
-- KitMeta.luau).
-- Kit.place(parent, name, cf, opts) puts a prop's pieces at cf (origin bottom-centre, front along cf.LookVector):
--   * each piece gets its Roblox material and, where one fits, a MaterialVariant; colour comes from the baked
--     vertex colours (the MeshPart colour is white or a tint that multiplies them);
--   * the pieces are cosmetic (no collision, no queries, no touch); the prop gets a few invisible box colliders
--     instead (its bounding box, or the shapes in COLL), so physics, bullets, the AI and pathfinding deal with
--     boxes, not the triangles;
--   * without the kit (batch not loaded yet) a prop is a plain box of its size, so the map plays the same;
--   * merged pieces (art-5b phase 2, docs/look/MODULAR_KIT.md): where Kit.MERGE is on for its batch, a prop's opaque
--     pieces are the one mesh its merged export joined (KitMeta `merged`), so the look changes and play does not.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local KitMeta = require(Shared:WaitForChild("KitMeta"))

local M = Enum.Material
local V = Vector3.new
local Kit = {}
Kit.GROUND = { Chair = true, JerryCans = true }

-- material key -> { material, variant, transparency, reflectance, castShadow }
Kit.MATS = {
	metal = { M.Metal },
	paint = { M.Metal, "ZR_MetalPaint" },
	chrome = { M.Metal, nil, 0, 0.12 },
	plastic = { M.SmoothPlastic },
	glass = { M.Glass, nil, 0.62, 0.05, false },
	fabric = { M.Fabric },
	wood = { M.Wood },
	rubber = { M.Rubber },
	concrete = { M.Concrete, "ZR_ConcreteWorn" },
	stone = { M.Marble },
	tile = { M.CeramicTiles },
	cardboard = { M.Cardboard },
	leather = { M.Leather },
	neon = { M.SmoothPlastic },
	glow = { M.Neon, nil, 0, 0, false },
	plaster = { M.Plaster, "ZR_PlasterPeel" },
	soil = { M.Ground },
	plant = { M.Fabric },
	carpet = { M.Carpet },
}

-- colliders in prop space (x right, y up, z toward the back; the front faces -z): { size, centre }
local function bx(sx, sy, sz, x, y, z)
	return { V(sx, sy, sz), V(x, y, z) }
end
local NONE = {}
Kit.COLL = {
	StoreFront = { bx(6, 12, 0.5, -5, 6, 0), bx(6, 12, 0.5, 5, 6, 0), bx(4, 4, 0.5, 0, 10, 0) },
	-- broken panes (x 2.3..4.85 and -7.7..-5.15 seen from the front... mirrored: see build_mall_kit_a) keep the
	-- kick plate (step over it) and the transom
	StoreFrontBroken = {
		bx(3, 12, 0.5, -6.5, 6, 0), bx(2.85, 1.1, 0.5, -3.58, 0.55, 0), bx(2.85, 4, 0.5, -3.58, 10, 0), bx(4.3, 4, 0.5, 0, 10, 0),
		bx(2.85, 12, 0.5, 3.58, 6, 0), bx(3, 1.1, 0.5, 6.5, 0.55, 0), bx(3, 4, 0.5, 6.5, 10, 0),
	},
	Shutter = { bx(16.4, 12.1, 0.6, 0, 6.05, 0) },
	-- bunk beds: the lower bed, the upper bed and the four posts, so things can lie on the lower mattress
	BunkBed = { bx(6.9, 1.6, 2.9, 0, 0.8, 0), bx(6.9, 0.5, 2.9, 0, 4.35, 0), bx(0.2, 6, 0.2, -3.35, 3, -1.35), bx(0.2, 6, 0.2, 3.35, 3, -1.35), bx(0.2, 6, 0.2, -3.35, 3, 1.35), bx(0.2, 6, 0.2, 3.35, 3, 1.35) },
	BunkBedMessy = { bx(6.9, 1.6, 3, 0, 0.8, -0.41), bx(6.9, 0.5, 3, 0, 4.35, -0.41), bx(0.2, 6, 0.2, -3.35, 3, -1.8), bx(0.2, 6, 0.2, 3.35, 3, -1.8), bx(0.2, 6, 0.2, -3.35, 3, 0.95), bx(0.2, 6, 0.2, 3.35, 3, 0.95) },
	ShutterHalf = { bx(16.4, 8.8, 0.6, 0, 7.7, 0) }, -- a 3.3 gap at the floor: prone to crawl under
	ShutterBent = { bx(11.4, 12.1, 0.6, -2.5, 6.05, 0), bx(5, 5.5, 0.6, 5.7, 9.35, 0) }, -- 4.4 x 6.6 gap at x 3.2..7.6
	CeilingHole = NONE, CeilingCollapse = NONE, CeilingDebris = NONE, BrokenEdge = NONE, GlassShards = NONE, RubbleA = NONE,
	Escalator = NONE, SlabCollapse = NONE, -- walkable shapes come from the map
	RubbleB = { bx(6.4, 1.4, 5, 0, 0.7, 0) },
	Balustrade = { bx(8, 3.8, 0.5, 0, 1.9, 0) },
	BalustradeBroken = { bx(8, 3.8, 0.5, 0, 1.9, 0) },
	WallBreach = { bx(1.7, 9, 0.8, -3.15, 4.5, 0), bx(1.7, 9, 0.8, 3.15, 4.5, 0), bx(4.6, 2.3, 0.8, 0, 7.85, 0) },
	Checkout = { bx(8, 3.2, 2.4, 0, 1.6, 0) },
	Kiosk = { bx(10.2, 3.3, 1.4, 0, 1.65, -2.4), bx(1.4, 3.3, 3.6, -4.4, 1.65, 0.3), bx(1.4, 3.3, 3.6, 4.4, 1.65, 0.3), bx(6.2, 3.3, 1.4, 2, 1.65, 2.4) },
	FoodTable = { bx(3, 2.6, 3, 0, 1.3, 0) },
	FoodTableMess = { bx(3, 2.6, 3, 0, 1.3, 0) },
	OfficeDesk = { bx(6, 2.7, 3, 0, 1.35, 0) },
	BallPit = { bx(12, 2.9, 0.8, 0, 1.45, -5.6), bx(12, 2.9, 0.8, 0, 1.45, 5.6), bx(0.8, 2.9, 10.4, -5.6, 1.45, 0), bx(0.8, 2.9, 10.4, 5.6, 1.45, 0), bx(10.4, 1.5, 10.4, 0, 0.75, 0) },
	DockDoorOpen = NONE,
	CargoLift = { bx(0.2, 10, 6, -3.9, 5, 0), bx(0.2, 10, 6, 3.9, 5, 0), bx(8, 10, 0.2, 0, 5, 2.9), bx(8, 0.3, 6, 0, 0.15, 0) },
	ParkingBarrier = { bx(1.6, 4.2, 1.6, 0, 2.1, 0), bx(1.2, 4.8, 1, -4, 2.4, 1) },
	BusShelter = { bx(10, 8, 0.2, 0, 4, 1.9), bx(0.2, 8, 3.3, 5, 4, 0.25) },
	TrolleyBay = NONE, CardboardPile = NONE,
	Hoarding = { bx(4, 8, 0.4, -4, 4, 0), bx(4, 8, 0.4, 4, 4, 0), bx(4, 4, 0.4, 0, 6, 0) },
	MannequinFallen = NONE, ClothesRackFallen = NONE, TrolleyTipped = { bx(3.6, 2, 3.4, 0, 1, 0) },
	-- Relay 7 bunker kit (ZR_BunkerKitA/B/C): wall and ceiling fittings take no collider (the wall or ceiling behind
	-- them does the job), furniture keeps its working height, the van is a hollow box you can climb into
	BlastDoor = { bx(0.6, 8.6, 8.2, -4.41, 4.3, -5.41) }, -- the open leaf (the frame wraps the wall's own ends)
	DoorFrame = NONE, Beam = NONE, CableTray = NONE, Duct = NONE, Fluoro = NONE, FluoroDead = NONE, CageLamp = NONE,
	CageLampRed = NONE, Vent = NONE, JunctionBox = NONE, Extinguisher = NONE, FirstAid = NONE, WallPhone = NONE,
	Speaker = NONE, WallClock = NONE, PipeRun = NONE, PipeRunRust = NONE, PipeValve = NONE, Rubble = NONE,
	DepartureBoard = NONE, Whiteboard = NONE, CorkBoard = NONE, GunRack = NONE, Pegboard = NONE, RangeDisplay = NONE,
	Pigeonholes = NONE, HoseReel = NONE, OilStain = NONE, Ramp = NONE, -- the ramp's slope is a WedgePart (Relay7)
	MapTable = { bx(24, 3.4, 10.1, 0, 1.7, 0.05) },
	Counter = { bx(12, 3.6, 3, 0, 1.8, 0) },
	GunBench = { bx(14, 3.3, 3, 0, 1.65, 0) },
	CraftBench = { bx(8, 3.3, 3.45, 0, 1.65, -0.22) },
	InsuranceWindow = { bx(10.6, 0.4, 1.6, 0, 2.95, -0.5) }, -- the counter shelf
	RangeBooth = { bx(10, 7, 0.3, 0, 3.5, 0), bx(1.5, 3.4, 5.2, 4.25, 1.7, -2.6) }, -- divider, shelf at the firing line
	WorkLight = { bx(1.8, 5.5, 1.8, 0, 2.75, 0) },
	Manhole = { bx(3.6, 3.6, 0.5, 0, 1.95, 2.6) }, -- the open lid (the shaft is painted on solid floor)
	Van = {
		bx(6.8, 7.0, 7.65, 0, 3.5, -6.5), -- bonnet and cab
		bx(6.6, 1.7, 12.5, 0, 0.85, 3.25), -- chassis and cargo floor
		bx(0.4, 6.1, 12.5, -3.1, 4.75, 3.25), bx(0.4, 6.1, 12.5, 3.1, 4.75, 3.25), -- cargo sides
		bx(6.6, 0.4, 12.5, 0, 7.6, 3.25), -- roof
		bx(1.3, 1.5, 9.5, -2.3, 2.45, 4.25), bx(1.3, 1.5, 9.5, 2.3, 2.45, 4.25), -- bench seats
	},
}
-- the fountain: its ring wall as eight boxes and the plinth (the basin is walkable, shots pass the sculpture)
do
	local f = { bx(5, 3.6, 5, 0, 1.8, 0) }
	for k = 0, 7 do
		local a = k * math.pi / 4
		local r = 8.55
		table.insert(f, { V(7.4, 1.9, 1.0), CFrame.new(math.cos(a) * r, 0.95, math.sin(a) * r) * CFrame.Angles(0, -a - math.pi / 2, 0) })
	end
	Kit.COLL.Fountain = f
end
-- art-5b phase 2, merged pieces: a batch switched on here places each prop's opaque pieces as the one mesh its <batch>M
-- export joined (KitMeta `merged`: ZR_MK_<name>__<mat>_M under one material, by the rule in zr_kit.py's merge_plan),
-- where that mesh is loaded; the prop's other pieces (glass, glow) stay as they are. A placement that tints,
-- re-materials or re-variants a joined piece keeps its pieces, since the joined mesh has one look. Play does not change:
-- the pieces are cosmetic either way, and the colliders keep the material of the prop's first piece, which bullets and
-- footsteps read (KitTests K06). All off: switch a batch on for an A/B look in Studio.
Kit.MERGE = {
	ZR_MallKitA = false,
	ZR_MallKitB = false,
	ZR_MallKitC = false,
	ZR_BunkerKitA = false,
	ZR_BunkerKitB = false,
	ZR_BunkerKitC = false,
}
-- props whose pieces the game uses one by one keep them: a shot steel plate falls by its "paint" piece (Lobby.luau); a
-- first aid box, which has no collider, is a loot container through its biggest piece (Border/Works.luau's cont). Keep
-- in step with zr_kit.py's MERGE_SKIP.
Kit.NOMERGE = { SteelPlate = true, FirstAid = true }

-- the collider's surface material for impacts and footsteps
local COLL_MAT = {
	metal = M.Metal, paint = M.Metal, chrome = M.Metal, plastic = M.Plastic, glass = M.Glass, fabric = M.Fabric, wood = M.Wood,
	rubber = M.Rubber, concrete = M.Concrete, stone = M.Marble, tile = M.CeramicTiles, cardboard = M.Cardboard,
	leather = M.Leather, plaster = M.Plaster, carpet = M.Carpet,
}

local function lib()
	return game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
end

function Kit.has(name)
	local p = KitMeta.props[name]
	local l = lib()
	return p ~= nil and l ~= nil and l:FindFirstChild("ZR_MK_" .. name .. "__" .. p.pieces[1].mat) ~= nil
end

function Kit.size(name)
	local p = KitMeta.props[name]
	return p and p.size, p and p.center
end

-- the pieces a placement takes: the merged mesh and the pieces it does not join, or nil for the prop's own pieces
local function mergedPieces(name, p, opts, l)
	local mg = p.merged
	if not (mg and l and Kit.MERGE[p.batch] and not Kit.NOMERGE[name]) then
		return nil
	end
	local custom = {}
	if typeof(opts.tint) == "Color3" then
		custom.paint = true
	elseif type(opts.tint) == "table" then
		for k in opts.tint do
			custom[k] = true
		end
	end
	for k in opts.mats or {} do
		custom[k] = true
	end
	for k in opts.variants or {} do
		custom[k] = true
	end
	local joined = {}
	for _, m in mg.of do
		if custom[m] then
			return nil
		end
		joined[m] = true
	end
	if not l:FindFirstChild("ZR_MK_" .. name .. "__" .. mg.mat .. "_M") then
		return nil
	end
	local list = { { mat = mg.mat, center = mg.center, merged = true, joins = #mg.of } }
	for _, pc in p.pieces do
		if not joined[pc.mat] then
			table.insert(list, pc)
		end
	end
	return list
end

-- opts: tint (Color3 for "paint", or { [mat] = Color3 }), variants ({ [mat] = name | false }), collide (false or a
-- list of { size, centre }), shadows (false: no piece casts a shadow), name, attrs ({ [k] = v } on the model),
-- scale (Vector3 in prop space: stretches the pieces, their offsets and the colliders, e.g. a beam to a span),
-- mats ({ [mat] = a Kit.MATS-style entry } for this prop only, e.g. a mirror's glass made opaque and shiny)
function Kit.place(parent, name, cf, opts)
	opts = opts or {}
	local p = KitMeta.props[name]
	if not p then
		warn("[ZR] Kit: no prop " .. tostring(name))
		return nil
	end
	-- floor-standing props whose meshes were exported off the origin stand on the floor (the chair's legs ended
	-- 0.41 above it, the jerry cans sank 0.4 into it); found by the 2026-11-01 overlap and footing check
	if Kit.GROUND[name] and not opts.scale then
		cf *= CFrame.new(0, p.size.Y / 2 - p.center.Y, 0)
	end
	local m = Instance.new("Model")
	m.Name = opts.name or ("Kit_" .. name)
	m:SetAttribute("Kit", name)
	m:SetAttribute("NoDetail", true)
	for k, v in opts.attrs or {} do
		m:SetAttribute(k, v)
	end
	local l = lib()
	local placed = 0
	local sc = opts.scale
	for _, pc in mergedPieces(name, p, opts, l) or p.pieces do
		local src = l and l:FindFirstChild("ZR_MK_" .. name .. "__" .. pc.mat .. (pc.merged and "_M" or ""))
		if src then
			local part = src:Clone()
			local mm = (opts.mats and opts.mats[pc.mat]) or Kit.MATS[pc.mat] or Kit.MATS.plastic
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = mm[1]
			local variant = mm[2]
			if opts.variants and opts.variants[pc.mat] ~= nil then
				variant = opts.variants[pc.mat] or nil
			end
			part.MaterialVariant = variant or ""
			part.Transparency = mm[3] or 0
			part.Reflectance = mm[4] or 0
			part.CastShadow = mm[5] ~= false and opts.shadows ~= false
			local tint = opts.tint
			if typeof(tint) == "Color3" then
				part.Color = (pc.mat == "paint") and tint or Color3.new(1, 1, 1)
			elseif type(tint) == "table" and tint[pc.mat] then
				part.Color = tint[pc.mat]
			else
				part.Color = Color3.new(1, 1, 1)
			end
			if sc then
				part.Size = part.Size * sc
				part.CFrame = cf * CFrame.new(pc.center * sc)
			else
				part.CFrame = cf * CFrame.new(pc.center)
			end
			part:SetAttribute("NoDetail", true)
			part:SetAttribute("KitMat", pc.mat)
			if pc.merged then
				-- how many pieces it stands for: a builder that counts a prop's pieces against a part budget counts these, so
				-- the merge never changes what gets placed (Meridian/StoresFill.luau's placeKit)
				part:SetAttribute("KitMerged", true)
				part:SetAttribute("KitJoins", pc.joins)
			end
			part.Parent = m
			placed += 1
		end
	end
	local coll = opts.collide
	if coll == nil then
		coll = Kit.COLL[name] or { { p.size, p.center } }
	end
	local mat0 = COLL_MAT[p.pieces[1].mat] or M.Concrete
	if placed == 0 then
		-- no kit: a plain stand-in of the prop's size (visible), same collision as with the kit
		local box = Instance.new("Part")
		box.Name = "KitFallback"
		box.Anchored = true
		box.Size = sc and p.size * sc or p.size
		box.CFrame = cf * CFrame.new(sc and p.center * sc or p.center)
		box.Color = Color3.fromRGB(110, 112, 108)
		box.Material = mat0
		box.CanCollide = false
		box.CanQuery = false
		box.TopSurface = Enum.SurfaceType.Smooth
		box.BottomSurface = Enum.SurfaceType.Smooth
		box:SetAttribute("NoDetail", true)
		box.Parent = m
	end
	if coll then
		for i, c in coll do
			local b = Instance.new("Part")
			b.Name = "KitCollider"
			b.Anchored = true
			local off = (typeof(c[2]) == "CFrame") and c[2] or CFrame.new(c[2])
			if sc then
				b.Size = c[1] * sc
				off = off - off.Position + off.Position * sc
			else
				b.Size = c[1]
			end
			b.CFrame = cf * off
			b.Transparency = 1
			b.CastShadow = false
			b.Material = mat0
			b.CanCollide = true
			b.CanQuery = true
			b.CanTouch = false
			b:SetAttribute("NoDetail", true)
			b.Parent = m
		end
	end
	m.Parent = parent
	return m
end

return Kit

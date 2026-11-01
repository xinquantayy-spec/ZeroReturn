--!strict
-- Equipment visuals (M16, body ZR_BLOCK_R15_V1): the one shared table that turns authoritative equipment (item
-- instances in a holder's slots) plus a look (outfit) into worn Blender meshes. The server's Appearance service
-- builds and diffs characters from Equipment.resolve(); clients read looks for first-person sleeves and gloves.
--   * Gameplay protection and storage stay in Items: nothing here grants armour, hit regions or space, and a
--     missing mesh never changes protection.
--   * Meshes come from the ZR_CharGear / ZR_CharBase batches, authored in their host part's space (AssetMeta gives
--     each mesh's centre offset), so a piece goes at host.CFrame * CFrame.new(centre * scale + shift).
--   * Torso layers (outfit overlay -> armour -> chest rig) are scaled about the torso centre by the shells of the
--     layers worn under them, so they never cut into each other; backpacks move back, the body camera forward.
--   * Compatibility: an item can block another slot (a full-cut helmet leaves no room for a headset, a gas mask leaves no
--     room for glasses: Tarkov's "blocks headset / eyewear / face cover"); a worn item can cover a region and hide
--     pieces (a backpack covers the chest rig's back harness and a hood worn down).
--   * Eyewear and goggles: the "eyes" slot draws glasses; night-vision goggles are not a slot but the device on the
--     head item's mount, drawn by the "nvg" group flipped up (default) or down over the eyes (state.nvg.down).
--   * Item instances may carry a cosmetic `tint` variant set by the server (faction kit); clients never choose it.
local AssetMeta = require(script.Parent.AssetMeta)
local Items = require(script.Parent.Items)
local RigSpec = require(script.Parent.RigSpec)

local Equipment = {}
Equipment.BODY_VERSION = "ZR_BLOCK_R15_V1"
Equipment.VISUAL_SLOTS = { "head", "ears", "face", "eyes", "armor", "rig", "back", "holster" }
assert(RigSpec.bodyVersion == Equipment.BODY_VERSION, "equipment authored for " .. Equipment.BODY_VERSION)

local TORSO = RigSpec.parts.UpperTorso.size

-- shell a worn torso layer adds for the layers above it: front, back, top (shoulder straps), side (studs)
Equipment.SHELLS = {
	jacket = { 0.07, 0.07, 0, 0.07 },
	vest = { 0.1, 0.1, 0.07, 0.08 },
	carrier = { 0.17, 0.17, 0.08, 0.07 },
	rig = { 0.05, 0.05, 0, 0 },
}

-- cosmetic colour variants an item instance can carry (it.tint), e.g. faction kit
Equipment.TINTS = {
	black = "343A3E", olive = "5F5E46", tan = "8A7A5A", ranger = "4E5442", grey = "55585A", navy = "2E3540", charcoal = "3B3A33",
}

-- mesh bounding-box sizes (assets/exports/ZR_CharGear.meta.json, ZR_CharBase.meta.json; the ZR_EyeGear rows are the boxes
-- assets/blender_scripts/build_eyewear.py forces): neutral fallback boxes
Equipment.SIZE = {
	ZR_EQ_HelmetA = Vector3.new(1.65, 1.366, 1.65),
	ZR_EQ_ArmGuard = Vector3.new(1.18, 0.72, 1.18),
	ZR_EQ_ArmorCollar = Vector3.new(1.74, 0.175, 1.64),
	ZR_EQ_Beanie = Vector3.new(1.35, 0.46, 1.27),
	ZR_EQ_BeltRig = Vector3.new(2.24, 0.39, 1.4),
	ZR_EQ_BodyCam = Vector3.new(0.3, 0.4, 0.22),
	ZR_EQ_BoomMic = Vector3.new(0.5711, 0.2868, 0.5963),
	ZR_EQ_Cap = Vector3.new(1.3, 0.3783, 1.7525),
	ZR_EQ_CarrierA = Vector3.new(2.33, 1.563, 1.512),
	ZR_EQ_CarrierPouches = Vector3.new(1.85, 0.95, 0.922),
	ZR_EQ_ChestRig = Vector3.new(2.25, 1.518, 1.475),
	ZR_EQ_ChestRigBack = Vector3.new(1.5919, 1.0311, 0.08),
	ZR_EQ_FacePlate = Vector3.new(1.68, 0.74, 0.58),
	ZR_EQ_GasMask = Vector3.new(1.37, 0.83, 1.686),
	ZR_EQ_GlassBallistic = Vector3.new(1.39, 0.325, 0.703),
	ZR_EQ_GlassFrag = Vector3.new(1.415, 0.373, 1.309),
	ZR_EQ_GlassRange = Vector3.new(1.39, 0.325, 0.711),
	ZR_EQ_GlassSun = Vector3.new(1.38, 0.3, 0.707),
	ZR_EQ_HardHat = Vector3.new(1.96, 0.695, 2.12),
	ZR_EQ_Headset = Vector3.new(1.74, 1.01, 0.58),
	ZR_EQ_HeadsetNeck = Vector3.new(1.74, 0.59, 0.945),
	ZR_EQ_HelmetB = Vector3.new(1.68, 1.4173, 1.66),
	ZR_EQ_Holster = Vector3.new(1.3, 0.8, 1.12),
	ZR_EQ_Mask = Vector3.new(1.32, 0.53, 1.243),
	ZR_EQ_NvBinoDown = Vector3.new(0.78, 0.655, 0.64),
	ZR_EQ_NvBinoUp = Vector3.new(0.78, 0.765, 0.4),
	ZR_EQ_NvGreenDown = Vector3.new(0.82, 0.675, 0.64),
	ZR_EQ_NvGreenUp = Vector3.new(0.82, 0.765, 0.42),
	ZR_EQ_NvMonoDown = Vector3.new(0.49, 0.675, 0.7),
	ZR_EQ_NvMonoUp = Vector3.new(0.49, 0.825, 0.45),
	ZR_EQ_NvQuadDown = Vector3.new(1.432, 0.625, 0.66),
	ZR_EQ_NvQuadUp = Vector3.new(1.432, 0.785, 0.37),
	ZR_EQ_NvStrap = Vector3.new(1.375, 0.311, 1.485),
	ZR_EQ_NvThermalDown = Vector3.new(0.74, 0.695, 0.74),
	ZR_EQ_NvThermalUp = Vector3.new(0.74, 0.865, 0.47),
	ZR_EQ_PackA = Vector3.new(1.72, 1.6774, 0.942),
	ZR_EQ_PackCanvas = Vector3.new(1.32, 1.3434, 0.72),
	ZR_EQ_PackRaid = Vector3.new(2.0412, 2.4424, 1.1004),
	ZR_EQ_PackSmall = Vector3.new(1.1, 1.09, 0.636),
	ZR_EQ_PackStraps = Vector3.new(1.98, 0.748, 1.5653),
	ZR_EQ_SoftVest = Vector3.new(2.36, 1.618, 1.305),
	ZR_OV_Armband = Vector3.new(1.09, 0.22, 1.09),
	ZR_OV_BootCuffs = Vector3.new(1.14, 0.33, 1.145),
	ZR_OV_FleeceCollar = Vector3.new(1.52, 0.31, 1.2),
	ZR_OV_Hood = Vector3.new(1.24, 0.6406, 1.4971),
	ZR_OV_KneePads = Vector3.new(1.1, 0.4, 1.232),
	ZR_OV_PaddedJacket = Vector3.new(2.3, 1.66, 1.265),
	ZR_OV_ShoulderMarker = Vector3.new(1.09, 0.43, 1.09),
}

-- meshes not uploaded to the asset library yet: the game shows neutral boxes of Equipment.SIZE in their `fb` colour for
-- them (CharTests lists these as pending, and fails if a key stays here after its mesh is in the library). Empty: the
-- eyewear batch ZR_EyeGear (build_eyewear.py) was uploaded 2026-11-01.
local pending: { [string]: boolean } = {}
Equipment.PENDING = pending

-- fb: colour of the neutral box shown while the mesh is missing (meshes that carry their own colours are placed with a white tint)
type Piece = { key: string, host: string, tint: string?, mat: string?, region: string?, shell: string?, name: string?, fb: string? }

local function P(key: string, host: string, tint: string?, mat: string?, extra: { [string]: any }?): Piece
	local p: any = { key = key, host = host, tint = tint, mat = mat }
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end
local function pair(key: string, part: string, tint: string?, mat: string?): { Piece }
	return { P(key, "Left" .. part, tint, mat), P(key, "Right" .. part, tint, mat) }
end
local function join(...: { Piece }): { Piece }
	local out = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(out, p)
		end
	end
	return out
end

-- ── looks: outfit colours (body segment tints) and look-level clothing / markers (not items) ──────────────────
-- cloth keys per body part (block body meshes carry neutral vertex colours; MeshPart.Color tints the outfit)
Equipment.CLOTH = {
	UpperTorso = "jacket", LeftUpperArm = "jacket", RightUpperArm = "jacket", LeftLowerArm = "jacket", RightLowerArm = "jacket",
	LowerTorso = "pants", LeftUpperLeg = "pants", RightUpperLeg = "pants", LeftLowerLeg = "pants", RightLowerLeg = "pants",
	Head = "skin", LeftHand = "glove", RightHand = "glove", LeftFoot = "boot", RightFoot = "boot",
}

local KNEE = function(tint: string)
	return pair("ZR_OV_KneePads", "LowerLeg", tint, "SmoothPlastic")
end
local LOOKS: { [string]: any } = {
	-- operator: practical field clothing, knee pads, the body camera this game is filmed through
	player = { jacket = "5A6047", pants = "40433A", skin = "C9A58A", glove = "2A2B29", boot = "5A4936", bodycam = true, overlays = KNEE("3A3C35") },
	-- scavengers: worn work clothes in mixed muted colours (a seeded variant per character); some bare-handed
	scav = {
		variants = {
			{ jacket = "5C554A", pants = "3D3B36", skin = "C4A386", glove = "4A4134", boot = "4A3F33", overlays = { P("ZR_OV_Hood", "UpperTorso", "5C554A", "Fabric", { region = "hood" }) } },
			{ jacket = "4B5560", pants = "4A4438", skin = "BF9C80", glove = "BF9C80", boot = "3E352C", overlays = {} },
			{ jacket = "55583F", pants = "45464A", skin = "C9A58A", glove = "3A3631", boot = "4A3F33", overlays = { P("ZR_OV_Hood", "UpperTorso", "6A6650", "Fabric", { region = "hood" }) } },
			{ jacket = "3E3F3C", pants = "4D4234", skin = "B8957A", glove = "2F2D2A", boot = "3A322A", overlays = KNEE("3A3833") },
		},
	},
	-- Harbor Watch guards: coordinated slate uniform, one restrained faction marker (left armband)
	guard = { jacket = "44515E", pants = "343B42", skin = "BF9C80", glove = "1E2022", boot = "2A2826",
		overlays = join({ P("ZR_OV_Armband", "LeftUpperArm", "B59B3A", "Fabric") }, KNEE("26292B")) },
	-- the Foreman's crew (bodyguards): black uniform, white shoulder markers on both arms
	bodyguard = { jacket = "34393D", pants = "2C3033", skin = "C9A58A", glove = "1A1B1C", boot = "222120",
		overlays = join(pair("ZR_OV_ShoulderMarker", "UpperArm", "D8D2C0", "Fabric"), KNEE("202224")) },
	-- the Foreman (boss): padded work jacket over concealed armour, fleece collar, high-vis boot cuffs; his hard
	-- hat is an item (the signature accessory) so it can be looted
	foreman = { jacket = "7E5F36", pants = "3B3A35", skin = "B8957A", glove = "3A2F25", boot = "4A3A2A",
		overlays = join({ P("ZR_OV_PaddedJacket", "UpperTorso", "7E5F36", "Fabric", { shell = "jacket" }), P("ZR_OV_FleeceCollar", "UpperTorso", "CFC6B0", "Fabric") },
			pair("ZR_OV_BootCuffs", "LowerLeg", "8A8478", "Fabric")),
		covers = { armorVisual = true } },
	-- THE STOKER (Meridian's garage boss, our Tagilla): a boiler stoker in navy work clothes and a scorched leather
	-- apron-vest, knee pads; his plate carrier and welding mask are items and stay in view
	stoker = { jacket = "2E3742", pants = "2A2D30", skin = "B8957A", glove = "4A3A2A", boot = "2A2622",
		overlays = join({ P("ZR_OV_PaddedJacket", "UpperTorso", "4A3B2C", "Fabric", { shell = "jacket" }) }, KNEE("2A2622")) },
	-- THE HOUNDS (Border Yard's roaming trio, our Goons; docs/design/BOSS_HOUNDS.md): HALBERD the leader in dark navy
	-- with tan knee pads, MORTAR the grenadier in olive with a black armband, KESTREL the marksman in a mottled
	-- brown-green with a hood; their carriers, helmets and guns are items
	halberd = { jacket = "26303A", pants = "222831", skin = "C9A58A", glove = "1A1B1C", boot = "1E1D1C",
		overlays = join({ P("ZR_OV_Armband", "LeftUpperArm", "B5A27A", "Fabric") }, KNEE("8A7A58")) },
	mortar = { jacket = "4A5236", pants = "3C4230", skin = "B8957A", glove = "2A2B26", boot = "2E2A24",
		overlays = join({ P("ZR_OV_Armband", "LeftUpperArm", "1E1F20", "Fabric") }, KNEE("2E3026")) },
	kestrel = { jacket = "5C5640", pants = "4A4634", skin = "BF9C80", glove = "3A3428", boot = "3A3228",
		overlays = join({ P("ZR_OV_Hood", "UpperTorso", "56523A", "Fabric", { region = "hood" }) }, KNEE("3E3A2C")) },
	-- Relay 7 traders (lobby NPCs), each in their trade's clothes: VOS the quartermaster (olive, red armband), HALE
	-- the field medic (pale coat, blue gloves, red-cross armband), TILDA the outfitter (dark, fleece collar), the Fence
	-- (hooded, shabby)
	vos = { jacket = "4E5338", pants = "393A31", skin = "B8957A", glove = "2A2B26", boot = "3E3528",
		overlays = join({ P("ZR_OV_Armband", "LeftUpperArm", "8A3A2E", "Fabric") }, KNEE("33352E")) },
	hale = { jacket = "C9C4B4", pants = "4A4E52", skin = "C9A58A", glove = "6F94B8", boot = "3A3631",
		overlays = { P("ZR_OV_Armband", "LeftUpperArm", "B03A2E", "Fabric") } },
	tilda = { jacket = "3B3530", pants = "2F3133", skin = "D2B092", glove = "2A2522", boot = "2E2925",
		overlays = { P("ZR_OV_FleeceCollar", "UpperTorso", "9A8F7A", "Fabric") } },
	fence = { jacket = "57503F", pants = "3A372F", skin = "BF9C80", glove = "3E352B", boot = "3A3128",
		overlays = { P("ZR_OV_Hood", "UpperTorso", "4F4838", "Fabric", { region = "hood" }) } },
}
Equipment.LOOKS = LOOKS
Equipment.LOOK_ALIAS = { boss = "foreman", follower = "bodyguard", watch = "guard" }

-- role presets: one rig, one appearance path. A preset is a look plus where its kit comes from: an AI loadout
-- generator (Loot.*Loadout, seeded) or, for the player operator, the inventory (the reference kit below is the
-- showroom / test dummy). AI kinds map to looks through this table.
Equipment.PRESETS = {
	operator = { look = "player", kit = { head = "HELMET_C3", ears = "HEADSET_GS1", rig = "RIG_PLATE", back = "BAG_PATROL", holster = "P9_PISTOL", primary = "R17_RIFLE" } },
	scavenger = { look = "scav", ai = "scav" },
	guard = { look = "guard", ai = "watch" },
	bodyguard = { look = "bodyguard", ai = "follower" },
	foreman = { look = "foreman", ai = "boss" },
	-- backlog (documented, not built yet): marksman / scout (light carrier, compact bag, hood), safehouse worker
	-- (unarmed workwear, apron, utility belt)
}
function Equipment.lookForAi(kind: string): string
	for _, p in Equipment.PRESETS do
		if p.ai == kind then
			return p.look
		end
	end
	return "player"
end

function Equipment.lookKey(name: string?): string
	local k = name and (Equipment.LOOK_ALIAS[name] or name) or "player"
	return LOOKS[k] and k or "player"
end

-- the concrete outfit of a look (scav variants resolved by a stored seed)
function Equipment.lookOf(name: string?, variant: number?): any
	local L = LOOKS[Equipment.lookKey(name)]
	if L.variants then
		local n = #L.variants
		return L.variants[((math.floor(variant or 1) - 1) % n) + 1]
	end
	return L
end

function Equipment.variants(name: string?): number
	local L = LOOKS[Equipment.lookKey(name)]
	return L.variants and #L.variants or 1
end

-- first-person sleeves and gloves follow the same look
function Equipment.fpColors(name: string?, variant: number?): { sleeve: Color3, cuff: Color3, glove: Color3, pad: Color3 }
	local L = Equipment.lookOf(name, variant)
	local sleeve = Color3.fromHex(L.jacket)
	local glove = Color3.fromHex(L.glove)
	return { sleeve = sleeve, cuff = sleeve:Lerp(Color3.new(0, 0, 0), 0.35), glove = glove, pad = glove:Lerp(Color3.new(1, 1, 1), 0.12) }
end

-- ── item visuals ─────────────────────────────────────────────────────────────────────────────────────────────
-- pieces: worn meshes; layer/shell: torso layering; blocks: slot -> refusal code; covers: regions hidden;
-- underHeadwear: pieces used instead when the head slot is occupied (headset band behind the neck)
local VIS: { [string]: any } = {
	HELMET_C2 = { pieces = { P("ZR_EQ_HelmetB", "Head", "55593F") }, blocks = { ears = "HELMET_COVERS_EARS" } },
	HELMET_C3 = { pieces = { P("ZR_EQ_HelmetA", "Head", "4F5340") } },
	HELMET_C4 = { pieces = { P("ZR_EQ_HelmetA", "Head", "3B3F36") } },
	HELMET_C5 = { pieces = { P("ZR_EQ_HelmetB", "Head", "34372F"), P("ZR_EQ_FacePlate", "Head", "4A4D4A", "Metal") }, blocks = { ears = "HELMET_COVERS_EARS" } },
	HARDHAT_FOREMAN = { pieces = { P("ZR_EQ_HardHat", "Head", "D4A93A") }, blocks = { ears = "HARD_HAT_BRIM" } },
	CAP_FIELD = { pieces = { P("ZR_EQ_Cap", "Head", "4A4A3E", "Fabric") } },
	BEANIE = { pieces = { P("ZR_EQ_Beanie", "Head", "3A3833", "Fabric") } },
	NV_STRAP = { pieces = { P("ZR_EQ_NvStrap", "Head", "42443A", "Fabric") } },
	HEADSET_GS1 = { pieces = { P("ZR_EQ_Headset", "Head", "3A3D36") }, underHeadwear = { P("ZR_EQ_HeadsetNeck", "Head", "3A3D36") } },
	HEADSET_COMM = { pieces = { P("ZR_EQ_Headset", "Head", "2A2C2E"), P("ZR_EQ_BoomMic", "Head", "2A2C2E") },
		underHeadwear = { P("ZR_EQ_HeadsetNeck", "Head", "2A2C2E"), P("ZR_EQ_BoomMic", "Head", "2A2C2E") } },
	GAITER = { pieces = { P("ZR_EQ_Mask", "Head", "6B6B5E", "Fabric") } },
	-- full-face gas mask (FACE COVER slot): blocks the eyewear slot, in both orders (Tarkov: an item that blocks a slot refuses
	-- to be worn with an item in it). The mesh carries its own colours, so it goes on with a white tint.
	GAS_MASK = { pieces = { P("ZR_EQ_GasMask", "Head", "FFFFFF", "SmoothPlastic", { fb = "2D342B" }) }, blocks = { eyes = "GAS_MASK_BLOCKS_EYEWEAR" } },
	-- THE STOKER's welding mask (FACE COVER slot): no mesh of its own yet (new meshes are uploaded from the owner's machine),
	-- so it wears the faceplate helmet's plate in blackened steel
	MASK_WELDER = { pieces = { P("ZR_EQ_FacePlate", "Head", "2B2C28", "Metal") } },
	-- eyewear (EYEWEAR slot): lenses keep their own colours (white tint). No helmet or face shield of ours blocks eyewear:
	-- the Tarkov face shields (Altyn, 1SCh, EXFIL) and helmets (Vulkan-5, Kolpak-1S) checked all list "Blocks eyewear: no",
	-- and our faceplate helmet (HELMET_C5) is the same kind of item, so glasses are worn under its plate.
	GLASSES_SUN = { pieces = { P("ZR_EQ_GlassSun", "Head", "FFFFFF", "SmoothPlastic", { fb = "5A3A22" }) } },
	GLASSES_RANGE = { pieces = { P("ZR_EQ_GlassRange", "Head", "FFFFFF", "SmoothPlastic", { fb = "C4A63C" }) } },
	GLASSES_BG1 = { pieces = { P("ZR_EQ_GlassBallistic", "Head", "FFFFFF", "SmoothPlastic", { fb = "2B3033" }) } },
	GLASSES_AF2 = { pieces = { P("ZR_EQ_GlassFrag", "Head", "FFFFFF", "SmoothPlastic", { fb = "2F5C9E" }) } },
	ARMOR_C2 = { layer = "armor", shell = "vest", pieces = { P("ZR_EQ_SoftVest", "UpperTorso", "2E3540", "Fabric") } },
	ARMOR_C3 = { layer = "armor", shell = "vest", pieces = { P("ZR_EQ_SoftVest", "UpperTorso", "4A5242", "Fabric") } },
	ARMOR_C4 = { layer = "armor", shell = "carrier", pieces = { P("ZR_EQ_CarrierA", "UpperTorso", "575A47", "Fabric") } },
	ARMOR_C5 = { layer = "armor", shell = "carrier", pieces = { P("ZR_EQ_CarrierA", "UpperTorso", "4D4F45", "Fabric"), P("ZR_EQ_ArmorCollar", "UpperTorso", "4D4F45", "Fabric") } },
	ARMOR_C6 = { layer = "armor", shell = "carrier", pieces = join({ P("ZR_EQ_CarrierA", "UpperTorso", "3E423D", "Fabric"), P("ZR_EQ_ArmorCollar", "UpperTorso", "3E423D", "Fabric") },
		pair("ZR_EQ_ArmGuard", "UpperArm", "3E423D", "Fabric")) },
	RIG_BELT = { pieces = { P("ZR_EQ_BeltRig", "LowerTorso", "5E5A47", "Fabric") } },
	RIG_CHEST = { layer = "rig", shell = "rig", pieces = { P("ZR_EQ_ChestRig", "UpperTorso", "5A5844", "Fabric"), P("ZR_EQ_ChestRigBack", "UpperTorso", "5A5844", "Fabric", { region = "upperBack" }) } },
	-- armoured rig: one item, armour and pouches together (Items: cannot be worn with body armour)
	RIG_PLATE = { layer = "armor", shell = "carrier", pieces = { P("ZR_EQ_CarrierA", "UpperTorso", "4F513F", "Fabric"), P("ZR_EQ_CarrierPouches", "UpperTorso", "4F513F", "Fabric") }, blocks = { armor = "ARMOR_CONFLICT" } },
	BAG_SLING = { layer = "pack", pieces = { P("ZR_EQ_PackSmall", "UpperTorso", "6B6A4E", "Fabric") }, covers = { upperBack = true, hood = true } },
	CANVAS_BAG = { layer = "pack", pieces = { P("ZR_EQ_PackCanvas", "UpperTorso", "7A7458", "Fabric") }, covers = { upperBack = true, hood = true } },
	-- neckUp: how far the head may tilt back under a tall pack before the waist takes over (radians)
	BAG_PATROL = { layer = "pack", pieces = { P("ZR_EQ_PackA", "UpperTorso", "5C5B44", "Fabric") }, covers = { upperBack = true, hood = true }, neckUp = 0.42 },
	BAG_RAID = { layer = "pack", pieces = { P("ZR_EQ_PackRaid", "UpperTorso", "53523F", "Fabric") }, covers = { upperBack = true, hood = true }, neckUp = 0.2 },
}
Equipment.VIS = VIS

-- night-vision goggles on a head mount (a helmet's NVG mount or the head strap), by device item id: the device is not a slot, it
-- is items[headGuid].mods.mount; the "nvg" group draws it flipped up on the front of the head (default, like Tarkov's N toggle off)
-- or down over the eyes (the character's NvDown attribute, set from the owner's "nvg" act)
local function nvgPair(name: string): { down: Piece, up: Piece }
	return {
		down = P("ZR_EQ_Nv" .. name .. "Down", "Head", "FFFFFF", "SmoothPlastic", { fb = "3B4339" }),
		up = P("ZR_EQ_Nv" .. name .. "Up", "Head", "FFFFFF", "SmoothPlastic", { fb = "3B4339" }),
	}
end
local NVG: { [string]: { down: Piece, up: Piece } } = {
	NV_MONO = nvgPair("Mono"), NV_BINO = nvgPair("Bino"), NV_GREEN = nvgPair("Green"), NV_QUAD = nvgPair("Quad"), TH_T7 = nvgPair("Thermal"),
}
Equipment.NVG = NVG

-- any pistol in the holster slot
local HOLSTER = { pieces = { P("ZR_EQ_Holster", "RightUpperLeg", "2E3134") } }
local BODYCAM = P("ZR_EQ_BodyCam", "UpperTorso", "FFFFFF", "SmoothPlastic")

function Equipment.visualOf(slot: string, id: string?): any
	if not id then
		return nil
	end
	if slot == "holster" then
		return HOLSTER
	end
	return VIS[id]
end

-- every mesh key this module can place (tests: all must exist in AssetMeta)
function Equipment.allKeys(): { string }
	local seen, out = {}, {}
	local function add(p)
		if not seen[p.key] then
			seen[p.key] = true
			table.insert(out, p.key)
		end
	end
	for _, v in VIS do
		for _, p in v.pieces do
			add(p)
		end
		for _, p in v.underHeadwear or {} do
			add(p)
		end
	end
	for _, dev in Equipment.NVG do
		add(dev.down)
		add(dev.up)
	end
	for _, p in HOLSTER.pieces do
		add(p)
	end
	add(BODYCAM)
	add({ key = "ZR_EQ_PackStraps" })
	for _, L in LOOKS do
		for _, v in L.variants or { L } do
			for _, p in v.overlays or {} do
				add(p)
			end
		end
	end
	table.sort(out)
	return out
end

-- ── compatibility ────────────────────────────────────────────────────────────────────────────────────────────
-- slots: { [slot] = itemId } currently worn. Returns a refusal code when `id` cannot go into `slot`.
function Equipment.conflict(slots: { [string]: string }, slot: string, id: string): string?
	local v = VIS[id]
	if v and v.blocks then
		for s, code in v.blocks do
			if s ~= slot and slots[s] then
				return code
			end
		end
	end
	for s, other in slots do
		if s ~= slot then
			local ov = VIS[other]
			if ov and ov.blocks and ov.blocks[slot] then
				return ov.blocks[slot]
			end
		end
	end
	return nil
end

-- ── resolve ──────────────────────────────────────────────────────────────────────────────────────────────────
-- state = { look, variant, items = { [slot] = { id = itemId, tint = variantName? } }, bodycam = bool?,
--           nvg = { id = deviceItemId, down = bool }? (goggles on the head item's mount) }
export type Entry = { group: string, key: string, host: string, offset: Vector3, scale: Vector3?, tint: string, mat: string, name: string, fb: string? }

-- authoritative equipment state of a holder (visual slots, and the goggles on the head item's mount). nvDown: the goggles are
-- pulled down over the eyes (the character's NvDown attribute); otherwise they are flipped up on the front of the head.
function Equipment.stateOf(h: any, look: string?, variant: number?, nvDown: boolean?): any
	local items = {}
	local nvg: any = nil
	if h and h.slots then
		for _, slot in Equipment.VISUAL_SLOTS do
			local g = h.slots[slot]
			local it = g and h.items[g]
			if it and Items.defs[it.id] then
				items[slot] = { id = it.id, tint = it.tint }
			end
		end
		local hg = h.slots.head
		local hit = hg and h.items[hg]
		local mg = hit and hit.mods and hit.mods.mount
		local dev = mg and h.items[mg]
		if dev and Equipment.NVG[dev.id] then
			nvg = { id = dev.id, down = nvDown == true }
		end
	end
	return { look = Equipment.lookKey(look), variant = variant or 1, items = items, nvg = nvg }
end

local function shellSum(list: { string }): (number, number, number, number)
	local f, b, t, s = 0, 0, 0, 0
	for _, name in list do
		local sh = Equipment.SHELLS[name]
		if sh then
			f += sh[1]
			b += sh[2]
			t += sh[3]
			s += sh[4]
		end
	end
	return f, b, t, s
end

-- scale + shift (UpperTorso space) for a layer worn over the shells in `under`
local function inflate(under: { string }): (Vector3?, Vector3)
	if #under == 0 then
		return nil, Vector3.zero
	end
	local f, b, t, s = shellSum(under)
	local sc = Vector3.new((TORSO.X + 2 * s) / TORSO.X, (TORSO.Y + 2 * t) / TORSO.Y, (TORSO.Z + f + b) / TORSO.Z)
	return sc, Vector3.new(0, 0, (b - f) / 2)
end

local function tintOf(p: Piece, inst: any): string
	local t = inst and inst.tint and Equipment.TINTS[inst.tint]
	return t or p.tint or "FFFFFF"
end

function Equipment.resolve(state: any): { Entry }
	local look = Equipment.lookOf(state.look, state.variant)
	local L = LOOKS[Equipment.lookKey(state.look)]
	local items = state.items or {}
	local out: { Entry } = {}
	-- covered regions: from the look (Foreman's jacket conceals armour) and from worn items (a backpack)
	local covered: { [string]: boolean } = {}
	for k, v in (L.covers or {}) do
		covered[k] = v
	end
	for slot, inst in items do
		local v = Equipment.visualOf(slot, inst.id)
		for k, val in (v and v.covers or {}) do
			covered[k] = val
		end
	end
	local function add(group: string, p: Piece, inst: any, scale: Vector3?, shift: Vector3?)
		if p.region and covered[p.region] then
			return
		end
		local c = AssetMeta[p.key] or Vector3.zero
		local off = (scale and c * scale or c) + (shift or Vector3.zero)
		table.insert(out, {
			group = group, key = p.key, host = p.host, offset = off, scale = scale, tint = tintOf(p, inst), mat = p.mat or "SmoothPlastic",
			name = p.name or p.key, fb = p.fb,
		})
	end
	-- torso layer stack: look overlays with a shell, then armour (armour slot, or an armoured rig), then chest rig
	local under: { string } = {}
	local armorInst, armorSlot, rigInst
	for _, slot in { "armor", "rig" } do
		local inst = items[slot]
		local v = inst and Equipment.visualOf(slot, inst.id)
		if v and v.layer == "armor" and not armorInst then
			armorInst, armorSlot = inst, slot
		elseif v and v.layer == "rig" then
			rigInst = inst
		end
	end
	-- outfit (look-level clothing and markers)
	for _, p in look.overlays or {} do
		add("outfit", p, nil)
		if p.shell then
			table.insert(under, p.shell)
		end
	end
	local outfitShells = table.clone(under)
	-- head, ears (band behind the neck under headwear), face
	if items.head then
		local v = Equipment.visualOf("head", items.head.id)
		for _, p in (v and v.pieces or {}) do
			add("head", p, items.head)
		end
	end
	if items.ears then
		local v = Equipment.visualOf("ears", items.ears.id)
		local list = v and ((items.head and v.underHeadwear) or v.pieces) or {}
		for _, p in list do
			add("ears", p, items.ears)
		end
	end
	if items.face then
		local v = Equipment.visualOf("face", items.face.id)
		for _, p in (v and v.pieces or {}) do
			add("face", p, items.face)
		end
	end
	-- eyewear, then the goggles on the head mount (up on the front of the head, or down over the eyes)
	if items.eyes then
		local v = Equipment.visualOf("eyes", items.eyes.id)
		for _, p in (v and v.pieces or {}) do
			add("eyes", p, items.eyes)
		end
	end
	local nvDev = state.nvg and Equipment.NVG[state.nvg.id]
	if nvDev then
		add("nvg", state.nvg.down and nvDev.down or nvDev.up, nil)
	end
	-- armour layer (hidden when the look conceals it: then it adds no shell either)
	if armorInst and not covered.armorVisual then
		local v = Equipment.visualOf(armorSlot :: string, armorInst.id)
		local sc, sh = inflate(under)
		for _, p in v.pieces do
			if p.host == "UpperTorso" then
				add(armorSlot :: string, p, armorInst, sc, sh)
			else
				add(armorSlot :: string, p, armorInst)
			end
		end
		table.insert(under, v.shell)
	end
	-- chest rig over whatever is under it
	if rigInst then
		local v = Equipment.visualOf("rig", rigInst.id)
		local sc, sh = inflate(under)
		for _, p in v.pieces do
			add("rig", p, rigInst, sc, sh)
		end
	end
	-- other rig / armour slot visuals that are not torso layers (utility belt)
	for _, slot in { "armor", "rig" } do
		local inst = items[slot]
		local v = inst and Equipment.visualOf(slot, inst.id)
		if v and not v.layer then
			for _, p in v.pieces do
				add(slot, p, inst)
			end
		end
	end
	-- backpack: moved back by the worn layers (the rig's back harness is covered by the pack); shared straps
	-- follow the outfit shells only (they run outside the armour lanes)
	if items.back then
		local v = Equipment.visualOf("back", items.back.id)
		if v then
			local _, b = shellSum(under)
			for _, p in v.pieces do
				add("back", p, items.back, nil, Vector3.new(0, 0, b))
			end
			local strapTint = tintOf(v.pieces[1], items.back)
			local sc, sh = inflate(outfitShells)
			add("back", { key = "ZR_EQ_PackStraps", host = "UpperTorso", tint = Color3.fromHex(strapTint):Lerp(Color3.new(0, 0, 0), 0.18):ToHex(), mat = "Fabric" }, nil, sc, sh)
		end
	end
	if items.holster then
		for _, p in HOLSTER.pieces do
			add("holster", p, nil)
		end
	end
	-- body camera (operators): on top of every front layer
	if look.bodycam or L.bodycam then
		local layers = table.clone(under)
		if rigInst then
			table.insert(layers, "rig")
		end
		local f = shellSum(layers)
		add("bodycam", BODYCAM, nil, nil, Vector3.new(0, 0, -f))
	end
	return out
end

-- neck limit when looking up (tall backpacks), or nil
function Equipment.neckUpOf(state: any): number?
	local n: number? = nil
	for slot, inst in state.items or {} do
		local v = Equipment.visualOf(slot, inst.id)
		if v and v.neckUp and (n == nil or v.neckUp < (n :: number)) then
			n = v.neckUp
		end
	end
	return n
end

-- how far worn torso gear reaches behind the torso centre (UpperTorso space, studs): slung long guns go over it
function Equipment.backExtent(entries: { Entry }): number
	local z = TORSO.Z / 2
	for _, e in entries do
		if e.host == "UpperTorso" and e.key ~= "ZR_EQ_PackStraps" then
			local size = Equipment.SIZE[e.key]
			if size then
				z = math.max(z, e.offset.Z + size.Z * (e.scale and e.scale.Z or 1) / 2)
			end
		end
	end
	return z
end

-- group signature: what a slot visibly wears (key, placement, scale, colour, material)
function Equipment.signature(entries: { Entry }): { [string]: string }
	local sig: { [string]: { string } } = {}
	for _, e in entries do
		local s = sig[e.group] or {}
		sig[e.group] = s
		local sc = e.scale and string.format("%.3f,%.3f,%.3f", e.scale.X, e.scale.Y, e.scale.Z) or "1"
		table.insert(s, string.format("%s@%s:%.3f,%.3f,%.3f*%s#%s/%s", e.key, e.host, e.offset.X, e.offset.Y, e.offset.Z, sc, e.tint, e.mat))
	end
	local out = {}
	for g, list in sig do
		out[g] = table.concat(list, ";")
	end
	return out
end

return Equipment

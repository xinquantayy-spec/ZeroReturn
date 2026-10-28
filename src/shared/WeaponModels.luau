--!strict
-- Part-built weapon/attachment models (original designs), authored in studs at third-person scale with the
-- pistol grip at the origin, barrel along -Z, top along +Y. Viewmodels scale the same spec down.
-- part = { "b", size, pos, color, rot?(deg), mat? }  box
--        { "c", length, diameter, pos, color, mat? }  cylinder along Z
-- anchors: muzzle, sight (iron sight eye point), rail (optic mount), magwell, grip (right hand),
--          hand (left hand), under (grip mount), side (light mount)
local Shared = script.Parent
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local V = Vector3.new
local C = {
	dark = Color3.fromHex("26292A"), metal = Color3.fromHex("3B403D"), poly = Color3.fromHex("4E5650"),
	wood = Color3.fromHex("6A4A31"), tan = Color3.fromHex("7C6E52"), steel = Color3.fromHex("5D6361"),
	glass = Color3.fromHex("1C2B33"), blade = Color3.fromHex("9EA3A0"),
}
local M = {}
M.C = C

M.weapons = {
	R17 = {
		parts = {
			{ "b", V(0.16, 0.2, 0.9), V(0, 0.06, -0.3), C.dark },
			{ "b", V(0.1, 0.03, 0.78), V(0, 0.18, -0.34), C.metal },
			{ "b", V(0.18, 0.18, 0.62), V(0, 0.04, -1.06), C.poly },
			{ "c", 0.46, 0.05, V(0, 0.05, -1.6), C.metal },
			{ "b", V(0.07, 0.07, 0.12), V(0, 0.05, -1.88), C.dark },
			{ "b", V(0.02, 0.1, 0.02), V(0, 0.18, -1.3), C.dark },
			{ "b", V(0.06, 0.05, 0.05), V(0, 0.215, 0.02), C.dark },
			{ "b", V(0.1, 0.19, 0.55), V(0, -0.02, 0.45), C.poly },
			{ "b", V(0.12, 0.24, 0.04), V(0, -0.03, 0.73), C.dark, nil, Enum.Material.Rubber },
			{ "b", V(0.08, 0.22, 0.1), V(0, -0.13, 0.04), C.poly, V(-15, 0, 0) },
			{ "b", V(0.03, 0.03, 0.17), V(0, -0.07, -0.12), C.dark },
			{ "b", V(0.05, 0.1, 0.05), V(0.1, 0.07, -0.18), C.metal },
		},
		anchors = { muzzle = V(0, 0.05, -1.96), sight = V(0, 0.235, 0.02), rail = V(0, 0.2, -0.32), magwell = V(0, -0.05, -0.38), grip = V(0, -0.12, 0.05), hand = V(0, -0.04, -1.02), under = V(0, -0.06, -1.1), side = V(0.1, 0.04, -1.15) },
		mag = "R17",
	},
	KST = {
		parts = {
			{ "b", V(0.16, 0.2, 0.82), V(0, 0.04, -0.25), C.dark },
			{ "b", V(0.15, 0.06, 0.74), V(0, 0.17, -0.25), C.metal },
			{ "b", V(0.17, 0.17, 0.46), V(0, 0.03, -0.9), C.wood, nil, Enum.Material.Wood },
			{ "b", V(0.07, 0.07, 0.42), V(0, 0.14, -0.95), C.wood, nil, Enum.Material.Wood },
			{ "c", 0.52, 0.055, V(0, 0.04, -1.42), C.metal },
			{ "b", V(0.03, 0.12, 0.03), V(0, 0.12, -1.58), C.dark },
			{ "b", V(0.08, 0.08, 0.1), V(0, 0.04, -1.72), C.dark },
			{ "b", V(0.1, 0.2, 0.62), V(0, -0.07, 0.48), C.wood, V(-6, 0, 0), Enum.Material.Wood },
			{ "b", V(0.08, 0.22, 0.1), V(0, -0.13, 0.04), C.wood, V(-18, 0, 0), Enum.Material.Wood },
			{ "b", V(0.06, 0.04, 0.08), V(0, 0.2, -0.05), C.dark },
		},
		anchors = { muzzle = V(0, 0.04, -1.78), sight = V(0, 0.225, -0.05), rail = V(0, 0.21, -0.25), magwell = V(0, -0.06, -0.38), grip = V(0, -0.12, 0.05), hand = V(0, -0.05, -0.9), under = V(0, -0.06, -0.95), side = V(0.1, 0.03, -0.9) },
		mag = "KST",
	},
	SPARROW = {
		parts = {
			{ "b", V(0.14, 0.2, 0.75), V(0, 0.05, -0.3), C.dark },
			{ "b", V(0.17, 0.18, 0.36), V(0, 0.03, -0.86), C.poly },
			{ "c", 0.2, 0.05, V(0, 0.05, -1.13), C.metal },
			{ "b", V(0.03, 0.09, 0.03), V(0, 0.19, -0.9), C.dark },
			{ "b", V(0.05, 0.06, 0.05), V(0, 0.2, 0.0), C.dark },
			{ "b", V(0.05, 0.05, 0.42), V(0.04, 0.02, 0.3), C.metal },
			{ "b", V(0.05, 0.05, 0.42), V(-0.04, 0.02, 0.3), C.metal },
			{ "b", V(0.11, 0.18, 0.04), V(0, 0.0, 0.52), C.dark, nil, Enum.Material.Rubber },
			{ "b", V(0.08, 0.2, 0.1), V(0, -0.12, 0.03), C.poly, V(-12, 0, 0) },
		},
		anchors = { muzzle = V(0, 0.05, -1.24), sight = V(0, 0.225, 0.0), rail = V(0, 0.2, -0.35), magwell = V(0, -0.05, -0.5), grip = V(0, -0.11, 0.04), hand = V(0, -0.04, -0.86), under = V(0, -0.06, -0.86), side = V(0.09, 0.03, -0.86) },
		mag = "SPARROW",
	},
	HARROW = {
		parts = {
			{ "b", V(0.15, 0.2, 0.55), V(0, 0.05, -0.15), C.dark },
			{ "c", 1.12, 0.075, V(0, 0.09, -0.98), C.metal },
			{ "c", 0.85, 0.065, V(0, -0.01, -0.86), C.metal },
			{ "b", V(0.13, 0.12, 0.36), V(0, -0.01, -0.98), C.wood, nil, Enum.Material.Wood },
			{ "b", V(0.11, 0.2, 0.62), V(0, -0.05, 0.46), C.wood, V(-8, 0, 0), Enum.Material.Wood },
			{ "b", V(0.08, 0.2, 0.1), V(0, -0.12, 0.05), C.wood, V(-20, 0, 0), Enum.Material.Wood },
			{ "b", V(0.02, 0.02, 0.02), V(0, 0.14, -1.5), C.blade },
		},
		anchors = { muzzle = V(0, 0.09, -1.55), sight = V(0, 0.165, 0.0), rail = V(0, 0.16, -0.15), magwell = V(0, -0.02, -0.4), grip = V(0, -0.11, 0.05), hand = V(0, -0.06, -0.98), under = V(0, -0.08, -0.98), side = V(0.08, 0.09, -0.7), pump = V(0, -0.01, -0.98), port = V(0, -0.06, -0.35) },
		moving = { pump = { 4 } },
		internal = true,
	},
	TUNDRA = {
		parts = {
			{ "b", V(0.12, 0.17, 1.95), V(0, -0.03, -0.55), C.wood, nil, Enum.Material.Wood },
			{ "c", 1.25, 0.06, V(0, 0.08, -1.42), C.metal },
			{ "b", V(0.1, 0.12, 0.42), V(0, 0.08, -0.12), C.metal },
			{ "b", V(0.16, 0.035, 0.035), V(0.09, 0.1, 0.06), C.metal },
			{ "b", V(0.03, 0.03, 0.03), V(0.17, 0.08, 0.06), C.metal },
			{ "b", V(0.025, 0.1, 0.025), V(0, 0.15, -1.98), C.dark },
			{ "b", V(0.05, 0.04, 0.06), V(0, 0.15, -0.38), C.dark },
			{ "b", V(0.08, 0.1, 0.26), V(0, -0.11, -0.25), C.metal },
		},
		anchors = { muzzle = V(0, 0.08, -2.05), sight = V(0, 0.18, -0.38), rail = V(0, 0.16, -0.15), magwell = V(0, -0.1, -0.25), grip = V(0, -0.1, 0.1), hand = V(0, -0.05, -0.9), under = V(0, -0.1, -1.0), side = V(0.08, 0.02, -1.0), bolt = V(0.17, 0.08, 0.06), port = V(0.04, 0.1, -0.12) },
		moving = { bolt = { 4, 5 } },
		internal = true,
	},
	P9 = {
		parts = {
			{ "b", V(0.07, 0.11, 0.58), V(0, 0.12, -0.22), C.dark },
			{ "b", V(0.065, 0.07, 0.48), V(0, 0.03, -0.18), C.poly },
			{ "b", V(0.07, 0.26, 0.13), V(0, -0.1, 0.03), C.poly, V(-12, 0, 0) },
			{ "b", V(0.025, 0.03, 0.12), V(0, -0.02, -0.18), C.dark },
			{ "b", V(0.02, 0.04, 0.02), V(0, 0.19, -0.48), C.dark },
			{ "b", V(0.05, 0.04, 0.03), V(0, 0.19, 0.05), C.dark },
		},
		anchors = { muzzle = V(0, 0.12, -0.52), sight = V(0, 0.215, 0.05), rail = V(0, 0.19, -0.2), magwell = V(0, -0.1, 0.03), grip = V(0, -0.08, 0.04), hand = V(-0.03, -0.12, 0.08), under = V(0, -0.02, -0.35), side = V(0, -0.02, -0.38) },
		mag = "P9", pistol = true,
	},
	KNIFE = {
		parts = {
			{ "b", V(0.025, 0.08, 0.42), V(0, 0.01, -0.3), C.blade, nil, Enum.Material.Metal },
			{ "b", V(0.05, 0.07, 0.24), V(0, 0, 0.04), C.dark },
			{ "b", V(0.03, 0.12, 0.03), V(0, 0, -0.09), C.metal },
		},
		anchors = { muzzle = V(0, 0, -0.5), sight = V(0, 0.1, 0), grip = V(0, 0, 0.04), hand = V(0, 0, 0.04) },
		melee = true,
	},
}

-- magazines relative to the weapon magwell anchor
M.mags = {
	R17 = { { "b", V(0.08, 0.36, 0.14), V(0, -0.17, 0), C.dark, V(10, 0, 0) } },
	KST = { { "b", V(0.08, 0.38, 0.15), V(0, -0.17, -0.04), C.dark, V(22, 0, 0) } },
	SPARROW = { { "b", V(0.07, 0.34, 0.1), V(0, -0.16, -0.02), C.dark, V(14, 0, 0) } },
	P9 = { { "b", V(0.055, 0.2, 0.1), V(0, -0.02, 0), C.dark, V(-12, 0, 0) } },
}

-- attachments relative to their mount anchor; eye = sight eye point (optics)
M.mods = {
	RED_DOT = {
		mount = "rail",
		parts = {
			{ "b", V(0.08, 0.025, 0.12), V(0, 0.0125, 0), C.dark }, -- base
			{ "b", V(0.012, 0.075, 0.05), V(-0.034, 0.0625, -0.02), C.dark }, -- hood posts
			{ "b", V(0.012, 0.075, 0.05), V(0.034, 0.0625, -0.02), C.dark },
			{ "b", V(0.08, 0.012, 0.05), V(0, 0.106, -0.02), C.dark }, -- hood top
			{ "b", V(0.056, 0.074, 0.004), V(0, 0.0625, -0.035), C.glass, nil, Enum.Material.Glass }, -- tinted window
			{ "b", V(0.03, 0.02, 0.03), V(0.03, 0.03, 0.03), C.metal }, -- battery cap
		},
		eye = V(0, 0.0625, 0),
	},
	SCOPE_4X = { mount = "rail", parts = { { "b", V(0.08, 0.05, 0.04), V(0, 0.025, -0.12), C.dark }, { "b", V(0.08, 0.05, 0.04), V(0, 0.025, 0.12), C.dark }, { "c", 0.5, 0.085, V(0, 0.1, 0), C.dark }, { "c", 0.12, 0.13, V(0, 0.1, -0.28), C.dark }, { "c", 0.1, 0.11, V(0, 0.1, 0.27), C.dark } }, eye = V(0, 0.1, 0.3), zoom = 4 },
	SUPP_62 = { mount = "muzzle", parts = { { "c", 0.42, 0.09, V(0, 0, -0.2), C.dark } }, len = 0.42 },
	SUPP_9 = { mount = "muzzle", parts = { { "c", 0.4, 0.085, V(0, 0, -0.19), C.dark } }, len = 0.4 },
	BRAKE_76 = { mount = "muzzle", parts = { { "b", V(0.08, 0.08, 0.12), V(0, 0, -0.06), C.dark } }, len = 0.12 },
	GRIP_V = { mount = "under", parts = { { "b", V(0.06, 0.2, 0.07), V(0, -0.1, 0), C.dark } } },
	LIGHT_T = { mount = "side", parts = { { "c", 0.16, 0.06, V(0.03, 0, 0), C.dark } } },
}

local function rot(r)
	if r then
		return CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end
	return CFrame.identity
end

-- one spec part -> Part at origin * offset (not parented)
function M.part(p, origin: CFrame, scale: number): Part
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if p[1] == "b" then
		part.Size = p[2] * scale
		part.CFrame = origin * CFrame.new(p[3] * scale) * rot(p[5])
		part.Color = p[4]
		part.Material = p[6] or Enum.Material.Metal
		if part.Material == Enum.Material.Glass then
			part.Transparency = 0.72 -- optics glass: see-through, lightly tinted
		end
	else
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(p[2], p[3], p[3]) * scale
		part.CFrame = origin * CFrame.new(p[4] * scale) * CFrame.Angles(0, math.rad(90), 0)
		part.Color = p[5]
		part.Material = p[6] or Enum.Material.Metal
	end
	return part
end

-- Build a weapon item (with its magazine and attachments) at `origin` (grip pose). items = holder items table.
-- Returns { parts, mag, moving = { pump?, bolt? }, anchors, spec, eye, zoom, reflex, muzzle, suppressed, lightPart }
-- (anchors in spec units). Parts in `moving` are also in `parts`.
function M.build(items, it, origin: CFrame, scale: number)
	local d = Items.defs[it.id]
	local wdef = d and d.weapon and Weapons[d.weapon]
	local spec = wdef and M.weapons[wdef.viewmodel or d.weapon]
	if not spec then
		return nil
	end
	local out = { parts = {}, mag = {}, moving = {}, anchors = spec.anchors, spec = spec, eye = spec.anchors.sight, muzzle = spec.anchors.muzzle }
	local tagOf = {}
	for name, list in spec.moving or {} do
		out.moving[name] = {}
		for _, i in list do
			tagOf[i] = name
		end
	end
	for i, p in spec.parts do
		local part = M.part(p, origin, scale)
		table.insert(out.parts, part)
		if tagOf[i] then
			table.insert(out.moving[tagOf[i]], part)
		end
	end
	out.pump = out.moving.pump or {}
	if d.family and it.mag and spec.mag and M.mags[spec.mag] and items[it.mag] then
		local mo = origin * CFrame.new(spec.anchors.magwell * scale)
		for _, p in M.mags[spec.mag] do
			table.insert(out.mag, M.part(p, mo, scale))
		end
	end
	for _, mg in it.mods or {} do
		local m = items[mg]
		local mspec = m and M.mods[m.id]
		local anchor = mspec and spec.anchors[mspec.mount]
		if anchor then
			local mo = origin * CFrame.new(anchor * scale)
			for k, p in mspec.parts do
				local part = M.part(p, mo, scale)
				table.insert(out.parts, part)
				if k == 1 and Items.defs[m.id].mod.light then
					out.lightPart = part -- cylinder along Z: its Right face points down the barrel
				end
			end
			if mspec.eye then
				out.eye = anchor + mspec.eye
				out.zoom = mspec.zoom
				out.reflex = Items.defs[m.id].mod.reflex == true
			end
			if mspec.mount == "muzzle" then
				out.muzzle = spec.anchors.muzzle + Vector3.new(0, 0, -(mspec.len or 0))
				out.suppressed = (Items.defs[m.id].mod.loud or 1) < 0.6
			end
		end
	end
	return out
end

-- third-person weapons are built at TP_SCALE so they read at block-body scale (ZR_BLOCK_R15_V1); hand anchors
-- from holdOf are already scaled (third-person studs)
M.TP_SCALE = 1.35
-- third-person hold kind ("long" | "pistol" | "melee") and the hand anchors (third-person studs) for an item id
local holdCache = {}
function M.holdOf(id: string?)
	if not id then
		return nil, nil
	end
	local c = holdCache[id]
	if c == nil then
		local d = Items.defs[id]
		local w = d and d.weapon and Weapons[d.weapon]
		local spec = w and M.weapons[w.viewmodel or d.weapon]
		local k = M.TP_SCALE
		local function sc(v)
			return v and v * k or nil
		end
		c = spec and { kind = spec.melee and "melee" or (spec.pistol and "pistol" or "long"), anchors = { grip = sc(spec.anchors.grip), hand = sc(spec.anchors.hand or spec.anchors.grip), magwell = sc(spec.anchors.magwell), port = sc(spec.anchors.port) } } or false
		holdCache[id] = c
	end
	if not c then
		return nil, nil
	end
	return c.kind, c.anchors
end

-- handling modifiers from attachments (mirror of server Inv.modStats)
function M.modStats(items, it)
	local st = { ergo = 0, recoil = 1, loud = 1, zoom = nil, reflex = false, light = false, suppressed = false }
	for _, mg in (it and it.mods) or {} do
		local m = items[mg]
		local md = m and Items.defs[m.id] and Items.defs[m.id].mod
		if md then
			st.ergo += md.ergo or 0
			st.recoil *= md.recoil or 1
			st.loud *= md.loud or 1
			st.zoom = md.zoom or st.zoom
			st.reflex = st.reflex or md.reflex == true
			st.light = st.light or md.light == true
			st.suppressed = st.suppressed or (md.loud or 1) < 0.6
		end
	end
	return st
end

return M

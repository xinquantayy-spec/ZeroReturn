--!nonstrict
-- M14: guns in 3D from their Blender parts (docs/weapons/WEAPON_MODDING.md). A weapon's build (WeaponParts) is
-- put together from the part meshes in ReplicatedStorage.ZR_Assets at the slots recorded in GunMeta, for the first
-- person viewmodel, the third-person gun in the hands or on the back, and loose loot on the ground.
--
-- build() returns the same shape as the old part-built spec (WeaponModels.build), so the weapon code works with
-- either: { parts, mag, moving = { pump?, bolt? }, anchors, spec, eye, zoom, reflex, muzzle, suppressed,
-- lightPart, meshes = true }. Anchors are in gun units around the gun origin, which is placed so that the firing
-- hand's anchor lands where the old spec had it (the poses tuned for first and third person still fit).
-- Returns nil while a mesh of the build has not loaded; the caller then uses the old spec.
local RS = game:GetService("ReplicatedStorage")
local Shared = script.Parent
local Items = require(Shared.Items)
local WP = require(Shared.WeaponParts)
local GunMeta = require(Shared.GunMeta)

local M = {}

-- material key (Blender) -> Roblox material, reflectance, transparency
local MAT = Enum.Material
M.MAT = {
	gunmetal = { MAT.Metal, 0.02 }, metal = { MAT.Metal, 0.04 }, brass = { MAT.Metal, 0.06 }, copper = { MAT.Metal, 0.05 },
	gold = { MAT.Foil, 0.08 }, chrome = { MAT.Metal, 0.15 }, plastic = { MAT.SmoothPlastic }, polymer = { MAT.Plastic },
	rubber = { MAT.Rubber }, fabric = { MAT.Fabric }, leather = { MAT.Leather }, paper = { MAT.SmoothPlastic },
	cardboard = { MAT.Cardboard }, wood = { MAT.Wood }, ceramic = { MAT.SmoothPlastic, 0.02 }, glass = { MAT.Glass, 0.05, 0.55 },
	emissive = { MAT.Neon }, foil = { MAT.Foil },
}

local function lib()
	return RS:FindFirstChild("ZR_Assets")
end

-- can this item be built from meshes now (a gun or a part with a part record, every mesh of its build loaded)?
local function loaded(items, g): boolean
	local it = items[g]
	if not it or not GunMeta.parts[it.id] then
		return false
	end
	local l = lib()
	if not l then
		return false
	end
	for _, e in WP.layout(items, g) do
		local pm = GunMeta.parts[e.id]
		if pm then
			for _, pc in pm.pieces do
				if not l:FindFirstChild(pc[1]) then
					return false
				end
			end
		end
	end
	return true
end

-- a gun base whose build can be made from meshes now
function M.ready(items, g): boolean
	local it = items[g]
	return it ~= nil and WP.isBase(it.id) and loaded(items, g)
end

-- a part (with the parts on it) made from meshes now
M.loaded = loaded

-- the meshes of item g's build (a gun or a part with its parts) with its origin at `origin`, `scale` studs per
-- stud; no anchors or moving parts (loose loot, pictures). Returns nil while a mesh has not loaded.
function M.pieces(items, g, origin: CFrame, scale: number?): { BasePart }?
	if not loaded(items, g) then
		return nil
	end
	local s = scale or 1
	local l = lib()
	local out = {}
	for _, e in WP.layout(items, g) do
		local pm = GunMeta.parts[e.id]
		if pm then
			for _, pc in pm.pieces do
				local src = l:FindFirstChild(pc[1])
				if src then
					local p = src:Clone()
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Massless = true
					p.Size = src.Size * s
					p.Color = Color3.new(1, 1, 1)
					local mm = M.MAT[pc[2]] or M.MAT.plastic
					p.Material = mm[1]
					p.Reflectance = mm[2] or 0
					p.Transparency = mm[3] or 0
					p.CastShadow = pc[2] ~= "glass"
					local cf = e.cf * CFrame.new(pc[3])
					p.CFrame = origin * CFrame.new(cf.Position * s) * cf.Rotation
					table.insert(out, p)
				end
			end
		end
	end
	return out
end

-- the box around parts in `frame` (default: world axes): lo, hi corners in that frame
function M.bounds(parts: { BasePart }, frame: CFrame?): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local cf, h = frame and frame:ToObjectSpace(p.CFrame) or p.CFrame, p.Size / 2
		local ex = Vector3.new(
			math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
			math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
			math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
		)
		lo = lo:Min(cf.Position - ex)
		hi = hi:Max(cf.Position + ex)
	end
	return lo, hi
end

-- the old spec's firing-hand anchor for a weapon (gun origin placement), from WeaponModels
local oldGrip = {}
function M.setOldGrip(id, v)
	oldGrip[id] = v
end

local function scaledCF(cf: CFrame, s: number): CFrame
	return CFrame.new(cf.Position * s) * cf.Rotation
end

-- build the gun item `it` (guid g in `items`) at `origin` (the gun origin's world frame) with `scale`
function M.build(items, it, origin: CFrame, scale: number, g: string?)
	-- the guid is needed for the layout; find it when the caller only has the item
	if not g then
		for k, v in items do
			if v == it then
				g = k
				break
			end
		end
	end
	if not g or not M.ready(items, g) then
		return nil
	end
	local l = lib()
	local layout = WP.layout(items, g)
	local st = WP.stats(items, g)
	-- anchors in the root's frame
	local A = {}
	local gripPart, handFrom = nil, nil
	local pumpRoot = nil
	for _, e in layout do
		local pm = GunMeta.parts[e.id]
		local p = WP.parts[e.id]
		if pm then
			for name, v in pm.anchors do
				local w = e.cf * v
				if name == "grip" then
					-- the pistol grip's own anchor wins over the receiver's
					if not gripPart or (p and p.cat == "grip") then
						A.grip, gripPart = w, e.id
					end
				elseif name == "hand" then
					-- the support hand: a foregrip, else the handguard or forend, else the base
					local rank = (p and p.cat == "foregrip") and 3 or ((p and (p.cat == "handguard" or p.cat == "stock")) and 2 or 1)
					if not handFrom or rank > handFrom then
						A.hand, handFrom = w, rank
					end
				elseif name == "muzzle" then
					-- the outermost muzzle (a device beats the barrel, the barrel beats the base)
					if not A.muzzle or w.Z < A.muzzle.Z then
						A.muzzle = w
					end
				elseif name == "eye" then
					if e.g == st.sight then
						A.sight = w
					elseif not A.iron or (p and (p.cat == "receiver" or p.cat == "ironrear")) then
						A.iron = w
					end
				elseif name == "beam" then
					A.beam = A.beam or w
				else
					A[name] = A[name] or w
				end
			end
			if e.slot == "forend" then
				pumpRoot = e.g
			end
		end
	end
	local rootIt = items[g]
	local rootMeta = GunMeta.parts[rootIt.id]
	if rootMeta and rootMeta.slots.mag then
		A.magwell = rootMeta.slots.mag.Position
	end
	A.grip = A.grip or Vector3.new(0, -0.12, 0.05)
	-- place the gun origin so the firing hand sits where the old spec had it
	local target = oldGrip[rootIt.id] or Vector3.new(0, -0.12, 0.05)
	local shift = A.grip - target
	for k, v in A do
		A[k] = v - shift
	end
	local inPump = {}
	if pumpRoot then
		WP.walk(items, pumpRoot, function(cg)
			inPump[cg] = true
		end)
	end
	local out = {
		parts = {}, mag = {}, moving = {}, meshes = true, anchors = A,
		spec = { pistol = rootMeta and rootMeta.cls == "pistol", melee = false },
		eye = A.sight or A.iron or Vector3.new(0, 0.2, 0), muzzle = A.muzzle or Vector3.new(0, 0, -2),
		zoom = st.zoom, reflex = st.reflex, suppressed = st.suppressed,
		shift = shift, -- root-frame point p appears at origin * (p - shift) * scale
	}
	local shiftCF = CFrame.new(-shift)
	for _, e in layout do
		local pm = GunMeta.parts[e.id]
		if pm then
			local isMag = e.slot == "mag" and e.depth == 1
			for _, pc in pm.pieces do
				local src = l:FindFirstChild(pc[1])
				if src then
					local p = src:Clone()
					p.Anchored = false
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Massless = true
					p.Size = src.Size * scale
					p.Color = Color3.new(1, 1, 1)
					local mm = M.MAT[pc[2]] or M.MAT.plastic
					p.Material = mm[1]
					p.Reflectance = mm[2] or 0
					p.Transparency = mm[3] or 0
					p.CastShadow = pc[2] ~= "glass"
					p.CFrame = origin * scaledCF(shiftCF * e.cf * CFrame.new(pc[3]), scale)
					if isMag then
						table.insert(out.mag, p)
					else
						table.insert(out.parts, p)
						local sub = pc[4]
						if sub then
							out.moving[sub] = out.moving[sub] or {}
							table.insert(out.moving[sub], p)
						elseif inPump[e.g] then
							out.moving.pump = out.moving.pump or {}
							table.insert(out.moving.pump, p)
						end
					end
				end
			end
		end
	end
	out.pump = out.moving.pump or {}
	if A.beam then
		-- the lamp: a small invisible part at the light's lens, its Right face down the barrel (-Z)
		local lp = Instance.new("Part")
		lp.Name = "Beam"
		lp.Size = Vector3.new(0.05, 0.05, 0.05) * scale
		lp.Transparency = 1
		lp.Anchored = false
		lp.CanCollide = false
		lp.CanQuery = false
		lp.CanTouch = false
		lp.Massless = true
		lp.CastShadow = false
		lp.CFrame = origin * CFrame.new(A.beam * scale) * CFrame.fromMatrix(Vector3.zero, -Vector3.zAxis, Vector3.yAxis, Vector3.xAxis)
		table.insert(out.parts, lp)
		out.lightPart = lp
	end
	if A.laser then
		-- the laser's aperture: the same kind of part, its Right face down the barrel (the beam starts here)
		local zp = Instance.new("Part")
		zp.Name = "Laser"
		zp.Size = Vector3.new(0.05, 0.05, 0.05) * scale
		zp.Transparency = 1
		zp.Anchored = false
		zp.CanCollide = false
		zp.CanQuery = false
		zp.CanTouch = false
		zp.Massless = true
		zp.CastShadow = false
		zp.CFrame = origin * CFrame.new(A.laser * scale) * CFrame.fromMatrix(Vector3.zero, -Vector3.zAxis, Vector3.yAxis, Vector3.xAxis)
		table.insert(out.parts, zp)
		out.laserPart = zp
	end
	return out
end

return M

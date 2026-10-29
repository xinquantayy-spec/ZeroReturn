--!nonstrict
-- Appearance (M16): what a character visibly wears, rebuilt only from authoritative state.
--   Equipment.resolve(holder slots + look) -> entries grouped per slot ("head", "ears", "armor", "back", ...,
--   "outfit", "bodycam"). Every group has a signature; an apply destroys and rebuilds only the groups whose
--   signature changed (per-slot diff), so a clothing change never recreates the character or touches combat state.
--   The character carries AppearanceRev (bumped on every visible change), Look / LookVariant and Gear_<slot>
--   (item id) attributes, which replicate to every client, late joiners included.
--   Worn pieces are welded, unanchored, massless, with no collision, queries or touch: decorative only (shots hit
--   the body parts and Health's armour rules decide protection from the item definitions).
--   A mesh that has not loaded gets a neutral box (logged once). When an asset batch arrives later, every character
--   with a fallback is reconciled from its holder's *current* state, so an older request can never win.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ZR")
local Equipment = require(Shared.Equipment)
local WP = require(Shared.WeaponParts)

local Appearance = {}
local ctx
-- char -> { rev, groups = { [group] = { sig, parts, fallback } }, bodySig, weaponSig, spec }
local tracked = setmetatable({}, { __mode = "k" })
Appearance.tracked = tracked
Appearance.stats = { applies = 0, built = 0, destroyed = 0, fallbacks = 0, reconciles = 0 }
local logged = {}

function Appearance.init(c)
	ctx = c
	if ctx.Assets and ctx.Assets.onLoaded then
		ctx.Assets.onLoaded(function()
			Appearance.reconcileAll("assets")
		end)
	end
end

local function lib()
	return ReplicatedStorage:FindFirstChild("ZR_Assets")
end

local function buildPiece(char, e)
	local host = char:FindFirstChild(e.host)
	if not host or not host:IsA("BasePart") then
		return nil, false
	end
	local L = lib()
	local src = L and L:FindFirstChild(e.key)
	local p, fallback
	if src and src:IsA("BasePart") then
		p = src:Clone()
		if e.scale then
			p.Size = src.Size * e.scale
		end
	else
		-- neutral stand-in until the batch loads: same footprint, plain block, clearly logged
		fallback = true
		p = Instance.new("Part")
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = (Equipment.SIZE[e.key] or Vector3.new(0.4, 0.4, 0.4)) * (e.scale or Vector3.one)
		Appearance.stats.fallbacks += 1
		if not logged[e.key] then
			logged[e.key] = true
			warn("[ZR] appearance fallback: mesh " .. e.key .. " not loaded yet (neutral box; protection unchanged)")
		end
	end
	p.Name = "Gear"
	p.Color = Color3.fromHex(e.tint)
	p.Material = Enum.Material[e.mat] or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.CFrame = host.CFrame * CFrame.new(e.offset)
	p:SetAttribute("ZR_Gear", e.group)
	p:SetAttribute("Key", e.key)
	local w = Instance.new("WeldConstraint")
	w.Part0 = host
	w.Part1 = p
	w.Parent = p
	p.Parent = char
	Appearance.stats.built += 1
	return p, fallback == true
end

-- what the hands and back show: the active weapon (with its mounts and magazine) and slung long guns
local function weaponSig(h, activeG)
	if not h then
		return "none"
	end
	local parts = { tostring(activeG) }
	local it = activeG and h.items[activeG]
	if it then
		-- the whole build (M14: every part shows in third person) and whether a magazine is in
		parts[#parts + 1] = WP.signature(h.items, activeG) .. (it.mag and "M" or "-")
	end
	for _, slot in { "primary", "secondary" } do
		local g = h.slots[slot]
		parts[#parts + 1] = (g and h.items[g]) and (g .. ":" .. WP.signature(h.items, g)) or "-"
	end
	return table.concat(parts, "|")
end

-- spec: { look, variant, holder, active (guid of the weapon in hands), weapons = false (no weapon visuals),
--         items = { [slot] = { id, tint } } (explicit state instead of a holder), keepWeapons = true }
-- Returns the appearance revision and whether anything visible changed.
function Appearance.apply(char, spec)
	if not char then
		return 0, false
	end
	spec = spec or {}
	local rec = tracked[char]
	if not rec then
		rec = { rev = char:GetAttribute("AppearanceRev") or 0, groups = {} }
		tracked[char] = rec
	end
	local look = Equipment.lookKey(spec.look or char:GetAttribute("Look"))
	local variant = spec.variant or char:GetAttribute("LookVariant") or 1
	rec.spec = { look = look, variant = variant, holder = spec.holder, active = spec.active, weapons = spec.weapons, items = spec.items }
	local state = spec.items and { look = look, variant = variant, items = spec.items } or Equipment.stateOf(spec.holder, look, variant)
	local entries = Equipment.resolve(state)
	local sigs = Equipment.signature(entries)
	local byGroup = {}
	local L = lib()
	for _, e in entries do
		local list = byGroup[e.group]
		if not list then
			list = {}
			byGroup[e.group] = list
		end
		table.insert(list, e)
		if not (L and L:FindFirstChild(e.key)) then
			-- availability is part of the signature: a fallback group rebuilds once its mesh arrives
			sigs[e.group] = sigs[e.group] .. "|fallback"
		end
	end
	local changed = false
	for g, grp in rec.groups do
		if sigs[g] ~= grp.sig then
			for _, p in grp.parts do
				p:Destroy()
			end
			Appearance.stats.destroyed += #grp.parts
			rec.groups[g] = nil
			changed = true
		end
	end
	for g, list in byGroup do
		if not rec.groups[g] then
			local parts, fb = {}, false
			for _, e in list do
				local p, isFb = buildPiece(char, e)
				if p then
					table.insert(parts, p)
					fb = fb or isFb
				end
			end
			rec.groups[g] = { sig = sigs[g], parts = parts, fallback = fb }
			changed = true
		end
	end
	-- stray gear (tagged but not in a current group, e.g. from an older build) never survives an apply
	local keep = {}
	for _, grp in rec.groups do
		for _, p in grp.parts do
			keep[p] = true
		end
	end
	for _, c in char:GetChildren() do
		if c:GetAttribute("ZR_Gear") and not keep[c] then
			c:Destroy()
			Appearance.stats.destroyed += 1
			changed = true
		end
	end
	-- outfit colours on the body segments
	local bodySig = look .. "/" .. tostring(variant)
	if rec.bodySig ~= bodySig then
		local outfit = Equipment.lookOf(look, variant)
		for name, cloth in Equipment.CLOTH do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				p.Color = Color3.fromHex(outfit[cloth] or "808080")
			end
		end
		rec.bodySig = bodySig
		changed = true
	end
	-- weapon carry state (in hand / slung)
	if not spec.keepWeapons and ctx and ctx.Chars then
		-- slung guns sit over the pack / plates, so the back extent is part of the weapon signature
		local wsig = (spec.weapons == false) and "off" or (weaponSig(spec.holder, spec.active) .. string.format("|%.2f", Equipment.backExtent(entries)))
		if rec.weaponSig ~= wsig then
			if spec.weapons == false or not spec.holder then
				ctx.Chars.setWeapon(char, nil, nil)
			else
				ctx.Chars.setWeapon(char, spec.holder, spec.active)
			end
			rec.weaponSig = wsig
			changed = true
		end
	end
	if changed then
		rec.rev += 1
	end
	char:SetAttribute("AppearanceRev", rec.rev)
	char:SetAttribute("Look", look)
	char:SetAttribute("LookVariant", variant)
	char:SetAttribute("BodyVersion", Equipment.BODY_VERSION)
	char:SetAttribute("NeckUp", Equipment.neckUpOf(state))
	for _, slot in Equipment.VISUAL_SLOTS do
		local it = state.items[slot]
		char:SetAttribute("Gear_" .. slot, it and it.id or nil)
	end
	Appearance.stats.applies += 1
	return rec.rev, changed
end

-- a weapon was put in the hands outside an apply (AI weapon switch): keep the record in step
function Appearance.noteWeapon(char, holder, g)
	local rec = char and tracked[char]
	if rec then
		local look = char:GetAttribute("Look")
		local entries = Equipment.resolve(Equipment.stateOf(holder, look, char:GetAttribute("LookVariant")))
		rec.weaponSig = holder and (weaponSig(holder, g) .. string.format("|%.2f", Equipment.backExtent(entries))) or "off"
		if rec.spec then
			rec.spec.active = g
		end
	end
end

-- rebuild every character that still shows a fallback, from its holder's current state
function Appearance.reconcileAll(reason)
	local n = 0
	for char, rec in tracked do
		local stale = false
		for _, grp in rec.groups do
			if grp.fallback then
				stale = true
				break
			end
		end
		if stale and char.Parent and rec.spec then
			local s = table.clone(rec.spec)
			s.keepWeapons = true
			Appearance.apply(char, s)
			n += 1
		end
	end
	Appearance.stats.reconciles += 1
	if n > 0 then
		print(string.format("[ZR] appearance: reconciled %d character(s) (%s)", n, tostring(reason)))
	end
	return n
end

-- current visible pieces of a character: { [group] = { keys... } } (tests, dev)
function Appearance.describe(char)
	local rec = char and tracked[char]
	local out = {}
	if rec then
		for g, grp in rec.groups do
			local keys = {}
			for _, p in grp.parts do
				if p.Parent then
					table.insert(keys, (p:GetAttribute("Key") or "?") .. (p:IsA("MeshPart") and "" or "(fallback)"))
				end
			end
			table.sort(keys)
			out[g] = keys
		end
	end
	return out
end

function Appearance.forget(char)
	tracked[char] = nil
end

return Appearance

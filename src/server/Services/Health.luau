--!nonstrict
-- Tarkov-style health (server-authoritative): seven body-part pools (440 total), light/heavy bleeding,
-- fractures, pain, energy/hydration, Tarkov 0.14's armour (hit zones, plates, soft armour and helmet parts, each with
-- its own class and durability; penetration, blunt trauma and ricochets: Plates.luau), destroyed-limb damage spill,
-- timed medical treatment, fall damage.
-- Players and AI share the same model; clients receive a compact "vitals" snapshot.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Textures = require(Shared.Textures)
local Inv = require(script.Parent.Inv)
local Progress = require(Shared.Progress)
local Plates = require(Shared.Plates)

local Health = {}
local ctx
local states = {} -- [model] = hs
Health.states = states

Health.PARTS = { "head", "thorax", "stomach", "larm", "rarm", "lleg", "rleg" }
local MAX = { head = 35, thorax = 85, stomach = 70, larm = 60, rarm = 60, lleg = 65, rleg = 65 }
Health.MAX = MAX
Health.NAMES = { head = "HEAD", thorax = "THORAX", stomach = "STOMACH", larm = "LEFT ARM", rarm = "RIGHT ARM", lleg = "LEFT LEG", rleg = "RIGHT LEG" }
local PART_OF = {
	Head = "head", UpperTorso = "thorax", LowerTorso = "stomach", HumanoidRootPart = "stomach", Torso = "thorax",
	LeftUpperArm = "larm", LeftLowerArm = "larm", LeftHand = "larm", RightUpperArm = "rarm", RightLowerArm = "rarm", RightHand = "rarm",
	LeftUpperLeg = "lleg", LeftLowerLeg = "lleg", LeftFoot = "lleg", RightUpperLeg = "rleg", RightLowerLeg = "rleg", RightFoot = "rleg",
}
Health.PART_OF = PART_OF
-- damage to a destroyed (blacked) part spreads to the rest at these rates (EFT wiki, Health system; audit gameplay.4)
local SPILL = { larm = 0.49, rarm = 0.49, lleg = 0.7, rleg = 0.7, stomach = 1.05 }
Health.SPILL = SPILL
local LIMB = { larm = true, rarm = true, lleg = true, rleg = true }
local BLEED_L, BLEED_H = 0.55, 1.5 -- hp/s
-- the cult's poison (Tarkov's cultist knife: a toxin that keeps hurting after the fight until an antidote stops it):
-- 1 hp/s spread over the body by each part's share, plus faster thirst and hunger. Our numbers; no source gives them.
local TOXIN = { rate = 1.0, energy = 0.08, water = 0.12 }
Health.TOXIN = TOXIN
local MED_COST = { light = 40, heavy = 120, fracture = 100 }

local function now()
	return os.clock()
end

function Health.new(scale)
	local hs = { parts = {}, bleedL = {}, bleedH = {}, fract = {}, painUntil = 0, energy = 100, water = 100, dead = false, dirty = true }
	for _, k in Health.PARTS do
		local m = MAX[k] * (scale or 1)
		hs.parts[k] = { hp = m, max = m }
	end
	return hs
end

local function total(hs)
	local t, m = 0, 0
	for _, p in hs.parts do
		t += p.hp
		m += p.max
	end
	return t, m
end
Health.total = total

local function syncHumanoid(hs)
	local hum = hs.hum
	if not hum or not hum.Parent then
		return
	end
	local t, m = total(hs)
	hum.MaxHealth = m
	if not hs.dead then
		hum.Health = math.max(1, t)
	end
end

function Health.kill(hs, cause)
	if hs.dead then
		return
	end
	hs.dead = true
	hs.cause = cause or hs.cause
	hs.dirty = true
	if hs.hum and hs.hum.Parent then
		hs.hum.Health = 0
	end
end

function Health.get(model)
	return states[model]
end

function Health.of(player)
	local char = player.Character
	return char and states[char]
end

-- opts: { player?, holder = fn -> holder, scale?, saved?, kind = "player"|"ai", inRaid? }
function Health.attach(model, opts)
	local hs = Health.new(opts.scale)
	hs.model, hs.player, hs.holder, hs.kind, hs.inRaid = model, opts.player, opts.holder, opts.kind or "ai", opts.inRaid
	local saved = opts.saved
	if saved and saved.parts then
		for k, v in saved.parts do
			if hs.parts[k] and type(v) == "number" then
				hs.parts[k].hp = math.clamp(v, 1, hs.parts[k].max)
			end
		end
		hs.energy = math.clamp(saved.energy or 100, 0, 100)
		hs.water = math.clamp(saved.water or 100, 0, 100)
	end
	hs.hum = model:FindFirstChildOfClass("Humanoid")
	states[model] = hs
	syncHumanoid(hs)
	-- old saves (gameplay-2a): armour from before plates and parts takes its new form once (Inv.migrateArmour)
	local h0 = opts.holder and opts.holder()
	if h0 and Inv.migrateArmour(h0) > 0 and opts.player and ctx and ctx.Profiles then
		ctx.Profiles.markDirty(opts.player)
	end
	model.AncestryChanged:Connect(function(_, parent)
		if not parent and states[model] == hs then
			states[model] = nil
		end
	end)
	-- fall damage (legs), fractures on hard landings
	if hs.hum then
		local root = model:FindFirstChild("HumanoidRootPart")
		local peak = 0
		hs.hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Freefall then
				peak = 0
				task.spawn(function()
					while hs.hum.Parent and hs.hum:GetState() == Enum.HumanoidStateType.Freefall do
						if root then
							peak = math.max(peak, -root.AssemblyLinearVelocity.Y)
						end
						task.wait()
					end
				end)
			elseif new == Enum.HumanoidStateType.Landed and peak > 62 and not hs.dead then
				local fprof = hs.player and ctx.Profiles.get(hs.player)
				local dmg = (peak - 62) * 1.1 * (1 - (fprof and Progress.bonus(fprof.skills, "health") or 0))
				Health.applyDamage(hs, "lleg", dmg * 0.5)
				Health.applyDamage(hs, "rleg", dmg * 0.5)
				if peak > 78 then
					hs.fract[math.random() < 0.5 and "lleg" or "rleg"] = true
				end
				hs.cause = hs.cause or "FALL"
				hs.dirty = true
			end
		end)
	end
	return hs
end

-- ── damage ─────────────────────────────────────────────────────────────────────
local applyDamage
local function spill(hs, key, amount)
	local alive = {}
	for _, k in Health.PARTS do
		if k ~= key and hs.parts[k].hp > 0 then
			table.insert(alive, k)
		end
	end
	if #alive == 0 then
		return Health.kill(hs)
	end
	local each = amount / #alive
	for _, k in alive do
		applyDamage(hs, k, each, true)
		if hs.dead then
			return
		end
	end
end

applyDamage = function(hs, key, dmg, noSpill)
	if dmg <= 0 or hs.dead then
		return
	end
	local p = hs.parts[key]
	if p.hp > 0 then
		local over = dmg - p.hp
		p.hp = math.max(0, p.hp - dmg)
		if p.hp <= 0 then
			if key == "head" or key == "thorax" then
				return Health.kill(hs)
			end
			if over > 0 and not noSpill then
				spill(hs, key, over * (SPILL[key] or 1))
			end
		end
	else
		if key == "head" or key == "thorax" then
			return Health.kill(hs)
		end
		if not noSpill then
			spill(hs, key, dmg * (SPILL[key] or 1))
		end
	end
	hs.dirty = true
	if total(hs) <= 0 then
		Health.kill(hs)
	end
end
Health.applyDamage = applyDamage

-- ── armour (Tarkov 0.14, decision gameplay-2a; the zones, formats and maths in Plates.luau) ────────────────────────────
-- Where on the body part the ray lands picks the zone (Plates.zoneOf). The pieces covering that zone are its layers,
-- outermost first: on the torso the plate whose format covers the spot, then the vest's soft part for the zone; on the
-- head the helmet's part (the face shield while it is down), an armoured face cover, then ballistic glasses. Each layer
-- has its own class and durability; Plates.resolve runs the round through them.

-- where a hit lands: { zone, pool, face, u, v, angle? } (angle: off head-on, for ricochets off a helmet)
local function whereHit(info)
	local p = info.part
	if not (p and typeof(p) == "Instance" and p:IsA("BasePart") and PART_OF[p.Name]) then
		return { zone = "chest", pool = "thorax", face = "front", u = 0, v = 0.3 }
	end
	local cf, h = p.CFrame, p.Size / 2
	local to = cf:PointToObjectSpace(typeof(info.hitPos) == "Vector3" and info.hitPos or p.Position)
	local from = typeof(info.from) == "Vector3" and cf:PointToObjectSpace(info.from) or nil
	-- a blow or a blast aimed at the part's middle meets its surface on the side it came from
	local lp = Plates.entry(from, to, h)
	if lp.Magnitude < 1e-3 then
		lp = Vector3.new(0, 0, -h.Z) -- no direction known: the front
	end
	local w = Plates.zoneOf(p.Name, lp, h)
	if w.pool == "head" and from then
		w.angle = Plates.incidence(lp, h, lp - from)
	end
	return w
end
Health.whereHit = whereHit

-- the layers protecting a hit at `w`, outermost first: { it, d, k (part) | plate, class, cur, max, destr, blunt, soft, ric }
local function layersFor(hs, w, partInst)
	local out = {}
	local h = hs.holder and hs.holder()
	if not h then
		return out
	end
	local zone = w.zone
	local function worn(slot)
		local g = h.slots[slot]
		local it = g and h.items[g]
		local d = it and Items.defs[it.id]
		if d and d.armor then
			return it, d
		end
		return nil, nil
	end
	local function parts(it, d, skipVisor)
		Plates.sync(it, d) -- a trader's repair sets it.dur: the parts follow
		for _, e in Plates.partsOf(d) or {} do
			if e.zones[zone] and not (e.visor and skipVisor) then
				local cur = Plates.partDur(it, d, e.k)
				if cur > 0 then
					table.insert(out, {
						-- soft: a vest's or rig's built-in armour (blunt under a stopped plate drops with it behind)
						it = it, d = d, k = e.k, class = e.class, cur = cur, max = e.dur, destr = e.destr, blunt = e.blunt, ric = e.ric,
						soft = d.kind == "armor" or d.kind == "rig",
					})
				end
			end
		end
	end
	if w.pool == "head" then
		local visorUp = partInst and partInst.Parent and partInst.Parent:GetAttribute("VisorUp") == true
		for _, slot in { "head", "face", "eyes" } do
			local it, d = worn(slot)
			if it then
				parts(it, d, visorUp)
			end
		end
		return out
	end
	for _, slot in { "armor", "rig" } do
		local it, d = worn(slot)
		if it then
			-- a plate (only on the torso, and only where its format covers), then the soft armour behind it
			local slots = Plates.slotsOf(d)
			if slots and it.mods and partInst and (partInst.Name == "UpperTorso" or partInst.Name == "Torso") then
				for _, s in Plates.SLOTS do
					local pg = it.mods[s]
					local p = pg and h.items[pg]
					local pd = p and Items.defs[p.id]
					if pd and pd.armor and (p.dur or 0) > 0 and Plates.plateCovers(Plates.shapeOf(d, s, pd), s, w) then
						table.insert(out, {
							it = p, d = pd, plate = true, class = pd.armor.class, cur = p.dur, max = pd.armor.dur, destr = pd.armor.destr,
							blunt = pd.armor.blunt, soft = false,
						})
					end
				end
			end
			parts(it, d, false)
		end
	end
	return out
end
Health.layersFor = layersFor

-- info = { dmg, pen, armorDmg, bleedL, bleedH, part (BasePart), hitPos, from, attacker, cause }
-- returns { part (the health pool), zone, dmg, penetrated, armor (the first piece hit), ricochet, killed }
function Health.hit(model, info)
	local hs = states[model]
	if not hs or hs.dead then
		return nil
	end
	local w = whereHit(info)
	local key = w.pool
	local layers = layersFor(hs, w, info.part)
	local r = Plates.resolve(layers, { dmg = info.dmg or 0, pen = info.pen or 0, armorDmg = info.armorDmg or 0.4, angle = w.angle }, math.random)
	for i, loss in r.losses do
		local L = layers[i]
		if loss > 0 and L then
			if L.k then
				Plates.setPart(L.it, L.d, L.k, L.cur - loss)
			else
				L.it.dur = math.max(0, (L.it.dur or 0) - loss)
			end
			hs.gearDirty = true
		end
	end
	local res = { part = key, zone = w.zone, penetrated = r.penetrated, armor = layers[1] and layers[1].d.id or nil, ricochet = r.ricochet or nil }
	local dmg = r.dmg
	-- a stopped or deflected round leaves no wound (no bleeding, no fracture), only its blunt damage
	local wounds = r.penetrated
	res.dmg = dmg
	hs.cause = info.cause or hs.cause
	hs.lastHit = { attacker = info.attacker, part = key, zone = w.zone, ammo = info.ammo, weapon = info.weapon, from = info.from, at = now() }
	applyDamage(hs, key, dmg)
	-- vitality skill (players): fewer bleeds; taking hits trains it
	local prof = hs.player and ctx.Profiles.get(hs.player)
	local bleedMul = 1 - (prof and Progress.bonus(prof.skills, "vitality") or 0)
	if prof and dmg > 0 and ctx.Economy then
		ctx.Economy.skillUp(hs.player, prof, "vitality", dmg * 0.04)
		ctx.Economy.skillUp(hs.player, prof, "stress", dmg * 0.02)
	end
	if wounds and dmg > 0 and not hs.dead then
		if math.random() < (info.bleedH or 0.05) * bleedMul then
			hs.bleedH[key] = true
		elseif math.random() < (info.bleedL or 0.12) * bleedMul then
			hs.bleedL[key] = true
		end
		if LIMB[key] and math.random() < (0.05 + dmg / 280) * (1 - (prof and Progress.bonus(prof.skills, "health") or 0)) then
			hs.fract[key] = true
		end
		-- a poisoned blade (THE CULT): the wound poisons until an antidote
		if info.toxin and not hs.toxin then
			hs.toxin = { t0 = now() }
			if hs.player then
				ctx.Remotes.note(hs.player, "toast", { text = "POISONED  ·  ONLY AN ANTIDOTE STOPS IT", tone = "warn" })
			end
		end
	end
	hs.dirty = true
	res.killed = hs.dead
	return res
end

function Health.inPain(hs)
	if now() < hs.painUntil then
		return false
	end
	if next(hs.fract) then
		return true
	end
	for k in LIMB do
		if hs.parts[k].hp <= 0 then
			return true
		end
	end
	return hs.parts.stomach.hp <= 0
end

-- movement / handling modifiers derived from injuries (client applies; server uses for validation)
function Health.mods(hs)
	local painkilled = now() < hs.painUntil
	local legs = 0
	for _, k in { "lleg", "rleg" } do
		if hs.fract[k] or hs.parts[k].hp <= 0 then
			legs += 1
		end
	end
	local arms = 0
	for _, k in { "larm", "rarm" } do
		if hs.fract[k] or hs.parts[k].hp <= 0 then
			arms += 1
		end
	end
	local pain = Health.inPain(hs)
	local m = {
		speed = (1 - legs * (painkilled and 0.06 or 0.14)) * (hs.using and 0.55 or 1),
		sprint = (legs == 0 or painkilled) and not hs.using,
		sway = 1 + arms * 0.45 + (pain and 0.35 or 0),
		tremor = pain and 0.7 or (hs.toxin and 0.4 or 0),
		reload = 1 + arms * 0.25,
		staminaRegen = ((hs.energy <= 0 or hs.water <= 0) and 0.5 or 1) * (((hs.boostUntil or 0) > os.clock()) and 1.5 or 1),
	}
	return m
end

local I = Textures.ICON
function Health.vitals(hs)
	local t, m = total(hs)
	local parts = {}
	for k, p in hs.parts do
		parts[k] = { math.ceil(p.hp), math.floor(p.max), hs.bleedH[k] and 2 or (hs.bleedL[k] and 1 or 0), hs.fract[k] and true or false }
	end
	local fx = {}
	local red, orange, green, blue = Color3.fromRGB(255, 56, 44), Color3.fromRGB(255, 134, 52), Color3.fromRGB(95, 255, 112), Color3.fromRGB(96, 192, 255)
	if next(hs.bleedH) then
		table.insert(fx, { icon = I.BLEED, label = "HEAVY BLEED", color = red })
	end
	if next(hs.bleedL) then
		table.insert(fx, { icon = I.BLEED, label = "BLEEDING", color = orange })
	end
	if next(hs.fract) then
		table.insert(fx, { icon = I.FRACTURE, label = "FRACTURE", color = orange })
	end
	if now() < hs.painUntil then
		table.insert(fx, { icon = I.PAIN, label = "PAINKILLERS", color = green })
	elseif Health.inPain(hs) then
		table.insert(fx, { icon = I.PAIN, label = "PAIN", color = red })
	end
	if hs.toxin then
		table.insert(fx, { icon = I.SKULL, label = "POISONED", color = Color3.fromRGB(160, 230, 70) })
	end
	if hs.water <= 0 then
		table.insert(fx, { icon = I.WATER, label = "DEHYDRATED", color = red })
	end
	if hs.energy <= 0 then
		table.insert(fx, { icon = I.ENERGY, label = "EXHAUSTED", color = red })
	end
	return {
		hp = t, max = m, parts = parts, effects = fx, energy = hs.energy, water = hs.water, mods = Health.mods(hs),
		using = hs.using and { label = hs.using.label, t0 = hs.using.t0, dur = hs.using.dur } or nil,
	}
end

function Health.push(hs)
	hs.dirty = false
	if hs.player and hs.player.Parent then
		ctx.Remotes.note(hs.player, "vitals", Health.vitals(hs))
	end
end

-- persisted between raids (bleeds/fractures are treated on return; destroyed parts come back at 1 hp)
function Health.save(hs)
	local parts = {}
	for k, p in hs.parts do
		parts[k] = math.max(1, math.floor(p.hp))
	end
	return { parts = parts, energy = math.floor(hs.energy), water = math.floor(hs.water) }
end

-- ── treatment ──────────────────────────────────────────────────────────────────
local function worstBleed(map, limbsOnly)
	local best, bv = nil, -1
	for k in map do
		if (not limbsOnly or LIMB[k]) then
			local v = MAX[k]
			if v > bv then
				best, bv = k, v
			end
		end
	end
	return best
end

local function mostDamaged(hs)
	local best, miss = nil, 0
	for _, k in Health.PARTS do
		local p = hs.parts[k]
		if p.hp > 0 and p.max - p.hp > miss then
			best, miss = k, p.max - p.hp
		end
	end
	return best, miss
end

-- what this item would do now (or nil, error)
local function plan(hs, d, it, part)
	if d.kind == "flare" then
		-- a signal flare (Services/Airdrop.luau): fired straight up under the open sky; the red one may call a plane
		local A = ctx.Airdrop
		if not (A and hs.player) then
			return nil, "NOT_USABLE"
		end
		local ok, code, msg = A.canFlare(hs.player)
		if not ok then
			return nil, code, msg
		end
		return { time = 1.2, label = "FIRING THE " .. string.upper(d.short or d.name), apply = function()
			A.flare(hs.player, d.flare)
			return 1
		end }
	end
	if d.kind == "food" then
		local f = d.food
		return { time = f.time or 3, label = "CONSUMING " .. string.upper(d.name), apply = function()
			hs.energy = math.clamp(hs.energy + (f.energy or 0), 0, 100)
			hs.water = math.clamp(hs.water + (f.water or 0), 0, 100)
			if f.stamina then
				-- an energy drink's boost (audit gameplay.8): stamina comes back half as fast again for f.stamina seconds
				hs.boostUntil = os.clock() + f.stamina
				hs.dirty = true
			end
			return 1
		end }
	end
	local m = d.med
	if not m then
		return nil, "NOT_USABLE"
	end
	local label = "USING " .. string.upper(d.name)
	if m.antidote then
		if not hs.toxin then
			return nil, "NOTHING_TO_TREAT"
		end
		return { time = m.time or 3, label = label, apply = function()
			hs.toxin = nil
			hs.dirty = true
			return 1
		end }
	end
	if m.pain and not m.hp then
		return { time = m.time or 1.5, label = label, apply = function()
			local pprof = hs.player and ctx.Profiles.get(hs.player)
			hs.painUntil = now() + (m.duration or 120) * (1 + (pprof and Progress.bonus(pprof.skills, "stress") or 0))
			return 1
		end }
	end
	if m.surgery then
		local target = (part and hs.parts[part] and hs.parts[part].hp <= 0 and part ~= "head" and part ~= "thorax") and part or nil
		if not target then
			for _, k in { "stomach", "larm", "rarm", "lleg", "rleg" } do
				if hs.parts[k].hp <= 0 then
					target = k
					break
				end
			end
		end
		if not target then
			return nil, "NOTHING_TO_TREAT"
		end
		local sprof = hs.player and ctx.Profiles.get(hs.player)
		return { time = (m.time or 12) * (1 - (sprof and Progress.bonus(sprof.skills, "surgery") or 0)), label = "SURGERY  ·  " .. Health.NAMES[target], apply = function()
			if hs.player then
				ctx.Economy.skillUp(hs.player, sprof, "surgery", 5)
			end
			local p = hs.parts[target]
			p.max = math.max(1, math.floor(p.max * 0.6))
			p.hp = 1
			return 1
		end }
	end
	-- bleeds / fractures first (Tarkov order), then hit points
	local heavy = m.heavy and ((part and hs.bleedH[part] and (not m.limbsOnly or LIMB[part])) and part or worstBleed(hs.bleedH, m.limbsOnly))
	if heavy then
		return { time = m.time or 3, label = label .. "  ·  " .. Health.NAMES[heavy], apply = function()
			hs.bleedH[heavy] = nil
			return m.hp and MED_COST.heavy or 1
		end }
	end
	local light = m.light and ((part and hs.bleedL[part]) and part or worstBleed(hs.bleedL, false))
	if light then
		return { time = m.time or 3, label = label .. "  ·  " .. Health.NAMES[light], apply = function()
			hs.bleedL[light] = nil
			return m.hp and MED_COST.light or 1
		end }
	end
	local frac = m.fracture and ((part and hs.fract[part]) and part or next(hs.fract))
	if frac then
		return { time = m.time or 4.5, label = label .. "  ·  " .. Health.NAMES[frac], apply = function()
			hs.fract[frac] = nil
			return m.hp and MED_COST.fracture or 1
		end }
	end
	if m.hp then
		local target, miss = nil, 0
		if part and hs.parts[part] and hs.parts[part].hp > 0 then
			target, miss = part, hs.parts[part].max - hs.parts[part].hp
		else
			target, miss = mostDamaged(hs)
		end
		if not target or miss < 1 then
			return nil, "NOTHING_TO_TREAT"
		end
		local amount = math.min(miss, it.hp or m.hp, 70)
		return { time = m.time or 3, label = label .. "  ·  " .. Health.NAMES[target], apply = function()
			local p = hs.parts[target]
			local real = math.min(amount, p.max - p.hp)
			p.hp += real
			return real
		end }
	end
	return nil, "NOTHING_TO_TREAT"
end

-- auto-pick the right item for the worst problem (Heal key)
local function smartPick(hs, h)
	local function find(pred)
		for _, cid in Inv.loadOrder(h) do
			for g in h.grids[cid] or {} do
				local it = h.items[g]
				local d = Items.defs[it.id]
				if (d.kind == "med") and pred(d.med, it) then
					return g
				end
			end
		end
		return nil
	end
	-- worst problem first; fall through when nothing on you treats it
	if next(hs.bleedH) then
		local limb = worstBleed(hs.bleedH, true)
		local g = (limb and find(function(m)
			return m.heavy and m.limbsOnly
		end)) or find(function(m)
			return m.heavy and not m.hp
		end) or find(function(m)
			return m.heavy
		end)
		if g then
			return g
		end
	end
	if next(hs.bleedL) then
		local g = find(function(m)
			return m.light and not m.hp and not m.heavy
		end) or find(function(m)
			return m.light
		end)
		if g then
			return g
		end
	end
	if next(hs.fract) then
		local g = find(function(m)
			return m.fracture
		end)
		if g then
			return g
		end
	end
	if Health.inPain(hs) then
		local g = find(function(m)
			return m.pain
		end)
		if g then
			return g
		end
	end
	local _, miss = mostDamaged(hs)
	if miss > 0 then
		return find(function(m, it)
			return m.hp ~= nil and (it.hp or m.hp) > 0
		end)
	end
	return nil
end

function Health.use(player, g, part)
	local s = ctx.Raid.session(player)
	local char = player.Character
	local hs = char and states[char]
	if not s or s.done or not hs or hs.dead then
		return ctx.Remotes.fail("NOT_AUTHORIZED")
	end
	if hs.using then
		return ctx.Remotes.fail("BUSY")
	end
	if part ~= nil and (type(part) ~= "string" or not MAX[part]) then
		return ctx.Remotes.fail("BAD_INPUT")
	end
	local h = s.inv
	if g == nil then
		g = smartPick(hs, h)
		if not g then
			return ctx.Remotes.fail("NOTHING_TO_TREAT", "Nothing to treat, or no suitable medicine.")
		end
	end
	local it = h.items[g]
	if not it then
		return ctx.Remotes.fail("NO_ITEM")
	end
	local d = Items.defs[it.id]
	local pl, err, msg = plan(hs, d, it, part)
	if not pl then
		return ctx.Remotes.fail(err or "NOTHING_TO_TREAT", msg)
	end
	local token = { label = pl.label, t0 = os.clock(), dur = pl.time }
	hs.using = token
	hs.dirty = true
	ctx.Remotes.note(player, "heal", { state = "start", t = pl.time, label = pl.label })
	if ctx.Chars and ctx.Chars.gesture then
		ctx.Chars.gesture(player.Character, "heal", pl.time)
	end
	task.delay(pl.time, function()
		if hs.using ~= token then
			return
		end
		hs.using = nil
		hs.dirty = true
		if hs.dead or ctx.Raid.session(player) ~= s or s.done or not h.items[g] then
			ctx.Remotes.note(player, "heal", { state = "cancel" })
			return
		end
		local used = pl.apply()
		if d.food and ctx.Economy then
			ctx.Economy.skillUp(player, ctx.Profiles.get(player), "metabolism", 6)
		end
		if d.med and d.med.hp then
			it.hp = (it.hp or d.med.hp) - (used or 0)
			if it.hp <= 0 then
				Inv.consume(h, g)
			end
		elseif it.uses and it.uses > 1 then
			it.uses -= 1
		else
			Inv.consume(h, g)
		end
		syncHumanoid(hs)
		ctx.Remotes.note(player, "heal", { state = "done" })
		Health.push(hs)
		ctx.Raid.push(player)
	end)
	return ctx.Remotes.ok()
end

function Health.cancelUse(player)
	local hs = Health.of(player)
	if hs and hs.using then
		hs.using = nil
		hs.dirty = true
		ctx.Remotes.note(player, "heal", { state = "cancel" })
	end
end

-- AI treatment (M8): same rules and items as players, picked automatically from the AI's own kit.
-- Returns the treatment time, or nil when there is nothing to treat or nothing to treat it with.
function Health.aiUse(model, h)
	local hs = states[model]
	if not hs or hs.dead or hs.using or not h then
		return nil
	end
	local g = smartPick(hs, h)
	local it = g and h.items[g]
	if not it then
		return nil
	end
	local d = Items.defs[it.id]
	local pl = plan(hs, d, it, nil)
	if not pl then
		return nil
	end
	local token = { label = pl.label, t0 = os.clock(), dur = pl.time }
	hs.using = token
	if ctx.Chars and ctx.Chars.gesture then
		ctx.Chars.gesture(model, "heal", pl.time)
	end
	task.delay(pl.time, function()
		if hs.using ~= token then
			return
		end
		hs.using = nil
		if hs.dead or not h.items[g] then
			return
		end
		local used = pl.apply()
		if d.med and d.med.hp then
			it.hp = (it.hp or d.med.hp) - (used or 0)
			if it.hp <= 0 then
				Inv.consume(h, g)
			end
		elseif it.uses and it.uses > 1 then
			it.uses -= 1
		else
			Inv.consume(h, g)
		end
		syncHumanoid(hs)
	end)
	return pl.time
end

-- ── loops ──────────────────────────────────────────────────────────────────────
function Health.init(c)
	ctx = c
	ctx.Remotes.onAct("cancelUse", function(player)
		Health.cancelUse(player)
	end, 3, 4)
end

function Health.start()
	-- 1 Hz: bleeding, metabolism, safehouse recovery
	task.spawn(function()
		while true do
			task.wait(1)
			for model, hs in states do
				if not hs.dead and model.Parent then
					for k in hs.bleedL do
						applyDamage(hs, k, BLEED_L)
						hs.cause = hs.cause or "BLEEDING"
					end
					for k in hs.bleedH do
						applyDamage(hs, k, BLEED_H)
						hs.cause = hs.cause or "BLEEDING"
					end
					if hs.toxin then
						local _, m = total(hs)
						for k, p in hs.parts do
							if p.hp > 0 and not hs.dead then
								applyDamage(hs, k, TOXIN.rate * p.max / math.max(1, m), true)
							end
						end
						hs.cause = hs.cause or "POISON"
						hs.energy = math.max(0, hs.energy - TOXIN.energy)
						hs.water = math.max(0, hs.water - TOXIN.water)
						hs.dirty = true
					end
					if hs.player then
						local prof = ctx.Profiles.get(hs.player)
						if hs.inRaid then
							-- metabolism skill slows energy / hydration drain
							local m = 1 - (prof and Progress.bonus(prof.skills, "metabolism") or 0)
							hs.energy = math.max(0, hs.energy - m / 26)
							hs.water = math.max(0, hs.water - m / 18)
							if hs.energy <= 0 or hs.water <= 0 then
								applyDamage(hs, "stomach", 0.2)
							end
						else
							-- hideout: slow natural recovery (the medstation speeds it up)
							local rate = 0.6 * ((prof and ctx.Hideout) and ctx.Hideout.healRate(prof) or 1)
							for _, p in hs.parts do
								if p.hp < p.max then
									p.hp = math.min(p.max, p.hp + rate)
									hs.dirty = true
								end
							end
							hs.energy = math.min(100, hs.energy + 0.25)
							hs.water = math.min(100, hs.water + 0.25)
						end
					end
					if hs.bleedL and (next(hs.bleedL) or next(hs.bleedH)) then
						hs.dirty = true
					end
					syncHumanoid(hs)
				end
			end
		end
	end)
	-- 6 Hz: push vitals to players when something changed
	task.spawn(function()
		while true do
			task.wait(0.16)
			for _, hs in states do
				if hs.dirty and hs.player then
					Health.push(hs)
				end
				if hs.gearDirty and hs.player then
					hs.gearDirty = false
					ctx.Raid.push(hs.player)
				end
			end
		end
	end)
end

return Health

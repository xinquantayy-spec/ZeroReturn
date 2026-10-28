--!nonstrict
-- Tarkov-style health (server-authoritative): seven body-part pools (440 total), light/heavy bleeding,
-- fractures, pain, energy/hydration, armor with class/durability/penetration, blunt trauma, helmet face
-- coverage and ricochets, destroyed-limb damage spill, timed medical treatment, fall damage.
-- Players and AI share the same model; clients receive a compact "vitals" snapshot.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Textures = require(Shared.Textures)
local Inv = require(script.Parent.Inv)

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
local SPILL = { larm = 0.7, rarm = 0.7, lleg = 1.0, rleg = 1.0, stomach = 1.5 }
local LIMB = { larm = true, rarm = true, lleg = true, rleg = true }
local BLEED_L, BLEED_H = 0.55, 1.5 -- hp/s
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
				local dmg = (peak - 62) * 1.1
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

-- worn armor protecting this hit, if any: guid, item, def
local function armorFor(hs, key, hitPos, partInst)
	local h = hs.holder and hs.holder()
	if not h then
		return nil
	end
	local function worn(slot)
		local g = h.slots[slot]
		local it = g and h.items[g]
		local d = it and Items.defs[it.id]
		if d and d.armor and (it.dur or 0) > 0 then
			return g, it, d
		end
		return nil
	end
	if key == "head" then
		local g, it, d = worn("head")
		if not g then
			return nil
		end
		local face = false
		if partInst and hitPos then
			local lp = partInst.CFrame:PointToObjectSpace(hitPos)
			face = lp.Z < -0.2 and lp.Y < 0.25
		end
		local covered
		if face then
			covered = d.armor.face == true
		else
			covered = math.random() < math.min(1, (d.armor.coverage or 0.6) + 0.3)
		end
		if covered then
			return g, it, d
		end
		return nil
	end
	local zone = (key == "thorax" and "thorax") or (key == "stomach" and "stomach") or ((key == "larm" or key == "rarm") and "arms") or nil
	if not zone then
		return nil
	end
	for _, slot in { "armor", "rig" } do
		local g, it, d = worn(slot)
		if g and d.armor.zones and d.armor.zones[zone] then
			return g, it, d
		end
	end
	return nil
end

-- info = { dmg, pen, armorDmg, bleedL, bleedH, part (BasePart), hitPos, attacker, cause }
-- returns { part, dmg, penetrated, armor, ricochet, killed }
function Health.hit(model, info)
	local hs = states[model]
	if not hs or hs.dead then
		return nil
	end
	local key = PART_OF[info.part and info.part.Name or ""] or "thorax"
	local res = { part = key, penetrated = true }
	local dmg = info.dmg or 0
	local wounds = true
	local g, it, d = armorFor(hs, key, info.hitPos, info.part)
	if g then
		local a = d.armor
		local durFrac = math.clamp(it.dur / a.dur, 0, 1)
		local eff = a.class * 10 * (0.55 + 0.45 * durFrac)
		local chance = math.clamp(((info.pen or 0) - eff + 12) / 24, 0, 1)
		local pen = math.random() < chance
		res.armor, res.penetrated = d.id, pen
		if key == "head" and not pen and a.ricochet and math.random() < a.ricochet * 0.5 then
			res.ricochet = true
			dmg = 0
			wounds = false
		end
		it.dur = math.max(0, it.dur - (info.pen or 20) * (info.armorDmg or 0.4) * (a.destr or 0.5) * (pen and 1.1 or 0.9))
		hs.gearDirty = true
		if pen then
			dmg *= (1 - a.class * 0.04)
		elseif not res.ricochet then
			dmg = (info.dmg or 0) * (a.blunt or 0.25)
			wounds = false
		end
	end
	res.dmg = dmg
	hs.cause = info.cause or hs.cause
	hs.lastHit = { attacker = info.attacker, part = key, ammo = info.ammo, weapon = info.weapon, from = info.from, at = now() }
	applyDamage(hs, key, dmg)
	if wounds and dmg > 0 and not hs.dead then
		if math.random() < (info.bleedH or 0.05) then
			hs.bleedH[key] = true
		elseif math.random() < (info.bleedL or 0.12) then
			hs.bleedL[key] = true
		end
		if LIMB[key] and math.random() < 0.05 + dmg / 280 then
			hs.fract[key] = true
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
		tremor = pain and 0.7 or 0,
		reload = 1 + arms * 0.25,
		staminaRegen = (hs.energy <= 0 or hs.water <= 0) and 0.5 or 1,
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
	if d.kind == "food" then
		local f = d.food
		return { time = f.time or 3, label = "CONSUMING " .. string.upper(d.name), apply = function()
			hs.energy = math.clamp(hs.energy + (f.energy or 0), 0, 100)
			hs.water = math.clamp(hs.water + (f.water or 0), 0, 100)
			return 1
		end }
	end
	local m = d.med
	if not m then
		return nil, "NOT_USABLE"
	end
	local label = "USING " .. string.upper(d.name)
	if m.pain and not m.hp then
		return { time = m.time or 1.5, label = label, apply = function()
			hs.painUntil = now() + (m.duration or 120)
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
		return { time = m.time or 12, label = "SURGERY  ·  " .. Health.NAMES[target], apply = function()
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
	local pl, err = plan(hs, d, it, part)
	if not pl then
		return ctx.Remotes.fail(err or "NOTHING_TO_TREAT")
	end
	local token = { label = pl.label, t0 = os.clock(), dur = pl.time }
	hs.using = token
	hs.dirty = true
	ctx.Remotes.note(player, "heal", { state = "start", t = pl.time, label = pl.label })
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
					if hs.player then
						if hs.inRaid then
							hs.energy = math.max(0, hs.energy - 1 / 26)
							hs.water = math.max(0, hs.water - 1 / 18)
							if hs.energy <= 0 or hs.water <= 0 then
								applyDamage(hs, "stomach", 0.2)
							end
						else
							-- hideout: slow natural recovery
							for _, p in hs.parts do
								if p.hp < p.max then
									p.hp = math.min(p.max, p.hp + 0.6)
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

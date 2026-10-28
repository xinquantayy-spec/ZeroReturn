--!nonstrict
-- Server-authoritative combat. Clients send shot intent only (seq, origin hint, direction).
-- Server validates state/ammo/cadence/origin, raycasts, applies damage. Reload/heal are server timed.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)

local Combat = {}
local ctx
local W = {} -- [player] = weapon runtime
Combat.stats = { accepted = 0, rejected = 0 }

local LIMB = {
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function filter(exclude)
	local list = { exclude }
	local fx = workspace:FindFirstChild("ZR_Fx")
	if fx then
		table.insert(list, fx)
	end
	params.FilterDescendantsInstances = list
	return params
end
Combat.filter = filter

local function ws(player)
	local w = W[player]
	if not w then
		w = { last = 0, seq = 0, reloadUntil = 0 }
		W[player] = w
	end
	return w
end

function Combat.reset(player)
	W[player] = { last = 0, seq = 0, reloadUntil = 0 }
end

local function alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return char, hum
	end
	return nil, nil
end

-- active weapon of a raid session: guid, item, Weapons def, item def, rounds holder (mag or weapon tube)
function Combat.activeWeapon(s)
	local slot = s.active
	local wg = slot and s.inv.slots[slot]
	local wit = wg and s.inv.items[wg]
	local d = wit and Items.defs[wit.id]
	local wdef = d and d.weapon and Weapons[d.weapon]
	if not wdef then
		return nil
	end
	local rounds = (d.family and wit.mag and s.inv.items[wit.mag]) or ((not d.family) and wit) or nil
	return wg, wit, wdef, d, rounds
end

local function reject(why, player)
	Combat.stats.rejected += 1
	if player then
		ctx.Remotes.strike(player, why)
	end
end

-- Apply a ballistic hit to any character (player or AI) through the Health model.
-- info = { dmg, pen, armorDmg, bleedL, bleedH, part, hitPos, attacker, from, weapon, ammo }
function Combat.hitModel(model, info)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and not ctx.Raid.session(victim) then
		return nil
	end
	local res = ctx.Health.hit(model, info)
	if not res then
		return nil
	end
	if victim then
		ctx.Remotes.note(victim, "dmg", { amt = math.floor(res.dmg + 0.5), from = info.from, part = res.part, blocked = not res.penetrated })
	else
		ctx.AI.onDamaged(model, info.attacker)
	end
	local attacker = info.attacker
	if res.killed and typeof(attacker) == "Instance" and attacker:IsA("Player") then
		ctx.Raid.addKill(attacker, victim)
		ctx.Remotes.note(attacker, "kill", { name = victim and victim.DisplayName or "Harbor Watch" })
	end
	return res
end

-- generic damage (environment): applied to the thorax through the health model
function Combat.damage(model, hum, amount, attacker, fromPos)
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	local res = Combat.hitModel(model, { dmg = amount, pen = 0, armorDmg = 0, part = torso, attacker = attacker, from = fromPos })
	return res and res.killed or false
end

-- active weapon of a raid session: guid, item, Weapons def, item def, rounds holder (mag or weapon tube)
function Combat.activeWeapon(s)
	local slot = s.active
	local wg = slot and s.inv.slots[slot]
	local wit = wg and s.inv.items[wg]
	local d = wit and Items.defs[wit.id]
	local wdef = d and d.weapon and Weapons[d.weapon]
	if not wdef then
		return nil
	end
	local rounds = (d.family and wit.mag and s.inv.items[wit.mag]) or ((not d.family) and wit) or nil
	return wg, wit, wdef, d, rounds
end

local function reject(why, player)
	Combat.stats.rejected += 1
	if player then
		ctx.Remotes.strike(player, why)
	end
end

-- attacker: Player or AI model; fromPos: where the damage came from (for the victim's indicator)
function Combat.damage(model, hum, amount, attacker, fromPos)
	if hum.Health <= 0 or amount <= 0 then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		if not ctx.Raid.session(victim) then
			return false
		end
		local w = W[victim]
		if w and w.healToken then
			w.healToken = nil
			ctx.Remotes.note(victim, "heal", { state = "cancel" })
		end
	end
	hum.Health = math.max(0, hum.Health - amount)
	local killed = hum.Health <= 0
	if victim then
		ctx.Remotes.note(victim, "dmg", { amt = math.floor(amount + 0.5), from = fromPos })
	else
		ctx.AI.onDamaged(model, attacker)
	end
	if killed and typeof(attacker) == "Instance" and attacker:IsA("Player") then
		ctx.Raid.addKill(attacker)
		ctx.Remotes.note(attacker, "kill", { name = victim and victim.DisplayName or "Harbor Watch" })
	end
	return killed
end

function Combat.shoot(player, seq, origin, dir)
	if type(seq) ~= "number" or not Util.finite(seq) or not Util.vec(origin) or not Util.vec(dir) then
		return reject("malformed shot", player)
	end
	local s = ctx.Raid.session(player)
	if not s or s.done then
		return reject("shot outside raid", nil)
	end
	local char = alive(player)
	local head = char and char:FindFirstChild("Head")
	if not head then
		return reject("dead shooter", nil)
	end
	local w = ws(player)
	if seq <= w.seq then
		return reject("replayed seq", player)
	end
	w.seq = seq
	local t = os.clock()
	if t < w.reloadUntil then
		return reject("shot while reloading", nil)
	end
	local wg, wit, wdef, wd, mag = Combat.activeWeapon(s)
	if not wdef then
		return reject("no weapon", player)
	end
	if t - w.last < (60 / wdef.rpm) * 0.8 then
		return reject("fire rate", player)
	end
	local hs = ctx.Health.of(player)
	if hs and hs.using then
		return reject("shot while treating", nil)
	end
	if not mag or (mag.a or 0) <= 0 then
		ctx.Remotes.note(player, "ammo", { a = 0 })
		return reject("empty", nil)
	end
	local m = dir.Magnitude
	if m < 0.5 or m > 1.5 then
		return reject("bad direction", player)
	end
	dir /= m
	local hp = head.Position
	if (origin - hp).Magnitude > 7 then
		origin = hp
	elseif (origin - hp).Magnitude > 0.05 and workspace:Raycast(hp, origin - hp, filter(char)) then
		origin = hp -- origin hint behind a wall: fall back to the server head position
	end
	w.last = t
	local ammoDef = mag.at and Items.defs[mag.at]
	mag.a -= 1
	if mag.a <= 0 then
		mag.at = nil
	end
	Combat.stats.accepted += 1
	local ballistic = ammoDef and ammoDef.ammo or { dmg = 40, pen = 20 }
	local pellets = ballistic.pellets or 1
	local hit, killed = false, false
	local firstPos, firstNormal
	for i = 1, pellets do
		local d2 = dir
		if pellets > 1 then
			local sp = math.rad(wdef.pelletSpread or 2.5)
			d2 = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles((math.random() * 2 - 1) * sp, (math.random() * 2 - 1) * sp, 0)).LookVector
		end
		local res = workspace:Raycast(origin, d2 * wdef.range, filter(char))
		local hitPos = res and res.Position or (origin + d2 * wdef.range)
		if i == 1 then
			firstPos, firstNormal = hitPos, res and res.Normal or nil
		end
		if res then
			local model = res.Instance:FindFirstAncestorOfClass("Model")
			local thum = model and model:FindFirstChildOfClass("Humanoid")
			if thum and thum.Health > 0 then
				local dist = (hitPos - origin).Magnitude
				local fs = wdef.range * Weapons.FALLOFF_START
				local fall = 1
				if dist > fs then
					fall = math.max(Weapons.FALLOFF_MIN, 1 - (dist - fs) / (wdef.range - fs) * (1 - Weapons.FALLOFF_MIN))
				end
				local r = Combat.hitModel(model, {
					dmg = ballistic.dmg * fall, pen = (ballistic.pen or 0) * (0.85 + 0.15 * fall), armorDmg = ballistic.armorDmg,
					bleedL = ballistic.bleedL, bleedH = ballistic.bleedH, part = res.Instance, hitPos = hitPos, attacker = player,
					from = origin, weapon = wd.name, ammo = ammoDef and ammoDef.name or "?",
				})
				if r then
					hit = true
					killed = killed or r.killed
				end
			end
		end
	end
	local hitPos = firstPos
	if hit then
		ctx.Remotes.note(player, "hit", { kill = killed })
	end
	ctx.AI.hearShot(origin, player)
	ctx.Remotes.fx("shot", { o = origin, p = hitPos, n = firstNormal, h = hit, w = wd.weapon }, player)
end

function Combat.reload(player)
	local s = ctx.Raid.session(player)
	if not s or s.done or not alive(player) then
		return
	end
	local w = ws(player)
	local t = os.clock()
	if t < w.reloadUntil then
		return
	end
	local wg, wit, wdef, wd, cur = Combat.activeWeapon(s)
	if not wdef or not wd.family then
		ctx.Remotes.note(player, "reload", { state = "none" })
		return
	end
	local best = Inv.bestMag(s.inv, wg)
	if not best then
		ctx.Remotes.note(player, "reload", { state = "none" })
		return
	end
	local dur = (cur and (cur.a or 0) > 0) and wdef.reload or wdef.reloadEmpty
	local token = {}
	w.reloadToken = token
	w.reloadUntil = t + dur
	ctx.Remotes.note(player, "reload", { state = "start", t = dur })
	task.delay(dur, function()
		if W[player] ~= w or w.reloadToken ~= token then
			return
		end
		local s2 = ctx.Raid.session(player)
		if s2 ~= s or s.done or not alive(player) or not s.inv.items[best] or not s.inv.items[wg] then
			return
		end
		local done, err = Inv.insertMag(s.inv, best, wg)
		if not done and err == "NO_SPACE" and wit.mag then
			-- no room for the old magazine: it falls to the ground (Tarkov quick reload)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local b = Inv.take(s.inv, wit.mag)
			if b and root then
				ctx.Loot.spawnPile(root.Position - Vector3.new(0, 2.5, 0), { b })
			end
			Inv.insertMag(s.inv, best, wg)
		end
		local m = wit.mag and s.inv.items[wit.mag]
		ctx.Remotes.note(player, "ammo", { a = m and m.a or 0 })
		ctx.Raid.push(player)
	end)
end

-- interim medkit use (replaced by the body-part Health model)
function Combat.startHeal(player, g)
	local s = ctx.Raid.session(player)
	local char, hum = alive(player)
	if not s or s.done or not hum then
		return ctx.Remotes.fail("NOT_AUTHORIZED")
	end
	if hum.Health >= hum.MaxHealth then
		return ctx.Remotes.fail("FULL_HEALTH", "Already at full health.")
	end
	local w = ws(player)
	if w.healToken then
		return ctx.Remotes.fail("BUSY")
	end
	if g == nil then
		for _, cid in Inv.loadOrder(s.inv) do
			for x in s.inv.grids[cid] or {} do
				local d = Items.defs[s.inv.items[x].id]
				if d.kind == "med" and d.med.hp then
					g = x
					break
				end
			end
			if g then
				break
			end
		end
	end
	local it = g and s.inv.items[g]
	local def = it and Items.defs[it.id]
	if not def or def.kind ~= "med" or not def.med.hp then
		return ctx.Remotes.fail("NO_ITEM", "No medkit on you.")
	end
	local token = {}
	w.healToken = token
	local t = def.med.time or 2.5
	ctx.Remotes.note(player, "heal", { state = "start", t = t, label = "USING " .. string.upper(def.name) })
	task.delay(t, function()
		if w.healToken ~= token then
			return
		end
		w.healToken = nil
		local _, h2 = alive(player)
		if not h2 or ctx.Raid.session(player) ~= s or s.done or not s.inv.items[g] then
			return
		end
		local amount = math.min(h2.MaxHealth - h2.Health, it.hp or def.med.hp, 60)
		h2.Health += amount
		it.hp = (it.hp or def.med.hp) - amount
		if it.hp <= 0 then
			Inv.consume(s.inv, g)
		end
		ctx.Remotes.note(player, "heal", { state = "done" })
		ctx.Raid.push(player)
	end)
	return ctx.Remotes.ok()
end

function Combat.init(c)
	ctx = c
	ctx.Remotes.onShoot(Combat.shoot)
	ctx.Remotes.onAct("reload", function(player)
		Combat.reload(player)
	end, 2, 3)
	ctx.Remotes.onAct("stance", function(player, p)
		local char = player.Character
		if not char or type(p) ~= "table" then
			return
		end
		char:SetAttribute("Crouch", p.c == true)
		char:SetAttribute("Aim", p.a == true)
		char:SetAttribute("Sprint", p.s == true)
		if type(p.p) == "number" and Util.finite(p.p) then
			char:SetAttribute("Pitch", math.clamp(math.floor(p.p), -80, 80))
		end
	end, 12, 14)
	Players.PlayerRemoving:Connect(function(p)
		W[p] = nil
	end)
end

return Combat

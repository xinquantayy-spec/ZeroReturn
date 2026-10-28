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
		w = { last = 0, seq = 0, reloadUntil = 0, drawUntil = 0 }
		W[player] = w
	end
	return w
end

function Combat.reset(player)
	W[player] = { last = 0, seq = 0, reloadUntil = 0, drawUntil = 0 }
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
	if w.tube then
		w.tube = nil -- firing interrupts shell-by-shell loading
	end
	if t < w.reloadUntil then
		return reject("shot while reloading", nil)
	end
	if t < (w.drawUntil or 0) then
		return reject("shot while drawing", nil)
	end
	local wg, wit, wdef, wd, mag = Combat.activeWeapon(s)
	if not wdef or wdef.melee then
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
	local ms = Inv.modStats(s.inv, wg)
	local loud = (wdef.loudness or 1) * ms.loud * ((ammoDef and ammoDef.ammo.subsonic and ms.suppressed) and 0.6 or 1)
	ctx.AI.hearShot(origin, player, nil, loud)
	local tracer = ammoDef and ammoDef.ammo and ammoDef.ammo.tracer or nil
	ctx.Remotes.fx("shot", { o = origin, p = hitPos, n = firstNormal, h = hit, w = wd.weapon, s = ms.suppressed or nil, t = tracer }, player)
end

-- tube-fed weapons: shells go in one at a time from rig/pockets/backpack; firing interrupts
local function tubeReload(player, s, w, wg, wit, wdef, wd)
	local token = {}
	w.tube = token
	ctx.Remotes.note(player, "reload", { state = "tube", t = wdef.reload })
	task.spawn(function()
		while w.tube == token do
			task.wait(wdef.reload)
			if w.tube ~= token or W[player] ~= w or ctx.Raid.session(player) ~= s or s.done or not alive(player) or not s.inv.items[wg] then
				break
			end
			if (wit.a or 0) >= (wd.capacity or 0) then
				break
			end
			local ammoG
			for _, cid in Inv.loadOrder(s.inv) do
				for g in s.inv.grids[cid] or {} do
					local it = s.inv.items[g]
					local d = Items.defs[it.id]
					if d.kind == "ammo" and d.caliber == wd.caliber and ((wit.a or 0) == 0 or wit.at == nil or wit.at == it.id) then
						ammoG = g
						break
					end
				end
				if ammoG then
					break
				end
			end
			if not ammoG then
				break
			end
			Inv.loadAmmo(s.inv, wg, ammoG, 1)
			ctx.Remotes.note(player, "ammo", { a = wit.a or 0, tube = true })
			if (wit.a or 0) >= (wd.capacity or 0) then
				break -- tube full: done right away
			end
		end
		if w.tube == token then
			w.tube = nil
		end
		ctx.Remotes.note(player, "reload", { state = "done" })
		ctx.Raid.push(player)
	end)
end

function Combat.reload(player)
	local s = ctx.Raid.session(player)
	if not s or s.done or not alive(player) then
		return
	end
	local w = ws(player)
	local t = os.clock()
	if t < w.reloadUntil or w.tube then
		return
	end
	local wg, wit, wdef, wd, cur = Combat.activeWeapon(s)
	if not wdef or wdef.melee then
		ctx.Remotes.note(player, "reload", { state = "none" })
		return
	end
	if not wd.family then
		return tubeReload(player, s, w, wg, wit, wdef, wd)
	end
	local best = Inv.bestMag(s.inv, wg)
	if not best then
		ctx.Remotes.note(player, "reload", { state = "none" })
		return
	end
	local hs = ctx.Health.of(player)
	local slow = hs and ctx.Health.mods(hs).reload or 1
	local dur = ((cur and (cur.a or 0) > 0) and wdef.reload or wdef.reloadEmpty) * slow
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

-- switch active weapon slot (draw time blocks firing)
function Combat.draw(player, slot)
	local s = ctx.Raid.session(player)
	if not s or s.done or not alive(player) then
		return
	end
	if slot ~= "primary" and slot ~= "secondary" and slot ~= "holster" and slot ~= "melee" then
		return
	end
	local g = s.inv.slots[slot]
	local it = g and s.inv.items[g]
	local d = it and Items.defs[it.id]
	if not d or not d.weapon or s.active == slot then
		return
	end
	s.active = slot
	Combat.drawDelay(player, slot)
	ctx.Raid.syncGear(player)
	ctx.Raid.push(player)
end

-- a weapon came into the hands: cancel reloads/checks, block firing for its draw time, light off
function Combat.drawDelay(player, slot)
	local s = ctx.Raid.session(player)
	local g = s and s.inv.slots[slot]
	local it = g and s.inv.items[g]
	local d = it and Items.defs[it.id]
	if not d or not d.weapon then
		return
	end
	local w = ws(player)
	w.tube = nil
	w.reloadToken = nil
	w.reloadUntil = 0
	w.checking = nil
	local t = Weapons[d.weapon].draw or 0.6
	w.drawUntil = os.clock() + t
	if player.Character then
		player.Character:SetAttribute("WeaponLight", false)
	end
	ctx.Remotes.note(player, "draw", { slot = slot, t = t })
end

-- tactical light: only when the weapon in hands carries one; replicated via attribute + third-person SpotLight
function Combat.setLight(player, on)
	local s = ctx.Raid.session(player)
	local char = player.Character
	if not s or s.done or not char then
		return
	end
	local wg = s.active and s.inv.slots[s.active]
	on = on == true and wg ~= nil and Inv.modStats(s.inv, wg).light == true
	char:SetAttribute("WeaponLight", on)
	for _, c in char:GetChildren() do
		if c.Name == "TPWeapon" then
			local l = c:FindFirstChild("WeaponLight")
			if l then
				l.Enabled = on
			end
		end
	end
end

-- Tarkov mag check: an estimate, not a number
local function estimate(a, cap)
	if a <= 0 then
		return "EMPTY"
	end
	local f = a / cap
	if f >= 1 then
		return "FULL"
	elseif f > 0.75 then
		return "ALMOST FULL"
	elseif f > 0.4 then
		return "ABOUT HALF"
	elseif f > 0.15 then
		return "LESS THAN HALF"
	end
	return "ALMOST EMPTY"
end

function Combat.magCheck(player)
	local s = ctx.Raid.session(player)
	if not s or s.done or not alive(player) then
		return
	end
	local w = ws(player)
	if w.checking then
		return
	end
	local wg, wit, wdef, wd, rounds = Combat.activeWeapon(s)
	if not wdef or wdef.melee then
		return
	end
	w.checking = true
	ctx.Remotes.note(player, "magcheck", { state = "start", t = 1.1 })
	task.delay(1.1, function()
		w.checking = nil
		local _, _, _, wd2, r2 = Combat.activeWeapon(s)
		if not wd2 then
			return
		end
		local cap = (wd2.family and r2 and Items.defs[r2.id].capacity) or wd2.capacity or 1
		local text = r2 and estimate(r2.a or 0, cap) or "NO MAGAZINE"
		local ammo = r2 and r2.at and Items.defs[r2.at] and Items.defs[r2.at].short or nil
		ctx.Remotes.note(player, "magcheck", { state = "done", text = text, ammo = ammo })
	end)
end

-- knife: short server raycast from the head
function Combat.melee(player, dir)
	local s = ctx.Raid.session(player)
	local char = alive(player)
	if not s or s.done or not char or not Util.vec(dir) then
		return
	end
	local _, _, wdef = Combat.activeWeapon(s)
	if not wdef or not wdef.melee then
		return
	end
	local w = ws(player)
	local t = os.clock()
	if t - w.last < 60 / wdef.rpm * 0.85 or t < (w.drawUntil or 0) then
		return
	end
	w.last = t
	local m = dir.Magnitude
	if m < 0.5 or m > 1.5 then
		return
	end
	local head = char:FindFirstChild("Head")
	local res = workspace:Raycast(head.Position, dir / m * wdef.range, filter(char))
	if res then
		local model = res.Instance:FindFirstAncestorOfClass("Model")
		local thum = model and model:FindFirstChildOfClass("Humanoid")
		if thum and thum.Health > 0 then
			local r = Combat.hitModel(model, { dmg = wdef.damage, pen = wdef.pen, armorDmg = 0.1, bleedL = 0.45, bleedH = 0.25, part = res.Instance, hitPos = res.Position, attacker = player, from = head.Position, weapon = "KNIFE", ammo = "BLADE" })
			if r then
				ctx.Remotes.note(player, "hit", { kill = r.killed })
			end
		end
	end
	ctx.AI.hearShot(head.Position, player, nil, 0.1)
end

function Combat.init(c)
	ctx = c
	ctx.Remotes.onShoot(Combat.shoot)
	ctx.Remotes.onAct("reload", function(player)
		Combat.reload(player)
	end, 2, 3)
	ctx.Remotes.onAct("draw", function(player, p)
		if type(p) == "table" and type(p.slot) == "string" then
			Combat.draw(player, p.slot)
		end
	end, 4, 6)
	ctx.Remotes.onAct("light", function(player, p)
		if type(p) == "table" and type(p.on) == "boolean" then
			Combat.setLight(player, p.on)
		end
	end, 3, 4)
	ctx.Remotes.onAct("magcheck", function(player)
		Combat.magCheck(player)
	end, 1, 2)
	ctx.Remotes.onAct("melee", function(player, p)
		if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" and type(p.z) == "number" then
			Combat.melee(player, Vector3.new(p.x, p.y, p.z))
		end
	end, 3, 4)
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

--!nonstrict
-- Server-authoritative combat. Clients send shot intent only (seq, origin hint, direction).
-- Server validates state/ammo/cadence/origin, raycasts, applies damage. Reload/heal are server timed.
local Players = game:GetService("Players")
local STUDIO = game:GetService("RunService"):IsStudio()
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Ballistics = require(Shared.Ballistics)
local Progress = require(Shared.Progress)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local Inv = require(script.Parent.Inv)
local WP = require(Shared.WeaponParts)

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
	if victim and STUDIO and victim:GetAttribute("DevGod") then
		return nil -- Studio test harness: watch AI fight a target that cannot die
	end
	local res = ctx.Health.hit(model, info)
	if not res then
		return nil
	end
	if victim then
		ctx.Remotes.note(victim, "dmg", { amt = math.floor(res.dmg + 0.5), from = info.from, part = res.part, blocked = not res.penetrated })
	else
		local as = typeof(info.attacker) == "Instance" and info.attacker:IsA("Player") and ctx.Raid.session(info.attacker)
		if as and as.scav then
			as.hostile = true -- a scav who shoots the guards is treated as an enemy for the rest of the raid
		end
		ctx.AI.onDamaged(model, info.attacker)
	end
	local attacker = info.attacker
	if res.killed and typeof(attacker) == "Instance" and attacker:IsA("Player") and attacker ~= victim then
		ctx.Raid.addKill(attacker, victim, model, res.part == "head")
		ctx.Remotes.note(attacker, "kill", { name = victim and victim.DisplayName or (model:GetAttribute("Label") or "UNKNOWN") })
	end
	return res
end

-- generic damage (environment): applied to the thorax through the health model
function Combat.damage(model, hum, amount, attacker, fromPos)
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	local res = Combat.hitModel(model, { dmg = amount, pen = 0, armorDmg = 0, part = torso, attacker = attacker, from = fromPos })
	return res and res.killed or false
end

-- ── M11 part B: wear, heat and malfunctions (Tarkov; docs/design/EFT_PARITY.md) ─────────────────────────────
-- Every shot wears the gun (more when hot). Mechanical malfunctions only below 93 % condition, likelier the worse it
-- is; big magazines cause feed failures at any condition; medium heat doubles the chance, maximum heat jams the bolt.
-- The malfunction stays with the gun until cleared: L (inspect) identifies it, then Shift+T clears it. A misfire
-- loses the round; a hard jam (5 % condition or less) may take more than one try.
Combat.BURN = { rifle = 0.05, smg = 0.04, pistol = 0.035, shotgun = 0.08, bolt = 0.07 } -- condition points per shot
local HEAT = { rifle = 0.011, smg = 0.009, pistol = 0.012, shotgun = 0.03, bolt = 0.035 } -- heat per shot (1 = max)
local HEAT_TAU = 30 -- seconds for the heat to fall to 1/e
Combat.FIX_TIME = { misfire = 0.9, eject = 1.3, feed = 1.6, jam = 2.2 }
Combat.MALF_NAMES = { misfire = "MISFIRE", eject = "FAILURE TO EJECT", feed = "FAILURE TO FEED", jam = "JAMMED BOLT" }
local heatOf = {} -- [weapon guid] = { h, t }

function Combat.heat(wg, t)
	local e = heatOf[wg]
	return e and e.h * math.exp(-((t or os.clock()) - e.t) / HEAT_TAU) or 0
end

-- per-shot chances: mechanical (by condition) and magazine (by capacity)
function Combat.malfChance(wear, magDef, heat)
	local mech = wear < 93 and 0.01 * ((93 - wear) / 93) ^ 1.5 or 0
	local feed = 0
	if magDef and (magDef.capacity or 0) >= 40 then
		feed = (magDef.capacity >= 50) and 0.003 or 0.002
	end
	if (heat or 0) >= 0.6 then
		mech, feed = mech * 2, feed * 2
	end
	return mech, feed
end

local function setMalf(player, wit, kind, hard)
	wit.mf, wit.mfk, wit.mfh = kind, nil, hard or nil
	ctx.Remotes.note(player, "malf", { state = "on" })
end

-- L: inspecting the gun identifies its malfunction
function Combat.inspect(player)
	local s = ctx.Raid.session(player)
	if not s or s.done or not alive(player) then
		return
	end
	local _, wit = Combat.activeWeapon(s)
	if not wit or not wit.mf or wit.mfk then
		return
	end
	local w = ws(player)
	if w.fixing then
		return
	end
	w.fixing = true
	ctx.Chars.gesture(player.Character, "check", 1.2)
	task.delay(1.2, function()
		w.fixing = nil
		if wit.mf then
			wit.mfk = true
			ctx.Remotes.note(player, "malf", { state = "known", kind = wit.mf, name = Combat.MALF_NAMES[wit.mf], hard = wit.mfh })
		end
	end)
end

-- Shift+T on a malfunctioning gun: clear it (once identified)
function Combat.clearMalf(player, s, w, wg, wit)
	if not wit.mfk then
		ctx.Remotes.note(player, "toast", { text = "INSPECT THE WEAPON FIRST", tone = "warn" })
		return
	end
	if w.fixing then
		return
	end
	w.fixing = true
	local tprof = ctx.Profiles.get(player)
	local dur = (Combat.FIX_TIME[wit.mf] or 1.2) * (wit.mfh and 1.6 or 1) * (1 - Progress.bonus(tprof and tprof.skills, "troubleshooting"))
	ctx.Remotes.note(player, "malf", { state = "fixing", t = dur })
	ctx.Chars.gesture(player.Character, "reload", dur)
	task.delay(dur, function()
		w.fixing = nil
		if not wit.mf or ctx.Raid.session(player) ~= s or s.done or not s.inv.items[wg] then
			return
		end
		if wit.mfh and math.random() < 0.5 then
			ctx.Remotes.note(player, "malf", { state = "known", kind = wit.mf, name = Combat.MALF_NAMES[wit.mf], hard = true, again = true })
			return
		end
		wit.mf, wit.mfk, wit.mfh = nil, nil, nil
		ctx.Remotes.note(player, "malf", { state = "off" })
		ctx.Economy.skillUp(player, tprof, "troubleshooting", 2)
	end)
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
	if char:GetAttribute("Mounted") then
		return reject("shot while on a mounted gun", nil) -- the mounted gun fires through Stationary, not the personal weapon
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
	-- fire rate: a small bucket instead of a strict gap between shots, so network jitter that bunches two honest shots
	-- does not drop one (audit quick win tech.10); the average still cannot pass the gun's rate by more than 10 %
	local rate = wdef.rpm / 60 * 1.1
	w.fireTokens = math.min(2, (w.fireTokens or 2) + (t - (w.fireT or t)) * rate)
	w.fireT = t
	if w.fireTokens < 1 then
		return reject("fire rate", player)
	end
	w.fireTokens -= 1
	local hs = ctx.Health.of(player)
	if hs and hs.using then
		return reject("shot while treating", nil)
	end
	if ctx.Grenades and ctx.Grenades.busy(player) then
		return reject("shot while throwing", nil)
	end
	-- M14: a gun missing a required part (barrel, bolt, handguard, ...) does not fire
	if wg and not WP.operable(s.inv.items, wg) then
		if t - (w.inopNote or 0) > 2 then
			w.inopNote = t
			ctx.Remotes.note(player, "toast", { text = "WEAPON IS MISSING PARTS", tone = "warn" })
		end
		return reject("inoperable", nil)
	end
	if not mag or (mag.a or 0) <= 0 then
		ctx.Remotes.note(player, "ammo", { a = 0 })
		return reject("empty", nil)
	end
	if wit and wit.mf then
		if t - (w.malfNote or 0) > 1.5 then
			w.malfNote = t
			ctx.Remotes.note(player, "malf", { state = "on" })
		end
		return reject("malfunction", nil)
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
	-- wear, heat, malfunctions (M11 part B)
	local malf
	if wg and wit and not wdef.melee then
		local h = Combat.heat(wg, t) + (HEAT[wdef.class] or 0.012)
		heatOf[wg] = { h = h, t = t }
		local wear = wit.wear or 100
		wit.wear = math.max(0, wear - (Combat.BURN[wdef.class] or 0.05) * (h >= 0.6 and 1.5 or 1))
		local mech, feed = Combat.malfChance(wear, mag ~= wit and Items.defs[mag.id] or nil, h)
		if h >= 1 then
			malf = "jam"
		elseif math.random() < feed then
			malf = "feed"
		elseif math.random() < mech then
			local r = math.random()
			malf = r < 0.25 and "misfire" or r < 0.55 and "eject" or r < 0.7 and "feed" or "jam"
		end
		if malf == "misfire" then
			-- the primer fails: the round is lost and nothing leaves the barrel
			setMalf(player, wit, "misfire")
			return
		end
	end
	Combat.stats.accepted += 1
	local ballistic = ammoDef and ammoDef.ammo or { dmg = 40, pen = 20 }
	local pellets = ballistic.pellets or 1
	local ms = Inv.modStats(s.inv, wg)
	-- ballistics (Tarkov): the bullet flies with drop and travel time; the bore is tilted for the sight's zero
	local v0, k = Ballistics.muzzle(wdef, ms.vel), Ballistics.drag(wdef)
	local zeroM = (s.zero and s.zero[wg]) or Ballistics.DEFAULT_ZERO
	local bore = Ballistics.tilt(dir, Ballistics.zeroAngle(zeroM, v0, k))
	local params = filter(char)
	local wskill = Progress.WEAPON_SKILL[wdef.class]
	local prof = ctx.Profiles.get(player)
	ctx.Economy.skillUp(player, prof, wskill, 0.08)
	local predHit = false
	local firstPos, firstNormal, firstMat
	for i = 1, pellets do
		local d2 = bore
		if pellets > 1 then
			local sp = math.rad(wdef.pelletSpread or 2.5)
			d2 = (CFrame.lookAt(Vector3.zero, bore) * CFrame.Angles((math.random() * 2 - 1) * sp, (math.random() * 2 - 1) * sp, 0)).LookVector
		end
		-- the shot's effects follow the arc as the world stands now
		local pres, ppos = Ballistics.trace(origin, d2, v0, k, wdef.range, params)
		if i == 1 then
			firstPos, firstNormal, firstMat = ppos, pres and pres.Normal or nil, pres and pres.Material or nil
		end
		local pm = pres and pres.Instance:FindFirstAncestorOfClass("Model")
		predHit = predHit or (pm ~= nil and pm:FindFirstChildOfClass("Humanoid") ~= nil)
		-- the damage comes from the bullet in flight
		Ballistics.fly(origin, d2, v0, k, wdef.range, params, function(res, hitPos, dist, _, keep)
			if ctx.Hazards.hit(res.Instance, player) then
				return
			end
			keep = type(keep) == "number" and keep or 1 -- the share of its damage the bullet kept through panes of glass
			local model = res.Instance:FindFirstAncestorOfClass("Model")
			local thum = model and model:FindFirstChildOfClass("Humanoid")
			if not (thum and thum.Health > 0) then
				return
			end
			local fs = wdef.range * Weapons.FALLOFF_START
			local fall = 1
			if dist > fs then
				fall = math.max(Weapons.FALLOFF_MIN, 1 - (dist - fs) / (wdef.range - fs) * (1 - Weapons.FALLOFF_MIN))
			end
			local r = Combat.hitModel(model, {
				dmg = ballistic.dmg * fall * keep, pen = (ballistic.pen or 0) * (0.85 + 0.15 * fall) * keep, armorDmg = ballistic.armorDmg,
				bleedL = ballistic.bleedL, bleedH = ballistic.bleedH, part = res.Instance, hitPos = hitPos, attacker = player,
				from = origin, weapon = wd.name, ammo = ammoDef and ammoDef.name or "?",
			})
			if r and player.Parent then
				ctx.Remotes.note(player, "hit", { kill = r.killed })
				ctx.Economy.skillUp(player, prof, wskill, 0.4)
				-- weapon mastering (Tarkov): one point per hit on a living target, so every pellet that lands counts
				ctx.Economy.masteryUp(player, prof, wdef.id, 1)
			end
		end)
	end
	local hitPos = firstPos
	local loud = (wdef.loudness or 1) * ms.loud * ((ammoDef and ammoDef.ammo.subsonic and ms.suppressed) and 0.6 or 1)
	ctx.AI.hearShot(origin, player, nil, loud)
	ctx.AI.bulletPassed(origin, hitPos, char)
	local tracer = ammoDef and ammoDef.ammo and ammoDef.ammo.tracer or nil
	ctx.Remotes.fx("shot", { o = origin, p = hitPos, n = firstNormal, h = predHit, w = wd.weapon, s = ms.suppressed or nil, t = tracer, m = firstMat }, player)
	if malf then
		setMalf(player, wit, malf, malf == "jam" and (wit.wear or 100) <= 5)
	end
end

-- WEAPON MASTERING (03) (Tarkov): only a weapon mastered to level 3 reloads while aiming down sights. Below that the
-- replicated aim is held off for the length of a reload (Weapon.luau does the same in first person), so others see
-- the gun come down and the server hitboxes follow; nothing the client says can raise the level.
function Combat.aimReload(prof, weaponId)
	return Progress.masteryFor(prof and prof.mastering, weaponId) >= 3
end

local function reloading(w)
	return os.clock() < w.reloadUntil or w.tube ~= nil
end

local function aimAllowed(player, s)
	local _, _, wdef = Combat.activeWeapon(s)
	return wdef ~= nil and Combat.aimReload(ctx.Profiles.get(player), wdef.id)
end

local function dropAim(player, s)
	local char = player.Character
	if char and char:GetAttribute("Aim") and not aimAllowed(player, s) then
		char:SetAttribute("Aim", false)
		ctx.Chars.pose(char)
	end
end

-- tube-fed weapons: shells go in one at a time from rig/pockets/backpack; firing interrupts
local function tubeReload(player, s, w, wg, wit, wdef, wd)
	local token = {}
	w.tube = token
	ctx.Remotes.note(player, "reload", { state = "tube", t = wdef.reload })
	ctx.Chars.gesture(player.Character, "tube", wdef.reload)
	task.spawn(function()
		while w.tube == token do
			task.wait(wdef.reload)
			if w.tube ~= token or W[player] ~= w or ctx.Raid.session(player) ~= s or s.done or not alive(player) or not s.inv.items[wg] then
				break
			end
			if (wit.a or 0) >= (Inv.capacityOf(s.inv, wg) or 0) then
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
			if (wit.a or 0) >= (Inv.capacityOf(s.inv, wg) or 0) then
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
		dropAim(player, s)
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
	dropAim(player, s)
	ctx.Remotes.note(player, "reload", { state = "start", t = dur })
	ctx.Chars.gesture(player.Character, "reload", dur)
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
	if not d or not d.weapon or s.active == slot or (ctx.Grenades and ctx.Grenades.busy(player)) then
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
		player.Character:SetAttribute("WeaponLaser", false)
		ctx.Chars.gesture(player.Character, "draw", t)
	end
	ctx.Remotes.note(player, "draw", { slot = slot, t = t })
end

-- tactical device: only when the weapon in hands carries one; replicated via attributes (WeaponLight with the
-- third-person SpotLight, WeaponLaser drawn by every client's LaserFx). A light/laser combo has a mode (Tarkov: Ctrl+T
-- switches it): "both", "light" or "laser"; a single-purpose device ignores it.
function Combat.deviceState(ms, on, mode)
	on = on == true
	local light = on and ms.light == true and (not ms.laser or mode ~= "laser")
	local laser = on and ms.laser == true and (not ms.light or mode ~= "light")
	return light, laser
end
function Combat.setLight(player, on, mode)
	local s = ctx.Raid.session(player)
	local char = player.Character
	if not s or s.done or not char then
		return
	end
	local wg = s.active and s.inv.slots[s.active]
	local ms = wg and Inv.modStats(s.inv, wg) or {}
	local laser
	on, laser = Combat.deviceState(ms, on == true and wg ~= nil, mode)
	char:SetAttribute("WeaponLaser", laser)
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

-- Alt+T checks the magazine (an estimate), Shift+T the chamber (Tarkov)
function Combat.magCheck(player, chamber)
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
	local dur = chamber and 0.8 or 1.1
	ctx.Remotes.note(player, "magcheck", { state = "start", t = dur, chamber = chamber })
	ctx.Chars.gesture(player.Character, "check", dur)
	task.delay(dur, function()
		w.checking = nil
		local _, _, _, wd2, r2 = Combat.activeWeapon(s)
		if not wd2 then
			return
		end
		local cap = (wd2.family and r2 and Items.defs[r2.id].capacity) or (wg and Inv.capacityOf(s.inv, wg)) or wd2.capacity or 1
		local text = r2 and estimate(r2.a or 0, cap) or "NO MAGAZINE"
		local ammo = r2 and r2.at and Items.defs[r2.at] and Items.defs[r2.at].short or nil
		if chamber then
			local loaded = r2 and (r2.a or 0) > 0
			text = loaded and "ROUND IN CHAMBER" or "CHAMBER EMPTY"
			ammo = loaded and ammo or nil
		end
		ctx.Remotes.note(player, "magcheck", { state = "done", text = text, ammo = ammo, chamber = chamber })
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
	ctx.Chars.gesture(char, "slash", 0.5)
	local head = char:FindFirstChild("Head")
	-- the blow is cast in the shots' group, so it can meet a pane's hit shell: a pane it reaches breaks and takes the blow
	local res = workspace:Raycast(head.Position, dir / m * wdef.range, Ballistics.shotParams(filter(char)))
	if res and ctx.Glass and ctx.Glass.blow(res.Instance, res.Position, dir / m, player) then
		res = nil
	end
	if res then
		local model = res.Instance:FindFirstAncestorOfClass("Model")
		local thum = model and model:FindFirstChildOfClass("Humanoid")
		if thum and thum.Health > 0 then
			local mprof = ctx.Profiles.get(player)
			ctx.Economy.skillUp(player, mprof, "melee", 1)
			local r = Combat.hitModel(model, { dmg = wdef.damage * (1 + Progress.bonus(mprof and mprof.skills, "melee")), pen = wdef.pen, armorDmg = 0.1, bleedL = 0.45, bleedH = 0.25, part = res.Instance, hitPos = res.Position, attacker = player, from = head.Position, weapon = "KNIFE", ammo = "BLADE" })
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
			local mode = (p.mode == "light" or p.mode == "laser") and p.mode or "both"
			Combat.setLight(player, p.on, mode)
		end
	end, 3, 4)
	ctx.Remotes.onAct("magcheck", function(player, p)
		local chamber = type(p) == "table" and p.chamber == true
		local s = chamber and ctx.Raid.session(player)
		if s and not s.done and alive(player) then
			local wg, wit = Combat.activeWeapon(s)
			if wit and wit.mf then
				Combat.clearMalf(player, s, ws(player), wg, wit)
				return
			end
		end
		Combat.magCheck(player, chamber)
	end, 1, 2)
	-- a face shield raised or lowered (Tarkov's N): raised, the face is open to hits (Health)
	ctx.Remotes.onAct("visor", function(player, p)
		local char = player.Character
		if char and type(p) == "table" and type(p.up) == "boolean" then
			char:SetAttribute("VisorUp", p.up or nil)
		end
	end, 4, 4)
	-- night-vision goggles flipped down over the eyes or up (Tarkov's N): the pose of the device on the head mount shows on the
	-- character (Equipment "nvg" group) and Raid.syncGear redresses it; no device on the mount keeps the attribute off
	ctx.Remotes.onAct("nvg", function(player, p)
		local s = ctx.Raid.session(player)
		local char = player.Character
		if s and not s.done and char and alive(player) and type(p) == "table" and type(p.down) == "boolean" then
			local down = p.down and ctx.Raid.nvgOf(s.inv) ~= nil
			s.nvDown = down or nil
			char:SetAttribute("NvDown", down or nil)
			ctx.Raid.syncGear(player)
		end
	end, 4, 4)
	-- zeroing (Tarkov's Page Up / Page Down): the zero of the weapon in hand, in Tarkov's steps up to its sights' range
	ctx.Remotes.onAct("zero", function(player, p)
		local s = ctx.Raid.session(player)
		if not s or type(p) ~= "table" or type(p.d) ~= "number" or not table.find(Ballistics.ZEROS, p.d) then
			return
		end
		local wg = Combat.activeWeapon(s)
		if not wg then
			return
		end
		local maxM = Inv.modStats(s.inv, wg).range or 400
		if p.d > maxM then
			ctx.Remotes.note(player, "zero", { d = (s.zero and s.zero[wg]) or Ballistics.DEFAULT_ZERO, max = maxM, g = wg })
			return
		end
		s.zero = s.zero or {}
		s.zero[wg] = p.d
		ctx.Remotes.note(player, "zero", { d = p.d, g = wg })
	end, 8, 8)
	ctx.Remotes.onAct("inspect", function(player)
		Combat.inspect(player)
	end, 1, 2)
	ctx.Remotes.onAct("melee", function(player, p)
		if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" and type(p.z) == "number" then
			Combat.melee(player, Vector3.new(p.x, p.y, p.z))
		end
	end, 3, 4)
	ctx.Remotes.onAct("stance", function(player, p)
		-- aiming during a reload needs WEAPON MASTERING (03) of the weapon in hands (aimAllowed above)
		local w = W[player]
		if type(p) == "table" and p.a == true and w and reloading(w) then
			local s = ctx.Raid.session(player)
			if s and not aimAllowed(player, s) then
				p.a = false
			end
		end
		ctx.Chars.applyStance(player, p)
	end, 12, 14)
	Players.PlayerRemoving:Connect(function(p)
		W[p] = nil
	end)
end

return Combat

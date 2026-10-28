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
	local wg = s.inv.slots.primary
	local wit = wg and s.inv.items[wg]
	local wdef = wit and Weapons[Items.defs[wit.id].weapon]
	if not wdef then
		return reject("no weapon", player)
	end
	if t - w.last < (60 / wdef.rpm) * 0.8 then
		return reject("fire rate", player)
	end
	local mag = wit.mag and s.inv.items[wit.mag]
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
	mag.a -= 1
	Combat.stats.accepted += 1
	local res = workspace:Raycast(origin, dir * wdef.range, filter(char))
	local hitPos = res and res.Position or (origin + dir * wdef.range)
	local hit = false
	if res then
		local model = res.Instance:FindFirstAncestorOfClass("Model")
		local thum = model and model:FindFirstChildOfClass("Humanoid")
		if thum and thum.Health > 0 then
			local nm = res.Instance.Name
			local mult = (nm == "Head" and wdef.headMult) or (LIMB[nm] and wdef.limbMult) or 1
			local dist = (hitPos - origin).Magnitude
			local fall = 1
			if dist > wdef.falloffStart then
				fall = math.max(wdef.falloffMin, 1 - (dist - wdef.falloffStart) / (wdef.range - wdef.falloffStart) * (1 - wdef.falloffMin))
			end
			local killed = Combat.damage(model, thum, wdef.damage * mult * fall, player, origin)
			hit = true
			ctx.Remotes.note(player, "hit", { head = nm == "Head", kill = killed })
		end
	end
	ctx.AI.hearShot(origin, player)
	ctx.Remotes.fx("shot", { o = origin, p = hitPos, n = res and res.Normal or nil, h = hit }, player)
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
	local wg = s.inv.slots.primary
	local wit = wg and s.inv.items[wg]
	local wdef = wit and Weapons[Items.defs[wit.id].weapon]
	if not wdef then
		return
	end
	local cur = wit.mag and s.inv.items[wit.mag]
	local curA = cur and cur.a or 0
	local better = false
	for _, c in { "pockets", "bag" } do
		for g in s.inv[c] do
			local it = s.inv.items[g]
			if it.id == wdef.mag and (it.a or 0) > curA then
				better = true
			end
		end
	end
	if not better then
		ctx.Remotes.note(player, "reload", { state = "none" })
		return
	end
	local token = {}
	w.reloadToken = token
	w.reloadUntil = t + wdef.reload
	ctx.Remotes.note(player, "reload", { state = "start", t = wdef.reload })
	task.delay(wdef.reload, function()
		if W[player] ~= w or w.reloadToken ~= token then
			return
		end
		local s2 = ctx.Raid.session(player)
		if s2 ~= s or s.done or not alive(player) then
			return
		end
		local done, a = Inv.reload(s.inv)
		ctx.Remotes.note(player, "ammo", { a = done and a or curA })
		ctx.Raid.push(player)
	end)
end

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
		g = Inv.findKind(s.inv, "heal", { "pockets", "bag" })
	end
	local it = g and s.inv.items[g]
	local def = it and Items.defs[it.id]
	local loc = g and Inv.locate(s.inv, g)
	if not def or def.kind ~= "heal" or (loc ~= "pockets" and loc ~= "bag") then
		return ctx.Remotes.fail("NO_ITEM", "No dressing in pockets or pack.")
	end
	local token = {}
	w.healToken = token
	ctx.Remotes.note(player, "heal", { state = "start", t = 2.5 })
	task.delay(2.5, function()
		if w.healToken ~= token then
			return
		end
		w.healToken = nil
		local _, h2 = alive(player)
		if not h2 or ctx.Raid.session(player) ~= s or s.done or not s.inv.items[g] then
			return
		end
		Inv.consume(s.inv, g)
		h2.Health = math.min(h2.MaxHealth, h2.Health + def.heal)
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

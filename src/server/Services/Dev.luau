--!nonstrict
-- Studio-only test bridge: ServerStorage.ZR_Dev:Invoke(cmd, ...) drives full-loop tests via MCP execute_luau.
-- Never created on live servers.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Inv = require(script.Parent.Inv)

local Dev = {}
local ctx

local function plr(name)
	return (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
end

local function brief(h)
	local list = {}
	for g, it in h.items do
		local where, info = Inv.locate(h, g)
		if type(info) == "string" and #info > 12 then
			info = h.items[info] and h.items[info].id or info
		end
		table.insert(list, string.format("%s x%d%s @%s%s%s", it.id, it.n, it.a and ("(" .. it.a .. ")") or "", tostring(where), type(info) == "string" and (":" .. info) or "", it.fip and " FIP" or (it.fir and " FIR" or "")))
	end
	table.sort(list)
	return list
end

local C = {}

function C.state(name)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local s = ctx.Raid.session(p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return HttpService:JSONEncode({
		player = p.Name, rev = prof and prof.rev, money = prof and prof.money, pending = prof and prof.pendingRaid and prof.pendingRaid.id,
		stats = prof and prof.stats, profileItems = prof and brief(prof), invariant = prof and select(2, Inv.check(prof)) or "ok",
		raid = s and { id = s.id, state = s.state, left = math.floor(s.endsAt - workspace:GetServerTimeNow()), extracts = s.extracts, kills = s.kills, items = brief(s.inv), invariant = select(2, Inv.check(s.inv)) or "ok" } or nil,
		health = hum and hum.Health, pos = root and tostring(Vector3.new(math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z))),
		persistence = ctx.Store.mode, world = ctx.Raid.world.status,
	})
end

function C.deploy(name)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local res = ctx.Raid.deploy(p, { rev = prof.rev })
	task.wait(1.5)
	return HttpService:JSONEncode(res)
end

function C.tp(name, where)
	local p = plr(name)
	local char = p.Character
	local cf
	local lc = ctx.Loot.containers[where]
	if lc and lc.part then
		cf = lc.part.CFrame * CFrame.new(0, 2, -4)
	elseif ctx.World.extracts[where] then
		cf = CFrame.new(ctx.World.extracts[where].pos + Vector3.new(0, 3.5, 0))
	elseif where == "safehouse" then
		cf = ctx.World.safehouse.spawn
	elseif typeof(where) == "Vector3" then
		cf = CFrame.new(where)
	end
	if not cf or not char then
		return "no target"
	end
	char:PivotTo(cf)
	return "ok " .. tostring(cf.Position)
end

-- open a world container (teleporting next to it) and wait for the search to finish
function C.loot(name, cid)
	local p = plr(name)
	C.tp(name, cid)
	task.wait(0.3)
	ctx.Loot.open(p, cid)
	local c = ctx.Loot.containers[cid]
	local t0 = os.clock()
	while c and c.searching[p] and os.clock() - t0 < 20 do
		task.wait(0.2)
	end
	if not c then
		return "none"
	end
	local v = ctx.Loot.view(c, p)
	local list = {}
	for g, it in v.items do
		table.insert(list, it.id .. "x" .. it.n)
	end
	table.sort(list)
	return HttpService:JSONEncode({ searched = v.searched, items = list })
end

local function firstVisible(p, c)
	for g in c.holder.grids.main or {} do
		if ctx.Loot.visible(c, p, g) then
			return g
		end
	end
	return nil
end

function C.take(name, cid)
	local p = plr(name)
	local c = ctx.Loot.containers[cid]
	local g = c and firstVisible(p, c)
	if not g then
		return "nothing"
	end
	return HttpService:JSONEncode(ctx.Remotes.dispatch(p, "inv", { op = "quick", g = g, from = "c:" .. cid, to = "me", rid = "take" .. g }))
end

-- take the first visible item from any grid or slot of a container/body (bodies: slots first)
function C.takeAny(name, cid, slotFirst)
	local p = plr(name)
	local c = ctx.Loot.containers[cid]
	if not c then
		return "none"
	end
	local pick
	if slotFirst then
		for _, sg in c.holder.slots do
			pick = sg
			break
		end
	end
	if not pick then
		for _, pl in c.holder.grids do
			for g in pl do
				if ctx.Loot.visible(c, p, g) then
					pick = g
					break
				end
			end
			if pick then
				break
			end
		end
	end
	if not pick then
		return "nothing visible"
	end
	local id = c.holder.items[pick].id
	return id .. " " .. HttpService:JSONEncode(ctx.Remotes.dispatch(p, "inv", { op = "quick", g = pick, from = "c:" .. cid, to = "me", rid = "ta" .. pick }))
end

function C.bodies()
	local out = {}
	for cid, c in ctx.Loot.containers do
		if c.body then
			table.insert(out, cid)
		end
	end
	return table.concat(out, ",")
end

function C.takeTwice(name, cid)
	local p = plr(name)
	local c = ctx.Loot.containers[cid]
	local g = c and firstVisible(p, c)
	if not g then
		return "nothing"
	end
	local r1, r2
	task.spawn(function()
		r1 = ctx.Remotes.dispatch(p, "inv", { op = "quick", g = g, from = "c:" .. cid, to = "me", rid = "dupA" })
	end)
	task.spawn(function()
		r2 = ctx.Remotes.dispatch(p, "inv", { op = "quick", g = g, from = "c:" .. cid, to = "me", rid = "dupB" })
	end)
	task.wait(0.2)
	local copies = (ctx.Raid.session(p).inv.items[g] and 1 or 0) + (c.holder.items[g] and 1 or 0)
	return HttpService:JSONEncode({ r1 = r1, r2 = r2, copiesTotal = copies })
end

function C.kill(name)
	local p = plr(name)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	task.wait(0.5)
	return "killed"
end

function C.extract(name)
	local s = ctx.Raid.session(plr(name))
	if not s then
		return "not in raid"
	end
	C.tp(name, s.extracts[1])
	return "moved to " .. s.extracts[1]
end

function C.rejoin(name)
	local p = plr(name)
	if ctx.Raid.session(p) then
		ctx.Raid.finalize(p, "DISCONNECTED")
	end
	local prof, rec = ctx.Profiles.reload(p)
	ctx.Raid.push(p)
	return HttpService:JSONEncode({ loaded = prof ~= nil, recovered = rec ~= nil, items = prof and brief(prof) })
end

function C.expire(name)
	local s = ctx.Raid.session(plr(name))
	if not s then
		return "not in raid"
	end
	s.endsAt = workspace:GetServerTimeNow() - 1
	task.wait(1.5)
	return "expired"
end

function C.failWrites(n)
	ctx.Store.failNext = n or 1
	return "next writes fail: " .. tostring(ctx.Store.failNext)
end

function C.ai()
	local out = {}
	for _, g in ctx.AI.guards do
		table.insert(out, string.format("%s %s hp=%d pos=%s", g.name, g.state, g.hum and g.hum.Health or -1, g.root and tostring(Vector3.new(math.floor(g.root.Position.X), math.floor(g.root.Position.Y), math.floor(g.root.Position.Z))) or "?"))
	end
	return table.concat(out, " | ")
end

function C.tests()
	local folder = script.Parent.Parent:FindFirstChild("Tests")
	local report = {}
	for _, m in folder:GetChildren() do
		if m:IsA("ModuleScript") then
			local ok, res = pcall(function()
				return require(m).run(ctx)
			end)
			table.insert(report, m.Name .. ": " .. (ok and res or ("ERROR " .. tostring(res))))
		end
	end
	return table.concat(report, "\n")
end

function C.ignore(name, on)
	plr(name):SetAttribute("DevIgnore", on ~= false)
	return "DevIgnore=" .. tostring(on ~= false)
end

function C.recovery(name)
	return HttpService:JSONEncode(ctx.Raid.inv(plr(name), { op = "recovery" }))
end

-- route a crafted payload through the real request dispatcher (validation, rate limit, de-dupe)
function C.dispatch(name, action, payload)
	return HttpService:JSONEncode(ctx.Remotes.dispatch(plr(name), action, payload))
end

-- shot abuse: same-tick flood, replayed sequence, NaN direction, far origin, fake extra args
function C.shotAbuse(name)
	local p = plr(name)
	local s = ctx.Raid.session(p)
	local head = p.Character and p.Character:FindFirstChild("Head")
	if not s or not head then
		return "not in raid"
	end
	local before = ctx.Combat.stats.accepted
	local _, _, _, _, mag = ctx.Combat.activeWeapon(s)
	local ammo0 = mag and mag.a
	local dir = Vector3.new(0, 0, -1)
	for i = 1, 20 do
		ctx.Combat.shoot(p, 100000 + i, head.Position, dir)
	end
	local flood = ctx.Combat.stats.accepted - before
	task.wait(0.3)
	local b2 = ctx.Combat.stats.accepted
	ctx.Combat.shoot(p, 100000 + 5, head.Position, dir) -- replayed (old) sequence
	ctx.Combat.shoot(p, 200001, head.Position, Vector3.new(0 / 0, 0, -1)) -- NaN
	ctx.Combat.shoot(p, 200002, head.Position + Vector3.new(500, 0, 0), dir) -- origin far away -> clamped to head
	local after = ctx.Combat.stats.accepted - b2
	return HttpService:JSONEncode({ floodAccepted = flood, laterAccepted = after, ammoBefore = ammo0, ammoAfter = mag and mag.a })
end

-- crash mid-raid: stored copy must already hold the escrow (pendingRaid); reload settles it as DISCONNECTED
function C.crash(name)
	local p = plr(name)
	if not ctx.Raid.session(p) then
		return "not in raid"
	end
	local key = ctx.Profiles.key(p.UserId)
	local stored = ctx.Store.peek(key)
	local storedPending = stored ~= nil and stored.pendingRaid ~= nil
	ctx.Raid.dropForTest(p)
	ctx.Profiles.forgetForTest(p)
	local prof, rec = ctx.Profiles.load(p)
	ctx.Chars.spawn(p, ctx.Raid.safeSpawnCF(), nil)
	ctx.Raid.push(p)
	local after = ctx.Store.peek(key)
	return HttpService:JSONEncode({
		storedPendingBeforeCrash = storedPending, recovered = rec ~= nil, outcome = rec and rec.outcome, lost = rec and rec.lost and #rec.lost,
		pendingAfter = prof and prof.pendingRaid ~= nil, storedPendingAfter = after and after.pendingRaid ~= nil,
		invariant = prof and select(2, Inv.check(prof)) or "ok", items = prof and brief(prof),
	})
end

-- save retry: fail the next n writes, then do a critical save (4 attempts with backoff)
function C.saveRetry(name, n)
	local p = plr(name)
	ctx.Store.failNext = n or 2
	local t0 = os.clock()
	local ok, err = ctx.Profiles.save(p, true)
	local left = ctx.Store.failNext
	ctx.Store.failNext = 0
	return HttpService:JSONEncode({ failInjected = n or 2, ok = ok, err = err, unusedFailures = left, seconds = math.floor((os.clock() - t0) * 10) / 10 })
end

-- health: vitals snapshot
function C.hp(name)
	local p = plr(name)
	local hs = ctx.Health.of(p)
	if not hs then
		return "no health state"
	end
	local v = ctx.Health.vitals(hs)
	local parts = {}
	for _, k in ctx.Health.PARTS do
		local pp = v.parts[k]
		table.insert(parts, string.format("%s %d/%d%s%s", k, pp[1], pp[2], pp[3] == 2 and " HB" or (pp[3] == 1 and " LB" or ""), pp[4] and " FX" or ""))
	end
	local fx = {}
	for _, e in v.effects do
		table.insert(fx, e.label)
	end
	return string.format("%d/%d E%d W%d | %s | %s | speed %.2f sprint %s", math.ceil(v.hp), v.max, v.energy, v.water, table.concat(parts, ", "), table.concat(fx, ","), v.mods.speed, tostring(v.mods.sprint))
end

-- simulate an incoming round on a body part: shootMe(name, "UpperTorso", "A62_FMJ")
function C.shootMe(name, partName, ammoId)
	local p = plr(name)
	local char = p.Character
	local part = char and char:FindFirstChild(partName or "UpperTorso")
	local ad = Items.defs[ammoId or "A62_FMJ"]
	if not part or not ad or not ad.ammo then
		return "bad args"
	end
	local a = ad.ammo
	local res = ctx.Combat.hitModel(char, { dmg = a.dmg, pen = a.pen, armorDmg = a.armorDmg, bleedL = a.bleedL, bleedH = a.bleedH, part = part, hitPos = part.Position + Vector3.new(0, 0.3, 0.3), attacker = nil, from = part.Position + Vector3.new(0, 0, 40), weapon = "TEST", ammo = ad.name })
	if not res then
		return "no hit"
	end
	return string.format("part %s dmg %.1f pen %s armor %s ric %s killed %s", res.part, res.dmg, tostring(res.penetrated), tostring(res.armor), tostring(res.ricochet), tostring(res.killed))
end

function C.wound(name, kind, part)
	local hs = ctx.Health.of(plr(name))
	if not hs then
		return "none"
	end
	if kind == "light" then
		hs.bleedL[part or "larm"] = true
	elseif kind == "heavy" then
		hs.bleedH[part or "lleg"] = true
	elseif kind == "fracture" then
		hs.fract[part or "lleg"] = true
	end
	hs.dirty = true
	return "ok"
end

function C.shots()
	return HttpService:JSONEncode(ctx.Combat.stats)
end

function Dev.init(c)
	ctx = c
	if not RunService:IsStudio() then
		return
	end
	local old = ServerStorage:FindFirstChild("ZR_Dev")
	if old then
		old:Destroy()
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "ZR_Dev"
	bf.OnInvoke = function(cmd, a, b, d)
		local f = C[cmd]
		if not f then
			return "unknown cmd"
		end
		local ok, res = pcall(f, a, b, d)
		return ok and res or ("ERR " .. tostring(res))
	end
	bf.Parent = ServerStorage
end

return Dev

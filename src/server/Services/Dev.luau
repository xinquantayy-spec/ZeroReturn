--!nonstrict
-- Studio-only test bridge: ServerStorage.ZR_Dev:Invoke(cmd, ...) drives full-loop tests via MCP execute_luau.
-- Never created on live servers.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local WP = require(Shared.WeaponParts)
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
		persistence = ctx.Store.mode, world = ctx.Raid.world.status, match = ctx.Match.state,
		scav = s and s.scav or nil, claims = prof and #prof.claims, scavReadyIn = prof and math.max(0, (prof.scavReadyAt or 0) - os.time()),
	})
end

-- deploy through the real request path; if it queued, start the raid now (skips the matching countdown)
function C.deploy(name, kind, map)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local res = ctx.Remotes.dispatch(p, "deploy", { rev = prof.rev, kind = kind, rid = "dev" .. os.clock(), map = map })
	if res.ok and res.data and res.data.queued then
		ctx.Match.startsAt = workspace:GetServerTimeNow()
	end
	local t0 = os.clock()
	while res.ok and not ctx.Raid.session(p) and os.clock() - t0 < 8 do
		task.wait(0.2)
	end
	task.wait(1)
	return HttpService:JSONEncode({ res = res, inRaid = ctx.Raid.session(p) ~= nil, match = ctx.Match.state })
end

function C.match(name)
	local p = plr(name)
	local st = ctx.Match.status(p)
	st.now = workspace:GetServerTimeNow()
	st.extractOpen = ctx.Match.extractOpen
	st.raids = ctx.Match.raids
	st.endedReason = ctx.Match.endedReason
	return HttpService:JSONEncode(st)
end

function C.endRaid()
	ctx.Match.endRaid("DEV")
	return "ended"
end

-- keep a raid running with nobody inside (to inspect bodies after a death)
function C.hold(on)
	ctx.Match.holdOpen = on ~= false
	return "holdOpen=" .. tostring(ctx.Match.holdOpen)
end

-- override a session's extract list: setExtracts(name, "A,B")
function C.setExtracts(name, csv)
	local s = ctx.Raid.session(plr(name))
	if not s then
		return "not in raid"
	end
	s.extracts = string.split(csv, ",")
	ctx.Remotes.note(plr(name), "raid", ctx.Raid.raidInfo(s))
	return table.concat(s.extracts, ",")
end

-- every insurance claim becomes ready now (the delivery loop runs every 10 s)
function C.claimNow(name)
	local prof = ctx.Profiles.get(plr(name))
	for _, c in prof.claims do
		c.readyAt = 0
	end
	return #prof.claims .. " claim(s) ready"
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
	char:SetAttribute("TP", os.clock())
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

-- everything inside a world container or body (server truth, no search needed)
function C.contents(cid)
	local c = ctx.Loot.containers[cid]
	if not c then
		return "none"
	end
	local list = brief(c.holder)
	for g, it in c.holder.items do
		if it.tag then
			table.insert(list, "TAG " .. HttpService:JSONEncode(it.tag) .. " " .. g)
		end
	end
	return HttpService:JSONEncode(list)
end

-- loose loot lying in the raid world (M10): id, item, area, position
function C.loose(area)
	local out = {}
	for id, e in ctx.Loot.loose do
		if not area or e.area == area then
			local it = e.holder.items[e.g]
			local p = e.part.Position
			table.insert(out, string.format("%s %s %s (%d,%d,%d)", id, it and it.id or "?", tostring(e.area), p.X, p.Y, p.Z))
		end
	end
	table.sort(out)
	return #out .. " loose\n" .. table.concat(out, "\n")
end

-- walk up to a loose item and take it through the real pickup rules
function C.takeLoose(name, id)
	local p = plr(name)
	local e = ctx.Loot.loose[id]
	if not e then
		return "no such loose item"
	end
	p.Character:PivotTo(CFrame.new(e.part.Position + Vector3.new(0, 3, 2.5)))
	p.Character:SetAttribute("TP", os.clock())
	task.wait(0.2)
	return tostring(ctx.Loot.takeLoose(p, id))
end

-- door state: door(id) -> state; door(id, true/false) opens/closes (unlocks for the test)
function C.door(id, open)
	local d = ctx.World.doors[id]
	if not d then
		return "no door"
	end
	if open ~= nil then
		d.locked = false
		ctx.Doors.aiOpen(d)
		if open == false and d.open then
			d.open = false
			d.part.CFrame = d.cf
		end
	end
	return string.format("%s locked=%s open=%s passThrough=%s", id, tostring(d.locked), tostring(d.open), tostring(d.modifier and d.modifier.PassThrough))
end

-- M13 switches: switch(id, true|false) flips it now; switch(id) reports
function C.switch(id, on)
	if on ~= nil and not ctx.Doors.setSwitch(id, on) then
		return "no switch " .. tostring(id)
	end
	local sw = ctx.World.switches[id]
	return sw and string.format("%s on=%s pending=%s", id, tostring(sw.on), tostring(sw.pending)) or "no switch"
end

-- item guids of an id in the player's stash/profile (or raid kit when in raid)
function C.find(name, id)
	local p = plr(name)
	local h = ctx.Raid.holder(p)
	local out = {}
	for g, it in h and h.items or {} do
		if it.id == id then
			local where = Inv.locate(h, g)
			table.insert(out, { g = g, n = it.n, where = tostring(where), fir = it.fir or nil })
		end
	end
	return HttpService:JSONEncode(out)
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

-- the shared raid clock runs out (everyone inside goes MIA)
function C.expire()
	if ctx.Match.state ~= "RUNNING" then
		return "no raid"
	end
	ctx.Match.endsAt = workspace:GetServerTimeNow() - 1
	task.wait(1.6)
	return "expired"
end

function C.failWrites(n)
	ctx.Store.failNext = n or 1
	return "next writes fail: " .. tostring(ctx.Store.failNext)
end

function C.ai()
	local out = {}
	for _, u in ctx.AI.units do
		local p = u.root and u.root.Position
		local rounds = "-"
		if u.w and u.inv.items[u.w.g] then
			local it = u.inv.items[u.w.g]
			local m = it.mag and u.inv.items[it.mag] or it
			rounds = tostring(m.a or 0)
		end
		table.insert(out, string.format("%s[%s] %s hp=%d pos=%s w=%s(%s) tgt=%s cover=%s st=%s", u.name, u.faction, u.state, u.hum and math.floor(u.hum.Health) or -1,
			p and string.format("%d,%d,%d", p.X, p.Y, p.Z) or "?", u.w and u.w.def.id or "-", rounds, u.target and u.target.Name or "-", tostring(u.cover ~= nil), tostring(u.stance)))
	end
	return table.concat(out, "\n") .. string.format("\ncover points: %d (ready %s), waves %d, boss %s, grenades %s", ctx.AI.cover.n, tostring(ctx.AI.cover.ready), ctx.AI.director.waves, tostring(ctx.AI.bossThisRaid), HttpService:JSONEncode(ctx.AI.nadeStats or {}))
end

-- spawn an AI near a position: spawnAI("scav"|"watch"|"boss"|"follower", Vector3)
function C.spawnAI(kind, pos)
	local u = ctx.AI.spawn(kind, pos or Vector3.new(0, 0, 0))
	return u and u.name or "failed"
end

-- send an AI unit to a point (as if it heard something there): aiGoto("Scav_3", Vector3)
function C.aiGoto(unitName, pos)
	for _, u in ctx.AI.units do
		if u.name == unitName and u.alive then
			u.state = "INVESTIGATE"
			u.goal = pos
			u.searchUntil = os.clock() + 30
			u.alert = os.clock() + 30
			return "going"
		end
	end
	return "no unit"
end

-- put the player at a spot facing a direction: face(name, Vector3 pos, Vector3 lookAt)
function C.place(name, pos, lookAt)
	local char = plr(name).Character
	if not char then
		return "no char"
	end
	char:PivotTo(CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z)))
	char:SetAttribute("TP", os.clock())
	return "ok"
end

-- M11 part B: set the active gun's condition and/or give it a malfunction (misfire / eject / feed / jam)
function C.weaponState(name, wear, malf)
	local p = plr(name)
	local s = p and ctx.Raid.session(p)
	if not s then
		return "not in raid"
	end
	local _, wit = ctx.Combat.activeWeapon(s)
	if not wit then
		return "no weapon"
	end
	if type(wear) == "number" then
		wit.wear = wear
	end
	if type(malf) == "string" then
		wit.mf, wit.mfk, wit.mfh = malf, nil, nil
		ctx.Remotes.note(p, "malf", { state = "on" })
	end
	return string.format("wear %.1f/%.1f malf %s known %s", wit.wear or 100, wit.wmax or 100, tostring(wit.mf), tostring(wit.mfk))
end

-- M16 character / equipment checks (C01-C12 server side)
function C.chartests()
	local CT = require(script.Parent.Parent.Tests.CharTests)
	return (CT.run(ctx))
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

-- economy test helpers (M9)
function C.xp(name, n)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	ctx.Economy.addXp(prof, n or 1000)
	ctx.Raid.push(p)
	return "level " .. ctx.Economy.level(prof) .. " xp " .. prof.xp
end

-- flea market (Tarkov): age the player's offers by some minutes and let the market resolve them
function C.flea(name, minutes)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local f = prof and prof.flea
	if not f then
		return "no flea state"
	end
	local sec = (minutes or 10) * 60
	for _, o in f.offers do
		o.chk = (o.chk or o.t) - sec
		o.t -= sec
	end
	ctx.Flea.resolve(p, prof, os.time(), ctx.Raid.session(p) ~= nil)
	ctx.Raid.afterChange(p, false)
	local n = 0
	for _ in f.offers do
		n += 1
	end
	return string.format("rating %.4f offers %d money %d", f.rating or 0, n, prof.money)
end

function C.money(name, n)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	prof.money = n or prof.money
	ctx.Raid.afterChange(p, false)
	return prof.money
end

-- found-in-raid items straight into the stash (hand-in tests)
function C.fir(name, id, n)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	local out = {}
	for _ = 1, n or 1 do
		local g, it = Inv.newItem(id, 1)
		it.fir = true
		if Inv.place(prof, g, it, { "stash" }) then
			table.insert(out, g)
		end
	end
	ctx.Raid.afterChange(p, false)
	return #out .. " placed"
end

-- finish the running hideout build and crafts now
function C.hideoutNow(name)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	if prof.hideout.build then
		prof.hideout.build.at = 0
	end
	for _, c in prof.hideout.crafts do
		c.at = 0
	end
	ctx.Hideout.settle(prof, p)
	ctx.Raid.afterChange(p, false)
	return HttpService:JSONEncode(ctx.Hideout.stateFor(prof))
end

function C.econ(name)
	local p = plr(name)
	local prof = ctx.Profiles.get(p)
	return HttpService:JSONEncode({ econ = ctx.Economy.stateFor(prof), quests = ctx.Quests.stateFor(prof), hideout = ctx.Hideout.stateFor(prof), money = prof.money, stashH = prof.stashH })
end

-- raid time of day and weather (M10): env(hour, "clear"|"overcast"|"fog"|"rain", rain 0..1). Applies to the
-- running raid at once (the clock jumps to `hour`) and to the next ones; env() with no hour goes back to random.
function C.env(hour, weather, rain, season)
	if hour == nil then
		ctx.Match.forceEnv = nil
		return "random"
	end
	local e = { clock0 = hour % 24, w = weather or "clear", rain = rain or ((weather == "rain") and 1 or 0), season = season }
	ctx.Match.forceEnv = e
	if ctx.Match.state == "RUNNING" and ctx.Match.env then
		local t = workspace:GetServerTimeNow()
		local cur = ctx.Match.env
		cur.w, cur.rain = e.w, e.rain
		cur.season = season or cur.season
		cur.clock0 = (e.clock0 - (t - (cur.t0 or t)) * 7 / 3600) % 24
		for p, s in ctx.Raid.sessions() do
			if not s.done then
				ctx.Remotes.note(p, "raid", ctx.Raid.raidInfo(s))
			end
		end
	elseif ctx.Match.state == "MATCHING" then
		ctx.Match.nextEnv = table.clone(e)
	end
	return HttpService:JSONEncode(ctx.Match.env or e)
end

-- M13: force the next raids onto a map ("quay7", "smelter"), or back to the vote (nil)
function C.map(id)
	ctx.Match.forceMap = id
	return "forceMap=" .. tostring(id) .. " active=" .. tostring(ctx.World.activeMap)
end

-- force the Foreman on (true), off (false) or back to chance (nil) for the next raids
function C.boss(on)
	ctx.AI.forceBoss = on
	return "forceBoss=" .. tostring(on)
end

function C.god(name, on)
	plr(name):SetAttribute("DevGod", on ~= false)
	return "DevGod=" .. tostring(on ~= false)
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
	ctx.Chars.spawn(p, ctx.Raid.safeSpawnCF(p), nil)
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

-- spawn an item into the player's raid kit (rig/pockets/backpack), an empty equipment slot, or the stash;
-- extra = item fields, e.g. { preset = "R17_PATROL" } for a gun build or { bare = true } for a stripped base
function C.give(name, id, n, slot, extra)
	local p = plr(name)
	if not Items.defs[id] then
		return "unknown item " .. tostring(id)
	end
	local h, inRaid = ctx.Raid.holder(p)
	if not h then
		return "no holder"
	end
	local g, it = Inv.newItem(id, n or 1, extra)
	local okP, err
	if slot then
		okP, err = Inv.placeSlot(h, g, it, slot)
	else
		okP, err = Inv.place(h, g, it, inRaid and Inv.loadOrder(h) or { "stash" })
	end
	if not okP then
		return "ERR " .. tostring(err)
	end
	ctx.Raid.afterChange(p, inRaid)
	return g
end

-- grenades (M11) ────────────────────────────────────────────────────────────
-- drop a live grenade at pos with velocity vel (thrower = the player): nade(name, "GREN_RK5", pos, vel)
function C.nade(name, id, pos, vel)
	local p = plr(name)
	local n = ctx.Grenades.throwFrom(p, pos, vel or Vector3.zero, id or "GREN_RK5")
	if not n then
		return "failed"
	end
	local f = n.path.final
	return string.format("id %d end %.1f,%.1f,%.1f rest %s bounces %d samples %d endT %.2f", n.id, f.X, f.Y, f.Z, tostring(n.path.rest), #n.path.b, #n.path.t, n.path.endT)
end

-- the real pull -> throw path from the player's head: nadeThrow(name, under, Vector3 look?)
function C.nadeThrow(name, under, look)
	local p = plr(name)
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return "no char"
	end
	local dir = look or root.CFrame.LookVector
	local before = ctx.Grenades.stats.thrown
	ctx.Grenades._pull(p)
	if not ctx.Grenades.busy(p) then
		return "pull refused (no grenade in rig/pockets?)"
	end
	task.wait(0.45)
	ctx.Grenades._throw(p, { x = dir.X, y = dir.Y, z = dir.Z, u = under == true })
	task.wait(0.1)
	local n = ctx.Grenades.live[ctx.Grenades.stats.thrown > before and (function()
		local best = nil
		for id in ctx.Grenades.live do
			best = math.max(best or 0, id)
		end
		return best
	end)() or -1]
	if not n then
		return "thrown " .. tostring(ctx.Grenades.stats.thrown - before)
	end
	local f, o = n.path.final, n.path.p[1]
	return string.format("thrown %s from %.1f,%.1f,%.1f to %.1f,%.1f,%.1f (%.1f studs) rest %s bounces %d", n.item, o.X, o.Y, o.Z, f.X, f.Y, f.Z, (f - o).Magnitude, tostring(n.path.rest), #n.path.b)
end

-- give an AI unit an item (rig/pockets first): aiGive("Scav_3", "GREN_RK5")
function C.aiGive(unitName, id)
	for _, u in ctx.AI.units do
		if u.name == unitName then
			local g, it = Inv.newItem(id, 1)
			local okP = Inv.place(u.inv, g, it, Inv.loadOrder(u.inv))
			return okP and g or "no space"
		end
	end
	return "no unit"
end

-- make a unit throw a grenade at a point now: aiThrow("Watch_2", Vector3)
function C.aiThrow(unitName, target)
	for _, u in ctx.AI.units do
		if u.name == unitName and u.alive then
			return tostring(ctx.AI.devThrow(u, target))
		end
	end
	return "no unit"
end

-- AI grenade drill: stand where an AI (kind, default the Foreman) sees you, then hide behind full cover and
-- report the AI's grenade decisions: nadeDrill(name, kind, seconds)
function C.nadeDrill(name, kind, seconds)
	local p = plr(name)
	local char = p.Character
	if not char or not ctx.Raid.session(p) then
		return "not in raid"
	end
	local wp = RaycastParams.new()
	wp.FilterType = Enum.RaycastFilterType.Include
	wp.FilterDescendantsInstances = { workspace.ZR_World, workspace.Terrain }
	local function dry(pos)
		local r = workspace:Raycast(pos + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), wp)
		return r ~= nil and r.Material ~= Enum.Material.Water and math.abs(r.Position.Y - pos.Y) < 0.6 and r.Normal.Y > 0.8
	end
	local function clear(a, b)
		return workspace:Raycast(a, b - a, wp) == nil
	end
	local found
	for _, list in ctx.AI.cover.cells do
		for _, c in list do
			if c.full and dry(c.pos) and c.pos.Y > -1 and c.pos.Y < 2 then
				for _, d in c.dirs do
					local B = c.pos + d * 26
					local side = Vector3.new(-d.Z, 0, d.X)
					local O = c.pos + side * 7
					if dry(B) and dry(O) and not clear(B + Vector3.new(0, 5, 0), c.pos + Vector3.new(0, 4, 0))
						and clear(B + Vector3.new(0, 5, 0), O + Vector3.new(0, 4, 0)) and clear(c.pos + Vector3.new(0, 2, 0), O + Vector3.new(0, 2, 0)) then
						found = { H = c.pos, B = B, O = O }
						break
					end
				end
			end
			if found then
				break
			end
		end
		if found then
			break
		end
	end
	if not found then
		return "no drill spot"
	end
	local stats0 = HttpService:JSONEncode(ctx.AI.nadeStats)
	char:PivotTo(CFrame.new(found.O + Vector3.new(0, 3.3, 0)))
	char:SetAttribute("TP", os.clock())
	local u = ctx.AI.spawn(kind or "boss", found.B, {})
	if not u then
		return "spawn failed"
	end
	task.wait(1)
	-- it has spotted us (awareness builds randomly; the drill is about what happens next)
	local tor = char:FindFirstChild("UpperTorso")
	u.aware[char] = 1.4
	u.seen[char] = os.clock()
	u.lastPos[char] = tor and tor.Position or found.O
	u.target = char
	u.state = "ENGAGE"
	u.spottedAt = os.clock()
	task.wait(4)
	local engaged = u.state
	char:PivotTo(CFrame.new(found.H + Vector3.new(0, 3.3, 0)))
	char:SetAttribute("TP", os.clock())
	local thrown0 = ctx.Grenades.stats.thrown
	local log = {}
	for i = 1, seconds or 20 do
		task.wait(1)
		table.insert(log, string.format("%d:%s/%d", i, u.state, ctx.Grenades.stats.thrown - thrown0))
	end
	return HttpService:JSONEncode({ spot = { H = tostring(found.H), B = tostring(found.B) }, engagedAfter5s = engaged, log = table.concat(log, " "), before = stats0, after = ctx.AI.nadeStats })
end

-- can a game script create a MaterialVariant with texture maps at runtime? (M12 material pipeline probe)
function C.mvProbe(id)
	local ok, err = pcall(function()
		local mv = Instance.new("MaterialVariant")
		mv.Name = "ZR_Probe"
		mv.BaseMaterial = Enum.Material.Concrete
		mv.ColorMap = id or "rbxassetid://111813157927046"
		mv.StudsPerTile = 8
		mv.Parent = game:GetService("MaterialService")
	end)
	return "runtime MaterialVariant: ok=" .. tostring(ok) .. " " .. tostring(err)
end

function C.nades()
	local out = { stats = ctx.Grenades.stats, live = {}, smokes = {} }
	for id, n in ctx.Grenades.live do
		table.insert(out.live, { id = id, item = n.item, left = math.floor((n.at - os.clock()) * 10) / 10 })
	end
	for _, sm in ctx.Grenades.smokes do
		table.insert(out.smokes, { age = math.floor(os.clock() - sm.t0), pos = tostring(sm.pos) })
	end
	return HttpService:JSONEncode(out)
end

-- active weapon summary (server truth) + third-person visuals
function C.weapon(name)
	local p = plr(name)
	local s = ctx.Raid.session(p)
	if not s then
		return "not in raid"
	end
	local wg, wit, wdef, wd, rounds = ctx.Combat.activeWeapon(s)
	local mods = {}
	if wg then
		WP.walk(s.inv.items, wg, function(_, it, _, sname)
			if sname then
				mods[sname] = it.id
			end
		end)
	end
	local char = p.Character
	local tp, sling, light = 0, 0, nil
	for _, c in char and char:GetChildren() or {} do
		if c.Name == "TPWeapon" then
			tp += 1
			light = light or (c:FindFirstChild("WeaponLight") and c.WeaponLight.Enabled)
		elseif c.Name == "TPSling" then
			sling += 1
		end
	end
	return HttpService:JSONEncode({
		active = s.active, g = wg, id = wit and wit.id, weapon = wdef and wdef.id, rounds = rounds and rounds.a, ammo = rounds and rounds.at,
		mods = mods, ms = wg and Inv.modStats(s.inv, wg), tpParts = tp, slingParts = sling, light = light,
		lightAttr = char and char:GetAttribute("WeaponLight"), activeAttr = char and char:GetAttribute("ActiveWeapon"), kind = wd and wd.kind,
	})
end

-- ── M16 character showroom ───────────────────────────────────────────────────
-- A neutral grey stage away from the map with dummies built and dressed through the real rig/appearance path.
-- list = { { name, kind (look) | preset ("operator", "scavenger", "guard", "bodyguard", "foreman"), seed (AI kit
-- seed), variant, gear = { [slot] = "ITEM" | "ITEM:tint" } (explicit kit, overrides the preset's), x, z, yaw (deg,
-- 180 = facing the stage front), stance, aim, sprint, speed (treadmill velocity for walk/sprint cycles), pitch,
-- depth, active (slot in hands) } }
local RigSpec = require(Shared.RigSpec)
local Equipment = require(Shared.Equipment)
local showKits = setmetatable({}, { __mode = "k" }) -- showroom dummy -> its kit holder
local SHOW_ORIGIN = Vector3.new(0, 0, 1100)
local function kitHolder(gear)
	local h = { slots = {}, items = {}, grids = {} }
	local n = 0
	for slot, spec in gear or {} do
		local id, tint = string.match(spec, "^([%w_]+):?(%w*)$")
		if id and Items.defs[id] then
			n += 1
			h.items["sg" .. n] = { id = id, tint = (tint ~= "" and tint) or nil }
			h.slots[slot] = "sg" .. n
		end
	end
	return h
end
C.kitHolder = kitHolder
function C.showroom(list)
	local folder = workspace:FindFirstChild("ZR_Showroom")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ZR_Showroom"
	local stage = Instance.new("Model")
	stage.Name = "Stage"
	for _, s in {
		{ Vector3.new(140, 1, 70), Vector3.new(0, -0.5, 0), Color3.fromRGB(148, 150, 152) },
		{ Vector3.new(140, 40, 1), Vector3.new(0, 20, 26), Color3.fromRGB(166, 168, 171) },
	} do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = s[1]
		p.CFrame = CFrame.new(SHOW_ORIGIN + s[2])
		p.Color = s[3]
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = stage
	end
	stage.Parent = folder
	folder.Parent = workspace
	local names = {}
	for i, d in list or {} do
		local preset = d.preset and Equipment.PRESETS[d.preset]
		local kind = d.kind or (preset and preset.look) or "player"
		local variant = d.variant or 1
		local h
		if d.gear then
			h = kitHolder(d.gear)
		elseif preset and preset.ai then
			h = ctx.AI.loadoutFor(preset.ai, Random.new(d.seed or i))
		elseif preset and preset.kit then
			h = kitHolder(preset.kit)
		else
			h = kitHolder({})
		end
		local rig = ctx.Chars.buildRig(kind, variant)
		rig.Name = d.name or ("Dummy" .. i)
		-- the root sits lower when crouched / prone (the anchored dummy has no Humanoid hip height to do it)
		local RigMath = require(Shared.RigMath)
		local drop = RigMath.STAND_HIP - RigMath.hipFor(d.stance or "s", d.depth or 0.7)
		local cf = CFrame.new(SHOW_ORIGIN + Vector3.new(d.x or (i - 1) * 6, RigSpec.hrp.center.Y - drop, d.z or 0)) * CFrame.Angles(0, math.rad(d.yaw or 180), 0)
		rig:PivotTo(cf)
		rig.HumanoidRootPart.Anchored = true
		rig:SetAttribute("Stance", d.stance or "s")
		rig:SetAttribute("Depth", d.depth or 0.7)
		rig:SetAttribute("Aim", d.aim == true)
		rig:SetAttribute("Sprint", d.sprint == true)
		rig:SetAttribute("Pitch", d.pitch or 0)
		rig:SetAttribute("Showroom", true)
		rig:SetAttribute("Preset", d.preset)
		rig.Parent = folder
		-- active = slot in the hands ("none": long guns slung, hands empty)
		local gear = ctx.Chars.gearOf(h, d.active or "primary")
		local activeG = (d.active ~= "none") and gear and gear.activeG or nil
		ctx.Appearance.apply(rig, { look = kind, variant = variant, holder = h, active = activeG })
		showKits[rig] = h
		if d.speed then
			rig.HumanoidRootPart.AssemblyLinearVelocity = cf.LookVector * d.speed
		end
		ctx.Chars.pose(rig)
		table.insert(names, rig.Name)
	end
	return table.concat(names, ",")
end

-- what a showroom dummy (or a player's character) visibly wears: group -> mesh keys, plus revision and kit
function C.appearance(name)
	local folder = workspace:FindFirstChild("ZR_Showroom")
	local m = (folder and folder:FindFirstChild(name)) or (Players:FindFirstChild(name) and Players[name].Character)
	if not m then
		return "no model " .. tostring(name)
	end
	local parts = {}
	for g, keys in ctx.Appearance.describe(m) do
		table.insert(parts, g .. "=" .. table.concat(keys, "+"))
	end
	table.sort(parts)
	local gear = {}
	for _, slot in Equipment.VISUAL_SLOTS do
		local id = m:GetAttribute("Gear_" .. slot)
		if id then
			table.insert(gear, slot .. ":" .. id)
		end
	end
	return string.format("%s rev=%s look=%s/%s gear={%s} pieces={%s}", m.Name, tostring(m:GetAttribute("AppearanceRev")), tostring(m:GetAttribute("Look")),
		tostring(m:GetAttribute("LookVariant")), table.concat(gear, ","), table.concat(parts, "; "))
end

-- equip / unequip on a showroom dummy through Inv (the same rules as players), then re-apply its appearance
function C.showEquip(name, slot, spec)
	local folder = workspace:FindFirstChild("ZR_Showroom")
	local m = folder and folder:FindFirstChild(name)
	local h = m and showKits[m]
	if not h then
		return "no dummy " .. tostring(name)
	end
	local cur = h.slots[slot]
	if cur then
		h.slots[slot] = nil
		h.items[cur] = nil
		h.erev = (h.erev or 0) + 1
	end
	if spec and spec ~= "" then
		local id, tint = string.match(spec, "^([%w_]+):?(%w*)$")
		if not (id and Items.defs[id]) then
			return "bad item " .. tostring(spec)
		end
		local g, it = ctx.Inv.newItem(id, 1, (tint ~= "" and { tint = tint }) or nil)
		local ok, err = ctx.Inv.placeSlot(h, g, it, slot)
		if not ok then
			ctx.Appearance.apply(m, { holder = h, keepWeapons = true })
			return "refused " .. tostring(err)
		end
	end
	ctx.Appearance.apply(m, { holder = h, keepWeapons = true })
	return C.appearance(name)
end

function C.showroomClear()
	local folder = workspace:FindFirstChild("ZR_Showroom")
	if folder then
		folder:Destroy()
	end
	return "cleared"
end

-- teleport the player to the showroom stage (the client's orbit camera follows dummies by name)
function C.showroomGo(name)
	local p = plr(name)
	if p.Character then
		p.Character:PivotTo(CFrame.new(SHOW_ORIGIN + Vector3.new(0, RigSpec.hrp.center.Y, -14)))
		p.Character:SetAttribute("TP", os.clock())
	end
	return "ok"
end

-- BENCHMARK (Studio only): set workspace attribute ZR_Bench to a map id in Edit mode, then start a test (Play, or Test ->
-- Clients and Servers for a client in its own process). The first player is put in a raid on that map and walked through
-- fixed viewpoints; the client holds each view, counts frames and shows the table on screen (Bench in Main.client).
local BENCH = {
	meridian = {
		{ "KASSA aisles", Vector3.new(630, 22, 8780), Vector3.new(630, 28, 8780), Vector3.new(665, 17, 8890) },
		{ "L2 gallery", Vector3.new(335, 51, 8826), Vector3.new(338, 56, 8828), Vector3.new(220, 47, 8860) },
		{ "Car park", Vector3.new(160, 4, 8530), Vector3.new(162, 8, 8532), Vector3.new(300, 2, 8620) },
		{ "Outside east", Vector3.new(935, 8, 9041), Vector3.new(940, 14, 9046), Vector3.new(600, 20, 8900) },
	},
	border = {
		{ "Bastion roof", Vector3.new(-165, 31, -5555), Vector3.new(-160, 36, -5550), Vector3.new(450, 5, -5000) },
		{ "Red Stores yard", Vector3.new(1060, 15, -5260), Vector3.new(1060, 20, -5260), Vector3.new(1163, 10, -5473) },
	},
}

local function bench(p, mapId)
	local views = BENCH[mapId]
	if not views then
		warn("[ZR] bench: no viewpoints for " .. tostring(mapId))
		return
	end
	local t0 = os.clock()
	while not (p.Character and p.Character:FindFirstChild("HumanoidRootPart")) and os.clock() - t0 < 60 do
		task.wait(0.5)
	end
	task.wait(3)
	C.map(mapId)
	C.god(p.Name, true)
	C.deploy(p.Name, "pmc", mapId)
	C.env(13, "clear", 0, "autumn")
	pcall(C.switch, "MALL_POWER", true)
	print("[ZR] bench: " .. mapId .. ", " .. #views .. " views")
	for i, v in views do
		C.tp(p.Name, v[2])
		p:SetAttribute("ZR_BenchView", string.format("%d|%d|%s|%.1f,%.1f,%.1f|%.1f,%.1f,%.1f", i, #views, v[1], v[3].X, v[3].Y, v[3].Z, v[4].X, v[4].Y, v[4].Z))
		task.wait(11) -- the client lets the view stream in for 4 s, then counts frames for 6 s
	end
	p:SetAttribute("ZR_BenchView", "done")
end

function Dev.init(c)
	ctx = c
	if not RunService:IsStudio() then
		return
	end
	local benchMap = workspace:GetAttribute("ZR_Bench")
	if type(benchMap) == "string" and benchMap ~= "" then
		game:GetService("Players").PlayerAdded:Connect(function(p)
			task.spawn(bench, p, benchMap)
		end)
	end
	local old = ServerStorage:FindFirstChild("ZR_Dev")
	if old then
		old:Destroy()
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "ZR_Dev"
	bf.OnInvoke = function(cmd, ...)
		local f = C[cmd]
		if not f then
			return "unknown cmd"
		end
		local ok, res = pcall(f, ...)
		return ok and res or ("ERR " .. tostring(res))
	end
	bf.Parent = ServerStorage
end

return Dev

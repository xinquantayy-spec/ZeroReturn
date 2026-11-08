--!nonstrict
-- Task checks for decision economy-6a, "map-first core, about 120" (docs/audit/2026-11-07/economy.md, decision economy-6):
-- the task list (shared/QuestData.luau), its loyalty-level groups and standings (shared/TraderData.luau), every objective
-- type's rules and the operational tasks (server/Services/Quests.luau). Run with the other test modules via ZR_Dev
-- "tests"; ctx is the server's service table. Pure checks call the shared modules; the rest use stand-in profiles and
-- stand-in raid sessions, never a real player's. A task place that the coordinator has not placed yet in a built map
-- (QuestData.NEW_ZONES) is listed in the notes as pending, not failed.
local Services = script.Parent.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local WP = require(Shared.WeaponParts)
local P = require(Shared.Progress)
local TD = require(Shared.TraderData)
local QD = require(Shared.QuestData)
local Maps = require(Shared.Maps)
local Settle = require(Services.Settle)
local Inv = require(Services.Inv)

local T = {}

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local SEVEN = { "vos", "hale", "rook", "dekker", "kovac", "tilda", "bram" }
local KINDS = { kill = true, handin = true, extract = true, visit = true, plant = true, mark = true, find = true, build = true }
local TARGETS = { scav = true, watch = true, pmc = true, boss = true, follower = true, any = true }
local CLASSES = { rifle = true, smg = true, shotgun = true, bolt = true, pistol = true, melee = true, grenade = true }
local PARTS = { head = true, thorax = true, stomach = true, arms = true, legs = true }

local function each(v, fn)
	if type(v) == "table" then
		for _, x in v do
			fn(x)
		end
	elseif v ~= nil then
		fn(v)
	end
end

-- a build from a trader preset's tree (as the traders sell it), with parts swapped or added: items, root guid
local function buildFrom(ref)
	local pr = WP.META.presets[ref.preset]
	if not pr then
		return nil, nil
	end
	local items, n = {}, 0
	local function add(t)
		n += 1
		local g = "t" .. n
		local it = { id = (ref.swap and ref.swap[t[1]]) or t[1], n = 1 }
		items[g] = it
		for sname, sub in t[2] do
			local cg = add(sub)
			if sname == "mag" then
				it.mag = cg
			else
				it.mods = it.mods or {}
				it.mods[sname] = cg
			end
		end
		return g
	end
	local root = add(pr.tree)
	for _, a in ref.add or {} do
		for _, it in items do
			if it.id == a[1] then
				n += 1
				local pg = "t" .. n
				items[pg] = { id = a[3], n = 1 }
				it.mods = it.mods or {}
				it.mods[a[2]] = pg
				break
			end
		end
	end
	return items, root
end

-- the first tasks of each loyalty-level group: those whose task before it is not the same trader's, of the same level
local function firstBatch(tid, k)
	local out = {}
	for _, q in QD.list do
		if q.trader == tid and (q.tl or 1) == k then
			local a = q.after and QD.byId[q.after]
			if not (a and a.trader == tid and (a.tl or 1) == k) then
				table.insert(out, q)
			end
		end
	end
	return out
end

function T.run(ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end
	local function listed(bad)
		return #bad == 0 and "" or (": " .. table.concat(bad, ", "))
	end

	-- ── the list ─────────────────────────────────────────────────────────────────────────────────────────────────
	local per = {}
	do
		local seen, dup = {}, {}
		for _, q in QD.list do
			if seen[q.id] then
				table.insert(dup, q.id)
			end
			seen[q.id] = true
			per[q.trader] = (per[q.trader] or 0) + 1
		end
		check("about 120 tasks (decision economy-6a), each id once" .. listed(dup), #QD.list >= 100 and #QD.list <= 140 and #dup == 0)
		local badTrader = {}
		for _, q in QD.list do
			if not TD.defs[q.trader] then
				table.insert(badTrader, q.id)
			end
		end
		local few = {}
		for _, tid in SEVEN do
			if (per[tid] or 0) < 12 then
				table.insert(few, tid .. "=" .. tostring(per[tid]))
			end
		end
		check("every task's trader exists, and each of the seven gives 12 or more (EFT: 52 to 91 each)" .. listed(badTrader) .. listed(few),
			#badTrader == 0 and #few == 0 and (per.fence or 0) >= 4)
		local badChain = {}
		for _, q in QD.list do
			for _, id in { q.after } do
				if id and not QD.byId[id] then
					table.insert(badChain, q.id .. "->" .. id)
				end
			end
			for _, id in q.needs or {} do
				if not QD.byId[id] then
					table.insert(badChain, q.id .. "->" .. id)
				end
			end
		end
		check("every chain points at real tasks" .. listed(badChain), #badChain == 0)
	end

	-- ── what the objectives name ─────────────────────────────────────────────────────────────────────────────────
	local pending = {}
	do
		local badItem, badMap, badZone, badKill, badText = {}, {}, {}, {}, {}
		local sold = {}
		for _, list in TD.offers do
			for _, o in list do
				sold[o.id] = true
			end
		end
		local function item(q, id, kind)
			local d = id and Items.defs[id]
			if not d then
				table.insert(badItem, q.id .. ":" .. tostring(id))
			elseif kind == "find" and d.kind ~= "quest" then
				table.insert(badItem, q.id .. ":" .. id .. " (not a quest item)")
			elseif (kind == "plant" or kind == "mark") and not sold[id] then
				table.insert(badItem, q.id .. ":" .. id .. " (nobody sells it)")
			end
		end
		for _, q in QD.list do
			for _, e in (q.reward and q.reward.items) or {} do
				item(q, e[1], "reward")
			end
			for tid in (q.reward and q.reward.reps) or {} do
				if not TD.defs[tid] then
					table.insert(badItem, q.id .. ": reps " .. tid)
				end
			end
			for _, o in q.obj do
				if not KINDS[o.kind] or (o.n or 0) < 1 then
					table.insert(badKill, q.id .. ": kind " .. tostring(o.kind))
				end
				if o.map and not Maps.defs[o.map] then
					table.insert(badMap, q.id .. ":" .. o.map)
				end
				if o.kind == "handin" or o.kind == "plant" or o.kind == "mark" or o.kind == "find" then
					item(q, o.item, o.kind)
				elseif o.kind == "build" then
					local d = Items.defs[o.base]
					if not (d and d.weapon and WP.BASES[o.base]) then
						table.insert(badItem, q.id .. ": build base " .. tostring(o.base))
					end
				end
				if o.kind == "find" then
					-- EFT: "Locate and obtain", then "Hand over" the same item
					local handed = false
					for _, o2 in q.obj do
						handed = handed or (o2.kind == "handin" and o2.item == o.item)
					end
					if not handed then
						table.insert(badItem, q.id .. ": " .. o.item .. " found but never handed over")
					end
				end
				if o.zone then
					local zoneMap = o.map
					if not QD.ZONE_NAMES[o.zone] or not zoneMap then
						table.insert(badZone, q.id .. ":" .. o.zone)
					else
						-- built here: it must exist; not built here or not placed yet: pending if requested
						local m = ctx and ctx.World and ctx.World.maps and ctx.World.maps[zoneMap]
						local there = m and m.visitZones and m.visitZones[o.zone]
						local req = QD.NEW_ZONES[o.zone]
						if not there then
							if req and req.map == zoneMap then
								if m and not table.find(pending, zoneMap .. ":" .. o.zone) then
									table.insert(pending, zoneMap .. ":" .. o.zone)
								end
							elseif m then
								table.insert(badZone, q.id .. ":" .. o.zone .. " missing on " .. zoneMap)
							end
						end
					end
				end
				if o.kind == "kill" then
					local ok = TARGETS[o.target] == true
					each(o.weapon, function(c)
						ok = ok and CLASSES[c] == true
					end)
					each(o.part, function(p)
						ok = ok and PARTS[p] == true
					end)
					each(o.gun, function(g)
						ok = ok and Items.defs[g] ~= nil
					end)
					each(o.boss or o.label, function(l)
						ok = ok and QD.BOSS_NAMES[l] ~= nil
					end)
					if o.time then
						ok = ok and #o.time == 2 and o.time[1] >= 0 and o.time[1] < 24 and o.time[2] >= 0 and o.time[2] < 24
					end
					if o.wear then
						ok = ok and Items.defs[o.wear] ~= nil
					end
					if not ok then
						table.insert(badKill, q.id)
					end
				end
				local txt = QD.describe(o)
				if type(txt) ~= "string" or txt == "?" or #txt < 6 then
					table.insert(badText, q.id)
				end
			end
		end
		check("every item a task names exists: hand-ins, quest items (kind quest), what you plant or mark (on sale somewhere), rewards" .. listed(badItem), #badItem == 0)
		check("every map a task names exists" .. listed(badMap), #badMap == 0)
		check("every place a task names has a name and a map, and stands in its built map or waits in the coordinator's list (QuestData.NEW_ZONES)" .. listed(badZone), #badZone == 0)
		check("kill objectives use known targets, weapon classes, body parts, guns, bosses and hours" .. listed(badKill), #badKill == 0)
		check("every objective reads as text (the boss task still reads 'Eliminate the Foreman')" .. listed(badText),
			#badText == 0 and QD.describe(QD.byId.T4.obj[1]) == "Eliminate the Foreman")
		local badNew = {}
		for id, z in QD.NEW_ZONES do
			if not (Maps.defs[z.map] and type(z.r) == "number" and z.r > 0 and QD.ZONE_NAMES[id]) then
				table.insert(badNew, id)
			end
		end
		check("the requested places each name a map, a radius and a UI name" .. listed(badNew), #badNew == 0)
	end
	if #pending > 0 then
		table.insert(notes, "PENDING places (coordinator's REQUEST, not placed yet): " .. table.concat(pending, ", "))
	end

	-- ── gunsmith builds ──────────────────────────────────────────────────────────────────────────────────────────
	do
		local bad, n = {}, 0
		for _, q in QD.list do
			for _, o in q.obj do
				if o.kind == "build" then
					n += 1
					local items, g = buildFrom(o.ref or {})
					local ok, miss = false, { "no reference build" }
					if items then
						ok, miss = QD.buildMatches(o, items, g)
					end
					local plainItems, pg = buildFrom({ preset = o.base })
					local plain = plainItems and QD.buildMatches(o, plainItems, pg)
					if not ok or plain then
						table.insert(bad, q.id .. (ok and " (the plain gun passes)" or (" misses " .. table.concat(miss, "/"))))
					end
				end
			end
		end
		check("gunsmith tasks (EFT's Gunsmith): " .. n .. " specifications, each met by a build from traders' parts and not by the plain gun" .. listed(bad), n >= 5 and #bad == 0)
		local items, g = buildFrom({ preset = "R17_DMR" })
		local f = items and QD.buildFigures(items, g)
		check("build figures read a preset: the marksman R-17 has a 6x scope, forty rounds, no suppressor",
			f ~= nil and f.zoom == 6 and f.cap == 40 and f.suppressed == false and f.ergo > 0 and f.recoil > 0)
	end

	-- ── standings and loyalty-level groups (EFT 1.1.0) ───────────────────────────────────────────────────────────
	local function down2(x)
		return math.floor(x * 100 + 1e-6) / 100
	end
	do
		local short, notEft = {}, {}
		for _, tid in SEVEN do
			local eft = TD.EFT_LL[tid]
			if (TD.TASK_REP[tid] or 0) + 1e-6 < eft[3][2] then
				table.insert(short, tid)
			end
			for k = 2, 4 do
				local req = TD.loyaltyReq(tid, k)
				if not (req and near(req.rep, down2(eft[k - 1][2]), 1e-9)) then
					table.insert(notEft, tid .. " LL" .. k)
				end
			end
		end
		check("every trader's tasks give at least EFT 1.1.0's LL4 standing" .. listed(short), #short == 0)
		check("so the loyalty table asks EFT's own standings (VOS 0.7 / 2.7 / 7.9 ...), unscaled" .. listed(notEft), #notEft == 0)
		-- the standing of LL k's tasks and below (a task's cost to another trader counts in its own group)
		local groupShort = {}
		for _, tid in SEVEN do
			local sum = { 0, 0, 0, 0 }
			for _, q in QD.list do
				local k = q.tl or 1
				if q.trader == tid and q.reward and q.reward.rep then
					sum[k] += q.reward.rep
				end
				local other = q.reward and q.reward.reps and q.reward.reps[tid]
				if other then
					sum[k] += other
				end
			end
			local cum = 0
			for k = 1, 3 do
				cum += sum[k]
				if cum + 1e-6 < TD.loyaltyReq(tid, k + 1).rep then
					table.insert(groupShort, tid .. " LL" .. (k + 1))
				end
			end
		end
		check("each group reaches the next level: LL1's tasks give LL2's standing, LL1-2 LL3's, LL1-3 LL4's" .. listed(groupShort), #groupShort == 0)
		local badBatch = {}
		for _, tid in SEVEN do
			for k = 1, 4 do
				local n = #firstBatch(tid, k)
				if n < 2 or n > 4 then
					table.insert(badBatch, tid .. " LL" .. k .. "=" .. n)
				end
			end
		end
		check("at each loyalty level 2 to 4 of the trader's tasks open at once, the rest follow them (EFT 1.1.0)" .. listed(badBatch), #badBatch == 0)
	end

	-- ── task-locked offers ───────────────────────────────────────────────────────────────────────────────────────
	do
		local bad, nLocked = {}, 0
		for tid, list in TD.offers do
			for i, o in list do
				for _, id in { o.task } do
					if id and not QD.byId[id] then
						table.insert(bad, tid .. "[" .. i .. "] " .. id)
					end
				end
				for _, id in o.start or {} do
					if not QD.byId[id] then
						table.insert(bad, tid .. "[" .. i .. "] " .. id)
					end
				end
				if o.task or o.start then
					nLocked += 1
				end
			end
		end
		check("task-locked offers (EFT: a task 'unlocks purchase of X'): " .. nLocked .. ", each naming a real task" .. listed(bad), nLocked >= 10 and #bad == 0)
		local ks
		for _, o in TD.offers.vos do
			if o.id == "KST_RIFLE" and o.task == "V10" then
				ks = o
			end
		end
		local mk
		for _, o in TD.offers.vos do
			if o.id == "MARKER" then
				mk = o
			end
		end
		local l0 = ks and TD.offerLock(ks, 1, {})
		local l1 = ks and TD.offerLock(ks, 1, { V10 = { s = "claimed" } })
		local l2 = ks and TD.offerLock(ks, 1, { V10 = { s = "active" } })
		local m0 = mk and TD.offerLock(mk, 1, {})
		local m1 = mk and TD.offerLock(mk, 1, { R8 = { s = "active" } })
		local unl = TD.unlocksOf("V10")
		check("offerLock: Fuel Count opens the KS-7 at LL1 once turned in (not while active); markers sell while a marking task is taken",
			ks ~= nil and l0 == true and l1 == false and l2 == true and mk ~= nil and m0 == true and m1 == false and #unl >= 1 and unl[1].trader == "vos")
		local llFirst, why = TD.offerLock(TD.offers.vos[#TD.offers.vos], 1, { V17 = { s = "claimed" } })
		check("a task-locked offer above the player's loyalty level still waits for the level", llFirst == true and type(why) == "string" and string.find(why, "loyalty", 1, true) ~= nil)
	end

	-- ── operational tasks (pure) ─────────────────────────────────────────────────────────────────────────────────
	do
		local bad, kinds = {}, {}
		local rng = Random.new(6006)
		local exits = { border = { "K11", "CR" }, quay7 = { "A", "C" } }
		for _, kind in QD.OPS_ORDER do
			for _, level in { 5, 15, 25, 40 } do
				for _ = 1, 120 do
					local inst = QD.rollOp(kind, level, rng, exits)
					local o = inst.obj and inst.obj[1]
					local ok = o ~= nil and #inst.obj == 1 and KINDS[o.kind] == true and (o.n or 0) >= 1 and type(inst.name) == "string"
						and (inst.reward.money or 0) > 0 and (inst.reward.xp or 0) > 0 and TD.defs[inst.trader] ~= nil
					ok = ok and ((kind == "scav") == (inst.trader == "fence"))
					if o then
						kinds[kind .. ":" .. o.kind] = true
						ok = ok and (o.map == nil or Maps.defs[o.map] ~= nil)
						if o.kind == "kill" then
							ok = ok and TARGETS[o.target] == true and (o.weapon == nil or CLASSES[o.weapon] == true) and (o.part == nil or PARTS[o.part] == true)
								and (o.boss == nil or QD.BOSS_MAP[o.boss] == o.map) and (o.dist == nil or (o.map ~= "smelter" and o.dist >= 20 and o.dist <= 100))
						elseif o.kind == "handin" then
							ok = ok and Items.defs[o.item] ~= nil and Items.defs[o.item].kind ~= "quest"
						elseif o.kind == "extract" then
							ok = ok and (o.exfil == nil or (exits[o.map] ~= nil and table.find(exits[o.map], o.exfil) ~= nil))
						end
					end
					if kind == "weekly" then
						ok = ok and inst.reward.items ~= nil and Items.defs[inst.reward.items[1][1]] ~= nil
					end
					-- Fence's count in scav raids, the others in PMC raids
					if kind == "scav" then
						ok = ok and (inst.reward.karma or 0) > 0 and (o.scav == true)
					else
						ok = ok and (inst.reward.rep or 0) > 0 and (o.kind == "handin" or o.scav == false)
					end
					if not ok and #bad < 5 then
						table.insert(bad, kind .. " L" .. level .. " " .. tostring(o and o.kind))
					end
				end
			end
		end
		check("operational tasks roll valid objectives: kills (scavs, PMCs, a boss on its map) with EFT's modifiers, exits, hand-ins; money, XP and standing" .. listed(bad),
			#bad == 0 and kinds["daily:kill"] and kinds["daily:extract"] and kinds["daily:handin"] and kinds["weekly:kill"] and kinds["scav:extract"])
		local d1, e1 = QD.periodOf("daily", 86400 * 20000 + 5)
		local w1, we = QD.periodOf("weekly", 86400 * 20000 + 5)
		check("operational timers: a daily ends at the next midnight (UTC), a weekly on Monday", d1 == 20000 and e1 == 86400 * 20001
			and (we + 3 * 86400) % 604800 == 0 and we > 86400 * 20000 + 5 and we - (86400 * 20000 + 5) <= 604800 and w1 > 0)
	end

	-- ── server rules ─────────────────────────────────────────────────────────────────────────────────────────────
	if not (ctx and ctx.Economy and ctx.Quests and ctx.World) then
		table.insert(notes, "server checks skipped (no ctx)")
	else
		local E, Q = ctx.Economy, ctx.Quests

		-- loyalty-level groups unlock as stated: at the level's player level and standing the group's first tasks open,
		-- a hair short of the standing they stay shut
		do
			local bad = {}
			for _, tid in SEVEN do
				for k = 2, 4 do
					local req = TD.loyaltyReq(tid, k)
					local batch = firstBatch(tid, k)
					local p = Settle.newProfile()
					local lvl = req.level
					for _, q in batch do
						lvl = math.max(lvl, q.level or 1)
					end
					p.xp = P.xpFor(math.min(lvl, P.MAX_LEVEL))
					for _, q in QD.list do
						if q.trader ~= tid or (q.tl or 1) < k then
							p.quests[q.id] = { s = "claimed", p = {} }
						end
					end
					E.standing(p, tid).rep = req.rep
					local open = E.loyalty(p, tid) == k
					for _, q in batch do
						open = open and Q.status(p, q) == "available"
					end
					E.standing(p, tid).rep = math.max(0, req.rep - 0.02)
					local shut = E.loyalty(p, tid) == k - 1
					for _, q in batch do
						shut = shut and Q.status(p, q) == "locked"
					end
					if not (open and shut) then
						table.insert(bad, tid .. " LL" .. k .. (open and "" or " (does not open)") .. (shut and "" or " (opens early)"))
					end
				end
			end
			check("loyalty-level groups: each opens at its level's player level and standing, and not a hair before" .. listed(bad), #bad == 0)
		end

		-- every task can be reached from a fresh start: take every open task, turn it in, repeat
		do
			local sp = Settle.newProfile()
			sp.xp = P.xpFor(P.MAX_LEVEL)
			sp.karma = 6
			local changed = true
			while changed do
				changed = false
				for _, q in QD.list do
					if not sp.quests[q.id] and Q.status(sp, q) == "available" then
						sp.quests[q.id] = { s = "claimed", p = {} }
						local r = q.reward or {}
						if r.rep then
							E.standing(sp, q.trader).rep += r.rep
						end
						for tid, dv in r.reps or {} do
							E.standing(sp, tid).rep += dv
						end
						changed = true
					end
				end
			end
			local left = {}
			for _, q in QD.list do
				if not sp.quests[q.id] then
					table.insert(left, q.id)
				end
			end
			local top = true
			for _, tid in SEVEN do
				top = top and E.loyalty(sp, tid) == 4
			end
			check("every task is reachable from the start (all " .. #QD.list .. " taken in turn), ending at LL4 with all seven" .. listed(left), #left == 0 and top)
		end

		-- old profiles keep their task states (economy-6a changed no id, objective or reward of the 23 older tasks)
		do
			local op = Settle.newProfile()
			op.xp = P.xpFor(4) -- below every operational task's level
			op.quests.V1 = { s = "claimed", p = {} }
			op.quests.V2 = { s = "active", p = { ["1"] = 2 } }
			op.quests.H3 = { s = "active", p = {} }
			op.quests.T5 = { s = "claimed", p = {} }
			op.quests.T6 = { s = "active", p = { ["1"] = 1, ["3"] = 1 } }
			local okRun, st = pcall(Q.stateFor, op)
			check("an old profile keeps its task states and progress; no operational tasks below level 5",
				okRun and st.V1.s == "claimed" and st.V2.s == "active" and st.V2.p[1] == 2 and st.H3.s == "active" and st.T5.s == "claimed"
					and st.T6.p[1] == 1 and st.T6.p[2] == 0 and st.T6.p[3] == 1 and #st.ops == 0 and op.quests.V2.s == "active")
			-- a task that was open before economy-6a and now waits for its giver's loyalty level stays shut until then
			local p8 = Settle.newProfile()
			p8.xp = P.xpFor(8)
			local v12 = QD.byId.V12
			local before = Q.status(p8, v12)
			E.standing(p8, "vos").rep = TD.loyaltyReq("vos", 2).rep
			check("a task waits for its giver's loyalty level (V12 at VOS LL2)", before == "locked" and Q.status(p8, v12) == "available")
		end

		-- kill conditions (EFT: map, place, weapon, distance, body part, time of day, target, gear)
		do
			local base = { scav = false, map = "border", gear = { armor = false, nv = false, worn = {} }, class = "bolt", part = "head", dist = 70, hour = 22 }
			local function with(t)
				local x = table.clone(base)
				for k, v in t do
					x[k] = v
				end
				return x
			end
			local o = { kind = "kill", target = "scav", n = 1, map = "border", weapon = "bolt", dist = 40, time = { 21, 5 }, part = "head" }
			local ok = Q.killMatches(o, "scav", nil, base) and Q.killMatches(o, "pscav", nil, base)
				and not Q.killMatches(o, "boss", "Broker", base) and not Q.killMatches(o, "scav", nil, with({ map = "meridian" }))
				and not Q.killMatches(o, "scav", nil, with({ class = "rifle" })) and not Q.killMatches(o, "scav", nil, with({ dist = 30 }))
				and not Q.killMatches(o, "scav", nil, with({ hour = 12 })) and Q.killMatches(o, "scav", nil, with({ hour = 3.5 }))
				and not Q.killMatches(o, "scav", nil, with({ part = "legs" })) and not Q.killMatches(o, "scav", nil, nil)
			check("kill conditions: map, weapon class, distance, a window past midnight and the body part each count; scavs include player scavs",
				ok and Q.inWindow(23, 21, 5) and Q.inWindow(4.9, 21, 5) and not Q.inWindow(5, 21, 5) and Q.inWindow(10, 9, 17))
			local gear = { kind = "kill", target = "any", n = 1, noArmor = true, noNv = true }
			local wear = { kind = "kill", target = "scav", n = 1, wear = "GAS_MASK", maxDist = 20 }
			local asScav = { kind = "kill", target = "pmc", n = 1, scav = true }
			local supp = { kind = "kill", target = "scav", n = 1, suppressed = true }
			local guard = { kind = "kill", target = "follower", n = 1, label = "Mortar" }
			check("gear and side: no armour, no night vision, a worn gas mask within 20 m, as a scav, suppressed, a named guard",
				Q.killMatches(gear, "boss", "Broker", base) and not Q.killMatches(gear, "scav", nil, with({ gear = { armor = true, nv = false, worn = {} } }))
					and not Q.killMatches(gear, "scav", nil, with({ gear = { armor = false, nv = true, worn = {} } }))
					and Q.killMatches(wear, "scav", nil, with({ dist = 10, gear = { armor = true, nv = false, worn = { GAS_MASK = true } } }))
					and not Q.killMatches(wear, "scav", nil, with({ dist = 25, gear = { armor = true, nv = false, worn = { GAS_MASK = true } } }))
					and not Q.killMatches(wear, "scav", nil, with({ dist = 10 }))
					and Q.killMatches(asScav, "pmc", nil, with({ scav = true })) and not Q.killMatches(asScav, "pmc", nil, base)
					and Q.killMatches(supp, "scav", nil, with({ suppressed = true })) and not Q.killMatches(supp, "scav", nil, base)
					and Q.killMatches(guard, "follower", "Mortar", base) and not Q.killMatches(guard, "follower", "Kestrel", base)
					and not Q.killMatches(guard, "boss", "Mortar", base))
			local z = { pos = Vector3.new(0, 10, 0), r = 20, h = 4 }
			check("places: a sphere, or a cylinder one floor tall when it has a half height",
				Q.inZone(z, Vector3.new(15, 12, 0)) and not Q.inZone(z, Vector3.new(15, 20, 0)) and not Q.inZone(z, Vector3.new(25, 10, 0))
					and Q.inZone({ pos = Vector3.zero, r = 5 }, Vector3.new(0, 4, 0)) and not Q.inZone({ pos = Vector3.zero, r = 5 }, Vector3.new(0, 6, 0)))
		end

		-- the end of a raid: quest items kept only by getting out, markers that count, run-throughs, one-raid objectives
		do
			local p = Settle.newProfile()
			p.xp = P.xpFor(12)
			p.quests.H9 = { s = "active", p = {} }
			p.quests.V10 = { s = "active", p = {} }
			p.quests.V6 = { s = "active", p = {} }
			p.quests.V14 = { s = "active", p = { ["1"] = 3 } }
			local dead = { map = "border", qfound = { QI_LETTERS = 1 }, qmarks = { ["V10#1"] = { at = os.clock() + 99, id = "V10", i = 1 } } }
			Q.onRaidEnd(nil, p, dead, "KIA", false)
			local lostOk = (p.qitems == nil or (p.qitems.QI_LETTERS or 0) == 0) and (p.quests.V10.p["1"] or 0) == 0 and p.quests.V14.p["1"] == 0
			local out = { map = "border", qfound = { QI_LETTERS = 1 }, qmarks = { ["V10#1"] = { at = os.clock() + 99, id = "V10", i = 1 } } }
			Q.onRaidEnd(nil, p, out, "SUCCESS", false)
			local keptOk = p.qitems ~= nil and p.qitems.QI_LETTERS == 1 and p.quests.V10.p["1"] == 1
			check("a death loses the quest items picked up and the marker set, and resets an in-one-raid count (V14); getting out keeps both",
				lostOk and keptOk)
			Q.onRaidEnd(nil, p, out, "SUCCESS", false)
			check("a raid ends once: a second call changes nothing", p.qitems.QI_LETTERS == 1 and p.quests.V10.p["1"] == 1)
			local rt = { map = "smelter", scav = false }
			Q.onRaidEnd(nil, p, rt, "SUCCESS", true)
			local afterRt = p.quests.V6.p["2"] or 0
			Q.onRaidEnd(nil, p, { map = "smelter", scav = false }, "SUCCESS", false)
			check("a run-through does not count for an extraction objective, a survived exit does (EFT wiki)", afterRt == 0 and p.quests.V6.p["2"] == 1)
			-- the quest item is handed over from the pouch
			local h9 = QD.byId.H9
			local money0 = p.money
			local doneBefore = Q.complete(p, h9)
			local res = Q.turnIn(nil, p, h9, p.quests.H9)
			check("a found quest item completes both lines (obtain, hand over) and is handed over from the pouch at turn-in",
				doneBefore and res == true and p.quests.H9.s == "claimed" and (p.qitems.QI_LETTERS or 0) == 0 and p.money == money0 + h9.reward.money)
			local lastMsg = p.msgs and p.msgs[#p.msgs]
			check("the turn-in mail is tagged for the messenger's task heading", lastMsg ~= nil and lastMsg.k == "done" and lastMsg.q == "H9" and lastMsg.f == "hale")
		end

		-- a gunsmith build in the stash completes the objective and is handed over
		do
			local p = Settle.newProfile()
			p.xp = P.xpFor(5)
			p.quests.K2 = { s = "active", p = {} }
			local k2 = QD.byId.K2
			local gave = E.giveStash(p, "P9_PISTOL", 1, { presetMag = true })
			local root
			for g, it in p.items do
				if it.id == "P9_PISTOL" and p.grids.stash[g] then
					root = g
				end
			end
			local before = root and Q.progress(p, k2, 1) or -1
			if root then
				local lg, lit = Inv.newItem("LIGHT_T", 1)
				p.items[lg] = lit
				p.items[root].mods = p.items[root].mods or {}
				p.items[root].mods.tactical = lg
			end
			local after = root and Q.progress(p, k2, 1) or -1
			local res = root and Q.turnIn(nil, p, k2, p.quests.K2)
			check("gunsmith: the plain P-9 does not do, with a light on it it does, and the build is handed over",
				gave and before == 0 and after == 1 and res == true and root ~= nil and p.items[root] == nil and p.quests.K2.s == "claimed")
		end

		-- operational tasks: rolled by level, failed and replaced when the timer runs out, replaced for money and standing
		do
			local p = Settle.newProfile()
			p.xp = P.xpFor(16)
			p.money = 10000000
			local monday = 4 * 86400 + 604800 * 2900 + 3600 -- a Monday, 01:00 UTC
			local noIntel = Settle.newProfile()
			noIntel.xp = P.xpFor(16)
			Q.ensureOps(noIntel, monday)
			check("Fence's scav task waits for the intelligence center (EFT; economy-7b); the dailies and the weekly do not",
				noIntel.ops.scav == nil and noIntel.ops.daily ~= nil and noIntel.ops.weekly ~= nil)
			p.hideout.levels.intel = 1
			Q.ensureOps(p, monday)
			local d = p.ops.daily and p.ops.daily.list or {}
			local w = p.ops.weekly and p.ops.weekly.list or {}
			local s = p.ops.scav and p.ops.scav.list or {}
			local ids = {}
			local unique = true
			for _, inst in { d[1], d[2], d[3], w[1], s[1] } do
				if inst then
					unique = unique and not ids[inst.id] and inst.s == "available"
					ids[inst.id] = true
				end
			end
			check("at level 16: three dailies, one weekly, one scav task for Fence, all open, ids unique", #d == 3 and #w == 1 and #s == 1 and unique and s[1].trader == "fence")
			d[1].s = "active"
			local wid = w[1].id
			local firstId = d[1].id
			Q.ensureOps(p, monday + 86400)
			local d2 = p.ops.daily.list
			local failMail = false
			for _, m in p.msgs or {} do
				failMail = failMail or (m.k == "fail" and m.q == firstId)
			end
			check("a daily not turned in by midnight fails (a message says so) and three new ones come; the weekly stays the week",
				#d2 == 3 and d2[1].id ~= firstId and failMail and p.ops.weekly.list[1].id == wid)
			local inst = d2[2]
			local tid = inst.trader
			local rep0 = E.standing(p, tid).rep or 0
			local money0 = p.money
			local cost, costRep = QD.replaceCost(inst)
			local res = Q.replaceOp(nil, p, inst)
			check("replacing an operational task costs money and standing (EFT) and rolls a new one in its place",
				res == true and p.money == money0 - cost and near(E.standing(p, tid).rep, rep0 - costRep) and p.ops.daily.list[2] ~= inst
					and p.ops.daily.list[2].id ~= inst.id and p.ops.daily.list[2].s == "available")
			local view = Q.stateFor(p)
			check("the client's view carries the operational tasks (with timer and replace price) and the quest-item pouch",
				type(view.ops) == "table" and #view.ops == 5 and view.ops[1].ends ~= nil and view.ops[1].cost ~= nil and type(view.qitems) == "table"
					and QD.byId.ops == nil and QD.byId.qitems == nil and QD.byId.found == nil)
			local low = Settle.newProfile()
			low.xp = P.xpFor(10)
			low.hideout.levels.intel = 1
			Q.ensureOps(low, monday)
			check("below level 15 no weekly; dailies and Fence's task from level 5", low.ops.weekly == nil and low.ops.daily ~= nil and low.ops.scav ~= nil)
		end
	end

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

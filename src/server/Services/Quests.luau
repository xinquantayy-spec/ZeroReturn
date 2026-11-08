--!nonstrict
-- Trader tasks (M9; decision economy-6a): accept in the hideout, progress during raids, hand in found-in-raid items and
-- collect rewards at the trader. Each task belongs to the trader whose EFT counterpart gives it (QuestData); its standing
-- goes to that trader. What counts (EFT; sources in QuestData):
--   kills       count even if you die; conditions read the kill (the killing hit's body part and weapon, the distance),
--               the raid clock, the map and place you stand in, and what you wear
--   extracts    a survived extraction, not a run-through (EFT wiki: run-throughs do not count for extraction tasks)
--   visits      reaching a task place (checked every second)
--   plant/mark  hold F at the place with the item in your raid kit; a marker counts once you have stayed alive 30 s after
--               setting it (or got out). Only the task's owner sees and can use the prompt (TaskFor = UserId)
--   find        a quest item at its place, for the owner only; it rides in the raid's quest-item pouch and is kept only by
--               getting out (EFT: lost on a failed extraction); then it waits in the profile's pouch (prof.qitems)
--   build       a gunsmith build in the stash (or worn) that meets the specification, handed over at turn-in
--   in one raid objectives (raid = true) start again when the raid ends before they are done
-- Loyalty-level groups (EFT 1.1.0): a task opens at its trader's loyalty level tl. Operational tasks (EFT's dailies and
-- weeklies): three dailies from level 5, one weekly from level 15 and one scav task from Fence, rolled per profile
-- (prof.ops), failed and replaced when their timer runs out; they can be replaced for money and a little standing.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local QD = require(Shared.QuestData)
local TD = require(Shared.TraderData)
local P = require(Shared.Progress)
local Env = require(Shared.Env)
local WP = require(Shared.WeaponParts)
local Weapons = require(Shared.Weapons)
local Inv = require(script.Parent.Inv)

local Quests = {}
local ctx
local spotFolder = nil -- workspace.ZR_TaskSpots: the per-player prompts of plant, mark and find places
local prompts = {} -- [player] = { [key] = part }
Quests.SPOT_NEAR = 60 -- studs: a place's prompt is made when its owner comes this close

local function fail(code, msg)
	return ctx.Remotes.fail(code, msg)
end

local function toast(player, text, tone)
	if typeof(player) == "Instance" then
		ctx.Remotes.note(player, "toast", { text = text, tone = tone or "good" })
	end
end

local function dirty(player)
	if typeof(player) == "Instance" then
		ctx.Profiles.markDirty(player)
	end
end

-- the player whose profile this is (nil for a stand-in profile in the tests)
local function playerOf(prof)
	for _, pl in Players:GetPlayers() do
		if ctx.Profiles.get(pl) == prof then
			return pl
		end
	end
	return nil
end

-- the raid session of a profile, if its player is in a raid
local function sessionOf(prof)
	for pl, s in ctx.Raid.sessions() do
		if not s.done and ctx.Profiles.get(pl) == prof then
			return s, pl
		end
	end
	return nil
end

local function claimed(prof, id)
	local st = prof.quests[id]
	return st ~= nil and st.s == "claimed"
end

-- messenger: a task message from its trader (Economy.mail), tagged for the messenger's task headings (Menus): k = "start",
-- "done" or "fail", q = the task's id
local function mail(prof, from, text, k, id)
	ctx.Economy.mail(prof, from, text)
	local m = prof.msgs and prof.msgs[#prof.msgs]
	if m then
		m.k, m.q = k, id
	end
end

-- ── unlocking ─────────────────────────────────────────────────────────────────────────────────────────────────────
function Quests.status(prof, q)
	local st = prof.quests[q.id]
	if st then
		return st.s
	end
	if q.after and not claimed(prof, q.after) then
		return "locked"
	end
	if ctx.Economy.level(prof) < (q.level or 1) then
		return "locked"
	end
	-- EFT 1.1.0: side tasks open in groups tied to the giver's loyalty level
	if (q.tl or 1) > 1 and ctx.Economy.loyalty(prof, q.trader) < q.tl then
		return "locked"
	end
	-- EFT 1.1.0's collector rules (audit economy.7): more finished tasks, a Fence standing, a loyalty level with every
	-- trader but Fence (the seven of EFT's eight)
	for _, id in q.needs or {} do
		if not claimed(prof, id) then
			return "locked"
		end
	end
	if q.karma and (prof.karma or P.KARMA.start) < q.karma then
		return "locked"
	end
	if q.ll then
		for _, tid in TD.list do
			if tid ~= "fence" and ctx.Economy.loyalty(prof, tid) < q.ll then
				return "locked"
			end
		end
	end
	return "available"
end

-- ── what the stash holds ──────────────────────────────────────────────────────────────────────────────────────────
-- is g in the stash grid or inside a container that is in the stash?
local function inStash(prof, g)
	local cur = g
	for _ = 1, 12 do
		if prof.grids.stash and prof.grids.stash[cur] then
			return true
		end
		local parent = nil
		for cid, pl in prof.grids do
			if pl[cur] then
				parent = cid
				break
			end
		end
		if not parent or parent == "stash" or parent == "pockets" then
			return parent == "stash"
		end
		cur = parent
	end
	return false
end

local function isQuestItem(id)
	local d = Items.defs[id]
	return d ~= nil and d.kind == "quest"
end

-- items of this id in the stash, not inside containers you are wearing; found in raid only unless fir == false
local function stashCount(prof, id, fir)
	local n = 0
	for g, it in prof.items do
		if it.id == id and (fir == false or it.fir) and inStash(prof, g) then
			n += it.n or 1
		end
	end
	return n
end

-- quest items waiting to be handed over (EFT's "Quest items" tab of the task stash)
local function pouch(prof)
	if type(prof.qitems) ~= "table" then
		prof.qitems = {}
	end
	return prof.qitems
end
local function inPouch(prof, id)
	return (type(prof.qitems) == "table" and prof.qitems[id]) or 0
end

-- what a hand-in objective can take now: the stash, plus the quest-item pouch for a quest item
local function haveFor(prof, o)
	local n = stashCount(prof, o.item, o.fir)
	if isQuestItem(o.item) then
		n += inPouch(prof, o.item)
	end
	return n
end

-- a gunsmith build that meets the objective: in the stash or worn (guid), or nil
function Quests.buildIn(prof, o)
	for g, it in prof.items do
		if it.id == o.base then
			local worn = false
			for _, sg in prof.slots or {} do
				if sg == g then
					worn = true
				end
			end
			if (worn or inStash(prof, g)) and QD.buildMatches(o, prof.items, g) then
				return g
			end
		end
	end
	return nil
end

-- ── progress ──────────────────────────────────────────────────────────────────────────────────────────────────────
-- objective progress: hand-ins, quest items and builds are counted from what you hold; the rest is stored in the state
-- (st: the task's state, or the operational task itself)
function Quests.progress(prof, q, i, st)
	local o = q.obj[i]
	if o.kind == "handin" then
		return math.min(o.n, haveFor(prof, o))
	elseif o.kind == "find" then
		return math.min(o.n, inPouch(prof, o.item))
	elseif o.kind == "build" then
		return Quests.buildIn(prof, o) and 1 or 0
	end
	st = st or prof.quests[q.id]
	return math.min(o.n, (st and st.p and st.p[tostring(i)]) or 0)
end

function Quests.complete(prof, q, st)
	for i, o in q.obj do
		if Quests.progress(prof, q, i, st) < o.n then
			return false
		end
	end
	return true
end

-- ── operational tasks (EFT's dailies and weeklies; QuestData.OPS) ─────────────────────────────────────────────────
local function opsList(prof)
	local out = {}
	if type(prof.ops) == "table" then
		for _, kind in QD.OPS_ORDER do
			local box = prof.ops[kind]
			for _, inst in (box and box.list) or {} do
				table.insert(out, inst)
			end
		end
	end
	return out
end

local function opById(prof, id)
	for _, inst in opsList(prof) do
		if inst.id == id then
			return inst
		end
	end
	return nil
end
Quests.opById = opById

-- the open exits of every built map (an exploration task may name one)
local function exitsOf()
	local out = {}
	for mapId, m in (ctx.World and ctx.World.maps) or {} do
		local list = {}
		for eid, e in m.extracts or {} do
			if type(e) == "table" and (e.rule == nil or e.rule.kind == "open") then
				table.insert(list, eid)
			end
		end
		table.sort(list)
		if #list > 0 then
			out[mapId] = list
		end
	end
	return out
end

local function rollInto(prof, kind, per, ends, slot, rn)
	local inst = QD.rollOp(kind, ctx.Economy.level(prof), Random.new(), exitsOf())
	inst.id = string.format("%s%d.%d", string.upper(string.sub(kind, 1, 1)), per, slot) .. ((rn or 0) > 0 and ("." .. rn) or "")
	inst.s, inst.p, inst.ends, inst.slot, inst.rn = "available", {}, ends, slot, rn or 0
	return inst
end

-- roll the lists a player is due (level 5 dailies, level 15 weeklies, Fence's scav task); a list whose timer ran out fails
-- what was not turned in and is replaced (EFT). now: os.time() unless a test passes one. Returns whether anything changed.
function Quests.ensureOps(prof, now)
	now = now or os.time()
	if type(prof.ops) ~= "table" then
		prof.ops = {}
	end
	local level = ctx.Economy.level(prof)
	local changed = false
	for _, kind in QD.OPS_ORDER do
		local cfg = QD.OPS[kind]
		local per, ends = QD.periodOf(kind, now)
		local box = prof.ops[kind]
		if type(box) == "table" and box.per ~= per then
			for _, inst in box.list or {} do
				if inst.s == "active" then
					inst.s = "failed"
					mail(prof, inst.trader, "Task failed: " .. inst.name .. ". The time ran out.", "fail", inst.id)
				end
			end
			prof.ops[kind] = nil
			box = nil
			changed = true
		end
		-- Fence's scav task opens with the intelligence center (EFT; economy-7b)
		if box == nil and level >= cfg.level and (kind ~= "scav" or not ctx.Hideout or ctx.Hideout.levelOf(prof, "intel") >= 1) then
			local list = {}
			for slot = 1, cfg.n do
				table.insert(list, rollInto(prof, kind, per, ends, slot, 0))
			end
			prof.ops[kind] = { per = per, list = list }
			changed = true
		end
	end
	if changed then
		local pl = playerOf(prof)
		if pl then
			dirty(pl)
		end
	end
	return changed
end

-- every active task and operational task: fn(q, st), st being the task's state or the operational task itself
local function eachActive(prof, fn)
	for _, q in QD.list do
		local st = prof.quests[q.id]
		if st and st.s == "active" then
			st.p = st.p or {}
			fn(q, st)
		end
	end
	for _, inst in opsList(prof) do
		if inst.s == "active" then
			inst.p = inst.p or {}
			fn(inst, inst)
		end
	end
end
Quests.eachActive = eachActive

-- the definition and state of a task or operational task by id
local function lookup(prof, id)
	local q = QD.byId[id]
	if q then
		return q, prof.quests[id]
	end
	local inst = opById(prof, id)
	return inst, inst
end

local function bump(player, prof, q, st, i, by)
	local o = q.obj[i]
	local k = tostring(i)
	st.p = st.p or {}
	local cur = st.p[k] or 0
	if cur >= o.n then
		return
	end
	st.p[k] = math.min(o.n, cur + (by or 1))
	dirty(player)
	toast(player, string.format("TASK  %s  ·  %s %d/%d", string.upper(q.name), string.upper(QD.describe(o)), st.p[k], o.n))
end

-- ── kills ─────────────────────────────────────────────────────────────────────────────────────────────────────────
local KILL_MATCH = {
	scav = { scav = true, pscav = true }, watch = { watch = true }, pmc = { pmc = true }, boss = { boss = true }, follower = { follower = true },
	any = { scav = true, pscav = true, watch = true, pmc = true, boss = true, follower = true },
}
-- Health's pools to EFT's body-part groups
local PART_GROUP = { head = "head", thorax = "thorax", stomach = "stomach", larm = "arms", rarm = "arms", lleg = "legs", rleg = "legs" }
-- the killing hit names its weapon by item name (Combat: the gun's name, "KNIFE"; Grenades: the grenade's name)
local NAME_CLASS, NAME_ID = { KNIFE = "melee" }, { KNIFE = "FIELD_KNIFE" }
for id, d in Items.defs do
	local w = d.weapon and Weapons[d.weapon]
	if type(w) == "table" and w.class then
		NAME_CLASS[d.name], NAME_ID[d.name] = w.class, id
	elseif d.kind == "grenade" then
		NAME_CLASS[d.name], NAME_ID[d.name] = "grenade", id
	end
end
local CONDS = { "map", "zone", "weapon", "gun", "dist", "maxDist", "part", "time", "scav", "suppressed", "noArmor", "noNv", "wear", "raid" }

function Quests.hasConditions(o)
	for _, k in CONDS do
		if o[k] ~= nil and k ~= "raid" then
			return true
		end
	end
	return false
end

local function oneOf(want, v)
	if type(want) == "table" then
		return v ~= nil and table.find(want, v) ~= nil
	end
	return want == v
end

-- is hour h (raid clock, 0..24) inside the window from..to (which may run past midnight)?
function Quests.inWindow(h, from, to)
	if from <= to then
		return h >= from and h < to
	end
	return h >= from or h < to
end

-- the map a raid session is on (a transit moves it; Raid sets it at the start)
local function mapOf(s)
	return s.map or (ctx.Match and ctx.Match.map)
end

-- a task place of a map ({ pos, r, h? }), or nil
function Quests.place(mapId, zoneId)
	local m = mapId and ctx.World.maps and ctx.World.maps[mapId]
	local zones = (m and m.visitZones) or (mapId == ctx.World.activeMap and ctx.World.visitZones) or {}
	return zones[zoneId]
end

-- is pos inside a place? (a place with a half height h is a short cylinder, for one floor of a building)
function Quests.inZone(z, pos)
	if not (z and z.pos and typeof(pos) == "Vector3") then
		return false
	end
	local d = pos - z.pos
	if z.h then
		return Vector3.new(d.X, 0, d.Z).Magnitude <= z.r and math.abs(d.Y) <= z.h
	end
	return d.Magnitude <= z.r
end

-- what the killer wears: any body armour or helmet, night vision on the head, the ids of what is worn
local WORN_SLOTS = { head = true, ears = true, face = true, eyes = true, armor = true, rig = true, back = true }
local function gearOf(s)
	local g = { armor = false, nv = false, worn = {} }
	local inv = s and s.inv
	if not inv then
		return g
	end
	for slot, guid in inv.slots or {} do
		local it = inv.items[guid]
		local d = it and Items.defs[it.id]
		if d and WORN_SLOTS[slot] then
			g.worn[it.id] = true
			if (slot == "armor" and d.armor) or (slot == "rig" and d.armor) or (slot == "head" and d.kind == "helmet") then
				g.armor = true
			end
			if slot == "head" then
				for _, sg in Inv.descendants(inv, guid) do
					local si = inv.items[sg]
					local sd = si and Items.defs[si.id]
					if sd and sd.kind == "nvg" then
						g.nv = true
					end
				end
			end
		end
	end
	return g
end

-- the facts of a kill the conditions read. victim: the dead character's model (the killing hit is its Health lastHit)
function Quests.killInfo(player, victim)
	local s = ctx.Raid.session(player)
	local info = { scav = s ~= nil and s.scav == true, map = s and mapOf(s) or nil, gear = gearOf(s) }
	local char = typeof(player) == "Instance" and player.Character or nil
	local root = char and char:FindFirstChild("HumanoidRootPart")
	info.pos = root and root.Position or nil
	local e = ctx.Match and ctx.Match.env
	if e then
		info.hour = Env.clock(e, workspace:GetServerTimeNow())
	end
	if typeof(victim) == "Instance" then
		local hs = ctx.Health and ctx.Health.get(victim)
		local lh = hs and hs.lastHit
		if lh then
			info.part = PART_GROUP[lh.part]
			if type(lh.weapon) == "string" then
				info.class, info.gun = NAME_CLASS[lh.weapon], NAME_ID[lh.weapon]
			end
		end
		local vr = victim:FindFirstChild("HumanoidRootPart")
		local vp = (vr and vr.Position) or (victim:IsA("Model") and victim:GetPivot().Position) or nil
		if vp and info.pos then
			info.dist = (info.pos - vp).Magnitude / QD.STUDS_PER_M
		end
	end
	-- the gun in hand: its class when the hit did not name one, and whether it wears a suppressor
	if s and ctx.Combat and ctx.Combat.activeWeapon then
		local wg, wit, wdef = ctx.Combat.activeWeapon(s)
		if wg and wdef then
			if info.class == nil then
				info.class, info.gun = wdef.class, wit.id
			end
			if info.class == wdef.class and wdef.class ~= "melee" then
				info.suppressed = WP.stats(s.inv.items, wg).suppressed == true
			end
		end
	end
	return info
end

-- does a kill objective take this kill? label: the victim's Label attribute (a boss's or a guard's name, audit
-- economy.9); info: Quests.killInfo (an objective with conditions needs it)
function Quests.killMatches(o, kind, label, info)
	if o.kind ~= "kill" or KILL_MATCH[o.target] == nil or KILL_MATCH[o.target][kind] ~= true then
		return false
	end
	local who = o.boss or o.label
	if who ~= nil and not oneOf(who, label) then
		return false
	end
	if not Quests.hasConditions(o) then
		return true
	end
	if info == nil then
		return false
	end
	if o.map and o.map ~= info.map then
		return false
	end
	if o.zone then
		local z = info.map and Quests.place(info.map, o.zone)
		if not (z and Quests.inZone(z, info.pos)) then
			return false
		end
	end
	if o.weapon and not oneOf(o.weapon, info.class) then
		return false
	end
	if o.gun and not oneOf(o.gun, info.gun) then
		return false
	end
	if o.dist and not (info.dist and info.dist >= o.dist) then
		return false
	end
	if o.maxDist and not (info.dist and info.dist <= o.maxDist) then
		return false
	end
	if o.part and not oneOf(o.part, info.part) then
		return false
	end
	if o.time and not (info.hour and Quests.inWindow(info.hour, o.time[1], o.time[2])) then
		return false
	end
	if o.scav ~= nil and o.scav ~= (info.scav == true) then
		return false
	end
	if o.suppressed and not info.suppressed then
		return false
	end
	local gear = info.gear or {}
	if o.noArmor and gear.armor then
		return false
	end
	if o.noNv and gear.nv then
		return false
	end
	if o.wear and not (gear.worn and gear.worn[o.wear]) then
		return false
	end
	return true
end

-- a raid kill by this player (Economy.onKill). victim: the dead character's model (AI or a player's character)
function Quests.onKill(player, kind, label, victim)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return
	end
	local info = nil
	eachActive(prof, function(q, st)
		for i, o in q.obj do
			if o.kind == "kill" then
				if info == nil and Quests.hasConditions(o) then
					info = Quests.killInfo(player, victim)
				end
				if Quests.killMatches(o, kind, label, info) then
					bump(player, prof, q, st, i)
				end
			end
		end
	end)
end

-- ── extracts ──────────────────────────────────────────────────────────────────────────────────────────────────────
-- does an extract objective take this extraction? (exit, scav or PMC, and the map when the objective names one)
function Quests.extractMatches(o, s, mapId)
	return o.kind == "extract" and (o.scav == nil or o.scav == (s.scav == true)) and (not o.exfil or o.exfil == s.exZone) and (not o.map or o.map == mapId)
end

local function countExtract(player, prof, s)
	local mapId = mapOf(s)
	eachActive(prof, function(q, st)
		for i, o in q.obj do
			if Quests.extractMatches(o, s, mapId) then
				bump(player, prof, q, st, i)
			end
		end
	end)
end

-- ── task places ───────────────────────────────────────────────────────────────────────────────────────────────────
-- the visit zone an objective means for a raid session: the zone of that name in the session's own map (audit economy.9:
-- the zones of the active map were used, wrong after a transit; zone names repeat across maps), or nil
function Quests.zoneFor(o, s, mapId)
	if o.kind ~= "visit" or (o.map and o.map ~= mapId) or (o.scav ~= nil and o.scav ~= (s.scav == true)) then
		return nil
	end
	return Quests.place(mapId, o.zone)
end

local function dropPrompt(player, key)
	local mine = prompts[player]
	local part = mine and mine[key]
	if part then
		part:Destroy()
		mine[key] = nil
	end
end

local function dropAll(player)
	if player == nil then
		return -- a stand-in raid in the tests
	end
	for _, part in prompts[player] or {} do
		part:Destroy()
	end
	prompts[player] = nil
end
Quests.dropAll = dropAll

-- the first item of this id anywhere in the raid kit (smallest stack first), or nil
local function findInKit(h, id)
	local best, bestN = nil, math.huge
	for g, it in h.items do
		if it.id == id and (it.n or 1) < bestN then
			best, bestN = g, it.n or 1
		end
	end
	return best
end

local PROMPT_TEXT = { plant = "Plant", mark = "Mark", find = "Pick up" }

-- the owner acts at a place: plant or mark (an item from the kit) or pick up a quest item
local function act(player, id, i)
	local s = ctx.Raid.session(player)
	local prof = ctx.Profiles.get(player)
	if not (s and not s.done and prof) then
		return
	end
	local q, st = lookup(prof, id)
	local o = q and q.obj[i]
	if not (o and st and st.s == "active") or Quests.progress(prof, q, i, st) >= o.n then
		return
	end
	local key = id .. "#" .. i
	-- the prompt's reach is the client's; the server measures again
	local z = (not o.map or o.map == mapOf(s)) and Quests.place(mapOf(s), o.zone) or nil
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (z and root and (root.Position - z.pos).Magnitude <= (z.r or 4) + 10) then
		return
	end
	if o.kind == "find" then
		s.qfound = s.qfound or {}
		if (s.qfound[o.item] or 0) >= o.n then
			return
		end
		s.qfound[o.item] = (s.qfound[o.item] or 0) + 1
		toast(player, "FOUND  " .. string.upper(Items.defs[o.item].name) .. "  ·  GET OUT TO KEEP IT")
		dropPrompt(player, key)
		ctx.Raid.push(player)
		return
	end
	local g = findInKit(s.inv, o.item)
	if not g then
		toast(player, "YOU NEED A " .. string.upper(Items.defs[o.item].name), "bad")
		return
	end
	Inv.consume(s.inv, g, 1)
	dropPrompt(player, key)
	ctx.Raid.afterChange(player, true)
	if o.kind == "mark" then
		-- EFT: the marker counts once you have stayed alive 30 s after setting it (you need not stay by it)
		s.qmarks = s.qmarks or {}
		s.qmarks[key] = { at = os.clock() + QD.MARK_SURVIVE, id = id, i = i }
		toast(player, string.format("MARKED  ·  STAY ALIVE %d S", QD.MARK_SURVIVE))
	else
		bump(player, prof, q, st, i, 1)
	end
end

local function ensurePrompt(player, key, z, o, id, i)
	local mine = prompts[player]
	if not mine then
		mine = {}
		prompts[player] = mine
	end
	if mine[key] or not spotFolder then
		return
	end
	local d = Items.defs[o.item]
	local seen = o.kind == "find" -- a quest item lies there; the others are a bare place
	local part = Instance.new("Part")
	part.Name = "TaskSpot"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Size = seen and Vector3.new(0.9, 0.3, 0.65) or Vector3.new(0.5, 0.5, 0.5)
	part.Transparency = seen and 0 or 1
	part.Material = Enum.Material.SmoothPlastic
	part.Color = (d and d.color) or Color3.fromRGB(120, 110, 90)
	-- objectives at one place stand side by side, each with its own prompt
	part.CFrame = CFrame.new(z.pos + Vector3.new((i - 1) * 1.2, part.Size.Y / 2, 0))
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Task"
	pp.KeyboardKeyCode = Enum.KeyCode.F -- Tarkov's interact key
	pp.ActionText = PROMPT_TEXT[o.kind] or "Use"
	pp.ObjectText = d and d.name or ""
	pp.HoldDuration = (o.kind == "plant" and QD.PLANT_HOLD) or (o.kind == "mark" and QD.MARK_HOLD) or 0
	pp.MaxActivationDistance = math.clamp((z.r or 4) + 4, 6, 12)
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	-- for its owner only: each client hides the others' (Interact; the server ignores anyone else)
	pp:SetAttribute("TaskFor", player.UserId)
	pp.Parent = part
	pp.Triggered:Connect(function(who)
		if who == player then
			act(player, id, i)
		end
	end)
	part.Parent = spotFolder
	mine[key] = part
end

local function finishMark(player, prof, m)
	local q, st = lookup(prof, m.id)
	if q and st and st.s == "active" then
		bump(player, prof, q, st, m.i, 1)
	end
end

-- every second: visits, the prompts at places the owners are near, markers whose 30 s have passed
local function tick()
	local live = {}
	for player, s in ctx.Raid.sessions() do
		local prof = not s.done and ctx.Profiles.get(player)
		local root = prof and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			live[player] = true
			local mapId = mapOf(s)
			local want = {}
			eachActive(prof, function(q, st)
				for i, o in q.obj do
					local key = q.id .. "#" .. i
					if o.kind == "visit" then
						local z = Quests.zoneFor(o, s, mapId)
						if z and (st.p[tostring(i)] or 0) < 1 and Quests.inZone(z, root.Position) then
							bump(player, prof, q, st, i)
						end
					elseif (o.kind == "plant" or o.kind == "mark" or o.kind == "find") and (not o.map or o.map == mapId) then
						local busy = (s.qmarks and s.qmarks[key]) or (o.kind == "find" and s.qfound and (s.qfound[o.item] or 0) >= o.n)
						local z = not busy and Quests.progress(prof, q, i, st) < o.n and Quests.place(mapId, o.zone) or nil
						if z and (root.Position - z.pos).Magnitude <= Quests.SPOT_NEAR then
							want[key] = true
							ensurePrompt(player, key, z, o, q.id, i)
						end
					end
				end
			end)
			for key in prompts[player] or {} do
				if not want[key] then
					dropPrompt(player, key)
				end
			end
			if s.qmarks then
				local now = os.clock()
				for key, m in s.qmarks do
					if now >= m.at then
						s.qmarks[key] = nil
						finishMark(player, prof, m)
					end
				end
			end
		end
	end
	for player in prompts do
		if not live[player] then
			dropAll(player)
		end
	end
end
Quests.tick, Quests.act = tick, act -- (the tests drive them with a stand-in raid)

-- ── the end of a raid ─────────────────────────────────────────────────────────────────────────────────────────────
-- every settled raid (Economy.afterRaid): outcome SUCCESS, KIA, MIA, SERVER_CLOSED; runThrough as Raid decided it
function Quests.onRaidEnd(player, prof, s, outcome, runThrough)
	if not (prof and s) or s.qEnded then
		return
	end
	s.qEnded = true
	-- markers set before a successful exit count: the operator is alive
	if outcome == "SUCCESS" then
		for _, m in s.qmarks or {} do
			finishMark(player, prof, m)
		end
	end
	s.qmarks = nil
	-- quest items: kept only by getting out (EFT: lost on a failed extraction; a run-through keeps them). A raid the
	-- server closed keeps everything, as Raid does with the kit
	if (outcome == "SUCCESS" or outcome == "SERVER_CLOSED") and s.qfound then
		local bag = pouch(prof)
		local names = {}
		for id, n in s.qfound do
			bag[id] = (bag[id] or 0) + n
			table.insert(names, Items.defs[id] and Items.defs[id].name or id)
		end
		if #names > 0 then
			toast(player, "QUEST ITEMS KEPT: " .. string.upper(table.concat(names, ", ")))
		end
	end
	s.qfound = nil
	-- a survived extraction counts; a run-through does not (EFT wiki)
	if outcome == "SUCCESS" and not runThrough then
		countExtract(player, prof, s)
	end
	-- objectives that must be done in one raid start again
	eachActive(prof, function(q, st)
		for i, o in q.obj do
			if o.raid and (st.p[tostring(i)] or 0) < o.n then
				st.p[tostring(i)] = 0
			end
		end
	end)
	dropAll(player)
	dirty(player)
end

-- the older hook (Economy.afterRaid on a successful raid): the same end of raid, without knowing a run-through
function Quests.onExtract(player, prof, s)
	if s and not s.qEnded then
		Quests.onRaidEnd(player, prof, s, "SUCCESS", nil)
	end
end

-- ── turning in ────────────────────────────────────────────────────────────────────────────────────────────────────
-- consume found-in-raid items for a hand-in (smallest stacks first); fir == false takes any
local function takeStash(prof, id, n, fir)
	local list = {}
	for g, it in prof.items do
		if it.id == id and (fir == false or it.fir) and inStash(prof, g) then
			table.insert(list, { g = g, it = it })
		end
	end
	table.sort(list, function(a, b)
		return (a.it.n or 1) < (b.it.n or 1)
	end)
	local left = n
	for _, e in list do
		if left <= 0 then
			break
		end
		local k = math.min(left, e.it.n or 1)
		Inv.consume(prof, e.g, k)
		left -= k
	end
	return left <= 0
end

local function takeFor(prof, o)
	local left = o.n
	if isQuestItem(o.item) then
		local bag = pouch(prof)
		local k = math.min(left, bag[o.item] or 0)
		if k > 0 then
			bag[o.item] -= k
			if bag[o.item] <= 0 then
				bag[o.item] = nil
			end
			left -= k
		end
	end
	return left <= 0 or takeStash(prof, o.item, left, o.fir)
end

local function pay(player, prof, q)
	local r = q.reward or {}
	-- zero amounts are left out (EFT's collector pays the container alone, its Trophy XP and standing alone)
	local rew = {}
	if (r.money or 0) > 0 then
		table.insert(rew, Util.commas(r.money) .. " " .. Config.CURRENCY)
	end
	if (r.xp or 0) > 0 then
		table.insert(rew, r.xp .. " XP")
	end
	for _, e in r.items or {} do
		table.insert(rew, Items.defs[e[1]].name .. (((e[2] or 1) > 1) and (" x" .. e[2]) or ""))
	end
	for _, x in TD.unlocksOf(q.id) do
		local d = Items.defs[x.offer.id]
		table.insert(rew, string.format("%s on sale at %s, loyalty %d", d and d.name or x.offer.id, TD.defs[x.trader].name, x.offer.ll))
	end
	if #rew == 0 then
		table.insert(rew, "your standing")
	end
	mail(prof, q.trader, "Task complete: " .. q.name .. ". Your reward: " .. table.concat(rew, ", ") .. ".", "done", q.id)
	-- the intelligence center adds 5 % (level 1) and 15 % (level 2) to task money (EFT; economy-7b)
	prof.money += math.floor((r.money or 0) * (1 + ((ctx.Hideout and ctx.Hideout.bonus(prof, "questMoney")) or 0) / 100))
	local up = ctx.Economy.addXp(prof, r.xp or 0)
	if r.rep then
		ctx.Economy.standing(prof, q.trader).rep += r.rep
	end
	-- a task may cost standing with another trader (EFT's BP Depot: Jaeger -0.01)
	for tid, d in r.reps or {} do
		if TD.defs[tid] and tid ~= "fence" then
			ctx.Economy.standing(prof, tid).rep += d
		end
	end
	if r.karma then
		prof.karma = math.clamp((prof.karma or P.KARMA.start) + r.karma, P.KARMA.min, P.KARMA.max)
	end
	-- reward items arrive like insurance returns: straight to the stash when there is room
	if r.items and #r.items > 0 then
		local bundles = {}
		for _, e in r.items do
			local d = Items.defs[e[1]]
			local left = e[2] or 1
			while left > 0 do
				local take = math.min(left, d.stack)
				local g, it = Inv.newItem(e[1], take)
				it.fir = true
				table.insert(bundles, { g = g, it = it, subs = {}, from = {} })
				left -= take
			end
		end
		table.insert(prof.claims, { readyAt = 0, bundles = bundles, raid = "task:" .. q.id })
	end
	local gain = (r.money or 0) > 0 and string.format("  +%s %s", Util.commas(r.money), Config.CURRENCY) or ""
	toast(player, string.format("TASK COMPLETE: %s%s", string.upper(q.name), gain))
	if up then
		toast(player, "LEVEL UP: " .. ctx.Economy.level(prof))
	end
end

-- hand over what the objectives take, then pay; st: the task's state or the operational task
function Quests.turnIn(player, prof, q, st)
	if not Quests.complete(prof, q, st) then
		return fail("INCOMPLETE", "Objectives are not complete yet.")
	end
	for _, o in q.obj do
		if o.kind == "handin" then
			if not takeFor(prof, o) then
				return fail("INCOMPLETE")
			end
		elseif o.kind == "build" then
			local g = Quests.buildIn(prof, o)
			if not g then
				return fail("INCOMPLETE")
			end
			Inv.consume(prof, g, 1)
		end
	end
	st.s = "claimed"
	pay(player, prof, q)
	return true
end

-- replace an operational task: money and a little standing (EFT wiki: a rouble cost and a reputation penalty)
local function replaceOp(player, prof, inst)
	local money, rep = QD.replaceCost(inst)
	if (prof.money or 0) < money then
		return fail("NOT_ENOUGH_MONEY", "Not enough money.")
	end
	local box = prof.ops[inst.k]
	local idx = box and table.find(box.list, inst)
	if not idx then
		return fail("BAD_INPUT")
	end
	prof.money -= money
	if inst.trader == "fence" then
		prof.karma = math.clamp((prof.karma or P.KARMA.start) - rep, P.KARMA.min, P.KARMA.max)
	else
		local tr = ctx.Economy.standing(prof, inst.trader)
		tr.rep = (tr.rep or 0) - rep
	end
	box.list[idx] = rollInto(prof, inst.k, box.per, inst.ends, inst.slot or idx, (inst.rn or 0) + 1)
	toast(player, "TASK REPLACED")
	return true
end
Quests.replaceOp = replaceOp

local function questReq(player, p)
	local prof = ctx.Profiles.get(player)
	if not prof then
		return fail("NOT_READY")
	end
	if ctx.Raid.session(player) then
		return fail("IN_RAID", "Tasks are managed from the hideout.")
	end
	-- an old save moves to the eight traders first, so a task's standing goes to the trader that gives it now (once)
	ctx.Economy.migrate(prof)
	if type(p.id) ~= "string" or #p.id > 40 then
		return fail("BAD_INPUT")
	end
	Quests.ensureOps(prof)
	local q = QD.byId[p.id]
	local res
	if q then
		local status = Quests.status(prof, q)
		if p.op == "accept" then
			if status ~= "available" then
				return fail("NOT_AVAILABLE")
			end
			prof.quests[q.id] = { s = "active", p = {} }
			-- EFT's trader sends the task's text when you take it
			mail(prof, q.trader, q.name .. ": " .. q.desc, "start", q.id)
			toast(player, "TASK ACCEPTED: " .. string.upper(q.name))
			res = true
		elseif p.op == "turnin" then
			if status ~= "active" then
				return fail("NOT_ACTIVE")
			end
			res = Quests.turnIn(player, prof, q, prof.quests[q.id])
		else
			return fail("BAD_INPUT")
		end
	else
		local inst = opById(prof, p.id)
		if not inst then
			return fail("BAD_INPUT")
		end
		if p.op == "accept" then
			if inst.s ~= "available" then
				return fail("NOT_AVAILABLE")
			end
			inst.s = "active"
			toast(player, "TASK ACCEPTED: " .. string.upper(inst.name))
			res = true
		elseif p.op == "turnin" then
			if inst.s ~= "active" then
				return fail("NOT_ACTIVE")
			end
			res = Quests.turnIn(player, prof, inst, inst)
		elseif p.op == "replace" then
			if inst.s ~= "available" and inst.s ~= "active" then
				return fail("NOT_AVAILABLE")
			end
			res = replaceOp(player, prof, inst)
		else
			return fail("BAD_INPUT")
		end
	end
	if res ~= true then
		return res
	end
	ctx.Raid.afterChange(player, false)
	return ctx.Remotes.ok()
end

-- ── the client's view ─────────────────────────────────────────────────────────────────────────────────────────────
-- every task with its status and progress; besides the task ids: ops (the operational tasks), qitems (the quest-item
-- pouch) and found (quest items picked up in the raid now, not yet kept)
function Quests.stateFor(prof)
	Quests.ensureOps(prof)
	local s = sessionOf(prof)
	local found = s and s.qfound
	local out = {}
	for _, q in QD.list do
		local status = Quests.status(prof, q)
		local prog = {}
		if status == "active" or status == "claimed" then
			for i, o in q.obj do
				local v = (status == "claimed") and o.n or Quests.progress(prof, q, i)
				if status == "active" and o.kind == "find" and found then
					v = math.min(o.n, v + (found[o.item] or 0))
				end
				prog[i] = v
			end
		end
		out[q.id] = { s = status, p = prog }
	end
	local ops = {}
	for _, inst in opsList(prof) do
		local prog = {}
		for i, o in inst.obj do
			prog[i] = (inst.s == "claimed") and o.n or Quests.progress(prof, inst, i, inst)
		end
		local cost, costRep = QD.replaceCost(inst)
		table.insert(ops, {
			id = inst.id, k = inst.k, trader = inst.trader, name = inst.name, obj = inst.obj, reward = inst.reward, s = inst.s, p = prog,
			ends = inst.ends, cost = cost, costRep = costRep,
		})
	end
	out.ops = ops
	out.qitems = table.clone(type(prof.qitems) == "table" and prof.qitems or {})
	out.found = found and table.clone(found) or nil
	return out
end

function Quests.init(c)
	ctx = c
	ctx.Remotes.onReq("quest", questReq, 4, 6)
	spotFolder = workspace:FindFirstChild("ZR_TaskSpots")
	if not spotFolder then
		spotFolder = Instance.new("Folder")
		spotFolder.Name = "ZR_TaskSpots"
		spotFolder.Parent = workspace
	end
	Players.PlayerRemoving:Connect(dropAll)
end

function Quests.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ZR] quest tick", err)
			end
		end
	end)
end

return Quests

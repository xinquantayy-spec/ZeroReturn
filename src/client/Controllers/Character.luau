--!nonstrict
-- Tarkov's character tabs inside the inventory screen (docs/design/EFT_PARITY.md section 3): HEALTH (the body by part
-- with bleeding and fractures, energy, hydration, weight and effects), SKILLS, MASTERING (weapon mastering by group,
-- docs/design/MASTERING.md), OVERALL (out of raid: level, raids, survival rate, kills, karma) and TASKS (in and out of a
-- raid: active tasks and their progress, pinned ones first). GEAR stays the inventory itself.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local QD = require(Shared.QuestData)
local P = require(Shared.Progress)
local TD = require(Shared.TraderData)

local Character = {}
local ctx, K

-- ── pinned tasks (audit ui.14) ──────────────────────────────────────────────────
-- Tarkov 0.16.7 pins tasks "at the top of the list on the task tab" (patch notes); here the character's TASKS tab and each
-- trader's TASKS tab. Only an active task takes a pin (AltChar: "pinning active quests"). The pins are kept in the
-- profile's settings (pins = { [task id] = true }, the settings request's `pin`), so they last across sessions.
function Character.isPinned(id)
	local pins = ctx and ctx.Settings.data.pins
	return type(pins) == "table" and pins[id] == true
end

function Character.setPin(id, on)
	local S = ctx.Settings.data
	if type(S.pins) ~= "table" then
		S.pins = {}
	end
	S.pins[id] = on and true or nil
	task.spawn(ctx.State.req, "settings", { pin = { id = id, on = on == true } })
end

-- the tasks of `list` with the pinned active ones first, each part in the list's own order
function Character.pinnedFirst(list, d)
	local top, rest = {}, {}
	for _, q in list do
		local qs = d and d.quests and d.quests[q.id]
		if qs and qs.s == "active" and Character.isPinned(q.id) then
			table.insert(top, q)
		else
			table.insert(rest, q)
		end
	end
	for _, q in rest do
		table.insert(top, q)
	end
	return top
end

local PARTS = {
	-- body diagram: part, label, column (0..2), row (0..3)
	{ "head", "HEAD", 1, 0 }, { "larm", "LEFT ARM", 0, 1 }, { "thorax", "THORAX", 1, 1 }, { "rarm", "RIGHT ARM", 2, 1 },
	{ "stomach", "STOMACH", 1, 2 }, { "lleg", "LEFT LEG", 0.5, 3 }, { "rleg", "RIGHT LEG", 1.5, 3 },
}

local function bar(parent, x, y, w, frac, color)
	local track = K.frame(parent, { BackgroundColor3 = K.C.panel2, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 6) })
	K.frame(track, { BackgroundColor3 = color, Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) })
end

local function health(f, w, h)
	local v = ctx.State.vitals
	local inRaid = ctx.State.inRaid()
	local bw, bh = math.min(170, math.floor((w * 0.55 - 40) / 3)), 74
	local ox = 10
	K.label(f, "HEALTH", 15, { FontFace = K.bold, Position = UDim2.fromOffset(ox, 0), Size = UDim2.fromOffset(300, 20) })
	if not (inRaid and v and v.parts) then
		K.label(f, "Out of the raid your operator recovers slowly in the bunker, faster with the medstation. Wounds that have not healed are still there when the next raid starts.", 12, {
			Position = UDim2.fromOffset(ox, 24), Size = UDim2.fromOffset(w * 0.55, 34), TextWrapped = true, TextColor3 = K.C.dim,
		})
	end
	for _, e in PARTS do
		local p = v and v.parts and v.parts[e[1]]
		local hp, max, bleed, frac = p and p[1], p and p[2], p and p[3] or 0, p and p[4]
		local x, y = ox + math.floor(e[3] * (bw + 10)), 60 + e[4] * (bh + 10)
		local box = K.frame(f, { Name = "Part_" .. e[1], Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(bw, bh), BackgroundColor3 = K.C.panel })
		local col = K.C.line
		if hp then
			local fr = max > 0 and hp / max or 0
			col = hp <= 0 and K.C.red or fr < 0.4 and K.C.orange or fr < 0.75 and K.C.ochre or K.C.green
		end
		K.stroke(box, col, 0.3)
		K.label(box, e[2], 11, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 14), TextColor3 = K.C.dim })
		K.label(box, hp and (hp <= 0 and "DESTROYED" or string.format("%d / %d", hp, max)) or "FULL", 15, {
			Position = UDim2.fromOffset(6, 20), Size = UDim2.new(1, -12, 0, 20), FontFace = K.bold, TextColor3 = hp and hp <= 0 and K.C.red or K.C.text,
		})
		if hp then
			bar(box, 6, 44, bw - 12, max > 0 and hp / max or 0, col)
		end
		local marks = {}
		if bleed == 2 then
			table.insert(marks, "HEAVY BLEEDING")
		elseif bleed == 1 then
			table.insert(marks, "LIGHT BLEEDING")
		end
		if frac then
			table.insert(marks, "FRACTURE")
		end
		if #marks > 0 then
			K.label(box, table.concat(marks, " · "), 10, { Position = UDim2.fromOffset(6, 54), Size = UDim2.new(1, -12, 0, 14), TextColor3 = K.C.orange, TextTruncate = Enum.TextTruncate.AtEnd })
		end
	end
	-- the right side: totals, energy and hydration, weight against the limits, effects
	local rx, rw = math.floor(w * 0.6), math.floor(w * 0.38)
	local y = 24
	local function line(label, value, frac, color)
		K.label(f, label, 12, { Position = UDim2.fromOffset(rx, y), Size = UDim2.fromOffset(rw * 0.6, 16), TextColor3 = K.C.dim })
		K.label(f, value, 13, { Position = UDim2.fromOffset(rx + rw * 0.6, y), Size = UDim2.fromOffset(rw * 0.4, 16), TextXAlignment = Enum.TextXAlignment.Right, FontFace = K.bold })
		if frac then
			bar(f, rx, y + 18, rw, frac, color or K.C.text)
		end
		y += frac and 32 or 22
	end
	if v and inRaid then
		line("HEALTH", string.format("%d / %d", math.ceil(v.hp), math.floor(v.max)), v.hp / math.max(1, v.max), K.C.green)
		line("ENERGY", string.format("%d / 100", math.floor(v.energy or 0)), (v.energy or 0) / 100, K.C.ochre)
		line("HYDRATION", string.format("%d / 100", math.floor(v.water or 0)), (v.water or 0) / 100, Color3.fromHex("6FA3C8"))
	else
		line("HEALTH", "FULL")
		line("ENERGY", "100 / 100", 1, K.C.ochre)
		line("HYDRATION", "100 / 100", 1, Color3.fromHex("6FA3C8"))
	end
	local M = ctx.Movement
	local lim = M and M.limits
	local wkg = M and M.weight or 0
	if lim then
		line("WEIGHT", string.format("%.1f kg  ·  OVERWEIGHT AT %.0f kg", wkg, lim.over), wkg / lim.max, wkg > lim.crit and K.C.red or wkg > lim.over and K.C.orange or K.C.text)
	end
	local gear = M and M.gear
	if gear and (gear.speed ~= 0 or gear.turn ~= 0 or gear.ergo ~= 0) then
		line("GEAR PENALTIES", string.format("MOVE %d%%  ·  TURN %d%%  ·  ERGO %d%%", gear.speed, gear.turn, gear.ergo))
	end
	y += 6
	K.label(f, "EFFECTS", 12, { Position = UDim2.fromOffset(rx, y), Size = UDim2.fromOffset(rw, 16), FontFace = K.bold })
	y += 18
	local fx = (inRaid and v and v.effects) or {}
	if #fx == 0 then
		K.label(f, "None.", 12, { Position = UDim2.fromOffset(rx, y), Size = UDim2.fromOffset(rw, 16), TextColor3 = K.C.dim })
	end
	for _, e in fx do
		K.label(f, e.label, 12, { Position = UDim2.fromOffset(rx, y), Size = UDim2.fromOffset(rw, 16), TextColor3 = e.color or K.C.text })
		y += 18
	end
end

local function skills(f, w)
	local d = ctx.State.data
	local econ = d and d.econ or {}
	K.label(f, "SKILLS", 15, { FontFace = K.bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(300, 20) })
	-- Tarkov's skills screen: by category, level 0 to 51 (elite), the bar is progress into the next level
	local sf = K.new("ScrollingFrame", {
		Name = "Skills", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24),
		CanvasSize = UDim2.new(), ScrollBarThickness = 5, Selectable = false,
	}, f)
	local cols = w > 900 and 3 or 2
	local cw = math.floor((w - 20 - (cols - 1) * 10) / cols)
	local y, n = 0, 0
	local cat
	for _, id in P.SKILL_ORDER do
		local def = P.SKILLS[id]
		if def.cat ~= cat then
			if n % cols ~= 0 then
				y += 64
			end
			n = 0
			cat = def.cat
			K.label(sf, cat, 12, { Position = UDim2.fromOffset(10, y + 4), Size = UDim2.fromOffset(300, 16), TextColor3 = K.C.ochre })
			y += 24
		end
		local pts = (econ.skills and econ.skills[id]) or 0
		local lvl, into, cost = P.skillProgress(pts)
		local col = n % cols
		local box = K.frame(sf, { Name = "Skill_" .. id, BackgroundColor3 = K.C.panel, Position = UDim2.fromOffset(10 + col * (cw + 10), y), Size = UDim2.fromOffset(cw, 58) })
		K.label(box, string.upper(def.name), 13, { FontFace = K.bold, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(0.65, 0, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		K.label(box, lvl >= P.SKILL_MAX and "ELITE" or ("LEVEL " .. lvl), 12, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.new(0.35, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = lvl >= P.SKILL_MAX and K.C.ochre or K.C.text })
		bar(box, 8, 24, cw - 16, lvl >= P.SKILL_MAX and 1 or into / math.max(1, cost), K.C.ochre)
		K.label(box, def.desc, 10, { Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 0, 24), TextWrapped = true, TextColor3 = K.C.dim, TextYAlignment = Enum.TextYAlignment.Top })
		n += 1
		if n % cols == 0 then
			y += 64
		end
	end
	if n % cols ~= 0 then
		y += 64
	end
	sf.CanvasSize = UDim2.fromOffset(0, y + 10)
end

-- Tarkov's MASTERING tab: every weapon group under its weapon class, with its level ("WEAPON MASTERING (02)"), a bar to
-- the next level and what each level gives (written out: touch has no hover). Every entry takes the gamepad selection,
-- so a controller moves down the list and the frame scrolls to it; on narrow screens the list is one column.
local function mastering(f, w)
	local d = ctx.State.data
	local econ = d and d.econ or {}
	local pts = econ.mastering or {}
	K.label(f, "MASTERING", 15, { FontFace = K.bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(300, 20) })
	K.label(f, "Every hit on a living target with a weapon of the group adds one point; every shotgun pellet that hits counts.", 11, {
		Position = UDim2.fromOffset(10, 22), Size = UDim2.fromOffset(w - 20, 28), TextWrapped = true, TextColor3 = K.C.dim,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local ROW = 84
	local cols = w > 760 and 2 or 1
	local cw = math.floor((w - 20 - (cols - 1) * 10) / cols)
	local y, n, cls = 52, 0, nil
	for _, gid in P.MASTERY_ORDER do
		local g = P.MASTERING[gid]
		if g.class ~= cls then
			if n % cols ~= 0 then
				y += ROW
			end
			n = 0
			cls = g.class
			K.label(f, cls, 12, { Position = UDim2.fromOffset(10, y + 2), Size = UDim2.fromOffset(300, 16), TextColor3 = K.C.ochre })
			y += 22
		end
		local p = pts[gid] or 0
		local lvl, a, b = P.masteryProgress(gid, p)
		local top = lvl >= P.MASTERY_MAX
		local box = K.frame(f, {
			Name = "Mastery_" .. gid, BackgroundColor3 = K.C.panel, Position = UDim2.fromOffset(10 + (n % cols) * (cw + 10), y),
			Size = UDim2.fromOffset(cw, ROW - 6), Selectable = true, SelectionImageObject = K.selection(),
		})
		K.label(box, string.upper(g.name), 13, { FontFace = K.bold, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(0.42, 0, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		K.label(box, string.format("WEAPON MASTERING (%02d)", lvl), 12, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.new(0.58, -8, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = top and K.C.ochre or K.C.text,
		})
		bar(box, 8, 26, cw - 16, top and 1 or (p - a) / math.max(1, b - a), K.C.ochre)
		K.label(box, top and (Util.commas(p) .. "  ·  MAX") or (Util.commas(p) .. " / " .. Util.commas(b)), 11, {
			Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 0, 14), TextColor3 = K.C.dim,
		})
		-- what the levels give, bright once reached
		for i, lv in { 2, 3 } do
			K.label(box, string.format("(%02d)  %s", lv, P.MASTERY_PERKS[lv]), 10, {
				Position = UDim2.fromOffset(8, 36 + i * 13), Size = UDim2.new(1, -16, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = lvl >= lv and K.C.text or K.C.dim,
			})
		end
		n += 1
		if n % cols == 0 then
			y += ROW
		end
	end
	if n % cols ~= 0 then
		y += ROW
	end
	return y
end

local function overall(f, w)
	local d = ctx.State.data
	local econ = d and d.econ or {}
	local s = d and d.stats or {}
	local lvl = econ.level or 1
	local xp = econ.xp or 0
	local a, b = P.xpFor(lvl), P.xpFor(lvl + 1)
	K.label(f, string.format("%s  ·  LEVEL %d", string.upper(game:GetService("Players").LocalPlayer.Name), lvl), 15, { FontFace = K.bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(w - 20, 20) })
	bar(f, 10, 26, math.min(500, w - 20), (xp - a) / math.max(1, b - a), K.C.ochre)
	K.label(f, string.format("%s / %s XP TO LEVEL %d", Util.commas(xp), Util.commas(b), lvl + 1), 11, { Position = UDim2.fromOffset(10, 36), Size = UDim2.fromOffset(500, 14), TextColor3 = K.C.dim })
	local raids = s.raids or 0
	local rows = {
		{ "RAIDS", raids }, { "SURVIVED", s.survived or 0 }, { "KILLED IN ACTION", s.kia or 0 }, { "MISSING IN ACTION", s.mia or 0 },
		{ "SURVIVAL RATE", raids > 0 and string.format("%d%%", math.floor((s.survived or 0) / raids * 100 + 0.5)) or "-" },
		{ "KILLS", s.kills or 0 }, { "PMC KILLS", s.pmcKills or 0 }, { "SCAV KILLS", s.scavKills or 0 }, { "BOSS KILLS", s.bossKills or 0 },
		{ "SCAV RAIDS", s.scavRaids or 0 }, { "SCAV RAIDS SURVIVED", s.scavSurvived or 0 },
		{ "VALUE EXTRACTED", Util.commas(s.extractedValue or 0) .. " " .. Config.CURRENCY },
		{ "FENCE KARMA", string.format("%.2f", econ.karma or 0) }, { "MONEY", Util.commas(d and d.money or 0) .. " " .. Config.CURRENCY },
	}
	local cols = 2
	local cw = math.floor((math.min(w, 900) - 20 - 10) / cols)
	for i, r in rows do
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		local box = K.frame(f, { Name = "Stat_" .. i, BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(10 + col * (cw + 10), 60 + row * 30), Size = UDim2.fromOffset(cw, 26) })
		K.label(box, r[1], 12, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), TextColor3 = K.C.dim })
		K.label(box, tostring(r[2]), 13, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, FontFace = K.bold })
	end
end

-- an objective's line: what it asks, with the item it names (decision economy-6a: quest items, plants, builds)
function Character.objectiveText(o)
	local what = QD.describe(o)
	if o.kind == "handin" then
		what ..= ": " .. Items.defs[o.item].name
	end
	return what
end

-- time left on an operational task (EFT shows the timer on dailies and weeklies)
function Character.timeLeft(ends, now)
	local s = math.max(0, (ends or now) - now)
	if s >= 86400 then
		return string.format("%dd %dh", s // 86400, (s % 86400) // 3600)
	end
	return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
end

-- the active tasks of every trader, pinned ones first (audit ui.14), each with its objectives and progress; PIN keeps
-- one at the top here and in its trader's list. Turning in stays at the trader, as in Tarkov. Below them: the active
-- operational tasks with their timers and the quest items you carry or keep (EFT's quest-item pouch; economy-6a).
local function tasks(f, w)
	local d = ctx.State.data
	local big = K.viewport().Y < 500 -- a phone: finger-sized PIN buttons (ui-3a)
	local btnW, btnH = big and 104 or 86, big and 36 or 22
	K.label(f, "TASKS", 15, { FontFace = K.bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(300, 20) })
	K.label(f, "Pinned tasks stay at the top of this list and of the trader's. Tasks are taken and turned in at the traders.", 11, {
		Position = UDim2.fromOffset(10, 20), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local y = 42
	local list = {}
	for _, q in QD.list do
		local qs = d and d.quests and d.quests[q.id]
		if qs and qs.s == "active" then
			table.insert(list, q)
		end
	end
	for _, q in Character.pinnedFirst(list, d) do
		local qs = d.quests[q.id]
		local pinned = Character.isPinned(q.id)
		local done = true
		for i, o in q.obj do
			if ((qs.p and qs.p[i]) or 0) < o.n then
				done = false
			end
		end
		local tr = TD.defs[q.trader]
		local head = string.upper(q.name) .. "   ·   " .. (tr and tr.name or string.upper(tostring(q.trader))) .. (done and "   ·   READY TO TURN IN" or "")
		K.label(f, head, 13, {
			FontFace = K.bold, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 30 - btnW, btnH), TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = done and K.C.green or (pinned and K.C.ochre or K.C.text),
		})
		local pb = K.button(f, pinned and "PINNED" or "PIN", {
			Name = "Pin_" .. q.id, Position = UDim2.fromOffset(w - 10 - btnW, y), Size = UDim2.fromOffset(btnW, btnH), TextSize = big and 13 or 11,
			TextColor3 = pinned and K.C.ochre or K.C.dim,
		})
		pb.Activated:Connect(function()
			Character.setPin(q.id, not pinned)
			if ctx.Inventory.open then
				ctx.Inventory.render()
			end
		end)
		y += btnH + 4
		for i, o in q.obj do
			local p = (qs.p and qs.p[i]) or 0
			local what = Character.objectiveText(o)
			K.label(f, string.format("  •  %s   %d/%d", what, math.min(p, o.n), o.n), 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = p >= o.n and K.C.green or K.C.text, TextTruncate = Enum.TextTruncate.AtEnd })
			y += 18
		end
		y += 10
	end
	-- operational tasks taken (dailies, weeklies, Fence's scav task)
	local now = (d and d.serverTime) or os.time()
	local opsActive = 0
	for _, inst in (d and d.quests and d.quests.ops) or {} do
		if inst.s == "active" then
			opsActive += 1
			local done = true
			for i, o in inst.obj do
				if ((inst.p and inst.p[i]) or 0) < o.n then
					done = false
				end
			end
			local tr = TD.defs[inst.trader]
			local head = string.format("%s   ·   %s   ·   %s LEFT%s", inst.name, tr and tr.name or string.upper(inst.trader), Character.timeLeft(inst.ends, now), done and "   ·   READY TO TURN IN" or "")
			K.label(f, head, 13, { FontFace = K.bold, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 18), TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = done and K.C.green or K.C.ochre })
			y += 20
			for i, o in inst.obj do
				local p = (inst.p and inst.p[i]) or 0
				K.label(f, string.format("  •  %s   %d/%d", Character.objectiveText(o), math.min(p, o.n), o.n), 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = p >= o.n and K.C.green or K.C.text, TextTruncate = Enum.TextTruncate.AtEnd })
				y += 18
			end
			y += 10
		end
	end
	if #list == 0 and opsActive == 0 then
		K.label(f, "No active tasks. Take tasks from the traders in the bunker.", 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = K.C.dim })
		y += 20
	end
	-- quest items (EFT: they ride in their own pouch, are kept only by extracting, and wait to be handed over)
	local names = {}
	for id, n in (d and d.quests and d.quests.qitems) or {} do
		if n > 0 and Items.defs[id] then
			table.insert(names, Items.defs[id].name .. (n > 1 and (" x" .. n) or ""))
		end
	end
	local carried = {}
	for id, n in (d and d.quests and d.quests.found) or {} do
		if n > 0 and Items.defs[id] then
			table.insert(carried, Items.defs[id].name .. (n > 1 and (" x" .. n) or ""))
		end
	end
	if #names > 0 or #carried > 0 then
		y += 4
		K.label(f, "QUEST ITEMS", 13, { FontFace = K.bold, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 18) })
		y += 20
		if #carried > 0 then
			K.label(f, "  •  Found this raid (extract to keep): " .. table.concat(carried, ", "), 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = K.C.ochre, TextTruncate = Enum.TextTruncate.AtEnd })
			y += 18
		end
		if #names > 0 then
			K.label(f, "  •  Waiting to be handed over: " .. table.concat(names, ", "), 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = K.C.text, TextTruncate = Enum.TextTruncate.AtEnd })
			y += 18
		end
	end
	return y
end

-- draw a tab into the scrolling frame f (w wide); returns the content height
function Character.draw(tab, f, w, h)
	if tab == "HEALTH" then
		health(f, w, h)
		return 400
	elseif tab == "SKILLS" then
		skills(f, w)
		return 26 + math.ceil(#P.SKILL_ORDER / (w > 900 and 3 or 2)) * 76
	elseif tab == "MASTERING" then
		return mastering(f, w) + 10
	elseif tab == "OVERALL" then
		overall(f, w)
		return 60 + 7 * 30
	elseif tab == "TASKS" then
		return tasks(f, w) + 10
	end
	return 0
end

function Character.init(c)
	ctx = c
	K = c.UiKit
end

return Character

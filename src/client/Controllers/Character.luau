--!nonstrict
-- Tarkov's character tabs inside the inventory screen (docs/design/EFT_PARITY.md section 3): HEALTH (the body by part
-- with bleeding and fractures, energy, hydration, weight and effects), SKILLS, OVERALL (out of raid: level, raids,
-- survival rate, kills, karma) and TASKS (in a raid: active tasks and their progress). GEAR stays the inventory itself.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local QD = require(Shared.QuestData)
local P = require(Shared.Progress)

local Character = {}
local ctx, K

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
		K.label(f, "Out of the raid your operator is treated and rested: every body part is at full health.", 12, {
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

local function tasks(f, w)
	local d = ctx.State.data
	K.label(f, "TASKS", 15, { FontFace = K.bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(300, 20) })
	local y = 26
	local any = false
	for _, q in QD.list do
		local qs = d and d.quests and d.quests[q.id]
		if qs and qs.s == "active" then
			any = true
			K.label(f, string.upper(q.name) .. "   ·   " .. (ctx.State.data.econ and q.trader and string.upper(q.trader) or ""), 13, { FontFace = K.bold, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 18) })
			y += 20
			for i, o in q.obj do
				local p = (qs.p and qs.p[i]) or 0
				local what = QD.describe(o)
				if o.kind == "handin" then
					what ..= ": " .. Items.defs[o.item].name
				end
				K.label(f, string.format("  •  %s   %d/%d", what, math.min(p, o.n), o.n), 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = p >= o.n and K.C.green or K.C.text })
				y += 18
			end
			y += 8
		end
	end
	if not any then
		K.label(f, "No active tasks. Take tasks from the traders in the bunker.", 12, { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(w - 20, 16), TextColor3 = K.C.dim })
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

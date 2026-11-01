--!nonstrict
-- Bodycam HUD, R.E.P.O.-inspired presentation (original implementation): tall condensed numerals with
-- RGB split + glow, spring "pop" on change, everything bent through the recorder lens (see Lens.luau).
-- Tarkov rules: no ammo counter, no hit markers, no damage-direction arrows; extract list on demand.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Env = require(Shared.Env)
local Maps = require(Shared.Maps)
local Sounds = require(Shared.Sounds)
local Textures = require(Shared.Textures)
local Lens = require(script.Parent.Lens)

local Hud = {}
local ctx, K, L
local player = Players.LocalPlayer
local gui, deathFade
local O = {}
local I = Textures.ICON
local ex, search, heal, progress = nil, nil, nil, nil
local toasts, toastSlot = {}, 0
local notice = { t = -10, dur = 0 }
local exitsUntil, squadUntil = 0, 0
local acc, lastYaw, swayX, swayY = 0, 0, 0, 0
local lastHp, lastMoney = nil, nil
local hitT = -1

local C = {
	green = Color3.fromRGB(95, 255, 112), greenDim = Color3.fromRGB(62, 178, 76),
	yellow = Color3.fromRGB(255, 230, 62), yellowDim = Color3.fromRGB(196, 172, 48),
	orange = Color3.fromRGB(255, 134, 52), orangeDim = Color3.fromRGB(196, 100, 42),
	red = Color3.fromRGB(255, 56, 44), white = Color3.fromRGB(242, 244, 236), dim = Color3.fromRGB(168, 174, 166),
	blue = Color3.fromRGB(96, 192, 255),
}
Hud.C = C

local function txt(name, at, size, align, extra)
	local o = { name = name, at = at, size = size, align = align or 0, glow = 0.86 }
	for k, v in extra or {} do
		o[k] = v
	end
	return L:text(o)
end

-- Text sizes at 1080p (the lens scales them with the screen and the HUD SCALE setting). Large enough to read
-- at a glance; everything is stacked in the margins (layout()) so the centre of the view stays clear.
local SZ = {
	hp = 78, st = 64, needs = 40, status = 36, rec = 46, dev = 26, clock = 66, exit = 34,
	notice = 84, noticeSub = 34, progLabel = 34, progBar = 34, weapon = 32, squadHead = 36, squad = 32,
	toast = 32, death = 90, deathSub = 34, match = 32,
}
Hud.SZ = SZ
local MAX_EXITS = 6
local toastTop, toastStep, squadBottom, squadStep = 0.36, 0.04, 0.93, 0.045
local SIDE_L, SIDE_R = 0.04, 0.96

-- stack objects downward from y0 (pixels); each entry = { obj, size }; returns the y below the last one
local function stack(list, x, y0, gap)
	local u, H = L.unit, math.max(1, L.H)
	local y = y0
	for _, e in list do
		y += e[2] * u * 0.5
		e[1]:setAt(x, y / H)
		y += e[2] * u * 0.5 + gap
	end
	return y
end

local function layout()
	L:resize()
	local u, H = L.unit, math.max(1, L.H)
	local gap = 7 * u
	local top = 0.058 * H + 4 * u
	-- vitals (top-left), toasts below them
	local leftEnd = stack({ { O.hp, SZ.hp }, { O.st, SZ.st }, { O.needs, SZ.needs }, { O.status, SZ.status } }, SIDE_L, top, gap)
	toastTop = (leftEnd + 10 * u + SZ.toast * u * 0.5) / H
	toastStep = (SZ.toast * u + gap) / H
	-- recorder line, clock and the exits list (top-right)
	local rightEnd = stack({ { O.rec, SZ.rec }, { O.dev, SZ.dev }, { O.clock, SZ.clock } }, SIDE_R, top, gap)
	local exits = {}
	for _, o in O.exits do
		table.insert(exits, { o, SZ.exit })
	end
	stack(exits, SIDE_R, rightEnd + 4 * u, gap * 0.7)
	-- notices sit above the sight line, progress below it
	local ny = 0.19 * H
	O.notice:setAt(0.5, ny / H)
	O.noticeSub:setAt(0.5, (ny + (SZ.notice + SZ.noticeSub) * 0.5 * u + gap) / H)
	local py = 0.74 * H
	O.progLabel:setAt(0.5, py / H)
	O.progBar:setAt(0.5, (py + (SZ.progLabel + SZ.progBar) * 0.5 * u + gap * 0.5) / H)
	-- bottom edge: weapon line (centre), squad roster (left, grows upward)
	local bottom = 0.955 * H - 4 * u
	O.weapon:setAt(0.5, (bottom - SZ.weapon * u * 0.5) / H)
	O.match:setAt(0.5, (bottom - SZ.weapon * u - gap - SZ.match * u * 0.5) / H)
	squadBottom = (bottom - SZ.squad * u * 0.5) / H
	squadStep = (SZ.squad * u + gap * 0.6) / H
	-- death card
	O.death:setAt(0.5, 0.45)
	O.deathSub:setAt(0.5, (0.45 * H + (SZ.death + SZ.deathSub) * 0.5 * u + gap) / H)
end
Hud.layout = layout

local function build()
	gui = K.screen("ZR_HUD", 5)
	gui.ScreenInsets = Enum.ScreenInsets.None
	L = Lens.new(gui, { k = 0.11 })
	Lens.prewarm(Lens.FONT, "0123456789:/+-.,%$ ABCDEFGHIJKLMNOPQRSTUVWXYZ·|()[]")
	Lens.prewarm(Lens.FONT_MED, "0123456789:/+-.,% ABCDEFGHIJKLMNOPQRSTUVWXYZ·|()")
	local V0 = Vector2.new(0.5, 0.5)
	-- vitals (top-left)
	O.hp = txt("Health", V0, SZ.hp)
	O.st = txt("Stamina", V0, SZ.st)
	O.needs = txt("Needs", V0, SZ.needs, 0, { font = Lens.FONT_MED, glow = nil })
	O.status = txt("Status", V0, SZ.status, 0, { font = Lens.FONT_MED, glow = nil })
	-- recorder overlay (top-right)
	O.rec = txt("Rec", V0, SZ.rec, 1, { glow = 0.9 })
	O.dev = txt("Device", V0, SZ.dev, 1, { font = Lens.FONT_MED, glow = nil, ca = 0.6 })
	O.clock = txt("Clock", V0, SZ.clock, 1)
	O.exits = {}
	for i = 1, MAX_EXITS do
		O.exits[i] = txt("Exit" .. i, V0, SZ.exit, 1, { font = Lens.FONT_MED, glow = nil })
	end
	-- centre notices (R.E.P.O.-style big value pop)
	O.notice = txt("Notice", V0, SZ.notice, 0.5, { glow = 0.8 })
	O.noticeSub = txt("NoticeSub", V0, SZ.noticeSub, 0.5, { font = Lens.FONT_MED })
	O.dot = L:icon({ name = "Dot", at = Vector2.new(0.5, 0.5), size = 10, align = 0.5, index = I.DOT, color = C.white, ca = 0, alpha = 0.25 })
	-- progress: label + "|" bar (bends with the lens)
	O.progLabel = txt("ProgLabel", V0, SZ.progLabel, 0.5, { font = Lens.FONT_MED })
	O.progBar = txt("ProgBar", V0, SZ.progBar, 0.5, { glow = 0.9, tracking = 0.12 })
	-- weapon line (bottom centre) and the hideout raid status above it
	O.weapon = txt("Weapon", V0, SZ.weapon, 0.5, { font = Lens.FONT_MED, glow = nil })
	O.match = txt("Match", V0, SZ.match, 0.5, { font = Lens.FONT_MED, glow = nil })
	O.match:show(false)
	-- squad (bottom-left)
	O.squad = {}
	for i = 1, 1 + 5 do
		O.squad[i] = txt("Squad" .. i, V0, i == 1 and SZ.squadHead or SZ.squad, 0, { glow = nil, font = i == 1 and Lens.FONT or Lens.FONT_MED })
		O.squad[i]:show(false)
	end
	-- toasts (left)
	for i = 1, 5 do
		toasts[i] = { o = txt("Toast" .. i, V0, SZ.toast, 0, { font = Lens.FONT_MED, glow = nil }), t = -10 }
		toasts[i].o:show(false)
	end
	-- camcorder corner brackets
	local a = 0.55
	O.brackets = {}
	for _, c in { { 0.024, 0.04, 1, 1 }, { 0.976, 0.04, -1, 1 }, { 0.024, 0.96, 1, -1 }, { 0.976, 0.96, -1, -1 } } do
		local x, y, dx, dy = c[1], c[2], c[3], c[4]
		table.insert(O.brackets, L:line({ a = Vector2.new(x, y), b = Vector2.new(x + dx * 0.045, y), thick = 2, color = C.white, alpha = a, segments = 3 }))
		table.insert(O.brackets, L:line({ a = Vector2.new(x, y), b = Vector2.new(x, y + dy * 0.07), thick = 2, color = C.white, alpha = a, segments = 3 }))
	end
	-- death
	deathFade = K.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 0 })
	O.death = txt("Death", V0, SZ.death, 0.5, { glow = 0.75 })
	O.deathSub = txt("DeathSub", V0, SZ.deathSub, 0.5, { font = Lens.FONT_MED })
	O.death:show(false)
	O.deathSub:show(false)
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
end

function Hud.toast(text, tone)
	toastSlot = toastSlot % #toasts + 1
	local slot = toasts[toastSlot]
	slot.t = os.clock()
	slot.o:set({ { t = string.upper(text), color = (tone == "warn" and C.orange) or (tone == "good" and C.green) or (tone == "bad" and C.red) or C.white } })
	slot.o:show(true)
	slot.o:pop(0.18)
end

-- big centre value, e.g. "+840 MK" when selling or "EXFIL 4.2"
function Hud.notice(main, sub, color, dur)
	notice = { t = os.clock(), dur = dur or 2.2, main = main, sub = sub, color = color or C.white }
	O.notice:set({ { t = main, color = notice.color } })
	O.noticeSub:set({ { t = sub or "", color = C.dim } })
	O.notice:pop(0.35)
end

function Hud.showExits()
	exitsUntil = os.clock() + 6
end

-- O: a time check (the raid clock pops; Tarkov 0.16.7 keeps the timer on screen)
function Hud.timeCheck()
	if O.clock and ctx.State.inRaid() then
		O.clock:pop(0.2)
	end
end

local function compass(v)
	local ang = math.deg(math.atan2(v.X, -v.Z)) % 360
	local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	return names[math.floor((ang + 22.5) / 45) % 8 + 1]
end
Hud.compass = compass

-- vitals provider: M4 health model publishes richer data into State.vitals
local function vitals()
	local v = ctx.State.vitals
	if v then
		return v
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return { hp = hum and hum.Health or 0, max = hum and hum.MaxHealth or 100 }
end

local function slowUpdate()
	local d = ctx.State.data
	local inRaid = ctx.State.inRaid()
	local raid = ctx.State.raid
	local now = workspace:GetServerTimeNow()
	local S = ctx.Settings.data
	-- recorder line
	local blink = math.floor(os.clock() * 1.6) % 2 == 0
	-- in a raid the recorder shows the raid's in-world time (7x real time); in the hideout, local time
	local stamp
	if inRaid and raid and raid.env then
		stamp = os.date("!%Y-%m-%d", math.floor(now)) .. "  " .. os.date("!%H:%M:%S", math.floor(Env.clock(raid.env, now) * 3600))
	else
		stamp = os.date("%Y-%m-%d  %H:%M:%S", math.floor(os.time()))
	end
	-- the bodycam stands by in the bunker and starts recording when the van doors slam (Lobby) or in the raid
	if inRaid or Hud.recording then
		O.rec:set({ { icon = I.DOT, color = C.red, alpha = blink and 0 or 0.85, size = SZ.rec * 0.66 }, { t = "REC", color = C.red }, { t = "   " .. stamp, size = SZ.rec * 0.78, color = C.white } })
	else
		O.rec:set({ { icon = I.DOT, color = C.white, alpha = 0.55, size = SZ.rec * 0.66 }, { t = "STBY", color = C.white }, { t = "   " .. stamp, size = SZ.rec * 0.78, color = C.white } })
	end
	O.dev:set({ { t = "ZR BODYCAM 4  ·  X7F3A21  ·  " .. (inRaid and Maps.nameOf(raid and raid.map) or "RELAY 7"), color = C.dim, alpha = 0.2 } })
	-- clock / money
	if inRaid and raid then
		local left = math.max(0, raid.endsAt - now)
		O.clock:set({ { t = Util.clock(left), color = left < 120 and C.red or C.orange }, { t = " LEFT", size = SZ.clock * 0.45, color = C.orangeDim, top = true } })
		if left < 60 and math.floor(left) % 10 == 0 then
			O.clock:pop(0.12)
		end
	else
		local money = d and d.money or 0
		O.clock:set({ { t = Util.commas(money), color = C.green }, { t = " " .. Config.CURRENCY, size = SZ.clock * 0.45, color = C.greenDim, top = true } })
		if lastMoney and money ~= lastMoney then
			O.clock:pop(0.3)
			local diff = money - lastMoney
			Hud.notice((diff > 0 and "+" or "") .. Util.commas(diff) .. " " .. Config.CURRENCY, nil, diff > 0 and C.green or C.red, 1.6)
		end
		lastMoney = money
	end
	-- extract list (Tarkov: names and requirements only, on demand; no distances or markers)
	local showEx = inRaid and raid and os.clock() < exitsUntil
	for i, o in O.exits do
		local e = (showEx and raid.extracts) and raid.extracts[i] or nil
		o:show(e ~= nil)
		if e then
			local status, col = Hud.exitStatus(e)
			o:set({ { icon = I.EXIT, color = col, size = SZ.exit * 0.85 }, { t = string.format(" EXFIL %s  ·  %s", e.id, string.upper(e.name)), color = C.white }, { t = status ~= "" and ("  " .. status) or "", color = col } })
		end
	end
	-- hideout: raid status line (bottom centre)
	local m = ctx.State.match
	if not inRaid and m then
		O.match:show(true)
		O.match:set(Hud.matchLine(m, now))
	else
		O.match:show(false)
	end
	-- weapon line
	local W = ctx.Weapon
	local Gr = ctx.Grenade
	local St = ctx.Stationary
	if inRaid and St and St.mounted then
		-- at a stationary gun: its name and the rounds left (Tarkov shows no counter: a deliberate exception, STATIONARY_WEAPONS.md)
		O.weapon:show(true)
		local low = St.rounds <= math.max(5, St.belt * 0.1)
		local leave = ctx.Input.device() == "Touch" and "TAP LEAVE" or (ctx.Input.label("MountLeave") .. " TO LEAVE")
		O.weapon:set({
			{ t = St.name .. "  ·  ", color = C.dim, alpha = 0.15 }, { t = St.rounds .. " / " .. St.belt, color = low and C.red or C.yellow, alpha = 0.1 },
			{ t = "  ·  " .. leave, color = C.dim, alpha = 0.15 },
		})
	elseif inRaid and Gr and Gr.state and Gr.state ~= "throw" then
		-- grenade in hand: what it is and how to throw it
		O.weapon:show(true)
		local how = Gr.state == "ready" and ("RELEASE " .. ctx.Input.label("Grenade") .. " TO THROW  ·  HOLD " .. ctx.Input.label("Aim") .. ": UNDERHAND") or "PULLING THE PIN"
		O.weapon:set({ { t = (Gr.itemName and Gr.itemName() or "GRENADE") .. "  ·  " .. how, color = C.yellow, alpha = 0.1 } })
	elseif inRaid and W.hasWeapon then
		O.weapon:show(true)
		local line = (W.weaponName or "WEAPON") .. "  ·  " .. (W.modeLabel and W.modeLabel() or W.modeName or "SINGLE")
		if W.light then
			line ..= "  ·  LIGHT"
		end
		if W.malf then
			-- Tarkov flashes the weapon corner on a malfunction; inspecting names it
			local blink = math.floor(os.clock() * 2.5) % 2 == 0
			local what = W.malfName and (W.malfName .. "  ·  " .. ctx.Input.label("ChamberCheck") .. " TO CLEAR")
				or ("MALFUNCTION  ·  " .. ctx.Input.label("InspectWeapon") .. " TO INSPECT")
			O.weapon:set({ { t = line .. "  ·  ", color = C.dim, alpha = 0.15 }, { t = what, color = C.red, alpha = blink and 0.05 or 0.45 } })
		else
			O.weapon:set({ { t = line, color = C.dim, alpha = 0.15 } })
		end
	else
		O.weapon:show(false)
	end
	O.dot:show(S.reticle == true and inRaid and not W.aiming)
	-- squad roster (bottom-left): always in the hideout; in raid only with the exits check (Tarkov has no
	-- friendly markers or teammate health, squads are told apart by armband colour)
	local sq = ctx.State.squad
	local members = sq and sq.members or {}
	local showSq = #members > 0 and (not inRaid or os.clock() < math.max(exitsUntil, squadUntil))
	local rows = showSq and (#members + 1) or 0
	local band = (sq and sq.color) and Color3.fromHex(sq.color) or C.yellow
	for i, o in O.squad do
		local on = i <= rows
		o:show(on)
		if on then
			o:setAt(SIDE_L, squadBottom - (rows - i) * squadStep)
			if i == 1 then
				o:set({ { icon = I.PERSON, color = band, size = SZ.squadHead * 0.8 }, { t = " SQUAD", color = C.yellow }, { t = "   ARMBAND", size = SZ.squad * 0.8, color = band, top = true } })
			else
				local mem = members[i - 1]
				local me = mem.id == player.UserId
				local segs = { { t = string.upper(mem.name) .. (mem.leader and " (LEAD)" or ""), color = me and C.yellow or C.white } }
				if not inRaid then
					segs[2] = { t = "   " .. (mem.status or ""), color = mem.status == "HIDEOUT" and C.dim or C.green }
				end
				o:set(segs)
			end
		end
	end
end

-- extract requirement text + colour (green open, yellow requirement, red closed)
function Hud.exitStatus(e)
	if e.closed then
		return "UNAVAILABLE", C.red
	elseif e.rule == "paid" then
		return "PAY " .. Util.commas(e.cost or 0) .. " " .. Config.CURRENCY, C.yellow
	elseif e.rule == "key" then
		return "KEY REQUIRED", C.yellow
	elseif e.rule == "chance" then
		return "MAY BE UNAVAILABLE", C.yellow
	elseif e.rule == "scav" then
		return "SCAV ONLY", C.green
	elseif e.rule == "power" then
		return e.powered and "POWER ON" or "NEEDS POWER", e.powered and C.green or C.yellow
	elseif e.rule == "nobag" then
		return "NO BACKPACK", C.yellow
	end
	return "", C.green
end

-- one line describing the server's raid cycle (shown in the hideout)
function Hud.matchLine(m, now)
	local function t(sec)
		return Util.clock(math.max(0, sec))
	end
	if m.state == "MATCHING" then
		local head = m.queued and ("MATCHING" .. (m.queued == "scav" and " (SCAV)" or "")) or "RAID FORMING"
		return { { t = head, color = C.yellow }, { t = "  ·  INSERTION IN " .. t(m.startsAt - now), color = C.white }, { t = string.format("  ·  %d QUEUED", m.inQueue or 0), color = C.dim } }
	elseif m.state == "RUNNING" then
		if m.queued then
			return { { t = "QUEUED FOR THE NEXT RAID", color = C.yellow }, { t = "  ·  CURRENT RAID ENDS IN " .. t(m.endsAt - now), color = C.white } }
		end
		local segs = { { t = "RAID IN PROGRESS", color = C.orange }, { t = "  ·  " .. t(m.endsAt - now) .. " LEFT", color = C.white }, { t = string.format("  ·  %d INSIDE", m.inRaid or 0), color = C.dim } }
		if now < (m.lateUntil or 0) then
			table.insert(segs, { t = "  ·  PMC ENTRY CLOSES " .. t(m.lateUntil - now), color = C.green })
		elseif now < (m.scavUntil or 0) then
			table.insert(segs, { t = "  ·  SCAV ENTRY " .. t(m.scavUntil - now), color = C.green })
		end
		return segs
	end
	return { { t = "NO RAID IN PROGRESS  ·  PLAN AT THE OPS TABLE, BOARD THE VAN", color = C.dim } }
end

local function fastUpdate(dt)
	local S = ctx.Settings.data
	local v = vitals()
	local hp, max = math.max(0, v.hp or 0), math.max(1, v.max or 100)
	local frac = hp / max
	local hpCol = frac < 0.3 and C.red or (frac < 0.6 and C.orange or C.green)
	local hpDim = frac < 0.3 and Color3.fromRGB(180, 40, 32) or (frac < 0.6 and C.orangeDim or C.greenDim)
	O.hp:set({ { icon = I.PLUS, color = hpCol, size = SZ.hp * 0.83 }, { t = " " .. math.ceil(hp), color = hpCol }, { t = " /" .. math.floor(max), size = SZ.hp * 0.5, color = hpDim, top = true } })
	if lastHp and hp < lastHp - 0.5 then
		O.hp:pop(0.32)
		O.hp:shake(4, 0.3)
	elseif lastHp and hp > lastHp + 5 then
		O.hp:pop(0.18)
	end
	lastHp = hp
	local stMax = v.stMax or Config.MAX_STAMINA
	local M = ctx.Movement
	local st = v.st or (M and M.stamina) or stMax
	local stCol = st < stMax * 0.2 and C.orange or C.yellow
	local segs = { { icon = I.BOLT, color = stCol, size = SZ.st * 0.9 }, { t = " " .. math.floor(st), color = stCol }, { t = " /" .. math.floor(stMax), size = SZ.st * 0.52, color = C.yellowDim, top = true } }
	local arms = M and M.arms or Config.MAX_ARMS
	if arms < Config.MAX_ARMS - 0.5 then
		local ac = arms < 20 and C.orange or C.yellowDim
		segs[#segs + 1] = { t = "   ARMS " .. math.floor(arms), size = SZ.st * 0.52, color = ac, top = true }
	end
	O.st:set(segs)
	-- needs + status effects (only when the health model provides them)
	if v.energy then
		O.needs:show(true)
		O.needs:set({ { icon = I.ENERGY, color = v.energy < 20 and C.red or C.orange, size = SZ.needs * 0.75 }, { t = " " .. math.floor(v.energy) .. "    ", color = C.white }, { icon = I.WATER, color = v.water < 20 and C.red or C.blue, size = SZ.needs * 0.75 }, { t = " " .. math.floor(v.water), color = C.white } })
	else
		O.needs:show(false)
	end
	local fx = v.effects
	if fx and #fx > 0 then
		O.status:show(true)
		local segs = {}
		for _, e in fx do
			segs[#segs + 1] = { icon = e.icon, color = e.color or C.red, size = SZ.status * 0.85 }
			segs[#segs + 1] = { t = " " .. e.label .. "   ", color = e.color or C.red }
		end
		O.status:set(segs)
	else
		O.status:show(false)
	end
	-- progress priority: extract > search > heal > generic (mag loading, examining...)
	local label, pf, col = nil, 0, C.yellow
	local now = os.clock()
	if ex then
		local left = ex.ends - workspace:GetServerTimeNow()
		local sec = math.ceil(left)
		if sec ~= ex.beep and sec >= 0 then
			ex.beep = sec
			ctx.Effects.sound(Sounds.EXTRACT_BEEP, SoundService, sec <= 1 and 0.55 or 0.4, sec <= 1 and 1.25 or 1)
			O.notice:pop(0.2)
		end
		label, pf, col = "EXTRACTING  ·  " .. string.upper(ex.name or ""), 1 - math.clamp(left / Config.EXTRACT_HOLD, 0, 1), C.green
		O.notice:set({ { t = string.format("%.1f", math.max(0, left)), color = C.green } })
		O.noticeSub:set({ { t = "HOLD POSITION", color = C.dim } })
		notice.t, notice.dur = now, 0.3
	elseif search then
		pf = math.clamp((now - search.t0) / search.dur, 0, 1)
		label = "SEARCHING  ·  " .. string.upper(search.label or "")
		if pf >= 1 and now - search.t0 > search.dur + 2 then
			search = nil
		end
	elseif heal then
		pf = math.clamp((now - heal.t0) / heal.dur, 0, 1)
		label, col = string.upper(heal.label or "APPLYING DRESSING"), C.green
	elseif progress then
		pf = math.clamp((now - progress.t0) / progress.dur, 0, 1)
		label, col = string.upper(progress.label), progress.color or C.yellow
		if pf >= 1 then
			progress = nil
		end
	end
	O.progLabel:show(label ~= nil)
	O.progBar:show(label ~= nil)
	if label then
		O.progLabel:set({ { t = label, color = C.white } })
		local n = 24
		local filled = math.floor(pf * n + 0.5)
		O.progBar:set({ { t = string.rep("|", filled), color = col }, { t = string.rep("|", n - filled), color = col, alpha = 0.78 } })
	end
	-- notices fade
	local age = now - notice.t
	local showNotice = age < notice.dur + 0.4
	O.notice:show(showNotice)
	O.noticeSub:show(showNotice and notice.sub ~= nil or (ex ~= nil))
	if showNotice then
		local a = math.clamp((age - notice.dur) / 0.4, 0, 1)
		O.notice:setAlpha(a)
		O.noticeSub:setAlpha(a)
	end
	-- toasts: stack newest at top, fade out
	local order = {}
	for _, tslot in toasts do
		if now - tslot.t < 4.5 then
			table.insert(order, tslot)
		else
			tslot.o:show(false)
		end
	end
	table.sort(order, function(a, b)
		return a.t > b.t
	end)
	for i, tslot in order do
		tslot.o:setAt(SIDE_L, toastTop + (i - 1) * toastStep)
		local a2 = now - tslot.t
		tslot.o:setAlpha(a2 > 3.5 and (a2 - 3.5) or 0)
	end
	-- death
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local dead = hum ~= nil and hum.Health <= 0
	deathFade.Visible = dead
	O.death:show(dead)
	O.deathSub:show(dead)
	if dead then
		deathFade.BackgroundTransparency = math.max(0.3, deathFade.BackgroundTransparency - dt * 0.5)
		O.death:set({ { icon = I.SKULL, color = C.red, size = SZ.death * 0.78 }, { t = " SIGNAL LOST", color = C.white } })
		O.deathSub:set({ { t = ctx.State.deathInfo or "RECORDING TERMINATED", color = C.dim } })
	else
		deathFade.BackgroundTransparency = 1
	end
	-- HUD sway: lags behind camera rotation a few pixels, like a visor overlay
	local yaw = ctx.Camera.yaw or 0
	local yawVel = dt > 0 and (yaw - lastYaw) / dt or 0
	lastYaw = yaw
	local tx = math.clamp(yawVel * 2.4, -8, 8) * L.unit
	local ty = math.clamp((ctx.Camera.speed or 0) * 0.08, 0, 3) * math.sin(os.clock() * 9) * L.unit
	swayX += (tx - swayX) * math.min(1, dt * 7)
	swayY += (ty - swayY) * math.min(1, dt * 7)
	L.root.Position = UDim2.fromOffset(swayX, swayY)
	L:step(dt)
	gui.Enabled = not ctx.studio and not (ctx.Inventory and ctx.Inventory.open)
end

-- generic timed progress (mag loading, examining, unlocking...)
function Hud.progress(label, dur, color)
	if dur and dur > 0 then
		progress = { label = label, t0 = os.clock(), dur = dur, color = color }
	else
		progress = nil
	end
end

local function applySettings()
	local S = ctx.Settings.data
	-- HUD text is straight by default (owner request); "CURVED HUD" bends it with the lens again
	L:setOptions(S.curve == true, S.lens ~= false, S.hudScale or 1)
	layout()
	local rec = S.film ~= false
	O.rec:show(rec)
	O.dev:show(rec)
	for _, b in O.brackets do
		b:show(rec)
	end
end

function Hud.init(c)
	ctx = c
	K = c.UiKit
	build()
	applySettings()
	c.Settings.changed:Connect(applySettings)
	c.State.on("toast", function(d)
		Hud.toast(d.text, d.tone)
	end)
	c.State.on("extract", function(d)
		if d.state == "start" then
			ex = { name = d.name, ends = d.ends }
			Hud.toast("EXFIL " .. tostring(d.zone) .. "  -  HOLD POSITION" .. (d.cost and ("  ·  PAYING " .. Util.commas(d.cost) .. " " .. Config.CURRENCY) or ""), "good")
		elseif d.state == "denied" then
			-- requirement not met at the zone (closed this raid, key missing, can't pay)
			ex = nil
			local raid = ctx.State.raid
			for _, e in raid and raid.extracts or {} do
				if e.id == d.zone and d.reason == "CLOSED" then
					e.closed = true
				end
			end
			Hud.notice("EXFIL " .. tostring(d.zone), d.text or "UNAVAILABLE", C.red, 2.6)
		else
			ex = nil
			Hud.toast("EXTRACTION INTERRUPTED", "warn")
		end
	end)
	c.State.on("search", function(d)
		if d.cancel then
			search = nil
		else
			search = { t0 = os.clock(), dur = d.t, label = d.label }
		end
	end)
	c.State.on("loot", function()
		search = nil
	end)
	c.State.on("heal", function(d)
		if d.state == "start" then
			heal = { t0 = os.clock(), dur = d.t, label = d.label }
		else
			heal = nil
			if d.state == "cancel" then
				Hud.toast("TREATMENT INTERRUPTED", "warn")
			end
		end
	end)
	c.State.on("hit", function(d)
		hitT = os.clock()
		if ctx.Settings.data.hitfx then
			ctx.Effects.sound(Sounds.HIT, SoundService, d.kill and 0.7 or 0.5, d.kill and 0.8 or 1)
		end
	end)
	c.State.on("progress", function(p)
		Hud.progress(p.label or "WORKING", p.t or 1)
	end)
	c.State.on("movenote", function(d)
		Hud.toast(d.text or "")
	end)
	c.State.on("magcheck", function(d)
		if type(d) ~= "table" then
			return
		end
		if d.state == "start" then
			Hud.progress(d.chamber and "CHECKING CHAMBER" or "CHECKING MAGAZINE", d.t or 1.1)
		elseif d.state == "done" then
			Hud.progress(nil)
			Hud.notice(d.text or "?", d.ammo and string.upper(d.ammo) or nil, C.white, 2.2)
		end
	end)
	c.State.on("raid", function(r)
		ex, search, heal = nil, nil, nil
		squadUntil = os.clock() + 8
		Hud.notice(Maps.nameOf(r and r.map), (r and r.scav) and "INSERTION CONFIRMED  ·  SCAV" or "INSERTION CONFIRMED", C.white, 3)
	end)
	c.State.on("summary", function()
		ex, search, heal = nil, nil, nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			slowUpdate()
		end
		fastUpdate(dt)
	end)
end

return Hud

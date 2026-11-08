--!nonstrict
-- Bodycam HUD, R.E.P.O.-inspired presentation (original implementation): tall condensed numerals with
-- RGB split + glow, spring "pop" on change, everything bent through the recorder lens (see Lens.luau).
-- Tarkov rules: no ammo counter, no hit markers, no damage-direction arrows; extract list on demand.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
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
local ride = nil -- a seat in a car exit's car: { name, ends, total } (the shared departure countdown)
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
-- Tarkov's health condition indicator (audit ui-1a): a body outline whose seven parts take their condition's colour
-- (HEALTH COLOR SCHEME: polychrome or monochrome), the effects as icons beside it, energy and water only as warnings;
-- the numbers are on the HEALTH tab. Segments in figure units (y down from the crown; 1 unit = 40 px at 1080p):
-- part, x0, y0, x1, y1, thickness.
local FIG = {
	{ "head", 0, 0.04, 0, 0.32, 0.3 },
	{ "thorax", 0, 0.41, 0, 0.83, 0.44 },
	{ "stomach", 0, 0.87, 0, 1.19, 0.38 },
	{ "larm", -0.36, 0.43, -0.44, 1.15, 0.15 },
	{ "rarm", 0.36, 0.43, 0.44, 1.15, 0.15 },
	{ "lleg", -0.12, 1.25, -0.16, 2.1, 0.18 },
	{ "rleg", 0.12, 1.25, 0.16, 2.1, 0.18 },
}
local FIG_H, FIG_W, FIG_UNIT = 2.1, 0.9, 40
local fig = { x = 0, y = 0, s = 40, shown = false, showUntil = 0, sig = "", touch = false }
-- Tarkov's stamina and stance indicator: the stamina and arm-stamina bars (bottom centre) and a stance marker beside
-- them, shown always or only while they change (STAMINA AND STANCE)
local bars = { x0 = 0, x1 = 0, y = 0, showUntil = 0 }

-- a part's colour: polychrome green, yellow, orange, red as it is hurt, black destroyed (Tarkov); monochrome greys
local function partColor(hp, mx, mono)
	local f = mx > 0 and hp / mx or 0
	if hp <= 0 then
		return Color3.fromRGB(48, 16, 14), 0.05
	end
	if mono then
		return C.white, 0.12 + 0.6 * (1 - f)
	end
	if f >= 0.75 then
		return C.green, 0.12
	elseif f >= 0.5 then
		return C.yellow, 0.12
	elseif f >= 0.25 then
		return C.orange, 0.1
	end
	return C.red, 0.08
end

local function setLine(o, ax, ay, bx, by, W, H)
	local a, b = Vector2.new(ax / W, ay / H), Vector2.new(bx / W, by / H)
	if o.a ~= a or o.b ~= b then
		o.a, o.b = a, b
		o.dirty = true
	end
end
-- the exits, then the transits (Tarkov lists both on O). A Border Yard PMC has up to 9 exits and the transit, a scav 25
-- and the transit; placeExits shrinks a long list to fit and splits it in two columns past that
local MAX_EXITS = 30
local exitArea = { touch = false, y0 = 200, y1 = 900, gap = 5, vit = { 0, 0 }, rec = { 0, 0 } } -- where the list may stand (layout())
local toastTop, toastStep, squadBottom, squadStep = 0.36, 0.04, 0.93, 0.045
local toastX = 0.04 -- the toasts' left edge (moved right of the touch stick when they would meet it)
local SIDE_L, SIDE_R = 0.04, 0.96
-- the device's safe area (a notch or rounded corners; audit ui.11): the HUD draws edge to edge for the bodycam lens, so
-- a hidden probe with DeviceSafeInsets tells how far in the side columns must start
local safeProbe = nil
local function safeSides(W)
	if not safeProbe then
		local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return 0.04, 0.96
		end
		local sg = Instance.new("ScreenGui")
		sg.Name = "ZR_SafeProbe"
		sg.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		sg.ResetOnSpawn = false
		sg.Enabled = true
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		f.Parent = sg
		sg.Parent = pg
		safeProbe = f
	end
	local full = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or W
	local l = math.max(0, safeProbe.AbsolutePosition.X)
	local r = math.max(0, full - (safeProbe.AbsolutePosition.X + safeProbe.AbsoluteSize.X))
	return math.max(0.04, (l + 8) / math.max(1, W)), math.min(0.96, 1 - (r + 8) / math.max(1, W))
end

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
	if not L then
		return
	end
	L:resize()
	local u, H, W = L.unit, math.max(1, L.H), math.max(1, L.W)
	SIDE_L, SIDE_R = safeSides(W)
	local gap = 7 * u
	local top = 0.058 * H + 4 * u
	-- Roblox's own menu sits at the left end of the top bar (GuiService.TopbarInset is the free band right of it): on a
	-- small screen the vitals start below that menu instead of under it
	local band = GuiService.TopbarInset
	local leftTop = top
	if band.Max.Y > 0 and band.Min.X > SIDE_L * W then
		leftTop = math.max(top, band.Max.Y + 4 * u)
	end
	-- the health figure: bottom left on a PC (Tarkov), top left on touch (the stick has the bottom left); its effect
	-- icons and the energy and water warnings beside it. Toasts start under whatever holds the top left.
	local touchRow = ctx.Touch and ctx.Touch.topRowBottom and ctx.Touch.topRowBottom()
	local bottom0 = 0.955 * H - 4 * u
	local s = FIG_UNIT * u
	fig.s, fig.touch = s, touchRow ~= nil
	local fw, fh = FIG_W * s, FIG_H * s
	local fx = SIDE_L * W + fw * 0.5
	local fy = touchRow and leftTop or (bottom0 - fh)
	fig.x, fig.y = fx, fy
	for _, e in FIG do
		local o = O.fig[e[1]]
		setLine(o, fx + e[2] * s, fy + e[3] * s, fx + e[4] * s, fy + e[5] * s, W, H)
		o.thick = e[6] * s / math.max(u, 1e-3)
	end
	local sx = (fx + fw * 0.5 + 10 * u) / W
	O.status:setAt(sx, (fy + 0.62 * s) / H)
	O.needs:setAt(sx, (fy + 0.62 * s + (SZ.status + SZ.needs) * 0.5 * u + gap) / H)
	local leftEnd = touchRow and (fy + fh) or leftTop
	toastTop = (leftEnd + 10 * u + SZ.toast * u * 0.5) / H
	toastStep = (SZ.toast * u + gap) / H
	-- recorder line and clock (top-right), the exits list below them. On touch the menu row (SET, EXIT, BAG) stands at
	-- the top centre (Touch.luau; KNOWN_ISSUES 75) and the list drops down under it, clear of the thumb buttons
	local rightEnd = stack({ { O.rec, SZ.rec }, { O.dev, SZ.dev }, { O.clock, SZ.clock } }, SIDE_R, top, gap)
	local row = ctx.Touch and ctx.Touch.topRowBottom and ctx.Touch.topRowBottom()
	-- on touch the toasts start right of the movement stick when their stack would reach it (KNOWN_ISSUES 77)
	toastX = SIDE_L
	if row and ctx.Touch.rectOf then
		local x0, y0, x1, y1 = ctx.Touch.rectOf("joy")
		if x0 then
			local gp = gui.AbsolutePosition
			local ty0 = toastTop * H - SZ.toast * u * 0.5
			local ty1 = (toastTop + 4 * toastStep) * H + SZ.toast * u * 0.5
			if y1 - gp.Y > ty0 and y0 - gp.Y < ty1 then
				toastX = math.max(SIDE_L, (x1 - gp.X + 10 * u) / W)
			end
		end
	end
	exitArea = {
		touch = row ~= nil, y0 = row and (row + gap) or (rightEnd + 4 * u), y1 = 0.88 * H, gap = gap * 0.7,
		vit = { leftTop, leftEnd }, rec = { top, rightEnd }, -- the figure's and the recorder column's bands (the touch drop-down passes between)
	}
	-- notices sit above the sight line (and below the touch menu row), progress below it
	local ny = 0.19 * H
	if row then
		ny = math.max(ny, row + gap + SZ.notice * u * 0.5)
	end
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
	fig.squadBottom = (fy - gap - SZ.squad * u * 0.5) / H -- in a raid on a PC the roster stands over the figure
	-- the stamina bars over the weapon line, the stance marker left of them
	bars.x0, bars.x1 = 0.5 * W - 90 * u, 0.5 * W + 90 * u
	bars.y = bottom - SZ.weapon * u - gap - 8 * u
	bars.u, bars.W, bars.H = u, W, H
	-- death card
	O.death:setAt(0.5, 0.45)
	O.deathSub:setAt(0.5, (0.45 * H + (SZ.death + SZ.deathSub) * 0.5 * u + gap) / H)
end
Hud.layout = layout

-- The exits list (Tarkov: on O, names and requirements only): one column under the clock, or on touch a drop-down under
-- the menu row at the top centre. A long list shrinks to fit its area; past a point it splits in two columns (on touch
-- they meet at the centre). Returns where each row stands (GUI absolute pixels) for the touch buttons
-- to fade under (Touch.luau), or nil when the list is hidden.
local function placeExits(rows)
	local n = math.min(#rows, #O.exits)
	for i = n + 1, #O.exits do
		O.exits[i]:show(false)
	end
	if n == 0 then
		return nil
	end
	local u, W, H, a = L.unit, L.W, L.H, exitArea
	local pitch = SZ.exit * u + a.gap
	local avail = math.max(1, a.y1 - a.y0)
	local cols, f = 1, math.min(1, avail / (n * pitch))
	-- a column may shrink to 62 % on a screen with keys (Tarkov's one column top right); the touch drop-down splits sooner,
	-- since a phone's text is small already
	if f < (a.touch and 0.85 or 0.62) then
		cols = 2
		f = math.max(0.5, math.min(1, avail / (math.ceil(n / 2) * pitch)))
	end
	local per = math.ceil(n / cols)
	local widths, colW
	local function fill(size)
		widths, colW = {}, { 0, 0 }
		for i = 1, n do
			local o, e = O.exits[i], rows[i]
			local status, col = Hud.exitStatus(e)
			local title = e.rule == "transit" and (" " .. string.upper(e.name)) or string.format(" EXFIL %s  ·  %s", e.id, string.upper(e.name))
			local resized = o.size ~= size
			o:setSize(size)
			local changed = o:set({ { icon = I.EXIT, color = col, size = size * 0.85 }, { t = title, color = C.white }, { t = status ~= "" and ("  " .. status) or "", color = col } })
			o:show(true)
			-- measured again only when the row, its size, the screen or a glyph's known width changed
			if changed or resized or o.mwVer ~= Lens.version or o.mwUnit ~= u then
				o.mw, o.mwVer, o.mwUnit = o:measure(), Lens.version, u
			end
			widths[i] = o.mw
			local c = (i <= per) and 1 or 2
			colW[c] = math.max(colW[c], widths[i])
		end
	end
	fill(SZ.exit * f)
	if a.touch then
		-- the drop-down passes between the vitals (top left) and the recorder column (top right), and keeps to the screen:
		-- a row too wide for the room beside it shrinks the list again (text scales with its size, so one pass fits it)
		local left = fig.x + FIG_W * fig.s * 0.5 + 10 * u + math.max(O.needs:measure(), O.status:measure()) + 12 * u
		local right = SIDE_R * W - math.max(O.rec:measure(), O.dev:measure(), O.clock:measure()) - 12 * u
		local rowH0, g0, k = SZ.exit * f * u, a.gap * f, 1
		for i = 1, n do
			local c, r = (i <= per) and 1 or 2, (i - 1) % per
			local yT = a.y0 + r * (rowH0 + g0)
			local yB = yT + rowH0
			local lo = (yB > a.vit[1] and yT < a.vit[2]) and left or SIDE_L * W
			local hi = (yB > a.rec[1] and yT < a.rec[2]) and right or SIDE_R * W
			local w = math.max(1, widths[i])
			if cols == 1 then
				k = math.min(k, 2 * math.min(0.5 * W - lo, hi - 0.5 * W) / w)
			elseif c == 1 then
				k = math.min(k, (0.5 * W - 10 * u - lo) / w)
			else
				k = math.min(k, (hi - 0.5 * W - 10 * u) / w)
			end
		end
		if k < 1 then
			f *= math.max(0.4, k)
			fill(SZ.exit * f)
		end
	end
	local rowH, g = SZ.exit * f * u, a.gap * f
	local gp, rects = gui.AbsolutePosition, {}
	for i = 1, n do
		local o = O.exits[i]
		local c, k = (i <= per) and 1 or 2, (i - 1) % per
		local x, align
		if a.touch then
			if cols == 1 then
				x, align = 0.5 * W, 0.5
			elseif c == 1 then
				x, align = 0.5 * W - 10 * u, 1
			else
				x, align = 0.5 * W + 10 * u, 0
			end
		else
			-- right-aligned under the clock; with two columns the first stands left of the second
			x, align = SIDE_R * W, 1
			if cols == 2 and c == 1 then
				x -= colW[2] + 26 * u
			end
		end
		local y = a.y0 + k * (rowH + g) + rowH * 0.5
		o:setAlign(align)
		o:setAt(x / W, y / H)
		local x0 = x - align * widths[i] + gp.X
		table.insert(rects, { x0, y - rowH * 0.5 + gp.Y, x0 + widths[i], y + rowH * 0.5 + gp.Y })
	end
	return rects
end

local function build()
	gui = K.screen("ZR_HUD", 5)
	gui.ScreenInsets = Enum.ScreenInsets.None
	L = Lens.new(gui, { k = 0.11 })
	Lens.prewarm(Lens.FONT, "0123456789:/+-.,%$ ABCDEFGHIJKLMNOPQRSTUVWXYZ·|()[]")
	Lens.prewarm(Lens.FONT_MED, "0123456789:/+-.,% ABCDEFGHIJKLMNOPQRSTUVWXYZ·|()")
	local V0 = Vector2.new(0.5, 0.5)
	-- the health figure (bottom left, top left on touch), its effect icons and the energy and water warnings
	O.fig = {}
	for _, e in FIG do
		O.fig[e[1]] = L:line({ name = "Fig_" .. e[1], a = V0, b = V0, thick = 4, segments = 1, color = C.green, alpha = 0.12 })
	end
	O.needs = txt("Needs", V0, SZ.needs, 0, { font = Lens.FONT_MED, glow = nil })
	O.status = txt("Status", V0, SZ.status, 0, { font = Lens.FONT_MED, glow = nil })
	-- the stamina and arm bars and the stance marker (bottom centre)
	O.stBack = L:line({ name = "StaminaBack", a = V0, b = V0, thick = 3, segments = 4, color = C.dim, alpha = 0.75 })
	O.stBar = L:line({ name = "StaminaBar", a = V0, b = V0, thick = 3, segments = 4, color = C.yellow, alpha = 0.1 })
	O.armBack = L:line({ name = "ArmsBack", a = V0, b = V0, thick = 2, segments = 4, color = C.dim, alpha = 0.75 })
	O.armBar = L:line({ name = "ArmsBar", a = V0, b = V0, thick = 2, segments = 4, color = C.white, alpha = 0.2 })
	O.stance = L:line({ name = "Stance", a = V0, b = V0, thick = 3, segments = 1, color = C.white, alpha = 0.2 })
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
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
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

-- Tarkov's "Signal Area" notice: the first step into a flare exit's area that no green flare has opened yet
local signalAt = nil
local function signalCheck(raid)
	local lp = game:GetService("Players").LocalPlayer
	local char = lp and lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local here = nil
	if raid and root then
		for _, e in raid.extracts or {} do
			if e.rule == "flare" and not e.flared and e.area and typeof(e.pos) == "Vector3" then
				local dx, dz = root.Position.X - e.pos.X, root.Position.Z - e.pos.Z
				if dx * dx + dz * dz <= e.area * e.area then
					here = e.id
					if signalAt ~= e.id then
						Hud.notice("SIGNAL AREA", "FIRE A GREEN FLARE TO OPEN " .. string.upper(e.name or ""), C.yellow, 4)
					end
					break
				end
			end
		end
	end
	signalAt = here
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
	-- SAVING OFF whenever the server keeps progress anywhere but Roblox's DataStore (Studio's in-memory store, or a live
	-- server whose DataStore is down: Store.luau), so nobody plays on thinking it is kept
	local persist = ctx.State.data and ctx.State.data.persistence
	local devLine = { { t = "ZR BODYCAM 4  ·  X7F3A21  ·  " .. (inRaid and Maps.nameOf(raid and raid.map) or "RELAY 7"), color = C.dim, alpha = 0.2 } }
	if persist ~= nil and persist ~= "DATASTORE" then
		table.insert(devLine, { t = "  ·  SAVING OFF", color = C.red, alpha = 0.1 })
	end
	O.dev:set(devLine)
	signalCheck(inRaid and raid or nil)
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
	local rows = {}
	if showEx then
		for _, e in raid.extracts or {} do
			table.insert(rows, e)
		end
		for _, tr in raid.transits or {} do
			table.insert(rows, { id = tr.id, name = tr.name, rule = "transit", open = tr.open, toName = tr.toName })
		end
	end
	Hud.exitRects = placeExits(rows)
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
		local line = (W.weaponName or "WEAPON") .. "  ·  " .. (W.modeLabel and W.modeLabel() or W.modeName or "SINGLE")
		if W.light then
			-- what the tactical device runs (a combo switches with Ctrl+T)
			local lt, lz = true, false
			if W.deviceState then
				lt, lz = W.deviceState()
			end
			line ..= "  ·  " .. ((lt and lz) and "LIGHT + LASER" or (lz and "LASER") or "LIGHT")
		end
		-- Tarkov shows the weapon corner for a few seconds after a switch, a fire-mode change or a check, not all the
		-- time (audit ui.3); a malfunction keeps it up and flashing
		local sig = line .. "|" .. tostring(W.modeCheckedAt) .. "|" .. tostring(W.lastCheck) .. "|" .. tostring(W.checking)
		if sig ~= Hud.weaponSig then
			Hud.weaponSig = sig
			Hud.weaponUntil = os.clock() + 4
		end
		local notify = ctx.Settings.data.malfNotes ~= false -- MALFUNCTION NOTIFICATIONS (Tarkov's GAME tab)
		O.weapon:show((notify and W.malf ~= nil and W.malf ~= false) or os.clock() < (Hud.weaponUntil or 0))
		if W.malf and ctx.Settings.data.malfNotes ~= false then
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
			local sb = (inRaid and fig.shown and not fig.touch and fig.squadBottom) or squadBottom
			o:setAt(SIDE_L, sb - (rows - i) * squadStep)
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
		return e.closedText or "UNAVAILABLE", C.red
	elseif e.rule == "paid" then
		-- a car that may not be there this raid reads like a chance exit
		return "PAY " .. Util.commas(e.cost or 0) .. " " .. Config.CURRENCY .. (e.chance and "  ·  MAY BE UNAVAILABLE" or ""), C.yellow
	elseif e.rule == "key" then
		return "KEY REQUIRED", C.yellow
	elseif e.rule == "chance" then
		return "MAY BE UNAVAILABLE", C.yellow
	elseif e.rule == "scav" then
		-- a scav's own list holds nothing else: no tag there (audit ui.15)
		local raid = ctx.State.raid
		return (raid and raid.scav) and "" or "SCAV ONLY", C.green
	elseif e.rule == "power" then
		return e.powered and "POWER ON" or "NEEDS POWER", e.powered and C.green or C.yellow
	elseif e.rule == "nobag" then
		return "NO BACKPACK", C.yellow
	elseif e.rule == "flare" then
		return e.flared and "OPEN  ·  FLARE SEEN" or "GREEN FLARE IN THE SIGNAL AREA", e.flared and C.green or C.yellow
	elseif e.rule == "transit" then
		-- Tarkov's transits open a minute into the raid (SPT); the countdown is 20 s in the zone
		return e.open and "TRANSIT  ·  OPEN" or "TRANSIT  ·  OPENS A MINUTE IN", e.open and C.green or C.yellow
	elseif e.rule == "coop" then
		-- Tarkov's co-op exit: a PMC and a scav leave together
		return "CO-OP EXTRACTION", C.yellow
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
		if m.queued == "scav" and now < (m.scavFrom or 0) then
			return { { t = "QUEUED AS SCAV", color = C.yellow }, { t = "  ·  SCAV ENTRY OPENS IN " .. t(m.scavFrom - now), color = C.white } }
		elseif m.queued then
			return { { t = "QUEUED FOR THE NEXT RAID", color = C.yellow }, { t = "  ·  CURRENT RAID ENDS IN " .. t(m.endsAt - now), color = C.white } }
		end
		local segs = { { t = "RAID IN PROGRESS", color = C.orange }, { t = "  ·  " .. t(m.endsAt - now) .. " LEFT", color = C.white }, { t = string.format("  ·  %d INSIDE", m.inRaid or 0), color = C.dim } }
		if now < (m.lateUntil or 0) then
			table.insert(segs, { t = "  ·  PMC ENTRY CLOSES " .. t(m.lateUntil - now), color = C.green })
		elseif now < (m.scavFrom or 0) then
			table.insert(segs, { t = "  ·  SCAV ENTRY OPENS IN " .. t(m.scavFrom - now), color = C.dim })
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
	local raidNow = ctx.State.inRaid()
	local t = os.clock()
	-- the health figure (HEALTH CONDITION: always shown, auto-hide, never); auto-hide shows it for 5 s after a part
	-- changes and while an effect lasts. Out of a raid Tarkov shows no vitals (audit ui.4): the HEALTH tab has them.
	local parts = v.parts
	local mode = S.hudHealth or 1
	local sig = ""
	if parts then
		for _, e in FIG do
			local p = parts[e[1]]
			sig ..= (p and p[1] or "-") .. "/"
		end
	end
	if sig ~= fig.sig then
		fig.sig = sig
		fig.showUntil = t + 5
	end
	local effects = v.effects or {}
	local showFig = raidNow and parts ~= nil and (mode == 1 or (mode == 2 and (t < fig.showUntil or #effects > 0)))
	for _, e in FIG do
		local o = O.fig[e[1]]
		o:show(showFig)
		if showFig then
			local p = parts[e[1]]
			local col, alpha = partColor(p and p[1] or 1, p and p[2] or 1, S.hudColors == 2)
			if o.color ~= col or o.alpha ~= alpha then
				o:setColor(col, alpha)
			end
		end
	end
	fig.shown = showFig
	-- effects as icons beside the figure; energy and water appear only as warnings (a quarter left: orange; the
	-- server adds EXHAUSTED and DEHYDRATED at nothing)
	local segs = {}
	for _, e in effects do
		segs[#segs + 1] = { icon = e.icon, color = e.color or C.red, size = SZ.status * 0.9 }
		segs[#segs + 1] = { t = "  ", size = SZ.status * 0.5 }
	end
	if showFig and v.energy and v.energy > 0 and v.energy < 25 then
		segs[#segs + 1] = { icon = I.ENERGY, color = C.orange, size = SZ.status * 0.9 }
		segs[#segs + 1] = { t = "  ", size = SZ.status * 0.5 }
	end
	if showFig and v.water and v.water > 0 and v.water < 25 then
		segs[#segs + 1] = { icon = I.WATER, color = C.orange, size = SZ.status * 0.9 }
	end
	O.status:show(showFig and #segs > 0)
	if showFig and #segs > 0 then
		O.status:set(segs)
	end
	O.needs:show(false)
	if lastHp and (v.hp or 0) < lastHp - 0.5 then
		fig.showUntil = t + 5
	end
	lastHp = v.hp or 0
	-- the stamina and stance indicator (STAMINA AND STANCE: always shown, auto-hide, never); auto-hide shows it while
	-- stamina or the arms are spent, the breath is held or the stance changes, and 1.5 s after
	local smode = S.hudStamina or 2
	local M = ctx.Movement
	local stMax = v.stMax or Config.MAX_STAMINA
	local st = v.st or (M and M.stamina) or stMax
	local arms = M and M.arms or Config.MAX_ARMS
	local stance, depth = M and M.stance or "s", M and M.depth or 0
	if st < stMax - 0.5 or arms < Config.MAX_ARMS - 0.5 or (M and M.breath) or stance ~= bars.stance or math.abs(depth - (bars.depth or depth)) > 0.04 then
		bars.showUntil = t + 1.5
	end
	bars.stance, bars.depth = stance, depth
	local showBars = raidNow and (smode == 1 or (smode == 2 and t < bars.showUntil))
	for _, o in { O.stBack, O.stBar, O.armBack, O.armBar, O.stance } do
		o:show(showBars)
	end
	if showBars and bars.W then
		local W, H, u = bars.W, bars.H, bars.u
		local x0, x1, y = bars.x0, bars.x1, bars.y
		local fs, fa = math.clamp(st / stMax, 0, 1), math.clamp(arms / Config.MAX_ARMS, 0, 1)
		setLine(O.stBack, x0, y, x1, y, W, H)
		setLine(O.stBar, x0, y, x0 + (x1 - x0) * math.max(fs, 0.002), y, W, H)
		O.stBar:setColor(fs < 0.2 and C.orange or C.yellow, 0.1)
		setLine(O.armBack, x0, y + 6 * u, x1, y + 6 * u, W, H)
		setLine(O.armBar, x0, y + 6 * u, x0 + (x1 - x0) * math.max(fa, 0.002), y + 6 * u, W, H)
		O.armBar:setColor((M and M.breath) and C.blue or (fa < 0.2 and C.orange or C.white), 0.2)
		-- the stance: a bar as tall as the body stands (lower the deeper the crouch), lying flat when prone
		local sx, base = x0 - 16 * u, y + 7 * u
		if stance == "p" then
			setLine(O.stance, sx - 9 * u, base, sx + 3 * u, base, W, H)
		else
			local hgt = (stance == "c" and (0.75 - 0.3 * depth) or 1) * 22 * u
			setLine(O.stance, sx, base, sx, base - hgt, W, H)
		end
	end
	-- progress priority: extract > car seat > search > heal > generic (mag loading, examining...)
	local label, pf, col = nil, 0, C.yellow
	local now = os.clock()
	if ride and ride.ends < workspace:GetServerTimeNow() - 4 then
		ride = nil -- nothing came after the departure (the news was lost): stop counting
	end
	local counting = false -- the car's last ten seconds are on the big notice
	if ex then
		local left = ex.ends - workspace:GetServerTimeNow()
		local sec = math.ceil(left)
		if sec ~= ex.beep and sec >= 0 then
			ex.beep = sec
			ctx.Effects.sound(Sounds.EXTRACT_BEEP, SoundService, sec <= 1 and 0.55 or 0.4, sec <= 1 and 1.25 or 1)
			O.notice:pop(0.2)
		end
		label, pf, col = (ex.transit and "TRANSIT  ·  " or "EXTRACTING  ·  ") .. string.upper(ex.name or ""), 1 - math.clamp(left / (ex.total or Config.EXTRACT_HOLD), 0, 1), C.green
		O.notice:set({ { t = string.format("%.1f", math.max(0, left)), color = C.green } })
		O.noticeSub:set({ { t = ex.transit and "STAY IN THE TRANSIT ZONE" or "HOLD POSITION", color = C.dim } })
		notice.t, notice.dur = now, 0.3
	elseif ride then
		-- a seat in the car: the shared departure countdown on the progress bar, the last ten seconds out loud like an extraction
		local left = ride.ends - workspace:GetServerTimeNow()
		label = "CAR LEAVES IN " .. Util.clock(math.ceil(math.max(0, left))) .. "  ·  " .. string.upper(ride.name or "")
		pf, col = 1 - math.clamp(left / math.max(1, ride.total or 60), 0, 1), C.yellow
		if left <= 10 then
			local sec = math.ceil(math.max(0, left))
			if sec ~= ride.beep then
				ride.beep = sec
				ctx.Effects.sound(Sounds.EXTRACT_BEEP, SoundService, sec <= 1 and 0.55 or 0.4, sec <= 1 and 1.25 or 1)
				O.notice:pop(0.2)
			end
			O.notice:set({ { t = string.format("%.1f", math.max(0, left)), color = C.yellow } })
			O.noticeSub:set({ { t = "STAY BY THE CAR", color = C.dim } })
			notice.t, notice.dur = now, 0.3
			counting = true
		end
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
	O.noticeSub:show(showNotice and notice.sub ~= nil or (ex ~= nil) or counting)
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
		tslot.o:setAt(toastX, toastTop + (i - 1) * toastStep)
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
	-- no HUD while any screen is open (audit ui.4): the inventory, a trader, the hideout, settings, a report
	gui.Enabled = not ctx.studio and not (ctx.Inventory and ctx.Inventory.open) and not (ctx.Screens and ctx.Screens.modal)
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
	-- the exit's name for the notices (Tarkov names the exit, not its code); its id if the raid list lacks it
	local function exitName(id)
		local raid = ctx.State.raid
		for _, e in raid and raid.extracts or {} do
			if e.id == id and e.name then
				return string.upper(e.name)
			end
		end
		return tostring(id)
	end
	-- transits (Transit.luau): the countdown shares the extraction's; on arrival the new map's name comes up big
	c.State.on("transit", function(d)
		if d.state == "start" then
			ex = { name = d.toName or d.to, ends = d.ends, total = d.total, transit = true }
			Hud.toast("TRANSIT TO " .. tostring(d.toName or d.to) .. " IN " .. tostring(d.total or 20) .. " S  ·  NO OTHER EXIT NOW", "good")
		elseif d.state == "arrived" then
			ex = nil
			Hud.notice(tostring(d.toName or d.to), "TRANSIT COMPLETE  ·  YOUR EXITS ARE ON O", C.green, 4)
		else
			ex = nil
			Hud.toast(d.text or "TRANSIT CANCELLED", "warn")
		end
	end)
	c.State.on("extract", function(d)
		if d.state == "start" and d.car then
			-- the fare is paid and a seat taken: every passenger counts down to the same departure (extract note, flagged car)
			ride = { name = d.name, ends = d.ends, total = d.total }
			Hud.toast("PAID " .. Util.commas(d.cost or 0) .. " " .. Config.CURRENCY .. "  ·  SEAT " .. tostring(d.seat or 1) .. " OF " .. tostring(d.seats or 4), "good")
			Hud.toast("EXFIL " .. exitName(d.zone) .. "  -  THE CAR LEAVES IN " .. tostring(math.ceil(d.total or 60)) .. " S  ·  STAY BY IT", "good")
		elseif d.state == "start" then
			ex = { name = d.name, ends = d.ends, total = d.total }
			Hud.toast("EXFIL " .. exitName(d.zone) .. "  -  HOLD POSITION" .. (d.cost and ("  ·  PAYING " .. Util.commas(d.cost) .. " " .. Config.CURRENCY) or ""), "good")
		elseif d.state == "left" then
			-- the car drove off with the seat paid for and its owner outside the zone: no refund
			ride = nil
			Hud.notice("EXFIL " .. exitName(d.zone), d.text or "THE CAR HAS LEFT", C.red, 3.5)
		elseif d.state == "denied" then
			-- requirement not met at the zone (closed this raid, key missing, can't pay); a car's zone only says where to pay
			if not d.car then
				ex = nil
			end
			local raid = ctx.State.raid
			for _, e in raid and raid.extracts or {} do
				if e.id == d.zone and d.reason == "CLOSED" then
					e.closed = true
				end
			end
			Hud.notice("EXFIL " .. exitName(d.zone), d.text or "UNAVAILABLE", d.reason == "PAY" and C.yellow or C.red, 2.6)
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
	-- a raid's first info is the insertion; the same raid's later infos (power on, a flare, a transit) only bring news
	local lastRaidId = nil
	c.State.on("raid", function(r)
		if r and r.id ~= nil and r.id == lastRaidId then
			return
		end
		lastRaidId = r and r.id
		ex, ride, search, heal = nil, nil, nil, nil
		squadUntil = os.clock() + 8
		Hud.notice(Maps.nameOf(r and r.map), (r and r.scav) and "INSERTION CONFIRMED  ·  SCAV" or "INSERTION CONFIRMED", C.white, 3)
	end)
	c.State.on("summary", function()
		ex, ride, search, heal = nil, nil, nil, nil
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

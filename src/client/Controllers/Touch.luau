--!nonstrict
-- Touch controls (Tarkov has none: EFT_PARITY exception 4; docs/design/TOUCH_CONTROLS.md). Built on what mobile
-- shooters settled on (CoD Mobile, PUBG Mobile, Arena Breakout):
--   * a movement stick on the left: it walks, runs when pushed past its ring, and locks the run when the thumb lets go
--     on the lock above it (a touch on the stick ends the lock); it floats to where the thumb lands unless fixed;
--   * FIRE aims down sights while held (AIM WHEN FIRING) and turns the view as the thumb moves on it;
--   * round icon buttons, rounded squares only for the menu row (settings, exits, bag);
--   * one button, two actions: a tap and a hold (RELOAD / magazine check, CROUCH / prone, the weapon / inspect, the fire
--     mode / its check, MED / the best med at once);
--   * MED opens a wheel of the quick slots (Tarkov's 4 to 0), MORE a tray of the rarely used;
--   * every element can be moved, resized, faded or hidden (Touch.edit: Settings, CONTROLS, EDIT TOUCH LAYOUT).
-- Roblox's own stick and jump button are turned off while this layout is on (GuiService.TouchControlsEnabled).
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local TL = require(Shared.TouchLayout)
local Items = require(Shared.Items)

local Touch = {}
local ctx, K
local player = Players.LocalPlayer
local gui -- the controls (device safe area, the top bar band included)
local touchMode = false
local els = {} -- [id] = { e = element, btn, icon, x, y, size, alpha, shown }
local fingers = {} -- [InputObject] = handler table (drag / finish)
local editing = nil -- the layout editor's state while it is open
local HOLD = 0.35
local C = {}

-- ── geometry ───────────────────────────────────────────────────────────────────
local function unit()
	local H = gui and gui.AbsoluteSize.Y or 390
	return math.clamp(H / 390, 1, 1.35)
end

local function layoutOf(id)
	local mine = ctx.Settings.data.touchLayout
	return (type(mine) == "table" and mine[id]) or nil
end

-- shown unless the player hid it (h = true), or shown though hidden by default (h = false)
local function shownOf(e, mine)
	if mine and mine.h ~= nil then
		return not mine.h
	end
	return e.shown
end

-- the menu row's default places: centred in the top bar's free band (right of Roblox's own menu)
local function menuDefault(id)
	local W = gui.AbsoluteSize.X
	local band = GuiService.TopbarInset
	local size = TL.byId[id].size * unit()
	local gap = 12
	local order = { "set", "exits", "bag" }
	local list = {}
	for _, o in order do
		local st = els[o]
		if st and st.want then
			table.insert(list, o)
		end
	end
	local rowW = #list * size + math.max(0, #list - 1) * gap
	local x0 = math.max(W * 0.5 - rowW * 0.5, band.Min.X + 10 - gui.AbsolutePosition.X)
	local cy = math.max(band.Max.Y, size + 8) * 0.5 - (gui.AbsolutePosition.Y + GuiService:GetGuiInset().Y)
	local i = table.find(list, id) or 1
	return x0 + (i - 1) * (size + gap) + size * 0.5, cy
end

-- where an element stands (pixels in the gui) and its size, from the player's layout or the defaults
local function placeOf(id)
	local e = TL.byId[id]
	local mine = layoutOf(e.like or id) -- a stationary gun's buttons stand where FIRE, AIM and RELOAD do
	local W, H = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	local size = e.size * unit() * ((mine and mine.s) or 1)
	local x, y
	if mine and mine.x and mine.y then
		x, y = mine.x * W, mine.y * H
	elseif e.x < 0 then
		x, y = menuDefault(id)
	else
		x, y = e.x * W, e.y * H
	end
	return x, y, size, (mine and mine.o) or 1, e.like and true or shownOf(e, mine)
end

-- ── visuals ────────────────────────────────────────────────────────────────────
local function iconLabel(parent, name, frac)
	local il = Instance.new("ImageLabel")
	il.Name = "Icon"
	il.BackgroundTransparency = 1
	il.AnchorPoint = Vector2.new(0.5, 0.5)
	il.Position = UDim2.fromScale(0.5, 0.5)
	il.Size = UDim2.fromScale(frac or 0.56, frac or 0.56)
	il.Image = TL.ICONS
	local off, sz = TL.rect(TL.ICON[name] or 0)
	il.ImageRectOffset, il.ImageRectSize = off, sz
	il.ImageColor3 = C.icon
	il.ZIndex = 3
	il.Parent = parent
	return il
end

local function roundButton(parent, name, square)
	local b = Instance.new("ImageButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Image = ""
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = C.bg
	b.BorderSizePixel = 0
	b.Selectable = false
	b.ZIndex = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = square and UDim.new(0.22, 0) or UDim.new(0.5, 0)
	corner.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = C.line
	st.Thickness = 1.5
	st.Transparency = 0.45
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	b.Parent = parent
	return b
end

-- the look of a button: on (held, aiming, crouched...) lights it
local function paint(st, on)
	if not st.btn then
		return
	end
	local a = st.alpha or 1
	local faded = st.under and 0.3 or 1
	st.btn.BackgroundColor3 = on and C.on or C.bg
	st.btn.BackgroundTransparency = 1 - (on and 0.75 or 0.5) * a * faded
	if st.icon then
		st.icon.ImageTransparency = 1 - math.max(0.15, a * faded)
		st.icon.ImageColor3 = on and C.iconOn or C.icon
	end
	local stroke = st.btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1 - 0.55 * a * faded
	end
end

-- ── a finger on an element ─────────────────────────────────────────────────────
local function trigger(action, down)
	ctx.Input.trigger(action, down)
end

local tray, wheel -- forward (their open/close)
local stickDown, stickUp, stickMove -- forward

-- what a finger does on element st (press / tap and hold / drag / special); returns the finger's handler
local function fingerOn(st, pos)
	local e = st.e
	local f = { last = pos, st = st, t0 = os.clock() }
	if e.special == "joy" then
		stickDown(pos)
		f.drag = stickMove
		f.finish = stickUp
		return f
	elseif e.special == "jump" then
		if ctx.Movement and ctx.Movement.jumpPress then
			ctx.Movement.jumpPress()
		end
		st.held = true
		f.finish = function()
			st.held = false
		end
		return f
	elseif e.special == "tray" then
		tray(not Touch.trayOpen)
		return f
	end
	if (e.id == "fire" or e.id == "fireL") and not e.mount then
		-- AIM WHEN FIRING (CoD's ADS fire): a gun in hand comes up to the sights while FIRE is held
		local W = ctx.Weapon
		if ctx.Settings.data.aimOnFire ~= false and W.hasWeapon and not W.melee and not W.aiming then
			W.setAim(true)
			f.autoAim = true
		end
	end
	if e.press then
		trigger(e.press, true)
		st.held = true
	elseif e.tap or e.special == "wheel" then
		-- a tap does the tap action when the finger lifts; held HOLD, the hold action starts
		local mine = {}
		f.tok = mine
		task.delay(HOLD, function()
			if f.tok ~= mine then
				return
			end
			f.held = true
			if e.hold then
				trigger(e.hold, true)
			end
		end)
	end
	if e.drag then
		f.drag = function(p)
			local d = p - f.last
			f.last = p
			ctx.Camera.addLook(d.X * 0.8, d.Y * 0.8)
		end
	end
	f.finish = function()
		f.tok = nil
		if e.press then
			trigger(e.press, false)
			st.held = false
		elseif f.held then
			if e.hold then
				trigger(e.hold, false)
			end
		elseif e.special == "wheel" then
			wheel(not Touch.wheelOpen)
		elseif e.tap then
			trigger(e.tap, true)
			trigger(e.tap, false)
		end
		if f.autoAim then
			ctx.Weapon.setAim(false)
		end
	end
	return f
end

-- ── the movement stick ─────────────────────────────────────────────────────────
-- walking is analog (how far the knob goes); past the ring, thumb upward: running; let go on the lock: the run stays on
local stick = { active = false, base = Vector2.zero, off = Vector2.zero, run = false, locked = false, r = 62 }
local SPRINT_PUSH = 1.25 -- the thumb this many radii out (forward half) runs
local LOCK_AT = 2.3 -- the lock sits this many radii above the base

local function stickParts()
	local st = els.joy
	return st and st.ring, st and st.knob, st and st.lock
end

function stickDown(pos)
	local st = els.joy
	stick.active, stick.r = true, st.size * 0.5
	if stick.locked then
		stick.locked = false -- a touch on the stick ends the lock
		ctx.Movement.setSprint(false)
	end
	-- floating: the stick comes to the thumb (FLOATING STICK on); fixed: it stays where the layout puts it
	if ctx.Settings.data.joyFloat ~= false then
		stick.base = pos
	else
		stick.base = Vector2.new(st.x, st.y)
	end
	stickMove(pos)
end

function stickMove(pos)
	local raw = pos - stick.base
	local r = stick.r
	local len = raw.Magnitude
	stick.off = len > r and raw.Unit * r or raw
	-- forward (within 55 degrees of straight up) and past the ring: run
	local up = len > 0 and (-raw.Y / len) or 0
	stick.run = len > r * SPRINT_PUSH and up > math.cos(math.rad(55))
	ctx.Movement.setSprint(stick.run)
	stick.overLock = stick.run and (pos - (stick.base + Vector2.new(0, -r * LOCK_AT))).Magnitude < r * 0.6
end

function stickUp()
	stick.active = false
	stick.off = Vector2.zero
	if stick.overLock then
		stick.locked = true -- auto-run until the stick is touched again
	else
		stick.run = false
		ctx.Movement.setSprint(false)
	end
	stick.overLock = false
end

-- every frame: the stick's direction to the humanoid (after Roblox's own controls, so ours wins), and its look
local function stickStep()
	local st = els.joy
	if not st or not touchMode then
		return
	end
	local r = math.max(1, stick.r)
	local v
	if stick.locked then
		v = Vector3.new(0, 0, -1)
		if not ctx.Movement.sprinting then
			ctx.Movement.setSprint(true)
		end
	elseif stick.active then
		v = Vector3.new(stick.off.X / r, 0, stick.off.Y / r)
	end
	if v then
		player:Move(v, true)
		stick.moving = true
	elseif stick.moving then
		player:Move(Vector3.zero, true)
		stick.moving = false
	end
	-- the look: the ring where the stick is, the knob in it, the lock above it while running
	local ring, knob, lock = stickParts()
	if ring then
		local base = stick.active and stick.base or Vector2.new(st.x, st.y)
		ring.Position = UDim2.fromOffset(base.X, base.Y)
		knob.Position = UDim2.fromOffset(base.X + stick.off.X, base.Y + stick.off.Y)
		local showLock = stick.locked or stick.run
		lock.Visible = showLock and st.shown
		lock.Position = UDim2.fromOffset(base.X, base.Y - stick.r * LOCK_AT)
		lock.BackgroundColor3 = (stick.locked or stick.overLock) and C.on or C.bg
		knob.BackgroundColor3 = (stick.run or stick.locked) and C.on or C.knob
	end
end

-- ── the med wheel: the best med, then the quick slots (Tarkov's 4 to 0) with their items ────────────────────────────
local wheelParts = {}
local function wheelItems()
	local out = { { action = "Heal", icon = "AUTO" } }
	local d = ctx.State.data
	local q = ctx.Settings.data.quick or {}
	for _, slot in { "4", "5", "6", "7", "8", "9", "0" } do
		local g = q[slot]
		local it = g and d and d.items and d.items[g]
		if it then
			table.insert(out, { action = "Quick" .. slot, item = it.id, slot = slot })
		end
	end
	return out
end

function wheel(open)
	Touch.wheelOpen = open == true
	for _, b in wheelParts do
		b:Destroy()
	end
	table.clear(wheelParts)
	if not Touch.wheelOpen then
		return
	end
	if Touch.trayOpen then
		tray(false)
	end
	local st = els.med
	local list = wheelItems()
	local size = 48 * unit()
	local R = st.size * 0.5 + size * 0.9
	-- a fan above the button, from the left round to the right
	local n = #list
	for i, w in list do
		local a = math.rad(n == 1 and 270 or (200 + (i - 1) * (140 / math.max(1, n - 1))))
		local b = roundButton(gui, "Wheel_" .. w.action, false)
		b.Size = UDim2.fromOffset(size, size)
		b.Position = UDim2.fromOffset(st.x + R * math.cos(a), st.y + R * math.sin(a))
		b.ZIndex = 6
		b.BackgroundTransparency = 0.2
		if w.item then
			local pic = Instance.new("Frame")
			pic.BackgroundTransparency = 1
			pic.Size = UDim2.fromScale(1, 1)
			pic.ZIndex = 7
			pic.Parent = b
			K.itemIcon(pic, w.item, size, size, false, false, 7)
			local lab = K.label(b, w.slot, 11, { Position = UDim2.fromOffset(0, -2), Size = UDim2.fromOffset(14, 14), FontFace = K.bold, ZIndex = 8 })
			lab.TextXAlignment = Enum.TextXAlignment.Center
		else
			iconLabel(b, w.icon, 0.6).ZIndex = 7
		end
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				trigger(w.action, true)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				trigger(w.action, false)
				wheel(false)
			end
		end)
		table.insert(wheelParts, b)
	end
	Touch.wheelUntil = os.clock() + 4
end

-- ── the tray (MORE): the rarely used ────────────────────────────────────────────
local trayParts = {}
local function trayNeeds(need)
	local W = ctx.Weapon
	if need == "device" then
		return W.hasDevice ~= nil and W.hasDevice()
	elseif need == "combo" then
		return W.hasCombo ~= nil and W.hasCombo()
	elseif need == "goggles" then
		local NV = ctx.NightVision
		return NV ~= nil and NV.canFlip ~= nil and NV.canFlip()
	elseif need == "zoom" then
		return W.hasZoom ~= nil and W.hasZoom()
	end
	return true
end

function tray(open)
	Touch.trayOpen = open == true
	for _, b in trayParts do
		b:Destroy()
	end
	table.clear(trayParts)
	local more = els.more
	if more then
		paint(more, Touch.trayOpen)
	end
	if not Touch.trayOpen then
		return
	end
	if Touch.wheelOpen then
		wheel(false)
	end
	local list = {}
	for _, t in TL.TRAY do
		if trayNeeds(t.need) then
			table.insert(list, t)
		end
	end
	local size = 46 * unit()
	local gap = 10
	local cols = math.min(5, #list)
	local rows = math.ceil(#list / cols)
	local W, H = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	local gridW = cols * size + (cols - 1) * gap
	local x0 = math.clamp(more.x - gridW * 0.5, 8, W - gridW - 8)
	local y0 = more.y + more.size * 0.5 + gap
	if y0 + rows * (size + gap) > H - 8 then
		y0 = more.y - more.size * 0.5 - gap - rows * (size + gap) -- no room below: open upward
	end
	for i, t in list do
		local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
		local b = roundButton(gui, "Tray_" .. t.action, false)
		b.Size = UDim2.fromOffset(size, size)
		b.Position = UDim2.fromOffset(x0 + c * (size + gap) + size * 0.5, y0 + r * (size + gap) + size * 0.5)
		b.ZIndex = 6
		b.BackgroundTransparency = 0.2
		iconLabel(b, t.icon, 0.62).ZIndex = 7
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Touch.trayUntil = os.clock() + 5
				trigger(t.action, true)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				trigger(t.action, false)
			end
		end)
		table.insert(trayParts, b)
	end
	Touch.trayUntil = os.clock() + 5
end

-- ── building and placing ───────────────────────────────────────────────────────
local function build()
	for _, st in els do
		for _, k in { "btn", "ring", "knob", "lock" } do
			if st[k] then
				st[k]:Destroy()
			end
		end
	end
	table.clear(els)
	for _, e in TL.ELEMENTS do
		local st = { e = e }
		els[e.id] = st
		if e.special == "joy" then
			-- the stick: a ring, a knob, and the run lock above it
			local ring = roundButton(gui, "Stick", false)
			ring.BackgroundTransparency = 1
			ring.Active = false
			ring.Interactable = false
			local knob = roundButton(gui, "StickKnob", false)
			knob.Active = false
			knob.Interactable = false
			knob.ZIndex = 3
			local lock = roundButton(gui, "StickLock", false)
			lock.Active = false
			lock.Interactable = false
			iconLabel(lock, "LOCK", 0.55)
			lock.Visible = false
			st.ring, st.knob, st.lock = ring, knob, lock
			-- the area a thumb lands in to move: the left of the screen below the vitals (the right is for looking)
			local zone = Instance.new("TextButton")
			zone.Name = "StickZone"
			zone.Text = ""
			zone.BackgroundTransparency = 1
			zone.AutoButtonColor = false
			zone.ZIndex = 1
			zone.Selectable = false
			zone.Parent = gui
			st.btn = zone
		else
			local b = roundButton(gui, "Btn_" .. e.id, e.square)
			st.btn = b
			st.icon = iconLabel(b, e.icon, e.square and 0.6 or 0.56)
		end
		st.btn.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch or editing then
				return
			end
			local f = fingerOn(st, Vector2.new(input.Position.X, input.Position.Y) - gui.AbsolutePosition)
			fingers[input] = f
		end)
	end
end

local function place()
	if not gui then
		return
	end
	-- the menu row's default places depend on which of its buttons show
	for _, id in { "set", "exits", "bag" } do
		local st = els[id]
		if st then
			st.want = editing ~= nil or st.shown ~= false -- the editor shows all three
		end
	end
	for id, st in els do
		local x, y, size, alpha, shown = placeOf(id)
		st.x, st.y, st.size, st.alpha, st.wantShown = x, y, size, alpha, shown
		if st.e.special == "joy" then
			st.ring.Size = UDim2.fromOffset(size, size)
			st.knob.Size = UDim2.fromOffset(size * 0.46, size * 0.46)
			st.lock.Size = UDim2.fromOffset(size * 0.42, size * 0.42)
			st.ring.BackgroundTransparency = 1
			local stroke = st.ring:FindFirstChildOfClass("UIStroke")
			stroke.Thickness = 2
			stroke.Transparency = 1 - 0.6 * alpha
			st.knob.BackgroundTransparency = 1 - 0.35 * alpha
			-- the zone: the left 40 % of the screen under the top quarter (fixed stick: around it)
			local W, H = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
			if ctx.Settings.data.joyFloat ~= false then
				st.btn.Position = UDim2.fromOffset(0, H * 0.3)
				st.btn.Size = UDim2.fromOffset(W * 0.4, H * 0.7)
			else
				st.btn.Position = UDim2.fromOffset(x - size, y - size)
				st.btn.Size = UDim2.fromOffset(size * 2, size * 2)
			end
		else
			st.btn.Size = UDim2.fromOffset(size, size)
			st.btn.Position = UDim2.fromOffset(x, y)
		end
	end
end
Touch.place = place

-- ── every 0.1 s: who shows, what is lit ─────────────────────────────────────────
local function refresh()
	if not gui then
		return
	end
	local touch = ctx.Input.device() == "Touch" or (UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.GamepadEnabled)
	if touch ~= touchMode then
		touchMode = touch
		-- Roblox's own stick and jump button give way to ours
		pcall(function()
			GuiService.TouchControlsEnabled = not touch
		end)
		place()
		if ctx.Hud and ctx.Hud.layout then
			ctx.Hud.layout()
		end
	end
	gui.Enabled = (touch and not ctx.Input.isMenu()) or editing ~= nil
	if editing then
		return
	end
	local inRaid = ctx.State.inRaid()
	local atGun = ctx.Stationary ~= nil and ctx.Stationary.mounted == true
	local W, M = ctx.Weapon, ctx.Movement
	local rects = ctx.Hud and ctx.Hud.exitRects
	for id, st in els do
		local e = st.e
		local shown = st.wantShown and (inRaid or not e.raid)
		if e.mount then
			shown = shown and atGun
		elseif atGun then
			-- at a stationary gun its own buttons take over (Stationary.luau); the menu row stays
			shown = shown and (id == "set" or id == "bag")
		end
		if id == "breath" then
			shown = shown and W.aiming == true
		elseif id == "light" then
			shown = shown and W.hasDevice ~= nil and W.hasDevice()
		elseif id == "nv" then
			local NV = ctx.NightVision
			shown = shown and NV ~= nil and NV.canFlip ~= nil and NV.canFlip()
		end
		st.shown = shown
		if e.special == "joy" then
			st.ring.Visible = shown
			st.knob.Visible = shown
			st.btn.Visible = shown
		else
			st.btn.Visible = shown
		end
		-- a button under a row of the exits list, or under the open tray or wheel, fades so what is on top reads
		local under = false
		if shown and st.btn and not e.square then
			local p, sz = st.btn.AbsolutePosition, st.btn.AbsoluteSize
			for _, r in rects or {} do
				if p.X < r[3] and p.X + sz.X > r[1] and p.Y < r[4] and p.Y + sz.Y > r[2] then
					under = true
					break
				end
			end
			for _, list in { trayParts, wheelParts } do
				for _, b in list do
					local q, qs = b.AbsolutePosition, b.AbsoluteSize
					if p.X < q.X + qs.X and p.X + sz.X > q.X and p.Y < q.Y + qs.Y and p.Y + sz.Y > q.Y then
						under = true
						break
					end
				end
			end
		end
		st.under = under
		local on = st.held
		if id == "aim" then
			on = W.aiming
		elseif id == "crouch" then
			on = M.crouching or M.prone
		elseif id == "leanL" then
			on = M.leanTarget < 0
		elseif id == "leanR" then
			on = M.leanTarget > 0
		elseif id == "light" then
			on = W.light
		elseif id == "nv" then
			on = ctx.NightVision and ctx.NightVision.down
		elseif id == "more" then
			on = Touch.trayOpen
		elseif id == "med" then
			on = Touch.wheelOpen
		elseif id == "mzoom" then
			on = ctx.Stationary and ctx.Stationary.zooming
		end
		if e.special ~= "joy" then
			paint(st, on == true)
		end
		-- the crouch button shows the stance it is in
		if id == "crouch" and st.icon then
			local off, sz = TL.rect(M.prone and TL.ICON.PRONE or TL.ICON.CROUCH)
			st.icon.ImageRectOffset, st.icon.ImageRectSize = off, sz
		end
	end
	-- the menu row re-centres when EXIT comes or goes (raid / hideout)
	local key = tostring(els.exits and els.exits.shown)
	if key ~= Touch.menuKey then
		Touch.menuKey = key
		place()
	end
	if Touch.trayOpen and (os.clock() > (Touch.trayUntil or 0) or not inRaid) then
		tray(false)
	end
	if Touch.wheelOpen and (os.clock() > (Touch.wheelUntil or 0) or not inRaid) then
		wheel(false)
	end
end

-- ── the HUD asks ───────────────────────────────────────────────────────────────
-- where the menu row ends (screen pixels from the top) while it stands in the top band, else nil: the HUD drops the exits
-- list under it and keeps its notices below it
function Touch.topRowBottom()
	if not touchMode or not gui then
		return nil
	end
	local bottom = nil
	for _, id in { "set", "exits", "bag" } do
		local st = els[id]
		if st and st.wantShown and st.y and st.y < gui.AbsoluteSize.Y * 0.25 then
			local b = st.y + st.size * 0.5 + gui.AbsolutePosition.Y + GuiService:GetGuiInset().Y
			bottom = math.max(bottom or 0, b)
		end
	end
	return bottom
end

-- an element's box (GUI absolute pixels: x0, y0, x1, y1) while the touch layout is on, else nil (the HUD keeps its
-- toasts off the stick)
function Touch.rectOf(id)
	local st = els[id]
	if not (touchMode and st and st.x and st.wantShown) then
		return nil
	end
	local p = gui.AbsolutePosition
	local h = st.size * 0.5
	return p.X + st.x - h, p.Y + st.y - h, p.X + st.x + h, p.Y + st.y + h
end

Touch.tray = function()
	return Touch.trayOpen == true
end

-- ── the layout editor ──────────────────────────────────────────────────────────
-- Every element shows (the hidden ones dimmed). Drag one to move it; tap it to pick it, then SIZE, OPACITY and SHOW /
-- HIDE act on it. SAVE keeps the layout in the profile (Settings.touchLayout), RESET goes back to the defaults.
local function editPanel()
	local ed = editing
	-- top left, where the default layout has no controls (the vitals sit under it while editing)
	local f = K.frame(ed.gui, {
		Name = "EditBar", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(348, 136),
		BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.1, ZIndex = 20,
	})
	K.new("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	ed.title = K.label(f, "TAP A CONTROL, THEN CHANGE IT  ·  DRAG IT TO MOVE IT", 11, {
		Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 28), FontFace = K.bold, ZIndex = 21, TextWrapped = true,
	})
	local n = 0
	local function btn(text, _w, fn)
		local col, row = n % 4, math.floor(n / 4)
		n += 1
		local b = K.button(f, text, { Position = UDim2.fromOffset(8 + col * 84, 34 + row * 50), Size = UDim2.fromOffset(78, 44), TextSize = 11, ZIndex = 21 })
		b.Name = "Edit_" .. string.gsub(string.gsub(string.gsub(text, "%-", "MINUS"), "%+", "PLUS"), "[^%w]", "")
		b.Activated:Connect(fn)
		return b
	end
	local function change(k, d, lo, hi)
		return function()
			local id = ed.sel
			if not id then
				return
			end
			local cur = ed.layout[id] or {}
			ed.layout[id] = cur
			cur[k] = math.clamp((cur[k] or 1) + d, lo, hi)
			Touch.editRefresh()
		end
	end
	btn("SIZE -", 66, change("s", -0.1, TL.LIMITS.s[1], TL.LIMITS.s[2]))
	btn("SIZE +", 66, change("s", 0.1, TL.LIMITS.s[1], TL.LIMITS.s[2]))
	btn("OPACITY -", 66, change("o", -0.15, TL.LIMITS.o[1], TL.LIMITS.o[2]))
	btn("OPACITY +", 66, change("o", 0.15, TL.LIMITS.o[1], TL.LIMITS.o[2]))
	ed.hideBtn = btn("HIDE", 70, function()
		local id = ed.sel
		if not id then
			return
		end
		local cur = ed.layout[id] or {}
		ed.layout[id] = cur
		cur.h = shownOf(TL.byId[id], cur) -- shown now: hide it; hidden: show it
		Touch.editRefresh()
	end)
	btn("RESET", 70, function()
		table.clear(ed.layout)
		ed.sel = nil
		Touch.editRefresh()
	end)
	btn("CANCEL", 76, function()
		Touch.edit(false)
	end)
	btn("SAVE", 76, function()
		Touch.edit(false, true)
	end)
end

function Touch.editRefresh()
	local ed = editing
	if not ed then
		return
	end
	-- the editor's working copy stands in for the saved layout while it is open
	local saved = ctx.Settings.data.touchLayout
	ctx.Settings.data.touchLayout = ed.layout
	place()
	ctx.Settings.data.touchLayout = saved
	for id, st in els do
		local shown = shownOf(st.e, ed.layout[id])
		if st.e.like then
			st.btn.Visible = false -- a stationary gun's buttons follow FIRE, AIM and RELOAD
			continue
		end
		local vis = { st.btn }
		if st.e.special == "joy" then
			vis = { st.ring, st.knob }
			st.ring.Position = UDim2.fromOffset(st.x, st.y)
			st.knob.Position = UDim2.fromOffset(st.x, st.y)
			st.btn.Position = UDim2.fromOffset(st.x - st.size * 0.5, st.y - st.size * 0.5)
			st.btn.Size = UDim2.fromOffset(st.size, st.size)
			st.btn.Visible = true
		end
		for _, v in vis do
			v.Visible = true
		end
		st.alpha = (shown and 1 or 0.35) * (st.alpha or 1)
		st.under = false
		if st.e.special == "joy" then
			-- the stick's touch area stays clear (a square behind the round stick read as a glitch); its ring shows the pick
			st.btn.BackgroundTransparency = 1
			st.knob.BackgroundTransparency = 1 - 0.35 * st.alpha
		else
			paint(st, ed.sel == id)
		end
		local stroke = st.btn:FindFirstChildOfClass("UIStroke") or (st.ring and st.ring:FindFirstChildOfClass("UIStroke"))
		if stroke then
			stroke.Color = ed.sel == id and C.on or C.line
			stroke.Thickness = ed.sel == id and 3 or 1.5
		end
	end
	if ed.sel then
		local e = TL.byId[ed.sel]
		local mine = ed.layout[ed.sel] or {}
		local shown = shownOf(e, mine)
		ed.title.Text = string.format("%s  ·  SIZE %d%%  ·  OPACITY %d%%%s", e.name, math.floor((mine.s or 1) * 100 + 0.5),
			math.floor((mine.o or 1) * 100 + 0.5), shown and "" or "  ·  HIDDEN")
		ed.hideBtn.Text = shown and "HIDE" or "SHOW"
	else
		ed.title.Text = "TAP A CONTROL TO CHANGE IT  ·  DRAG IT TO MOVE IT"
		ed.hideBtn.Text = "HIDE"
	end
end

-- open (on = true) or close the editor; save keeps the working layout
function Touch.edit(on, save)
	if on and not editing then
		local cur = ctx.Settings.data.touchLayout
		local copy = {}
		for id, v in (type(cur) == "table" and cur or {}) do
			copy[id] = table.clone(v)
		end
		editing = { layout = copy, sel = nil }
		tray(false)
		wheel(false)
		ctx.Input.setMenu(true)
		local eg = K.screen("ZR_TouchEdit", 7)
		eg.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		editing.gui = eg
		local dim = K.frame(eg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, ZIndex = 0 })
		dim.Active = false
		editPanel()
		gui.DisplayOrder = 8 -- the controls above the dimming, under nothing else
		gui.Enabled = true
		Touch.editRefresh()
	elseif not on and editing then
		local ed = editing
		editing = nil
		if save then
			ctx.Settings.set("touchLayout", TL.sanitize(ed.layout) or {})
		end
		ed.gui:Destroy()
		gui.DisplayOrder = 6
		ctx.Input.setMenu(false)
		build()
		place()
		refresh()
	end
end

-- in the editor a finger moves the control it lands on (and picks it)
local function editBegan(input)
	if not editing or input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y) - gui.AbsolutePosition
	local best, bd = nil, math.huge
	for id, st in els do
		local d = (Vector2.new(st.x, st.y) - pos).Magnitude
		if not st.e.like and d < st.size * 0.6 and d < bd then
			best, bd = id, d
		end
	end
	if best then
		editing.sel = best
		editing.drag = { id = best, input = input, from = pos, x0 = els[best].x, y0 = els[best].y }
		Touch.editRefresh()
	end
end

local function editMoved(input)
	local dr = editing and editing.drag
	if not dr or (dr.input ~= input and input.UserInputType ~= Enum.UserInputType.MouseMovement) then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y) - gui.AbsolutePosition
	local W, H = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	local st = els[dr.id]
	local h = st.size * 0.5
	local x = math.clamp(dr.x0 + (pos.X - dr.from.X), h, W - h)
	local y = math.clamp(dr.y0 + (pos.Y - dr.from.Y), h, H - h)
	local cur = editing.layout[dr.id] or {}
	editing.layout[dr.id] = cur
	cur.x, cur.y = x / W, y / H
	Touch.editRefresh()
end

-- ── tests and the Studio bridge ────────────────────────────────────────────────
-- a finger on element id for secs, dragged by `drag` pixels (or "tray:<action>", "wheel:<action>")
function Touch.simulate(id, secs, drag)
	local kind, action = string.match(id, "^(%a+):(%w+)$")
	if kind == "tray" or kind == "wheel" then
		local parts = kind == "tray" and trayParts or wheelParts
		local name = (kind == "tray" and "Tray_" or "Wheel_") .. action
		for _, b in parts do
			if b.Name == name then
				trigger(action, true)
				task.wait(secs or 0.05)
				trigger(action, false)
				if kind == "wheel" then
					wheel(false)
				end
				return true
			end
		end
		return false
	end
	local st = els[id]
	if not st or not st.x then
		return false
	end
	local p0 = Vector2.new(st.x, st.y)
	local f = fingerOn(st, p0)
	if drag then
		task.wait(0.05)
		if f.drag then
			f.drag(p0 + drag)
		end
	end
	task.wait(secs or 0.05)
	if f.finish then
		f.finish()
	end
	return true
end

-- the stick held at offset (dx, dy) in radii for secs (dy -1.5: pushed past the ring forward); the thumb lands
-- (landX, landY) radii from the stick's centre (floating: the stick comes to it; fixed: it stays and the knob goes there)
function Touch.stick(dx, dy, secs, release, landX, landY)
	local st = els.joy
	local centre = Vector2.new(st.x, st.y)
	stickDown(centre + Vector2.new(landX or 0, landY or 0) * (st.size * 0.5))
	local landed = { base = { stick.base.X - centre.X, stick.base.Y - centre.Y }, knob = { stick.off.X, stick.off.Y } }
	stickMove(stick.base + Vector2.new(dx, dy) * stick.r)
	task.wait(secs or 0.5)
	local out = { run = stick.run, locked = stick.locked, sprinting = ctx.Movement.sprinting, landed = landed, r = stick.r }
	if release ~= false then
		stickUp()
	end
	out.lockedAfter = stick.locked
	return out
end

function Touch.state()
	return {
		mode = touchMode, run = stick.run, locked = stick.locked, active = stick.active, tray = Touch.trayOpen == true,
		wheel = Touch.wheelOpen == true, editing = editing ~= nil, roblox = GuiService.TouchControlsEnabled,
	}
end

-- ── start ──────────────────────────────────────────────────────────────────────
function Touch.init(c)
	ctx = c
	K = c.UiKit
	C = {
		bg = Color3.fromRGB(18, 20, 18), on = K.C.ochre, line = Color3.fromRGB(205, 210, 196), knob = Color3.fromRGB(205, 210, 196),
		icon = Color3.fromRGB(232, 236, 226), iconOn = Color3.fromRGB(20, 20, 18),
	}
	HOLD = c.Input.HOLD or HOLD
	gui = K.screen("ZR_Touch", 6)
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	build()
	-- a finger's moves and its lifting reach the element it started on, wherever it goes
	UIS.InputChanged:Connect(function(input)
		if editing then
			editMoved(input)
			return
		end
		local f = fingers[input]
		if f and f.drag then
			f.drag(Vector2.new(input.Position.X, input.Position.Y) - gui.AbsolutePosition)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if editing then
			if editing.drag and editing.drag.input == input then
				editing.drag = nil
			end
			return
		end
		local f = fingers[input]
		if f then
			fingers[input] = nil
			if f.finish then
				f.finish()
			end
		end
	end)
	UIS.InputBegan:Connect(function(input)
		if editing then
			editBegan(input)
		end
	end)
	c.Input.deviceChanged:Connect(refresh)
	c.Settings.changed:Connect(function()
		if not editing then
			place()
		end
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		place()
		if Touch.trayOpen then
			tray(true)
		end
	end)
	-- the stick drives the humanoid after Roblox's control script has (ours wins the frame)
	RunService:BindToRenderStep("ZR_TouchStick", Enum.RenderPriority.Input.Value + 2, function()
		local ok, err = pcall(stickStep)
		if not ok then
			warn("[ZR] touch stick", err)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc > 0.1 then
			acc = 0
			refresh()
		end
	end)
	place()
	refresh()
end

return Touch

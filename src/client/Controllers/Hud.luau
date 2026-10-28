--!nonstrict
-- "FIELD RECORDER M4" HUD: REC/channel/timestamp, raid clock + exits, vitals, ammo, reticle, hitmarker,
-- progress (search/heal/extract), damage edge + direction, toasts, vignette. Event-driven + 10 Hz text.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Util = require(Shared.Util)
local Sounds = require(Shared.Sounds)
local SoundService = game:GetService("SoundService")

local Hud = {}
local ctx, K
local player = Players.LocalPlayer
local gui, vigGui, root, R = nil, nil, nil, {}
local ex, search, heal = nil, nil, nil
local dmgAlpha, dmgDir, hitT, hitKill = 0, nil, -1, false
local toasts = {}
local acc = 0

local function mono(parent, text, size, props)
	local l = K.label(parent, text, size, props)
	l.TextStrokeTransparency = 0.75
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	return l
end

local function bar(parent, pos, w, h, color)
	local back = K.frame(parent, { Position = pos, Size = UDim2.fromOffset(w, h), BackgroundColor3 = K.C.black, BackgroundTransparency = 0.55 })
	K.stroke(back, K.C.line, 0.7)
	local fill = K.frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	return back, fill
end

local function build()
	gui = K.screen("ZR_HUD", 5)
	vigGui = K.screen("ZR_Vignette", 1)
	vigGui.ScreenInsets = Enum.ScreenInsets.None
	-- vignette: four soft edges (gradients, no textures)
	for i, spec in { { UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90 }, { UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90 }, { UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 }, { UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 } } do
		local f = K.frame(vigGui, { Size = spec[1], Position = spec[2], BackgroundColor3 = K.C.black, BackgroundTransparency = 0 })
		local g = K.new("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }) }, f)
		f.Name = "Vig" .. i
		R["vig" .. i] = f
		g.Name = "G"
	end
	R.dmg = K.frame(vigGui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("6E1E14"), BackgroundTransparency = 1 })
	K.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.2) }) }, R.dmg)

	root = K.frame(gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	R.scale = K.new("UIScale", { Scale = K.scale() }, root)
	-- top-left recorder block
	local tl = K.frame(root, { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(380, 76) })
	R.rec = mono(tl, "", 15, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(380, 20), FontFace = K.bold })
	R.time = mono(tl, "", 14, { Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(380, 18) })
	R.sig = mono(tl, "", 12, { Position = UDim2.fromOffset(0, 38), Size = UDim2.fromOffset(380, 16), TextColor3 = K.C.dim })
	R.dev = mono(tl, "", 11, { Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(380, 16), TextColor3 = K.C.ochre })
	-- top-right status
	local tr = K.frame(root, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(420, 80) })
	R.status = mono(tr, "", 15, { Size = UDim2.fromOffset(420, 20), TextXAlignment = Enum.TextXAlignment.Right, FontFace = K.bold })
	R.timer = mono(tr, "", 14, { Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(420, 18), TextXAlignment = Enum.TextXAlignment.Right })
	R.exits = mono(tr, "", 11, { Position = UDim2.fromOffset(0, 38), Size = UDim2.fromOffset(420, 32), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	-- bottom-left vitals
	local bl = K.frame(root, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12), Size = UDim2.fromOffset(300, 64) })
	mono(bl, "HEALTH", 11, { Size = UDim2.fromOffset(80, 14), TextColor3 = K.C.dim })
	R.hpText = mono(bl, "100", 13, { Position = UDim2.fromOffset(222, 0), Size = UDim2.fromOffset(60, 14), TextXAlignment = Enum.TextXAlignment.Right, FontFace = K.bold })
	R.hpSeg = {}
	for i = 1, 10 do
		local seg = K.frame(bl, { Position = UDim2.fromOffset((i - 1) * 28, 18), Size = UDim2.fromOffset(25, 9), BackgroundColor3 = K.C.text })
		R.hpSeg[i] = seg
	end
	mono(bl, "STAMINA", 11, { Position = UDim2.fromOffset(0, 32), Size = UDim2.fromOffset(80, 14), TextColor3 = K.C.dim })
	R.staBack, R.sta = bar(bl, UDim2.fromOffset(0, 48), 277, 4, K.C.ochre)
	R.statusLine = mono(root, "", 13, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -82), Size = UDim2.fromOffset(300, 16), TextColor3 = K.C.orange, FontFace = K.bold })
	-- bottom-right weapon
	local br = K.frame(root, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -12), Size = UDim2.fromOffset(260, 60) })
	R.weapon = mono(br, "", 12, { Size = UDim2.fromOffset(260, 14), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.dim })
	R.ammo = mono(br, "", 30, { Position = UDim2.fromOffset(0, 14), Size = UDim2.fromOffset(260, 32), TextXAlignment = Enum.TextXAlignment.Right, FontFace = K.bold })
	R.mode = mono(br, "", 11, { Position = UDim2.fromOffset(0, 46), Size = UDim2.fromOffset(260, 14), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = K.C.dim })
	-- centre: reticle, hitmarker, damage direction
	R.dot = K.frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), BackgroundColor3 = K.C.text, BackgroundTransparency = 0.25 })
	R.hit = K.frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Visible = false })
	for _, rot in { 45, -45 } do
		K.frame(R.hit, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 2), Rotation = rot, BackgroundColor3 = K.C.text })
	end
	R.dir = K.frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(220, 220), BackgroundTransparency = 1, Visible = false })
	K.frame(R.dir, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(46, 4), BackgroundColor3 = K.C.red })
	-- progress (search / heal / extract)
	R.prog = K.frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(300, 38), BackgroundTransparency = 1, Visible = false })
	R.progLabel = mono(R.prog, "", 13, { Size = UDim2.fromOffset(300, 18), TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold })
	R.progBack, R.progFill = bar(R.prog, UDim2.fromOffset(0, 22), 300, 6, K.C.ochre)
	-- toasts
	R.toasts = K.frame(root, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.42, 0), Size = UDim2.fromOffset(420, 120) })
	K.list(R.toasts, nil, 2)
	R.tag = mono(root, "", 11, { Position = UDim2.fromOffset(14, 84), Size = UDim2.fromOffset(380, 14), TextColor3 = K.C.orange })
	-- death overlay
	R.death = K.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.C.black, BackgroundTransparency = 1, Visible = false, ZIndex = 10 })
	R.deathText = mono(R.death, "[ SIGNAL LOST ]", 28, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 40), TextXAlignment = Enum.TextXAlignment.Center, FontFace = K.bold, ZIndex = 11 })
end

function Hud.toast(text, tone)
	local l = mono(R.toasts, text, 13, { Size = UDim2.fromOffset(420, 17), TextColor3 = (tone == "warn" and K.C.orange) or (tone == "good" and K.C.green) or K.C.text })
	table.insert(toasts, { l = l, t = os.clock() })
	if #toasts > 5 then
		table.remove(toasts, 1).l:Destroy()
	end
end

local function compass(v)
	local ang = math.deg(math.atan2(v.X, -v.Z)) % 360
	local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	return names[math.floor((ang + 22.5) / 45) % 8 + 1]
end
Hud.compass = compass

local function slowUpdate()
	local d = ctx.State.data
	local inRaid = ctx.State.inRaid()
	local raid = ctx.State.raid
	local now = workspace:GetServerTimeNow()
	local blink = math.floor(os.clock() * 1.2) % 2 == 0
	R.rec.Text = string.format('<font color="#C24A35">%s</font> REC   %s', blink and "●" or "○", "CH.04")
	R.dev.Text = Config.RECORDER .. (inRaid and "  ·  QUAY 7 TELEMETRY" or "  ·  RELAY 7 STANDBY")
	local clockBase = inRaid and raid and (7 * 3600 + 10 * 60 + (now - raid.started)) or (6 * 3600 + 40 * 60 + now % 3600)
	R.time.Text = os.date("!%Y.%m.%d", math.floor(now)) .. "  " .. os.date("!%H:%M:%S", math.floor(clockBase))
	local bars = inRaid and (3 + (math.floor(now / 7) % 2)) or 4
	R.sig.Text = "SIG " .. string.rep("|", bars) .. '<font color="#4A504C">' .. string.rep("|", 4 - bars) .. "</font>   BAT 81%"
	if inRaid and raid then
		local left = raid.endsAt - now
		local st = (ex and "EXTRACTING") or "ACTIVE"
		R.status.Text = Config.MAP_NAME .. " / " .. st
		R.timer.Text = string.format('<font color="%s">%s</font> LEFT', left < 60 and "#C07946" or "#D6DBC9", Util.clock(left))
		local names = {}
		local cam = workspace.CurrentCamera
		for _, e in raid.extracts or {} do
			local v = e.pos - cam.CFrame.Position
			table.insert(names, string.format("EXFIL %s %s %s %dm", e.id, e.name, compass(v), math.floor(v.Magnitude * 0.28)))
		end
		R.exits.Text = table.concat(names, "\n")
		R.tag.Text = ""
	else
		R.status.Text = "SAFEHOUSE / RELAY 7"
		R.timer.Text = d and (Util.commas(d.money or 0) .. " " .. Config.CURRENCY) or ""
		R.exits.Text = "[E] map table to deploy · stash lockers to equip"
		R.tag.Text = (d and d.persistence == "MEMORY") and "DEV STORE · MEMORY (not saved across sessions)" or ""
	end
	-- weapon
	local W = ctx.Weapon
	if inRaid and W.hasWeapon then
		R.weapon.Text = "R-17 CARBINE"
		R.ammo.Text = string.format('%d <font color="#8C948D" size="18">| %d</font>', W.ammo, W.spare)
		R.mode.Text = (W.mode == 1 and "AUTO" or "SEMI") .. (W.reloading and "  ·  RELOADING" or "")
	else
		R.weapon.Text, R.ammo.Text, R.mode.Text = "", "", ""
	end
end

local function fastUpdate(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hp = hum and hum.Health or 0
	local segs = math.ceil(hp / 10)
	for i, seg in R.hpSeg do
		seg.BackgroundTransparency = (i <= segs) and 0.1 or 0.8
		seg.BackgroundColor3 = (hp < 35) and K.C.orange or K.C.text
	end
	R.hpText.Text = tostring(math.floor(hp))
	R.sta.Size = UDim2.fromScale(math.clamp(ctx.Weapon.stamina / Config.MAX_STAMINA, 0, 1), 1)
	local S = ctx.Settings.data
	local inRaid = ctx.State.inRaid()
	R.dot.Visible = S.reticle and inRaid and not ctx.Weapon.aiming
	local vig = S.film ~= false and S.quality >= 2
	for i = 1, 4 do
		R["vig" .. i].Visible = vig
	end
	-- progress priority: extract > search > heal
	local label, frac = nil, 0
	local now = os.clock()
	if ex then
		local left = ex.ends - workspace:GetServerTimeNow()
		label = string.format("( o ) EXFIL %s  -  HOLD %.1fs", ex.name, math.max(0, left))
		local sec = math.ceil(left)
		if sec ~= ex.beep and sec >= 0 then
			ex.beep = sec
			ctx.Effects.sound(Sounds.EXTRACT_BEEP, SoundService, sec <= 1 and 0.55 or 0.4, sec <= 1 and 1.25 or 1)
		end
		frac = 1 - math.clamp(left / Config.EXTRACT_HOLD, 0, 1)
	elseif search then
		frac = math.clamp((now - search.t0) / search.dur, 0, 1)
		label = "SEARCHING  " .. string.upper(search.label or "")
		if frac >= 1 and now - search.t0 > search.dur + 2 then
			search = nil
		end
	elseif heal then
		frac = math.clamp((now - heal.t0) / heal.dur, 0, 1)
		label = "APPLYING DRESSING"
	end
	R.prog.Visible = label ~= nil
	if label then
		R.progLabel.Text = label
		R.progFill.Size = UDim2.fromScale(frac, 1)
	end
	R.statusLine.Text = (heal and "HEALING") or (ctx.Weapon.reloading and "RELOADING") or ((hp > 0 and hp < 35) and "CRITICAL") or ""
	-- hitmarker / damage
	R.hit.Visible = now - hitT < 0.12
	if R.hit.Visible then
		for _, c in R.hit:GetChildren() do
			c.BackgroundColor3 = hitKill and K.C.red or K.C.text
		end
	end
	dmgAlpha = math.max(0, dmgAlpha - dt * 1.4)
	R.dmg.BackgroundTransparency = 1 - dmgAlpha
	R.dir.Visible = dmgAlpha > 0.05 and dmgDir ~= nil
	if R.dir.Visible then
		local cam = workspace.CurrentCamera
		local v = cam.CFrame:VectorToObjectSpace(dmgDir - cam.CFrame.Position)
		R.dir.Rotation = math.deg(math.atan2(v.X, -v.Z))
	end
	for i = #toasts, 1, -1 do
		local t = toasts[i]
		local age = now - t.t
		if age > 4 then
			t.l:Destroy()
			table.remove(toasts, i)
		elseif age > 3 then
			t.l.TextTransparency = (age - 3)
		end
	end
	R.death.Visible = hum ~= nil and hum.Health <= 0
	if R.death.Visible then
		R.death.BackgroundTransparency = math.max(0.25, R.death.BackgroundTransparency - dt * 0.6)
	else
		R.death.BackgroundTransparency = 1
	end
	gui.Enabled = not (ctx.Inventory and ctx.Inventory.open)
end

function Hud.init(c)
	ctx = c
	K = c.UiKit
	build()
	c.State.on("toast", function(d)
		Hud.toast(d.text, d.tone)
	end)
	c.State.on("extract", function(d)
		if d.state == "start" then
			ex = { name = d.name, ends = d.ends }
			Hud.toast("EXFIL " .. tostring(d.zone) .. "  -  HOLD POSITION", "good")
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
			heal = { t0 = os.clock(), dur = d.t }
		else
			heal = nil
			if d.state == "cancel" then
				Hud.toast("DRESSING INTERRUPTED", "warn")
			end
		end
	end)
	c.State.on("hit", function(d)
		hitT = os.clock()
		hitKill = d.kill == true
		ctx.Effects.sound(Sounds.HIT, SoundService, hitKill and 0.7 or 0.5, hitKill and 0.8 or 1)
	end)
	c.State.on("kill", function()
		Hud.toast("TARGET DOWN", "good")
	end)
	c.State.on("dmg", function(d)
		dmgAlpha = math.clamp((d.amt or 10) / 45, 0.12, 0.45)
		dmgDir = typeof(d.from) == "Vector3" and d.from or nil
	end)
	c.State.on("raid", function(d)
		ex, search, heal = nil, nil, nil
		Hud.toast("INSERTION CONFIRMED  -  " .. Config.MAP_NAME, "good")
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
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		R.scale.Scale = K.scale()
	end)
end

return Hud

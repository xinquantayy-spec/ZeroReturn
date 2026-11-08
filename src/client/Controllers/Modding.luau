--!nonstrict
-- M14 weapon modding screen (Tarkov's "Modding"): the gun in 3D from its Blender parts (turn it by dragging), a
-- box for every slot of the build placed above or below the gun with a line to where the slot is, the parts you
-- carry or keep in the stash that fit a slot (click a slot), and the build's stats. Missing required parts show in
-- red: the gun does not fire without them. The server checks every change (fits, conflicts, size, multitool).
-- docs/weapons/WEAPON_MODDING.md
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local WP = require(Shared.WeaponParts)
local GunBuild = require(Shared.GunBuild)
local GunMeta = require(Shared.GunMeta)

local Modding = { open_ = nil }
local ctx, K
local gui
local state = { g = nil, yaw = 0, pitch = 0.08, pick = nil, scroll = Vector2.zero }
local defs = Items.defs

local function data()
	return ctx.State.data
end

-- ── stats ────────────────────────────────────────────────────────────────────
local function pct(x)
	return string.format("%+d%%", math.floor(x + (x >= 0 and 0.5 or -0.5)))
end

-- a part's effect and the slots it fits, for the detail strip and the part lists
function Modding.describePart(id, short)
	local p = WP.parts[id]
	if not p then
		return {}
	end
	local fx = {}
	table.insert(fx, (WP.CATS[p.cat] and WP.CATS[p.cat].name or string.upper(p.cat)) .. (WP.CATS[p.cat] and WP.CATS[p.cat].group == "vital" and " (VITAL)" or ""))
	if p.ergo and p.ergo ~= 0 then
		table.insert(fx, string.format("ERGO %+d", p.ergo))
	end
	if p.recoil and p.recoil ~= 0 then
		table.insert(fx, "RECOIL " .. pct(p.recoil))
	end
	if p.acc and p.acc ~= 0 then
		table.insert(fx, "ACCURACY " .. pct(-p.acc)) -- less spread = better accuracy
	end
	if p.vel and p.vel ~= 0 then
		table.insert(fx, "VELOCITY " .. pct(p.vel))
	end
	if p.loud and p.loud ~= 1 then
		table.insert(fx, "LOUDNESS " .. pct((p.loud - 1) * 100))
	end
	if p.zoom then
		table.insert(fx, string.format("%dx", p.zoom))
	end
	if p.capacity then
		table.insert(fx, string.format("%d SHELLS", p.capacity))
	end
	if p.light then
		table.insert(fx, "LIGHT")
	end
	if p.laser then
		table.insert(fx, "LASER")
	end
	local lines = { table.concat(fx, "   ") }
	if not short then
		table.insert(lines, p.desc)
	end
	return lines
end

-- the figures Tarkov's weapon screen shows, for a build
function Modding.figures(items, g)
	local it = items[g]
	local d = it and defs[it.id]
	local w = d and d.weapon and Weapons[d.weapon]
	if not w then
		return nil
	end
	local st = WP.stats(items, g)
	local mass = (d.mass or 0) + st.mass
	local mag = it.mag and items[it.mag]
	if mag then
		mass += (defs[mag.id].mass or 0) + (mag.a or 0) * ((mag.at and defs[mag.at] and defs[mag.at].mass) or 0)
	end
	local sw, sh = d.w, d.h
	if it.sz then
		sw, sh = it.sz[1], it.sz[2]
	end
	return {
		ergo = math.max(1, math.floor(w.ergo + st.ergo + 0.5)),
		recoilV = math.floor(w.recoilV * 100 * st.recoil + 0.5),
		recoilH = math.floor(w.recoilH * 100 * st.recoil + 0.5),
		moa = w.aimSpread * 60 * st.acc,
		range = st.range or ((d.kind == "pistol") and 50 or 100),
		velocity = math.floor(w.velocity * st.vel + 0.5),
		rpm = w.rpm, caliber = d.caliber, mass = mass, w = sw, h = sh, suppressed = st.suppressed, loud = st.loud,
		missing = WP.missing(items, g), operable = st.operable, zoom = st.zoom,
	}
end

function Modding.describeBuild(items, g, short)
	local f = Modding.figures(items, g)
	local lines = {}
	if f then
		table.insert(lines, string.format("ERGO %d   RECOIL %d / %d   ACCURACY %.1f MOA   SIGHTING %d m   VELOCITY %d m/s%s",
			f.ergo, f.recoilV, f.recoilH, f.moa, f.range, f.velocity, f.suppressed and "   SUPPRESSED" or ""))
	end
	local miss = WP.missing(items, g)
	if #miss > 0 then
		local names = {}
		for _, m in miss do
			table.insert(names, WP.SLOT_NAMES[m.slot] or string.upper(m.slot))
		end
		table.insert(lines, '<font color="#C24A35">MISSING: ' .. table.concat(names, ", ") .. (f and "  (WILL NOT FIRE)" or "") .. "</font>")
	end
	if not short then
		local n = 0
		WP.walk(items, g, function()
			n += 1
		end)
		table.insert(lines, string.format("%d PARTS", n - 1))
	end
	return lines
end

-- ── slots of a build ─────────────────────────────────────────────────────────
-- every slot on the build (the root's magazine well too): { parent, parentId, slot, child?, req, point (root frame) }
local function slotsOf(items, g)
	local out = {}
	local cfOf = {}
	for _, e in WP.layout(items, g) do
		cfOf[e.g] = e.cf
	end
	WP.walk(items, g, function(cg, it, _, _, depth)
		local meta = GunMeta.parts[it.id]
		local cf = cfOf[cg] or CFrame.identity
		local names = {}
		for sname in WP.SLOTS[it.id] or {} do
			table.insert(names, sname)
		end
		if depth == 0 and defs[it.id] and defs[it.id].family and meta and meta.slots.mag then
			table.insert(names, "mag")
		end
		table.sort(names)
		for _, sname in names do
			local sl = meta and meta.slots[sname]
			local child = (sname == "mag") and it.mag or (it.mods and it.mods[sname])
			local s = WP.SLOTS[it.id] and WP.SLOTS[it.id][sname]
			table.insert(out, {
				parent = cg, parentId = it.id, slot = sname, child = child and items[child] and child or nil,
				req = s ~= nil and s.req == true, point = (cf * (sl or CFrame.identity)).Position,
			})
		end
	end)
	return out
end

-- parts and magazines you have that fit a slot (loose in a grid; the ones on this build excluded)
local function candidates(items, rootG, sl)
	local d = data()
	local out = {}
	local locate = ctx.Inventory.locate
	local onBuild = {}
	WP.walk(items, rootG, function(cg)
		onBuild[cg] = true
	end)
	for pg, it in items do
		if not onBuild[pg] and locate and locate(d, pg) == "grid" then
			local def = defs[it.id]
			if sl.slot == "mag" then
				local base = defs[sl.parentId]
				if def and def.kind == "mag" and base and def.family == base.family then
					table.insert(out, { g = pg, it = it })
				end
			elseif WP.parts[it.id] and WP.fits(sl.parentId, sl.slot, it.id) then
				local skip = sl.child
				local conflict = WP.conflict(items, rootG, it.id, skip)
				table.insert(out, { g = pg, it = it, conflict = conflict })
			end
		end
	end
	table.sort(out, function(a, b)
		local na, nb = defs[a.it.id].name, defs[b.it.id].name
		if na ~= nb then
			return na < nb
		end
		return a.g < b.g
	end)
	return out
end

local function req(payload)
	local res = ctx.State.req("inv", payload)
	if res and not res.ok and not res.msg then
		ctx.State.toast(string.gsub(res.code or "FAILED", "_", " "), "warn")
	end
	return res
end

-- ── drawing ──────────────────────────────────────────────────────────────────
local function line(parent, a, b, color, z)
	local d = b - a
	local len = d.Magnitude
	if len < 1 then
		return
	end
	local f = K.frame(parent, {
		Name = "Lead", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(len, 1), Rotation = math.deg(math.atan2(d.Y, d.X)), BackgroundColor3 = color, BackgroundTransparency = 0.35,
		ZIndex = z or 3,
	})
	pcall(function()
		f.Interactable = false
	end)
	return f
end

local function close()
	if gui then
		gui.Enabled = false
		local w = K.root(gui):FindFirstChild("Window")
		if w then
			w:Destroy()
		end
	end
	state.g = nil
	state.pick = nil
	Modding.open_ = nil
	Modding.closedAt = os.clock()
end
Modding.close = close

function Modding.render()
	if not state.g then
		return
	end
	local d = data()
	local items = d and d.items
	local it = items and items[state.g]
	if not it then
		close()
		return
	end
	local old = K.root(gui):FindFirstChild("Window")
	if old then
		old:Destroy()
	end
	local vp = K.viewport(gui)
	local W = math.floor(math.min(vp.X - 24, 1180))
	local H = math.floor(math.min(vp.Y - 16, 680))
	local win = K.frame(K.root(gui), { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = K.C.bg, BackgroundTransparency = 0.02, ZIndex = 1 })
	K.stroke(win, K.C.line, 0.45)
	local def = defs[it.id]
	K.label(win, "MODDING  ·  " .. string.upper(def.name), 16, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 22), FontFace = K.bold, ZIndex = 2 })
	local closeB = K.button(win, "CLOSE", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(120, 28), ZIndex = 2 })
	closeB.Activated:Connect(close)
	-- right: the build's figures
	local statsW = math.floor(math.clamp(W * 0.24, 220, 300))
	local sp = K.frame(win, { Name = "Stats", Position = UDim2.new(1, -statsW - 10, 0, 44), Size = UDim2.fromOffset(statsW, H - 54), BackgroundColor3 = K.C.panel, ZIndex = 2 })
	K.stroke(sp, K.C.line, 0.8)
	K.pad(sp, 10)
	K.list(sp, nil, 3)
	local f = Modding.figures(items, state.g)
	local function row(label, value, color)
		local r = K.frame(sp, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), ZIndex = 3 })
		K.label(r, label, 12, { Size = UDim2.fromScale(0.58, 1), TextColor3 = K.C.dim, ZIndex = 3 })
		K.label(r, value, 13, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.42, 1), TextXAlignment = Enum.TextXAlignment.Right, FontFace = K.bold, TextColor3 = color or K.C.text, ZIndex = 3 })
	end
	if f then
		row("ERGONOMICS", tostring(f.ergo))
		row("RECOIL VERTICAL", tostring(f.recoilV))
		row("RECOIL HORIZONTAL", tostring(f.recoilH))
		row("ACCURACY", string.format("%.1f MOA", f.moa))
		row("SIGHTING RANGE", f.range .. " m")
		row("MUZZLE VELOCITY", f.velocity .. " m/s")
		row("FIRE RATE", f.rpm .. " RPM")
		row("CALIBER", tostring(f.caliber or "-"))
		row("WEIGHT", string.format("%.2f kg", f.mass))
		row("SIZE", string.format("%dx%d", f.w, f.h))
		if f.zoom then
			row("OPTIC", string.format("%dx", f.zoom))
		end
		row("SOUND", f.suppressed and "SUPPRESSED" or (f.loud > 1.05 and "LOUD" or "NORMAL"), f.suppressed and K.C.green or nil)
		if #f.missing > 0 then
			local names = {}
			for _, m in f.missing do
				table.insert(names, WP.SLOT_NAMES[m.slot] or string.upper(m.slot))
			end
			K.label(sp, "MISSING: " .. table.concat(names, ", ") .. "\nTHE WEAPON WILL NOT FIRE", 12, { Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextColor3 = K.C.red, FontFace = K.bold, ZIndex = 3 })
		else
			K.label(sp, "READY TO FIRE", 12, { Size = UDim2.new(1, 0, 0, 18), TextColor3 = K.C.green, FontFace = K.bold, ZIndex = 3 })
		end
	else
		for _, l in Modding.describeBuild(items, state.g, false) do
			K.label(sp, l, 12, { Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, ZIndex = 3 })
		end
	end
	K.label(sp, ctx.State.inRaid() and "In a raid, vital parts (barrels, handguards, gas blocks, grips, receivers) need a multitool in your inventory." or "Parts come from and go back to your stash.", 11, { Size = UDim2.new(1, 0, 0, 44), TextWrapped = true, TextColor3 = K.C.dim, ZIndex = 3 })
	-- centre: the 3D build with the slot boxes around it
	local areaW = W - statsW - 34
	local area = K.frame(win, { Name = "Build", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 44), Size = UDim2.fromOffset(areaW, H - 54), ZIndex = 2 })
	local slots = slotsOf(items, state.g)
	local top, bottom = {}, {}
	local TOP = { scope = true, rearsight = true, top = true, mount = true, sidemount = true, scout = true, optic = true, charge = true, dustcover = true, upper = true, slide = true }
	for _, sl in slots do
		if TOP[sl.slot] then
			table.insert(top, sl)
		else
			table.insert(bottom, sl)
		end
	end
	local box = math.floor(math.clamp((areaW - 16) / math.max(#top, #bottom, 6) - 8, 52, 84))
	local rowH = box + 18
	local vH = (H - 54) - 2 * rowH - 24
	local vpf = K.new("ViewportFrame", {
		Name = "View", BackgroundColor3 = Color3.fromHex("161A1C"), BackgroundTransparency = 0, Position = UDim2.fromOffset(0, rowH + 12),
		Size = UDim2.fromOffset(areaW, vH), Ambient = Color3.fromRGB(150, 152, 158), LightColor = Color3.fromRGB(255, 248, 236),
		LightDirection = Vector3.new(0.45, -1, 0.35), ZIndex = 2,
	}, area)
	K.stroke(vpf, K.C.line, 0.85)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 18
	cam.Parent = vpf
	vpf.CurrentCamera = cam
	local model = Instance.new("Model")
	model.Name = "Gun"
	local b = GunBuild.build(items, it, CFrame.identity, 1, state.g)
	local center, size = Vector3.zero, Vector3.new(0.3, 0.6, 2.5)
	if b then
		for _, p in b.parts do
			p.Anchored = true
			p.Parent = model
		end
		for _, p in b.mag do
			p.Anchored = true
			p.Parent = model
		end
		model.Parent = vpf
		local cf, sz = model:GetBoundingBox()
		center, size = cf.Position, sz
	else
		-- meshes still loading: the 2D picture of the build in the frame
		K.gunPicture(vpf, items, state.g, areaW - 40, vH - 30, false, 3)
	end
	local shift = b and b.shift or Vector3.zero
	-- camera on the picture side (-X), turned by yaw / pitch
	local aspect = areaW / math.max(1, vH)
	local tanV = math.tan(math.rad(cam.FieldOfView / 2))
	local dist = math.max(size.Z / 2 / (tanV * aspect), size.Y / 2 / tanV) * 1.25 + size.X
	local function camCF()
		local y, p = state.yaw, state.pitch
		local dir = Vector3.new(-math.cos(y) * math.cos(p), math.sin(p), math.sin(y) * math.cos(p))
		return CFrame.lookAt(center + dir * dist, center)
	end
	cam.CFrame = camCF()
	-- the slot boxes, with a lead to the slot on the gun
	local leads = {}
	local function project(pw)
		local c = cam.CFrame
		local pc = c:PointToObjectSpace(pw)
		if pc.Z >= -0.01 then
			return nil
		end
		local x = (pc.X / -pc.Z) / (tanV * aspect)
		local y = (pc.Y / -pc.Z) / tanV
		return Vector2.new((x + 1) / 2 * areaW, (1 - y) / 2 * vH + rowH + 12)
	end
	local function drawLeads()
		for _, l in leads do
			l:Destroy()
		end
		table.clear(leads)
		for _, e in area:GetChildren() do
			if e.Name == "Slot" and e:GetAttribute("PX") then
				local sl = e:GetAttribute("Top")
				local pw = Vector3.new(e:GetAttribute("PX"), e:GetAttribute("PY"), e:GetAttribute("PZ"))
				local pt = project(pw)
				if pt then
					local a = Vector2.new(e.Position.X.Offset + box / 2, sl and (e.Position.Y.Offset + rowH - 2) or e.Position.Y.Offset)
					local l = line(area, a, pt, K.C.line, 3)
					if l then
						table.insert(leads, l)
					end
				end
			end
		end
	end
	local function placeRow(list, y, isTop)
		-- in the order the slots appear along the gun, spread over the row
		for _, sl in list do
			local pt = project(sl.point - shift)
			sl.sx = pt and pt.X or areaW / 2
		end
		table.sort(list, function(a, c)
			return a.sx < c.sx
		end)
		local n = #list
		local gap = n > 0 and (areaW - n * box) / (n + 1) or 0
		for i, sl in list do
			local x = math.floor(gap * i + box * (i - 1))
			local f = K.new("TextButton", {
				Name = "Slot", Text = "", AutoButtonColor = true, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(box, rowH - 4),
				BackgroundColor3 = K.C.panel, BorderSizePixel = 0, ZIndex = 4, Selectable = true, SelectionImageObject = K.selection(),
			}, area)
			local missing = sl.req and not sl.child
			local picked = state.pick and state.pick.parent == sl.parent and state.pick.slot == sl.slot
			K.stroke(f, picked and K.C.ochre or (missing and K.C.red or K.C.line), (picked or missing) and 0 or 0.7, (picked or missing) and 2 or 1)
			K.label(f, WP.SLOT_NAMES[sl.slot] or (sl.slot == "mag" and "MAGAZINE" or string.upper(sl.slot)), 9, {
				Position = UDim2.fromOffset(3, 1), Size = UDim2.new(1, -6, 0, 12), TextColor3 = missing and K.C.red or K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
			})
			local pic = K.frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 14), Size = UDim2.new(1, -4, 1, -16), ZIndex = 5 })
			if sl.child then
				local cit = items[sl.child]
				if K.isBuild(items, sl.child) then
					K.gunPicture(pic, items, sl.child, box - 4, rowH - 20, false, 5)
				else
					K.itemIcon(pic, cit.id, box - 4, rowH - 20, false, false, 5)
				end
				K.label(f, defs[cit.id].short, 9, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -1), Size = UDim2.new(1, -6, 0, 11), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6 })
			else
				K.label(f, sl.req and "REQUIRED" or "EMPTY", 10, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 1, -16), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = missing and K.C.red or Color3.fromHex("4E5557"), ZIndex = 6 })
			end
			local pw = sl.point - shift
			f:SetAttribute("PX", pw.X)
			f:SetAttribute("PY", pw.Y)
			f:SetAttribute("PZ", pw.Z)
			f:SetAttribute("Top", isTop)
			f.Activated:Connect(function()
				if picked then
					state.pick = nil
				else
					state.pick = { parent = sl.parent, parentId = sl.parentId, slot = sl.slot, child = sl.child }
				end
				Modding.render()
			end)
		end
	end
	placeRow(top, 0, true)
	placeRow(bottom, rowH + 12 + vH + 12, false)
	drawLeads()
	-- drag to turn the gun
	local dragging = nil
	vpf.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input.Position
		end
	end)
	vpf.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dlt = input.Position - dragging
			dragging = input.Position
			state.yaw = (state.yaw + dlt.X * 0.01) % (math.pi * 2)
			state.pitch = math.clamp(state.pitch - dlt.Y * 0.008, -1.2, 1.2)
			cam.CFrame = camCF()
			drawLeads()
		end
	end)
	vpf.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)
	-- a picked slot: the parts that fit it
	if state.pick then
		local pk = state.pick
		local listW = math.floor(math.min(360, areaW * 0.5))
		local panel = K.frame(win, { Name = "Parts", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -statsW - 22, 0, 44 + rowH + 14), Size = UDim2.fromOffset(listW, math.min(vH - 4, 360)), BackgroundColor3 = K.C.bg, ZIndex = 20 })
		K.stroke(panel, K.C.ochre, 0.2)
		K.label(panel, (WP.SLOT_NAMES[pk.slot] or (pk.slot == "mag" and "MAGAZINE" or string.upper(pk.slot))) .. "  ·  " .. defs[pk.parentId].short, 12, { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 16), FontFace = K.bold, TextColor3 = K.C.ochre, ZIndex = 21 })
		local sf = K.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 24), Size = UDim2.new(1, -8, 1, -28), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ZIndex = 21 }, panel)
		K.list(sf, nil, 3)
		local order = 0
		local function prow(label, sub, icon, onClick, color)
			order += 1
			local r = K.new("TextButton", { Text = "", AutoButtonColor = true, LayoutOrder = order, Size = UDim2.new(1, -6, 0, 44), BackgroundColor3 = K.C.panel, BorderSizePixel = 0, ZIndex = 22, Selectable = true, SelectionImageObject = K.selection() }, sf)
			if icon then
				local pic = K.frame(r, { BackgroundColor3 = K.C.panel2, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(64, 40), ZIndex = 23 })
				K.itemIcon(pic, icon, 64, 40, false, false, 24)
			end
			K.label(r, label, 12, { Position = UDim2.fromOffset(icon and 72 or 8, 2), Size = UDim2.new(1, -(icon and 76 or 12), 0, 18), FontFace = K.bold, TextColor3 = color or K.C.text, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23 })
			K.label(r, sub or "", 10, { Position = UDim2.fromOffset(icon and 72 or 8, 20), Size = UDim2.new(1, -(icon and 76 or 12), 0, 22), TextColor3 = K.C.dim, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23 })
			r.Activated:Connect(onClick)
			return r
		end
		if pk.child then
			prow("REMOVE " .. string.upper(defs[items[pk.child].id].name), "Back to " .. (ctx.State.inRaid() and "your inventory" or "the stash"), nil, function()
				state.pick = nil
				req({ op = "unmod", g = pk.parent, slot = pk.slot })
			end, K.C.orange)
		end
		local cands = candidates(items, state.g, pk)
		for _, c in cands do
			local cd = defs[c.it.id]
			local sub
			if pk.slot == "mag" then
				sub = string.format("%d/%d %s", c.it.a or 0, cd.capacity or 0, c.it.at and defs[c.it.at] and defs[c.it.at].short or "")
			else
				sub = table.concat(Modding.describePart(c.it.id, true), "  ")
			end
			if c.conflict then
				sub = "DOES NOT GO WITH " .. string.upper(defs[c.conflict] and defs[c.conflict].short or c.conflict)
			end
			prow(string.upper(cd.name), sub, c.it.id, function()
				if c.conflict then
					ctx.State.toast("THAT PART DOES NOT GO WITH THIS BUILD", "warn")
					return
				end
				state.pick = nil
				req({ op = "mod", g = pk.parent, slot = pk.slot, mod = c.g })
			end, c.conflict and K.C.dim or nil)
		end
		if #cands == 0 and not pk.child then
			K.label(sf, "No part for this slot in " .. (ctx.State.inRaid() and "your inventory." or "your stash.") .. " Traders sell them.", 11, { LayoutOrder = 999, Size = UDim2.new(1, -6, 0, 40), TextWrapped = true, TextColor3 = K.C.dim, ZIndex = 22 })
		end
	end
end

function Modding.open(g)
	local d = data()
	if not d or not d.items or not d.items[g] then
		return
	end
	if state.g ~= g then
		state.yaw, state.pitch, state.pick = 0, 0.08, nil
	end
	state.g = g
	Modding.open_ = g
	gui.Enabled = true
	Modding.render()
end

function Modding.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Modding", 26)
	gui.Enabled = false
	c.State.changed:Connect(function()
		if state.g then
			Modding.render()
		end
	end)
	c.Input.on("Back", function(down)
		if down and state.g then
			if state.pick then
				state.pick = nil
				Modding.render()
			else
				close()
			end
		end
	end)
end

return Modding

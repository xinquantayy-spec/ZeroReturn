--!nonstrict
-- Tarkov's INSPECT window (docs/design/EFT_PARITY.md, section 1): the item's name, its 3D model (drag to turn it,
-- scroll to zoom), the description, and the attribute sheet for its kind. Weapons: weight, ergonomics, accuracy,
-- sighting range, recoil, muzzle velocity, effective distance, fire modes, rate of fire, caliber. Ammo: damage,
-- penetration and the chance to go through fresh armor of each class, armor damage, fragmentation and bleeding.
-- Armour (Tarkov 0.14, gameplay-2a): class, durability, material, the armoured zones, blunt throughput, ricochet, each
-- built-in part with its class and durability, each plate slot with the plate in it (or EMPTY); a plate: its class,
-- durability, material, position, the zones it covers and the vests it fits. Eyewear and masks: blindness protection,
-- lens tint and the slots they block. Meds, food, grenades, keys, parts, magazines and containers get their own rows.
-- Windows drag by the title bar and up to three stay open, as in Tarkov.
-- Gamepad (audit ui.5): the right stick turns the top window's model, B closes the top window.
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Stims = require(Shared.Stims)
local WP = require(Shared.WeaponParts)
local Weapons = require(Shared.Weapons)
local ItemModel = require(Shared.ItemModel)
local Equipment = require(Shared.Equipment)
local Plates = require(Shared.Plates)

local Inspect = {}
local ctx, K, gui
local defs = Items.defs
local windows = {} -- open windows, oldest first
local MAX_OPEN = 3
local zTop = 1
local M_PER_STUD = 0.32 -- 3.125 studs to the metre (Range.luau)
local ROW = 30

-- ── names ─────────────────────────────────────────────────────────────────────
local CALIBERS = {}
for _, d in defs do
	if d.kind == "ammo" and d.caliber and not CALIBERS[d.caliber] then
		CALIBERS[d.caliber] = string.match(d.name, "^(%S+)") or d.caliber
	end
end
local MODES = { AUTO = "FULL AUTO", SEMI = "SINGLE", BURST = "BURST", PUMP = "PUMP-ACTION", BOLT = "BOLT-ACTION" }
local ROMAN = { "I", "II", "III", "IV", "V", "VI" } -- Tarkov marks armour classes in Roman numerals (0.14)

-- Tarkov's armour material name (Plates.MATERIALS, EFT 1.0's list)
local function material(mat)
	local m = Plates.MATERIALS[mat or ""]
	return m and m.name or "ARAMID"
end

-- the zones a set covers, in Tarkov's order, as one line
local function zoneLine(set)
	local names = Plates.zoneNames(set)
	return #names > 0 and table.concat(names, ", ") or "NONE"
end

local function pct(x)
	return string.format("%d%%", math.floor((x or 0) * 100 + 0.5))
end

local function signed(x, suffix)
	return string.format("%+g%s", math.floor(x * 10 + (x >= 0 and 0.5 or -0.5)) / 10, suffix or "")
end

-- ── the attribute sheet ──────────────────────────────────────────────────────
-- rows { name, value, bar (0..1, optional), tone ("good" / "bad", optional) }; classes: penetration chances 1..6
local function sheet(items, g, it, d, opts)
	local rows, classes = {}, nil
	local function add(name, value, bar, tone)
		table.insert(rows, { name = name, value = tostring(value), bar = bar and math.clamp(bar, 0.04, 1) or nil, tone = tone })
	end
	local mass = opts.mass or d.mass or 0
	local w = d.weapon and Weapons[d.weapon]
	if (d.kind == "weapon" or d.kind == "pistol") and w then
		local f = ctx.Modding and ctx.Modding.figures(items, g)
		if f then
			mass = opts.mass or f.mass
			add("ERGONOMICS", f.ergo, f.ergo / 100)
			add("ACCURACY", string.format("%.2f MOA", f.moa), 1 - f.moa / 8)
			add("SIGHTING RANGE", f.range .. " m", f.range / 1000)
			-- Tarkov's figures since gameplay-1a: up to about 600 vertical (pistols, shotguns) and 900 horizontal
			add("VERTICAL RECOIL", f.recoilV, f.recoilV / 600)
			add("HORIZONTAL RECOIL", f.recoilH, f.recoilH / 900)
			add("MUZZLE VELOCITY", f.velocity .. " m/s", f.velocity / 1000)
			if #f.missing > 0 then
				local miss = {}
				for _, m in f.missing do
					table.insert(miss, string.upper(m.slot))
				end
				add("NOT OPERABLE", "MISSING " .. table.concat(miss, ", "), nil, "bad")
			end
		end
		local wear, wmax = it.wear or 100, it.wmax or 100
		add("DURABILITY", string.format("%.1f/%.1f", wear, wmax), wear / 100, wear < 93 and "bad" or nil)
		if it.mf then
			add("MALFUNCTION", it.mfk and string.upper(it.mf == "eject" and "failure to eject" or it.mf == "feed" and "failure to feed" or it.mf == "jam" and "jammed bolt" or "misfire") or "NOT INSPECTED", nil, "bad")
		end
		add("EFFECTIVE DISTANCE", math.floor(w.range * M_PER_STUD / 10 + 0.5) * 10 .. " m")
		local modes = {}
		for _, m in w.modes or {} do
			table.insert(modes, MODES[m] or m)
		end
		add("FIRE MODES", table.concat(modes, ", "))
		add("RATE OF FIRE", w.rpm .. " RPM")
		add("CALIBER", CALIBERS[d.caliber] or d.caliber or "-")
	elseif d.kind == "ammo" and d.ammo then
		local a = d.ammo
		add("DAMAGE", a.pellets and string.format("%d x %d", a.dmg, a.pellets) or a.dmg, a.dmg * (a.pellets or 1) / 300)
		add("PENETRATION", a.pen, a.pen / 70)
		add("ARMOR DAMAGE", pct(a.armorDmg))
		add("FRAGMENTATION CHANCE", pct(a.frag))
		add("LIGHT BLEEDING CHANCE", pct(a.bleedL))
		add("HEAVY BLEEDING CHANCE", pct(a.bleedH))
		add("CALIBER", CALIBERS[d.caliber] or d.caliber)
		-- EFT's inspector also lists the round's speed and its recoil and accuracy modifiers (economy-1a)
		if a.speed then
			add("BULLET SPEED", a.speed .. " M/S", a.speed / 1000)
		end
		if a.recoil and a.recoil ~= 0 then
			add("RECOIL", string.format("%+d%%", math.floor(a.recoil * 100 + 0.5)))
		end
		if a.acc and a.acc ~= 0 then
			add("ACCURACY", string.format("%+d%%", math.floor(a.acc * 100 + 0.5)))
		end
		if a.subsonic then
			add("SUBSONIC", "YES")
		end
		if a.tracer then
			add("TRACER", type(a.tracer) == "string" and string.upper(a.tracer) or "YES")
		end
		classes = {}
		for c = 1, 6 do
			classes[c] = Items.penChance(a.pen, c, 1)
		end
	elseif d.kind == "mag" then
		add("CAPACITY", d.capacity .. " ROUNDS")
		add("CALIBER", CALIBERS[d.caliber] or d.caliber or "-")
		local fw = d.family and Weapons[d.family]
		if fw then
			add("FITS", fw.name)
		end
	end
	-- goggles (Tarkov's night vision and thermal entries) and the mount on a helmet or strap
	if d.kind == "nvg" and d.part and d.part.nv then
		local nv = d.part.nv
		add("DEVICE", nv.thermal and "THERMAL GOGGLES" or (nv.mask == "mono" and "MONOCULAR" or nv.mask == "quad" and "PANORAMIC GOGGLES" or "BINOCULAR GOGGLES"))
		add("IMAGE", nv.thermal and "WHITE HOT" or (nv.grain > 1.8 and "GRAINY" or nv.grain < 1 and "CLEAN" or "FAIR"))
		add("LIGHT FLARE", nv.thermal and "NONE" or (nv.bloom > 1.2 and "STRONG" or nv.bloom < 0.5 and "SLIGHT" or "MODERATE"))
		add("MOUNTS ON", "HELMET MOUNT, HEAD STRAP")
		if nv.thermal then
			add("OPTICS", "IRON SIGHTS ONLY")
		end
	end
	if WP.SLOTS[it.id] and WP.SLOTS[it.id].mount and d.kind ~= "mod" then
		local mg = it.mods and it.mods.mount
		add("NIGHT VISION MOUNT", (mg and items[mg] and Items.defs[items[mg].id]) and string.upper(Items.defs[items[mg].id].short) or "EMPTY")
	end
	-- a weapon part's modifiers (magazines can be parts too)
	local p = WP.parts[it.id]
	if p and d.kind ~= "weapon" and d.kind ~= "pistol" then
		local cat = WP.CATS[p.cat]
		add("TYPE", cat and string.upper(cat.name) or string.upper(p.cat))
		if p.ergo and p.ergo ~= 0 then
			add("ERGONOMICS", signed(p.ergo), nil, p.ergo > 0 and "good" or "bad")
		end
		if p.recoil and p.recoil ~= 0 then
			add("RECOIL", signed(p.recoil, "%"), nil, p.recoil < 0 and "good" or "bad")
		end
		if p.acc and p.acc ~= 0 then
			add("ACCURACY", signed(-p.acc, "%"), nil, p.acc < 0 and "good" or "bad")
		end
		if p.vel and p.vel ~= 0 then
			add("MUZZLE VELOCITY", signed(p.vel, "%"), nil, p.vel > 0 and "good" or "bad")
		end
		if p.loud and p.loud ~= 1 then
			add("LOUDNESS", signed((p.loud - 1) * 100, "%"), nil, p.loud < 1 and "good" or "bad")
		end
		if p.zoom then
			add("MAGNIFICATION", p.zoom .. "x")
		end
		if p.range then
			add("SIGHTING RANGE", p.range .. " m")
		end
		if p.capacity then
			add("CAPACITY", p.capacity .. " SHELLS")
		end
	end
	if d.armor then
		-- the armour panel (Tarkov 0.14): the whole piece, then each built-in part and each plate slot
		local ar = d.armor
		local dur = it.dur or ar.dur
		local slots = Plates.slotsOf(d)
		local cls = Plates.classOf(defs, items, it)
		add("ARMOR CLASS", ROMAN[cls] and string.format("%s (%d)", ROMAN[cls], cls) or cls)
		local dmax = it.dmax or ar.dur
		local durName = slots and "SOFT ARMOR DURABILITY" or "DURABILITY"
		add(durName, dmax < ar.dur - 0.05 and string.format("%d/%d (MAX %d)", math.ceil(dur), math.floor(dmax), ar.dur) or string.format("%d/%d", math.ceil(dur), ar.dur), dur / ar.dur)
		add("MATERIAL", material(ar.mat))
		if d.plate then
			local p = d.plate
			add("POSITION", p.pos == "any" and "FRONT OR BACK" or p.pos == "side" and "SIDE" or string.upper(p.pos))
			-- the zones it covers and the vests it fits
			local covered, fits = {}, {}
			for _, cd in defs do
				local cs = Plates.slotsOf(cd)
				if cs then
					local any = false
					for _, s in Plates.SLOTS do
						if cs[s] and Plates.fits(cd, s, d) then
							any = true
							for z in Plates.plateZones(cd, s, d) do
								covered[z] = true
							end
						end
					end
					if any then
						table.insert(fits, cd.short or cd.name)
					end
				end
			end
			table.sort(fits)
			add("ARMORED AREAS", zoneLine(covered))
			add("FITS", #fits > 0 and table.concat(fits, ", ") or "NONE")
		else
			-- the zones of its parts, with what its plates in place add
			local set = table.clone(ar.zones or {})
			for _, s in Plates.SLOTS do
				local pg = slots and it.mods and it.mods[s]
				local p = pg and items[pg]
				if p and defs[p.id] then
					for z in Plates.plateZones(d, s, defs[p.id]) do
						set[z] = true
					end
				end
			end
			add("ARMORED AREAS", zoneLine(set))
		end
		add("BLUNT THROUGHPUT", pct(ar.blunt))
		if ar.ric then
			add("RICOCHET CHANCE", string.upper(ar.ric))
		end
		-- each built-in part (EFT: soft armour inserts, helmet parts): its zones, class and durability
		local parts = Plates.partsOf(d)
		if parts and #parts > 1 then
			for _, e in parts do
				local cur = Plates.partDur(it, d, e.k)
				local zs = {}
				for z in e.zones do
					zs[z] = true
				end
				add(e.name .. "  ·  " .. zoneLine(zs), string.format("%s  ·  %d/%d", ROMAN[e.class] or tostring(e.class), math.ceil(cur), e.dur), cur / math.max(e.dur, 1), cur <= 0 and "bad" or nil)
			end
		end
		-- each plate slot: the plate in it (class, durability) or EMPTY
		if slots then
			for _, s in Plates.SLOTS do
				if slots[s] then
					local pg = it.mods and it.mods[s]
					local p = pg and items[pg]
					local pd = p and defs[p.id]
					if pd and pd.armor then
						local pdur = p.dur or pd.armor.dur
						add(Plates.SLOT_NAMES[s], string.format("%s  ·  %s  ·  %d/%d", pd.short or pd.name, ROMAN[pd.armor.class] or tostring(pd.armor.class), math.ceil(pdur), pd.armor.dur), pdur / pd.armor.dur, pdur <= 0 and "bad" or nil)
					else
						add(Plates.SLOT_NAMES[s], "EMPTY", nil, "bad")
					end
				end
			end
		end
	end
	-- eyewear and gas masks: the share of a stun charge's white-out the lenses stop (Tarkov's blindness protection) and the tint
	if d.eye then
		add("BLINDNESS PROTECTION", pct(d.eye.flash))
		add("LENS TINT", d.eye.lens)
	end
	-- what a worn item leaves no room for (a full-cut helmet blocks the earpiece, a gas mask blocks eyewear)
	local vis = Equipment.VIS[d.id]
	if vis and vis.blocks then
		local names = {}
		for slot in vis.blocks do
			table.insert(names, Items.SLOT_NAMES[slot] or string.upper(slot))
		end
		table.sort(names)
		add("BLOCKS", table.concat(names, ", "), nil, "bad")
	end
	if d.grid then
		add("CAPACITY", string.format("%d SLOTS (%dx%d)", d.grid.w * d.grid.h, d.grid.w, d.grid.h))
	end
	-- Tarkov's gear penalties
	if d.pen then
		if d.pen.speed and d.pen.speed ~= 0 then
			add("MOVEMENT SPEED", d.pen.speed .. "%", nil, "bad")
		end
		if d.pen.turn and d.pen.turn ~= 0 then
			add("TURN SPEED", d.pen.turn .. "%", nil, "bad")
		end
		if d.pen.ergo and d.pen.ergo ~= 0 then
			add("ERGONOMICS", d.pen.ergo .. "%", nil, "bad")
		end
	end
	if d.med then
		local m = d.med
		if m.hp then
			add("HP RESOURCE", it.hp and string.format("%d/%d", math.ceil(it.hp), m.hp) or m.hp, (it.hp or m.hp) / m.hp)
		end
		if m.uses and m.uses > 1 then
			add("USES", string.format("%d/%d", it.uses or m.uses, m.uses))
		end
		local cures = {}
		for _, e in { { "light", "LIGHT BLEEDING" }, { "heavy", "HEAVY BLEEDING" }, { "fracture", "FRACTURES" }, { "surgery", "DESTROYED PARTS" } } do
			if m[e[1]] then
				table.insert(cures, e[2])
			end
		end
		if m.pain then
			table.insert(cures, string.format("PAIN (%d s)", m.duration or 0))
		end
		-- a stimulant (gameplay-4b): what it stops, then each buff and side effect with its timing (EFT's list)
		local sd = m.stim and Stims.DEFS[m.stim]
		if sd and sd.stopBleeds then
			table.insert(cures, "LIGHT BLEEDING")
			table.insert(cures, "HEAVY BLEEDING")
		end
		if sd and sd.pain then
			table.insert(cures, string.format("PAIN (%d S)", sd.pain))
		end
		if #cures > 0 then
			add("TREATS", table.concat(cures, ", "), nil, "good")
		end
		for _, f in sd and sd.fx or {} do
			for _, ln in Stims.lines(f) do
				add(ln[1], ln[2], nil, ln[3])
			end
		end
		if m.limbsOnly then
			add("USE ON", "ARMS AND LEGS")
		end
		add("USE TIME", m.time .. " s")
	end
	if d.food then
		local f = d.food
		if f.energy then
			add("ENERGY", signed(f.energy), nil, f.energy >= 0 and "good" or "bad")
		end
		if f.water then
			add("HYDRATION", signed(f.water), nil, f.water >= 0 and "good" or "bad")
		end
		if f.stamina then
			add("STAMINA", signed(f.stamina), nil, f.stamina >= 0 and "good" or "bad")
		end
		add("USE TIME", f.time .. " s")
	end
	if d.nade then
		local n = d.nade
		add("TYPE", string.upper(n.type or "frag"))
		if n.fuse then
			add("FUSE TIME", n.fuse .. " s")
		end
		if n.blastR then
			add("EXPLOSION RADIUS", string.format("%.1f m", n.blastR * M_PER_STUD))
		end
		if n.frags then
			add("FRAGMENTS", n.frags)
		end
		if n.fragDmg then
			add("FRAGMENT DAMAGE", string.format("%d-%d", n.fragDmg[1], n.fragDmg[2]))
		end
	end
	if d.key then
		add("USES LEFT", string.format("%d/%d", it.uses or d.key.uses, d.key.uses), (it.uses or d.key.uses) / d.key.uses)
	end
	if d.repair then
		add("REPAIR POINTS", d.repair.points)
	end
	table.insert(rows, 1, { name = "WEIGHT", value = string.format("%.2f kg", mass) })
	local sw, sh = d.w, d.h
	if it.sz then
		sw, sh = it.sz[1], it.sz[2]
	end
	table.insert(rows, 2, { name = "SIZE", value = string.format("%dx%d", sw, sh) })
	return rows, classes
end

-- ── the 3D view ──────────────────────────────────────────────────────────────
local function buildModel(view, items, g, it, d)
	local model = Instance.new("Model")
	model.Name = "Item"
	local lo, hi
	local pieces = ItemModel.gunPieces(items, g, CFrame.new())
	if pieces and #pieces > 0 then
		for _, p in pieces do
			ItemModel.quiet(p)
			p.Parent = model
		end
		lo, hi = ItemModel.bounds(pieces)
	else
		local size, centre = ItemModel.placeMeta(model, it.id, CFrame.new(), true)
		if not size then
			size, centre = ItemModel.placeWear(model, d, CFrame.new())
		end
		if not size then
			model:Destroy()
			return nil
		end
		lo, hi = centre.Position - size / 2, centre.Position + size / 2
	end
	model.WorldPivot = CFrame.new((lo + hi) / 2)
	model.Parent = view
	local size = hi - lo
	local dims = { size.X, size.Y, size.Z }
	table.sort(dims, function(a, b)
		return a > b
	end)
	return model, dims, pieces ~= nil and #pieces > 0
end

-- ── windows ──────────────────────────────────────────────────────────────────
local function closeWin(win)
	for _, cn in win.conns do
		cn:Disconnect()
	end
	local hadFocus = GuiService.SelectedObject ~= nil and GuiService.SelectedObject:IsDescendantOf(win.frame)
	win.frame:Destroy()
	local i = table.find(windows, win)
	if i then
		table.remove(windows, i)
	end
	-- the gamepad selection goes back where it was before the window opened (Roblox leaves none behind)
	if hadFocus and win.prevSel and ctx then
		ctx.Input.padFocus(win.prevSel)
	end
end

local function raise(win)
	zTop += 1
	win.frame.ZIndex = zTop
end

-- the window in front (the last one raised)
local function topWindow()
	local best = nil
	for _, win in windows do
		if not best or win.frame.ZIndex > best.frame.ZIndex then
			best = win
		end
	end
	return best
end

function Inspect.closeAll()
	for i = #windows, 1, -1 do
		closeWin(windows[i])
	end
end

-- B / Backspace: close the window in front; false when none is open (audit ui.5)
function Inspect.closeTop()
	local win = topWindow()
	if win then
		closeWin(win)
		return true
	end
	return false
end

function Inspect.isOpen()
	return #windows > 0
end

-- items: the item table holding g; opts: key (one window per key), mass (total kg), unknown (not examined)
function Inspect.open(items, g, opts)
	opts = opts or {}
	local it = items and items[g]
	local d = it and defs[it.id]
	if not d then
		return
	end
	local key = opts.key or tostring(g)
	for _, win in windows do
		if win.key == key then
			raise(win)
			return
		end
	end
	if #windows >= MAX_OPEN then
		closeWin(windows[1])
	end
	local unknown = opts.unknown
	local rows, classes = {}, nil
	if not unknown then
		rows, classes = sheet(items, g, it, d, opts)
	end
	local vp = K.viewport(gui)
	local W = math.floor(math.min(620, vp.X - 16))
	local cols = W >= 480 and 2 or 1
	local topH = math.floor(math.clamp(W * 0.36, 110, 210))
	local sheetH = math.ceil(#rows / cols) * ROW + (classes and 52 or 0)
	local H = math.floor(math.min(36 + topH + 8 + sheetH + 10, vp.Y - 16))
	local n = #windows
	zTop += 1
	local frame = K.frame(K.root(gui), {
		Name = "Inspect", Active = true, ZIndex = zTop, BackgroundColor3 = K.C.bg,
		Position = UDim2.fromOffset(math.floor((vp.X - W) / 2) + n * 26, math.floor((vp.Y - H) / 2) + n * 26), Size = UDim2.fromOffset(W, H),
	})
	K.stroke(frame, K.C.ochre, 0.45)
	local win = { frame = frame, key = key, conns = {}, prevSel = GuiService.SelectedObject }
	table.insert(windows, win)
	-- title bar: the full name, found-in-raid / insured marks, close
	local bar = K.frame(frame, { Name = "Title", Active = true, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = K.C.panel2 })
	K.label(bar, unknown and "UNKNOWN ITEM" or string.upper(d.name), 14, { FontFace = K.bold, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -236, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	local marks = {}
	if it.fir then
		table.insert(marks, "FOUND IN RAID")
	end
	if it.ins then
		table.insert(marks, "INSURED")
	end
	K.label(bar, table.concat(marks, "  ·  "), 10, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 0), Size = UDim2.fromOffset(110, 28), TextColor3 = K.C.green, TextXAlignment = Enum.TextXAlignment.Right })
	local x = K.button(bar, "X", { Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(26, 22), TextSize = 12 })
	-- Tarkov's wish list toggle (handbook WISH LIST, a mark on the item in the stash)
	if not unknown and ctx.Settings and ctx.Settings.setWish then
		local wished = (ctx.Settings.data.wish or {})[it.id] == true
		local wb = K.button(bar, wished and "WISHED" or "+ WISH", { Name = "Wish", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(74, 22), TextSize = 10, TextColor3 = wished and K.C.ochre or K.C.dim })
		wb.Activated:Connect(function()
			wished = not wished
			ctx.Settings.setWish(it.id, wished)
			wb.Text = wished and "WISHED" or "+ WISH"
			wb.TextColor3 = wished and K.C.ochre or K.C.dim
			if ctx.Inventory.open then
				ctx.Inventory.render()
			end
		end)
	end
	x.Activated:Connect(function()
		closeWin(win)
	end)
	-- the model, turnable; the 2D picture when its meshes are not loaded (or the item is unknown)
	local viewW = math.floor(W * (cols == 2 and 0.5 or 0.46))
	local view = K.new("ViewportFrame", {
		Name = "Model", Active = true, BackgroundColor3 = Color3.fromRGB(22, 23, 21), Position = UDim2.fromOffset(8, 36), Size = UDim2.fromOffset(viewW, topH),
		Ambient = Color3.fromRGB(150, 148, 140), LightColor = Color3.fromRGB(255, 248, 235), LightDirection = Vector3.new(-0.5, -1, -0.6),
	}, frame)
	K.stroke(view, K.C.line, 0.6)
	local model, dims, isGun
	if not unknown then
		model, dims, isGun = buildModel(view, items, g, it, d)
	end
	if model then
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.Parent = view
		view.CurrentCamera = cam
		local yaw, pitch, zoom = isGun and -90 or 35, isGun and 0 or -25, 1
		-- fit the longest side across the view and the middle one up it (a gun's length, a box's height)
		local tanV = math.tan(math.rad(15))
		local aspect = viewW / topH
		local fit = math.max(dims[1] / 2 / (tanV * aspect), dims[2] / 2 / tanV) * 1.15 + dims[3] / 2
		local function apply()
			model:PivotTo(CFrame.Angles(math.rad(pitch), 0, 0) * CFrame.Angles(0, math.rad(yaw), 0))
			cam.CFrame = CFrame.new(Vector3.new(0, 0, math.max(fit, 0.3) * zoom), Vector3.zero)
		end
		apply()
		-- the right stick (the loop in Inspect.init) turns the model of the window in front: degrees left-right, up-down
		win.turn = function(dYaw, dPitch)
			yaw += dYaw
			pitch = math.clamp(pitch + dPitch, -85, 85)
			apply()
		end
		local turning, last = false, nil
		view.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				turning, last = true, input.Position
				raise(win)
			end
		end)
		view.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				zoom = math.clamp(zoom - input.Position.Z * 0.1, 0.45, 1.6)
				apply()
			end
		end)
		table.insert(win.conns, UIS.InputChanged:Connect(function(input)
			if turning and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local dlt = input.Position - last
				last = input.Position
				yaw += dlt.X * 0.6
				pitch = math.clamp(pitch + dlt.Y * 0.6, -85, 85)
				apply()
			end
		end))
		table.insert(win.conns, UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				turning = false
			end
		end))
	else
		local sw, sh = d.w, d.h
		local pw = math.floor(math.min(viewW - 16, (topH - 16) * sw / sh))
		local ph = math.floor(pw * sh / sw)
		local holder = K.frame(view, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(pw, ph) })
		if K.isBuild(items, g) then
			K.gunPicture(holder, items, g, pw, ph, false, 2)
		else
			K.itemIcon(holder, it.id, pw, ph, false, unknown, 2)
		end
	end
	-- description (and a dog tag's owner)
	local text = unknown and "Examine this item to identify it." or (d.desc or "")
	if not unknown and it.tag then
		text ..= string.format("\n\nOPERATOR %s  ·  LEVEL %d%s", string.upper(tostring(it.tag.name)), it.tag.lvl or 1, it.tag.by and ("  ·  KILLED BY " .. string.upper(tostring(it.tag.by))) or "")
	end
	K.label(frame, text, 12, {
		Name = "Description", Position = UDim2.fromOffset(viewW + 18, 36), Size = UDim2.fromOffset(W - viewW - 26, topH), TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = K.C.dim, ClipsDescendants = true,
	})
	-- the sheet
	local sy = 36 + topH + 8
	local sf = K.new("ScrollingFrame", {
		Name = "Sheet", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, sy), Size = UDim2.fromOffset(W - 16, H - sy - 8),
		CanvasSize = UDim2.fromOffset(0, sheetH), ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y, Selectable = false,
	}, frame)
	local cw = math.floor((W - 16 - (cols - 1) * 8) / cols)
	for i, r in rows do
		local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
		local rf = K.frame(sf, { Name = "Row_" .. r.name, BackgroundColor3 = K.C.panel, BackgroundTransparency = 0.25, Position = UDim2.fromOffset(col * (cw + 8), line * ROW), Size = UDim2.fromOffset(cw, ROW - 3) })
		K.label(rf, r.name, 11, { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0.55, -6, 1, -3), TextColor3 = K.C.dim, TextTruncate = Enum.TextTruncate.AtEnd })
		K.label(rf, r.value, 13, {
			Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0.45, 0, 1, -3), TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd, FontFace = K.bold,
			TextColor3 = r.tone == "good" and K.C.green or r.tone == "bad" and K.C.red or K.C.text,
		})
		if r.bar then
			local track = K.frame(rf, { BackgroundColor3 = K.C.panel2, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -2), Size = UDim2.new(1, -12, 0, 3) })
			K.frame(track, { BackgroundColor3 = K.C.text, BackgroundTransparency = 0.25, Size = UDim2.fromScale(r.bar, 1) })
		end
	end
	if classes then
		-- the chance to go through fresh armor of each class (Tarkov shows it on hover since 0.14.5)
		local y = math.ceil(#rows / cols) * ROW + 2
		K.label(sf, "CHANCE TO PENETRATE NEW ARMOR, BY CLASS", 11, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 16), TextColor3 = K.C.dim })
		local bw = math.floor((W - 16 - 5 * 4) / 6)
		for c = 1, 6 do
			local ch = classes[c]
			local tone = ch >= 0.75 and K.C.green or ch >= 0.35 and K.C.ochre or ch >= 0.1 and K.C.orange or K.C.red
			local cell = K.frame(sf, { Name = "Class" .. c, BackgroundColor3 = K.C.panel, Position = UDim2.fromOffset((c - 1) * (bw + 4), y + 18), Size = UDim2.fromOffset(bw, 28) })
			K.stroke(cell, tone, 0.3)
			K.label(cell, string.format("CLASS %d  %s", c, pct(ch)), 12, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = tone, FontFace = K.bold })
		end
	end
	-- drag the window by its title bar; any click raises it
	local moving, mlast = false, nil
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			moving, mlast = true, input.Position
			raise(win)
		end
	end)
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			raise(win)
		end
	end)
	table.insert(win.conns, UIS.InputChanged:Connect(function(input)
		if moving and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dlt = input.Position - mlast
			mlast = input.Position
			local d = K.toLocalLen(dlt) -- screen pixels in the root's units (MENU TEXT SIZE)
			frame.Position += UDim2.fromOffset(d.X, d.Y)
		end
	end))
	table.insert(win.conns, UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			moving = false
		end
	end))
	ctx.Input.padFocus(x) -- a gamepad only (audit ui.5)
	return frame
end

function Inspect.init(c)
	ctx = c
	K = c.UiKit
	gui = K.screen("ZR_Inspect", 40)
	-- the right stick turns the model in the window in front (audit ui.5): the camera leaves the stick alone while a
	-- screen is open (Camera.luau), the left stick and the D-pad keep moving the selection. Same dead zone and curve as
	-- the camera; up to 180 degrees a second across, 120 up and down
	local stick = Vector2.zero
	UIS.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.zero
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if #windows == 0 or stick.Magnitude <= 0.14 then
			return
		end
		local win = topWindow()
		if win and win.turn then
			local s = (math.min(stick.Magnitude, 1) - 0.14) / 0.86
			local v = stick.Unit * s * s
			win.turn(v.X * dt * 180, -v.Y * dt * 120)
		end
	end)
end

return Inspect

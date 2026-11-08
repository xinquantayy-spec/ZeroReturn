--!nonstrict
-- Pure-logic regression tests (grid, inventory 2.0, settlement, loot, de-dupe, locks). Run via ZR_Dev "tests".
local Services = script.Parent.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Grid = require(Shared.Grid)
local Items = require(Shared.Items)
local Config = require(Shared.Config)
local Inv = require(Services.Inv)
local Settle = require(Services.Settle)
local Loot = require(Services.Loot)

local T = {}

local function findId(h, id, where)
	for g, it in h.items do
		if it.id == id and (not where or Inv.locate(h, g) == where) then
			return g
		end
	end
	return nil
end

local function biggest(h, id)
	local best, n = nil, -1
	for g, it in h.items do
		if it.id == id and it.n > n then
			best, n = g, it.n
		end
	end
	return best
end

local function countId(h, id)
	local n = 0
	for _, it in h.items do
		if it.id == id then
			n += it.n
		end
	end
	return n
end

function T.run(ctx)
	local passed, failed, notes = 0, 0, {}
	local skipped = 0
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end
	-- a lean server (tech-4b) builds only some maps: a check about one map runs only where that map was built
	local plan = ctx and ctx.World and ctx.World.planMaps and ctx.World.planMaps()
	local function checkOn(maps, name, cond)
		for id in string.gmatch(maps, "[%w_]+") do
			if plan ~= nil and not plan[id] then
				skipped += 1
				return
			end
		end
		check(name, cond)
	end
	local function inv(h)
		local ok, msg = Inv.check(h)
		if not ok then
			table.insert(notes, "invariant: " .. tostring(msg))
		end
		return ok
	end

	-- grid geometry
	local sz = function()
		return 2, 1
	end
	check("grid fits empty", Grid.fits(4, 4, {}, sz, 1, 1, 2, 1))
	check("grid out of bounds", not Grid.fits(4, 4, {}, sz, 4, 1, 2, 1))
	check("grid overlap", not Grid.fits(4, 4, { a = { x = 1, y = 1, r = 0 } }, sz, 2, 1, 2, 1))
	check("grid rotated fits", Grid.fits(4, 4, { a = { x = 1, y = 1, r = 0 } }, sz, 3, 1, 1, 2))
	local fx, fy, fr = Grid.findFree(4, 1, {}, function()
		return 1, 2
	end, 1, 2)
	check("findFree rotates 1x2 into 4x1", fx == 1 and fy == 1 and fr == 1)

	-- starter profile
	local p = Settle.newProfile()
	check("new profile invariant", inv(p))
	local pw = p.items[p.slots.primary]
	local pm = pw and p.items[pw.mag]
	check("starter rifle loaded", pm ~= nil and pm.a == 25 and pm.at == "A62_FMJ")
	check("starter pistol loaded", p.slots.holster ~= nil and p.items[p.slots.holster].mag ~= nil)
	check("starter worn kit", p.slots.secure and p.slots.back and p.slots.rig and p.slots.armor and p.slots.melee and true)
	local rigMags = 0
	for g in p.grids[p.slots.rig] do
		if Items.defs[p.items[g].id].kind == "mag" then
			rigMags += 1
		end
	end
	check("rig holds 3 mags", rigMags == 3)
	local pocketsOk = true
	for g in p.grids.pockets do
		local d = Items.defs[p.items[g].id]
		pocketsOk = pocketsOk and d.w * d.h == 1
	end
	check("pockets hold 1x1 only", pocketsOk)

	-- moves and rules
	local rigMag = findId(p, "R17_MAG", "grid")
	check("move mag to stash corner", (Inv.move(p, rigMag, { c = "stash", x = 10, y = 19, r = 0 })) and inv(p))
	check("out of bounds rejected", not Inv.move(p, rigMag, { c = "stash", x = 10, y = 20, r = 0 }))
	local back = p.slots.back
	check("bag into itself rejected", not Inv.move(p, back, { c = back, x = 1, y = 1, r = 0 }))
	check("full bag into rig rejected", select(2, Inv.move(p, back, { c = p.slots.rig, x = 1, y = 1, r = 0 })) ~= nil)
	local water = findId(p, "WATER")
	local _, eTooBig = Inv.move(p, water, { c = "pockets", x = 4, y = 1, r = 0 })
	check("1x2 into pockets rejected", eTooBig == "TOO_BIG")
	local _, eSec = Inv.move(p, p.slots.primary, { c = p.slots.secure, x = 1, y = 1, r = 0 })
	check("rifle into secure rejected", eSec == "SECURE_RESTRICTED")
	local stashAmmo = findId(p, "A9_PST")
	check("ammo into secure allowed", (Inv.move(p, stashAmmo, { c = p.slots.secure, x = 1, y = 1, r = 0 })))
	local helmet = findId(p, "HELMET_C2")
	check("equip helmet", (Inv.move(p, helmet, { slot = "head" })) and p.slots.head == helmet)
	local _, eW = Inv.move(p, helmet, { slot = "holster" })
	check("helmet into holster rejected", eW ~= nil)
	local prg, pri = Inv.newItem("RIG_PLATE")
	Inv.place(p, prg, pri, { "stash" })
	local oldRig = p.slots.rig
	Inv.detach(p, oldRig)
	Inv.autoPlace(p, oldRig, { "stash" })
	local _, eConf = Inv.move(p, prg, { slot = "rig" })
	check("plate rig blocked by body armor", eConf == "ARMOR_CONFLICT")
	check("invariant after rule checks", inv(p))
	check("secure locked in raid", select(2, Inv.move(p, p.slots.secure, { c = "stash", x = 1, y = 1, r = 0 }, { inRaid = true })) == "SECURE_LOCKED")

	-- stacks
	local h = Inv.newHolder("profile")
	local g1, a1 = Inv.newItem("A62_FMJ", 50)
	local g2, a2 = Inv.newItem("A62_FMJ", 30)
	Inv.place(h, g1, a1, { "stash" })
	Inv.place(h, g2, a2, { "stash" })
	check("stack merge keeps count", countId(h, "A62_FMJ") == 80 and inv(h))
	local sg = findId(h, "A62_FMJ")
	check("split stack", (Inv.split(h, sg, 10, { c = "stash", x = 5, y = 5, r = 0 })) and countId(h, "A62_FMJ") == 80 and inv(h))

	-- Tarkov stash SORT: by kind, larger first, nothing overlaps, nothing lost
	do
		local sh = Inv.newHolder("profile")
		for _, e in { { "BANDAGE", 1 }, { "R17_RIFLE", 1 }, { "A62_FMJ", 40 }, { "ARMOR_C2", 1 }, { "WATER", 1 }, { "R17_MAG", 1 } } do
			local ng, ni = Inv.newItem(e[1], e[2])
			Inv.place(sh, ng, ni, { "stash" })
		end
		local before = 0
		for _ in sh.grids.stash do
			before += 1
		end
		local okSort = Inv.sortStash(sh)
		local after, first = 0, nil
		for gg, pp in sh.grids.stash do
			after += 1
			if pp.x == 1 and pp.y == 1 then
				first = sh.items[gg].id
			end
		end
		check("stash sort keeps every item, no overlaps", okSort and before == after and before == 6 and inv(sh))
		check("stash sort puts weapons first", first == "R17_RIFLE")
	end
	-- Tarkov's default PC keys: no two actions on the same key and modifier; chords only on Alt, Shift or Ctrl
	do
		local IM = require(Shared.InputMap)
		local seen, dup, badMod = {}, nil, false
		for action, spec in IM do
			if spec.mod ~= nil and spec.mod ~= "Alt" and spec.mod ~= "Shift" and spec.mod ~= "Ctrl" then
				badMod = true
			end
			for _, k in spec.keys do
				local id = k.Name .. "+" .. tostring(spec.mod) .. (spec.context == "mount" and "+mount" or "") -- the mount context reuses play keys
				if seen[id] then
					dup = action .. "/" .. seen[id]
				end
				seen[id] = action
			end
		end
		check("input map: one action per key and modifier" .. (dup and (" (" .. dup .. ")") or ""), dup == nil and not badMod)
		check("input map: Tarkov keys (X prone, B fire mode, Alt+T magazine, Shift+T chamber, V melee, 4 quick slot)",
			IM.Prone.keys[1] == Enum.KeyCode.X and IM.FireMode.keys[1] == Enum.KeyCode.B and IM.MagCheck.mod == "Alt"
			and IM.ChamberCheck.mod == "Shift" and IM.Knife.keys[1] == Enum.KeyCode.V and IM.Quick4.keys[1] == Enum.KeyCode.Four)
		check("input map: T is the tactical device and Ctrl+T its mode (Tarkov)", IM.Light.keys[1] == Enum.KeyCode.T and IM.Light.mod == nil
			and IM.DeviceMode.keys[1] == Enum.KeyCode.T and IM.DeviceMode.mod == "Ctrl")
		-- the gamepad has fewer buttons than Tarkov has keys (KNOWN_ISSUES 76): a button may carry several actions told
		-- apart by a tap or a hold (padHow) and by aiming or not (padAim); only these eight buttons are shared, and no two
		-- of their actions may fire from the same press (a press and a hold may: B crouches, then lies down). View: a tap
		-- opens the settings, a hold the menu bar out of a raid (ui-6a)
		local SHARED = {
			DPadUp = "FreeLook+Heal+ZeroUp", DPadDown = "Extracts+Grenade+ZeroDown", DPadRight = "DeviceMode+FireMode+Light",
			DPadLeft = "CycleWeapon+SightMode+ToggleNVG", ButtonR3 = "ChamberCheck+FireModeCheck+MagCheck",
			ButtonB = "Crouch+Prone", ButtonY = "InspectWeapon+Inventory", ButtonSelect = "MenuBar+Settings",
		}
		local byPad = {}
		for action, spec in IM do
			if spec.context ~= "mount" and spec.context ~= "menu" then
				for _, k in spec.pad or {} do
					byPad[k.Name] = byPad[k.Name] or {}
					table.insert(byPad[k.Name], action)
				end
			end
		end
		local function clash(a, b)
			local sa, sb = IM[a], IM[b]
			local aimApart = sa.padAim ~= nil and sb.padAim ~= nil and sa.padAim ~= sb.padAim
			if aimApart then
				return false
			end
			local ha, hb = sa.padHow or "press", sb.padHow or "press"
			if (ha == "press" and hb == "hold") or (ha == "hold" and hb == "press") then
				return false
			end
			return ha == hb or ha == "press" or hb == "press"
		end
		local badPad = nil
		for key, list in byPad do
			table.sort(list)
			if #list > 1 and SHARED[key] ~= table.concat(list, "+") then
				badPad = key .. ": " .. table.concat(list, "+")
			end
			for i = 1, #list do
				for j = i + 1, #list do
					if clash(list[i], list[j]) then
						badPad = badPad or (key .. ": " .. list[i] .. " and " .. list[j] .. " fire from the same press")
					end
				end
			end
		end
		for key in SHARED do
			if not byPad[key] or #byPad[key] < 2 then
				badPad = badPad or (key .. " is not shared")
			end
		end
		local noPad = {}
		for action, spec in IM do
			if #(spec.pad or {}) == 0 and not ({ Sidearm = true, Primary = true, Secondary = true, Knife = true })[action]
				and not string.match(action, "^Quick") and not string.match(action, "^Screen") then
				table.insert(noPad, action)
			end
		end
		table.sort(noPad)
		check("input map: every control but the slot keys, quick slots and screen keys has a gamepad way (D-left cycles the weapons, D-up heals, the menu bar opens the screens)"
			.. (#noPad > 0 and (" (missing: " .. table.concat(noPad, ", ") .. ")") or ""), #noPad == 0)
		check("input map: the shared gamepad buttons are the eight planned ones, each press telling its actions apart (tap, hold, aiming)" .. (badPad and (" (" .. badPad .. ")") or ""), badPad == nil)
	end
	-- touch controls (Touch.luau; TouchLayout.luau): every control's icon and action exist, the defaults do not overlap on
	-- common phone and tablet screens, and the server keeps only a clean layout
	do
		local TLm = require(Shared.TouchLayout)
		local IMt = require(Shared.InputMap)
		local seenId, badEl = {}, nil
		for _, e in TLm.ELEMENTS do
			if seenId[e.id] then
				badEl = "duplicate " .. e.id
			end
			seenId[e.id] = true
			if e.icon and TLm.ICON[e.icon] == nil then
				badEl = badEl or ("no icon " .. e.icon)
			end
			for _, a in { e.press, e.tap, e.hold } do
				if a and not IMt[a] then
					badEl = badEl or ("no action " .. a)
				end
			end
			if e.x >= 0 and (e.x > 1 or e.y < 0 or e.y > 1) then
				badEl = badEl or ("off screen " .. e.id)
			end
		end
		for _, t in TLm.TRAY do
			if not IMt[t.action] or TLm.ICON[t.icon] == nil then
				badEl = badEl or ("tray " .. t.action)
			end
		end
		check("touch: every control has its icon and an action the input map knows; ids are unique" .. (badEl and (" (" .. badEl .. ")") or ""), badEl == nil)
		local overlap = nil
		for _, scr in { { 844, 390 }, { 667, 375 }, { 932, 430 }, { 1024, 768 } } do
			local W, H = scr[1], scr[2]
			local u = math.clamp(H / 390, 1, 1.35)
			local list = {}
			for _, e in TLm.ELEMENTS do
				if e.shown and not e.mount and e.x >= 0 then
					table.insert(list, e)
				end
			end
			for i = 1, #list do
				local a = list[i]
				local ra = a.size * u / 2
				if a.x * W - ra < 0 or a.x * W + ra > W or a.y * H - ra < 0 or a.y * H + ra > H then
					overlap = overlap or string.format("%s off a %dx%d screen", a.id, W, H)
				end
				for j = i + 1, #list do
					local b = list[j]
					local d = math.sqrt(((a.x - b.x) * W) ^ 2 + ((a.y - b.y) * H) ^ 2)
					if d < ra + b.size * u / 2 then
						overlap = overlap or string.format("%s and %s on %dx%d", a.id, b.id, W, H)
					end
				end
			end
		end
		check("touch: the default controls neither overlap nor leave the screen on 844x390, 667x375, 932x430 and 1024x768" .. (overlap and (" (" .. overlap .. ")") or ""), overlap == nil)
		local clean = TLm.sanitize({
			fire = { x = 0.5, y = 2, s = 9, o = 0, h = true }, nope = { x = 0.1 }, aim = { x = 0 / 0, y = math.huge, s = "big" },
			reload = "x", jump = { h = "yes" },
		})
		-- through the settings request (the real one, for the playtest's player): a full layout of every control passes the
		-- payload check, comes back cleaned, and junk is refused; the player's own layout is put back after
		local pl = game:GetService("Players"):GetPlayers()[1]
		local profT = pl and ctx.Profiles.get(pl)
		if profT and profT.settings then
			local before = profT.settings.touchLayout
			local full = {}
			for _, e in TLm.ELEMENTS do
				full[e.id] = { x = 0.5, y = 0.5, s = 1.2, o = 0.8, h = false }
			end
			full.fire.s = 9
			local r1 = ctx.Remotes.dispatch(pl, "settings", { touchLayout = full })
			local savedT = profT.settings.touchLayout
			local okFull = r1 and r1.ok and savedT ~= nil and savedT.fire ~= nil and savedT.fire.s == 1.6 and savedT.jump ~= nil
			task.wait(0.6) -- the request's rate limit
			local r2 = ctx.Remotes.dispatch(pl, "settings", { touchLayout = "junk" })
			profT.settings.touchLayout = before
			check("touch: the settings request takes a layout of all " .. #TLm.ELEMENTS .. " controls, keeps it cleaned, and refuses one that is not a table",
				okFull and r2 ~= nil and not r2.ok)
			-- pinned tasks (audit ui.14, Tarkov 0.16.7): a known task pins and unpins; an unknown id or a bad shape is refused
			local QD = require(Shared.QuestData)
			local qid = QD.list and QD.list[1] and QD.list[1].id
			if not qid then
				for id in QD.byId do
					qid = id
					break
				end
			end
			local pinsBefore = profT.settings.pins
			task.wait(0.6)
			local p1 = ctx.Remotes.dispatch(pl, "settings", { pin = { id = qid, on = true } })
			local pinned = profT.settings.pins ~= nil and profT.settings.pins[qid] == true
			task.wait(0.6)
			local p2 = ctx.Remotes.dispatch(pl, "settings", { pin = { id = qid, on = false } })
			local unpinned = profT.settings.pins ~= nil and profT.settings.pins[qid] == nil
			task.wait(0.6)
			local p3 = ctx.Remotes.dispatch(pl, "settings", { pin = { id = "NOT_A_TASK", on = true } })
			task.wait(0.6)
			local p4 = ctx.Remotes.dispatch(pl, "settings", { pin = qid })
			profT.settings.pins = pinsBefore
			check("tasks: a pin is kept in the settings and taken off again; an unknown task or a bad shape is refused",
				qid ~= nil and p1 and p1.ok and pinned and p2 and p2.ok and unpinned and p3 and not p3.ok and p4 and not p4.ok)
		end
		check("touch: a layout keeps only known controls, numbers clamped (position 0-1, size 60-160 %, opacity 25-100 %), NaN and junk dropped",
			clean ~= nil and clean.fire.y == 1 and clean.fire.s == 1.6 and clean.fire.o == 0.25 and clean.fire.h == true and clean.nope == nil
				and clean.aim == nil and clean.reload == nil and clean.jump == nil and TLm.sanitize({}) == nil and TLm.sanitize("x") == nil)
	end
	-- M11 part B, Tarkov's rules since audit gameplay.11: from 93 % condition only heat causes malfunctions (even with a
	-- drum); below it they rise with wear, and drums and heat (0-200, from 100) add their own chances. GameplayTests has the rest
	do
		local C = ctx.Combat
		local m95 = C.malfChance(95, Items.defs.R17_MAG60, 0)
		local m50 = C.malfChance(50, nil, 0)
		local m20 = C.malfChance(20, nil, 0)
		local f50 = C.malfChance(50, Items.defs.R17_MAG60, 0)
		local m50hot = C.malfChance(50, nil, 150)
		check("malfunctions (Tarkov): none from 93% even with a drum, rising with wear, drums and heat add below it",
			m95 == 0 and m50 > 0 and m20 > m50 and f50 > m50 and m50hot > m50)
		local TDm = require(Shared.TraderData)
		local pts, cost, newMax = TDm.repairQuote("vos", { id = "R17_RIFLE", wear = 60 })
		check("trader repair: 40 points, a cost, the maximum drops", pts == 40 and cost and cost > 0 and newMax and newMax < 100 and newMax > 90)
		check("trader repair: VOS does not repair armour, ROOK does (EFT: Prapor weapons, Skier armour)",
			TDm.repairQuote("vos", { id = "ARMOR_C4", dur = 10 }) == nil and TDm.repairQuote("rook", { id = "ARMOR_C4", dur = 10 }) ~= nil)
		local gp = Items.gearPenalties({ slots = { armor = "a", head = "h" }, items = { a = { id = "ARMOR_C4" }, h = { id = "HELMET_C3" } } })
		-- (the PC-4 copies the 6B23-2 empty, -1/-1/-2.5; the class 3 helmet the LShZ, 0/-1/-1; no plates in the test vest)
		check("gear penalties add up (movement, turn, ergonomics)", gp.speed == -1 and gp.turn == -2 and gp.ergo == -3.5)
	end
	-- Tarkov's messenger keeps the last 40 messages, newest last
	do
		local fake = {}
		for i = 1, 45 do
			ctx.Economy.mail(fake, "vos", "message " .. i)
		end
		check("messenger keeps the last 40 messages", #fake.msgs == 40 and fake.msgs[40].x == "message 45" and fake.msgs[1].x == "message 6")
	end
	-- the flea market (Tarkov's rules): fee formula, offer slots by rating, banned kinds, offers sell or come back
	do
		local FR = require(Shared.FleaRules)
		local even, over, under = FR.fee(10000, 1, 10000), FR.fee(10000, 1, 20000), FR.fee(10000, 1, 5000)
		check("flea fee (EFT 1.1.0: 5 %): 10 % at the base value, steeper when overpriced", even == 1000 and over == 1791 and under == 896)
		check("flea offer slots by rating", FR.slots(0.19) == 1 and FR.slots(0.2) == 2 and FR.slots(7) == 3 and FR.slots(150) == 8 and FR.slots(1000) == 10)
		check("flea bans secure containers", not FR.tradeable("SECURE_S") and FR.tradeable("R17_RIFLE"))
		local o1, o2 = FR.offersFor("R17_RIFLE", 77), FR.offersFor("R17_RIFLE", 77)
		local same, sorted = #o1 > 0 and #o1 == #o2, true
		for i, o in o1 do
			same = same and o.price == o2[i].price and o.stock == o2[i].stock
			sorted = sorted and (i == 1 or o.price >= o1[i - 1].price)
		end
		check("flea operator offers are the same on every server and cheapest first", same and sorted)
		-- since decision economy-3a offers live in the sellers' escrow books (FleaTests: sales, expiry, the mailbox, races);
		-- an offer kept in the profile from before is given back when there is no player to move it to the shared market
		local fp = Inv.newHolder("profile")
		fp.money, fp.known, fp.msgs = 0, {}, {}
		local sg, si = Inv.newItem("R17_RIFLE", 1, { fir = true })
		Inv.place(fp, sg, si, { "stash" })
		fp.flea = { rating = 0.2, offers = { old = { id = "R17_RIFLE", n = 1, price = 9000, t = os.time() - 3600, b = Inv.take(fp, sg) } } }
		ctx.Flea.resolve(nil, fp, os.time())
		check("flea: an offer from before the shared market (economy-3a) comes back to the stash, still found in raid",
			next(fp.flea.offers) == nil and fp.items[sg] ~= nil and fp.items[sg].fir == true and Inv.locate(fp, sg) == "grid" and fp.money == 0)
	end
	-- goggles (Tarkov): a gear component that goes on a helmet's or strap's mount, not on every helmet
	do
		local WPm = require(Shared.WeaponParts)
		check("goggles are gear (kind nvg) with a tube record", Items.defs.NV_BINO.kind == "nvg" and Items.defs.TH_T7.part.nv.thermal == true)
		check("goggles fit mounted helmets and the strap, not the shell helmet", WPm.fits("HELMET_C3", "mount", "NV_BINO") and WPm.fits("NV_STRAP", "mount", "NV_QUAD") and not WPm.fits("HELMET_C2", "mount", "NV_BINO"))
		local nh = Inv.newHolder("profile")
		local hg, hi = Inv.newItem("HELMET_C4", 1)
		local ng, ni = Inv.newItem("NV_MONO", 1)
		Inv.place(nh, hg, hi, { "stash" })
		Inv.place(nh, ng, ni, { "stash" })
		local okA = Inv.attachPart(nh, hg, "mount", ng, { "stash" })
		local okI = Inv.check(nh)
		local okD = Inv.detachPart(nh, hg, "mount", { "stash" })
		check("goggles go on a helmet's mount and come off again", okA and okI and okD and not (nh.items[hg].mods and nh.items[hg].mods.mount) and Inv.locate(nh, ng) == "grid")
	end
	-- ballistics (Tarkov): drop grows with distance; a zeroed arc meets the line of sight at the zero distance
	do
		local Bl = require(Shared.Ballistics)
		local v0, k = Bl.muzzle({ velocity = 880 }, 1), Bl.drag({ class = "rifle" })
		local a100, a300 = Bl.zeroAngle(100, v0, k), Bl.zeroAngle(300, v0, k)
		check("ballistics: zeroing further tilts the bore more", a100 > 0 and a300 > a100 * 2)
		local sky = RaycastParams.new()
		sky.FilterType = Enum.RaycastFilterType.Include
		sky.FilterDescendantsInstances = {}
		local o = Vector3.new(0, 3000, 0)
		local _, endPos = Bl.trace(o, Bl.tilt(Vector3.new(1, 0, 0), a100), v0, k, 100 * Bl.STUDS_PER_M, sky)
		local _, endFlat = Bl.trace(o, Vector3.new(1, 0, 0), v0, k, 100 * Bl.STUDS_PER_M, sky)
		check("ballistics: a 100 m zero crosses the sight line at 100 m; an untilted shot has dropped", math.abs(endPos.Y - o.Y) < 0.06 and (o.Y - endFlat.Y) > 0.15)
		-- a bullet in flight (server, real time) reaches what is in its path
		local box = Instance.new("Part")
		box.Anchored, box.Size, box.Position = true, Vector3.new(4, 6, 1), Vector3.new(5000, 3000, -100)
		box.Parent = workspace
		local only = RaycastParams.new()
		only.FilterType = Enum.RaycastFilterType.Include
		only.FilterDescendantsInstances = { box }
		local got
		Bl.fly(Vector3.new(5000, 3000, 0), Vector3.new(0, 0, -1), v0, k, 400, only, function(res)
			got = res.Instance
		end)
		local t0 = os.clock()
		while not got and os.clock() - t0 < 1 do
			task.wait()
		end
		box:Destroy()
		check("ballistics: a bullet in flight hits what is in its path", got == box)
	end
	-- propane cylinders (Customs): a hit bursts one, a neighbour goes with it, a new raid puts them back
	do
		local H = ctx.Hazards
		local holder = Instance.new("Folder")
		holder.Parent = workspace
		local a = H.register(holder, CFrame.new(6000, 2000, 0))
		local b = H.register(holder, CFrame.new(6004, 2000, 0))
		local burst = H.hit(a.model.PrimaryPart, nil)
		task.wait(0.8)
		local gone = a.model == nil and b.model == nil
		H.reset()
		local back = a.model ~= nil and b.model ~= nil
		for i = #H.spots, 1, -1 do
			if H.spots[i] == a or H.spots[i] == b then
				table.remove(H.spots, i)
			end
		end
		holder:Destroy()
		check("propane: a hit bursts it and its neighbour; a new raid restores both", burst and gone and back)
	end
	-- border snipers: Border Yard registers edge strips, with its spawns left clear
	check("border sniper strips on Border Yard", #ctx.Hazards.zones >= 4)
	-- seasons (Tarkov 0.16): by the calendar, and every rolled raid carries one
	do
		local Env = require(Shared.Env)
		check("seasons by month", Env.seasonOf(1) == "winter" and Env.seasonOf(4) == "spring" and Env.seasonOf(7) == "summer" and Env.seasonOf(10) == "autumn" and Env.seasonOf(12) == "winter")
		local e = Env.roll(Random.new(5))
		check("a rolled raid has a season", Env.SEASONS[e.season] ~= nil)
	end
	-- the movement guard: a sprint and a vault fit in a sample, a 30-stud jump does not
	do
		local h, up = ctx.Guard.limits(18, 0.25)
		check("movement guard limits: sprint plus vault allowed, teleports caught", h > 18 * 0.25 + 3 and h < 30 and up > 7 and up < 30)
		-- hardened 2026-11-07 (audit tech-6): falls fit, a 60-stud drop from rest is a teleport, walls stop a straight line
		check("movement guard: a real fall fits, a 60-stud drop from standing does not", ctx.Guard.maxDrop(40, 0.25) > 40 * 0.25 + 1 and ctx.Guard.maxDrop(0, 0.25) * 2 < 60)
		local wall = Instance.new("Part")
		wall.Anchored, wall.CanCollide, wall.Size, wall.Transparency = true, true, Vector3.new(1, 12, 12), 1
		wall.CFrame = CFrame.new(0, 900, 0)
		wall.Parent = workspace
		local across = ctx.Guard.throughWall(Vector3.new(-5, 900, 0), Vector3.new(5, 900, 0))
		local along = ctx.Guard.throughWall(Vector3.new(-5, 900, 8), Vector3.new(5, 900, 8))
		wall.CanCollide = false
		local ghost = ctx.Guard.throughWall(Vector3.new(-5, 900, 0), Vector3.new(5, 900, 0))
		wall:Destroy()
		check("movement guard: a move through a solid wall is caught, beside it or through a non-solid part is not", across and not along and not ghost)
		-- line of sight for looting and doors (audit quick win tech.5): a wall between the head and the target blocks,
		-- the target's own furniture around it does not
		local head = Instance.new("Part")
		head.Name, head.Anchored, head.CanCollide, head.CanQuery, head.Size = "Head", true, false, false, Vector3.one
		head.CFrame = CFrame.new(-6, 900, 0)
		local fakeChar = Instance.new("Model")
		head.Parent = fakeChar
		local drawer = Instance.new("Part")
		drawer.Anchored, drawer.Size, drawer.CFrame = true, Vector3.new(1, 1, 1), CFrame.new(6, 900, 0)
		drawer.Parent = workspace
		local blocker = Instance.new("Part")
		blocker.Anchored, blocker.Size, blocker.CFrame = true, Vector3.new(1, 12, 12), CFrame.new(0, 900, 0)
		blocker.Parent = workspace
		local seenThroughWall = ctx.Guard.canSee(fakeChar, drawer, 1.2)
		blocker.CFrame = CFrame.new(5.2, 900, 0) -- now the desk the drawer sits in, just in front of it
		local seenInDesk = ctx.Guard.canSee(fakeChar, drawer, 1.2)
		blocker:Destroy()
		local seenClear = ctx.Guard.canSee(fakeChar, drawer, 1.2)
		drawer:Destroy()
		fakeChar:Destroy()
		check("line of sight: a wall blocks looting and doors, the container's own furniture does not", not seenThroughWall and seenInDesk and seenClear)
	end
	-- the INSPECT window's per-class penetration chances use the same formula as hits (Health.luau)
	-- (Tarkov's curve since gameplay-2a: none 15 below the class's 10x, always 15 above since EFT 0.14.6; 6.2 FMJ vs class 2: 96.7 %)
	check("penetration chance formula shared (Tarkov's curve, gameplay-2a)", Items.penChance(25, 4, 1) == 0 and Items.penChance(56, 4, 1) == 1
		and Items.penChance(26, 2, 1) > 0.95 and Items.penChance(26, 2, 1) < 1)
	-- audit gameplay.2-4 and .14-15 (Tarkov's numbers): velocity factor, fragmentation, spill, grenade gravity, Factory time
	if ctx and ctx.Combat and ctx.Combat.velocityFactor then
		local C = ctx.Combat
		check("velocity factor: full speed keeps everything, 60 % speed does 60 %, never under a fifth",
			C.velocityFactor(1) == 1 and math.abs(C.velocityFactor(0.6) - 0.6) < 1e-9 and C.velocityFactor(0.05) == 0.2 and C.velocityFactor(nil) == 1)
		check("fragmentation: only rounds with 20+ penetration, at the round's own chance",
			C.fragments({ pen = 26, frag = 0.2 }, 0.1) and not C.fragments({ pen = 26, frag = 0.2 }, 0.3) and not C.fragments({ pen = 12, frag = 0.45 }, 0.01))
	end
	if ctx and ctx.Health and ctx.Health.SPILL then
		local S = ctx.Health.SPILL
		check("spill: EFT's x0.49 arms, x0.7 legs, x1.05 stomach", S.larm == 0.49 and S.rarm == 0.49 and S.lleg == 0.7 and S.rleg == 0.7 and S.stomach == 1.05)
	end
	do
		local Gr = require(Shared.Grenades)
		local MapsD = require(Shared.Maps)
		check("grenades fall at the world's real gravity (30.7 studs/s2, as bullets)", Gr.GRAV == 30.7)
		check("Smelter (our Factory) raids last 20 minutes", MapsD.defs.smelter.raidTime == 1200)
	end
	-- audit ai.14: the border sniper fires from beyond the strip's outer edge, whichever edge it is
	if ctx and ctx.Hazards and ctx.Hazards.sniperOffset and ctx.World and ctx.World.bounds then
		local b = ctx.World.bounds
		local east = ctx.Hazards.sniperOffset({ lo = Vector3.new(b.x1 - 10, -100, b.z0), hi = Vector3.new(b.x1, 100, b.z1) })
		local north = ctx.Hazards.sniperOffset({ lo = Vector3.new(b.x0, -100, b.z0), hi = Vector3.new(b.x1, 100, b.z0 + 10) })
		check("border sniper: an east strip is shot from the east, a north strip from the north, 40 up",
			east.X == 200 and math.abs(east.Z) <= 60 and north.Z == -200 and math.abs(north.X) <= 60 and east.Y == 40 and north.Y == 40)
	end
	-- audit ai.15: Smelter (our Factory) rolls Tagilla (THE STOKER) at 30 % and the cultists at 8 % at night
	do
		local sb = ctx and ctx.World and ctx.World.maps and ctx.World.maps.smelter and ctx.World.maps.smelter.bosses
		local st, cu = nil, nil
		for _, b in sb or {} do
			if b.label == "Stoker" then
				st = b
			elseif b.label == "Priest" then
				cu = b
			end
		end
		checkOn("smelter", "Smelter rolls THE STOKER at 30 % (1,220 health, the hammer) and THE CULT at 8 % in night raids, three zones",
			st ~= nil and st.chance == 0.3 and st.charge == true and math.abs(st.hp * 440 - 1220) < 1e-6 and #st.route >= 4
				and cu ~= nil and cu.chance == 0.08 and cu.night == true and #cu.zones == 3)
	end
	-- audit ai.2: EFT's boss health (scales of the 440 a PMC has)
	do
		local bb = ctx and ctx.World and ctx.World.maps and ctx.World.maps.border and ctx.World.maps.border.boss
		checkOn("border", "the Broker has Reshala's 752 health and his guards 630", bb ~= nil and math.abs(bb.hp * 440 - 752) < 1e-6 and math.abs(bb.crewHp * 440 - 630) < 1e-6)
		-- audit ai.3: Reshala's three zones, his own chance, look and kit (no armour, no helmet, none of the Foreman's loot)
		local bk = Loot.brokerLoadout(Random.new(5))
		local foreman = false
		for _, it in bk.items do
			if it.id == "KEY_OFFICE" or it.id == "LEDGER" or it.id == "BRASS_LION" then
				foreman = true
			end
		end
		-- every zone stands on the map at its own building, its guards and loop round its home (a first version doubled the
		-- map offset, so the guards spawned off the map, and its fuel stop fell back to a storage block across the map).
		-- The dorm guards wait in the courtyard, 75-95 studs from the lobby, and his dorm loop reaches 134 studs out.
		local bw = ctx and ctx.World and ctx.World.maps and ctx.World.maps.border
		local near = bb ~= nil and bb.zones ~= nil and bw ~= nil and bw.bounds ~= nil
		local mapsF = script.Parent.Parent:FindFirstChild("Maps")
		local layM = mapsF and mapsF:FindFirstChild("Border") and mapsF.Border:FindFirstChild("Layout")
		local okL, Lay = false, nil
		if layM then
			okL, Lay = pcall(require, layM)
		end
		local at = {}
		if near and okL and type(Lay) == "table" then
			local ox, oz = bw.bounds.x0 - Lay.box[1], bw.bounds.z0 - Lay.box[2]
			for _, e in Lay.blds do
				at[e[2]] = Vector3.new(ox + e[4], 0, oz + e[5])
			end
		end
		local function onMap(p)
			local b = bw.bounds
			return p.X > b.x0 and p.X < b.x1 and p.Z > b.z0 and p.Z < b.z1
		end
		local WANT = { DORMS = "BLOCK A", ["FUEL STOP"] = "FUEL STOP", BASTION = "THE BASTION" }
		for _, z in (near and bb.zones) or {} do
			local c = at[WANT[z.name] or ""]
			near = near and c ~= nil and onMap(z.home) and (Vector3.new(z.home.X, 0, z.home.Z) - c).Magnitude < 110
			for _, p in z.crew or {} do
				near = near and onMap(p) and (p - z.home).Magnitude < 100
			end
			for _, p in z.route or {} do
				near = near and onMap(p) and (p - z.home).Magnitude < 150
			end
		end
		checkOn("border", "the Broker's zones stand on the map at the dorms, the fuel stop and the Bastion, guards and loop round each home", near)
		checkOn("border", "the Broker: three zones (dorms, fuel stop, Bastion), 45 %, his own look; no armour, helmet or Foreman loot",
			bb ~= nil and bb.zones ~= nil and #bb.zones == 3 and bb.chance == 0.45 and bb.look == "broker" and bb.loadout == "brokerLoadout"
				and bk.slots.armor == nil and bk.slots.head == nil and bk.slots.holster ~= nil and not foreman)
		local mb = ctx and ctx.World and ctx.World.maps and ctx.World.maps.meridian and ctx.World.maps.meridian.boss
		checkOn("meridian", "the Caretaker has Killa's 890 health and five double pockets", mb ~= nil and math.abs(mb.hp * 440 - 890) < 1e-6
			and (function()
				local h = Loot.caretakerLoadout(Random.new(3))
				return h.pocketsW == 5 and h.pocketsH == 2
			end)())
	end
	-- audit tech.13: clients get only the meshes they clone; the server keeps the whole library in ServerStorage
	do
		local sl = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
		local cl = game:GetService("ReplicatedStorage"):FindFirstChild("ZR_Assets")
		if sl and cl and ctx and ctx.Assets and ctx.Assets.clientNeeds and #sl:GetChildren() > 0 then
			local need, extra, missing = 0, 0, 0
			for _, d in sl:GetChildren() do
				if ctx.Assets.clientNeeds(d.Name) then
					need += 1
					missing += cl:FindFirstChild(d.Name) and 0 or 1
				end
			end
			for _, d in cl:GetChildren() do
				extra += ctx.Assets.clientNeeds(d.Name) and 0 or 1
			end
			check(string.format("clients get only the meshes they clone (%d of the library's %d)", #cl:GetChildren(), #sl:GetChildren()),
				missing == 0 and extra == 0 and #cl:GetChildren() == need and need < #sl:GetChildren()
					and cl:FindFirstChild("ZR_MK_Van__paint") == nil and cl:FindFirstChild("ZR_NAT_Grass") ~= nil)
		end
	end
	-- every item a trader's barter asks for can be had: found in a loot pool, bought from a trader or crafted
	-- (CRACKED_LENS was in no pool, so VOS's 4x scope barter could never be done; economy helper, 2026-11-08)
	do
		local TDb = require(Shared.TraderData)
		local HDb = require(Shared.HideoutData)
		local got = {}
		for _, pool in Loot.POOLS do
			for _, e in pool do
				if type(e) == "table" and e.id then
					got[e.id] = true
				end
			end
		end
		for _, list in TDb.offers do
			for _, of in list do
				got[of.id] = true
			end
		end
		for _, r in HDb.recipes or {} do
			if r.get then
				got[r.get[1]] = true
			end
		end
		local missing = {}
		for _, list in TDb.barters do
			for _, bt in list do
				for _, g in bt.give do
					if not got[g[1]] and not table.find(missing, g[1]) then
						table.insert(missing, g[1])
					end
				end
			end
		end
		check("every barter ingredient can be found, bought or crafted" .. (#missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. ")") or ""),
			#missing == 0)
	end
	-- audit art.2: our own hazy skies; the server puts up the clear set, clients switch by weather and hour
	do
		local SkyM = require(Shared.Sky)
		local okIds = true
		for _, set in SkyM.SETS do
			for _, v in set do
				okIds = okIds and string.match(v, "^rbxassetid://%d+$") ~= nil
			end
		end
		local live = game:GetService("Lighting"):FindFirstChild("ZR_Sky")
		check("skies: three sets of real image ids; night from dusk to dawn, overcast under weather; the server's sky starts clear",
			okIds and SkyM.pick("clear", 2) == "night" and SkyM.pick("clear", 12) == "clear" and SkyM.pick("rain", 12) == "overcast"
				and SkyM.pick("fog", 21.5) == "night" and live ~= nil and live.SkyboxBk == SkyM.SETS.clear.side)
	end
	-- audit ai-1a: EFT's roster on the Tarkov-layout maps. Border Yard (Customs): scavs on the posts and the Bastion's guns,
	-- marksmen on the reference's perches (the tower one always, the bridge and factory ones half the time); no Watch
	do
		local bm = ctx and ctx.World and ctx.World.maps and ctx.World.maps.border
		local scavs, watch, marks, sure = 0, 0, 0, 0
		for _, wp in (bm and bm.watchPosts) or {} do
			if wp.kind == "scav" then
				scavs += 1
			else
				watch += 1
			end
			if wp.role == "marksman" then
				marks += 1
				sure += (wp.chance == 1) and 1 or 0
			end
		end
		checkOn("border", "Border Yard: scavs on every post and gun, no Watch; three marksman perches, the tower one always manned",
			scavs >= 8 and watch == 0 and marks == 3 and sure == 1)
		local mk = Loot.marksmanLoadout(Random.new(4))
		local mg = mk.slots.primary and mk.items[mk.slots.primary]
		check("a marksman carries a bolt rifle and no armour", mg ~= nil and mg.id == "TUNDRA_BOLT" and mk.slots.armor == nil)
	end
	-- audit ai-7a: EFT's player scav window. From 17 minutes in on Border Yard and Meridian Mall (Customs, Interchange),
	-- from the start on Smelter and Quay 7, until SCAV_CUTOFF before the end
	do
		local MapsW = require(Shared.Maps)
		local bf, bt = MapsW.scavWindow("border", 1000, 3400, Config.SCAV_CUTOFF)
		local mf = MapsW.scavWindow("meridian", 0, 2400, Config.SCAV_CUTOFF)
		local sf, st = MapsW.scavWindow("smelter", 50, 1250, Config.SCAV_CUTOFF)
		local qf = MapsW.scavWindow("quay7", 0, 1500, Config.SCAV_CUTOFF)
		check("player scavs: in from 17 minutes on Border Yard and Meridian, from the start on Smelter and Quay 7, until the cutoff",
			bf == 2020 and bt == 3400 - Config.SCAV_CUTOFF and mf == 1020 and sf == 50 and st == 1250 - Config.SCAV_CUTOFF and qf == 0)
		check("player scavs: Match lets them in by the window and has a scav spawn", ctx and ctx.Match and type(ctx.Match.scavSpawn) == "function"
			and type(ctx.Match.canEnter) == "function")
	end
	-- audit ai-2: EFT's sleep. Calm units over 300 m (937.5 studs) from every raider sleep; they wake inside 265 m, and the
	-- gap between keeps them from flickering; a unit that is not calm never falls asleep
	if ctx and ctx.AI and ctx.AI.sleepState then
		local ss, FAR, NEAR = ctx.AI.sleepState, ctx.AI.SLEEP_FAR, ctx.AI.WAKE_NEAR
		check("AI sleep: calm and over 300 m from every raider sleeps; wakes inside 265 m; holds its state between; never while alert",
			FAR == 937.5 and NEAR == 828.125 and ss(false, 1000, true) == true and ss(false, 1000, false) == false and ss(false, 900, true) == false
				and ss(true, 900, true) == true and ss(true, 820, true) == false and ss(true, math.huge, false) == true)
	end
	-- audit ai.8: scavs spawn alone or in groups of two or three (45 / 45 / 10 %), never more than the room left
	if ctx and ctx.AI and ctx.AI.groupSize then
		local gs = ctx.AI.groupSize
		local n, solo, three, over, capped = 3000, 0, 0, 0, true
		for _ = 1, n do
			local s = gs(3)
			solo += (s == 1) and 1 or 0
			three += (s == 3) and 1 or 0
			over += (s > 3 or s < 1) and 1 or 0
			capped = capped and gs(1) == 1 and gs(2) <= 2 and gs(0) == 1
		end
		check("scavs spawn alone (about 45 %), in pairs or in threes (about 10 %), never past the room left",
			over == 0 and capped and math.abs(solo / n - 0.45) < 0.04 and math.abs(three / n - 0.097) < 0.025)
	end

	-- ammo + magazines
	local mg, mi = Inv.newItem("R17_MAG", 1, { a = 0 })
	Inv.place(h, mg, mi, { "stash" })
	local ag = biggest(h, "A62_FMJ")
	local loaded = Inv.loadAmmo(h, mg, ag)
	check("load mag 25", loaded == 25 and h.items[mg].a == 25 and h.items[mg].at == "A62_FMJ" and countId(h, "A62_FMJ") == 55 and inv(h))
	local pg, pi = Inv.newItem("A9_PST", 20)
	Inv.place(h, pg, pi, { "stash" })
	local _, eCal = Inv.loadAmmo(h, mg, pg)
	check("wrong caliber rejected", eCal == "WRONG_CALIBER")
	local apg, api = Inv.newItem("A62_AP", 10)
	Inv.place(h, apg, api, { "stash" })
	Inv.unloadAmmo(h, mg, { "stash" })
	check("unload returns rounds", h.items[mg].a == 0 and countId(h, "A62_FMJ") == 80 and inv(h))
	Inv.loadAmmo(h, mg, ag, 5)
	local _, eMix = Inv.loadAmmo(h, mg, apg)
	check("mixed ammo rejected", eMix == "MIXED_AMMO")
	-- best mag + swap
	local q = Settle.newProfile()
	local qw = q.slots.primary
	local qold = q.items[qw].mag
	q.items[qold].a = 3
	local best = Inv.bestMag(q, qw)
	check("best mag from rig", best ~= nil and Inv.locate(q, best) == "grid" and q.items[best].a == 25)
	local okSwap = Inv.insertMag(q, best, qw)
	check("mag swap keeps both", okSwap and q.items[qw].mag == best and Inv.locate(q, qold) == "grid" and inv(q))

	-- bundles / transfers between holders
	local bag = q.slots.back
	local before = 0
	for _ in q.grids[bag] do
		before += 1
	end
	local b = Inv.take(q, bag)
	check("take bag with contents", b ~= nil and #b.subs >= before and q.items[bag] == nil and inv(q))
	local box = Inv.newHolder("box", 6, 6)
	check("give bag to box", (Inv.give(box, b, nil, { "main" })) and inv(box) and box.items[bag] ~= nil)
	local moved = Inv.transfer(box, bag, q, { slot = "back" })
	check("transfer back to slot", moved and q.slots.back == bag and inv(q) and inv(box) and next(box.items) == nil)
	local tiny = Inv.newHolder("box", 1, 1)
	local okT, eT = Inv.transfer(q, bag, tiny, nil, { "main" })
	check("failed transfer rolls back", not okT and q.slots.back == bag and inv(q) and inv(tiny) and eT ~= nil)
	local s1, i1 = Inv.newItem("A62_FMJ", 40)
	local s2, i2 = Inv.newItem("A62_FMJ", 40)
	local hb = Inv.newHolder("box", 3, 3)
	Inv.place(hb, s1, i1, { "main" })
	Inv.place(q, s2, i2, { "stash" })
	local pl = hb.grids.main[s1]
	Inv.transfer(q, s2, hb, { c = "main", x = pl.x, y = pl.y, r = 0 })
	check("cross-holder merge conserves", hb.items[s1].n == 60 and q.items[s2].n == 20 and inv(q) and inv(hb))

	-- deploy / settle
	local prof = Settle.newProfile()
	local stashCount = 0
	for _ in prof.grids.stash do
		stashCount += 1
	end
	local firG = prof.slots.primary
	if firG and prof.items[firG] then
		prof.items[firG].fir = true
	end
	local raidInv = Settle.deploy(prof, "raid1", 1)
	check("deploy reserves loadout", raidInv ~= nil and prof.pendingRaid ~= nil and next(prof.slots) == nil and prof.pendingRaid.secure ~= nil)
	check("an item taken into a raid is no longer found in raid (Tarkov; audit economy.4)", firG ~= nil and raidInv.items[firG] ~= nil and raidInv.items[firG].fir == nil)
	check("deploy twice rejected", Settle.deploy(prof, "raid2", 2) == nil)
	check("profile invariant during raid", inv(prof))
	check("raid inventory invariant", inv(raidInv))
	local lg, li = Inv.newItem("SEALED_DRIVE", 1, { fip = true })
	check("loot into raid kit", (Inv.place(raidInv, lg, li, Inv.loadOrder(raidInv))))
	local r1 = Settle.finalize(prof, "raid1", "SUCCESS", raidInv, 3)
	local r2, e2 = Settle.finalize(prof, "raid1", "SUCCESS", raidInv, 4)
	check("success credits loot once", r1 ~= nil and prof.items[lg] ~= nil and r2 == nil and e2 == "ALREADY_FINALIZED")
	check("found in raid on extraction", prof.items[lg] and prof.items[lg].fir == true and prof.items[lg].fip == nil)
	check("profile invariant after success", inv(prof))

	local prof2 = Settle.newProfile()
	local inv2 = Settle.deploy(prof2, "raidK", 1)
	local kg, ki = Inv.newItem("GOLD_CHAIN", 1, { fip = true })
	Inv.place(inv2, kg, ki, { inv2.slots.secure })
	local xg, xi = Inv.newItem("DECK_TRANSCEIVER", 1, { fip = true })
	Inv.place(inv2, xg, xi, Inv.loadOrder(inv2))
	local rk = Settle.finalize(prof2, "raidK", "KIA", inv2, 2)
	check("KIA lists losses", rk ~= nil and #rk.lost > 0 and #rk.retained == 0)
	check("KIA keeps secure contents", prof2.slots.secure ~= nil and prof2.items[kg] ~= nil and prof2.items[kg].fir == nil and prof2.items[kg].fip == nil)
	check("KIA loses the rest", prof2.items[xg] == nil and prof2.slots.primary == nil and next(prof2.grids.pockets) == nil)
	check("invariant after KIA", inv(prof2))
	prof2.money = 0
	local okRk = Settle.recoveryKit(prof2)
	check("recovery kit when broke", okRk and inv(prof2))
	check("recovery kit only once", not Settle.recoveryKit(prof2))
	local rkValue = 0
	for _, it in prof2.items do
		if it.rk then
			rkValue += Items.valueOf(it)
		end
	end
	check("recovery kit worth nothing", rkValue == 0)

	local prof3 = Settle.newProfile()
	local raid3 = Settle.deploy(prof3, "raidD", 1)
	local sec3 = raid3.slots.secure
	local rd = Settle.finalize(prof3, "raidD", "DISCONNECTED", nil, 2)
	check("crash settles as loss, secure restored", rd ~= nil and prof3.pendingRaid == nil and #rd.lost > 0 and prof3.slots.secure == sec3 and inv(prof3))

	-- audit tech-7: a server closing mid-raid keeps the kit, but nothing is found in raid and it is not a survival
	local prof4 = Settle.newProfile()
	local raid4 = Settle.deploy(prof4, "raidC", 1)
	local wg4 = raid4.slots.primary
	local cg, ci = Inv.newItem("SEALED_DRIVE", 1, { fip = true })
	Inv.place(raid4, cg, ci, Inv.loadOrder(raid4))
	local survived4 = prof4.stats.survived
	local rc4 = Settle.finalize(prof4, "raidC", "SUCCESS", raid4, 2, { runThrough = true, closed = true })
	check("server closed: kit and loot kept", rc4 ~= nil and prof4.slots.primary == wg4 and prof4.items[cg] ~= nil and prof4.pendingRaid == nil and inv(prof4))
	check("server closed: loot not found in raid", prof4.items[cg] and prof4.items[cg].fir == nil and prof4.items[cg].fip == nil)
	check("server closed: not counted as survived", prof4.stats.survived == survived4)

	local old = { schema = 1, items = {}, settings = { fov = 90 } }
	Settle.migrate(old)
	check("schema change wipes, keeps settings", old.schema == Settle.SCHEMA and old.settings.fov == 90 and old.slots.primary ~= nil and inv(old))

	-- loot
	local lb = Inv.newHolder("box", 5, 4)
	local order = Loot.fill(lb, Random.new(7), "crate", 4)
	check("loot fill invariant", inv(lb) and #order >= 1)
	local gl = Loot.guardLoadout(Random.new(3))
	check("guard loadout invariant", inv(gl) and gl.slots.primary ~= nil and gl.slots.rig ~= nil)

	-- health model (pure parts)
	local Health = require(Services.Health)
	local hs = Health.new()
	local t0, m0 = Health.total(hs)
	check("health 440 total", t0 == 440 and m0 == 440)
	Health.applyDamage(hs, "larm", 80)
	check("limb overflow spills", hs.parts.larm.hp == 0 and Health.total(hs) < 440 - 60 and not hs.dead)
	local before = hs.parts.thorax.hp
	Health.applyDamage(hs, "larm", 30)
	check("destroyed limb spreads damage", hs.parts.thorax.hp < before and not hs.dead)
	Health.applyDamage(hs, "head", 40)
	check("head destroyed kills", hs.dead == true)
	local hs2 = Health.new()
	Health.applyDamage(hs2, "thorax", 84)
	check("thorax at 1 survives", not hs2.dead and hs2.parts.thorax.hp == 1)
	Health.applyDamage(hs2, "lleg", 200)
	check("spill into thorax kills", hs2.dead == true)
	local hs3 = Health.new()
	hs3.fract.lleg = true
	check("fracture causes pain, slows, no sprint", Health.inPain(hs3) and Health.mods(hs3).speed < 1 and Health.mods(hs3).sprint == false)
	hs3.painUntil = os.clock() + 60
	check("painkillers allow sprint", Health.mods(hs3).sprint == true and not Health.inPain(hs3))

	-- M14 weapon modding (Tarkov-style builds: slots and fits, swaps, conflicts, required parts, sizes, the
	-- multitool rule in raid, presets, tube capacity)
	do
		local WP = require(Shared.WeaponParts)
		local h = Settle.newProfile()
		local rifle, pistol = h.slots.primary, h.slots.holster
		local function stash(id, extra)
			local g, it = Inv.newItem(id, 1, extra)
			local okP = Inv.place(h, g, it, { "stash" })
			return okP and g or nil
		end
		local function partOn(rootG, id)
			local found
			WP.walk(h.items, rootG, function(cg, it)
				if it.id == id then
					found = cg
				end
			end)
			return found
		end
		local r = h.items[rifle]
		check("starter rifle is a whole default build", WP.signature(h.items, rifle) ~= "" and partOn(rifle, "R17_UPPER") ~= nil and partOn(rifle, "R17_BRL_145") ~= nil and WP.operable(h.items, rifle) and inv(h))
		local w0, h0 = Inv.sizeOf(r)
		check("default R-17 is 5x2", w0 == 5 and h0 == 2)
		local barrel = partOn(rifle, "R17_BRL_145")
		local supp9, supp62, dot, scope, light = stash("SUPP_9"), stash("SUPP_62"), stash("RED_DOT"), stash("SCOPE_4X"), stash("LIGHT_T")
		check("parts placed", supp9 and supp62 and dot and scope and light and true)
		check("9mm suppressor does not fit the 6.2 barrel", select(2, Inv.attachPart(h, barrel, "muzzle", supp9, { "stash" })) == "WRONG_FIT")
		check("rail optic does not fit the pistol", select(2, Inv.attachMod(h, pistol, dot, { "stash" })) == "NO_SLOT")
		local fh = partOn(rifle, "R17_FH_A2")
		check("suppressor replaces the flash hider (swap to stash)", (Inv.attachMod(h, rifle, supp62, { "stash" })) and h.items[barrel].mods.muzzle == supp62 and Inv.locate(h, fh) == "grid" and inv(h))
		local w1 = Inv.sizeOf(h.items[rifle])
		check("a suppressor makes the rifle longer (6 cells)", w1 == 6)
		check("reflex goes on the upper's rail", (Inv.attachMod(h, rifle, dot, { "stash" })) and partOn(rifle, "RED_DOT") == dot and inv(h))
		check("scope swaps the reflex back to the stash", (Inv.attachMod(h, rifle, scope, { "stash" })) and partOn(rifle, "SCOPE_4X") == scope and Inv.locate(h, dot) == "grid" and inv(h))
		local ms = Inv.modStats(h, rifle)
		check("build stats: suppressed, 4x, quieter, less recoil", ms.suppressed and ms.zoom == 4 and ms.loud < 0.5 and ms.recoil < 1 and ms.operable)
		check("no rail for a light on the carbine handguard", select(2, Inv.attachMod(h, rifle, light, { "stash" })) == "NO_SLOT")
		-- the quad rail handguard: a light goes on its side rail
		local quad = stash("R17_HG_QUAD")
		local upper = partOn(rifle, "R17_UPPER")
		local carb = partOn(rifle, "R17_HG_CARB")
		check("quad rail replaces the carbine handguard", (Inv.attachPart(h, upper, "handguard", quad, { "stash" })) and Inv.locate(h, carb) == "grid" and inv(h))
		check("light on the quad rail (slot drop on the equipped gun)", (Inv.move(h, light, { slot = "primary" })) and partOn(rifle, "LIGHT_T") == light and Inv.modStats(h, rifle).light)
		-- conflicts: a free-float handguard needs a low-profile gas block
		local mlok = stash("R17_HG_MLOK")
		check("free-float handguard refused over the front sight gas block", select(2, Inv.attachPart(h, upper, "handguard", mlok, { "stash" })) == "CONFLICT")
		-- required parts: no barrel, no shooting; the barrel comes off with its parts
		local mass0 = Inv.weight(h)
		check("parts count toward carried weight", mass0 > 0)
		check("barrel off (with its suppressor and gas block)", (Inv.detachPart(h, upper, "barrel", { "stash" })) and Inv.locate(h, barrel) == "grid" and h.items[barrel].mods.muzzle == supp62 and Inv.weight(h) < mass0 and inv(h))
		check("a gun without a barrel is not operable", not WP.operable(h.items, rifle) and #WP.missing(h.items, rifle) == 1 and WP.missing(h.items, rifle)[1].slot == "barrel")
		local bw = Inv.sizeOf(h.items[barrel])
		check("a barrel with a suppressor on it is bigger than the bare barrel", bw > Items.defs.R17_BRL_145.w)
		check("barrel back on", (Inv.attachPart(h, upper, "barrel", barrel, { "stash" })) and WP.operable(h.items, rifle) and inv(h))
		-- the build moves as one bundle
		local b = Inv.take(h, rifle)
		check("bundle carries the whole build", b ~= nil and #b.subs >= 8)
		check("bundle restore", b ~= nil and (Inv.give(h, b, nil, { "stash" })) and partOn(rifle, "SCOPE_4X") == scope and inv(h))
		-- a magazine dropped onto the equipped pistol loads it
		local spareMag = stash("P9_MAG")
		local oldMag = h.items[pistol].mag
		check("mag onto holster slot inserts", spareMag ~= nil and (Inv.move(h, spareMag, { slot = "holster" })) and h.items[pistol].mag == spareMag and Inv.locate(h, oldMag) == "grid" and inv(h))
		-- presets and tube-fed capacity
		local tac = stash("HARROW12", { preset = "HAR_TAC" })
		check("a preset gun arrives as its build", tac ~= nil and partOn(tac, "HAR_TUBE_8") ~= nil and partOn(tac, "RED_DOT") ~= nil and inv(h))
		check("tube-fed capacity comes from the tube (8)", tac ~= nil and Inv.capacityOf(h, tac) == 8)
		local sw, sh = Inv.sizeOf(h.items[tac])
		check("preset size from its parts", sw >= 6 and sh >= 1)
		-- in a raid, vital parts need a multitool; functional parts do not (Tarkov 0.14+)
		local h2 = Settle.newProfile()
		local raid = Settle.deploy(h2, "MT1", 1000)
		local rg = raid and raid.slots.primary
		local rbar, rgrip
		if rg then
			WP.walk(raid.items, rg, function(cg, it)
				if it.id == "R17_BRL_145" then
					rbar = cg
				elseif it.id == "AR_PG_A2" then
					rgrip = cg
				end
			end)
		end
		check("raid copy keeps the build", rbar ~= nil and rgrip ~= nil)
		if rbar and rgrip then
			local order = Inv.loadOrder(raid)
			check("raid: pistol grip cannot come off without a multitool", select(2, Inv.detachPart(raid, rg, "grip", order, { inRaid = true })) == "NEED_MULTITOOL")
			check("raid: a vital part cannot be dragged off either", select(2, Inv.move(raid, rgrip, { c = order[1], x = 1, y = 1 }, { inRaid = true })) == "NEED_MULTITOOL")
			check("raid: the flash hider comes off without tools", (Inv.detachPart(raid, rbar, "muzzle", order, { inRaid = true })) and Inv.check(raid))
			local mtg, mt = Inv.newItem("MULTITOOL")
			local placed = Inv.place(raid, mtg, mt, order)
			check("raid: with a multitool the grip comes off", placed and (Inv.detachPart(raid, rg, "grip", order, { inRaid = true })) and Inv.check(raid))
			check("raid: no grip, no shooting", not WP.operable(raid.items, rg))
		end
	end

	-- operator rig math (shared by the server hitbox pose and every client's animator)
	do
		local RigMath = require(Shared.RigMath)
		local RigSpec = require(Shared.RigSpec)
		local root = CFrame.new(RigSpec.hrp.center)
		local chest = CFrame.new(RigSpec.parts.UpperTorso.center)
		local c = RigMath.arm.R
		local target = (chest * CFrame.new(0.3, 0, -0.9)).Position
		local _, _, _, handCF = RigMath.solve(c, chest, target, CFrame.identity, Vector3.new(0.6, -0.7, 0.9))
		check("arm IK reaches its target", ((handCF * CFrame.new(c.j3.p1)).Position - target).Magnitude < 0.02)
		local L, W = RigMath.pose(root, { stance = "s", hold = "long", mode = "ready", weapon = { grip = Vector3.new(0, -0.12, 0.05), hand = Vector3.new(0, -0.04, -1.02) } })
		local n = 0
		for _ in L do
			n += 1
		end
		check("pose solves all 15 joints and the weapon", n == 15 and W ~= nil)
		check("stance hip heights", RigMath.hipFor("c", 1) < RigMath.hipFor("s") and RigMath.hipFor("p") < RigMath.hipFor("c", 1))
		local eyeS = RigMath.eye(root, { stance = "s" }).Position.Y
		local eyeP = RigMath.eye(root * CFrame.new(0, RigMath.hipFor("p") - RigMath.STAND_HIP, 0), { stance = "p" }).Position.Y
		check("eye heights stand/prone", eyeS > 4.8 and eyeS < 5.6 and eyeP < 1.4)
		local eyeL = RigMath.eye(root, { stance = "s", lean = 1 }).Position
		check("lean right moves the eye right", eyeL.X > 0.6)
		-- crouched legs keep the ankles on the floor
		local crootY = RigSpec.hrp.center.Y - (RigMath.STAND_HIP - RigMath.hipFor("c", 1))
		local Lc = RigMath.pose(CFrame.new(0, crootY, 0), { stance = "c", depth = 1 })
		local Jr, Jh = RigMath.joints.Root, RigMath.joints.RightHip
		local pelvis = CFrame.new(0, crootY, 0) * CFrame.new(Jr.p0) * Lc.Root * CFrame.new(-Jr.p1)
		local thigh = pelvis * CFrame.new(Jh.p0) * Lc.RightHip * CFrame.new(-Jh.p1)
		local Jk, Ja = RigMath.joints.RightKnee, RigMath.joints.RightAnkle
		local shin = thigh * CFrame.new(Jk.p0) * Lc.RightKnee * CFrame.new(-Jk.p1)
		local ankle = (shin * CFrame.new(Ja.p0)).Position
		check("crouch IK plants the ankle", math.abs(ankle.Y - RigMath.ANKLE_H) < 0.05)
		-- M16 block body: proportions from the owner's reference (broad torso, arm and leg blocks, rounded head)
		local P = RigSpec.parts
		check("block body proportions", RigSpec.bodyVersion == "ZR_BLOCK_R15_V1" and math.abs(P.UpperTorso.size.X - 2 * P.LeftUpperLeg.size.X) < 0.05
			and P.Head.size.X < P.UpperTorso.size.X * 0.65 and math.abs(P.LeftUpperArm.size.X - P.LeftUpperLeg.size.X) < 0.05 and RigSpec.height > 5.2 and RigSpec.height < 5.7)
		-- the support hand reaches the long gun in the ready and aim holds (block arms are short for their width)
		local _, wp = require(Shared.WeaponModels).holdOf("R17_RIFLE")
		for _, mode in { "ready", "aim" } do
			local _, Wm = RigMath.pose(root, { stance = "s", hold = "long", mode = mode, weapon = wp })
			local _, chestM = RigMath.spine(root, { stance = "s" })
			local lh = Wm * CFrame.new(RigMath.supportPoint(wp, "long")) * RigMath.GRIP_L
			local wrist = (lh * CFrame.new(RigMath.arm.L.j3.p1)).Position
			local sh = (chestM * CFrame.new(RigMath.arm.L.j1.p0)).Position
			check("support hand reaches (" .. mode .. ")", (wrist - sh).Magnitude <= RigMath.arm.L.a + RigMath.arm.L.b + 0.02)
		end
	end

	-- M7: player scav raids
	do
		local function n(h)
			local c = 0
			for _ in h.items do
				c += 1
			end
			return c
		end
		local pr = Settle.newProfile()
		local kit = Loot.scavLoadout(Random.new(7))
		check("scav kit has a primary", kit.slots.primary ~= nil and inv(kit))
		local raidKit = Settle.deployScav(pr, "SCAV1", 1000, kit)
		check("scav deploy keeps the PMC loadout home", raidKit == kit and pr.slots.primary ~= nil and pr.pendingRaid ~= nil and pr.pendingRaid.scav == true)
		check("scav cooldown set (karma-adjusted)", pr.scavReadyAt == 1000 + require(Shared.Progress).scavCooldown(Config.SCAV_COOLDOWN, pr.karma))
		check("scav cannot double deploy", Settle.deployScav(pr, "SCAV2", 1001, kit) == nil)
		local lg, lit = Inv.newItem("GOLD_CHAIN", 1)
		lit.fip = true
		local placed = Inv.place(kit, lg, lit, Inv.loadOrder(kit))
		local rc = Settle.finalize(pr, "SCAV1", "SUCCESS", kit, 1100)
		check("scav extract settles", placed and rc ~= nil and rc.scav == true and pr.pendingRaid == nil and inv(pr))
		check("scav loot lands in the stash as FIR", pr.items[lg] ~= nil and pr.items[lg].fir == true and Inv.locate(pr, lg) == "grid")
		check("scav stats", pr.stats.scavRaids == 1 and pr.stats.scavSurvived == 1)
		local blocked, why = Settle.deployScav(pr, "SCAV3", 1200, Loot.scavLoadout(Random.new(8)))
		check("scav cooldown blocks", blocked == nil and why == "SCAV_COOLDOWN")
		local pr2 = Settle.newProfile()
		local before = n(pr2)
		local kit2 = Loot.scavLoadout(Random.new(9))
		Settle.deployScav(pr2, "SCAV4", 1000, kit2)
		local rk = Settle.finalize(pr2, "SCAV4", "KIA", kit2, 1100)
		check("scav death leaves the PMC untouched", rk ~= nil and n(pr2) == before and pr2.pendingRaid == nil and pr2.slots.primary ~= nil and inv(pr2))
		-- a server closing mid-raid: the scav's haul still comes home, but not as found in raid or as a survival
		local pr3 = Settle.newProfile()
		local kit3 = Loot.scavLoadout(Random.new(10))
		Settle.deployScav(pr3, "SCAV5", 1000, kit3)
		local sg3, sit3 = Inv.newItem("GOLD_CHAIN", 1)
		sit3.fip = true
		Inv.place(kit3, sg3, sit3, Inv.loadOrder(kit3))
		local rs3 = Settle.finalize(pr3, "SCAV5", "SUCCESS", kit3, 1100, { runThrough = true, closed = true })
		check("scav server closed: haul kept, not found in raid", rs3 ~= nil and pr3.items[sg3] ~= nil and pr3.items[sg3].fir == nil and inv(pr3))
		check("scav server closed: not counted as survived", pr3.stats.scavSurvived == 0 and pr3.stats.extractedValue == 0)
	end

	-- M7: insurance (insure, lose the kit on a body, settle at raid end, claim after the delay)
	if ctx and ctx.Match then
		local pr = Settle.newProfile()
		pr.money = 1000000
		local wg = pr.slots.primary
		local magG = pr.items[wg].mag
		local cost = Settle.insure(pr, wg, 42)
		check("insure weapon + mag", cost ~= nil and cost > 0 and pr.items[wg].ins == 42 and pr.items[magG].ins == 42)
		check("insure twice refused", select(2, Settle.insure(pr, wg, 42)) == "ALREADY_INSURED")
		check("secure container not insurable", select(2, Settle.insure(pr, pr.slots.secure, 42)) == "NOT_INSURABLE")
		local q = Settle.insureQuote(pr, 42)
		local all = Settle.insureAll(pr, 42)
		check("insure all", q.n > 0 and all == q.cost and Settle.insureQuote(pr, 42).n == 0)
		local raid = Settle.deploy(pr, "INS1", 2000)
		local bp = raid.slots.back
		local xg, xit = Inv.newItem("BOLTS", 1)
		local placedX = Inv.place(raid, xg, xit, { bp })
		Settle.finalize(pr, "INS1", "KIA", raid, 2100)
		local returns = {}
		local nb = ctx.Match.collectInsured(raid, returns)
		local bundles = returns[42] or {}
		local allIns, hasBolts, hasWeapon, hasMag = true, false, false, false
		for _, b in bundles do
			for _, x in { b, table.unpack(b.subs) } do
				allIns = allIns and x.it.ins == 42
				hasBolts = hasBolts or x.g == xg
				hasWeapon = hasWeapon or x.g == wg
				hasMag = hasMag or x.g == magG
			end
		end
		check("insured gear collected from the body", placedX and nb > 0 and #bundles == nb and hasWeapon and hasMag)
		check("only insured parts come back", allIns and not hasBolts)
		pr.claims = { { readyAt = 5000, bundles = bundles } }
		local d0, w0 = Settle.claim(pr, 4000)
		check("insurance return waits for the delay", d0 == 0 and w0 == #bundles)
		local d1, w1 = Settle.claim(pr, 6000)
		check("insurance return delivered to the stash", d1 == #bundles and w1 == 0 and pr.items[wg] ~= nil and pr.items[wg].ins == nil and pr.items[wg].mag == magG and inv(pr))
	end

	-- M8: AI factions and loadouts
	if ctx and ctx.AI then
		local H = ctx.AI.hostileTo
		check("AI scavs ignore player scavs", H("scav", { s = { scav = true } }) == false)
		check("AI scavs fight a scav who turned on them", H("scav", { s = { scav = true, hostile = true } }) == true)
		check("AI scavs fight PMCs", H("scav", { s = { scav = false } }) == true)
		check("Harbor Watch fights player scavs", H("watch", { s = { scav = true } }) == true)
		check("same-faction AI are friends", H("scav", { unit = { faction = "scav" } }) == false and H("watch", { unit = { faction = "watch" } }) == false)
		check("AI never fight each other (Watch/scav truce)", H("watch", { unit = { faction = "scav" } }) == false and H("scav", { unit = { faction = "watch" } }) == false)
		local function loaded(h)
			local wg = h.slots.primary or h.slots.holster
			local w = wg and h.items[wg]
			local m = w and (w.mag and h.items[w.mag] or w)
			return m ~= nil and (m.a or 0) > 0 and m.at ~= nil
		end
		local function spareMags(h)
			local wg = h.slots.primary
			local w = wg and h.items[wg]
			local n = 0
			for g, it in h.items do
				local d = Items.defs[it.id]
				if d.kind == "mag" and w and g ~= w.mag and d.family == Items.defs[w.id].family then
					n += 1
				end
			end
			return n
		end
		local g = Loot.guardLoadout(Random.new(3))
		local b = Loot.bossLoadout(Random.new(4))
		local c = Loot.crewLoadout(Random.new(5))
		check("guard loadout valid and loaded", inv(g) and loaded(g) and spareMags(g) >= 1)
		check("boss loadout valid, loaded, heavy armour", inv(b) and loaded(b) and spareMags(b) == 3 and b.items[b.slots.armor].id == "ARMOR_C5" and b.slots.holster ~= nil)
		check("crew loadout valid and loaded", inv(c) and loaded(c) and spareMags(c) >= 2)
		check("ai skills defined", ctx.AI.SKILL.scav.spread > ctx.AI.SKILL.watch.spread and ctx.AI.SKILL.watch.spread > ctx.AI.SKILL.boss.spread)
	end

	-- M9: progression, traders, tasks, hideout, run-through
	do
		local P = require(Shared.Progress)
		local TD = require(Shared.TraderData)
		local QD = require(Shared.QuestData)
		local HD = require(Shared.HideoutData)
		check("xp curve", P.levelOf(0) == 1 and P.levelOf(999) == 1 and P.levelOf(1000) == 2 and P.xpFor(3) > P.xpFor(2))
		check("EFT's level table (economy-4b): 79 levels, level 15 at 177,337, the top at 172,016,256; nothing past it",
			P.MAX_LEVEL == 79 and P.xpFor(15) == 177337 and P.xpFor(79) == 172016256 and P.xpFor(90) == 172016256 and P.levelOf(177336) == 14
				and P.levelOf(177337) == 15 and P.levelOf(10 ^ 9) == 79 and math.abs(P.xpRatio(1) - 1) < 1e-9 and P.xpRatio(30) > 20)
		do
			-- a lost raid keeps 75 % of its experience (EFT 1.0.2.0); a survived one adds the extraction bonus; tasks keep the
			-- share of a level they gave on the old curve (V1 at level 1: 500, as before; V2 at level 2: 1,200 x 1.65 -> 2,000)
			local pk = { karma = 0, xp = 0, level = 1, skills = {} }
			local ok1, gK = pcall(ctx.Economy.afterRaid, nil, pk, { scav = false, xp = 1000 }, "KIA", false)
			local ok2, gM = pcall(ctx.Economy.afterRaid, nil, pk, { scav = false, xp = 1000 }, "MIA", false)
			local ok3, gS = pcall(ctx.Economy.afterRaid, nil, pk, { scav = false, xp = 1000 }, "SUCCESS", false)
			check("raid experience: 75 % kept after death or MIA, +300 for a survived raid; a head kill x1.2; task rewards on EFT's table",
				ok1 and ok2 and ok3 and gK == 750 and gM == 750 and gS == 1300 and P.XP.headshot == 0.2 and QD.byId.V1.reward.xp == 500
					and QD.byId.V2.reward.xp == 2000)
		end
		check("skill levels (Tarkov: level n costs min(10n, 100), elite at 51)", P.skillLevel(0) == 0 and P.skillLevel(10) == 1 and P.skillLevel(29) == 1 and P.skillLevel(30) == 2 and P.skillLevel(550) == 10 and P.skillLevel(4649) == 50 and P.skillLevel(4650) == 51 and P.skillLevel(99999) == 51 and math.abs(P.bonus({ endurance = 550 }, "endurance") - 0.06) < 1e-6)
		local fk = {} -- a fresh key every run: the fatigue table lives for the whole server, so a fixed key failed on a second run
		local m1 = ctx.Economy.fatigueMul(fk, "endurance", 0)
		local _, ff = ctx.Economy.fatigueMul(fk, "endurance", 0)
		ff.n, ff.fresh = 3, false
		local m3 = ctx.Economy.fatigueMul(fk, "endurance", 10)
		local m4 = ctx.Economy.fatigueMul(fk, "endurance", 300)
		check("skill fatigue: 129% fresh, 36% after three points, 100% after 200 s idle", math.abs(m1 - 1.29) < 1e-9 and math.abs(m3 - 0.36) < 1e-9 and m4 == 1)
		local rifle = TD.offers.vos[1]
		check("loyalty opens goods, prices stay (EFT)", TD.price("vos", rifle, 2) == TD.price("vos", rifle, 1) and TD.price("vos", rifle, 1) > Items.defs[rifle.id].value)
		-- (6.2 rounds are the Peacekeeper role's, DEKKER's, since economy-2a)
		local fmj = nil
		for _, o in TD.offers.dekker do
			if o.id == "A62_FMJ" then
				fmj = o
			end
		end
		check("ammo offers sell a stack", fmj ~= nil and fmj.n == 60 and TD.price("dekker", fmj, 1) == math.ceil(Items.defs["A62_FMJ"].value * 60 * TD.defs.dekker.markup))
		local chain = { id = "GOLD_CHAIN", n = 1 }
		local who, price = TD.bestBuyer(chain, 0)
		check("best buyer for valuables", who == "hale" and price == math.floor(Items.defs.GOLD_CHAIN.value * 0.5))
		check("quest items are not sold", TD.bestBuyer({ id = "LEDGER", n = 1 }, 0) == nil)
		-- audit economy.6 and .8: Charisma is 0.1 % a level off repairs (not trader prices); the Sealed Drive has a task
		local worn = { id = "R17_RIFLE", n = 1, wear = 60, wmax = 90 }
		local _, c0 = TD.repairQuote("vos", worn)
		local _, c1 = TD.repairQuote("vos", worn, 0.05)
		check("charisma: repairs cost less with it, trader prices ignore it", c0 ~= nil and c1 ~= nil and c1 < c0 and P.SKILLS.charisma.per == 0.001
			and TD.price("vos", rifle, 1) == TD.price("vos", rifle, 1, nil))
		local drive = false
		for _, q in QD.list do
			for _, o in q.obj do
				if o.kind == "handin" and o.item == "SEALED_DRIVE" then
					drive = true
				end
			end
		end
		check("the Sealed Drive is wanted by a task", drive)
		check("fence pays more with good karma", TD.sellPrice("fence", chain, 3) > TD.sellPrice("fence", chain, -3))
		check("dog tags are worth more for veterans", Items.valueOf({ id = "DOGTAG", n = 1, tag = { lvl = 10 } }) > Items.valueOf({ id = "DOGTAG", n = 1, tag = { lvl = 1 } }))
		-- data consistency
		local okData = true
		for _, q in QD.list do
			for _, o in q.obj do
				if o.kind == "handin" and not Items.defs[o.item] then
					okData = false
				end
			end
			for _, e in (q.reward and q.reward.items) or {} do
				okData = okData and Items.defs[e[1]] ~= nil
			end
			okData = okData and (q.after == nil or QD.byId[q.after] ~= nil) and TD.defs[q.trader] ~= nil
		end
		for _, r in HD.recipes do
			okData = okData and Items.defs[r.get[1]] ~= nil and HD.modules[r.module] ~= nil
			for _, e in r.give do
				okData = okData and Items.defs[e[1]] ~= nil
			end
		end
		check("economy data references valid items", okData)
		-- run-through keeps the loot but not found-in-raid
		local pr = Settle.newProfile()
		local raid = Settle.deploy(pr, "RT1", 3000)
		local lg, lit = Inv.newItem("GOLD_CHAIN", 1)
		lit.fip = true
		Inv.place(raid, lg, lit, Inv.loadOrder(raid))
		local rc = Settle.finalize(pr, "RT1", "SUCCESS", raid, 3100, { runThrough = true })
		check("run-through: loot kept, not found-in-raid", rc ~= nil and rc.runThrough == true and pr.items[lg] ~= nil and pr.items[lg].fir == nil and inv(pr))
		if ctx and ctx.Economy and ctx.Quests and ctx.Hideout then
			local E = ctx.Economy
			local p2 = Settle.newProfile()
			check("loyalty starts at 1", E.loyalty(p2, "vos") == 1)
			local r2 = TD.loyaltyReq("vos", 2)
			p2.xp = P.xpFor(r2.level)
			E.standing(p2, "vos").rep = r2.rep
			check("loyalty 2 at EFT 1.1.0's level and standing, no money asked", E.loyalty(p2, "vos") == 2)
			check("give and consume stash items", E.giveStash(p2, "BOLTS", 3) and select(2, E.stashItems(p2, "BOLTS")) == 3 and E.consumeStash(p2, "BOLTS", 2) and select(2, E.stashItems(p2, "BOLTS")) == 1 and inv(p2))
			local wg = nil
			for g, it in p2.items do
				if it.id == "R17_MAG" and Inv.locate(p2, g) == "grid" then
					wg = g
				end
			end
			local qp, qt = E.quote(p2, wg)
			check("quote sells a magazine to the quartermaster", qp ~= nil and qt == "vos")
			-- tasks
			local Q = ctx.Quests
			local q1 = QD.byId.V1
			check("first task available, follow-up locked", Q.status(p2, q1) == "available" and Q.status(p2, QD.byId.V2) == "locked")
			p2.quests.V1 = { s = "active", p = { ["1"] = 5 } }
			check("kill task complete at 5/5", Q.complete(p2, q1))
			local h1 = QD.byId.H1
			p2.quests.H1 = { s = "active", p = {} }
			check("hand-in needs found-in-raid items", not Q.complete(p2, h1))
			for _ = 1, 2 do
				local g, it = Inv.newItem("BANDAGE", 1)
				it.fir = true
				Inv.place(p2, g, it, { "stash" })
			end
			local mg, mit = Inv.newItem("MEDKIT_S", 1)
			mit.fir = true
			Inv.place(p2, mg, mit, { "stash" })
			check("hand-in complete with FIR items in the stash", Q.complete(p2, h1))
			-- hideout build finishing offline
			p2.hideout.build = { m = "storage", l = 1, at = 0 }
			ctx.Hideout.settle(p2, nil)
			check("a build finishes offline: old storage racks 1 -> stash 2 (10x40, decision economy-7b)", p2.hideout.levels.stash == 2 and p2.stashH == 40 and Inv.dims(p2, "stash") == 10 and select(2, Inv.dims(p2, "stash")) == 40)
		end
	end

	-- M10 raid environment: clock, daylight, rolls, AI sense multipliers, loadout lights
	do
		local Env = require(Shared.Env)
		local e = { clock0 = 17.0, w = "rain", rain = 1, t0 = 1000 }
		check("raid clock runs 7x", math.abs(Env.clock(e, 1000 + 3600 / 7) - 18.0) < 1e-6)
		check("raid clock wraps midnight", math.abs(Env.clock({ clock0 = 23.5, w = "clear", rain = 0, t0 = 0 }, 3600 / 7) - 0.5) < 1e-6)
		check("daylight: noon 1, midnight 0, dusk between", Env.daylight(12) == 1 and Env.daylight(0) == 0 and Env.daylight(18) > 0 and Env.daylight(18) < 1)
		local rng = Random.new(5)
		local okRolls, seenRain, seenNight = true, false, false
		for _ = 1, 300 do
			local r = Env.roll(rng)
			okRolls = okRolls and Env.WEATHER[r.w] ~= nil and r.clock0 >= 0 and r.clock0 < 24 and ((r.w == "rain") == (r.rain > 0))
			seenRain = seenRain or r.w == "rain"
			seenNight = seenNight or Env.daylight(r.clock0) == 0
		end
		check("env rolls valid (weather, clock, rain only when raining)", okRolls and seenRain and seenNight)
		local day = { clock0 = 12, w = "clear", rain = 0, t0 = 0 }
		local night = { clock0 = 1, w = "clear", rain = 0, t0 = 0 }
		local fog = { clock0 = 12, w = "fog", rain = 0, t0 = 0 }
		check("AI sight: day > fog > night", Env.sight(day, 0) == 1 and Env.sight(fog, 0) < 1 and Env.sight(night, 0) < Env.sight(fog, 0))
		check("AI hearing dulled by rain only", Env.hearing(day) == 1 and Env.hearing(e) < 1 and Env.hearing(nil) == 1)
		local lit = 0
		for i = 1, 20 do
			local gh = Loot.crewLoadout(Random.new(i))
			local wg = gh.slots.primary
			if wg and Inv.modStats(gh, wg).light then
				lit += 1
			end
			local okInv = Inv.check(gh)
			if not okInv then
				lit = -100
				break
			end
		end
		check("crew weapons carry lights (valid kits)", lit > 5)
	end

	-- M10 world: loose loot spots and pools, doors and keys
	if ctx and ctx.World then
		local W = ctx.World
		local nSpots, badSpot = 0, nil
		for _, sp in W.looseSpots or {} do
			nSpots += 1
			if not Loot.POOLS[sp.tbl] or type(sp.chance) ~= "number" then
				badSpot = sp.tbl
			end
		end
		check("loose spots placed with valid pools", nSpots >= 40 and badSpot == nil)
		local badItem = nil
		for name, pool in Loot.POOLS do
			for _, e in pool do
				if not Items.defs[e.id] then
					badItem = name .. ":" .. tostring(e.id)
				end
			end
		end
		check("every loot pool item exists", badItem == nil)
		local dorm, keyed, okKeys = 0, 0, true
		for id, d in W.doors do
			if string.sub(id, 1, 4) == "DORM" then
				dorm += 1
			end
			if d.key and (d.map == nil or d.map == "quay7") then
				keyed += 1
				okKeys = okKeys and Items.defs[d.key] ~= nil and Items.defs[d.key].kind == "key"
			end
		end
		checkOn("quay7", "dormitory has 8 doors, locked ones need real keys", dorm == 8 and keyed == 4 and okKeys)
		checkOn("quay7", "vault opens with the keycard", W.doors.VAULT and W.doors.VAULT.key == "RUSTED_KEYCARD" and W.doors.VAULT.card == true)
		local rand = Random.new(3)
		local sawKey = false
		for _ = 1, 60 do
			local _, it = Loot.rollEntry(rand, "keys")
			sawKey = sawKey or (it and Items.defs[it.id].kind == "key")
		end
		check("key spots roll keys", sawKey)
	end

	-- M11 grenades: physics, aiming, fragments, flash, smoke, picking, items and sources
	do
		local GR = require(Shared.Grenades)
		-- flat floor at y = 0 and a 6-stud wall at x = 30 (normal -x)
		local function ray(o, d)
			local best, bp, bn = math.huge, nil, nil
			local L = d.Magnitude
			local u = d / L
			if u.Y < -1e-6 then
				local sdist = -o.Y / u.Y
				if sdist >= 0 and sdist <= L and sdist < best then
					best, bp, bn = sdist, o + u * sdist, Vector3.yAxis
				end
			end
			if u.X > 1e-6 then
				local sdist = (30 - o.X) / u.X
				local hp = o + u * sdist
				if sdist >= 0 and sdist <= L and sdist < best and hp.Y < 6 then
					best, bp, bn = sdist, hp, -Vector3.xAxis
				end
			end
			return bp, bn
		end
		local level = GR.simulate(Vector3.new(0, 5.3, 0), GR.launch(Vector3.new(0, 0, -1), false), 3.5, ray)
		check("grenade lands, rolls and comes to rest on the floor", level.rest and math.abs(level.final.Y - GR.RADIUS) < 0.05 and level.land ~= nil and level.endT < 3.5)
		check("level overhand throw carries 25-60 studs", (level.final * Vector3.new(1, 0, 1)).Magnitude > 25 and (level.final * Vector3.new(1, 0, 1)).Magnitude < 60)
		local under = GR.simulate(Vector3.new(0, 3.7, 0), GR.launch(Vector3.new(0, 0, -1), true), 3.5, ray)
		check("underhand throw is short", (under.final * Vector3.new(1, 0, 1)).Magnitude < level.final.Magnitude * 0.6 and under.rest)
		local wall = GR.simulate(Vector3.new(0, 3, 0), Vector3.new(50, 2, 0), 3.5, ray)
		check("a throw into a wall bounces back", wall.final.X < 30 - GR.RADIUS and #wall.b >= 1)
		local okMono = true
		for i = 2, #level.t do
			okMono = okMono and level.t[i] >= level.t[i - 1]
		end
		check("path samples ordered and bounded", okMono and #level.t <= GR.MAX_SAMPLES + 1)
		local mid = GR.at(level, level.t[3] * 0.5 + level.t[2] * 0.5)
		check("path interpolation between samples", (mid - level.p[2]:Lerp(level.p[3], 0.5)).Magnitude < 1e-3 and GR.at(level, 99) == level.final)
		local from, to = Vector3.new(0, 5, 0), Vector3.new(0, 0.2, -40)
		local okAim = true
		for _, high in { false, true } do
			local dir = GR.aim(from, to, 60, high)
			if not dir then
				okAim = false
			else
				local pth = GR.simulate(from, dir * 60, 8, function(o, d)
					local L = d.Magnitude
					local u = d / L
					if u.Y < -1e-6 then
						local sd = -o.Y / u.Y
						if sd >= 0 and sd <= L then
							return o + u * sd, Vector3.yAxis
						end
					end
					return nil, nil
				end)
				okAim = okAim and pth.land ~= nil and (GR.at(pth, pth.land) - to).Magnitude < 2.5
			end
		end
		check("lob and flat solutions both land on the target", okAim and GR.aim(from, Vector3.new(0, 0, -900), 60, false) == nil)
		local near = GR.fragLambda(190, 2, 4)
		check("fragment hits fall off with distance", near > GR.fragLambda(190, 2, 8) * 3.5 and GR.fragLambda(190, 2, 0.1) == GR.fragLambda(190, 2, 1.2))
		local prng, sum = Random.new(11), 0
		for _ = 1, 4000 do
			sum += GR.poisson(prng, 1.7)
		end
		check("fragment counts average the expected value", math.abs(sum / 4000 - 1.7) < 0.12)
		local stunSpec = Items.defs.GREN_STUN.nade
		check("stun: facing it blinds more than looking away, walls stop it", GR.blind(stunSpec, 8, 0.9, true) > GR.blind(stunSpec, 8, -0.9, true) * 3 and GR.blind(stunSpec, 8, 0.9, false) == 0 and GR.blind(stunSpec, 30, 1, true) == 0)
		local sm = Items.defs.GREN_SMOKE.nade
		local r0 = GR.cloud(sm, 0.5)
		local r1, d1 = GR.cloud(sm, 10)
		local _, dEnd = GR.cloud(sm, sm.smokeT + 9)
		check("smoke cloud grows, holds and clears", r1 > r0 and d1 == 1 and dEnd == 0)
		local c = Vector3.new(0, 4, 0)
		check("smoke blocks sight through it, not past it", GR.segmentInCloud(Vector3.new(-40, 4, 0), Vector3.new(40, 4, 0), c, r1, 1)
			and not GR.segmentInCloud(Vector3.new(-40, 4, 30), Vector3.new(40, 4, 30), c, r1, 1)
			and GR.segmentInCloud(Vector3.new(0, 4, 0), Vector3.new(40, 4, 0), c, r1, 1))
		-- quick throw takes the rig first, then pockets, never the backpack
		local h = Inv.newHolder("raid")
		local function slot(name, id)
			local g, it = Inv.newItem(id, 1)
			Inv.placeSlot(h, g, it, name)
			return g
		end
		local rig = slot("rig", "RIG_CHEST")
		local back = slot("back", "BAG_PATROL")
		local gb, ib = Inv.newItem("GREN_F7", 1)
		Inv.place(h, gb, ib, { back })
		check("no grenade outside the backpack: nothing to throw", GR.pick(h, Items.defs) == nil)
		local gp, ip = Inv.newItem("GREN_SMOKE", 1)
		Inv.place(h, gp, ip, { "pockets" })
		local gr, ir = Inv.newItem("GREN_RK5", 1)
		Inv.place(h, gr, ir, { rig })
		check("quick throw picks the rig before the pockets", GR.pick(h, Items.defs) == gr and GR.pick(h, Items.defs, { smoke = true }) == gp)
		local okDefs, sold, inLoot = true, {}, {}
		for id, d in Items.defs do
			if d.kind == "grenade" then
				okDefs = okDefs and d.nade and (d.nade.fuse or 0) > 0 and (d.nade.type ~= "frag" or (d.nade.frags > 0 and d.nade.fragR > d.nade.blastR))
			end
		end
		local TD = require(Shared.TraderData)
		for _, o in TD.offers.vos do
			sold[o.id] = true
		end
		for _, pool in Loot.POOLS do
			for _, e in pool do
				inLoot[e.id] = true
			end
		end
		check("grenades defined, sold by VOS and found in loot", okDefs and sold.GREN_RK5 and sold.GREN_F7 and sold.GREN_STUN and sold.GREN_SMOKE and inLoot.GREN_RK5 and inLoot.GREN_F7 and inLoot.GREN_SMOKE)
		check("VOS buys grenades and repair kits", TD.sellPrice("vos", { id = "GREN_RK5", n = 1 }) ~= nil and TD.sellPrice("vos", { id = "WEAPON_KIT", n = 1, pts = 150 }) ~= nil)
		local bossNades, guardNades = 0, 0
		for i = 1, 20 do
			local bh = Loot.bossLoadout(Random.new(i))
			local gh = Loot.guardLoadout(Random.new(100 + i))
			for _, it in bh.items do
				if Items.defs[it.id].kind == "grenade" then
					bossNades += 1
				end
			end
			for _, it in gh.items do
				if Items.defs[it.id].kind == "grenade" then
					guardNades += 1
				end
			end
		end
		check("the Foreman always carries grenades, guards often", bossNades >= 60 and guardNades >= 6)
		local HD = require(Shared.HideoutData)
		check("grenade and repair kit crafts", HD.byRecipe.NADE_RK5 ~= nil and HD.byRecipe.GUN_KIT ~= nil and Items.defs[HD.byRecipe.GUN_KIT.get[1]].kind == "repair")
	end

	-- weapon mastering (Tarkov; docs/design/MASTERING.md): levels at the group's thresholds (running totals), points only
	-- into a known group, a level-up reported once, reloading while aiming from level 3, saved with the profile
	do
		local P = require(Shared.Progress)
		check("mastering: every weapon group in the order, thresholds rising", #P.MASTERY_ORDER == 29 and (function()
			for _, gid in P.MASTERY_ORDER do
				local g = P.MASTERING[gid]
				if not (g and g.level2 > 0 and g.level3 > g.level2 and P.MASTERY_OF[g.weapons[1]] == gid) then
					return false
				end
			end
			return true
		end)())
		check("mastering: Tarkov's M4 thresholds on the R-17 (1600 / 2000)", P.masteryLevel("R17", 1599) == 1 and P.masteryLevel("R17", 1600) == 2
			and P.masteryLevel("R17", 1999) == 2 and P.masteryLevel("R17", 2000) == 3 and P.masteryLevel("R17", nil) == 1)
		local l1, a1, b1 = P.masteryProgress("P9", 10)
		local l3, a3, b3 = P.masteryProgress("P9", 500)
		check("mastering: the bar runs from the level's start to the next level, full at 3", l1 == 1 and a1 == 0 and b1 == 75 and l3 == 3 and a3 == 100 and b3 == 100)
		check("mastering: the knife and unknown weapons have none", P.masteryFor({}, "KNIFE") == 0 and P.masteryFor(nil, "R17") == 1)
		if ctx and ctx.Economy and ctx.Combat then
			local prof = {}
			Settle.progressFields(prof)
			check("mastering: a fresh profile starts with no points", type(prof.mastering) == "table" and next(prof.mastering) == nil)
			check("mastering: a point into an unknown group or a bad amount is refused", ctx.Economy.mastery(prof, "NOPE", 1) == false
				and ctx.Economy.mastery(prof, "P9", 0) == false and ctx.Economy.mastery(prof, "P9", -3) == false and prof.mastering.P9 == nil)
			local ups = 0
			for _ = 1, 74 do
				if ctx.Economy.mastery(prof, "P9", 1) then
					ups += 1
				end
			end
			check("mastering: no level-up before the threshold", ups == 0 and prof.mastering.P9 == 74 and not ctx.Combat.aimReload(prof, "P9"))
			check("mastering: the 75th hit levels the P-9 up once", ctx.Economy.mastery(prof, "P9", 1) == true and ctx.Economy.mastery(prof, "P9", 1) == false)
			ctx.Economy.mastery(prof, "P9", 30)
			check("mastering: level 3 lets the group reload while aiming, other groups not", ctx.Combat.aimReload(prof, "P9") and not ctx.Combat.aimReload(prof, "R17"))
		end
	end

	-- THE STOKER (Meridian's second boss, our Tagilla): Meridian rolls two bosses on their own; his kit and his look
	if ctx and ctx.World and ctx.Loot then
		local mm = ctx.World.maps and ctx.World.maps.meridian
		local bl = mm and mm.bosses
		local care, stok = bl and bl[1], bl and bl[2]
		checkOn("meridian", "stoker: Meridian has two bosses, each with its own chance (the Caretaker 60 %, the Stoker 35 %)",
			bl ~= nil and #bl == 2 and care.label == "Caretaker" and care.chance == 0.6 and stok.label == "Stoker" and stok.chance == 0.35,
			bl and #bl)
		checkOn("meridian", "stoker: he charges with the hammer, has Tagilla's 1,220 health (x 2.77) and his garage route",
			stok ~= nil and stok.charge == true and math.abs(stok.hp * 440 - 1220) < 0.5 and stok.route ~= nil and #stok.route >= 3)
		local h = ctx.Loot.stokerLoadout(Random.new(7))
		local function at(slot)
			local g = h.slots[slot]
			return g and h.items[g] and h.items[g].id
		end
		check("stoker: his kit is the welding mask (face cover, class 5 for the face), a class 6 carrier and a 12 gauge; no helmet",
			at("face") == "MASK_WELDER" and at("armor") == "ARMOR_C6" and at("primary") == "HARROW12" and at("head") == nil
				and Items.defs.MASK_WELDER.armor.class == 5 and Items.defs.MASK_WELDER.armor.zones.face == true)
		local Equipment = require(game:GetService("ReplicatedStorage").ZR.Equipment)
		check("stoker: he has a look of his own", Equipment.LOOKS.stoker ~= nil and Equipment.lookKey("stoker") == "stoker")
	end

	-- THE HOUNDS (Border Yard's roaming trio, our Goons): a second boss group beside the Broker, three men of their own
	if ctx and ctx.World and ctx.Loot then
		local bm = ctx.World.maps and ctx.World.maps.border
		local bl = bm and bm.bosses
		local hb = bl and bl[2]
		checkOn("border", "hounds: Border Yard rolls the Broker and THE HOUNDS on their own (Tarkov's Goons: 20 % on Customs)",
			bl ~= nil and #bl >= 2 and bl[1].label == "Broker" and hb.label == "Halberd" and hb.chance == 0.2, bl and #bl)
		local crewOk = hb ~= nil and #hb.crew == 2 and hb.crew[1].label == "Mortar" and hb.crew[2].label == "Kestrel"
			and typeof(hb.crew[1].pos) == "Vector3" and typeof(hb.crew[2].pos) == "Vector3"
		checkOn("border", "hounds: HALBERD leads MORTAR and KESTREL, each with Tarkov's health (1,120, 910, 795) and the boss's skill",
			crewOk and math.abs(hb.hp * 440 - 1120) < 0.5 and math.abs(hb.crew[1].hp * 440 - 910) < 0.5 and math.abs(hb.crew[2].hp * 440 - 795) < 0.5
				and hb.skill == "boss" and hb.crew[1].skill == "boss" and hb.crew[2].skill == "boss")
		checkOn("border", "hounds: they walk a loop of the map from the Bastion (10 points)", hb ~= nil and #hb.route == 10 and typeof(hb.home) == "Vector3")
		local function at(h, slot)
			local g = h.slots[slot]
			return g and h.items[g] and h.items[g].id
		end
		local function count(h, ids)
			local n = 0
			for _, it in h.items do
				if ids[it.id] then
					n += 1
				end
			end
			return n
		end
		-- every seed: the whole kit fits (no spare magazine, grenade or med left out), five double pockets, a sound holder
		local kitsOk, why = true, nil
		for seed = 1, 40 do
			local hh, hm, hk = ctx.Loot.halberdLoadout(Random.new(seed)), ctx.Loot.mortarLoadout(Random.new(seed)), ctx.Loot.kestrelLoadout(Random.new(seed))
			-- (at least: the loot rolls on top may add a magazine, a grenade or a med of their own)
			local fits = count(hh, { R17_MAG = true }) >= 4 and count(hh, { P9_MAG = true }) >= 2 and count(hh, { MEDKIT_L = true }) >= 1
				and count(hm, { KST_MAG = true }) >= 2 and count(hm, { A40_HE = true }) >= 4 and count(hm, { GREN_F7 = true, GREN_RK5 = true }) >= 2
				and count(hm, { MEDKIT_L = true, SPLINT = true }) >= 2
				and count(hk, { R17_MAG = true }) >= 5 and count(hk, { GREN_SMOKE = true }) >= 2 and count(hk, { MEDKIT_M = true }) >= 1
			for _, h in { hh, hm, hk } do
				local okH, err = Inv.check(h)
				if not okH or h.pocketsW ~= 5 or h.pocketsH ~= 2 then
					fits, why = false, err or "pockets"
				end
			end
			if not fits then
				kitsOk, why = false, "seed " .. seed .. " " .. tostring(why or "a kit item left out")
				break
			end
		end
		check("hounds: their kits fit whole in five double pockets (Tarkov's Goons), every seed", kitsOk, why)
		local hh, hm, hk = ctx.Loot.halberdLoadout(Random.new(5)), ctx.Loot.mortarLoadout(Random.new(5)), ctx.Loot.kestrelLoadout(Random.new(5))
		check("hounds: HALBERD class 5, a goggle mount and an AR, MORTAR with no head armour, the GL-6 and his rifle (ai-5b), KESTREL a class 4 vest, chest rig, frame pack and DMR",
			at(hh, "primary") == "R17_RIFLE" and at(hh, "armor") == "ARMOR_C5" and at(hh, "head") == "NV_STRAP" and at(hh, "face") == "GAITER"
				and at(hm, "primary") == "GL6_LAUNCHER" and at(hm, "secondary") == "KST_RIFLE" and at(hm, "head") == "BEANIE" and Items.defs.BEANIE.armor == nil
				and at(hk, "primary") == "R17_RIFLE" and at(hk, "armor") == "ARMOR_C4" and at(hk, "rig") == "RIG_CHEST" and at(hk, "back") == "BAG_PATROL")
		-- a double pocket takes a 1 x 2 upright and refuses one lying across two pockets
		local hp = Inv.newHolder("raid")
		hp.pocketsW, hp.pocketsH = 5, 2
		local g1, it1 = Inv.newItem("MEDKIT_L", 1)
		local placed = Inv.place(hp, g1, it1, { "pockets" })
		local _, _, p1 = Inv.locate(hp, g1)
		local w1 = p1 and select(1, Grid.dims(1, 2, p1.r))
		local g2, it2 = Inv.newItem("BAG_SLING", 1)
		check("hounds: a double pocket holds a 1 x 2 upright, refuses a 2 x 2", placed and w1 == 1 and not Inv.place(hp, g2, it2, { "pockets" }))
		local Eq = require(game:GetService("ReplicatedStorage").ZR.Equipment)
		check("hounds: each of the three has a look of his own",
			Eq.lookKey("halberd") == "halberd" and Eq.lookKey("mortar") == "mortar" and Eq.lookKey("kestrel") == "kestrel")
	end

	-- THE CULT (Border Yard's night group, Tarkov's cultists): the group, its rules, the knife, the toxin, the antidote, kits
	if ctx and ctx.World and ctx.Loot and ctx.AI and ctx.Health then
		local bl = ctx.World.maps.border and ctx.World.maps.border.bosses
		local cult = nil
		for _, b in bl or {} do
			if b.label == "Priest" then
				cult = b
			end
		end
		local zonesOk = cult ~= nil and #cult.zones == 3
		for _, z in cult and cult.zones or {} do
			local optional = 0
			for _, w in z.crew do
				zonesOk = zonesOk and w.ambush == true and w.charge == "knife" and w.post == true and typeof(w.pos) == "Vector3"
				if w.chance then
					optional += 1
				end
			end
			zonesOk = zonesOk and #z.crew == 4 and optional == 2 and typeof(z.post) == "Vector3"
		end
		checkOn("border", "cult: Border rolls THE CULT at 20 % in night raids only, in three zones, two to four warriors lying in wait",
			cult ~= nil and cult.chance == 0.2 and cult.night == true and math.abs(cult.hp * 440 - 850) < 0.5 and zonesOk)
		local K, H = ctx.AI.MELEE and ctx.AI.MELEE.knife, ctx.AI.MELEE and ctx.AI.MELEE.hammer
		check("cult: the knife charge is shorter and quicker than the hammer, poisons, and leaves the hammer as it was",
			K ~= nil and H ~= nil and K.toxin == true and K.range < H.range and K.every < H.every and H.dmg == 110 and not H.toxin)
		-- a hit with the poisoned blade poisons; the toxin shows and shakes the aim; the antidote is a one-use injector
		local poisoned, shown = false, false
		local okR, rig = pcall(ctx.Chars.buildRig, "cultist", 1)
		if okR and rig then
			ctx.Health.attach(rig, { kind = "ai", holder = function()
				return { slots = {}, items = {}, grids = {} }
			end })
			local hsR = ctx.Health.get(rig)
			ctx.Health.hit(rig, { dmg = 12, pen = 0, part = rig:FindFirstChild("UpperTorso"), toxin = true, bleedL = 0, bleedH = 0 })
			poisoned = hsR ~= nil and hsR.toxin ~= nil
			if hsR then
				local v = ctx.Health.vitals(hsR)
				for _, e in v.effects do
					shown = shown or e.label == "POISONED"
				end
				shown = shown and v.mods.tremor > 0
			end
			rig:Destroy()
		end
		local ad = Items.defs.ANTIDOTE
		check("cult: the knife poisons, POISONED shows and the aim trembles; the antidote injector cures it",
			poisoned and shown and ad ~= nil and ad.kind == "med" and ad.med.antidote == true and ad.med.uses == 1)
		local function count(h, id)
			local n = 0
			for _, it in h.items do
				if it.id == id then
					n += 1
				end
			end
			return n
		end
		local c1, pr = ctx.Loot.cultistLoadout(Random.new(4)), ctx.Loot.priestLoadout(Random.new(4))
		local g = c1.slots.primary
		check("cult: robes and no armour, a suppressed SMG; the priest carries the ritual knife",
			g ~= nil and c1.items[g].id == "SPARROW_SMG" and count(c1, "SUPP_9") == 1 and c1.slots.armor == nil and count(pr, "RITUAL_KNIFE") >= 1
				and Inv.check(c1) and Inv.check(pr))
		local Eq = require(game:GetService("ReplicatedStorage").ZR.Equipment)
		check("cult: the warriors and the priest look their own", Eq.lookKey("cultist") == "cultist" and Eq.lookKey("priest") == "priest")
	end

	-- THE FORESTER (Border Yard's lone trapper, Tarkov's Partisan): the boss, who he hunts, his roll, his kit, his tripwires
	if ctx and ctx.World and ctx.Loot and ctx.AI then
		local bl = ctx.World.maps.border and ctx.World.maps.border.bosses
		local fo = nil
		for _, b in bl or {} do
			if b.label == "Forester" then
				fo = b
			end
		end
		checkOn("border", "forester: Border rolls THE FORESTER alone at 20 %, 950 health, roaming an 8-point loop, silent, with 5 wires",
			fo ~= nil and fo.chance == 0.2 and math.abs(fo.hp * 440 - 950) < 0.5 and fo.roam == true and #fo.route == 8 and fo.crew == nil
				and fo.karmaHunt == true and fo.silent == true and fo.traps == 5)
		local A = ctx.AI
		check("forester: he hunts low karma; anyone else only close by (25 studs) or once they have hurt him",
			A.forestHostile(-0.5, nil, 200) and not A.forestHostile(0.2, nil, 200) and A.forestHostile(0.2, nil, 20)
				and A.forestHostile(0.2, true, 200) and not A.forestHostile(0, nil, nil))
		check("forester: each raider with low karma in the queue adds 10 % to his roll, up to 50 %",
			math.abs(A.forestChance(0.2, { 0.2, -0.5, -1 }) - 0.4) < 1e-9 and A.forestChance(0.2, { -1, -1, -1, -1, -1, -1 }) == 0.5
				and A.forestChance(0.2, {}) == 0.2)
		local fk = ctx.Loot.foresterLoadout(Random.new(7))
		local nades = 0
		for _, it in fk.items do
			if it.id == "GREN_F7" or it.id == "GREN_RK5" then
				nades += 1
			end
		end
		local pg = fk.slots.primary
		local pack = Items.defs.FORESTER_PACK
		check("forester: no armour and no helmet, his own pack (Tarkov's Partisan's bag: 4x3, 20 slots), a long gun, grenades",
			fk.slots.armor == nil and fk.items[fk.slots.head].id == "BEANIE" and fk.items[fk.slots.back].id == "FORESTER_PACK"
				and pg ~= nil and (fk.items[pg].id == "KST_RIFLE" or fk.items[pg].id == "HARROW12") and nades >= 2 and Inv.check(fk)
				and pack.w == 4 and pack.h == 3 and pack.grid.w * pack.grid.h == 20 and pack.mass == 0.7 and pack.pen.speed == -5)
		local Eq = require(game:GetService("ReplicatedStorage").ZR.Equipment)
		check("forester: his own look", Eq.lookKey("forester") == "forester")
		local TW = ctx.Tripwires
		if TW then
			local a, b = Vector3.new(0, 0, 0), Vector3.new(4, 0, 0)
			check("tripwire: a step across the wire or onto it sets it off; beside it or past its end does not",
				TW.crosses(a, b, Vector3.new(2, 3, -1), Vector3.new(2, 3, 1)) and TW.crosses(a, b, Vector3.new(2, 3, -2), Vector3.new(2, 3, -0.3))
					and not TW.crosses(a, b, Vector3.new(2, 3, -3), Vector3.new(2, 3, -1)) and not TW.crosses(a, b, Vector3.new(5, 3, -1), Vector3.new(5, 3, 1)))
			local e1, e2, side = TW.doorEnds(CFrame.new(), Vector3.new(4, 7, 0.35), 1)
			local f1, _, side2 = TW.doorEnds(CFrame.new(), Vector3.new(4, 7, 0.35), -1)
			check("tripwire: across a doorway at the sill, on the side the leaf does not swing to, in from the jambs",
				side == 1 and side2 == -1 and math.abs(e1.Z - 1) < 1e-6 and math.abs(f1.Z + 1) < 1e-6 and math.abs(e1.Y + 3.5) < 1e-6
					and math.abs(e2.X - e1.X - (4 - 2 * TW.CFG.inset)) < 1e-6)
			-- a wire laid in the showroom (far from every map): a shot that meets it sets it off (the grenade is held back)
			local origThrow = ctx.Grenades.throwFrom
			local savedStats = table.clone(TW.stats)
			local thrown = nil
			ctx.Grenades.throwFrom = function(_, origin, _, item)
				thrown = { origin = origin, item = item }
				return nil
			end
			local okP, t = pcall(TW.place, Vector3.new(0, 0, 1300), Vector3.new(4, 0, 1300), "GREN_RK5", nil)
			local shellOk, shotOk = false, false
			if okP and t then
				local shell = t.model:FindFirstChild("TripWire")
				shellOk = shell ~= nil and shell.CanQuery and shell.Transparency == 1 and t.model:FindFirstChild("Wire") ~= nil
					and #t.model.TrapPrompt:GetChildren() == 2
				local B2 = require(game:GetService("ReplicatedStorage").ZR.Ballistics)
				local keep = B2.through and B2.through({ Instance = shell, Position = t.mid }, Vector3.xAxis, true)
				shotOk = keep == 1 and not t.armed and thrown ~= nil and thrown.item == "GREN_RK5" and t.model:FindFirstChild("Stake") ~= nil
					and t.model:FindFirstChild("Wire") == nil
			end
			ctx.Grenades.throwFrom = origThrow
			TW.stats = savedStats
			for i = #TW.list, 1, -1 do
				if TW.list[i] == t then
					table.remove(TW.list, i)
				end
			end
			if okP and t and t.model then
				t.model:Destroy()
			end
			check("tripwire: two stakes, a wire and a hidden shell; a shot that meets the wire pulls the pin and flies on",
				okP and shellOk and shotOk)
		end
	end

	-- hideout style (Tarkov 0.16 customisation): walls, floor and ceiling options, the shell's own first, unlocked by level
	do
		local HS = require(Shared.HideoutStyle)
		local MS = game:GetService("MaterialService")
		local ok, missing = true, {}
		for _, cat in HS.CATS do
			local list = (HS :: any)[cat]
			local seen, last = {}, 0
			ok = ok and #list >= 4 and list[1].level == 1 and HS.default(cat) == list[1].id
			for _, o in list do
				ok = ok and not seen[o.id] and o.level >= last and HS.option(cat, o.id) == o
				seen[o.id], last = true, o.level
				for _, k in { "band", "line", "upper", "surface" } do
					local fin = o[k]
					if fin then
						ok = ok and Enum.Material[fin.mat] ~= nil and #fin.color == 6
						if fin.var ~= "" and not MS:FindFirstChild(fin.var, true) then
							table.insert(missing, fin.var)
						end
					end
				end
			end
		end
		check("hideout style: walls, floor and ceiling each start with the shell as built and unlock by level; every finish's material exists",
			ok and HS.unlocked(HS.walls[2], 5) and not HS.unlocked(HS.walls[2], 4) and HS.option("walls", "nope") == nil)
		check("hideout style: every MaterialVariant a finish names is in MaterialService" .. (#missing > 0 and (" (missing " .. table.concat(missing, ", ") .. ")") or ""),
			#missing == 0)
	end

	-- transits (Tarkov 0.15): Border Yard's to Meridian Mall and back, opening a minute in with a 20 s countdown (SPT)
	if ctx and ctx.World and ctx.Transit and ctx.World.maps.border and ctx.World.maps.meridian then
		local TR = ctx.Transit
		local function only(mid)
			local list = ctx.World.maps[mid].transits or {}
			return #list == 1 and list[1] or nil
		end
		local b, m = only("border"), only("meridian")
		check("transit: Border Yard has one to Meridian Mall and Meridian Mall one back, each a 16-stud zone with its sign",
			b ~= nil and m ~= nil and b.to == "meridian" and m.to == "border" and b.size.X == 16 and m.size.Z == 16 and b.sign ~= nil and m.sign ~= nil
				and TR.inside(b, b.pos + Vector3.new(0, 1, 0)) and not TR.inside(b, b.pos + Vector3.new(20, 1, 0)))
		check("transit: opens 60 s into the raid, 20 s countdown (SPT)", TR.CFG.openAfter == 60 and TR.CFG.timer == 20)
		local pmcList = m and TR.extractsFor("border", m.pos, false) or {}
		local scavList = b and TR.extractsFor("meridian", b.pos, true) or {}
		local carIn, pmcOnlyIn = false, false
		for _, id in scavList do
			local me = ctx.World.maps.meridian.extracts[id]
			carIn = carIn or ctx.Extract.isCar(me)
			pmcOnlyIn = pmcOnlyIn or (me.rule and me.rule.who == "pmc")
		end
		-- Interchange (reference section 9): a scav has the two corner exits and the co-op one; the car, the saferoom, the
		-- flare path and the fence hole are for PMCs
		check("transit: arriving, a PMC gets the nearest spawn's exits, a scav every exit a scav may use (not the car nor a PMC-only one)",
			#pmcList > 0 and #scavList == 3 and not carIn and not pmcOnlyIn)
		local mrp = ctx.World.maps.meridian.extracts.RP
		local other = ctx.World.activeMap ~= "meridian"
		check("transit: the exits of a map that is not in play keep their own keys in the raid's tables (map:id)",
			mrp ~= nil and ((other and ctx.Extract.key(mrp) == "meridian:RP") or (not other and ctx.Extract.key(mrp) == "RP")))
	end

	-- co-op exits (Tarkov's Boiler Room Basement): a PMC and a player scav in the zone together; the hold breaks when the
	-- partner leaves; both gain Fence standing (stand-in raiders: a rig in the zone as the partner)
	if ctx and ctx.World and ctx.Extract and ctx.Raid and ctx.Economy and ctx.World.maps.border then
		local EX = ctx.Extract
		local bc = ctx.World.maps.border.extracts and ctx.World.maps.border.extracts.BC
		local okRig, rig = pcall(ctx.Chars.buildRig, "scav", 1)
		local blockedAlone, blockedWith, holdWith, holdGone, sameSide = nil, nil, nil, nil, nil
		if bc and okRig and rig then
			rig.Parent = workspace
			rig:PivotTo(CFrame.new(bc.cf.Position + Vector3.new(0, 1, 0)))
			local pmc = { Character = nil }
			local sPmc = { scav = false, state = "ACTIVE", inv = { slots = {}, items = {}, grids = {} } }
			local partner = { Character = rig }
			local sScav = { scav = true, state = "ACTIVE" }
			local origSessions = ctx.Raid.sessions
			local fake = { [pmc] = sPmc }
			ctx.Raid.sessions = function()
				return fake
			end
			local okRun = pcall(function()
				blockedAlone = EX.blocked(pmc, sPmc, bc)
				fake[partner] = sScav
				blockedWith = EX.blocked(pmc, sPmc, bc)
				holdWith = EX.holdBlocked(sPmc, bc, pmc)
				sScav.scav = false -- another PMC is no partner
				sameSide = EX.blocked(pmc, sPmc, bc)
				sScav.scav = true
				rig:PivotTo(CFrame.new(bc.cf.Position + Vector3.new(bc.size.X + 20, 1, 0)))
				holdGone = EX.holdBlocked(sPmc, bc, pmc)
			end)
			ctx.Raid.sessions = origSessions
			rig:Destroy()
			if not okRun then
				blockedAlone = "ERROR"
			end
		end
		check("co-op exit: BOILER CELLAR needs a scav with the PMC; another PMC will not do; the hold stops when the scav leaves",
			bc ~= nil and bc.rule.kind == "coop" and blockedAlone == "COOP" and blockedWith == nil and holdWith == nil and sameSide == "COOP"
				and holdGone == "COOP")
		local P = require(Shared.Progress)
		local prof = { karma = 0.2, xp = 0, level = 1, skills = {} }
		-- (settled the same whatever the outcome; no player keeps the task hooks out of the stand-in)
		local okA = pcall(ctx.Economy.afterRaid, nil, prof, { scav = false, karmaDelta = P.KARMA.coop, xp = 0 }, "KIA", true)
		check("co-op exit: leaving together adds Fence standing to the PMC too (a scav's raid also adds its extract bonus)",
			okA and P.KARMA.coop > 0 and math.abs(prof.karma - (0.2 + P.KARMA.coop)) < 1e-9)
	end

	-- flare exits (Extract kind "flare"): the green flare; NORTH LINE and RIVER PATH open by flare; OLD PUMPS shows green
	-- flares while it is there (Tarkov's Railroad Passage, Smuggler's Tunnel and Old Gas Station)
	if ctx and ctx.World and ctx.Extract and ctx.Match and ctx.World.maps then
		local gd = Items.defs.FLARE_GREEN
		check("flare exits: the green signal flare (1 x 2, 0.19 kg) opens exits",
			gd ~= nil and gd.kind == "flare" and gd.flare.color == "green" and gd.flare.exit == true and gd.w == 1 and gd.h == 2
				and math.abs(gd.mass - 0.19) < 1e-6)
		local bx = ctx.World.maps.border and ctx.World.maps.border.extracts
		local mx = ctx.World.maps.meridian and ctx.World.maps.meridian.extracts
		local nl, op, rp = bx and bx.NL, bx and bx.OP, mx and mx.RP
		checkOn("border meridian", "flare exits: NORTH LINE and RIVER PATH open by flare; OLD PUMPS, a chance exit, sends up green flares",
			nl ~= nil and nl.rule.kind == "flare" and nl.rule.radius == 94 and rp ~= nil and rp.rule.kind == "flare"
				and op ~= nil and op.rule.kind == "chance" and op.rule.signal == "green")
		if nl then
			-- the rule on Border's exits: closed; a flare outside the area opens nothing; one inside opens it
			local W, M, X = ctx.World, ctx.Match, ctx.Extract
			local saved, savedOpen = W.extracts, table.clone(M.flareOpen)
			W.extracts = bx
			table.clear(M.flareOpen)
			local s = { inv = Inv.newHolder("raid") }
			local b0 = X.blocked(nil, s, nl)
			local far = X.openFlareAt(nl.pos + Vector3.new(120, 0, 0))
			local b1 = X.blocked(nil, s, nl)
			local near = X.openFlareAt(nl.pos + Vector3.new(40, 30, -20))
			local b2 = X.blocked(nil, s, nl)
			W.extracts = saved
			table.clear(M.flareOpen)
			for k, v in savedOpen do
				M.flareOpen[k] = v
			end
			check("flare exits: closed until a green flare goes up inside the signal area, then open",
				b0 == "FLARE" and #far == 0 and b1 == "FLARE" and #near == 1 and near[1] == "NORTH LINE" and b2 == nil,
				tostring(b0) .. "/" .. tostring(b1) .. "/" .. tostring(b2))
		end
	end

	-- airdrops (Services/Airdrop.luau): Tarkov's four crates, their pools, a full crate fits its 10 x 12 grid, the
	-- maps' roll numbers
	if ctx and ctx.Airdrop and ctx.Loot then
		local A = ctx.Airdrop
		local WPmod = require(game:GetService("ReplicatedStorage").ZR.WeaponParts)
		local kinds, bad = {}, {}
		for _, t in A.TYPES do
			kinds[t.id] = true
			for _, e in ctx.Loot.POOLS[t.pool] or {} do
				if not Items.defs[e.id] and not (WPmod.defs and WPmod.defs[e.id]) and not (WPmod.PARTS and WPmod.PARTS[e.id]) then
					table.insert(bad, e.id)
				end
			end
			if not ctx.Loot.POOLS[t.pool] then
				table.insert(bad, t.pool)
			end
		end
		check("airdrop: four crates (common, medical, supply, weapon), every pool item exists",
			kinds.common and kinds.medical and kinds.supply and kinds.weapon and #bad == 0, table.concat(bad, ","))
		local fits = true
		for _, t in A.TYPES do
			local holder = Inv.newHolder("box", 10, 12)
			local order = ctx.Loot.fill(holder, Random.new(11), t.pool, t.count[2])
			if #order < math.floor(t.count[2] * 0.6) then
				fits = false
			end
		end
		check("airdrop: a crate's most items (up to 18) go into its 10 x 12 grid", fits)
		local okB, LB = pcall(require, script.Parent.Parent.Maps.Border.Layout)
		local okM, LM = pcall(require, script.Parent.Parent.Maps.Meridian.Layout)
		local ab = okB and LB.hazard and LB.hazard.airdrop
		local am = okM and LM.hazard and LM.hazard.airdrop
		check("airdrop: Border Yard and Meridian roll Tarkov's numbers (20 %, 6 people, 300 to 900 s in)",
			ab and am and ab.chance == 0.2 and am.chance == 0.2 and ab.minPlayers == 6 and am.minPlayers == 6 and ab.first[1] == 300 and ab.first[2] == 900)
		check("airdrop: the plane flies its run at drop height and the crate sinks slowly (about 7 studs a second)",
			A.ALT >= 300 and A.RUN >= 1000 and A.FALL > 4 and A.FALL < 10)
		local fd = Items.defs.FLARE_RED
		local found = 0
		for _, pool in { "crate", "jacket", "weaponbox", "toolbox" } do
			for _, e in ctx.Loot.POOLS[pool] or {} do
				if e.id == "FLARE_RED" then
					found += 1
				end
			end
		end
		check("airdrop: the red flare is a 1 x 2 flare that calls a plane, found in crates, jackets, weapon boxes and toolboxes",
			fd ~= nil and fd.kind == "flare" and fd.w == 1 and fd.h == 2 and fd.flare and fd.flare.call == true and found == 4
				and type(A.canFlare) == "function" and type(A.flare) == "function", found)
	end

	-- remote de-dupe
	if ctx and ctx.Remotes then
		local calls = 0
		ctx.Remotes.onReq("__test", function()
			calls += 1
			return ctx.Remotes.ok(calls)
		end, 100, 100)
		local fake = { Name = "test" }
		local a = ctx.Remotes.dispatch(fake, "__test", { rid = "X1" })
		local bb = ctx.Remotes.dispatch(fake, "__test", { rid = "X1" })
		local bad = ctx.Remotes.dispatch(fake, "__test", { rid = "X2", nested = { a = { b = { c = { d = 1 } } } } })
		check("rid de-dupe", calls == 1 and a == bb)
		check("deep payload rejected", bad.ok == false and bad.code == "BAD_INPUT")
		check("unknown action rejected", ctx.Remotes.dispatch(fake, "nope", {}).code == "BAD_INPUT")
	end

	-- session lock (memory store only)
	if ctx and ctx.Store and ctx.Store.mode == "MEMORY" then
		local S = ctx.Store
		local key = "__locktest_" .. tostring(os.clock())
		local d1 = S.acquire(key, function()
			return { v = 1 }
		end)
		local mine = S.serverId
		S.serverId = "other-server"
		local w2ok, w2err = S.write(key, { v = 2 }, false)
		S.serverId = mine
		check("lock blocks other server", d1 ~= nil and not w2ok and w2err == "LOCK_LOST")
		check("release ok", (S.write(key, { v = 3 }, true)))
	end

	-- Relay 7 lobby (L1-L7): the bunker as built, the station prompts, the screens, the range rules
	if ctx and ctx.World and ctx.World.safehouse and ctx.World.safehouse.model and ctx.Lobby and ctx.Range then
		local sh = ctx.World.safehouse
		local R7 = ctx.World.Relay7
		local kits, fallback, shadows, prompts, losOff = 0, 0, 0, 0, 0
		local screensSeen = {}
		for _, d in sh.model:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Kit") then
				kits += 1
				if d:FindFirstChild("KitFallback") then
					fallback += 1
				end
			elseif d:IsA("Light") and d.Shadows then
				shadows += 1
			elseif d:IsA("ProximityPrompt") then
				prompts += 1
				if not d.RequiresLineOfSight then
					losOff += 1
				end
				local sc = string.match(d:GetAttribute("Screen") or "", "^([^:]+)")
				if sc then
					screensSeen[sc] = true
				end
			end
		end
		check("lobby: under 300 kit props", kits > 200 and kits < 300)
		check("lobby: at most 6 shadow-casting lights", shadows <= 6)
		local lib = game:GetService("ServerStorage"):FindFirstChild("ZR_Assets")
		if lib and lib:FindFirstChild("ZR_MK_Van__paint") then
			check("lobby: every kit prop built from its meshes", fallback == 0)
		end
		check("lobby: no prompt reaches through a wall", prompts >= 25 and losOff == 0)
		local missing = {}
		for _, k in { "stash", "mirror", "deploy", "squad", "tasks", "insurance", "trader", "mail", "hideout", "modding", "van", "scav" } do
			if not screensSeen[k] then
				table.insert(missing, k)
			end
		end
		check("lobby: every station has its prompt", #missing == 0)
		-- every trader of the trader screen has a counter (the Fence his stall) and stands behind it
		local TDl = require(game:GetService("ReplicatedStorage").ZR.TraderData)
		local counterFor, npcs = {}, workspace:FindFirstChild("ZR_Traders")
		for _, d in sh.model:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				local id = string.match(d:GetAttribute("Screen") or "", "^trader:(.+)$")
				if id then
					counterFor[id] = true
				end
			end
		end
		local noCounter = {}
		for _, id in TDl.list do
			if not counterFor[id] or not (npcs and npcs:FindFirstChild("Trader_" .. id)) then
				table.insert(noCounter, id)
			end
		end
		check("lobby: all eight traders at a counter" .. (#noCounter > 0 and " (missing " .. table.concat(noCounter, ", ") .. ")" or ""), #noCounter == 0)
		check("lobby: twelve beds, lockers and spawns", #sh.spawns == 12 and #sh.lockers == 12)
		-- owner, 2026-11-01: the bunker is kept, not dirty all over, and nothing flickers
		local worn, slabs, spotsN, shrunk = 0, 0, 0, 0
		for _, d in sh.shell:GetDescendants() do
			if d:IsA("BasePart") then
				if d.MaterialVariant ~= "" then
					worn += 1
				end
				if not d.CanCollide and d.Transparency < 1 then
					slabs += 1 -- paint slabs in front of a wall face (what the decals used to fight with)
				end
				if (d.Name == "WallPaint" and math.abs(d.Size.Y - 4.5) > 0.001) or (d.Name == "WallLine" and math.abs(d.Size.Y - 0.28) > 0.001) then
					shrunk += 1 -- a band pulled back by the z-fighting pass would open a slit
				end
			elseif d:IsA("Attachment") and d.Name == "DetailSpot" then
				spotsN += 1
			end
		end
		check("lobby: shell plain (no worn variants), paint in the walls, no slits", worn == 0 and slabs == 0 and shrunk == 0)
		check("lobby: grime placed where it builds up", spotsN >= 150 and sh.shell:GetAttribute("DetailProfile") == "clean")
		local row = ctx.Lobby.row("NO RAID", "RELAY 7")
		check("lobby: departure rows are 24 flaps", #row == 24 and string.sub(row, -7) == "RELAY 7" and #ctx.Lobby.row(string.rep("X", 30), "LIVE 12:00") == 24)
		local rowsOk = true
		for _, st in { { state = "IDLE", inQueue = 0 }, { state = "MATCHING", inQueue = 2, votes = { quay7 = 2 } }, { state = "RUNNING", inRaid = 3 } } do
			for _, r in ctx.Lobby.departure(st, workspace:GetServerTimeNow()) do
				rowsOk = rowsOk and #r == 24
			end
		end
		check("lobby: departure board fills all four rows", rowsOk)
		-- the range: a booth gives its lane, downrange of the line or behind the booths gives none
		local laneOk = true
		for i, l in R7.LANES do
			laneOk = laneOk and ctx.Range.laneAt(R7.P(R7.FIRING_LINE + 4, 4, (l[1] + l[2]) / 2)) == i
		end
		check("range: each booth is its lane", laneOk)
		check("range: no lane downrange or outside", ctx.Range.laneAt(R7.P(R7.FIRING_LINE - 3, 4, 90)) == nil and ctx.Range.laneAt(R7.P(60, 4, 20)) == nil)
		-- from each booth no target hides another (their faces do not overlap in bearing)
		local hidden = false
		local byLane = {}
		for _, t in R7.targets() do
			byLane[t.lane] = byLane[t.lane] or {}
			table.insert(byLane[t.lane], t)
		end
		for lane, list in byLane do
			local mid = (R7.LANES[lane][1] + R7.LANES[lane][2]) / 2
			for i = 1, #list do
				for j = i + 1, #list do
					local a, b = list[i], list[j]
					local w = 0.6
					local function span(t)
						local dx = (R7.FIRING_LINE + 4) - t.x
						return (t.z - w - mid) / dx, (t.z + w - mid) / dx
					end
					local a0, a1 = span(a)
					local b0, b1 = span(b)
					if math.min(a1, b1) - math.max(a0, b0) > 0.004 then
						hidden = true
					end
				end
			end
		end
		check("range: thirteen targets, none hidden behind another", #R7.targets() == 13 and not hidden)
	end

	-- eyewear and the gas mask (Tarkov): the EYEWEAR slot takes only eyewear; a gas mask and glasses refuse each other; ballistic
	-- glasses carry an eyes zone (Health's side is in CharTests); TILDA sells the glasses; goggles show on the head mount
	do
		local Equipment = require(Shared.Equipment)
		local TDe = require(Shared.TraderData)
		local function bare()
			return { slots = {}, items = {}, grids = {} }
		end
		local function put(h, slot, id)
			local g, it = Inv.newItem(id, 1)
			local okP, err = Inv.placeSlot(h, g, it, slot)
			return okP, err
		end
		-- the slot: after FACE COVER, named EYEWEAR, accepts only eyewear
		local sk, skN = Items.SLOTS.eyes, 0
		for _ in sk or {} do
			skN += 1
		end
		check("eyewear: the EYEWEAR slot sits after FACE COVER and accepts only the eyewear kind",
			sk ~= nil and sk.eyewear == true and skN == 1 and Items.SLOT_NAMES.eyes == "EYEWEAR" and table.find(Items.SLOT_ORDER, "eyes") == table.find(Items.SLOT_ORDER, "face") + 1
			and table.find(Equipment.VISUAL_SLOTS, "eyes") ~= nil)
		local h1 = bare()
		local okSun = put(h1, "eyes", "GLASSES_SUN")
		local h2 = bare()
		local _, eHelm = put(h2, "eyes", "HELMET_C2")
		local _, eGlass = put(h2, "face", "GLASSES_SUN")
		local _, eMask = put(h2, "eyes", "GAS_MASK")
		local okMask = put(h2, "face", "GAS_MASK")
		check("eyewear: glasses fit the eyes slot; a helmet or a mask is refused there and glasses on the face slot", okSun and eHelm == "WRONG_SLOT" and eMask == "WRONG_SLOT" and eGlass == "WRONG_SLOT" and okMask and inv(h1))
		-- blocking rules: the gas mask and glasses refuse each other in either order
		local h3 = bare()
		put(h3, "face", "GAS_MASK")
		local okE3, e3 = put(h3, "eyes", "GLASSES_SUN")
		local h4 = bare()
		put(h4, "eyes", "GLASSES_BG1")
		local okF4, e4 = put(h4, "face", "GAS_MASK")
		check("eyewear: a worn gas mask refuses glasses and worn glasses refuse a gas mask (GAS_MASK_BLOCKS_EYEWEAR)",
			not okE3 and e3 == "GAS_MASK_BLOCKS_EYEWEAR" and not okF4 and e4 == "GAS_MASK_BLOCKS_EYEWEAR"
			and Equipment.conflict({ face = "GAS_MASK" }, "eyes", "GLASSES_AF2") == "GAS_MASK_BLOCKS_EYEWEAR" and Equipment.conflict({ eyes = "GLASSES_RANGE" }, "face", "GAS_MASK") == "GAS_MASK_BLOCKS_EYEWEAR")
		-- what does not block: the face-plate helmet (Tarkov's face shields list "blocks eyewear: no"), the gaiter, the headset rule is unchanged
		local h5 = bare()
		local okH5 = put(h5, "head", "HELMET_C5")
		local okG5 = put(h5, "eyes", "GLASSES_AF2")
		local h6 = bare()
		put(h6, "head", "HELMET_C5")
		local okM6 = put(h6, "face", "GAS_MASK")
		local h7 = bare()
		put(h7, "face", "GAITER")
		local okG7 = put(h7, "eyes", "GLASSES_RANGE")
		local h8 = bare()
		put(h8, "head", "HELMET_C2")
		local okE8, e8 = put(h8, "ears", "HEADSET_GS1")
		check("eyewear: the face-plate helmet takes glasses or a mask, a gaiter takes glasses; the full-cut helmet still blocks the headset",
			okH5 and okG5 and okM6 and okG7 and not okE8 and e8 == "HELMET_COVERS_EARS")
		-- the items: plain glasses are unarmoured, ballistic glasses are class 1 and 2 with an eyes zone, the mask is a face cover
		local D = Items.defs
		check("eyewear: plain glasses and the mask have no armour; ballistic glasses are class 1 and 2 armoured at the eyes",
			D.GLASSES_SUN.armor == nil and D.GLASSES_RANGE.armor == nil and D.GAS_MASK.armor == nil and D.GAS_MASK.kind == "facecover"
			and D.GLASSES_BG1.armor.class == 1 and D.GLASSES_AF2.armor.class == 2 and D.GLASSES_BG1.armor.zones.eyes == true and D.GLASSES_AF2.armor.zones.eyes == true
			and D.GLASSES_BG1.kind == "eyewear" and D.GLASSES_AF2.kind == "eyewear")
		local _, bgi = Inv.newItem("GLASSES_BG1", 1)
		local _, sui = Inv.newItem("GLASSES_SUN", 1)
		check("eyewear: ballistic glasses start at full durability, plain ones have none (Tarkov shows '---')", bgi.dur == D.GLASSES_BG1.armor.dur and sui.dur == nil)
		local lensOk = true
		for _, id in { "GLASSES_SUN", "GLASSES_RANGE", "GLASSES_BG1", "GLASSES_AF2", "GAS_MASK" } do
			local e = D[id].eye
			lensOk = lensOk and e ~= nil and e.flash >= 0 and e.flash <= 0.4 and e.shade > 0 and e.shade <= 0.3 and typeof(e.tint) == "Color3" and type(e.lens) == "string"
		end
		local tSun, tRng, tFrag = D.GLASSES_SUN.eye.tint, D.GLASSES_RANGE.eye.tint, D.GLASSES_AF2.eye.tint
		check("eyewear: every lens has a mild tint and a flash share (sunglasses brown, shooting glasses yellow, class 2 blue)",
			lensOk and tSun.R > tSun.B and tRng.R > tRng.B * 2 and tRng.G > tRng.B * 2 and tFrag.B > tFrag.R)
		-- TILDA sells the glasses at Tarkov-like loyalty levels (no gas mask: Tarkov gas masks are not sold for cash) and buys eyewear
		local function offerOf(id)
			for _, o in TDe.offers.tilda do
				if o.id == id then
					return o
				end
			end
			return nil
		end
		local oS, oR, oB, oA = offerOf("GLASSES_SUN"), offerOf("GLASSES_RANGE"), offerOf("GLASSES_BG1"), offerOf("GLASSES_AF2")
		check("eyewear: TILDA sells the sunglasses at LL1, shooting and class 1 glasses at LL3, class 2 at LL4, and no gas mask",
			oS ~= nil and oS.ll == 1 and oR ~= nil and oR.ll == 3 and oB ~= nil and oB.ll == 3 and oA ~= nil and oA.ll == 4 and offerOf("GAS_MASK") == nil)
		local sellBg = TDe.sellPrice("tilda", { id = "GLASSES_BG1", n = 1, dur = 25 })
		check("eyewear: TILDA buys eyewear and VOS does not; prices rise with protection",
			sellBg ~= nil and sellBg > 0 and TDe.sellPrice("vos", { id = "GLASSES_BG1", n = 1, dur = 25 }) == nil
			and TDe.price("tilda", oS, 1) < TDe.price("tilda", oR, 3) and TDe.price("tilda", oR, 3) < TDe.price("tilda", oB, 3) and TDe.price("tilda", oB, 3) < TDe.price("tilda", oA, 4))
		-- ROOK repairs worn ballistic glasses like other armour (each repair lowers the maximum); plain glasses have no condition
		-- to restore (EFT: Skier repairs armour, the Ragman does not)
		local rpBg, _, rpMax = TDe.repairQuote("rook", { id = "GLASSES_BG1", n = 1, dur = 10 })
		check("eyewear: ROOK repairs worn ballistic glasses (the maximum drops); plain glasses and VOS give no repair",
			rpBg == 15 and rpMax ~= nil and rpMax < 25 and TDe.repairQuote("rook", { id = "GLASSES_SUN", n = 1 }) == nil and TDe.repairQuote("vos", { id = "GLASSES_BG1", n = 1, dur = 10 }) == nil)
		-- the loot tables carry the mask and the glasses
		local function pooled(pool, id)
			for _, e in Loot.POOLS[pool] do
				if e.id == id then
					return true
				end
			end
			return false
		end
		check("eyewear: the gas mask and glasses are in the loot tables",
			pooled("locker", "GAS_MASK") and pooled("medbag", "GAS_MASK") and pooled("toolbox", "GAS_MASK") and pooled("weaponbox", "GLASSES_BG1") and pooled("weaponbox", "GLASSES_AF2")
			and pooled("jacket", "GLASSES_SUN") and pooled("locker", "GLASSES_RANGE"))
		-- AI kits: some wear glasses, a few a gas mask, never both (the slot rule keeps the second one out)
		local nGlass, nMask, nBoth, nBad = 0, 0, 0, 0
		for i = 1, 150 do
			for _, build in { Loot.guardLoadout, Loot.scavLoadout, Loot.crewLoadout } do
				local kh = build(Random.new(i))
				local eg, fg = kh.slots.eyes, kh.slots.face
				local faceId = fg and kh.items[fg] and kh.items[fg].id
				if eg then
					nGlass += 1
				end
				if faceId == "GAS_MASK" then
					nMask += 1
				end
				if eg and faceId == "GAS_MASK" then
					nBoth += 1
				end
				if not inv(kh) then
					nBad += 1
				end
			end
		end
		check("eyewear: AI kits wear glasses now and then and a gas mask rarely, never both, and stay valid", nGlass > 20 and nMask > 0 and nBoth == 0 and nBad == 0)
		-- goggles on the head item's mount show on the character: flipped up by default, down over the eyes when pulled down
		local nh = bare()
		local hg2 = "HG"
		local ng2 = "NG"
		nh.items[hg2] = { id = "HELMET_C4", n = 1, dur = 50, mods = { mount = ng2 } }
		nh.items[ng2] = { id = "NV_MONO", n = 1 }
		nh.slots.head = hg2
		local stUp, stDn = Equipment.stateOf(nh, "player", 1, false), Equipment.stateOf(nh, "player", 1, true)
		local function nvgKeys(st)
			local list = {}
			for _, e in Equipment.resolve(st) do
				if e.group == "nvg" then
					table.insert(list, e.key)
				end
			end
			return table.concat(list, "+")
		end
		local sigUp, sigDn = Equipment.signature(Equipment.resolve(stUp)).nvg, Equipment.signature(Equipment.resolve(stDn)).nvg
		check("goggles: the device on the worn helmet's mount shows up by default and down when pulled down (two different looks)",
			stUp.nvg ~= nil and stUp.nvg.id == "NV_MONO" and stUp.nvg.down == false and stDn.nvg.down == true and nvgKeys(stUp) == "ZR_EQ_NvMonoUp" and nvgKeys(stDn) == "ZR_EQ_NvMonoDown"
			and sigUp ~= nil and sigDn ~= nil and sigUp ~= sigDn)
		local nb = bare()
		nb.items.H = { id = "HELMET_C2", n = 1 }
		nb.slots.head = "H"
		local nc = bare()
		nc.items.S = { id = "NV_STRAP", n = 1, mods = { mount = "D" } }
		nc.items.D = { id = "TH_T7", n = 1 }
		nc.slots.head = "S"
		check("goggles: no device on the head item, no goggles drawn; the strap carries them like a helmet does",
			Equipment.stateOf(nb, "player", 1, true).nvg == nil and Equipment.stateOf(bare(), "player", 1, true).nvg == nil and nvgKeys(Equipment.stateOf(nc, "player", 1, true)) == "ZR_EQ_NvThermalDown")
		local noNvg = {}
		for id, d in Items.defs do
			if d.kind == "nvg" and not Equipment.NVG[id] then
				table.insert(noNvg, id)
			end
		end
		check("goggles: every night-vision device has an up and a down model", #noNvg == 0 and Equipment.NVG.NV_QUAD.down.key == "ZR_EQ_NvQuadDown" and Equipment.NVG.NV_QUAD.up.key == "ZR_EQ_NvQuadUp")
		if ctx and ctx.Raid then
			check("goggles: the server finds the device on the head item's mount", ctx.Raid.nvgOf(nh) == ng2 and ctx.Raid.nvgOf(nb) == nil and ctx.Raid.nvgOf(nc) == "D" and ctx.Raid.nvgOf(bare()) == nil)
		end
		-- the pending list names only meshes the game places
		local known = {}
		for _, k in Equipment.allKeys() do
			known[k] = true
		end
		local stray = {}
		for k in Equipment.PENDING do
			if not known[k] then
				table.insert(stray, k)
			end
		end
		check("eyewear: Equipment.PENDING lists only meshes the game places", #stray == 0)
	end

	-- stationary guns (Tarkov's NSV Utyos and AGS-30 as our HMG-12 and AGL-30, docs/design/STATIONARY_WEAPONS.md): the kinds, the arcs,
	-- who may man a gun and when they must get off, the rate of fire and the belt, damage through the normal hit path, the AGL-30's
	-- burst, a guard's use of a gun, the raid reset, Border Yard's placements. The operators are stand-in tables (a rig for a
	-- character, a raid session the test hands out): the server needs a real Player only to tell the client, and a table has nobody
	-- to tell. The test guns are stepped by hand (Stationary.update with a clock of the test's own) and kept out of the Heartbeat loop.
	do
		local SG = require(Shared.Stationary)
		local Wp = require(Shared.Weapons)
		local IM = require(Shared.InputMap)
		local RigM = require(Shared.RigMath)
		local STAND = RigM.STAND_HIP + RigM.hrpHalf
		local H, A = SG.KINDS.HMG12, SG.KINDS.AGL30
		local okShared, errShared = pcall(function()
			-- the kinds: Tarkov's rates, the NSV's B-32 numbers, a launcher round the grenade system can burst
			check("stationary: the kinds carry Tarkov's rates (650 and 425 RPM), belts and the B-32 round (182 damage, 88 penetration)",
				H.rpm == 650 and A.rpm == 425 and H.belt == 100 and A.belt == 30 and H.dmg == 182 and H.pen == 88 and A.round == "AGL30_ROUND")
			local missing = {}
			for kind, k in SG.KINDS do
				for _, f in { "rpm", "belt", "velocity", "drag", "range", "zero", "spread", "bloomPerShot", "bloomMax", "bloomDecay", "tracerEvery", "loud", "pivotH", "muzzleLen", "zoom", "shake", "turnRate", "aiRange", "aiMin", "aiErr" } do
					if type(k[f]) ~= "number" then
						table.insert(missing, kind .. "." .. f)
					end
				end
				for _, f in { "id", "name", "short", "what", "sound", "ammoName" } do
					if type(k[f]) ~= "string" then
						table.insert(missing, kind .. "." .. f)
					end
				end
				for _, f in { "eye", "op" } do
					if typeof(k[f]) ~= "Vector3" then
						table.insert(missing, kind .. "." .. f)
					end
				end
				for _, f in { "burst", "pause", "arcs" } do
					if type(k[f]) ~= "table" then
						table.insert(missing, kind .. "." .. f)
					end
				end
			end
			check("stationary: every kind has the numbers the server and the client read" .. (#missing > 0 and (" (missing " .. table.concat(missing, ", ") .. ")") or ""), #missing == 0)
			check("stationary: the time between rounds is 60 / RPM", math.abs(SG.interval(H) - 60 / 650) < 1e-9 and math.abs(SG.interval(A) - 60 / 425) < 1e-9)
			local rd = Items.defs[A.round]
			check("stationary: the launcher's round is a frag charge that bursts on contact (fuse 0)",
				rd ~= nil and rd.nade ~= nil and rd.nade.type == "frag" and rd.nade.fuse == 0 and rd.kind == "hazard")
			-- arcs
			local arcs = SG.makeArcs(H)
			local narrow = SG.makeArcs(H, { left = 30 })
			check("stationary: arcs come from the kind, and a map can narrow them per gun",
				math.abs(arcs.l - math.rad(70)) < 1e-9 and math.abs(arcs.r - math.rad(70)) < 1e-9 and math.abs(arcs.up - math.rad(40)) < 1e-9
				and math.abs(arcs.dn - math.rad(20)) < 1e-9 and math.abs(narrow.l - math.rad(30)) < 1e-9 and math.abs(narrow.r - math.rad(70)) < 1e-9)
			local cy1, cp1 = SG.clamp(arcs, math.rad(120), math.rad(80))
			local cy2, cp2 = SG.clamp(arcs, math.rad(-120), math.rad(-80))
			local cy3, cp3 = SG.clamp(arcs, math.rad(350), math.rad(5))
			check("stationary: the aim is held inside the arcs (left, right, up, down; 350 degrees is 10 to the right)",
				math.abs(cy1 - arcs.l) < 1e-9 and math.abs(cp1 - arcs.up) < 1e-9 and math.abs(cy2 + arcs.r) < 1e-9 and math.abs(cp2 + arcs.dn) < 1e-9
				and math.abs(cy3 - math.rad(-10)) < 1e-9 and math.abs(cp3 - math.rad(5)) < 1e-9)
			check("stationary: inArc takes the edge with its slack",
				SG.inArc(arcs, 0, 0) and SG.inArc(arcs, math.rad(69.9), math.rad(39.9)) and not SG.inArc(arcs, math.rad(70.1), 0)
				and SG.inArc(arcs, math.rad(70.1), 0, math.rad(0.5)) and not SG.inArc(arcs, 0, math.rad(-20.1)) and not SG.inArc(arcs, math.rad(180), 0))
			-- the aiming maths: positive yaw is left, and the aim that sends a round from the eye through a point
			local fr = SG.frame(CFrame.new(0, 0, 0))
			local wy, wp = math.rad(25), math.rad(10)
			local goal = SG.eye(fr, H, wy) + SG.dirOf(fr, H, wy, wp) * 300
			local ay, ap = SG.anglesFrom(fr, H, goal)
			local leftYaw = SG.anglesTo(fr, H, SG.pivot(fr, H).Position + Vector3.new(-50, 0, -50))
			local rightYaw = SG.anglesTo(fr, H, SG.pivot(fr, H).Position + Vector3.new(50, 0, -50))
			check("stationary: positive yaw is left, and anglesFrom finds the aim that puts a round from the eye on a point",
				math.abs(leftYaw - math.rad(45)) < 1e-6 and math.abs(rightYaw + math.rad(45)) < 1e-6 and math.abs(ay - wy) < 1e-4 and math.abs(ap - wp) < 1e-4)
			check("stationary: approach turns toward the goal by at most the step, the short way round",
				math.abs(SG.approach(0, 1, 0.25) - 0.25) < 1e-9 and math.abs(SG.approach(0, 0.1, 0.25) - 0.1) < 1e-9
				and SG.approach(math.rad(170), math.rad(-170), 0.1) > math.rad(170))
			-- the input map: the mount actions have a context of their own and follow the player's Fire and Aim keys
			check("stationary: the mount actions have their own context (fire and zoom follow the player's Fire and Aim keys, F or B leaves)",
				IM.MountFire.context == "mount" and IM.MountZoom.context == "mount" and IM.MountLeave.context == "mount"
				and IM.MountFire.like == "Fire" and IM.MountZoom.like == "Aim" and IM.MountLeave.keys[1] == Enum.KeyCode.F and IM.MountLeave.pad[1] == Enum.KeyCode.ButtonB
				and IM.MountFire.pad[1] == Enum.KeyCode.ButtonR2 and IM.MountZoom.pad[1] == Enum.KeyCode.ButtonL2
				and IM.MountFire.touch ~= nil and IM.MountZoom.touch ~= nil and IM.MountLeave.touch ~= nil)
		end)
		if not okShared then
			check("stationary: the shared checks ran without an error (" .. tostring(errShared) .. ")", false)
		end

		if ctx and ctx.Stationary and ctx.Combat and ctx.Health and ctx.Chars and ctx.Grenades and ctx.Hazards and ctx.AI then
			local ST = ctx.Stationary
			local realFire, realSession, realGuns, realSee = ST.fire, ST.sessionOf, ST.guns, ctx.AI.visiblePart
			local stage = Instance.new("Folder")
			stage.Name = "ZR_TestStationary"
			stage.Parent = workspace
			local sessions, mine, dummies, fired, useReal = {}, {}, {}, 0, false
			local origin = Vector3.new(9000, 2500, 0)
			-- stand-ins, passing everything else through: the test's stand-in operators have sessions of their own, its guns count
			-- their rounds instead of flying them (until useReal), its guard is "seen" by anyone it points at
			local stubSession = function(p)
				if typeof(p) == "Instance" then
					return realSession(p)
				end
				return sessions[p]
			end
			ST.sessionOf = stubSession
			ST.fire = function(g, who)
				if mine[g] and not useReal then
					fired += 1
					return
				end
				return realFire(g, who)
			end
			ctx.AI.visiblePart = function(u, model, eye)
				if u.test then
					return model:FindFirstChild("UpperTorso")
				end
				return realSee(u, model, eye)
			end

			local function place(kind, at, turn)
				local g = ST.place(kind, CFrame.new(at) * CFrame.Angles(0, turn or 0, 0), { parent = stage })
				for i = #ST.guns, 1, -1 do
					if ST.guns[i] == g then
						table.remove(ST.guns, i) -- the Heartbeat loop must not tick a gun the test steps by hand
					end
				end
				mine[g] = true
				return g
			end
			local function rigAt(look, pos)
				local rig = ctx.Chars.buildRig(look)
				rig:PivotTo(CFrame.new(pos))
				rig.HumanoidRootPart.Anchored = true
				rig.Parent = stage
				return rig
			end
			local function operator(name, pos)
				local op = { Name = name, DisplayName = name, Character = rigAt("player", pos), Parent = stage }
				sessions[op] = { done = false }
				return op
			end
			local function dummy(pos)
				local rig = rigAt("guard", pos)
				local held = { slots = {}, items = {}, grids = {} }
				ctx.Health.attach(rig, { kind = "ai", holder = function()
					return held
				end })
				table.insert(dummies, rig)
				return rig, ctx.Health.get(rig)
			end
			-- the trigger held for `secs` seconds on a gun stepped at 60 Hz by a clock of the test's own; returns that clock
			local function hold(g, secs, fire)
				local t = os.clock()
				for _ = 1, math.floor(secs * 60) do
					t += 1 / 60
					ST.setAim(g, 0, 0, fire, t)
					ST.update(g, t, 1 / 60)
				end
				return t
			end

			local okLive, errLive = pcall(function()
				local gun = place("HMG12", origin, math.rad(90))
				local spec = gun.spec
				local spot = SG.opSpot(gun.frame, spec)
				local function nearSpot(i) -- standing a few studs from the operator spot
					return spot + Vector3.new(0, STAND, 0) + gun.frame:VectorToWorldSpace(Vector3.new(i, 0, 2))
				end
				local farSpot = spot + Vector3.new(0, STAND, 0) + gun.frame:VectorToWorldSpace(Vector3.new(0, 0, 60))
				local eyeP = SG.eye(gun.frame, spec, 0)
				local fwd = gun.frame.LookVector

				-- mounting
				local opFar, opOver, opNone, opDead = operator("Far", farSpot), operator("Over", nearSpot(0)), operator("NoRaid", nearSpot(0)), operator("Dead", nearSpot(0))
				sessions[opOver].done = true
				sessions[opNone] = nil
				opDead.Character.Humanoid.Health = 0
				check("stationary: a raider too far away, outside a raid, whose raid is over or who is dead cannot man a gun",
					not ST.mount(opFar, gun) and not ST.mount(opOver, gun) and not ST.mount(opNone, gun) and not ST.mount(opDead, gun) and gun.op == nil)
				local opA = operator("Alpha", nearSpot(0))
				local rootA = opA.Character.HumanoidRootPart
				local mountedA = ST.mount(opA, gun)
				check("stationary: a raider in a raid within reach mounts: held at the operator spot, facing along the gun, the gun marked and its prompt off",
					mountedA and gun.op == opA and ST.gunOf(opA) == gun and opA.Character:GetAttribute("Mounted") == gun.id
					and (rootA.Position - (spot + Vector3.new(0, STAND, 0))).Magnitude < 0.5 and rootA.CFrame.LookVector:Dot(fwd) > 0.99
					and gun.model:GetAttribute("Op") == "Alpha" and gun.prompt.Enabled == false)
				local gunB = place("HMG12", origin + Vector3.new(0, 0, 6), math.rad(90)) -- its spot is 6 studs from the first gun's
				local opB = operator("Bravo", nearSpot(1))
				check("stationary: one operator per gun and one gun per operator",
					not ST.mount(opB, gun) and gun.op == opA and not ST.mount(opA, gunB) and gunB.op == nil and ST.gunOf(opA) == gun)

				-- aiming: the client's update is held inside the arcs, and only the operator's counts
				ST.aim(opA, { y = 9, p = 9, f = 1 })
				local hiOk = math.abs(gun.yaw - gun.arcs.l) < 1e-9 and math.abs(gun.pitch - gun.arcs.up) < 1e-9 and gun.fire == true
				ST.aim(opA, { y = 0 / 0, p = 0, f = 1 })
				local nanOk = math.abs(gun.yaw - gun.arcs.l) < 1e-9
				ST.aim(opA, { y = -9, p = -9, f = 0 })
				local loOk = math.abs(gun.yaw + gun.arcs.r) < 1e-9 and math.abs(gun.pitch + gun.arcs.dn) < 1e-9 and gun.fire == false
				ST.aim(opB, { y = 0.1, p = 0.1, f = 1 })
				check("stationary: the operator's aim is clamped to the arcs (left/up, right/down), a non-number is ignored, a bystander cannot aim the gun",
					hiOk and nanOk and loOk and math.abs(gun.yaw + gun.arcs.r) < 1e-9 and gun.fire == false)

				-- leaving: frees the gun; the same raider cannot take it again at once (F is both keys), but a moment later
				ST.leave(opA)
				local freed = gun.op == nil and ST.gunOf(opA) == nil and opA.Character:GetAttribute("Mounted") == nil and gun.prompt.Enabled == true and gun.model:GetAttribute("Op") == ""
				local tooSoon = ST.mount(opA, gun)
				task.wait(ST.RESTART + 0.15)
				local humA = opA.Character:FindFirstChildOfClass("Humanoid")
				local why = string.format(" [freed %s, tooSoon %s, crew %s, dist %.1f, health %s, stub %s, root %s, mounted %s]", tostring(freed),
					tostring(tooSoon), tostring(gun.crew ~= nil), (rootA.Position - SG.opSpot(gun.frame, gun.spec)).Magnitude,
					tostring(humA and humA.Health), tostring(ST.sessionOf == stubSession), tostring(opA.Character:FindFirstChild("HumanoidRootPart") ~= nil),
					tostring(ST.gunOf(opA) ~= nil))
				local later = ST.mount(opA, gun)
				local ok = freed and not tooSoon and later and gun.op == opA
				check("stationary: leaving frees the gun; the same raider cannot grab it again at once but can a moment later" .. (ok and "" or why), ok)

				-- the operator is put off the gun: too far from the spot, the raid ends, death
				opA.Character:PivotTo(CFrame.new(spot + Vector3.new(0, STAND, 0) + gun.frame:VectorToWorldSpace(Vector3.new(0, 0, 5))))
				ST.update(gun, os.clock(), 1 / 60)
				local stayed = gun.op == opA -- 5 studs from the spot is inside the leash
				opA.Character:PivotTo(CFrame.new(farSpot))
				ST.update(gun, os.clock(), 1 / 60)
				local awayOff = gun.op == nil and opA.Character:GetAttribute("Mounted") == nil
				local opC = operator("Charlie", nearSpot(0))
				ST.mount(opC, gun)
				sessions[opC].done = true
				ST.update(gun, os.clock(), 1 / 60)
				local raidOff = gun.op == nil and opC.Character:GetAttribute("Mounted") == nil
				local opD = operator("Delta", nearSpot(0))
				ST.mount(opD, gun)
				local onD = gun.op == opD
				opD.Character.Humanoid.Health = 0
				ST.update(gun, os.clock(), 1 / 60)
				local deadOff = onD and gun.op == nil and opD.Character:GetAttribute("Mounted") == nil
				check("stationary: an operator who strays more than 8 studs, whose raid ends or who dies is put off the gun",
					stayed and awayOff and raidOff and deadOff and gun.prompt.Enabled == true)

				-- rate of fire and the belt (the gun counts its rounds here instead of flying them)
				local opE = operator("Echo", nearSpot(0))
				ST.mount(opE, gun)
				gun.rounds, gun.nextShot, gun.shots, fired = spec.belt, 0, 0, 0
				hold(gun, 2, true)
				local hmgShots = fired
				check("stationary: the HMG-12 fires 650 rounds a minute (about 22 in two seconds), each one off the belt",
					hmgShots >= 21 and hmgShots <= 23 and gun.rounds == spec.belt - hmgShots and gun.shots == hmgShots)
				local gunL = place("AGL30", origin + Vector3.new(300, 0, 0), 0)
				local opL = operator("Lima", SG.opSpot(gunL.frame, gunL.spec) + Vector3.new(0, STAND, 1.5))
				local onL = ST.mount(opL, gunL)
				fired = 0
				hold(gunL, 2, true)
				check("stationary: the AGL-30 fires 425 rounds a minute (about 15 in two seconds) from a belt of 30",
					onL and fired >= 14 and fired <= 16 and gunL.rounds == gunL.spec.belt - fired)
				gun.rounds, gun.nextShot, fired = 50, 0, 0
				local base = os.clock() + 1000
				local s1, s2, s3 = ST.trigger(gun, base, nil), ST.trigger(gun, base + 0.01, nil), ST.trigger(gun, base + 0.1, nil)
				check("stationary: a round inside the interval is refused (650 RPM is 92 ms apart), the next one fires", s1 and not s2 and s3 and fired == 2 and gun.rounds == 48)
				gun.rounds, gun.nextShot, fired = 3, 0, 0
				local tEmpty = hold(gun, 1, true)
				check("stationary: an empty belt stops the gun and nothing reloads it", fired == 3 and gun.rounds == 0 and not ST.trigger(gun, tEmpty + 5, nil))
				gun.rounds, gun.nextShot, fired = 50, 0, 0
				local tk = os.clock() + 3000
				ST.setAim(gun, 0, 0, true, tk)
				ST.update(gun, tk + ST.KEEP + 0.3, 1 / 60)
				local released = fired == 0
				ST.update(gun, tk + 0.1, 1 / 60)
				check("stationary: a trigger whose aim updates stopped counts as released after 0.7 s", released and fired == 1)
				ST.setAim(gun, 0.4, 0.1, false, tk + 0.2)
				ST.update(gun, tk + 0.3, 1 / 60)
				check("stationary: the belt and the aim reach every client as attributes on the model",
					gun.model:GetAttribute("Rounds") == gun.rounds and math.abs((gun.model:GetAttribute("Yaw") or 9) - 0.4) < 1e-6
					and math.abs((gun.model:GetAttribute("Pitch") or 9) - 0.1) < 1e-6)
				check("stationary: damage falls off with distance like every weapon (whole to a third of the range, 60 percent at the end)",
					ST.falloff(0, 1000) == 1 and ST.falloff(Wp.FALLOFF_START * 1000, 1000) == 1 and math.abs(ST.falloff(1000, 1000) - Wp.FALLOFF_MIN) < 1e-9
					and ST.falloff(2000, 1000) == Wp.FALLOFF_MIN and ST.falloff(600, 1000) < 1 and ST.falloff(600, 1000) > Wp.FALLOFF_MIN)

				-- a real bullet through the normal hit path (Ballistics, Combat.hitModel, Health.hit)
				useReal = true
				local tgt, hs = dummy(eyeP + fwd * 80)
				local total0 = ctx.Health.total(hs)
				local ty, tp = SG.anglesFrom(gun.frame, spec, tgt.UpperTorso.Position)
				ST.setAim(gun, ty, tp, false, os.clock())
				ST.fire(gun, opE)
				local t0 = os.clock()
				while not hs.lastHit and os.clock() - t0 < 1.5 do
					task.wait()
				end
				check("stationary: a round from the HMG-12 flies as a real bullet and hurts what it meets through Health.hit (weapon, ammunition, health)",
					hs.lastHit ~= nil and hs.lastHit.weapon == spec.name and hs.lastHit.ammo == spec.ammoName and ctx.Health.total(hs) < total0)
				-- an AGL-30 round flies to a wall and bursts there through the grenade system (a frag blast); a world is needed for that
				if workspace:FindFirstChild("ZR_World") then
					local eyeL = SG.eye(gunL.frame, gunL.spec, 0)
					local wall = Instance.new("Part")
					wall.Anchored, wall.Size, wall.Position = true, Vector3.new(60, 60, 2), eyeL + gunL.frame.LookVector * 120
					wall.Parent = stage
					local ly, lp = SG.anglesFrom(gunL.frame, gunL.spec, wall.Position)
					ST.setAim(gunL, ly, lp, false, os.clock())
					local shells0, blasts0 = ST.stats.shells, ctx.Grenades.stats.exploded
					ST.fire(gunL, opL)
					local t1 = os.clock()
					while ST.stats.shells == shells0 and os.clock() - t1 < 2 do
						task.wait()
					end
					check("stationary: an AGL-30 round flies to what it hits and bursts there through the grenade system",
						ST.stats.shells == shells0 + 1 and ctx.Grenades.stats.exploded == blasts0 + 1)
					local fake = { Instance = wall, Normal = Vector3.yAxis, Material = Enum.Material.Concrete }
					local before = ST.stats.shells
					ST.burst(gunL, nil, fake, wall.Position, gunL.spec.arm - 5)
					local dud = ST.stats.shells == before
					ST.burst(gunL, nil, fake, wall.Position, gunL.spec.arm + 40)
					local armed = ST.stats.shells == before + 1
					ST.expire(gun, nil, wall.Position)
					local mgExpire = ST.stats.shells == before + 1
					ST.expire(gunL, nil, wall.Position)
					check("stationary: a launcher round nearer than its arming distance is a dud, one that flies its whole range bursts itself, a machine-gun round just ends",
						dud and armed and mgExpire and ST.stats.shells == before + 2)
				end
				-- shots by a guard's model and by a stand-in operator run through the whole fire path
				local crewRig = rigAt("guard", spot + Vector3.new(0, STAND, 0))
				local shotOk1 = pcall(realFire, gun, crewRig)
				local shotOk2 = pcall(realFire, gun, opE)
				useReal = false
				check("stationary: a shot by a guard's model and a shot by an operator both run through the fire path", shotOk1 and shotOk2)
				ST.leave(opE)

				-- guards: who may post, the reach, the burst fire, walking off
				local opM = operator("Mike", nearSpot(0))
				local gotOn = ST.mount(opM, gun)
				local humM = opM.Character:FindFirstChildOfClass("Humanoid")
				local hsM = ctx.Health.of(opM)
				local whyM = string.format(" [mounted %s, op %s, crew %s, health %s, dist %.1f, stub %s, session %s, using %s, nade %s]",
					tostring(gotOn), tostring(gun.op and gun.op.Name), tostring(gun.crew ~= nil), tostring(humM and humM.Health),
					(opM.Character.HumanoidRootPart.Position - SG.opSpot(gun.frame, gun.spec)).Magnitude, tostring(ST.sessionOf == stubSession),
					tostring(ST.sessionOf(opM) ~= nil), tostring(hsM and hsM.using), tostring(ctx.Grenades.busy(opM)))
				ST.guns = { gun }
				local manned = ST.gunNear(spot + Vector3.new(0, STAND, 0), 4)
				ST.leave(opM)
				local free = ST.gunNear(spot + Vector3.new(0, STAND, 0), 4)
				ST.guns = realGuns
				local okM = manned == nil and free == gun
				check("stationary: a gun with a raider on it is no post for a guard, a free one is" .. (okM and "" or whyM), okM)
				local eyeL = SG.eye(gunL.frame, gunL.spec, 0)
				local left = gun.frame:VectorToWorldSpace(Vector3.new(-1, 0, 0))
				check("stationary: a guard's reach is the arcs and the kind's range (ahead yes; behind, to the side or past 190 studs no; the launcher not inside 40 studs)",
					ST.reaches(gun, eyeP + fwd * 100) and not ST.reaches(gun, eyeP - fwd * 100) and not ST.reaches(gun, eyeP + left * 100)
					and not ST.reaches(gun, eyeP + fwd * 250) and ST.reaches(gunL, eyeL + gunL.frame.LookVector * 100) and not ST.reaches(gunL, eyeL + gunL.frame.LookVector * 20))
				gun.rounds, gun.nextShot, gun.yaw, gun.pitch, fired = spec.belt, 0, 0, 0, 0
				local unit = { alive = true, state = "ENGAGE", post = true, root = crewRig.HumanoidRootPart, model = crewRig, label = "Test Gunner", test = true }
				local behind = dummy(eyeP - fwd * 80)
				unit.target = behind
				local tc = os.clock()
				ST.guns = { gun }
				local seatedBehind = ST.crew(unit, tc)
				local front = dummy(eyeP + fwd * 80)
				unit.target = front
				local seated, look = ST.crew(unit, tc)
				ST.guns = realGuns
				local opX = operator("Xray", nearSpot(0))
				check("stationary: a guard does not man a gun against a target outside its arcs, does against one in its arcs and sight, and then no raider can mount it",
					seatedBehind == false and seated == true and typeof(look) == "Vector3" and gun.crew == unit and unit.gun == gun and gun.prompt.Enabled == false and not ST.mount(opX, gun))
				for i = 1, 240 do -- four seconds at 60 Hz, the guard's AI step (5 Hz) in between
					tc += 1 / 60
					if i % 12 == 0 then
						ST.crew(unit, tc)
					end
					ST.update(gun, tc, 1 / 60)
				end
				check("stationary: the guard lays the gun on the target and fires bursts (5 to 10 rounds) off the belt",
					fired >= 5 and fired <= 60 and gun.rounds == spec.belt - fired and math.abs(gun.yaw) < 0.2 and gun.crew == unit)
				front.Humanoid.Health = 0
				local stays = ST.crew(unit, tc + 0.2)
				local goneOk = stays == false and gun.crew == nil and unit.gun == nil and gun.prompt.Enabled == true
				local front2 = dummy(eyeP + fwd * 80)
				unit.target = front2
				ST.guns = { gun }
				local reseated = ST.crew(unit, tc + 1)
				ST.guns = realGuns
				crewRig:PivotTo(CFrame.new(farSpot))
				local walked = ST.crew(unit, tc + 1.2)
				check("stationary: the guard leaves the gun when the target dies or when moved away from the spot, and the gun is free again",
					goneOk and reseated == true and walked == false and gun.crew == nil and unit.gun == nil)

				-- a new raid: every gun full, free and straight ahead
				local opF = operator("Foxtrot", nearSpot(0))
				ST.mount(opF, gun)
				local onF = gun.op == opF
				gun.rounds, gunL.rounds = 12, 3
				ST.setAim(gun, 0.5, 0.2, true, os.clock())
				ST.guns = { gun, gunL }
				ST.reset()
				ST.guns = realGuns
				check("stationary: a new raid frees every gun, fills its belt and points it straight ahead",
					onF and gun.op == nil and opF.Character:GetAttribute("Mounted") == nil and gun.rounds == spec.belt and gunL.rounds == gunL.spec.belt
					and gun.yaw == 0 and gun.pitch == 0 and gun.fire == false and gun.prompt.Enabled == true and gun.model:GetAttribute("Rounds") == spec.belt)
				-- taking a gun away puts its operator off it
				local gunR = place("HMG12", origin + Vector3.new(-300, 0, 0), 0)
				local opR = operator("Romeo", SG.opSpot(gunR.frame, gunR.spec) + Vector3.new(0, STAND, 1.5))
				ST.mount(opR, gunR)
				local onR = gunR.op == opR
				ST.remove(gunR)
				check("stationary: removing a gun puts its operator off it", onR and gunR.op == nil and opR.Character:GetAttribute("Mounted") == nil and ST.gunOf(opR) == nil and gunR.model.Parent == nil)
			end)
			ST.fire, ST.sessionOf, ST.guns, ctx.AI.visiblePart = realFire, realSession, realGuns, realSee
			for _, d in dummies do
				ctx.Health.states[d] = nil
			end
			stage:Destroy()
			if not okLive then
				check("stationary: the live checks ran without an error (" .. tostring(errLive) .. ")", false)
			end
			-- the maps' own guns, as built: Border Yard puts an HMG-12 and an AGL-30 on the Bastion's roof, inside the world folder
			local nHmg, nAgl, inWorld = 0, 0, true
			for _, g in ST.guns do
				if g.model.Parent then -- (a gun of a rebuilt world is still listed until the next place)
					if g.kind == "HMG12" then
						nHmg += 1
					elseif g.kind == "AGL30" then
						nAgl += 1
					end
					if not g.model:FindFirstAncestor("ZR_World") then
						inWorld = false
					end
				end
			end
			checkOn("border", "stationary: Border Yard carries an HMG-12 and an AGL-30 on the Bastion roof, inside the world folder", nHmg >= 1 and nAgl >= 1 and inWorld)
		end
	end

	-- Meridian Mall on Interchange's rules (gameplay): the empty-backpack exit, the two-step power exit, minefields, the new keys
	-- and what the map registered for them
	if ctx and ctx.Extract and ctx.World and ctx.Hazards then
		local EX, WD, HZ = ctx.Extract, ctx.World, ctx.Hazards
		-- FENCE GAP (kind nobag): a worn backpack blocks it, an empty back slot does not, and it is checked again during the hold
		local bare = { inv = { items = {}, slots = {} }, scav = false }
		local packed = { inv = { items = {}, slots = { back = "g1" } }, scav = false }
		local gap = { id = "T_GAP", rule = { kind = "nobag" } }
		local c1, t1 = EX.blocked(nil, packed, gap)
		check("extract nobag: a worn backpack blocks the exit, an empty back slot does not", c1 == "BACKPACK" and type(t1) == "string" and EX.blocked(nil, bare, gap) == nil)
		check("extract nobag: a pack put on during the hold cancels it; other rules are never cancelled that way",
			EX.holdBlocked(packed, gap) == "BACKPACK" and EX.holdBlocked(bare, gap) == nil and EX.holdBlocked(packed, { rule = { kind = "open" } }) == nil)
		-- SHELTER EXIT: the mall power first, then the lever (rule power with `also`); each step reads its own text
		local swA = { id = "T_A", on = false }
		local swB = { id = "T_B", on = false }
		WD.switches.T_A, WD.switches.T_B = swA, swB
		local chain = { id = "T_SE", rule = { kind = "power", switch = "T_B", also = "T_A", needs = "B TEXT", needsAlso = "A TEXT" } }
		local ca, ta = EX.blocked(nil, bare, chain)
		swA.on = true
		local cb, tb = EX.blocked(nil, bare, chain)
		swB.on = true
		local cc = EX.blocked(nil, bare, chain)
		local plain = { id = "T_P", rule = { kind = "power", switch = "T_A", needs = "A TEXT" } }
		swA.on = false
		local cd, td = EX.blocked(nil, bare, plain)
		WD.switches.T_A, WD.switches.T_B = nil, nil
		check("extract power chain: no power says the first text, power without the lever the second, both on opens it; a plain power rule still reads its switch",
			ca == "POWER" and ta == "A TEXT" and cb == "POWER" and tb == "B TEXT" and cc == nil and cd == "POWER" and td == "A TEXT")
		-- minefield: a live charge answers within its radius, a spent one does not, a new raid arms it again
		local mined = HZ.mineField({ Vector3.new(7000, 2000, 7000), Vector3.new(7100, 2000, 7000) })
		local near = HZ.mineNear(Vector3.new(7001.5, 2000.4, 7001.5))
		local far = HZ.mineNear(Vector3.new(7000 + HZ.MINE_R + 2, 2000, 7000))
		local below = HZ.mineNear(Vector3.new(7000, 1980, 7000))
		local okBoom = near ~= nil and pcall(HZ.detonate, near, nil, nil)
		local spent = near ~= nil and near.live == false and HZ.mineNear(Vector3.new(7000, 2000, 7000)) == nil
		HZ.reset()
		local rearmed = near ~= nil and near.live == true and HZ.mineNear(Vector3.new(7000, 2000, 7000)) == near
		for i = #HZ.mines, 1, -1 do
			if HZ.mines[i] == mined then
				table.remove(HZ.mines, i)
			end
		end
		check("minefield: a live charge answers within its radius (not beyond it or far below), a spent one is silent, a new raid arms it again",
			near ~= nil and far == nil and below == nil and okBoom and spent and rearmed and #mined.list == 2)
		-- the keys the rebuild added: real key items with a door id, in the mall key pool, all of them found by the Caretaker's loadout or the pool
		local mmKeys = { "KEY_MM_IRON_FRONT", "KEY_MM_IRON_GRATE", "KEY_MM_RESCUE", "KEY_MM_NESTA_REG", "KEY_MM_KASSA_REG", "KEY_MM_BOLT_REG", "KEY_MM_BOLT_OFFICE", "KEY_MM_BOLT_GOODS", "KEY_MM_SUBSTATION", "KEY_MM_UNIT14" }
		local okMM, pooledMM = true, {}
		for _, e in Loot.POOLS.mallkeys do
			pooledMM[e.id] = true
		end
		for _, id in mmKeys do
			local d = Items.defs[id]
			okMM = okMM and d ~= nil and d.kind == "key" and d.key ~= nil and type(d.key.door) == "string" and (d.key.uses or 0) > 0 and pooledMM[id] == true
		end
		check("meridian keys: ten KEY_MM_* items exist with a door id and uses, all in the mall key pool; UNIT 14 is a keycard", okMM and Items.defs.KEY_MM_UNIT14.key.card == true and Items.defs.CARD_MALL_VAULT.key.door == "mm_shelter")
		-- the map as built (skipped when it did not build): rules, sides, spawns, boss
		local mm = WD.maps and WD.maps.meridian
		if mm then
			local ex = mm.extracts or {}
			local se, fg = ex.SE, ex.FG
			check("meridian extracts: seven, the shelter reads power (the lever as a second step when it exists), the fence gap needs an empty back slot",
				ex.RS and ex.RC and ex.SC and ex.WC and ex.RP and se and fg and fg.rule.kind == "nobag" and se.rule.kind == "power" and se.rule.switch ~= nil
				and (se.rule.switch == "MALL_POWER" or (se.rule.switch == "SHELTER_SWITCH" and se.rule.also == "MALL_POWER")))
			local has = function(list, id)
				for _, v in list or {} do
					if v == id then
						return true
					end
				end
				return false
			end
			local nw, sw = mm.sideExtracts and mm.sideExtracts.nw, mm.sideExtracts and mm.sideExtracts.se
			check("meridian sides: MallNW gets the rescue checkpoint, MallSE the rail siding, both the substation car, the shelter, the river path, the fence gap and the west camp (co-op, a PMC with a scav)",
				has(nw, "RC") and not has(nw, "RS") and has(sw, "RS") and not has(sw, "RC") and has(nw, "SC") and has(sw, "SC") and has(nw, "SE") and has(sw, "SE")
				and has(nw, "RP") and has(sw, "RP") and has(nw, "FG") and has(sw, "FG") and has(nw, "WC") and has(sw, "WC") and ex.WC.rule.kind == "coop")
			local sideOk, nN, nS = true, 0, 0
			for _, sp in mm.spawns or {} do
				sideOk = sideOk and (sp.side == "nw" or sp.side == "se") and sp.extracts == mm.sideExtracts[sp.side]
				if sp.side == "nw" then
					nN += 1
				else
					nS += 1
				end
			end
			check("meridian spawns: one group per reference cluster on its own half, each with its side's exits", sideOk and nN >= 8 and nS >= 8)
			local b = mm.boss
			check("meridian boss: THE CARETAKER at 60 percent with zones to choose from, or none when the shell is missing (the AI reads chance and zones)",
				b == nil or (b.name == "THE CARETAKER" and b.chance == 0.6 and b.look == "bodyguard" and b.loadout == "caretakerLoadout" and #(b.zones or {}) >= 1 and b.zones[1].home ~= nil and #b.zones[1].route >= 3))
			local posted = true
			for _, wp in mm.watchPosts or {} do
				posted = posted and mm.patrols[wp.route] ~= nil and wp.kind == "scav"
			end
			check("meridian guards: every watch post has its route, scav zones plentiful", posted and #(mm.scavZones or {}) >= 10)
			check("meridian hazards: a minefield on the west band", #HZ.mines >= 1)
		end
	end

	-- Car exits (Tarkov's V-Ex, docs/design/EFT_PARITY.md "Car exits"): the per-raid roll covers paid cars; the fare is paid at the car
	-- (refused without the money, for a fifth passenger, for a scav, outside a raid, when the car is not there or has left); the first
	-- fare starts one countdown that later passengers join; the departure takes the seated passengers inside the zone, leaves the
	-- others without a refund and closes the exit for good. No raid and no map are needed: the raiders are stand-in tables with a
	-- profile of their own and a tiny character, the car is a stand-in exit that lives only here (registered in World.extracts for the
	-- time of the checks, which never yield), and the car state is swapped for a private table. WRITTEN 2026-11-01, NOT RUN yet.
	if ctx and ctx.Extract and ctx.Match and ctx.Profiles and ctx.World and ctx.Raid then
		local EX, WD, MT, PF = ctx.Extract, ctx.World, ctx.Match, ctx.Profiles
		-- the roll
		local rule = { kind = "paid", cost = 20000, chance = 0.5, seats = 4, depart = 60 }
		check("car roll: a paid rule with a chance rolls it; a plain paid rule, an open exit and a lucky chance exit are there",
			EX.rollOpen(rule, 0.3) == true and EX.rollOpen(rule, 0.7) == false and EX.rollOpen({ kind = "paid", cost = 8000 }, 0.99) == true
			and EX.rollOpen({ kind = "chance", chance = 0.6 }, 0.7) == false and EX.rollOpen({ kind = "chance", chance = 0.6 }, 0.5) == true
			and EX.rollOpen({ kind = "open" }, 0.99) == true)
		local sample = { CAR = { rule = rule }, BOAT = { rule = { kind = "paid", cost = 8000 } }, GATE = { rule = { kind = "open" } }, HOLE = { rule = { kind = "chance", chance = 0.5 } } }
		local lowRoll = MT.rollExtracts(sample, function()
			return 0.1
		end)
		local highRoll = MT.rollExtracts(sample, function()
			return 0.9
		end)
		check("car roll: Match rolls the car with the other chance exits (all there on a low roll; on a high one the car and the chance exit are gone, the boat and the gate stay)",
			lowRoll.CAR == true and lowRoll.BOAT == true and lowRoll.GATE == true and lowRoll.HOLE == true
			and highRoll.CAR == false and highRoll.HOLE == false and highRoll.BOAT == true and highRoll.GATE == true)
		-- the cars as the maps built them (skipped for a map that did not build)
		for _, spec in { { "border", "DC" }, { "meridian", "SC" } } do
			local me = WD.maps and WD.maps[spec[1]] and WD.maps[spec[1]].extracts and WD.maps[spec[1]].extracts[spec[2]]
			if me then
				local r = me.rule
				local rig = me.carRig
				check("car exits: " .. spec[2] .. " is a paid car with a 50 percent chance, 4 seats and a 60 s countdown",
					r.kind == "paid" and (r.cost or 0) > 0 and r.chance == 0.5 and r.seats == 4 and r.depart == 60 and EX.isCar(me))
				check("car exits: " .. spec[2] .. " has its car and a held fare prompt that names the fare and the exit",
					rig ~= nil and rig.prompt ~= nil and rig.prompt.HoldDuration > 0 and string.find(rig.prompt.ActionText, "Pay ", 1, true) == 1
					and string.find(rig.prompt.ActionText, Config.CURRENCY, 1, true) ~= nil and rig.prompt.ObjectText == me.name)
			end
		end
		-- the stand-ins
		local zonePos = Vector3.new(9000, 3000, 9000)
		local car = {
			id = "T_CAR", name = "TEST CAR", pos = zonePos, size = Vector3.new(26, 12, 26), cf = CFrame.new(zonePos + Vector3.new(0, 6, 0)),
			rule = { kind = "paid", cost = 20000, chance = 0.5, seats = 4, depart = 60 },
		}
		local models, players = {}, {}
		local function raider(name, money, offset, hp)
			local model = Instance.new("Model")
			local hum = Instance.new("Humanoid")
			hum.Health = hp or 100
			hum.Parent = model
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Position = zonePos + offset
			root.Parent = model
			table.insert(models, model)
			local p = { Name = name, DisplayName = name, Character = model }
			PF.attachTest(p, { money = money })
			table.insert(players, p)
			return p, { done = false, state = "ACTIVE", scav = false, extracts = { "T_CAR" } }
		end
		local sent, finished = {}, {}
		local realNotify, realFinalize, realCars = EX.notify, ctx.Raid.finalize, EX.cars
		EX.notify = function(p, kind, data)
			table.insert(sent, { p = p, kind = kind, data = data })
		end
		ctx.Raid.finalize = function(p, outcome)
			table.insert(finished, { p = p, outcome = outcome })
		end
		EX.cars = {}
		MT.extractOpen.T_CAR = true
		WD.extracts.T_CAR = car
		local okCar, errCar = pcall(function()
			local t0 = 5000
			local anna, sAnna = raider("Anna", 50000, Vector3.new(2, 1, 3))
			local boris, sBoris = raider("Boris", 30000, Vector3.new(-3, 1, 1))
			local dmitri, sDmitri = raider("Dmitri", 50000, Vector3.new(40, 1, 0)) -- pays, then wanders off
			local elena, sElena = raider("Elena", 50000, Vector3.new(0, 1, -2)) -- pays, then is killed
			local fyodor, sFyodor = raider("Fyodor", 50000, Vector3.new(1, 1, 1)) -- arrives when the car is full
			local broke, sBroke = raider("Broke", 100, Vector3.new(1, 1, 1))
			local infoBefore = ctx.Raid.raidInfo({ extracts = { "T_CAR" } }).extracts[1]
			check("car list: the exit list shows the car as paid with a chance (like a chance exit), 4 seats, and not closed",
				infoBefore.rule == "paid" and infoBefore.cost == 20000 and infoBefore.chance == true and infoBefore.seats == 4 and infoBefore.closed == nil)
			-- a scav's list has every exit but the cars (Tarkov's V-Ex is for PMCs) and the PMC-only ones (who = "pmc"); the
			-- stand-in is a car like the real ones
			local nAll, nCars, nPmc = 0, 0, 0
			for _, we in WD.extracts do
				nAll += 1
				if EX.isCar(we) then
					nCars += 1
				elseif we.rule and we.rule.who == "pmc" then
					nPmc += 1
				end
			end
			local scavList = MT.extractsFor({ extracts = {} }, true)
			local pmcOnlyIn = false
			for _, id in scavList do
				pmcOnlyIn = pmcOnlyIn or ((WD.extracts[id].rule or {}).who == "pmc")
			end
			check("car scavs: a scav's exit list has every exit but the cars (the stand-in car is left out) and the PMC-only ones",
				table.find(scavList, "T_CAR") == nil and #scavList == nAll - nCars - nPmc and nCars >= 1 and not pmcOnlyIn
					and (ctx.World.activeMap ~= "border" or nPmc == 2))

			-- no money, no seat
			local okBroke, whyBroke = EX.pay(broke, sBroke, car, t0)
			local cs0 = EX.cars.T_CAR
			check("car fare: no money, no seat (refused as MONEY, nothing taken, no seat, no countdown started)",
				okBroke == false and whyBroke == "MONEY" and PF.get(broke).money == 100 and (cs0 == nil or (#cs0.seats == 0 and cs0.departAt == nil)))
			-- the zone only says where to pay
			local hint, hintText = EX.blocked(anna, sAnna, car)
			check("car zone: standing in it without a seat gives the hint PAY AT THE CAR (no hold for a car)", hint == "PAY" and hintText == "PAY AT THE CAR")

			-- the first fare
			local ok1 = EX.pay(anna, sAnna, car, t0)
			local cs = EX.cars.T_CAR
			check("car fare: the money goes at once, the payer holds a seat and the first fare starts the countdown",
				ok1 == true and PF.get(anna).money == 30000 and cs ~= nil and #cs.seats == 1 and cs.departAt == t0 + 60)
			local note = sent[#sent]
			check("car countdown: the payer gets the extract note flagged car, with the shared end time, the length and the seat",
				note ~= nil and note.p == anna and note.kind == "extract" and note.data.state == "start" and note.data.car == true and note.data.zone == "T_CAR"
				and note.data.ends == t0 + 60 and note.data.total == 60 and note.data.seat == 1 and note.data.seats == 4)
			check("car zone: a passenger waiting in the zone is not blocked or told anything", (EX.blocked(anna, sAnna, car)) == nil)
			-- a later passenger joins the same countdown
			local ok2 = EX.pay(boris, sBoris, car, t0 + 20)
			check("car fare: a later passenger joins the same countdown (the end time does not move, theirs is the same)",
				ok2 == true and PF.get(boris).money == 10000 and #cs.seats == 2 and cs.departAt == t0 + 60 and sent[#sent].p == boris and sent[#sent].data.ends == t0 + 60)
			local okAgain, whyAgain = EX.pay(anna, sAnna, car, t0 + 21)
			check("car fare: a passenger who pays again is refused and charged nothing", okAgain == false and whyAgain == "SEATED" and PF.get(anna).money == 30000 and #cs.seats == 2)

			-- four seats
			EX.pay(dmitri, sDmitri, car, t0 + 30)
			EX.pay(elena, sElena, car, t0 + 31)
			local okFull, whyFull = EX.pay(fyodor, sFyodor, car, t0 + 32)
			check("car seats: four seats, and the fifth fare is refused as FULL and charged nothing",
				#cs.seats == 4 and okFull == false and whyFull == "FULL" and PF.get(fyodor).money == 50000)
			check("car zone: a full car says so to the one without a seat", (EX.blocked(fyodor, sFyodor, car)) == "FULL")

			-- the other refusals
			local _, whyScav = EX.pay(fyodor, { done = false, scav = true, extracts = { "T_CAR" } }, car, t0 + 33)
			local _, whyNone = EX.pay(fyodor, nil, car, t0 + 33)
			local _, whyDone = EX.pay(fyodor, { done = true, scav = false, extracts = { "T_CAR" } }, car, t0 + 33)
			local _, whySide = EX.pay(fyodor, { done = false, scav = false, extracts = { "OTHER" } }, car, t0 + 33)
			MT.extractOpen.T_CAR = false
			local _, whyShut = EX.pay(fyodor, sFyodor, car, t0 + 33)
			local hintShut, textShut = EX.blocked(fyodor, sFyodor, car)
			MT.extractOpen.T_CAR = true
			check("car fare: refused for a scav (PMC only), outside a raid or after it, an exit not on the raider's list, and a car that is not there this raid",
				whyScav == "PMC_ONLY" and whyNone == "NOT_IN_RAID" and whyDone == "NOT_IN_RAID" and whySide == "NOT_OFFERED" and whyShut == "CLOSED"
				and hintShut == "CLOSED" and textShut == "NOT AVAILABLE THIS RAID" and PF.get(fyodor).money == 50000 and #cs.seats == 4)

			-- Elena is killed before the car leaves (her session ends)
			sElena.done = true
			-- nothing happens before the countdown ends
			EX.carTick(t0 + 59)
			check("car departure: nothing happens before the countdown ends", cs.left == false and #finished == 0)
			-- the departure
			local dmitriPaid = PF.get(dmitri).money
			EX.carTick(t0 + 60)
			local leftNotes = {}
			for _, n in sent do
				if n.kind == "extract" and n.data.state == "left" then
					table.insert(leftNotes, n)
				end
			end
			check("car departure: the seated passengers inside the zone extract with SUCCESS (and their session names the exit)",
				#finished == 2 and finished[1].p == anna and finished[1].outcome == "SUCCESS" and finished[2].p == boris and finished[2].outcome == "SUCCESS"
				and sAnna.exZone == "T_CAR" and sBoris.exZone == "T_CAR")
			check("car departure: a passenger outside the zone is left behind and told, with no refund; a dead one is neither taken nor told",
				#leftNotes == 1 and leftNotes[1].p == dmitri and leftNotes[1].data.car == true and PF.get(dmitri).money == dmitriPaid and sDmitri.exZone == nil
				and sElena.exZone == nil)
			-- the exit is closed for the rest of the raid
			local whyGone, textGone = EX.blocked(fyodor, sFyodor, car)
			local okGone, whyGone2 = EX.pay(fyodor, sFyodor, car, t0 + 61)
			local infoAfter = ctx.Raid.raidInfo({ extracts = { "T_CAR" } }).extracts[1]
			check("car departure: the exit is closed for the rest of the raid (zone, fare and exit list all say the car has left)",
				cs.left == true and EX.carLeft(car) and whyGone == "LEFT" and textGone == "THE CAR HAS LEFT" and okGone == false and whyGone2 == "LEFT"
				and PF.get(fyodor).money == 50000 and infoAfter.closed == true and infoAfter.closedText == "THE CAR HAS LEFT")
			EX.carTick(t0 + 90)
			local leftAgain = 0
			for _, n in sent do
				if n.kind == "extract" and n.data.state == "left" then
					leftAgain += 1
				end
			end
			check("car departure: it happens once (a later tick takes nobody else and tells nobody again)", #finished == 2 and leftAgain == 1)
			-- a new raid starts clean
			EX.reset()
			check("car reset: a new raid clears the seats, the countdown and the departure", EX.cars.T_CAR == nil and not EX.carLeft(car) and next(EX.cars) == nil)
		end)
		-- put everything back
		WD.extracts.T_CAR = nil
		MT.extractOpen.T_CAR = nil
		EX.cars, EX.notify, ctx.Raid.finalize = realCars, realNotify, realFinalize
		for _, we in WD.extracts do
			EX.syncCar(we) -- (the reset above showed or hid the real cars by the private state: put them back by the real one)
		end
		for _, p in players do
			PF.detachTest(p)
		end
		for _, m in models do
			m:Destroy()
		end
		if not okCar then
			check("car exits: the checks ran without an error (" .. tostring(errCar) .. ")", false)
		end
	end

	-- atmosphere pass (docs/look/ATMOSPHERE.md): the ambience atlas, the sound maker (silent while the asset id is empty), the
	-- published switch state, the skylight tags, the floors that name their reverb. WRITTEN 2026-11-01, NOT RUN yet.
	do
		local AmbAtlas = require(Shared.AmbAtlas)
		local AmbSound = require(Shared.AmbSound)
		local names = { "room_tone_loop", "elec_hum_loop", "garage_tone_loop", "siren_loop", "generator_loop", "drip_1", "drip_2", "drip_3", "gun_far_1", "gun_far_2", "gun_far_3" }
		local regions, shapeOk, loopsOk = {}, true, true
		for _, n in names do
			local r = AmbAtlas[n]
			local good = type(r) == "table" and type(r[1]) == "number" and type(r[2]) == "number" and r[2] > 0
				and type(r[3]) == "number" and r[3] > 0 and r[3] <= 1 and type(r[4]) == "boolean"
			shapeOk = shapeOk and good
			if good then
				regions[#regions + 1] = r
				loopsOk = loopsOk and (r[4] == (string.find(n, "_loop", 1, true) ~= nil))
			end
		end
		table.sort(regions, function(a, b)
			return a[1] < b[1]
		end)
		local apart = true
		for i = 2, #regions do
			apart = apart and regions[i][1] >= regions[i - 1][1] + regions[i - 1][2] - 0.0001
		end
		check("atmosphere atlas: 11 regions with start, length, gain (0 to 1) and a loop flag, no overlaps, and exactly the _loop ones loop",
			shapeOk and loopsOk and apart and #regions == #names)
		local snd = AmbSound.make("drip_1", {})
		local none = AmbSound.make("no_such_sound", {})
		if snd then
			snd:Destroy()
		end
		check("atmosphere sounds: a Sound is made only once Sounds.AMB_ATLAS is set (silent and error-free while it is empty), an unknown name makes none",
			(snd ~= nil) == AmbSound.ready() and none == nil)
		local enumOk = true
		for _, n in { "NoReverb", "Plain", "Alley", "Room", "Hallway", "StoneRoom", "Auditorium", "Hangar", "ParkingLot", "Bathroom", "StoneCorridor" } do
			enumOk = enumOk and pcall(function()
				return Enum.ReverbType[n]
			end)
		end
		check("atmosphere reverb: every Enum.ReverbType name the controller and the floor marks use exists", enumOk)
		if ctx and ctx.World and ctx.World.publishSwitch then
			local WD = ctx.World
			local seen = nil
			local fake = {
				id = "T_PUB", on = false,
				onChange = function(on)
					seen = on
				end,
			}
			WD.publishSwitch("T_PUB", fake)
			fake.onChange(true)
			local a1, s1 = workspace:GetAttribute("ZR_Sw_T_PUB"), seen
			fake.onChange(false)
			local a2, s2 = workspace:GetAttribute("ZR_Sw_T_PUB"), seen
			workspace:SetAttribute("ZR_Sw_T_PUB", nil)
			check("atmosphere switches: onChange publishes the state as workspace attribute ZR_Sw_<id> and still runs the original",
				a1 == true and s1 == true and a2 == false and s2 == false)
			local lever = WD.switches.MALL_POWER
			local attr = workspace:GetAttribute("ZR_Sw_MALL_POWER")
			check("atmosphere switches: Meridian's power lever is wrapped, and its attribute (once set) matches the lever",
				lever == nil or (lever.published == true and (attr == nil or attr == (lever.on == true))))
		end
		local mm = ctx and ctx.World and ctx.World.maps and ctx.World.maps.meridian
		local mall = mm and mm.model and mm.model:FindFirstChild("Mall")
		if mall then
			local sky, baths, tunnels = 0, 0, 0
			for _, p in game:GetService("CollectionService"):GetTagged("ZR_Skylight") do
				if p:IsDescendantOf(mall) then
					sky += 1
				end
			end
			for _, p in mall:GetDescendants() do
				if p.Name == "UnitFloor" then
					local rv = p:GetAttribute("Reverb")
					if rv == "Bathroom" then
						baths += 1
					elseif rv == "StoneCorridor" then
						tunnels += 1
					end
				end
			end
			check("atmosphere dust and reverb: the mall's roof glass is tagged ZR_Skylight, a washroom floor says Bathroom, the service tunnel's says StoneCorridor",
				sky >= 10 and baths >= 1 and tunnels >= 1)
		end
	end

	-- Breakable glass (docs/design/GLASS.md): the maps tag their panes, every tagged pane has a hit shell that only shots and blows can
	-- meet, a bullet breaks a pane once (one fx event) and goes on past it with a little less damage, a new raid mends it. The
	-- mechanics run on stand-in panes far above the maps, so no raid is needed. WRITTEN 2026-11-01, NOT RUN yet.
	if ctx and ctx.Glass and ctx.Remotes then
		local GL, WD = ctx.Glass, ctx.World
		local Ballistics = require(Shared.Ballistics)
		local AmbAtlas = require(Shared.AmbAtlas)
		local CS = game:GetService("CollectionService")
		local CFG = GL.CFG
		-- the sound atlas: the three glass one-shots are there, and no two regions overlap
		do
			local list, shapeOk = {}, true
			for name, r in AmbAtlas do
				if type(r) == "table" then
					table.insert(list, r)
					if string.find(name, "glass_break_", 1, true) == 1 then
						shapeOk = shapeOk and type(r[1]) == "number" and type(r[2]) == "number" and r[2] >= 1 and r[2] <= 4
							and type(r[3]) == "number" and r[3] > 0 and r[3] <= 1 and r[4] == false
					end
				end
			end
			table.sort(list, function(a, b)
				return a[1] < b[1]
			end)
			local apart = true
			for i = 2, #list do
				apart = apart and list[i][1] >= list[i - 1][1] + list[i - 1][2] - 0.0001
			end
			check("glass sounds: glass_break_1 to 3 are one-shots in the ambience atlas (1 to 4 s, gain up to 1) and no two regions overlap",
				AmbAtlas.glass_break_1 ~= nil and AmbAtlas.glass_break_2 ~= nil and AmbAtlas.glass_break_3 ~= nil and shapeOk and apart)
		end
		check("glass: the collision groups are made and Ballistics uses them (shots and blows are cast in ZR_Shot, which meets the hit shells); the loss is 5 to 10 percent",
			Ballistics.shotGroup == GL.SHOT_GROUP and (Ballistics.through == GL.through or (ctx.Tripwires ~= nil and ctx.Tripwires.prevThrough == GL.through))
				and CFG.keep >= 0.9 and CFG.keep <= 0.95)
		-- how far a ray travels inside a box before it leaves (straight through, 60 degrees off, along the pane, a turned pane, no direction)
		do
			local size = Vector3.new(4, 3, 0.2)
			local c0 = CFrame.new(0, 0, 0)
			local a60 = math.rad(60)
			local d1 = GL.exitDist(c0, size, Vector3.new(0, 0, -0.1), Vector3.new(0, 0, 1))
			local d2 = GL.exitDist(c0, size, Vector3.new(0, 0, -0.1), Vector3.new(math.sin(a60), 0, math.cos(a60)))
			local d3 = GL.exitDist(c0, size, Vector3.new(-2, 0, 0), Vector3.new(1, 0, 0))
			local c1 = CFrame.new(10, 5, 3) * CFrame.Angles(0, math.rad(90), 0)
			local d4 = GL.exitDist(c1, size, c1:PointToWorldSpace(Vector3.new(0, 0, -0.1)), c1:VectorToWorldSpace(Vector3.new(0, 0, 1)))
			local d5 = GL.exitDist(c0, size, Vector3.zero, Vector3.zero)
			check("glass: the way through a pane is 0.2 straight on, 0.4 at 60 degrees, the whole width along it, the same in a turned frame, and 0 (not NaN) without a direction",
				math.abs(d1 - 0.2) < 0.001 and math.abs(d2 - 0.4) < 0.001 and math.abs(d3 - 4) < 0.001 and math.abs(d4 - 0.2) < 0.001 and d5 == 0)
		end
		-- the maps tag their panes
		for _, spec in { { "border", "dorm windows" }, { "meridian", "shop fronts" } } do
			local m = WD and WD.maps and WD.maps[spec[1]]
			if m and m.model then
				local n, glass, shelled = 0, 0, 0
				for _, p in CS:GetTagged(GL.TAG) do
					if p:IsDescendantOf(m.model) then
						n += 1
						if p.Material == Enum.Material.Glass then
							glass += 1
						end
						local e = GL.entryOf(p)
						if e and e.shell and e.shell.Parent ~= nil and e.shell.CanQuery and not e.shell.CanCollide and not p.CanQuery then
							shelled += 1
						end
					end
				end
				check("glass: " .. spec[1] .. "'s " .. spec[2] .. " are tagged ZR_Glass (" .. n .. " panes, all glass, each with a hit shell and no ray stopped by the pane itself)",
					n >= 10 and glass == n and shelled == n)
			end
		end
		check("glass: every tagged pane is in the registry", GL.count() == #CS:GetTagged(GL.TAG))
		-- stand-in panes (4 x 3, 0.1 thick) in a row with a wall 20 studs behind the first; the events the service sends are caught
		local P0 = Vector3.new(0, 3200, 9000)
		local made, sent = {}, {}
		local realFx = ctx.Remotes.fx
		ctx.Remotes.fx = function(kind, data)
			table.insert(sent, { kind = kind, data = data })
		end
		local function plate(z, alpha)
			local p = Instance.new("Part")
			p.Name = "T_Pane"
			p.Anchored = true
			p.Size = Vector3.new(4, 3, 0.1)
			p.CFrame = CFrame.new(P0 + Vector3.new(0, 0, z))
			p.Transparency = alpha
			p.CanCollide = true
			p.CanQuery = true -- like Meridian's shop glass: registering makes it pass ordinary rays
			p.Parent = workspace
			CS:AddTag(p, GL.TAG)
			table.insert(made, p)
			return p
		end
		local function glassEvents()
			local out = {}
			for _, s in sent do
				if s.kind == "glass" then
					table.insert(out, s.data)
				end
			end
			return out
		end
		local okGlass, errGlass = pcall(function()
			local wall = Instance.new("Part")
			wall.Name = "T_Wall"
			wall.Anchored = true
			wall.Size = Vector3.new(12, 12, 1)
			wall.CFrame = CFrame.new(P0 + Vector3.new(0, 0, 20))
			wall.Parent = workspace
			table.insert(made, wall)
			local pane = plate(0, 0.5)
			local e = GL.register(pane)
			check("glass: registering a pane makes its hit shell (invisible, not solid, only queryable, in its own group); the pane keeps blocking movement and stops no ray",
				e ~= nil and e.shell ~= nil and e.shell.Parent ~= nil and e.shell.CanQuery == true and e.shell.CanCollide == false and e.shell.Transparency == 1
				and e.shell.CollisionGroup == GL.GROUP and e.shell.Size.Z >= CFG.minThick - 0.0001 and pane.CanCollide == true and pane.CanQuery == false)
			if not e then
				return
			end
			local from, fwd = P0 + Vector3.new(0, 0, -10), Vector3.new(0, 0, 1)
			local rp0 = RaycastParams.new()
			rp0.FilterType = Enum.RaycastFilterType.Exclude
			rp0.FilterDescendantsInstances = {}
			local function cast(group)
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = {}
				if group then
					rp.CollisionGroup = group
				end
				return workspace:Raycast(from, fwd * 40, rp)
			end
			local plain, shot, sight = cast(nil), cast(Ballistics.shotGroup), cast(GL.SIGHT_GROUP)
			local castOk = sight ~= nil and sight.Instance.Name == "T_Wall" and shot ~= nil and shot.Instance == e.shell and plain ~= nil and plain.Instance == pane
			check("glass: a sight ray (the AI's group) passes a whole pane and its shell and reaches the wall; a shot meets the shell; an ordinary ray meets the pane (Roblox ignores CanQuery on a part that collides)"
				.. (castOk and "" or string.format(" [sight %s, shot %s, plain %s, pane group %s]", sight and sight.Instance:GetFullName() or "nil",
					shot and shot.Instance:GetFullName() or "nil", plain and plain.Instance:GetFullName() or "nil", pane.CollisionGroup)),
				castOk)
			local k1, f1 = nil, nil
			if shot then
				k1, f1 = GL.through(shot, fwd, false)
			end
			check("glass: through() answers a shell with the share kept and the way to just past it, nothing for any other part, and an effects trace breaks nothing",
				k1 == CFG.keep and type(f1) == "number" and f1 > CFG.nudge and f1 < 1 and plain ~= nil and GL.through(plain, fwd, false) == nil and not GL.isBroken(pane))
			local tres, tpos, tdist = Ballistics.trace(from, fwd, 2000, 0.1, 60, rp0)
			check("glass: the effects trace goes on past a pane to what lies behind, along the same line, and leaves the pane whole",
				tres ~= nil and tres.Instance.Name == "T_Wall" and math.abs(tdist - 29.5) < 1 and math.abs(tpos.X - from.X) < 0.05 and math.abs(tpos.Y - from.Y) < 0.5
				and not GL.isBroken(pane) and pane.Transparency == 0.5)
			-- a bullet in flight
			local gotInst, gotPos, gotKeep
			Ballistics.fly(from, fwd, 2000, 0.1, 60, rp0, function(res, pos, _, _, keep)
				gotInst, gotPos, gotKeep = res.Instance, pos, keep
			end)
			local t0 = os.clock()
			while gotKeep == nil and os.clock() - t0 < 2 do
				task.wait()
			end
			local ev = glassEvents()
			check("glass: a bullet in flight breaks the pane (invisible, no collision, no query, flagged GlassBroken), reaches the wall on the same line with the share kept, and one glass event carries the pane's size and the shot's direction",
				gotInst ~= nil and gotInst.Name == "T_Wall" and gotKeep ~= nil and math.abs(gotKeep - CFG.keep) < 0.000001 and math.abs(gotPos.X - from.X) < 0.05
				and GL.isBroken(pane) and pane.Transparency == 1 and pane.CanCollide == false and pane.CanQuery == false and e.shell.CanQuery == false
				and pane:GetAttribute("GlassBroken") == true and #ev == 1 and ev[1].sz == pane.Size and typeof(ev[1].d) == "Vector3"
				and (ev[1].d - fwd).Magnitude < 0.05 and typeof(ev[1].h) == "Vector3" and typeof(ev[1].cf) == "CFrame")
			local after = cast(Ballistics.shotGroup)
			check("glass: a broken pane stops nothing, not even a shot, breaking it again does nothing and sends nothing",
				after ~= nil and after.Instance.Name == "T_Wall" and GL.shatter(e, shot and shot.Position or P0, fwd) == false and #glassEvents() == 1)
			-- a new raid mends it
			local mended = GL.reset()
			local again = cast(Ballistics.shotGroup)
			check("glass: reset mends the pane as the map built it (look, collision, no ray stopped), and a shot meets its shell again",
				mended >= 1 and not GL.isBroken(pane) and pane.Transparency == 0.5 and pane.CanCollide == true and pane.CanQuery == false and e.shell.CanQuery == true
				and pane:GetAttribute("GlassBroken") == nil and again ~= nil and again.Instance == e.shell)
			-- a blow
			local wallHit = cast(nil)
			check("glass: a blow at a shell breaks the pane and is spent on it; a blow at anything else is not a pane",
				GL.blow(e.shell, e.shell.Position, fwd, nil) == true and GL.isBroken(pane) and wallHit ~= nil and GL.blow(wallHit.Instance, wallHit.Position, fwd, nil) == false)
			GL.reset()
			-- three panes in a row: one bullet breaks them all and keeps the share three times over
			local pane2, pane3 = plate(5, 0.4), plate(10, 0.3)
			local e2, e3 = GL.register(pane2), GL.register(pane3)
			gotInst, gotPos, gotKeep = nil, nil, nil
			Ballistics.fly(from, fwd, 2000, 0.1, 60, rp0, function(res, pos, _, _, keep)
				gotInst, gotPos, gotKeep = res.Instance, pos, keep
			end)
			t0 = os.clock()
			while gotKeep == nil and os.clock() - t0 < 2 do
				task.wait()
			end
			check("glass: one bullet through three panes breaks all three, reaches the wall and keeps the share to the third power",
				e2 ~= nil and e3 ~= nil and gotInst ~= nil and gotInst.Name == "T_Wall" and gotKeep ~= nil and math.abs(gotKeep - CFG.keep ^ 3) < 0.000001
				and GL.isBroken(pane) and GL.isBroken(pane2) and GL.isBroken(pane3) and math.abs(gotPos.X - from.X) < 0.05)
			GL.reset()
		end)
		-- put everything back
		ctx.Remotes.fx = realFx
		GL.reset()
		for _, p in made do
			GL.unregister(p)
			p:Destroy()
		end
		if not okGlass then
			check("glass: the checks ran without an error (" .. tostring(errGlass) .. ")", false)
		end
	end

	-- ui-7a: no public text chat in a raid (Tarkov has none); the squad channel reaches the squad only (Chat.luau). The
	-- raid and squad lookups are stood in for while the checks run (they do not yield)
	if ctx.Chat then
		local Chat = ctx.Chat
		local A, B, C = {}, {}, {}
		local oldS, oldQ = ctx.Raid.session, ctx.Match.squadOf
		local inR, sq = { [A] = { done = false } }, { [A] = "s1", [B] = "s1" }
		ctx.Raid.session = function(p)
			return inR[p]
		end
		ctx.Match.squadOf = function(p)
			return sq[p]
		end
		local okPub = Chat.allowPublic(B, C) and not Chat.allowPublic(A, B) and not Chat.allowPublic(B, A)
		local okSq = Chat.allowSquad(A, B) and Chat.allowSquad(B, A) and not Chat.allowSquad(A, C) and Chat.allowSquad(C, C)
		ctx.Raid.session, ctx.Match.squadOf = oldS, oldQ
		check("chat: the public channel only between two players in the bunker", okPub)
		check("chat: the squad channel reaches the sender and the squad, nobody else", okSq)
	end

	local summary = string.format("%d passed, %d failed", passed, failed) .. (skipped > 0 and string.format(", %d skipped (maps not built on this server)", skipped) or "")
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

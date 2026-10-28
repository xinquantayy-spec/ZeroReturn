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
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
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
	local raidInv = Settle.deploy(prof, "raid1", 1)
	check("deploy reserves loadout", raidInv ~= nil and prof.pendingRaid ~= nil and next(prof.slots) == nil and prof.pendingRaid.secure ~= nil)
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

	-- weapon modding (mounts, caliber-specific muzzle devices, swaps return the old part, slot drops)
	do
		local h = Settle.newProfile()
		local rifle, pistol = h.slots.primary, h.slots.holster
		local function stash(id)
			local g, it = Inv.newItem(id)
			local okP = Inv.place(h, g, it, { "stash" })
			return okP and g or nil
		end
		local dot, scope, supp9, supp62, light = stash("RED_DOT"), stash("SCOPE_4X"), stash("SUPP_9"), stash("SUPP_62"), stash("LIGHT_T")
		check("mods placed", dot and scope and supp9 and supp62 and light and true)
		check("9mm suppressor refused on 6.2 rifle", select(2, Inv.attachMod(h, rifle, supp9, { "stash" })) == "WRONG_CALIBER")
		check("rail optic refused on pistol", select(2, Inv.attachMod(h, pistol, dot, { "stash" })) == "NO_MOUNT")
		check("suppressor installs", (Inv.attachMod(h, rifle, supp62, { "stash" })) and h.items[rifle].mods.muzzle == supp62 and Inv.locate(h, supp62) == "mod")
		check("reflex installs", (Inv.attachMod(h, rifle, dot, { "stash" })) and inv(h))
		check("scope swaps reflex back to stash", (Inv.attachMod(h, rifle, scope, { "stash" })) and h.items[rifle].mods.rail == scope and Inv.locate(h, dot) == "grid" and inv(h))
		local ms = Inv.modStats(h, rifle)
		check("mod stats", ms.suppressed and ms.zoom == 4 and ms.loud < 0.5 and ms.recoil < 1)
		check("light via slot drop", (Inv.move(h, light, { slot = "primary" })) and h.items[rifle].mods.side == light and Inv.modStats(h, rifle).light)
		local mass0 = Inv.weight(h)
		check("mods count toward carried weight", mass0 > 0)
		check("detach returns to grid", (Inv.detachMod(h, rifle, "muzzle", { "stash" })) and Inv.locate(h, supp62) == "grid" and Inv.weight(h) < mass0 and inv(h))
		check("detach empty mount fails", select(2, Inv.detachMod(h, rifle, "under", { "stash" })) == "NO_MOD")
		-- weapon with mods moves as one bundle (take/restore keeps attachments)
		local b = Inv.take(h, rifle)
		check("bundle carries mods", b ~= nil and #b.subs >= 3)
		check("bundle restore", b ~= nil and (Inv.give(h, b, nil, { "stash" })) and h.items[rifle].mods.rail == scope and inv(h))
		-- magazine dropped onto the equipped weapon's slot loads it
		local spareMag = stash("P9_MAG")
		local pw = h.items[pistol]
		local oldMag = pw.mag
		check("mag onto holster slot inserts", spareMag ~= nil and (Inv.move(h, spareMag, { slot = "holster" })) and h.items[pistol].mag == spareMag and Inv.locate(h, oldMag) == "grid" and inv(h))
	end

	-- operator rig math (shared by the server hitbox pose and every client's animator)
	do
		local RigMath = require(Shared.RigMath)
		local root = CFrame.new(0, 3.3, 0)
		local chest = CFrame.new(0, 3.835, 0)
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
		local crootY = 3.3 - (RigMath.STAND_HIP - RigMath.hipFor("c", 1))
		local Lc = RigMath.pose(CFrame.new(0, crootY, 0), { stance = "c", depth = 1 })
		local Jr, Jh = RigMath.joints.Root, RigMath.joints.RightHip
		local pelvis = CFrame.new(0, crootY, 0) * CFrame.new(Jr.p0) * Lc.Root * CFrame.new(-Jr.p1)
		local thigh = pelvis * CFrame.new(Jh.p0) * Lc.RightHip * CFrame.new(-Jh.p1)
		local Jk, Ja = RigMath.joints.RightKnee, RigMath.joints.RightAnkle
		local shin = thigh * CFrame.new(Jk.p0) * Lc.RightKnee * CFrame.new(-Jk.p1)
		local ankle = (shin * CFrame.new(Ja.p0)).Position
		check("crouch IK plants the ankle", math.abs(ankle.Y - 0.26) < 0.05)
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
		check("skill levels", P.skillLevel(0) == 0 and P.skillLevel(250) == 2 and P.skillLevel(5000) == 10 and math.abs(P.bonus({ endurance = 500 }, "endurance") - 0.15) < 1e-6)
		local rifle = TD.offers.vos[1]
		check("loyalty discounts prices", TD.price("vos", rifle, 2) < TD.price("vos", rifle, 1) and TD.price("vos", rifle, 1) > Items.defs[rifle.id].value)
		check("ammo offers sell a stack", TD.price("vos", TD.offers.vos[9], 1) == math.ceil(Items.defs["A62_FMJ"].value * 60 * 1.25))
		local chain = { id = "GOLD_CHAIN", n = 1 }
		local who, price = TD.bestBuyer(chain, 0)
		check("best buyer for valuables", who == "hale" and price == math.floor(Items.defs.GOLD_CHAIN.value * 0.5))
		check("quest items are not sold", TD.bestBuyer({ id = "LEDGER", n = 1 }, 0) == nil)
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
			p2.xp = P.xpFor(3)
			E.standing(p2, "vos").spent = 150000
			E.standing(p2, "vos").rep = 0.15
			check("loyalty 2 at level 3 / 150k / 0.15", E.loyalty(p2, "vos") == 2)
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
			check("storage racks add stash rows", p2.hideout.levels.storage == 1 and p2.stashH == 25 and Inv.dims(p2, "stash") == 10 and select(2, Inv.dims(p2, "stash")) == 25)
		end
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

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

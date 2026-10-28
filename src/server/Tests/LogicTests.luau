--!nonstrict
-- Pure-logic regression tests (grid, inventory 2.0, settlement, loot, de-dupe, locks). Run via ZR_Dev "tests".
local Services = script.Parent.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Grid = require(Shared.Grid)
local Items = require(Shared.Items)
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

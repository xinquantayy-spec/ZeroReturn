--!nonstrict
-- Pure-logic regression tests (grid, inventory, settlement, de-dupe, locks). Run in Studio via EFB_Dev "tests".
local Services = script.Parent.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("EFB")
local Grid = require(Shared.Grid)
local Util = require(Shared.Util)
local Inv = require(Services.Inv)
local Settle = require(Services.Settle)
local Loot = require(Services.Loot)

local T = {}

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
	local function one(h, g)
		local ok = Inv.check(h)
		return ok and h.items[g] ~= nil
	end

	-- grid
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
	check("new profile invariant", (Inv.check(p)))
	check("starter rifle equipped", p.slots.primary ~= nil and p.items[p.slots.primary].mag ~= nil)
	check("starter pack equipped", p.slots.bag ~= nil)

	-- moves
	local someMag
	for g, it in p.items do
		if it.id == "R17_MAG" and Inv.locate(p, g) == "pockets" then
			someMag = g
		end
	end
	check("mag in pockets", someMag ~= nil)
	local okMove = Inv.move(p, someMag, { c = "stash", x = 8, y = 5, r = 0 })
	check("move to stash corner", okMove and one(p, someMag))
	local blocked = Inv.move(p, someMag, { c = "stash", x = 8, y = 6, r = 0 })
	check("out of bounds rejected", not blocked)
	check("bag into own pack rejected", not Inv.move(p, p.slots.bag, { c = "bag", x = 1, y = 1, r = 0 }))
	local band = Inv.findKind(p, "heal", { "pockets", "bag" })
	check("dressing in loadout", band ~= nil)
	check("unequip pack with contents rejected", not Inv.move(p, p.slots.bag, { c = "stash", x = 1, y = 6, r = 0 }))
	check("invariant after moves", (Inv.check(p)))

	-- stacking + fill mags
	local g1, a1 = Inv.newItem("UC62", 50)
	local g2, a2 = Inv.newItem("UC62", 30)
	local h = Inv.newHolder(true)
	Inv.place(h, g1, a1, { "stash" })
	Inv.place(h, g2, a2, { "stash" })
	local total = 0
	for _, it in h.items do
		total += it.n
	end
	check("stack merge keeps count", total == 80 and (Inv.check(h)))
	local mg, mi = Inv.newItem("R17_MAG", 1, { a = 0 })
	Inv.place(h, mg, mi, { "stash" })
	local loaded = Inv.fillMags(h)
	check("fill mags loads 25", loaded == 25 and h.items[mg].a == 25 and (Inv.check(h)))

	-- deploy / settle success (idempotent)
	local prof = Settle.newProfile()
	local raidInv = Settle.deploy(prof, "raid1", 1)
	check("deploy reserves loadout", raidInv ~= nil and prof.pendingRaid ~= nil and next(prof.slots) == nil)
	check("deploy twice rejected", Settle.deploy(prof, "raid2", 2) == nil)
	check("profile invariant during raid", (Inv.check(prof)))
	check("raid inventory invariant", (Inv.check(raidInv)))
	local lg, li = Inv.newItem("SEALED_DRIVE", 1)
	check("loot placed in raid bag", (Inv.place(raidInv, lg, li, { "pockets", "bag" })))
	local r1 = Settle.finalize(prof, "raid1", "SUCCESS", raidInv, 3)
	local r2, e2 = Settle.finalize(prof, "raid1", "SUCCESS", raidInv, 4)
	check("success credits loot once", r1 ~= nil and prof.items[lg] ~= nil and r2 == nil and e2 == "ALREADY_FINALIZED")
	check("profile invariant after success", (Inv.check(prof)))
	local drives = 0
	for _, it in prof.items do
		if it.id == "SEALED_DRIVE" then
			drives += 1
		end
	end
	check("no duplicated loot", drives == 1)

	-- KIA loses loadout and loot
	local prof2 = Settle.newProfile()
	local stashCount = Util.count(prof2.stash)
	local inv2 = Settle.deploy(prof2, "raidK", 1)
	local kg, ki = Inv.newItem("DECK_TRANSCEIVER", 1)
	Inv.place(inv2, kg, ki, { "bag", "pockets" })
	local rk = Settle.finalize(prof2, "raidK", "KIA", inv2, 2)
	check("KIA receipt lists losses", rk ~= nil and #rk.lost > 0 and #rk.retained == 0)
	check("KIA leaves loadout empty", next(prof2.slots) == nil and next(prof2.pockets) == nil)
	check("KIA keeps stash, no loot credit", Util.count(prof2.stash) == stashCount and prof2.items[kg] == nil)
	check("recovery kit when weaponless", (Settle.recoveryKit(prof2)) and prof2.slots.primary ~= nil)
	check("recovery kit only once", not Settle.recoveryKit(prof2))
	check("invariant after recovery", (Inv.check(prof2)))

	-- disconnect recovery (no raid inventory available)
	local prof3 = Settle.newProfile()
	Settle.deploy(prof3, "raidD", 1)
	local rd = Settle.finalize(prof3, "raidD", "DISCONNECTED", nil, 2)
	check("disconnect settles as loss", rd ~= nil and prof3.pendingRaid == nil and #rd.lost > 0)

	-- container claim atomicity
	local c = { items = Loot.roll(Random.new(1), "crate", 3) }
	local target = c.items[1].g
	local hA, hB = Inv.newHolder(false), Inv.newHolder(false)
	local okA = Loot.claim(c, target, hA)
	local okB, eB = Loot.claim(c, target, hB)
	check("same GUID claimed once", okA and not okB and eB == "GONE" and hB.items[target] == nil)

	-- remote de-dupe: same rid executes once
	if ctx and ctx.Remotes then
		local calls = 0
		ctx.Remotes.onReq("__test", function()
			calls += 1
			return ctx.Remotes.ok(calls)
		end, 100, 100)
		local fake = { Name = "test" }
		local a = ctx.Remotes.dispatch(fake, "__test", { rid = "X1" })
		local b = ctx.Remotes.dispatch(fake, "__test", { rid = "X1" })
		local bad = ctx.Remotes.dispatch(fake, "__test", { rid = "X2", nested = { a = { b = { c = { d = 1 } } } } })
		check("rid de-dupe", calls == 1 and a == b)
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

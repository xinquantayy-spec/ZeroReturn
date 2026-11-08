--!nonstrict
-- Recovery checks for decision gameplay-6b, "Tarkov's rules, scaled times": the three insurers (prices, windows, storage),
-- old saves' insurance, claims filed, held and lost, the MIA rule, 30 % health after death or MIA, out-of-raid recovery,
-- HALE's treatment prices and the scav cooldown. Pure rules and profile transactions only (no raid, no player needed).
-- Run via ZR_Dev "tests" (every module in Tests). EFT's figures: EFT wiki Insurance and Health system (see Config.luau,
-- TraderData.INSURERS and TraderData.TREATMENT).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Services = script.Parent.Parent:WaitForChild("Services")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Progress = require(Shared.Progress)
local TD = require(Shared.TraderData)
local Inv = require(Services.Inv)
local Settle = require(Services.Settle)
local Health = require(Services.Health)

local T = {}

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

-- a loose item as Match.collectInsured hands it over: { g, it, subs }
local function bundle(id, extra)
	local g, it = Inv.newItem(id, 1, extra)
	return { g = g, it = it, subs = {} }
end

local function guidOf(p, id)
	for g, it in p.items do
		if it.id == id then
			return g
		end
	end
	return nil
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
	local function guard(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(label .. ": the checks ran without an error (" .. tostring(err) .. ")", false)
		end
	end
	local half = function()
		return 0.5
	end

	-- ── the insurers: EFT's hours divided by one constant each, prices as multiples of VOS's ─────────────────────────
	guard("insurers", function()
		check("three insurers in EFT's order: VOS (Prapor), HALE (Therapist), BRAM (Jaeger)", table.concat(TD.INSURER_LIST, ",") == "vos,hale,bram")
		local v1, v2, vh = TD.insureWindow("vos")
		local h1, h2, hh = TD.insureWindow("hale")
		local b1, b2, bh = TD.insureWindow("bram")
		check("VOS returns in 2-3 h and holds 24 h (EFT's Prapor 24-36 h / 12, 4 days / 4)", v1 == 7200 and v2 == 10800 and vh == 86400)
		check("HALE returns in 1-2 h and holds 36 h (EFT's Therapist 12-24 h / 12, 6 days / 4)", h1 == 3600 and h2 == 7200 and hh == 129600)
		check("BRAM returns in 10-20 min and holds 24 h", b1 == 600 and b2 == 1200 and bh == 86400)
		check("the constants: returns / 12, storage / 4", Config.INSURANCE_RETURN_DIV == 12 and Config.INSURANCE_HOLD_DIV == 4 and v1 * 12 == 24 * 3600 and vh * 4 == 96 * 3600)
		local s1, s2 = TD.insureSpan("bram")
		check("the screens' words: BRAM 10-20 MIN, held 24 H; VOS 2-3 H", s1 == "10-20 MIN" and s2 == "24 H" and (TD.insureSpan("vos")) == "2-3 H")
		local gold = { id = "GOLD_CHAIN", n = 1 }
		local vos = TD.insurePrice("vos", gold)
		check("VOS charges today's rate: 7 % of the value", vos == math.max(Config.INSURANCE_MIN, math.floor(Items.valueOf(gold) * Config.INSURANCE_RATE)) and Config.INSURANCE_RATE == 0.07)
		check("HALE charges 1.33x VOS's price, BRAM 2.5x", TD.insurePrice("hale", gold) == math.floor(vos * 1.33) and TD.insurePrice("bram", gold) == math.floor(vos * 2.5))
		check("the cheapest item still costs VOS's minimum", TD.insurePrice("vos", { id = "BOLTS", n = 1 }) >= Config.INSURANCE_MIN)
		local full = { id = "R17_MAG", n = 1, a = 25, at = "A62_FMJ" }
		local empty = { id = "R17_MAG", n = 1, a = 0 }
		check("rounds in a magazine are not insured, so not paid for", TD.insurePrice("vos", full) == TD.insurePrice("vos", empty))
		check("Charisma takes its share off the sum", TD.insureTotal("vos", { gold, gold }, 0.1) == math.floor(vos * 2 * 0.9))
		check("an old save's insured item (no insurer) is VOS's; an unknown insurer is VOS too", TD.insurerOf(nil) == "vos" and TD.insurerOf("hale") == "hale" and TD.insurerOf("nobody") == "vos")
	end)

	-- ── insuring: EFT's rules on what can be insured, the chosen insurer, containers ──────────────────────────────────
	guard("insure", function()
		local pr = Settle.newProfile()
		pr.money = 1000000
		local wg = pr.slots.primary
		local mg = pr.items[wg].mag
		local list = { wg }
		Inv.descendants(pr, wg, list)
		local items = {}
		for _, x in list do
			if Settle.insurable(pr, x) then
				table.insert(items, pr.items[x])
			end
		end
		local cost = Settle.insure(pr, wg, 7, "hale")
		check("insure a rifle with HALE: her price for it and its parts", cost == TD.insureTotal("hale", items, 0))
		check("the rifle and its magazine carry the owner and the insurer", pr.items[wg].ins == 7 and pr.items[wg].isr == "hale" and pr.items[mg].ins == 7 and pr.items[mg].isr == "hale")
		check("an unknown insurer is refused", select(2, Settle.insure(pr, pr.slots.armor, 7, "nobody")) == "NO_INSURER")
		check("left out, the insurer is VOS (old clients)", Settle.insure(pr, pr.slots.armor, 7) ~= nil and pr.items[pr.slots.armor].isr == "vos")
		-- a container insures what can be insured inside it (EFT); consumables stay uninsured
		local bag = pr.slots.back
		local bg, bit = Inv.newItem("BOLTS", 1)
		check("a bag of bolts goes into the pack", Inv.place(pr, bg, bit, { bag }) == true)
		check("insure the pack with BRAM", Settle.insure(pr, bag, 7, "bram") ~= nil)
		local water = nil
		for _, x in Inv.descendants(pr, bag) do
			if pr.items[x].id == "WATER" then
				water = x
			end
		end
		check("the pack's bolts are insured with it; its water is not (EFT: food, meds and ammo cannot be)", pr.items[bag].isr == "bram" and pr.items[bg].ins == 7 and pr.items[bg].isr == "bram" and water ~= nil and pr.items[water].ins == nil)
		check("melee weapons, meds, food, ammo and keys cannot be insured", not Settle.insurable(pr, pr.slots.melee) and not Settle.insurable(pr, water)
			and not Settle.insurable(pr, guidOf(pr, "BANDAGE")) and not Settle.insurable(pr, guidOf(pr, "A62_FMJ")))
		local kg, kit = Inv.newItem("KEY_OFFICE", 1)
		local rg, rit = Inv.newItem("RITUAL_KNIFE", 1)
		Inv.place(pr, kg, kit, { "stash" })
		Inv.place(pr, rg, rit, { "stash" })
		check("a key cannot be insured, the cult's knife can (EFT's Cultist knife)", not Settle.insurable(pr, kg) and Settle.insurable(pr, rg))
		local q = Settle.insureQuote(pr, 7)
		check("the deploy screen's quote: each insurer's price, VOS's as the cost", q.by and q.by.vos == q.cost and (q.n == 0 or (q.by.hale > q.by.vos and q.by.bram > q.by.hale)))
		local all = Settle.insureAll(pr, 7, "vos")
		check("INSURE ALL with VOS charges the quote", q.n == 0 or all == q.cost)
	end)

	-- ── claims: filed by insurer, held, lost after the storage time ──────────────────────────────────────────────────
	guard("claims", function()
		local pr = Settle.newProfile()
		-- an old save's pending return (ins without an insurer) and Match's new ones (readyAt = when the gear was lost)
		local old = bundle("GOLD_CHAIN", { ins = 7 })
		local mag = bundle("R17_MAG", { ins = 7, isr = "hale", a = 25, at = "A62_FMJ" })
		local fast = bundle("HELMET_C2", { ins = 7, isr = "bram" })
		local reward = bundle("BOLTS")
		pr.claims = { { readyAt = 1000, bundles = { old, mag, fast }, raid = "R1" }, { readyAt = 0, bundles = { reward }, raid = "task:V1" } }
		local filed = Settle.fileClaims(pr, 5000, half)
		local by = {}
		for _, c in pr.claims do
			by[c.isr or "task"] = c
		end
		check("one raid's return is split by insurer (three returns), the task reward is left alone", filed == 3 and #pr.claims == 4 and by.task and by.task.isr == nil and by.task.readyAt == 0)
		check("an old save's insured item comes back through VOS", by.vos and by.vos.bundles[1] == old)
		check("VOS: back 2-3 h after the loss (rolled), held 24 h", by.vos.at == 1000 and by.vos.readyAt == 1000 + 7200 + 1800 and by.vos.exp == by.vos.readyAt + 86400)
		check("HALE: 1-2 h, held 36 h; BRAM: 10-20 min, held 24 h", by.hale.readyAt == 1000 + 3600 + 1800 and by.hale.exp == by.hale.readyAt + 129600 and by.bram.readyAt == 1000 + 600 + 300 and by.bram.exp == by.bram.readyAt + 86400)
		check("a magazine comes back without its rounds (EFT)", mag.it.a == 0 and mag.it.at == nil)
		check("every return has its own id", by.vos.id ~= nil and by.hale.id ~= nil and by.vos.id ~= by.hale.id)
		check("filing twice changes nothing", Settle.fileClaims(pr, 5000, half) == 0 and #pr.claims == 4)
		local stray = { readyAt = 0, bundles = { bundle("GOLD_CHAIN", { ins = 7 }) } }
		local pz = Settle.newProfile()
		pz.claims = { stray }
		Settle.fileClaims(pz, 9000, half)
		check("a return with no loss time (the dev tool's readyAt 0) counts from now, not from 1970", pz.claims[1].at == 9000 and pz.claims[1].exp > 9000)
		-- RECEIVE: nothing before the window, one return by its id, the rest after
		local d0 = Settle.claim(pr, 1000 + 600, by.bram.id)
		check("nothing comes before the insurer's window", d0 == 0)
		local d1 = Settle.claim(pr, by.bram.readyAt, by.bram.id)
		check("RECEIVE on one return takes only its items, into the stash, insurance cleared", d1 == 1 and pr.items[fast.g] ~= nil and pr.items[fast.g].ins == nil and pr.items[fast.g].isr == nil and pr.items[old.g] == nil)
		-- the storage time runs out
		local gone = Settle.expireClaims(pr, by.vos.exp)
		check("a return left past its storage time is lost (EFT)", #gone == 1 and gone[1] == by.vos)
		check("a lost return is no longer in the claims", (function()
			for _, c in pr.claims do
				if c == by.vos then
					return false
				end
			end
			return true
		end)())
		local late = { isr = "hale", readyAt = 0, exp = 100, bundles = { bundle("GOLD_CHAIN", { ins = 7 }) }, id = "x" }
		local pl = Settle.newProfile()
		pl.claims = { late }
		check("an expired return is not handed out even before it is swept", Settle.claim(pl, 200) == 0)
		local tasks = Settle.claim(pr, by.hale.readyAt + 1, Settle.isTaskClaim)
		check("the task reward lands by itself; the insurance return waits for RECEIVE ALL", tasks == 1 and pr.items[reward.g] ~= nil and pr.items[mag.g] == nil)
		check("RECEIVE ALL takes the rest", Settle.claim(pr, by.hale.readyAt + 1) == 1 and pr.items[mag.g] ~= nil and #pr.claims == 0)
	end)

	-- ── old saves: a return pending under the old 15-minute rule survives the update ───────────────────────────────────
	guard("old saves", function()
		local p = Settle.newProfile()
		check("a new profile has nothing old to file", p.insv == 2)
		p.insv = nil
		local now = os.time()
		local item = bundle("GOLD_CHAIN", { ins = 7 })
		p.claims = { { readyAt = now - 3 * 86400, bundles = { item }, raid = "OLD" } }
		Settle.migrate(p)
		local c = p.claims[1]
		check("an old save's pending return is filed once, through VOS", p.insv == 2 and #p.claims == 1 and c.isr == "vos")
		check("it keeps the old rule's time and gets the full storage time from the first login", c.readyAt == now - 3 * 86400 and c.exp >= now + 86400 - 5)
		check("and can still be received", Settle.claim(p, now) == 1 and p.items[item.g] ~= nil and p.items[item.g].ins == nil)
		Settle.migrate(p)
		check("migrating again changes nothing", p.insv == 2 and #p.claims == 0)
	end)

	-- ── the MIA rule and the death rule ─────────────────────────────────────────────────────────────────────────────
	guard("mia", function()
		check("MIA: the worn insured kit does not come back (EFT wiki: 'will not bring back insured equipped items')", Settle.kitReturns("MIA") == false)
		check("death and disconnect: the kit stays on the body and comes back at the raid's end unless looted", Settle.kitReturns("KIA") == true and Settle.kitReturns("DISCONNECTED") == true)
	end)

	-- ── health after death or MIA: 30 % of every part ──────────────────────────────────────────────────────────────
	guard("after death", function()
		local function settle(outcome, crashed)
			local pr = Settle.newProfile()
			local raid = Settle.deploy(pr, "D1", 100)
			pr.health = { energy = 55, water = 20 }
			Settle.finalize(pr, "D1", outcome, (not crashed) and raid or nil, 200)
			return pr
		end
		local function thirty(h)
			for _, k in Health.PARTS do
				if not (h and h.parts and near(h.parts[k], Health.MAX[k] * 0.3)) then
					return false
				end
			end
			return true
		end
		local kia, mia, dc = settle("KIA"), settle("MIA"), settle("DISCONNECTED", true)
		check("after death every part is at 30 % of its maximum (EFT)", Config.DEATH_HEALTH == 0.3 and thirty(kia.health))
		check("after MIA too", thirty(mia.health))
		check("a raid lost to a crash too", thirty(dc.health))
		check("energy and water keep the raid's floor of 40; recovery counts from the raid's end", kia.health.energy == 55 and kia.health.water == 40 and kia.health.t == 200)
		local ok = Settle.newProfile()
		local raid = Settle.deploy(ok, "D2", 100)
		local kept = { parts = { head = 20, thorax = 50, stomach = 40, larm = 0, rarm = 60, lleg = 65, rleg = 65 }, energy = 70, water = 70, t = 150 }
		ok.health = kept
		Settle.finalize(ok, "D2", "SUCCESS", raid, 200)
		check("a survivor keeps the wounds they came back with", ok.health == kept and ok.health.parts.larm == 0)
		local sc = Settle.newProfile()
		sc.health = kept
		Settle.deployScav(sc, "D3", 100, Inv.newHolder("raid"))
		Settle.finalize(sc, "D3", "KIA", nil, 200)
		check("a player scav's death leaves the PMC's health alone", sc.health == kept)
	end)

	-- ── out-of-raid recovery: EFT's rates x4, one pool over the damaged parts ───────────────────────────────────────
	guard("recovery", function()
		check("HP: EFT's 456.6 an hour x4 = 1,826.4 an hour", near(Health.OUT_HP_SEC * 3600, 1826.4, 1e-6) and near(Health.OUT_HP_SEC * 3600 / Config.OUT_REGEN_MUL, 456.6, 1e-6))
		check("energy and hydration: EFT's 1 a minute x4", near(Health.OUT_VITALS_SEC * 60, 4))
		local function body()
			return {
				head = { hp = 35, max = 35 }, thorax = { hp = 45, max = 85 }, stomach = { hp = 60, max = 70 }, larm = { hp = 0, max = 60 },
				rarm = { hp = 60, max = 60 }, lleg = { hp = 65, max = 65 }, rleg = { hp = 65, max = 65 },
			}
		end
		local p = body()
		local used = Health.recover(p, 20)
		check("the pool is shared by the damaged parts, not given to each", near(used, 20) and near(p.thorax.hp, 55) and near(p.stomach.hp, 70) and p.head.hp == 35)
		p = body()
		used = Health.recover(p, 30)
		check("what a full part cannot take goes to the others", near(used, 30) and near(p.stomach.hp, 70) and near(p.thorax.hp, 65))
		check("a destroyed part does not come back by itself", p.larm.hp == 0)
		local b = Health.afterDeath({ energy = 50, water = 50 }, 0)
		local start = 0
		for _, k in Health.PARTS do
			start += b.parts[k]
		end
		local hs = { parts = {}, energy = b.energy, water = b.water }
		for _, k in Health.PARTS do
			hs.parts[k] = { hp = b.parts[k], max = Health.MAX[k] }
		end
		local got = Health.recoverFor(hs, 60, 1)
		check("one minute out of raid: 30.44 HP over the body, +4 energy, +4 water", near(got, 1826.4 / 60, 1e-6) and near(hs.energy, 54) and near(hs.water, 54))
		check("the medstation's multiplier works on the HP only", near(Health.recoverFor(hs, 60, 2), 2 * 1826.4 / 60, 1e-6) and near(hs.energy, 58))
		local later = Health.recoverSaved(b, 3600, 1)
		local total = 0
		for _, k in Health.PARTS do
			total += later.parts[k]
		end
		check("an hour away heals a 30 % body completely (132 + 1,826 HP > 440)", start < 140 and near(total, 440) and later.t == 3600)
		local quarter = Health.recoverSaved(b, 600, 1)
		local qt = 0
		for _, k in Health.PARTS do
			qt += quarter.parts[k]
		end
		check("ten minutes away: 304.4 HP more", near(qt - start, 1826.4 / 6, 1e-6))
		local hb = Health.new()
		hb.parts.larm.hp = 0
		hb.parts.head.hp = 0.4
		local saved = Health.save(hb)
		check("a destroyed arm is saved destroyed (0); a living head keeps at least 1; the save is timed", saved.parts.larm == 0 and saved.parts.head == 1 and type(saved.t) == "number")
	end)

	-- ── HALE's treatment ──────────────────────────────────────────────────────────────────────────────────────────
	guard("treatment", function()
		local st = {
			head = { hp = 35, max = 35, bleed = 0 }, thorax = { hp = 60, max = 85, bleed = 0 }, stomach = { hp = 70, max = 70, bleed = 0 },
			larm = { hp = 60, max = 60, bleed = 0, fract = true }, rarm = { hp = 60, max = 60, bleed = 2 }, lleg = { hp = 0, max = 65, bleed = 0 },
			rleg = { hp = 65, max = 65, bleed = 0 },
		}
		local c1, lines = TD.treatQuote(st, 1, 10)
		check("LL1: 30 an HP, a destroyed leg its HP plus 2,500, a heavy bleed 1,400, a fracture 1,350", c1 == 25 * 30 + (65 * 30 + 2500) + 1400 + 1350 and #lines == 4)
		local c4 = TD.treatQuote(st, 4, 10)
		check("LL4: 40.5 an HP (EFT's Therapist LL1-4: 30, 33, 36, 40.5)", c4 == math.ceil(25 * 40.5) + math.ceil(65 * 40.5 + 2500) + 1400 + 1350)
		check("LL2 and LL3: 33 and 36 an HP", TD.treatQuote({ thorax = { hp = 75, max = 85 } }, 2, 10) == 330 and TD.treatQuote({ thorax = { hp = 75, max = 85 } }, 3, 10) == 360)
		check("a light bleed costs 750", TD.treatQuote({ stomach = { hp = 70, max = 70, bleed = 1 } }, 1, 10) == 750)
		local c5, l5, free = TD.treatQuote(st, 1, 5)
		check("free at player level 5 or below, the lines still listed (EFT)", c5 == 0 and free == true and #l5 == 4 and select(3, TD.treatQuote(st, 1, 6)) == false)
		check("nothing wrong, nothing to pay", select(2, TD.treatQuote({ head = { hp = 35, max = 35 } }, 1, 10))[1] == nil)
		local hs = Health.new()
		hs.parts.head.hp = 10.2
		hs.parts.lleg.hp = 0
		hs.bleedH.larm = true
		hs.fract.rleg = true
		local view = Health.treatState(hs)
		check("the treatment sees the body as the health screen shows it", view.head.hp == 11 and view.head.max == 35 and view.lleg.hp == 0 and view.larm.bleed == 2 and view.rleg.fract == true)
		Health.treat(hs)
		local whole = true
		for _, k in Health.PARTS do
			whole = whole and hs.parts[k].hp == hs.parts[k].max
		end
		check("HEAL ALL: every part full (the destroyed leg too), no bleed, no fracture", whole and next(hs.bleedH) == nil and next(hs.bleedL) == nil and next(hs.fract) == nil)
	end)

	-- ── the scav cooldown ───────────────────────────────────────────────────────────────────────────────────────────
	guard("scav cooldown", function()
		check("15 minutes at karma 0", Config.SCAV_COOLDOWN == 900 and Progress.scavCooldown(Config.SCAV_COOLDOWN, 0) == 900)
		check("karma still shortens and lengthens it", Progress.scavCooldown(Config.SCAV_COOLDOWN, 3) == 684 and Progress.scavCooldown(Config.SCAV_COOLDOWN, -3) == 1116)
		check("insurance's old fixed delay is gone (Match's readyAt is the loss time)", Config.INSURANCE_DELAY == 0)
	end)

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

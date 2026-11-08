--!nonstrict
-- Hideout checks for decision economy-7b ("Economy core, about 14"): EFT's modules, levels, costs and requirements,
-- bonuses, power and fuel burn, craft timing online and offline, the scav case and the bitcoin farm, old saves'
-- migration, and the server's operations on a scratch profile (Hideout.act, no player). Pure rules where possible.
-- Since economy-1a's crafts (2026-11-08): every craft's items, tools and numbers, the rules that keep a craft out, and
-- spot checks against EFT's current crafts with their sources.
-- Run via ZR_Dev "tests" (every module in Tests). EFT's figures and their sources: HideoutData.luau's header.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Services = script.Parent.Parent:WaitForChild("Services")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Progress = require(Shared.Progress)
local TD = require(Shared.TraderData)
local HD = require(Shared.HideoutData)
local Inv = require(Services.Inv)
local Settle = require(Services.Settle)

local T = {}

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

-- a bare hideout table at version 2 (pure tests)
local function hideout(levels)
	return { v = HD.VERSION, levels = levels or {}, builds = {}, crafts = {}, fuel = {}, on = false, btc = { cards = {}, coins = 0, prog = 0 }, t = 0 }
end

local function give(p, id, n)
	local d = Items.defs[id]
	local left = n or 1
	while left > 0 do
		local take = math.min(left, d.stack or 1)
		local g, it = Inv.newItem(id, take)
		if not Inv.place(p, g, it, { "stash" }) then
			return false
		end
		left -= take
	end
	return true
end

local function count(p, id)
	local n = 0
	for g in p.grids.stash or {} do
		local it = p.items[g]
		if it and it.id == id then
			n += it.n or 1
		end
	end
	return n
end

local function firOf(p, id)
	for g in p.grids.stash or {} do
		local it = p.items[g]
		if it and it.id == id then
			return it.fir == true
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
	local DIV = Config.HIDEOUT_TIME_DIV

	-- ── the modules: EFT's fourteen, its levels, costs and requirements ─────────────────────────────────────────────
	guard("modules", function()
		check("one time divisor for every hideout clock: 4 (ours, decision economy-4b)", DIV == 4 and HD.div() == 4)
		local ids = {}
		for _, id in HD.ORDER do
			ids[id] = true
		end
		local n = 0
		for id in HD.modules do
			n += 1
			ids[id] = ids[id] and true or false
		end
		check("fourteen modules, all in EFT's area order", n == 14 and #HD.ORDER == 14 and table.concat(HD.ORDER, ",")
			== "security,lavatory,stash,generator,water,medstation,nutrition,rest,workbench,intel,range,scavcase,illumination,bitcoin")
		local lv = {}
		for _, id in HD.ORDER do
			table.insert(lv, #HD.modules[id].levels)
		end
		check("EFT's level counts: stash 4, scav case 1, the rest 3", table.concat(lv, ",") == "3,3,4,3,3,3,3,3,3,3,3,1,3,3")
		local bad = {}
		for id, m in HD.modules do
			for i, l in m.levels do
				for _, e in l.items or {} do
					if not Items.defs[e[1]] or e[2] < 1 then
						table.insert(bad, id .. i .. ":" .. tostring(e[1]))
					end
				end
				for _, nd in l.needs or {} do
					if not HD.modules[nd[1]] or nd[2] > #HD.modules[nd[1]].levels then
						table.insert(bad, id .. i .. " needs " .. tostring(nd[1]))
					end
				end
				for _, s in l.skills or {} do
					if not Progress.SKILLS[s[1]] then
						table.insert(bad, id .. i .. " skill " .. tostring(s[1]))
					end
				end
			end
		end
		check("every requirement is a real item, module level or skill" .. (#bad > 0 and (": " .. table.concat(bad, " ")) or ""), #bad == 0)
		local S, Me, W, G = HD.modules.stash.levels, HD.modules.medstation.levels, HD.modules.workbench.levels, HD.modules.generator.levels
		check("EFT's money, 1 rouble = 1 MK: stash 2.5M / 8.5M / EUR 200,000 at 191 = 38.2M", S[2].cost == 2500000 and S[3].cost == 8500000 and S[4].cost == 200000 * 191)
		check("EFT's money: medstation 50k / 150k / 500k, workbench 3 395k, generator 1 100k, lavatory 1 2k", Me[1].cost == 50000 and Me[2].cost == 150000 and Me[3].cost == 500000
			and W[3].cost == 395000 and G[1].cost == 100000 and HD.modules.lavatory.levels[1].cost == 2000)
		check("EFT's build times / 4: stash 4 four days -> 24 h, scav case 3 d 8 h -> 20 h, bitcoin 3 4 d 10 h", near(HD.buildNeed(S[4]), 86400) and near(HD.buildNeed(HD.modules.scavcase.levels[1]), 72000)
			and near(HD.buildNeed(HD.modules.bitcoin.levels[3]), 381600 / 4))
		check("EFT's prerequisites: generator 1 needs security 1, medstation 3 needs lavatory 2 and Vitality 3, stash 4 needs intel 2",
			G[1].needs[1][1] == "security" and Me[3].needs[2][1] == "lavatory" and Me[3].skills[1][1] == "vitality" and Me[3].skills[1][2] == 3
			and S[4].needs[4][1] == "intel" and S[4].needs[4][2] == 2)
		check("the stash grows 10x30 / 40 / 50 / 68 (EFT)", S[1].rows == 30 and S[2].rows == 40 and S[3].rows == 50 and S[4].rows == 68 and HD.stashRows({ levels = {} }) == 30)
		local hd = hideout({ security = 1, illumination = 1 })
		local lines, ok = HD.requirements(hd, HD.modules.security.levels[2], { money = 50000, count = function()
			return 5
		end, skills = { endurance = 0 } })
		local skillLine
		for _, l in lines do
			if l.k == "skill" then
				skillLine = l
			end
		end
		check("requirements list have / need: Endurance 2 missing blocks security 2", not ok and skillLine and skillLine.need == 2 and skillLine.have == 0 and not skillLine.ok)
		local _, ok2 = HD.requirements(hd, HD.modules.security.levels[2], { money = 50000, count = function()
			return 5
		end, skills = { endurance = 30 } })
		check("... and Endurance level 2 (30 points) passes", ok2)
	end)

	-- ── bonuses (each level adds its own, as EFT's profile bonuses do) ───────────────────────────────────────────────
	guard("bonuses", function()
		local hd = hideout({ medstation = 3, generator = 1, bitcoin = 3, intel = 3, rest = 3, nutrition = 2 })
		check("medstation +6 / +12 / +20 % health regeneration add up (38 % at level 3)", HD.bonus(hideout({ medstation = 1 }), "hpRegen") == 6
			and HD.bonus(hideout({ medstation = 2 }), "hpRegen") == 18 and HD.bonus(hideout({ medstation = 3 }), "hpRegen") == 38)
		check("bitcoin farm card slots 10 / 25 / 50 (EFT), fuel slots 2 / 4 / 6", HD.gpuSlots(hideout({ bitcoin = 1 })) == 10 and HD.gpuSlots(hideout({ bitcoin = 2 })) == 25
			and HD.gpuSlots(hd) == 50 and HD.fuelSlots(hideout({ generator = 1 })) == 2 and HD.fuelSlots(hideout({ generator = 3 })) == 6)
		check("intelligence center 3: scav cooldown -35 %, task money +15 %, insurance -20 %, flea fee -30 %", HD.bonus(hd, "scavCooldown") == 35
			and HD.bonus(hd, "questMoney") == 15 and HD.bonus(hd, "insuranceTime") == 20 and HD.bonus(hd, "fleaFee") == 30)
		check("health regeneration from the medstation, nutrition unit 2 and rest space 3 together: 38 + 7 + 15", HD.bonus(hd, "hpRegen", true) == 60)
		check("without power: the powered modules' bonuses stop (rest space's +15 % stays), slots stay", HD.bonus(hd, "hpRegen", false) == 15
			and HD.bonus(hd, "fleaFee", false) == 0 and HD.bonus(hd, "gpuSlots", false) == 50)
		check("bonus texts for the screen", HD.bonusText("hpRegen", 6) == "Health regeneration +6 %" and HD.bonusText("weaponKit", 1) == "Weapon repair with repair kits")
		if ctx and ctx.Hideout then
			local p = { hideout = hideout({ medstation = 2, generator = 1 }) }
			p.hideout.fuel = { 60 }
			p.hideout.on = true
			local powered = ctx.Hideout.healRate(p)
			p.hideout.on = false
			check("Hideout.healRate: 1.18 with the medstation 2 powered, 1 without power", near(powered, 1.18) and near(ctx.Hideout.healRate(p), 1))
			local q = { hideout = hideout({ generator = 1, nutrition = 3, water = 3, intel = 3 }) }
			q.hideout.fuel = { 60 }
			q.hideout.on = true
			local e, wr = ctx.Hideout.vitalsRate(q)
			check("Hideout.vitalsRate: energy x1.6 (nutrition 3), hydration x1.8 (water collector 3 and nutrition 3)", near(e, 1.6) and near(wr, 1.8))
			check("Hideout.cut: the flea fee x0.7 and scav cooldown x0.65 at intelligence 3", near(ctx.Hideout.cut(q, "fleaFee"), 0.7) and near(ctx.Hideout.cut(q, "scavCooldown"), 0.65))
		end
	end)

	-- ── fuel and power ───────────────────────────────────────────────────────────────────────────────────────────────
	guard("fuel", function()
		check("EFT's burn: a unit every 12 min 38 s, divided by 4; a 60-unit canister lasts 3 h 9 min 30 s", near(HD.burnRate(), 4 / 758) and HD.FUEL.units == 60
			and HD.FUEL.item == "FUEL_CAN" and near(HD.FUEL.units / HD.burnRate(), 11370))
		check("without power a powered module's craft runs at 0.07 (EFT wiki: \"more than 14 times\" longer)", HD.NO_POWER == 0.07 and 1 / HD.NO_POWER > 14)
		local hd = hideout({ generator = 1, workbench = 1, lavatory = 1 })
		check("no fuel, no power", not HD.powered(hd))
		hd.fuel = { 60 }
		check("fuel but switched off: no power", not HD.powered(hd))
		hd.on = true
		check("fuel and switched on: power", HD.powered(hd))
		local ev = HD.tick(hd, 1000)
		check("fuel burns while it runs (1000 s: 5.28 units)", near(HD.fuelUnits(hd), 60 - 1000 * 4 / 758, 1e-6) and #ev == 0 and hd.t == 1000)
		hd.on = false
		HD.tick(hd, 5000)
		check("switched off: no fuel burns", near(HD.fuelUnits(hd), 60 - 1000 * 4 / 758, 1e-6))
		-- fuel that runs out in the middle of a craft: full speed until then, 0.07 after (EFT: "more than 14 times" slower)
		local h2 = hideout({ generator = 1, workbench = 1, lavatory = 1 })
		h2.fuel = { 300 * HD.burnRate() }
		h2.on = true
		h2.crafts.workbench = { r = "AMMO_BP", get = { "A76_BP", 60 }, need = 1000, done = 0 }
		h2.crafts.lavatory = { r = "LAV_SOAP", get = { "SOAP", 6 }, need = 1000, done = 0 }
		local ev2 = HD.tick(h2, 1000)
		local outOfFuel, lavDone = false, false
		for _, e in ev2 do
			outOfFuel = outOfFuel or e.k == "fuel"
			lavDone = lavDone or (e.k == "craft" and e.m == "lavatory")
		end
		check("out of fuel: the generator switches itself off and says so", outOfFuel and h2.on == false and #h2.fuel == 0)
		check("a workbench craft: 300 s at full speed, the other 700 s at 0.07", near(h2.crafts.workbench.done, 300 + 700 * HD.NO_POWER, 1e-6))
		check("the lavatory needs no power (EFT wiki): its craft finished on time", lavDone and h2.crafts.lavatory.done == 1000)
		check("the finish estimate with power and fuel to spare, and without power", HD.eta(100, true, true, 1000) == 100 and near(HD.eta(100, true, false, 0), 100 / HD.NO_POWER)
			and HD.eta(100, false, false, 0) == 100 and near(HD.eta(100, true, true, 40), 40 + 60 / HD.NO_POWER))
	end)

	-- ── craft timing, online (many small ticks) and offline (one long tick) alike ─────────────────────────────────────
	guard("crafts", function()
		local r = HD.byRecipe.AMMO_BP
		check("craft time: EFT's 2 h 36 min 40 s / 4 (SPT's 9,400 s; tarkovforge shows 2 h 37 min)", near(HD.craftNeed(r, nil), 9400 / 4))
		check("the Crafting skill shortens it (Progress' rate), never under 5 s", HD.craftNeed(r, { crafting = 4650 }) < HD.craftNeed(r, nil) and HD.craftNeed({ time = 1 }, nil) == 5)
		local function setup()
			local hd = hideout({ generator = 1, medstation = 1 })
			hd.fuel = { 60, 60 }
			hd.on = true
			hd.crafts.medstation = { r = "MED_CMS", get = { "SURGKIT", 1 }, need = 735, done = 0 }
			return hd
		end
		local online = setup()
		local t = 0
		while t < 20000 do
			t += 5
			HD.tick(online, t)
		end
		local offline = setup()
		HD.tick(offline, 20000)
		check("online ticks and one offline tick give the same craft, fuel and power", online.crafts.medstation.done == 735 and offline.crafts.medstation.done == 735
			and near(HD.fuelUnits(online), HD.fuelUnits(offline), 1e-6) and online.on == offline.on)
		local h3 = setup()
		h3.t = 100
		local ev = HD.tick(h3, 50)
		check("a clock that runs backwards changes nothing", h3.t == 100 and h3.crafts.medstation.done == 0 and #ev == 0)
		local ids, dupe, selfLoop, both, badItem, badNum, mostly, refills = {}, {}, {}, {}, {}, {}, {}, {}
		local CRAFTING = { medstation = true, workbench = true, lavatory = true, nutrition = true, water = true, intel = true }
		local perModule = {}
		local function value(id)
			local d = Items.defs[id]
			return (d and d.value) or 0
		end
		for _, rc in HD.recipes do
			if ids[rc.id] then
				table.insert(dupe, rc.id)
			end
			ids[rc.id] = true
			perModule[rc.module] = (perModule[rc.module] or 0) + 1
			if not HD.modules[rc.module] or not CRAFTING[rc.module] or rc.level < 1 or rc.level > #HD.modules[rc.module].levels or not Items.defs[rc.get[1]] then
				table.insert(badItem, rc.id)
			end
			if not (rc.time > 0 and rc.get[2] >= 1 and #rc.give >= 1 and type(rc.eft) == "string" and #rc.eft > 0) then
				table.insert(badNum, rc.id)
			end
			local only = #rc.give == 1 and rc.give[1][1] == rc.get[1]
			if only then
				table.insert(selfLoop, rc.id)
			end
			-- the header's rule made exact: the product may go in too (our generic food, fabric...) only when the rest of
			-- what goes in is worth at least the product units it uses up and more comes out than went in; EFT's own
			-- refills (refill = true) are the exception
			local seen, own, rest = {}, 0, 0
			for _, e in rc.give do
				if not Items.defs[e[1]] then
					table.insert(badItem, rc.id .. ":" .. e[1])
				end
				if seen[e[1]] or not (e[2] > 0) then
					table.insert(badNum, rc.id .. ":" .. e[1])
				end
				seen[e[1]] = true
				if e[1] == rc.get[1] then
					own += e[2]
				else
					rest += value(e[1]) * e[2]
				end
				for _, tl in rc.tools or {} do
					if tl[1] == e[1] then
						table.insert(both, rc.id)
					end
				end
			end
			for _, tl in rc.tools or {} do
				if not Items.defs[tl[1]] then
					table.insert(badItem, rc.id .. ":tool " .. tl[1])
				end
				if not (tl[2] >= 1) then
					table.insert(badNum, rc.id .. ":tool " .. tl[1])
				end
			end
			if rc.refill then
				table.insert(refills, rc.id)
				if own ~= rc.get[2] then
					table.insert(mostly, rc.id .. " (a refill takes one of its product)")
				end
			elseif own > 0 and (own >= rc.get[2] or rest < own * value(rc.get[1])) then
				table.insert(mostly, rc.id)
			end
		end
		local function listed(t)
			return #t > 0 and (": " .. table.concat(t, " ")) or ""
		end
		check(string.format("EFT's current crafts with a product here: %d (medstation %d, workbench %d, lavatory %d, nutrition %d, water %d, intel %d), no ids clash",
			#HD.recipes, perModule.medstation or 0, perModule.workbench or 0, perModule.lavatory or 0, perModule.nutrition or 0, perModule.water or 0, perModule.intel or 0),
			#HD.recipes >= 76 and #dupe == 0)
		check("every craft's module, level, product, inputs and tools are real items and levels" .. listed(badItem), #badItem == 0)
		check("every craft takes positive counts and time, lists each input once and names EFT's product" .. listed(badNum), #badNum == 0)
		check("no craft only turns an item into more of itself" .. listed(selfLoop), #selfLoop == 0)
		check("no craft takes in mostly its own product or makes no more of it (EFT's refills aside)" .. listed(mostly), #mostly == 0)
		check("the one refill is EFT's weapon repair kit's (a used kit in, a full one out)", #refills == 1 and refills[1] == "GUN_KIT")
		check("no item is both used up and a tool in one craft", #both == 0)
		-- products are the items ours copies (economy-1a's crafts): no craft makes a near round or stim any more
		local makes = {}
		for _, rc in HD.recipes do
			makes[rc.get[1]] = (makes[rc.get[1]] or 0) + 1
		end
		check("no craft makes 7.62x39 PS (EFT's craft makes FMJ), 9x18 Pst or PSV (PstM, SP8), 7.62x54R LPS or SNB, 12/70 buckshot or lead slugs (Piranha, the .50 BMG slug), M995",
			not makes.A76_PS and not makes.A918_PST and not makes.A918_PSV and not makes.A76L_LPS and not makes.A76L_SNB and not makes.A12_BUCK and not makes.A12_SLUG and not makes.A62_AP)
		check("SJ6 (our SV-3) is made by no craft: EFT's needs an SJ1, and SJ1, PNB and AHF1-M have no counterpart here", not makes.STIM_STAMINA)
		check("no craft makes a near armour, helmet or magazine (Module-3M, Zhuk, MICH, the 6L31)", not makes.ARMOR_C2 and not makes.ARMOR_C3 and not makes.HELMET_C3 and not makes.KST_MAG40)
		check("LogicTests' crafts are still there: RK-5 grenades and the repair kit", HD.byRecipe.NADE_RK5 ~= nil and HD.byRecipe.GUN_KIT ~= nil
			and Items.defs[HD.byRecipe.GUN_KIT.get[1]].kind == "repair")
	end)

	-- ── spot checks against EFT's current crafts (decision economy-1a's crafts; sources beside each) ───────────────────
	guard("EFT crafts", function()
		local function has(list, id, n)
			for _, e in list or {} do
				if e[1] == id then
					return n == nil or e[2] == n
				end
			end
			return false
		end
		local function is(id, module, level, time, get, n)
			local r = HD.byRecipe[id]
			return r ~= nil and r.module == module and r.level == level and r.time == time and r.get[1] == get and r.get[2] == n
		end
		-- tarkovforge.com/hideout/workbench (2 h 1 min, 150 from 150 M882 and 2 Kite); xgamingserver's toolset page: the
		-- toolset is returned; SPT's 7,250 s
		local r = HD.byRecipe.AMMO_9AP
		check("workbench 3: 9x19 AP 6.3 x150 from FMJ M882 x150 and 2 gunpowder, the toolset returned, 7,250 s",
			is("AMMO_9AP", "workbench", 3, 7250, "A9_AP", 150) and has(r.give, "A9_FMJ", 150) and has(r.give, "GUNPOWDER", 2) and #r.give == 2 and has(r.tools, "TOOLSET", 1))
		-- xgamingserver's Zagustin page (snapshot 2026-11-04): medstation 3, 1 h 52 min, CALOK-B, Grizzly, 2 piles of meds,
		-- the silicone tube "tool, returned"
		r = HD.byRecipe.MED_ZAGUSTIN
		check("medstation 3: Zagustin (our HM-2) from CALOK-B, Grizzly and 2 piles of meds, the silicone tube returned, 1 h 52 min",
			is("MED_ZAGUSTIN", "medstation", 3, 6720, "STIM_HEMO", 1) and has(r.give, "HEMOSTAT", 1) and has(r.give, "MEDKIT_XL", 1) and has(r.give, "MEDS_PILE", 2)
				and has(r.tools, "SILICONE_TUBE", 1) and not has(r.give, "SILICONE_TUBE"))
		-- xgamingserver's fuel tank page: lavatory 2, 1 h 2 min, 2 Zibbo and 2 Crickent lighters, water used up, the tube
		-- returned (economy-7b used the tube up)
		r = HD.byRecipe.LAV_FUEL
		check("lavatory 2: the fuel tank from 4 lighters and water, the silicone tube now a tool", is("LAV_FUEL", "lavatory", 2, 3720, "FUEL_CAN", 1)
			and has(r.give, "LIGHTER", 4) and has(r.give, "WATER", 1) and has(r.tools, "SILICONE_TUBE", 1) and not has(r.give, "SILICONE_TUBE"))
		-- xgamingserver's radiator helix page: workbench 3, 2 h 18 min, 80 M80, 2 Hawk, a helix, the multitool returned, 40 M80A1
		r = HD.byRecipe.AMMO_M80A1
		check("workbench 3: 7.62x51 M80A1 x40 from M80 x80, 2 gunpowder and a helix (our signal coil), multitool returned",
			is("AMMO_M80A1", "workbench", 3, 8280, "A76N_EP", 40) and has(r.give, "A76N_BALL", 80) and has(r.give, "GUNPOWDER", 2) and has(r.give, "SIGNAL_COIL", 1)
				and has(r.tools, "MULTITOOL", 1))
		-- xgamingserver's toolset page: the weapon repair kit is EFT's refill (a kit, a toolset not returned, gun lube, 3
		-- weapon parts, 2 metal spare parts, 25 min)
		r = HD.byRecipe.GUN_KIT
		check("workbench 3: the repair kit is EFT's refill: a kit, a toolset, gun lube, 3 weapon parts and 2 metal spare parts used up, 25 min",
			is("GUN_KIT", "workbench", 3, 1500, "WEAPON_KIT", 1) and r.refill == true and has(r.give, "WEAPON_KIT", 1) and has(r.give, "TOOLSET", 1)
				and has(r.give, "GUN_LUBE", 1) and has(r.give, "WEAPON_PARTS", 3) and has(r.give, "SPARE_PARTS", 2) and #(r.tools or {}) == 0)
		-- SPT production.json (EFT 0.16.9): the AK-74N from weapon parts and its wooden handguard and stock, pliers and a
		-- screwdriver returned, 4,900 s (tarkovforge: 1 h 22 min); the KS-74 copies the AK-74N
		r = HD.byRecipe.WB_AK74N
		check("workbench 1: a KS-74 (EFT's AK-74N) from weapon parts and wooden furniture, pliers and screwdriver returned",
			is("WB_AK74N", "workbench", 1, 4900, "KS74_RIFLE", 1) and has(r.give, "WEAPON_PARTS", 1) and has(r.tools, "PLIERS", 1) and has(r.tools, "SCREWDRIVER", 1))
		-- xgamingserver's printer paper page and SPT: the intelligence folder takes 31 h 40 min (tarkovforge shows "1d 7h")
		check("intelligence center 3: the folder takes 31 h 40 min", is("INT_FOLDER", "intel", 3, 114000, "INTEL_FOLDER", 1))
		-- xgamingserver's sewing kit page: every lavatory craft that sews keeps the sewing kit (returned)
		local sewn = true
		for _, id in { "LAV_CORDURA", "LAV_RIPSTOP", "LAV_BLACKROCK", "LAV_SWITCHBLADE", "LAV_COMMANDO", "LAV_PILGRIM" } do
			sewn = sewn and has(HD.byRecipe[id].tools, "SEWING_KIT", 1) and not has(HD.byRecipe[id].give, "SEWING_KIT")
		end
		check("the lavatory's sewing crafts keep the sewing kit as a tool", sewn)
		-- SPT: the water collector's and nutrition unit's emergency water rations keep the silicone tube; the Hot Rod keeps the
		-- water filter (xgamingserver's BakeEzy page too)
		check("the silicone tube and water filter are tools in the water rations and the Hot Rod", has(HD.byRecipe.WC_RATION.tools, "SILICONE_TUBE", 1)
			and has(HD.byRecipe.NUT_WATER.tools, "SILICONE_TUBE", 1) and has(HD.byRecipe.NUT_HOTROD.tools, "WATER_FILTER", 1) and not has(HD.byRecipe.NUT_HOTROD.give, "WATER_FILTER"))
		-- tarkovforge's current counts where EFT 1.x changed SPT's 0.16.9 ones: 5.45 BP 60 (0.16.9: 120), 4.6 AP SX 60 (120),
		-- SS190 60 (100), .45 AP 100 (150), Propital 4 (7), Ox bleach 3 (5), PAB-9 100 (150), BCP FMJ 60 (120)
		check("EFT 1.x's counts: 5.45 BP 60, 4.6 AP 60, SS190 60, .45 AP 100, Propital 4, bleach 3, PAB-9 100, 7.62x51 FMJ 60",
			HD.byRecipe.AMMO_54BP.get[2] == 60 and HD.byRecipe.AMMO_46AP.get[2] == 60 and HD.byRecipe.AMMO_SS190.get[2] == 60 and HD.byRecipe.AMMO_45AP.get[2] == 100
				and HD.byRecipe.MED_PROPITAL.get[2] == 4 and HD.byRecipe.LAV_BLEACH.get[2] == 3 and HD.byRecipe.AMMO_PAB9.get[2] == 100 and HD.byRecipe.AMMO_76FMJ.get[2] == 60)
		-- the rounds the crafts now make are the ones ours copies (EFT_PARITY's catalogue): M855A1 from M855, BT from PS,
		-- BP from PP
		check("rounds by their copies: M855A1 (EP) from M855 (SS), 7.62x54R BT from PS, 7.62x39 BP from PP", HD.byRecipe.AMMO_AP.get[1] == "A62_EP"
			and has(HD.byRecipe.AMMO_AP.give, "A62_SS", 180) and HD.byRecipe.AMMO_76LBT.get[1] == "A76L_BT" and has(HD.byRecipe.AMMO_76LBT.give, "A76L_PS", 50)
			and has(HD.byRecipe.AMMO_BP.give, "A76_PP", 90))
	end)

	-- ── the bitcoin farm ─────────────────────────────────────────────────────────────────────────────────────────────
	guard("bitcoin", function()
		check("EFT 1.1.0: one card 300,000 s a coin (/ 4 = 20 h 50 min), 50 cards x (1 + 49 x 0.041225)", near(1 / HD.btcRate(1), 75000)
			and near(HD.btcRate(50), 4 * (1 + 49 * 0.041225) / 300000) and HD.btcRate(0) == 0)
		local hd = hideout({ generator = 3, bitcoin = 3 })
		hd.btc.cards = table.create(50, false)
		hd.fuel = { 60, 60, 60, 60, 60, 60 }
		hd.on = true
		local per = 1 / HD.btcRate(50)
		local ev = HD.tick(hd, math.floor(per * 1.5))
		check("50 cards with power: one coin after 1.5 coin-times (6 h 54 min each)", hd.btc.coins == 1 and #ev >= 1 and near(hd.btc.prog, 0.5, 0.01))
		hd.on = false
		local before = hd.btc.prog
		HD.tick(hd, math.floor(per * 10))
		check("no power: the farm stops", hd.btc.coins == 1 and near(hd.btc.prog, before, 1e-9))
		hd.on = true
		hd.fuel = { 60, 60, 60, 60, 60, 60 }
		HD.tick(hd, math.floor(per * 15))
		check("three coins wait at most, then it halts (EFT)", hd.btc.coins == 3 and hd.btc.prog == 0)
		local h2 = hideout({ generator = 1, bitcoin = 1 })
		h2.fuel = { 60 }
		h2.on = true
		HD.tick(h2, 100000)
		check("no cards, no coins", h2.btc.coins == 0)
		check("the coin is our cold wallet, the card our graphics card", HD.BTC.coin == "COLD_WALLET" and HD.BTC.gpu == "GPU_CARD" and Items.defs.COLD_WALLET and Items.defs.GPU_CARD)
	end)

	-- ── the scav case ────────────────────────────────────────────────────────────────────────────────────────────────
	guard("scav case", function()
		local ids = {}
		for _, s in HD.SCAV do
			table.insert(ids, s.id .. ":" .. s.time)
		end
		check("EFT's five runs and times: 2,500 41:40, 15,000 2:08:20, 95,000 2:15, moonshine 4:40, intelligence folder 5:20",
			table.concat(ids, ",") == "MK2500:2500,MK15000:7700,MK95000:8100,MOONSHINE:16800,INTEL:19200")
		local run = HD.byScav.MK2500
		check("divided by 4, and Fence's standing: x1 at 0, x0.5 at 6, x9 at -7 (EFT globals)", near(HD.scavNeed(run, 0), 625) and near(HD.scavNeed(run, 6), 312.5)
			and near(HD.scavNeed(run, -7), 5625) and near(HD.scavNeed(run, 2.7), 625 * 0.9))
		local seed = 7
		local function rng()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local okCounts, okIds, okAmmo, never = true, true, true, true
		local totals = { MK2500 = { 1, 2 }, MK15000 = { 2, 4 }, MK95000 = { 2, 5 }, MOONSHINE = { 4, 6 }, INTEL = { 4, 7 } }
		for _, s in HD.SCAV do
			for _ = 1, 40 do
				local got = HD.rollScav(s, rng)
				local lo, hi = totals[s.id][1], totals[s.id][2]
				if #got < lo or #got > hi then
					okCounts = false
				end
				for _, e in got do
					local d = Items.defs[e.id]
					if not d then
						okIds = false
					elseif d.kind == "ammo" and (e.n < 1 or e.n > d.stack) then
						okAmmo = false
					end
					if HD.SCAV_NEVER[e.id] or (d and (d.kind == "quest" or d.kind == "secure")) then
						never = false
					end
				end
			end
		end
		check("each run brings EFT's number of items (1-2, 2-4, 2-5, 4-6, 4-7)", okCounts)
		check("only real items, ammunition in a stack it can hold", okIds and okAmmo)
		check("no boss loot, quest items, pouches or task goods (EFT: no boss items)", never)
		local food = true
		for _, tier in { "common", "rare", "superrare" } do
			for _, id in HD.scavPool(HD.byScav.MK2500, tier) do
				local k = Items.defs[id].kind
				food = food and (k == "food" or k == "ammo")
			end
		end
		check("the 2,500 run brings food and ammunition only", food and #HD.scavPool(HD.byScav.MK2500, "common") > 0)
		check("the moonshine run can bring weapons and armour; the folder run electronics", #HD.scavPool(HD.byScav.MOONSHINE, "common") > 0 and #HD.scavPool(HD.byScav.INTEL, "rare") > 0)
	end)

	-- ── old saves ────────────────────────────────────────────────────────────────────────────────────────────────────
	guard("migration", function()
		local now = 100000
		local old = {
			levels = { generator = 1, medstation = 2, workbench = 2, storage = 1, nutrition = 1 },
			build = { m = "storage", l = 2, at = now + 600 },
			crafts = { workbench = { r = "AMMO_AP", at = now + 300 }, nutrition = { r = "WATER", at = now - 10 }, medstation = { r = "MED_ROAD", at = now + 50 } },
		}
		check("an old save migrates once", HD.migrate(old, now) == true and HD.migrate(old, now) == false and old.v == HD.VERSION)
		local L = old.levels
		check("generator, medstation and workbench keep their levels", L.generator == 1 and L.medstation == 2 and L.workbench == 2)
		check("storage racks 1 (10x25) -> stash 2 (10x40); the water collector keeps level 1 as \"water\"", L.stash == 2 and L.storage == nil and L.water == 1 and L.nutrition == nil)
		check("the storage build under way -> stash 3, same finish time", old.builds.stash and old.builds.stash.l == 3 and old.builds.stash.at == now + 600 and old.build == nil)
		local c = old.crafts
		check("crafts under way keep their product and time (and run at full speed)", c.workbench.get[1] == "A62_AP" and c.workbench.need == 300 and c.workbench.legacy
			and c.water and c.water.get[1] == "WATER" and c.water.need == 0 and c.medstation.get[1] == "MEDKIT_M")
		HD.tick(old, now + 300)
		check("... and finish on time without fuel", old.crafts.workbench.done == 300 and old.crafts.medstation.done == 50)
		HD.tick(old, now + 600)
		check("... the build too", old.levels.stash == 3 and old.builds.stash == nil and HD.stashRows(old) == 50)
		local fresh = { levels = {}, crafts = {} }
		HD.migrate(fresh, now)
		check("a new profile starts with the stash at level 1 (10x30, EFT's Standard Edition)", fresh.levels.stash == 1 and HD.stashRows(fresh) == 30 and fresh.v == HD.VERSION)
		local top = { levels = { storage = 2 }, crafts = {} }
		HD.migrate(top, now)
		check("racks 2 (10x30) -> stash 3 (10x50): nobody loses rows or what they paid for", top.levels.stash == 3)
	end)

	-- ── the server: build, power, craft, collect, the scav case and the farm on a scratch profile ────────────────────
	guard("server", function()
		local H = ctx and ctx.Hideout
		if not (H and H.act) then
			check("ctx.Hideout.act is there", false)
			return
		end
		local p = Settle.newProfile()
		p.money = 100000000
		H.settle(p, nil)
		check("a new profile: hideout v2, stash 1, 10x30", p.hideout.v == HD.VERSION and p.hideout.levels.stash == 1 and p.stashH == 30)
		local r = H.act(nil, p, { op = "build", m = "generator" })
		check("the generator needs security 1 first", type(r) == "table" and r.code == "REQUIREMENTS")
		r = H.act(nil, p, { op = "build", m = "security" })
		check("security 1 needs its item (EFT's construction measuring tape)", type(r) == "table" and r.code == "MISSING_ITEMS")
		give(p, "TAPE_MEASURE", 2)
		local m0 = p.money
		r = H.act(nil, p, { op = "build", m = "security" })
		check("security 1: instant, 20,000 MK and the tape measure taken", r == true and p.hideout.levels.security == 1 and p.money == m0 - 20000 and count(p, "TAPE_MEASURE") == 1)
		give(p, "SPARK_PLUG", 1)
		r = H.act(nil, p, { op = "build", m = "generator" })
		check("generator 1 built", r == true and p.hideout.levels.generator == 1)
		give(p, "NUTS", 2)
		give(p, "BOLTS", 2)
		give(p, "MULTITOOL", 2)
		r = H.act(nil, p, { op = "build", m = "workbench" })
		check("workbench 1 built (EFT's screw nuts x2, bolts x2 and a multitool)", r == true and p.hideout.levels.workbench == 1 and count(p, "MULTITOOL") == 1
			and count(p, "NUTS") == 0 and count(p, "BOLTS") == 0)
		give(p, "SCREWDRIVER", 1)
		give(p, "SKS_RIFLE", 1)
		r = H.act(nil, p, { op = "craft", r = "WB_PARTS_SKS" })
		check("no power: the workbench cannot start a craft (EFT)", type(r) == "table" and r.code == "NO_POWER")
		r = H.act(nil, p, { op = "fuel" })
		check("fuel needs a canister", type(r) == "table" and r.code == "MISSING_ITEMS")
		give(p, "FUEL_CAN", 3)
		check("a canister into the empty generator starts it", H.act(nil, p, { op = "fuel" }) == true and HD.powered(p.hideout) and #p.hideout.fuel == 1)
		check("two fuel slots at level 1", H.act(nil, p, { op = "fuel" }) == true and (H.act(nil, p, { op = "fuel" })).code == "FULL")
		r = H.act(nil, p, { op = "craft", r = "WB_PARTS_SKS" })
		local c = p.hideout.crafts.workbench
		check("the craft starts: the SK-45 used up, the screwdriver goes in with it (EFT's tool)", r == true and c and count(p, "SKS_RIFLE") == 0
			and count(p, "SCREWDRIVER") == 0 and count(p, "MULTITOOL") == 1
			and near(c.need, HD.craftNeed(HD.byRecipe.WB_PARTS_SKS, p.skills)))
		check("one craft at a time in a module", (H.act(nil, p, { op = "craft", r = "WB_KITE" })).code == "BUSY")
		check("not ready yet", (H.act(nil, p, { op = "collect", m = "workbench" })).code == "NOT_READY")
		HD.tick(p.hideout, p.hideout.t + c.need + 1)
		r = H.act(nil, p, { op = "collect", m = "workbench" })
		check("collected: weapon parts found in raid, the screwdriver back", r == true and count(p, "WEAPON_PARTS") == 1 and firOf(p, "WEAPON_PARTS") == true
			and count(p, "SCREWDRIVER") == 1 and p.hideout.crafts.workbench == nil)
		-- the crafts thread's REQUESTs (2026-11-08): a crafted gun comes with its default magazine; a refill takes the most
		-- worn repair kit
		local gunOk = H.giveAll(p, { { "KS74_RIFLE", 1, true } })
		local withMag, gunG = false, nil
		for g, it in p.items do
			if it.id == "KS74_RIFLE" then
				gunG = g
				withMag = it.mag ~= nil and p.items[it.mag] ~= nil
			end
		end
		if gunG then
			Inv.take(p, gunG)
		end
		check("a crafted gun arrives with its default magazine, as a trader's does", gunOk and withMag)
		local gWorn, kWorn = Inv.newItem("WEAPON_KIT", 1, { pts = 40 })
		local gNew, kNew = Inv.newItem("WEAPON_KIT", 1, { pts = 150 })
		Inv.place(p, gNew, kNew, { "stash" })
		Inv.place(p, gWorn, kWorn, { "stash" })
		ctx.Economy.consumeStash(p, "WEAPON_KIT", 1)
		check("the refill uses up the most worn repair kit", p.items[gWorn] == nil and p.items[gNew] ~= nil)
		Inv.take(p, gNew)
		check("the switch: off, and on again with fuel", H.act(nil, p, { op = "power", on = false }) == true and not HD.powered(p.hideout)
			and H.act(nil, p, { op = "power", on = true }) == true and HD.powered(p.hideout))
		-- the scav case and the farm, levels set directly (their EFT requirements are checked above)
		p.hideout.levels.scavcase = 1
		local m1 = p.money
		r = H.act(nil, p, { op = "scav", r = "MK2500" })
		check("a 2,500 MK run: paid, the scavs out for 625 s at karma 0", r == true and p.money == m1 - 2500 and p.hideout.scav and p.hideout.scav.at >= os.time() + 620)
		check("one run at a time", (H.act(nil, p, { op = "scav", r = "MK15000" })).code == "BUSY")
		local got = #p.hideout.scav.got
		HD.tick(p.hideout, p.hideout.scav.at)
		r = H.act(nil, p, { op = "scavGet" })
		check("they are back: 1 or 2 items into the stash", r == true and got >= 1 and got <= 2 and p.hideout.scav == nil)
		p.hideout.levels.bitcoin = 1
		give(p, "GPU_CARD", 2)
		check("graphics cards go in and come out", H.act(nil, p, { op = "gpu", add = true }) == true and H.act(nil, p, { op = "gpu", add = true }) == true
			and #p.hideout.btc.cards == 2 and H.act(nil, p, { op = "gpu", add = false }) == true and count(p, "GPU_CARD") == 1)
		p.hideout.btc.coins = 2
		r = H.act(nil, p, { op = "coins" })
		check("collected coins are cold wallets, found in raid", r == true and count(p, "COLD_WALLET") == 2 and firOf(p, "COLD_WALLET") == true and p.hideout.btc.coins == 0)
		local s = H.stateFor(p)
		check("the snapshot: power, fuel, slots, the farm", s.power == true and s.cap == 2 and s.btc and s.btc.gpus == 1 and s.btc.slots == 10 and s.levels.generator == 1)
		r = H.act(nil, p, { op = "build", m = "medstation" })
		check("money and items are checked before anything is taken", type(r) == "table" and r.code == "MISSING_ITEMS")
		-- an old save through Hideout.settle (Profiles.load calls it)
		local q = Settle.newProfile()
		q.hideout = { levels = { storage = 2, generator = 1 }, crafts = {}, build = nil }
		H.settle(q, nil)
		check("an old save loads: racks 2 -> stash 3, 10x50 rows", q.hideout.levels.stash == 3 and q.stashH == 50 and Inv.dims(q, "stash") == Config.STASH_W
			and select(2, Inv.dims(q, "stash")) == 50)
	end)

	-- ── everything a level or a craft asks for can be found, bought or crafted ───────────────────────────────────────
	guard("obtainable", function()
		local got = {}
		for _, list in TD.offers or {} do
			for _, of in list do
				got[of.id] = true
			end
		end
		for _, list in TD.barters or {} do
			for _, bt in list do
				got[bt.id] = true
			end
		end
		for _, rc in HD.recipes do
			got[rc.get[1]] = true
		end
		local okLoot, Loot = pcall(function()
			return require(Services.Loot)
		end)
		if okLoot and type(Loot) == "table" and Loot.POOLS then
			for _, pool in Loot.POOLS do
				for _, e in pool do
					if type(e) == "table" and e.id then
						got[e.id] = true
					end
				end
			end
		end
		-- a gun's default build can be stripped for its parts (EFT too: the AK-74N craft takes the wooden furniture that
		-- comes on AK-74s), so the parts on an obtainable gun's default build are obtainable
		local okWP, WP = pcall(function()
			return require(Shared.WeaponParts)
		end)
		if okWP and type(WP) == "table" and WP.META and WP.META.presets then
			local function walk(t)
				for _, sub in t[2] or {} do
					got[sub[1]] = true
					walk(sub)
				end
			end
			for _, pr in WP.META.presets do
				if got[pr.base] and pr.tree then
					walk(pr.tree)
				end
			end
		end
		local missing, pending = {}, {}
		local function want(id)
			if not got[id] and not table.find(missing, id) and not table.find(pending, id) then
				-- the three new barter goods wait for the coordinator's loot pools (hideout REQUEST): reported, not failed
				if id == "MOONSHINE" or id == "GUNPOWDER" or id == "FABRIC" then
					table.insert(pending, id)
				else
					table.insert(missing, id)
				end
			end
		end
		for _, m in HD.modules do
			for _, l in m.levels do
				for _, e in l.items or {} do
					want(e[1])
				end
			end
		end
		for _, rc in HD.recipes do
			for _, e in rc.give do
				want(e[1])
			end
			for _, e in rc.tools or {} do
				want(e[1])
			end
		end
		for _, s in HD.SCAV do
			if s.item then
				want(s.item)
			end
		end
		check("every item the hideout asks for can be found, bought or crafted" .. (#missing > 0 and (": " .. table.concat(missing, " ")) or ""), not okLoot or #missing == 0)
		if not okLoot then
			table.insert(notes, "PENDING loot pools not loaded here (checked against traders and crafts only; not there: " .. table.concat(missing, ", ") .. ")")
		end
		if #pending > 0 then
			table.insert(notes, "PENDING in no loot pool yet: " .. table.concat(pending, ", "))
		end
	end)

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

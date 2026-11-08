--!nonstrict
-- AI checks (decision ai-3a, EFT's numbers for the AI's senses and aim): the pure rules in shared/BotData.luau (notice
-- time by distance, the difficulty roll, sight and cone per role, the aim's settling, hit affection, the 1.0 head rule,
-- rain and fog, memory, hearing) and the EFT role each of our bosses and crews takes. How the AI behaves in a raid is
-- checked in Studio by the coordinator. Run with the other test modules (ZR_Dev "tests").
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local BotData = require(Shared.BotData)

local T = {}

local function near(a, b, eps)
	return type(a) == "number" and math.abs(a - b) <= (eps or 1e-6)
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
	local S = BotData.STUDS
	local stats = BotData.stats

	-- notice time by distance (Look): 0.1 s close, 1 s at 90 m, 3 s at 160 m, straight lines between, the last slope on
	local N = BotData.noticeTime
	check("notice: 0.1 s right next to the bot", near(N(0), 0.1))
	check("notice: 0.55 s at 45 m, half way to 90 m", near(N(45), 0.55))
	check("notice: 1 s at 90 m", near(N(90), 1))
	check("notice: 2 s at 125 m, half way to 160 m", near(N(125), 2))
	check("notice: 3 s at 160 m", near(N(160), 3))
	check("notice: 5 s at 230 m (the 90-160 m slope carries on)", near(N(230), 5))
	local rising = true
	for m = 0, 260, 5 do
		if N(m + 5) <= N(m) then
			rising = false
		end
	end
	check("notice: never quicker further away", rising)
	local scav = stats("assault", "normal")
	check("notice: a normal scav notices someone 90 m (281 studs) away in 1 s", near(BotData.noticeAt(90 * S, scav), 1))
	check("notice: Birdeye (VISIBILITY_CHANGE_SPEED 15.384) at 160 m in 0.2 s", near(BotData.noticeAt(160 * S, stats("followerbirdeye")), 3 / 15.384, 1e-4))
	check("notice: Knight twice as quick as the Broker, the Broker twice as quick as a scav",
		stats("bossknight").notice == 2 * stats("bossbully").notice and stats("bossbully").notice == 2 * scav.notice)

	-- the difficulty roll: EFT's mix on Customs (Border Yard) and Interchange (Meridian Mall)
	local mix = BotData.mapMods("border").mix
	local mixM = BotData.mapMods("meridian").mix
	check("difficulty mix: 10 / 50 / 40 on Border Yard and Meridian",
		mix.easy == 10 and mix.normal == 50 and mix.hard == 40 and mixM.easy == 10 and mixM.normal == 50 and mixM.hard == 40)
	local even = { easy = 0, normal = 0, hard = 0 }
	for i = 1, 1000 do
		local d = BotData.roll((i - 0.5) / 1000, mix)
		even[d] += 1
	end
	check(string.format("difficulty roll: 1,000 evenly spread rolls give 100 / 500 / 400 (got %d / %d / %d)", even.easy, even.normal, even.hard),
		even.easy == 100 and even.normal == 500 and even.hard == 400)
	local rng = Random.new(20261108)
	local got = { easy = 0, normal = 0, hard = 0 }
	for _ = 1, 20000 do
		local d = BotData.difficulty("assault", rng:NextNumber(), mix)
		got[d] += 1
	end
	local pe, pn, ph = got.easy / 200, got.normal / 200, got.hard / 200
	check(string.format("difficulty roll: 20,000 scavs within 1.5 points of 10 / 50 / 40 %% (got %.1f / %.1f / %.1f)", pe, pn, ph),
		math.abs(pe - 10) < 1.5 and math.abs(pn - 50) < 1.5 and math.abs(ph - 40) < 1.5)
	check("difficulty: bosses and guards fight at normal, sniper scavs at hard",
		BotData.difficulty("bossbully", 0.01, mix) == "normal" and BotData.difficulty("followerbully", 0.99, mix) == "normal"
			and BotData.difficulty("marksman", 0.5, mix) == "hard")
	check("difficulty: hard scavs aim better than normal ones, easy ones worse (BASE_SHIEF)",
		stats("assault", "hard").spreadMul < 1 and scav.spreadMul == 1 and stats("assault", "easy").spreadMul > 1)

	-- sight and cone per role (bot_presets over the bot files), in studs
	local function sees(role, m, cone, diff)
		local s = stats(role, diff)
		return near(s.sight, m * S) and s.cone == cone
	end
	check("sight: scavs 125 / 129 / 137 m over 70 / 70 / 75 degrees each side (easy / normal / hard)",
		sees("assault", 125, 70, "easy") and sees("assault", 129, 70, "normal") and sees("assault", 137, 75, "hard"))
	check("sight: a normal scav's cone test is cos 70 degrees", near(scav.coneCos, math.cos(math.rad(70))))
	check("sight: sniper scavs 220 m (normal), raiders 127 m", sees("marksman", 220, 80, "normal") and sees("pmcbot", 127, 70))
	check("sight: the Broker (Reshala) 140 m over 80 degrees, his guards 142 m over 160", sees("bossbully", 140, 80) and sees("followerbully", 142, 160))
	check("sight: the Caretaker (Killa) and the Stoker (Tagilla) 137 m all round",
		sees("bosskilla", 137, 180) and sees("bosstagilla", 137, 180) and stats("bosskilla").coneCos < -1 and stats("bosstagilla").coneCos < -1)
	check("sight: THE HOUNDS 142 / 170 / 250 m (Knight, Big Pipe, Birdeye)",
		sees("bossknight", 142, 160) and sees("followerbigpipe", 170, 180) and sees("followerbirdeye", 250, 179))
	check("sight: the Forester (Partisan) 117 m over 70, the cultists 142 m over 160",
		sees("bosspartisan", 117, 70) and sees("sectantpriest", 142, 160) and sees("sectantwarrior", 142, 160))
	local wake = (ctx and ctx.AI and ctx.AI.WAKE_NEAR) or 265 * S
	local bad = {}
	for role, set in BotData.ROLES do
		for diff, r in set do
			if not (r.sight > 0 and r.sight * S <= wake and r.cone > 0 and r.cone <= 180 and r.notice > 0 and r.aimTime > 0) then
				table.insert(bad, role .. "/" .. diff)
			end
		end
	end
	check("sight: every role sees no further than a sleeping bot wakes (265 m), cones within 180" .. (#bad > 0 and (" (" .. table.concat(bad, ", ") .. ")") or ""), #bad == 0)

	-- the aim settles (Scattering MaxScatter over WorkingScatter, within Aiming.MAX_AIM_TIME)
	local A = BotData.aimMul
	check("aim: a scav's error starts at twice its settled value", near(A(0, scav, false), 2))
	check("aim: half way through MAX_AIM_TIME (0.75 s) it is at 1.5x", near(A(0.75, scav, false), 1.5))
	check("aim: settled after 1.5 s", near(A(1.5, scav, false), 1) and near(A(9, scav, false), 1))
	check("aim: thrown away by a hit (the aim starts later) it stays at its widest", near(A(-1, scav, false), 2))
	check("aim: moving takes TIME_COEF_IF_MOVE longer (scav 1.5x)", A(1.5, scav, true) > 1 and near(A(2.25, scav, true), 1))
	check("aim: bosses start at 2.67x (0.4 over 0.15); Big Pipe settles in 0.3 s",
		near(A(0, stats("bossbully"), false), 0.4 / 0.15) and near(A(0.3, stats("followerbigpipe"), false), 1))

	-- hit affection (Aiming.BASE_HIT_AFFECTION_*)
	local H = BotData.hitAngle
	check("hit: a normal scav's aim is knocked 19-32 degrees and back in 1.17 s", scav.hitMin == 19 and scav.hitMax == 32 and near(scav.hitDelay, 1.17))
	check("hit: the knock is all there at once, half after half the time, gone after it",
		near(H(25, 1.17, 0), 25) and near(H(25, 1.17, 0.585), 12.5) and H(25, 1.17, 1.17) == 0 and H(25, 1.17, 5) == 0)
	local falling = true
	for i = 0, 11 do
		if H(30, 1.2, (i + 1) * 0.1) > H(30, 1.2, i * 0.1) then
			falling = false
		end
	end
	check("hit: the knock only ever shrinks", falling)
	check("hit: easy scavs take 1.77 s to recover, hard ones 0.27 s", near(stats("assault", "easy").hitDelay, 1.77) and near(stats("assault", "hard").hitDelay, 0.27))
	local smaller = true
	for _, role in { "pmcbot", "bossbully", "followerbully", "bosskilla", "bosstagilla", "bossknight", "followerbigpipe", "followerbirdeye", "bosspartisan", "sectantpriest", "sectantwarrior" } do
		if stats(role).hitMax >= scav.hitMin then
			smaller = false
		end
	end
	check("hit: bosses, guards and raiders are knocked less than any scav (10 degrees at most)", smaller)
	check("hit: the Caretaker and the Stoker recover in 0.27 s and almost never lose their aim",
		near(stats("bosskilla").hitDelay, 0.27) and stats("bosskilla").discard <= 0.01 and stats("bosstagilla").discard <= 0.01)
	check("hit: a scav throws its aim away 96 % of the time, for 2.3-3.1 s", near(scav.discard, 0.96) and scav.discardMin == 2.3 and scav.discardMax == 3.1)

	-- EFT 1.0: slower detection and no head shots on someone unseen for 15 s
	check("1.0: first contact holds a scav's fire 0.75 s (bot_presets), Killa's 0.1 s (no preset)", scav.firstAdd == 0.75 and stats("bosskilla").firstAdd == 0.1)
	check("1.0: head shots only on a contact within 15 s of the last sight",
		BotData.headAllowed(3) and BotData.headAllowed(14.9) and not BotData.headAllowed(15) and not BotData.headAllowed(60) and not BotData.headAllowed(nil))
	check("1.0: a scav loses someone out of view after 0.25 s, the Goons' Birdeye after 2 s", scav.lose == 0.25 and stats("followerbirdeye").lose == 2)

	-- memory and hearing
	check("memory: 52 s for a scav, 104 s for Knight (HALBERD), 102 s for Birdeye; 22 s of searching",
		scav.forget == 52 and stats("bossknight").forget == 104 and stats("followerbirdeye").forget == 102 and scav.find == 22)
	check("hearing: a scav hears steps for sure within 10 m and up to 30 m (65 % at normal)",
		near(scav.hearClose, 10 * S) and near(scav.hearFar, 30 * S) and near(scav.hearChance, 0.65))
	check("hearing: the Caretaker 36 / 66 m, raiders 26 / 56 m",
		near(stats("bosskilla").hearClose, 36 * S) and near(stats("bosskilla").hearFar, 66 * S) and near(stats("pmcbot").hearFar, 56 * S))
	check("hearing: gunfire carries as far as FAR_DIST says (scav 1x, Killa 2.2x)", near(scav.shotHear, 1) and near(stats("bosskilla").shotHear, 2.2))
	check("hearing: a calm scav turns to a sound after 0.75 s, a boss at once", near(scav.hearPeace, 0.75) and stats("bossbully").hearPeace == 0)
	check("sight: calm scavs see 75 % as far (VISION_DIST_COEF_PEACE), easy ones half", scav.peace == 0.75 and stats("assault", "easy").peace == 0.5)

	-- rain and fog (BotLocationModifier: rain takes 35 % off at full rain on Customs and Interchange; fog nothing)
	local mods = BotData.mapMods("border")
	local s1, v1 = BotData.weather(mods, 1, 0)
	local s2, v2 = BotData.weather(mods, 0, 1)
	local s3 = BotData.weather(mods, 0.5, 1)
	check("weather: full rain leaves 65 % of sight and the notice speed as it is", near(s1, 0.65) and near(v1, 1))
	check("weather: fog changes nothing on Customs (coefficients 0)", near(s2, 1) and near(v2, 1))
	check("weather: half rain in fog leaves 82.5 %", near(s3, 0.825))
	check("weather: the maps with no twin take Customs' numbers", BotData.mapMods("quay7") == BotData.mapMods(nil) and BotData.mapMods(nil).rainSight == 0.35)

	-- every boss, named man and crew maps to an EFT role
	local R, roleFor = BotData.ROLES, BotData.roleFor
	local missing = {}
	for _, map in { BotData.BOSS_ROLE, BotData.CREW_ROLE, BotData.KIND_ROLE } do
		for label, role in map do
			if not (R[role] and R[role].normal) then
				table.insert(missing, label .. " -> " .. role)
			end
		end
	end
	check("roles: every mapped role has EFT numbers" .. (#missing > 0 and (" (" .. table.concat(missing, ", ") .. ")") or ""), #missing == 0)
	local want = {
		Broker = "bossbully", Caretaker = "bosskilla", Stoker = "bosstagilla", Halberd = "bossknight", Mortar = "followerbigpipe",
		Kestrel = "followerbirdeye", Forester = "bosspartisan", Priest = "sectantpriest", Cultist = "sectantwarrior",
		Foreman = "bossgluhar", Sawyer = "bosskojaniy",
	}
	local wrong = {}
	for label, role in want do
		if roleFor("boss", label) ~= role then
			table.insert(wrong, label)
		end
	end
	check("roles: Broker, Caretaker, Stoker, THE HOUNDS, Forester, THE CULT, Foreman and Sawyer each take their role" .. (#wrong > 0 and (" (" .. table.concat(wrong, ", ") .. ")") or ""), #wrong == 0)
	check("roles: crews by their boss (Broker's guards, the Foreman's and the Sawyer's crews); named crew by name",
		roleFor("follower", "Crew", "Broker") == "followerbully" and roleFor("follower", "Crew", "Foreman") == "followergluharassault"
			and roleFor("follower", "Crew", "Sawyer") == "followerkojaniy" and roleFor("follower", "Mortar", "Halberd") == "followerbigpipe"
			and roleFor("follower", "Cultist", nil) == "sectantwarrior")
	check("roles: scavs (and scav groups) are assault, every Watch guard a raider (pmcbot)",
		roleFor("scav", "Scav", nil) == "assault" and roleFor("scav", "Scav", "Scav") == "assault" and roleFor("watch", "Harbor Watch") == "pmcbot"
			and roleFor("watch", "Bastion Gunner") == "pmcbot" and roleFor("watch", "Ranger") == "pmcbot")
	-- and the bosses the maps really spawn (the maps built on this server)
	local W = ctx and ctx.World
	local nMaps, nLabels, unknown = 0, 0, {}
	-- a crew member is a spot (unnamed: his boss's crew role) or a table with its own label (THE HOUNDS, the cultists)
	local function crew(list, id, label)
		for _, p in list or {} do
			nLabels += 1
			local named = type(p) == "table" and p.label
			if named and not BotData.BOSS_ROLE[named] then
				table.insert(unknown, id .. ": " .. label .. "'s " .. named)
			elseif not named and not BotData.CREW_ROLE[label] then
				table.insert(unknown, id .. ": " .. label .. "'s crew")
			end
		end
	end
	for id, m in (W and W.maps) or {} do
		nMaps += 1
		for _, b in m.bosses or (m.boss and { m.boss }) or {} do
			local label = b.label or "Foreman" -- AI.reset names a boss without a label the Foreman
			nLabels += 1
			if not BotData.BOSS_ROLE[label] then
				table.insert(unknown, id .. ": " .. label)
			end
			crew(b.crew, id, label)
			for _, z in b.zones or {} do
				crew(z.crew, id, label)
			end
		end
	end
	check(string.format("roles: every boss and crew on the %d built maps has its own role (%d checked)%s", nMaps, nLabels,
		#unknown > 0 and (": " .. table.concat(unknown, ", ")) or ""), #unknown == 0)

	-- AI looting (decision ai-8a): what a bot takes from a body (Services/BotLoot), and that it is lost to insurance
	local okLoot, errLoot = pcall(function()
		local Services = script.Parent.Parent:WaitForChild("Services")
		local Inv = require(Services.Inv)
		local BotLoot = require(Services.BotLoot)
		local function wear(h, id, slot, extra)
			local g, it = Inv.newItem(id, 1, extra)
			assert(Inv.placeSlot(h, g, it, slot), id)
			return g
		end
		local function carry(h, id, n, extra, order)
			local g, it = Inv.newItem(id, n or 1, extra)
			assert(Inv.place(h, g, it, order or Inv.loadOrder(h)), id)
			return g
		end
		-- the bot: a cheap pump gun, a chest rig, a day bag. The body: a better rifle (insured) with a loaded magazine
		-- in the pack, a helmet (insured), a gold chain (insured), a dressing, a key, and a chain in its secure container
		local bot = Inv.newHolder("raid")
		local pump = wear(bot, "HARROW12", "primary")
		wear(bot, "RIG_CHEST", "rig")
		wear(bot, "BAG_SLING", "back")
		local body = Inv.newHolder("raid")
		local rifle = wear(body, "KST_RIFLE", "primary", { ins = 99 })
		local helmet = wear(body, "HELMET_C3", "head", { ins = 99 })
		wear(body, "CANVAS_BAG", "back")
		local sec = wear(body, "SECURE_S", "secure")
		local mag = carry(body, "KST_MAG", 1, { a = 30, at = "A76_PS" })
		local chain = carry(body, "GOLD_CHAIN", 1, { ins = 99 })
		local dressing = carry(body, "BANDAGE", 1)
		local key = carry(body, "KEY_OFFICE", 1)
		local hidden = carry(body, "GOLD_CHAIN", 1, nil, { sec })
		local plan = BotLoot.pick(bot, body)
		local kinds = {}
		for _, e in plan do
			kinds[e.g] = e.kind
		end
		check("loot: a better gun with rounds for it (worth a fifth more than its own)", kinds[rifle] == "gun")
		check("loot: a helmet for its empty head slot", kinds[helmet] == "wear")
		check("loot: a gold chain, worth carrying", kinds[chain] == "take")
		check("loot: no dressing (too cheap), no key, nothing out of the secure container", kinds[dressing] == nil and kinds[key] == nil and kinds[hidden] == nil)
		local res = BotLoot.apply(bot, body, plan)
		check("loot: the rifle in hand, the pump gun slung as its second gun", bot.slots.primary == rifle and bot.slots.secondary == pump and res.gun == rifle)
		check("loot: the rifle's loaded magazine comes with it", bot.items[mag] ~= nil and body.items[mag] == nil)
		check("loot: the helmet worn and the chain carried", bot.slots.head == helmet and bot.items[chain] ~= nil and body.items[chain] == nil and res.gear == true)
		check("loot: what a bot takes is lost to insurance (EFT 0.13.5)", bot.items[rifle].ins == nil and bot.items[helmet].ins == nil and bot.items[chain].ins == nil)
		check("loot: both inventories stay valid", (Inv.check(bot)) and (Inv.check(body)) and body.items[hidden] ~= nil)
		-- a cheaper gun stays, ammunition for another calibre stays, four things at most
		local bot2 = Inv.newHolder("raid")
		wear(bot2, "KST_RIFLE", "primary")
		wear(bot2, "BAG_PATROL", "back")
		local body2 = Inv.newHolder("raid")
		local pump2 = wear(body2, "HARROW12", "primary")
		wear(body2, "BAG_RAID", "back")
		local buck = carry(body2, "A12_BUCK", 20)
		for _ = 1, 6 do
			carry(body2, "GOLD_CHAIN", 1)
		end
		local plan2 = BotLoot.pick(bot2, body2)
		local k2, takes = {}, 0
		for _, e in plan2 do
			k2[e.g] = e.kind
			if e.kind == "take" then
				takes += 1
			end
		end
		check("loot: a cheaper gun and rounds it cannot fire stay on the body", k2[pump2] == nil and k2[buck] == nil)
		check("loot: at most four things a search", takes == BotLoot.MAX_TAKE)
	end)
	if not okLoot then
		check("loot: the checks ran (" .. tostring(errLoot) .. ")", false)
	end

	local summary = string.format("AiTests: %d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

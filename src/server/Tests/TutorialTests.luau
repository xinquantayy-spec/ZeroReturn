--!nonstrict
-- First-raid checks for decision ui-5a (Tarkov 1.0's tutorial raid): the rules in TutorialData.luau, the course built by
-- Maps/Tutorial.luau, the loaned kit and its settlement (Settle.deployTutorial), and the step rules of Services/Tutorial.
-- Run via ZR_Dev "tests" (every module in Tests). Nothing here starts a run or touches a real player.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local TD = require(Shared.TutorialData)
local Items = require(Shared.Items)
local Maps = require(Shared.Maps)

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
	local function guard(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(label .. ": the checks ran without an error (" .. tostring(err) .. ")", false)
		end
	end

	guard("the rules", function()
		local ids, kinds = {}, true
		for _, s in TD.STEPS do
			ids[s.id] = (ids[s.id] or 0) + 1
			local d = s.done
			kinds = kinds and (string.match(d, "^has:[%w_]+$") ~= nil or d == "loaded" or string.match(d, "^clear:%a+$") ~= nil
				or d == "healthy" or string.match(d, "^zone:%a+$") ~= nil or d == "extract")
		end
		local unique = true
		for _, n in ids do
			unique = unique and n == 1
		end
		check("eight steps in Tarkov's order, each id once, each with a condition the service knows", #TD.STEPS == 8 and unique and kinds
			and TD.STEPS[1].id == "desk" and TD.STEPS[#TD.STEPS].done == "extract")
		local real = true
		for _, id in TD.KIT.slots do
			real = real and Items.defs[id] ~= nil
		end
		for _, e in TD.KIT.pockets do
			real = real and Items.defs[e[1]] ~= nil
		end
		for _, list in TD.LOOT do
			for _, e in list do
				real = real and Items.defs[e[1]] ~= nil
			end
		end
		check("the kit and the course's loot are real items; the body carries the SMG and three magazines", real and Items.defs[TD.AMMO] ~= nil
			and TD.LOOT.body[1][1] == "SPARROW_SMG" and TD.LOOT.body[2][2] == 3)
		check("the next step after each and none after the last", TD.next(nil) == TD.STEPS[1] and TD.next("desk") == TD.STEPS[2]
			and TD.next("exit") == nil)
		check("offered to a profile that has never raided, not after a raid, a finish or a skip",
			TD.offered({ stats = { raids = 0, scavRaids = 0 } }) and not TD.offered({ stats = { raids = 1, scavRaids = 0 } })
			and not TD.offered({ tut = "done", stats = { raids = 0 } }) and not TD.offered({ tut = "skipped" }) and not TD.offered(nil))
	end)

	guard("the course", function()
		local m = ctx.World.maps.tutorial
		check("the course is built as a map of its own, with its exit and its spawn", m ~= nil and m.extracts.TG ~= nil
			and m.spawns[1] ~= nil and m.spawns[1].id == TD.SPAWN)
		local inOrder = false
		for _, id in Maps.order do
			inOrder = inOrder or id == "tutorial"
		end
		local voted = false
		for _, id in ctx.Match.builtMaps() do
			voted = voted or id == "tutorial"
		end
		check("never in the map vote", not inOrder and not voted and Maps.defs.tutorial ~= nil)
		local sp = ctx.World.tutorial
		local acts = true
		for _, p in sp and sp.signs or {} do
			acts = acts and type(p:GetAttribute("ZR_TutSign")) == "string"
		end
		local groups = {}
		for _, p in sp and sp.posts or {} do
			groups[p.group] = (groups[p.group] or 0) + 1
		end
		check("its signs name controls, scavs hold the garage (two), the street and the office, and its zones are set", sp ~= nil
			and #sp.signs >= 8 and acts and groups.garage == 2 and groups.street == 1 and groups.office == 1
			and sp.zones.office ~= nil and sp.zones.yard ~= nil and sp.zones.garage ~= nil)
		local bars = 0
		for _, d in sp.model:GetDescendants() do
			if d:GetAttribute("ZR_TutBar") then
				bars += 1
			end
		end
		check("green bars run the whole way (start to gate)", bars >= 40)
	end)

	guard("the kit and its settlement", function()
		local Settle, Inv = ctx.Settle, ctx.Inv
		local p = Settle.newProfile()
		local kit = ctx.Tutorial.kit()
		local slots = kit.slots
		check("the loaned kit: a knife, a chest rig, a small bag and a dressing, no gun", slots.melee ~= nil and slots.rig ~= nil
			and slots.back ~= nil and slots.primary == nil and Inv.findKind(kit, "med") ~= nil)
		local inv, err = Settle.deployTutorial(p, "tut-test", 1000, kit)
		check("it goes in without a scav cooldown or a scav raid counted", inv == kit and err == nil and p.pendingRaid.tutorial == true
			and (p.scavReadyAt or 0) == 0 and p.stats.scavRaids == 0)
		local g, it = Inv.newItem("SPARROW_SMG", 1)
		it.fip = true
		Inv.place(inv, g, it, Inv.loadOrder(inv))
		local receipt = Settle.finalize(p, "tut-test", "SUCCESS", inv, 1100)
		local stash = false
		for _, x in p.items do
			stash = stash or x.id == "SPARROW_SMG"
		end
		check("an extract brings the kit and the loot to the stash, found in raid, with no scav survival counted",
			receipt ~= nil and stash and p.stats.scavSurvived == 0 and p.pendingRaid == nil)
	end)

	guard("the step rules", function()
		local Inv = ctx.Inv
		local h = Inv.newHolder("raid")
		local s = { inv = h, active = "melee" }
		local run = { bots = { { group = "garage", u = { alive = false } }, { group = "street", u = { alive = true, hum = { Health = 100 } } } } }
		local fake = { Character = nil }
		local gun = { id = "has", done = "has:SPARROW_SMG" }
		check("has: not before the gun is carried", not ctx.Tutorial.met(fake, s, run, gun))
		local g, it = Inv.newItem("SPARROW_SMG", 1)
		Inv.placeSlot(h, g, it, "primary")
		check("has: met once it is", ctx.Tutorial.met(fake, s, run, gun))
		local loaded = { id = "load", done = "loaded" }
		local mg = h.items[g].mag
		if mg then
			h.items[mg].a = 0
		end
		check("loaded: not with an empty magazine or the gun not in hand", not ctx.Tutorial.met(fake, s, run, loaded))
		local m2, mag = Inv.newItem("SPARROW_MAG", 1, { a = 30, at = TD.AMMO })
		h.items[m2] = mag
		h.items[g].mag = m2
		s.active = "primary"
		check("loaded: met with a loaded magazine in the gun in hand", ctx.Tutorial.met(fake, s, run, loaded))
		check("clear: met when every scav of the group is down, not while one stands",
			ctx.Tutorial.met(fake, s, run, { done = "clear:garage" }) and not ctx.Tutorial.met(fake, s, run, { done = "clear:street" }))
		check("extract: only an extract ends the last step", not ctx.Tutorial.met(fake, s, run, { done = "extract" }))
	end)

	local summary = string.format("TutorialTests: %d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

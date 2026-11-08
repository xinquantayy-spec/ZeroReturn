--!nonstrict
-- What a bot takes when it loots (decision ai-8a, Tarkov's rules). EFT: scavs loot bodies since 0.12.7 ("to grab
-- additional firepower") and search corpses and loose loot since 0.13.5, whose notes add that "contents taken by bots
-- are not refundable by insurance"; 1.0.2 fixed bots re-equipping looted weapons. Which items a bot prefers is not
-- written down anywhere we could reach, so the choice is ours: a gun worth a fifth more than its own with rounds for
-- it, gear for a slot it has empty, then the most valuable things per cell that fit its rig, pockets and pack, at most
-- four a search and nothing out of a secure container. Pure apart from moving items between the two holders (Inv);
-- AI.luau walks the bot there, searches and re-arms it. AiTests checks the choices and the moves.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Items = require(Shared.Items)
local Inv = require(script.Parent.Inv)

local BotLoot = {}
local defs = Items.defs

BotLoot.MAX_TAKE = 4 -- things a search takes besides a gun and worn gear (ours)
BotLoot.MIN_VALUE = 4000 -- worth carrying (MK, ours: a ration is not, a chain is)
BotLoot.GUN_BETTER = 1.2 -- a looted gun must be worth this much more than the bot's own (ours)
BotLoot.WEAR = { "head", "armor", "rig", "back" }
local GUN_SLOTS = { "primary", "secondary" }
local SKIP = { quest = true, key = true, secure = true, hazard = true }

-- an item's worth with everything on and in it
function BotLoot.worth(h, g)
	local it = h.items[g]
	if not it then
		return 0
	end
	local v = Items.valueOf(it)
	for _, sg in Inv.descendants(h, g) do
		local s = h.items[sg]
		if s then
			v += Items.valueOf(s)
		end
	end
	return v
end

-- is g inside a secure container (or the container itself)? Bots never take those (Tarkov: the secure container
-- cannot be looted)
local function inSecure(h, g)
	local sec = h.slots and h.slots.secure
	if not sec then
		return false
	end
	local cur = g
	for _ = 1, 32 do
		if cur == sec then
			return true
		end
		cur = Inv.parentOf(h, cur)
		if not cur then
			return false
		end
	end
	return false
end

-- rounds for gun g of holder h somewhere in h: its own magazine or tube, a magazine of its family, a stack of its
-- calibre
local function hasRounds(h, g)
	local w = h.items[g]
	local wd = w and defs[w.id]
	if not wd then
		return false
	end
	if (w.a or 0) > 0 then
		return true
	end
	local m = w.mag and h.items[w.mag]
	if m and (m.a or 0) > 0 then
		return true
	end
	for _, pl in h.grids or {} do
		for og in pl do
			local o = h.items[og]
			local od = o and defs[o.id]
			if od and ((od.kind == "mag" and wd.family and od.family == wd.family and (o.a or 0) > 0) or (od.kind == "ammo" and wd.caliber and od.caliber == wd.caliber)) then
				return true
			end
		end
	end
	return false
end

-- the bot's gun in hand slot order (what it fights with)
local function botGun(bot)
	for _, s in GUN_SLOTS do
		local g = bot.slots[s]
		if g and bot.items[g] and defs[bot.items[g].id] and defs[bot.items[g].id].weapon then
			return g, s
		end
	end
	return nil, nil
end

-- the plan for bot holder `bot` looting holder `src`: an ordered list of { kind = "gun", g } | { kind = "wear", slot,
-- g } | { kind = "take", g }. Nothing is moved.
function BotLoot.pick(bot, src)
	local plan = {}
	if not (bot and src and src.items) then
		return plan
	end
	-- 1. a better gun (a body's slung or carried gun, or one lying in a pile)
	local myG = botGun(bot)
	local mine = myG and BotLoot.worth(bot, myG) or 0
	local bestG, bestV = nil, mine * BotLoot.GUN_BETTER
	local function considerGun(g)
		local it = src.items[g]
		local d = it and defs[it.id]
		if d and (d.kind == "weapon") and not inSecure(src, g) and hasRounds(src, g) then
			local v = BotLoot.worth(src, g)
			if v > bestV then
				bestG, bestV = g, v
			end
		end
	end
	for _, s in GUN_SLOTS do
		if src.slots and src.slots[s] then
			considerGun(src.slots[s])
		end
	end
	for _, pl in src.grids or {} do
		for g in pl do
			considerGun(g)
		end
	end
	if bestG then
		table.insert(plan, { kind = "gun", g = bestG })
	end
	-- 2. worn gear for a slot the bot has empty (a body's helmet, armour, rig, pack)
	for _, slot in BotLoot.WEAR do
		local g = src.slots and src.slots[slot]
		if g and not bot.slots[slot] and src.items[g] then
			-- the slot takes the kind, and armour and an armoured rig are not worn together (the move itself checks
			-- the rest, Inv.canEquip, and leaves the item where it is if the bot cannot wear it)
			local d = defs[src.items[g].id]
			local accepts = Items.SLOTS[slot]
			local rig = bot.slots.rig and bot.items[bot.slots.rig]
			local clash = (slot == "armor" and rig and defs[rig.id] and defs[rig.id].armor) or (slot == "rig" and d and d.armor and bot.slots.armor)
			if d and accepts and accepts[d.kind] and not clash then
				table.insert(plan, { kind = "wear", slot = slot, g = g })
			end
		end
	end
	-- 3. valuables: the most worth per cell first, never ammunition for another gun, keys, quest items or the secure
	-- container's contents
	local myCal = myG and defs[bot.items[myG].id].caliber
	local list = {}
	local planned = {}
	for _, e in plan do
		planned[e.g] = true
	end
	for cid, pl in src.grids or {} do
		for g in pl do
			local it = src.items[g]
			local d = it and defs[it.id]
			if d and not planned[g] and not SKIP[d.kind] and d.kind ~= "weapon" and d.kind ~= "pistol" and not inSecure(src, g) and not (d.grid and next(src.grids[g] or {}) ~= nil) then
				local ok = true
				if d.kind == "ammo" or d.kind == "mag" then
					ok = myCal ~= nil and (d.caliber == myCal or (d.kind == "mag" and d.family ~= nil and d.family == defs[bot.items[myG].id].family))
				end
				local v = BotLoot.worth(src, g)
				if ok and v >= BotLoot.MIN_VALUE then
					local w, h = Inv.sizeOf(it)
					table.insert(list, { g = g, v = v, per = v / math.max(1, w * h), cid = cid })
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.per ~= b.per then
			return a.per > b.per
		end
		return a.g < b.g
	end)
	for i = 1, math.min(#list, BotLoot.MAX_TAKE) do
		table.insert(plan, { kind = "take", g = list[i].g })
	end
	return plan
end

-- what a bot takes is lost to insurance (EFT 0.13.5): clear the claim on g and everything on or in it
local function voidInsurance(h, g)
	local all = Inv.descendants(h, g)
	table.insert(all, g)
	for _, x in all do
		local it = h.items[x]
		if it then
			it.ins, it.isr = nil, nil
		end
	end
end

-- carry the plan out. Returns { moved = n, gun = guid of a new gun in the bot's primary slot?, gear = true if worn
-- gear changed }. The bot's own gun goes to its free secondary slot; with both slots taken it keeps its guns.
function BotLoot.apply(bot, src, plan)
	local out = { moved = 0, gear = false }
	local order = Inv.loadOrder(bot)
	for _, e in plan do
		if src.items[e.g] then
			if e.kind == "gun" then
				local old = bot.slots.primary
				local ok = true
				if old then
					if not bot.slots.secondary then
						ok = Inv.move(bot, old, { slot = "secondary" }) == true
					else
						ok = false
					end
				end
				if ok and Inv.transfer(src, e.g, bot, { slot = "primary" }, nil) then
					voidInsurance(bot, e.g)
					out.moved += 1
					out.gun = e.g
					-- its magazines and rounds come too, as far as they fit
					local wd = defs[bot.items[e.g].id]
					for _, pl in src.grids or {} do
						for og in table.clone(pl) do
							local o = src.items[og]
							local od = o and defs[o.id]
							if od and not inSecure(src, og) and ((od.kind == "mag" and wd.family and od.family == wd.family) or (od.kind == "ammo" and wd.caliber and od.caliber == wd.caliber)) then
								if Inv.transfer(src, og, bot, nil, order) then
									voidInsurance(bot, og)
								end
							end
						end
					end
				elseif old and bot.slots.secondary == old and not bot.slots.primary then
					Inv.move(bot, old, { slot = "primary" }) -- undo
				end
			elseif e.kind == "wear" then
				if not bot.slots[e.slot] and Inv.transfer(src, e.g, bot, { slot = e.slot }, nil) then
					voidInsurance(bot, e.g)
					out.moved += 1
					out.gear = true
				end
			elseif Inv.transfer(src, e.g, bot, nil, order) then
				voidInsurance(bot, e.g)
				out.moved += 1
			end
		end
	end
	return out
end

return BotLoot

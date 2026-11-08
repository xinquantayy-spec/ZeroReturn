--!nonstrict
-- The flea market's rules (Tarkov, docs/design/EFT_PARITY.md section 3), shared by the server's market and the
-- client's BROWSE (the level gates) and ADD OFFER (the fee preview) windows and the logic tests.
local Items = require(script.Parent.Items)
local Weapons = require(script.Parent.Weapons)

local Flea = {}
Flea.LEVEL = 15
Flea.WINDOW = 900 -- seconds per market refresh
Flea.DURATION = 12 * 3600 -- an offer's life
Flea.BANNED = { secure = true, quest = true }

-- EFT's flea ban list (audit economy.3): the strongest gear and items tied to events never go on the market. EFT bans
-- its class 5-6 body armour (Zabralo, Redut-T5, THOR), its class 4-5 helmets and their face shields (Altyn, Rys-T,
-- Vulkan, Exfil, FAST MT, Airframe, Caiman, Killa's Maska), the raid packs (6Sh118, Blackjack 50, Attack 2), the
-- GPNVG-18 and the thermal sights, the top armour-piercing rounds (M995/M855A1, 7.62x39 BP, 7.62x54R SNB, 9x19 AP 6.3),
-- the red RSP-30 flare, dog tags, the Sacred Amulet and the physical bitcoin (patch 0.14 list, GGRecon 16 Jan 2024;
-- patch 0.12.12 list, NME 13 Dec 2021; the red flare "Not on flea", tarkovforge 2026). Ours, item for item:
Flea.BANNED_ITEMS = {
	ARMOR_C5 = true, ARMOR_C6 = true, -- class 5 and 6 body armour
	-- class 5 and 6 plates (EFT 0.14.0.0: "class 5 and 6 plates cannot be sold on the flea market"; gameplay-2a)
	PLATE_CE5 = true, PLATE_PE5 = true, PLATE_CE6 = true, PLATE_PE6 = true, PLATE_CE5S = true,
	PLATE_HP5F = true, PLATE_HP5B = true, PLATE_HP5S = true, PLATE_BWF = true, PLATE_BWB = true, PLATE_BWS = true,
	HELMET_C4 = true, HELMET_C5 = true, MASK_WELDER = true, -- class 4-5 helmets and the class 5 face armour
	HARDHAT_FOREMAN = true, -- a boss's own helmet (EFT bans Killa's Maska)
	TH_T7 = true, NV_QUAD = true, -- thermal goggles and the panoramic quad (GPNVG-18)
	BAG_RAID = true, -- the raid pack
	A62_AP = true, A76_BP = true, A76L_SNB = true, A9_AP = true, -- the top armour-piercing round of each calibre
	FLARE_RED = true, DOGTAG = true, RITUAL_AMULET = true, COLD_WALLET = true, -- the airdrop flare, tags, amulet, the "bitcoin"
}

-- EFT 1.0's category gates (audit economy.3): the market opens at level 15, but buying some categories needs a higher
-- level; the offer shows greyed out with the level it needs. Level 20 bolt-action rifles, foregrips and muzzle devices;
-- 25 assault rifles, marksman rifles, backpacks, lights and lasers; 30 barter items, gear components, injectors and
-- keycards; M80 at 35 (Insider Gaming and attractmo.de, 16 Nov 2025; timesaver.gg, June 2026, "greyed out with a level
-- requirement"). Battlestate has published no full table, so only these are gated. Listing your own offers is not gated
-- (no source says it is).
Flea.GATES = {
	weapon = { bolt = 20, rifle = 25 }, -- by the gun's class (Weapons)
	mod = { foregrip = 20, muzzle = 20, tactical = 25 }, -- by the part's category (WeaponParts): brakes, flash hiders,
	-- compensators and suppressors are EFT's "muzzle devices"
	backpack = 25,
	loot = 30, repair = 30, -- barter items (the handbook lists the repair kit with them)
	nvg = 30, -- gear components: the goggles that go on a helmet's mount
}
Flea.ITEM_LEVEL = { A76L_LPS = 35 } -- the full-power 7.6x54R LPS stands in for EFT's 7.62x51 M80 (pen 41 against our 42)

-- Tarkov's listing fee: VO x Ti x 4^PO x Q + VR x Tr x 4^PR x Q (one stack per offer, Q = 1)
function Flea.fee(baseValue, count, asked)
	local VO, VR = math.max(1, baseValue * count), math.max(1, asked)
	local PO, PR = math.log10(VO / VR), math.log10(VR / VO)
	if VR < VO then
		PO = (PO > 0) and PO ^ 1.08 or PO
	else
		PR = (PR > 0) and PR ^ 1.08 or PR
	end
	return math.ceil(VO * 0.03 * 4 ^ PO + VR * 0.03 * 4 ^ PR)
end

-- offer slots by flea rating (Tarkov's table)
function Flea.slots(rating)
	local r = rating or 0.2
	if r < 0.2 then
		return 1
	elseif r < 7 then
		return 2
	elseif r < 30 then
		return 3
	elseif r < 60 then
		return 4
	elseif r < 100 then
		return 5
	elseif r < 150 then
		return 6
	elseif r < 1000 then
		return 8
	end
	return 10
end

function Flea.tradeable(id)
	local d = Items.defs[id]
	return d ~= nil and not Flea.BANNED[d.kind] and not Flea.BANNED_ITEMS[id] and (d.value or 0) > 0
end

-- the player level an item needs to be bought on the market (EFT 1.0's category gates; Flea.LEVEL when none)
function Flea.levelFor(id)
	local d = Items.defs[id]
	if not d then
		return Flea.LEVEL
	end
	local lvl = Flea.ITEM_LEVEL[id]
	local g = Flea.GATES[d.kind]
	if not lvl and type(g) == "number" then
		lvl = g
	elseif not lvl and type(g) == "table" then
		local w = d.weapon and Weapons[d.weapon]
		lvl = (d.kind == "weapon" and w and g[w.class]) or (d.part and g[d.part.cat]) or nil
	end
	-- injectors and keycards (level 30)
	if not lvl and ((d.med and d.med.antidote) or (d.key and d.key.card)) then
		lvl = 30
	end
	return math.max(Flea.LEVEL, lvl or 0)
end

-- can a player of this level buy the item on the market: true, or false and why ("BANNED" / "LOCKED")
function Flea.canBuy(id, level)
	if not Flea.tradeable(id) then
		return false, "BANNED"
	end
	if (level or 1) < Flea.levelFor(id) then
		return false, "LOCKED"
	end
	return true
end

-- the market price an item settles around (the handbook value with a flea premium)
function Flea.marketPrice(id)
	local d = Items.defs[id]
	return math.floor((d and d.value or 0) * 1.15)
end

local SELLERS = { "Grit", "Halyard", "Moss", "Kestrel", "Ostrog", "Tallow", "Vesper", "Rook", "Sable", "Juniper", "Flint", "Marrow", "Pike", "Cinder", "Tamarack" }
-- the operators' offers on an item in a window: { i, seller, price, stock } (the same on every server)
function Flea.offersFor(id, window)
	local d = Items.defs[id]
	if not Flea.tradeable(id) then
		return {}
	end
	local seed = window * 131
	for c in string.gmatch(id, ".") do
		seed = (seed * 31 + string.byte(c)) % 2147483647
	end
	local rng = Random.new(seed)
	-- the rarer the item, the fewer people sell it (audit economy.2: epic and legendary used to get the most offers)
	local rare = ({ uncommon = 0.8, rare = 0.5, epic = 0.3, legendary = 0.15 })[d.rarity or ""] or 1
	local n = math.clamp(math.floor(rng:NextNumber() * 4 * rare + 1), 1, 4)
	local out = {}
	local mp = Flea.marketPrice(id)
	for i = 1, n do
		local price = math.max(1, math.floor(mp * (0.88 + rng:NextNumber() * 0.42)))
		local stock = d.stack > 1 and math.floor(d.stack * (0.5 + rng:NextNumber())) or rng:NextInteger(1, 3)
		table.insert(out, { i = i, seller = SELLERS[rng:NextInteger(1, #SELLERS)], price = price, stock = stock })
	end
	table.sort(out, function(a, b)
		return a.price < b.price
	end)
	return out
end

-- the chance an offer sells in a minute: near the market price within minutes, overpriced slowly, far over never
function Flea.saleRate(price, marketPrice)
	local r = price / math.max(1, marketPrice)
	if r <= 0.9 then
		return 0.6
	elseif r <= 1.05 then
		return 0.18
	elseif r <= 1.25 then
		return 0.05
	end
	-- the simulated buyers stop at about 1.25x the market price (audit economy.1): above that only a real player buys
	return 0
end

return Flea

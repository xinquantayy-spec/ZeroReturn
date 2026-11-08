--!nonstrict
-- The flea market's rules (Tarkov, docs/design/EFT_PARITY.md sections 3 and 10), shared by the server's market
-- (Flea.luau, FleaStore.luau), the client's BROWSE (the level gates), ADD OFFER (the fee preview) and MY OFFERS windows
-- and the tests. Since decision economy-3a the market is real: other players' offers from every server, held in escrow,
-- with an AI floor (operators' offers only where players offer too little, AI buyers only for the cheapest fair offer).
-- EFT's figures come from the game's own settings (globals.json "RagFair", EFT 0.16.9.40743 as dumped by the SPT
-- project), the EFT wiki's "Flea market" page (read 2026-11-08), the game's English text (locale en.json) and patch
-- notes up to 1.1.0, each cited where it is used.
local Items = require(script.Parent.Items)
local Weapons = require(script.Parent.Weapons)

local Flea = {}
Flea.LEVEL = 15 -- globals RagFair.minUserLevel 15 (EFT wiki: "PMC level 15 to create offers")
Flea.WINDOW = 900 -- seconds per AI floor refresh (ours: the operators' offers change every 15 minutes)
Flea.DURATION = 12 * 3600 -- an offer's life: globals RagFair.offerDurationTimeInHour 12
-- REMOVE does not pull an offer at once: it ends 0.02 h (72 s) later and can still be bought until then (globals
-- RagFair.offerDurationTimeInHourAfterRemove 0.02; SPT's server uses 71 s for the same rule)
Flea.REMOVE_DELAY = 72
-- returned items (an offer that expired or was removed) wait 72 h if the stash has no room for them (globals
-- RagFair.yourOfferDidNotSellMaxStorageTimeInHour 72: EFT keeps them on Ragman's message that long)
Flea.RETURN_HOLD = 72 * 3600
Flea.RATING_START = 0.2 -- EFT wiki: "Starting reputation: 0.20"
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
	-- the top armour-piercing round of each calibre; 5.4x39 BS (EFT's 5.45 BS) and 9x18 PBM (EFT's 9x18 PBM) since
	-- economy-1a's third slice (the coordinator's request of 18:05). EFT's wiki round pages say rounds "cannot be listed"
	-- and item trackers mark many as banned, yet EFT 1.0 gates M80 at level 35 and PS12B at 40, and 1.0.4.0 (28 Mar 2026)
	-- "Removed the ability to list incomplete ammo stacks on the Flea Market" (timesaver.gg): rounds are still traded,
	-- in full stacks (Flea.FULL_STACK), and only the top piercers are banned here.
	A62_AP = true, A76_BP = true, A76L_SNB = true, A9_AP = true, A54_BS = true, A918_PBM = true,
	-- 7.6x51 (economy-1a's fifth slice): EFT keeps M62, M80A1, M61 and M993 off its flea market (tarkovforge.com, the
	-- coordinator's request of 18:06)
	A76N_TR = true, A76N_EP = true, A76N_AP = true, A76N_TC = true,
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
-- EFT's M80 at 35: A76N_BALL is EFT's 7.62x51 M80 since economy-1a's fifth slice; the full-power 7.6x54R LPS stood in
-- for it before (pen 41 against our 42) and keeps its gate while EconomyTests pins it
Flea.ITEM_LEVEL = { A76N_BALL = 35, A76L_LPS = 35 }

-- EFT's listing limits: some items may be on the market only a few at a time per player ("This item ({0}) has a
-- listing limit! Maximum: {1}, in one pack: {2}", locale ragfair/restrictionLimits; globals RagFair.ItemRestrictions:
-- LEDX, graphics card, intelligence folder, moonshine, military power filter, ophthalmoscope, pipe grip wrench, ratchet
-- wrench, GreenBat lithium battery, military circuit board and 6-STEN-140-M battery 5 each). Ours, item for item:
Flea.LIST_LIMIT = {
	LEDX = 5, GPU_CARD = 5, INTEL_FOLDER = 5, MOONSHINE = 5, POWER_FILTER = 5, OPHTHALMOSCOPE = 5,
	PIPE_WRENCH = 5, RATCHET = 5, LI_BATTERY = 5, MIL_CIRCUIT = 5, BATTERY = 5,
}
-- EFT 1.0.4.0 (28 March 2026): "Removed the ability to list incomplete ammo stacks on the Flea Market" (timesaver.gg)
Flea.FULL_STACK = { ammo = true }

-- Tarkov's listing fee: VO x Ti x 4^PO x Q + VR x Tr x 4^PR x Q (EFT wiki, Flea market). Ti = Tr = 5 % since 1.1.0
-- ("Increased Flea Market fee from 3% to 5%", patch 1.1.0, 3 Aug 2026, patched.gg; 3 % before: globals
-- RagFair.communityItemTax / communityRequirementTax). VO and VR are the whole offer's base value and asking price; with
-- one stack per offer the per-item form (Q = count) and the pack form (Q = 1) give the same fee, so `asked` is the total.
Flea.TI, Flea.TR = 0.05, 0.05
function Flea.fee(baseValue, count, asked)
	local VO, VR = math.max(1, baseValue * count), math.max(1, asked)
	local PO, PR = math.log10(VO / VR), math.log10(VR / VO)
	if VR < VO then
		PO = (PO > 0) and PO ^ 1.08 or PO
	else
		PR = (PR > 0) and PR ^ 1.08 or PR
	end
	return math.ceil(VO * Flea.TI * 4 ^ PO + VR * Flea.TR * 4 ^ PR)
end

-- offer slots by flea rating (the EFT wiki's table: 1 below 0.20, 2 to 6.99, 3 to 29.99, 4 to 59.99, 5 to 99.99,
-- 6 to 149.99, 8 to 999.99, 10 from 1000; the 0.16.9 game settings carry a larger table, see the parity notes)
function Flea.slots(rating)
	local r = rating or Flea.RATING_START
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

-- the rating a sale earns and an unsold offer costs (globals RagFair: ratingIncreaseCount 0.02 per ratingSumForIncrease
-- 100,000 sold, counted up to maxSumForIncreaseRatingPerOneSale 50,000,000 a sale = the wiki's +0.01 per 50,000;
-- ratingDecreaseCount 0.03 per ratingSumForDecrease 100,000 of an offer that expires or is removed unsold, up to
-- maxSumForDecreaseRatingPerOneSale 30,000,000). The wiki confirms a loss for unsold and removed offers without a figure.
function Flea.ratingGain(value)
	return 0.02 * math.min(math.max(0, value), 50000000) / 100000
end
function Flea.ratingLoss(value)
	return 0.03 * math.min(math.max(0, value), 30000000) / 100000
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

-- can this stack go on the market as one offer (EFT 1.0.4.0: rounds only in full stacks): true, or false and why
function Flea.listable(id, n)
	local d = Items.defs[id]
	if not d or not Flea.tradeable(id) then
		return false, "BANNED"
	end
	if Flea.FULL_STACK[d.kind] and d.stack > 1 and (n or 1) < d.stack then
		return false, "FULL_STACK"
	end
	return true
end

-- the market price an item settles around (the handbook value with a flea premium): the AVG the client shows, the AI
-- floor's centre and the most an AI buyer pays
function Flea.marketPrice(id)
	local d = Items.defs[id]
	return math.floor((d and d.value or 0) * 1.15)
end

-- ── the AI floor: operators' offers ─────────────────────────────────────────────────────────────────────────────────
-- Roblox servers hold 12 players, so at quiet times the market would look empty: operators (AI sellers) offer each
-- item, the same offers on every server for a 15-minute window, and step aside as players list the item.
local SELLERS = { "Grit", "Halyard", "Moss", "Kestrel", "Ostrog", "Tallow", "Vesper", "Wren", "Sable", "Juniper", "Flint", "Marrow", "Pike", "Cinder", "Tamarack" }
Flea.SELLERS = SELLERS
-- the operators' offers on an item in a window: { i, seller, price, stock } (the same on every server), cheapest first
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

-- the operators' offers shown beside `players` player offers of the same item: only where players offer too few (the
-- floor is as many offers as the operators would make), the cheapest operators stepping aside first so that they do
-- not undercut the players
function Flea.aiFloor(id, window, players)
	local all = Flea.offersFor(id, window)
	local keep = math.max(0, #all - math.max(0, players or 0))
	local out = {}
	for k = #all - keep + 1, #all do
		table.insert(out, all[k])
	end
	return out
end

-- an operator's flea rating (EFT shows every seller's rating beside the name): fixed per name
function Flea.aiRating(name)
	local h = 7
	for c in string.gmatch(name or "", ".") do
		h = (h * 33 + string.byte(c)) % 100003
	end
	return 20 + (h % 9000) / 10 -- 20.0 to 919.9
end

-- ── AI buyers ─────────────────────────────────────────────────────────────────────────────────────────────────────
-- EFT's buyers are players, who take the cheapest offer. Ours add operators who buy players' offers, but only the
-- cheapest offer of an item and only at or below the going rate: `ref` is the lower of the market price and the
-- cheapest other offer (operators' or players'). Above it they never buy (decision economy-3a; the old simulation kept
-- buying up to 1.25x, audit economy.1). The chance an offer sells in a minute (ours): 50 % at 0.8x or less, 25 % to
-- 0.9x, 8 % to 1.0x.
function Flea.aiBuyRate(unitPrice, ref)
	local r = unitPrice / math.max(1, ref)
	if r > 1 then
		return 0
	elseif r <= 0.8 then
		return 0.5
	elseif r <= 0.9 then
		return 0.25
	end
	return 0.08
end

function Flea.aiRef(id, cheapestOther)
	return math.min(Flea.marketPrice(id), cheapestOther or math.huge)
end

-- ── the market index entry (one MemoryStore sorted-map entry per item; FleaStore.luau) ───────────────────────────
-- One compact string per item: "1|<AI window>|<i>:<bought>,...|<offer>;<offer>;..." where an offer is
-- "<offer id>,<price>,<units left>,<ends>,<rating x100>,<seller name>,<pack 0/1>". Offer ids are "<seller user id>-<n>",
-- names are Roblox user names (letters, digits, underscore). At most MAX_PER_ITEM offers an item (ours: Roblox's
-- 32 KB value limit and the memory quota, FleaStore's budget note).
Flea.MAX_PER_ITEM = 40
Flea.ENTRY_LIMIT = 32 * 1024
local function clean(s, n)
	return string.sub(string.gsub(tostring(s or ""), "[^%w_]", ""), 1, n)
end
Flea.cleanName = function(s)
	return clean(s, 20)
end

function Flea.encodeEntry(e)
	local ai = {}
	for i, k in e.a or {} do
		if type(i) == "number" and type(k) == "number" and k > 0 then
			table.insert(ai, string.format("%d:%d", i, k))
		end
	end
	table.sort(ai)
	local offers = {}
	for _, o in e.o or {} do
		table.insert(offers, string.format("%s,%d,%d,%d,%d,%s,%d", string.sub(string.gsub(tostring(o.o or ""), "[^%d%-]", ""), 1, 24), math.floor(o.p), math.floor(o.n), math.floor(o.e), math.floor((o.r or 0) * 100), clean(o.nm, 20), o.pk and 1 or 0))
	end
	return string.format("1|%d|%s|%s", math.floor(e.w or 0), table.concat(ai, ","), table.concat(offers, ";"))
end

function Flea.decodeEntry(s)
	local out = { w = 0, a = {}, o = {} }
	if type(s) ~= "string" then
		return out
	end
	local v, w, ai, offers = string.match(s, "^(%d+)|(%d*)|([%d:,]*)|(.*)$")
	if v ~= "1" then
		return out
	end
	out.w = tonumber(w) or 0
	for i, k in string.gmatch(ai, "(%d+):(%d+)") do
		out.a[tonumber(i)] = tonumber(k)
	end
	for part in string.gmatch(offers, "[^;]+") do
		local o, p, n, e, r, nm, pk = string.match(part, "^([%w_%-]+),(%d+),(%d+),(%d+),(%-?%d+),([%w_]*),([01])$")
		if o then
			table.insert(out.o, { o = o, p = tonumber(p), n = tonumber(n), e = tonumber(e), r = tonumber(r) / 100, nm = nm, pk = pk == "1" })
		end
	end
	return out
end

-- the seller's user id in an offer id ("<user id>-<n>"), or nil for a malformed id
function Flea.sellerOf(oid)
	if type(oid) ~= "string" or #oid > 24 then
		return nil
	end
	local uid = string.match(oid, "^(%d+)%-%d+$")
	return uid and tonumber(uid) or nil
end

-- the unit price buyers compare (a pack's price spread over its units)
function Flea.unitOf(o)
	return o.pk and (o.p / math.max(1, o.n)) or o.p
end

return Flea

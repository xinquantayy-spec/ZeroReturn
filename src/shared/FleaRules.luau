--!nonstrict
-- The flea market's rules (Tarkov, docs/design/EFT_PARITY.md section 3), shared by the server's market and the
-- client's ADD OFFER window (the fee preview) and the logic tests.
local Items = require(script.Parent.Items)

local Flea = {}
Flea.LEVEL = 15
Flea.WINDOW = 900 -- seconds per market refresh
Flea.DURATION = 12 * 3600 -- an offer's life
Flea.BANNED = { secure = true, quest = true }

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
	return d ~= nil and not Flea.BANNED[d.kind] and (d.value or 0) > 0
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

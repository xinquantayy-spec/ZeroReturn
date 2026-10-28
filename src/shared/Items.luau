--!strict
-- Item definitions (read-only). Instances/ownership are server truth; see server Services/Inv.
export type ItemDef = {
	id: string,
	name: string,
	short: string,
	kind: string, -- weapon | mag | ammo | heal | bag | loot
	w: number,
	h: number,
	mass: number,
	stack: number,
	value: number,
	rarity: string,
	desc: string,
	color: Color3,
	heal: number?,
	capacity: number?,
	bagW: number?,
	bagH: number?,
	weapon: string?,
	ammo: string?,
}

local function c(hex: string): Color3
	return Color3.fromHex(hex)
end

local defs: { [string]: any } = {
	R17_RIFLE = { name = "R-17 Carbine", short = "R-17", kind = "weapon", w = 4, h = 2, mass = 3.2, stack = 1, value = 240, rarity = "common", desc = "Fictional 6.2mm service carbine. Dependable, stiff recoil.", color = c("#55605A"), weapon = "R17" },
	R17_MAG = { name = "R-17 Magazine", short = "MAG", kind = "mag", w = 1, h = 2, mass = 0.4, stack = 1, value = 24, rarity = "common", desc = "25-round steel box magazine.", color = c("#3E4440"), capacity = 25, ammo = "UC62" },
	UC62 = { name = "UC-6.2 Cartridges", short = "6.2", kind = "ammo", w = 1, h = 1, mass = 0.012, stack = 60, value = 1, rarity = "common", desc = "Universal 6.2mm cartridges. Loads R-17 magazines.", color = c("#A08A5C") },
	BANDAGE = { name = "Field Dressing", short = "DRESS", kind = "heal", w = 1, h = 1, mass = 0.1, stack = 1, value = 18, rarity = "common", desc = "Restores 25 health over 2.5 seconds. Interrupted by damage.", color = c("#C9CDBE"), heal = 25 },
	CANVAS_BAG = { name = "Canvas Pack", short = "PACK", kind = "bag", w = 2, h = 2, mass = 0.9, stack = 1, value = 60, rarity = "common", desc = "Worn canvas backpack with a 4x4 compartment.", color = c("#6B6A4E"), bagW = 4, bagH = 4 },
	SIGNAL_COIL = { name = "Signal Coil", short = "COIL", kind = "loot", w = 1, h = 1, mass = 0.5, stack = 1, value = 38, rarity = "common", desc = "Copper induction coil pulled from a harbor relay.", color = c("#9C6B42") },
	CERAMIC_FUSE = { name = "Ceramic Fuse", short = "FUSE", kind = "loot", w = 1, h = 1, mass = 0.2, stack = 1, value = 28, rarity = "common", desc = "High-voltage ceramic fuse. Dock cranes still need them.", color = c("#B9B3A2") },
	CRACKED_LENS = { name = "Cracked Lens", short = "LENS", kind = "loot", w = 1, h = 1, mass = 0.4, stack = 1, value = 52, rarity = "uncommon", desc = "Coated optical lens. Chipped, still valuable.", color = c("#6F8A8C") },
	DECK_TRANSCEIVER = { name = "Deck Transceiver", short = "XCVR", kind = "loot", w = 2, h = 2, mass = 1.8, stack = 1, value = 150, rarity = "uncommon", desc = "Ship-to-shore radio set. Heavy but in demand.", color = c("#4B5652") },
	RUSTED_KEYCARD = { name = "Rusted Keycard", short = "KEY", kind = "loot", w = 1, h = 1, mass = 0.1, stack = 1, value = 90, rarity = "uncommon", desc = "Quay authority keycard. The stripe still reads.", color = c("#8A6252") },
	SEALED_DRIVE = { name = "Sealed Drive", short = "DRIVE", kind = "loot", w = 1, h = 1, mass = 0.1, stack = 1, value = 120, rarity = "rare", desc = "Evacuation office data drive in a sealed sleeve.", color = c("#C07946") },
}

for id, d in defs do
	d.id = id
end

local Items = { defs = defs }

function Items.get(id: string): any
	return defs[id]
end

function Items.valueOf(it: any): number
	local d = defs[it.id]
	if not d then
		return 0
	end
	local v = d.value * (it.n or 1)
	if it.a then
		v += it.a * defs.UC62.value
	end
	if it.rk then
		v = 0
	end
	return v
end

return Items

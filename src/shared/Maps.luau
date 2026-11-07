--!strict
-- M13 map registry shared by server and client: names, raid length and the deploy-screen blurb for each map.
-- The geometry lives in the server's World (Quay 7) and src/server/Maps/* (one module per map).
export type MapDef = {
	id: string,
	name: string,
	kind: string,
	raidTime: number,
	desc: string,
}

local Maps = {}

Maps.order = { "quay7", "smelter", "meridian", "border" }

Maps.defs = {
	quay7 = {
		id = "quay7",
		name = "QUAY 7",
		kind = "INDUSTRIAL PORT",
		raidTime = 1500,
		desc = "Container stacks, a pump annex, the freight depot and a crew dormitory on a cold harbour. Long sight lines; the Foreman holds the depot in some raids.",
	},
	smelter = {
		id = "smelter",
		name = "SMELTER",
		kind = "FACTORY",
		raidTime = 1200, -- Tarkov's Factory: 20 minutes (audit gameplay.15)
		desc = "Blast furnaces, catwalks, a casting shed, offices and service tunnels under the yard. Short raids, close fights.",
	},
	meridian = {
		id = "meridian",
		name = "MERIDIAN MALL",
		kind = "SHOPPING MALL",
		raidTime = 2400,
		desc = "A three-level mall at full scale: a garage under three anchor stores, the L1 and L2 galleries around the atria, a food court, loading docks, and a service tunnel below. Outside it: the substation, the west camp, the rescue camp and checkpoint, and mined and sniper-covered edges. Long raids. Throw the switch at the substation to power the mall and the hidden shelter exit; the Caretaker walks the mall in some raids.",
	},
	border = {
		id = "border",
		name = "BORDER YARD",
		kind = "CUSTOMS ZONE",
		raidTime = 2400,
		desc = "A customs zone on a river crossing at full scale: two dormitory blocks, a fuel stop and a tank farm, the derrick and the frame, big warehouses, the red stores and a trailer lot in the trees, bunkers under the yards, the main bridge and the rail lines. Long raids; the Broker keeps the dorms in some raids.",
	},
} :: { [string]: MapDef }

-- maps taken out of the rotation for now (their modules stay in src/server/Maps and are not built); moving an
-- entry back into Maps.defs and Maps.order, and its module back into World.build, brings the map back
Maps.parked = {
	pinewatch = {
		id = "pinewatch",
		name = "PINEWATCH",
		kind = "FOREST",
		raidTime = 1800,
		desc = "Pine woods on rolling hills: a sawmill, a lake with a boathouse, an ambushed convoy, a ranger lookout and an old shelter under the ridge. Big and open; the Sawyer works the mill in some raids.",
	},
} :: { [string]: MapDef }

function Maps.valid(id: any): boolean
	return type(id) == "string" and Maps.defs[id] ~= nil
end

function Maps.nameOf(id: string?): string
	local d = id and Maps.defs[id]
	return d and d.name or "QUAY 7"
end

-- the map with the most votes; a tie (or no votes) is settled by `pick` (a random index 1..n)
function Maps.winner(votes: { [string]: number }, pick: (number) -> number): string
	local best, list = -1, {}
	for _, id in Maps.order do
		local n = votes[id] or 0
		if n > best then
			best, list = n, { id }
		elseif n == best then
			table.insert(list, id)
		end
	end
	return list[pick(#list)]
end

return Maps

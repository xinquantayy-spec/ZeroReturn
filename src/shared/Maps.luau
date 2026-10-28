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

Maps.order = { "quay7", "smelter" }

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
		raidTime = 900,
		desc = "Blast furnaces, catwalks, a casting shed, offices and service tunnels under the yard. Short raids, close fights.",
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

--!nonstrict
-- Tunnel portals where a railway leaves a map. Past the limit the hills rise, so a line's rails used to stop in the
-- slope. Of the rail run ends the map's rail step passes in, those where the hill rises 10 studs or more within 14
-- studs beyond get a concrete head wall with shut steel gates that takes the line in (a line that goes on, or ends at a
-- river bank, has level or falling ground there). Exits within 40 studs that point the same way share one portal (a
-- double line), and every rail end within 30 studs of it sets the width of the opening (the other track of a pair may
-- stop a little short of the limit).
--   exits     { { x, z, ux, uz } }: map-local run ends and the unit way out
--   ends      { { x, z } }: every rail run end of the map
--   groundAt  (x, z) -> world height of the ground
--   V         (x, y, z) -> world point of a map-local one
--   atEdge    optional (e) -> true where the map's own edge stands right past the end (Border's boundary is rock
--             parts that the height grid does not hold); the hill test still counts
-- Returns the number of portals built.
return function(kit, parent, exits, ends, groundAt, V, atEdge)
	local hex, M = kit.hex, kit.M
	local CON, GATE, BRACE = hex("8A877F"), hex("4C544B"), hex("3A3F38")
	local made = 0
	local used = {}
	for i, a in exits do
		if not used[i] and (groundAt(a.x + a.ux * 14, a.z + a.uz * 14) - groundAt(a.x, a.z) >= 10 or (atEdge and atEdge(a))) then
			used[i] = true
			local ux, uz = a.ux, a.uz
			for j = i + 1, #exits do
				local b = exits[j]
				if not used[j] and (b.x - a.x) ^ 2 + (b.z - a.z) ^ 2 < 1600 and b.ux * a.ux + b.uz * a.uz > 0.8 then
					used[j] = true
					ux, uz = ux + b.ux, uz + b.uz
				end
			end
			local ul = math.sqrt(ux * ux + uz * uz)
			ux, uz = ux / ul, uz / ul
			-- across the line: the outermost rail ends near the mouth; along it: the farthest one in
			local lo, hi, far = 0, 0, 0
			for _, q in ends do
				local dx, dz = q.x - a.x, q.z - a.z
				if dx * dx + dz * dz < 900 then
					local across = dx * uz - dz * ux
					lo, hi = math.min(lo, across), math.max(hi, across)
					far = math.max(far, dx * ux + dz * uz)
				end
			end
			local mid = (lo + hi) / 2
			local cx, cz = a.x + uz * mid + ux * far, a.z - ux * mid + uz * far
			local OW, OH, T = (hi - lo) + 18, 22, 5
			local WW, WH = OW + 24, 36
			local g = groundAt(cx, cz)
			-- the front face 1.5 studs past the rail ends; local -Z points into the hill
			local base = CFrame.lookAt(V(cx, g, cz), V(cx + ux, g, cz + uz)) * CFrame.new(0, 0, -1.5)
			local pm = kit.model("TunnelPortal", parent)
			local function blk(sx, sy, sz, x, y, z, col, mat)
				return kit.boxCF(pm, sx, sy, sz, base * CFrame.new(x, y, z), col, mat)
			end
			-- piers (3 studs into the ground: the foot of the slope is uneven), the lintel and its coping
			for _, sg in { -1, 1 } do
				blk(12, WH + 3, T, sg * (OW / 2 + 6), (WH + 3) / 2 - 3, -T / 2, CON, M.Concrete)
			end
			blk(OW, WH - OH, T, 0, OH + (WH - OH) / 2, -T / 2, CON, M.Concrete)
			blk(WW + 1.2, 1.2, T + 1.2, 0, WH + 0.6, -T / 2, CON, M.Concrete)
			-- the shut gates: two leaves with braces on their faces
			for _, sg in { -1, 1 } do
				blk(OW / 2 - 0.2, OH, 0.6, sg * (OW / 4 + 0.05), OH / 2, -T / 2, GATE, M.CorrodedMetal)
				for _, y in { 3, OH / 2, OH - 3 } do
					blk(OW / 2 - 1.2, 0.8, 0.5, sg * (OW / 4 + 0.05), y, -T / 2 + 0.55, BRACE, M.Metal)
				end
			end
			made += 1
		end
	end
	return made
end

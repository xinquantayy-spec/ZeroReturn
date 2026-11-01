--!nonstrict
-- Roads into the hills, for the maps' dressing (Border and Meridian). A road that leaves the map used to run straight
-- into the boundary rock. A row of concrete barriers now closes it 6 studs short of the limit, as Tarkov closes its map
-- edges. A row that would reach into an exit zone (its half size plus 3 studs) or come within 9 studs of a spawn is
-- left out, whole: cover keeps clear of play spots (LookTests L03). The rows stand on the road, so the caller places
-- them without the road's own keep-out.
--   ctx.L        the map's layout: L.roads { id, surface, width, { x, z, ... } } and L.ext { id, name, side, x, z, sx, sy, sz }
--   ctx.inside   (x, z) -> true inside the map's limit
--   ctx.place    (kind, x, z, ry, size): put one cover prop there (the caller counts it and keeps later props off it)
--   ctx.spawns   { Vector2 }: the map's spawn points, map-local
--   ctx.rng      a Random
--   ctx.size     the barrier's footprint (the wear kit's BarrierBroken)
-- RoadEnds.new(ctx) returns { row = function(cx, cz, ox, oz, w, stagger) -> placed, clear = function(x, z, r) -> bool,
-- edges = function() -> rows placed at the limit }.
local RoadEnds = {}

function RoadEnds.new(ctx)
	local L, inside, rng, size = ctx.L, ctx.inside, ctx.rng, ctx.size
	local self = {}

	function self.clear(x, z, rad)
		for _, e in L.ext do
			if (Vector2.new(e[4], e[5]) - Vector2.new(x, z)).Magnitude < rad + math.max(e[6], e[8]) / 2 + 3 then
				return false
			end
		end
		for _, p in ctx.spawns do
			if (p - Vector2.new(x, z)).Magnitude < rad + 9 then
				return false
			end
		end
		return true
	end

	-- a row of barriers across a road (cx, cz) of width w whose way out is (ox, oz); every other one is set `stagger`
	-- studs along the road. The whole row or nothing.
	function self.row(cx, cz, ox, oz, w, stagger)
		local k = math.max(1, math.ceil((w + 2) / (size.X - 0.4)))
		local ry = math.deg(math.atan2(-ox, -oz))
		local spots = {}
		for i = 1, k do
			local s = (i - (k + 1) / 2) * (size.X - 0.4)
			local off = ((i % 2 == 0) and stagger or 0) + rng:NextNumber(-0.3, 0.3)
			local x, z = cx - oz * s + ox * off, cz + ox * s + oz * off
			if not self.clear(x, z, size.X / 2) then
				return false
			end
			table.insert(spots, { x, z })
		end
		for _, p in spots do
			ctx.place("BarrierBroken", p[1], p[2], ry + rng:NextNumber(-7, 7), size)
		end
		return true
	end

	-- every road's way off the map: where it crosses the limit, a row 6 studs inside
	function self.edges()
		local rows = 0
		for _, rd in L.roads do
			local w, pts = rd[3], rd[4]
			for s = 1, #pts / 2 - 1 do
				local ax, az, bx, bz = pts[2 * s - 1], pts[2 * s], pts[2 * s + 1], pts[2 * s + 2]
				local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
				if len > 1 then
					local ux, uz = (bx - ax) / len, (bz - az) / len
					local steps = math.ceil(len / 2)
					local px, pz, was = ax, az, inside(ax, az)
					for q = 1, steps do
						local x, z = ax + (bx - ax) * q / steps, az + (bz - az) * q / steps
						local now = inside(x, z)
						if was ~= now then
							-- the inside point and the way out from it
							local ix, iz, ox, oz = px, pz, ux, uz
							if now then
								ix, iz, ox, oz = x, z, -ux, -uz
							end
							if self.row(ix - ox * 6, iz - oz * 6, ox, oz, w, 0.8) then
								rows += 1
							end
						end
						px, pz, was = x, z, now
					end
				end
			end
		end
		return rows
	end

	return self
end

return RoadEnds

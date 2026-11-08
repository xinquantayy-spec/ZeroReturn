--!nonstrict
-- A free spot on a floor for a task's quest item, plant or mark (decision economy-6a). A map names a rough point (a
-- room's middle, the foot of a tank); once the map is built, furniture and clutter included, this finds the nearest
-- point within `reach` studs that lies on the same floor, has headroom, touches no wall and stands in no furniture.
-- Kit furniture neither collides nor answers queries, so its boxes are read from the models. World.endMap runs it on
-- every visit zone marked `free`; ZR_Dev "taskSpots" reports where each one ended up.
local SpotFinder = {}

local CLEAR = Vector3.new(1.4, 2.4, 1.4) -- the room an item or a kneeling player needs above the floor
local WALL_GAP = 0.9 -- studs from any wall or solid part

-- the kit props of a map, with their boxes, once per map
function SpotFinder.kitIndex(root)
	local list = {}
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Kit") then
			local ok, cf, size = pcall(m.GetBoundingBox, m)
			if ok then
				table.insert(list, { cf = cf, half = size / 2, p = cf.Position })
			end
		end
	end
	return list
end

local function inKit(index, q, near)
	for _, b in index do
		if (b.p - q).Magnitude < near + b.half.Magnitude then
			local l = b.cf:PointToObjectSpace(q)
			if math.abs(l.X) < b.half.X + 0.5 and math.abs(l.Y) < b.half.Y + 0.4 and math.abs(l.Z) < b.half.Z + 0.5 then
				return true
			end
		end
	end
	return false
end

-- is floor point q free: headroom, no wall or solid part close by, no furniture over it
function SpotFinder.clear(root, index, q)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { root }
	op.RespectCanCollide = true
	local box = CFrame.new(q + Vector3.new(0, CLEAR.Y / 2 + 0.15, 0))
	local parts = workspace:GetPartBoundsInBox(box, CLEAR + Vector3.new(WALL_GAP * 2, 0, WALL_GAP * 2), op)
	if #parts > 0 then
		return false
	end
	return not inKit(index, q + Vector3.new(0, 0.8, 0), 4)
end

-- the nearest free floor point to p within `reach` studs, on the floor p stands on (within `dy` studs of p.Y); nil
-- when there is none
function SpotFinder.floor(root, index, p, reach, dy)
	reach, dy = reach or 6, dy or 2.5
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { root, workspace.Terrain }
	rp.IgnoreWater = true
	for ring = 0, reach, 0.75 do
		local n = ring == 0 and 1 or math.max(8, math.floor(ring * 5))
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local x, z = p.X + math.cos(a) * ring, p.Z + math.sin(a) * ring
			local hit = workspace:Raycast(Vector3.new(x, p.Y + 2.4, z), Vector3.new(0, -2.4 - dy, 0), rp)
			if hit and hit.Normal.Y > 0.85 and math.abs(hit.Position.Y - p.Y) <= dy then
				if SpotFinder.clear(root, index, hit.Position) then
					return hit.Position + Vector3.new(0, 0.05, 0)
				end
			end
		end
	end
	return nil
end

return SpotFinder

--!strict
-- Pure inventory-grid geometry. placements: { [guid] = {x, y, r} }, 1-based cells, r = 0|1 (rotated 90deg).
local Grid = {}

function Grid.dims(w: number, h: number, r: number?): (number, number)
	if r == 1 then
		return h, w
	end
	return w, h
end

function Grid.isInt(n: any): boolean
	return type(n) == "number" and n == n and n % 1 == 0 and n > -100000 and n < 100000
end

local function overlaps(ax: number, ay: number, aw: number, ah: number, bx: number, by: number, bw: number, bh: number): boolean
	return not (ax + aw - 1 < bx or bx + bw - 1 < ax or ay + ah - 1 < by or by + bh - 1 < ay)
end

-- sizeOf(guid) -> (w, h) unrotated
function Grid.fits(cw: number, ch: number, placements: { [string]: any }, sizeOf: (string) -> (number, number), x: number, y: number, w: number, h: number, ignore: string?): boolean
	if x < 1 or y < 1 or x + w - 1 > cw or y + h - 1 > ch then
		return false
	end
	for g, p in placements do
		if g ~= ignore then
			local sw, sh = sizeOf(g)
			local pw, ph = Grid.dims(sw, sh, p.r)
			if overlaps(x, y, w, h, p.x, p.y, pw, ph) then
				return false
			end
		end
	end
	return true
end

function Grid.findFree(cw: number, ch: number, placements: { [string]: any }, sizeOf: (string) -> (number, number), w: number, h: number): (number?, number?, number?)
	for r = 0, 1 do
		if r == 1 and w == h then
			break
		end
		local rw, rh = Grid.dims(w, h, r)
		for y = 1, ch - rh + 1 do
			for x = 1, cw - rw + 1 do
				if Grid.fits(cw, ch, placements, sizeOf, x, y, rw, rh) then
					return x, y, r
				end
			end
		end
	end
	return nil, nil, nil
end

-- guid occupying cell (x, y), if any
function Grid.at(placements: { [string]: any }, sizeOf: (string) -> (number, number), x: number, y: number): string?
	for g, p in placements do
		local sw, sh = sizeOf(g)
		local pw, ph = Grid.dims(sw, sh, p.r)
		if x >= p.x and x <= p.x + pw - 1 and y >= p.y and y <= p.y + ph - 1 then
			return g
		end
	end
	return nil
end

return Grid

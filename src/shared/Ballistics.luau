--!nonstrict
-- Projectile ballistics (Tarkov: bullets fly with drop and travel time; sights are zeroed with Page Up / Page Down).
-- A bullet leaves the muzzle at the weapon's muzzle velocity (m/s, scaled by its barrel), loses speed to drag
-- (exponential, by weapon class) and falls with gravity. The server flies every bullet in real time, a raycast per
-- frame along its path, so a moving target has to be led at range; the shot's effects use an instant trace of the
-- same arc. Zeroing tilts the bore up so the arc crosses the line of sight at the zero distance.
local RunService = game:GetService("RunService")

local B = {}
B.STUDS_PER_M = 3.125 -- Range.luau / the INSPECT window
B.G = 9.81 * B.STUDS_PER_M -- studs/s^2 (real gravity, not Roblox's character gravity)
B.DRAG = { rifle = 0.8, bolt = 0.6, smg = 0.5, pistol = 0.45, shotgun = 2.4 } -- 1/s
B.ZEROS = { 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1000 } -- metres (Tarkov's steps)
B.DEFAULT_ZERO = 100
B.STEP = 1 / 60
B.MAX_TIME = 3

-- Glass (server/Services/Glass.luau, docs/design/GLASS.md). A pane of glass has an invisible hit shell that only rays cast in the
-- collision group B.shotGroup can touch, so the AI's sight and every other ray pass the pane as they always did. When a bullet's
-- ray meets a shell, B.through(res, dir, real) (set by the Glass service) answers: nil = not glass, the bullet stops as before;
-- otherwise keep, exit = the share of its damage the bullet keeps and how far along dir the far side of the pane lies. A real
-- bullet (real = true) breaks the pane; the effects trace leaves it whole. Either way the bullet goes on from just past the pane
-- on the same line, undeflected. Both stay nil until the Glass service has registered its groups: then nothing changes.
B.through = nil
B.shotGroup = nil
B.MAX_PANES = 6 -- panes one bullet can pass in one step (the next one stops it)

-- each calibre's reference round: a gun's velocity figure is for this load, and other loads scale it by their own
-- speed (EFT: a round's initial speed, changed by the barrel; economy-1a). M855, PS, Pst gzh, 7 mm buckshot, LPS gzh,
-- and since the third slice 5.45 PS gs and 9x18 P gzh
B.CAL_REF = { ["6.2"] = 922, ["7.6"] = 717, ["9"] = 457, ["12"] = 415, ["7.6L"] = 865, ["5.4"] = 890, ["9.18"] = 302, ["7.6N"] = 820, ["9.39"] = 290, ["4.6"] = 620, ["5.7"] = 715 }

-- muzzle velocity in studs/s for a weapon def, its build's velocity multiplier and (optional) the round's item def
function B.muzzle(wdef, velMul, ammoDef)
	local k = 1
	local ref = ammoDef and B.CAL_REF[ammoDef.caliber or ""]
	local sp = ammoDef and ammoDef.ammo and ammoDef.ammo.speed
	if ref and sp then
		k = sp / ref
	end
	return (wdef.velocity or 700) * (velMul or 1) * k * B.STUDS_PER_M
end

function B.drag(wdef)
	return B.DRAG[wdef.class] or 0.6
end

-- time to cover a horizontal distance d (studs) at muzzle speed v0 with drag k (nil when it never gets there)
function B.timeTo(d, v0, k)
	local f = 1 - k * d / v0
	if f <= 0.02 then
		return nil
	end
	return -math.log(f) / k
end

-- how far below the bore line the bullet is after d studs
function B.dropAt(d, v0, k)
	local t = B.timeTo(d, v0, k) or B.MAX_TIME
	return 0.5 * B.G * t * t
end

-- the bore's upward tilt (radians) that puts the arc on the line of sight at the zero distance (metres)
function B.zeroAngle(zeroM, v0, k)
	local d = (zeroM or B.DEFAULT_ZERO) * B.STUDS_PER_M
	return math.atan2(B.dropAt(d, v0, k), d)
end

-- dir tilted up by angle a (about the horizontal axis across it)
function B.tilt(dir, a)
	if a == 0 then
		return dir
	end
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-4 then
		return dir
	end
	return (CFrame.fromAxisAngle(right.Unit, a) * dir).Unit
end

local function stepOnce(b, dt, real)
	local v = b.vel
	local nv = v * math.exp(-b.k * dt) - Vector3.new(0, B.G * dt, 0)
	local delta = (v + nv) * 0.5 * dt
	local left = delta
	local panes = 0
	while true do
		local res = workspace:Raycast(b.pos, left, b.params)
		if not res then
			break
		end
		local keep, far = nil, nil
		local through = B.through
		if through and panes < B.MAX_PANES then
			local ok, k2, f2 = pcall(through, res, left.Unit, real)
			if ok then
				keep, far = k2, f2
			end
		end
		if not keep then
			b.dist += (res.Position - b.pos).Magnitude
			b.pos = res.Position
			return res
		end
		-- a pane: on from just past it, with a little less damage
		panes += 1
		b.keep = (b.keep or 1) * keep
		local beyond = res.Position + left.Unit * (far or 0.1)
		local moved = beyond - b.pos
		b.dist += moved.Magnitude
		b.pos = beyond
		left -= moved
		if left:Dot(delta) <= 0 then
			left = Vector3.zero -- the step ended inside the pane
			break
		end
	end
	b.pos += left
	b.dist += left.Magnitude
	b.vel = nv
	b.t += dt
	return nil
end

-- the whole arc at once (effects, the AI's near-miss check): result or nil, end position, distance, speed fraction
function B.trace(origin, dir, v0, k, maxDist, params)
	local b = { pos = origin, vel = dir * v0, k = k, params = B.shotParams(params), dist = 0, t = 0 }
	while b.dist < maxDist and b.t < B.MAX_TIME do
		local res = stepOnce(b, B.STEP, false)
		if res then
			return res, b.pos, b.dist, b.vel.Magnitude / v0
		end
	end
	return nil, b.pos, b.dist, b.vel.Magnitude / v0
end

-- a private copy of a raycast filter (the shared ones are rewritten for every shot)
function B.copyParams(src)
	local p = RaycastParams.new()
	p.FilterType = src.FilterType
	p.FilterDescendantsInstances = src.FilterDescendantsInstances
	p.IgnoreWater = src.IgnoreWater
	p.RespectCanCollide = src.RespectCanCollide
	p.CollisionGroup = src.CollisionGroup
	return p
end

-- the filter a bullet or a blow is cast with: a private copy of src, in the group that sees the panes' hit shells (once the Glass
-- service has made the groups; before that, src's own group)
function B.shotParams(src)
	local p = B.copyParams(src)
	if B.shotGroup then
		p.CollisionGroup = B.shotGroup
	end
	return p
end

-- real-time flight (server): onHit(result, position, distance, speed fraction, damage kept) on the first hit (the last number is
-- below 1 after panes of glass), onEnd(position) when it falls out of range or time
local live = {}
local conn
function B.fly(origin, dir, v0, k, maxDist, params, onHit, onEnd)
	table.insert(live, { pos = origin, vel = dir * v0, v0 = v0, k = k, params = B.shotParams(params), dist = 0, t = 0, maxDist = maxDist, onHit = onHit, onEnd = onEnd })
	if conn then
		return
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		for i = #live, 1, -1 do
			local b = live[i]
			local res = stepOnce(b, dt, true)
			if res then
				table.remove(live, i)
				local ok, err = pcall(b.onHit, res, b.pos, b.dist, b.vel.Magnitude / b.v0, b.keep or 1)
				if not ok then
					warn("[ZR] bullet hit:", err)
				end
			elseif b.dist >= b.maxDist or b.t >= B.MAX_TIME then
				table.remove(live, i)
				if b.onEnd then
					pcall(b.onEnd, b.pos)
				end
			end
		end
		if #live == 0 then
			conn:Disconnect()
			conn = nil
		end
	end)
end

function B.inFlight()
	return #live
end

return B

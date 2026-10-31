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

-- muzzle velocity in studs/s for a weapon def and its build's velocity multiplier
function B.muzzle(wdef, velMul)
	return (wdef.velocity or 700) * (velMul or 1) * B.STUDS_PER_M
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

local function stepOnce(b, dt)
	local v = b.vel
	local nv = v * math.exp(-b.k * dt) - Vector3.new(0, B.G * dt, 0)
	local delta = (v + nv) * 0.5 * dt
	local res = workspace:Raycast(b.pos, delta, b.params)
	if res then
		b.dist += (res.Position - b.pos).Magnitude
		b.pos = res.Position
		return res
	end
	b.pos += delta
	b.dist += delta.Magnitude
	b.vel = nv
	b.t += dt
	return nil
end

-- the whole arc at once (effects, the AI's near-miss check): result or nil, end position, distance, speed fraction
function B.trace(origin, dir, v0, k, maxDist, params)
	local b = { pos = origin, vel = dir * v0, k = k, params = params, dist = 0, t = 0 }
	while b.dist < maxDist and b.t < B.MAX_TIME do
		local res = stepOnce(b, B.STEP)
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

-- real-time flight (server): onHit(result, position, distance, speed fraction) on the first hit, onEnd(position)
-- when it falls out of range or time
local live = {}
local conn
function B.fly(origin, dir, v0, k, maxDist, params, onHit, onEnd)
	table.insert(live, { pos = origin, vel = dir * v0, v0 = v0, k = k, params = B.copyParams(params), dist = 0, t = 0, maxDist = maxDist, onHit = onHit, onEnd = onEnd })
	if conn then
		return
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		for i = #live, 1, -1 do
			local b = live[i]
			local res = stepOnce(b, dt)
			if res then
				table.remove(live, i)
				local ok, err = pcall(b.onHit, res, b.pos, b.dist, b.vel.Magnitude / b.v0)
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

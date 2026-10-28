--!strict
-- Grenade rules shared by the server (authoritative throws, paths and damage), the client (it draws the path
-- the server sends) and the logic tests. Tarkov rules: G throws the first grenade in your rig or pockets, the
-- fuse starts when it leaves the hand, a short underhand throw exists, frags send fragments that armour can
-- stop, stun charges blind and deafen, smoke screens block sight for everyone (AI included).
local G = {}

G.GRAV = 45 -- studs/s^2: a readable arc at the game's scale (1 m is about 3 studs)
G.RADIUS = 0.16 -- collision radius of the grenade body
G.REST = 0.25 -- restitution of the normal velocity on a bounce
G.MU = 0.6 -- Coulomb friction on a bounce: tangential impulse <= MU * normal impulse
G.TUMBLE = 0.8 -- an irregular body loses more speed tumbling on every bounce
G.ROLL = 1.0 -- sliding / rolling deceleration on the ground, in g
G.STEP = 1 / 60
G.SAMPLE = 0.05 -- path samples sent to clients (linear interpolation is exact to ~0.02 studs at this rate)
G.MAX_SAMPLES = 200
G.PULL_TIME = 0.55 -- client pin-pull animation; the server accepts a throw 0.35 s after the pull message
G.PULL_MIN = 0.35
G.PULL_MAX = 30 -- a pulled pin is forgotten after this long (lost client)
G.COOLDOWN = 0.9
G.THROW = {
	over = { speed = 60, loft = math.rad(9), up = 0.25, side = 0.35, fwd = 0.55 },
	under = { speed = 25, loft = math.rad(4), up = -1.6, side = 0.25, fwd = 0.7 },
}

-- launch velocity for a look direction (unit), throw style and the thrower's velocity (half of it carries over)
function G.launch(look: Vector3, under: boolean, inherit: Vector3?): Vector3
	local spec = under and G.THROW.under or G.THROW.over
	local flat = Vector3.new(look.X, 0, look.Z)
	local yaw = flat.Magnitude > 1e-4 and flat.Unit or Vector3.new(0, 0, -1)
	local pitch = math.atan2(look.Y, math.max(1e-4, flat.Magnitude))
	if under then
		pitch = math.clamp(pitch * 0.5, math.rad(-20), math.rad(35)) -- underhand: a flat lob that rolls on
	end
	pitch = math.clamp(pitch + spec.loft, math.rad(-60), math.rad(80))
	local dir = yaw * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
	local carry = inherit or Vector3.zero
	return dir * spec.speed + Vector3.new(carry.X, math.max(0, carry.Y), carry.Z) * 0.5
end

-- release point for a thrower's eye (or head) CFrame-like basis
function G.releasePoint(eye: Vector3, look: Vector3, under: boolean): Vector3
	local spec = under and G.THROW.under or G.THROW.over
	local flat = Vector3.new(look.X, 0, look.Z)
	local fwd = flat.Magnitude > 1e-4 and flat.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	return eye + fwd * spec.fwd + right * spec.side + Vector3.new(0, spec.up, 0)
end

export type Ray = (Vector3, Vector3) -> (Vector3?, Vector3?)
export type Path = { t: { number }, p: { Vector3 }, b: { number }, final: Vector3, rest: boolean, land: number?, endT: number }

-- Integrate a throw until the fuse runs out or it comes to rest. `rc(origin, direction)` is the caller's world
-- raycast (returns hit position and normal). Air: gravity, bounces with restitution and Coulomb friction.
-- Ground: once a bounce is soft it slides/rolls (slope pull, friction, walls, falls off edges).
function G.simulate(p0: Vector3, v0: Vector3, fuse: number, rc: Ray): Path
	local g = Vector3.new(0, -G.GRAV, 0)
	local R = G.RADIUS
	local p, v, t = p0, v0, 0
	local ts, ps, bounces = { 0 }, { p0 }, {}
	local nextSample = G.SAMPLE
	local land: number? = nil
	local rest = false
	local mode = "air"
	local ground = Vector3.yAxis
	local iter = 0
	local function sample(force: boolean?)
		if (force or t >= nextSample) and #ts < G.MAX_SAMPLES then
			table.insert(ts, t)
			table.insert(ps, p)
			nextSample = t + G.SAMPLE
		end
	end
	while t < fuse and iter < 2000 do
		iter += 1
		local dt = math.min(G.STEP, fuse - t)
		if mode == "air" then
			local np = p + v * dt + g * (0.5 * dt * dt)
			local d = np - p
			local len = d.Magnitude
			local hitPos, n = nil, nil
			if len > 1e-6 then
				hitPos, n = rc(p, d / len * (len + R))
			end
			if hitPos and n then
				local travel = math.max(0, (hitPos - p).Magnitude - R)
				local frac = math.clamp(travel / math.max(len, 1e-6), 0, 1)
				local tc = dt * frac
				local vc = v + g * tc
				local vn = vc:Dot(n)
				t += math.max(tc, 1e-3)
				p = hitPos + n * (R + 0.01)
				if vn < 0 then
					local vT = vc - n * vn
					local jn = -(1 + G.REST) * vn
					local vtm = vT.Magnitude
					local drop = math.min(vtm, G.MU * jn)
					vT = (vtm > 1e-6) and vT * ((vtm - drop) / vtm) or Vector3.zero
					v = vT * G.TUMBLE - n * (vn * G.REST)
				else
					v = vc
				end
				land = land or t
				if -vn > 4 then
					table.insert(bounces, t)
					sample(true)
				end
				if n.Y > 0.6 then
					if math.abs(v:Dot(n)) < 3.5 then
						mode = "ground"
						ground = n
						v -= n * v:Dot(n)
						if v.Magnitude < 0.6 then
							rest = true
							break
						end
					end
				end
			else
				p, v = np, v + g * dt
				t += dt
			end
		else
			-- sliding / rolling on the ground plane
			local gt = g - ground * g:Dot(ground)
			local vt = v - ground * v:Dot(ground)
			local spd = vt.Magnitude
			local fr = G.ROLL * G.GRAV * ground.Y
			if spd < 0.25 and gt.Magnitude <= fr then
				rest = true
				break
			end
			local acc = gt - ((spd > 1e-4) and vt / spd * fr or Vector3.zero)
			local nv = vt + acc * dt
			if spd > 1e-4 and nv:Dot(vt) <= 0 and gt.Magnitude <= fr then
				rest = true
				break
			end
			local np = p + (vt + nv) * (0.5 * dt)
			local d = np - p
			local len = d.Magnitude
			local wPos, wn = nil, nil
			if len > 1e-6 then
				wPos, wn = rc(p, d / len * (len + R))
			end
			if wPos and wn and wn.Y < 0.6 then
				-- rolled into a wall: bounce off it and keep rolling
				local vn = nv:Dot(wn)
				if vn < 0 then
					nv -= wn * ((1 + G.REST) * vn)
					if -vn > 4 then
						table.insert(bounces, t)
					end
				end
				p = wPos + wn * (R + 0.01)
				v = nv
				t += dt
			else
				local gp, gn = rc(np + Vector3.new(0, 0.35, 0), Vector3.new(0, -(0.35 + R + 0.45), 0))
				if gp and gn and gn.Y > 0.6 then
					p = gp + gn * R
					ground = gn
					v = nv
				else
					mode = "air" -- off an edge
					p, v = np, nv
				end
				t += dt
			end
		end
		sample()
		if p.Y < -2000 then
			break
		end
	end
	if ts[#ts] ~= t then
		table.insert(ts, t)
		table.insert(ps, p)
	end
	return { t = ts, p = ps, b = bounces, final = p, rest = rest, land = land, endT = t }
end

-- position on a path at time t (seconds after release)
function G.at(path: any, t: number): Vector3
	local ts, ps = path.t, path.p
	local n = #ts
	if n == 0 then
		return Vector3.zero
	end
	if t <= ts[1] then
		return ps[1]
	end
	if t >= ts[n] then
		return ps[n]
	end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if ts[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a = (t - ts[lo]) / math.max(1e-6, ts[hi] - ts[lo])
	return ps[lo]:Lerp(ps[hi], a)
end

-- launch direction (unit) that lands a throw of `speed` from `from` on `to`; high = lob over cover.
-- nil when out of range. (Ballistic, no bounces: callers verify with simulate.)
function G.aim(from: Vector3, to: Vector3, speed: number, high: boolean): Vector3?
	local d = to - from
	local flat = Vector3.new(d.X, 0, d.Z)
	local x = flat.Magnitude
	if x < 0.5 then
		return nil
	end
	local y = d.Y
	local g = G.GRAV
	local v2 = speed * speed
	local disc = v2 * v2 - g * (g * x * x + 2 * y * v2)
	if disc < 0 then
		return nil
	end
	local root = math.sqrt(disc)
	local tanA = (v2 + (high and root or -root)) / (g * x)
	local a = math.atan(tanA)
	local f = flat / x
	return (f * math.cos(a) + Vector3.new(0, math.sin(a), 0)).Unit
end

-- the grenade a quick throw takes: first in the rig, then the pockets, in reading order (Tarkov: never from the
-- backpack). Works on server holders and on the client's snapshot (same shape). `want` limits the types
-- (e.g. { frag = true, stun = true } for AI flushing someone out of cover). deep: the backpack too (AI).
function G.pick(h: any, defs: any, want: { [string]: boolean }?, deep: boolean?): string?
	local order = {}
	if h.slots and h.slots.rig and h.grids[h.slots.rig] then
		table.insert(order, h.slots.rig)
	end
	table.insert(order, "pockets")
	if deep and h.slots and h.slots.back and h.grids[h.slots.back] then
		table.insert(order, h.slots.back)
	end
	local best, bestKey = nil, math.huge
	for i, cid in order do
		for g, pos in h.grids[cid] or {} do
			local it = h.items[g]
			local d = it and defs[it.id]
			if d and d.kind == "grenade" and (not want or want[d.nade.type]) then
				local key = i * 100000 + (pos.y or 0) * 100 + (pos.x or 0)
				if key < bestKey then
					best, bestKey = g, key
				end
			end
		end
	end
	return best
end

-- ── fragments ────────────────────────────────────────────────────────────────
-- body parts fragments can strike (hands and feet count with their limb)
G.BODY = {
	"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
	"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg",
}

-- mean projected area of a box (Cauchy: surface area / 4)
function G.areaOf(size: Vector3): number
	return (size.X * size.Y + size.Y * size.Z + size.X * size.Z) / 2
end

-- expected fragment strikes on a target of `area` at `dist` from `frags` fragments spread over a sphere
function G.fragLambda(frags: number, area: number, dist: number): number
	local d = math.max(dist, 1.2)
	return frags * area / (4 * math.pi * d * d)
end

function G.poisson(rng: Random, lambda: number): number
	if lambda <= 0 then
		return 0
	end
	if lambda > 30 then
		return math.max(0, math.floor(lambda + math.sqrt(lambda) * (rng:NextNumber() * 2 - 1) * 1.7 + 0.5))
	end
	local L, k, p = math.exp(-lambda), 0, 1
	repeat
		k += 1
		p *= rng:NextNumber()
	until p <= L or k > 60
	return k - 1
end

-- damage and penetration of one fragment that flew `dist` studs (they slow down quickly)
function G.fragHit(spec: any, dist: number, rng: Random): (number, number)
	local f = math.clamp(dist / spec.fragR, 0, 1)
	local dmg = (spec.fragDmg[1] + rng:NextNumber() * (spec.fragDmg[2] - spec.fragDmg[1])) * (1 - 0.5 * f)
	local pen = (spec.fragPen[1] + rng:NextNumber() * (spec.fragPen[2] - spec.fragPen[1])) * (1 - 0.4 * f)
	return dmg, pen
end

-- ── stun and smoke ───────────────────────────────────────────────────────────
-- how badly a flash blinds: distance share and facing (dot of the look direction with the way to the flash)
function G.blind(spec: any, dist: number, facing: number, los: boolean): number
	if not los then
		return (dist < 5) and 0.15 or 0
	end
	local k = math.clamp(1 - dist / spec.blindR, 0, 1)
	local face = (facing > 0.6 and 1) or (facing > 0.2 and 0.7) or (facing > -0.2 and 0.35) or 0.12
	return k * face
end

function G.deaf(spec: any, dist: number, los: boolean): number
	return math.clamp(1 - dist / spec.deafR, 0, 1) * (los and 1 or 0.5)
end

-- smoke cloud radius and density over its life (grows for 4 s, holds, thins out over the last 8 s)
function G.cloud(spec: any, age: number): (number, number)
	if age < 0 or age > spec.smokeT + 8 then
		return 0, 0
	end
	local grow = math.clamp(age / 4, 0, 1)
	local r = spec.smokeR * (0.25 + 0.75 * (1 - (1 - grow) * (1 - grow)))
	local dens = (age > spec.smokeT) and (1 - (age - spec.smokeT) / 8) or math.clamp(age / 1.2, 0, 1)
	return r * (1 + 0.15 * math.clamp((age - 4) / spec.smokeT, 0, 1)), dens
end

-- length of the segment a-b that lies inside the sphere (c, radius)
function G.insideLength(a: Vector3, b: Vector3, c: Vector3, radius: number): number
	local ab = b - a
	local len = ab.Magnitude
	if len < 1e-4 then
		return 0
	end
	local u = ab / len
	local ac = a - c
	local bb = u:Dot(ac)
	local disc = bb * bb - (ac:Dot(ac) - radius * radius)
	if disc <= 0 then
		return 0
	end
	local s = math.sqrt(disc)
	return math.max(0, math.min(-bb + s, len) - math.max(-bb - s, 0))
end

-- does the line of sight a-b cross enough dense smoke to hide someone? (grazing the edge does not;
-- standing inside the cloud you see only a few studs)
function G.segmentInCloud(a: Vector3, b: Vector3, c: Vector3, r: number, dens: number): boolean
	if dens < 0.35 or r <= 0 then
		return false
	end
	return G.insideLength(a, b, c, r * 0.8) * dens > 4
end

return G

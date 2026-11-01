--!nonstrict
-- Stationary (mounted) weapons: the two kinds, their numbers and the aiming maths. Shared by the server (arcs, fire
-- rate, ammo, damage), the client (camera limits, gun pose) and the logic tests. docs/design/STATIONARY_WEAPONS.md
-- Angles are radians relative to the gun's frame: yaw 0 is straight ahead and positive turns left, pitch positive is up.
-- A gun's frame is upright: its position is the ground under the pivot and its heading is where it points at yaw 0.
local S = {}

S.STUDS_PER_M = 3.125
-- tracers, flash and sound are drawn for guns within this many studs of the camera
S.SHOW_RANGE = 450
-- the operator is dismounted when this far from the operator spot (studs)
S.LEASH = 8

-- kinds: rpm and the belt come from Tarkov's NSV Utyos (650 RPM) and AGS-30 (425 RPM); the guns spawn full and
-- cannot be reloaded. dmg/pen are the NSV's B-32 round (182 / 88). Everything else is our own design.
-- pivotH: height of the trunnion above the gun's ground point; eye: the camera relative to the pivot (turns with
-- yaw); op: where the operator stands, relative to the gun's ground point (+z is behind the gun). Crews (AI guards):
-- aiRange/aiMin the distances they will fire at (studs), aiErr extra spread (degrees), burst the rounds in a burst
-- and pause the seconds between bursts. spread/bloom are degrees; velocity m/s; drag 1/s; zero metres (Ballistics.zeroAngle);
-- range, arming and the crews' ranges studs.
S.KINDS = {
	HMG12 = {
		id = "HMG12", name = "HMG-12 'Bastion'", short = "HMG-12", what = "12.7 mm heavy machine gun", sound = "HMG12",
		rpm = 650, belt = 100, dmg = 182, pen = 88, armorDmg = 0.85, bleedL = 0.35, bleedH = 0.2, ammoName = "12.7 mm HMG round",
		velocity = 800, drag = 0.45, range = 1100, zero = 200,
		spread = 0.12, bloomPerShot = 0.014, bloomMax = 0.75, bloomDecay = 0.6, tracerEvery = 4, loud = 2.6,
		arcs = { left = 70, right = 70, up = 40, down = 20 },
		pivotH = 3.6, muzzleLen = 5.8, eye = Vector3.new(0, 1.0, 1.7), op = Vector3.new(0, 0, 3.4),
		zoom = 2.0, shake = 1.0, turnRate = 1.1, aiRange = 190, aiMin = 0, aiErr = 0.5, burst = { 5, 10 }, pause = { 0.7, 1.5 },
	},
	AGL30 = {
		id = "AGL30", name = "AGL-30", short = "AGL-30", what = "30 mm automatic grenade launcher", sound = "AGL30",
		rpm = 425, belt = 30, round = "AGL30_ROUND", arm = 20, ammoName = "30 mm launcher round",
		velocity = 185, drag = 0.12, range = 900, zero = 120,
		spread = 0.1, bloomPerShot = 0.035, bloomMax = 0.6, bloomDecay = 0.5, tracerEvery = 0, loud = 2.4,
		arcs = { left = 60, right = 60, up = 55, down = 14 },
		pivotH = 3.4, muzzleLen = 3.6, eye = Vector3.new(0, 1.0, 1.5), op = Vector3.new(0, 0, 3.2),
		zoom = 3.0, shake = 1.5, turnRate = 0.9, aiRange = 170, aiMin = 40, aiErr = 0.6, burst = { 2, 4 }, pause = { 1.2, 2.2 },
	},
}

function S.interval(spec)
	return 60 / spec.rpm
end

-- angle in (-pi, pi]
function S.wrap(a)
	local w = (a + math.pi) % (2 * math.pi) - math.pi
	if w == -math.pi then
		return math.pi
	end
	return w
end

-- arcs in radians from degrees { left, right, up, down } (anything missing comes from the kind)
function S.makeArcs(spec, over)
	over = over or {}
	local d = spec.arcs
	return {
		l = math.rad(over.left or d.left), r = math.rad(over.right or d.right),
		up = math.rad(over.up or d.up), dn = math.rad(over.down or d.down),
	}
end

-- the upright frame of a CFrame: its position and heading (rotation about y), nothing else
function S.heading(cf)
	local _, y = cf:ToEulerAnglesYXZ()
	return y
end

function S.frame(cf)
	return CFrame.new(cf.Position) * CFrame.Angles(0, S.heading(cf), 0)
end

function S.pivot(frame, spec)
	return frame * CFrame.new(0, spec.pivotH, 0)
end

-- the gun's aim as a CFrame at the pivot
function S.aimCF(frame, spec, yaw, pitch)
	return S.pivot(frame, spec) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

function S.dirOf(frame, spec, yaw, pitch)
	return S.aimCF(frame, spec, yaw, pitch).LookVector
end

function S.muzzle(frame, spec, yaw, pitch)
	return (S.aimCF(frame, spec, yaw, pitch) * CFrame.new(0, 0.1, -spec.muzzleLen)).Position
end

-- the operator's eye (the camera): fixed height behind the pivot, turns with yaw only
function S.eye(frame, spec, yaw)
	return (S.pivot(frame, spec) * CFrame.Angles(0, yaw, 0) * CFrame.new(spec.eye)).Position
end

-- where the operator stands (feet)
function S.opSpot(frame, spec)
	return (frame * CFrame.new(spec.op)).Position
end

function S.clamp(arcs, yaw, pitch)
	return math.clamp(S.wrap(yaw), -arcs.r, arcs.l), math.clamp(pitch, -arcs.dn, arcs.up)
end

-- inside the arcs (tol: radians of slack)
function S.inArc(arcs, yaw, pitch, tol)
	tol = tol or 0
	local y = S.wrap(yaw)
	return y <= arcs.l + tol and y >= -arcs.r - tol and pitch <= arcs.up + tol and pitch >= -arcs.dn - tol
end

-- yaw and pitch that point the gun at a world position
function S.anglesTo(frame, spec, target)
	local d = frame:VectorToObjectSpace(target - S.pivot(frame, spec).Position)
	return math.atan2(-d.X, -d.Z), math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
end

-- the aim (yaw, pitch) that makes a round fired from the eye pass through target: the eye turns with the yaw, so a few
-- passes settle it (anglesTo measures from the pivot and is only good for arc checks)
function S.anglesFrom(frame, spec, target)
	local y, p = S.anglesTo(frame, spec, target)
	for _ = 1, 3 do
		local d = frame:VectorToObjectSpace(target - S.eye(frame, spec, y))
		y, p = math.atan2(-d.X, -d.Z), math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
	end
	return y, p
end

-- one step from a toward b of at most `step` (angles in radians, yaw wraps)
function S.approach(a, b, step)
	local d = S.wrap(b - a)
	if math.abs(d) <= step then
		return a + d
	end
	return a + (d > 0 and step or -step)
end

return S

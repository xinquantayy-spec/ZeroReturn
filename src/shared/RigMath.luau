--!nonstrict
-- Operator rig math (RigSpec): rest joint data, two-bone IK and the full-body pose solver.
-- One solver feeds both sides: the server writes the result into Motor6D.C0 (hitboxes follow stance, lean,
-- aim pitch and the weapon hold) and clients write it into Motor6D.Transform every frame (walk cycle,
-- gestures). Joint locals are rotations of the child relative to the parent at the joint (rest = identity);
-- the Root joint may also translate (crouch bob, prone).
local RigSpec = require(script.Parent.RigSpec)

local M = {}
local CF, V3 = CFrame.new, Vector3.new
local ANG = CFrame.Angles

local function centerOf(name)
	return name == "HumanoidRootPart" and RigSpec.hrp.center or RigSpec.parts[name].center
end

M.joints = {}
for _, j in RigSpec.joints do
	M.joints[j.name] = { name = j.name, part0 = j.p0, part1 = j.p1, p0 = j.pos - centerOf(j.p0), p1 = j.pos - centerOf(j.p1) }
end
M.hrpHalf = RigSpec.hrp.size.Y / 2
M.STAND_HIP = RigSpec.hipHeight
M.CROUCH_DROP = 0.95 -- full-depth crouch lowers the hips this much
M.PRONE_HIP = 0.45
M.headEye = V3(0, 0.08, -0.34) -- eye point in head space
local NECK_IN_CHEST = M.joints.Neck.p0
local PIVOT = (M.joints.RightShoulder.p0 + M.joints.LeftShoulder.p0) / 2 -- weapon pitch pivot (chest space)

-- hip height the owner's humanoid uses for a stance (others derive the floor from it)
function M.hipFor(stance, depth)
	if stance == "p" then
		return M.PRONE_HIP
	elseif stance == "c" then
		return M.STAND_HIP - M.CROUCH_DROP * (depth or 0.7)
	end
	return M.STAND_HIP
end

local function frame(d, h)
	local x = h - d * h:Dot(d)
	if x.Magnitude < 1e-5 then
		x = (math.abs(d.X) < 0.9) and Vector3.xAxis or Vector3.zAxis
		x -= d * x:Dot(d)
	end
	x = x.Unit
	local y = -d
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end
M.frame = frame

local function chain(a, b, c, hinge)
	local J1, J2, J3 = M.joints[a], M.joints[b], M.joints[c]
	local bu, bf = J2.p0 - J1.p1, J3.p0 - J2.p1
	return { j1 = J1, j2 = J2, j3 = J3, a = bu.Magnitude, b = bf.Magnitude, restU = frame(bu.Unit, hinge), restF = frame(bf.Unit, hinge) }
end
M.arm = { R = chain("RightShoulder", "RightElbow", "RightWrist", Vector3.xAxis), L = chain("LeftShoulder", "LeftElbow", "LeftWrist", Vector3.xAxis) }
M.leg = { R = chain("RightHip", "RightKnee", "RightAnkle", -Vector3.xAxis), L = chain("LeftHip", "LeftKnee", "LeftAnkle", -Vector3.xAxis) }

-- two-bone IK: middle joint position and hinge axis (world) for root S, end target W, lengths a/b, pole dir
function M.ik(S, W, a, b, pole)
	local d = W - S
	local dist = d.Magnitude
	local u = dist > 1e-4 and d / dist or V3(0, -1, 0)
	local reach = math.clamp(dist, math.abs(a - b) + 1e-3, a + b - 1e-3)
	local cosA = (a * a + reach * reach - b * b) / (2 * a * reach)
	local sinA = math.sqrt(math.max(0, 1 - cosA * cosA))
	local p = pole - u * pole:Dot(u)
	if p.Magnitude < 1e-4 then
		p = (math.abs(u.Y) < 0.9 and Vector3.yAxis or Vector3.zAxis)
		p -= u * p:Dot(u)
	end
	p = p.Unit
	return S + u * (a * cosA) + p * (a * sinA), p:Cross(u).Unit
end

-- solve a 3-joint chain so its end joint reaches `target` with world rotation `endRot`.
-- returns the three joint locals and the end part's world CFrame
function M.solve(c, parentCF, target, endRot, pole)
	local S = (parentCF * CF(c.j1.p0)).Position
	local E, h = M.ik(S, target, c.a, c.b, pole)
	local R1 = frame((E - S).Unit, h) * c.restU:Inverse()
	local seg1 = CF(S) * R1 * CF(-c.j1.p1)
	local Ej = (seg1 * CF(c.j2.p0)).Position
	local dF = target - Ej
	local R2 = (dF.Magnitude > 1e-4 and frame(dF.Unit, h) or frame((E - S).Unit, h)) * c.restF:Inverse()
	local seg2 = CF(Ej) * R2 * CF(-c.j2.p1)
	local Wj = (seg2 * CF(c.j3.p0)).Position
	local er = endRot.Rotation
	return parentCF.Rotation:Inverse() * R1, R1:Inverse() * R2, R2:Inverse() * er, CF(Wj) * er * CF(-c.j3.p1)
end

-- ── weapon holds (chest space) and hand grips (weapon space) ────────────────────
local R = math.rad
M.HOLD = {
	long = {
		ready = CF(0.26, -0.08, -0.86) * ANG(R(-22), R(8), 0),
		aim = CF(0.2, 0.42, -0.8),
		sprint = CF(0.1, -0.12, -0.62) * ANG(0, R(55), 0) * ANG(R(-32), 0, R(22)),
		low = CF(0.32, -0.5, -0.62) * ANG(R(-55), R(10), 0),
	},
	pistol = {
		ready = CF(0.16, -0.2, -1.0) * ANG(R(-30), 0, 0),
		aim = CF(0.06, 0.6, -1.5),
		sprint = CF(0.42, -0.45, -0.5) * ANG(R(-70), 0, 0),
		low = CF(0.42, -0.6, -0.55) * ANG(R(-75), 0, 0),
	},
	melee = {
		ready = CF(0.55, -0.28, -0.78) * ANG(R(12), 0, R(-24)),
		aim = CF(0.55, -0.28, -0.78) * ANG(R(12), 0, R(-24)),
		sprint = CF(0.62, -0.62, -0.42) * ANG(R(-45), 0, 0),
		low = CF(0.62, -0.68, -0.4) * ANG(R(-50), 0, 0),
	},
}
M.GRIP_R = CF(0.05, 0.06, 0.02) * ANG(R(35), 0, 0) -- right hand relative to the weapon's grip anchor
M.GRIP_L = CF(-0.03, -0.12, 0.0) * ANG(0, 0, R(90)) * ANG(R(-15), 0, 0) -- left hand under the handguard
M.GRIP_LP = CF(-0.07, -0.02, 0.04) * ANG(0, 0, R(55)) * ANG(R(25), 0, 0) -- left hand cupping a pistol grip
M.POUCH = CF(-0.45, -0.75, -0.42) -- chest space: rig pouch for magazines
M.ARM_POLE = { R = V3(0.6, -0.7, 0.9), L = V3(-0.7, -0.8, 0.6) } -- chest space, elbows down/out/back
M.KNEE_POLE = V3(0, 0, -1)

-- head CFrame for a stance (no arms/legs): the bodycam eye and third-person heads agree
function M.spine(rootCF, p)
	local rootL
	if p.stance == "p" then
		rootL = CF(0, -0.93, 0.55) * ANG(R(-88), 0, 0)
	else
		rootL = CF(0, -(p.bob or 0), 0) * ANG((p.fwd or 0), 0, (p.sway or 0))
	end
	local Jr = M.joints.Root
	local pelvis = rootCF * CF(Jr.p0) * rootL * CF(-Jr.p1)
	local lean = p.lean or 0
	local pitch = p.pitch or 0
	local waistL, neckL
	if p.stance == "p" then
		waistL = ANG(math.clamp(pitch, -0.2, 0.4) * 0.25, 0, 0)
		neckL = ANG(R(70) + math.clamp(pitch, -0.3, 0.6) * 0.6, 0, 0)
	else
		waistL = ANG(0, 0, -lean * 0.42) * ANG(pitch * 0.3 + (p.crouchFwd or 0), 0, 0)
		neckL = ANG(pitch * 0.5, 0, lean * 0.18)
	end
	local Jw, Jn = M.joints.Waist, M.joints.Neck
	local chest = pelvis * CF(Jw.p0) * waistL * CF(-Jw.p1)
	local head = chest * CF(Jn.p0) * neckL * CF(-Jn.p1)
	return pelvis, chest, head, rootL, waistL, neckL
end

-- eye point (world) for the first-person camera: root-relative, matching the third-person head
function M.eye(rootCF, p)
	local _, _, head = M.spine(rootCF, p)
	return head * CF(M.headEye)
end

-- Full-body pose.
-- p = { stance "s"|"c"|"p", depth, lean, pitch (rad), hold "long"|"pistol"|"melee"|nil, mode "ready"|"aim"|"sprint"|"low",
--       holdCF = CFrame? (chest-space hold, overrides mode), weapon = { grip, hand, magwell }?, floorY, airborne,
--       gait = { phase, amp, dir (root-local), stride, lift }?, lHand / rHand = CFrame? (world overrides),
--       weaponOverride = CFrame? (world) }
-- returns locals { [jointName] = CFrame }, weaponCF (world) or nil, rightHandCF
function M.pose(rootCF, p)
	local L = {}
	local pelvis, chest, _, rootL, waistL, neckL = M.spine(rootCF, p)
	L.Root, L.Waist, L.Neck = rootL, waistL, neckL
	local yaw = rootCF -- humanoid roots stay upright (yaw only)
	-- weapon
	local W
	local hold = p.hold and M.HOLD[p.hold]
	if hold then
		local h = p.holdCF or hold[p.mode or "ready"] or hold.ready
		if p.stance == "p" then
			W = yaw * CF(0.18, -1.0, -1.5) * ANG(math.clamp(p.pitch or 0, -0.35, 0.6), 0, 0)
			if p.hold == "pistol" then
				W *= CF(0, 0.05, -0.4)
			end
		else
			local remain = (p.pitch or 0) * 0.7
			W = chest * CF(PIVOT) * ANG(remain, 0, 0) * CF(-PIVOT) * h
		end
		if p.weaponOverride then
			W = p.weaponOverride
		end
	end
	-- arms
	local poleR = chest:VectorToWorldSpace(M.ARM_POLE.R)
	local poleL = chest:VectorToWorldSpace(M.ARM_POLE.L)
	local rHandCF
	local wp = p.weapon
	if W and wp then
		local rh = p.rHand or (W * CF(wp.grip) * M.GRIP_R)
		local a = M.arm.R
		local l1, l2, l3, handCF = M.solve(a, chest, (rh * CF(a.j3.p1)).Position, rh, poleR)
		L.RightShoulder, L.RightElbow, L.RightWrist, rHandCF = l1, l2, l3, handCF
		local lh = p.lHand
		if not lh and p.hold ~= "melee" then
			lh = W * CF(wp.hand) * (p.hold == "pistol" and M.GRIP_LP or M.GRIP_L)
		end
		if lh then
			local b = M.arm.L
			local m1, m2, m3 = M.solve(b, chest, (lh * CF(b.j3.p1)).Position, lh, poleL)
			L.LeftShoulder, L.LeftElbow, L.LeftWrist = m1, m2, m3
		end
	end
	if not L.RightShoulder then
		-- unarmed / free hand: relaxed hang with a little swing
		local sw = p.gait and p.gait.amp * math.sin(p.gait.phase) * 0.35 or 0
		L.RightShoulder, L.RightElbow, L.RightWrist = ANG(-sw + 0.05, 0, R(4)), ANG(R(12), 0, 0), CFrame.identity
	end
	if not L.LeftShoulder then
		local sw = p.gait and p.gait.amp * math.sin(p.gait.phase) * 0.35 or 0
		L.LeftShoulder, L.LeftElbow, L.LeftWrist = ANG(sw + 0.05, 0, R(-4)), ANG(R(14), 0, 0), CFrame.identity
	end
	-- legs
	if p.airborne and p.stance ~= "p" then
		L.RightHip, L.RightKnee, L.RightAnkle = ANG(R(18), 0, R(3)), ANG(R(-30), 0, 0), ANG(R(10), 0, 0)
		L.LeftHip, L.LeftKnee, L.LeftAnkle = ANG(R(8), 0, R(-3)), ANG(R(-42), 0, 0), ANG(R(14), 0, 0)
	elseif p.stance == "p" then
		L.RightHip, L.RightKnee, L.RightAnkle = ANG(0, 0, R(-6)), ANG(R(-4), 0, 0), ANG(R(-60), 0, 0)
		L.LeftHip, L.LeftKnee, L.LeftAnkle = ANG(0, 0, R(6)), ANG(R(-4), 0, 0), ANG(R(-60), 0, 0)
	else
		local floorY = p.floorY or (rootCF.Position.Y - M.hipFor(p.stance, p.depth) - M.hrpHalf)
		local g = p.gait
		local crouch = p.stance == "c" and (p.depth or 0.7) or 0
		local kneePole = rootCF:VectorToWorldSpace(M.KNEE_POLE)
		for _, side in { "R", "L" } do
			local c = M.leg[side]
			local sx = side == "R" and 1 or -1
			local base = V3(sx * (0.4 + crouch * 0.1), 0, -crouch * 0.25)
			local lift, fp = 0, 0
			if g and g.amp > 0.01 then
				local ph = (g.phase + (side == "R" and 0 or math.pi)) % (2 * math.pi)
				local half = g.amp * (g.stride or 1.2) / 2
				local u
				if ph < math.pi then -- stance: foot planted, slides back under the body
					u = ph / math.pi
					base += (g.dir or V3(0, 0, -1)) * (half - 2 * half * u)
				else -- swing: lift and carry forward
					u = (ph - math.pi) / math.pi
					local e = u * u * (3 - 2 * u)
					base += (g.dir or V3(0, 0, -1)) * (-half + 2 * half * e)
					lift = math.sin(u * math.pi) * (g.lift or 0.32) * g.amp
					fp = -math.sin(u * math.pi) * 0.35 * g.amp
				end
			end
			local ankleW = rootCF:PointToWorldSpace(base)
			ankleW = V3(ankleW.X, floorY + 0.26 + lift, ankleW.Z)
			local footRot = yaw.Rotation * ANG(fp, 0, 0)
			local h1, h2, h3 = M.solve(c, pelvis, ankleW, footRot, kneePole)
			L[side == "R" and "RightHip" or "LeftHip"] = h1
			L[side == "R" and "RightKnee" or "LeftKnee"] = h2
			L[side == "R" and "RightAnkle" or "LeftAnkle"] = h3
		end
	end
	return L, W, rHandCF
end

return M

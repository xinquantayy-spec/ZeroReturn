--!strict
-- Tarkov's recoil (audit decision gameplay-1a). Pure rules shared by the client (Weapon fires, Camera springs) and
-- RecoilTests. No per-frame allocation: a profile and a state are tables the caller keeps and these functions refill.
--
-- How Tarkov's recoil works, and where each part comes from:
-- - Every shot kicks the gun along a set recoil angle (90 = straight up, more = to the left, less = to the right) with
--   a random dispersion either side of it; the vertical recoil figure sets how hard. The horizontal figure is the
--   rearward kick into the shoulder, not the sideways throw (VK "Tarkovskoe Metadvizhenie", "Otdacha oruzhiya v EFT",
--   13 March 2023: angle 140 up-left, 60 up-right, most guns close to 100; dispersion e.g. 120 +- 60).
-- - Convergence pulls the gun back to where you aimed. In full auto it cannot keep up, so the gun hangs at a height
--   and returns when you let go (same VK article); the first shots fly up most, then it settles back down in auto
--   (SPT Forge, Fontaine's Recoil Overhaul, describing vanilla). Pulling down during a burst therefore leaves you low
--   once it returns, as in Tarkov.
-- - The camera has its own, smaller recoil; bullets leave the barrel, so they and the sights follow the gun.
-- - Tarkov 0.16: a camera shake from the buttstock hitting the shoulder and a random turn of the weapon on each shot
--   (0.16.0.0 patch notes, Insider Gaming).
-- - The build's recoil (its parts' percentages, Tarkov's sum) and the weapon skills scale it all.
-- Numbers from Tarkov's own config (SPT's copy of the game's backend globals, config.Aiming and config.SkillsSettings)
-- are named after their field. What is marked "ours" was not found for Tarkov and is tuned here.
local Progress = require(script.Parent.Progress)

local R = {}

-- ── Tarkov's globals ──────────────────────────────────────────────────────────────────────────────────────────────
R.SCALING = 1 -- RecoilScaling
R.CONVERGENCE_MULT = 1 -- RecoilConvergenceMult
-- recoil by pose: RecoilXIntensityByPose { 0.6, 0.7, 1 }, RecoilYIntensityByPose and RecoilZIntensityByPose
-- { 0.7, 0.7, 1 }. Our reading: X the climb, Y sideways, Z rearward, each { prone, crouched, standing } (standing must
-- be the 1, and the sway's ProceduralIntensityByPose { 0.6, 0.7, 1 } is least when prone)
R.PRONE = { 0.6, 0.7, 0.7 }
R.CROUCH = { 0.7, 0.7, 0.7 }
-- weapon skills (WeaponSkillRecoilBonusPerLevel) and Recoil Control (RecoilControl.RecoilBonusPerLevel): 0.3 % less
-- recoil a level each, -15.3 % at elite (tarkovforge.com Assault Rifles: "-0.3% per level, up to -15% at Elite");
-- the two multiply (our reading)
R.WEAPON_SKILL_PER = 0.003
R.CONTROL_PER = 0.003
-- the springs. RecoilHandDamping 0.45 and RecoilDamping 0.7 read as the velocity kept per physics step at Unity's
-- default 50 Hz (our reading): the gun rises at 40 a second, the camera more softly at 18
R.HAND_RISE = -math.log(0.45) * 50
R.CAM_RISE = -math.log(0.7) * 50

-- ── ours ──────────────────────────────────────────────────────────────────────────────────────────────────────────
-- degrees of climb per point of Tarkov's vertical figure: a default R-17 (Tarkov's M4A1, 79) peaks at 1.2 degrees a
-- shot; in full auto it flies to about 2.9 in the first shots and hangs near 1.3
R.DEG_PER_V = 0.015
-- pistols and shotguns show figures 3 to 5 times a rifle's for a kick nowhere near that much bigger
R.CLASS_K = { pistol = 0.5, shotgun = 0.7 } :: { [string]: number }
R.STRENGTH = { 0.9, 1.15 } -- each shot's strength drawn in this band
R.BACK = { 0.65, 1.05 } -- each shot's rearward kick drawn in this band
R.BACK_PER_H = 0.000145 -- viewmodel studs of rearward kick per point of horizontal figure (visual)
R.THUMP_PER_H = 0.000045 -- radians of the buttstock's camera roll per point of horizontal figure (0.16, visual)
R.STABLE_MUL = 0.5 -- after the gun's stable shot the climb kick is halved; the sideways throw stays
R.SERIES_GAP = 2 -- a pause longer than this many cycles starts a new series of shots
R.ERGO = { 0.85, 1.15 } -- convergence x at 0 and 100 ergonomics (1 at 50)
R.MEAN_STRENGTH = (R.STRENGTH[1] + R.STRENGTH[2]) / 2

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- recoil multipliers for the pose (climb, sideways, rearward). depth: Movement's crouch depth, 0 near standing to 1
-- fully down; the crouch figure blends in with the height (our reading)
function R.pose(stance: string?, depth: number?): (number, number, number)
	if stance == "p" then
		return R.PRONE[1], R.PRONE[2], R.PRONE[3]
	elseif stance == "c" then
		local d = math.clamp(depth or 1, 0, 1)
		return lerp(1, R.CROUCH[1], d), lerp(1, R.CROUCH[2], d), lerp(1, R.CROUCH[3], d)
	end
	return 1, 1, 1
end

-- the skills' multiplier: the weapon class's skill and Recoil Control (profile skill "recoil", read if present)
function R.skillMul(skills: any?, class: string?): number
	if type(skills) ~= "table" then
		return 1
	end
	local ws = Progress.WEAPON_SKILL[class or ""]
	local lw = ws and Progress.skillLevel(skills[ws]) or 0
	local lc = Progress.skillLevel(skills.recoil)
	return (1 - R.WEAPON_SKILL_PER * lw) * (1 - R.CONTROL_PER * lc)
end

-- convergence by ergonomics (the build's and the gear's): handier guns come back sooner (ours)
function R.ergoMul(ergo: number?): number
	return lerp(R.ERGO[1], R.ERGO[2], math.clamp(ergo or 50, 0, 100) / 100)
end

-- the peak of one kick on a spring that rises at a and returns at b (a > b): the kick D * (e^-bt - e^-at) tops at this
-- share of D
function R.peak(a: number, b: number): number
	local r = b / a
	return r ^ (b / (a - b)) - r ^ (a / (a - b))
end

export type Profile = {
	v: number, -- Tarkov's vertical figure of this build after skills
	h: number, -- and its horizontal (rearward) figure
	climb: number, -- degrees of climb of one shot at full strength
	back: number, -- viewmodel studs of rearward kick
	thump: number, -- radians of camera roll from the buttstock
	angle: number,
	disp: number,
	conv: number, -- the return per second
	cam: number, -- the camera's share
	stable: number, -- full auto settles after this shot (0: never)
	dg: number, -- the gun spring's kick scale (a shot's climb is its peak)
	dc: number, -- the camera spring's
}

function R.blank(): Profile
	return { v = 0, h = 0, climb = 0, back = 0, thump = 0, angle = 90, disp = 0, conv = 5, cam = 0.4, stable = 0, dg = 1, dc = 0.4 }
end

-- a gun's recoil now: def (Weapons entry), recoilMul (the build against its default build, WeaponParts.stats().recoil),
-- ergo (the build's ergonomics with the gear's), skills (the profile's). Fills `out` when given.
function R.profile(def: any, recoilMul: number?, ergo: number?, skills: any?, out: Profile?): Profile
	local p = out or R.blank()
	local k = (recoilMul or 1) * R.skillMul(skills, def.class) * R.SCALING
	p.v = (def.recoilV or 0) * 100 * k
	p.h = (def.recoilH or 0) * 100 * k
	p.climb = p.v * R.DEG_PER_V * (R.CLASS_K[def.class or ""] or 1)
	p.back = p.h * R.BACK_PER_H
	p.thump = p.h * R.THUMP_PER_H
	p.angle = def.recoilAngle or 90
	p.disp = def.recoilDisp or 0
	-- kept well under the camera's rise so both springs keep a clean rise then return
	p.conv = math.min((def.recoilConv or 5) * R.CONVERGENCE_MULT * R.ergoMul(ergo), R.CAM_RISE * 0.8)
	p.cam = math.clamp(def.recoilCam or 0.4, 0, 1)
	p.stable = def.recoilStable or 0
	p.dg = 1 / R.peak(R.HAND_RISE, p.conv)
	p.dc = p.cam / R.peak(R.CAM_RISE, p.conv)
	return p
end

-- the shot's index in its series: Tarkov counts the shots of a burst; a pause of more than two cycles starts again
function R.nextIndex(n: number, gap: number, period: number): number
	if gap <= period * R.SERIES_GAP then
		return n + 1
	end
	return 1
end

-- one shot's kick: climb and sideways (degrees; sideways positive = left) and rearward (studs). n: the shot's index in
-- its series; pv, ph, pb: R.pose; u1 (angle), u2 (strength), u3 (rearward): random numbers 0..1
function R.kick(p: Profile, n: number, pv: number, ph: number, pb: number, u1: number, u2: number, u3: number): (number, number, number)
	local th = math.rad(p.angle + (2 * u1 - 1) * p.disp)
	local s = lerp(R.STRENGTH[1], R.STRENGTH[2], u2) * p.climb
	local jp = s * math.sin(th) * pv
	local jy = -s * math.cos(th) * ph
	if p.stable > 0 and n > p.stable then
		jp *= R.STABLE_MUL
	end
	return jp, jy, lerp(R.BACK[1], R.BACK[2], u3) * p.back * pb
end

-- the springs: each axis is a fast rise (u - w, w decays at the rise) and a slow return (u decays at the convergence),
-- stepped exactly, so 30 and 144 frames a second give the same climb
export type State = { gu: number, gw: number, hu: number, hw: number, cu: number, cw: number, du: number, dw: number, b: number }

function R.new(): State
	return { gu = 0, gw = 0, hu = 0, hw = 0, cu = 0, cw = 0, du = 0, dw = 0, b = 5 }
end

-- a shot's kick (degrees, R.kick) into the gun's and the camera's springs
function R.shot(st: State, p: Profile, jp: number, jy: number)
	st.b = p.conv
	local g, c = p.dg, p.dc
	st.gu += jp * g
	st.gw += jp * g
	st.hu += jy * g
	st.hw += jy * g
	st.cu += jp * c
	st.cw += jp * c
	st.du += jy * c
	st.dw += jy * c
end

function R.step(st: State, dt: number)
	if dt <= 0 then
		return
	end
	local eb = math.exp(-st.b * dt)
	local eh = math.exp(-R.HAND_RISE * dt)
	local ec = math.exp(-R.CAM_RISE * dt)
	st.gu *= eb
	st.hu *= eb
	st.cu *= eb
	st.du *= eb
	st.gw *= eh
	st.hw *= eh
	st.cw *= ec
	st.dw *= ec
end

-- the gun's offset from the aim point (degrees: climb, left)
function R.gun(st: State): (number, number)
	return st.gu - st.gw, st.hu - st.hw
end

-- the camera's offset (degrees)
function R.cam(st: State): (number, number)
	return st.cu - st.cw, st.du - st.dw
end

-- the climb of one standing shot of the default build in degrees (the AI's burst error reads it)
function R.kickDeg(def: any): number
	return (def.recoilV or 0) * 100 * R.DEG_PER_V * (R.CLASS_K[def.class or ""] or 1) * R.MEAN_STRENGTH
end

-- where a sight's dot sits on screen for the gun's offset from the camera (radians; up, left): pixels right and down
-- from the centre, for the vertical field of view (degrees) and the viewport's height
function R.screen(relP: number, relY: number, vfov: number, height: number): (number, number)
	local f = (height / 2) / math.tan(math.rad(vfov) / 2)
	return -math.tan(relY) * f, -math.tan(relP) * f
end

return R

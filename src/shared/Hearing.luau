--!strict
-- Footstep hearing (Tarkov skills, audit gameplay.9): pure rules shared by the client's Effects.footstep and the server's
-- GameplayTests, so the rule that plays is the rule that is checked.
-- Your Perception lengthens how far you hear (+0.3 % a level, +15 % at elite: the EFT wiki, quoted at
-- gamezo.gg/?p=72006). The walker's Covert Movement shortens how far his steps carry (EFT wiki Covert_Movement and
-- tarkovforge.com/skills/covert-movement: -1.2 % a level on common surfaces, -0.6 % on uncommon ones, -60 % on every
-- surface at elite; it "reduces the sound radius"; weapon and equipment noise -1.2 % a level). The rates a level live in
-- Progress.SKILLS (perception.per, covert.per); the results are capped at Tarkov's elite figures, so they hold whatever
-- rate a branch has. Which surfaces are "uncommon" is not published: here they are the loud ones, metal and gravel.
local Progress = require(script.Parent.Progress)

local H = {}

H.PERCEPTION_MAX = 0.15 -- Tarkov: hearing distance +15 % at elite
H.COVERT_MAX = 0.6 -- Tarkov: footstep noise -60 % at elite
H.LOUD_SURFACE = { metal = true, gravel = true } -- Effects.surfaceOf families taken as Tarkov's "uncommon" surfaces

-- the share the walker's Covert Movement level takes off his step's radius on a surface family (nil: his kit's noise)
function H.covertQuiet(level: number?, fam: string?): number
	if type(level) ~= "number" or level <= 0 then
		return 0
	end
	local q = Progress.SKILLS.covert.per * level
	if fam ~= nil and H.LOUD_SURFACE[fam] and level < Progress.SKILL_MAX then
		q *= 0.5
	end
	return math.min(H.COVERT_MAX, q)
end

-- how much further the listener hears for his Perception (1 = untrained)
function H.perceptionReach(skills: any?): number
	return 1 + math.min(H.PERCEPTION_MAX, Progress.bonus(skills, "perception"))
end

-- the radius (studs) of someone else's step. intensity runs 0.11 (slow crouch) to 1.25 (sprint). How far steps carry is
-- Tarkov's after 0.14.5.5 (audit gameplay.5): about 43 m (134 studs) crouch-walking slowly, over 100 m (312 studs)
-- sprinting; an active headset lifts quiet sounds (x1.3); then the two skills.
function H.stepRadius(intensity: number, headset: boolean, listenerSkills: any?, walkerCovert: number?, fam: string?): number
	return (120 + intensity * 160) * (headset and 1.3 or 1) * H.perceptionReach(listenerSkills) * (1 - H.covertQuiet(walkerCovert, fam))
end

return H

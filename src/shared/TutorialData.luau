--!strict
-- Decision ui-5a (the audit's "EFT 1.0-style tutorial raid"): the first raid. Tarkov 1.0 (15 November 2025) puts a new
-- character into a short raid of its own on a closed-off part of Ground Zero: it starts in an office lobby with medical
-- supplies on the reception desk, a body in the corridor beyond a barricade carries an SMG and three magazines, two or
-- three scavs hold the parking garage with its cars for cover, more wait on the street, a second building leads out
-- the back past tents with medkits and splints, and a green flare marks the exit at a gated fence. Control signs on the
-- walls and green glowing bars along the floor point the way; it lasts about 20 minutes, and then the story begins
-- (Prima Games' walkthrough; VidaExtra; Insider Gaming, all 2025). Ours copies that course on its own small area (the
-- map "tutorial", src/server/Maps/Tutorial.luau), with each sign naming the control for the device in use (keyboard,
-- gamepad or touch). Differences, by decision: it is offered, not forced, and can be skipped; the kit it starts with
-- is a loan (nothing from the stash goes in, and what comes out goes to the stash like a scav run's); a death or a
-- give-up costs nothing and the offer stays.

local T = {}

T.MAP = "tutorial"
T.TIME = 1200 -- seconds: Tarkov's tutorial raid takes about 20 minutes (VidaExtra)
T.SPAWN = "T0"
T.EXIT = "TG"

-- the loaned kit: a knife on the belt, an open chest rig and a small bag, one dressing in the pockets. The gun comes from
-- the body in the corridor, as in Tarkov.
T.KIT = {
	slots = { melee = "FIELD_KNIFE", rig = "RIG_CHEST", back = "BAG_SLING" },
	pockets = { { "BANDAGE", 1 } },
}

-- what lies where (map-local positions come from the map module; these are the contents). Tarkov: healing on the
-- reception desk; the SMG with three magazines beside a body; A-1 medkits, CARs and splints in the tents.
T.LOOT = {
	desk = { { "MEDKIT_S", 1 }, { "PAINKILLERS", 1 }, { "BANDAGE", 1 } },
	body = { { "SPARROW_SMG", 1, "gun" }, { "SPARROW_MAG", 3, "mag" }, { "MEDKIT_M", 1 } },
	tentA = { { "MEDKIT_S", 1 }, { "SPLINT", 1 }, { "WATER", 1 } },
	tentB = { { "MEDKIT_M", 1 }, { "TOURNIQUET", 1 }, { "CHOC_BAR", 1 } },
}
T.AMMO = "A9_PST" -- the rounds in the body's magazines (the SMG-9 fires 9x19)

-- the steps, in order. `signs`: the controls the signs at that place name (Input actions; "Interact" is the prompt key).
-- `done`: how the server knows (Tutorial.luau checks these kinds).
export type Step = { id: string, text: string, signs: { string }, done: string }
T.STEPS = {
	{ id = "desk", text = "Take the medical supplies from the reception desk", signs = { "Interact", "Inventory" }, done = "has:MEDKIT_S" },
	{ id = "body", text = "Get over the barricade and search the body: take the SMG and its magazines", signs = { "Vault", "Interact" }, done = "has:SPARROW_SMG" },
	{ id = "load", text = "Put the SMG in your hands and load a magazine", signs = { "Primary", "Reload", "MagCheck" }, done = "loaded" },
	{ id = "garage", text = "Clear the parking garage", signs = { "Aim", "Fire", "LeanLeft", "LeanRight" }, done = "clear:garage" },
	{ id = "heal", text = "Treat your wounds", signs = { "Heal", "Inventory" }, done = "healthy" },
	{ id = "street", text = "Cross the street to the office block", signs = { "Sprint", "Crouch" }, done = "zone:office" },
	{ id = "tents", text = "Take what you need from the tents in the yard", signs = { "Interact" }, done = "zone:yard" },
	{ id = "exit", text = "Follow the green lights to the gate and extract", signs = { "Extracts" }, done = "extract" },
} :: { Step }

-- who is offered it: a profile that has never raided and has not finished or skipped it
function T.offered(prof: any): boolean
	if type(prof) ~= "table" then
		return false
	end
	if prof.tut ~= nil then
		return false
	end
	local st = prof.stats
	return type(st) ~= "table" or ((st.raids or 0) == 0 and (st.scavRaids or 0) == 0)
end

-- the step after `id` (nil at the end)
function T.next(id: string?): Step?
	if id == nil then
		return T.STEPS[1]
	end
	for i, s in T.STEPS do
		if s.id == id then
			return T.STEPS[i + 1]
		end
	end
	return nil
end

function T.step(id: string): Step?
	for _, s in T.STEPS do
		if s.id == id then
			return s
		end
	end
	return nil
end

return T

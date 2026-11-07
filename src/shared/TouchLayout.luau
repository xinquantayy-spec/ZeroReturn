--!strict
-- Touch controls: the elements, where they start, their icons, and the check a player's own layout passes on the
-- server (Settings, CONTROLS, EDIT TOUCH LAYOUT). Tarkov has no touch controls (EFT_PARITY exception 4), so the design
-- follows what mobile shooters settled on (docs/design/TOUCH_CONTROLS.md): CoD Mobile, PUBG Mobile, Arena Breakout.
local T = {}

-- assets/textures/gen_touch_icons.py: 1024 x 512, 32 white icons in 128 px cells, 8 per row (tinted at runtime)
T.ICONS = "rbxassetid://124317104695534"
T.ICON = {
	FIRE = 0, AIM = 1, RELOAD = 2, CROUCH = 3, PRONE = 4, JUMP = 5, LEAN_L = 6, LEAN_R = 7,
	GRENADE = 8, MED = 9, SWAP = 10, MODE = 11, MORE = 12, LOOK = 13, LIGHT = 14, NV = 15,
	GEAR = 16, EXITS = 17, BAG = 18, RUN = 19, LOCK = 20, BREATH = 21, CHAMBER = 22, MAGCHECK = 23,
	INSPECT = 24, ZERO_UP = 25, ZERO_DOWN = 26, SIGHT = 27, DEVICE = 28, MODECHECK = 29, CLOSE = 30, AUTO = 31,
}

function T.rect(i: number): (Vector2, Vector2)
	return Vector2.new((i % 8) * 128, math.floor(i / 8) * 128), Vector2.new(128, 128)
end

export type Element = {
	id: string, name: string, icon: string?, x: number, y: number, size: number, shown: boolean, square: boolean?,
	tap: string?, hold: string?, press: string?, drag: boolean?, special: string?, raid: boolean?, mount: boolean?, like: string?,
}

-- id, editor name, icon, default centre (scale of the screen's safe area), size (px on a 390 px tall screen; larger
-- screens scale it up to 1.35x), shown by default. The action an element sends:
--   press = the action is down while the finger is (FIRE, NADE, LOOK, leans...)
--   tap / hold = a tap does one action, a press held Input.HOLD the other (RELOAD: magazine check, CROUCH: prone...)
--   special = the stick, the jump, the med wheel, the tray, the menu row's own handling
-- raid = shown only in a raid. Elements with x = -1 take a place worked out at runtime (the menu row: the top bar's free
-- band, centred).
T.ELEMENTS = {
	{ id = "joy", name = "MOVE STICK", x = 0.15, y = 0.72, size = 124, shown = true, special = "joy" },
	{ id = "fire", name = "FIRE (DRAG TO AIM)", icon = "FIRE", x = 0.84, y = 0.64, size = 96, shown = true, press = "Fire", drag = true, raid = true },
	{ id = "aim", name = "AIM DOWN SIGHTS", icon = "AIM", x = 0.70, y = 0.49, size = 62, shown = true, press = "Aim", raid = true },
	{ id = "reload", name = "RELOAD / HOLD: CHECK MAGAZINE", icon = "RELOAD", x = 0.94, y = 0.42, size = 54, shown = true, tap = "Reload", hold = "MagCheck", raid = true },
	{ id = "jump", name = "JUMP / VAULT", icon = "JUMP", x = 0.95, y = 0.86, size = 56, shown = true, special = "jump" },
	{ id = "crouch", name = "CROUCH / HOLD: PRONE", icon = "CROUCH", x = 0.84, y = 0.89, size = 56, shown = true, tap = "Crouch", hold = "Prone" },
	{ id = "nade", name = "GRENADE (HOLD, DRAG, LET GO)", icon = "GRENADE", x = 0.72, y = 0.87, size = 50, shown = true, press = "Grenade", drag = true, raid = true },
	{ id = "med", name = "MEDS AND QUICK SLOTS / HOLD: BEST MED", icon = "MED", x = 0.61, y = 0.82, size = 50, shown = true, special = "wheel", hold = "Heal", raid = true },
	{ id = "swap", name = "NEXT WEAPON / HOLD: INSPECT", icon = "SWAP", x = 0.59, y = 0.66, size = 50, shown = true, tap = "CycleWeapon", hold = "InspectWeapon", raid = true },
	{ id = "mode", name = "FIRE MODE / HOLD: CHECK IT", icon = "MODE", x = 0.59, y = 0.49, size = 46, shown = true, tap = "FireMode", hold = "FireModeCheck", raid = true },
	{ id = "leanL", name = "LEAN LEFT", icon = "LEAN_L", x = 0.70, y = 0.33, size = 44, shown = true, press = "LeanLeft", raid = true },
	{ id = "leanR", name = "LEAN RIGHT", icon = "LEAN_R", x = 0.80, y = 0.33, size = 44, shown = true, press = "LeanRight", raid = true },
	-- LOOK and MORE sit off the screen's centre line, where they covered the view (audit ui.10); LOOK stays below the
	-- recorder column's raid clock
	{ id = "look", name = "FREE LOOK (DRAG)", icon = "LOOK", x = 0.89, y = 0.31, size = 44, shown = true, press = "FreeLook", drag = true, raid = true },
	{ id = "more", name = "MORE (THE RARELY USED)", icon = "MORE", x = 0.60, y = 0.20, size = 44, shown = true, special = "tray", raid = true },
	{ id = "breath", name = "HOLD BREATH (WHILE AIMING)", icon = "BREATH", x = 0.31, y = 0.58, size = 50, shown = true, press = "Sprint", raid = true },
	-- off at first (the editor shows them): a second fire button for the left thumb, and the device and goggles, which
	-- the tray holds
	{ id = "fireL", name = "LEFT FIRE", icon = "FIRE", x = 0.31, y = 0.40, size = 62, shown = false, press = "Fire", raid = true },
	{ id = "light", name = "TACTICAL DEVICE / HOLD: ITS MODE", icon = "LIGHT", x = 0.49, y = 0.49, size = 44, shown = false, press = "Light", raid = true },
	{ id = "nv", name = "NIGHT VISION", icon = "NV", x = 0.49, y = 0.62, size = 44, shown = false, press = "ToggleNVG", raid = true },
	-- at a stationary gun these replace the weapon's (the Stationary controller; FIRE drags to aim)
	-- (they stand where FIRE, AIM and RELOAD stand in the player's layout: `like`)
	{ id = "mfire", name = "GUN: FIRE (DRAG TO AIM)", icon = "FIRE", x = 0.84, y = 0.64, size = 96, shown = true, press = "MountFire", drag = true, raid = true, mount = true, like = "fire" },
	{ id = "mzoom", name = "GUN: ZOOM", icon = "AIM", x = 0.70, y = 0.49, size = 62, shown = true, press = "MountZoom", raid = true, mount = true, like = "aim" },
	{ id = "mleave", name = "GUN: LEAVE", icon = "CLOSE", x = 0.94, y = 0.42, size = 54, shown = true, press = "MountLeave", raid = true, mount = true, like = "reload" },
	-- the menu row (rounded squares): settings, the exits, the bag
	{ id = "set", name = "SETTINGS", icon = "GEAR", x = -1, y = -1, size = 46, shown = true, square = true, press = "Settings" },
	{ id = "exits", name = "EXITS", icon = "EXITS", x = -1, y = -1, size = 46, shown = true, square = true, press = "Extracts", raid = true },
	{ id = "bag", name = "INVENTORY", icon = "BAG", x = -1, y = -1, size = 46, shown = true, square = true, press = "Inventory" },
} :: { Element }

T.byId = {} :: { [string]: Element }
for _, e in T.ELEMENTS do
	T.byId[e.id] = e
end

-- the tray (MORE): the rarely used, each an icon; `need` hides one that cannot do anything now (Touch.luau)
T.TRAY = {
	-- short: the caption under the icon (audit ui.10)
	{ action = "MagCheck", icon = "MAGCHECK", name = "CHECK MAGAZINE", short = "MAG" },
	{ action = "ChamberCheck", icon = "CHAMBER", name = "CHECK CHAMBER", short = "CHAMBER" },
	{ action = "FireModeCheck", icon = "MODECHECK", name = "CHECK FIRE MODE", short = "MODE?" },
	{ action = "InspectWeapon", icon = "INSPECT", name = "INSPECT WEAPON", short = "INSPECT" },
	{ action = "ZeroUp", icon = "ZERO_UP", name = "ZEROING UP", short = "ZERO +" },
	{ action = "ZeroDown", icon = "ZERO_DOWN", name = "ZEROING DOWN", short = "ZERO -" },
	{ action = "SightMode", icon = "SIGHT", name = "SIGHT MODE", need = "zoom", short = "SIGHT" },
	{ action = "Light", icon = "LIGHT", name = "TACTICAL DEVICE", need = "device", short = "DEVICE" },
	{ action = "DeviceMode", icon = "DEVICE", name = "DEVICE MODE", need = "combo", short = "DEV MODE" },
	{ action = "ToggleNVG", icon = "NV", name = "NIGHT VISION", need = "goggles", short = "NV" },
}

T.LIMITS = { s = { 0.6, 1.6 }, o = { 0.25, 1 } }

-- a player's layout as the server keeps it: { [id] = { x, y, s, o, h } } for known elements only, every number finite
-- and in range; anything else is dropped. nil when there is nothing usable.
function T.sanitize(t: any): any?
	if type(t) ~= "table" then
		return nil
	end
	local out, n = {}, 0
	for id, v in t do
		if type(id) == "string" and T.byId[id] and type(v) == "table" and n < #T.ELEMENTS then
			local e = {}
			local function num(k: string, lo: number, hi: number)
				local x = v[k]
				if type(x) == "number" and x == x and x > -math.huge and x < math.huge then
					e[k] = math.clamp(x, lo, hi)
				end
			end
			num("x", 0, 1)
			num("y", 0, 1)
			num("s", T.LIMITS.s[1], T.LIMITS.s[2])
			num("o", T.LIMITS.o[1], T.LIMITS.o[2])
			if type(v.h) == "boolean" then
				e.h = v.h
			end
			if next(e) ~= nil then
				out[id] = e
				n += 1
			end
		end
	end
	return n > 0 and out or nil
end

return T

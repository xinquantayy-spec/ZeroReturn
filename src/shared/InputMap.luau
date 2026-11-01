--!strict
-- Single source of truth for action bindings (PC keys, gamepad, touch label). Movement/jump/look stay
-- with Roblox's PlayerModule + our camera. Interact uses ProximityPrompts (F / ButtonX / tap); Q/E lean (Tarkov).
-- Gamepad D-pad buttons are shared: a tap does one thing, a hold another. D-down: extracts / grenade (Grenade
-- controller); D-right: fire mode / tactical device; D-left: next weapon / goggles (Weapon and NightVision).
-- PC keys are Tarkov's defaults (docs/design/EFT_PARITY.md section 4): `mod` makes a chord with Alt, Shift or
-- Ctrl (Alt+T checks the magazine, Shift+T the chamber, Alt+B the fire mode); a key's plain action only fires
-- when none of its chord modifiers is held. Players can rebind PC keys (Settings, CONTROLS); Esc stays Roblox's
-- menu, so the settings open on P.
local K = Enum.KeyCode
return {
	Fire = { keys = { K.MouseLeftButton }, pad = { K.ButtonR2 }, touch = "FIRE", context = "play" },
	Aim = { keys = { K.MouseRightButton }, pad = { K.ButtonL2 }, touch = "ADS", context = "play" },
	Reload = { keys = { K.R }, pad = { K.ButtonX }, touch = "RLD", context = "play" },
	Sprint = { keys = { K.LeftShift }, pad = { K.ButtonL3 }, touch = "RUN", context = "play" },
	Crouch = { keys = { K.C }, pad = { K.ButtonB }, touch = "CRCH", context = "play" },
	-- Tarkov heals from quick slots (4 to 0) or the inventory; gamepad and touch keep a MED button
	Heal = { keys = {}, pad = { K.DPadUp }, touch = "MED", context = "play" },
	FireMode = { keys = { K.B }, pad = { K.DPadRight }, context = "play" },
	FireModeCheck = { keys = { K.B }, mod = "Alt", pad = {}, context = "play" },
	Extracts = { keys = { K.O }, pad = { K.DPadDown }, touch = "EXIT", context = "play" },
	Inventory = { keys = { K.Tab }, pad = { K.ButtonY }, touch = "BAG", context = "global" },
	Settings = { keys = { K.P }, pad = { K.ButtonSelect }, touch = "SET", context = "global" },
	Back = { keys = { K.Backspace }, pad = { K.ButtonB }, context = "menu" },
	-- Tarkov: 1 sidearm (holster), 2 weapon on sling, 3 weapon on back, V melee
	Sidearm = { keys = { K.One }, pad = {}, context = "play" },
	Primary = { keys = { K.Two }, pad = {}, context = "play" },
	Secondary = { keys = { K.Three }, pad = {}, context = "play" },
	Knife = { keys = { K.V }, pad = {}, context = "play" },
	CycleWeapon = { keys = {}, pad = { K.DPadLeft }, touch = "SWAP", context = "play" },
	MagCheck = { keys = { K.T }, mod = "Alt", pad = { K.ButtonR3 }, context = "play" },
	ChamberCheck = { keys = { K.T }, mod = "Shift", pad = {}, context = "play" },
	-- T: the tactical device on and off. Gamepad: hold D-right (a tap is the fire mode). Touch: LGT.
	Light = { keys = { K.T }, pad = { K.DPadRight }, touch = "LGT", context = "play" },
	-- Tarkov: Ctrl+T switches a tactical device's mode (light, laser, both on a combo). Gamepad: hold D-right while
	-- aiming. Touch: hold LGT. (Both in the Weapon controller's Light handler.)
	DeviceMode = { keys = { K.T }, mod = "Ctrl", pad = {}, context = "play" },
	-- Tarkov: N flips the goggles (or a face shield) up and down. Gamepad: hold D-left (a tap cycles weapons).
	ToggleNVG = { keys = { K.N }, pad = { K.DPadLeft }, touch = "NV", context = "play" },
	-- Tarkov: Alt + right mouse changes a sight's mode (a variable scope's magnification)
	SightMode = { keys = { K.MouseRightButton }, mod = "Alt", pad = {}, context = "play" },
	-- Tarkov: Page Up / Page Down set the sight's zeroing distance
	ZeroUp = { keys = { K.PageUp }, pad = {}, context = "play" },
	ZeroDown = { keys = { K.PageDown }, pad = {}, context = "play" },
	InspectWeapon = { keys = { K.L }, pad = {}, context = "play" },
	LeanLeft = { keys = { K.Q }, pad = { K.ButtonL1 }, touch = "LN-L", context = "play" },
	LeanRight = { keys = { K.E }, pad = { K.ButtonR1 }, touch = "LN-R", context = "play" },
	Prone = { keys = { K.X }, pad = {}, touch = "PRN", context = "play" },
	FreeLook = { keys = { K.LeftAlt }, pad = {}, context = "play" },
	-- G: hold to pull the pin, release to throw (hold aim for underhand). Gamepad: hold D-down (a tap is Extracts).
	Grenade = { keys = { K.G }, pad = { K.DPadDown }, touch = "NADE", context = "play" },
	-- stationary guns (Stationary controller): while mounted these replace the personal-weapon actions (context "mount").
	-- Fire and zoom follow the player's Fire and Aim keys (`like`); F leaves, Tarkov's interact key, since the game has no
	-- documented control for its stationary weapons
	MountFire = { like = "Fire", keys = { K.MouseLeftButton }, pad = { K.ButtonR2 }, touch = "FIRE", context = "mount" },
	MountZoom = { like = "Aim", keys = { K.MouseRightButton }, pad = { K.ButtonL2 }, touch = "ZOOM", context = "mount" },
	MountLeave = { keys = { K.F }, pad = { K.ButtonB }, touch = "LEAVE", context = "mount" },
	-- Tarkov's quick slots: hover an item in your pockets or rig in the inventory and press the key to bind it;
	-- in a raid the key uses it (meds, food) or readies it (grenades). Global, so binding works with the inventory open.
	Quick4 = { keys = { K.Four }, pad = {}, context = "global" },
	Quick5 = { keys = { K.Five }, pad = {}, context = "global" },
	Quick6 = { keys = { K.Six }, pad = {}, context = "global" },
	Quick7 = { keys = { K.Seven }, pad = {}, context = "global" },
	Quick8 = { keys = { K.Eight }, pad = {}, context = "global" },
	Quick9 = { keys = { K.Nine }, pad = {}, context = "global" },
	Quick0 = { keys = { K.Zero }, pad = {}, context = "global" },
}

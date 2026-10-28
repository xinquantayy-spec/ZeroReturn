--!strict
-- Single source of truth for action bindings (PC keys, gamepad, touch label). Movement/jump/look stay
-- with Roblox's PlayerModule + our camera. Interact uses ProximityPrompts (F / ButtonX / tap); Q/E lean (Tarkov).
return {
	Fire = { keys = { Enum.KeyCode.MouseLeftButton }, pad = { Enum.KeyCode.ButtonR2 }, touch = "FIRE", context = "play" },
	Aim = { keys = { Enum.KeyCode.MouseRightButton }, pad = { Enum.KeyCode.ButtonL2 }, touch = "ADS", context = "play" },
	Reload = { keys = { Enum.KeyCode.R }, pad = { Enum.KeyCode.ButtonX }, touch = "RLD", context = "play" },
	Sprint = { keys = { Enum.KeyCode.LeftShift }, pad = { Enum.KeyCode.ButtonL3 }, touch = "RUN", context = "play" },
	Crouch = { keys = { Enum.KeyCode.C, Enum.KeyCode.LeftControl }, pad = { Enum.KeyCode.ButtonB }, touch = "CRCH", context = "play" },
	Heal = { keys = { Enum.KeyCode.H }, pad = { Enum.KeyCode.DPadUp }, touch = "MED", context = "play" },
	FireMode = { keys = { Enum.KeyCode.V }, pad = { Enum.KeyCode.DPadRight }, context = "play" },
	Extracts = { keys = { Enum.KeyCode.O }, pad = { Enum.KeyCode.DPadDown }, touch = "EXIT", context = "play" },
	Inventory = { keys = { Enum.KeyCode.Tab, Enum.KeyCode.I }, pad = { Enum.KeyCode.ButtonY }, touch = "BAG", context = "global" },
	Settings = { keys = { Enum.KeyCode.P }, pad = { Enum.KeyCode.ButtonSelect }, touch = "SET", context = "global" },
	Back = { keys = { Enum.KeyCode.Backspace }, pad = { Enum.KeyCode.ButtonB }, context = "menu" },
	Primary = { keys = { Enum.KeyCode.One }, pad = {}, context = "play" },
	Secondary = { keys = { Enum.KeyCode.Two }, pad = {}, context = "play" },
	Sidearm = { keys = { Enum.KeyCode.Three }, pad = {}, context = "play" },
	Knife = { keys = { Enum.KeyCode.Four }, pad = {}, context = "play" },
	CycleWeapon = { keys = {}, pad = { Enum.KeyCode.DPadLeft }, touch = "SWAP", context = "play" },
	MagCheck = { keys = { Enum.KeyCode.T }, pad = { Enum.KeyCode.ButtonR3 }, context = "play" },
	Light = { keys = { Enum.KeyCode.L }, pad = {}, context = "play" },
	LeanLeft = { keys = { Enum.KeyCode.Q }, pad = { Enum.KeyCode.ButtonL1 }, touch = "LN-L", context = "play" },
	LeanRight = { keys = { Enum.KeyCode.E }, pad = { Enum.KeyCode.ButtonR1 }, touch = "LN-R", context = "play" },
	Prone = { keys = { Enum.KeyCode.Z }, pad = {}, touch = "PRN", context = "play" },
	FreeLook = { keys = { Enum.KeyCode.LeftAlt }, pad = {}, context = "play" },
}

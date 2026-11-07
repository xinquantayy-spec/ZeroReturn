--!nonstrict
-- UI checks that run on the server (audit ui.5, ui.9, ui.14): the menu bindings in the shared input map. The screens
-- themselves are client UI and are checked in Studio by the coordinator. Run with the other test modules (ZR_Dev "tests").
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local InputMap = require(Shared.InputMap)

local T = {}

function T.run(_ctx)
	local passed, failed, notes = 0, 0, {}
	local function check(name, cond)
		if cond then
			passed += 1
		else
			failed += 1
			table.insert(notes, "FAIL " .. name)
		end
	end

	-- ui.5: in a menu LB and RB step through the open screen's tabs (the console convention; Tarkov has no gamepad)
	local prev, nxt = InputMap.TabPrev, InputMap.TabNext
	check("input map: TabPrev is LB and TabNext is RB, in menus only",
		prev ~= nil and nxt ~= nil and prev.context == "menu" and nxt.context == "menu"
		and prev.pad[1] == Enum.KeyCode.ButtonL1 and nxt.pad[1] == Enum.KeyCode.ButtonR1)
	check("input map: the tab buttons take no PC key (a mouse clicks the tabs)", #prev.keys == 0 and #nxt.keys == 0)
	check("input map: on foot LB and RB still lean (the play context is off while a menu is open)",
		InputMap.LeanLeft.pad[1] == Enum.KeyCode.ButtonL1 and InputMap.LeanLeft.context == "play"
		and InputMap.LeanRight.pad[1] == Enum.KeyCode.ButtonR1 and InputMap.LeanRight.context == "play")
	-- no two actions that can fire in a menu (menu and global contexts) share a gamepad button: Back is B, the tabs LB / RB,
	-- the inventory Y, the settings View
	local seen, clash = {}, nil
	for action, spec in InputMap do
		if spec.context == "menu" or spec.context == "global" then
			for _, k in spec.pad or {} do
				if seen[k] then
					clash = seen[k] .. " and " .. action .. " on " .. k.Name
				end
				seen[k] = action
			end
		end
	end
	check("input map: one action per gamepad button in menus" .. (clash and (" (" .. clash .. ")") or ""), clash == nil)

	local summary = string.format("%d passed, %d failed", passed, failed)
	if #notes > 0 then
		summary ..= " :: " .. table.concat(notes, "; ")
	end
	return summary
end

return T

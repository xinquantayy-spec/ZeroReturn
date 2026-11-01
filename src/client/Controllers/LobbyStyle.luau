--!nonstrict
-- Hideout style (Tarkov 0.16 customisation; shared/HideoutStyle.luau, docs/design/HIDEOUT_STYLE.md): this player's walls,
-- floor and ceiling, painted on Relay 7's shell on this client only (everyone else sees their own choice). The shell
-- (ZR_World.Relay7.Shell): walls in three cuts (WallPaint, the olive band; WallLine; Wall, the upper paint), the Floor
-- slab and the Ceiling_<room> slabs. The first option of each category is the shell as built.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local HS = require(Shared.HideoutStyle)

local LobbyStyle = {}
local ctx
local orig = {} -- [part] = { Material, MaterialVariant, Color } as built
local shown = {} -- [cat] = option id painted now
local CUT = { WallPaint = "band", WallLine = "line", Wall = "upper" }

local function shellModel()
	local w = workspace:FindFirstChild("ZR_World")
	local r = w and w:FindFirstChild("Relay7")
	return r and r:FindFirstChild("Shell")
end

local function paint(p, fin)
	local o = orig[p]
	if not o then
		o = { p.Material, p.MaterialVariant, p.Color }
		orig[p] = o
	end
	if fin then
		p.Material = Enum.Material[fin.mat] or o[1]
		p.MaterialVariant = fin.var or ""
		p.Color = Color3.fromHex(fin.color)
	else
		p.Material, p.MaterialVariant, p.Color = o[1], o[2], o[3]
	end
end

-- paint one category on every shell part it covers (parts that are not streamed in yet get it when they come)
local function apply(sh, cat, o)
	for _, p in sh:GetChildren() do
		if p:IsA("BasePart") then
			if cat == "walls" and CUT[p.Name] then
				paint(p, o[CUT[p.Name]])
			elseif cat == "floor" and p.Name == "Floor" then
				paint(p, o.surface)
			elseif cat == "ceiling" and p:GetAttribute("Ceiling") then
				paint(p, o.surface)
			end
		end
	end
end

function LobbyStyle.refresh(force)
	local sh = shellModel()
	if not sh then
		return
	end
	local d = ctx.State.data
	local mine = (d and d.hideout and d.hideout.style) or nil
	if not mine and not force then
		return -- in a raid the hideout state is not sent: keep what is painted
	end
	for _, cat in HS.CATS do
		local id = (mine and mine[cat]) or HS.default(cat)
		local o = HS.option(cat, id) or HS.option(cat, HS.default(cat))
		if force or shown[cat] ~= o.id then
			shown[cat] = o.id
			apply(sh, cat, o)
		end
	end
end

function LobbyStyle.init(c)
	ctx = c
	c.State.changed:Connect(function()
		LobbyStyle.refresh(false)
	end)
	-- the shell streams in after the client starts, and its parts can come and go: repaint whatever arrives
	task.spawn(function()
		local sh
		while not sh do
			sh = shellModel()
			if not sh then
				task.wait(1)
			end
		end
		sh.ChildAdded:Connect(function()
			task.defer(LobbyStyle.refresh, true)
		end)
		LobbyStyle.refresh(true)
	end)
end

return LobbyStyle

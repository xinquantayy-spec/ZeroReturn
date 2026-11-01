--!nonstrict
-- Zero Return server bootstrap. Explicit startup order; services share one ctx table.
local Services = script.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local ctx = {}
for _, name in { "Remotes", "Store", "Profiles", "Inv", "Settle", "Assets", "World", "DetailPlan", "Health", "Chars", "Appearance", "Loot", "Combat", "Grenades", "Extract", "AI", "Raid", "Match", "Economy", "Quests", "Hideout", "Flea", "Guard", "Hazards", "Stationary", "Doors", "Lobby", "Range", "Dev" } do
	ctx[name] = require(Services:WaitForChild(name))
end
-- breakable glass (docs/design/GLASS.md) is optional: a fault in it is logged and the game boots without it (every use of ctx.Glass
-- checks for it first)
do
	local okGlass, Glass = pcall(require, Services:WaitForChild("Glass"))
	if okGlass then
		ctx.Glass = Glass
	else
		warn("[ZR] Glass failed to load, panes will not break:", Glass)
	end
end
-- tripwires (Services/Tripwires.luau, THE FORESTER's traps) are optional too: without them he roams with none
do
	local okTw, Tripwires = pcall(require, Services:WaitForChild("Tripwires"))
	if okTw then
		ctx.Tripwires = Tripwires
	else
		warn("[ZR] Tripwires failed to load, no traps this server:", Tripwires)
	end
end
-- airdrops (Services/Airdrop.luau) are optional too: a fault is logged and the raid runs without the plane
do
	local okAir, Airdrop = pcall(require, Services:WaitForChild("Airdrop"))
	if okAir then
		ctx.Airdrop = Airdrop
	else
		warn("[ZR] Airdrop failed to load, no planes this server:", Airdrop)
	end
end

ctx.Remotes.init(ctx)
ctx.Store.init(ctx)
ctx.Profiles.init(ctx)
ctx.Assets.init(ctx)
ctx.World.build()
-- M12: the cosmetic detail plan reads the finished map once (walls, openings, floors) and publishes it for the
-- clients' detail layer; it yields while it works, so the rest of the server starts in the meantime
task.spawn(function()
	-- the maps and the lobby bunker's shell (decals only there; its cells are published with every map)
	local models = ctx.World.mapModels()
	local sh = ctx.World.safehouse
	if sh and sh.shell then
		table.insert(models, sh.shell)
		ctx.DetailPlan.always = { { x0 = sh.lo.X, z0 = sh.lo.Z, x1 = sh.hi.X, z1 = sh.hi.Z } }
	end
	local ok, err = pcall(ctx.DetailPlan.generate, models, 1207, ctx.World.detailAvoid(), ctx.World.natureRegions)
	if not ok then
		warn("[ZR] detail plan failed:", err)
		return
	end
	-- clients only get the detail of the map in play (published again on every activation)
	local function publish(_, m)
		local n = ctx.DetailPlan.publish(m and m.bounds)
		print(string.format("[ZR] detail plan published for %s: %d entries", tostring(ctx.World.activeMap), n))
	end
	ctx.World.onActivate = publish
	publish(ctx.World.activeMap, ctx.World.maps[ctx.World.activeMap])
end)
for _, name in { "Health", "Chars", "Appearance", "Loot", "Combat", "Grenades", "Extract", "AI", "Raid", "Match", "Economy", "Quests", "Hideout", "Flea", "Guard", "Hazards", "Stationary", "Doors", "Lobby", "Range", "Dev" } do
	ctx[name].init(ctx)
end
if ctx.Airdrop then
	ctx.Airdrop.init(ctx)
end
if ctx.Glass then
	local okInit, errInit = pcall(ctx.Glass.init, ctx)
	if not okInit then
		warn("[ZR] Glass init failed, panes will not break:", errInit)
	end
end
-- after Glass: the wires' shot check wraps the panes' (Ballistics.through)
if ctx.Tripwires then
	local okTw, errTw = pcall(ctx.Tripwires.init, ctx)
	if not okTw then
		warn("[ZR] Tripwires init failed:", errTw)
		ctx.Tripwires = nil
	end
end
ctx.Remotes.open()
ctx.Profiles.start()
ctx.Health.start()
ctx.Extract.start()
ctx.Raid.start()
ctx.Match.start()
ctx.Economy.start()
ctx.Quests.start()
ctx.Hideout.start()
ctx.Flea.start()
ctx.Guard.start()
ctx.Hazards.start()
ctx.Stationary.start()
ctx.Lobby.start()
ctx.Range.start()
if ctx.Airdrop then
	ctx.Airdrop.start()
end
print("[ZR] server ready", Config.BUILD, "persistence:", ctx.Store.mode)

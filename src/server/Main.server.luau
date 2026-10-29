--!nonstrict
-- Zero Return server bootstrap. Explicit startup order; services share one ctx table.
local Services = script.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local ctx = {}
for _, name in { "Remotes", "Store", "Profiles", "Inv", "Settle", "Assets", "World", "DetailPlan", "Health", "Chars", "Appearance", "Loot", "Combat", "Grenades", "Extract", "AI", "Raid", "Match", "Economy", "Quests", "Hideout", "Doors", "Dev" } do
	ctx[name] = require(Services:WaitForChild(name))
end

ctx.Remotes.init(ctx)
ctx.Store.init(ctx)
ctx.Profiles.init(ctx)
ctx.Assets.init(ctx)
ctx.World.build()
-- M12: the cosmetic detail plan reads the finished map once (walls, openings, floors) and publishes it for the
-- clients' detail layer; it yields while it works, so the rest of the server starts in the meantime
task.spawn(function()
	local ok, err = pcall(ctx.DetailPlan.generate, ctx.World.mapModels(), 1207, ctx.World.detailAvoid(), ctx.World.natureRegions)
	if not ok then
		warn("[ZR] detail plan failed:", err)
	end
end)
for _, name in { "Health", "Chars", "Appearance", "Loot", "Combat", "Grenades", "Extract", "AI", "Raid", "Match", "Economy", "Quests", "Hideout", "Doors", "Dev" } do
	ctx[name].init(ctx)
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
print("[ZR] server ready", Config.BUILD, "persistence:", ctx.Store.mode)

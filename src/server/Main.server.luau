--!nonstrict
-- Zero Return server bootstrap. Explicit startup order; services share one ctx table.
local Services = script.Parent:WaitForChild("Services")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZR")
local Config = require(Shared.Config)

local ctx = {}
for _, name in { "Remotes", "Store", "Profiles", "Inv", "Settle", "Assets", "World", "Health", "Chars", "Loot", "Combat", "Extract", "AI", "Raid", "Dev" } do
	ctx[name] = require(Services:WaitForChild(name))
end

ctx.Remotes.init(ctx)
ctx.Store.init(ctx)
ctx.Profiles.init(ctx)
ctx.Assets.init(ctx)
ctx.World.build()
for _, name in { "Health", "Chars", "Loot", "Combat", "Extract", "AI", "Raid", "Dev" } do
	ctx[name].init(ctx)
end
ctx.Remotes.open()
ctx.Profiles.start()
ctx.Health.start()
ctx.Extract.start()
ctx.Raid.start()
print("[ZR] server ready", Config.BUILD, "persistence:", ctx.Store.mode)

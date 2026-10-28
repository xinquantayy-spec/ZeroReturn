-- Escape From Bloxov client entry (Rojo sync smoke test; replaced by the real bootstrap)
local Version = require(game:GetService("ReplicatedStorage"):WaitForChild("EFB"):WaitForChild("Version"))
print("[EFB] ROJO_SMOKE client", Version.name, Version.build, game:GetService("Players").LocalPlayer.Name)

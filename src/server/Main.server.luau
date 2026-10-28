-- Escape From Bloxov server entry (Rojo sync smoke test; replaced by the real bootstrap)
local Version = require(game:GetService("ReplicatedStorage"):WaitForChild("EFB"):WaitForChild("Version"))
print("[EFB] ROJO_SMOKE server", Version.name, Version.build)

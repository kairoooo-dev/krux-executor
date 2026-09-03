-- local stash sample: sanity ping
local player = game.Players.LocalPlayer
print("[executor] hello " .. (player and player.Name or "?") .. " — VM is alive")
print("[executor] workspace:", game.Workspace and "ok" or "null")
return true
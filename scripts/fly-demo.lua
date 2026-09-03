-- local stash sample: fly toggle (simple, unguarded classic builds only)
local plr = game.Players.LocalPlayer
local hum = plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
if not hum then
    print("[executor] no humanoid yet")
    return false
end

local flying = false
local speed = 50
local BodyVelocity

local function setFly(on)
    flying = on
    if on then
        BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        BodyVelocity.Parent = hum.Parent
    elseif BodyVelocity then
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
end

game:GetService("RunService").Heartbeat:Connect(function()
    if not flying or not BodyVelocity then return end
    local cam = workspace.CurrentCamera
    BodyVelocity.Velocity = speed * cam.CFrame.LookVector
end)

setFly(not flying)
print("[executor] fly " .. (flying and "ON" or "OFF"))
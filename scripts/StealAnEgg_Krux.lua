-- Steal An Egg – Krux v8.1
-- Rayfield UI | Fixed + Anticheat Bypass

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- ===== ANTICHEAT BYPASS (metatable hooks) =====
do
    local success, err = pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, idx)
            if self:IsA("Humanoid") and (idx == "WalkSpeed" or idx == "JumpPower") then
                if not checkcaller() then
                    return 16
                end
            end
            return oldIndex(self, idx)
        end))

        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, idx, val)
            if self:IsA("Humanoid") and (idx == "WalkSpeed" or idx == "JumpPower") then
                if checkcaller() then
                    return oldNewIndex(self, idx, val)
                end
            end
            return oldNewIndex(self, idx, val)
        end))

        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "GetPropertyChangedSignal" then
                local prop = ...
                if self:IsA("Humanoid") and (prop == "WalkSpeed" or prop == "JumpPower") then
                    return oldNamecall(self, ...)
                end
            end
            return oldNamecall(self, ...)
        end))
    end)
    if success then
        print("[KRUX] Metamethod hooks installed")
    else
        warn("[KRUX] Hook failed (executor may not support): " .. tostring(err))
    end
end

-- ===== LOAD RAYFIELD =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

if not Rayfield then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "KRUX",
            Text = "Rayfield failed to load",
            Duration = 3,
        })
    end)
    return
end

-- ===== SETTINGS =====
local Settings = {
    AutoCollect = true,
    SpeedBypass = true,
    AntiRagdoll = true,
    AntiTrap = true,
    AutoPlace = true,
    AutoHatch = true,
    ESP = true,
    KillAura = false,
    SpeedMultiplier = 4,
    CollectRange = 40,
    SelectedEgg = 1,
    SelectedPet = 1,
    _speedApplied = false,
}

-- ===== ALL EGGS =====
local Eggs = {
    "Chicken Egg", "Dog Egg", "Owl Egg", "Brr Brr Patapim Egg",
    "Frog Egg", "Trulimero Trulicina Egg", "Swan Egg",
    "Jerboa Egg", "Sand Spider Egg",
    "Toucan Egg", "Gorilla Egg", "Spider Egg",
    "Walrus Egg", "Polar Bear Egg", "Mammoth Egg", "King Mammoth Egg",
    "Lava Frog Egg", "Flaming Bull Egg", "Cerberus Egg",
    "Parrotfish Egg", "Shark Egg", "Beluga Whale Egg",
    "Ankylosaurus Egg", "Bronto Egg",
    "Cosmic Gecko Egg",
    "Eternal Oni Tiger Egg",
}

local Pets = {
    "Chicken", "Dog", "Owl", "Brr Brr Patapim",
    "Frog", "Trulimero Trulicina", "Swan",
    "Jerboa", "Sand Spider",
    "Toucan", "Gorilla", "Spider",
    "Walrus", "Polar Bear", "Mammoth", "King Mammoth",
    "Lava Frog", "Flaming Bull", "Cerberus",
    "Parrotfish", "Shark", "Beluga Whale",
    "Ankylosaurus", "Bronto",
    "Cosmic Gecko",
    "Eternal Oni Tiger",
}

-- ===== RAYFIELD UI =====
local Window = Rayfield:CreateWindow({
    Name = "KRUX v8.1",
    Icon = 0,
    LoadingTitle = "Krux Ultimate",
    LoadingSubtitle = "Steal An Egg | v8.1",
    Theme = "Dark",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "KruxHub",
        FileName = "StealAnEgg"
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ===== MAIN TAB =====
local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Auto Farm")

MainTab:CreateToggle({
    Name = "Auto Collect",
    CurrentValue = Settings.AutoCollect,
    Flag = "AutoCollect",
    Callback = function(v) Settings.AutoCollect = v end,
})

MainTab:CreateSlider({
    Name = "Collect Range",
    Range = {10, 80},
    Increment = 5,
    Suffix = "Studs",
    CurrentValue = Settings.CollectRange,
    Flag = "CollectRange",
    Callback = function(v) Settings.CollectRange = v end,
})

MainTab:CreateToggle({
    Name = "Auto Place",
    CurrentValue = Settings.AutoPlace,
    Flag = "AutoPlace",
    Callback = function(v) Settings.AutoPlace = v end,
})

MainTab:CreateToggle({
    Name = "Auto Hatch",
    CurrentValue = Settings.AutoHatch,
    Flag = "AutoHatch",
    Callback = function(v) Settings.AutoHatch = v end,
})

-- ===== COMBAT TAB =====
local CombatTab = Window:CreateTab("Combat", 4483362459)
CombatTab:CreateSection("Movement")

CombatTab:CreateToggle({
    Name = "Speed Bypass",
    CurrentValue = Settings.SpeedBypass,
    Flag = "SpeedBypass",
    Callback = function(v) Settings.SpeedBypass = v end,
})

CombatTab:CreateSlider({
    Name = "Speed Multiplier",
    Range = {1, 8},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = Settings.SpeedMultiplier,
    Flag = "SpeedMultiplier",
    Callback = function(v) Settings.SpeedMultiplier = v end,
})

CombatTab:CreateSection("Protection")

CombatTab:CreateToggle({
    Name = "Anti-Ragdoll",
    CurrentValue = Settings.AntiRagdoll,
    Flag = "AntiRagdoll",
    Callback = function(v) Settings.AntiRagdoll = v end,
})

CombatTab:CreateToggle({
    Name = "Anti-Trap",
    CurrentValue = Settings.AntiTrap,
    Flag = "AntiTrap",
    Callback = function(v) Settings.AntiTrap = v end,
})

CombatTab:CreateToggle({
    Name = "Kill Aura",
    CurrentValue = Settings.KillAura,
    Flag = "KillAura",
    Callback = function(v) Settings.KillAura = v end,
})

-- ===== EGGS TAB =====
local EggsTab = Window:CreateTab("Eggs", 4483362460)
EggsTab:CreateSection("Egg Finder")

EggsTab:CreateToggle({
    Name = "ESP",
    CurrentValue = Settings.ESP,
    Flag = "ESP",
    Callback = function(v) Settings.ESP = v end,
})

EggsTab:CreateSection("Egg Spawner")

EggsTab:CreateDropdown({
    Name = "Select Egg",
    Options = Eggs,
    CurrentOption = Eggs[Settings.SelectedEgg],
    Flag = "EggSelector",
    Callback = function(option)
        for i, name in ipairs(Eggs) do
            if name == option then Settings.SelectedEgg = i; break end
        end
    end,
})

EggsTab:CreateButton({
    Name = "Spawn Egg",
    Callback = function()
        Settings.SpawnEgg = true
        task.delay(0.5, function() Settings.SpawnEgg = false end)
    end,
})

EggsTab:CreateSection("Pet Spawner")

EggsTab:CreateDropdown({
    Name = "Select Pet",
    Options = Pets,
    CurrentOption = Pets[Settings.SelectedPet],
    Flag = "PetSelector",
    Callback = function(option)
        for i, name in ipairs(Pets) do
            if name == option then Settings.SelectedPet = i; break end
        end
    end,
})

EggsTab:CreateButton({
    Name = "Spawn Pet",
    Callback = function()
        Settings.SpawnPet = true
        task.delay(0.5, function() Settings.SpawnPet = false end)
    end,
})

Rayfield:LoadConfiguration()

-- ============================================================
-- ===== CORE FEATURES =====
-- ============================================================

-- ===== SPEED BYPASS (set on spawn, not every frame) =====
local function applySpeed(char)
    if not Settings.SpeedBypass then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    task.delay(0.3, function()
        if Settings.SpeedBypass then
            hum.WalkSpeed = 16 * Settings.SpeedMultiplier
            hum.JumpPower = 50 * Settings.SpeedMultiplier
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(applySpeed)
if LocalPlayer.Character then task.spawn(applySpeed, LocalPlayer.Character) end

-- ===== ANTI-RAGDOLL =====
RunService.Heartbeat:Connect(function()
    if not Settings.AntiRagdoll then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    pcall(function()
        if hum.PlatformStand then hum.PlatformStand = false end
        if hum.Sit then hum.Sit = false end
        hum.AutoRotate = true
    end)
end)

-- ===== ANTI-TRAP =====
RunService.Heartbeat:Connect(function()
    if not Settings.AntiTrap then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if hrp.Position.Y < -5 then
        pcall(function()
            hrp.Velocity = Vector3.new(0, 50, 0)
            hrp.CFrame = CFrame.new(hrp.Position.X, 10, hrp.Position.Z)
        end)
    end
end)

-- ===== ESP (debounced — only updates every 2s) =====
local espObjects = {}
local espCache = {}
local espLastUpdate = 0

local function updateESP()
    if not Settings.ESP then
        for obj, h in pairs(espObjects) do
            pcall(function() h:Destroy() end)
        end
        espObjects = {}
        espCache = {}
        return
    end

    local now = tick()
    if now - espLastUpdate < 2 then return end
    espLastUpdate = now

    local found = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("egg") or n:find("nest") then
                found[obj] = true
                if not espObjects[obj] then
                    local h = Instance.new("Highlight")
                    h.FillColor = Color3.fromRGB(0, 255, 200)
                    h.FillTransparency = 0.35
                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                    h.OutlineTransparency = 0.2
                    h.Adornee = obj
                    h.Parent = obj
                    espObjects[obj] = h
                end
            end
        end
    end

    for obj, h in pairs(espObjects) do
        if not found[obj] or not obj.Parent then
            pcall(function() h:Destroy() end)
            espObjects[obj] = nil
        end
    end
end

RunService.Heartbeat:Connect(updateESP)

-- ===== REMOTE HELPERS (cached, not spammy) =====
local cachedRemotes = nil
local remoteCacheTime = 0

local function getRemotes()
    local now = tick()
    if cachedRemotes and now - remoteCacheTime < 5 then
        return cachedRemotes
    end
    cachedRemotes = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            table.insert(cachedRemotes, obj)
        end
    end
    remoteCacheTime = now
    return cachedRemotes
end

local function fireIfMatch(patterns, ...)
    for _, remote in ipairs(getRemotes()) do
        local n = remote.Name:lower()
        for _, pat in ipairs(patterns) do
            if n:find(pat) then
                pcall(function() remote:FireServer(...) end)
                break
            end
        end
    end
end

-- ===== FIND EGGS / PLOTS =====
local function findEggs()
    local eggs = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("egg") or n:find("nest") then
                table.insert(eggs, obj)
            end
        end
    end
    return eggs
end

local function findPlots()
    local plots = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local n = obj.Name:lower()
            if n:find("plot") or n:find("base") then
                table.insert(plots, obj)
            end
        end
    end
    return plots
end

-- ===== AUTO COLLECT (with random jitter) =====
local function autoCollect()
    if not Settings.AutoCollect then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, egg in ipairs(findEggs()) do
        local pos
        pcall(function()
            pos = egg:IsA("BasePart") and egg.Position or egg:GetPivot().Position
        end)
        if pos and (hrp.Position - pos).Magnitude <= Settings.CollectRange then
            pcall(function()
                if egg:FindFirstChild("ClickDetector") then
                    egg.ClickDetector:Click()
                end
            end)
            fireIfMatch({"collect", "steal", "grab", "pickup"}, egg)
            task.wait(0.15 + math.random() * 0.1)
        end
    end
end

-- ===== AUTO PLACE =====
local function autoPlace()
    if not Settings.AutoPlace then return end
    for _, plot in ipairs(findPlots()) do
        fireIfMatch({"place"}, plot)
        task.wait(0.2 + math.random() * 0.1)
    end
end

-- ===== AUTO HATCH =====
local function autoHatch()
    if not Settings.AutoHatch then return end
    fireIfMatch({"hatch", "open", "crack"})
end

-- ===== SPAWN EGG =====
local function spawnEgg()
    if not Settings.SpawnEgg then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local eggName = Eggs[Settings.SelectedEgg]
    fireIfMatch({"spawn", "egg", "add", "give"}, eggName)
    fireIfMatch({"spawn", "egg", "add", "give"}, "egg", eggName)

    local egg = Instance.new("Part")
    egg.Size = Vector3.new(2, 2, 2)
    egg.Shape = Enum.PartType.Ball
    egg.BrickColor = BrickColor.new("Bright yellow")
    egg.Material = Enum.Material.Neon
    egg.CFrame = hrp.CFrame * CFrame.new(0, 3, 5)
    egg.Name = eggName
    egg.Parent = workspace

    local click = Instance.new("ClickDetector")
    click.Parent = egg

    click.MouseClick:Connect(function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = eggName .. " Collected!",
                Duration = 1,
            })
        end)
        fireIfMatch({"collect", "steal", "grab", "pickup"}, egg)
        egg:Destroy()
    end)

    task.delay(10, function()
        if egg and egg.Parent then egg:Destroy() end
    end)
end

-- ===== SPAWN PET =====
local function spawnPet()
    if not Settings.SpawnPet then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local petName = Pets[Settings.SelectedPet]
    fireIfMatch({"pet", "spawn", "add", "give"}, petName)
    fireIfMatch({"pet", "spawn", "add", "give"}, "pet", petName)

    local pet = Instance.new("Model")
    pet.Name = petName
    pet.Parent = workspace

    local body = Instance.new("Part")
    body.Size = Vector3.new(2, 2, 2)
    body.Shape = Enum.PartType.Ball
    body.BrickColor = BrickColor.new("Bright blue")
    body.Material = Enum.Material.Neon
    body.CFrame = hrp.CFrame * CFrame.new(0, 0, 5)
    body.Parent = pet

    local head = Instance.new("Part")
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Shape = Enum.PartType.Ball
    head.BrickColor = BrickColor.new("Bright yellow")
    head.Material = Enum.Material.Neon
    head.CFrame = body.CFrame * CFrame.new(0, 1.5, 0)
    head.Parent = pet

    local highlight = Instance.new("Highlight")
    highlight.Adornee = pet
    highlight.FillColor = Color3.fromRGB(100, 200, 255)
    highlight.FillTransparency = 0.2
    highlight.Parent = pet

    task.delay(8, function()
        if pet and pet.Parent then pet:Destroy() end
    end)
end

-- ===== KILL AURA (throttled, random delay) =====
local killAuraLastTick = 0
local function killAura()
    if not Settings.KillAura then return end
    local now = tick()
    if now - killAuraLastTick < 0.5 then return end
    killAuraLastTick = now

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local tc = player.Character
            if tc then
                local th = tc:FindFirstChild("HumanoidRootPart")
                local hum = tc:FindFirstChild("Humanoid")
                if th and hum and (hrp.Position - th.Position).Magnitude < 15 then
                    pcall(function() hum.Health = 0 end)
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if Settings.KillAura then killAura() end
end)

-- ===== MAIN LOOP (randomized interval) =====
task.spawn(function()
    while true do
        local delay = 0.8 + math.random() * 0.4
        task.wait(delay)

        pcall(function()
            if Settings.AutoCollect then autoCollect() end
            if Settings.AutoPlace then autoPlace() end
            if Settings.AutoHatch then autoHatch() end
            if Settings.SpawnEgg then spawnEgg() end
            if Settings.SpawnPet then spawnPet() end
        end)
    end
end)

-- ===== DONE =====
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "KRUX v8.1",
        Text = "Loaded | Anticheat hooks active",
        Duration = 2,
    })
end)
print("[KRUX v8.1] Loaded. Metamethod hooks active. All features online.")

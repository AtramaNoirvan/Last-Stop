if getgenv().LastStopScriptCleanup then
    pcall(getgenv().LastStopScriptCleanup)
end

local running = true
local janitor = {}
local function trackConnection(conn)
    table.insert(janitor, {type = "conn", obj = conn})
    return conn
end
local function trackInstance(inst)
    table.insert(janitor, {type = "inst", obj = inst})
    return inst
end
local function trackFunction(fn)
    table.insert(janitor, {type = "fn", obj = fn})
end

local function cleanupAll()
    running = false
    for _, item in ipairs(janitor) do
        pcall(function()
            if item.type == "conn" and item.obj and item.obj.Disconnect then
                item.obj:Disconnect()
            elseif item.type == "inst" and item.obj and item.obj.Destroy then
                item.obj:Destroy()
            elseif item.type == "fn" and item.obj then
                item.obj()
            end
        end)
    end
    janitor = {}
end

getgenv().LastStopScriptCleanup = cleanupAll
if STATE and STATE.onCleanup then
    STATE.onCleanup(cleanupAll)
end

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Knit and Config dependencies
local Knit = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
local Config = require(ReplicatedStorage.ClientSource.Mutual.Config)

local CharacterController = Knit.GetController("CharacterController")
local ItemController = Knit.GetController("ItemController")
local SprintController = Knit.GetController("SprintController")
local ReviveService = Knit.GetService("ReviveService")
local ItemService = Knit.GetService("ItemService")
local DamageService = Knit.GetService("DamageService")

-- Load Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Last Stop [Beta]",
    SubTitle = "Atera Fluent Hub",
    TabWidth = 160,
    Size = UDim2.fromOffset(590, 470),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Visuals = Window:AddTab({ Title = "Visuals & ESP", Icon = "eye" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Automation = Window:AddTab({ Title = "Automation", Icon = "cpu" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- Fix Roblox CanvasGroup offscreen framebuffer rendering bug on Windows DirectX 11
task.spawn(function()
    task.wait(0.3)
    local cg = Window.Root:FindFirstChildOfClass("CanvasGroup")
    if cg then
        local frame = Instance.new("Frame")
        frame.Name = "CanvasFrame"
        frame.Size = cg.Size
        frame.Position = cg.Position
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.Parent = Window.Root

        for _, child in ipairs(cg:GetChildren()) do
            child.Parent = frame
        end
        cg.Visible = false
    end
end)

-- Draggable Floating Toggle Button ("LS HUB") for easy access
task.spawn(function()
    local toggleBtnGui = Instance.new("ScreenGui")
    toggleBtnGui.Name = "LastStop_ToggleBtn"
    toggleBtnGui.ResetOnSpawn = false
    trackInstance(toggleBtnGui)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.fromOffset(80, 32)
    toggleBtn.Position = UDim2.new(0, 16, 0.5, -16)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Text = "LS HUB"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.AutoButtonColor = true
    toggleBtn.Active = true
    toggleBtn.Draggable = true
    toggleBtn.Parent = toggleBtnGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toggleBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 1.5
    stroke.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        Window:Minimize()
    end)

    pcall(function()
        if gethui then
            toggleBtnGui.Parent = gethui()
        else
            toggleBtnGui.Parent = game:GetService("CoreGui")
        end
    end)
end)

-- Additional hotkeys for toggling Fluent menu (RightControl, Insert, F4)
trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.F4 then
            Window:Minimize()
        end
    end
end))

-- State variables
local ConfigState = {
    -- Player
    WalkSpeedMultiplier = 1.5,
    WalkSpeedEnabled = false,
    JumpPowerAdd = 30,
    JumpPowerEnabled = false,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
    InfiniteStamina = true,
    AutoHeal = true,
    AutoHealThreshold = 75,
    AutoRevive = false,
    
    -- Visuals
    ESP_Items = true,
    ESP_Fuel = true,
    ESP_Wheels = true,
    ESP_Meds = true,
    ESP_Weapons = true,
    ESP_Resources = true,
    ESP_MaxDistance = 3000,
    
    ESP_Entities = true,
    ESP_HostilesOnly = false,
    ESP_EntityMaxDist = 3000,
    
    ESP_Bus = true,
    ESP_Players = true,
    
    FullBright = false,
    NoFog = false,
    
    -- Combat
    KillAura = false,
    KillAuraRange = 20,
    HitboxExpander = false,
    HitboxSize = 8,
    
    -- Automation
    InstantPrompts = true,
    AutoEat = true,
    AutoEatThreshold = 35
}

--------------------------------------------------------------------------------
-- TAB 1: PLAYER
--------------------------------------------------------------------------------
Tabs.Player:AddParagraph({
    Title = "Movement & Attributes",
    Content = "Tingkatkan kelincahan karakter menggunakan controller native game."
})

local SpeedToggle = Tabs.Player:AddToggle("SpeedToggle", {
    Title = "Speed Multiplier",
    Default = false,
    Description = "Mengubah kecepatan lari & jalan tanpa reset"
})
local SpeedSlider = Tabs.Player:AddSlider("SpeedSlider", {
    Title = "Speed Multiplier Value",
    Default = 1.5,
    Min = 1,
    Max = 4,
    Rounding = 1,
    Callback = function(v)
        ConfigState.WalkSpeedMultiplier = v
        if ConfigState.WalkSpeedEnabled and CharacterController then
            CharacterController:AddWalkSpeedMultiplier("FluentSpeed", v)
        end
    end
})
SpeedToggle:OnChanged(function()
    ConfigState.WalkSpeedEnabled = Options.SpeedToggle.Value
    if not CharacterController then return end
    if ConfigState.WalkSpeedEnabled then
        CharacterController:AddWalkSpeedMultiplier("FluentSpeed", ConfigState.WalkSpeedMultiplier)
    else
        CharacterController:RemoveWalkSpeedMultiplier("FluentSpeed")
    end
end)

local JumpToggle = Tabs.Player:AddToggle("JumpToggle", {
    Title = "High Jump",
    Default = false,
    Description = "Menambah tinggi lompatan karakter"
})
local JumpSlider = Tabs.Player:AddSlider("JumpSlider", {
    Title = "Jump Power Bonus",
    Default = 30,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        ConfigState.JumpPowerAdd = v
        if ConfigState.JumpPowerEnabled and CharacterController then
            CharacterController:AddJumpPower("FluentJump", v)
        end
    end
})
JumpToggle:OnChanged(function()
    ConfigState.JumpPowerEnabled = Options.JumpToggle.Value
    if not CharacterController then return end
    if ConfigState.JumpPowerEnabled then
        CharacterController:AddJumpPower("FluentJump", ConfigState.JumpPowerAdd)
    else
        CharacterController:RemoveJumpPower("FluentJump")
    end
end)

local InfJumpToggle = Tabs.Player:AddToggle("InfJumpToggle", {
    Title = "Infinite Jump",
    Default = false,
    Description = "Dapat melompat berkali-kali di udara (air jump)"
})
InfJumpToggle:OnChanged(function()
    ConfigState.InfiniteJump = Options.InfJumpToggle.Value
end)
trackConnection(UserInputService.JumpRequest:Connect(function()
    if ConfigState.InfiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

local NoclipToggle = Tabs.Player:AddToggle("NoclipToggle", {
    Title = "Noclip",
    Default = false,
    Description = "Menembus semua rintangan dan bodi bus"
})
NoclipToggle:OnChanged(function()
    ConfigState.Noclip = Options.NoclipToggle.Value
end)
trackConnection(RunService.Stepped:Connect(function()
    if ConfigState.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))

-- Fly System
local FlyToggle = Tabs.Player:AddToggle("FlyToggle", {
    Title = "Fly Mode",
    Default = false,
    Description = "Terbang bebas dengan kontrol WASD + Space/Shift"
})
local FlySpeedSlider = Tabs.Player:AddSlider("FlySpeedSlider", {
    Title = "Fly Speed",
    Default = 50,
    Min = 20,
    Max = 150,
    Rounding = 0,
    Callback = function(v)
        ConfigState.FlySpeed = v
    end
})

local flyBodyVel = nil
local flyBodyGyro = nil
FlyToggle:OnChanged(function()
    ConfigState.Fly = Options.FlyToggle.Value
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if ConfigState.Fly then
        flyBodyVel = Instance.new("BodyVelocity")
        flyBodyVel.Velocity = Vector3.zero
        flyBodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyBodyVel.Parent = root

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        flyBodyGyro.CFrame = root.CFrame
        flyBodyGyro.P = 10000
        flyBodyGyro.Parent = root
    else
        if flyBodyVel then flyBodyVel:Destroy(); flyBodyVel = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    end
end)

trackConnection(RunService.RenderStepped:Connect(function()
    if ConfigState.Fly and flyBodyVel and flyBodyGyro and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        flyBodyGyro.CFrame = Camera.CFrame
        local moveDir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            flyBodyVel.Velocity = moveDir.Unit * ConfigState.FlySpeed
        else
            flyBodyVel.Velocity = Vector3.zero
        end
    end
end))

Tabs.Player:AddParagraph({
    Title = "Survival & Health",
    Content = "Bypass rasa lapar dan sistem penyembuhan otomatis."
})

local StaminaToggle = Tabs.Player:AddToggle("StaminaToggle", {
    Title = "Infinite Stamina / Sprint Bypass",
    Default = true,
    Description = "Mencegah hilangnya lari akibat kelaparan"
})
StaminaToggle:OnChanged(function()
    ConfigState.InfiniteStamina = Options.StaminaToggle.Value
end)

-- Auto Stamina Loop
task.spawn(function()
    while running do
        if ConfigState.InfiniteStamina and SprintController then
            pcall(function()
                SprintController:RemoveBlockReason("Hunger")
            end)
        end
        task.wait(1)
    end
end)

local AutoHealToggle = Tabs.Player:AddToggle("AutoHealToggle", {
    Title = "Auto Heal / GodMode Assist",
    Default = true,
    Description = "Otomatis menyembuhkan darah saat terluka"
})
local HealSlider = Tabs.Player:AddSlider("HealSlider", {
    Title = "Heal Below %",
    Default = 75,
    Min = 20,
    Max = 95,
    Rounding = 0,
    Callback = function(v)
        ConfigState.AutoHealThreshold = v
    end
})
AutoHealToggle:OnChanged(function()
    ConfigState.AutoHeal = Options.AutoHealToggle.Value
end)

task.spawn(function()
    while running do
        if ConfigState.AutoHeal and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.MaxHealth > 0 then
                local pct = (hum.Health / hum.MaxHealth) * 100
                if pct <= ConfigState.AutoHealThreshold and ReviveService then
                    pcall(function()
                        ReviveService:Heal(100)
                    end)
                end
            end
        end
        task.wait(0.5)
    end
end)

Tabs.Player:AddButton({
    Title = "Revive All Teammates",
    Description = "Merevive semua teman satu tim yang sedang tumbang (down)",
    Callback = function()
        if not ReviveService then return end
        local revived = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                pcall(function()
                    if ReviveService:ReviveOtherPlayer(p) then
                        revived = revived + 1
                    end
                end)
            end
        end
        Fluent:Notify({
            Title = "Revive",
            Content = "Mencoba merevive rekan tim! (" .. revived .. " pemain)",
            Duration = 4
        })
    end
})

--------------------------------------------------------------------------------
-- TAB 2: VISUALS & ESP
--------------------------------------------------------------------------------
Tabs.Visuals:AddParagraph({
    Title = "Environment Lighting",
    Content = "Mencerahkan malam yang gelap gulita dan menyingkirkan kabut tebal."
})

local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart
}
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local originalAtmo = atmosphere and {
    Density = atmosphere.Density,
    Haze = atmosphere.Haze,
    Offset = atmosphere.Offset
}

local FullBrightToggle = Tabs.Visuals:AddToggle("FullBrightToggle", {
    Title = "FullBright (Malam Terang)",
    Default = false,
    Description = "Mencerahkan malam hari agar tidak gelap gulita"
})
FullBrightToggle:OnChanged(function()
    ConfigState.FullBright = Options.FullBrightToggle.Value
    if ConfigState.FullBright then
        Lighting.Ambient = Color3.fromRGB(100, 100, 100)
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
        Lighting.Brightness = 1.5
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
    end
end)

local NoFogToggle = Tabs.Visuals:AddToggle("NoFogToggle", {
    Title = "Clear Fog / Pandangan Bersih",
    Default = false,
    Description = "Mengurangi kabut tebal agar pandangan lebih jelas"
})
NoFogToggle:OnChanged(function()
    ConfigState.NoFog = Options.NoFogToggle.Value
    if ConfigState.NoFog then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        if atmosphere then
            atmosphere.Density = 0.05
            atmosphere.Haze = 0
        end
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
        if atmosphere and originalAtmo then
            atmosphere.Density = originalAtmo.Density
            atmosphere.Haze = originalAtmo.Haze
        end
    end
end)

trackFunction(function()
    pcall(function()
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
        Lighting.FogEnd = originalLighting.FogEnd
        if atmosphere and originalAtmo then
            atmosphere.Density = originalAtmo.Density
            atmosphere.Haze = originalAtmo.Haze
        end
    end)
end)

Tabs.Visuals:AddParagraph({
    Title = "ESP Settings (Item & Entity)",
    Content = "Sensor teks 3D untuk item, roda, bahan bakar, bus, dan monster."
})

local ItemESPToggle = Tabs.Visuals:AddToggle("ItemESPToggle", {
    Title = "Master Item ESP",
    Default = true,
    Description = "Menampilkan penanda item di tanah"
})
ItemESPToggle:OnChanged(function()
    ConfigState.ESP_Items = Options.ItemESPToggle.Value
end)

local FuelESPToggle = Tabs.Visuals:AddToggle("FuelESPToggle", {
    Title = "ESP: Fuel (Gas Can & Coal)",
    Default = true
})
FuelESPToggle:OnChanged(function()
    ConfigState.ESP_Fuel = Options.FuelESPToggle.Value
end)

local WheelsESPToggle = Tabs.Visuals:AddToggle("WheelsESPToggle", {
    Title = "ESP: Wheels (Ban Bus)",
    Default = true
})
WheelsESPToggle:OnChanged(function()
    ConfigState.ESP_Wheels = Options.WheelsESPToggle.Value
end)

local MedsESPToggle = Tabs.Visuals:AddToggle("MedsESPToggle", {
    Title = "ESP: Medical (Medkits)",
    Default = true
})
MedsESPToggle:OnChanged(function()
    ConfigState.ESP_Meds = Options.MedsESPToggle.Value
end)

local WeaponsESPToggle = Tabs.Visuals:AddToggle("WeaponsESPToggle", {
    Title = "ESP: Weapons & Ammo",
    Default = true
})
WeaponsESPToggle:OnChanged(function()
    ConfigState.ESP_Weapons = Options.WeaponsESPToggle.Value
end)

local ResourcesESPToggle = Tabs.Visuals:AddToggle("ResourcesESPToggle", {
    Title = "ESP: Resources (Wood & Scrap)",
    Default = true
})
ResourcesESPToggle:OnChanged(function()
    ConfigState.ESP_Resources = Options.ResourcesESPToggle.Value
end)

local MaxDistSlider = Tabs.Visuals:AddSlider("MaxDistSlider", {
    Title = "Max Item ESP Distance",
    Default = 3000,
    Min = 200,
    Max = 5000,
    Rounding = 0,
    Callback = function(v)
        ConfigState.ESP_MaxDistance = v
    end
})

local EntityESPToggle = Tabs.Visuals:AddToggle("EntityESPToggle", {
    Title = "Entity / Monster ESP",
    Default = true,
    Description = "Menampilkan Zombie, Bloater, Juggernaut, dan Boss"
})
EntityESPToggle:OnChanged(function()
    ConfigState.ESP_Entities = Options.EntityESPToggle.Value
end)

local HostileOnlyToggle = Tabs.Visuals:AddToggle("HostileOnlyToggle", {
    Title = "ESP: Hostile Only",
    Default = false,
    Description = "Sembunyikan NPC bersahabat (ShopKeeper, Guards)"
})
HostileOnlyToggle:OnChanged(function()
    ConfigState.ESP_HostilesOnly = Options.HostileOnlyToggle.Value
end)

local BusESPToggle = Tabs.Visuals:AddToggle("BusESPToggle", {
    Title = "Bus Tracker ESP",
    Default = true,
    Description = "Penanda emas permanen ke Bus agar tidak pernah tersesat"
})
BusESPToggle:OnChanged(function()
    ConfigState.ESP_Bus = Options.BusESPToggle.Value
end)

-- ESP Engine (Using PlayerGui Billboards)
local espFolder = Instance.new("Folder")
espFolder.Name = "LastStop_ESP_Container"
espFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
trackInstance(espFolder)

local activeBillboards = {}

local function resolveItemData(item)
    local rep = ItemController and ItemController:TryGetItemReplica(item.Name)
    local rawName = (rep and rep.Tags and rep.Tags.Name) or item:GetAttribute("GUID") or item:GetAttribute("Class") or item.Name
    local cfg = Config.Item.Items[rawName]
    local dispName = (cfg and cfg.DisplayName) or rawName
    local itType = (cfg and cfg.Type) or "Item"
    
    if rawName == "BasicWheel" or item.Name:find("Wheel") then
        itType = "Wheel"
    elseif rawName == "GasCan" or rawName == "Coal" or rawName == "CoalBlock" then
        itType = "Fuel"
    elseif rawName == "Medkit" or rawName == "Bandage" then
        itType = "Medic"
    elseif rawName == "Wood" or rawName == "Scrap" then
        itType = "Resources"
    end
    
    return dispName, itType
end

local categoryColors = {
    Fuel = Color3.fromRGB(255, 165, 0),      -- Orange
    Wheel = Color3.fromRGB(0, 230, 255),     -- Cyan
    Medic = Color3.fromRGB(50, 255, 100),    -- Green
    Weapon = Color3.fromRGB(255, 60, 60),    -- Red
    Firearm = Color3.fromRGB(255, 60, 60),
    Melee = Color3.fromRGB(255, 100, 100),
    Resources = Color3.fromRGB(240, 200, 80),-- Yellow
    Default = Color3.fromRGB(200, 200, 200)
}

local function createBillboard(adornPart, text, color, offset)
    local bg = Instance.new("BillboardGui")
    bg.Name = "ESP_Tag"
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 150, 0, 30)
    bg.StudsOffset = offset or Vector3.new(0, 1.5, 0)
    bg.Adornee = adornPart
    bg.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = bg

    return bg, label
end

-- ESP Update Heartbeat Loop
trackConnection(RunService.RenderStepped:Connect(function()
    if not running then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos = myRoot.Position

    -- 1. BUS ESP
    local bus = Workspace:FindFirstChild("ITEM_CONTAINER") and Workspace.ITEM_CONTAINER:FindFirstChild("Bus")
    if bus and bus:IsDescendantOf(Workspace) and ConfigState.ESP_Bus then
        local busAdorn = bus:FindFirstChild("SeatPart") or bus:FindFirstChildWhichIsA("BasePart")
        if busAdorn then
            local dist = math.floor((bus:GetPivot().Position - myPos).Magnitude)
            if not activeBillboards["Bus"] then
                local bg, lbl = createBillboard(busAdorn, "🚌 BUS [" .. dist .. "m]", Color3.fromRGB(255, 215, 0), Vector3.new(0, 4, 0))
                lbl.TextSize = 15
                activeBillboards["Bus"] = {gui = bg, label = lbl, obj = bus}
            else
                activeBillboards["Bus"].label.Text = "🚌 BUS [" .. dist .. "m]"
            end
        end
    else
        if activeBillboards["Bus"] then
            pcall(function() activeBillboards["Bus"].gui:Destroy() end)
            activeBillboards["Bus"] = nil
        end
    end

    -- 2. ITEMS ESP
    local itemContainer = Workspace:FindFirstChild("ITEM_CONTAINER")
    if itemContainer and ConfigState.ESP_Items then
        for _, item in ipairs(itemContainer:GetChildren()) do
            if item.Name ~= "Bus" and (item:IsA("Tool") or item:IsA("Model")) then
                local pivot = item:GetPivot().Position
                local dist = math.floor((pivot - myPos).Magnitude)
                local id = "Item_" .. item.Name

                if dist <= ConfigState.ESP_MaxDistance then
                    local dispName, itType = resolveItemData(item)
                    
                    -- Check category filters
                    local show = true
                    if itType == "Fuel" and not ConfigState.ESP_Fuel then show = false end
                    if itType == "Wheel" and not ConfigState.ESP_Wheels then show = false end
                    if itType == "Medic" and not ConfigState.ESP_Meds then show = false end
                    if (itType == "Weapon" or itType == "Firearm" or itType == "Melee") and not ConfigState.ESP_Weapons then show = false end
                    if itType == "Resources" and not ConfigState.ESP_Resources then show = false end

                    if show then
                        local color = categoryColors[itType] or categoryColors.Default
                        local adorn = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart", true)
                        if adorn then
                            if not activeBillboards[id] then
                                local bg, lbl = createBillboard(adorn, dispName .. " [" .. dist .. "m]", color)
                                activeBillboards[id] = {gui = bg, label = lbl, obj = item}
                            else
                                activeBillboards[id].label.Text = dispName .. " [" .. dist .. "m]"
                            end
                        end
                    else
                        if activeBillboards[id] then
                            pcall(function() activeBillboards[id].gui:Destroy() end)
                            activeBillboards[id] = nil
                        end
                    end
                else
                    if activeBillboards[id] then
                        pcall(function() activeBillboards[id].gui:Destroy() end)
                        activeBillboards[id] = nil
                    end
                end
            end
        end
    end

    -- 3. ENTITIES ESP
    local entityContainer = Workspace:FindFirstChild("ENTITY_CONTAINER")
    if entityContainer and ConfigState.ESP_Entities then
        for _, ent in ipairs(entityContainer:GetChildren()) do
            local pivot = ent:GetPivot().Position
            local dist = math.floor((pivot - myPos).Magnitude)
            local id = "Ent_" .. ent.Name

            if dist <= ConfigState.ESP_EntityMaxDist then
                local entType = ent:GetAttribute("Type") or ent.Name
                local isNPC = ent:GetAttribute("NPC") ~= nil or entType == "ShopKeeper" or entType == "Guard" or entType == "TraderGuardian"

                local show = true
                if ConfigState.ESP_HostilesOnly and isNPC then
                    show = false
                end

                if show then
                    local color = isNPC and Color3.fromRGB(0, 255, 180) or Color3.fromRGB(255, 60, 60)
                    local hum = ent:FindFirstChildOfClass("Humanoid")
                    local hpStr = hum and (" (" .. math.floor(hum.Health) .. " HP)") or ""
                    local text = (isNPC and "👤 " or "🧟 ") .. entType .. hpStr .. " [" .. dist .. "m]"

                    local adorn = ent:FindFirstChild("HumanoidRootPart") or ent:FindFirstChild("Head") or ent:FindFirstChildWhichIsA("BasePart")
                    if adorn then
                        if not activeBillboards[id] then
                            local bg, lbl = createBillboard(adorn, text, color, Vector3.new(0, 2.5, 0))
                            activeBillboards[id] = {gui = bg, label = lbl, obj = ent}
                        else
                            activeBillboards[id].label.Text = text
                        end
                    end
                else
                    if activeBillboards[id] then
                        pcall(function() activeBillboards[id].gui:Destroy() end)
                        activeBillboards[id] = nil
                    end
                end
            else
                if activeBillboards[id] then
                    pcall(function() activeBillboards[id].gui:Destroy() end)
                    activeBillboards[id] = nil
                end
            end
        end
    end

    -- Cleanup stale billboards
    for key, data in pairs(activeBillboards) do
        if not data.obj or not data.obj:IsDescendantOf(Workspace) then
            pcall(function() data.gui:Destroy() end)
            activeBillboards[key] = nil
        end
    end
end))

trackFunction(function()
    for _, data in pairs(activeBillboards) do
        pcall(function() data.gui:Destroy() end)
    end
    activeBillboards = {}
end)

--------------------------------------------------------------------------------
-- TAB 3: COMBAT
--------------------------------------------------------------------------------
Tabs.Combat:AddParagraph({
    Title = "Melee & Kill Aura",
    Content = "Serang semua monster di sekitar tanpa perlu mengayunkan sekop secara manual."
})

local KillAuraToggle = Tabs.Combat:AddToggle("KillAuraToggle", {
    Title = "Kill Aura (Auto Melee Hit)",
    Default = false,
    Description = "Menyerang zombie dalam jangkauan menggunakan senjata melee"
})
local KillAuraRangeSlider = Tabs.Combat:AddSlider("KillAuraRangeSlider", {
    Title = "Kill Aura Range (Studs)",
    Default = 20,
    Min = 5,
    Max = 30,
    Rounding = 0,
    Callback = function(v)
        ConfigState.KillAuraRange = v
    end
})
KillAuraToggle:OnChanged(function()
    ConfigState.KillAura = Options.KillAuraToggle.Value
end)

-- Kill Aura Worker Loop
task.spawn(function()
    while running do
        if ConfigState.KillAura and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local equippedTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
            local toolComp = equippedTool and ItemController and ItemController.Cache.Items[equippedTool.Name]

            if myRoot and toolComp and toolComp.Replica then
                local entityContainer = Workspace:FindFirstChild("ENTITY_CONTAINER")
                if entityContainer then
                    for _, ent in ipairs(entityContainer:GetChildren()) do
                        local isNPC = ent:GetAttribute("NPC") ~= nil or ent:GetAttribute("Type") == "ShopKeeper" or ent:GetAttribute("Type") == "Guard"
                        if not isNPC then
                            local pivot = ent:GetPivot().Position
                            local dist = (pivot - myRoot.Position).Magnitude
                            if dist <= ConfigState.KillAuraRange then
                                local targetPart = ent:FindFirstChild("HumanoidRootPart") or ent:FindFirstChild("Head") or ent:FindFirstChildWhichIsA("BasePart")
                                if targetPart then
                                    pcall(function()
                                        toolComp.Replica:FireServer("Melee", "Hit", targetPart, targetPart.Position, Vector3.new(0, 1, 0), Enum.Material.Plastic)
                                    end)
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.15)
    end
end)

Tabs.Combat:AddParagraph({
    Title = "Hitbox Expander",
    Content = "Memperbesar hitbox monster agar tembakan dan pukulan sekop selalu kena."
})

local HitboxToggle = Tabs.Combat:AddToggle("HitboxToggle", {
    Title = "Hitbox Expander",
    Default = false,
    Description = "Memperbesar ukuran tubuh zombie di sekitar"
})
local HitboxSlider = Tabs.Combat:AddSlider("HitboxSlider", {
    Title = "Hitbox Size",
    Default = 8,
    Min = 4,
    Max = 20,
    Rounding = 0,
    Callback = function(v)
        ConfigState.HitboxSize = v
    end
})
HitboxToggle:OnChanged(function()
    ConfigState.HitboxExpander = Options.HitboxToggle.Value
end)

local expandedParts = {}
task.spawn(function()
    while running do
        if ConfigState.HitboxExpander then
            local entityContainer = Workspace:FindFirstChild("ENTITY_CONTAINER")
            if entityContainer then
                for _, ent in ipairs(entityContainer:GetChildren()) do
                    local isNPC = ent:GetAttribute("NPC") ~= nil or ent:GetAttribute("Type") == "ShopKeeper"
                    if not isNPC then
                        local root = ent:FindFirstChild("HumanoidRootPart")
                        if root then
                            if not expandedParts[root] then
                                expandedParts[root] = root.Size
                            end
                            root.Size = Vector3.new(ConfigState.HitboxSize, ConfigState.HitboxSize, ConfigState.HitboxSize)
                            root.Transparency = 0.7
                            root.CanCollide = false
                        end
                    end
                end
            end
        else
            if next(expandedParts) then
                for part, originalSize in pairs(expandedParts) do
                    pcall(function()
                        if part and part.Parent then
                            part.Size = originalSize
                            part.Transparency = 1
                        end
                    end)
                end
                expandedParts = {}
            end
        end
        task.wait(0.5)
    end
end)

trackFunction(function()
    for part, originalSize in pairs(expandedParts) do
        pcall(function()
            if part and part.Parent then
                part.Size = originalSize
                part.Transparency = 1
            end
        end)
    end
end)

--------------------------------------------------------------------------------
-- TAB 4: AUTOMATION & UTILITY
--------------------------------------------------------------------------------
Tabs.Automation:AddParagraph({
    Title = "Proximity & Interactions",
    Content = "Interaksi instan tanpa menunggu penahanan tombol."
})

local origPrompts = {}
local PromptsToggle = Tabs.Automation:AddToggle("PromptsToggle", {
    Title = "Instant Proximity Prompts",
    Default = true,
    Description = "Interaksi instan (Buka pintu, kemudi bus, furnace, dsb)"
})
PromptsToggle:OnChanged(function()
    ConfigState.InstantPrompts = Options.PromptsToggle.Value
    if ConfigState.InstantPrompts then
        for _, p in ipairs(Workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                if not origPrompts[p] then
                    origPrompts[p] = {hold = p.HoldDuration, dist = p.MaxActivationDistance}
                end
                p.HoldDuration = 0
                p.MaxActivationDistance = 25
            end
        end
    else
        for p, data in pairs(origPrompts) do
            pcall(function()
                if p and p.Parent then
                    p.HoldDuration = data.hold
                    p.MaxActivationDistance = data.dist
                end
            end)
        end
        origPrompts = {}
    end
end)

trackConnection(Workspace.DescendantAdded:Connect(function(desc)
    if ConfigState.InstantPrompts and desc:IsA("ProximityPrompt") then
        task.wait()
        if not origPrompts[desc] then
            origPrompts[desc] = {hold = desc.HoldDuration, dist = desc.MaxActivationDistance}
        end
        desc.HoldDuration = 0
        desc.MaxActivationDistance = 25
    end
end))

trackFunction(function()
    for p, data in pairs(origPrompts) do
        pcall(function()
            if p and p.Parent then
                p.HoldDuration = data.hold
                p.MaxActivationDistance = data.dist
            end
        end)
    end
end)

Tabs.Automation:AddParagraph({
    Title = "Auto Eat & Hunger",
    Content = "Makan otomatis saat rasa lapar berada di level kritis."
})

local AutoEatToggle = Tabs.Automation:AddToggle("AutoEatToggle", {
    Title = "Auto Eat",
    Default = true,
    Description = "Makan makanan di inventory saat lapar"
})
local EatSlider = Tabs.Automation:AddSlider("EatSlider", {
    Title = "Eat Below % Hunger",
    Default = 35,
    Min = 10,
    Max = 70,
    Rounding = 0,
    Callback = function(v)
        ConfigState.AutoEatThreshold = v
    end
})
AutoEatToggle:OnChanged(function()
    ConfigState.AutoEat = Options.AutoEatToggle.Value
end)

task.spawn(function()
    while running do
        if ConfigState.AutoEat and LocalPlayer.Character then
            local comp = Knit.Components.Player and Knit.Components.Player:FromInstance(LocalPlayer)
            if comp and comp.Replica and comp.Replica.Data then
                local hunger = comp.Replica.Data.Hunger or 100
                local maxHunger = comp.Replica.Data.MaxHunger or 100
                local pct = (hunger / maxHunger) * 100

                if pct <= ConfigState.AutoEatThreshold then
                    local inv = comp.Replica.Data.Inventory or {}
                    for _, itemId in ipairs(inv) do
                        local rep = ItemController and ItemController:TryGetItemReplica(itemId)
                        local rawName = rep and rep.Tags and rep.Tags.Name
                        local cfg = Config.Item.Items[rawName]
                        if cfg and (cfg.Type == "Food" or rawName == "Apple" or rawName == "ChocolateBar" or rawName == "Coke") then
                            local toolInst = LocalPlayer.Backpack:FindFirstChild(itemId) or LocalPlayer.Character:FindFirstChild(itemId)
                            if toolInst then
                                pcall(function()
                                    comp.Replica:FireServer("Eat", toolInst)
                                end)
                                task.wait(1.5)
                                break
                            end
                        end
                    end
                end
            end
        end
        task.wait(2)
    end
end)

--------------------------------------------------------------------------------
-- TAB 5: TELEPORT
--------------------------------------------------------------------------------
Tabs.Teleport:AddParagraph({
    Title = "Quick Waypoints",
    Content = "Teleportasi instan ke titik-titik krusial di peta."
})

Tabs.Teleport:AddButton({
    Title = "Teleport to Bus (Kabin / Driver Seat)",
    Description = "Kembali langsung ke Bus",
    Callback = function()
        local bus = Workspace:FindFirstChild("ITEM_CONTAINER") and Workspace.ITEM_CONTAINER:FindFirstChild("Bus")
        if bus and LocalPlayer.Character then
            local seat = bus:FindFirstChild("SeatPart") or bus:FindFirstChildWhichIsA("BasePart")
            local targetPos = seat and (seat.CFrame + Vector3.new(0, 3, 0)) or (bus:GetPivot() + Vector3.new(0, 4, 0))
            LocalPlayer.Character:PivotTo(targetPos)
            Fluent:Notify({ Title = "Teleport", Content = "Berhasil teleport ke Bus!", Duration = 3 })
        else
            Fluent:Notify({ Title = "Teleport", Content = "Bus tidak ditemukan di map!", Duration = 3 })
        end
    end
})

local function teleportToNearestItem(filterFn, label)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local itemContainer = Workspace:FindFirstChild("ITEM_CONTAINER")
    if not itemContainer then return end

    local nearest = nil
    local nearestDist = math.huge

    for _, it in ipairs(itemContainer:GetChildren()) do
        if it.Name ~= "Bus" then
            local dispName, itType = resolveItemData(it)
            if filterFn(dispName, itType, it) then
                local pivot = it:GetPivot().Position
                local dist = (pivot - myRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = it
                end
            end
        end
    end

    if nearest then
        local targetCFrame = nearest:GetPivot() + Vector3.new(0, 3, 0)
        myChar:PivotTo(targetCFrame)
        Fluent:Notify({
            Title = "Teleport",
            Content = "Teleport ke " .. label .. " (" .. math.floor(nearestDist) .. "m)!",
            Duration = 3
        })
    else
        Fluent:Notify({
            Title = "Teleport",
            Content = "Tidak ada " .. label .. " ditemukan!",
            Duration = 3
        })
    end
end

Tabs.Teleport:AddButton({
    Title = "Teleport to Nearest Fuel (Gas Can / Coal)",
    Description = "Mencari dan teleport ke bahan bakar terdekat",
    Callback = function()
        teleportToNearestItem(function(name, itType)
            return itType == "Fuel" or name:find("Gas") or name:find("Coal")
        end, "Bahan Bakar")
    end
})

Tabs.Teleport:AddButton({
    Title = "Teleport to Nearest Wheel (Ban Bus)",
    Description = "Mencari dan teleport ke ban terdekat",
    Callback = function()
        teleportToNearestItem(function(name, itType, it)
            return itType == "Wheel" or it.Name:find("Wheel") or name:find("Wheel")
        end, "Ban Bus")
    end
})

Tabs.Teleport:AddButton({
    Title = "Teleport to Nearest Medkit",
    Description = "Mencari dan teleport ke perlengkapan medis",
    Callback = function()
        teleportToNearestItem(function(name, itType)
            return itType == "Medic" or name:find("Medkit") or name:find("Bandage")
        end, "Medkit")
    end
})

Tabs.Teleport:AddButton({
    Title = "Teleport to Nearest Wood / Scrap",
    Description = "Mencari bahan bangunan / repair",
    Callback = function()
        teleportToNearestItem(function(name, itType)
            return itType == "Resources" or name:find("Wood") or name:find("Scrap")
        end, "Wood / Scrap")
    end
})

Tabs.Teleport:AddButton({
    Title = "Teleport to ShopKeeper (Trader Outpost)",
    Description = "Teleport ke pedagang atau posko aman",
    Callback = function()
        local entityContainer = Workspace:FindFirstChild("ENTITY_CONTAINER")
        if entityContainer and LocalPlayer.Character then
            for _, ent in ipairs(entityContainer:GetChildren()) do
                if ent:GetAttribute("NPC") == "ShopKeeper" or ent:GetAttribute("Type") == "ShopKeeper" then
                    LocalPlayer.Character:PivotTo(ent:GetPivot() + Vector3.new(0, 2, 3))
                    Fluent:Notify({ Title = "Teleport", Content = "Teleport ke ShopKeeper!", Duration = 3 })
                    return
                end
            end
        end
        Fluent:Notify({ Title = "Teleport", Content = "ShopKeeper belum spawn di rute saat ini!", Duration = 3 })
    end
})

--------------------------------------------------------------------------------
-- TAB 6: SETTINGS
--------------------------------------------------------------------------------
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("FluentHub")
SaveManager:SetFolder("FluentHub/LastStop")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

if Options.MenuKeybind then
    pcall(function()
        Options.MenuKeybind:SetValue("RightControl")
    end)
end

Tabs.Settings:AddParagraph({
    Title = "Script Management",
    Content = "Tutup dan bersihkan script dengan aman."
})

Tabs.Settings:AddButton({
    Title = "Unload / Close Script",
    Description = "Menutup menu dan membersihkan semua loop serta ESP",
    Callback = function()
        cleanupAll()
        Fluent:Destroy()
    end
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Last Stop [Beta] - Hub",
    Content = "Script siap! Klik tombol 'LS HUB' di layar atau tekan RightControl / Insert untuk buka/tutup menu.",
    Duration = 7
})

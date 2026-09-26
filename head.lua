--[[
    ╔═════════════════════════════════════════════════════════════════╗
    ║                     LAST STOP [BETA] - FLUENT HUB               ║
    ║                  Enhanced Survival & Scavenger Suite            ║
    ║               Built with Fluent UI Library by dawid             ║
    ╚═════════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Clean up any previous Fluent Hub GUI instances to prevent duplicates
for _, gui in ipairs(CoreGui:GetChildren()) do
    if gui:IsA("ScreenGui") and (gui.Name == "ScreenGui" or gui.Name:find("Fluent")) then
        gui:Destroy()
    end
end
if CoreGui:FindFirstChild("FluentHub_ESP") then
    CoreGui.FluentHub_ESP:Destroy()
end

-- Knit Framework Access
local Knit
pcall(function()
    Knit = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
end)

local InputController = Knit and Knit.GetController("InputController")
local CharacterController = Knit and Knit.GetController("CharacterController")
local SprintController = Knit and Knit.GetController("SprintController")
local ItemController = Knit and Knit.GetController("ItemController")
local EntityController = Knit and Knit.GetController("EntityController")
local EffectController = Knit and Knit.GetController("EffectController")
local ItemService = Knit and Knit.GetService("ItemService")

-- Safe Instance & Character Getters
local function GetCharacter()
    return (workspace:FindFirstChild("PLAYER_CONTAINER") and workspace.PLAYER_CONTAINER:FindFirstChild(LocalPlayer.Name)) 
        or LocalPlayer.Character
end

local function GetRootPart(char)
    char = char or GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head") or char.PrimaryPart)
end

local function GetHumanoid(char)
    char = char or GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Crash-proof BasePart & Position extractor (handles both Parts and Models)
local function GetPartAndPosition(inst)
    if not inst then return nil, nil end
    if inst:IsA("BasePart") then
        return inst, inst.Position
    elseif inst:IsA("Model") then
        local bp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
        if bp then
            return bp, bp.Position
        end
        return inst, inst:GetPivot().Position
    end
    return nil, nil
end

-- Load Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Last Stop [Beta] | Fluent Hub",
    SubTitle = "Survival & Extraction Suite",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 480),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Combat    = Window:AddTab({ Title = "Combat & Aura", Icon = "swords" }),
    Bus       = Window:AddTab({ Title = "Bus & Scavenge", Icon = "truck" }),
    Visuals   = Window:AddTab({ Title = "ESP & Visuals", Icon = "eye" }),
    Movement  = Window:AddTab({ Title = "Movement", Icon = "gauge" }),
    Teleports = Window:AddTab({ Title = "Teleports", Icon = "navigation" }),
    Settings  = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- State variables
local Config = {
    -- Combat & Aura
    KillAura = false,
    AuraRange = 18,
    PrioritizeBoss = true,
    AutoEquipMelee = true,
    
    -- Auto Aim Kepala (Head Aimbot)
    Aimbot = false,
    AimbotRightClick = true,
    AimbotSmoothness = 3,
    AimbotFOV = 180,
    
    -- Hitbox Expander (Jarak Damage Diperbesar)
    HitboxExpander = false,
    HitboxSize = 12,
    
    -- Auto Eat (Hunger Management)
    AutoEat = false,
    AutoEatThreshold = 50, -- Trigger when hunger <= 50%
    
    -- Auto Loot (Item Vacuum)
    AutoLoot = false,
    AutoLootRange = 50,
    AutoLootFilter = "All",
    
    -- Survival Defense
    SafeHover = false,
    AutoHeal = false,
    AutoHealThreshold = 100,
    InfiniteSprint = false,
    AntiRagdoll = false,
    
    -- Visuals
    EntityESP = false,
    ItemESP = false,
    ItemFilter = "All",
    BusESP = false,
    Fullbright = false,
    NoFog = false,
    
    -- Movement
    WalkSpeed = 16,
    WalkSpeedEnabled = false,
    JumpPower = 50,
    JumpPowerEnabled = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
}

--------------------------------------------------------------------
-- COMBAT / KILL AURA (SMOOTH & SILENT - ZERO SCREEN JITTER)
--------------------------------------------------------------------
local function GetEntityClassification(entity)
    local typeAttr = entity:GetAttribute("Type") or entity:GetAttribute("NPC") or entity.Name
    local lower = typeAttr:lower()
    
    if lower:find("shopkeeper") or lower:find("guard") or lower:find("riley") or lower:find("noodle") then
        return "Friendly", typeAttr
    end
    if lower:find("fredboss") or lower:find("boss") or lower:find("dracula") or lower:find("anubis") or lower:find("juggernaut") or lower:find("kraken") then
        return "Boss", typeAttr
    end
    return "Hostile", typeAttr
end

local function GetTargetEntities()
    local targets = {}
    local hrp = GetRootPart()
    if not hrp then return targets end
    
    local container = workspace:FindFirstChild("ENTITY_CONTAINER")
    if not container then return targets end
    
    for _, entity in ipairs(container:GetChildren()) do
        local classification, typeName = GetEntityClassification(entity)
        if classification ~= "Friendly" then
            local part, pos = nil, nil
            for _, name in ipairs({"HumanoidRootPart", "Torso", "Head", "EntityDetector"}) do
                local child = entity:FindFirstChild(name)
                if child then
                    part, pos = GetPartAndPosition(child)
                    if part and pos then break end
                end
            end
            if not part or not pos then
                part, pos = GetPartAndPosition(entity)
            end
            
            if part and pos then
                local dist = (pos - hrp.Position).Magnitude
                if dist <= Config.AuraRange then
                    table.insert(targets, {
                        Entity = entity,
                        Part = part,
                        Pos = pos,
                        Dist = dist,
                        IsBoss = (classification == "Boss"),
                        Name = typeName
                    })
                end
            end
        end
    end
    
    table.sort(targets, function(a, b)
        if Config.PrioritizeBoss and a.IsBoss ~= b.IsBoss then
            return a.IsBoss
        end
        return a.Dist < b.Dist
    end)
    
    return targets
end

-- Smooth Silent Kill Aura Loop
task.spawn(function()
    while true do
        task.wait(0.08)
        if Config.KillAura then
            local targets = GetTargetEntities()
            if #targets > 0 then
                local target = targets[1]
                local hrp = GetRootPart()
                
                if hrp and target.Entity and target.Entity.Parent then
                    local holding = ItemController and ItemController:GetHoldingItem()
                    
                    -- Auto-Equip Melee Weapon if holding nothing or non-weapon item
                    if (not holding or not holding.Config or holding.Config.Type ~= "Melee") and Config.AutoEquipMelee and ItemController then
                        local melees = ItemController:GetItemsByType("Melee")
                        if melees and #melees > 0 and ItemService then
                            pcall(function()
                                ItemService:EquipItem(melees[1])
                            end)
                            holding = ItemController:GetHoldingItem()
                        end
                    end
                    
                    if holding and holding.Config and holding.Config.Type == "Melee" then
                        local canAttack = true
                        if holding.CheckAttack then
                            canAttack = holding:CheckAttack()
                        end
                        
                        if canAttack then
                            pcall(function() holding:Activate() end)
                            
                            local hitPart = target.Entity:FindFirstChild("Torso") 
                                or target.Entity:FindFirstChild("HumanoidRootPart") 
                                or target.Entity:FindFirstChild("Head") 
                                or target.Part
                                
                            if hitPart and not hitPart:IsA("BasePart") then
                                hitPart = hitPart:FindFirstChildWhichIsA("BasePart") or target.Part
                            end
                            
                            if holding.Replica and hitPart and hitPart:IsA("BasePart") then
                                pcall(function()
                                    holding.Replica:FireServer("Melee", "Hit", hitPart, hitPart.Position, Vector3.new(0, 1, 0), Enum.Material.Plastic)
                                    if holding.ConfirmHit then
                                        holding:ConfirmHit("Entity")
                                    end
                                end)
                            end
                            
                            if EffectController and hitPart and hitPart:IsA("BasePart") then
                                pcall(function()
                                    local hitData = {
                                        Instance = hitPart,
                                        Position = hitPart.Position,
                                        Normal = Vector3.new(0, 1, 0),
                                        Material = Enum.Material.Plastic,
                                        ImpactType = "Entity",
                                        Source = LocalPlayer
                                    }
                                    EffectController:Play("Melee", "Hit", nil, hitData)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------
-- AUTO AIM KEPALA (HEAD AIMBOT)
--------------------------------------------------------------------
local camera = workspace.CurrentCamera
local aimbotRightClickHeld = false

UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimbotRightClickHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimbotRightClickHeld = false
    end
end)

local function GetBestHeadTarget()
    local mouse = LocalPlayer:GetMouse()
    local mPos = Vector2.new(mouse.X, mouse.Y)
    local bestTarget, bestDist = nil, Config.AimbotFOV
    
    local container = workspace:FindFirstChild("ENTITY_CONTAINER")
    if not container then return nil end
    
    for _, entity in ipairs(container:GetChildren()) do
        local class = GetEntityClassification(entity)
        if class ~= "Friendly" then
            local head = entity:FindFirstChild("Head") or entity:FindFirstChild("HumanoidRootPart")
            if head then
                local headPos = head:IsA("BasePart") and head.Position or head:GetPivot().Position
                local screenPos, onScreen = camera:WorldToViewportPoint(headPos)
                if onScreen then
                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mPos).Magnitude
                    if screenDist <= bestDist then
                        bestDist = screenDist
                        bestTarget = headPos
                    end
                end
            end
        end
    end
    return bestTarget
end

RunService.RenderStepped:Connect(function()
    if Config.Aimbot then
        local shouldAim = not Config.AimbotRightClick or aimbotRightClickHeld
        if shouldAim then
            local targetPos = GetBestHeadTarget()
            if targetPos then
                local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)
                if Config.AimbotSmoothness > 1 then
                    camera.CFrame = camera.CFrame:Lerp(targetCFrame, 1 / Config.AimbotSmoothness)
                else
                    camera.CFrame = targetCFrame
                end
            end
        end
    end
end)

--------------------------------------------------------------------
-- HITBOX EXPANDER (JARAK DAMAGE DIPERBESAR)
--------------------------------------------------------------------
local hitboxCache = {}

task.spawn(function()
    while true do
        task.wait(0.3)
        if Config.HitboxExpander then
            local container = workspace:FindFirstChild("ENTITY_CONTAINER")
            if container then
                for _, entity in ipairs(container:GetChildren()) do
                    local class = GetEntityClassification(entity)
                    if class ~= "Friendly" then
                        local part = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso")
                        if part and part:IsA("BasePart") then
                            if not hitboxCache[part] then
                                hitboxCache[part] = {
                                    Size = part.Size,
                                    CanCollide = part.CanCollide,
                                    Transparency = part.Transparency,
                                    Color = part.Color,
                                    Material = part.Material
                                }
                            end
                            part.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                            part.CanCollide = false
                            part.Transparency = 0.65
                            part.Color = Color3.fromRGB(255, 60, 60)
                            part.Material = Enum.Material.ForceField
                        end
                    end
                end
            end
        else
            if next(hitboxCache) then
                for part, data in pairs(hitboxCache) do
                    if part and part.Parent then
                        pcall(function()
                            part.Size = data.Size
                            part.CanCollide = data.CanCollide
                            part.Transparency = data.Transparency
                            part.Color = data.Color
                            part.Material = data.Material
                        end)
                    end
                end
                table.clear(hitboxCache)
            end
        end
    end
end)

--------------------------------------------------------------------
-- AUTO EAT (MAKAN OTOMATIS SAAT HUNGER <= 50%)
--------------------------------------------------------------------
local autoEatDebounce = false

task.spawn(function()
    while true do
        task.wait(1.2)
        if Config.AutoEat and not autoEatDebounce then
            pcall(function()
                local playerComp = Knit and Knit.Components and Knit.Components.Player and Knit.Components.Player:FromInstance(LocalPlayer)
                local rep = playerComp and playerComp.Replica
                if rep and rep.Data then
                    local hunger = rep.Data.Hunger or 100
                    local maxHunger = rep.Data.MaxHunger or 100
                    local pct = (hunger / maxHunger) * 100
                    
                    if pct <= Config.AutoEatThreshold then
                        if ItemController and ItemService then
                            local foods = ItemController:GetItemsByType("Food")
                            if foods and #foods > 0 then
                                autoEatDebounce = true
                                
                                -- Select food (prefer Apple/ChocolateBar)
                                local selectedFood = foods[1]
                                for _, fId in ipairs(foods) do
                                    local comp = Knit.Components.Item:FromId(fId)
                                    local n = comp and comp.Replica and comp.Replica.Tags and comp.Replica.Tags.Name or ""
                                    if n == "Apple" or n == "ChocolateBar" then
                                        selectedFood = fId
                                        break
                                    end
                                end
                                
                                -- Remember current equipped weapon to re-equip after
                                local prev = ItemController:GetHoldingItem()
                                local prevId = prev and prev.Id
                                
                                -- Equip food item
                                ItemService:EquipItem(selectedFood)
                                task.wait(0.35)
                                
                                -- Consume food
                                local curHolding = ItemController:GetHoldingItem()
                                if curHolding and curHolding.Activate then
                                    curHolding:Activate()
                                else
                                    ItemService:Eat()
                                end
                                task.wait(0.8)
                                
                                -- Re-equip previous weapon
                                if prevId then
                                    pcall(function() ItemService:EquipItem(prevId) end)
                                end
                                
                                Fluent:Notify({
                                    Title = "Auto Eat",
                                    Content = string.format("Makan otomatis berhasil! Lapar sebelumnya: %d%%", math.floor(pct)),
                                    Duration = 3
                                })
                                
                                task.wait(1.5)
                                autoEatDebounce = false
                            end
                        end
                    end
                end
            end)
        end
    end
end)

--------------------------------------------------------------------
-- SAFE HOVER GODMODE & AUTO HEAL (SURVIVAL DEFENSE)
--------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.08)
        if Config.SafeHover then
            local hrp = GetRootPart()
            if hrp then
                local tooClose = false
                local container = workspace:FindFirstChild("ENTITY_CONTAINER")
                if container then
                    for _, entity in ipairs(container:GetChildren()) do
                        local class = GetEntityClassification(entity)
                        if class ~= "Friendly" then
                            local _, pos = GetPartAndPosition(entity)
                            if pos and (pos - hrp.Position).Magnitude < 14 then
                                tooClose = true
                                break
                            end
                        end
                    end
                end
                
                if tooClose then
                    local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -35, 0))
                    if ray then
                        local safeY = ray.Position.Y + 7.5
                        if hrp.Position.Y < safeY then
                            hrp.CFrame = CFrame.new(hrp.Position.X, safeY, hrp.Position.Z)
                            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.8)
        if Config.AutoHeal then
            local hum = GetHumanoid()
            if hum and hum.Health < Config.AutoHealThreshold then
                if ItemController and ItemService then
                    local meds = ItemController:GetItemsByType("Medic") or ItemController:GetItemsByType("Food")
                    if meds and #meds > 0 then
                        pcall(function()
                            ItemService:Eat(meds[1])
                        end)
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------
-- INFINITE SPRINT & ANTI-RAGDOLL
--------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.2)
        if Config.InfiniteSprint and SprintController then
            pcall(function()
                SprintController.BlockReasons = {}
                SprintController:SetSprinting(true)
            end)
        end
        if Config.AntiRagdoll then
            local char = GetCharacter()
            if char and char:GetAttribute("Ragdolled") then
                char:SetAttribute("Ragdolled", false)
            end
            local hum = GetHumanoid(char)
            if hum and (hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.FallingDown) then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end)

--------------------------------------------------------------------
-- BUS & ITEM HELPERS
--------------------------------------------------------------------
local function GetBusInstance()
    return (workspace:FindFirstChild("ITEM_CONTAINER") and workspace.ITEM_CONTAINER:FindFirstChild("Bus"))
        or workspace:FindFirstChild("Bus")
end

local function GetItemCleanName(item)
    if not item then return "Unknown" end
    if Knit and Knit.Components and Knit.Components.Item then
        local comp = Knit.Components.Item:FromInstance(item)
        if comp and comp.Replica and comp.Replica.Tags and comp.Replica.Tags.Name then
            return comp.Replica.Tags.Name
        end
    end
    local guid = item:GetAttribute("GUID") or item:GetAttribute("Class") or item:GetAttribute("Type")
    if guid and #guid > 0 and not guid:find("%-") then
        return guid
    end
    return item.Name
end

local function CategorizeItem(cleanName, item)
    local n = cleanName:lower()
    if n:find("gascan") or n:find("fuel") or item:GetAttribute("SaleF_Fuel") or n:find("coal") then
        return "Fuel"
    elseif n:find("bat") or n:find("mace") or n:find("sword") or n:find("shovel") or n:find("ammo") or n:find("gun") or n:find("pistol") or n:find("shotgun") or n:find("rifle") or n:find("sight") or n:find("scope") or n:find("suppressor") then
        return "Weapons"
    elseif n:find("bandage") or n:find("medkit") or n:find("apple") or n:find("chocolate") or n:find("coke") or n:find("cure") or n:find("potion") or n:find("food") then
        return "Medical"
    elseif n:find("wheel") or n:find("tire") or n:find("hammer") or n:find("spring") or n:find("scrap") or n:find("engine") then
        return "Wheels"
    elseif n:find("gold") or n:find("silver") or n:find("trophy") or n:find("globe") or n:find("statue") or n:find("watch") then
        return "Valuables"
    else
        return "Other"
    end
end

local function BringItemsToTarget(itemFilterFunc, destinationCFrame, maxDist)
    local container = workspace:FindFirstChild("ITEM_CONTAINER")
    if not container then return 0 end
    
    local hrp = GetRootPart()
    local count = 0
    
    for _, item in ipairs(container:GetChildren()) do
        if item.Name ~= "Bus" then
            local cleanName = GetItemCleanName(item)
            local category = CategorizeItem(cleanName, item)
            
            if itemFilterFunc(cleanName, category, item) then
                local part, pos = GetPartAndPosition(item)
                if part and pos and (not maxDist or (pos - hrp.Position).Magnitude <= maxDist) then
                    pcall(function()
                        if part:IsA("BasePart") then
                            part.CFrame = destinationCFrame + Vector3.new(0, 1 + (count * 0.3), 0)
                            part.AssemblyLinearVelocity = Vector3.zero
                            part.AssemblyAngularVelocity = Vector3.zero
                        elseif part:IsA("Model") then
                            part:PivotTo(destinationCFrame + Vector3.new(0, 1 + (count * 0.3), 0))
                        end
                    end)
                    count = count + 1
                end
            end
        end
    end
    return count
end

--------------------------------------------------------------------
-- AUTO LOOT (CONTINUOUS LOOT VACUUM & STORE)
--------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(1.5)
        if Config.AutoLoot then
            pcall(function()
                local hrp = GetRootPart()
                if hrp then
                    local container = workspace:FindFirstChild("ITEM_CONTAINER")
                    if container then
                        local count = 0
                        for _, item in ipairs(container:GetChildren()) do
                            if item.Name ~= "Bus" then
                                local cleanName = GetItemCleanName(item)
                                local category = CategorizeItem(cleanName, item)
                                
                                local match = (Config.AutoLootFilter == "All") 
                                    or (Config.AutoLootFilter == "Valuables" and category == "Valuables")
                                    or (Config.AutoLootFilter == "Fuel" and category == "Fuel")
                                    or (Config.AutoLootFilter == "Weapons" and category == "Weapons")
                                    or (Config.AutoLootFilter == "Medical" and category == "Medical")
                                    
                                if match then
                                    local part, pos = GetPartAndPosition(item)
                                    if part and pos and (pos - hrp.Position).Magnitude <= Config.AutoLootRange then
                                        pcall(function()
                                            if part:IsA("BasePart") then
                                                part.CFrame = hrp.CFrame + Vector3.new(0, 1 + (count * 0.2), 0)
                                                part.AssemblyLinearVelocity = Vector3.zero
                                                part.AssemblyAngularVelocity = Vector3.zero
                                            elseif part:IsA("Model") then
                                                part:PivotTo(hrp.CFrame + Vector3.new(0, 1 + (count * 0.2), 0))
                                            end
                                            
                                            -- Attempt to auto-store item if storable
                                            if ItemService and ItemController then
                                                local comp = Knit.Components.Item:FromInstance(item)
                                                if comp and ItemController:IsItemStorable(comp) then
                                                    ItemService:StoreItem(item)
                                                end
                                            end
                                        end)
                                        count = count + 1
                                        if count >= 12 then break end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

--------------------------------------------------------------------
-- ESP ENGINE (CRASH-PROOF)
--------------------------------------------------------------------
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "FluentHub_ESP"
ESPFolder.Parent = CoreGui

local activeBillboards = {}

local function ClearESP()
    for _, bb in pairs(activeBillboards) do
        if bb and bb.Gui and bb.Gui.Parent then
            bb.Gui:Destroy()
        end
    end
    table.clear(activeBillboards)
end

local function CreateBillboard(adornee, text, color, offset)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Tag"
    bb.Adornee = adornee
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(140, 26)
    bb.StudsOffset = offset or Vector3.new(0, 2.5, 0)
    bb.MaxDistance = 1500
    bb.Parent = ESPFolder
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = bb
    
    return bb, label
end

-- ESP Update Loop
task.spawn(function()
    while true do
        task.wait(0.2)
        local hrp = GetRootPart()
        if not hrp then
            ClearESP()
        else
            -- 1. Bus ESP
            local bus = GetBusInstance()
            if bus then
                local busMain, busPos = GetPartAndPosition(bus)
                if busMain and busPos then
                    local id = "Bus"
                    local bbData = activeBillboards[id]
                    if Config.BusESP then
                        local dist = math.floor((busPos - hrp.Position).Magnitude)
                        local busText = string.format("🚌 [BUS] %dm", dist)
                        if not bbData or not bbData.Gui.Parent then
                            local bb, lbl = CreateBillboard(busMain, busText, Color3.fromRGB(255, 220, 50), Vector3.new(0, 4, 0))
                            activeBillboards[id] = { Gui = bb, Label = lbl }
                        else
                            bbData.Label.Text = busText
                        end
                    elseif bbData then
                        bbData.Gui:Destroy()
                        activeBillboards[id] = nil
                    end
                end
            end
            
            -- 2. Entity ESP
            local entContainer = workspace:FindFirstChild("ENTITY_CONTAINER")
            if entContainer then
                for _, entity in ipairs(entContainer:GetChildren()) do
                    local id = "Ent_" .. entity.Name
                    local bbData = activeBillboards[id]
                    
                    if Config.EntityESP then
                        local part, pos = nil, nil
                        for _, name in ipairs({"Head", "HumanoidRootPart", "Torso"}) do
                            local child = entity:FindFirstChild(name)
                            if child then
                                part, pos = GetPartAndPosition(child)
                                if part and pos then break end
                            end
                        end
                        if not part or not pos then
                            part, pos = GetPartAndPosition(entity)
                        end
                        
                        if part and pos then
                            local classification, typeName = GetEntityClassification(entity)
                            local dist = math.floor((pos - hrp.Position).Magnitude)
                            local col = Color3.fromRGB(255, 75, 75)
                            if classification == "Friendly" then
                                col = Color3.fromRGB(75, 255, 120)
                            elseif classification == "Boss" then
                                col = Color3.fromRGB(255, 50, 200)
                            end
                            
                            local text = string.format("[%s] %dm", typeName, dist)
                            if not bbData or not bbData.Gui.Parent then
                                local bb, lbl = CreateBillboard(part, text, col, Vector3.new(0, 2.5, 0))
                                activeBillboards[id] = { Gui = bb, Label = lbl, Target = entity }
                            else
                                bbData.Label.Text = text
                            end
                        end
                    elseif bbData then
                        bbData.Gui:Destroy()
                        activeBillboards[id] = nil
                    end
                end
            end
            
            -- 3. Item ESP
            local itemContainer = workspace:FindFirstChild("ITEM_CONTAINER")
            if itemContainer then
                for _, item in ipairs(itemContainer:GetChildren()) do
                    if item.Name ~= "Bus" then
                        local id = "Item_" .. item.Name
                        local bbData = activeBillboards[id]
                        
                        if Config.ItemESP then
                            local cleanName = GetItemCleanName(item)
                            local category = CategorizeItem(cleanName, item)
                            
                            local show = (Config.ItemFilter == "All") or (Config.ItemFilter == category)
                            if show then
                                local part, pos = GetPartAndPosition(item)
                                if part and pos then
                                    local dist = math.floor((pos - hrp.Position).Magnitude)
                                    local col = Color3.fromRGB(220, 220, 220)
                                    if category == "Fuel" then col = Color3.fromRGB(255, 180, 0)
                                    elseif category == "Weapons" then col = Color3.fromRGB(255, 80, 80)
                                    elseif category == "Medical" then col = Color3.fromRGB(80, 255, 120)
                                    elseif category == "Wheels" then col = Color3.fromRGB(0, 200, 255)
                                    elseif category == "Valuables" then col = Color3.fromRGB(255, 215, 0)
                                    end
                                    
                                    local text = string.format("📦 %s [%dm]", cleanName, dist)
                                    if not bbData or not bbData.Gui.Parent then
                                        local bb, lbl = CreateBillboard(part, text, col, Vector3.new(0, 1.2, 0))
                                        activeBillboards[id] = { Gui = bb, Label = lbl, Target = item }
                                    else
                                        bbData.Label.Text = text
                                    end
                                end
                            elseif bbData then
                                bbData.Gui:Destroy()
                                activeBillboards[id] = nil
                            end
                        elseif bbData then
                            bbData.Gui:Destroy()
                            activeBillboards[id] = nil
                        end
                    end
                end
            end
            
            -- Cleanup dangling billboards
            for id, data in pairs(activeBillboards) do
                if data.Target and not data.Target.Parent then
                    data.Gui:Destroy()
                    activeBillboards[id] = nil
                end
            end
        end
    end
end)

--------------------------------------------------------------------
-- FULLBRIGHT & FOG REMOVER
--------------------------------------------------------------------
local originalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd
}

local function UpdateLighting()
    if Config.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    else
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
    end
    
    if Config.NoFog then
        Lighting.FogEnd = 1000000
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") then
                v.Density = 0
            elseif v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
                v.Enabled = false
            end
        end
    else
        Lighting.FogEnd = originalLighting.FogEnd
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") then
                v.Density = 0.3
            elseif v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
                v.Enabled = true
            end
        end
    end
end

--------------------------------------------------------------------
-- MOVEMENT / FLY & NOCLIP
--------------------------------------------------------------------
RunService.Stepped:Connect(function()
    if Config.Noclip then
        local char = GetCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- Smooth Fly Implementation
local flying = false
local flyBV, flyBG

local function StartFly()
    local hrp = GetRootPart()
    if not hrp then return end
    
    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "FluentFly_Velocity"
    flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    
    flyBG = Instance.new("BodyGyro")
    flyBG.Name = "FluentFly_Gyro"
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.CFrame = hrp.CFrame
    flyBG.Parent = hrp
    
    flying = true
    task.spawn(function()
        local camera = workspace.CurrentCamera
        while flying and Config.Fly do
            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end
            
            if flyBV and flyBV.Parent then
                flyBV.Velocity = moveDir.Unit * Config.FlySpeed
                if moveDir.Magnitude == 0 then
                    flyBV.Velocity = Vector3.zero
                end
            end
            if flyBG and flyBG.Parent then
                flyBG.CFrame = camera.CFrame
            end
            RunService.RenderStepped:Wait()
        end
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
    end)
end

local function StopFly()
    flying = false
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
end

local function UpdateSpeeds()
    if CharacterController then
        if Config.WalkSpeedEnabled then
            CharacterController:AddWalkSpeed("FluentSpeed", Config.WalkSpeed - 16)
        else
            CharacterController:RemoveWalkSpeed("FluentSpeed")
        end
        
        if Config.JumpPowerEnabled then
            CharacterController:AddJumpPower("FluentJump", Config.JumpPower - 50)
        else
            CharacterController:RemoveJumpPower("FluentJump")
        end
    else
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = Config.WalkSpeedEnabled and Config.WalkSpeed or 16
            hum.JumpPower = Config.JumpPowerEnabled and Config.JumpPower or 50
        end
    end
end

--------------------------------------------------------------------
-- BUILD FLUENT UI TABS
--------------------------------------------------------------------

-- TAB 1: COMBAT & AURA
Tabs.Combat:AddParagraph({
    Title = "Silent Kill Aura",
    Content = "Menyerang otomatis tanpa memutar layar (Zero Screen Shake)."
})

local AuraToggle = Tabs.Combat:AddToggle("KillAuraToggle", {
    Title = "Silent Kill Aura",
    Description = "Serang zombie terdekat tanpa jedag-jedug",
    Default = false,
    Callback = function(val)
        Config.KillAura = val
        if val then
            Fluent:Notify({
                Title = "Kill Aura Active",
                Content = "Pastikan memegang senjata melee (Hammer/Shovel/Katana/Bat)!",
                Duration = 4
            })
        end
    end
})

local AuraRangeSlider = Tabs.Combat:AddSlider("AuraRange", {
    Title = "Aura Reach (Studs)",
    Description = "Jarak jangkauan aura serang",
    Default = 18,
    Min = 10,
    Max = 35,
    Rounding = 0,
    Callback = function(val)
        Config.AuraRange = val
    end
})

local AutoEquipToggle = Tabs.Combat:AddToggle("AutoEquipMelee", {
    Title = "Auto Equip Melee Weapon",
    Description = "Otomatis mengeluarkan senjata melee dari tas jika tangan kosong",
    Default = true,
    Callback = function(val)
        Config.AutoEquipMelee = val
    end
})

local BossPriorityToggle = Tabs.Combat:AddToggle("PrioritizeBoss", {
    Title = "Prioritize Bosses & Mini-Bosses",
    Default = true,
    Callback = function(val)
        Config.PrioritizeBoss = val
    end
})

-- AUTO AIM KEPALA (HEAD AIMBOT)
Tabs.Combat:AddParagraph({
    Title = "Auto Aim Kepala (Head Aimbot)",
    Content = "Mengarahkan bidikan dan kamera otomatis ke kepala zombie."
})

local AimbotToggle = Tabs.Combat:AddToggle("HeadAimbot", {
    Title = "Enable Auto Aim Kepala",
    Description = "Kamera otomatis mengunci ke kepala musuh terdekat",
    Default = false,
    Callback = function(val)
        Config.Aimbot = val
    end
})

local AimbotRightClickToggle = Tabs.Combat:AddToggle("AimbotHoldRightClick", {
    Title = "Only Aim While Holding Right Click",
    Description = "Hanya mengunci kepala saat klik kanan ditahan",
    Default = true,
    Callback = function(val)
        Config.AimbotRightClick = val
    end
})

local AimbotSmoothSlider = Tabs.Combat:AddSlider("AimbotSmoothness", {
    Title = "Aim Smoothness",
    Description = "1 = Instan, 2-10 = Halus/Smooth",
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(val)
        Config.AimbotSmoothness = val
    end
})

local AimbotFOVSlider = Tabs.Combat:AddSlider("AimbotFOV", {
    Title = "Aimbot FOV Radius",
    Description = "Radius deteksi target dari kursor mouse",
    Default = 180,
    Min = 50,
    Max = 400,
    Rounding = 0,
    Callback = function(val)
        Config.AimbotFOV = val
    end
})

-- HITBOX EXPANDER (JARAK DAMAGE DIPERBESAR)
Tabs.Combat:AddParagraph({
    Title = "Hitbox Expander (Jarak Damage Diperbesar)",
    Content = "Memperbesar hitbox tubuh zombie agar jangkauan pukulan senjata melee Anda berlipat ganda."
})

local HitboxToggle = Tabs.Combat:AddToggle("HitboxExpanderToggle", {
    Title = "Hitbox Expander (Extended Damage Reach)",
    Description = "Ubah hitbox zombie menjadi kubus raksasa",
    Default = false,
    Callback = function(val)
        Config.HitboxExpander = val
    end
})

local HitboxSizeSlider = Tabs.Combat:AddSlider("HitboxSizeSlider", {
    Title = "Hitbox Expansion Size (Studs)",
    Description = "Ukuran kotak target (Default 12, Rekomendasi 10-18)",
    Default = 12,
    Min = 5,
    Max = 25,
    Rounding = 0,
    Callback = function(val)
        Config.HitboxSize = val
    end
})

-- SURVIVAL & ANTI-DAMAGE
Tabs.Combat:AddParagraph({
    Title = "Survival & Anti-Damage Defense",
    Content = "Mencegah kelaparan dan serangan zombie."
})

local AutoEatToggle = Tabs.Combat:AddToggle("AutoEatToggle", {
    Title = "Auto Eat (Makan Otomatis)",
    Description = "Otomatis makan dari tas saat hunger di bawah 50%",
    Default = false,
    Callback = function(val)
        Config.AutoEat = val
        if val then
            Fluent:Notify({
                Title = "Auto Eat Active",
                Content = string.format("Akan makan otomatis saat hunger <= %d%%!", Config.AutoEatThreshold),
                Duration = 4
            })
        end
    end
})

local AutoEatThresholdSlider = Tabs.Combat:AddSlider("AutoEatThresholdSlider", {
    Title = "Auto Eat Hunger Floor (%)",
    Description = "Batas lapar untuk makan otomatis (Default 50%)",
    Default = 50,
    Min = 20,
    Max = 80,
    Rounding = 0,
    Callback = function(val)
        Config.AutoEatThreshold = val
    end
})

local SafeHoverToggle = Tabs.Combat:AddToggle("SafeHoverToggle", {
    Title = "Safe Hover (Anti-Zombie Touch)",
    Description = "Melayang aman saat zombie mendekat sehingga cakar mereka tidak kena",
    Default = false,
    Callback = function(val)
        Config.SafeHover = val
    end
})

local AutoHealToggle = Tabs.Combat:AddToggle("AutoHealToggle", {
    Title = "Auto Heal (Medkit / Food)",
    Description = "Otomatis menggunakan item penyembuh saat darah sekarat",
    Default = false,
    Callback = function(val)
        Config.AutoHeal = val
    end
})

local InfSprintToggle = Tabs.Combat:AddToggle("InfSprint", {
    Title = "Infinite Sprint (No Stamina / Hunger Floor)",
    Default = false,
    Callback = function(val)
        Config.InfiniteSprint = val
    end
})

local AntiRagdollToggle = Tabs.Combat:AddToggle("AntiRagdoll", {
    Title = "Anti-Ragdoll & Stun Recovery",
    Default = false,
    Callback = function(val)
        Config.AntiRagdoll = val
    end
})

-- TAB 2: BUS & SCAVENGE
Tabs.Bus:AddParagraph({
    Title = "Auto Loot System",
    Content = "Menyedot dan mengambil barang otomatis ke karakter Anda secara berkala."
})

local AutoLootToggle = Tabs.Bus:AddToggle("AutoLootToggle", {
    Title = "Auto Loot (Sedot Barang Otomatis)",
    Description = "Secara otomatis menyedot barang di sekitar ke kaki Anda setiap 1.5 detik",
    Default = false,
    Callback = function(val)
        Config.AutoLoot = val
        if val then
            Fluent:Notify({
                Title = "Auto Loot Active",
                Content = string.format("Menyedot barang kategori [%s] radius %d studs!", Config.AutoLootFilter, Config.AutoLootRange),
                Duration = 4
            })
        end
    end
})

local AutoLootRangeSlider = Tabs.Bus:AddSlider("AutoLootRangeSlider", {
    Title = "Auto Loot Range (Studs)",
    Description = "Jarak sedot barang (Default 50 studs)",
    Default = 50,
    Min = 20,
    Max = 150,
    Rounding = 0,
    Callback = function(val)
        Config.AutoLootRange = val
    end
})

local AutoLootFilterDropdown = Tabs.Bus:AddDropdown("AutoLootFilterDropdown", {
    Title = "Auto Loot Filter",
    Values = {"All", "Valuables", "Fuel", "Weapons", "Medical"},
    Default = "All",
    Callback = function(val)
        Config.AutoLootFilter = val
    end
})

Tabs.Bus:AddParagraph({
    Title = "Instant Loot Actions",
    Content = "Tarik kumpulan barang sekaligus dengan 1 kali klik."
})

Tabs.Bus:AddButton({
    Title = "Bring Valuables to Player (Gold / Silver / Artifacts)",
    Description = "Menyedot semua batangan emas, perak, & piala untuk dijual ke Shopkeeper",
    Callback = function()
        local hrp = GetRootPart()
        if not hrp then return end
        local brought = BringItemsToTarget(function(name, cat)
            return cat == "Valuables"
        end, hrp.CFrame, 600)
        Fluent:Notify({
            Title = "Gold & Valuables Grabber",
            Content = string.format("Berhasil menarik %d item emas & berharga ke kaki Anda!", brought),
            Duration = 4
        })
    end
})

Tabs.Bus:AddButton({
    Title = "Vacuum ALL Nearby Loot (150 Studs)",
    Description = "Brings everything around you to your position",
    Callback = function()
        local hrp = GetRootPart()
        if not hrp then return end
        local brought = BringItemsToTarget(function() return true end, hrp.CFrame, 150)
        Fluent:Notify({
            Title = "Vacuum Loot",
            Content = string.format("Menyedot %d item ke kaki Anda!", brought),
            Duration = 3
        })
    end
})

Tabs.Bus:AddButton({
    Title = "Teleport to Bus",
    Description = "Instantly warp inside the bus cabin",
    Callback = function()
        local bus = GetBusInstance()
        local hrp = GetRootPart()
        if bus and hrp then
            local main = bus.PrimaryPart or bus:FindFirstChild("Main") or bus:FindFirstChildWhichIsA("BasePart")
            if main then
                hrp.CFrame = main.CFrame + Vector3.new(0, 5, 0)
                Fluent:Notify({
                    Title = "Bus Warp",
                    Content = "Teleported to the Bus!",
                    Duration = 3
                })
            end
        else
            Fluent:Notify({
                Title = "Error",
                Content = "Bus not found in map!",
                Duration = 3
            })
        end
    end
})

Tabs.Bus:AddButton({
    Title = "Bring Fuel Cans to Bus Furnace",
    Description = "Vacuums all nearby gas cans straight into the bus",
    Callback = function()
        local bus = GetBusInstance()
        if not bus then return end
        local furnace = bus:FindFirstChild("FurnaceBurn") or bus:FindFirstChild("Fuel") or bus.PrimaryPart
        if furnace then
            local brought = BringItemsToTarget(function(name, cat)
                return cat == "Fuel"
            end, furnace.CFrame, 500)
            Fluent:Notify({
                Title = "Fuel Transferred",
                Content = string.format("Brought %d fuel cans to the bus!", brought),
                Duration = 3
            })
        end
    end
})

Tabs.Bus:AddButton({
    Title = "Bring Wheels to Bus",
    Description = "Transfers all discovered car tires / wheels to the bus",
    Callback = function()
        local bus = GetBusInstance()
        if not bus then return end
        local tiresFolder = bus:FindFirstChild("Tires") or bus.PrimaryPart
        local brought = BringItemsToTarget(function(name, cat)
            return cat == "Wheels"
        end, tiresFolder and tiresFolder.CFrame or bus.PrimaryPart.CFrame, 500)
        Fluent:Notify({
            Title = "Wheels Brought",
            Content = string.format("Brought %d wheels to the bus!", brought),
            Duration = 3
        })
    end
})

-- TAB 3: VISUALS & ESP
Tabs.Visuals:AddToggle("BusESPToggle", {
    Title = "Bus ESP (Never Lose The Bus)",
    Default = false,
    Callback = function(val)
        Config.BusESP = val
    end
})

Tabs.Visuals:AddToggle("EntityESPToggle", {
    Title = "Entity ESP (Zombies / NPCs / Bosses)",
    Default = false,
    Callback = function(val)
        Config.EntityESP = val
    end
})

Tabs.Visuals:AddToggle("ItemESPToggle", {
    Title = "Item & Loot ESP",
    Default = false,
    Callback = function(val)
        Config.ItemESP = val
    end
})

Tabs.Visuals:AddDropdown("ItemFilterDropdown", {
    Title = "Item Filter Category",
    Values = {"All", "Fuel", "Weapons", "Medical", "Wheels", "Valuables"},
    Default = "All",
    Callback = function(val)
        Config.ItemFilter = val
    end
})

Tabs.Visuals:AddParagraph({
    Title = "World Atmosphere",
    Content = "Clear heavy fog and light up the darkness."
})

Tabs.Visuals:AddToggle("FullbrightToggle", {
    Title = "Fullbright (Night Vision)",
    Default = false,
    Callback = function(val)
        Config.Fullbright = val
        UpdateLighting()
    end
})

Tabs.Visuals:AddToggle("NoFogToggle", {
    Title = "Fog Remover & Clear Sky",
    Default = false,
    Callback = function(val)
        Config.NoFog = val
        UpdateLighting()
    end
})

-- TAB 4: MOVEMENT
Tabs.Movement:AddToggle("WalkSpeedToggle", {
    Title = "Enable Custom WalkSpeed",
    Default = false,
    Callback = function(val)
        Config.WalkSpeedEnabled = val
        UpdateSpeeds()
    end
})

Tabs.Movement:AddSlider("WalkSpeedSlider", {
    Title = "WalkSpeed",
    Default = 28,
    Min = 16,
    Max = 120,
    Rounding = 0,
    Callback = function(val)
        Config.WalkSpeed = val
        if Config.WalkSpeedEnabled then
            UpdateSpeeds()
        end
    end
})

Tabs.Movement:AddToggle("JumpPowerToggle", {
    Title = "Enable Custom JumpPower",
    Default = false,
    Callback = function(val)
        Config.JumpPowerEnabled = val
        UpdateSpeeds()
    end
})

Tabs.Movement:AddSlider("JumpPowerSlider", {
    Title = "JumpPower",
    Default = 75,
    Min = 50,
    Max = 200,
    Rounding = 0,
    Callback = function(val)
        Config.JumpPower = val
        if Config.JumpPowerEnabled then
            UpdateSpeeds()
        end
    end
})

Tabs.Movement:AddToggle("NoclipToggle", {
    Title = "Noclip (Walk Through Objects & Barricades)",
    Default = false,
    Callback = function(val)
        Config.Noclip = val
    end
})

Tabs.Movement:AddToggle("FlyToggle", {
    Title = "Flight Mode (WASD + Space/Shift)",
    Default = false,
    Callback = function(val)
        Config.Fly = val
        if val then
            StartFly()
        else
            StopFly()
        end
    end
})

Tabs.Movement:AddSlider("FlySpeedSlider", {
    Title = "Flight Speed",
    Default = 60,
    Min = 20,
    Max = 180,
    Rounding = 0,
    Callback = function(val)
        Config.FlySpeed = val
    end
})

-- TAB 5: TELEPORTS
Tabs.Teleports:AddButton({
    Title = "Teleport to Bus",
    Callback = function()
        local bus = GetBusInstance()
        local hrp = GetRootPart()
        if bus and hrp and bus.PrimaryPart then
            hrp.CFrame = bus.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
        end
    end
})

Tabs.Teleports:AddButton({
    Title = "Teleport to Nearest Fuel Can (GasCan)",
    Callback = function()
        local hrp = GetRootPart()
        local container = workspace:FindFirstChild("ITEM_CONTAINER")
        if not hrp or not container then return end
        
        local nearest, minD = nil, math.huge
        for _, item in ipairs(container:GetChildren()) do
            local clean = GetItemCleanName(item)
            if CategorizeItem(clean, item) == "Fuel" then
                local p, pos = GetPartAndPosition(item)
                if p and pos then
                    local d = (pos - hrp.Position).Magnitude
                    if d < minD then
                        minD = d
                        nearest = p
                    end
                end
            end
        end
        
        if nearest then
            local _, pos = GetPartAndPosition(nearest)
            if pos then
                hrp.CFrame = CFrame.new(pos) + Vector3.new(0, 3, 0)
                Fluent:Notify({ Title = "Teleported", Content = string.format("Warped to Fuel Can (%dm away)!", math.floor(minD)), Duration = 3 })
            end
        else
            Fluent:Notify({ Title = "Notice", Content = "No fuel cans found in map!", Duration = 3 })
        end
    end
})

Tabs.Teleports:AddButton({
    Title = "Teleport to Nearest Medical / Food",
    Callback = function()
        local hrp = GetRootPart()
        local container = workspace:FindFirstChild("ITEM_CONTAINER")
        if not hrp or not container then return end
        
        local nearest, minD = nil, math.huge
        for _, item in ipairs(container:GetChildren()) do
            local clean = GetItemCleanName(item)
            if CategorizeItem(clean, item) == "Medical" then
                local p, pos = GetPartAndPosition(item)
                if p and pos then
                    local d = (pos - hrp.Position).Magnitude
                    if d < minD then
                        minD = d
                        nearest = p
                    end
                end
            end
        end
        
        if nearest then
            local _, pos = GetPartAndPosition(nearest)
            if pos then
                hrp.CFrame = CFrame.new(pos) + Vector3.new(0, 3, 0)
                Fluent:Notify({ Title = "Teleported", Content = string.format("Warped to Healing Item (%dm away)!", math.floor(minD)), Duration = 3 })
            end
        else
            Fluent:Notify({ Title = "Notice", Content = "No medical items found in map!", Duration = 3 })
        end
    end
})

Tabs.Teleports:AddButton({
    Title = "Safe Sky Escape (Escape Horde)",
    Description = "Teleports 45 studs upwards to safety",
    Callback = function()
        local hrp = GetRootPart()
        if hrp then
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 45, 0)
            local hum = GetHumanoid()
            if hum then
                hum.PlatformStand = true
                task.wait(0.1)
                hum.PlatformStand = false
            end
        end
    end
})

-- TAB 6: SETTINGS
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentHub_LastStop")
SaveManager:SetFolder("FluentHub_LastStop/config")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent Hub Updated!",
    Content = "Auto Eat (Hunger < 50%) & Auto Loot are now active!",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()

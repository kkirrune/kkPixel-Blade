-- Single-file HUB: Enhanced Native UI Mode (Volcano Safe)
-- Author: kkirru-style
-- Features: V5 Logic + UI Controls + Automatic Remote Event Discovery + Modern Native UI Style.

local SETTINGS = {
    AuraEnabled = false, AuraRange = 500, AttackDelay = 0.5, AutoBehindTarget = false, AutoMoveToTarget = false,
    AutoSkills = false, AutoHeal = false, AutoHealHPThreshold = 0.75, AutoUpgrade = false, SelectAllBuffs = false,
    FreezeEnemyAI = false, EnemyHitboxScale = 1.0, PlayerHitboxScale = 1.0, AutoDisconnect = false, 
    PANIC_KEY = Enum.KeyCode.Insert, UIVisible = true
}

local REMOTE_NAMES = {
    Attack = nil, 
    Skill = nil,  
    Heal = nil,   
}

-- ==== Roblox Services & Helpers ====
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local pcall = pcall
local os_clock = os.clock
local math_max = math.max
local RNG = Random.new(os.time())
local print = print
local tostring = tostring
local tonumber = tonumber
local string_lower = string.lower

-- [ ... (Phần Logic và Auto Remote Detector giữ nguyên từ V5.5) ... ]

-- V5.6: Khai báo lại các biến logic 
local MIN_ATTACK_DELAY = 0.05 
local BURST_ATTACK_COUNT = 3 
local BURST_DELAY = 0.15 
local ADMIN_KEYWORDS = {"mod", "admin", "dev", "staff", "owner", "helper", "frostblade"} 
local TARGET_CACHE_TIME = 0.5 
local TARGET_CACHE = nil
local lastCacheUpdate = 0
local loopConnection = nil
local AttackRemote = nil
local SkillRemote = nil
local HealRemote = nil

local function random(min, max) return RNG:NextNumber(min, max) end
local function EstimateServerCooldown(baseDelay)
    local ping = game:GetService("Stats").Network.LocalPing:GetValue() or 0.05
    return math_max(baseDelay, 0.05) + ping
end

-- V5.5 Logic: CÁC HÀM TỰ ĐỘNG DÒ TÌM REMOTE (Hooking/Listener)
local function tryHookRemote(remote)
    if remote and remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
        local originalFire = remote.FireServer
        remote.FireServer = function(self, ...)
            local args = {...}
            local remoteName = string_lower(self.Name)

            if not AttackRemote and (remoteName:find("attack") or remoteName:find("damage") or remoteName:find("hit")) then
                AttackRemote = self
                REMOTE_NAMES.Attack = self.Name
                print("!!! Auto Remote Found: Attack/Damage Remote is " .. self.Name .. " !!!")
            elseif not HealRemote and (remoteName:find("heal") or remoteName:find("buff")) and #args == 0 then
                HealRemote = self
                REMOTE_NAMES.Heal = self.Name
                print("!!! Auto Remote Found: Heal/Buff Remote is " .. self.Name .. " !!!")
            elseif not SkillRemote and (remoteName:find("skill") or remoteName:find("ability")) then
                SkillRemote = self
                REMOTE_NAMES.Skill = self.Name
                print("!!! Auto Remote Found: Skill/Ability Remote is " .. self.Name .. " !!!")
            end

            return originalFire(self, unpack(args))
        end
    end
end

local function scanAndHookRemotes()
    local remotes = {}
    local function getChildren(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                table.insert(remotes, child)
            elseif child:IsA("Folder") or child:IsA("Configuration") or child:IsA("Model") or child:IsA("Part") then
                getChildren(child)
            end
        end
    end
    getChildren(ReplicatedStorage)
    getChildren(Workspace)
    if Player then getChildren(Player) end
    for _, remote in ipairs(remotes) do
        tryHookRemote(remote)
    end
end

-- [ ... (Các hàm updateTargetCache, executePanicSwitch, checkA#### giữ nguyên) ... ]

local function updateTargetCache(maxRange)
    if os_clock() - lastCacheUpdate < TARGET_CACHE_TIME then return TARGET_CACHE end
    local localHumanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not localHumanoid or localHumanoid.Health <= 0 then TARGET_CACHE = nil; lastCacheUpdate = os_clock(); return nil end
    local localRoot = Player.Character.PrimaryPart
    local nearestTarget = nil
    local minDistance = maxRange * maxRange 
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v ~= Player.Character and v.PrimaryPart then
            local root = v.PrimaryPart
            if root and localRoot then
                local distance = (root.Position - localRoot.Position).Magnitude
                if distance < maxRange and distance * distance < minDistance then
                    nearestTarget = v
                    minDistance = distance * distance
                end
            end
        end
    end
    TARGET_CACHE = nearestTarget
    lastCacheUpdate = os_clock()
    return nearestTarget
end

local function getTargetPosition(target)
    if target and target.PrimaryPart then
        local targetPos = target.PrimaryPart.Position
        local randomOffset = Vector3.new(random(-5, 5), random(5, 10), random(-5, 5)) 
        local fuzzyTargetPos = targetPos + randomOffset
        if SETTINGS.AutoBehindTarget and Player.Character and Player.Character.PrimaryPart then
            local backVector = target.PrimaryPart.CFrame.lookVector * 5 
            return fuzzyTargetPos - backVector 
        end
        return fuzzyTargetPos
    end
    return nil
end

local function executePanicSwitch(isBanRisk)
    if loopConnection then loopConnection:Disconnect() loopConnection = nil end
    if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
         pcall(function() Player.Character.Humanoid.PlatformStand = false end)
    end
    pcall(function() 
        if Player.Character and Player.Character.HumanoidRootPart then
            Player.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1) 
        end
    end)
    if isBanRisk and SETTINGS.AutoDisconnect then
        warn("ADMIN DETECTED! Executing safe shutdown...")
        pcall(function() game:Shutdown() end) 
    else
        print("!!! Panic switch activated. Exploit disabled. !!!")
        if UI and UI.Toggles then
            pcall(function()
                UI.Toggles.AuraEnabled:SetValue(false)
                UI.Toggles.AutoHeal:SetValue(false)
                UI.Toggles.FreezeEnemyAI:SetValue(false)
            end)
        end
    end
end

local function checkAdmins()
    if os_clock() - (checkAdmins.lastTime or 0) < 5.0 then return end
    checkAdmins.lastTime = os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Player then
            local name = player.Name:lower()
            local displayName = player.DisplayName:lower()
            for _, keyword in ipairs(ADMIN_KEYWORDS) do
                if name:find(keyword) or displayName:find(keyword) then
                    print("!!! ADMIN/MOD DETECTED: " .. player.Name .. " !!!")
                    executePanicSwitch(true)
                    return
                end
            end
        end
    end
end

local function startLoop()
    if loopConnection then loopConnection:Disconnect() end
    local lastAttackTime = 0
    local burstCounter = 0
    local lastSkillTime = 0
    local lastHealTime = 0
    local lastFreezeTime = 0
    loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
        local timeNow = os.clock()
        local char = Player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not humanoid or humanoid.Health <= 0 or not char.PrimaryPart then return end
        local target = updateTargetCache(SETTINGS.AuraRange)

        -- 1. Kill Aura/Auto Attack
        local currentAttackDelay = SETTINGS.AttackDelay
        if SETTINGS.AuraEnabled and target and AttackRemote then
            if burstCounter > 0 then
                local jitterDelay = random(currentAttackDelay * 0.9, currentAttackDelay * 1.05)
                if timeNow - lastAttackTime >= jitterDelay then
                    pcall(AttackRemote.FireServer, AttackRemote, target) 
                    lastAttackTime = timeNow
                    burstCounter = burstCounter - 1
                end
            else
                local jitterBurstDelay = random(BURST_DELAY * 0.9, BURST_DELAY * 1.1)
                if timeNow - lastAttackTime >= jitterBurstDelay then burstCounter = BURST_ATTACK_COUNT end
            end
        end

        -- Auto Move 
        if SETTINGS.AutoMoveToTarget and target and target.PrimaryPart then
            local targetPos = getTargetPosition(target)
            local currentPos = char.PrimaryPart.Position
            local distance = (targetPos - currentPos).Magnitude
            if distance > 1.0 then 
                local moveVector = (targetPos - currentPos).Unit * 0.5 
                local newCFrame = CFrame.new(currentPos + moveVector)
                pcall(function() char:SetPrimaryPartCFrame(newCFrame) end) 
            end
        end

        if SETTINGS.AutoSkills and SkillRemote and (timeNow - lastSkillTime > EstimateServerCooldown(random(0.2, 0.3))) then 
            pcall(SkillRemote.FireServer, SkillRemote, "AllSkills") 
            lastSkillTime = timeNow
        end
        
        local currentHPPercent = humanoid.Health / humanoid.MaxHealth
        local healThreshold = SETTINGS.AutoHealHPThreshold 

        if SETTINGS.AutoHeal and HealRemote and currentHPPercent < healThreshold and (timeNow - lastHealTime > 5.0) then
            pcall(HealRemote.FireServer, HealRemote)
            lastHealTime = timeNow
        end

        if SETTINGS.FreezeEnemyAI and (timeNow - lastFreezeTime > 0.5) then
            delay(0, function() 
                for _, v in ipairs(Workspace:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v ~= char then
                        local h = v.Humanoid
                        pcall(function()
                            h.WalkSpeed = 0 
                            h.JumpPower = 0  
                        end)
                    end
                end
                lastFreezeTime = timeNow
            end)
        end
        
        -- 5. V4 Admin Check
        checkAdmins()
    end)
end

local function updateLoopStatus()
    local shouldRun = SETTINGS.AuraEnabled or SETTINGS.AutoSkills or SETTINGS.AutoHeal or SETTINGS.FreezeEnemyAI
    if shouldRun and not loopConnection then
        startLoop()
        print("Farm loop started.")
    elseif not shouldRun and loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
        print("Farm loop stopped.")
    end
end


-- === [ Enhanced Native UI Creator ] ===
local UI = {}
local ACCENT_COLOR = Color3.fromRGB(207, 48, 74) -- Linoria-style Red/Pink
local BG_COLOR = Color3.fromRGB(30, 30, 30)
local FRAME_COLOR = Color3.fromRGB(40, 40, 40)
local TOGGLE_ON = Color3.fromRGB(48, 207, 74)
local TOGGLE_OFF = ACCENT_COLOR

local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PixelBlade_V5_6_UI"
    ScreenGui.Parent = CoreGui
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 320, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210)
    MainFrame.BackgroundColor3 = FRAME_COLOR
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    UI.MainFrame = MainFrame
    
    -- Add UICorner for modern look
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = MainFrame

    -- Title Bar (With gradient)
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "PIXEL BLADE V5.6 (Enhanced UI)"
    Title.Font = Enum.Font.SourceSansBold
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundColor3 = ACCENT_COLOR
    Title.TextSize = 18
    Title.Parent = MainFrame
    
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, ACCENT_COLOR),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 100, 150)) -- Lighter accent
    })
    Gradient.Parent = Title

    -- Scroll Frame for contents
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, 0, 1, -30)
    Scroll.Position = UDim2.new(0, 0, 0, 30)
    Scroll.BackgroundColor3 = BG_COLOR
    Scroll.BorderSizePixel = 0
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 750)
    Scroll.Parent = MainFrame
    
    local UILayout = Instance.new("UIListLayout")
    UILayout.FillDirection = Enum.FillDirection.Vertical
    UILayout.Padding = UDim.new(0, 8)
    UILayout.Parent = Scroll
    
    local UI_Padding = Instance.new("UIPadding")
    UI_Padding.PaddingTop = UDim.new(0, 10)
    UI_Padding.PaddingBottom = UDim.new(0, 10)
    UI_Padding.PaddingLeft = UDim.new(0, 10)
    UI_Padding.PaddingRight = UDim.new(0, 10)
    UI_Padding.Parent = Scroll

    -- Helper function to create a labeled toggle (styled)
    local function createToggle(name, settingKey)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 35) -- Apply padding via size
        frame.BackgroundColor3 = FRAME_COLOR
        frame.Parent = Scroll
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Text = name
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundColor3 = FRAME_COLOR
        label.TextSize = 15
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        label.Parent = frame
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.3, -10, 0.7, 0)
        button.Position = UDim2.new(0.7, 5, 0.5, -0.5 * button.Size.Y.Offset)
        button.Text = (SETTINGS[settingKey] and "ON") or "OFF"
        button.Font = Enum.Font.SourceSansBold
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 16
        button.BackgroundColor3 = (SETTINGS[settingKey] and TOGGLE_ON) or TOGGLE_OFF
        button.Parent = frame
        
        local CornerBtn = Instance.new("UICorner")
        CornerBtn.CornerRadius = UDim.new(0, 4)
        CornerBtn.Parent = button

        local function updateToggle(value)
            SETTINGS[settingKey] = value
            button.Text = value and "ON" or "OFF"
            button.BackgroundColor3 = value and TOGGLE_ON or TOGGLE_OFF
            updateLoopStatus() 
        end

        button.MouseButton1Click:Connect(function()
            updateToggle(not SETTINGS[settingKey])
        end)
        
        return {Frame = frame, SetValue = updateToggle, TextButton = button}
    end

    -- Helper function to create a labeled slider (styled)
    local function createSlider(name, settingKey, minVal, maxVal, step, suffix)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 50)
        frame.BackgroundColor3 = FRAME_COLOR
        frame.Parent = Scroll

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 15)
        label.Text = name .. ": " .. tostring(SETTINGS[settingKey]) .. suffix
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundColor3 = FRAME_COLOR
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Position = UDim2.new(0, 5, 0, 0)
        label.Parent = frame
        
        local slider = Instance.new("TextBox")
        slider.Size = UDim2.new(1, -10, 0, 25)
        slider.Position = UDim2.new(0, 5, 0, 20)
        slider.Text = tostring(SETTINGS[settingKey])
        slider.Font = Enum.Font.SourceSans
        slider.TextColor3 = Color3.fromRGB(20, 20, 20)
        slider.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
        slider.TextSize = 14
        slider.Parent = frame
        
        local CornerSlider = Instance.new("UICorner")
        CornerSlider.CornerRadius = UDim.new(0, 4)
        CornerSlider.Parent = slider

        slider.FocusLost:Connect(function(enterPressed)
            local newVal = tonumber(slider.Text)
            if newVal then
                newVal = math_max(minVal, math.min(maxVal, newVal))
                newVal = math.floor(newVal / step + 0.5) * step 
                
                SETTINGS[settingKey] = newVal
                slider.Text = tostring(newVal)
                label.Text = name .. ": " .. tostring(newVal) .. suffix
            else
                slider.Text = tostring(SETTINGS[settingKey])
            end
        end)
        
        return {Frame = frame, SetValue = function(val) 
            SETTINGS[settingKey] = val 
            slider.Text = tostring(val)
            label.Text = name .. ": " .. tostring(val) .. suffix
        end}
    end

    -- Helper function to create a section header
    local function createHeader(text)
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -20, 0, 25)
        header.Text = text
        header.Font = Enum.Font.SourceSansBold
        header.TextColor3 = Color3.fromRGB(255, 255, 255)
        header.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        header.TextSize = 16
        header.Parent = Scroll
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = header
        
        return header
    end
    
    UI.Toggles = {}
    UI.Sliders = {}

    -- === FARM SECTION ===
    createHeader("FARM PIXEL BLADE (V5 ANTI-BAN)")
    UI.Toggles.AuraEnabled = createToggle("BẬT KILL AURA", "AuraEnabled")
    UI.Sliders.AuraRange = createSlider("Phạm vi Aura", "AuraRange", 100, 1000, 10, " Studs")
    UI.Sliders.AttackDelay = createSlider("Tốc độ Đánh", "AttackDelay", 0.05, 1.0, 0.05, " s")
    UI.Toggles.AutoMoveToTarget = createToggle("Auto Dịch Chuyển Quái (TP)", "AutoMoveToTarget")
    UI.Toggles.AutoBehindTarget = createToggle("Auto Đứng Đằng Sau Quái", "AutoBehindTarget")
    
    -- === SKILL/HEAL SECTION ===
    createHeader("KỸ NĂNG & HỒI PHỤC")
    UI.Toggles.AutoHeal = createToggle("Auto Buff Máu Siêu Cấp", "AutoHeal")
    UI.Sliders.AutoHealHPThreshold = createSlider("Ngưỡng HP Buff", "AutoHealHPThreshold", 0.1, 0.9, 0.05, " (0.0 - 1.0)")
    UI.Toggles.AutoSkills = createToggle("Auto Tất Cả Skills", "AutoSkills")

    -- === EXPLOIT/STEALTH SECTION ===
    createHeader("STEALTH & ADMIN EVASION")
    UI.Toggles.FreezeEnemyAI = createToggle("Khống Chế Quái (Đóng Băng)", "FreezeEnemyAI")
    UI.Sliders.EnemyHitboxScale = createSlider("Giảm Hitbox Quái", "EnemyHitboxScale", 0.5, 1.0, 0.1, "x")
    UI.Sliders.PlayerHitboxScale = createSlider("Tăng Hitbox Người Chơi", "PlayerHitboxScale", 1.0, 1.5, 0.1, "x")
    UI.Toggles.AutoDisconnect = createToggle("Tự động Rời khi có Admin", "AutoDisconnect")

    -- === FOOTER/PANIC SECTION ===
    local Footer = createHeader("Phím Tắt: " .. SETTINGS.PANIC_KEY.Name .. " (Ẩn UI/Ngắt Khẩn Cấp)")
    Footer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    
    -- Dragging functionality for the MainFrame
    local drag = false
    local dragStart = Vector2.new(0, 0)
    local dragOffset = UDim2.new(0, 0, 0, 0)
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dragStart = input.Position
            dragOffset = MainFrame.Position
        end
    end)

    Title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and drag then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(0, dragOffset.X.Offset + delta.X, 0, dragOffset.Y.Offset + delta.Y)
        end
    end)

    return ScreenGui
end

-- Khởi tạo UI
pcall(createUI)
if UI.MainFrame then
    UI.MainFrame.Visible = SETTINGS.UIVisible
end

-- Khởi tạo Panic Key Bind (Ẩn UI và Ngắt Khẩn Cấp)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == SETTINGS.PANIC_KEY then
        if UI.MainFrame then
            SETTINGS.UIVisible = not SETTINGS.UIVisible
            UI.MainFrame.Visible = SETTINGS.UIVisible
        end
        executePanicSwitch(false) 
    end
end)

-- Khởi tạo Loop và Hook Remotes
scanAndHookRemotes()
updateLoopStatus()

print("-------------------------------------------------------")
print("KKPIXEL_BLADE_V5.6: Enhanced Native UI (Volcano Safe) LOADED")
print("VUI LÒNG TỰ TẤN CÔNG/DÙNG SKILL MỘT LẦN ĐỂ KÍCH HOẠT FARM.")
print("-------------------------------------------------------")

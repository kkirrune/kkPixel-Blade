-- Single-file HUB: Enhanced Native UI Mode (Volcano Safe)
-- Author: kkirru-style (ChatGPT)
-- Version: V5.7 (Stable) — Hitbox + MoveSpeed + AutoAttack + GomQuai grouped, Burst dual-bar UI

local SETTINGS = {
    -- Auto Farm
    AuraEnabled = false,
    AuraRange = 500,
    AttackDelay = 0.5,
    AutoBehindTarget = false,
    AutoMoveToTarget = false,

    -- Skills & Heal
    AutoSkills = false,
    AutoHeal = false,
    AutoHealHPThreshold = 0.75,
    AutoUpgrade = false,
    SelectAllBuffs = false,

    -- Exploit & Anti-Ban / Grouped Controls
    FreezeEnemyAI = false,
    EnemyHitboxScale = 1.0,
    PlayerHitboxScale = 1.0,
    AutoDisconnect = false,
    HitboxScaleChangeInterval = 10, -- giây giữa 2 lần thay đổi hitbox
    MoveSpeedLimit = 5, -- giới hạn tốc độ di chuyển (studs per step)
    GomQuaiEnabled = false,
    GomQuaiRange = 50,
    GomQuaiDelay = 2.0, -- delay giữa mỗi lần gom quái

    -- Burst / Combo
    BurstEnabled = true,
    BurstCount = 3,
    BurstDelay = 0.15,
    BurstCooldown = 1.0, -- thời gian nạp lại thanh burst

    -- UI & Panic
    PANIC_KEY = Enum.KeyCode.Insert,
    UIVisible = true
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
local StatsService = game:GetService("Stats")

local Player = Players.LocalPlayer

local pcall = pcall
local os_clock = os.clock
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local RNG = Random.new(os.time())
local print = print
local tostring = tostring
local tonumber = tonumber
local string_lower = string.lower
local table_unpack = table.unpack

-- V5.7 Stable: Khai báo lại các biến logic
local MIN_ATTACK_DELAY = 0.05
local ADMIN_KEYWORDS = {"mod", "admin", "dev", "staff", "owner", "helper", "frostblade"}
local TARGET_CACHE_TIME = 0.5
local TARGET_CACHE = nil
local lastCacheUpdate = 0
local loopConnection = nil
local AttackRemote = nil
local SkillRemote = nil
local HealRemote = nil
local lastHitboxChangeTime = 0
local lastGomQuaiTime = 0

-- Burst state (server-agnostic local charge)
local burstCharge = 0
local lastBurstUse = 0

local function random(min, max) return RNG:NextNumber(min, max) end
local function EstimateServerCooldown(baseDelay)
    local ok, pingVal = pcall(function() return StatsService.Network.LocalPing:GetValue() end)
    local ping = (ok and pingVal) or 0.05
    return math_max(baseDelay, 0.05) + ping
end

-- Safe hook: support RemoteEvent (:FireServer) and RemoteFunction (:InvokeServer)
local function tryHookRemote(remote)
    if not remote then return end
    if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then return end

    local remoteNameLower = string_lower(remote.Name or "")

    if remote:IsA("RemoteEvent") then
        local originalFire = remote.FireServer
        if type(originalFire) ~= "function" then return end

        remote.FireServer = function(self, ...)
            local args = {...}
            local remoteName = string_lower(self.Name or "")

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

            return originalFire(self, table_unpack(args))
        end

    elseif remote:IsA("RemoteFunction") then
        local originalInvoke = remote.InvokeServer
        if type(originalInvoke) ~= "function" then return end

        remote.InvokeServer = function(self, ...)
            local args = {...}
            local remoteName = string_lower(self.Name or "")

            if not AttackRemote and (remoteName:find("attack") or remoteName:find("damage") or remoteName:find("hit")) then
                AttackRemote = self
                REMOTE_NAMES.Attack = self.Name
                print("!!! Auto Remote Found (Function): Attack/Damage Remote is " .. self.Name .. " !!!")
            elseif not HealRemote and (remoteName:find("heal") or remoteName:find("buff")) and #args == 0 then
                HealRemote = self
                REMOTE_NAMES.Heal = self.Name
                print("!!! Auto Remote Found (Function): Heal/Buff Remote is " .. self.Name .. " !!!")
            elseif not SkillRemote and (remoteName:find("skill") or remoteName:find("ability")) then
                SkillRemote = self
                REMOTE_NAMES.Skill = self.Name
                print("!!! Auto Remote Found (Function): Skill/Ability Remote is " .. self.Name .. " !!!")
            end

            return originalInvoke(self, table_unpack(args))
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
                -- dive deeper but avoid infinite recursion
                pcall(function() getChildren(child) end)
            end
        end
    end
    pcall(function() getChildren(ReplicatedStorage) end)
    pcall(function() getChildren(Workspace) end)
    if Player then pcall(function() getChildren(Player) end) end
    for _, remote in ipairs(remotes) do
        pcall(function() tryHookRemote(remote) end)
    end
end

-- Update target cache (use magnitude consistently)
local function updateTargetCache(maxRange)
    if os_clock() - lastCacheUpdate < TARGET_CACHE_TIME then return TARGET_CACHE end
    local localHumanoid = Player and Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not localHumanoid or localHumanoid.Health <= 0 then TARGET_CACHE = nil; lastCacheUpdate = os_clock(); return nil end
    local localRoot = Player.Character and Player.Character.PrimaryPart
    if not localRoot then TARGET_CACHE = nil; lastCacheUpdate = os_clock(); return nil end

    local nearestTarget = nil
    local minDistance = maxRange

    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v ~= Player.Character and v.PrimaryPart then
            local root = v.PrimaryPart
            if root and localRoot then
                local distance = (root.Position - localRoot.Position).Magnitude
                if distance < maxRange and distance < minDistance then
                    nearestTarget = v
                    minDistance = distance
                end
            end
        end
    end

    TARGET_CACHE = nearestTarget
    lastCacheUpdate = os_clock()
    return nearestTarget
end

-- Lấy vị trí mục tiêu với offset / đứng sau nếu bật
local function getTargetPosition(target)
    if target and target.PrimaryPart then
        local targetPos = target.PrimaryPart.Position
        local randomOffset = Vector3.new(random(-5, 5), random(5, 10), random(-5, 5))
        local fuzzyTargetPos = targetPos + randomOffset
        if SETTINGS.AutoBehindTarget and Player and Player.Character and Player.Character.PrimaryPart then
            local backVector = target.PrimaryPart.CFrame.LookVector * 5
            return fuzzyTargetPos - backVector
        end
        return fuzzyTargetPos
    end
    return nil
end

-- Panic / safe shutdown
local function executePanicSwitch(isBanRisk)
    if loopConnection then loopConnection:Disconnect() loopConnection = nil end
    if Player and Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
        pcall(function() Player.Character.Humanoid.PlatformStand = false end)
    end
    pcall(function()
        if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            -- reset size to sane default
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
                if UI.Toggles.AuraEnabled then UI.Toggles.AuraEnabled.SetValue(false) end
                if UI.Toggles.AutoHeal then UI.Toggles.AutoHeal.SetValue(false) end
                if UI.Toggles.FreezeEnemyAI then UI.Toggles.FreezeEnemyAI.SetValue(false) end
            end)
        end
    end
end

-- Admin check (simple, low frequency)
local function checkAdmins()
    if os_clock() - (checkAdmins.lastTime or 0) < 5.0 then return end
    checkAdmins.lastTime = os_clock()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Player then
            local ok, name = pcall(function() return player.Name:lower() end)
            local ok2, dname = pcall(function() return player.DisplayName:lower() end)
            local nameStr = ok and name or ""
            local displayName = ok2 and dname or ""
            for _, keyword in ipairs(ADMIN_KEYWORDS) do
                if nameStr:find(keyword) or displayName:find(keyword) then
                    print("!!! ADMIN/MOD DETECTED: " .. (player.Name or "Unknown") .. " !!!")
                    executePanicSwitch(true)
                    return
                end
            end
        end
    end
end

-- Gom quái (throttled theo GomQuaiDelay)
local function gomQuai()
    if not SETTINGS.GomQuaiEnabled then return end
    if not Player or not Player.Character or not Player.Character.PrimaryPart then return end
    if os_clock() - lastGomQuaiTime < SETTINGS.GomQuaiDelay then return end
    lastGomQuaiTime = os_clock()

    local char = Player.Character
    local rootPart = char.PrimaryPart
    local gomRange = SETTINGS.GomQuaiRange

    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and v ~= char and v.PrimaryPart then
            local targetRootPart = v.PrimaryPart
            local distance = (rootPart.Position - targetRootPart.Position).Magnitude
            if distance <= gomRange then
                local newPos = rootPart.Position + Vector3.new(random(-2, 2), 0, random(-2, 2))
                pcall(function()
                    -- Try set PrimaryPart CFrame; many games allow this, some don't.
                    if v.PrimaryPart and v:IsA("Model") then
                        v:SetPrimaryPartCFrame(CFrame.new(newPos))
                    end
                end)
            end
        end
    end
end

-- Giới hạn di chuyển với an toàn (tránh Unit khi distance = 0)
local function limitMoveSpeed(targetPos, currentPos, maxSpeed)
    local delta = targetPos - currentPos
    local dist = delta.Magnitude
    if dist == 0 or maxSpeed <= 0 then return currentPos end
    local direction = delta.Unit
    -- moveDist: mỗi bước Heartbeat ta giới hạn di chuyển
    local moveDist = math_min(maxSpeed, dist)
    local moveVector = direction * moveDist
    return currentPos + moveVector
end

-- Thay đổi hitbox an toàn (throttled)
local function applyHitboxScale(scale)
    if not Player or not Player.Character then return end
    if os_clock() - lastHitboxChangeTime < SETTINGS.HitboxScaleChangeInterval then return end
    lastHitboxChangeTime = os_clock()
    pcall(function()
        local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then
            -- Một số game không cho phép thay kích thước trực tiếp; nếu lỗi thì pcall sẽ bắt
            hrp.Size = Vector3.new(2 * scale, 2 * scale, 1 * scale)
        end
    end)
end

-- Safe call to remote (supports both Event and Function)
local function safeFireRemote(remote, ...)
    if not remote then return end
    pcall(function()
        if remote.FireServer then
            remote:FireServer(...)
        elseif remote.InvokeServer then
            remote:InvokeServer(...)
        end
    end)
end

-- Start main loop (Stable: throttled, safe)
local function startLoop()
    if loopConnection then loopConnection:Disconnect() end
    local lastAttackTime = 0
    local burstCounter = 0
    local lastSkillTime = 0
    local lastHealTime = 0
    local lastFreezeTime = 0
    local lastHitboxTimeLocal = 0

    -- initialize burstCharge
    burstCharge = SETTINGS.BurstCount
    lastBurstUse = 0

    loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
        local timeNow = os_clock()
        local char = Player and Player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not humanoid or humanoid.Health <= 0 or not char.PrimaryPart then return end

        -- Refill burst charge slowly (BurstCooldown defines full refill time)
        if SETTINGS.BurstEnabled and SETTINGS.BurstCount and SETTINGS.BurstCooldown and burstCharge < SETTINGS.BurstCount then
            local refillPerSec = SETTINGS.BurstCount / math_max(0.0001, SETTINGS.BurstCooldown)
            burstCharge = math_min(SETTINGS.BurstCount, burstCharge + refillPerSec * deltaTime)
        end

        local target = updateTargetCache(SETTINGS.AuraRange)

        -- 1. Kill Aura / Auto Attack with Burst logic
        local currentAttackDelay = math_max(SETTINGS.AttackDelay, MIN_ATTACK_DELAY)
        if SETTINGS.AuraEnabled and target and AttackRemote then
            if burstCounter > 0 then
                local jitterDelay = random(currentAttackDelay * 0.9, currentAttackDelay * 1.05)
                if timeNow - lastAttackTime >= jitterDelay then
                    safeFireRemote(AttackRemote, target)
                    lastAttackTime = timeNow
                    burstCounter = burstCounter - 1
                end
            else
                -- Only trigger a burst if we have at least 1 full "charge" available
                if SETTINGS.BurstEnabled and burstCharge >= 1 then
                    -- apply a small jitter before burst
                    local jitterBurstDelay = random(SETTINGS.BurstDelay * 0.9, SETTINGS.BurstDelay * 1.1)
                    if timeNow - lastAttackTime >= jitterBurstDelay then
                        burstCounter = SETTINGS.BurstCount
                        burstCharge = math_max(0, burstCharge - 1) -- consume one charge to do a burst
                        lastBurstUse = timeNow
                    end
                else
                    -- Normal single attack when burst disabled or no charge
                    if timeNow - lastAttackTime >= currentAttackDelay then
                        safeFireRemote(AttackRemote, target)
                        lastAttackTime = timeNow
                    end
                end
            end
        end

        -- Auto Move To Target (throttled & limited)
        if SETTINGS.AutoMoveToTarget and target and target.PrimaryPart then
            local targetPos = getTargetPosition(target)
            if targetPos then
                local currentPos = char.PrimaryPart.Position
                local limitedPos = limitMoveSpeed(targetPos, currentPos, SETTINGS.MoveSpeedLimit * deltaTime * 60) -- scale by frame/time to be smoother
                if (limitedPos - currentPos).Magnitude > 0.001 then
                    pcall(function()
                        char:SetPrimaryPartCFrame(CFrame.new(limitedPos))
                    end)
                end
            end
        end

        -- Auto Skills
        if SETTINGS.AutoSkills and SkillRemote and (timeNow - lastSkillTime > EstimateServerCooldown(random(0.2, 0.3))) then
            safeFireRemote(SkillRemote, "AllSkills")
            lastSkillTime = timeNow
        end

        -- Auto Heal
        local currentHPPercent = humanoid.Health / math_max(1, humanoid.MaxHealth)
        local healThreshold = SETTINGS.AutoHealHPThreshold
        if SETTINGS.AutoHeal and HealRemote and currentHPPercent < healThreshold and (timeNow - lastHealTime > 5.0) then
            safeFireRemote(HealRemote)
            lastHealTime = timeNow
        end

        -- Freeze Enemy AI (lightweight)
        if SETTINGS.FreezeEnemyAI and (timeNow - lastFreezeTime > 0.5) then
            lastFreezeTime = timeNow
            delay(0, function()
                for _, v in ipairs(Workspace:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v ~= char then
                        local h = v.Humanoid
                        pcall(function()
                            if h then
                                if h.RootPart then
                                    -- Attempt to slowdown instead of hard zero to be safer
                                    h.WalkSpeed = 0
                                    h.JumpPower = 0
                                else
                                    h.WalkSpeed = 0
                                    h.JumpPower = 0
                                end
                            end
                        end)
                    end
                end
            end)
        end

        -- Hitbox scaling (throttled)
        if SETTINGS.PlayerHitboxScale and (timeNow - lastHitboxTimeLocal > 0.1) then
            lastHitboxTimeLocal = timeNow
            applyHitboxScale(SETTINGS.PlayerHitboxScale)
        end

        -- Gom quái
        if SETTINGS.GomQuaiEnabled then
            gomQuai()
        end

        -- Admin check (low frequency)
        checkAdmins()

        -- Update UI bars if present
        if UI and UI.Bars then
            -- Burst bar: normalized 0..1
            if UI.Bars.BurstBar and SETTINGS.BurstEnabled then
                local normalizedBurst = math_min(1, math_max(0, burstCharge / math_max(1, SETTINGS.BurstCount)))
                pcall(function()
                    UI.Bars.BurstBar.Size = UDim2.new(normalizedBurst, 0, 1, 0)
                    UI.Bars.BurstLabel.Text = ("Burst: %d/%d"):format(math_floor(burstCharge + 0.5), SETTINGS.BurstCount)
                end)
            end
            -- Hitbox bar: show current scale relative to [1.0 .. 1.5]
            if UI.Bars.HitboxBar then
                local minScale = 1.0
                local maxScale = 1.5
                local clamped = math_min(maxScale, math_max(minScale, SETTINGS.PlayerHitboxScale))
                local normalizedHB = (clamped - minScale) / (maxScale - minScale)
                pcall(function()
                    UI.Bars.HitboxBar.Size = UDim2.new(normalizedHB, 0, 1, 0)
                    UI.Bars.HitboxLabel.Text = ("Hitbox: %.2fx"):format(SETTINGS.PlayerHitboxScale)
                end)
            end
        end
    end)
end

local function updateLoopStatus()
    local shouldRun = SETTINGS.AuraEnabled or SETTINGS.AutoSkills or SETTINGS.AutoHeal or SETTINGS.FreezeEnemyAI or SETTINGS.GomQuaiEnabled
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
    ScreenGui.Name = "PixelBlade_V5_7_UI"
    -- Prefer PlayerGui; fallback to CoreGui if not available
    local successParent = pcall(function()
        ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end)
    if not successParent then
        ScreenGui.Parent = CoreGui
    end

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 340, 0, 480)
    MainFrame.Position = UDim2.new(0.5, -170, 0.5, -240)
    MainFrame.BackgroundColor3 = FRAME_COLOR
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    UI.MainFrame = MainFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = MainFrame

    -- Title Bar
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 34)
    Title.Text = "PIXEL BLADE V5.7 (Stable)"
    Title.Font = Enum.Font.SourceSansBold
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundColor3 = ACCENT_COLOR
    Title.TextSize = 18
    Title.Parent = MainFrame

    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, ACCENT_COLOR),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 100, 150))
    })
    Gradient.Parent = Title

    -- Scroll Frame for contents
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, 0, 1, -34)
    Scroll.Position = UDim2.new(0, 0, 0, 34)
    Scroll.BackgroundColor3 = BG_COLOR
    Scroll.BorderSizePixel = 0
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 900)
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

    -- Helper Toggle
    local function createToggle(name, settingKey)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 36)
        frame.BackgroundColor3 = FRAME_COLOR
        frame.Parent = Scroll

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.65, 0, 1, 0)
        label.Text = name
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundColor3 = FRAME_COLOR
        label.TextSize = 15
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        label.Parent = frame

        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.35, -10, 0.7, 0)
        button.Position = UDim2.new(0.65, 5, 0.5, -0.5 * 24)
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

    -- Helper Slider (textbox-style)
    local function createSlider(name, settingKey, minVal, maxVal, step, suffix)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 52)
        frame.BackgroundColor3 = FRAME_COLOR
        frame.Parent = Scroll

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 16)
        label.Text = name .. ": " .. tostring(SETTINGS[settingKey]) .. (suffix or "")
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundColor3 = FRAME_COLOR
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Position = UDim2.new(0, 5, 0, 0)
        label.Parent = frame

        local slider = Instance.new("TextBox")
        slider.Size = UDim2.new(1, -10, 0, 28)
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
                newVal = math_max(minVal, math_min(maxVal, newVal))
                if step and step > 0 then
                    newVal = math_floor(newVal / step + 0.5) * step
                end
                SETTINGS[settingKey] = newVal
                slider.Text = tostring(newVal)
                label.Text = name .. ": " .. tostring(newVal) .. (suffix or "")
                updateLoopStatus()
            else
                slider.Text = tostring(SETTINGS[settingKey])
            end
        end)

        return {Frame = frame, SetValue = function(val)
            SETTINGS[settingKey] = val
            slider.Text = tostring(val)
            label.Text = name .. ": " .. tostring(val) .. (suffix or "")
            updateLoopStatus()
        end}
    end

    local function createHeader(text)
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -20, 0, 26)
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

    -- Start building UI sections
    UI.Toggles = {}
    UI.Sliders = {}
    UI.Bars = {}

    createHeader("FARM PIXEL BLADE (V5 STABLE)")
    UI.Toggles.AuraEnabled = createToggle("BẬT KILL AURA", "AuraEnabled")
    UI.Sliders.AuraRange = createSlider("Phạm vi Aura", "AuraRange", 100, 2000, 10, " Studs")
    UI.Sliders.AttackDelay = createSlider("Tốc độ Đánh (s)", "AttackDelay", 0.05, 1.0, 0.01, " s")
    UI.Toggles.AutoMoveToTarget = createToggle("Auto Dịch Chuyển Quái (TP)", "AutoMoveToTarget")
    UI.Toggles.AutoBehindTarget = createToggle("Auto Đứng Đằng Sau Quái", "AutoBehindTarget")

    createHeader("KỸ NĂNG & HỒI PHỤC")
    UI.Toggles.AutoHeal = createToggle("Auto Buff/Heal", "AutoHeal")
    UI.Sliders.AutoHealHPThreshold = createSlider("Ngưỡng HP Buff", "AutoHealHPThreshold", 0.1, 0.95, 0.05, " (0.0 - 1.0)")
    UI.Toggles.AutoSkills = createToggle("Auto Tất Cả Skills", "AutoSkills")

    createHeader("STEALTH, HITBOX & MOVEMENT (Grouped)")
    UI.Toggles.FreezeEnemyAI = createToggle("Khống Chế Quái (Đóng Băng)", "FreezeEnemyAI")
    UI.Sliders.EnemyHitboxScale = createSlider("Giảm Hitbox Quái", "EnemyHitboxScale", 0.5, 1.0, 0.1, "x")
    UI.Sliders.PlayerHitboxScale = createSlider("Tăng Hitbox Người Chơi", "PlayerHitboxScale", 1.0, 1.5, 0.05, "x")
    UI.Sliders.HitboxChangeInterval = createSlider("Hitbox Change Interval", "HitboxScaleChangeInterval", 1, 60, 1, " s")
    UI.Sliders.MoveSpeedLimit = createSlider("Move Speed Limit (studs/frame equiv)", "MoveSpeedLimit", 1, 20, 0.5, " x")
    UI.Toggles.AutoDisconnect = createToggle("Tự động Rời khi có Admin", "AutoDisconnect")

    createHeader("GOM QUÁI & BURST (Grouped)")
    UI.Toggles.GomQuaiEnabled = createToggle("Bật Gom Quái", "GomQuaiEnabled")
    UI.Sliders.GomQuaiRange = createSlider("Phạm vi Gom", "GomQuaiRange", 10, 200, 1, " Studs")
    UI.Sliders.GomQuaiDelay = createSlider("Gom Delay", "GomQuaiDelay", 0.1, 10, 0.1, " s")

    UI.Toggles.BurstEnabled = createToggle("Bật Burst Combo", "BurstEnabled")
    UI.Sliders.BurstCount = createSlider("Số lần trong 1 Burst", "BurstCount", 1, 8, 1, " hits")
    UI.Sliders.BurstDelay = createSlider("Delay giữa hit trong Burst", "BurstDelay", 0.01, 0.5, 0.01, " s")
    UI.Sliders.BurstCooldown = createSlider("Burst Cooldown (full)", "BurstCooldown", 0.5, 10, 0.1, " s")

    -- Dual bars: Burst charge + Hitbox visual
    local barFrame = Instance.new("Frame")
    barFrame.Size = UDim2.new(1, -20, 0, 60)
    barFrame.BackgroundColor3 = FRAME_COLOR
    barFrame.Parent = Scroll

    local CornerBarFrame = Instance.new("UICorner")
    CornerBarFrame.CornerRadius = UDim.new(0, 6)
    CornerBarFrame.Parent = barFrame

    -- Burst bar background
    local burstBg = Instance.new("Frame")
    burstBg.Size = UDim2.new(1, -20, 0, 20)
    burstBg.Position = UDim2.new(0, 10, 0, 6)
    burstBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    burstBg.Parent = barFrame

    local burstFill = Instance.new("Frame")
    burstFill.Size = UDim2.new(0, 0, 1, 0)
    burstFill.BackgroundColor3 = TOGGLE_ON
    burstFill.BorderSizePixel = 0
    burstFill.Parent = burstBg

    local burstLabel = Instance.new("TextLabel")
    burstLabel.Size = UDim2.new(1, 0, 1, 0)
    burstLabel.Text = "Burst: 0/" .. tostring(SETTINGS.BurstCount)
    burstLabel.Font = Enum.Font.SourceSans
    burstLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    burstLabel.BackgroundTransparency = 1
    burstLabel.TextSize = 14
    burstLabel.Parent = burstBg

    -- Hitbox bar background
    local hitBg = Instance.new("Frame")
    hitBg.Size = UDim2.new(1, -20, 0, 20)
    hitBg.Position = UDim2.new(0, 10, 0, 32)
    hitBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    hitBg.Parent = barFrame

    local hitFill = Instance.new("Frame")
    hitFill.Size = UDim2.new(0, 0, 1, 0)
    hitFill.BackgroundColor3 = ACCENT_COLOR
    hitFill.BorderSizePixel = 0
    hitFill.Parent = hitBg

    local hitLabel = Instance.new("TextLabel")
    hitLabel.Size = UDim2.new(1, 0, 1, 0)
    hitLabel.Text = "Hitbox: " .. tostring(SETTINGS.PlayerHitboxScale) .. "x"
    hitLabel.Font = Enum.Font.SourceSans
    hitLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hitLabel.BackgroundTransparency = 1
    hitLabel.TextSize = 14
    hitLabel.Parent = hitBg

    UI.Bars.BurstBar = burstFill
    UI.Bars.BurstLabel = burstLabel
    UI.Bars.HitboxBar = hitFill
    UI.Bars.HitboxLabel = hitLabel

    -- Footer / Panic
    local Footer = createHeader("Phím Tắt: " .. SETTINGS.PANIC_KEY.Name .. " (Ẩn UI/Ngắt Khẩn Cấp)")
    Footer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)

    -- Drag functionality
    local drag = false
    local dragStart = Vector2.new(0, 0)
    local dragOffset = MainFrame.Position

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
pcall(function() createUI() end)
if UI.MainFrame then
    UI.MainFrame.Visible = SETTINGS.UIVisible
end

-- Panic Key Bind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == SETTINGS.PANIC_KEY then
        if UI.MainFrame then
            SETTINGS.UIVisible = not SETTINGS.UIVisible
            UI.MainFrame.Visible = SETTINGS.UIVisible
        end
        executePanicSwitch(false)
    end
end)

-- Init
scanAndHookRemotes()
updateLoopStatus()

print("-------------------------------------------------------")
print("KKPIXEL_BLADE_V5.7: Enhanced Native UI (Stable) LOADED")
print("BURST: " .. tostring(SETTINGS.BurstEnabled) .. " | HitboxScaleInterval: " .. tostring(SETTINGS.HitboxScaleChangeInterval))
print("-------------------------------------------------------")

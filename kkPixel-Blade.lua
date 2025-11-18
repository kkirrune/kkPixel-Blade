-- KKPixelBlade V6.0 (Single-file) - Ultimate Safe + Enhanced UI (Linoria)
-- Author: kkirru-style (Gemini) -> rewritten by ChatGPT -> Modified for Linoria UI with Config Save/Load
-- Version: V6.0 (Linoria UI, Config Enabled)
-- Usage: paste into executor and run. Designed as a single-file HUB.

-- Kiểm tra sự tồn tại của thư viện Linoria và khởi tạo
local Linoria = getgenv().Linoria
if not Linoria and not getgenv()._linoria then
    local function notify(t) warn("[KKPB] Linoria UI Library not found. Starting without UI.") end
    if pcall(function() notify(game:GetService("StarterGui")) end) then
        -- Attempt to use Roblox's notification system if possible
    end
end

local UI_LIB_READY = (Linoria or getgenv()._linoria)

-- Danh sách các khóa cần lưu/tải
local CONFIG_KEYS = {
    "AuraEnabled", "AuraRange", "AttackDelay", "AutoMoveToTarget", "AutoBehindTarget",
    "AutoSkills", "AutoHeal", "AutoHealHPThreshold", "AutoUpgrade",
    "PlayerHitboxScale", "EnemyHitboxScale", "HitboxChangeInterval", "MoveSpeedLimit",
    "FreezeEnemyAI", "GomQuaiEnabled", "GomQuaiRange", "GomQuaiDelay",
    "BurstEnabled", "BurstCount", "BurstDelay", "BurstCooldown",
    "AutoDisconnect",
}

-- MÔ PHỎNG HÀM LƯU/TẢI CẤU HÌNH CỦA EXECUTOR
local CONFIG_NAME = "KKPB_V6_Config"

local function safeSaveConfig(settingsTable)
    local savedData = {}
    for _, key in ipairs(CONFIG_KEYS) do
        savedData[key] = settingsTable[key]
    end
    
    if type(getgenv()._save) == 'function' then -- Sử dụng hàm lưu Executor (giả định)
        getgenv()._save(CONFIG_NAME, savedData)
    elseif getgenv().Linoria and getgenv().Linoria.SaveConfig then
        getgenv().Linoria:SaveConfig(savedData, CONFIG_NAME)
    else
        getgenv()[CONFIG_NAME .. "_Settings"] = savedData -- Lưu vào Global Env
        print("[KKPB] Config Saved to Global Environment.")
    end
end

local function safeLoadConfig()
    local loadedData = {}
    if type(getgenv()._load) == 'function' then
        loadedData = getgenv()._load(CONFIG_NAME) or {}
    elseif getgenv().Linoria and getgenv().Linoria.LoadConfig then
        loadedData = getgenv().Linoria:LoadConfig(CONFIG_NAME) or {}
    else
        loadedData = getgenv()[CONFIG_NAME .. "_Settings"] or {} -- Tải từ Global Env
        if next(loadedData) ~= nil then
            print("[KKPB] Config Loaded from Global Environment.")
        end
    end
    return loadedData
end
-- KẾT THÚC MÔ PHỎNG CONFIG

local function safe_start_script()
    -- Services (cached locally inside function for safety)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local Stats = game:GetService("Stats")

    -- Local player (pcall safe)
    local Player = Players.LocalPlayer

    -- Basic locals
    local pcall = pcall
    local tick = os.clock
    local floor = math.floor
    local max = math.max
    local min = math.min
    local Random = Random.new(tick())
    local tostring = tostring
    local tonumber = tonumber
    local string_lower = string.lower

    -- SETTINGS (default)
    local SETTINGS = {
        UIVisible = true,
        PANIC_KEY = Enum.KeyCode.Insert,

        -- FARM
        AuraEnabled = false,
        AuraRange = 600,
        AttackDelay = 0.25,
        AutoMoveToTarget = false,
        AutoBehindTarget = false,

        -- Skills / Heal
        AutoSkills = false,
        AutoHeal = false,
        AutoHealHPThreshold = 0.6,
        AutoUpgrade = false,

        -- Hitbox / Movement
        PlayerHitboxScale = 1.0,
        EnemyHitboxScale = 1.0,
        HitboxChangeInterval = 10,
        MoveSpeedLimit = 6,

        -- Misc
        FreezeEnemyAI = false,
        GomQuaiEnabled = false,
        GomQuaiRange = 40,
        GomQuaiDelay = 2.0,

        -- Burst
        BurstEnabled = true,
        BurstCount = 3,
        BurstDelay = 0.12,
        BurstCooldown = 1.2,

        AutoDisconnect = false,
    }
    
    -- TẢI CẤU HÌNH NGAY LẬP TỨC
    local loadedCfg = safeLoadConfig()
    for _, key in ipairs(CONFIG_KEYS) do
        if loadedCfg[key] ~= nil then
            SETTINGS[key] = loadedCfg[key]
        end
    end

    -- Internal state
    local STATE = {
        loopConnection = nil,
        lastHitboxTime = 0,
        lastGomQuaiTime = 0,
        lastCacheUpdate = 0,
        targetCache = nil,
        remotes = {},
        AttackRemote = nil,
        SkillRemote = nil,
        HealRemote = nil,
        burstCharge = SETTINGS.BurstCount, -- Initialize burst
        lastBurstUse = 0,
    }
    
    -- UI elements (for updates only)
    local UI_ELEMENTS = {
        BurstLabel = nil,
        HitboxLabel = nil,
        BurstProgressBar = nil,
        HitboxProgressBar = nil,
        -- Reference to Linoria Sliders/Toggles for forced UI update after Load
        LinoriaControls = {} 
    }

    local ADMIN_KEYWORDS = {"admin","mod","owner","staff","dev","frostblade","helper"}
    local MIN_ATTACK_DELAY = 0.05

    -- helpers
    local function rand(minv, maxv)
        return Random:NextNumber(minv, maxv)
    end

    local function EstimateServerCooldown(baseDelay)
        local ok, val = pcall(function() return Stats.Network.LocalPing:GetValue() end)
        local ping = (ok and val) or 0.05
        return max(baseDelay, 0.05) + ping
    end

    -- Safe remote fire/invoke (Logic remains the same)
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

    -- Scan and hook remotes (Logic remains the same)
    local function tryHookRemote(remote)
        -- ... (remote hooking logic remains the same) ...
        if not remote then return end
        local className = remote.ClassName or ""
        if className ~= "RemoteEvent" and className ~= "RemoteFunction" then return end
        local nameLower = string_lower(remote.Name or "")

        local excluded = {"effect","visual","hitmarker","sound","particle","vfx","tool","slash","bone"}
        for _, kw in ipairs(excluded) do
            if nameLower:find(kw) then return end
        end

        -- if remote already wrapped, skip
        if STATE.remotes[remote] then return end

        if remote.ClassName == "RemoteEvent" then
            local ok, orig = pcall(function() return remote.FireServer end)
            if not ok or type(orig) ~= "function" then return end
            local function wrappedFire(self, ...)
                local rn = string_lower(self.Name or "")
                -- heuristics
                if not STATE.AttackRemote and (rn:find("attack") or rn:find("damage") or rn:find("hit")) then
                    STATE.AttackRemote = self
                    print("[KKPB] Found Attack Remote: "..tostring(self.Name))
                elseif not STATE.HealRemote and (rn:find("heal") or rn:find("buff")) then
                    STATE.HealRemote = self
                    print("[KKPB] Found Heal Remote: "..tostring(self.Name))
                elseif not STATE.SkillRemote and (rn:find("skill") or rn:find("ability")) then
                    STATE.SkillRemote = self
                    print("[KKPB] Found Skill Remote: "..tostring(self.Name))
                end
                return orig(self, ...)
            end
            pcall(function() remote.FireServer = wrappedFire end)
            STATE.remotes[remote] = true
        elseif remote.ClassName == "RemoteFunction" then
            local ok, orig = pcall(function() return remote.InvokeServer end)
            if not ok or type(orig) ~= "function" then return end
            local function wrappedInvoke(self, ...)
                local rn = string_lower(self.Name or "")
                if not STATE.AttackRemote and (rn:find("attack") or rn:find("damage") or rn:find("hit")) then
                    STATE.AttackRemote = self
                    print("[KKPB] Found Attack Remote (Function): "..tostring(self.Name))
                elseif not STATE.HealRemote and (rn:find("heal") or rn:find("buff")) then
                    STATE.HealRemote = self
                    print("[KKPB] Found Heal Remote (Function): "..tostring(self.Name))
                elseif not STATE.SkillRemote and (rn:find("skill") or rn:find("ability")) then
                    STATE.SkillRemote = self
                    print("[KKPB] Found Skill Remote (Function): "..tostring(self.Name))
                end
                return orig(self, ...)
            end
            pcall(function() remote.InvokeServer = wrappedInvoke end)
            STATE.remotes[remote] = true
        end
    end

    local function scanRemotesOnce()
        -- conservative traversal
        local function traverse(parent)
            for _, v in ipairs(parent:GetChildren()) do
                if v.ClassName == "RemoteEvent" or v.ClassName == "RemoteFunction" then
                    pcall(function() tryHookRemote(v) end)
                else
                    -- only traverse reasonable containers
                    local cl = v.ClassName
                    if cl == "Folder" or cl == "ModuleScript" or cl == "Model" or cl == "Configuration" or cl == "Script" or cl == "LocalScript" then
                        pcall(function() traverse(v) end)
                    end
                end
            end
        end
        pcall(function() traverse(ReplicatedStorage) end)
        pcall(function() traverse(Workspace) end)
        if Player then pcall(function() traverse(Player) end) end
    end

    -- Target selection (Logic remains the same)
    local function updateTargetCache(maxRange)
        -- ... (target cache logic remains the same) ...
        if tick() - STATE.lastCacheUpdate < 0.45 then return STATE.targetCache end
        STATE.lastCacheUpdate = tick()
        STATE.targetCache = nil

        local char = (Player and Player.Character) or nil
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return nil end
        local root = char and char.PrimaryPart
        if not root then return nil end

        local nearest, mind = nil, maxRange
        for _, v in ipairs(Workspace:GetChildren()) do
            if v ~= char and v:FindFirstChildOfClass("Humanoid") and v.PrimaryPart then
                local h = v:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local dist = (v.PrimaryPart.Position - root.Position).Magnitude
                    if dist < mind then
                        nearest = v
                        mind = dist
                    end
                end
            end
        end
        STATE.targetCache = nearest
        return nearest
    end

    local function getTargetPosition(target)
        -- ... (get target position logic remains the same) ...
        if not target or not target.PrimaryPart then return nil end
        local off = Vector3.new(rand(-4,4), rand(4,10), rand(-4,4))
        local pos = target.PrimaryPart.Position + off
        if SETTINGS.AutoBehindTarget and Player and Player.Character and Player.Character.PrimaryPart then
            local back = target.PrimaryPart.CFrame.LookVector * 4
            return pos - back
        end
        return pos
    end

    -- Admin detection -> panic (Logic remains the same)
    local function executePanicSwitch(isBanRisk)
        -- stop loop
        if STATE.loopConnection then
            pcall(function() STATE.loopConnection:Disconnect() end)
            STATE.loopConnection = nil
        end
        -- reset HRP size
        pcall(function()
            if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                Player.Character.HumanoidRootPart.Size = Vector3.new(2,2,1)
            end
        end)
        if isBanRisk and SETTINGS.AutoDisconnect then
            pcall(function() game:Shutdown() end)
        else
            print("[KKPB] Panic: exploit paused. UI is hidden.")
            if UI_LIB_READY and Linoria.Destroy then
                -- Try to hide the Linoria UI
                Linoria.Destroy(true)
            end
        end
    end

    local function checkAdmins()
        -- ... (admin check logic remains the same) ...
        if not Players then return end
        if tick() - (checkAdmins._last or 0) < 4.0 then return end
        checkAdmins._last = tick()
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= Player then
                local ok1, n = pcall(function() return pl.Name:lower() end)
                local ok2, dn = pcall(function() return pl.DisplayName:lower() end)
                local nstr = (ok1 and n) or ""
                local dnstr = (ok2 and dn) or ""
                for _, kw in ipairs(ADMIN_KEYWORDS) do
                    if nstr:find(kw) or dnstr:find(kw) then
                        print("[KKPB] Admin keyword detected: "..(pl.Name or "?"))
                        executePanicSwitch(true)
                        return
                    end
                end
            end
        end
    end

    -- Gom quái: lightweight teleport of NPC models nearby (Logic remains the same)
    local function gomQuai()
        -- ... (gom quai logic remains the same) ...
        if not SETTINGS.GomQuaiEnabled then return end
        if tick() - STATE.lastGomQuaiTime < SETTINGS.GomQuaiDelay then return end
        STATE.lastGomQuaiTime = tick()
        local char = Player and Player.Character
        if not char or not char.PrimaryPart then return end
        for _, v in ipairs(Workspace:GetChildren()) do
            if v ~= char and v:FindFirstChildOfClass("Humanoid") and v.PrimaryPart then
                local dist = (v.PrimaryPart.Position - char.PrimaryPart.Position).Magnitude
                if dist <= SETTINGS.GomQuaiRange then
                    pcall(function()
                        if v:IsA("Model") and v.PrimaryPart then
                            local offset = Vector3.new(rand(-2,2),0,rand(-2,2))
                            v:SetPrimaryPartCFrame(CFrame.new(char.PrimaryPart.Position + offset))
                        end
                    end)
                end
            end
        end
    end

    local function applyHitboxScale(scale)
        -- ... (hitbox scale logic remains the same) ...
        if tick() - STATE.lastHitboxTime < SETTINGS.HitboxChangeInterval then return end
        STATE.lastHitboxTime = tick()
        pcall(function()
            if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = Player.Character.HumanoidRootPart
                hrp.Size = Vector3.new(2*scale, 2*scale, 1*scale)
            end
        end)
    end

    -- Movement limiter (Logic remains the same)
    local function limitMoveSpeed(targetPos, currentPos, maxSpeed)
        -- ... (move limit logic remains the same) ...
        local delta = targetPos - currentPos
        local dist = delta.Magnitude
        if dist == 0 or maxSpeed <= 0 then return currentPos end
        local dir = delta.Unit
        local move = min(maxSpeed, dist) * dir
        return currentPos + move
    end

    -- Main logic loop (Logic remains the same, except for UI update)
    local function startLoop()
        if STATE.loopConnection then pcall(function() STATE.loopConnection:Disconnect() end) end

        STATE.burstCharge = SETTINGS.BurstCount -- Reset/Initialize burst charge
        STATE.lastBurstUse = 0

        local lastAttack = 0
        local burstCounter = 0
        local lastSkill = 0
        local lastHeal = 0
        local lastFreeze = 0

        STATE.loopConnection = RunService.Heartbeat:Connect(function(dt)
            local now = tick()
            local char = Player and Player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not char or not hum or hum.Health <= 0 or not char.PrimaryPart then return end

            -- refill burst
            if SETTINGS.BurstEnabled and SETTINGS.BurstCount and SETTINGS.BurstCooldown and STATE.burstCharge < SETTINGS.BurstCount then
                local refill = SETTINGS.BurstCount / max(0.0001, SETTINGS.BurstCooldown)
                STATE.burstCharge = min(SETTINGS.BurstCount, STATE.burstCharge + refill * dt)
            end

            -- update target
            local target = updateTargetCache(SETTINGS.AuraRange)

            -- ATTACK logic (Remains the same)
            local attackDelay = max(SETTINGS.AttackDelay, MIN_ATTACK_DELAY)
            if SETTINGS.AuraEnabled and target and STATE.AttackRemote then
                if burstCounter > 0 then
                    local jitter = rand(SETTINGS.BurstDelay*0.9, SETTINGS.BurstDelay*1.1)
                    if now - lastAttack >= jitter then
                        pcall(function() safeFireRemote(STATE.AttackRemote, target) end)
                        lastAttack = now
                        burstCounter = burstCounter - 1
                    end
                else
                    if SETTINGS.BurstEnabled and STATE.burstCharge >= 1 then
                        local jitterBurst = rand(attackDelay*0.9, attackDelay*1.05)
                        if now - lastAttack >= jitterBurst then
                            burstCounter = SETTINGS.BurstCount
                            STATE.burstCharge = max(0, STATE.burstCharge - 1)
                            STATE.lastBurstUse = now
                        end
                    else
                        if now - lastAttack >= attackDelay then
                            pcall(function() safeFireRemote(STATE.AttackRemote, target) end)
                            lastAttack = now
                        end
                    end
                end
            end

            -- Auto move to target (Remains the same)
            if SETTINGS.AutoMoveToTarget and target and target.PrimaryPart then
                local tpos = getTargetPosition(target)
                if tpos then
                    local cpos = char.PrimaryPart.Position
                    local limited = limitMoveSpeed(tpos, cpos, SETTINGS.MoveSpeedLimit * dt * 60)
                    if (limited - cpos).Magnitude > 0.001 then
                        pcall(function()
                            char:SetPrimaryPartCFrame(CFrame.new(limited))
                        end)
                    end
                end
            end

            -- Auto skills (Remains the same)
            if SETTINGS.AutoSkills and STATE.SkillRemote and (now - lastSkill > EstimateServerCooldown(rand(0.2,0.35))) then
                pcall(function() safeFireRemote(STATE.SkillRemote, "AllSkills") end)
                lastSkill = now
            end

            -- Auto heal (Remains the same)
            local currentHPPercent = hum.Health / max(1, hum.MaxHealth)
            if SETTINGS.AutoHeal and STATE.HealRemote and currentHPPercent < SETTINGS.AutoHealHPThreshold and (now - lastHeal > 5.0) then
                pcall(function() safeFireRemote(STATE.HealRemote) end)
                lastHeal = now
            end

            -- Freeze AI (Remains the same)
            if SETTINGS.FreezeEnemyAI and (now - lastFreeze > 0.5) then
                lastFreeze = now
                delay(0, function()
                    for _, v in ipairs(Workspace:GetChildren()) do
                        if v ~= char and v:FindFirstChildOfClass("Humanoid") then
                            local h = v:FindFirstChildOfClass("Humanoid")
                            pcall(function()
                                if h then
                                    h.WalkSpeed = 0
                                    h.JumpPower = 0
                                end
                            end)
                        end
                    end
                end)
            end

            -- Hitbox apply (Remains the same)
            applyHitboxScale(SETTINGS.PlayerHitboxScale)

            -- Gom quái (Remains the same)
            if SETTINGS.GomQuaiEnabled then gomQuai() end

            -- Admin check (Remains the same)
            checkAdmins()

            -- Update UI bars
            if UI_LIB_READY and UI_ELEMENTS.BurstLabel then
                pcall(function()
                    local normalizedBurst = min(1, max(0, STATE.burstCharge / max(1, SETTINGS.BurstCount)))
                    UI_ELEMENTS.BurstProgressBar:Update(normalizedBurst)
                    UI_ELEMENTS.BurstLabel:Update("Burst: "..floor(STATE.burstCharge+0.5).."/"..tostring(SETTINGS.BurstCount))
                    
                    local minScale, maxScale = 1.0, 1.6
                    local cl = min(maxScale, max(minScale, SETTINGS.PlayerHitboxScale))
                    local normHitbox = (cl - minScale) / (maxScale - minScale)
                    UI_ELEMENTS.HitboxProgressBar:Update(normHitbox)
                    UI_ELEMENTS.HitboxLabel:Update(("Hitbox: %.2fx"):format(SETTINGS.PlayerHitboxScale))
                end)
            end
        end)
    end

    local function updateLoopStatus()
        local shouldRun = SETTINGS.AuraEnabled or SETTINGS.AutoSkills or SETTINGS.AutoHeal or SETTINGS.FreezeEnemyAI or SETTINGS.GomQuaiEnabled
        if shouldRun and not STATE.loopConnection then
            startLoop()
            print("[KKPB] Farm loop started")
        elseif not shouldRun and STATE.loopConnection then
            pcall(function() STATE.loopConnection:Disconnect() end)
            STATE.loopConnection = nil
            print("[KKPB] Farm loop stopped")
        end
    end
    
    -- Function to refresh all UI elements with current SETTINGS values
    local function updateLinoriaUI()
        for key, control in pairs(UI_ELEMENTS.LinoriaControls) do
            if control and control.Update then
                control:Update(SETTINGS[key])
            end
        end
        updateLoopStatus()
        -- Force a manual update for the progress bars
        if UI_ELEMENTS.HitboxLabel then 
            UI_ELEMENTS.HitboxLabel:Update(("Hitbox: %.2fx"):format(SETTINGS.PlayerHitboxScale)) 
        end
    end

    -- ========== LINORIA UI BUILDER ===========
    local function createLinoriaUI()
        if not UI_LIB_READY then return end

        local Window = Linoria:Window("KKPIXEL BLADE V6.0 (Safe)", {
            Theme = Color3.fromRGB(207, 48, 74),
            Size = UDim2.fromOffset(400, 500),
            Position = UDim2.fromOffset(50, 50)
        })

        local Tab1 = Window:Tab("FARMING")
        local Tab2 = Window:Tab("COMBAT & MISC")
        local Tab3 = Window:Tab("CONFIG")

        -- === TAB 1: FARMING ===
        local FarmGroup = Tab1:Group("FARM")
        UI_ELEMENTS.LinoriaControls.AuraEnabled = FarmGroup:Toggle("BẬT KILL AURA", SETTINGS.AuraEnabled, function(v)
            SETTINGS.AuraEnabled = v
            updateLoopStatus()
        end)

        UI_ELEMENTS.LinoriaControls.AuraRange = FarmGroup:Slider("Phạm vi Aura", SETTINGS.AuraRange, {
            Min = 100, Max = 3000, Decimals = 0, Suffix = " Studs",
            Callback = function(v) SETTINGS.AuraRange = v end
        })

        UI_ELEMENTS.LinoriaControls.AttackDelay = FarmGroup:Slider("Tốc độ Đánh (s)", SETTINGS.AttackDelay, {
            Min = 0.05, Max = 1.0, Decimals = 2, Suffix = " s",
            Callback = function(v) SETTINGS.AttackDelay = v end
        })
        
        UI_ELEMENTS.LinoriaControls.AutoMoveToTarget = FarmGroup:Toggle("Auto Dịch chuyển (TP)", SETTINGS.AutoMoveToTarget, function(v)
            SETTINGS.AutoMoveToTarget = v
        end)
        
        UI_ELEMENTS.LinoriaControls.AutoBehindTarget = FarmGroup:Toggle("Auto Đứng đằng sau mục tiêu", SETTINGS.AutoBehindTarget, function(v)
            SETTINGS.AutoBehindTarget = v
        end)

        local GomQuaiGroup = Tab1:Group("GOM QUÁI")
        UI_ELEMENTS.LinoriaControls.GomQuaiEnabled = GomQuaiGroup:Toggle("Bật Gom Quái", SETTINGS.GomQuaiEnabled, function(v)
            SETTINGS.GomQuaiEnabled = v
            updateLoopStatus()
        end)

        UI_ELEMENTS.LinoriaControls.GomQuaiRange = GomQuaiGroup:Slider("Phạm vi Gom", SETTINGS.GomQuaiRange, {
            Min = 5, Max = 250, Decimals = 0, Suffix = " Studs",
            Callback = function(v) SETTINGS.GomQuaiRange = v end
        })
        
        UI_ELEMENTS.LinoriaControls.GomQuaiDelay = GomQuaiGroup:Slider("Delay Gom (s)", SETTINGS.GomQuaiDelay, {
            Min = 0.1, Max = 10.0, Decimals = 1, Suffix = " s",
            Callback = function(v) SETTINGS.GomQuaiDelay = v end
        })

        -- === TAB 2: COMBAT & MISC ===
        local SkillsGroup = Tab2:Group("KỸ NĂNG & HỒI PHỤC")
        UI_ELEMENTS.LinoriaControls.AutoHeal = SkillsGroup:Toggle("Auto Buff/Heal", SETTINGS.AutoHeal, function(v)
            SETTINGS.AutoHeal = v
            updateLoopStatus()
        end)
        
        UI_ELEMENTS.LinoriaControls.AutoHealHPThreshold = SkillsGroup:Slider("Ngưỡng HP Buff", SETTINGS.AutoHealHPThreshold, {
            Min = 0.1, Max = 0.95, Decimals = 2, Suffix = " (0-1)",
            Callback = function(v) SETTINGS.AutoHealHPThreshold = v end
        })
        
        UI_ELEMENTS.LinoriaControls.AutoSkills = SkillsGroup:Toggle("Auto Tất cả Skills", SETTINGS.AutoSkills, function(v)
            SETTINGS.AutoSkills = v
            updateLoopStatus()
        end)
        
        local HitboxGroup = Tab2:Group("HITBOX & MOVEMENT")
        
        UI_ELEMENTS.LinoriaControls.PlayerHitboxScale = HitboxGroup:Slider("Tăng Hitbox Người chơi", SETTINGS.PlayerHitboxScale, {
            Min = 1.0, Max = 1.6, Decimals = 2, Suffix = "x",
            Callback = function(v) SETTINGS.PlayerHitboxScale = v end
        })

        UI_ELEMENTS.LinoriaControls.EnemyHitboxScale = HitboxGroup:Slider("Giảm Hitbox Quái", SETTINGS.EnemyHitboxScale, {
            Min = 0.5, Max = 1.0, Decimals = 2, Suffix = "x",
            Callback = function(v) SETTINGS.EnemyHitboxScale = v end
        })
        
        UI_ELEMENTS.LinoriaControls.HitboxChangeInterval = HitboxGroup:Slider("Hitbox Interval", SETTINGS.HitboxChangeInterval, {
            Min = 1, Max = 60, Decimals = 0, Suffix = " s",
            Callback = function(v) SETTINGS.HitboxChangeInterval = v end
        })

        UI_ELEMENTS.LinoriaControls.MoveSpeedLimit = HitboxGroup:Slider("Move Speed Limit", SETTINGS.MoveSpeedLimit, {
            Min = 1, Max = 30, Decimals = 1,
            Callback = function(v) SETTINGS.MoveSpeedLimit = v end
        })
        
        UI_ELEMENTS.LinoriaControls.FreezeEnemyAI = HitboxGroup:Toggle("Khống chế quái (Freeze)", SETTINGS.FreezeEnemyAI, function(v)
            SETTINGS.FreezeEnemyAI = v
            updateLoopStatus()
        end)

        UI_ELEMENTS.LinoriaControls.AutoDisconnect = HitboxGroup:Toggle("Tự động rời khi admin", SETTINGS.AutoDisconnect, function(v)
            SETTINGS.AutoDisconnect = v
        end)
        
        local BurstGroup = Tab2:Group("BURST COMBO")
        UI_ELEMENTS.LinoriaControls.BurstEnabled = BurstGroup:Toggle("Bật Burst Combo", SETTINGS.BurstEnabled, function(v)
            SETTINGS.BurstEnabled = v
        end)
        
        UI_ELEMENTS.LinoriaControls.BurstCount = BurstGroup:Slider("Số hits trong Burst", SETTINGS.BurstCount, {
            Min = 1, Max = 8, Decimals = 0, Suffix = " hits",
            Callback = function(v)
                SETTINGS.BurstCount = v
                STATE.burstCharge = min(STATE.burstCharge, v) -- Prevent overflow if max is reduced
            end
        })
        
        UI_ELEMENTS.LinoriaControls.BurstDelay = BurstGroup:Slider("Delay giữa hit", SETTINGS.BurstDelay, {
            Min = 0.01, Max = 0.5, Decimals = 2, Suffix = " s",
            Callback = function(v) SETTINGS.BurstDelay = v end
        })
        
        UI_ELEMENTS.LinoriaControls.BurstCooldown = BurstGroup:Slider("Burst Cooldown (full)", SETTINGS.BurstCooldown, {
            Min = 0.5, Max = 10.0, Decimals = 1, Suffix = " s",
            Callback = function(v) SETTINGS.BurstCooldown = v end
        })
        
        -- Progress Bars
        local StatusGroup = Tab2:Group("STATUS")
        
        UI_ELEMENTS.BurstLabel = StatusGroup:Label("Burst: "..floor(STATE.burstCharge+0.5).."/"..tostring(SETTINGS.BurstCount))
        UI_ELEMENTS.BurstProgressBar = StatusGroup:Progress(0, Color3.fromRGB(48,207,74))

        UI_ELEMENTS.HitboxLabel = StatusGroup:Label(("Hitbox: %.2fx"):format(SETTINGS.PlayerHitboxScale))
        UI_ELEMENTS.HitboxProgressBar = StatusGroup:Progress(0, Color3.fromRGB(207,48,74))

        -- === TAB 3: CONFIG & INFO ===
        local ConfigGroup = Tab3:Group("LƯU & TẢI CẤU HÌNH")
        
        ConfigGroup:Button("LƯU CẤU HÌNH HIỆN TẠI", function()
            safeSaveConfig(SETTINGS)
        end)
        
        ConfigGroup:Button("TẢI CẤU HÌNH ĐÃ LƯU", function()
            local newCfg = safeLoadConfig()
            if next(newCfg) ~= nil then
                for _, key in ipairs(CONFIG_KEYS) do
                    if newCfg[key] ~= nil then
                        SETTINGS[key] = newCfg[key]
                    end
                end
                updateLinoriaUI() -- Cập nhật UI để khớp với SETTINGS mới
                print("[KKPB] Configuration Loaded Successfully and UI Updated.")
            else
                print("[KKPB] No saved configuration found or load failed.")
            end
        end)
        
        local InfoGroup = Tab3:Group("THÔNG TIN")
        InfoGroup:Label("Phiên bản: V6.0 - Linoria UI")
        InfoGroup:Label("Phím Tắt Ẩn/Panic: **"..SETTINGS.PANIC_KEY.Name.."**")
        InfoGroup:Button("EXECUTE PANIC SWITCH (PAUSE ALL)", function()
            executePanicSwitch(false)
        end)
        
        -- Bind the panic key to the UI visibility toggle function of the Linoria window
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == SETTINGS.PANIC_KEY then
                SETTINGS.UIVisible = not SETTINGS.UIVisible
                Window:ToggleVisibility(SETTINGS.UIVisible)
                
                -- Also trigger the main panic logic (reset HRp size, stop loop)
                executePanicSwitch(false)
            end
        end)
    end
    
    -- Try to create the Linoria UI
    pcall(createLinoriaUI)
    
    -- initial scan
    pcall(function() scanRemotesOnce() end)

    -- periodic rescans (low frequency)
    spawn(function()
        while true do
            pcall(function() scanRemotesOnce() end)
            wait(8 + rand(0,4))
        end
    end)

    -- initial update
    updateLoopStatus()

    print("----------------------------------------------------")
    print("KKPIXEL_BLADE_V6.0: LOADED (Linoria UI, Config Enabled)")
    print("----------------------------------------------------")
end

pcall(safe_start_script)

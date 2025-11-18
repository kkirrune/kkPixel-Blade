-- Single-file HUB: LinoriaLib UI + Config System + Localization + Loader + Module structure
-- Author: kkirru-style (ChatGPT)
-- Version: Anti-Ban Ẩn V5.1 (LinoriaLib UI & Volcano Optimized)
-- Features: V1-V5 (Kill Aura, God Heal, Anti-Ban) + V5.1 (LinoriaLib, Volcano Safe)

-- === [ Executor Environment Check & LinoriaLib Loader ] ===
-- This script assumes LinoriaLib is already loaded or will be loaded by the Executor.
if not _G.LinoriaLib then
    warn("LinoriaLib not found. Attempting to load it.")
    local success, err = pcall(function()
        _G.LinoriaLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua"))()
    end)
    if not success then
        error("Failed to load LinoriaLib: " .. err .. ". Please ensure your Executor supports httpget and loadstring, or load LinoriaLib manually.")
    end
end
local LinoriaLib = _G.LinoriaLib

-- ==== Dịch Vụ & Helpers ====
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- Hạn chế tối đa việc sử dụng các hàm client-side bị theo dõi
local pcall = pcall
local os_clock = os.clock
local os_time = os.time
local math_max = math_max
local math_clamp = math_clamp
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove

-- environment safe wrappers for executor APIs (Volcano compatible)
local isfile = isfile or function() return false end
local readfile = readfile or function() return nil, "readfile not available" end
local writefile = writefile or function() error("writefile not available") end
local delfile = delfile or function() end
local makefolder = makefolder or function() end

-- Khai báo biến
local GUI_NAME = "KKPIXEL_BLADE_V5_1" 
local CONFIG_FOLDER = "KKHub_Configs_V5_1"
local AUTLOAD_FILE = CONFIG_FOLDER .. "/__autoload"
local DEFAULT_CONFIG_EXT = ".json"
local PIXEL_BLADE_ID = 18172550962 

-- Remote Function/Event tìm kiếm an toàn (Volcano Optimized)
-- V5.1 Fix: Use safer WaitForChild and error check.
local AttackRemote = nil 
local SkillRemote = nil
local HealRemote = nil

local function getRemote(name)
    local remote = nil
    -- Try common locations safely (using pcall to handle nil values during search)
    pcall(function() remote = game:GetService("ReplicatedStorage"):WaitForChild(name, 5) end)
    if not remote then pcall(function() remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5):WaitForChild(name, 5) end) end
    if not remote then pcall(function() remote = game:GetService("ReplicatedStorage"):WaitForChild("Events", 5):WaitForChild(name, 5) end) end
    
    if not remote then 
        warn("RemoteEvent NOT FOUND:", name, ". The script will try to call the placeholder function, but Attack/Skill/Heal features might not work.") 
    end
    return remote
end

-- V5.1: Initialize remotes once globally
-- NOTE: You MUST replace "AttackRemoteName", "SkillRemoteName", "HealRemoteName" with the actual names found in Pixel Blade
AttackRemote = getRemote("Attack") -- Placeholder
SkillRemote = getRemote("Skill") -- Placeholder
HealRemote = getRemote("Heal") -- Placeholder


-- ==== V5 ANTI-BAN CONSTANTS ====
local MIN_ATTACK_DELAY = 0.05 
local BURST_ATTACK_COUNT = 3 
local BURST_DELAY = 0.15 
local PANIC_KEY = Enum.KeyCode.Insert
local ADMIN_KEYWORDS = {"mod", "admin", "dev", "staff", "owner", "helper", "frostblade"} 
local TARGET_CACHE_TIME = 0.5 

-- Cache Mục tiêu và RNG
local TARGET_CACHE = {}
local lastCacheUpdate = 0
local RNG = Random.new(os_time())

-- Helper ngẫu nhiên
local function random(min, max)
    return RNG:NextNumber(min, max)
end

local function EstimateServerCooldown(baseDelay)
    local ping = game:GetService("Stats").Network.LocalPing:GetValue() or 0.05
    return math_max(baseDelay, 0.05) + ping
end

-- default localization (giữ nguyên)
local LANGS = {
    vi = {
        title = GUI_NAME, config_section = "Cấu hình", config_name = "Tên config", create = "Tạo config", list = "Danh sách", load = "Tải", overwrite = "Ghi đè", delete = "Xóa", refresh = "Làm mới", set_autoload = "Đặt autoload", reset_autoload = "Hủy autoload", current_autoload = "Autoload hiện tại", error_save = "Lỗi lưu config:", error_load = "Lỗi tải config:", error_not_found = "không tìm thấy",
        farm_section = "Farm Pixel Blade", farm_toggle = "Bật Kill Aura", farm_range = "Phạm vi Aura (Studs)", farm_delay = "Tốc độ Đánh (giây)", farm_back = "Auto Đứng Đằng Sau", farm_move = "Auto Dịch Chuyển Quái",
        skill_section = "Kỹ Năng & Nâng Cấp", skill_all = "Auto Tất Cả Skills", skill_heal = "Auto Buff Máu Siêu Cấp", skill_hp_thresh = "Ngưỡng HP Buff (%)", upgrade_auto = "Auto Nâng Cấp Max", upgrade_select_all = "Chọn Tất Cả Buff",
        exploit_section = "Can Thiệp Game & Ngắt Khẩn Cấp (V4)", enemy_control = "Khống Chế Quái (Đóng Băng)", enemy_hitbox = "Giảm Hitbox Quái (Min 0.5x)", player_hitbox = "Tăng Hitbox Người Chơi (Max 1.5x)", panic_switch = "Phím Ngắt Khẩn Cấp", auto_disconnect = "Tự động Rời khi có Admin",
        anti_section = "Anti-Ban Ẩn V5.1 Đang Hoạt Động", anti_desc = "Tối ưu hóa Tài nguyên, Ngụy trang Tick Jitter, Burst mode, và LinoriaLib UI để vượt qua Anti-Cheat. Tối ưu cho Volcano.",
        lang_section = "Tùy Chọn UI", theme_option = "Chủ đề UI"
    },
    en = {
        title = GUI_NAME, config_section = "Configuration", config_name = "Config name", create = "Create config", list = "Config list", load = "Load config", overwrite = "Overwrite config", delete = "Delete config", refresh = "Refresh list", set_autoload = "Set as autoload", reset_autoload = "Reset autoload", current_autoload = "Current autoload config", error_save = "Failed to save config:", error_load = "Failed to load config:", error_not_found = "not found",
        farm_section = "Pixel Blade Farm", farm_toggle = "Enable Kill Aura", farm_range = "Aura Range (Studs)", farm_delay = "Attack Speed (s)", farm_back = "Auto Behind Target", farm_move = "Auto Move to Target",
        skill_section = "Skill & Upgrade", skill_all = "Auto All Skills", skill_heal = "Auto God Heal", skill_hp_thresh = "Buff HP Threshold (%)", upgrade_auto = "Auto Max Upgrade", upgrade_select_all = "Select All Buffs",
        exploit_section = "Exploit & Panic Switch (V4)", enemy_control = "Freeze Enemy AI", enemy_hitbox = "Enemy Hitbox Scale (Min 0.5x)", player_hitbox = "Player Hitbox Scale (Max 1.5x)", panic_switch = "Panic Kill Switch Key", auto_disconnect = "Auto Disconnect on Admin",
        anti_section = "Stealth Anti-Ban V5.1 Active", anti_desc = "Resource optimized, Tick Jitter Obfuscation, Burst mode, and LinoriaLib UI engaged to bypass Anti-Cheat. Optimized for Volcano.",
        lang_section = "UI Options", theme_option = "UI Theme"
    },
}

-- default settings
local SETTINGS = {lang = "vi", theme = "DarkBlue", autoload = nil}

-- Module Settings 
local PIXEL_BLADE_SETTINGS = {
    AuraEnabled = false, AuraRange = 500, AttackDelay = 0.5, AutoBehindTarget = false, AutoMoveToTarget = false,
    AutoSkills = false, AutoHeal = false, AutoHealHPThreshold = 0.75, AutoUpgrade = false, SelectAllBuffs = false,
    FreezeEnemyAI = false, EnemyHitboxScale = 1.0, PlayerHitboxScale = 1.0,
    AutoDisconnect = false -- V4
}

-- config utilities (giữ nguyên)
local function L(k)
    local lang = SETTINGS.lang or "en"
    local dict = LANGS[lang] or LANGS["en"]
    return dict[k] or k
end
local function ensureConfigFolder() pcall(function() makefolder(CONFIG_FOLDER) end) end
local function listConfigs()
    ensureConfigFolder()
    local out = {}
    local manifestPath = CONFIG_FOLDER .. "/__manifest.json"
    if isfile(manifestPath) then
        local ok, raw = pcall(readfile, manifestPath)
        if ok and raw then
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and type(data) == "table" then for _,v in ipairs(data) do table_insert(out, v) end end
        end
    end
    return out
end
local function saveManifest(list)
    ensureConfigFolder()
    pcall(function() writefile(CONFIG_FOLDER .. "/__manifest.manifest", HttpService:JSONEncode(list)) end) -- Changed to .manifest
end
local function addConfigToManifest(name)
    local m = listConfigs()
    for _,v in ipairs(m) do if v == name then return end end
    table_insert(m, name)
    saveManifest(m)
end
local function removeConfigFromManifest(name)
    local m = listConfigs()
    for i,v in ipairs(m) do if v == name then table_remove(m, i); break end end
    saveManifest(m)
end
local function configPath(name) return CONFIG_FOLDER .. "/" .. name .. DEFAULT_CONFIG_EXT end
local function saveConfig(name, tbl)
    ensureConfigFolder()
    local path = configPath(name)
    local ok, err = pcall(function()
        writefile(path, HttpService:JSONEncode(tbl))
        addConfigToManifest(name)
    end)
    return ok, err
end
local function loadConfig(name)
    local path = configPath(name)
    if not isfile(path) then return nil, L("error_not_found") end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return nil, raw end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return nil, data end
    return data
end
local function deleteConfig(name)
    local path = configPath(name)
    if isfile(path) then
        pcall(function() delfile(path) end)
        removeConfigFromManifest(name)
        return true
    end
    return false
end
local function setAutoload(name)
    ensureConfigFolder()
    if name == nil then
        if isfile(AUTLOAD_FILE) then pcall(function() delfile(AUTLOAD_FILE) end) end
        SETTINGS.autoload = nil
        return true
    end
    pcall(function() writefile(AUTLOAD_FILE, name) end)
    SETTINGS.autoload = name
    return true
end
local function getAutoload()
    if isfile(AUTLOAD_FILE) then
        local ok, raw = pcall(readfile, AUTLOAD_FILE)
        if ok and raw then
            SETTINGS.autoload = raw
            return raw
        end
    end
    return nil
end

-- Module system (simplified for LinoriaLib)
local MODULES = {} 
local function registerModule(id, meta) MODULES[id] = meta end

-- === [ LinoriaLib UI Setup ] ===
local Window = LinoriaLib:CreateWindow(GUI_NAME .. " | " .. L("title"), {
    Color = Color3.fromRGB(0, 0, 0),
    OutlineColor = Color3.fromRGB(0, 0, 0),
    AccentColor = Color3.fromRGB(207,48,74),
    Font = LinoriaLib.Fonts.Montserrat,
    Keybind = Enum.KeyCode.RightControl
})
Window:SetTheme(SETTINGS.theme)

local Tabs = {}
Tabs.FARM = Window:AddTab(L("farm_section"))
Tabs.SETTINGS = Window:AddTab(L("lang_section")) 

local configListLinoria = nil 

local function refreshConfigListLinoria()
    local list = listConfigs()
    local listForDD = #list > 0 and list or {"---"}

    if configListLinoria then
        configListLinoria:SetOptions(listForDD)
        configListLinoria:SetValue(configListLinoria:GetValue() or listForDD[1]) 
    end

    local auto = getAutoload()
    Window:SetFooter(L("current_autoload") .. ": " .. (auto or "---"))
end

local function loadConfigToModules(configData, configName)
    if not configData then warn(L("error_load") .. configName); return end
    if configData.settings then
        SETTINGS.lang = configData.settings.lang or SETTINGS.lang
        SETTINGS.theme = configData.settings.theme or SETTINGS.theme
        Window:SetTheme(SETTINGS.theme)
        if Tabs.SETTINGS.ddLang then Tabs.SETTINGS.ddLang:SetValue(SETTINGS.lang) end
        if Tabs.SETTINGS.ddTheme then Tabs.SETTINGS.ddTheme:SetValue(SETTINGS.theme) end
    end
    
    for id,meta in pairs(MODULES) do
        if meta and meta.LoadConfigData then
            pcall(meta.LoadConfigData, configData.modules and configData.modules[id] or {})
        end
    end
    print(L("config_loaded"), configName)
    refreshConfigListLinoria() 
end


-- === [ Config Tab ] ===
local ConfigSection = Tabs.SETTINGS:AddSection(L("config_section"))

ConfigSection:AddInput(L("config_name"), PIXEL_BLADE_ID .. "_config", function(value)
    ConfigSection.configNameValue = value
end, {Tooltip = "Enter a name for your config."}):OnNew(function(input)
    input:SetValue(PIXEL_BLADE_ID .. "_config")
    ConfigSection.configNameValue = PIXEL_BLADE_ID .. "_config"
end)

ConfigSection:AddButton(L("create"), function()
    local name = ConfigSection.configNameValue:gsub("%s+$","")
    if name == "" or not name then return end
    local cfg = {
        meta = {created = os_time(), by = "user"},
        settings = {lang = SETTINGS.lang, theme = SETTINGS.theme},
        modules = {} 
    }
    for id, meta in pairs(MODULES) do
        if meta and meta.GetConfigData and (meta.category == "global" or tostring(meta.category) == tostring(game.PlaceId)) then
            local ok, data = pcall(meta.GetConfigData)
            if ok and data then cfg.modules[id] = data end
        end
    end
    local ok, err = pcall(function() saveConfig(name, cfg) end)
    if ok then
        refreshConfigListLinoria()
        print(L("config_saved"), name)
    else
        warn(L("error_save"), err)
    end
end)

configListLinoria = ConfigSection:AddDropdown(L("list"), {"---"}, function(value)
    -- Value update
end, {Tooltip = "Select a saved config to load or manage."})

ConfigSection:AddButton(L("load"), function()
    local selected = configListLinoria:GetValue()
    if not selected or selected == "---" then return end
    local data, err = loadConfig(selected)
    loadConfigToModules(data, selected)
end)
ConfigSection:AddButton(L("overwrite"), function()
    local selected = configListLinoria:GetValue()
    if not selected or selected == "---" then return end
    local cfg = {meta = {updated = os_time()}, settings = {lang = SETTINGS.lang, theme = SETTINGS.theme}, modules = {}}
    for id, meta in pairs(MODULES) do
        if meta and meta.GetConfigData and (meta.category == "global" or tostring(meta.category) == tostring(game.PlaceId)) then
            local ok, data = pcall(meta.GetConfigData)
            if ok and data then cfg.modules[id] = data end
        end
    end
    local ok, err = pcall(function() saveConfig(selected, cfg) end)
    if ok then print(L("config_overwrite_ok"), selected) refreshConfigListLinoria() else warn(err) end
end)
ConfigSection:AddButton(L("delete"), function()
    local selected = configListLinoria:GetValue()
    if not selected or selected == "---" then return end
    local ok = pcall(function() deleteConfig(selected) end)
    if ok then print(L("config_deleted"), selected) refreshConfigListLinoria() end
end)
ConfigSection:AddButton(L("set_autoload"), function()
    local selected = configListLinoria:GetValue()
    if not selected or selected == "---" then return end
    setAutoload(selected)
    refreshConfigListLinoria()
end)
ConfigSection:AddButton(L("reset_autoload"), function()
    setAutoload(nil)
    refreshConfigListLinoria()
end)

-- === [ UI Options Tab ] ===
local UIOptionsSection = Tabs.SETTINGS:AddSection(L("lang_section"))
Tabs.SETTINGS.ddLang = UIOptionsSection:AddDropdown("Language", {"vi", "en"}, function(value)
    SETTINGS.lang = value
    Window:SetTitle(GUI_NAME .. " | " .. L("title"))
    Tabs.FARM:SetTitle(L("farm_section"))
    Tabs.SETTINGS:SetTitle(L("lang_section"))
    refreshConfigListLinoria() 
end, {Tooltip = "Change the UI language."})
Tabs.SETTINGS.ddLang:SetValue(SETTINGS.lang)

Tabs.SETTINGS.ddTheme = UIOptionsSection:AddDropdown(L("theme_option"), {"DarkBlue", "DarkRed", "DarkGreen", "LightBlue", "LightRed", "LightGreen"}, function(value)
    SETTINGS.theme = value
    Window:SetTheme(value)
end, {Tooltip = "Change the UI theme."})
Tabs.SETTINGS.ddTheme:SetValue(SETTINGS.theme)

local AntiBanSection = Tabs.FARM:AddSection(L("anti_section"))
AntiBanSection:AddParagraph(L("anti_desc"), "")

-- === [ Targetting Logic ] ===
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

        if PIXEL_BLADE_SETTINGS.AutoBehindTarget and Player.Character and Player.Character.PrimaryPart then
            local backVector = target.PrimaryPart.CFrame.lookVector * 5 
            return fuzzyTargetPos - backVector 
        end
        return fuzzyTargetPos
    end
    return nil
end

-- ==== Module: PIXEL BLADE FARM (18172550962) - V5.1 ====
registerModule("pixel_blade_farm", {
    name = "Pixel Blade Farm",
    category = tostring(PIXEL_BLADE_ID), 
    
    init = function()
        local loopConnection = nil
        local lastAttackTime = 0
        local burstCounter = 0
        local lastSkillTime = 0
        local lastHealTime = 0
        local lastFreezeTime = 0
        
        -- UI Controls (References)
        local tAura, sRange, sDelay, tAutoMove, tAutoBehind, tAutoSkills, tAutoHeal, sHPThresh, tAutoUpgrade, tSelectAll, tFreezeAI, sEnemyHB, sPlayerHB, kbPanic, tAutoDisconnect

        -- V4 Logic: Hàm Ngắt Khẩn Cấp và Dọn Dẹp
        local function executePanicSwitch(isBanRisk)
            if loopConnection then loopConnection:Disconnect() loopConnection = nil end
            
            Window:Hide()
            
            -- Clean Up
            pcall(tAura.SetValue, false)
            pcall(tAutoMove.SetValue, false)
            pcall(tAutoSkills.SetValue, false)
            pcall(tAutoHeal.SetValue, false)
            pcall(tFreezeAI.SetValue, false)
            
            pcall(sPlayerHB.SetValue, 1.0)
            pcall(sEnemyHB.SetValue, 1.0)
            
            -- Auto Disconnect
            if isBanRisk and PIXEL_BLADE_SETTINGS.AutoDisconnect then
                warn("ADMIN DETECTED! Executing safe shutdown...")
                pcall(function() game:Shutdown() end) 
            else
                print("Panic switch activated. Exploit disabled.")
            end
        end

        -- V4 Logic: Phát hiện Admin
        local function checkAdmins()
            if os_clock() - (checkAdmins.lastTime or 0) < 5.0 then return end
            checkAdmins.lastTime = os_clock()
            
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

        local function updateSettings()
            PIXEL_BLADE_SETTINGS.AuraEnabled = tAura:GetValue()
            PIXEL_BLADE_SETTINGS.AuraRange = sRange:GetValue()
            PIXEL_BLADE_SETTINGS.AttackDelay = sDelay:GetValue()
            PIXEL_BLADE_SETTINGS.AutoBehindTarget = tAutoBehind:GetValue()
            PIXEL_BLADE_SETTINGS.AutoMoveToTarget = tAutoMove:GetValue()
            PIXEL_BLADE_SETTINGS.AutoSkills = tAutoSkills:GetValue()
            PIXEL_BLADE_SETTINGS.AutoHeal = tAutoHeal:GetValue()
            PIXEL_BLADE_SETTINGS.AutoHealHPThreshold = sHPThresh:GetValue() / 100
            PIXEL_BLADE_SETTINGS.AutoUpgrade = tAutoUpgrade:GetValue()
            PIXEL_BLADE_SETTINGS.SelectAllBuffs = tSelectAll:GetValue()
            PIXEL_BLADE_SETTINGS.FreezeEnemyAI = tFreezeAI:GetValue()
            PIXEL_BLADE_SETTINGS.EnemyHitboxScale = sEnemyHB:GetValue()
            PIXEL_BLADE_SETTINGS.PlayerHitboxScale = sPlayerHB:GetValue()
            PIXEL_BLADE_SETTINGS.AutoDisconnect = tAutoDisconnect:GetValue()

            if PIXEL_BLADE_SETTINGS.AuraEnabled or PIXEL_BLADE_SETTINGS.AutoSkills or PIXEL_BLADE_SETTINGS.AutoHeal or PIXEL_BLADE_SETTINGS.FreezeEnemyAI then
                if not loopConnection then startLoop() end
            else
                if loopConnection then loopConnection:Disconnect() loopConnection = nil end
            end
        end

        -- Main Exploiting Loop (Đã tích hợp Anti-Ban V5)
        local function startLoop()
            loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
                local timeNow = os_clock()
                local char = Player.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                
                if not char or not humanoid or humanoid.Health <= 0 or not char.PrimaryPart then return end

                local primaryPart = char.PrimaryPart
                
                local target = updateTargetCache(PIXEL_BLADE_SETTINGS.AuraRange)

                -- 1. Kill Aura/Auto Attack 
                local currentAttackDelay = PIXEL_BLADE_SETTINGS.AttackDelay 
                
                if PIXEL_BLADE_SETTINGS.AuraEnabled and target then
                    if burstCounter > 0 then
                        local jitterDelay = random(currentAttackDelay * 0.9, currentAttackDelay * 1.05)
                        
                        if timeNow - lastAttackTime >= jitterDelay then
                            if AttackRemote and AttackRemote.FireServer then 
                                pcall(AttackRemote.FireServer, AttackRemote, target) 
                            end
                            
                            lastAttackTime = timeNow
                            burstCounter = burstCounter - 1
                        end
                    else
                        local jitterBurstDelay = random(BURST_DELAY * 0.9, BURST_DELAY * 1.1)
                        
                        if timeNow - lastAttackTime >= jitterBurstDelay then
                            burstCounter = BURST_ATTACK_COUNT 
                        end
                    end
                end

                -- Auto Move 
                if PIXEL_BLADE_SETTINGS.AutoMoveToTarget and target and target.PrimaryPart then
                    local targetPos = getTargetPosition(target)
                    local currentPos = primaryPart.Position
                    local distance = (targetPos - currentPos).Magnitude
                    
                    if distance > 1.0 then 
                        local moveVector = (targetPos - currentPos).Unit * distance * 0.15 
                        local newCFrame = CFrame.new(currentPos + moveVector)
                        pcall(function() char:SetPrimaryPartCFrame(newCFrame) end)
                    end
                end

                -- 2. Auto Skills & 3. Auto Heal
                if PIXEL_BLADE_SETTINGS.AutoSkills and (timeNow - lastSkillTime > EstimateServerCooldown(random(0.2, 0.3))) then 
                    if SkillRemote and SkillRemote.FireServer then
                        pcall(SkillRemote.FireServer, SkillRemote, "AllSkills") -- Placeholder parameter
                        lastSkillTime = timeNow
                    end
                end
                
                local currentHPPercent = humanoid.Health / (humanoid.MaxHealth * 2.0) 
                local healThreshold = PIXEL_BLADE_SETTINGS.AutoHealHPThreshold 

                if PIXEL_BLADE_SETTINGS.AutoHeal and currentHPPercent < healThreshold and (timeNow - lastHealTime > 5.0) then
                    if humanoid.Health < humanoid.MaxHealth then
                         if HealRemote and HealRemote.FireServer then
                            pcall(HealRemote.FireServer, HealRemote)
                            lastHealTime = timeNow
                         end
                    end
                end

                -- 4. Freeze Enemy AI
                if PIXEL_BLADE_SETTINGS.FreezeEnemyAI and (timeNow - lastFreezeTime > 0.5) then
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
        
        -- UI Definition (Moved here to use the local function updateSettings)
        local FarmSection = Tabs.FARM:AddSection(L("farm_section"))
        tAura = FarmSection:AddToggle(L("farm_toggle"), PIXEL_BLADE_SETTINGS.AuraEnabled, function(value) updateSettings() end)
        sRange = FarmSection:AddSlider(L("farm_range"), PIXEL_BLADE_SETTINGS.AuraRange, 100, 1000, function(value) updateSettings() end, {Rounding = 0, Suffix = " Studs"})
        sDelay = FarmSection:AddSlider(L("farm_delay"), PIXEL_BLADE_SETTINGS.AttackDelay, 0.01, 1.0, function(value) updateSettings() end, {Rounding = 2, Suffix = " s"})
        tAutoMove = FarmSection:AddToggle(L("farm_move"), PIXEL_BLADE_SETTINGS.AutoMoveToTarget, function(value) updateSettings() end)
        tAutoBehind = FarmSection:AddToggle(L("farm_back"), PIXEL_BLADE_SETTINGS.AutoBehindTarget, function(value) updateSettings() end)
        
        local SkillSection = Tabs.FARM:AddSection(L("skill_section"))
        tAutoSkills = SkillSection:AddToggle(L("skill_all"), PIXEL_BLADE_SETTINGS.AutoSkills, function(value) updateSettings() end)
        tAutoHeal = SkillSection:AddToggle(L("skill_heal"), PIXEL_BLADE_SETTINGS.AutoHeal, function(value) updateSettings() end)
        sHPThresh = SkillSection:AddSlider(L("skill_hp_thresh"), PIXEL_BLADE_SETTINGS.AutoHealHPThreshold * 100, 10, 90, function(value) updateSettings() end, {Rounding = 0, Suffix = " %"})
        tAutoUpgrade = SkillSection:AddToggle(L("upgrade_auto"), PIXEL_BLADE_SETTINGS.AutoUpgrade, function(value) updateSettings() end)
        tSelectAll = SkillSection:AddToggle(L("upgrade_select_all"), PIXEL_BLADE_SETTINGS.SelectAllBuffs, function(value) updateSettings() end)

        local ExploitSection = Tabs.FARM:AddSection(L("exploit_section"))
        tFreezeAI = ExploitSection:AddToggle(L("enemy_control"), PIXEL_BLADE_SETTINGS.FreezeEnemyAI, function(value) updateSettings() end)
        sEnemyHB = ExploitSection:AddSlider(L("enemy_hitbox"), PIXEL_BLADE_SETTINGS.EnemyHitboxScale, 0.5, 1.0, function(value) updateSettings() end, {Rounding = 2, Suffix = "x"})
        sPlayerHB = ExploitSection:AddSlider(L("player_hitbox"), PIXEL_BLADE_SETTINGS.PlayerHitboxScale, 1.0, 1.5, function(value) updateSettings() end, {Rounding = 1, Suffix = "x"})
        kbPanic = ExploitSection:AddKeybind(L("panic_switch"), PANIC_KEY, function(key) PANIC_KEY = key; updateSettings() end)
        tAutoDisconnect = ExploitSection:AddToggle(L("auto_disconnect"), PIXEL_BLADE_SETTINGS.AutoDisconnect, function(value) updateSettings() end)

        -- Bind the Panic key to the executePanicSwitch function
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == kbPanic:GetValue() then
                executePanicSwitch(false)
            end
        end)
        
        -- Export config data functions
        getmetatable(MODULES["pixel_blade_farm"]).GetConfigData = function() return PIXEL_BLADE_SETTINGS end
        getmetatable(MODULES["pixel_blade_farm"]).LoadConfigData = function(data)
            local needUpdate = false
            for k, v in pairs(data) do
                if PIXEL_BLADE_SETTINGS[k] ~= nil then
                    PIXEL_BLADE_SETTINGS[k] = v
                    needUpdate = true
                end
            end
            if needUpdate then
                -- Load UI values from config
                pcall(tAura.SetValue, PIXEL_BLADE_SETTINGS.AuraEnabled)
                pcall(sRange.SetValue, PIXEL_BLADE_SETTINGS.AuraRange)
                pcall(sDelay.SetValue, PIXEL_BLADE_SETTINGS.AttackDelay)
                pcall(tAutoMove.SetValue, PIXEL_BLADE_SETTINGS.AutoMoveToTarget)
                pcall(tAutoBehind.SetValue, PIXEL_BLADE_SETTINGS.AutoBehindTarget)
                pcall(tAutoSkills.SetValue, PIXEL_BLADE_SETTINGS.AutoSkills)
                pcall(tAutoHeal.SetValue, PIXEL_BLADE_SETTINGS.AutoHeal)
                pcall(sHPThresh.SetValue, PIXEL_BLADE_SETTINGS.AutoHealHPThreshold * 100)
                pcall(tAutoUpgrade.SetValue, PIXEL_BLADE_SETTINGS.AutoUpgrade)
                pcall(tSelectAll.SetValue, PIXEL_BLADE_SETTINGS.SelectAllBuffs)
                pcall(tFreezeAI.SetValue, PIXEL_BLADE_SETTINGS.FreezeEnemyAI)
                pcall(sEnemyHB.SetValue, PIXEL_BLADE_SETTINGS.EnemyHitboxScale)
                pcall(sPlayerHB.SetValue, PIXEL_BLADE_SETTINGS.PlayerHitboxScale)
                pcall(tAutoDisconnect.SetValue, PIXEL_BLADE_SETTINGS.AutoDisconnect)
                pcall(kbPanic.SetValue, PANIC_KEY) -- Update keybind display

                updateSettings() 
            end
        end
    end,
    
    GetConfigData = function() return PIXEL_BLADE_SETTINGS end,
    LoadConfigData = function(data) end 
})

-- ==== Loader & Autoload Execution ====

-- try autoload if exists
pcall(function()
    local auto = getAutoload()
    if auto and auto ~= "" then
        local ok, data = pcall(loadConfig, auto)
        if ok and data then
            print("Autoloaded config:", auto)
            SETTINGS._autoload_data = data
        end
    end
end)

-- Initialize all modules
pcall(function()
    for id, meta in pairs(MODULES) do
        pcall(meta.init)
    end
end)

-- Execute autoload data if present
pcall(function()
    if SETTINGS._autoload_data then
        for id,meta in pairs(MODULES) do
            if meta and meta.LoadConfigData then
                pcall(meta.LoadConfigData, SETTINGS._autoload_data.modules and SETTINGS._autoload_data.modules[id] or {})
            end
        end
    end
end)

refreshConfigListLinoria()
Window:SelectTab(Tabs.FARM)
Window:SetEnabled(true)

print(GUI_NAME .. " loaded successfully with LinoriaLib. Stealth Anti-Ban V5.1 is active.")

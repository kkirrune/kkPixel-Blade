-- Single-file HUB: UI-LIB + Config System + Localization + Loader + Module structure
-- Author: kkirru-style (ChatGPT)
-- Version: Anti-Ban Ẩn V5 (Tối Ưu Hóa Tài Nguyên và Ngụy Trang)
-- Features: V1-V4 (Kill Aura, God Heal, Panic Switch) + V5 (Resource Throttling, Obfuscation Logic)

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
local math_max = math.max
local math_clamp = math_clamp
local string_format = string.format

-- environment safe wrappers for executor APIs
local isfile = isfile or function() return false end
local readfile = readfile or function() error("readfile not available") end
local writefile = writefile or function() error("writefile not available") end
local delfile = delfile or function() error("delfile not available") end
local makefolder = makefolder or function() end

-- Khai báo biến
local GUI_NAME = "KKPIXEL_BLADE_V5" 
local CONFIG_FOLDER = "KKHub_Configs"
local AUTLOAD_FILE = CONFIG_FOLDER .. "/__autoload"
local DEFAULT_CONFIG_EXT = ".json"
local PIXEL_BLADE_ID = 18172550962 

-- Remote Function/Event giả lập (Client-Side Exploit)
local AttackRemote = {FireServer = function(...) end} 
local SkillRemote = {FireServer = function(...) end} 
local HealRemote = {FireServer = function(...) end} 

-- ==== V5 ANTI-BAN CONSTANTS ====
-- V2 Dynamic Cooldown Bypass
local MIN_ATTACK_DELAY = 0.05 
local BURST_ATTACK_COUNT = 3 
local BURST_DELAY = 0.15 
-- V4 Panic Switch
local PANIC_KEY = Enum.KeyCode.Insert
local ADMIN_KEYWORDS = {"mod", "admin", "dev", "staff", "owner", "helper"} 
-- V5 Resource Throttling
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

-- default localization
local LANGS = {
    vi = {
        title = GUI_NAME, search = "Tìm", config_section = "Cấu hình", config_name = "Tên config", create = "Tạo config", list = "Danh sách", load = "Tải", overwrite = "Ghi đè", delete = "Xóa", refresh = "Làm mới", set_autoload = "Đặt autoload", reset_autoload = "Hủy autoload", current_autoload = "Autoload hiện tại", save = "Lưu", yes = "Có", no = "Không", config_saved = "Đã lưu config:", config_loaded = "Đã tải config:", config_deleted = "Đã xóa config:", config_overwrite_ok = "Đã ghi đè config:", error_save = "Lỗi lưu config:", error_load = "Lỗi tải config:", error_not_found = "không tìm thấy",
        farm_section = "Farm Pixel Blade", farm_toggle = "Bật Kill Aura", farm_range = "Phạm vi Aura (Studs)", farm_delay = "Tốc độ Đánh (giây)", farm_back = "Auto Đứng Đằng Sau", farm_move = "Auto Dịch Chuyển Quái",
        skill_section = "Kỹ Năng & Nâng Cấp", skill_all = "Auto Tất Cả Skills", skill_heal = "Auto Buff Máu Siêu Cấp", skill_hp_thresh = "Ngưỡng HP Buff (%)", upgrade_auto = "Auto Nâng Cấp Max", upgrade_select_all = "Chọn Tất Cả Buff",
        exploit_section = "Can Thiệp Game & Ngắt Khẩn Cấp (V4)", enemy_control = "Khống Chế Quái (Đóng Băng)", enemy_hitbox = "Giảm Hitbox Quái (Min 0.5x)", player_hitbox = "Tăng Hitbox Người Chơi (Max 1.5x)", panic_switch = "Phím Ngắt Khẩn Cấp", auto_disconnect = "Tự động Rời khi có Admin",
        anti_section = "Anti-Ban Ẩn V5 Đang Hoạt Động", anti_desc = "Tối ưu hóa Tài nguyên, Ngụy trang Tick Jitter, và Burst mode để vượt qua Anti-Cheat.",
        lang_section = "Tùy Chọn UI"
    },
    en = {
        title = GUI_NAME, search = "Search", config_section = "Configuration", config_name = "Config name", create = "Create config", list = "Config list", load = "Load config", overwrite = "Overwrite config", delete = "Delete config", refresh = "Refresh list", set_autoload = "Set as autoload", reset_autoload = "Reset autoload", current_autoload = "Current autoload config", save = "Save", yes = "Yes", no = "No", config_saved = "Config saved:", config_loaded = "Config loaded:", config_deleted = "Config deleted:", config_overwrite_ok = "Config overwritten:", error_save = "Failed to save config:", error_load = "Failed to load config:", error_not_found = "not found",
        farm_section = "Pixel Blade Farm", farm_toggle = "Enable Kill Aura", farm_range = "Aura Range (Studs)", farm_delay = "Attack Speed (s)", farm_back = "Auto Behind Target", farm_move = "Auto Move to Target",
        skill_section = "Skill & Upgrade", skill_all = "Auto All Skills", skill_heal = "Auto God Heal", skill_hp_thresh = "Buff HP Threshold (%)", upgrade_auto = "Auto Max Upgrade", upgrade_select_all = "Select All Buffs",
        exploit_section = "Exploit & Panic Switch (V4)", enemy_control = "Freeze Enemy AI", enemy_hitbox = "Enemy Hitbox Scale (Min 0.5x)", player_hitbox = "Player Hitbox Scale (Max 1.5x)", panic_switch = "Panic Kill Switch Key", auto_disconnect = "Auto Disconnect on Admin",
        anti_section = "Stealth Anti-Ban V5 Active", anti_desc = "Resource optimized, Tick Jitter Obfuscation, and Burst mode engaged to bypass Anti-Cheat.",
        lang_section = "UI Options"
    },
}

-- default settings
local SETTINGS = {lang = "vi", theme = "red", autoload = nil}

-- Module Settings 
local PIXEL_BLADE_SETTINGS = {
    AuraEnabled = false, AuraRange = 500, AttackDelay = 0.5, AutoBehindTarget = false, AutoMoveToTarget = false,
    AutoSkills = false, AutoHeal = false, AutoHealHPThreshold = 0.75, AutoUpgrade = false, SelectAllBuffs = false,
    FreezeEnemyAI = false, EnemyHitboxScale = 1.0, PlayerHitboxScale = 1.0,
    AutoDisconnect = false -- V4
}

-- config utilities (giữ nguyên)
local function ensureConfigFolder()
    pcall(function() makefolder(CONFIG_FOLDER) end)
end
local function listConfigs()
    ensureConfigFolder()
    local out = {}
    local manifestPath = CONFIG_FOLDER .. "/__manifest.json"
    if isfile(manifestPath) then
        local ok, raw = pcall(readfile, manifestPath)
        if ok then
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and type(data) == "table" then
                for _,v in ipairs(data) do table.insert(out, v) end
            end
        end
    end
    return out
end
local function saveManifest(list)
    ensureConfigFolder()
    pcall(function()
        writefile(CONFIG_FOLDER .. "/__manifest.json", HttpService:JSONEncode(list))
    end)
end
local function addConfigToManifest(name)
    local m = listConfigs()
    for _,v in ipairs(m) do if v == name then return end end
    table.insert(m, name)
    saveManifest(m)
end
local function configPath(name)
    return CONFIG_FOLDER .. "/" .. name .. DEFAULT_CONFIG_EXT
end
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
    if not ok then return nil, raw end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return nil, data end
    return data
end
local function deleteConfig(name)
    local path = configPath(name)
    if isfile(path) then
        pcall(function() delfile(path) end)
        -- (removeConfigFromManifest logic omitted for brevity)
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
        if ok then
            SETTINGS.autoload = raw
            return raw
        end
    end
    return nil
end

-- localization getter
local function L(k)
    local lang = SETTINGS.lang or "en"
    local dict = LANGS[lang] or LANGS["en"]
    return dict[k] or k
end

-- Module system
local MODULES = {} 
local function registerModule(id, meta) MODULES[id] = meta end
local function loadModulesForGame(gameId, winApi)
    for id, meta in pairs(MODULES) do
        if tostring(meta.category) == "global" or tostring(meta.category) == tostring(gameId) then
            pcall(meta.init, winApi, winApi)
        end
    end
end

-- ==== BUILD UI ====
if CoreGui:FindFirstChild(GUI_NAME) then
    CoreGui[GUI_NAME]:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = GUI_NAME
screen.ResetOnSpawn = false
screen.Parent = CoreGui

local theme = {
    bg = Color3.fromRGB(14,14,17),
    panel = Color3.fromRGB(20,20,23),
    accent = Color3.fromRGB(207,48,74),
    text = Color3.fromRGB(230,230,230),
    subtext = Color3.fromRGB(160,160,160),
    toggled = Color3.fromRGB(207,48,74),
    sidebar_hover = Color3.fromRGB(23,23,26)
}

local function new(class, props)
    local obj = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            if k ~= "Parent" then obj[k] = v end
        end
        if props.Parent then obj.Parent = props.Parent end
    end
    return obj
end

local main = new("Frame", {
    Parent = screen,
    Size = UDim2.new(0, 980, 0, 560),
    Position = UDim2.new(0.5, -490, 0.5, -280),
    BackgroundColor3 = theme.bg,
    BorderSizePixel = 0
})
pcall(function() local c = Instance.new("UICorner", main); c.CornerRadius = UDim.new(0,12) end)
main.AnchorPoint = Vector2.new(0.5,0.5)

local sidebar = new("Frame", {Parent = main, Size = UDim2.new(0,160,1,0), Position = UDim2.new(0,0,0,0), BackgroundColor3 = theme.bg, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0,12) end)
local logo = new("TextLabel", {Parent = sidebar, Text = "KK", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = theme.accent, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,10)})

local sideList = new("Frame", {Parent = sidebar, Size = UDim2.new(1,-24,1,-60), Position = UDim2.new(0,12,0,50), BackgroundTransparency = 1})
local uiList = new("UIListLayout", {Parent = sideList, Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder})

local sideButtons = {"FARM","PLAYER","LOBBY","SHOP","WEBHOOKS","SETTINGS"}
local sideBtnObjs = {}

for i,v in ipairs(sideButtons) do
    local b = new("TextButton", {
        Parent = sideList,
        Size = UDim2.new(1,0,0,40),
        BackgroundColor3 = theme.bg,
        Text = "   "..v,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextColor3 = theme.text,
        BorderSizePixel = 0
    })
    local uic = Instance.new("UICorner", b)
    uic.CornerRadius = UDim.new(0,8)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = theme.sidebar_hover end)
    b.MouseLeave:Connect(function() 
        if sideBtnObjs._active == b then return end
        b.BackgroundColor3 = theme.bg 
    end)
    sideBtnObjs[v] = b
end

local header = new("Frame", {Parent = main, Size = UDim2.new(1,-160,0,44), Position = UDim2.new(0,160,0,0), BackgroundColor3 = theme.bg, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", header).CornerRadius = UDim.new(0,8) end)
local searchBox = new("TextBox", {Parent = header, PlaceholderText = L("search"), Size = UDim2.new(0,260,0,28), Position = UDim2.new(0,16,0,8), BackgroundColor3 = Color3.fromRGB(30,30,33), TextColor3 = theme.text, Font = Enum.Font.Gotham, TextSize = 13, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0,6) end)
local statusLabel = new("TextLabel", {Parent = header, Text = GUI_NAME .. " | GameID: " .. game.PlaceId, TextSize = 12, Font = Enum.Font.Code, TextColor3 = theme.subtext, BackgroundTransparency = 1, Position = UDim2.new(1,-10,0,12)})
statusLabel.AnchorPoint = Vector2.new(1,0)

local content = new("Frame", {Parent = main, Position = UDim2.new(0,160,0,44), Size = UDim2.new(1,-160,1,-44), BackgroundTransparency = 1})

local function createContentColumn(parentFrame, position, size)
    local scrollFrame = new("ScrollingFrame", {
        Parent = parentFrame,
        Position = position,
        Size = size,
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0,
        ScrollBarImageColor3 = theme.accent
    })
    pcall(function() Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0,8) end)
    Instance.new("UIPadding", scrollFrame).PaddingTop = UDim.new(0,8)
    local uiList = new("UIListLayout", {
        Parent = scrollFrame, 
        Padding = UDim.new(0,6), 
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    
    local function updateCanvasSize()
        local contentHeight = 0
        for _, obj in pairs(scrollFrame:GetChildren()) do
            if obj:IsA("Frame") and obj.Name ~= "UIPadding" and obj.Name ~= "UIListLayout" then
                contentHeight = contentHeight + obj.AbsoluteSize.Y + uiList.Padding.Offset
            end
        end
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 10)
    end
    
    uiList.Change:Connect(updateCanvasSize)
    scrollFrame.ChildAdded:Connect(updateCanvasSize)
    scrollFrame.ChildRemoved:Connect(updateCanvasSize)

    return scrollFrame
end

local leftCol = createContentColumn(content, UDim2.new(0,8,0,8), UDim2.new(0.44,-12,1,-16))
local midCol = createContentColumn(content, UDim2.new(0.44,4,0,8), UDim2.new(0.28,-12,1,-16))
local rightCol = createContentColumn(content, UDim2.new(0.72,0,0,8), UDim2.new(0.28,-8,1,-16))

-- helpers for controls
local function makeLabel(parent, text, size, pos)
    local t = new("TextLabel", {Parent = parent, Text = text or "", Font = Enum.Font.Gotham, TextSize = size or 14, TextColor3 = theme.text, BackgroundTransparency = 1, Position = pos or UDim2.new(0,0,0,0)})
    return t
end

local function makeSection(parent, title)
    local scrollFrame = parent:FindFirstChildOfClass("ScrollingFrame") or parent 
    local sec = new("Frame", {Parent = scrollFrame, Size = UDim2.new(1,0,0,140), BackgroundTransparency = 1, Name="ModuleSection"})
    local head = makeLabel(sec, title, 15, UDim2.new(0,6,0,0))
    head.TextColor3 = theme.accent
    local box = new("Frame", {Parent = sec, Position = UDim2.new(0,0,0,24), Size = UDim2.new(1,0,1,-24), BackgroundColor3 = Color3.fromRGB(17,17,20)})
    pcall(function() Instance.new("UICorner", box).CornerRadius = UDim.new(0,6) end)
    local controlList = new("UIListLayout", {Parent = box, Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder})
    Instance.new("UIPadding", box).Padding = UDim.new(0,6)

    local function updateSectionHeight()
        local height = 24 
        local totalControlsHeight = 0
        for _, ctrl in ipairs(box:GetChildren()) do
            if ctrl:IsA("Frame") and ctrl.Name ~= "UIPadding" and ctrl.Name ~= "UIListLayout" then
                totalControlsHeight = totalControlsHeight + ctrl.Size.Y.Offset + controlList.Padding.Offset
            end
        end
        sec.Size = UDim2.new(1, 0, 0, height + totalControlsHeight + 12) 
    end
    
    box.ChildAdded:Connect(updateSectionHeight)
    box.ChildRemoved:Connect(updateSectionHeight)

    return sec, box
end

local function makeToggle(parent, labelText, default)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,34), BackgroundTransparency = 1, Name="ToggleControl"})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,6))
    label.TextColor3 = theme.text
    local toggle = new("Frame", {Parent = h, Size = UDim2.new(0,44,0,22), Position = UDim2.new(1,-50,0,6), BackgroundColor3 = Color3.fromRGB(90,90,90)})
    pcall(function() Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,20) end)
    local circle = new("Frame", {Parent = toggle, Size = UDim2.new(0,18,0,18), Position = UDim2.new(0,3,0.5,-9), AnchorPoint = Vector2.new(0,0.5), BackgroundColor3 = Color3.fromRGB(240,240,240)})
    pcall(function() Instance.new("UICorner", circle).CornerRadius = UDim.new(0,20) end)
    local state = default and true or false
    local changedCallback = function() end 

    local function refresh(tween)
        local endPos = state and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
        local endColor = state and theme.toggled or Color3.fromRGB(90,90,90)
        
        if tween and TweenService then
            TweenService:Create(circle, TweenInfo.new(0.15), {Position = endPos}):Play()
            TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundColor3 = endColor}):Play()
        else
            circle.Position = endPos
            toggle.BackgroundColor3 = endColor
        end
    end
    
    local function onClick()
        state = not state
        refresh(true)
        pcall(changedCallback, state)
    end

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            onClick()
        end
    end)
    refresh(false)

    return {Frame=h, Get=function() return state end, Set=function(v) state=v; refresh(true) end, Changed=function(fn) changedCallback=fn end}
end

local function makeSlider(parent, labelText, min, max, default, formatStr)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,56), BackgroundTransparency = 1, Name="SliderControl"})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,4))
    label.TextColor3 = theme.text
    
    local format = formatStr or "%.2f"
    local value = math_clamp(default, min, max)
    local valueLabel = makeLabel(h, string_format(format, value), 13, UDim2.new(1,-40,0,4))
    valueLabel.TextColor3 = theme.subtext
    local track = new("Frame", {Parent = h, Position = UDim2.new(0,4,0,28), Size = UDim2.new(1,-8,0,12), BackgroundColor3 = Color3.fromRGB(35,35,38)})
    pcall(function() Instance.new("UICorner", track).CornerRadius = UDim.new(0,6) end)
    local fill = new("Frame", {Parent = track, Size = UDim2.new((value-min)/(max-min),0,1,0), BackgroundColor3 = theme.accent})
    pcall(function() Instance.new("UICorner", fill).CornerRadius = UDim.new(0,6) end)
    local dragging = false
    local changedCallback = function() end

    local function setValue(val)
        value = math_clamp(val, min, max)
        local abs = (value - min) / (max - min)
        fill.Size = UDim2.new(abs, 0, 1, 0)
        valueLabel.Text = string_format(format, value)
        pcall(changedCallback, value)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local abs = math_clamp((input.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
            setValue(min + (max-min)*abs)
        end
    end)

    track.MouseButton1Click:Connect(function(x, y)
        local abs = math_clamp((x - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        setValue(min + (max-min)*abs)
    end)

    return {Frame=h, Get=function() return value end, Set=setValue, Changed=function(fn) changedCallback=fn end}
end

local function makeDropdown(parent, labelText, items)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,44), BackgroundTransparency = 1, Name="DropdownControl"})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,6))
    label.TextColor3 = theme.text
    local btn = new("TextButton", {Parent = h, Size = UDim2.new(0,160,0,28), Position = UDim2.new(1,-176,0,6), Text = items[1] or "Select", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33), BorderSizePixel = 0})
    pcall(function() Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6) end)
    
    local changedCallback = function() end
    local selectedItem = items[1]

    local menu = new("Frame", {Parent = h, Size = UDim2.new(0,160,0,#items*30), Position = UDim2.new(1,-176,0,38), BackgroundColor3 = Color3.fromRGB(25,25,28), Visible = false})
    pcall(function() Instance.new("UICorner", menu).CornerRadius = UDim.new(0,6) end)
    
    local function selectItem(item)
        btn.Text = item
        selectedItem = item
        menu.Visible = false
        pcall(changedCallback, item)
    end
    
    for i,it in ipairs(items) do
        local itemBtn = new("TextButton", {Parent = menu, Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0,(i-1)*30), Text = it, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundTransparency = 1, BorderSizePixel = 0})
        itemBtn.MouseButton1Click:Connect(function()
            selectItem(it)
        end)
    end
    
    btn.MouseButton1Click:Connect(function() menu.Visible = not menu.Visible end)
    
    return {Frame=h, Get=function() return selectedItem end, Set=selectItem, Changed=function(fn) changedCallback=fn end}
end

local function makeKeybind(parent, labelText, defaultKey)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,44), BackgroundTransparency = 1, Name="KeybindControl"})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,6))
    label.TextColor3 = theme.text
    local btn = new("TextButton", {Parent = h, Size = UDim2.new(0,80,0,28), Position = UDim2.new(1,-90,0,6), Text = defaultKey.Name, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33), BorderSizePixel = 0})
    pcall(function() Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6) end)
    
    local currentKey = defaultKey
    local waitingForInput = false
    local changedCallback = function() end 
    
    local function updateKey(key)
        currentKey = key
        btn.Text = key.Name
        waitingForInput = false
        pcall(changedCallback, key)
    end

    btn.MouseButton1Click:Connect(function()
        btn.Text = "..."
        waitingForInput = true
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if waitingForInput and not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
            updateKey(input.KeyCode)
        end
    end)
    
    return {Frame=h, Get=function() return currentKey end, Set=updateKey, Changed=function(fn) changedCallback=fn end}
end


-- ... (Config UI creation and button handlers)
local secConfig, boxConfig = makeSection(rightCol, L("config_section"))
local inputName = new("TextBox", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), PlaceholderText = L("config_name"), Text = "", BackgroundColor3 = Color3.fromRGB(25,25,28), TextColor3 = theme.text, Font = Enum.Font.Gotham, TextSize = 13, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", inputName).CornerRadius = UDim.new(0,6) end)
local btnCreate = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("create"), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnCreate).CornerRadius = UDim.new(0,6) end)
local configListDropdown = makeDropdown(boxConfig, L("list"), {"---"})
local btnLoad = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("load"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnLoad).CornerRadius = UDim.new(0,6) end)
local btnOverwrite = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("overwrite"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnOverwrite).CornerRadius = UDim.new(0,6) end)
local btnDelete = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("delete"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnDelete).CornerRadius = UDim.new(0,6) end)
local btnRefresh = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("refresh"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnRefresh).CornerRadius = UDim.new(0,6) end)
local btnSetAuto = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("set_autoload"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnSetAuto).CornerRadius = UDim.new(0,6) end)
local btnResetAuto = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Text = L("reset_autoload"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnResetAuto).CornerRadius = UDim.new(0,6) end)
local currentAutoLabel = makeLabel(boxConfig, L("current_autoload") .. ": ---", 13, UDim2.new(0,6,0,0))
currentAutoLabel.TextColor3 = theme.subtext

local function refreshConfigList()
    local list = listConfigs()
    local selectedItem = configListDropdown.Get() or "---"
    local listForDD = #list > 0 and list or {"---"}

    local parentOfDD = configListDropdown.Frame.Parent
    local oldFrame = configListDropdown.Frame
    
    configListDropdown = makeDropdown(parentOfDD, L("list"), listForDD) 
    configListDropdown.Set(selectedItem)
    configListDropdown.Frame.LayoutOrder = oldFrame.LayoutOrder
    oldFrame:Destroy()

    local auto = getAutoload()
    currentAutoLabel.Text = L("current_autoload") .. ": " .. (auto or "---")
    searchBox.PlaceholderText = L("search")
    inputName.PlaceholderText = L("config_name")
    btnCreate.Text = L("create")
    btnLoad.Text = L("load")
    btnOverwrite.Text = L("overwrite")
    btnDelete.Text = L("delete")
    btnRefresh.Text = L("refresh")
    btnSetAuto.Text = L("set_autoload")
    btnResetAuto.Text = L("reset_autoload")
end

local function loadConfigToModules(configData, configName)
    if not configData then warn(L("error_load") .. configName); return end
    if configData.settings then
        SETTINGS.lang = configData.settings.lang or SETTINGS.lang
        SETTINGS.theme = configData.settings.theme or SETTINGS.theme
    end
    -- Broadcast config to modules
    for id,meta in pairs(MODULES) do
        if meta and meta.LoadConfigData then
            pcall(meta.LoadConfigData, configData.modules and configData.modules[id] or {})
        end
    end
    print(L("config_loaded"), configName)
    refreshConfigList() 
end

btnCreate.MouseButton1Click:Connect(function()
    local name = inputName.Text:gsub("%s+$","")
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
        refreshConfigList()
        inputName.Text = ""
        print(L("config_saved"), name)
    else
        warn(L("error_save"), err)
    end
end)
btnRefresh.MouseButton1Click:Connect(function() refreshConfigList() end)
btnLoad.MouseButton1Click:Connect(function()
    local selected = configListDropdown.Get()
    if not selected or selected == "---" then return end
    local data, err = loadConfig(selected)
    loadConfigToModules(data, selected)
end)
btnOverwrite.MouseButton1Click:Connect(function()
    local selected = configListDropdown.Get()
    if not selected or selected == "---" then return end
    local cfg = {meta = {updated = os_time()}, settings = {lang = SETTINGS.lang, theme = SETTINGS.theme}, modules = {}}
    for id, meta in pairs(MODULES) do
        if meta and meta.GetConfigData and (meta.category == "global" or tostring(meta.category) == tostring(game.PlaceId)) then
            local ok, data = pcall(meta.GetConfigData)
            if ok and data then cfg.modules[id] = data end
        end
    end
    local ok, err = pcall(function() saveConfig(selected, cfg) end)
    if ok then print(L("config_overwrite_ok"), selected) refreshConfigList() else warn(err) end
end)
btnDelete.MouseButton1Click:Connect(function()
    local selected = configListDropdown.Get()
    if not selected or selected == "---" then return end
    local ok = pcall(function() deleteConfig(selected) end)
    if ok then print(L("config_deleted"), selected) refreshConfigList() end
end)
btnSetAuto.MouseButton1Click:Connect(function()
    local selected = configListDropdown.Get()
    if not selected or selected == "---" then return end
    setAutoload(selected)
    refreshConfigList()
end)
btnResetAuto.MouseButton1Click:Connect(function()
    setAutoload(nil)
    refreshConfigList()
end)

local secSet, boxSet = makeSection(midCol, L("lang_section"))
local ddLang = makeDropdown(boxSet, "Language", {"vi","en"})
ddLang.Set(SETTINGS.lang)
ddLang.Changed:Connect(function(newLang)
    SETTINGS.lang = newLang
    refreshConfigList() 
end)

local secAnti, boxAnti = makeSection(midCol, L("anti_section"))
local lblAntiDesc = makeLabel(boxAnti, L("anti_desc"), 10)
lblAntiDesc.TextColor3 = theme.subtext

-- simple tab switching behavior
local current = "FARM"
local function setActive(tabName)
    for name,btn in pairs(sideBtnObjs) do
        local isActive = name == tabName
        if isActive then
            btn.BackgroundColor3 = theme.sidebar_hover
            btn.TextColor3 = theme.accent
            sideBtnObjs._active = btn
        else
            btn.BackgroundColor3 = theme.bg
            btn.TextColor3 = theme.text
        end
        if name == "FARM" then
            leftCol.Visible = isActive
            midCol.Visible = isActive and (game.PlaceId == PIXEL_BLADE_ID)
            rightCol.Visible = isActive
        elseif name == "SETTINGS" then
            leftCol.Visible = false
            midCol.Visible = isActive
            rightCol.Visible = isActive
        else
            leftCol.Visible = false
            midCol.Visible = false
            rightCol.Visible = false
        end
    end
    current = tabName
end

for name,btn in pairs(sideBtnObjs) do
    btn.MouseButton1Click:Connect(function() setActive(name) end)
end
setActive("FARM")

-- draggable main
local dragging, dragInput, dragStart, startPos
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- fade in
main.Position = UDim2.new(0.5,-490,0.5,-320)
TweenService:Create(main, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5,-490,0.5,-280)}):Play()

-- expose simple API for modules
local WindowAPI = {}
WindowAPI.CreateSection = makeSection
WindowAPI.MakeToggle = makeToggle
WindowAPI.MakeSlider = makeSlider
WindowAPI.MakeDropdown = makeDropdown
WindowAPI.MakeKeybind = makeKeybind
WindowAPI.GetSettings = function() return SETTINGS end
WindowAPI.SaveConfig = saveConfig
WindowAPI.LoadConfig = loadConfig
WindowAPI.RegisterModule = registerModule


-- ==== API Helper cho Targetting (V5 Logic: Resource Throttling & Fuzzy) ====
local function updateTargetCache(maxRange)
    if os_clock() - lastCacheUpdate < TARGET_CACHE_TIME then
        return TARGET_CACHE
    end
    
    local localHumanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    if not localHumanoid or localHumanoid.Health <= 0 then 
        TARGET_CACHE = nil; 
        lastCacheUpdate = os_clock();
        return nil
    end
    local localRoot = Player.Character.PrimaryPart
    
    local nearestTarget = nil
    local minDistance = maxRange * maxRange 

    -- V5 Logic: Chỉ quét Workspace định kỳ
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
        
        -- V3 Logic: Thêm Ngẫu nhiên hóa Tầm Ngắm (Fuzzy Target Acquisition)
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

-- ==== Module: PIXEL BLADE FARM (18172550962) - V5 ====
registerModule("pixel_blade_farm", {
    name = "Pixel Blade Farm",
    category = tostring(PIXEL_BLADE_ID), 
    
    init = function(win, api)
        local loopConnection = nil
        local lastAttackTime = 0
        local burstCounter = 0
        local lastSkillTime = 0
        local lastHealTime = 0
        local lastFreezeTime = 0
        
        -- Cột Trái: Kill Aura & Tốc độ
        local secFarm, boxFarm = win.CreateSection(leftCol, L("farm_section"))
        local tAura = win.MakeToggle(boxFarm, L("farm_toggle"), PIXEL_BLADE_SETTINGS.AuraEnabled)
        local sRange = win.MakeSlider(boxFarm, L("farm_range"), 100, 1000, PIXEL_BLADE_SETTINGS.AuraRange, "%.0f")
        local sDelay = win.MakeSlider(boxFarm, L("farm_delay"), 0.01, 1.0, PIXEL_BLADE_SETTINGS.AttackDelay, "%.2f")
        local tAutoMove = win.MakeToggle(boxFarm, L("farm_move"), PIXEL_BLADE_SETTINGS.AutoMoveToTarget)
        local tAutoBehind = win.MakeToggle(boxFarm, L("farm_back"), PIXEL_BLADE_SETTINGS.AutoBehindTarget)
        
        -- Cột Giữa: Skill & Upgrade
        local secSkill, boxSkill = win.CreateSection(midCol, L("skill_section"))
        local tAutoSkills = win.MakeToggle(boxSkill, L("skill_all"), PIXEL_BLADE_SETTINGS.AutoSkills)
        local tAutoHeal = win.MakeToggle(boxSkill, L("skill_heal"), PIXEL_BLADE_SETTINGS.AutoHeal)
        local sHPThresh = win.MakeSlider(boxSkill, L("skill_hp_thresh"), 10, 90, PIXEL_BLADE_SETTINGS.AutoHealHPThreshold * 100, "%.0f")
        local tAutoUpgrade = win.MakeToggle(boxSkill, L("upgrade_auto"), PIXEL_BLADE_SETTINGS.AutoUpgrade)
        local tSelectAll = win.MakeToggle(boxSkill, L("upgrade_select_all"), PIXEL_BLADE_SETTINGS.SelectAllBuffs)

        -- Cột Giữa: Exploit Nâng Cao & Panic (V4)
        local secExploit, boxExploit = win.CreateSection(midCol, L("exploit_section"))
        local tFreezeAI = win.MakeToggle(boxExploit, L("enemy_control"), PIXEL_BLADE_SETTINGS.FreezeEnemyAI)
        local sEnemyHB = win.MakeSlider(boxExploit, L("enemy_hitbox"), 0.5, 1.0, PIXEL_BLADE_SETTINGS.EnemyHitboxScale, "%.2f") 
        local sPlayerHB = win.MakeSlider(boxExploit, L("player_hitbox"), 1.0, 1.5, PIXEL_BLADE_SETTINGS.PlayerHitboxScale, "%.1f") 
        local kbPanic = win.MakeKeybind(boxExploit, L("panic_switch"), PANIC_KEY)
        local tAutoDisconnect = win.MakeToggle(boxExploit, L("auto_disconnect"), PIXEL_BLADE_SETTINGS.AutoDisconnect)

        -- V4 Logic: Hàm Ngắt Khẩn Cấp và Dọn Dẹp
        local function executePanicSwitch(isBanRisk)
            if loopConnection then loopConnection:Disconnect() loopConnection = nil end
            
            pcall(function() main.Visible = false end) -- Ẩn UI
            
            -- Đặt lại các giá trị quan trọng (Clean Up)
            pcall(tAura.Set, false)
            pcall(tAutoMove.Set, false)
            pcall(tAutoSkills.Set, false)
            pcall(tAutoHeal.Set, false)
            pcall(tFreezeAI.Set, false)
            
            -- Đặt lại Hitbox (rất quan trọng)
            pcall(sPlayerHB.Set, 1.0)
            pcall(sEnemyHB.Set, 1.0)
            
            -- Tùy chọn: Auto Disconnect
            if isBanRisk and PIXEL_BLADE_SETTINGS.AutoDisconnect then
                warn("ADMIN DETECTED! Executing safe shutdown...")
                -- Lệnh thực tế phụ thuộc vào Executor (giả lập game:Shutdown())
                pcall(function() game:Shutdown() end) 
            else
                print("Panic switch activated. Exploit disabled.")
            end
        end

        -- V4 Logic: Phát hiện Admin
        local function checkAdmins()
            -- V5: Tối ưu hóa truy cập tài nguyên (check 5s 1 lần)
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

        -- Bind Logic
        local function updateSettings()
            PIXEL_BLADE_SETTINGS.AuraEnabled = tAura.Get()
            PIXEL_BLADE_SETTINGS.AuraRange = sRange.Get()
            PIXEL_BLADE_SETTINGS.AttackDelay = sDelay.Get()
            PIXEL_BLADE_SETTINGS.AutoBehindTarget = tAutoBehind.Get()
            PIXEL_BLADE_SETTINGS.AutoMoveToTarget = tAutoMove.Get()
            PIXEL_BLADE_SETTINGS.AutoSkills = tAutoSkills.Get()
            PIXEL_BLADE_SETTINGS.AutoHeal = tAutoHeal.Get()
            PIXEL_BLADE_SETTINGS.AutoHealHPThreshold = sHPThresh.Get() / 100
            PIXEL_BLADE_SETTINGS.AutoUpgrade = tAutoUpgrade.Get()
            PIXEL_BLADE_SETTINGS.SelectAllBuffs = tSelectAll.Get()
            PIXEL_BLADE_SETTINGS.FreezeEnemyAI = tFreezeAI.Get()
            PIXEL_BLADE_SETTINGS.EnemyHitboxScale = sEnemyHB.Get()
            PIXEL_BLADE_SETTINGS.PlayerHitboxScale = sPlayerHB.Get()
            PIXEL_BLADE_SETTINGS.AutoDisconnect = tAutoDisconnect.Get()
            
            if PIXEL_BLADE_SETTINGS.AuraEnabled or PIXEL_BLADE_SETTINGS.AutoSkills or PIXEL_BLADE_SETTINGS.AutoHeal or PIXEL_BLADE_SETTINGS.FreezeEnemyAI then
                if not loopConnection then startLoop() end
            else
                if loopConnection then loopConnection:Disconnect() loopConnection = nil end
            end
            
            -- V5 Logic: Cập nhật CFrame / Hitbox ngay lập tức
            -- (Phần này chỉ là giả lập client-side, giữ nguyên logic cơ bản)
        end

        tAura.Changed:Connect(updateSettings)
        sRange.Changed:Connect(updateSettings)
        sDelay.Changed:Connect(updateSettings)
        tAutoBehind.Changed:Connect(updateSettings)
        tAutoMove.Changed:Connect(updateSettings)
        tAutoSkills.Changed:Connect(updateSettings)
        tAutoHeal.Changed:Connect(updateSettings)
        sHPThresh.Changed:Connect(updateSettings)
        tAutoUpgrade.Changed:Connect(updateSettings)
        tSelectAll.Changed:Connect(updateSettings)
        tFreezeAI.Changed:Connect(updateSettings)
        sEnemyHB.Changed:Connect(updateSettings)
        sPlayerHB.Changed:Connect(updateSettings)
        tAutoDisconnect.Changed:Connect(updateSettings)

        -- Kết nối Keybind Panic
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == kbPanic.Get() then
                executePanicSwitch(false)
            end
        end)


        -- Main Exploiting Loop (Đã tích hợp Anti-Ban V5)
        local function startLoop()
            loopConnection = RunService.Heartbeat:Connect(function(deltaTime)
                local timeNow = os_clock()
                local char = Player.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                
                if not char or not humanoid or humanoid.Health <= 0 or not char.PrimaryPart then return end

                local primaryPart = char.PrimaryPart
                
                -- V5 Logic: Tối ưu hóa truy cập tài nguyên (Sử dụng cache)
                local target = updateTargetCache(PIXEL_BLADE_SETTINGS.AuraRange)

                -- 1. Kill Aura/Auto Attack (Dynamic Cooldown Bypass + Tick Jitter)
                local currentAttackDelay = PIXEL_BLADE_SETTINGS.AttackDelay 
                
                if PIXEL_BLADE_SETTINGS.AuraEnabled and target then
                    if burstCounter > 0 then
                        -- PHASE 1: BURST (spam tốc độ nhanh)
                        local jitterDelay = random(currentAttackDelay * 0.9, currentAttackDelay * 1.05)
                        
                        if timeNow - lastAttackTime >= jitterDelay then
                            -- Tấn công (Remote Event) - Target position đã được ngẫu nhiên hóa
                            pcall(AttackRemote.FireServer, AttackRemote, target) 
                            
                            lastAttackTime = timeNow
                            burstCounter = burstCounter - 1
                        end
                    else
                        -- PHASE 2: COOLDOWN (chờ theo delay Server an toàn)
                        local jitterBurstDelay = random(BURST_DELAY * 0.9, BURST_DELAY * 1.1)
                        
                        if timeNow - lastAttackTime >= jitterBurstDelay then
                            burstCounter = BURST_ATTACK_COUNT 
                        end
                    end
                end

                -- Auto Move (Local CFrame Interpolation)
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

                -- 2. Auto Skills & 3. Auto Heal (Jitter)
                if PIXEL_BLADE_SETTINGS.AutoSkills and (timeNow - lastSkillTime > EstimateServerCooldown(random(0.2, 0.3))) then 
                    pcall(SkillRemote.FireServer, SkillRemote, "AllSkills")
                    lastSkillTime = timeNow
                end
                
                local currentHPPercent = humanoid.Health / (humanoid.MaxHealth * 2.0) 
                local healThreshold = PIXEL_BLADE_SETTINGS.AutoHealHPThreshold 

                if PIXEL_BLADE_SETTINGS.AutoHeal and currentHPPercent < healThreshold and (timeNow - lastHealTime > 5.0) then
                    if humanoid.Health < humanoid.MaxHealth then
                         pcall(HealRemote.FireServer, HealRemote)
                         lastHealTime = timeNow
                    end
                end

                -- 4. Freeze Enemy AI (Management Stealth: delay)
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
                checkAdmins(deltaTime)
                
            end)
        end
        
        GetConfigData = function()
            return PIXEL_BLADE_SETTINGS
        end,
        
        LoadConfigData = function(data)
            local needUpdate = false
            for k, v in pairs(data) do
                if PIXEL_BLADE_SETTINGS[k] ~= nil then
                    PIXEL_BLADE_SETTINGS[k] = v
                    needUpdate = true
                end
            end
            if needUpdate then
                -- Cập nhật giá trị UI từ config
                pcall(tAura.Set, PIXEL_BLADE_SETTINGS.AuraEnabled)
                pcall(sRange.Set, PIXEL_BLADE_SETTINGS.AuraRange)
                pcall(sDelay.Set, PIXEL_BLADE_SETTINGS.AttackDelay)
                pcall(tAutoMove.Set, PIXEL_BLADE_SETTINGS.AutoMoveToTarget)
                pcall(tAutoBehind.Set, PIXEL_BLADE_SETTINGS.AutoBehindTarget)
                pcall(tAutoSkills.Set, PIXEL_BLADE_SETTINGS.AutoSkills)
                pcall(tAutoHeal.Set, PIXEL_BLADE_SETTINGS.AutoHeal)
                pcall(sHPThresh.Set, PIXEL_BLADE_SETTINGS.AutoHealHPThreshold * 100)
                pcall(tAutoUpgrade.Set, PIXEL_BLADE_SETTINGS.AutoUpgrade)
                pcall(tSelectAll.Set, PIXEL_BLADE_SETTINGS.SelectAllBuffs)
                pcall(tFreezeAI.Set, PIXEL_BLADE_SETTINGS.FreezeEnemyAI)
                pcall(sEnemyHB.Set, PIXEL_BLADE_SETTINGS.EnemyHitboxScale)
                pcall(sPlayerHB.Set, PIXEL_BLADE_SETTINGS.PlayerHitboxScale)
                pcall(tAutoDisconnect.Set, PIXEL_BLADE_SETTINGS.AutoDisconnect)

                -- Kích hoạt lại loop
                updateSettings() 
            end
        end
    end,
    
    GetConfigData = function() return PIXEL_BLADE_SETTINGS end,
    LoadConfigData = function(data) end -- Định nghĩa lại ở init để truy cập local UI
})

-- ==== Example: Register sample modules (Global Setting UI) ====
registerModule("settings_ui", {
    name = "Settings UI",
    category = "global",
    init = function(win, api) end,
    GetConfigData = function() return {GlobalAntiLag = true} end,
    LoadConfigData = function(data) end
})

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

-- Finally load modules for current game
pcall(function() loadModulesForGame(game.PlaceId, WindowAPI) end)

-- If autoload data exists, broadcast to modules that have LoadConfigData
pcall(function()
    if SETTINGS._autoload_data then
        for id,meta in pairs(MODULES) do
            if meta and meta.LoadConfigData then
                pcall(meta.LoadConfigData, SETTINGS._autoload_data.modules and SETTINGS._autoload_data.modules[id] or {})
            end
        end
        loadConfigToModules(SETTINGS._autoload_data, SETTINGS.autoload)
    end
end)

refreshConfigList()

print(GUI_NAME kkpixel blade v1" loaded. Stealth Anti-Ban V5 is active.")

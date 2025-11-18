-- Single-file HUB: UI-LIB + Config System + Localization + Loader + Module structure
-- Author: kkirru-style (ChatGPT)
-- Usage: paste into executor and run. No external HttpGet, no cheating logic.
-- Features included:
--  - Sidebar + header + 3-column content layout (UI-LIB style)
--  - Module registration system (per-game or global)
--  - Config save/load/list/delete/overwrite/autoload (uses writefile/readfile if available)
--  - Localization (English + Vietnamese example), switchable
--  - Simple API for modules to add controls
--  - Autoload config on start if set
--  - All in one file

-- ==== Services & helpers ====
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- environment safe wrappers for executor APIs
local isfile = isfile or function() return false end
local readfile = readfile or function() error("readfile not available") end
local writefile = writefile or function() error("writefile not available") end
local delfile = delfile or function() error("delfile not available") end
local makefolder = makefolder or function() end

-- constants
local GUI_NAME = "KK_Hub_OneFile_v1"
local CONFIG_FOLDER = "KKHub_Configs"
local AUTLOAD_FILE = CONFIG_FOLDER .. "/__autoload"
local DEFAULT_CONFIG_EXT = ".json"

-- default localization
local LANGS = {
    en = {
        title = "KK Hub",
        search = "Search",
        config_section = "Configuration",
        config_name = "Config name",
        create = "Create config",
        list = "Config list",
        load = "Load config",
        overwrite = "Overwrite config",
        delete = "Delete config",
        refresh = "Refresh list",
        set_autoload = "Set as autoload",
        reset_autoload = "Reset autoload",
        current_autoload = "Current autoload config",
        save = "Save",
        yes = "Yes",
        no = "No"
    },
    vi = {
        title = "KK Hub",
        search = "Tìm",
        config_section = "Cấu hình",
        config_name = "Tên config",
        create = "Tạo config",
        list = "Danh sách",
        load = "Tải",
        overwrite = "Ghi đè",
        delete = "Xóa",
        refresh = "Làm mới",
        set_autoload = "Đặt autoload",
        reset_autoload = "Hủy autoload",
        current_autoload = "Autoload hiện tại",
        save = "Lưu",
        yes = "Có",
        no = "Không"
    }
}

-- default settings (in-memory)
local SETTINGS = {
    lang = "vi", -- default language
    theme = "red", -- placeholder
    autoload = nil
}

-- config utilities
local function ensureConfigFolder()
    -- try create folder if executor supports
    pcall(function() makefolder(CONFIG_FOLDER) end)
end

local function listConfigs()
    ensureConfigFolder()
    local out = {}
    -- try to iterate by reading autoload file and listing known files
    -- many executors don't provide listdir; so we'll attempt to read a manifest file
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

local function removeConfigFromManifest(name)
    local m = listConfigs()
    local nm = {}
    for _,v in ipairs(m) do if v ~= name then table.insert(nm, v) end end
    saveManifest(nm)
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
    if not isfile(path) then return nil, "not found" end
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
        if ok then
            SETTINGS.autoload = raw
            return raw
        end
    end
    return nil
end

-- localization getter
local function L(k)
    local lang = LANGS[SETTINGS.lang] and SETTINGS.lang or "en"
    local dict = LANGS[lang] or LANGS["en"]
    return dict[k] or k
end

-- Module system
local MODULES = {} -- { id = {name=..., init=function(win,api) end, category="global" / gameid } }

local function registerModule(id, meta)
    -- meta: {name, category, init = function(window, moduleAPI) end}
    MODULES[id] = meta
end

local function loadModulesForGame(gameId, windowAPI)
    for id, meta in pairs(MODULES) do
        if meta then
            if meta.category == "global" or tostring(meta.category) == tostring(gameId) then
                pcall(meta.init, windowAPI, {
                    SaveConfig = function(name, tbl) return saveConfig(name, tbl) end,
                    LoadConfig = function(name) return loadConfig(name) end,
                    GetSetting = function(k) return SETTINGS[k] end,
                    SetSetting = function(k,v) SETTINGS[k]=v end
                })
            end
        end
    end
end

-- ==== BUILD UI ====
-- clear if exists
if CoreGui:FindFirstChild(GUI_NAME) then
    CoreGui[GUI_NAME]:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = GUI_NAME
screen.ResetOnSpawn = false
screen.Parent = CoreGui

-- theme
local theme = {
    bg = Color3.fromRGB(14,14,17),
    panel = Color3.fromRGB(20,20,23),
    accent = Color3.fromRGB(207,48,74),
    text = Color3.fromRGB(230,230,230),
    subtext = Color3.fromRGB(160,160,160),
    toggled = Color3.fromRGB(207,48,74)
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

-- main window
local main = new("Frame", {
    Parent = screen,
    Size = UDim2.new(0, 980, 0, 560),
    Position = UDim2.new(0.5, -490, 0.5, -280),
    BackgroundColor3 = theme.bg,
    BorderSizePixel = 0
})
pcall(function() local c = Instance.new("UICorner", main); c.CornerRadius = UDim.new(0,12) end)
main.AnchorPoint = Vector2.new(0.5,0.5)

-- left sidebar
local sidebar = new("Frame", {Parent = main, Size = UDim2.new(0,160,1,0), Position = UDim2.new(0,0,0,0), BackgroundColor3 = theme.bg, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0,12) end)
local logo = new("TextLabel", {Parent = sidebar, Text = "Chiyo", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = theme.accent, BackgroundTransparency = 1, Position = UDim2.new(0,12,0,10)})

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
    b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(23,23,26) end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = theme.bg end)
    sideBtnObjs[v] = b
end

-- header
local header = new("Frame", {Parent = main, Size = UDim2.new(1,-160,0,44), Position = UDim2.new(0,160,0,0), BackgroundColor3 = theme.bg, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", header).CornerRadius = UDim.new(0,8) end)
local searchBox = new("TextBox", {Parent = header, PlaceholderText = L("search"), Size = UDim2.new(0,260,0,28), Position = UDim2.new(0,16,0,8), BackgroundColor3 = Color3.fromRGB(30,30,33), TextColor3 = theme.text, Font = Enum.Font.Gotham, TextSize = 13, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0,6) end)
local statusLabel = new("TextLabel", {Parent = header, Text = "Pixel Blade - v1.8", TextSize = 12, Font = Enum.Font.Code, TextColor3 = theme.subtext, BackgroundTransparency = 1, Position = UDim2.new(1,-10,0,12)})
statusLabel.AnchorPoint = Vector2.new(1,0)

-- content area
local content = new("Frame", {Parent = main, Position = UDim2.new(0,160,0,44), Size = UDim2.new(1,-160,1,-44), BackgroundTransparency = 1})
local leftCol = new("Frame", {Parent = content, Position = UDim2.new(0,8,0,8), Size = UDim2.new(0,0.44,-16,0), BackgroundColor3 = theme.panel, BorderSizePixel = 0})
local midCol = new("Frame", {Parent = content, Position = UDim2.new(0.44,16,0,8), Size = UDim2.new(0,0.28,-8,0), BackgroundColor3 = theme.panel, BorderSizePixel = 0})
local rightCol = new("Frame", {Parent = content, Position = UDim2.new(0.72,24,0,8), Size = UDim2.new(0,0.28,-16,0), BackgroundColor3 = theme.panel, BorderSizePixel = 0})

for _,c in pairs({leftCol, midCol, rightCol}) do
    pcall(function() Instance.new("UICorner", c).CornerRadius = UDim.new(0,8) end)
    Instance.new("UIPadding", c).PaddingTop = UDim.new(0,8)
end

-- small helpers for controls
local function makeLabel(parent, text, size, pos)
    local t = new("TextLabel", {Parent = parent, Text = text or "", Font = Enum.Font.Gotham, TextSize = size or 14, TextColor3 = theme.text, BackgroundTransparency = 1, Position = pos or UDim2.new(0,0,0,0)})
    return t
end

local function makeSection(parent, title)
    local sec = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,140), BackgroundTransparency = 1})
    local head = makeLabel(sec, title, 15, UDim2.new(0,6,0,0))
    head.TextColor3 = theme.accent
    local box = new("Frame", {Parent = sec, Position = UDim2.new(0,0,0,24), Size = UDim2.new(1,0,1,-24), BackgroundColor3 = Color3.fromRGB(17,17,20)})
    pcall(function() Instance.new("UICorner", box).CornerRadius = UDim.new(0,6) end)
    return sec, box
end

-- controls: toggle / slider / dropdown / keybind
local function makeToggle(parent, labelText, default)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,34), BackgroundTransparency = 1})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,6))
    label.TextColor3 = theme.text
    local toggle = new("Frame", {Parent = h, Size = UDim2.new(0,44,0,22), Position = UDim2.new(1,-56,0,6), BackgroundColor3 = Color3.fromRGB(90,90,90)})
    pcall(function() Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,20) end)
    local circle = new("Frame", {Parent = toggle, Size = UDim2.new(0,18,0,18), Position = UDim2.new(0,5,0.5,-9), AnchorPoint = Vector2.new(0,0.5), BackgroundColor3 = Color3.fromRGB(240,240,240)})
    pcall(function() Instance.new("UICorner", circle).CornerRadius = UDim.new(0,20) end)
    local state = default and true or false
    local function refresh()
        if state then
            circle.Position = UDim2.new(1,-11,0.5,-9)
            toggle.BackgroundColor3 = theme.toggled
        else
            circle.Position = UDim2.new(0,5,0.5,-9)
            toggle.BackgroundColor3 = Color3.fromRGB(90,90,90)
        end
    end
    toggle.InputBegan:Connect(function()
        state = not state
        refresh()
    end)
    refresh()
    return {Frame=h, Get=function() return state end, Set=function(v) state=v; refresh() end}
end

local function makeSlider(parent, labelText, min, max, default)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,56), BackgroundTransparency = 1})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,4))
    label.TextColor3 = theme.text
    local valueLabel = makeLabel(h, tostring(default), 13, UDim2.new(1,-40,0,4))
    valueLabel.TextColor3 = theme.subtext
    local track = new("Frame", {Parent = h, Position = UDim2.new(0,4,0,28), Size = UDim2.new(1,-8,0,12), BackgroundColor3 = Color3.fromRGB(35,35,38)})
    pcall(function() Instance.new("UICorner", track).CornerRadius = UDim.new(0,6) end)
    local fill = new("Frame", {Parent = track, Size = UDim2.new((default-min)/(max-min),0,1,0), BackgroundColor3 = theme.accent})
    pcall(function() Instance.new("UICorner", fill).CornerRadius = UDim.new(0,6) end)
    local dragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local abs = math.clamp((input.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(abs,0,1,0)
            local val = min + (max-min)*abs
            valueLabel.Text = string.format("%.2f", val)
        end
    end)
    return {Frame=h, Get=function() return min + (max-min)*fill.Size.X.Scale end}
end

local function makeDropdown(parent, labelText, items)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,44), BackgroundTransparency = 1})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,6))
    label.TextColor3 = theme.text
    local btn = new("TextButton", {Parent = h, Size = UDim2.new(0,160,0,28), Position = UDim2.new(1,-176,0,6), Text = items[1] or "Select", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33), BorderSizePixel = 0})
    pcall(function() Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6) end)
    local menu = new("Frame", {Parent = h, Size = UDim2.new(0,160,0,#items*30), Position = UDim2.new(1,-176,0,38), BackgroundColor3 = Color3.fromRGB(25,25,28), Visible = false})
    pcall(function() Instance.new("UICorner", menu).CornerRadius = UDim.new(0,6) end)
    for i,it in ipairs(items) do
        local itemBtn = new("TextButton", {Parent = menu, Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0,(i-1)*30), Text = it, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundTransparency = 1, BorderSizePixel = 0})
        itemBtn.MouseButton1Click:Connect(function()
            btn.Text = it
            menu.Visible = false
        end)
    end
    btn.MouseButton1Click:Connect(function() menu.Visible = not menu.Visible end)
    return {Frame=h, Get=function() return btn.Text end}
end

local function makeKeybind(parent, labelText, defaultKey)
    local h = new("Frame", {Parent = parent, Size = UDim2.new(1,0,0,34), BackgroundTransparency = 1})
    local label = makeLabel(h, labelText, 14, UDim2.new(0,4,0,6))
    label.TextColor3 = theme.text
    local box = new("TextButton", {Parent = h, Size = UDim2.new(0,140,0,24), Position = UDim2.new(1,-156,0,4), Text = defaultKey or "RightShift", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33), BorderSizePixel = 0})
    pcall(function() Instance.new("UICorner", box).CornerRadius = UDim.new(0,6) end)
    box.MouseButton1Click:Connect(function()
        box.Text = "Press a key..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                box.Text = inp.KeyCode.Name
                conn:Disconnect()
            end
        end)
    end)
    return {Frame=h, Get=function() return box.Text end}
end

-- create config UI on rightCol
local secConfig, boxConfig = makeSection(rightCol, L("config_section"))

local inputName = new("TextBox", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,8), PlaceholderText = L("config_name"), Text = "", BackgroundColor3 = Color3.fromRGB(25,25,28), TextColor3 = theme.text, Font = Enum.Font.Gotham, TextSize = 13, BorderSizePixel = 0})
pcall(function() Instance.new("UICorner", inputName).CornerRadius = UDim.new(0,6) end)

local btnCreate = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,44), Text = L("create"), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnCreate).CornerRadius = UDim.new(0,6) end)

local configListDropdown = makeDropdown(boxConfig, L("list"), {"---"})
configListDropdown.Frame.Position = UDim2.new(0,6,0,84)
configListDropdown.Frame.Size = UDim2.new(1,-12,0,44)

local btnLoad = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,136), Text = L("load"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnLoad).CornerRadius = UDim.new(0,6) end)
local btnOverwrite = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,176), Text = L("overwrite"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnOverwrite).CornerRadius = UDim.new(0,6) end)
local btnDelete = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,216), Text = L("delete"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnDelete).CornerRadius = UDim.new(0,6) end)
local btnRefresh = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,256), Text = L("refresh"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnRefresh).CornerRadius = UDim.new(0,6) end)

local btnSetAuto = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,296), Text = L("set_autoload"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnSetAuto).CornerRadius = UDim.new(0,6) end)
local btnResetAuto = new("TextButton", {Parent = boxConfig, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,336), Text = L("reset_autoload"), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.text, BackgroundColor3 = Color3.fromRGB(30,30,33)})
pcall(function() Instance.new("UICorner", btnResetAuto).CornerRadius = UDim.new(0,6) end)

local currentAutoLabel = makeLabel(boxConfig, L("current_autoload") .. ": ---", 13, UDim2.new(0,6,0,376))
currentAutoLabel.TextColor3 = theme.subtext

-- Helper to refresh config dropdown
local function refreshConfigList()
    local list = listConfigs()
    if #list == 0 then list = {"---"} end
    -- replace dropdown items
    local parentFrame = configListDropdown.Frame
    -- clear old menu if exists
    for _,ch in ipairs(parentFrame:GetChildren()) do
        if ch:IsA("Frame") and ch ~= parentFrame then ch:Destroy() end
    end
    -- reset button text
    for _,obj in ipairs(parentFrame:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Parent == parentFrame and obj.Position.Y.Offset == 0 then
            -- that's original; skip
        end
    end
    -- Instead of re-creating whole dropdown (complex), just set the button text to first or selected
    if list[1] then
        -- update internal items by creating a new menu under parentFrame
        local menu = Instance.new("Frame", parentFrame)
        menu.Size = UDim2.new(0,160,0,#list*30)
        menu.Position = UDim2.new(1,-176,0,38)
        menu.BackgroundColor3 = Color3.fromRGB(25,25,28)
        menu.Visible = false
        pcall(function() Instance.new("UICorner", menu).CornerRadius = UDim.new(0,6) end)
        for i,item in ipairs(list) do
            local itemBtn = Instance.new("TextButton", menu)
            itemBtn.Size = UDim2.new(1,0,0,30)
            itemBtn.Position = UDim2.new(0,0,0,(i-1)*30)
            itemBtn.BackgroundTransparency = 1
            itemBtn.Font = Enum.Font.Gotham
            itemBtn.TextSize = 13
            itemBtn.TextColor3 = theme.text
            itemBtn.Text = item
            itemBtn.MouseButton1Click:Connect(function()
                -- set text on main button
                for _,child in ipairs(parentFrame:GetChildren()) do
                    if child:IsA("TextButton") and child.Position.Y.Offset == 0 then
                        child.Text = item
                    end
                end
                menu.Visible = false
            end)
        end
        -- find the visible button (we created earlier) and hook it
        for _,child in ipairs(parentFrame:GetChildren()) do
            if child:IsA("TextButton") and child.Position.Y.Offset == 0 then
                child.MouseButton1Click:Connect(function() menu.Visible = not menu.Visible end)
                child.Text = list[1] or "---"
            end
        end
    end
    -- update current autoload label
    local auto = getAutoload()
    currentAutoLabel.Text = L("current_autoload") .. ": " .. (auto or "---")
end

-- bind actions
btnCreate.MouseButton1Click:Connect(function()
    local name = inputName.Text:gsub("%s+$","")
    if name == "" or not name then return end
    -- collect current UI state into a config table: (example collects nothing real, modules can supply their own)
    local cfg = {
        meta = {created = os.time(), by = "user"},
        settings = {
            lang = SETTINGS.lang,
            theme = SETTINGS.theme
        },
        modules = {} -- empty, modules can fill in
    }
    local ok, err = pcall(function() saveConfig(name, cfg) end)
    if ok then
        refreshConfigList()
        inputName.Text = ""
        print("Saved config:", name)
    else
        warn("Failed to save config:", err)
    end
end)

btnRefresh.MouseButton1Click:Connect(function() refreshConfigList() end)

btnLoad.MouseButton1Click:Connect(function()
    local selected = nil
    -- find selected in dropdown
    for _,child in ipairs(configListDropdown.Frame:GetChildren()) do
        if child:IsA("TextButton") and child.Position.Y.Offset == 0 then
            selected = child.Text
        end
    end
    if not selected or selected == "---" then return end
    local ok, data = pcall(loadConfig, selected)
    if ok and data then
        -- broadcast loaded config to modules (modules decide what to do)
        for id,meta in pairs(MODULES) do
            if meta and meta.loadConfig then
                pcall(meta.loadConfig, data)
            end
        end
        print("Loaded config:", selected)
    else
        warn("Failed to load config:", data)
    end
end)

btnOverwrite.MouseButton1Click:Connect(function()
    local selected = nil
    for _,child in ipairs(configListDropdown.Frame:GetChildren()) do
        if child:IsA("TextButton") and child.Position.Y.Offset == 0 then selected = child.Text end
    end
    if not selected or selected == "---" then return end
    local cfg = {
        meta = {updated = os.time()},
        settings = {
            lang = SETTINGS.lang,
            theme = SETTINGS.theme
        },
        modules = {}
    }
    local ok, err = pcall(function() saveConfig(selected, cfg) end)
    if ok then print("Overwrote config:", selected) refreshConfigList() else warn(err) end
end)

btnDelete.MouseButton1Click:Connect(function()
    local selected = nil
    for _,child in ipairs(configListDropdown.Frame:GetChildren()) do
        if child:IsA("TextButton") and child.Position.Y.Offset == 0 then selected = child.Text end
    end
    if not selected or selected == "---" then return end
    local ok = pcall(function() deleteConfig(selected) end)
    if ok then print("Deleted:", selected) refreshConfigList() end
end)

btnSetAuto.MouseButton1Click:Connect(function()
    local selected = nil
    for _,child in ipairs(configListDropdown.Frame:GetChildren()) do
        if child:IsA("TextButton") and child.Position.Y.Offset == 0 then selected = child.Text end
    end
    if not selected or selected == "---" then return end
    setAutoload(selected)
    refreshConfigList()
end)

btnResetAuto.MouseButton1Click:Connect(function()
    setAutoload(nil)
    refreshConfigList()
end)

-- language switcher example in Settings tab (we'll create small section)
local secSet, boxSet = makeSection(midCol, "UI Options")
local ddLang = makeDropdown(boxSet, "Language", {"vi","en"})
ddLang.Frame.Position = UDim2.new(0,6,0,8)
ddLang.Frame.Size = UDim2.new(1,-12,0,44)
-- set handler
for _,ch in ipairs(ddLang.Frame:GetDescendants()) do
    if ch:IsA("TextButton") and ch.Position.Y.Offset ~= 0 then
        ch.MouseButton1Click:Connect(function()
            SETTINGS.lang = ch.Text
            -- update strings
            searchBox.PlaceholderText = L("search")
            inputName.PlaceholderText = L("config_name")
            btnCreate.Text = L("create")
            btnLoad.Text = L("load")
            btnOverwrite.Text = L("overwrite")
            btnDelete.Text = L("delete")
            btnRefresh.Text = L("refresh")
            btnSetAuto.Text = L("set_autoload")
            btnResetAuto.Text = L("reset_autoload")
            currentAutoLabel.Text = L("current_autoload") .. ": " .. (getAutoload() or "---")
        end)
    end
end

-- simple tab switching behavior
local current = "FARM"
local function setActive(tabName)
    for name,btn in pairs(sideBtnObjs) do
        if name == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(23,23,26)
            btn.TextColor3 = theme.accent
        else
            btn.BackgroundColor3 = theme.bg
            btn.TextColor3 = theme.text
        end
    end
    -- for simplicity we always show all columns (modules control content)
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

-- try autoload if exists
pcall(function()
    local auto = getAutoload()
    if auto and auto ~= "" then
        local ok, data = pcall(loadConfig, auto)
        if ok and data then
            -- broadcast to modules after we load modules (we will load modules next)
            print("Autoloaded config:", auto)
            -- store for later broadcast
            SETTINGS._autoload_data = data
        end
    end
end)

-- ==== Example: Register sample modules (these are placeholders modules that show how to extend) ====
-- Module example: Global "Settings" module that adds options in Settings tab
registerModule("settings_ui", {
    name = "Settings UI",
    category = "global",
    init = function(win, api)
        -- create a section under Settings tab (midCol used for example)
        local sec, box = win.CreateSection(midCol, "Settings")
        local tAutoClose = win.MakeToggle(box, "Auto Close UI on Start", false)
        local tShowHints = win.MakeToggle(box, "Show Hints", true)
        -- loadConfig handler
    end,
    loadConfig = function(cfg)
        -- if this module stores data in cfg.modules.settings_ui, it can read it here
        -- example: apply setting
    end
})

-- Module example: Game-specific sample
registerModule("sample_game", {
    name = "Sample Game Module",
    category = tostring(game.PlaceId), -- only load when in this game
    init = function(win, api)
        local sec, box = win.CreateSection(leftCol, "Game Controls")
        local t = win.MakeToggle(box, "Example Toggle", false)
        local s = win.MakeSlider(box, "Example Delay (s)", 0.05, 2, 0.3)
        -- modules can call api.SaveConfig or api.GetSetting etc.
    end
})

-- Finally load modules for current game
pcall(function() loadModulesForGame(game.PlaceId, WindowAPI) end)

-- If autoload data exists, broadcast to modules that have loadConfig
pcall(function()
    if SETTINGS._autoload_data then
        for id,meta in pairs(MODULES) do
            if meta and meta.loadConfig then
                pcall(meta.loadConfig, SETTINGS._autoload_data)
            end
        end
    end
end)

-- expose API globally for user to interact
_G.KK_Hub = {
    SaveConfig = saveConfig,
    LoadConfig = loadConfig,
    DeleteConfig = deleteConfig,
    ListConfigs = listConfigs,
    SetAutoload = setAutoload,
    GetAutoload = getAutoload,
    RegisterModule = registerModule,
    API_Window = WindowAPI
}

-- final refresh
refreshConfigList()

print("KK Hub loaded. Use _G.KK_Hub to interact programmatically.")

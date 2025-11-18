-- KKPixelBlade V6.0 (Single-file) - Ultimate Safe + Enhanced UI
-- Author: kkirru-style (Gemini) -> rewritten by ChatGPT (tớ)
-- Version: V6.0 (Rewritten: safer hooks, tighter throttles, cleaner UI)
-- Usage: paste into executor and run. Designed as a single-file HUB.

-- NOTE: Script wraps all sensitive calls in pcall and keeps state local.
-- Be mindful: using exploits may violate game rules. Use at your own risk.

local function safe_start_script()
    -- Services (cached locally inside function for safety)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local CoreGui = game:GetService("CoreGui")
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
        burstCharge = 0,
        lastBurstUse = 0,
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

    -- Safe remote fire/invoke
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

    -- Scan and hook remotes: conservative, non-destructive (wraps originals)
    local function tryHookRemote(remote)
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

    -- Target selection (throttled cache)
    local function updateTargetCache(maxRange)
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
        if not target or not target.PrimaryPart then return nil end
        local off = Vector3.new(rand(-4,4), rand(4,10), rand(-4,4))
        local pos = target.PrimaryPart.Position + off
        if SETTINGS.AutoBehindTarget and Player and Player.Character and Player.Character.PrimaryPart then
            local back = target.PrimaryPart.CFrame.LookVector * 4
            return pos - back
        end
        return pos
    end

    -- Admin detection -> panic
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
            if UI and UI.MainFrame then
                pcall(function() UI.MainFrame.Visible = false end)
            end
        end
    end

    local function checkAdmins()
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

    -- Gom quái: lightweight teleport of NPC models nearby
    local function gomQuai()
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
        if tick() - STATE.lastHitboxTime < SETTINGS.HitboxChangeInterval then return end
        STATE.lastHitboxTime = tick()
        pcall(function()
            if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = Player.Character.HumanoidRootPart
                hrp.Size = Vector3.new(2*scale, 2*scale, 1*scale)
            end
        end)
    end

    -- Movement limiter: move toward target limited by MoveSpeedLimit
    local function limitMoveSpeed(targetPos, currentPos, maxSpeed)
        local delta = targetPos - currentPos
        local dist = delta.Magnitude
        if dist == 0 or maxSpeed <= 0 then return currentPos end
        local dir = delta.Unit
        local move = min(maxSpeed, dist) * dir
        return currentPos + move
    end

    -- Main logic loop
    local function startLoop()
        if STATE.loopConnection then pcall(function() STATE.loopConnection:Disconnect() end) end

        STATE.burstCharge = SETTINGS.BurstCount
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

            -- ATTACK logic
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

            -- Auto move to target (throttled speed)
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

            -- Auto skills
            if SETTINGS.AutoSkills and STATE.SkillRemote and (now - lastSkill > EstimateServerCooldown(rand(0.2,0.35))) then
                pcall(function() safeFireRemote(STATE.SkillRemote, "AllSkills") end)
                lastSkill = now
            end

            -- Auto heal
            local currentHPPercent = hum.Health / max(1, hum.MaxHealth)
            if SETTINGS.AutoHeal and STATE.HealRemote and currentHPPercent < SETTINGS.AutoHealHPThreshold and (now - lastHeal > 5.0) then
                pcall(function() safeFireRemote(STATE.HealRemote) end)
                lastHeal = now
            end

            -- Freeze AI
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

            -- Hitbox apply
            applyHitboxScale(SETTINGS.PlayerHitboxScale)

            -- Gom quái
            if SETTINGS.GomQuaiEnabled then gomQuai() end

            -- Admin check (low frequency)
            checkAdmins()

            -- Update UI bars
            if UI and UI.Bars then
                pcall(function()
                    if UI.Bars.BurstBar then
                        local normalized = min(1, max(0, STATE.burstCharge / max(1, SETTINGS.BurstCount)))
                        UI.Bars.BurstBar.Size = UDim2.new(normalized, 0, 1, 0)
                        UI.Bars.BurstLabel.Text = "Burst: "..floor(STATE.burstCharge+0.5).."/"..tostring(SETTINGS.BurstCount)
                    end
                    if UI.Bars.HitboxBar then
                        local minScale, maxScale = 1.0, 1.5
                        local cl = min(maxScale, max(minScale, SETTINGS.PlayerHitboxScale))
                        local norm = (cl - minScale) / (maxScale - minScale)
                        UI.Bars.HitboxBar.Size = UDim2.new(norm, 0, 1, 0)
                        UI.Bars.HitboxLabel.Text = ("Hitbox: %.2fx"):format(SETTINGS.PlayerHitboxScale)
                    end
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

    -- ========== UI Builder ===========
    UI = {}
    local ACCENT = Color3.fromRGB(207,48,74)
    local BG = Color3.fromRGB(24,24,24)
    local FRAME = Color3.fromRGB(38,38,38)
    local TOGG_ON = Color3.fromRGB(48,207,74)
    local TOGG_OFF = ACCENT

    local function createToggle(name, key)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 36)
        frame.BackgroundColor3 = FRAME
        frame.Parent = Scroll

        local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,6) corner.Parent = frame
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.65,0,1,0)
        label.Text = name
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(220,220,220)
        label.BackgroundTransparency = 1
        label.TextSize = 15
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.35, -10, 0.7, 0)
        btn.Position = UDim2.new(0.65, 5, 0.15, 0)
        btn.Text = (SETTINGS[key] and "ON") or "OFF"
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.new(1,1,1)
        btn.BackgroundColor3 = (SETTINGS[key] and TOGG_ON) or TOGG_OFF
        btn.Parent = frame
        local cornerB = Instance.new("UICorner") cornerB.CornerRadius = UDim.new(0,4) cornerB.Parent = btn

        local function setVal(v)
            SETTINGS[key] = v
            btn.Text = v and "ON" or "OFF"
            btn.BackgroundColor3 = v and TOGG_ON or TOGG_OFF
            updateLoopStatus()
        end
        btn.MouseButton1Click:Connect(function() setVal(not SETTINGS[key]) end)
        return {Frame = frame, SetValue = setVal}
    end

    local function createSlider(name, key, minV, maxV, step, suffix)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -20, 0, 54)
        frame.BackgroundColor3 = FRAME
        frame.Parent = Scroll
        local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,6) corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,0,16)
        label.Position = UDim2.new(0,5,0,2)
        label.Text = name .. ": " .. tostring(SETTINGS[key]) .. (suffix or "")
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(220,220,220)
        label.TextSize = 12
        label.BackgroundTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -10, 0, 30)
        box.Position = UDim2.new(0,5,0,20)
        box.Text = tostring(SETTINGS[key])
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.TextColor3 = Color3.fromRGB(20,20,20)
        box.BackgroundColor3 = Color3.fromRGB(200,200,200)
        box.Parent = frame
        local cornerS = Instance.new("UICorner") cornerS.CornerRadius = UDim.new(0,4) cornerS.Parent = box

        box.FocusLost:Connect(function()
            local v = tonumber(box.Text)
            if v then
                v = max(minV, min(maxV, v))
                if step and step > 0 then v = floor(v/step + 0.5) * step end
                SETTINGS[key] = v
                box.Text = tostring(v)
                label.Text = name .. ": " .. tostring(v) .. (suffix or "")
                updateLoopStatus()
            else
                box.Text = tostring(SETTINGS[key])
            end
        end)

        return {Frame = frame, SetValue = function(val)
            SETTINGS[key] = val
            box.Text = tostring(val)
            label.Text = name .. ": " .. tostring(val) .. (suffix or "")
            updateLoopStatus()
        end}
    end

    local function createHeader(text)
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -20, 0, 26)
        header.Text = text
        header.Font = Enum.Font.SourceSansBold
        header.TextColor3 = Color3.new(1,1,1)
        header.BackgroundColor3 = Color3.fromRGB(50,50,50)
        header.TextSize = 16
        header.Parent = Scroll
        local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,6) corner.Parent = header
        return header
    end

    -- Build UI
    local function createUI()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "KKPixelBlade_V6_UI"
        -- try PlayerGui then CoreGui
        local ok
        ok = pcall(function() ScreenGui.Parent = Player:WaitForChild("PlayerGui") end)
        if not ok then ScreenGui.Parent = CoreGui end

        local Main = Instance.new("Frame")
        Main.Size = UDim2.new(0,360,0,520)
        Main.Position = UDim2.new(0.5, -180, 0.5, -260)
        Main.BackgroundColor3 = FRAME
        Main.BorderSizePixel = 0
        Main.ClipsDescendants = true
        Main.Parent = ScreenGui
        UI.MainFrame = Main

        local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,10) corner.Parent = Main

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1,0,0,36)
        Title.Text = "KKPIXEL BLADE V6.0 (Safe)"
        Title.Font = Enum.Font.SourceSansBold
        Title.TextSize = 18
        Title.TextColor3 = Color3.new(1,1,1)
        Title.BackgroundColor3 = ACCENT
        Title.Parent = Main
        local g = Instance.new("UIGradient") g.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,ACCENT), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,120,160))} g.Parent = Title

        Scroll = Instance.new("ScrollingFrame")
        Scroll.Size = UDim2.new(1,0,1,-36)
        Scroll.Position = UDim2.new(0,0,0,36)
        Scroll.BackgroundColor3 = BG
        Scroll.BorderSizePixel = 0
        Scroll.CanvasSize = UDim2.new(0,0,0,1100)
        Scroll.Parent = Main
        local layout = Instance.new("UIListLayout") layout.FillDirection = Enum.FillDirection.Vertical layout.Padding = UDim.new(0,8) layout.Parent = Scroll
        local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0,10); pad.PaddingLeft=UDim.new(0,10); pad.Parent = Scroll

        -- Sections
        createHeader("FARM")
        UI.Toggles = {}
        UI.Sliders = {}
        UI.Bars = {}

        UI.Toggles.AuraEnabled = createToggle("BẬT KILL AURA", "AuraEnabled")
        UI.Sliders.AuraRange = createSlider("Phạm vi Aura", "AuraRange", 100, 3000, 10, " Studs")
        UI.Sliders.AttackDelay = createSlider("Tốc độ Đánh (s)", "AttackDelay", 0.05, 1.0, 0.01, " s")
        UI.Toggles.AutoMoveToTarget = createToggle("Auto Dịch chuyển (TP)", "AutoMoveToTarget")
        UI.Toggles.AutoBehindTarget = createToggle("Auto Đứng đằng sau mục tiêu", "AutoBehindTarget")

        createHeader("KỸ NĂNG & HỒI PHỤC")
        UI.Toggles.AutoHeal = createToggle("Auto Buff/Heal", "AutoHeal")
        UI.Sliders.AutoHealHPThreshold = createSlider("Ngưỡng HP Buff", "AutoHealHPThreshold", 0.1, 0.95, 0.05, " (0-1)")
        UI.Toggles.AutoSkills = createToggle("Auto Tất cả Skills", "AutoSkills")

        createHeader("STEALTH, HITBOX & MOVE")
        UI.Toggles.FreezeEnemyAI = createToggle("Khống chế quái (Freeze)", "FreezeEnemyAI")
        UI.Sliders.EnemyHitboxScale = createSlider("Giảm Hitbox Quái", "EnemyHitboxScale", 0.5, 1.0, 0.05, "x")
        UI.Sliders.PlayerHitboxScale = createSlider("Tăng Hitbox Người chơi", "PlayerHitboxScale", 1.0, 1.6, 0.05, "x")
        UI.Sliders.HitboxChangeInterval = createSlider("Hitbox Interval", "HitboxChangeInterval", 1, 60, 1, " s")
        UI.Sliders.MoveSpeedLimit = createSlider("Move Speed Limit", "MoveSpeedLimit", 1, 30, 0.5, "")
        UI.Toggles.AutoDisconnect = createToggle("Tự động rời khi admin", "AutoDisconnect")

        createHeader("GOM QUÁI & BURST")
        UI.Toggles.GomQuaiEnabled = createToggle("Bật Gom Quái", "GomQuaiEnabled")
        UI.Sliders.GomQuaiRange = createSlider("Phạm vi Gom", "GomQuaiRange", 5, 250, 1, " Studs")
        UI.Sliders.GomQuaiDelay = createSlider("Delay Gom (s)", "GomQuaiDelay", 0.1, 10, 0.1, " s")

        UI.Toggles.BurstEnabled = createToggle("Bật Burst Combo", "BurstEnabled")
        UI.Sliders.BurstCount = createSlider("Số hits trong Burst", "BurstCount", 1, 8, 1, " hits")
        UI.Sliders.BurstDelay = createSlider("Delay giữa hit", "BurstDelay", 0.01, 0.5, 0.01, " s")
        UI.Sliders.BurstCooldown = createSlider("Burst Cooldown (full)", "BurstCooldown", 0.5, 10, 0.1, " s")

        -- Bars
        local barFrame = Instance.new("Frame")
        barFrame.Size = UDim2.new(1, -20, 0, 60)
        barFrame.BackgroundColor3 = FRAME
        barFrame.Parent = Scroll
        local cb = Instance.new("UICorner") cb.CornerRadius = UDim.new(0,6) cb.Parent = barFrame

        local burstBg = Instance.new("Frame") burstBg.Size = UDim2.new(1,-20,0,20) burstBg.Position = UDim2.new(0,10,0,6) burstBg.BackgroundColor3 = Color3.fromRGB(50,50,50) burstBg.Parent = barFrame
        local burstFill = Instance.new("Frame") burstFill.Size = UDim2.new(0,0,1,0) burstFill.BackgroundColor3 = TOGG_ON burstFill.BorderSizePixel = 0 burstFill.Parent = burstBg
        local burstLabel = Instance.new("TextLabel") burstLabel.Size = UDim2.new(1,0,1,0) burstLabel.Text = "Burst: 0/"..tostring(SETTINGS.BurstCount) burstLabel.BackgroundTransparency = 1 burstLabel.Font = Enum.Font.SourceSans burstLabel.TextColor3 = Color3.new(1,1,1) burstLabel.TextSize = 14 burstLabel.Parent = burstBg

        local hitBg = Instance.new("Frame") hitBg.Size = UDim2.new(1,-20,0,20) hitBg.Position = UDim2.new(0,10,0,32) hitBg.BackgroundColor3 = Color3.fromRGB(50,50,50) hitBg.Parent = barFrame
        local hitFill = Instance.new("Frame") hitFill.Size = UDim2.new(0,0,1,0) hitFill.BackgroundColor3 = ACCENT hitFill.BorderSizePixel = 0 hitFill.Parent = hitBg
        local hitLabel = Instance.new("TextLabel") hitLabel.Size = UDim2.new(1,0,1,0) hitLabel.Text = "Hitbox: "..tostring(SETTINGS.PlayerHitboxScale).."x" hitLabel.BackgroundTransparency = 1 hitLabel.Font = Enum.Font.SourceSans hitLabel.TextColor3 = Color3.new(1,1,1) hitLabel.TextSize = 14 hitLabel.Parent = hitBg

        UI.Bars.BurstBar = burstFill UI.Bars.BurstLabel = burstLabel UI.Bars.HitboxBar = hitFill UI.Bars.HitboxLabel = hitLabel

        local footer = createHeader("Phím Tắt: "..SETTINGS.PANIC_KEY.Name.." (Ẩn UI / Panic)")
        footer.BackgroundColor3 = Color3.fromRGB(20,20,20)

        -- Draggable
        local drag = false
        local dragStart, dragOffset = Vector2.new(0,0), Vector2.new(0,0)
        Title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                drag = true
                dragStart = UserInputService:GetMouseLocation()
                local cur = UI.MainFrame.Position
                dragOffset = dragStart - Vector2.new(cur.X.Offset, cur.Y.Offset)
            end
        end)
        Title.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
        RunService.RenderStepped:Connect(function()
            if drag and UI.MainFrame then
                local m = UserInputService:GetMouseLocation()
                UI.MainFrame.Position = UDim2.new(0, m.X - dragOffset.X, 0, m.Y - dragOffset.Y)
            end
        end)

        return ScreenGui
    end

    -- create UI and set initial visibility
    pcall(function() createUI() end)
    if UI and UI.MainFrame then UI.MainFrame.Visible = SETTINGS.UIVisible end

    -- Panic key binding
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == SETTINGS.PANIC_KEY then
            if UI and UI.MainFrame then
                SETTINGS.UIVisible = not SETTINGS.UIVisible
                pcall(function() UI.MainFrame.Visible = SETTINGS.UIVisible end)
            end
            executePanicSwitch(false)
        end
    end)

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
    print("KKPIXEL_BLADE_V6.0: LOADED (Single-file, Safe Mode)")
    print("----------------------------------------------------")
end

pcall(safe_start_script)

-- Added: Resizable UI + Close Button + Save/Load Config System
-- Example implementation snippet:
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local cfgFile = "kkpixel_config.json"
local config = {}

local function loadConfig()
    if isfile(cfgFile) then
        local data = readfile(cfgFile)
        config = HttpService:JSONDecode(data)
    end
end

local function saveConfig()
    writefile(cfgFile, HttpService:JSONEncode(config))
end

-- Resizable UI frame
local ui = script.Parent:WaitForChild("MainUI")
local draggingSize = false
local resizeHandle = Instance.new("Frame", ui)
resizeHandle.Size = UDim2.new(0,20,0,20)
resizeHandle.Position = UDim2.new(1,-20,1,-20)
resizeHandle.BackgroundColor3 = Color3.fromRGB(90,90,90)
resizeHandle.Active = true
resizeHandle.Draggable = false

resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSize = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSize = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingSize and input.UserInputType == Enum.UserInputType.MouseMovement then
        local newX = math.clamp(input.Position.X - ui.AbsolutePosition.X, 200, 900)
        local newY = math.clamp(input.Position.Y - ui.AbsolutePosition.Y, 150, 700)
        ui.Size = UDim2.new(0,newX,0,newY)
        config.uiSize = {newX,newY}
        saveConfig()
    end
end)

-- Close Button (X)
local closeBtn = Instance.new("TextButton", ui)
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0,25,0,25)
closeBtn.Position = UDim2.new(1,-30,0,5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255,60,60)
closeBtn.MouseButton1Click:Connect(function()
    ui.Visible = false
end)

-- Apply config
loadConfig()
if config.uiSize then
    ui.Size = UDim2.new(0, config.uiSize[1], 0, config.uiSize[2])
end

-- ▼ Minimize Button (bottom-right)
local miniBtn = Instance.new("TextButton", ui)
miniBtn.Text = "_"
miniBtn.Size = UDim2.new(0,28,0,20)
miniBtn.Position = UDim2.new(1,-33,1,-25)
miniBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
miniBtn.TextColor3 = Color3.fromRGB(255,255,255)
miniBtn.AutoButtonColor = true

local minimized = false
local oldSize = ui.Size

miniBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        oldSize = ui.Size
        ui.Size = UDim2.new(0,200,0,35)
        config.uiMinimized = true
    else
        ui.Size = oldSize
        config.uiMinimized = false
    end
    saveConfig()
end)

-- Apply minimize state from config
if config.uiMinimized then
    minimized = true
    oldSize = UDim2.new(0, config.uiSize and config.uiSize[1] or 300, 0, config.uiSize and config.uiSize[2] or 200)
    ui.Size = UDim2.new(0,200,0,35)
end

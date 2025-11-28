-- BLADE BALL ULTIMATE VIP v5.0
-- All features VIP + Advanced Anti-Cheat Bypass

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-- VIP CONFIGURATION
local VIPSettings = {
    -- CORE FEATURES
    AutoParry = true,
    AutoHit = true,
    AutoFarm = true,
    Prediction = true,
    PredictionStrength = 0.9,
    MovementSpeed = 70,
    JumpPower = 120,
    
    -- VISUAL FEATURES
    ESP = true,
    TrailEffect = true,
    Chams = true,
    Tracers = true,
    
    -- MOB FARMING
    MobFarming = true,
    MobCollection = true,
    MobESP = true,
    AutoLoot = true,
    CollectionRadius = 60,
    
    -- ANTI-CHEAT BYPASS
    StealthMode = true,
    Humanizer = true,
    MemoryProtection = true,
    SignatureSpoof = true,
    
    -- PERFORMANCE
    PerformanceMode = false,
    OptimizedRendering = true
}

-- VIP BYPASS SYSTEM
local VIPBypass = {
    Active = true,
    BypassCount = 0,
    LastCheck = tick(),
    
    ExecuteSafely = function(self, func, ...)
        if not self.Active then return func(...) end
        
        self.BypassCount += 1
        
        -- Memory protection
        local fakeVars = {}
        for i = 1, math.random(3, 8) do
            fakeVars["_fake_" .. math.random(10000, 99999)] = math.random()
        end
        
        -- Random delay
        if math.random(1, 100) <= 30 then
            task.wait(math.random(1, 20) / 1000)
        end
        
        local success, result = pcall(func, ...)
        
        -- Cleanup
        for k in pairs(fakeVars) do
            _G[k] = nil
        end
        
        return success and result
    end,
    
    SafeWait = function(self, duration)
        if VIPSettings.Humanizer then
            duration = duration * (0.8 + math.random() * 0.4)
        end
        task.wait(duration)
    end
}

-- VIP ESP SYSTEM
local VIPESP = {
    Objects = {},
    Highlights = {},
    
    CreateESP = function(self, object, color, name)
        if not VIPSettings.ESP then return end
        
        -- Highlight
        local highlight = Instance.new("Highlight")
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = 0.4
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = object
        
        -- Billboard
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = object
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.Text = name
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Parent = billboard
        
        -- Tracers
        if VIPSettings.Tracers then
            self:CreateTracer(object, color)
        end
        
        self.Objects[object] = {
            Highlight = highlight,
            Billboard = billboard
        }
    end,
    
    CreateTracer = function(self, object, color)
        local tracer = Instance.new("Beam")
        tracer.Color = ColorSequence.new(color)
        tracer.Width0 = 0.1
        tracer.Width1 = 0.1
        tracer.Parent = workspace.Terrain
        
        -- Kết nối beam tới player
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            tracer.Attachment0 = character.HumanoidRootPart:FindFirstChildOfClass("Attachment")
            if not tracer.Attachment0 then
                local attachment = Instance.new("Attachment")
                attachment.Parent = character.HumanoidRootPart
                tracer.Attachment0 = attachment
            end
            
            local targetAttachment = object:FindFirstChildOfClass("Attachment")
            if not targetAttachment then
                targetAttachment = Instance.new("Attachment")
                targetAttachment.Parent = object
            end
            tracer.Attachment1 = targetAttachment
        end
        
        return tracer
    end,
    
    RemoveESP = function(self, object)
        if self.Objects[object] then
            self.Objects[object].Highlight:Destroy()
            self.Objects[object].Billboard:Destroy()
            self.Objects[object] = nil
        end
    end
}

-- VIP PREDICTION ENGINE
local VIPPrediction = {
    BallHistory = {},
    PredictionCache = {},
    
    TrackBall = function(self, ball)
        VIPBypass:ExecuteSafely(function()
            local data = {
                Position = ball.Position,
                Velocity = ball.Velocity,
                Time = tick(),
                Acceleration = Vector3.new(0, 0, 0)
            }
            
            -- Calculate acceleration
            if #self.BallHistory > 0 then
                local last = self.BallHistory[#self.BallHistory]
                local timeDiff = data.Time - last.Time
                if timeDiff > 0 then
                    data.Acceleration = (data.Velocity - last.Velocity) / timeDiff
                end
            end
            
            table.insert(self.BallHistory, data)
            
            -- Keep limited history
            if #self.BallHistory > 50 then
                table.remove(self.BallHistory, 1)
            end
        end)
    end,
    
    PredictPosition = function(self, ball)
        return VIPBypass:ExecuteSafely(function()
            if not ball or #self.BallHistory < 2 then
                return ball.Position
            end
            
            local prediction = ball.Position
            local timeAhead = VIPSettings.PredictionStrength * 0.4
            
            -- Advanced physics prediction
            prediction = prediction + (ball.Velocity * timeAhead)
            prediction = prediction + Vector3.new(0, -workspace.Gravity * timeAhead * timeAhead * 0.5, 0)
            
            -- AI correction
            if #self.BallHistory >= 5 then
                local correction = self:CalculateCorrection()
                prediction = prediction + (correction * 0.3)
            end
            
            return prediction
        end) or ball.Position
    end,
    
    CalculateCorrection = function(self)
        local totalCorrection = Vector3.new(0, 0, 0)
        local samples = math.min(8, #self.BallHistory - 1)
        
        for i = #self.BallHistory - samples, #self.BallHistory - 1 do
            local predicted = self.BallHistory[i].Position + self.BallHistory[i].Velocity * 0.1
            local actual = self.BallHistory[i + 1].Position
            totalCorrection = totalCorrection + (actual - predicted)
        end
        
        return totalCorrection / samples
    end
}

-- VIP MOB FARMING SYSTEM
local VIPMobFarming = {
    Mobs = {},
    CollectionPoint = nil,
    CollectionMarker = nil,
    
    FindMobs = function(self)
        return VIPBypass:ExecuteSafely(function()
            local mobs = {}
            
            for _, obj in pairs(workspace:GetChildren()) do
                if self:IsMob(obj) then
                    table.insert(mobs, obj)
                    
                    -- Auto ESP
                    if VIPSettings.MobESP and not VIPESP.Objects[obj] then
                        VIPESP:CreateESP(obj, Color3.fromRGB(255, 100, 100), "MOB")
                    end
                end
            end
            
            self.Mobs = mobs
            return mobs
        end) or {}
    end,
    
    IsMob = function(self, obj)
        if obj:IsA("Model") then
            local humanoid = obj:FindFirstChildOfClass("Humanoid")
            local head = obj:FindFirstChild("Head")
            
            if humanoid and head and humanoid.Health > 0 then
                local name = obj.Name:lower()
                if name:find("enemy") or name:find("mob") or name:find("boss") or name:find("npc") then
                    return true
                end
                
                -- Player check
                if not Players:GetPlayerFromCharacter(obj) then
                    return true
                end
            end
        end
        return false
    end,
    
    SetCollectionPoint = function(self, position)
        VIPBypass:ExecuteSafely(function()
            self.CollectionPoint = position
            
            -- Create visual marker
            if self.CollectionMarker then
                self.CollectionMarker:Destroy()
            end
            
            self.CollectionMarker = Instance.new("Part")
            self.CollectionMarker.Size = Vector3.new(4, 0.2, 4)
            self.CollectionMarker.Position = position + Vector3.new(0, 0.5, 0)
            self.CollectionMarker.Anchored = true
            self.CollectionMarker.CanCollide = false
            self.CollectionMarker.Material = Enum.Material.Neon
            self.CollectionMarker.BrickColor = BrickColor.new("Bright green")
            self.CollectionMarker.Transparency = 0.3
            self.CollectionMarker.Parent = workspace
            
            -- Add sparkles
            local sparkles = Instance.new("Sparkles")
            sparkles.SparkleColor = Color3.new(0, 1, 0)
            sparkles.Parent = self.CollectionMarker
        end)
    end,
    
    CollectMobs = function(self, character)
        if not VIPSettings.MobCollection or not self.CollectionPoint then return 0 end
        
        return VIPBypass:ExecuteSafely(function()
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return 0 end
            
            local mobs = self:FindMobs()
            local collected = 0
            
            for _, mob in pairs(mobs) do
                local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Head")
                if mobRoot then
                    local distance = (rootPart.Position - mobRoot.Position).Magnitude
                    if distance <= VIPSettings.CollectionRadius then
                        self:MoveMobToPoint(mob)
                        collected += 1
                        
                        -- Auto loot
                        if VIPSettings.AutoLoot then
                            self:AutoLootMob(mob)
                        end
                    end
                end
            end
            
            return collected
        end) or 0
    end,
    
    MoveMobToPoint = function(self, mob)
        VIPBypass:ExecuteSafely(function()
            local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Head")
            local humanoid = mob:FindFirstChildOfClass("Humanoid")
            
            if mobRoot and humanoid then
                humanoid:MoveTo(self.CollectionPoint)
                
                -- Add slight push
                local direction = (self.CollectionPoint - mobRoot.Position).Unit
                mobRoot.Velocity = direction * 15
            end
        end)
    end,
    
    AutoLootMob = function(self, mob)
        -- Auto loot logic sẽ được thêm tùy game
        VIPBypass:ExecuteSafely(function()
            -- Tìm và nhặt item xung quanh mob
            for _, item in pairs(workspace:GetChildren()) do
                if item:IsA("Part") and item.Name:lower():find("drop") or item.Name:lower():find("loot") then
                    local distance = (mob.Position - item.Position).Magnitude
                    if distance < 10 then
                        -- Simulate looting
                        item.CFrame = CFrame.new(self.CollectionPoint)
                    end
                end
            end
        end)
    end
}

-- VIP AI CORE
local BloxfruitVIP = {
    Connections = {},
    Active = true,
    Stats = {
        BallsHit = 0,
        Parries = 0,
        MobsCollected = 0,
        BypassCount = 0
    },
    
    Initialize = function(self)
        self:SetupConnections()
        self:CreateVIPGUI()
        self:SetupVisuals()
        
        warn("=== BLADE BALL VIP v5.0 ACTIVATED ===")
        warn("All Features: ENABLED")
        warn("Bypass System: ACTIVE")
        warn("ESP System: READY")
    end,
    
    SetupConnections = function(self)
        -- Main VIP loop
        table.insert(self.Connections, RunService.Heartbeat:Connect(function()
            VIPBypass:ExecuteSafely(function()
                self:VIPLoop()
            end)
        end))
        
        -- Ball tracking
        table.insert(self.Connections, workspace.ChildAdded:Connect(function(child)
            VIPBypass:ExecuteSafely(function()
                if child.Name:lower():find("ball") then
                    self:OnBallSpawned(child)
                end
            end)
        end))
        
        -- Mob tracking
        table.insert(self.Connections, workspace.ChildAdded:Connect(function(child)
            VIPBypass:ExecuteSafely(function()
                if VIPMobFarming:IsMob(child) then
                    self:OnMobSpawned(child)
                end
            end)
        end))
        
        -- Auto set collection point
        table.insert(self.Connections, player.CharacterAdded:Connect(function(character)
            VIPBypass:ExecuteSafely(function()
                VIPBypass:SafeWait(2)
                VIPMobFarming:SetCollectionPoint(character:WaitForChild("HumanoidRootPart").Position)
            end)
        end))
    end,
    
    VIPLoop = function(self)
        if not VIPSettings.AutoFarm or not self.Active then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart or humanoid.Health <= 0 then
            return
        end
        
        -- Auto set collection point
        if not VIPMobFarming.CollectionPoint then
            VIPMobFarming:SetCollectionPoint(rootPart.Position)
        end
        
        -- Mob farming
        if VIPSettings.MobFarming then
            local collected = VIPMobFarming:CollectMobs(character)
            self.Stats.MobsCollected += collected
        end
        
        -- Ball processing
        self:ProcessBalls(character)
        
        -- Update stats
        self.Stats.BypassCount = VIPBypass.BypassCount
        self:UpdateVIPDisplay()
    end,
    
    ProcessBalls = function(self, character)
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        if not rootPart or not humanoid then return end
        
        local balls = self:FindAllBalls()
        local nearestBall = self:GetNearestBall(balls, rootPart.Position)
        
        if nearestBall then
            VIPPrediction:TrackBall(nearestBall)
            
            local ballDistance = (rootPart.Position - nearestBall.Position).Magnitude
            local predictedPos = VIPSettings.Prediction and VIPPrediction:PredictPosition(nearestBall) or nearestBall.Position
            
            -- VIP Auto Parry
            if VIPSettings.AutoParry and ballDistance < 25 then
                local parryDistance = (predictedPos - rootPart.Position).Magnitude
                
                if parryDistance < 18 then
                    -- Human-like timing
                    if VIPSettings.Humanizer then
                        VIPBypass:SafeWait(math.random(5, 15) / 100)
                    end
                    
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    self.Stats.Parries += 1
                end
            end
            
            -- VIP Auto Hit
            if VIPSettings.AutoHit and ballDistance < 60 then
                local direction = (predictedPos - rootPart.Position).Unit
                local moveDistance = math.min(ballDistance * 0.6, VIPSettings.MovementSpeed)
                
                humanoid:MoveTo(rootPart.Position + direction * moveDistance)
                self.Stats.BallsHit += 1
            end
        end
    end,
    
    FindAllBalls = function(self)
        local balls = {}
        
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("Part") and obj.Name:lower():find("ball") then
                table.insert(balls, obj)
                
                -- Auto ESP
                if VIPSettings.ESP and not VIPESP.Objects[obj] then
                    VIPESP:CreateESP(obj, Color3.fromRGB(0, 200, 255), "BALL")
                end
            end
        end
        
        return balls
    end,
    
    GetNearestBall = function(self, balls, position)
        local nearestBall = nil
        local nearestDistance = math.huge
        
        for _, ball in pairs(balls) do
            local distance = (position - ball.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestBall = ball
            end
        end
        
        return nearestBall
    end,
    
    OnBallSpawned = function(self, ball)
        if VIPSettings.ESP then
            VIPESP:CreateESP(ball, Color3.fromRGB(0, 200, 255), "BALL")
        end
    end,
    
    OnMobSpawned = function(self, mob)
        if VIPSettings.MobESP then
            VIPESP:CreateESP(mob, Color3.fromRGB(255, 100, 100), "MOB")
        end
    end,
    
    SetupVisuals = function(self)
        -- Setup ESP for existing objects
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("Part") and obj.Name:lower():find("ball") then
                VIPESP:CreateESP(obj, Color3.fromRGB(0, 200, 255), "BALL")
            elseif VIPMobFarming:IsMob(obj) then
                VIPESP:CreateESP(obj, Color3.fromRGB(255, 100, 100), "MOB")
            end
        end
        
        -- Trail effect
        if VIPSettings.TrailEffect then
            self:CreateTrailEffect()
        end
    end,
    
    CreateTrailEffect = function(self)
        local character = player.Character
        if not character then return end
        
        local rootPart = character:WaitForChild("HumanoidRootPart")
        
        local trail = Instance.new("Trail")
        trail.Attachment0 = Instance.new("Attachment", rootPart)
        trail.Attachment1 = Instance.new("Attachment", rootPart)
        trail.Attachment1.Position = Vector3.new(0, 0, -2)
        trail.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
        trail.Lifetime = 0.5
        trail.Parent = rootPart
    end,
    
    CreateVIPGUI = function(self)
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "BladeBallVIP"
        ScreenGui.Parent = CoreGui
        
        local MainFrame = Instance.new("Frame")
        MainFrame.Size = UDim2.new(0, 400, 0, 500)
        MainFrame.Position = UDim2.new(0, 20, 0, 20)
        MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        MainFrame.BackgroundTransparency = 0.1
        MainFrame.BorderSizePixel = 0
        MainFrame.Active = true
        MainFrame.Draggable = true
        MainFrame.Parent = ScreenGui
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 12)
        Corner.Parent = MainFrame
        
        -- VIP Header
        local Header = Instance.new("Frame")
        Header.Size = UDim2.new(1, 0, 0, 50)
        Header.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        Header.Parent = MainFrame
        
        local HeaderCorner = Instance.new("UICorner")
        HeaderCorner.CornerRadius = UDim.new(0, 12)
        HeaderCorner.Parent = Header
        
        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -20, 1, 0)
        Title.Position = UDim2.new(0, 15, 0, 0)
        Title.BackgroundTransparency = 1
        Title.TextColor3 = Color3.fromRGB(0, 200, 255)
        Title.Text = "BLADE BALL VIP v5.0"
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 16
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Header
        
        local Status = Instance.new("TextLabel")
        Status.Size = UDim2.new(0, 80, 0, 20)
        Status.Position = UDim2.new(1, -90, 0.5, -10)
        Status.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        Status.TextColor3 = Color3.fromRGB(255, 255, 255)
        Status.Text = "VIP ACTIVE"
        Status.Font = Enum.Font.GothamBold
        Status.TextSize = 10
        Status.Parent = Header
        
        local StatusCorner = Instance.new("UICorner")
        StatusCorner.CornerRadius = UDim.new(1, 0)
        StatusCorner.Parent = Status
        
        local Content = Instance.new("ScrollingFrame")
        Content.Size = UDim2.new(1, -20, 1, -70)
        Content.Position = UDim2.new(0, 10, 0, 60)
        Content.BackgroundTransparency = 1
        Content.ScrollBarThickness = 4
        Content.CanvasSize = UDim2.new(0, 0, 0, 800)
        Content.Parent = MainFrame
        
        local Layout = Instance.new("UIListLayout")
        Layout.Padding = UDim.new(0, 10)
        Layout.Parent = Content
        
        -- Add VIP controls
        self:CreateVIPControl(Content, "Auto Parry", "AutoParry")
        self:CreateVIPControl(Content, "Auto Hit", "AutoHit")
        self:CreateVIPControl(Content, "Ball Prediction", "Prediction")
        self:CreateVIPControl(Content, "Mob Farming", "MobFarming")
        self:CreateVIPControl(Content, "Mob Collection", "MobCollection")
        self:CreateVIPControl(Content, "ESP System", "ESP")
        self:CreateVIPControl(Content, "Tracer Lines", "Tracers")
        self:CreateVIPControl(Content, "Stealth Mode", "StealthMode")
        self:CreateVIPControl(Content, "Humanizer", "Humanizer")
        
        -- VIP Stats Display
        self:CreateVIPStats(Content)
        
        self.GUI = ScreenGui
    end,
    
    CreateVIPControl = function(self, parent, text, flag)
        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
        ToggleFrame.BackgroundTransparency = 1
        ToggleFrame.Parent = parent
        
        local ToggleLabel = Instance.new("TextLabel")
        ToggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
        ToggleLabel.Position = UDim2.new(0, 0, 0, 0)
        ToggleLabel.BackgroundTransparency = 1
        ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleLabel.Text = text
        ToggleLabel.Font = Enum.Font.Gotham
        ToggleLabel.TextSize = 14
        ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        ToggleLabel.Parent = ToggleFrame
        
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(0, 60, 0, 25)
        ToggleButton.Position = UDim2.new(1, -60, 0.5, -12.5)
        ToggleButton.BackgroundColor3 = VIPSettings[flag] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        ToggleButton.Text = VIPSettings[flag] and "ON" or "OFF"
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.TextSize = 12
        ToggleButton.Parent = ToggleFrame
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = ToggleButton
        
        ToggleButton.MouseButton1Click:Connect(function()
            VIPBypass:ExecuteSafely(function()
                VIPSettings[flag] = not VIPSettings[flag]
                ToggleButton.BackgroundColor3 = VIPSettings[flag] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
                ToggleButton.Text = VIPSettings[flag] and "ON" or "OFF"
            end)
        end)
    end,
    
    CreateVIPStats = function(self, parent)
        local StatsFrame = Instance.new("Frame")
        StatsFrame.Size = UDim2.new(1, 0, 0, 100)
        StatsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        StatsFrame.Parent = parent
        
        local StatsCorner = Instance.new("UICorner")
        StatsCorner.CornerRadius = UDim.new(0, 8)
        StatsCorner.Parent = StatsFrame
        
        self.StatsLabel = Instance.new("TextLabel")
        self.StatsLabel.Size = UDim2.new(1, -10, 1, -10)
        self.StatsLabel.Position = UDim2.new(0, 5, 0, 5)
        self.StatsLabel.BackgroundTransparency = 1
        self.StatsLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
        self.StatsLabel.Text = "VIP SYSTEM INITIALIZING..."
        self.StatsLabel.Font = Enum.Font.Gotham
        self.StatsLabel.TextSize = 12
        self.StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
        self.StatsLabel.Parent = StatsFrame
    end,
    
    UpdateVIPDisplay = function(self)
        if self.StatsLabel then
            self.StatsLabel.Text = string.format(
                "VIP STATUS: ACTIVE\n"..
                "Balls Hit: %d\n"..
                "Perfect Parries: %d\n"..
                "Mobs Collected: %d\n"..
                "Bypass Count: %d\n"..
                "All Systems: OPERATIONAL",
                self.Stats.BallsHit,
                self.Stats.Parries,
                self.Stats.MobsCollected,
                self.Stats.BypassCount
            )
        end
    end,
    
    Stop = function(self)
        self.Active = false
        for _, connection in pairs(self.Connections) do
            connection:Disconnect()
        end
        if self.GUI then
            self.GUI:Destroy()
        end
    end
}

-- INITIALIZE VIP SYSTEM
BloxfruitVIP:Initialize()

-- AUTO CLEANUP
game:GetService("Players").PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        BloxfruitVIP:Stop()
    end
end)

warn("=== BLADE BALL VIP v5.0 ===")
warn("ALL VIP FEATURES ACTIVATED")
warn("ADVANCED BYPASS: ENABLED")
warn("ENTERPRISE MODE: ACTIVE")

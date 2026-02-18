--[[
    通用辅助中心 (最终修复版)
    功能：自瞄修复 + 队友/敌人颜色分离 + 骨骼透视
    适配：Synapse X, Krnl, Fluxus, Electron
]]

-- 1. 尝试加载 UI 库 (多源容错)
local Success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not Success then
    -- 如果主链接失败，尝试备用链接
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
end

local Window = Rayfield:CreateWindow({
    Name = "通用辅助中心 | 最终修复版",
    LoadingTitle = "正在加载脚本...",
    LoadingSubtitle = "自瞄 + 队友染色系统",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UniversalHub_V4",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

--// 服务引用
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// 全局设置表
local Settings = {
    Aimbot = {
        Enabled = false,
        TeamCheck = true, -- 自瞄强制不锁队友
        WallCheck = false,
        AimPart = "Head", -- 瞄准部位
        Smoothness = 0.5, -- 平滑度
        FOV = 150,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255)
    },
    ESP = {
        Enabled = false,
        Boxes = false,
        Names = false,
        Health = false,
        Tracers = false,
        Skeleton = false,
        ShowTeammates = true, -- 是否显示队友
        EnemyColor = Color3.fromRGB(255, 40, 40), -- 敌人红色
        TeamColor = Color3.fromRGB(40, 255, 40),  -- 队友绿色
        TextSize = 13
    },
    Misc = {
        WalkSpeed = 16,
        JumpPower = 50
    }
}

--// 绘图对象 (FOV圈)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 60
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Visible = false

--// 核心辅助函数

-- 判断玩家是否存活
local function IsAlive(Player)
    return Player and Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0
end

-- 判断是否为队友
local function IsTeammate(Player)
    if LocalPlayer.Team == nil or Player.Team == nil then return false end
    return LocalPlayer.Team == Player.Team
end

-- 获取最近的敌人 (用于自瞄)
local function GetClosestTarget()
    local ClosestPlayer = nil
    local ShortestDistance = Settings.Aimbot.FOV
    local MousePos = UserInputService:GetMouseLocation()

    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and IsAlive(Player) then
            -- 自瞄逻辑：如果是队友且开启了队伍检测，则跳过
            if Settings.Aimbot.TeamCheck and IsTeammate(Player) then continue end
            
            local Character = Player.Character
            local Part = Character:FindFirstChild(Settings.Aimbot.AimPart) or Character:FindFirstChild("Head")
            
            if Part then
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Part.Position)
                local Distance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - MousePos).Magnitude
                
                if OnScreen and Distance < ShortestDistance then
                    -- 墙体检测
                    if Settings.Aimbot.WallCheck then
                        local RayParams = RaycastParams.new()
                        RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Character}
                        RayParams.FilterType = Enum.RaycastFilterType.Blacklist
                        local RayHit = Workspace:Raycast(Camera.CFrame.Position, (Part.Position - Camera.CFrame.Position), RayParams)
                        if RayHit then continue end
                    end

                    ShortestDistance = Distance
                    ClosestPlayer = Player
                end
            end
        end
    end
    return ClosestPlayer
end

--// 渲染循环 (每帧运行)
RunService.RenderStepped:Connect(function()
    -- 1. 更新 FOV 圆圈位置
    FOVCircle.Visible = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
    FOVCircle.Radius = Settings.Aimbot.FOV
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Color = Settings.Aimbot.FOVColor

    -- 2. 自瞄执行逻辑
    if Settings.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local Target = GetClosestTarget()
        if Target and Target.Character then
            local Part = Target.Character:FindFirstChild(Settings.Aimbot.AimPart)
            if Part then
                -- 平滑锁定
                local TargetPos = Part.Position
                local CurrentCF = Camera.CFrame
                local GoalCF = CFrame.new(CurrentCF.Position, TargetPos)
                
                -- Lerp 插值实现平滑 (1 - Smoothness)
                Camera.CFrame = CurrentCF:Lerp(GoalCF, 1 - Settings.Aimbot.Smoothness)
            end
        end
    end
end)

--// ESP (透视) 系统 - 包含队友染色
local ESP_Storage = {}

local function RemoveESP(Player)
    if ESP_Storage[Player] then
        for _, v in pairs(ESP_Storage[Player]) do v:Remove() end
        ESP_Storage[Player] = nil
    end
end

local function CreateESP(Player)
    local Objs = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        HealthBar = Drawing.new("Line"),
        HealthOutline = Drawing.new("Line")
    }
    Objs.Box.Thickness = 1
    Objs.Box.Filled = false
    Objs.Name.Center = true
    Objs.Name.Outline = true
    Objs.Tracer.Thickness = 1
    
    ESP_Storage[Player] = Objs
end

RunService.RenderStepped:Connect(function()
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if not ESP_Storage[Player] then CreateESP(Player) end
            
            local Objs = ESP_Storage[Player]
            local Char = Player.Character
            local IsAlly = IsTeammate(Player)
            
            -- 决定是否绘制：玩家必须存活 + 透视开启
            local ShouldDraw = Settings.ESP.Enabled and IsAlive(Player)

            -- 如果不显示队友且是队友，则不绘制
            if IsAlly and not Settings.ESP.ShowTeammates then ShouldDraw = false end

            if ShouldDraw and Char and Char:FindFirstChild("HumanoidRootPart") and Char:FindFirstChild("Head") then
                local HRP = Char.HumanoidRootPart
                local Head = Char.Head
                local Hum = Char.Humanoid
                
                local Pos, OnScreen = Camera:WorldToViewportPoint(HRP.Position)
                
                if OnScreen then
                    -- 计算颜色：队友=绿，敌人=红
                    local DrawColor = IsAlly and Settings.ESP.TeamColor or Settings.ESP.EnemyColor

                    local HeadPos = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 0.5, 0))
                    local LegPos = Camera:WorldToViewportPoint(HRP.Position - Vector3.new(0, 3, 0))
                    local Height = LegPos.Y - HeadPos.Y
                    local Width = Height / 2

                    -- 应用颜色
                    Objs.Box.Color = DrawColor
                    Objs.Name.Color = DrawColor
                    Objs.Tracer.Color = DrawColor

                    -- 绘制方框
                    Objs.Box.Visible = Settings.ESP.Boxes
                    Objs.Box.Size = Vector2.new(Width, Height)
                    Objs.Box.Position = Vector2.new(Pos.X - Width/2, HeadPos.Y)

                    -- 绘制名字
                    Objs.Name.Visible = Settings.ESP.Names
                    Objs.Name.Text = Player.Name .. (IsAlly and " [队友]" or "")
                    Objs.Name.Position = Vector2.new(Pos.X, HeadPos.Y - 15)
                    Objs.Name.Size = Settings.ESP.TextSize

                    -- 绘制射线
                    Objs.Tracer.Visible = Settings.ESP.Tracers
                    Objs.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    Objs.Tracer.To = Vector2.new(Pos.X, LegPos.Y)
                    
                    -- 绘制血条 (颜色基于血量百分比)
                    if Settings.ESP.Health then
                        Objs.HealthOutline.Visible = true
                        Objs.HealthBar.Visible = true
                        local HP = Hum.Health / Hum.MaxHealth
                        local BarX = Pos.X - Width/2 - 5
                        
                        Objs.HealthOutline.From = Vector2.new(BarX, HeadPos.Y)
                        Objs.HealthOutline.To = Vector2.new(BarX, LegPos.Y)
                        Objs.HealthOutline.Color = Color3.new(0,0,0)
                        Objs.HealthOutline.Thickness = 3
                        
                        Objs.HealthBar.From = Vector2.new(BarX, LegPos.Y)
                        Objs.HealthBar.To = Vector2.new(BarX, LegPos.Y - (Height * HP))
                        Objs.HealthBar.Color = Color3.fromHSV(HP * 0.3, 1, 1) -- 动态血量颜色
                        Objs.HealthBar.Thickness = 1
                    else
                        Objs.HealthOutline.Visible = false
                        Objs.HealthBar.Visible = false
                    end
                else
                    for _, v in pairs(Objs) do v.Visible = false end
                end
            else
                for _, v in pairs(Objs) do v.Visible = false end
            end
        else
            RemoveESP(Player)
        end
    end
end)

Players.PlayerRemoving:Connect(RemoveESP)

--// 骨骼透视 (Skeleton) - 同样支持队友染色
local SkeletonLines = {}
local SkeletonLinks = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"}}

RunService.RenderStepped:Connect(function()
    for i, v in pairs(SkeletonLines) do v:Remove() end
    SkeletonLines = {}
    
    if not Settings.ESP.Enabled or not Settings.ESP.Skeleton then return end
    
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and IsAlive(Player) then
            local IsAlly = IsTeammate(Player)
            
            -- 如果设置不显示队友，则跳过
            if IsAlly and not Settings.ESP.ShowTeammates then continue end
            
            local DrawColor = IsAlly and Settings.ESP.TeamColor or Settings.ESP.EnemyColor
            local Char = Player.Character
            
            for _, Link in pairs(SkeletonLinks) do
                local P1 = Char:FindFirstChild(Link[1])
                local P2 = Char:FindFirstChild(Link[2])
                if P1 and P2 then
                    local Pos1, On1 = Camera:WorldToViewportPoint(P1.Position)
                    local Pos2, On2 = Camera:WorldToViewportPoint(P2.Position)
                    if On1 or On2 then
                        local L = Drawing.new("Line")
                        L.From = Vector2.new(Pos1.X, Pos1.Y)
                        L.To = Vector2.new(Pos2.X, Pos2.Y)
                        L.Color = DrawColor
                        L.Thickness = 1
                        L.Visible = true
                        table.insert(SkeletonLines, L)
                    end
                end
            end
        end
    end
end)

--// UI 界面构建 (Rayfield)

local AimTab = Window:CreateTab("自瞄设置", 4483345998)
local ESPTab = Window:CreateTab("透视视觉", 4483345998)
local MiscTab = Window:CreateTab("玩家杂项", 4483345998)

-- 自瞄页面
AimTab:CreateToggle({
    Name = "启用自瞄 (按住右键)",
    CurrentValue = false,
    Callback = function(v) Settings.Aimbot.Enabled = v end
})
AimTab:CreateToggle({
    Name = "不瞄队友 (强制)",
    CurrentValue = true,
    Callback = function(v) Settings.Aimbot.TeamCheck = v end
})
AimTab:CreateToggle({
    Name = "墙体检测 (不瞄墙后)",
    CurrentValue = false,
    Callback = function(v) Settings.Aimbot.WallCheck = v end
})
AimTab:CreateSlider({
    Name = "自瞄范围 (FOV)",
    Range = {10, 800},
    Increment = 10,
    CurrentValue = 150,
    Callback = function(v) Settings.Aimbot.FOV = v end
})
AimTab:CreateSlider({
    Name = "平滑度 (0=暴力, 0.9=缓慢)",
    Range = {0, 0.9},
    Increment = 0.1,
    CurrentValue = 0.5,
    Callback = function(v) Settings.Aimbot.Smoothness = v end
})

-- 透视页面
ESPTab:CreateToggle({
    Name = "启用透视 (总开关)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP.Enabled = v end
})
ESPTab:CreateSection("颜色设置")
ESPTab:CreateToggle({
    Name = "显示队友 (开启可看队友)",
    CurrentValue = true,
    Callback = function(v) Settings.ESP.ShowTeammates = v end
})
ESPTab:CreateColorPicker({
    Name = "敌人颜色 (默认红)",
    Color = Color3.fromRGB(255, 40, 40),
    Callback = function(v) Settings.ESP.EnemyColor = v end
})
ESPTab:CreateColorPicker({
    Name = "队友颜色 (默认绿)",
    Color = Color3.fromRGB(40, 255, 40),
    Callback = function(v) Settings.ESP.TeamColor = v end
})
ESPTab:CreateSection("透视项目")
ESPTab:CreateToggle({
    Name = "方框 (Box)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP.Boxes = v end
})
ESPTab:CreateToggle({
    Name = "骨骼 (Skeleton)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP.Skeleton = v end
})
ESPTab:CreateToggle({
    Name = "射线 (Tracers)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP.Tracers = v end
})
ESPTab:CreateToggle({
    Name = "名字 (Names)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP.Names = v end
})
ESPTab:CreateToggle({
    Name = "血条 (Health)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP.Health = v end
})

-- 杂项页面
MiscTab:CreateSlider({
    Name = "移动速度 (WalkSpeed)",
    Range = {16, 250},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(v)
        Settings.Misc.WalkSpeed = v
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = v
        end
    end
})

MiscTab:CreateSlider({
    Name = "跳跃高度 (JumpPower)",
    Range = {50, 300},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(v)
        Settings.Misc.JumpPower = v
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = v
        end
    end
})

-- 重生后保持属性
LocalPlayer.CharacterAdded:Connect(function(Char)
    task.wait(1)
    if Char:FindFirstChild("Humanoid") then
        Char.Humanoid.WalkSpeed = Settings.Misc.WalkSpeed
        Char.Humanoid.JumpPower = Settings.Misc.JumpPower
    end
end)

Rayfield:Notify({
    Title = "脚本加载成功",
    Content = "按 K 键可隐藏/显示菜单",
    Duration = 5,
    Image = 4483345998,
})

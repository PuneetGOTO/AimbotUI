--[[
    Aimbot v2.0 - “噩梦版”
    完善者: Lorain & AI 助手
    原始作者: 战斗++

    免责声明: 此脚本仅用于技术学习和研究目的。在游戏中使用此类工具会违反服务条款并可能导致账户封禁。
    请勿在任何游戏中使用。使用者需自行承担所有风险。
]]

print("正在启动 Aimbot [v2.0 噩梦版]...")

--// 缓存 & 服务
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

--// 缓存函数
local select, pcall, getgenv, next, Vector2, Vector3, CFrame, Color3, Enum, Instance, UDim, UDim2, Drawing, RaycastParams, typeof = 
      select, pcall, getgenv, next, Vector2.new, Vector3.new, CFrame.new, Color3.fromRGB, Enum, Instance.new, UDim.new, UDim2.new, Drawing.new, RaycastParams.new, typeof

local mathclamp, mathhuge = math.clamp, math.huge

--// 防止多进程运行
pcall(function()
	getgenv().Aimbot.Functions:Exit()
	print("已终止旧的 Aimbot 进程。")
end)

--// 环境
getgenv().Aimbot = {}
local Environment = getgenv().Aimbot

--// 变量
local Typing, Running, ServiceConnections, Animation = false, false, {}, nil
local oldMouseHit, oldMouseCFrame -- 用于静默瞄准挂钩

--// 脚本设置 (包含更多“可怕”功能!)
Environment.Settings = {
	Main = {
		Enabled = true,
		TriggerKey = "MouseButton2", -- 可以是按键码(KeyCode)或输入类型(UserInputType)
		Toggle = false,
	},
	Aimbot = {
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = true, -- 已通过射线投射优化
		LockPart = "Head", -- 目标部位
		TargetPriority = "Distance", -- 目标优先级: "Distance" (距离) 或 "FOV" (视野)
		Prediction = false, -- 移动预测
		BulletSpeed = 500, -- 子弹速度 (每秒 Studs), 请根据不同武器调整
		SilentAim = false, -- 可怕的功能：静默瞄准
	},
	Triggerbot = {
		Enabled = false,
		TriggerKey = "MouseButton1", -- 按住此键激活扳机机器人
	},
	Visuals = {
		FOV = {
			Enabled = true,
			Visible = true,
			Amount = 120, -- 范围
			Color = Color3(255, 255, 255),
			LockedColor = Color3(255, 0, 0),
			Transparency = 0.8,
			Sides = 60,
			Thickness = 1,
			Filled = false,
		},
		LockIndicator = {
			Enabled = true,
			Type = "Highlight", -- 锁定指示器类型: "Highlight" (高亮) 或 "Box" (方框)
			Color = Color3(255, 0, 0),
		}
	},
	Misc = {
		ThirdPerson = false, -- 第三人称模式：使用 mousemoverel 代替 CFrame
		ThirdPersonSensitivity = 3, -- 第三人称灵敏度, 范围: 0.1 - 10
		Smoothing = 0.1, -- 瞄准平滑: 完全锁定前的动画时间(秒)
	}
}

--// 视觉效果
Environment.FOVCircle = Drawing.new("Circle")
Environment.LockIndicator = nil -- 将会是高亮(Highlight)或广告牌GUI(BillboardGui)

--// ================== 核心函数 ==================

local function CancelLock()
	Environment.Locked = nil
	if Animation then Animation:Cancel() Animation = nil end
	
	if Environment.FOVCircle then
		Environment.FOVCircle.Color = Environment.Settings.Visuals.FOV.Color
	end

	if Environment.LockIndicator then
		if Environment.LockIndicator.ClassName == "Highlight" then
			Environment.LockIndicator.Enabled = false
		elseif Environment.LockIndicator.Parent ~= nil then
			Environment.LockIndicator:Destroy()
		end
		Environment.LockIndicator = nil
	end
end

local function CreateLockIndicator(target)
	if not Environment.Settings.Visuals.LockIndicator.Enabled or not target or not target.Character then return end
	
	-- 如果指示器已存在于目标身上，则重新启用它
	if Environment.LockIndicator and Environment.LockIndicator.Parent == target.Character then
		if Environment.LockIndicator.ClassName == "Highlight" then Environment.LockIndicator.Enabled = true end
		return
	end
	
	CancelLock() -- 清理上一个指示器

	if Environment.Settings.Visuals.LockIndicator.Type == "Highlight" then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Environment.Settings.Visuals.LockIndicator.Color
		highlight.OutlineColor = Color3(0,0,0)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- 始终在顶部显示
		highlight.Parent = target.Character
		Environment.LockIndicator = highlight
	else -- 可以扩展为其他类型，如方框
		-- 方框的实现示例，但高亮效果更好。
	end
end


local function GetClosestPlayer()
	local closestPlayer, requiredMetric = nil, mathhuge
	local fovRadius = Environment.Settings.Visuals.FOV.Enabled and Environment.Settings.Visuals.FOV.Amount or mathhuge
	local mousePos = UserInputService:GetMouseLocation()

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
			-- 设置检查
			if Environment.Settings.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
			if Environment.Settings.Aimbot.AliveCheck and player.Character.Humanoid.Health <= 0 then continue end

			local primaryPart = player.Character.PrimaryPart
			if not primaryPart then continue end

			-- 可见性 & 位置
			local targetPart = player.Character:FindFirstChild(Environment.Settings.Aimbot.LockPart)
			local headPos = targetPart and targetPart.Position or primaryPart.Position

			-- 智能目标回退 (如果头被挡住，尝试打身体)
			if targetPart and Environment.Settings.Aimbot.WallCheck then
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				rayParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
				
				local raycastResult = workspace:Raycast(Camera.CFrame.Position, (headPos - Camera.CFrame.Position).Unit * 2000, rayParams)
				if raycastResult and raycastResult.Instance.Parent ~= player.Character then
					-- 头被挡住了，尝试 HumanoidRootPart (躯干)
					targetPart = player.Character:FindFirstChild("HumanoidRootPart")
					headPos = targetPart and targetPart.Position or primaryPart.Position
					
					local torsoRaycast = workspace:Raycast(Camera.CFrame.Position, (headPos - Camera.CFrame.Position).Unit * 2000, rayParams)
					if torsoRaycast and torsoRaycast.Instance.Parent ~= player.Character then
						continue -- 头和身体都被挡住了
					end
				end
			end
			
			local vector, onScreen = Camera:WorldToViewportPoint(headPos)
			if onScreen then
				local metric
				if Environment.Settings.Aimbot.TargetPriority == "FOV" then -- 按视野距离
					metric = (Vector2(mousePos.X, mousePos.Y) - Vector2(vector.X, vector.Y)).Magnitude
					if metric < requiredMetric and metric <= fovRadius then
						requiredMetric = metric
						closestPlayer = player
					end
				else -- 按真实距离
					metric = (Camera.CFrame.Position - headPos).Magnitude
					if metric < requiredMetric then
						requiredMetric = metric
						closestPlayer = player
					end
				end
			end
		end
	end

	-- 检查当前锁定的目标是否仍然有效
	if Environment.Locked then
		if not Environment.Locked.Parent or not Environment.Locked.Character or Environment.Locked.Character.Humanoid.Health <= 0 then
			CancelLock()
		else
			local vector, onScreen = Camera:WorldToViewportPoint(Environment.Locked.Character:FindFirstChild(Environment.Settings.Aimbot.LockPart).Position)
			if not onScreen or (Vector2(mousePos.X, mousePos.Y) - Vector2(vector.X, vector.Y)).Magnitude > fovRadius then
				CancelLock()
			end
		end
	end

	if closestPlayer then
		Environment.Locked = closestPlayer
		CreateLockIndicator(closestPlayer)
	end
end

local function HandleTriggerbot()
    if not Environment.Settings.Triggerbot.Enabled or not UserInputService:IsKeyDown(Enum.KeyCode[Environment.Settings.Triggerbot.TriggerKey]) then
        return
    end

    local target = Mouse.Target
    if target and target.Parent and target.Parent:FindFirstChild("Humanoid") then
        local player = Players:GetPlayerFromCharacter(target.Parent)
        if player and player ~= LocalPlayer then
            if Environment.Settings.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then return end
            
            -- 开火
            pcall(function()
                mouse1press()
                task.wait(0.05)
                mouse1release()
            end)
        end
    end
end

local function SilentAimHook(activate)
    if activate then
        if getfenv(Mouse.Hit).script then return end -- 已经被挂钩
        oldMouseHit = Mouse.Hit
		oldMouseCFrame = Mouse.CFrame

        -- 挂钩是一个复杂的过程，可能会被修复。newcclosure 是一种常用方法。
        local mt = getrawmetatable(Mouse)
        local oldNamecall = mt.__namecall
        
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(...)
            local args = {...}
            local method = getnamecallmethod()
            -- 如果正在调用 Mouse.Hit 并且静默瞄准已激活
            if method == "Hit" and Environment.Locked and Running and Environment.Settings.Aimbot.SilentAim then
                local targetPart = Environment.Locked.Character:FindFirstChild(Environment.Settings.Aimbot.LockPart) or Environment.Locked.Character.PrimaryPart
                if targetPart then
					local aimPos = targetPart.Position
					if Environment.Settings.Aimbot.Prediction then -- 预测逻辑
						local distance = (Camera.CFrame.Position - aimPos).Magnitude
						local timeToTarget = distance / Environment.Settings.Aimbot.BulletSpeed
						aimPos = aimPos + (Environment.Locked.Character.PrimaryPart.AssemblyLinearVelocity * timeToTarget)
					end
                    return CFrame(aimPos) -- 返回修改后的目标位置
                end
            end
            return oldNamecall(...) -- 否则，正常调用
        end)
        setreadonly(mt, true)
        print("静默瞄准挂钩已附加。")
    else
		if not oldMouseHit then return end
		local mt = getrawmetatable(Mouse)
        local oldNamecall = mt.__namecall

		setreadonly(mt, false)
		-- 恢复 (这很棘手, 理想情况是找到原始函数, 但在此情景下这样可以)
		mt.__namecall = oldNamecall 
		setreadonly(mt, true)
		
        oldMouseHit = nil
        print("静默瞄准挂钩已分离。")
    end
end

--// ================== 主循环 ==================

local function MainLoop()
	-- 更新视觉效果
	if Environment.Settings.Visuals.FOV.Enabled and Environment.Settings.Main.Enabled then
		local fov = Environment.Settings.Visuals.FOV
		Environment.FOVCircle.Radius = fov.Amount
		Environment.FOVCircle.Thickness = fov.Thickness
		Environment.FOVCircle.Filled = fov.Filled
		Environment.FOVCircle.NumSides = fov.Sides
		Environment.FOVCircle.Color = Environment.Locked and fov.LockedColor or fov.Color
		Environment.FOVCircle.Transparency = fov.Transparency
		Environment.FOVCircle.Visible = fov.Visible
		Environment.FOVCircle.Position = UserInputService:GetMouseLocation()
	else
		Environment.FOVCircle.Visible = false
	end

	HandleTriggerbot()

	if Running and Environment.Settings.Main.Enabled then
		if not Environment.Locked then
			GetClosestPlayer()
		end

		if Environment.Locked then
			local targetPart = Environment.Locked.Character:FindFirstChild(Environment.Settings.Aimbot.LockPart) or Environment.Locked.Character.PrimaryPart
			if not targetPart then CancelLock() return end

			local aimPosition = targetPart.Position

			-- 移动预测逻辑
			if Environment.Settings.Aimbot.Prediction then
				local distance = (Camera.CFrame.Position - aimPosition).Magnitude
				if Environment.Settings.Aimbot.BulletSpeed > 0 then
					local timeToTarget = distance / Environment.Settings.Aimbot.BulletSpeed
					-- 目标未来位置 = 当前位置 + (速度 * 到达时间)
					aimPosition = aimPosition + (Environment.Locked.Character.PrimaryPart.AssemblyLinearVelocity * timeToTarget)
				end
			end
			
			-- 瞄准逻辑
			if Environment.Settings.Aimbot.SilentAim then
				-- 静默瞄准在挂钩函数中处理，这里不需要移动相机
			elseif Environment.Settings.Misc.ThirdPerson then
				local sensitivity = mathclamp(Environment.Settings.Misc.ThirdPersonSensitivity, 0.1, 10)
				local vector = Camera:WorldToViewportPoint(aimPosition)
				local mousePos = UserInputService:GetMouseLocation()
				mousemoverel((vector.X - mousePos.X) * sensitivity, (vector.Y - mousePos.Y) * sensitivity)
			else
				local aimCFrame = CFrame(Camera.CFrame.Position, aimPosition)
				if Environment.Settings.Misc.Smoothing > 0 then
					if Animation then Animation:Cancel() end
					Animation = TweenService:Create(Camera, TweenInfo.new(Environment.Settings.Misc.Smoothing, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = aimCFrame})
					Animation:Play()
				else
					Camera.CFrame = aimCFrame
				end
			end
		end
	else
		if Environment.Locked then
			CancelLock()
		end
	end
end

--// ================== UI 创建与逻辑 ==================
local AimbotUI, MainFrame

local function CreateUI()
	AimbotUI = Instance.new("ScreenGui")
	AimbotUI.Name = "AimbotUI_Nightmare_CN"
	AimbotUI.ResetOnSpawn = false
	AimbotUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
	
	-- 主界面开关按钮
	local ToggleButton = Instance.new("TextButton")
	ToggleButton.Size = UDim2.new(0, 50, 0, 50)
	ToggleButton.Position = UDim2.new(0, 20, 0.5, -25)
	ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	ToggleButton.Text = "梦" -- 噩梦的“梦”字
	ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	ToggleButton.TextSize = 24
	ToggleButton.Font = Enum.Font.GothamBold
	ToggleButton.Draggable = true
	ToggleButton.Parent = AimbotUI
	Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1,0)

	MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 550, 0, 400)
	MainFrame.Position = UDim2.new(0.5, -275, 0.5, -200)
	MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	MainFrame.BorderSizePixel = 0
	MainFrame.Draggable = true
	MainFrame.Active = true
	MainFrame.Visible = false
	MainFrame.Parent = AimbotUI
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
	
	ToggleButton.MouseButton1Click:Connect(function()
		MainFrame.Visible = not MainFrame.Visible
	end)

	local TitleBar = Instance.new("Frame")
	TitleBar.Size = UDim2.new(1, 0, 0, 40)
	TitleBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
	TitleBar.Parent = MainFrame
	
	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, 0, 1, 0)
	Title.BackgroundTransparency = 1
	Title.Text = "自瞄 v2.0 | 作者 战斗++ & Lorain"
	Title.TextColor3 = Color3.fromRGB(255, 0, 0)
	Title.TextSize = 18
	Title.Font = Enum.Font.GothamBold
	Title.Parent = TitleBar

	local TabsFrame = Instance.new("Frame")
	TabsFrame.Size = UDim2.new(1, 0, 0, 35)
	TabsFrame.Position = UDim2.new(0,0,0,40)
	TabsFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
	TabsFrame.Parent = MainFrame

	local ContentFrame = Instance.new("Frame")
	ContentFrame.Size = UDim2.new(1, -20, 1, -95)
	ContentFrame.Position = UDim2.new(0,10,0,85)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.Parent = MainFrame
	
	local Pages = {}

	-- 创建标签页和页面的辅助函数
	local function CreateTab(name)
		local Page = Instance.new("ScrollingFrame")
		Page.Size = UDim2.new(1, 0, 1, 0)
		Page.BackgroundTransparency = 1
		Page.BorderSizePixel = 0
		Page.CanvasSize = UDim2.new(0,0,2,0)
		Page.ScrollBarImageColor3 = Color3.fromRGB(255,0,0)
		Page.ScrollBarThickness = 5
		Page.Visible = false
		Page.Parent = ContentFrame

		local ListLayout = Instance.new("UIListLayout", Page)
		ListLayout.Padding = UDim.new(0, 10)
		ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

		local TabButton = Instance.new("TextButton")
		TabButton.Size = UDim2.new(0, 100, 1, 0)
		TabButton.Name = name
		TabButton.Text = name
		TabButton.BackgroundColor3 = Color3.fromRGB(25,25,25)
		TabButton.TextColor3 = Color3.fromRGB(180,180,180)
		TabButton.Font = Enum.Font.GothamSemibold
		TabButton.TextSize = 14
		TabButton.Parent = TabsFrame
		
		table.insert(Pages, {Button=TabButton, Page=Page})
		
		return Page
	end

	-- 创建UI组件的辅助函数
	local function CreateToggle(parent, text, settingTable, key)
		local Frame = Instance.new("TextButton")
		Frame.Size = UDim2.new(1, 0, 0, 30)
		Frame.BackgroundColor3 = Color3.fromRGB(40,40,40)
		Frame.AutoButtonColor = false
		Frame.Text = ""
		Frame.Parent = parent
		Instance.new("UICorner", Frame).CornerRadius = UDim.new(0,5)

		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(0.7, 0, 1, 0)
		Label.Position = UDim2.new(0, 10, 0, 0)
		Label.BackgroundTransparency = 1
		Label.Text = text
		Label.TextColor3 = Color3.fromRGB(220,220,220)
		Label.Font = Enum.Font.Gotham
		Label.TextXAlignment = Enum.TextXAlignment.Left

		local Status = Instance.new("TextLabel", Frame)
		Status.Size = UDim2.new(0.3, -10, 1, 0)
		Status.Position = UDim2.new(0.7, 0, 0, 0)
		Status.BackgroundTransparency = 1
		Status.Text = settingTable[key] and "开启" or "关闭"
		Status.TextColor3 = settingTable[key] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
		Status.Font = Enum.Font.GothamBold
		Status.TextXAlignment = Enum.TextXAlignment.Right

		Frame.MouseButton1Click:Connect(function()
			settingTable[key] = not settingTable[key]
			Status.Text = settingTable[key] and "开启" or "关闭"
			Status.TextColor3 = settingTable[key] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
            if key == "SilentAim" then SilentAimHook(settingTable[key]) end -- 静默瞄准的特殊处理
		end)
	end
	
	local function CreateSlider(parent, text, settingTable, key, min, max, step)
		local Frame = Instance.new("Frame")
		Frame.Size = UDim2.new(1,0,0,50)
		Frame.BackgroundTransparency = 1
		Frame.Parent = parent

		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(1, 0, 0, 20)
		Label.BackgroundTransparency = 1
		Label.Font = Enum.Font.Gotham
		Label.TextColor3 = Color3.fromRGB(220,220,220)
		Label.TextXAlignment = Enum.TextXAlignment.Left
		
		local SliderFrame = Instance.new("Frame", Frame)
		SliderFrame.Size = UDim2.new(1, 0, 0, 10)
		SliderFrame.Position = UDim2.new(0,0,0,25)
		SliderFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
		Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0,5)
		
		local Progress = Instance.new("Frame", SliderFrame)
		Progress.BackgroundColor3 = Color3.fromRGB(255,0,0)
		Instance.new("UICorner", Progress).CornerRadius = UDim.new(0,5)

		local Handle = Instance.new("TextButton", SliderFrame)
		Handle.Size = UDim2.new(0,16,0,16)
		Handle.Position = UDim2.new(0, -8, 0.5, -8)
		Handle.BackgroundColor3 = Color3.fromRGB(255,255,255)
		Handle.Text = ""
		Instance.new("UICorner", Handle).CornerRadius = UDim.new(1,0)
		
		local function UpdateSlider(value)
			local percentage = (value - min) / (max-min)
			Progress.Size = UDim2.new(percentage, 0, 1, 0)
			Handle.Position = UDim2.new(percentage, -8, 0.5, -8)
			Label.Text = string.format("%s: %.2f", text, value)
			settingTable[key] = value
		end

		UpdateSlider(settingTable[key])

		Handle.MouseButton1Down:Connect(function()
			local move_conn, release_conn
			move_conn = UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					local relativePos = (input.Position.X - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X
					local newValue = mathclamp(min + (max-min) * relativePos, min, max)
					newValue = math.floor(newValue / step + 0.5) * step -- 应用步长
					UpdateSlider(newValue)
				end
			end)
			release_conn = UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					move_conn:Disconnect()
					release_conn:Disconnect()
				end
			end)
		end)
	end

	local function CreateKeybind(parent, text, settingTable, key)
		local Frame = Instance.new("Frame")
		Frame.Size = UDim2.new(1,0,0,30)
		Frame.BackgroundColor3 = Color3.fromRGB(40,40,40)
		Frame.Parent = parent
		Instance.new("UICorner", Frame).CornerRadius = UDim.new(0,5)

		local Label = Instance.new("TextLabel", Frame)
		Label.Size = UDim2.new(0.5, 0, 1, 0)
		Label.Position = UDim2.new(0, 10, 0, 0)
		Label.BackgroundTransparency = 1
		Label.Text = text
		Label.TextColor3 = Color3.fromRGB(220,220,220)
		Label.Font = Enum.Font.Gotham
		Label.TextXAlignment = Enum.TextXAlignment.Left

		local KeyButton = Instance.new("TextButton", Frame)
		KeyButton.Size = UDim2.new(0.5, -10, 1, -10)
		KeyButton.Position = UDim2.new(0.5, 0, 0.5, -10)
		KeyButton.BackgroundColor3 = Color3.fromRGB(30,30,30)
		KeyButton.TextColor3 = Color3.fromRGB(255,255,255)
		KeyButton.Font = Enum.Font.GothamBold
		KeyButton.Text = tostring(settingTable[key])
		Instance.new("UICorner", KeyButton).CornerRadius = UDim.new(0,4)
		
		KeyButton.MouseButton1Click:Connect(function()
			KeyButton.Text = "..."
			local conn = UserInputService.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				local keyName
				if input.UserInputType == Enum.UserInputType.MouseButton1 then keyName = "MouseButton1"
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then keyName = "MouseButton2"
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then keyName = "MouseButton3"
				else keyName = input.KeyCode.Name end
				
				settingTable[key] = keyName
				KeyButton.Text = keyName
				conn:Disconnect()
			end)
		end)
	end
	
	-- 创建页面
	local mainPage = CreateTab("主要")
	local visualsPage = CreateTab("视觉")
	local miscPage = CreateTab("杂项")

	-- 填充“主要”页面
	CreateToggle(mainPage, "启用自瞄", Environment.Settings.Main, "Enabled")
	CreateKeybind(mainPage, "自瞄按键", Environment.Settings.Main, "TriggerKey")
	CreateToggle(mainPage, "切换模式", Environment.Settings.Main, "Toggle")
	CreateToggle(mainPage, "队友检查", Environment.Settings.Aimbot, "TeamCheck")
	CreateToggle(mainPage, "穿墙检查 (已优化)", Environment.Settings.Aimbot, "WallCheck")
	CreateToggle(mainPage, "静默瞄准", Environment.Settings.Aimbot, "SilentAim")
	CreateToggle(mainPage, "移动预测", Environment.Settings.Aimbot, "Prediction")
	CreateSlider(mainPage, "子弹速度", Environment.Settings.Aimbot, "BulletSpeed", 0, 2000, 50)
	CreateToggle(mainPage, "启用扳机", Environment.Settings.Triggerbot, "Enabled")
	CreateKeybind(mainPage, "扳机按键", Environment.Settings.Triggerbot, "TriggerKey")
	
	-- 填充“视觉”页面
	CreateToggle(visualsPage, "启用视野圈", Environment.Settings.Visuals.FOV, "Enabled")
	CreateToggle(visualsPage, "显示视野圈", Environment.Settings.Visuals.FOV, "Visible")
	CreateSlider(visualsPage, "视野圈半径", Environment.Settings.Visuals.FOV, "Amount", 10, 500, 5)
	CreateSlider(visualsPage, "视野圈边数", Environment.Settings.Visuals.FOV, "Sides", 3, 100, 1)
	CreateToggle(visualsPage, "启用锁定指示", Environment.Settings.Visuals.LockIndicator, "Enabled")

	-- 填充“杂项”页面
	CreateSlider(miscPage, "瞄准平滑", Environment.Settings.Misc, "Smoothing", 0, 1, 0.01)
	CreateToggle(miscPage, "第三人称瞄准", Environment.Settings.Misc, "ThirdPerson")
	CreateSlider(miscPage, "第三人称灵敏度", Environment.Settings.Misc, "ThirdPersonSensitivity", 0.1, 10, 0.1)


	-- 标签页切换逻辑
	local function SwitchTab(selected)
		for _, v in ipairs(Pages) do
			local isSelected = v.Button == selected
			v.Page.Visible = isSelected
			v.Button.BackgroundColor3 = isSelected and Color3.fromRGB(40,40,40) or Color3.fromRGB(25,25,25)
			v.Button.TextColor3 = isSelected and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,180)
		end
	end

	for _, v in ipairs(Pages) do
		v.Button.MouseButton1Click:Connect(function()
			SwitchTab(v.Button)
		end)
	end
	
	Instance.new("UIListLayout", TabsFrame).FillDirection = Enum.FillDirection.Horizontal
	
	-- 默认选中第一个标签页
	SwitchTab(Pages[1].Button)

	AimbotUI.Parent = PlayerGui
end

--// ================== 脚本控制 ==================

local function Load()
	CreateUI()

	ServiceConnections.RenderStepped = RunService.RenderStepped:Connect(MainLoop)

	ServiceConnections.InputBegan = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or Typing then return end
		local keyName = input.KeyCode.Name
		local inputType = input.UserInputType.Name

		if keyName == Environment.Settings.Main.TriggerKey or inputType == Environment.Settings.Main.TriggerKey then
			if Environment.Settings.Main.Toggle then
				Running = not Running
				if not Running then CancelLock() end
			else
				Running = true
			end
		end
	end)

	ServiceConnections.InputEnded = UserInputService.InputEnded:Connect(function(input, gpe)
		if gpe or Typing then return end
		local keyName = input.KeyCode.Name
		local inputType = input.UserInputType.Name

		if not Environment.Settings.Main.Toggle then
			if keyName == Environment.Settings.Main.TriggerKey or inputType == Environment.Settings.Main.TriggerKey then
				Running = false
				CancelLock()
			end
		end
	end)
	
	ServiceConnections.TypingStarted = UserInputService.TextBoxFocused:Connect(function() Typing = true; CancelLock() end)
	ServiceConnections.TypingEnded = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)
end

Environment.Functions = {}
function Environment.Functions:Exit()
	for _, v in pairs(ServiceConnections) do
		v:Disconnect()
	end
	if Environment.FOVCircle and Environment.FOVCircle.Remove then Environment.FOVCircle:Remove() end
	if AimbotUI then AimbotUI:Destroy() end
    SilentAimHook(false) -- 确保退出时移除挂钩
	getgenv().Aimbot = nil
end

--// 启动脚本
Load()

print("Aimbot [v2.0 噩梦版] 加载成功。请负责任地使用。")

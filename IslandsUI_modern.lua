-- Islands Modern UI
-- Created by Codeium AI

print("Script Source Released on 17.03.2024")
warn("Loading Islands Modern UI...")

repeat wait() until game:IsLoaded()

-- Constants
local ScriptVersion = "V4"
local FileName = "Islands"
local GameName = "Islands" 
local NotificationIcon = "rbxassetid://1234567890"

-- Load UI Libraries
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/IJHGIAJGIHJASUIJGHIUHIUHSUIAOHJAHOIBNAO/Nekohub/main/Fluent-master/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/IJHGIAJGIHJASUIJGHIUHIUHSUIAOHJAHOIBNAO/Nekohub/main/Fluent-master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/IJHGIAJGIHJASUIJGHIUHIUHSUIAOHJAHOIBNAO/Nekohub/main/Fluent-master/Addons/InterfaceManager.lua"))()

-- Notification System
local function SendNotification(Title, Text)
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title = Title,
        Text = Text, 
        Icon = NotificationIcon
    })
end

SendNotification("Welcome!", "Welcome to Islands "..ScriptVersion)

-- Create Main Window
local Window = Fluent:CreateWindow({
    Title = "Islands Modern "..ScriptVersion,
    SubTitle = "by Codeium AI",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Create Tabs
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Farming = Window:AddTab({ Title = "Farming", Icon = "tree" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Building = Window:AddTab({ Title = "Building", Icon = "blocks" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Main Tab
local MainSection = Tabs.Main:AddSection("Quick Actions")

MainSection:AddButton({
    Title = "Collect All Resources",
    Description = "Automatically collect all nearby resources",
    Callback = function()
        -- Add resource collection logic
    end
})

MainSection:AddToggle({
    Title = "Auto Farm",
    Description = "Automatically farm resources",
    Default = false,
    Callback = function(Value)
        _G.AutoFarm = Value
    end
})

-- Combat Tab  
local CombatSection = Tabs.Combat:AddSection("Combat Options")

CombatSection:AddToggle({
    Title = "Kill Aura",
    Description = "Automatically attack nearby enemies",
    Default = false,
    Callback = function(Value)
        _G.KillAura = Value
    end
})

CombatSection:AddSlider({
    Title = "Attack Range",
    Description = "Set the kill aura range",
    Default = 10,
    Min = 5,
    Max = 20,
    Callback = function(Value)
        _G.KillAuraRange = Value
    end
})

-- Farming Tab
local FarmingSection = Tabs.Farming:AddSection("Farming Options")

FarmingSection:AddToggle({
    Title = "Auto Plant",
    Description = "Automatically plant crops",
    Default = false,
    Callback = function(Value)
        _G.AutoPlant = Value
    end
})

FarmingSection:AddToggle({
    Title = "Auto Harvest", 
    Description = "Automatically harvest crops",
    Default = false,
    Callback = function(Value)
        _G.AutoHarvest = Value
    end
})

-- Teleport Tab
local TeleportSection = Tabs.Teleport:AddSection("Locations")

TeleportSection:AddButton({
    Title = "Hub",
    Description = "Teleport to Hub",
    Callback = function()
        TeleportV4(game:GetService("Workspace").Hub.Position)
    end
})

TeleportSection:AddButton({
    Title = "Farm",
    Description = "Teleport to Farm Area",
    Callback = function()
        TeleportV4(game:GetService("Workspace").Farm.Position) 
    end
})

-- Building Tab
local BuildingSection = Tabs.Building:AddSection("Building Tools")

BuildingSection:AddToggle({
    Title = "Block Printer",
    Description = "Automatically place blocks",
    Default = false,
    Callback = function(Value)
        _G.BlockPrinter = Value
    end
})

BuildingSection:AddDropdown({
    Title = "Block Type",
    Description = "Select block type to place",
    Values = {"Wood", "Stone", "Metal"},
    Default = "Wood",
    Callback = function(Value)
        _G.BlockType = Value
    end
})

-- Player Tab
local PlayerSection = Tabs.Player:AddSection("Player Options")

PlayerSection:AddToggle({
    Title = "Player Fly",
    Description = "Enable flying",
    Default = false,
    Callback = function(Value)
        _G.PlayerFly = Value
    end
})

PlayerSection:AddSlider({
    Title = "Walk Speed",
    Description = "Set player walk speed",
    Default = 16,
    Min = 16,
    Max = 100,
    Callback = function(Value)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = Value
    end
})

-- Settings Tab
local SettingsSection = Tabs.Settings:AddSection("Settings")

SettingsSection:AddDropdown({
    Title = "Teleport Method",
    Description = "Select teleport method",
    Values = {"Tween", "Instant", "MiniTp"},
    Default = "Tween",
    Callback = function(Value)
        _G.TeleportMethod = Value
    end
})

SettingsSection:AddToggle({
    Title = "Auto Update",
    Description = "Automatically update script",
    Default = true,
    Callback = function(Value)
        _G.AutoUpdate = Value
    end
})

-- Initialize Save Manager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Set ignore indexes
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

-- Initialize Interface Manager
InterfaceManager:SetFolder("IslandsModern")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- Load Interface Manager
SaveManager:Load()

-- Set window to center
Window:SelectTab(1)

-- Anti AFK
local VirtualUser = game:GetService("VirtualUser")
game.Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

SendNotification("Loaded!", "Islands Modern UI has been loaded successfully!")

-- [[ Load Theme First ]]
local UI_Theme_URL = "https://raw.githubusercontent.com/learnhtsd/lt2/refs/heads/main/ui_theme.lua"
local Theme = loadstring(game:HttpGet(UI_Theme_URL))()

-- [[ Cleanup Old UI ]]
if game.CoreGui:FindFirstChild("MyModularHub") then
    game.CoreGui.MyModularHub:Destroy()
end

-- [[ Base Frames ]]
local Hub_ScreenGui = Instance.new("ScreenGui", game.CoreGui)
Hub_ScreenGui.Name = "MyModularHub"
Hub_ScreenGui.ResetOnSpawn = false

local Main_Frame = Instance.new("Frame", Hub_ScreenGui)
Main_Frame.Size = UDim2.fromOffset(600, 400)
Main_Frame.Position = UDim2.fromScale(0.5, 0.5)
Main_Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Main_Frame.BackgroundColor3 = Theme.Colors.MainBackground
Instance.new("UICorner", Main_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

-- [[ Sidebar Construction ]]
local Sidebar = Instance.new("Frame", Main_Frame)
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 140, 1, -20)
Sidebar.Position = UDim2.fromOffset(10, 10)
Sidebar.BackgroundColor3 = Theme.Colors.NavbarBackground
Instance.new("UICorner", Sidebar)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- [[ Page Holder Construction ]]
local PageHolder = Instance.new("Frame", Main_Frame)
PageHolder.Name = "PageHolder"
PageHolder.Size = UDim2.new(1, -170, 1, -20)
PageHolder.Position = UDim2.fromOffset(160, 10)
PageHolder.BackgroundTransparency = 1

-- [[ Tab System API ]]
local Hub = { Tabs = {} }
local TabCount = 0

function Hub:CreateTab(name)
    TabCount = TabCount + 1
    
    -- Create the scrolling content area
    local Page = Instance.new("ScrollingFrame", PageHolder)
    Page.Name = name .. "Tab"
    Page.Size = UDim2.fromScale(1, 1)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.ScrollBarThickness = 2
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local Layout = Instance.new("UIListLayout", Page)
    Layout.Padding = UDim.new(0, 8)

    -- Create the Sidebar Button
    local TabBtn = Instance.new("TextButton", Sidebar)
    TabBtn.Size = UDim2.new(0.9, 0, 0, 35)
    TabBtn.Text = name
    TabBtn.BackgroundColor3 = Theme.Colors.ButtonDefault
    TabBtn.TextColor3 = Theme.Colors.TextColor
    TabBtn.Font = Theme.Fonts.Main
    TabBtn.LayoutOrder = TabCount
    Instance.new("UICorner", TabBtn)

    -- Click Logic
    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(PageHolder:GetChildren()) do
            if p:IsA("ScrollingFrame") then p.Visible = false end
        end
        Page.Visible = true
    end)

    -- Default to the first tab created
    if TabCount == 1 then Page.Visible = true end

    return Page
end

-- [[ Element API ]]
function Hub:AddButton(parent, name, callback)
    local Btn = Instance.new("TextButton", parent)
    Btn.Size = UDim2.new(1, -10, 0, 40)
    Btn.BackgroundColor3 = Theme.Colors.ElementBackground
    Btn.Text = "  " .. name
    Btn.TextColor3 = Theme.Colors.TextColor
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Theme.Fonts.Main
    Instance.new("UICorner", Btn)
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

-- [[ Settings Logic Implementation ]]
local Settings = {}
function Settings:Load(Tab, MainFrame, ScreenGui)
    local UserInputService = game:GetService("UserInputService")
    local CurrentKey = Enum.KeyCode.RightControl
    
    -- 1. Menu Toggle Hotkey
    Hub:AddButton(Tab, "Menu Toggle: [Right Control]", function()
        print("To change key, edit the 'CurrentKey' variable in script.")
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CurrentKey then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)

    -- 2. Scale / UI Size
    Hub:AddButton(Tab, "Increase Menu Scale", function()
        MainFrame.Size = UDim2.fromOffset(MainFrame.AbsoluteSize.X + 20, MainFrame.AbsoluteSize.Y + 15)
    end)

    Hub:AddButton(Tab, "Decrease Menu Scale", function()
        MainFrame.Size = UDim2.fromOffset(MainFrame.AbsoluteSize.X - 20, MainFrame.AbsoluteSize.Y - 15)
    end)

    -- 3. Dark Mode / Light Mode Toggle
    local IsDark = true
    Hub:AddButton(Tab, "Toggle Dark/Light Mode", function()
        IsDark = not IsDark
        MainFrame.BackgroundColor3 = IsDark and Theme.Colors.MainBackground or Color3.fromRGB(240, 240, 240)
    end)

    -- 4. Unload Button
    Hub:AddButton(Tab, "Unload UI / Stop Script", function()
        ScreenGui:Destroy()
    end)
end

-- [[ Initialize Your Tabs ]]
local HomeTab     = Hub:CreateTab("Home")
local PlayerTab   = Hub:CreateTab("Player")
local WorldTab    = Hub:CreateTab("World")
local TeleportTab = Hub:CreateTab("Teleport")
local TreeTab     = Hub:CreateTab("Tree")
local SettingsTab = Hub:CreateTab("Settings")

-- [[ Initialize Content ]]
Hub:AddButton(HomeTab, "Welcome to the Hub", function() print("Home!") end)
Hub:AddButton(PlayerTab, "Infinite Jump (Example)", function() print("Jump active") end)

-- RUN THE SETTINGS LOAD FUNCTION
Settings:Load(SettingsTab, Main_Frame, Hub_ScreenGui)

getgenv().Hub = Hub

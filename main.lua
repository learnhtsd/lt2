local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- [[ Load Theme ]]
local Theme = {
    ["Colors"] = {
        MainBackground = Color3.fromRGB(24, 25, 30),
        NavbarBackground = Color3.fromRGB(18, 19, 23),
        ElementBackground = Color3.fromRGB(30, 31, 37),
        AccentColor = Color3.fromRGB(75, 120, 240),
        TextColor = Color3.fromRGB(255, 255, 255),
        SecondaryTextColor = Color3.fromRGB(200, 200, 200),
        ButtonDefault = Color3.fromRGB(35, 36, 42),
        SliderBar = Color3.fromRGB(50, 50, 60),
        SliderHandle = Color3.fromRGB(255, 255, 255),
        ToggleOn = Color3.fromRGB(75, 120, 240),
        ToggleOff = Color3.fromRGB(50, 50, 60),
    },
    ["Fonts"] = {
        Main = Enum.Font.Gotham,
        MainBold = Enum.Font.GothamBold,
        Secondary = Enum.Font.GothamMedium,
    },
    ["Sizes"] = {
        ElementHeight = 40,
        ElementCornerRadius = UDim.new(0, 8),
        UI_Size = UDim2.fromOffset(550, 380)
    }
}

-- [[ Utility Functions ]]
local function MakeDraggable(frame, parent)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = parent.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            parent.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- [[ Cleanup ]]
if game.CoreGui:FindFirstChild("ModernHub") then game.CoreGui.ModernHub:Destroy() end

-- [[ Main UI Construction ]]
local Hub_ScreenGui = Instance.new("ScreenGui", game.CoreGui)
Hub_ScreenGui.Name = "ModernHub"

local Main_Frame = Instance.new("Frame", Hub_ScreenGui)
Main_Frame.Size = Theme.Sizes.UI_Size
Main_Frame.Position = UDim2.fromScale(0.5, 0.5)
Main_Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Main_Frame.BackgroundColor3 = Theme.Colors.MainBackground
Main_Frame.BorderSizePixel = 0
Instance.new("UICorner", Main_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

-- Subtle Border (UIStroke)
local MainStroke = Instance.new("UIStroke", Main_Frame)
MainStroke.Thickness = 1.2
MainStroke.Color = Theme.Colors.AccentColor
MainStroke.Transparency = 0.6

-- Drag Handle / Top Bar
local TopBar = Instance.new("Frame", Main_Frame)
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundTransparency = 1
MakeDraggable(TopBar, Main_Frame)

-- Sidebar
local Sidebar = Instance.new("Frame", Main_Frame)
Sidebar.Size = UDim2.new(0, 150, 1, -10)
Sidebar.Position = UDim2.fromOffset(5, 5)
Sidebar.BackgroundColor3 = Theme.Colors.NavbarBackground
Instance.new("UICorner", Sidebar).CornerRadius = Theme.Sizes.ElementCornerRadius

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Page Holder
local PageHolder = Instance.new("Frame", Main_Frame)
PageHolder.Size = UDim2.new(1, -165, 1, -40)
PageHolder.Position = UDim2.fromOffset(160, 35)
PageHolder.BackgroundTransparency = 1

-- [[ Hub API ]]
local Hub = { Tabs = {}, ActiveTab = nil }

function Hub:CreateTab(name)
    local TabBtn = Instance.new("TextButton", Sidebar)
    TabBtn.Size = UDim2.new(0.9, 0, 0, 32)
    TabBtn.BackgroundColor3 = Theme.Colors.ButtonDefault
    TabBtn.Text = name
    TabBtn.TextColor3 = Theme.Colors.SecondaryTextColor
    TabBtn.Font = Theme.Fonts.Secondary
    TabBtn.TextSize = 13
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)
    
    local TabStroke = Instance.new("UIStroke", TabBtn)
    TabStroke.Thickness = 1
    TabStroke.Color = Theme.Colors.AccentColor
    TabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    TabStroke.Transparency = 1 -- Hidden by default

    local Page = Instance.new("ScrollingFrame", PageHolder)
    Page.Size = UDim2.fromScale(1, 1)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.ScrollBarThickness = 0
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UIListLayout", Page).Padding = UDim.new(0, 6)

    TabBtn.MouseButton1Click:Connect(function()
        for _, otherPage in pairs(PageHolder:GetChildren()) do otherPage.Visible = false end
        for _, otherBtn in pairs(Sidebar:GetChildren()) do 
            if otherBtn:IsA("TextButton") then
                TweenService:Create(otherBtn, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Colors.ButtonDefault, TextColor3 = Theme.Colors.SecondaryTextColor}):Play()
                otherBtn.UIStroke.Transparency = 1
            end
        end
        
        Page.Visible = true
        TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Colors.AccentColor, TextColor3 = Theme.Colors.TextColor}):Play()
        TabBtn.UIStroke.Transparency = 0
    end)

    if not Hub.ActiveTab then
        Page.Visible = true
        Hub.ActiveTab = TabBtn
        TabBtn.BackgroundColor3 = Theme.Colors.AccentColor
        TabBtn.TextColor3 = Theme.Colors.TextColor
        TabStroke.Transparency = 0
    end

    return Page
end

function Hub:AddButton(parent, name, callback)
    local BtnFrame = Instance.new("Frame", parent)
    BtnFrame.Size = UDim2.new(1, -10, 0, Theme.Sizes.ElementHeight)
    BtnFrame.BackgroundColor3 = Theme.Colors.ElementBackground
    Instance.new("UICorner", BtnFrame).CornerRadius = Theme.Sizes.ElementCornerRadius
    
    local Btn = Instance.new("TextButton", BtnFrame)
    Btn.Size = UDim2.fromScale(1, 1)
    Btn.BackgroundTransparency = 1
    Btn.Text = "   " .. name
    Btn.TextColor3 = Theme.Colors.TextColor
    Btn.Font = Theme.Fonts.Main
    Btn.TextSize = 14
    Btn.TextXAlignment = Enum.TextXAlignment.Left

    -- Hover Animation
    Btn.MouseEnter:Connect(function()
        TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 41, 48)}):Play()
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.ElementBackground}):Play()
    end)
    
    Btn.MouseButton1Click:Connect(callback)
end

-- [[ Initialization ]]
local HomeTab = Hub:CreateTab("Home")
local PlayerTab = Hub:CreateTab("Player")
local SettingsTab = Hub:CreateTab("Settings")

Hub:AddButton(HomeTab, "Welcome to Modern Hub", function() print("Hello!") end)
Hub:AddButton(SettingsTab, "Unload Script", function() Hub_ScreenGui:Destroy() end)

return Hub

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- [[ 1. THEME CONFIGURATION ]]
local Theme = {
    ["Colors"] = {
        MainBackground = Color3.fromRGB(24, 25, 30),
        NavbarBackground = Color3.fromRGB(18, 19, 23),
        ElementBackground = Color3.fromRGB(30, 31, 37),
        AccentColor = Color3.fromRGB(75, 120, 240),
        TextColor = Color3.fromRGB(255, 255, 255),
        SecondaryTextColor = Color3.fromRGB(200, 200, 200),
        ButtonDefault = Color3.fromRGB(35, 36, 42),
    },
    ["Fonts"] = {
        Main = Enum.Font.Gotham,
        MainBold = Enum.Font.GothamBold,
    },
    ["Sizes"] = {
        ElementHeight = 38,
        ElementCornerRadius = UDim.new(0, 6),
        UI_Size = UDim2.fromOffset(550, 350)
    }
}

-- [[ 2. CLEANUP & CORE ]]
if game.CoreGui:FindFirstChild("ModernHub") then game.CoreGui.ModernHub:Destroy() end

local Hub_ScreenGui = Instance.new("ScreenGui", game.CoreGui)
Hub_ScreenGui.Name = "ModernHub"
Hub_ScreenGui.ResetOnSpawn = false

local Main_Frame = Instance.new("Frame", Hub_ScreenGui)
Main_Frame.Size = Theme.Sizes.UI_Size
Main_Frame.Position = UDim2.fromScale(0.5, 0.5)
Main_Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Main_Frame.BackgroundColor3 = Theme.Colors.MainBackground
Main_Frame.BorderSizePixel = 0
Instance.new("UICorner", Main_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

local MainStroke = Instance.new("UIStroke", Main_Frame)
MainStroke.Thickness = 1.2
MainStroke.Color = Theme.Colors.AccentColor
MainStroke.Transparency = 0.5

-- [[ 3. DRAG LOGIC ]]
local function MakeDraggable(frame, parent)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = parent.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            parent.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

local DragHandle = Instance.new("Frame", Main_Frame)
DragHandle.Size = UDim2.new(1, 0, 0, 30)
DragHandle.BackgroundTransparency = 1
MakeDraggable(DragHandle, Main_Frame)

-- [[ 4. LAYOUT COMPONENTS ]]
local Sidebar = Instance.new("Frame", Main_Frame)
Sidebar.Size = UDim2.new(0, 140, 1, -20)
Sidebar.Position = UDim2.fromOffset(10, 10)
Sidebar.BackgroundColor3 = Theme.Colors.NavbarBackground
Instance.new("UICorner", Sidebar)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local PageHolder = Instance.new("Frame", Main_Frame)
PageHolder.Size = UDim2.new(1, -170, 1, -40)
PageHolder.Position = UDim2.fromOffset(160, 30)
PageHolder.BackgroundTransparency = 1

-- [[ 5. API FUNCTIONS ]]
local Hub = { Tabs = {} }

function Hub:CreateTab(name)
    local TabBtn = Instance.new("TextButton", Sidebar)
    TabBtn.Size = UDim2.new(0.9, 0, 0, 32)
    TabBtn.BackgroundColor3 = Theme.Colors.ButtonDefault
    TabBtn.Text = name
    TabBtn.TextColor3 = Theme.Colors.SecondaryTextColor
    TabBtn.Font = Theme.Fonts.Main
    TabBtn.TextSize = 13
    Instance.new("UICorner", TabBtn)
    
    local TabStroke = Instance.new("UIStroke", TabBtn)
    TabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    TabStroke.Color = Theme.Colors.AccentColor
    TabStroke.Transparency = 1

    local Page = Instance.new("ScrollingFrame", PageHolder)
    Page.Size = UDim2.fromScale(1, 1)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.ScrollBarThickness = 0
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UIListLayout", Page).Padding = UDim.new(0, 6)

    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(PageHolder:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end
        for _, b in pairs(Sidebar:GetChildren()) do 
            if b:IsA("TextButton") then 
                TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.ButtonDefault}):Play()
                b.UIStroke.Transparency = 1
            end 
        end
        Page.Visible = true
        TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.AccentColor}):Play()
        TabStroke.Transparency = 0
    end)

    if #Sidebar:GetChildren() == 2 then -- Auto-select first tab
        Page.Visible = true
        TabBtn.BackgroundColor3 = Theme.Colors.AccentColor
        TabStroke.Transparency = 0
    end

    return Page
end

function Hub:AddButton(parent, name, callback)
    local BtnFrame = Instance.new("Frame", parent)
    BtnFrame.Size = UDim2.new(1, -10, 0, Theme.Sizes.ElementHeight)
    BtnFrame.BackgroundColor3 = Theme.Colors.ElementBackground
    Instance.new("UICorner", BtnFrame)
    
    local Btn = Instance.new("TextButton", BtnFrame)
    Btn.Size = UDim2.fromScale(1, 1)
    Btn.BackgroundTransparency = 1
    Btn.Text = "   " .. name
    Btn.TextColor3 = Theme.Colors.TextColor
    Btn.Font = Theme.Fonts.Main
    Btn.TextSize = 14
    Btn.TextXAlignment = Enum.TextXAlignment.Left

    Btn.MouseEnter:Connect(function()
        TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 46, 53)}):Play()
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.ElementBackground}):Play()
    end)

    Btn.MouseButton1Click:Connect(callback)
end

-- [[ 6. INITIALIZATION ]]
local HomeTab = Hub:CreateTab("Home")
local PlayerTab = Hub:CreateTab("Player")
local SettingsTab = Hub:CreateTab("Settings")

-- Add Content
Hub:AddButton(HomeTab, "Welcome to the Improved UI", function() print("Home Clicked") end)

-- [[ 7. LOAD SETTINGS DIRECTLY ]]
local function LoadSettings()
    local CurrentKey = Enum.KeyCode.RightControl
    
    Hub:AddButton(SettingsTab, "Toggle Key: [Right Control]", function()
        print("Keybind system ready")
    end)

    Hub:AddButton(SettingsTab, "Scale Up UI", function()
        Main_Frame.Size = UDim2.fromOffset(Main_Frame.AbsoluteSize.X + 20, Main_Frame.AbsoluteSize.Y + 15)
    end)

    Hub:AddButton(SettingsTab, "Scale Down UI", function()
        Main_Frame.Size = UDim2.fromOffset(Main_Frame.AbsoluteSize.X - 20, Main_Frame.AbsoluteSize.Y - 15)
    end)

    Hub:AddButton(SettingsTab, "Unload UI", function()
        Hub_ScreenGui:Destroy()
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == CurrentKey then
            Hub_ScreenGui.Enabled = not Hub_ScreenGui.Enabled
        end
    end)
end

LoadSettings()

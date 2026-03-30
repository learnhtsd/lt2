-- File: main.lua (Save inside the main folder)

local UI_Theme_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/MyModularHub/refs/heads/main/ui_theme.lua"
local Success, Theme = pcall(function()
    return loadstring(game:HttpGet(UI_Theme_URL))()
end)

if not (Success and Theme) then
    error("Failed to load UI Theme script. Make sure the URL is correct and public.")
end

-- ==========================================
-- Core UI Creation Logic (Background, Navbar, etc.)
-- ==========================================
local Hub_ScreenGui = Instance.new("ScreenGui", game.Players.LocalPlayer:WaitForChild("PlayerGui"))
Hub_ScreenGui.Name = "MyModularHub"
Hub_ScreenGui.ResetOnSpawn = false

local Main_Frame = Instance.new("Frame", Hub_ScreenGui)
Main_Frame.Name = "MainFrame"
Main_Frame.Size = Theme.Sizes.UI_Size
Main_Frame.BackgroundColor3 = Theme.Colors.MainBackground
Main_Frame.BorderSizePixel = 0
Main_Frame.Position = UDim2.fromScale(0.5, 0.5)
Main_Frame.AnchorPoint = Vector2.new(0.5, 0.5)

Instance.new("UICorner", Main_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

-- (Creation of Navbar, Page Container, language icons, and active page logic would go here)
-- (This part requires a full UI library creation which is a larger project.)
-- For this modular example, we will focus on how features connect.

-- A key object for our modular system: The Page Container.
-- All elements will be parented here and UIListLayout handles placement.
local PageContainer = Instance.new("Frame", Main_Frame)
PageContainer.Name = "PageContainer"
PageContainer.Size = UDim2.new(1, -70, 1, -60) -- Offset for navbar and title
PageContainer.Position = UDim2.fromOffset(70, 60)
PageContainer.BackgroundTransparency = 1

local PageLayout = Instance.new("UIListLayout", PageContainer)
PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
PageLayout.Padding = UDim.new(0, 8) -- Distance between options

-- Example Title (Based on image)
local PageTitle = Instance.new("TextLabel", Main_Frame)
PageTitle.Text = "SlotTab"
PageTitle.Size = UDim2.fromOffset(200, 30)
PageTitle.Position = UDim2.fromOffset(130, 20)
PageTitle.BackgroundTransparency = 1
PageTitle.TextColor3 = Theme.Colors.SecondaryTextColor
PageTitle.TextSize = 18
PageTitle.Font = Theme.Fonts.MainBold
PageTitle.TextXAlignment = Enum.TextXAlignment.Left

-- ==========================================
-- Feature Injection (The Core of the Idea)
-- ==========================================
-- This is how another script can add a button/slider/toggle.

local Add_Button = function(name, callback)
    local Button_Frame = Instance.new("Frame", PageContainer)
    Button_Frame.Size = UDim2.new(1, -20, 0, Theme.Sizes.ElementHeight)
    Button_Frame.BackgroundColor3 = Theme.Colors.ElementBackground
    Instance.new("UICorner", Button_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

    local ButtonText = Instance.new("TextLabel", Button_Frame)
    ButtonText.Text = name
    ButtonText.Size = UDim2.new(0.7, 0, 1, 0)
    ButtonText.Position = UDim2.fromOffset(10, 0)
    ButtonText.BackgroundTransparency = 1
    ButtonText.TextColor3 = Theme.Colors.TextColor
    ButtonText.TextSize = 16
    ButtonText.Font = Theme.Fonts.Main
    ButtonText.TextXAlignment = Enum.TextXAlignment.Left

    local Click_Button = Instance.new("TextButton", Button_Frame)
    Click_Button.Name = "ActionButton"
    Click_Button.Text = "Activate"
    Click_Button.Size = UDim2.fromOffset(100, Theme.Sizes.ElementHeight - 10)
    Click_Button.Position = UDim2.new(1, -110, 0.5, 0)
    Click_Button.AnchorPoint = Vector2.new(0, 0.5)
    Click_Button.BackgroundColor3 = Theme.Colors.ButtonDefault
    Click_Button.TextColor3 = Theme.Colors.AccentColor
    Click_Button.TextSize = 16
    Click_Button.Font = Theme.Fonts.MainBold
    Instance.new("UICorner", Click_Button).CornerRadius = Theme.Sizes.ElementCornerRadius

    Click_Button.MouseButton1Click:Connect(callback)
end

local Add_Toggle = function(name, default, callback)
    local Toggle_Frame = Instance.new("Frame", PageContainer)
    Toggle_Frame.Size = UDim2.new(1, -20, 0, Theme.Sizes.ElementHeight)
    Toggle_Frame.BackgroundColor3 = Theme.Colors.ElementBackground
    Instance.new("UICorner", Toggle_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

    local ToggleText = Instance.new("TextLabel", Toggle_Frame)
    ToggleText.Text = name
    ToggleText.Size = UDim2.new(0.7, 0, 1, 0)
    ToggleText.Position = UDim2.fromOffset(10, 0)
    ToggleText.BackgroundTransparency = 1
    ToggleText.TextColor3 = Theme.Colors.TextColor
    ToggleText.TextSize = 16
    ToggleText.Font = Theme.Fonts.Main
    ToggleText.TextXAlignment = Enum.TextXAlignment.Left

    local Toggle_Btn = Instance.new("TextButton", Toggle_Frame)
    Toggle_Btn.Name = "Toggle"
    Toggle_Btn.Text = "" -- Empty text
    Toggle_Btn.Size = UDim2.fromOffset(60, Theme.Sizes.ElementHeight - 10)
    Toggle_Btn.Position = UDim2.new(1, -70, 0.5, 0)
    Toggle_Btn.AnchorPoint = Vector2.new(0, 0.5)
    Toggle_Btn.BackgroundColor3 = (default and Theme.Colors.ToggleOn or Theme.Colors.ToggleOff)
    Instance.new("UICorner", Toggle_Btn).CornerRadius = UDim.new(1, 0) -- Rounded edges for toggle

    local State = default
    Toggle_Btn.MouseButton1Click:Connect(function()
        State = not State
        Toggle_Btn.BackgroundColor3 = (State and Theme.Colors.ToggleOn or Theme.Colors.ToggleOff)
        callback(State)
    end)
end

-- (Similar Add_Slider function would go here)

-- Expose these functions as the public API
getgenv().Hub = {
    AddButton = Add_Button,
    AddToggle = Add_Toggle,
    Theme = Theme -- Allow features to read theme info
}

-- Return the hub framework itself
return Hub

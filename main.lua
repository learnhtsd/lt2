-- ==========================================
-- 1. Theme Loading (The "Brain")
-- ==========================================
local UI_Theme_URL = "https://raw.githubusercontent.com/learnhtsd/lt2/refs/heads/main/ui_theme.lua"

local function GetTheme()
    local success, result = pcall(function()
        return game:HttpGet(UI_Theme_URL)
    end)
    
    if not success then return nil end
    
    local func, err = loadstring(result)
    if not func then 
        warn("Theme Syntax Error: " .. tostring(err))
        return nil 
    end
    
    local runSuccess, themeTable = pcall(func)
    if not runSuccess then return nil end
    
    return themeTable
end

local Theme = GetTheme()

-- Fallback Theme (If GitHub fails, the UI still loads so you can use it)
if not Theme then
    warn("Using Fallback Theme: GitHub link failed or file is formatted incorrectly.")
    Theme = {
        Colors = {
            MainBackground = Color3.fromRGB(25, 25, 25),
            ElementBackground = Color3.fromRGB(35, 35, 35),
            AccentColor = Color3.fromRGB(75, 120, 240),
            TextColor = Color3.fromRGB(255, 255, 255),
            SecondaryTextColor = Color3.fromRGB(200, 200, 200),
            ButtonDefault = Color3.fromRGB(45, 45, 45),
            ToggleOn = Color3.fromRGB(75, 120, 240),
            ToggleOff = Color3.fromRGB(60, 60, 60),
        },
        Fonts = { Main = Enum.Font.Gotham, MainBold = Enum.Font.GothamBold },
        Sizes = { ElementHeight = 40, ElementCornerRadius = UDim.new(0, 8), UI_Size = UDim2.fromOffset(500, 400) }
    }
end

-- ==========================================
-- 2. Core UI Creation
-- ==========================================
local Hub_ScreenGui = Instance.new("ScreenGui")
Hub_ScreenGui.Name = "MyModularHub"
Hub_ScreenGui.ResetOnSpawn = false
Hub_ScreenGui.Parent = game.CoreGui -- Changed to CoreGui so it stays if you reset

local Main_Frame = Instance.new("Frame", Hub_ScreenGui)
Main_Frame.Name = "MainFrame"
Main_Frame.Size = Theme.Sizes.UI_Size
Main_Frame.BackgroundColor3 = Theme.Colors.MainBackground
Main_Frame.BorderSizePixel = 0
Main_Frame.Position = UDim2.fromScale(0.5, 0.5)
Main_Frame.AnchorPoint = Vector2.new(0.5, 0.5)

Instance.new("UICorner", Main_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

-- Page Container
local PageContainer = Instance.new("ScrollingFrame", Main_Frame)
PageContainer.Name = "PageContainer"
PageContainer.Size = UDim2.new(1, -20, 1, -70)
PageContainer.Position = UDim2.fromOffset(10, 60)
PageContainer.BackgroundTransparency = 1
PageContainer.ScrollBarThickness = 2
PageContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
PageContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y

local PageLayout = Instance.new("UIListLayout", PageContainer)
PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
PageLayout.Padding = UDim.new(0, 8)

-- Title
local PageTitle = Instance.new("TextLabel", Main_Frame)
PageTitle.Text = "Modular Hub v1.0"
PageTitle.Size = UDim2.fromOffset(200, 30)
PageTitle.Position = UDim2.fromOffset(15, 15)
PageTitle.BackgroundTransparency = 1
PageTitle.TextColor3 = Theme.Colors.TextColor
PageTitle.TextSize = 20
PageTitle.Font = Theme.Fonts.MainBold
PageTitle.TextXAlignment = Enum.TextXAlignment.Left

-- ==========================================
-- 3. Feature API
-- ==========================================
local Hub = {}

function Hub:AddButton(name, callback)
    local Button_Frame = Instance.new("Frame", PageContainer)
    Button_Frame.Size = UDim2.new(1, -10, 0, Theme.Sizes.ElementHeight)
    Button_Frame.BackgroundColor3 = Theme.Colors.ElementBackground
    Instance.new("UICorner", Button_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

    local ButtonText = Instance.new("TextLabel", Button_Frame)
    ButtonText.Text = name
    ButtonText.Size = UDim2.new(0.6, 0, 1, 0)
    ButtonText.Position = UDim2.fromOffset(10, 0)
    ButtonText.BackgroundTransparency = 1
    ButtonText.TextColor3 = Theme.Colors.TextColor
    ButtonText.Font = Theme.Fonts.Main
    ButtonText.TextXAlignment = Enum.TextXAlignment.Left

    local Click_Button = Instance.new("TextButton", Button_Frame)
    Click_Button.Text = "EXECUTE"
    Click_Button.Size = UDim2.fromOffset(80, Theme.Sizes.ElementHeight - 12)
    Click_Button.Position = UDim2.new(1, -90, 0.5, 0)
    Click_Button.AnchorPoint = Vector2.new(0, 0.5)
    Click_Button.BackgroundColor3 = Theme.Colors.ButtonDefault
    Click_Button.TextColor3 = Theme.Colors.AccentColor
    Click_Button.Font = Theme.Fonts.MainBold
    Instance.new("UICorner", Click_Button).CornerRadius = Theme.Sizes.ElementCornerRadius

    Click_Button.MouseButton1Click:Connect(callback)
end

function Hub:AddToggle(name, default, callback)
    local Toggle_Frame = Instance.new("Frame", PageContainer)
    Toggle_Frame.Size = UDim2.new(1, -10, 0, Theme.Sizes.ElementHeight)
    Toggle_Frame.BackgroundColor3 = Theme.Colors.ElementBackground
    Instance.new("UICorner", Toggle_Frame).CornerRadius = Theme.Sizes.ElementCornerRadius

    local ToggleText = Instance.new("TextLabel", Toggle_Frame)
    ToggleText.Text = name
    ToggleText.Size = UDim2.new(0.6, 0, 1, 0)
    ToggleText.Position = UDim2.fromOffset(10, 0)
    ToggleText.BackgroundTransparency = 1
    ToggleText.TextColor3 = Theme.Colors.TextColor
    ToggleText.Font = Theme.Fonts.Main
    ToggleText.TextXAlignment = Enum.TextXAlignment.Left

    local Toggle_Btn = Instance.new("TextButton", Toggle_Frame)
    Toggle_Btn.Text = ""
    Toggle_Btn.Size = UDim2.fromOffset(45, 22)
    Toggle_Btn.Position = UDim2.new(1, -55, 0.5, 0)
    Toggle_Btn.AnchorPoint = Vector2.new(0, 0.5)
    Toggle_Btn.BackgroundColor3 = (default and Theme.Colors.ToggleOn or Theme.Colors.ToggleOff)
    Instance.new("UICorner", Toggle_Btn).CornerRadius = UDim.new(1, 0)

    local State = default
    Toggle_Btn.MouseButton1Click:Connect(function()
        State = not State
        Toggle_Btn.BackgroundColor3 = (State and Theme.Colors.ToggleOn or Theme.Colors.ToggleOff)
        callback(State)
    end)
end

-- ==========================================
-- 4. Execution & Testing
-- ==========================================
getgenv().Hub = Hub

-- Example Usage (This is what you'd put in your actual script):
Hub:AddButton("Print Hello", function()
    print("Hello from the menu!")
end)

Hub:AddToggle("God Mode", false, function(toggled)
    print("God Mode is now: ", toggled)
end)

print("Menu Loaded Successfully!")

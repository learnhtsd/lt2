local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- [[ THEME ]]
local Theme = {
    Colors = {
        MainBackground = Color3.fromRGB(20, 21, 26),
        SecondaryBackground = Color3.fromRGB(28, 29, 35),
        Sidebar = Color3.fromRGB(18, 19, 23),
        Accent = Color3.fromRGB(90, 140, 255),
        AccentDark = Color3.fromRGB(65, 110, 230),
        Text = Color3.fromRGB(255,255,255),
        SubText = Color3.fromRGB(180,180,180),
        SectionText = Color3.fromRGB(110, 115, 125), -- Color for section headers
        Element = Color3.fromRGB(35, 36, 42),
        ElementHover = Color3.fromRGB(50, 52, 60)
    },
    Fonts = {
        Main = Enum.Font.Gotham,
        Bold = Enum.Font.GothamBold
    }
}

-- cleanup
if game.CoreGui:FindFirstChild("ModernHub") then
    game.CoreGui.ModernHub:Destroy()
end

-- screen
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name = "ModernHub"
gui.ResetOnSpawn = false

-- main frame
local main = Instance.new("Frame", gui)
main.Size = UDim2.fromOffset(600, 380)
main.Position = UDim2.fromScale(0.5,0.5)
main.AnchorPoint = Vector2.new(0.5,0.5)
main.BackgroundColor3 = Theme.Colors.MainBackground
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)

-- gradient & styling
local grad = Instance.new("UIGradient", main)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Theme.Colors.MainBackground),
    ColorSequenceKeypoint.new(1, Theme.Colors.SecondaryBackground)
}
local stroke = Instance.new("UIStroke", main)
stroke.Color = Theme.Colors.Accent
stroke.Transparency = 0.7
stroke.Thickness = 1.5

-- DRAG LOGIC
local function dragify(frame)
    local drag, start, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            start = i.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - start
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    frame.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
end

local dragBar = Instance.new("Frame", main)
dragBar.Size = UDim2.new(1,0,0,32)
dragBar.BackgroundTransparency = 1
dragify(dragBar)

-- SIDEBAR
local sidebar = Instance.new("Frame", main)
sidebar.Size = UDim2.new(0,150,1,-20)
sidebar.Position = UDim2.fromOffset(10,10)
sidebar.BackgroundColor3 = Theme.Colors.Sidebar
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0,8)

local layout = Instance.new("UIListLayout", sidebar)
layout.Padding = UDim.new(0,6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local selector = Instance.new("Frame", sidebar)
selector.Size = UDim2.new(0,4,0,30)
selector.BackgroundColor3 = Theme.Colors.Accent
selector.BorderSizePixel = 0
Instance.new("UICorner", selector)

-- PAGE HOLDER
local pages = Instance.new("Frame", main)
pages.Size = UDim2.new(1,-180,1,-40)
pages.Position = UDim2.fromOffset(170,30)
pages.BackgroundTransparency = 1

-- API
local Hub = {}

function Hub:CreateTab(name)
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.new(0.9,0,0,32)
    btn.BackgroundColor3 = Theme.Colors.Element
    btn.Text = name
    btn.TextColor3 = Theme.Colors.SubText
    btn.Font = Theme.Fonts.Main
    btn.TextSize = 13
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn)

    local page = Instance.new("ScrollingFrame", pages)
    page.Size = UDim2.fromScale(1,1)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Theme.Colors.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local list = Instance.new("UIListLayout", page)
    list.Padding = UDim.new(0,8)
    
    -- Padding for the list inside the page
    local pad = Instance.new("UIPadding", page)
    pad.PaddingLeft = UDim.new(0, 5)
    pad.PaddingRight = UDim.new(0, 5)

    btn.MouseButton1Click:Connect(function()
        for _,p in pairs(pages:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end
        for _,b in pairs(sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.Element, TextColor3 = Theme.Colors.SubText}):Play()
            end
        end
        page.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Theme.Colors.Accent, TextColor3 = Color3.new(1,1,1)}):Play()
    end)

    return page
end

-- NEW: SECTION FUNCTION
function Hub:AddSection(parent, text)
    local sectionFrame = Instance.new("Frame", parent)
    sectionFrame.Size = UDim2.new(1, -10, 0, 25)
    sectionFrame.BackgroundTransparency = 1
    
    local label = Instance.new("TextLabel", sectionFrame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text:upper()
    label.TextColor3 = Theme.Colors.SectionText
    label.Font = Theme.Fonts.Bold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    local line = Instance.new("Frame", sectionFrame)
    line.Size = UDim2.new(1, - (label.TextBounds.X + 10), 0, 1)
    line.Position = UDim2.new(0, label.TextBounds.X + 5, 0.5, 0)
    line.BackgroundColor3 = Theme.Colors.SectionText
    line.BackgroundTransparency = 0.7
    line.BorderSizePixel = 0
end

function Hub:AddButton(parent, text, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1,-10,0,38)
    frame.BackgroundColor3 = Theme.Colors.Element
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.fromScale(1,1)
    btn.BackgroundTransparency = 1
    btn.Text = "    "..text
    btn.Font = Theme.Fonts.Main
    btn.TextSize = 14
    btn.TextColor3 = Theme.Colors.Text
    btn.TextXAlignment = Enum.TextXAlignment.Left

    btn.MouseButton1Click:Connect(callback)
    
    -- Hover Effects
    btn.MouseEnter:Connect(function() TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Colors.Element}):Play() end)
end

_G.Hub = Hub -- Make Hub global so ModuleScripts can see it
return Hub

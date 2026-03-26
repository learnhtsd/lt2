local Lib = {}
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

-- [1] ANTI-DUPLICATE
if CoreGui:FindFirstChild("LT2Hub") then
    CoreGui.LT2Hub:Destroy()
end

-- [2] BASE UI SETUP
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner_Main = Instance.new("UICorner")
local MainScale = Instance.new("UIScale")
local Header = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local TabScroll = Instance.new("ScrollingFrame")
local TabUIList = Instance.new("UIListLayout")
local ContentArea = Instance.new("Frame")

local Pages = {}
local TabButtons = {}

ScreenGui.Name = "LT2Hub"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
MainFrame.Size = UDim2.new(0, 400, 0, 450)
MainFrame.ClipsDescendants = true

UICorner_Main.CornerRadius = UDim.new(0, 10)
UICorner_Main.Parent = MainFrame

MainScale.Parent = MainFrame

-- [3] DRAGGING SYSTEM
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then update(input) end
end)

-- [4] HEADER & NAVIGATION SETUP
Header.Name = "Header"
Header.Parent = MainFrame
Header.BackgroundTransparency = 1.000
Header.Size = UDim2.new(1, 0, 0, 45)

Title.Name = "Title"
Title.Parent = Header
Title.BackgroundTransparency = 1.000
Title.Position = UDim2.new(0, 15, 0, 10)
Title.Size = UDim2.new(0, 200, 0, 25)
Title.Font = Enum.Font.GothamBold
Title.Text = "Lumber Tycoon 2 Hub"
Title.TextColor3 = Color3.fromRGB(230, 230, 230)
Title.TextSize = 15.000
Title.TextXAlignment = Enum.TextXAlignment.Left

TabScroll.Name = "TabScroll"
TabScroll.Parent = MainFrame
TabScroll.BackgroundTransparency = 1
TabScroll.Position = UDim2.new(0, 10, 0, 50)
TabScroll.Size = UDim2.new(1, -20, 0, 40)
TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabScroll.ScrollBarThickness = 0
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X

TabUIList.Parent = TabScroll
TabUIList.FillDirection = Enum.FillDirection.Horizontal
TabUIList.Padding = UDim.new(0, 8)
TabUIList.VerticalAlignment = Enum.VerticalAlignment.Center
TabUIList.SortOrder = Enum.SortOrder.LayoutOrder

ContentArea.Name = "ContentArea"
ContentArea.Parent = MainFrame
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.new(0, 0, 0, 100)
ContentArea.Size = UDim2.new(1, 0, 1, -100)

-- [5] EXPORTED FUNCTIONS (THE LIBRARY)

function Lib:ShowPage(name)
    for pageName, frame in pairs(Pages) do
        frame.Visible = (pageName == name)
    end
    for btnName, btn in pairs(TabButtons) do
        if btnName == name then
            btn.BackgroundColor3 = Color3.fromRGB(210, 210, 210)
            btn.BackgroundTransparency = 0
            btn.TextLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
        else
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            btn.BackgroundTransparency = 0.5
            btn.TextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

function Lib:CreateTab(name)
    local Tab = Instance.new("Frame")
    local TabBtn = Instance.new("TextButton")
    local TabCorner = Instance.new("UICorner")
    local Label = Instance.new("TextLabel")
    local TabPadding = Instance.new("UIPadding")

    Tab.Name = name .. "TabFrame"
    Tab.Parent = TabScroll
    Tab.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Tab.BackgroundTransparency = 0.5
    Tab.Size = UDim2.new(0, 0, 0, 32)
    Tab.AutomaticSize = Enum.AutomaticSize.X

    TabCorner.CornerRadius = UDim.new(0, 16)
    TabCorner.Parent = Tab

    Label.Name = "TextLabel"
    Label.Parent = Tab
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 15, 0, 0)
    Label.Size = UDim2.new(0, 0, 1, 0)
    Label.AutomaticSize = Enum.AutomaticSize.X
    Label.Font = Enum.Font.GothamMedium
    Label.Text = name
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 13

    TabPadding.PaddingRight = UDim.new(0, 15)
    TabPadding.Parent = Tab

    TabBtn.Name = "Clicker"
    TabBtn.Parent = Tab
    TabBtn.BackgroundTransparency = 1
    TabBtn.Size = UDim2.new(1, 0, 1, 0)
    TabBtn.Text = ""

    TabButtons[name] = Tab

    local Page = Instance.new("ScrollingFrame")
    Page.Name = name .. "Page"
    Page.Parent = ContentArea
    Page.BackgroundTransparency = 1
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.Visible = false
    Page.ScrollBarThickness = 2
    
    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Page
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.Padding = UDim.new(0, 6)

    Pages[name] = Page

    TabBtn.MouseButton1Click:Connect(function()
        self:ShowPage(name)
    end)
    
    return Page
end

function Lib:CreateButton(parent, name, callback)
    local BtnFrame = Instance.new("TextButton")
    local BtnCorner = Instance.new("UICorner")
    local BtnText = Instance.new("TextLabel")

    BtnFrame.Parent = parent
    BtnFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    BtnFrame.BackgroundTransparency = 0.5
    BtnFrame.Size = UDim2.new(0, 368, 0, 38)
    BtnFrame.AutoButtonColor = true
    BtnFrame.Text = ""

    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = BtnFrame

    BtnText.Parent = BtnFrame
    BtnText.BackgroundTransparency = 1
    BtnText.Position = UDim2.new(0, 12, 0, 0)
    BtnText.Size = UDim2.new(1, -24, 1, 0)
    BtnText.Font = Enum.Font.GothamMedium
    BtnText.Text = name
    BtnText.TextColor3 = Color3.fromRGB(220, 220, 220)
    BtnText.TextSize = 13
    BtnText.TextXAlignment = Enum.TextXAlignment.Left

    BtnFrame.MouseButton1Click:Connect(callback)
end

function Lib:Notify(msg)
    print("[LT2 Hub]: " .. msg)
end

return Lib

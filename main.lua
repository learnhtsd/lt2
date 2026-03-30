-- GitHub Config
local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main"

-- ==========================================
-- UI ENGINE START
-- ==========================================
local Library = {}
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Clean reload
for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "NexusCustomHub" then v:Destroy() end
end

function Library:CreateWindow()
    local Window = {}
    local CurrentTab = nil

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NexusCustomHub"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 550, 0, 350)
    MainFrame.Position = UDim2.new(0.5, -275, 0.5, -175)
    MainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

    -- Sidebar Fixed: Parented directly to MainFrame
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 60, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(21, 21, 26)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 6)
    
    -- Prevents the right side of sidebar from having rounded corners inside the UI
    local SidebarMask = Instance.new("Frame")
    SidebarMask.Size = UDim2.new(0, 10, 1, 0)
    SidebarMask.Position = UDim2.new(1, -10, 0, 0)
    SidebarMask.BackgroundColor3 = Color3.fromRGB(21, 21, 26)
    SidebarMask.BorderSizePixel = 0
    SidebarMask.Parent = Sidebar

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Parent = Sidebar
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarList.Padding = UDim.new(0, 12)
    
    Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 15)

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -70, 1, -20)
    ContentContainer.Position = UDim2.new(0, 70, 0, 10)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Draggable Logic
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    function Window:CreateTab(TabName, IconID)
        local Tab = {}
        
        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name = TabName
        TabBtn.Size = UDim2.new(0, 36, 0, 36)
        TabBtn.Parent = Sidebar
        TabBtn.BorderSizePixel = 0
        
        if IconID == "" or IconID == nil then
            TabBtn.BackgroundTransparency = 0.9
            TabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            TabBtn.BackgroundTransparency = 1
            TabBtn.Image = IconID
        end
        TabBtn.ImageColor3 = Color3.fromRGB(150, 150, 150)
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)

        -- Blue Fill and Outline Animation
        local Stroke = Instance.new("UIStroke")
        Stroke.Parent = TabBtn
        Stroke.Color = Color3.fromRGB(74, 120, 255)
        Stroke.Thickness = 0
        Stroke.Transparency = 1

        local function SetTabVisuals(active)
            local targetThickness = active and 2 or 0
            local targetTransparency = active and 0 or 1
            local targetBgTrans = active and 0.8 or 1
            local targetIconColor = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)

            TweenService:Create(Stroke, TweenInfo.new(0.3), {Thickness = targetThickness, Transparency = targetTransparency}):Play()
            TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = targetBgTrans, ImageColor3 = targetIconColor}):Play()
            if active then TabBtn.BackgroundColor3 = Color3.fromRGB(74, 120, 255) end
        end

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.Visible = false
        TabPage.ScrollBarThickness = 0
        TabPage.Parent = ContentContainer
        Instance.new("UIListLayout", TabPage).Padding = UDim.new(0, 8)

        TabBtn.MouseButton1Click:Connect(function()
            if CurrentTab then
                CurrentTab.SetVisuals(false)
                CurrentTab.Page.Visible = false
            end
            SetTabVisuals(true)
            TabPage.Visible = true
            CurrentTab = {SetVisuals = SetTabVisuals, Page = TabPage}
        end)

        if not CurrentTab then
            SetTabVisuals(true)
            TabPage.Visible = true
            CurrentTab = {SetVisuals = SetTabVisuals, Page = TabPage}
        end

        function Tab:CreateSection(Name)
            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, 0, 0, 30)
            Label.BackgroundTransparency = 1
            Label.Text = Name
            Label.TextColor3 = Color3.fromRGB(255, 255, 255)
            Label.Font = Enum.Font.GothamBold
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = TabPage
        end

        function Tab:CreateAction(Title, ButtonText, Callback)
            local Frame = Instance.new("Frame")
            Frame.Size = UDim2.new(1, -10, 0, 40)
            Frame.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
            Frame.Parent = TabPage
            Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)

            local Lbl = Instance.new("TextLabel")
            Lbl.Size = UDim2.new(0.6, 0, 1, 0)
            Lbl.Position = UDim2.new(0, 15, 0, 0)
            Lbl.BackgroundTransparency = 1
            Lbl.Text = Title
            Lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            Lbl.Font = Enum.Font.GothamMedium
            Lbl.TextSize = 13
            Lbl.TextXAlignment = Enum.TextXAlignment.Left
            Lbl.Parent = Frame

            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(0, 75, 0, 26)
            Btn.AnchorPoint = Vector2.new(1, 0.5)
            Btn.Position = UDim2.new(1, -15, 0.5, 0)
            Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
            Btn.Text = ButtonText
            Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Btn.Font = Enum.Font.GothamBold
            Btn.TextSize = 12
            Btn.Parent = Frame
            Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4)
            Btn.MouseButton1Click:Connect(Callback)
        end

        return Tab
    end
    return Window
end

-- ==========================================
-- LOAD TABS & MODULES
-- ==========================================
local Hub = Library:CreateWindow()
local Home = Hub:CreateTab("Home", "")
local Player = Hub:CreateTab("Player", "")
local World = Hub:CreateTab("World", "")
local Teleport = Hub:CreateTab("Teleport", "")

local function LoadModule(name)
    local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s", User, Repo, Branch, name, tick())
    local s, code = pcall(function() return game:HttpGet(url) end)
    if s and code then
        local f = loadstring(code)
        if f then return f() end
    end
end

local Movement = LoadModule("PlayerMovement")
if Movement then Movement.Init(Player) end

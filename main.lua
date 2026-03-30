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

-- Destroy old instances for clean reloading
for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "NexusCustomHub" then v:Destroy() end
end

function Library:CreateWindow()
    local Window = {}
    local CurrentTab = nil

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NexusCustomHub"
    ScreenGui.Parent = CoreGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 550, 0, 350)
    MainFrame.Position = UDim2.new(0.5, -275, 0.5, -175)
    MainFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 50, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(21, 21, 26)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 6)
    
    local SideBlock = Instance.new("Frame")
    SideBlock.Size = UDim2.new(0, 10, 1, 0)
    SideBlock.Position = UDim2.new(1, -10, 0, 0)
    SideBlock.BackgroundColor3 = Color3.fromRGB(21, 21, 26)
    SideBlock.BorderSizePixel = 0
    SideBlock.Parent = Sidebar

    -- NEW: Container specifically for the tabs
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, 0, 1, 0)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = Sidebar

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Parent = TabContainer -- Applied to TabContainer
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.VerticalAlignment = Enum.VerticalAlignment.Top
    SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarList.Padding = UDim.new(0, 15) 
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = TabContainer -- Applied to TabContainer
    UIPadding.PaddingTop = UDim.new(0, 20)

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -60, 1, -20)
    ContentContainer.Position = UDim2.new(0, 60, 0, 10)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Make Window Draggable
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Tab API
    function Window:CreateTab(TabName, IconID)
        local Tab = {}
        
        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name = TabName
        TabBtn.Size = UDim2.new(0, 32, 0, 32)
        TabBtn.Parent = TabContainer -- Parented to the new TabContainer
        
        if IconID == nil or IconID == "" then
            TabBtn.BackgroundTransparency = 0.85
            TabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)
        else
            TabBtn.BackgroundTransparency = 1
            TabBtn.Image = IconID
        end
        TabBtn.ImageColor3 = Color3.fromRGB(150, 150, 150)

        -- Animated Outline (UIStroke) instead of a line
        local TabStroke = Instance.new("UIStroke")
        TabStroke.Parent = TabBtn
        TabStroke.Color = Color3.fromRGB(74, 120, 255)
        TabStroke.Thickness = 0
        TabStroke.Transparency = 1
        TabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- Tweens for the outline animation
        local TweenIn = TweenService:Create(TabStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Thickness = 2, Transparency = 0})
        local TweenOut = TweenService:Create(TabStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Thickness = 0, Transparency = 1})

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 2
        TabPage.BorderSizePixel = 0
        TabPage.Visible = false
        TabPage.Parent = ContentContainer

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = TabPage
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 8)

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y)
        end)

        TabBtn.MouseButton1Click:Connect(function()
            if CurrentTab then
                CurrentTab.TweenOut:Play()
                CurrentTab.Btn.ImageColor3 = Color3.fromRGB(150, 150, 150)
                CurrentTab.Page.Visible = false
            end
            TweenIn:Play()
            TabBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, TweenOut = TweenOut, Page = TabPage}
        end)

        if not CurrentTab then
            TabBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
            TweenIn:Play()
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, TweenOut = TweenOut, Page = TabPage}
        end

        function Tab:CreateSection(Name)
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Size = UDim2.new(1, 0, 0, 30)
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Text = Name
            SectionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            SectionLabel.Font = Enum.Font.GothamBold
            SectionLabel.TextSize = 14
            SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
            SectionLabel.Parent = TabPage
        end

        function Tab:CreateAction(Title, ButtonText, Callback)
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size = UDim2.new(1, -10, 0, 40)
            ActionFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
            ActionFrame.BorderSizePixel = 0
            ActionFrame.Parent = TabPage
            Instance.new("UICorner", ActionFrame).CornerRadius = UDim.new(0, 6)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
            TitleLabel.Position = UDim2.new(0, 15, 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text = Title
            TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            TitleLabel.Font = Enum.Font.GothamMedium
            TitleLabel.TextSize = 13
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.Parent = ActionFrame

            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size = UDim2.new(0, 70, 0, 26)
            
            -- FIX: Using AnchorPoint to keep it perfectly aligned to the right edge
            ActionBtn.AnchorPoint = Vector2.new(1, 0.5)
            ActionBtn.Position = UDim2.new(1, -15, 0.5, 0) 
            
            ActionBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
            ActionBtn.Text = ButtonText
            ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            ActionBtn.Font = Enum.Font.GothamBold
            ActionBtn.TextSize = 12
            ActionBtn.Parent = ActionFrame
            Instance.new("UICorner", ActionBtn).CornerRadius = UDim.new(0, 4)

            ActionBtn.MouseButton1Click:Connect(Callback)
        end

        return Tab
    end
    return Window
end

-- ==========================================
-- SCRIPT EXECUTION & MODULE LOADING
-- ==========================================
local HubWindow = Library:CreateWindow()

-- Create the 4 tabs with blank icons
local HomeTab = HubWindow:CreateTab("Home", "")
local PlayerTab = HubWindow:CreateTab("Player", "")
local WorldTab = HubWindow:CreateTab("World", "")
local TeleportTab = HubWindow:CreateTab("Teleport", "")

local function LoadModule(ModuleName)
    local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s", 
        User, Repo, Branch, ModuleName, tick())
    
    local success, code = pcall(function() return game:HttpGet(URL) end)
    if success and code then
        local func = loadstring(code)
        if func then return func() end
    end
    warn("Failed to load module: " .. ModuleName)
end

-- Load the Movement Module and assign it SPECIFICALLY to the PlayerTab
local MovementModule = LoadModule("PlayerMovement")
if MovementModule and MovementModule.Init then
    MovementModule.Init(PlayerTab)
end

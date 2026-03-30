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

    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, 0, 1, 0)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = Sidebar

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Parent = TabContainer
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarList.Padding = UDim.new(0, 15) 
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = TabContainer
    UIPadding.PaddingTop = UDim.new(0, 20)

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -65, 1, -20)
    ContentContainer.Position = UDim2.new(0, 60, 0, 10)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    -- Draggable Logic
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
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

    function Window:CreateTab(TabName, IconID)
        local Tab = {}
        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name = TabName
        TabBtn.Size = UDim2.new(0, 32, 0, 32)
        TabBtn.Parent = TabContainer
        TabBtn.BackgroundTransparency = 0.85
        TabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 2
        TabPage.BorderSizePixel = 0
        TabPage.Visible = false
        TabPage.Parent = ContentContainer

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = TabPage
        PageLayout.Padding = UDim.new(0, 8)

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y)
        end)

        TabBtn.MouseButton1Click:Connect(function()
            if CurrentTab then CurrentTab.Page.Visible = false end
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, Page = TabPage}
        end)

        if not CurrentTab then TabPage.Visible = true; CurrentTab = {Btn = TabBtn, Page = TabPage} end

        -- TOGGLE WITH VISUAL FEEDBACK
        function Tab:CreateToggle(Title, Default, Callback)
            local Toggled = Default
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size = UDim2.new(1, -10, 0, 40)
            ActionFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
            ActionFrame.Parent = TabPage
            Instance.new("UICorner", ActionFrame)

            local Label = Instance.new("TextLabel")
            Label.Text = Title
            Label.Size = UDim2.new(0.5, 0, 1, 0)
            Label.Position = UDim2.new(0, 15, 0, 0)
            Label.TextColor3 = Color3.fromRGB(220, 220, 220)
            Label.BackgroundTransparency = 1
            Label.Font = Enum.Font.GothamMedium
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = ActionFrame

            local StatusBtn = Instance.new("TextButton")
            StatusBtn.Size = UDim2.new(0, 40, 0, 20)
            StatusBtn.AnchorPoint = Vector2.new(1, 0.5)
            StatusBtn.Position = UDim2.new(1, -15, 0.5, 0)
            StatusBtn.Text = ""
            StatusBtn.BackgroundColor3 = Toggled and Color3.fromRGB(74, 120, 255) or Color3.fromRGB(50, 50, 58)
            StatusBtn.Parent = ActionFrame
            Instance.new("UICorner", StatusBtn).CornerRadius = UDim.new(0, 10)

            StatusBtn.MouseButton1Click:Connect(function()
                Toggled = not Toggled
                TweenService:Create(StatusBtn, TweenInfo.new(0.2), {BackgroundColor3 = Toggled and Color3.fromRGB(74, 120, 255) or Color3.fromRGB(50, 50, 58)}):Play()
                Callback(Toggled)
            end)
        end

        -- SLIDER
        function Tab:CreateSlider(Title, Min, Max, Default, Callback)
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size = UDim2.new(1, -10, 0, 50)
            ActionFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
            ActionFrame.Parent = TabPage
            Instance.new("UICorner", ActionFrame)

            local Label = Instance.new("TextLabel")
            Label.Text = Title .. ": " .. Default
            Label.Size = UDim2.new(1, 0, 0, 25)
            Label.Position = UDim2.new(0, 15, 0, 0)
            Label.TextColor3 = Color3.fromRGB(200, 200, 200)
            Label.BackgroundTransparency = 1
            Label.Font = Enum.Font.GothamMedium
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = ActionFrame

            local SliderBack = Instance.new("Frame")
            SliderBack.Size = UDim2.new(1, -30, 0, 4)
            SliderBack.Position = UDim2.new(0, 15, 0, 35)
            SliderBack.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
            SliderBack.Parent = ActionFrame

            local SliderFill = Instance.new("Frame")
            SliderFill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = Color3.fromRGB(74, 120, 255)
            SliderFill.BorderSizePixel = 0
            SliderFill.Parent = SliderBack

            local function UpdateSlider()
                local MousePos = UserInputService:GetMouseLocation().X
                local RelativePos = math.clamp((MousePos - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X, 0, 1)
                local Value = math.floor(Min + (Max - Min) * RelativePos)
                SliderFill.Size = UDim2.new(RelativePos, 0, 1, 0)
                Label.Text = Title .. ": " .. Value
                Callback(Value)
            end

            SliderBack.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local connection
                    connection = UserInputService.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider() end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then connection:Disconnect() end
                    end)
                    UpdateSlider()
                end
            end)
        end

        -- KEYBIND
        function Tab:CreateKeybind(Title, DefaultKey, Callback)
            local CurrentKey = DefaultKey.Name
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size = UDim2.new(1, -10, 0, 40)
            ActionFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
            ActionFrame.Parent = TabPage
            Instance.new("UICorner", ActionFrame)

            local Label = Instance.new("TextLabel")
            Label.Text = Title
            Label.Size = UDim2.new(0.5, 0, 1, 0)
            Label.Position = UDim2.new(0, 15, 0, 0)
            Label.TextColor3 = Color3.fromRGB(220, 220, 220)
            Label.BackgroundTransparency = 1
            Label.Font = Enum.Font.GothamMedium
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.Parent = ActionFrame

            local BindBtn = Instance.new("TextButton")
            BindBtn.Size = UDim2.new(0, 80, 0, 26)
            BindBtn.AnchorPoint = Vector2.new(1, 0.5)
            BindBtn.Position = UDim2.new(1, -15, 0.5, 0)
            BindBtn.Text = CurrentKey
            BindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
            BindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            BindBtn.Font = Enum.Font.GothamBold
            BindBtn.Parent = ActionFrame
            Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 4)

            BindBtn.MouseButton1Click:Connect(function()
                BindBtn.Text = "..."
                local connection
                connection = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        CurrentKey = input.KeyCode.Name
                        BindBtn.Text = CurrentKey
                        connection:Disconnect()
                    end
                end)
            end)

            UserInputService.InputBegan:Connect(function(input, gpe)
                if not gpe and input.KeyCode.Name == CurrentKey then
                    Callback()
                end
            end)
        end

        function Tab:CreateAction(Title, ButtonText, Callback)
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size = UDim2.new(1, -10, 0, 40)
            ActionFrame.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
            ActionFrame.Parent = TabPage
            Instance.new("UICorner", ActionFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
            TitleLabel.Position = UDim2.new(0, 15, 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text = Title
            TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            TitleLabel.Font = Enum.Font.GothamMedium
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.Parent = ActionFrame

            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size = UDim2.new(0, 70, 0, 26)
            ActionBtn.AnchorPoint = Vector2.new(1, 0.5)
            ActionBtn.Position = UDim2.new(1, -15, 0.5, 0) 
            ActionBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
            ActionBtn.Text = ButtonText
            ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            ActionBtn.Font = Enum.Font.GothamBold
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

local MovementModule = LoadModule("PlayerMovement")
if MovementModule and MovementModule.Init then
    MovementModule.Init(PlayerTab)
end

local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main" 
local Version = "v0.0.012"

-- ==========================================
-- UI ENGINE START
-- ==========================================
local Library = {}
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 50, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 6)

    local SideBlock = Instance.new("Frame")
    SideBlock.Size = UDim2.new(0, 10, 1, 0)
    SideBlock.Position = UDim2.new(1, -10, 0, 0)
    SideBlock.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
    SideBlock.BorderSizePixel = 0
    SideBlock.Parent = Sidebar

    local HeaderTitle = Instance.new("TextLabel")
    HeaderTitle.Size = UDim2.new(1, -75, 0, 30)
    HeaderTitle.Position = UDim2.new(0, 65, 0, 10)
    HeaderTitle.BackgroundTransparency = 1
    -- Added Version here
    HeaderTitle.Text = "<b>Lumber Tycoon 2</b> <font color=\"#4a78ff\">Hub</font> <font color=\"#555555\" size=\"12\">" .. Version .. "</font>"
    HeaderTitle.RichText = true
    HeaderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    HeaderTitle.Font = Enum.Font.GothamMedium
    HeaderTitle.TextSize = 16
    HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
    HeaderTitle.Parent = MainFrame

    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, 0, 1, 0)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = Sidebar

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Parent = TabContainer
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.VerticalAlignment = Enum.VerticalAlignment.Top
    SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarList.Padding = UDim.new(0, 15) 

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.Parent = TabContainer
    SidebarPadding.PaddingTop = UDim.new(0, 20)

    -- Content container handles the overall clipping
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -80, 1, -60)
    ContentContainer.Position = UDim2.new(0, 65, 0, 45)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.ClipsDescendants = true -- KEEP THIS TRUE
    ContentContainer.Parent = MainFrame

    -- Draggable
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    function Window:CreateTab(TabName)
        local Tab = {}

        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name = TabName
        TabBtn.Size = UDim2.new(0, 32, 0, 32)
        TabBtn.Parent = TabContainer
        TabBtn.BackgroundColor3 = Color3.fromRGB(74, 120, 255)
        TabBtn.BackgroundTransparency = 1
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)

        local FallbackText = Instance.new("TextLabel", TabBtn)
        FallbackText.Size = UDim2.new(1, 0, 1, 0)
        FallbackText.BackgroundTransparency = 1
        FallbackText.Text = string.sub(TabName, 1, 1):upper()
        FallbackText.TextColor3 = Color3.fromRGB(120, 120, 130)
        FallbackText.Font = Enum.Font.GothamBold
        FallbackText.TextSize = 14
        FallbackText.Name = "TabIconText"

        local TweenIn = TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85})
        local TweenOut = TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 1})

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 0 
        TabPage.BorderSizePixel = 0
        TabPage.Visible = false
        TabPage.Parent = ContentContainer
        TabPage.ClipsDescendants = true -- Keep content inside the window!

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = TabPage
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 6) 

        -- THE FIX: UIPadding inside the scrolling frame
        -- This gives the 1px UIStroke room to exist without being clipped by the edge
        local PagePadding = Instance.new("UIPadding")
        PagePadding.Parent = TabPage
        PagePadding.PaddingLeft = UDim.new(0, 2)
        PagePadding.PaddingRight = UDim.new(0, 8)
        PagePadding.PaddingTop = UDim.new(0, 2)
        PagePadding.PaddingBottom = UDim.new(0, 20) -- Massive bottom padding to prevent cutoff

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 25)
        end)

        TabBtn.MouseButton1Click:Connect(function()
            if CurrentTab then
                CurrentTab.TweenOut:Play()
                CurrentTab.Btn.TabIconText.TextColor3 = Color3.fromRGB(120, 120, 130)
                CurrentTab.Page.Visible = false
            end
            TweenIn:Play()
            FallbackText.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, TweenOut = TweenOut, Page = TabPage}
        end)

        if not CurrentTab then
            TweenIn:Play()
            FallbackText.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, TweenOut = TweenOut, Page = TabPage}
        end

        local function AddDepthStroke(frame)
            local Stroke = Instance.new("UIStroke")
            Stroke.Parent = frame
            Stroke.Color = Color3.fromRGB(40, 40, 48)
            Stroke.Thickness = 1
            Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        end

        function Tab:CreateSection(Name)
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Size = UDim2.new(1, 0, 0, 20)
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Text = Name:upper()
            SectionLabel.TextColor3 = Color3.fromRGB(74, 120, 255)
            SectionLabel.Font = Enum.Font.GothamBold
            SectionLabel.TextSize = 11
            SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
            SectionLabel.Parent = TabPage
        end

        function Tab:CreateAction(Title, ButtonText, Callback)
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size = UDim2.new(1, 0, 0, 28)
            ActionFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
            ActionFrame.Parent = TabPage
            Instance.new("UICorner", ActionFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(ActionFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
            TitleLabel.Position = UDim2.new(0, 10, 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text = Title
            TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            TitleLabel.Font = Enum.Font.GothamMedium
            TitleLabel.TextSize = 12
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.Parent = ActionFrame

            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size = UDim2.new(0, 70, 0, 20)
            ActionBtn.AnchorPoint = Vector2.new(1, 0.5)
            ActionBtn.Position = UDim2.new(1, -8, 0.5, 0) 
            ActionBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
            ActionBtn.Text = ButtonText
            ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            ActionBtn.Font = Enum.Font.GothamBold
            ActionBtn.TextSize = 11
            ActionBtn.Parent = ActionFrame
            Instance.new("UICorner", ActionBtn).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(ActionBtn)
            ActionBtn.MouseButton1Click:Connect(Callback)
        end

        function Tab:CreateToggle(Title, Default, Callback)
            local Toggled = Default
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, 0, 0, 28)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
            ToggleFrame.Parent = TabPage
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(ToggleFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
            TitleLabel.Position = UDim2.new(0, 10, 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text = Title
            TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            TitleLabel.Font = Enum.Font.GothamMedium
            TitleLabel.TextSize = 12
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.Parent = ToggleFrame

            local ToggleBG = Instance.new("TextButton")
            ToggleBG.Size = UDim2.new(0, 34, 0, 18)
            ToggleBG.AnchorPoint = Vector2.new(1, 0.5)
            ToggleBG.Position = UDim2.new(1, -8, 0.5, 0)
            ToggleBG.BackgroundColor3 = Toggled and Color3.fromRGB(74, 120, 255) or Color3.fromRGB(35, 35, 42)
            ToggleBG.Text = ""
            ToggleBG.Parent = ToggleFrame
            Instance.new("UICorner", ToggleBG).CornerRadius = UDim.new(1, 0)
            AddDepthStroke(ToggleBG)

            local ToggleDot = Instance.new("Frame")
            ToggleDot.Size = UDim2.new(0, 12, 0, 12)
            ToggleDot.Position = Toggled and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            ToggleDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ToggleDot.Parent = ToggleBG
            Instance.new("UICorner", ToggleDot).CornerRadius = UDim.new(1, 0)

            ToggleBG.MouseButton1Click:Connect(function()
                Toggled = not Toggled
                local targetPos = Toggled and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
                local targetCol = Toggled and Color3.fromRGB(74, 120, 255) or Color3.fromRGB(35, 35, 42)
                TweenService:Create(ToggleDot, TweenInfo.new(0.2), {Position = targetPos}):Play()
                TweenService:Create(ToggleBG, TweenInfo.new(0.2), {BackgroundColor3 = targetCol}):Play()
                Callback(Toggled)
            end)
        end

        function Tab:CreateSlider(Title, Min, Max, Default, Callback)
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size = UDim2.new(1, 0, 0, 38)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
            SliderFrame.Parent = TabPage
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(SliderFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size = UDim2.new(1, -30, 0, 20)
            TitleLabel.Position = UDim2.new(0, 10, 0, 4)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text = Title .. ": " .. Default
            TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            TitleLabel.Font = Enum.Font.GothamMedium
            TitleLabel.TextSize = 12
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.Parent = SliderFrame

            local SliderBG = Instance.new("Frame")
            SliderBG.Size = UDim2.new(1, -20, 0, 4)
            SliderBG.Position = UDim2.new(0, 10, 0, 26)
            SliderBG.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
            SliderBG.Parent = SliderFrame
            Instance.new("UICorner", SliderBG)

            local SliderFill = Instance.new("Frame")
            SliderFill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = Color3.fromRGB(74, 120, 255)
            SliderFill.BorderSizePixel = 0
            SliderFill.Parent = SliderBG
            Instance.new("UICorner", SliderFill)

            local SliderBtn = Instance.new("TextButton")
            SliderBtn.Size = UDim2.new(1, 0, 1, 0)
            SliderBtn.BackgroundTransparency = 1
            SliderBtn.Text = ""
            SliderBtn.Parent = SliderBG

            local function UpdateSlider()
                local mousePos = UserInputService:GetMouseLocation().X
                local barPos = SliderBG.AbsolutePosition.X
                local barWidth = SliderBG.AbsoluteSize.X
                local percentage = math.clamp((mousePos - barPos) / barWidth, 0, 1)
                local value = math.floor(Min + (Max - Min) * percentage)
                SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
                TitleLabel.Text = Title .. ": " .. value
                Callback(value)
            end

            local sliding = false
            SliderBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider() end
            end)
        end

        function Tab:CreateKeybind(Title, Default, Callback)
            local KeyName = (typeof(Default) == "EnumItem") and Default.Name or Default.UserInputType.Name
            local KeybindFrame = Instance.new("Frame")
            KeybindFrame.Size = UDim2.new(1, 0, 0, 28)
            KeybindFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
            KeybindFrame.Parent = TabPage
            Instance.new("UICorner", KeybindFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(KeybindFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
            TitleLabel.Position = UDim2.new(0, 10, 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text = Title
            TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            TitleLabel.Font = Enum.Font.GothamMedium
            TitleLabel.TextSize = 12
            TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
            TitleLabel.Parent = KeybindFrame

            local BindBtn = Instance.new("TextButton")
            BindBtn.Size = UDim2.new(0, 70, 0, 20)
            BindBtn.AnchorPoint = Vector2.new(1, 0.5)
            BindBtn.Position = UDim2.new(1, -8, 0.5, 0) 
            BindBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
            BindBtn.Text = KeyName
            BindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            BindBtn.Font = Enum.Font.GothamBold
            BindBtn.TextSize = 11
            BindBtn.Parent = KeybindFrame
            Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(BindBtn)

            BindBtn.MouseButton1Click:Connect(function()
                BindBtn.Text = "..."
                local connection
                connection = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        KeyName = input.KeyCode.Name
                        BindBtn.Text = KeyName
                        connection:Disconnect()
                    elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                        KeyName = input.UserInputType.Name
                        BindBtn.Text = KeyName
                        connection:Disconnect()
                    end
                end)
            end)

            UserInputService.InputBegan:Connect(function(input, processed)
                if not processed then
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == KeyName then
                        Callback()
                    elseif input.UserInputType.Name == KeyName then
                        Callback()
                    end
                end
            end)
        end
        function Tab:CreateDropdown(Title, Options, Default, Callback)
                    local Dropdown = {
                        Open = false,
                        Selected = Default or "Select..."
                    }

                    local DropdownFrame = Instance.new("Frame")
                    DropdownFrame.Size = UDim2.new(1, 0, 0, 28) -- Closed height
                    DropdownFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
                    DropdownFrame.ClipsDescendants = true
                    DropdownFrame.Parent = TabPage
                    Instance.new("UICorner", DropdownFrame).CornerRadius = UDim.new(0, 6)
                    AddDepthStroke(DropdownFrame)

                    local Header = Instance.new("TextButton")
                    Header.Size = UDim2.new(1, 0, 0, 28)
                    Header.BackgroundTransparency = 1
                    Header.Text = ""
                    Header.Parent = DropdownFrame

                    local TitleLabel = Instance.new("TextLabel")
                    TitleLabel.Size = UDim2.new(0.6, 0, 1, 0)
                    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
                    TitleLabel.BackgroundTransparency = 1
                    TitleLabel.Text = Title
                    TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
                    TitleLabel.Font = Enum.Font.GothamMedium
                    TitleLabel.TextSize = 12
                    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
                    TitleLabel.Parent = Header

                    local SelectedLabel = Instance.new("TextLabel")
                    SelectedLabel.Size = UDim2.new(0.4, -25, 1, 0)
                    SelectedLabel.Position = UDim2.new(1, -10, 0, 0)
                    SelectedLabel.AnchorPoint = Vector2.new(1, 0)
                    SelectedLabel.BackgroundTransparency = 1
                    SelectedLabel.Text = Dropdown.Selected
                    SelectedLabel.TextColor3 = Color3.fromRGB(74, 120, 255)
                    SelectedLabel.Font = Enum.Font.GothamBold
                    SelectedLabel.TextSize = 11
                    SelectedLabel.TextXAlignment = Enum.TextXAlignment.Right
                    SelectedLabel.Parent = Header

                    local OptionHolder = Instance.new("Frame")
                    OptionHolder.Size = UDim2.new(1, -10, 0, 0)
                    OptionHolder.Position = UDim2.new(0, 5, 0, 30)
                    OptionHolder.BackgroundTransparency = 1
                    OptionHolder.Parent = DropdownFrame

                    local Layout = Instance.new("UIListLayout", OptionHolder)
                    Layout.Padding = UDim.new(0, 3)

                    local function Refresh()
                        for _, child in pairs(OptionHolder:GetChildren()) do
                            if child:IsA("TextButton") then child:Destroy() end
                        end

                        for _, opt in pairs(Options) do
                            local OptBtn = Instance.new("TextButton")
                            OptBtn.Size = UDim2.new(1, 0, 0, 22)
                            OptBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                            OptBtn.Text = opt
                            OptBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
                            OptBtn.Font = Enum.Font.Gotham
                            OptBtn.TextSize = 11
                            OptBtn.Parent = OptionHolder
                            Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)

                            OptBtn.MouseButton1Click:Connect(function()
                                Dropdown.Selected = opt
                                SelectedLabel.Text = opt
                                Dropdown.Open = false
                                TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 28)}):Play()
                                Callback(opt)
                            end)
                        end
                    end

                    Header.MouseButton1Click:Connect(function()
                        Dropdown.Open = not Dropdown.Open
                        local targetHeight = Dropdown.Open and (Layout.AbsoluteContentSize.Y + 35) or 28
                        TweenService:Create(DropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
                    end)

                    Refresh()
                end
            return Tab
        end
    return Window
end

-- ==========================================
-- SCRIPT EXECUTION
-- ==========================================
local HubWindow = Library:CreateWindow()

local HomeTab     = HubWindow:CreateTab("Home")
local PlayerTab   = HubWindow:CreateTab("Player")
local WorldTab    = HubWindow:CreateTab("World")
local TeleportTab = HubWindow:CreateTab("Teleport")
local WoodTab    = HubWindow:CreateTab("Wood")
local BuildTab    = HubWindow:CreateTab("Build")
local SettingsTab = HubWindow:CreateTab("Settings")

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
if MovementModule and MovementModule.Init then MovementModule.Init(PlayerTab) end 

local TeleportModule = LoadModule("Teleport")
if TeleportModule and TeleportModule.Init then TeleportModule.Init(TeleportTab) end

local GhostModule = LoadModule("GhostSuite")
if GhostModule and GhostModule.Init then GhostModule.Init(BuildTab) end

local SettingsModule = LoadModule("Settings")
if SettingsModule and SettingsModule.Init then  
    SettingsModule.Init(SettingsTab, {User = User, Repo = Repo, Branch = Branch}) 
end

local GetWoodModule = LoadModule("GetWood")
if GetWoodModule and GetWoodModule.Init then GetWoodModule.Init(WoodTab) end 

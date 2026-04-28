local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main"
local Version = "v0.0.185"

-- ============================================================
-- ██████╗  ██████╗ ███╗   ██╗███████╗██╗ ██████╗
-- ██╔════╝ ██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
-- ██║      ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
-- ██║      ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
-- ╚██████╗ ╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
--  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
-- ============================================================
-- EASY CONFIGURATION — edit this block only
-- ============================================================

local Config = {

    -- ── WINDOW SIZE ──────────────────────────────────────────
    -- Controls the overall menu frame dimensions in pixels.
    Window = {
        Width  = 500,   -- total menu width
        Height = 300,   -- total menu height
        SidebarWidth = 35,  -- icon sidebar width
    },

    -- ── ELEMENT SCALE ─────────────────────────────────────────
    -- Scales the *contents* of the menu independently of the window.
    -- Elements: row heights, font sizes, padding, toggle/button sizes.
    -- 1.0 = default  |  0.75 = compact  |  1.25 = large
    Elements = {
        Scale = 0.75,
    },

    -- ── COLOR THEME ───────────────────────────────────────────
    -- Swap any colour below to retheme the entire UI instantly.
    Theme = {
        Accent          = Color3.fromRGB(74,  120, 255),  -- blue highlights / active
        Background      = Color3.fromRGB(18,  18,  22),   -- main window background
        Surface         = Color3.fromRGB(24,  24,  29),   -- element cards / dropdowns
        SurfaceDeep     = Color3.fromRGB(35,  35,  42),   -- inset areas / track bg
        Sidebar         = Color3.fromRGB(14,  14,  17),   -- sidebar background
        Stroke          = Color3.fromRGB(40,  40,  48),   -- border / depth strokes
        TextPrimary     = Color3.fromRGB(220, 220, 220),  -- element title text
        TextSecondary   = Color3.fromRGB(120, 120, 130),  -- muted / icon text
        TextDark        = Color3.fromRGB(180, 180, 180),  -- description text
        TextWhite       = Color3.fromRGB(255, 255, 255),  -- header / active labels
        Success         = Color3.fromRGB(45,  160, 75),   -- confirm-action green
        Warning         = Color3.fromRGB(190, 120, 15),   -- secure-action amber
        NotifBackground = Color3.fromRGB(24,  24,  29),   -- notification card bg
    },
}

-- ============================================================
-- SCALE HELPERS  (do not edit — derived from Config above)
-- ES()  = Element Scale  — use for heights, padding, offsets
-- FS()  = Font Scale     — clamped so text never becomes unreadable
-- ============================================================
local function ES(n) return math.round(n * Config.Elements.Scale) end
local function FS(n) return math.max(8, math.round(n * Config.Elements.Scale)) end
local T = Config.Theme   -- shorthand: T.Accent, T.Surface, etc.
local W = Config.Window  -- shorthand: W.Width, W.Height, etc.

-- ============================================================
-- UI ENGINE
-- ============================================================
local Library = {}
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "DynxeLT2Hub" then v:Destroy() end
end

-- ── Image helper (unchanged) ─────────────────────────────────
getgenv().GetImage = function(folder, fileName)
    local localPath       = "Dynxe/Images/" .. folder .. "/" .. fileName
    local folderPath      = "Dynxe/Images/" .. folder
    local placeholderLocal = "Dynxe/Images/Placeholder.png"
    local placeholderUrl  = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/Images/Placeholder.png",
        User, Repo, Branch
    )
    if isfolder and not isfolder("Dynxe")        then makefolder("Dynxe") end
    if isfolder and not isfolder("Dynxe/Images") then makefolder("Dynxe/Images") end
    if folder ~= "" and isfolder and not isfolder(folderPath) then makefolder(folderPath) end
    if not isfile(placeholderLocal) then
        local pOk, pData = pcall(function() return game:HttpGet(placeholderUrl) end)
        if pOk and #pData > 100 then writefile(placeholderLocal, pData) end
    end
    if isfile(localPath) then return getcustomasset(localPath) end
    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/Images/%s/%s",
        User, Repo, Branch, folder, fileName
    )
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if ok and content and not content:find("404: Not Found") and #content > 100 then
        writefile(localPath, content)
        return getcustomasset(localPath)
    else
        warn("Asset Missing: " .. fileName .. " (Using Placeholder from " .. User .. "/" .. Repo .. ")")
        return isfile(placeholderLocal) and getcustomasset(placeholderLocal) or "rbxassetid://6023426923"
    end
end

-- ── Window ───────────────────────────────────────────────────
function Library:CreateWindow()
    local Window     = {}
    local CurrentTab = nil

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name            = "DynxeLT2Hub"
    ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent          = CoreGui

    -- TOOLTIP
    local TooltipGui = Instance.new("TextLabel")
    TooltipGui.Size                = UDim2.new(0, 0, 0, 0)
    TooltipGui.AutomaticSize       = Enum.AutomaticSize.XY
    TooltipGui.BackgroundColor3    = Color3.fromRGB(20, 20, 25)
    TooltipGui.TextColor3          = T.TextDark
    TooltipGui.Font                = Enum.Font.GothamMedium
    TooltipGui.TextSize            = FS(11)
    TooltipGui.RichText            = true
    TooltipGui.Visible             = false
    TooltipGui.ZIndex              = 100
    TooltipGui.Parent              = ScreenGui
    local TTPad = Instance.new("UIPadding", TooltipGui)
    TTPad.PaddingTop    = UDim.new(0, ES(6))
    TTPad.PaddingBottom = UDim.new(0, ES(6))
    TTPad.PaddingLeft   = UDim.new(0, ES(8))
    TTPad.PaddingRight  = UDim.new(0, ES(8))
    Instance.new("UICorner", TooltipGui).CornerRadius = UDim.new(0, 4)
    local TTStroke = Instance.new("UIStroke", TooltipGui)
    TTStroke.Color     = Color3.fromRGB(150, 150, 150)
    TTStroke.Thickness = 1

    function Library.ShowTooltip(text)
        TooltipGui.Text    = text
        TooltipGui.Visible = true
    end
    function Library.HideTooltip()
        TooltipGui.Visible = false
    end
    UserInputService.InputChanged:Connect(function(input)
        if TooltipGui.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then
            TooltipGui.Position = UDim2.new(0, math.round(input.Position.X + 12), 0, math.round(input.Position.Y + 12))
        end
    end)

    -- TOOLTIP ATTACHMENT HELPER
    local function AttachTooltip(TitleLabel, ElementTable)
        function ElementTable:AddTooltip(text)
            local InfoIcon = Instance.new("TextLabel")
            InfoIcon.Size               = UDim2.new(0, ES(16), 0, ES(16))
            InfoIcon.AnchorPoint        = Vector2.new(0, 0.5)
            InfoIcon.BackgroundTransparency = 1
            InfoIcon.Text               = "(?)"
            InfoIcon.TextColor3         = T.TextSecondary
            InfoIcon.Font               = Enum.Font.Gotham
            InfoIcon.TextSize           = FS(11)
            InfoIcon.Parent             = TitleLabel
            local function updatePos()
                InfoIcon.Position = UDim2.new(0, TitleLabel.TextBounds.X + 6, 0.5, 0)
            end
            TitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(updatePos)
            updatePos()
            InfoIcon.MouseEnter:Connect(function()
                InfoIcon.TextColor3 = T.Accent
                Library.ShowTooltip(text)
            end)
            InfoIcon.MouseLeave:Connect(function()
                InfoIcon.TextColor3 = T.TextSecondary
                Library.HideTooltip()
            end)
            return ElementTable
        end
        return ElementTable
    end

    -- MAIN FRAME
    local MainFrame = Instance.new("Frame")
    MainFrame.Size                 = UDim2.new(0, W.Width, 0, W.Height)
    MainFrame.Position             = UDim2.new(0.5, -math.floor(W.Width/2), 0.5, -math.floor(W.Height/2))
    MainFrame.BackgroundColor3     = T.Background
    MainFrame.BackgroundTransparency = 0.15
    MainFrame.BorderSizePixel      = 0
    MainFrame.ZIndex               = 2
    MainFrame.Parent               = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

    -- SIDEBAR
    local Sidebar = Instance.new("Frame")
    Sidebar.Size             = UDim2.new(0, W.SidebarWidth, 1, 0)
    Sidebar.BackgroundColor3 = T.Sidebar
    Sidebar.BorderSizePixel  = 0
    Sidebar.Parent           = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 6)

    local SideBlock = Instance.new("Frame")
    SideBlock.Size             = UDim2.new(0, 10, 1, 0)
    SideBlock.Position         = UDim2.new(1, -10, 0, 0)
    SideBlock.BackgroundColor3 = T.Sidebar
    SideBlock.BorderSizePixel  = 0
    SideBlock.Parent           = Sidebar

    -- HEADER
    local HeaderTitle = Instance.new("TextLabel")
    HeaderTitle.Size               = UDim2.new(1, -(W.SidebarWidth + 25), 0, 30)
    HeaderTitle.Position           = UDim2.new(0, W.SidebarWidth + 15, 0, 10)
    HeaderTitle.BackgroundTransparency = 1
    HeaderTitle.Text               = "<b>Dynxe</b> <font color=\"#4a78ff\">LT2</font> <font color=\"#555555\" size=\"" .. FS(12) .. "\">" .. Version .. "</font>"
    HeaderTitle.RichText           = true
    HeaderTitle.TextColor3         = T.TextWhite
    HeaderTitle.Font               = Enum.Font.GothamMedium
    HeaderTitle.TextSize           = FS(16)
    HeaderTitle.TextXAlignment     = Enum.TextXAlignment.Left
    HeaderTitle.Parent             = MainFrame

    local ActiveTabLabel = Instance.new("TextLabel")
    ActiveTabLabel.Size            = UDim2.new(0, 150, 0, 30)
    ActiveTabLabel.Position        = UDim2.new(1, -160, 0, 10)
    ActiveTabLabel.BackgroundTransparency = 1
    ActiveTabLabel.Text            = ""
    ActiveTabLabel.TextColor3      = T.Accent
    ActiveTabLabel.Font            = Enum.Font.GothamMedium
    ActiveTabLabel.TextSize        = FS(12)
    ActiveTabLabel.TextXAlignment  = Enum.TextXAlignment.Right
    ActiveTabLabel.Parent          = MainFrame

    -- TAB CONTAINER (inside sidebar)
    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name              = "TabContainer"
    TabContainer.Size              = UDim2.new(1, 0, 1, 0)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ScrollBarThickness = 0
    TabContainer.BorderSizePixel   = 0
    TabContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    TabContainer.Parent            = Sidebar

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Parent             = TabContainer
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.VerticalAlignment  = Enum.VerticalAlignment.Top
    SidebarList.SortOrder          = Enum.SortOrder.LayoutOrder
    SidebarList.Padding            = UDim.new(0, ES(15))

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.Parent     = TabContainer
    SidebarPadding.PaddingTop = UDim.new(0, ES(20))

    SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, SidebarList.AbsoluteContentSize.Y + 30)
    end)

    -- CONTENT AREA
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size              = UDim2.new(1, -(W.SidebarWidth + 30), 1, -60)
    ContentContainer.Position          = UDim2.new(0, W.SidebarWidth + 15, 0, 45)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.ClipsDescendants  = true
    ContentContainer.Parent            = MainFrame

    -- NOTIFICATIONS
    local NotificationContainer = Instance.new("Frame")
    NotificationContainer.Name             = "NotificationContainer"
    NotificationContainer.Size             = UDim2.new(0, 250, 1, -20)
    NotificationContainer.Position         = UDim2.new(1, -260, 0, 10)
    NotificationContainer.BackgroundTransparency = 1
    NotificationContainer.Parent           = ScreenGui

    local NotifList = Instance.new("UIListLayout")
    NotifList.Parent           = NotificationContainer
    NotifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifList.SortOrder        = Enum.SortOrder.LayoutOrder
    NotifList.Padding          = UDim.new(0, 8)

    function Library:Notify(Title, Text, Duration)
        Duration = Duration or 5
        local NotifFrame = Instance.new("Frame")
        NotifFrame.Size             = UDim2.new(1, 0, 0, 0)
        NotifFrame.BackgroundColor3 = T.NotifBackground
        NotifFrame.BorderSizePixel  = 0
        NotifFrame.ClipsDescendants = true
        NotifFrame.Parent           = NotificationContainer
        Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 6)
        local Stroke = Instance.new("UIStroke", NotifFrame)
        Stroke.Color     = T.Accent
        Stroke.Thickness = 1
        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size            = UDim2.new(1, -20, 0, ES(20))
        TitleLabel.Position        = UDim2.new(0, 10, 0, 5)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text            = Title:upper()
        TitleLabel.TextColor3      = T.Accent
        TitleLabel.Font            = Enum.Font.GothamBold
        TitleLabel.TextSize        = FS(12)
        TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
        TitleLabel.Parent          = NotifFrame
        local ContentLabel = Instance.new("TextLabel")
        ContentLabel.Size          = UDim2.new(1, -20, 0, ES(30))
        ContentLabel.Position      = UDim2.new(0, 10, 0, ES(22))
        ContentLabel.BackgroundTransparency = 1
        ContentLabel.Text          = Text
        ContentLabel.TextColor3    = T.TextDark
        ContentLabel.Font          = Enum.Font.Gotham
        ContentLabel.TextSize      = FS(11)
        ContentLabel.TextWrapped   = true
        ContentLabel.TextXAlignment = Enum.TextXAlignment.Left
        ContentLabel.Parent        = NotifFrame
        TweenService:Create(NotifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, ES(60))}):Play()
        task.delay(Duration, function()
            local Tween = TweenService:Create(NotifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
            Tween:Play()
            Tween.Completed:Connect(function() NotifFrame:Destroy() end)
        end)
    end

    -- DRAG
    local dragging, dragStart, startPos = false, nil, nil
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        end
    end)
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local d = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- ── CREATE TAB ───────────────────────────────────────────
    function Window:CreateTab(TabName)
        local Tab = {}

        -- Tab icon button in sidebar
        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name              = TabName
        TabBtn.Size              = UDim2.new(0, ES(32), 0, ES(32))
        TabBtn.Parent            = TabContainer
        TabBtn.BackgroundColor3  = T.Accent
        TabBtn.BackgroundTransparency = 1
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)

        local FallbackText = Instance.new("TextLabel", TabBtn)
        FallbackText.Size              = UDim2.new(1, 0, 1, 0)
        FallbackText.BackgroundTransparency = 1
        FallbackText.Text              = string.sub(TabName, 1, 1):upper()
        FallbackText.TextColor3        = T.TextSecondary
        FallbackText.Font              = Enum.Font.GothamBold
        FallbackText.TextSize          = FS(14)
        FallbackText.Name              = "TabIconText"

        -- icon download (unchanged logic)
        local folderName  = "DynxeLT2"
        local fileName    = TabName .. "_" .. Version:gsub("%.", "") .. ".png"
        local filePath    = folderName .. "/" .. fileName
        local finalAssetUrl = ""
        if isfolder and makefolder and writefile and isfile and getcustomasset then
            if not isfolder(folderName) then makefolder(folderName) end
            if not isfile(filePath) then
                local iconUrl = string.format("https://raw.githubusercontent.com/%s/%s/%s/Icons/%s.png?t=%s", User, Repo, Branch, TabName, tick())
                local ok, imgData = pcall(function() return game:HttpGet(iconUrl) end)
                if ok and imgData and not imgData:match("404: Not Found") then writefile(filePath, imgData) end
            end
            if isfile(filePath) then finalAssetUrl = getcustomasset(filePath) end
        end

        local TabIcon = Instance.new("ImageLabel")
        TabIcon.Size               = UDim2.new(0, ES(20), 0, ES(20))
        TabIcon.Position           = UDim2.new(0.5, -ES(10), 0.5, -ES(10))
        TabIcon.BackgroundTransparency = 1
        TabIcon.Image              = finalAssetUrl
        TabIcon.ImageColor3        = T.TextWhite
        TabIcon.ScaleType          = Enum.ScaleType.Fit
        TabIcon.Name               = "TabIcon"
        TabIcon.Parent             = TabBtn
        if finalAssetUrl ~= "" then FallbackText.Visible = false end

        local TweenIn  = TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85})
        local TweenOut = TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 1})

        -- Tab page (scrolling content)
        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size               = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 0
        TabPage.BorderSizePixel    = 0
        TabPage.Visible            = false
        TabPage.ClipsDescendants   = true
        TabPage.Parent             = ContentContainer
        Tab.Container              = TabPage

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent   = TabPage
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding  = UDim.new(0, ES(6))

        local PagePadding = Instance.new("UIPadding")
        PagePadding.Parent        = TabPage
        PagePadding.PaddingLeft   = UDim.new(0, 2)
        PagePadding.PaddingRight  = UDim.new(0, 8)
        PagePadding.PaddingTop    = UDim.new(0, 2)
        PagePadding.PaddingBottom = UDim.new(0, ES(20))

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 25)
        end)

        local function ActivateTab()
            if CurrentTab then
                CurrentTab.TweenOut:Play()
                CurrentTab.Btn.TabIconText.TextColor3 = T.TextSecondary
                local prev = CurrentTab.Btn:FindFirstChild("TabIcon")
                if prev then prev.ImageColor3 = T.TextSecondary end
                CurrentTab.Page.Visible = false
            end
            TweenIn:Play()
            FallbackText.TextColor3 = T.TextWhite
            TabIcon.ImageColor3     = T.TextWhite
            TabPage.Visible         = true
            ActiveTabLabel.Text     = TabName:upper()
            CurrentTab = {Btn = TabBtn, TweenOut = TweenOut, Page = TabPage}
        end

        TabBtn.MouseButton1Click:Connect(ActivateTab)
        if not CurrentTab then ActivateTab() end

        -- ── SHARED HELPERS ────────────────────────────────────
        local function AddDepthStroke(frame)
            local Stroke = Instance.new("UIStroke")
            Stroke.Parent          = frame
            Stroke.Color           = T.Stroke
            Stroke.Thickness       = 1
            Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        end

        -- ── ROW ───────────────────────────────────────────────
        function Tab:CreateRow()
            local Row = setmetatable({}, {__index = self})
            local RowFrame = Instance.new("Frame")
            RowFrame.Size              = UDim2.new(1, 0, 0, ES(28))
            RowFrame.BackgroundTransparency = 1
            RowFrame.Parent            = self.Container
            local RowLayout = Instance.new("UIListLayout")
            RowLayout.Parent          = RowFrame
            RowLayout.FillDirection   = Enum.FillDirection.Horizontal
            RowLayout.SortOrder       = Enum.SortOrder.LayoutOrder
            RowLayout.Padding         = UDim.new(0, ES(6))
            RowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                RowFrame.Size = UDim2.new(1, 0, 0, RowLayout.AbsoluteContentSize.Y)
            end)
            RowFrame.ChildAdded:Connect(function()
                task.defer(function()
                    local elements = {}
                    for _, v in pairs(RowFrame:GetChildren()) do
                        if v:IsA("GuiObject") and not v:IsA("UIListLayout") then
                            table.insert(elements, v)
                        end
                    end
                    local count = #elements
                    if count > 0 then
                        local totalPadding = (count - 1) * ES(6)
                        for _, v in pairs(elements) do
                            v.Size = UDim2.new(1/count, -totalPadding/count, 0, v.Size.Y.Offset)
                        end
                    end
                end)
            end)
            Row.Container = RowFrame
            return Row
        end

        -- ── SECTION ───────────────────────────────────────────
        function Tab:CreateSection(Name)
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Size              = UDim2.new(1, 0, 0, ES(20))
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Text              = Name:upper()
            SectionLabel.TextColor3        = T.Accent
            SectionLabel.Font              = Enum.Font.GothamBold
            SectionLabel.TextSize          = FS(11)
            SectionLabel.TextXAlignment    = Enum.TextXAlignment.Left
            SectionLabel.Parent            = self.Container
        end

        -- ── ACTION ────────────────────────────────────────────
        function Tab:CreateAction(Title, ButtonText, Callback, Secure)
            local Element     = {}
            Element.Disabled  = false -- Track disabled state
            
            local RowHeight   = ES(28)
            local BtnHeight   = ES(20)
            local BtnWidth    = ES(70)
        
            local ActionFrame = Instance.new("Frame")
            ActionFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            ActionFrame.BackgroundColor3 = T.Surface
            ActionFrame.Parent           = self.Container
            Instance.new("UICorner", ActionFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(ActionFrame)
        
            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.65, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = ActionFrame
        
            if Secure then
                local LockBadge = Instance.new("TextLabel")
                LockBadge.Size             = UDim2.new(0, ES(22), 0, ES(14))
                LockBadge.AnchorPoint      = Vector2.new(0, 0.5)
                LockBadge.BackgroundColor3 = Color3.fromRGB(180, 120, 20)
                LockBadge.BackgroundTransparency = 0.3
                LockBadge.Text             = "🔒"
                LockBadge.TextSize         = FS(9)
                LockBadge.Font             = Enum.Font.Gotham
                LockBadge.TextColor3       = Color3.fromRGB(255, 220, 100)
                LockBadge.Parent           = TitleLabel
                Instance.new("UICorner", LockBadge).CornerRadius = UDim.new(0, 3)
                local function updateBadgePos()
                    LockBadge.Position = UDim2.new(0, TitleLabel.TextBounds.X + 8, 0.5, 0)
                end
                TitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateBadgePos)
                updateBadgePos()
            end
        
            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size             = UDim2.new(0, BtnWidth, 0, BtnHeight)
            ActionBtn.AnchorPoint      = Vector2.new(1, 0.5)
            ActionBtn.Position         = UDim2.new(1, -ES(8), 0.5, 0)
            ActionBtn.BackgroundColor3 = T.SurfaceDeep
            ActionBtn.Text             = ButtonText
            ActionBtn.TextColor3       = T.TextWhite
            ActionBtn.Font             = Enum.Font.GothamBold
            ActionBtn.TextSize         = FS(11)
            ActionBtn.Parent           = ActionFrame
            Instance.new("UICorner", ActionBtn).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(ActionBtn)
        
            -- INTERNAL STATE HELPERS
            local awaitingConfirm = false
            local resetThread     = nil
        
            local function resetBtn()
                awaitingConfirm = false
                TweenService:Create(ActionBtn, TweenInfo.new(0.25), {
                    BackgroundColor3 = Element.Disabled and T.Surface or T.SurfaceDeep,
                    TextTransparency = Element.Disabled and 0.5 or 0
                }):Play()
                ActionBtn.Text      = ButtonText
                ActionBtn.TextColor3 = T.TextWhite
            end
        
            -- PUBLIC METHODS
            function Element:SetText(NewText)
                ButtonText = NewText
                if not awaitingConfirm then
                    ActionBtn.Text = NewText
                end
            end
        
            function Element:SetDisabled(State)
                Element.Disabled = State
                ActionBtn.Active = not State
                
                -- Visual feedback for disabled state
                TweenService:Create(ActionBtn, TweenInfo.new(0.2), {
                    BackgroundTransparency = State and 0.5 or 0,
                    TextTransparency = State and 0.5 or 0,
                    BackgroundColor3 = State and T.Surface or T.SurfaceDeep
                }):Play()
        
                -- Cancel any active confirmation if we disable it mid-process
                if State and awaitingConfirm then
                    if resetThread then task.cancel(resetThread) end
                    resetBtn()
                end
            end
        
            -- CLICK LOGIC
            ActionBtn.MouseButton1Click:Connect(function()
                if Element.Disabled then return end
                
                if Secure then
                    if not awaitingConfirm then
                        awaitingConfirm = true
                        TweenService:Create(ActionBtn, TweenInfo.new(0.2), {BackgroundColor3 = T.Warning}):Play()
                        ActionBtn.Text      = "Confirm?"
                        ActionBtn.TextColor3 = Color3.fromRGB(255, 240, 180)
                        if resetThread then task.cancel(resetThread) end
                        resetThread = task.delay(3, resetBtn)
                    else
                        if resetThread then task.cancel(resetThread) end
                        awaitingConfirm = false
                        TweenService:Create(ActionBtn, TweenInfo.new(0.15), {BackgroundColor3 = T.Success}):Play()
                        ActionBtn.Text      = "✓ Done"
                        ActionBtn.TextColor3 = Color3.fromRGB(200, 255, 210)
                        Callback()
                        task.delay(1.2, resetBtn)
                    end
                else
                    Callback()
                end
            end)
        
            return AttachTooltip(TitleLabel, Element)
        end

        -- ── TOGGLE ────────────────────────────────────────────
        function Tab:CreateToggle(Title, Default, Callback)
            local Element  = {}
            local Toggled  = Default
            local RowHeight = ES(28)

            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            ToggleFrame.BackgroundColor3 = T.Surface
            ToggleFrame.Parent           = self.Container
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(ToggleFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.65, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = ToggleFrame

            local ToggleBG = Instance.new("TextButton")
            ToggleBG.Size             = UDim2.new(0, ES(34), 0, ES(18))
            ToggleBG.AnchorPoint      = Vector2.new(1, 0.5)
            ToggleBG.Position         = UDim2.new(1, -ES(8), 0.5, 0)
            ToggleBG.BackgroundColor3 = Toggled and T.Accent or T.SurfaceDeep
            ToggleBG.Text             = ""
            ToggleBG.Parent           = ToggleFrame
            Instance.new("UICorner", ToggleBG).CornerRadius = UDim.new(1, 0)
            AddDepthStroke(ToggleBG)

            local dotOff = ES(3)
            local dotOn  = ES(34) - ES(15)
            local dotSz  = ES(12)
            local ToggleDot = Instance.new("Frame")
            ToggleDot.Size             = UDim2.new(0, dotSz, 0, dotSz)
            ToggleDot.Position         = Toggled and UDim2.new(0, dotOn, 0.5, -dotSz/2) or UDim2.new(0, dotOff, 0.5, -dotSz/2)
            ToggleDot.BackgroundColor3 = T.TextWhite
            ToggleDot.Parent           = ToggleBG
            Instance.new("UICorner", ToggleDot).CornerRadius = UDim.new(1, 0)

            ToggleBG.MouseButton1Click:Connect(function()
                Toggled = not Toggled
                local targetPos = Toggled and UDim2.new(0, dotOn, 0.5, -dotSz/2) or UDim2.new(0, dotOff, 0.5, -dotSz/2)
                local targetCol = Toggled and T.Accent or T.SurfaceDeep
                TweenService:Create(ToggleDot, TweenInfo.new(0.2), {Position = targetPos}):Play()
                TweenService:Create(ToggleBG,  TweenInfo.new(0.2), {BackgroundColor3 = targetCol}):Play()
                Callback(Toggled)
            end)

            return AttachTooltip(TitleLabel, Element)
        end

        -- ── SLIDER ────────────────────────────────────────────
        function Tab:CreateSlider(Title, Min, Max, Default, Callback)
            local Element   = {}
            local RowHeight = ES(38)

            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            SliderFrame.BackgroundColor3 = T.Surface
            SliderFrame.Parent           = self.Container
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(SliderFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(1, -ES(70), 0, ES(20))
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, ES(4))
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = SliderFrame

            local ValueLabel = Instance.new("TextLabel")
            ValueLabel.Size            = UDim2.new(0, ES(55), 0, ES(20))
            ValueLabel.AnchorPoint     = Vector2.new(1, 0)
            ValueLabel.Position        = UDim2.new(1, -ES(8), 0, ES(4))
            ValueLabel.BackgroundTransparency = 1
            ValueLabel.Text            = tostring(Default)
            ValueLabel.TextColor3      = T.Accent
            ValueLabel.Font            = Enum.Font.GothamBold
            ValueLabel.TextSize        = FS(12)
            ValueLabel.TextXAlignment  = Enum.TextXAlignment.Right
            ValueLabel.Parent          = SliderFrame

            local trackY = ES(28)
            local SliderBG = Instance.new("Frame")
            SliderBG.Size             = UDim2.new(1, -ES(20), 0, ES(4))
            SliderBG.Position         = UDim2.new(0, ES(10), 0, trackY)
            SliderBG.BackgroundColor3 = T.SurfaceDeep
            SliderBG.Parent           = SliderFrame
            Instance.new("UICorner", SliderBG)

            local SliderFill = Instance.new("Frame")
            SliderFill.Size             = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = T.Accent
            SliderFill.BorderSizePixel  = 0
            SliderFill.Parent           = SliderBG
            Instance.new("UICorner", SliderFill)

            local SliderBtn = Instance.new("TextButton")
            SliderBtn.Size               = UDim2.new(1, 0, 1, 0)
            SliderBtn.BackgroundTransparency = 1
            SliderBtn.Text               = ""
            SliderBtn.ZIndex             = SliderFrame.ZIndex + 5
            SliderBtn.Parent             = SliderFrame

            local function UpdateSlider()
                local mousePos = UserInputService:GetMouseLocation().X
                local barPos   = SliderBG.AbsolutePosition.X
                local barWidth = SliderBG.AbsoluteSize.X
                local pct      = math.clamp((mousePos - barPos) / barWidth, 0, 1)
                local value    = math.floor(Min + (Max - Min) * pct)
                SliderFill.Size   = UDim2.new(pct, 0, 1, 0)
                ValueLabel.Text   = tostring(value)
                Callback(value)
            end

            local sliding = false
            SliderBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = true; UpdateSlider()
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider() end
            end)

            return AttachTooltip(TitleLabel, Element)
        end

        -- ── KEYBIND ───────────────────────────────────────────
        function Tab:CreateKeybind(Title, Default, Callback)
            local Element   = {}
            local KeyName   = (typeof(Default) == "EnumItem") and Default.Name or Default.UserInputType.Name
            local RowHeight = ES(28)

            local KeybindFrame = Instance.new("Frame")
            KeybindFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            KeybindFrame.BackgroundColor3 = T.Surface
            KeybindFrame.Parent           = self.Container
            Instance.new("UICorner", KeybindFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(KeybindFrame)

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.65, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = KeybindFrame

            local BindBtn = Instance.new("TextButton")
            BindBtn.Size             = UDim2.new(0, ES(70), 0, ES(20))
            BindBtn.AnchorPoint      = Vector2.new(1, 0.5)
            BindBtn.Position         = UDim2.new(1, -ES(8), 0.5, 0)
            BindBtn.BackgroundColor3 = T.SurfaceDeep
            BindBtn.Text             = KeyName
            BindBtn.TextColor3       = T.TextWhite
            BindBtn.Font             = Enum.Font.GothamBold
            BindBtn.TextSize         = FS(11)
            BindBtn.Parent           = KeybindFrame
            Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 4)
            AddDepthStroke(BindBtn)

            BindBtn.MouseButton1Click:Connect(function()
                BindBtn.Text = "..."
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        KeyName = input.KeyCode.Name; BindBtn.Text = KeyName; conn:Disconnect()
                    elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                        KeyName = input.UserInputType.Name; BindBtn.Text = KeyName; conn:Disconnect()
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

            return AttachTooltip(TitleLabel, Element)
        end

-- ── INFO BOX ──────────────────────────────────────────────────
        function Tab:CreateInfoBox(CfgOrTitle, LegacyDescription)
            local Cfg
            if type(CfgOrTitle) == "string" then
                Cfg = { Title = CfgOrTitle, Description = LegacyDescription }
            else
                Cfg = CfgOrTitle or {}
            end

            local InfoBox     = {}
            local hasHeader   = (Cfg.Title ~= nil and Cfg.Title ~= "") or (Cfg.Icon ~= nil and Cfg.Icon ~= "")
            local headerH     = hasHeader and ES(28) or 0

            -- ── Outer card (vertical list so height is automatic) ────
            local Card = Instance.new("Frame")
            Card.Size             = UDim2.new(1, 0, 0, 0)
            Card.AutomaticSize    = Enum.AutomaticSize.Y
            Card.BackgroundColor3 = T.Surface
            Card.BorderSizePixel  = 0
            Card.ClipsDescendants = false
            Card.Parent           = self.Container
            Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 6)

            local CardStroke = Instance.new("UIStroke", Card)
            CardStroke.Color           = T.Stroke
            CardStroke.Thickness       = 1
            CardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

            local CardLayout = Instance.new("UIListLayout", Card)
            CardLayout.SortOrder      = Enum.SortOrder.LayoutOrder
            CardLayout.FillDirection  = Enum.FillDirection.Vertical
            CardLayout.Padding        = UDim.new(0, 0)

            -- ── Top accent stripe ─────────────────────────────────────
            local TopStripe = Instance.new("Frame")
            TopStripe.LayoutOrder      = 1
            TopStripe.Size             = UDim2.new(1, 0, 0, 2)
            TopStripe.BackgroundColor3 = T.Accent
            TopStripe.BorderSizePixel  = 0
            TopStripe.Parent           = Card
            -- UICorner on just the top: a covering frame hides the bottom rounding
            Instance.new("UICorner", TopStripe).CornerRadius = UDim.new(0, 6)
            local StripeFloor = Instance.new("Frame", TopStripe)
            StripeFloor.Size             = UDim2.new(1, 0, 0.5, 1)
            StripeFloor.Position         = UDim2.new(0, 0, 0.5, 0)
            StripeFloor.BackgroundColor3 = T.Accent
            StripeFloor.BorderSizePixel  = 0

            -- ── Header (icon · title on left, badge on right) ─────────
            local Header
            if hasHeader then
                Header = Instance.new("Frame")
                Header.LayoutOrder      = 2
                Header.Size             = UDim2.new(1, 0, 0, headerH)
                Header.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
                Header.BorderSizePixel  = 0
                Header.Parent           = Card

                -- Icon (left-anchored, fixed width)
                local iconW = (Cfg.Icon and Cfg.Icon ~= "") and ES(22) or 0
                if Cfg.Icon and Cfg.Icon ~= "" then
                    local IconLabel = Instance.new("TextLabel")
                    IconLabel.Size                = UDim2.new(0, iconW, 1, 0)
                    IconLabel.Position            = UDim2.new(0, ES(10), 0, 0)
                    IconLabel.BackgroundTransparency = 1
                    IconLabel.Text                = Cfg.Icon
                    IconLabel.TextColor3          = T.Accent
                    IconLabel.Font                = Enum.Font.GothamBold
                    IconLabel.TextSize            = FS(13)
                    IconLabel.TextXAlignment      = Enum.TextXAlignment.Center
                    IconLabel.Parent              = Header
                end

                -- Title (fills space between icon and badge)
                local TitleLabel = Instance.new("TextLabel")
                TitleLabel.Size               = UDim2.new(1, -(ES(10) + iconW + ES(6) + ES(90)), 1, 0)
                TitleLabel.Position           = UDim2.new(0, ES(10) + iconW + ES(6), 0, 0)
                TitleLabel.BackgroundTransparency = 1
                TitleLabel.Text               = Cfg.Title or ""
                TitleLabel.TextColor3         = T.TextWhite
                TitleLabel.Font               = Enum.Font.GothamBold
                TitleLabel.TextSize           = FS(12)
                TitleLabel.TextXAlignment     = Enum.TextXAlignment.Left
                TitleLabel.TextTruncate       = Enum.TextTruncate.AtEnd
                TitleLabel.Parent             = Header

                -- Badge (right-anchored pill)
                local BadgeLabel = Instance.new("TextLabel")
                BadgeLabel.AnchorPoint        = Vector2.new(1, 0.5)
                BadgeLabel.Position           = UDim2.new(1, -ES(8), 0.5, 0)
                BadgeLabel.Size               = UDim2.new(0, ES(80), 0, ES(17))
                BadgeLabel.BackgroundColor3   = Cfg.BadgeColor or T.Success
                BadgeLabel.TextColor3         = T.TextWhite
                BadgeLabel.Font               = Enum.Font.GothamBold
                BadgeLabel.TextSize           = FS(10)
                BadgeLabel.Text               = Cfg.Badge or ""
                BadgeLabel.Visible            = (Cfg.Badge ~= nil and Cfg.Badge ~= "")
                BadgeLabel.Parent             = Header
                Instance.new("UICorner", BadgeLabel).CornerRadius = UDim.new(1, 0)

                -- Store refs for API
                function InfoBox:SetTitle(text)
                    TitleLabel.Text = text or ""
                end
                function InfoBox:SetBadge(text, color)
                    BadgeLabel.Text             = text or ""
                    BadgeLabel.BackgroundColor3 = color or T.Success
                    BadgeLabel.Visible          = (text ~= nil and text ~= "")
                end
                function InfoBox:SetAccentColor(color)
                    TopStripe.BackgroundColor3  = color
                    StripeFloor.BackgroundColor3 = color
                    CardStroke.Color            = color
                end
            end

            -- ── Description body ──────────────────────────────────────
            local Body = Instance.new("Frame")
            Body.LayoutOrder        = 3
            Body.Size               = UDim2.new(1, 0, 0, 0)
            Body.AutomaticSize      = Enum.AutomaticSize.Y
            Body.BackgroundTransparency = 1
            Body.Parent             = Card

            local BodyPad = Instance.new("UIPadding", Body)
            BodyPad.PaddingLeft   = UDim.new(0, ES(10))
            BodyPad.PaddingRight  = UDim.new(0, ES(10))
            BodyPad.PaddingTop    = UDim.new(0, ES(7))
            BodyPad.PaddingBottom = UDim.new(0, ES(9))

            local DescLabel = Instance.new("TextLabel")
            DescLabel.Size                = UDim2.new(1, 0, 0, 0)
            DescLabel.BackgroundTransparency = 1
            DescLabel.Text                = Cfg.Description or ""
            DescLabel.TextColor3          = T.TextDark
            DescLabel.Font                = Enum.Font.Gotham
            DescLabel.TextSize            = FS(11)
            DescLabel.TextWrapped         = true
            DescLabel.RichText            = true
            DescLabel.LineHeight          = 1.35
            DescLabel.TextXAlignment      = Enum.TextXAlignment.Left
            DescLabel.AutomaticSize       = Enum.AutomaticSize.Y
            DescLabel.Parent              = Body

            function InfoBox:SetDescription(text)
                DescLabel.Text = text or ""
            end

            return InfoBox
        end

        -- ── IMAGE SELECTOR ────────────────────────────────────
        function Tab:CreateImageSelector(Title, Config2, Callback)
            local Element = {Selected = {}}
            Config2 = Config2 or {}
            local Multi    = Config2.MultiSelect or false
            local Rows     = Config2.Rows or 1
            local SlotSize = Config2.SlotSize or UDim2.new(0, ES(70), 0, ES(70))

            local TopPadding   = ES(35)
            local BottomPadding = ES(10)
            local CellPaddingY  = ES(8)
            local ScrollHeight  = (SlotSize.Y.Offset * Rows) + (CellPaddingY * (Rows - 1)) + 6
            local TotalHeight   = TopPadding + ScrollHeight + BottomPadding

            local SelectorFrame = Instance.new("Frame")
            SelectorFrame.Name             = Title .. "_ImageSelector"
            SelectorFrame.Size             = UDim2.new(1, 0, 0, TotalHeight)
            SelectorFrame.BackgroundColor3 = T.Surface
            SelectorFrame.Parent           = self.Container
            Instance.new("UICorner", SelectorFrame).CornerRadius = UDim.new(0, 6)
            local FrameStroke = Instance.new("UIStroke", SelectorFrame)
            FrameStroke.Color     = T.Stroke
            FrameStroke.Thickness = 1

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(1, -20, 0, ES(20))
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, ES(8))
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(13)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = SelectorFrame

            local Scroll = Instance.new("ScrollingFrame")
            Scroll.Size                  = UDim2.new(1, -ES(20), 0, ScrollHeight)
            Scroll.Position              = UDim2.new(0, ES(10), 0, TopPadding)
            Scroll.BackgroundTransparency = 1
            Scroll.BorderSizePixel       = 0
            Scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
            Scroll.ScrollBarThickness    = 2
            Scroll.ScrollBarImageColor3  = T.Accent
            Scroll.ScrollingDirection    = Enum.ScrollingDirection.X
            Scroll.Parent                = SelectorFrame

            local Layout = Instance.new("UIGridLayout", Scroll)
            Layout.CellSize      = SlotSize
            Layout.CellPadding   = UDim2.new(0, ES(8), 0, CellPaddingY)
            Layout.SortOrder     = Enum.SortOrder.LayoutOrder
            Layout.FillDirection = Enum.FillDirection.Vertical

            local Padding = Instance.new("UIPadding", Scroll)
            Padding.PaddingLeft   = UDim.new(0, 2)
            Padding.PaddingTop    = UDim.new(0, ES(3))
            Padding.PaddingBottom = UDim.new(0, ES(3))

            function Element:AddSlot(ID, SlotTitle, SlotSubText)
                local Slot = Instance.new("TextButton")
                Slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                Slot.Text             = ""
                Slot.Parent           = Scroll
                Instance.new("UICorner", Slot).CornerRadius = UDim.new(0, 6)
                local Stroke = Instance.new("UIStroke", Slot)
                Stroke.Color          = Color3.fromRGB(50, 50, 55)
                Stroke.Thickness      = 1.2
                Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                local Image = Instance.new("ImageLabel")
                Image.Size               = UDim2.new(0.4, 0, 0.4, 0)
                Image.Position           = UDim2.new(0.5, 0, 0.35, 0)
                Image.AnchorPoint        = Vector2.new(0.5, 0.5)
                Image.BackgroundTransparency = 1
                Image.Image              = ID
                Image.Parent             = Slot
                if SlotTitle then
                    local Txt = Instance.new("TextLabel")
                    Txt.Size           = UDim2.new(1, 0, 0, FS(12))
                    Txt.Position       = UDim2.new(0, 0, 0.62, 0)
                    Txt.BackgroundTransparency = 1
                    Txt.Text           = SlotTitle
                    Txt.TextColor3     = T.TextPrimary
                    Txt.Font           = Enum.Font.GothamMedium
                    Txt.TextSize       = FS(10)
                    Txt.Parent         = Slot
                end
                if SlotSubText then
                    local SubTxt = Instance.new("TextLabel")
                    SubTxt.Size           = UDim2.new(1, 0, 0, FS(12))
                    SubTxt.Position       = UDim2.new(0, 0, 0.78, 0)
                    SubTxt.BackgroundTransparency = 1
                    SubTxt.Text           = SlotSubText
                    SubTxt.TextColor3     = Color3.fromRGB(120, 230, 120)
                    SubTxt.Font           = Enum.Font.GothamBold
                    SubTxt.TextSize       = FS(10)
                    SubTxt.Parent         = Slot
                end
                Slot.MouseButton1Click:Connect(function()
                    local isSelected = (Slot.BackgroundColor3 == T.Accent)
                    if not Multi then
                        for _, child in pairs(Scroll:GetChildren()) do
                            if child:IsA("TextButton") then
                                TweenService:Create(child, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 24)}):Play()
                                child:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(50, 50, 55)
                            end
                        end
                        Element.Selected = {SlotTitle or ID}
                    else
                        if isSelected then
                            for i, v in ipairs(Element.Selected) do
                                if v == (SlotTitle or ID) then table.remove(Element.Selected, i) break end
                            end
                        else
                            table.insert(Element.Selected, SlotTitle or ID)
                        end
                    end
                    local targetColor = isSelected and Color3.fromRGB(20, 20, 24) or T.Accent
                    local strokeColor = isSelected and Color3.fromRGB(50, 50, 55) or Color3.new(1,1,1)
                    TweenService:Create(Slot, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                    Stroke.Color = strokeColor
                    Callback(Multi and Element.Selected or Element.Selected[1])
                end)
                Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    Scroll.CanvasSize = UDim2.new(0, Layout.AbsoluteContentSize.X + 10, 0, 0)
                end)
                return Slot
            end

            return Element
        end

        -- ── DROPDOWN ──────────────────────────────────────────
        function Tab:CreateDropdown(Title, Options, Default, Callback)
            local Element  = {}
            local Dropdown = {Open = false, Selected = Default or "Select..."}
            local RowHeight = ES(28)

            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Size             = UDim2.new(1, 0, 0, RowHeight)
            DropdownFrame.BackgroundColor3 = T.Surface
            DropdownFrame.ClipsDescendants = true
            DropdownFrame.Parent           = self.Container
            Instance.new("UICorner", DropdownFrame).CornerRadius = UDim.new(0, 6)
            AddDepthStroke(DropdownFrame)

            local Header = Instance.new("TextButton")
            Header.Size               = UDim2.new(1, 0, 0, RowHeight)
            Header.BackgroundTransparency = 1
            Header.Text               = ""
            Header.Parent             = DropdownFrame

            local TitleLabel = Instance.new("TextLabel")
            TitleLabel.Size            = UDim2.new(0.6, 0, 1, 0)
            TitleLabel.Position        = UDim2.new(0, ES(10), 0, 0)
            TitleLabel.BackgroundTransparency = 1
            TitleLabel.Text            = Title
            TitleLabel.TextColor3      = T.TextPrimary
            TitleLabel.Font            = Enum.Font.GothamMedium
            TitleLabel.TextSize        = FS(12)
            TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
            TitleLabel.Parent          = Header

            local SelectedLabel = Instance.new("TextLabel")
            SelectedLabel.Size            = UDim2.new(0.4, -25, 1, 0)
            SelectedLabel.Position        = UDim2.new(1, -10, 0, 0)
            SelectedLabel.AnchorPoint     = Vector2.new(1, 0)
            SelectedLabel.BackgroundTransparency = 1
            SelectedLabel.Text            = Dropdown.Selected
            SelectedLabel.TextColor3      = T.Accent
            SelectedLabel.Font            = Enum.Font.GothamBold
            SelectedLabel.TextSize        = FS(11)
            SelectedLabel.TextXAlignment  = Enum.TextXAlignment.Right
            SelectedLabel.Parent          = Header

            local OptionHolder = Instance.new("Frame")
            OptionHolder.Size             = UDim2.new(1, -10, 0, 0)
            OptionHolder.Position         = UDim2.new(0, 5, 0, RowHeight + ES(2))
            OptionHolder.BackgroundTransparency = 1
            OptionHolder.Parent           = DropdownFrame

            local Layout = Instance.new("UIListLayout", OptionHolder)
            Layout.Padding = UDim.new(0, ES(3))

            local function Refresh()
                for _, child in pairs(OptionHolder:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in pairs(Options) do
                    local OptBtn = Instance.new("TextButton")
                    OptBtn.Size             = UDim2.new(1, 0, 0, ES(22))
                    OptBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                    OptBtn.Text             = opt
                    OptBtn.TextColor3       = T.TextDark
                    OptBtn.Font             = Enum.Font.Gotham
                    OptBtn.TextSize         = FS(11)
                    OptBtn.Parent           = OptionHolder
                    Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)
                    OptBtn.MouseButton1Click:Connect(function()
                        Dropdown.Selected  = opt
                        SelectedLabel.Text = opt
                        Dropdown.Open      = false
                        TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, RowHeight)}):Play()
                        Callback(opt)
                    end)
                end
            end

            Header.MouseButton1Click:Connect(function()
                Dropdown.Open = not Dropdown.Open
                local targetHeight = Dropdown.Open and (Layout.AbsoluteContentSize.Y + RowHeight + ES(7)) or RowHeight
                TweenService:Create(DropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
            end)

            Refresh()
            return AttachTooltip(TitleLabel, Element)
        end

        return Tab
    end

    return Window
end

-- ============================================================
-- SCRIPT EXECUTION
-- ============================================================
local HubWindow = Library:CreateWindow()

local HomeTab       = HubWindow:CreateTab("Home")
local PlayerTab     = HubWindow:CreateTab("Player")
local WorldTab      = HubWindow:CreateTab("World")
local TeleportTab   = HubWindow:CreateTab("Teleport")
local WoodTab       = HubWindow:CreateTab("Wood")
local PlotTab       = HubWindow:CreateTab("Plot")
local DuplicatetTab = HubWindow:CreateTab("Duplicate")
local ShopTab       = HubWindow:CreateTab("Shop")
local VehicleTab    = HubWindow:CreateTab("Vehicle")
local BuildTab      = HubWindow:CreateTab("Build")
local ToolTab       = HubWindow:CreateTab("Tool")
local ProtectionTab = HubWindow:CreateTab("Protection")
local SettingsTab   = HubWindow:CreateTab("Settings")

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

local HomeModule = LoadModule("Home")
if HomeModule and HomeModule.Init then HomeModule.Init(HomeTab, Library) end

local MovementModule = LoadModule("PlayerMovement")
if MovementModule and MovementModule.Init then MovementModule.Init(PlayerTab) end
local FlashlightModule = LoadModule("FlashLight")
if FlashlightModule and FlashlightModule.Init then FlashlightModule.Init(PlayerTab) end

local TeleportModule = LoadModule("Teleport")
if TeleportModule and TeleportModule.Init then TeleportModule.Init(TeleportTab) end

local GhostModule = LoadModule("GhostSuite")
if GhostModule and GhostModule.Init then GhostModule.Init(BuildTab) end

local WorldModule = LoadModule("World")
if WorldModule and WorldModule.Init then WorldModule.Init(WorldTab, Library) end

local SettingsModule = LoadModule("Settings")
if SettingsModule and SettingsModule.Init then
    SettingsModule.Init(SettingsTab, HubWindow, {User = User, Repo = Repo, Branch = Branch})
end

local DraggerModule = LoadModule("HardDragger")
if DraggerModule and DraggerModule.Init then DraggerModule.Init(ToolTab) end

local WatchDogModule = LoadModule("WatchDog")
if WatchDogModule and WatchDogModule.Init then WatchDogModule.Init(ProtectionTab) end
local AntiFlingModule = LoadModule("AntiFling")
if AntiFlingModule and AntiFlingModule.Init then AntiFlingModule.Init(ProtectionTab) end
local AntiVoidModule = LoadModule("AntiVoid")
if AntiVoidModule and AntiVoidModule.Init then AntiVoidModule.Init(ProtectionTab) end
local AntiRagdollModule = LoadModule("AntiRagdoll")
if AntiRagdollModule and AntiRagdollModule.Init then AntiRagdollModule.Init(ProtectionTab) end
local AntiAFKModule = LoadModule("AntiAFK")
if AntiAFKModule and AntiAFKModule.Init then AntiAFKModule.Init(ProtectionTab) end

local LooseObjectTeleportModule = LoadModule("LooseObjectTeleport")
if LooseObjectTeleportModule and LooseObjectTeleportModule.Init then LooseObjectTeleportModule.Init(ToolTab, Library) end

local PlayPositionNotifyModule = LoadModule("PlayPositionNotify")
if PlayPositionNotifyModule and PlayPositionNotifyModule.Init then PlayPositionNotifyModule.Init(ToolTab, Library) end

local TreeCamModule = LoadModule("TreeCam")
if TreeCamModule and TreeCamModule.Init then TreeCamModule.Init(WoodTab) end

local VehicleModule = LoadModule("Vehicle")
if VehicleModule and VehicleModule.Init then VehicleModule.Init(VehicleTab) end

local SaveGameModule = LoadModule("SaveGame")
if SaveGameModule and SaveGameModule.Init then SaveGameModule.Init(PlotTab, Library) end

local PlotModule = LoadModule("Plot")
if PlotModule and PlotModule.Init then PlotModule.Init(PlotTab, Library) end

local AxeDupeModule = LoadModule("AxeDupe")
if AxeDupeModule and AxeDupeModule.Init then AxeDupeModule.Init(DuplicatetTab) end

local TreeModule = LoadModule("Tree")
if TreeModule and TreeModule.Init then TreeModule.Init(WoodTab, LooseObjectTeleportModule) end

local ShopScript = LoadModule("Shop")
if ShopScript and ShopScript.Init then ShopScript.Init(ShopTab, LooseObjectTeleportModule) end

local Theme = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/learnhtsd/lt2/refs/heads/main/Theme.lua"
))()

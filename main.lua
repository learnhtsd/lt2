-- ==========================================
-- CONFIGURATION
-- ==========================================
local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main" 
local Version = "v0.0.038"
local ToggleKey = Enum.KeyCode.RightControl

-- ==========================================
-- UI ENGINE START
-- ==========================================
local Library = {}
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "NexusCustomHub" then v:Destroy() end
end

-- Module names to search across
local ModuleNames = {"PlayerMovement", "Teleport", "GhostSuite", "World", "Settings", "GetWood", "Tool"}
local ModuleCache = {} -- { [ModuleName] = "source code string" }

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
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == ToggleKey then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)

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
    HeaderTitle.Text = "<b>Lumber Tycoon 2</b> <font color=\"#4a78ff\">Hub</font> <font color=\"#555555\" size=\"12\">" .. Version .. "</font>"
    HeaderTitle.RichText = true
    HeaderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    HeaderTitle.Font = Enum.Font.GothamMedium
    HeaderTitle.TextSize = 16
    HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
    HeaderTitle.Parent = MainFrame

    -- ==========================================
    -- SEARCH BAR
    -- ==========================================
    local SearchBar = Instance.new("Frame")
    SearchBar.Size = UDim2.new(0, 140, 0, 22)
    SearchBar.Position = UDim2.new(1, -148, 0, 9)
    SearchBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    SearchBar.BorderSizePixel = 0
    SearchBar.Parent = MainFrame
    Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(0, 5)
    local SearchStroke = Instance.new("UIStroke", SearchBar)
    SearchStroke.Color = Color3.fromRGB(50, 50, 62)
    SearchStroke.Thickness = 1

    local SearchIcon = Instance.new("TextLabel")
    SearchIcon.Size = UDim2.new(0, 18, 1, 0)
    SearchIcon.Position = UDim2.new(0, 4, 0, 0)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Text = "🔍"
    SearchIcon.TextSize = 10
    SearchIcon.Font = Enum.Font.Gotham
    SearchIcon.TextColor3 = Color3.fromRGB(100, 100, 120)
    SearchIcon.Parent = SearchBar

    local SearchInput = Instance.new("TextBox")
    SearchInput.Size = UDim2.new(1, -26, 1, 0)
    SearchInput.Position = UDim2.new(0, 22, 0, 0)
    SearchInput.BackgroundTransparency = 1
    SearchInput.PlaceholderText = "Search modules..."
    SearchInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
    SearchInput.Text = ""
    SearchInput.TextColor3 = Color3.fromRGB(200, 200, 220)
    SearchInput.Font = Enum.Font.Gotham
    SearchInput.TextSize = 11
    SearchInput.ClearTextOnFocus = false
    SearchInput.TextXAlignment = Enum.TextXAlignment.Left
    SearchInput.Parent = SearchBar

    -- Clear button (x)
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(0, 16, 1, 0)
    ClearBtn.Position = UDim2.new(1, -18, 0, 0)
    ClearBtn.BackgroundTransparency = 1
    ClearBtn.Text = "✕"
    ClearBtn.TextColor3 = Color3.fromRGB(80, 80, 100)
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 10
    ClearBtn.Visible = false
    ClearBtn.Parent = SearchBar

    -- Search Results Dropdown (sits below MainFrame header area, overlays content)
    local SearchResults = Instance.new("Frame")
    SearchResults.Name = "SearchResults"
    SearchResults.Size = UDim2.new(0, 200, 0, 0)
    SearchResults.Position = UDim2.new(1, -208, 0, 33)
    SearchResults.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
    SearchResults.BorderSizePixel = 0
    SearchResults.ClipsDescendants = true
    SearchResults.Visible = false
    SearchResults.ZIndex = 10
    SearchResults.Parent = MainFrame
    Instance.new("UICorner", SearchResults).CornerRadius = UDim.new(0, 6)
    local ResultsStroke = Instance.new("UIStroke", SearchResults)
    ResultsStroke.Color = Color3.fromRGB(50, 50, 62)
    ResultsStroke.Thickness = 1

    local ResultsScroll = Instance.new("ScrollingFrame")
    ResultsScroll.Size = UDim2.new(1, 0, 1, 0)
    ResultsScroll.BackgroundTransparency = 1
    ResultsScroll.ScrollBarThickness = 2
    ResultsScroll.ScrollBarImageColor3 = Color3.fromRGB(74, 120, 255)
    ResultsScroll.BorderSizePixel = 0
    ResultsScroll.ZIndex = 10
    ResultsScroll.Parent = SearchResults

    local ResultsList = Instance.new("UIListLayout", ResultsScroll)
    ResultsList.SortOrder = Enum.SortOrder.LayoutOrder
    ResultsList.Padding = UDim.new(0, 0)

    local ResultsPadding = Instance.new("UIPadding", ResultsScroll)
    ResultsPadding.PaddingTop = UDim.new(0, 4)
    ResultsPadding.PaddingBottom = UDim.new(0, 4)

    ResultsList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ResultsScroll.CanvasSize = UDim2.new(0, 0, 0, ResultsList.AbsoluteContentSize.Y + 8)
    end)

    -- Fetch all modules into cache (background)
    local function FetchModuleCache()
        for _, modName in ipairs(ModuleNames) do
            if not ModuleCache[modName] then
                task.spawn(function()
                    local url = string.format(
                        "https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s",
                        User, Repo, Branch, modName, tick()
                    )
                    local ok, src = pcall(function() return game:HttpGet(url) end)
                    if ok and src then
                        ModuleCache[modName] = src
                    end
                end)
            end
        end
    end

    -- Clear all result rows
    local function ClearResults()
        for _, child in pairs(ResultsScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
        end
    end

    -- Add a result row
    local function AddResultRow(moduleName, lineNum, lineText)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 44)
        Row.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        Row.BackgroundTransparency = 1
        Row.BorderSizePixel = 0
        Row.ZIndex = 10
        Row.Parent = ResultsScroll

        local Divider = Instance.new("Frame")
        Divider.Size = UDim2.new(1, -16, 0, 1)
        Divider.Position = UDim2.new(0, 8, 1, -1)
        Divider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        Divider.BorderSizePixel = 0
        Divider.ZIndex = 10
        Divider.Parent = Row

        -- Module name badge
        local ModLabel = Instance.new("TextLabel")
        ModLabel.Size = UDim2.new(1, -16, 0, 14)
        ModLabel.Position = UDim2.new(0, 10, 0, 6)
        ModLabel.BackgroundTransparency = 1
        ModLabel.Text = moduleName .. "  <font color=\"#555566\">line " .. lineNum .. "</font>"
        ModLabel.RichText = true
        ModLabel.TextColor3 = Color3.fromRGB(74, 120, 255)
        ModLabel.Font = Enum.Font.GothamBold
        ModLabel.TextSize = 10
        ModLabel.TextXAlignment = Enum.TextXAlignment.Left
        ModLabel.ZIndex = 10
        ModLabel.Parent = Row

        -- Matched line preview
        local LineLabel = Instance.new("TextLabel")
        LineLabel.Size = UDim2.new(1, -16, 0, 18)
        LineLabel.Position = UDim2.new(0, 10, 0, 21)
        LineLabel.BackgroundTransparency = 1
        LineLabel.Text = lineText:gsub("^%s+", "") -- trim leading whitespace
        LineLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
        LineLabel.Font = Enum.Font.Code
        LineLabel.TextSize = 10
        LineLabel.TextXAlignment = Enum.TextXAlignment.Left
        LineLabel.TextTruncate = Enum.TextTruncate.AtEnd
        LineLabel.ZIndex = 10
        LineLabel.Parent = Row

        -- Hover effect
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Size = UDim2.new(1, 0, 1, 0)
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""
        ClickBtn.ZIndex = 11
        ClickBtn.Parent = Row

        ClickBtn.MouseEnter:Connect(function()
            TweenService:Create(Row, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
        end)
        ClickBtn.MouseLeave:Connect(function()
            TweenService:Create(Row, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        end)
    end

    -- Add a "no results" row
    local function AddNoResultsRow(query)
        local Row = Instance.new("TextLabel")
        Row.Size = UDim2.new(1, 0, 0, 36)
        Row.BackgroundTransparency = 1
        Row.Text = "No results for \"" .. query .. "\""
        Row.TextColor3 = Color3.fromRGB(80, 80, 100)
        Row.Font = Enum.Font.Gotham
        Row.TextSize = 11
        Row.ZIndex = 10
        Row.Parent = ResultsScroll
    end

    -- Add a "loading" row
    local function AddLoadingRow()
        local Row = Instance.new("TextLabel")
        Row.Size = UDim2.new(1, 0, 0, 36)
        Row.BackgroundTransparency = 1
        Row.Text = "Fetching modules..."
        Row.TextColor3 = Color3.fromRGB(74, 120, 255)
        Row.Font = Enum.Font.Gotham
        Row.TextSize = 11
        Row.ZIndex = 10
        Row.Parent = ResultsScroll
    end

    -- Show/hide results panel with tween
    local function ShowResults(show, height)
        SearchResults.Visible = true
        local targetHeight = show and math.min(height or 0, 220) or 0
        TweenService:Create(SearchResults, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 200, 0, targetHeight)
        }):Play()
        if not show then
            task.delay(0.2, function() SearchResults.Visible = false end)
        end
    end

    -- Perform search
    local searchDebounce = nil
    local function DoSearch(query)
        query = query:lower()
        ClearResults()

        if query == "" then
            ShowResults(false)
            return
        end

        -- Check if any modules are loaded yet
        local anyLoaded = false
        for _, modName in ipairs(ModuleNames) do
            if ModuleCache[modName] then anyLoaded = true break end
        end

        if not anyLoaded then
            AddLoadingRow()
            ShowResults(true, 36)
            return
        end

        local results = {}
        local MAX_RESULTS = 12

        for _, modName in ipairs(ModuleNames) do
            local src = ModuleCache[modName]
            if src then
                local lineNum = 0
                for line in src:gmatch("[^\n]+") do
                    lineNum += 1
                    if line:lower():find(query, 1, true) then
                        table.insert(results, {mod = modName, line = lineNum, text = line})
                        if #results >= MAX_RESULTS then break end
                    end
                end
            end
        end

        if #results == 0 then
            AddNoResultsRow(query)
            ShowResults(true, 36)
        else
            for _, r in ipairs(results) do
                AddResultRow(r.mod, r.line, r.text)
            end
            ShowResults(true, #results * 44 + 8)
        end
    end

    -- Wire up search input
    SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        local query = SearchInput.Text
        ClearBtn.Visible = query ~= ""

        if searchDebounce then task.cancel(searchDebounce) end
        searchDebounce = task.delay(0.3, function()
            DoSearch(query)
        end)
    end)

    SearchInput.Focused:Connect(function()
        TweenService:Create(SearchStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(74, 120, 255)}):Play()
        if SearchInput.Text ~= "" then
            DoSearch(SearchInput.Text)
        end
        -- Begin fetching modules as soon as user focuses the search bar
        FetchModuleCache()
    end)

    SearchInput.FocusLost:Connect(function()
        TweenService:Create(SearchStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(50, 50, 62)}):Play()
        -- Small delay so clicks on results register first
        task.delay(0.25, function()
            if not SearchInput:IsFocused() then
                ShowResults(false)
            end
        end)
    end)

    ClearBtn.MouseButton1Click:Connect(function()
        SearchInput.Text = ""
        ClearBtn.Visible = false
        ShowResults(false)
        SearchInput:CaptureFocus()
    end)

    -- ==========================================
    -- TAB CONTAINER (unchanged from original)
    -- ==========================================
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

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.Parent = TabContainer
    SidebarPadding.PaddingTop = UDim.new(0, 20)

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -80, 1, -60)
    ContentContainer.Position = UDim2.new(0, 65, 0, 45)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.ClipsDescendants = true
    ContentContainer.Parent = MainFrame

    local NotificationContainer = Instance.new("Frame")
    NotificationContainer.Name = "NotificationContainer"
    NotificationContainer.Size = UDim2.new(0, 250, 1, -20)
    NotificationContainer.Position = UDim2.new(1, -260, 0, 10)
    NotificationContainer.BackgroundTransparency = 1
    NotificationContainer.Parent = ScreenGui
    
    local NotifList = Instance.new("UIListLayout")
    NotifList.Parent = NotificationContainer
    NotifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifList.SortOrder = Enum.SortOrder.LayoutOrder
    NotifList.Padding = UDim.new(0, 8)
    
    function Library:Notify(Title, Text, Duration)
        Duration = Duration or 5
        local NotifFrame = Instance.new("Frame")
        NotifFrame.Size = UDim2.new(1, 0, 0, 0)
        NotifFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
        NotifFrame.BorderSizePixel = 0
        NotifFrame.ClipsDescendants = true
        NotifFrame.Parent = NotificationContainer
        
        Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 6)
        local Stroke = Instance.new("UIStroke", NotifFrame)
        Stroke.Color = Color3.fromRGB(74, 120, 255)
        Stroke.Thickness = 1
        
        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, -20, 0, 20)
        TitleLabel.Position = UDim2.new(0, 10, 0, 5)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = Title:upper()
        TitleLabel.TextColor3 = Color3.fromRGB(74, 120, 255)
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextSize = 12
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = NotifFrame
    
        local ContentLabel = Instance.new("TextLabel")
        ContentLabel.Size = UDim2.new(1, -20, 0, 30)
        ContentLabel.Position = UDim2.new(0, 10, 0, 22)
        ContentLabel.BackgroundTransparency = 1
        ContentLabel.Text = Text
        ContentLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        ContentLabel.Font = Enum.Font.Gotham
        ContentLabel.TextSize = 11
        ContentLabel.TextWrapped = true
        ContentLabel.TextXAlignment = Enum.TextXAlignment.Left
        ContentLabel.Parent = NotifFrame
    
        TweenService:Create(NotifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 60)}):Play()
        
        task.delay(Duration, function()
            local Tween = TweenService:Create(NotifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1})
            Tween:Play()
            Tween.Completed:Connect(function() NotifFrame:Destroy() end)
        end)
    end
    
    -- Dragging
    local dragging, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- ==========================================
    -- WINDOW:CREATETAB (unchanged from original)
    -- ==========================================
    function Window:CreateTab(TabName)
        local Tab = {}

        local TabBtn = Instance.new("ImageButton")
        TabBtn.Name = TabName
        TabBtn.Size = UDim2.new(0, 32, 0, 32)
        TabBtn.Parent = TabContainer
        TabBtn.BackgroundColor3 = Color3.fromRGB(74, 120, 255)
        TabBtn.BackgroundTransparency = 1
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)

        local TabIconText = Instance.new("TextLabel", TabBtn)
        TabIconText.Name = "TabIconText"
        TabIconText.Size = UDim2.new(1, 0, 1, 0)
        TabIconText.BackgroundTransparency = 1
        TabIconText.Text = string.sub(TabName, 1, 1):upper()
        TabIconText.TextColor3 = Color3.fromRGB(120, 120, 130)
        TabIconText.Font = Enum.Font.GothamBold
        TabIconText.TextSize = 14

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 0 
        TabPage.Visible = false
        TabPage.Parent = ContentContainer

        local PageLayout = Instance.new("UIListLayout", TabPage)
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 6) 

        local PagePadding = Instance.new("UIPadding", TabPage)
        PagePadding.PaddingLeft = UDim.new(0, 2)
        PagePadding.PaddingRight = UDim.new(0, 8)
        PagePadding.PaddingTop = UDim.new(0, 2)
        PagePadding.PaddingBottom = UDim.new(0, 20)

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 25)
        end)

        TabBtn.MouseButton1Click:Connect(function()
            if CurrentTab then
                TweenService:Create(CurrentTab.Btn, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                CurrentTab.Btn.TabIconText.TextColor3 = Color3.fromRGB(120, 120, 130)
                CurrentTab.Page.Visible = false
            end
            TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85}):Play()
            TabIconText.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, Page = TabPage}
        end)

        if not CurrentTab then
            TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85}):Play()
            TabIconText.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabPage.Visible = true
            CurrentTab = {Btn = TabBtn, Page = TabPage}
        end

        local function AddDepthStroke(frame)
            local Stroke = Instance.new("UIStroke", frame)
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
            local Dropdown = { Open = false, Selected = Default or "Select..." }

            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Size = UDim2.new(1, 0, 0, 28)
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
-- SCRIPT EXECUTION (unchanged)
-- ==========================================
local HubWindow = Library:CreateWindow()

local HomeTab     = HubWindow:CreateTab("Home")
local PlayerTab   = HubWindow:CreateTab("Player")
local WorldTab    = HubWindow:CreateTab("World")
local TeleportTab = HubWindow:CreateTab("Teleport")
local WoodTab     = HubWindow:CreateTab("Wood")
local BuildTab    = HubWindow:CreateTab("Build")
local ToolTab     = HubWindow:CreateTab("Tool")
local SettingsTab = HubWindow:CreateTab("Settings")

local function LoadModule(ModuleName)
    local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s", 
        User, Repo, Branch, ModuleName, tick())
    local success, code = pcall(function() return game:HttpGet(URL) end)
    if success and code then
        -- Cache the source for search as modules load
        ModuleCache[ModuleName] = code
        local func, err = loadstring(code)
        if func then
            local runSuccess, result = pcall(func)
            if runSuccess then return result end
            warn("Error running module " .. ModuleName .. ": " .. tostring(result))
        else
            warn("Syntax error in module " .. ModuleName .. ": " .. tostring(err))
        end
    else
        warn("Failed to download module: " .. ModuleName)
    end
end

local MovementModule = LoadModule("PlayerMovement")
if MovementModule and MovementModule.Init then MovementModule.Init(PlayerTab) end 

local TeleportModule = LoadModule("Teleport")
if TeleportModule and TeleportModule.Init then TeleportModule.Init(TeleportTab) end

local GhostModule = LoadModule("GhostSuite")
if GhostModule and GhostModule.Init then GhostModule.Init(BuildTab) end

local WorldModule = LoadModule("World")
if WorldModule and WorldModule.Init then WorldModule.Init(WorldTab, Library) end 

local SettingsModule = LoadModule("Settings")
if SettingsModule and SettingsModule.Init then  
    SettingsModule.Init(SettingsTab, {User = User, Repo = Repo, Branch = Branch}) 
end

local GetWoodModule = LoadModule("GetWood")
if GetWoodModule and GetWoodModule.Init then GetWoodModule.Init(WoodTab) end 

local ToolModule = LoadModule("Tool")
if ToolModule and ToolModule.Init then ToolModule.Init(ToolTab, Library) end

Library:Notify("Success", "Nexus Hub loaded successfully!", 4)

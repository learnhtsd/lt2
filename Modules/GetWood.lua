function Tab:CreateDropdown(Title, Options, Default, Callback)
    local Dropdown = {
        Open = false,
        Selected = Default or "Select..."
    }
    
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
    TitleLabel.Size = UDim2.new(0.5, 0, 1, 0) -- Adjusted width
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = Title
    TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    TitleLabel.Font = Enum.Font.GothamMedium
    TitleLabel.TextSize = 12
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Header

    local SelectedLabel = Instance.new("TextLabel")
    SelectedLabel.Size = UDim2.new(0.5, -20, 1, 0) -- Give more room for tree names
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
        -- Added a small buffer to the height to ensure the last item isn't cut off
        local targetHeight = Dropdown.Open and (Layout.AbsoluteContentSize.Y + 38) or 28
        TweenService:Create(DropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
    end)

    Refresh()
end

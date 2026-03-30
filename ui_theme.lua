-- File: ui_theme.lua (Save inside the main folder)

local theme = {
    -- Based on the provided dark-mode image
    ["Colors"] = {
        MainBackground = Color3.fromRGB(24, 25, 30),
        NavbarBackground = Color3.fromRGB(18, 19, 23),
        ElementBackground = Color3.fromRGB(30, 31, 37),
        
        AccentColor = Color3.fromRGB(75, 120, 240), -- The cool blue highlight
        TextColor = Color3.fromRGB(255, 255, 255),
        SecondaryTextColor = Color3.fromRGB(200, 200, 200),
        
        ButtonDefault = Color3.fromRGB(35, 36, 42),
        SliderBar = Color3.fromRGB(50, 50, 60),
        SliderHandle = Color3.fromRGB(255, 255, 255),
        ToggleOn = Color3.fromRGB(75, 120, 240), -- The blue highlight
        ToggleOff = Color3.fromRGB(50, 50, 60),
    },
    ["Fonts"] = {
        Main = Enum.Font.Gotham,
        MainBold = Enum.Font.GothamBold,
        Secondary = Enum.Font.GothamMedium,
    },
    ["Sizes"] = {
        ElementHeight = 40,
        ElementCornerRadius = UDim.new(0, 8),
        UI_Size = UDim2.fromOffset(500, 400)
    }
}

return theme

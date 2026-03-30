local PlayerMovement = {}

function PlayerMovement.Init(OrionLib, Window)
    -- Create the Tab
    local MovementTab = Window:MakeTab({
        Name = "Movement",
        Icon = "rbxassetid://4483345998",
        PremiumOnly = false
    })

    -- Add a Section for organization
    local MainSection = MovementTab:AddSection({
        Name = "Main Controls"
    })

    -- Toggle for Speed
    MainSection:AddToggle({
        Name = "Enable Speed Hack",
        Default = false,
        Callback = function(Value)
            _G.SpeedEnabled = Value
            if not Value and game.Players.LocalPlayer.Character then
                game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end    
    })

    -- Slider for Speed Value
    MainSection:AddSlider({
        Name = "WalkSpeed Custom",
        Min = 16,
        Max = 250,
        Default = 16,
        Color = Color3.fromRGB(255,255,255),
        Increment = 1,
        ValueName = "Speed",
        Callback = function(Value)
            _G.SpeedValue = Value
        end    
    })

    -- Keybind to Toggle Speed
    MainSection:AddBind({
        Name = "Toggle Speed Bind",
        Default = Enum.KeyCode.G,
        Hold = false,
        Callback = function()
            -- This logic flips the toggle state
            _G.SpeedEnabled = not _G.SpeedEnabled
            OrionLib:MakeNotification({
                Name = "Speed Toggled",
                Content = "Speed is now " .. (_G.SpeedEnabled and "ON" or "OFF"),
                Time = 2
            })
        end    
    })

    -- Constant Loop for logic
    task.spawn(function()
        while task.wait() do
            if _G.SpeedEnabled then
                pcall(function()
                    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = _G.SpeedValue or 16
                end)
            end
        end
    end)
end

return PlayerMovement

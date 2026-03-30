local PlayerMovement = {}

function PlayerMovement.Init(OrionLib, Window)
    local MovementTab = Window:MakeTab({
        Name = "Movement",
        Icon = "rbxassetid://4483345998",
        PremiumOnly = false
    })

    local MainSection = MovementTab:AddSection({
        Name = "Main Controls"
    })

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

    MainSection:AddBind({
        Name = "Toggle Speed Bind",
        Default = Enum.KeyCode.G,
        Hold = false,
        Callback = function()
            _G.SpeedEnabled = not _G.SpeedEnabled
            OrionLib:MakeNotification({
                Name = "Speed Toggled",
                Content = "Speed is now " .. (_G.SpeedEnabled and "ON" or "OFF"),
                Time = 2
            })
        end    
    })

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

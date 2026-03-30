local PlayerMovement = {}

-- We pass the UI Library reference from the main script to this module
function PlayerMovement.Init(Library, Window)
    local MovementTab = Window:CreateTab("Movement")

    -- Add a Toggle for WalkSpeed
    MovementTab:CreateToggle({
        Name = "Enable Speed Hack",
        CurrentValue = false,
        Callback = function(Value)
            _G.SpeedEnabled = Value
            if not Value then
                game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
            end
        end,
    })

    -- Add a Slider for the Speed Value
    MovementTab:CreateSlider({
        Name = "WalkSpeed Amount",
        Range = {16, 250},
        Increment = 1,
        CurrentValue = 16,
        Callback = function(Value)
            _G.SpeedValue = Value
        end,
    })

    -- Add a Keybind to reset position
    MovementTab:CreateKeybind({
        Name = "Reset Character",
        CurrentKey = "R",
        Callback = function()
            game.Players.LocalPlayer.Character:BreakJoints()
        end,
    })

    -- Logic Loop for the module
    task.spawn(function()
        while task.wait() do
            if _G.SpeedEnabled and game.Players.LocalPlayer.Character then
                local hum = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.WalkSpeed = _G.SpeedValue or 16
                end
            end
        end
    end)
end

return PlayerMovement

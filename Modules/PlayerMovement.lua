-- Inside your module's Init function
function Module.Init(Tab)
    Tab:CreateToggle("Speed Hack", false, function(state)
        print("Speed is now: ", state)
        -- logic here
    end)

    Tab:CreateSlider("WalkSpeed", 16, 200, 16, function(value)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
    end)

    Tab:CreateKeybind("Quick Teleport", Enum.KeyCode.E, function()
        print("E was pressed!")
    end)
end

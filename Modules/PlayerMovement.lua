local PlayerMovement = {}

function PlayerMovement.Init(Api)
    -- We use the API function from the Main script
    Api.CreateButton("Toggle Speed", function()
        _G.SpeedEnabled = not _G.SpeedEnabled
        print("Speed is now: " .. tostring(_G.SpeedEnabled))
    end)

    Api.CreateButton("Reset Character", function()
        if game.Players.LocalPlayer.Character then
            game.Players.LocalPlayer.Character:BreakJoints()
        end
    end)

    -- Logic Loop
    task.spawn(function()
        while task.wait() do
            if _G.SpeedEnabled then
                pcall(function()
                    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50
                end)
            else
                pcall(function()
                    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
                end)
            end
        end
    end)
end

return PlayerMovement

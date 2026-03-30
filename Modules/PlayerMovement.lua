local PlayerMovement = {}

function PlayerMovement.Init(Api)
    -- Speed Toggle
    _G.SpeedEnabled = false
    Api.CreateButton("Toggle Speed", function()
        _G.SpeedEnabled = not _G.SpeedEnabled
        print("Speed is: " .. tostring(_G.SpeedEnabled))
    end)

    -- Reset Button
    Api.CreateButton("Reset Character", function()
        if game.Players.LocalPlayer.Character then
            game.Players.LocalPlayer.Character:BreakJoints()
        end
    end)

    -- Speed Loop
    task.spawn(function()
        while task.wait() do
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = _G.SpeedEnabled and 60 or 16
            end
        end
    end)
end

return PlayerMovement

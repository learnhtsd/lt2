local PlayerMovement = {}

-- Notice we receive "Tab" instead of "Window" now
function PlayerMovement.Init(Tab)
    
    Tab:CreateSection("Movement Options")

    _G.SpeedEnabled = false
    Tab:CreateAction("Speed Hack", "Toggle", function()
        _G.SpeedEnabled = not _G.SpeedEnabled
        print("Speed hack is now: " .. tostring(_G.SpeedEnabled))
    end)

    Tab:CreateAction("Reset Character", "Kill", function()
        local char = game.Players.LocalPlayer.Character
        if char then
            char:BreakJoints()
        end
    end)

    Tab:CreateSection("Misc Options")
    
    Tab:CreateAction("Print Position", "Print", function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            print(tostring(char.HumanoidRootPart.Position))
        end
    end)

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

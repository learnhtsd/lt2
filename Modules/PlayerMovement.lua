local PlayerMovement = {}

function PlayerMovement.Init(Tab)
    
    Tab:CreateSection("Movement Options")

    -- Speed Hack Toggle (Using CreateAction since CreateToggle doesn't exist yet)
    _G.SpeedEnabled = false
    Tab:CreateAction("Speed Hack", "Toggle", function()
        _G.SpeedEnabled = not _G.SpeedEnabled
        print("Speed hack is now: " .. tostring(_G.SpeedEnabled))
    end)

    -- Reset Character
    Tab:CreateAction("Reset Character", "Kill", function()
        local char = game.Players.LocalPlayer.Character
        if char then
            char:BreakJoints()
        end
    end)

    -- Fast WalkSpeed (Using CreateAction since CreateSlider doesn't exist yet)
    Tab:CreateAction("Fast WalkSpeed (50)", "Apply", function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid").WalkSpeed = 50
        end
    end)

    Tab:CreateSection("Misc Options")
    
    -- Print Position
    Tab:CreateAction("Print Position", "Print", function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            print(tostring(char.HumanoidRootPart.Position))
        end
    end)

    -- Background loop to maintain Speed Hack
    task.spawn(function()
        while task.wait() do
            local char = game.Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if _G.SpeedEnabled then
                    hum.WalkSpeed = 60
                end
                -- Removed the "or 16" fallback here so it doesn't fight the "Fast WalkSpeed" button when the toggle is off
            end
        end
    end)

    -- Quick Teleport Keybind (Using native UserInputService since CreateKeybind doesn't exist yet)
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.E then
            print("E was pressed! (Quick Teleport Placeholder)")
        end
    end)

end

return PlayerMovement

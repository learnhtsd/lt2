local PlayerMovement = {}

-- Notice we receive "Tab" instead of "Window" now
function PlayerMovement.Init(Tab)
    
    Tab:CreateSection("Movement Options")

    _G.SpeedEnabled = false
    Tab:CreateAction("Speed Hack", "Toggle", function()
        _G.SpeedEnabled = not _G.SpeedEnabled
        print("Speed hack is now: " .. tostring(_G.SpeedEnabled))
-- Inside your module's Init function
function Module.Init(Tab)
    Tab:CreateToggle("Speed Hack", false, function(state)
        print("Speed is now: ", state)
        -- logic here
    end)

    Tab:CreateAction("Reset Character", "Kill", function()
        local char = game.Players.LocalPlayer.Character
        if char then
            char:BreakJoints()
        end
    Tab:CreateSlider("WalkSpeed", 16, 200, 16, function(value)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
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
    Tab:CreateKeybind("Quick Teleport", Enum.KeyCode.E, function()
        print("E was pressed!")
    end)
end

return PlayerMovement

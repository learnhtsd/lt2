local PlayerMovement = {}

function PlayerMovement.Init(Window)
    -- Create a Tab for Player Options (using a standard user icon ID)
    local PlayerTab = Window:CreateTab("rbxassetid://7733674079")

    -- Add a bold section title just like "Base Option" or "Land Option"
    PlayerTab:CreateSection("Movement Options")

    -- Add an action button layout (Text on left, button on right)
    _G.SpeedEnabled = false
    PlayerTab:CreateAction("Speed Hack", "Toggle", function()
        _G.SpeedEnabled = not _G.SpeedEnabled
        print("Speed hack is now: " .. tostring(_G.SpeedEnabled))
    end)

    PlayerTab:CreateAction("Reset Character", "Kill", function()
        local char = game.Players.LocalPlayer.Character
        if char then
            char:BreakJoints()
        end
    end)

    -- Example of a second section
    PlayerTab:CreateSection("Misc Options")
    
    PlayerTab:CreateAction("Print Position", "Print", function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            print(char.HumanoidRootPart.Position)
        end
    end)

    -- Background Loop for Speed
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

-- File: Modules/SuperSpeed.lua (SAVE INSIDE THE MODULES FOLDER)

local Hub = getgenv().Hub
if not Hub then error("This module requires the Main Hub framework to be running!") end

local Settings = {
    SpeedEnabled = false,
    Speed = 100
}

-- 1. Use the Hub API to add the elements. This requires NO UI logic on your part.
Hub:AddToggle("Enable Super Speed", false, function(State)
    Settings.SpeedEnabled = State
end)

-- Hub:AddSlider("Set Speed", 16, 500, 100, function(Value)
--     Settings.Speed = Value
-- end)

-- 2. Define the main function logic
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer

RunService.Heartbeat:Connect(function()
    if Settings.SpeedEnabled and Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.WalkSpeed = Settings.Speed
    elseif not Settings.SpeedEnabled and Player.Character and Player.Character:FindFirstChild("Humanoid") then
        if Player.Character.Humanoid.WalkSpeed ~= 16 then -- Prevent constant setting
            Player.Character.Humanoid.WalkSpeed = 16 -- Reset to default
        end
    end
end)

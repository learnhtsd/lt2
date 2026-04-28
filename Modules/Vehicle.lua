local VehicleModule = {}

-- Services
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Function to flip the vehicle
local function FlipVehicle()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
        local vehicleMain = humanoid.SeatPart.Parent
        local targetPart = vehicleMain:IsA("Model") and vehicleMain.PrimaryPart or humanoid.SeatPart

        if targetPart then
            -- Flip 180 degrees and nudge up to prevent clipping
            local currentCF = targetPart.CFrame
            local flipCF = currentCF * CFrame.Angles(0, 0, math.pi)
            
            targetPart.CFrame = flipCF + Vector3.new(0, 2, 0)
        end
    end
end

-- The Init function called by your Main Script
function VehicleModule.Init(Tab)
    Tab:CreateSection("Vehicle Utilities")

    -- Flip Button (Captured as a variable)
    local FlipButton = Tab:CreateAction("Flip Vehicle", "Flip 180°", function()
        FlipVehicle()
    end)
    
    FlipButton:AddTooltip("Flips your current vehicle right-side up. (Only active when driving)")

    -- Logic Loop: Handles button state
    task.spawn(function()
        local lastVehicleState = nil -- Track state to avoid redundant updates

        while task.wait(0.5) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local isInVehicle = !!(hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat"))

            -- Only update if the state has changed
            if isInVehicle ~= lastVehicleState then
                lastVehicleState = isInVehicle
                
                if isInVehicle then
                    FlipButton:SetDisabled(false)
                    FlipButton:SetText("Flip 180°")
                else
                    FlipButton:SetDisabled(true)
                    FlipButton:SetText("No Vehicle")
                end
            end
        end
    end)
end

return VehicleModule

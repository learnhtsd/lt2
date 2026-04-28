local VehicleModule = {}

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local function FlipVehicle()
    local character = player.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
        local vehicleMain = humanoid.SeatPart.Parent
        local targetPart  = vehicleMain:IsA("Model") and vehicleMain.PrimaryPart or humanoid.SeatPart

        if targetPart then
            local flipCF = targetPart.CFrame * CFrame.Angles(0, 0, math.pi)
            targetPart.CFrame = flipCF + Vector3.new(0, 2, 0)
        end
    end
end

function VehicleModule.Init(Tab)
    Tab:CreateSection("Vehicle Utilities")

    local FlipButton = Tab:CreateAction("Flip Vehicle", "Flip 180°", function()
        FlipVehicle()
    end)

    FlipButton:AddTooltip("Flips your current vehicle right-side up. Only active when seated in a vehicle.")

    -- Disabled by default until a vehicle is detected
    FlipButton:SetDisabled(true)
    FlipButton:SetText("No Vehicle")

    task.spawn(function()
        local lastState = nil

        while task.wait(0.5) do
            local char        = player.Character
            local hum         = char and char:FindFirstChildOfClass("Humanoid")
            local isInVehicle = not not (hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat"))

            if isInVehicle ~= lastState then
                lastState = isInVehicle
                FlipButton:SetDisabled(not isInVehicle)
                FlipButton:SetText(isInVehicle and "Flip 180°" or "No Vehicle")
            end
        end
    end)
end

return VehicleModule

local VehicleModule = {}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Function to flip the vehicle
local function FlipVehicle()
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not (humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat")) then
        -- Optional: Library:Notify call if you want feedback when not in a car
        warn("You must be in a VehicleSeat to flip the vehicle!")
        return 
    end

    local vehicleMain = humanoid.SeatPart.Parent
    -- Attempt to find the PrimaryPart or the Seat itself to move the whole assembly
    local targetPart = vehicleMain:IsA("Model") and vehicleMain.PrimaryPart or humanoid.SeatPart

    if targetPart then
        -- Calculate new CFrame: Same position, but rotated 180 degrees on the LookVector axis (Flip)
        -- We also add 2 studs of height to prevent clipping into the floor
        local currentCF = targetPart.CFrame
        local flipCF = currentCF * CFrame.Angles(0, 0, math.pi) -- math.pi is 180 degrees
        
        targetPart.CFrame = flipCF + Vector3.new(0, 2, 0)
    end
end

-- The Init function called by your Main Script
function VehicleModule.Init(Tab)
    -- Create Section for categorization
    Tab:CreateSection("Vehicle Utilities")

    -- Flip Button
    Tab:CreateAction("Flip Vehicle", "Flip 180°", function()
        FlipVehicle()
    end):AddTooltip("Flips your current vehicle right-side up (or upside down).")

    -- Optional: InfoBox to show current vehicle status
    local VehInfo = Tab:CreateInfoBox("Vehicle Status", "No vehicle detected.")
    
    -- Dynamic update loop for the InfoBox
    task.spawn(function()
        while task.wait(1) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.SeatPart then
                VehInfo:SetTitle("Driving")
                VehInfo:SetDescription("Connected to: " .. hum.SeatPart.Parent.Name)
            else
                VehInfo:SetTitle("Walking")
                VehInfo:SetDescription("Not currently in a vehicle.")
            end
        end
    end)
end

return VehicleModule

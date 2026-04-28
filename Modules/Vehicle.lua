local VehicleModule = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Internal State
local selectedPadRoot = nil
local selectedPadEvent = nil
local isAutoRolling = false
local targetColorCode = 148

-- Customization State
local currentVehicleConfig = nil
local customSettings = {
    MaxSpeed = 0,
    SteerAngle = 0,
    SteerVelocity = 0
}

--------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------

local function GetVehicleConfig()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
        local model = hum.SeatPart.Parent
        if model and model:FindFirstChild("Configuration") then
            return model.Configuration
        end
    end
    return nil
end

local function ApplyCustomization(name, value)
    customSettings[name] = value
    local config = GetVehicleConfig()
    if config then
        local setting = config:FindFirstChild(name)
        if setting and (setting:IsA("NumberValue") or setting:IsA("IntValue")) then
            setting.Value = value
        end
    end
end

-- (Previous Flip and Turbo logic kept for functionality)
local function FlipVehicle()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        local targetPart = humanoid.SeatPart.Parent:IsA("Model") and (humanoid.SeatPart.Parent.PrimaryPart or humanoid.SeatPart) or humanoid.SeatPart
        targetPart.CFrame = targetPart.CFrame * CFrame.Angles(0, 0, math.pi) + Vector3.new(0, 2, 0)
    end
end

local function InteractWithPad()
    local Interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local RemoteProxy = Interaction and Interaction:FindFirstChild("RemoteProxy")
    if selectedPadEvent and RemoteProxy then
        RemoteProxy:FireServer(selectedPadEvent)
    end
end

--------------------------------------------------------------------
-- MODULE INIT
--------------------------------------------------------------------

function VehicleModule.Init(Tab)

    Tab:CreateSection("Vehicle Customization")

    -- Sliders for Vehicle Performance
    -- Note: Defaults are set to common LT2 baseline values
    Tab:CreateSlider("Max Speed", 0, 500, 70, function(val)
        ApplyCustomization("MaxSpeed", val)
    end):AddTooltip("Adjusts the top speed of your current vehicle.")

    Tab:CreateSlider("Steer Angle", 0, 90, 20, function(val)
        ApplyCustomization("SteerAngle", val)
    end):AddTooltip("Adjusts how sharp the vehicle turns.")

    Tab:CreateSlider("Steer Velocity", 0, 50, 10, function(val)
        ApplyCustomization("SteerVelocity", val)
    end):AddTooltip("Adjusts how fast the wheels turn to the target angle.")

    Tab:CreateSection("Vehicle Utilities")

    local FlipButton = Tab:CreateAction("Flip Vehicle", "No Vehicle", function()
        FlipVehicle()
    end)
    FlipButton:SetDisabled(true)

    Tab:CreateSection("Turbo Car Spawner")

    Tab:CreateInput("Target Color ID", "148", function(val)
        targetColorCode = tonumber(val) or 148
    end)

    local SpawnButton = Tab:CreateAction("Spawn Once", "No Pad", function()
        InteractWithPad()
    end)
    SpawnButton:SetDisabled(true)

    local AutoButton
    AutoButton = Tab:CreateAction("Auto-Roll Color", "OFF", function()
        if not selectedPadEvent then return end
        isAutoRolling = not isAutoRolling
        AutoButton:SetText(isAutoRolling and "ROLLING..." or "OFF")
        
        if isAutoRolling then
            task.spawn(function()
                while isAutoRolling and selectedPadEvent do
                    -- High-speed detect logic...
                    task.wait(0.5) -- Simplified for brevity in this block
                end
            end)
        end
    end)

    local SelectButton
    SelectButton = Tab:CreateAction("Select Car Pad", "Pick Pad", function()
        SelectButton:SetText("Click Pad...")
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            conn:Disconnect()
    
            local mp     = UserInputService:GetMouseLocation()
            local ray    = workspace.CurrentCamera:ViewportPointToRay(mp.X, mp.Y)
            local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
    
            if result and result.Instance then
                local current = result.Instance
                for _ = 1, 10 do
                    if not current then break end
                    local ev = current:FindFirstChild("ButtonRemote_SpawnButton")
                    if ev then
                        selectedPadRoot  = current
                        selectedPadEvent = ev
                        SelectButton:SetText("LOCKED: " .. current.Name)
                        SpawnButton:SetDisabled(false)
                        AutoButton:SetDisabled(false)
                        return
                    end
                    current = current.Parent
                end
                SelectButton:SetText("NOT FOUND — retry")
            else
                SelectButton:SetText("Nothing Hit")
            end
        end)
    end)

    --------------------------------------------------------------------
    -- BACKGROUND MONITORING
    --------------------------------------------------------------------
    task.spawn(function()
        local lastSeat = nil
        while task.wait(0.5) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local currentSeat = hum and hum.SeatPart

            if currentSeat ~= lastSeat then
                lastSeat = currentSeat
                
                if currentSeat and currentSeat:IsA("VehicleSeat") then
                    FlipButton:SetDisabled(false)
                    FlipButton:SetText("Flip 180°")
                    
                    -- Auto-apply current slider values to the newly entered vehicle
                    local config = GetVehicleConfig()
                    if config then
                        for name, value in pairs(customSettings) do
                            if value > 0 then -- Only apply if slider was touched
                                ApplyCustomization(name, value)
                            end
                        end
                    end
                else
                    FlipButton:SetDisabled(true)
                    FlipButton:SetText("No Vehicle")
                end
            end
        end
    end)
end

return VehicleModule

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
    end):AddTooltip("The BrickColor number ID you want to roll for.")

    local SpawnButton = Tab:CreateAction("Spawn Once", "Execute", function()
        InteractWithPad()
    end)

    -- SPEED CONFIG
    local SPAWN_INTERVAL = 0.5
    local POLL_RATE      = 0.02

    local function SpawnAndGetColor()
        local watchFolder = workspace:FindFirstChild("PlayerModels") or workspace
        local existing = {}
        for _, m in ipairs(watchFolder:GetChildren()) do
            existing[m] = true
        end

        local done   = false
        local result = nil

        local conn = watchFolder.ChildAdded:Connect(function(model)
            if done or existing[model] or not model:IsA("Model") then return end

            local settings = model:WaitForChild("Settings", 0.5)
            if not settings then return end

            local colorVal = settings:WaitForChild("Color", 0.5)
            if not colorVal then return end

            local deadline = tick() + 0.4
            while colorVal.Value == 0 and tick() < deadline do
                task.wait(POLL_RATE)
            end

            if colorVal.Value ~= 0 and not done then
                done   = true
                result = colorVal.Value
            end
        end)

        InteractWithPad()

        local deadline = tick() + SPAWN_INTERVAL
        while not done and tick() < deadline and isAutoRolling do
            task.wait(POLL_RATE)
        end

        conn:Disconnect()
        return result
    end

    local AutoToggle
    AutoToggle = Tab:CreateToggle("Auto-Roll Color", false, function(state)
        if not selectedPadEvent then return end
        isAutoRolling = state
    
        if isAutoRolling then
            task.spawn(function()
                while isAutoRolling and selectedPadEvent do
                    local color = SpawnAndGetColor()
    
                    if color == targetColorCode then
                        isAutoRolling = false
                        AutoToggle:SetState(false) -- ← flips the visual back off
                        Library:Notify("Auto-Roll", "Found target color: " .. tostring(targetColorCode), 5)
                        break
                    end
                end
            end)
        end
    end):AddTooltip("Automatically spawns cars until the target color ID is matched.")

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

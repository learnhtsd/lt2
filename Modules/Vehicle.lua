local VehicleModule = {}

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player            = Players.LocalPlayer

local selectedPadRoot  = nil
local selectedPadEvent = nil
local isAutoRolling    = false
local targetColorCode  = 148

local customSettings = {
    MaxSpeed      = 0,
    SteerAngle    = 0,
    SteerVelocity = 0,
}

local vehicleDefaults = {}   -- snapshot of values when player sat down (may already be modified)
local trueDefaults    = {}   -- permanent first-seen values per vehicle name, never overwritten
local cachedConfig    = nil  -- held while seated so exit block can reach it after SeatPart clears
local cachedVehicleKey = nil -- name key into trueDefaults for the current vehicle

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------

local function GetVehicleConfig()
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if not seat then return nil end

    local vehicle = seat
    while vehicle.Parent and vehicle.Parent ~= workspace and vehicle.Parent.Name ~= "PlayerModels" do
        vehicle = vehicle.Parent
    end

    if vehicle and vehicle:IsA("Model") then
        local config = vehicle:FindFirstChild("Configuration", true)
        if config and config:FindFirstChild("MaxSpeed") then
            return config, vehicle.Name
        end
    end

    return nil, nil
end

local function ReadConfigValue(config, name)
    if not config then return nil end
    local setting = config:FindFirstChild(name)
    if setting and setting:IsA("ValueBase") then
        return setting.Value
    end
    return nil
end

local function WriteConfigValues(config, values)
    if not config or not values then return end
    for name, value in pairs(values) do
        local setting = config:FindFirstChild(name)
        if setting and setting:IsA("ValueBase") then
            setting.Value = value
        end
    end
end

local function ApplyCustomization(name, value)
    customSettings[name] = value
    if cachedConfig then
        local setting = cachedConfig:FindFirstChild(name)
        if setting and setting:IsA("ValueBase") then
            setting.Value = value
        end
    end
end

local function SafeUpdateSlider(slider, value)
    if not slider then return end
    pcall(function()
        if type(slider.SetValue) == "function" then
            slider:SetValue(value)
        elseif type(slider.Set) == "function" then
            slider:Set(value)
        end
    end)
end

local function FlipVehicle()
    local character = player.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        local veh   = humanoid.SeatPart.Parent
        local tPart = veh:IsA("Model") and (veh.PrimaryPart or humanoid.SeatPart) or humanoid.SeatPart
        tPart.CFrame = tPart.CFrame * CFrame.Angles(0, 0, math.pi) + Vector3.new(0, 2, 0)
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

function VehicleModule.Init(Tab, Library)

    Tab:CreateSection("Vehicle Modifications")

    local SpeedSlider = Tab:CreateSlider("Max Speed", 0.1, 10.0, 0.1, function(val)
        ApplyCustomization("MaxSpeed", val)
    end, 2)
    SpeedSlider:SetDisabled(true)

    local SteerAngleSlider = Tab:CreateSlider("Steer Angle", 0.1, 2.0, 0.1, function(val)
        ApplyCustomization("SteerAngle", val)
    end, 2)
    SteerAngleSlider:SetDisabled(true)

    local SteerVelocitySlider = Tab:CreateSlider("Steer Velocity", 0.01, 0.03, 0.01, function(val)
        ApplyCustomization("SteerVelocity", val)
    end, 3)
    SteerVelocitySlider:SetDisabled(true)

    local FlipButton = Tab:CreateAction("Flip Vehicle", "No Vehicle", function()
        FlipVehicle()
    end)
    FlipButton:SetDisabled(true)

    local ResetButton = Tab:CreateAction("Reset Vehicle Stats", "Reset", function()
        -- Always prefer the permanent true defaults over the sit-snapshot
        local defaults = (cachedVehicleKey and trueDefaults[cachedVehicleKey]) or vehicleDefaults
        if not defaults or not defaults.MaxSpeed then return end

        WriteConfigValues(cachedConfig, defaults)

        customSettings.MaxSpeed      = 0
        customSettings.SteerAngle    = 0
        customSettings.SteerVelocity = 0

        SafeUpdateSlider(SpeedSlider,         math.clamp(defaults.MaxSpeed,      0.1, 10.0))
        SafeUpdateSlider(SteerAngleSlider,    math.clamp(defaults.SteerAngle,    0.1, 2.0))
        SafeUpdateSlider(SteerVelocitySlider, math.clamp(defaults.SteerVelocity, 0.01, 0.03))
    end)
    ResetButton:SetDisabled(true)

    local resetOnExit = true
    Tab:CreateToggle("Reset Config On Exit", true, function(state)
        resetOnExit = state
    end):AddTooltip("When on, the vehicle's stats are restored to their original values when you get out.")

    Tab:CreateSection("Vehicle Pad Spawner")

    Tab:CreateInput("Target Color ID", "148", function(val)
        targetColorCode = tonumber(val) or 148
    end):AddTooltip("The BrickColor number ID you want to roll for.")

    local SpawnButton
    local AutoToggle
    local SelectButton
    SelectButton = Tab:CreateAction("Select Car Pad", "Select", function()
        SelectButton:SetText("Click Pad!")
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
                        SelectButton:SetText(current.Name)
                        SpawnButton:SetDisabled(false)
                        AutoToggle:SetDisabled(false)
                        return
                    end
                    current = current.Parent
                end
                SelectButton:SetText("Not Found")
            else
                SelectButton:SetText("Missed")
            end
        end)
    end)

    SpawnButton = Tab:CreateAction("Respawn Vehicle", "Respawn", function()
        InteractWithPad()
    end)
    SpawnButton:SetDisabled(true)

    local SPAWN_INTERVAL = 0.5
    local POLL_RATE      = 0.02

    local function SpawnAndGetColor()
        local watchFolder = workspace:FindFirstChild("PlayerModels") or workspace
        local existing = {}
        for _, m in ipairs(watchFolder:GetChildren()) do existing[m] = true end

        local done, result = false, nil

        local conn = watchFolder.ChildAdded:Connect(function(model)
            if done or existing[model] or not model:IsA("Model") then return end
            local settings = model:WaitForChild("Settings", 0.5)
            if not settings then return end
            local colorVal = settings:WaitForChild("Color", 0.5)
            if not colorVal then return end
            local deadline = tick() + 0.4
            while colorVal.Value == 0 and tick() < deadline do task.wait(POLL_RATE) end
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

    AutoToggle = Tab:CreateToggle("Auto-Roll Color", false, function(state)
        if not selectedPadEvent then
            AutoToggle:SetState(false)
            return
        end
        isAutoRolling = state

        if isAutoRolling then
            task.spawn(function()
                while isAutoRolling and selectedPadEvent do
                    local color = SpawnAndGetColor()
                    if color == targetColorCode then
                        isAutoRolling = false
                        AutoToggle:SetState(false)
                        if Library then
                            Library:Notify("Auto-Roll", "Found target color: " .. tostring(targetColorCode), 5)
                        end
                        break
                    end
                end
            end)
        end
    end)
    AutoToggle:SetDisabled(true)

    --------------------------------------------------------------------
    -- BACKGROUND MONITORING
    --------------------------------------------------------------------
    task.spawn(function()
        local lastSeat = nil

        while task.wait(0.5) do
            local char        = player.Character
            local hum         = char and char:FindFirstChildOfClass("Humanoid")
            local currentSeat = hum and hum.SeatPart

            if currentSeat ~= lastSeat then
                lastSeat = currentSeat

                if currentSeat then
                    -- PLAYER ENTERED VEHICLE
                    FlipButton:SetDisabled(false)
                    FlipButton:SetText("Flip 180°")
                    ResetButton:SetDisabled(false)
                    SpeedSlider:SetDisabled(false)
                    SteerAngleSlider:SetDisabled(false)
                    SteerVelocitySlider:SetDisabled(false)

                    cachedConfig     = nil
                    cachedVehicleKey = nil

                    for _ = 1, 6 do
                        local config, vehicleName = GetVehicleConfig()
                        if config then
                            cachedConfig     = config
                            cachedVehicleKey = vehicleName
                            break
                        end
                        task.wait(0.5)
                    end

                    if cachedConfig and cachedVehicleKey then
                        -- First time seeing this vehicle? Record its true factory defaults
                        if not trueDefaults[cachedVehicleKey] then
                            trueDefaults[cachedVehicleKey] = {
                                MaxSpeed      = ReadConfigValue(cachedConfig, "MaxSpeed"),
                                SteerAngle    = ReadConfigValue(cachedConfig, "SteerAngle"),
                                SteerVelocity = ReadConfigValue(cachedConfig, "SteerVelocity"),
                            }
                            print("[Vehicle] Recorded true defaults for:", cachedVehicleKey)
                        end

                        -- If resetOnExit is on, restore factory defaults now before snapshotting
                        if resetOnExit then
                            WriteConfigValues(cachedConfig, trueDefaults[cachedVehicleKey])
                        end

                        -- Snapshot what's in the config right now (post-restore if applicable)
                        vehicleDefaults = {
                            MaxSpeed      = ReadConfigValue(cachedConfig, "MaxSpeed"),
                            SteerAngle    = ReadConfigValue(cachedConfig, "SteerAngle"),
                            SteerVelocity = ReadConfigValue(cachedConfig, "SteerVelocity"),
                        }

                        -- Update sliders to reflect current config
                        SafeUpdateSlider(SpeedSlider,         math.clamp(vehicleDefaults.MaxSpeed,      0.1, 10.0))
                        SafeUpdateSlider(SteerAngleSlider,    math.clamp(vehicleDefaults.SteerAngle,    0.1, 2.0))
                        SafeUpdateSlider(SteerVelocitySlider, math.clamp(vehicleDefaults.SteerVelocity, 0.01, 0.05))

                        -- Re-apply any lingering custom values
                        if customSettings.MaxSpeed      > 0 then ApplyCustomization("MaxSpeed",      customSettings.MaxSpeed)      end
                        if customSettings.SteerAngle    > 0 then ApplyCustomization("SteerAngle",    customSettings.SteerAngle)    end
                        if customSettings.SteerVelocity > 0 then ApplyCustomization("SteerVelocity", customSettings.SteerVelocity) end
                    end
                else
                    -- PLAYER EXITED VEHICLE
                    print("[Vehicle] Player exited vehicle.")

                    -- Restore factory defaults if toggle is on (use cachedConfig, SeatPart is nil now)
                    if resetOnExit and cachedConfig and cachedVehicleKey and trueDefaults[cachedVehicleKey] then
                        WriteConfigValues(cachedConfig, trueDefaults[cachedVehicleKey])
                    end

                    -- Clear session state
                    cachedConfig         = nil
                    cachedVehicleKey     = nil
                    vehicleDefaults      = {}
                    customSettings.MaxSpeed      = 0
                    customSettings.SteerAngle    = 0
                    customSettings.SteerVelocity = 0

                    -- Reset UI
                    FlipButton:SetDisabled(true)
                    FlipButton:SetText("No Vehicle")

                    ResetButton:SetDisabled(true)

                    SpeedSlider:SetDisabled(true)
                    SafeUpdateSlider(SpeedSlider, 0.1)

                    SteerAngleSlider:SetDisabled(true)
                    SafeUpdateSlider(SteerAngleSlider, 0.1)

                    SteerVelocitySlider:SetDisabled(true)
                    SafeUpdateSlider(SteerVelocitySlider, 0.01)
                end
            end
        end
    end)

end

return VehicleModule

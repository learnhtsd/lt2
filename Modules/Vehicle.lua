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

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------

local function GetVehicleConfig()
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then
        print("[Vehicle] GetVehicleConfig: No seat found")
        return nil
    end

    local playerModels = workspace:FindFirstChild("PlayerModels")
    if not playerModels then
        print("[Vehicle] GetVehicleConfig: PlayerModels not found in workspace")
        return nil
    end

    -- Walk up from the seat until we find the Model directly under PlayerModels
    local part = hum.SeatPart
    print("[Vehicle] Starting walk from:", part.Name, part.ClassName)
    while part and part.Parent ~= playerModels do
        print("[Vehicle]   walking up:", part.Name, "-> parent:", part.Parent and part.Parent.Name or "nil")
        part = part.Parent
    end

    if part and part:IsA("Model") then
        print("[Vehicle] Landed on model:", part.Name)
        local config = part:FindFirstChild("Configuration")
        if config then
            print("[Vehicle] Found Configuration, values:")
            for _, v in ipairs(config:GetChildren()) do
                print("  >>", v.Name, v.ClassName, v.Value)
            end
            return config
        else
            print("[Vehicle] Configuration NOT found. Model children:")
            for _, v in ipairs(part:GetChildren()) do
                print("  >>", v.Name, v.ClassName)
            end
        end
    else
        print("[Vehicle] Walk failed — part:", part and part.Name or "nil")
    end

    return nil
end

local function ReadConfigValue(config, name)
    if not config then return nil end
    local setting = config:FindFirstChild(name)
    if setting and (setting:IsA("NumberValue") or setting:IsA("IntValue")) then
        return setting.Value
    end
    print("[Vehicle] ReadConfigValue: '" .. name .. "' not found or wrong type")
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

    Tab:CreateSection("Vehicle Customization")

    local SpeedSlider = Tab:CreateSlider("Max Speed", 0.1, 2.0, 0.1, function(val)
        ApplyCustomization("MaxSpeed", val)
    end, 2)
    SpeedSlider:SetDisabled(true)
    SpeedSlider:AddTooltip("LT2 range: 0.1 – 2.0. Higher = faster top speed.")

    local SteerAngleSlider = Tab:CreateSlider("Steer Angle", 0.1, 2.0, 0.1, function(val)
        ApplyCustomization("SteerAngle", val)
    end, 2)
    SteerAngleSlider:SetDisabled(true)
    SteerAngleSlider:AddTooltip("LT2 range: 0.1 – 2.0. Higher = sharper turns.")

    local SteerVelocitySlider = Tab:CreateSlider("Steer Velocity", 0.01, 0.05, 0.01, function(val)
        ApplyCustomization("SteerVelocity", val)
    end, 3)
    SteerVelocitySlider:SetDisabled(true)
    SteerVelocitySlider:AddTooltip("LT2 range: 0.01 – 0.05. How fast wheels rotate to target angle.")

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
                        AutoToggle:SetState(false)
                        if Library then
                            Library:Notify("Auto-Roll", "Found target color: " .. tostring(targetColorCode), 5)
                        end
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
            local char        = player.Character
            local hum         = char and char:FindFirstChildOfClass("Humanoid")
            local currentSeat = hum and hum.SeatPart

            if currentSeat ~= lastSeat then
                lastSeat = currentSeat

                if currentSeat and currentSeat:IsA("VehicleSeat") then
                    print("[Vehicle] Seat detected:", currentSeat.Name, "| parent:", currentSeat.Parent and currentSeat.Parent.Name or "nil")

                    FlipButton:SetDisabled(false)
                    FlipButton:SetText("Flip 180°")
                    SpeedSlider:SetDisabled(false)
                    SteerAngleSlider:SetDisabled(false)
                    SteerVelocitySlider:SetDisabled(false)

                    -- Wait for server replication
                    task.wait(0.8)

                    local config = GetVehicleConfig()
                    if config then
                        local speed    = ReadConfigValue(config, "MaxSpeed")
                        local angle    = ReadConfigValue(config, "SteerAngle")
                        local velocity = ReadConfigValue(config, "SteerVelocity")

                        print("[Vehicle] Raw read — MaxSpeed:", speed, "| SteerAngle:", angle, "| SteerVelocity:", velocity)

                        if speed ~= nil then
                            local clamped = math.clamp(speed, 0.1, 2.0)
                            print("[Vehicle] SetValue SpeedSlider ->", clamped)
                            SpeedSlider:SetValue(clamped)
                        end
                        if angle ~= nil then
                            local clamped = math.clamp(angle, 0.1, 2.0)
                            print("[Vehicle] SetValue SteerAngleSlider ->", clamped)
                            SteerAngleSlider:SetValue(clamped)
                        end
                        if velocity ~= nil then
                            local clamped = math.clamp(velocity, 0.01, 0.05)
                            print("[Vehicle] SetValue SteerVelocitySlider ->", clamped)
                            SteerVelocitySlider:SetValue(clamped)
                        end

                        -- Re-apply player customisations only if explicitly changed
                        if customSettings.MaxSpeed > 0 and customSettings.MaxSpeed ~= speed then
                            ApplyCustomization("MaxSpeed", customSettings.MaxSpeed)
                        end
                        if customSettings.SteerAngle > 0 and customSettings.SteerAngle ~= angle then
                            ApplyCustomization("SteerAngle", customSettings.SteerAngle)
                        end
                        if customSettings.SteerVelocity > 0 and customSettings.SteerVelocity ~= velocity then
                            ApplyCustomization("SteerVelocity", customSettings.SteerVelocity)
                        end
                    else
                        print("[Vehicle] Config was nil after wait — sliders not synced")
                    end
                else
                    FlipButton:SetDisabled(true)
                    FlipButton:SetText("No Vehicle")
                    SpeedSlider:SetDisabled(true)
                    SpeedSlider:SetValue(0.1)
                    SteerAngleSlider:SetDisabled(true)
                    SteerAngleSlider:SetValue(0.1)
                    SteerVelocitySlider:SetDisabled(true)
                    SteerVelocitySlider:SetValue(0.01)
                end
            end
        end
    end)
end

return VehicleModule

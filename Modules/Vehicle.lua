local VehicleModule = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player           = Players.LocalPlayer

-- ── Flip ─────────────────────────────────────────────────────
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

-- ── Car pad interaction ───────────────────────────────────────
-- Walks up the instance tree looking for a ProximityPrompt or
-- ClickDetector, then fires it via executor helper functions.
local function InteractWithPad(instance)
    if not instance then return false end

    local current = instance
    for _ = 0, 6 do
        -- ProximityPrompt (most common in modern LT2 pads)
        local prompt = current:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            if fireproximityprompt then
                fireproximityprompt(prompt)
                return true
            end
        end

        -- ClickDetector fallback
        local cd = current:FindFirstChildOfClass("ClickDetector")
        if cd then
            if fireclickdetector then
                fireclickdetector(cd)
                return true
            end
        end

        if current.Parent == nil or current.Parent == workspace then break end
        current = current.Parent
    end

    return false
end

-- Raycast from the camera through the current mouse screen position
local function GetMouseTarget()
    local camera  = workspace.CurrentCamera
    local mouse   = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000)
    return result and result.Instance or nil
end

-- ── Init ─────────────────────────────────────────────────────
function VehicleModule.Init(Tab)

    -- ── Flip ─────────────────────────────────────────────────
    Tab:CreateSection("Vehicle Utilities")

    local FlipButton = Tab:CreateAction("Flip Vehicle", "Flip 180°", function()
        FlipVehicle()
    end)
    FlipButton:AddTooltip("Flips your current vehicle right-side up. Only active when seated in a vehicle.")
    FlipButton:SetDisabled(true)
    FlipButton:SetText("No Vehicle")

    -- ── Car spawner ───────────────────────────────────────────
    Tab:CreateSection("Car Spawner")

    local selectedPad    = nil
    local pickingMode    = false
    local pickConnection = nil

    -- Spawn button — fires the saved pad, disabled until one is picked
    local SpawnButton = Tab:CreateAction("Spawn Car", "Spawn", function()
        if selectedPad and selectedPad.Parent then
            local ok = InteractWithPad(selectedPad)
            if not ok then
                warn("[Vehicle] Could not interact with saved pad — try reselecting.")
            end
        end
    end)
    SpawnButton:AddTooltip("Spawns a car using the last selected car pad. Pick a pad first.")
    SpawnButton:SetDisabled(true)
    SpawnButton:SetText("No Pad")

    -- Select button — enters pick mode then waits for a world click
    local SelectButton = Tab:CreateAction("Select Car Pad", "Pick", function()
        if pickingMode then return end

        pickingMode = true
        SelectButton:SetText("Click Pad...")
        SelectButton:SetDisabled(true)

        pickConnection = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

            pickConnection:Disconnect()
            pickConnection = nil
            pickingMode    = false

            local target = GetMouseTarget()

            if target then
                selectedPad = target

                SelectButton:SetText("Repick")
                SelectButton:SetDisabled(false)
                SpawnButton:SetDisabled(false)
                SpawnButton:SetText("Spawn")

                -- Interact immediately on first pick so the car spawns right away
                InteractWithPad(selectedPad)
            else
                -- Missed (clicked sky etc.) — reset without saving
                SelectButton:SetText("Pick")
                SelectButton:SetDisabled(false)
                warn("[Vehicle] No target found. Click directly on the car pad spawn button.")
            end
        end)
    end)
    SelectButton:AddTooltip("Click this, then left-click a car pad in the world. Simulates pressing E to spawn your vehicle instantly.")

    -- ── Vehicle seat polling ──────────────────────────────────
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

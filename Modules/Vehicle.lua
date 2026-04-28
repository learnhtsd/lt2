local VehicleModule = {}

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player           = Players.LocalPlayer

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

local function GetRootModel(instance)
    local current = instance
    while current and current.Parent and not current.Parent:IsA("Workspace") do
        current = current.Parent
    end
    return current
end

-- LT2 pads use a RemoteEvent called ButtonRemote_SpawnButton.
-- FireServer() is all that is needed.
local function InteractWithPad(instance)
    if not instance then return false end

    local root = GetRootModel(instance)
    if not root then return false end

    -- Strategy 1: ButtonRemote_SpawnButton (primary LT2 method)
    local remote = root:FindFirstChild("ButtonRemote_SpawnButton")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
        return true
    end

    -- Strategy 2: Any RemoteEvent with spawn/button in the name
    for _, child in ipairs(root:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            local n = child.Name:lower()
            if n:find("spawn") or n:find("button") then
                child:FireServer()
                return true
            end
        end
    end

    -- Strategy 3: ProximityPrompt
    local prompt = root:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        fireproximityprompt(prompt)
        return true
    end

    -- Strategy 4: firetouchinterest on SpawnButton mesh
    local spawnModel = root:FindFirstChild("SpawnButton")
    if spawnModel then
        local part = spawnModel:FindFirstChildOfClass("MeshPart")
                  or spawnModel:FindFirstChildOfClass("Part")
                  or spawnModel:FindFirstChildOfClass("UnionOperation")
        if part and firetouchinterest then
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                firetouchinterest(hrp, part, 0)
                task.wait(0.1)
                firetouchinterest(hrp, part, 1)
                return true
            end
        end
    end

    -- Strategy 5: ClickDetector
    local cd = root:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then
        fireclickdetector(cd)
        return true
    end

    return false
end

local function GetMouseTarget()
    local camera  = workspace.CurrentCamera
    local mouse   = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000)
    return result and result.Instance or nil
end

function VehicleModule.Init(Tab)

    Tab:CreateSection("Vehicle Utilities")

    local FlipButton = Tab:CreateAction("Flip Vehicle", "Flip 180°", function()
        FlipVehicle()
    end)
    FlipButton:AddTooltip("Flips your current vehicle right-side up. Only active when seated.")
    FlipButton:SetDisabled(true)
    FlipButton:SetText("No Vehicle")

    Tab:CreateSection("Car Spawner")

    local selectedPad    = nil
    local pickingMode    = false
    local pickConnection = nil

    local SpawnButton = Tab:CreateAction("Spawn Car", "Spawn", function()
        if selectedPad and selectedPad.Parent then
            local ok = InteractWithPad(selectedPad)
            if not ok then
                warn("[Vehicle] Could not interact with pad — try reselecting.")
            end
        end
    end)
    SpawnButton:AddTooltip("Spawns a car at the selected pad. Use Select Car Pad first.")
    SpawnButton:SetDisabled(true)
    SpawnButton:SetText("No Pad")

    local SelectButton
    SelectButton = Tab:CreateAction("Select Car Pad", "Pick", function()
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
                InteractWithPad(selectedPad)
            else
                SelectButton:SetText("Pick")
                SelectButton:SetDisabled(false)
                warn("[Vehicle] No target found. Click directly on the car pad.")
            end
        end)
    end)
    SelectButton:AddTooltip("Click, then left-click a car pad in the world to select and spawn your vehicle.")

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

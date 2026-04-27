-- [[ LOOSE OBJECT TELEPORT MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local LooseObjectTeleport = {}

local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService   = game:GetService("GuiService")
local Players      = game:GetService("Players")
local Player       = Players.LocalPlayer
local Camera       = workspace.CurrentCamera
local StarterGui   = game:GetService("StarterGui")
local Mouse        = Player:GetMouse()

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     CONFIGURATION & STATE                       │
-- └─────────────────────────────────────────────────────────────────┘
local Settings = {
    PreClickDelay          = 0.08,
    BetweenRetryDelay      = 0.05,
    PostSyncDelay          = 0.01,
    CFrameNudgeDelay       = 0.05,
    PostGrabDelay          = 0.05,
    PostBatchDelay         = 0.01,
    OwnershipMoveThreshold = 0.05,
    OwnershipTimeout       = 2,
    MaxRetries             = 5,
    GapDistance            = 6,
    CleanRadius            = 12,
    LockMouseMovement      = true,
    SelectionColor         = Color3.fromRGB(50, 50, 255),
    OutlineThickness       = 0.02,
    
    -- Stacking Config
    StackX = 1,
    StackY = 5,
    StackZ = 1,
}

local State = {
    SelectedObjects  = {},
    SelectionBoxes   = {},
    Connections      = {},
    TempDeleted      = {},
    BatchCancelled   = false,
    
    ClickSelectMode  = false,
    GroupSelectMode  = false,
    LassoMode        = false,
    LassoDragging    = false,
    LassoStartPos    = nil,
    LassoGui         = nil,
    LassoFrame       = nil,
    
    -- Stacking State
    IsPreviewing     = false,
    PreviewFolder    = nil,
    PreviewCFrame    = CFrame.new(),
    
    Library          = nil, 
}

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        HELPER FUNCTIONS                         │
-- └─────────────────────────────────────────────────────────────────┘

local function Notify(title, text, duration)
    if State.Library and State.Library.Notify then
        State.Library:Notify(title, text, duration or 2)
    else
        StarterGui:SetCore("SendNotification", {
            Title    = title;
            Text     = text;
            Duration = duration or 2;
        })
    end
end

local function GetOwnerIdentity(model)
    if not model then return nil end
    local ownerValue = model:FindFirstChild("Owner")
    if ownerValue then
        local val = ownerValue.Value
        if typeof(val) == "Instance" and val:IsA("Player") then
            return val.Name
        end
        return tostring(val)
    end
    return nil
end

local function GetModelSignature(model)
    local mainPart  = model:FindFirstChild("Main") or model:FindFirstChildWhichIsA("BasePart")
    local mainClass = mainPart and mainPart.ClassName or "nil"
    local childKeys = {}
    for _, child in ipairs(model:GetChildren()) do
        table.insert(childKeys, child.ClassName .. ":" .. child.Name)
    end
    table.sort(childKeys)
    return mainClass .. "|" .. table.concat(childKeys, ",")
end

local function GetTreeClass(model)
    local tc = model:FindFirstChild("TreeClass")
    return tc and tostring(tc.Value) or nil
end

local function getObjectData(target)
    if not target or not target:IsA("BasePart") or target.Anchored then return nil end
    if target:IsDescendantOf(Player.Character) then return nil end
    local model = target:FindFirstAncestorOfClass("Model")
    local main  = (model and model:FindFirstChild("Main")) or target
    if main:IsA("BasePart") and not main.Anchored then
        return main, (model and model.Name or target.Name), model
    end
    return nil
end

local function SetCharacterGhosting(char, ghost)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.LocalTransparencyModifier = ghost and 1 or 0
            part.CanCollide = not ghost
        end
    end
end

local function UpdateVisuals()
    for _, v in pairs(State.SelectionBoxes) do v:Destroy() end
    State.SelectionBoxes = {}
    
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            local box         = Instance.new("SelectionBox")
            box.Color3        = Settings.SelectionColor
            box.LineThickness = Settings.OutlineThickness
            box.Adornee       = obj
            box.Parent        = game:GetService("CoreGui")
            table.insert(State.SelectionBoxes, box)
        end
    end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        STACK PREVIEW ENGINE                     │
-- └─────────────────────────────────────────────────────────────────┘

local function ClearPreview()
    State.IsPreviewing = false
    if State.PreviewFolder then
        State.PreviewFolder:Destroy()
        State.PreviewFolder = nil
    end
end

local function StartStackPreview()
    if #State.SelectedObjects == 0 then return Notify("Error", "No items selected.") end
    
    -- Verify identical types
    local firstModel = State.SelectedObjects[1]:FindFirstAncestorOfClass("Model") or State.SelectedObjects[1]
    local firstSig = GetModelSignature(firstModel)
    
    for i = 2, #State.SelectedObjects do
        local m = State.SelectedObjects[i]:FindFirstAncestorOfClass("Model") or State.SelectedObjects[i]
        if GetModelSignature(m) ~= firstSig then
            return Notify("Error", "Multiple item types selected. Cannot stack mixed items.")
        end
    end

    ClearPreview()
    State.IsPreviewing = true
    
    local folder = Instance.new("Folder")
    folder.Name = "StackPreview"
    folder.Parent = workspace
    State.PreviewFolder = folder

    local itemSize = State.SelectedObjects[1].Size
    local count = 0
    
    -- Create visual ghosts
    for y = 0, Settings.StackY - 1 do
        for x = 0, Settings.StackX - 1 do
            for z = 0, Settings.StackZ - 1 do
                count = count + 1
                if count > #State.SelectedObjects then break end
                
                local ghost = Instance.new("Part")
                ghost.Size = itemSize
                ghost.Color = Color3.fromRGB(100, 255, 100)
                ghost.Transparency = 0.6
                ghost.CanCollide = false
                ghost.Anchored = true
                ghost.Material = Enum.Material.ForceField
                ghost.Name = "Ghost_" .. count
                
                -- Relative offset
                local offset = Vector3.new(x * itemSize.X, y * itemSize.Y, z * itemSize.Z)
                ghost.Parent = folder
                
                -- Tag the offset for the actual TP logic later
                local val = Instance.new("Vector3Value")
                val.Name = "Offset"
                val.Value = offset
                val.Parent = ghost
            end
        end
    end
    
    Notify("Preview", "Left Click to place stack. Right Click/Stop to cancel.")
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        EXECUTION LOGIC                          │
-- └─────────────────────────────────────────────────────────────────┘

local function WaitForOwnership(target)
    local startPos = target.Position
    local deadline = tick() + Settings.OwnershipTimeout
    while tick() < deadline do
        RunService.Heartbeat:Wait()
        if not target or not target.Parent then break end
        if (target.Position - startPos).Magnitude >= Settings.OwnershipMoveThreshold then
            return true
        end
    end
    return false
end

local function GrabAndTeleport(currentTarget, targetGoalCF, char, head, root, originalParents)
    currentTarget.Parent = originalParents[currentTarget] or workspace
    
    -- Ghosting environment
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {char, currentTarget}
    for _, part in ipairs(workspace:GetPartBoundsInRadius(currentTarget.Position, Settings.CleanRadius, overlapParams)) do
        local n = string.lower(part.Name)
        if part:IsA("BasePart") and n ~= "baseplate" and n ~= "ground" and n ~= "terrain" then
            table.insert(State.TempDeleted, {Part = part, OldParent = part.Parent})
            part.Parent = nil
        end
    end

    local size = currentTarget.Size
    local cf   = currentTarget.CFrame
    local worldHalfHeight = math.abs(cf.UpVector.Y)   * (size.Y * 0.5)
                          + math.abs(cf.RightVector.Y) * (size.X * 0.5)
                          + math.abs(cf.LookVector.Y)  * (size.Z * 0.5)
    local hoverPos = currentTarget.Position + Vector3.new(0, worldHalfHeight + Settings.GapDistance, 0)
    local hoverCF  = CFrame.lookAt(hoverPos, currentTarget.Position)

    local playerLock = RunService.Heartbeat:Connect(function()
        if root then
            root.CFrame = hoverCF
            root.AssemblyLinearVelocity = Vector3.zero
        end
        if Settings.LockMouseMovement and head and currentTarget then
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame     = CFrame.lookAt(head.Position, currentTarget.Position)
        end
    end)

    task.wait(Settings.PreClickDelay)

    local attempts = 0
    local detected = false
    while not detected and attempts < Settings.MaxRetries do
        attempts = attempts + 1
        mouse1press()
        detected = WaitForOwnership(currentTarget)
        mouse1release()
        if not detected and attempts < Settings.MaxRetries then
            task.wait(Settings.BetweenRetryDelay)
        end
    end

    playerLock:Disconnect()
    Camera.CameraType = Enum.CameraType.Custom

    for _, data in ipairs(State.TempDeleted) do
        if data.Part then data.Part.Parent = data.OldParent end
    end
    State.TempDeleted = {}

    if currentTarget and currentTarget.Parent then
        local tpLock = RunService.Heartbeat:Connect(function()
            if currentTarget and currentTarget.Parent then
                currentTarget.CFrame                  = targetGoalCF
                currentTarget.AssemblyLinearVelocity  = Vector3.zero
                currentTarget.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        task.wait(Settings.PostSyncDelay)
        tpLock:Disconnect()

        if currentTarget and currentTarget.Parent then
            currentTarget.CFrame = targetGoalCF * CFrame.new(0, 0.05, 0)
            task.wait(Settings.CFrameNudgeDelay)
            currentTarget.CFrame = targetGoalCF
        end
    end

    task.wait(Settings.PostGrabDelay)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     BUTTON / HOTKEY ACTIONS                     │
-- └─────────────────────────────────────────────────────────────────┘

local function PerformExecute(customGoals)
    if #State.SelectedObjects > 0 and Player.Character then
        local char = Player.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local head = char:FindFirstChild("Head")
        if not root or not head or not hum then return end

        State.BatchCancelled = false
        Notify("Batch Start", "Syncing " .. #State.SelectedObjects .. " items...", 3)

        local originalCharCFrame = root.CFrame
        Player.CameraMode = Enum.CameraMode.LockFirstPerson
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        hum.PlatformStand = true
        SetCharacterGhosting(char, true)

        local OriginalParents = {}
        for _, obj in ipairs(State.SelectedObjects) do
            if obj and obj.Parent then
                OriginalParents[obj] = obj.Parent
                obj.Parent = nil
            end
        end

        local snapshot = {table.unpack(State.SelectedObjects)}
        for i, currentTarget in ipairs(snapshot) do
            if not currentTarget then continue end
            if State.BatchCancelled then
                local op = OriginalParents[currentTarget]
                if op then currentTarget.Parent = op end
                continue
            end

            -- If customGoals (stacking) is provided, use the specific CFrame for this index
            local goal = customGoals and customGoals[i] or (originalCharCFrame * CFrame.new(0, 0.5, 0) * currentTarget.CFrame.Rotation)
            GrabAndTeleport(currentTarget, goal, char, head, root, OriginalParents)
        end

        task.wait(Settings.PostBatchDelay)

        SetCharacterGhosting(char, false)
        hum.PlatformStand = false
        Camera.CameraType = Enum.CameraType.Custom
        Player.CameraMode = Enum.CameraMode.Classic
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        root.AssemblyLinearVelocity = Vector3.zero
        
        char:PivotTo(originalCharCFrame * CFrame.new(0, 10, 0))
        State.SelectedObjects = {}
        UpdateVisuals()
        Notify("Finished", State.BatchCancelled and "Batch cancelled." or "Batch complete.", 3)
    end
end

local function ExecuteStackPlacement()
    if not State.PreviewFolder then return end
    
    local goals = {}
    local ghosts = State.PreviewFolder:GetChildren()
    table.sort(ghosts, function(a, b) 
        return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+")) 
    end)
    
    for i, ghost in ipairs(ghosts) do
        goals[i] = ghost.CFrame
    end
    
    ClearPreview()
    PerformExecute(goals)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       MODULE INITIALIZE                         │
-- └─────────────────────────────────────────────────────────────────┘

function LooseObjectTeleport.Init(Tab, LibraryInstance)
    State.Library = LibraryInstance
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    State.Connections = {}
    
    -- Setup Lasso GUI
    if State.LassoGui then State.LassoGui:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name = "LassoDragGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = game:GetService("CoreGui")
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(60, 130, 255); frame.BackgroundTransparency = 0.75; frame.BorderSizePixel = 0; frame.Visible = false; frame.Parent = sg
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(120, 180, 255); stroke.Thickness = 1.5; stroke.Parent = frame
    State.LassoGui = sg; State.LassoFrame = frame

    -- UI
    Tab:CreateSection("Item Teleportation")
    Tab:CreateToggle("Click Selection", false, function(val) State.ClickSelectMode = val end)
    Tab:CreateToggle("Group Selection", false, function(val) State.GroupSelectMode = val end)
    Tab:CreateToggle("Lasso Tool", false, function(val) State.LassoMode = val end)
    
    Tab:CreateSection("Stack Configuration")
    Tab:CreateSlider("Stack Width (X)", 1, 10, 1, function(val) Settings.StackX = val end)
    Tab:CreateSlider("Stack Height (Y)", 1, 20, 5, function(val) Settings.StackY = val end)
    Tab:CreateSlider("Stack Depth (Z)", 1, 10, 1, function(val) Settings.StackZ = val end)
    
    local MainRow = Tab:CreateRow()
    MainRow:CreateAction("Clear Selection", "Clear", function()
        State.SelectedObjects = {}
        UpdateVisuals()
        ClearPreview()
        Notify("Cleared", "Selection reset.")
    end)
    
    local stackBtn
    stackBtn = MainRow:CreateAction("Start Stack", "Layers", function()
        if State.IsPreviewing then
            ClearPreview()
            stackBtn:UpdateText("Start Stack")
        else
            StartStackPreview()
            if State.IsPreviewing then
                stackBtn:UpdateText("Stop Preview")
            end
        end
    end)

    MainRow:CreateAction("Quick TP", "Execute", function() PerformExecute() end)

    -- Input & Loop
    local runConn = RunService.RenderStepped:Connect(function()
        if State.IsPreviewing and State.PreviewFolder then
            local mousePos = Mouse.Hit.p
            for _, ghost in ipairs(State.PreviewFolder:GetChildren()) do
                local offset = ghost:FindFirstChild("Offset")
                if offset then
                    ghost.CFrame = CFrame.new(mousePos) * CFrame.new(offset.Value)
                end
            end
        end
    end)
    table.insert(State.Connections, runConn)

    local mb1DownConn = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if State.IsPreviewing then
                stackBtn:UpdateText("Start Stack")
                ExecuteStackPlacement()
            elseif State.LassoMode then
                State.LassoDragging = true
                State.LassoStartPos = UIS:GetMouseLocation()
            elseif State.GroupSelectMode then
                local _, itemName, targetModel = getObjectData(Mouse.Target)
                if itemName then
                    local targetOwnerIden = GetOwnerIdentity(targetModel)
                    local targetSig = GetModelSignature(targetModel)
                    local targetTreeClass = GetTreeClass(targetModel)
                    local playerModels = workspace:FindFirstChild("PlayerModels")
                    if playerModels then
                        for _, obj in ipairs(playerModels:GetDescendants()) do
                            if obj:IsA("Model") and obj.Name == itemName and GetOwnerIdentity(obj) == targetOwnerIden and GetModelSignature(obj) == targetSig and GetTreeClass(obj) == targetTreeClass then
                                local part = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
                                if part and not part.Anchored then
                                    if not table.find(State.SelectedObjects, part) then table.insert(State.SelectedObjects, part) end
                                end
                            end
                        end
                    end
                    UpdateVisuals()
                end
            elseif State.ClickSelectMode then
                local main = getObjectData(Mouse.Target)
                if main then
                    local idx = table.find(State.SelectedObjects, main)
                    if not idx then table.insert(State.SelectedObjects, main) else table.remove(State.SelectedObjects, idx) end
                    UpdateVisuals()
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            if State.IsPreviewing then
                ClearPreview()
                stackBtn:UpdateText("Start Stack")
            end
        end
    end)
    table.insert(State.Connections, mb1DownConn)

    local mouseMoveConn = UIS.InputChanged:Connect(function(input)
        if State.LassoDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateLassoFrame(UIS:GetMouseLocation())
        end
    end)
    table.insert(State.Connections, mouseMoveConn)

    local mb1UpConn = UIS.InputEnded:Connect(function(input)
        if State.LassoDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
            SelectObjectsInLassoRect(State.LassoStartPos, UIS:GetMouseLocation())
        end
    end)
    table.insert(State.Connections, mb1UpConn)
end

function LooseObjectTeleport.Unload()
    ClearPreview()
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    for _, v in pairs(State.SelectionBoxes) do v:Destroy() end
    if State.LassoGui then State.LassoGui:Destroy() end
    Notify("Unloaded", "Module cleaned up.")
end

function SelectObjectsInLassoRect(startPos, endPos)
    local minX, minY = math.min(startPos.X, endPos.X), math.min(startPos.Y, endPos.Y)
    local maxX, maxY = math.max(startPos.X, endPos.X), math.max(startPos.Y, endPos.Y)
    local playerModels = workspace:FindFirstChild("PlayerModels")
    if not playerModels then return end
    local inset = GuiService:GetGuiInset()
    for _, obj in ipairs(playerModels:GetDescendants()) do
        if obj:IsA("Model") then
            local part = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
            if part and not part.Anchored and not part:IsDescendantOf(Player.Character) then
                local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
                local sx, sy = screenPos.X + inset.X, screenPos.Y + inset.Y
                if onScreen and sx >= minX and sx <= maxX and sy >= minY and sy <= maxY then
                    if not table.find(State.SelectedObjects, part) then table.insert(State.SelectedObjects, part) end
                end
            end
        end
    end
    UpdateVisuals()
end

function UpdateLassoFrame(currentPos)
    if not State.LassoFrame or not State.LassoStartPos then return end
    local minX, minY = math.min(State.LassoStartPos.X, currentPos.X), math.min(State.LassoStartPos.Y, currentPos.Y)
    local maxX, maxY = math.max(State.LassoStartPos.X, currentPos.X), math.max(State.LassoStartPos.Y, currentPos.Y)
    State.LassoFrame.Position = UDim2.fromOffset(minX, minY)
    State.LassoFrame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
    State.LassoFrame.Visible = true
end

return LooseObjectTeleport

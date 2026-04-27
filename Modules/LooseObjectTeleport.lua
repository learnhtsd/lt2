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

    -- Stack settings
    StackX                 = 1,
    StackY                 = 5,
    StackZ                 = 1,
    StackPadding           = 0.05,
}

local State = {
    SelectedObjects   = {},
    SelectionBoxes    = {},
    Connections       = {},
    TempDeleted       = {},
    BatchCancelled    = false,

    -- FIX 3: Global busy flag — silences all selection input during any TP batch
    IsBusy            = false,

    ClickSelectMode   = false,
    GroupSelectMode   = false,
    LassoMode         = false,
    LassoDragging     = false,
    LassoStartPos     = nil,
    LassoGui          = nil,
    LassoFrame        = nil,

    -- Stack mode
    StackMode         = false,
    StackPreviewParts = {},
    StackPreviewBoxes = {}, -- FIX 1: track outline SelectionBoxes separately for cleanup
    StackPreviewConn  = nil,
    StackStartBtn     = nil,

    Library           = nil,
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
-- │                     BATCH CLEANUP HELPER                        │
-- └─────────────────────────────────────────────────────────────────┘

-- FIX 4: Centralised post-batch restore so both PerformExecute and
-- PerformStackExecute do it identically and correctly.
-- Character is snapped back to `originalCharCFrame` BEFORE PlatformStand
-- is disabled so humanoid physics re-engage at a safe, grounded position.
local function RestoreCharacterAfterBatch(char, root, hum, originalCharCFrame)
    -- 1. Zero all motion while still ghosted / PlatformStand on
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- 2. Snap back to where the player started — NOT on top of any objects
    root.CFrame = originalCharCFrame

    -- 3. Un-ghost before re-enabling physics so the character doesn't clip
    SetCharacterGhosting(char, false)

    -- 4. Re-enable humanoid physics now that the character is safely placed
    hum.PlatformStand = false

    -- 5. One frame later, zero velocity again in case Roblox physics gave a
    --    small impulse when PlatformStand toggled off
    task.wait()
    if root and root.Parent then
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    Camera.CameraType = Enum.CameraType.Custom
    Player.CameraMode = Enum.CameraMode.Classic
    UIS.MouseBehavior = Enum.MouseBehavior.Default
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         LASSO ENGINE                            │
-- └─────────────────────────────────────────────────────────────────┘

local function InitLassoGui()
    if State.LassoGui then State.LassoGui:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "LassoDragGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Name                   = "LassoRect"
    frame.BackgroundColor3       = Color3.fromRGB(60, 130, 255)
    frame.BackgroundTransparency = 0.75
    frame.BorderSizePixel        = 0
    frame.Visible                = false
    frame.ZIndex                 = 10
    frame.Parent                 = sg

    local stroke           = Instance.new("UIStroke")
    stroke.Color           = Color3.fromRGB(120, 180, 255)
    stroke.Thickness       = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent          = frame

    State.LassoGui   = sg
    State.LassoFrame = frame
end

local function UpdateLassoFrame(currentPos)
    if not State.LassoFrame or not State.LassoStartPos then return end
    local minX = math.min(State.LassoStartPos.X, currentPos.X)
    local minY = math.min(State.LassoStartPos.Y, currentPos.Y)
    local maxX = math.max(State.LassoStartPos.X, currentPos.X)
    local maxY = math.max(State.LassoStartPos.Y, currentPos.Y)
    State.LassoFrame.Position = UDim2.fromOffset(minX, minY)
    State.LassoFrame.Size     = UDim2.fromOffset(maxX - minX, maxY - minY)
    State.LassoFrame.Visible  = true
end

local function SelectObjectsInLassoRect(startPos, endPos)
    local minX = math.min(startPos.X, endPos.X)
    local minY = math.min(startPos.Y, endPos.Y)
    local maxX = math.max(startPos.X, endPos.X)
    local maxY = math.max(startPos.Y, endPos.Y)

    if (maxX - minX) < 6 or (maxY - minY) < 6 then return end

    local playerModels = workspace:FindFirstChild("PlayerModels")
    if not playerModels then
        Notify("Lasso", "workspace.PlayerModels not found.")
        return
    end

    local addedCount   = 0
    local removedCount = 0
    local inset        = GuiService:GetGuiInset()

    for _, obj in ipairs(playerModels:GetDescendants()) do
        if obj:IsA("Model") then
            local part = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
            if part and not part.Anchored and not part:IsDescendantOf(Player.Character) then
                local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
                local sx = screenPos.X + inset.X
                local sy = screenPos.Y + inset.Y

                if onScreen and screenPos.Z > 0 and sx >= minX and sx <= maxX and sy >= minY and sy <= maxY then
                    local idx = table.find(State.SelectedObjects, part)
                    if idx then
                        table.remove(State.SelectedObjects, idx)
                        removedCount = removedCount + 1
                    else
                        table.insert(State.SelectedObjects, part)
                        addedCount = addedCount + 1
                    end
                end
            end
        end
    end

    UpdateVisuals()
    Notify("Lasso", "+" .. addedCount .. " / -" .. removedCount .. " — Queue: " .. #State.SelectedObjects)
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

-- FIX 2: `preserveRotation` param — pass true for regular TP (keep world angle),
-- false for stack TP (force objects upright so they sit flat in the grid).
local function GrabAndTeleport(currentTarget, goalPos, char, head, root, originalParents, preserveRotation)
    currentTarget.Parent = originalParents[currentTarget] or workspace

    -- Build rotation component: upright identity for stacks, original angle for regular TP
    local rotationPart = preserveRotation
        and currentTarget.CFrame.Rotation
        or  CFrame.new()

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

        -- Kill the throw velocity Roblox applies on drag-release immediately,
        -- before any yield, so the object doesn't fly back to its origin.
        if currentTarget and currentTarget.Parent then
            currentTarget.AssemblyLinearVelocity  = Vector3.zero
            currentTarget.AssemblyAngularVelocity = Vector3.zero
        end

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
        local goalCF = CFrame.new(goalPos) * rotationPart

        local tpLock = RunService.Heartbeat:Connect(function()
            if currentTarget and currentTarget.Parent then
                currentTarget.CFrame                  = goalCF
                currentTarget.AssemblyLinearVelocity  = Vector3.zero
                currentTarget.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        task.wait(Settings.PostSyncDelay)
        tpLock:Disconnect()

        if currentTarget and currentTarget.Parent then
            currentTarget.CFrame = goalCF * CFrame.new(0, 0.05, 0)
            task.wait(Settings.CFrameNudgeDelay)
            currentTarget.CFrame = goalCF
        end
    end

    task.wait(Settings.PostGrabDelay)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         STACK ENGINE                            │
-- └─────────────────────────────────────────────────────────────────┘

local function AllSelectedSameType()
    if #State.SelectedObjects == 0 then
        return false, "Queue is empty."
    end
    local refName, refSig
    for _, obj in ipairs(State.SelectedObjects) do
        if not (obj and obj.Parent) then continue end
        local model = obj:FindFirstAncestorOfClass("Model")
        local name  = model and model.Name or obj.Name
        local sig   = model and GetModelSignature(model) or (obj.ClassName .. ":" .. obj.Name)
        if not refName then
            refName = name
            refSig  = sig
        elseif name ~= refName or sig ~= refSig then
            return false, "Mixed item types in queue.\nAll items must be identical to use Stack TP."
        end
    end
    return true, "OK"
end

local function GetStackPositions(origin, itemSize, countX, countY, countZ, totalItems)
    local positions = {}
    local stepX = itemSize.X + Settings.StackPadding
    local stepY = itemSize.Y + Settings.StackPadding
    local stepZ = itemSize.Z + Settings.StackPadding
    local offX  = (countX - 1) * stepX * 0.5
    local offZ  = (countZ - 1) * stepZ * 0.5

    for z = 0, countZ - 1 do
        for y = 0, countY - 1 do
            for x = 0, countX - 1 do
                table.insert(positions, origin + Vector3.new(
                    x * stepX - offX,
                    y * stepY,
                    z * stepZ - offZ
                ))
                if #positions >= totalItems then
                    return positions
                end
            end
        end
    end
    return positions
end

-- FIX 1: Destroys BOTH ghost parts AND their tracked outline SelectionBoxes
local function ClearStackPreview()
    if State.StackPreviewConn then
        State.StackPreviewConn:Disconnect()
        State.StackPreviewConn = nil
    end
    for _, box in ipairs(State.StackPreviewBoxes) do
        if box and box.Parent then box:Destroy() end
    end
    State.StackPreviewBoxes = {}
    for _, p in ipairs(State.StackPreviewParts) do
        if p and p.Parent then p:Destroy() end
    end
    State.StackPreviewParts = {}
end

local function SetStackBtnLabel(label)
    if State.StackStartBtn then
        if State.StackStartBtn.SetLabel then
            State.StackStartBtn:SetLabel(label)
        elseif State.StackStartBtn.SetText then
            State.StackStartBtn:SetText(label)
        end
    end
end

local function StopStackMode(silent)
    State.StackMode = false
    ClearStackPreview()
    SetStackBtnLabel("Start Stack")
    if not silent then
        Notify("Stack TP", "Placement cancelled.")
    end
end

local function StartStackMode()
    if State.StackMode then
        StopStackMode()
        return
    end

    local ok, reason = AllSelectedSameType()
    if not ok then
        Notify("Stack TP — Blocked", reason, 4)
        return
    end

    local capacity = Settings.StackX * Settings.StackY * Settings.StackZ
    if capacity < #State.SelectedObjects then
        Notify("Stack TP — Too Small",
            "Grid holds " .. capacity .. " slots but queue has " .. #State.SelectedObjects .. " items.\n"
            .. "Increase X / Y / Z sliders.", 5)
        return
    end

    local refSize = Vector3.new(4, 4, 4)
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then refSize = obj.Size; break end
    end

    ClearStackPreview()
    for i = 1, #State.SelectedObjects do
        local p           = Instance.new("Part")
        p.Name            = "StackPreview_" .. i
        p.Size            = refSize
        p.Anchored        = true
        p.CanCollide      = false
        p.CanTouch        = false
        p.Transparency    = 0.45
        p.Color           = Color3.fromRGB(80, 130, 255)
        p.Material        = Enum.Material.Neon
        p.CastShadow      = false
        p.Parent          = workspace
        table.insert(State.StackPreviewParts, p)

        -- FIX 1: Store box reference so ClearStackPreview can destroy it
        local box         = Instance.new("SelectionBox")
        box.Color3        = Color3.fromRGB(140, 180, 255)
        box.LineThickness = 0.03
        box.Adornee       = p
        box.Parent        = game:GetService("CoreGui")
        table.insert(State.StackPreviewBoxes, box)
    end

    State.StackMode = true
    SetStackBtnLabel("Stop Stack")
    Notify("Stack TP",
        "Move cursor to target — click to place " .. #State.SelectedObjects .. " items.", 4)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    State.StackPreviewConn = RunService.RenderStepped:Connect(function()
        if not State.StackMode then return end

        local excludeList = {}
        if Player.Character then table.insert(excludeList, Player.Character) end
        for _, p in ipairs(State.StackPreviewParts) do table.insert(excludeList, p) end
        rayParams.FilterDescendantsInstances = excludeList

        local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
        local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)

        local groundOrigin
        if result then
            groundOrigin = result.Position + Vector3.new(0, refSize.Y * 0.5, 0)
        else
            groundOrigin = unitRay.Origin + unitRay.Direction * 40
        end

        local positions = GetStackPositions(
            groundOrigin, refSize,
            Settings.StackX, Settings.StackY, Settings.StackZ,
            #State.StackPreviewParts
        )

        for i, ghostPart in ipairs(State.StackPreviewParts) do
            if positions[i] then
                ghostPart.CFrame = CFrame.new(positions[i])
            end
        end
    end)
end

local function PerformStackExecute(hitPos)
    if not State.StackMode then return end

    local ok, reason = AllSelectedSameType()
    if not ok then
        StopStackMode()
        Notify("Stack TP — Blocked", reason, 4)
        return
    end

    local refSize = Vector3.new(4, 4, 4)
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then refSize = obj.Size; break end
    end

    local groundOrigin = hitPos + Vector3.new(0, refSize.Y * 0.5, 0)
    local goalPositions = GetStackPositions(
        groundOrigin, refSize,
        Settings.StackX, Settings.StackY, Settings.StackZ,
        #State.SelectedObjects
    )

    -- FIX 1: Wipe preview (parts + boxes) fully before TP begins
    StopStackMode(true)

    if not Player.Character then return end
    local char = Player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not root or not head or not hum then return end

    -- FIX 3: Raise busy flag — suppresses all selection clicks during TP
    State.IsBusy         = true
    State.BatchCancelled = false
    Notify("Stack TP", "Teleporting " .. #State.SelectedObjects .. " items into stack…", 3)

    local originalCharCFrame = root.CFrame

    Player.CameraMode = Enum.CameraMode.LockFirstPerson
    UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
    hum.PlatformStand = true
    SetCharacterGhosting(char, true)

    local originalParents = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            originalParents[obj] = obj.Parent
            obj.Parent           = nil
        end
    end

    local snapshot = {table.unpack(State.SelectedObjects)}

    for i, currentTarget in ipairs(snapshot) do
        if not currentTarget then continue end
        if State.BatchCancelled then
            local op = originalParents[currentTarget]
            if op then currentTarget.Parent = op end
            continue
        end
        local targetPos = goalPositions[i] or groundOrigin
        -- FIX 2: preserveRotation = false → objects placed perfectly upright
        GrabAndTeleport(currentTarget, targetPos, char, head, root, originalParents, false)
    end

    task.wait(Settings.PostBatchDelay)

    -- FIX 4: Safe character restore — snap to origin first, then un-ragdoll
    RestoreCharacterAfterBatch(char, root, hum, originalCharCFrame)

    State.IsBusy          = false
    State.SelectedObjects = {}
    UpdateVisuals()

    Notify("Stack TP", State.BatchCancelled and "Batch cancelled." or "Stack complete!", 3)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     BUTTON / HOTKEY ACTIONS                     │
-- └─────────────────────────────────────────────────────────────────┘

local function PerformSingleSelect()
    local main = getObjectData(Mouse.Target)
    if main then
        local idx = table.find(State.SelectedObjects, main)
        if not idx then
            table.insert(State.SelectedObjects, main)
            Notify("Added", "Queue: " .. #State.SelectedObjects)
        else
            table.remove(State.SelectedObjects, idx)
            Notify("Removed", "Object removed.")
        end
        UpdateVisuals()
    end
end

local function PerformGroupSelect()
    local _, itemName, targetModel = getObjectData(Mouse.Target)
    local targetOwnerIden = GetOwnerIdentity(targetModel)
    if not (itemName and targetOwnerIden and targetModel) then return end

    local targetSig       = GetModelSignature(targetModel)
    local targetTreeClass = GetTreeClass(targetModel)
    local addedCount      = 0
    local removedCount    = 0

    local playerModels = workspace:FindFirstChild("PlayerModels")
    if not playerModels then return end

    for i, obj in ipairs(playerModels:GetDescendants()) do
        if i % 1000 == 0 then task.wait() end
        if obj:IsA("Model") and obj.Name == itemName
            and GetOwnerIdentity(obj) == targetOwnerIden
            and GetModelSignature(obj) == targetSig
            and GetTreeClass(obj) == targetTreeClass then

            local part = obj:FindFirstChild("Main") or obj:FindFirstChildWhichIsA("BasePart")
            if part and not part.Anchored then
                local idx = table.find(State.SelectedObjects, part)
                if idx then
                    table.remove(State.SelectedObjects, idx)
                    removedCount = removedCount + 1
                else
                    table.insert(State.SelectedObjects, part)
                    addedCount = addedCount + 1
                end
            end
        end
    end
    UpdateVisuals()
    Notify("Group", "+" .. addedCount .. " / -" .. removedCount .. " — Queue: " .. #State.SelectedObjects)
end

local function PerformClear()
    if State.StackMode then StopStackMode(true) end
    State.SelectedObjects = {}
    State.BatchCancelled  = true
    UpdateVisuals()
    Notify("Cleared", "Queue emptied — batch cancelled.")
end

local function PerformExecute()
    if #State.SelectedObjects == 0 or not Player.Character then
        Notify("Wait", "Queue empty or missing character.", 2)
        return
    end

    local char = Player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not root or not head or not hum then return end

    -- FIX 3: Raise busy flag — suppresses all selection clicks during TP
    State.IsBusy         = true
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
            obj.Parent           = nil
        end
    end

    local finalPos = (originalCharCFrame * CFrame.new(0, 0.5, 0)).Position
    local snapshot = {table.unpack(State.SelectedObjects)}

    for _, currentTarget in ipairs(snapshot) do
        if not currentTarget then continue end
        if State.BatchCancelled then
            local op = OriginalParents[currentTarget]
            if op then currentTarget.Parent = op end
            continue
        end
        -- FIX 2: preserveRotation = true → keep world rotation for regular TP
        GrabAndTeleport(currentTarget, finalPos, char, head, root, OriginalParents, true)
    end

    task.wait(Settings.PostBatchDelay)

    -- FIX 4: Safe character restore — snap to origin first, then un-ragdoll
    RestoreCharacterAfterBatch(char, root, hum, originalCharCFrame)

    State.IsBusy          = false
    State.SelectedObjects = {}
    UpdateVisuals()

    Notify("Finished", State.BatchCancelled and "Batch cancelled." or "Batch complete.", 3)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       MODULE INITIALIZE                         │
-- └─────────────────────────────────────────────────────────────────┘

function LooseObjectTeleport.Init(Tab, LibraryInstance)
    State.Library = LibraryInstance

    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    State.Connections = {}

    InitLassoGui()

    -- ── Selection section ────────────────────────────────────────
    Tab:CreateSection("Item Teleportation")
    Tab:CreateToggle("Click Selection", false, function(val)
        State.ClickSelectMode = val
    end)

    Tab:CreateToggle("Group Selection", false, function(val)
        State.GroupSelectMode = val
    end)

    Tab:CreateToggle("Lasso Tool", false, function(val)
        State.LassoMode = val
        if not val then
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
        end
    end):AddTooltip("Drag a box over objects to select them.")

    Tab:CreateSlider("Max Retries", 1, 10, 5, function(val)
        Settings.MaxRetries = val
    end):AddTooltip("How many times to attempt grabbing network ownership per failed object.")

    local MainRow = Tab:CreateRow()
    MainRow:CreateAction("Clear Selection", "Clear", PerformClear)
    MainRow:CreateAction("TP Selection",    "Execute", PerformExecute)

    -- ── Stack TP section ─────────────────────────────────────────
    Tab:CreateSection("Stack Teleport")

    Tab:CreateSlider("Stack X (columns)", 1, 20, Settings.StackX, function(val)
        Settings.StackX = val
    end):AddTooltip("How many items wide the stack is (left ↔ right).")

    Tab:CreateSlider("Stack Y (layers)",  1, 50, Settings.StackY, function(val)
        Settings.StackY = val
    end):AddTooltip("How many items tall the stack is (bottom ↑ top).")

    Tab:CreateSlider("Stack Z (rows)",    1, 20, Settings.StackZ, function(val)
        Settings.StackZ = val
    end):AddTooltip("How many items deep the stack is (front ↔ back).")

    Tab:CreateSlider("Item Padding", 0, 5, Settings.StackPadding * 10, function(val)
        Settings.StackPadding = val / 10
    end):AddTooltip("Gap between each item in the stack (0 = flush, 5 = 0.5 studs apart).")

    local StackRow = Tab:CreateRow()
    State.StackStartBtn = StackRow:CreateAction(
        "Stack TP — place selected items in a neat grid",
        "Start Stack",
        StartStackMode
    )
    State.StackStartBtn:AddTooltip(
        "All selected items must be the same type.\n"
        .. "After clicking Start Stack, a ghost preview follows your cursor.\n"
        .. "Left-click in the world to confirm placement."
    )

    -- ── Input routing ────────────────────────────────────────────
    local mb1DownConn = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        -- FIX 3: Completely ignore world clicks while any batch is running
        if State.IsBusy then return end

        if State.StackMode then
            local excludeList = {}
            if Player.Character then table.insert(excludeList, Player.Character) end
            for _, p in ipairs(State.StackPreviewParts) do table.insert(excludeList, p) end

            local rayParams = RaycastParams.new()
            rayParams.FilterType                 = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = excludeList

            local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
            local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)
            local hitPos  = result and result.Position or (unitRay.Origin + unitRay.Direction * 40)

            task.spawn(PerformStackExecute, hitPos)

        elseif State.LassoMode then
            State.LassoDragging = true
            State.LassoStartPos = UIS:GetMouseLocation()
            if State.LassoFrame then
                State.LassoFrame.Size    = UDim2.fromOffset(0, 0)
                State.LassoFrame.Visible = false
            end

        elseif State.GroupSelectMode then
            PerformGroupSelect()

        elseif State.ClickSelectMode then
            PerformSingleSelect()
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
            State.LassoStartPos = nil
        end
    end)
    table.insert(State.Connections, mb1UpConn)

    UpdateVisuals()
end

function LooseObjectTeleport.Unload()
    StopStackMode(true)
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    for _, v in pairs(State.SelectionBoxes) do v:Destroy() end
    if State.LassoGui then State.LassoGui:Destroy() end

    Camera.CameraType = Enum.CameraType.Custom
    Player.CameraMode = Enum.CameraMode.Classic
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    Notify("Unloaded", "Loose Object Teleport successfully unloaded.")
end

return LooseObjectTeleport

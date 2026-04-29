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
    PostSyncDelay          = 0.05,
    CFrameNudgeDelay       = 0.05,
    PostGrabDelay          = 0.1,
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

    -- NEW: Keep teleported items selected after a batch finishes (default off)
    KeepSelected           = false,
}

local State = {
    SelectedObjects   = {},
    SelectionBoxes    = {},
    Connections       = {},
    TempDeleted       = {},
    BatchCancelled    = false,

    -- Global busy flag — silences all selection input during any TP batch
    IsBusy            = false,

    -- FIX 1: Signals GrabAndTeleport's playerLock is active so ghostLock
    -- skips its own root/camera enforcement (prevents them fighting each other)
    GrabPhase         = false,

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
    StackPreviewBoxes = {},
    StackPreviewConn  = nil,
    StackStartBtn     = nil,
    StackRotation     = CFrame.new(),

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

--
-- FIX 1 + FIX 3: Accept saved camera state so we can restore exactly
-- what the player had before the batch started.
--
-- Restoration order matters to prevent the spaz/rotation bug:
--   1. Kill the ghostLock heartbeat first (stops competing writes)
--   2. Zero velocities
--   3. Restore position
--   4. Un-ghost the character
--   5. Wait one frame so physics settles with the character visible
--   6. Re-zero velocities (physics may have ticked)
--   7. Re-set position  ← catches any kick that happened in step 5
--   8. Release PlatformStand (now the character is already grounded)
--   9. Wait one more frame then zero again (PlatformStand release can nudge)
--  10. Restore camera to whatever state the player was in
--
local function RestoreCharacterAfterBatch(char, root, hum, originalCharCFrame, ghostLock, origCamType, origCamMode)
    -- 1. Kill the ghostLock so it stops enforcing Scriptable camera / root lock
    if ghostLock then ghostLock:Disconnect() end

    -- 2-3. Zero velocities, then snap to saved position
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = originalCharCFrame

    -- 4. Un-ghost (restores LocalTransparencyModifier + CanCollide)
    SetCharacterGhosting(char, false)

    -- 5. One physics frame for the engine to acknowledge the new state
    task.wait()

    -- 6-7. Re-enforce position after the physics tick (catches any kick)
    if root and root.Parent then
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = originalCharCFrame
    end

    -- 8. Now release PlatformStand — character is already in the right spot
    hum.PlatformStand = false

    -- 9. One more frame; PlatformStand release can cause a small nudge
    task.wait()
    if root and root.Parent then
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    -- 10. FIX 3: Restore the camera to exactly what the player had.
    --     Re-attach the camera subject so third-person tracking resumes.
    Camera.CameraType = origCamType
    Player.CameraMode = origCamMode
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    if hum2 then
        Camera.CameraSubject = hum2
    end

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

local function GrabAndTeleport(currentTarget, goalCFrame, char, head, root, originalParents)
    local wasCollidable = currentTarget.CanCollide
    currentTarget.CanCollide = false
    currentTarget.Parent = originalParents[currentTarget] or workspace

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

    -- FIX 1: Signal ghostLock to stand down while playerLock drives position
    State.GrabPhase = true

    local playerLock = RunService.Heartbeat:Connect(function()
        if root then
            root.CFrame = hoverCF
            root.AssemblyLinearVelocity = Vector3.zero
        end
        if Settings.LockMouseMovement and head and currentTarget then
            -- FIX 2: Camera already Scriptable from RunBatch; just update its CFrame
            Camera.CFrame = CFrame.lookAt(head.Position, currentTarget.Position)
        end
    end)

    task.wait(Settings.PreClickDelay)

    local attempts     = 0
    local gotOwnership = false
    while not gotOwnership and attempts < Settings.MaxRetries do
        attempts = attempts + 1
        mouse1press()
        gotOwnership = WaitForOwnership(currentTarget)
        if not gotOwnership then
            mouse1release()
            if currentTarget and currentTarget.Parent then
                currentTarget.AssemblyLinearVelocity  = Vector3.zero
                currentTarget.AssemblyAngularVelocity = Vector3.zero
            end
            if attempts < Settings.MaxRetries then
                task.wait(Settings.BetweenRetryDelay)
            end
        end
    end

    playerLock:Disconnect()

    -- FIX 1: Return control to ghostLock — it will re-lock root and camera
    State.GrabPhase = false

    -- FIX 2 + FIX 1: Do NOT restore Camera.CameraType here.
    -- ghostLock (still alive) immediately takes over: it enforces Scriptable
    -- camera at the head and locks root.CFrame to originalCharCFrame.
    -- Restoring CameraType here mid-batch was what caused the camera snap
    -- and the cascade that led to the character spaz.

    for _, data in ipairs(State.TempDeleted) do
        if data.Part then data.Part.Parent = data.OldParent end
    end
    State.TempDeleted = {}

    if currentTarget and currentTarget.Parent then
        task.wait(0.2)

        local preLock = RunService.Heartbeat:Connect(function()
            if currentTarget and currentTarget.Parent then
                currentTarget.CFrame                  = goalCFrame
                currentTarget.AssemblyLinearVelocity  = Vector3.zero
                currentTarget.AssemblyAngularVelocity = Vector3.zero
            end
        end)
        task.wait(Settings.PostSyncDelay)
        preLock:Disconnect()

        if gotOwnership then mouse1release() end

        if currentTarget and currentTarget.Parent then
            currentTarget.AssemblyLinearVelocity  = Vector3.zero
            currentTarget.AssemblyAngularVelocity = Vector3.zero
        end

        local postLock = RunService.Heartbeat:Connect(function()
            if currentTarget and currentTarget.Parent then
                currentTarget.CFrame                  = goalCFrame
                currentTarget.AssemblyLinearVelocity  = Vector3.zero
                currentTarget.AssemblyAngularVelocity = Vector3.zero
            end
        end)
        task.wait(Settings.CFrameNudgeDelay)
        postLock:Disconnect()

        if currentTarget and currentTarget.Parent then
            currentTarget.CFrame = goalCFrame * CFrame.new(0, 0.05, 0)
            task.wait(Settings.CFrameNudgeDelay)
            currentTarget.CFrame = goalCFrame
        end

    elseif not gotOwnership then
        mouse1release()
    end

    if currentTarget and currentTarget.Parent then
        currentTarget.AssemblyLinearVelocity  = Vector3.zero
        currentTarget.AssemblyAngularVelocity = Vector3.zero
        currentTarget.CanCollide              = wasCollidable
        currentTarget.Anchored                = true
        local ref = currentTarget
        task.delay(2, function()
            if ref and ref.Parent then ref.Anchored = false end
        end)
    end

    task.wait(Settings.PostGrabDelay)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │              *** SHARED INTERNAL BATCH RUNNER ***               │
-- │                                                                 │
-- │  jobs  — array of { target = BasePart, goalCF = CFrame }       │
-- └─────────────────────────────────────────────────────────────────┘
local function RunBatch(jobs)
    if #jobs == 0 then
        Notify("Batch", "No jobs supplied.", 2)
        return
    end
    if not Player.Character then
        Notify("Batch", "Character missing.", 2)
        return
    end

    local char = Player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not root or not head or not hum then return end

    -- Raise busy flag — blocks all UI selection clicks while running
    State.IsBusy         = true
    State.BatchCancelled = false
    State.GrabPhase      = false  -- reset in case a previous batch was cancelled dirty

    -- FIX 3: Save the player's camera state so we can restore it precisely.
    local origCamType = Camera.CameraType
    local origCamMode = Player.CameraMode

    local originalCharCFrame = root.CFrame

    -- FIX 2: Use Scriptable camera driven by ghostLock instead of LockFirstPerson.
    -- LockFirstPerson uses a canned Roblox camera offset that feels "fake".
    -- Scriptable lets us position the camera exactly at eye-level inside the head,
    -- giving real first-person feel with full control.
    Player.CameraMode = Enum.CameraMode.Classic  -- don't fight LockFirstPerson's offsets
    Camera.CameraType = Enum.CameraType.Scriptable
    UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
    hum.PlatformStand = true
    SetCharacterGhosting(char, true)

    --
    -- ghostLock runs every Heartbeat for the entire lifetime of the batch.
    --
    -- It has two responsibilities:
    --   A) Always: enforce no-collision on every character part.
    --   B) When NOT in GrabPhase: lock root.CFrame to the saved position and
    --      hold the Scriptable camera at eye level (FIX 1 + FIX 2).
    --      During GrabPhase, playerLock inside GrabAndTeleport owns these.
    --
    local ghostLock = RunService.Heartbeat:Connect(function()
        -- A) Always enforce no-collision
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end

        -- B) Between grabs: hold the character still and show real first-person view.
        --    GrabPhase = true means playerLock is alive; we skip to avoid fighting it.
        if not State.GrabPhase then
            if root and root.Parent then
                root.CFrame = originalCharCFrame
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
            -- FIX 2: Real first-person — camera sits at the eye position inside the head.
            -- head.CFrame already points the right direction; nudge up ~0.25 studs to
            -- approximate eye level (Roblox heads are 1 stud tall, origin at centre).
            if head and head.Parent then
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame     = head.CFrame * CFrame.new(0, 0.25, 0)
            end
        end
    end)

    -- Pre-collect original parents and pull all targets out of the world
    local originalParents = {}
    for _, job in ipairs(jobs) do
        if job.target and job.target.Parent then
            originalParents[job.target] = job.target.Parent
            job.target.Parent = nil
        end
    end

    -- Run each job
    for _, job in ipairs(jobs) do
        if not job.target then continue end
        if State.BatchCancelled then
            -- Restore unprocessed objects on cancel
            local op = originalParents[job.target]
            if op then job.target.Parent = op end
            continue
        end
        GrabAndTeleport(job.target, job.goalCF, char, head, root, originalParents)
    end

    task.wait(Settings.PostBatchDelay)

    -- FIX 1 + FIX 3: Pass saved camera state into restore so it resets properly.
    RestoreCharacterAfterBatch(char, root, hum, originalCharCFrame, ghostLock, origCamType, origCamMode)

    State.IsBusy = false

    return not State.BatchCancelled -- true = all succeeded, false = cancelled
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

local function GetStackPositions(origin, itemSize, countX, countY, countZ, totalItems, stackRotation)
    stackRotation = stackRotation or CFrame.new()
    local positions = {}
    local stepX = itemSize.X + Settings.StackPadding
    local stepY = itemSize.Y + Settings.StackPadding
    local stepZ = itemSize.Z + Settings.StackPadding
    local offX  = (countX - 1) * stepX * 0.5
    local offZ  = (countZ - 1) * stepZ * 0.5

    for z = 0, countZ - 1 do
        for y = 0, countY - 1 do
            for x = 0, countX - 1 do
                local localOffset   = Vector3.new(x * stepX - offX, y * stepY, z * stepZ - offZ)
                local rotatedOffset = stackRotation:VectorToWorldSpace(localOffset)
                table.insert(positions, origin + rotatedOffset)
                if #positions >= totalItems then return positions end
            end
        end
    end
    return positions
end

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
    State.StackMode     = false
    State.StackRotation = CFrame.new()
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
            #State.StackPreviewParts,
            State.StackRotation
        )

        for i, ghostPart in ipairs(State.StackPreviewParts) do
            if positions[i] then
                ghostPart.CFrame = CFrame.new(positions[i]) * State.StackRotation
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
        #State.SelectedObjects,
        State.StackRotation
    )
    local capturedRotation = State.StackRotation

    StopStackMode(true)

    -- Build jobs list for RunBatch
    local jobs = {}
    for i, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            local targetPos = goalPositions[i] or groundOrigin
            table.insert(jobs, {
                target = obj,
                goalCF = CFrame.new(targetPos) * capturedRotation
            })
        end
    end

    Notify("Stack TP", "Teleporting " .. #jobs .. " items into stack…", 3)

    local success = RunBatch(jobs)

    -- NEW: Only clear the queue if KeepSelected is off
    if not Settings.KeepSelected then
        State.SelectedObjects = {}
    end
    UpdateVisuals()
    Notify("Stack TP", success and "Stack complete!" or "Batch cancelled.", 3)
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
    if not root then return end

    local finalPos = (root.CFrame * CFrame.new(0, 0.5, 0)).Position

    -- Capture rotations before building the jobs list
    local jobs = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            table.insert(jobs, {
                target = obj,
                goalCF = CFrame.new(finalPos) * obj.CFrame.Rotation
            })
        end
    end

    Notify("Batch Start", "Syncing " .. #jobs .. " items...", 3)

    local success = RunBatch(jobs)

    -- NEW: Only clear the queue if KeepSelected is off
    if not Settings.KeepSelected then
        State.SelectedObjects = {}
    end
    UpdateVisuals()
    Notify("Finished", success and "Batch complete." or "Batch cancelled.", 3)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │              *** PUBLIC API FOR EXTERNAL SCRIPTS ***            │
-- │                                                                 │
-- │  Usage from another module (e.g. ShopModule):                  │
-- │                                                                 │
-- │    local LOT = require(path.to.LooseObjectTeleport)            │
-- │                                                                 │
-- │    LOT.Select(somePart)                                         │
-- │    LOT.Deselect(somePart)                                       │
-- │    LOT.TeleportTo(CFrame.new(0, 5, 0))                         │
-- │    LOT.TeleportObjectTo(somePart, CFrame.new(100, 5, 200))     │
-- │    LOT.TeleportMany({                                           │
-- │        { target = partA, goalCF = CFrame.new(10, 0, 10) },     │
-- │        { target = partB, goalCF = CFrame.new(20, 0, 10) },     │
-- │    })                                                           │
-- └─────────────────────────────────────────────────────────────────┘

-- Add a BasePart to the selection queue.
function LooseObjectTeleport.Select(part)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"),
        "LOT.Select: expected a BasePart, got " .. typeof(part))
    if State.IsBusy then
        warn("LOT.Select: ignored — a batch is currently running.")
        return
    end
    if not table.find(State.SelectedObjects, part) then
        table.insert(State.SelectedObjects, part)
        UpdateVisuals()
    end
end

-- Remove a BasePart from the selection queue.
function LooseObjectTeleport.Deselect(part)
    local idx = table.find(State.SelectedObjects, part)
    if idx then
        table.remove(State.SelectedObjects, idx)
        UpdateVisuals()
    end
end

-- Clear the entire selection queue.
function LooseObjectTeleport.Clear()
    PerformClear()
end

-- Teleport every part in the selection queue to goalCF.
-- Queue is always cleared after an API call regardless of KeepSelected.
function LooseObjectTeleport.TeleportTo(goalCF)
    assert(typeof(goalCF) == "CFrame",
        "LOT.TeleportTo: expected a CFrame, got " .. typeof(goalCF))
    if #State.SelectedObjects == 0 then
        Notify("LOT API", "Selection queue is empty.", 2)
        return false
    end
    if State.IsBusy then
        warn("LOT.TeleportTo: ignored — a batch is already running.")
        return false
    end

    local jobs = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            table.insert(jobs, { target = obj, goalCF = goalCF })
        end
    end

    local success = RunBatch(jobs)
    State.SelectedObjects = {}
    UpdateVisuals()
    return success
end

-- Teleport a single part to goalCF without touching the selection queue.
function LooseObjectTeleport.TeleportObjectTo(part, goalCF)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"),
        "LOT.TeleportObjectTo: expected a BasePart, got " .. typeof(part))
    assert(typeof(goalCF) == "CFrame",
        "LOT.TeleportObjectTo: expected a CFrame, got " .. typeof(goalCF))
    if State.IsBusy then
        warn("LOT.TeleportObjectTo: ignored — a batch is already running.")
        return false
    end

    return RunBatch({ { target = part, goalCF = goalCF } })
end

-- Teleport multiple parts, each to its own individual CFrame.
function LooseObjectTeleport.TeleportMany(jobs)
    assert(type(jobs) == "table", "LOT.TeleportMany: expected a table of jobs.")
    if State.IsBusy then
        warn("LOT.TeleportMany: ignored — a batch is already running.")
        return false
    end
    return RunBatch(jobs)
end

-- Read-only helpers.
function LooseObjectTeleport.IsBusy()
    return State.IsBusy
end

function LooseObjectTeleport.GetQueueSize()
    return #State.SelectedObjects
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
    Tab:CreateSection("Teleportation Tools")
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
    end)

    -- NEW TOGGLE: Keep selected objects highlighted after a teleport finishes.
    -- When ON, the queue is preserved so you can TP the same set again or inspect
    -- which items were moved. When OFF (default), the queue clears as before.
    Tab:CreateToggle("Keep Selection After TP", false, function(val)
        Settings.KeepSelected = val
    end)

    Tab:CreateSlider("Max Retries", 1, 10, 5, function(val)
        Settings.MaxRetries = val
    end):AddTooltip("How many times to attempt grabbing network ownership per failed object.")

    local MainRow = Tab:CreateRow()
    MainRow:CreateAction("Clear Selection", "Clear", PerformClear)
    MainRow:CreateAction("Teleport Selection", "TP", PerformExecute)

    -- ── Stack TP section ─────────────────────────────────────────
    Tab:CreateSection("Sorting")
    Tab:CreateSlider("X", 1, 100, Settings.StackX, function(val)
        Settings.StackX = val
    end)
    Tab:CreateSlider("Y", 1, 50, Settings.StackY, function(val)
        Settings.StackY = val
    end)
    Tab:CreateSlider("Z", 1, 100, Settings.StackZ, function(val)
        Settings.StackZ = val
    end)

    Tab:CreateSlider("Padding", 0, 10, Settings.StackPadding * 10, function(val)
        Settings.StackPadding = val / 10
    end)

    local StackRow = Tab:CreateRow()
    State.StackStartBtn = StackRow:CreateAction(
        "Sort Selected Objects",
        "Start",
        StartStackMode
    )

    -- ── Input routing ────────────────────────────────────────────
    local mb1DownConn = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end

        if State.StackMode and input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.R then
                State.StackRotation = State.StackRotation * CFrame.Angles(math.rad(90), 0, 0)
                Notify("Stack TP", "X rotation +90°")
                return
            elseif input.KeyCode == Enum.KeyCode.T then
                State.StackRotation = State.StackRotation * CFrame.Angles(0, math.rad(90), 0)
                Notify("Stack TP", "Y rotation +90°")
                return
            end
        end

        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

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

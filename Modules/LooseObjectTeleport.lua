-- [[ LOOSE OBJECT TELEPORT MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local LooseObjectTeleport = {}

local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService   = game:GetService("GuiService")
local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player    = Players.LocalPlayer
local Camera    = workspace.CurrentCamera
local StarterGui = game:GetService("StarterGui")
local Mouse     = Player:GetMouse()

local ClientIsDragging = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientIsDragging")

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        SIGNAL UTILITY                           │
-- └─────────────────────────────────────────────────────────────────┘
local function NewSignal()
    local sig = { _listeners = {} }
    function sig:Connect(fn)
        local id = {}
        self._listeners[id] = fn
        return { Disconnect = function() self._listeners[id] = nil end }
    end
    function sig:Wait()
        local co = coroutine.running()
        local conn
        conn = self:Connect(function(...)
            conn:Disconnect()
            task.spawn(co, ...)
        end)
        return coroutine.yield()
    end
    function sig:_Fire(...)
        for _, fn in pairs(self._listeners) do
            task.spawn(fn, ...)
        end
    end
    return sig
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     CONFIGURATION & STATE                       │
-- └─────────────────────────────────────────────────────────────────┘
local Settings = {
    -- How many times to fire ClientIsDragging per object
    DragFires        = 10,
    -- Delay between each fire
    DragFireDelay    = 0.03,
    -- Max seconds to wait for OwnerString to change before giving up and moving anyway
    OwnershipTimeout = 3,
    -- Fallback wait (s) used when no OwnerString is found on the model
    FallbackWait     = 0.5,
    -- Delay between objects in a batch
    PostObjectDelay  = 0.1,

    SelectionColor  = Color3.fromRGB(74, 120, 255),
    OutlineThickness = 0.02,

    StackX       = 1,
    StackY       = 5,
    StackZ       = 1,
    StackPadding = 0.05,

    KeepSelected = false,
}

local State = {
    SelectedObjects = {},
    SelectionBoxes  = {},
    Connections     = {},
    IsBusy          = false,
    BatchCancelled  = false,

    ClickSelectMode = false,
    GroupSelectMode = false,
    LassoMode       = false,
    LassoDragging   = false,
    LassoStartPos   = nil,
    LassoGui        = nil,
    LassoFrame      = nil,

    StackMode         = false,
    StackPreviewParts = {},
    StackPreviewBoxes = {},
    StackPreviewConn  = nil,
    StackStartBtn     = nil,
    StackRotation     = CFrame.new(),

    Library        = nil,
    BatchCompleted = NewSignal(),
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
        if typeof(val) == "Instance" and val:IsA("Player") then return val.Name end
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
-- │                      CORE TELEPORT LOGIC                        │
-- │                                                                 │
-- │  For each object:                                               │
-- │    1. TP player HRP to the object                               │
-- │    2. Fire ClientIsDragging on the object's model               │
-- │    3. Wait for Owner.OwnerString to change (sync confirmed)     │
-- │    4. Move the object to goalCF                                  │
-- └─────────────────────────────────────────────────────────────────┘

-- Returns a yaw-only CFrame at the given position matching the player's
-- horizontal facing. This is used so items land facing the same direction
-- the player is looking — rotating the player rotates the whole stack.
local function PlayerAlignedCFrame(position, root)
    local look    = root.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.001 then
        flatLook = Vector3.new(0, 0, -1)
    end
    return CFrame.lookAt(position, position + flatLook.Unit)
end

local function TeleportSingle(target, goalCF, root)
    if not target or not target.Parent then return end

    -- Locate Owner.OwnerString for sync detection
    local model       = target:FindFirstAncestorOfClass("Model") or target.Parent
    local ownerFolder = model:FindFirstChild("Owner")
    local ownerString = ownerFolder and ownerFolder:FindFirstChild("OwnerString")
    local initialValue = ownerString and ownerString.Value

    -- 1. TP player next to the object so the server considers us close
    root.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
    task.wait(0.05)

    -- 2. Fire ClientIsDragging to claim ownership
    for i = 1, Settings.DragFires do
        ClientIsDragging:FireServer(model)
        task.wait(Settings.DragFireDelay)
    end

    -- 3. Wait for OwnerString to change — that's the server confirming sync.
    --    Falls back to FallbackWait if no OwnerString exists on this model.
    if ownerString and initialValue ~= nil then
        local deadline = tick() + Settings.OwnershipTimeout
        while tick() < deadline do
            if ownerString.Value ~= initialValue then break end
            task.wait()   -- RunService.Heartbeat cadence
        end
    else
        task.wait(Settings.FallbackWait)
    end

    -- 4. Move the object
    if target and target.Parent then
        target.CFrame = goalCF
    end

    task.wait(Settings.PostObjectDelay)
end

local function RunBatch(jobs)
    if #jobs == 0 then
        State.BatchCompleted:_Fire(true, 0)
        return true
    end

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not root then
        Notify("Error", "Character missing.", 2)
        State.BatchCompleted:_Fire(false, 0)
        return false
    end

    State.IsBusy         = true
    State.BatchCancelled = false

    -- Save player position to restore after batch
    local savedCFrame = root.CFrame

    Notify("Batch", "Teleporting " .. #jobs .. " object(s)…", #jobs * 0.8)

    for _, job in ipairs(jobs) do
        if State.BatchCancelled then break end
        if job.target and job.target.Parent then
            TeleportSingle(job.target, job.goalCF, root)
        end
    end

    -- Return player to where they were before the batch
    if root and root.Parent then
        root.CFrame = savedCFrame
    end

    State.IsBusy = false

    local success = not State.BatchCancelled
    State.BatchCompleted:_Fire(success, #jobs)
    return success
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
    if not playerModels then Notify("Lasso", "PlayerModels not found.") return end

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
-- │                         STACK ENGINE                            │
-- └─────────────────────────────────────────────────────────────────┘
local function AllSelectedSameType()
    if #State.SelectedObjects == 0 then return false, "Queue is empty." end
    local refName, refSig
    for _, obj in ipairs(State.SelectedObjects) do
        if not (obj and obj.Parent) then continue end
        local model = obj:FindFirstAncestorOfClass("Model")
        local name  = model and model.Name or obj.Name
        local sig   = model and GetModelSignature(model) or (obj.ClassName .. ":" .. obj.Name)
        if not refName then
            refName = name; refSig = sig
        elseif name ~= refName or sig ~= refSig then
            return false, "Mixed item types — all items must be identical."
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
    if State.StackPreviewConn then State.StackPreviewConn:Disconnect() State.StackPreviewConn = nil end
    for _, box in ipairs(State.StackPreviewBoxes) do if box and box.Parent then box:Destroy() end end
    State.StackPreviewBoxes = {}
    for _, p in ipairs(State.StackPreviewParts) do if p and p.Parent then p:Destroy() end end
    State.StackPreviewParts = {}
end

local function SetStackBtnLabel(label)
    if State.StackStartBtn then
        if State.StackStartBtn.SetLabel then State.StackStartBtn:SetLabel(label)
        elseif State.StackStartBtn.SetText then State.StackStartBtn:SetText(label) end
    end
end

local function StopStackMode(silent)
    State.StackMode     = false
    State.StackRotation = CFrame.new()
    ClearStackPreview()
    SetStackBtnLabel("Start")
    if not silent then Notify("Stack TP", "Placement cancelled.") end
end

local function StartStackMode()
    if State.StackMode then StopStackMode() return end

    local ok, reason = AllSelectedSameType()
    if not ok then Notify("Stack TP — Blocked", reason, 4) return end

    local capacity = Settings.StackX * Settings.StackY * Settings.StackZ
    if capacity < #State.SelectedObjects then
        Notify("Stack TP — Too Small",
            "Grid holds " .. capacity .. " but queue has " .. #State.SelectedObjects .. ".\nIncrease sliders.", 5)
        return
    end

    local refSize = Vector3.new(4, 4, 4)
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then refSize = obj.Size break end
    end

    ClearStackPreview()
    for i = 1, #State.SelectedObjects do
        local p        = Instance.new("Part")
        p.Name         = "StackPreview_" .. i
        p.Size         = refSize
        p.Anchored     = true
        p.CanCollide   = false
        p.CanTouch     = false
        p.Transparency = 0.45
        p.Color        = Color3.fromRGB(80, 130, 255)
        p.Material     = Enum.Material.Neon
        p.CastShadow   = false
        p.Parent       = workspace
        table.insert(State.StackPreviewParts, p)

        local box         = Instance.new("SelectionBox")
        box.Color3        = Color3.fromRGB(140, 180, 255)
        box.LineThickness = 0.03
        box.Adornee       = p
        box.Parent        = game:GetService("CoreGui")
        table.insert(State.StackPreviewBoxes, box)
    end

    State.StackMode = true
    SetStackBtnLabel("Stop")
    Notify("Stack TP", "Move cursor — click to place " .. #State.SelectedObjects .. " items.", 4)

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
        local groundOrigin = result
            and (result.Position + Vector3.new(0, refSize.Y * 0.5, 0))
            or (unitRay.Origin + unitRay.Direction * 40)

        local positions = GetStackPositions(
            groundOrigin, refSize,
            Settings.StackX, Settings.StackY, Settings.StackZ,
            #State.StackPreviewParts, State.StackRotation
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
    if not ok then StopStackMode() Notify("Stack TP — Blocked", reason, 4) return end

    local refSize = Vector3.new(4, 4, 4)
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then refSize = obj.Size break end
    end

    local groundOrigin    = hitPos + Vector3.new(0, refSize.Y * 0.5, 0)
    local goalPositions   = GetStackPositions(
        groundOrigin, refSize,
        Settings.StackX, Settings.StackY, Settings.StackZ,
        #State.SelectedObjects, State.StackRotation
    )
    local capturedRotation = State.StackRotation
    StopStackMode(true)

    local jobs = {}
    for i, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            table.insert(jobs, {
                target = obj,
                goalCF = CFrame.new(goalPositions[i] or groundOrigin) * capturedRotation
            })
        end
    end

    task.spawn(function()
        local success = RunBatch(jobs)
        if not Settings.KeepSelected then State.SelectedObjects = {} end
        UpdateVisuals()
        Notify("Stack TP", success and "Stack complete!" or "Batch cancelled.", 3)
    end)
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
            Notify("Removed", "Object removed. Queue: " .. #State.SelectedObjects)
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
    local addedCount, removedCount = 0, 0

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
    Notify("Cleared", "Queue emptied.")
end

local function PerformExecute()
    if #State.SelectedObjects == 0 or not Player.Character then
        Notify("Wait", "Queue empty or missing character.", 2)
        return
    end
    local char = Player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local finalPos = root.Position

    local jobs = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then
            table.insert(jobs, {
                target = obj,
                goalCF = PlayerAlignedCFrame(finalPos, root)
            })
        end
    end

    task.spawn(function()
        local success = RunBatch(jobs)
        if not Settings.KeepSelected then State.SelectedObjects = {} end
        UpdateVisuals()
        Notify("Finished", success and "Batch complete." or "Batch cancelled.", 3)
    end)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         PUBLIC API                              │
-- └─────────────────────────────────────────────────────────────────┘
function LooseObjectTeleport.Select(part)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"), "LOT.Select: expected BasePart")
    if State.IsBusy then warn("LOT.Select: ignored — batch running.") return end
    if not table.find(State.SelectedObjects, part) then
        table.insert(State.SelectedObjects, part)
        UpdateVisuals()
    end
end

function LooseObjectTeleport.Deselect(part)
    local idx = table.find(State.SelectedObjects, part)
    if idx then table.remove(State.SelectedObjects, idx) UpdateVisuals() end
end

function LooseObjectTeleport.Clear()
    PerformClear()
end

function LooseObjectTeleport.TeleportTo(goalCF)
    assert(typeof(goalCF) == "CFrame", "LOT.TeleportTo: expected CFrame")
    if #State.SelectedObjects == 0 then Notify("LOT API", "Queue is empty.", 2) return false end
    if State.IsBusy then warn("LOT.TeleportTo: ignored — batch running.") return false end
    local jobs = {}
    for _, obj in ipairs(State.SelectedObjects) do
        if obj and obj.Parent then table.insert(jobs, { target = obj, goalCF = goalCF }) end
    end
    local success = RunBatch(jobs)
    State.SelectedObjects = {}
    UpdateVisuals()
    return success
end

function LooseObjectTeleport.TeleportObjectTo(part, goalCF)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"), "LOT.TeleportObjectTo: expected BasePart")
    assert(typeof(goalCF) == "CFrame", "LOT.TeleportObjectTo: expected CFrame")
    if State.IsBusy then warn("LOT.TeleportObjectTo: ignored — batch running.") return false end
    return RunBatch({ { target = part, goalCF = goalCF } })
end

function LooseObjectTeleport.TeleportMany(jobs)
    assert(type(jobs) == "table", "LOT.TeleportMany: expected table of jobs")
    if State.IsBusy then warn("LOT.TeleportMany: ignored — batch running.") return false end
    return RunBatch(jobs)
end

function LooseObjectTeleport.WaitForBatch()
    if not State.IsBusy then return true, 0 end
    return State.BatchCompleted:Wait()
end

function LooseObjectTeleport.IsBusy()
    return State.IsBusy
end

function LooseObjectTeleport.GetQueueSize()
    return #State.SelectedObjects
end

LooseObjectTeleport.BatchCompleted = nil

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                          INITIALIZE                             │
-- └─────────────────────────────────────────────────────────────────┘
function LooseObjectTeleport.Init(Tab, LibraryInstance)
    State.Library = LibraryInstance
    LooseObjectTeleport.BatchCompleted = State.BatchCompleted

    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    State.Connections = {}

    InitLassoGui()

    Tab:CreateSection("Teleportation Tools")
    Tab:CreateToggle("Click Selection", false, function(val) State.ClickSelectMode = val end)
    Tab:CreateToggle("Group Selection", false, function(val) State.GroupSelectMode = val end)
    Tab:CreateToggle("Lasso Tool", false, function(val)
        State.LassoMode = val
        if not val then
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
        end
    end)
    Tab:CreateToggle("Keep Selection After TP", false, function(val) Settings.KeepSelected = val end)

    Tab:CreateSlider("Ownership Timeout (s)", 1, 10, Settings.OwnershipTimeout, function(val)
        Settings.OwnershipTimeout = val
    end):AddTooltip("Max seconds to wait for OwnerString sync before moving the object anyway.")

    Tab:CreateSlider("Drag Fires", 1, 30, Settings.DragFires, function(val)
        Settings.DragFires = val
    end):AddTooltip("How many times ClientIsDragging is fired per object to claim ownership.")

    local MainRow = Tab:CreateRow()
    MainRow:CreateAction("Clear Selection", "Clear", PerformClear)
    MainRow:CreateAction("Teleport Selection", "TP", function()
        task.spawn(PerformExecute)
    end)

    Tab:CreateSection("Sorting")
    Tab:CreateSlider("X", 1, 100, Settings.StackX, function(val) Settings.StackX = val end)
    Tab:CreateSlider("Y", 1, 50,  Settings.StackY, function(val) Settings.StackY = val end)
    Tab:CreateSlider("Z", 1, 100, Settings.StackZ, function(val) Settings.StackZ = val end)
    Tab:CreateSlider("Padding", 0, 10, Settings.StackPadding * 10, function(val)
        Settings.StackPadding = val / 10
    end)

    local StackRow = Tab:CreateRow()
    State.StackStartBtn = StackRow:CreateAction("Sort Selected Objects", "Start", StartStackMode)

    -- Input routing
    table.insert(State.Connections, UIS.InputBegan:Connect(function(input, processed)
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
            if State.LassoFrame then State.LassoFrame.Size = UDim2.fromOffset(0,0) State.LassoFrame.Visible = false end

        elseif State.GroupSelectMode then
            PerformGroupSelect()

        elseif State.ClickSelectMode then
            PerformSingleSelect()
        end
    end))

    table.insert(State.Connections, UIS.InputChanged:Connect(function(input)
        if State.LassoDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateLassoFrame(UIS:GetMouseLocation())
        end
    end))

    table.insert(State.Connections, UIS.InputEnded:Connect(function(input)
        if State.LassoDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.LassoDragging = false
            if State.LassoFrame then State.LassoFrame.Visible = false end
            SelectObjectsInLassoRect(State.LassoStartPos, UIS:GetMouseLocation())
            State.LassoStartPos = nil
        end
    end))

    UpdateVisuals()
end

function LooseObjectTeleport.Unload()
    StopStackMode(true)
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    for _, v in pairs(State.SelectionBoxes) do v:Destroy() end
    if State.LassoGui then State.LassoGui:Destroy() end
    Notify("Unloaded", "Loose Object Teleport unloaded.")
end

return LooseObjectTeleport

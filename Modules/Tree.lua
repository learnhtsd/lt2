local TreeModule = {}

-- ==========================================
--             SYSTEM SETTINGS
-- ==========================================
local Settings = {
    AxePriority = {
        "ManyAxe", "Rukiryaxe", "AxeAlphaTesters", "IceAxe", "AxeTwitter",
        "Beesaxe", "CandyCaneAxe", "RustyAxe", "GingerbreadAxe", "FireAxe",
        "AxeChicken", "InverseAxe", "AxeSwamp", "AxePig", "SilverAxe",
        "Axe3", "Axe2", "Axe1", "BasicHatchet"
    },

    LogBindings = {
        ["Cherry"]      = "PieAxe",
        ["Volcano"]     = "FireAxe",
        ["Frost"]       = "IceAxe",
        ["GoldSwampy"]  = "AxeSwamp",
        ["GreenSwampy"] = "AxeSwamp",
        ["Walnut"]      = "GingerbreadAxe",
        ["Koa"]         = "GingerbreadAxe",
        ["CaveCrawler"] = "CaveAxe",
        ["LoneCave"]    = "EndTimesAxe",
    },

    -- [ Movement & View ]
    DistanceToTree  = 3.5,
    VerticalOffset  = 0.4,
    HideGround      = true,

    SyncDelay       = 0.25,
    ReadyDelay      = 0.3,

    -- [ Chopping Speed ]
    SwingHoldTime   = 0.1,
    SwingCooldown   = 0.12,
    RandomVariation = 0.02,

    -- [ LOT Settings ]
    -- How long to wait after chop completes for logs to physically settle
    -- in the world before LOT tries to grab them.
    LogSettleDelay  = 1.5,
    -- Drop offset in front of the player when logs are delivered.
    LogDropDistance = 6,
}

-- ==========================================
--             CORE SERVICES & VARS
-- ==========================================
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player  = Players.LocalPlayer
local camera  = Workspace.CurrentCamera

local isChopping          = false
local currentTargetWood   = nil
local preChopCFrame       = nil
local preChopCameraCFrame = nil
local lockConn            = nil

local groundObject         = Workspace:FindFirstChild("Baseplate")
local originalTransparency = groundObject and groundObject.Transparency or 0

-- ==========================================
--             UTILITY FUNCTIONS
-- ==========================================
local function SetGroundVisible(visible)
    if not groundObject or not Settings.HideGround then return end
    groundObject.Transparency = visible and originalTransparency or 1
end

local function GetAxeFromBackpack(targetAxeName)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, item in ipairs(backpack:GetChildren()) do
        if item.Name == "Tool" then
            local toolNameObj = item:FindFirstChild("ToolName")
            if toolNameObj and toolNameObj.Value == targetAxeName then
                return item
            end
        end
    end
    return nil
end

local function DetermineAndEquipAxe(treeClass)
    local targetAxe = nil
    local boundName = Settings.LogBindings[treeClass]
    if boundName then targetAxe = GetAxeFromBackpack(boundName) end

    if not targetAxe then
        for _, name in ipairs(Settings.AxePriority) do
            local found = GetAxeFromBackpack(name)
            if found then targetAxe = found; break end
        end
    end

    if targetAxe and player.Character then
        targetAxe.Parent = player.Character
        return targetAxe
    end
    return player.Character and player.Character:FindFirstChildOfClass("Tool")
end

local function FindPriorityWood(treeClass)
    local targetPart = nil
    local maxSections = -1

    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder.Name:lower():match("treeregion") then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model")
                and model:FindFirstChild("TreeClass")
                and model.TreeClass.Value == treeClass then
                    local sectionCount   = 0
                    local tempLowestPart = nil
                    local lowestY        = math.huge

                    for _, part in ipairs(model:GetChildren()) do
                        if part.Name == "WoodSection" then
                            sectionCount = sectionCount + 1
                            if part.Position.Y < lowestY then
                                lowestY        = part.Position.Y
                                tempLowestPart = part
                            end
                        end
                    end

                    if treeClass == "Generic" and sectionCount < 12 then continue end

                    if sectionCount > maxSections and tempLowestPart then
                        maxSections = sectionCount
                        targetPart  = tempLowestPart
                    end
                end
            end
        end
    end
    return targetPart
end

local function ScanForTreeTypes()
    local foundTypes = {}
    local seen = {}
    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder.Name:lower():match("treeregion") then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local treeClass = model:FindFirstChild("TreeClass")
                    if treeClass and treeClass:IsA("StringValue") and not seen[treeClass.Value] then
                        seen[treeClass.Value] = true
                        table.insert(foundTypes, treeClass.Value)
                    end
                end
            end
        end
    end
    return #foundTypes > 0 and foundTypes or {"None Found"}
end

local function CleanupState()
    isChopping = false
    currentTargetWood = nil
    SetGroundVisible(true)

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")

    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool.Parent = player:FindFirstChild("Backpack") end
    end

    if hrp and preChopCFrame then
        hrp.CFrame = preChopCFrame
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end

    player.CameraMode = Enum.CameraMode.Classic

    if preChopCameraCFrame then
        camera.CFrame = preChopCameraCFrame
    end

    if lockConn then
        lockConn:Disconnect()
        lockConn = nil
    end
end

-- ==========================================
--   COLLECT LOOSE LOGS FROM PLAYERMODELS
--   after the tree has been chopped.
--
--   Scans workspace.PlayerModels for any
--   Model whose TreeClass matches treeClass
--   and returns the "Main" BasePart of each,
--   ready to pass straight into LOT.
-- ==========================================
local function CollectLooseLogs(treeClass)
    local parts = {}
    local logModels = Workspace:FindFirstChild("LogModels")

    if not logModels then
        warn("[TreeModule] workspace.LogModels not found.")
        return parts
    end

    for _, model in ipairs(logModels:GetChildren()) do
        if model:IsA("Model") then
            local tc = model:FindFirstChild("TreeClass")
            if tc and tc.Value == treeClass then
                local main = model:FindFirstChild("Main")
                if main and main:IsA("BasePart") then
                    table.insert(parts, main)
                end
            end
        end
    end

    if #parts == 0 then
        warn("[TreeModule] No logs found in workspace.LogModels for TreeClass:", treeClass)
    end

    return parts
end

-- ==========================================
--   BUILD LOT JOB LIST
--   Fans logs out in a row in front of
--   the player so they don't all stack.
-- ==========================================
local function BuildLOTJobs(logParts)
    local jobs = {}
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return jobs end

    local origin   = hrp.CFrame
    local forward  = origin.LookVector
    local right    = origin.RightVector
    local spacing  = 5  -- studs between each log side-by-side
    local count    = #logParts
    local startOff = -((count - 1) / 2) * spacing  -- centre the row

    for i, part in ipairs(logParts) do
        local sideOffset = startOff + (i - 1) * spacing
        local goalPos    = origin.Position
                         + (forward * Settings.LogDropDistance)
                         + (right   * sideOffset)
                         + Vector3.new(0, 2, 0)  -- slight lift so logs don't clip ground
        table.insert(jobs, {
            target = part,
            goalCF = CFrame.new(goalPos),
        })
    end

    return jobs
end

-- ==========================================
--             CHOP + DELIVER
-- ==========================================
local function StartChopping(treeClass, LOT, onComplete)
    if isChopping then return end

    local targetWood = FindPriorityWood(treeClass)
    if not targetWood then return end

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local equippedTool = DetermineAndEquipAxe(treeClass)
    if not equippedTool then return end

    -- Save state so CleanupState can return us home.
    preChopCFrame       = hrp.CFrame
    preChopCameraCFrame = camera.CFrame

    isChopping        = true
    currentTargetWood = targetWood
    local originalSizeY = currentTargetWood.Size.Y

    SetGroundVisible(false)

    -- Position player next to the bottom log.
    local logUp     = targetWood.CFrame.UpVector
    local halfHeight = targetWood.Size.Y / 2
    local aimPoint  = targetWood.Position - (logUp * (halfHeight * 0.7))

    local lookDir   = targetWood.CFrame.LookVector
    local standPos  = aimPoint
                    + (lookDir * Settings.DistanceToTree)
                    + Vector3.new(0, Settings.VerticalOffset, 0)

    local baseLook       = CFrame.lookAt(standPos, aimPoint)
    local upsideDownCFrame = baseLook * CFrame.Angles(0, 0, math.pi)

    hrp.CFrame = upsideDownCFrame
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    task.wait(Settings.SyncDelay)
    player.CameraMode = Enum.CameraMode.LockFirstPerson

    lockConn = RunService.RenderStepped:Connect(function()
        if isChopping and currentTargetWood then
            hrp.CFrame = upsideDownCFrame
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPoint)
                          * CFrame.Angles(0, 0, math.pi)
        else
            if lockConn then lockConn:Disconnect() end
        end
    end)

    task.wait(Settings.ReadyDelay)

    task.spawn(function()
        local center = camera.ViewportSize / 2
        local rng    = Random.new()

        -- ── PHASE 1: CHOP ──────────────────────────────────────────────
        while isChopping
        and currentTargetWood.Parent
        and currentTargetWood:IsDescendantOf(Workspace) do

            -- A meaningful size change means the section detached — stop.
            if math.abs(currentTargetWood.Size.Y - originalSizeY) > 0.4 then
                break
            end

            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true,  game, 1)
            task.wait(Settings.SwingHoldTime)
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
            task.wait(Settings.SwingCooldown
                     + rng:NextNumber(-Settings.RandomVariation, Settings.RandomVariation))
        end

        -- ── PHASE 2: RETURN PLAYER HOME ────────────────────────────────
        -- CleanupState teleports the player back to preChopCFrame,
        -- unequips the axe, restores the camera, and clears isChopping.
        CleanupState()

        -- ── PHASE 3: WAIT FOR LOGS TO SETTLE ──────────────────────────
        -- Give the physics sim time to drop the cut sections into
        -- PlayerModels so CollectLooseLogs can find them.
        task.wait(Settings.LogSettleDelay)

        -- ── PHASE 4: TELEPORT LOGS TO PLAYER VIA LOT ──────────────────
        if LOT then
            local logParts = CollectLooseLogs(treeClass)

            if #logParts > 0 then
                -- Guard: don't stack calls if LOT is already busy
                -- (e.g. called from another module simultaneously).
                if not LOT.IsBusy() then
                    local jobs = BuildLOTJobs(logParts)
                    -- Run in its own thread so onComplete fires after delivery.
                    task.spawn(function()
                        LOT.TeleportMany(jobs)
                        if onComplete then onComplete() end
                    end)
                else
                    -- LOT is busy — skip delivery and fire completion anyway.
                    warn("[TreeModule] LOT is busy; skipping log delivery.")
                    if onComplete then onComplete() end
                end
            else
                -- No loose logs found (tree may still be standing).
                if onComplete then onComplete() end
            end
        else
            -- No LOT reference provided; just signal done.
            if onComplete then onComplete() end
        end
    end)
end

-- ==========================================
--             DYNXE UI INITIALIZATION
-- ==========================================
-- LOT is optional. Pass it in from your loader:
--   TreeModule.Init(Tab, LooseObjectTeleportModule)
-- If omitted the module chops normally with no delivery step.
function TreeModule.Init(Tab, LOT)
    Tab:CreateSection("Auto Chop Settings")

    local treeTypes    = ScanForTreeTypes()
    local selectedTree = treeTypes[1] or "None Found"
    local chopActionButton

    Tab:CreateDropdown("Target Wood Type", treeTypes, selectedTree, function(selected)
        selectedTree = selected
    end):AddTooltip("Select the type of tree to hunt and chop. Logs will be teleported back to you after the chop.")

    chopActionButton = Tab:CreateAction("Process Tree", "Start Chop", function()
        if isChopping then
            -- Cancel mid-chop.
            isChopping = false
            if type(chopActionButton) == "table" and chopActionButton.SetText then
                chopActionButton:SetText("Start Chop")
            end
        else
            if selectedTree == "None Found" then return end

            if type(chopActionButton) == "table" and chopActionButton.SetText then
                chopActionButton:SetText("Cancel")
            end

            StartChopping(selectedTree, LOT, function()
                if type(chopActionButton) == "table" and chopActionButton.SetText then
                    chopActionButton:SetText("Start Chop")
                end
            end)
        end
    end)

    if type(chopActionButton) == "table" and chopActionButton.AddTooltip then
        chopActionButton:AddTooltip("Chops the target tree, then teleports the logs back to you. Click again to cancel.")
    end
end

return TreeModule

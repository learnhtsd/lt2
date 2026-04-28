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
    LogSettleDelay  = 1.5,
    LogDropDistance = 6,
    ResizeTarget    = Vector3.new(3, 3, 3),

    -- [ Sell Location ]
    SellPosition    = Vector3.new(315.0, 1, 88.3),
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

local preChopLogModels    = {}

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
    local targetPart  = nil
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

local function SnapshotLogModels()
    preChopLogModels = {}
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then return end
    for _, model in ipairs(logModels:GetChildren()) do
        preChopLogModels[model] = true
    end
end

-- ==========================================
--   OWNERSHIP CHECK
--   Checks both Owner (ObjectValue → Player)
--   and OwnerString (StringValue → player.Name)
-- ==========================================
local function IsOwnedByLocalPlayer(model)
    local ownerObj = model:FindFirstChild("Owner")
    if ownerObj then
        -- ObjectValue pointing directly to the Player instance
        if ownerObj:IsA("ObjectValue") and ownerObj.Value == player then
            return true
        end
        -- StringValue holding the player's name
        if ownerObj:IsA("StringValue") and ownerObj.Value == player.Name then
            return true
        end
    end

    local ownerStr = model:FindFirstChild("OwnerString")
    if ownerStr and ownerStr:IsA("StringValue") and ownerStr.Value == player.Name then
        return true
    end

    return false
end

-- ==========================================
--   COLLECT STUMPS (WoodSection with ID=1)
--   from models that are NEW since snapshot
-- ==========================================
local function CollectNewStumps(treeClass)
    local results   = {}
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then
        warn("[TreeModule] workspace.LogModels not found.")
        return results
    end

    for _, model in ipairs(logModels:GetChildren()) do
        if preChopLogModels[model] then continue end

        if model:IsA("Model") then
            local tc = model:FindFirstChild("TreeClass")
            if tc and tc.Value == treeClass then
                for _, part in ipairs(model:GetChildren()) do
                    if part.Name == "WoodSection" and part:IsA("BasePart") then
                        local id = part:FindFirstChild("ID")
                        if id and id.Value == 1 then
                            table.insert(results, part)
                            break
                        end
                    end
                end
            end
        end
    end

    if #results == 0 then
        warn("[TreeModule] No stump (WoodSection ID=1) found after chop for TreeClass:", treeClass)
    end

    return results
end

-- ==========================================
--   COLLECT ALL OWNED STUMPS
--   Scans ALL of LogModels for logs owned
--   by the local player regardless of chop.
-- ==========================================
local function CollectAllOwnedStumps()
    local results   = {}
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then
        warn("[TreeModule] workspace.LogModels not found.")
        return results
    end

    for _, model in ipairs(logModels:GetChildren()) do
        if not model:IsA("Model") then continue end
        if not IsOwnedByLocalPlayer(model) then continue end

        -- Grab the WoodSection with ID == 1 (stump) as the grab handle
        for _, part in ipairs(model:GetChildren()) do
            if part.Name == "WoodSection" and part:IsA("BasePart") then
                local id = part:FindFirstChild("ID")
                if id and id.Value == 1 then
                    table.insert(results, part)
                    break
                end
            end
        end
    end

    if #results == 0 then
        warn("[TreeModule] No owned logs found in workspace.LogModels.")
    end

    return results
end

local function CleanupState()
    isChopping        = false
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
--   SHARED LOT BATCH HELPER
--   Teleports a list of stump parts to a
--   list of goal CFrames via LOT, one by one.
-- ==========================================
local function RunLOTBatch(LOT, stumps, goalCFBuilder, onComplete)
    if not LOT then
        if onComplete then onComplete() end
        return
    end

    if #stumps == 0 then
        warn("[TreeModule] RunLOTBatch: nothing to teleport.")
        if onComplete then onComplete() end
        return
    end

    task.spawn(function()
        for i, stump in ipairs(stumps) do
            if LOT.IsBusy() then
                repeat task.wait(0.1) until not LOT.IsBusy()
            end

            local goalCF = goalCFBuilder(i, stump)

            local originalSize = stump.Size
            stump.Size = Settings.ResizeTarget

            LOT.TeleportObjectTo(stump, goalCF)

            -- Reset size after this specific TP finishes
            task.spawn(function()
                repeat task.wait(0.1) until not LOT.IsBusy()
                if stump and stump.Parent then
                    stump.Size = originalSize
                end
            end)
        end

        if onComplete then onComplete() end
    end)
end

-- ==========================================
--             CHOP + DELIVER
-- ==========================================
local function StartChopping(treeClass, LOT, onComplete)
    if isChopping then return end

    SnapshotLogModels()

    local targetWood = FindPriorityWood(treeClass)
    if not targetWood then return end

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local equippedTool = DetermineAndEquipAxe(treeClass)
    if not equippedTool then return end

    preChopCFrame       = hrp.CFrame
    preChopCameraCFrame = camera.CFrame

    isChopping        = true
    currentTargetWood = targetWood
    local originalSizeY = currentTargetWood.Size.Y

    SetGroundVisible(false)

    local logUp      = targetWood.CFrame.UpVector
    local halfHeight = targetWood.Size.Y / 2
    local aimPoint   = targetWood.Position - (logUp * (halfHeight * 0.7))

    local lookDir        = targetWood.CFrame.LookVector
    local standPos       = aimPoint
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

        -- ── PHASE 1: CHOP ─────────────────────────────────────────────
        while isChopping
        and currentTargetWood.Parent
        and currentTargetWood:IsDescendantOf(Workspace) do
            if math.abs(currentTargetWood.Size.Y - originalSizeY) > 0.4 then
                break
            end
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true,  game, 1)
            task.wait(Settings.SwingHoldTime)
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
            task.wait(Settings.SwingCooldown
                     + rng:NextNumber(-Settings.RandomVariation, Settings.RandomVariation))
        end

        -- ── PHASE 2: RETURN PLAYER HOME ───────────────────────────────
        CleanupState()

        -- ── PHASE 3: WAIT FOR LOGS TO SETTLE ─────────────────────────
        task.wait(Settings.LogSettleDelay)

        -- ── PHASE 4: DELIVER NEW LOGS ─────────────────────────────────
        local stumps     = CollectNewStumps(treeClass)
        local currentHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

        RunLOTBatch(LOT, stumps, function(i, _)
            return currentHRP
                and (currentHRP.CFrame * CFrame.new((i - 1) * 5, 0, -Settings.LogDropDistance))
                or CFrame.new(0, 0, 0)
        end, onComplete)
    end)
end

-- ==========================================
--             DYNXE UI INITIALIZATION
-- ==========================================
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
        chopActionButton:AddTooltip("Chops the target tree then teleports your logs back to you.")
    end

    -- ── LOG MANAGEMENT SECTION ────────────────────────────────────────
    Tab:CreateSection("Log Management")

    -- TP ALL LOGS TO PLAYER
    local tpAllButton = Tab:CreateAction("Teleport Logs", "TP All My Logs", function()
        if not LOT then
            warn("[TreeModule] LOT not available.")
            return
        end
        if LOT.IsBusy() then
            warn("[TreeModule] LOT is busy — try again shortly.")
            return
        end

        local stumps     = CollectAllOwnedStumps()
        local currentHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

        if #stumps == 0 then
            warn("[TreeModule] No owned logs found to teleport.")
            return
        end

        if type(tpAllButton) == "table" and tpAllButton.SetText then
            tpAllButton:SetText("Working...")
        end

        RunLOTBatch(LOT, stumps, function(i, _)
            return currentHRP
                and (currentHRP.CFrame * CFrame.new((i - 1) * 5, 0, -Settings.LogDropDistance))
                or CFrame.new(0, 0, 0)
        end, function()
            if type(tpAllButton) == "table" and tpAllButton.SetText then
                tpAllButton:SetText("TP All My Logs")
            end
        end)
    end)

    if type(tpAllButton) == "table" and tpAllButton.AddTooltip then
        tpAllButton:AddTooltip("Teleports all logs you own in the world to your current position.")
    end

    -- SELL ALL LOGS
    local sellButton = Tab:CreateAction("Sell Logs", "Sell All My Logs", function()
        if not LOT then
            warn("[TreeModule] LOT not available.")
            return
        end
        if LOT.IsBusy() then
            warn("[TreeModule] LOT is busy — try again shortly.")
            return
        end

        local stumps = CollectAllOwnedStumps()

        if #stumps == 0 then
            warn("[TreeModule] No owned logs found to sell.")
            return
        end

        if type(sellButton) == "table" and sellButton.SetText then
            sellButton:SetText("Selling...")
        end

        -- Fan logs out around the sell point so they don't all stack
        local sellPos = Settings.SellPosition
        RunLOTBatch(LOT, stumps, function(i, _)
            return CFrame.new(
                sellPos.X + ((i - 1) * 5),
                sellPos.Y,
                sellPos.Z
            )
        end, function()
            if type(sellButton) == "table" and sellButton.SetText then
                sellButton:SetText("Sell All My Logs")
            end
        end)
    end)

    if type(sellButton) == "table" and sellButton.AddTooltip then
        sellButton:AddTooltip("Teleports all logs you own to the sawmill sell point.")
    end
end

return TreeModule

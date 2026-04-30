local TreeModule = {}

-- ==========================================
--             SYSTEM SETTINGS
-- ==========================================
local Settings = {
    -- [ Movement & View ]
    DistanceToTree  = 3.5,
    VerticalOffset  = 0.4,
    HideGround      = true,

    SyncDelay       = 0.25,
    ReadyDelay      = 0.1,

    -- [ Cut Settings ]
    -- How many FireServer calls per WoodSection per pass.
    -- High damage axes only need 1-2 passes; lower damage axes may need more.
    -- The loop will keep firing until the section is actually gone.
    FiresPerSection = 50,
    -- Delay between individual fires within a single pass (lets server register each cut)
    FireDelay       = 0.03,
    -- Delay between full section sweeps (lets the server process cuts)
    SweepDelay      = 0.1,
    -- How long (seconds) to keep hammering the base before giving up
    ChopTimeout     = 30,

    -- [ LOT Settings ]
    LogDropDistance = 6,
    ResizeTarget    = Vector3.new(3, 3, 3),

    -- [ Sell Location ]
    SellPosition    = Vector3.new(315.0, 1, 88.3),
}

-- ==========================================
--             DAMAGE TABLE
--   Mirrors the Xeno script damage values.
--   Used to set hitPoints in CutArguments.
-- ==========================================
local AxeDamage = {
    ["Basic Hatchet"]       = function(_)      return 0.2        end,
    ["Plain Axe"]           = function(_)      return 0.55       end,
    ["Steel Axe"]           = function(_)      return 0.93       end,
    ["Hardened Axe"]        = function(_)      return 1.45       end,
    ["Silver Axe"]          = function(_)      return 1.6        end,
    ["Rukiryaxe"]           = function(_)      return 1.68       end,
    ["Beta Axe of Bosses"]  = function(_)      return 1.45       end,
    ["Alpha Axe of Testing"]= function(_)      return 1.5        end,
    ["Johiro"]              = function(_)      return 1.8        end,
    ["Beesaxe"]             = function(_)      return 1.4        end,
    ["CHICKEN AXE"]         = function(_)      return 0.9        end,
    ["Amber Axe"]           = function(_)      return 3.39       end,
    ["The Many Axe"]        = function(_)      return 10.2       end,
    ["Candy Cane Axe"]      = function(_)      return 0          end,
    ["Fire Axe"]            = function(tc)     return tc == "Volcano"     and 6.35 or 0.6    end,
    ["End Times Axe"]       = function(tc)     return tc == "LoneCave"    and 1e7  or 1.58   end,
    ["Gingerbread Axe"]     = function(tc)
        if tc == "Walnut" then return 8.5
        elseif tc == "Koa" then return 11
        else return 1.2 end
    end,
    ["Bird Axe"]            = function(tc)
        if tc == "Volcano"     then return 2.5
        elseif tc == "CaveCrawler" then return 3.9
        else return 1.65 end
    end,
}

local function GetDamage(axeName, treeClass)
    local fn = AxeDamage[axeName]
    return fn and fn(treeClass) or 1.0   -- default fallback
end

-- ==========================================
--             CORE SERVICES & VARS
-- ==========================================
local Players  = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isChopping          = false
local preChopCFrame       = nil
local preChopCameraCFrame = nil
local lockConn            = nil
local preChopLogModels    = {}

local groundObject         = Workspace:FindFirstChild("Baseplate")
local originalTransparency = groundObject and groundObject.Transparency or 0

-- ==========================================
--             UTILITY
-- ==========================================
local function SetGroundVisible(visible)
    if not groundObject or not Settings.HideGround then return end
    groundObject.Transparency = visible and originalTransparency or 1
end

-- Returns the equipped Tool and its display name (via ToolTip child or property)
local function GetEquippedAxe()
    local char = player.Character
    if not char then return nil, nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil, nil end
    local tipChild = tool:FindFirstChild("ToolTip")
    local name = (tipChild and tipChild:IsA("StringValue")) and tipChild.Value or tool.ToolTip
    return tool, name
end

local function ScanForTreeTypes()
    local found, seen = {}, {}
    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder.Name:lower():match("treeregion") then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local tc = model:FindFirstChild("TreeClass")
                    if tc and tc:IsA("StringValue") and not seen[tc.Value] then
                        seen[tc.Value] = true
                        table.insert(found, tc.Value)
                    end
                end
            end
        end
    end
    return #found > 0 and found or {"None Found"}
end

-- Finds the tree of treeClass with the most WoodSections (biggest tree)
local function FindPriorityTree(treeClass)
    local bestModel   = nil
    local maxSections = -1

    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder.Name:lower():match("treeregion") then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model")
                and model:FindFirstChild("TreeClass")
                and model.TreeClass.Value == treeClass then
                    local count = 0
                    for _, part in ipairs(model:GetChildren()) do
                        if part.Name == "WoodSection" then count += 1 end
                    end
                    if treeClass == "Generic" and count < 12 then continue end
                    if count > maxSections then
                        maxSections = count
                        bestModel   = model
                    end
                end
            end
        end
    end
    return bestModel
end

-- Returns all WoodSection parts in a tree model, bottom-first
local function GetSectionsBottomFirst(treeModel)
    local sections = {}
    for _, part in ipairs(treeModel:GetChildren()) do
        if part.Name == "WoodSection" then
            table.insert(sections, part)
        end
    end
    table.sort(sections, function(a, b)
        return a.Position.Y < b.Position.Y
    end)
    return sections
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
-- ==========================================
local function IsOwnedByLocalPlayer(model)
    local ownerObj = model:FindFirstChild("Owner")
    if ownerObj then
        if ownerObj:IsA("ObjectValue") and ownerObj.Value == player then return true end
        if ownerObj:IsA("StringValue") and ownerObj.Value == player.Name then return true end
    end
    local ownerStr = model:FindFirstChild("OwnerString")
    if ownerStr and ownerStr:IsA("StringValue") and ownerStr.Value == player.Name then
        return true
    end
    return false
end

local function CollectNewStumps(treeClass)
    local results   = {}
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then return results end
    for _, model in ipairs(logModels:GetChildren()) do
        if preChopLogModels[model] then continue end
        if model:IsA("Model") then
            local tc = model:FindFirstChild("TreeClass")
            if tc and tc.Value == treeClass then
                local iw = model:FindFirstChild("InnerWood")
                if iw and iw:IsA("BasePart") then
                    table.insert(results, iw)
                end
            end
        end
    end
    if #results == 0 then
        warn("[TreeModule] No InnerWood found after chop for TreeClass:", treeClass)
    end
    return results
end

local function CollectAllOwnedStumps()
    local results   = {}
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then return results end
    for _, model in ipairs(logModels:GetChildren()) do
        if not model:IsA("Model") then continue end
        if not IsOwnedByLocalPlayer(model) then continue end
        local iw = model:FindFirstChild("InnerWood")
        if iw and iw:IsA("BasePart") then
            table.insert(results, iw)
        end
    end
    if #results == 0 then
        warn("[TreeModule] No owned InnerWood found.")
    end
    return results
end

local function CleanupState()
    isChopping = false
    SetGroundVisible(true)

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")

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

local function WaitForLogsToSettle(treeClass)
    local VELOCITY_THRESHOLD = 0.5
    local STABLE_DURATION    = 0.3
    local TIMEOUT            = 10
    local POLL_RATE          = 0.05

    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then task.wait(1.5) return end

    local innerWoods = {}
    for _, model in ipairs(logModels:GetChildren()) do
        if preChopLogModels[model] then continue end
        if model:IsA("Model") then
            local tc = model:FindFirstChild("TreeClass")
            if tc and tc.Value == treeClass then
                local iw = model:FindFirstChild("InnerWood")
                if iw and iw:IsA("BasePart") then
                    table.insert(innerWoods, iw)
                end
            end
        end
    end

    if #innerWoods == 0 then task.wait(1.5) return end

    local deadline   = tick() + TIMEOUT
    local stableFrom = nil

    while tick() < deadline do
        local allStill = true
        for _, iw in ipairs(innerWoods) do
            if not iw or not iw.Parent then continue end
            if iw.AssemblyLinearVelocity.Magnitude > VELOCITY_THRESHOLD then
                allStill = false
                break
            end
        end
        if allStill then
            if not stableFrom then stableFrom = tick()
            elseif tick() - stableFrom >= STABLE_DURATION then return end
        else
            stableFrom = nil
        end
        task.wait(POLL_RATE)
    end
    warn("[TreeModule] WaitForLogsToSettle timed out — proceeding anyway.")
end

-- ==========================================
--   LOT BATCH HELPER
-- ==========================================
local function RunLOTBatch(LOT, stumps, goalCFBuilder, onComplete)
    if not LOT then if onComplete then onComplete() end return end
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
            local goalCF      = goalCFBuilder(i, stump)
            local originalSize = stump.Size
            stump.Size        = Settings.ResizeTarget
            LOT.TeleportObjectTo(stump, goalCF)
            task.spawn(function()
                repeat task.wait(0.1) until not LOT.IsBusy()
                if stump and stump.Parent then stump.Size = originalSize end
            end)
        end
        if onComplete then onComplete() end
    end)
end

-- ==========================================
--   PLANK SELLING
-- ==========================================
local PLANK_SELL_CF  = CFrame.new(315.5, 0, 83)
local _sellPlanksOn  = false
local _hoverOutline  = nil
local _hoverPlank    = nil
local _plankConn     = nil
local _clickConn     = nil

local function IsOwnedPlank(part)
    if not part then return false end
    if part.Name ~= "Plank" then return false end
    local playerModels = Workspace:FindFirstChild("PlayerModels")
    if not playerModels or part.Parent ~= playerModels then return false end
    local owner = part:FindFirstChild("Owner")
    if not owner then return false end
    local ownerStr = owner:FindFirstChild("OwnerString")
    if not ownerStr or not ownerStr:IsA("StringValue") then return false end
    return ownerStr.Value == player.Name
end

local function ClearHoverOutline()
    if _hoverOutline then
        _hoverOutline:Destroy()
        _hoverOutline = nil
    end
    _hoverPlank = nil
end

local function ApplyHoverOutline(part)
    if _hoverPlank == part then return end
    ClearHoverOutline()
    _hoverPlank   = part
    _hoverOutline = Instance.new("SelectionBox")
    _hoverOutline.Adornee        = part
    _hoverOutline.Color3         = Color3.fromRGB(74, 120, 255)   -- THEME.Accent
    _hoverOutline.LineThickness  = 0.06
    _hoverOutline.SurfaceColor3  = Color3.fromRGB(74, 120, 255)
    _hoverOutline.SurfaceTransparency = 0.6
    _hoverOutline.Parent         = Workspace
end

local function StopSellPlanks()
    _sellPlanksOn = false
    ClearHoverOutline()
    if _plankConn  then _plankConn:Disconnect();  _plankConn  = nil end
    if _clickConn  then _clickConn:Disconnect();  _clickConn  = nil end
end

local function StartSellPlanks(LOT)
    if not LOT then
        warn("[TreeModule] LOT not available for Sell Planks.")
        return
    end

    _sellPlanksOn = true

    -- Hover detection via mouse RenderStepped
    _plankConn = RunService.RenderStepped:Connect(function()
        if not _sellPlanksOn then return end

        local mouse     = player:GetMouse()
        local target    = mouse.Target

        if target and IsOwnedPlank(target) then
            ApplyHoverOutline(target)
        else
            ClearHoverOutline()
        end
    end)

    -- Click to sell the hovered plank
    _clickConn = game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
        if processed then return end
        if not _sellPlanksOn then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not _hoverPlank or not _hoverPlank.Parent then return end
        if not IsOwnedPlank(_hoverPlank) then return end

        local plank = _hoverPlank
        ClearHoverOutline()

        if LOT.IsBusy() then
            repeat task.wait(0.05) until not LOT.IsBusy()
        end

        LOT.TeleportObjectTo(plank, PLANK_SELL_CF)
    end)
end

-- ==========================================
--   REMOTE CUT
-- ==========================================
local RemoteProxy = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")

-- FIX 1: Height is now near the BOTTOM of the section (10% up from base)
--         instead of the center. This makes the cut register lower on the log.
-- FIX 2: Small FireDelay between individual fires so the server can process
--         each cut before the next one arrives (prevents silent drops).
local function FireCutSection(section, tool, axeName, treeClass)
    if not section or not section.Parent then return end

    local idObj = section:FindFirstChild("ID")
    if not idObj then return end

    local damage = GetDamage(axeName, treeClass)

    -- Cut near the bottom of the section instead of the center.
    -- section.Size.Y * 0.1 = 10% up from the base of the log.
    local height = section.Size.Y * 0.1

    local args = {
        sectionId    = idObj.Value,
        faceVector   = Vector3.new(0, 0, -1),
        height       = height,
        hitPoints    = damage,
        cooldown     = 0,
        cuttingClass = "Axe",
        tool         = tool,
    }

    for _ = 1, Settings.FiresPerSection do
        if not section.Parent then break end  -- section was cut, stop early
        RemoteProxy:FireServer(section.Parent.CutEvent, args)
        task.wait(Settings.FireDelay)         -- let the server register each fire
    end
end

-- ==========================================
--   FALL DETECTION
--   In LT2, WoodSections are NOT removed when the tree falls —
--   they just drop with it. The real signal is new LogModels
--   appearing in Workspace.LogModels for our treeClass.
-- ==========================================
local function TreeHasFallen(treeClass)
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then return false end
    for _, model in ipairs(logModels:GetChildren()) do
        if preChopLogModels[model] then continue end   -- existed before chop
        if not model:IsA("Model") then continue end
        local tc = model:FindFirstChild("TreeClass")
        if tc and tc.Value == treeClass then
            return true   -- new log appeared — tree is down
        end
    end
    return false
end

-- ==========================================
--   MAIN CHOP SEQUENCE
-- ==========================================
local function StartChopping(treeClass, LOT, onComplete)
    if isChopping then return end

    -- 1. Snapshot existing logs so we can detect new ones later
    SnapshotLogModels()

    -- 2. Find the best tree
    local treeModel = FindPriorityTree(treeClass)
    if not treeModel then
        warn("[TreeModule] No tree found for class:", treeClass)
        if onComplete then onComplete() end
        return
    end

    -- 3. Find the lowest WoodSection as our stand-near target
    local sections = GetSectionsBottomFirst(treeModel)
    if #sections == 0 then
        warn("[TreeModule] Tree has no WoodSections.")
        if onComplete then onComplete() end
        return
    end

    -- 4. Get equipped axe — player must have one in hand
    local tool, axeName = GetEquippedAxe()
    if not tool then
        warn("[TreeModule] No axe equipped. Please equip an axe before chopping.")
        if onComplete then onComplete() end
        return
    end

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if onComplete then onComplete() end
        return
    end

    -- 5. Save state, TP player next to the lowest section
    preChopCFrame       = hrp.CFrame
    preChopCameraCFrame = camera.CFrame
    isChopping          = true

    SetGroundVisible(false)

    local targetPart = sections[1]
    local aimPoint   = targetPart.Position
    local lookDir    = targetPart.CFrame.LookVector
    local standPos   = aimPoint
                     + (lookDir * Settings.DistanceToTree)
                     + Vector3.new(0, Settings.VerticalOffset, 0)

    local standCF = CFrame.lookAt(standPos, aimPoint)
    hrp.CFrame    = standCF
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    -- Lock player in place while chopping
    lockConn = RunService.RenderStepped:Connect(function()
        if isChopping then
            hrp.CFrame = standCF
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        else
            if lockConn then lockConn:Disconnect() lockConn = nil end
        end
    end)

    task.wait(Settings.SyncDelay)

    -- 6. Keep firing at the BASE section until it's fully gone,
    --    then wait for the whole tree to fall before TPing back.
    task.spawn(function()
        local baseSection = GetSectionsBottomFirst(treeModel)[1]

        if not baseSection then
            warn("[TreeModule] Base section missing before chop started.")
            CleanupState()
            if onComplete then onComplete() end
            return
        end

        -- Keep hammering the base section until new LogModels appear
        -- (meaning the tree has actually fallen) or we hit the timeout.
        -- NOTE: WoodSections are NOT removed when a tree falls in LT2 —
        -- they fall with the tree. We detect the fell by watching LogModels.
        local deadline = tick() + Settings.ChopTimeout

        while not TreeHasFallen(treeClass) and isChopping and tick() < deadline do
            if not baseSection or not baseSection.Parent then
                -- Section ref is gone somehow; re-grab the current lowest one
                local fresh = GetSectionsBottomFirst(treeModel)
                if #fresh == 0 then break end
                baseSection = fresh[1]
            end
            FireCutSection(baseSection, tool, axeName, treeClass)
            task.wait(Settings.SweepDelay)
        end

        if tick() >= deadline then
            warn("[TreeModule] ChopTimeout reached — tree never fell. Aborting.")
        elseif not isChopping then
            -- User cancelled
            CleanupState()
            if onComplete then onComplete() end
            return
        else
            print("[TreeModule] New logs detected — tree is down. Returning player.")
        end

        -- 7. Unequip the axe so LOT can TP logs freely,
        --    then return player, wait for physics to settle, then deliver.
        do
            local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
            if equippedTool then
                equippedTool.Parent = player.Backpack
            end
        end

        CleanupState()
        WaitForLogsToSettle(treeClass)

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
--             DYNXE UI
-- ==========================================
function TreeModule.Init(Tab, LOT)
    Tab:CreateSection("Auto-Tree Configuration")

    local treeTypes    = ScanForTreeTypes()
    local selectedTree = treeTypes[1] or "Error"
    local chopButton

    Tab:CreateDropdown("Target Tree Type", treeTypes, selectedTree, function(sel)
        selectedTree = sel
    end)

    chopButton = Tab:CreateAction("Get Tree", "Start", function()
        if isChopping then
            isChopping = false
            if type(chopButton) == "table" and chopButton.SetText then
                chopButton:SetText("Start")
            end
        else
            if selectedTree == "None Found" then return end
            local _, axeName = GetEquippedAxe()
            if not axeName then
                warn("[TreeModule] Equip an axe before starting.")
                return
            end
            if type(chopButton) == "table" and chopButton.SetText then
                chopButton:SetText("Stop")
            end
            StartChopping(selectedTree, LOT, function()
                if type(chopButton) == "table" and chopButton.SetText then
                    chopButton:SetText("Start")
                end
            end)
        end
    end)

    -- ── LOG MANAGEMENT ────────────────────────────────────────────
    Tab:CreateSection("Log Management")

    local tpAllButton = Tab:CreateAction("Teleport All Logs To Me", "TP", function()
        if not LOT then warn("[TreeModule] LOT not available.") return end
        if LOT.IsBusy() then warn("[TreeModule] LOT busy.") return end

        local stumps     = CollectAllOwnedStumps()
        local currentHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if #stumps == 0 then return end

        if type(tpAllButton) == "table" and tpAllButton.SetText then
            tpAllButton:SetText("Working...")
        end

        RunLOTBatch(LOT, stumps, function(i, _)
            return currentHRP
                and (currentHRP.CFrame * CFrame.new((i - 1) * 5, 0, -Settings.LogDropDistance))
                or CFrame.new(0, 0, 0)
        end, function()
            if type(tpAllButton) == "table" and tpAllButton.SetText then
                tpAllButton:SetText("TP")
            end
        end)
    end)

    local sellButton = Tab:CreateAction("Sell All Logs/Trees", "Sell", function()
        if not LOT then warn("[TreeModule] LOT not available.") return end
        if LOT.IsBusy() then warn("[TreeModule] LOT busy.") return end

        local stumps = CollectAllOwnedStumps()
        if #stumps == 0 then return end

        if type(sellButton) == "table" and sellButton.SetText then
            sellButton:SetText("Selling...")
        end

        local sellPos = Settings.SellPosition
        RunLOTBatch(LOT, stumps, function(i, _)
            return CFrame.new(sellPos.X + ((i - 1) * 5), sellPos.Y, sellPos.Z)
        end, function()
            if type(sellButton) == "table" and sellButton.SetText then
                sellButton:SetText("Sell")
            end
        end)
    end)
    Tab:CreateToggle("Click To Sell (Planks)", false, function(state)
        if state then
            StartSellPlanks(LOT)
        else
            StopSellPlanks()
        end
    end)
end

return TreeModule

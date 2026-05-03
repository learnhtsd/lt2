local TreeModule = {}

-- ==========================================
--             SYSTEM SETTINGS
-- ==========================================
local Settings = {
    SyncDelay       = 0.25,
    ReadyDelay      = 0.1,

    -- [ Cut Settings ]
    FiresPerSection = 50,
    FireDelay       = 0.03,
    SweepDelay      = 0.1,

    -- [ LOT Settings ]
    LogDropDistance = 6,

    -- [ Sell Location ]
    SellPosition    = Vector3.new(315, -1, 95),

    -- [ Auto Recover Settings ]
    RespawnSettleDelay = 2.0,   -- seconds to wait after respawn before acting
    AxePickupDelay     = 0.1,   -- delay between picking up each axe
}

-- ==========================================
--             DAMAGE TABLE
-- ==========================================
local AxeDamage = {
    ["Basic Hatchet"]       = function(_)  return 0.2  end,
    ["Plain Axe"]           = function(_)  return 0.55 end,
    ["Steel Axe"]           = function(_)  return 0.93 end,
    ["Hardened Axe"]        = function(_)  return 1.45 end,
    ["Silver Axe"]          = function(_)  return 1.6  end,
    ["Rukiryaxe"]           = function(_)  return 1.68 end,
    ["Beta Axe of Bosses"]  = function(_)  return 1.45 end,
    ["Alpha Axe of Testing"]= function(_)  return 1.5  end,
    ["Johiro"]              = function(_)  return 1.8  end,
    ["Beesaxe"]             = function(_)  return 1.4  end,
    ["CHICKEN AXE"]         = function(_)  return 0.9  end,
    ["Amber Axe"]           = function(_)  return 3.39 end,
    ["The Many Axe"]        = function(_)  return 10.2 end,
    ["Candy Cane Axe"]      = function(_)  return 0    end,
    ["Fire Axe"]            = function(tc) return tc == "Volcano"      and 6.35 or 0.6   end,
    ["End Times Axe"]       = function(tc) return tc == "LoneCave"     and 1e7  or 1.58  end,
    ["Gingerbread Axe"]     = function(tc)
        if tc == "Walnut" then return 8.5
        elseif tc == "Koa" then return 11
        else return 1.2 end
    end,
    ["Bird Axe"]            = function(tc)
        if tc == "Volcano"       then return 2.5
        elseif tc == "CaveCrawler" then return 3.9
        else return 1.65 end
    end,
}

local function GetDamage(axeName, treeClass)
    local fn = AxeDamage[axeName]
    return fn and fn(treeClass) or 1.0
end

-- ==========================================
--             CORE SERVICES & VARS
-- ==========================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local isChopping          = false
local preChopCFrame       = nil
local preChopCameraCFrame = nil
local preChopLogModels    = {}

-- ==========================================
--             UTILITY
-- ==========================================

local function ReadAxeName(tool)
    if not tool then return nil end
    local tipChild = tool:FindFirstChild("ToolTip")
    return (tipChild and tipChild:IsA("StringValue")) and tipChild.Value or tool.ToolTip
end

local function GetBackpackAxe()
    local char = player.Character
    if char then
        local equipped = char:FindFirstChildOfClass("Tool")
        if equipped then
            return equipped, ReadAxeName(equipped)
        end
    end
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            return tool, ReadAxeName(tool)
        end
    end
    return nil, nil
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
            if not stableFrom then
                stableFrom = tick()
            elseif tick() - stableFrom >= STABLE_DURATION then
                return
            end
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
            local goalCF = goalCFBuilder(i, stump)
            LOT.TeleportObjectTo(stump, goalCF)
            task.spawn(function()
                repeat task.wait(0.1) until not LOT.IsBusy()
            end)
        end
        if onComplete then onComplete() end
    end)
end

-- ==========================================
--   PLANK SELLING
-- ==========================================
local PLANK_SELL_CF = CFrame.new(315.5, -2, 83)
local _sellPlanksOn = false
local _hoverOutline = nil
local _hoverPlank   = nil
local _plankConn    = nil
local _clickConn    = nil
local _isSelling    = false

local function FindOwnedPlank(part)
    if not part then return nil end
    local current = part
    while current and current ~= Workspace do
        if current.Name == "Plank" and current:IsA("Model") then
            local playerModels = Workspace:FindFirstChild("PlayerModels")
            if not playerModels then return nil end
            if current.Parent ~= playerModels then return nil end
            local owner = current:FindFirstChild("Owner")
            if not owner then return nil end
            local ownerStr = owner:FindFirstChild("OwnerString")
            if not ownerStr or not ownerStr:IsA("StringValue") then return nil end
            if ownerStr.Value ~= player.Name then return nil end
            return current
        end
        current = current.Parent
    end
    return nil
end

local function ClearHoverOutline()
    if _hoverOutline then _hoverOutline:Destroy(); _hoverOutline = nil end
    _hoverPlank = nil
end

local function ApplyHoverOutline(model)
    if _hoverPlank == model then return end
    ClearHoverOutline()
    _hoverPlank                       = model
    _hoverOutline                     = Instance.new("SelectionBox")
    _hoverOutline.Adornee             = model
    _hoverOutline.Color3              = Color3.fromRGB(74, 120, 255)
    _hoverOutline.LineThickness       = 0.08
    _hoverOutline.SurfaceColor3       = Color3.fromRGB(74, 120, 255)
    _hoverOutline.SurfaceTransparency = 0.65
    _hoverOutline.Parent              = Workspace
end

local function StopSellPlanks()
    _sellPlanksOn = false
    _isSelling    = false
    ClearHoverOutline()
    if _plankConn then _plankConn:Disconnect(); _plankConn = nil end
    if _clickConn then _clickConn:Disconnect(); _clickConn = nil end
end

local function StartSellPlanks(LOT)
    if not LOT then warn("[TreeModule] LOT not available for Sell Planks.") return end

    _sellPlanksOn = true
    _isSelling    = false
    local mouse   = player:GetMouse()

    _plankConn = RunService.RenderStepped:Connect(function()
        if not _sellPlanksOn then return end
        if _isSelling then ClearHoverOutline() return end
        local plank = FindOwnedPlank(mouse.Target)
        if plank then ApplyHoverOutline(plank) else ClearHoverOutline() end
    end)

    _clickConn = mouse.Button1Down:Connect(function()
        if not _sellPlanksOn or _isSelling then return end
        if not _hoverPlank or not _hoverPlank.Parent then return end

        local plank = _hoverPlank
        ClearHoverOutline()
        _isSelling = true

        task.spawn(function()
            if LOT.IsBusy() then repeat task.wait(0.05) until not LOT.IsBusy() end

            local target = plank.PrimaryPart
            if not target then
                for _, v in ipairs(plank:GetDescendants()) do
                    if v:IsA("BasePart") then target = v; break end
                end
            end

            if not target then
                warn("[TreeModule] Plank has no BasePart to teleport.")
                _isSelling = false
                return
            end

            LOT.TeleportObjectTo(target, PLANK_SELL_CF)
            repeat task.wait(0.05) until not LOT.IsBusy()
            _isSelling = false
        end)
    end)
end

-- ==========================================
--   REMOTE CUT
-- ==========================================
local RemoteProxy       = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("RemoteProxy")
local ClientInteracted  = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientInteracted")

local function CutHeightFrac(sizeY)
    return math.clamp(0.1 + (8 - sizeY) / 60, 0.1, 0.2)
end

local function FireCutSection(section, tool, axeName, treeClass)
    if not section or not section.Parent then return end

    local idObj = section:FindFirstChild("ID")
    if not idObj then return end

    local damage = GetDamage(axeName, treeClass)
    local height = section.Size.Y * CutHeightFrac(section.Size.Y)

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
        if not section.Parent then break end
        RemoteProxy:FireServer(section.Parent.CutEvent, args)
        task.wait(Settings.FireDelay)
    end
end

-- ==========================================
--   FALL DETECTION
-- ==========================================
local function TreeHasFallen(treeClass)
    local logModels = Workspace:FindFirstChild("LogModels")
    if not logModels then return false end
    for _, model in ipairs(logModels:GetChildren()) do
        if preChopLogModels[model] then continue end
        if not model:IsA("Model") then continue end
        local tc = model:FindFirstChild("TreeClass")
        if tc and tc.Value == treeClass then return true end
    end
    return false
end

-- ==========================================
--   AUTO RECOVER AXE
-- ==========================================
local _autoRecoverOn    = false
local _autoRecoverConn  = nil   -- CharacterAdded connection
local _deathPosition    = nil   -- Vector3 recorded the moment the player dies
local _deathHumConn     = nil   -- Humanoid.Died connection for the current character

local AXE_RECOVER_RADIUS = 20   -- studs around death position to search

-- Searches workspace.PlayerModels for dropped axe models that:
--   1. Are owned by the local player (Owner.OwnerString == player.Name)
--   2. Have a Handle within AXE_RECOVER_RADIUS studs of _deathPosition
local function GetOwnedAxesNearDeath()
    local axes         = {}
    local playerModels = Workspace:FindFirstChild("PlayerModels")
    if not playerModels then
        warn("[TreeModule] Auto Recover: PlayerModels not found.")
        return axes
    end

    for _, obj in ipairs(playerModels:GetDescendants()) do
        if not (obj.Name == "Model" and obj:IsA("Model")) then continue end

        -- Ownership check
        local ownerFolder = obj:FindFirstChild("Owner")
        if not ownerFolder then continue end
        local ownerStr = ownerFolder:FindFirstChild("OwnerString")
        if not ownerStr or not ownerStr:IsA("StringValue") then continue end
        if ownerStr.Value ~= player.Name then continue end

        -- Distance check (only when we have a recorded death position)
        if _deathPosition then
            local handle = obj:FindFirstChild("Handle") or obj.PrimaryPart
            if not handle then continue end
            if (handle.Position - _deathPosition).Magnitude > AXE_RECOVER_RADIUS then continue end
        end

        table.insert(axes, obj)
    end
    return axes
end

-- Teleports the player's HumanoidRootPart next to the axe's handle.
local function TeleportToAxe(axe)
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local handle = axe:FindFirstChild("Handle") or axe.PrimaryPart
    if not handle then return end
    -- Stand slightly above and in front of the axe so physics doesn't clip
    hrp.CFrame = CFrame.new(handle.Position + Vector3.new(0, 3, 0))
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    task.wait(0.2)  -- brief settle so the server registers the new position
end

local MAX_AXES_TO_RECOVER = 10
local PICKUP_TIMEOUT      = 3     -- seconds to keep retrying one axe before skipping
local PICKUP_FIRE_RATE    = 0.15  -- seconds between remote fires during retry loop

-- Counts "Tool"-named tools currently held by the player
-- (backpack, equipped on character, and the workspace character model).
local function CountHeldTools()
    local count = 0
    -- Backpack (unequipped)
    for _, v in ipairs(player.Backpack:GetChildren()) do
        if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
    end
    -- Character (equipped slot)
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
        end
    end
    -- workspace.<PlayerName> model (game may place the equipped tool here)
    local wsChar = Workspace:FindFirstChild(player.Name)
    if wsChar then
        for _, v in ipairs(wsChar:GetChildren()) do
            if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
        end
    end
    return count
end

-- Fires the pickup remote repeatedly for up to PICKUP_TIMEOUT seconds.
-- Returns true if a new Tool appeared in the player's possession, false if timed out.
local function PickupAxeWithRetry(axe)
    local handle = axe:FindFirstChild("Handle") or axe.PrimaryPart
    if not handle then
        warn("[TreeModule] Auto Recover: Axe has no Handle, skipping.")
        return false
    end

    local before   = CountHeldTools()
    local deadline = tick() + PICKUP_TIMEOUT

    while tick() < deadline do
        if not axe or not axe.Parent then
            warn("[TreeModule] Auto Recover: Axe disappeared mid-retry, skipping.")
            return false
        end
        ClientInteracted:FireServer(axe, "Pick up tool", handle.CFrame)
        task.wait(PICKUP_FIRE_RATE)
        if CountHeldTools() > before then
            return true
        end
    end

    warn("[TreeModule] Auto Recover: Timed out on axe — skipping.")
    return false
end

-- Called once per respawn when the toggle is active.
local function OnRespawnedRecover(char)
    -- Wait for the character to be fully ready before doing anything.
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hrp or not hum then
        warn("[TreeModule] Auto Recover: Character parts missing after respawn.")
        return
    end

    -- Extra settle time so the server has placed the dropped axes in the world.
    task.wait(Settings.RespawnSettleDelay)

    if not _autoRecoverOn then return end  -- user may have toggled off while waiting

    local axes = GetOwnedAxesNearDeath()
    if #axes == 0 then
        warn("[TreeModule] Auto Recover: No owned axes found near death position after respawn.")
        return
    end

    -- Cap to MAX_AXES_TO_RECOVER so we never loop over dozens of stale models.
    if #axes > MAX_AXES_TO_RECOVER then
        axes = {table.unpack(axes, 1, MAX_AXES_TO_RECOVER)}
    end

    -- TP to the first axe so the server's proximity check passes.
    TeleportToAxe(axes[1])

    local picked = 0
    for i, axe in ipairs(axes) do
        if not axe or not axe.Parent then continue end

        -- TP to each axe before attempting pickup so distance stays valid.
        if i > 1 then TeleportToAxe(axe) end

        if PickupAxeWithRetry(axe) then
            picked += 1
            print(("[TreeModule] Auto Recover: Axe %d/%d picked up."):format(i, #axes))
        else
            print(("[TreeModule] Auto Recover: Axe %d/%d skipped."):format(i, #axes))
        end
    end

    print(("[TreeModule] Auto Recover: Done — %d/%d axe(s) recovered."):format(picked, #axes))
end

-- Hooks Humanoid.Died on the current character to record the death position.
local function HookDeathPosition(char)
    if _deathHumConn then _deathHumConn:Disconnect(); _deathHumConn = nil end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    _deathHumConn = hum.Died:Connect(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        _deathPosition = hrp and hrp.Position or nil
        if _deathPosition then
            print(("[TreeModule] Auto Recover: Death position recorded at %s."):format(tostring(_deathPosition)))
        end
    end)
end

local function StartAutoRecoverAxe()
    if _autoRecoverConn then return end  -- already running
    _autoRecoverOn = true

    -- Hook the current character immediately in case they die without respawning first.
    if player.Character then
        task.spawn(HookDeathPosition, player.Character)
    end

    _autoRecoverConn = player.CharacterAdded:Connect(function(char)
        if not _autoRecoverOn then return end
        -- Always hook the new character so the next death position is captured.
        task.spawn(HookDeathPosition, char)
        task.spawn(OnRespawnedRecover, char)
    end)
    print("[TreeModule] Auto Recover Axe: ON")
end

local function StopAutoRecoverAxe()
    _autoRecoverOn = false
    if _autoRecoverConn then
        _autoRecoverConn:Disconnect()
        _autoRecoverConn = nil
    end
    if _deathHumConn then
        _deathHumConn:Disconnect()
        _deathHumConn = nil
    end
    _deathPosition = nil
    print("[TreeModule] Auto Recover Axe: OFF")
end

-- ==========================================
--   MAIN CHOP SEQUENCE
-- ==========================================
local function StartChopping(treeClass, LOT, onComplete)
    if isChopping then return end

    SnapshotLogModels()

    local treeModel = FindPriorityTree(treeClass)
    if not treeModel then
        warn("[TreeModule] No tree found for class:", treeClass)
        if onComplete then onComplete() end
        return
    end

    local sections = GetSectionsBottomFirst(treeModel)
    if #sections == 0 then
        warn("[TreeModule] Tree has no WoodSections.")
        if onComplete then onComplete() end
        return
    end

    local tool, axeName = GetBackpackAxe()
    if not tool then
        warn("[TreeModule] No tool found in Backpack. Cannot chop.")
        if onComplete then onComplete() end
        return
    end
    print(("[TreeModule] Using '%s' from Backpack for tree class '%s'."):format(axeName, treeClass))

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if onComplete then onComplete() end
        return
    end

    preChopCFrame       = hrp.CFrame
    preChopCameraCFrame = camera.CFrame
    isChopping          = true

    local targetPart = sections[1]
    local standPos   = targetPart.Position + Vector3.new(4, 0, 0)
    hrp.CFrame       = CFrame.lookAt(standPos, targetPart.Position)
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    task.wait(Settings.SyncDelay)

    task.spawn(function()
        local baseSection = GetSectionsBottomFirst(treeModel)[1]

        if not baseSection then
            warn("[TreeModule] Base section missing before chop started.")
            CleanupState()
            if onComplete then onComplete() end
            return
        end

        while not TreeHasFallen(treeClass) and isChopping do
            if not baseSection or not baseSection.Parent then
                local fresh = GetSectionsBottomFirst(treeModel)
                if #fresh == 0 then break end
                baseSection = fresh[1]
            end
            FireCutSection(baseSection, tool, axeName, treeClass)
            task.wait(Settings.SweepDelay)
        end

        if not isChopping then
            CleanupState()
            if onComplete then onComplete() end
            return
        end

        print("[TreeModule] Tree is down. Returning player.")

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
        if state then StartSellPlanks(LOT) else StopSellPlanks() end
    end)

    Tab:CreateSection("Tool Recovery")

    Tab:CreateToggle("Auto Recover Axe", false, function(state)
        if state then StartAutoRecoverAxe() else StopAutoRecoverAxe() end
    end)
end

return TreeModule

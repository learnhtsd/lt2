local AxeRecoverModule = {}

-- ==========================================
--             SETTINGS
-- ==========================================
local Settings = {
    RespawnSettleDelay = 5.0,   -- seconds to wait after respawn before scanning
    PickupTimeout      = 3,     -- seconds to keep retrying one axe before skipping
    PickupFireRate     = 0.15,  -- seconds between remote fires during retry loop
    AxeRecoverRadius   = 20,    -- studs around death position to search
    MaxAxesToRecover   = 10,    -- hard cap on axes processed per respawn
}

-- ==========================================
--             SERVICES & VARS
-- ==========================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player           = Players.LocalPlayer
local ClientInteracted = ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientInteracted")

local _autoRecoverOn   = false
local _autoRecoverConn = nil    -- CharacterAdded connection
local _deathPosition   = nil    -- Vector3 recorded the moment the player dies
local _deathHumConn    = nil    -- Humanoid.Died connection for the current character

-- ==========================================
--             HELPERS
-- ==========================================

-- Searches workspace.PlayerModels for dropped axe models owned by the local
-- player and within AxeRecoverRadius studs of the last recorded death position.
local function GetOwnedAxesNearDeath()
    local axes         = {}
    local playerModels = Workspace:FindFirstChild("PlayerModels")
    if not playerModels then
        warn("[AxeRecoverModule] PlayerModels not found in workspace.")
        return axes
    end

    for _, obj in ipairs(playerModels:GetDescendants()) do
        if not (obj.Name == "Model" and obj:IsA("Model")) then continue end

        -- Ownership check: Owner.OwnerString must match the local player
        local ownerFolder = obj:FindFirstChild("Owner")
        if not ownerFolder then continue end
        local ownerStr = ownerFolder:FindFirstChild("OwnerString")
        if not ownerStr or not ownerStr:IsA("StringValue") then continue end
        if ownerStr.Value ~= player.Name then continue end

        -- Distance check (skipped if no death position has been recorded yet)
        if _deathPosition then
            local handle = obj:FindFirstChild("Handle") or obj.PrimaryPart
            if not handle then continue end
            if (handle.Position - _deathPosition).Magnitude > Settings.AxeRecoverRadius then continue end
        end

        table.insert(axes, obj)
    end
    return axes
end

-- Counts every Tool named "Tool" currently in the player's possession across:
--   • player.Backpack            (unequipped)
--   • player.Character           (equipped slot)
--   • workspace.<PlayerName>     (server-side character model)
local function CountHeldTools()
    local count = 0

    for _, v in ipairs(player.Backpack:GetChildren()) do
        if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
    end

    local char = player.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
        end
    end

    local wsChar = Workspace:FindFirstChild(player.Name)
    if wsChar then
        for _, v in ipairs(wsChar:GetChildren()) do
            if v.Name == "Tool" and v:IsA("Tool") then count += 1 end
        end
    end

    return count
end

-- Teleports the player's HumanoidRootPart to just above the axe's handle
-- so the server-side proximity check passes before the pickup remote fires.
local function TeleportToAxe(axe)
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local handle = axe:FindFirstChild("Handle") or axe.PrimaryPart
    if not handle then return end
    hrp.CFrame = CFrame.new(handle.Position + Vector3.new(0, 3, 0))
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    task.wait(0.2)
end

-- Fires the pickup remote repeatedly for up to PickupTimeout seconds.
-- Returns true if a new Tool appeared in the player's possession, false if timed out.
local function PickupAxeWithRetry(axe)
    local handle = axe:FindFirstChild("Handle") or axe.PrimaryPart
    if not handle then
        warn("[AxeRecoverModule] Axe has no Handle — skipping.")
        return false
    end

    local before   = CountHeldTools()
    local deadline = tick() + Settings.PickupTimeout

    while tick() < deadline do
        if not axe or not axe.Parent then
            warn("[AxeRecoverModule] Axe disappeared mid-retry — skipping.")
            return false
        end
        ClientInteracted:FireServer(axe, "Pick up tool", handle.CFrame)
        task.wait(Settings.PickupFireRate)
        if CountHeldTools() > before then
            return true
        end
    end

    warn("[AxeRecoverModule] Timed out on axe — skipping.")
    return false
end

-- ==========================================
--             CORE LOGIC
-- ==========================================

-- Runs once per respawn while the toggle is active.
local function OnRespawnedRecover(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hrp or not hum then
        warn("[AxeRecoverModule] Character parts missing after respawn.")
        return
    end

    task.wait(Settings.RespawnSettleDelay)

    if not _autoRecoverOn then return end

    local axes = GetOwnedAxesNearDeath()
    if #axes == 0 then
        warn("[AxeRecoverModule] No owned axes found near death position after respawn.")
        return
    end

    if #axes > Settings.MaxAxesToRecover then
        axes = {table.unpack(axes, 1, Settings.MaxAxesToRecover)}
    end

    TeleportToAxe(axes[1])

    local picked = 0
    for i, axe in ipairs(axes) do
        if not axe or not axe.Parent then continue end
        if i > 1 then TeleportToAxe(axe) end

        if PickupAxeWithRetry(axe) then
            picked += 1
            print(("[AxeRecoverModule] Axe %d/%d picked up."):format(i, #axes))
        else
            print(("[AxeRecoverModule] Axe %d/%d skipped."):format(i, #axes))
        end
    end

    print(("[AxeRecoverModule] Done — %d/%d axe(s) recovered."):format(picked, #axes))
end

-- Connects Humanoid.Died on the active character to record the death position.
local function HookDeathPosition(char)
    if _deathHumConn then _deathHumConn:Disconnect(); _deathHumConn = nil end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    _deathHumConn = hum.Died:Connect(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        _deathPosition = hrp and hrp.Position or nil
        if _deathPosition then
            print(("[AxeRecoverModule] Death position recorded at %s."):format(tostring(_deathPosition)))
        end
    end)
end

local function Start()
    if _autoRecoverConn then return end
    _autoRecoverOn = true

    if player.Character then
        task.spawn(HookDeathPosition, player.Character)
    end

    _autoRecoverConn = player.CharacterAdded:Connect(function(char)
        if not _autoRecoverOn then return end
        task.spawn(HookDeathPosition, char)
        task.spawn(OnRespawnedRecover, char)
    end)

    print("[AxeRecoverModule] Auto Recover Axe: ON")
end

local function Stop()
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
    print("[AxeRecoverModule] Auto Recover Axe: OFF")
end

-- ==========================================
--             UI INIT
-- ==========================================
function AxeRecoverModule.Init(Tab)
    Tab:CreateToggle("Auto Recover Axe", false, function(state)
        if state then Start() else Stop() end
    end)
end

return AxeRecoverModule

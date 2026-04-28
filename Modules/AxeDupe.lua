-- RespawnLoad.lua
-- Reloads the current save slot in the correct LT2 sequence:
--   1. Invoke RequestLoad  → unloads plot, starts preview phase
--   2. Wait for server     → let the preview phase settle
--   3. Kill character      → respawns the player fresh on the new plot

local RespawnLoad = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function RespawnLoad.Init(Tab, Library)
    if not Tab then return warn("[RespawnLoad] Tab was nil!") end

    local LocalPlayer      = Players.LocalPlayer
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")

    local function Notify(title, body, duration)
        if Library and Library.Notify then
            Library:Notify(title, body, duration or 4)
        else
            warn(("[RespawnLoad] %s — %s"):format(title, body))
        end
    end

    -- ================================================================
    --  CORE LOGIC
    -- ================================================================
    local function ReloadCurrentSlot()
        -- 1. Read the active slot FIRST — still valid before anything changes
        local slotObj = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if not slotObj or slotObj.Value == -1 then
            Notify("ERROR", "No save slot is currently loaded.", 5)
            return
        end
        local slot = slotObj.Value

        -- 2. Validate remotes
        if not loadSaveRequests then
            Notify("ERROR", "LoadSaveRequests folder not found.", 5)
            return
        end
        local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")
        if not RequestLoadRemote then
            Notify("ERROR", "RequestLoad remote not found.", 5)
            return
        end

        -- 3. Invoke RequestLoad FIRST
        --    This is what tells the server to unload the current plot
        --    and enter the load-preview / plot-selection phase.
        Notify("LOADING", "Unloading plot and starting reload for slot " .. slot .. "…", 4)

        local ok, err = pcall(function()
            RequestLoadRemote:InvokeServer(slot)
        end)

        if not ok then
            Notify("FAILED", "RequestLoad failed: " .. tostring(err), 6)
            return
        end

        -- 4. Give the server time to fully process the unload/preview phase
        --    before we wipe the character.
        task.wait(2)

        -- 5. NOW kill the character so the player respawns cleanly
        --    onto the freshly loaded plot.
        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")

        if humanoid and humanoid.Health > 0 then
            Notify("RESPAWNING", "Respawning onto loaded plot…", 3)
            humanoid.Health = 0

            -- Wait for the new character to be fully ready
            local newChar = LocalPlayer.CharacterAdded:Wait()
            newChar:WaitForChild("HumanoidRootPart", 10)

            Notify("SUCCESS", "Slot " .. slot .. " reloaded and respawned!", 5)
        else
            -- Character already dead or missing — still counts as success
            -- since RequestLoad already went through
            Notify("SUCCESS", "Slot " .. slot .. " load request sent!", 5)
        end
    end

    -- ================================================================
    --  UI
    -- ================================================================
    Tab:CreateSection("Respawn & Reload")

    Tab:CreateAction("Reload Current Slot", "Reload", function()
        task.spawn(ReloadCurrentSlot)
    end)
end

return RespawnLoad

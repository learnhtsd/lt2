-- RespawnLoad.lua
-- Kills the player then reloads their currently active save slot.

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
    local function KillAndReload()
        -- 1. Grab the current slot BEFORE we die (character may be wiped)
        local slotObj = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if not slotObj or slotObj.Value == -1 then
            Notify("ERROR", "No save slot is currently loaded.", 5)
            return
        end
        local slot = slotObj.Value

        -- 2. Verify the remotes exist
        if not loadSaveRequests then
            Notify("ERROR", "LoadSaveRequests folder not found.", 5)
            return
        end
        local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")
        if not RequestLoadRemote then
            Notify("ERROR", "RequestLoad remote not found.", 5)
            return
        end

        -- 3. Kill the character via Humanoid
        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            Notify("ERROR", "Character not found or already dead.", 5)
            return
        end

        Notify("RESPAWNING", "Killing character to reload slot " .. slot .. "…", 3)
        humanoid.Health = 0

        -- 4. Wait for the NEW character to fully load in
        --    CharacterAdded fires on the new spawn, then we wait for the
        --    HumanoidRootPart so the server has fully initialised the character.
        local newChar = LocalPlayer.CharacterAdded:Wait()
        newChar:WaitForChild("HumanoidRootPart", 10)

        -- Small buffer so the server finishes its own spawn logic
        task.wait(1.5)

        -- 5. Re-invoke the load for the same slot
        Notify("LOADING", "Reloading slot " .. slot .. "…", 3)
        local ok, err = pcall(function()
            RequestLoadRemote:InvokeServer(slot)
        end)

        if ok then
            Notify("SUCCESS", "Slot " .. slot .. " reloaded successfully!", 5)
        else
            Notify("FAILED", "Load invoke failed: " .. tostring(err), 6)
        end
    end

    -- ================================================================
    --  UI
    -- ================================================================
    Tab:CreateSection("Respawn & Reload")

    Tab:CreateAction("Respawn & Reload Slot", "Respawn", function()
        -- Run in a separate thread so the UI button returns immediately
        task.spawn(KillAndReload)
    end)
end

return RespawnLoad

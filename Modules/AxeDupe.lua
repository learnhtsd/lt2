-- RespawnLoad.lua
-- Fires RequestLoad and kills the character in parallel so the respawn
-- lands on the freshly loaded plot without either step racing the other.

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

    -- How long to wait after firing RequestLoad before killing the character.
    -- Increase if the plot hasn't unloaded yet when you respawn.
    -- Decrease if you're spawning before the new plot is ready.
    local KILL_DELAY = 0.2 -- seconds

    local function ReloadCurrentSlot()
        -- 1. Read active slot
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

        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            Notify("ERROR", "Character not found or already dead.", 5)
            return
        end

        Notify("RELOADING", "Reloading slot " .. slot .. "…", 4)

        -- 3. Fire RequestLoad and kill in parallel.
        --    RequestLoad goes first, then KILL_DELAY later the character
        --    dies — giving the server just enough time to start the unload
        --    before the respawn begins.
        task.spawn(function()
            local ok, err = pcall(function()
                RequestLoadRemote:InvokeServer(slot)
            end)
            if not ok then
                Notify("FAILED", "RequestLoad failed: " .. tostring(err), 6)
            end
        end)

        task.delay(KILL_DELAY, function()
            -- Re-fetch in case the reference changed
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                h.Health = 0
            end
        end)

        -- 4. Wait for the fresh character then confirm
        local newChar = LocalPlayer.CharacterAdded:Wait()
        newChar:WaitForChild("HumanoidRootPart", 10)

        Notify("SUCCESS", "Slot " .. slot .. " reloaded!", 5)
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

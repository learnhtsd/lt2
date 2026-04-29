-- RespawnLoad.lua
-- Kills the character first, waits for death, then fires RequestLoad so
-- the respawn always lands on the freshly loaded plot.
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
        local hrp      = char and char:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 then
            Notify("ERROR", "Character not found or already dead.", 5)
            return
        end

        Notify("RELOADING", "Reloading slot " .. slot .. "…", 4)

        -- 3. Fling into the void and wait until the humanoid is dead
        hrp.CFrame = CFrame.new(0, -5000, 0)
        humanoid.Died:Wait()

        -- 4. Now fire RequestLoad — character is confirmed dead
        local ok, err = pcall(function()
            RequestLoadRemote:InvokeServer(slot)
        end)
        if not ok then
            Notify("FAILED", "RequestLoad failed: " .. tostring(err), 6)
            return
        end

        -- 5. Wait for the fresh character then confirm
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

-- SaveGame.lua
local SaveGame = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- This function now accepts the 'Tab' object from your UI Library
function SaveGame.Init(Tab, Library)
    local LocalPlayer = Players.LocalPlayer
    
    Tab:CreateSection("Plot Management")

    Tab:CreateAction("Force Save Game", "Save", function()
        local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
        local currentSlot = LocalPlayer:FindFirstChild("CurrentSaveSlot")

        if loadSaveRequests and currentSlot and currentSlot.Value ~= -1 then
            local RequestSaveRemote = loadSaveRequests:FindFirstChild("RequestSave")
            
            if RequestSaveRemote then
                Library:Notify("SAVING", "Attempting to force save slot " .. tostring(currentSlot.Value), 3)
                
                -- Invoke the server
                local success = RequestSaveRemote:InvokeServer(currentSlot.Value)
                
                if success then
                    Library:Notify("SUCCESS", "Slot " .. tostring(currentSlot.Value) .. " saved!", 5)
                else
                    Library:Notify("FAILED", "Save failed (Check cooldown)", 5)
                end
            else
                Library:Notify("ERROR", "Remote not found", 5)
            end
        else
            Library:Notify("ERROR", "No slot loaded", 5)
        end
    end)
end

return SaveGame

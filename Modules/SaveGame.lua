-- SaveGame.lua
local SaveGame = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

function SaveGame.Init(Tab, Library)
    -- Safety check: ensure the tab exists
    if not Tab then return warn("SaveGame Module: Tab was nil!") end
    
    local LocalPlayer = Players.LocalPlayer
    
    Tab:CreateSection("Plot Management")

    Tab:CreateAction("Save Slot", "Save", function()
        local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
        local currentSlot = LocalPlayer:FindFirstChild("CurrentSaveSlot")

        if loadSaveRequests and currentSlot and currentSlot.Value ~= -1 then
            local RequestSaveRemote = loadSaveRequests:FindFirstChild("RequestSave")
            
            if RequestSaveRemote then
                -- Only use Notify if Library was passed correctly
                if Library and Library.Notify then
                    Library:Notify("SAVING", "Attempting to force save slot " .. tostring(currentSlot.Value), 3)
                end
                
                local success = RequestSaveRemote:InvokeServer(currentSlot.Value)
                
                if success then
                    if Library and Library.Notify then Library:Notify("SUCCESS", "Slot saved!", 5) end
                else
                    if Library and Library.Notify then Library:Notify("FAILED", "Save on cooldown", 5) end
                end
            end
        else
            if Library and Library.Notify then Library:Notify("ERROR", "No slot loaded", 5) end
        end
    end)
end

return SaveGame

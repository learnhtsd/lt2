-- Plot.lua
local Plot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

function Plot.Init(Tab, Library)
    -- Safety check: ensure the tab exists
    if not Tab then return warn("Plot Module: Tab was nil!") end
    
    local LocalPlayer = Players.LocalPlayer
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
    
    Tab:CreateSection("Save Management")

    Tab:CreateAction("Save Slot", "Save", function()
        local currentSlot = LocalPlayer:FindFirstChild("CurrentSaveSlot")

        if loadSaveRequests and currentSlot and currentSlot.Value ~= -1 then
            local RequestSaveRemote = loadSaveRequests:FindFirstChild("RequestSave")
            
            if RequestSaveRemote then
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

    Tab:CreateSection("Load Management")
    
    -- Variable to hold the currently selected slot (1-6)
    local selectedSlotToLoad = 1

    -- NOTE: Depending on your specific UI Library, the method to create a dropdown or slider 
    -- might differ (e.g., CreateDropdown, AddDropdown, CreateSlider). Adjust the name as needed.
    if Tab.CreateDropdown then
        Tab:CreateDropdown("Select Slot to Load", {"1", "2", "3", "4", "5", "6"}, "1", function(value)
            selectedSlotToLoad = tonumber(value)
        end)
    else
        -- If your UI library doesn't support dropdowns easily, you can uncomment this loop 
        -- to just spawn 6 separate buttons instead.
        --[[
        for i = 1, 6 do
            Tab:CreateAction("Set Slot to " .. i, "Select", function() selectedSlotToLoad = i end)
        end
        ]]
    end

    Tab:CreateAction("Load Selected Slot", "Load", function()
        if loadSaveRequests then
            local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")
            local SelectLoadPlotRemote = loadSaveRequests:FindFirstChild("SelectLoadPlot")

            if Library and Library.Notify then
                Library:Notify("LOADING", "Attempting to load slot " .. tostring(selectedSlotToLoad), 3)
            end

            if RequestLoadRemote then
                -- 1. Fire the load request for the specific slot
                RequestLoadRemote:InvokeServer(selectedSlotToLoad)
                
                -- 2. Handle the Plot Selection
                -- In LT2, SelectLoadPlot is typically fired when clicking a physical plot sign.
                -- If you need this script to auto-claim a plot, you will likely need to pass the 
                -- Plot model (from workspace.Properties) as an argument.
                if SelectLoadPlotRemote then
                    -- SelectLoadPlotRemote:InvokeServer(TargetPlotObject) 
                end

                if Library and Library.Notify then 
                    Library:Notify("SUCCESS", "Sent load request for slot " .. tostring(selectedSlotToLoad), 5) 
                end
            else
                if Library and Library.Notify then 
                    Library:Notify("ERROR", "RequestLoad remote not found", 5) 
                end
            end
        else
            if Library and Library.Notify then Library:Notify("ERROR", "LoadSaveRequests folder missing", 5) end
        end
    end)
end

return Plot

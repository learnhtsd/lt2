-- Plot.lua
local Plot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

function Plot.Init(Tab, Library)
    if not Tab then return warn("Plot Module: Tab was nil!") end
    
    local LocalPlayer = Players.LocalPlayer
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
    local propertyPurchasing = ReplicatedStorage:FindFirstChild("PropertyPurchasing")
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    
    -- ==========================================
    -- SAVE & LOAD MANAGEMENT
    -- ==========================================
    Tab:CreateSection("Management")
    local selectedSlotToLoad = 1
    if Tab.CreateDropdown then
        Tab:CreateDropdown("Select Slot to Load", {"1", "2", "3", "4", "5", "6"}, "1", function(value)
            selectedSlotToLoad = tonumber(value)
        end)
    end
    Tab:CreateAction("Load Selected Slot", "Load", function()
        local RequestLoadRemote = loadSaveRequests and loadSaveRequests:FindFirstChild("RequestLoad")
        if RequestLoadRemote then
            RequestLoadRemote:InvokeServer(selectedSlotToLoad)
            if Library and Library.Notify then Library:Notify("SUCCESS", "Loading slot " .. selectedSlotToLoad, 5) end
        end
    end)
    Tab:CreateAction("Save Slot", "Save", function()
        local currentSlot = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if loadSaveRequests and currentSlot and currentSlot.Value ~= -1 then
            local RequestSaveRemote = loadSaveRequests:FindFirstChild("RequestSave")
            if RequestSaveRemote then
                if Library and Library.Notify then Library:Notify("SAVING", "Forcing save...", 3) end
                local success = RequestSaveRemote:InvokeServer(currentSlot.Value)
                if success and Library and Library.Notify then Library:Notify("SUCCESS", "Slot saved!", 5) end
            end
        end
    end)
    Tab:CreateAction("Claim Free Land", "Claim", function()
        local properties = Workspace:FindFirstChild("Properties")
        if not properties or not propertyPurchasing then return end
        local claimRemote = propertyPurchasing:FindFirstChild("ClientPurchasedProperty")
        
        for _, plot in pairs(properties:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            local origin = plot:FindFirstChild("OriginSquare")
            if owner and origin and owner.Value == nil then
                claimRemote:FireServer(plot, origin.OriginCFrame.Value.p + Vector3.new(0, 3, 0))
                if Library and Library.Notify then Library:Notify("PROPERTY", "Claimed!", 3) end
                task.wait(0.5)
                if LocalPlayer.Character then LocalPlayer.Character:MoveTo(origin.Position) end
                break 
            end
        end
    end)
    Tab:CreateAction("Max Land (Full Expand)", "Expand", function()
        local properties = Workspace:FindFirstChild("Properties")
        if not properties or not propertyPurchasing then return end
        local expandRemote = propertyPurchasing:FindFirstChild("ClientExpandedProperty")
        
        local playerPlot = nil
        for _, plot in pairs(properties:GetChildren()) do
            if plot.Owner.Value == LocalPlayer then playerPlot = plot break end
        end

        if playerPlot and playerPlot:FindFirstChild("OriginSquare") then
            local spos = playerPlot.OriginSquare.Position
            local offsets = {
                {0, 40}, {0, -40}, {40, 0}, {-40, 0},
                {40, 40}, {40, -40}, {-40, 40}, {-40, -40},
                {80, 0}, {-80, 0}, {0, 80}, {0, -80},
                {80, 80}, {80, -80}, {-80, 80}, {-80, -80},
                {40, 80}, {-40, 80}, {80, 40}, {80, -40},
                {-80, 40}, {-80, -40}, {40, -80}, {-40, -80}
            }

            for _, offset in ipairs(offsets) do
                expandRemote:FireServer(playerPlot, CFrame.new(spos.X + offset[1], spos.Y, spos.Z + offset[2]))
                task.wait(0.05) 
            end
            if Library and Library.Notify then Library:Notify("SUCCESS", "Plot fully expanded!", 3) end
        end
    end)
    Tab:CreateAction("Clear Entire Base", "Wipe", function()
        local playerModels = Workspace:FindFirstChild("PlayerModels")
        local destroyRemote = interaction and interaction:FindFirstChild("DestroyStructure")

        if not playerModels or not destroyRemote then
            if Library and Library.Notify then Library:Notify("ERROR", "Wipe system unavailable", 3) end
            return
        end

        if Library and Library.Notify then 
            Library:Notify("WIPE", "Clearing your base... this may take a moment.", 4) 
        end

        local count = 0
        for _, model in pairs(playerModels:GetChildren()) do
            local owner = model:FindFirstChild("Owner")
            -- Verify you are the owner before firing
            if owner and owner.Value == LocalPlayer then
                destroyRemote:FireServer(model)
                count = count + 1
                -- Wait every 20 items to prevent the server from lagging out
                if count % 20 == 0 then task.wait(0.1) end
            end
        end

        if Library and Library.Notify then 
            Library:Notify("SUCCESS", "Base wipe complete!", 3) 
        end
    end)
end

return Plot

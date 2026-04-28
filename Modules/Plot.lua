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
    
    -- ==========================================
    -- SAVE & LOAD MANAGEMENT
    -- ==========================================
    Tab:CreateSection("Save Management")

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

    Tab:CreateSection("Load Management")
    
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

    -- ==========================================
    -- PROPERTY ACTIONS
    -- ==========================================
    Tab:CreateSection("Property Actions")

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
            
            -- This table contains all the offsets from your screenshots
            local offsets = {
                -- Sides
                {0, 40}, {0, -40}, {40, 0}, {-40, 0},
                -- Inner Corners
                {40, 40}, {40, -40}, {-40, 40}, {-40, -40},
                -- Outer Extensions
                {80, 0}, {-80, 0}, {0, 80}, {0, -80},
                -- Outer Corners
                {80, 80}, {80, -80}, {-80, 80}, {-80, -80},
                -- Remaining Grid Gaps
                {40, 80}, {-40, 80}, {80, 40}, {80, -40},
                {-80, 40}, {-80, -40}, {40, -80}, {-40, -80}
            }

            if Library and Library.Notify then Library:Notify("EXPANDING", "Purchasing all plots...", 4) end

            for _, offset in ipairs(offsets) do
                expandRemote:FireServer(playerPlot, CFrame.new(spos.X + offset[1], spos.Y, spos.Z + offset[2]))
                task.wait(0.05) -- Small delay to prevent server lag/kicks
            end

            if Library and Library.Notify then Library:Notify("SUCCESS", "Plot fully expanded!", 3) end
        else
            if Library and Library.Notify then Library:Notify("ERROR", "Claim a plot first!", 3) end
        end
    end)
end

return Plot

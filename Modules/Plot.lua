-- Plot.lua
local Plot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

function Plot.Init(Tab, Library)
    -- Safety check: ensure the tab exists
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
    
    local selectedSlotToLoad = 1

    if Tab.CreateDropdown then
        Tab:CreateDropdown("Select Slot to Load", {"1", "2", "3", "4", "5", "6"}, "1", function(value)
            selectedSlotToLoad = tonumber(value)
        end)
    end

    Tab:CreateAction("Load Selected Slot", "Load", function()
        if loadSaveRequests then
            local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")

            if Library and Library.Notify then
                Library:Notify("LOADING", "Attempting to load slot " .. tostring(selectedSlotToLoad), 3)
            end

            if RequestLoadRemote then
                RequestLoadRemote:InvokeServer(selectedSlotToLoad)
                if Library and Library.Notify then 
                    Library:Notify("SUCCESS", "Sent load request for slot " .. tostring(selectedSlotToLoad), 5) 
                end
            else
                if Library and Library.Notify then 
                    Library:Notify("ERROR", "RequestLoad remote not found", 5) 
                end
            end
        end
    end)

    -- ==========================================
    -- NEW PROPERTY ACTIONS (From Screenshots)
    -- ==========================================
    Tab:CreateSection("Property Actions")

    -- Logic for "Free Land" screenshot
    Tab:CreateAction("Claim Free Land", "Claim", function()
        local properties = Workspace:FindFirstChild("Properties")
        if not properties or not propertyPurchasing then return end

        local claimRemote = propertyPurchasing:FindFirstChild("ClientPurchasedProperty")
        
        for _, plot in pairs(properties:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            local origin = plot:FindFirstChild("OriginSquare")
            
            -- Find a plot with no owner
            if owner and origin and owner.Value == nil then
                local pos = origin.OriginCFrame.Value.p + Vector3.new(0, 3, 0)
                
                claimRemote:FireServer(plot, pos)
                
                if Library and Library.Notify then
                    Library:Notify("PROPERTY", "Claimed an available plot!", 3)
                end
                
                -- Teleport to the new plot after a short delay
                task.wait(0.5)
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = origin.CFrame + Vector3.new(0, 10, 0)
                end
                break -- Only claim one
            end
        end
    end)

    -- Logic for "Max Land" screenshot
    Tab:CreateAction("Max Land (Expand)", "Expand", function()
        local properties = Workspace:FindFirstChild("Properties")
        if not properties or not propertyPurchasing then return end

        local expandRemote = propertyPurchasing:FindFirstChild("ClientExpandedProperty")
        local playerPlot = nil

        -- Find the plot the player actually owns
        for _, plot in pairs(properties:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            if owner and owner.Value == LocalPlayer then
                playerPlot = plot
                break
            end
        end

        if playerPlot and playerPlot:FindFirstChild("OriginSquare") then
            local originPos = playerPlot.OriginSquare.Position
            
            -- Fire the expansion remotes (+40 and -40 as seen in your screenshot)
            expandRemote:FireServer(playerPlot, CFrame.new(originPos.X + 40, originPos.Y, originPos.Z))
            expandRemote:FireServer(playerPlot, CFrame.new(originPos.X - 40, originPos.Y, originPos.Z))
            
            if Library and Library.Notify then
                Library:Notify("PROPERTY", "Expansion requests sent!", 3)
            end
        else
            if Library and Library.Notify then
                Library:Notify("ERROR", "You need to own a plot first!", 3)
            end
        end
    end)
end

return Plot

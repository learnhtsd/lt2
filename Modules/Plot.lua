-- Plot.lua
local Plot = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

function Plot.Init(Tab, Library)
    if not Tab then return warn("Plot Module: Tab was nil!") end
    
    local LocalPlayer = Players.LocalPlayer
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")
    local propertyPurchasing = ReplicatedStorage:FindFirstChild("PropertyPurchasing")
    
    ---------------------------------------------------------------------------
    -- SAVE / LOAD SECTION
    ---------------------------------------------------------------------------
    Tab:CreateSection("Save & Load")

    Tab:CreateAction("Force Save Current Slot", "Save", function()
        local currentSlot = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if loadSaveRequests and currentSlot and currentSlot.Value ~= -1 then
            local RequestSave = loadSaveRequests:FindFirstChild("RequestSave")
            if RequestSave then
                Library:Notify("SAVING", "Forcing save on slot " .. tostring(currentSlot.Value), 3)
                RequestSave:InvokeServer(currentSlot.Value)
            end
        else
            Library:Notify("ERROR", "No slot currently loaded", 5)
        end
    end)

    local selectedSlot = 1
    Tab:CreateDropdown("Select Slot", {"1", "2", "3", "4", "5", "6"}, "1", function(v)
        selectedSlot = tonumber(v)
    end)

    Tab:CreateAction("Load Selected Slot", "Load", function()
        if loadSaveRequests and loadSaveRequests:FindFirstChild("RequestLoad") then
            Library:Notify("LOADING", "Loading slot " .. selectedSlot, 3)
            loadSaveRequests.RequestLoad:InvokeServer(selectedSlot)
        end
    end)

    ---------------------------------------------------------------------------
    -- PROPERTY EXPLOITS
    ---------------------------------------------------------------------------
    Tab:CreateSection("Property Management")

    Tab:CreateAction("Set Price to 0", "Execute", function()
        if propertyPurchasing and propertyPurchasing:FindFirstChild("SetPropertyPurchasingValue") then
            -- This attempts to tell the server the property price is 0
            propertyPurchasing.SetPropertyPurchasingValue:FireServer(0)
            Library:Notify("EXPLOIT", "Attempted to set land price to 0", 5)
        else
            Library:Notify("ERROR", "Remote not found", 5)
        end
    end)

    Tab:CreateAction("Purchase Property", "Claim", function()
        -- In LT2, you usually need to be near the plot or have a plot selected.
        -- This fires the remote found in your scanner.
        if propertyPurchasing and propertyPurchasing:FindFirstChild("ClientPurchasedProperty") then
            propertyPurchasing.ClientPurchasedProperty:FireServer(LocalPlayer)
            Library:Notify("PROPERTY", "Sent purchase request", 5)
        end
    end)

    Tab:CreateAction("Max Land Expansion", "Expand", function()
        -- This usually requires looping the purchase remote or 
        -- firing the ClientPurchasedProperty multiple times.
        if propertyPurchasing and propertyPurchasing:FindFirstChild("ClientPurchasedProperty") then
            Library:Notify("EXPANDING", "Attempting to max out land...", 3)
            for i = 1, 15 do -- Typical max expansions
                propertyPurchasing.ClientPurchasedProperty:FireServer(LocalPlayer)
                task.wait(0.1)
            end
        end
    end)
    
    Tab:CreateSection("Misc Utilities")
    
    Tab:CreateToggle("Auto-Enter Purchase Mode", false, function(state)
        _G.AutoPurchaseMode = state
        task.spawn(function()
            while _G.AutoPurchaseMode do
                if propertyPurchasing and propertyPurchasing:FindFirstChild("ClientEnterPropertyPurchaseMode") then
                    propertyPurchasing.ClientEnterPropertyPurchaseMode:FireServer(LocalPlayer)
                end
                task.wait(2)
            end
        end)
    end)
end

return Plot

local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    -- Variables
    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local queuedObjects = {}
    local connections = {}

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        DragStrength = 1e8,
        Snappiness = 150,
        HoldDistance = 7
    }

    -- Physics logic
    local function applyPhysics(obj)
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local folder = Instance.new("Folder", obj)
        folder.Name = "TempFetchPhysics"
        
        local att = Instance.new("Attachment", obj)
        local alignPos = Instance.new("AlignPosition", folder)
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0 = att
        alignPos.MaxForce = Config.DragStrength
        alignPos.Responsiveness = Config.Snappiness
        
        local alignOri = Instance.new("AlignOrientation", folder)
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        
        local loop = RunService.Heartbeat:Connect(function()
            if not folder or not folder.Parent then return end
            local targetCF = root.CFrame * CFrame.new(0, 0, -Config.HoldDistance)
            alignPos.Position = targetCF.Position
            alignOri.CFrame = targetCF
        end)
        
        return folder, loop
    end

    -- UI INTEGRATION
    Tab:CreateSection("Loose Object Teleporter")

    Tab:CreateToggle("Selection Mode", false, function(state)
        Config.SelectionEnabled = state
        Library:Notify("Selection", state and "Click objects to queue" or "Selection disabled", 2)
    end)

    Tab:CreateAction("Clear List", "Deselect All", function()
        local count = #queuedObjects
        for _, obj in ipairs(queuedObjects) do
            if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
        end
        queuedObjects = {}
        Library:Notify("Queue Cleared", "Removed " .. count .. " items from list.", 2)
    end)

    Tab:CreateAction("Execute", "Start Fetching", function()
        if #queuedObjects == 0 then 
            Library:Notify("Error", "No objects selected!", 3)
            return 
        end
        
        Library:Notify("Teleport", "Fetching " .. #queuedObjects .. " items...", 3)
        
        -- Process queue in reverse to safely remove items
        for i = #queuedObjects, 1, -1 do
            local obj = queuedObjects[i]
            if obj and obj.Parent then
                local physicsFolder, loop = applyPhysics(obj)
                
                -- Briefly wait for the object to travel to the player
                task.wait(0.4) 
                
                -- Cleanup
                if loop then loop:Disconnect() end
                if physicsFolder then physicsFolder:Destroy() end
                if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
            end
            table.remove(queuedObjects, i)
        end
        
        Library:Notify("Complete", "All objects fetched successfully.", 3)
    end)

    -- SELECTION LISTENER
    connections.Input = UIS.InputBegan:Connect(function(input, processed)
        if processed or not Config.SelectionEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            -- Validate: Must be a part and not anchored
            if target and target:IsA("BasePart") and not target.Anchored then
                local index = table.find(queuedObjects, target)
                
                if index then
                    -- Remove from queue
                    table.remove(queuedObjects, index)
                    if target:FindFirstChild("TP_Highlight") then target.TP_Highlight:Destroy() end
                    Library:Notify("Queue Update", "Object removed. Total: " .. #queuedObjects, 1)
                else
                    -- Add to queue
                    table.insert(queuedObjects, target)
                    local h = Instance.new("SelectionBox")
                    h.Name = "TP_Highlight"
                    h.Color3 = Color3.fromRGB(74, 120, 255)
                    h.Adornee = target
                    h.Parent = target
                    Library:Notify("Queue Update", "Object added. Total: " .. #queuedObjects, 1)
                end
            end
        end
    end)
end

return LooseObjectTeleport

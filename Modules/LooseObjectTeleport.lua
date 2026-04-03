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
        DragStrength = 1e12, -- High strength to override game dragger
        Snappiness = 200,    -- Instant snap
        HoldDistance = 7     -- Studs in front of player
    }

    -- Physics logic for "Hard Dragging"
    local function applyPhysics(obj)
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        -- Container for cleanup
        local folder = Instance.new("Folder")
        folder.Name = "HardDragForce"
        folder.Parent = obj
        
        -- Attachment on the object itself
        local att0 = Instance.new("Attachment")
        att0.WorldPosition = obj.Position
        att0.Parent = obj
        
        -- Position Mover
        local alignPos = Instance.new("AlignPosition")
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0 = att0
        alignPos.MaxForce = Config.DragStrength
        alignPos.Responsiveness = Config.Snappiness
        alignPos.Parent = folder
        
        -- Orientation Stabilizer
        local alignOri = Instance.new("AlignOrientation")
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att0
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        alignOri.Parent = folder
        
        local loop = RunService.Heartbeat:Connect(function()
            if not folder or not folder.Parent or not root then return end
            -- Calculate target position 7 studs in front of the character
            local targetCF = root.CFrame * CFrame.new(0, 0, -Config.HoldDistance)
            alignPos.Position = targetCF.Position
            alignOri.CFrame = targetCF
        end)
        
        return folder, loop, att0
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
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if not root then 
            return Library:Notify("Error", "Character not found!", 3) 
        end
        
        if #queuedObjects == 0 then 
            return Library:Notify("Error", "No objects selected!", 3) 
        end
        
        Library:Notify("Teleport", "Fetching " .. #queuedObjects .. " items...", 3)
        
        -- Process in a separate thread so the UI stays responsive
        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                
                if obj and obj.Parent and obj:IsA("BasePart") then
                    -- Apply high-strength physics to win the tug-of-war
                    local folder, loop, att = applyPhysics(obj)
                    
                    -- Brief wait for the object to "snap" to the player
                    task.wait(0.5) 
                    
                    -- Cleanup constraints
                    if loop then loop:Disconnect() end
                    if folder then folder:Destroy() end
                    if att then att:Destroy() end
                    if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
                end
                
                -- Clear from list as we go
                table.remove(queuedObjects, i)
            end
            Library:Notify("Complete", "Sequence finished.", 3)
        end)
    end)

    -- SELECTION LISTENER
    connections.Input = UIS.InputBegan:Connect(function(input, processed)
        if processed or not Config.SelectionEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            -- Basic validation: Part must be unanchored
            if target and target:IsA("BasePart") and not target.Anchored then
                local index = table.find(queuedObjects, target)
                
                if index then
                    table.remove(queuedObjects, index)
                    if target:FindFirstChild("TP_Highlight") then target.TP_Highlight:Destroy() end
                    Library:Notify("Queue", "Removed. Total: " .. #queuedObjects, 1)
                else
                    table.insert(queuedObjects, target)
                    local h = Instance.new("SelectionBox")
                    h.Name = "TP_Highlight"
                    h.Color3 = Color3.fromRGB(74, 120, 255)
                    h.Adornee = target
                    h.Parent = target
                    Library:Notify("Queue", "Added. Total: " .. #queuedObjects, 1)
                end
            end
        end
    end)
end

return LooseObjectTeleport

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
    local activeLoops = {} -- Track running drag loops

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        DragStrength = 1e12,
        Snappiness = 200,
        HoldDistance = 7,
        DragDuration = 1.5 -- How long to drag each object
    }

    -- Physics logic for "Hard Dragging"
    local function applyPhysics(obj)
        if not obj or not obj.Parent or not obj:IsA("BasePart") then return end
        
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        -- Create folder for cleanup
        local folder = Instance.new("Folder")
        folder.Name = "HardDragForce"
        folder.Parent = obj
        
        -- Attachment on the object
        local att0 = Instance.new("Attachment")
        att0.Parent = obj
        
        -- Position constraint
        local alignPos = Instance.new("AlignPosition")
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0 = att0
        alignPos.MaxForce = Config.DragStrength
        alignPos.Responsiveness = Config.Snappiness
        alignPos.Parent = folder
        
        -- Rotation constraint
        local alignOri = Instance.new("AlignOrientation")
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att0
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        alignOri.Parent = folder
        
        local startTime = tick()
        local dragLoop
        dragLoop = RunService.Heartbeat:Connect(function()
            if not folder or not folder.Parent or not root or not root.Parent then 
                dragLoop:Disconnect()
                return 
            end
            
            -- Calculate target position 7 studs in front of the character
            local targetCF = root.CFrame * CFrame.new(0, 0, -Config.HoldDistance)
            alignPos.Position = targetCF.Position
            alignOri.CFrame = targetCF
            
            -- Stop dragging after duration expires
            if tick() - startTime > Config.DragDuration then
                dragLoop:Disconnect()
            end
        end)
        
        -- Return cleanup function
        return function()
            if dragLoop then dragLoop:Disconnect() end
            if folder then folder:Destroy() end
            if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
        end
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
            if obj and obj:FindFirstChild("TP_Highlight") then 
                obj.TP_Highlight:Destroy() 
            end
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
        
        -- Process in a separate thread
        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                
                if obj and obj.Parent and obj:IsA("BasePart") then
                    local cleanup = applyPhysics(obj)
                    
                    if cleanup then
                        -- Wait for drag to complete
                        task.wait(Config.DragDuration)
                        -- Run cleanup
                        cleanup()
                    end
                end
                
                -- Remove from queue as we process
                table.remove(queuedObjects, i)
                task.wait(0.1) -- Small delay between objects
            end
            Library:Notify("Complete", "Sequence finished.", 3)
        end)
    end)

    -- SELECTION LISTENER
    connections.Input = UIS.InputBegan:Connect(function(input, processed)
        if processed or not Config.SelectionEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            -- Validate: Part must exist, be a BasePart, and be unanchored
            if target and target:IsA("BasePart") and not target.Anchored then
                local index = table.find(queuedObjects, target)
                
                if index then
                    -- Remove from queue
                    table.remove(queuedObjects, index)
                    if target:FindFirstChild("TP_Highlight") then 
                        target.TP_Highlight:Destroy() 
                    end
                    Library:Notify("Queue", "Removed. Total: " .. #queuedObjects, 1)
                else
                    -- Add to queue
                    table.insert(queuedObjects, target)
                    local h = Instance.new("SelectionBox")
                    h.Name = "TP_Highlight"
                    h.Color3 = Color3.fromRGB(74, 120, 255)
                    h.Adornee = target
                    h.Parent = target
                    Library:Notify("Queue", "Added. Total: " .. #queuedObjects, 1)
                end
            else
                if not target then
                    Library:Notify("Error", "Click on a part!", 2)
                elseif target.Anchored then
                    Library:Notify("Error", "Part is anchored!", 2)
                end
            end
        end
    end)
    
    -- Cleanup on disable
    Tab:CreateAction("Cleanup", "Stop All Active Drags", function()
        for _, cleanup in ipairs(activeLoops) do
            pcall(cleanup)
        end
        activeLoops = {}
        Library:Notify("Cleanup", "Stopped all active drags", 2)
    end)
end

return LooseObjectTeleport

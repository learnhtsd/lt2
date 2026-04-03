local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")

    -- Variables
    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local queuedObjects = {}
    local connections = {}

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        Speed = 100, -- Studs per second
        HoldDistance = 7, -- Studs in front of player
        UseTeleport = false -- If true, instantly teleports instead of dragging
    }

    -- Direct movement method
    local function moveObjectToPlayer(obj)
        if not obj or not obj.Parent or not obj:IsA("BasePart") then return end
        
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local startTime = tick()
        local maxDuration = 5 -- Max 5 seconds to reach player
        
        local moveLoop
        moveLoop = RunService.Heartbeat:Connect(function()
            if not obj or not obj.Parent or not root or not root.Parent then
                moveLoop:Disconnect()
                return
            end
            
            -- Target position: in front of player
            local targetCF = root.CFrame * CFrame.new(0, 0, -Config.HoldDistance)
            local currentPos = obj.Position
            local distance = (targetCF.Position - currentPos).Magnitude
            
            -- Timeout safety
            if tick() - startTime > maxDuration or distance < 1 then
                moveLoop:Disconnect()
                return
            end
            
            if Config.UseTeleport then
                -- Instant teleport
                obj.CFrame = targetCF
                moveLoop:Disconnect()
            else
                -- Smooth movement towards player
                local direction = (targetCF.Position - currentPos).Unit
                local newPos = currentPos + direction * Config.Speed * (1/60)
                obj.CFrame = CFrame.new(newPos) * obj.CFrame.Rotation
            end
        end)
    end

    -- UI INTEGRATION
    Tab:CreateSection("Loose Object Teleporter")

    Tab:CreateToggle("Selection Mode", false, function(state)
        Config.SelectionEnabled = state
        Library:Notify("Selection", state and "Click objects to queue" or "Selection disabled", 2)
    end)

    Tab:CreateToggle("Instant Teleport", false, function(state)
        Config.UseTeleport = state
        Library:Notify("Mode", state and "Instant teleport ON" or "Smooth drag ON", 2)
    end)

    Tab:CreateSlider("Drag Speed", 10, 500, 100, function(value)
        Config.Speed = value
        Library:Notify("Speed", "Set to " .. value .. " studs/sec", 1)
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

    Tab:CreateAction("Execute", "Start Teleporting", function()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if not root then 
            return Library:Notify("Error", "Character not found!", 3) 
        end
        
        if #queuedObjects == 0 then 
            return Library:Notify("Error", "No objects selected!", 3) 
        end

        Library:Notify("Teleport", "Fetching " .. #queuedObjects .. " items...", 3)
        
        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                
                if obj and obj.Parent and obj:IsA("BasePart") then
                    moveObjectToPlayer(obj)
                    
                    -- Wait for object to arrive
                    if Config.UseTeleport then
                        task.wait(0.2)
                    else
                        task.wait(5.5) -- Max movement time + buffer
                    end
                end
                
                -- Remove highlight
                if obj and obj:FindFirstChild("TP_Highlight") then
                    obj.TP_Highlight:Destroy()
                end
                
                table.remove(queuedObjects, i)
            end
            
            Library:Notify("Complete", "All items collected!", 3)
        end)
    end)

    -- SELECTION LISTENER
    connections.Input = UIS.InputBegan:Connect(function(input, processed)
        if processed or not Config.SelectionEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            
            if target and target:IsA("BasePart") and not target.Anchored then
                local index = table.find(queuedObjects, target)
                
                if index then
                    table.remove(queuedObjects, index)
                    if target:FindFirstChild("TP_Highlight") then 
                        target.TP_Highlight:Destroy() 
                    end
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
            else
                if not target then
                    Library:Notify("Error", "Click on a part!", 2)
                elseif target.Anchored then
                    Library:Notify("Error", "Part is anchored!", 2)
                end
            end
        end
    end)
end

return LooseObjectTeleport

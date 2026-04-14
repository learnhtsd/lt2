local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera

    -- Variables
    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local queuedObjects = {}
    local targetCFrame = nil -- For the "Global Destination" logic
    local connections = {}

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        UseGrabLogic = true, -- Uses VirtualInputManager (Script 1 logic)
        GlobalMode = false,  -- If true, TPs to targetCFrame. If false, TPs to Player.
        DragSteps = 12       -- Smoothness of the drag
    }

    ---------------------------------------------------------
    -- HELPER UTILITIES
    ---------------------------------------------------------
    local function stopAllMotion(obj)
        if obj and obj:IsA("BasePart") then
            obj.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            obj.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end

    local function linearDrag(obj, endPos)
        local startCFrame = obj.CFrame
        local finalCFrame = CFrame.new(endPos)
        
        local oldCollide = obj.CanCollide
        obj.CanCollide = false 
        
        for i = 1, Config.DragSteps do
            obj.CFrame = startCFrame:Lerp(finalCFrame, i/Config.DragSteps)
            stopAllMotion(obj)
            task.wait(0.01)
        end
        
        obj.CFrame = finalCFrame
        obj.CanCollide = oldCollide
    end

    ---------------------------------------------------------
    -- UI INTEGRATION
    ---------------------------------------------------------
    Tab:CreateSection("Multi-Object Grabber")

    Tab:CreateToggle("Selection Mode (Click Part)", false, function(state)
        Config.SelectionEnabled = state
        Library:Notify("Selection", state and "Click objects to queue" or "Selection disabled", 2)
    end)

    Tab:CreateToggle("Global Destination Mode", false, function(state)
        Config.GlobalMode = state
        Library:Notify("Mode", state and "Will TP to marked location" or "Will TP to Player", 2)
    end)

    Tab:CreateAction("Set Destination (Mouse)", "Mark Spot", function()
        targetCFrame = Mouse.Hit
        Library:Notify("Success", "Global Destination Set!", 2)
    end)

    Tab:CreateAction("Clear Queue", "Reset List", function()
        for _, obj in ipairs(queuedObjects) do
            if obj and obj:FindFirstChild("TP_Highlight") then 
                obj.TP_Highlight:Destroy() 
            end
        end
        queuedObjects = {}
        Library:Notify("Queue", "Cleared all items.", 2)
    end)

    Tab:CreateAction("Execute TP", "Start Process", function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then return Library:Notify("Error", "No Character!", 3) end
        if #queuedObjects == 0 then return Library:Notify("Error", "Queue is empty!", 3) end
        if Config.GlobalMode and not targetCFrame then return Library:Notify("Error", "Set Destination first!", 3) end

        Library:Notify("Processing", "Moving " .. #queuedObjects .. " items...", 3)
        
        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                if obj and obj.Parent and obj:IsA("BasePart") then
                    
                    -- 1. Determine Destination
                    local destination = Config.GlobalMode and targetCFrame.Position or (hrp.Position + hrp.CFrame.LookVector * 5)

                    -- 2. Teleport Player to item to ensure it's in range/rendered
                    hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 0, -5), obj.Position)
                    task.wait(0.3)

                    -- 3. Virtual Click Grab (Script 1 Logic)
                    local vector, onScreen = Camera:WorldToViewportPoint(obj.Position)
                    if onScreen then
                        VIM:SendMouseMoveEvent(vector.X, vector.Y, game)
                        task.wait(0.05)
                        VIM:SendMouseButtonEvent(vector.X, vector.Y, 0, true, game, 0)
                        task.wait(0.1)
                        
                        -- 4. Move the object
                        linearDrag(obj, destination)
                        
                        -- 5. Release
                        VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
                        stopAllMotion(obj)
                        task.wait(0.1)
                    end
                end

                -- Cleanup highlight and table
                if obj and obj:FindFirstChild("TP_Highlight") then
                    obj.TP_Highlight:Destroy()
                end
                table.remove(queuedObjects, i)
            end
            Library:Notify("Complete", "Queue finished.", 3)
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
                else
                    table.insert(queuedObjects, target)
                    local h = Instance.new("SelectionBox")
                    h.Name = "TP_Highlight"
                    h.Color3 = Color3.fromRGB(150, 255, 150)
                    h.Adornee = target
                    h.Parent = target
                end
            end
        end
    end)
end

return LooseObjectTeleport

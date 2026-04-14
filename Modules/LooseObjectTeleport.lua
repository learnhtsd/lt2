local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local Camera = workspace.CurrentCamera

    -- Variables
    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local queuedObjects = {}
    local connections = {}

    -- Lasso UI Variables
    local dragStart = nil
    local isDragging = false
    
    -- Safely mount UI (CoreGui for exploits, fallback to PlayerGui)
    local guiParent = pcall(function() return CoreGui.Name end) and CoreGui or Player:WaitForChild("PlayerGui")
    
    local selectionGui = Instance.new("ScreenGui")
    selectionGui.Name = "LassoSelectionGui"
    selectionGui.Parent = guiParent

    local selectionBox2D = Instance.new("Frame")
    selectionBox2D.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    selectionBox2D.BackgroundTransparency = 0.5
    selectionBox2D.BorderSizePixel = 1
    selectionBox2D.BorderColor3 = Color3.fromRGB(0, 170, 255)
    selectionBox2D.Visible = false
    selectionBox2D.Parent = selectionGui

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        GroupSelectionEnabled = false,
        LassoEnabled = false,
        UseGrabLogic = true,
        DragSteps = 12
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
            if not obj or not obj.Parent then break end
            obj.CFrame = startCFrame:Lerp(finalCFrame, i/Config.DragSteps)
            stopAllMotion(obj)
            task.wait(0.01)
        end
        
        if obj and obj.Parent then
            obj.CFrame = finalCFrame
            obj.CanCollide = oldCollide
        end
    end

    local function addToQueue(obj)
        if obj and obj:IsA("BasePart") and not obj.Anchored then
            if not table.find(queuedObjects, obj) then
                table.insert(queuedObjects, obj)
                local h = Instance.new("SelectionBox")
                h.Name = "TP_Highlight"
                h.Color3 = Color3.fromRGB(150, 255, 150)
                h.Adornee = obj
                h.Parent = obj
            end
        end
    end

    local function removeFromQueue(obj)
        local index = table.find(queuedObjects, obj)
        if index then
            table.remove(queuedObjects, index)
            if obj:FindFirstChild("TP_Highlight") then 
                obj.TP_Highlight:Destroy() 
            end
        end
    end

    ---------------------------------------------------------
    -- UI INTEGRATION
    ---------------------------------------------------------
    Tab:CreateSection("Multi-Object Grabber")

    Tab:CreateToggle("Selection Mode (Click Part)", false, function(state)
        Config.SelectionEnabled = state
        Library:Notify("Selection", state and "Click objects to queue" or "Click selection disabled", 2)
    end)

    Tab:CreateToggle("Group Selection", false, function(state)
        Config.GroupSelectionEnabled = state
        Library:Notify("Group Selection", state and "Clicking selects entire model" or "Group selection disabled", 2)
    end)

    Tab:CreateToggle("Lasso Tool (Drag Box)", false, function(state)
        Config.LassoEnabled = state
        Library:Notify("Lasso Tool", state and "Click and drag to select objects" or "Lasso disabled", 2)
        if not state and isDragging then
            isDragging = false
            selectionBox2D.Visible = false
        end
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

        Library:Notify("Processing", "Moving " .. #queuedObjects .. " items to your position...", 3)
        
        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                if obj and obj.Parent and obj:IsA("BasePart") then
                    
                    -- 1. Determine Destination (Player's current position)
                    local destination = hrp.Position

                    -- 2. Teleport Player to item to ensure it's in range/rendered
                    local originalPlayerCFrame = hrp.CFrame
                    hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 0, -5), obj.Position)
                    task.wait(0.3)

                    -- 3. Virtual Click Grab (Script 1 Logic)
                    local vector, onScreen = Camera:WorldToViewportPoint(obj.Position)
                    if onScreen then
                        VIM:SendMouseMoveEvent(vector.X, vector.Y, game)
                        task.wait(0.05)
                        VIM:SendMouseButtonEvent(vector.X, vector.Y, 0, true, game, 0)
                        task.wait(0.1)
                        
                        -- 4. Move the object back to the player's destination
                        linearDrag(obj, destination)
                        
                        -- 5. Release
                        VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
                        stopAllMotion(obj)
                        task.wait(0.1)
                    end
                    
                    -- Return player to original spot to grab the next item smoothly
                    hrp.CFrame = originalPlayerCFrame
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

    ---------------------------------------------------------
    -- INPUT LISTENERS
    ---------------------------------------------------------
    connections.InputBegan = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            
            -- Lasso Drag Start
            if Config.LassoEnabled then
                isDragging = true
                dragStart = Vector2.new(Mouse.X, Mouse.Y)
                selectionBox2D.Position = UDim2.new(0, dragStart.X, 0, dragStart.Y)
                selectionBox2D.Size = UDim2.new(0, 0, 0, 0)
                selectionBox2D.Visible = true
                return
            end

            -- Normal / Group Selection
            if Config.SelectionEnabled then
                local target = Mouse.Target
                if target and target:IsA("BasePart") and not target.Anchored then
                    
                    local isCurrentlySelected = table.find(queuedObjects, target) ~= nil

                    if Config.GroupSelectionEnabled then
                        local root = target:FindFirstAncestorWhichIsA("Model") or target.Parent
                        if root and root ~= workspace then
                            for _, child in ipairs(root:GetDescendants()) do
                                if child:IsA("BasePart") and not child.Anchored then
                                    if isCurrentlySelected then
                                        removeFromQueue(child)
                                    else
                                        addToQueue(child)
                                    end
                                end
                            end
                        end
                    else
                        if isCurrentlySelected then
                            removeFromQueue(target)
                        else
                            addToQueue(target)
                        end
                    end
                end
            end
        end
    end)

    connections.InputChanged = UIS.InputChanged:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            local currentPos = Vector2.new(Mouse.X, Mouse.Y)
            local minX = math.min(dragStart.X, currentPos.X)
            local minY = math.min(dragStart.Y, currentPos.Y)
            local maxX = math.max(dragStart.X, currentPos.X)
            local maxY = math.max(dragStart.Y, currentPos.Y)

            selectionBox2D.Position = UDim2.new(0, minX, 0, minY)
            selectionBox2D.Size = UDim2.new(0, maxX - minX, 0, maxY - minY)
        end
    end)

    connections.InputEnded = UIS.InputEnded:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
            isDragging = false
            selectionBox2D.Visible = false

            local endPos = Vector2.new(Mouse.X, Mouse.Y)
            local minX = math.min(dragStart.X, endPos.X)
            local minY = math.min(dragStart.Y, endPos.Y)
            local maxX = math.max(dragStart.X, endPos.X)
            local maxY = math.max(dragStart.Y, endPos.Y)

            -- Find all unanchored parts within the 2D bounding box
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Anchored then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(obj.Position)
                    if onScreen then
                        if screenPos.X >= minX and screenPos.X <= maxX and screenPos.Y >= minY and screenPos.Y <= maxY then
                            addToQueue(obj)
                        end
                    end
                end
            end
        end
    end)
end

return LooseObjectTeleport

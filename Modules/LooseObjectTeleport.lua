local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera
    local CoreGui = game:GetService("CoreGui")

    -- Variables
    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local queuedObjects = {}
    local connections = {}
    
    -- Lasso UI Setup
    local lassoGui = Instance.new("ScreenGui")
    lassoGui.Name = "LassoSelectionGui"
    lassoGui.Parent = CoreGui
    
    local selectionFrame = Instance.new("Frame")
    selectionFrame.Name = "SelectionFrame"
    selectionFrame.Parent = lassoGui
    selectionFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    selectionFrame.BackgroundTransparency = 0.7
    selectionFrame.BorderSizePixel = 1
    selectionFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
    selectionFrame.Visible = false

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        LassoEnabled = false,
        GroupSelectEnabled = false,
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
            obj.CFrame = startCFrame:Lerp(finalCFrame, i/Config.DragSteps)
            stopAllMotion(obj)
            task.wait(0.01)
        end
        
        obj.CFrame = finalCFrame
        obj.CanCollide = oldCollide
    end

    local function addToQueue(part)
        if part and part:IsA("BasePart") and not part.Anchored and not table.find(queuedObjects, part) then
            table.insert(queuedObjects, part)
            local h = Instance.new("SelectionBox")
            h.Name = "TP_Highlight"
            h.Color3 = Color3.fromRGB(0, 255, 0)
            h.LineThickness = 0.05
            h.Adornee = part
            h.Parent = part
        end
    end

    ---------------------------------------------------------
    -- UI INTEGRATION
    ---------------------------------------------------------
    Tab:CreateSection("Selection Tools")

    Tab:CreateToggle("Individual Click Select", false, function(state)
        Config.SelectionEnabled = state
    end)

    Tab:CreateToggle("Lasso Drag Select", false, function(state)
        Config.LassoEnabled = state
        selectionFrame.Visible = false
    end)

    Tab:CreateToggle("Group Selection (Same Name)", false, function(state)
        Config.GroupSelectEnabled = state
    end)

    Tab:CreateSection("Execution")

    Tab:CreateAction("Clear Queue", "Reset Selection", function()
        for _, obj in ipairs(queuedObjects) do
            if obj and obj:FindFirstChild("TP_Highlight") then 
                obj.TP_Highlight:Destroy() 
            end
        end
        queuedObjects = {}
        Library:Notify("Queue", "Cleared all items.", 2)
    end)

    Tab:CreateAction("Execute TP", "Bring to Current Spot", function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then return Library:Notify("Error", "No Character!", 3) end
        if #queuedObjects == 0 then return Library:Notify("Error", "Queue is empty!", 3) end

        -- Capture position at the moment of button press
        local dropOffPoint = hrp.Position + (hrp.CFrame.LookVector * 4)

        Library:Notify("Processing", "Fetching " .. #queuedObjects .. " items...", 3)
        
        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                if obj and obj.Parent and obj:IsA("BasePart") then
                    
                    -- TP Player to item
                    hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 5, 0), obj.Position)
                    task.wait(0.35)

                    -- Virtual Grab
                    local vector, onScreen = Camera:WorldToViewportPoint(obj.Position)
                    if onScreen then
                        VIM:SendMouseMoveEvent(vector.X, vector.Y, game)
                        task.wait(0.05)
                        VIM:SendMouseButtonEvent(vector.X, vector.Y, 0, true, game, 0)
                        task.wait(0.1)
                        
                        linearDrag(obj, dropOffPoint)
                        
                        VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
                        stopAllMotion(obj)
                        task.wait(0.1)
                    end
                end

                if obj and obj:FindFirstChild("TP_Highlight") then
                    obj.TP_Highlight:Destroy()
                end
                table.remove(queuedObjects, i)
            end
            Library:Notify("Complete", "All items delivered.", 3)
        end)
    end)

    ---------------------------------------------------------
    -- INPUT LOGIC
    ---------------------------------------------------------
    local dragging = false
    local startPos = Vector2.new()

    connections.InputBegan = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if Config.LassoEnabled then
                dragging = true
                startPos = UIS:GetMouseLocation()
                selectionFrame.Position = UDim2.fromOffset(startPos.X, startPos.Y)
                selectionFrame.Size = UDim2.fromOffset(0, 0)
                selectionFrame.Visible = true
            elseif Config.SelectionEnabled or Config.GroupSelectEnabled then
                local target = Mouse.Target
                if target and target:IsA("BasePart") then
                    if Config.GroupSelectEnabled then
                        local targetName = target.Name
                        local count = 0
                        for _, v in ipairs(workspace:GetDescendants()) do
                            if v:IsA("BasePart") and v.Name == targetName and not v.Anchored then
                                addToQueue(v)
                                count = count + 1
                            end
                        end
                        Library:Notify("Group Select", "Added " .. count .. " items named: " .. targetName, 2)
                    else
                        addToQueue(target)
                    end
                end
            end
        end
    end)

    connections.InputChanged = UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentPos = UIS:GetMouseLocation()
            local diff = currentPos - startPos
            
            selectionFrame.Size = UDim2.fromOffset(math.abs(diff.X), math.abs(diff.Y))
            selectionFrame.Position = UDim2.fromOffset(
                math.min(startPos.X, currentPos.X),
                math.min(startPos.Y, currentPos.Y)
            )
        end
    end)

    connections.InputEnded = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            selectionFrame.Visible = false
            
            local endPos = UIS:GetMouseLocation()
            local minX, maxX = math.min(startPos.X, endPos.X), math.max(startPos.X, endPos.X)
            local minY, maxY = math.min(startPos.Y, endPos.Y), math.max(startPos.Y, endPos.Y)
            
            local lassoCount = 0
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v.Anchored then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(v.Position)
                    if onScreen then
                        if screenPos.X >= minX and screenPos.X <= maxX and screenPos.Y >= minY and screenPos.Y <= maxY then
                            addToQueue(v)
                            lassoCount = lassoCount + 1
                        end
                    end
                end
            end
            Library:Notify("Lasso", "Added " .. lassoCount .. " items.", 2)
        end
    end)
end

return LooseObjectTeleport

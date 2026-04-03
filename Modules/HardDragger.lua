local HardDragger = {}

function HardDragger.Init(Tab, Library)
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local Camera = workspace.CurrentCamera

    -- Configuration (Controlled by UI)
    local Config = {
        Enabled = false,
        DragStrength = 1e8,
        Snappiness = 150,
        HoldDistance = 8,
        MaxDragRadius = 12,
        MaxThrowSpeed = 300
    }

    -- State
    local isDragging = false
    local currentObject = nil
    local physicsFolder = nil
    local connections = {}

    -- Physics State
    local throwVelocity = Vector3.zero
    local lastPosition = nil
    local initialRotation = nil

    -- Cleanup current physics
    local function stopPhysics()
        if isDragging and currentObject and currentObject.Parent then
            local finalVel = throwVelocity
            if finalVel.Magnitude > Config.MaxThrowSpeed then
                finalVel = finalVel.Unit * Config.MaxThrowSpeed
            end
            currentObject.AssemblyLinearVelocity = finalVel
        end

        isDragging = false
        currentObject = nil
        lastPosition = nil
        initialRotation = nil
        throwVelocity = Vector3.zero
        
        if physicsFolder then
            physicsFolder:Destroy()
            physicsFolder = nil
        end
    end

    local function applyHardPhysics(obj)
        if not obj or obj.Anchored or not Config.Enabled then return end
        
        stopPhysics() 
        isDragging = true
        currentObject = obj
        lastPosition = obj.Position
        
        initialRotation = Camera.CFrame.Rotation:Inverse() * obj.CFrame
        
        physicsFolder = Instance.new("Folder")
        physicsFolder.Name = "HardDrag_Override"
        physicsFolder.Parent = obj

        local att = Instance.new("Attachment", obj)
        obj.AssemblyLinearVelocity = Vector3.zero
        obj.AssemblyAngularVelocity = Vector3.zero

        local alignPos = Instance.new("AlignPosition")
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0 = att
        alignPos.MaxForce = Config.DragStrength
        alignPos.MaxVelocity = math.huge
        alignPos.Responsiveness = Config.Snappiness
        alignPos.Position = obj.Position
        alignPos.Parent = physicsFolder

        local alignOri = Instance.new("AlignOrientation")
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        alignOri.CFrame = obj.CFrame 
        alignOri.Parent = physicsFolder

        if Player.Character then
            for _, part in pairs(Player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    local noCol = Instance.new("NoCollisionConstraint")
                    noCol.Part0 = obj
                    noCol.Part1 = part
                    noCol.Parent = physicsFolder
                end
            end
        end

        local dragLoop
        dragLoop = RunService.Heartbeat:Connect(function(dt)
            local character = Player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")

            -- Safety breaks
            if not isDragging or not currentObject or not currentObject.Parent or not rootPart or not Config.Enabled then
                if dragLoop then dragLoop:Disconnect() end
                if isDragging then stopPhysics() end
                return
            end

            if lastPosition then
                throwVelocity = (currentObject.Position - lastPosition) / dt
            end
            lastPosition = currentObject.Position

            -- 1. Position Calculation
            local zoomDistance = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude
            local targetPos = Camera.CFrame.Position + (Mouse.UnitRay.Direction * (zoomDistance + Config.HoldDistance))

            -- 2. Distance Clamp
            local offsetFromPlayer = targetPos - rootPart.Position
            if offsetFromPlayer.Magnitude > Config.MaxDragRadius then
                targetPos = rootPart.Position + (offsetFromPlayer.Unit * Config.MaxDragRadius)
            end

            -- 3. Raycast
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {character, currentObject, physicsFolder}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local rayHit = workspace:Raycast(Camera.CFrame.Position, targetPos - Camera.CFrame.Position, rayParams)

            if rayHit then
                targetPos = rayHit.Position - ( (targetPos - Camera.CFrame.Position).Unit * 1.5 )
            end

            -- Apply Positions and dynamic responsiveness
            alignPos.Responsiveness = Config.Snappiness
            alignOri.Responsiveness = Config.Snappiness
            alignPos.Position = targetPos
            alignOri.CFrame = Camera.CFrame.Rotation * initialRotation
            
            currentObject.AssemblyLinearVelocity = Vector3.zero
            currentObject.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    -- Input Listeners setup
    connections.Began = UIS.InputBegan:Connect(function(input, processed)
        if processed or not Config.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            if target and not target.Anchored then
                applyHardPhysics(target)
            end
        end
    end)

    connections.Ended = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            stopPhysics()
        end
    end)

    -- ==========================================
    -- UI CONSTRUCTION
    -- ==========================================
    Tab:CreateSection("Hard Dragger")

    Tab:CreateToggle("Enable Hard Dragger", false, function(state)
        Config.Enabled = state
        if not state then
            stopPhysics()
        end
        if Library then
            Library:Notify("Hard Dragger", state and "Dragger Enabled" or "Dragger Disabled", 3)
        end
    end)

    Tab:CreateSlider("Snappiness", 10, 300, 150, function(value)
        Config.Snappiness = value
    end)

    Tab:CreateSlider("Hold Distance", 2, 30, 8, function(value)
        Config.HoldDistance = value
    end)

    Tab:CreateSlider("Max Drag Radius", 5, 50, 12, function(value)
        Config.MaxDragRadius = value
    end)

    Tab:CreateSlider("Max Throw Speed", 50, 1000, 300, function(value)
        Config.MaxThrowSpeed = value
    end)

    Tab:CreateInfoBox("Tip", "Click and hold an unanchored object to drag it. Sliders update in real-time.")
end

return HardDragger

local HardDragger = {}

function HardDragger.Init(Tab, Library)
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local Camera = workspace.CurrentCamera

    -- Configuration
    local Config = {
        Enabled = false,
        DragStrength = 1e8,
        Snappiness = 150,
        HoldDistance = 10, -- Distance from the CHARACTER
        MaxDragRadius = 20,
        MaxThrowSpeed = 300
    }

    -- State
    local isDragging = false
    local currentObject = nil
    local physicsFolder = nil
    local connections = {}

    local throwVelocity = Vector3.zero
    local lastPosition = nil
    local initialRotation = nil

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
        
        -- Store rotation relative to camera
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
        alignPos.Parent = physicsFolder

        local alignOri = Instance.new("AlignOrientation")
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        alignOri.Parent = physicsFolder

        -- Disable collision with player to prevent "riding" the object or physics jitters
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

            if not isDragging or not currentObject or not currentObject.Parent or not rootPart or not Config.Enabled then
                if dragLoop then dragLoop:Disconnect() end
                stopPhysics()
                return
            end

            -- Update Velocity for throwing
            throwVelocity = (currentObject.Position - lastPosition) / dt
            lastPosition = currentObject.Position

            -- IMPROVED 3RD PERSON MATH:
            -- 1. Get the direction from the camera to the mouse
            local unitRay = Mouse.UnitRay
            
            -- 2. Calculate distance from Camera to Character
            local camToCharDist = (Camera.CFrame.Position - rootPart.Position).Magnitude
            
            -- 3. Set target position at a fixed distance BEYOND the character
            -- This prevents the "zoom glitch" where zooming out moves the object
            local targetPos = Camera.CFrame.Position + (unitRay.Direction * (camToCharDist + Config.HoldDistance))

            -- 4. Clamp distance from player so you don't drag things across the map
            local offset = targetPos - rootPart.Position
            if offset.Magnitude > Config.MaxDragRadius then
                targetPos = rootPart.Position + (offset.Unit * Config.MaxDragRadius)
            end

            -- 5. Obstacle Raycast (Stops object from going through walls)
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {character, currentObject, physicsFolder}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local rayHit = workspace:Raycast(Camera.CFrame.Position, targetPos - Camera.CFrame.Position, rayParams)
            if rayHit then
                targetPos = rayHit.Position - (unitRay.Direction * 1.5)
            end

            -- Apply to physics constraints
            alignPos.Position = targetPos
            alignOri.CFrame = Camera.CFrame.Rotation * initialRotation
            
            -- Keep momentum clean
            currentObject.AssemblyLinearVelocity = Vector3.zero
            currentObject.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    -- Listeners
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

    -- UI Section
    Tab:CreateSection("Hard Dragger (3rd Person Fix)")

    Tab:CreateToggle("Enable Dragger", false, function(state)
        Config.Enabled = state
        if not state then stopPhysics() end
    end)

    Tab:CreateSlider("Snappiness", 50, 300, 150, function(v) Config.Snappiness = v end)
    Tab:CreateSlider("Hold Distance", 5, 25, 10, function(v) Config.HoldDistance = v end)
    Tab:CreateSlider("Max Radius", 10, 100, 20, function(v) Config.MaxDragRadius = v end)
end

return HardDragger

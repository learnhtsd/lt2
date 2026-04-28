local HardDragger = {}

function HardDragger.Init(Tab, Library)
    local UIS        = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players    = game:GetService("Players")

    local Player = Players.LocalPlayer
    local Mouse  = Player:GetMouse()
    local Camera = workspace.CurrentCamera

    local Config = {
        Enabled       = false,
        DragStrength  = 1e8,
        Snappiness    = 150,
        MaxDragRadius = 10,   -- max studs from player root the object can be dragged to
        MaxThrowSpeed = 300,
    }

    local isDragging      = false
    local currentObject   = nil
    local physicsFolder   = nil
    local connections     = {}

    local throwVelocity   = Vector3.zero
    local lastPosition    = nil
    local initialRotation = nil

    -- Recorded at grab time
    local grabHoldDistance = 10   -- camera → object distance when grabbed
    local grabRootOffset   = nil  -- object position relative to rootPart at grab time

    local function stopPhysics()
        if isDragging and currentObject and currentObject.Parent then
            local finalVel = throwVelocity
            if finalVel.Magnitude > Config.MaxThrowSpeed then
                finalVel = finalVel.Unit * Config.MaxThrowSpeed
            end
            currentObject.AssemblyLinearVelocity = finalVel
        end

        isDragging      = false
        currentObject   = nil
        lastPosition    = nil
        initialRotation = nil
        grabRootOffset  = nil

        if physicsFolder then
            physicsFolder:Destroy()
            physicsFolder = nil
        end
    end

    local function applyHardPhysics(obj)
        if not obj or obj.Anchored or not Config.Enabled then return end

        stopPhysics()

        local character = Player.Character
        local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        isDragging      = true
        currentObject   = obj
        lastPosition    = obj.Position

        -- KEY FIX: record true camera→object distance at grab time.
        -- This becomes the fixed "hold distance" for the entire drag,
        -- so the target always sits at the same depth regardless of zoom.
        grabHoldDistance = (Camera.CFrame.Position - obj.Position).Magnitude

        -- Record where the object sat relative to the player root at grab time.
        -- The radius clamp will measure from rootPart but we already know the
        -- initial offset was valid, so we clamp to MaxDragRadius from root.
        grabRootOffset = obj.Position - rootPart.Position

        -- Store rotation relative to camera at grab time
        initialRotation = Camera.CFrame.Rotation:Inverse() * obj.CFrame

        physicsFolder      = Instance.new("Folder")
        physicsFolder.Name = "HardDrag_Override"
        physicsFolder.Parent = obj

        local att = Instance.new("Attachment", obj)
        obj.AssemblyLinearVelocity  = Vector3.zero
        obj.AssemblyAngularVelocity = Vector3.zero

        local alignPos = Instance.new("AlignPosition")
        alignPos.Mode          = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0   = att
        alignPos.MaxForce      = Config.DragStrength
        alignPos.MaxVelocity   = math.huge
        alignPos.Responsiveness = Config.Snappiness
        alignPos.Parent        = physicsFolder

        local alignOri = Instance.new("AlignOrientation")
        alignOri.Mode          = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0   = att
        alignOri.MaxTorque     = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        alignOri.Parent        = physicsFolder

        -- Suppress player↔object collisions to stop riding/jitter
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    local noCol  = Instance.new("NoCollisionConstraint")
                    noCol.Part0  = obj
                    noCol.Part1  = part
                    noCol.Parent = physicsFolder
                end
            end
        end

        local dragLoop
        dragLoop = RunService.Heartbeat:Connect(function(dt)
            local char     = Player.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")

            if not isDragging or not currentObject or not currentObject.Parent
            or not rootPart or not Config.Enabled then
                if dragLoop then dragLoop:Disconnect() end
                stopPhysics()
                return
            end

            -- Track velocity for throw
            throwVelocity = (currentObject.Position - lastPosition) / dt
            lastPosition  = currentObject.Position

            local unitRay = Mouse.UnitRay

            -- KEY FIX: use the distance recorded AT GRAB TIME, not
            -- camToCharDist + HoldDistance. This keeps the object at
            -- the same depth in the scene regardless of where on the
            -- object you clicked or how far zoomed out the camera is.
            local targetPos = Camera.CFrame.Position + (unitRay.Direction * grabHoldDistance)

            -- Clamp so the object can't be dragged further than MaxDragRadius
            -- from the player root. Because we use grabHoldDistance, a part
            -- grabbed at e.g. 8 studs will naturally sit at ~8 studs and won't
            -- fight the clamp unless you actively try to drag past MaxDragRadius.
            local toTarget = targetPos - rootPart.Position
            if toTarget.Magnitude > Config.MaxDragRadius then
                targetPos = rootPart.Position + (toTarget.Unit * Config.MaxDragRadius)
            end

            -- Wall/obstacle raycast — stop object going through geometry
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char, currentObject, physicsFolder}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local rayHit = workspace:Raycast(
                Camera.CFrame.Position,
                targetPos - Camera.CFrame.Position,
                rayParams
            )
            if rayHit then
                targetPos = rayHit.Position - (unitRay.Direction * 1.5)
            end

            alignPos.Position = targetPos
            alignOri.CFrame   = Camera.CFrame.Rotation * initialRotation

            currentObject.AssemblyLinearVelocity  = Vector3.zero
            currentObject.AssemblyAngularVelocity = Vector3.zero
        end)
    end

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

    -- UI
    Tab:CreateSection("Hard Dragger (3rd Person Fix)")

    Tab:CreateToggle("Enable Dragger", false, function(state)
        Config.Enabled = state
        if not state then stopPhysics() end
    end)

    Tab:CreateSlider("Snappiness",  50,  300, 150, function(v) Config.Snappiness    = v end)
    Tab:CreateSlider("Max Radius",   5,  100,  10, function(v) Config.MaxDragRadius = v end)
end

return HardDragger

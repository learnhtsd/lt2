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
        Snappiness    = 150,
        MaxDragRadius = 8,
        MaxThrowSpeed = 300,
    }

    local isDragging         = false
    local currentObject      = nil
    local physicsFolder      = nil
    local connections        = {}

    local throwVelocity      = Vector3.zero
    local lastPosition       = nil
    local initialRotation    = nil
    local grabHoldDistance   = 10

    -- Store original physical properties so we can restore them
    local originalProperties = nil
    local hadCustomProperties = false

    -- Nearly massless properties used during drag
    local DRAG_PROPERTIES = PhysicalProperties.new(
        0.01,  -- density   (near zero = near massless)
        0,     -- friction
        0,     -- elasticity
        0,     -- frictionWeight
        0      -- elasticityWeight
    )

    local alignPos = nil  -- kept in scope so heartbeat can write Position before first tick

    local function computeTargetPos(rootPart)
        local unitRay  = Mouse.UnitRay
        local targetPos = Camera.CFrame.Position + (unitRay.Direction * grabHoldDistance)

        local toTarget = targetPos - rootPart.Position
        if toTarget.Magnitude > Config.MaxDragRadius then
            targetPos = rootPart.Position + (toTarget.Unit * Config.MaxDragRadius)
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {Player.Character, currentObject, physicsFolder}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local rayHit = workspace:Raycast(Camera.CFrame.Position, targetPos - Camera.CFrame.Position, rayParams)
        if rayHit then
            targetPos = rayHit.Position - (unitRay.Direction * 1.5)
        end

        return targetPos
    end

    local function stopPhysics()
        if isDragging and currentObject and currentObject.Parent then
            -- Restore original physical properties
            if hadCustomProperties then
                currentObject.CustomPhysicalProperties = originalProperties
            else
                currentObject.CustomPhysicalProperties = PhysicalProperties.new(
                    -- Roblox default material properties
                    0.7, 0.3, 0.5, 1, 1
                )
            end

            local finalVel = throwVelocity
            if finalVel.Magnitude > Config.MaxThrowSpeed then
                finalVel = finalVel.Unit * Config.MaxThrowSpeed
            end
            currentObject.AssemblyLinearVelocity = finalVel
        end

        isDragging       = false
        currentObject    = nil
        lastPosition     = nil
        initialRotation  = nil
        alignPos         = nil
        originalProperties   = nil
        hadCustomProperties  = false

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

        isDragging     = true
        currentObject  = obj
        lastPosition   = obj.Position

        grabHoldDistance = (Camera.CFrame.Position - obj.Position).Magnitude
        initialRotation  = Camera.CFrame.Rotation:Inverse() * obj.CFrame

        -- Save and override physical properties to make object massless during drag
        hadCustomProperties  = obj.CustomPhysicalProperties ~= nil
        originalProperties   = obj.CustomPhysicalProperties
        obj.CustomPhysicalProperties = DRAG_PROPERTIES

        obj.AssemblyLinearVelocity  = Vector3.zero
        obj.AssemblyAngularVelocity = Vector3.zero

        physicsFolder        = Instance.new("Folder")
        physicsFolder.Name   = "HardDrag_Override"
        physicsFolder.Parent = obj

        local att        = Instance.new("Attachment", obj)

        alignPos                 = Instance.new("AlignPosition")
        alignPos.Mode            = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0     = att
        alignPos.MaxForce        = math.huge
        alignPos.MaxVelocity     = math.huge
        alignPos.Responsiveness  = Config.Snappiness
        alignPos.Parent          = physicsFolder

        -- KEY FIX: set Position immediately so there's zero
        -- frames where it defaults to Vector3.zero and jolts
        alignPos.Position = computeTargetPos(rootPart)

        local alignOri               = Instance.new("AlignOrientation")
        alignOri.Mode                = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0         = att
        alignOri.MaxTorque           = math.huge
        alignOri.Responsiveness      = Config.Snappiness
        alignOri.CFrame              = Camera.CFrame.Rotation * initialRotation
        alignOri.Parent              = physicsFolder

        -- Suppress player collision to stop riding/jitter
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
            local root     = char and char:FindFirstChild("HumanoidRootPart")

            if not isDragging or not currentObject or not currentObject.Parent
            or not root or not Config.Enabled then
                if dragLoop then dragLoop:Disconnect() end
                stopPhysics()
                return
            end

            throwVelocity = (currentObject.Position - lastPosition) / dt
            lastPosition  = currentObject.Position

            local targetPos = computeTargetPos(root)

            alignPos.Position = targetPos
            alignOri.CFrame   = Camera.CFrame.Rotation * initialRotation

            -- Belt-and-suspenders: keep killing residual velocity
            -- so the near-massless object doesn't drift
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
    Tab:CreateToggle("Enable Dragger", false, function(state)
        Config.Enabled = state
        if not state then stopPhysics() end
    end)
end

return HardDragger

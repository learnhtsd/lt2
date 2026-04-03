local HardDragger = {}

-- Services
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Internal State
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera

local state = {
    Enabled = false,
    IsDragging = false,
    CurrentObject = nil,
    PhysicsFolder = nil,
    Connections = {},
    
    -- Configurable via Sliders
    Strength = 1e8,
    Snappiness = 150,
    Distance = 8,
    Radius = 12,
    MaxThrow = 300,
    
    -- Physics Math
    ThrowVelocity = Vector3.zero,
    LastPosition = nil,
    InitialRotation = nil
}

local function stopPhysics()
    if state.IsDragging and state.CurrentObject and state.CurrentObject.Parent then
        local finalVel = state.ThrowVelocity
        if finalVel.Magnitude > state.MaxThrow then
            finalVel = finalVel.Unit * state.MaxThrow
        end
        state.CurrentObject.AssemblyLinearVelocity = finalVel
    end

    state.IsDragging = false
    state.CurrentObject = nil
    state.LastPosition = nil
    state.InitialRotation = nil
    state.ThrowVelocity = Vector3.zero
    
    if state.PhysicsFolder then
        state.PhysicsFolder:Destroy()
        state.PhysicsFolder = nil
    end
end

local function applyHardPhysics(obj)
    if not obj or obj.Anchored or not state.Enabled then return end
    
    stopPhysics() 
    state.IsDragging = true
    state.CurrentObject = obj
    state.LastPosition = obj.Position
    state.InitialRotation = Camera.CFrame.Rotation:Inverse() * obj.CFrame
    
    state.PhysicsFolder = Instance.new("Folder")
    state.PhysicsFolder.Name = "HardDrag_Override"
    state.PhysicsFolder.Parent = obj

    local att = Instance.new("Attachment", obj)
    obj.AssemblyLinearVelocity = Vector3.zero
    obj.AssemblyAngularVelocity = Vector3.zero

    local alignPos = Instance.new("AlignPosition")
    alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPos.Attachment0 = att
    alignPos.MaxForce = state.Strength
    alignPos.MaxVelocity = math.huge
    alignPos.Responsiveness = state.Snappiness
    alignPos.Position = obj.Position
    alignPos.Parent = state.PhysicsFolder

    local alignOri = Instance.new("AlignOrientation")
    alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOri.Attachment0 = att
    alignOri.MaxTorque = state.Strength
    alignOri.Responsiveness = state.Snappiness
    alignOri.CFrame = obj.CFrame 
    alignOri.Parent = state.PhysicsFolder

    -- Anti-Fling logic
    if Player.Character then
        for _, part in pairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                local noCol = Instance.new("NoCollisionConstraint")
                noCol.Part0 = obj
                noCol.Part1 = part
                noCol.Parent = state.PhysicsFolder
            end
        end
    end

    local dragLoop
    dragLoop = RunService.Heartbeat:Connect(function(dt)
        if not state.IsDragging or not state.CurrentObject or not state.CurrentObject.Parent or not state.Enabled then
            dragLoop:Disconnect()
            return
        end

        if state.LastPosition then
            state.ThrowVelocity = (state.CurrentObject.Position - state.LastPosition) / dt
        end
        state.LastPosition = state.CurrentObject.Position

        local targetPos = Camera.CFrame.Position + (Mouse.UnitRay.Direction * (state.Distance))

        -- Distance Clamp
        local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local offset = targetPos - root.Position
            if offset.Magnitude > state.Radius then
                targetPos = root.Position + (offset.Unit * state.Radius)
            end
        end

        -- Raycast Obstacles
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {Player.Character, state.CurrentObject, state.PhysicsFolder}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local hit = workspace:Raycast(Camera.CFrame.Position, targetPos - Camera.CFrame.Position, params)

        if hit then
            targetPos = hit.Position - ((targetPos - Camera.CFrame.Position).Unit * 1.5)
        end

        alignPos.Position = targetPos
        alignOri.CFrame = Camera.CFrame.Rotation * state.InitialRotation
        
        state.CurrentObject.AssemblyLinearVelocity = Vector3.zero
        state.CurrentObject.AssemblyAngularVelocity = Vector3.zero
    end)
end

function HardDragger.Init(Tab)
    Tab:CreateSection("Hard Dragger Controls")

    Tab:CreateToggle("Enable Hard Drag", false, function(v)
        state.Enabled = v
        if not v then stopPhysics() end
    end)

    Tab:CreateSlider("Drag Strength", 1, 10, 8, function(v)
        state.Strength = 10^v -- Scale exponentially for massive force
    end)

    Tab:CreateSlider("Snappiness", 10, 300, 150, function(v)
        state.Snappiness = v
    end)

    Tab:CreateSlider("Hold Distance", 2, 30, 8, function(v)
        state.Distance = v
    end)

    Tab:CreateSlider("Max Reach", 5, 50, 12, function(v)
        state.Radius = v
    end)

    Tab:CreateSlider("Throw Power", 0, 1000, 300, function(v)
        state.MaxThrow = v
    end)

    -- Input Handling
    table.insert(state.Connections, UIS.InputBegan:Connect(function(input, processed)
        if processed or not state.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            if target and not target.Anchored then
                applyHardPhysics(target)
            end
        end
    end))

    table.insert(state.Connections, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            stopPhysics()
        end
    end))
    
    return state
end

return HardDragger

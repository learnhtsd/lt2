local PlayerMovement = {}

function PlayerMovement.Init(Tab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.SpeedEnabled = false
    _G.WalkSpeed = 50
    _G.SprintEnabled = false
    _G.SprintSpeed = 100
    _G.IsSprinting = false

    _G.JumpEnabled = false
    _G.JumpHeight = 50
    _G.InfJump = false

    _G.FlyEnabled = false
    _G.FlySpeed = 50
    
    _G.Noclip = false
    _G.AntiFling = false
    _G.WaterWalk = false
    _G.ClickTP = false
    
    _G.HardDragger = true
    _G.DragDistance = 100 -- Increase this for even further range
    local draggedPart = nil
    local dragBP = nil
    local dragBG = nil

    local flyVelocity = nil
    local flyGyro = nil

    -- ===========================
    -- PHYSICS & UTILS
    -- ===========================
    local function UpdateFlyPhysics(state)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if state and hrp and hum then
            if not flyVelocity or not flyVelocity.Parent then
                flyVelocity = Instance.new("BodyVelocity")
                flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                flyVelocity.Parent = hrp
            end
            if not flyGyro or not flyGyro.Parent then
                flyGyro = Instance.new("BodyGyro")
                flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
                flyGyro.P = 10000
                flyGyro.Parent = hrp
            end
            hum.PlatformStand = true 
        else
            if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
            if flyGyro then flyGyro:Destroy(); flyGyro = nil end
            if hum then 
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            if hrp then hrp.Velocity = Vector3.new(0,0,0) end
        end
    end

    -- Input Began
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and _G.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end

        if not processed and _G.HardDragger and input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            -- Target must exist and not be anchored
            if target and not target.Anchored then
                draggedPart = target
                
                -- BodyPosition setup
                dragBP = Instance.new("BodyPosition")
                dragBP.Name = "ExploitDragBP"
                dragBP.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                dragBP.P = 200000 -- High power to move heavy wood
                dragBP.D = 1000   -- Damping to prevent rubber-banding
                dragBP.Parent = draggedPart

                -- BodyGyro setup
                dragBG = Instance.new("BodyGyro")
                dragBG.Name = "ExploitDragBG"
                dragBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                dragBG.P = 200000
                dragBG.CFrame = draggedPart.CFrame -- Maintain its current rotation
                dragBG.Parent = draggedPart
            end
        end
    end)

    -- Input Ended
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragBP then dragBP:Destroy(); dragBP = nil end
            if dragBG then dragBG:Destroy(); dragBG = nil end
            draggedPart = nil
        end
    end)

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Movement")
    Tab:CreateToggle("Enable WalkSpeed", false, function(s) _G.SpeedEnabled = s end)
    Tab:CreateSlider("Walk Value", 16, 200, 50, function(v) _G.WalkSpeed = v end)
    Tab:CreateToggle("Fly", false, function(s) _G.FlyEnabled = s UpdateFlyPhysics(s) end)
    Tab:CreateSlider("Fly Speed", 16, 300, 50, function(v) _G.FlySpeed = v end)

    Tab:CreateSection("LT2 Utilities")
    Tab:CreateToggle("Hard Dragger", true, function(s) _G.HardDragger = s end)
    Tab:CreateSlider("Drag Reach", 50, 1000, 200, function(v) _G.DragDistance = v end)
    Tab:CreateToggle("Noclip", false, function(s) _G.Noclip = s end)

    -- ===========================
    -- MASTER LOOP
    -- ===========================
    RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")

        -- Logic for the Hard Dragger
        if _G.HardDragger and draggedPart and dragBP then
            -- We use Mouse.Hit.Position, which allows you to drag it as far as your camera can see.
            -- To keep the item from clipping through the ground, we add a small offset.
            local targetPos = Mouse.Hit.Position + Vector3.new(0, 2, 0)
            
            -- Optional: Distance clamping (uncomment if you want to limit range)
            --[[
            local dist = (hrp.Position - targetPos).Magnitude
            if dist > _G.DragDistance then
                targetPos = hrp.Position + (targetPos - hrp.Position).Unit * _G.DragDistance
            end
            ]]
            
            dragBP.Position = targetPos
            
            -- Keep the part from rotating wildly while dragging
            if dragBG then
                dragBG.CFrame = Mouse.Origin -- Makes the part "face" the camera
            end
        end

        -- Noclip Logic
        if _G.Noclip then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end

        -- Fly Logic
        if _G.FlyEnabled and hrp then
            local cam = Workspace.CurrentCamera
            local moveVector = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + cam.CFrame.RightVector end
            
            if flyVelocity then
                flyVelocity.Velocity = (moveVector.Magnitude > 0) and (moveVector.Unit * _G.FlySpeed) or Vector3.new(0,0,0)
            end
            if flyGyro then
                flyGyro.CFrame = cam.CFrame
            end
        end
    end)
end

return PlayerMovement

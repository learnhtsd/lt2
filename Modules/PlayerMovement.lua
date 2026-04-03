local PlayerMovement = {}

function PlayerMovement.Init(Tab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local Camera = Workspace.CurrentCamera

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.SpeedEnabled = false
    _G.WalkSpeed = 16
    _G.SprintEnabled = false
    _G.SprintSpeed = 32
    _G.IsSprinting = false

    _G.JumpEnabled = false
    _G.JumpHeight = 16
    _G.InfJump = false

    -- Flight States
    _G.FlyMasterSwitch = true
    _G.IsFlying = false
    _G.FlySpeed = 250
    local lastFlyVelocity = Vector3.zero

    _G.Noclip = false
    _G.WaterWalk = false
    _G.ClickTP = false

    -- Hard Dragger State
    _G.HardDragger = false
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
                flyVelocity.Name = "ExploitFlyVelocity"
                flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                flyVelocity.Parent = hrp
            end
            if not flyGyro or not flyGyro.Parent then
                flyGyro = Instance.new("BodyGyro")
                flyGyro.Name = "ExploitFlyGyro"
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

            if hrp then
                hrp.AssemblyLinearVelocity = lastFlyVelocity
            end
            
            task.wait(0.1)
            if hum then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
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
            if target and not target.Anchored then
                draggedPart = target
                dragBP = Instance.new("BodyPosition")
                dragBP.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                dragBP.P = 100000
                dragBP.Parent = draggedPart

                dragBG = Instance.new("BodyGyro")
                dragBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                dragBG.P = 100000
                dragBG.Parent = draggedPart
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragBP then dragBP:Destroy(); dragBP = nil end
            if dragBG then dragBG:Destroy(); dragBG = nil end
            draggedPart = nil
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        if _G.InfJump then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState("Jumping") end
        end
    end)

    -- ===========================
    -- UI SECTIONS
    -- ===========================

    -- CAMERA SECTION
    Tab:CreateSection("Camera Settings")
    
    Tab:CreateSlider("Field of View", 1, 120, 70, function(v)
        Camera.FieldOfView = v
    end)

    Tab:CreateToggle("Infinite Zoom", false, function(s)
        if s then
            LocalPlayer.CameraMaxZoomDistance = 10000
            LocalPlayer.CameraMinZoomDistance = 0.5
        else
            LocalPlayer.CameraMaxZoomDistance = 128
        end
    end)

    Tab:CreateSlider("Max Zoom Distance", 128, 10000, 128, function(v)
        LocalPlayer.CameraMaxZoomDistance = v
    end)

    -- SPEED SECTION
    Tab:CreateSection("Speed & Sprint")
    Tab:CreateToggle("Enable WalkSpeed", false, function(s) _G.SpeedEnabled = s end)
    Tab:CreateSlider("Walk Value", 16, 1000, 16, function(v) _G.WalkSpeed = v end)
    Tab:CreateToggle("Enable Sprinting", false, function(s) _G.SprintEnabled = s end)
    Tab:CreateSlider("Sprint Value", 16, 1000, 32, function(v) _G.SprintSpeed = v end)
    Tab:CreateKeybind("Sprint Key", Enum.KeyCode.LeftShift, function() _G.IsSprinting = not _G.IsSprinting end)

    -- JUMPING SECTION
    Tab:CreateSection("Jumping")
    Tab:CreateToggle("Enable Jump Height", false, function(s) _G.JumpEnabled = s end)
    Tab:CreateSlider("Jump Power", 16, 500, 16, function(v) _G.JumpHeight = v end)
    Tab:CreateToggle("Infinite Jump", false, function(s) _G.InfJump = s end)

    -- FLIGHT SECTION
    Tab:CreateSection("Flight")
    Tab:CreateToggle("Enable Fly Hotkey", true, function(s) 
        _G.FlyMasterSwitch = s 
        if not s and _G.IsFlying then
            _G.IsFlying = false
            UpdateFlyPhysics(false)
        end
    end)
    Tab:CreateSlider("Fly Speed", 16, 2500, 250, function(v) _G.FlySpeed = v end)
    Tab:CreateKeybind("Fly Hotkey", Enum.KeyCode.Q, function() 
        if _G.FlyMasterSwitch then
            _G.IsFlying = not _G.IsFlying 
            UpdateFlyPhysics(_G.IsFlying) 
        end
    end)

    -- UTILITY SECTION
    Tab:CreateSection("Utility")
    Tab:CreateToggle("Noclip", false, function(s) _G.Noclip = s end)
    Tab:CreateToggle("Water Walk", false, function(s) _G.WaterWalk = s end)
    Tab:CreateToggle("Ctrl + Click TP", false, function(s) _G.ClickTP = s end)

    Tab:CreateToggle("LT2 Hard Dragger", false, function(s) 
        _G.HardDragger = s 
        if not s then
            if dragBP then dragBP:Destroy(); dragBP = nil end
            if dragBG then dragBG:Destroy(); dragBG = nil end
            draggedPart = nil
        end
    end)

    Tab:CreateAction("Reset Character", "Kill", function()
        if LocalPlayer.Character then LocalPlayer.Character:BreakJoints() end
    end)

    -- ===========================
    -- MASTER LOOP
    -- ===========================
    RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")

        -- Hard Dragger Logic
        if _G.HardDragger and draggedPart and dragBP and dragBG then
            local hitPos = Mouse.Hit.Position
            dragBP.Position = hitPos + Vector3.new(0, (draggedPart.Size.Y / 2) + 2, 0)
            if char:FindFirstChild("Head") then
                dragBG.CFrame = CFrame.new(draggedPart.Position, char.Head.Position)
            end
        end

        -- Noclip
        if _G.Noclip then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end

        -- Water Walk
        if _G.WaterWalk and hrp then
            if hrp.Position.Y <= 1 and hrp.Position.Y >= -5 then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.1, 0)
            end
        end

        -- Speed/Jump Logic
        if hum then
            if _G.SprintEnabled and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or _G.IsSprinting) then
                hum.WalkSpeed = _G.SprintSpeed
            elseif _G.SpeedEnabled then
                hum.WalkSpeed = _G.WalkSpeed
            end

            if _G.JumpEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = _G.JumpHeight
            end
        end

        -- Fly Logic
        if _G.IsFlying and hrp then
            if not hrp:FindFirstChild("ExploitFlyVelocity") then UpdateFlyPhysics(true) end
            if flyVelocity and flyGyro then
                local moveVector = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Camera.CFrame.RightVector end
                
                local vel = (moveVector.Magnitude > 0) and (moveVector.Unit * _G.FlySpeed) or Vector3.new(0,0,0)
                flyVelocity.Velocity = vel
                flyGyro.CFrame = Camera.CFrame
                lastFlyVelocity = vel
            end
        end
    end)
end

return PlayerMovement

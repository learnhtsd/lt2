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
    _G.WalkSpeed = 16
    _G.SprintEnabled = false
    _G.SprintSpeed = 64
    _G.IsSprinting = false

    _G.JumpHeight = 50
    _G.InfJump = false

    -- Flight States
    _G.FlyMasterSwitch = true
    _G.IsFlying = false
    _G.FlySpeed = 250

    _G.Noclip = false
    _G.WaterWalk = false
    _G.ClickTP = false

    local flyVelocity = nil
    local flyGyro = nil

    -- ===========================
    -- CLEANUP ORPHANED OBJECTS
    -- ===========================
    local function CleanupOrphanedFlyObjects()
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local orphanedVelocity = hrp:FindFirstChild("ExploitFlyVelocity")
                local orphanedGyro = hrp:FindFirstChild("ExploitFlyGyro")
                if orphanedVelocity then orphanedVelocity:Destroy() end
                if orphanedGyro then orphanedGyro:Destroy() end
            end
        end
    end

    CleanupOrphanedFlyObjects()

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
                flyVelocity.Velocity = Vector3.new(0, 0, 0)
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
                task.wait(0.05)
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end
    end

    -- Inputs
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and _G.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
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

    -- SPEED SECTION
    Tab:CreateSection("Movement")
    Tab:CreateSlider("Walk Speed", 16, 400, 16, function(v) _G.WalkSpeed = v end)
    Tab:CreateSlider("Jump Power", 50, 800, 50, function(v) _G.JumpHeight = v end)
    Tab:CreateSlider("Sprint Speed", 32, 800, 64, function(v) _G.SprintSpeed = v end)
    Tab:CreateSlider("Fly Speed", 32, 1600, 250, function(v) _G.FlySpeed = v end)
    Tab:CreateToggle("Sprint Toggle", false, function(s) _G.SprintEnabled = s end)
    Tab:CreateToggle("Enable Fly", true, function(s) 
        _G.FlyMasterSwitch = s 
        if not s and _G.IsFlying then
            _G.IsFlying = false
            UpdateFlyPhysics(false)
        end
    end)
    
    Tab:CreateKeybind("Fly Hotkey", Enum.KeyCode.Q, function() 
        if _G.FlyMasterSwitch then
            _G.IsFlying = not _G.IsFlying 
            UpdateFlyPhysics(_G.IsFlying) 
        end
    end)

    
    -- CAMERA SECTION
    Tab:CreateSection("Camera Settings")
    Tab:CreateSlider("Field of View", 60, 120, 70, function(v) Camera.FieldOfView = v end)
    Tab:CreateToggle("Infinite Zoom", false, function(s)
        LocalPlayer.CameraMaxZoomDistance = s and 10000 or 128
        LocalPlayer.CameraMinZoomDistance = 0.5
    end)

    -- UTILITY SECTION
    Tab:CreateSection("Utility")
    Tab:CreateKeybind("Sprint HotKey", Enum.KeyCode.LeftShift, function() _G.IsSprinting = not _G.IsSprinting end)
    Tab:CreateKeybind("Fly Hotkey", Enum.KeyCode.Q, function() 
        if _G.FlyMasterSwitch then
            _G.IsFlying = not _G.IsFlying 
            UpdateFlyPhysics(_G.IsFlying) 
        end
    end)
    Tab:CreateToggle("Noclip", false, function(s) _G.Noclip = s end)
    Tab:CreateToggle("Water Walk", false, function(s) _G.WaterWalk = s end)
    Tab:CreateToggle("Ctrl + Click TP", false, function(s) _G.ClickTP = s end)
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

        -- Noclip
        if _G.Noclip then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end

        -- Speed/Jump Loop Logic
        if hum then
            -- Jump Power Application
            hum.UseJumpPower = true
            hum.JumpPower = _G.JumpHeight

            -- Speed Logic
            if _G.SprintEnabled and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or _G.IsSprinting) then
                hum.WalkSpeed = _G.SprintSpeed
            else
                hum.WalkSpeed = _G.WalkSpeed
            end
        end

        -- Water Walk
        if _G.WaterWalk and hrp then
            if hrp.Position.Y <= 1 and hrp.Position.Y >= -5 then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.1, 0)
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
            end
        end
    end)
end

return PlayerMovement

local PlayerMovement = {}

function PlayerMovement.Init(Tab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

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
            if hum then hum.PlatformStand = false end
        end
    end

    -- Click TP 
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and _G.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local Mouse = LocalPlayer:GetMouse()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end)

    -- Inf Jump
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
    Tab:CreateSection("Speed & Sprint")
    Tab:CreateToggle("Enable WalkSpeed", false, function(s) _G.SpeedEnabled = s end)
    Tab:CreateSlider("Walk Value", 16, 200, 50, function(v) _G.WalkSpeed = v end)
    Tab:CreateToggle("Enable Sprinting", false, function(s) _G.SprintEnabled = s end)
    Tab:CreateSlider("Sprint Value", 50, 300, 100, function(v) _G.SprintSpeed = v end)
    Tab:CreateKeybind("Sprint Key", Enum.KeyCode.LeftShift, function() _G.IsSprinting = not _G.IsSprinting end)

    -- JUMPING SECTION
    Tab:CreateSection("Jumping")
    Tab:CreateToggle("Enable Jump Height", false, function(s) _G.JumpEnabled = s end)
    Tab:CreateSlider("Jump Power", 50, 300, 50, function(v) _G.JumpHeight = v end)
    Tab:CreateToggle("Infinite Jump", false, function(s) _G.InfJump = s end)

    -- FLIGHT SECTION
    Tab:CreateSection("Flight")
    Tab:CreateToggle("Enable Fly", false, function(s) _G.FlyEnabled = s UpdateFlyPhysics(s) end)
    Tab:CreateSlider("Fly Speed", 16, 300, 50, function(v) _G.FlySpeed = v end)
    Tab:CreateKeybind("Fly Hotkey", Enum.KeyCode.Q, function() 
        _G.FlyEnabled = not _G.FlyEnabled 
        UpdateFlyPhysics(_G.FlyEnabled) 
    end)

    -- UTILITY SECTION
    Tab:CreateSection("Utility")
    Tab:CreateToggle("Noclip", false, function(s) _G.Noclip = s end)
    Tab:CreateToggle("Anti-Fling", false, function(s) _G.AntiFling = s end)
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

        -- Water Walk
        if _G.WaterWalk and hrp then
            if hrp.Position.Y <= 1 and hrp.Position.Y >= -5 then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.1, 0)
            end
        end

        -- Anti-Fling
        if _G.AntiFling and hrp then
            hrp.RotVelocity = Vector3.new(0, 0, 0)
        end

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

        -- Fly 
        if _G.FlyEnabled and hrp then
            if not hrp:FindFirstChild("ExploitFlyVelocity") then UpdateFlyPhysics(true) end
            if flyVelocity and flyGyro then
                local cam = Workspace.CurrentCamera
                local moveVector = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + cam.CFrame.RightVector end
                flyVelocity.Velocity = (moveVector.Magnitude > 0) and (moveVector.Unit * _G.FlySpeed) or Vector3.new(0,0,0)
                flyGyro.CFrame = cam.CFrame
            end
        end
    end)
end

return PlayerMovement

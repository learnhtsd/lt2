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
    
    _G.JumpEnabled = false
    _G.JumpHeight = 50

    _G.FlyEnabled = false
    _G.FlySpeed = 50
    
    local flyVelocity = nil
    local flyGyro = nil

    -- ===========================
    -- FLY PHYSICS HANDLER
    -- ===========================
    local function UpdateFlyPhysics(state)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if state and hrp and hum then
            -- Create Body Movers for flight if they don't exist
            if not flyVelocity or not flyVelocity.Parent then
                flyVelocity = Instance.new("BodyVelocity")
                flyVelocity.Name = "ExploitFlyVelocity"
                flyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
                flyVelocity.Parent = hrp
            end
            if not flyGyro or not flyGyro.Parent then
                flyGyro = Instance.new("BodyGyro")
                flyGyro.Name = "ExploitFlyGyro"
                flyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
                flyGyro.P = 10000
                flyGyro.Parent = hrp
            end
            hum.PlatformStand = true -- Disables normal walking animations/physics
        else
            -- Clean up Body Movers when fly is disabled
            if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
            if flyGyro then flyGyro:Destroy(); flyGyro = nil end
            if hum then hum.PlatformStand = false end
        end
    end

    -- ===========================
    -- UI ELEMENTS
    -- ===========================
    
    Tab:CreateSection("Speed")
    Tab:CreateToggle("Enable Speed", false, function(state)
        _G.SpeedEnabled = state
    end)
    Tab:CreateSlider("Speed Value", 16, 200, 50, function(value)
        _G.WalkSpeed = value
    end)

    Tab:CreateSection("Jump")
    Tab:CreateToggle("Enable Jump Height", false, function(state)
        _G.JumpEnabled = state
    end)
    Tab:CreateSlider("Jump Height Value", 50, 300, 50, function(value)
        _G.JumpHeight = value
    end)

    Tab:CreateSection("Fly")
    Tab:CreateToggle("Enable Fly", false, function(state)
        _G.FlyEnabled = state
        UpdateFlyPhysics(state)
    end)
    Tab:CreateSlider("Fly Speed", 16, 300, 50, function(value)
        _G.FlySpeed = value
    end)
    Tab:CreateKeybind("Fly Hotkey", Enum.KeyCode.Q, function()
        _G.FlyEnabled = not _G.FlyEnabled
        UpdateFlyPhysics(_G.FlyEnabled)
    end)

    Tab:CreateSection("Utility")
    Tab:CreateAction("Reset Character", "Kill", function()
        local char = LocalPlayer.Character
        if char then
            char:BreakJoints()
        end
    end)

    -- ===========================
    -- MASTER MOVEMENT LOOP
    -- ===========================
    RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")

        -- 1. Enforce Speed and Jump Height
        if hum then
            if _G.SpeedEnabled then
                hum.WalkSpeed = _G.WalkSpeed
            end

            if _G.JumpEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = _G.JumpHeight
            end
        end

        -- 2. Handle Fly Movement
        if _G.FlyEnabled and hrp then
            -- Re-apply fly physics if the player respawned while fly was enabled
            if not hrp:FindFirstChild("ExploitFlyVelocity") then
                UpdateFlyPhysics(true)
            end

            if flyVelocity and flyGyro then
                local cam = Workspace.CurrentCamera
                local moveVector = Vector3.new(0, 0, 0)

                -- Calculate movement direction based on camera angle and WASD
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + cam.CFrame.RightVector end

                -- Apply Velocity
                if moveVector.Magnitude > 0 then
                    flyVelocity.Velocity = moveVector.Unit * _G.FlySpeed
                else
                    flyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
                
                -- Face the camera direction
                flyGyro.CFrame = cam.CFrame
            end
        end
    end)
end

return PlayerMovement

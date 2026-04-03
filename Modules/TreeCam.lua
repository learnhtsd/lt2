local TreeCam = {}

function TreeCam.Init(Tab)
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local UserSettings = UserSettings():GetService("UserGameSettings")
    
    local Camera = Workspace.CurrentCamera
    
    -- STATE VARIABLES
    _G.LoneTreeCamEnabled = false
    local TreePosition = Vector3.new(-50, -215, -1315) -- The target
    local Distance = 25 -- How far back the camera stays
    local Yaw = 0   -- Horizontal rotation
    local Pitch = 0 -- Vertical rotation

    -- UI SECTION
    Tab:CreateToggle("Orbit Lone Cave Tree", false, function(state)
        _G.LoneTreeCamEnabled = state
        
        if state then
            Camera.CameraType = Enum.CameraType.Scriptable
            -- Reset angles when opening so it's not jarring
            Yaw = 0
            Pitch = 0
        else
            Camera.CameraType = Enum.CameraType.Custom
        end
    end)

    -- INPUT HANDLING
    UserInputService.InputChanged:Connect(function(input, processed)
        if not _G.LoneTreeCamEnabled then return end
        
        -- Only rotate if Right Mouse Button is held down
        if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local Delta = input.Delta
            local Sensitivity = UserSettings.MouseSensitivity
            
            -- Adjust Yaw and Pitch based on mouse movement
            Yaw = Yaw - (Delta.X * Sensitivity * 0.5)
            Pitch = math.clamp(Pitch - (Delta.Y * Sensitivity * 0.5), -80, 80) -- Clamp to prevent flipping over
        end
    end)

    -- MASTER LOGIC
    RunService.RenderStepped:Connect(function()
        if _G.LoneTreeCamEnabled then
            -- Calculate the new CFrame based on rotation and distance
            local Rotation = CFrame.Angles(0, math.rad(Yaw), 0) * CFrame.Angles(math.rad(Pitch), 0, 0)
            local targetCFrame = CFrame.new(TreePosition) * Rotation * CFrame.new(0, 0, Distance)
            
            -- Smoothly interpolate or set directly (using direct for responsiveness)
            Camera.CFrame = CFrame.lookAt(targetCFrame.Position, TreePosition)
        end
    end)
end

return TreeCam

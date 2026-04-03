local TreeCam = {}

function TreeCam.Init(Tab)
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    -- STATE VARIABLES
    _G.LoneTreeCamEnabled = false
    local Camera = Workspace.CurrentCamera
    
    -- The coordinates for the Lone Cave Tree (End Times/Blue Wood area)
    -- Adjust these slightly if the angle isn't to your liking
    local TreeCFrame = CFrame.new(635, -165, 415) 
    local ViewCFrame = CFrame.new(610, -150, 400) -- Positioning the camera back a bit to see the tree

    -- UI SECTION
    Tab:CreateToggle("View Lone Cave Tree", false, function(state)
        _G.LoneTreeCamEnabled = state
        
        if state then
            -- Set camera to Scriptable so we can move it
            Camera.CameraType = Enum.CameraType.Scriptable
        else
            -- Set back to Custom so it follows the player again
            Camera.CameraType = Enum.CameraType.Custom
        end
    end)

    -- MASTER LOGIC
    -- We use RenderStepped to keep the camera locked while the toggle is on
    RunService.RenderStepped:Connect(function()
        if _G.LoneTreeCamEnabled then
            Camera.CFrame = CFrame.lookAt(ViewCFrame.Position, TreeCFrame.Position)
        end
    end)
end

return TreeCam

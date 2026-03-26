local Movement = {}
local Player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

Movement.WalkSpeed = 16
Movement.JumpPower = 50
Movement.Flying = false
Movement.FlySpeed = 50
Movement.FlyKey = Enum.KeyCode.Q

local flyConnection
local onFlyToggleCallback -- Used to update the UI color when pressing 'Q'

function Movement.ToggleFly()
    Movement.Flying = not Movement.Flying
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if Movement.Flying then
        flyConnection = RunService.Heartbeat:Connect(function()
            if not Movement.Flying or not hrp then if flyConnection then flyConnection:Disconnect() end return end
            hrp.Velocity = Vector3.new(0, 0, 0)
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            hrp.CFrame = hrp.CFrame + (moveDir * (Movement.FlySpeed / 50))
        end)
    else
        if flyConnection then flyConnection:Disconnect() end
    end
    
    if onFlyToggleCallback then onFlyToggleCallback(Movement.Flying) end
    return Movement.Flying
end

-- Keybind listener
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Movement.FlyKey then
        Movement.ToggleFly()
    end
end)

function Movement.SetUpdateCallback(func) onFlyToggleCallback = func end

return Movement

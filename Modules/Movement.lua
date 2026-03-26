local Movement = {}
local Player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")

Movement.Sprinting = false
Movement.Flying = false
Movement.FlySpeed = 50

local flyConnection

function Movement.SetSpeed(val)
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.WalkSpeed = val
    end
end

function Movement.SetJump(val)
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.JumpPower = val
        Player.Character.Humanoid.UseJumpPower = true
    end
end

function Movement.ToggleFly()
    Movement.Flying = not Movement.Flying
    local char = Player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if Movement.Flying then
        -- Create a loop to keep the player in the air
        flyConnection = RunService.Heartbeat:Connect(function()
            if not Movement.Flying or not hrp then flyConnection:Disconnect() return end
            hrp.Velocity = Vector3.new(0, 0, 0)
            
            -- Simple Fly Movement logic
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.new(0,0,0)
            
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            
            hrp.CFrame = hrp.CFrame + (moveDir * (Movement.FlySpeed / 100))
        end)
    else
        if flyConnection then flyConnection:Disconnect() end
    end
    return Movement.Flying
end

return Movement

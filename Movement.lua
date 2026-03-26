local Movement = {}
local Player = game.Players.LocalPlayer

function Movement.SetSpeed(value)
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.WalkSpeed = value
    end
end

function Movement.SetJump(value)
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.JumpPower = value
    end
end

return Movement

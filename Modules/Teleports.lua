local Tele = {}
Tele.Locations = {
    {"Spawn", CFrame.new(155, 3, 74)},
    {"Wood R Us", CFrame.new(265, 3, 57)},
    -- ... add the rest of your locations here
}

function Tele.GoTo(cframe)
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = cframe
    end
end

return Tele

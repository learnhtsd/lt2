local PlayPositionNotify = {}

function PlayPositionNotify.Init(Tab, Library)
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer

    Tab:CreateSection("Location Tools")

    Tab:CreateAction("Get Position", "Check Coords", function()
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root then
            local Pos = Root.Position
            -- Rounding to 1 decimal place for a cleaner notification
            local RoundedX = math.floor(Pos.X * 10) / 10
            local RoundedY = math.floor(Pos.Y * 10) / 10
            local RoundedZ = math.floor(Pos.Z * 10) / 10
            
            local CoordString = string.format("X: %s, Y: %s, Z: %s", RoundedX, RoundedY, RoundedZ)
            
            Library:Notify("Current Position", CoordString, 5)
        else
            Library:Notify("Error", "Character or RootPart not found!", 3)
        end
    end)
end

return PlayPositionNotify

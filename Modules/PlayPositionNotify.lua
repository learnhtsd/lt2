local PlayPositionNotify = {}

function PlayPositionNotify.Init(Tab, Library)
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer

    Tab:CreateSection("Location Tools")

    Tab:CreateAction("Get Position", "Check Coords & Copy", function()
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root then
            local Pos = Root.Position
            -- Formats to 1 decimal place and creates the string
            local CoordString = string.format("X: %.1f, Y: %.1f, Z: %.1f", Pos.X, Pos.Y, Pos.Z)
            
            -- Copies the string to your Windows/Mac clipboard
            if setclipboard then
                setclipboard(CoordString)
                Library:Notify("Current Position", "Coordinates copied to clipboard!", 5)
            else
                Library:Notify("Current Position", CoordString, 5)
            end
        else
            Library:Notify("Error", "Character or RootPart not found!", 3)
        end
    end)
end

return PlayPositionNotify

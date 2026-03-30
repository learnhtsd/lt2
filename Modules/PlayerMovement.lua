local Module = {}

function Module.Init(Tab)
    Tab:CreateSlider("WalkSpeed", 16, 250, 16, function(v)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
    end)
    
    Tab:CreateToggle("Infinite Jump", false, function(state)
        -- logic here
    end)
end

return Module -- <--- THIS LINE IS THE MOST IMPORTANT!

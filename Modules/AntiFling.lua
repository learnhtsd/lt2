local AntiFling = {}

function AntiFling.Init(Tab)
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.AntiFlingEnabled = false

    -- ===========================
    -- UI SECTION
    -- ===========================
    Tab:CreateSection("Protections")

    Tab:CreateToggle("Anti-Fling", false, function(state)
        _G.AntiFlingEnabled = state
    end)

    -- ===========================
    -- ANTI-FLING LOGIC
    -- ===========================
    RunService.Stepped:Connect(function()
        if not _G.AntiFlingEnabled then return end

        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    -- Resetting velocity prevents the physics engine from 
                    -- calculating the "impact" force that flings you.
                    part.CanCollide = false 
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end)
end

return AntiFling

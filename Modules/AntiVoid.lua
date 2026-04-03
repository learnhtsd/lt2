local AntiVoid = {}

function AntiVoid.Init(Tab)
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.AntiVoidEnabled = false
    _G.VoidThreshold = -500 -- The Y-level where teleport triggers
    _G.SafeYLevel = 50      -- How high to teleport you back up

    -- ===========================
    -- UI SECTION
    -- ===========================
    Tab:CreateSection("Void Protection")

    Tab:CreateToggle("Enable Anti-Void", false, function(state)
        _G.AntiVoidEnabled = state
    end)

    Tab:CreateSlider("Void Depth", -2000, -100, -500, function(value)
        _G.VoidThreshold = value
    end)

    -- ===========================
    -- ANTI-VOID LOGIC
    -- ===========================
    RunService.Heartbeat:Connect(function()
        if not _G.AntiVoidEnabled then return end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if hrp then
            -- Check if the player has fallen below the threshold
            if hrp.Position.Y < _G.VoidThreshold then
                -- Reset velocity so you don't keep falling after TP
                hrp.AssemblyLinearVelocity = Vector3.zero
                
                -- Teleport back to the center of the map at a safe height
                -- You can change Vector3.new(0, _G.SafeYLevel, 0) to a specific spawn location
                hrp.CFrame = CFrame.new(hrp.Position.X, _G.SafeYLevel, hrp.Position.Z)
            end
        end
    end)
end

return AntiVoid

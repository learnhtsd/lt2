local AntiVoid = {}

function AntiVoid.Init(Tab)
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer


    -- STATE VARIABLES
    _G.AntiVoidEnabled = true
    local VOID_THRESHOLD = -60 -- Hardcoded threshold


    -- HELPER: GET PLOT OR SPAWN
    local function GetSafeDestination()
        -- 1. Try to find the player's plot in LT2
        local properties = workspace:FindFirstChild("Properties")
        if properties then
            for _, plot in ipairs(properties:GetChildren()) do
                local owner = plot:FindFirstChild("Owner")
                if owner and owner.Value == LocalPlayer then
                    local origin = plot:FindFirstChild("Origin")
                    if origin then
                        -- Return the center of the plot, slightly raised
                        return origin.CFrame + Vector3.new(0, 5, 0)
                    end
                end
            end
        end

        -- 2. Fallback to Baseplate/Spawn area if no plot found
        return CFrame.new(0, 10, 0) 
    end


    -- UI SECTION
    Tab:CreateToggle("Enable Anti-Void", true, function(state)
        _G.AntiVoidEnabled = state
    end)


    -- MASTER LOGIC
    RunService.Heartbeat:Connect(function()
        if not _G.AntiVoidEnabled then return end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        -- Check against the fixed -60 threshold
        if hrp and hrp.Position.Y < VOID_THRESHOLD then
            -- Stop all falling momentum immediately
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            
            -- Automatically find where to go and warp
            hrp.CFrame = GetSafeDestination()
        end
    end)
end

return AntiVoid

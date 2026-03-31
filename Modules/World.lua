local World = {}

function World.Init(Tab)
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace.Terrain

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.TimeOfDay = 12
    _G.TimeLock = false
    _G.ShadowsEnabled = true
    _G.FogEnabled = true
    _G.WaterEnabled = true
    _G.FullBright = false
    _G.PostProcessing = true

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Lighting & Time")

    Tab:CreateSlider("Time of Day", 0, 24, 12, function(v)
        _G.TimeOfDay = v
        Lighting.ClockTime = v
    end)

    Tab:CreateToggle("Time Lock", false, function(s)
        _G.TimeLock = s
    end)

    Tab:CreateToggle("Full Bright", false, function(s)
        _G.FullBright = s
        if not s then
            -- Reset to a neutral state when turned off
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.fromRGB(0, 0, 0)
            Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        end
    end)

    Tab:CreateToggle("Shadows", true, function(s)
        _G.ShadowsEnabled = s
    end)

    Tab:CreateToggle("Fog", true, function(s)
        _G.FogEnabled = s
    end)

    Tab:CreateSection("Environment & Effects")

    Tab:CreateToggle("Post-Processing Effects", true, function(s)
        _G.PostProcessing = s
    end)

    Tab:CreateToggle("Water Visibility", true, function(s)
        _G.WaterEnabled = s
        if s then
            Terrain.WaterTransparency = 1
            Terrain.WaterWaveSize = 0.15
            Terrain.WaterWaveSpeed = 10
        end
    end)

    -- ===========================
    -- MASTER LOOP (FORCE SETTINGS)
    -- ===========================
    RunService.RenderStepped:Connect(function()
        -- Force Time
        if _G.TimeLock then
            Lighting.ClockTime = _G.TimeOfDay
        end

        -- Force Full Bright
        if _G.FullBright then
            Lighting.Brightness = 2
            Lighting.ClockTime = _G.TimeOfDay
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        end

        -- Force Shadows
        if Lighting.GlobalShadows ~= _G.ShadowsEnabled then
            Lighting.GlobalShadows = _G.ShadowsEnabled
        end

        -- Force Fog Removal
        if not _G.FogEnabled then
            Lighting.FogEnd = 1000000
            Lighting.FogStart = 0
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0 end
        end

        -- Force Water Removal
        if not _G.WaterEnabled then
            Terrain.WaterTransparency = 1
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
        end

        -- Force Post-Processing Removal (Blur, Bloom, etc)
        if not _G.PostProcessing then
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostProcessEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") then
                    effect.Enabled = false
                end
            end
        else
            -- Optional: If you want to re-enable them when the toggle is on, 
            -- you'd need a more complex system to track which ones were originally on.
        end
    end)
end

return World

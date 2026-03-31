local World = {}

function World.Init(Tab)
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace.Terrain

    -- ===========================
    -- SAVE ORIGINAL STATES
    -- ===========================
    -- We save these when the script first injects so we can restore them later
    local originalFogEnd = Lighting.FogEnd
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    local originalAtmosphereParent = atmosphere and atmosphere.Parent or nil

    local originalWaterTransparency = Terrain.WaterTransparency
    local originalWaterReflectance = Terrain.WaterReflectance

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.TimeOfDay = 12
    _G.TimeLock = false
    _G.ShadowsEnabled = true
    _G.FogEnabled = true
    _G.WaterEnabled = true

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Lighting & Time")

    -- Time of Day Slider (0-24, Default 12)
    Tab:CreateSlider("Time of Day", 0, 24, 12, function(v)
        _G.TimeOfDay = v
        -- If time isn't locked, just change it once
        if not _G.TimeLock then
            Lighting.ClockTime = v
        end
    end)

    -- Time Lock Toggle
    Tab:CreateToggle("Time Lock", false, function(s)
        _G.TimeLock = s
        if s then
            Lighting.ClockTime = _G.TimeOfDay
        end
    end)

    -- Shadows Toggle (Default On)
    Tab:CreateToggle("Shadows", true, function(s)
        _G.ShadowsEnabled = s
        Lighting.GlobalShadows = s
    end)

    -- Fog Toggle (Default On)
    Tab:CreateToggle("Fog", true, function(s)
        _G.FogEnabled = s
        if s then
            -- Restore original fog
            Lighting.FogEnd = originalFogEnd
            if atmosphere then atmosphere.Parent = originalAtmosphereParent end
        else
            -- Remove fog
            Lighting.FogEnd = 1000000
            if atmosphere then atmosphere.Parent = nil end
        end
    end)

    Tab:CreateSection("Environment")

    -- Water Toggle (Default On)
    Tab:CreateToggle("Water Visibility", true, function(s)
        _G.WaterEnabled = s
        if s then
            -- Restore original water
            Terrain.WaterTransparency = originalWaterTransparency
            Terrain.WaterReflectance = originalWaterReflectance
        else
            -- Make water completely invisible
            Terrain.WaterTransparency = 1
            Terrain.WaterReflectance = 0
        end
    end)

    -- ===========================
    -- MASTER LOOP
    -- ===========================
    RunService.RenderStepped:Connect(function()
        -- Constantly force the time if Time Lock is enabled
        if _G.TimeLock then
            Lighting.ClockTime = _G.TimeOfDay
        end
    end)
end

return World

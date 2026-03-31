local World = {}

function World.Init(Tab)
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace.Terrain

    -- ===========================
    -- STATE & CACHE
    -- ===========================
    _G.TimeOfDay = 12
    _G.TimeLock = false
    _G.FullBright = false
    _G.ShadowsEnabled = true
    _G.FogEnabled = true
    _G.WaterEnabled = true
    _G.PostProcessing = true

    -- Store original states for Post-Processing
    local effectCache = {}
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostProcessEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") then
            effectCache[effect] = effect.Enabled
        end
    end

    -- ===========================
    -- FUNCTIONS
    -- ===========================
    local function ToggleWater(state)
        if state then
            -- Restore Water: Replace Air back to Water in a huge radius
            -- Note: This only restores water where it originally was if the game uses standard voxels
            Terrain:ReplaceMaterial(Region3int16.new(Vector3int16.new(-32000, -500, -32000), Vector3int16.new(32000, 500, 32000)), 4, Enum.Material.Air, Enum.Material.Water)
            Terrain.WaterTransparency = 1
        else
            -- Remove Water: Replace all Water with Air (This stops the "Swimming" state/damage)
            Terrain:ReplaceMaterial(Region3int16.new(Vector3int16.new(-32000, -500, -32000), Vector3int16.new(32000, 500, 32000)), 4, Enum.Material.Water, Enum.Material.Air)
        end
    end

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Lighting & Time")

    Tab:CreateSlider("Time of Day", 0, 24, 12, function(v)
        _G.TimeOfDay = v
        Lighting.ClockTime = v
    end)

    Tab:CreateToggle("Time Lock", false, function(s) _G.TimeLock = s end)
    
    Tab:CreateToggle("Full Bright", false, function(s) 
        _G.FullBright = s 
        if not s then
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.fromRGB(127, 127, 127)
            Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        end
    end)

    Tab:CreateToggle("Shadows", true, function(s) _G.ShadowsEnabled = s end)
    Tab:CreateToggle("Fog", true, function(s) _G.FogEnabled = s end)

    Tab:CreateSection("Environment")

    Tab:CreateToggle("Post-Processing", true, function(s)
        _G.PostProcessing = s
        for effect, originalState in pairs(effectCache) do
            if s then
                effect.Enabled = originalState
            else
                effect.Enabled = false
            end
        end
    end)

    Tab:CreateToggle("Water Enabled", true, function(s)
        _G.WaterEnabled = s
        ToggleWater(s)
    end)

    -- ===========================
    -- MASTER LOOP
    -- ===========================
    RunService.RenderStepped:Connect(function()
        if _G.TimeLock then Lighting.ClockTime = _G.TimeOfDay end
        
        if _G.FullBright then
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 2
        end

        if Lighting.GlobalShadows ~= _G.ShadowsEnabled then
            Lighting.GlobalShadows = _G.ShadowsEnabled
        end

        if not _G.FogEnabled then
            Lighting.FogEnd = 1e6
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0 end
        end
    end)
end

return World

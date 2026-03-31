local World = {}

function World.Init(Tab, Lib) -- Added Lib for notifications
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

    local effectCache = {}
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostProcessEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") then
            effectCache[effect] = effect.Enabled
        end
    end

    -- ===========================
    -- FIXED WATER FUNCTION
    -- ===========================
    local function ToggleWater(state)
        -- 1. Handle Terrain Water (The ocean/river voxels)
        if state then
            Terrain:ReplaceMaterial(Region3int16.new(Vector3int16.new(-32000, -500, -32000), Vector3int16.new(32000, 500, 32000)), 4, Enum.Material.Air, Enum.Material.Water)
        else
            Terrain:ReplaceMaterial(Region3int16.new(Vector3int16.new(-32000, -500, -32000), Vector3int16.new(32000, 500, 32000)), 4, Enum.Material.Water, Enum.Material.Air)
        end

        -- 2. Handle Part Water (The physical "Water" parts you identified)
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "Water" then
                if state then
                    -- Restore Water Parts
                    obj.Transparency = 0.8 -- Or whatever the original was
                    obj.CanCollide = false
                    obj.CanTouch = true -- Re-enables damage/swimming
                else
                    -- Disable Water Parts
                    obj.Transparency = 1
                    obj.CanCollide = false
                    obj.CanTouch = false -- STOPS the lava/water damage script from firing
                end
            end
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
            effect.Enabled = s and originalState or false
        end
    end)

    Tab:CreateToggle("Water Enabled", true, function(s)
        _G.WaterEnabled = s
        ToggleWater(s)
        
        if Lib and Lib.Notify then
            Lib:Notify("Environment", s and "Water restored." or "Water & Hazards disabled!", 3)
        end
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

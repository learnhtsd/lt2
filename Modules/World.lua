local World = {}

function World.Init(Tab, Lib)
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

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

    local waterParts = {}
    local effectCache = {}

    -- Pre-scan for Water parts and Post-Processing effects
    local function ScanWorld()
        waterParts = {} -- Reset
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "Water" then
                -- Store original transparency to restore it correctly later
                table.insert(waterParts, {Instance = obj, OriginalTransparency = obj.Transparency})
            end
        end

        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostProcessEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") then
                effectCache[effect] = effect.Enabled
            end
        end
    end

    -- Run initial scan
    ScanWorld()

    -- ===========================
    -- TOGGLE LOGIC
    -- ===========================
    local function ToggleWater(state)
        for _, data in pairs(waterParts) do
            local part = data.Instance
            if part and part.Parent then
                if state then
                    -- Restore Water
                    part.Transparency = data.OriginalTransparency
                    part.CanCollide = false -- Usually water is non-collidable anyway
                    part.CanTouch = true    -- Allows swimming/damage scripts to work
                else
                    -- Disable Water
                    part.Transparency = 1
                    part.CanCollide = false
                    part.CanTouch = false   -- This prevents "Touch" events (like drowning/lava scripts)
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
            if effect then
                effect.Enabled = s and originalState or false
            end
        end
    end)

    Tab:CreateToggle("Water Enabled", true, function(s)
        _G.WaterEnabled = s
        ToggleWater(s)
        
        if Lib and Lib.Notify then
            Lib:Notify("Environment", s and "Water restored." or "Water disabled!", 3)
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

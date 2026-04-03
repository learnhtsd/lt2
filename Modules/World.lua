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
    _G.BouldersRemoved = false -- NEW
    _G.PostProcessing = true

    local waterParts = {}
    local boulderParts = {} -- NEW
    local effectCache = {}

    -- Pre-scan for Water, Boulders, and Post-Processing effects
    local function ScanWorld()
        waterParts = {}
        boulderParts = {} -- Reset
        
        for _, obj in pairs(Workspace:GetDescendants()) do
            -- Cache Water
            if obj:IsA("BasePart") and obj.Name == "Water" then
                table.insert(waterParts, {Instance = obj, OriginalTransparency = obj.Transparency})
            end
            
            -- Cache Boulders (LT2 Specific)
            if obj:IsA("BasePart") and (obj.Name == "Boulder" or obj.Name == "SmallBoulder") then
                table.insert(boulderParts, {Instance = obj, OriginalTransparency = obj.Transparency})
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
                part.Transparency = state and data.OriginalTransparency or 1
                part.CanCollide = false
                part.CanTouch = state -- Disables drowning/lava logic when water is "off"
            end
        end
    end

    local function ToggleBoulders(state) -- NEW logic
        for _, data in pairs(boulderParts) do
            local part = data.Instance
            if part and part.Parent then
                if state then
                    -- "Remove" Boulders
                    part.Transparency = 1
                    part.CanCollide = false
                else
                    -- Restore Boulders
                    part.Transparency = data.OriginalTransparency
                    part.CanCollide = true
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
    end)

    -- NEW TOGGLE FOR BOULDERS
    Tab:CreateToggle("Toggle Tundra Boulders", false, function(s)
        _G.BouldersRemoved = s
        ToggleBoulders(s)
        
        if Lib and Lib.Notify then
            Lib:Notify("Environment", s and "Boulders cleared!" or "Boulders restored.", 3)
        end
    end)
    Tab:CreateToggle("Toggle Volcano Boulders", false, function(s)
            _G.VolcanoBouldersRemoved = s
            -- 1. Handle Static Crater Boulders (The ones in your photo)
            for _, data in pairs(volcanoCraterParts) do
                if data.Instance and data.Instance.Parent then
                    data.Instance.Transparency = s and 1 or data.OriginalTransparency
                    data.Instance.CanCollide = not s
                    -- Sink them so they don't burn your truck
                    if s then
                        data.Instance.CFrame = data.Instance.CFrame * CFrame.new(0, -500, 0)
                    else
                        -- To restore perfectly, we'd need to cache CFrames, 
                        -- but usually, a simple vertical move back works:
                        data.Instance.CFrame = data.Instance.CFrame * CFrame.new(0, 500, 0)
                    end
                end
            end
            
            if Lib and Lib.Notify then
                Lib:Notify("Environment", s and "Volcano cleared!" or "Volcano restored.", 3)
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

        -- 2. Handle DYNAMIC Rolling Boulders (The ones that spawn later)
        if _G.VolcanoBouldersRemoved then
            for _, obj in pairs(Workspace:GetChildren()) do
                if obj.Name == "Boulder" and (obj:FindFirstChild("LavaLight") or obj:FindFirstChild("Fire")) then
                    obj.CanCollide = false
                    obj.Transparency = 1
                    if obj:IsA("BasePart") then
                        obj.CFrame = obj.CFrame * CFrame.new(0, -500, 0) 
                    end
                end
            end
        end
    end)
end

return World

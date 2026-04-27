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
    _G.BouldersRemoved = false 
    _G.VolcanoBouldersRemoved = false
    _G.PostProcessing = true

    local waterParts = {}
    local boulderParts = {} 
    local effectCache = {}

    -- IMPROVED: Incremental Scan to prevent freezing
    local function ScanWorld()
        waterParts = {}
        boulderParts = {}
        
        -- Using a localized reference is slightly faster in Luau
        local descendants = workspace:GetDescendants()
        local total = #descendants
        
        -- Process in batches to maintain high FPS
        local BATCH_SIZE = 1000 
        
        for i = 1, total do
            local obj = descendants[i]
            
            -- Yield logic: process BATCH_SIZE items then wait for the next frame
            if i % BATCH_SIZE == 0 then 
                task.wait() 
            end
    
            -- Use ClassName check (faster than IsA for simple types)
            if obj.ClassName == "Part" or obj.ClassName == "MeshPart" or obj.ClassName == "WedgePart" then
                local name = obj.Name
                
                if name == "Water" then
                    table.insert(waterParts, {Instance = obj, OriginalTransparency = obj.Transparency})
                elseif name == "Boulder" or name == "SmallBoulder" then
                    -- Optimization: only check children if the name matches
                    if not (obj:FindFirstChild("LavaLight") or obj:FindFirstChild("Fire")) then
                        table.insert(boulderParts, {Instance = obj, OriginalTransparency = obj.Transparency})
                    end
                end
            end
        end
    
        -- Lighting Scan (Much smaller, usually doesn't need yielding)
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostProcessEffect") then -- Covers Blur, Bloom, etc.
                effectCache[effect] = effect.Enabled
            end
        end
        
        if Lib and Lib.Notify then
            Lib:Notify("System", "World Scan Complete!", 2)
        end
    end

    -- Run initial scan in a separate thread so it doesn't block the UI loading
    task.spawn(ScanWorld)

    -- ===========================
    -- TOGGLE LOGIC
    -- ===========================
    local function ToggleWater(state)
        for _, data in pairs(waterParts) do
            local part = data.Instance
            if part and part.Parent then
                part.Transparency = state and data.OriginalTransparency or 1
                part.CanCollide = false
                part.CanTouch = state 
            end
        end
    end

    local function ToggleBoulders(state)
        for _, data in pairs(boulderParts) do
            local part = data.Instance
            if part and part.Parent then
                part.Transparency = state and 1 or data.OriginalTransparency
                part.CanCollide = not state
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

    Tab:CreateToggle("Toggle Tundra Boulders", false, function(s)
        _G.BouldersRemoved = s
        ToggleBoulders(s)
        if Lib and Lib.Notify then Lib:Notify("Environment", s and "Boulders cleared!" or "Boulders restored.", 3) end
    end)

    Tab:CreateToggle("Toggle Volcano Boulders", false, function(s)
        _G.VolcanoBouldersRemoved = s
        if Lib and Lib.Notify then Lib:Notify("Environment", s and "Volcano bypass active!" or "Volcano restored.", 3) end
    end)

    -- ===========================
    -- MASTER LOOP (Optimized)
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

        -- DYNAMIC Boulders logic
        if _G.VolcanoBouldersRemoved then
            for _, obj in pairs(Workspace:GetChildren()) do
                if obj.Name == "Boulder" and (obj:FindFirstChild("LavaLight") or obj:FindFirstChild("Fire")) then
                    if obj:IsA("BasePart") and obj.CanCollide == true then
                        obj.CanCollide = false
                        obj.Transparency = 1
                        -- Move them far away so they don't hit the player
                        obj.CFrame = obj.CFrame * CFrame.new(0, -1000, 0) 
                    end
                end
            end
        end
    end)
end

return World

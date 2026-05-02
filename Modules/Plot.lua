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
    _G.SpookEvent = false
    _G.EnhancedGraphics = false

    local waterParts = {}
    local boulderParts = {}
    local volcanoBoulderParts = {}  -- Cached separately so RenderStepped never scans
    local effectCache = {}
    local originalLightingSettings = {}

    -- Dirty flags — prevent redundant property writes every frame
    local lastFullBright = false
    local lastShadows = true
    local lastFogEnabled = true

    -- Bridge Backup for Resetting
    local bridgeBackup = nil
    if Workspace:FindFirstChild("Bridge") then
        bridgeBackup = Workspace.Bridge:Clone()
    end

    -- ===========================
    -- WORLD SCAN (run once at startup)
    -- ===========================
    local function ScanWorld()
        waterParts = {}
        boulderParts = {}
        volcanoBoulderParts = {}

        local descendants = Workspace:GetDescendants()
        local count = 0

        for _, obj in pairs(descendants) do
            count = count + 1
            if count % 500 == 0 then task.wait() end

            if obj:IsA("BasePart") then
                if obj.Name == "Water" then
                    table.insert(waterParts, { Instance = obj, OriginalTransparency = obj.Transparency })

                elseif obj.Name == "Boulder" or obj.Name == "SmallBoulder" then
                    local isVolcano = obj:FindFirstChild("LavaLight") or obj:FindFirstChild("Fire")
                    if isVolcano then
                        table.insert(volcanoBoulderParts, { Instance = obj, OriginalTransparency = obj.Transparency, OriginalCFrame = obj.CFrame, OriginalCanCollide = obj.CanCollide })
                    else
                        table.insert(boulderParts, { Instance = obj, OriginalTransparency = obj.Transparency })
                    end
                end
            end
        end

        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostProcessEffect") or effect:IsA("BlurEffect")
                or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect")
                or effect:IsA("SunRaysEffect") then
                effectCache[effect] = effect.Enabled
            end
        end

        if Lib and Lib.Notify then
            Lib:Notify("System", "World Scan Complete!", 2)
        end
    end

    task.spawn(ScanWorld)

    -- ===========================
    -- BRIDGE LOGIC
    -- ===========================
    local function ToggleBridge(state)
        if state then
            local bridge = Workspace:FindFirstChild("Bridge")
            if bridge then
                local vlb = bridge:FindFirstChild("VerticalLiftBridge")
                local lift = vlb and vlb:FindFirstChild("Lift")

                if lift then
                    for _, child in pairs(lift:GetChildren()) do
                        if child:IsA("BasePart") and child.Name == "Base" then
                            child.CFrame = CFrame.new(child.Position.X, 6.5, child.Position.Z) * child.CFrame.Rotation
                        end
                    end
                end

                if vlb then
                    local targets = { "BRope", "Structure", "Weight", "WRope" }
                    for _, child in pairs(vlb:GetChildren()) do
                        if table.find(targets, child.Name) then child:Destroy() end
                    end
                end
            end
        else
            if bridgeBackup then
                if Workspace:FindFirstChild("Bridge") then Workspace.Bridge:Destroy() end
                local restoredBridge = bridgeBackup:Clone()
                restoredBridge.Parent = Workspace
            end
        end
    end

    -- ===========================
    -- ENHANCED VISUALS LOGIC
    -- ===========================
    local function ToggleEnhanced(state)
        if state then
            originalLightingSettings.Brightness = Lighting.Brightness
            originalLightingSettings.OutdoorAmbient = Lighting.OutdoorAmbient
            originalLightingSettings.ExposureCompensation = Lighting.ExposureCompensation

            Lighting.Brightness = 3
            Lighting.ExposureCompensation = 0.5

            local bloom = Lighting:FindFirstChild("EnhancedBloom") or Instance.new("BloomEffect", Lighting)
            bloom.Name = "EnhancedBloom"
            bloom.Intensity = 1
            bloom.Size = 24
            bloom.Threshold = 2
            bloom.Enabled = true

            local cc = Lighting:FindFirstChild("EnhancedCC") or Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "EnhancedCC"
            cc.Contrast = 0.1
            cc.Saturation = 0.15
            cc.TintColor = Color3.fromRGB(255, 253, 245)
            cc.Enabled = true

            local sunrays = Lighting:FindFirstChild("EnhancedRays") or Instance.new("SunRaysEffect", Lighting)
            sunrays.Name = "EnhancedRays"
            sunrays.Intensity = 0.1
            sunrays.Spread = 1
            sunrays.Enabled = true
        else
            Lighting.Brightness = originalLightingSettings.Brightness or 2
            Lighting.ExposureCompensation = originalLightingSettings.ExposureCompensation or 0

            if Lighting:FindFirstChild("EnhancedBloom") then Lighting.EnhancedBloom.Enabled = false end
            if Lighting:FindFirstChild("EnhancedCC") then Lighting.EnhancedCC.Enabled = false end
            if Lighting:FindFirstChild("EnhancedRays") then Lighting.EnhancedRays.Enabled = false end
        end
    end

    -- ===========================
    -- TOGGLE FUNCTIONS
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

    -- Uses the cached list — no per-frame scanning needed
    local function ToggleVolcanoBoulders(state)
        for _, data in pairs(volcanoBoulderParts) do
            local part = data.Instance
            if part and part.Parent then
                if state then
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CFrame = data.OriginalCFrame * CFrame.new(0, -1000, 0)
                else
                    part.CanCollide = data.OriginalCanCollide
                    part.Transparency = data.OriginalTransparency
                    part.CFrame = data.OriginalCFrame
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

    Tab:CreateToggle("Enhanced Visuals", false, function(s)
        _G.EnhancedGraphics = s
        ToggleEnhanced(s)
        if Lib and Lib.Notify then Lib:Notify("Graphics", s and "Visuals Enhanced!" or "Visuals reset.", 3) end
    end)

    Tab:CreateToggle("Spook Event", false, function(s)
        _G.SpookEvent = s
        local spook = Lighting:FindFirstChild("Spook")
        if spook then
            spook.Value = s
        else
            if Lib and Lib.Notify then Lib:Notify("Error", "Spook object not found in Lighting!", 3) end
        end
    end)

    Tab:CreateToggle("Post-Processing", true, function(s)
        _G.PostProcessing = s
        for effect, originalState in pairs(effectCache) do
            if effect then effect.Enabled = s and originalState or false end
        end
    end)

    Tab:CreateToggle("Water Enabled", true, function(s)
        _G.WaterEnabled = s
        ToggleWater(s)
    end)

    Tab:CreateToggle("Lower Bridge", false, function(s)
        _G.BridgeDown = s
        ToggleBridge(s)
        if Lib and Lib.Notify then
            Lib:Notify("Map", s and "Bridge lowered and cleaned!" or "Bridge reset to original.", 3)
        end
    end)

    Tab:CreateToggle("Toggle Tundra Boulders", false, function(s)
        _G.BouldersRemoved = s
        ToggleBoulders(s)
    end)

    Tab:CreateToggle("Toggle Volcano Boulders", false, function(s)
        _G.VolcanoBouldersRemoved = s
        ToggleVolcanoBoulders(s)
    end)

    -- ===========================
    -- MASTER LOOP (kept lean — no scanning, no redundant writes)
    -- ===========================
    RunService.RenderStepped:Connect(function()
        -- Time lock
        if _G.TimeLock then
            Lighting.ClockTime = _G.TimeOfDay
        end

        -- Full bright — only write when state actually changed
        if _G.FullBright ~= lastFullBright then
            lastFullBright = _G.FullBright
            if _G.FullBright then
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.Brightness = 2
            end
            -- The toggle's off-branch already resets ambient, nothing extra needed here
        end

        -- Shadows — only write on change
        if _G.ShadowsEnabled ~= lastShadows then
            lastShadows = _G.ShadowsEnabled
            Lighting.GlobalShadows = _G.ShadowsEnabled
        end

        -- Fog — only write on change
        if _G.FogEnabled ~= lastFogEnabled then
            lastFogEnabled = _G.FogEnabled
            if not _G.FogEnabled then
                Lighting.FogEnd = 1e6
                local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                if atm then atm.Density = 0 end
            else
                -- Let the game restore fog naturally; could store originals here if needed
                Lighting.FogEnd = 100000
            end
        end
    end)
end

return World

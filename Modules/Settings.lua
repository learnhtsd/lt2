local SettingsModule = {}
local CoreGui      = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
_G.NexusConnections = _G.NexusConnections or {}

-- ── Theme presets ────────────────────────────────────────────
local ThemePresets = {
    Default = {
        Accent          = Color3.fromRGB(74,  120, 255),
        Background      = Color3.fromRGB(18,  18,  22),
        Surface         = Color3.fromRGB(24,  24,  29),
        SurfaceDeep     = Color3.fromRGB(35,  35,  42),
        Sidebar         = Color3.fromRGB(14,  14,  17),
        Stroke          = Color3.fromRGB(40,  40,  48),
        TextPrimary     = Color3.fromRGB(220, 220, 220),
        TextSecondary   = Color3.fromRGB(120, 120, 130),
        TextDark        = Color3.fromRGB(180, 180, 180),
        TextWhite       = Color3.fromRGB(255, 255, 255),
        Success         = Color3.fromRGB(45,  160,  75),
        Warning         = Color3.fromRGB(190, 120,  15),
        NotifBackground = Color3.fromRGB(24,  24,  29),
    },
    Midnight = {
        Accent          = Color3.fromRGB(140,  80, 255),
        Background      = Color3.fromRGB(10,  10,  15),
        Surface         = Color3.fromRGB(16,  16,  22),
        SurfaceDeep     = Color3.fromRGB(25,  25,  35),
        Sidebar         = Color3.fromRGB(8,    8,  12),
        Stroke          = Color3.fromRGB(35,  35,  55),
        TextPrimary     = Color3.fromRGB(210, 210, 230),
        TextSecondary   = Color3.fromRGB(110, 110, 140),
        TextDark        = Color3.fromRGB(170, 170, 200),
        TextWhite       = Color3.fromRGB(255, 255, 255),
        Success         = Color3.fromRGB(45,  160,  75),
        Warning         = Color3.fromRGB(190, 120,  15),
        NotifBackground = Color3.fromRGB(16,  16,  22),
    },
    Emerald = {
        Accent          = Color3.fromRGB(40,  200, 120),
        Background      = Color3.fromRGB(12,  20,  16),
        Surface         = Color3.fromRGB(18,  28,  22),
        SurfaceDeep     = Color3.fromRGB(28,  40,  32),
        Sidebar         = Color3.fromRGB(10,  16,  12),
        Stroke          = Color3.fromRGB(30,  55,  40),
        TextPrimary     = Color3.fromRGB(200, 230, 210),
        TextSecondary   = Color3.fromRGB(100, 150, 120),
        TextDark        = Color3.fromRGB(160, 200, 175),
        TextWhite       = Color3.fromRGB(255, 255, 255),
        Success         = Color3.fromRGB(40,  200, 120),
        Warning         = Color3.fromRGB(190, 120,  15),
        NotifBackground = Color3.fromRGB(18,  28,  22),
    },
    Crimson = {
        Accent          = Color3.fromRGB(220,  55,  55),
        Background      = Color3.fromRGB(20,  12,  12),
        Surface         = Color3.fromRGB(28,  18,  18),
        SurfaceDeep     = Color3.fromRGB(40,  25,  25),
        Sidebar         = Color3.fromRGB(16,   9,   9),
        Stroke          = Color3.fromRGB(55,  30,  30),
        TextPrimary     = Color3.fromRGB(230, 210, 210),
        TextSecondary   = Color3.fromRGB(150, 100, 100),
        TextDark        = Color3.fromRGB(200, 170, 170),
        TextWhite       = Color3.fromRGB(255, 255, 255),
        Success         = Color3.fromRGB(45,  160,  75),
        Warning         = Color3.fromRGB(190, 120,  15),
        NotifBackground = Color3.fromRGB(28,  18,  18),
    },
    Slate = {
        Accent          = Color3.fromRGB(160, 165, 180),
        Background      = Color3.fromRGB(22,  23,  26),
        Surface         = Color3.fromRGB(30,  31,  36),
        SurfaceDeep     = Color3.fromRGB(42,  43,  50),
        Sidebar         = Color3.fromRGB(16,  17,  20),
        Stroke          = Color3.fromRGB(48,  50,  60),
        TextPrimary     = Color3.fromRGB(215, 216, 220),
        TextSecondary   = Color3.fromRGB(115, 118, 130),
        TextDark        = Color3.fromRGB(175, 177, 185),
        TextWhite       = Color3.fromRGB(255, 255, 255),
        Success         = Color3.fromRGB(45,  160,  75),
        Warning         = Color3.fromRGB(190, 120,  15),
        NotifBackground = Color3.fromRGB(30,  31,  36),
    },
}

local AccentPresets = {
    Blue   = Color3.fromRGB(74,  120, 255),
    Purple = Color3.fromRGB(140,  80, 255),
    Teal   = Color3.fromRGB(40,  180, 160),
    Green  = Color3.fromRGB(60,  180,  80),
    Red    = Color3.fromRGB(220,  60,  60),
    Orange = Color3.fromRGB(220, 130,  30),
    Pink   = Color3.fromRGB(220,  80, 160),
    White  = Color3.fromRGB(200, 200, 200),
}

-- ── Helper: repaint all live descendants ─────────────────────
local function ApplyTheme(T, MainFrame, SidebarFrame)
    local hub = CoreGui:FindFirstChild("DynxeLT2Hub")
    if not hub then return end
    for _, obj in ipairs(hub:GetDescendants()) do
        if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("ScrollingFrame") then
            if obj.BackgroundTransparency < 1 then
                local c = obj.BackgroundColor3
                -- Match to old theme values and remap
                for key, color in pairs(T) do
                    if typeof(color) == "Color3" and c == color then
                        -- already current, skip
                    end
                end
            end
        end
    end
    -- Targeted repaints for known structural elements
    if MainFrame then
        MainFrame.BackgroundColor3 = T.Background
    end
    if SidebarFrame then
        SidebarFrame.BackgroundColor3 = T.Sidebar
        for _, child in ipairs(SidebarFrame:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundColor3 = T.Sidebar
            end
        end
    end
end

function SettingsModule.Init(Tab, MainUI, RepoConfig, Config)
    local ScreenGui, MainFrame, SidebarFrame
    if typeof(MainUI) == "table" then
        ScreenGui   = MainUI.UI
        MainFrame   = MainUI.Frame
        SidebarFrame = MainUI.Sidebar
    elseif typeof(MainUI) == "Instance" then
        ScreenGui = MainUI
    end
    if not ScreenGui or not ScreenGui.Parent then
        ScreenGui = CoreGui:FindFirstChild("DynxeLT2Hub")
    end

    local T = Config and Config.Theme
    local W = Config and Config.Window
    local E = Config and Config.Elements

    -- ════════════════════════════════════════════════════════
    -- APPEARANCE
    -- ════════════════════════════════════════════════════════
    if Config and MainFrame then

        -- ── Theme Presets ─────────────────────────────────────
        Tab:CreateSection("Theme")

        local presetNames = {}
        for name in pairs(ThemePresets) do table.insert(presetNames, name) end
        table.sort(presetNames)

        Tab:CreateDropdown("Theme Preset", presetNames, "Default", function(selected)
            local preset = ThemePresets[selected]
            if not preset then return end
            -- Copy all values into live Config.Theme
            for key, color in pairs(preset) do
                T[key] = color
            end
            ApplyTheme(T, MainFrame, SidebarFrame)
        end):AddTooltip("Applies a complete color theme. Reload for full element coverage.")

        -- ── Accent Color ───────────────────────────────────────
        Tab:CreateSection("Accent Color")

        local accentNames = {}
        for name in pairs(AccentPresets) do table.insert(accentNames, name) end
        table.sort(accentNames)

        Tab:CreateDropdown("Accent Preset", accentNames, "Blue", function(selected)
            local color = AccentPresets[selected]
            if not color then return end
            T.Accent = color
            -- Best-effort live repaint of accent-colored elements
            local hub = CoreGui:FindFirstChild("DynxeLT2Hub")
            if hub then
                for _, obj in ipairs(hub:GetDescendants()) do
                    if obj:IsA("TextLabel") and obj.Name ~= "TabIconText" then
                        if obj.TextColor3 == T.Accent then obj.TextColor3 = color end
                    end
                    if obj:IsA("UIStroke") and obj.Color == T.Accent then
                        obj.Color = color
                    end
                    if obj:IsA("Frame") and obj.BackgroundColor3 == T.Accent then
                        TweenService:Create(obj, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
                    end
                end
            end
            T.Accent = color
        end):AddTooltip("Changes the accent highlight color. New elements reflect immediately.")

        -- ── Window Size ───────────────────────────────────────
        Tab:CreateSection("Window Size")

        Tab:CreateSlider("Width", 300, 800, W.Width, function(val)
            W.Width = val
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                Size     = UDim2.new(0, val, 0, W.Height),
                Position = UDim2.new(0.5, -math.floor(val / 2), 0.5, -math.floor(W.Height / 2))
            }):Play()
        end):AddTooltip("Total menu width in pixels.")

        Tab:CreateSlider("Height", 150, 600, W.Height, function(val)
            W.Height = val
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                Size     = UDim2.new(0, W.Width, 0, val),
                Position = UDim2.new(0.5, -math.floor(W.Width / 2), 0.5, -math.floor(val / 2))
            }):Play()
        end):AddTooltip("Total menu height in pixels.")

        Tab:CreateSlider("Sidebar Width", 20, 80, W.SidebarWidth, function(val)
            W.SidebarWidth = val
            if SidebarFrame then
                TweenService:Create(SidebarFrame, TweenInfo.new(0.2), {
                    Size = UDim2.new(0, val, 1, 0)
                }):Play()
            end
        end):AddTooltip("Width of the icon sidebar in pixels.")

        -- ── Element Scale ─────────────────────────────────────
        Tab:CreateSection("Element Scale")

        Tab:CreateDropdown("Scale Preset", {"Compact (0.65)", "Default (0.75)", "Normal (1.0)", "Large (1.25)"}, "Default (0.75)", function(selected)
            local map = {
                ["Compact (0.65)"] = 0.65,
                ["Default (0.75)"] = 0.75,
                ["Normal (1.0)"]   = 1.0,
                ["Large (1.25)"]   = 1.25,
            }
            if map[selected] then
                E.Scale = map[selected]
            end
        end):AddTooltip("Changes row height, font size, and padding. Requires a Reload to take full effect.")

        -- ── Opacity ───────────────────────────────────────────
        Tab:CreateSection("Opacity")

        Tab:CreateSlider("Menu Opacity", 0, 100, 85, function(val)
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                BackgroundTransparency = 1 - (val / 100)
            }):Play()
        end):AddTooltip("How opaque the menu background is. 100 = fully solid.")

    end

    -- ════════════════════════════════════════════════════════
    -- INTERFACE
    -- ════════════════════════════════════════════════════════
    Tab:CreateSection("Interface")

    Tab:CreateKeybind("Toggle Menu", Enum.KeyCode.LeftAlt, function()
        if ScreenGui then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end):AddTooltip("Hotkey to show/hide the menu.")

    -- ════════════════════════════════════════════════════════
    -- SYSTEM
    -- ════════════════════════════════════════════════════════
    Tab:CreateSection("System")

    local function Unload()
        _G.NexusActive = false
        for _, conn in pairs(_G.NexusConnections) do
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                conn:Disconnect()
            end
        end
        _G.NexusConnections = {}
        pcall(function() game:GetService("Lighting").ClockTime = 12 end)
        pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
    end

    Tab:CreateAction("Reload Script", "Reload", function()
        Unload()
        task.wait(0.1)
        local URL = string.format(
            "https://raw.githubusercontent.com/%s/%s/%s/main.lua?t=%s",
            RepoConfig.User, RepoConfig.Repo, RepoConfig.Branch, tick()
        )
        local ok, result = pcall(function() return game:HttpGet(URL) end)
        if ok and result and result ~= "" then
            local fn = loadstring(result)
            if fn then fn() else warn("[Settings] Reload: loadstring failed") end
        else
            warn("[Settings] Reload: HttpGet failed — " .. tostring(result))
        end
    end):AddTooltip("Reloads the entire script from GitHub. Use this after changing Element Scale.")

    Tab:CreateAction("Unload Script", "Unload", Unload, true)
end

return SettingsModule

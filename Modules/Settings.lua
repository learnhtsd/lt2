local SettingsModule = {}
local CoreGui    = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
_G.NexusConnections = _G.NexusConnections or {}

function SettingsModule.Init(Tab, MainUI, RepoConfig, Config)
    local ScreenGui, MainFrame
    if typeof(MainUI) == "table" then
        ScreenGui  = MainUI.UI
        MainFrame  = MainUI.Frame
    elseif typeof(MainUI) == "Instance" then
        ScreenGui = MainUI
    end
    if not ScreenGui or not ScreenGui.Parent then
        ScreenGui = CoreGui:FindFirstChild("DynxeLT2Hub")
    end

    -- ── UI Settings ──────────────────────────────────────────
    if Config and MainFrame then
        local T = Config.Theme
        local W = Config.Window

        Tab:CreateSection("Window Size")

        Tab:CreateSlider("Width", 300, 800, W.Width, function(val)
            W.Width = val
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                Size     = UDim2.new(0, val, 0, W.Height),
                Position = UDim2.new(0.5, -math.floor(val/2), 0.5, -math.floor(W.Height/2))
            }):Play()
        end):AddTooltip("Adjusts the total width of the menu window.")

        Tab:CreateSlider("Height", 200, 600, W.Height, function(val)
            W.Height = val
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                Size     = UDim2.new(0, W.Width, 0, val),
                Position = UDim2.new(0.5, -math.floor(W.Width/2), 0.5, -math.floor(val/2))
            }):Play()
        end):AddTooltip("Adjusts the total height of the menu window.")

        Tab:CreateSection("Accent Color")

        local AccentPresets = {
            {Name = "Blue",    Color = Color3.fromRGB(74,  120, 255)},
            {Name = "Purple",  Color = Color3.fromRGB(140,  80, 255)},
            {Name = "Teal",    Color = Color3.fromRGB(40,  180, 160)},
            {Name = "Green",   Color = Color3.fromRGB(60,  180,  80)},
            {Name = "Red",     Color = Color3.fromRGB(220,  60,  60)},
            {Name = "Orange",  Color = Color3.fromRGB(220, 130,  30)},
            {Name = "Pink",    Color = Color3.fromRGB(220,  80, 160)},
        }
        local PresetNames = {}
        for _, p in ipairs(AccentPresets) do
            table.insert(PresetNames, p.Name)
        end

        Tab:CreateDropdown("Color Preset", PresetNames, "Blue", function(selected)
            for _, p in ipairs(AccentPresets) do
                if p.Name == selected then
                    T.Accent = p.Color
                    -- Propagate to any accent-colored elements still reachable
                    local hub = CoreGui:FindFirstChild("DynxeLT2Hub")
                    if hub then
                        for _, obj in ipairs(hub:GetDescendants()) do
                            if obj:IsA("TextLabel") and obj.TextColor3 == T.Accent then
                                obj.TextColor3 = p.Color
                            end
                            if obj:IsA("UIStroke") and obj.Color == T.Accent then
                                obj.Color = p.Color
                            end
                            if obj:IsA("Frame") and obj.BackgroundColor3 == T.Accent then
                                obj.BackgroundColor3 = p.Color
                            end
                        end
                    end
                    T.Accent = p.Color
                    break
                end
            end
        end):AddTooltip("Changes the accent highlight color. New elements reflect immediately; reload for full effect.")

        Tab:CreateSection("Transparency")

        Tab:CreateSlider("Menu Opacity", 0, 100, 85, function(val)
            -- 100 = fully opaque, 0 = fully transparent
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {
                BackgroundTransparency = 1 - (val / 100)
            }):Play()
        end):AddTooltip("Controls how transparent the menu background is.")
    end

    -- ── Interface ────────────────────────────────────────────
    Tab:CreateSection("Interface")
    Tab:CreateKeybind("Toggle Menu", Enum.KeyCode.LeftAlt, function()
        if ScreenGui then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)

    -- ── System ───────────────────────────────────────────────
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
        pcall(function() game.Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
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
    end)

    Tab:CreateAction("Unload Script", "Unload", Unload, true)
end

return SettingsModule

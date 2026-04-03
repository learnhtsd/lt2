local SettingsModule = {}
local CoreGui = game:GetService("CoreGui")

_G.NexusConnections = _G.NexusConnections or {}

function SettingsModule.Init(Tab, MainUI, RepoConfig)

    -- Resolve the real ScreenGui regardless of what was passed in.
    -- Handles: Window table (has .UI), a direct ScreenGui, or last-resort CoreGui search.
    local ScreenGui
    if typeof(MainUI) == "table" then
        ScreenGui = MainUI.UI
    elseif typeof(MainUI) == "Instance" then
        ScreenGui = MainUI
    end
    if not ScreenGui or not ScreenGui.Parent then
        ScreenGui = CoreGui:FindFirstChild("DynxeLT2Hub")
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
        -- 1. Signal all loops to stop
        _G.NexusActive = false

        -- 2. Disconnect tracked connections safely
        for _, conn in pairs(_G.NexusConnections) do
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                conn:Disconnect()
            end
        end
        _G.NexusConnections = {}

        -- 3. Restore defaults (wrapped so one failure doesn't block the rest)
        pcall(function() game:GetService("Lighting").ClockTime = 12 end)
        pcall(function() game.Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)

        -- 4. Destroy the UI last
        if ScreenGui and ScreenGui.Parent then
            ScreenGui:Destroy()
        end
    end

    Tab:CreateAction("Reload Script", "Reload", function()
        Unload()

        -- Wait a frame so Unload fully finishes before re-executing
        task.wait(0.1)

        local URL = string.format(
            "https://raw.githubusercontent.com/%s/%s/%s/main.lua?t=%s",
            RepoConfig.User, RepoConfig.Repo, RepoConfig.Branch, tick()
        )

        local ok, result = pcall(function() return game:HttpGet(URL) end)
        if ok and result and result ~= "" then
            local fn = loadstring(result)
            if fn then
                fn()
            else
                warn("[Settings] Reload: loadstring failed — syntax error in main.lua")
            end
        else
            warn("[Settings] Reload: HttpGet failed — " .. tostring(result))
        end
    end)

    Tab:CreateAction("Unload Script", "Unload", Unload)
end

return SettingsModule

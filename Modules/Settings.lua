local SettingsModule = {}
local CoreGui = game:GetService("CoreGui")

-- Use a global table to track connections for easy cleaning
_G.NexusConnections = _G.NexusConnections or {}

function SettingsModule.Init(Tab, MainUI, RepoConfig)
    Tab:CreateSection("Interface")

    -- FIX: Hotkey Toggle
    -- Instead of searching CoreGui every time, we use the MainUI reference passed in
    Tab:CreateKeybind("Toggle Menu", Enum.KeyCode.LeftAlt, function()
        if MainUI then
            MainUI.Enabled = not MainUI.Enabled
        end
    end)

    Tab:CreateSection("System")

    -- FIX: Proper Unload
    local function Unload()
        -- 1. Signal all loops to stop
        _G.NexusActive = false
        
        -- 2. Disconnect all tracked events
        for _, conn in pairs(_G.NexusConnections) do
            if conn then conn:Disconnect() end
        end
        _G.NexusConnections = {}

        -- 3. Restore Lighting/Camera defaults if needed
        game:GetService("Lighting").ClockTime = 12
        game.Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        -- 4. Destroy the UI
        if MainUI then MainUI:Destroy() end
    end

    Tab:CreateAction("Reload Script", "Reload", function()
        Unload()
        
        local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/main.lua?t=%s", 
            RepoConfig.User, RepoConfig.Repo, RepoConfig.Branch, tick())
        
        local success, code = pcall(function() return game:HttpGet(URL) end)
        if success and code then
            local func = loadstring(code)
            if func then func() end
        end
    end)

    Tab:CreateAction("Unload Script", "Unload", Unload)
end

return SettingsModule

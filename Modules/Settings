local SettingsModule = {}
local CoreGui = game:GetService("CoreGui")

function SettingsModule.Init(Tab, RepoConfig)
    Tab:CreateSection("Interface")

    -- Toggle Menu Hotkey
    Tab:CreateKeybind("Toggle Menu", Enum.KeyCode.RightShift, function()
        local hub = CoreGui:FindFirstChild("NexusCustomHub")
        if hub then
            hub.Enabled = not hub.Enabled
        end
    end)

    Tab:CreateSection("System")

    -- Reload Menu Button
    Tab:CreateAction("Reload Script", "Reload", function()
        -- Destroy the current GUI
        local hub = CoreGui:FindFirstChild("NexusCustomHub")
        if hub then hub:Destroy() end
        
        -- Re-fetch and execute the main script from GitHub
        local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/main.lua?t=%s", 
            RepoConfig.User, RepoConfig.Repo, RepoConfig.Branch, tick())
        
        local success, code = pcall(function() return game:HttpGet(URL) end)
        if success and code then
            local func = loadstring(code)
            if func then func() end
        else
            warn("Failed to fetch main script for reload.")
        end
    end)

    -- Unload Menu Button
    Tab:CreateAction("Unload Script", "Unload", function()
        local hub = CoreGui:FindFirstChild("NexusCustomHub")
        if hub then hub:Destroy() end
    end)
end

return SettingsModule

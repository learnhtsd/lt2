-- Configuration
local GitHubUser = "YourUsername"
local Repository = "YourRepo"
local Branch = "main"

-- Load a standard UI Library (Example: Rayfield or Kavo)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Project Nexus",
    LoadingTitle = "Loading Systems...",
    LoadingSubtitle = "by " .. GitHubUser,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NexusConfigs",
        FileName = "MainConfig"
    }
})

-- Function to load modules from GitHub
local function LoadModule(ModuleName)
    local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua", 
        GitHubUser, Repository, Branch, ModuleName)
    
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if success and type(result) == "table" then
        return result
    else
        warn("Failed to load module: " .. ModuleName .. " Error: " .. tostring(result))
        return nil
    end
end

-- Initialize Modules
local MovementModule = LoadModule("PlayerMovement")
if MovementModule then
    MovementModule.Init(Rayfield, Window)
end

Rayfield:Notify({
    Title = "Success",
    Content = "All modules loaded successfully.",
    Duration = 5
})

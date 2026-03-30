-- GitHub Config
local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main"

-- 1. Load Orion Library First
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()

-- 2. Create Main Window
local Window = OrionLib:MakeWindow({
    Name = "Custom Hub", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "OrionConfig",
    IntroText = "Initializing..."
})

-- 3. Dynamic Module Loader with Cache-Buster
local function LoadGithubModule(ModuleName)
    -- Adding a random string at the end (?t=) prevents Roblox from loading a cached old version
    local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s", 
        User, Repo, Branch, ModuleName, tick())
        
    local Success, Result = pcall(function()
        return loadstring(game:HttpGet(URL))()
    end)
    
    if Success and type(Result) == "table" then
        return Result
    else
        warn("Failed to load module: " .. ModuleName .. " | Error: " .. tostring(Result))
        return nil
    end
end

-- 4. Initialize the Movement Module
local Movement = LoadGithubModule("PlayerMovement")
if Movement then
    Movement.Init(OrionLib, Window)
else
    OrionLib:MakeNotification({
        Name = "Error",
        Content = "Movement module failed to load. Check F9 console.",
        Time = 5
    })
end

-- 5. Finalize UI
OrionLib:Init()

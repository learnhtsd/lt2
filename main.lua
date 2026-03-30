-- Force destroy any old UI instances
for _, v in pairs(game.CoreGui:GetChildren()) do
    if v:IsA("ScreenGui") and (v.Name:find("Rayfield") or v.Name:find("Orion")) then
        v:Destroy()
    end
end

-- GitHub Config
local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main"

-- Load Orion Library
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()

-- Create Main Window
local Window = OrionLib:MakeWindow({
    Name = "Custom Hub", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "OrionConfig",
    IntroText = "Initializing..."
})

-- Dynamic Module Loader
local function LoadGithubModule(Path)
    local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua", User, Repo, Branch, Path)
    local Success, Script = pcall(function()
        return loadstring(game:HttpGet(URL))()
    end)
    
    if Success and type(Script) == "table" then
        return Script
    else
        warn("Could not load module: " .. Path)
        return nil
    end
end

-- Initialize the Movement Module
local Movement = LoadGithubModule("PlayerMovement")
if Movement then
    Movement.Init(OrionLib, Window)
end

-- Finalize
OrionLib:Init()

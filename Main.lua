-- CORRECTED: Points to the FOLDER, not the file
local BaseURL = "https://raw.githubusercontent.com/learnhtsd/lt2/main/"

local function SafeLoad(FileName)
    local url = BaseURL .. FileName
    -- We use a cache-buster (?t=...) to make sure we get the LATEST version
    local success, content = pcall(function() 
        return game:HttpGet(url .. "?t=" .. os.time()) 
    end)
    
    if not success or content:find("<!DOCTYPE html>") or content == "404: Not Found" then
        warn("Lumber Hub Error: Could not find " .. FileName .. " at " .. url)
        return nil
    end
    
    local func, err = loadstring(content)
    if not func then
        warn("Lumber Hub Error: Syntax error in " .. FileName .. " -> " .. tostring(err))
        return nil
    end
    
    return func()
end

-- 1. Load the UI Library
local Lib = SafeLoad("UI_Library.lua")

if Lib then
    -- 2. Load the Modules
    -- (Make sure you have a folder named Modules on GitHub!)
    local MoveMod = SafeLoad("Modules/Movement.lua")
    local TeleMod = SafeLoad("Modules/Teleports.lua")

    -- 3. Build the UI
    local MoveTab = Lib:CreateTab("Movement")
    Lib:CreateButton(MoveTab, "Speed (50)", function()
        if MoveMod then 
            MoveMod.SetSpeed(50) 
        else
            -- Fallback if the module failed to load
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 50
        end
    end)
    
    Lib:ShowPage("Movement") -- Make the page visible
    print("Lumber Hub: Successfully Loaded!")
else
    warn("Lumber Hub: UI Library failed to load. Script stopping.")
end

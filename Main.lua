-- Change this to your ACTUAL Raw GitHub link (Ending with a /)
local BaseURL = "https://github.com/learnhtsd/lt2/raw/refs/heads/main/UI_Library.lua"

local function SafeLoad(FileName)
    local url = BaseURL .. FileName
    local success, content = pcall(function() return game:HttpGet(url) end)
    
    if not success or content == "404: Not Found" then
        warn("Lumber Hub Error: Could not find file at " .. url)
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
    local MoveMod = SafeLoad("Modules/Movement.lua")
    local TeleMod = SafeLoad("Modules/Teleports.lua")

    -- 3. Build the UI (Ensure Lib:CreateTab and Lib:CreateButton are defined in UI_Library.lua)
    local MoveTab = Lib:CreateTab("Movement")
    Lib:CreateButton(MoveTab, "Speed (50)", function()
        if MoveMod then MoveMod.SetSpeed(50) end
    end)
    
    print("Lumber Hub: Successfully Loaded!")
else
    warn("Lumber Hub: UI Library failed to load. Script stopping.")
end

local BaseURL = "https://raw.githubusercontent.com/learnhtsd/lt2/main/"

local function SafeLoad(FileName)
    local url = BaseURL .. FileName
    local success, content = pcall(function() 
        return game:HttpGet(url .. "?t=" .. os.time()) 
    end)
    
    if not success or content:find("<!DOCTYPE html>") or content == "404: Not Found" then
        warn("Lumber Hub Error: Could not find " .. FileName)
        return nil
    end
    
    local func, err = loadstring(content)
    if not func then
        warn("Lumber Hub Error: Syntax error in " .. FileName .. " -> " .. tostring(err))
        return nil
    end
    
    return func()
end

local Lib = SafeLoad("UI_Library.lua")

if Lib then
    local MoveMod = SafeLoad("Modules/Movement.lua")
    local MoveTab = Lib:CreateTab("Movement")

    -- 1. SPEED BUTTON
    Lib:CreateButton(MoveTab, "Speed (50)", function()
        if MoveMod then MoveMod.SetSpeed(50) end
    end)

    -- 2. JUMP BUTTON (New)
    Lib:CreateButton(MoveTab, "High Jump (100)", function()
        if MoveMod then MoveMod.SetJump(100) end
    end)

    -- 3. FLY BUTTON (New)
    Lib:CreateButton(MoveTab, "Toggle Fly", function()
        if MoveMod then 
            local state = MoveMod.ToggleFly()
            Lib:Notify("Fly is now: " .. (state and "ON" or "OFF"))
        end
    end)
    
    Lib:ShowPage("Movement")
    print("Lumber Hub: Loaded Everything!")
end

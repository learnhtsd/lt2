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

-- [1] Load the Library and Movement Module
local Lib = SafeLoad("UI_Library.lua")
local MoveMod = SafeLoad("Modules/Movement.lua")

if Lib and MoveMod then
    -- [2] Create the Tab
    local MoveTab = Lib:CreateTab("Movement")

    -- [3] WALK SPEED SLIDER
    Lib:CreateSlider(MoveTab, "Walk Speed", 16, 300, 16, function(value)
        MoveMod.SetSpeed(value)
    end)

    -- [4] JUMP POWER SLIDER
    Lib:CreateSlider(MoveTab, "Jump Power", 50, 500, 50, function(value)
        MoveMod.SetJump(value)
    end)

    -- [5] FLY SPEED SLIDER
    Lib:CreateSlider(MoveTab, "Fly Speed", 10, 500, 50, function(value)
        MoveMod.FlySpeed = value
    end)

    -- [6] FLY TOGGLE (Default Key: Q)
    -- This toggle returns a function ('updateFlyUI') that we can use 
    -- to change the button color/text when the user presses 'Q'
    local updateFlyUI = Lib:CreateToggle(MoveTab, "Toggle Fly (Q)", false, function(state)
        -- Only trigger if the module state is different from the UI state
        if state ~= MoveMod.Flying then
            MoveMod.ToggleFly()
        end
    end)

    -- Link the Movement Module back to the UI so pressing 'Q' updates the button color
    if MoveMod.SetUpdateCallback then
        MoveMod.SetUpdateCallback(updateFlyUI)
    end
    
    -- [7] Finalize
    Lib:ShowPage("Movement")
    print("Lumber Hub: Successfully Loaded with Sliders and Keybinds!")
else
    warn("Lumber Hub: Failed to load one or more components.")
end

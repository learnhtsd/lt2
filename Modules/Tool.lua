local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local RunService = game:GetService("RunService")

-- Variable for toggle
local InspectorEnabled = false 

function Tool.Init(Tab, Lib)
    -- This part works (you see the text)
    Tab:CreateSection("Diagnostic Tools")
    
    -- FIXED: Changed CreateLabel to CreateAction since your Library might not support Labels
    Tab:CreateAction("Hovering: None", "INFO", function() end)

    -- ===========================
    -- OBJECT INSPECTOR
    -- ===========================
    Tab:CreateToggle("Object Inspector", false, function(state)
        InspectorEnabled = state
        
        -- Safety check for the Notification system
        if Lib and Lib.Notify then
            Lib:Notify("Inspector", state and "Enabled! Right-click to log." or "Disabled.", 3)
        end
    end)

    -- Right Click to Log/Notify Name
    Mouse.Button2Down:Connect(function()
        if InspectorEnabled and Mouse.Target then
            local t = Mouse.Target
            local info = string.format("Name: %s | Class: %s", t.Name, t.ClassName)
            
            if Lib and Lib.Notify then
                Lib:Notify("Object Identified", info, 5)
            end
            
            print("--------------------------")
            print("INSPECTED OBJECT:")
            print("Name: " .. t.Name)
            print("Class: " .. t.ClassName)
            print("Parent: " .. (t.Parent and t.Parent.Name or "Nil"))
            print("Full Path: " .. t:GetFullName())
            print("--------------------------")
        end
    end)
end

return Tool

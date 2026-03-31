local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Variable for toggle
local InspectorEnabled = false 

function Tool.Init(Tab, Lib)
    -- Section Header
    Tab:CreateSection("Diagnostic Tools")

    -- ===========================
    -- OBJECT INSPECTOR TOGGLE
    -- ===========================
    Tab:CreateToggle("Object Inspector", false, function(state)
        InspectorEnabled = state
        
        -- Safety check for the Notification system
        if Lib and Lib.Notify then
            local msg = state and "Enabled! Left-click any object to log its name." or "Inspector Disabled."
            Lib:Notify("Inspector", msg, 5)
        end
    end)

    -- ===========================
    -- SELECTION LOGIC (Right Click)
    -- ===========================
    Mouse.Button1Down:Connect(function()
        if InspectorEnabled and Mouse.Target then
            local t = Mouse.Target
            local info = string.format("Name: %s | Class: %s", t.Name, t.ClassName)
            
            -- Send the notification to the bottom right
            if Lib and Lib.Notify then
                Lib:Notify("Object Identified", info, 10)
            end
            
            -- Detailed print to console (F9) for easy copying
            print("--------------------------")
            print("INSPECTED OBJECT:")
            print("Name:   " .. t.Name)
            print("Class:  " .. t.ClassName)
            print("Parent: " .. (t.Parent and t.Parent.Name or "Nil"))
            print("Path:   " .. t:GetFullName())
            print("--------------------------")
        end
    end)
end

return Tool

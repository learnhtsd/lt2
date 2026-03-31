local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Variable for toggle
local InspectorEnabled = false 

function Tool.Init(Tab, Lib)
    Tab:CreateSection("Diagnostic Tools")
    
    local InspectorLabel = Tab:CreateLabel("Hovering: None")

    -- ===========================
    -- OBJECT INSPECTOR
    -- ===========================
    Tab:CreateToggle("Object Inspector", false, function(state)
        InspectorEnabled = state
        if state then
            Lib:Notify("Inspector", "Enabled! Right-click an object to log its name.", 4)
        else
            InspectorLabel:SetText("Hovering: None")
            Lib:Notify("Inspector", "Disabled.", 2)
        end
    end)

    -- Right Click to Log/Notify Name
    Mouse.Button2Down:Connect(function()
        if InspectorEnabled and Mouse.Target then
            local t = Mouse.Target
            local info = string.format("Name: %s | Class: %s", t.Name, t.ClassName)
            
            -- Send the notification to the bottom right
            Lib:Notify("Object Identified", info, 5)
            
            -- Print to console (F9) for easy copying
            print("--------------------------")
            print("INSPECTED OBJECT:")
            print("Name: " .. t.Name)
            print("Class: " .. t.ClassName)
            print("Parent: " .. (t.Parent and t.Parent.Name or "Nil"))
            print("Full Path: " .. t:GetFullName())
            print("--------------------------")
        end
    end)

    -- Real-time label update
    game:GetService("RunService").RenderStepped:Connect(function()
        if InspectorEnabled then
            local target = Mouse.Target
            if target then
                InspectorLabel:SetText(string.format("Hovering: %s [%s]", target.Name, target.ClassName))
            else
                InspectorLabel:SetText("Hovering: Nil")
            end
        end
    end)
end

return Tool

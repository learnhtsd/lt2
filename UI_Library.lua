local Lib = {}
local CoreGui = game:GetService("CoreGui")

-- Anti-Duplicate
if CoreGui:FindFirstChild("LT2Hub") then CoreGui.LT2Hub:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LT2Hub"
ScreenGui.Parent = CoreGui

-- ... (Insert all your UI creation code here: MainFrame, Header, etc.) ...

function Lib:CreateTab(name)
    -- (Insert your CreateTab logic here)
    -- Return the Page frame so we can add buttons to it later
    return Page 
end

function Lib:CreateButton(parent, name, callback)
    -- (Insert your CreateButton logic here)
end

return Lib -- This is the magic line

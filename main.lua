local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main"

-- 1. Create the Screen UI
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UIListLayout = Instance.new("UIListLayout")

ScreenGui.Name = "CustomHub"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false

-- Minimalist Sidebar/Corner Design
MainFrame.Name = "Container"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0, 10, 0.5, -100) -- Left side center
MainFrame.Size = UDim2.new(0, 150, 0, 0) -- Starts small, expands with buttons
MainFrame.AutomaticSize = Enum.AutomaticSize.Y

UIListLayout.Parent = MainFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 2. The "Bridge" Function
-- This is what we pass to modules so they can add buttons
local UI_API = {}
function UI_API.CreateButton(text, callback)
    local btn = Instance.new("TextButton")
    btn.Name = text
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Font = Enum.Font.Offset
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- 3. Module Loader
local function LoadModule(name)
    local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s", 
        User, Repo, Branch, name, tick())
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    
    if success and type(result) == "table" then
        return result
    else
        warn("Failed: " .. tostring(result))
    end
end

-- 4. Execute Module
local Movement = LoadModule("PlayerMovement")
if Movement then
    Movement.Init(UI_API)
end

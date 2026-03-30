-- GitHub Config
local User = "learnhtsd"
local Repo = "lt2"
local Branch = "main"

-- 1. Create the UI Container
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LumberHub_Custom"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0, 20, 0.4, 0) -- Positioned on the left
MainFrame.Size = UDim2.new(0, 160, 0, 0)
MainFrame.AutomaticSize = Enum.AutomaticSize.Y

local Layout = Instance.new("UIListLayout")
Layout.Parent = MainFrame
Layout.Padding = UDim.new(0, 4)
Layout.SortOrder = Enum.SortOrder.LayoutOrder

-- 2. The API for Modules
local UI_API = {}

function UI_API.CreateButton(text, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    
    -- Small corner radius for a cleaner look
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- 3. The Loader (Fixed Cache-Busting)
local function LoadModule(name)
    local URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/Modules/%s.lua?t=%s", 
        User, Repo, Branch, name, tick())
    
    local success, code = pcall(function() return game:HttpGet(URL) end)
    
    if success and code then
        local func, err = loadstring(code)
        if func then
            return func()
        else
            warn("Syntax Error in " .. name .. ": " .. tostring(err))
        end
    else
        warn("Failed to fetch module from GitHub: " .. name)
    end
end

-- 4. Load the Movement Module
local MovementModule = LoadModule("PlayerMovement")
if MovementModule and MovementModule.Init then
    MovementModule.Init(UI_API)
end

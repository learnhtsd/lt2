local Lib = {}
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

if CoreGui:FindFirstChild("LT2Hub") then CoreGui.LT2Hub:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LT2Hub"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 450)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner", MainFrame)
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, 0, 1, -100)
ContentArea.Position = UDim2.new(0, 0, 0, 100)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Pages = {}

-- [NEW] TOGGLE FUNCTION
function Lib:CreateToggle(parent, name, default, callback)
    local Enabled = default
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 368, 0, 38)
    Btn.BackgroundColor3 = Enabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
    Btn.Text = name .. ": " .. (Enabled and "ON" or "OFF")
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamMedium
    Btn.Parent = parent
    
    local Corner = Instance.new("UICorner", Btn)

    Btn.MouseButton1Click:Connect(function()
        Enabled = not Enabled
        Btn.BackgroundColor3 = Enabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
        Btn.Text = name .. ": " .. (Enabled and "ON" or "OFF")
        callback(Enabled)
    end)
    
    return function(val) -- External update function
        Enabled = val
        Btn.BackgroundColor3 = Enabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
        Btn.Text = name .. ": " .. (Enabled and "ON" or "OFF")
    end
end

-- [NEW] SLIDER FUNCTION
function Lib:CreateSlider(parent, name, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(0, 368, 0, 50)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    SliderFrame.Parent = parent
    Instance.new("UICorner", SliderFrame)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -20, 0, 20)
    Label.Position = UDim2.new(0, 10, 0, 5)
    Label.BackgroundTransparency = 1
    Label.Text = name .. ": " .. default
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SliderFrame

    local Tray = Instance.new("Frame")
    Tray.Size = UDim2.new(1, -20, 0, 6)
    Tray.Position = UDim2.new(0, 10, 0, 35)
    Tray.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Tray.Parent = SliderFrame

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    Fill.Parent = Tray

    local function UpdateSlider()
        local mousePos = UserInputService:GetMouseLocation().X
        local trayPos = Tray.AbsolutePosition.X
        local traySize = Tray.AbsoluteSize.X
        local percent = math.clamp((mousePos - trayPos) / traySize, 0, 1)
        local val = math.floor(min + (max - min) * percent)
        Fill.Size = UDim2.new(percent, 0, 1, 0)
        Label.Text = name .. ": " .. val
        callback(val)
    end

    Tray.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local move; move = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider() end
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then move:Disconnect() end
            end)
            UpdateSlider()
        end
    end)
end

-- (Keep your existing CreateTab and ShowPage functions here)
function Lib:CreateTab(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.Parent = ContentArea
    local Layout = Instance.new("UIListLayout", Page)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.Padding = UDim.new(0, 6)
    Pages[name] = Page
    return Page
end

function Lib:ShowPage(name)
    for k, v in pairs(Pages) do v.Visible = (k == name) end
end

return Lib

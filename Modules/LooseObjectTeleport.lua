-- Services
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

-- Variables
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera

-- State
local selectionMode = false
local queuedObjects = {}
local activeDrags = {} -- Store physics folders to keep them moving
local isProcessing = false

-- Configuration (Refined from your Hard Dragger)
local CONFIG = {
    DragStrength = 1e8,
    Snappiness = 150,
    HoldDistance = 8,
    MaxThrowSpeed = 300
}

-------------------------------------------------------------------------------
-- UI SETUP (Bottom-Right Minimalist)
-------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "LooseObjectFetch_UI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 160, 0, 115)
MainFrame.Position = UDim2.new(1, -10, 1, -10)
MainFrame.AnchorPoint = Vector2.new(1, 1)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 4)

local function CreateBtn(text, pos, color)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(1, -10, 0, 25)
    btn.Position = UDim2.new(0, 5, 0, pos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Code
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
    return btn
end

local ToggleBtn = CreateBtn("SELECT MODE: OFF", 10, Color3.fromRGB(40, 40, 40))
local ClearBtn = CreateBtn("DESELECT ALL (0)", 45, Color3.fromRGB(80, 30, 30))
local StartBtn = CreateBtn("START FETCHING", 80, Color3.fromRGB(30, 80, 30))

-------------------------------------------------------------------------------
-- HARD DRAGGER ENGINE
-------------------------------------------------------------------------------
local function applyHardDrag(obj)
    if not obj or activeDrags[obj] then return end
    
    local folder = Instance.new("Folder")
    folder.Name = "HardDrag_Physics"
    folder.Parent = obj
    activeDrags[obj] = folder

    local att = Instance.new("Attachment", obj)
    
    local alignPos = Instance.new("AlignPosition")
    alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPos.Attachment0 = att
    alignPos.MaxForce = CONFIG.DragStrength
    alignPos.Responsiveness = CONFIG.Snappiness
    alignPos.Parent = folder

    local alignOri = Instance.new("AlignOrientation")
    alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOri.Attachment0 = att
    alignOri.MaxTorque = CONFIG.DragStrength
    alignOri.Responsiveness = CONFIG.Snappiness
    alignOri.Parent = folder

    -- Heartbeat loop to keep item in front of player
    local dragConn
    dragConn = RunService.Heartbeat:Connect(function()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if not folder or not folder.Parent or not root then
            dragConn:Disconnect()
            activeDrags[obj] = nil
            return
        end
        
        local targetCF = root.CFrame * CFrame.new(0, 0, -CONFIG.HoldDistance)
        alignPos.Position = targetCF.Position
        alignOri.CFrame = targetCF
    end)
end

-------------------------------------------------------------------------------
-- FETCH SEQUENCE
-------------------------------------------------------------------------------
local function executeFetch()
    if isProcessing or #queuedObjects == 0 then return end
    isProcessing = true
    StartBtn.Text = "FETCHING..."
    StartBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 30)

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local startPos = root.CFrame

    for i = #queuedObjects, 1, -1 do
        local obj = queuedObjects[i]
        if obj and obj.Parent then
            -- 1. TP to Item + Force Orientation (Stand in front)
            root.Anchored = true
            local targetPos = obj.Position + (Vector3.new(obj.Position.X - startPos.X, 0, obj.Position.Z - startPos.Z).Unit * -5)
            root.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 3, 0), obj.Position)
            
            -- Hijack Camera for the click
            local oldCamType = Camera.CameraType
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), obj.Position)
            
            task.wait(0.2) -- Network Handshake

            -- 2. Grab (Click)
            local screenPos, onScreen = Camera:WorldToScreenPoint(obj.Position)
            if onScreen then
                VIM:SendMouseMoveEvent(screenPos.X, screenPos.Y, game)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
            end

            -- 3. Attach Hard Physics
            applyHardDrag(obj)
            task.wait(0.1)

            -- 4. Cleanup UI Highlight
            if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
            table.remove(queuedObjects, i)
            ClearBtn.Text = "DESELECT ALL (" .. #queuedObjects .. ")"
            
            -- Return Camera
            Camera.CameraType = oldCamType
        end
    end

    -- 5. Return Home
    root.CFrame = startPos
    task.wait(0.1)
    root.Anchored = false
    
    isProcessing = false
    StartBtn.Text = "START FETCHING"
    StartBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
end

-------------------------------------------------------------------------------
-- INPUT & UI LOGIC
-------------------------------------------------------------------------------
ToggleBtn.MouseButton1Click:Connect(function()
    selectionMode = not selectionMode
    ToggleBtn.Text = selectionMode and "SELECT MODE: ON" or "SELECT MODE: OFF"
    ToggleBtn.BackgroundColor3 = selectionMode and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(40, 40, 40)
end)

ClearBtn.MouseButton1Click:Connect(function()
    for _, obj in ipairs(queuedObjects) do
        if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
    end
    queuedObjects = {}
    ClearBtn.Text = "DESELECT ALL (0)"
end)

StartBtn.MouseButton1Click:Connect(executeFetch)

UIS.InputBegan:Connect(function(input, processed)
    if processed or not selectionMode then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local target = Mouse.Target
        if target and not target.Anchored then
            -- Check if already in queue
            local index = table.find(queuedObjects, target)
            if index then
                table.remove(queuedObjects, index)
                if target:FindFirstChild("TP_Highlight") then target.TP_Highlight:Destroy() end
            else
                table.insert(queuedObjects, target)
                local highlight = Instance.new("SelectionBox")
                highlight.Name = "TP_Highlight"
                highlight.Adornee = target
                highlight.Color3 = Color3.fromRGB(0, 255, 100)
                highlight.Parent = target
            end
            ClearBtn.Text = "DESELECT ALL (" .. #queuedObjects .. ")"
        end
    elseif input.KeyCode == Enum.KeyCode.X then
        -- Universal Drop/Release
        for _, folder in pairs(activeDrags) do folder:Destroy() end
        activeDrags = {}
        local mouseLoc = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(mouseLoc.X, mouseLoc.Y, 0, false, game, 1)
    end
end)

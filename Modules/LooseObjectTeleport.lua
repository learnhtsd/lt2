local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local VIM = game:GetService("VirtualInputManager")

    -- Variables
    local Player = Players.LocalPlayer
    local Mouse = Player:GetMouse()
    local Camera = workspace.CurrentCamera

    -- Configuration
    local Config = {
        SelectionEnabled = false,
        DragStrength = 1e8,
        Snappiness = 150,
        HoldDistance = 7
    }

    local queuedObjects = {}
    local isProcessing = false
    local connections = {}

    -- Physics logic (unchanged)
    local function applyPhysics(obj)
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local folder = Instance.new("Folder", obj)
        folder.Name = "TempFetchPhysics"
        local att = Instance.new("Attachment", obj)
        local alignPos = Instance.new("AlignPosition", folder)
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0 = att
        alignPos.MaxForce = Config.DragStrength
        alignPos.Responsiveness = Config.Snappiness
        local alignOri = Instance.new("AlignOrientation", folder)
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        local loop = RunService.Heartbeat:Connect(function()
            if not folder or not folder.Parent then return end
            local targetCF = root.CFrame * CFrame.new(0, 0, -Config.HoldDistance)
            alignPos.Position = targetCF.Position
            alignOri.CFrame = targetCF
        end)
        return folder, loop
    end

    -- UI INTEGRATION
    Tab:CreateSection("Loose Object Teleporter")

    Tab:CreateToggle("Selection Mode", false, function(state)
        Config.SelectionEnabled = state
    end)

    -- Fixed: Renamed to CreateAction and captured the returned button object
    local DeselectBtnObj = Tab:CreateAction("Clear List", "Deselect All (0)", function()
        for _, obj in ipairs(queuedObjects) do
            if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
        end
        queuedObjects = {}
        DeselectBtnObj.Text = "Deselect All (0)"
    end)

    Tab:CreateAction("Execute", "Start Fetching", function()
        -- Insert your runFetchSequence() logic here
        Library:Notify("Teleport", "Starting fetch sequence...", 3)
    end)

    -- SELECTION LISTENER
    connections.Input = UIS.InputBegan:Connect(function(input, processed)
        if processed or not Config.SelectionEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local target = Mouse.Target
            if target and not target.Anchored then
                local index = table.find(queuedObjects, target)
                
                if index then
                    table.remove(queuedObjects, index)
                    if target:FindFirstChild("TP_Highlight") then target.TP_Highlight:Destroy() end
                else
                    table.insert(queuedObjects, target)
                    local h = Instance.new("SelectionBox")
                    h.Name = "TP_Highlight"
                    h.Color3 = Color3.fromRGB(0, 255, 150)
                    h.Adornee = target
                    h.Parent = target
                end
                -- Fixed: Correctly updating the text on the returned button object
                DeselectBtnObj.Text = "Deselect All (" .. #queuedObjects .. ")"
            end
        end
    end)
end

return LooseObjectTeleport

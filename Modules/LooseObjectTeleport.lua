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
        HoldDistance = 7 -- Distance in front of player during the "snap back"
    }

    -- State
    local queuedObjects = {}
    local isProcessing = false
    local connections = {}

    -------------------------------------------------------------------------------
    -- PHYSICS UTILS
    -------------------------------------------------------------------------------
    
    local function applyPhysics(obj)
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local folder = Instance.new("Folder")
        folder.Name = "TempFetchPhysics"
        folder.Parent = obj

        local att = Instance.new("Attachment", obj)
        
        local alignPos = Instance.new("AlignPosition")
        alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
        alignPos.Attachment0 = att
        alignPos.MaxForce = Config.DragStrength
        alignPos.Responsiveness = Config.Snappiness
        alignPos.Parent = folder

        local alignOri = Instance.new("AlignOrientation")
        alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
        alignOri.Attachment0 = att
        alignOri.MaxTorque = Config.DragStrength
        alignOri.Responsiveness = Config.Snappiness
        alignOri.Parent = folder

        -- Local loop to keep item pinned during the teleport
        local loop = RunService.Heartbeat:Connect(function()
            if not folder or not folder.Parent then return end
            local targetCF = root.CFrame * CFrame.new(0, 0, -Config.HoldDistance)
            alignPos.Position = targetCF.Position
            alignOri.CFrame = targetCF
        end)

        return folder, loop
    end

    local function releaseAll()
        local mouseLoc = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(mouseLoc.X, mouseLoc.Y, 0, false, game, 1)
    end

    -------------------------------------------------------------------------------
    -- CORE FETCH LOGIC
    -------------------------------------------------------------------------------

    local function runFetchSequence()
        if isProcessing or #queuedObjects == 0 then return end
        isProcessing = true
        
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then isProcessing = false return end

        local startPos = root.CFrame

        for i = #queuedObjects, 1, -1 do
            local obj = queuedObjects[i]
            if obj and obj.Parent then
                -- 1. TP to Item (Face it directly)
                root.Anchored = true
                local offset = (obj.Position - startPos.Position).Unit * -5
                root.CFrame = CFrame.lookAt(obj.Position + offset + Vector3.new(0, 2, 0), obj.Position)
                
                -- Camera Hijack (Precision targeting)
                local oldCamType = Camera.CameraType
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), obj.Position)
                
                task.wait(0.25) -- Wait for ownership/streaming

                -- 2. The Grab
                local screenPos, onScreen = Camera:WorldToScreenPoint(obj.Position)
                if onScreen then
                    VIM:SendMouseMoveEvent(screenPos.X, screenPos.Y, game)
                    task.wait(0.05)
                    VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
                end

                -- 3. Apply Hard Drag
                local pFolder, pLoop = applyPhysics(obj)
                task.wait(0.1)

                -- 4. TP Back to Start
                root.CFrame = startPos
                
                -- Destination Buffer (Let physics settle at home)
                for _ = 1, 10 do RunService.Heartbeat:Wait() end

                -- 5. THE STOP: Kill physics and release click once home
                if pLoop then pLoop:Disconnect() end
                if pFolder then pFolder:Destroy() end
                releaseAll()
                
                -- Cleanup Highlights
                if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
                table.remove(queuedObjects, i)
                
                -- Reset Camera for next item
                Camera.CameraType = oldCamType
                task.wait(0.1)
            end
        end

        root.Anchored = false
        isProcessing = false
        Library:Notify("Fetch Sequence Complete")
    end

    -------------------------------------------------------------------------------
    -- UI INTEGRATION
    -------------------------------------------------------------------------------

    Tab:CreateSection("Loose Object Teleporter")

    Tab:CreateToggle("Selection Mode", false, function(state)
        Config.SelectionEnabled = state
        if not state then
            -- Optional: Clear highlights when turning off
        end
    end)

    local DeselectBtn = Tab:CreateButton("Deselect All (0)", function()
        for _, obj in ipairs(queuedObjects) do
            if obj:FindFirstChild("TP_Highlight") then obj.TP_Highlight:Destroy() end
        end
        queuedObjects = {}
        -- Note: If your library has a way to update button text, call it here.
    end)

    Tab:CreateButton("Start Fetching", function()
        runFetchSequence()
    end)

    -------------------------------------------------------------------------------
    -- SELECTION LISTENER
    -------------------------------------------------------------------------------

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
                -- Update button text via Library if supported:
                -- DeselectBtn:SetText("Deselect All (" .. #queuedObjects .. ")")
            end
        end
    end)
end

return LooseObjectTeleport

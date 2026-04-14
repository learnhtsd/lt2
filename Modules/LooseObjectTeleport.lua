local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab, Library)
    -- Services
    local Players     = game:GetService("Players")
    local UIS         = game:GetService("UserInputService")
    local VIM         = game:GetService("VirtualInputManager")
    local RunService  = game:GetService("RunService")
    local CoreGui     = game:GetService("CoreGui")
    local Camera      = workspace.CurrentCamera

    -- Variables
    local Player        = Players.LocalPlayer
    local Mouse         = Player:GetMouse()
    local queuedObjects = {}
    local connections   = {}

    -- Lasso state
    local dragStart  = nil
    local isDragging = false

    -- FIX 1: IgnoreGuiInset so UIS:GetMouseLocation() and WorldToViewportPoint
    --         share the same coordinate origin (top-left of the viewport).
    local guiParent = pcall(function() return CoreGui.Name end) and CoreGui
                      or Player:WaitForChild("PlayerGui")

    local selectionGui              = Instance.new("ScreenGui")
    selectionGui.Name               = "LassoSelectionGui"
    selectionGui.IgnoreGuiInset     = true   -- ← FIX
    selectionGui.ResetOnSpawn       = false
    selectionGui.Parent             = guiParent

    local selectionBox2D                      = Instance.new("Frame")
    selectionBox2D.BackgroundColor3           = Color3.fromRGB(0, 170, 255)
    selectionBox2D.BackgroundTransparency     = 0.65
    selectionBox2D.BorderSizePixel            = 2
    selectionBox2D.BorderColor3               = Color3.fromRGB(0, 220, 255)
    selectionBox2D.Visible                    = false
    selectionBox2D.Parent                     = selectionGui

    -- Configuration
    local Config = {
        SelectionEnabled      = false,
        GroupSelectionEnabled = false,
        LassoEnabled          = false,
        DragSteps             = 12,
    }

    ---------------------------------------------------------
    -- HELPER UTILITIES
    ---------------------------------------------------------
    local function stopAllMotion(obj)
        if obj and obj:IsA("BasePart") then
            obj.AssemblyLinearVelocity  = Vector3.zero
            obj.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local function linearDrag(obj, endPos)
        local startCFrame = obj.CFrame
        local finalCFrame = CFrame.new(endPos)
        local oldCollide  = obj.CanCollide
        obj.CanCollide    = false

        for i = 1, Config.DragSteps do
            if not obj or not obj.Parent then break end
            obj.CFrame = startCFrame:Lerp(finalCFrame, i / Config.DragSteps)
            stopAllMotion(obj)
            task.wait(0.01)
        end

        if obj and obj.Parent then
            obj.CFrame     = finalCFrame
            obj.CanCollide = oldCollide
        end
    end

    local function addToQueue(obj)
        if obj and obj:IsA("BasePart") and not obj.Anchored then
            if not table.find(queuedObjects, obj) then
                table.insert(queuedObjects, obj)
                local h         = Instance.new("SelectionBox")
                h.Name          = "TP_Highlight"
                h.Color3        = Color3.fromRGB(150, 255, 150)
                h.LineThickness = 0.04
                h.Adornee       = obj
                h.Parent        = obj
            end
        end
    end

    local function removeFromQueue(obj)
        local index = table.find(queuedObjects, obj)
        if index then
            table.remove(queuedObjects, index)
            local h = obj:FindFirstChild("TP_Highlight")
            if h then h:Destroy() end
        end
    end

    -- FIX 3a: Check whether ANY part of a model is already queued.
    --         Using the first found part as the toggle anchor avoids
    --         the partial-selection flip bug.
    local function isModelQueued(model)
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("BasePart") and table.find(queuedObjects, child) then
                return true
            end
        end
        return false
    end

    local function getModelParts(model)
        local parts = {}
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("BasePart") and not child.Anchored then
                parts[#parts + 1] = child
            end
        end
        return parts
    end

    ---------------------------------------------------------
    -- UI INTEGRATION
    ---------------------------------------------------------
    Tab:CreateSection("Multi-Object Grabber")

    Tab:CreateToggle("Selection Mode (Click Part)", false, function(state)
        Config.SelectionEnabled = state
        Library:Notify("Selection", state and "Click objects to queue" or "Click selection disabled", 2)
    end)

    Tab:CreateToggle("Group Selection", false, function(state)
        Config.GroupSelectionEnabled = state
        Library:Notify("Group Selection", state and "Clicking selects entire model" or "Group selection disabled", 2)
    end)

    Tab:CreateToggle("Lasso Tool (Drag Box)", false, function(state)
        Config.LassoEnabled = state
        Library:Notify("Lasso Tool", state and "Click and drag to select objects" or "Lasso disabled", 2)
        if not state and isDragging then
            isDragging = false
            selectionBox2D.Visible = false
        end
    end)

    Tab:CreateAction("Clear Queue", "Reset List", function()
        for _, obj in ipairs(queuedObjects) do
            local h = obj and obj:FindFirstChild("TP_Highlight")
            if h then h:Destroy() end
        end
        queuedObjects = {}
        Library:Notify("Queue", "Cleared all items.", 2)
    end)

    Tab:CreateAction("Execute TP", "Start Process", function()
        local char = Player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            return Library:Notify("Error", "No Character!", 3)
        end
        if #queuedObjects == 0 then
            return Library:Notify("Error", "Queue is empty!", 3)
        end

        Library:Notify("Processing", "Moving " .. #queuedObjects .. " items…", 3)

        task.spawn(function()
            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]
                if obj and obj.Parent and obj:IsA("BasePart") then
                    local destination         = hrp.Position
                    local originalPlayerCFrame = hrp.CFrame

                    hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 0, -5), obj.Position)
                    task.wait(0.3)

                    local vector, onScreen = Camera:WorldToViewportPoint(obj.Position)
                    if onScreen then
                        VIM:SendMouseMoveEvent(vector.X, vector.Y, game)
                        task.wait(0.05)
                        VIM:SendMouseButtonEvent(vector.X, vector.Y, 0, true, game, 0)
                        task.wait(0.2)
                        linearDrag(obj, destination)
                        VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
                        stopAllMotion(obj)
                        task.wait(0.2)
                    end

                    hrp.CFrame = originalPlayerCFrame
                end

                local h = obj and obj:FindFirstChild("TP_Highlight")
                if h then h:Destroy() end
                table.remove(queuedObjects, i)
            end
            Library:Notify("Complete", "Queue finished.", 3)
        end)
    end)

    ---------------------------------------------------------
    -- INPUT LISTENERS
    ---------------------------------------------------------
    connections.InputBegan = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        -- Lasso: begin drag
        if Config.LassoEnabled then
            isDragging = true
            -- FIX 1: use UIS:GetMouseLocation() — same space as WorldToViewportPoint
            --        with IgnoreGuiInset = true.
            dragStart = UIS:GetMouseLocation()
            selectionBox2D.Position = UDim2.fromOffset(dragStart.X, dragStart.Y)
            selectionBox2D.Size     = UDim2.fromOffset(0, 0)
            selectionBox2D.Visible  = true
            return
        end

        -- Normal / Group selection
        if Config.SelectionEnabled then
            local target = Mouse.Target
            if not target or not target:IsA("BasePart") or target.Anchored then return end

            if Config.GroupSelectionEnabled then
                -- FIX 3b: walk up to the nearest Model; if none (or it IS workspace),
                --         fall back to single-part behaviour instead of doing nothing.
                local root = target:FindFirstAncestorWhichIsA("Model")
                if not root or root == workspace then
                    -- No meaningful model container — toggle the part itself
                    if table.find(queuedObjects, target) then
                        removeFromQueue(target)
                    else
                        addToQueue(target)
                    end
                    return
                end

                -- FIX 3a: decide add/remove from the model-wide state
                local shouldRemove = isModelQueued(root)
                for _, part in ipairs(getModelParts(root)) do
                    if shouldRemove then
                        removeFromQueue(part)
                    else
                        addToQueue(part)
                    end
                end
            else
                if table.find(queuedObjects, target) then
                    removeFromQueue(target)
                else
                    addToQueue(target)
                end
            end
        end
    end)

    -- FIX 2: Drive the lasso box from RenderStepped instead of InputChanged.
    --        RenderStepped runs once per frame so it can never fire faster than
    --        the renderer, eliminating the event-flood lag InputChanged can cause.
    connections.LassoRender = RunService.RenderStepped:Connect(function()
        if not isDragging then return end

        local cur  = UIS:GetMouseLocation()
        local minX = math.min(dragStart.X, cur.X)
        local minY = math.min(dragStart.Y, cur.Y)
        local maxX = math.max(dragStart.X, cur.X)
        local maxY = math.max(dragStart.Y, cur.Y)

        selectionBox2D.Position = UDim2.fromOffset(minX, minY)
        selectionBox2D.Size     = UDim2.fromOffset(maxX - minX, maxY - minY)
    end)

    connections.InputEnded = UIS.InputEnded:Connect(function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not isDragging then return end

        isDragging             = false
        selectionBox2D.Visible = false

        local endPos = UIS:GetMouseLocation()
        local minX   = math.min(dragStart.X, endPos.X)
        local minY   = math.min(dragStart.Y, endPos.Y)
        local maxX   = math.max(dragStart.X, endPos.X)
        local maxY   = math.max(dragStart.Y, endPos.Y)

        -- Ignore accidental micro-drags (< 6 px in either axis)
        if (maxX - minX) < 6 or (maxY - minY) < 6 then return end

        -- FIX 1: WorldToViewportPoint now shares the same origin as
        --        UIS:GetMouseLocation() because IgnoreGuiInset = true.
        -- FIX 2: Collect first, then batch-add to avoid a single giant stall.
        -- FIX 1 continued: Drop the strict onScreen guard — a part can project
        --        into the drag rect even when partially off-screen.
        local toAdd = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored then
                local sp = Camera:WorldToViewportPoint(obj.Position)
                if sp.X >= minX and sp.X <= maxX and sp.Y >= minY and sp.Y <= maxY then
                    toAdd[#toAdd + 1] = obj
                end
            end
        end

        -- Batch insertion: add up to 30 objects per frame to stay smooth
        local BATCH = 30
        for i = 1, #toAdd, BATCH do
            for j = i, math.min(i + BATCH - 1, #toAdd) do
                addToQueue(toAdd[j])
            end
            if i + BATCH <= #toAdd then
                task.wait()   -- yield for one frame between batches
            end
        end

        Library:Notify("Lasso", "Selected " .. #toAdd .. " object(s).", 2)
    end)
end

return LooseObjectTeleport

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

    -- Returns current one-way latency in seconds (clamped to sane range).
    local function getPing()
        local ok, ping = pcall(function()
            return Players.LocalPlayer:GetNetworkPing()
        end)
        return math.clamp(ok and ping or 0.1, 0.02, 1.0)
    end

    -- Ping-aware task.wait: adds 1.5× the excess ping above 80 ms as a buffer
    -- so every timed operation stays ahead of server corrections.
    local function syncWait(base)
        local extra = math.max(0, getPing() - 0.08) * 1.5
        task.wait(base + extra)
    end

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

    -- Finds the best screen-space pixel to click for a given BasePart.
    --
    -- Strategy: sample the object center + all 6 face-centers (inset 40 % from
    -- the surface to avoid edge clipping).  For each candidate, fire a raycast
    -- from the camera through that pixel and confirm the ray actually lands on
    -- the target object.  The first confirmed hit is returned; if none pass the
    -- raycast check we fall back to the raw center so the caller can still try.
    --
    -- Returns: Vector2 screen position, or nil if the object is fully off-screen.
    local function getPreciseScreenPos(obj)
        if not obj or not obj.Parent then return nil end

        local rayParams = RaycastParams.new()
        rayParams.FilterType                  = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances  = { Player.Character }

        -- 7 sample points in object-local space (center + face centres at 40 % size)
        local s = obj.Size * 0.4
        local offsets = {
            Vector3.zero,
            Vector3.new( s.X, 0,    0   ),
            Vector3.new(-s.X, 0,    0   ),
            Vector3.new(0,    s.Y,  0   ),
            Vector3.new(0,   -s.Y,  0   ),
            Vector3.new(0,    0,    s.Z ),
            Vector3.new(0,    0,   -s.Z ),
        }

        local fallbackScreen = nil

        for _, offset in ipairs(offsets) do
            local worldPt  = obj.CFrame:PointToWorldSpace(offset)
            local sp, onScreen = Camera:WorldToViewportPoint(worldPt)
            if onScreen then
                local screen2 = Vector2.new(sp.X, sp.Y)
                if not fallbackScreen then
                    fallbackScreen = screen2   -- store first visible point as fallback
                end
                -- Confirm via raycast that this pixel actually hits our object
                local ray    = Camera:ScreenPointToRay(sp.X, sp.Y)
                local result = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
                if result and result.Instance == obj then
                    return screen2   -- confirmed hit — use this point
                end
            end
        end

        return fallbackScreen   -- best-effort fallback (unconfirmed but on-screen)
    end

    -- Orbit the object at `dist` studs in 8 horizontal directions + slight elevation
    -- and return the first CFrame that has an unobstructed raycast to the object.
    -- Falls back to the raw -Z offset if nothing clear is found.
    local function findViewCFrame(obj)
        if not obj or not obj.Parent then return CFrame.new(obj.Position) end

        local dist = math.max(obj.Size.Magnitude + 3, 7)
        local elev = 2   -- studs above object centre

        local params = RaycastParams.new()
        params.FilterType                 = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { Player.Character }

        for deg = 0, 315, 45 do
            local rad       = math.rad(deg)
            local offset    = Vector3.new(math.sin(rad) * dist, elev, math.cos(rad) * dist)
            local candidate = obj.Position + offset
            local toObj     = (obj.Position - candidate).Unit
            local result    = workspace:Raycast(candidate, toObj * (dist + 4), params)
            if result and result.Instance == obj then
                return CFrame.new(candidate, obj.Position)
            end
        end

        -- Nothing clear found — use raw fallback
        return CFrame.new(obj.Position + Vector3.new(0, elev, -dist), obj.Position)
    end

    -- Walk the ray from the camera to `obj`, collecting every BasePart that sits
    -- in the way, and make them client-invisible with LocalTransparencyModifier.
    -- Returns a restore table so the caller can undo this after the click.
    local function hideBlockers(obj)
        local hidden = {}
        if not obj or not obj.Parent then return hidden end

        local sp       = Camera:WorldToViewportPoint(obj.Position)
        local ray      = Camera:ScreenPointToRay(sp.X, sp.Y)
        local params   = RaycastParams.new()
        params.FilterType                 = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { Player.Character, obj }

        for _ = 1, 10 do   -- cap at 10 layers of obstruction
            local result  = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
            if not result then break end
            if result.Instance == obj then break end   -- clear path reached

            local blocker = result.Instance
            if not blocker:IsA("BasePart") then break end

            -- Hide client-side only; server never sees this change
            table.insert(hidden, { part = blocker, ltm = blocker.LocalTransparencyModifier })
            blocker.LocalTransparencyModifier = 1

            -- Extend the exclusion list so the next cast passes through it too
            local f = params.FilterDescendantsInstances
            f[#f + 1] = blocker
            params.FilterDescendantsInstances = f
        end

        return hidden
    end

    local function restoreBlockers(hidden)
        for _, entry in ipairs(hidden) do
            if entry.part and entry.part.Parent then
                entry.part.LocalTransparencyModifier = entry.ltm
            end
        end
    end

    local function isPlayerPart(obj)
        local char = Player.Character
        return char ~= nil and (obj == char or obj:IsDescendantOf(char))
    end

    local function addToQueue(obj)
        if obj and obj:IsA("BasePart") and not obj.Anchored and not isPlayerPart(obj) then
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

        if not hrp then return Library:Notify("Error", "No Character!", 3) end
        if #queuedObjects == 0 then return Library:Notify("Error", "Queue is empty!", 3) end

        Library:Notify("Processing", "Moving " .. #queuedObjects .. " items...", 3)

        task.spawn(function()
            local SNAP_THRESHOLD = 6   -- studs: closer than this = slingshot-back
            local MAX_RETRIES    = 4   -- attempts per object before giving up

            -- FIX 1: capture the player's real home position ONCE before any
            -- warping happens. Every item in the queue gets dragged to THIS spot.
            -- Re-reading hrp.Position inside the loop was the source of items
            -- landing on each other because the player was already warped away.
            local homePos = hrp.Position

            for i = #queuedObjects, 1, -1 do
                local obj = queuedObjects[i]

                if not (obj and obj.Parent and obj:IsA("BasePart")) then
                    local h = obj and obj:FindFirstChild("TP_Highlight")
                    if h then h:Destroy() end
                    table.remove(queuedObjects, i)
                    continue
                end

                local spawnPos = obj.Position   -- item's original position
                local grabbed  = false

                for attempt = 1, MAX_RETRIES do

                    -- 1. Find the best unobstructed viewpoint around the object
                    --    (8-angle orbit) instead of always warping due north.
                    --    Store the CFrame so we can reuse it for the desync check.
                    local viewCF = findViewCFrame(obj)
                    hrp.CFrame   = viewCF
                    syncWait(0.35)

                    -- 2. Attempt a raycast-confirmed click position.
                    --    If the object is still occluded from this angle, hide each
                    --    blocking part client-side (LocalTransparencyModifier = 1)
                    --    so the virtual click ray passes straight through to the target.
                    local screenPos = getPreciseScreenPos(obj)
                    local hidden    = {}

                    if not screenPos then
                        -- Still no confirmed hit — punch through any blockers
                        hidden     = hideBlockers(obj)
                        syncWait(0.05)
                        screenPos  = getPreciseScreenPos(obj)
                    end

                    if not screenPos then
                        -- Completely invisible even after hiding blockers — skip attempt
                        restoreBlockers(hidden)
                        syncWait(0.2)
                        continue
                    end

                    -- 3. Virtual grab at the confirmed pixel
                    VIM:SendMouseMoveEvent(screenPos.X, screenPos.Y, game)
                    syncWait(0.05)
                    VIM:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
                    syncWait(0.15)   -- hold time — raise if the game needs a longer press

                    -- 4. Drag to homePos then release; restore any hidden blockers
                    linearDrag(obj, homePos)
                    VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
                    stopAllMotion(obj)
                    restoreBlockers(hidden)

                    -- 5. Return player home so the next desync warp is a real move
                    hrp.CFrame = CFrame.new(homePos)
                    syncWait(0.15)

                    -- 6. Desync check: warp player back to the exact viewpoint we
                    --    grabbed from (near spawnPos with clear LOS) and wait for
                    --    any server slingshot correction to arrive.
                    hrp.CFrame = viewCF
                    syncWait(0.5)

                    if not obj or not obj.Parent then
                        grabbed = true
                        break
                    end

                    local distFromSpawn = (obj.Position - spawnPos).Magnitude
                    if distFromSpawn >= SNAP_THRESHOLD then
                        grabbed = true   -- object is away from its origin, grab held
                        break
                    end

                    Library:Notify(
                        "Desync",
                        "Item " .. i .. " snapped back (" .. attempt .. "/" .. MAX_RETRIES .. ")",
                        2
                    )
                end

                if not grabbed then
                    Library:Notify("Warning", "Item " .. i .. " failed after " .. MAX_RETRIES .. " attempts.", 3)
                end

                -- Return home before processing the next item
                hrp.CFrame = CFrame.new(homePos)

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
            if isPlayerPart(target) then return end   -- never select own character

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
            if obj:IsA("BasePart") and not obj.Anchored and not isPlayerPart(obj) then
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

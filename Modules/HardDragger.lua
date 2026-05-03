local HardDragger = {}

function HardDragger.Init(Tab)
    local RunService = game:GetService("RunService")
    local Players    = game:GetService("Players")

    local Player = Players.LocalPlayer
    local Mouse  = Player:GetMouse()
    local Camera = workspace.CurrentCamera

    local Config = {
        Enabled  = false,
        Distance = 10,   -- hold distance from camera in studs
    }

    local dragLoop   = nil
    local watcherConn = nil

    -- ── Stop controlling the current Dragger ──────────────────────
    local function StopControlling()
        if dragLoop then
            dragLoop:Disconnect()
            dragLoop = nil
        end
    end

    -- ── Start overriding a Dragger's position every frame ─────────
    local MAX_RADIUS = 20  -- max studs from player HRP

    local function StartControlling(dragger)
        StopControlling()

        -- Match hold distance to wherever the dragger spawned
        local holdDist = (Camera.CFrame.Position - dragger.Position).Magnitude
        if holdDist < 2 then holdDist = Config.Distance end

        -- Lock rotation to spawn orientation so it never drifts
        local lockedRotation = dragger.CFrame - dragger.CFrame.Position

        dragLoop = RunService.Heartbeat:Connect(function()
            -- Stop if dragger was removed or feature toggled off
            if not dragger or not dragger.Parent then
                StopControlling()
                return
            end
            if not Config.Enabled then return end

            local char = Player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")

            local targetPos = Camera.CFrame.Position
                + Mouse.UnitRay.Direction * holdDist

            -- Clamp to MAX_RADIUS studs from the player so third-person
            -- can't fling objects across the map
            if hrp then
                local toTarget = targetPos - hrp.Position
                if toTarget.Magnitude > MAX_RADIUS then
                    targetPos = hrp.Position + toTarget.Unit * MAX_RADIUS
                end
            end

            -- Apply position with locked rotation
            dragger.CFrame = CFrame.new(targetPos) * lockedRotation
        end)
    end

    -- ── Watch workspace for the Dragger to appear ─────────────────
    -- The connection is permanent so it works regardless of toggle timing.
    watcherConn = workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "Dragger" then return end
        if not Config.Enabled then return end

        StartControlling(child)

        -- Clean up automatically when the game removes the Dragger
        child.AncestryChanged:Connect(function()
            if not child.Parent then
                StopControlling()
            end
        end)
    end)

    -- ── UI ────────────────────────────────────────────────────────
    Tab:CreateSection("Hard Dragger")

    Tab:CreateToggle("Hard Dragger", false, function(state)
        Config.Enabled = state
        if not state then StopControlling() end
    end)

    Tab:CreateSlider("Hold Distance", 2, 50, Config.Distance, function(val)
        Config.Distance = val
    end)
end

return HardDragger

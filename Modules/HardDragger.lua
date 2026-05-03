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
    local function StartControlling(dragger)
        StopControlling()

        -- Match hold distance to wherever the dragger spawned
        local holdDist = (Camera.CFrame.Position - dragger.Position).Magnitude
        if holdDist < 2 then holdDist = Config.Distance end

        dragLoop = RunService.Heartbeat:Connect(function()
            -- Stop if dragger was removed or feature toggled off
            if not dragger or not dragger.Parent then
                StopControlling()
                return
            end
            if not Config.Enabled then return end

            local targetPos = Camera.CFrame.Position
                + Mouse.UnitRay.Direction * holdDist

            -- Preserve the dragger's current orientation so the game's
            -- own rotation logic isn't broken — only move it.
            dragger.CFrame = CFrame.new(targetPos)
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
    Tab:CreateToggle("Hard Dragger", false, function(state)
        Config.Enabled = state
        if not state then StopControlling() end
    end)
end

return HardDragger

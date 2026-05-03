local HardDragger = {}

function HardDragger.Init(Tab)
    local Players = game:GetService("Players")
    local Player  = Players.LocalPlayer

    local Config = { Enabled = false }

    local MASSLESS_PROPS = PhysicalProperties.new(
        0.01,  -- density   (near zero = near massless)
        0,     -- friction
        0,     -- elasticity
        0,     -- frictionWeight
        0      -- elasticityWeight
    )

    local _draggedPart    = nil
    local _originalProps  = nil
    local _hadCustomProps = false

    local function Restore()
        if not _draggedPart then return end
        pcall(function()
            if _hadCustomProps then
                _draggedPart.CustomPhysicalProperties = _originalProps
            else
                _draggedPart.CustomPhysicalProperties = nil
            end
        end)
        _draggedPart    = nil
        _originalProps  = nil
        _hadCustomProps = false
    end

    local function MakeMassless(part)
        if not part or not part:IsA("BasePart") then return end
        _draggedPart    = part
        _hadCustomProps = part.CustomPhysicalProperties ~= nil
        _originalProps  = part.CustomPhysicalProperties
        part.CustomPhysicalProperties = MASSLESS_PROPS
    end

    workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "Dragger" then return end
        if not Config.Enabled then return end

        -- Defer one frame so the weld connecting Dragger -> object is established
        task.defer(function()
            if not child.Parent then return end

            -- GetConnectedParts returns everything joined to this part by a joint
            local connected = child:GetConnectedParts(true)
            for _, part in ipairs(connected) do
                if part ~= child and part:IsA("BasePart") and not part.Anchored then
                    MakeMassless(part)
                    break
                end
            end

            -- Restore when Dragger is removed (mouse released)
            child.AncestryChanged:Connect(function()
                if not child.Parent then
                    Restore()
                end
            end)
        end)
    end)

    -- UI
    Tab:CreateSection("Hard Dragger")

    Tab:CreateToggle("Hard Dragger", false, function(state)
        Config.Enabled = state
        if not state then Restore() end
    end)
end

return HardDragger

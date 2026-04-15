local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.ItemTP_Enabled = false
    _G.ItemTP_Position = Vector3.zero
    _G.ItemTP_HoldTime = 0.1
    _G.ItemTP_Visual = nil
    
    local IGNORE_LIST = {"baseplate", "terrain", "ground", "map", "wall", "floor"}

    -- ===========================
    -- VISUAL DROP POINT
    -- ===========================
    local function UpdateVisual()
        if not _G.ItemTP_Visual then
            local p = Instance.new("Part")
            p.Name = "DropPointVisual"
            p.Shape = Enum.PartType.Cylinder
            p.Size = Vector3.new(0.5, 4, 4)
            p.Rotation = Vector3.new(0, 0, 90)
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(0, 255, 125)
            p.Transparency = 0.5
            p.Parent = workspace
            _G.ItemTP_Visual = p
        end
        _G.ItemTP_Visual.Position = _G.ItemTP_Position
    end

    -- ===========================
    -- TELEPORT LOGIC
    -- ===========================
    local function TeleportCorrectly(target)
        -- Determine the assembly root
        -- If it's a model, we need to move the PrimaryPart or ALL parts
        local targetPos = _G.ItemTP_Position + Vector3.new(0, 2, 0)
        
        if target:IsA("Model") then
            -- Moving a model via PivotTo is cleaner for the engine's internal physics
            target:PivotTo(CFrame.new(targetPos))
            
            -- Force wake-up for every part in the model
            for _, p in pairs(target:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CFrame = CFrame.new(targetPos) -- Snap every part
                    p.Velocity = Vector3.new(0, 0.1, 0)
                    p.RotVelocity = Vector3.zero
                end
            end
        elseif target:IsA("BasePart") then
            target.CFrame = CFrame.new(targetPos)
            target.Velocity = Vector3.new(0, 0.1, 0)
            target.RotVelocity = Vector3.zero
        end
    end

    local function IsMoveable(target)
        if not target or not target:IsA("BasePart") or target.Anchored then return false end
        local name = target.Name:lower()
        for _, b in pairs(IGNORE_LIST) do if name:find(b) then return false end end
        
        local model = target:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then return false end
        return true
    end

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Item Teleporter")
    
    local ControlsRow = Tab:CreateRow()
    ControlsRow:CreateAction("Set Drop Point", "Target", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            _G.ItemTP_Position = char.HumanoidRootPart.Position - Vector3.new(0, 3, 0)
            UpdateVisual()
        end
    end)

    Tab:CreateToggle("Enable Item TP", false, function(s) 
        _G.ItemTP_Enabled = s 
        if _G.ItemTP_Visual then _G.ItemTP_Visual.Transparency = s and 0.5 or 1 end
    end)

    Tab:CreateSlider("Hold (ms)", 50, 500, 100, function(v)
        _G.ItemTP_HoldTime = v / 1000
    end)

    -- ===========================
    -- INTERACTION
    -- ===========================
    local ClickStartTime = 0

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not _G.ItemTP_Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            ClickStartTime = tick()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not _G.ItemTP_Enabled or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        
        if (tick() - ClickStartTime) >= _G.ItemTP_HoldTime then
            local target = Mouse.Target
            if IsMoveable(target) then
                -- Check if it belongs to a model
                local model = target:FindFirstAncestorOfClass("Model")
                TeleportCorrectly(model or target)
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if _G.ItemTP_Enabled and _G.ItemTP_Visual then
            _G.ItemTP_Visual.CFrame = _G.ItemTP_Visual.CFrame * CFrame.Angles(0.05, 0, 0)
        end
    end)
end

return LooseObjectTeleport

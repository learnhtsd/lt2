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
    
    -- Only these will be blocked
    local IGNORE_LIST = {"baseplate", "terrain", "ground", "map", "wall", "floor", "sky"}

    -- ===========================
    -- VISUAL DROP POINT LOGIC
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
    -- THE FILTER LOGIC
    -- ===========================
    local function IsMoveableItem(target)
        if not target or not target:IsA("BasePart") then return false end
        
        -- 1. Ignore Map Names
        local name = target.Name:lower()
        for _, blocked in pairs(IGNORE_LIST) do
            if name:find(blocked) then return false end
        end

        -- 2. Strictly Unanchored (The only physical requirement left)
        if target.Anchored then return false end

        -- 3. Player/NPC Check (Safety)
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
            -- Sets it exactly where you are standing
            _G.ItemTP_Position = char.HumanoidRootPart.Position - Vector3.new(0, 3, 0)
            UpdateVisual()
        end
    end)

    Tab:CreateToggle("Enable Item TP", false, function(s) 
        _G.ItemTP_Enabled = s 
        if _G.ItemTP_Visual then 
            _G.ItemTP_Visual.Transparency = s and 0.5 or 1 
        end
    end)

    Tab:CreateSlider("Hold (ms)", 50, 500, 100, function(v)
        _G.ItemTP_HoldTime = v / 1000
    end)

    -- ===========================
    -- TELEPORT EXECUTION
    -- ===========================
    local function ForceTeleport(target)
        -- Find the root part to apply the CFrame to
        local root = target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")) or target
        
        if root and root:IsA("BasePart") then
            -- Teleport Logic
            local targetPos = _G.ItemTP_Position + Vector3.new(0, 2, 0)
            
            -- Frame 1: Initial Move
            root.CFrame = CFrame.new(targetPos)
            root.Velocity = Vector3.new(0, 2, 0) -- Kick physics to wake up
            
            -- Frame 2: Corrective Move (Prevents desync)
            task.delay(0.05, function()
                if root and root.Parent then
                    root.CFrame = CFrame.new(targetPos)
                    root.Velocity = Vector3.zero
                end
            end)
        end
    end

    -- ===========================
    -- INTERACTION LISTENERS
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
        
        -- Check if held long enough
        if (tick() - ClickStartTime) >= _G.ItemTP_HoldTime then
            local target = Mouse.Target
            if target and IsMoveableItem(target) then
                local parentModel = target:FindFirstAncestorOfClass("Model")
                ForceTeleport(parentModel or target)
            end
        end
    end)

    -- Spin the visual marker
    RunService.RenderStepped:Connect(function()
        if _G.ItemTP_Enabled and _G.ItemTP_Visual then
            _G.ItemTP_Visual.CFrame = _G.ItemTP_Visual.CFrame * CFrame.Angles(0.05, 0, 0)
        end
    end)
end

return LooseObjectTeleport

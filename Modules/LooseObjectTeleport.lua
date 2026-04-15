local LooseObjectTeleport = {}

function LooseObjectTeleport.Init(Tab)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    _G.ItemTP_Enabled = false
    _G.ItemTP_Position = Vector3.new(0, 0, 0)
    _G.ItemTP_HoldTime = 0.1
    _G.ItemTP_StrictPhysics = true -- Only move unanchored items

    local ClickStartTime = 0

    -- ===========================
    -- THE "LOOSE OBJECT" FILTER
    -- ===========================
    local function IsLooseObject(instance)
        if not instance then return false end
        
        -- 1. Ignore anything attached to a Player/NPC
        if instance:FindFirstAncestorOfClass("Model") and instance:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
            return false
        end

        -- 2. Check for Physics (The "Loose" Check)
        -- If it's a single part, check if it's anchored.
        -- If it's a model, check if its PrimaryPart or first child part is anchored.
        if instance:IsA("BasePart") then
            if _G.ItemTP_StrictPhysics and instance.Anchored then return false end
            return true
        elseif instance:IsA("Model") then
            local root = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
            if root and _G.ItemTP_StrictPhysics and root.Anchored then return false end
            return root ~= nil
        end

        return false
    end

    local function GetValidTarget(hit)
        if not hit then return nil end
        
        -- Check if the direct hit or its parent model is a "loose" object
        local model = hit:FindFirstAncestorOfClass("Model")
        if model and IsLooseObject(model) then return model end
        if IsLooseObject(hit) then return hit end
        
        return nil
    end

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Item Teleporter")
    
    local ControlsRow = Tab:CreateRow()
    ControlsRow:CreateAction("Set Drop Point", "Target", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            _G.ItemTP_Position = char.HumanoidRootPart.Position
            -- Optional: Add notification here
        end
    end)

    Tab:CreateToggle("Enable Item TP", false, function(s) 
        _G.ItemTP_Enabled = s 
    end)

    Tab:CreateSection("Safety Filters")
    
    Tab:CreateToggle("Strict Physics Only", true, function(s)
        _G.ItemTP_StrictPhysics = s
    end):AddTooltip("When ON, you can only TP unanchored (loose) parts. Prevents moving the map.")

    Tab:CreateSlider("Hold Duration (ms)", 50, 500, 100, function(v)
        _G.ItemTP_HoldTime = v / 1000
    end)

    -- ===========================
    -- INTERACTION LOGIC
    -- ===========================
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not _G.ItemTP_Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            ClickStartTime = tick()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not _G.ItemTP_Enabled or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        
        if (tick() - ClickStartTime) >= _G.ItemTP_HoldTime then
            local target = GetValidTarget(Mouse.Target)
            
            if target then
                -- Network ownership check is handled by the engine, 
                -- but CFrame/PivotTo is the most stable way to move items.
                if target:IsA("Model") then
                    target:PivotTo(CFrame.new(_G.ItemTP_Position))
                else
                    target.CFrame = CFrame.new(_G.ItemTP_Position)
                end
            end
        end
    end)
end

return LooseObjectTeleport

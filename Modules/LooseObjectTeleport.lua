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
    
    local IGNORE_LIST = {"Baseplate", "Terrain", "Ground", "Map", "Walls"}
    local ALLOWED_CLASSES = {"Part", "MeshPart", "UnionOperation", "CornerWedgePart", "WedgePart"}

    -- ===========================
    -- FILTER LOGIC
    -- ===========================
    local function IsMoveableItem(target)
        if not target or not target:IsA("BasePart") then return false end
        
        -- Ignore Map Names
        for _, name in pairs(IGNORE_LIST) do
            if target.Name:lower():find(name:lower()) then return false end
        end

        -- Check Class & Anchored
        local isSupported = false
        for _, className in pairs(ALLOWED_CLASSES) do
            if target:IsA(className) then isSupported = true; break end
        end
        
        if not isSupported or target.Anchored then return false end

        -- Ignore Players
        if target:FindFirstAncestorOfClass("Model") and target:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
            return false
        end

        -- Size Guard
        if target.Size.X > 50 or target.Size.Y > 50 or target.Size.Z > 50 then return false end

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
            _G.ItemTP_Position = char.HumanoidRootPart.Position
        end
    end)

    Tab:CreateToggle("Enable Item TP", false, function(s) 
        _G.ItemTP_Enabled = s 
    end)

    Tab:CreateSlider("Hold Duration (ms)", 50, 500, 100, function(v)
        _G.ItemTP_HoldTime = v / 1000
    end)

    -- ===========================
    -- THE TELEPORT FUNCTION
    -- ===========================
    local function TeleportItem(target)
        -- Find the root of the object (if it's a model)
        local itemToMove = nil
        if target:IsA("Model") then
            itemToMove = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        elseif target:IsA("BasePart") then
            itemToMove = target
        end

        if itemToMove then
            -- 1. Apply CFrame
            itemToMove.CFrame = CFrame.new(_G.ItemTP_Position + Vector3.new(0, 2, 0))
            
            -- 2. Force Physics Wake-up
            -- Sometimes unanchored parts "sleep" and won't move until hit.
            -- Setting a tiny velocity forces the engine to recalculate its position.
            itemToMove.Velocity = Vector3.new(0, 0.1, 0)
            itemToMove.RotVelocity = Vector3.new(0, 0, 0)
        end
    end

    -- ===========================
    -- INTERACTION LOGIC
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
            if target and IsMoveableItem(target) then
                -- Check if it's part of a model first
                local parentModel = target:FindFirstAncestorOfClass("Model")
                if parentModel then
                    TeleportItem(parentModel)
                else
                    TeleportItem(target)
                end
            end
        end
    end)
end

return LooseObjectTeleport

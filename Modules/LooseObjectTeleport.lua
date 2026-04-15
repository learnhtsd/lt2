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
    
    -- New strict filters
    local IGNORE_LIST = {"Baseplate", "Terrain", "Ground", "Map", "Walls"}
    local ALLOWED_CLASSES = {"Part", "MeshPart", "UnionOperation", "CornerWedgePart", "WedgePart"}

    -- ===========================
    -- THE "ACTUAL ITEM" FILTER
    -- ===========================
    local function IsMoveableItem(target)
        if not target then return false end
        
        -- 1. Check Blacklist Names
        for _, name in pairs(IGNORE_LIST) do
            if target.Name:lower():find(name:lower()) then return false end
        end

        -- 2. Check Class Whitelist (Prevents grabbing Folders/Scripts/etc)
        local isSupportedClass = false
        for _, className in pairs(ALLOWED_CLASSES) do
            if target:IsA(className) then
                isSupportedClass = true
                break
            end
        end
        if not isSupportedClass then return false end

        -- 3. Physics & Parent Check
        -- A 'loose' item shouldn't be anchored and shouldn't belong to a player
        if target.Anchored then return false end
        if target:FindFirstAncestorOfClass("Model") and target:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
            return false
        end

        -- 4. Size Guard (Optional but effective)
        -- Prevents moving massive unanchored map chunks. 
        -- If any dimension is > 50 studs, it's probably not a 'loose item'.
        if target.Size.X > 50 or target.Size.Y > 50 or target.Size.Z > 50 then
            return false
        end

        return true
    end

    local function GetValidTarget(hit)
        if not hit then return nil end
        
        -- Check if it's a part of a small model (like a log or tool)
        local model = hit:FindFirstAncestorOfClass("Model")
        if model then
            -- Check the PrimaryPart or the hit part itself
            local checkPart = model.PrimaryPart or hit
            if IsMoveableItem(checkPart) then return model end
        end
        
        -- Check the part directly
        if IsMoveableItem(hit) then return hit end
        
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
        end
    end)

    Tab:CreateToggle("Enable Item TP", false, function(s) 
        _G.ItemTP_Enabled = s 
    end)

    Tab:CreateSlider("Hold Duration (ms)", 50, 500, 100, function(v)
        _G.ItemTP_HoldTime = v / 1000
    end)

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
            local target = GetValidTarget(Mouse.Target)
            
            if target then
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

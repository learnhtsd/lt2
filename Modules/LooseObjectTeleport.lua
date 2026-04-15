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
    _G.ItemTP_Position = Vector3.new(0, 0, 0)
    _G.ItemTP_HoldTime = 0.1
    _G.ItemTP_ShowVisual = true

    local ClickStartTime = 0
    local VisualPart = nil

    -- ===========================
    -- UTILS
    -- ===========================
    local function GetValidTarget(hit)
        if not hit then return nil end
        -- Prioritize Models (like Wood/Items) but ignore Players
        local model = hit:FindFirstAncestorOfClass("Model")
        if model and not model:FindFirstChildOfClass("Humanoid") then return model end
        if hit:IsA("BasePart") and not hit.Parent:FindFirstChildOfClass("Humanoid") then return hit end
        return nil
    end

    local function CreateVisual()
        if VisualPart then VisualPart:Destroy() end
        VisualPart = Instance.new("Part")
        VisualPart.Name = "TP_Visual_Marker"
        VisualPart.Size = Vector3.new(4, 0.2, 4)
        VisualPart.Anchored = true
        VisualPart.CanCollide = false
        VisualPart.Material = Enum.Material.Neon
        VisualPart.Color = Color3.fromRGB(0, 255, 150)
        VisualPart.Transparency = 0.5
        VisualPart.Parent = workspace
    end

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    Tab:CreateSection("Item Teleporter")
    
    Tab:CreateInfoBox("Instructions", "1. Use <b>Set Drop Point</b> to save a location.\n2. Enable the <b>Toggle</b>.\n3. Hold <b>Left Click</b> on an object for 0.1s.")

    -- Controls Row
    local ControlsRow = Tab:CreateRow()
    
    ControlsRow:CreateAction("Set Drop Point", "Target", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            _G.ItemTP_Position = char.HumanoidRootPart.Position
            
            if _G.ItemTP_ShowVisual then
                CreateVisual()
                VisualPart.Position = _G.ItemTP_Position - Vector3.new(0, 3, 0)
            end
            
            -- Assuming your Library has a Notify function
            -- Library:Notify("Success", "Target position updated!", 2)
        end
    end)

    Tab:CreateToggle("Enable Item TP", false, function(s) 
        _G.ItemTP_Enabled = s 
        if not s and VisualPart then VisualPart:Destroy(); VisualPart = nil end
    end)

    Tab:CreateSection("Configuration")
    
    Tab:CreateSlider("Hold Duration (ms)", 50, 500, 100, function(v)
        _G.ItemTP_HoldTime = v / 1000
    end)

    Tab:CreateToggle("Show Visual Marker", true, function(s)
        _G.ItemTP_ShowVisual = s
        if not s and VisualPart then VisualPart:Destroy(); VisualPart = nil end
    end)

    -- ===========================
    -- LOGIC LISTENERS
    -- ===========================
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

    -- Keep visual updated or handled via Heartbeat if you want it to pulse
    RunService.Heartbeat:Connect(function()
        if _G.ItemTP_Enabled and _G.ItemTP_ShowVisual and VisualPart then
            VisualPart.CFrame = VisualPart.CFrame * CFrame.Angles(0, math.rad(2), 0)
        end
    end)
end

return LooseObjectTeleport

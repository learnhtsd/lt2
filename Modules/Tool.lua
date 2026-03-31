local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local Selection = {}

-- Variables for toggles
local IsLassoing = false
local IsClickSelecting = false
local LassoRange = 25

-- LT2 Dragging Remote
local DragRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Interaction") 
    and game:GetService("ReplicatedStorage").Interaction:FindFirstChild("ClientIsDragging")

-- Check if object is moveable (Loose wood or items without an anchor)
local function IsMoveable(obj)
    if not obj or not obj:IsA("Model") then return false end
    
    -- Check for LT2 wood tags or lack of an 'Owner' property on a plot
    if obj:FindFirstChild("TreeClass") or obj:FindFirstChild("WoodSection") then return true end
    
    -- Check if it's a loose item/box
    local main = obj:FindFirstChild("Main") or obj:FindFirstChildOfClass("BasePart")
    if main and not main.Anchored then return true end
    
    return false
end

local function GetTargetRoot(obj)
    if not obj then return nil end
    if obj.Name == "WoodSection" or obj.Name == "Base" then return obj.Parent end
    if obj:IsA("BasePart") and obj.Parent:IsA("Model") then return obj.Parent end
    return obj
end

function Tool.Init(Tab)
    Tab:CreateSection("Object Management")
    
    -- Using a Label instead of updating the Section Title to avoid crashes
    local CountLabel = Tab:CreateLabel("Items Selected: 0")

    local function UpdateUI()
        -- Safe way to update the label
        if CountLabel and CountLabel.SetText then
            CountLabel:SetText("Items Selected: " .. #Selection)
        end
    end

    Tab:CreateToggle("Click Select", false, function(state)
        IsClickSelecting = state
    end)

    Tab:CreateToggle("Lasso (Auto-Select Nearby)", false, function(state)
        IsLassoing = state
        if IsLassoing then
            task.spawn(function()
                while IsLassoing do
                    local char = Player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        for _, obj in pairs(workspace:GetChildren()) do
                            if IsMoveable(obj) and not table.find(Selection, obj) then
                                local part = obj:FindFirstChildOfClass("BasePart")
                                if part and (char.HumanoidRootPart.Position - part.Position).Magnitude < LassoRange then
                                    table.insert(Selection, obj)
                                    local h = Instance.new("Highlight")
                                    h.Name = "SelectionHighlight"
                                    h.FillColor = Color3.fromRGB(0, 255, 255)
                                    h.Parent = obj
                                    UpdateUI()
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end)

    -- Mouse Click Logic for the Click Selector
    local Connection
    Connection = Mouse.Button1Down:Connect(function()
        if IsClickSelecting and Mouse.Target then
            local root = GetTargetRoot(Mouse.Target)
            if root and IsMoveable(root) and not table.find(Selection, root) then
                table.insert(Selection, root)
                local h = Instance.new("Highlight")
                h.Name = "SelectionHighlight"
                h.FillColor = Color3.fromRGB(0, 255, 0)
                h.Parent = root
                UpdateUI()
            end
        end
    end)

    Tab:CreateAction("Bring All Selected", "Teleport", function()
        local char = Player.Character
        if not char or #Selection == 0 then return end
        
        -- Target position: 5 studs in front of player
        local targetPos = char.HumanoidRootPart.Position + (char.HumanoidRootPart.CFrame.LookVector * 7)
        
        for i, obj in pairs(Selection) do
            local main = obj:FindFirstChild("Main") or obj:FindFirstChildOfClass("BasePart")
            if main then
                -- 1. Move the CFrame
                main.CFrame = CFrame.new(targetPos + Vector3.new(0, i * 2, 0))
                
                -- 2. Force network ownership (wake up physics)
                if DragRemote then
                    DragRemote:FireServer(obj)
                end
            end
        end
        print("Moved " .. #Selection .. " items.")
    end)

    Tab:CreateAction("Clear Selection", "Deselect All", function()
        for _, obj in pairs(Selection) do
            if obj:FindFirstChild("SelectionHighlight") then
                obj.SelectionHighlight:Destroy()
            end
        end
        Selection = {}
        UpdateUI()
    end)
end

return Tool

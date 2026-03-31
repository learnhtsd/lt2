local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local Selection = {}

-- Variables for toggles
local IsLassoing = false
local IsClickSelecting = false
local LassoRange = 25
local InspectorEnabled = false -- New Toggle Variable

-- LT2 Dragging Remote
local DragRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Interaction") 
    and game:GetService("ReplicatedStorage").Interaction:FindFirstChild("ClientIsDragging")

-- Check if object is moveable
local function IsMoveable(obj)
    if not obj or not obj:IsA("Model") then return false end
    if obj:FindFirstChild("TreeClass") or obj:FindFirstChild("WoodSection") then return true end
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
    
    local CountLabel = Tab:CreateLabel("Items Selected: 0")
    local InspectorLabel = Tab:CreateLabel("Hovering: None") -- Label for Object Name

    local function UpdateUI()
        if CountLabel and CountLabel.SetText then
            CountLabel:SetText("Items Selected: " .. #Selection)
        end
    end

    -- ===========================
    -- NEW: OBJECT INSPECTOR
    -- ===========================
    Tab:CreateToggle("Object Inspector", false, function(state)
        InspectorEnabled = state
        if not state then
            InspectorLabel:SetText("Hovering: None")
        end
    end)

    -- Loop to update Inspector Label
    game:GetService("RunService").RenderStepped:Connect(function()
        if InspectorEnabled then
            local target = Mouse.Target
            if target then
                -- Shows Name [Class] | Parent Name
                InspectorLabel:SetText(string.format("Hovering: %s [%s] | Parent: %s", 
                    target.Name, 
                    target.ClassName, 
                    (target.Parent and target.Parent.Name or "None")
                ))
            else
                InspectorLabel:SetText("Hovering: Nil")
            end
        end
    end)

    -- ===========================
    -- EXISTING TOOLS
    -- ===========================
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

    Mouse.Button1Down:Connect(function()
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
        local targetPos = char.HumanoidRootPart.Position + (char.HumanoidRootPart.CFrame.LookVector * 7)
        for i, obj in pairs(Selection) do
            local main = obj:FindFirstChild("Main") or obj:FindFirstChildOfClass("BasePart")
            if main then
                main.CFrame = CFrame.new(targetPos + Vector3.new(0, i * 2, 0))
                if DragRemote then DragRemote:FireServer(obj) end
            end
        end
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

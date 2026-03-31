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
    if not obj then return false end
    -- Ignore the baseplate or static map parts
    if obj.Parent == workspace and (obj.Name == "Base" or obj.Name == "WoodSection") then return true end
    -- Check if it's a model with wood tags
    if obj:FindFirstChild("TreeClass") or obj:FindFirstChild("WoodSection") then return true end
    -- Loose items usually have a 'Main' part that isn't anchored
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

    local function UpdateUI()
        CountLabel:SetText("Items Selected: " .. #Selection)
    end

    Tab:CreateToggle("Click Select", false, function(state)
        IsClickSelecting = state
    end)

    Tab:CreateToggle("Lasso (Proximity)", false, function(state)
        IsLassoing = state
        task.spawn(function()
            while IsLassoing do
                local char = Player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    for _, obj in pairs(workspace:GetChildren()) do
                        if IsMoveable(obj) then
                            local part = obj:FindFirstChildOfClass("BasePart")
                            if part and (char.HumanoidRootPart.Position - part.Position).Magnitude < LassoRange then
                                if not table.find(Selection, obj) then
                                    table.insert(Selection, obj)
                                    local h = Instance.new("Highlight", obj)
                                    h.FillColor = Color3.fromRGB(0, 255, 255)
                                    UpdateUI()
                                end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end)

    -- Mouse Click Logic
    Mouse.Button1Down:Connect(function()
        if IsClickSelecting and Mouse.Target then
            local root = GetTargetRoot(Mouse.Target)
            if root and IsMoveable(root) and not table.find(Selection, root) then
                table.insert(Selection, root)
                local h = Instance.new("Highlight", root)
                h.FillColor = Color3.fromRGB(0, 255, 0)
                UpdateUI()
            end
        end
    end)

    Tab:CreateAction("Bring Selected", "Teleport", function()
        local char = Player.Character
        if not char or #Selection == 0 then return end
        
        local pos = char.HumanoidRootPart.Position + (char.HumanoidRootPart.CFrame.LookVector * 5)
        
        for i, obj in pairs(Selection) do
            local main = obj:FindFirstChild("Main") or obj:FindFirstChildOfClass("BasePart")
            if main then
                -- In LT2, we 'SetNetworkOwner' by interacting or using the Drag Remote
                -- Force CFrame move
                main.CFrame = CFrame.new(pos + Vector3.new(0, i * 1.5, 0))
                
                -- Tell the server we are 'holding' it to update physics
                if DragRemote then
                    DragRemote:FireServer(obj)
                end
            end
        end
    end)

    Tab:CreateAction("Deselect All", "Clear", function()
        for _, obj in pairs(Selection) do
            if obj:FindFirstChild("Highlight") then obj.Highlight:Destroy() end
        end
        Selection = {}
        UpdateUI()
    end)
end

return Tool

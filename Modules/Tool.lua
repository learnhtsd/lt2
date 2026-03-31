local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local Selection = {} -- Stores the selected objects

-- Configuration
local LassoRange = 20 -- How far the lasso reaches
local IsLassoing = false
local IsClickSelecting = false

-- Function to check if an item is already selected
local function IsSelected(obj)
    for _, v in pairs(Selection) do
        if v == obj then return true end
    end
    return false
end

-- Function to find the actual "Root" of an object (LT2 uses complex models)
local function GetTargetRoot(obj)
    if not obj then return nil end
    -- If it's wood, find the main log/plank model
    if obj.Name == "WoodSection" or obj.Name == "Base" then
        return obj.Parent
    -- If it's a loose item/furniture
    elseif obj:FindFirstAncestor("Folder") or obj.Parent == workspace then
        return obj
    end
    return obj
end

function Tool.Init(Tab)
    local ToolSection = Tab:CreateSection("Object Tools (Selected: 0)")

    -- Update UI Label
    local function UpdateCount()
        ToolSection:SetText("Object Tools (Selected: " .. #Selection .. ")")
    end

    Tab:CreateToggle("Click to Select", false, function(state)
        IsClickSelecting = state
    end)

    Tab:CreateToggle("Lasso Tool (Auto-Select Nearby)", false, function(state)
        IsLassoing = state
        task.spawn(function()
            while IsLassoing do
                local char = Player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    -- Scan workspace for loose items near player
                    for _, obj in pairs(workspace:GetChildren()) do
                        if obj:IsA("Model") and obj:FindFirstChild("Main") or obj:FindFirstChild("WoodSection") then
                            local part = obj:FindFirstChildOfClass("BasePart")
                            if part then
                                local dist = (char.HumanoidRootPart.Position - part.Position).Magnitude
                                if dist < LassoRange and not IsSelected(obj) then
                                    table.insert(Selection, obj)
                                    -- Optional: Highlight effect
                                    local h = Instance.new("Highlight", obj)
                                    h.FillColor = Color3.fromRGB(0, 255, 255)
                                    UpdateCount()
                                end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end)

    -- Click Logic for Single Selection
    Mouse.Button1Down:Connect(function()
        if IsClickSelecting and Mouse.Target then
            local root = GetTargetRoot(Mouse.Target)
            if root and not IsSelected(root) then
                table.insert(Selection, root)
                local h = Instance.new("Highlight", root)
                h.FillColor = Color3.fromRGB(0, 255, 0)
                UpdateCount()
            end
        end
    end)

    Tab:CreateAction("Teleport Selected", "Bring to Me", function()
        local char = Player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local targetPos = char.HumanoidRootPart.CFrame * CFrame.new(0, 5, -5) -- 5 studs in front
        
        for i, obj in pairs(Selection) do
            local mainPart = obj:FindFirstChild("Main") or obj:FindFirstChildOfClass("BasePart")
            if mainPart then
                -- Check for LT2 Owner permissions if necessary
                mainPart.CFrame = targetPos * CFrame.new(0, i * 2, 0) -- Stack them
            end
        end
        print("Teleported " .. #Selection .. " items.")
    end)

    Tab:CreateAction("Deselect All", "Clear", function()
        for _, obj in pairs(Selection) do
            if obj:FindFirstChild("Highlight") then
                obj.Highlight:Destroy()
            end
        end
        Selection = {}
        UpdateCount()
        print("Selection cleared.")
    end)
end

return Tool

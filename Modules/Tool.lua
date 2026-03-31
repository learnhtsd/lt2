local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local Selection = {}

-- Variables for toggles
local IsLassoing = false
local IsClickSelecting = false
local LassoRange = 25
local InspectorEnabled = false 

-- LT2 Dragging Remote
local DragRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Interaction") 
    and game:GetService("ReplicatedStorage").Interaction:FindFirstChild("ClientIsDragging")

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

-- Added 'Lib' parameter to receive the Library table
function Tool.Init(Tab, Lib)
    Tab:CreateSection("Object Management")
    
    local CountLabel = Tab:CreateLabel("Items Selected: 0")
    local InspectorLabel = Tab:CreateLabel("Hovering: None")

    local function UpdateUI()
        if CountLabel and CountLabel.SetText then
            CountLabel:SetText("Items Selected: " .. #Selection)
        end
    end

    -- ===========================
    -- OBJECT INSPECTOR w/ NOTIFS
    -- ===========================
    Tab:CreateToggle("Object Inspector", false, function(state)
        InspectorEnabled = state
        if state then
            Lib:Notify("Inspector", "Enabled! Right-click an object to log its name.", 4)
        else
            InspectorLabel:SetText("Hovering: None")
            Lib:Notify("Inspector", "Disabled.", 2)
        end
    end)

    -- Right Click to Log/Notify Name
    Mouse.Button2Down:Connect(function()
        if InspectorEnabled and Mouse.Target then
            local t = Mouse.Target
            local info = string.format("Name: %s | Class: %s", t.Name, t.ClassName)
            
            -- Send the notification
            Lib:Notify("Object Identified", info, 5)
            
            -- Print to console for easy copying
            print("--------------------------")
            print("INSPECTED OBJECT:")
            print("Name: " .. t.Name)
            print("Class: " .. t.ClassName)
            print("Parent: " .. (t.Parent and t.Parent.Name or "Nil"))
            print("--------------------------")
        end
    end)

    game:GetService("RunService").RenderStepped:Connect(function()
        if InspectorEnabled then
            local target = Mouse.Target
            if target then
                InspectorLabel:SetText(string.format("Hovering: %s [%s]", target.Name, target.ClassName))
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
        Lib:Notify("Tool", state and "Click Selection Active" or "Click Selection Off", 2)
    end)

    Tab:CreateToggle("Lasso (Auto-Select)", false, function(state)
        IsLassoing = state
        Lib:Notify("Tool", state and "Lasso Started" or "Lasso Stopped", 2)
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
        if #Selection == 0 then 
            Lib:Notify("Error", "No items selected to bring!", 3)
            return 
        end
        
        local char = Player.Character
        local targetPos = char.HumanoidRootPart.Position + (char.HumanoidRootPart.CFrame.LookVector * 7)
        
        for i, obj in pairs(Selection) do
            local main = obj:FindFirstChild("Main") or obj:FindFirstChildOfClass("BasePart")
            if main then
                main.CFrame = CFrame.new(targetPos + Vector3.new(0, i * 2, 0))
                if DragRemote then DragRemote:FireServer(obj) end
            end
        end
        Lib:Notify("Success", "Moved " .. #Selection .. " items.", 3)
    end)

    Tab:CreateAction("Clear Selection", "Deselect All", function()
        local count = #Selection
        for _, obj in pairs(Selection) do
            if obj:FindFirstChild("SelectionHighlight") then
                obj.SelectionHighlight:Destroy()
            end
        end
        Selection = {}
        UpdateUI()
        Lib:Notify("Tool", "Cleared " .. count .. " items from selection.", 2)
    end)
end

return Tool

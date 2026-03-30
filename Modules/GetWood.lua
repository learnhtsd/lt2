local GetWood = {}

-- Variables to track state
local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

-- List of all LT2 Trees
local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Utility: Find the closest tree of selected type
local function GetNearestTree(treeName)
    local closestTree = nil
    local shortestDist = math.huge
    
    for _, tree in pairs(workspace:GetChildren()) do
        -- LT2 trees usually have a 'TreeClass' or 'WoodID' tag
        if tree:FindFirstChild("TreeClass") and tree.TreeClass.Value == treeName then
            local woodPart = tree:FindFirstChild("WoodSection")
            if woodPart then
                local dist = (Character.HumanoidRootPart.Position - woodPart.Position).Magnitude
                if dist < shortestDist then
                    closestTree = tree
                    shortestDist = dist
                end
            end
        end
    end
    return closestTree
end

function GetWood.Init(Tab)
    Tab:CreateSection("Wood Management")

    -- 1. Tree Dropdown
    Tab:CreateDropdown("Select Tree", TreeTypes, "Oak", function(choice)
        SelectedTree = choice
    end)

    -- 2. The "Get Wood" Button
    Tab:CreateAction("Auto Farm", "Start", function()
        if IsFarming then return end
        IsFarming = true
        
        local Root = Character.HumanoidRootPart
        local OldPos = Root.CFrame
        local TargetTree = GetNearestTree(SelectedTree)

        if not TargetTree then
            warn("No " .. SelectedTree .. " found!")
            IsFarming = false
            return
        end

        -- Teleport to Tree
        Root.CFrame = TargetTree.WoodSection.CFrame * CFrame.new(0, 0, 3)
        task.wait(0.5)

        -- Cutting Logic
        -- Note: This assumes you have an axe equipped. 
        -- LT2 requires firing a remote to 'hit' the tree.
        local Tool = Character:FindFirstChildOfClass("Tool")
        if Tool and Tool:FindFirstChild("RemoteClick") then
            repeat
                Tool.RemoteClick:FireServer({
                    ["Part"] = TargetTree.WoodSection,
                    ["Pos"] = TargetTree.WoodSection.Position,
                    ["Normal"] = Vector3.new(0, 1, 0)
                })
                task.wait(0.1) -- Swing speed
            until not TargetTree:Parent() or not IsFarming
        else
            warn("Please equip an axe first!")
        end

        -- Teleport Back
        Root.CFrame = OldPos
        
        -- Optional: Bring wood back logic
        -- This usually involves looping through 'dropped' parts and setting CFrame
        task.wait(0.5)
        for _, v in pairs(workspace.LogFolder:GetChildren()) do
            if v:FindFirstChild("Owner") and v.Owner.Value == Player then
                v.CFrame = OldPos * CFrame.new(0, 5, 0)
            end
        end

        IsFarming = false
    end)
    
    Tab:CreateToggle("Stop Farming", false, function(v)
        if not v then IsFarming = false end
    end)
end

return GetWood

local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Finds the remote even if it's hidden in a folder inside the axe
local function FindAxeRemote(tool)
    if not tool then return nil end
    -- Check common names first
    local common = tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click")
    if common and common:IsA("RemoteEvent") then return common end
    
    -- Search everywhere inside the tool for any RemoteEvent
    for _, obj in pairs(tool:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local function GetNearestTree(treeName)
    local closestTree = nil
    local shortestDist = math.huge
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("StringValue") and obj.Name == "TreeClass" and obj.Value == treeName then
            local treeModel = obj.Parent
            local cutPart = treeModel:FindFirstChild("WoodSection") or treeModel:FindFirstChild("Base")
            
            if cutPart and cutPart:IsA("BasePart") then
                local dist = (char.HumanoidRootPart.Position - cutPart.Position).Magnitude
                if dist < shortestDist then
                    closestTree = treeModel
                    shortestDist = dist
                end
            end
        end
    end
    return closestTree
end

function GetWood.Init(Tab)
    Tab:CreateSection("Wood Management")

    Tab:CreateDropdown("Select Tree Type", TreeTypes, "Oak", function(choice)
        SelectedTree = choice
    end)

    Tab:CreateAction("Auto Farm", "Start", function()
        if IsFarming then return end
        
        local char = Player.Character
        local tool = char:FindFirstChildOfClass("Tool")
        
        -- If not in hand, check backpack and try to equip it
        if not tool then
            local backpackTool = Player.Backpack:FindFirstChildOfClass("Tool")
            if backpackTool then
                backpackTool.Parent = char
                task.wait(0.5)
                tool = backpackTool
            end
        end

        local remote = FindAxeRemote(tool)
        
        if not tool or not remote then
            warn("ERROR: No Axe found in hand or backpack!")
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("ERROR: No " .. SelectedTree .. " trees found nearby.")
            return
        end

        IsFarming = true
        print("Farming started using Remote: " .. remote.Name)
        
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Move to tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        -- Chop Loop
        while IsFarming and target and target.Parent do
            remote:FireServer({
                ["Part"] = woodSection,
                ["Pos"] = woodSection.Position,
                ["Normal"] = Vector3.new(0, 1, 0)
            })
            task.wait(0.2)
            
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                break
            end
        end

        char.HumanoidRootPart.CFrame = oldPos
        IsFarming = false
        print("Done!")
    end)

    Tab:CreateToggle("Stop Farming", false, function(state)
        IsFarming = false
    end)
end

return GetWood

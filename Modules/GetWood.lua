local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Brute force search for the remote inside your character
local function ForceGetRemote()
    local char = Player.Character
    if not char then return nil end

    -- Scan everything currently attached to your character
    for _, item in pairs(char:GetChildren()) do
        if item:IsA("Tool") or item:IsA("Model") then
            -- Look deep inside this item for any RemoteEvent
            for _, descendant in pairs(item:GetDescendants()) do
                if descendant:IsA("RemoteEvent") then
                    print("Found Remote: " .. descendant.Name .. " inside " .. item.Name)
                    return descendant, item
                end
            end
        end
    end
    return nil, nil
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
        
        local remote, axeObject = ForceGetRemote()
        
        if not remote then
            warn("CRITICAL ERROR: No RemoteEvent found inside your held tool!")
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found nearby.")
            return
        end

        IsFarming = true
        print("Success! Using: " .. axeObject.Name .. " | Remote: " .. remote.Name)
        
        local char = Player.Character
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Teleport to tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        -- Chop Loop
        while IsFarming and target and target.Parent do
            -- Safety check: ensure woodSection still exists
            if not woodSection or not woodSection.Parent then
                woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")
            end
            
            if woodSection then
                remote:FireServer({
                    ["Part"] = woodSection,
                    ["Pos"] = woodSection.Position,
                    ["Normal"] = Vector3.new(0, 1, 0)
                })
            end
            
            task.wait(0.2)
            
            -- If the tree breaks into logs, stop chopping
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                break
            end
        end

        char.HumanoidRootPart.CFrame = oldPos
        IsFarming = false
        print("Farm Cycle Finished.")
    end)

    Tab:CreateToggle("Stop Farming", false, function(state)
        IsFarming = false
    end)
end

return GetWood

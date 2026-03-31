local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- This function now scans YOUR CHARACTER directly for anything that looks like an axe
local function GetAxeAndRemote()
    local char = Player.Character
    if not char then return nil, nil end

    -- 1. Look for a tool in the character (equipped)
    local tool = char:FindFirstChildOfClass("Tool")
    
    -- 2. If no 'Tool' class found, look for any Model in the character that might be the axe
    if not tool then
        for _, obj in pairs(char:GetChildren()) do
            if obj:IsA("Model") and (obj:FindFirstChild("RemoteClick") or obj:FindFirstChild("Click")) then
                tool = obj
                break
            end
        end
    end

    -- 3. Find the Remote inside whatever we found
    if tool then
        local remote = tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click")
        if not remote then
            -- Last resort: find any RemoteEvent inside the object
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    remote = v
                    break
                end
            end
        end
        return tool, remote
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
        
        local tool, remote = GetAxeAndRemote()
        
        if not tool or not remote then
            warn("STILL NOT FOUND. Name of what you are holding: " .. (Player.Character:FindFirstChildOfClass("Tool") and Player.Character:FindFirstChildOfClass("Tool").Name or "Nothing"))
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found nearby.")
            return
        end

        IsFarming = true
        print("Success! Using Axe: " .. tool.Name .. " | Remote: " .. remote.Name)
        
        local char = Player.Character
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Teleport
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

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
        print("Cycle Finished.")
    end)

    Tab:CreateToggle("Stop Farming", false, function(state)
        IsFarming = false
    end)
end

return GetWood

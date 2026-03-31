local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Deep search for trees (LT2 hides trees in folders sometimes)
local function GetNearestTree(treeName)
    local closestTree = nil
    local shortestDist = math.huge
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    for _, obj in pairs(workspace:GetDescendants()) do
        -- We look for the "TreeClass" value which identifies the wood type
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
    local Status = {Text = "Idle"} -- Simple status tracker

    Tab:CreateSection("Wood Management")

    Tab:CreateDropdown("Select Tree Type", TreeTypes, "Oak", function(choice)
        SelectedTree = choice
        print("Selected: " .. choice)
    end)

    Tab:CreateAction("Auto Farm", "Start", function()
        if IsFarming then return end
        
        -- 1. CHARACTER CHECK
        local char = Player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            warn("Character not loaded!")
            return
        end

        -- 2. AXE CHECK (Must be held in hand)
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then
            warn("Hold your axe in your hand first!")
            return
        end

        local remote = tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click")
        if not remote then
            warn("This tool doesn't have a valid RemoteClick event.")
            return
        end

        -- 3. TREE SEARCH
        print("Searching for " .. SelectedTree .. "...")
        local target = GetNearestTree(SelectedTree)
        
        if not target then
            warn("Could not find any " .. SelectedTree .. " in the workspace.")
            return
        end

        -- 4. START FARMING
        IsFarming = true
        print("Farming " .. target.Name)
        
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Teleport to tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        -- The Loop
        while IsFarming and target and target.Parent do
            -- LT2 Remote arguments: Part, Position, and Normal
            remote:FireServer({
                ["Part"] = woodSection,
                ["Pos"] = woodSection.Position,
                ["Normal"] = Vector3.new(0, 1, 0)
            })
            task.wait(0.2)
            
            -- Break if the wood is cut down
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                print("Tree harvested!")
                break
            end
        end

        -- 5. CLEANUP
        char.HumanoidRootPart.CFrame = oldPos
        IsFarming = false
        print("Teleported back. Farm done.")
    end)

    Tab:CreateToggle("Stop Farming", false, function(state)
        IsFarming = false
        print("Auto-farm disabled.")
    end)
end

return GetWood

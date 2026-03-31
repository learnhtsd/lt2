local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- We target the game's standard interaction remote directly
local InteractionRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Interaction") 
    and game:GetService("ReplicatedStorage").Interaction:FindFirstChild("RemoteProxy")

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
        
        -- Fallback: If no Interaction remote, search tool for ANY remote
        local remote = InteractionRemote
        if not remote and tool then
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                    remote = v
                    break
                end
            end
        end

        if not tool then
            warn("Please hold your axe!")
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found nearby.")
            return
        end

        IsFarming = true
        print("Farming started. Using tool: " .. tool.Name)
        
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Move to tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        while IsFarming and target and target.Parent do
            -- Re-check wood section if it updates
            woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")
            
            if woodSection then
                -- Standard LT2 Cut Argument structure
                local args = {
                    ["Part"] = woodSection,
                    ["Pos"] = woodSection.Position,
                    ["Normal"] = Vector3.new(0, 1, 0)
                }
                
                -- Fire the remote (Supports Event or Function)
                if remote then
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(args)
                    else
                        remote:InvokeServer(args)
                    end
                end
            end
            
            task.wait(0.18)
            
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

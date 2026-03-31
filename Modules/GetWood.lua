local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Use the most common interaction proxy for LT2
local Interaction = game:GetService("ReplicatedStorage"):FindFirstChild("Interaction")
local Remote = Interaction and (Interaction:FindFirstChild("RemoteProxy") or Interaction:FindFirstChild("VerifyAction"))

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
        
        if not tool then
            warn("Hold the axe in your hand before clicking Start!")
            return
        end

        -- Try to find the axe's specific remote or fall back to the global interaction
        local toolRemote = tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click")
        local activeRemote = toolRemote or Remote

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found nearby.")
            return
        end

        IsFarming = true
        
        -- Teleport Logic
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        print("Farming " .. SelectedTree .. " with " .. tool.Name)

        while IsFarming and target and target.Parent do
            woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")
            
            if woodSection and activeRemote then
                -- 1. Force the Axe to swing visually
                tool:Activate() 

                -- 2. Construct the data for the server
                local args = {
                    ["Part"] = woodSection,
                    ["Pos"] = woodSection.Position,
                    ["Normal"] = Vector3.new(0, 1, 0)
                }

                -- 3. Send the hit to the server
                if activeRemote:IsA("RemoteEvent") then
                    activeRemote:FireServer(args)
                elseif activeRemote:IsA("RemoteFunction") then
                    activeRemote:InvokeServer(args)
                end
            end
            
            -- Speed: 0.2 is the "Sweet Spot" for most LT2 axes to avoid lag-back
            task.wait(0.2)
            
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                break
            end
        end

        IsFarming = false
        print("Done.")
    end)

    Tab:CreateToggle("Stop", false, function(state)
        IsFarming = false
    end)
end

return GetWood

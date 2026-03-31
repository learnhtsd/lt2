local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Target the game's main interaction system
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
            warn("Equip your axe first!")
            return
        end

        -- Find the tool's specific remote if the global one isn't responding
        local toolRemote = tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click")
        local activeRemote = toolRemote or Remote

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found nearby.")
            return
        end

        IsFarming = true
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Move to tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        print("Attempting to chop with: " .. activeRemote.Name)

        while IsFarming and target and target.Parent do
            woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")
            
            if woodSection and activeRemote then
                -- Generate realistic click data
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                
                -- We "aim" from the player to the wood
                local direction = (woodSection.Position - char.HumanoidRootPart.Position).Unit * 10
                local result = workspace:Raycast(char.HumanoidRootPart.Position, direction, rayParams)

                local hitPos = result and result.Position or woodSection.Position
                local hitNormal = result and result.Normal or Vector3.new(0, 1, 0)

                local args = {
                    ["Part"] = woodSection,
                    ["Pos"] = hitPos,
                    ["Normal"] = hitNormal
                }

                -- Execute based on Remote type
                if activeRemote:IsA("RemoteEvent") then
                    activeRemote:FireServer(args)
                elseif activeRemote:IsA("RemoteFunction") then
                    activeRemote:InvokeServer(args)
                end
            end
            
            task.wait(0.2) -- LT2 anticheat is sensitive to speeds under 0.15
            
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                break
            end
        end

        IsFarming = false
        print("Chop sequence finished.")
    end)

    Tab:CreateToggle("Stop", false, function(state)
        IsFarming = false
    end)
end

return GetWood

local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Direct access to the game's interaction remote
local Interaction = game:GetService("ReplicatedStorage"):FindFirstChild("Interaction")
local Remote = Interaction and (Interaction:FindFirstChild("RemoteProxy") or Interaction:FindFirstChild("VerifyAction"))

local function GetNearestTree(treeName)
    local closestTree = nil
    local shortestDist = math.huge
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    for _, obj in pairs(workspace:GetDescendants()) do
        -- 1. Must be the right tree type
        -- 2. Must NOT be a plank (Planks usually don't have a 'TreeClass' value inside a 'Tree' model)
        if obj:IsA("StringValue") and obj.Name == "TreeClass" and obj.Value == treeName then
            local treeModel = obj.Parent
            
            -- ENSURE IT'S A STANDING TREE:
            -- Real trees in LT2 usually have a 'WoodSection' or 'Base' AND are not inside 'PlayerModels'
            if treeModel and not treeModel:FindFirstChild("Owner") then 
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
            warn("Please equip your axe!")
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No standing " .. SelectedTree .. " found. Make sure you aren't looking at planks!")
            return
        end

        IsFarming = true
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Move to the base of the tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        -- Determine the best remote to use
        local toolRemote = tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click")
        local activeRemote = toolRemote or Remote

        while IsFarming and target and target.Parent do
            -- Always target the LOWEST part of the tree
            woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")
            
            if woodSection and activeRemote then
                -- VISUAL SWING
                tool:Activate() 

                -- THE "GHOST MOUSE" BYPASS:
                -- We send the arguments directly. If the axe still requires a hover, 
                -- we use a Raycast to tell the server our 'Mouse' is hitting the part.
                local hitPos = woodSection.Position
                local hitNormal = Vector3.new(0, 1, 0)

                local args = {
                    ["Part"] = woodSection,
                    ["Pos"] = hitPos,
                    ["Normal"] = hitNormal
                }

                if activeRemote:IsA("RemoteEvent") then
                    activeRemote:FireServer(args)
                elseif activeRemote:IsA("RemoteFunction") then
                    activeRemote:InvokeServer(args)
                end
            end
            
            task.wait(0.2)
            
            -- Stop if the tree is gone or turned into logs
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                break
            end
        end

        IsFarming = false
        print("Farming complete.")
    end)

    Tab:CreateToggle("Stop", false, function(state)
        IsFarming = false
    end)
end

return GetWood

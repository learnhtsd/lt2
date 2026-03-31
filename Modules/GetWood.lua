local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

-- Improved tree detection
local function GetNearestTree(treeName)
    local closestTree = nil
    local shortestDist = math.huge
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    -- LT2 trees are usually directly in Workspace or a "Trees" folder
    for _, obj in pairs(workspace:GetChildren()) do
        -- Check if it's a Tree model (LT2 trees have a TreeClass value)
        local treeClass = obj:FindFirstChild("TreeClass")
        if treeClass and treeClass.Value == treeName then
            local woodSection = obj:FindFirstChild("WoodSection") or obj:FindFirstChild("Base")
            
            if woodSection then
                local dist = (char.HumanoidRootPart.Position - woodSection.Position).Magnitude
                if dist < shortestDist then
                    closestTree = obj
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
        print("Selected Tree: " .. choice)
    end)

    Tab:CreateAction("Auto Farm", "Start", function()
        if IsFarming then 
            print("Already farming!")
            return 
        end
        
        local char = Player.Character
        local tool = char:FindFirstChildOfClass("Tool")
        
        -- LT2 axes often use "RemoteClick" or just "Click"
        local remote = tool and (tool:FindFirstChild("RemoteClick") or tool:FindFirstChild("Click"))
        
        if not tool or not remote then
            warn("Check failed: Equip your axe first!")
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found in range.")
            return
        end

        print("Target found: " .. target.Name .. ". Starting farm...")
        IsFarming = true
        
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection") or target:FindFirstChild("Base")

        -- Teleport slightly above/beside the tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 2, 2)
        task.wait(0.5)

        -- Chop Loop
        while IsFarming and target and target.Parent do
            remote:FireServer({
                ["Part"] = woodSection,
                ["Pos"] = woodSection.Position,
                ["Normal"] = Vector3.new(0, 1, 0)
            })
            task.wait(0.2) -- Slightly slower to prevent kick/lag
            
            -- Exit if the tree is destroyed
            if not target:FindFirstChild("WoodSection") and not target:FindFirstChild("Base") then
                break
            end
        end

        print("Tree cut. Returning...")
        char.HumanoidRootPart.CFrame = oldPos
        
        -- Bring wood back (checks LogFolder for logs owned by player)
        task.wait(1)
        local logFolder = workspace:FindFirstChild("LogFolder")
        if logFolder then
            for _, log in pairs(logFolder:GetChildren()) do
                if log:FindFirstChild("Owner") and log.Owner.Value == Player then
                    log.CFrame = oldPos * CFrame.new(0, 10, 0)
                end
            end
        end
        
        IsFarming = false
        print("Farm cycle complete.")
    end)

    Tab:CreateToggle("Stop Farming", false, function(state)
        if state then
            IsFarming = false
            print("Emergency Stop Activated")
        end
    end)
end

return GetWood

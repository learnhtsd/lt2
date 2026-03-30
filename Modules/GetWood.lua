local GetWood = {}

local SelectedTree = "Oak"
local IsFarming = false
local Player = game.Players.LocalPlayer

-- Updated tree names to match LT2 internal values
local TreeTypes = {
    "Oak", "Birch", "Cherry", "Walnut", "Fir", "Pine", "Koa", 
    "Volcano", "Frost", "Gold", "Silver", "Palm", "Swamp", 
    "Spooky", "Sinister", "Cave", "Cocoa", "Oof", "Phantom"
}

local function GetNearestTree(treeName)
    local closestTree = nil
    local shortestDist = math.huge
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

    -- LT2 trees are often nested. We check Workspace and potential folders.
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "TreeClass" and obj.Value == treeName then
            local tree = obj.Parent
            local cutPart = tree:FindFirstChild("WoodSection") or tree:FindFirstChild("Base")
            
            if cutPart then
                local dist = (char.HumanoidRootPart.Position - cutPart.Position).Magnitude
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

    Tab:CreateDropdown("Select Tree Type", TreeTypes, "Oak", function(choice)
        SelectedTree = choice
    end)

    Tab:CreateAction("Auto Farm", "Start", function()
        if IsFarming then return end
        
        local char = Player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        
        if not tool or not tool:FindFirstChild("RemoteClick") then
            warn("Equip an axe first!")
            return
        end

        local target = GetNearestTree(SelectedTree)
        if not target then
            warn("No " .. SelectedTree .. " found nearby.")
            return
        end

        IsFarming = true
        local oldPos = char.HumanoidRootPart.CFrame
        local woodSection = target:FindFirstChild("WoodSection")

        -- Move to tree
        char.HumanoidRootPart.CFrame = woodSection.CFrame * CFrame.new(0, 0, 2)
        task.wait(0.3)

        -- Chop chop
        repeat
            tool.RemoteClick:FireServer({
                ["Part"] = woodSection,
                ["Pos"] = woodSection.Position,
                ["Normal"] = Vector3.new(0, 1, 0)
            })
            task.wait(0.15)
        until not target:Parent() or not IsFarming

        -- Return home
        char.HumanoidRootPart.CFrame = oldPos
        
        -- Bring wood back
        task.wait(0.5)
        for _, log in pairs(workspace.LogFolder:GetChildren()) do
            if log:FindFirstChild("Owner") and log.Owner.Value == Player then
                log.CFrame = oldPos * CFrame.new(0, 5, 0)
            end
        end
        
        IsFarming = false
    end)

    Tab:CreateToggle("Emergency Stop", false, function(state)
        IsFarming = not state -- If toggle is ON, IsFarming becomes false
    end)
end

return GetWood

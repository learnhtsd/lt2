local GetWood = {}

function GetWood.Init(Tab, Library)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local SelectedTree = nil
    local Running = false
    local OriginalCFrame = nil

    local Trees = {
        "Oak","Birch","Cherry","Walnut","Koa","LoneCave","Volcano","Swamp"
    }

    local function GetCharacter()
        return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    end

    local function GetAxe()
        local char = GetCharacter()
        local backpack = LocalPlayer:WaitForChild("Backpack")

        for _, v in pairs(char:GetChildren()) do
            if v:IsA("Tool") then return v end
        end

        for _, v in pairs(backpack:GetChildren()) do
            if v:IsA("Tool") then
                v.Parent = char
                task.wait(0.1)
                return v
            end
        end

        return nil
    end

    local function GetTreeModel()
        if not SelectedTree then return nil end

        local char = GetCharacter()
        local hrp = char:WaitForChild("HumanoidRootPart")

        local closestTree = nil
        local closestDist = math.huge

        for _, model in pairs(workspace:GetDescendants()) do
            if model:IsA("Model") and model.Parent and model.Parent.Name == "TreeRegion" then
                local treeClass = model:FindFirstChild("TreeClass")
                if treeClass and treeClass.Value == SelectedTree then
                    local woodParts = {}
                    local minY, maxY

                    for _, v in pairs(model:GetDescendants()) do
                        if v:IsA("BasePart") and v.Name:lower():find("wood") then
                            table.insert(woodParts, v)
                            if not minY or v.Position.Y < minY then minY = v.Position.Y end
                            if not maxY or v.Position.Y > maxY then maxY = v.Position.Y end
                        end
                    end

                    if #woodParts >= 6 then
                        local height = maxY - minY
                        if height > 15 then
                            local basePart = woodParts[1]
                            local dist = (basePart.Position - hrp.Position).Magnitude

                            if dist > 50 and dist < closestDist then
                                closestDist = dist
                                closestTree = model
                            end
                        end
                    end
                end
            end
        end

        return closestTree
    end

    local function GetLowestLog(tree)
        local lowest
        for _, v in pairs(tree:GetDescendants()) do
            if v:IsA("BasePart") and v.Name:lower():find("wood") then
                if not lowest or v.Position.Y < lowest.Position.Y then
                    lowest = v
                end
            end
        end
        return lowest
    end

    local function Teleport(cf)
        local hrp = GetCharacter():WaitForChild("HumanoidRootPart")
        hrp.CFrame = cf
    end

    local function SwingAxe(targetPart)
        local axe = GetAxe()
        if not axe or not targetPart then return end

        -- Force mouse target to the wood part so AxeClient registers the hit
        local mouse = LocalPlayer:GetMouse()
        mouse.Target = targetPart

        axe:Activate()

        task.wait(0.05)
    end

    local function StartFarming()
        if Running then
            Library:Notify("Get Wood", "Already running", 3)
            return
        end

        if not SelectedTree then
            Library:Notify("Error", "No tree selected", 4)
            return
        end

        if not GetAxe() then
            Library:Notify("Error", "No axe equipped", 4)
            return
        end

        local tree = GetTreeModel()
        if not tree then
            Library:Notify("Error", "No " .. SelectedTree .. " tree found nearby", 4)
            return
        end

        Running = true
        Library:Notify("Get Wood", "Started farming " .. SelectedTree, 4)

        local hrp = GetCharacter():WaitForChild("HumanoidRootPart")
        OriginalCFrame = hrp.CFrame

        while Running and tree and tree.Parent do
            local log = GetLowestLog(tree)
            if not log then break end

            -- Teleport right next to the log
            Teleport(CFrame.new(log.Position + Vector3.new(3, 2, 0)))
            task.wait(0.15)
            SwingAxe(log)
            task.wait(0.4)
        end

        if OriginalCFrame then
            Teleport(OriginalCFrame)
        end

        Library:Notify("Get Wood", "Finished / Stopped", 4)
        Running = false
    end

    local function StopFarming()
        if not Running then
            Library:Notify("Get Wood", "Not running", 3)
            return
        end

        Running = false

        if OriginalCFrame then
            Teleport(OriginalCFrame)
        end

        Library:Notify("Get Wood", "Force stopped", 4)
    end

    -- UI
    Tab:CreateAction("Debug: Scan Remotes", "Scan", function()
        print("=== ReplicatedStorage Remotes ===")
        for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                print(v.ClassName, "| Path:", v:GetFullName())
            end
        end
        print("--- Done ---")
    end)

    Tab:CreateSection("Wood Farming")

    Tab:CreateDropdown("Select Tree", Trees, nil, function(value)
        SelectedTree = value
        Library:Notify("Get Wood", "Selected: " .. value, 3)
    end)

    Tab:CreateAction("Start Auto Chop", "Start", function()
        task.spawn(StartFarming)
    end)

    Tab:CreateAction("Force Stop", "Stop", function()
        StopFarming()
    end)
end

return GetWood

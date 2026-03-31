local GetWood = {}

function Wood.Init(Tab, Library)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local SelectedTree = nil
    local Running = false
    local OriginalCFrame = nil

    -- ==========================================
    -- TREE LIST (EDIT IF NEEDED)
    -- ==========================================
    local Trees = {
        "Oak",
        "Birch",
        "Cherry",
        "Walnut",
        "Koa",
        "LoneCave",
        "Volcano",
        "Swamp"
    }

    -- ==========================================
    -- HELPERS
    -- ==========================================
    local function GetCharacter()
        return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    end

    local function GetAxe()
        local char = GetCharacter()
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("Tool") and string.find(v.Name:lower(), "axe") then
                return v
            end
        end
        return nil
    end

    local function GetTreeModel(name)
        for _, tree in pairs(workspace:GetDescendants()) do
            if tree.Name:lower():find(name:lower()) and tree:IsA("Model") then
                return tree
            end
        end
        return nil
    end

    local function GetLowestLog(tree)
        local lowest = nil
        for _, v in pairs(tree:GetDescendants()) do
            if v:IsA("BasePart") then
                if not lowest or v.Position.Y < lowest.Position.Y then
                    lowest = v
                end
            end
        end
        return lowest
    end

    local function Teleport(cf)
        local char = GetCharacter()
        local hrp = char:WaitForChild("HumanoidRootPart")
        hrp.CFrame = cf
    end

    local function SwingAxe()
        local axe = GetAxe()
        if axe then
            axe:Activate()
        end
    end

    -- ==========================================
    -- MAIN LOOP
    -- ==========================================
    local function StartFarming()
        if Running then
            Library:Notify("Get Wood", "Already running", 3)
            return
        end

        if not SelectedTree then
            Library:Notify("Error", "No tree selected", 4)
            return
        end

        local tree = GetTreeModel(SelectedTree)
        if not tree then
            Library:Notify("Error", "Tree not found", 4)
            return
        end

        local axe = GetAxe()
        if not axe then
            Library:Notify("Error", "No axe equipped", 4)
            return
        end

        Running = true
        Library:Notify("Get Wood", "Started farming " .. SelectedTree, 4)

        local char = GetCharacter()
        local hrp = char:WaitForChild("HumanoidRootPart")
        OriginalCFrame = hrp.CFrame

        local baseLog = GetLowestLog(tree)
        if not baseLog then
            Library:Notify("Error", "Failed to find base log", 4)
            Running = false
            return
        end

        -- Teleport to base
        Teleport(baseLog.CFrame * CFrame.new(0, 3, 0))

        -- Chop loop
        while Running and tree.Parent do
            local log = GetLowestLog(tree)
            if not log then break end

            -- Stay near log (no cursor needed)
            Teleport(log.CFrame * CFrame.new(0, 3, 0))

            -- Swing axe
            SwingAxe()

            task.wait(0.2)
        end

        -- Return player
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

        -- Return player safely
        if OriginalCFrame then
            Teleport(OriginalCFrame)
        end

        Library:Notify("Wood", "Force stopped", 4)
    end

    -- ==========================================
    -- UI
    -- ==========================================
    Tab:CreateSection("Wood Farming")

    Tab:CreateDropdown("Select Tree", Trees, nil, function(value)
        SelectedTree = value
        Library:Notify("Wood", "Selected: " .. value, 3)
    end)

    Tab:CreateAction("Start Auto Chop", "Start", function()
        task.spawn(StartFarming)
    end)

    Tab:CreateAction("Force Stop", "Stop", function()
        StopFarming()
    end)
end

return GetWood

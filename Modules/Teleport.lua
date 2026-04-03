local TeleportModule = {}

function TeleportModule.Init(Tab)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    local selectedTarget = nil -- Stores the DisplayName of the selected player

    -- ===========================
    -- TELEPORT LOGIC
    -- = :=========================
    local function Teleport(Pos)
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            -- Added a small Y offset (5) to prevent getting stuck in the floor
            Character.HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(0, 5, 0))
        end
    end

    -- ===========================
    -- WORLD LOCATIONS (POIs)
    -- = :=========================
    local poiData = {
        ["Wood R Us"] = Vector3.new(265, 3, 57),
        ["Land Store"] = Vector3.new(257, 3, -99),
        ["Boxed Cars"] = Vector3.new(510, 3, -1465),
        ["Fancy Furnishings"] = Vector3.new(500, 3, -1720),
        ["Fine Arts Shop"] = Vector3.new(5207, -166, 719),
        ["The Link"] = Vector3.new(4607, 7, -795),
        ["Volcano"] = Vector3.new(-1585, 622, 1140),
        ["Snow Mountain"] = Vector3.new(1448, 413, 3186),
        ["Swamp"] = Vector3.new(-1209, 132, -801),
        ["Palm Island #1"] = Vector3.new(2000, -6, -1500),
        ["Lonecave"] = Vector3.new(3581, -179, 430),
        ["Power of Ease"] = Vector3.new(1065, -17, 1133)
    }

    local poiNames = {}
    for name, _ in pairs(poiData) do table.insert(poiNames, name) end
    table.sort(poiNames)

    Tab:CreateSection("Point of Interest")
    
    Tab:CreateDropdown("Select Location", poiNames, "Select...", function(val)
        Teleport(poiData[val]) -- Teleport immediately on selection
    end)

    -- ===========================
    -- PLAYER & PLOT SECTION
    -- ===========================
    Tab:CreateSection("Player & Plot Teleports")

    local function GetPlayerList()
        local list = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then 
                table.insert(list, p.DisplayName) 
            end
        end
        return list
    end

    Tab:CreateDropdown("Select Player", GetPlayerList(), "Select...", function(val)
        selectedTarget = val
    end)

    -- Button 1: Teleport to the actual Player
    Tab:CreateAction("Go to Player", "TP", function()
        if selectedTarget then
            for _, p in pairs(Players:GetPlayers()) do
                if p.DisplayName == selectedTarget and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then Teleport(hrp.Position) end
                end
            end
        end
    end)

    -- Button 2: Teleport to that Player's Plot
    Tab:CreateAction("Go to Player's Plot", "PLOT", function()
        if selectedTarget then
            local properties = workspace:FindFirstChild("Properties")
            if properties then
                for _, plot in pairs(properties:GetChildren()) do
                    local owner = plot:FindFirstChild("Owner")
                    -- Matching the Owner value to the selected player's name
                    if owner and tostring(owner.Value) == selectedTarget then
                        local origin = plot:FindFirstChild("Origin") or plot:FindFirstChildOfClass("Part")
                        if origin then Teleport(origin.Position) end
                        break
                    end
                end
            end
        end
    end)

end

return TeleportModule

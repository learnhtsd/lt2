local TeleportModule = {}

function TeleportModule.Init(Tab)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- ==========================================
    -- TELEPORT LOGIC
    -- ==========================================
    local function Teleport(Pos)
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(0, 5, 0))
        end
    end

    -- ==========================================
    -- STATIC POIS (Stores & Wood)
    -- ==========================================
    local staticLocations = {
        ["Stores"] = {
            {"Wood R Us", Vector3.new(265, 3, 57)},
            {"Land Store", Vector3.new(160, 3, 115)},
            {"Boxed Cars", Vector3.new(509, 3, -146)},
            {"Fancy Furnishings", Vector3.new(491, 3, -172)},
            {"Fine Arts Shop", Vector3.new(5207, -166, 719)},
            {"The Link", Vector3.new(4607, 7, -795)}
        },
        ["Wood Locations"] = {
            {"Volcano (Fire)", Vector3.new(-1585, 622, 1140)},
            {"Snow Mountain", Vector3.new(1448, 413, 3186)},
            {"Swamp (Gold)", Vector3.new(-1209, 132, -801)},
            {"Palm Island", Vector3.new(2549, 3, -1668)},
            {"Cave (End Times)", Vector3.new(3581, -179, 430)}
        }
    }

    for Category, Points in pairs(staticLocations) do
        Tab:CreateSection(Category)
        for _, Data in pairs(Points) do
            Tab:CreateAction(Data[1], "TP", function() Teleport(Data[2]) end)
        end
    end

    -- ==========================================
    -- DYNAMIC PLAYER TELEPORTS
    -- ==========================================
    Tab:CreateSection("Active Players")
    
    local function RefreshPlayers()
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                Tab:CreateAction(plr.DisplayName, "TP to Plr", function()
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        Teleport(plr.Character.HumanoidRootPart.Position)
                    end
                end)
            end
        end
    end
    RefreshPlayers()

    -- ==========================================
    -- DYNAMIC PLOT TELEPORTS
    -- ==========================================
    Tab:CreateSection("Player Plots")

    local function GetPlots()
        -- LT2 stores plots in Workspace.Properties
        local Properties = workspace:FindFirstChild("Properties")
        if Properties then
            for _, plot in pairs(Properties:GetChildren()) do
                local Owner = plot:FindFirstChild("Owner")
                if Owner and Owner.Value ~= nil then
                    local OwnerName = tostring(Owner.Value)
                    -- Find the Origin square to TP to
                    local Origin = plot:FindFirstChild("Origin") or plot:FindFirstChildOfClass("Part")
                    
                    if Origin then
                        Tab:CreateAction(OwnerName .. "'s Plot", "TP to Plot", function()
                            Teleport(Origin.Position)
                        end)
                    end
                end
            end
        end
    end
    GetPlots()

end

return TeleportModule

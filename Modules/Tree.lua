local TreeModule = {}

-- ==========================================
--             SYSTEM SETTINGS
-- ==========================================
local Settings = {
    -- [ Axe Configuration ]
    AxePriority = {
        "ManyAxe", "Rukiryaxe", "AxeAlphaTesters", "IceAxe", "AxeTwitter",
        "Beesaxe", "CandyCaneAxe", "RustyAxe", "GingerbreadAxe", "FireAxe",
        "AxeChicken", "InverseAxe", "AxeSwamp", "AxePig", "SilverAxe",
        "Axe3", "Axe2", "Axe1", "BasicHatchet"
    },
    
    LogBindings = {
        ["Cherry"] = "PieAxe",
        ["Volcano"] = "FireAxe",
        ["Frost"] = "IceAxe",
        ["GoldSwampy"] = "AxeSwamp",
        ["GreenSwampy"] = "AxeSwamp",
        ["Walnut"] = "GingerbreadAxe",
        ["Koa"] = "GingerbreadAxe",
        ["CaveCrawler"] = "CaveAxe",
        ["LoneCave"] = "EndTimesAxe",
    },

    -- [ Movement & View ]
    DistanceToTree = 3.5,        
    VerticalOffset = 0.4,        
    HideGround = true,           
    
    SyncDelay = 0.25,            
    ReadyDelay = 0.3,           
    
    -- [ Chopping Speed ]
    SwingHoldTime = 0.1,        
    SwingCooldown = 0.12,        
    RandomVariation = 0.02,      
}

-- ==========================================
--             CORE SERVICES & VARS
-- ==========================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- State Variables
local isChopping = false
local currentTargetWood = nil
local preChopCFrame = nil
local preChopCameraCFrame = nil
local lockConn = nil

local groundObject = Workspace:FindFirstChild("Baseplate")
local originalTransparency = groundObject and groundObject.Transparency or 0

-- ==========================================
--             UTILITY FUNCTIONS
-- ==========================================
local function SetGroundVisible(visible)
    if not groundObject or not Settings.HideGround then return end
    groundObject.Transparency = visible and originalTransparency or 1
end

local function GetAxeFromBackpack(targetAxeName)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, item in ipairs(backpack:GetChildren()) do
        if item.Name == "Tool" then
            local toolNameObj = item:FindFirstChild("ToolName")
            if toolNameObj and toolNameObj.Value == targetAxeName then
                return item
            end
        end
    end
    return nil
end

local function DetermineAndEquipAxe(treeClass)
    local targetAxe = nil
    local boundName = Settings.LogBindings[treeClass]
    if boundName then targetAxe = GetAxeFromBackpack(boundName) end
    
    if not targetAxe then
        for _, name in ipairs(Settings.AxePriority) do
            local found = GetAxeFromBackpack(name)
            if found then targetAxe = found; break end
        end
    end
    
    if targetAxe and player.Character then
        targetAxe.Parent = player.Character 
        return targetAxe
    end
    return player.Character and player.Character:FindFirstChildOfClass("Tool")
end

local function FindPriorityWood(treeClass)
    local targetPart = nil
    local maxSections = -1

    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder.Name:lower():match("treeregion") then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and model:FindFirstChild("TreeClass") and model.TreeClass.Value == treeClass then
                    local sectionCount = 0
                    local tempLowestPart = nil
                    local lowestY = math.huge
                    
                    for _, part in ipairs(model:GetChildren()) do
                        if part.Name == "WoodSection" then
                            sectionCount = sectionCount + 1
                            if part.Position.Y < lowestY then
                                lowestY = part.Position.Y
                                tempLowestPart = part
                            end
                        end
                    end

                    if treeClass == "Generic" and sectionCount < 12 then continue end

                    if sectionCount > maxSections and tempLowestPart then
                        maxSections = sectionCount
                        targetPart = tempLowestPart
                    end
                end
            end
        end
    end
    return targetPart
end

local function ScanForTreeTypes()
    local foundTypes = {}
    local seen = {}
    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder.Name:lower():match("treeregion") then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local treeClass = model:FindFirstChild("TreeClass")
                    if treeClass and treeClass:IsA("StringValue") and not seen[treeClass.Value] then
                        seen[treeClass.Value] = true
                        table.insert(foundTypes, treeClass.Value)
                    end
                end
            end
        end
    end
    return #foundTypes > 0 and foundTypes or {"None Found"}
end

local function CleanupState()
    isChopping = false
    currentTargetWood = nil
    SetGroundVisible(true) 
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Unequip tool
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool.Parent = player:FindFirstChild("Backpack") end
    end

    -- Return to original physical position
    if hrp and preChopCFrame then
        hrp.CFrame = preChopCFrame
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    end

    player.CameraMode = Enum.CameraMode.Classic

    -- Return original camera orientation
    if preChopCameraCFrame then
        camera.CFrame = preChopCameraCFrame
    end

    -- Disconnect render step
    if lockConn then 
        lockConn:Disconnect()
        lockConn = nil 
    end
end

local function StartChopping(treeClass, onComplete)
    if isChopping then return end
    
    local targetWood = FindPriorityWood(treeClass)
    if not targetWood then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local equippedTool = DetermineAndEquipAxe(treeClass)
    if not equippedTool then return end

    -- Save Initial State
    preChopCFrame = hrp.CFrame
    preChopCameraCFrame = camera.CFrame

    isChopping = true
    currentTargetWood = targetWood
    local originalSizeY = currentTargetWood.Size.Y

    SetGroundVisible(false)

    -- Math / Positioning Logic
    local logUp = targetWood.CFrame.UpVector
    local halfHeight = targetWood.Size.Y / 2
    local aimPoint = targetWood.Position - (logUp * (halfHeight * 0.7)) 
    
    local lookDir = targetWood.CFrame.LookVector
    local standPos = aimPoint + (lookDir * Settings.DistanceToTree) + Vector3.new(0, Settings.VerticalOffset, 0)
    
    local baseLook = CFrame.lookAt(standPos, aimPoint)
    local upsideDownCFrame = baseLook * CFrame.Angles(0, 0, math.pi)

    hrp.CFrame = upsideDownCFrame
    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    
    task.wait(Settings.SyncDelay) 
    player.CameraMode = Enum.CameraMode.LockFirstPerson

    lockConn = RunService.RenderStepped:Connect(function()
        if isChopping and currentTargetWood then
            hrp.CFrame = upsideDownCFrame
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPoint) * CFrame.Angles(0, 0, math.pi)
        else
            if lockConn then lockConn:Disconnect() end
        end
    end)

    task.wait(Settings.ReadyDelay)

    task.spawn(function()
        local center = camera.ViewportSize / 2
        local rng = Random.new()
        
        while isChopping and currentTargetWood.Parent and currentTargetWood:IsDescendantOf(Workspace) do
            if math.abs(currentTargetWood.Size.Y - originalSizeY) > 0.4 then break end

            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            task.wait(Settings.SwingHoldTime) 
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)

            task.wait(Settings.SwingCooldown + rng:NextNumber(-Settings.RandomVariation, Settings.RandomVariation)) 
        end

        -- Exit & Cleanup Phase
        CleanupState()
        if onComplete then onComplete() end
    end)
end

-- ==========================================
--             DYNXE UI INITIALIZATION
-- ==========================================
function TreeModule.Init(Tab)
    -- Section Layout
    Tab:CreateSection("Auto Chop Settings")
    
    -- Variables
    local treeTypes = ScanForTreeTypes()
    local selectedTree = treeTypes[1] or "None Found"
    local chopActionButton

    -- Setup Dropdown
    Tab:CreateDropdown("Target Wood Type", treeTypes, selectedTree, function(selected)
        selectedTree = selected
    end):AddTooltip("Select the type of tree you want the script to automatically hunt and chop down.")

    -- Setup Action Button
    chopActionButton = Tab:CreateAction("Process Tree", "Start Chop", function()
        if isChopping then
            -- [ CANCEL STATE ]
            isChopping = false -- Flips the state, breaking the loop and calling CleanupState() 
            
            -- Attempt to revert button text. Note: Depending on the specific build of DYNXE, 
            -- if CreateAction returns an object, we update the text below.
            if type(chopActionButton) == "table" and chopActionButton.SetText then
                chopActionButton:SetText("Start Chop")
            end
        else
            -- [ START STATE ]
            if selectedTree == "None Found" then return end
            
            if type(chopActionButton) == "table" and chopActionButton.SetText then
                chopActionButton:SetText("Cancel")
            end
            
            StartChopping(selectedTree, function()
                -- When the tree is successfully chopped naturally, reset button visuals
                if type(chopActionButton) == "table" and chopActionButton.SetText then
                    chopActionButton:SetText("Start Chop")
                end
            end)
        end
    end)
    
    -- Add Tooltip to Action
    if type(chopActionButton) == "table" and chopActionButton.AddTooltip then
        chopActionButton:AddTooltip("Click to start chopping. Click again during the process to cancel and teleport back.")
    end
end

return TreeModule

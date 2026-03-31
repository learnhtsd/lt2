local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local UIS = game:GetService("UserInputService")

local DragRemote = game.ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientIsDragging")

-- State
local SelectedObjects = {}
local Highlights = {}
local DebugMode = false
local ClickSelectEnabled = false
local LastClickedPart = nil

-- =========================
-- VISUAL HELPER FUNCTIONS
-- =========================
local function AddHighlight(part)
    if not part or Highlights[part] then return end
    
    local hl = Instance.new("Highlight")
    hl.Adornee = part
    hl.FillColor = Color3.fromRGB(0, 255, 100) -- Green selection
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0.2
    
    -- Attempt to hide it in CoreGui, fallback to the part if exploit doesn't support it
    local success = pcall(function()
        hl.Parent = game:GetService("CoreGui")
    end)
    if not success then
        hl.Parent = part
    end
    
    Highlights[part] = hl
end

local function RemoveHighlight(part)
    if Highlights[part] then
        Highlights[part]:Destroy()
        Highlights[part] = nil
    end
end

local function ClearAllSelections()
    for part, hl in pairs(Highlights) do
        if hl then hl:Destroy() end
    end
    table.clear(Highlights)
    table.clear(SelectedObjects)
end

function Tool.Init(Tab, Lib)

    Tab:CreateSection("Drag TP System")

    -- DEBUG BUTTON
    Tab:CreateToggle("Debug Drag (Click Object)", false, function(state)
        DebugMode = state
        if Lib then
            Lib:Notify("Debug", state and "Click an object to log drag args" or "Disabled", 3)
        end
    end)

    -- DESELECT ALL (Updated)
    Tab:CreateAction("Selection", "Deselect All", function()
        ClearAllSelections()
        if Lib then Lib:Notify("Selection", "Cleared all selected items", 2) end
    end)

    -- CLICK SELECT
    Tab:CreateToggle("Click Select", false, function(state)
        ClickSelectEnabled = state
    end)

    -- MAIN TP BUTTON (FIXED)
    Tab:CreateAction("Selection", "TP to Me (Drag)", function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        if #SelectedObjects == 0 then
            if Lib then Lib:Notify("Error", "No selected items", 3) end
            return
        end

        for i, obj in ipairs(SelectedObjects) do
            local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj

            if not part then continue end

            local offset = Vector3.new((i % 5) * 3, 0, -6)
            local targetPos = hrp.Position + offset
            local targetCF = CFrame.new(targetPos)

            -- 🔥 DRAG START
            pcall(function()
                DragRemote:FireServer(part, true)
            end)

            task.wait(0.1)

            -- 🔥 LOCAL MOVE (Fix: Most drag systems require you to actually move it locally)
            pcall(function()
                part.CFrame = targetCF
                -- Kill momentum so it doesn't fly away
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)

            -- 🔥 DRAG MOVE (Send updated CFrame to server)
            pcall(function()
                DragRemote:FireServer(part, targetCF)
            end)

            task.wait(0.1)

            -- 🔥 DRAG END
            pcall(function()
                DragRemote:FireServer(part, false)
            end)

            task.wait(0.15)
        end
        
        -- Optional: Automatically clear selections after teleporting
        -- ClearAllSelections() 

        if Lib then Lib:Notify("Success", "Moved using drag system", 3) end
    end)

    -- =========================
    -- INPUT / DEBUG SYSTEM
    -- =========================

    Mouse.Button1Down:Connect(function()
        if not Mouse.Target then return end

        local target = Mouse.Target
        LastClickedPart = target

        -- DEBUG MODE
        if DebugMode then
            print("=== DEBUG CLICK ===")
            print("Part:", target)
            print("FullName:", target:GetFullName())
            print("Position:", target.Position)

            print("---- Testing Drag Patterns ----")

            pcall(function()
                print("Test 1: (part, true)")
                DragRemote:FireServer(target, true)
            end)

            task.wait(0.2)

            pcall(function()
                print("Test 2: (part, CFrame)")
                DragRemote:FireServer(target, target.CFrame)
            end)

            task.wait(0.2)

            pcall(function()
                print("Test 3: (part, false)")
                DragRemote:FireServer(target, false)
            end)

            print("==== END DEBUG ====")
        end

        -- NORMAL SELECT (Updated for Toggle/Deselect)
        if ClickSelectEnabled then
            local existingIndex = table.find(SelectedObjects, target)
            
            if existingIndex then
                -- Deselect it if it's already selected
                table.remove(SelectedObjects, existingIndex)
                RemoveHighlight(target)
                if Lib then Lib:Notify("Deselected", target.Name, 2) end
            else
                -- Select it if it's new
                table.insert(SelectedObjects, target)
                AddHighlight(target)
                if Lib then Lib:Notify("Selected", target.Name, 2) end
            end
        end
    end)
end

return Tool

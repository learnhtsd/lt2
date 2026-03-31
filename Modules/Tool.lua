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

-- =========================
-- VISUAL HELPER FUNCTIONS
-- =========================
local function AddHighlight(part)
    if not part or Highlights[part] then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = part
    hl.FillColor = Color3.fromRGB(0, 255, 100)
    hl.Parent = (game:GetService("CoreGui") or part)
    Highlights[part] = hl
end

local function RemoveHighlight(part)
    if Highlights[part] then
        Highlights[part]:Destroy()
        Highlights[part] = nil
    end
end

function Tool.Init(Tab, Lib)
    Tab:CreateSection("Drag TP System")

    Tab:CreateAction("Selection", "Deselect All", function()
        for part, _ in pairs(Highlights) do RemoveHighlight(part) end
        table.clear(SelectedObjects)
        if Lib then Lib:Notify("Selection", "Cleared", 2) end
    end)

    Tab:CreateToggle("Click Select", false, function(state)
        ClickSelectEnabled = state
    end)

    -- MAIN TP BUTTON (RE-ENGINEERED)
    Tab:CreateAction("Selection", "TP to Me (Force Sync)", function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or #SelectedObjects == 0 then return end

        for i, obj in ipairs(SelectedObjects) do
            local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
            if not part then continue end

            local targetCF = hrp.CFrame * CFrame.new((i % 5) * 3, 2, -7)

            -- STEP 1: Request Ownership (Grab)
            DragRemote:FireServer(part, true)
            task.wait(0.2) -- Wait for server to acknowledge the "Grab"

            -- STEP 2: Move the item locally
            part.CFrame = targetCF
            part.AssemblyLinearVelocity = Vector3.new(0, 1, 0) -- Tiny nudge to keep physics awake
            
            -- STEP 3: Tell Server "I am moving this now"
            -- We fire this multiple times to ensure the server updates the position record
            for _ = 1, 3 do
                DragRemote:FireServer(part, targetCF)
                task.wait(0.05)
            end

            -- STEP 4: Release (Drop)
            task.wait(0.1)
            DragRemote:FireServer(part, false)
            
            -- STEP 5: Final Velocity Reset (Prevents it from flying away)
            task.wait(0.1)
            pcall(function()
                part.AssemblyLinearVelocity = Vector3.new(0, -0.5, 0)
            end)
        end

        if Lib then Lib:Notify("Success", "Items Synced to Server", 3) end
    end)

    -- INPUT LISTENER
    Mouse.Button1Down:Connect(function()
        if not Mouse.Target or not ClickSelectEnabled then return end
        local target = Mouse.Target
        
        local index = table.find(SelectedObjects, target)
        if index then
            table.remove(SelectedObjects, index)
            RemoveHighlight(target)
        else
            table.insert(SelectedObjects, target)
            AddHighlight(target)
        end
    end)
end

return Tool

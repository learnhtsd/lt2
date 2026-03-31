local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local DragRemote = game.ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientIsDragging")

local SelectedObjects = {}
local Highlights = {}
local ClickSelectEnabled = false

-- Visuals
local function AddHighlight(part)
    if not part or Highlights[part] then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = part
    hl.FillColor = Color3.fromRGB(255, 170, 0) -- Orange for "Ghost Mode"
    hl.Parent = (game:GetService("CoreGui") or part)
    Highlights[part] = hl
end

local function RemoveHighlight(part)
    if Highlights[part] then Highlights[part]:Destroy() Highlights[part] = nil end
end

function Tool.Init(Tab, Lib)
    Tab:CreateSection("Ghost-Grab TP (Long Distance)")

    Tab:CreateAction("Selection", "Deselect All", function()
        for part, _ in pairs(Highlights) do RemoveHighlight(part) end
        table.clear(SelectedObjects)
    end)

    Tab:CreateToggle("Click Select", false, function(state)
        ClickSelectEnabled = state
    end)

    Tab:CreateAction("Selection", "Ghost TP (No Distance Limit)", function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or #SelectedObjects == 0 then return end

        -- Save where we are standing right now
        local originalPos = hrp.CFrame

        for i, part in ipairs(SelectedObjects) do
            if not part:IsA("BasePart") then continue end

            local targetPos = originalPos * CFrame.new((i % 5) * 4, 2, -10)

            -- 1. TELEPORT TO THE ITEM (GHOSTING)
            -- We do this so the server thinks we are close enough to touch it
            hrp.CFrame = part.CFrame * CFrame.new(0, 5, 0)
            task.wait(0.15) -- Wait for server to register our new position

            -- 2. GRAB WHILE NEARBY
            DragRemote:FireServer(part, true)
            task.wait(0.1)

            -- 3. TELEPORT BACK HOME
            hrp.CFrame = originalPos
            task.wait(0.1)

            -- 4. BRING ITEM TO US
            part.CFrame = targetPos
            DragRemote:FireServer(part, targetPos)
            
            -- 5. DROP
            task.wait(0.1)
            DragRemote:FireServer(part, false)
            
            -- Prevent "Physics Sleep"
            part.AssemblyLinearVelocity = Vector3.new(0, -1, 0)
        end
        
        -- Return to original spot just in case
        hrp.CFrame = originalPos

        if Lib then Lib:Notify("Success", "Ghost-Grab Finished", 2) end
    end)

    -- Selection Logic
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

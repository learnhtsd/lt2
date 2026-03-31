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
    hl.FillColor = Color3.fromRGB(0, 255, 255) -- Cyan for "Slide Mode"
    hl.Parent = (game:GetService("CoreGui") or part)
    Highlights[part] = hl
end

local function RemoveHighlight(part)
    if Highlights[part] then Highlights[part]:Destroy() Highlights[part] = nil end
end

function Tool.Init(Tab, Lib)
    Tab:CreateSection("Advanced Slide TP")

    Tab:CreateAction("Selection", "Deselect All", function()
        for part, _ in pairs(Highlights) do RemoveHighlight(part) end
        table.clear(SelectedObjects)
    end)

    Tab:CreateToggle("Click Select", false, function(state)
        ClickSelectEnabled = state
    end)

    Tab:CreateAction("Selection", "Slide TP (Anti-Cheat Bypass)", function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or #SelectedObjects == 0 then return end

        for i, part in ipairs(SelectedObjects) do
            if not part:IsA("BasePart") then continue end

            local startPos = part.Position
            local endPos = hrp.Position + Vector3.new((i % 5) * 3, 2, -7)
            local distance = (startPos - endPos).Magnitude
            
            -- 1. GRAB
            DragRemote:FireServer(part, true)
            task.wait(0.1)

            -- 2. THE SLIDE (Bypasses distance checks)
            local steps = math.floor(distance / 25) -- Move 25 studs per "tick"
            for s = 1, steps do
                local nextPos = startPos:Lerp(endPos, s/steps)
                local nextCF = CFrame.new(nextPos)
                
                part.CFrame = nextCF
                DragRemote:FireServer(part, nextCF)
                
                -- This wait is tiny, but enough to let the server heartbeat catch up
                if s % 2 == 0 then task.wait() end 
            end

            -- 3. FINAL SNAP
            part.CFrame = CFrame.new(endPos)
            DragRemote:FireServer(part, CFrame.new(endPos))
            
            -- 4. DROP
            task.wait(0.1)
            DragRemote:FireServer(part, false)
            
            -- Wake up physics
            part.AssemblyLinearVelocity = Vector3.new(0, -1, 0)
        end
        
        if Lib then Lib:Notify("Success", "Slide Complete", 2) end
    end)

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

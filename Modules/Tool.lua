local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local UIS = game:GetService("UserInputService")

local DragRemote = game.ReplicatedStorage:WaitForChild("Interaction"):WaitForChild("ClientIsDragging")

-- State
local SelectedObjects = {}
local DebugMode = false
local LastClickedPart = nil

function Tool.Init(Tab, Lib)

    Tab:CreateSection("Drag TP System")

    -- DEBUG BUTTON
    Tab:CreateToggle("Debug Drag (Click Object)", false, function(state)
        DebugMode = state
        if Lib then
            Lib:Notify("Debug", state and "Click an object to log drag args" or "Disabled", 3)
        end
    end)

    -- CLEAR
    Tab:CreateAction("Selection", "Clear Selected", function()
        SelectedObjects = {}
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
            local part =
                obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                or obj

            if not part then continue end

            local offset = Vector3.new((i % 5) * 3, 0, -6)
            local targetPos = hrp.Position + offset
            local targetCF = CFrame.new(targetPos)

            -- 🔥 DRAG START
            pcall(function()
                DragRemote:FireServer(part, true)
            end)

            task.wait(0.1)

            -- 🔥 DRAG MOVE (THIS IS THE IMPORTANT ONE)
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

            -- 🔍 TEST COMMON DRAG PATTERNS
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

        -- NORMAL SELECT
        if ClickSelectEnabled then
            if not table.find(SelectedObjects, target) then
                table.insert(SelectedObjects, target)
                if Lib then
                    Lib:Notify("Selected", target.Name, 2)
                end
            end
        end
    end)
end

return Tool

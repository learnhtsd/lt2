local Tool = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- State Variables
local InspectorEnabled = false 
local ClickSelectEnabled = false
local LassoEnabled = false
local SelectedObjects = {} -- Table to store our group

-- Lasso UI Elements
local SelectionBoxGui = Instance.new("ScreenGui", game.CoreGui)
local LassoFrame = Instance.new("Frame", SelectionBoxGui)
LassoFrame.BackgroundColor3 = Color3.fromRGB(74, 120, 255)
LassoFrame.BackgroundTransparency = 0.7
LassoFrame.BorderSizePixel = 1
LassoFrame.Visible = false

function Tool.Init(Tab, Lib)
    Tab:CreateSection("Diagnostic Tools")

    -- 1. OBJECT INSPECTOR
    Tab:CreateToggle("Object Inspector", false, function(state)
        InspectorEnabled = state
        if Lib and Lib.Notify then
            Lib:Notify("Inspector", state and "Enabled! Click to log info." or "Disabled.", 3)
        end
    end)

    Tab:CreateSection("Selection Suite")

    -- 2. CLICK SELECT TOGGLE
    Tab:CreateToggle("Click Select", false, function(state)
        ClickSelectEnabled = state
    end)

    -- 3. LASSO TOOL TOGGLE
    Tab:CreateToggle("Lasso Tool", false, function(state)
        LassoEnabled = state
    end)

    -- 4. DESELECT BUTTON
    Tab:CreateAction("Group Actions", "Deselect All", function()
        for _, obj in pairs(SelectedObjects) do
            if obj:FindFirstChild("SelectionHighlight") then
                obj.SelectionHighlight:Destroy()
            end
        end
        SelectedObjects = {}
        Lib:Notify("Selection", "Cleared all selected items.", 3)
    end)

-- 5. KRON-STYLE TELEPORT (Snap-Claim Logic)
    Tab:CreateAction("Group Actions", "TP to Me", function()
        if #SelectedObjects == 0 then
            Lib:Notify("Error", "No items selected!", 3)
            return
        end

        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local originalPos = hrp.CFrame -- Remember where we started
        Lib:Notify("Teleporting", "Processing " .. #SelectedObjects .. " items...", 3)

        for i, item in ipairs(SelectedObjects) do
            pcall(function()
                local targetPart = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                
                if targetPart and targetPart:IsA("BasePart") then
                    -- STEP 1: Teleport Player to the item to gain Network Ownership
                    hrp.CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
                    task.wait(0.1) -- Short wait for the engine to register you are there

                    -- STEP 2: Move the item to our original saved position
                    local dropPos = originalPos * CFrame.new(0, 2, -7)
                    if item:IsA("Model") then
                        item:SetPrimaryPartCFrame(dropPos)
                    else
                        item.CFrame = dropPos
                    end

                    -- STEP 3: "Kick" the physics so it doesn't freeze
                    targetPart.Velocity = Vector3.new(0, 1, 0)
                    targetPart.RotVelocity = Vector3.new(0, 0.1, 0)
                    
                    -- STEP 4: Teleport Player back to original spot to move the next one
                    hrp.CFrame = originalPos
                end
            end)
            
            task.wait(0.1) -- Delay between items to prevent LT2 anti-cheat flags
        end

        Lib:Notify("Success", "All items processed!", 3)
    end)

    -- ===========================
    -- SELECTION LOGIC
    -- ===========================
    
    local dragging = false
    local startPos = Vector2.new()

    -- Function to highlight objects
    local function AddToSelection(obj)
        if not table.find(SelectedObjects, obj) then
            table.insert(SelectedObjects, obj)
            local highlight = Instance.new("SelectionBox")
            highlight.Name = "SelectionHighlight"
            highlight.Adornee = obj
            highlight.Color3 = Color3.fromRGB(74, 120, 255)
            highlight.LineThickness = 0.05
            highlight.Parent = obj
        end
    end

    Mouse.Button1Down:Connect(function()
        -- Inspector Logic
        if InspectorEnabled and Mouse.Target then
            print("--- INSPECT: " .. Mouse.Target:GetFullName() .. " ---")
        end

        -- Click Select Logic
        if ClickSelectEnabled and Mouse.Target then
            AddToSelection(Mouse.Target)
        end

        -- Lasso Start
        if LassoEnabled then
            dragging = true
            startPos = UserInputService:GetMouseLocation()
            LassoFrame.Visible = true
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if LassoEnabled and dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentPos = UserInputService:GetMouseLocation()
            local diff = currentPos - startPos
            
            LassoFrame.Size = UDim2.new(0, math.abs(diff.X), 0, math.abs(diff.Y))
            LassoFrame.Position = UDim2.new(0, math.min(startPos.X, currentPos.X), 0, math.min(startPos.Y, currentPos.Y))
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            LassoFrame.Visible = false
            
            -- Selection Box Logic (Screen to World)
            if LassoEnabled then
                local guiSize = LassoFrame.AbsoluteSize
                local guiPos = LassoFrame.AbsolutePosition
                
                -- Simple check for parts in the box
                for _, v in pairs(game.Workspace:GetChildren()) do
                    if v:IsA("BasePart") or (v:IsA("Model") and v.PrimaryPart) then
                        local part = v:IsA("Model") and v.PrimaryPart or v
                        local screenPos, onScreen = game.Workspace.CurrentCamera:WorldToScreenPoint(part.Position)
                        
                        if onScreen then
                            if screenPos.X >= guiPos.X and screenPos.X <= guiPos.X + guiSize.X and
                               screenPos.Y >= guiPos.Y and screenPos.Y <= guiPos.Y + guiSize.Y then
                                AddToSelection(v)
                            end
                        end
                    end
                end
            end
        end
    end)
end

return Tool

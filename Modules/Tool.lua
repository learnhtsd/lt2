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
            if obj and obj:FindFirstChild("SelectionHighlight") then
                obj.SelectionHighlight:Destroy()
            end
        end
        SelectedObjects = {}
        if Lib and Lib.Notify then
            Lib:Notify("Selection", "Cleared all selected items.", 3)
        end
    end)

    -- 5. "STAY PUT" TELEPORT (Fixed Anti-Snapback Logic)
    Tab:CreateAction("Group Actions", "TP to Me", function()
        if #SelectedObjects == 0 then
            if Lib and Lib.Notify then Lib:Notify("Error", "No items selected!", 3) end
            return
        end

        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local originalPos = hrp.CFrame
        if Lib and Lib.Notify then Lib:Notify("Teleporting", "Moving " .. #SelectedObjects .. " items...", 3) end

        for i, item in ipairs(SelectedObjects) do
            pcall(function()
                -- Find the part we are actually moving
                local targetPart = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                
                if targetPart and targetPart:IsA("BasePart") then
                    -- STEP 1: Fly to the item to claim network ownership
                    hrp.CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
                    
                    -- CRITICAL: Wait slightly longer for the server to grant network ownership
                    task.wait(0.2) 

                    -- STEP 2: Calculate drop position (Spread them out slightly so they don't explode)
                    local offsetX = (i % 5) * 2 - 4
                    local dropPos = originalPos * CFrame.new(offsetX, 2, -5)
                    
                    -- STEP 3: Move the item safely
                    if item:IsA("Model") then
                        item:PivotTo(dropPos) -- Replaced deprecated SetPrimaryPartCFrame
                    else
                        item.CFrame = dropPos
                    end

                    -- STEP 4: The Real "Force Settle"
                    -- Do NOT change Anchored state! It ruins client-server physics replication.
                    -- Instead, kill its momentum completely so it drops straight down.
                    targetPart.AssemblyLinearVelocity = Vector3.zero
                    targetPart.AssemblyAngularVelocity = Vector3.zero

                    -- Small delay to let the position change register before moving away
                    task.wait(0.1) 
                end
            end)
        end

        -- STEP 5: Snap back to start ONCE after all items are collected
        hrp.CFrame = originalPos

        if Lib and Lib.Notify then Lib:Notify("Success", "Items moved and settled.", 3) end
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

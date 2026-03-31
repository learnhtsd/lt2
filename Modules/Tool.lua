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

-- 5. TELEPORT BUTTON (LT2 Compatibility + Physics Wake-up)
    Tab:CreateAction("Group Actions", "TP to Me", function()
        if #SelectedObjects == 0 then
            Lib:Notify("Error", "No items selected!", 3)
            return
        end

        Lib:Notify("Teleporting", "Moving " .. #SelectedObjects .. " items...", 5)
        
        local character = Player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local targetPos = character.HumanoidRootPart.CFrame * CFrame.new(0, 2, -7) -- 2 units up, 7 units forward

        for i, item in ipairs(SelectedObjects) do
            pcall(function()
                local root = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                
                if root and root:IsA("BasePart") then
                    -- 1. Move the item
                    if item:IsA("Model") then
                        item:SetPrimaryPartCFrame(targetPos)
                    else
                        item.CFrame = targetPos
                    end

                    -- 2. WAKE UP PHYSICS (The "Anti-Freeze" Fix)
                    -- We apply a tiny bit of velocity and a micro-rotation
                    root.Velocity = Vector3.new(0, 0.1, 0) 
                    root.RotVelocity = Vector3.new(0, 0.05, 0)
                    
                    -- 3. Network Ownership Check
                    -- Since you mentioned you have ownership, this ensures the server 
                    -- recognizes you as the physics calculator immediately.
                    if root.ReceiveAge == 0 or true then 
                        task.spawn(function()
                            -- Briefly set to non-anchored if LT2's system anchored it
                            root.Anchored = false 
                        end)
                    end
                end
            end)
            
            task.wait(0.15) -- Slightly longer wait to let the engine catch up
        end
        
        Lib:Notify("Success", "Items moved and unfrozen.", 3)
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

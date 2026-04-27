-- [[ SHOP MODULE ]] --
-- Optimized for Dynxe LT2 UI Engine
-- Includes: Ownership Validation, Multi-Stage Teleport, and Auto-UI Confirmation

local ShopModule = {}

local Players = game:GetService("Players")
local Player  = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         CONFIGURATION                           │
-- └─────────────────────────────────────────────────────────────────┘
local ITEM_TP_POS   = Vector3.new(268.3, 5.2, 67.4)     -- Where boxes land
local PLAYER_TP_POS = Vector3.new(263.0, 3.2, 63.5)     -- Where you stand to buy
local _LOT = nil  

local ShopItems = {
    {
        Name        = "Basic Hatchet",
        Image       = "BasicHatchet.png",
        Price       = 500,
        BoxItemName = "BasicHatchet",
    },
    -- Add more items here following the same structure
}

function ShopModule.SetLOT(lot)
    _LOT = lot
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     INTERNAL HELPERS                            │
-- └─────────────────────────────────────────────────────────────────┘

-- Clicks the "ChatChoice" button you found in PlayerGui
local function AutoConfirmUI()
    local PlayerGui = Player:WaitForChild("PlayerGui")
    local ChatGUI = PlayerGui:FindFirstChild("ChatGUI")
    
    if ChatGUI then
        -- Navigate the path found in your logs
        local chat = ChatGUI:FindFirstChild("Chat")
        local choices = chat and chat:FindFirstChild("Choices")
        
        if choices then
            local confirmBtn = choices:WaitForChild("ChatChoice", 2)
            if confirmBtn and confirmBtn:IsA("TextButton") then
                -- use firesignal if supported, otherwise standard click simulation
                if firesignal then
                    firesignal(confirmBtn.MouseButton1Click)
                else
                    -- Fallback for basic executors
                    for _, connection in pairs(getconnections(confirmBtn.MouseButton1Click)) do
                        connection:Fire()
                    end
                end
                print("[ShopModule] UI Confirmation Clicked.")
                return true
            end
        end
    end
    return false
end

-- Finds boxes that match the ID and are NOT owned by anyone
local function ResolveItemParts(item, quantity)
    local stores = workspace:FindFirstChild("Stores")
    if not stores then return {} end

    local results = {}

    for _, storeFolder in ipairs(stores:GetChildren()) do
        local shopItems = storeFolder:FindFirstChild("ShopItems")
        if not shopItems then continue end
        if #results >= quantity then break end

        for _, box in ipairs(shopItems:GetChildren()) do
            if #results >= quantity then break end
            if not (box:IsA("Model") and box.Name == "Box") then continue end

            -- 1. Identity Check
            local nameVal = box:FindFirstChild("BoxItemName")
            if not (nameVal and nameVal.Value == item.BoxItemName) then continue end

            -- 2. Ownership Check (per your screenshot)
            local ownerFolder = box:FindFirstChild("Owner")
            local ownerString = ownerFolder and ownerFolder:FindFirstChild("OwnerString")
            
            -- If OwnerString has text, someone else is buying it. Skip.
            if ownerString and ownerString.Value ~= "" then continue end

            -- 3. Physical Part Check
            local main = box:FindFirstChild("Main")
            if main and main:IsA("BasePart") and not main.Anchored then
                table.insert(results, {
                    Part = main,
                    Box = box
                })
            end
        end
    end

    return results
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘

function ShopModule.Init(Tab, lot, GetImageFunc)
    if lot ~= nil then _LOT = lot end
    local GetImage = GetImageFunc or (getfenv and getfenv().GetImage) or function() return nil end

    local SelectedItem = ShopItems[1]
    local Quantity     = 1

    Tab:CreateSection("Hardware Store")

    -- Item Selection
    local Catalog = Tab:CreateImageSelector("Select Item", {
        MultiSelect = false,
        Rows        = 1,
        SlotSize    = UDim2.new(0, 75, 0, 75),
    }, function(name)
        for _, item in pairs(ShopItems) do
            if item.Name == name then
                SelectedItem = item
                break
            end
        end
        ShopModule.UpdateDisplay()
    end)

    for _, item in pairs(ShopItems) do
        local img = GetImage("Images", item.Image)
        Catalog:AddSlot(img, item.Name, "$" .. tostring(item.Price))
    end

    -- Quantity Slider
    Tab:CreateSlider("Quantity", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    -- The "Buy" Logic
    local PurchaseBtn = Tab:CreateAction("Finalize Order", "$0", function()
        if not SelectedItem then return end
        if _LOT == nil or _LOT.IsBusy() then return end

        local itemData = ResolveItemParts(SelectedItem, Quantity)
        
        -- Fallback: TP player back if nothing is found
        if #itemData == 0 then 
            warn("[ShopModule] No available items found.")
            local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = CFrame.new(PLAYER_TP_POS) end
            return 
        end

        local jobs = {}
        for _, data in ipairs(itemData) do
            table.insert(jobs, {
                target = data.Part,
                goalCF = CFrame.new(ITEM_TP_POS + Vector3.new(0, data.Part.Size.Y * 0.5, 0)),
            })
        end

        task.spawn(function()
            -- 1. TP the Items to the counter
            local success = _LOT.TeleportMany(jobs)
            
            if success then
                -- 2. TP Player to the counter to trigger the prompt
                local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = CFrame.new(PLAYER_TP_POS)
                    task.wait(0.3) -- Wait for character to stabilize
                end

                -- 3. Interact with the store
                for _, data in ipairs(itemData) do
                    -- Try to find a ClickDetector on the box or nearby
                    local detector = data.Box:FindFirstChildOfClass("ClickDetector")
                    if detector then
                        fireclickdetector(detector)
                        task.wait(0.3) -- Wait for UI to pop up
                        
                        -- 4. Click the "ChatChoice" button automatically
                        AutoConfirmUI()
                    end
                end
            end
        end)
    end, false)

    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local newText = string.format("$%d", SelectedItem.Price * Quantity)
        if PurchaseBtn then
            if PurchaseBtn.Set then PurchaseBtn:Set(newText)
            elseif PurchaseBtn.Update then PurchaseBtn:Update(newText) end
        end
    end

    ShopModule.UpdateDisplay()
end

return ShopModule

local ShopModule = {}

-- 1. Shop Configuration
local ShopItems = {
    {Name = "Large Axe", Image = "Axe.png", Price = 500}
    -- Add more items here following the same format!
}

function ShopModule.Init(Tab)
    -- Internal State
    local SelectedItem = ShopItems[1]
    local Quantity = 1

    Tab:CreateSection("Hardware Store")

    -- 2. Item Catalog
    local Catalog = Tab:CreateImageSelector("Select Item", {
        MultiSelect = false,
        Rows = 1,
        SlotSize = UDim2.new(0, 75, 0, 75)
    }, function(name)
        for _, item in pairs(ShopItems) do
            if item.Name == name then
                SelectedItem = item
                break
            end
        end
        ShopModule.UpdateDisplay()
    end)

    -- Populate the Catalog
    for _, item in pairs(ShopItems) do
        local img = GetImage("Images", item.Image) 
        Catalog:AddSlot(img, item.Name, "$" .. tostring(item.Price))
    end

    -- 3. Quantity Slider (Cleaned up: Only shows "Quantity")
    local QuantitySlider = Tab:CreateSlider("Quantity", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    -- 4. Purchase Action (Initial state set to Purchase ($0))
    local PurchaseBtn = Tab:CreateAction("Finalize Order", "$0", function()
        if not SelectedItem then return end
        local total = SelectedItem.Price * Quantity
        print(string.format("Purchased %dx %s for $%d", Quantity, SelectedItem.Name, total))
    end, false) 

    -- Update Display Logic
    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local total = SelectedItem.Price * Quantity
        
        -- Update the Purchase Button text dynamically
        -- Note: If your library uses a specific name for updating the button (like :Set() or :Update()), 
        -- make sure it matches your library's API.
        if PurchaseBtn then
            local newText = string.format("$%d", total)
            if PurchaseBtn.Set then
                PurchaseBtn:Set(newText)
            elseif PurchaseBtn.Update then
                PurchaseBtn:Update(newText)
            end
        end
    end

    ShopModule.UpdateDisplay()
end

return ShopModule

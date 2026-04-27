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

    -- 2. Item Catalog (Now supports custom sizes and rows!)
    local Catalog = Tab:CreateImageSelector("Select Item", {
        MultiSelect = false,
        Rows = 1, -- Change this to add more rows!
        SlotSize = UDim2.new(0, 75, 0, 75) -- Customize slot width and height
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

    -- 3. Quantity Slider 
    local QuantitySlider = Tab:CreateSlider("Quantity / $0", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    -- 4. Purchase Action (Secure check removed!)
    local PurchaseBtn = Tab:CreateAction("Finalize Order", "Purchase", function()
        if not SelectedItem then return end
        local total = SelectedItem.Price * Quantity
        print(string.format("Purchased %dx %s for $%d", Quantity, SelectedItem.Name, total))
    end, false) -- 'false' removes the lock icon

    -- Update Display Logic
    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local total = SelectedItem.Price * Quantity
        
        -- Update Slider text
        if QuantitySlider and QuantitySlider.SetTitle then
            QuantitySlider:SetTitle(string.format("Quantity / $%d", total))
        end

        -- Update Purchase Button text 
        -- (Note: Use :Set() or :Update() depending on your specific UI library's method for updating actions)
        if PurchaseBtn then
            local newText = string.format("Purchase ($%d)", total)
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

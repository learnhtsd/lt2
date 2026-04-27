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
    local Catalog = Tab:CreateImageSelector("Select Item", false, function(name)
        for _, item in pairs(ShopItems) do
            if item.Name == name then
                SelectedItem = item
                break
            end
        end
        ShopModule.UpdateDisplay()
    end)

    -- Populate the Catalog and pass the Price as the SubText
    for _, item in pairs(ShopItems) do
        local img = GetImage("Images", item.Image) 
        -- Pass the formatted price as the third argument (SlotSubText)
        Catalog:AddSlot(img, item.Name, "$" .. tostring(item.Price))
    end

    -- 3. Quantity Slider (Total price display merged here)
    local QuantitySlider = Tab:CreateSlider("Quantity / $0", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    -- Update Display Logic
    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local total = SelectedItem.Price * Quantity
        
        -- Dynamically update the slider title to show Quantity / TotalPrice
        -- Note: If your UI library uses a different method (like :Set() or :Update()), change :SetTitle below.
        if QuantitySlider and QuantitySlider.SetTitle then
            QuantitySlider:SetTitle(string.format("Quantity / $%d", total))
        end
    end

    -- 4. Purchase Action
    Tab:CreateAction("Finalize Order", "Purchase", function()
        local total = SelectedItem.Price * Quantity
        print(string.format("Purchased %dx %s for $%d", Quantity, SelectedItem.Name, total))
    end, true) 

    ShopModule.UpdateDisplay()
end

return ShopModule

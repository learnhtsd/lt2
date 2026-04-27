local ShopModule = {}

-- 1. Shop Configuration (Proper Table Format)
local ShopItems = {
    {Name = "Large Axe", Image = "Axe.png", Price = 500}
    -- Add more items here following the same format!
}

function ShopModule.Init(Tab)
    -- Internal State
    local SelectedItem = ShopItems[1]
    local Quantity = 1

    Tab:CreateSection("Hardware Store")

    -- 2. Item Catalog (Using our new ImageSelector)
    local Catalog = Tab:CreateImageSelector("Select Item", false, function(name)
        for _, item in pairs(ShopItems) do
            if item.Name == name then
                SelectedItem = item
                break
            end
        end
        ShopModule.UpdateDisplay()
    end)

    -- Populate the Catalog from our table
    for _, item in pairs(ShopItems) do
        -- We call GetImage HERE, inside the loop
        local img = GetImage("Images", item.Image) 
        Catalog:AddSlot(img, item.Name)
    end

    -- 3. Pricing & Selection Info
    local PriceInfo = Tab:CreateInfoBox("Selection", "Select an item to see details.")

    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local total = SelectedItem.Price * Quantity
        PriceInfo:SetTitle(SelectedItem.Name)
        PriceInfo:SetDescription(string.format(
            "Price per unit: $%d\nTotal Price: $%d", 
            SelectedItem.Price, 
            total
        ))
    end

    -- 4. Quantity Slider
    Tab:CreateSlider("Quantity", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    -- 5. Purchase Action
    Tab:CreateAction("Finalize Order", "Purchase", function()
        local total = SelectedItem.Price * Quantity
        print(string.format("Purchased %dx %s for $%d", Quantity, SelectedItem.Name, total))
    end, true) 

    ShopModule.UpdateDisplay()
end

return ShopModule

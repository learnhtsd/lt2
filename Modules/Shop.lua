local ShopModule = {}

-- 1. Shop Configuration (Edit your items here!)
local ShopItems = {
    local img = GetImage("Images", "Axe.png")
}

function ShopModule.Init(Tab)
    -- Internal State
    local SelectedItem = ShopItems[1]
    local Quantity = 1

    Tab:CreateSection("Hardware Store")

    -- 2. Item Catalog (Using our new ImageSelector)
    local Catalog = Tab:CreateImageSelector("Select Item", false, function(name)
        -- Find the item data based on the name selected
        for _, item in pairs(ShopItems) do
            if item.Name == name then
                SelectedItem = item
                break
            end
        end
        
        -- Update the info box dynamically
        ShopModule.UpdateDisplay()
    end)

    -- Populate the Catalog from our table
    for _, item in pairs(ShopItems) do
        -- Assuming your images are in GitHub under Images/Shop/
        local img = GetImage("Shop", item.Image)
        Catalog:AddSlot(img, item.Name)
    end

    -- 3. Pricing & Selection Info
    local PriceInfo = Tab:CreateInfoBox("Selection", "Select an item to see details.")

    -- Helper to update the text display
    ShopModule.UpdateDisplay = function()
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
        
        -- Logic for checking money would go here
        print(string.format("Purchased %dx %s for $%d", Quantity, SelectedItem.Name, total))
        
        Library:Notify("Purchase Success", "You bought " .. Quantity .. "x " .. SelectedItem.Name, 5)
    end, true) -- Secure mode enabled (double-click to buy)

    -- Initialize the display for the first item
    ShopModule.UpdateDisplay()
end

return ShopModule

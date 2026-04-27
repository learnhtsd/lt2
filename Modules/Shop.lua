-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine
-- Requires LooseObjectTeleport (LOT) to be passed in via Init()

local ShopModule = {}

local Players = game:GetService("Players")
local Player  = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     SHOP CONFIGURATION                          │
-- │                                                                 │
-- │  World structure:                                               │
-- │    workspace.Stores                                             │
-- │      ├─ ShopItems   (one folder per store, all named the same)  │
-- │      │    └─ Box                                                │
-- │      │        ├─ BoxItemName  (StringValue — item identity)     │
-- │      │        ├─ Main         (BasePart — what LOT grabs)       │
-- │      │        ├─ Owner                                          │
-- │      │        └─ Type                                           │
-- │      ├─ ShopItems                                               │
-- │      │    └─ Box ...                                            │
-- │      └─ ShopItems  ...                                          │
-- │                                                                 │
-- │  There is no label telling stores apart, so ResolveItemParts    │
-- │  scans EVERY ShopItems folder and collects any Box whose        │
-- │  BoxItemName.Value matches. This works fine because item names  │
-- │  are unique across all stores.                                  │
-- │                                                                 │
-- │  Per-item config fields:                                        │
-- │    Name        — display name shown in the UI catalog           │
-- │    Image       — filename passed to GetImage()                  │
-- │    Price       — cost shown on the buy button                   │
-- │    BoxItemName — must match BoxItemName.Value inside the Box    │
-- └─────────────────────────────────────────────────────────────────┘

local ShopItems = {
    {
        Name        = "Basic Hatchet",
        Image       = "BasicHatchet.png",
        Price       = 500,
        BoxItemName = "BasicHatchet",  -- must match BoxItemName.Value in-world
    },
    -- Add more items following the same format:
    -- {
    --     Name        = "Large Axe",
    --     Image       = "LargeAxe.png",
    --     Price       = 800,
    --     BoxItemName = "LargeAxe",
    -- },
}

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      WORLD PATH RESOLVER                        │
-- │                                                                 │
-- │  Scans every ShopItems folder under workspace.Stores and        │
-- │  collects up to `quantity` Box models whose BoxItemName.Value   │
-- │  matches item.BoxItemName. Returns their Main BaseParts.        │
-- └─────────────────────────────────────────────────────────────────┘
local function ResolveItemParts(item, quantity)
    local stores = workspace:FindFirstChild("Stores")
    if not stores then
        warn("[ShopModule] workspace.Stores not found.")
        return {}
    end

    local results = {}

    -- Iterate every direct child of Stores named "ShopItems"
    for _, shopItems in ipairs(stores:GetChildren()) do
        if #results >= quantity then break end
        if shopItems.Name ~= "ShopItems" then continue end

        for _, box in ipairs(shopItems:GetChildren()) do
            if #results >= quantity then break end
            if not (box:IsA("Model") and box.Name == "Box") then continue end

            local nameVal = box:FindFirstChild("BoxItemName")
            if not (nameVal and nameVal:IsA("StringValue")) then continue end
            if nameVal.Value ~= item.BoxItemName then continue end

            local main = box:FindFirstChild("Main")
            if main and main:IsA("BasePart") and not main.Anchored then
                table.insert(results, main)
            end
        end
    end

    if #results == 0 then
        warn(string.format(
            "[ShopModule] No Box with BoxItemName='%s' found in any ShopItems folder.\n"
            .. "  Check the item is in stock and Main is not anchored.",
            item.BoxItemName
        ))
    elseif #results < quantity then
        warn(string.format(
            "[ShopModule] Requested %d × '%s' but only %d found across all stores.",
            quantity, item.Name, #results
        ))
    end

    return results
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘

-- Tab          — the UI tab object from your library
-- LOT          — the LooseObjectTeleport module (already initialised)
-- GetImageFunc — optional override for GetImage(); falls back to the
--               global GetImage if not provided
function ShopModule.Init(Tab, LOT, GetImageFunc)
    local GetImage = GetImageFunc
                  or (getfenv and getfenv().GetImage)
                  or function() return nil end

    -- ── Internal state ────────────────────────────────────────────
    local SelectedItem = ShopItems[1]
    local Quantity     = 1

    -- ── UI construction ───────────────────────────────────────────
    Tab:CreateSection("Hardware Store")

    -- Item catalog
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

    -- Quantity slider
    Tab:CreateSlider("Quantity", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    -- Purchase button
    local PurchaseBtn = Tab:CreateAction("Finalize Order", "$0", function()
        if not SelectedItem then return end

        if LOT.IsBusy() then
            warn("[ShopModule] A teleport is already running — please wait.")
            return
        end

        local parts = ResolveItemParts(SelectedItem, Quantity)
        if #parts == 0 then return end

        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            warn("[ShopModule] No character found.")
            return
        end

        -- Fan items out sideways in front of the player
        local jobs      = {}
        local spacing   = 3
        local rightVec  = root.CFrame.RightVector
        local totalSpan = (#parts - 1) * spacing

        for i, part in ipairs(parts) do
            local sideOffset = rightVec * ((i - 1) * spacing - totalSpan * 0.5)
            local dropPos    = (root.CFrame * CFrame.new(0, 0, -5)).Position
                             + sideOffset
                             + Vector3.new(0, part.Size.Y * 0.5, 0)

            table.insert(jobs, {
                target = part,
                goalCF = CFrame.new(dropPos),
            })
        end

        print(string.format(
            "[ShopModule] Purchasing %d × %s for $%d.",
            #parts, SelectedItem.Name, SelectedItem.Price * #parts
        ))

        task.spawn(function()
            local success = LOT.TeleportMany(jobs)
            print(string.format(
                "[ShopModule] Teleport %s.",
                success and "complete" or "cancelled"
            ))
        end)
    end, false)

    -- ── Display updater ───────────────────────────────────────────
    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local newText = string.format("$%d", SelectedItem.Price * Quantity)
        if PurchaseBtn then
            if PurchaseBtn.Set        then PurchaseBtn:Set(newText)
            elseif PurchaseBtn.Update then PurchaseBtn:Update(newText) end
        end
    end

    ShopModule.UpdateDisplay()
end

return ShopModule

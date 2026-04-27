-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ShopModule = {}

local Players = game:GetService("Players")
local Player  = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     LOT REFERENCE                               │
-- │                                                                 │
-- │  Set this BEFORE or AFTER Init — both work.                     │
-- │                                                                 │
-- │  Option A — pass at init time:                                  │
-- │    ShopModule.Init(Tab, LOT)                                    │
-- │                                                                 │
-- │  Option B — set separately (useful if load order is awkward):   │
-- │    ShopModule.SetLOT(LOT)                                       │
-- │    ShopModule.Init(Tab)                                          │
-- └─────────────────────────────────────────────────────────────────┘
local _LOT = nil  -- internal reference, set via Init or SetLOT

function ShopModule.SetLOT(lot)
    _LOT = lot
end

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
-- │      └─ ShopItems  ...                                          │
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
        BoxItemName = "BasicHatchet",
    },
    -- {
    --     Name        = "Large Axe",
    --     Image       = "LargeAxe.png",
    --     Price       = 800,
    --     BoxItemName = "LargeAxe",
    -- },
}

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      WORLD PATH RESOLVER                        │
-- └─────────────────────────────────────────────────────────────────┘
local function ResolveItemParts(item, quantity)
    local stores = workspace:FindFirstChild("Stores")
    if not stores then
        warn("[ShopModule] workspace.Stores not found.")
        return {}
    end

    local results = {}

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
            "[ShopModule] No Box with BoxItemName='%s' found in any ShopItems folder.",
            item.BoxItemName
        ))
    elseif #results < quantity then
        warn(string.format(
            "[ShopModule] Requested %d × '%s' but only %d found.",
            quantity, item.Name, #results
        ))
    end

    return results
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘

-- Tab          — the UI tab object from your library
-- lot          — (optional) the LooseObjectTeleport module.
--               Can also be supplied via ShopModule.SetLOT(lot) instead.
-- GetImageFunc — (optional) override for GetImage()
function ShopModule.Init(Tab, lot, GetImageFunc)
    -- Accept LOT either as a parameter or from a prior SetLOT call
    if lot ~= nil then
        _LOT = lot
    end

    local GetImage = GetImageFunc
                  or (getfenv and getfenv().GetImage)
                  or function() return nil end

    -- ── Internal state ────────────────────────────────────────────
    local SelectedItem = ShopItems[1]
    local Quantity     = 1

    -- ── UI construction ───────────────────────────────────────────
    Tab:CreateSection("Hardware Store")

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

    Tab:CreateSlider("Quantity", 1, 50, 1, function(val)
        Quantity = val
        ShopModule.UpdateDisplay()
    end)

    local PurchaseBtn = Tab:CreateAction("Finalize Order", "$0", function()
        if not SelectedItem then return end

        -- Guard: LOT must be set before purchasing
        if _LOT == nil then
            warn("[ShopModule] LOT is not set. Call ShopModule.SetLOT(lot) or pass it to Init.")
            return
        end

        if _LOT.IsBusy() then
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
            local success = _LOT.TeleportMany(jobs)
            print(string.format(
                "[ShopModule] Teleport %s.",
                success and "complete" or "cancelled"
            ))
        end)
    end, false)

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

-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ShopModule = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Player            = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     PURCHASE COORDINATES                        │
-- │                                                                 │
-- │  ITEM_DROP_CF   — where LOT places the shop box before buying  │
-- │  PLAYER_BUY_CF  — where the player is teleported to trigger    │
-- │                   the NPC purchase range                        │
-- └─────────────────────────────────────────────────────────────────┘
local ITEM_DROP_CF  = CFrame.new(268.5, 5.2,  67.4)
local PLAYER_BUY_CF = CFrame.new(262.1, 3.2,  64.8)

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     LOT REFERENCE                               │
-- └─────────────────────────────────────────────────────────────────┘
local _LOT = nil

function ShopModule.SetLOT(lot)
    _LOT = lot
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     NPC / REMOTE SETUP                          │
-- │                                                                 │
-- │  Mirrors the buyer script's NPC table and remote references.    │
-- │  IDs are fetched once on the first purchase attempt.            │
-- └─────────────────────────────────────────────────────────────────┘
local NPCs = {
    Thom    = workspace.Stores.WoodRUs.Thom,
    Corey   = workspace.Stores.FurnitureStore.Corey,
    Jenny   = workspace.Stores.CarStore.Jenny,
    Bob     = workspace.Stores.ShackShop.Bob,
    Timothy = workspace.Stores.FineArt.Timothy,
    Lincoln = workspace.Stores.LogicStore.Lincoln,
}

local Remote      = ReplicatedStorage.NPCDialog.PlayerChatted
local PromptChat  = ReplicatedStorage.NPCDialog.PromptChat
local SetChatting = ReplicatedStorage.NPCDialog.SetChattingValue

-- IDs are populated once by FetchNPCIDs() below
local NPCIDs    = {}
local IDsFetched = false

local function Notify(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title    = title,
        Text     = text,
        Duration = duration or 3,
    })
end

-- Fetches dialog IDs for every NPC — called once before the first purchase.
-- Blocks the calling coroutine while it runs (uses task.wait internally).
local function FetchNPCIDs()
    if IDsFetched then return end

    Notify("Shop", "Fetching NPC IDs, please wait…", 5)

    SetChatting:InvokeServer(true)

    local lastData
    local conn = PromptChat.OnClientEvent:Connect(function(_, chatData)
        lastData = chatData
    end)

    for name, npc in pairs(NPCs) do
        if not npc:FindFirstChild("Dialog") then
            Instance.new("Dialog", npc)
        end
        lastData = nil
        PromptChat:FireServer(true, npc, npc.Dialog)
        local t = tick()
        repeat task.wait() until lastData or tick() - t > 5
        if lastData then
            NPCIDs[name] = lastData.ID
        else
            warn("[ShopModule] Timed out fetching ID for NPC: " .. name)
        end
    end

    conn:Disconnect()
    SetChatting:InvokeServer(false)

    IDsFetched = true
    Notify("Shop", "NPC IDs ready.", 3)
end

-- Returns the NPC arg table for the NPC closest to the given BasePart.
local function GetNearestNPCArg(mainPart)
    if not mainPart then return nil end

    local bestDist = math.huge
    local bestNPC, bestName

    for name, npc in pairs(NPCs) do
        local store = npc.Parent
        if store and store:FindFirstChild("Counter") then
            local dist = (store.Counter.CFrame.p - mainPart.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestNPC  = npc
                bestName = name
            end
        end
    end

    if not bestNPC then return nil end
    if not bestNPC:FindFirstChild("Dialog") then
        Instance.new("Dialog", bestNPC)
    end

    return {
        ID        = NPCIDs[bestName],
        Character = bestNPC,
        Name      = bestName,
        Dialog    = bestNPC.Dialog,
    }
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       PURCHASE SEQUENCE                         │
-- │                                                                 │
-- │  Full flow for a single part:                                   │
-- │    1. LOT teleports the box to ITEM_DROP_CF                     │
-- │    2. WaitForBatch confirms the TP completed                    │
-- │    3. Player is teleported to PLAYER_BUY_CF                     │
-- │    4. Remotes are spammed until the box's parent becomes        │
-- │       "PlayerModels" (or a timeout/vanish is detected)          │
-- └─────────────────────────────────────────────────────────────────┘
local SPAM_INTERVAL    = 0.1   -- seconds between each remote fire
local SPAM_TIMEOUT     = 30    -- seconds before giving up
local SPAM_NOTIFY_FREQ = 50    -- notify every N fires

local function SpamPurchase(mainPart, npcArg, itemName)
    local fireCount = 0
    local deadline  = tick() + SPAM_TIMEOUT

    Notify("Shop", ("Buying '%s' from %s…"):format(itemName, npcArg.Name), 4)

    while tick() < deadline do
        -- ── Success ──────────────────────────────────────────────
        if mainPart.Parent and mainPart.Parent.Name == "PlayerModels" then
            Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
            return true
        end

        -- ── Item vanished unexpectedly ────────────────────────────
        if not mainPart or not mainPart.Parent then
            Notify("⚠️ Item Gone", "Object disappeared before purchase.", 4)
            return false
        end

        -- ── Fire the three-step purchase sequence ─────────────────
        pcall(function()
            Remote:InvokeServer(npcArg, "Initiate")
            Remote:InvokeServer(npcArg, "ConfirmPurchase")
            Remote:InvokeServer(npcArg, "EndChat")
        end)

        fireCount += 1

        if fireCount % SPAM_NOTIFY_FREQ == 0 then
            Notify("⏳ Buying…", ("Fired %d times for '%s'"):format(fireCount, itemName), 3)
        end

        task.wait(SPAM_INTERVAL)
    end

    Notify("❌ Timeout", ("Purchase of '%s' timed out after %d fires."):format(itemName, fireCount), 5)
    return false
end

-- Runs the full TP → wait → player warp → spam sequence for one part.
local function PurchasePart(mainPart, itemName)
    -- Step 1: Build a single-item job and hand it to LOT
    local job = { target = mainPart, goalCF = ITEM_DROP_CF }

    local success = _LOT.TeleportMany({ job })

    -- Step 2: TeleportMany is synchronous — it already returned — but use
    -- WaitForBatch as a safety net in case another batch is still winding down.
    if _LOT.IsBusy() then
        Notify("Shop", "Waiting for TP to settle…", 2)
        success = _LOT.WaitForBatch()
    end

    if not success then
        Notify("❌ TP Failed", ("Teleport cancelled for '%s'."):format(itemName), 4)
        return false
    end

    -- Step 3: Warp the player into purchase range
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        Notify("❌ Error", "No character found.", 3)
        return false
    end

    root.CFrame = PLAYER_BUY_CF

    -- One frame so the server can register our new position
    task.wait(0.1)

    -- Step 4: Identify the nearest NPC and spam the remotes
    local npcArg = GetNearestNPCArg(mainPart)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", ("Could not find NPC for '%s'."):format(itemName), 4)
        return false
    end

    return SpamPurchase(mainPart, npcArg, itemName)
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     SHOP CONFIGURATION                          │
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
function ShopModule.Init(Tab, lot, GetImageFunc)
    if lot ~= nil then _LOT = lot end

    local GetImage = GetImageFunc
                  or (getfenv and getfenv().GetImage)
                  or function() return nil end

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

        if _LOT == nil then
            warn("[ShopModule] LOT is not set. Call ShopModule.SetLOT(lot) or pass it to Init.")
            return
        end

        if _LOT.IsBusy() then
            Notify("Shop", "A teleport is already running — please wait.", 3)
            return
        end

        local parts = ResolveItemParts(SelectedItem, Quantity)
        if #parts == 0 then return end

        -- Run the full purchase sequence in a background thread so the UI
        -- doesn't freeze. Items are bought one at a time so each TP → spam
        -- cycle completes cleanly before the next one starts.
        task.spawn(function()
            -- Fetch NPC IDs on the very first purchase (no-op on repeats)
            FetchNPCIDs()

            local bought   = 0
            local failed   = 0
            local itemName = SelectedItem.Name

            Notify("Shop", ("Starting purchase of %d × %s…"):format(#parts, itemName), 4)

            for _, mainPart in ipairs(parts) do
                -- Skip if part already vanished between the resolve and now
                if not mainPart or not mainPart.Parent then
                    failed += 1
                    continue
                end

                -- Guard: don't queue while another LOT batch is still alive
                if _LOT.IsBusy() then
                    _LOT.WaitForBatch()
                end

                local ok = PurchasePart(mainPart, itemName)
                if ok then
                    bought += 1
                else
                    failed += 1
                end
            end

            Notify(
                "Shop — Done",
                ("Bought %d / %d × %s.%s"):format(
                    bought, #parts, itemName,
                    failed > 0 and ("\n%d failed."):format(failed) or ""
                ),
                5
            )
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

-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ShopModule = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Player            = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                        STORE REGISTRY                           │
-- │                                                                  │
-- │  Each entry maps a store key (used in LT2ItemList.lua as        │
-- │  item.Store) to its NPC, item drop position, and the position   │
-- │  the player stands at to trigger the purchase remote.           │
-- │                                                                  │
-- │  ItemDropCF  — where the item is teleported before buying.      │
-- │  PlayerBuyCF — where the player stands to fire the NPC remote.  │
-- └─────────────────────────────────────────────────────────────────┘
local STORES = {
    WoodRUs = {
        NPC         = workspace.Stores.WoodRUs.Thom,
        ItemDropCF  = CFrame.new(268.5, 5.2,  67.4),
        PlayerBuyCF = CFrame.new(262.1, 3.2,  64.8),
    },
    FurnitureStore = {
        NPC         = workspace.Stores.FurnitureStore.Corey,
        ItemDropCF  = CFrame.new(0, 0, 0),   -- TODO: set correct drop position
        PlayerBuyCF = CFrame.new(0, 0, 0),   -- TODO: set correct buy position
    },
    CarStore = {
        NPC         = workspace.Stores.CarStore.Jenny,
        ItemDropCF  = CFrame.new(0, 0, 0),
        PlayerBuyCF = CFrame.new(0, 0, 0),
    },
    ShackShop = {
        NPC         = workspace.Stores.ShackShop.Bob,
        ItemDropCF  = CFrame.new(0, 0, 0),
        PlayerBuyCF = CFrame.new(0, 0, 0),
    },
    FineArt = {
        NPC         = workspace.Stores.FineArt.Timothy,
        ItemDropCF  = CFrame.new(0, 0, 0),
        PlayerBuyCF = CFrame.new(0, 0, 0),
    },
    LogicStore = {
        NPC         = workspace.Stores.LogicStore.Lincoln,
        ItemDropCF  = CFrame.new(0, 0, 0),
        PlayerBuyCF = CFrame.new(0, 0, 0),
    },
}

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     LOT REFERENCE                               │
-- └─────────────────────────────────────────────────────────────────┘
local _LOT = nil

function ShopModule.SetLOT(lot)
    _LOT = lot
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     NPC / REMOTE SETUP                          │
-- └─────────────────────────────────────────────────────────────────┘
local Remote      = ReplicatedStorage.NPCDialog.PlayerChatted
local PromptChat  = ReplicatedStorage.NPCDialog.PromptChat
local SetChatting = ReplicatedStorage.NPCDialog.SetChattingValue

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       FUNDS REMOTE                              │
-- └─────────────────────────────────────────────────────────────────┘
local GetFundsRemote = nil

local function FindRemoteRecursive(root, name)
    for _, child in ipairs(root:GetDescendants()) do
        if child.Name == name and child:IsA("RemoteFunction") then
            return child
        end
    end
    return nil
end

local function FetchFunds()
    if not GetFundsRemote then
        GetFundsRemote = FindRemoteRecursive(ReplicatedStorage, "GetFunds")
        if not GetFundsRemote then
            warn("[ShopModule] GetFunds RemoteFunction not found.")
            return nil
        end
    end
    local ok, result = pcall(function()
        return GetFundsRemote:InvokeServer()
    end)
    if ok and type(result) == "number" then return result end
    warn("[ShopModule] GetFunds failed: " .. tostring(result))
    return nil
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      NPC ID FETCHING                            │
-- └─────────────────────────────────────────────────────────────────┘
local NPCIDs     = {}   -- storeKey → dialog ID
local IDsFetched = false

local function Notify(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title    = title,
        Text     = text,
        Duration = duration or 3,
    })
end

local function FetchNPCIDs()
    if IDsFetched then return end

    Notify("Shop", "Fetching NPC IDs, please wait…", 5)
    SetChatting:InvokeServer(true)

    local lastData
    local conn = PromptChat.OnClientEvent:Connect(function(_, chatData)
        lastData = chatData
    end)

    for storeKey, store in pairs(STORES) do
        local npc = store.NPC
        if not npc:FindFirstChild("Dialog") then
            Instance.new("Dialog", npc)
        end
        lastData = nil
        PromptChat:FireServer(true, npc, npc.Dialog)
        local t = tick()
        repeat task.wait() until lastData or tick() - t > 5
        if lastData then
            NPCIDs[storeKey] = lastData.ID
        else
            warn("[ShopModule] Timed out fetching ID for store: " .. storeKey)
        end
    end

    conn:Disconnect()
    SetChatting:InvokeServer(false)

    IDsFetched = true
    Notify("Shop", "NPC IDs ready.", 3)
end

-- Returns the npcArg table for a specific store key.
local function GetNPCArg(storeKey)
    local store = STORES[storeKey]
    if not store then
        warn("[ShopModule] Unknown store key: " .. tostring(storeKey))
        return nil
    end
    local npc = store.NPC
    if not npc:FindFirstChild("Dialog") then
        Instance.new("Dialog", npc)
    end
    return {
        ID        = NPCIDs[storeKey],
        Character = npc,
        Name      = storeKey,
        Dialog    = npc.Dialog,
    }
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │               SAFE INVOKE — HARD TIMEOUT PER CALL               │
-- └─────────────────────────────────────────────────────────────────┘
local INVOKE_TIMEOUT = 3

local function SafeInvoke(npcArg, action)
    local co   = coroutine.running()
    local done = false

    local fireThread = task.spawn(function()
        pcall(function() Remote:InvokeServer(npcArg, action) end)
        if not done then done = true; task.spawn(co) end
    end)

    task.delay(INVOKE_TIMEOUT, function()
        if not done then
            done = true
            pcall(task.cancel, fireThread)
            task.spawn(co)
        end
    end)

    coroutine.yield()
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     POWER OF EASE PURCHASE                      │
-- └─────────────────────────────────────────────────────────────────┘
local POE_PRICE    = 10009000
local POE_TP_CF    = CFrame.new(1059.4, 17.2, 1130.3)
local POE_TIMEOUT  = 60
local POE_INTERVAL = 0.2

local function PurchasePowerOfEase()
    local funds = FetchFunds()
    if funds == nil then
        Notify("❌ Funds Error", "Could not retrieve your balance.", 4)
        return
    end
    if funds < POE_PRICE then
        Notify("❌ Insufficient Funds",
            ("Need $%s  •  Have $%s  •  Short $%s"):format(
                tostring(POE_PRICE), tostring(funds), tostring(POE_PRICE - funds)), 5)
        return
    end

    FetchNPCIDs()

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then Notify("❌ Error", "No character found.", 3) return end

    local returnCF = root.CFrame
    root.CFrame = POE_TP_CF
    task.wait(0.15)

    Notify("Shop", "Initiating Power of Ease purchase…", 4)

    -- Find nearest NPC to where the player is now
    local bestKey, bestDist = nil, math.huge
    for storeKey, store in pairs(STORES) do
        local npc = store.NPC
        local dist = (npc.Parent:FindFirstChild("Counter") and
            (npc.Parent.Counter.CFrame.p - root.Position).Magnitude) or math.huge
        if dist < bestDist then bestDist = dist; bestKey = storeKey end
    end

    local npcArg = bestKey and GetNPCArg(bestKey)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", "Could not find an NPC.", 4)
        root.CFrame = returnCF
        return
    end

    local fireCount = 0
    local deadline  = tick() + POE_TIMEOUT
    local purchased = false

    while tick() < deadline do
        SafeInvoke(npcArg, "Initiate")
        SafeInvoke(npcArg, "ConfirmPurchase")
        SafeInvoke(npcArg, "EndChat")
        fireCount += 1

        local newFunds = FetchFunds()
        if newFunds and newFunds < funds then
            purchased = true
            break
        end

        if fireCount % 25 == 0 then
            Notify("⏳ Purchasing…", ("Fired %d times…"):format(fireCount), 3)
        end
        task.wait(POE_INTERVAL)
    end

    if purchased then
        Notify("✅ Power of Ease!", ("Purchased after %d fires."):format(fireCount), 5)
    else
        Notify("❌ Timeout", ("Not confirmed after %d fires."):format(fireCount), 5)
    end

    task.wait(0.1)
    local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if r then r.CFrame = returnCF end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       PURCHASE SEQUENCE                         │
-- └─────────────────────────────────────────────────────────────────┘
local SPAM_TIMEOUT     = 30
local SPAM_NOTIFY_FREQ = 50

local function IsSuccessParent(parent)
    if not parent then return false end
    if parent.Name == "PlayerModels" then return true end
    if parent == Player.Backpack     then return true end
    if parent == Player.Character    then return true end
    local current = parent
    while current do
        if current.Name == "PlayerModels" then return true end
        current = current.Parent
    end
    return false
end

local function SpamPurchase(mainPart, npcArg, itemName)
    local fireCount = 0
    local deadline  = tick() + SPAM_TIMEOUT
    local stopped   = false

    -- Fire loop in background — a hung InvokeServer can't block success detection
    task.spawn(function()
        while not stopped and tick() < deadline do
            SafeInvoke(npcArg, "Initiate")
            if stopped then break end
            SafeInvoke(npcArg, "ConfirmPurchase")
            if stopped then break end
            SafeInvoke(npcArg, "EndChat")
            fireCount += 1
            if fireCount % SPAM_NOTIFY_FREQ == 0 then
                Notify("⏳ Buying…", ("Fired %d times for '%s'"):format(fireCount, itemName), 3)
            end
        end
    end)

    -- Success detection runs independently on main thread
    while not stopped and tick() < deadline do
        local parent = mainPart and mainPart.Parent

        if IsSuccessParent(parent) then
            stopped = true
            Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
            return true
        end

        if parent == nil then
            task.wait()
            local newParent = mainPart and mainPart.Parent
            if IsSuccessParent(newParent) then
                stopped = true
                Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
                return true
            end
            if newParent == nil then
                stopped = true
                Notify("⚠️ Item Gone", ("'%s' removed before purchase."):format(itemName), 4)
                return false
            end
        end

        task.wait(0.05)
    end

    stopped = true
    Notify("❌ Timeout", ("'%s' timed out after %d fires."):format(itemName, fireCount), 5)
    return false
end

-- storeKey drives which drop/buy positions and NPC are used.
local function PurchasePart(mainPart, itemName, storeKey, originalCF)
    local store = STORES[storeKey]
    if not store then
        warn("[ShopModule] PurchasePart: unknown store key '" .. tostring(storeKey) .. "'")
        return false
    end

    -- TP item to this store's drop position
    local success = _LOT.TeleportMany({ { target = mainPart, goalCF = store.ItemDropCF } })
    if _LOT.IsBusy() then
        success = _LOT.WaitForBatch()
    end
    if not success then
        Notify("❌ TP Failed", ("Teleport cancelled for '%s'."):format(itemName), 4)
        return false
    end

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then Notify("❌ Error", "No character found.", 3) return false end

    originalCF = originalCF or root.CFrame

    -- Stand at this store's buy position
    root.CFrame = store.PlayerBuyCF
    task.wait(0.1)

    local npcArg = GetNPCArg(storeKey)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", ("Could not get NPC for store '%s'."):format(storeKey), 4)
        return false
    end

    local purchased = SpamPurchase(mainPart, npcArg, itemName)

    if purchased then
        task.wait(0.05)
        if mainPart and mainPart.Parent then
            _LOT.TeleportMany({ { target = mainPart, goalCF = originalCF } })
        end
        local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if r then r.CFrame = originalCF * CFrame.new(0, 0, 3) end
    end

    return purchased
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     REMOTE ITEM LIST LOADER                     │
-- └─────────────────────────────────────────────────────────────────┘
local function LoadItemList()
    local genv   = getgenv()
    local user   = genv.User   or "learnhtsd"
    local repo   = genv.Repo   or "lt2"
    local branch = genv.Branch or "main"

    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/LT2ItemList.lua?t=%s",
        user, repo, branch, tick()
    )

    local ok, result = pcall(function() return game:HttpGet(url) end)
    if not ok or not result or result:find("404: Not Found") then
        warn("[ShopModule] Could not fetch LT2ItemList.lua — " .. tostring(result))
        return nil
    end

    local fn, parseErr = loadstring(result)
    if not fn then
        warn("[ShopModule] LT2ItemList.lua syntax error — " .. tostring(parseErr))
        return nil
    end

    local ok2, items = pcall(fn)
    if not ok2 or type(items) ~= "table" then
        warn("[ShopModule] LT2ItemList.lua must return a table — " .. tostring(items))
        return nil
    end

    -- Validate that every item has a Store key that exists in STORES
    for _, item in ipairs(items) do
        if not item.Store then
            warn(("[ShopModule] Item '%s' is missing a Store field."):format(tostring(item.Name)))
        elseif not STORES[item.Store] then
            warn(("[ShopModule] Item '%s' has unknown Store '%s'."):format(
                tostring(item.Name), tostring(item.Store)))
        end
    end

    print(("[ShopModule] Loaded %d item(s)."):format(#items))
    return items
end

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
        warn(("[ShopModule] No Box '%s' found."):format(item.BoxItemName))
    elseif #results < quantity then
        warn(("[ShopModule] Wanted %d × '%s', found %d."):format(quantity, item.Name, #results))
    end

    return results
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘
function ShopModule.Init(Tab, lot, GetImageFunc)
    if lot ~= nil then _LOT = lot end

    local GetImage = GetImageFunc or getgenv().GetImage or function() return nil end

    local ShopItems = LoadItemList()
    if not ShopItems or #ShopItems == 0 then
        warn("[ShopModule] No items loaded — shop tab will be empty.")
        Tab:CreateSection("Hardware Store")
        return
    end

    local SelectedItem = ShopItems[1]
    local Quantity     = 1

    local PurchaseBtn
    local function UpdateDisplay()
        if not SelectedItem then return end
        if PurchaseBtn then
            PurchaseBtn:SetText(string.format("$%d", SelectedItem.Price * Quantity))
        end
    end

    Tab:CreateSection("Stores")

    local WoodRUsbanner = Tab:CreateImage("WoodRUs.png", 50)
    local Catalog = Tab:CreateImageSelector("Wood R Us", {
        MultiSelect = false,
        VisibleRows = 3,
        SlotSize    = UDim2.new(0, 70, 0, 70),
    }, function(name)
        for _, item in pairs(ShopItems) do
            if item.Name == name then SelectedItem = item break end
        end
        UpdateDisplay()
    end)

    for _, item in pairs(ShopItems) do
        local img = GetImage("", item.Image)
        Catalog:AddSlot(img, item.Name, "$" .. tostring(item.Price))
    end

    Tab:CreateSlider("Quantity", 1, 100, 1, function(val)
        Quantity = val
        UpdateDisplay()
    end)

    PurchaseBtn = Tab:CreateAction("Finalize Order", ("$%d"):format(ShopItems[1].Price), function()
        if not SelectedItem then return end
        if _LOT == nil then
            warn("[ShopModule] LOT not set.")
            return
        end
        if _LOT.IsBusy() then
            Notify("Shop", "A teleport is already running — please wait.", 3)
            return
        end
        if not SelectedItem.Store or not STORES[SelectedItem.Store] then
            Notify("❌ Config Error",
                ("Item '%s' has no valid Store set in LT2ItemList.lua."):format(SelectedItem.Name), 5)
            return
        end

        local totalCost = SelectedItem.Price * Quantity
        local funds     = FetchFunds()

        if funds == nil then
            Notify("❌ Funds Error", "Could not retrieve balance.", 4)
            return
        end
        if funds < totalCost then
            Notify("❌ Insufficient Funds",
                ("Need $%d  •  Have $%d  •  Short $%d"):format(totalCost, funds, totalCost - funds), 5)
            return
        end

        local parts = ResolveItemParts(SelectedItem, Quantity)
        if #parts == 0 then return end

        local char      = Player.Character
        local root      = char and char:FindFirstChild("HumanoidRootPart")
        local pressedCF = root and root.CFrame
        local storeKey  = SelectedItem.Store

        task.spawn(function()
            FetchNPCIDs()

            local bought   = 0
            local failed   = 0
            local itemName = SelectedItem.Name

            Notify("Shop",
                ("Purchasing %d × %s ($%d) from %s"):format(#parts, itemName, totalCost, storeKey), 4)

            for _, mainPart in ipairs(parts) do
                if not mainPart or not mainPart.Parent then failed += 1; continue end
                if _LOT.IsBusy() then _LOT.WaitForBatch() end

                local ok = PurchasePart(mainPart, itemName, storeKey, pressedCF)
                if ok then bought += 1 else failed += 1 end
            end

            Notify("Shop — Done",
                ("Bought %d / %d × %s.%s"):format(
                    bought, #parts, itemName,
                    failed > 0 and ("\n%d failed."):format(failed) or ""), 5)
        end)
    end, false)

    UpdateDisplay()
    ShopModule.UpdateDisplay = UpdateDisplay

    Tab:CreateSection("Special")
    Tab:CreateAction("Buy Power of Ease ($10,009,000)", "Buy", function()
        task.spawn(PurchasePowerOfEase)
    end, false)
end

return ShopModule

-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ShopModule = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Player            = Players.LocalPlayer

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

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   PER-STORE CONFIGURATION                       │
-- │                                                                 │
-- │  Each key matches a child name under workspace.Stores.          │
-- │  NPCName    → key in the NPCs table above.                      │
-- │  ItemDropCF → where the bought box is teleported to.            │
-- │  PlayerBuyCF→ where your character stands during purchase.      │
-- │                                                                 │
-- │  Items in LT2ItemList.lua must include  Store = "WoodRUs"       │
-- │  (or whichever key applies) so the module knows which config    │
-- │  to use.                                                        │
-- └─────────────────────────────────────────────────────────────────┘
local StoreConfigs = {
    WoodRUs = {
        NPCName     = "Thom",
        ItemDropCF  = CFrame.new(268.5, 5.2,  67.4),
        PlayerBuyCF = CFrame.new(262.1, 3.2,  64.8),
    },
    FurnitureStore = {
        NPCName     = "Corey",
        ItemDropCF  = CFrame.new(477.2, 5.6, -1721.8),   -- TODO: set real coordinates
        PlayerBuyCF = CFrame.new(481.4, 3.2, -1712.5),   -- TODO: set real coordinates
    },
    CarStore = {
        NPCName     = "Jenny",
        ItemDropCF  = CFrame.new(528, 5.7, -1460),   -- TODO: set real coordinates
        PlayerBuyCF = CFrame.new(524.9, 3.2, -1466.6),   -- TODO: set real coordinates
    },
    ShackShop = {
        NPCName     = "Bob",
        ItemDropCF  = CFrame.new(260.4, 10.4, -2551.3),   -- TODO: set real coordinates
        PlayerBuyCF = CFrame.new(256.7, 8.4, -2546.7),   -- TODO: set real coordinates
    },
    FineArt = {
        NPCName     = "Timothy",
        ItemDropCF  = CFrame.new(5238.2, -164.0, 740.3),   -- TODO: set real coordinates
        PlayerBuyCF = CFrame.new(5232.4, -166.0, 737.3),   -- TODO: set real coordinates
    },
    LogicStore = {
        NPCName     = "Lincoln",
        ItemDropCF  = CFrame.new(4595.5, 9.4, -785.1),   -- TODO: set real coordinates
        PlayerBuyCF = CFrame.new(4598.4, 7.0, -778.4),   -- TODO: set real coordinates
    },
}

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
            warn("[ShopModule] GetFunds RemoteFunction not found anywhere in ReplicatedStorage.")
            return nil
        end
        print("[ShopModule] Found GetFunds at: " .. GetFundsRemote:GetFullName())
    end

    local ok, result = pcall(function()
        return GetFundsRemote:InvokeServer()
    end)
    if ok and type(result) == "number" then
        return result
    end
    warn("[ShopModule] GetFunds remote call failed: " .. tostring(result))
    return nil
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      NPC ID FETCHING                            │
-- └─────────────────────────────────────────────────────────────────┘
local NPCIDs     = {}
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

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   NPC ARG — BY STORE NAME                       │
-- │                                                                  │
-- │  Looks up the store config directly instead of finding the      │
-- │  nearest counter. Guarantees the right NPC is always used.      │
-- └─────────────────────────────────────────────────────────────────┘
local function GetNPCArgForStore(storeName)
    local config = StoreConfigs[storeName]
    if not config then
        warn("[ShopModule] No StoreConfig found for store: " .. tostring(storeName))
        return nil
    end

    local npcName = config.NPCName
    local npc     = NPCs[npcName]
    if not npc then
        warn("[ShopModule] NPC '" .. tostring(npcName) .. "' not found in NPCs table.")
        return nil
    end

    if not npc:FindFirstChild("Dialog") then
        Instance.new("Dialog", npc)
    end

    return {
        ID        = NPCIDs[npcName],
        Character = npc,
        Name      = npcName,
        Dialog    = npc.Dialog,
    }
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │               SAFE INVOKE — HARD TIMEOUT PER CALL               │
-- └─────────────────────────────────────────────────────────────────┘
local INVOKE_TIMEOUT = 4

local function SafeInvoke(npcArg, action)
    local co   = coroutine.running()
    local done = false

    local fireThread = task.spawn(function()
        pcall(function()
            Remote:InvokeServer(npcArg, action)
        end)
        if not done then
            done = true
            task.spawn(co)
        end
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
        Notify("❌ Funds Error", "Could not retrieve your balance. Try again.", 4)
        return
    end

    if funds < POE_PRICE then
        Notify(
            "❌ Insufficient Funds",
            ("Need $%s  •  Have $%s  •  Short $%s"):format(
                tostring(POE_PRICE), tostring(funds), tostring(POE_PRICE - funds)
            ),
            5
        )
        return
    end

    FetchNPCIDs()

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        Notify("❌ Error", "No character found.", 3)
        return
    end

    local returnCF = root.CFrame
    root.CFrame = POE_TP_CF
    task.wait(0.15)

    Notify("Shop", "Teleported — initiating Power of Ease purchase…", 4)

    -- POE has no specific store config, so fall back to nearest-counter logic
    local bestDist = math.huge
    local bestNPC, bestName

    for name, npc in pairs(NPCs) do
        local store = npc.Parent
        if store and store:FindFirstChild("Counter") then
            local dist = (store.Counter.CFrame.p - root.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestNPC  = npc
                bestName = name
            end
        end
    end

    if not bestNPC then
        Notify("❌ No NPC", "Could not find an NPC at the Power of Ease location.", 4)
        root.CFrame = returnCF
        return
    end

    if not bestNPC:FindFirstChild("Dialog") then
        Instance.new("Dialog", bestNPC)
    end

    local npcArg = {
        ID        = NPCIDs[bestName],
        Character = bestNPC,
        Name      = bestName,
        Dialog    = bestNPC.Dialog,
    }

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
            Notify("⏳ Purchasing…", ("Fired %d times — waiting for deduction…"):format(fireCount), 3)
        end

        task.wait(POE_INTERVAL)
    end

    if purchased then
        Notify("✅ Power of Ease!", ("Purchased after %d fires. Returning…"):format(fireCount), 5)
    else
        Notify("❌ Timeout", ("Purchase not confirmed after %d fires."):format(fireCount), 5)
    end

    task.wait(0.1)
    local returnChar = Player.Character
    local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
    if returnRoot then returnRoot.CFrame = returnCF end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       PURCHASE SEQUENCE                         │
-- └─────────────────────────────────────────────────────────────────┘
local SPAM_TIMEOUT       = 30
local SPAM_NOTIFY_FREQ   = 50
local INVOKE_GAP         = 0.05
local CYCLE_GAP          = 0.12
local FAIL_BACKOFF_AFTER = 8
local FAIL_BACKOFF_WAIT  = 0.6

local function IsSuccessParent(parent)
    if not parent then return false end
    if parent.Name == "PlayerModels"  then return true end
    if parent == Player.Backpack      then return true end
    if parent == Player.Character     then return true end
    local current = parent
    while current do
        if current.Name == "PlayerModels" then return true end
        current = current.Parent
    end
    return false
end

local function CheckItemState(mainPart)
    if not mainPart then return "gone" end
    local parent = mainPart.Parent
    if IsSuccessParent(parent) then return "success" end
    if parent == nil then
        task.wait(0.12)
        local newParent = mainPart.Parent
        if IsSuccessParent(newParent) then return "success" end
        if newParent == nil             then return "gone"    end
    end
    return "pending"
end

local function FlushDialog(npcArg, count)
    count = count or 2
    for _ = 1, count do
        SafeInvoke(npcArg, "EndChat")
        task.wait(0.05)
    end
end

local function SpamPurchase(mainPart, npcArg, itemName)
    local fireCount  = 0
    local failStreak = 0
    local deadline   = tick() + SPAM_TIMEOUT

    FlushDialog(npcArg, 2)
    task.wait(CYCLE_GAP)

    while tick() < deadline do
        SafeInvoke(npcArg, "Initiate")
        task.wait(INVOKE_GAP)

        local preState = CheckItemState(mainPart)
        if preState == "success" then
            FlushDialog(npcArg, 1)
            Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
            return true
        elseif preState == "gone" then
            FlushDialog(npcArg, 1)
            Notify("⚠️ Item Gone", ("'%s' disappeared before confirmation."):format(itemName), 4)
            return false
        end

        SafeInvoke(npcArg, "ConfirmPurchase")
        fireCount += 1

        local postState = CheckItemState(mainPart)
        SafeInvoke(npcArg, "EndChat")

        if postState == "success" then
            Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
            return true
        elseif postState == "gone" then
            Notify("⚠️ Item Gone", ("'%s' disappeared during purchase."):format(itemName), 4)
            return false
        end

        failStreak += 1
        if failStreak >= FAIL_BACKOFF_AFTER then
            FlushDialog(npcArg, 3)
            task.wait(FAIL_BACKOFF_WAIT)
            failStreak = 0
        else
            task.wait(CYCLE_GAP)
        end

        if fireCount % SPAM_NOTIFY_FREQ == 0 then
            Notify("⏳ Buying…", ("Fired %d times for '%s'"):format(fireCount, itemName), 3)
        end
    end

    FlushDialog(npcArg, 2)
    Notify("❌ Timeout", ("Purchase of '%s' timed out after %d fires."):format(itemName, fireCount), 5)
    return false
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      PURCHASE PART                              │
-- │                                                                 │
-- │  Now accepts the full item table so it can read item.Store      │
-- │  and pull the correct ItemDropCF / PlayerBuyCF / NPC.           │
-- └─────────────────────────────────────────────────────────────────┘
local function PurchasePart(mainPart, item, originalCF)
    local storeName = item.Store
    local config    = StoreConfigs[storeName]

    if not config then
        warn("[ShopModule] No StoreConfig for store '" .. tostring(storeName) .. "' — skipping purchase.")
        return false
    end

    local itemDropCF  = config.ItemDropCF
    local playerBuyCF = config.PlayerBuyCF
    local itemName    = item.Name

    local success = _LOT.TeleportMany({ { target = mainPart, goalCF = itemDropCF } })

    if _LOT.IsBusy() then
        Notify("Shop", "Waiting for TP to settle…", 2)
        success = _LOT.WaitForBatch()
    end

    if not success then
        Notify("❌ TP Failed", ("Teleport cancelled for '%s'."):format(itemName), 4)
        return false
    end

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        Notify("❌ Error", "No character found.", 3)
        return false
    end

    originalCF = originalCF or root.CFrame
    root.CFrame = playerBuyCF
    task.wait(0.1)

    local npcArg = GetNPCArgForStore(storeName)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", ("Could not find NPC for store '%s'."):format(tostring(storeName)), 4)
        return false
    end

    local purchased = SpamPurchase(mainPart, npcArg, itemName)

    if purchased then
        task.wait(0.05)
        if mainPart and mainPart.Parent then
            _LOT.TeleportMany({ { target = mainPart, goalCF = originalCF } })
        end
        local returnChar = Player.Character
        local returnRoot = returnChar and returnChar:FindFirstChild("HumanoidRootPart")
        if returnRoot then
            returnRoot.CFrame = originalCF * CFrame.new(0, 0, 3)
        end
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

    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or not result or result:find("404: Not Found") then
        warn("[ShopModule] Could not fetch LT2ItemList.lua — " .. tostring(result))
        return nil
    end

    local fn, parseErr = loadstring(result)
    if not fn then
        warn("[ShopModule] LT2ItemList.lua has a syntax error — " .. tostring(parseErr))
        return nil
    end

    local ok2, items = pcall(fn)
    if not ok2 or type(items) ~= "table" then
        warn("[ShopModule] LT2ItemList.lua must return a table — " .. tostring(items))
        return nil
    end

    print(("[ShopModule] Loaded %d item(s) from LT2ItemList.lua"):format(#items))
    return items
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                   SHOPITEMS ↔ STORE MATCHER                     │
-- │                                                                  │
-- │  workspace.Stores has multiple children named "ShopItems".      │
-- │  We identify which one belongs to a given store by finding      │
-- │  the ShopItems container whose parts sit closest to that        │
-- │  store's Counter (same landmark used by the NPC distance code). │
-- │                                                                  │
-- │  Results are cached so the scan only runs once per store.       │
-- └─────────────────────────────────────────────────────────────────┘
local ShopItemsCache = {}  -- storeName → ShopItems instance (or false if not found)

local function GetShopItemsForStore(storeName)
    -- Return cached result (false means "already searched, not found")
    if ShopItemsCache[storeName] ~= nil then
        return ShopItemsCache[storeName] or nil
    end

    local config = StoreConfigs[storeName]
    if not config then
        ShopItemsCache[storeName] = false
        return nil
    end

    -- Anchor point: the store's Counter position (same as NPC proximity logic)
    local npc   = NPCs[config.NPCName]
    local store = npc and npc.Parent
    local anchor

    if store and store:FindFirstChild("Counter") then
        anchor = store.Counter.CFrame.p
    elseif store and store:IsA("Model") then
        local ok, piv = pcall(function() return store:GetPivot().Position end)
        if ok then anchor = piv end
    end

    if not anchor then
        warn("[ShopModule] Could not determine position for store: " .. storeName)
        ShopItemsCache[storeName] = false
        return nil
    end

    -- Scan all ShopItems containers and pick the closest one
    local stores = workspace:FindFirstChild("Stores")
    if not stores then
        warn("[ShopModule] workspace.Stores not found.")
        ShopItemsCache[storeName] = false
        return nil
    end

    local bestContainer, bestDist = nil, math.huge

    for _, child in ipairs(stores:GetChildren()) do
        if child.Name ~= "ShopItems" then continue end

        -- Sample the first BasePart we find inside to get a position
        local samplePos
        for _, desc in ipairs(child:GetDescendants()) do
            if desc:IsA("BasePart") then
                samplePos = desc.Position
                break
            end
        end

        if samplePos then
            local dist = (samplePos - anchor).Magnitude
            if dist < bestDist then
                bestDist      = dist
                bestContainer = child
            end
        end
    end

    if bestContainer then
        print(("[ShopModule] Matched ShopItems for '%s' → %s (dist %.1f)"):format(
            storeName, bestContainer:GetFullName(), bestDist))
    else
        warn("[ShopModule] No ShopItems container found near store: " .. storeName)
    end

    ShopItemsCache[storeName] = bestContainer or false
    return bestContainer
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                      WORLD PATH RESOLVER                        │
-- │                                                                  │
-- │  Searches only the ShopItems container that belongs to the      │
-- │  item's linked store. Falls back to all containers if the       │
-- │  item has no Store field or the match fails.                    │
-- └─────────────────────────────────────────────────────────────────┘
local function ResolveItemParts(item, limit)
    local stores = workspace:FindFirstChild("Stores")
    if not stores then
        warn("[ShopModule] workspace.Stores not found.")
        return {}
    end

    local results = {}

    local function searchContainer(shopItems)
        for _, box in ipairs(shopItems:GetChildren()) do
            if #results >= limit then break end
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

    local storeName = item.Store
    if storeName then
        local targetContainer = GetShopItemsForStore(storeName)
        if targetContainer then
            searchContainer(targetContainer)
            return results
        end
        -- If the match failed, fall through to the broad scan below
        warn("[ShopModule] Falling back to full scan for item: " .. tostring(item.Name))
    end

    -- Broad fallback: search every ShopItems container (original behaviour)
    for _, child in ipairs(stores:GetChildren()) do
        if #results >= limit then break end
        if child.Name ~= "ShopItems" then continue end
        searchContainer(child)
    end

    return results
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                    RESTOCK-AWARE BUY LOOP                       │
-- └─────────────────────────────────────────────────────────────────┘
local RESTOCK_POLL_RATE    = 0.5
local RESTOCK_NOTIFY_EVERY = 10
local RESTOCK_TIMEOUT      = 120

local _isBuying = false

local function RunBuyLoop(item, totalQty, pressedCF, onDone)
    _isBuying = true

    FetchNPCIDs()

    local bought       = 0
    local failed       = 0
    local itemName     = item.Name
    local restockTimer = 0

    Notify("Shop", ("Starting order: %d × %s"):format(totalQty, itemName), 4)

    while bought < totalQty and _isBuying do
        local stillNeed = totalQty - bought
        local parts     = ResolveItemParts(item, stillNeed)

        if #parts == 0 then
            if restockTimer == 0 then
                Notify(
                    "⏳ Waiting for restock…",
                    ("Bought %d / %d × %s — shelf is empty."):format(bought, totalQty, itemName),
                    RESTOCK_NOTIFY_EVERY
                )
            end

            task.wait(RESTOCK_POLL_RATE)
            restockTimer += RESTOCK_POLL_RATE

            if restockTimer % RESTOCK_NOTIFY_EVERY < RESTOCK_POLL_RATE then
                Notify(
                    "⏳ Still waiting for restock…",
                    ("Bought %d / %d × %s  •  %ds elapsed"):format(
                        bought, totalQty, itemName, math.floor(restockTimer)
                    ),
                    RESTOCK_NOTIFY_EVERY
                )
            end

            if restockTimer >= RESTOCK_TIMEOUT then
                Notify(
                    "❌ Restock Timeout",
                    ("No new '%s' appeared after %ds.\nStopping at %d / %d."):format(
                        itemName, RESTOCK_TIMEOUT, bought, totalQty
                    ),
                    6
                )
                break
            end

            continue
        end

        if restockTimer > 0 then
            Notify(
                "🛒 Restock detected!",
                ("%d × '%s' appeared — resuming purchase…"):format(#parts, itemName),
                3
            )
            restockTimer = 0
        end

        for _, mainPart in ipairs(parts) do
            if not _isBuying      then break end
            if bought >= totalQty then break end

            if not mainPart or not mainPart.Parent then
                failed += 1
                continue
            end

            if _LOT.IsBusy() then _LOT.WaitForBatch() end

            -- Pass the full item table so PurchasePart can read item.Store
            local ok = PurchasePart(mainPart, item, pressedCF)
            if ok then
                bought += 1
                if bought % 5 == 0 and bought < totalQty then
                    Notify(
                        "🛒 Progress",
                        ("Bought %d / %d × %s"):format(bought, totalQty, itemName),
                        2
                    )
                end
            else
                failed += 1
            end
        end
    end

    _isBuying = false

    local reason = (bought >= totalQty) and "✅ Order Complete" or "🛑 Order Stopped"
    Notify(
        reason,
        ("Bought %d / %d × %s.%s"):format(
            bought, totalQty, itemName,
            failed > 0 and ("\n%d failed."):format(failed) or ""
        ),
        6
    )

    if onDone then onDone() end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                         MODULE INIT                             │
-- └─────────────────────────────────────────────────────────────────┘
function ShopModule.Init(Tab, lot, GetImageFunc)
    if lot ~= nil then _LOT = lot end

    local GetImage = GetImageFunc
                  or getgenv().GetImage
                  or function() return nil end

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
        if not SelectedItem or not PurchaseBtn then return end
        PurchaseBtn:SetText(("$%d"):format(SelectedItem.Price * Quantity))
    end

    local function SetBuyingState(buying)
        if not PurchaseBtn then return end
        if buying then
            PurchaseBtn:SetText("⛔ Stop")
        else
            UpdateDisplay()
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
            if item.Name == name then
                SelectedItem = item
                break
            end
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

        if _isBuying then
            _isBuying = false
            Notify("🛑 Cancelling…", "Stopping after the current item finishes.", 3)
            return
        end

        if not SelectedItem then return end

        if _LOT == nil then
            warn("[ShopModule] LOT is not set. Call ShopModule.SetLOT(lot) or pass it to Init.")
            return
        end

        if not SelectedItem.Store then
            Notify("❌ Config Error", ("Item '%s' has no Store field set."):format(SelectedItem.Name), 5)
            warn("[ShopModule] Item '" .. SelectedItem.Name .. "' is missing the Store field in LT2ItemList.lua")
            return
        end

        if not StoreConfigs[SelectedItem.Store] then
            Notify("❌ Config Error", ("Unknown store '%s' for item '%s'."):format(SelectedItem.Store, SelectedItem.Name), 5)
            return
        end

        if _LOT.IsBusy() then
            Notify("Shop", "A teleport is already running — please wait.", 3)
            return
        end

        local funds = FetchFunds()
        if funds == nil then
            Notify("❌ Funds Error", "Could not retrieve your balance. Try again.", 4)
            return
        end

        if funds < SelectedItem.Price then
            Notify(
                "❌ Insufficient Funds",
                ("Need at least $%d  •  You have $%d"):format(SelectedItem.Price, funds),
                5
            )
            return
        end

        local totalCost = SelectedItem.Price * Quantity
        local targetQty = Quantity
        if funds < totalCost then
            targetQty = math.floor(funds / SelectedItem.Price)
            Notify(
                "⚠️ Partial Order",
                ("Can only afford %d / %d × %s ($%d available, $%d needed).\nBuying %d."):format(
                    targetQty, Quantity, SelectedItem.Name,
                    funds, totalCost, targetQty
                ),
                6
            )
        end

        local char      = Player.Character
        local root      = char and char:FindFirstChild("HumanoidRootPart")
        local pressedCF = root and root.CFrame

        SetBuyingState(true)

        task.spawn(function()
            RunBuyLoop(SelectedItem, targetQty, pressedCF, function()
                SetBuyingState(false)
            end)
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

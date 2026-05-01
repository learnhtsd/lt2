-- [[ SHOP MODULE ]] --
-- Designed for Dynxe LT2 UI Engine

local ShopModule = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local Player            = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                     PURCHASE COORDINATES                        │
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
-- │               SAFE INVOKE — HARD TIMEOUT PER CALL               │
-- │                                                                  │
-- │  Each InvokeServer gets its own hard timeout. The client thread  │
-- │  is resumed so the caller always makes progress, even if the    │
-- │  server never responds. The server still processes the invoke;  │
-- │  only the client stops waiting for the reply.                   │
-- └─────────────────────────────────────────────────────────────────┘
local INVOKE_TIMEOUT = 4  -- seconds; raised from 3 to give server more room

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

    local npcArg = GetNearestNPCArg(root)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", "Could not find an NPC at the Power of Ease location.", 4)
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
    if returnRoot then
        returnRoot.CFrame = returnCF
    end
end

-- ┌─────────────────────────────────────────────────────────────────┐
-- │                       PURCHASE SEQUENCE                         │
-- │                                                                  │
-- │  WHY THE ORIGINAL BROKE                                         │
-- │  ─────────────────────                                          │
-- │  The old code ran the fire loop in a background thread and      │
-- │  checked for success on the main thread simultaneously.         │
-- │  SafeInvoke would time-out mid-cycle (e.g. after Initiate)      │
-- │  and immediately fire ConfirmPurchase before the server had      │
-- │  finished opening the dialog — corrupting its state machine.    │
-- │  The server then rejected ConfirmPurchase with a "not enough    │
-- │  money" error even when the player had sufficient funds.        │
-- │                                                                  │
-- │  THE FIX                                                        │
-- │  ────────                                                        │
-- │  Everything is now sequential in one thread:                    │
-- │    1. Initiate   (wait for server ack or timeout)               │
-- │    2. ConfirmPurchase (wait for server ack or timeout)          │
-- │    3. Check success                                             │
-- │    4. EndChat    — ALWAYS fires to reset server dialog state    │
-- │    5. Short gap before the next cycle                           │
-- │                                                                  │
-- │  If repeated cycles fail the module backs off for longer to     │
-- │  give the server time to fully close any stuck dialog.          │
-- └─────────────────────────────────────────────────────────────────┘

-- Timing constants (tune if the game's server tick changes)
local SPAM_TIMEOUT       = 30    -- total seconds before giving up
local SPAM_NOTIFY_FREQ   = 50    -- notify every N fires
local INVOKE_GAP         = 0.05  -- pause between Initiate and ConfirmPurchase
local CYCLE_GAP          = 0.12  -- pause after EndChat before next Initiate
local FAIL_BACKOFF_AFTER = 8     -- consecutive failures before long pause
local FAIL_BACKOFF_WAIT  = 0.6   -- long pause duration (lets server clear stuck state)

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

-- Checks mainPart's parent and handles the brief nil-transition window
-- that sometimes occurs right as the server hands the item to the player.
-- Returns: "success" | "gone" | "pending"
local function CheckItemState(mainPart)
    if not mainPart then return "gone" end
    local parent = mainPart.Parent

    if IsSuccessParent(parent) then return "success" end

    if parent == nil then
        -- nil can be a one-frame blip during handoff — give it a moment
        task.wait(0.12)
        local newParent = mainPart.Parent
        if IsSuccessParent(newParent) then return "success" end
        if newParent == nil             then return "gone"    end
    end

    return "pending"
end

-- Fires EndChat up to `count` times with a small gap to flush any
-- stuck server-side dialog state before starting a fresh attempt.
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

    -- Clear any leftover dialog state from a previous run
    FlushDialog(npcArg, 2)
    task.wait(CYCLE_GAP)

    while tick() < deadline do

        -- ── Step 1: Open dialog ───────────────────────────────────
        SafeInvoke(npcArg, "Initiate")
        task.wait(INVOKE_GAP)  -- let server finish opening dialog before confirm

        -- Pre-confirm check: item might already be moving (very fast server)
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

        -- ── Step 2: Confirm purchase ──────────────────────────────
        SafeInvoke(npcArg, "ConfirmPurchase")
        fireCount += 1

        -- ── Step 3: Check success (before EndChat — item may have moved) ──
        local postState = CheckItemState(mainPart)

        -- ── Step 4: End chat — ALWAYS, to keep server state clean ─
        SafeInvoke(npcArg, "EndChat")

        if postState == "success" then
            Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
            return true
        elseif postState == "gone" then
            Notify("⚠️ Item Gone", ("'%s' disappeared during purchase."):format(itemName), 4)
            return false
        end

        -- ── Step 5: Failure bookkeeping & inter-cycle gap ─────────
        failStreak += 1

        if failStreak >= FAIL_BACKOFF_AFTER then
            -- Server dialog is likely stuck. Flush harder and pause longer.
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

    FlushDialog(npcArg, 2)  -- leave dialog state clean even on timeout
    Notify("❌ Timeout", ("Purchase of '%s' timed out after %d fires."):format(itemName, fireCount), 5)
    return false
end

local function PurchasePart(mainPart, itemName, originalCF)
    local success = _LOT.TeleportMany({ { target = mainPart, goalCF = ITEM_DROP_CF } })

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

    root.CFrame = PLAYER_BUY_CF
    task.wait(0.1)

    local npcArg = GetNearestNPCArg(mainPart)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", ("Could not find NPC for '%s'."):format(itemName), 4)
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
        if not SelectedItem then return end
        local newText = string.format("$%d", SelectedItem.Price * Quantity)
        if PurchaseBtn then
            PurchaseBtn:SetText(newText)
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
        if not SelectedItem then return end

        if _LOT == nil then
            warn("[ShopModule] LOT is not set. Call ShopModule.SetLOT(lot) or pass it to Init.")
            return
        end

        if _LOT.IsBusy() then
            Notify("Shop", "A teleport is already running — please wait.", 3)
            return
        end

        local totalCost = SelectedItem.Price * Quantity
        local funds     = FetchFunds()

        if funds == nil then
            Notify("❌ Funds Error", "Could not retrieve your balance. Try again.", 4)
            return
        end

        if funds < totalCost then
            Notify(
                "❌ Insufficient Funds",
                ("Need $%d  •  You have $%d  •  Short $%d"):format(
                    totalCost, funds, totalCost - funds
                ),
                5
            )
            return
        end

        local parts = ResolveItemParts(SelectedItem, Quantity)
        if #parts == 0 then return end

        local char      = Player.Character
        local root      = char and char:FindFirstChild("HumanoidRootPart")
        local pressedCF = root and root.CFrame

        task.spawn(function()
            FetchNPCIDs()

            local bought    = 0
            local failed    = 0
            local itemName  = SelectedItem.Name
            local liveFunds = FetchFunds() or funds

            Notify(
                "Shop",
                ("Purchasing %d × %s  ($%d)\nBalance: $%d"):format(
                    #parts, itemName, totalCost, liveFunds
                ),
                4
            )

            for _, mainPart in ipairs(parts) do
                if not mainPart or not mainPart.Parent then
                    failed += 1
                    continue
                end

                if _LOT.IsBusy() then
                    _LOT.WaitForBatch()
                end

                local ok = PurchasePart(mainPart, itemName, pressedCF)
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

    UpdateDisplay()
    ShopModule.UpdateDisplay = UpdateDisplay

    Tab:CreateSection("Special")

    Tab:CreateAction("Buy Power of Ease ($10,009,000)", "Buy", function()
        task.spawn(PurchasePowerOfEase)
    end, false)
end

return ShopModule

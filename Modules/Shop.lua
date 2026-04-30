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
-- │                     POWER OF EASE PURCHASE                      │
-- └─────────────────────────────────────────────────────────────────┘
local POE_PRICE    = 10009000
local POE_TP_CF    = CFrame.new(1059.4, 17.2, 1130.3)
local POE_TIMEOUT  = 60  -- seconds to wait for money deduction
local POE_INTERVAL = 0.2 -- polling interval

local function PurchasePowerOfEase()
    -- 1. Check funds
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

    -- 2. Resolve the NPC/remote args (reuse existing NPC fetch infrastructure)
    FetchNPCIDs()

    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        Notify("❌ Error", "No character found.", 3)
        return
    end

    local returnCF = root.CFrame  -- save position before TP

    -- 3. Teleport player to the Power of Ease location
    root.CFrame = POE_TP_CF
    task.wait(0.15)

    Notify("Shop", "Teleported — initiating Power of Ease purchase…", 4)

    -- 4. Find the nearest NPC at the new position
    local npcArg = GetNearestNPCArg(root)
    if not npcArg or not npcArg.ID then
        Notify("❌ No NPC", "Could not find an NPC at the Power of Ease location.", 4)
        root.CFrame = returnCF
        return
    end

    -- 5. Fire purchase remote until player's balance drops (verification)
    local fireCount = 0
    local deadline  = tick() + POE_TIMEOUT
    local purchased = false

    while tick() < deadline do
        pcall(function()
            Remote:InvokeServer(npcArg, "Initiate")
            Remote:InvokeServer(npcArg, "ConfirmPurchase")
            Remote:InvokeServer(npcArg, "EndChat")
        end)

        fireCount += 1

        -- Poll balance every fire to detect successful deduction
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

    -- 6. Report result and TP back
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
-- └─────────────────────────────────────────────────────────────────┘
local SPAM_INTERVAL    = 0.1
local SPAM_TIMEOUT     = 30
local SPAM_NOTIFY_FREQ = 50

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

local function SpamPurchase(mainPart, npcArg, itemName)
    local fireCount = 0
    local deadline  = tick() + SPAM_TIMEOUT

    Notify("Shop", ("Buying '%s' from %s…"):format(itemName, npcArg.Name), 4)

    while tick() < deadline do
        local parent = mainPart and mainPart.Parent

        if IsSuccessParent(parent) then
            Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
            return true
        end

        if parent == nil then
            task.wait()
            local newParent = mainPart and mainPart.Parent
            if IsSuccessParent(newParent) then
                Notify("✅ Purchased!", ("'%s' bought after %d fires."):format(itemName, fireCount), 5)
                return true
            end
            if newParent == nil then
                Notify("⚠️ Item Gone", ("'%s' was removed before purchase completed."):format(itemName), 4)
                return false
            end
        end

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
-- │                                                                 │
-- │  Fetches LT2ItemList.lua from the root of your GitHub repo     │
-- │  and runs it. The file must return a table of item entries,    │
-- │  for example:                                                   │
-- │                                                                 │
-- │  return {                                                       │
-- │      {                                                          │
-- │          Name        = "Basic Hatchet",                        │
-- │          Image       = "BasicHatchet.png",                     │
-- │          Price       = 12,                                      │
-- │          BoxItemName = "BasicHatchet",                         │
-- │      },                                                         │
-- │      {                                                          │
-- │          Name        = "Large Axe",                            │
-- │          Image       = "LargeAxe.png",                         │
-- │          Price       = 800,                                     │
-- │          BoxItemName = "LargeAxe",                             │
-- │      },                                                         │
-- │  }                                                              │
-- │                                                                 │
-- │  User / Repo / Branch are read from getgenv() so they always   │
-- │  stay in sync with whatever the main script has set.           │
-- └─────────────────────────────────────────────────────────────────┘
local function LoadItemList()
    local genv   = getgenv()
    local user   = genv.User   or "learnhtsd"
    local repo   = genv.Repo   or "lt2"
    local branch = genv.Branch or "main"

    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/LT2ItemList.lua?t=%s",
        user, repo, branch, tick()  -- cache-bust so edits are picked up immediately
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

    -- Fetch the item list from GitHub. If it fails, leave the tab
    -- empty rather than crashing halfway through UI construction.
    local ShopItems = LoadItemList()
    if not ShopItems or #ShopItems == 0 then
        warn("[ShopModule] No items loaded — shop tab will be empty.")
        Tab:CreateSection("Hardware Store")
        return
    end

    local SelectedItem = ShopItems[1]
    local Quantity     = 1

    Tab:CreateSection("Stores")

    local Catalog = Tab:CreateImageSelector("Wood R Us", {
        MultiSelect = false,
        VisibleRows        = 3,
        SlotSize    = UDim2.new(0, 70, 0, 70),
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
        local img = GetImage("", item.Image)
        Catalog:AddSlot(img, item.Name, "$" .. tostring(item.Price))
    end

    Tab:CreateSlider("Quantity", 1, 100, 1, function(val)
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

    ShopModule.UpdateDisplay = function()
        if not SelectedItem then return end
        local newText = string.format("$%d", SelectedItem.Price * Quantity)
        if PurchaseBtn then
            if PurchaseBtn.Set        then PurchaseBtn:Set(newText)
            elseif PurchaseBtn.Update then PurchaseBtn:Update(newText) end
        end
    end

    ShopModule.UpdateDisplay()

    Tab:CreateSection("Special")

    Tab:CreateAction("Buy Power of Ease ($10,009,000)", "Buy", function()
    task.spawn(PurchasePowerOfEase)
end, false)
end

return ShopModule

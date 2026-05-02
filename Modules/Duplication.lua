local Duplication = {}

function Duplication.Init(Tab, Library)
    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer       = Players.LocalPlayer

    -- ===========================
    -- STATE VARIABLES
    -- ===========================
    local env = getgenv and getgenv() or _G

    env.DupeSource = nil
    env.DupeTarget = nil
    env.PM_Connections = env.PM_Connections or {}

    env.DupeItems = {
        Furniture   = false,
        Structures  = false,
        Decorations = false,
        Plants      = false,
        Axes        = false,
    }

    -- ===========================
    -- NOTIFY HELPER
    -- ===========================
    local function Notify(title, body, duration)
        if Library and Library.Notify then
            Library:Notify(title, body, duration or 4)
        else
            warn(("[Duplication] %s — %s"):format(title, body))
        end
    end

    -- ===========================
    -- HELPERS
    -- ===========================
    local function GetPlayerNames()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(names, p.Name)
        end
        return names
    end

    -- ===========================
    -- AXE DUPE LOGIC
    -- ===========================
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")

    local axeDupeRunning = false
    local axeDupeCount   = 0

    local function ReloadCurrentSlot()
        local slotObj = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if not slotObj or slotObj.Value == -1 then
            warn("[Duplication] No save slot is currently loaded.")
            return false
        end
        local slot = slotObj.Value

        if not loadSaveRequests then
            warn("[Duplication] LoadSaveRequests folder not found.")
            return false
        end

        local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")
        local ClientMayLoad     = loadSaveRequests:FindFirstChild("ClientMayLoad")

        if not RequestLoadRemote or not ClientMayLoad then
            warn("[Duplication] Necessary load remotes missing.")
            return false
        end

        local canLoad, result = pcall(function()
            return ClientMayLoad:InvokeServer(slot)
        end)
        if not canLoad or result ~= true then
            warn("[Duplication] Server denied load request (cooldown?).")
            return false
        end

        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp      = char and char:FindFirstChild("HumanoidRootPart")

        if not humanoid or humanoid.Health <= 0 then
            warn("[Duplication] Character not found or already dead.")
            return false
        end

        -- Drop below baseplate to die
        hrp.CFrame = CFrame.new(hrp.Position.X, -100, hrp.Position.Z)
        humanoid.Died:Wait()

        local ok, err = pcall(function()
            RequestLoadRemote:InvokeServer(slot)
        end)

        if not ok then
            warn("[Duplication] RequestLoad failed: " .. tostring(err))
            return false
        end

        local newChar = LocalPlayer.CharacterAdded:Wait()
        newChar:WaitForChild("HumanoidRootPart", 10)

        return true
    end

    local axeDupeBtn

    local function RunAxeDupe()
        if axeDupeRunning then
            axeDupeRunning = false
            return
        end

        -- Find the axe in the player's backpack or character
        local function FindAxe()
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local char     = LocalPlayer.Character

            local function searchIn(parent)
                if not parent then return nil end
                for _, item in ipairs(parent:GetChildren()) do
                    -- Axes in LT2 typically have "Axe" or "Hatchet" in their name
                    local name = item.Name:lower()
                    if name:find("axe") or name:find("hatchet") then
                        return item
                    end
                end
                return nil
            end

            return searchIn(backpack) or searchIn(char)
        end

        local axe = FindAxe()
        if not axe then
            Notify("Axe Dupe", "No axe found in backpack or character.", 4)
            return
        end

        axeDupeRunning = true
        axeDupeCount   = 0

        if axeDupeBtn then axeDupeBtn:SetText("Stop") end
        Notify("Axe Dupe", "Starting — equip and drop your axe, then let the script cycle.", 5)

        while axeDupeRunning do
            -- Equip the axe so it becomes a tool in the world
            local char      = LocalPlayer.Character
            local humanoid  = char and char:FindFirstChildOfClass("Humanoid")

            axe = FindAxe()
            if not axe then
                Notify("Axe Dupe", "Axe not found — stopping.", 4)
                break
            end

            -- Equip then drop (unequip while it's a held tool drops it to workspace)
            if humanoid then
                humanoid:EquipTool(axe)
                task.wait(0.3)
                -- Dropping: parent the tool to workspace briefly so it becomes a loose object
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    axe.Parent = workspace
                    local handle = axe:FindFirstChild("Handle")
                    if handle then
                        handle.CFrame = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 3)
                    end
                end
                task.wait(0.2)
            end

            -- Reload slot — this gives back the axe via save restore
            local success = ReloadCurrentSlot()
            if not success then
                axeDupeRunning = false
                break
            end

            axeDupeCount += 1
            Notify("Axe Dupe", ("Cycle %d complete."):format(axeDupeCount), 2)

            -- Small cooldown between cycles to respect server rate limits
            task.wait(1.5)
        end

        axeDupeRunning = false
        if axeDupeBtn then axeDupeBtn:SetText("Start") end
        Notify("Axe Dupe", ("Stopped after %d cycle(s)."):format(axeDupeCount), 4)
    end

    -- ===========================
    -- UI SECTIONS
    -- ===========================
    local Notice = Tab:CreateInfoBox()
    Notice:AddText("⚠ Tab Is Under Development", { Bold = true, Size = 14 })
    Notice:AddDivider()
    Notice:AddText(
        "Some features below may not fully work yet.",
        { Size = 12, Opacity = 0.80, Italic = true, Wrap = true }
    )

    -- ───────────────────────────
    -- BASE DUPLICATION (existing)
    -- ───────────────────────────
    Tab:CreateSection("BASE DUPLICATION")

    local SourceDropdown = Tab:CreateDropdown("Base To Duplicate:", GetPlayerNames(), "Select Owner", function(selected)
        env.DupeSource = selected
    end)
    local TargetDropdown = Tab:CreateDropdown("Base To Drop", GetPlayerNames(), "Select Target", function(selected)
        env.DupeTarget = selected
    end)

    local function RefreshLists()
        local names = GetPlayerNames()
        if SourceDropdown.Refresh then
            SourceDropdown:Refresh(names)
            TargetDropdown:Refresh(names)
        end
    end

    table.insert(env.PM_Connections, Players.PlayerAdded:Connect(RefreshLists))
    table.insert(env.PM_Connections, Players.PlayerRemoving:Connect(RefreshLists))

    local isProcessing = false
    local StartButton = Tab:CreateAction("Duplicate", "Start", function()
        if isProcessing then return end
        if not env.DupeSource or not env.DupeTarget then
            warn("[Duplication] Please select a Source and Target first.")
            return
        end
        isProcessing = true
        StartButton:SetText("Processing...")
        print("Executing Dupe from", env.DupeSource, "to", env.DupeTarget)
        task.delay(5, function()
            isProcessing = false
            StartButton:SetText("Start Duplication")
            print("Duplication sequence finished.")
        end)
    end)

    -- ───────────────────────────
    -- OBJECTS TO DUPLICATE
    -- ───────────────────────────
    Tab:CreateSection("OBJECTS TO DUPLICATE")

    Tab:CreateToggle("Structures & Blueprints", false, function(s) env.DupeItems.Structures  = s end)
    Tab:CreateToggle("Furniture",               false, function(s) env.DupeItems.Furniture   = s end)
    Tab:CreateToggle("Wires",                   false, function(s) env.DupeItems.Decorations = s end)
    Tab:CreateToggle("Gifts",                   false, function(s) env.DupeItems.Decorations = s end)
    Tab:CreateToggle("Planks/Wood",             false, function(s) env.DupeItems.Decorations = s end)

    -- ───────────────────────────
    -- AXE DUPLICATION
    -- ───────────────────────────
    Tab:CreateSection("AXE DUPLICATION")

    Tab:CreateInfoBox():AddText(
        "Equip your axe before starting. Each cycle drops the axe and reloads " ..
        "your save slot so the axe reappears in your inventory while the " ..
        "dropped copy remains in the world.",
        { Size = 12, Opacity = 0.80, Italic = true, Wrap = true }
    )

    axeDupeBtn = Tab:CreateAction("Axe Dupe", "Start", function()
        task.spawn(RunAxeDupe)
    end)
end

return Duplication

-- CombinedModule.lua
local CombinedModule = {}

function CombinedModule.Init(Tab, Library)
    if not Tab then return warn("[CombinedModule] Tab was nil!") end

    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer       = Players.LocalPlayer

    -- ================================================================
    --  SHARED HELPERS
    -- ================================================================
    local function Notify(title, body, duration)
        if Library and Library.Notify then
            Library:Notify(title, body, duration or 4)
        else
            warn(("[CombinedModule] %s — %s"):format(title, body))
        end
    end

    -- ================================================================
    --  RESPAWN & RELOAD
    -- ================================================================
    local loadSaveRequests = ReplicatedStorage:FindFirstChild("LoadSaveRequests")

    local function ReloadCurrentSlot()
        local slotObj = LocalPlayer:FindFirstChild("CurrentSaveSlot")
        if not slotObj or slotObj.Value == -1 then
            Notify("ERROR", "No save slot is currently loaded.", 5)
            return
        end
        local slot = slotObj.Value

        if not loadSaveRequests then
            Notify("ERROR", "LoadSaveRequests folder not found.", 5)
            return
        end

        local RequestLoadRemote = loadSaveRequests:FindFirstChild("RequestLoad")
        local ClientMayLoad     = loadSaveRequests:FindFirstChild("ClientMayLoad")

        if not RequestLoadRemote or not ClientMayLoad then
            Notify("ERROR", "Necessary load remotes missing.", 5)
            return
        end

        -- PRE-CHECK: Can we load right now?
        local success, result = pcall(function()
            return ClientMayLoad:InvokeServer(slot)
        end)
        if not success then
            Notify("ERROR", "ClientMayLoad failed to communicate.", 5)
            return
        elseif result ~= true then
            Notify("DENIED", "Server denied load request (Cooldown?).", 5)
            return
        end

        -- Character Validation
        local char     = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp      = char and char:FindFirstChild("HumanoidRootPart")

        if not humanoid or humanoid.Health <= 0 then
            Notify("ERROR", "Character not found or already dead.", 5)
            return
        end

        Notify("RELOADING", "Permissions valid. Reloading slot " .. slot .. "…", 4)

        -- Drop below baseplate and wait for death
        hrp.CFrame = CFrame.new(hrp.Position.X, -100, hrp.Position.Z)
        humanoid.Died:Wait()

        -- Fire RequestLoad
        local ok, err = pcall(function()
            RequestLoadRemote:InvokeServer(slot)
        end)
        if not ok then
            Notify("FAILED", "RequestLoad failed: " .. tostring(err), 6)
            return
        end

        -- Wait for fresh character then confirm
        local newChar = LocalPlayer.CharacterAdded:Wait()
        newChar:WaitForChild("HumanoidRootPart", 10)
        Notify("SUCCESS", "Slot " .. slot .. " reloaded!", 5)
    end

    Tab:CreateSection("Respawn & Reload")
    Tab:CreateAction("Reload Current Slot", "Reload", function()
        task.spawn(ReloadCurrentSlot)
    end)

    -- ================================================================
    --  DUPLICATION
    -- ================================================================
    local env = getgenv and getgenv() or _G

    env.DupeSource       = nil
    env.DupeTarget       = nil
    env.PM_Connections   = env.PM_Connections or {}
    env.DupeItems = {
        Furniture    = false,
        Structures   = false,
        Decorations  = false,
        Plants       = false,
    }

    local function GetPlayerNames()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            table.insert(names, p.Name)
        end
        return names
    end

    -- Info notice
    local Notice = Tab:CreateInfoBox()
    Notice:AddText("⚠ Tab Is Under Development", { Bold = true, Size = 14 })
    Notice:AddDivider()
    Notice:AddText("The Features Below Will Not Work", {
        Size    = 12,
        Opacity = 0.80,
        Italic  = true,
        Wrap    = true,
    })

    Tab:CreateSection("BASE DUPLICATION")

    local SourceDropdown = Tab:CreateDropdown("Base To Duplicate:", GetPlayerNames(), "Select Owner", function(selected)
        env.DupeSource = selected
    end)
    local TargetDropdown = Tab:CreateDropdown("Base To Drop:", GetPlayerNames(), "Select Target", function(selected)
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
    local StartButton  = Tab:CreateAction("Duplicate", "Start", function()
        if isProcessing then return end
        if not env.DupeSource or not env.DupeTarget then
            warn("Please select a Source and Target first!")
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

    Tab:CreateSection("OBJECTS TO DUPLICATE")
    Tab:CreateToggle("Structures & Blueprints", false, function(s) env.DupeItems.Structures   = s end)
    Tab:CreateToggle("Furniture",               false, function(s) env.DupeItems.Furniture    = s end)
    Tab:CreateToggle("Wires",                   false, function(s) env.DupeItems.Decorations  = s end)
    Tab:CreateToggle("Gifts",                   false, function(s) env.DupeItems.Decorations  = s end)
    Tab:CreateToggle("Axes",                    false, function(s) env.DupeItems.Decorations  = s end)
    Tab:CreateToggle("Planks/Wood",             false, function(s) env.DupeItems.Decorations  = s end)
end

return CombinedModule

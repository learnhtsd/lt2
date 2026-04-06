local WatchDog = {}

function WatchDog.Init(Tab, Library)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    -- ===========================
    -- CONFIG & STATE
    -- ===========================
    local Settings = {
        Enabled = false,
        TeleportThreshold = 50, -- Distance moved in 1 second to flag as TP
        SpeedThreshold = 100,    -- WalkSpeed above this flags as Speeding
        MaxLogs = 8             -- How many lines to show before clearing old ones
    }

    local PlayerData = {} -- Stores last positions/times
    local Logs = {}       -- Stores the strings for the InfoBox

    -- Create the Dynamic InfoBox
    local MonitorBox = Tab:CreateInfoBox("WatchDog Monitor", "System standby... Enable monitoring to begin.")

    -- ===========================
    -- CORE LOGIC
    -- ===========================
    local function UpdateLogs(newText)
        table.insert(Logs, 1, newText) -- Add new log to top
        if #Logs > Settings.MaxLogs then table.remove(Logs) end
        
        local fullLog = table.concat(Logs, "\n")
        MonitorBox:SetDescription(fullLog)
    end

    local function MonitorPlayers()
        if not Settings.Enabled then return end

        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer or not player.Character then continue end
            
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum then
                local currentPos = hrp.Position
                local lastData = PlayerData[player.Name]

                if lastData then
                    local distance = (currentPos - lastData.Pos).Magnitude
                    local deltaTime = tick() - lastData.Time

                    -- 1. Check for Teleporting
                    if distance > Settings.TeleportThreshold and deltaTime < 1.5 then
                        UpdateLogs('<font color="rgb(255, 80, 80)">[TP]</font> ' .. player.Name .. ' moved ' .. math.floor(distance) .. ' studs')
                    end

                    -- 2. Check for Speeding
                    if hum.WalkSpeed > Settings.SpeedThreshold then
                        UpdateLogs('<font color="rgb(255, 200, 80)">[SPEED]</font> ' .. player.Name .. ' @ ' .. math.floor(hum.WalkSpeed))
                    end
                end

                -- Update record
                PlayerData[player.Name] = {Pos = currentPos, Time = tick()}
            end
        end
    end

    -- ===========================
    -- UI CONTROLS
    -- ===========================
    Tab:CreateSection("WatchDog Configuration")

    Tab:CreateToggle("Enable Monitoring", false, function(s)
        Settings.Enabled = s
        if s then
            MonitorBox:SetTitle("🛡️ WatchDog: ACTIVE")
            UpdateLogs("<i>Monitoring started...</i>")
        else
            MonitorBox:SetTitle("🛡️ WatchDog: STANDBY")
            MonitorBox:SetDescription("System disabled.")
            table.clear(Logs)
            table.clear(PlayerData)
        end
    end)

    Tab:CreateSlider("TP Sensitivity", 20, 200, 50, function(v) Settings.TeleportThreshold = v end)
    
    Tab:CreateAction("Clear Logs", "Purge", function()
        table.clear(Logs)
        MonitorBox:SetDescription("<i>Logs cleared.</i>")
    end)

    -- Master Connection
    RunService.Heartbeat:Connect(function()
        -- Only check every ~0.5 seconds to save performance
        task.wait(0.5)
        if Settings.Enabled then
            MonitorPlayers()
        end
    end)
end

return WatchDog

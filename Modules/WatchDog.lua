local WatchDog = {}

function WatchDog.Init(Tab, Library)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    -- ===========================
    -- ADVANCED CONFIG
    -- ===========================
    local Settings = {
        Enabled = false,
        TP_Limit = 45,        -- Studs per 0.5s
        Speed_Limit = 35,     -- Max "Normal" WalkSpeed
        Fly_Threshold = 15,   -- Vertical height maintained without ground
        MaxLogs = 12
    }

    local PlayerData = {} 
    local Logs = {}       

    local MonitorBox = Tab:CreateInfoBox("WatchDog: Advanced Threat Detection", "Ready. Awaiting System Start...")

    -- ===========================
    -- LOGGING ENGINE
    -- ===========================
    local function Log(tag, name, color, detail)
        local timestamp = os.date("%X")
        local entry = string.format('<b>[%s]</b> <font color="%s">[%s]</font> %s: %s', timestamp, color, tag, name, detail)
        
        table.insert(Logs, 1, entry)
        if #Logs > Settings.MaxLogs then table.remove(Logs) end
        MonitorBox:SetDescription(table.concat(Logs, "\n"))
    end

    -- ===========================
    -- DETECTION ENGINES
    -- ===========================
    local function Analyze(player)
        if player == LocalPlayer or not player.Character then return end
        
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local name = player.Name
        local pos = hrp.Position
        local state = hum:GetState()
        local last = PlayerData[name]

        if last then
            local dist = (pos - last.pos).Magnitude
            local verticalDist = pos.Y - last.pos.Y
            
            -- 1. TELEPORT CHECK (Horizontal)
            local horizontalDist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(last.pos.X, 0, last.pos.Z)).Magnitude
            if horizontalDist > Settings.TP_Limit then
                Log("TP", name, "#ff4b4b", math.floor(horizontalDist) .. " studs")
            end

            -- 2. FLY / HOVER CHECK
            -- If they stay at the same Y level while "Freefall" or "Physics" state for too long
            if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Physics then
                if math.abs(verticalDist) < 1.5 and horizontalDist > 5 then
                    last.flyTicks = (last.flyTicks or 0) + 1
                    if last.flyTicks > 4 then -- Flag after 2 seconds of consistent hovering
                        Log("FLY", name, "#4b86ff", "Static Altitude")
                    end
                else
                    last.flyTicks = 0
                end
            end

            -- 3. SPEED CHECK (Magnitude based)
            -- LT2 hackers often bypass the 'WalkSpeed' property, so we check actual velocity
            local velocity = hrp.Velocity.Magnitude
            if velocity > 120 then
                Log("SPD", name, "#ffae4b", "Vel: " .. math.floor(velocity))
            end
            
            -- 4. NO-CLIP (Basic Check)
            -- If the player is deep underground (LT2 map floor is usually around 0 to -50)
            if pos.Y < -60 then
                Log("CLIP", name, "#ffffff", "Under Map")
            end
        end

        PlayerData[name] = {pos = pos, flyTicks = (last and last.flyTicks or 0)}
    end

    -- ===========================
    -- UI & LOOP
    -- ===========================
    Tab:CreateSection("WatchDog Controls")

    Tab:CreateToggle("Master Switch", false, function(s)
        Settings.Enabled = s
        if s then
            Log("SYS", "WatchDog", "#00ff00", "Neural Link Established")
        else
            table.clear(Logs)
            MonitorBox:SetDescription("System Offline.")
        end
    end)

    Tab:CreateSlider("Sensitivity", 10, 100, 45, function(v) Settings.TP_Limit = v end)

    Tab:CreateAction("Wipe History", "Clear", function()
        table.clear(Logs)
        MonitorBox:SetDescription("<i>History purged.</i>")
    end)

    -- Execution Loop
    task.spawn(function()
        while true do
            if Settings.Enabled then
                for _, p in pairs(Players:GetPlayers()) do
                    Analyze(p)
                end
            end
            task.wait(0.5) -- Scan twice per second for efficiency
        end
    end)
end

return WatchDog

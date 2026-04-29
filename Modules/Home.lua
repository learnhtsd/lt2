local HomeModule = {}

function HomeModule.Init(Tab, Library)
    local Player          = game:GetService("Players").LocalPlayer
    local TeleportService = game:GetService("TeleportService")
    local HttpService     = game:GetService("HttpService")
    local Username        = Player.Name

    -- ── 1. Welcome InfoBox ────────────────────────────────────
    local WelcomeBox = Tab:CreateInfoBox()

    WelcomeBox:AddText("👋  Hello, " .. Username .. "!", {
        Bold  = true,
        Size  = 13,
        Color = Color3.fromRGB(220, 220, 220),
    })

    WelcomeBox:AddSpacer(2)

    WelcomeBox:AddText("Thank you for using Dynxe. You are currently using an early version. Im alone and need time :)", {
        Size    = 11,
        Color   = Color3.fromRGB(150, 150, 160),
        Wrap    = true,
        Italic  = true,
    })

    WelcomeBox:AddSpacer(4)
    WelcomeBox:AddDivider()
    WelcomeBox:AddSpacer(2)

    WelcomeBox:AddText("⚠  EARLY ACCESS", {
        Bold  = true,
        Size  = 10,
        Color = Color3.fromRGB(190, 130, 30),
    })

    -- ── 2. Information InfoBox ────────────────────────────────
    local InfoBox = Tab:CreateInfoBox()

    InfoBox:AddText("ℹ  Information", {
        Bold  = true,
        Size  = 13,
        Color = Color3.fromRGB(220, 220, 220),
    })

    InfoBox:AddDivider()
    InfoBox:AddSpacer(2)

    InfoBox:AddText("Version:       v0.0.208", {
        Size  = 11,
        Color = Color3.fromRGB(150, 150, 160),
        Font  = Enum.Font.GothamMono,
    })

    local StatusLabel = InfoBox:AddText("Status:        Checking...", {
        Size  = 11,
        Color = Color3.fromRGB(150, 150, 160),
        Font  = Enum.Font.GothamMono,
    })

    InfoBox:AddText("Last Updated:  April 2026", {
        Size  = 11,
        Color = Color3.fromRGB(150, 150, 160),
        Font  = Enum.Font.GothamMono,
    })

    InfoBox:AddSpacer(2)

    local BadgeLabel = InfoBox:AddText("● ONLINE", {
        Bold  = true,
        Size  = 10,
        Color = Color3.fromRGB(45, 160, 75),
    })

    -- Live status check
    task.spawn(function()
        local ok = pcall(function()
            game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/main/main.lua")
        end)
        if ok then
            StatusLabel:Set("Status:        Online")
            StatusLabel:Tween({ TextColor3 = Color3.fromRGB(45, 160, 75) }, 0.4)
            BadgeLabel:Set("● ONLINE")
            BadgeLabel:Tween({ TextColor3 = Color3.fromRGB(45, 160, 75) }, 0.4)
        else
            StatusLabel:Set("Status:        Offline")
            StatusLabel:Tween({ TextColor3 = Color3.fromRGB(200, 60, 60) }, 0.4)
            BadgeLabel:Set("● OFFLINE")
            BadgeLabel:Tween({ TextColor3 = Color3.fromRGB(200, 60, 60) }, 0.4)
            Library:Notify("Warning", "Could not reach the update server.", 5)
        end
    end)

    -- ── 3. Server Management ──────────────────────────────────
    Tab:CreateSection("Server Management")

    local function ServerHop(order)
        local LoadScript = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/main/main.lua?t="..tick()))()'
        if queue_on_teleport then queue_on_teleport(LoadScript) end

        Library:Notify("System", "Searching for " .. (order == "Asc" and "smallest" or "largest") .. " server...", 4)

        local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100"
        local success, Servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(api))
        end)

        if success and Servers and Servers.data then
            for _, s in pairs(Servers.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, Player)
                    return
                end
            end
        end

        Library:Notify("Error", "No suitable server found.", 3)
    end

    Tab:CreateAction("Rejoin Server", "Rejoin", function()
        local LoadScript = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/main/main.lua?t="..tick()))()'
        if queue_on_teleport then queue_on_teleport(LoadScript) end
        TeleportService:Teleport(game.PlaceId, Player)
    end)

    local HopRow = Tab:CreateRow()
    HopRow:CreateAction("Descending Server", "Join", function() ServerHop("Asc")  end)
    HopRow:CreateAction("Ascending Server",  "Join", function() ServerHop("Desc") end)

    -- ── 4. Community & Support ────────────────────────────────
    Tab:CreateSection("Community & Support")

    Tab:CreateAction("Discord Server", "Copy", function()
        setclipboard("https://discord.gg/yourlink")
        Library:Notify("System", "Invite link copied to clipboard!", 3)
    end)

    Tab:CreateAction("YouTube Channel", "Open", function()
        if request then
            request({ Url = "https://youtube.com/@yourchannel", Method = "GET" })
        else
            setclipboard("https://youtube.com/@yourchannel")
            Library:Notify("System", "Link copied to clipboard!", 3)
        end
    end)
end

return HomeModule

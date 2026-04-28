local HomeModule = {}
function HomeModule.Init(Tab, Library)
    local Player = game:GetService("Players").LocalPlayer
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local Username = Player.Name

    -- 1. Welcome InfoBox
    Tab:CreateInfoBox({
        Title       = "Hello, " .. Username .. "!",
        Icon        = "👋",
        Badge       = "Early Access",
        BadgeColor  = Color3.fromRGB(160, 100, 15),
        Description = "Thank you for using Dynxe. You are currently using an early version. Im alone and need time :)",
    })

    -- 2. Information InfoBox
    local InfoBox = Tab:CreateInfoBox({
        Title       = "Information",
        Icon        = "ℹ",
        Badge       = "Online",
        BadgeColor  = Color3.fromRGB(45, 160, 75),
        Description = "Version: v0.0.101\nStatus: Online\nLast Updated: April 2026",
    })

    -- Optionally update the badge live based on a connectivity check
    -- InfoBox:SetBadge("Offline", Color3.fromRGB(180, 60, 60))

    -- 2. SERVER MANAGEMENT SECTION
    Tab:CreateSection("Server Management")

    -- Unified Teleport Function with reload logic
    local function ServerHop(order)
        local LoadScript = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/main/main.lua?t="..tick()))()'
        if queue_on_teleport then queue_on_teleport(LoadScript) end
        Library:Notify("System", "Searching for " .. (order == "Asc" and "Smallest" or "Largest") .. " server...", 4)
        local api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100"
        local success, Servers = pcall(function() return HttpService:JSONDecode(game:HttpGet(api)) end)
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

    -- Server Management Actions
    Tab:CreateAction("Rejoin Server", "Rejoin", function()
        local LoadScript = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/learnhtsd/lt2/main/main.lua?t="..tick()))()'
        if queue_on_teleport then queue_on_teleport(LoadScript) end
        TeleportService:Teleport(game.PlaceId, Player)
    end)

    local HopRow = Tab:CreateRow()
    HopRow:CreateAction("Decending Server", "Join", function() ServerHop("Asc") end)
    HopRow:CreateAction("Ascending Server", "Join", function() ServerHop("Desc") end)

    -- 3. Socials / Links Section
    Tab:CreateSection("Community & Support")

    Tab:CreateAction("Discord Server", "Copy", function()
        setclipboard("https://discord.gg/yourlink")
        Library:Notify("System", "Link copied!", 3)
    end)

    Tab:CreateAction("YouTube Channel", "Open", function()
        if request then
            request({Url = "https://youtube.com/@yourchannel", Method = "GET"})
        else
            setclipboard("https://youtube.com/@yourchannel")
            Library:Notify("System", "Link copied!", 3)
        end
    end)
end

return HomeModule

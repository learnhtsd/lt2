local HomeModule = {}

function HomeModule.Init(Tab, Library)
    local Player = game:GetService("Players").LocalPlayer
    local TeleportService = game:GetService("TeleportService")
    local Username = Player.Name 

    -- 1. Welcome InfoBox
    Tab:CreateInfoBox("Hello, " .. Username .. "!", "Thank you for using Dynxe. You are currently using an early version of Dynxe. I'm alone and need time :)")
    
    Tab:CreateInfoBox("Information", "Current Version: v0.0.101\nStatus: Online\nLast Updated: April 2026")

    -- 2. SERVER MANAGEMENT SECTION
    Tab:CreateSection("Server Management")

    -- Helper function to ensure script auto-runs after teleporting
    local function PrepareAutoLoad()
        local scriptUrl = "https://raw.githubusercontent.com/learnhtsd/lt2/main/Main.lua" -- Use your actual loadstring URL
        if queue_on_teleport then
            queue_on_teleport('loadstring(game:HttpGet("' .. scriptUrl .. '"))()')
        end
    end

    Tab:CreateAction("Rejoin Server", "Rejoin", function()
        PrepareAutoLoad()
        Library:Notify("System", "Rejoining current server...", 3)
        TeleportService:Teleport(game.PlaceId, Player)
    end)

    Tab:CreateAction("Small Server", "Find New", function()
        PrepareAutoLoad()
        Library:Notify("System", "Searching for a different server...", 3)
        
        -- Basic server hop logic
        local HttpService = game:GetService("HttpService")
        local Servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        
        for _, s in pairs(Servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, Player)
                break
            end
        end
    end)

    -- 3. Socials / Links Section
    Tab:CreateSection("Community & Support")
    
    Tab:CreateAction("Discord Server", "Copy Link", function()
        setclipboard("https://discord.gg/yourlink")
        Library:Notify("System", "Discord link copied to clipboard!", 3)
    end)

    Tab:CreateAction("YouTube Channel", "Open Link", function()
        if request then
            request({Url = "https://youtube.com/@yourchannel", Method = "GET"})
        else
            setclipboard("https://youtube.com/@yourchannel")
            Library:Notify("System", "Link copied (Executor doesn't support opening browsers)", 3)
        end
    end)
end

return HomeModule

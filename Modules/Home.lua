local HomeModule = {}

function HomeModule.Init(Tab, Library)
    -- Get the local player
    local Player = game:GetService("Players").LocalPlayer
    local Username = Player.Name -- This is their @name

    -- 1. Welcome InfoBox (Updated with @username)
    Tab:CreateInfoBox("Hello, " .. Username .. "!", "Thank you for using Dynxe. You are currently using a early version of Dynxe. Im alone and need time :)")
    
    Tab:CreateInfoBox("Information", "Current Version: v~\nStatus: yup is working\nLast Updated: March 2026")

    -- 3. Socials / Links Section
    Tab:CreateSection("Community & Support")
    
    Tab:CreateAction("Discord Server", "Copy Link", function()
        setclipboard("https://discord.gg/yourlink") -- Replace with your actual link
        Library:Notify("System", "Discord link copied to clipboard!", 3)
    end)

    Tab:CreateAction("YouTube Channel", "Open Link", function()
        -- Most executors support this to open a browser window
        if request then
            request({
                Url = "https://youtube.com/@yourchannel",
                Method = "GET"
            })
        else
            setclipboard("https://youtube.com/@yourchannel")
            Library:Notify("System", "Link copied (Executor doesn't support opening browsers)", 3)
        end
    end)
end

return HomeModule

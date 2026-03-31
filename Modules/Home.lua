local HomeModule = {}

function HomeModule.Init(Tab, Library)
    -- 1. Welcome InfoBox
    Tab:CreateInfoBox("Nexus Custom Hub", "Welcome to the ultimate Lumber Tycoon 2 companion. Use the sidebar to navigate through the different categories.")

    -- 2. Script Details Section
    Tab:CreateSection("Script Status")
    
    Tab:CreateInfoBox("Version Info", "Current Version: v0.0.053\nStatus: [ ONLINE ]\nLast Updated: March 2026")

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

    -- 4. Keybinds Reminder
    Tab:CreateSection("Quick Tips")
    
    Tab:CreateInfoBox("", "• Press 'RightShift' to hide/show the UI.\n• If icons don't load, wait a few seconds and rejoin.\n• Use 'Ghost Suite' for seamless building.")

    -- 5. Credits
    Tab:CreateSection("Credits")
    Tab:CreateInfoBox("Developed By", "Main Developer: learnhtsd\nUI Design: Nexus Team\nSpecial thanks to the LT2 Community.")
end

return HomeModule

local BaseURL = "https://raw.githubusercontent.com/learnhtsd/lt2/main/"

-- 1. Load the Library
local Lib = loadstring(game:HttpGet(BaseURL .. "UI_Library.lua"))()

-- 2. Load the Modules
local MoveMod = loadstring(game:HttpGet(BaseURL .. "Modules/Movement.lua"))()
local TeleMod = loadstring(game:HttpGet(BaseURL .. "Modules/Teleports.lua"))()

-- 3. Assemble the UI
local MoveTab = Lib:CreateTab("Movement")
local TeleTab = Lib:CreateTab("Teleports")

-- Add Movement Buttons
Lib:CreateButton(MoveTab, "Speed (50)", function() MoveMod.SetSpeed(50) end)

-- Add Teleport Buttons using a loop
for _, loc in pairs(TeleMod.Locations) do
    Lib:CreateButton(TeleTab, loc[1], function() TeleMod.GoTo(loc[2]) end)
end

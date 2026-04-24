Dynxe LT2 UI Engine Documentation

Overview

The Dynxe LT2 UI Engine is a modern, modular graphical user interface library for Roblox scripts. It utilizes a sleek dark theme, smooth TweenService animations, draggable windows with synchronized backdrop shadows, and a dynamic tab system.

This library is designed for exploit/script hub developers and includes robust features like custom custom icon loading (via getcustomasset), secure double-click confirmation buttons, fluid sliders, and an intuitive tooltip system.

1. Initialization

To start using the library, you first need to create the main window. When initialized, the engine automatically cleans up any previous instances of the GUI to prevent duplicates.

-- Load the library (assuming the script is assigned to the 'Library' variable)
local Window = Library:CreateWindow()


2. Global Features

Notifications

The library includes a built-in notification system that slides in from the bottom right of the screen.

-- Library:Notify(Title, Text, Duration)
Library:Notify("Success", "Script loaded successfully!", 5)


Tooltips

Almost any UI element can have a tooltip attached to it. This adds a small (?) icon next to the element's title. Hovering over this icon reveals a descriptive text box that follows the mouse.

You can chain :AddTooltip("your text") to the end of your element creation code:

Tab:CreateToggle("Auto Farm", false, function(state) end):AddTooltip("Automatically farms nearby enemies.")


3. Layout & Structure

Creating Tabs

The UI is divided into tabs on the left sidebar. If your executor supports custom assets (isfolder, writefile, getcustomasset), the library will attempt to fetch a custom icon from your GitHub repository. Otherwise, it falls back to a clean initial-letter icon.

local MainTab = Window:CreateTab("Main")
local SettingsTab = Window:CreateTab("Settings")


Sections

Sections are simple, bold, colored text labels used to categorize elements within a tab.

MainTab:CreateSection("Player Hacks")


Rows (Side-by-Side Elements)

You can place elements side-by-side using the CreateRow function. Any UI elements created inside this row will be evenly spaced horizontally.

local PlayerRow = MainTab:CreateRow()

-- These two toggles will appear next to each other on the same line
PlayerRow:CreateToggle("God Mode", false, function() end)
PlayerRow:CreateToggle("Invisibility", false, function() end)


4. UI Elements

Actions (Buttons)

Creates a clickable button.

Standard Button:

MainTab:CreateAction("Give Health", "Execute", function()
    print("Health given!")
end)


Secure Button (Double-Confirm):
By passing true as the 4th parameter, the button becomes "Secure."

1st Click: Button turns amber and asks "Confirm?". If ignored for 3 seconds, it resets.

2nd Click: Executes the function, briefly flashes green, and displays "✓ Done".

MainTab:CreateAction("Wipe Data", "Delete", function()
    print("Data wiped!")
end, true)


Toggles

Creates a boolean switch (On/Off).

-- Tab:CreateToggle(Title, DefaultState, Callback)
MainTab:CreateToggle("Aimbot", false, function(state)
    print("Aimbot is now:", state)
end)


Sliders

Creates a fluid, draggable slider for numeric values. The user can click anywhere on the slider frame to immediately snap to that value. The current value is cleanly displayed in blue on the right side.

-- Tab:CreateSlider(Title, Min, Max, Default, Callback)
MainTab:CreateSlider("WalkSpeed", 16, 100, 16, function(value)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
end)


Keybinds

Creates a button that listens for user keyboard or mouse input. When clicked, it waits for the user's next key press to assign a new hotkey. When that hotkey is pressed later, the callback fires.

-- Tab:CreateKeybind(Title, DefaultKey, Callback)
MainTab:CreateKeybind("Toggle Aimbot", Enum.KeyCode.E, function()
    print("Hotkey pressed!")
end)


Info Boxes

Creates a clean, formatted text box to display information. It returns an object that allows you to dynamically update the text at any time.

-- Tab:CreateInfoBox(Title, Description)
local StatusBox = MainTab:CreateInfoBox("Status", "Waiting for game to load...")

-- Update dynamically later in your script:
StatusBox:SetTitle("Connected")
StatusBox:SetDescription("Ready to execute scripts.")


Dropdowns

Creates a collapsible menu for selecting a single option from a provided list.

-- Tab:CreateDropdown(Title, OptionsTable, DefaultSelected, Callback)
MainTab:CreateDropdown("Teleport Location", {"Spawn", "Wood Drop", "Volcano"}, "Spawn", function(selected)
    print("Teleporting to: " .. selected)
end)


5. Modular Script Execution (Advanced)

The Dynxe LT2 UI engine comes pre-configured with a remote loading system. Instead of putting all script logic inside the UI file, it utilizes a LoadModule function to fetch logic directly from your GitHub repository (using game:HttpGet and loadstring).

local function LoadModule(ModuleName)
    -- Fetches raw lua module from Github
end

-- Example of loading and initializing an external script
local TeleportModule = LoadModule("Teleport")
if TeleportModule and TeleportModule.Init then 
    TeleportModule.Init(TeleportTab) 
end


This architecture allows you to maintain clean UI code while categorizing your game exploits into isolated files (e.g., PlayerMovement.lua, GetWood.lua, WatchDog.lua).

Dependencies & Requirements

Executor Support: For the custom tab icons to work, the executing environment must support isfolder, makefolder, writefile, isfile, getcustomasset, and game:HttpGet.

Font: Relies on Roblox's built-in Gotham font family (Gotham, GothamMedium, GothamBold).

Services: Heavily relies on CoreGui, UserInputService, and TweenService.

local GhostSuite = {}

function GhostSuite.Init(Tab)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()

    -- ===========================
    -- STATE & CONFIG
    -- ===========================
    _G.GhostSuiteEnabled = false
    local ExtractedObjects = {}
    
    local BlacklistNames = {
        ["Baseplate"] = true, ["BasePlate"] = true,
        ["Ground"] = true, ["Water"] = true, ["Map"] = true
    }

    -- ===========================
    -- CORE LOGIC
    -- ===========================
    local function IsProtected(target)
        if BlacklistNames[target.Name] then return true end
        if target:FindFirstAncestor("Properties") or target:FindFirstAncestor("Owner") then
            return true
        end
        if target.Name:lower():find("baseplate") then return true end
        return false
    end

    local function CreateOutline(target)
        local box = Instance.new("SelectionBox")
        box.Name = "GhostHighlighter"
        box.Adornee = target
        box.LineThickness = 0.05
        box.Color3 = Color3.fromRGB(0, 255, 150)
        box.SurfaceColor3 = Color3.fromRGB(0, 255, 150)
        box.SurfaceTransparency = 0.8
        box.Parent = game:GetService("CoreGui") 
        return box
    end

    local function RestoreAll()
        local count = 0
        for part, data in pairs(ExtractedObjects) do
            if part then
                part.Parent = data.Parent
                if data.Box then data.Box:Destroy() end
                count = count + 1
            end
        end
        ExtractedObjects = {}
        return count
    end

    -- ===========================
    -- UI ELEMENTS
    -- ===========================
    Tab:CreateSection("Ghost Suite")
    Tab:CreateToggle("Master Enable", false, function(s) 
        _G.GhostSuiteEnabled = s 
        if not s then RestoreAll() end
    end)

    Tab:CreateSection("Controls")
    Tab:CreateAction("Restore All Objects", "Reset", function()
        local count = RestoreAll()
        print("Restored " .. count .. " objects.")
    end)

    Tab:CreateSection("Keybinds")
    
    -- Dynamic Keybinds instead of static Actions
    Tab:CreateKeybind("Ghost Object Key", Enum.UserInputType.MouseButton3, function()
        if not _G.GhostSuiteEnabled then return end
        
        local target = Mouse.Target
        if target and target:IsA("BasePart") then
            if IsProtected(target) then return end

            if ExtractedObjects[target] then
                local data = ExtractedObjects[target]
                target.Parent = data.Parent
                if data.Box then data.Box:Destroy() end
                ExtractedObjects[target] = nil
            else
                local originalParent = target.Parent
                local outline = CreateOutline(target)
                ExtractedObjects[target] = { Parent = originalParent, Box = outline }
                target.Parent = nil -- This "ghosts" the object
            end
        end
    end)

    Tab:CreateKeybind("Mass Restore Key", Enum.KeyCode.Z, function()
        if not _G.GhostSuiteEnabled then return end
        RestoreAll()
    end)
end

return GhostSuite

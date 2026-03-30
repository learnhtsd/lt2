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
    _G.GhostKey = Enum.UserInputType.MouseButton3 -- Default: Middle Click
    _G.RestoreKey = Enum.KeyCode.Z
    
    local ExtractedObjects = {}
    
    local BlacklistNames = {
        ["Baseplate"] = true, ["BasePlate"] = true,
        ["Ground"] = true, ["Water"] = true, ["Map"] = true
    }

    -- ===========================
    -- CORE LOGIC
    -- ===========================
    local function IsProtected(target)
        if not target then return true end
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
        for part, data in pairs(ExtractedObjects) do
            if part then
                part.Parent = data.Parent
                if data.Box then data.Box:Destroy() end
            end
        end
        ExtractedObjects = {}
    end

    -- ===========================
    -- UI ELEMENTS (Fixed Labels)
    -- ===========================
    Tab:CreateSection("Ghost Suite")
    Tab:CreateToggle("Master Enable", false, function(s) 
        _G.GhostSuiteEnabled = s 
        if not s then RestoreAll() end
    end)

    -- Now these are functional keybinds instead of static "INFO" buttons
    Tab:CreateKeybind("Mass Restore Key", _G.RestoreKey, function()
        if _G.GhostSuiteEnabled then RestoreAll() end
    end)

    Tab:CreateAction("Manual Restore All", "Reset Now", function()
        RestoreAll()
    end)

    -- ===========================
    -- INPUT HANDLER
    -- ===========================
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not _G.GhostSuiteEnabled then return end

        -- Ghost/Unghost Logic (Checks against the MouseButton3 or your custom bind)
        if input.UserInputType == _G.GhostKey then
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
                    target.Parent = nil 
                end
            end
        end
    end)
end

return GhostSuite

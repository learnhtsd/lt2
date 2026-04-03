-- Inside your Init function where 'Tab' is defined
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- STATE VARIABLE
_G.AntiFlingEnabled = false

-- SETTINGS (Adjustable)
local MaxHorizontalSpeed = 100 
local MaxRotationSpeed = 10    
local MaxVerticalSpeed = 250   

-- UI SECTION
Tab:CreateToggle("Anti-Fling", false, function(state)
    _G.AntiFlingEnabled = state
end)

-- MASTER LOGIC
RunService.Heartbeat:Connect(function()
    if not _G.AntiFlingEnabled then return end
    
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")
    
    if Root then
        -- 1. KILL ROTATION (Prevents the spin-out)
        if Root.AssemblyAngularVelocity.Magnitude > MaxRotationSpeed then
            Root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        
        -- 2. LIMIT HORIZONTAL VELOCITY (Allows jumping/flying)
        local Velocity = Root.AssemblyLinearVelocity
        local HorizontalVelocity = Vector3.new(Velocity.X, 0, Velocity.Z)
        
        if HorizontalVelocity.Magnitude > MaxHorizontalSpeed then
            local NewHorizontal = HorizontalVelocity.Unit * MaxHorizontalSpeed
            Root.AssemblyLinearVelocity = Vector3.new(NewHorizontal.X, Velocity.Y, NewHorizontal.Z)
        end

        -- 3. EXTREME VERTICAL SAFETY
        if math.abs(Velocity.Y) > MaxVerticalSpeed then
            Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, 0, Root.AssemblyLinearVelocity.Z)
        end
    end
end)

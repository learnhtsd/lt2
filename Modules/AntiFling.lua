local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MaxHorizontalSpeed = 100 -- Prevents being launched sideways
local MaxRotationSpeed = 10    -- Prevents the "spinning" fling
local MaxVerticalSpeed = 250   -- High enough to allow jumping/flying

RunService.Heartbeat:Connect(function()
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")
    
    if Root then
        -- 1. FIX ROTATION (The main cause of flinging)
        -- We limit how fast the character can spin.
        if Root.AssemblyAngularVelocity.Magnitude > MaxRotationSpeed then
            Root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        
        -- 2. FIX VELOCITY (The movement/launching)
        local Velocity = Root.AssemblyLinearVelocity
        
        -- Check if we are moving too fast horizontally (X and Z)
        local HorizontalVelocity = Vector3.new(Velocity.X, 0, Velocity.Z)
        
        if HorizontalVelocity.Magnitude > MaxHorizontalSpeed then
            -- Scale it back down to the max speed instead of stopping entirely
            local NewHorizontal = HorizontalVelocity.Unit * MaxHorizontalSpeed
            Root.AssemblyLinearVelocity = Vector3.new(NewHorizontal.X, Velocity.Y, NewHorizontal.Z)
        end

        -- 3. SAFETY CAP FOR VERTICAL (To allow jumping/flying)
        -- Only zero it out if it's an extreme "map-clearing" launch
        if math.abs(Velocity.Y) > MaxVerticalSpeed then
            Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, 0, Root.AssemblyLinearVelocity.Z)
        end
    end
end)

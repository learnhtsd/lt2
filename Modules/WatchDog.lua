local WatchDog = {}
WatchDog.__index = WatchDog

local RunService = game:GetService("RunService")

function WatchDog.new(targetPlayer)
    local self = setmetatable({}, WatchDog)
    self.Player = targetPlayer
    self.LastPos = nil
    self.Flags = 0
    self.Threshold = 28 -- Speed limit (Standard walk is 16)
    self.Active = false
    return self
end

function WatchDog:Start(callback)
    if self.Active then return end
    self.Active = true
    
    self.Connection = RunService.Heartbeat:Connect(function(dt)
        local char = self.Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if root and hum and hum.Health > 0 then
            local currentPos = root.Position
            
            if self.LastPos then
                -- Calculate horizontal velocity (X and Z only)
                -- Distance formula: d = sqrt((x2-x1)^2 + (z2-z1)^2)
                local distance = (Vector2.new(currentPos.X, currentPos.Z) - Vector2.new(self.LastPos.X, self.LastPos.Z)).Magnitude
                local speed = distance / dt
                
                -- Detect Speeding or Teleporting (ignores seated players)
                local isSpeeding = speed > self.Threshold and not hum.Sit
                local isTeleporting = speed > 350 
                
                if isSpeeding or isTeleporting then
                    -- Increase suspicion severity
                    self.Flags = math.min(self.Flags + 1.5, 100)
                else
                    -- Slowly clear suspicion over time
                    self.Flags = math.max(self.Flags - 0.1, 0)
                end

                -- Send the data back to your UI
                callback({
                    Speed = math.floor(speed),
                    IsHacking = (self.Flags > 20), -- Status flips at 20% risk
                    Severity = self.Flags
                })
            end
            self.LastPos = currentPos
        end
    end)
end

function WatchDog:Stop()
    if self.Connection then 
        self.Connection:Disconnect() 
        self.Active = false
    end
end

return WatchDog

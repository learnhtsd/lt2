-- ============================================================
-- PASTE THIS BLOCK inside Tab:CreateAction(), just before the
-- final:  return AttachTooltip(TitleLabel, Element)
-- It exposes SetDisabled() and SetText() on the returned element.
-- ============================================================

    function Element:SetDisabled(disabled)
        ActionBtn.AutoButtonColor = not disabled
        ActionBtn.TextColor3      = disabled and Color3.fromRGB(80, 80, 90) or T.TextWhite
        TweenService:Create(ActionBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = disabled and Color3.fromRGB(28, 28, 33) or T.SurfaceDeep
        }):Play()
    end

    function Element:SetText(text)
        ActionBtn.Text = text
    end

-- ============================================================
-- Vehicle.lua  (all original bugs fixed)
-- ============================================================

local VehicleModule = {}

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local function FlipVehicle()
    local character = player.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
        local vehicleMain = humanoid.SeatPart.Parent
        local targetPart  = vehicleMain:IsA("Model") and vehicleMain.PrimaryPart or humanoid.SeatPart

        if targetPart then
            local flipCF = targetPart.CFrame * CFrame.Angles(0, 0, math.pi)
            targetPart.CFrame = flipCF + Vector3.new(0, 2, 0)  -- nudge up to prevent clipping
        end
    end
end

function VehicleModule.Init(Tab)
    Tab:CreateSection("Vehicle Utilities")

    local FlipButton = Tab:CreateAction("Flip Vehicle", "Flip 180°", function()
        FlipVehicle()
    end)

    FlipButton:AddTooltip("Flips your current vehicle right-side up. Only active when seated in a vehicle.")

    -- Start disabled — player isn't in a vehicle yet
    FlipButton:SetDisabled(true)
    FlipButton:SetText("No Vehicle")

    -- Poll seat state and update button accordingly
    task.spawn(function()
        local lastState = nil

        while task.wait(0.5) do
            local char        = player.Character
            local hum         = char and char:FindFirstChildOfClass("Humanoid")
            local isInVehicle = not not (hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat"))

            if isInVehicle ~= lastState then
                lastState = isInVehicle

                if isInVehicle then
                    FlipButton:SetDisabled(false)
                    FlipButton:SetText("Flip 180°")
                else
                    FlipButton:SetDisabled(true)
                    FlipButton:SetText("No Vehicle")
                end
            end
        end
    end)
end

return VehicleModule

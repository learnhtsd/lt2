-- [[ BRAND MODULE ]] --
-- Auto-spawns a 3D Dynxe logo bar in the workspace

local BrandModule = {}

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")
local Player       = Players.LocalPlayer

local THEME = {
    Accent      = Color3.fromRGB(74,  120, 255),
    Background  = Color3.fromRGB(18,  18,  22),
    TextWhite   = Color3.fromRGB(255, 255, 255),
}

function BrandModule.Init(version, position, rotation)
    local VERSION  = version  or "v0.0.272"
    local _Position = position or Vector3.new(0, 5, 0)
    local _Rotation = rotation or Vector3.new(0, 0, 0)

    local rootCF = CFrame.new(_Position)
        * CFrame.Angles(
            math.rad(_Rotation.X),
            math.rad(_Rotation.Y),
            math.rad(_Rotation.Z)
        )

    local Model = Instance.new("Model")
    Model.Name = "DynxeBrand"

    -- ── Main bar ──────────────────────────────────────────────────
    local Bar = Instance.new("Part")
    Bar.Name             = "Bar"
    Bar.Size             = Vector3.new(4.2, 0.55, 0.18)
    Bar.Color            = THEME.Background
    Bar.Material         = Enum.Material.SmoothPlastic
    Bar.Anchored         = true
    Bar.CanCollide       = false
    Bar.CastShadow       = false
    Bar.TopSurface       = Enum.SurfaceType.Smooth
    Bar.BottomSurface    = Enum.SurfaceType.Smooth
    Bar.CFrame           = rootCF
    Bar.Parent           = Model

    -- ── Accent strip ──────────────────────────────────────────────
    local Strip = Instance.new("Part")
    Strip.Name          = "AccentStrip"
    Strip.Size          = Vector3.new(4.2, 0.06, 0.20)
    Strip.Color         = THEME.Accent
    Strip.Material      = Enum.Material.Neon
    Strip.Anchored      = true
    Strip.CanCollide    = false
    Strip.CastShadow    = false
    Strip.TopSurface    = Enum.SurfaceType.Smooth
    Strip.BottomSurface = Enum.SurfaceType.Smooth
    Strip.CFrame        = rootCF * CFrame.new(0, -0.305, -0.01)
    Strip.Parent        = Model

    -- ── Left cap ──────────────────────────────────────────────────
    local CapL = Instance.new("Part")
    CapL.Name          = "CapLeft"
    CapL.Size          = Vector3.new(0.06, 0.55, 0.20)
    CapL.Color         = THEME.Accent
    CapL.Material      = Enum.Material.Neon
    CapL.Anchored      = true
    CapL.CanCollide    = false
    CapL.CastShadow    = false
    CapL.TopSurface    = Enum.SurfaceType.Smooth
    CapL.BottomSurface = Enum.SurfaceType.Smooth
    CapL.CFrame        = rootCF * CFrame.new(-2.07, 0, -0.01)
    CapL.Parent        = Model

    -- ── Right cap ─────────────────────────────────────────────────
    local CapR = CapL:Clone()
    CapR.Name   = "CapRight"
    CapR.CFrame = rootCF * CFrame.new(2.07, 0, -0.01)
    CapR.Parent = Model

    -- ── "Dynxe" label ─────────────────────────────────────────────
    local LabelMain = Instance.new("Part")
    LabelMain.Size       = Vector3.new(2.0, 0.42, 0.08)
    LabelMain.Transparency = 1
    LabelMain.Anchored   = true
    LabelMain.CanCollide = false
    LabelMain.CastShadow = false
    LabelMain.CFrame     = rootCF * CFrame.new(-0.55, 0.02, -0.05)
    LabelMain.Parent     = Model

    local SG_Main = Instance.new("SurfaceGui", LabelMain)
    SG_Main.Face          = Enum.NormalId.Front
    SG_Main.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    SG_Main.PixelsPerStud = 100
    SG_Main.AlwaysOnTop   = true
    SG_Main.LightInfluence = 0

    local TxtMain = Instance.new("TextLabel", SG_Main)
    TxtMain.Size                  = UDim2.new(1, 0, 1, 0)
    TxtMain.BackgroundTransparency = 1
    TxtMain.Text                  = "Dynxe"
    TxtMain.Font                  = Enum.Font.GothamBold
    TxtMain.TextScaled            = true
    TxtMain.TextColor3            = THEME.TextWhite
    TxtMain.TextXAlignment        = Enum.TextXAlignment.Left

    -- ── Version label ─────────────────────────────────────────────
    local LabelVer = Instance.new("Part")
    LabelVer.Size        = Vector3.new(1.6, 0.28, 0.08)
    LabelVer.Transparency = 1
    LabelVer.Anchored    = true
    LabelVer.CanCollide  = false
    LabelVer.CastShadow  = false
    LabelVer.CFrame      = rootCF * CFrame.new(1.1, -0.06, -0.05)
    LabelVer.Parent      = Model

    local SG_Ver = Instance.new("SurfaceGui", LabelVer)
    SG_Ver.Face          = Enum.NormalId.Front
    SG_Ver.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    SG_Ver.PixelsPerStud = 100
    SG_Ver.AlwaysOnTop   = true
    SG_Ver.LightInfluence = 0

    local TxtVer = Instance.new("TextLabel", SG_Ver)
    TxtVer.Size                  = UDim2.new(1, 0, 1, 0)
    TxtVer.BackgroundTransparency = 1
    TxtVer.Text                  = VERSION
    TxtVer.Font                  = Enum.Font.Gotham
    TxtVer.TextScaled            = true
    TxtVer.TextColor3            = THEME.Accent
    TxtVer.TextXAlignment        = Enum.TextXAlignment.Right

    Model.PrimaryPart = Bar
    Model.Parent      = workspace

    -- ── Neon pulse ────────────────────────────────────────────────
    task.spawn(function()
        while Model and Model.Parent do
            TweenService:Create(Strip, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = Color3.fromRGB(100, 150, 255)
            }):Play()
            task.wait(1.4)
            TweenService:Create(Strip, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = THEME.Accent
            }):Play()
            task.wait(1.4)
        end
    end)

    return Model
end

return BrandModule
